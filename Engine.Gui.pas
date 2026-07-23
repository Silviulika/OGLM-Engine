unit Engine.Gui;

interface

uses
  System.SysUtils, System.Classes, System.Math, System.Generics.Collections,
  Vcl.Graphics, Vcl.Imaging.pngimage, Vcl.Imaging.jpeg, GraphicEx,
  dglOpenGL, Neslib.FastMath,
  Renderer.Shader;

type
  TGuiAlignment = (
    gaTopLeft,
    gaTop,
    gaTopRight,
    gaLeft,
    gaCenter,
    gaRight,
    gaBottomLeft,
    gaBottom,
    gaBottomRight,
    gaBorder
  );

  TGuiRect = record
    X1: Single;
    Y1: Single;
    X2: Single;
    Y2: Single;
    XTiles: Single;
    YTiles: Single;
    class function Create(AX1, AY1, AX2, AY2: Single): TGuiRect; static;
    function Width: Single;
    function Height: Single;
    function IsEmpty: Boolean;
  end;

  TGuiDrawResult = array[TGuiAlignment] of TGuiRect;

  TGuiVertex = packed record
    Position: TVector2;
    TexCoord: TVector2;
  end;

  TGuiTexture = class
  private
    FFileName: string;
    FTextureID: GLuint;
    FWidth: Integer;
    FHeight: Integer;
  public
    destructor Destroy; override;
    procedure Clear;
    function LoadFromFile(const AFileName: string): Boolean;
    property FileName: string read FFileName;
    property TextureID: GLuint read FTextureID;
    property Width: Integer read FWidth;
    property Height: Integer read FHeight;
  end;

  TGuiElement = class(TCollectionItem)
  private
    FTopLeft: TVector3;
    FBottomRight: TVector3;
    FScale: TVector3;
    FAlign: TGuiAlignment;
    FName: string;
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(Collection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
    property Name: string read FName write FName;
    property TopLeft: TVector3 read FTopLeft write FTopLeft;
    property BottomRight: TVector3 read FBottomRight write FBottomRight;
    property Scale: TVector3 read FScale write FScale;
    property Align: TGuiAlignment read FAlign write FAlign;
  end;

  TGuiElementList = class(TOwnedCollection)
  private
    function GetItem(Index: Integer): TGuiElement;
    procedure SetItem(Index: Integer; const Value: TGuiElement);
  public
    constructor Create(AOwner: TPersistent);
    function Add: TGuiElement;
    function FindItem(const AName: string): TGuiElement;
    property Items[Index: Integer]: TGuiElement read GetItem write SetItem; default;
  end;

  TGuiComponent = class(TCollectionItem)
  private
    FElements: TGuiElementList;
    FName: string;
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(Collection: TCollection); override;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    procedure CalculateRects(AX1, AY1, AX2, AY2: Single; const ATextureSize: TVector2;
      out AResult: TGuiDrawResult; ARefresh: Boolean = True; AScale: Single = 1.0);
    procedure BuildVertices(AX1, AY1, AX2, AY2: Single; const ATextureSize: TVector2;
      var AVertices: TArray<TGuiVertex>; AScale: Single = 1.0);
    function HitTest(AX, AY, AX1, AY1, AX2, AY2: Single; const ATextureSize: TVector2;
      AScale: Single = 1.0): Boolean;
    property Name: string read FName write FName;
    property Elements: TGuiElementList read FElements;
  end;

  TGuiComponentList = class(TOwnedCollection)
  private
    function GetItem(Index: Integer): TGuiComponent;
    procedure SetItem(Index: Integer; const Value: TGuiComponent);
  public
    constructor Create(AOwner: TPersistent);
    function Add: TGuiComponent;
    function FindItem(const AName: string): TGuiComponent;
    property Items[Index: Integer]: TGuiComponent read GetItem write SetItem; default;
  end;

  TGuiLayout = class(TComponent)
  private
    FComponents: TGuiComponentList;
    FTexture: TGuiTexture;
    FTextureFileName: string;
    procedure SetTextureFileName(const Value: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Clear;
    procedure LoadFromStream(AStream: TStream);
    procedure SaveToStream(AStream: TStream);
    procedure LoadFromFile(const AFileName: string);
    procedure SaveToFile(const AFileName: string);
    function FindComponent(const AName: string): TGuiComponent; reintroduce;
    property Components: TGuiComponentList read FComponents;
    property Texture: TGuiTexture read FTexture;
  published
    property TextureFileName: string read FTextureFileName write SetTextureFileName;
  end;

  TGuiRenderer = class
  private
    FShader: TShader;
    FOwnsShader: Boolean;
    FVAO: GLuint;
    FVBO: GLuint;
    FWhiteTextureID: GLuint;
    FOpacity: Single;
    FColorKeyEnabled: Boolean;
    FColorKey: TVector3;
    FColorKeyTolerance: Single;
    procedure CreateBuffers;
    procedure DestroyBuffers;
    procedure CreateWhiteTexture;
    procedure DestroyWhiteTexture;
    procedure SetColorKeyTolerance(const Value: Single);
    procedure SetOpacity(const Value: Single);
  public
    constructor Create(const AVertexShaderFile, AFragmentShaderFile: string); overload;
    constructor Create(AShader: TShader; AOwnsShader: Boolean = False); overload;
    destructor Destroy; override;
    procedure RenderSolidRect(AX, AY, AWidth, AHeight: Single;
      AViewportWidth, AViewportHeight: Integer; const AColor: TVector4);
    procedure RenderVertices(const AVertices: TArray<TGuiVertex>; ATextureID: GLuint;
      AViewportWidth, AViewportHeight: Integer; const ATint: TVector4);
    procedure RenderComponent(AComponent: TGuiComponent; ATexture: TGuiTexture;
      AX, AY, AWidth, AHeight: Single; AViewportWidth, AViewportHeight: Integer;
      const ATint: TVector4; AScale: Single = 1.0);
    procedure RenderLayout(ALayout: TGuiLayout; const AComponentName: string;
      AX, AY, AWidth, AHeight: Single; AViewportWidth, AViewportHeight: Integer;
      const ATint: TVector4; AScale: Single = 1.0);
    property Shader: TShader read FShader;
    property Opacity: Single read FOpacity write SetOpacity;
    property ColorKeyEnabled: Boolean read FColorKeyEnabled write FColorKeyEnabled;
    property ColorKey: TVector3 read FColorKey write FColorKey;
    property ColorKeyTolerance: Single read FColorKeyTolerance write SetColorKeyTolerance;
  end;

  TGuiControl = class(TComponent)
  private
    FChildren: TObjectList<TGuiControl>;
    FComponentName: string;
    FHeight: Single;
    FLayout: TGuiLayout;
    FLeft: Single;
    FParent: TGuiControl;
    FScale: Single;
    FTop: Single;
    FTint: TVector4;
    FVisible: Boolean;
    FWidth: Single;
    function GetChild(Index: Integer): TGuiControl;
    function GetChildCount: Integer;
    function GetAbsoluteLeft: Single;
    function GetAbsoluteTop: Single;
    function GetRecursiveVisible: Boolean;
    procedure SetParent(const Value: TGuiControl);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AddChild(AChild: TGuiControl);
    procedure InsertChild(Index: Integer; AChild: TGuiControl);
    procedure RemoveChild(AChild: TGuiControl);
    procedure Render(ARenderer: TGuiRenderer; AViewportWidth, AViewportHeight: Integer); virtual;
    property Children[Index: Integer]: TGuiControl read GetChild;
    property ChildCount: Integer read GetChildCount;
    property AbsoluteLeft: Single read GetAbsoluteLeft;
    property AbsoluteTop: Single read GetAbsoluteTop;
    property RecursiveVisible: Boolean read GetRecursiveVisible;
    property Parent: TGuiControl read FParent write SetParent;
    property Tint: TVector4 read FTint write FTint;
  published
    property ComponentName: string read FComponentName write FComponentName;
    property Height: Single read FHeight write FHeight;
    property Layout: TGuiLayout read FLayout write FLayout;
    property Left: Single read FLeft write FLeft;
    property Scale: Single read FScale write FScale;
    property Top: Single read FTop write FTop;
    property Visible: Boolean read FVisible write FVisible;
    property Width: Single read FWidth write FWidth;
  end;

implementation

const
  GUI_LAYOUT_VERSION = 1;

function GuiNullRect: TGuiRect;
begin
  Result := TGuiRect.Create(0, 0, 0, 0);
end;

function SafeDiv(const ANumerator, ADenominator: Single; const ADefault: Single = 1.0): Single;
begin
  if SameValue(ADenominator, 0.0) then
    Exit(ADefault);
  Result := ANumerator / ADenominator;
end;

function ClampRect(const ARect: TGuiRect): TGuiRect;
begin
  Result := ARect;
  if Result.X2 < Result.X1 then
    Result.X2 := Result.X1;
  if Result.Y2 < Result.Y1 then
    Result.Y2 := Result.Y1;
end;

function SourceRectFromElement(AElement: TGuiElement): TGuiRect;
begin
  Result := TGuiRect.Create(
    System.Math.Min(AElement.TopLeft.X, AElement.BottomRight.X),
    System.Math.Min(AElement.TopLeft.Y, AElement.BottomRight.Y),
    System.Math.Max(AElement.TopLeft.X, AElement.BottomRight.X),
    System.Math.Max(AElement.TopLeft.Y, AElement.BottomRight.Y)
  );
end;

procedure WriteInteger(AStream: TStream; AValue: Integer);
begin
  AStream.WriteBuffer(AValue, SizeOf(AValue));
end;

function ReadInteger(AStream: TStream): Integer;
begin
  AStream.ReadBuffer(Result, SizeOf(Result));
end;

procedure WriteSingle(AStream: TStream; AValue: Single);
begin
  AStream.WriteBuffer(AValue, SizeOf(AValue));
end;

function ReadSingle(AStream: TStream): Single;
begin
  AStream.ReadBuffer(Result, SizeOf(Result));
end;

procedure WriteStringValue(AStream: TStream; const AValue: string);
var
  LLength: Integer;
begin
  LLength := Length(AValue);
  WriteInteger(AStream, LLength);
  if LLength > 0 then
    AStream.WriteBuffer(PChar(AValue)^, LLength * SizeOf(Char));
end;

function ReadStringValue(AStream: TStream): string;
var
  LLength: Integer;
begin
  LLength := ReadInteger(AStream);
  SetLength(Result, LLength);
  if LLength > 0 then
    AStream.ReadBuffer(PChar(Result)^, LLength * SizeOf(Char));
end;

procedure WriteVector3(AStream: TStream; const AValue: TVector3);
begin
  WriteSingle(AStream, AValue.X);
  WriteSingle(AStream, AValue.Y);
  WriteSingle(AStream, AValue.Z);
end;

function ReadVector3(AStream: TStream): TVector3;
begin
  Result := Vector3(ReadSingle(AStream), ReadSingle(AStream), ReadSingle(AStream));
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

procedure AppendQuad(var AVertices: TArray<TGuiVertex>; const ADest, ASource: TGuiRect;
  const ATextureSize: TVector2);
var
  LSource: TGuiRect;
  LU1, LU2, LV1, LV2: Single;
  LX: TVector2;
  LY: TVector2;

  function InsetAxis(AStart, AEnd: Single): TVector2;
  var
    LInset: Single;
  begin
    LInset := System.Math.Min(0.5, Abs(AEnd - AStart) * 0.5);
    if AEnd >= AStart then
      Result := Vector2(AStart + LInset, AEnd - LInset)
    else
      Result := Vector2(AStart - LInset, AEnd + LInset);
  end;
begin
  if ADest.IsEmpty or SameValue(ATextureSize.X, 0.0) or SameValue(ATextureSize.Y, 0.0) then
    Exit;

  LSource := ASource;
  LX := InsetAxis(LSource.X1, LSource.X2);
  LY := InsetAxis(LSource.Y1, LSource.Y2);

  LU1 := LX.X / ATextureSize.X;
  LU2 := LX.Y / ATextureSize.X;
  LV1 := 1.0 - (LY.X / ATextureSize.Y);
  LV2 := 1.0 - (LY.Y / ATextureSize.Y);

  AppendVertex(AVertices, Vector2(ADest.X1, ADest.Y1), Vector2(LU1, LV1));
  AppendVertex(AVertices, Vector2(ADest.X1, ADest.Y2), Vector2(LU1, LV2));
  AppendVertex(AVertices, Vector2(ADest.X2, ADest.Y2), Vector2(LU2, LV2));

  AppendVertex(AVertices, Vector2(ADest.X1, ADest.Y1), Vector2(LU1, LV1));
  AppendVertex(AVertices, Vector2(ADest.X2, ADest.Y2), Vector2(LU2, LV2));
  AppendVertex(AVertices, Vector2(ADest.X2, ADest.Y1), Vector2(LU2, LV1));
end;

procedure AppendTiledQuad(var AVertices: TArray<TGuiVertex>; const ADest, ASource: TGuiRect;
  const ATextureSize: TVector2);
var
  LTilesX, LTilesY: Single;
  LTileWidth, LTileHeight: Single;
  LX, LY, LNextX, LNextY: Single;
  LRemainingX, LRemainingY: Single;
  LFracX, LFracY: Single;
  LDest, LSource: TGuiRect;
begin
  if ADest.IsEmpty or ASource.IsEmpty then
    Exit;

  LTilesX := System.Math.Max(ADest.XTiles, 1.0);
  LTilesY := System.Math.Max(ADest.YTiles, 1.0);
  LTileWidth := ADest.Width / LTilesX;
  LTileHeight := ADest.Height / LTilesY;

  LY := ADest.Y1;
  LRemainingY := LTilesY;
  while (LRemainingY > 0.001) and (LY < ADest.Y2) do
  begin
    LFracY := System.Math.Min(1.0, LRemainingY);
    if LRemainingY <= 1.0 then
      LNextY := ADest.Y2
    else
      LNextY := System.Math.Min(ADest.Y2, LY + LTileHeight);

    LX := ADest.X1;
    LRemainingX := LTilesX;
    while (LRemainingX > 0.001) and (LX < ADest.X2) do
    begin
      LFracX := System.Math.Min(1.0, LRemainingX);
      if LRemainingX <= 1.0 then
        LNextX := ADest.X2
      else
        LNextX := System.Math.Min(ADest.X2, LX + LTileWidth);

      LDest := TGuiRect.Create(LX, LY, LNextX, LNextY);
      LSource := TGuiRect.Create(
        ASource.X1,
        ASource.Y1,
        ASource.X1 + (ASource.Width * LFracX),
        ASource.Y1 + (ASource.Height * LFracY)
      );
      AppendQuad(AVertices, LDest, LSource, ATextureSize);

      LX := LNextX;
      LRemainingX := LRemainingX - 1.0;
    end;

    LY := LNextY;
    LRemainingY := LRemainingY - 1.0;
  end;
end;

procedure AppendBorderQuad(var AVertices: TArray<TGuiVertex>; const AElement: TGuiElement;
  const ADest: TGuiDrawResult; const ATextureSize: TVector2);
var
  LLeft, LTop, LRight, LBottom: Single;
  LBorderX, LBorderY: Single;
  LSource: TGuiRect;
begin
  LSource := SourceRectFromElement(AElement);
  LLeft := LSource.X1;
  LTop := LSource.Y1;
  LRight := LSource.X2;
  LBottom := LSource.Y2;
  LBorderX := Abs(AElement.Scale.X);
  LBorderY := Abs(AElement.Scale.Y);

  if (LBorderX <= 0.0) or (LBorderY <= 0.0) then
  begin
    AppendTiledQuad(AVertices, ADest[gaCenter], TGuiRect.Create(LLeft, LTop, LRight, LBottom), ATextureSize);
    Exit;
  end;

  LSource := TGuiRect.Create(LLeft, LTop, LLeft + LBorderX, LTop + LBorderY);
  AppendQuad(AVertices, ADest[gaTopLeft], LSource, ATextureSize);

  LSource := TGuiRect.Create(LLeft + LBorderX, LTop, LRight - LBorderX, LTop + LBorderY);
  AppendTiledQuad(AVertices, ADest[gaTop], LSource, ATextureSize);

  LSource := TGuiRect.Create(LRight - LBorderX, LTop, LRight, LTop + LBorderY);
  AppendQuad(AVertices, ADest[gaTopRight], LSource, ATextureSize);

  LSource := TGuiRect.Create(LRight - LBorderX, LTop + LBorderY, LRight, LBottom - LBorderY);
  AppendTiledQuad(AVertices, ADest[gaRight], LSource, ATextureSize);

  LSource := TGuiRect.Create(LRight - LBorderX, LBottom - LBorderY, LRight, LBottom);
  AppendQuad(AVertices, ADest[gaBottomRight], LSource, ATextureSize);

  LSource := TGuiRect.Create(LLeft + LBorderX, LBottom - LBorderY, LRight - LBorderX, LBottom);
  AppendTiledQuad(AVertices, ADest[gaBottom], LSource, ATextureSize);

  LSource := TGuiRect.Create(LLeft, LBottom - LBorderY, LLeft + LBorderX, LBottom);
  AppendQuad(AVertices, ADest[gaBottomLeft], LSource, ATextureSize);

  LSource := TGuiRect.Create(LLeft, LTop + LBorderY, LLeft + LBorderX, LBottom - LBorderY);
  AppendTiledQuad(AVertices, ADest[gaLeft], LSource, ATextureSize);

  LSource := TGuiRect.Create(LLeft + LBorderX, LTop + LBorderY, LRight - LBorderX, LBottom - LBorderY);
  AppendTiledQuad(AVertices, ADest[gaCenter], LSource, ATextureSize);
end;

{ TGuiRect }

class function TGuiRect.Create(AX1, AY1, AX2, AY2: Single): TGuiRect;
begin
  Result.X1 := AX1;
  Result.Y1 := AY1;
  Result.X2 := AX2;
  Result.Y2 := AY2;
  Result.XTiles := 1.0;
  Result.YTiles := 1.0;
end;

function TGuiRect.Height: Single;
begin
  Result := Y2 - Y1;
end;

function TGuiRect.IsEmpty: Boolean;
begin
  Result := (Width <= 0.0) or (Height <= 0.0);
end;

function TGuiRect.Width: Single;
begin
  Result := X2 - X1;
end;

{ TGuiTexture }

destructor TGuiTexture.Destroy;
begin
  Clear;
  inherited;
end;

procedure TGuiTexture.Clear;
begin
  if FTextureID <> 0 then
  begin
    glDeleteTextures(1, @FTextureID);
    FTextureID := 0;
  end;

  FFileName := '';
  FWidth := 0;
  FHeight := 0;
end;

function TGuiTexture.LoadFromFile(const AFileName: string): Boolean;
var
  LPicture: TPicture;
  LBitmap: TBitmap;
  LData: TBytes;
  LExt: string;
  LRowSize: Integer;
  LForceOpaqueAlpha: Boolean;
  LHasNonZeroAlpha: Boolean;
  LX: Integer;
  LY: Integer;
  LOffset: Integer;
begin
  Result := False;
  if not FileExists(AFileName) then
    Exit;

  LPicture := TPicture.Create;
  LBitmap := TBitmap.Create;
  try
    LExt := LowerCase(ExtractFileExt(AFileName));
    LForceOpaqueAlpha := False;
    if LExt = '.bmp' then
    begin
      LBitmap.LoadFromFile(AFileName);
      if (LBitmap.Width <= 0) or (LBitmap.Height <= 0) then
        Exit;

      LForceOpaqueAlpha := LBitmap.PixelFormat <> pf32bit;
      LBitmap.PixelFormat := pf32bit;
    end
    else
    begin
      LPicture.LoadFromFile(AFileName);
      if (LPicture.Width <= 0) or (LPicture.Height <= 0) then
        Exit;

      LBitmap.PixelFormat := pf32bit;
      LBitmap.SetSize(LPicture.Width, LPicture.Height);
      LBitmap.Canvas.Brush.Color := clBlack;
      LBitmap.Canvas.FillRect(Rect(0, 0, LBitmap.Width, LBitmap.Height));
      LBitmap.Canvas.Draw(0, 0, LPicture.Graphic);
    end;

    LRowSize := LBitmap.Width * 4;
    SetLength(LData, LRowSize * LBitmap.Height);
    LHasNonZeroAlpha := False;
    for LY := 0 to LBitmap.Height - 1 do
    begin
      Move(LBitmap.ScanLine[LBitmap.Height - 1 - LY]^, LData[LY * LRowSize], LRowSize);
      for LX := 0 to LBitmap.Width - 1 do
      begin
        LOffset := (LY * LRowSize) + (LX * 4) + 3;
        if LData[LOffset] <> 0 then
          LHasNonZeroAlpha := True;
      end;
    end;

    if LForceOpaqueAlpha or ((LExt <> '.png') and not LHasNonZeroAlpha) then
      for LY := 0 to LBitmap.Height - 1 do
        for LX := 0 to LBitmap.Width - 1 do
        begin
          LOffset := (LY * LRowSize) + (LX * 4) + 3;
          LData[LOffset] := 255;
        end;

    if FTextureID = 0 then
      glGenTextures(1, @FTextureID);

    glBindTexture(GL_TEXTURE_2D, FTextureID);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, LBitmap.Width, LBitmap.Height, 0,
      GL_BGRA, GL_UNSIGNED_BYTE, @LData[0]);
    glBindTexture(GL_TEXTURE_2D, 0);

    FFileName := AFileName;
    FWidth := LBitmap.Width;
    FHeight := LBitmap.Height;
    Result := True;
  finally
    LBitmap.Free;
    LPicture.Free;
  end;
end;

{ TGuiElement }

constructor TGuiElement.Create(Collection: TCollection);
begin
  inherited;
  FScale := Vector3(1.0, 1.0, 1.0);
  FAlign := gaCenter;
end;

procedure TGuiElement.Assign(Source: TPersistent);
var
  LSource: TGuiElement;
begin
  if Source is TGuiElement then
  begin
    LSource := TGuiElement(Source);
    FName := LSource.FName;
    FTopLeft := LSource.FTopLeft;
    FBottomRight := LSource.FBottomRight;
    FScale := LSource.FScale;
    FAlign := LSource.FAlign;
    Exit;
  end;

  inherited;
end;

function TGuiElement.GetDisplayName: string;
begin
  Result := FName;
  if Result = '' then
    Result := inherited GetDisplayName;
end;

{ TGuiElementList }

constructor TGuiElementList.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner, TGuiElement);
end;

function TGuiElementList.Add: TGuiElement;
begin
  Result := TGuiElement(inherited Add);
end;

function TGuiElementList.FindItem(const AName: string): TGuiElement;
var
  LIndex: Integer;
begin
  Result := nil;
  for LIndex := 0 to Count - 1 do
    if SameText(Items[LIndex].Name, AName) then
      Exit(Items[LIndex]);
end;

function TGuiElementList.GetItem(Index: Integer): TGuiElement;
begin
  Result := TGuiElement(inherited GetItem(Index));
end;

procedure TGuiElementList.SetItem(Index: Integer; const Value: TGuiElement);
begin
  inherited SetItem(Index, Value);
end;

{ TGuiComponent }

constructor TGuiComponent.Create(Collection: TCollection);
begin
  inherited;
  FElements := TGuiElementList.Create(Self);
end;

destructor TGuiComponent.Destroy;
begin
  FElements.Free;
  inherited;
end;

procedure TGuiComponent.Assign(Source: TPersistent);
var
  LSource: TGuiComponent;
begin
  if Source is TGuiComponent then
  begin
    LSource := TGuiComponent(Source);
    FName := LSource.FName;
    FElements.Assign(LSource.FElements);
    Exit;
  end;

  inherited;
end;

procedure TGuiComponent.BuildVertices(AX1, AY1, AX2, AY2: Single; const ATextureSize: TVector2;
  var AVertices: TArray<TGuiVertex>; AScale: Single);
var
  LRects: TGuiDrawResult;
  LIndex: Integer;
  LElement: TGuiElement;
  LDest: TGuiRect;
  LSource: TGuiRect;
begin
  CalculateRects(AX1, AY1, AX2, AY2, ATextureSize, LRects, True, AScale);

  for LIndex := 0 to FElements.Count - 1 do
  begin
    LElement := FElements[LIndex];
    if LElement.Align = gaBorder then
    begin
      AppendBorderQuad(AVertices, LElement, LRects, ATextureSize);
      Continue;
    end;

    LDest := LRects[LElement.Align];
    LSource := SourceRectFromElement(LElement);
    AppendTiledQuad(AVertices, LDest, LSource, ATextureSize);
  end;
end;

procedure TGuiComponent.CalculateRects(AX1, AY1, AX2, AY2: Single; const ATextureSize: TVector2;
  out AResult: TGuiDrawResult; ARefresh: Boolean; AScale: Single);
var
  LAlignment: TGuiAlignment;
  LIndex: Integer;
  LElement: TGuiElement;
  LWidth: Single;
  LHeight: Single;
  LBorderX: Single;
  LBorderY: Single;
  LScale: Single;

  function ElementWidth(AElement: TGuiElement): Single;
  begin
    Result := Abs((AElement.BottomRight.X - AElement.TopLeft.X) * AElement.Scale.X * AScale);
  end;

  function ElementHeight(AElement: TGuiElement): Single;
  begin
    Result := Abs((AElement.BottomRight.Y - AElement.TopLeft.Y) * AElement.Scale.Y * AScale);
  end;

  procedure AssignTileCount(var ARect: TGuiRect; AElement: TGuiElement);
  var
    LSourceWidth: Single;
    LSourceHeight: Single;
  begin
    LSourceWidth := Abs(AElement.BottomRight.X - AElement.TopLeft.X);
    LSourceHeight := Abs(AElement.BottomRight.Y - AElement.TopLeft.Y);
    ARect.XTiles := System.Math.Max(1.0, SafeDiv(ARect.Width, LSourceWidth * AElement.Scale.X * AScale));
    ARect.YTiles := System.Math.Max(1.0, SafeDiv(ARect.Height, LSourceHeight * AElement.Scale.Y * AScale));
  end;

begin
  for LAlignment := Low(TGuiAlignment) to High(TGuiAlignment) do
    AResult[LAlignment] := GuiNullRect;

  AResult[gaTopLeft] := TGuiRect.Create(AX1, AY1, AX1, AY1);
  AResult[gaTopRight] := TGuiRect.Create(AX2, AY1, AX2, AY1);
  AResult[gaBottomLeft] := TGuiRect.Create(AX1, AY2, AX1, AY2);
  AResult[gaBottomRight] := TGuiRect.Create(AX2, AY2, AX2, AY2);

  if ARefresh then
  begin
    for LIndex := 0 to FElements.Count - 1 do
    begin
      LElement := FElements[LIndex];
      if LElement.Align <> gaBorder then
        Continue;

      LScale := LElement.Scale.Z;
      if SameValue(LScale, 0.0) then
        LScale := 1.0;

      LBorderX := Abs(LElement.Scale.X * LScale * AScale);
      LBorderY := Abs(LElement.Scale.Y * LScale * AScale);

      AResult[gaTopLeft] := TGuiRect.Create(AX1, AY1, AX1 + LBorderX, AY1 + LBorderY);
      AResult[gaTopRight] := TGuiRect.Create(AX2 - LBorderX, AY1, AX2, AY1 + LBorderY);
      AResult[gaBottomLeft] := TGuiRect.Create(AX1, AY2 - LBorderY, AX1 + LBorderX, AY2);
      AResult[gaBottomRight] := TGuiRect.Create(AX2 - LBorderX, AY2 - LBorderY, AX2, AY2);
    end;

    for LIndex := 0 to FElements.Count - 1 do
    begin
      LElement := FElements[LIndex];
      LWidth := ElementWidth(LElement);
      LHeight := ElementHeight(LElement);

      case LElement.Align of
        gaTopLeft:
          AResult[gaTopLeft] := TGuiRect.Create(AX1, AY1, AX1 + LWidth, AY1 + LHeight);
        gaTopRight:
          AResult[gaTopRight] := TGuiRect.Create(AX2 - LWidth, AY1, AX2, AY1 + LHeight);
        gaBottomLeft:
          AResult[gaBottomLeft] := TGuiRect.Create(AX1, AY2 - LHeight, AX1 + LWidth, AY2);
        gaBottomRight:
          AResult[gaBottomRight] := TGuiRect.Create(AX2 - LWidth, AY2 - LHeight, AX2, AY2);
      end;
    end;

    AResult[gaTop] := TGuiRect.Create(AResult[gaTopLeft].X2, AY1, AResult[gaTopRight].X1,
      System.Math.Max(AResult[gaTopLeft].Y2, AResult[gaTopRight].Y2));
    AResult[gaBottom] := TGuiRect.Create(AResult[gaBottomLeft].X2,
      System.Math.Min(AResult[gaBottomLeft].Y1, AResult[gaBottomRight].Y1),
      AResult[gaBottomRight].X1, AY2);
    AResult[gaLeft] := TGuiRect.Create(AX1, AResult[gaTopLeft].Y2,
      System.Math.Max(AResult[gaTopLeft].X2, AResult[gaBottomLeft].X2), AResult[gaBottomLeft].Y1);
    AResult[gaRight] := TGuiRect.Create(System.Math.Min(AResult[gaTopRight].X1, AResult[gaBottomRight].X1),
      AResult[gaTopRight].Y2, AX2, AResult[gaBottomRight].Y1);

    for LIndex := 0 to FElements.Count - 1 do
    begin
      LElement := FElements[LIndex];
      LWidth := ElementWidth(LElement);
      LHeight := ElementHeight(LElement);

      case LElement.Align of
        gaTop:
          AResult[gaTop].Y2 := AY1 + LHeight;
        gaBottom:
          AResult[gaBottom].Y1 := AY2 - LHeight;
        gaLeft:
          AResult[gaLeft].X2 := AX1 + LWidth;
        gaRight:
          AResult[gaRight].X1 := AX2 - LWidth;
      end;
    end;

    AResult[gaCenter] := TGuiRect.Create(AResult[gaLeft].X2, AResult[gaTop].Y2,
      AResult[gaRight].X1, AResult[gaBottom].Y1);
  end
  else
  begin
    AResult[gaCenter] := TGuiRect.Create(AX1, AY1, AX2, AY2);
  end;

  for LAlignment := Low(TGuiAlignment) to gaBottomRight do
    AResult[LAlignment] := ClampRect(AResult[LAlignment]);

  for LIndex := 0 to FElements.Count - 1 do
  begin
    LElement := FElements[LIndex];
    if LElement.Align = gaBorder then
      Continue;
    AssignTileCount(AResult[LElement.Align], LElement);
  end;
end;

function TGuiComponent.GetDisplayName: string;
begin
  Result := FName;
  if Result = '' then
    Result := inherited GetDisplayName;
end;

function TGuiComponent.HitTest(AX, AY, AX1, AY1, AX2, AY2: Single; const ATextureSize: TVector2;
  AScale: Single): Boolean;
var
  LRects: TGuiDrawResult;
begin
  CalculateRects(AX1, AY1, AX2, AY2, ATextureSize, LRects, True, AScale);
  Result := (AX >= AX1) and (AX <= AX2) and (AY >= AY1) and (AY <= AY2);
end;

{ TGuiComponentList }

constructor TGuiComponentList.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner, TGuiComponent);
end;

function TGuiComponentList.Add: TGuiComponent;
begin
  Result := TGuiComponent(inherited Add);
end;

function TGuiComponentList.FindItem(const AName: string): TGuiComponent;
var
  LIndex: Integer;
begin
  Result := nil;
  for LIndex := 0 to Count - 1 do
    if SameText(Items[LIndex].Name, AName) then
      Exit(Items[LIndex]);
end;

function TGuiComponentList.GetItem(Index: Integer): TGuiComponent;
begin
  Result := TGuiComponent(inherited GetItem(Index));
end;

procedure TGuiComponentList.SetItem(Index: Integer; const Value: TGuiComponent);
begin
  inherited SetItem(Index, Value);
end;

{ TGuiLayout }

constructor TGuiLayout.Create(AOwner: TComponent);
begin
  inherited;
  FComponents := TGuiComponentList.Create(Self);
  FTexture := TGuiTexture.Create;
end;

destructor TGuiLayout.Destroy;
begin
  FTexture.Free;
  FComponents.Free;
  inherited;
end;

procedure TGuiLayout.Clear;
begin
  FComponents.Clear;
end;

function TGuiLayout.FindComponent(const AName: string): TGuiComponent;
begin
  Result := FComponents.FindItem(AName);
end;

procedure TGuiLayout.LoadFromFile(const AFileName: string);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    LoadFromStream(LStream);
  finally
    LStream.Free;
  end;
end;

procedure TGuiLayout.LoadFromStream(AStream: TStream);
var
  LVersion: Integer;
  LComponentCount: Integer;
  LElementCount: Integer;
  LAlignmentCount: Integer;
  LComponentIndex: Integer;
  LElementIndex: Integer;
  LAlignmentIndex: Integer;
  LAlignmentOrdinal: Integer;
  LComponent: TGuiComponent;
  LElement: TGuiElement;
begin
  Clear;
  LVersion := ReadInteger(AStream);
  if LVersion <> GUI_LAYOUT_VERSION then
    raise EInvalidOperation.CreateFmt('Unsupported GUI layout version %d.', [LVersion]);

  LComponentCount := ReadInteger(AStream);
  for LComponentIndex := 0 to LComponentCount - 1 do
  begin
    LComponent := FComponents.Add;
    LComponent.Name := ReadStringValue(AStream);
    LElementCount := ReadInteger(AStream);

    for LElementIndex := 0 to LElementCount - 1 do
    begin
      LElement := LComponent.Elements.Add;
      LElement.Name := ReadStringValue(AStream);
      LElement.TopLeft := ReadVector3(AStream);
      LElement.BottomRight := ReadVector3(AStream);
      LElement.Scale := ReadVector3(AStream);

      LAlignmentCount := ReadInteger(AStream);
      for LAlignmentIndex := 0 to LAlignmentCount - 1 do
      begin
        LAlignmentOrdinal := ReadInteger(AStream);
        if (LAlignmentIndex = 0) and (LAlignmentOrdinal >= Ord(Low(TGuiAlignment))) and
          (LAlignmentOrdinal <= Ord(High(TGuiAlignment))) then
          LElement.Align := TGuiAlignment(LAlignmentOrdinal);
      end;
    end;
  end;
end;

procedure TGuiLayout.SaveToFile(const AFileName: string);
var
  LStream: TFileStream;
begin
  ForceDirectories(ExtractFilePath(AFileName));
  LStream := TFileStream.Create(AFileName, fmCreate);
  try
    SaveToStream(LStream);
  finally
    LStream.Free;
  end;
end;

procedure TGuiLayout.SaveToStream(AStream: TStream);
var
  LComponentIndex: Integer;
  LElementIndex: Integer;
  LComponent: TGuiComponent;
  LElement: TGuiElement;
begin
  WriteInteger(AStream, GUI_LAYOUT_VERSION);
  WriteInteger(AStream, FComponents.Count);

  for LComponentIndex := 0 to FComponents.Count - 1 do
  begin
    LComponent := FComponents[LComponentIndex];
    WriteStringValue(AStream, LComponent.Name);
    WriteInteger(AStream, LComponent.Elements.Count);

    for LElementIndex := 0 to LComponent.Elements.Count - 1 do
    begin
      LElement := LComponent.Elements[LElementIndex];
      WriteStringValue(AStream, LElement.Name);
      WriteVector3(AStream, LElement.TopLeft);
      WriteVector3(AStream, LElement.BottomRight);
      WriteVector3(AStream, LElement.Scale);
      WriteInteger(AStream, 1);
      WriteInteger(AStream, Ord(LElement.Align));
    end;
  end;
end;

procedure TGuiLayout.SetTextureFileName(const Value: string);
begin
  if SameText(FTextureFileName, Value) and
     ((FTextureFileName = '') or (FTexture.TextureID <> 0)) then
    Exit;

  FTextureFileName := Value;
  if FTextureFileName = '' then
    FTexture.Clear
  else
    FTexture.LoadFromFile(FTextureFileName);
end;

{ TGuiRenderer }

constructor TGuiRenderer.Create(const AVertexShaderFile, AFragmentShaderFile: string);
begin
  inherited Create;
  FOwnsShader := True;
  FOpacity := 1.0;
  FColorKeyEnabled := False;
  FColorKey := Vector3(0.0, 0.0, 0.0);
  FColorKeyTolerance := 0.01;
  FShader := TShader.Create(AVertexShaderFile, AFragmentShaderFile);
  CreateBuffers;
  CreateWhiteTexture;
end;

constructor TGuiRenderer.Create(AShader: TShader; AOwnsShader: Boolean);
begin
  inherited Create;
  FShader := AShader;
  FOwnsShader := AOwnsShader;
  FOpacity := 1.0;
  FColorKeyEnabled := False;
  FColorKey := Vector3(0.0, 0.0, 0.0);
  FColorKeyTolerance := 0.01;
  CreateBuffers;
  CreateWhiteTexture;
end;

destructor TGuiRenderer.Destroy;
begin
  DestroyWhiteTexture;
  DestroyBuffers;
  if FOwnsShader then
    FShader.Free;
  inherited;
end;

procedure TGuiRenderer.CreateBuffers;
begin
  glGenVertexArrays(1, @FVAO);
  glGenBuffers(1, @FVBO);

  glBindVertexArray(FVAO);
  glBindBuffer(GL_ARRAY_BUFFER, FVBO);
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, SizeOf(TGuiVertex), nil);
  glEnableVertexAttribArray(1);
  glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, SizeOf(TGuiVertex), Pointer(SizeOf(TVector2)));
  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glBindVertexArray(0);
end;

procedure TGuiRenderer.CreateWhiteTexture;
var
  LPixel: array[0..3] of Byte;
begin
  LPixel[0] := 255;
  LPixel[1] := 255;
  LPixel[2] := 255;
  LPixel[3] := 255;

  glGenTextures(1, @FWhiteTextureID);
  glBindTexture(GL_TEXTURE_2D, FWhiteTextureID);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 1, 1, 0, GL_RGBA, GL_UNSIGNED_BYTE, @LPixel[0]);
  glBindTexture(GL_TEXTURE_2D, 0);
end;

procedure TGuiRenderer.DestroyBuffers;
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

procedure TGuiRenderer.DestroyWhiteTexture;
begin
  if FWhiteTextureID <> 0 then
  begin
    glDeleteTextures(1, @FWhiteTextureID);
    FWhiteTextureID := 0;
  end;
end;

procedure TGuiRenderer.RenderComponent(AComponent: TGuiComponent; ATexture: TGuiTexture;
  AX, AY, AWidth, AHeight: Single; AViewportWidth, AViewportHeight: Integer;
  const ATint: TVector4; AScale: Single);
var
  LVertices: TArray<TGuiVertex>;
  LTextureSize: TVector2;
begin
  if (AComponent = nil) or (ATexture = nil) or (ATexture.TextureID = 0) then
    Exit;

  LTextureSize := Vector2(ATexture.Width, ATexture.Height);
  AComponent.BuildVertices(AX, AY, AX + AWidth, AY + AHeight, LTextureSize, LVertices, AScale);
  RenderVertices(LVertices, ATexture.TextureID, AViewportWidth, AViewportHeight, ATint);
end;

procedure TGuiRenderer.RenderLayout(ALayout: TGuiLayout; const AComponentName: string;
  AX, AY, AWidth, AHeight: Single; AViewportWidth, AViewportHeight: Integer;
  const ATint: TVector4; AScale: Single);
begin
  if ALayout = nil then
    Exit;
  RenderComponent(ALayout.FindComponent(AComponentName), ALayout.Texture, AX, AY, AWidth, AHeight,
    AViewportWidth, AViewportHeight, ATint, AScale);
end;

procedure TGuiRenderer.RenderSolidRect(AX, AY, AWidth, AHeight: Single;
  AViewportWidth, AViewportHeight: Integer; const AColor: TVector4);
var
  LVertices: TArray<TGuiVertex>;

  procedure SetVertex(AIndex: Integer; AXPos, AYPos, AU, AV: Single);
  begin
    LVertices[AIndex].Position := Vector2(AXPos, AYPos);
    LVertices[AIndex].TexCoord := Vector2(AU, AV);
  end;

begin
  if (AWidth <= 0.0) or (AHeight <= 0.0) or (FWhiteTextureID = 0) then
    Exit;

  SetLength(LVertices, 6);
  SetVertex(0, AX, AY, 0.0, 0.0);
  SetVertex(1, AX, AY + AHeight, 0.0, 1.0);
  SetVertex(2, AX + AWidth, AY + AHeight, 1.0, 1.0);
  SetVertex(3, AX, AY, 0.0, 0.0);
  SetVertex(4, AX + AWidth, AY + AHeight, 1.0, 1.0);
  SetVertex(5, AX + AWidth, AY, 1.0, 0.0);

  RenderVertices(LVertices, FWhiteTextureID, AViewportWidth, AViewportHeight, AColor);
end;

procedure TGuiRenderer.RenderVertices(const AVertices: TArray<TGuiVertex>; ATextureID: GLuint;
  AViewportWidth, AViewportHeight: Integer; const ATint: TVector4);
begin
  if (Length(AVertices) = 0) or (ATextureID = 0) or (FShader = nil) or
    (AViewportWidth <= 0) or (AViewportHeight <= 0) then
    Exit;

  glDisable(GL_DEPTH_TEST);
  glDisable(GL_CULL_FACE);
  glEnable(GL_BLEND);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

  FShader.Use;
  FShader.SetUniform('viewportSize', Vector2(AViewportWidth, AViewportHeight));
  FShader.SetUniform('tintColor', ATint);
  FShader.SetUniform('opacity', FOpacity);
  FShader.SetUniform('colorKeyEnabled', FColorKeyEnabled);
  FShader.SetUniform('colorKey', FColorKey);
  FShader.SetUniform('colorKeyTolerance', FColorKeyTolerance);
  FShader.SetUniform('guiTexture', 0);

  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, ATextureID);

  glBindVertexArray(FVAO);
  glBindBuffer(GL_ARRAY_BUFFER, FVBO);
  glBufferData(GL_ARRAY_BUFFER, Length(AVertices) * SizeOf(TGuiVertex), @AVertices[0], GL_DYNAMIC_DRAW);
  glDrawArrays(GL_TRIANGLES, 0, Length(AVertices));

  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glBindVertexArray(0);
  glBindTexture(GL_TEXTURE_2D, 0);
end;

procedure TGuiRenderer.SetColorKeyTolerance(const Value: Single);
begin
  FColorKeyTolerance := System.Math.Max(0.0, Value);
end;

procedure TGuiRenderer.SetOpacity(const Value: Single);
begin
  FOpacity := System.Math.Min(1.0, System.Math.Max(0.0, Value));
end;

{ TGuiControl }

constructor TGuiControl.Create(AOwner: TComponent);
begin
  inherited;
  FChildren := TObjectList<TGuiControl>.Create(False);
  FScale := 1.0;
  FTint := Vector4(1.0, 1.0, 1.0, 1.0);
  FVisible := True;
end;

destructor TGuiControl.Destroy;
begin
  SetParent(nil);
  FChildren.Free;
  inherited;
end;

procedure TGuiControl.AddChild(AChild: TGuiControl);
begin
  InsertChild(FChildren.Count, AChild);
end;

function TGuiControl.GetAbsoluteLeft: Single;
begin
  Result := FLeft;
  if FParent <> nil then
    Result := Result + FParent.AbsoluteLeft;
end;

function TGuiControl.GetAbsoluteTop: Single;
begin
  Result := FTop;
  if FParent <> nil then
    Result := Result + FParent.AbsoluteTop;
end;

function TGuiControl.GetChild(Index: Integer): TGuiControl;
begin
  Result := FChildren[Index];
end;

function TGuiControl.GetChildCount: Integer;
begin
  Result := FChildren.Count;
end;

function TGuiControl.GetRecursiveVisible: Boolean;
begin
  Result := FVisible and ((FParent = nil) or FParent.RecursiveVisible);
end;

procedure TGuiControl.InsertChild(Index: Integer; AChild: TGuiControl);
begin
  if AChild = nil then
    Exit;
  AChild.SetParent(nil);
  AChild.FParent := Self;
  FChildren.Insert(Index, AChild);
end;

procedure TGuiControl.RemoveChild(AChild: TGuiControl);
begin
  if AChild = nil then
    Exit;
  if FChildren.Remove(AChild) >= 0 then
    AChild.FParent := nil;
end;

procedure TGuiControl.Render(ARenderer: TGuiRenderer; AViewportWidth, AViewportHeight: Integer);
var
  LIndex: Integer;
begin
  if (ARenderer = nil) or not RecursiveVisible then
    Exit;

  ARenderer.RenderLayout(FLayout, FComponentName, AbsoluteLeft, AbsoluteTop, FWidth, FHeight,
    AViewportWidth, AViewportHeight, FTint, FScale);

  for LIndex := 0 to FChildren.Count - 1 do
    FChildren[LIndex].Render(ARenderer, AViewportWidth, AViewportHeight);
end;

procedure TGuiControl.SetParent(const Value: TGuiControl);
begin
  if FParent = Value then
    Exit;

  if FParent <> nil then
    FParent.FChildren.Remove(Self);

  FParent := Value;

  if (FParent <> nil) and (FParent.FChildren.IndexOf(Self) < 0) then
    FParent.FChildren.Add(Self);
end;

end.
