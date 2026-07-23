unit Engine.Time;

(* Time-based progression manager for custom OpenGL engines.
   No VCL component dependencies, no GLScene types, just a plain class. *)

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.Classes,
  System.SysUtils,
  System.Types,
  Vcl.Forms;

type
  // Event signature used by OnProgress and OnTotalProgress.
  TProgressEvent = procedure(Sender: TObject; const deltaTime, newTime: Double) of object;

  // How the cadencer triggers progress:
  //   tmManual        – you call Progress manually
  //   tmASAP          – Windows message loop drives progress
  //   tmApplicationIdle – hooks VCL’s Application.OnIdle
  TTimerMode = (tmManual, tmASAP, tmApplicationIdle);

  // Which time source to use:
  //   trRTC               – Real Time Clock (low resolution)
  //   trPerformanceCounter – high precision performance counter
  //   trExternal          – you supply CurrentTime manually
  TTimerTimeReference = (trRTC, trPerformanceCounter, trExternal);

  TEngineTimer = class
  private
    fEnabled: Boolean;
    fTimeMultiplier: Double;
    fOriginTime: Double;
    fCurrentTime: Double;
    fLastTime: Double;          // last time used for delta calculation
    fDownTime: Double;          // used when toggling Enabled
    fLastMultiplier: Double;    // for smooth multiplier changes
    fMode: TTimerMode;
    fTimeReference: TTimerTimeReference;
    fMaxDeltaTime: Double;
    fMinDeltaTime: Double;
    fFixedDeltaTime: Double;
    fSleepLength: Integer;
    fOnProgress: TProgressEvent;
    fOnTotalProgress: TProgressEvent;
    fProgressing: Integer;      // recursion guard (negative when inside OnProgress)

    procedure SetEnabled(const Value: Boolean);
    procedure SetTimeMultiplier(const Value: Double);
    procedure SetMode(const Value: TTimerMode);
    procedure SetTimeReference(const Value: TTimerTimeReference);
    function GetRawReferenceTime: Double;
    procedure RestartASAP;
    procedure OnIdleEvent(Sender: TObject; var Done: Boolean);
  public
    constructor Create;
    destructor Destroy; override;

    // Manual call to advance time. Usually you only call this in tmManual mode,
    // but it can be used in any mode to force a progress step.
    procedure Progress;

    // Returns the current progression time (OriginTime-adjusted and multiplied).
    function GetCurrentTime: Double; inline;

    // Resets OriginTime so that current progression time becomes zero.
    procedure Reset;

    // True if a Progress call is currently active (prevents re-entrancy).
    function IsBusy: Boolean;

    // Current raw time (unadjusted, no multiplier) used for calculations.
    property CurrentTime: Double read fCurrentTime;

    // Origin subtracted from raw time before multiplication.
    property OriginTime: Double read fOriginTime write fOriginTime;

    // Enables / pauses the cadencer (keeps time continuity).
    property Enabled: Boolean read fEnabled write SetEnabled default True;

    // Multiplier applied to the raw delta time. Negative values are allowed.
    property TimeMultiplier: Double read fTimeMultiplier write SetTimeMultiplier;

    // Maximum allowed delta time per progress call. Negative = no limit.
    property MaxDeltaTime: Double read fMaxDeltaTime write fMaxDeltaTime;

    // Minimum delta time required to fire a progress event.
    property MinDeltaTime: Double read fMinDeltaTime write fMinDeltaTime;

    // Fixed timestep: when > 0, several progress calls may be issued per real frame.
    property FixedDeltaTime: Double read fFixedDeltaTime write fFixedDeltaTime;

    // Millisecond sleep before each progress (-1 = no sleep).
    property SleepLength: Integer read fSleepLength write fSleepLength default -1;

    // How the cadencer is triggered.
    property Mode: TTimerMode read fMode write SetMode default tmASAP;

    // Time source (RTC, performance counter, or external).
    property TimeReference: TTimerTimeReference read fTimeReference write SetTimeReference default trPerformanceCounter;

    // Called after each individual step (when FixedDeltaTime is used, may be called several times).
    property OnProgress: TProgressEvent read fOnProgress write fOnProgress;

    // Called after all steps for a real frame have been processed.
    property OnTotalProgress: TProgressEvent read fOnTotalProgress write fOnTotalProgress;
  end;

implementation

const
  cTickGLCadencer = 'TickGLCadencer';

type
  TASAPHandler = class
  private
    FTooFastCounter: Integer;
    FTimer: Cardinal;
    FWindowHandle: HWND;
    procedure WndProc(var Msg: TMessage);
  public
    constructor Create;
    destructor Destroy; override;
  end;

var
  // Global list of cadencers that use tmASAP mode.
  vASAPCadencerList: TList = nil;
  // Hidden window that drives the ASAP messages.
  vASAPHandler: TASAPHandler = nil;
  // Frequency of the high-resolution performance counter.
  vCounterFrequency: Int64 = 0;
  // Cached message ID for our custom window message.
  vWMTickCadencer: Cardinal = 0;

{ Helper functions for global registration }

function GetWMTickCadencer: Cardinal;
begin
  if vWMTickCadencer = 0 then
    vWMTickCadencer := RegisterWindowMessage(cTickGLCadencer);
  Result := vWMTickCadencer;
end;

procedure RegisterASAPCadencer(aCadencer: TEngineTimer);
begin
  if aCadencer.Mode <> tmASAP then
    Exit;
  if not Assigned(vASAPCadencerList) then
    vASAPCadencerList := TList.Create;
  if vASAPCadencerList.IndexOf(aCadencer) < 0 then
  begin
    vASAPCadencerList.Add(aCadencer);
    if not Assigned(vASAPHandler) then
      vASAPHandler := TASAPHandler.Create;
  end;
end;

procedure UnregisterASAPCadencer(aCadencer: TEngineTimer);
var
  i: Integer;
begin
  if aCadencer.Mode <> tmASAP then
    Exit;
  if Assigned(vASAPCadencerList) then
  begin
    i := vASAPCadencerList.IndexOf(aCadencer);
    if i >= 0 then
      vASAPCadencerList[i] := nil;
  end;
end;

procedure CleanupASAP;
begin
  if Assigned(vASAPCadencerList) then
  begin
    vASAPCadencerList.Pack;
    if vASAPCadencerList.Count = 0 then
    begin
      FreeAndNil(vASAPCadencerList);
      FreeAndNil(vASAPHandler);
    end;
  end;
end;

{ TASAPHandler }
constructor TASAPHandler.Create;
begin
  inherited Create;
  FWindowHandle := AllocateHWnd(WndProc);
  PostMessage(FWindowHandle, GetWMTickCadencer, 0, 0);
end;

destructor TASAPHandler.Destroy;
begin
  if FTimer <> 0 then
    KillTimer(FWindowHandle, FTimer);
  DeallocateHWnd(FWindowHandle);
  inherited;
end;

var
  vWndProcInLoop: Boolean = False;

procedure TASAPHandler.WndProc(var Msg: TMessage);
var
  i: Integer;
  cad: TEngineTimer;
begin
  with Msg do
  begin
    if Msg = WM_TIMER then
    begin
      KillTimer(FWindowHandle, FTimer);
      FTimer := 0;
    end;
    if (Msg <> WM_TIMER) and (Cardinal(GetMessageTime) = GetTickCount) then
    begin
      Inc(FTooFastCounter);
      if FTooFastCounter > 5000 then
      begin
        if FTimer = 0 then
          FTimer := SetTimer(FWindowHandle, 1, 1, nil);
        FTooFastCounter := 0;
      end;
    end
    else
      FTooFastCounter := 0;
    if FTimer <> 0 then
    begin
      Result := 0;
      Exit;
    end;
    if not vWndProcInLoop then
    begin
      vWndProcInLoop := True;
      try
        if (Msg = GetWMTickCadencer) or (Msg = WM_TIMER) then
        begin
          // Iterate backwards because cadencers may be removed
          for i := vASAPCadencerList.Count - 1 downto 0 do
          begin
            cad := TEngineTimer(vASAPCadencerList[i]);
            if Assigned(cad) and (cad.Mode = tmASAP) and cad.Enabled and (cad.fProgressing = 0) then
            begin
              if Application.Terminated then
                cad.Enabled := False
              else
              begin
                try
                  cad.Progress;
                except
                  Application.HandleException(Self);
                  cad.Enabled := False;
                end;
              end;
            end;
          end;
          CleanupASAP;
          if Assigned(vASAPCadencerList) then
            PostMessage(FWindowHandle, GetWMTickCadencer, 0, 0);
        end;
      finally
        vWndProcInLoop := False;
      end;
    end;
    Result := 0;
  end;
end;

{ TEngineTimer }

constructor TEngineTimer.Create;
begin
  inherited Create;
  fTimeReference := trPerformanceCounter;
  fDownTime := GetRawReferenceTime;
  fOriginTime := fDownTime;
  fTimeMultiplier := 1;
  fSleepLength := -1;
  fMode := tmASAP;
  fEnabled := True;
  // Ensure performance counter frequency is read
  if vCounterFrequency = 0 then
    if not QueryPerformanceFrequency(vCounterFrequency) then
      vCounterFrequency := 0;
end;

destructor TEngineTimer.Destroy;
begin
  Assert(fProgressing = 0);
  if fMode = tmASAP then
    UnregisterASAPCadencer(Self)
  else if fMode = tmApplicationIdle then
    Application.OnIdle := nil;
  inherited;
end;

procedure TEngineTimer.SetEnabled(const Value: Boolean);
begin
  if fEnabled <> Value then
  begin
    fEnabled := Value;
    if fEnabled then
      fOriginTime := fOriginTime + GetRawReferenceTime - fDownTime
    else
      fDownTime := GetRawReferenceTime;
    RestartASAP;
  end;
end;

procedure TEngineTimer.SetTimeMultiplier(const Value: Double);
var
  rawRef: Double;
begin
  if Value = fTimeMultiplier then
    Exit;
  if Value = 0 then
  begin
    fLastMultiplier := fTimeMultiplier;
    Enabled := False;
  end
  else
  begin
    rawRef := GetRawReferenceTime;
    if fTimeMultiplier = 0 then
    begin
      Enabled := True;
      fOriginTime := rawRef - (rawRef - fOriginTime) * fLastMultiplier / Value;
    end
    else
      fOriginTime := rawRef - (rawRef - fOriginTime) * fTimeMultiplier / Value;
  end;
  fTimeMultiplier := Value;
end;

procedure TEngineTimer.SetMode(const Value: TTimerMode);
begin
  if fMode = Value then
    Exit;
  if fMode <> tmManual then
  begin
    if fMode = tmASAP then
      UnregisterASAPCadencer(Self)
    else if fMode = tmApplicationIdle then
      Application.OnIdle := nil;
  end;
  fMode := Value;
  RestartASAP;
end;

procedure TEngineTimer.SetTimeReference(const Value: TTimerTimeReference);
begin
  fTimeReference := Value;
  // No additional action needed, the next GetRawReferenceTime will use the new source.
end;

procedure TEngineTimer.RestartASAP;
begin
  if (fMode in [tmASAP, tmApplicationIdle]) and fEnabled then
  begin
    if fMode = tmASAP then
      RegisterASAPCadencer(Self)
    else // tmApplicationIdle
      Application.OnIdle := OnIdleEvent;
  end
  else
  begin
    if fMode = tmASAP then
      UnregisterASAPCadencer(Self)
    else if fMode = tmApplicationIdle then
      Application.OnIdle := nil;
  end;
end;

procedure TEngineTimer.OnIdleEvent(Sender: TObject; var Done: Boolean);
begin
  Progress;
  Done := False;
end;

function TEngineTimer.GetRawReferenceTime: Double;
var
  counter: Int64;
begin
  case fTimeReference of
    trRTC:
      Result := Now * 86400.0;   // 3600*24
    trPerformanceCounter:
      begin
        if vCounterFrequency = 0 then
          Result := 0
        else
        begin
          QueryPerformanceCounter(counter);
          Result := counter / vCounterFrequency;
        end;
      end;
    trExternal:
      Result := fCurrentTime;
  else
    Result := 0;
  end;
end;

function TEngineTimer.GetCurrentTime: Double;
begin
  Result := (GetRawReferenceTime - fOriginTime) * fTimeMultiplier;
  fCurrentTime := Result;
end;

function TEngineTimer.IsBusy: Boolean;
begin
  Result := fProgressing <> 0;
end;

procedure TEngineTimer.Reset;
begin
  fLastTime := 0;
  fDownTime := GetRawReferenceTime;
  fOriginTime := fDownTime;
end;

procedure TEngineTimer.Progress;
var
  deltaTime, newTime, totalDelta, fullTotalDelta, firstLastTime: Double;
  fixedStep: Double;
begin
  if (fProgressing < 0) or (not fEnabled) then
    Exit;

  if fSleepLength >= 0 then
    Sleep(fSleepLength);

  if fMode = tmASAP then
  begin
    Application.ProcessMessages;
    if not Assigned(vASAPCadencerList) or (vASAPCadencerList.IndexOf(Self) < 0) then
      Exit;
  end;

  Inc(fProgressing);
  try
    if not fEnabled then
      Exit;

    newTime := GetCurrentTime;
    deltaTime := newTime - fLastTime;

    // Minimum delta time check
    if deltaTime < fMinDeltaTime then
    begin
      // Store the new time but do not fire events
      if deltaTime > 0 then
        fLastTime := newTime;
      Exit;
    end;

    // Fixed timestep handling
    if fFixedDeltaTime > 0 then
      fixedStep := fFixedDeltaTime
    else
      fixedStep := deltaTime;

    totalDelta := deltaTime;
    fullTotalDelta := totalDelta;
    firstLastTime := fLastTime;

    // Clamp maximum delta time if requested
    if (fMaxDeltaTime > 0) and (totalDelta > fMaxDeltaTime) then
    begin
      fOriginTime := fOriginTime + (totalDelta - fMaxDeltaTime) / fTimeMultiplier;
      totalDelta := fMaxDeltaTime;
      newTime := fLastTime + totalDelta;
    end;

    // Process steps (one or more if fixed timestep is used)
    while totalDelta >= fixedStep do
    begin
      fLastTime := fLastTime + fixedStep;

      // Fire OnProgress event for this step
      if Assigned(fOnProgress) then
      begin
        fProgressing := -fProgressing;   // mark as inside event
        try
          fOnProgress(Self, fixedStep, fLastTime);
        finally
          fProgressing := -fProgressing;
        end;
      end;

      totalDelta := totalDelta - fixedStep;
      if fixedStep <= 0 then
        Break;
    end;

    // Fire OnTotalProgress after all steps
    if Assigned(fOnTotalProgress) then
    begin
      fProgressing := -fProgressing;
      try
        fOnTotalProgress(Self, fullTotalDelta, firstLastTime);
      finally
        fProgressing := -fProgressing;
      end;
    end;
  finally
    Dec(fProgressing);
  end;
end;

end.
