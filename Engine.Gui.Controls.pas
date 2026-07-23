unit Engine.Gui.Controls;

interface

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.Math, System.Generics.Collections,
  Vcl.Controls, Vcl.Graphics, Vcl.StdCtrls,
  dglOpenGL, Neslib.FastMath,
  Engine.Gui, Engine.Gui.BitmapFont;

type
  TGuiMouseAction = (gmaMouseUp, gmaMouseDown, gmaMouseMove);

  TGuiBaseControl = class;
  TGuiFocusControl = class;
  TGuiForm = class;
  TGuiPopupMenu = class;

  TGuiAcceptMouseQuery = procedure(Sender: TGuiBaseControl; Shift: TShiftState;
    Action: TGuiMouseAction; Button: TMouseButton; X, Y: Integer;
    var Accept: Boolean) of object;
  TGuiFormCanRequest = procedure(Sender: TGuiForm; var Can: Boolean) of object;
  TGuiFormCloseOption = (gcoHide, gcoIgnore, gcoDestroy);
  TGuiFormCanClose = procedure(Sender: TGuiForm; var CanClose: TGuiFormCloseOption) of object;
  TGuiFormNotify = procedure(Sender: TGuiForm) of object;
  TGuiFormMove = procedure(Sender: TGuiForm; var Left, Top: Single) of object;
  TGuiPopupMenuClick = procedure(Sender: TGuiPopupMenu; Index: Integer;
    const MenuItemText: string) of object;

  TGuiBaseComponent = class(TGuiControl)
  private
    FAlphaChannel: Single;
    FAutosize: Boolean;
    FNoZWrite: Boolean;
    FRedrawAtOnce: Boolean;
    FRotation: Single;
    function GetGuiLayout: TGuiLayout;
    function GetGuiLayoutName: string;
    procedure SetAlphaChannel(const Value: Single);
    procedure SetGuiLayout(const Value: TGuiLayout);
    procedure SetGuiLayoutName(const Value: string);
  protected
    function EffectiveTint: TVector4; virtual;
    procedure RenderSkin(ARenderer: TGuiRenderer; const ASkinName: string;
      AX, AY, AWidth, AHeight: Single; AViewportWidth, AViewportHeight: Integer); virtual;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property AlphaChannel: Single read FAlphaChannel write SetAlphaChannel;
    property Autosize: Boolean read FAutosize write FAutosize;
    property GuiLayout: TGuiLayout read GetGuiLayout write SetGuiLayout;
    property GuiLayoutName: string read GetGuiLayoutName write SetGuiLayoutName;
    property NoZWrite: Boolean read FNoZWrite write FNoZWrite;
    property RedrawAtOnce: Boolean read FRedrawAtOnce write FRedrawAtOnce;
    property Rotation: Single read FRotation write FRotation;
  end;

  TGuiBaseControl = class(TGuiBaseComponent)
  private
    FActiveControl: TGuiBaseControl;
    FEnteredControl: TGuiBaseControl;
    FFocusedControl: TGuiFocusControl;
    FKeepMouseEvents: Boolean;
    FOnAcceptMouseQuery: TGuiAcceptMouseQuery;
    FOnMouseDown: TMouseEvent;
    FOnMouseEnter: TNotifyEvent;
    FOnMouseLeave: TNotifyEvent;
    FOnMouseMove: TMouseMoveEvent;
    FOnMouseUp: TMouseEvent;
    procedure SetActiveControl(const Value: TGuiBaseControl);
    procedure SetFocusedControl(const Value: TGuiFocusControl);
  protected
    function AcceptMouse(Shift: TShiftState; Action: TGuiMouseAction;
      Button: TMouseButton; X, Y: Integer): Boolean; virtual;
    procedure DoMouseEnter; virtual;
    procedure DoMouseLeave; virtual;
    function FindRootControl: TGuiBaseControl;
    procedure InternalMouseDown(Shift: TShiftState; Button: TMouseButton; X, Y: Integer); virtual;
    procedure InternalMouseMove(Shift: TShiftState; X, Y: Integer); virtual;
    procedure InternalMouseUp(Shift: TShiftState; Button: TMouseButton; X, Y: Integer); virtual;
  public
    destructor Destroy; override;
    function MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer): Boolean; virtual;
    function MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer): Boolean; virtual;
    function MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer): Boolean; virtual;
    procedure KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState); virtual;
    procedure KeyPress(Sender: TObject; var Key: Char); virtual;
    procedure KeyUp(Sender: TObject; var Key: Word; Shift: TShiftState); virtual;
    property ActiveControl: TGuiBaseControl read FActiveControl write SetActiveControl;
    property KeepMouseEvents: Boolean read FKeepMouseEvents write FKeepMouseEvents default False;
  published
    property FocusedControl: TGuiFocusControl read FFocusedControl write SetFocusedControl;
    property OnAcceptMouseQuery: TGuiAcceptMouseQuery read FOnAcceptMouseQuery write FOnAcceptMouseQuery;
    property OnMouseDown: TMouseEvent read FOnMouseDown write FOnMouseDown;
    property OnMouseEnter: TNotifyEvent read FOnMouseEnter write FOnMouseEnter;
    property OnMouseLeave: TNotifyEvent read FOnMouseLeave write FOnMouseLeave;
    property OnMouseMove: TMouseMoveEvent read FOnMouseMove write FOnMouseMove;
    property OnMouseUp: TMouseEvent read FOnMouseUp write FOnMouseUp;
  end;

  TGuiBaseFontControl = class(TGuiBaseControl)
  private
    FBitmapFont: TGuiCustomBitmapFont;
    FDefaultColor: TColor;
    FFont: TFont;
    FTextCacheColor: TColor;
    FTextCacheKey: string;
    FTextTexture: GLuint;
    FTextTextureHeight: Integer;
    FTextTextureWidth: Integer;
    procedure FontChanged(Sender: TObject);
    procedure SetBitmapFont(const Value: TGuiCustomBitmapFont);
    procedure SetDefaultColor(const Value: TColor);
    procedure SetFont(const Value: TFont);
  protected
    procedure DeleteTextTexture;
    function FitTextToWidth(const AText: string; AMaxWidth: Single): string;
    function MeasureTextHeight: Integer;
    function MeasureTextWidth(const AText: string): Integer;
    function PrepareTextTexture(const AText: string; AColor: TColor): Boolean;
    procedure RenderText(ARenderer: TGuiRenderer; const AText: string;
      AX1, AY1, AX2, AY2: Single; AViewportWidth, AViewportHeight: Integer;
      AAlignment: TAlignment; ATextLayout: TTextLayout; AColor: TColor);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property BitmapFont: TGuiCustomBitmapFont read FBitmapFont write SetBitmapFont;
    property DefaultColor: TColor read FDefaultColor write SetDefaultColor;
    property Font: TFont read FFont write SetFont;
  end;

  TGuiBaseTextControl = class(TGuiBaseFontControl)
  private
    FCaption: string;
    procedure SetCaption(const Value: string);
  public
  published
    property Caption: string read FCaption write SetCaption;
  end;

  TGuiFocusControl = class(TGuiBaseTextControl)
  private
    FFocused: Boolean;
    FFocusedColor: TColor;
    FOnKeyDown: TKeyEvent;
    FOnKeyPress: TKeyPressEvent;
    FOnKeyUp: TKeyEvent;
    procedure SetFocusedColor(const Value: TColor);
  protected
    procedure InternalKeyDown(var Key: Word; Shift: TShiftState); virtual;
    procedure InternalKeyPress(var Key: Char); virtual;
    procedure InternalKeyUp(var Key: Word; Shift: TShiftState); virtual;
    procedure SetFocused(Value: Boolean); virtual;
  public
    procedure KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState); override;
    procedure KeyPress(Sender: TObject; var Key: Char); override;
    procedure KeyUp(Sender: TObject; var Key: Word; Shift: TShiftState); override;
    function RootControl: TGuiBaseControl;
    procedure SetFocus;
    procedure NextControl;
    procedure PrevControl;
  published
    property Focused: Boolean read FFocused write SetFocused;
    property FocusedColor: TColor read FFocusedColor write SetFocusedColor;
    property OnKeyDown: TKeyEvent read FOnKeyDown write FOnKeyDown;
    property OnKeyPress: TKeyPressEvent read FOnKeyPress write FOnKeyPress;
    property OnKeyUp: TKeyEvent read FOnKeyUp write FOnKeyUp;
  end;

  TGuiPanel = class(TGuiBaseControl)
  public
    procedure Render(ARenderer: TGuiRenderer; AViewportWidth, AViewportHeight: Integer); override;
  end;

  TGuiCheckBox = class(TGuiBaseControl)
  private
    FChecked: Boolean;
    FCheckedLayoutName: string;
    FGroup: Integer;
    FOnChange: TNotifyEvent;
    procedure SetChecked(const Value: Boolean);
    procedure SetCheckedLayoutName(const Value: string);
    procedure SetGroup(const Value: Integer);
  protected
    procedure InternalMouseDown(Shift: TShiftState; Button: TMouseButton; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Render(ARenderer: TGuiRenderer; AViewportWidth, AViewportHeight: Integer); override;
  published
    property Checked: Boolean read FChecked write SetChecked;
    property CheckedLayoutName: string read FCheckedLayoutName write SetCheckedLayoutName;
    property GuiLayoutNameChecked: string read FCheckedLayoutName write SetCheckedLayoutName;
    property Group: Integer read FGroup write SetGroup;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  TGuiButton = class(TGuiFocusControl)
  private
    FAllowUp: Boolean;
    FGroup: Integer;
    FOnButtonClick: TNotifyEvent;
    FPressed: Boolean;
    FPressedLayoutName: string;
    procedure SetGroup(const Value: Integer);
    procedure SetPressed(const Value: Boolean);
    procedure SetPressedLayoutName(const Value: string);
  protected
    procedure InternalKeyDown(var Key: Word; Shift: TShiftState); override;
    procedure InternalKeyUp(var Key: Word; Shift: TShiftState); override;
    procedure InternalMouseDown(Shift: TShiftState; Button: TMouseButton; X, Y: Integer); override;
    procedure InternalMouseUp(Shift: TShiftState; Button: TMouseButton; X, Y: Integer); override;
    procedure SetFocused(Value: Boolean); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Render(ARenderer: TGuiRenderer; AViewportWidth, AViewportHeight: Integer); override;
  published
    property AllowUp: Boolean read FAllowUp write FAllowUp;
    property Group: Integer read FGroup write SetGroup;
    property OnButtonClick: TNotifyEvent read FOnButtonClick write FOnButtonClick;
    property Pressed: Boolean read FPressed write SetPressed;
    property PressedLayoutName: string read FPressedLayoutName write SetPressedLayoutName;
    property GuiLayoutNamePressed: string read FPressedLayoutName write SetPressedLayoutName;
  end;

  TGuiEdit = class(TGuiFocusControl)
  private
    FEditChar: string;
    FOnChange: TNotifyEvent;
    FReadOnly: Boolean;
    FSelStart: Integer;
    procedure SetEditChar(const Value: string);
    procedure SetSelStart(const Value: Integer);
  protected
    procedure InternalKeyDown(var Key: Word; Shift: TShiftState); override;
    procedure InternalKeyPress(var Key: Char); override;
    procedure InternalMouseDown(Shift: TShiftState; Button: TMouseButton; X, Y: Integer); override;
    procedure SetFocused(Value: Boolean); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Render(ARenderer: TGuiRenderer; AViewportWidth, AViewportHeight: Integer); override;
  published
    property EditChar: string read FEditChar write SetEditChar;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property ReadOnly: Boolean read FReadOnly write FReadOnly default False;
    property SelStart: Integer read FSelStart write SetSelStart;
  end;

  TGuiLabel = class(TGuiBaseTextControl)
  private
    FAlignment: TAlignment;
    FTextLayout: TTextLayout;
    procedure SetAlignment(const Value: TAlignment);
    procedure SetTextLayout(const Value: TTextLayout);
  public
    constructor Create(AOwner: TComponent); override;
    procedure Render(ARenderer: TGuiRenderer; AViewportWidth, AViewportHeight: Integer); override;
  published
    property Alignment: TAlignment read FAlignment write SetAlignment;
    property TextLayout: TTextLayout read FTextLayout write SetTextLayout;
  end;

  TGuiAdvancedLabel = class(TGuiLabel)
  end;

  TGuiForm = class(TGuiBaseTextControl)
  private
    FMoving: Boolean;
    FOldX: Integer;
    FOldY: Integer;
    FOnCanClose: TGuiFormCanClose;
    FOnCanMove: TGuiFormCanRequest;
    FOnCanResize: TGuiFormCanRequest;
    FOnHide: TGuiFormNotify;
    FOnMoving: TGuiFormMove;
    FOnShow: TGuiFormNotify;
    FTitleColor: TColor;
    FTitleOffset: Single;
    procedure SetTitleColor(const Value: TColor);
  protected
    procedure InternalMouseDown(Shift: TShiftState; Button: TMouseButton; X, Y: Integer); override;
    procedure InternalMouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure InternalMouseUp(Shift: TShiftState; Button: TMouseButton; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Close;
    procedure NotifyHide; virtual;
    procedure NotifyShow; virtual;
    procedure Render(ARenderer: TGuiRenderer; AViewportWidth, AViewportHeight: Integer); override;
  published
    property OnCanClose: TGuiFormCanClose read FOnCanClose write FOnCanClose;
    property OnCanMove: TGuiFormCanRequest read FOnCanMove write FOnCanMove;
    property OnCanResize: TGuiFormCanRequest read FOnCanResize write FOnCanResize;
    property OnHide: TGuiFormNotify read FOnHide write FOnHide;
    property OnMoving: TGuiFormMove read FOnMoving write FOnMoving;
    property OnShow: TGuiFormNotify read FOnShow write FOnShow;
    property TitleColor: TColor read FTitleColor write SetTitleColor;
    property TitleOffset: Single read FTitleOffset write FTitleOffset;
  end;

  TGuiScrollbar = class(TGuiFocusControl)
  private
    FHorizontal: Boolean;
    FKnobLayoutName: string;
    FLocked: Boolean;
    FMax: Single;
    FMin: Single;
    FOnChange: TNotifyEvent;
    FPageSize: Single;
    FPos: Single;
    FScrollOffset: Single;
    FScrolling: Boolean;
    FStep: Single;
    function KnobRect: TGuiRect;
    procedure SetHorizontal(const Value: Boolean);
    procedure SetKnobLayoutName(const Value: string);
    procedure SetMax(const Value: Single);
    procedure SetMin(const Value: Single);
    procedure SetPageSize(const Value: Single);
    procedure SetPos(const Value: Single);
  protected
    procedure InternalMouseDown(Shift: TShiftState; Button: TMouseButton; X, Y: Integer); override;
    procedure InternalMouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure InternalMouseUp(Shift: TShiftState; Button: TMouseButton; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    function MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer): Boolean; override;
    function MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer): Boolean; override;
    procedure PageDown;
    procedure PageUp;
    procedure Render(ARenderer: TGuiRenderer; AViewportWidth, AViewportHeight: Integer); override;
    procedure StepDown;
    procedure StepUp;
  published
    property GuiLayoutKnobName: string read FKnobLayoutName write SetKnobLayoutName;
    property Horizontal: Boolean read FHorizontal write SetHorizontal;
    property KnobLayoutName: string read FKnobLayoutName write SetKnobLayoutName;
    property Locked: Boolean read FLocked write FLocked default False;
    property Max: Single read FMax write SetMax;
    property Min: Single read FMin write SetMin;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property PageSize: Single read FPageSize write SetPageSize;
    property Pos: Single read FPos write SetPos;
    property Step: Single read FStep write FStep;
  end;

  TGuiPopupMenu = class(TGuiFocusControl)
  private
    FMarginSize: Single;
    FMenuItems: TStringList;
    FOnClick: TGuiPopupMenuClick;
    FSelIndex: Integer;
    function GetMenuItems: TStrings;
    procedure MenuItemsChanged(Sender: TObject);
    procedure SetMarginSize(const Value: Single);
    procedure SetMenuItems(const Value: TStrings);
    procedure SetSelIndex(const Value: Integer);
  protected
    procedure InternalMouseDown(Shift: TShiftState; Button: TMouseButton; X, Y: Integer); override;
    procedure InternalMouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure SetFocused(Value: Boolean); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer): Boolean; override;
    procedure Popup(PX, PY: Integer);
    procedure Render(ARenderer: TGuiRenderer; AViewportWidth, AViewportHeight: Integer); override;
  published
    property MarginSize: Single read FMarginSize write SetMarginSize;
    property MenuItems: TStrings read GetMenuItems write SetMenuItems;
    property OnClick: TGuiPopupMenuClick read FOnClick write FOnClick;
    property SelIndex: Integer read FSelIndex write SetSelIndex;
  end;

  TGuiStringGrid = class(TGuiFocusControl)
  private
    FColumnSize: Integer;
    FColumns: TStringList;
    FDrawHeader: Boolean;
    FHeaderColor: TColor;
    FMarginSize: Integer;
    FRows: TObjectList<TStringList>;
    FRowHeight: Integer;
    FSelCol: Integer;
    FSelRow: Integer;
    function GetColumns: TStrings;
    function GetRow(Index: Integer): TStringList;
    function GetRowCount: Integer;
    procedure SetColumns(const Value: TStrings);
    procedure SetRowCount(const Value: Integer);
  protected
    procedure InternalMouseDown(Shift: TShiftState; Button: TMouseButton; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function Add(const Data: array of string): Integer; overload;
    function Add(const Data: string): Integer; overload;
    procedure Clear;
    procedure Render(ARenderer: TGuiRenderer; AViewportWidth, AViewportHeight: Integer); override;
    procedure SetText(const Data: string);
    property Row[Index: Integer]: TStringList read GetRow;
  published
    property ColumnSize: Integer read FColumnSize write FColumnSize;
    property Columns: TStrings read GetColumns write SetColumns;
    property DrawHeader: Boolean read FDrawHeader write FDrawHeader;
    property HeaderColor: TColor read FHeaderColor write FHeaderColor;
    property MarginSize: Integer read FMarginSize write FMarginSize;
    property RowCount: Integer read GetRowCount write SetRowCount;
    property RowHeight: Integer read FRowHeight write FRowHeight;
    property SelCol: Integer read FSelCol write FSelCol;
    property SelRow: Integer read FSelRow write FSelRow;
  end;

function UnpressGroup(CurrentObject: TGuiControl; AGroupID: Integer; ExceptControl: TGuiControl = nil): Boolean;

implementation

function ColorToVec4(AColor: TColor; AAlpha: Single): TVector4;
var
  LColor: COLORREF;
begin
  LColor := ColorToRGB(AColor);
  Result := Vector4(GetRValue(LColor) / 255.0, GetGValue(LColor) / 255.0,
    GetBValue(LColor) / 255.0, AAlpha);
end;

procedure RenderTextureQuad(ARenderer: TGuiRenderer; ATextureID: GLuint;
  AX, AY, AWidth, AHeight: Single; AViewportWidth, AViewportHeight: Integer;
  const ATint: TVector4);
var
  LVertices: TArray<TGuiVertex>;
begin
  if (ARenderer = nil) or (ATextureID = 0) or (AWidth <= 0) or (AHeight <= 0) then
    Exit;

  SetLength(LVertices, 6);
  LVertices[0].Position := Vector2(AX, AY);
  LVertices[0].TexCoord := Vector2(0, 1);
  LVertices[1].Position := Vector2(AX, AY + AHeight);
  LVertices[1].TexCoord := Vector2(0, 0);
  LVertices[2].Position := Vector2(AX + AWidth, AY + AHeight);
  LVertices[2].TexCoord := Vector2(1, 0);
  LVertices[3].Position := Vector2(AX, AY);
  LVertices[3].TexCoord := Vector2(0, 1);
  LVertices[4].Position := Vector2(AX + AWidth, AY + AHeight);
  LVertices[4].TexCoord := Vector2(1, 0);
  LVertices[5].Position := Vector2(AX + AWidth, AY);
  LVertices[5].TexCoord := Vector2(1, 1);
  ARenderer.RenderVertices(LVertices, ATextureID, AViewportWidth, AViewportHeight, ATint);
end;

function PointInRectF(AX, AY: Single; const ARect: TGuiRect): Boolean;
begin
  Result := (AX >= ARect.X1) and (AX <= ARect.X2) and
    (AY >= ARect.Y1) and (AY <= ARect.Y2);
end;

function UnpressGroup(CurrentObject: TGuiControl; AGroupID: Integer; ExceptControl: TGuiControl): Boolean;
var
  LIndex: Integer;
begin
  Result := False;
  if (CurrentObject = nil) or (AGroupID < 0) then
    Exit;

  if (CurrentObject <> ExceptControl) and (CurrentObject is TGuiButton) and
    (TGuiButton(CurrentObject).Group = AGroupID) and TGuiButton(CurrentObject).Pressed then
  begin
    TGuiButton(CurrentObject).Pressed := False;
    Result := True;
  end
  else if (CurrentObject <> ExceptControl) and (CurrentObject is TGuiCheckBox) and
    (TGuiCheckBox(CurrentObject).Group = AGroupID) and TGuiCheckBox(CurrentObject).Checked then
  begin
    TGuiCheckBox(CurrentObject).Checked := False;
    Result := True;
  end;

  for LIndex := 0 to CurrentObject.ChildCount - 1 do
    Result := UnpressGroup(CurrentObject.Children[LIndex], AGroupID, ExceptControl) or Result;
end;

{ TGuiBaseComponent }

constructor TGuiBaseComponent.Create(AOwner: TComponent);
begin
  inherited;
  FAlphaChannel := 1.0;
end;

function TGuiBaseComponent.EffectiveTint: TVector4;
begin
  Result := Tint;
  Result.W := Result.W * FAlphaChannel;
end;

function TGuiBaseComponent.GetGuiLayout: TGuiLayout;
begin
  Result := Layout;
end;

function TGuiBaseComponent.GetGuiLayoutName: string;
begin
  Result := ComponentName;
end;

procedure TGuiBaseComponent.RenderSkin(ARenderer: TGuiRenderer; const ASkinName: string;
  AX, AY, AWidth, AHeight: Single; AViewportWidth, AViewportHeight: Integer);
begin
  if (ARenderer = nil) or (Layout = nil) or (ASkinName = '') then
    Exit;

  ARenderer.RenderLayout(Layout, ASkinName, AX, AY, AWidth, AHeight,
    AViewportWidth, AViewportHeight, EffectiveTint);
end;

procedure TGuiBaseComponent.SetAlphaChannel(const Value: Single);
begin
  FAlphaChannel := System.Math.EnsureRange(Value, 0.0, 1.0);
end;

procedure TGuiBaseComponent.SetGuiLayout(const Value: TGuiLayout);
begin
  Layout := Value;
end;

procedure TGuiBaseComponent.SetGuiLayoutName(const Value: string);
begin
  ComponentName := Value;
end;

{ TGuiBaseControl }

destructor TGuiBaseControl.Destroy;
begin
  if FEnteredControl <> nil then
    FEnteredControl.DoMouseLeave;
  inherited;
end;

function TGuiBaseControl.AcceptMouse(Shift: TShiftState; Action: TGuiMouseAction;
  Button: TMouseButton; X, Y: Integer): Boolean;
begin
  Result := RecursiveVisible and (X >= AbsoluteLeft) and (X < AbsoluteLeft + Width) and
    (Y >= AbsoluteTop) and (Y < AbsoluteTop + Height);
  if Assigned(FOnAcceptMouseQuery) then
    FOnAcceptMouseQuery(Self, Shift, Action, Button, X, Y, Result);
end;

procedure TGuiBaseControl.DoMouseEnter;
begin
  if Assigned(FOnMouseEnter) then
    FOnMouseEnter(Self);
end;

procedure TGuiBaseControl.DoMouseLeave;
begin
  if Assigned(FOnMouseLeave) then
    FOnMouseLeave(Self);
end;

function TGuiBaseControl.FindRootControl: TGuiBaseControl;
var
  LParent: TGuiControl;
begin
  Result := Self;
  LParent := Parent;
  while LParent <> nil do
  begin
    if LParent is TGuiBaseControl then
      Result := TGuiBaseControl(LParent);
    LParent := LParent.Parent;
  end;
end;

procedure TGuiBaseControl.InternalMouseDown(Shift: TShiftState; Button: TMouseButton; X, Y: Integer);
begin
  if Assigned(FOnMouseDown) then
    FOnMouseDown(Self, Button, Shift, X, Y);
end;

procedure TGuiBaseControl.InternalMouseMove(Shift: TShiftState; X, Y: Integer);
begin
  if Assigned(FOnMouseMove) then
    FOnMouseMove(Self, Shift, X, Y);
end;

procedure TGuiBaseControl.InternalMouseUp(Shift: TShiftState; Button: TMouseButton; X, Y: Integer);
begin
  if Assigned(FOnMouseUp) then
    FOnMouseUp(Self, Button, Shift, X, Y);
end;

procedure TGuiBaseControl.KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if FFocusedControl <> nil then
    FFocusedControl.KeyDown(Sender, Key, Shift);
end;

procedure TGuiBaseControl.KeyPress(Sender: TObject; var Key: Char);
begin
  if FFocusedControl <> nil then
    FFocusedControl.KeyPress(Sender, Key);
end;

procedure TGuiBaseControl.KeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if FFocusedControl <> nil then
    FFocusedControl.KeyUp(Sender, Key, Shift);
end;

function TGuiBaseControl.MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer): Boolean;
var
  LIndex: Integer;
  LChild: TGuiControl;
begin
  Result := False;
  if not AcceptMouse(Shift, gmaMouseDown, Button, X, Y) then
    Exit;

  Result := True;
  if not FKeepMouseEvents then
  begin
    if (FActiveControl <> nil) and FActiveControl.MouseDown(Sender, Button, Shift, X, Y) then
      Exit;

    for LIndex := ChildCount - 1 downto 0 do
    begin
      LChild := Children[LIndex];
      if (LChild <> FActiveControl) and (LChild is TGuiBaseControl) and
        TGuiBaseControl(LChild).MouseDown(Sender, Button, Shift, X, Y) then
        Exit;
    end;
  end;

  InternalMouseDown(Shift, Button, X, Y);
end;

function TGuiBaseControl.MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer): Boolean;
var
  LIndex: Integer;
  LChild: TGuiControl;
  LHandledChild: TGuiBaseControl;
begin
  Result := False;
  if not AcceptMouse(Shift, gmaMouseMove, mbMiddle, X, Y) then
  begin
    if FEnteredControl <> nil then
    begin
      FEnteredControl.DoMouseLeave;
      FEnteredControl := nil;
    end;
    Exit;
  end;

  Result := True;
  if not FKeepMouseEvents then
  begin
    if (FActiveControl <> nil) and FActiveControl.MouseMove(Sender, Shift, X, Y) then
      Exit;

    for LIndex := ChildCount - 1 downto 0 do
    begin
      LChild := Children[LIndex];
      if (LChild <> FActiveControl) and (LChild is TGuiBaseControl) and
        TGuiBaseControl(LChild).MouseMove(Sender, Shift, X, Y) then
      begin
        LHandledChild := TGuiBaseControl(LChild);
        if FEnteredControl <> LHandledChild then
        begin
          if FEnteredControl <> nil then
            FEnteredControl.DoMouseLeave;
          FEnteredControl := LHandledChild;
          FEnteredControl.DoMouseEnter;
        end;
        Exit;
      end;
    end;
  end;

  if FEnteredControl <> nil then
  begin
    FEnteredControl.DoMouseLeave;
    FEnteredControl := nil;
  end;
  InternalMouseMove(Shift, X, Y);
end;

function TGuiBaseControl.MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer): Boolean;
var
  LIndex: Integer;
  LChild: TGuiControl;
begin
  Result := False;
  if not AcceptMouse(Shift, gmaMouseUp, Button, X, Y) then
    Exit;

  Result := True;
  if not FKeepMouseEvents then
  begin
    if (FActiveControl <> nil) and FActiveControl.MouseUp(Sender, Button, Shift, X, Y) then
      Exit;

    for LIndex := ChildCount - 1 downto 0 do
    begin
      LChild := Children[LIndex];
      if (LChild <> FActiveControl) and (LChild is TGuiBaseControl) and
        TGuiBaseControl(LChild).MouseUp(Sender, Button, Shift, X, Y) then
        Exit;
    end;
  end;

  InternalMouseUp(Shift, Button, X, Y);
end;

procedure TGuiBaseControl.SetActiveControl(const Value: TGuiBaseControl);
begin
  FActiveControl := Value;
end;

procedure TGuiBaseControl.SetFocusedControl(const Value: TGuiFocusControl);
begin
  if FFocusedControl = Value then
    Exit;

  if FFocusedControl <> nil then
    FFocusedControl.Focused := False;
  FFocusedControl := Value;
  if FFocusedControl <> nil then
    FFocusedControl.Focused := True;
end;

{ TGuiBaseFontControl }

constructor TGuiBaseFontControl.Create(AOwner: TComponent);
begin
  inherited;
  FFont := TFont.Create;
  FFont.Name := 'Segoe UI';
  FFont.Size := 10;
  FFont.OnChange := FontChanged;
  FDefaultColor := clWhite;
  FTextCacheColor := clNone;
end;

destructor TGuiBaseFontControl.Destroy;
begin
  DeleteTextTexture;
  FFont.Free;
  inherited;
end;

procedure TGuiBaseFontControl.DeleteTextTexture;
begin
  if FTextTexture <> 0 then
  begin
    glDeleteTextures(1, @FTextTexture);
    FTextTexture := 0;
  end;
  FTextTextureWidth := 0;
  FTextTextureHeight := 0;
  FTextCacheKey := '';
end;

function TGuiBaseFontControl.FitTextToWidth(const AText: string; AMaxWidth: Single): string;
begin
  Result := AText;
  while (Result <> '') and (MeasureTextWidth(Result) > Trunc(AMaxWidth)) do
    Delete(Result, 1, 1);
end;

procedure TGuiBaseFontControl.FontChanged(Sender: TObject);
begin
  DeleteTextTexture;
end;

function TGuiBaseFontControl.MeasureTextHeight: Integer;
var
  LBitmap: TBitmap;
begin
  if FBitmapFont <> nil then
    Exit(FBitmapFont.CharHeight);

  LBitmap := TBitmap.Create;
  try
    LBitmap.SetSize(1, 1);
    LBitmap.Canvas.Font.Assign(FFont);
    Result := LBitmap.Canvas.TextHeight('Mg');
  finally
    LBitmap.Free;
  end;
end;

function TGuiBaseFontControl.MeasureTextWidth(const AText: string): Integer;
var
  LBitmap: TBitmap;
begin
  if AText = '' then
    Exit(0);

  if FBitmapFont <> nil then
    Exit(FBitmapFont.CalcStringWidth(AText));

  LBitmap := TBitmap.Create;
  try
    LBitmap.SetSize(1, 1);
    LBitmap.Canvas.Font.Assign(FFont);
    Result := LBitmap.Canvas.TextWidth(AText);
  finally
    LBitmap.Free;
  end;
end;

function TGuiBaseFontControl.PrepareTextTexture(const AText: string; AColor: TColor): Boolean;
var
  LBitmap: TBitmap;
  LData: TBytes;
  LWidth: Integer;
  LHeight: Integer;
  LRow: PByte;
  LX: Integer;
  LY: Integer;
  LSrc: PByte;
  LDst: PByte;
  LMask: Byte;
  LColor: COLORREF;
  LRed: Byte;
  LGreen: Byte;
  LBlue: Byte;
  LCacheKey: string;
begin
  Result := False;
  if AText = '' then
  begin
    DeleteTextTexture;
    Exit;
  end;

  LCacheKey := AText + '|' + IntToStr(ColorToRGB(AColor));
  if (FTextTexture <> 0) and (FTextCacheKey = LCacheKey) and (FTextCacheColor = AColor) then
    Exit(True);

  LBitmap := TBitmap.Create;
  try
    LBitmap.PixelFormat := pf32bit;
    LBitmap.SetSize(1, 1);
    LBitmap.Canvas.Font.Assign(FFont);
    LWidth := Max(1, LBitmap.Canvas.TextWidth(AText) + 2);
    LHeight := Max(1, LBitmap.Canvas.TextHeight('Mg') + 2);
    LBitmap.SetSize(LWidth, LHeight);
    LBitmap.Canvas.Brush.Color := clBlack;
    LBitmap.Canvas.FillRect(Rect(0, 0, LWidth, LHeight));
    LBitmap.Canvas.Font.Assign(FFont);
    LBitmap.Canvas.Font.Color := clWhite;
    LBitmap.Canvas.TextOut(1, 1, AText);

    LColor := ColorToRGB(AColor);
    LRed := GetRValue(LColor);
    LGreen := GetGValue(LColor);
    LBlue := GetBValue(LColor);
    SetLength(LData, LWidth * LHeight * 4);

    for LY := 0 to LHeight - 1 do
    begin
      LRow := LBitmap.ScanLine[LHeight - 1 - LY];
      for LX := 0 to LWidth - 1 do
      begin
        LSrc := LRow + (LX * 4);
        LDst := @LData[((LY * LWidth) + LX) * 4];
        LMask := System.Math.Max(LSrc[0], System.Math.Max(LSrc[1], LSrc[2]));
        LDst[0] := LRed;
        LDst[1] := LGreen;
        LDst[2] := LBlue;
        LDst[3] := LMask;
      end;
    end;

    if FTextTexture = 0 then
      glGenTextures(1, @FTextTexture);
    glBindTexture(GL_TEXTURE_2D, FTextTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, LWidth, LHeight, 0,
      GL_RGBA, GL_UNSIGNED_BYTE, Pointer(LData));
    glBindTexture(GL_TEXTURE_2D, 0);

    FTextTextureWidth := LWidth;
    FTextTextureHeight := LHeight;
    FTextCacheKey := LCacheKey;
    FTextCacheColor := AColor;
    Result := True;
  finally
    LBitmap.Free;
  end;
end;

procedure TGuiBaseFontControl.RenderText(ARenderer: TGuiRenderer; const AText: string;
  AX1, AY1, AX2, AY2: Single; AViewportWidth, AViewportHeight: Integer;
  AAlignment: TAlignment; ATextLayout: TTextLayout; AColor: TColor);
var
  LX: Single;
  LY: Single;
  LWidth: Single;
  LHeight: Single;
begin
  if FBitmapFont <> nil then
  begin
    FBitmapFont.RenderTextInRect(ARenderer, AText, AX1, AY1, AX2, AY2,
      AViewportWidth, AViewportHeight, AAlignment, ATextLayout,
      ColorToVec4(AColor, AlphaChannel));
    Exit;
  end;

  if not PrepareTextTexture(AText, AColor) then
    Exit;

  LWidth := FTextTextureWidth;
  LHeight := FTextTextureHeight;
  case AAlignment of
    taCenter:
      LX := AX1 + ((AX2 - AX1) - LWidth) * 0.5;
    taRightJustify:
      LX := AX2 - LWidth;
  else
    LX := AX1;
  end;

  case ATextLayout of
    tlTop:
      LY := AY1;
    tlBottom:
      LY := AY2 - LHeight;
  else
    LY := AY1 + ((AY2 - AY1) - LHeight) * 0.5;
  end;

  RenderTextureQuad(ARenderer, FTextTexture, LX, LY, LWidth, LHeight,
    AViewportWidth, AViewportHeight, Vector4(1, 1, 1, AlphaChannel));
end;

procedure TGuiBaseFontControl.SetBitmapFont(const Value: TGuiCustomBitmapFont);
begin
  if FBitmapFont <> Value then
  begin
    FBitmapFont := Value;
    DeleteTextTexture;
  end;
end;

procedure TGuiBaseFontControl.SetDefaultColor(const Value: TColor);
begin
  if FDefaultColor <> Value then
  begin
    FDefaultColor := Value;
    DeleteTextTexture;
  end;
end;

procedure TGuiBaseFontControl.SetFont(const Value: TFont);
begin
  FFont.Assign(Value);
  DeleteTextTexture;
end;

{ TGuiBaseTextControl }

procedure TGuiBaseTextControl.SetCaption(const Value: string);
begin
  if FCaption <> Value then
  begin
    FCaption := Value;
    DeleteTextTexture;
  end;
end;

{ TGuiFocusControl }

procedure TGuiFocusControl.InternalKeyDown(var Key: Word; Shift: TShiftState);
begin
  if Assigned(FOnKeyDown) then
    FOnKeyDown(Self, Key, Shift);
end;

procedure TGuiFocusControl.InternalKeyPress(var Key: Char);
begin
  if Assigned(FOnKeyPress) then
    FOnKeyPress(Self, Key);
end;

procedure TGuiFocusControl.InternalKeyUp(var Key: Word; Shift: TShiftState);
begin
  if Assigned(FOnKeyUp) then
    FOnKeyUp(Self, Key, Shift);
end;

procedure TGuiFocusControl.KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  InternalKeyDown(Key, Shift);
end;

procedure TGuiFocusControl.KeyPress(Sender: TObject; var Key: Char);
begin
  InternalKeyPress(Key);
end;

procedure TGuiFocusControl.KeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  InternalKeyUp(Key, Shift);
end;

procedure TGuiFocusControl.NextControl;
begin
end;

procedure TGuiFocusControl.PrevControl;
begin
end;

function TGuiFocusControl.RootControl: TGuiBaseControl;
begin
  Result := FindRootControl;
end;

procedure TGuiFocusControl.SetFocus;
var
  LRoot: TGuiBaseControl;
begin
  LRoot := RootControl;
  if LRoot <> nil then
    LRoot.FocusedControl := Self;
end;

procedure TGuiFocusControl.SetFocused(Value: Boolean);
begin
  if FFocused <> Value then
  begin
    FFocused := Value;
    DeleteTextTexture;
  end;
end;

procedure TGuiFocusControl.SetFocusedColor(const Value: TColor);
begin
  if FFocusedColor <> Value then
  begin
    FFocusedColor := Value;
    DeleteTextTexture;
  end;
end;

{ TGuiPanel }

procedure TGuiPanel.Render(ARenderer: TGuiRenderer; AViewportWidth, AViewportHeight: Integer);
var
  LIndex: Integer;
begin
  if not RecursiveVisible then
    Exit;
  RenderSkin(ARenderer, ComponentName, AbsoluteLeft, AbsoluteTop, Width, Height,
    AViewportWidth, AViewportHeight);
  for LIndex := 0 to ChildCount - 1 do
    Children[LIndex].Render(ARenderer, AViewportWidth, AViewportHeight);
end;

{ TGuiCheckBox }

constructor TGuiCheckBox.Create(AOwner: TComponent);
begin
  inherited;
  FGroup := -1;
end;

procedure TGuiCheckBox.InternalMouseDown(Shift: TShiftState; Button: TMouseButton; X, Y: Integer);
begin
  if Button = mbLeft then
    Checked := not Checked;
  inherited;
end;

procedure TGuiCheckBox.Render(ARenderer: TGuiRenderer; AViewportWidth, AViewportHeight: Integer);
var
  LIndex: Integer;
  LSkin: string;
begin
  if not RecursiveVisible then
    Exit;

  LSkin := ComponentName;
  if FChecked and (FCheckedLayoutName <> '') then
    LSkin := FCheckedLayoutName;
  RenderSkin(ARenderer, LSkin, AbsoluteLeft, AbsoluteTop, Width, Height,
    AViewportWidth, AViewportHeight);

  for LIndex := 0 to ChildCount - 1 do
    Children[LIndex].Render(ARenderer, AViewportWidth, AViewportHeight);
end;

procedure TGuiCheckBox.SetChecked(const Value: Boolean);
begin
  if FChecked = Value then
    Exit;
  if Value and (FGroup >= 0) then
    UnpressGroup(FindRootControl, FGroup, Self);
  FChecked := Value;
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TGuiCheckBox.SetCheckedLayoutName(const Value: string);
begin
  FCheckedLayoutName := Value;
end;

procedure TGuiCheckBox.SetGroup(const Value: Integer);
begin
  FGroup := Value;
  if FChecked and (FGroup >= 0) then
    UnpressGroup(FindRootControl, FGroup, Self);
end;

{ TGuiButton }

constructor TGuiButton.Create(AOwner: TComponent);
begin
  inherited;
  FGroup := -1;
  FFocusedColor := clYellow;
end;

procedure TGuiButton.InternalKeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited;
  if Key in [VK_SPACE, VK_RETURN] then
    Pressed := True;
end;

procedure TGuiButton.InternalKeyUp(var Key: Word; Shift: TShiftState);
begin
  if (Key in [VK_SPACE, VK_RETURN]) and (FGroup < 0) then
    Pressed := False;
  inherited;
end;

procedure TGuiButton.InternalMouseDown(Shift: TShiftState; Button: TMouseButton; X, Y: Integer);
begin
  FindRootControl.ActiveControl := Self;
  inherited InternalMouseDown(Shift, Button, X, Y);
  if Button = mbLeft then
  begin
    if FAllowUp then
      Pressed := not Pressed
    else
      Pressed := True;
  end;
end;

procedure TGuiButton.InternalMouseUp(Shift: TShiftState; Button: TMouseButton; X, Y: Integer);
begin
  if (Button = mbLeft) and (FGroup < 0) then
    Pressed := False;
  inherited;
end;

procedure TGuiButton.Render(ARenderer: TGuiRenderer; AViewportWidth, AViewportHeight: Integer);
var
  LIndex: Integer;
  LSkin: string;
  LTextColor: TColor;
begin
  if not RecursiveVisible then
    Exit;

  LSkin := ComponentName;
  if FPressed and (FPressedLayoutName <> '') then
    LSkin := FPressedLayoutName;
  RenderSkin(ARenderer, LSkin, AbsoluteLeft, AbsoluteTop, Width, Height,
    AViewportWidth, AViewportHeight);

  if FFocused then
    LTextColor := FFocusedColor
  else
    LTextColor := DefaultColor;
  RenderText(ARenderer, Caption, AbsoluteLeft + 4, AbsoluteTop,
    AbsoluteLeft + Width - 4, AbsoluteTop + Height, AViewportWidth,
    AViewportHeight, taCenter, tlCenter, LTextColor);

  for LIndex := 0 to ChildCount - 1 do
    Children[LIndex].Render(ARenderer, AViewportWidth, AViewportHeight);
end;

procedure TGuiButton.SetFocused(Value: Boolean);
begin
  inherited;
  if (not Value) and (FGroup < 0) then
    FPressed := False;
end;

procedure TGuiButton.SetGroup(const Value: Integer);
begin
  FGroup := Value;
  if FPressed and (FGroup >= 0) then
    UnpressGroup(RootControl, FGroup, Self);
end;

procedure TGuiButton.SetPressed(const Value: Boolean);
begin
  if FPressed = Value then
    Exit;
  if Value and (FGroup >= 0) then
    UnpressGroup(RootControl, FGroup, Self);
  FPressed := Value;
  if FPressed and Assigned(FOnButtonClick) then
    FOnButtonClick(Self);
end;

procedure TGuiButton.SetPressedLayoutName(const Value: string);
begin
  FPressedLayoutName := Value;
end;

{ TGuiEdit }

constructor TGuiEdit.Create(AOwner: TComponent);
begin
  inherited;
  FEditChar := '|';
  FSelStart := 1;
  FFocusedColor := clWhite;
end;

procedure TGuiEdit.InternalKeyDown(var Key: Word; Shift: TShiftState);
begin
  if FReadOnly then
    Exit;
  inherited;
  case Key of
    VK_DELETE:
      if FSelStart <= Length(Caption) then
      begin
        Delete(FCaption, FSelStart, 1);
        DeleteTextTexture;
        if Assigned(FOnChange) then
          FOnChange(Self);
      end;
    VK_LEFT:
      SelStart := FSelStart - 1;
    VK_RIGHT:
      SelStart := FSelStart + 1;
    VK_HOME:
      SelStart := 1;
    VK_END:
      SelStart := Length(Caption) + 1;
  end;
end;

procedure TGuiEdit.InternalKeyPress(var Key: Char);
begin
  if FReadOnly then
    Exit;
  inherited;
  case Key of
    #8:
      if FSelStart > 1 then
      begin
        Delete(FCaption, FSelStart - 1, 1);
        SelStart := FSelStart - 1;
        DeleteTextTexture;
        if Assigned(FOnChange) then
          FOnChange(Self);
      end;
  else
    if Key >= #32 then
    begin
      Insert(Key, FCaption, FSelStart);
      SelStart := FSelStart + 1;
      DeleteTextTexture;
      if Assigned(FOnChange) then
        FOnChange(Self);
    end;
  end;
end;

procedure TGuiEdit.InternalMouseDown(Shift: TShiftState; Button: TMouseButton; X, Y: Integer);
begin
  if not FReadOnly then
    SetFocus;
  inherited;
end;

procedure TGuiEdit.Render(ARenderer: TGuiRenderer; AViewportWidth, AViewportHeight: Integer);
var
  LIndex: Integer;
  LText: string;
  LTextColor: TColor;
begin
  if not RecursiveVisible then
    Exit;

  RenderSkin(ARenderer, ComponentName, AbsoluteLeft, AbsoluteTop, Width, Height,
    AViewportWidth, AViewportHeight);

  LText := Caption;
  if FFocused then
    Insert(FEditChar, LText, FSelStart);
  LText := FitTextToWidth(LText, Width - 8);

  if FFocused then
    LTextColor := FFocusedColor
  else
    LTextColor := DefaultColor;
  RenderText(ARenderer, LText, AbsoluteLeft + 4, AbsoluteTop, AbsoluteLeft + Width - 4,
    AbsoluteTop + Height, AViewportWidth, AViewportHeight, taLeftJustify, tlCenter, LTextColor);

  for LIndex := 0 to ChildCount - 1 do
    Children[LIndex].Render(ARenderer, AViewportWidth, AViewportHeight);
end;

procedure TGuiEdit.SetEditChar(const Value: string);
begin
  FEditChar := Value;
  DeleteTextTexture;
end;

procedure TGuiEdit.SetFocused(Value: Boolean);
begin
  inherited;
  if Value then
    SelStart := Length(Caption) + 1;
end;

procedure TGuiEdit.SetSelStart(const Value: Integer);
begin
  FSelStart := System.Math.EnsureRange(Value, 1, Length(Caption) + 1);
  DeleteTextTexture;
end;

{ TGuiLabel }

constructor TGuiLabel.Create(AOwner: TComponent);
begin
  inherited;
  FAlignment := taLeftJustify;
  FTextLayout := tlCenter;
end;

procedure TGuiLabel.Render(ARenderer: TGuiRenderer; AViewportWidth, AViewportHeight: Integer);
var
  LIndex: Integer;
begin
  if not RecursiveVisible then
    Exit;
  RenderSkin(ARenderer, ComponentName, AbsoluteLeft, AbsoluteTop, Width, Height,
    AViewportWidth, AViewportHeight);
  RenderText(ARenderer, Caption, AbsoluteLeft, AbsoluteTop, AbsoluteLeft + Width,
    AbsoluteTop + Height, AViewportWidth, AViewportHeight, FAlignment, FTextLayout, DefaultColor);
  for LIndex := 0 to ChildCount - 1 do
    Children[LIndex].Render(ARenderer, AViewportWidth, AViewportHeight);
end;

procedure TGuiLabel.SetAlignment(const Value: TAlignment);
begin
  FAlignment := Value;
end;

procedure TGuiLabel.SetTextLayout(const Value: TTextLayout);
begin
  FTextLayout := Value;
end;

{ TGuiForm }

constructor TGuiForm.Create(AOwner: TComponent);
begin
  inherited;
  FTitleColor := clWhite;
  FTitleOffset := 6;
end;

procedure TGuiForm.Close;
var
  LClose: TGuiFormCloseOption;
begin
  LClose := gcoHide;
  if Assigned(FOnCanClose) then
    FOnCanClose(Self, LClose);

  case LClose of
    gcoHide:
      begin
        Visible := False;
        NotifyHide;
      end;
    gcoDestroy:
      Free;
  end;
end;

procedure TGuiForm.InternalMouseDown(Shift: TShiftState; Button: TMouseButton; X, Y: Integer);
var
  LCanMove: Boolean;
begin
  FindRootControl.ActiveControl := Self;
  inherited InternalMouseDown(Shift, Button, X, Y);
  if Button <> mbLeft then
    Exit;

  LCanMove := True;
  if Assigned(FOnCanMove) then
    FOnCanMove(Self, LCanMove);
  if LCanMove and (Y < AbsoluteTop + System.Math.Max(MeasureTextHeight + FTitleOffset, 20)) then
  begin
    FMoving := True;
    FOldX := X;
    FOldY := Y;
    FindRootControl.ActiveControl := Self;
  end;
end;

procedure TGuiForm.InternalMouseMove(Shift: TShiftState; X, Y: Integer);
var
  LLeft: Single;
  LTop: Single;
begin
  inherited;
  if not FMoving then
    Exit;

  LLeft := Left + (X - FOldX);
  LTop := Top + (Y - FOldY);
  if Assigned(FOnMoving) then
    FOnMoving(Self, LLeft, LTop);
  Left := LLeft;
  Top := LTop;
  FOldX := X;
  FOldY := Y;
end;

procedure TGuiForm.InternalMouseUp(Shift: TShiftState; Button: TMouseButton; X, Y: Integer);
begin
  FMoving := False;
  if FindRootControl.ActiveControl = Self then
    FindRootControl.ActiveControl := nil;
  inherited;
end;

procedure TGuiForm.NotifyHide;
begin
  if Assigned(FOnHide) then
    FOnHide(Self);
end;

procedure TGuiForm.NotifyShow;
begin
  if Assigned(FOnShow) then
    FOnShow(Self);
end;

procedure TGuiForm.Render(ARenderer: TGuiRenderer; AViewportWidth, AViewportHeight: Integer);
var
  LIndex: Integer;
begin
  if not RecursiveVisible then
    Exit;
  RenderSkin(ARenderer, ComponentName, AbsoluteLeft, AbsoluteTop, Width, Height,
    AViewportWidth, AViewportHeight);
  RenderText(ARenderer, Caption, AbsoluteLeft + 8, AbsoluteTop + FTitleOffset,
    AbsoluteLeft + Width - 8, AbsoluteTop + FTitleOffset + MeasureTextHeight + 4,
    AViewportWidth, AViewportHeight, taLeftJustify, tlCenter, FTitleColor);
  for LIndex := 0 to ChildCount - 1 do
    Children[LIndex].Render(ARenderer, AViewportWidth, AViewportHeight);
end;

procedure TGuiForm.SetTitleColor(const Value: TColor);
begin
  FTitleColor := Value;
  DeleteTextTexture;
end;

{ TGuiScrollbar }

constructor TGuiScrollbar.Create(AOwner: TComponent);
begin
  inherited;
  FMin := 0;
  FMax := 100;
  FStep := 1;
  FPageSize := 10;
end;

procedure TGuiScrollbar.InternalMouseDown(Shift: TShiftState; Button: TMouseButton; X, Y: Integer);
var
  LKnob: TGuiRect;
begin
  SetFocus;
  inherited;
  if (Button <> mbLeft) or FLocked then
    Exit;

  LKnob := KnobRect;
  if PointInRectF(X, Y, LKnob) then
  begin
    FScrolling := True;
    if FHorizontal then
      FScrollOffset := X - LKnob.X1
    else
      FScrollOffset := Y - LKnob.Y1;
    FindRootControl.ActiveControl := Self;
  end
  else if FHorizontal then
  begin
    if X < LKnob.X1 then
      PageUp
    else
      PageDown;
  end
  else if Y < LKnob.Y1 then
    PageUp
  else
    PageDown;
end;

procedure TGuiScrollbar.InternalMouseMove(Shift: TShiftState; X, Y: Integer);
var
  LTrack: Single;
  LKnob: TGuiRect;
  LValue: Single;
begin
  inherited;
  if not FScrolling then
    Exit;

  LKnob := KnobRect;
  if FHorizontal then
  begin
    LTrack := System.Math.Max(1.0, Width - LKnob.Width);
    LValue := FMin + ((X - AbsoluteLeft - FScrollOffset) / LTrack) * (FMax - FMin);
  end
  else
  begin
    LTrack := System.Math.Max(1.0, Height - LKnob.Height);
    LValue := FMin + ((Y - AbsoluteTop - FScrollOffset) / LTrack) * (FMax - FMin);
  end;
  Pos := LValue;
end;

procedure TGuiScrollbar.InternalMouseUp(Shift: TShiftState; Button: TMouseButton; X, Y: Integer);
begin
  FScrolling := False;
  if FindRootControl.ActiveControl = Self then
    FindRootControl.ActiveControl := nil;
  inherited;
end;

function TGuiScrollbar.KnobRect: TGuiRect;
var
  LRange: Single;
  LRatio: Single;
  LSize: Single;
  LTrack: Single;
  LOffset: Single;
begin
  LRange := System.Math.Max(0.0001, FMax - FMin);
  LRatio := System.Math.EnsureRange(FPageSize / (LRange + FPageSize), 0.05, 1.0);
  if FHorizontal then
  begin
    LSize := System.Math.Max(10.0, Width * LRatio);
    LTrack := System.Math.Max(1.0, Width - LSize);
    LOffset := ((FPos - FMin) / LRange) * LTrack;
    Result := TGuiRect.Create(AbsoluteLeft + LOffset, AbsoluteTop,
      AbsoluteLeft + LOffset + LSize, AbsoluteTop + Height);
  end
  else
  begin
    LSize := System.Math.Max(10.0, Height * LRatio);
    LTrack := System.Math.Max(1.0, Height - LSize);
    LOffset := ((FPos - FMin) / LRange) * LTrack;
    Result := TGuiRect.Create(AbsoluteLeft, AbsoluteTop + LOffset,
      AbsoluteLeft + Width, AbsoluteTop + LOffset + LSize);
  end;
end;

function TGuiScrollbar.MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer): Boolean;
begin
  if FScrolling then
  begin
    InternalMouseMove(Shift, X, Y);
    Exit(True);
  end;
  Result := inherited;
end;

function TGuiScrollbar.MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer): Boolean;
begin
  if FScrolling then
  begin
    InternalMouseUp(Shift, Button, X, Y);
    Exit(True);
  end;
  Result := inherited;
end;

procedure TGuiScrollbar.PageDown;
begin
  Pos := FPos + FPageSize;
end;

procedure TGuiScrollbar.PageUp;
begin
  Pos := FPos - FPageSize;
end;

procedure TGuiScrollbar.Render(ARenderer: TGuiRenderer; AViewportWidth, AViewportHeight: Integer);
var
  LIndex: Integer;
  LKnob: TGuiRect;
begin
  if not RecursiveVisible then
    Exit;
  RenderSkin(ARenderer, ComponentName, AbsoluteLeft, AbsoluteTop, Width, Height,
    AViewportWidth, AViewportHeight);
  LKnob := KnobRect;
  RenderSkin(ARenderer, FKnobLayoutName, LKnob.X1, LKnob.Y1, LKnob.Width, LKnob.Height,
    AViewportWidth, AViewportHeight);
  for LIndex := 0 to ChildCount - 1 do
    Children[LIndex].Render(ARenderer, AViewportWidth, AViewportHeight);
end;

procedure TGuiScrollbar.SetHorizontal(const Value: Boolean);
begin
  FHorizontal := Value;
end;

procedure TGuiScrollbar.SetKnobLayoutName(const Value: string);
begin
  FKnobLayoutName := Value;
end;

procedure TGuiScrollbar.SetMax(const Value: Single);
begin
  FMax := Value;
  if FMax < FMin then
    FMax := FMin;
  SetPos(FPos);
end;

procedure TGuiScrollbar.SetMin(const Value: Single);
begin
  FMin := Value;
  if FMax < FMin then
    FMax := FMin;
  SetPos(FPos);
end;

procedure TGuiScrollbar.SetPageSize(const Value: Single);
begin
  FPageSize := System.Math.Max(0.0, Value);
end;

procedure TGuiScrollbar.SetPos(const Value: Single);
var
  LNewPos: Single;
begin
  LNewPos := System.Math.EnsureRange(Value, FMin, FMax);
  if SameValue(FPos, LNewPos) then
    Exit;
  FPos := LNewPos;
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TGuiScrollbar.StepDown;
begin
  Pos := FPos + FStep;
end;

procedure TGuiScrollbar.StepUp;
begin
  Pos := FPos - FStep;
end;

{ TGuiPopupMenu }

constructor TGuiPopupMenu.Create(AOwner: TComponent);
begin
  inherited;
  FMenuItems := TStringList.Create;
  FMenuItems.OnChange := MenuItemsChanged;
  FMarginSize := 4;
  FSelIndex := -1;
  Visible := False;
end;

destructor TGuiPopupMenu.Destroy;
begin
  FMenuItems.Free;
  inherited;
end;

procedure TGuiPopupMenu.InternalMouseDown(Shift: TShiftState; Button: TMouseButton; X, Y: Integer);
begin
  inherited;
  if (Button = mbLeft) and (FSelIndex >= 0) and (FSelIndex < FMenuItems.Count) then
  begin
    if Assigned(FOnClick) then
      FOnClick(Self, FSelIndex, FMenuItems[FSelIndex]);
    Visible := False;
  end;
end;

function TGuiPopupMenu.GetMenuItems: TStrings;
begin
  Result := FMenuItems;
end;

procedure TGuiPopupMenu.InternalMouseMove(Shift: TShiftState; X, Y: Integer);
var
  LIndex: Integer;
begin
  inherited;
  LIndex := Trunc((Y - AbsoluteTop - FMarginSize) / System.Math.Max(1, MeasureTextHeight));
  if (LIndex < 0) or (LIndex >= FMenuItems.Count) then
    LIndex := -1;
  SelIndex := LIndex;
end;

procedure TGuiPopupMenu.MenuItemsChanged(Sender: TObject);
begin
  Height := (FMenuItems.Count * MeasureTextHeight) + (FMarginSize * 2);
  DeleteTextTexture;
end;

function TGuiPopupMenu.MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer): Boolean;
begin
  Result := inherited;
  if not Result then
    Visible := False;
end;

procedure TGuiPopupMenu.Popup(PX, PY: Integer);
begin
  Left := PX;
  Top := PY;
  Width := System.Math.Max(Width, 80);
  Height := (FMenuItems.Count * MeasureTextHeight) + (FMarginSize * 2);
  Visible := True;
  SetFocus;
end;

procedure TGuiPopupMenu.Render(ARenderer: TGuiRenderer; AViewportWidth, AViewportHeight: Integer);
var
  LIndex: Integer;
  LY: Single;
  LColor: TColor;
begin
  if not RecursiveVisible then
    Exit;
  RenderSkin(ARenderer, ComponentName, AbsoluteLeft, AbsoluteTop, Width, Height,
    AViewportWidth, AViewportHeight);
  LY := AbsoluteTop + FMarginSize;
  for LIndex := 0 to FMenuItems.Count - 1 do
  begin
    if LIndex = FSelIndex then
      LColor := FocusedColor
    else
      LColor := DefaultColor;
    RenderText(ARenderer, FMenuItems[LIndex], AbsoluteLeft + FMarginSize, LY,
      AbsoluteLeft + Width - FMarginSize, LY + MeasureTextHeight,
      AViewportWidth, AViewportHeight, taLeftJustify, tlCenter, LColor);
    LY := LY + MeasureTextHeight;
  end;
end;

procedure TGuiPopupMenu.SetFocused(Value: Boolean);
begin
  inherited;
  if not Value then
    Visible := False;
end;

procedure TGuiPopupMenu.SetMarginSize(const Value: Single);
begin
  FMarginSize := System.Math.Max(0.0, Value);
  MenuItemsChanged(Self);
end;

procedure TGuiPopupMenu.SetMenuItems(const Value: TStrings);
begin
  FMenuItems.Assign(Value);
end;

procedure TGuiPopupMenu.SetSelIndex(const Value: Integer);
begin
  FSelIndex := System.Math.EnsureRange(Value, -1, FMenuItems.Count - 1);
end;

{ TGuiStringGrid }

constructor TGuiStringGrid.Create(AOwner: TComponent);
begin
  inherited;
  FColumns := TStringList.Create;
  FRows := TObjectList<TStringList>.Create(True);
  FColumnSize := 96;
  FRowHeight := 22;
  FMarginSize := 4;
  FDrawHeader := True;
  FHeaderColor := clSilver;
  FSelCol := -1;
  FSelRow := -1;
end;

destructor TGuiStringGrid.Destroy;
begin
  FRows.Free;
  FColumns.Free;
  inherited;
end;

function TGuiStringGrid.Add(const Data: array of string): Integer;
var
  LIndex: Integer;
  LRow: TStringList;
begin
  LRow := TStringList.Create;
  for LIndex := Low(Data) to High(Data) do
    LRow.Add(Data[LIndex]);
  Result := FRows.Add(LRow);
end;

function TGuiStringGrid.Add(const Data: string): Integer;
var
  LRow: TStringList;
begin
  LRow := TStringList.Create;
  LRow.Delimiter := #9;
  LRow.StrictDelimiter := True;
  LRow.DelimitedText := Data;
  Result := FRows.Add(LRow);
end;

procedure TGuiStringGrid.Clear;
begin
  FRows.Clear;
  FSelCol := -1;
  FSelRow := -1;
end;

function TGuiStringGrid.GetColumns: TStrings;
begin
  Result := FColumns;
end;

function TGuiStringGrid.GetRow(Index: Integer): TStringList;
begin
  Result := FRows[Index];
end;

function TGuiStringGrid.GetRowCount: Integer;
begin
  Result := FRows.Count;
end;

procedure TGuiStringGrid.InternalMouseDown(Shift: TShiftState; Button: TMouseButton; X, Y: Integer);
var
  LLocalX: Integer;
  LLocalY: Integer;
  LHeaderOffset: Integer;
begin
  inherited;
  if Button <> mbLeft then
    Exit;
  LLocalX := X - Round(AbsoluteLeft) - FMarginSize;
  LLocalY := Y - Round(AbsoluteTop) - FMarginSize;
  LHeaderOffset := 0;
  if FDrawHeader then
    LHeaderOffset := FRowHeight;
  FSelCol := LLocalX div System.Math.Max(1, FColumnSize);
  FSelRow := (LLocalY - LHeaderOffset) div System.Math.Max(1, FRowHeight);
  if (FSelRow < 0) or (FSelRow >= FRows.Count) then
    FSelRow := -1;
end;

procedure TGuiStringGrid.Render(ARenderer: TGuiRenderer; AViewportWidth, AViewportHeight: Integer);
var
  LCol: Integer;
  LRowIndex: Integer;
  LX: Single;
  LY: Single;
  LText: string;
begin
  if not RecursiveVisible then
    Exit;
  RenderSkin(ARenderer, ComponentName, AbsoluteLeft, AbsoluteTop, Width, Height,
    AViewportWidth, AViewportHeight);

  LY := AbsoluteTop + FMarginSize;
  if FDrawHeader then
  begin
    LX := AbsoluteLeft + FMarginSize;
    for LCol := 0 to FColumns.Count - 1 do
    begin
      RenderText(ARenderer, FColumns[LCol], LX, LY, LX + FColumnSize, LY + FRowHeight,
        AViewportWidth, AViewportHeight, taLeftJustify, tlCenter, FHeaderColor);
      LX := LX + FColumnSize;
    end;
    LY := LY + FRowHeight;
  end;

  for LRowIndex := 0 to FRows.Count - 1 do
  begin
    LX := AbsoluteLeft + FMarginSize;
    for LCol := 0 to FRows[LRowIndex].Count - 1 do
    begin
      LText := FRows[LRowIndex][LCol];
      RenderText(ARenderer, LText, LX, LY, LX + FColumnSize, LY + FRowHeight,
        AViewportWidth, AViewportHeight, taLeftJustify, tlCenter, DefaultColor);
      LX := LX + FColumnSize;
    end;
    LY := LY + FRowHeight;
    if LY > AbsoluteTop + Height then
      Break;
  end;
end;

procedure TGuiStringGrid.SetColumns(const Value: TStrings);
begin
  FColumns.Assign(Value);
end;

procedure TGuiStringGrid.SetRowCount(const Value: Integer);
begin
  while FRows.Count < Value do
    FRows.Add(TStringList.Create);
  while FRows.Count > Value do
    FRows.Delete(FRows.Count - 1);
end;

procedure TGuiStringGrid.SetText(const Data: string);
var
  LLines: TStringList;
  LIndex: Integer;
begin
  Clear;
  LLines := TStringList.Create;
  try
    LLines.Text := Data;
    for LIndex := 0 to LLines.Count - 1 do
      Add(LLines[LIndex]);
  finally
    LLines.Free;
  end;
end;

initialization
  RegisterClasses([TGuiBaseControl, TGuiPanel, TGuiButton, TGuiCheckBox, TGuiEdit,
    TGuiLabel, TGuiAdvancedLabel, TGuiForm, TGuiScrollbar, TGuiPopupMenu,
    TGuiStringGrid]);

end.
