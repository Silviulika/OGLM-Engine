unit Engine.Gui.Controls;

interface

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.Math, System.Generics.Collections,
  Vcl.Controls, Vcl.Graphics, Vcl.StdCtrls,
  dglOpenGL, Neslib.FastMath,
  Engine.Paths, Engine.Gui, Engine.Gui.BitmapFont;

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
  TGuiProgressShape = (gpsCircle, gpsTriangle);
  TGuiWindowState = (gwsNormal, gwsMinimized, gwsMaximized);
  TGuiTitleButton = (gtbNone, gtbMinimize, gtbMaximize, gtbClose);

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
    procedure BeginRenderTransform(ARenderer: TGuiRenderer);
    procedure EndRenderTransform(ARenderer: TGuiRenderer);
    procedure RenderSkin(ARenderer: TGuiRenderer; const ASkinName: string;
      AX, AY, AWidth, AHeight: Single; AViewportWidth, AViewportHeight: Integer); virtual;
    procedure RenderSkinClipped(ARenderer: TGuiRenderer;
      const ASkinName: string; AX, AY, AWidth, AHeight: Single;
      const AClipRect: TGuiRect; AViewportWidth, AViewportHeight: Integer);
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
    procedure RemoveControlReference(AControl: TGuiBaseControl);
    procedure SetActiveControl(const Value: TGuiBaseControl);
    procedure SetFocusedControl(const Value: TGuiFocusControl);
  protected
    function AcceptMouse(Shift: TShiftState; Action: TGuiMouseAction;
      Button: TMouseButton; X, Y: Integer): Boolean; virtual;
    procedure DoMouseEnter; virtual;
    procedure DoMouseLeave; virtual;
    function FindRootControl: TGuiBaseControl;
    function ScreenToUnrotated(AX, AY: Single): TVector2;
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
    function ContainsPoint(X, Y: Single): Boolean; virtual;
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
    FMouseOver: Boolean;
    FOnKeyDown: TKeyEvent;
    FOnKeyPress: TKeyPressEvent;
    FOnKeyUp: TKeyEvent;
    procedure SetFocusedColor(const Value: TColor);
  protected
    procedure DoMouseEnter; override;
    procedure DoMouseLeave; override;
    procedure InternalKeyDown(var Key: Word; Shift: TShiftState); virtual;
    procedure InternalKeyPress(var Key: Char); virtual;
    procedure InternalKeyUp(var Key: Word; Shift: TShiftState); virtual;
    procedure SetFocused(Value: Boolean); virtual;
  public
    procedure KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState); override;
    procedure KeyPress(Sender: TObject; var Key: Char); override;
    procedure KeyUp(Sender: TObject; var Key: Word; Shift: TShiftState); override;
    function RootControl: TGuiBaseControl;
    function Highlighted: Boolean;
    procedure SetFocus;
    procedure NextControl;
    procedure PrevControl;
  published
    property Focused: Boolean read FFocused write SetFocused;
    property FocusedColor: TColor read FFocusedColor write SetFocusedColor;
    property Hovered: Boolean read FMouseOver;
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
    function MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer): Boolean; override;
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
    FButtonSize: Single;
    FCloseButtonLayoutName: string;
    FHasRestoreBounds: Boolean;
    FHotTitleButton: TGuiTitleButton;
    FMaximizeButtonLayoutName: string;
    FMinimizeButtonLayoutName: string;
    FMoving: Boolean;
    FOldX: Integer;
    FOldY: Integer;
    FOnCanClose: TGuiFormCanClose;
    FOnCanMove: TGuiFormCanRequest;
    FOnCanResize: TGuiFormCanRequest;
    FOnHide: TGuiFormNotify;
    FOnMaximize: TGuiFormNotify;
    FOnMinimize: TGuiFormNotify;
    FOnMoving: TGuiFormMove;
    FOnRestore: TGuiFormNotify;
    FOnShow: TGuiFormNotify;
    FPressedTitleButton: TGuiTitleButton;
    FRestoreButtonLayoutName: string;
    FRestoreHeight: Single;
    FRestoreLeft: Single;
    FRestoreTop: Single;
    FRestoreWidth: Single;
    FShowCloseButton: Boolean;
    FShowMaximizeButton: Boolean;
    FShowMinimizeButton: Boolean;
    FTitleBarHeight: Single;
    FTitleColor: TColor;
    FTitleOffset: Single;
    FWindowState: TGuiWindowState;
    function ButtonLayoutName(AButton: TGuiTitleButton): string;
    function FirstTitleButtonLeft: Single;
    function TitleButtonAt(X, Y: Single): TGuiTitleButton;
    function TitleButtonRect(AButton: TGuiTitleButton): TGuiRect;
    procedure RenderTitleButton(ARenderer: TGuiRenderer;
      AButton: TGuiTitleButton; AViewportWidth, AViewportHeight: Integer);
    procedure SaveRestoreBounds;
    procedure SetButtonSize(const Value: Single);
    procedure SetTitleColor(const Value: TColor);
    procedure SetTitleBarHeight(const Value: Single);
    procedure SetWindowState(const Value: TGuiWindowState);
  protected
    procedure DoMouseLeave; override;
    procedure InternalMouseDown(Shift: TShiftState; Button: TMouseButton; X, Y: Integer); override;
    procedure InternalMouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure InternalMouseUp(Shift: TShiftState; Button: TMouseButton; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Close;
    procedure GetRestoreBounds(out ALeft, ATop, AWidth, AHeight: Single);
    procedure Maximize;
    procedure Minimize;
    procedure NotifyHide; virtual;
    procedure NotifyShow; virtual;
    procedure RefreshWindowStateBounds;
    function MouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer): Boolean; override;
    function MouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer): Boolean; override;
    procedure Render(ARenderer: TGuiRenderer; AViewportWidth, AViewportHeight: Integer); override;
    procedure Restore;
    procedure SetRestoreBounds(ALeft, ATop, AWidth, AHeight: Single);
    procedure ToggleMaximize;
  published
    property ButtonSize: Single read FButtonSize write SetButtonSize;
    property CloseButtonLayoutName: string read FCloseButtonLayoutName
      write FCloseButtonLayoutName;
    property MaximizeButtonLayoutName: string read FMaximizeButtonLayoutName
      write FMaximizeButtonLayoutName;
    property MinimizeButtonLayoutName: string read FMinimizeButtonLayoutName
      write FMinimizeButtonLayoutName;
    property OnCanClose: TGuiFormCanClose read FOnCanClose write FOnCanClose;
    property OnCanMove: TGuiFormCanRequest read FOnCanMove write FOnCanMove;
    property OnCanResize: TGuiFormCanRequest read FOnCanResize write FOnCanResize;
    property OnHide: TGuiFormNotify read FOnHide write FOnHide;
    property OnMaximize: TGuiFormNotify read FOnMaximize write FOnMaximize;
    property OnMinimize: TGuiFormNotify read FOnMinimize write FOnMinimize;
    property OnMoving: TGuiFormMove read FOnMoving write FOnMoving;
    property OnRestore: TGuiFormNotify read FOnRestore write FOnRestore;
    property OnShow: TGuiFormNotify read FOnShow write FOnShow;
    property RestoreButtonLayoutName: string read FRestoreButtonLayoutName
      write FRestoreButtonLayoutName;
    property ShowCloseButton: Boolean read FShowCloseButton
      write FShowCloseButton;
    property ShowMaximizeButton: Boolean read FShowMaximizeButton
      write FShowMaximizeButton;
    property ShowMinimizeButton: Boolean read FShowMinimizeButton
      write FShowMinimizeButton;
    property TitleBarHeight: Single read FTitleBarHeight
      write SetTitleBarHeight;
    property TitleColor: TColor read FTitleColor write SetTitleColor;
    property TitleOffset: Single read FTitleOffset write FTitleOffset;
    property WindowState: TGuiWindowState read FWindowState
      write SetWindowState;
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

  TGuiProgressBar = class(TGuiBaseTextControl)
  protected
    FFillColor: TColor;
    FFillLayoutName: string;
    FHorizontal: Boolean;
    FMax: Single;
    FMin: Single;
    FOnChange: TNotifyEvent;
    FReverse: Boolean;
    FShowText: Boolean;
    FTrackColor: TColor;
    FValue: Single;
    function ProgressRatio: Single;
    function ProgressText: string;
    procedure SetMax(const Value: Single);
    procedure SetMin(const Value: Single);
    procedure SetValue(const Value: Single);
  public
    constructor Create(AOwner: TComponent); override;
    procedure Render(ARenderer: TGuiRenderer; AViewportWidth,
      AViewportHeight: Integer); override;
  published
    property FillColor: TColor read FFillColor write FFillColor;
    property FillLayoutName: string read FFillLayoutName write FFillLayoutName;
    property Horizontal: Boolean read FHorizontal write FHorizontal;
    property Max: Single read FMax write SetMax;
    property Min: Single read FMin write SetMin;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property Position: Single read FValue write SetValue;
    property Reverse: Boolean read FReverse write FReverse;
    property ShowText: Boolean read FShowText write FShowText;
    property TrackColor: TColor read FTrackColor write FTrackColor;
    property Value: Single read FValue write SetValue;
  end;

  TGuiShapeProgress = class(TGuiProgressBar)
  private
    FInnerRadius: Single;
    FSegments: Integer;
    FShape: TGuiProgressShape;
    FStartAngle: Single;
    procedure SetInnerRadius(const Value: Single);
    procedure SetSegments(const Value: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    procedure Render(ARenderer: TGuiRenderer; AViewportWidth,
      AViewportHeight: Integer); override;
  published
    property InnerRadius: Single read FInnerRadius write SetInnerRadius;
    property Segments: Integer read FSegments write SetSegments;
    property Shape: TGuiProgressShape read FShape write FShape;
    property StartAngle: Single read FStartAngle write FStartAngle;
  end;

  TGuiAnimatedProgress = class(TGuiProgressBar)
  private
    FAtlasDirty: Boolean;
    FAtlasTexture: TGuiTexture;
    FAtlasTexturePath: string;
    FCurrentFrameIndex: Integer;
    FFirstFrame: Integer;
    FFrameCount: Integer;
    FFrameRate: Single;
    FFrameTimer: Single;
    FGridColumns: Integer;
    FGridRows: Integer;
    FLastTick: UInt64;
    FLoop: Boolean;
    FOverlayLayoutName: string;
    FPlaying: Boolean;
    procedure EnsureAtlasTexture;
    function GetCurrentSheetFrameIndex: Integer;
    function GetGridFrameCapacity: Integer;
    procedure NormalizeFrameRange;
    procedure RenderAtlasFrame(ARenderer: TGuiRenderer;
      const AClipRect: TGuiRect; AViewportWidth, AViewportHeight: Integer);
    procedure SetAtlasTexturePath(const Value: string);
    procedure SetCurrentFrameIndex(const Value: Integer);
    procedure SetFirstFrame(const Value: Integer);
    procedure SetFrameCount(const Value: Integer);
    procedure SetFrameRate(const Value: Single);
    procedure SetGridColumns(const Value: Integer);
    procedure SetGridRows(const Value: Integer);
    procedure SetPlaying(const Value: Boolean);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function LoadAtlas(const APath: string): Boolean;
    procedure RestartAnimation;
    procedure Render(ARenderer: TGuiRenderer; AViewportWidth,
      AViewportHeight: Integer); override;
    procedure UpdateAnimation(DeltaTime: Single);
    property CurrentSheetFrameIndex: Integer
      read GetCurrentSheetFrameIndex;
    property GridFrameCapacity: Integer read GetGridFrameCapacity;
  published
    property AtlasTexturePath: string read FAtlasTexturePath
      write SetAtlasTexturePath;
    property CurrentFrameIndex: Integer read FCurrentFrameIndex
      write SetCurrentFrameIndex;
    property FirstFrame: Integer read FFirstFrame write SetFirstFrame;
    property FrameCount: Integer read FFrameCount write SetFrameCount;
    property FrameRate: Single read FFrameRate write SetFrameRate;
    property GridColumns: Integer read FGridColumns write SetGridColumns;
    property GridRows: Integer read FGridRows write SetGridRows;
    property Loop: Boolean read FLoop write FLoop;
    property OverlayLayoutName: string read FOverlayLayoutName
      write FOverlayLayoutName;
    property Playing: Boolean read FPlaying write SetPlaying;
  end;

  TGuiSpinner = class(TGuiBaseComponent)
  private
    FAngle: Single;
    FAutoSpin: Boolean;
    FColor: TColor;
    FLastTick: UInt64;
    FSegments: Integer;
    FSpeed: Single;
    FThickness: Single;
    FTrackColor: TColor;
    procedure SetSegments(const Value: Integer);
    procedure SetThickness(const Value: Single);
  public
    constructor Create(AOwner: TComponent); override;
    procedure Render(ARenderer: TGuiRenderer; AViewportWidth,
      AViewportHeight: Integer); override;
  published
    property Angle: Single read FAngle write FAngle;
    property AutoSpin: Boolean read FAutoSpin write FAutoSpin;
    property Color: TColor read FColor write FColor;
    property Segments: Integer read FSegments write SetSegments;
    property Speed: Single read FSpeed write FSpeed;
    property Thickness: Single read FThickness write SetThickness;
    property TrackColor: TColor read FTrackColor write FTrackColor;
  end;

  TGuiListBox = class(TGuiFocusControl)
  protected
    FHoverIndex: Integer;
    FItemHeight: Single;
    FItems: TStringList;
    FMarginSize: Single;
    FOnChange: TNotifyEvent;
    FSelectedIndex: Integer;
    FSelectionColor: TColor;
    FTopIndex: Integer;
    function GetItems: TStrings;
    function ItemsTop: Single; virtual;
    function ItemIndexAt(Y, AListTop: Single): Integer;
    procedure ItemsChanged(Sender: TObject);
    procedure SetItemHeight(const Value: Single);
    procedure SetItems(const Value: TStrings);
    procedure SetSelectedIndex(const Value: Integer);
    procedure SetTopIndex(const Value: Integer);
    procedure DoMouseLeave; override;
    procedure InternalMouseDown(Shift: TShiftState; Button: TMouseButton;
      X, Y: Integer); override;
    procedure InternalMouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure RenderItems(ARenderer: TGuiRenderer; ATop, AHeight: Single;
      AViewportWidth, AViewportHeight: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function AddItem(const AText: string): Integer;
    procedure Clear;
    procedure DeleteItem(AIndex: Integer);
    function Item(AIndex: Integer): string;
    function ItemCount: Integer;
    procedure Render(ARenderer: TGuiRenderer; AViewportWidth,
      AViewportHeight: Integer); override;
  published
    property ItemHeight: Single read FItemHeight write SetItemHeight;
    property Items: TStrings read GetItems write SetItems;
    property MarginSize: Single read FMarginSize write FMarginSize;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property SelectedIndex: Integer read FSelectedIndex write SetSelectedIndex;
    property SelectionColor: TColor read FSelectionColor write FSelectionColor;
    property TopIndex: Integer read FTopIndex write SetTopIndex;
  end;

  TGuiComboBox = class(TGuiListBox)
  private
    FArrowLayoutName: string;
    FDropDownCount: Integer;
    FDropDownLayoutName: string;
    FDroppedDown: Boolean;
    function DropDownHeight: Single;
    procedure SetDropDownCount(const Value: Integer);
    procedure SetDroppedDown(const Value: Boolean);
  protected
    function ItemsTop: Single; override;
    procedure InternalMouseDown(Shift: TShiftState; Button: TMouseButton;
      X, Y: Integer); override;
    procedure InternalMouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure SetFocused(Value: Boolean); override;
  public
    constructor Create(AOwner: TComponent); override;
    function ContainsPoint(X, Y: Single): Boolean; override;
    procedure Render(ARenderer: TGuiRenderer; AViewportWidth,
      AViewportHeight: Integer); override;
  published
    property ArrowLayoutName: string read FArrowLayoutName write FArrowLayoutName;
    property DropDownCount: Integer read FDropDownCount write SetDropDownCount;
    property DropDownLayoutName: string read FDropDownLayoutName
      write FDropDownLayoutName;
    property DroppedDown: Boolean read FDroppedDown write SetDroppedDown;
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

procedure AppendGuiVertex(var AVertices: TArray<TGuiVertex>;
  const AVertex: TGuiVertex);
var
  LIndex: Integer;
begin
  LIndex := Length(AVertices);
  SetLength(AVertices, LIndex + 1);
  AVertices[LIndex] := AVertex;
end;

function InterpolateGuiVertex(const A, B: TGuiVertex;
  AAmount: Single): TGuiVertex;
begin
  Result.Position := A.Position + ((B.Position - A.Position) * AAmount);
  Result.TexCoord := A.TexCoord + ((B.TexCoord - A.TexCoord) * AAmount);
end;

procedure ClipGuiPolygon(var AVertices: TArray<TGuiVertex>;
  AAxis, ABoundary: Single; AKeepGreater: Boolean);
var
  LInput: TArray<TGuiVertex>;
  LPrevious: TGuiVertex;
  LCurrent: TGuiVertex;
  LPreviousValue: Single;
  LCurrentValue: Single;
  LPreviousInside: Boolean;
  LCurrentInside: Boolean;
  LAmount: Single;
  LIndex: Integer;

  function AxisValue(const AVertex: TGuiVertex): Single;
  begin
    if AAxis = 0.0 then
      Result := AVertex.Position.X
    else
      Result := AVertex.Position.Y;
  end;

  function Inside(AValue: Single): Boolean;
  begin
    if AKeepGreater then
      Result := AValue >= ABoundary
    else
      Result := AValue <= ABoundary;
  end;

begin
  if Length(AVertices) = 0 then
    Exit;

  LInput := AVertices;
  SetLength(AVertices, 0);
  LPrevious := LInput[High(LInput)];
  LPreviousValue := AxisValue(LPrevious);
  LPreviousInside := Inside(LPreviousValue);

  for LIndex := 0 to High(LInput) do
  begin
    LCurrent := LInput[LIndex];
    LCurrentValue := AxisValue(LCurrent);
    LCurrentInside := Inside(LCurrentValue);

    if LCurrentInside <> LPreviousInside then
    begin
      if SameValue(LCurrentValue, LPreviousValue) then
        LAmount := 0.0
      else
        LAmount := (ABoundary - LPreviousValue) /
          (LCurrentValue - LPreviousValue);
      AppendGuiVertex(AVertices,
        InterpolateGuiVertex(LPrevious, LCurrent, LAmount));
    end;
    if LCurrentInside then
      AppendGuiVertex(AVertices, LCurrent);

    LPrevious := LCurrent;
    LPreviousValue := LCurrentValue;
    LPreviousInside := LCurrentInside;
  end;
end;

procedure RenderComponentClipped(ARenderer: TGuiRenderer;
  AComponent: TGuiComponent; ATexture: TGuiTexture; AX, AY, AWidth,
  AHeight: Single; const AClipRect: TGuiRect; AViewportWidth,
  AViewportHeight: Integer; const ATint: TVector4; AScale: Single);
var
  LSource: TArray<TGuiVertex>;
  LClipped: TArray<TGuiVertex>;
  LPolygon: TArray<TGuiVertex>;
  LTextureSize: TVector2;
  LIndex: Integer;
  LVertex: Integer;
begin
  if (ARenderer = nil) or (AComponent = nil) or (ATexture = nil) or
     (ATexture.TextureID = 0) or (AWidth <= 0.0) or (AHeight <= 0.0) or
     AClipRect.IsEmpty then
    Exit;

  LTextureSize := Vector2(ATexture.Width, ATexture.Height);
  AComponent.BuildVertices(AX, AY, AX + AWidth, AY + AHeight,
    LTextureSize, LSource, AScale);
  SetLength(LClipped, 0);
  LIndex := 0;
  while LIndex + 2 <= High(LSource) do
  begin
    SetLength(LPolygon, 3);
    LPolygon[0] := LSource[LIndex];
    LPolygon[1] := LSource[LIndex + 1];
    LPolygon[2] := LSource[LIndex + 2];
    ClipGuiPolygon(LPolygon, 0.0, AClipRect.X1, True);
    ClipGuiPolygon(LPolygon, 0.0, AClipRect.X2, False);
    ClipGuiPolygon(LPolygon, 1.0, AClipRect.Y1, True);
    ClipGuiPolygon(LPolygon, 1.0, AClipRect.Y2, False);

    for LVertex := 1 to Length(LPolygon) - 2 do
    begin
      AppendGuiVertex(LClipped, LPolygon[0]);
      AppendGuiVertex(LClipped, LPolygon[LVertex]);
      AppendGuiVertex(LClipped, LPolygon[LVertex + 1]);
    end;
    Inc(LIndex, 3);
  end;

  ARenderer.RenderVertices(LClipped, ATexture.TextureID, AViewportWidth,
    AViewportHeight, ATint);
end;

procedure SetSolidVertex(var AVertex: TGuiVertex; AX, AY: Single); forward;

procedure RenderGuiLine(ARenderer: TGuiRenderer; AX1, AY1, AX2, AY2,
  AThickness: Single; AViewportWidth, AViewportHeight: Integer;
  const AColor: TVector4);
var
  LDX: Single;
  LDY: Single;
  LLength: Single;
  LNX: Single;
  LNY: Single;
  LVertices: TArray<TGuiVertex>;
begin
  LDX := AX2 - AX1;
  LDY := AY2 - AY1;
  LLength := Sqrt((LDX * LDX) + (LDY * LDY));
  if (ARenderer = nil) or (LLength <= 0.0001) or (AThickness <= 0.0) then
    Exit;

  LNX := (-LDY / LLength) * AThickness * 0.5;
  LNY := (LDX / LLength) * AThickness * 0.5;
  SetLength(LVertices, 6);
  SetSolidVertex(LVertices[0], AX1 + LNX, AY1 + LNY);
  SetSolidVertex(LVertices[1], AX1 - LNX, AY1 - LNY);
  SetSolidVertex(LVertices[2], AX2 - LNX, AY2 - LNY);
  SetSolidVertex(LVertices[3], AX1 + LNX, AY1 + LNY);
  SetSolidVertex(LVertices[4], AX2 - LNX, AY2 - LNY);
  SetSolidVertex(LVertices[5], AX2 + LNX, AY2 + LNY);
  ARenderer.RenderSolidVertices(LVertices, AViewportWidth, AViewportHeight,
    AColor);
end;

function PointInRectF(AX, AY: Single; const ARect: TGuiRect): Boolean;
begin
  Result := (AX >= ARect.X1) and (AX <= ARect.X2) and
    (AY >= ARect.Y1) and (AY <= ARect.Y2);
end;

procedure SetSolidVertex(var AVertex: TGuiVertex; AX, AY: Single);
begin
  AVertex.Position := Vector2(AX, AY);
  AVertex.TexCoord := Vector2(0.5, 0.5);
end;

procedure RenderRingSector(ARenderer: TGuiRenderer; ACX, ACY, AOuterRadius,
  AInnerRadius, AStartAngle, ASweepAngle: Single; ASegments: Integer;
  AViewportWidth, AViewportHeight: Integer; const AColor: TVector4);
var
  LVertices: TArray<TGuiVertex>;
  LSegmentCount: Integer;
  LIndex: Integer;
  LVertex: Integer;
  LAngle1: Single;
  LAngle2: Single;
  LStep: Single;
  LSin1: Single;
  LCos1: Single;
  LSin2: Single;
  LCos2: Single;
begin
  if (ARenderer = nil) or (AOuterRadius <= 0.0) or
     System.Math.SameValue(ASweepAngle, 0.0) then
    Exit;

  LSegmentCount := System.Math.EnsureRange(Integer(System.Math.Ceil(
    System.Abs(ASweepAngle) / 360.0 *
    System.Math.Max(3, ASegments))), 1, System.Math.Max(3, ASegments));
  LStep := System.Math.DegToRad(ASweepAngle / LSegmentCount);
  LAngle1 := System.Math.DegToRad(AStartAngle);
  SetLength(LVertices, LSegmentCount * 6);
  LVertex := 0;
  for LIndex := 0 to LSegmentCount - 1 do
  begin
    LAngle2 := LAngle1 + LStep;
    System.Math.SinCos(LAngle1, LSin1, LCos1);
    System.Math.SinCos(LAngle2, LSin2, LCos2);

    SetSolidVertex(LVertices[LVertex], ACX + (LCos1 * AInnerRadius),
      ACY + (LSin1 * AInnerRadius));
    SetSolidVertex(LVertices[LVertex + 1], ACX + (LCos1 * AOuterRadius),
      ACY + (LSin1 * AOuterRadius));
    SetSolidVertex(LVertices[LVertex + 2], ACX + (LCos2 * AOuterRadius),
      ACY + (LSin2 * AOuterRadius));
    SetSolidVertex(LVertices[LVertex + 3], ACX + (LCos1 * AInnerRadius),
      ACY + (LSin1 * AInnerRadius));
    SetSolidVertex(LVertices[LVertex + 4], ACX + (LCos2 * AOuterRadius),
      ACY + (LSin2 * AOuterRadius));
    SetSolidVertex(LVertices[LVertex + 5], ACX + (LCos2 * AInnerRadius),
      ACY + (LSin2 * AInnerRadius));
    Inc(LVertex, 6);
    LAngle1 := LAngle2;
  end;
  ARenderer.RenderSolidVertices(LVertices, AViewportWidth, AViewportHeight,
    AColor);
end;

procedure RenderTriangle(ARenderer: TGuiRenderer; AX1, AY1, AX2, AY2,
  AX3, AY3: Single; AViewportWidth, AViewportHeight: Integer;
  const AColor: TVector4);
var
  LVertices: TArray<TGuiVertex>;
begin
  SetLength(LVertices, 3);
  SetSolidVertex(LVertices[0], AX1, AY1);
  SetSolidVertex(LVertices[1], AX2, AY2);
  SetSolidVertex(LVertices[2], AX3, AY3);
  ARenderer.RenderSolidVertices(LVertices, AViewportWidth, AViewportHeight,
    AColor);
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

procedure TGuiBaseComponent.BeginRenderTransform(ARenderer: TGuiRenderer);
begin
  if ARenderer <> nil then
    ARenderer.PushRotation(FRotation, AbsoluteLeft + (Width * 0.5),
      AbsoluteTop + (Height * 0.5));
end;

procedure TGuiBaseComponent.EndRenderTransform(ARenderer: TGuiRenderer);
begin
  if ARenderer <> nil then
    ARenderer.PopTransform;
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

procedure TGuiBaseComponent.RenderSkinClipped(ARenderer: TGuiRenderer;
  const ASkinName: string; AX, AY, AWidth, AHeight: Single;
  const AClipRect: TGuiRect; AViewportWidth, AViewportHeight: Integer);
begin
  if (ARenderer = nil) or (Layout = nil) or (ASkinName = '') then
    Exit;

  RenderComponentClipped(ARenderer, Layout.FindComponent(ASkinName),
    Layout.Texture, AX, AY, AWidth, AHeight, AClipRect, AViewportWidth,
    AViewportHeight, EffectiveTint, 1.0);
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
var
  Ancestor: TGuiControl;
begin
  Ancestor := Parent;
  while Ancestor <> nil do
  begin
    if Ancestor is TGuiBaseControl then
      TGuiBaseControl(Ancestor).RemoveControlReference(Self);
    Ancestor := Ancestor.Parent;
  end;
  if FEnteredControl <> nil then
    FEnteredControl.DoMouseLeave;
  inherited;
end;

function TGuiBaseControl.AcceptMouse(Shift: TShiftState; Action: TGuiMouseAction;
  Button: TMouseButton; X, Y: Integer): Boolean;
begin
  Result := RecursiveVisible and ContainsPoint(X, Y);
  if Assigned(FOnAcceptMouseQuery) then
    FOnAcceptMouseQuery(Self, Shift, Action, Button, X, Y, Result);
end;

function TGuiBaseControl.ContainsPoint(X, Y: Single): Boolean;
var
  LPoint: TVector2;
begin
  LPoint := ScreenToUnrotated(X, Y);
  Result := (LPoint.X >= AbsoluteLeft) and
    (LPoint.X < AbsoluteLeft + Width) and
    (LPoint.Y >= AbsoluteTop) and
    (LPoint.Y < AbsoluteTop + Height);
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

function TGuiBaseControl.ScreenToUnrotated(AX, AY: Single): TVector2;
var
  LParentPoint: TVector2;
  LRadians: Single;
  LSin: Single;
  LCos: Single;
  LCX: Single;
  LCY: Single;
  LDX: Single;
  LDY: Single;
begin
  if Parent is TGuiBaseControl then
    LParentPoint := TGuiBaseControl(Parent).ScreenToUnrotated(AX, AY)
  else
    LParentPoint := Vector2(AX, AY);

  if System.Math.SameValue(Rotation, 0.0) then
    Exit(LParentPoint);

  LRadians := System.Math.DegToRad(-Rotation);
  System.Math.SinCos(LRadians, LSin, LCos);
  LCX := AbsoluteLeft + (Width * 0.5);
  LCY := AbsoluteTop + (Height * 0.5);
  LDX := LParentPoint.X - LCX;
  LDY := LParentPoint.Y - LCY;
  Result.X := LCX + (LCos * LDX) - (LSin * LDY);
  Result.Y := LCY + (LSin * LDX) + (LCos * LDY);
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
  LPoint: TVector2;
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

  LPoint := ScreenToUnrotated(X, Y);
  InternalMouseDown(Shift, Button, Round(LPoint.X), Round(LPoint.Y));
end;

function TGuiBaseControl.MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer): Boolean;
var
  LIndex: Integer;
  LChild: TGuiControl;
  LHandledChild: TGuiBaseControl;
  LPoint: TVector2;
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
  LPoint := ScreenToUnrotated(X, Y);
  InternalMouseMove(Shift, Round(LPoint.X), Round(LPoint.Y));
end;

function TGuiBaseControl.MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer): Boolean;
var
  LIndex: Integer;
  LChild: TGuiControl;
  LPoint: TVector2;
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

  LPoint := ScreenToUnrotated(X, Y);
  InternalMouseUp(Shift, Button, Round(LPoint.X), Round(LPoint.Y));
end;

procedure TGuiBaseControl.SetActiveControl(const Value: TGuiBaseControl);
begin
  FActiveControl := Value;
end;

procedure TGuiBaseControl.RemoveControlReference(AControl: TGuiBaseControl);
begin
  if FActiveControl = AControl then
    FActiveControl := nil;
  if FEnteredControl = AControl then
    FEnteredControl := nil;
  if FFocusedControl = AControl then
    SetFocusedControl(nil);
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

procedure TGuiFocusControl.DoMouseEnter;
begin
  if not FMouseOver then
  begin
    FMouseOver := True;
    DeleteTextTexture;
  end;
  inherited;
end;

procedure TGuiFocusControl.DoMouseLeave;
begin
  if FMouseOver then
  begin
    FMouseOver := False;
    DeleteTextTexture;
  end;
  inherited;
end;

function TGuiFocusControl.Highlighted: Boolean;
begin
  Result := FFocused or FMouseOver;
end;

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
  BeginRenderTransform(ARenderer);
  RenderSkin(ARenderer, ComponentName, AbsoluteLeft, AbsoluteTop, Width, Height,
    AViewportWidth, AViewportHeight);
  for LIndex := 0 to ChildCount - 1 do
    Children[LIndex].Render(ARenderer, AViewportWidth, AViewportHeight);
  EndRenderTransform(ARenderer);
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

  BeginRenderTransform(ARenderer);
  LSkin := ComponentName;
  if FChecked and (FCheckedLayoutName <> '') then
    LSkin := FCheckedLayoutName;
  RenderSkin(ARenderer, LSkin, AbsoluteLeft, AbsoluteTop, Width, Height,
    AViewportWidth, AViewportHeight);

  for LIndex := 0 to ChildCount - 1 do
    Children[LIndex].Render(ARenderer, AViewportWidth, AViewportHeight);
  EndRenderTransform(ARenderer);
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
  SetFocus;
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
  if FindRootControl.ActiveControl = Self then
    FindRootControl.ActiveControl := nil;
  inherited;
end;

function TGuiButton.MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer): Boolean;
var
  LPoint: TVector2;
begin
  if FindRootControl.ActiveControl = Self then
  begin
    LPoint := ScreenToUnrotated(X, Y);
    InternalMouseUp(Shift, Button, Round(LPoint.X), Round(LPoint.Y));
    Exit(True);
  end;
  Result := inherited;
end;

procedure TGuiButton.Render(ARenderer: TGuiRenderer; AViewportWidth, AViewportHeight: Integer);
var
  LIndex: Integer;
  LSkin: string;
  LTextColor: TColor;
begin
  if not RecursiveVisible then
    Exit;

  BeginRenderTransform(ARenderer);
  LSkin := ComponentName;
  if FPressed and (FPressedLayoutName <> '') then
    LSkin := FPressedLayoutName;
  RenderSkin(ARenderer, LSkin, AbsoluteLeft, AbsoluteTop, Width, Height,
    AViewportWidth, AViewportHeight);

  if Highlighted then
    LTextColor := FFocusedColor
  else
    LTextColor := DefaultColor;
  RenderText(ARenderer, Caption, AbsoluteLeft + 4, AbsoluteTop,
    AbsoluteLeft + Width - 4, AbsoluteTop + Height, AViewportWidth,
    AViewportHeight, taCenter, tlCenter, LTextColor);

  for LIndex := 0 to ChildCount - 1 do
    Children[LIndex].Render(ARenderer, AViewportWidth, AViewportHeight);
  EndRenderTransform(ARenderer);
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

  BeginRenderTransform(ARenderer);
  RenderSkin(ARenderer, ComponentName, AbsoluteLeft, AbsoluteTop, Width, Height,
    AViewportWidth, AViewportHeight);

  LText := Caption;
  if FFocused then
    Insert(FEditChar, LText, FSelStart);
  LText := FitTextToWidth(LText, Width - 8);

  if Highlighted then
    LTextColor := FFocusedColor
  else
    LTextColor := DefaultColor;
  RenderText(ARenderer, LText, AbsoluteLeft + 4, AbsoluteTop, AbsoluteLeft + Width - 4,
    AbsoluteTop + Height, AViewportWidth, AViewportHeight, taLeftJustify, tlCenter, LTextColor);

  for LIndex := 0 to ChildCount - 1 do
    Children[LIndex].Render(ARenderer, AViewportWidth, AViewportHeight);
  EndRenderTransform(ARenderer);
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
  BeginRenderTransform(ARenderer);
  RenderSkin(ARenderer, ComponentName, AbsoluteLeft, AbsoluteTop, Width, Height,
    AViewportWidth, AViewportHeight);
  RenderText(ARenderer, Caption, AbsoluteLeft, AbsoluteTop, AbsoluteLeft + Width,
    AbsoluteTop + Height, AViewportWidth, AViewportHeight, FAlignment, FTextLayout, DefaultColor);
  for LIndex := 0 to ChildCount - 1 do
    Children[LIndex].Render(ARenderer, AViewportWidth, AViewportHeight);
  EndRenderTransform(ARenderer);
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
  FButtonSize := 18;
  FTitleBarHeight := 28;
  FTitleColor := clWhite;
  FTitleOffset := 6;
  FShowMinimizeButton := True;
  FShowMaximizeButton := True;
  FShowCloseButton := True;
  FWindowState := gwsNormal;
  FHotTitleButton := gtbNone;
  FPressedTitleButton := gtbNone;
end;

function TGuiForm.ButtonLayoutName(AButton: TGuiTitleButton): string;
begin
  case AButton of
    gtbMinimize:
      Result := FMinimizeButtonLayoutName;
    gtbMaximize:
      if FWindowState = gwsMaximized then
        Result := FRestoreButtonLayoutName
      else
        Result := FMaximizeButtonLayoutName;
    gtbClose:
      Result := FCloseButtonLayoutName;
  else
    Result := '';
  end;
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
        FMoving := False;
        FPressedTitleButton := gtbNone;
        NotifyHide;
      end;
    gcoDestroy:
      Free;
  end;
end;

procedure TGuiForm.DoMouseLeave;
begin
  FHotTitleButton := gtbNone;
  inherited;
end;

function TGuiForm.FirstTitleButtonLeft: Single;
var
  LRect: TGuiRect;
begin
  Result := AbsoluteLeft + Width - 8;
  if FShowCloseButton then
  begin
    LRect := TitleButtonRect(gtbClose);
    Result := System.Math.Min(Result, LRect.X1);
  end;
  if FShowMaximizeButton then
  begin
    LRect := TitleButtonRect(gtbMaximize);
    Result := System.Math.Min(Result, LRect.X1);
  end;
  if FShowMinimizeButton then
  begin
    LRect := TitleButtonRect(gtbMinimize);
    Result := System.Math.Min(Result, LRect.X1);
  end;
end;

procedure TGuiForm.GetRestoreBounds(out ALeft, ATop, AWidth,
  AHeight: Single);
begin
  if FHasRestoreBounds and (FWindowState <> gwsNormal) then
  begin
    ALeft := FRestoreLeft;
    ATop := FRestoreTop;
    AWidth := FRestoreWidth;
    AHeight := FRestoreHeight;
  end
  else
  begin
    ALeft := Left;
    ATop := Top;
    AWidth := Width;
    AHeight := Height;
  end;
end;

procedure TGuiForm.InternalMouseDown(Shift: TShiftState; Button: TMouseButton; X, Y: Integer);
var
  LCanMove: Boolean;
  LTitleButton: TGuiTitleButton;
begin
  FindRootControl.ActiveControl := Self;
  inherited InternalMouseDown(Shift, Button, X, Y);
  if Button <> mbLeft then
    Exit;

  LTitleButton := TitleButtonAt(X, Y);
  if LTitleButton <> gtbNone then
  begin
    FMoving := False;
    FPressedTitleButton := LTitleButton;
    FHotTitleButton := LTitleButton;
    Exit;
  end;

  LCanMove := True;
  if Assigned(FOnCanMove) then
    FOnCanMove(Self, LCanMove);
  if LCanMove and (FWindowState <> gwsMaximized) and
     (Y < AbsoluteTop + FTitleBarHeight) then
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
  FHotTitleButton := TitleButtonAt(X, Y);
  if FPressedTitleButton <> gtbNone then
    Exit;
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
var
  LPressedButton: TGuiTitleButton;
  LActivateButton: Boolean;
begin
  LPressedButton := FPressedTitleButton;
  LActivateButton := (Button = mbLeft) and
    (LPressedButton <> gtbNone) and
    (TitleButtonAt(X, Y) = LPressedButton);
  FPressedTitleButton := gtbNone;
  FMoving := False;
  if FindRootControl.ActiveControl = Self then
    FindRootControl.ActiveControl := nil;
  inherited;

  if not LActivateButton then
    Exit;
  case LPressedButton of
    gtbMinimize:
      Minimize;
    gtbMaximize:
      ToggleMaximize;
    gtbClose:
      Close;
  end;
end;

procedure TGuiForm.Maximize;
var
  LCanResize: Boolean;
begin
  if FWindowState = gwsMaximized then
    Exit;

  LCanResize := True;
  if Assigned(FOnCanResize) then
    FOnCanResize(Self, LCanResize);
  if not LCanResize then
    Exit;

  if FWindowState = gwsNormal then
    SaveRestoreBounds;
  FWindowState := gwsMaximized;
  RefreshWindowStateBounds;
  if Assigned(FOnMaximize) then
    FOnMaximize(Self);
end;

procedure TGuiForm.Minimize;
begin
  if FWindowState = gwsMinimized then
    Exit;

  if FWindowState = gwsNormal then
    SaveRestoreBounds;
  FWindowState := gwsMinimized;
  if FHasRestoreBounds then
  begin
    Left := FRestoreLeft;
    Top := FRestoreTop;
    Width := FRestoreWidth;
  end;
  Height := FTitleBarHeight;
  if Assigned(FOnMinimize) then
    FOnMinimize(Self);
end;

function TGuiForm.MouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer): Boolean;
var
  LPoint: TVector2;
begin
  if FMoving or (FPressedTitleButton <> gtbNone) then
  begin
    LPoint := ScreenToUnrotated(X, Y);
    InternalMouseMove(Shift, Round(LPoint.X), Round(LPoint.Y));
    Exit(True);
  end;
  Result := inherited;
end;

function TGuiForm.MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer): Boolean;
var
  LPoint: TVector2;
begin
  if FMoving or (FPressedTitleButton <> gtbNone) then
  begin
    LPoint := ScreenToUnrotated(X, Y);
    InternalMouseUp(Shift, Button, Round(LPoint.X), Round(LPoint.Y));
    Exit(True);
  end;
  Result := inherited;
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

procedure TGuiForm.RefreshWindowStateBounds;
begin
  case FWindowState of
    gwsMinimized:
      Height := FTitleBarHeight;
    gwsMaximized:
      if Parent <> nil then
      begin
        Left := 0;
        Top := 0;
        Width := Parent.Width;
        Height := Parent.Height;
      end;
  end;
end;

procedure TGuiForm.Render(ARenderer: TGuiRenderer; AViewportWidth, AViewportHeight: Integer);
var
  LIndex: Integer;
  LTextRight: Single;
begin
  if not RecursiveVisible then
    Exit;
  RefreshWindowStateBounds;
  BeginRenderTransform(ARenderer);
  RenderSkin(ARenderer, ComponentName, AbsoluteLeft, AbsoluteTop, Width, Height,
    AViewportWidth, AViewportHeight);
  RenderTitleButton(ARenderer, gtbMinimize, AViewportWidth, AViewportHeight);
  RenderTitleButton(ARenderer, gtbMaximize, AViewportWidth, AViewportHeight);
  RenderTitleButton(ARenderer, gtbClose, AViewportWidth, AViewportHeight);
  LTextRight := System.Math.Max(AbsoluteLeft + 8,
    FirstTitleButtonLeft - 4);
  RenderText(ARenderer, Caption, AbsoluteLeft + 8, AbsoluteTop + FTitleOffset,
    LTextRight, AbsoluteTop + FTitleOffset + MeasureTextHeight + 4,
    AViewportWidth, AViewportHeight, taLeftJustify, tlCenter, FTitleColor);
  if FWindowState <> gwsMinimized then
    for LIndex := 0 to ChildCount - 1 do
      Children[LIndex].Render(ARenderer, AViewportWidth, AViewportHeight);
  EndRenderTransform(ARenderer);
end;

procedure TGuiForm.RenderTitleButton(ARenderer: TGuiRenderer;
  AButton: TGuiTitleButton; AViewportWidth, AViewportHeight: Integer);
var
  LRect: TGuiRect;
  LLayoutName: string;
  LCenterX: Single;
  LCenterY: Single;
  LGlyphSize: Single;
  LColor: TVector4;
  LHasCustomSkin: Boolean;
begin
  if ((AButton = gtbMinimize) and not FShowMinimizeButton) or
     ((AButton = gtbMaximize) and not FShowMaximizeButton) or
     ((AButton = gtbClose) and not FShowCloseButton) or
     (AButton = gtbNone) then
    Exit;

  LRect := TitleButtonRect(AButton);
  LLayoutName := ButtonLayoutName(AButton);
  LHasCustomSkin := (Layout <> nil) and (LLayoutName <> '') and
    (Layout.FindComponent(LLayoutName) <> nil);
  if LHasCustomSkin then
    RenderSkin(ARenderer, LLayoutName, LRect.X1, LRect.Y1, LRect.Width,
      LRect.Height, AViewportWidth, AViewportHeight)
  else
  begin
    if (AButton = FHotTitleButton) or
       (AButton = FPressedTitleButton) then
    begin
      if AButton = gtbClose then
        LColor := ColorToVec4(clRed, AlphaChannel * 0.85)
      else
        LColor := ColorToVec4(clGray, AlphaChannel * 0.75);
      ARenderer.RenderSolidRect(LRect.X1, LRect.Y1, LRect.Width,
        LRect.Height, AViewportWidth, AViewportHeight, LColor);
    end;

    LCenterX := (LRect.X1 + LRect.X2) * 0.5;
    LCenterY := (LRect.Y1 + LRect.Y2) * 0.5;
    LGlyphSize := System.Math.Max(4.0, LRect.Width * 0.46);
    LColor := ColorToVec4(FTitleColor, AlphaChannel);
    case AButton of
      gtbMinimize:
        ARenderer.RenderSolidRect(LCenterX - (LGlyphSize * 0.5),
          LCenterY + (LGlyphSize * 0.25), LGlyphSize, 2,
          AViewportWidth, AViewportHeight, LColor);
      gtbMaximize:
        if FWindowState = gwsMaximized then
        begin
          ARenderer.RenderSolidRect(LCenterX - (LGlyphSize * 0.30),
            LCenterY - (LGlyphSize * 0.42), LGlyphSize * 0.72, 2,
            AViewportWidth, AViewportHeight, LColor);
          ARenderer.RenderSolidRect(LCenterX + (LGlyphSize * 0.30),
            LCenterY - (LGlyphSize * 0.42), 2, LGlyphSize * 0.72,
            AViewportWidth, AViewportHeight, LColor);
          ARenderer.RenderSolidRect(LCenterX - (LGlyphSize * 0.50),
            LCenterY - (LGlyphSize * 0.18), LGlyphSize * 0.72, 2,
            AViewportWidth, AViewportHeight, LColor);
          ARenderer.RenderSolidRect(LCenterX - (LGlyphSize * 0.50),
            LCenterY - (LGlyphSize * 0.18), 2, LGlyphSize * 0.72,
            AViewportWidth, AViewportHeight, LColor);
          ARenderer.RenderSolidRect(LCenterX - (LGlyphSize * 0.50),
            LCenterY + (LGlyphSize * 0.50), LGlyphSize * 0.72, 2,
            AViewportWidth, AViewportHeight, LColor);
          ARenderer.RenderSolidRect(LCenterX + (LGlyphSize * 0.20),
            LCenterY - (LGlyphSize * 0.18), 2, LGlyphSize * 0.72,
            AViewportWidth, AViewportHeight, LColor);
        end
        else
        begin
          ARenderer.RenderSolidRect(LCenterX - (LGlyphSize * 0.5),
            LCenterY - (LGlyphSize * 0.5), LGlyphSize, 2,
            AViewportWidth, AViewportHeight, LColor);
          ARenderer.RenderSolidRect(LCenterX - (LGlyphSize * 0.5),
            LCenterY + (LGlyphSize * 0.5) - 2, LGlyphSize, 2,
            AViewportWidth, AViewportHeight, LColor);
          ARenderer.RenderSolidRect(LCenterX - (LGlyphSize * 0.5),
            LCenterY - (LGlyphSize * 0.5), 2, LGlyphSize,
            AViewportWidth, AViewportHeight, LColor);
          ARenderer.RenderSolidRect(LCenterX + (LGlyphSize * 0.5) - 2,
            LCenterY - (LGlyphSize * 0.5), 2, LGlyphSize,
            AViewportWidth, AViewportHeight, LColor);
        end;
      gtbClose:
        begin
          RenderGuiLine(ARenderer, LCenterX - (LGlyphSize * 0.5),
            LCenterY - (LGlyphSize * 0.5), LCenterX + (LGlyphSize * 0.5),
            LCenterY + (LGlyphSize * 0.5), 2, AViewportWidth,
            AViewportHeight, LColor);
          RenderGuiLine(ARenderer, LCenterX + (LGlyphSize * 0.5),
            LCenterY - (LGlyphSize * 0.5), LCenterX - (LGlyphSize * 0.5),
            LCenterY + (LGlyphSize * 0.5), 2, AViewportWidth,
            AViewportHeight, LColor);
        end;
    end;
  end;
end;

procedure TGuiForm.Restore;
begin
  if FWindowState = gwsNormal then
    Exit;

  FWindowState := gwsNormal;
  if FHasRestoreBounds then
  begin
    Left := FRestoreLeft;
    Top := FRestoreTop;
    Width := FRestoreWidth;
    Height := FRestoreHeight;
  end;
  if Assigned(FOnRestore) then
    FOnRestore(Self);
end;

procedure TGuiForm.SaveRestoreBounds;
begin
  FRestoreLeft := Left;
  FRestoreTop := Top;
  FRestoreWidth := Width;
  FRestoreHeight := Height;
  FHasRestoreBounds := True;
end;

procedure TGuiForm.SetButtonSize(const Value: Single);
begin
  FButtonSize := System.Math.EnsureRange(Value, 10.0, 128.0);
  if FTitleBarHeight < FButtonSize + 4.0 then
    FTitleBarHeight := FButtonSize + 4.0;
  RefreshWindowStateBounds;
end;

procedure TGuiForm.SetRestoreBounds(ALeft, ATop, AWidth, AHeight: Single);
begin
  FRestoreLeft := ALeft;
  FRestoreTop := ATop;
  FRestoreWidth := System.Math.Max(1.0, AWidth);
  FRestoreHeight := System.Math.Max(FTitleBarHeight, AHeight);
  FHasRestoreBounds := True;
end;

procedure TGuiForm.SetTitleBarHeight(const Value: Single);
begin
  FTitleBarHeight := System.Math.EnsureRange(Value,
    FButtonSize + 4.0, 256.0);
  RefreshWindowStateBounds;
end;

procedure TGuiForm.SetTitleColor(const Value: TColor);
begin
  FTitleColor := Value;
  DeleteTextTexture;
end;

procedure TGuiForm.SetWindowState(const Value: TGuiWindowState);
begin
  case Value of
    gwsNormal:
      Restore;
    gwsMinimized:
      Minimize;
    gwsMaximized:
      Maximize;
  end;
end;

function TGuiForm.TitleButtonAt(X, Y: Single): TGuiTitleButton;
begin
  if FShowCloseButton and PointInRectF(X, Y,
    TitleButtonRect(gtbClose)) then
    Exit(gtbClose);
  if FShowMaximizeButton and PointInRectF(X, Y,
    TitleButtonRect(gtbMaximize)) then
    Exit(gtbMaximize);
  if FShowMinimizeButton and PointInRectF(X, Y,
    TitleButtonRect(gtbMinimize)) then
    Exit(gtbMinimize);
  Result := gtbNone;
end;

function TGuiForm.TitleButtonRect(AButton: TGuiTitleButton): TGuiRect;
var
  LRight: Single;
  LTop: Single;

  function TakeButton(ATitleButton: TGuiTitleButton;
    AVisible: Boolean): Boolean;
  begin
    Result := False;
    if not AVisible then
      Exit;
    if ATitleButton = AButton then
    begin
      Result := True;
      Exit;
    end;
    LRight := LRight - FButtonSize - 2.0;
  end;

begin
  LRight := AbsoluteLeft + Width - 4.0;
  LTop := AbsoluteTop + System.Math.Max(0.0,
    (FTitleBarHeight - FButtonSize) * 0.5);
  if TakeButton(gtbClose, FShowCloseButton) or
     TakeButton(gtbMaximize, FShowMaximizeButton) or
     TakeButton(gtbMinimize, FShowMinimizeButton) then
    Result := TGuiRect.Create(LRight - FButtonSize, LTop, LRight,
      LTop + FButtonSize)
  else
    Result := TGuiRect.Create(0, 0, 0, 0);
end;

procedure TGuiForm.ToggleMaximize;
begin
  if FWindowState = gwsMaximized then
    Restore
  else
    Maximize;
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
var
  LPoint: TVector2;
begin
  if FScrolling then
  begin
    LPoint := ScreenToUnrotated(X, Y);
    InternalMouseMove(Shift, Round(LPoint.X), Round(LPoint.Y));
    Exit(True);
  end;
  Result := inherited;
end;

function TGuiScrollbar.MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer): Boolean;
var
  LPoint: TVector2;
begin
  if FScrolling then
  begin
    LPoint := ScreenToUnrotated(X, Y);
    InternalMouseUp(Shift, Button, Round(LPoint.X), Round(LPoint.Y));
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
  BeginRenderTransform(ARenderer);
  RenderSkin(ARenderer, ComponentName, AbsoluteLeft, AbsoluteTop, Width, Height,
    AViewportWidth, AViewportHeight);
  LKnob := KnobRect;
  RenderSkin(ARenderer, FKnobLayoutName, LKnob.X1, LKnob.Y1, LKnob.Width, LKnob.Height,
    AViewportWidth, AViewportHeight);
  for LIndex := 0 to ChildCount - 1 do
    Children[LIndex].Render(ARenderer, AViewportWidth, AViewportHeight);
  EndRenderTransform(ARenderer);
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
  BeginRenderTransform(ARenderer);
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
  EndRenderTransform(ARenderer);
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
  BeginRenderTransform(ARenderer);
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
  EndRenderTransform(ARenderer);
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

{ TGuiProgressBar }

constructor TGuiProgressBar.Create(AOwner: TComponent);
begin
  inherited;
  FMin := 0.0;
  FMax := 100.0;
  FValue := 0.0;
  FHorizontal := True;
  FShowText := True;
  FFillColor := clLime;
  FTrackColor := clGray;
end;

function TGuiProgressBar.ProgressRatio: Single;
begin
  if System.Math.SameValue(FMax, FMin) then
    Exit(0.0);
  Result := System.Math.EnsureRange((FValue - FMin) / (FMax - FMin),
    0.0, 1.0);
end;

function TGuiProgressBar.ProgressText: string;
begin
  if Caption <> '' then
    Result := Caption
  else
    Result := IntToStr(Round(ProgressRatio * 100.0)) + '%';
end;

procedure TGuiProgressBar.Render(ARenderer: TGuiRenderer; AViewportWidth,
  AViewportHeight: Integer);
var
  LIndex: Integer;
  LRatio: Single;
  LFillX: Single;
  LFillY: Single;
  LFillWidth: Single;
  LFillHeight: Single;
  LFillRect: TGuiRect;
begin
  if not RecursiveVisible then
    Exit;

  BeginRenderTransform(ARenderer);
  if ComponentName = '' then
    ARenderer.RenderSolidRect(AbsoluteLeft, AbsoluteTop, Width, Height,
      AViewportWidth, AViewportHeight,
      ColorToVec4(FTrackColor, AlphaChannel))
  else
    RenderSkin(ARenderer, ComponentName, AbsoluteLeft, AbsoluteTop, Width,
      Height, AViewportWidth, AViewportHeight);

  LRatio := ProgressRatio;
  LFillX := AbsoluteLeft;
  LFillY := AbsoluteTop;
  if FHorizontal then
  begin
    LFillWidth := Width * LRatio;
    LFillHeight := Height;
    if FReverse then
      LFillX := AbsoluteLeft + Width - LFillWidth;
  end
  else
  begin
    LFillWidth := Width;
    LFillHeight := Height * LRatio;
    if FReverse then
      LFillY := AbsoluteTop
    else
      LFillY := AbsoluteTop + Height - LFillHeight;
  end;

  if (LFillWidth > 0.0) and (LFillHeight > 0.0) then
    if FFillLayoutName = '' then
      ARenderer.RenderSolidRect(LFillX, LFillY, LFillWidth, LFillHeight,
        AViewportWidth, AViewportHeight,
        ColorToVec4(FFillColor, AlphaChannel))
    else
    begin
      LFillRect := TGuiRect.Create(LFillX, LFillY,
        LFillX + LFillWidth, LFillY + LFillHeight);
      RenderSkinClipped(ARenderer, FFillLayoutName, AbsoluteLeft,
        AbsoluteTop, Width, Height, LFillRect, AViewportWidth,
        AViewportHeight);
    end;

  if FShowText then
    RenderText(ARenderer, ProgressText, AbsoluteLeft + 4, AbsoluteTop,
      AbsoluteLeft + Width - 4, AbsoluteTop + Height, AViewportWidth,
      AViewportHeight, taCenter, tlCenter, DefaultColor);

  for LIndex := 0 to ChildCount - 1 do
    Children[LIndex].Render(ARenderer, AViewportWidth, AViewportHeight);
  EndRenderTransform(ARenderer);
end;

procedure TGuiProgressBar.SetMax(const Value: Single);
begin
  FMax := Value;
  if FMax < FMin then
    FMax := FMin;
  SetValue(FValue);
end;

procedure TGuiProgressBar.SetMin(const Value: Single);
begin
  FMin := Value;
  if FMax < FMin then
    FMax := FMin;
  SetValue(FValue);
end;

procedure TGuiProgressBar.SetValue(const Value: Single);
var
  LValue: Single;
begin
  LValue := System.Math.EnsureRange(Value, FMin, FMax);
  if System.Math.SameValue(FValue, LValue) then
    Exit;
  FValue := LValue;
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

{ TGuiShapeProgress }

constructor TGuiShapeProgress.Create(AOwner: TComponent);
begin
  inherited;
  FShape := gpsCircle;
  FInnerRadius := 0.62;
  FSegments := 64;
  FStartAngle := -90.0;
  ShowText := False;
end;

procedure TGuiShapeProgress.Render(ARenderer: TGuiRenderer; AViewportWidth,
  AViewportHeight: Integer);
var
  LIndex: Integer;
  LCX: Single;
  LCY: Single;
  LRadius: Single;
  LRatio: Single;
  LBottom: Single;
  LTop: Single;
  LHalfWidth: Single;
  LCutY: Single;
  LCutHalfWidth: Single;
  LVertices: TArray<TGuiVertex>;
begin
  if not RecursiveVisible then
    Exit;

  BeginRenderTransform(ARenderer);
  LCX := AbsoluteLeft + (Width * 0.5);
  LCY := AbsoluteTop + (Height * 0.5);
  LRadius := System.Math.Max(0.0,
    System.Math.Min(Width, Height) * 0.5);
  LRatio := ProgressRatio;

  if FShape = gpsCircle then
  begin
    RenderRingSector(ARenderer, LCX, LCY, LRadius,
      LRadius * FInnerRadius, 0.0, 360.0, FSegments, AViewportWidth,
      AViewportHeight, ColorToVec4(FTrackColor, AlphaChannel));
    if LRatio > 0.0 then
      RenderRingSector(ARenderer, LCX, LCY, LRadius,
        LRadius * FInnerRadius, FStartAngle, 360.0 * LRatio, FSegments,
        AViewportWidth, AViewportHeight,
        ColorToVec4(FFillColor, AlphaChannel));
  end
  else
  begin
    LTop := LCY - LRadius;
    LBottom := LCY + LRadius;
    LHalfWidth := LRadius;
    RenderTriangle(ARenderer, LCX, LTop, LCX + LHalfWidth, LBottom,
      LCX - LHalfWidth, LBottom, AViewportWidth, AViewportHeight,
      ColorToVec4(FTrackColor, AlphaChannel));

    if LRatio > 0.0 then
    begin
      LCutY := LBottom - ((LBottom - LTop) * LRatio);
      LCutHalfWidth := LHalfWidth * (1.0 - LRatio);
      SetLength(LVertices, 6);
      SetSolidVertex(LVertices[0], LCX - LHalfWidth, LBottom);
      SetSolidVertex(LVertices[1], LCX + LHalfWidth, LBottom);
      SetSolidVertex(LVertices[2], LCX + LCutHalfWidth, LCutY);
      SetSolidVertex(LVertices[3], LCX - LHalfWidth, LBottom);
      SetSolidVertex(LVertices[4], LCX + LCutHalfWidth, LCutY);
      SetSolidVertex(LVertices[5], LCX - LCutHalfWidth, LCutY);
      ARenderer.RenderSolidVertices(LVertices, AViewportWidth,
        AViewportHeight, ColorToVec4(FFillColor, AlphaChannel));
    end;
  end;

  if FShowText then
    RenderText(ARenderer, ProgressText, AbsoluteLeft, AbsoluteTop,
      AbsoluteLeft + Width, AbsoluteTop + Height, AViewportWidth,
      AViewportHeight, taCenter, tlCenter, DefaultColor);
  for LIndex := 0 to ChildCount - 1 do
    Children[LIndex].Render(ARenderer, AViewportWidth, AViewportHeight);
  EndRenderTransform(ARenderer);
end;

procedure TGuiShapeProgress.SetInnerRadius(const Value: Single);
begin
  FInnerRadius := System.Math.EnsureRange(Value, 0.0, 0.95);
end;

procedure TGuiShapeProgress.SetSegments(const Value: Integer);
begin
  FSegments := System.Math.EnsureRange(Value, 3, 512);
end;

{ TGuiAnimatedProgress }

constructor TGuiAnimatedProgress.Create(AOwner: TComponent);
begin
  inherited;
  FAtlasTexture := TGuiTexture.Create;
  FAtlasDirty := False;
  FGridColumns := 1;
  FGridRows := 1;
  FFirstFrame := 0;
  FFrameCount := 1;
  FCurrentFrameIndex := 0;
  FFrameRate := 12.0;
  FLoop := True;
  FPlaying := True;
  FLastTick := GetTickCount64;
  Horizontal := False;
  Reverse := False;
  ShowText := False;
  FillColor := clWhite;
end;

destructor TGuiAnimatedProgress.Destroy;
begin
  FAtlasTexture.Free;
  inherited;
end;

procedure TGuiAnimatedProgress.EnsureAtlasTexture;
var
  LFileName: string;
begin
  if not FAtlasDirty then
    Exit;

  FAtlasDirty := False;
  FAtlasTexture.Clear;
  if FAtlasTexturePath = '' then
    Exit;

  LFileName := TEnginePaths.ResolveAssetPath(FAtlasTexturePath);
  if FileExists(LFileName) then
    FAtlasTexture.LoadFromFile(LFileName);
end;

function TGuiAnimatedProgress.GetCurrentSheetFrameIndex: Integer;
begin
  Result := System.Math.EnsureRange(FFirstFrame + FCurrentFrameIndex, 0,
    System.Math.Max(0, GetGridFrameCapacity - 1));
end;

function TGuiAnimatedProgress.GetGridFrameCapacity: Integer;
begin
  Result := System.Math.Max(1, FGridColumns) *
    System.Math.Max(1, FGridRows);
end;

function TGuiAnimatedProgress.LoadAtlas(const APath: string): Boolean;
var
  LFileName: string;
begin
  LFileName := TEnginePaths.ResolveAssetPath(Trim(APath));
  Result := FileExists(LFileName);
  if not Result then
    Exit;
  SetAtlasTexturePath(APath);
  FAtlasDirty := True;
  RestartAnimation;
end;

procedure TGuiAnimatedProgress.NormalizeFrameRange;
var
  LCapacity: Integer;
begin
  FGridColumns := System.Math.EnsureRange(FGridColumns, 1, 1024);
  FGridRows := System.Math.EnsureRange(FGridRows, 1, 1024);
  LCapacity := GetGridFrameCapacity;
  FFirstFrame := System.Math.EnsureRange(FFirstFrame, 0,
    System.Math.Max(0, LCapacity - 1));
  FFrameCount := System.Math.EnsureRange(FFrameCount, 1,
    System.Math.Max(1, LCapacity - FFirstFrame));
  FCurrentFrameIndex := System.Math.EnsureRange(FCurrentFrameIndex, 0,
    System.Math.Max(0, FFrameCount - 1));
end;

procedure TGuiAnimatedProgress.Render(ARenderer: TGuiRenderer;
  AViewportWidth, AViewportHeight: Integer);
var
  LIndex: Integer;
  LNow: UInt64;
  LRatio: Single;
  LFillX: Single;
  LFillY: Single;
  LFillWidth: Single;
  LFillHeight: Single;
  LFillRect: TGuiRect;
begin
  if not RecursiveVisible then
    Exit;

  LNow := GetTickCount64;
  if LNow >= FLastTick then
    UpdateAnimation((LNow - FLastTick) / 1000.0);
  FLastTick := LNow;
  EnsureAtlasTexture;

  BeginRenderTransform(ARenderer);
  if ComponentName = '' then
    ARenderer.RenderSolidRect(AbsoluteLeft, AbsoluteTop, Width, Height,
      AViewportWidth, AViewportHeight,
      ColorToVec4(FTrackColor, AlphaChannel))
  else
    RenderSkin(ARenderer, ComponentName, AbsoluteLeft, AbsoluteTop, Width,
      Height, AViewportWidth, AViewportHeight);

  LRatio := ProgressRatio;
  LFillX := AbsoluteLeft;
  LFillY := AbsoluteTop;
  if FHorizontal then
  begin
    LFillWidth := Width * LRatio;
    LFillHeight := Height;
    if FReverse then
      LFillX := AbsoluteLeft + Width - LFillWidth;
  end
  else
  begin
    LFillWidth := Width;
    LFillHeight := Height * LRatio;
    if FReverse then
      LFillY := AbsoluteTop
    else
      LFillY := AbsoluteTop + Height - LFillHeight;
  end;

  if (LFillWidth > 0.0) and (LFillHeight > 0.0) then
  begin
    LFillRect := TGuiRect.Create(LFillX, LFillY,
      LFillX + LFillWidth, LFillY + LFillHeight);
    if FFillLayoutName <> '' then
      RenderSkinClipped(ARenderer, FFillLayoutName, AbsoluteLeft,
        AbsoluteTop, Width, Height, LFillRect, AViewportWidth,
        AViewportHeight)
    else if FAtlasTexture.TextureID = 0 then
      ARenderer.RenderSolidRect(LFillX, LFillY, LFillWidth, LFillHeight,
        AViewportWidth, AViewportHeight,
        ColorToVec4(FFillColor, AlphaChannel));
    RenderAtlasFrame(ARenderer, LFillRect, AViewportWidth, AViewportHeight);
  end;

  if FOverlayLayoutName <> '' then
    RenderSkin(ARenderer, FOverlayLayoutName, AbsoluteLeft, AbsoluteTop,
      Width, Height, AViewportWidth, AViewportHeight);

  if FShowText then
    RenderText(ARenderer, ProgressText, AbsoluteLeft + 4, AbsoluteTop,
      AbsoluteLeft + Width - 4, AbsoluteTop + Height, AViewportWidth,
      AViewportHeight, taCenter, tlCenter, DefaultColor);

  for LIndex := 0 to ChildCount - 1 do
    Children[LIndex].Render(ARenderer, AViewportWidth, AViewportHeight);
  EndRenderTransform(ARenderer);
end;

procedure TGuiAnimatedProgress.RenderAtlasFrame(ARenderer: TGuiRenderer;
  const AClipRect: TGuiRect; AViewportWidth, AViewportHeight: Integer);
var
  LVertices: TArray<TGuiVertex>;
  LSheetFrame: Integer;
  LFrameX: Integer;
  LFrameY: Integer;
  LLeftFraction: Single;
  LRightFraction: Single;
  LTopFraction: Single;
  LBottomFraction: Single;
  LU0: Single;
  LU1: Single;
  LVTop: Single;
  LVBottom: Single;
  LClipU0: Single;
  LClipU1: Single;
  LClipVTop: Single;
  LClipVBottom: Single;
  LTint: TVector4;
  LFillTint: TVector4;

  procedure SetVertex(AIndex: Integer; AX, AY, AU, AV: Single);
  begin
    LVertices[AIndex].Position := Vector2(AX, AY);
    LVertices[AIndex].TexCoord := Vector2(AU, AV);
  end;

begin
  if (ARenderer = nil) or (FAtlasTexture.TextureID = 0) or
     AClipRect.IsEmpty or (Width <= 0.0) or (Height <= 0.0) then
    Exit;

  LSheetFrame := GetCurrentSheetFrameIndex;
  LFrameX := LSheetFrame mod FGridColumns;
  LFrameY := LSheetFrame div FGridColumns;
  LU0 := LFrameX / FGridColumns;
  LU1 := (LFrameX + 1) / FGridColumns;
  LVTop := 1.0 - (LFrameY / FGridRows);
  LVBottom := 1.0 - ((LFrameY + 1) / FGridRows);

  LLeftFraction := System.Math.EnsureRange(
    (AClipRect.X1 - AbsoluteLeft) / Width, 0.0, 1.0);
  LRightFraction := System.Math.EnsureRange(
    (AClipRect.X2 - AbsoluteLeft) / Width, 0.0, 1.0);
  LTopFraction := System.Math.EnsureRange(
    (AClipRect.Y1 - AbsoluteTop) / Height, 0.0, 1.0);
  LBottomFraction := System.Math.EnsureRange(
    (AClipRect.Y2 - AbsoluteTop) / Height, 0.0, 1.0);
  LClipU0 := LU0 + ((LU1 - LU0) * LLeftFraction);
  LClipU1 := LU0 + ((LU1 - LU0) * LRightFraction);
  LClipVTop := LVTop + ((LVBottom - LVTop) * LTopFraction);
  LClipVBottom := LVTop + ((LVBottom - LVTop) * LBottomFraction);

  SetLength(LVertices, 6);
  SetVertex(0, AClipRect.X1, AClipRect.Y1, LClipU0, LClipVTop);
  SetVertex(1, AClipRect.X1, AClipRect.Y2, LClipU0, LClipVBottom);
  SetVertex(2, AClipRect.X2, AClipRect.Y2, LClipU1, LClipVBottom);
  SetVertex(3, AClipRect.X1, AClipRect.Y1, LClipU0, LClipVTop);
  SetVertex(4, AClipRect.X2, AClipRect.Y2, LClipU1, LClipVBottom);
  SetVertex(5, AClipRect.X2, AClipRect.Y1, LClipU1, LClipVTop);

  LTint := EffectiveTint;
  LFillTint := ColorToVec4(FFillColor, 1.0);
  LTint.X := LTint.X * LFillTint.X;
  LTint.Y := LTint.Y * LFillTint.Y;
  LTint.Z := LTint.Z * LFillTint.Z;
  LTint.W := LTint.W * LFillTint.W;
  ARenderer.RenderVertices(LVertices, FAtlasTexture.TextureID,
    AViewportWidth, AViewportHeight, LTint);
end;

procedure TGuiAnimatedProgress.RestartAnimation;
begin
  FFrameTimer := 0.0;
  FCurrentFrameIndex := 0;
  FPlaying := True;
  FLastTick := GetTickCount64;
end;

procedure TGuiAnimatedProgress.SetAtlasTexturePath(const Value: string);
var
  LStoredPath: string;
begin
  LStoredPath := TEnginePaths.ToAssetRelativePath(Trim(Value));
  if SameText(FAtlasTexturePath, LStoredPath) then
    Exit;
  FAtlasTexturePath := LStoredPath;
  FAtlasDirty := True;
end;

procedure TGuiAnimatedProgress.SetCurrentFrameIndex(const Value: Integer);
begin
  FCurrentFrameIndex := System.Math.EnsureRange(Value, 0,
    System.Math.Max(0, FFrameCount - 1));
end;

procedure TGuiAnimatedProgress.SetFirstFrame(const Value: Integer);
begin
  FFirstFrame := System.Math.EnsureRange(Value, 0,
    System.Math.Max(0, GetGridFrameCapacity - 1));
  NormalizeFrameRange;
end;

procedure TGuiAnimatedProgress.SetFrameCount(const Value: Integer);
begin
  FFrameCount := System.Math.EnsureRange(Value, 1,
    System.Math.Max(1, GetGridFrameCapacity - FFirstFrame));
  NormalizeFrameRange;
end;

procedure TGuiAnimatedProgress.SetFrameRate(const Value: Single);
begin
  FFrameRate := System.Math.EnsureRange(Value, 0.001, 240.0);
end;

procedure TGuiAnimatedProgress.SetGridColumns(const Value: Integer);
begin
  FGridColumns := System.Math.EnsureRange(Value, 1, 1024);
  NormalizeFrameRange;
end;

procedure TGuiAnimatedProgress.SetGridRows(const Value: Integer);
begin
  FGridRows := System.Math.EnsureRange(Value, 1, 1024);
  NormalizeFrameRange;
end;

procedure TGuiAnimatedProgress.SetPlaying(const Value: Boolean);
begin
  FPlaying := Value;
  FLastTick := GetTickCount64;
end;

procedure TGuiAnimatedProgress.UpdateAnimation(DeltaTime: Single);
var
  LFrameDuration: Single;
  LNewIndex: Integer;
begin
  if not FPlaying or (FFrameCount <= 1) then
    Exit;

  DeltaTime := System.Math.EnsureRange(DeltaTime, 0.0, 10.0);
  if DeltaTime <= 0.0 then
    Exit;

  LFrameDuration := 1.0 / System.Math.Max(0.001, FFrameRate);
  FFrameTimer := FFrameTimer + DeltaTime;
  while FFrameTimer >= LFrameDuration do
  begin
    FFrameTimer := FFrameTimer - LFrameDuration;
    LNewIndex := FCurrentFrameIndex + 1;
    if LNewIndex >= FFrameCount then
    begin
      if FLoop then
        LNewIndex := 0
      else
      begin
        LNewIndex := FFrameCount - 1;
        FPlaying := False;
      end;
    end;
    FCurrentFrameIndex := LNewIndex;
    if not FPlaying then
      Break;
  end;
end;

{ TGuiSpinner }

constructor TGuiSpinner.Create(AOwner: TComponent);
begin
  inherited;
  FAngle := -90.0;
  FAutoSpin := True;
  FColor := clWhite;
  FTrackColor := clGray;
  FSegments := 12;
  FSpeed := 180.0;
  FThickness := 0.22;
end;

procedure TGuiSpinner.Render(ARenderer: TGuiRenderer; AViewportWidth,
  AViewportHeight: Integer);
var
  LIndex: Integer;
  LTick: UInt64;
  LDelta: Single;
  LCX: Single;
  LCY: Single;
  LRadius: Single;
  LInnerRadius: Single;
  LStep: Single;
  LAlpha: Single;
  LColor: TVector4;
begin
  if not RecursiveVisible then
    Exit;

  LTick := GetTickCount64;
  if FAutoSpin and (FLastTick <> 0) then
  begin
    LDelta := System.Math.Min(0.25, (LTick - FLastTick) / 1000.0);
    FAngle := FAngle + (FSpeed * LDelta);
    if System.Abs(FAngle) >= 360.0 then
      FAngle := FAngle - (Trunc(FAngle / 360.0) * 360.0);
  end;
  FLastTick := LTick;

  BeginRenderTransform(ARenderer);
  LCX := AbsoluteLeft + (Width * 0.5);
  LCY := AbsoluteTop + (Height * 0.5);
  LRadius := System.Math.Max(0.0,
    System.Math.Min(Width, Height) * 0.5);
  LInnerRadius := LRadius * (1.0 - FThickness);
  RenderRingSector(ARenderer, LCX, LCY, LRadius, LInnerRadius, 0.0, 360.0,
    System.Math.Max(32, FSegments * 4), AViewportWidth, AViewportHeight,
    ColorToVec4(FTrackColor, AlphaChannel * 0.35));

  LStep := 360.0 / FSegments;
  for LIndex := 0 to FSegments - 1 do
  begin
    LAlpha := (LIndex + 1) / FSegments;
    LColor := ColorToVec4(FColor, AlphaChannel * LAlpha);
    RenderRingSector(ARenderer, LCX, LCY, LRadius, LInnerRadius,
      FAngle + (LIndex * LStep), LStep * 0.58, 4, AViewportWidth,
      AViewportHeight, LColor);
  end;

  for LIndex := 0 to ChildCount - 1 do
    Children[LIndex].Render(ARenderer, AViewportWidth, AViewportHeight);
  EndRenderTransform(ARenderer);
end;

procedure TGuiSpinner.SetSegments(const Value: Integer);
begin
  FSegments := System.Math.EnsureRange(Value, 3, 128);
end;

procedure TGuiSpinner.SetThickness(const Value: Single);
begin
  FThickness := System.Math.EnsureRange(Value, 0.02, 1.0);
end;

{ TGuiListBox }

constructor TGuiListBox.Create(AOwner: TComponent);
begin
  inherited;
  FItems := TStringList.Create;
  FItems.OnChange := ItemsChanged;
  FHoverIndex := -1;
  FSelectedIndex := -1;
  FItemHeight := 24.0;
  FMarginSize := 4.0;
  FSelectionColor := clHighlight;
end;

destructor TGuiListBox.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TGuiListBox.AddItem(const AText: string): Integer;
begin
  Result := FItems.Add(AText);
end;

procedure TGuiListBox.Clear;
begin
  FItems.Clear;
end;

procedure TGuiListBox.DeleteItem(AIndex: Integer);
begin
  if (AIndex >= 0) and (AIndex < FItems.Count) then
    FItems.Delete(AIndex);
end;

procedure TGuiListBox.DoMouseLeave;
begin
  FHoverIndex := -1;
  inherited;
end;

function TGuiListBox.GetItems: TStrings;
begin
  Result := FItems;
end;

procedure TGuiListBox.InternalMouseDown(Shift: TShiftState;
  Button: TMouseButton; X, Y: Integer);
var
  LIndex: Integer;
begin
  SetFocus;
  inherited;
  if Button <> mbLeft then
    Exit;
  LIndex := ItemIndexAt(Y, ItemsTop);
  if LIndex >= 0 then
    SelectedIndex := LIndex;
end;

procedure TGuiListBox.InternalMouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  FHoverIndex := ItemIndexAt(Y, ItemsTop);
end;

function TGuiListBox.ItemsTop: Single;
begin
  Result := AbsoluteTop;
end;

function TGuiListBox.Item(AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex < FItems.Count) then
    Result := FItems[AIndex]
  else
    Result := '';
end;

function TGuiListBox.ItemCount: Integer;
begin
  Result := FItems.Count;
end;

function TGuiListBox.ItemIndexAt(Y, AListTop: Single): Integer;
begin
  if Y < AListTop + FMarginSize then
    Exit(-1);
  Result := FTopIndex + Trunc((Y - AListTop - FMarginSize) /
    System.Math.Max(1.0, FItemHeight));
  if (Result < FTopIndex) or (Result >= FItems.Count) then
    Result := -1;
end;

procedure TGuiListBox.ItemsChanged(Sender: TObject);
begin
  FSelectedIndex := System.Math.EnsureRange(FSelectedIndex, -1,
    FItems.Count - 1);
  FHoverIndex := System.Math.EnsureRange(FHoverIndex, -1, FItems.Count - 1);
  SetTopIndex(FTopIndex);
  DeleteTextTexture;
end;

procedure TGuiListBox.Render(ARenderer: TGuiRenderer; AViewportWidth,
  AViewportHeight: Integer);
var
  LIndex: Integer;
begin
  if not RecursiveVisible then
    Exit;
  BeginRenderTransform(ARenderer);
  RenderSkin(ARenderer, ComponentName, AbsoluteLeft, AbsoluteTop, Width, Height,
    AViewportWidth, AViewportHeight);
  RenderItems(ARenderer, AbsoluteTop, Height, AViewportWidth, AViewportHeight);
  for LIndex := 0 to ChildCount - 1 do
    Children[LIndex].Render(ARenderer, AViewportWidth, AViewportHeight);
  EndRenderTransform(ARenderer);
end;

procedure TGuiListBox.RenderItems(ARenderer: TGuiRenderer; ATop,
  AHeight: Single; AViewportWidth, AViewportHeight: Integer);
var
  LIndex: Integer;
  LY: Single;
  LBottom: Single;
  LColor: TColor;
  LText: string;
begin
  LY := ATop + FMarginSize;
  LBottom := ATop + AHeight - FMarginSize;
  for LIndex := FTopIndex to FItems.Count - 1 do
  begin
    if LY + FItemHeight > LBottom + 0.01 then
      Break;
    if LIndex = FSelectedIndex then
      ARenderer.RenderSolidRect(AbsoluteLeft + FMarginSize, LY,
        System.Math.Max(0.0, Width - (FMarginSize * 2)), FItemHeight,
        AViewportWidth,
        AViewportHeight, ColorToVec4(FSelectionColor, AlphaChannel * 0.75));
    if (LIndex = FSelectedIndex) or (LIndex = FHoverIndex) then
      LColor := FocusedColor
    else
      LColor := DefaultColor;
    LText := FitTextToWidth(FItems[LIndex],
      System.Math.Max(0.0, Width - (FMarginSize * 3)));
    RenderText(ARenderer, LText, AbsoluteLeft + (FMarginSize * 2), LY,
      AbsoluteLeft + Width - FMarginSize, LY + FItemHeight, AViewportWidth,
      AViewportHeight, taLeftJustify, tlCenter, LColor);
    LY := LY + FItemHeight;
  end;
end;

procedure TGuiListBox.SetItemHeight(const Value: Single);
begin
  FItemHeight := System.Math.Max(1.0, Value);
end;

procedure TGuiListBox.SetItems(const Value: TStrings);
begin
  FItems.Assign(Value);
end;

procedure TGuiListBox.SetSelectedIndex(const Value: Integer);
var
  LValue: Integer;
begin
  LValue := System.Math.EnsureRange(Value, -1, FItems.Count - 1);
  if FSelectedIndex = LValue then
    Exit;
  FSelectedIndex := LValue;
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TGuiListBox.SetTopIndex(const Value: Integer);
begin
  FTopIndex := System.Math.EnsureRange(Value, 0,
    System.Math.Max(0, FItems.Count - 1));
end;

{ TGuiComboBox }

constructor TGuiComboBox.Create(AOwner: TComponent);
begin
  inherited;
  FDropDownCount := 8;
end;

function TGuiComboBox.ContainsPoint(X, Y: Single): Boolean;
var
  LPoint: TVector2;
begin
  Result := inherited ContainsPoint(X, Y);
  if Result or not FDroppedDown then
    Exit;
  LPoint := ScreenToUnrotated(X, Y);
  Result := (LPoint.X >= AbsoluteLeft) and
    (LPoint.X < AbsoluteLeft + Width) and
    (LPoint.Y >= AbsoluteTop + Height) and
    (LPoint.Y < AbsoluteTop + Height + DropDownHeight);
end;

function TGuiComboBox.DropDownHeight: Single;
begin
  Result := (System.Math.Min(FItems.Count, FDropDownCount) * FItemHeight) +
    (FMarginSize * 2);
end;

procedure TGuiComboBox.InternalMouseDown(Shift: TShiftState;
  Button: TMouseButton; X, Y: Integer);
var
  LIndex: Integer;
begin
  inherited;
  if Button <> mbLeft then
    Exit;

  if Y < AbsoluteTop + Height then
  begin
    DroppedDown := not FDroppedDown;
    Exit;
  end;

  if FDroppedDown then
  begin
    LIndex := ItemIndexAt(Y, AbsoluteTop + Height);
    if LIndex >= 0 then
      SelectedIndex := LIndex;
    DroppedDown := False;
  end;
end;

procedure TGuiComboBox.InternalMouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if FDroppedDown and (Y >= AbsoluteTop + Height) then
    FHoverIndex := ItemIndexAt(Y, AbsoluteTop + Height)
  else
    FHoverIndex := -1;
end;

function TGuiComboBox.ItemsTop: Single;
begin
  Result := AbsoluteTop + Height;
end;

procedure TGuiComboBox.Render(ARenderer: TGuiRenderer; AViewportWidth,
  AViewportHeight: Integer);
var
  LIndex: Integer;
  LText: string;
  LTextColor: TColor;
  LArrowSize: Single;
  LVertices: TArray<TGuiVertex>;
begin
  if not RecursiveVisible then
    Exit;

  BeginRenderTransform(ARenderer);
  RenderSkin(ARenderer, ComponentName, AbsoluteLeft, AbsoluteTop, Width, Height,
    AViewportWidth, AViewportHeight);
  if (FSelectedIndex >= 0) and (FSelectedIndex < FItems.Count) then
    LText := FItems[FSelectedIndex]
  else
    LText := Caption;
  LText := FitTextToWidth(LText,
    System.Math.Max(0.0, Width - Height - 8));
  if Highlighted then
    LTextColor := FocusedColor
  else
    LTextColor := DefaultColor;
  RenderText(ARenderer, LText, AbsoluteLeft + 4, AbsoluteTop,
    AbsoluteLeft + Width - Height - 4, AbsoluteTop + Height, AViewportWidth,
    AViewportHeight, taLeftJustify, tlCenter, LTextColor);

  LArrowSize := System.Math.Min(Width, Height);
  if FArrowLayoutName <> '' then
    RenderSkin(ARenderer, FArrowLayoutName,
      AbsoluteLeft + Width - LArrowSize, AbsoluteTop, LArrowSize, Height,
      AViewportWidth, AViewportHeight)
  else
  begin
    SetLength(LVertices, 3);
    SetSolidVertex(LVertices[0], AbsoluteLeft + Width - (LArrowSize * 0.70),
      AbsoluteTop + (Height * 0.40));
    SetSolidVertex(LVertices[1], AbsoluteLeft + Width - (LArrowSize * 0.30),
      AbsoluteTop + (Height * 0.40));
    SetSolidVertex(LVertices[2], AbsoluteLeft + Width - (LArrowSize * 0.50),
      AbsoluteTop + (Height * 0.65));
    ARenderer.RenderSolidVertices(LVertices, AViewportWidth, AViewportHeight,
      ColorToVec4(DefaultColor, AlphaChannel));
  end;

  if FDroppedDown and (DropDownHeight > 0.0) then
  begin
    if FDropDownLayoutName <> '' then
      RenderSkin(ARenderer, FDropDownLayoutName, AbsoluteLeft,
        AbsoluteTop + Height, Width, DropDownHeight, AViewportWidth,
        AViewportHeight)
    else
      ARenderer.RenderSolidRect(AbsoluteLeft, AbsoluteTop + Height, Width,
        DropDownHeight, AViewportWidth, AViewportHeight,
        Vector4(0.05, 0.05, 0.05, AlphaChannel * 0.95));
    RenderItems(ARenderer, AbsoluteTop + Height, DropDownHeight,
      AViewportWidth, AViewportHeight);
  end;

  for LIndex := 0 to ChildCount - 1 do
    Children[LIndex].Render(ARenderer, AViewportWidth, AViewportHeight);
  EndRenderTransform(ARenderer);
end;

procedure TGuiComboBox.SetDropDownCount(const Value: Integer);
begin
  FDropDownCount := System.Math.EnsureRange(Value, 1, 1000);
end;

procedure TGuiComboBox.SetDroppedDown(const Value: Boolean);
begin
  FDroppedDown := Value and (FItems.Count > 0);
  if FDroppedDown then
    SetFocus
  else
    FHoverIndex := -1;
end;

procedure TGuiComboBox.SetFocused(Value: Boolean);
begin
  inherited;
  if not Value then
    FDroppedDown := False;
end;

initialization
  RegisterClasses([TGuiBaseControl, TGuiPanel, TGuiButton, TGuiCheckBox, TGuiEdit,
    TGuiLabel, TGuiAdvancedLabel, TGuiForm, TGuiScrollbar, TGuiPopupMenu,
    TGuiStringGrid, TGuiProgressBar, TGuiShapeProgress,
    TGuiAnimatedProgress, TGuiSpinner, TGuiListBox, TGuiComboBox]);

end.
