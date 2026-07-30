unit OGLM_GameForm;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.Classes,
  System.SysUtils,
  System.IOUtils,
  System.StrUtils,
  Vcl.Controls,
  Vcl.Forms,
  Engine,
  Engine.Time;

const
  WM_OGLM_START_GAME = WM_APP + $4D;

type
  TGameForm = class(TForm)
  private const
    GAME_TITLE = 'OpenGL Micro Engine Game';

    { Template entry point.

      Leave this empty while launching with a run argument:
        OGLM_Game.exe MainMenu.omescn
        OGLM_Game.exe --scene GameIntro.omescn
        OGLM_Game.exe "Data\Scenes\Scene.omescn"
        OGLM_Game.exe --scene MainMenu.omescn --fullscreen
        OGLM_Game.exe --fullscreen GUI_Scene.omescn
        OGLM_Game.exe --scene GUI_Scene.omescn --resolution 1600x900
        OGLM_Game.exe --fullscreen --res=1920x1080 MainMenu.omescn

      For a shipped game/template copy, set this to the first scene to load
      when no command-line scene is supplied, for example:
        DEFAULT_ENTRY_SCENE = 'MainMenu.omescn';
    }
    DEFAULT_ENTRY_SCENE = '';

    DEFAULT_WIDTH = 1280;
    DEFAULT_HEIGHT = 720;
    MIN_STARTUP_WIDTH = 320;
    MIN_STARTUP_HEIGHT = 200;
    DEFAULT_ANTIALIASING_SAMPLES = 4;
    START_FULLSCREEN = False;
    START_MAXIMIZED = False;
  private
    FEngine: TGameEngine;
    FTimer: TEngineTimer;
    FLog: TStringList;
    FCurrentScene: string;
    FLastScriptError: string;
    FStartFullScreen: Boolean;
    FStartupWidth: Integer;
    FStartupHeight: Integer;
    FStartupResolutionSpecified: Boolean;
    FDisplayModeChanged: Boolean;
    FDisplayModeStatus: string;
    FGameStartPending: Boolean;

    procedure ApplyStartupWindowMode;
    procedure RestoreDisplayMode;
    procedure InitializeGame;
    procedure ShutdownGame;
    procedure StartGameAfterShow;
    procedure StartGameLoop;
    procedure StopGameLoop;
    function NudgeMouseCursor: Boolean;
    procedure LoadStartupScene;
    procedure LogLine(const AText: string);

    function StartupSceneArgument: string;
    function StartupFullScreenArgument: Boolean;
    function StartupResolutionArgument(var AWidth, AHeight: Integer): Boolean;
    function BooleanSwitchValue(const AValue: string;
      ADefault: Boolean): Boolean;
    function ExtractSwitchValue(const AArg, ASwitch: string): string;
    function IsFullScreenSwitch(const AArg: string): Boolean;
    function IsWindowedSwitch(const AArg: string): Boolean;
    function IsWindowModeArgument(const AArg: string): Boolean;
    function IsResolutionSwitch(const AArg: string): Boolean;
    function IsResolutionArgument(const AArg: string): Boolean;
    function IsWidthSwitch(const AArg: string): Boolean;
    function IsHeightSwitch(const AArg: string): Boolean;
    function TryParseResolution(const AValue: string; out AWidth,
      AHeight: Integer): Boolean;
    function TryParsePositiveInteger(const AValue: string;
      out AValueInt: Integer): Boolean;
    function TryApplyFullScreenResolution(AWidth, AHeight: Integer): Boolean;
    function DisplayChangeResultText(AResult: Longint): string;
    procedure ClampStartupResolution(var AWidth, AHeight: Integer);
    function NormalizeSceneArgument(const AScene: string): string;
    function StripArgumentQuotes(const AValue: string): string;

    procedure GameProgress(Sender: TObject; const DeltaTime, NewTime: Double);
    procedure FormShowHandler(Sender: TObject);
    procedure FormResizeHandler(Sender: TObject);
    procedure FormPaintHandler(Sender: TObject);
    procedure FormMouseDownHandler(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormMouseMoveHandler(Sender: TObject; Shift: TShiftState;
      X, Y: Integer);
    procedure FormMouseUpHandler(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormKeyDownHandler(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FormKeyPressHandler(Sender: TObject; var Key: Char);
    procedure FormKeyUpHandler(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FormCloseHandler(Sender: TObject; var Action: TCloseAction);
    procedure WMStartGame(var Message: TMessage); message WM_OGLM_START_GAME;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  GameForm: TGameForm;

implementation

constructor TGameForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner, 0);

  Caption := GAME_TITLE;
  Position := poScreenCenter;
  DoubleBuffered := False;
  KeyPreview := True;

  FStartupWidth := DEFAULT_WIDTH;
  FStartupHeight := DEFAULT_HEIGHT;
  FStartupResolutionSpecified := StartupResolutionArgument(FStartupWidth,
    FStartupHeight);
  ClientWidth := FStartupWidth;
  ClientHeight := FStartupHeight;

  FStartFullScreen := StartupFullScreenArgument;
  ApplyStartupWindowMode;

  OnShow := FormShowHandler;
  OnResize := FormResizeHandler;
  OnPaint := FormPaintHandler;
  OnMouseDown := FormMouseDownHandler;
  OnMouseMove := FormMouseMoveHandler;
  OnMouseUp := FormMouseUpHandler;
  OnKeyDown := FormKeyDownHandler;
  OnKeyPress := FormKeyPressHandler;
  OnKeyUp := FormKeyUpHandler;
  OnClose := FormCloseHandler;

  InitializeGame;
end;

procedure TGameForm.ApplyStartupWindowMode;
var
  TargetMonitor: TMonitor;
begin
  if FStartFullScreen then
  begin
    Position := poDesigned;
    WindowState := wsNormal;
    BorderStyle := bsNone;

    if FStartupResolutionSpecified then
      FDisplayModeChanged := TryApplyFullScreenResolution(FStartupWidth,
        FStartupHeight);

    if FDisplayModeChanged then
      SetBounds(0, 0, FStartupWidth, FStartupHeight)
    else
    begin
      TargetMonitor := Screen.PrimaryMonitor;
      SetBounds(TargetMonitor.Left, TargetMonitor.Top, TargetMonitor.Width,
        TargetMonitor.Height);
    end;
    Exit;
  end;

  BorderStyle := bsSizeable;
  WindowState := wsNormal;
  if START_MAXIMIZED then
    WindowState := wsMaximized;
end;

procedure TGameForm.RestoreDisplayMode;
begin
  if not FDisplayModeChanged then
    Exit;

  ChangeDisplaySettings(PDeviceMode(nil), 0);
  FDisplayModeChanged := False;
  LogLine('Display mode restored.');
end;

destructor TGameForm.Destroy;
begin
  ShutdownGame;
  inherited Destroy;
end;

procedure TGameForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);

  { CreateNew/no-DFM forms can otherwise behave like owned tool windows.
    Keep the game host as a normal taskbar application window. }
  Params.WndParent := 0;
  Params.ExStyle := Params.ExStyle or WS_EX_APPWINDOW;
end;

procedure TGameForm.InitializeGame;
var
  EngineSettings: TEngineSettings;
begin
  FLog := TStringList.Create;
  LogLine('Starting OGLM_Game.');
  if FStartFullScreen then
    LogLine('Window mode: fullscreen.')
  else
    LogLine('Window mode: windowed.');
  if FStartupResolutionSpecified then
    LogLine(Format('Requested resolution: %dx%d.', [FStartupWidth,
      FStartupHeight]));
  if FDisplayModeStatus <> '' then
    LogLine(FDisplayModeStatus);
  LogLine(Format('Active client size: %dx%d.', [ClientWidth, ClientHeight]));

  EngineSettings := TEngineSettings.Default;
  EngineSettings.Width := ClientWidth;
  EngineSettings.Height := ClientHeight;
  EngineSettings.AntialiasingSamples := DEFAULT_ANTIALIASING_SAMPLES;

  FEngine := TGameEngine.Create(Self, EngineSettings);
  LogLine('Engine and renderer initialized.');

  LoadStartupScene;
end;

procedure TGameForm.ShutdownGame;
begin
  FGameStartPending := False;
  StopGameLoop;
  ReleaseCapture;

  if Assigned(FEngine) then
    FEngine.ActivateRenderContext;

  FreeAndNil(FEngine);
  RestoreDisplayMode;

  if Assigned(FLog) then
  begin
    try
      FLog.SaveToFile(TPath.Combine(ExtractFilePath(Application.ExeName),
        'OGLM_Game.log'));
    except
      { Do not raise while the game form is being destroyed. }
    end;
    FreeAndNil(FLog);
  end;
end;

procedure TGameForm.StartGameAfterShow;
begin
  if (FEngine = nil) or Application.Terminated or (FTimer <> nil) then
    Exit;

  FEngine.Resize(ClientWidth, ClientHeight);
  FEngine.Render;
  StartGameLoop;
  if FStartFullScreen and NudgeMouseCursor then
    LogLine('Mouse cursor nudged after fullscreen startup.');
end;

procedure TGameForm.StartGameLoop;
begin
  if FTimer <> nil then
    Exit;

  FTimer := TEngineTimer.Create;
  FTimer.Enabled := False;
  FTimer.Mode := tmASAP;
  FTimer.MaxDeltaTime := 0.1;
  FTimer.OnProgress := GameProgress;
  FTimer.Enabled := True;
  LogLine('Game loop started using ASAP updates.');
end;

procedure TGameForm.StopGameLoop;
begin
  if FTimer = nil then
    Exit;

  FTimer.Enabled := False;
  FTimer.OnProgress := nil;
  FreeAndNil(FTimer);
  LogLine('Game loop stopped.');
end;

function TGameForm.NudgeMouseCursor: Boolean;
var
  CursorPosition: TPoint;
  VirtualLeft: Integer;
  VirtualTop: Integer;
  VirtualRight: Integer;
  VirtualBottom: Integer;
begin
  Result := False;
  if not GetCursorPos(CursorPosition) then
    Exit;

  VirtualLeft := GetSystemMetrics(SM_XVIRTUALSCREEN);
  VirtualTop := GetSystemMetrics(SM_YVIRTUALSCREEN);
  VirtualRight := VirtualLeft + GetSystemMetrics(SM_CXVIRTUALSCREEN) - 1;
  VirtualBottom := VirtualTop + GetSystemMetrics(SM_CYVIRTUALSCREEN) - 1;

  if CursorPosition.X < VirtualRight then
    Result := SetCursorPos(CursorPosition.X + 1, CursorPosition.Y)
  else if CursorPosition.X > VirtualLeft then
    Result := SetCursorPos(CursorPosition.X - 1, CursorPosition.Y)
  else if CursorPosition.Y < VirtualBottom then
    Result := SetCursorPos(CursorPosition.X, CursorPosition.Y + 1)
  else if CursorPosition.Y > VirtualTop then
    Result := SetCursorPos(CursorPosition.X, CursorPosition.Y - 1);
end;

procedure TGameForm.LoadStartupScene;
var
  SceneFileName: string;
begin
  SceneFileName := NormalizeSceneArgument(StartupSceneArgument);

  if SceneFileName = '' then
  begin
    LogLine('No startup scene argument supplied; using engine default scene.');
    Exit;
  end;

  try
    FEngine.LoadSceneFromFile(SceneFileName);
    FCurrentScene := SceneFileName;
    Caption := Format('%s - %s', [GAME_TITLE, ExtractFileName(SceneFileName)]);
    LogLine('Loaded startup scene: ' + SceneFileName);
  except
    on E: Exception do
    begin
      LogLine('Failed to load startup scene "' + SceneFileName + '": ' +
        E.Message);
      Application.MessageBox(PChar('Failed to load scene:' + sLineBreak +
        SceneFileName + sLineBreak + sLineBreak + E.Message), 'OGLM_Game',
        MB_ICONERROR or MB_OK);
      Application.Terminate;
    end;
  end;
end;

function TGameForm.StartupSceneArgument: string;
var
  I: Integer;
  Arg: string;
begin
  Result := DEFAULT_ENTRY_SCENE;
  I := 1;
  while I <= ParamCount do
  begin
    Arg := Trim(ParamStr(I));

    if Arg = '' then
    begin
      Inc(I);
      Continue;
    end;

    if SameText(Arg, '--scene') or SameText(Arg, '-scene') or
       SameText(Arg, '/scene') then
    begin
      if I < ParamCount then
        Exit(ParamStr(I + 1));
      Exit('');
    end;

    if StartsText('--scene=', Arg) then
      Exit(Copy(Arg, Length('--scene=') + 1, MaxInt));
    if StartsText('-scene=', Arg) then
      Exit(Copy(Arg, Length('-scene=') + 1, MaxInt));
    if StartsText('/scene:', Arg) then
      Exit(Copy(Arg, Length('/scene:') + 1, MaxInt));
    if StartsText('/scene=', Arg) then
      Exit(Copy(Arg, Length('/scene=') + 1, MaxInt));

    if IsWindowModeArgument(Arg) then
    begin
      Inc(I);
      Continue;
    end;

    if IsResolutionArgument(Arg) then
    begin
      if IsResolutionSwitch(Arg) or IsWidthSwitch(Arg) or IsHeightSwitch(Arg) then
        Inc(I);
      Inc(I);
      Continue;
    end;

    { The first non-switch argument is treated as the scene file. This keeps
      the common workflow short: OGLM_Game.exe MainMenu.omescn }
    if (not StartsText('-', Arg)) and (not StartsText('/', Arg)) then
      Exit(Arg);

    Inc(I);
  end;
end;

function TGameForm.StartupResolutionArgument(var AWidth,
  AHeight: Integer): Boolean;
var
  I: Integer;
  Arg: string;
  SwitchValue: string;
  ParsedWidth: Integer;
  ParsedHeight: Integer;
begin
  Result := False;
  I := 1;
  while I <= ParamCount do
  begin
    Arg := StripArgumentQuotes(Trim(ParamStr(I)));
    if Arg = '' then
    begin
      Inc(I);
      Continue;
    end;

    if IsResolutionSwitch(Arg) then
    begin
      if (I < ParamCount) and TryParseResolution(ParamStr(I + 1),
        ParsedWidth, ParsedHeight) then
      begin
        AWidth := ParsedWidth;
        AHeight := ParsedHeight;
        Result := True;
      end;
      Inc(I, 2);
      Continue;
    end;

    SwitchValue := ExtractSwitchValue(Arg, '--resolution');
    if SwitchValue = '' then
      SwitchValue := ExtractSwitchValue(Arg, '-resolution');
    if SwitchValue = '' then
      SwitchValue := ExtractSwitchValue(Arg, '/resolution');
    if SwitchValue = '' then
      SwitchValue := ExtractSwitchValue(Arg, '--res');
    if SwitchValue = '' then
      SwitchValue := ExtractSwitchValue(Arg, '-res');
    if SwitchValue = '' then
      SwitchValue := ExtractSwitchValue(Arg, '/res');

    if (SwitchValue <> '') and TryParseResolution(SwitchValue, ParsedWidth,
      ParsedHeight) then
    begin
      AWidth := ParsedWidth;
      AHeight := ParsedHeight;
      Result := True;
      Inc(I);
      Continue;
    end;

    if IsWidthSwitch(Arg) then
    begin
      if (I < ParamCount) and TryParsePositiveInteger(ParamStr(I + 1),
        ParsedWidth) then
      begin
        AWidth := ParsedWidth;
        Result := True;
      end;
      Inc(I, 2);
      Continue;
    end;

    if IsHeightSwitch(Arg) then
    begin
      if (I < ParamCount) and TryParsePositiveInteger(ParamStr(I + 1),
        ParsedHeight) then
      begin
        AHeight := ParsedHeight;
        Result := True;
      end;
      Inc(I, 2);
      Continue;
    end;

    SwitchValue := ExtractSwitchValue(Arg, '--width');
    if SwitchValue = '' then
      SwitchValue := ExtractSwitchValue(Arg, '-width');
    if SwitchValue = '' then
      SwitchValue := ExtractSwitchValue(Arg, '/width');
    if (SwitchValue <> '') and TryParsePositiveInteger(SwitchValue,
      ParsedWidth) then
    begin
      AWidth := ParsedWidth;
      Result := True;
      Inc(I);
      Continue;
    end;

    SwitchValue := ExtractSwitchValue(Arg, '--height');
    if SwitchValue = '' then
      SwitchValue := ExtractSwitchValue(Arg, '-height');
    if SwitchValue = '' then
      SwitchValue := ExtractSwitchValue(Arg, '/height');
    if (SwitchValue <> '') and TryParsePositiveInteger(SwitchValue,
      ParsedHeight) then
    begin
      AHeight := ParsedHeight;
      Result := True;
      Inc(I);
      Continue;
    end;

    Inc(I);
  end;

  ClampStartupResolution(AWidth, AHeight);
end;

function TGameForm.StartupFullScreenArgument: Boolean;
var
  I: Integer;
  Arg: string;
begin
  Result := START_FULLSCREEN;

  for I := 1 to ParamCount do
  begin
    Arg := StripArgumentQuotes(Trim(ParamStr(I)));
    if Arg = '' then
      Continue;

    if IsFullScreenSwitch(Arg) then
    begin
      Result := True;
      Continue;
    end;

    if IsWindowedSwitch(Arg) then
    begin
      Result := False;
      Continue;
    end;

    if StartsText('--fullscreen=', Arg) then
      Result := BooleanSwitchValue(Copy(Arg, Length('--fullscreen=') + 1,
        MaxInt), True)
    else if StartsText('-fullscreen=', Arg) then
      Result := BooleanSwitchValue(Copy(Arg, Length('-fullscreen=') + 1,
        MaxInt), True)
    else if StartsText('--full-screen=', Arg) then
      Result := BooleanSwitchValue(Copy(Arg, Length('--full-screen=') + 1,
        MaxInt), True)
    else if StartsText('-full-screen=', Arg) then
      Result := BooleanSwitchValue(Copy(Arg, Length('-full-screen=') + 1,
        MaxInt), True)
    else if StartsText('/fullscreen:', Arg) then
      Result := BooleanSwitchValue(Copy(Arg, Length('/fullscreen:') + 1,
        MaxInt), True)
    else if StartsText('/fullscreen=', Arg) then
      Result := BooleanSwitchValue(Copy(Arg, Length('/fullscreen=') + 1,
        MaxInt), True);
  end;
end;

function TGameForm.BooleanSwitchValue(const AValue: string;
  ADefault: Boolean): Boolean;
var
  Value: string;
begin
  Value := LowerCase(StripArgumentQuotes(Trim(AValue)));

  if (Value = '') then
    Exit(ADefault);
  if (Value = '1') or (Value = 'true') or (Value = 'yes') or
     (Value = 'on') then
    Exit(True);
  if (Value = '0') or (Value = 'false') or (Value = 'no') or
     (Value = 'off') then
    Exit(False);

  Result := ADefault;
end;

function TGameForm.ExtractSwitchValue(const AArg, ASwitch: string): string;
var
  Prefix: string;
begin
  Result := '';

  Prefix := ASwitch + '=';
  if StartsText(Prefix, AArg) then
    Exit(Copy(AArg, Length(Prefix) + 1, MaxInt));

  Prefix := ASwitch + ':';
  if StartsText(Prefix, AArg) then
    Exit(Copy(AArg, Length(Prefix) + 1, MaxInt));
end;

function TGameForm.IsFullScreenSwitch(const AArg: string): Boolean;
begin
  Result := SameText(AArg, '--fullscreen') or
    SameText(AArg, '-fullscreen') or
    SameText(AArg, '/fullscreen') or
    SameText(AArg, '--full-screen') or
    SameText(AArg, '-full-screen') or
    SameText(AArg, '/full-screen') or
    SameText(AArg, '--fs') or
    SameText(AArg, '-fs') or
    SameText(AArg, '/fs');
end;

function TGameForm.IsWindowedSwitch(const AArg: string): Boolean;
begin
  Result := SameText(AArg, '--window') or
    SameText(AArg, '-window') or
    SameText(AArg, '/window') or
    SameText(AArg, '--windowed') or
    SameText(AArg, '-windowed') or
    SameText(AArg, '/windowed') or
    SameText(AArg, '--no-fullscreen') or
    SameText(AArg, '-no-fullscreen') or
    SameText(AArg, '/no-fullscreen');
end;

function TGameForm.IsWindowModeArgument(const AArg: string): Boolean;
begin
  Result := IsFullScreenSwitch(AArg) or IsWindowedSwitch(AArg) or
    StartsText('--fullscreen=', AArg) or
    StartsText('-fullscreen=', AArg) or
    StartsText('--full-screen=', AArg) or
    StartsText('-full-screen=', AArg) or
    StartsText('/fullscreen:', AArg) or
    StartsText('/fullscreen=', AArg);
end;

function TGameForm.IsResolutionSwitch(const AArg: string): Boolean;
begin
  Result := SameText(AArg, '--resolution') or
    SameText(AArg, '-resolution') or
    SameText(AArg, '/resolution') or
    SameText(AArg, '--res') or
    SameText(AArg, '-res') or
    SameText(AArg, '/res');
end;

function TGameForm.IsResolutionArgument(const AArg: string): Boolean;
begin
  Result := IsResolutionSwitch(AArg) or IsWidthSwitch(AArg) or
    IsHeightSwitch(AArg) or
    StartsText('--resolution=', AArg) or
    StartsText('-resolution=', AArg) or
    StartsText('/resolution:', AArg) or
    StartsText('/resolution=', AArg) or
    StartsText('--res=', AArg) or
    StartsText('-res=', AArg) or
    StartsText('/res:', AArg) or
    StartsText('/res=', AArg) or
    StartsText('--width=', AArg) or
    StartsText('-width=', AArg) or
    StartsText('/width:', AArg) or
    StartsText('/width=', AArg) or
    StartsText('--height=', AArg) or
    StartsText('-height=', AArg) or
    StartsText('/height:', AArg) or
    StartsText('/height=', AArg);
end;

function TGameForm.IsWidthSwitch(const AArg: string): Boolean;
begin
  Result := SameText(AArg, '--width') or SameText(AArg, '-width') or
    SameText(AArg, '/width');
end;

function TGameForm.IsHeightSwitch(const AArg: string): Boolean;
begin
  Result := SameText(AArg, '--height') or SameText(AArg, '-height') or
    SameText(AArg, '/height');
end;

function TGameForm.TryParseResolution(const AValue: string; out AWidth,
  AHeight: Integer): Boolean;
var
  Value: string;
  DelimPos: Integer;
begin
  Value := LowerCase(StripArgumentQuotes(Trim(AValue)));
  Value := StringReplace(Value, ' ', '', [rfReplaceAll]);
  Value := StringReplace(Value, '*', 'x', [rfReplaceAll]);
  Value := StringReplace(Value, ',', 'x', [rfReplaceAll]);

  DelimPos := Pos('x', Value);
  Result := (DelimPos > 1) and
    TryParsePositiveInteger(Copy(Value, 1, DelimPos - 1), AWidth) and
    TryParsePositiveInteger(Copy(Value, DelimPos + 1, MaxInt), AHeight);
end;

function TGameForm.TryParsePositiveInteger(const AValue: string;
  out AValueInt: Integer): Boolean;
begin
  Result := TryStrToInt(StripArgumentQuotes(Trim(AValue)), AValueInt) and
    (AValueInt > 0);
end;

function TGameForm.TryApplyFullScreenResolution(AWidth,
  AHeight: Integer): Boolean;
var
  DevMode: TDeviceMode;
  ChangeResult: Longint;
begin
  FillChar(DevMode, SizeOf(DevMode), 0);
  DevMode.dmSize := SizeOf(DevMode);

  DevMode.dmFields := DM_PELSWIDTH or DM_PELSHEIGHT;
  DevMode.dmPelsWidth := DWORD(AWidth);
  DevMode.dmPelsHeight := DWORD(AHeight);

  ChangeResult := ChangeDisplaySettings(DevMode, CDS_FULLSCREEN);
  Result := ChangeResult = DISP_CHANGE_SUCCESSFUL;

  if Result then
    FDisplayModeStatus := Format('Fullscreen display mode: %dx%d.',
      [AWidth, AHeight])
  else
    FDisplayModeStatus := Format(
      'Fullscreen display mode %dx%d unavailable (%s); using desktop resolution.',
      [AWidth, AHeight, DisplayChangeResultText(ChangeResult)]);
end;

function TGameForm.DisplayChangeResultText(AResult: Longint): string;
begin
  case AResult of
    DISP_CHANGE_SUCCESSFUL:
      Result := 'success';
    DISP_CHANGE_RESTART:
      Result := 'restart required';
    DISP_CHANGE_FAILED:
      Result := 'display driver failed the mode change';
    DISP_CHANGE_BADMODE:
      Result := 'unsupported display mode';
    DISP_CHANGE_NOTUPDATED:
      Result := 'registry was not updated';
    DISP_CHANGE_BADFLAGS:
      Result := 'invalid display flags';
    DISP_CHANGE_BADPARAM:
      Result := 'invalid display parameters';
  else
    Result := 'display error ' + IntToStr(AResult);
  end;
end;

procedure TGameForm.ClampStartupResolution(var AWidth, AHeight: Integer);
begin
  if AWidth < MIN_STARTUP_WIDTH then
    AWidth := MIN_STARTUP_WIDTH;
  if AHeight < MIN_STARTUP_HEIGHT then
    AHeight := MIN_STARTUP_HEIGHT;
end;

function TGameForm.NormalizeSceneArgument(const AScene: string): string;
var
  Candidate: string;
begin
  Candidate := StripArgumentQuotes(Trim(AScene));
  if Candidate = '' then
    Exit('');

  if TPath.IsPathRooted(Candidate) then
    Exit(Candidate);

  { Bare names are intentionally left bare so TGameEngine resolves them into
    Data\Scenes and appends .omescn when needed. Relative paths are rooted at
    the executable directory, allowing "Data\Scenes\Scene.omescn" as a run arg. }
  if (Pos('\', Candidate) > 0) or (Pos('/', Candidate) > 0) then
    Exit(TPath.GetFullPath(TPath.Combine(ExtractFilePath(Application.ExeName),
      Candidate)));

  Result := Candidate;
end;

function TGameForm.StripArgumentQuotes(const AValue: string): string;
begin
  Result := AValue;
  if Length(Result) < 2 then
    Exit;

  if ((Result[1] = '"') and (Result[Length(Result)] = '"')) or
     ((Result[1] = '''') and (Result[Length(Result)] = '''')) then
    Result := Copy(Result, 2, Length(Result) - 2);
end;

procedure TGameForm.LogLine(const AText: string);
begin
  if FLog = nil then
    Exit;

  FLog.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + AText);
end;

procedure TGameForm.FormShowHandler(Sender: TObject);
begin
  if (FEngine = nil) or Application.Terminated or (FTimer <> nil) or
    FGameStartPending then
    Exit;

  if PostMessage(Handle, WM_OGLM_START_GAME, 0, 0) then
    FGameStartPending := True
  else
    StartGameAfterShow;
end;

procedure TGameForm.WMStartGame(var Message: TMessage);
begin
  Message.Result := 0;
  FGameStartPending := False;

  if csDestroying in ComponentState then
    Exit;

  StartGameAfterShow;
end;

procedure TGameForm.GameProgress(Sender: TObject; const DeltaTime,
  NewTime: Double);
begin
  if FEngine = nil then
    Exit;

  try
    FEngine.Update(DeltaTime, NewTime);

    if FEngine.LastScriptLifecycleError <> FLastScriptError then
    begin
      FLastScriptError := FEngine.LastScriptLifecycleError;
      if FLastScriptError <> '' then
        LogLine('Script lifecycle error: ' + FLastScriptError);
    end;

    FEngine.Render;
  except
    on E: Exception do
    begin
      LogLine('Frame error: ' + E.Message);
      raise;
    end;
  end;
end;

procedure TGameForm.FormResizeHandler(Sender: TObject);
begin
  if FEngine = nil then
    Exit;

  FEngine.Resize(ClientWidth, ClientHeight);
  FEngine.Render;
end;

procedure TGameForm.FormPaintHandler(Sender: TObject);
begin
  if FEngine <> nil then
    FEngine.Render;
end;

procedure TGameForm.FormMouseDownHandler(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if (FEngine <> nil) and FEngine.GuiMouseDown(Button, Shift, X, Y) then
  begin
    SetCapture(Handle);
    FEngine.Render;
  end;
end;

procedure TGameForm.FormMouseMoveHandler(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
begin
  if (FEngine <> nil) and FEngine.GuiMouseMove(Shift, X, Y) then
    FEngine.Render;
end;

procedure TGameForm.FormMouseUpHandler(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if (FEngine <> nil) and FEngine.GuiMouseUp(Button, Shift, X, Y) then
  begin
    ReleaseCapture;
    FEngine.Render;
  end;
end;

procedure TGameForm.FormKeyDownHandler(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (FEngine <> nil) and FEngine.GuiKeyDown(Key, Shift) then
  begin
    Key := 0;
    FEngine.Render;
  end;
end;

procedure TGameForm.FormKeyPressHandler(Sender: TObject; var Key: Char);
begin
  if (FEngine <> nil) and FEngine.GuiKeyPress(Key) then
  begin
    Key := #0;
    FEngine.Render;
  end;
end;

procedure TGameForm.FormKeyUpHandler(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (FEngine <> nil) and FEngine.GuiKeyUp(Key, Shift) then
  begin
    Key := 0;
    FEngine.Render;
  end;
end;

procedure TGameForm.FormCloseHandler(Sender: TObject; var Action: TCloseAction);
begin
  ReleaseCapture;
  StopGameLoop;
end;

end.
