unit Managers.Scene;

interface

uses
  System.Generics.Collections, System.SysUtils, System.Classes, System.Math,
  Neslib.FastMath, dglOpenGL,
  Renderer.Mesh, Renderer.Particles, Renderer.Billboards, Renderer.AnimatedSprites,
  Renderer.Camera, Renderer.Light,
  Renderer.Shader, Engine.Types, Engine.Audio, Engine.Animation,
  Engine.Generators, Engine.Wind, Utility.Functions, Renderer.Mesh.List,
  Renderer.Mesh.Factory;

type
  TSceneObject = class;
  TObjectList = TArray<TSceneObject>;
  TLightList = TArray<TLight>;

  TSceneObjectScriptState = class
  private
    FSource: string;
    FEntryPoint: string;
    FProgramSource: string;
    FCompiledProgram: IInterface;
    FAttached: Boolean;
    FEnabled: Boolean;
    FCompiled: Boolean;
    FRunning: Boolean;
    FModified: Boolean;
    FLastMessages: string;

    procedure SetSource(const Value: string);
    procedure SetEntryPoint(const Value: string);
    procedure SetProgramSource(const Value: string);
    procedure SetCompiledProgram(const Value: IInterface);
  public
    constructor Create;

    procedure Assign(Source: TSceneObjectScriptState);
    procedure Clear;
    procedure ClearRuntime;
    procedure MarkModified;
    procedure SaveToStream(Stream: TStream);
    procedure LoadFromStream(Stream: TStream; SceneVersion: Integer);

    property Source: string read FSource write SetSource;
    property EntryPoint: string read FEntryPoint write SetEntryPoint;
    property ProgramSource: string read FProgramSource write SetProgramSource;
    property CompiledProgram: IInterface read FCompiledProgram write SetCompiledProgram;
    property Attached: Boolean read FAttached write FAttached;
    property Enabled: Boolean read FEnabled write FEnabled;
    property Compiled: Boolean read FCompiled write FCompiled;
    property Running: Boolean read FRunning write FRunning;
    property Modified: Boolean read FModified write FModified;
    property LastMessages: string read FLastMessages write FLastMessages;
  end;

  TSceneAudioEmitter = class
  private
    FName: string;
    FEnabled: Boolean;
    FAudioPath: string;
    FAutoPlay: Boolean;
    FLoop: Boolean;
    FSpatial: Boolean;
    FMutedAtMaxDistance: Boolean;
    FVolume: Single;
    FMode: TBass3DMode;
    FMinDistance: Single;
    FMaxDistance: Single;
    FInsideConeAngle: Integer;
    FOutsideConeAngle: Integer;
    FOutsideVolume: Integer;
    FOffset: TVector3;
    FVelocity: TVector3;
    FOrientation: TVector3;
    FRuntimeSound: TBassSound;

    procedure SetVolume(const Value: Single);
    procedure SetMinDistance(const Value: Single);
    procedure SetMaxDistance(const Value: Single);
    procedure SetInsideConeAngle(const Value: Integer);
    procedure SetOutsideConeAngle(const Value: Integer);
    procedure SetOutsideVolume(const Value: Integer);
  public
    constructor Create;
    procedure Assign(Source: TSceneAudioEmitter);
    function Clone: TSceneAudioEmitter;
    procedure SaveToStream(Stream: TStream);
    procedure LoadFromStream(Stream: TStream);

    property Name: string read FName write FName;
    property Enabled: Boolean read FEnabled write FEnabled;
    property AudioPath: string read FAudioPath write FAudioPath;
    property AutoPlay: Boolean read FAutoPlay write FAutoPlay;
    property Loop: Boolean read FLoop write FLoop;
    property Spatial: Boolean read FSpatial write FSpatial;
    property MutedAtMaxDistance: Boolean read FMutedAtMaxDistance write FMutedAtMaxDistance;
    property Volume: Single read FVolume write SetVolume;
    property Mode: TBass3DMode read FMode write FMode;
    property MinDistance: Single read FMinDistance write SetMinDistance;
    property MaxDistance: Single read FMaxDistance write SetMaxDistance;
    property InsideConeAngle: Integer read FInsideConeAngle write SetInsideConeAngle;
    property OutsideConeAngle: Integer read FOutsideConeAngle write SetOutsideConeAngle;
    property OutsideVolume: Integer read FOutsideVolume write SetOutsideVolume;
    property Offset: TVector3 read FOffset write FOffset;
    property Velocity: TVector3 read FVelocity write FVelocity;
    property Orientation: TVector3 read FOrientation write FOrientation;
    property RuntimeSound: TBassSound read FRuntimeSound write FRuntimeSound;
  end;

  TSceneAudioEmitterList = class(System.Generics.Collections.TObjectList<TSceneAudioEmitter>)
  private
    function GetItem(AIndex: Integer): TSceneAudioEmitter;
  public
    function AddEmitterToList(AEmitter: TSceneAudioEmitter): Integer;
    function CreateEmitter: TSceneAudioEmitter;
    function NameIsUnique(const AName: string): Boolean;
    function GenerateUniqueName: string;
    function DeleteEmitter(AIndex: Integer): Boolean; overload;
    function DeleteEmitter(AEmitter: TSceneAudioEmitter): Boolean; overload;
    function Clone: TSceneAudioEmitterList;
    procedure SaveToStream(Stream: TStream);
    procedure LoadFromStream(Stream: TStream);

    property Item[Index: Integer]: TSceneAudioEmitter read GetItem; default;
  end;

  TSceneObject = class(TObject)
  private
    fObjectList: TObjectList;
    fParent: TSceneObject;
    fMeshList: TMeshList;
    fLightList: TLightList;

    fPosition: TVector3;
    fScale: TVector3;
    fOrientation: TQuaternion;
    fRotationEuler: TVector3; // stable editor-facing Euler angles, in radians

    fObjectMatrix: TMatrix4;

    fIsRoot: Boolean;
    fName: String;

    fWorldMatrix: TMatrix4;
    fWorldMatrixValid: Boolean;

    fOnDestroy: TNotifyEvent;
    fIsInstance: Boolean;
    fInstanceSource: TSceneObject;
    fPendingInstanceSourcePath: TArray<Integer>;
    fHasPendingInstanceSource: Boolean;

    fWireframe: Boolean;

    fIsGizmo: Boolean;
    fBoundingRadius: Single;
    fInternalBoundingRadius: Single;

    fCamera: TCamera;
    fParticleSystemList: TParticleSystemList;
    fBillboardList: TBillboardList;
    fAnimatedSpriteList: TAnimatedSpriteList;
    fAudioListener: Boolean;
    fAudioListenerVelocity: TVector3;
    fAudioListenerFront: TVector3;
    fAudioListenerTop: TVector3;
    fAudioDistanceFactor: Single;
    fAudioRolloffFactor: Single;
    fAudioDopplerFactor: Single;
    fAudioEmitterList: TSceneAudioEmitterList;
    fScriptState: TSceneObjectScriptState;
    fWindSettings: TWindActorSettings;
    fWindTime: Single;
    fWindPoseApplied: Boolean;

    procedure RebuildModelMatrix;  // computes local matrix
    procedure LookAtDirection(const ADirection: TVector3);
    function GetPosition: TVector3;
    procedure SetPosition(const Value: TVector3);
    function GetScale: TVector3;
    procedure SetScale(const Value: TVector3);
    function GetRotation: TVector3;
    procedure SetRotation(const Value: TVector3);
    procedure SetOrientation(const Value: TQuaternion);
    function GetRotationEuler: TVector3;
    procedure SetRotationEuler(const Value: TVector3);

    function GetCount: Integer;
    function GetObject(aIndex: Integer): TSceneObject;
    procedure SetObject(aIndex: Integer; aObject: TSceneObject);

    procedure SetCamera(aCamera: TCamera);

    function GetName: String;
    procedure SetName(aName: String);

    function GetLight(aIndex: Integer): TLight;
    procedure SetLight(aIndex: Integer; aLight: TLight);

    function GeTSceneObject(aIndex: Integer): TSceneObject;
    procedure SeTSceneObject(aIndex: Integer; aBaseSceneObject: TSceneObject);

    function Copy(const Source: TObjectList): TObjectList;
    procedure SetWireframe(ModeOn: Boolean);
    procedure SetIsInstance(const Value: Boolean);
    function GetInstanceSource: TSceneObject;
    function GetParticleSystem: TParticleSystem;
    function GetParticleSystemCount: Integer;
    function GetBillboard: TBillboard;
    function GetBillboardCount: Integer;
    function GetAnimatedSprite: TAnimatedSprite;
    function GetAnimatedSpriteCount: Integer;
    function GetAudioEmitter: TSceneAudioEmitter;
    function GetAudioEmitterCount: Integer;
    function GetAnimationController: TSkeletonAnimator;
    procedure SetWindSettings(const Value: TWindActorSettings);
    function TryGetVertexWindFrame(out ARoot, AAxis: TVector3;
      out AHeight: Single): Boolean;
    function RootObject: TSceneObject;
    function BuildPathFromRoot(out Path: TArray<Integer>): Boolean;
    function FindObjectByPath(const Path: TArray<Integer>): TSceneObject;
    procedure ResolveInstanceLinks(ARoot: TSceneObject);
    procedure MakeInstancesUniqueFromSource(ASource: TSceneObject);
    function ApplyWindAnimation(DeltaTime: Single): Boolean;
    procedure ResetWindAnimationPose;
  public
    constructor Create(aOwner: TSceneObject);
    destructor Destroy; override;

    function AddObject(aObject: TSceneObject): Integer;
    function CreateObject: TSceneObject;
    function IndexOfObject(aObject: TSceneObject): Integer;
    function MoveObject(aObject: TSceneObject; NewIndex: Integer): Boolean;

    procedure AttachObject(atIndex: Integer; aSceneObject: TSceneObject);
    procedure DetachObject(aObject: TSceneObject);

    procedure DeleteObject(aIndex: Integer); overload;
    procedure DeleteObject(aObject: TSceneObject); overload;

    procedure CombineMeshLists; // To be moved in a new constructor class
    procedure WeldMeshes(KeepChilds: Boolean = True);    // To be moved in a new constructor class

    // returns a copy
    function GetMeshListCopy: TMeshList;
    function EffectiveMeshList: TMeshList;
    function CanInstanceFrom(Source: TSceneObject): Boolean;
    procedure MakeInstanceOf(Source: TSceneObject);
    procedure MakeUniqueFromInstance;

    function CreateLight: TLight;
    function LightsCount: Integer;

    procedure NotifyChange;

    procedure UpdateWorldMatrices(const ParentWorld: TMatrix4); overload;
    procedure UpdateWorldMatrices; overload;
    procedure UpdateParticles(DeltaTime: Single; NewTime: Double);
    procedure UpdateAnimations(DeltaTime: Single);
    procedure EnableTreeWind;
    procedure EnableVertexTreeWind;
    procedure DisableWind;
    procedure ApplyVertexWindUniforms(Shader: TShader);
    function AnimationCount: Integer;
    function AnimationName(AIndex: Integer): string;
    function PlayAnimation(const AName: string; ALoop: Boolean = True;
      ABlendDuration: Single = 0.0): Boolean;
    procedure PauseAnimation;
    procedure ResumeAnimation;
    procedure StopAnimation(AResetToBindPose: Boolean = True);

    procedure UpdateLights;
    function CreateCamera: TCamera;
    function AddParticleSystem: TParticleSystem;
    function CreateParticleSystem: TParticleSystem;
    function GetParticleSystemItem(aIndex: Integer): TParticleSystem;
    function RemoveParticleSystem(aIndex: Integer): Boolean; overload;
    function RemoveParticleSystem(aParticleSystem: TParticleSystem): Boolean; overload;
    procedure RemoveParticleSystem; overload;
    function AddBillboard: TBillboard;
    function CreateBillboard: TBillboard;
    function GetBillboardItem(aIndex: Integer): TBillboard;
    function RemoveBillboard(aIndex: Integer): Boolean; overload;
    function RemoveBillboard(aBillboard: TBillboard): Boolean; overload;
    procedure RemoveBillboard; overload;
    function AddAnimatedSprite: TAnimatedSprite;
    function CreateAnimatedSprite: TAnimatedSprite;
    function GetAnimatedSpriteItem(aIndex: Integer): TAnimatedSprite;
    function RemoveAnimatedSprite(aIndex: Integer): Boolean; overload;
    function RemoveAnimatedSprite(aAnimatedSprite: TAnimatedSprite): Boolean; overload;
    procedure RemoveAnimatedSprite; overload;
    function AddAudioEmitter: TSceneAudioEmitter;
    function CreateAudioEmitter: TSceneAudioEmitter;
    function GetAudioEmitterItem(aIndex: Integer): TSceneAudioEmitter;
    function RemoveAudioEmitter(aIndex: Integer): Boolean; overload;
    function RemoveAudioEmitter(aEmitter: TSceneAudioEmitter): Boolean; overload;
    procedure RemoveAudioEmitter; overload;

    function Clone: TSceneObject;
    procedure SaveToStream(Stream: TStream);
    class function LoadFromStream(Stream: TStream; AOwner: TSceneObject;
      SceneVersion: Integer = 1): TSceneObject;

    function IsDescendantOf(aPotentialAncestor: TSceneObject): Boolean;

    procedure UpdateBoundingRadiusFromMesh;

    function HasGeometry: Boolean;
    function HasParticles: Boolean;
    function HasBillboard: Boolean;
    function HasAnimatedSprite: Boolean;
    function HasAudio: Boolean;
    function HasSkeletonAnimation: Boolean;
    function HasWindAnimation: Boolean;
    function HasBoneWindAnimation: Boolean;
    function HasVertexWindAnimation: Boolean;
    function HasCamera: Boolean;

    function GetBoundingRadius: Single;

    property WorldMatrix: TMatrix4 read fWorldMatrix;

    // Properties for transformation
    property Position: TVector3 read GetPosition write SetPosition;
    property Scale: TVector3 read GetScale write SetScale;
    property Rotation: TVector3 read GetRotation write SetRotation;
    property Orientation: TQuaternion read fOrientation write SetOrientation;
    property UIRotation: TVector3 read GetRotationEuler write SetRotationEuler; // for UI only

    property Count: Integer read GetCount;
    property ObjectList[aindex: Integer]: TSceneObject read GetObject write SetObject;

    property MeshList: TMeshList read fMeshList;
    property AnimationController: TSkeletonAnimator read GetAnimationController;

    property IsWorldMatrixValid: Boolean read fWorldMatrixValid; // read only, use NotifyChange

    property Name: String read GetName write SetName;

    property OnDestroy: TNotifyEvent read fOnDestroy write fOnDestroy;
    property IsInstance: Boolean read fIsInstance write SetIsInstance;
    property InstanceSource: TSceneObject read GetInstanceSource;
    property IsGizmo: Boolean read fIsGizmo write fIsGizmo;
    property BoundingRadius: Single read GetBoundingRadius;// write fBoundingRadius;

    property Camera: TCamera read fCamera write fCamera;//SetCamera;
    property ParticleSystem: TParticleSystem read GetParticleSystem;
    property ParticleSystemList: TParticleSystemList read fParticleSystemList;
    property ParticleSystemCount: Integer read GetParticleSystemCount;
    property ParticleSystemItem[aIndex: Integer]: TParticleSystem read GetParticleSystemItem;
    property Billboard: TBillboard read GetBillboard;
    property BillboardList: TBillboardList read fBillboardList;
    property BillboardCount: Integer read GetBillboardCount;
    property BillboardItem[aIndex: Integer]: TBillboard read GetBillboardItem;
    property AnimatedSprite: TAnimatedSprite read GetAnimatedSprite;
    property AnimatedSpriteList: TAnimatedSpriteList read fAnimatedSpriteList;
    property AnimatedSpriteCount: Integer read GetAnimatedSpriteCount;
    property AnimatedSpriteItem[aIndex: Integer]: TAnimatedSprite read GetAnimatedSpriteItem;
    property AudioListener: Boolean read fAudioListener write fAudioListener;
    property AudioListenerVelocity: TVector3 read fAudioListenerVelocity write fAudioListenerVelocity;
    property AudioListenerFront: TVector3 read fAudioListenerFront write fAudioListenerFront;
    property AudioListenerTop: TVector3 read fAudioListenerTop write fAudioListenerTop;
    property AudioDistanceFactor: Single read fAudioDistanceFactor write fAudioDistanceFactor;
    property AudioRolloffFactor: Single read fAudioRolloffFactor write fAudioRolloffFactor;
    property AudioDopplerFactor: Single read fAudioDopplerFactor write fAudioDopplerFactor;
    property AudioEmitter: TSceneAudioEmitter read GetAudioEmitter;
    property AudioEmitterList: TSceneAudioEmitterList read fAudioEmitterList;
    property AudioEmitterCount: Integer read GetAudioEmitterCount;
    property AudioEmitterItem[aIndex: Integer]: TSceneAudioEmitter read GetAudioEmitterItem;
    property ScriptState: TSceneObjectScriptState read fScriptState;
    property WindSettings: TWindActorSettings read fWindSettings write SetWindSettings;
    property Light[aIndex: Integer]: TLight read GetLight write SetLight;
    property SceneObject[aIndex: Integer]: TSceneObject read GeTSceneObject write SeTSceneObject;
    property Parent: TSceneObject read fParent;
    property ObjectMatrix: TMatrix4 read fObjectMatrix;

    property WireFrame: Boolean read fWireframe write SetWireframe;
  end;

  TSceneManager = class
  private
    fRoot: TSceneObject;

    fName: String;

    fWireFrame: Boolean;

    function GetRoot: TSceneObject;
    procedure SetRoot(aObject: TSceneObject);
    function GetCount: Integer;

    procedure SetWireFrame(ModeOn: Boolean);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Update;
    procedure UpdateParticles(DeltaTime: Single; NewTime: Double);
    procedure SaveToStream(Stream: TStream);
    procedure LoadFromStream(Stream: TStream);

    function AddSceneObject(aSceneObject: TSceneObject): Integer;
    procedure DeleteObject(aObject: TSceneObject);

    function FindCamera(aObject: TSceneObject): TSceneObject; overload;
    function FindCamera: TSceneObject;                        overload;

    function FindSceneObject(aName: string): TSceneObject;    overload;
    function FindSceneObject(aIndex: Integer): TSceneObject;  overload;
    function GetLights: TArray<TLight>;

    function IndexOf(aName: string): Integer;                 overload;
    function IndexOf(aObject: TSceneObject): Integer;         overload;

    property Root: TSceneObject read GetRoot write SetRoot;

    property Count: Integer read GetCount;

    property Name: String read fName write fName;

    property WireFrame: Boolean read fWireFrame write SetWireFrame;
  end;

implementation

const
  SCENE_FILE_VERSION = 11;
  MAX_SERIALIZED_STRING_CHARS = 1048576;
  MAX_SCENE_DEPTH = 256;
  MAX_SCENE_LIGHTS = 65536;
  MAX_SCENE_CHILDREN = 100000;
  SCENE_FILE_MAGIC: array[0..7] of AnsiChar = ('O', 'M', 'E', 'S', 'C', 'N', '0', '1');
  SCENE_OBJECT_SCRIPT_STATE_VERSION = 1;
  SCENE_AUDIO_EMITTER_VERSION = 1;
  SCENE_AUDIO_EMITTER_LIST_VERSION = 1;

threadvar
  SceneLoadDepth: Integer;

procedure WriteStringToStream(Stream: TStream; const Value: string);
var
  Len: Integer;
begin
  Len := Length(Value);
  Stream.WriteBuffer(Len, SizeOf(Len));
  if Len > 0 then
    Stream.WriteBuffer(Value[1], Len * SizeOf(Char));
end;

function ReadStringFromStream(Stream: TStream): string;
var
  Len: Integer;
  ByteCount: Int64;
begin
  Stream.ReadBuffer(Len, SizeOf(Len));
  if (Len < 0) or (Len > MAX_SERIALIZED_STRING_CHARS) then
    raise Exception.Create('Invalid string length in scene stream.');
  ByteCount := Int64(Len) * SizeOf(Char);
  if ByteCount > Stream.Size - Stream.Position then
    raise Exception.Create('Truncated string in scene stream.');
  SetLength(Result, Len);
  if Len > 0 then
    Stream.ReadBuffer(Result[1], ByteCount);
end;

function SceneMagicMatches(const Magic: array of AnsiChar): Boolean;
var
  I: Integer;
begin
  Result := Length(Magic) = Length(SCENE_FILE_MAGIC);
  if not Result then
    Exit;

  for I := Low(SCENE_FILE_MAGIC) to High(SCENE_FILE_MAGIC) do
    if Magic[I] <> SCENE_FILE_MAGIC[I] then
      Exit(False);
end;

{ TSceneObjectScriptState }

constructor TSceneObjectScriptState.Create;
begin
  inherited Create;
  FEnabled := True;
end;

procedure TSceneObjectScriptState.Assign(Source: TSceneObjectScriptState);
begin
  if Source = nil then
  begin
    Clear;
    Exit;
  end;

  FSource := Source.FSource;
  FEntryPoint := Source.FEntryPoint;
  FAttached := Source.FAttached;
  FEnabled := Source.FEnabled;
  FModified := Source.FModified;
  FLastMessages := Source.FLastMessages;
  ClearRuntime;
end;

procedure TSceneObjectScriptState.Clear;
begin
  FSource := '';
  FEntryPoint := '';
  FAttached := False;
  FEnabled := True;
  FModified := False;
  FLastMessages := '';
  ClearRuntime;
end;

procedure TSceneObjectScriptState.ClearRuntime;
begin
  FProgramSource := '';
  FCompiledProgram := nil;
  FCompiled := False;
  FRunning := False;
end;

procedure TSceneObjectScriptState.MarkModified;
begin
  FModified := True;
  ClearRuntime;
end;

procedure TSceneObjectScriptState.SetSource(const Value: string);
begin
  if FSource = Value then
    Exit;

  FSource := Value;
  FAttached := Trim(FSource) <> '';
  MarkModified;
end;

procedure TSceneObjectScriptState.SetEntryPoint(const Value: string);
begin
  if FEntryPoint = Value then
    Exit;

  FEntryPoint := Value;
  MarkModified;
end;

procedure TSceneObjectScriptState.SetProgramSource(const Value: string);
begin
  FProgramSource := Value;
end;

procedure TSceneObjectScriptState.SetCompiledProgram(const Value: IInterface);
begin
  FCompiledProgram := Value;
  FCompiled := FCompiledProgram <> nil;
end;

procedure TSceneObjectScriptState.SaveToStream(Stream: TStream);
var
  Version: Integer;
  SavedAttached: Boolean;
begin
  Version := SCENE_OBJECT_SCRIPT_STATE_VERSION;
  Stream.WriteBuffer(Version, SizeOf(Version));
  WriteStringToStream(Stream, FSource);
  WriteStringToStream(Stream, FEntryPoint);
  WriteStringToStream(Stream, FLastMessages);

  SavedAttached := FAttached or (Trim(FSource) <> '');
  Stream.WriteBuffer(SavedAttached, SizeOf(SavedAttached));
  Stream.WriteBuffer(FEnabled, SizeOf(FEnabled));
  Stream.WriteBuffer(FModified, SizeOf(FModified));
end;

procedure TSceneObjectScriptState.LoadFromStream(Stream: TStream; SceneVersion: Integer);
var
  Version: Integer;
begin
  Stream.ReadBuffer(Version, SizeOf(Version));
  if (Version < 1) or (Version > SCENE_OBJECT_SCRIPT_STATE_VERSION) then
    raise Exception.CreateFmt('Unsupported scene object script state version: %d.',
      [Version]);

  FSource := ReadStringFromStream(Stream);
  FEntryPoint := ReadStringFromStream(Stream);
  FLastMessages := ReadStringFromStream(Stream);
  Stream.ReadBuffer(FAttached, SizeOf(FAttached));
  Stream.ReadBuffer(FEnabled, SizeOf(FEnabled));
  Stream.ReadBuffer(FModified, SizeOf(FModified));

  FAttached := FAttached or (Trim(FSource) <> '');
  ClearRuntime;
end;

{ TSceneAudioEmitter }

constructor TSceneAudioEmitter.Create;
begin
  inherited Create;
  FName := 'AudioEmitter';
  FEnabled := True;
  FAudioPath := '';
  FAutoPlay := False;
  FLoop := False;
  FSpatial := True;
  FMutedAtMaxDistance := False;
  FVolume := 1.0;
  FMode := b3dmNormal;
  FMinDistance := 1.0;
  FMaxDistance := 100.0;
  FInsideConeAngle := 360;
  FOutsideConeAngle := 360;
  FOutsideVolume := 100;
  FOffset := Vector3(0, 0, 0);
  FVelocity := Vector3(0, 0, 0);
  FOrientation := Vector3(0, 0, -1);
  FRuntimeSound := nil;
end;

procedure TSceneAudioEmitter.Assign(Source: TSceneAudioEmitter);
begin
  if Source = nil then
    Exit;

  FName := Source.FName;
  FEnabled := Source.FEnabled;
  FAudioPath := Source.FAudioPath;
  FAutoPlay := Source.FAutoPlay;
  FLoop := Source.FLoop;
  FSpatial := Source.FSpatial;
  FMutedAtMaxDistance := Source.FMutedAtMaxDistance;
  FVolume := Source.FVolume;
  FMode := Source.FMode;
  FMinDistance := Source.FMinDistance;
  FMaxDistance := Source.FMaxDistance;
  FInsideConeAngle := Source.FInsideConeAngle;
  FOutsideConeAngle := Source.FOutsideConeAngle;
  FOutsideVolume := Source.FOutsideVolume;
  FOffset := Source.FOffset;
  FVelocity := Source.FVelocity;
  FOrientation := Source.FOrientation;
  FRuntimeSound := nil;
end;

function TSceneAudioEmitter.Clone: TSceneAudioEmitter;
begin
  Result := TSceneAudioEmitter.Create;
  Result.Assign(Self);
end;

procedure TSceneAudioEmitter.SetVolume(const Value: Single);
begin
  FVolume := EnsureRange(Value, 0.0, 1.0);
end;

procedure TSceneAudioEmitter.SetMinDistance(const Value: Single);
begin
  FMinDistance := Max(0.0, Value);
end;

procedure TSceneAudioEmitter.SetMaxDistance(const Value: Single);
begin
  FMaxDistance := Max(0.0, Value);
end;

procedure TSceneAudioEmitter.SetInsideConeAngle(const Value: Integer);
begin
  FInsideConeAngle := EnsureRange(Value, 0, 360);
end;

procedure TSceneAudioEmitter.SetOutsideConeAngle(const Value: Integer);
begin
  FOutsideConeAngle := EnsureRange(Value, 0, 360);
end;

procedure TSceneAudioEmitter.SetOutsideVolume(const Value: Integer);
begin
  FOutsideVolume := EnsureRange(Value, 0, 100);
end;

procedure TSceneAudioEmitter.SaveToStream(Stream: TStream);
var
  Version: Integer;
  ModeValue: Integer;
begin
  Version := SCENE_AUDIO_EMITTER_VERSION;
  Stream.WriteBuffer(Version, SizeOf(Version));
  WriteStringToStream(Stream, FName);
  Stream.WriteBuffer(FEnabled, SizeOf(FEnabled));
  WriteStringToStream(Stream, FAudioPath);
  Stream.WriteBuffer(FAutoPlay, SizeOf(FAutoPlay));
  Stream.WriteBuffer(FLoop, SizeOf(FLoop));
  Stream.WriteBuffer(FSpatial, SizeOf(FSpatial));
  Stream.WriteBuffer(FMutedAtMaxDistance, SizeOf(FMutedAtMaxDistance));
  Stream.WriteBuffer(FVolume, SizeOf(FVolume));
  ModeValue := Ord(FMode);
  Stream.WriteBuffer(ModeValue, SizeOf(ModeValue));
  Stream.WriteBuffer(FMinDistance, SizeOf(FMinDistance));
  Stream.WriteBuffer(FMaxDistance, SizeOf(FMaxDistance));
  Stream.WriteBuffer(FInsideConeAngle, SizeOf(FInsideConeAngle));
  Stream.WriteBuffer(FOutsideConeAngle, SizeOf(FOutsideConeAngle));
  Stream.WriteBuffer(FOutsideVolume, SizeOf(FOutsideVolume));
  Stream.WriteBuffer(FOffset, SizeOf(FOffset));
  Stream.WriteBuffer(FVelocity, SizeOf(FVelocity));
  Stream.WriteBuffer(FOrientation, SizeOf(FOrientation));
end;

procedure TSceneAudioEmitter.LoadFromStream(Stream: TStream);
var
  Version: Integer;
  ModeValue: Integer;
begin
  Stream.ReadBuffer(Version, SizeOf(Version));
  if (Version < 1) or (Version > SCENE_AUDIO_EMITTER_VERSION) then
    raise Exception.CreateFmt('Unsupported audio-emitter version: %d.', [Version]);

  FName := ReadStringFromStream(Stream);
  Stream.ReadBuffer(FEnabled, SizeOf(FEnabled));
  FAudioPath := ReadStringFromStream(Stream);
  Stream.ReadBuffer(FAutoPlay, SizeOf(FAutoPlay));
  Stream.ReadBuffer(FLoop, SizeOf(FLoop));
  Stream.ReadBuffer(FSpatial, SizeOf(FSpatial));
  Stream.ReadBuffer(FMutedAtMaxDistance, SizeOf(FMutedAtMaxDistance));
  Stream.ReadBuffer(FVolume, SizeOf(FVolume));
  Stream.ReadBuffer(ModeValue, SizeOf(ModeValue));
  FMode := TBass3DMode(EnsureRange(ModeValue, Ord(Low(TBass3DMode)),
    Ord(High(TBass3DMode))));
  Stream.ReadBuffer(FMinDistance, SizeOf(FMinDistance));
  Stream.ReadBuffer(FMaxDistance, SizeOf(FMaxDistance));
  Stream.ReadBuffer(FInsideConeAngle, SizeOf(FInsideConeAngle));
  Stream.ReadBuffer(FOutsideConeAngle, SizeOf(FOutsideConeAngle));
  Stream.ReadBuffer(FOutsideVolume, SizeOf(FOutsideVolume));
  Stream.ReadBuffer(FOffset, SizeOf(FOffset));
  Stream.ReadBuffer(FVelocity, SizeOf(FVelocity));
  Stream.ReadBuffer(FOrientation, SizeOf(FOrientation));
  FRuntimeSound := nil;

  if Trim(FName) = '' then
    FName := 'AudioEmitter';
  SetVolume(FVolume);
  SetMinDistance(FMinDistance);
  SetMaxDistance(FMaxDistance);
  SetInsideConeAngle(FInsideConeAngle);
  SetOutsideConeAngle(FOutsideConeAngle);
  SetOutsideVolume(FOutsideVolume);
end;

{ TSceneAudioEmitterList }

function TSceneAudioEmitterList.GetItem(AIndex: Integer): TSceneAudioEmitter;
begin
  if (AIndex >= 0) and (AIndex < Count) then
    Result := Items[AIndex]
  else
    Result := nil;
end;

function TSceneAudioEmitterList.AddEmitterToList(
  AEmitter: TSceneAudioEmitter): Integer;
begin
  if AEmitter = nil then
    raise Exception.Create('Cannot add nil audio emitter.');

  if Trim(AEmitter.Name) = '' then
    AEmitter.Name := GenerateUniqueName
  else if not NameIsUnique(AEmitter.Name) then
    AEmitter.Name := GenerateUniqueName;

  Result := inherited Add(AEmitter);
end;

function TSceneAudioEmitterList.CreateEmitter: TSceneAudioEmitter;
begin
  Result := TSceneAudioEmitter.Create;
  AddEmitterToList(Result);
end;

function TSceneAudioEmitterList.NameIsUnique(const AName: string): Boolean;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if SameText(Items[I].Name, AName) then
      Exit(False);
  Result := True;
end;

function TSceneAudioEmitterList.GenerateUniqueName: string;
var
  Counter: Integer;
begin
  Counter := 1;
  repeat
    Result := 'AudioEmitter_' + Counter.ToString;
    Inc(Counter);
  until NameIsUnique(Result);
end;

function TSceneAudioEmitterList.DeleteEmitter(AIndex: Integer): Boolean;
begin
  if (AIndex < 0) or (AIndex >= Count) then
    Exit(False);
  Delete(AIndex);
  Result := True;
end;

function TSceneAudioEmitterList.DeleteEmitter(
  AEmitter: TSceneAudioEmitter): Boolean;
begin
  Result := DeleteEmitter(IndexOf(AEmitter));
end;

function TSceneAudioEmitterList.Clone: TSceneAudioEmitterList;
var
  I: Integer;
begin
  Result := TSceneAudioEmitterList.Create;
  for I := 0 to Count - 1 do
    if Items[I] <> nil then
      Result.AddEmitterToList(Items[I].Clone);
end;

procedure TSceneAudioEmitterList.SaveToStream(Stream: TStream);
var
  I: Integer;
  Version: Integer;
  EmitterCount: Integer;
begin
  Version := SCENE_AUDIO_EMITTER_LIST_VERSION;
  Stream.WriteBuffer(Version, SizeOf(Version));
  EmitterCount := Count;
  Stream.WriteBuffer(EmitterCount, SizeOf(EmitterCount));
  for I := 0 to EmitterCount - 1 do
    Items[I].SaveToStream(Stream);
end;

procedure TSceneAudioEmitterList.LoadFromStream(Stream: TStream);
var
  I: Integer;
  Version: Integer;
  EmitterCount: Integer;
  Emitter: TSceneAudioEmitter;
begin
  Clear;
  Stream.ReadBuffer(Version, SizeOf(Version));
  if (Version < 1) or (Version > SCENE_AUDIO_EMITTER_LIST_VERSION) then
    raise Exception.CreateFmt('Unsupported audio-emitter-list version: %d.',
      [Version]);

  Stream.ReadBuffer(EmitterCount, SizeOf(EmitterCount));
  if (EmitterCount < 0) or (EmitterCount > 100000) then
    raise Exception.Create('Invalid audio-emitter-list count in scene stream.');

  for I := 0 to EmitterCount - 1 do
  begin
    Emitter := TSceneAudioEmitter.Create;
    try
      Emitter.LoadFromStream(Stream);
      AddEmitterToList(Emitter);
    except
      Emitter.Free;
      raise;
    end;
  end;
end;

{ TSceneObject }
procedure TSceneObject.RebuildModelMatrix;
var
  TransMat, ScaleMat: TMatrix4;
begin
  TransMat.InitTranslation(fPosition);
  ScaleMat.InitScaling(fScale);
  fObjectMatrix := TransMat * fOrientation.ToMatrix * ScaleMat;
  NotifyChange;
end;

procedure TSceneObject.LookAtDirection(const ADirection: TVector3);
var
  ForwardDir, BackDir, UpHint, RightDir, UpDir: TVector3;
  RotationMatrix: TMatrix4;
  NewOrientation: TQuaternion;
begin
  ForwardDir := ADirection;
  if ForwardDir.LengthSquared < 1e-6 then
    Exit;

  ForwardDir.Normalize;
  BackDir := -ForwardDir;

  UpHint := Vector3(0, 1, 0);
  if Abs(ForwardDir.Dot(UpHint)) > 0.98 then
    UpHint := Vector3(0, 0, 1);

  RightDir := UpHint.Cross(BackDir);
  if RightDir.LengthSquared < 1e-6 then
    Exit;
  RightDir.Normalize;

  UpDir := BackDir.Cross(RightDir);
  if UpDir.LengthSquared < 1e-6 then
    Exit;
  UpDir.Normalize;

  RotationMatrix := TMatrix4.Identity;
  RotationMatrix.Columns[0] := Vector4(RightDir, 0);
  RotationMatrix.Columns[1] := Vector4(UpDir, 0);
  RotationMatrix.Columns[2] := Vector4(BackDir, 0);
  RotationMatrix.Columns[3] := Vector4(0, 0, 0, 1);

  NewOrientation.Init(RotationMatrix);
  fOrientation := NewOrientation.Normalize;
  fRotationEuler := QuaternionToEulerXYZ(fOrientation);
  RebuildModelMatrix;
end;

function TSceneObject.GetPosition: TVector3;
begin
  Result := fPosition;
end;

procedure TSceneObject.SetPosition(const Value: TVector3);
begin
  fPosition := Value;
  RebuildModelMatrix;
end;

function TSceneObject.GetScale: TVector3;
begin
  Result := fScale;
end;

procedure TSceneObject.SetScale(const Value: TVector3);
begin
  fScale := Value;
  RebuildModelMatrix;
end;

function TSceneObject.GetRotation: TVector3;
begin
  // Return the stable Euler value entered by the user. Reconstructing Euler
  // angles from a quaternion on every read causes equivalent 0/180-degree
  // representations to alternate near gimbal-lock orientations.
  Result := fRotationEuler;
end;

procedure TSceneObject.SetRotation(const Value: TVector3);
begin
  fRotationEuler := Value;
  fOrientation := EulerToQuaternionXYZ(fRotationEuler).Normalize;
  RebuildModelMatrix;
end;

procedure TSceneObject.SetOrientation(const Value: TQuaternion);
begin
  // Direct quaternion assignments (for example LookAt) synchronize the
  // editor-facing Euler cache once. Do not perform this conversion every frame.
  fOrientation := Value.Normalize;
  fRotationEuler := QuaternionToEulerXYZ(fOrientation);
  RebuildModelMatrix;
end;

function TSceneObject.GetRotationEuler: TVector3;
begin
  Result := fRotationEuler;
end;

procedure TSceneObject.SetRotationEuler(const Value: TVector3);
begin
  SetRotation(Value);
end;

function TSceneObject.GetCount: Integer;
begin
  Result := Length(fObjectList);
end;

function TSceneObject.GetObject(aIndex: Integer): TSceneObject;
begin
  if (aIndex >= 0) and (aIndex <= Length(fObjectList) -1) then
    Result := fObjectList[aIndex]
  else
    Result := nil;
end;

procedure TSceneObject.SetObject(aIndex: Integer; aObject: TSceneObject);
begin
  if (aIndex >= 0) and (aIndex <= Length(fObjectList) -1) then
    fObjectList[aIndex] := aObject;
end;

procedure TSceneObject.SetCamera(aCamera: TCamera);
begin
  if fCamera <> aCamera then
  begin
    if fCamera <> nil then
      fCamera.Free;

    fCamera := aCamera;
  end;
end;

function TSceneObject.GetName: String;
begin
  Result := fName;
end;

procedure TSceneObject.SetName(aName: String);
var
  baseName: string;
  counter: Integer;
  newName: string;

  function NameExistsInSiblings(const n: string): Boolean;
  var
    i: Integer;
  begin
    if fParent = nil then
      Exit(False);   // No siblings to conflict with
    for i := 0 to fParent.Count - 1 do
      if (fParent.ObjectList[i] <> Self) and SameText(fParent.ObjectList[i].Name, n) then
        Exit(True);
    Result := False;
  end;

begin
  if aName = fName then
    Exit;

  baseName := aName;
  counter := 1;
  newName := baseName;
  while NameExistsInSiblings(newName) do
  begin
    newName := baseName + '_' + IntToStr(counter);
    Inc(counter);
  end;

  fName := newName;
end;

function TSceneObject.GetLight(aIndex: Integer): TLight;
begin
  if (aIndex >= 0) and (aIndex < Length(fLightList)) then
    Result := fLightList[aIndex]
  else
    Result := nil;
end;

procedure TSceneObject.SetLight(aIndex: Integer; aLight: TLight);
begin
  if (aIndex >= 0) and (aIndex < Length(fLightList)) then
    if aLight <> nil then
      fLightList[aIndex] := aLight;
end;

function TSceneObject.GeTSceneObject(aIndex: Integer): TSceneObject;
begin
  if (aIndex >= 0) and (aIndex < Length(fObjectList)) then
    Result := fObjectList[aIndex]
  else
    Result := nil;
end;

procedure TSceneObject.SeTSceneObject(aIndex: Integer; aBaseSceneObject: TSceneObject);
begin
  if (aIndex >= 0) and (aIndex < Length(fObjectList)) then
    if aBaseSceneObject <> nil then
      fObjectList[aIndex] := aBaseSceneObject;
end;

function TSceneObject.Copy(const Source: TObjectList): TObjectList;
var
  i: Integer;
begin
  SetLength(Result, Length(Source));
  for i := 0 to High(Source) do
    Result[i] := Source[i];
end;

procedure TSceneObject.SetWireframe(ModeOn: Boolean);
var
  i: Integer;
  Meshes: TMeshList;
begin
  fWireframe := ModeOn;

  // All meshes in the list
  Meshes := EffectiveMeshList;
  if Assigned(Meshes) and (Meshes.Count > 0) then
    for i := 0 to Meshes.Count - 1 do
      if Assigned(Meshes.Item[i]) then
        Meshes.Item[i].WireFrame := ModeOn;

  // Recurse children
  for i := 0 to Count - 1 do
    if Assigned(ObjectList[i]) then
      ObjectList[i].WireFrame := ModeOn;
end;

procedure TSceneObject.SetIsInstance(const Value: Boolean);
begin
  if fIsInstance = Value then
    Exit;

  if not Value then
    MakeUniqueFromInstance
  else if Assigned(fInstanceSource) then
    fIsInstance := True;
end;

function TSceneObject.GetInstanceSource: TSceneObject;
begin
  if fIsInstance then
    Result := fInstanceSource
  else
    Result := nil;
end;

function TSceneObject.GetParticleSystem: TParticleSystem;
begin
  Result := GetParticleSystemItem(0);
end;

function TSceneObject.GetParticleSystemCount: Integer;
begin
  if Assigned(fParticleSystemList) then
    Result := fParticleSystemList.Count
  else
    Result := 0;
end;

function TSceneObject.GetBillboard: TBillboard;
begin
  Result := GetBillboardItem(0);
end;

function TSceneObject.GetBillboardCount: Integer;
begin
  if Assigned(fBillboardList) then
    Result := fBillboardList.Count
  else
    Result := 0;
end;

function TSceneObject.GetAnimatedSprite: TAnimatedSprite;
begin
  Result := GetAnimatedSpriteItem(0);
end;

function TSceneObject.GetAnimatedSpriteCount: Integer;
begin
  if Assigned(fAnimatedSpriteList) then
    Result := fAnimatedSpriteList.Count
  else
    Result := 0;
end;

function TSceneObject.GetAudioEmitter: TSceneAudioEmitter;
begin
  Result := GetAudioEmitterItem(0);
end;

function TSceneObject.GetAudioEmitterCount: Integer;
begin
  if Assigned(fAudioEmitterList) then
    Result := fAudioEmitterList.Count
  else
    Result := 0;
end;

function TSceneObject.RootObject: TSceneObject;
begin
  Result := Self;
  while Assigned(Result) and Assigned(Result.fParent) do
    Result := Result.fParent;
end;

function TSceneObject.BuildPathFromRoot(out Path: TArray<Integer>): Boolean;
var
  Obj: TSceneObject;
  ParentObj: TSceneObject;
  Indices: TList<Integer>;
  Index: Integer;
  ChildIndex: Integer;
  SavedIndex: Integer;
  I: Integer;
begin
  Result := False;
  SetLength(Path, 0);

  Obj := Self;
  if Obj = nil then
    Exit;

  Indices := TList<Integer>.Create;
  try
    while Assigned(Obj.fParent) do
    begin
      if Obj.IsGizmo then
        Exit(False);

      ParentObj := Obj.fParent;
      Index := -1;
      SavedIndex := 0;
      for ChildIndex := 0 to ParentObj.Count - 1 do
        if Assigned(ParentObj.ObjectList[ChildIndex]) and
           (not ParentObj.ObjectList[ChildIndex].IsGizmo) then
        begin
          if ParentObj.ObjectList[ChildIndex] = Obj then
          begin
            Index := SavedIndex;
            Break;
          end;
          Inc(SavedIndex);
        end;

      if Index < 0 then
        Exit(False);

      Indices.Insert(0, Index);
      Obj := ParentObj;
    end;

    SetLength(Path, Indices.Count);
    for I := 0 to Indices.Count - 1 do
      Path[I] := Indices[I];

    Result := True;
  finally
    Indices.Free;
  end;
end;

function TSceneObject.FindObjectByPath(const Path: TArray<Integer>): TSceneObject;
var
  I: Integer;
  ChildIndex: Integer;
begin
  Result := Self;
  for I := 0 to High(Path) do
  begin
    if Result = nil then
      Exit(nil);

    ChildIndex := Path[I];
    if (ChildIndex < 0) or (ChildIndex >= Result.Count) then
      Exit(nil);

    Result := Result.ObjectList[ChildIndex];
  end;
end;

function TSceneObject.EffectiveMeshList: TMeshList;
var
  Source: TSceneObject;
  Guard: Integer;
begin
  Result := fMeshList;
  Source := Self;
  Guard := 0;

  while Assigned(Source) and Source.fIsInstance and Assigned(Source.fInstanceSource) and
        (Source.fInstanceSource <> Source) and (Guard < 64) do
  begin
    if Source.fInstanceSource = Self then
      Exit(fMeshList);

    Source := Source.fInstanceSource;
    Inc(Guard);
  end;

  if Assigned(Source) then
    Result := Source.fMeshList;
end;

function TSceneObject.GetAnimationController: TSkeletonAnimator;
var
  Meshes: TMeshList;
begin
  Meshes := EffectiveMeshList;
  if Assigned(Meshes) then
    Result := Meshes.AnimationController
  else
    Result := nil;
end;

procedure TSceneObject.SetWindSettings(const Value: TWindActorSettings);
var
  Settings: TWindActorSettings;
begin
  Settings := Value;
  Settings.Sanitize;
  fWindSettings := Settings;
  if not fWindSettings.Enabled then
    fWindTime := 0.0;
end;

procedure TSceneObject.EnableTreeWind;
begin
  WindSettings := TWindActorSettings.DefaultTree;
end;

procedure TSceneObject.EnableVertexTreeWind;
begin
  WindSettings := TWindActorSettings.DefaultVertexTree;
end;

procedure TSceneObject.DisableWind;
var
  Settings: TWindActorSettings;
begin
  Settings := fWindSettings;
  Settings.Enabled := False;
  Settings.Kind := wakNone;
  WindSettings := Settings;
end;

function TSceneObject.HasWindAnimation: Boolean;
begin
  Result := fWindSettings.Enabled and (fWindSettings.Kind <> wakNone);
end;

function TSceneObject.HasBoneWindAnimation: Boolean;
begin
  Result := fWindSettings.Enabled and (fWindSettings.Kind = wakTree);
end;

function TSceneObject.HasVertexWindAnimation: Boolean;
begin
  Result := fWindSettings.Enabled and (fWindSettings.Kind = wakVertexTree);
end;

function TSceneObject.ApplyWindAnimation(DeltaTime: Single): Boolean;
var
  Animator: TSkeletonAnimator;
begin
  Result := False;
  if not HasBoneWindAnimation then
    Exit;

  Animator := AnimationController;
  if (Animator = nil) or (Animator.Skeleton = nil) or
     (Animator.Skeleton.BoneCount = 0) then
    Exit;

  fWindTime := fWindTime + System.Math.Max(0.0, DeltaTime);
  Result := TTreeWindSystem.Apply(Animator, fWindSettings, fWindTime,
    Animator.State = apsPlaying);
  if Result then
    fWindPoseApplied := True;
end;

function TSceneObject.TryGetVertexWindFrame(out ARoot, AAxis: TVector3;
  out AHeight: Single): Boolean;
var
  Meshes: TMeshList;
  Mesh: TMesh;
  Bounds, CombinedBounds: TAABB;
  LocalRoot, LocalAxis: TVector3;
  WorldAxis: TVector4;
  Extents: TVector3;
  I, AxisIndex: Integer;
  HasBounds: Boolean;
begin
  Result := False;
  ARoot := Vector3(0.0, 0.0, 0.0);
  AAxis := Vector3(0.0, 1.0, 0.0);
  AHeight := 0.0;

  Meshes := EffectiveMeshList;
  if (Meshes = nil) or (Meshes.Count = 0) then
    Exit;

  HasBounds := False;
  for I := 0 to Meshes.Count - 1 do
  begin
    Mesh := Meshes.Item[I];
    if (Mesh = nil) or (Mesh.VertexCount <= 0) then
      Continue;

    Bounds := Mesh.GetBoundingBox.Transform(Mesh.LocalMatrix);
    if not HasBounds then
    begin
      CombinedBounds := Bounds;
      HasBounds := True;
    end
    else
    begin
      CombinedBounds.Min.X := System.Math.Min(CombinedBounds.Min.X, Bounds.Min.X);
      CombinedBounds.Min.Y := System.Math.Min(CombinedBounds.Min.Y, Bounds.Min.Y);
      CombinedBounds.Min.Z := System.Math.Min(CombinedBounds.Min.Z, Bounds.Min.Z);
      CombinedBounds.Max.X := System.Math.Max(CombinedBounds.Max.X, Bounds.Max.X);
      CombinedBounds.Max.Y := System.Math.Max(CombinedBounds.Max.Y, Bounds.Max.Y);
      CombinedBounds.Max.Z := System.Math.Max(CombinedBounds.Max.Z, Bounds.Max.Z);
    end;
  end;

  if not HasBounds then
    Exit;

  Extents := CombinedBounds.Max - CombinedBounds.Min;
  AxisIndex := 1;
  if (Extents.X > Extents.Y) and (Extents.X >= Extents.Z) then
    AxisIndex := 0
  else if (Extents.Z > Extents.Y) and (Extents.Z > Extents.X) then
    AxisIndex := 2;

  LocalRoot := (CombinedBounds.Min + CombinedBounds.Max) * 0.5;
  case AxisIndex of
    0:
      begin
        LocalAxis := Vector3(1.0, 0.0, 0.0);
        LocalRoot.X := CombinedBounds.Min.X;
        AHeight := Extents.X;
      end;
    2:
      begin
        LocalAxis := Vector3(0.0, 0.0, 1.0);
        LocalRoot.Z := CombinedBounds.Min.Z;
        AHeight := Extents.Z;
      end;
  else
    LocalAxis := Vector3(0.0, 1.0, 0.0);
    LocalRoot.Y := CombinedBounds.Min.Y;
    AHeight := Extents.Y;
  end;

  ARoot := Vector3(fWorldMatrix * Vector4(LocalRoot, 1.0));
  WorldAxis := fWorldMatrix * Vector4(LocalAxis, 0.0);
  AHeight := Vector3(WorldAxis).Length * AHeight;
  if (AHeight <= 1.0e-5) or (Vector3(WorldAxis).LengthSquared <= 1.0e-8) then
    Exit;

  AAxis := Vector3(WorldAxis).Normalize;
  Result := True;
end;

procedure TSceneObject.ApplyVertexWindUniforms(Shader: TShader);
var
  Root, Axis: TVector3;
  Height: Single;
begin
  if Shader = nil then
    Exit;

  Shader.SetUniform('useVertexWind', GLint(0));
  if (not HasVertexWindAnimation) or
     (not TryGetVertexWindFrame(Root, Axis, Height)) then
    Exit;

  Shader.SetUniform('useVertexWind', GLint(1));
  Shader.SetUniform('windTime', GLfloat(fWindTime));
  Shader.SetUniform('windDirection', fWindSettings.Direction);
  Shader.SetUniform('windStrength', GLfloat(fWindSettings.Strength));
  Shader.SetUniform('windFrequency', GLfloat(fWindSettings.Frequency));
  Shader.SetUniform('windGustStrength', GLfloat(fWindSettings.GustStrength));
  Shader.SetUniform('windGustFrequency', GLfloat(fWindSettings.GustFrequency));
  Shader.SetUniform('windPhaseOffset', GLfloat(fWindSettings.PhaseOffset));
  Shader.SetUniform('windTrunkFlex', GLfloat(fWindSettings.TrunkFlex));
  Shader.SetUniform('windBranchFlex', GLfloat(fWindSettings.BranchFlex));
  Shader.SetUniform('windLeafFlutter', GLfloat(fWindSettings.LeafFlutter));
  Shader.SetUniform('windRoot', Root);
  Shader.SetUniform('windAxis', Axis);
  Shader.SetUniform('windHeight', GLfloat(Height));
end;

procedure TSceneObject.ResetWindAnimationPose;
var
  Animator: TSkeletonAnimator;
  Pose: TArray<TSkeletonTransform>;
begin
  if not fWindPoseApplied then
    Exit;

  Animator := AnimationController;
  if (Animator <> nil) and (Animator.Skeleton <> nil) then
  begin
    Animator.Skeleton.GetBindPose(Pose);
    Animator.SetProceduralPose(Pose);
    if Assigned(fMeshList) then
      fMeshList.ApplyCurrentPose(True);
  end;

  fWindPoseApplied := False;
end;

function TSceneObject.CanInstanceFrom(Source: TSceneObject): Boolean;
var
  SourceMeshes: TMeshList;
begin
  Result := False;
  if (Source = nil) or (Source = Self) or Source.IsDescendantOf(Self) then
    Exit;

  SourceMeshes := Source.EffectiveMeshList;
  Result := Assigned(SourceMeshes) and (SourceMeshes.Count > 0);
end;

procedure TSceneObject.MakeInstanceOf(Source: TSceneObject);
begin
  if not CanInstanceFrom(Source) then
    Exit;

  fMeshList.Clear;
  fInstanceSource := Source;
  fIsInstance := True;
  UpdateBoundingRadiusFromMesh;
  NotifyChange;
end;

procedure TSceneObject.MakeUniqueFromInstance;
var
  SourceMeshes: TMeshList;
  ClonedMeshes: TMeshList;
begin
  if not fIsInstance then
    Exit;

  SourceMeshes := EffectiveMeshList;
  if Assigned(SourceMeshes) and (SourceMeshes <> fMeshList) then
  begin
    ClonedMeshes := SourceMeshes.Clone;
    fMeshList.Free;
    fMeshList := ClonedMeshes;
  end;

  fInstanceSource := nil;
  fIsInstance := False;
  UpdateBoundingRadiusFromMesh;
  NotifyChange;
end;

procedure TSceneObject.ResolveInstanceLinks(ARoot: TSceneObject);
var
  I: Integer;
  Source: TSceneObject;
begin
  if fHasPendingInstanceSource then
  begin
    Source := nil;
    if Assigned(ARoot) then
      Source := ARoot.FindObjectByPath(fPendingInstanceSourcePath);

    if Assigned(Source) and (Source <> Self) and (not Source.IsDescendantOf(Self)) then
    begin
      fInstanceSource := Source;
      fIsInstance := True;
      fMeshList.Clear;
    end
    else
    begin
      fInstanceSource := nil;
      fIsInstance := False;
    end;

    fHasPendingInstanceSource := False;
    SetLength(fPendingInstanceSourcePath, 0);
  end;

  UpdateBoundingRadiusFromMesh;

  for I := 0 to Count - 1 do
    if Assigned(ObjectList[I]) then
      ObjectList[I].ResolveInstanceLinks(ARoot);
end;

procedure TSceneObject.MakeInstancesUniqueFromSource(ASource: TSceneObject);
var
  I: Integer;
begin
  if ASource = nil then
    Exit;

  if (Self <> ASource) and fIsInstance and (fInstanceSource = ASource) then
    MakeUniqueFromInstance;

  for I := 0 to Count - 1 do
    if Assigned(ObjectList[I]) then
      ObjectList[I].MakeInstancesUniqueFromSource(ASource);
end;

constructor TSceneObject.Create(aOwner: TSceneObject);
begin
  inherited Create;

  fIsGizmo := False;
  SetLength(fObjectList, 0);
  SetLength(fLightList, 0);
  fPosition.Init(0, 0, 0);
  fScale.Init(1, 1, 1);

  fOrientation.Init;
  fRotationEuler.Init(0, 0, 0);
  RebuildModelMatrix;
  SetName('DummyObject');

  fCamera := nil;
  fParticleSystemList := TParticleSystemList.Create;
  fBillboardList := TBillboardList.Create;
  fAnimatedSpriteList := TAnimatedSpriteList.Create;
  fAudioEmitterList := TSceneAudioEmitterList.Create;
  fScriptState := TSceneObjectScriptState.Create;
  fAudioListener := False;
  fAudioListenerVelocity := Vector3(0, 0, 0);
  fAudioListenerFront := Vector3(0, 0, -1);
  fAudioListenerTop := Vector3(0, 1, 0);
  fAudioDistanceFactor := 1.0;
  fAudioRolloffFactor := 1.0;
  fAudioDopplerFactor := 1.0;
  fWindSettings := TWindActorSettings.Disabled;
  fWindTime := 0.0;
  fWindPoseApplied := False;
  fMeshList := TMeshList.Create;
  fIsInstance := False;
  fInstanceSource := nil;
  fHasPendingInstanceSource := False;
  SetLength(fPendingInstanceSourcePath, 0);

  if aOwner = nil then
  begin
    fIsRoot := True;
    fParent := nil;
    fWorldMatrix := fObjectMatrix;
    fWorldMatrixValid := True;
  end
  else
  begin
    fIsRoot := False;
    fParent := aOwner;
    fWorldMatrix := TMatrix4.Identity;
    fWorldMatrixValid := False;
    aOwner.AddObject(Self);
  end;
end;

destructor TSceneObject.Destroy;
var
  i: Integer;
  SceneRoot: TSceneObject;
begin
  if Assigned(fOnDestroy) then
    fOnDestroy(Self);

  SceneRoot := RootObject;
  if Assigned(SceneRoot) and (SceneRoot <> Self) then
    SceneRoot.MakeInstancesUniqueFromSource(Self);

  // Remove this object from its parent (prevents dangling pointer)
  if fParent <> nil then
    fParent.DetachObject(Self);

  // Free children in reverse order (they will also detach themselves)
  for i := Count - 1 downto 0 do
    ObjectList[i].Free;

  for i := Length(fLightList) - 1 downto 0 do
    fLightList[i].Free;
  SetLength(fLightList, 0);

  fMeshList.Free;
  fParticleSystemList.Free;
  fBillboardList.Free;
  fAnimatedSpriteList.Free;
  fAudioEmitterList.Free;
  fScriptState.Free;

  if fCamera <> nil then
    fCamera.Free;

  inherited Destroy;
end;

function TSceneObject.AddObject(aObject: TSceneObject): Integer;
begin
  AttachObject(Length(fObjectList), aObject);
  Result := Length(fObjectList) - 1;
end;

function TSceneObject.CreateObject: TSceneObject;
begin
  Result := TSceneObject.Create(Self);
end;

function TSceneObject.IndexOfObject(aObject: TSceneObject): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to Length(fObjectList) - 1 do
    if fObjectList[I] = aObject then
      Exit(I);
end;

function TSceneObject.MoveObject(aObject: TSceneObject; NewIndex: Integer): Boolean;
var
  OldIndex, I: Integer;
  Obj: TSceneObject;
begin
  Result := False;
  OldIndex := IndexOfObject(aObject);
  if OldIndex < 0 then
    Exit;

  if NewIndex < 0 then
    NewIndex := 0;
  if NewIndex >= Length(fObjectList) then
    NewIndex := Length(fObjectList) - 1;

  if OldIndex = NewIndex then
    Exit(True);

  Obj := fObjectList[OldIndex];
  if OldIndex < NewIndex then
  begin
    for I := OldIndex to NewIndex - 1 do
      fObjectList[I] := fObjectList[I + 1];
  end
  else
  begin
    for I := OldIndex downto NewIndex + 1 do
      fObjectList[I] := fObjectList[I - 1];
  end;

  fObjectList[NewIndex] := Obj;
  NotifyChange;
  Result := True;
end;

procedure TSceneObject.AttachObject(atIndex: Integer; aSceneObject: TSceneObject);
var
  idx, j: Integer;
  oldParent: TSceneObject;
begin
  if aSceneObject = nil then
    raise Exception.Create('Cannot insert nil object into scene');

  if aSceneObject.fParent <> nil then
  begin
    oldParent := aSceneObject.fParent;
    for idx := 0 to Length(oldParent.fObjectList) - 1 do
    begin
      if oldParent.fObjectList[idx] = aSceneObject then
      begin
        // Remove by shifting remaining elements left
        for j := idx to Length(oldParent.fObjectList) - 2 do
          oldParent.fObjectList[j] := oldParent.fObjectList[j + 1];
        SetLength(oldParent.fObjectList, Length(oldParent.fObjectList) - 1);
        Break;
      end;
    end;
  end;

  if atIndex < 0 then atIndex := 0;
  if atIndex > Length(fObjectList) then atIndex := Length(fObjectList);

  SetLength(fObjectList, Length(fObjectList) + 1);

  for idx := Length(fObjectList) - 1 downto atIndex + 1 do
    fObjectList[idx] := fObjectList[idx - 1];

  fObjectList[atIndex] := aSceneObject;
  aSceneObject.fParent := Self;
  aSceneObject.NotifyChange;
end;

procedure TSceneObject.DetachObject(aObject: TSceneObject);
var
  i, j: Integer;
begin
  for i := 0 to Length(fObjectList) - 1 do
  begin
    if fObjectList[i] = aObject then
    begin
      aObject.fParent := nil;
      aObject.NotifyChange;

      for j := i to Length(fObjectList) - 2 do
        fObjectList[j] := fObjectList[j + 1];

      SetLength(fObjectList, Length(fObjectList) - 1);
      Exit;
    end;
  end;
end;

procedure TSceneObject.DeleteObject(aIndex: Integer);
var
  obj: TSceneObject;
  i: Integer;
begin
  if (aIndex < 0) or (aIndex >= Length(fObjectList)) then
    raise Exception.CreateFmt('DeleteObject: Index %d out of bounds', [aIndex]);

  obj := fObjectList[aIndex];

  // Shift left from aIndex +1 to end
  for i := aIndex to Length(fObjectList) - 2 do
    fObjectList[i] := fObjectList[i + 1];

  SetLength(fObjectList, Length(fObjectList) - 1);

  obj.Free;
end;

procedure TSceneObject.DeleteObject(aObject: TSceneObject);
var
  i: Integer;
begin
  for i := 0 to Length(fObjectList) -1 do
    if fObjectList[i] = aObject then
      begin
        DeleteObject(i);
        Break;
      end;
end;

procedure TSceneObject.CombineMeshLists;

  procedure TransformVertices(const M, NormalMat: TMatrix4;
    const SrcMesh: TMesh; out DestMesh: TMesh);
  var
    i: Integer;
    NewVerts: TArray<TVertex>;
    NewIndices: TArray<GLuint>;
    Pos4, Norm4, Tan4, Bit4: TVector4;
  begin
    if (SrcMesh = nil) or (SrcMesh.VertexCount = 0) then
    begin
      DestMesh := nil;
      Exit;
    end;

    SetLength(NewVerts, SrcMesh.VertexCount);
    for i := 0 to SrcMesh.VertexCount - 1 do
    begin
      Pos4 := M * Vector4(SrcMesh.Vertices[i].Position, 1.0);
      NewVerts[i].Position := Vector3(Pos4);

      Norm4 := NormalMat * Vector4(SrcMesh.Vertices[i].Normal, 0.0);
      NewVerts[i].Normal := Vector3(Norm4).Normalize;

      Tan4 := NormalMat * Vector4(SrcMesh.Vertices[i].Tangent, 0.0);
      NewVerts[i].Tangent := Vector3(Tan4).Normalize;

      Bit4 := NormalMat * Vector4(SrcMesh.Vertices[i].Bitangent, 0.0);
      NewVerts[i].Bitangent := Vector3(Bit4).Normalize;

      NewVerts[i].TexCoord := SrcMesh.Vertices[i].TexCoord;
    end;

    SetLength(NewIndices, SrcMesh.IndexCount);
    for i := 0 to SrcMesh.IndexCount - 1 do
      NewIndices[i] := SrcMesh.Indices[i];

    DestMesh := TMesh.Create(NewVerts, NewIndices, SrcMesh.Name, SrcMesh.MeshType);
    // Copy rendering properties
    DestMesh.MaterialLibrary := SrcMesh.MaterialLibrary;
    DestMesh.LibMaterialname := SrcMesh.LibMaterialname;
    DestMesh.OnRender := SrcMesh.OnRender;
  end;

  procedure CollectAndAddMeshes(Obj: TSceneObject; const ParentInvWorld: TMatrix4);
  var
    i: Integer;
    ObjToParent: TMatrix4;
    MeshToParent: TMatrix4;
    NormMat: TMatrix4;
    M3: TMatrix3;
    NewMesh: TMesh;
  begin
    if Obj = nil then Exit;

    // Transform from Obj's world space to parent's local space
    ObjToParent := ParentInvWorld * Obj.fWorldMatrix;

    // Process each mesh in the current object
    if Assigned(Obj.fMeshList) then
    begin
      for i := 0 to Obj.fMeshList.Count - 1 do
        if Assigned(Obj.fMeshList.Item[i]) then
        begin
          MeshToParent := ObjToParent * Obj.fMeshList.Item[i].LocalMatrix;
          M3 := Matrix3(MeshToParent);
          NormMat := Matrix4(M3.Inverse.Transpose);
          TransformVertices(MeshToParent, NormMat, Obj.fMeshList.Item[i], NewMesh);
          if NewMesh <> nil then
            Self.fMeshList.AddMeshToList(NewMesh);
        end;
    end;

    // Recurse into children of this object
    for i := 0 to Obj.Count - 1 do
      CollectAndAddMeshes(Obj.ObjectList[i], ParentInvWorld);
  end;

var
  i: Integer;
  ChildrenCopy: TArray<TSceneObject>;
begin
  // Ensure all world matrices are up to date
  UpdateWorldMatrices;

  // Collect all meshes from every child and descendant,
  // transform them into this object's local space,
  // and add them as individual meshes to our MeshList.
  for i := 0 to Count - 1 do
    if Assigned(ObjectList[i]) then
      CollectAndAddMeshes(ObjectList[i], Self.fWorldMatrix.Inverse);

  // Delete all child objects (they are no longer needed)
  ChildrenCopy := Copy(fObjectList);   // copy because list will change
  for i := 0 to Length(ChildrenCopy) - 1 do
    if Assigned(ChildrenCopy[i]) then
      ChildrenCopy[i].Free;

  // Update bounding radius (now includes the newly added meshes)
  UpdateBoundingRadiusFromMesh;
  NotifyChange;
end;

procedure TSceneObject.WeldMeshes(KeepChilds: Boolean = True);
begin
  // PlaceHolder
end;

function TSceneObject.GetMeshListCopy: TMeshList;
var
  Meshes: TMeshList;
begin
  Meshes := EffectiveMeshList;
  if Assigned(Meshes) then
    Result := Meshes.Clone
  else
    Result := TMeshList.Create;
end;

function TSceneObject.CreateLight: TLight;
begin
  SetLength(fLightList, Length(fLightList) + 1);
  Result := TLight.Create;
  Result.Name := fName;
  fLightList[High(fLightList)] := Result;
end;

function TSceneObject.LightsCount: Integer;
begin
  Result := Length(fLightList);
end;

procedure TSceneObject.NotifyChange;
var
  i: Integer;
begin
  fWorldMatrixValid := False;
  for i := 0 to Count - 1 do
    if ObjectList[i] <> nil then
      ObjectList[i].NotifyChange;   // Recursively invalidate children
end;

procedure TSceneObject.UpdateWorldMatrices(const ParentWorld: TMatrix4);
var
  i: Integer;
begin
  if not fWorldMatrixValid then
  begin
    if fParent = nil then
      fWorldMatrix := fObjectMatrix
    else
      fWorldMatrix := ParentWorld * fObjectMatrix;

    fWorldMatrixValid := True;

      // Update all meshes in the list
      for i := 0 to fMeshList.Count - 1 do
        if Assigned(fMeshList.Item[i]) then
          begin
            fMeshList.Item[i].ParentModelMatrix := fWorldMatrix;
            //GetBoundingRadius; // MARK
          end;


    // for now is disabled
    {if fCamera <> nil then
    begin
      fCamera.Position := Vector3(fWorldMatrix.Columns[3]);

      // Forward vector from world matrix
      fCamera.Front := Vector3(-fWorldMatrix.Columns[2].X, -fWorldMatrix.Columns[2].Y, -fWorldMatrix.Columns[2].Z);

      fCamera.Front.Normalize;
    end;}

    UpdateLights;   // <- runs for every node
  end;

  // Recurse children
  for i := 0 to Count - 1 do
    if Assigned(ObjectList[i]) then
      ObjectList[i].UpdateWorldMatrices(fWorldMatrix);
end;

procedure TSceneObject.UpdateWorldMatrices;
begin
  UpdateWorldMatrices(TMatrix4.Identity); // root parent is identity
end;

procedure TSceneObject.UpdateLights;
var
  i: Integer;
  Light: TLight;
  LocalDir, TargetDir: TVector3;
  WorldDir: TVector4;
begin
  for i := 0 to Length(fLightList) - 1 do
  begin
    Light := fLightList[i];
    if not Assigned(Light) then Continue;

    // Position = translation part (column 3 of the world matrix)
    Light.Position := Vector3(fWorldMatrix.Columns[3]);

    // For directional and spot lights, rotate a default local forward direction
    if Light.LightType in [ltDirectional, ltSpot] then
    begin
      if Light.UseTarget then
      begin
        if Light.ResolveTargetDirection(TargetDir) then
        begin
          Light.Direction := TargetDir;
          LookAtDirection(TargetDir);
          Continue;
        end;
      end;

      // Local forward direction (adjust to your coordinate system)
      LocalDir := Vector3(0, 0, -1);
      // Transform with W=0 - only rotation+scale, no translation
      WorldDir := fWorldMatrix * Vector4(LocalDir, 0);
      Light.Direction := Vector3(WorldDir);
    end;
  end;
end;

function TSceneObject.CreateCamera: TCamera;
begin
  if fCamera <> nil then
    FreeAndNil(fCamera);

  fCamera := TCamera.Create;

  Result := fCamera;
end;

function TSceneObject.Clone: TSceneObject;
var
  i: Integer;
  childClone: TSceneObject;
  SourceMeshes: TMeshList;
  ClonedMeshes: TMeshList;
begin
  Result := TSceneObject.Create(nil);
  Result.fIsRoot := False;
  Result.fParent := nil;
  Result.fWorldMatrix := TMatrix4.Identity;
  Result.fWorldMatrixValid := False;

  Result.fName := fName + ' (copy)';
  Result.fPosition := fPosition;
  Result.fScale := fScale;
  Result.fOrientation := fOrientation;
  Result.fRotationEuler := fRotationEuler;
  Result.fIsInstance := False;
  Result.fInstanceSource := nil;
  Result.fWireframe := fWireframe;
  Result.fAudioListener := fAudioListener;
  Result.fAudioListenerVelocity := fAudioListenerVelocity;
  Result.fAudioListenerFront := fAudioListenerFront;
  Result.fAudioListenerTop := fAudioListenerTop;
  Result.fAudioDistanceFactor := fAudioDistanceFactor;
  Result.fAudioRolloffFactor := fAudioRolloffFactor;
  Result.fAudioDopplerFactor := fAudioDopplerFactor;
  Result.fWindSettings := fWindSettings;
  Result.fWindTime := 0.0;
  Result.fWindPoseApplied := False;
  Result.RebuildModelMatrix;

  // Clone all effective meshes. Copy/paste must be safe even if the original
  // instance source is deleted before the clipboard is pasted.
  SourceMeshes := EffectiveMeshList;
  if Assigned(SourceMeshes) then
  begin
    ClonedMeshes := SourceMeshes.Clone;
    Result.fMeshList.Free;
    Result.fMeshList := ClonedMeshes;
  end;

  // Copy lights (unchanged)
  for i := 0 to Length(fLightList) - 1 do
  begin
    Result.CreateLight;
    Result.fLightList[i].Assign(fLightList[i]);
  end;

  Result.fParticleSystemList.Free;
  if Assigned(fParticleSystemList) then
    Result.fParticleSystemList := fParticleSystemList.Clone
  else
    Result.fParticleSystemList := TParticleSystemList.Create;

  Result.fBillboardList.Free;
  if Assigned(fBillboardList) then
    Result.fBillboardList := fBillboardList.Clone
  else
    Result.fBillboardList := TBillboardList.Create;

  Result.fAnimatedSpriteList.Free;
  if Assigned(fAnimatedSpriteList) then
    Result.fAnimatedSpriteList := fAnimatedSpriteList.Clone
  else
    Result.fAnimatedSpriteList := TAnimatedSpriteList.Create;

  Result.fAudioEmitterList.Free;
  if Assigned(fAudioEmitterList) then
    Result.fAudioEmitterList := fAudioEmitterList.Clone
  else
    Result.fAudioEmitterList := TSceneAudioEmitterList.Create;

  Result.fScriptState.Assign(fScriptState);

  // Clone children (unchanged)
  for i := 0 to Count - 1 do
  begin
    childClone := ObjectList[i].Clone;
    Result.AttachObject(Result.Count, childClone);
  end;

  Result.UpdateBoundingRadiusFromMesh;
  Result.fCamera := nil;
end;

procedure TSceneObject.SaveToStream(Stream: TStream);
var
  I: Integer;
  LightCount: Integer;
  SavedChildCount: Integer;
  HasCameraValue: Boolean;
  SavedIsInstance: Boolean;
  HasInstanceSourceValue: Boolean;
  InstanceSourcePath: TArray<Integer>;
  InstancePathCount: Integer;
begin
  HasInstanceSourceValue := fIsInstance and Assigned(fInstanceSource) and
    (fInstanceSource.RootObject = RootObject) and
    fInstanceSource.BuildPathFromRoot(InstanceSourcePath);
  SavedIsInstance := fIsInstance and HasInstanceSourceValue;

  WriteStringToStream(Stream, fName);
  Stream.WriteBuffer(fPosition, SizeOf(fPosition));
  Stream.WriteBuffer(fScale, SizeOf(fScale));
  Stream.WriteBuffer(fOrientation, SizeOf(fOrientation));
  Stream.WriteBuffer(SavedIsInstance, SizeOf(SavedIsInstance));
  Stream.WriteBuffer(fWireframe, SizeOf(fWireframe));
  Stream.WriteBuffer(fIsGizmo, SizeOf(fIsGizmo));

  Stream.WriteBuffer(HasInstanceSourceValue, SizeOf(HasInstanceSourceValue));
  if HasInstanceSourceValue then
  begin
    InstancePathCount := Length(InstanceSourcePath);
    Stream.WriteBuffer(InstancePathCount, SizeOf(InstancePathCount));
    if InstancePathCount > 0 then
      Stream.WriteBuffer(InstanceSourcePath[0], InstancePathCount * SizeOf(Integer));
  end;

  fMeshList.SaveToStream(Stream);

  LightCount := Length(fLightList);
  Stream.WriteBuffer(LightCount, SizeOf(LightCount));
  for I := 0 to LightCount - 1 do
    fLightList[I].SaveToStream(Stream);

  HasCameraValue := fCamera <> nil;
  Stream.WriteBuffer(HasCameraValue, SizeOf(HasCameraValue));
  if HasCameraValue then
    fCamera.SaveToStream(Stream);

  fParticleSystemList.SaveToStream(Stream);

  fBillboardList.SaveToStream(Stream);

  fAnimatedSpriteList.SaveToStream(Stream);

  Stream.WriteBuffer(fAudioListener, SizeOf(fAudioListener));
  Stream.WriteBuffer(fAudioListenerVelocity, SizeOf(fAudioListenerVelocity));
  Stream.WriteBuffer(fAudioListenerFront, SizeOf(fAudioListenerFront));
  Stream.WriteBuffer(fAudioListenerTop, SizeOf(fAudioListenerTop));
  Stream.WriteBuffer(fAudioDistanceFactor, SizeOf(fAudioDistanceFactor));
  Stream.WriteBuffer(fAudioRolloffFactor, SizeOf(fAudioRolloffFactor));
  Stream.WriteBuffer(fAudioDopplerFactor, SizeOf(fAudioDopplerFactor));
  fAudioEmitterList.SaveToStream(Stream);

  fScriptState.SaveToStream(Stream);

  fWindSettings.SaveToStream(Stream);

  SavedChildCount := 0;
  for I := 0 to Count - 1 do
    if Assigned(ObjectList[I]) and (not ObjectList[I].IsGizmo) then
      Inc(SavedChildCount);

  Stream.WriteBuffer(SavedChildCount, SizeOf(SavedChildCount));
  for I := 0 to Count - 1 do
    if Assigned(ObjectList[I]) and (not ObjectList[I].IsGizmo) then
      ObjectList[I].SaveToStream(Stream);
end;

class function TSceneObject.LoadFromStream(Stream: TStream; AOwner: TSceneObject;
  SceneVersion: Integer): TSceneObject;
var
  I: Integer;
  LightCount: Integer;
  ChildCount: Integer;
  InstancePathCount: Integer;
  HasCameraValue: Boolean;
  HasParticleSystemValue: Boolean;
  HasBillboardValue: Boolean;
  HasInstanceSourceValue: Boolean;
begin
  if SceneLoadDepth >= MAX_SCENE_DEPTH then
    raise Exception.CreateFmt('Scene hierarchy exceeds the maximum depth of %d.',
      [MAX_SCENE_DEPTH]);
  Inc(SceneLoadDepth);
  Result := nil;
  try
    try
      Result := TSceneObject.Create(AOwner);
      Result.fName := ReadStringFromStream(Stream);
    Stream.ReadBuffer(Result.fPosition, SizeOf(Result.fPosition));
    Stream.ReadBuffer(Result.fScale, SizeOf(Result.fScale));
    Stream.ReadBuffer(Result.fOrientation, SizeOf(Result.fOrientation));
    Result.fOrientation := Result.fOrientation.Normalize;
    Result.fRotationEuler := QuaternionToEulerXYZ(Result.fOrientation);
    Stream.ReadBuffer(Result.fIsInstance, SizeOf(Result.fIsInstance));
    Stream.ReadBuffer(Result.fWireframe, SizeOf(Result.fWireframe));
    Stream.ReadBuffer(Result.fIsGizmo, SizeOf(Result.fIsGizmo));

    if SceneVersion >= 4 then
    begin
      Stream.ReadBuffer(HasInstanceSourceValue, SizeOf(HasInstanceSourceValue));
      if HasInstanceSourceValue then
      begin
        Stream.ReadBuffer(InstancePathCount, SizeOf(InstancePathCount));
        if (InstancePathCount < 0) or (InstancePathCount > 4096) then
          raise Exception.Create('Invalid instance source path in scene stream.');
        if Int64(InstancePathCount) * SizeOf(Integer) > Stream.Size - Stream.Position then
          raise Exception.Create('Truncated instance source path in scene stream.');

        SetLength(Result.fPendingInstanceSourcePath, InstancePathCount);
        if InstancePathCount > 0 then
          Stream.ReadBuffer(Result.fPendingInstanceSourcePath[0],
            InstancePathCount * SizeOf(Integer));
        Result.fHasPendingInstanceSource := True;
      end
      else
        Result.fIsInstance := False;
    end
    else
      Result.fIsInstance := False;

    Result.RebuildModelMatrix;

    Result.fMeshList.LoadFromStream(Stream);

    Stream.ReadBuffer(LightCount, SizeOf(LightCount));
    if (LightCount < 0) or (LightCount > MAX_SCENE_LIGHTS) then
      raise Exception.Create('Invalid light count in scene stream.');
    SetLength(Result.fLightList, LightCount);
    for I := 0 to LightCount - 1 do
    begin
      Result.fLightList[I] := TLight.Create;
      Result.fLightList[I].LoadFromStream(Stream, SceneVersion);
    end;

    Stream.ReadBuffer(HasCameraValue, SizeOf(HasCameraValue));
    if HasCameraValue then
    begin
      Result.fCamera := TCamera.Create;
      Result.fCamera.LoadFromStream(Stream);
    end;

    if SceneVersion >= 7 then
      Result.fParticleSystemList.LoadFromStream(Stream)
    else if SceneVersion >= 2 then
    begin
      Stream.ReadBuffer(HasParticleSystemValue, SizeOf(HasParticleSystemValue));
      if HasParticleSystemValue then
      begin
        Result.fParticleSystemList.AddParticleSystemToList(TParticleSystem.Create);
        Result.fParticleSystemList.Item[Result.fParticleSystemList.Count - 1].LoadFromStream(Stream);
      end;
    end;

    if SceneVersion >= 6 then
      Result.fBillboardList.LoadFromStream(Stream)
    else if SceneVersion >= 5 then
    begin
      Stream.ReadBuffer(HasBillboardValue, SizeOf(HasBillboardValue));
      if HasBillboardValue then
      begin
        Result.fBillboardList.AddBillboardToList(TBillboard.Create);
        Result.fBillboardList.Item[Result.fBillboardList.Count - 1].LoadFromStream(Stream);
      end;
    end;

    if SceneVersion >= 10 then
      Result.fAnimatedSpriteList.LoadFromStream(Stream);

    if SceneVersion >= 8 then
    begin
      Stream.ReadBuffer(Result.fAudioListener, SizeOf(Result.fAudioListener));
      Stream.ReadBuffer(Result.fAudioListenerVelocity, SizeOf(Result.fAudioListenerVelocity));
      Stream.ReadBuffer(Result.fAudioListenerFront, SizeOf(Result.fAudioListenerFront));
      Stream.ReadBuffer(Result.fAudioListenerTop, SizeOf(Result.fAudioListenerTop));
      Stream.ReadBuffer(Result.fAudioDistanceFactor, SizeOf(Result.fAudioDistanceFactor));
      Stream.ReadBuffer(Result.fAudioRolloffFactor, SizeOf(Result.fAudioRolloffFactor));
      Stream.ReadBuffer(Result.fAudioDopplerFactor, SizeOf(Result.fAudioDopplerFactor));
      Result.fAudioEmitterList.LoadFromStream(Stream);
      Result.fAudioDistanceFactor := Max(0.0, Result.fAudioDistanceFactor);
      Result.fAudioRolloffFactor := Max(0.0, Result.fAudioRolloffFactor);
      Result.fAudioDopplerFactor := Max(0.0, Result.fAudioDopplerFactor);
    end;

    if SceneVersion >= 9 then
      Result.fScriptState.LoadFromStream(Stream, SceneVersion)
    else
      Result.fScriptState.Clear;

    if SceneVersion >= 11 then
      Result.fWindSettings.LoadFromStream(Stream)
    else
      Result.fWindSettings := TWindActorSettings.Disabled;

    Stream.ReadBuffer(ChildCount, SizeOf(ChildCount));
    if (ChildCount < 0) or (ChildCount > MAX_SCENE_CHILDREN) then
      raise Exception.Create('Invalid child count in scene stream.');
    for I := 0 to ChildCount - 1 do
      TSceneObject.LoadFromStream(Stream, Result, SceneVersion);

    Result.UpdateBoundingRadiusFromMesh;
    Result.NotifyChange;
    except
      Result.Free;
      raise;
    end;
  finally
    Dec(SceneLoadDepth);
  end;
end;

function TSceneObject.AddParticleSystem: TParticleSystem;
begin
  if fParticleSystemList = nil then
    fParticleSystemList := TParticleSystemList.Create;
  Result := fParticleSystemList.CreateParticleSystem;
end;

function TSceneObject.CreateParticleSystem: TParticleSystem;
begin
  Result := GetParticleSystem;
  if Result = nil then
    Result := AddParticleSystem;
end;

function TSceneObject.GetParticleSystemItem(aIndex: Integer): TParticleSystem;
begin
  if Assigned(fParticleSystemList) then
    Result := fParticleSystemList.Item[aIndex]
  else
    Result := nil;
end;

function TSceneObject.RemoveParticleSystem(aIndex: Integer): Boolean;
begin
  Result := Assigned(fParticleSystemList) and
    fParticleSystemList.DeleteParticleSystem(aIndex);
end;

function TSceneObject.RemoveParticleSystem(
  aParticleSystem: TParticleSystem): Boolean;
begin
  Result := Assigned(fParticleSystemList) and
    fParticleSystemList.DeleteParticleSystem(aParticleSystem);
end;

procedure TSceneObject.RemoveParticleSystem;
begin
  RemoveParticleSystem(0);
end;

function TSceneObject.AddBillboard: TBillboard;
begin
  if fBillboardList = nil then
    fBillboardList := TBillboardList.Create;
  Result := fBillboardList.CreateBillboard;
end;

function TSceneObject.CreateBillboard: TBillboard;
begin
  Result := GetBillboard;
  if Result = nil then
    Result := AddBillboard;
end;

function TSceneObject.GetBillboardItem(aIndex: Integer): TBillboard;
begin
  if Assigned(fBillboardList) then
    Result := fBillboardList.Item[aIndex]
  else
    Result := nil;
end;

function TSceneObject.RemoveBillboard(aIndex: Integer): Boolean;
begin
  Result := Assigned(fBillboardList) and fBillboardList.DeleteBillboard(aIndex);
end;

function TSceneObject.RemoveBillboard(aBillboard: TBillboard): Boolean;
begin
  Result := Assigned(fBillboardList) and
    fBillboardList.DeleteBillboard(aBillboard);
end;

procedure TSceneObject.RemoveBillboard;
begin
  RemoveBillboard(0);
end;

function TSceneObject.AddAnimatedSprite: TAnimatedSprite;
begin
  if fAnimatedSpriteList = nil then
    fAnimatedSpriteList := TAnimatedSpriteList.Create;
  Result := fAnimatedSpriteList.CreateAnimatedSprite;
end;

function TSceneObject.CreateAnimatedSprite: TAnimatedSprite;
begin
  Result := GetAnimatedSprite;
  if Result = nil then
    Result := AddAnimatedSprite;
end;

function TSceneObject.GetAnimatedSpriteItem(aIndex: Integer): TAnimatedSprite;
begin
  if Assigned(fAnimatedSpriteList) then
    Result := fAnimatedSpriteList.Item[aIndex]
  else
    Result := nil;
end;

function TSceneObject.RemoveAnimatedSprite(aIndex: Integer): Boolean;
begin
  Result := Assigned(fAnimatedSpriteList) and
    fAnimatedSpriteList.DeleteAnimatedSprite(aIndex);
end;

function TSceneObject.RemoveAnimatedSprite(
  aAnimatedSprite: TAnimatedSprite): Boolean;
begin
  Result := Assigned(fAnimatedSpriteList) and
    fAnimatedSpriteList.DeleteAnimatedSprite(aAnimatedSprite);
end;

procedure TSceneObject.RemoveAnimatedSprite;
begin
  RemoveAnimatedSprite(0);
end;

function TSceneObject.AddAudioEmitter: TSceneAudioEmitter;
begin
  if fAudioEmitterList = nil then
    fAudioEmitterList := TSceneAudioEmitterList.Create;
  Result := fAudioEmitterList.CreateEmitter;
end;

function TSceneObject.CreateAudioEmitter: TSceneAudioEmitter;
begin
  Result := GetAudioEmitter;
  if Result = nil then
    Result := AddAudioEmitter;
end;

function TSceneObject.GetAudioEmitterItem(
  aIndex: Integer): TSceneAudioEmitter;
begin
  if Assigned(fAudioEmitterList) then
    Result := fAudioEmitterList.Item[aIndex]
  else
    Result := nil;
end;

function TSceneObject.RemoveAudioEmitter(aIndex: Integer): Boolean;
begin
  Result := Assigned(fAudioEmitterList) and
    fAudioEmitterList.DeleteEmitter(aIndex);
end;

function TSceneObject.RemoveAudioEmitter(
  aEmitter: TSceneAudioEmitter): Boolean;
begin
  Result := Assigned(fAudioEmitterList) and
    fAudioEmitterList.DeleteEmitter(aEmitter);
end;

procedure TSceneObject.RemoveAudioEmitter;
begin
  RemoveAudioEmitter(0);
end;

procedure TSceneObject.UpdateParticles(DeltaTime: Single; NewTime: Double);
var
  I: Integer;
begin
  if Assigned(fParticleSystemList) then
    for I := 0 to fParticleSystemList.Count - 1 do
      if Assigned(fParticleSystemList.Item[I]) then
        fParticleSystemList.Item[I].Update(DeltaTime, NewTime, fWorldMatrix);

  if Assigned(fAnimatedSpriteList) then
    fAnimatedSpriteList.Update(DeltaTime);

  for I := 0 to Count - 1 do
    if Assigned(ObjectList[I]) then
      ObjectList[I].UpdateParticles(DeltaTime, NewTime);
end;

procedure TSceneObject.UpdateAnimations(DeltaTime: Single);
var
  I: Integer;
begin
  if HasVertexWindAnimation then
    fWindTime := fWindTime + System.Math.Max(0.0, DeltaTime);

  // Instances share their source mesh list and therefore its animator. Updating
  // only the owning object prevents one controller from advancing repeatedly.
  if (not fIsInstance) and Assigned(fMeshList) then
  begin
    fMeshList.UpdateAnimations(DeltaTime);
    if HasBoneWindAnimation then
    begin
      if ApplyWindAnimation(DeltaTime) then
      begin
        fMeshList.ApplyCurrentPose;
        UpdateBoundingRadiusFromMesh;
      end;
    end
    else
      ResetWindAnimationPose;

    if Assigned(fMeshList.AnimationController) then
      UpdateBoundingRadiusFromMesh;
  end;

  for I := 0 to Count - 1 do
    if Assigned(ObjectList[I]) then
      ObjectList[I].UpdateAnimations(DeltaTime);
end;

function TSceneObject.AnimationCount: Integer;
var
  Animator: TSkeletonAnimator;
begin
  Animator := AnimationController;
  if Assigned(Animator) then
    Result := Animator.AnimationCount
  else
    Result := 0;
end;

function TSceneObject.AnimationName(AIndex: Integer): string;
var
  Animator: TSkeletonAnimator;
  Clip: TSkeletonAnimationClip;
begin
  Result := '';
  Animator := AnimationController;
  if not Assigned(Animator) then
    Exit;
  Clip := Animator.Animations[AIndex];
  if Assigned(Clip) then
    Result := Clip.Name;
end;

function TSceneObject.PlayAnimation(const AName: string; ALoop: Boolean;
  ABlendDuration: Single): Boolean;
begin
  Result := Assigned(AnimationController) and
    AnimationController.Play(AName, ALoop, ABlendDuration);
end;

procedure TSceneObject.PauseAnimation;
begin
  if Assigned(AnimationController) then
    AnimationController.Pause;
end;

procedure TSceneObject.ResumeAnimation;
begin
  if Assigned(AnimationController) then
    AnimationController.Resume;
end;

procedure TSceneObject.StopAnimation(AResetToBindPose: Boolean);
begin
  if Assigned(AnimationController) then
    AnimationController.Stop(AResetToBindPose);
end;

function TSceneObject.IsDescendantOf(aPotentialAncestor: TSceneObject): Boolean;
var
  obj: TSceneObject;
begin
  Result := False;
  obj := Self.fParent;
  while Assigned(obj) do
  begin
    if obj = aPotentialAncestor then
      Exit(True);
    obj := obj.fParent;
  end;
end;

procedure TSceneObject.UpdateBoundingRadiusFromMesh;
var
  Meshes: TMeshList;
begin
  Meshes := EffectiveMeshList;
  if Assigned(Meshes) then
    fInternalBoundingRadius := Meshes.GetBoundingRadius
  else
    fInternalBoundingRadius := 0;
end;

function TSceneObject.HasGeometry: Boolean;
var
  i: Integer;
  Meshes: TMeshList;
begin
  Result := False;
  Meshes := EffectiveMeshList;
  if not Assigned(Meshes) then
    Exit;

  for i := 0 to Meshes.Count - 1 do
    if Assigned(Meshes.Item[i]) and
       (Length(Meshes.Item[i].Indices) > 0) and
       (Length(Meshes.Item[i].Vertices) > 0) then
      Exit(True);
end;

function TSceneObject.HasParticles: Boolean;
begin
  Result := Assigned(fParticleSystemList) and (fParticleSystemList.Count > 0);
end;

function TSceneObject.HasBillboard: Boolean;
begin
  Result := Assigned(fBillboardList) and (fBillboardList.Count > 0);
end;

function TSceneObject.HasAnimatedSprite: Boolean;
begin
  Result := Assigned(fAnimatedSpriteList) and (fAnimatedSpriteList.Count > 0);
end;

function TSceneObject.HasAudio: Boolean;
begin
  Result := fAudioListener or
    (Assigned(fAudioEmitterList) and (fAudioEmitterList.Count > 0));
end;

function TSceneObject.HasSkeletonAnimation: Boolean;
begin
  Result := Assigned(AnimationController);
end;

function TSceneObject.HasCamera: Boolean;
begin
  Result := fCamera <> nil;
end;

function TSceneObject.GetBoundingRadius: Single;
var
  MaxScale: Single;
  Meshes: TMeshList;
  Source: TSceneObject;
  Guard: Integer;
begin
  Meshes := EffectiveMeshList;
  if (Meshes = nil) or (Meshes.Count = 0) then
    fBoundingRadius := 0
  else
    begin
      if fIsInstance and Assigned(fInstanceSource) then
      begin
        Source := fInstanceSource;
        Guard := 0;
        while Source.fIsInstance and Assigned(Source.fInstanceSource) and
              (Source.fInstanceSource <> Source) and (Guard < 64) do
        begin
          Source := Source.fInstanceSource;
          Inc(Guard);
        end;
        if Assigned(Source) and (Source <> Self) then
          fInternalBoundingRadius := Source.fInternalBoundingRadius;
      end;

      MaxScale := System.Math.Max(Abs(Scale.X),
        System.Math.Max(Abs(Scale.Y), Abs(Scale.Z)));
      fBoundingRadius := fInternalBoundingRadius * MaxScale;
    end;

  Result := fBoundingRadius;
end;

{ TSceneManager }
function TSceneManager.GetRoot: TSceneObject;
begin
  Result := fRoot;
end;

procedure TSceneManager.SetRoot(aObject: TSceneObject);
var
  OldRoot: TSceneObject;
begin
  if fRoot = aObject then
    Exit;

  OldRoot := fRoot;
  if Assigned(aObject) and Assigned(aObject.fParent) then
    aObject.fParent.DetachObject(aObject);

  fRoot := aObject;
  if Assigned(fRoot) then
    fRoot.fParent := nil;

  OldRoot.Free;
end;

function TSceneManager.GetCount: Integer;
begin
  Result := fRoot.Count;
end;

procedure TSceneManager.SetWireFrame(ModeOn: Boolean);
begin
  fWireFrame := ModeOn;           // keep for possible future use
  if Assigned(fRoot) then
    fRoot.WireFrame := ModeOn;
end;

constructor TSceneManager.Create;
begin
  inherited Create;

  fWireFrame := False;

  fRoot := TSceneObject.Create(nil);
  fRoot.Name := 'ROOT';
end;

destructor TSceneManager.Destroy;
begin
  fRoot.Free;

  inherited Destroy;
end;

procedure TSceneManager.Update;
begin
  fRoot.UpdateWorldMatrices;
end;

procedure TSceneManager.UpdateParticles(DeltaTime: Single; NewTime: Double);
begin
  if Assigned(fRoot) then
  begin
    fRoot.UpdateWorldMatrices;
    fRoot.UpdateParticles(DeltaTime, NewTime);
  end;
end;

procedure TSceneManager.SaveToStream(Stream: TStream);
var
  Version: Integer;
begin
  Stream.WriteBuffer(SCENE_FILE_MAGIC[0], SizeOf(SCENE_FILE_MAGIC));
  Version := SCENE_FILE_VERSION;
  Stream.WriteBuffer(Version, SizeOf(Version));
  WriteStringToStream(Stream, fName);
  fRoot.SaveToStream(Stream);
end;

procedure TSceneManager.LoadFromStream(Stream: TStream);
var
  Magic: array[0..7] of AnsiChar;
  Version: Integer;
  LoadedName: string;
  NewRoot: TSceneObject;
  OldRoot: TSceneObject;
begin
  Stream.ReadBuffer(Magic[0], SizeOf(Magic));
  if not SceneMagicMatches(Magic) then
    raise Exception.Create('Invalid OpenGL Micro Engine scene file.');

  Stream.ReadBuffer(Version, SizeOf(Version));
  if (Version < 1) or (Version > SCENE_FILE_VERSION) then
    raise Exception.CreateFmt('Unsupported scene version: %d.', [Version]);

  LoadedName := ReadStringFromStream(Stream);
  NewRoot := TSceneObject.LoadFromStream(Stream, nil, Version);
  try
    NewRoot.ResolveInstanceLinks(NewRoot);
    OldRoot := fRoot;
    fRoot := NewRoot;
    fName := LoadedName;
    if Assigned(OldRoot) then
      OldRoot.Free;
  except
    NewRoot.Free;
    raise;
  end;
end;
function TSceneManager.AddSceneObject(aSceneObject: TSceneObject): Integer;
begin
  Result := fRoot.AddObject(aSceneObject);
end;

procedure TSceneManager.DeleteObject(aObject: TSceneObject);
begin
  fRoot.DeleteObject(aObject);
end;

function TSceneManager.FindCamera(aObject: TSceneObject): TSceneObject;
var
  i: Integer;
  Obj: TSceneObject;
begin
  if aObject.Camera <> nil then
    Exit(aObject);

  for i := 0 to aObject.Count - 1 do
  begin
    Obj := FindCamera(aObject.ObjectList[i]);

    if Obj <> nil then
      Exit(Obj);
  end;

  Result := nil;
end;

function TSceneManager.FindCamera: TSceneObject;
var
  i: Integer;
begin
  for i := 0 to fRoot.Count - 1 do
  begin
    Result := FindCamera(fRoot.ObjectList[i]);

    if Result <> nil then
      Exit;
  end;

  Result := nil;
end;

function TSceneManager.FindSceneObject(aName: string): TSceneObject;
  function FindInTree(aObject: TSceneObject): TSceneObject;
  var
    i: Integer;
  begin
    Result := nil;
    if aObject = nil then
      Exit;

    if SameText(aObject.Name, aName) then
      Exit(aObject);

    for i := 0 to aObject.Count - 1 do
    begin
      Result := FindInTree(aObject.ObjectList[i]);
      if Result <> nil then
        Exit;
    end;
  end;
begin
  Result := FindInTree(fRoot);
end;

function TSceneManager.FindSceneObject(aIndex: Integer): TSceneObject;
begin
  Result := fRoot.ObjectList[aIndex];
end;

function TSceneManager.GetLights: TArray<TLight>;
var
  Lights: TList<TLight>;

  procedure CollectFrom(aObject: TSceneObject);
  var
    i: Integer;
    Light: TLight;
  begin
    if aObject = nil then
      Exit;

    for i := 0 to aObject.LightsCount - 1 do
    begin
      Light := aObject.Light[i];
      if Assigned(Light) then
        Lights.Add(Light);
    end;

    for i := 0 to aObject.Count - 1 do
      CollectFrom(aObject.ObjectList[i]);
  end;

begin
  Lights := TList<TLight>.Create;
  try
    CollectFrom(fRoot);
    Result := Lights.ToArray;
  finally
    Lights.Free;
  end;
end;

function TSceneManager.IndexOf(aName: string): Integer;
var
  i: Integer;
begin
  if fRoot.Count <= 0 then Exit(-1);

  for i := 0 to fRoot.Count -1 do
    begin
      if fRoot.ObjectList[i].Name = aName then
        Exit(i);
    end;

  // if we are here, nothing is found
  Result := -1;
end;

function TSceneManager.IndexOf(aObject: TSceneObject): Integer;
begin
  Result := IndexOf(aObject.Name);
end;

end.
