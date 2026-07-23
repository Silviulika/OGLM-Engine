unit Renderer.Billboards;

interface

uses
  System.SysUtils, System.Classes, System.Math, System.Types,
  System.Generics.Collections,
  Vcl.Graphics, Vcl.Imaging.pngimage, GraphicEx,
  dglOpenGL, Neslib.FastMath,
  Renderer.Shader, Engine.Paths, Engine.Types;

type
  TBillboardBlendMode = (bbAlpha, bbAdditive);

  TBillboard = class
  private type
    TBillboardVertex = packed record
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
    FBlendMode: TBillboardBlendMode;
    FAlphaCutoff: Single;
    FTexturePath: string;

    FVAO: GLuint;
    FVBO: GLuint;
    FTextureID: GLuint;
    FTextureWidth: Integer;
    FTextureHeight: Integer;
    FTextureKey: string;
    FTextureDirty: Boolean;
    FShader: TShader;

    procedure SetWidth(const Value: Single);
    procedure SetHeight(const Value: Single);
    procedure SetAlphaCutoff(const Value: Single);
    procedure SetTexturePath(const Value: string);

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

    procedure Assign(Source: TBillboard);
    function Clone: TBillboard;

    procedure Render(const ViewProjection: TMatrix4; const OwnerWorldMatrix: TMatrix4;
      const CameraRight, CameraUp: TVector3; OverrideWorldWidth: Single = 0.0;
      OverrideWorldHeight: Single = 0.0);

    procedure SaveToStream(Stream: TStream);
    procedure LoadFromStream(Stream: TStream);

    property Name: string read FName write FName;
    property Enabled: Boolean read FEnabled write FEnabled;
    property Width: Single read FWidth write SetWidth;
    property Height: Single read FHeight write SetHeight;
    property Offset: TVector3 read FOffset write FOffset;
    property Rotation: Single read FRotation write FRotation;
    property Color: TVector4 read FColor write FColor;
    property BlendMode: TBillboardBlendMode read FBlendMode write FBlendMode;
    property AlphaCutoff: Single read FAlphaCutoff write SetAlphaCutoff;
    property TexturePath: string read FTexturePath write SetTexturePath;
    property TextureID: GLuint read FTextureID;
    property TextureWidth: Integer read FTextureWidth;
    property TextureHeight: Integer read FTextureHeight;
  end;

  TBillboardList = class(TObjectList<TBillboard>)
  private
    function GetItem(AIndex: Integer): TBillboard;
  public
    function AddBillboardToList(ABillboard: TBillboard): Integer;
    function CreateBillboard: TBillboard;
    function NameIsUnique(const AName: string): Boolean;
    function GenerateUniqueName: string;
    function DeleteBillboard(AIndex: Integer): Boolean; overload;
    function DeleteBillboard(ABillboard: TBillboard): Boolean; overload;
    function Clone: TBillboardList;
    procedure SaveToStream(Stream: TStream);
    procedure LoadFromStream(Stream: TStream);

    property Item[Index: Integer]: TBillboard read GetItem; default;
  end;

implementation

const
  BILLBOARD_STREAM_VERSION = 3;
  BILLBOARD_LIST_STREAM_VERSION = 1;
  BILLBOARD_MAX_TEXTURE_SIZE = 1024;

type
  TBillboardTextureCacheEntry = class
  public
    TextureID: GLuint;
    Width: Integer;
    Height: Integer;
    RefCount: Integer;
  end;

var
  GSharedBillboardShader: TShader = nil;
  GBillboardInstanceCount: Integer = 0;
  GBillboardTextureCache: TObjectDictionary<string, TBillboardTextureCacheEntry> = nil;

function BillboardTextureCache: TObjectDictionary<string, TBillboardTextureCacheEntry>;
begin
  if GBillboardTextureCache = nil then
    GBillboardTextureCache := TObjectDictionary<string, TBillboardTextureCacheEntry>.Create([doOwnsValues]);
  Result := GBillboardTextureCache;
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
    raise Exception.Create('Invalid string length in billboard stream.');

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

function BuildBillboardTextureCacheKey(const AFileName: string): string;
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

procedure DownsampleBillboardPixelsIfNeeded(var Pixels: TBytes; var Width,
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
  if (MaxDimension <= BILLBOARD_MAX_TEXTURE_SIZE) or (MaxDimension <= 0) then
    Exit;

  Scale := BILLBOARD_MAX_TEXTURE_SIZE / MaxDimension;
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

function TryCreateBillboardTextureFromFile(const AFileName: string;
  out TextureID: GLuint; out TextureWidth, TextureHeight: Integer): Boolean;
var
  Graphic: TGraphic;
  Bitmap: TBitmap;
  Ext: string;
  Data: TBytes;
  RowSize: Integer;
  X, Y, I: Integer;
  ColorValue: TColor;
  AlphaOffset: Integer;
  HasNonZeroAlpha: Boolean;
begin
  Result := False;
  TextureID := 0;
  TextureWidth := 0;
  TextureHeight := 0;
  Ext := LowerCase(ExtractFileExt(AFileName));
  Graphic := nil;
  Bitmap := nil;
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
        TextureHeight, BILLBOARD_MAX_TEXTURE_SIZE) then
        Exit;
    end
    else if Ext = '.png' then
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
      DownsampleBillboardPixelsIfNeeded(Data, TextureWidth, TextureHeight);
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
    glGenerateMipmap(GL_TEXTURE_2D);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);

    Result := TextureID <> 0;
  finally
    Bitmap.Free;
    Graphic.Free;
  end;
end;

function TryAcquireBillboardTexture(const AFileName: string;
  out TextureID: GLuint; out TextureWidth, TextureHeight: Integer;
  out TextureKey: string): Boolean;
var
  Cache: TObjectDictionary<string, TBillboardTextureCacheEntry>;
  Entry: TBillboardTextureCacheEntry;
begin
  Result := False;
  TextureID := 0;
  TextureWidth := 0;
  TextureHeight := 0;
  TextureKey := BuildBillboardTextureCacheKey(AFileName);
  Cache := BillboardTextureCache;
  if Cache.TryGetValue(TextureKey, Entry) then
  begin
    Inc(Entry.RefCount);
    TextureID := Entry.TextureID;
    TextureWidth := Entry.Width;
    TextureHeight := Entry.Height;
    Exit(True);
  end;

  if not TryCreateBillboardTextureFromFile(AFileName, TextureID, TextureWidth,
    TextureHeight) then
    Exit;

  Entry := TBillboardTextureCacheEntry.Create;
  Entry.TextureID := TextureID;
  Entry.Width := TextureWidth;
  Entry.Height := TextureHeight;
  Entry.RefCount := 1;
  Cache.Add(TextureKey, Entry);
  Result := True;
end;

{ TBillboard }

constructor TBillboard.Create;
begin
  inherited Create;

  FName := 'Billboard';
  FEnabled := True;
  FWidth := 1.0;
  FHeight := 1.0;
  FOffset := Vector3(0, 0, 0);
  FRotation := 0.0;
  FColor := Vector4(1, 1, 1, 1);
  FBlendMode := bbAlpha;
  FAlphaCutoff := 0.05;
  FTexturePath := '';

  FVAO := 0;
  FVBO := 0;
  FTextureID := 0;
  FTextureWidth := 0;
  FTextureHeight := 0;
  FTextureKey := '';
  FTextureDirty := True;
  FShader := nil;
  Inc(GBillboardInstanceCount);
end;

destructor TBillboard.Destroy;
begin
  DestroyBuffers;
  DestroyTexture;
  DestroyShader;
  Dec(GBillboardInstanceCount);
  if GBillboardInstanceCount <= 0 then
  begin
    GBillboardInstanceCount := 0;
    FreeAndNil(GSharedBillboardShader);
    FreeAndNil(GBillboardTextureCache);
  end;
  inherited Destroy;
end;

procedure TBillboard.Assign(Source: TBillboard);
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
  FTexturePath := Source.FTexturePath;
  MarkTextureDirty;
end;

function TBillboard.Clone: TBillboard;
begin
  Result := TBillboard.Create;
  Result.Assign(Self);
end;

procedure TBillboard.SetWidth(const Value: Single);
begin
  FWidth := Max(0.001, Value);
end;

procedure TBillboard.SetHeight(const Value: Single);
begin
  FHeight := Max(0.001, Value);
end;

procedure TBillboard.SetAlphaCutoff(const Value: Single);
begin
  FAlphaCutoff := ClampSingle(Value, 0.0, 1.0);
end;

procedure TBillboard.SetTexturePath(const Value: string);
begin
  if SameText(FTexturePath, Trim(Value)) then
    Exit;

  FTexturePath := Trim(Value);
  MarkTextureDirty;
end;

procedure TBillboard.MarkTextureDirty;
begin
  FTextureDirty := True;
end;

procedure TBillboard.EnsureBuffers;
begin
  if FVAO <> 0 then
    Exit;

  glGenVertexArrays(1, @FVAO);
  glBindVertexArray(FVAO);

  glGenBuffers(1, @FVBO);
  glBindBuffer(GL_ARRAY_BUFFER, FVBO);
  glBufferData(GL_ARRAY_BUFFER, 0, nil, GL_DYNAMIC_DRAW);

  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, SizeOf(TBillboardVertex), nil);

  glEnableVertexAttribArray(1);
  glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, SizeOf(TBillboardVertex),
    Pointer(NativeUInt(SizeOf(TVector3))));

  glEnableVertexAttribArray(2);
  glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, SizeOf(TBillboardVertex),
    Pointer(NativeUInt(SizeOf(TVector3) + SizeOf(TVector4))));

  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glBindVertexArray(0);
end;

procedure TBillboard.EnsureShader;
begin
  if FShader = nil then
  begin
    if GSharedBillboardShader = nil then
      GSharedBillboardShader := TShader.Create(TEnginePaths.Shader('Billboard.vert'),
        TEnginePaths.Shader('Billboard.frag'));
    FShader := GSharedBillboardShader;
  end;
end;

procedure TBillboard.EnsureTexture;
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

  if not TryAcquireBillboardTexture(TextureFileName, FTextureID, FTextureWidth,
    FTextureHeight, FTextureKey) then
  begin
    FTextureDirty := False;
    FTextureKey := '';
    Exit;
  end;

  FTextureDirty := False;
end;

procedure TBillboard.DestroyBuffers;
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

procedure TBillboard.DestroyTexture;
var
  Entry: TBillboardTextureCacheEntry;
  TextureID: GLuint;
  ReleasedFromCache: Boolean;
begin
  if FTextureID <> 0 then
  begin
    ReleasedFromCache := False;
    if (FTextureKey <> '') and Assigned(GBillboardTextureCache) and
       GBillboardTextureCache.TryGetValue(FTextureKey, Entry) then
    begin
      Dec(Entry.RefCount);
      if Entry.RefCount <= 0 then
      begin
        TextureID := Entry.TextureID;
        if TextureID <> 0 then
          glDeleteTextures(1, @TextureID);
        GBillboardTextureCache.Remove(FTextureKey);
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

procedure TBillboard.DestroyShader;
begin
  FShader := nil;
end;

procedure TBillboard.Render(const ViewProjection: TMatrix4;
  const OwnerWorldMatrix: TMatrix4; const CameraRight, CameraUp: TVector3;
  OverrideWorldWidth, OverrideWorldHeight: Single);
const
  TEX: array[0..5] of TVector2 = (
    (X: 0; Y: 0), (X: 1; Y: 0), (X: 1; Y: 1),
    (X: 0; Y: 0), (X: 1; Y: 1), (X: 0; Y: 1)
  );
var
  Vertices: array[0..5] of TBillboardVertex;
  WorldPosition: TVector3;
  OwnerScaleX, OwnerScaleY: Single;
  Right, Up, RotRight, RotUp: TVector3;
  Corners: array[0..3] of TVector3;
  RenderWidth, RenderHeight: Single;
  HalfWidth, HalfHeight, S, C: Single;
  OldDepthMask, OldBlendEnabled, OldCullEnabled, OldDepthTestEnabled: GLboolean;
  OldSrcRGB, OldDstRGB, OldSrcAlpha, OldDstAlpha: GLint;
begin
  if (not FEnabled) or (FColor.W <= 0.001) then
    Exit;

  EnsureShader;
  EnsureBuffers;
  EnsureTexture;

  WorldPosition := Vector3(OwnerWorldMatrix * Vector4(FOffset, 1.0));
  if OverrideWorldWidth > 0.0 then
    RenderWidth := OverrideWorldWidth
  else
  begin
    OwnerScaleX := Max(Vector3(OwnerWorldMatrix.Columns[0]).Length, 0.001);
    RenderWidth := FWidth * OwnerScaleX;
  end;

  if OverrideWorldHeight > 0.0 then
    RenderHeight := OverrideWorldHeight
  else
  begin
    OwnerScaleY := Max(Vector3(OwnerWorldMatrix.Columns[1]).Length, 0.001);
    RenderHeight := FHeight * OwnerScaleY;
  end;

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

  Vertices[0].Position := Corners[0]; Vertices[0].Color := FColor; Vertices[0].TexCoord := TEX[0];
  Vertices[1].Position := Corners[1]; Vertices[1].Color := FColor; Vertices[1].TexCoord := TEX[1];
  Vertices[2].Position := Corners[2]; Vertices[2].Color := FColor; Vertices[2].TexCoord := TEX[2];
  Vertices[3].Position := Corners[0]; Vertices[3].Color := FColor; Vertices[3].TexCoord := TEX[3];
  Vertices[4].Position := Corners[2]; Vertices[4].Color := FColor; Vertices[4].TexCoord := TEX[4];
  Vertices[5].Position := Corners[3]; Vertices[5].Color := FColor; Vertices[5].TexCoord := TEX[5];

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
    bbAdditive: glBlendFunc(GL_SRC_ALPHA, GL_ONE);
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

procedure TBillboard.SaveToStream(Stream: TStream);
var
  Version: Integer;
  BlendValue: Integer;
begin
  Version := BILLBOARD_STREAM_VERSION;
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
  WriteStringToStream(Stream, FTexturePath);
  Stream.WriteBuffer(FAlphaCutoff, SizeOf(FAlphaCutoff));
end;

procedure TBillboard.LoadFromStream(Stream: TStream);
var
  Version: Integer;
  BlendValue: Integer;
begin
  Stream.ReadBuffer(Version, SizeOf(Version));
  if (Version < 1) or (Version > BILLBOARD_STREAM_VERSION) then
    raise Exception.CreateFmt('Unsupported billboard version: %d.', [Version]);

  if Version >= 3 then
    FName := ReadStringFromStream(Stream)
  else
    FName := 'Billboard';

  Stream.ReadBuffer(FEnabled, SizeOf(FEnabled));
  Stream.ReadBuffer(FWidth, SizeOf(FWidth));
  Stream.ReadBuffer(FHeight, SizeOf(FHeight));
  Stream.ReadBuffer(FOffset, SizeOf(FOffset));
  Stream.ReadBuffer(FRotation, SizeOf(FRotation));
  Stream.ReadBuffer(FColor, SizeOf(FColor));
  Stream.ReadBuffer(BlendValue, SizeOf(BlendValue));
  FBlendMode := TBillboardBlendMode(EnsureRange(BlendValue,
    Ord(Low(TBillboardBlendMode)), Ord(High(TBillboardBlendMode))));
  FTexturePath := ReadStringFromStream(Stream);
  if Version >= 2 then
    Stream.ReadBuffer(FAlphaCutoff, SizeOf(FAlphaCutoff))
  else
    FAlphaCutoff := 0.05;

  FWidth := ClampSingle(FWidth, 0.001, 100000.0);
  FHeight := ClampSingle(FHeight, 0.001, 100000.0);
  FAlphaCutoff := ClampSingle(FAlphaCutoff, 0.0, 1.0);
  FColor.X := ClampSingle(FColor.X, 0.0, 1000.0);
  FColor.Y := ClampSingle(FColor.Y, 0.0, 1000.0);
  FColor.Z := ClampSingle(FColor.Z, 0.0, 1000.0);
  FColor.W := ClampSingle(FColor.W, 0.0, 1.0);
  MarkTextureDirty;
end;

{ TBillboardList }

function TBillboardList.GetItem(AIndex: Integer): TBillboard;
begin
  if (AIndex >= 0) and (AIndex < Count) then
    Result := Items[AIndex]
  else
    Result := nil;
end;

function TBillboardList.AddBillboardToList(ABillboard: TBillboard): Integer;
begin
  if ABillboard = nil then
    Exit(-1);

  if Trim(ABillboard.Name) = '' then
    ABillboard.Name := GenerateUniqueName
  else if not NameIsUnique(ABillboard.Name) then
    ABillboard.Name := GenerateUniqueName;

  Result := inherited Add(ABillboard);
end;

function TBillboardList.CreateBillboard: TBillboard;
begin
  Result := TBillboard.Create;
  AddBillboardToList(Result);
end;

function TBillboardList.NameIsUnique(const AName: string): Boolean;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if SameText(Items[I].Name, AName) then
      Exit(False);
  Result := True;
end;

function TBillboardList.GenerateUniqueName: string;
var
  Counter: Integer;
begin
  Counter := 1;
  repeat
    Result := 'Billboard_' + Counter.ToString;
    Inc(Counter);
  until NameIsUnique(Result);
end;

function TBillboardList.DeleteBillboard(AIndex: Integer): Boolean;
begin
  if (AIndex < 0) or (AIndex >= Count) then
    Exit(False);
  Delete(AIndex);
  Result := True;
end;

function TBillboardList.DeleteBillboard(ABillboard: TBillboard): Boolean;
var
  Index: Integer;
begin
  Index := IndexOf(ABillboard);
  Result := DeleteBillboard(Index);
end;

function TBillboardList.Clone: TBillboardList;
var
  I: Integer;
begin
  Result := TBillboardList.Create;
  for I := 0 to Count - 1 do
    if Items[I] <> nil then
      Result.AddBillboardToList(Items[I].Clone);
end;

procedure TBillboardList.SaveToStream(Stream: TStream);
var
  I: Integer;
  Version: Integer;
  BillboardCount: Integer;
begin
  Version := BILLBOARD_LIST_STREAM_VERSION;
  Stream.WriteBuffer(Version, SizeOf(Version));
  BillboardCount := Count;
  Stream.WriteBuffer(BillboardCount, SizeOf(BillboardCount));
  for I := 0 to BillboardCount - 1 do
    Items[I].SaveToStream(Stream);
end;

procedure TBillboardList.LoadFromStream(Stream: TStream);
var
  I: Integer;
  Version: Integer;
  BillboardCount: Integer;
  Billboard: TBillboard;
begin
  Clear;
  Stream.ReadBuffer(Version, SizeOf(Version));
  if (Version < 1) or (Version > BILLBOARD_LIST_STREAM_VERSION) then
    raise Exception.CreateFmt('Unsupported billboard-list version: %d.',
      [Version]);

  Stream.ReadBuffer(BillboardCount, SizeOf(BillboardCount));
  if (BillboardCount < 0) or (BillboardCount > 100000) then
    raise Exception.Create('Invalid billboard-list count in scene stream.');

  for I := 0 to BillboardCount - 1 do
  begin
    Billboard := TBillboard.Create;
    try
      Billboard.LoadFromStream(Stream);
      AddBillboardToList(Billboard);
    except
      Billboard.Free;
      raise;
    end;
  end;
end;

end.
