unit Editor.GuiDesigner;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.Math,
  System.UITypes,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.StdCtrls,
  Neslib.FastMath,
  PasImGui,
  Engine.Paths,
  Engine.Gui,
  Engine.Gui.Controls,
  Engine.Gui.Manager;

type
  TGuiDesignerMode = (gdmDesign, gdmInteract);

  TGuiDesignerImGui = class
  private
    FManager: TGuiManager;
    FLayoutSource: TGuiLayout;
    FActive: Boolean;
    FMode: TGuiDesignerMode;
    FSelected: TGuiControl;
    FDragging: Boolean;
    FResizing: Boolean;
    FDragOffsetX: Single;
    FDragOffsetY: Single;
    FResizeStartX: Integer;
    FResizeStartY: Integer;
    FResizeStartWidth: Single;
    FResizeStartHeight: Single;
    FLastError: string;
    FOnChanged: TNotifyEvent;

    procedure SetActive(const Value: Boolean);
    procedure SetMode(const Value: TGuiDesignerMode);
    procedure ApplyMode;
    procedure Changed;
    procedure EnsureSelection;
    function DefaultSkinName(AKind: TGuiControlKind): string;
    function CanParentTo(AParent: TGuiControl): Boolean;
    procedure AddControl(AKind: TGuiControlKind);
    procedure DeleteSelected;
    procedure LoadDefaultLayout;
    procedure UseLayoutSource;

    procedure DrawHierarchy;
    procedure DrawControlNode(AControl: TGuiControl);
    procedure DrawProperties;
    procedure DrawCommonProperties(AControl: TGuiControl);
    procedure DrawTextProperties(AControl: TGuiControl);
    procedure DrawSpecificProperties(AControl: TGuiControl);
    procedure DrawEventBindings(AControl: TGuiControl);
    procedure DrawSelectionOverlay;

    function DrawString(const ALabel, AValue: string;
      out ANewValue: string; ABufferSize: Integer = 512): Boolean;
    function DrawStringList(const ALabel: string; AStrings: TStrings): Boolean;
    function DrawColor(const ALabel: string; AValue: TColor;
      out ANewValue: TColor): Boolean;
    function DrawSkinCombo(const ALabel, AValue: string;
      out ANewValue: string): Boolean;
    function DrawParentCombo(AControl: TGuiControl): Boolean;
  public
    constructor Create(AManager: TGuiManager);
    destructor Destroy; override;

    procedure Draw;
    procedure Open;
    function HandleMouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer): Boolean;
    function HandleMouseMove(Shift: TShiftState; X, Y: Integer): Boolean;
    function HandleMouseUp(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer): Boolean;
    function HandleKeyDown(var Key: Word; Shift: TShiftState): Boolean;

    property Active: Boolean read FActive write SetActive;
    property Mode: TGuiDesignerMode read FMode write SetMode;
    property Selected: TGuiControl read FSelected;
    property LayoutSource: TGuiLayout read FLayoutSource write FLayoutSource;
    property OnChanged: TNotifyEvent read FOnChanged write FOnChanged;
  end;

implementation

function GuiDesignerBackgroundDrawList(
  AViewport: PImGuiViewport): PImDrawList; cdecl;
  external CIMGUI_LIB name 'igGetBackgroundDrawList_ViewportPtr';

const
  GUI_DESIGNER_ADD_POPUP = 'Add engine GUI control###EngineGuiAddControl';
  GUI_DESIGNER_RESIZE_HANDLE = 9.0;
  GUI_DESIGNER_EVENT_NAMES: array[0..14] of string = (
    'OnCreate',
    'OnButtonClick',
    'OnChange',
    'OnMouseDown',
    'OnMouseMove',
    'OnMouseUp',
    'OnMouseEnter',
    'OnMouseLeave',
    'OnKeyDown',
    'OnKeyPress',
    'OnKeyUp',
    'OnMenuClick',
    'OnWindowMove',
    'OnWindowShow',
    'OnWindowHide'
  );

function ClampByte(AValue: Single): Byte;
begin
  Result := EnsureRange(Round(AValue * 255.0), 0, 255);
end;

function SnapValue(AValue: Single; ASnap: Boolean): Single;
begin
  if ASnap then
    Result := Round(AValue / 8.0) * 8.0
  else
    Result := AValue;
end;

procedure SetAnsiBuffer(var ABuffer: TArray<AnsiChar>; const AValue: string;
  ASize: Integer);
var
  Value: AnsiString;
  CopyLength: Integer;
begin
  SetLength(ABuffer, Max(2, ASize));
  FillChar(ABuffer[0], Length(ABuffer) * SizeOf(AnsiChar), 0);
  Value := AnsiString(AValue);
  CopyLength := Min(Length(Value), Length(ABuffer) - 1);
  if CopyLength > 0 then
    Move(Value[1], ABuffer[0], CopyLength);
end;

function AnsiBufferValue(const ABuffer: TArray<AnsiChar>): string;
begin
  if Length(ABuffer) = 0 then
    Exit('');
  Result := string(AnsiString(PAnsiChar(@ABuffer[0])));
end;

{ TGuiDesignerImGui }

constructor TGuiDesignerImGui.Create(AManager: TGuiManager);
begin
  inherited Create;
  FManager := AManager;
  FMode := gdmDesign;
end;

destructor TGuiDesignerImGui.Destroy;
begin
  FActive := False;
  ApplyMode;
  inherited;
end;

procedure TGuiDesignerImGui.SetActive(const Value: Boolean);
begin
  if FActive = Value then
    Exit;
  FActive := Value;
  FDragging := False;
  FResizing := False;
  ApplyMode;
end;

procedure TGuiDesignerImGui.SetMode(const Value: TGuiDesignerMode);
begin
  if FMode = Value then
    Exit;
  FMode := Value;
  FDragging := False;
  FResizing := False;
  ApplyMode;
end;

procedure TGuiDesignerImGui.ApplyMode;
var
  RuntimeEnabled: Boolean;
begin
  if FManager = nil then
    Exit;
  RuntimeEnabled := (not FActive) or (FMode = gdmInteract);
  FManager.InputEnabled := RuntimeEnabled;
  FManager.EventDispatchEnabled := RuntimeEnabled;
end;

procedure TGuiDesignerImGui.Changed;
begin
  FLastError := '';
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TGuiDesignerImGui.EnsureSelection;
begin
  if (FSelected <> nil) and
     ((FManager = nil) or not FManager.ContainsControl(FSelected) or
      (FSelected = FManager.Root)) then
    FSelected := nil;
end;

function TGuiDesignerImGui.DefaultSkinName(
  AKind: TGuiControlKind): string;
var
  KindName: string;
  Candidate: string;
  I: Integer;
begin
  Result := '';
  if (FManager = nil) or (FManager.Layout = nil) then
    Exit;

  case AKind of
    gckPanel: KindName := 'Panel';
    gckButton: KindName := 'Button';
    gckCheckBox: KindName := 'CheckBox';
    gckEdit: KindName := 'Edit';
    gckLabel, gckAdvancedLabel: KindName := 'Label';
    gckWindow: KindName := 'Window';
    gckScrollbar: KindName := 'Scrollbar';
    gckPopupMenu: KindName := 'PopupMenu';
    gckStringGrid: KindName := 'StringGrid';
  else
    KindName := '';
  end;

  for I := 0 to FManager.Layout.Components.Count - 1 do
  begin
    Candidate := FManager.Layout.Components[I].Name;
    if SameText(Candidate, KindName) or
       SameText(Candidate, KindName + '_1') then
      Exit(Candidate);
  end;
end;

function TGuiDesignerImGui.CanParentTo(AParent: TGuiControl): Boolean;
var
  Ancestor: TGuiControl;
begin
  Result := (FManager <> nil) and (FSelected <> nil);
  if not Result then
    Exit;
  if AParent = nil then
    AParent := FManager.Root;

  Ancestor := AParent;
  while Ancestor <> nil do
  begin
    if Ancestor = FSelected then
      Exit(False);
    Ancestor := Ancestor.Parent;
  end;
end;

procedure TGuiDesignerImGui.AddControl(AKind: TGuiControlKind);
var
  ParentControl: TGuiControl;
  Control: TGuiControl;
  BaseName: string;
begin
  if FManager = nil then
    Exit;

  if (FSelected is TGuiPanel) or (FSelected is TGuiForm) then
    ParentControl := FSelected
  else
    ParentControl := nil;

  case AKind of
    gckPanel: BaseName := 'Panel';
    gckButton: BaseName := 'Button';
    gckCheckBox: BaseName := 'CheckBox';
    gckEdit: BaseName := 'Edit';
    gckLabel: BaseName := 'Label';
    gckAdvancedLabel: BaseName := 'AdvancedLabel';
    gckWindow: BaseName := 'Window';
    gckScrollbar: BaseName := 'Scrollbar';
    gckPopupMenu: BaseName := 'PopupMenu';
    gckStringGrid: BaseName := 'StringGrid';
  else
    BaseName := 'Control';
  end;

  Control := FManager.CreateControl(AKind, BaseName, ParentControl);
  Control.Left := 48 + ((FManager.Count - 1) mod 12) * 12;
  Control.Top := 72 + ((FManager.Count - 1) mod 10) * 12;
  Control.ComponentName := DefaultSkinName(AKind);
  if Control is TGuiBaseTextControl then
    TGuiBaseTextControl(Control).Caption := Control.Name;
  FSelected := Control;
  Changed;
end;

procedure TGuiDesignerImGui.DeleteSelected;
var
  ParentControl: TGuiControl;
begin
  EnsureSelection;
  if (FManager = nil) or (FSelected = nil) then
    Exit;

  ParentControl := FSelected.Parent;
  FManager.DeleteControl(FSelected);
  if (ParentControl <> nil) and (ParentControl <> FManager.Root) and
     FManager.ContainsControl(ParentControl) then
    FSelected := ParentControl
  else
    FSelected := nil;
  Changed;
end;

procedure TGuiDesignerImGui.LoadDefaultLayout;
var
  LayoutFileName: string;
  TextureFileName: string;
begin
  if FManager = nil then
    Exit;

  LayoutFileName := TEnginePaths.EngineGUI('Windows_All_GUI.layout');
  TextureFileName := TEnginePaths.EngineGUI('AllGUI.bmp');
  if not FileExists(LayoutFileName) then
    LayoutFileName := TEnginePaths.EngineGUI('Windows.layout');
  if not FileExists(TextureFileName) then
    TextureFileName := TEnginePaths.EngineGUI('DefaultSkin.bmp');

  try
    if not FManager.LoadLayout(LayoutFileName, TextureFileName) then
      raise Exception.Create('Default engine GUI layout or atlas was not found.');
    Changed;
  except
    on E: Exception do
      FLastError := E.Message;
  end;
end;

procedure TGuiDesignerImGui.UseLayoutSource;
begin
  if (FManager = nil) or (FLayoutSource = nil) then
    Exit;
  try
    FManager.AssignLayout(FLayoutSource);
    Changed;
  except
    on E: Exception do
      FLastError := E.Message;
  end;
end;

procedure TGuiDesignerImGui.Draw;
var
  OpenWindow: Boolean;
  ModeValue: Integer;
  EnabledValue: Boolean;
begin
  if not FActive or (FManager = nil) then
    Exit;

  EnsureSelection;
  ApplyMode;
  DrawSelectionOverlay;

  ImGui.SetNextWindowPos(ImVec2.New(285, 74), ImGuiCond_FirstUseEver);
  ImGui.SetNextWindowSize(ImVec2.New(470, 690), ImGuiCond_FirstUseEver);
  OpenWindow := True;
  if ImGui.Begin_('Engine GUI Designer###EngineGuiDesigner', @OpenWindow,
    ImGuiWindowFlags_MenuBar) then
  begin
    ModeValue := Ord(FMode);
    if ImGui.RadioButton('Design', @ModeValue, Ord(gdmDesign)) then
      Mode := gdmDesign;
    ImGui.SameLine;
    if ImGui.RadioButton('Interact', @ModeValue, Ord(gdmInteract)) then
      Mode := gdmInteract;
    ImGui.SameLine;
    EnabledValue := FManager.Enabled;
    if ImGui.Checkbox('Visible', @EnabledValue) then
    begin
      FManager.Enabled := EnabledValue;
      Changed;
    end;

    ImGui.Separator;
    if ImGui.Button('Load default skin') then
      LoadDefaultLayout;
    ImGui.SameLine;
    if ImGui.Button('Use Layout Editor skin') then
      UseLayoutSource;
    ImGui.SameLine;
    ImGui.TextDisabled(PAnsiChar(AnsiString(Format('%d skin(s)',
      [FManager.Layout.Components.Count]))));

    if ImGui.BeginChild('EngineGuiHierarchyPane', ImVec2.New(205, -1),
      ImGuiChildFlags_Border) then
      DrawHierarchy;
    ImGui.EndChild;

    ImGui.SameLine;
    if ImGui.BeginChild('EngineGuiPropertiesPane', ImVec2.New(0, -1),
      ImGuiChildFlags_Border) then
      DrawProperties;
    ImGui.EndChild;

    if FLastError <> '' then
    begin
      ImGui.Separator;
      ImGui.TextWrapped(PAnsiChar(AnsiString(FLastError)));
    end;
  end;
  ImGui.End_;

  if not OpenWindow then
    Active := False;
end;

procedure TGuiDesignerImGui.DrawHierarchy;
begin
  if ImGui.Button('+ Add') then
    ImGui.OpenPopup(GUI_DESIGNER_ADD_POPUP);
  ImGui.SameLine;
  if ImGui.Button('Delete') then
    DeleteSelected;

  if ImGui.BeginPopup(GUI_DESIGNER_ADD_POPUP) then
  begin
    if ImGui.MenuItem('Panel') then AddControl(gckPanel);
    if ImGui.MenuItem('Window') then AddControl(gckWindow);
    ImGui.Separator;
    if ImGui.MenuItem('Button') then AddControl(gckButton);
    if ImGui.MenuItem('Check box') then AddControl(gckCheckBox);
    if ImGui.MenuItem('Edit') then AddControl(gckEdit);
    if ImGui.MenuItem('Label') then AddControl(gckLabel);
    if ImGui.MenuItem('Advanced label') then AddControl(gckAdvancedLabel);
    if ImGui.MenuItem('Scrollbar') then AddControl(gckScrollbar);
    if ImGui.MenuItem('Popup menu') then AddControl(gckPopupMenu);
    if ImGui.MenuItem('String grid') then AddControl(gckStringGrid);
    ImGui.EndPopup;
  end;

  if FSelected <> nil then
  begin
    if ImGui.Button('Back') then
    begin
      FManager.SendToBack(FSelected);
      Changed;
    end;
    ImGui.SameLine;
    if ImGui.Button('Front') then
    begin
      FManager.BringToFront(FSelected);
      Changed;
    end;
  end;

  ImGui.Separator;
  if FManager.Root.ChildCount = 0 then
    ImGui.TextDisabled('No engine GUI controls.')
  else
    DrawControlNode(FManager.Root);
end;

procedure TGuiDesignerImGui.DrawControlNode(AControl: TGuiControl);
var
  I: Integer;
  Flags: ImGuiTreeNodeFlags;
  Opened: Boolean;
  LabelText: string;
begin
  if AControl = FManager.Root then
  begin
    for I := 0 to AControl.ChildCount - 1 do
      DrawControlNode(AControl.Children[I]);
    Exit;
  end;

  Flags := ImGuiTreeNodeFlags_OpenOnArrow or
    ImGuiTreeNodeFlags_SpanAvailWidth;
  if AControl.ChildCount = 0 then
    Flags := Flags or ImGuiTreeNodeFlags_Leaf or
      ImGuiTreeNodeFlags_NoTreePushOnOpen;
  if AControl = FSelected then
    Flags := Flags or ImGuiTreeNodeFlags_Selected;

  LabelText := AControl.Name + '  [' + FManager.KindName(AControl) + ']';
  Opened := ImGui.TreeNodeEx(Pointer(AControl), Flags,
    PAnsiChar(AnsiString(LabelText)));
  if ImGui.IsItemClicked(ImGuiMouseButton_Left) then
    FSelected := AControl;

  if Opened and (AControl.ChildCount > 0) then
  begin
    for I := 0 to AControl.ChildCount - 1 do
      DrawControlNode(AControl.Children[I]);
    ImGui.TreePop;
  end;
end;

procedure TGuiDesignerImGui.DrawProperties;
begin
  EnsureSelection;
  if FSelected = nil then
  begin
    ImGui.TextDisabled('Select or add a control.');
    ImGui.TextWrapped('The scene owns this GUI tree. ImGui only edits it.');
    Exit;
  end;

  ImGui.Text(PAnsiChar(AnsiString(FManager.KindName(FSelected))));
  ImGui.SameLine;
  ImGui.TextDisabled(PAnsiChar(AnsiString('#' +
    IntToStr(FManager.HandleOf(FSelected)))));
  ImGui.Separator;

  if FMode = gdmInteract then
  begin
    ImGui.TextWrapped('Interact mode sends input and script events to the engine GUI.');
    ImGui.TextDisabled('Switch to Design to edit properties.');
    Exit;
  end;

  DrawCommonProperties(FSelected);
  DrawTextProperties(FSelected);
  DrawSpecificProperties(FSelected);
  DrawEventBindings(FSelected);
end;

procedure TGuiDesignerImGui.DrawCommonProperties(AControl: TGuiControl);
var
  NewText: string;
  Existing: TGuiControl;
  Values: array[0..3] of Single;
  BoolValue: Boolean;
  BaseComponent: TGuiBaseComponent;
begin
  if ImGui.CollapsingHeader('Control', ImGuiTreeNodeFlags_DefaultOpen) then
  begin
    if DrawString('Name##EngineGuiControl', AControl.Name, NewText, 256) then
    begin
      NewText := Trim(NewText);
      Existing := FManager.FindControl(NewText);
      if (NewText <> '') and
         ((Existing = nil) or (Existing = AControl)) then
        try
          AControl.Name := NewText;
          Changed;
        except
          on E: Exception do
            FLastError := E.Message;
        end
      else
        FLastError := 'GUI control names must be non-empty and unique.';
    end;

    DrawParentCombo(AControl);

    BoolValue := AControl.Visible;
    if ImGui.Checkbox('Visible##EngineGuiControl', @BoolValue) then
    begin
      AControl.Visible := BoolValue;
      Changed;
    end;

    if DrawSkinCombo('Skin', AControl.ComponentName, NewText) then
    begin
      AControl.ComponentName := NewText;
      Changed;
    end;

    Values[0] := AControl.Left;
    Values[1] := AControl.Top;
    if ImGui.DragFloat2('Position', @Values[0], 1.0, -100000, 100000,
      '%.1f') then
    begin
      AControl.Left := Values[0];
      AControl.Top := Values[1];
      Changed;
    end;

    Values[0] := AControl.Width;
    Values[1] := AControl.Height;
    if ImGui.DragFloat2('Size', @Values[0], 1.0, 1, 100000, '%.1f') then
    begin
      AControl.Width := Max(1.0, Values[0]);
      AControl.Height := Max(1.0, Values[1]);
      Changed;
    end;

    Values[0] := AControl.Scale;
    if ImGui.DragFloat('Scale', @Values[0], 0.01, 0.01, 1000, '%.2f') then
    begin
      AControl.Scale := Max(0.01, Values[0]);
      Changed;
    end;

    Values[0] := AControl.Tint.X;
    Values[1] := AControl.Tint.Y;
    Values[2] := AControl.Tint.Z;
    Values[3] := AControl.Tint.W;
    if ImGui.ColorEdit4('Tint', @Values[0]) then
    begin
      AControl.Tint := Vector4(Values[0], Values[1], Values[2], Values[3]);
      Changed;
    end;

    BaseComponent := TGuiBaseComponent(AControl);
    Values[0] := BaseComponent.AlphaChannel;
    if ImGui.DragFloat('Opacity', @Values[0], 0.01, 0, 1, '%.2f') then
    begin
      BaseComponent.AlphaChannel := EnsureRange(Values[0], 0.0, 1.0);
      Changed;
    end;

    Values[0] := BaseComponent.Rotation;
    if ImGui.DragFloat('Rotation', @Values[0], 0.25, -360, 360,
      '%.1f deg') then
    begin
      BaseComponent.Rotation := Values[0];
      Changed;
    end;

    BoolValue := BaseComponent.Autosize;
    if ImGui.Checkbox('Autosize', @BoolValue) then
    begin
      BaseComponent.Autosize := BoolValue;
      Changed;
    end;
  end;
end;

procedure TGuiDesignerImGui.DrawTextProperties(AControl: TGuiControl);
var
  FontControl: TGuiBaseFontControl;
  TextControl: TGuiBaseTextControl;
  FocusControl: TGuiFocusControl;
  NewText: string;
  NewColor: TColor;
  IntValue: Integer;
  StyleMask: Integer;
  BoolValue: Boolean;
begin
  if not (AControl is TGuiBaseFontControl) then
    Exit;

  FontControl := TGuiBaseFontControl(AControl);
  if not ImGui.CollapsingHeader('Text', ImGuiTreeNodeFlags_DefaultOpen) then
    Exit;

  if AControl is TGuiBaseTextControl then
  begin
    TextControl := TGuiBaseTextControl(AControl);
    if DrawString('Caption', TextControl.Caption, NewText, 1024) then
    begin
      TextControl.Caption := NewText;
      Changed;
    end;
  end;

  if DrawString('Font name', FontControl.Font.Name, NewText, 256) then
  begin
    FontControl.Font.Name := NewText;
    Changed;
  end;

  IntValue := FontControl.Font.Size;
  if ImGui.DragInt('Font size', @IntValue, 1, 1, 256, '%d',
    ImGuiSliderFlags_None) then
  begin
    FontControl.Font.Size := Max(1, IntValue);
    Changed;
  end;

  if DrawColor('Text color', FontControl.DefaultColor, NewColor) then
  begin
    FontControl.DefaultColor := NewColor;
    Changed;
  end;

  StyleMask := 0;
  if fsBold in FontControl.Font.Style then StyleMask := StyleMask or 1;
  if fsItalic in FontControl.Font.Style then StyleMask := StyleMask or 2;
  if fsUnderline in FontControl.Font.Style then StyleMask := StyleMask or 4;

  BoolValue := (StyleMask and 1) <> 0;
  if ImGui.Checkbox('Bold', @BoolValue) then
  begin
    if BoolValue then
      FontControl.Font.Style := FontControl.Font.Style + [fsBold]
    else
      FontControl.Font.Style := FontControl.Font.Style - [fsBold];
    Changed;
  end;
  ImGui.SameLine;
  BoolValue := (StyleMask and 2) <> 0;
  if ImGui.Checkbox('Italic', @BoolValue) then
  begin
    if BoolValue then
      FontControl.Font.Style := FontControl.Font.Style + [fsItalic]
    else
      FontControl.Font.Style := FontControl.Font.Style - [fsItalic];
    Changed;
  end;

  if AControl is TGuiFocusControl then
  begin
    FocusControl := TGuiFocusControl(AControl);
    if DrawColor('Focused text', FocusControl.FocusedColor, NewColor) then
    begin
      FocusControl.FocusedColor := NewColor;
      Changed;
    end;
  end;
end;

procedure TGuiDesignerImGui.DrawSpecificProperties(AControl: TGuiControl);
var
  Button: TGuiButton;
  CheckBox: TGuiCheckBox;
  Edit: TGuiEdit;
  LabelControl: TGuiLabel;
  GuiForm: TGuiForm;
  Scrollbar: TGuiScrollbar;
  PopupMenu: TGuiPopupMenu;
  StringGrid: TGuiStringGrid;
  NewText: string;
  NewColor: TColor;
  BoolValue: Boolean;
  IntValue: Integer;
  FloatValue: Single;
begin
  if not ImGui.CollapsingHeader('Type Properties',
    ImGuiTreeNodeFlags_DefaultOpen) then
    Exit;

  if AControl is TGuiButton then
  begin
    Button := TGuiButton(AControl);
    BoolValue := Button.Pressed;
    if ImGui.Checkbox('Pressed', @BoolValue) then
    begin
      Button.Pressed := BoolValue;
      Changed;
    end;
    BoolValue := Button.AllowUp;
    if ImGui.Checkbox('Allow up', @BoolValue) then
    begin
      Button.AllowUp := BoolValue;
      Changed;
    end;
    IntValue := Button.Group;
    if ImGui.DragInt('Group', @IntValue, 1, -1, 100000, '%d',
      ImGuiSliderFlags_None) then
    begin
      Button.Group := IntValue;
      Changed;
    end;
    if DrawSkinCombo('Pressed skin', Button.PressedLayoutName,
      NewText) then
    begin
      Button.PressedLayoutName := NewText;
      Changed;
    end;
  end
  else if AControl is TGuiCheckBox then
  begin
    CheckBox := TGuiCheckBox(AControl);
    BoolValue := CheckBox.Checked;
    if ImGui.Checkbox('Checked', @BoolValue) then
    begin
      CheckBox.Checked := BoolValue;
      Changed;
    end;
    IntValue := CheckBox.Group;
    if ImGui.DragInt('Group', @IntValue, 1, -1, 100000, '%d',
      ImGuiSliderFlags_None) then
    begin
      CheckBox.Group := IntValue;
      Changed;
    end;
    if DrawSkinCombo('Checked skin', CheckBox.CheckedLayoutName,
      NewText) then
    begin
      CheckBox.CheckedLayoutName := NewText;
      Changed;
    end;
  end
  else if AControl is TGuiEdit then
  begin
    Edit := TGuiEdit(AControl);
    BoolValue := Edit.ReadOnly;
    if ImGui.Checkbox('Read only', @BoolValue) then
    begin
      Edit.ReadOnly := BoolValue;
      Changed;
    end;
    if DrawString('Mask character', Edit.EditChar, NewText, 8) then
    begin
      Edit.EditChar := NewText;
      Changed;
    end;
  end
  else if AControl is TGuiLabel then
  begin
    LabelControl := TGuiLabel(AControl);
    IntValue := Ord(LabelControl.Alignment);
    ImGui.RadioButton('Left', @IntValue, Ord(taLeftJustify));
    ImGui.SameLine;
    ImGui.RadioButton('Center', @IntValue, Ord(taCenter));
    ImGui.SameLine;
    ImGui.RadioButton('Right', @IntValue, Ord(taRightJustify));
    if IntValue <> Ord(LabelControl.Alignment) then
    begin
      LabelControl.Alignment := TAlignment(IntValue);
      Changed;
    end;

    IntValue := Ord(LabelControl.TextLayout);
    ImGui.RadioButton('Top##TextLayout', @IntValue, Ord(tlTop));
    ImGui.SameLine;
    ImGui.RadioButton('Middle##TextLayout', @IntValue, Ord(tlCenter));
    ImGui.SameLine;
    ImGui.RadioButton('Bottom##TextLayout', @IntValue, Ord(tlBottom));
    if IntValue <> Ord(LabelControl.TextLayout) then
    begin
      LabelControl.TextLayout := TTextLayout(IntValue);
      Changed;
    end;
  end
  else if AControl is TGuiForm then
  begin
    GuiForm := TGuiForm(AControl);
    FloatValue := GuiForm.TitleOffset;
    if ImGui.DragFloat('Title offset', @FloatValue, 1, -1000, 1000,
      '%.1f') then
    begin
      GuiForm.TitleOffset := FloatValue;
      Changed;
    end;
    if DrawColor('Title color', GuiForm.TitleColor, NewColor) then
    begin
      GuiForm.TitleColor := NewColor;
      Changed;
    end;
  end
  else if AControl is TGuiScrollbar then
  begin
    Scrollbar := TGuiScrollbar(AControl);
    BoolValue := Scrollbar.Horizontal;
    if ImGui.Checkbox('Horizontal', @BoolValue) then
    begin
      Scrollbar.Horizontal := BoolValue;
      Changed;
    end;
    BoolValue := Scrollbar.Locked;
    if ImGui.Checkbox('Locked', @BoolValue) then
    begin
      Scrollbar.Locked := BoolValue;
      Changed;
    end;
    FloatValue := Scrollbar.Min;
    if ImGui.DragFloat('Minimum', @FloatValue, 0.1, -100000, 100000,
      '%.2f') then
    begin
      Scrollbar.Min := FloatValue;
      Changed;
    end;
    FloatValue := Scrollbar.Max;
    if ImGui.DragFloat('Maximum', @FloatValue, 0.1, -100000, 100000,
      '%.2f') then
    begin
      Scrollbar.Max := FloatValue;
      Changed;
    end;
    FloatValue := Scrollbar.Pos;
    if ImGui.DragFloat('Position##Scrollbar', @FloatValue, 0.1,
      Scrollbar.Min, Scrollbar.Max, '%.2f') then
    begin
      Scrollbar.Pos := FloatValue;
      Changed;
    end;
    FloatValue := Scrollbar.PageSize;
    if ImGui.DragFloat('Page size', @FloatValue, 0.1, 0, 100000,
      '%.2f') then
    begin
      Scrollbar.PageSize := Max(0.0, FloatValue);
      Changed;
    end;
    FloatValue := Scrollbar.Step;
    if ImGui.DragFloat('Step', @FloatValue, 0.1, 0, 100000,
      '%.2f') then
    begin
      Scrollbar.Step := Max(0.0, FloatValue);
      Changed;
    end;
    if DrawSkinCombo('Knob skin', Scrollbar.KnobLayoutName,
      NewText) then
    begin
      Scrollbar.KnobLayoutName := NewText;
      Changed;
    end;
  end
  else if AControl is TGuiPopupMenu then
  begin
    PopupMenu := TGuiPopupMenu(AControl);
    FloatValue := PopupMenu.MarginSize;
    if ImGui.DragFloat('Margin', @FloatValue, 1, 0, 1000, '%.1f') then
    begin
      PopupMenu.MarginSize := Max(0.0, FloatValue);
      Changed;
    end;
    if DrawStringList('Menu items', PopupMenu.MenuItems) then
      Changed;
  end
  else if AControl is TGuiStringGrid then
  begin
    StringGrid := TGuiStringGrid(AControl);
    if DrawStringList('Columns', StringGrid.Columns) then
      Changed;
    BoolValue := StringGrid.DrawHeader;
    if ImGui.Checkbox('Draw header', @BoolValue) then
    begin
      StringGrid.DrawHeader := BoolValue;
      Changed;
    end;
    IntValue := StringGrid.RowCount;
    if ImGui.DragInt('Rows', @IntValue, 1, 0, 100000, '%d',
      ImGuiSliderFlags_None) then
    begin
      StringGrid.RowCount := Max(0, IntValue);
      Changed;
    end;
    IntValue := StringGrid.RowHeight;
    if ImGui.DragInt('Row height', @IntValue, 1, 1, 10000, '%d',
      ImGuiSliderFlags_None) then
    begin
      StringGrid.RowHeight := Max(1, IntValue);
      Changed;
    end;
    if DrawColor('Header color', StringGrid.HeaderColor, NewColor) then
    begin
      StringGrid.HeaderColor := NewColor;
      Changed;
    end;
  end;
end;

procedure TGuiDesignerImGui.DrawEventBindings(AControl: TGuiControl);
var
  I: Integer;
  HandlerName: string;
  ScriptName: string;
  NewText: string;
begin
  if not ImGui.CollapsingHeader('Script Events') then
    Exit;

  for I := Low(GUI_DESIGNER_EVENT_NAMES) to
    High(GUI_DESIGNER_EVENT_NAMES) do
  begin
    HandlerName := FManager.EventHandler(AControl,
      GUI_DESIGNER_EVENT_NAMES[I]);
    ScriptName := FManager.EventScript(AControl,
      GUI_DESIGNER_EVENT_NAMES[I]);

    ImGui.PushId(I);
    ImGui.Text(PAnsiChar(AnsiString(GUI_DESIGNER_EVENT_NAMES[I])));
    if DrawString('Handler', HandlerName, NewText, 256) then
    begin
      FManager.SetEventHandler(AControl, GUI_DESIGNER_EVENT_NAMES[I],
        NewText, ScriptName);
      HandlerName := NewText;
      Changed;
    end;
    if DrawString('Script', ScriptName, NewText, 256) then
    begin
      FManager.SetEventHandler(AControl, GUI_DESIGNER_EVENT_NAMES[I],
        HandlerName, NewText);
      Changed;
    end;
    ImGui.Separator;
    ImGui.PopId;
  end;
end;

procedure TGuiDesignerImGui.DrawSelectionOverlay;
var
  DrawList: PImDrawList;
  X1, Y1, X2, Y2: Single;
  Color: ImU32;
begin
  EnsureSelection;
  if (FMode <> gdmDesign) or (FSelected = nil) or
     (FManager.Renderer = nil) then
    Exit;

  X1 := FManager.Renderer.X + FSelected.AbsoluteLeft;
  Y1 := FManager.Renderer.Y + FSelected.AbsoluteTop;
  X2 := X1 + FSelected.Width;
  Y2 := Y1 + FSelected.Height;
  if FSelected.Visible then
    Color := IM_COL32(255, 194, 64, 255)
  else
    Color := IM_COL32(150, 150, 150, 255);

  DrawList := GuiDesignerBackgroundDrawList(ImGui.GetMainViewport);
  DrawList^.AddRect(ImVec2.New(X1, Y1), ImVec2.New(X2, Y2), Color,
    0, ImDrawFlags_Closed, 2);
  DrawList^.AddRectFilled(
    ImVec2.New(X2 - GUI_DESIGNER_RESIZE_HANDLE,
      Y2 - GUI_DESIGNER_RESIZE_HANDLE),
    ImVec2.New(X2 + 1, Y2 + 1), Color);
end;

function TGuiDesignerImGui.DrawString(const ALabel, AValue: string;
  out ANewValue: string; ABufferSize: Integer): Boolean;
var
  Buffer: TArray<AnsiChar>;
begin
  SetAnsiBuffer(Buffer, AValue, ABufferSize);
  Result := ImGui.InputText(PAnsiChar(AnsiString(ALabel)), @Buffer[0],
    Length(Buffer));
  if Result then
    ANewValue := AnsiBufferValue(Buffer)
  else
    ANewValue := AValue;
end;

function TGuiDesignerImGui.DrawStringList(const ALabel: string;
  AStrings: TStrings): Boolean;
var
  Buffer: TArray<AnsiChar>;
  Value: string;
begin
  if AStrings = nil then
    Exit(False);
  SetAnsiBuffer(Buffer, AStrings.Text, 4096);
  Result := ImGui.InputTextMultiline(PAnsiChar(AnsiString(ALabel)),
    @Buffer[0], Length(Buffer), ImVec2.New(-1, 90),
    ImGuiInputTextFlags_AllowTabInput, nil, nil);
  if Result then
  begin
    Value := AnsiBufferValue(Buffer);
    AStrings.Text := Value;
  end;
end;

function TGuiDesignerImGui.DrawColor(const ALabel: string; AValue: TColor;
  out ANewValue: TColor): Boolean;
var
  RGBValue: COLORREF;
  ColorValues: array[0..2] of Single;
begin
  RGBValue := ColorToRGB(AValue);
  ColorValues[0] := GetRValue(RGBValue) / 255.0;
  ColorValues[1] := GetGValue(RGBValue) / 255.0;
  ColorValues[2] := GetBValue(RGBValue) / 255.0;
  Result := ImGui.ColorEdit3(PAnsiChar(AnsiString(ALabel)),
    @ColorValues[0]);
  if Result then
    ANewValue := RGB(ClampByte(ColorValues[0]), ClampByte(ColorValues[1]),
      ClampByte(ColorValues[2]))
  else
    ANewValue := AValue;
end;

function TGuiDesignerImGui.DrawSkinCombo(const ALabel, AValue: string;
  out ANewValue: string): Boolean;
var
  I: Integer;
  SelectedValue: Boolean;
  Component: TGuiComponent;
  Preview: string;
begin
  Result := False;
  ANewValue := AValue;
  if AValue = '' then
    Preview := '<none>'
  else
    Preview := AValue;

  if not ImGui.BeginCombo(PAnsiChar(AnsiString(ALabel)),
    PAnsiChar(AnsiString(Preview))) then
    Exit;
  try
    SelectedValue := AValue = '';
    if ImGui.Selectable('<none>', SelectedValue) then
    begin
      ANewValue := '';
      Result := True;
    end;

    for I := 0 to FManager.Layout.Components.Count - 1 do
    begin
      Component := FManager.Layout.Components[I];
      SelectedValue := SameText(AValue, Component.Name);
      if ImGui.Selectable(PAnsiChar(AnsiString(Component.Name)),
        SelectedValue) then
      begin
        ANewValue := Component.Name;
        Result := True;
      end;
    end;
  finally
    ImGui.EndCombo;
  end;
end;

function TGuiDesignerImGui.DrawParentCombo(
  AControl: TGuiControl): Boolean;
var
  I: Integer;
  Candidate: TGuiControl;
  ParentName: string;
  SelectedValue: Boolean;
begin
  Result := False;
  if AControl.Parent = FManager.Root then
    ParentName := '<root>'
  else if AControl.Parent <> nil then
    ParentName := AControl.Parent.Name
  else
    ParentName := '<root>';

  if not ImGui.BeginCombo('Parent', PAnsiChar(AnsiString(ParentName))) then
    Exit;
  try
    SelectedValue := AControl.Parent = FManager.Root;
    if ImGui.Selectable('<root>', SelectedValue) then
    begin
      FManager.SetParent(AControl, FManager.Root);
      Changed;
      Result := True;
    end;

    for I := 0 to FManager.Count - 1 do
    begin
      Candidate := FManager.ControlAt(I);
      if (Candidate = AControl) or not CanParentTo(Candidate) then
        Continue;
      SelectedValue := AControl.Parent = Candidate;
      if ImGui.Selectable(PAnsiChar(AnsiString(Candidate.Name)),
        SelectedValue) then
      begin
        FManager.SetParent(AControl, Candidate);
        Changed;
        Result := True;
      end;
    end;
  finally
    ImGui.EndCombo;
  end;
end;

procedure TGuiDesignerImGui.Open;
begin
  Active := True;
end;

function TGuiDesignerImGui.HandleMouseDown(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer): Boolean;
var
  LocalX: Single;
  LocalY: Single;
  RightValue: Single;
  BottomValue: Single;
begin
  Result := False;
  if not FActive or (FMode <> gdmDesign) or (FManager = nil) or
     (Button <> mbLeft) then
    Exit;

  EnsureSelection;
  FSelected := FManager.ControlAtPoint(X, Y);
  if FSelected = nil then
    Exit;

  LocalX := X - FManager.Renderer.X;
  LocalY := Y - FManager.Renderer.Y;
  RightValue := FSelected.AbsoluteLeft + FSelected.Width;
  BottomValue := FSelected.AbsoluteTop + FSelected.Height;
  FResizing := (Abs(LocalX - RightValue) <=
    GUI_DESIGNER_RESIZE_HANDLE) and
    (Abs(LocalY - BottomValue) <= GUI_DESIGNER_RESIZE_HANDLE);
  FDragging := not FResizing;

  if FResizing then
  begin
    FResizeStartX := X;
    FResizeStartY := Y;
    FResizeStartWidth := FSelected.Width;
    FResizeStartHeight := FSelected.Height;
  end
  else
  begin
    FDragOffsetX := LocalX - FSelected.AbsoluteLeft;
    FDragOffsetY := LocalY - FSelected.AbsoluteTop;
  end;
  Result := True;
end;

function TGuiDesignerImGui.HandleMouseMove(Shift: TShiftState;
  X, Y: Integer): Boolean;
var
  LocalX: Single;
  LocalY: Single;
  ParentLeft: Single;
  ParentTop: Single;
  Snap: Boolean;
begin
  Result := FActive and (FMode = gdmDesign) and
    (FDragging or FResizing);
  if not Result then
    Exit;

  EnsureSelection;
  if FSelected = nil then
  begin
    FDragging := False;
    FResizing := False;
    Exit(False);
  end;

  Snap := ssShift in Shift;
  if FResizing then
  begin
    FSelected.Width := Max(1.0, SnapValue(
      FResizeStartWidth + X - FResizeStartX, Snap));
    FSelected.Height := Max(1.0, SnapValue(
      FResizeStartHeight + Y - FResizeStartY, Snap));
  end
  else
  begin
    LocalX := X - FManager.Renderer.X;
    LocalY := Y - FManager.Renderer.Y;
    if (FSelected.Parent <> nil) and
       (FSelected.Parent <> FManager.Root) then
    begin
      ParentLeft := FSelected.Parent.AbsoluteLeft;
      ParentTop := FSelected.Parent.AbsoluteTop;
    end
    else
    begin
      ParentLeft := 0;
      ParentTop := 0;
    end;
    FSelected.Left := SnapValue(LocalX - FDragOffsetX - ParentLeft, Snap);
    FSelected.Top := SnapValue(LocalY - FDragOffsetY - ParentTop, Snap);
  end;
  Changed;
end;

function TGuiDesignerImGui.HandleMouseUp(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer): Boolean;
begin
  Result := FActive and (FMode = gdmDesign) and
    (Button = mbLeft) and (FDragging or FResizing);
  if Result then
  begin
    FDragging := False;
    FResizing := False;
  end;
end;

function TGuiDesignerImGui.HandleKeyDown(var Key: Word;
  Shift: TShiftState): Boolean;
var
  Step: Single;
begin
  Result := False;
  EnsureSelection;
  if not FActive or (FMode <> gdmDesign) or (FSelected = nil) then
    Exit;

  if ssShift in Shift then
    Step := 10
  else
    Step := 1;

  case Key of
    VK_DELETE:
      DeleteSelected;
    VK_LEFT:
      FSelected.Left := FSelected.Left - Step;
    VK_RIGHT:
      FSelected.Left := FSelected.Left + Step;
    VK_UP:
      FSelected.Top := FSelected.Top - Step;
    VK_DOWN:
      FSelected.Top := FSelected.Top + Step;
  else
    Exit;
  end;

  if Key <> VK_DELETE then
    Changed;
  Key := 0;
  Result := True;
end;

end.
