unit Engine.Gui.BitmapFont;

interface

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.Math,
  Vcl.Graphics, Vcl.StdCtrls, Vcl.Imaging.pngimage, Vcl.Imaging.jpeg, GraphicEx,
  dglOpenGL, Neslib.FastMath,
  Engine.Gui;

type
  TGuiBitmapFontRange = class(TCollectionItem)
  private
    FCharCount: Integer;
    FStartASCII: WideChar;
    FStartGlyphIdx: Integer;
    FStopASCII: WideChar;
    FStopGlyphIdx: Integer;
    function GetStartASCII: string;
    function GetStopASCII: string;
    procedure SetStartASCII(const Value: string);
    procedure SetStartGlyphIdx(const Value: Integer);
    procedure SetStopASCII(const Value: string);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(Collection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
    procedure NotifyChange;
  published
    property CharCount: Integer read FCharCount;
    property StartASCII: string read GetStartASCII write SetStartASCII;
    property StartGlyphIdx: Integer read FStartGlyphIdx write SetStartGlyphIdx;
    property StopASCII: string read GetStopASCII write SetStopASCII;
    property StopGlyphIdx: Integer read FStopGlyphIdx;
  end;

  TGuiBitmapFontRanges = class(TCollection)
  private
    FCharCount: Integer;
    FOwner: TPersistent;
    function GetItem(Index: Integer): TGuiBitmapFontRange;
    procedure SetItem(Index: Integer; const Value: TGuiBitmapFontRange);
  protected
    function CalcCharacterCount: Integer;
    function GetOwner: TPersistent; override;
    procedure Update(Item: TCollectionItem); override;
  public
    constructor Create(AOwner: TPersistent);
    function Add: TGuiBitmapFontRange; overload;
    function Add(const StartASCII, StopASCII: WideChar): TGuiBitmapFontRange; overload;
    function Add(const StartASCII, StopASCII: AnsiChar): TGuiBitmapFontRange; overload;
    function CharacterToTileIndex(AChar: WideChar): Integer;
    procedure NotifyChange;
    function TileIndexToChar(AIndex: Integer): WideChar;
    property CharacterCount: Integer read FCharCount;
    property Items[Index: Integer]: TGuiBitmapFontRange read GetItem write SetItem; default;
  end;

  TGuiCharInfo = record
    L: Word;
    T: Word;
    W: Word;
  end;

  TGuiTextureImageAlpha = (giaDefault, giaOpaque, giaTransparentColor);

  TGuiCustomBitmapFont = class(TComponent)
  private
    FCharHeight: Integer;
    FChars: TArray<TGuiCharInfo>;
    FCharsLoaded: Boolean;
    FCharWidth: Integer;
    FGlyphs: TPicture;
    FGlyphsAlpha: TGuiTextureImageAlpha;
    FGlyphsIntervalX: Integer;
    FGlyphsIntervalY: Integer;
    FHSpace: Integer;
    FHSpaceFix: Integer;
    FMagFilter: GLint;
    FMinFilter: GLint;
    FRanges: TGuiBitmapFontRanges;
    FTextureHeight: Integer;
    FTextureID: GLuint;
    FTextureModified: Boolean;
    FTextureWidth: Integer;
    FVSpace: Integer;
    procedure OnGlyphsChanged(Sender: TObject);
    procedure SetCharHeight(const Value: Integer);
    procedure SetCharWidth(const Value: Integer);
    procedure SetGlyphs(const Value: TPicture);
    procedure SetGlyphsAlpha(const Value: TGuiTextureImageAlpha);
    procedure SetGlyphsIntervalX(const Value: Integer);
    procedure SetGlyphsIntervalY(const Value: Integer);
    procedure SetHSpace(const Value: Integer);
    procedure SetMagFilter(const Value: GLint);
    procedure SetMinFilter(const Value: GLint);
    procedure SetRanges(const Value: TGuiBitmapFontRanges);
    procedure SetVSpace(const Value: Integer);
  protected
    procedure AddGlyphVertices(var AVertices: TArray<TGuiVertex>; AX, AY: Single;
      ACharIndex: Integer);
    function CharactersPerRow: Integer;
    procedure EnsureCharsLoaded;
    procedure FreeTextureHandle; virtual;
    procedure GetCharTexCoords(ACharIndex: Integer; out TopLeft, BottomRight: TVector2);
    procedure ResetCharWidths(AWidth: Integer = -1);
    procedure TextureChanged;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function CalcStringWidth(const AText: string): Integer; virtual;
    function CharacterCount: Integer; virtual;
    function CharacterToTileIndex(AChar: WideChar): Integer; virtual;
    procedure CheckTexture;
    function GetCharWidth(AChar: WideChar): Integer;
    procedure LoadGlyphsFromFile(const AFileName: string);
    procedure RenderString(ARenderer: TGuiRenderer; const AText: string; AX, AY: Single;
      AViewportWidth, AViewportHeight: Integer; AAlignment: TAlignment;
      ALayout: TTextLayout; const AColor: TVector4); virtual;
    procedure RenderTextInRect(ARenderer: TGuiRenderer; const AText: string;
      AX1, AY1, AX2, AY2: Single; AViewportWidth, AViewportHeight: Integer;
      AAlignment: TAlignment; ALayout: TTextLayout; const AColor: TVector4); virtual;
    function TextHeight(const AText: string): Integer;
    procedure TextOut(ARenderer: TGuiRenderer; AX, AY: Single; const AText: string;
      AViewportWidth, AViewportHeight: Integer; const AColor: TVector4);
    function TextWidth(const AText: string): Integer;
    function TileIndexToChar(AIndex: Integer): WideChar; virtual;
    property CharHeight: Integer read FCharHeight write SetCharHeight default 16;
    property Glyphs: TPicture read FGlyphs write SetGlyphs;
    property HSpaceFix: Integer read FHSpaceFix write FHSpaceFix;
    property TextureHeight: Integer read FTextureHeight;
    property TextureID: GLuint read FTextureID;
    property TextureWidth: Integer read FTextureWidth;
  published
    property CharWidth: Integer read FCharWidth write SetCharWidth default 16;
    property GlyphsAlpha: TGuiTextureImageAlpha read FGlyphsAlpha write SetGlyphsAlpha default giaDefault;
    property GlyphsIntervalX: Integer read FGlyphsIntervalX write SetGlyphsIntervalX default 0;
    property GlyphsIntervalY: Integer read FGlyphsIntervalY write SetGlyphsIntervalY default 0;
    property HSpace: Integer read FHSpace write SetHSpace default 1;
    property MagFilter: GLint read FMagFilter write SetMagFilter default GL_LINEAR;
    property MinFilter: GLint read FMinFilter write SetMinFilter default GL_LINEAR;
    property Ranges: TGuiBitmapFontRanges read FRanges write SetRanges;
    property VSpace: Integer read FVSpace write SetVSpace default 1;
  end;

  TGuiBitmapFont = class(TGuiCustomBitmapFont)
  published
    property CharHeight;
    property CharWidth;
    property Glyphs;
    property GlyphsAlpha;
    property GlyphsIntervalX;
    property GlyphsIntervalY;
    property HSpace;
    property MagFilter;
    property MinFilter;
    property Ranges;
    property VSpace;
  end;

  TGuiFlatText = class(TComponent)
  private
    FAlignment: TAlignment;
    FBitmapFont: TGuiCustomBitmapFont;
    FColor: TVector4;
    FLayout: TTextLayout;
    FLeft: Single;
    FText: string;
    FTop: Single;
    procedure SetBitmapFont(const Value: TGuiCustomBitmapFont);
  public
    constructor Create(AOwner: TComponent); override;
    procedure Render(ARenderer: TGuiRenderer; AViewportWidth, AViewportHeight: Integer);
  published
    property Alignment: TAlignment read FAlignment write FAlignment;
    property BitmapFont: TGuiCustomBitmapFont read FBitmapFont write SetBitmapFont;
    property Layout: TTextLayout read FLayout write FLayout;
    property Left: Single read FLeft write FLeft;
    property Text: string read FText write FText;
    property Top: Single read FTop write FTop;
  end;

implementation

type
  TStringArray = TArray<string>;

function SplitTextLines(const AText: string): TStringArray;
var
  I: Integer;
  LStart: Integer;
  LCount: Integer;

  procedure AddLine(const AValue: string);
  begin
    SetLength(Result, LCount + 1);
    Result[LCount] := AValue;
    Inc(LCount);
  end;

begin
  LCount := 0;
  LStart := 1;
  I := 1;
  while I <= Length(AText) do
  begin
    if (AText[I] = #10) or (AText[I] = #13) then
    begin
      AddLine(Copy(AText, LStart, I - LStart));
      if (AText[I] = #13) and (I < Length(AText)) and (AText[I + 1] = #10) then
        Inc(I);
      LStart := I + 1;
    end;
    Inc(I);
  end;
  AddLine(Copy(AText, LStart, MaxInt));
end;

procedure AppendVertex(var AVertices: TArray<TGuiVertex>; const APosition, ATexCoord: TVector2);
var
  LIndex: Integer;
begin
  LIndex := Length(AVertices);
  SetLength(AVertices, LIndex + 1);
  AVertices[LIndex].Position := APosition;
  AVertices[LIndex].TexCoord := ATexCoord;
end;

function ColorMatches(AColorA, AColorB: COLORREF): Boolean;
begin
  Result := (GetRValue(AColorA) = GetRValue(AColorB)) and
    (GetGValue(AColorA) = GetGValue(AColorB)) and
    (GetBValue(AColorA) = GetBValue(AColorB));
end;

{ TGuiBitmapFontRange }

constructor TGuiBitmapFontRange.Create(Collection: TCollection);
begin
  inherited;
  FStartASCII := ' ';
  FStopASCII := '~';
  FStartGlyphIdx := 0;
  NotifyChange;
end;

procedure TGuiBitmapFontRange.Assign(Source: TPersistent);
var
  LSource: TGuiBitmapFontRange;
begin
  if Source is TGuiBitmapFontRange then
  begin
    LSource := TGuiBitmapFontRange(Source);
    FStartASCII := LSource.FStartASCII;
    FStopASCII := LSource.FStopASCII;
    FStartGlyphIdx := LSource.FStartGlyphIdx;
    NotifyChange;
    Exit;
  end;
  inherited;
end;

function TGuiBitmapFontRange.GetDisplayName: string;
begin
  Result := Format('ASCII [#%d, #%d] -> Glyphs [%d, %d]',
    [Ord(FStartASCII), Ord(FStopASCII), FStartGlyphIdx, FStopGlyphIdx]);
end;

function TGuiBitmapFontRange.GetStartASCII: string;
begin
  Result := FStartASCII;
end;

function TGuiBitmapFontRange.GetStopASCII: string;
begin
  Result := FStopASCII;
end;

procedure TGuiBitmapFontRange.NotifyChange;
begin
  FCharCount := Ord(FStopASCII) - Ord(FStartASCII) + 1;
  if FCharCount < 0 then
    FCharCount := 0;
  FStopGlyphIdx := FStartGlyphIdx + FCharCount - 1;
  if Collection is TGuiBitmapFontRanges then
    TGuiBitmapFontRanges(Collection).NotifyChange;
end;

procedure TGuiBitmapFontRange.SetStartASCII(const Value: string);
begin
  if Value = '' then
    Exit;
  FStartASCII := Value[1];
  NotifyChange;
end;

procedure TGuiBitmapFontRange.SetStartGlyphIdx(const Value: Integer);
begin
  FStartGlyphIdx := System.Math.Max(0, Value);
  NotifyChange;
end;

procedure TGuiBitmapFontRange.SetStopASCII(const Value: string);
begin
  if Value = '' then
    Exit;
  FStopASCII := Value[1];
  NotifyChange;
end;

{ TGuiBitmapFontRanges }

constructor TGuiBitmapFontRanges.Create(AOwner: TPersistent);
begin
  inherited Create(TGuiBitmapFontRange);
  FOwner := AOwner;
end;

function TGuiBitmapFontRanges.Add: TGuiBitmapFontRange;
begin
  Result := TGuiBitmapFontRange(inherited Add);
end;

function TGuiBitmapFontRanges.Add(const StartASCII, StopASCII: WideChar): TGuiBitmapFontRange;
begin
  Result := Add;
  Result.FStartASCII := StartASCII;
  Result.FStopASCII := StopASCII;
  Result.NotifyChange;
end;

function TGuiBitmapFontRanges.Add(const StartASCII, StopASCII: AnsiChar): TGuiBitmapFontRange;
begin
  Result := Add(WideChar(StartASCII), WideChar(StopASCII));
end;

function TGuiBitmapFontRanges.CalcCharacterCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Count - 1 do
    Inc(Result, Items[I].CharCount);
end;

function TGuiBitmapFontRanges.CharacterToTileIndex(AChar: WideChar): Integer;
var
  I: Integer;
  LRange: TGuiBitmapFontRange;
begin
  Result := -1;
  for I := 0 to Count - 1 do
  begin
    LRange := Items[I];
    if (AChar >= LRange.FStartASCII) and (AChar <= LRange.FStopASCII) then
      Exit(LRange.StartGlyphIdx + Ord(AChar) - Ord(LRange.FStartASCII));
  end;
end;

function TGuiBitmapFontRanges.GetItem(Index: Integer): TGuiBitmapFontRange;
begin
  Result := TGuiBitmapFontRange(inherited Items[Index]);
end;

function TGuiBitmapFontRanges.GetOwner: TPersistent;
begin
  Result := FOwner;
end;

procedure TGuiBitmapFontRanges.NotifyChange;
begin
  FCharCount := CalcCharacterCount;
  if FOwner is TGuiCustomBitmapFont then
    TGuiCustomBitmapFont(FOwner).TextureChanged;
end;

procedure TGuiBitmapFontRanges.SetItem(Index: Integer; const Value: TGuiBitmapFontRange);
begin
  inherited Items[Index] := Value;
end;

function TGuiBitmapFontRanges.TileIndexToChar(AIndex: Integer): WideChar;
var
  I: Integer;
  LRange: TGuiBitmapFontRange;
begin
  Result := #0;
  for I := 0 to Count - 1 do
  begin
    LRange := Items[I];
    if (AIndex >= LRange.StartGlyphIdx) and (AIndex <= LRange.StopGlyphIdx) then
      Exit(WideChar(AIndex - LRange.StartGlyphIdx + Ord(LRange.FStartASCII)));
  end;
end;

procedure TGuiBitmapFontRanges.Update(Item: TCollectionItem);
begin
  inherited;
  NotifyChange;
end;

{ TGuiCustomBitmapFont }

constructor TGuiCustomBitmapFont.Create(AOwner: TComponent);
begin
  inherited;
  FRanges := TGuiBitmapFontRanges.Create(Self);
  FRanges.Add(' ', '~');
  FGlyphs := TPicture.Create;
  FGlyphs.OnChange := OnGlyphsChanged;
  FCharWidth := 16;
  FCharHeight := 16;
  FHSpace := 1;
  FVSpace := 1;
  FMinFilter := GL_LINEAR;
  FMagFilter := GL_LINEAR;
  FGlyphsAlpha := giaDefault;
  FTextureModified := True;
end;

destructor TGuiCustomBitmapFont.Destroy;
begin
  FreeTextureHandle;
  FGlyphs.Free;
  FRanges.Free;
  inherited;
end;

procedure TGuiCustomBitmapFont.AddGlyphVertices(var AVertices: TArray<TGuiVertex>;
  AX, AY: Single; ACharIndex: Integer);
var
  LChar: TGuiCharInfo;
  LTopLeft: TVector2;
  LBottomRight: TVector2;
  LX2: Single;
  LY2: Single;
begin
  if (ACharIndex < 0) or (ACharIndex >= Length(FChars)) then
    Exit;

  LChar := FChars[ACharIndex];
  if LChar.W = 0 then
    Exit;

  GetCharTexCoords(ACharIndex, LTopLeft, LBottomRight);
  LX2 := AX + LChar.W;
  LY2 := AY + FCharHeight;

  AppendVertex(AVertices, Vector2(AX, AY), Vector2(LTopLeft.X, LTopLeft.Y));
  AppendVertex(AVertices, Vector2(AX, LY2), Vector2(LTopLeft.X, LBottomRight.Y));
  AppendVertex(AVertices, Vector2(LX2, LY2), Vector2(LBottomRight.X, LBottomRight.Y));

  AppendVertex(AVertices, Vector2(AX, AY), Vector2(LTopLeft.X, LTopLeft.Y));
  AppendVertex(AVertices, Vector2(LX2, LY2), Vector2(LBottomRight.X, LBottomRight.Y));
  AppendVertex(AVertices, Vector2(LX2, AY), Vector2(LBottomRight.X, LTopLeft.Y));
end;

function TGuiCustomBitmapFont.CalcStringWidth(const AText: string): Integer;
var
  LLine: string;
  LLines: TStringArray;
  LLineWidth: Integer;
  I: Integer;
  C: Integer;
begin
  Result := 0;
  LLines := SplitTextLines(AText);
  for LLine in LLines do
  begin
    LLineWidth := 0;
    for I := 1 to Length(LLine) do
    begin
      C := GetCharWidth(LLine[I]);
      if C > 0 then
      begin
        if LLineWidth > 0 then
          Inc(LLineWidth, FHSpace + FHSpaceFix);
        Inc(LLineWidth, C);
      end;
    end;
    Result := System.Math.Max(Result, LLineWidth);
  end;
end;

function TGuiCustomBitmapFont.CharacterCount: Integer;
begin
  Result := FRanges.CharacterCount;
end;

function TGuiCustomBitmapFont.CharacterToTileIndex(AChar: WideChar): Integer;
begin
  Result := FRanges.CharacterToTileIndex(AChar);
end;

function TGuiCustomBitmapFont.CharactersPerRow: Integer;
begin
  if (FGlyphs.Width > 0) and (FCharWidth + FGlyphsIntervalX > 0) then
    Result := (FGlyphs.Width + FGlyphsIntervalX) div (FCharWidth + FGlyphsIntervalX)
  else
    Result := 0;
end;

procedure TGuiCustomBitmapFont.CheckTexture;
var
  LBitmap: TBitmap;
  LData: TBytes;
  LHeight: Integer;
  LRow: PByte;
  LSourceColor: COLORREF;
  LTransparentColor: COLORREF;
  LWidth: Integer;
  LX: Integer;
  LY: Integer;
  LSrc: PByte;
  LDst: PByte;
begin
  if (not FTextureModified) and (FTextureID <> 0) then
    Exit;

  FreeTextureHandle;
  if (FGlyphs.Graphic = nil) or FGlyphs.Graphic.Empty or (FGlyphs.Width <= 0) or (FGlyphs.Height <= 0) then
    Exit;

  LBitmap := TBitmap.Create;
  try
    LBitmap.PixelFormat := pf32bit;
    LBitmap.SetSize(FGlyphs.Width, FGlyphs.Height);
    LBitmap.Canvas.Brush.Color := clBlack;
    LBitmap.Canvas.FillRect(Rect(0, 0, LBitmap.Width, LBitmap.Height));
    LBitmap.Canvas.Draw(0, 0, FGlyphs.Graphic);

    LWidth := LBitmap.Width;
    LHeight := LBitmap.Height;
    LTransparentColor := ColorToRGB(LBitmap.Canvas.Pixels[0, 0]);
    SetLength(LData, LWidth * LHeight * 4);

    for LY := 0 to LHeight - 1 do
    begin
      LRow := LBitmap.ScanLine[LHeight - 1 - LY];
      for LX := 0 to LWidth - 1 do
      begin
        LSrc := LRow + (LX * 4);
        LDst := @LData[((LY * LWidth) + LX) * 4];
        LSourceColor := RGB(LSrc[2], LSrc[1], LSrc[0]);

        LDst[0] := LSrc[2];
        LDst[1] := LSrc[1];
        LDst[2] := LSrc[0];
        if (FGlyphsAlpha <> giaOpaque) and ColorMatches(LSourceColor, LTransparentColor) then
          LDst[3] := 0
        else
          LDst[3] := 255;
      end;
    end;

    glGenTextures(1, @FTextureID);
    glBindTexture(GL_TEXTURE_2D, FTextureID);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, FMinFilter);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, FMagFilter);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, LWidth, LHeight, 0,
      GL_RGBA, GL_UNSIGNED_BYTE, Pointer(LData));
    glBindTexture(GL_TEXTURE_2D, 0);

    FTextureWidth := LWidth;
    FTextureHeight := LHeight;
    FTextureModified := False;
    FCharsLoaded := False;
  finally
    LBitmap.Free;
  end;
end;

procedure TGuiCustomBitmapFont.EnsureCharsLoaded;
var
  I: Integer;
  LColumns: Integer;
begin
  if FCharsLoaded then
    Exit;

  ResetCharWidths;
  LColumns := CharactersPerRow;
  if LColumns <= 0 then
    Exit;

  for I := 0 to CharacterCount - 1 do
  begin
    FChars[I].L := (I mod LColumns) * (FCharWidth + FGlyphsIntervalX);
    FChars[I].T := (I div LColumns) * (FCharHeight + FGlyphsIntervalY);
  end;
  FCharsLoaded := True;
end;

procedure TGuiCustomBitmapFont.FreeTextureHandle;
begin
  if FTextureID <> 0 then
  begin
    glDeleteTextures(1, @FTextureID);
    FTextureID := 0;
  end;
  FTextureWidth := 0;
  FTextureHeight := 0;
  FTextureModified := True;
end;

function TGuiCustomBitmapFont.GetCharWidth(AChar: WideChar): Integer;
var
  LIndex: Integer;
begin
  LIndex := CharacterToTileIndex(AChar);
  EnsureCharsLoaded;
  if (LIndex >= 0) and (LIndex < Length(FChars)) then
    Result := FChars[LIndex].W
  else
    Result := 0;
end;

procedure TGuiCustomBitmapFont.GetCharTexCoords(ACharIndex: Integer; out TopLeft,
  BottomRight: TVector2);
var
  LChar: TGuiCharInfo;
begin
  TopLeft := Vector2(0, 0);
  BottomRight := Vector2(0, 0);
  if (ACharIndex < 0) or (ACharIndex >= Length(FChars)) or
    (FTextureWidth <= 0) or (FTextureHeight <= 0) then
    Exit;

  LChar := FChars[ACharIndex];
  TopLeft.X := LChar.L / FTextureWidth;
  TopLeft.Y := 1.0 - (LChar.T / FTextureHeight);
  BottomRight.X := (LChar.L + LChar.W) / FTextureWidth;
  BottomRight.Y := 1.0 - ((LChar.T + FCharHeight) / FTextureHeight);
end;

procedure TGuiCustomBitmapFont.LoadGlyphsFromFile(const AFileName: string);
begin
  FGlyphs.LoadFromFile(AFileName);
  TextureChanged;
end;

procedure TGuiCustomBitmapFont.OnGlyphsChanged(Sender: TObject);
begin
  TextureChanged;
end;

procedure TGuiCustomBitmapFont.RenderString(ARenderer: TGuiRenderer; const AText: string;
  AX, AY: Single; AViewportWidth, AViewportHeight: Integer; AAlignment: TAlignment;
  ALayout: TTextLayout; const AColor: TVector4);
var
  LWidth: Integer;
  LHeight: Integer;
begin
  LWidth := CalcStringWidth(AText);
  LHeight := TextHeight(AText);
  case AAlignment of
    taCenter:
      AX := AX - (LWidth * 0.5);
    taRightJustify:
      AX := AX - LWidth;
  end;

  case ALayout of
    tlCenter:
      AY := AY - (LHeight * 0.5);
    tlBottom:
      AY := AY - LHeight;
  end;

  RenderTextInRect(ARenderer, AText, AX, AY, AX + LWidth, AY + LHeight,
    AViewportWidth, AViewportHeight, taLeftJustify, tlTop, AColor);
end;

procedure TGuiCustomBitmapFont.RenderTextInRect(ARenderer: TGuiRenderer; const AText: string;
  AX1, AY1, AX2, AY2: Single; AViewportWidth, AViewportHeight: Integer;
  AAlignment: TAlignment; ALayout: TTextLayout; const AColor: TVector4);
var
  LCharIndex: Integer;
  LLine: string;
  LLines: TStringArray;
  LLineHeight: Integer;
  LLineIndex: Integer;
  LLineWidth: Integer;
  LTextHeight: Integer;
  LVertices: TArray<TGuiVertex>;
  LX: Single;
  LY: Single;
  I: Integer;
begin
  if (ARenderer = nil) or (AText = '') then
    Exit;

  CheckTexture;
  if FTextureID = 0 then
    Exit;

  EnsureCharsLoaded;
  LLines := SplitTextLines(AText);
  LLineHeight := FCharHeight + FVSpace;
  LTextHeight := TextHeight(AText);

  case ALayout of
    tlBottom:
      LY := AY2 - LTextHeight;
    tlCenter:
      LY := AY1 + ((AY2 - AY1) - LTextHeight) * 0.5;
  else
    LY := AY1;
  end;

  for LLineIndex := 0 to High(LLines) do
  begin
    LLine := LLines[LLineIndex];
    LLineWidth := CalcStringWidth(LLine);
    case AAlignment of
      taCenter:
        LX := AX1 + ((AX2 - AX1) - LLineWidth) * 0.5;
      taRightJustify:
        LX := AX2 - LLineWidth;
    else
      LX := AX1;
    end;

    for I := 1 to Length(LLine) do
    begin
      if LLine[I] = #32 then
      begin
        LX := LX + GetCharWidth(#32) + FHSpaceFix + FHSpace;
        Continue;
      end;

      LCharIndex := CharacterToTileIndex(LLine[I]);
      if LCharIndex >= 0 then
      begin
        AddGlyphVertices(LVertices, LX, LY, LCharIndex);
        LX := LX + GetCharWidth(LLine[I]) + FHSpaceFix + FHSpace;
      end;
    end;
    LY := LY + LLineHeight;
  end;

  ARenderer.RenderVertices(LVertices, FTextureID, AViewportWidth, AViewportHeight, AColor);
end;

procedure TGuiCustomBitmapFont.ResetCharWidths(AWidth: Integer);
var
  I: Integer;
begin
  if AWidth < 0 then
    AWidth := FCharWidth;
  SetLength(FChars, CharacterCount);
  for I := 0 to High(FChars) do
    FChars[I].W := AWidth;
end;

procedure TGuiCustomBitmapFont.SetCharHeight(const Value: Integer);
begin
  FCharHeight := System.Math.Max(1, Value);
  TextureChanged;
end;

procedure TGuiCustomBitmapFont.SetCharWidth(const Value: Integer);
begin
  FCharWidth := System.Math.Max(1, Value);
  TextureChanged;
end;

procedure TGuiCustomBitmapFont.SetGlyphs(const Value: TPicture);
begin
  FGlyphs.Assign(Value);
  TextureChanged;
end;

procedure TGuiCustomBitmapFont.SetGlyphsAlpha(const Value: TGuiTextureImageAlpha);
begin
  FGlyphsAlpha := Value;
  TextureChanged;
end;

procedure TGuiCustomBitmapFont.SetGlyphsIntervalX(const Value: Integer);
begin
  FGlyphsIntervalX := System.Math.Max(0, Value);
  TextureChanged;
end;

procedure TGuiCustomBitmapFont.SetGlyphsIntervalY(const Value: Integer);
begin
  FGlyphsIntervalY := System.Math.Max(0, Value);
  TextureChanged;
end;

procedure TGuiCustomBitmapFont.SetHSpace(const Value: Integer);
begin
  FHSpace := Value;
end;

procedure TGuiCustomBitmapFont.SetMagFilter(const Value: GLint);
begin
  FMagFilter := Value;
  TextureChanged;
end;

procedure TGuiCustomBitmapFont.SetMinFilter(const Value: GLint);
begin
  FMinFilter := Value;
  TextureChanged;
end;

procedure TGuiCustomBitmapFont.SetRanges(const Value: TGuiBitmapFontRanges);
begin
  FRanges.Assign(Value);
  TextureChanged;
end;

procedure TGuiCustomBitmapFont.SetVSpace(const Value: Integer);
begin
  FVSpace := Value;
end;

function TGuiCustomBitmapFont.TextHeight(const AText: string): Integer;
var
  LLines: TStringArray;
begin
  LLines := SplitTextLines(AText);
  if Length(LLines) = 0 then
    Exit(0);
  Result := (Length(LLines) * (FCharHeight + FVSpace)) - FVSpace;
end;

procedure TGuiCustomBitmapFont.TextOut(ARenderer: TGuiRenderer; AX, AY: Single;
  const AText: string; AViewportWidth, AViewportHeight: Integer; const AColor: TVector4);
begin
  RenderString(ARenderer, AText, AX, AY, AViewportWidth, AViewportHeight,
    taLeftJustify, tlTop, AColor);
end;

function TGuiCustomBitmapFont.TextWidth(const AText: string): Integer;
begin
  Result := CalcStringWidth(AText);
end;

procedure TGuiCustomBitmapFont.TextureChanged;
begin
  FCharsLoaded := False;
  FTextureModified := True;
end;

function TGuiCustomBitmapFont.TileIndexToChar(AIndex: Integer): WideChar;
begin
  Result := FRanges.TileIndexToChar(AIndex);
end;

{ TGuiFlatText }

constructor TGuiFlatText.Create(AOwner: TComponent);
begin
  inherited;
  FAlignment := taLeftJustify;
  FLayout := tlTop;
  FColor := Vector4(1, 1, 1, 1);
end;

procedure TGuiFlatText.Render(ARenderer: TGuiRenderer; AViewportWidth, AViewportHeight: Integer);
begin
  if FBitmapFont <> nil then
    FBitmapFont.RenderString(ARenderer, FText, FLeft, FTop, AViewportWidth, AViewportHeight,
      FAlignment, FLayout, FColor);
end;

procedure TGuiFlatText.SetBitmapFont(const Value: TGuiCustomBitmapFont);
begin
  FBitmapFont := Value;
end;

initialization
  RegisterClasses([TGuiBitmapFont, TGuiFlatText]);

end.
