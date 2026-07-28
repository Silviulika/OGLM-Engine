unit Engine.GUI.Editor;

interface

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.Math, System.IOUtils,
  Neslib.FastMath, PasImGui,
  Engine.Paths, Engine.Gui;

type
  TGuiEditorCanvasKind = (
    geckNone,
    geckComponentPreview,
    geckAtlas
  );

  TGuiEditorFileMode = (
    gefNone,
    gefOpenLayout,
    gefSaveLayout,
    gefImportLayout,
    gefSelectAtlas
  );

  TGuiEditorImGui = class
  private
    FActive: Boolean;
    FDirty: Boolean;
    FLayout: TGuiLayout;
    FCurrentFileName: string;
    FSelectedComponentIndex: Integer;
    FSelectedElementIndex: Integer;
    FComponentName: array[0..127] of AnsiChar;
    FElementName: array[0..127] of AnsiChar;
    FPreviewSize: array[0..1] of Single;
    FPreviewZoom: Single;
    FPreviewPan: ImVec2;
    FPreviewPanning: Boolean;
    FPreviewPanStartMouse: ImVec2;
    FPreviewPanStartOffset: ImVec2;
    FAtlasZoom: Single;
    FAtlasPan: ImVec2;
    FAtlasPanning: Boolean;
    FAtlasPanStartMouse: ImVec2;
    FAtlasPanStartOffset: ImVec2;
    FAtlasSelecting: Boolean;
    FAtlasSelectionStart: TVector2;
    FVisibleCanvasKind: TGuiEditorCanvasKind;
    FVisibleCanvasPosition: ImVec2;
    FVisibleCanvasSize: ImVec2;
    FVisibleContentPosition: ImVec2;
    FVisibleContentScale: Single;
    FVisibleContentBaseScale: Single;
    FVisibleContentWidth: Single;
    FVisibleContentHeight: Single;
    FLastError: string;
    FFileMode: TGuiEditorFileMode;
    FFileDialogOpenRequested: Boolean;
    FFileItems: TArray<string>;
    FFileSelectedIndex: Integer;
    FFileName: array[0..255] of AnsiChar;
    FFileSearch: array[0..127] of AnsiChar;
    FFileDialogError: string;
    FPendingOverwriteFileName: string;
    procedure AddComponent;
    procedure AddElement;
    procedure DeleteSelectedComponent;
    procedure DeleteSelectedElement;
    procedure DrawAtlasCanvas;
    procedure DrawComponentList;
    procedure DrawComponentPreview;
    procedure DrawElementProperties;
    procedure DrawFileDialog;
    procedure DrawMainMenu;
    procedure DrawWorkspace;
    procedure DuplicateSelectedComponent;
    procedure DuplicateSelectedElement;
    procedure ExecuteFileDialogAction;
    function FileDialogTitle: string;
    procedure ImportLayout(const AFileName: string);
    function IsTextureFile(const AFileName: string): Boolean;
    procedure LoadDefaultAtlas;
    procedure LoadLayout(const AFileName: string);
    procedure MarkDirty;
    function SelectedComponent: TGuiComponent;
    function SelectedElement: TGuiElement;
    procedure NewLayout;
    procedure OpenFileDialog(AMode: TGuiEditorFileMode);
    procedure RefreshFileItems;
    procedure SaveLayout(const AFileName: string);
    procedure SelectComponent(AIndex: Integer);
    procedure SelectElement(AIndex: Integer);
    procedure SetCurrentFileName(const AFileName: string);
    procedure SetLayoutAtlas(const AFileName: string);
    function UniqueComponentName(const ABaseName: string;
      AIgnore: TGuiComponent = nil): string;
    function UniqueElementName(AComponent: TGuiComponent;
      const ABaseName: string; AIgnore: TGuiElement = nil): string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Draw;
    function HandleMouseWheel(X, Y, WheelDelta: Integer): Boolean;
    procedure Open;
    property Active: Boolean read FActive write FActive;
    property Layout: TGuiLayout read FLayout;
  end;

implementation

const
  GUI_LAYOUT_EXTENSION = '.layout';
  GUI_FILE_POPUP_NAME = 'GUI Asset Browser###GuiEditorFileBrowser';
  GUI_ALIGN_NAMES: array[TGuiAlignment] of string = (
    'Top Left',
    'Top',
    'Top Right',
    'Left',
    'Center',
    'Right',
    'Bottom Left',
    'Bottom',
    'Bottom Right',
    'Border'
  );
  PREVIEW_MIN_ZOOM = 0.25;
  PREVIEW_MAX_ZOOM = 8.0;
  ATLAS_MIN_ZOOM = 0.25;
  ATLAS_MAX_ZOOM = 16.0;
  CANVAS_MIN_HEIGHT = 320.0;

procedure SetTextBuffer(var ABuffer: array of AnsiChar; const AValue: string);
var
  TextValue: AnsiString;
  Count: Integer;
begin
  if Length(ABuffer) = 0 then
    Exit;

  FillChar(ABuffer[0], Length(ABuffer) * SizeOf(AnsiChar), 0);
  TextValue := AnsiString(AValue);
  Count := System.Math.Min(Length(TextValue), Length(ABuffer) - 1);
  if Count > 0 then
    Move(TextValue[1], ABuffer[0], Count * SizeOf(AnsiChar));
end;

function TextBufferValue(var ABuffer: array of AnsiChar): string;
begin
  if Length(ABuffer) = 0 then
    Exit('');
  Result := Trim(string(AnsiString(PAnsiChar(@ABuffer[0]))));
end;

function ClampSingle(const AValue, AMinimum, AMaximum: Single): Single;
begin
  Result := System.Math.Min(AMaximum, System.Math.Max(AMinimum, AValue));
end;

function ImPoint(AX, AY: Single): ImVec2;
begin
  Result := ImVec2.New(AX, AY);
end;

function ScreenPointToTexture(const AMouse, AImagePosition: ImVec2;
  AImageScale: Single; ATextureWidth, ATextureHeight: Integer;
  out ATexturePoint: TVector2): Boolean;
begin
  Result := (AImageScale > 0.0) and
    (AMouse.x >= AImagePosition.x) and
    (AMouse.y >= AImagePosition.y) and
    (AMouse.x <= AImagePosition.x + (ATextureWidth * AImageScale)) and
    (AMouse.y <= AImagePosition.y + (ATextureHeight * AImageScale));
  if not Result then
    Exit;

  ATexturePoint := Vector2(
    ClampSingle((AMouse.x - AImagePosition.x) / AImageScale, 0.0,
      ATextureWidth),
    ClampSingle((AMouse.y - AImagePosition.y) / AImageScale, 0.0,
      ATextureHeight)
  );
end;

function PointInElementRect(const APoint: TVector2;
  AElement: TGuiElement): Boolean;
var
  LeftValue: Single;
  TopValue: Single;
  RightValue: Single;
  BottomValue: Single;
begin
  LeftValue := System.Math.Min(AElement.TopLeft.X, AElement.BottomRight.X);
  TopValue := System.Math.Min(AElement.TopLeft.Y, AElement.BottomRight.Y);
  RightValue := System.Math.Max(AElement.TopLeft.X, AElement.BottomRight.X);
  BottomValue := System.Math.Max(AElement.TopLeft.Y, AElement.BottomRight.Y);
  Result := (APoint.X >= LeftValue) and (APoint.X <= RightValue) and
    (APoint.Y >= TopValue) and (APoint.Y <= BottomValue);
end;

{ TGuiEditorImGui }

constructor TGuiEditorImGui.Create;
begin
  inherited Create;
  FLayout := TGuiLayout.Create(nil);
  FSelectedComponentIndex := -1;
  FSelectedElementIndex := -1;
  FPreviewSize[0] := 360.0;
  FPreviewSize[1] := 240.0;
  FPreviewZoom := 1.0;
  FPreviewPan := ImPoint(0, 0);
  FAtlasZoom := 1.0;
  FAtlasPan := ImPoint(0, 0);
  FFileMode := gefNone;
  FFileSelectedIndex := -1;
  SetTextBuffer(FComponentName, '');
  SetTextBuffer(FElementName, '');
  SetTextBuffer(FFileName, 'Untitled' + GUI_LAYOUT_EXTENSION);
  SetTextBuffer(FFileSearch, '');
  LoadDefaultAtlas;
end;

destructor TGuiEditorImGui.Destroy;
begin
  FLayout.Free;
  inherited;
end;

procedure TGuiEditorImGui.AddComponent;
var
  Component: TGuiComponent;
begin
  Component := FLayout.Components.Add;
  Component.Name := UniqueComponentName('Component');
  SelectComponent(FLayout.Components.Count - 1);
  MarkDirty;
end;

procedure TGuiEditorImGui.AddElement;
var
  Component: TGuiComponent;
  Element: TGuiElement;
begin
  Component := SelectedComponent;
  if Component = nil then
    Exit;

  Element := Component.Elements.Add;
  Element.Name := UniqueElementName(Component, 'Element');
  Element.TopLeft := Vector3(0, 0, 0);
  Element.BottomRight := Vector3(32, 32, 0);
  Element.Scale := Vector3(1, 1, 1);
  Element.Align := gaCenter;
  SelectElement(Component.Elements.Count - 1);
  MarkDirty;
end;

procedure TGuiEditorImGui.DeleteSelectedComponent;
var
  Index: Integer;
begin
  if SelectedComponent = nil then
    Exit;

  Index := FSelectedComponentIndex;
  FLayout.Components.Delete(Index);
  if Index >= FLayout.Components.Count then
    Index := FLayout.Components.Count - 1;
  SelectComponent(Index);
  MarkDirty;
end;

procedure TGuiEditorImGui.DeleteSelectedElement;
var
  Component: TGuiComponent;
  Index: Integer;
begin
  Component := SelectedComponent;
  if (Component = nil) or (SelectedElement = nil) then
    Exit;

  Index := FSelectedElementIndex;
  Component.Elements.Delete(Index);
  if Index >= Component.Elements.Count then
    Index := Component.Elements.Count - 1;
  SelectElement(Index);
  MarkDirty;
end;

procedure TGuiEditorImGui.Draw;
var
  OpenWindow: Boolean;
  WindowTitle: string;
  AtlasFileName: string;
begin
  if not FActive then
  begin
    DrawFileDialog;
    Exit;
  end;

  if FCurrentFileName = '' then
    WindowTitle := 'GUI Layout Editor - Untitled'
  else
    WindowTitle := 'GUI Layout Editor - ' + ExtractFileName(FCurrentFileName);
  if FDirty then
    WindowTitle := WindowTitle + ' *';
  AtlasFileName := FLayout.Texture.FileName;
  if (AtlasFileName <> '') and (FLayout.Texture.Width > 0) and
     (FLayout.Texture.Height > 0) then
    WindowTitle := WindowTitle + Format(' | Atlas: %s (%dx%d)', [
      ExtractFileName(AtlasFileName), FLayout.Texture.Width,
      FLayout.Texture.Height]);
  if FLastError <> '' then
    WindowTitle := WindowTitle + ' | Error: ' + FLastError;
  WindowTitle := WindowTitle + '###EngineGuiEditor';

  ImGui.SetNextWindowPos(ImPoint(170, 70), ImGuiCond_FirstUseEver);
  ImGui.SetNextWindowSize(ImPoint(1180, 760), ImGuiCond_FirstUseEver);
  OpenWindow := True;
  if ImGui.Begin_(AnsiString(WindowTitle), @OpenWindow,
    ImGuiWindowFlags_MenuBar) then
  begin
    DrawMainMenu;

    if ImGui.BeginChild('GuiComponentPane', ImPoint(230, -1),
      ImGuiChildFlags_Border) then
      DrawComponentList;
    ImGui.EndChild;

    ImGui.SameLine;
    if ImGui.BeginChild('GuiWorkspacePane', ImPoint(-310, -1),
      ImGuiChildFlags_Border, ImGuiWindowFlags_NoScrollbar or
      ImGuiWindowFlags_NoScrollWithMouse) then
      DrawWorkspace;
    ImGui.EndChild;

    ImGui.SameLine;
    if ImGui.BeginChild('GuiPropertiesPane', ImPoint(0, -1),
      ImGuiChildFlags_Border) then
      DrawElementProperties;
    ImGui.EndChild;
  end;
  ImGui.End_;

  if not OpenWindow then
    FActive := False;

  DrawFileDialog;
end;

procedure TGuiEditorImGui.DrawAtlasCanvas;
var
  CanvasPosition: ImVec2;
  CanvasSize: ImVec2;
  ImagePosition: ImVec2;
  MousePosition: ImVec2;
  DrawList: PImDrawList;
  TextureID: ImTextureID;
  FitScale: Single;
  ImageScale: Single;
  ImageWidth: Single;
  ImageHeight: Single;
  TexturePoint: TVector2;
  Component: TGuiComponent;
  Element: TGuiElement;
  LeftValue: Single;
  TopValue: Single;
  RightValue: Single;
  BottomValue: Single;
  RectMin: ImVec2;
  RectMax: ImVec2;
  BorderColor: ImU32;
  I: Integer;
  HitIndex: Integer;
  Hovered: Boolean;
begin
  CanvasSize := ImGui.GetContentRegionAvail;
  CanvasSize.x := System.Math.Max(200.0, CanvasSize.x);
  CanvasSize.y := System.Math.Max(CANVAS_MIN_HEIGHT, CanvasSize.y);
  CanvasPosition := ImGui.GetCursorScreenPos;
  ImGui.InvisibleButton('GuiAtlasCanvas', CanvasSize);
  Hovered := ImGui.IsItemHovered;
  DrawList := ImGui.GetWindowDrawList;

  DrawList^.PushClipRect(CanvasPosition,
    ImPoint(CanvasPosition.x + CanvasSize.x, CanvasPosition.y + CanvasSize.y),
    True);
  DrawList^.AddRectFilled(CanvasPosition,
    ImPoint(CanvasPosition.x + CanvasSize.x, CanvasPosition.y + CanvasSize.y),
    IM_COL32(28, 31, 36, 255));

  if (FLayout.Texture.TextureID = 0) or
     (FLayout.Texture.Width <= 0) or (FLayout.Texture.Height <= 0) then
  begin
    DrawList^.AddRect(CanvasPosition,
      ImPoint(CanvasPosition.x + CanvasSize.x, CanvasPosition.y + CanvasSize.y),
      IM_COL32(85, 90, 98, 255), 0.0, ImDrawFlags_Closed, 1.0);
    DrawList^.PopClipRect;
    Exit;
  end;

  FitScale := System.Math.Min(
    System.Math.Max(1.0, CanvasSize.x - 32.0) / FLayout.Texture.Width,
    System.Math.Max(1.0, CanvasSize.y - 32.0) / FLayout.Texture.Height);
  ImageScale := System.Math.Max(0.01, FitScale * FAtlasZoom);
  ImageWidth := FLayout.Texture.Width * ImageScale;
  ImageHeight := FLayout.Texture.Height * ImageScale;
  ImagePosition := ImPoint(
    CanvasPosition.x + ((CanvasSize.x - ImageWidth) * 0.5) + FAtlasPan.x,
    CanvasPosition.y + ((CanvasSize.y - ImageHeight) * 0.5) + FAtlasPan.y);
  FVisibleCanvasKind := geckAtlas;
  FVisibleCanvasPosition := CanvasPosition;
  FVisibleCanvasSize := CanvasSize;
  FVisibleContentPosition := ImagePosition;
  FVisibleContentScale := ImageScale;
  FVisibleContentBaseScale := FitScale;
  FVisibleContentWidth := FLayout.Texture.Width;
  FVisibleContentHeight := FLayout.Texture.Height;

  TextureID := ImTextureID(NativeUInt(FLayout.Texture.TextureID));
  DrawList^.AddImage(TextureID, ImagePosition,
    ImPoint(ImagePosition.x + ImageWidth, ImagePosition.y + ImageHeight),
    ImPoint(0, 1), ImPoint(1, 0), IM_COL32(255, 255, 255, 255));
  DrawList^.AddRect(ImagePosition,
    ImPoint(ImagePosition.x + ImageWidth, ImagePosition.y + ImageHeight),
    IM_COL32(105, 112, 124, 255), 0.0, ImDrawFlags_Closed, 1.0);

  Component := SelectedComponent;
  if Component <> nil then
    for I := 0 to Component.Elements.Count - 1 do
    begin
      Element := Component.Elements[I];
      LeftValue := System.Math.Min(Element.TopLeft.X, Element.BottomRight.X);
      TopValue := System.Math.Min(Element.TopLeft.Y, Element.BottomRight.Y);
      RightValue := System.Math.Max(Element.TopLeft.X, Element.BottomRight.X);
      BottomValue := System.Math.Max(Element.TopLeft.Y, Element.BottomRight.Y);
      RectMin := ImPoint(ImagePosition.x + (LeftValue * ImageScale),
        ImagePosition.y + (TopValue * ImageScale));
      RectMax := ImPoint(ImagePosition.x + (RightValue * ImageScale),
        ImagePosition.y + (BottomValue * ImageScale));
      if I = FSelectedElementIndex then
        BorderColor := IM_COL32(255, 202, 76, 255)
      else
        BorderColor := IM_COL32(64, 185, 255, 220);
      DrawList^.AddRect(RectMin, RectMax, BorderColor, 0.0,
        ImDrawFlags_Closed, 2.0);
    end;

  DrawList^.PopClipRect;

  MousePosition := ImGui.GetMousePos;
  if Hovered and ImGui.IsMouseClicked(ImGuiMouseButton_Middle) then
  begin
    FAtlasPanning := True;
    FAtlasPanStartMouse := MousePosition;
    FAtlasPanStartOffset := FAtlasPan;
  end;
  if FAtlasPanning then
  begin
    if ImGui.IsMouseDown(ImGuiMouseButton_Middle) then
      FAtlasPan := ImPoint(
        FAtlasPanStartOffset.x + MousePosition.x - FAtlasPanStartMouse.x,
        FAtlasPanStartOffset.y + MousePosition.y - FAtlasPanStartMouse.y)
    else
      FAtlasPanning := False;
  end;

  if Hovered and ImGui.IsMouseClicked(ImGuiMouseButton_Left) and
     ScreenPointToTexture(MousePosition, ImagePosition, ImageScale,
       FLayout.Texture.Width, FLayout.Texture.Height, TexturePoint) then
  begin
    HitIndex := -1;
    if Component <> nil then
      for I := Component.Elements.Count - 1 downto 0 do
        if PointInElementRect(TexturePoint, Component.Elements[I]) then
        begin
          HitIndex := I;
          Break;
        end;

    if HitIndex >= 0 then
      SelectElement(HitIndex)
    else if SelectedElement <> nil then
    begin
      FAtlasSelecting := True;
      FAtlasSelectionStart := TexturePoint;
      Element := SelectedElement;
      Element.TopLeft := Vector3(TexturePoint.X, TexturePoint.Y,
        Element.TopLeft.Z);
      Element.BottomRight := Vector3(TexturePoint.X, TexturePoint.Y,
        Element.BottomRight.Z);
      MarkDirty;
    end;
  end;

  if FAtlasSelecting then
  begin
    if ImGui.IsMouseDown(ImGuiMouseButton_Left) then
    begin
      if ScreenPointToTexture(MousePosition, ImagePosition, ImageScale,
        FLayout.Texture.Width, FLayout.Texture.Height, TexturePoint) then
      begin
        Element := SelectedElement;
        if Element <> nil then
        begin
          Element.TopLeft := Vector3(
            System.Math.Min(FAtlasSelectionStart.X, TexturePoint.X),
            System.Math.Min(FAtlasSelectionStart.Y, TexturePoint.Y),
            Element.TopLeft.Z);
          Element.BottomRight := Vector3(
            System.Math.Max(FAtlasSelectionStart.X, TexturePoint.X),
            System.Math.Max(FAtlasSelectionStart.Y, TexturePoint.Y),
            Element.BottomRight.Z);
          MarkDirty;
        end;
      end;
    end
    else
      FAtlasSelecting := False;
  end;
end;

procedure TGuiEditorImGui.DrawComponentList;
var
  I: Integer;
  Component: TGuiComponent;
  Selected: Boolean;
  LabelText: string;
begin
  ImGui.Text('Components');
  ImGui.Separator;

  if ImGui.Button('+ Add') then
    AddComponent;
  ImGui.SameLine;
  if ImGui.Button('Duplicate') then
    DuplicateSelectedComponent;
  ImGui.SameLine;
  if ImGui.Button('Delete') then
    DeleteSelectedComponent;

  ImGui.Separator;
  if ImGui.BeginChild('GuiComponentList', ImPoint(-1, -78)) then
    for I := 0 to FLayout.Components.Count - 1 do
    begin
      Component := FLayout.Components[I];
      Selected := I = FSelectedComponentIndex;
      LabelText := Component.Name + '##GuiComponent' + IntToStr(I);
      if ImGui.Selectable(AnsiString(LabelText), Selected) then
        SelectComponent(I);
    end;
  ImGui.EndChild;

  ImGui.Separator;
  Component := SelectedComponent;
  if Component <> nil then
  begin
    ImGui.PushItemWidth(-1);
    if ImGui.InputText('##GuiComponentName', @FComponentName[0],
      SizeOf(FComponentName)) then
    begin
      Component.Name := UniqueComponentName(
        TextBufferValue(FComponentName), Component);
      SetTextBuffer(FComponentName, Component.Name);
      MarkDirty;
    end;
    ImGui.PopItemWidth;
  end;
end;

procedure TGuiEditorImGui.DrawComponentPreview;
var
  CanvasPosition: ImVec2;
  CanvasSize: ImVec2;
  PreviewPosition: ImVec2;
  MousePosition: ImVec2;
  DrawList: PImDrawList;
  TextureID: ImTextureID;
  Vertices: TArray<TGuiVertex>;
  Component: TGuiComponent;
  PreviewWidth: Single;
  PreviewHeight: Single;
  I: Integer;
  Hovered: Boolean;
begin
  ImGui.PushItemWidth(180);
  if ImGui.DragFloat2('Size', @FPreviewSize[0], 1.0, 1.0, 4096.0,
    '%.0f') then
  begin
    FPreviewSize[0] := System.Math.Max(1.0, FPreviewSize[0]);
    FPreviewSize[1] := System.Math.Max(1.0, FPreviewSize[1]);
  end;
  ImGui.SameLine;
  if ImGui.SliderFloat('Zoom', @FPreviewZoom, PREVIEW_MIN_ZOOM,
    PREVIEW_MAX_ZOOM, '%.2fx') then
    FPreviewZoom := ClampSingle(FPreviewZoom, PREVIEW_MIN_ZOOM,
      PREVIEW_MAX_ZOOM);
  ImGui.SameLine;
  if ImGui.Button('Reset view') then
  begin
    FPreviewZoom := 1.0;
    FPreviewPan := ImPoint(0, 0);
  end;
  ImGui.PopItemWidth;

  CanvasSize := ImGui.GetContentRegionAvail;
  CanvasSize.x := System.Math.Max(200.0, CanvasSize.x);
  CanvasSize.y := System.Math.Max(CANVAS_MIN_HEIGHT, CanvasSize.y);
  CanvasPosition := ImGui.GetCursorScreenPos;
  ImGui.InvisibleButton('GuiComponentPreviewCanvas', CanvasSize);
  Hovered := ImGui.IsItemHovered;
  DrawList := ImGui.GetWindowDrawList;

  DrawList^.PushClipRect(CanvasPosition,
    ImPoint(CanvasPosition.x + CanvasSize.x, CanvasPosition.y + CanvasSize.y),
    True);
  DrawList^.AddRectFilled(CanvasPosition,
    ImPoint(CanvasPosition.x + CanvasSize.x, CanvasPosition.y + CanvasSize.y),
    IM_COL32(28, 31, 36, 255));

  PreviewWidth := FPreviewSize[0] * FPreviewZoom;
  PreviewHeight := FPreviewSize[1] * FPreviewZoom;
  PreviewPosition := ImPoint(
    CanvasPosition.x + ((CanvasSize.x - PreviewWidth) * 0.5) + FPreviewPan.x,
    CanvasPosition.y + ((CanvasSize.y - PreviewHeight) * 0.5) + FPreviewPan.y);
  FVisibleCanvasKind := geckComponentPreview;
  FVisibleCanvasPosition := CanvasPosition;
  FVisibleCanvasSize := CanvasSize;
  FVisibleContentPosition := PreviewPosition;
  FVisibleContentScale := FPreviewZoom;
  FVisibleContentBaseScale := 1.0;
  FVisibleContentWidth := FPreviewSize[0];
  FVisibleContentHeight := FPreviewSize[1];
  DrawList^.AddRectFilled(PreviewPosition,
    ImPoint(PreviewPosition.x + PreviewWidth,
      PreviewPosition.y + PreviewHeight),
    IM_COL32(13, 15, 18, 255));

  Component := SelectedComponent;
  if (Component <> nil) and (Component.Elements.Count > 0) and
     (FLayout.Texture.TextureID <> 0) and
     (FLayout.Texture.Width > 0) and (FLayout.Texture.Height > 0) then
  begin
    SetLength(Vertices, 0);
    Component.BuildVertices(0, 0, PreviewWidth, PreviewHeight,
      Vector2(FLayout.Texture.Width, FLayout.Texture.Height), Vertices,
      FPreviewZoom);
    TextureID := ImTextureID(NativeUInt(FLayout.Texture.TextureID));
    I := 0;
    while I + 5 < Length(Vertices) do
    begin
      DrawList^.AddImageQuad(TextureID,
        ImPoint(PreviewPosition.x + Vertices[I].Position.X,
          PreviewPosition.y + Vertices[I].Position.Y),
        ImPoint(PreviewPosition.x + Vertices[I + 5].Position.X,
          PreviewPosition.y + Vertices[I + 5].Position.Y),
        ImPoint(PreviewPosition.x + Vertices[I + 2].Position.X,
          PreviewPosition.y + Vertices[I + 2].Position.Y),
        ImPoint(PreviewPosition.x + Vertices[I + 1].Position.X,
          PreviewPosition.y + Vertices[I + 1].Position.Y),
        ImPoint(Vertices[I].TexCoord.X, Vertices[I].TexCoord.Y),
        ImPoint(Vertices[I + 5].TexCoord.X, Vertices[I + 5].TexCoord.Y),
        ImPoint(Vertices[I + 2].TexCoord.X, Vertices[I + 2].TexCoord.Y),
        ImPoint(Vertices[I + 1].TexCoord.X, Vertices[I + 1].TexCoord.Y),
        IM_COL32(255, 255, 255, 255));
      Inc(I, 6);
    end;
  end;

  DrawList^.AddRect(PreviewPosition,
    ImPoint(PreviewPosition.x + PreviewWidth,
      PreviewPosition.y + PreviewHeight),
    IM_COL32(72, 166, 232, 255), 0.0, ImDrawFlags_Closed, 2.0);
  DrawList^.PopClipRect;

  MousePosition := ImGui.GetMousePos;
  if Hovered and ImGui.IsMouseClicked(ImGuiMouseButton_Middle) then
  begin
    FPreviewPanning := True;
    FPreviewPanStartMouse := MousePosition;
    FPreviewPanStartOffset := FPreviewPan;
  end;
  if FPreviewPanning then
  begin
    if ImGui.IsMouseDown(ImGuiMouseButton_Middle) then
      FPreviewPan := ImPoint(
        FPreviewPanStartOffset.x + MousePosition.x - FPreviewPanStartMouse.x,
        FPreviewPanStartOffset.y + MousePosition.y - FPreviewPanStartMouse.y)
    else
      FPreviewPanning := False;
  end;
end;

procedure TGuiEditorImGui.DrawElementProperties;
var
  Component: TGuiComponent;
  Element: TGuiElement;
  I: Integer;
  Selected: Boolean;
  LabelText: string;
  AlignmentIndex: Integer;
  Alignment: TGuiAlignment;
  RectValues: array[0..3] of Single;
  ScaleValues: array[0..2] of Single;
  LeftValue: Single;
  TopValue: Single;
  WidthValue: Single;
  HeightValue: Single;
  MaxWidth: Single;
  MaxHeight: Single;
begin
  Component := SelectedComponent;
  ImGui.Text('Elements');
  ImGui.Separator;

  if Component = nil then
  begin
    ImGui.TextDisabled('No component selected.');
    Exit;
  end;

  if ImGui.Button('+ Add##GuiElement') then
    AddElement;
  ImGui.SameLine;
  if ImGui.Button('Duplicate##GuiElement') then
    DuplicateSelectedElement;
  ImGui.SameLine;
  if ImGui.Button('Delete##GuiElement') then
    DeleteSelectedElement;

  if ImGui.BeginChild('GuiElementList', ImPoint(-1, 190),
    ImGuiChildFlags_Border) then
    for I := 0 to Component.Elements.Count - 1 do
    begin
      Selected := I = FSelectedElementIndex;
      LabelText := Component.Elements[I].Name + '##GuiElement' + IntToStr(I);
      if ImGui.Selectable(AnsiString(LabelText), Selected) then
        SelectElement(I);
    end;
  ImGui.EndChild;

  Element := SelectedElement;
  if Element = nil then
  begin
    ImGui.TextDisabled('No element selected.');
    Exit;
  end;

  ImGui.Separator;
  ImGui.PushItemWidth(-1);
  if ImGui.InputText('Name##GuiElementProperty', @FElementName[0],
    SizeOf(FElementName)) then
  begin
    Element.Name := UniqueElementName(Component,
      TextBufferValue(FElementName), Element);
    SetTextBuffer(FElementName, Element.Name);
    MarkDirty;
  end;

  AlignmentIndex := Ord(Element.Align);
  if ImGui.BeginCombo('Alignment', PAnsiChar(AnsiString(
    GUI_ALIGN_NAMES[Element.Align]))) then
  begin
    for Alignment := Low(TGuiAlignment) to High(TGuiAlignment) do
    begin
      Selected := Ord(Alignment) = AlignmentIndex;
      if ImGui.Selectable(AnsiString(GUI_ALIGN_NAMES[Alignment]), Selected) then
      begin
        Element.Align := Alignment;
        AlignmentIndex := Ord(Alignment);
        MarkDirty;
      end;
    end;
    ImGui.EndCombo;
  end;

  LeftValue := System.Math.Min(Element.TopLeft.X, Element.BottomRight.X);
  TopValue := System.Math.Min(Element.TopLeft.Y, Element.BottomRight.Y);
  WidthValue := Abs(Element.BottomRight.X - Element.TopLeft.X);
  HeightValue := Abs(Element.BottomRight.Y - Element.TopLeft.Y);
  RectValues[0] := LeftValue;
  RectValues[1] := TopValue;
  RectValues[2] := WidthValue;
  RectValues[3] := HeightValue;
  if ImGui.DragFloat4('Source rect', @RectValues[0], 1.0, 0.0,
    100000.0, '%.1f') then
  begin
    RectValues[0] := System.Math.Max(0.0, RectValues[0]);
    RectValues[1] := System.Math.Max(0.0, RectValues[1]);
    RectValues[2] := System.Math.Max(0.0, RectValues[2]);
    RectValues[3] := System.Math.Max(0.0, RectValues[3]);

    if (FLayout.Texture.Width > 0) and (FLayout.Texture.Height > 0) then
    begin
      MaxWidth := FLayout.Texture.Width;
      MaxHeight := FLayout.Texture.Height;
      RectValues[0] := System.Math.Min(MaxWidth, RectValues[0]);
      RectValues[1] := System.Math.Min(MaxHeight, RectValues[1]);
      RectValues[2] := System.Math.Min(MaxWidth - RectValues[0],
        RectValues[2]);
      RectValues[3] := System.Math.Min(MaxHeight - RectValues[1],
        RectValues[3]);
    end;

    Element.TopLeft := Vector3(RectValues[0], RectValues[1],
      Element.TopLeft.Z);
    Element.BottomRight := Vector3(RectValues[0] + RectValues[2],
      RectValues[1] + RectValues[3], Element.BottomRight.Z);
    MarkDirty;
  end;

  ScaleValues[0] := Element.Scale.X;
  ScaleValues[1] := Element.Scale.Y;
  ScaleValues[2] := Element.Scale.Z;
  if ImGui.DragFloat3('Scale', @ScaleValues[0], 0.05, 0.0, 1000.0,
    '%.3f') then
  begin
    Element.Scale := Vector3(ScaleValues[0], ScaleValues[1],
      ScaleValues[2]);
    MarkDirty;
  end;
  ImGui.PopItemWidth;

  if Element.Align = gaBorder then
    ImGui.TextDisabled('Border uses Scale X/Y as edge size and Z as multiplier.');
end;

procedure TGuiEditorImGui.DrawFileDialog;
var
  OpenPopup: Boolean;
  SearchText: string;
  DisplayName: string;
  Selected: Boolean;
  ExecuteNow: Boolean;
  ActionLabel: string;
  I: Integer;
begin
  if FFileDialogOpenRequested then
  begin
    ImGui.OpenPopup(GUI_FILE_POPUP_NAME);
    FFileDialogOpenRequested := False;
  end;

  if FFileMode = gefNone then
    Exit;

  ImGui.SetNextWindowSize(ImPoint(680, 470), ImGuiCond_Appearing);
  OpenPopup := True;
  if not ImGui.BeginPopupModal(GUI_FILE_POPUP_NAME, @OpenPopup,
    ImGuiWindowFlags_NoSavedSettings) then
  begin
    if not OpenPopup then
      FFileMode := gefNone;
    Exit;
  end;

  ImGui.Text(AnsiString(FileDialogTitle));
  ImGui.TextWrapped(AnsiString(TEnginePaths.EngineGUIDir));
  ImGui.PushItemWidth(240);
  ImGui.InputText('Search##GuiFileDialog', @FFileSearch[0],
    SizeOf(FFileSearch));
  ImGui.PopItemWidth;
  ImGui.SameLine;
  if ImGui.Button('Refresh##GuiFileDialog') then
    RefreshFileItems;

  if FFileMode = gefSaveLayout then
  begin
    ImGui.PushItemWidth(-1);
    if ImGui.InputText('File name##GuiFileDialog', @FFileName[0],
      SizeOf(FFileName)) then
      FPendingOverwriteFileName := '';
    ImGui.PopItemWidth;
  end;

  ImGui.Separator;
  SearchText := LowerCase(TextBufferValue(FFileSearch));
  ExecuteNow := False;
  if ImGui.BeginChild('GuiFileDialogList', ImPoint(-1, -100),
    ImGuiChildFlags_Border) then
    for I := 0 to High(FFileItems) do
    begin
      DisplayName := ExtractFileName(FFileItems[I]);
      if (SearchText <> '') and
         (Pos(SearchText, LowerCase(DisplayName)) = 0) then
        Continue;
      Selected := I = FFileSelectedIndex;
      if ImGui.Selectable(AnsiString(DisplayName + '##GuiFile' +
        IntToStr(I)), Selected) then
      begin
        FFileSelectedIndex := I;
        if FFileMode = gefSaveLayout then
        begin
          SetTextBuffer(FFileName, DisplayName);
          FPendingOverwriteFileName := '';
        end;
      end;
      if ImGui.IsItemHovered and
         ImGui.IsMouseDoubleClicked(ImGuiMouseButton_Left) and
         (FFileMode <> gefSaveLayout) then
        ExecuteNow := True;
    end;
  ImGui.EndChild;

  if FFileDialogError <> '' then
    ImGui.TextColored(ImVec4.New(1.0, 0.35, 0.30, 1.0),
      PAnsiChar(AnsiString(FFileDialogError)), []);

  case FFileMode of
    gefOpenLayout: ActionLabel := 'Open';
    gefSaveLayout:
      if FPendingOverwriteFileName <> '' then
        ActionLabel := 'Overwrite'
      else
        ActionLabel := 'Save';
    gefImportLayout: ActionLabel := 'Import';
    gefSelectAtlas: ActionLabel := 'Use atlas';
  else
    ActionLabel := 'Apply';
  end;

  if ImGui.Button(AnsiString(ActionLabel)) or ExecuteNow then
    ExecuteFileDialogAction;
  ImGui.SameLine;
  if ImGui.Button('Cancel##GuiFileDialog') then
  begin
    FFileMode := gefNone;
    ImGui.CloseCurrentPopup;
  end;

  ImGui.EndPopup;
  if not OpenPopup then
    FFileMode := gefNone;
end;

procedure TGuiEditorImGui.DrawMainMenu;
begin
  if not ImGui.BeginMenuBar then
    Exit;

  if ImGui.BeginMenu('File') then
  begin
    if ImGui.MenuItem('New') then
      NewLayout;
    if ImGui.MenuItem('Open...') then
      OpenFileDialog(gefOpenLayout);
    if ImGui.MenuItem('Save', nil, False, FDirty or
      (FCurrentFileName = '')) then
    begin
      if FCurrentFileName = '' then
        OpenFileDialog(gefSaveLayout)
      else
        SaveLayout(FCurrentFileName);
    end;
    if ImGui.MenuItem('Save As...') then
      OpenFileDialog(gefSaveLayout);
    ImGui.Separator;
    if ImGui.MenuItem('Import components...') then
      OpenFileDialog(gefImportLayout);
    ImGui.Separator;
    if ImGui.MenuItem('Close') then
      FActive := False;
    ImGui.EndMenu;
  end;

  if ImGui.BeginMenu('Atlas') then
  begin
    if ImGui.MenuItem('Choose...') then
      OpenFileDialog(gefSelectAtlas);
    if ImGui.MenuItem('Use DefaultSkin.bmp') then
      LoadDefaultAtlas;
    ImGui.EndMenu;
  end;

  if ImGui.BeginMenu('Edit') then
  begin
    if ImGui.MenuItem('Add component') then
      AddComponent;
    if ImGui.MenuItem('Duplicate component', nil, False,
      SelectedComponent <> nil) then
      DuplicateSelectedComponent;
    if ImGui.MenuItem('Delete component', nil, False,
      SelectedComponent <> nil) then
      DeleteSelectedComponent;
    ImGui.Separator;
    if ImGui.MenuItem('Add element', nil, False,
      SelectedComponent <> nil) then
      AddElement;
    if ImGui.MenuItem('Duplicate element', nil, False,
      SelectedElement <> nil) then
      DuplicateSelectedElement;
    if ImGui.MenuItem('Delete element', nil, False,
      SelectedElement <> nil) then
      DeleteSelectedElement;
    ImGui.EndMenu;
  end;

  ImGui.EndMenuBar;
end;

procedure TGuiEditorImGui.DrawWorkspace;
begin
  FVisibleCanvasKind := geckNone;

  if FLastError <> '' then
    ImGui.TextColored(ImVec4.New(1.0, 0.35, 0.30, 1.0),
      PAnsiChar(AnsiString(FLastError)), []);

  if ImGui.BeginTabBar('GuiEditorWorkspaceTabs') then
  begin
    if ImGui.BeginTabItem('Component Preview') then
    begin
      DrawComponentPreview;
      ImGui.EndTabItem;
    end;
    if ImGui.BeginTabItem('Atlas') then
    begin
      ImGui.PushItemWidth(160);
      if ImGui.SliderFloat('Atlas zoom', @FAtlasZoom, ATLAS_MIN_ZOOM,
        ATLAS_MAX_ZOOM, '%.2fx') then
        FAtlasZoom := ClampSingle(FAtlasZoom, ATLAS_MIN_ZOOM,
          ATLAS_MAX_ZOOM);
      ImGui.SameLine;
      if ImGui.Button('Reset atlas view') then
      begin
        FAtlasZoom := 1.0;
        FAtlasPan := ImPoint(0, 0);
      end;
      ImGui.PopItemWidth;
      DrawAtlasCanvas;
      ImGui.EndTabItem;
    end;
    ImGui.EndTabBar;
  end;
end;

function TGuiEditorImGui.HandleMouseWheel(X, Y,
  WheelDelta: Integer): Boolean;
var
  WheelSteps: Single;
  OldZoom: Single;
  NewZoom: Single;
  NewContentScale: Single;
  NewContentWidth: Single;
  NewContentHeight: Single;
  ContentPointX: Single;
  ContentPointY: Single;
  MouseInsideContent: Boolean;
begin
  Result := False;
  if (not FActive) or (FVisibleCanvasKind = geckNone) or
     (WheelDelta = 0) then
    Exit;

  if (X < FVisibleCanvasPosition.x) or
     (Y < FVisibleCanvasPosition.y) or
     (X > FVisibleCanvasPosition.x + FVisibleCanvasSize.x) or
     (Y > FVisibleCanvasPosition.y + FVisibleCanvasSize.y) then
    Exit;

  WheelSteps := WheelDelta / WHEEL_DELTA;
  case FVisibleCanvasKind of
    geckComponentPreview:
      begin
        OldZoom := FPreviewZoom;
        NewZoom := ClampSingle(OldZoom * System.Math.Power(1.2,
          WheelSteps), PREVIEW_MIN_ZOOM, PREVIEW_MAX_ZOOM);
      end;
    geckAtlas:
      begin
        OldZoom := FAtlasZoom;
        NewZoom := ClampSingle(OldZoom * System.Math.Power(1.2,
          WheelSteps), ATLAS_MIN_ZOOM, ATLAS_MAX_ZOOM);
      end;
  else
    Exit;
  end;

  if SameValue(NewZoom, OldZoom, 0.0001) then
    Exit(True);

  MouseInsideContent :=
    (X >= FVisibleContentPosition.x) and
    (Y >= FVisibleContentPosition.y) and
    (X <= FVisibleContentPosition.x +
      (FVisibleContentWidth * FVisibleContentScale)) and
    (Y <= FVisibleContentPosition.y +
      (FVisibleContentHeight * FVisibleContentScale));
  if MouseInsideContent and (FVisibleContentScale > 0.0) then
  begin
    ContentPointX := (X - FVisibleContentPosition.x) /
      FVisibleContentScale;
    ContentPointY := (Y - FVisibleContentPosition.y) /
      FVisibleContentScale;
    NewContentScale := FVisibleContentBaseScale * NewZoom;
    NewContentWidth := FVisibleContentWidth * NewContentScale;
    NewContentHeight := FVisibleContentHeight * NewContentScale;

    if FVisibleCanvasKind = geckAtlas then
      FAtlasPan := ImPoint(
        X - (ContentPointX * NewContentScale) -
          FVisibleCanvasPosition.x -
          ((FVisibleCanvasSize.x - NewContentWidth) * 0.5),
        Y - (ContentPointY * NewContentScale) -
          FVisibleCanvasPosition.y -
          ((FVisibleCanvasSize.y - NewContentHeight) * 0.5))
    else
      FPreviewPan := ImPoint(
        X - (ContentPointX * NewContentScale) -
          FVisibleCanvasPosition.x -
          ((FVisibleCanvasSize.x - NewContentWidth) * 0.5),
        Y - (ContentPointY * NewContentScale) -
          FVisibleCanvasPosition.y -
          ((FVisibleCanvasSize.y - NewContentHeight) * 0.5));
  end;

  if FVisibleCanvasKind = geckAtlas then
    FAtlasZoom := NewZoom
  else
    FPreviewZoom := NewZoom;
  Result := True;
end;

procedure TGuiEditorImGui.DuplicateSelectedComponent;
var
  Source: TGuiComponent;
  Component: TGuiComponent;
begin
  Source := SelectedComponent;
  if Source = nil then
    Exit;

  Component := FLayout.Components.Add;
  Component.Assign(Source);
  Component.Name := UniqueComponentName(Source.Name + ' Copy', Component);
  SelectComponent(FLayout.Components.Count - 1);
  MarkDirty;
end;

procedure TGuiEditorImGui.DuplicateSelectedElement;
var
  Component: TGuiComponent;
  Source: TGuiElement;
  Element: TGuiElement;
begin
  Component := SelectedComponent;
  Source := SelectedElement;
  if (Component = nil) or (Source = nil) then
    Exit;

  Element := Component.Elements.Add;
  Element.Assign(Source);
  Element.Name := UniqueElementName(Component, Source.Name + ' Copy',
    Element);
  SelectElement(Component.Elements.Count - 1);
  MarkDirty;
end;

procedure TGuiEditorImGui.ExecuteFileDialogAction;
var
  FileName: string;
begin
  FFileDialogError := '';
  try
    if FFileMode = gefSaveLayout then
    begin
      FileName := ExtractFileName(TextBufferValue(FFileName));
      if FileName = '' then
      begin
        FFileDialogError := 'Enter a file name.';
        Exit;
      end;
      if ExtractFileExt(FileName) = '' then
        FileName := ChangeFileExt(FileName, GUI_LAYOUT_EXTENSION);
      FileName := TPath.Combine(TEnginePaths.EngineGUIDir, FileName);

      if FileExists(FileName) and
         (not SameText(FPendingOverwriteFileName, FileName)) then
      begin
        FPendingOverwriteFileName := FileName;
        FFileDialogError := 'The file already exists. Press Overwrite to replace it.';
        Exit;
      end;
      SaveLayout(FileName);
    end
    else
    begin
      if (FFileSelectedIndex < 0) or
         (FFileSelectedIndex > High(FFileItems)) then
      begin
        FFileDialogError := 'Select a file.';
        Exit;
      end;
      FileName := FFileItems[FFileSelectedIndex];
      case FFileMode of
        gefOpenLayout: LoadLayout(FileName);
        gefImportLayout: ImportLayout(FileName);
        gefSelectAtlas: SetLayoutAtlas(FileName);
      end;
    end;

    FFileMode := gefNone;
    FPendingOverwriteFileName := '';
    ImGui.CloseCurrentPopup;
  except
    on E: Exception do
      FFileDialogError := E.Message;
  end;
end;

function TGuiEditorImGui.FileDialogTitle: string;
begin
  case FFileMode of
    gefOpenLayout: Result := 'Open GUI layout';
    gefSaveLayout: Result := 'Save GUI layout';
    gefImportLayout: Result := 'Import components';
    gefSelectAtlas: Result := 'Choose GUI atlas';
  else
    Result := 'GUI assets';
  end;
end;

procedure TGuiEditorImGui.ImportLayout(const AFileName: string);
var
  TemporaryLayout: TGuiLayout;
  Component: TGuiComponent;
  I: Integer;
  FirstImportedIndex: Integer;
begin
  TemporaryLayout := TGuiLayout.Create(nil);
  try
    TemporaryLayout.LoadFromFile(AFileName);
    FirstImportedIndex := FLayout.Components.Count;
    for I := 0 to TemporaryLayout.Components.Count - 1 do
    begin
      Component := FLayout.Components.Add;
      Component.Assign(TemporaryLayout.Components[I]);
      Component.Name := UniqueComponentName(Component.Name, Component);
    end;
    if FirstImportedIndex < FLayout.Components.Count then
      SelectComponent(FirstImportedIndex);
  finally
    TemporaryLayout.Free;
  end;

  MarkDirty;
end;

function TGuiEditorImGui.IsTextureFile(const AFileName: string): Boolean;
var
  Extension: string;
begin
  Extension := LowerCase(ExtractFileExt(AFileName));
  Result := (Extension = '.bmp') or (Extension = '.png') or
    (Extension = '.jpg') or (Extension = '.jpeg') or
    (Extension = '.tga');
end;

procedure TGuiEditorImGui.LoadDefaultAtlas;
var
  FileName: string;
begin
  FileName := TEnginePaths.EngineGUI('DefaultSkin.bmp');
  if FileExists(FileName) then
    SetLayoutAtlas(FileName)
  else
    FLastError := 'Default GUI atlas was not found: ' + FileName;
end;

procedure TGuiEditorImGui.LoadLayout(const AFileName: string);
begin
  FLayout.LoadFromFile(AFileName);
  LoadDefaultAtlas;
  SetCurrentFileName(AFileName);
  if FLayout.Components.Count > 0 then
    SelectComponent(0)
  else
    SelectComponent(-1);
  FDirty := False;
  FLastError := '';
end;

procedure TGuiEditorImGui.MarkDirty;
begin
  FDirty := True;
  FLastError := '';
end;

procedure TGuiEditorImGui.NewLayout;
begin
  FLayout.Clear;
  LoadDefaultAtlas;
  SetCurrentFileName('');
  SelectComponent(-1);
  FDirty := False;
  FLastError := '';
end;

procedure TGuiEditorImGui.Open;
begin
  FActive := True;
end;

procedure TGuiEditorImGui.OpenFileDialog(AMode: TGuiEditorFileMode);
begin
  FFileMode := AMode;
  FFileDialogOpenRequested := True;
  FFileSelectedIndex := -1;
  FFileDialogError := '';
  FPendingOverwriteFileName := '';
  SetTextBuffer(FFileSearch, '');

  if AMode = gefSaveLayout then
  begin
    if FCurrentFileName <> '' then
      SetTextBuffer(FFileName, ExtractFileName(FCurrentFileName))
    else
      SetTextBuffer(FFileName, 'Untitled' + GUI_LAYOUT_EXTENSION);
  end;
  RefreshFileItems;
end;

procedure TGuiEditorImGui.RefreshFileItems;
var
  Files: TArray<string>;
  FileList: TStringList;
  FileName: string;
  Extension: string;
  I: Integer;
begin
  SetLength(FFileItems, 0);
  FFileSelectedIndex := -1;
  if not TDirectory.Exists(TEnginePaths.EngineGUIDir) then
  begin
    FFileDialogError := 'GUI asset folder does not exist.';
    Exit;
  end;

  FileList := TStringList.Create;
  try
    FileList.Sorted := True;
    FileList.Duplicates := dupIgnore;
    Files := TDirectory.GetFiles(TEnginePaths.EngineGUIDir, '*',
      TSearchOption.soTopDirectoryOnly);
    for FileName in Files do
    begin
      Extension := LowerCase(ExtractFileExt(FileName));
      if ((FFileMode in [gefOpenLayout, gefSaveLayout, gefImportLayout]) and
          (Extension = GUI_LAYOUT_EXTENSION)) or
         ((FFileMode = gefSelectAtlas) and IsTextureFile(FileName)) then
        FileList.Add(FileName);
    end;

    SetLength(FFileItems, FileList.Count);
    for I := 0 to FileList.Count - 1 do
      FFileItems[I] := FileList[I];
  finally
    FileList.Free;
  end;
end;

procedure TGuiEditorImGui.SaveLayout(const AFileName: string);
begin
  FLayout.SaveToFile(AFileName);
  SetCurrentFileName(AFileName);
  FDirty := False;
  FLastError := '';
end;

function TGuiEditorImGui.SelectedComponent: TGuiComponent;
begin
  Result := nil;
  if (FSelectedComponentIndex >= 0) and
     (FSelectedComponentIndex < FLayout.Components.Count) then
    Result := FLayout.Components[FSelectedComponentIndex];
end;

function TGuiEditorImGui.SelectedElement: TGuiElement;
var
  Component: TGuiComponent;
begin
  Result := nil;
  Component := SelectedComponent;
  if (Component <> nil) and (FSelectedElementIndex >= 0) and
     (FSelectedElementIndex < Component.Elements.Count) then
    Result := Component.Elements[FSelectedElementIndex];
end;

procedure TGuiEditorImGui.SelectComponent(AIndex: Integer);
var
  Component: TGuiComponent;
begin
  if (AIndex < 0) or (AIndex >= FLayout.Components.Count) then
    FSelectedComponentIndex := -1
  else
    FSelectedComponentIndex := AIndex;

  Component := SelectedComponent;
  if Component = nil then
  begin
    SetTextBuffer(FComponentName, '');
    SelectElement(-1);
  end
  else
  begin
    SetTextBuffer(FComponentName, Component.Name);
    if Component.Elements.Count > 0 then
      SelectElement(0)
    else
      SelectElement(-1);
  end;
end;

procedure TGuiEditorImGui.SelectElement(AIndex: Integer);
var
  Element: TGuiElement;
begin
  if (SelectedComponent = nil) or (AIndex < 0) or
     (AIndex >= SelectedComponent.Elements.Count) then
    FSelectedElementIndex := -1
  else
    FSelectedElementIndex := AIndex;

  Element := SelectedElement;
  if Element <> nil then
    SetTextBuffer(FElementName, Element.Name)
  else
    SetTextBuffer(FElementName, '');
end;

procedure TGuiEditorImGui.SetCurrentFileName(const AFileName: string);
begin
  FCurrentFileName := AFileName;
end;

procedure TGuiEditorImGui.SetLayoutAtlas(const AFileName: string);
begin
  FLastError := '';
  if not FileExists(AFileName) then
  begin
    FLastError := 'GUI atlas was not found: ' + AFileName;
    Exit;
  end;

  FLayout.TextureFileName := AFileName;
  if FLayout.Texture.TextureID = 0 then
    FLastError := 'Could not load GUI atlas: ' + AFileName
  else
    FLastError := '';
end;

function TGuiEditorImGui.UniqueComponentName(const ABaseName: string;
  AIgnore: TGuiComponent): string;
var
  BaseName: string;
  Candidate: string;
  Existing: TGuiComponent;
  Index: Integer;
begin
  BaseName := Trim(ABaseName);
  if BaseName = '' then
    BaseName := 'Component';
  Candidate := BaseName;
  Index := 1;
  repeat
    Existing := FLayout.FindComponent(Candidate);
    if (Existing = nil) or (Existing = AIgnore) then
      Exit(Candidate);
    Candidate := Format('%s_%d', [BaseName, Index]);
    Inc(Index);
  until False;
end;

function TGuiEditorImGui.UniqueElementName(AComponent: TGuiComponent;
  const ABaseName: string; AIgnore: TGuiElement): string;
var
  BaseName: string;
  Candidate: string;
  Existing: TGuiElement;
  Index: Integer;
begin
  BaseName := Trim(ABaseName);
  if BaseName = '' then
    BaseName := 'Element';
  Candidate := BaseName;
  Index := 1;
  repeat
    Existing := AComponent.Elements.FindItem(Candidate);
    if (Existing = nil) or (Existing = AIgnore) then
      Exit(Candidate);
    Candidate := Format('%s_%d', [BaseName, Index]);
    Inc(Index);
  until False;
end;

end.
