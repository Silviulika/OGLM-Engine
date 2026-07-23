unit Engine.Audio;

interface

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.Generics.Collections, System.Math,
  bass;

type
  EBassAudioError = class(Exception);

  TBassPlaybackState = (
    bpsStopped,
    bpsPlaying,
    bpsPaused,
    bpsStalled,
    bpsPausedDevice,
    bpsUnknown
  );

  TBass3DMode = (
    b3dmNormal,
    b3dmRelative,
    b3dmOff
  );

  TBass3DVector = record
    X: Single;
    Y: Single;
    Z: Single;
    class function Create(AX, AY, AZ: Single): TBass3DVector; static;
  end;

  TBassAudioEngine = class;

  TBassSound = class
  private
    FOwner: TBassAudioEngine;
    FHandle: DWORD;
    FIsMusic: Boolean;
    FFileName: string;
    FLoop: Boolean;
    FSpatial: Boolean;
    FMutedAtMaxDistance: Boolean;
    function GetLengthSeconds: Double;
    function GetPositionSeconds: Double;
    function GetState: TBassPlaybackState;
    function GetVolume: Single;
    procedure SetLoop(const Value: Boolean);
    procedure SetPositionSeconds(const Value: Double);
    procedure SetVolume(const Value: Single);
    procedure EnsureHandle(const AAction: string);
  public
    constructor Create(AOwner: TBassAudioEngine; AHandle: DWORD;
      const AFileName: string; AIsMusic, ALoop: Boolean;
      ASpatial: Boolean = False; AMutedAtMaxDistance: Boolean = False);
    destructor Destroy; override;

    procedure Play(Restart: Boolean = False);
    procedure Pause;
    procedure Stop;
    function GetLevel(out Left, Right: Single): Boolean;
    procedure Set3DAttributes(AMode: TBass3DMode; AMinDistance,
      AMaxDistance: Single; AInsideConeAngle, AOutsideConeAngle,
      AOutsideVolume: Integer);
    procedure Set3DPosition(const APosition, AOrientation,
      AVelocity: TBass3DVector);

    property Handle: DWORD read FHandle;
    property FileName: string read FFileName;
    property IsMusic: Boolean read FIsMusic;
    property Loop: Boolean read FLoop write SetLoop;
    property Spatial: Boolean read FSpatial;
    property MutedAtMaxDistance: Boolean read FMutedAtMaxDistance;
    property LengthSeconds: Double read GetLengthSeconds;
    property PositionSeconds: Double read GetPositionSeconds write SetPositionSeconds;
    property State: TBassPlaybackState read GetState;
    property Volume: Single read GetVolume write SetVolume;
  end;

  TBassAudioEngine = class
  private
    FInitialized: Boolean;
    FInitializedFor3D: Boolean;
    FDevice: Integer;
    FFrequency: DWORD;
    FWindowHandle: HWND;
    FSounds: TObjectList<TBassSound>;
    class procedure RaiseLastError(const AAction: string); static;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Initialize(AWindowHandle: HWND = 0; ADevice: Integer = -1;
      AFrequency: DWORD = 44100; AFlags: DWORD = 0);
    procedure Initialize3D(AWindowHandle: HWND = 0; ADevice: Integer = -1;
      AFrequency: DWORD = 44100);
    procedure Shutdown;

    function LoadSound(const AFileName: string; ALoop: Boolean = False;
      ASpatial: Boolean = False; AMutedAtMaxDistance: Boolean = False): TBassSound;
    procedure FreeSound(var ASound: TBassSound);
    procedure ClearSounds;

    class function ErrorText(AErrorCode: Integer): string; static;
    class function LastErrorText: string; static;
    class function PlaybackStateText(AState: TBassPlaybackState): string; static;
    class function IsSupportedAudioFile(const AFileName: string): Boolean; static;

    function CPUUsage: Single;
    function MasterVolume: Single;
    procedure SetMasterVolume(AValue: Single);
    procedure Set3DFactors(ADistanceFactor, ARolloffFactor,
      ADopplerFactor: Single);
    procedure Get3DFactors(out ADistanceFactor, ARolloffFactor,
      ADopplerFactor: Single);
    procedure SetListener3D(const APosition, AVelocity, AFront,
      ATop: TBass3DVector);
    procedure Apply3D;

    property Initialized: Boolean read FInitialized;
    property InitializedFor3D: Boolean read FInitializedFor3D;
    property Device: Integer read FDevice;
    property Frequency: DWORD read FFrequency;
    property WindowHandle: HWND read FWindowHandle;
  end;

implementation

const
  BASS_UNICODE_FLAG = BASS_UNICODE;

function BassLoopFlag(ALoop: Boolean): DWORD;
begin
  if ALoop then
    Result := BASS_SAMPLE_LOOP
  else
    Result := 0;
end;

function Bass3DModeValue(AMode: TBass3DMode): Integer;
begin
  case AMode of
    b3dmRelative: Result := BASS_3DMODE_RELATIVE;
    b3dmOff: Result := BASS_3DMODE_OFF;
  else
    Result := BASS_3DMODE_NORMAL;
  end;
end;

function BassVector(const AVector: TBass3DVector): BASS_3DVECTOR;
begin
  Result.x := AVector.X;
  Result.y := AVector.Y;
  Result.z := AVector.Z;
end;

{ TBass3DVector }

class function TBass3DVector.Create(AX, AY, AZ: Single): TBass3DVector;
begin
  Result.X := AX;
  Result.Y := AY;
  Result.Z := AZ;
end;

{ TBassSound }

constructor TBassSound.Create(AOwner: TBassAudioEngine; AHandle: DWORD;
  const AFileName: string; AIsMusic, ALoop, ASpatial,
  AMutedAtMaxDistance: Boolean);
begin
  inherited Create;
  FOwner := AOwner;
  FHandle := AHandle;
  FFileName := AFileName;
  FIsMusic := AIsMusic;
  FLoop := ALoop;
  FSpatial := ASpatial;
  FMutedAtMaxDistance := AMutedAtMaxDistance;
end;

destructor TBassSound.Destroy;
begin
  if FHandle <> 0 then
  begin
    if FIsMusic then
      BASS_MusicFree(FHandle)
    else
      BASS_StreamFree(FHandle);
    FHandle := 0;
  end;

  inherited Destroy;
end;

procedure TBassSound.EnsureHandle(const AAction: string);
begin
  if FHandle = 0 then
    raise EBassAudioError.Create(AAction + ': no BASS channel is loaded.');
end;

function TBassSound.GetLengthSeconds: Double;
var
  Bytes: QWORD;
begin
  Result := 0.0;
  if FHandle = 0 then
    Exit;

  Bytes := BASS_ChannelGetLength(FHandle, BASS_POS_BYTE);
  if Bytes = High(QWORD) then
    Exit;

  Result := BASS_ChannelBytes2Seconds(FHandle, Bytes);
end;

function TBassSound.GetPositionSeconds: Double;
var
  Bytes: QWORD;
begin
  Result := 0.0;
  if FHandle = 0 then
    Exit;

  Bytes := BASS_ChannelGetPosition(FHandle, BASS_POS_BYTE);
  if Bytes = High(QWORD) then
    Exit;

  Result := BASS_ChannelBytes2Seconds(FHandle, Bytes);
end;

function TBassSound.GetState: TBassPlaybackState;
begin
  if FHandle = 0 then
    Exit(bpsStopped);

  case BASS_ChannelIsActive(FHandle) of
    BASS_ACTIVE_STOPPED: Result := bpsStopped;
    BASS_ACTIVE_PLAYING: Result := bpsPlaying;
    BASS_ACTIVE_STALLED: Result := bpsStalled;
    BASS_ACTIVE_PAUSED: Result := bpsPaused;
    BASS_ACTIVE_PAUSED_DEVICE: Result := bpsPausedDevice;
  else
    Result := bpsUnknown;
  end;
end;

function TBassSound.GetVolume: Single;
begin
  Result := 1.0;
  if FHandle = 0 then
    Exit;

  if not BASS_ChannelGetAttribute(FHandle, BASS_ATTRIB_VOL, Result) then
    Result := 1.0;
end;

procedure TBassSound.SetLoop(const Value: Boolean);
begin
  FLoop := Value;
  if FHandle <> 0 then
    BASS_ChannelFlags(FHandle, BassLoopFlag(FLoop), BASS_SAMPLE_LOOP);
end;

procedure TBassSound.SetPositionSeconds(const Value: Double);
var
  Bytes: QWORD;
begin
  EnsureHandle('Set playback position');
  Bytes := BASS_ChannelSeconds2Bytes(FHandle, Max(0.0, Value));
  if not BASS_ChannelSetPosition(FHandle, Bytes, BASS_POS_BYTE) then
    TBassAudioEngine.RaiseLastError('Set playback position');
end;

procedure TBassSound.SetVolume(const Value: Single);
begin
  EnsureHandle('Set channel volume');
  if not BASS_ChannelSetAttribute(FHandle, BASS_ATTRIB_VOL,
    EnsureRange(Value, 0.0, 1.0)) then
    TBassAudioEngine.RaiseLastError('Set channel volume');
end;

procedure TBassSound.Play(Restart: Boolean);
begin
  EnsureHandle('Play');
  if not BASS_ChannelPlay(FHandle, Restart) then
    TBassAudioEngine.RaiseLastError('Play');
end;

procedure TBassSound.Pause;
begin
  EnsureHandle('Pause');
  if not BASS_ChannelPause(FHandle) then
    TBassAudioEngine.RaiseLastError('Pause');
end;

procedure TBassSound.Stop;
begin
  EnsureHandle('Stop');
  if not BASS_ChannelStop(FHandle) then
    TBassAudioEngine.RaiseLastError('Stop');
end;

function TBassSound.GetLevel(out Left, Right: Single): Boolean;
var
  Level: DWORD;
begin
  Left := 0.0;
  Right := 0.0;
  Result := False;

  if FHandle = 0 then
    Exit;

  Level := BASS_ChannelGetLevel(FHandle);
  if Level = DWORD($FFFFFFFF) then
    Exit;

  Left := EnsureRange(LoWord(Level) / 32768.0, 0.0, 1.0);
  Right := EnsureRange(HiWord(Level) / 32768.0, 0.0, 1.0);
  Result := True;
end;

procedure TBassSound.Set3DAttributes(AMode: TBass3DMode; AMinDistance,
  AMaxDistance: Single; AInsideConeAngle, AOutsideConeAngle,
  AOutsideVolume: Integer);
begin
  EnsureHandle('Set 3D channel attributes');
  if not BASS_ChannelSet3DAttributes(FHandle, Bass3DModeValue(AMode),
    Max(0.0, AMinDistance), Max(0.0, AMaxDistance),
    EnsureRange(AInsideConeAngle, 0, 360),
    EnsureRange(AOutsideConeAngle, 0, 360),
    EnsureRange(AOutsideVolume, 0, 100)) then
    TBassAudioEngine.RaiseLastError('Set 3D channel attributes');
end;

procedure TBassSound.Set3DPosition(const APosition, AOrientation,
  AVelocity: TBass3DVector);
var
  PositionValue: BASS_3DVECTOR;
  OrientationValue: BASS_3DVECTOR;
  VelocityValue: BASS_3DVECTOR;
begin
  EnsureHandle('Set 3D channel position');
  PositionValue := BassVector(APosition);
  OrientationValue := BassVector(AOrientation);
  VelocityValue := BassVector(AVelocity);

  if not BASS_ChannelSet3DPosition(FHandle, PositionValue,
    OrientationValue, VelocityValue) then
    TBassAudioEngine.RaiseLastError('Set 3D channel position');
end;

{ TBassAudioEngine }

constructor TBassAudioEngine.Create;
begin
  inherited Create;
  FSounds := TObjectList<TBassSound>.Create(True);
  FDevice := -1;
  FFrequency := 44100;
end;

destructor TBassAudioEngine.Destroy;
begin
  Shutdown;
  FSounds.Free;
  inherited Destroy;
end;

procedure TBassAudioEngine.Initialize(AWindowHandle: HWND; ADevice: Integer;
  AFrequency, AFlags: DWORD);
begin
  if FInitialized then
  begin
    if ((AFlags and BASS_DEVICE_3D) <> 0) and not FInitializedFor3D then
      raise EBassAudioError.Create(
        'BASS is already initialized without 3D support. Restart the audio ' +
        'engine and initialize it with Initialize3D before loading spatial sounds.');
    Exit;
  end;

  if HiWord(BASS_GetVersion) <> BASSVERSION then
    raise EBassAudioError.CreateFmt(
      'BASS DLL version mismatch. Expected %s API, got %x.',
      [BASSVERSIONTEXT, BASS_GetVersion]);

  if not BASS_Init(ADevice, AFrequency, AFlags, AWindowHandle, nil) then
    RaiseLastError('Initialize BASS');

  FInitialized := True;
  FInitializedFor3D := (AFlags and BASS_DEVICE_3D) <> 0;
  FDevice := ADevice;
  FFrequency := AFrequency;
  FWindowHandle := AWindowHandle;
end;

procedure TBassAudioEngine.Initialize3D(AWindowHandle: HWND; ADevice: Integer;
  AFrequency: DWORD);
begin
  Initialize(AWindowHandle, ADevice, AFrequency, BASS_DEVICE_3D);
end;

procedure TBassAudioEngine.Shutdown;
begin
  ClearSounds;

  if FInitialized then
  begin
    BASS_Free;
    FInitialized := False;
    FInitializedFor3D := False;
  end;
end;

function TBassAudioEngine.LoadSound(const AFileName: string;
  ALoop, ASpatial, AMutedAtMaxDistance: Boolean): TBassSound;
var
  FullPath: string;
  StreamFlags: DWORD;
  MusicFlags: DWORD;
  SpatialFlags: DWORD;
  Handle: DWORD;
  IsMusic: Boolean;
  StreamError: Integer;
  MusicError: Integer;
begin
  if not FInitialized then
  begin
    if ASpatial then
      Initialize3D
    else
      Initialize;
  end;

  if ASpatial and not FInitializedFor3D then
    raise EBassAudioError.Create(
      'Cannot load a spatial sound because BASS was initialized without ' +
      'BASS_DEVICE_3D. Initialize the audio engine with Initialize3D first.');

  FullPath := ExpandFileName(Trim(AFileName));
  if (FullPath = '') or (not FileExists(FullPath)) then
    raise EBassAudioError.Create('Audio file not found: ' + AFileName);

  SpatialFlags := 0;
  if ASpatial then
  begin
    SpatialFlags := BASS_SAMPLE_3D or BASS_SAMPLE_MONO;
    if AMutedAtMaxDistance then
      SpatialFlags := SpatialFlags or BASS_SAMPLE_MUTEMAX;
  end;

  StreamFlags := BASS_STREAM_PRESCAN or BASS_UNICODE_FLAG or
    BassLoopFlag(ALoop) or SpatialFlags;
  MusicFlags := BASS_MUSIC_RAMP or BASS_MUSIC_PRESCAN or BASS_UNICODE_FLAG or
    BassLoopFlag(ALoop) or SpatialFlags;

  Handle := BASS_StreamCreateFile(0, Pointer(PChar(FullPath)), 0, 0,
    StreamFlags);
  IsMusic := False;
  StreamError := BASS_OK;
  MusicError := BASS_OK;

  if Handle = 0 then
  begin
    StreamError := BASS_ErrorGetCode;
    Handle := BASS_MusicLoad(0, Pointer(PChar(FullPath)), 0, 0,
      MusicFlags, 1);
    if Handle <> 0 then
      IsMusic := True
    else
      MusicError := BASS_ErrorGetCode;
  end;

  if Handle = 0 then
    raise EBassAudioError.CreateFmt(
      'Load audio file "%s" failed. Stream: %s (code %d); module fallback: ' +
      '%s (code %d). Spatial=%s.',
      [FullPath, ErrorText(StreamError), StreamError, ErrorText(MusicError),
       MusicError, BoolToStr(ASpatial, True)]);

  Result := TBassSound.Create(Self, Handle, FullPath, IsMusic, ALoop,
    ASpatial, AMutedAtMaxDistance);
  FSounds.Add(Result);
end;

procedure TBassAudioEngine.FreeSound(var ASound: TBassSound);
begin
  if ASound = nil then
    Exit;

  FSounds.Remove(ASound);
  ASound := nil;
end;

procedure TBassAudioEngine.ClearSounds;
begin
  if FSounds <> nil then
    FSounds.Clear;
end;

class procedure TBassAudioEngine.RaiseLastError(const AAction: string);
begin
  raise EBassAudioError.Create(AAction + ': ' + LastErrorText);
end;

class function TBassAudioEngine.ErrorText(AErrorCode: Integer): string;
begin
  case AErrorCode of
    BASS_OK: Result := 'OK';
    BASS_ERROR_MEM: Result := 'Memory error.';
    BASS_ERROR_FILEOPEN: Result := 'Could not open the file.';
    BASS_ERROR_DRIVER: Result := 'No available sound driver.';
    BASS_ERROR_BUFLOST: Result := 'The sample buffer was lost.';
    BASS_ERROR_HANDLE: Result := 'Invalid BASS handle.';
    BASS_ERROR_FORMAT: Result := 'Unsupported sample format.';
    BASS_ERROR_POSITION: Result := 'Invalid playback position.';
    BASS_ERROR_INIT: Result := 'BASS has not been initialized.';
    BASS_ERROR_START: Result := 'BASS could not start output.';
    BASS_ERROR_ALREADY: Result := 'BASS is already in that state.';
    BASS_ERROR_NOTAUDIO: Result := 'The file does not contain audio.';
    BASS_ERROR_NOCHAN: Result := 'No free channel is available.';
    BASS_ERROR_ILLTYPE: Result := 'Illegal BASS type.';
    BASS_ERROR_ILLPARAM: Result := 'Illegal BASS parameter.';
    BASS_ERROR_NO3D: Result := '3D support is not available.';
    BASS_ERROR_DEVICE: Result := 'Invalid output device.';
    BASS_ERROR_NOPLAY: Result := 'The channel is not playing.';
    BASS_ERROR_FREQ: Result := 'Illegal sample rate.';
    BASS_ERROR_NOTFILE: Result := 'The stream is not file-backed.';
    BASS_ERROR_EMPTY: Result := 'The file contains no sample data.';
    BASS_ERROR_NONET: Result := 'No internet connection could be opened.';
    BASS_ERROR_CREATE: Result := 'Could not create the file.';
    BASS_ERROR_NOFX: Result := 'Effects are not available.';
    BASS_ERROR_NOTAVAIL: Result := 'Requested action is not available.';
    BASS_ERROR_DECODE: Result := 'Invalid decoding-channel operation.';
    BASS_ERROR_DX: Result := 'A sufficient DirectX version is not installed.';
    BASS_ERROR_TIMEOUT: Result := 'Connection timed out.';
    BASS_ERROR_FILEFORM: Result := 'Unsupported file format.';
    BASS_ERROR_VERSION: Result := 'Invalid BASS/add-on version.';
    BASS_ERROR_CODEC: Result := 'Codec is not available or not supported.';
    BASS_ERROR_ENDED: Result := 'The channel has ended.';
    BASS_ERROR_BUSY: Result := 'The device is busy.';
    BASS_ERROR_UNKNOWN: Result := 'Unknown BASS error.';
  else
    Result := Format('BASS error %d.', [AErrorCode]);
  end;
end;

class function TBassAudioEngine.LastErrorText: string;
var
  ErrorCode: Integer;
begin
  ErrorCode := BASS_ErrorGetCode;
  Result := Format('%s (code %d)', [ErrorText(ErrorCode), ErrorCode]);
end;

class function TBassAudioEngine.PlaybackStateText(
  AState: TBassPlaybackState): string;
begin
  case AState of
    bpsStopped: Result := 'Stopped';
    bpsPlaying: Result := 'Playing';
    bpsPaused: Result := 'Paused';
    bpsStalled: Result := 'Stalled';
    bpsPausedDevice: Result := 'Paused by device';
  else
    Result := 'Unknown';
  end;
end;

class function TBassAudioEngine.IsSupportedAudioFile(
  const AFileName: string): Boolean;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(AFileName));
  Result := (Ext = '.wav') or (Ext = '.aif') or (Ext = '.aiff') or
    (Ext = '.mp1') or (Ext = '.mp2') or (Ext = '.mp3') or
    (Ext = '.ogg') or (Ext = '.mod') or (Ext = '.mo3') or
    (Ext = '.s3m') or (Ext = '.xm') or (Ext = '.it') or
    (Ext = '.mtm') or (Ext = '.umx');
end;

function TBassAudioEngine.CPUUsage: Single;
begin
  if FInitialized then
    Result := BASS_GetCPU
  else
    Result := 0.0;
end;

function TBassAudioEngine.MasterVolume: Single;
begin
  if FInitialized then
    Result := BASS_GetVolume
  else
    Result := 1.0;
end;

procedure TBassAudioEngine.SetMasterVolume(AValue: Single);
begin
  if not FInitialized then
    Initialize;

  if not BASS_SetVolume(EnsureRange(AValue, 0.0, 1.0)) then
    RaiseLastError('Set master volume');
end;

procedure TBassAudioEngine.Set3DFactors(ADistanceFactor, ARolloffFactor,
  ADopplerFactor: Single);
begin
  if not FInitialized then
    Initialize3D;

  if not BASS_Set3DFactors(Max(0.0, ADistanceFactor),
    Max(0.0, ARolloffFactor), Max(0.0, ADopplerFactor)) then
    RaiseLastError('Set 3D factors');
end;

procedure TBassAudioEngine.Get3DFactors(out ADistanceFactor, ARolloffFactor,
  ADopplerFactor: Single);
begin
  ADistanceFactor := 1.0;
  ARolloffFactor := 1.0;
  ADopplerFactor := 1.0;

  if not FInitialized then
    Exit;

  if not BASS_Get3DFactors(ADistanceFactor, ARolloffFactor,
    ADopplerFactor) then
    RaiseLastError('Get 3D factors');
end;

procedure TBassAudioEngine.SetListener3D(const APosition, AVelocity, AFront,
  ATop: TBass3DVector);
var
  PositionValue: BASS_3DVECTOR;
  VelocityValue: BASS_3DVECTOR;
  FrontValue: BASS_3DVECTOR;
  TopValue: BASS_3DVECTOR;
begin
  if not FInitialized then
    Initialize3D;

  PositionValue := BassVector(APosition);
  VelocityValue := BassVector(AVelocity);
  FrontValue := BassVector(AFront);
  TopValue := BassVector(ATop);

  if not BASS_Set3DPosition(PositionValue, VelocityValue,
    FrontValue, TopValue) then
    RaiseLastError('Set 3D listener');
end;

procedure TBassAudioEngine.Apply3D;
begin
  if FInitialized then
    BASS_Apply3D;
end;

end.
