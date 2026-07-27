unit Engine.Gui.Manager;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Math,
  System.Generics.Collections,
  Vcl.Controls,
  Neslib.FastMath,
  Engine.Gui,
  Engine.Gui.Controls,
  Renderer.Renderer;

type
  TGuiControlKind = (
    gckPanel,
    gckButton,
    gckCheckBox,
    gckEdit,
    gckLabel,
    gckAdvancedLabel,
    gckWindow,
    gckScrollbar,
    gckPopupMenu,
    gckStringGrid
  );

  TGuiEventData = record
    X: Single;
    Y: Single;
    Value: Single;
    Index: Integer;
    Button: Integer;
    Key: Integer;
    Modifiers: Integer;
    Text: string;

    class function Empty: TGuiEventData; static;
  end;

  TGuiScriptEvent = procedure(AControl: TGuiControl;
    const AEventName, AScriptName, AHandlerName: string;
    const AData: TGuiEventData) of object;
  TGuiControlRemovedEvent = procedure(AControl: TGuiControl) of object;

  TGuiEventBinding = record
    ScriptName: string;
    HandlerName: string;
  end;

  TGuiEventBindingMap = TDictionary<string, TGuiEventBinding>;

  TGuiManager = class(TComponent)
  private
    FRenderer: TRenderer;
    FLayout: TGuiLayout;
    FRoot: TGuiPanel;
    FControls: TList<TGuiControl>;
    FBindings: TObjectDictionary<TGuiControl, TGuiEventBindingMap>;
    FHandleToControl: TDictionary<Integer, TGuiControl>;
    FControlToHandle: TDictionary<TGuiControl, Integer>;
    FPendingDeletes: TList<TGuiControl>;
    FNextHandle: Integer;
    FDispatchDepth: Integer;
    FEnabled: Boolean;
    FMouseCaptured: Boolean;
    FOnScriptEvent: TGuiScriptEvent;
    FOnControlRemoved: TGuiControlRemovedEvent;

    function GetCount: Integer;
    function CanonicalEventName(const AEventName: string): string;
    function MakeUniqueName(const AName: string): string;
    function PointOverControl(AControl: TGuiControl; X, Y: Single): Boolean;
    function PointOverGui(X, Y: Single): Boolean;
    function ShiftToMask(const AShift: TShiftState): Integer;
    procedure ConfigureControlEvents(AControl: TGuiControl);
    procedure DispatchEvent(AControl: TGuiControl; const AEventName: string;
      const AData: TGuiEventData);
    procedure QueueControlDelete(AControl: TGuiControl);
    procedure FlushPendingDeletes;
    procedure RemoveControlRuntime(AControl: TGuiControl);

    procedure ControlMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure ControlMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer);
    procedure ControlMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure ControlMouseEnter(Sender: TObject);
    procedure ControlMouseLeave(Sender: TObject);
    procedure ControlKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure ControlKeyPress(Sender: TObject; var Key: Char);
    procedure ControlKeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure ControlButtonClick(Sender: TObject);
    procedure ControlChanged(Sender: TObject);
    procedure ControlFormMoving(Sender: TGuiForm; var Left, Top: Single);
    procedure ControlFormShow(Sender: TGuiForm);
    procedure ControlFormHide(Sender: TGuiForm);
    procedure ControlPopupClick(Sender: TGuiPopupMenu; Index: Integer;
      const MenuItemText: string);
  public
    constructor Create(AOwner: TComponent; ARenderer: TRenderer); reintroduce;
    destructor Destroy; override;

    procedure Clear;
    procedure Render;
    procedure Resize(AWidth, AHeight: Integer);

    function LoadLayout(const ALayoutFileName: string;
      const ATextureFileName: string = ''): Boolean;
    function SetTexture(const ATextureFileName: string): Boolean;

    function CreateControl(AKind: TGuiControlKind; const AName: string;
      AParent: TGuiControl = nil): TGuiControl;
    function CreatePanel(const AName: string;
      AParent: TGuiControl = nil): TGuiPanel;
    function CreateButton(const AName: string;
      AParent: TGuiControl = nil): TGuiButton;
    function CreateCheckBox(const AName: string;
      AParent: TGuiControl = nil): TGuiCheckBox;
    function CreateEdit(const AName: string;
      AParent: TGuiControl = nil): TGuiEdit;
    function CreateLabel(const AName: string;
      AParent: TGuiControl = nil): TGuiLabel;
    function CreateAdvancedLabel(const AName: string;
      AParent: TGuiControl = nil): TGuiAdvancedLabel;
    function CreateWindow(const AName: string;
      AParent: TGuiControl = nil): TGuiForm;
    function CreateScrollbar(const AName: string;
      AParent: TGuiControl = nil): TGuiScrollbar;
    function CreatePopupMenu(const AName: string;
      AParent: TGuiControl = nil): TGuiPopupMenu;
    function CreateStringGrid(const AName: string;
      AParent: TGuiControl = nil): TGuiStringGrid;

    procedure DeleteControl(AControl: TGuiControl);
    procedure SetParent(AControl, AParent: TGuiControl);
    procedure SetVisible(AControl: TGuiControl; AVisible: Boolean);
    procedure BringToFront(AControl: TGuiControl);
    procedure SendToBack(AControl: TGuiControl);

    function ContainsControl(AControl: TGuiControl): Boolean;
    function ControlAt(AIndex: Integer): TGuiControl;
    function FindControl(const AName: string): TGuiControl;
    function HandleOf(AControl: TGuiControl): Integer;
    function ControlFromHandle(AHandle: Integer): TGuiControl;
    function KindOf(AControl: TGuiControl): TGuiControlKind;
    function KindName(AControl: TGuiControl): string;

    procedure SetEventHandler(AControl: TGuiControl; const AEventName,
      AHandlerName, AScriptName: string);
    function EventHandler(AControl: TGuiControl;
      const AEventName: string): string;
    function EventScript(AControl: TGuiControl;
      const AEventName: string): string;

    function MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer): Boolean;
    function MouseMove(Shift: TShiftState; X, Y: Integer): Boolean;
    function MouseUp(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer): Boolean;
    function KeyDown(var Key: Word; Shift: TShiftState): Boolean;
    function KeyPress(var Key: Char): Boolean;
    function KeyUp(var Key: Word; Shift: TShiftState): Boolean;

    property Renderer: TRenderer read FRenderer;
    property Layout: TGuiLayout read FLayout;
    property Root: TGuiPanel read FRoot;
    property Count: Integer read GetCount;
    property Enabled: Boolean read FEnabled write FEnabled;
    property OnScriptEvent: TGuiScriptEvent read FOnScriptEvent write FOnScriptEvent;
    property OnControlRemoved: TGuiControlRemovedEvent read FOnControlRemoved
      write FOnControlRemoved;
  end;

implementation

const
  GUI_MODIFIER_SHIFT = 1;
  GUI_MODIFIER_CTRL = 2;
  GUI_MODIFIER_ALT = 4;

{ TGuiEventData }

class function TGuiEventData.Empty: TGuiEventData;
begin
  Result.X := 0;
  Result.Y := 0;
  Result.Value := 0;
  Result.Index := -1;
  Result.Button := -1;
  Result.Key := 0;
  Result.Modifiers := 0;
  Result.Text := '';
end;

{ TGuiManager }

constructor TGuiManager.Create(AOwner: TComponent; ARenderer: TRenderer);
begin
  inherited Create(AOwner);
  FRenderer := ARenderer;
  FControls := TList<TGuiControl>.Create;
  FBindings := TObjectDictionary<TGuiControl, TGuiEventBindingMap>.Create(
    [doOwnsValues]);
  FHandleToControl := TDictionary<Integer, TGuiControl>.Create;
  FControlToHandle := TDictionary<TGuiControl, Integer>.Create;
  FPendingDeletes := TList<TGuiControl>.Create;
  FNextHandle := 1;
  FEnabled := True;

  FLayout := TGuiLayout.Create(Self);
  FRoot := TGuiPanel.Create(Self);
  FRoot.Name := 'GuiRoot';
  FRoot.Layout := FLayout;
  FRoot.ComponentName := '';
  Resize(1, 1);
  HandleOf(FRoot);
end;

destructor TGuiManager.Destroy;
begin
  FOnScriptEvent := nil;
  FDispatchDepth := 0;
  FlushPendingDeletes;
  Clear;
  FreeAndNil(FRoot);
  FreeAndNil(FLayout);
  FControlToHandle.Free;
  FHandleToControl.Free;
  FBindings.Free;
  FPendingDeletes.Free;
  FControls.Free;
  inherited;
end;

function TGuiManager.GetCount: Integer;
begin
  Result := FControls.Count;
end;

function TGuiManager.CanonicalEventName(const AEventName: string): string;
var
  Value: string;
begin
  Value := Trim(AEventName);
  if SameText(Value, 'OnClick') or SameText(Value, 'OnButtonClick') then
    Exit('OnButtonClick');
  if SameText(Value, 'OnMove') or SameText(Value, 'OnMoving') or
     SameText(Value, 'OnWindowMove') then
    Exit('OnWindowMove');
  if SameText(Value, 'OnShow') or SameText(Value, 'OnWindowShow') then
    Exit('OnWindowShow');
  if SameText(Value, 'OnHide') or SameText(Value, 'OnWindowHide') then
    Exit('OnWindowHide');
  if SameText(Value, 'OnMenuClick') then
    Exit('OnMenuClick');
  if SameText(Value, 'OnChange') then
    Exit('OnChange');
  if SameText(Value, 'OnMouseDown') then
    Exit('OnMouseDown');
  if SameText(Value, 'OnMouseMove') then
    Exit('OnMouseMove');
  if SameText(Value, 'OnMouseUp') then
    Exit('OnMouseUp');
  if SameText(Value, 'OnMouseEnter') then
    Exit('OnMouseEnter');
  if SameText(Value, 'OnMouseLeave') then
    Exit('OnMouseLeave');
  if SameText(Value, 'OnKeyDown') then
    Exit('OnKeyDown');
  if SameText(Value, 'OnKeyPress') then
    Exit('OnKeyPress');
  if SameText(Value, 'OnKeyUp') then
    Exit('OnKeyUp');
  Result := Value;
end;

function TGuiManager.MakeUniqueName(const AName: string): string;
var
  BaseName: string;
  Candidate: string;
  I: Integer;
  Suffix: Integer;
begin
  BaseName := Trim(AName);
  if BaseName = '' then
    BaseName := 'GuiControl';

  for I := 1 to Length(BaseName) do
    if not CharInSet(BaseName[I],
      ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      BaseName[I] := '_';
  if not CharInSet(BaseName[1], ['A'..'Z', 'a'..'z', '_']) then
    BaseName := 'Gui_' + BaseName;

  Candidate := BaseName;
  Suffix := 1;
  while FindComponent(Candidate) <> nil do
  begin
    Candidate := BaseName + '_' + IntToStr(Suffix);
    Inc(Suffix);
  end;
  Result := Candidate;
end;

function TGuiManager.PointOverControl(AControl: TGuiControl;
  X, Y: Single): Boolean;
var
  I: Integer;
begin
  Result := False;
  if (AControl = nil) or not AControl.RecursiveVisible then
    Exit;
  if (X < AControl.AbsoluteLeft) or
     (Y < AControl.AbsoluteTop) or
     (X >= AControl.AbsoluteLeft + AControl.Width) or
     (Y >= AControl.AbsoluteTop + AControl.Height) then
    Exit;

  for I := AControl.ChildCount - 1 downto 0 do
    if PointOverControl(AControl.Children[I], X, Y) then
      Exit(True);

  Result := AControl <> FRoot;
end;

function TGuiManager.PointOverGui(X, Y: Single): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := FRoot.ChildCount - 1 downto 0 do
    if PointOverControl(FRoot.Children[I], X, Y) then
      Exit(True);
end;

function TGuiManager.ShiftToMask(const AShift: TShiftState): Integer;
begin
  Result := 0;
  if ssShift in AShift then
    Result := Result or GUI_MODIFIER_SHIFT;
  if ssCtrl in AShift then
    Result := Result or GUI_MODIFIER_CTRL;
  if ssAlt in AShift then
    Result := Result or GUI_MODIFIER_ALT;
end;

procedure TGuiManager.ConfigureControlEvents(AControl: TGuiControl);
begin
  if AControl is TGuiBaseControl then
  begin
    TGuiBaseControl(AControl).OnMouseDown := ControlMouseDown;
    TGuiBaseControl(AControl).OnMouseMove := ControlMouseMove;
    TGuiBaseControl(AControl).OnMouseUp := ControlMouseUp;
    TGuiBaseControl(AControl).OnMouseEnter := ControlMouseEnter;
    TGuiBaseControl(AControl).OnMouseLeave := ControlMouseLeave;
  end;

  if AControl is TGuiFocusControl then
  begin
    TGuiFocusControl(AControl).OnKeyDown := ControlKeyDown;
    TGuiFocusControl(AControl).OnKeyPress := ControlKeyPress;
    TGuiFocusControl(AControl).OnKeyUp := ControlKeyUp;
  end;

  if AControl is TGuiButton then
    TGuiButton(AControl).OnButtonClick := ControlButtonClick
  else if AControl is TGuiCheckBox then
    TGuiCheckBox(AControl).OnChange := ControlChanged
  else if AControl is TGuiEdit then
    TGuiEdit(AControl).OnChange := ControlChanged
  else if AControl is TGuiScrollbar then
    TGuiScrollbar(AControl).OnChange := ControlChanged
  else if AControl is TGuiForm then
  begin
    TGuiForm(AControl).OnMoving := ControlFormMoving;
    TGuiForm(AControl).OnShow := ControlFormShow;
    TGuiForm(AControl).OnHide := ControlFormHide;
  end
  else if AControl is TGuiPopupMenu then
    TGuiPopupMenu(AControl).OnClick := ControlPopupClick;
end;

procedure TGuiManager.DispatchEvent(AControl: TGuiControl;
  const AEventName: string; const AData: TGuiEventData);
var
  EventMap: TGuiEventBindingMap;
  Binding: TGuiEventBinding;
  EventName: string;
begin
  if (AControl = nil) or not Assigned(FOnScriptEvent) then
    Exit;

  EventName := CanonicalEventName(AEventName);
  if (EventName = '') or
     not FBindings.TryGetValue(AControl, EventMap) or
     not EventMap.TryGetValue(LowerCase(EventName), Binding) or
     (Trim(Binding.HandlerName) = '') then
    Exit;

  Inc(FDispatchDepth);
  try
    FOnScriptEvent(AControl, EventName, Binding.ScriptName,
      Binding.HandlerName, AData);
  finally
    Dec(FDispatchDepth);
  end;
end;

procedure TGuiManager.QueueControlDelete(AControl: TGuiControl);
var
  I: Integer;
begin
  if (AControl = nil) or (AControl = FRoot) or
     FPendingDeletes.Contains(AControl) then
    Exit;

  for I := AControl.ChildCount - 1 downto 0 do
    if ContainsControl(AControl.Children[I]) then
      QueueControlDelete(AControl.Children[I]);

  AControl.Visible := False;
  RemoveControlRuntime(AControl);
  FPendingDeletes.Add(AControl);
end;

procedure TGuiManager.FlushPendingDeletes;
var
  Control: TGuiControl;
begin
  if FDispatchDepth > 0 then
    Exit;

  while FPendingDeletes.Count > 0 do
  begin
    Control := FPendingDeletes[0];
    FPendingDeletes.Delete(0);
    Control.Free;
  end;
end;

procedure TGuiManager.RemoveControlRuntime(AControl: TGuiControl);
var
  Handle: Integer;
begin
  if AControl = nil then
    Exit;

  if Assigned(FOnControlRemoved) then
    FOnControlRemoved(AControl);
  FBindings.Remove(AControl);
  FControls.Remove(AControl);
  if FControlToHandle.TryGetValue(AControl, Handle) then
  begin
    FControlToHandle.Remove(AControl);
    FHandleToControl.Remove(Handle);
  end;
end;

procedure TGuiManager.ControlMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Data: TGuiEventData;
begin
  Data := TGuiEventData.Empty;
  Data.X := X;
  Data.Y := Y;
  Data.Button := Ord(Button);
  Data.Modifiers := ShiftToMask(Shift);
  DispatchEvent(TGuiControl(Sender), 'OnMouseDown', Data);
end;

procedure TGuiManager.ControlMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
  Data: TGuiEventData;
begin
  Data := TGuiEventData.Empty;
  Data.X := X;
  Data.Y := Y;
  Data.Modifiers := ShiftToMask(Shift);
  DispatchEvent(TGuiControl(Sender), 'OnMouseMove', Data);
end;

procedure TGuiManager.ControlMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Data: TGuiEventData;
begin
  Data := TGuiEventData.Empty;
  Data.X := X;
  Data.Y := Y;
  Data.Button := Ord(Button);
  Data.Modifiers := ShiftToMask(Shift);
  DispatchEvent(TGuiControl(Sender), 'OnMouseUp', Data);
end;

procedure TGuiManager.ControlMouseEnter(Sender: TObject);
begin
  DispatchEvent(TGuiControl(Sender), 'OnMouseEnter', TGuiEventData.Empty);
end;

procedure TGuiManager.ControlMouseLeave(Sender: TObject);
begin
  DispatchEvent(TGuiControl(Sender), 'OnMouseLeave', TGuiEventData.Empty);
end;

procedure TGuiManager.ControlKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  Data: TGuiEventData;
begin
  Data := TGuiEventData.Empty;
  Data.Key := Key;
  Data.Modifiers := ShiftToMask(Shift);
  DispatchEvent(TGuiControl(Sender), 'OnKeyDown', Data);
end;

procedure TGuiManager.ControlKeyPress(Sender: TObject; var Key: Char);
var
  Data: TGuiEventData;
begin
  Data := TGuiEventData.Empty;
  Data.Key := Ord(Key);
  Data.Text := Key;
  DispatchEvent(TGuiControl(Sender), 'OnKeyPress', Data);
end;

procedure TGuiManager.ControlKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  Data: TGuiEventData;
begin
  Data := TGuiEventData.Empty;
  Data.Key := Key;
  Data.Modifiers := ShiftToMask(Shift);
  DispatchEvent(TGuiControl(Sender), 'OnKeyUp', Data);
end;

procedure TGuiManager.ControlButtonClick(Sender: TObject);
var
  Data: TGuiEventData;
begin
  Data := TGuiEventData.Empty;
  Data.Value := Ord(TGuiButton(Sender).Pressed);
  DispatchEvent(TGuiControl(Sender), 'OnButtonClick', Data);
end;

procedure TGuiManager.ControlChanged(Sender: TObject);
var
  Data: TGuiEventData;
begin
  Data := TGuiEventData.Empty;
  if Sender is TGuiCheckBox then
    Data.Value := Ord(TGuiCheckBox(Sender).Checked)
  else if Sender is TGuiEdit then
    Data.Text := TGuiEdit(Sender).Caption
  else if Sender is TGuiScrollbar then
    Data.Value := TGuiScrollbar(Sender).Pos;
  DispatchEvent(TGuiControl(Sender), 'OnChange', Data);
end;

procedure TGuiManager.ControlFormMoving(Sender: TGuiForm;
  var Left, Top: Single);
var
  Data: TGuiEventData;
begin
  Data := TGuiEventData.Empty;
  Data.X := Left;
  Data.Y := Top;
  DispatchEvent(Sender, 'OnWindowMove', Data);
end;

procedure TGuiManager.ControlFormShow(Sender: TGuiForm);
begin
  DispatchEvent(Sender, 'OnWindowShow', TGuiEventData.Empty);
end;

procedure TGuiManager.ControlFormHide(Sender: TGuiForm);
begin
  DispatchEvent(Sender, 'OnWindowHide', TGuiEventData.Empty);
end;

procedure TGuiManager.ControlPopupClick(Sender: TGuiPopupMenu;
  Index: Integer; const MenuItemText: string);
var
  Data: TGuiEventData;
begin
  Data := TGuiEventData.Empty;
  Data.Index := Index;
  Data.Text := MenuItemText;
  DispatchEvent(Sender, 'OnMenuClick', Data);
end;

procedure TGuiManager.Clear;
begin
  FlushPendingDeletes;
  while FControls.Count > 0 do
    DeleteControl(FControls[FControls.Count - 1]);
  FBindings.Clear;
  FHandleToControl.Clear;
  FControlToHandle.Clear;
  FNextHandle := 1;
  HandleOf(FRoot);
  FMouseCaptured := False;
  if FRoot <> nil then
  begin
    FRoot.ActiveControl := nil;
    FRoot.FocusedControl := nil;
  end;
end;

procedure TGuiManager.Render;
begin
  FlushPendingDeletes;
  if not FEnabled or (FRenderer = nil) or (FRoot = nil) or
     (FRenderer.GuiRenderer = nil) or (FControls.Count = 0) then
    Exit;

  Resize(FRenderer.Width, FRenderer.Height);
  FRoot.Render(FRenderer.GuiRenderer, FRenderer.Width, FRenderer.Height);
end;

procedure TGuiManager.Resize(AWidth, AHeight: Integer);
begin
  if FRoot = nil then
    Exit;
  FRoot.Left := 0;
  FRoot.Top := 0;
  FRoot.Width := Max(1, AWidth);
  FRoot.Height := Max(1, AHeight);
end;

function TGuiManager.LoadLayout(const ALayoutFileName,
  ATextureFileName: string): Boolean;
begin
  Result := False;
  if (FLayout = nil) or not FileExists(ALayoutFileName) then
    Exit;
  if (ATextureFileName <> '') and not FileExists(ATextureFileName) then
    Exit;

  FLayout.LoadFromFile(ALayoutFileName);
  if ATextureFileName <> '' then
    FLayout.TextureFileName := ATextureFileName;
  Result := True;
end;

function TGuiManager.SetTexture(const ATextureFileName: string): Boolean;
begin
  Result := (FLayout <> nil) and FileExists(ATextureFileName);
  if Result then
    FLayout.TextureFileName := ATextureFileName;
end;

function TGuiManager.CreateControl(AKind: TGuiControlKind;
  const AName: string; AParent: TGuiControl): TGuiControl;
begin
  case AKind of
    gckPanel: Result := TGuiPanel.Create(Self);
    gckButton: Result := TGuiButton.Create(Self);
    gckCheckBox: Result := TGuiCheckBox.Create(Self);
    gckEdit: Result := TGuiEdit.Create(Self);
    gckLabel: Result := TGuiLabel.Create(Self);
    gckAdvancedLabel: Result := TGuiAdvancedLabel.Create(Self);
    gckWindow: Result := TGuiForm.Create(Self);
    gckScrollbar: Result := TGuiScrollbar.Create(Self);
    gckPopupMenu: Result := TGuiPopupMenu.Create(Self);
    gckStringGrid: Result := TGuiStringGrid.Create(Self);
  else
    raise EArgumentOutOfRangeException.Create('AKind');
  end;

  try
    Result.Name := MakeUniqueName(AName);
    Result.Layout := FLayout;
    Result.ComponentName := '';
    Result.Left := 0;
    Result.Top := 0;
    Result.Width := 120;
    Result.Height := 32;

    case AKind of
      gckLabel, gckAdvancedLabel:
        begin
          Result.Width := 160;
          Result.Height := 24;
        end;
      gckEdit:
        Result.Width := 180;
      gckWindow:
        begin
          Result.Width := 320;
          Result.Height := 200;
        end;
      gckScrollbar:
        begin
          Result.Width := 180;
          Result.Height := 20;
        end;
      gckPopupMenu:
        begin
          Result.Width := 160;
          Result.Visible := False;
        end;
      gckStringGrid:
        begin
          Result.Width := 320;
          Result.Height := 180;
        end;
    end;

    if (AParent = nil) or not ContainsControl(AParent) then
      AParent := FRoot;
    Result.Parent := AParent;
    FControls.Add(Result);
    ConfigureControlEvents(Result);
    HandleOf(Result);
  except
    Result.Free;
    raise;
  end;
end;

function TGuiManager.CreatePanel(const AName: string;
  AParent: TGuiControl): TGuiPanel;
begin
  Result := TGuiPanel(CreateControl(gckPanel, AName, AParent));
end;

function TGuiManager.CreateButton(const AName: string;
  AParent: TGuiControl): TGuiButton;
begin
  Result := TGuiButton(CreateControl(gckButton, AName, AParent));
end;

function TGuiManager.CreateCheckBox(const AName: string;
  AParent: TGuiControl): TGuiCheckBox;
begin
  Result := TGuiCheckBox(CreateControl(gckCheckBox, AName, AParent));
end;

function TGuiManager.CreateEdit(const AName: string;
  AParent: TGuiControl): TGuiEdit;
begin
  Result := TGuiEdit(CreateControl(gckEdit, AName, AParent));
end;

function TGuiManager.CreateLabel(const AName: string;
  AParent: TGuiControl): TGuiLabel;
begin
  Result := TGuiLabel(CreateControl(gckLabel, AName, AParent));
end;

function TGuiManager.CreateAdvancedLabel(const AName: string;
  AParent: TGuiControl): TGuiAdvancedLabel;
begin
  Result := TGuiAdvancedLabel(CreateControl(gckAdvancedLabel, AName, AParent));
end;

function TGuiManager.CreateWindow(const AName: string;
  AParent: TGuiControl): TGuiForm;
begin
  Result := TGuiForm(CreateControl(gckWindow, AName, AParent));
end;

function TGuiManager.CreateScrollbar(const AName: string;
  AParent: TGuiControl): TGuiScrollbar;
begin
  Result := TGuiScrollbar(CreateControl(gckScrollbar, AName, AParent));
end;

function TGuiManager.CreatePopupMenu(const AName: string;
  AParent: TGuiControl): TGuiPopupMenu;
begin
  Result := TGuiPopupMenu(CreateControl(gckPopupMenu, AName, AParent));
end;

function TGuiManager.CreateStringGrid(const AName: string;
  AParent: TGuiControl): TGuiStringGrid;
begin
  Result := TGuiStringGrid(CreateControl(gckStringGrid, AName, AParent));
end;

procedure TGuiManager.DeleteControl(AControl: TGuiControl);
begin
  if (AControl = nil) or (AControl = FRoot) or not ContainsControl(AControl) then
    Exit;

  if FDispatchDepth > 0 then
  begin
    QueueControlDelete(AControl);
    Exit;
  end;

  while AControl.ChildCount > 0 do
    DeleteControl(AControl.Children[AControl.ChildCount - 1]);
  RemoveControlRuntime(AControl);
  AControl.Free;
end;

procedure TGuiManager.SetParent(AControl, AParent: TGuiControl);
var
  Ancestor: TGuiControl;
begin
  if (AControl = nil) or (AControl = FRoot) or not ContainsControl(AControl) then
    Exit;
  if AParent = nil then
    AParent := FRoot;
  if (AParent <> FRoot) and not ContainsControl(AParent) then
    raise EArgumentException.Create('GUI parent belongs to another manager.');

  Ancestor := AParent;
  while Ancestor <> nil do
  begin
    if Ancestor = AControl then
      raise EInvalidOperation.Create('A GUI control cannot be parented to itself or its child.');
    Ancestor := Ancestor.Parent;
  end;
  AControl.Parent := AParent;
end;

procedure TGuiManager.SetVisible(AControl: TGuiControl; AVisible: Boolean);
var
  Changed: Boolean;
begin
  if (AControl = nil) or ((AControl <> FRoot) and not ContainsControl(AControl)) then
    Exit;
  Changed := AControl.Visible <> AVisible;
  AControl.Visible := AVisible;
  if Changed and (AControl is TGuiForm) then
    if AVisible then
      TGuiForm(AControl).NotifyShow
    else
      TGuiForm(AControl).NotifyHide;
end;

procedure TGuiManager.BringToFront(AControl: TGuiControl);
var
  ParentControl: TGuiControl;
begin
  if (AControl = nil) or (AControl = FRoot) then
    Exit;
  ParentControl := AControl.Parent;
  if ParentControl = nil then
    Exit;
  ParentControl.RemoveChild(AControl);
  ParentControl.AddChild(AControl);
end;

procedure TGuiManager.SendToBack(AControl: TGuiControl);
var
  ParentControl: TGuiControl;
begin
  if (AControl = nil) or (AControl = FRoot) then
    Exit;
  ParentControl := AControl.Parent;
  if ParentControl = nil then
    Exit;
  ParentControl.RemoveChild(AControl);
  ParentControl.InsertChild(0, AControl);
end;

function TGuiManager.ContainsControl(AControl: TGuiControl): Boolean;
begin
  Result := (AControl = FRoot) or
    ((AControl <> nil) and FControls.Contains(AControl));
end;

function TGuiManager.ControlAt(AIndex: Integer): TGuiControl;
begin
  if (AIndex < 0) or (AIndex >= FControls.Count) then
    Exit(nil);
  Result := FControls[AIndex];
end;

function TGuiManager.FindControl(const AName: string): TGuiControl;
var
  Control: TGuiControl;
begin
  if (FRoot <> nil) and SameText(FRoot.Name, AName) then
    Exit(FRoot);
  for Control in FControls do
    if SameText(Control.Name, AName) then
      Exit(Control);
  Result := nil;
end;

function TGuiManager.HandleOf(AControl: TGuiControl): Integer;
begin
  if AControl = nil then
    Exit(0);
  if not ContainsControl(AControl) then
    raise EArgumentException.Create('GUI control belongs to another manager.');
  if FControlToHandle.TryGetValue(AControl, Result) then
    Exit;

  Result := FNextHandle;
  Inc(FNextHandle);
  FControlToHandle.Add(AControl, Result);
  FHandleToControl.Add(Result, AControl);
end;

function TGuiManager.ControlFromHandle(AHandle: Integer): TGuiControl;
begin
  if AHandle = 0 then
    Exit(nil);
  if not FHandleToControl.TryGetValue(AHandle, Result) then
    Result := nil;
end;

function TGuiManager.KindOf(AControl: TGuiControl): TGuiControlKind;
begin
  if AControl is TGuiButton then
    Result := gckButton
  else if AControl is TGuiCheckBox then
    Result := gckCheckBox
  else if AControl is TGuiEdit then
    Result := gckEdit
  else if AControl is TGuiAdvancedLabel then
    Result := gckAdvancedLabel
  else if AControl is TGuiLabel then
    Result := gckLabel
  else if AControl is TGuiForm then
    Result := gckWindow
  else if AControl is TGuiScrollbar then
    Result := gckScrollbar
  else if AControl is TGuiPopupMenu then
    Result := gckPopupMenu
  else if AControl is TGuiStringGrid then
    Result := gckStringGrid
  else
    Result := gckPanel;
end;

function TGuiManager.KindName(AControl: TGuiControl): string;
begin
  case KindOf(AControl) of
    gckPanel: Result := 'Panel';
    gckButton: Result := 'Button';
    gckCheckBox: Result := 'CheckBox';
    gckEdit: Result := 'Edit';
    gckLabel: Result := 'Label';
    gckAdvancedLabel: Result := 'AdvancedLabel';
    gckWindow: Result := 'Window';
    gckScrollbar: Result := 'Scrollbar';
    gckPopupMenu: Result := 'PopupMenu';
    gckStringGrid: Result := 'StringGrid';
  else
    Result := 'Control';
  end;
end;

procedure TGuiManager.SetEventHandler(AControl: TGuiControl;
  const AEventName, AHandlerName, AScriptName: string);
var
  EventMap: TGuiEventBindingMap;
  Binding: TGuiEventBinding;
  EventKey: string;
begin
  if (AControl = nil) or not ContainsControl(AControl) then
    raise EArgumentException.Create('Invalid GUI control.');

  EventKey := LowerCase(CanonicalEventName(AEventName));
  if EventKey = '' then
    raise EArgumentException.Create('GUI event name cannot be empty.');

  if not FBindings.TryGetValue(AControl, EventMap) then
  begin
    EventMap := TGuiEventBindingMap.Create;
    FBindings.Add(AControl, EventMap);
  end;

  if Trim(AHandlerName) = '' then
  begin
    EventMap.Remove(EventKey);
    Exit;
  end;

  Binding.ScriptName := AScriptName;
  Binding.HandlerName := Trim(AHandlerName);
  EventMap.AddOrSetValue(EventKey, Binding);
end;

function TGuiManager.EventHandler(AControl: TGuiControl;
  const AEventName: string): string;
var
  EventMap: TGuiEventBindingMap;
  Binding: TGuiEventBinding;
begin
  Result := '';
  if (AControl <> nil) and
     FBindings.TryGetValue(AControl, EventMap) and
     EventMap.TryGetValue(LowerCase(CanonicalEventName(AEventName)), Binding) then
    Result := Binding.HandlerName;
end;

function TGuiManager.EventScript(AControl: TGuiControl;
  const AEventName: string): string;
var
  EventMap: TGuiEventBindingMap;
  Binding: TGuiEventBinding;
begin
  Result := '';
  if (AControl <> nil) and
     FBindings.TryGetValue(AControl, EventMap) and
     EventMap.TryGetValue(LowerCase(CanonicalEventName(AEventName)), Binding) then
    Result := Binding.ScriptName;
end;

function TGuiManager.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer): Boolean;
var
  LocalX: Integer;
  LocalY: Integer;
begin
  Result := False;
  if not FEnabled or (FRoot = nil) or (FRenderer = nil) then
    Exit;

  LocalX := X - FRenderer.X;
  LocalY := Y - FRenderer.Y;
  Result := PointOverGui(LocalX, LocalY);
  if Result then
  begin
    try
      FRoot.MouseDown(Self, Button, Shift, LocalX, LocalY);
      FMouseCaptured := True;
    finally
      FlushPendingDeletes;
    end;
  end;
end;

function TGuiManager.MouseMove(Shift: TShiftState; X, Y: Integer): Boolean;
var
  LocalX: Integer;
  LocalY: Integer;
  OverGui: Boolean;
begin
  Result := False;
  if not FEnabled or (FRoot = nil) or (FRenderer = nil) then
    Exit;

  LocalX := X - FRenderer.X;
  LocalY := Y - FRenderer.Y;
  OverGui := PointOverGui(LocalX, LocalY);
  if FMouseCaptured or OverGui or
     ((LocalX >= 0) and (LocalY >= 0) and
      (LocalX < FRoot.Width) and (LocalY < FRoot.Height)) then
    try
      FRoot.MouseMove(Self, Shift, LocalX, LocalY);
    finally
      FlushPendingDeletes;
    end;
  Result := FMouseCaptured or OverGui;
end;

function TGuiManager.MouseUp(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer): Boolean;
var
  LocalX: Integer;
  LocalY: Integer;
begin
  Result := False;
  if not FEnabled or (FRoot = nil) or (FRenderer = nil) then
    Exit;

  LocalX := X - FRenderer.X;
  LocalY := Y - FRenderer.Y;
  Result := FMouseCaptured or PointOverGui(LocalX, LocalY);
  if Result then
    try
      FRoot.MouseUp(Self, Button, Shift, LocalX, LocalY);
    finally
      FlushPendingDeletes;
    end;
  FMouseCaptured := False;
end;

function TGuiManager.KeyDown(var Key: Word; Shift: TShiftState): Boolean;
begin
  Result := FEnabled and (FRoot <> nil) and (FRoot.FocusedControl <> nil);
  if Result then
    try
      FRoot.KeyDown(Self, Key, Shift);
    finally
      FlushPendingDeletes;
    end;
end;

function TGuiManager.KeyPress(var Key: Char): Boolean;
begin
  Result := FEnabled and (FRoot <> nil) and (FRoot.FocusedControl <> nil);
  if Result then
    try
      FRoot.KeyPress(Self, Key);
    finally
      FlushPendingDeletes;
    end;
end;

function TGuiManager.KeyUp(var Key: Word; Shift: TShiftState): Boolean;
begin
  Result := FEnabled and (FRoot <> nil) and (FRoot.FocusedControl <> nil);
  if Result then
    try
      FRoot.KeyUp(Self, Key, Shift);
    finally
      FlushPendingDeletes;
    end;
end;

end.
