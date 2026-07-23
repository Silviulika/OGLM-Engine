unit Renderer.AnimatedSprites;

interface

uses
  System.SysUtils, System.Classes, System.Math, System.Types,
  System.Generics.Collections, System.IOUtils,
  Vcl.Graphics, Vcl.Imaging.pngimage, GraphicEx,
  dglOpenGL, Neslib.FastMath,
  Renderer.Shader, Engine.Paths, Engine.Types;

type
  TAnimatedSpriteBlendMode = (asAlpha, asAdditive);

  TAnimatedSprite = class
  private type
    TAnimatedSpriteVertex = packed record
      Position: TVector3;
      Color: TVector4;
      TexCoord: TVector2;
    end;
  private
    FName: string;
    FEnabled: Boolean;
    FWidth: Single;
    FHeight: Single;
    FOffset: TVector3;
    FRotation: Single;
    FColor: TVector4;
    FBlendMode: TAnimatedSpriteBlendMode;
    FAlphaCutoff: Single;
    FFrameRate: Single;
    FLoop: Boolean;
    FPlaying: Boolean;
    FCurrentFrameIndex: Integer;
    FFrameTimer: Single;
    FTexturePath: string;
    FGridColumns: Integer;
    FGridRows: Integer;
    FFirstFrame: Integer;
    FFrameCount: Integer;

    FVAO: GLuint;
    FVBO: GLuint;
    FTextureID: GLuint;
    FTextureWidth: Integer;
    FTextureHeight: Integer;
    FTextureKey: string;
    FTextureDirty: Boolean;
    FShader: TShader;

    function GetFrameCount: Integer;
    function GetGridFrameCapacity: Integer;
    function GetCurrentSheetFrameIndex: Integer;
    procedure SetWidth(const Value: Single);
    procedure SetHeight(const Value: Single);
    procedure SetAlphaCutoff(const Value: Single);
    procedure SetFrameRate(const Value: Single);
    procedure SetCurrentFrameIndex(const Value: Integer);
    procedure SetTexturePath(const Value: string);
    procedure SetGridColumns(const Value: Integer);
    procedure SetGridRows(const Value: Integer);
    procedure SetFirstFrame(const Value: Integer);
    procedure SetFrameCount(const Value: Integer);
    procedure NormalizeFrameRange;

    procedure EnsureBuffers;
    procedure EnsureShader;
    procedure EnsureTexture;
    procedure DestroyBuffers;
    procedure DestroyTexture;
    procedure DestroyShader;
    procedure MarkTextureDirty;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Assign(Source: TAnimatedSprite);
    function Clone: TAnimatedSprite;

    function LoadTexture(const APath: string): Boolean;
    procedure Restart;
    procedure Update(DeltaTime: Single);
    procedure Render(const ViewProjection: TMatrix4; const OwnerWorldMatrix: TMatrix4;
      const CameraRight, CameraUp: TVector3);

    procedure SaveToStream(Stream: TStream);
    procedure LoadFromStream(Stream: TStream);

    property Name: string read FName write FName;
    property Enabled: Boolean read FEnabled write FEnabled;
    property Width: Single read FWidth write SetWidth;
    property Height: Single read FHeight write SetHeight;
    property Offset: TVector3 read FOffset write FOffset;
    property Rotation: Single read FRotation write FRotation;
    property Color: TVector4 read FColor write FColor;
    property BlendMode: TAnimatedSpriteBlendMode read FBlendMode write FBlendMode;
    property AlphaCutoff: Single read FAlphaCutoff write SetAlphaCutoff;
    property FrameRate: Single read FFrameRate write SetFrameRate;
    property Loop: Boolean read FLoop write FLoop;
    property Playing: Boolean read FPlaying write FPlaying;
    property CurrentFrameIndex: Integer read FCurrentFrameIndex write SetCurrentFrameIndex;
    property TexturePath: string read FTexturePath write SetTexturePath;
    property GridColumns: Integer read FGridColumns write SetGridColumns;
    property GridRows: Integer read FGridRows write SetGridRows;
    property FirstFrame: Integer read FFirstFrame write SetFirstFrame;
    property FrameCount: Integer read GetFrameCount write SetFrameCount;
    property GridFrameCapacity: Integer read GetGridFrameCapacity;
    property CurrentSheetFrameIndex: Integer read GetCurrentSheetFrameIndex;
    property TextureID: GLuint read FTextureID;
    property TextureWidth: Integer read FTextureWidth;
    property TextureHeight: Integer read FTextureHeight;
  end;

  TAnimatedSpriteList = class(TObjectList<TAnimatedSprite>)
  private
    function GetItem(AIndex: Integer): TAnimatedSprite;
  public
    function AddAnimatedSpriteToList(AAnimatedSprite: TAnimatedSprite): Integer;
    function CreateAnimatedSprite: TAnimatedSprite;
    function NameIsUnique(const AName: string): Boolean;
    function GenerateUniqueName: string;
    function DeleteAnimatedSprite(AIndex: Integer): Boolean; overload;
    function DeleteAnimatedSprite(AAnimatedSprite: TAnimatedSprite): Boolean; overload;
    function Clone: TAnimatedSpriteList;
    procedure Update(DeltaTime: Single);
    procedure SaveToStream(Stream: TStream);
    procedure LoadFromStream(Stream: TStream);

    property Item[Index: Integer]: TAnimatedSprite read GetItem; default;
  end;

implementation

const
  ANIMATED_SPRITE_STREAM_VERSION = 2;
  ANIMATED_SPRITE_LIST_STREAM_VERSION = 1;
  ANIMATED_SPRITE_MAX_TEXTURE_SIZE = 4096;

type
  TAnimatedSpriteTextureCacheEntry = class
  public
    TextureID: GLuint;
    Width: Integer;
    Height: Integer;
    RefCount: Integer;
  end;

var
  GSharedAnimatedSpriteShader: TShader = nil;
  GAnimatedSpriteInstanceCount: Integer = 0;
  GAnimatedSpriteTextureCache: TObjectDictionary<string, TAnimatedSpriteTextureCacheEntry> = nil;

function AnimatedSpriteTextureCache: TObjectDictionary<string, TAnimatedSpriteTextureCacheEntry>;
begin
  if GAnimatedSpriteTextureCache = nil then
    GAnimatedSpriteTextureCache := TObjectDictionary<string, TAnimatedSpriteTextureCacheEntry>.Create([doOwnsValues]);
  Result := GAnimatedSpriteTextureCache;
end;

procedure WriteStringToStream(Stream: TStream; const Value: string);
var
  Len: Integer;
begin
  Len := Length(Value);
  Stream.WriteBuffer(Len, SizeOf(Len));
  if Len > 0 then
    Stream.WriteBuffer(Value[1], Len * SizeOf(Char));
end;

function ReadStringFromStream(Stream: TStream): string;
var
  Len: Integer;
begin
  Stream.ReadBuffer(Len, SizeOf(Len));
  if Len < 0 then
    raise Exception.Create('Invalid string length in animated-sprite stream.');

  SetLength(Result, Len);
  if Len > 0 then
    Stream.ReadBuffer(Result[1], Len * SizeOf(Char));
end;

function ClampSingle(Value, MinValue, MaxValue: Single): Single;
begin
  if Value < MinValue then
    Result := MinValue
  else if Value > MaxValue then
    Result := MaxValue
  else
    Result := Value;
end;

function IsAnimatedSpriteTextureFile(const AFileName: string): Boolean;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(AFileName));
  Result := (Ext = '.tga') or (Ext = '.png') or (Ext = '.dds');
end;

function TryLoadTargaTextureRGBA(const AFileName: string; out Pixels: TBytes;
  out Width, Height: Integer; MaxTextureSize: Integer = 0): Boolean;
var
  Stream: TFileStream;
  Header: array[0..17] of Byte;
  IDLength, ColorMapType, ImageType, BitsPerPixel, Descriptor: Byte;
  BytesPerPixel: Integer;
  SourceWidth, SourceHeight: Integer;
  TargetWidth, TargetHeight: Integer;
  SourcePixelCount, PixelIndex: Integer;
  TopOrigin, RightOrigin: Boolean;
  PacketHeader: Byte;
  RunLength, I: Integer;
  B, G, R, A: Byte;
  CurrentX, CurrentY: Integer;
  XMap, YMap: TArray<Integer>;
  Scale: Double;

  function WordAt(Offset: Integer): Word;
  begin
    Result := Word(Header[Offset]) or (Word(Header[Offset + 1]) shl 8);
  end;

  function ReadPixel(out B, G, R, A: Byte): Boolean;
  var
    FilePixel: array[0..3] of Byte;
  begin
    Result := Stream.Read(FilePixel[0], BytesPerPixel) = BytesPerPixel;
    if not Result then
      Exit;

    B := FilePixel[0];
    G := FilePixel[1];
    R := FilePixel[2];
    if BytesPerPixel = 4 then
      A := FilePixel[3]
    else
      A := 255;
  end;

  procedure AdvanceSourcePixel;
  begin
    Inc(CurrentX);
    if CurrentX >= SourceWidth then
    begin
      CurrentX := 0;
      Inc(CurrentY);
    end;
  end;

  procedure StorePixel(B, G, R, A: Byte);
  var
    SourceX, SourceY, TargetX, TargetY, DestIndex: Integer;
  begin
    if CurrentY >= SourceHeight then
      Exit;

    if RightOrigin then
      SourceX := SourceWidth - 1 - CurrentX
    else
      SourceX := CurrentX;

    if TopOrigin then
      SourceY := CurrentY
    else
      SourceY := SourceHeight - 1 - CurrentY;

    TargetX := XMap[SourceX];
    TargetY := YMap[SourceY];
    DestIndex := (TargetY * TargetWidth + TargetX) * 4;
    Pixels[DestIndex + 0] := R;
    Pixels[DestIndex + 1] := G;
    Pixels[DestIndex + 2] := B;
    Pixels[DestIndex + 3] := A;
  end;

begin
  Result := False;
  Pixels := nil;
  Width := 0;
  Height := 0;

  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    if Stream.Read(Header[0], SizeOf(Header)) <> SizeOf(Header) then
      Exit;

    IDLength := Header[0];
    ColorMapType := Header[1];
    ImageType := Header[2];
    SourceWidth := WordAt(12);
    SourceHeight := WordAt(14);
    BitsPerPixel := Header[16];
    Descriptor := Header[17];

    if (ColorMapType <> 0) or not (ImageType in [2, 10]) or
       not (BitsPerPixel in [24, 32]) or (SourceWidth <= 0) or
       (SourceHeight <= 0) or (SourceWidth > MaxInt div SourceHeight) then
      Exit;

    SourcePixelCount := SourceWidth * SourceHeight;
    if SourcePixelCount > MaxInt div 4 then
      Exit;

    TargetWidth := SourceWidth;
    TargetHeight := SourceHeight;
    if (MaxTextureSize > 0) and
       (System.Math.Max(SourceWidth, SourceHeight) > MaxTextureSize) then
    begin
      Scale := MaxTextureSize / System.Math.Max(SourceWidth, SourceHeight);
      TargetWidth := System.Math.Max(1, Round(SourceWidth * Scale));
      TargetHeight := System.Math.Max(1, Round(SourceHeight * Scale));
    end;

    SetLength(XMap, SourceWidth);
    for I := 0 to SourceWidth - 1 do
      XMap[I] := Integer((Int64(I) * TargetWidth) div SourceWidth);

    SetLength(YMap, SourceHeight);
    for I := 0 to SourceHeight - 1 do
      YMap[I] := Integer((Int64(I) * TargetHeight) div SourceHeight);

    BytesPerPixel := BitsPerPixel div 8;
    TopOrigin := (Descriptor and $20) <> 0;
    RightOrigin := (Descriptor and $10) <> 0;
    SetLength(Pixels, TargetWidth * TargetHeight * 4);

    if Stream.Size < SizeOf(Header) + IDLength then
      Exit;
    Stream.Position := SizeOf(Header) + IDLength;

    PixelIndex := 0;
    CurrentX := 0;
    CurrentY := 0;
    if ImageType = 2 then
    begin
      while PixelIndex < SourcePixelCount do
      begin
        if not ReadPixel(B, G, R, A) then
          Exit;
        StorePixel(B, G, R, A);
        AdvanceSourcePixel;
        Inc(PixelIndex);
      end;
    end
    else
    begin
      while PixelIndex < SourcePixelCount do
      begin
        if Stream.Read(PacketHeader, SizeOf(PacketHeader)) <> SizeOf(PacketHeader) then
          Exit;

        RunLength := (PacketHeader and $7F) + 1;
        if (PacketHeader and $80) <> 0 then
        begin
          if not ReadPixel(B, G, R, A) then
            Exit;

          for I := 0 to RunLength - 1 do
          begin
            if PixelIndex >= SourcePixelCount then
              Exit;
            StorePixel(B, G, R, A);
            AdvanceSourcePixel;
            Inc(PixelIndex);
          end;
        end
        else
        begin
          for I := 0 to RunLength - 1 do
          begin
            if PixelIndex >= SourcePixelCount then
              Exit;
            if not ReadPixel(B, G, R, A) then
              Exit;
            StorePixel(B, G, R, A);
            AdvanceSourcePixel;
            Inc(PixelIndex);
          end;
        end;
      end;
    end;

    Width := TargetWidth;
    Height := TargetHeight;
    Result := PixelIndex = SourcePixelCount;
  finally
    if not Result then
    begin
      Pixels := nil;
      Width := 0;
      Height := 0;
    end;
    Stream.Free;
  end;
end;

function BuildAnimatedSpriteTextureCacheKey(const AFileName: string): string;
var
  SearchRec: TSearchRec;
begin
  Result := LowerCase(ExpandFileName(AFileName));
  if FindFirst(AFileName, faAnyFile, SearchRec) = 0 then
  try
    Result := Result + '|' + IntToStr(SearchRec.Size) + '|' +
      FloatToStr(SearchRec.TimeStamp);
  finally
    FindClose(SearchRec);
  end;
end;

procedure DownsampleAnimatedSpritePixelsIfNeeded(var Pixels: TBytes; var Width,
  Height: Integer);
var
  MaxDimension: Integer;
  NewWidth, NewHeight: Integer;
  NewPixels: TBytes;
  Scale: Double;
  X, Y: Integer;
  SourceX, SourceY: Integer;
  SourceIndex, DestIndex: Integer;
begin
  MaxDimension := System.Math.Max(Width, Height);
  if (MaxDimension <= ANIMATED_SPRITE_MAX_TEXTURE_SIZE) or (MaxDimension <= 0) then
    Exit;

  Scale := ANIMATED_SPRITE_MAX_TEXTURE_SIZE / MaxDimension;
  NewWidth := System.Math.Max(1, Round(Width * Scale));
  NewHeight := System.Math.Max(1, Round(Height * Scale));
  SetLength(NewPixels, NewWidth * NewHeight * 4);

  for Y := 0 to NewHeight - 1 do
  begin
    SourceY := Integer((Int64(Y) * Height) div NewHeight);
    for X := 0 to NewWidth - 1 do
    begin
      SourceX := Integer((Int64(X) * Width) div NewWidth);
      SourceIndex := (SourceY * Width + SourceX) * 4;
      DestIndex := (Y * NewWidth + X) * 4;
      Move(Pixels[SourceIndex], NewPixels[DestIndex], 4);
    end;
  end;

  Pixels := NewPixels;
  Width := NewWidth;
  Height := NewHeight;
end;

function TryCreateAnimatedSpriteTextureFromFile(const AFileName: string;
  out TextureID: GLuint; out TextureWidth, TextureHeight: Integer): Boolean;
var
  Graphic: TGraphic;
  Bitmap: TBitmap;
  Png: TPngImage;
  RGBLine: pRGBLine;
  AlphaLine: pByteArray;
  Ext: string;
  Data: TBytes;
  RowSize: Integer;
  X, Y, I, SourceY: Integer;
  ColorValue: TColor;
  AlphaOffset: Integer;
  HasNonZeroAlpha: Boolean;
  SupportsDirectPngCopy: Boolean;
begin
  Result := False;
  TextureID := 0;
  TextureWidth := 0;
  TextureHeight := 0;
  Ext := LowerCase(ExtractFileExt(AFileName));
  Graphic := nil;
  Bitmap := nil;
  Png := nil;
  try
    if Ext = '.dds' then
    begin
      Result := LoadDDS2DTexture(AFileName, True, GL_RGBA8, GL_CLAMP_TO_EDGE,
        False, TextureID, TextureWidth, TextureHeight);
      Exit;
    end
    else if Ext = '.tga' then
    begin
      if not TryLoadTargaTextureRGBA(AFileName, Data, TextureWidth,
        TextureHeight, ANIMATED_SPRITE_MAX_TEXTURE_SIZE) then
        Exit;
    end
    else if Ext = '.png' then
    begin
      Png := TPngImage.Create;
      Png.LoadFromFile(AFileName);
      SupportsDirectPngCopy := (Png.Header.BitDepth = 8) and
        (Png.Header.ColorType in [COLOR_RGB, COLOR_RGBALPHA]);

      if SupportsDirectPngCopy then
      begin
        TextureWidth := Png.Width;
        TextureHeight := Png.Height;
        SetLength(Data, TextureWidth * TextureHeight * 4);

        for Y := 0 to TextureHeight - 1 do
        begin
          SourceY := TextureHeight - 1 - Y;
          RGBLine := pRGBLine(Png.Scanline[SourceY]);
          if Png.Header.ColorType = COLOR_RGBALPHA then
            AlphaLine := Png.AlphaScanline[SourceY]
          else
            AlphaLine := nil;

          for X := 0 to TextureWidth - 1 do
          begin
            I := (Y * TextureWidth + X) * 4;
            Data[I + 0] := RGBLine^[X].rgbtRed;
            Data[I + 1] := RGBLine^[X].rgbtGreen;
            Data[I + 2] := RGBLine^[X].rgbtBlue;
            if AlphaLine <> nil then
              Data[I + 3] := AlphaLine^[X]
            else
              Data[I + 3] := 255;
          end;
        end;
      end
      else
      begin
        Graphic := TGraphicClass(TPNGGraphic).Create;
        Graphic.LoadFromFile(AFileName);
        Bitmap := TBitmap.Create;
        Bitmap.PixelFormat := pf32bit;
        Bitmap.SetSize(Graphic.Width, Graphic.Height);
        Bitmap.Canvas.Brush.Color := clBlack;
        Bitmap.Canvas.FillRect(Rect(0, 0, Graphic.Width, Graphic.Height));
        Bitmap.Canvas.Draw(0, 0, Graphic);

        TextureWidth := Bitmap.Width;
        TextureHeight := Bitmap.Height;
        RowSize := Bitmap.Width * 4;
        SetLength(Data, RowSize * Bitmap.Height);
        for Y := 0 to Bitmap.Height - 1 do
          for X := 0 to Bitmap.Width - 1 do
          begin
            ColorValue := ColorToRGB(Bitmap.Canvas.Pixels[X, Bitmap.Height - 1 - Y]);
            I := (Y * Bitmap.Width + X) * 4;
            Data[I + 0] := Byte(ColorValue and $FF);
            Data[I + 1] := Byte((ColorValue shr 8) and $FF);
            Data[I + 2] := Byte((ColorValue shr 16) and $FF);
            Data[I + 3] := 255;
          end;
      end;

      DownsampleAnimatedSpritePixelsIfNeeded(Data, TextureWidth, TextureHeight);
    end
    else
      Exit;

    if (TextureWidth <= 0) or (TextureHeight <= 0) or (Length(Data) < 4) then
      Exit;

    HasNonZeroAlpha := False;
    for I := 0 to (Length(Data) div 4) - 1 do
    begin
      AlphaOffset := I * 4 + 3;
      if Data[AlphaOffset] <> 0 then
      begin
        HasNonZeroAlpha := True;
        Break;
      end;
    end;

    if not HasNonZeroAlpha then
      for I := 0 to (Length(Data) div 4) - 1 do
        Data[I * 4 + 3] := 255;

    glGenTextures(1, @TextureID);
    glBindTexture(GL_TEXTURE_2D, TextureID);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, TextureWidth, TextureHeight, 0,
      GL_RGBA, GL_UNSIGNED_BYTE, @Data[0]);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);

    Result := TextureID <> 0;
  finally
    Png.Free;
    Bitmap.Free;
    Graphic.Free;
  end;
end;

function TryAcquireAnimatedSpriteTexture(const AFileName: string;
  out TextureID: GLuint; out TextureWidth, TextureHeight: Integer;
  out TextureKey: string): Boolean;
var
  Cache: TObjectDictionary<string, TAnimatedSpriteTextureCacheEntry>;
  Entry: TAnimatedSpriteTextureCacheEntry;
begin
  Result := False;
  TextureID := 0;
  TextureWidth := 0;
  TextureHeight := 0;
  TextureKey := BuildAnimatedSpriteTextureCacheKey(AFileName);
  Cache := AnimatedSpriteTextureCache;
  if Cache.TryGetValue(TextureKey, Entry) then
  begin
    Inc(Entry.RefCount);
    TextureID := Entry.TextureID;
    TextureWidth := Entry.Width;
    TextureHeight := Entry.Height;
    Exit(True);
  end;

  if not TryCreateAnimatedSpriteTextureFromFile(AFileName, TextureID,
    TextureWidth, TextureHeight) then
    Exit;

  Entry := TAnimatedSpriteTextureCacheEntry.Create;
  Entry.TextureID := TextureID;
  Entry.Width := TextureWidth;
  Entry.Height := TextureHeight;
  Entry.RefCount := 1;
  Cache.Add(TextureKey, Entry);
  Result := True;
end;

{ TAnimatedSprite }

constructor TAnimatedSprite.Create;
begin
  inherited Create;

  FName := 'AnimatedSprite';
  FEnabled := True;
  FWidth := 1.0;
  FHeight := 1.0;
  FOffset := Vector3(0, 0, 0);
  FRotation := 0.0;
  FColor := Vector4(1, 1, 1, 1);
  FBlendMode := asAlpha;
  FAlphaCutoff := 0.05;
  FFrameRate := 12.0;
  FLoop := True;
  FPlaying := True;
  FCurrentFrameIndex := 0;
  FFrameTimer := 0.0;
  FTexturePath := '';
  FGridColumns := 16;
  FGridRows := 16;
  FFirstFrame := 0;
  FFrameCount := FGridColumns * FGridRows;

  FVAO := 0;
  FVBO := 0;
  FTextureID := 0;
  FTextureWidth := 0;
  FTextureHeight := 0;
  FTextureKey := '';
  FTextureDirty := True;
  FShader := nil;
  Inc(GAnimatedSpriteInstanceCount);
end;

destructor TAnimatedSprite.Destroy;
begin
  DestroyBuffers;
  DestroyTexture;
  DestroyShader;
  Dec(GAnimatedSpriteInstanceCount);
  if GAnimatedSpriteInstanceCount <= 0 then
  begin
    GAnimatedSpriteInstanceCount := 0;
    FreeAndNil(GSharedAnimatedSpriteShader);
    FreeAndNil(GAnimatedSpriteTextureCache);
  end;
  inherited Destroy;
end;

procedure TAnimatedSprite.Assign(Source: TAnimatedSprite);
begin
  if Source = nil then
    Exit;

  FEnabled := Source.FEnabled;
  FName := Source.FName;
  FWidth := Source.FWidth;
  FHeight := Source.FHeight;
  FOffset := Source.FOffset;
  FRotation := Source.FRotation;
  FColor := Source.FColor;
  FBlendMode := Source.FBlendMode;
  FAlphaCutoff := Source.FAlphaCutoff;
  FFrameRate := Source.FFrameRate;
  FLoop := Source.FLoop;
  FPlaying := Source.FPlaying;
  FCurrentFrameIndex := Source.FCurrentFrameIndex;
  FFrameTimer := Source.FFrameTimer;
  FTexturePath := Source.FTexturePath;
  FGridColumns := Source.FGridColumns;
  FGridRows := Source.FGridRows;
  FFirstFrame := Source.FFirstFrame;
  FFrameCount := Source.FFrameCount;
  NormalizeFrameRange;
  MarkTextureDirty;
end;

function TAnimatedSprite.Clone: TAnimatedSprite;
begin
  Result := TAnimatedSprite.Create;
  Result.Assign(Self);
end;

function TAnimatedSprite.GetFrameCount: Integer;
begin
  Result := FFrameCount;
end;

function TAnimatedSprite.GetGridFrameCapacity: Integer;
begin
  Result := Max(1, FGridColumns) * Max(1, FGridRows);
end;

function TAnimatedSprite.GetCurrentSheetFrameIndex: Integer;
begin
  Result := EnsureRange(FFirstFrame + FCurrentFrameIndex, 0,
    Max(0, GetGridFrameCapacity - 1));
end;

procedure TAnimatedSprite.SetWidth(const Value: Single);
begin
  FWidth := Max(0.001, Value);
end;

procedure TAnimatedSprite.SetHeight(const Value: Single);
begin
  FHeight := Max(0.001, Value);
end;

procedure TAnimatedSprite.SetAlphaCutoff(const Value: Single);
begin
  FAlphaCutoff := ClampSingle(Value, 0.0, 1.0);
end;

procedure TAnimatedSprite.SetFrameRate(const Value: Single);
begin
  FFrameRate := ClampSingle(Value, 0.001, 240.0);
end;

procedure TAnimatedSprite.SetCurrentFrameIndex(const Value: Integer);
var
  NewIndex: Integer;
begin
  NewIndex := EnsureRange(Value, 0, Max(0, FFrameCount - 1));

  if FCurrentFrameIndex = NewIndex then
    Exit;

  FCurrentFrameIndex := NewIndex;
end;

procedure TAnimatedSprite.SetTexturePath(const Value: string);
var
  StoredPath: string;
begin
  StoredPath := TEnginePaths.ToAssetRelativePath(Trim(Value));
  if SameText(FTexturePath, StoredPath) then
    Exit;

  FTexturePath := StoredPath;
  MarkTextureDirty;
end;

procedure TAnimatedSprite.SetGridColumns(const Value: Integer);
begin
  FGridColumns := EnsureRange(Value, 1, 1024);
  NormalizeFrameRange;
end;

procedure TAnimatedSprite.SetGridRows(const Value: Integer);
begin
  FGridRows := EnsureRange(Value, 1, 1024);
  NormalizeFrameRange;
end;

procedure TAnimatedSprite.SetFirstFrame(const Value: Integer);
begin
  FFirstFrame := EnsureRange(Value, 0, Max(0, GetGridFrameCapacity - 1));
  NormalizeFrameRange;
end;

procedure TAnimatedSprite.SetFrameCount(const Value: Integer);
begin
  FFrameCount := EnsureRange(Value, 1, Max(1, GetGridFrameCapacity - FFirstFrame));
  NormalizeFrameRange;
end;

procedure TAnimatedSprite.NormalizeFrameRange;
var
  Capacity: Integer;
begin
  FGridColumns := EnsureRange(FGridColumns, 1, 1024);
  FGridRows := EnsureRange(FGridRows, 1, 1024);
  Capacity := GetGridFrameCapacity;
  FFirstFrame := EnsureRange(FFirstFrame, 0, Max(0, Capacity - 1));
  FFrameCount := EnsureRange(FFrameCount, 1, Max(1, Capacity - FFirstFrame));
  FCurrentFrameIndex := EnsureRange(FCurrentFrameIndex, 0,
    Max(0, FFrameCount - 1));
end;

function TAnimatedSprite.LoadTexture(const APath: string): Boolean;
begin
  Result := IsAnimatedSpriteTextureFile(APath);
  if not Result then
    Exit;

  TexturePath := APath;
  Restart;
end;

procedure TAnimatedSprite.Restart;
begin
  FFrameTimer := 0.0;
  FPlaying := True;
  SetCurrentFrameIndex(0);
end;

procedure TAnimatedSprite.Update(DeltaTime: Single);
var
  FrameDuration: Single;
  NewIndex: Integer;
begin
  if (not FEnabled) or (not FPlaying) or (FFrameCount <= 1) then
    Exit;

  DeltaTime := Max(0.0, DeltaTime);
  if DeltaTime <= 0.0 then
    Exit;

  FrameDuration := 1.0 / Max(0.001, FFrameRate);
  FFrameTimer := FFrameTimer + DeltaTime;
  while FFrameTimer >= FrameDuration do
  begin
    FFrameTimer := FFrameTimer - FrameDuration;
    NewIndex := FCurrentFrameIndex + 1;
    if NewIndex >= FFrameCount then
    begin
      if FLoop then
        NewIndex := 0
      else
      begin
        NewIndex := FFrameCount - 1;
        FPlaying := False;
      end;
    end;
    SetCurrentFrameIndex(NewIndex);
    if not FPlaying then
      Break;
  end;
end;

procedure TAnimatedSprite.MarkTextureDirty;
begin
  FTextureDirty := True;
end;

procedure TAnimatedSprite.EnsureBuffers;
begin
  if FVAO <> 0 then
    Exit;

  glGenVertexArrays(1, @FVAO);
  glBindVertexArray(FVAO);

  glGenBuffers(1, @FVBO);
  glBindBuffer(GL_ARRAY_BUFFER, FVBO);
  glBufferData(GL_ARRAY_BUFFER, 0, nil, GL_DYNAMIC_DRAW);

  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, SizeOf(TAnimatedSpriteVertex), nil);

  glEnableVertexAttribArray(1);
  glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, SizeOf(TAnimatedSpriteVertex),
    Pointer(NativeUInt(SizeOf(TVector3))));

  glEnableVertexAttribArray(2);
  glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, SizeOf(TAnimatedSpriteVertex),
    Pointer(NativeUInt(SizeOf(TVector3) + SizeOf(TVector4))));

  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glBindVertexArray(0);
end;

procedure TAnimatedSprite.EnsureShader;
begin
  if FShader = nil then
  begin
    if GSharedAnimatedSpriteShader = nil then
      GSharedAnimatedSpriteShader := TShader.Create(
        TEnginePaths.Shader('Billboard.vert'),
        TEnginePaths.Shader('Billboard.frag'));
    FShader := GSharedAnimatedSpriteShader;
  end;
end;

procedure TAnimatedSprite.EnsureTexture;
var
  TextureFileName: string;
begin
  if Trim(FTexturePath) = '' then
  begin
    DestroyTexture;
    FTextureDirty := False;
    Exit;
  end;

  if (FTextureID <> 0) and (not FTextureDirty) then
    Exit;

  DestroyTexture;
  TextureFileName := TEnginePaths.ResolveAssetPath(FTexturePath);
  if (TextureFileName = '') or (not FileExists(TextureFileName)) then
  begin
    FTextureDirty := False;
    Exit;
  end;

  if not TryAcquireAnimatedSpriteTexture(TextureFileName, FTextureID,
    FTextureWidth, FTextureHeight, FTextureKey) then
  begin
    FTextureDirty := False;
    FTextureKey := '';
    Exit;
  end;

  FTextureDirty := False;
end;

procedure TAnimatedSprite.DestroyBuffers;
begin
  if FVBO <> 0 then
  begin
    glDeleteBuffers(1, @FVBO);
    FVBO := 0;
  end;

  if FVAO <> 0 then
  begin
    glDeleteVertexArrays(1, @FVAO);
    FVAO := 0;
  end;
end;

procedure TAnimatedSprite.DestroyTexture;
var
  Entry: TAnimatedSpriteTextureCacheEntry;
  TextureID: GLuint;
  ReleasedFromCache: Boolean;
begin
  if FTextureID <> 0 then
  begin
    ReleasedFromCache := False;
    if (FTextureKey <> '') and Assigned(GAnimatedSpriteTextureCache) and
       GAnimatedSpriteTextureCache.TryGetValue(FTextureKey, Entry) then
    begin
      Dec(Entry.RefCount);
      if Entry.RefCount <= 0 then
      begin
        TextureID := Entry.TextureID;
        if TextureID <> 0 then
          glDeleteTextures(1, @TextureID);
        GAnimatedSpriteTextureCache.Remove(FTextureKey);
      end;
      ReleasedFromCache := True;
    end;

    if not ReleasedFromCache then
    begin
      TextureID := FTextureID;
      glDeleteTextures(1, @TextureID);
    end;
  end;

  FTextureID := 0;
  FTextureWidth := 0;
  FTextureHeight := 0;
  FTextureKey := '';
end;

procedure TAnimatedSprite.DestroyShader;
begin
  FShader := nil;
end;

procedure TAnimatedSprite.Render(const ViewProjection: TMatrix4;
  const OwnerWorldMatrix: TMatrix4; const CameraRight, CameraUp: TVector3);
var
  Vertices: array[0..5] of TAnimatedSpriteVertex;
  WorldPosition: TVector3;
  OwnerScaleX, OwnerScaleY: Single;
  Right, Up, RotRight, RotUp: TVector3;
  Corners: array[0..3] of TVector3;
  RenderWidth, RenderHeight: Single;
  HalfWidth, HalfHeight, S, C: Single;
  SheetFrame, FrameX, FrameY: Integer;
  U0, V0, U1, V1: Single;
  Tex: array[0..5] of TVector2;
  OldDepthMask, OldBlendEnabled, OldCullEnabled, OldDepthTestEnabled: GLboolean;
  OldSrcRGB, OldDstRGB, OldSrcAlpha, OldDstAlpha: GLint;
begin
  if (not FEnabled) or (FColor.W <= 0.001) then
    Exit;

  EnsureShader;
  EnsureBuffers;
  EnsureTexture;

  WorldPosition := Vector3(OwnerWorldMatrix * Vector4(FOffset, 1.0));
  OwnerScaleX := Max(Vector3(OwnerWorldMatrix.Columns[0]).Length, 0.001);
  OwnerScaleY := Max(Vector3(OwnerWorldMatrix.Columns[1]).Length, 0.001);
  RenderWidth := FWidth * OwnerScaleX;
  RenderHeight := FHeight * OwnerScaleY;
  HalfWidth := RenderWidth * 0.5;
  HalfHeight := RenderHeight * 0.5;

  Right := CameraRight.Normalize * HalfWidth;
  Up := CameraUp.Normalize * HalfHeight;
  S := Sin(FRotation);
  C := Cos(FRotation);
  RotRight := Right * C + Up * S;
  RotUp := Up * C - Right * S;

  Corners[0] := WorldPosition - RotRight - RotUp;
  Corners[1] := WorldPosition + RotRight - RotUp;
  Corners[2] := WorldPosition + RotRight + RotUp;
  Corners[3] := WorldPosition - RotRight + RotUp;

  SheetFrame := GetCurrentSheetFrameIndex;
  FrameX := SheetFrame mod FGridColumns;
  FrameY := SheetFrame div FGridColumns;
  U0 := FrameX / FGridColumns;
  U1 := (FrameX + 1) / FGridColumns;
  V1 := 1.0 - (FrameY / FGridRows);
  V0 := 1.0 - ((FrameY + 1) / FGridRows);

  Tex[0] := Vector2(U0, V0);
  Tex[1] := Vector2(U1, V0);
  Tex[2] := Vector2(U1, V1);
  Tex[3] := Vector2(U0, V0);
  Tex[4] := Vector2(U1, V1);
  Tex[5] := Vector2(U0, V1);

  Vertices[0].Position := Corners[0]; Vertices[0].Color := FColor; Vertices[0].TexCoord := Tex[0];
  Vertices[1].Position := Corners[1]; Vertices[1].Color := FColor; Vertices[1].TexCoord := Tex[1];
  Vertices[2].Position := Corners[2]; Vertices[2].Color := FColor; Vertices[2].TexCoord := Tex[2];
  Vertices[3].Position := Corners[0]; Vertices[3].Color := FColor; Vertices[3].TexCoord := Tex[3];
  Vertices[4].Position := Corners[2]; Vertices[4].Color := FColor; Vertices[4].TexCoord := Tex[4];
  Vertices[5].Position := Corners[3]; Vertices[5].Color := FColor; Vertices[5].TexCoord := Tex[5];

  OldDepthTestEnabled := glIsEnabled(GL_DEPTH_TEST);
  OldBlendEnabled := glIsEnabled(GL_BLEND);
  OldCullEnabled := glIsEnabled(GL_CULL_FACE);
  glGetBooleanv(GL_DEPTH_WRITEMASK, @OldDepthMask);
  glGetIntegerv(GL_BLEND_SRC_RGB, @OldSrcRGB);
  glGetIntegerv(GL_BLEND_DST_RGB, @OldDstRGB);
  glGetIntegerv(GL_BLEND_SRC_ALPHA, @OldSrcAlpha);
  glGetIntegerv(GL_BLEND_DST_ALPHA, @OldDstAlpha);

  glEnable(GL_DEPTH_TEST);
  glDepthMask(GL_FALSE);
  glDisable(GL_CULL_FACE);
  glEnable(GL_BLEND);
  case FBlendMode of
    asAdditive: glBlendFunc(GL_SRC_ALPHA, GL_ONE);
  else
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  end;

  FShader.Use;
  FShader.SetUniform('viewProjection', ViewProjection);
  FShader.SetUniform('alphaCutoff', FAlphaCutoff);
  if FTextureID <> 0 then
  begin
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, FTextureID);
    FShader.SetUniform('billboardTexture', 0);
    FShader.SetUniform('useTexture', 1);
  end
  else
    FShader.SetUniform('useTexture', 0);

  glBindVertexArray(FVAO);
  glBindBuffer(GL_ARRAY_BUFFER, FVBO);
  glBufferData(GL_ARRAY_BUFFER, SizeOf(Vertices), @Vertices[0], GL_DYNAMIC_DRAW);
  glDrawArrays(GL_TRIANGLES, 0, Length(Vertices));
  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glBindVertexArray(0);
  glBindTexture(GL_TEXTURE_2D, 0);

  glBlendFuncSeparate(OldSrcRGB, OldDstRGB, OldSrcAlpha, OldDstAlpha);
  glDepthMask(OldDepthMask);
  if OldDepthTestEnabled = GL_TRUE then glEnable(GL_DEPTH_TEST) else glDisable(GL_DEPTH_TEST);
  if OldBlendEnabled = GL_TRUE then glEnable(GL_BLEND) else glDisable(GL_BLEND);
  if OldCullEnabled = GL_TRUE then glEnable(GL_CULL_FACE) else glDisable(GL_CULL_FACE);
end;

procedure TAnimatedSprite.SaveToStream(Stream: TStream);
var
  Version: Integer;
  BlendValue: Integer;
begin
  Version := ANIMATED_SPRITE_STREAM_VERSION;
  Stream.WriteBuffer(Version, SizeOf(Version));
  WriteStringToStream(Stream, FName);
  Stream.WriteBuffer(FEnabled, SizeOf(FEnabled));
  Stream.WriteBuffer(FWidth, SizeOf(FWidth));
  Stream.WriteBuffer(FHeight, SizeOf(FHeight));
  Stream.WriteBuffer(FOffset, SizeOf(FOffset));
  Stream.WriteBuffer(FRotation, SizeOf(FRotation));
  Stream.WriteBuffer(FColor, SizeOf(FColor));
  BlendValue := Ord(FBlendMode);
  Stream.WriteBuffer(BlendValue, SizeOf(BlendValue));
  Stream.WriteBuffer(FAlphaCutoff, SizeOf(FAlphaCutoff));
  Stream.WriteBuffer(FFrameRate, SizeOf(FFrameRate));
  Stream.WriteBuffer(FLoop, SizeOf(FLoop));
  Stream.WriteBuffer(FPlaying, SizeOf(FPlaying));
  Stream.WriteBuffer(FCurrentFrameIndex, SizeOf(FCurrentFrameIndex));
  WriteStringToStream(Stream, FTexturePath);
  Stream.WriteBuffer(FGridColumns, SizeOf(FGridColumns));
  Stream.WriteBuffer(FGridRows, SizeOf(FGridRows));
  Stream.WriteBuffer(FFirstFrame, SizeOf(FFirstFrame));
  Stream.WriteBuffer(FFrameCount, SizeOf(FFrameCount));
end;

procedure TAnimatedSprite.LoadFromStream(Stream: TStream);
var
  Version: Integer;
  BlendValue: Integer;
  FrameCountValue: Integer;
  I: Integer;
  LegacyFramePath: string;
begin
  Stream.ReadBuffer(Version, SizeOf(Version));
  if (Version < 1) or (Version > ANIMATED_SPRITE_STREAM_VERSION) then
    raise Exception.CreateFmt('Unsupported animated-sprite version: %d.', [Version]);

  FName := ReadStringFromStream(Stream);
  Stream.ReadBuffer(FEnabled, SizeOf(FEnabled));
  Stream.ReadBuffer(FWidth, SizeOf(FWidth));
  Stream.ReadBuffer(FHeight, SizeOf(FHeight));
  Stream.ReadBuffer(FOffset, SizeOf(FOffset));
  Stream.ReadBuffer(FRotation, SizeOf(FRotation));
  Stream.ReadBuffer(FColor, SizeOf(FColor));
  Stream.ReadBuffer(BlendValue, SizeOf(BlendValue));
  FBlendMode := TAnimatedSpriteBlendMode(EnsureRange(BlendValue,
    Ord(Low(TAnimatedSpriteBlendMode)), Ord(High(TAnimatedSpriteBlendMode))));
  Stream.ReadBuffer(FAlphaCutoff, SizeOf(FAlphaCutoff));
  Stream.ReadBuffer(FFrameRate, SizeOf(FFrameRate));
  Stream.ReadBuffer(FLoop, SizeOf(FLoop));
  Stream.ReadBuffer(FPlaying, SizeOf(FPlaying));
  Stream.ReadBuffer(FCurrentFrameIndex, SizeOf(FCurrentFrameIndex));

  if Version >= 2 then
  begin
    FTexturePath := ReadStringFromStream(Stream);
    Stream.ReadBuffer(FGridColumns, SizeOf(FGridColumns));
    Stream.ReadBuffer(FGridRows, SizeOf(FGridRows));
    Stream.ReadBuffer(FFirstFrame, SizeOf(FFirstFrame));
    Stream.ReadBuffer(FFrameCount, SizeOf(FFrameCount));
  end
  else
  begin
    Stream.ReadBuffer(FrameCountValue, SizeOf(FrameCountValue));
    if (FrameCountValue < 0) or (FrameCountValue > 100000) then
      raise Exception.Create('Invalid animated-sprite frame count in scene stream.');

    FTexturePath := '';
    for I := 0 to FrameCountValue - 1 do
    begin
      LegacyFramePath := ReadStringFromStream(Stream);
      if (LegacyFramePath <> '') and
         ((FTexturePath = '') or (I = FCurrentFrameIndex)) then
        FTexturePath := LegacyFramePath;
    end;

    FGridColumns := 1;
    FGridRows := 1;
    FFirstFrame := 0;
    FFrameCount := 1;
    FCurrentFrameIndex := 0;
  end;

  FWidth := ClampSingle(FWidth, 0.001, 100000.0);
  FHeight := ClampSingle(FHeight, 0.001, 100000.0);
  FAlphaCutoff := ClampSingle(FAlphaCutoff, 0.0, 1.0);
  FFrameRate := ClampSingle(FFrameRate, 0.001, 240.0);
  FColor.X := ClampSingle(FColor.X, 0.0, 1000.0);
  FColor.Y := ClampSingle(FColor.Y, 0.0, 1000.0);
  FColor.Z := ClampSingle(FColor.Z, 0.0, 1000.0);
  FColor.W := ClampSingle(FColor.W, 0.0, 1.0);
  NormalizeFrameRange;
  FFrameTimer := 0.0;
  MarkTextureDirty;
end;

{ TAnimatedSpriteList }

function TAnimatedSpriteList.GetItem(AIndex: Integer): TAnimatedSprite;
begin
  if (AIndex >= 0) and (AIndex < Count) then
    Result := Items[AIndex]
  else
    Result := nil;
end;

function TAnimatedSpriteList.AddAnimatedSpriteToList(
  AAnimatedSprite: TAnimatedSprite): Integer;
begin
  if AAnimatedSprite = nil then
    Exit(-1);

  if Trim(AAnimatedSprite.Name) = '' then
    AAnimatedSprite.Name := GenerateUniqueName
  else if not NameIsUnique(AAnimatedSprite.Name) then
    AAnimatedSprite.Name := GenerateUniqueName;

  Result := inherited Add(AAnimatedSprite);
end;

function TAnimatedSpriteList.CreateAnimatedSprite: TAnimatedSprite;
begin
  Result := TAnimatedSprite.Create;
  AddAnimatedSpriteToList(Result);
end;

function TAnimatedSpriteList.NameIsUnique(const AName: string): Boolean;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if SameText(Items[I].Name, AName) then
      Exit(False);
  Result := True;
end;

function TAnimatedSpriteList.GenerateUniqueName: string;
var
  Counter: Integer;
begin
  Counter := 1;
  repeat
    Result := 'AnimatedSprite_' + Counter.ToString;
    Inc(Counter);
  until NameIsUnique(Result);
end;

function TAnimatedSpriteList.DeleteAnimatedSprite(AIndex: Integer): Boolean;
begin
  if (AIndex < 0) or (AIndex >= Count) then
    Exit(False);
  Delete(AIndex);
  Result := True;
end;

function TAnimatedSpriteList.DeleteAnimatedSprite(
  AAnimatedSprite: TAnimatedSprite): Boolean;
var
  Index: Integer;
begin
  Index := IndexOf(AAnimatedSprite);
  Result := DeleteAnimatedSprite(Index);
end;

function TAnimatedSpriteList.Clone: TAnimatedSpriteList;
var
  I: Integer;
begin
  Result := TAnimatedSpriteList.Create;
  for I := 0 to Count - 1 do
    if Items[I] <> nil then
      Result.AddAnimatedSpriteToList(Items[I].Clone);
end;

procedure TAnimatedSpriteList.Update(DeltaTime: Single);
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if Items[I] <> nil then
      Items[I].Update(DeltaTime);
end;

procedure TAnimatedSpriteList.SaveToStream(Stream: TStream);
var
  I: Integer;
  Version: Integer;
  AnimatedSpriteCount: Integer;
begin
  Version := ANIMATED_SPRITE_LIST_STREAM_VERSION;
  Stream.WriteBuffer(Version, SizeOf(Version));
  AnimatedSpriteCount := Count;
  Stream.WriteBuffer(AnimatedSpriteCount, SizeOf(AnimatedSpriteCount));
  for I := 0 to AnimatedSpriteCount - 1 do
    Items[I].SaveToStream(Stream);
end;

procedure TAnimatedSpriteList.LoadFromStream(Stream: TStream);
var
  I: Integer;
  Version: Integer;
  AnimatedSpriteCount: Integer;
  AnimatedSprite: TAnimatedSprite;
begin
  Clear;
  Stream.ReadBuffer(Version, SizeOf(Version));
  if (Version < 1) or (Version > ANIMATED_SPRITE_LIST_STREAM_VERSION) then
    raise Exception.CreateFmt('Unsupported animated-sprite-list version: %d.',
      [Version]);

  Stream.ReadBuffer(AnimatedSpriteCount, SizeOf(AnimatedSpriteCount));
  if (AnimatedSpriteCount < 0) or (AnimatedSpriteCount > 100000) then
    raise Exception.Create('Invalid animated-sprite-list count in scene stream.');

  for I := 0 to AnimatedSpriteCount - 1 do
  begin
    AnimatedSprite := TAnimatedSprite.Create;
    try
      AnimatedSprite.LoadFromStream(Stream);
      AddAnimatedSpriteToList(AnimatedSprite);
    except
      AnimatedSprite.Free;
      raise;
    end;
  end;
end;

end.
