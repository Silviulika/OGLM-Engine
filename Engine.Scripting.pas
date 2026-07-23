unit Engine.Scripting;

interface

uses
  Winapi.Windows, Winapi.MultiMon,
  System.Classes, System.SysUtils, System.Math, System.Types,
  System.Generics.Collections, System.Variants,
  dwsComp, dwsExprs, dwsInfo, dwsErrors, dwsSymbols,
  DWS.FastMath,
  dglOpenGL, Neslib.FastMath,
  Managers.Scene, Managers.Material,
  Renderer.Camera, Renderer.Light, Renderer.Mesh, Renderer.Mesh.Factory,
  Renderer.Renderer, Renderer.SkyDome, Renderer.Shader, Renderer.Particles, Renderer.Billboards,
  Engine.Types, Engine.Audio, Engine.Physics, Engine.Animation, Engine.Keyboard,
  Engine.Mouse;

type
  TEngineScriptTargetKind = (
    stkGlobal,
    stkSceneObject,
    stkShader,
    stkMaterial,
    stkRenderTechnique
  );

  TEngineScriptPrefabLoadCallback = function(const AFileName: string;
    AParent: TSceneObject): TSceneObject of object;
  TEngineScriptPrefabDestroyCallback = procedure(AObject: TSceneObject) of object;
  TEngineScriptLogCallback = procedure(const AMessage: string) of object;

  TEngineScriptExecutionResult = record
    Success: Boolean;
    Messages: string;

    class function Ok: TEngineScriptExecutionResult; static;
    class function Error(const AMessages: string): TEngineScriptExecutionResult; static;
  end;

  TEngineScriptAsset = class
  private
    FID: string;
    FName: string;
    FSource: string;
    FEntryPoint: string;
    FDescription: string;
    FAuthor: string;
    FCategory: string;
    FVersionText: string;
    FCreatedAt: TDateTime;
    FModifiedAt: TDateTime;
    FEnabled: Boolean;
    FTargetKind: TEngineScriptTargetKind;
    FTargetName: string;
    FRuntimeTarget: TObject;

    class function NewID: string; static;
  public
    constructor Create; virtual;

    procedure Assign(Source: TEngineScriptAsset);
    procedure Touch;
    procedure SaveToStream(Stream: TStream); overload;
    procedure SaveToStream(Stream: TStream; AVersion: Integer); overload;
    procedure LoadFromStream(Stream: TStream); overload;
    procedure LoadFromStream(Stream: TStream; AVersion: Integer); overload;

    property ID: string read FID write FID;
    property Name: string read FName write FName;
    property Source: string read FSource write FSource;
    property EntryPoint: string read FEntryPoint write FEntryPoint;
    property Description: string read FDescription write FDescription;
    property Author: string read FAuthor write FAuthor;
    property Category: string read FCategory write FCategory;
    property VersionText: string read FVersionText write FVersionText;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property ModifiedAt: TDateTime read FModifiedAt write FModifiedAt;
    property Enabled: Boolean read FEnabled write FEnabled;
    property TargetKind: TEngineScriptTargetKind read FTargetKind write FTargetKind;
    property TargetName: string read FTargetName write FTargetName;
    property RuntimeTarget: TObject read FRuntimeTarget write FRuntimeTarget;
  end;

  TEngineScriptContext = class
  private
    FNextHandle: Integer;
    FObjects: TDictionary<Integer, TObject>;
    FHandles: TDictionary<TObject, Integer>;

    function RegisterHandle(AObject: TObject): Integer;
  public
    Renderer: TRenderer;
    SceneManager: TSceneManager;
    MaterialLibrary: TMaterialLibrary;
    DefaultMaterialName: string;
    DefaultMeshRender: TOnMeshRender;
    PhysicsWorld: TPhysicsWorld;
    AudioEngine: TBassAudioEngine;
    PrefabLoader: TEngineScriptPrefabLoadCallback;
    PrefabDestroyer: TEngineScriptPrefabDestroyCallback;
    LogCallback: TEngineScriptLogCallback;
    DeltaTime: Single;
    TimeSeconds: Double;

    CurrentScriptName: string;
    CurrentEventName: string;
    CurrentTargetKind: TEngineScriptTargetKind;
    CurrentTargetName: string;
    CurrentTarget: TObject;

    constructor Create;
    destructor Destroy; override;

    procedure Bind(ARenderer: TRenderer; ASceneManager: TSceneManager;
      AMaterialLibrary: TMaterialLibrary; const ADefaultMaterialName: string;
      ADefaultMeshRender: TOnMeshRender; APhysicsWorld: TPhysicsWorld = nil;
      AAudioEngine: TBassAudioEngine = nil;
      APrefabLoader: TEngineScriptPrefabLoadCallback = nil;
      APrefabDestroyer: TEngineScriptPrefabDestroyCallback = nil;
      ALogCallback: TEngineScriptLogCallback = nil);
    procedure ClearHandles;

    function HandleOf(AObject: TObject): Integer;
    procedure Forget(AObject: TObject);
    procedure ForgeTSceneObjectTree(AObject: TSceneObject);

    function SceneObjectFromHandle(const AHandle: Integer): TSceneObject;
    function MeshFromHandle(const AHandle: Integer): TMesh;
    function LightFromHandle(const AHandle: Integer): TLight;
    function CameraFromHandle(const AHandle: Integer): TCamera;
    function MaterialFromHandle(const AHandle: Integer): TMaterial;
    function ShaderFromHandle(const AHandle: Integer): TShader;
    function ParticleSystemFromHandle(const AHandle: Integer): TParticleSystem;
    function OwnerOfParticleSystem(AParticleSystem: TParticleSystem): TSceneObject;
    function BillboardFromHandle(const AHandle: Integer): TBillboard;
    function AudioEmitterFromHandle(const AHandle: Integer): TSceneAudioEmitter;
    function PhysicsBodyFromHandle(const AHandle: Integer): TPhysicsBody;

    procedure BeginScript(const AScriptName, AEventName: string;
      ATargetKind: TEngineScriptTargetKind; const ATargetName: string;
      ATarget: TObject);
    procedure EndScript;
    function CurrentTargetHandle: Integer;
  end;

  TdwsEngineUnit = class;

  TEngineScriptManager = class
  private
    FDWS: TDelphiWebScript;
    FFastMath: TdwsFastMath;
    FEngineUnit: TdwsEngineUnit;
    FContext: TEngineScriptContext;
    FScripts: System.Generics.Collections.TObjectList<TEngineScriptAsset>;
    FProgramCache: TDictionary<string, IdwsProgram>;

    function GetCount: Integer;
    function GetScript(const AIndex: Integer): TEngineScriptAsset;
    function BuildExecutableSource(AScript: TEngineScriptAsset): string; overload;
    function BuildExecutableSource(AScript: TEngineScriptAsset;
      const AEntryPoint: string): string; overload;
    function BuildSceneObjectPath(Obj: TSceneObject): string;
    function FindSceneObjectByPath(const Path: string): TSceneObject;
    function ScriptDefinesCallable(AScript: TEngineScriptAsset;
      const ACallableName: string): Boolean;
    function TargetNameFor(ATargetKind: TEngineScriptTargetKind;
      ATarget: TObject): string;
    function ScriptMatchesTarget(AScript: TEngineScriptAsset;
      ATargetKind: TEngineScriptTargetKind; ATarget: TObject;
      const ATargetName: string): Boolean;
    procedure ResolveScriptTarget(AScript: TEngineScriptAsset);
    procedure MergeResult(var ADest: TEngineScriptExecutionResult;
      const ASource: TEngineScriptExecutionResult; const ALabel: string);
    function GetCompiledProgram(const AProgramSource: string;
      out AProgram: IdwsProgram): TEngineScriptExecutionResult;
    procedure ClearProgramCache;
    function MakeUniqueScriptName(const AName: string;
      AIgnore: TEngineScriptAsset): string;
    function FindSceneObjectScriptByTarget(const ATargetName: string): TEngineScriptAsset;
    procedure ImportSceneObjectScriptStates(AObject: TSceneObject);
    procedure SyncSceneObjectScriptState(AScript: TEngineScriptAsset);
    procedure ResetSceneObjectScriptRuntime(AObject: TSceneObject);
    procedure ClearSceneObjectScriptStates(AObject: TSceneObject);
  public
    constructor Create; virtual;
    destructor Destroy; override;

    procedure BindEngine(ARenderer: TRenderer; ASceneManager: TSceneManager;
      AMaterialLibrary: TMaterialLibrary; const ADefaultMaterialName: string;
      ADefaultMeshRender: TOnMeshRender; APhysicsWorld: TPhysicsWorld = nil;
      AAudioEngine: TBassAudioEngine = nil;
      APrefabLoader: TEngineScriptPrefabLoadCallback = nil;
      APrefabDestroyer: TEngineScriptPrefabDestroyCallback = nil;
      ALogCallback: TEngineScriptLogCallback = nil);
    procedure SetFrameTiming(const ADeltaTime, ATimeSeconds: Double);
    procedure ResetRuntimeState;

    function AddScript(const AName, ASource: string;
      ATargetKind: TEngineScriptTargetKind = stkGlobal;
      const ATargetName: string = ''; const AEntryPoint: string = ''): TEngineScriptAsset;
    function AddGlobalScript(const AName, ASource: string;
      const AEntryPoint: string = ''): TEngineScriptAsset;
    function AddObjectScript(AObject: TSceneObject; const AName, ASource: string;
      const AEntryPoint: string = ''): TEngineScriptAsset;
    function AddMaterialScript(AMaterial: TMaterial; const AName, ASource: string;
      const AEntryPoint: string = ''): TEngineScriptAsset;
    function AddShaderScript(AShader: TShader; const AName, ASource: string;
      const AEntryPoint: string = ''): TEngineScriptAsset;
    function AddOrReplaceAsset(AScript: TEngineScriptAsset): TEngineScriptAsset;

    procedure Clear;
    procedure DeleteScript(const AIndex: Integer);
    function FindByID(const AID: string): TEngineScriptAsset;
    function FindByName(const AName: string): TEngineScriptAsset;

    function CompileScript(AScript: TEngineScriptAsset): TEngineScriptExecutionResult;
    function ExecuteScript(AScript: TEngineScriptAsset;
      const AEventName: string = ''): TEngineScriptExecutionResult;
    function ExecuteScriptEntry(AScript: TEngineScriptAsset;
      const AEntryPoint, AEventName: string): TEngineScriptExecutionResult;
    function ExecuteLifecycleEvent(const AEventName: string): TEngineScriptExecutionResult;
    function ExecuteGlobalScripts(const AEventName: string = ''): TEngineScriptExecutionResult;
    function ExecuteScriptsForTarget(ATargetKind: TEngineScriptTargetKind;
      ATarget: TObject; const AEventName: string = ''): TEngineScriptExecutionResult;

    procedure ResolveScriptTargets;
    procedure SaveToStream(Stream: TStream);
    procedure LoadFromStream(Stream: TStream);
    function TryLoadFromStream(Stream: TStream): Boolean;
    procedure SaveToFile(const AFileName: string);
    procedure LoadFromFile(const AFileName: string);
    procedure SaveAssetToFile(AScript: TEngineScriptAsset; const AFileName: string);
    function LoadAssetFromFile(const AFileName: string): TEngineScriptAsset;

    property Context: TEngineScriptContext read FContext;
    property ScriptEngine: TDelphiWebScript read FDWS;
    property Count: Integer read GetCount;
    property Script[const AIndex: Integer]: TEngineScriptAsset read GetScript; default;
  end;

  TdwsEngineUnit = class(TdwsUnit)
  private
    FContext: TEngineScriptContext;
    FRenderWindowFullscreen: Boolean;
    FRenderWindowFullscreenHandle: HWND;
    FRenderWindowStoredStyle: NativeInt;
    FRenderWindowStoredExStyle: NativeInt;
    FRenderWindowStoredPlacement: TWindowPlacement;

    procedure RegisterEngineFunction(const AName, AResultType: string;
      const AParamNames, AParamTypes: array of string; const AOnEval: TFuncEvalEvent;
      const AOverloaded: Boolean = False);
    procedure RegisterMeshClass;
    procedure RegisterSceneObjectClass;
    procedure RegisterLightClass;
    procedure RegisterMaterialClass;
    procedure RegisterShaderClass;

    procedure RequireContext;
    function RequireSkyDome: TSkyDome;
    function RootObject: TSceneObject;
    function ParentOrRootFromHandle(const AHandle: Integer): TSceneObject;
    function RequireSceneObject(ExtObject: TObject): TSceneObject;
    function ParamAsSceneObject(Info: TProgramInfo; const AIndex: Integer): TSceneObject;
    procedure SetResultSceneObject(Info: TProgramInfo; AObject: TSceneObject);
    function RequireMesh(ExtObject: TObject): TMesh;
    function ParamAsMesh(Info: TProgramInfo; const AIndex: Integer): TMesh;
    procedure SetResultMesh(Info: TProgramInfo; AMesh: TMesh);
    function RequireLight(ExtObject: TObject): TLight;
    function ParamAsLight(Info: TProgramInfo; const AIndex: Integer): TLight;
    procedure SetResultLight(Info: TProgramInfo; ALight: TLight);
    function RequireMaterial(ExtObject: TObject): TMaterial;
    function ParamAsMaterial(Info: TProgramInfo; const AIndex: Integer): TMaterial;
    procedure SetResultMaterial(Info: TProgramInfo; AMaterial: TMaterial);
    function RequireShader(ExtObject: TObject): TShader;
    function ParamAsShader(Info: TProgramInfo; const AIndex: Integer): TShader;
    procedure SetResultShader(Info: TProgramInfo; AShader: TShader);
    function WorldMatrixOf(AObject: TSceneObject): TMatrix4;
    function WorldPositionOf(AObject: TSceneObject): TVector3;
    function DefaultObjectSpawnPosition(AParent: TSceneObject): TVector3;
    function RequireHeightFieldMesh(const AHandle: Integer): THeightFieldMesh;
    procedure ReleaseAudioEmitterRuntime(AEmitter: TSceneAudioEmitter);
    procedure ReleaseSceneObjectAudio(AObject: TSceneObject);
    procedure DestroySceneObjectForScript(AObject: TSceneObject);

    procedure SetInfoVector2(const AInfo: IInfo; const AVector: TVector2);
    procedure SetResultVector2(Info: TProgramInfo; const AVector: TVector2);

    function InfoAsVector3(const AInfo: IInfo): TVector3;
    function ParamAsVector3(Info: TProgramInfo; const AIndex: Integer): TVector3;
    procedure SetInfoVector3(const AInfo: IInfo; const AVector: TVector3);
    procedure SetResultVector3(Info: TProgramInfo; const AVector: TVector3);

    function InfoAsVector4(const AInfo: IInfo): TVector4;
    function ParamAsVector4(Info: TProgramInfo; const AIndex: Integer): TVector4;
    procedure SetInfoVector4(const AInfo: IInfo; const AVector: TVector4);
    procedure SetResultVector4(Info: TProgramInfo; const AVector: TVector4);

    function InfoAsMatrix4(const AInfo: IInfo): TMatrix4;
    function ParamAsMatrix4(Info: TProgramInfo; const AIndex: Integer): TMatrix4;
    procedure SetInfoMatrix4(const AInfo: IInfo; const AMatrix: TMatrix4);
    procedure SetResultMatrix4(Info: TProgramInfo; const AMatrix: TMatrix4);

    procedure ConfigureMesh(AMesh: TMesh);
    function AddMeshToObject(AObject: TSceneObject; AMesh: TMesh): Integer;
    function FindMeshOwnerRecursive(AObject: TSceneObject; AMesh: TMesh): TSceneObject;
    procedure NotifyMeshChanged(AMesh: TMesh; const AGeometryChanged: Boolean = False);
    procedure SetMeshMaterialName(AMesh: TMesh; const AMaterialName: string);
    function FindObjectRecursive(AObject: TSceneObject; const AName: string): TSceneObject;
    function GetMaterialShaderParameter(AMaterial: TMaterial; const AName: string): Single;
    procedure SetMaterialShaderParameter(AMaterial: TMaterial; const AName: string;
      const AValue: Single);
    function RequireRenderer: TRenderer;
    function RenderWindowHandle: HWND;
    function TryGetRenderWindowRect(out ARect: TRect): Boolean;
    function TryGetRenderWindowClientRect(out ARect: TRect): Boolean;
    function TryGetMonitorRect(AHandle: HWND; out ARect: TRect): Boolean;
    procedure ResizeRendererFromRenderWindow;
    procedure SetRenderWindowClientSize(AWidth, AHeight: Integer);
    function RenderWindowIsFullscreen: Boolean;
    procedure SetRenderWindowFullscreen(AEnabled: Boolean);

    procedure DoScriptEventName(Info: TProgramInfo);
    procedure DoScriptTargetKind(Info: TProgramInfo);
    procedure DoScriptTargetName(Info: TProgramInfo);
    procedure DoScriptTargetHandle(Info: TProgramInfo);
    procedure DoScriptTargetObject(Info: TProgramInfo);
    procedure DoScriptTargetMaterial(Info: TProgramInfo);
    procedure DoScriptTargetShader(Info: TProgramInfo);
    procedure DoDeltaTime(Info: TProgramInfo);
    procedure DoTimeSeconds(Info: TProgramInfo);
    procedure DoLog(Info: TProgramInfo);
    procedure DoKeyCode(Info: TProgramInfo);
    procedure DoKeyPressedCode(Info: TProgramInfo);
    procedure DoKeyPressedName(Info: TProgramInfo);
    procedure DoMouseButtonCode(Info: TProgramInfo);
    procedure DoMouseButtonPressedCode(Info: TProgramInfo);
    procedure DoMouseButtonPressedName(Info: TProgramInfo);
    procedure DoMousePosition(Info: TProgramInfo);
    procedure DoMouseX(Info: TProgramInfo);
    procedure DoMouseY(Info: TProgramInfo);
    procedure DoMouseInsideViewport(Info: TProgramInfo);
    procedure DoMouseRayOrigin(Info: TProgramInfo);
    procedure DoMouseRayDirection(Info: TProgramInfo);
    procedure DoScreenRayOrigin(Info: TProgramInfo);
    procedure DoScreenRayDirection(Info: TProgramInfo);
    procedure DoMousePlaneHit(Info: TProgramInfo);
    procedure DoMousePlanePoint(Info: TProgramInfo);
    procedure DoScreenPlaneHit(Info: TProgramInfo);
    procedure DoScreenPlanePoint(Info: TProgramInfo);
    procedure DoHeightFieldLocalHeight(Info: TProgramInfo);
    procedure DoHeightFieldWorldPoint(Info: TProgramInfo);
    procedure DoHeightFieldWorldHeight(Info: TProgramInfo);
    procedure DoMouseHeightFieldHit(Info: TProgramInfo);
    procedure DoMouseHeightFieldPoint(Info: TProgramInfo);
    procedure DoMouseHeightFieldLocalPoint(Info: TProgramInfo);
    procedure DoScreenHeightFieldHit(Info: TProgramInfo);
    procedure DoScreenHeightFieldPoint(Info: TProgramInfo);
    procedure DoScreenHeightFieldLocalPoint(Info: TProgramInfo);
    procedure DoViewportLeft(Info: TProgramInfo);
    procedure DoViewportTop(Info: TProgramInfo);
    procedure DoViewportWidth(Info: TProgramInfo);
    procedure DoViewportHeight(Info: TProgramInfo);
    procedure DoViewportPosition(Info: TProgramInfo);
    procedure DoViewportSize(Info: TProgramInfo);
    procedure DoViewportRect(Info: TProgramInfo);
    procedure DoViewportAspectRatio(Info: TProgramInfo);
    procedure DoViewportSetPosition(Info: TProgramInfo);
    procedure DoViewportSetSize(Info: TProgramInfo);
    procedure DoViewportSetRect(Info: TProgramInfo);
    procedure DoRenderWindowLeft(Info: TProgramInfo);
    procedure DoRenderWindowTop(Info: TProgramInfo);
    procedure DoRenderWindowWidth(Info: TProgramInfo);
    procedure DoRenderWindowHeight(Info: TProgramInfo);
    procedure DoRenderWindowPosition(Info: TProgramInfo);
    procedure DoRenderWindowSize(Info: TProgramInfo);
    procedure DoRenderWindowRect(Info: TProgramInfo);
    procedure DoRenderWindowAspectRatio(Info: TProgramInfo);
    procedure DoRenderWindowSetPosition(Info: TProgramInfo);
    procedure DoRenderWindowSetSize(Info: TProgramInfo);
    procedure DoRenderWindowSetRect(Info: TProgramInfo);
    procedure DoRenderWindowFullScreen(Info: TProgramInfo);
    procedure DoRenderWindowSetFullScreen(Info: TProgramInfo);
    procedure DoRenderWindowToggleFullScreen(Info: TProgramInfo);

    procedure DoSceneRoot(Info: TProgramInfo);
    procedure DoSceneRootObject(Info: TProgramInfo);
    procedure DoSceneFind(Info: TProgramInfo);
    procedure DoSceneFindObject(Info: TProgramInfo);
    procedure DoSceneUpdate(Info: TProgramInfo);
    procedure DoSceneRender(Info: TProgramInfo);
    procedure DoPrefabLoad(Info: TProgramInfo);
    procedure DoPrefabDestroy(Info: TProgramInfo);

    procedure DoObjectFromHandle(Info: TProgramInfo);
    procedure DoObjectHandle(Info: TProgramInfo);
    procedure DoObjectCreate(Info: TProgramInfo);
    procedure DoObjectDelete(Info: TProgramInfo);
    procedure DoObjectChildCount(Info: TProgramInfo);
    procedure DoObjectChild(Info: TProgramInfo);
    procedure DoObjectParent(Info: TProgramInfo);
    procedure DoObjectName(Info: TProgramInfo);
    procedure DoObjectSetName(Info: TProgramInfo);
    procedure DoObjectPosition(Info: TProgramInfo);
    procedure DoObjectSetPosition(Info: TProgramInfo);
    procedure DoObjectRotation(Info: TProgramInfo);
    procedure DoObjectSetRotation(Info: TProgramInfo);
    procedure DoObjectScale(Info: TProgramInfo);
    procedure DoObjectSetScale(Info: TProgramInfo);
    procedure DoObjectMatrix(Info: TProgramInfo);
    procedure DoObjectModelMatrix(Info: TProgramInfo);
    procedure DoObjectLocalMatrix(Info: TProgramInfo);
    procedure DoObjectWorldMatrix(Info: TProgramInfo);
    procedure DoObjectWorldPosition(Info: TProgramInfo);
    procedure DoObjectSetWireframe(Info: TProgramInfo);
    procedure DoObjectHasGeometry(Info: TProgramInfo);
    procedure DoObjectHasCamera(Info: TProgramInfo);
    procedure DoObjectHasParticles(Info: TProgramInfo);
    procedure DoObjectHasBillboards(Info: TProgramInfo);
    procedure DoObjectHasAudio(Info: TProgramInfo);

    procedure DoObjectMeshCount(Info: TProgramInfo);
    procedure DoObjectMesh(Info: TProgramInfo);
    procedure DoObjectMeshObject(Info: TProgramInfo);
    procedure DoObjectAddMeshFile(Info: TProgramInfo);
    procedure DoObjectAddMeshFileObject(Info: TProgramInfo);
    procedure DoObjectAddPlane(Info: TProgramInfo);
    procedure DoObjectAddCube(Info: TProgramInfo);
    procedure DoObjectAddSphere(Info: TProgramInfo);
    procedure DoObjectAddCylinder(Info: TProgramInfo);
    procedure DoObjectAddCapsule(Info: TProgramInfo);
    procedure DoObjectAddTorus(Info: TProgramInfo);
    procedure DoObjectAddCone(Info: TProgramInfo);
    procedure DoObjectAddPrism(Info: TProgramInfo);
    procedure DoObjectAddFrustum(Info: TProgramInfo);
    procedure DoObjectAddIcosphere(Info: TProgramInfo);
    procedure DoObjectAddGeodesicDome(Info: TProgramInfo);
    procedure DoObjectAddArrow(Info: TProgramInfo);
    procedure DoObjectAddSuperEllipsoid(Info: TProgramInfo);
    procedure DoObjectSetMaterial(Info: TProgramInfo);

    procedure DoMeshFromHandle(Info: TProgramInfo);
    procedure DoMeshHandle(Info: TProgramInfo);
    procedure DoMeshName(Info: TProgramInfo);
    procedure DoMeshSetName(Info: TProgramInfo);
    procedure DoMeshPosition(Info: TProgramInfo);
    procedure DoMeshSetPosition(Info: TProgramInfo);
    procedure DoMeshRotation(Info: TProgramInfo);
    procedure DoMeshSetRotation(Info: TProgramInfo);
    procedure DoMeshScale(Info: TProgramInfo);
    procedure DoMeshSetScale(Info: TProgramInfo);
    procedure DoMeshSetTransform(Info: TProgramInfo);
    procedure DoMeshVisible(Info: TProgramInfo);
    procedure DoMeshSetVisible(Info: TProgramInfo);
    procedure DoMeshWireframe(Info: TProgramInfo);
    procedure DoMeshSetWireframe(Info: TProgramInfo);
    procedure DoMeshAlwaysOnTop(Info: TProgramInfo);
    procedure DoMeshSetAlwaysOnTop(Info: TProgramInfo);
    procedure DoMeshTag(Info: TProgramInfo);
    procedure DoMeshSetTag(Info: TProgramInfo);
    procedure DoMeshType(Info: TProgramInfo);
    procedure DoMeshVertexCount(Info: TProgramInfo);
    procedure DoMeshIndexCount(Info: TProgramInfo);
    procedure DoMeshBoundingBoxMin(Info: TProgramInfo);
    procedure DoMeshBoundingBoxMax(Info: TProgramInfo);
    procedure DoMeshLocalMatrix(Info: TProgramInfo);
    procedure DoMeshModelMatrix(Info: TProgramInfo);
    procedure DoMeshParentModelMatrix(Info: TProgramInfo);
    procedure DoMeshMaterialName(Info: TProgramInfo);
    procedure DoMeshSetMaterialName(Info: TProgramInfo);
    procedure DoMeshSetMaterial(Info: TProgramInfo);
    procedure DoMeshApplyTransform(Info: TProgramInfo);
    procedure DoMeshScaleUVs(Info: TProgramInfo);
    procedure DoMeshRecomputeBoundingBox(Info: TProgramInfo);

    procedure DoObjectParticleSystemCount(Info: TProgramInfo);
    procedure DoObjectParticleSystem(Info: TProgramInfo);
    procedure DoObjectCreateParticleSystem(Info: TProgramInfo);
    procedure DoObjectRemoveParticleSystem(Info: TProgramInfo);
    procedure DoParticleBlendAlpha(Info: TProgramInfo);
    procedure DoParticleBlendAdditive(Info: TProgramInfo);
    procedure DoParticleTextureNone(Info: TProgramInfo);
    procedure DoParticleTextureSoftCircle(Info: TProgramInfo);
    procedure DoParticleTexturePerlin(Info: TProgramInfo);
    procedure DoParticleTextureFile(Info: TProgramInfo);
    procedure DoParticleSpaceObject(Info: TProgramInfo);
    procedure DoParticleSpaceWorld(Info: TProgramInfo);
    procedure DoParticleCount(Info: TProgramInfo);
    procedure DoParticleClear(Info: TProgramInfo);
    procedure DoParticleBurst(Info: TProgramInfo);
    procedure DoParticleBoolean(Info: TProgramInfo);
    procedure DoParticleSetBoolean(Info: TProgramInfo);
    procedure DoParticleInteger(Info: TProgramInfo);
    procedure DoParticleSetInteger(Info: TProgramInfo);
    procedure DoParticleFloat(Info: TProgramInfo);
    procedure DoParticleSetFloat(Info: TProgramInfo);
    procedure DoParticleVector3(Info: TProgramInfo);
    procedure DoParticleSetVector3(Info: TProgramInfo);
    procedure DoParticleVector4(Info: TProgramInfo);
    procedure DoParticleSetVector4(Info: TProgramInfo);
    procedure DoParticleString(Info: TProgramInfo);
    procedure DoParticleSetString(Info: TProgramInfo);

    procedure DoObjectBillboardCount(Info: TProgramInfo);
    procedure DoObjectBillboard(Info: TProgramInfo);
    procedure DoObjectCreateBillboard(Info: TProgramInfo);
    procedure DoObjectRemoveBillboard(Info: TProgramInfo);
    procedure DoBillboardBlendAlpha(Info: TProgramInfo);
    procedure DoBillboardBlendAdditive(Info: TProgramInfo);
    procedure DoBillboardBoolean(Info: TProgramInfo);
    procedure DoBillboardSetBoolean(Info: TProgramInfo);
    procedure DoBillboardInteger(Info: TProgramInfo);
    procedure DoBillboardSetInteger(Info: TProgramInfo);
    procedure DoBillboardFloat(Info: TProgramInfo);
    procedure DoBillboardSetFloat(Info: TProgramInfo);
    procedure DoBillboardVector3(Info: TProgramInfo);
    procedure DoBillboardSetVector3(Info: TProgramInfo);
    procedure DoBillboardVector4(Info: TProgramInfo);
    procedure DoBillboardSetVector4(Info: TProgramInfo);
    procedure DoBillboardString(Info: TProgramInfo);
    procedure DoBillboardSetString(Info: TProgramInfo);

    procedure DoObjectAudioEmitterCount(Info: TProgramInfo);
    procedure DoObjectAudioEmitter(Info: TProgramInfo);
    procedure DoObjectCreateAudioEmitter(Info: TProgramInfo);
    procedure DoObjectRemoveAudioEmitter(Info: TProgramInfo);
    procedure DoObjectAudioListener(Info: TProgramInfo);
    procedure DoObjectSetAudioListener(Info: TProgramInfo);
    procedure DoObjectAudioVector3(Info: TProgramInfo);
    procedure DoObjectSetAudioVector3(Info: TProgramInfo);
    procedure DoObjectAudioFloat(Info: TProgramInfo);
    procedure DoObjectSetAudioFloat(Info: TProgramInfo);
    procedure DoAudio3DModeNormal(Info: TProgramInfo);
    procedure DoAudio3DModeRelative(Info: TProgramInfo);
    procedure DoAudio3DModeOff(Info: TProgramInfo);
    procedure DoAudioInitialized(Info: TProgramInfo);
    procedure DoAudioApply3D(Info: TProgramInfo);
    procedure DoAudioMasterVolume(Info: TProgramInfo);
    procedure DoAudioSetMasterVolume(Info: TProgramInfo);
    procedure DoAudioEmitterBoolean(Info: TProgramInfo);
    procedure DoAudioEmitterSetBoolean(Info: TProgramInfo);
    procedure DoAudioEmitterInteger(Info: TProgramInfo);
    procedure DoAudioEmitterSetInteger(Info: TProgramInfo);
    procedure DoAudioEmitterFloat(Info: TProgramInfo);
    procedure DoAudioEmitterSetFloat(Info: TProgramInfo);
    procedure DoAudioEmitterVector3(Info: TProgramInfo);
    procedure DoAudioEmitterSetVector3(Info: TProgramInfo);
    procedure DoAudioEmitterString(Info: TProgramInfo);
    procedure DoAudioEmitterSetString(Info: TProgramInfo);

    procedure DoObjectCreateLight(Info: TProgramInfo);
    procedure DoObjectLightCount(Info: TProgramInfo);
    procedure DoObjectLight(Info: TProgramInfo);
    procedure DoLightFromHandle(Info: TProgramInfo);
    procedure DoLightHandle(Info: TProgramInfo);
    procedure DoLightTypeDirectional(Info: TProgramInfo);
    procedure DoLightTypePoint(Info: TProgramInfo);
    procedure DoLightTypeSpot(Info: TProgramInfo);
    procedure DoLightType(Info: TProgramInfo);
    procedure DoLightSetType(Info: TProgramInfo);
    procedure DoLightEnabled(Info: TProgramInfo);
    procedure DoLightSetEnabled(Info: TProgramInfo);
    procedure DoLightDiffuse(Info: TProgramInfo);
    procedure DoLightSetDiffuse(Info: TProgramInfo);
    procedure DoLightAmbient(Info: TProgramInfo);
    procedure DoLightSetAmbient(Info: TProgramInfo);
    procedure DoLightSpecular(Info: TProgramInfo);
    procedure DoLightSetSpecular(Info: TProgramInfo);
    procedure DoLightPosition(Info: TProgramInfo);
    procedure DoLightSetPosition(Info: TProgramInfo);
    procedure DoLightDirection(Info: TProgramInfo);
    procedure DoLightSetDirection(Info: TProgramInfo);
    procedure DoLightSetAttenuation(Info: TProgramInfo);
    procedure DoLightSetSpot(Info: TProgramInfo);
    procedure DoLightCastShadows(Info: TProgramInfo);
    procedure DoLightSetCastShadows(Info: TProgramInfo);
    procedure DoLightShadowStrength(Info: TProgramInfo);
    procedure DoLightSetShadowStrength(Info: TProgramInfo);

    procedure DoObjectCreateCamera(Info: TProgramInfo);
    procedure DoObjectCamera(Info: TProgramInfo);
    procedure DoCameraLookAt(Info: TProgramInfo);
    procedure DoCameraMoveForward(Info: TProgramInfo);
    procedure DoCameraMoveRight(Info: TProgramInfo);
    procedure DoCameraMoveUp(Info: TProgramInfo);
    procedure DoCameraRotateYaw(Info: TProgramInfo);
    procedure DoCameraRotatePitch(Info: TProgramInfo);
    procedure DoCameraPosition(Info: TProgramInfo);
    procedure DoCameraTarget(Info: TProgramInfo);
    procedure DoCameraViewMatrix(Info: TProgramInfo);
    procedure DoCameraViewProjectionMatrix(Info: TProgramInfo);

    procedure DoMaterialCount(Info: TProgramInfo);
    procedure DoMaterialName(Info: TProgramInfo);
    procedure DoMaterialByName(Info: TProgramInfo);
    procedure DoMaterialByNameObject(Info: TProgramInfo);
    procedure DoMaterialFromHandle(Info: TProgramInfo);
    procedure DoMaterialHandle(Info: TProgramInfo);
    procedure DoMaterialShaderParameter(Info: TProgramInfo);
    procedure DoMaterialSetShaderParameter(Info: TProgramInfo);

    procedure DoShaderFromHandle(Info: TProgramInfo);
    procedure DoShaderHandle(Info: TProgramInfo);
    procedure DoShaderVertexPath(Info: TProgramInfo);
    procedure DoShaderFragmentPath(Info: TProgramInfo);
    procedure DoShaderUse(Info: TProgramInfo);
    procedure DoShaderReload(Info: TProgramInfo);
    procedure DoShaderSetUniformBoolean(Info: TProgramInfo);
    procedure DoShaderSetUniformInteger(Info: TProgramInfo);
    procedure DoShaderSetUniformFloat(Info: TProgramInfo);
    procedure DoShaderSetUniformVector3(Info: TProgramInfo);
    procedure DoShaderSetUniformVector4(Info: TProgramInfo);
    procedure DoShaderSetUniformMatrix4(Info: TProgramInfo);

    procedure DoRendererProjectionMatrix(Info: TProgramInfo);
    procedure DoRendererViewMatrix(Info: TProgramInfo);
    procedure DoRendererViewProjectionMatrix(Info: TProgramInfo);
    procedure DoRendererShadowLightViewProjection(Info: TProgramInfo);
    procedure DoRendererShadowLightMatrix(Info: TProgramInfo);
    procedure DoRendererSetBackgroundColor(Info: TProgramInfo);
    procedure DoRendererSetShadowEnabled(Info: TProgramInfo);
    procedure DoRendererSetShadowTarget(Info: TProgramInfo);
    procedure DoRendererSetShadowDistance(Info: TProgramInfo);
    procedure DoRendererSetShadowArea(Info: TProgramInfo);
    procedure DoRendererSetShadowMapSize(Info: TProgramInfo);
    procedure DoSkyDomeResetDefaults(Info: TProgramInfo);
    procedure DoSkyDomeBoolean(Info: TProgramInfo);
    procedure DoSkyDomeSetBoolean(Info: TProgramInfo);
    procedure DoSkyDomeInteger(Info: TProgramInfo);
    procedure DoSkyDomeSetInteger(Info: TProgramInfo);
    procedure DoSkyDomeFloat(Info: TProgramInfo);
    procedure DoSkyDomeSetFloat(Info: TProgramInfo);
    procedure DoSkyDomeVector3(Info: TProgramInfo);
    procedure DoSkyDomeSetVector3(Info: TProgramInfo);
    procedure DoSkyDomeVector4(Info: TProgramInfo);
    procedure DoSkyDomeSetVector4(Info: TProgramInfo);

    procedure DoPhysicsBodyStatic(Info: TProgramInfo);
    procedure DoPhysicsBodyDynamic(Info: TProgramInfo);
    procedure DoPhysicsBodyKinematic(Info: TProgramInfo);
    procedure DoPhysicsBodyCharacter(Info: TProgramInfo);
    procedure DoPhysicsBodyProjectile(Info: TProgramInfo);
    procedure DoPhysicsColliderAuto(Info: TProgramInfo);
    procedure DoPhysicsColliderNone(Info: TProgramInfo);
    procedure DoPhysicsColliderSphere(Info: TProgramInfo);
    procedure DoPhysicsColliderCapsule(Info: TProgramInfo);
    procedure DoPhysicsColliderAABB(Info: TProgramInfo);
    procedure DoPhysicsColliderMesh(Info: TProgramInfo);
    procedure DoPhysicsColliderConvexHull(Info: TProgramInfo);
    procedure DoPhysicsBodyCount(Info: TProgramInfo);
    procedure DoPhysicsBody(Info: TProgramInfo);
    procedure DoPhysicsFindBody(Info: TProgramInfo);
    procedure DoPhysicsAddBody(Info: TProgramInfo);
    procedure DoPhysicsRemoveBody(Info: TProgramInfo);
    procedure DoPhysicsRemoveBodyForObject(Info: TProgramInfo);
    procedure DoPhysicsClear(Info: TProgramInfo);
    procedure DoPhysicsStep(Info: TProgramInfo);
    procedure DoPhysicsEnsureNativeScene(Info: TProgramInfo);
    procedure DoPhysicsGravity(Info: TProgramInfo);
    procedure DoPhysicsSetGravity(Info: TProgramInfo);
    procedure DoPhysicsGroundPlaneEnabled(Info: TProgramInfo);
    procedure DoPhysicsSetGroundPlaneEnabled(Info: TProgramInfo);
    procedure DoPhysicsGroundHeight(Info: TProgramInfo);
    procedure DoPhysicsSetGroundHeight(Info: TProgramInfo);
    procedure DoPhysicsApplyRadialImpulse(Info: TProgramInfo);
    procedure DoPhysicsRaycastHit(Info: TProgramInfo);
    procedure DoPhysicsRaycastPoint(Info: TProgramInfo);
    procedure DoPhysicsRaycastNormal(Info: TProgramInfo);
    procedure DoPhysicsRaycastBody(Info: TProgramInfo);
    procedure DoPhysicsBodyObject(Info: TProgramInfo);
    procedure DoPhysicsBodyType(Info: TProgramInfo);
    procedure DoPhysicsBodySetType(Info: TProgramInfo);
    procedure DoPhysicsBodyColliderKind(Info: TProgramInfo);
    procedure DoPhysicsBodySetColliderKind(Info: TProgramInfo);
    procedure DoPhysicsBodyBoolean(Info: TProgramInfo);
    procedure DoPhysicsBodySetBoolean(Info: TProgramInfo);
    procedure DoPhysicsBodyFloat(Info: TProgramInfo);
    procedure DoPhysicsBodySetFloat(Info: TProgramInfo);
    procedure DoPhysicsBodyVector3(Info: TProgramInfo);
    procedure DoPhysicsBodySetVector3(Info: TProgramInfo);
    procedure DoPhysicsBodyConfigureSphere(Info: TProgramInfo);
    procedure DoPhysicsBodyConfigureCapsule(Info: TProgramInfo);
    procedure DoPhysicsBodyConfigureAABB(Info: TProgramInfo);
    procedure DoPhysicsBodyConfigureMesh(Info: TProgramInfo);
    procedure DoPhysicsBodyAutoFitCollider(Info: TProgramInfo);
    procedure DoPhysicsBodyAddForce(Info: TProgramInfo);
    procedure DoPhysicsBodyAddImpulse(Info: TProgramInfo);
    procedure DoPhysicsBodyClearForces(Info: TProgramInfo);
    procedure DoPhysicsBodyStop(Info: TProgramInfo);

    procedure DoSceneObjectCreate(Info: TProgramInfo; var ExtObject: TObject);
    procedure DoSceneObjectCreateNamed(Info: TProgramInfo; var ExtObject: TObject);
    procedure DoSceneObjectCreateChild(Info: TProgramInfo; var ExtObject: TObject);
    procedure DoSceneObjectCreateAt(Info: TProgramInfo; var ExtObject: TObject);
    procedure DoSceneObjectCreateNamedAt(Info: TProgramInfo;
      var ExtObject: TObject);
    procedure DoSceneObjectCreateChildAt(Info: TProgramInfo;
      var ExtObject: TObject);
    procedure DoSceneObjectCleanup(ExternalObject: TObject);
    procedure DoSceneObjectDelete(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectGetHandle(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectGetName(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectSetName(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectGetPosition(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectSetPosition(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectGetRotation(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectSetRotation(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectGetScale(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectSetScale(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectGetMatrix(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectGetModelMatrix(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectGetLocalMatrix(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectGetWorldMatrix(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectGetWorldPosition(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectGetParent(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectGetChildCount(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectChild(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectGetWireframe(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectSetWireframe(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectGetHasGeometry(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectGetHasCamera(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectGetHasParticles(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectGetHasBillboards(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectGetHasAudio(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectGetHasSkeletonAnimation(Info: TProgramInfo;
      ExtObject: TObject);
    procedure DoSceneObjectGetAnimationCount(Info: TProgramInfo;
      ExtObject: TObject);
    procedure DoSceneObjectAnimationName(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectSetAnimationName(Info: TProgramInfo;
      ExtObject: TObject);
    procedure DoSceneObjectAnimationIndex(Info: TProgramInfo;
      ExtObject: TObject);
    procedure DoSceneObjectGetCurrentAnimationName(Info: TProgramInfo;
      ExtObject: TObject);
    procedure DoSceneObjectGetCurrentAnimationIndex(Info: TProgramInfo;
      ExtObject: TObject);
    procedure DoSceneObjectPlayAnimation(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectPlayAnimationIndex(Info: TProgramInfo;
      ExtObject: TObject);
    procedure DoSceneObjectBlendToAnimation(Info: TProgramInfo;
      ExtObject: TObject);
    procedure DoSceneObjectIsAnimationPlaying(Info: TProgramInfo;
      ExtObject: TObject);
    procedure DoSceneObjectPauseAnimation(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectResumeAnimation(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectStopAnimation(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectGetAnimationState(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectGetAnimationTime(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectSetAnimationTime(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectGetAnimationNormalizedTime(Info: TProgramInfo;
      ExtObject: TObject);
    procedure DoSceneObjectSetAnimationNormalizedTime(Info: TProgramInfo;
      ExtObject: TObject);
    procedure DoSceneObjectGetAnimationDuration(Info: TProgramInfo;
      ExtObject: TObject);
    procedure DoSceneObjectAnimationClipDuration(Info: TProgramInfo;
      ExtObject: TObject);
    procedure DoSceneObjectAnimationClipDurationByName(Info: TProgramInfo;
      ExtObject: TObject);
    procedure DoSceneObjectGetAnimationSpeed(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectSetAnimationSpeed(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectGetAnimationLooping(Info: TProgramInfo;
      ExtObject: TObject);
    procedure DoSceneObjectSetAnimationLooping(Info: TProgramInfo;
      ExtObject: TObject);
    procedure DoSceneObjectGetAnimationBlending(Info: TProgramInfo;
      ExtObject: TObject);
    procedure DoSceneObjectGetMeshCount(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectMesh(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectMeshObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectAddMeshFile(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectAddMeshFileObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectSetMaterial(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectGetParticleSystemCount(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectParticleSystem(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectCreateParticleSystem(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectRemoveParticleSystem(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectGetLightCount(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectLight(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectCreateLight(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectLightObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectCreateLightObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectCamera(Info: TProgramInfo; ExtObject: TObject);
    procedure DoSceneObjectCreateCamera(Info: TProgramInfo; ExtObject: TObject);

    procedure DoLightCleanup(ExternalObject: TObject);
    procedure DoLightGetHandle(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightGetName(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightSetName(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightGetType(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightSetTypeObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightGetEnabled(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightSetEnabledObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightGetAmbient(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightSetAmbientObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightGetDiffuse(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightSetDiffuseObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightGetSpecular(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightSetSpecularObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightGetPosition(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightSetPositionObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightGetDirection(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightSetDirectionObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightGetUseTarget(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightSetUseTarget(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightGetTargetPosition(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightSetTargetPosition(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightGetConstantAttenuation(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightSetConstantAttenuation(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightGetLinearAttenuation(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightSetLinearAttenuation(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightGetQuadraticAttenuation(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightSetQuadraticAttenuation(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightGetSpotCutoff(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightSetSpotCutoff(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightGetSpotExponent(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightSetSpotExponent(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightGetCastShadows(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightSetCastShadowsObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightGetShadowStrength(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightSetShadowStrengthObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightSetAttenuationObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLightSetSpotObject(Info: TProgramInfo; ExtObject: TObject);

    procedure DoMaterialCleanup(ExternalObject: TObject);
    procedure DoMaterialGetHandle(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMaterialGetName(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMaterialSetName(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMaterialGetTextureCount(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMaterialGetMaterialID(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMaterialGetMaterialType(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMaterialSetMaterialType(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMaterialGetShader(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMaterialSetShader(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMaterialShaderParameterObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMaterialSetShaderParameterObject(Info: TProgramInfo; ExtObject: TObject);

    procedure DoShaderCleanup(ExternalObject: TObject);
    procedure DoShaderGetHandle(Info: TProgramInfo; ExtObject: TObject);
    procedure DoShaderGetVertexPath(Info: TProgramInfo; ExtObject: TObject);
    procedure DoShaderGetFragmentPath(Info: TProgramInfo; ExtObject: TObject);
    procedure DoShaderGetProgramID(Info: TProgramInfo; ExtObject: TObject);
    procedure DoShaderUseObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoShaderReloadObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoShaderSetUniformBooleanObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoShaderSetUniformIntegerObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoShaderSetUniformFloatObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoShaderSetUniformVector3Object(Info: TProgramInfo; ExtObject: TObject);
    procedure DoShaderSetUniformVector4Object(Info: TProgramInfo; ExtObject: TObject);
    procedure DoShaderSetUniformMatrix4Object(Info: TProgramInfo; ExtObject: TObject);

    procedure DoMeshCleanup(ExternalObject: TObject);
    procedure DoMeshGetHandle(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshGetName(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshSetNameObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshGetPosition(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshSetPositionObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshGetRotation(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshSetRotationObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshGetScale(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshSetScaleObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshSetTransformObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshGetVisible(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshSetVisibleObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshGetWireframe(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshSetWireframeObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshGetAlwaysOnTop(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshSetAlwaysOnTopObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshGetTag(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshSetTagObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshGetMeshType(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshGetVertexCount(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshGetIndexCount(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshGetBoundingBoxMin(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshGetBoundingBoxMax(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshGetLocalMatrix(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshGetModelMatrix(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshGetParentModelMatrix(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshGetMaterialName(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshSetMaterialNameObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshSetMaterialObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshApplyTransformObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshScaleUVsObject(Info: TProgramInfo; ExtObject: TObject);
    procedure DoMeshRecomputeBoundingBoxObject(Info: TProgramInfo; ExtObject: TObject);
  public
    constructor RegisterEngine(AOwner: TComponent; AScript: TDelphiWebScript;
      AContext: TEngineScriptContext);
  end;

implementation

const
  SCRIPT_FILE_VERSION = 4;
  SCRIPT_ASSET_FILE_VERSION = 4;
  SCRIPT_FILE_MAGIC: array[0..7] of AnsiChar = ('O', 'M', 'E', 'S', 'C', 'R', '0', '1');
  SCRIPT_ASSET_FILE_MAGIC: array[0..7] of AnsiChar = ('O', 'M', 'E', 'S', 'C', 'A', '0', '1');
  SCRIPT_TEXT_FORMAT_VERSION = 1;
  SCRIPT_TEXT_LIBRARY_HEADER = 'OpenGL Micro Engine Script Library';
  SCRIPT_TEXT_ASSET_HEADER = 'OpenGL Micro Engine Script Asset';
  SCRIPT_TEXT_SCRIPT_BEGIN = '--- Script ---';
  SCRIPT_TEXT_SCRIPT_END = '--- End Script ---';
  SCRIPT_TEXT_SOURCE_BEGIN = '--- Source ---';
  SCRIPT_SOURCE_KEY: array[0..15] of Byte =
    ($4F, $47, $4C, $2D, $4D, $45, $2D, $53,
     $43, $52, $49, $50, $54, $2D, $30, $33);

procedure WriteScriptString(Stream: TStream; const Value: string);
var
  Len: Integer;
begin
  Len := Length(Value);
  Stream.WriteBuffer(Len, SizeOf(Len));
  if Len > 0 then
    Stream.WriteBuffer(Value[1], Len * SizeOf(Char));
end;

function ReadScriptString(Stream: TStream): string;
var
  Len: Integer;
begin
  Stream.ReadBuffer(Len, SizeOf(Len));
  if Len < 0 then
    raise Exception.Create('Invalid string length in script stream.');

  SetLength(Result, Len);
  if Len > 0 then
    Stream.ReadBuffer(Result[1], Len * SizeOf(Char));
end;

function ScriptBytesChecksum(const Data: TBytes): Cardinal;
var
  B: Byte;
  HashValue: UInt64;
begin
  HashValue := $811C9DC5;
  for B in Data do
    HashValue := ((HashValue xor B) * $01000193) and $FFFFFFFF;
  Result := Cardinal(HashValue);
end;

procedure CryptScriptBytes(var Data: TBytes);
var
  I: Integer;
begin
  for I := 0 to High(Data) do
    Data[I] := Data[I] xor SCRIPT_SOURCE_KEY[I mod Length(SCRIPT_SOURCE_KEY)] xor
      Byte((I * 31 + Length(Data)) and $FF);
end;

procedure WriteEncryptedScriptString(Stream: TStream; const Value: string);
var
  Data: TBytes;
  Len: Integer;
  Checksum: Cardinal;
begin
  Data := TEncoding.UTF8.GetBytes(Value);
  Checksum := ScriptBytesChecksum(Data);
  CryptScriptBytes(Data);

  Len := Length(Data);
  Stream.WriteBuffer(Len, SizeOf(Len));
  Stream.WriteBuffer(Checksum, SizeOf(Checksum));
  if Len > 0 then
    Stream.WriteBuffer(Data[0], Len);
end;

function ReadEncryptedScriptString(Stream: TStream): string;
var
  Data: TBytes;
  Len: Integer;
  StoredChecksum: Cardinal;
begin
  Stream.ReadBuffer(Len, SizeOf(Len));
  if (Len < 0) or (Len > 32 * 1024 * 1024) then
    raise Exception.Create('Invalid encrypted script string length.');

  Stream.ReadBuffer(StoredChecksum, SizeOf(StoredChecksum));
  SetLength(Data, Len);
  if Len > 0 then
  begin
    Stream.ReadBuffer(Data[0], Len);
    CryptScriptBytes(Data);
  end;

  if ScriptBytesChecksum(Data) <> StoredChecksum then
    raise Exception.Create('Script source integrity check failed.');

  Result := TEncoding.UTF8.GetString(Data, 0, Length(Data));
end;

function ScriptMagicMatches(const Magic: array of AnsiChar): Boolean;
var
  I: Integer;
begin
  Result := Length(Magic) = Length(SCRIPT_FILE_MAGIC);
  if not Result then
    Exit;

  for I := 0 to High(SCRIPT_FILE_MAGIC) do
    if Magic[I] <> SCRIPT_FILE_MAGIC[I] then
      Exit(False);
end;

function ScriptAssetMagicMatches(const Magic: array of AnsiChar): Boolean;
var
  I: Integer;
begin
  Result := Length(Magic) = Length(SCRIPT_ASSET_FILE_MAGIC);
  if not Result then
    Exit;

  for I := 0 to High(SCRIPT_ASSET_FILE_MAGIC) do
    if Magic[I] <> SCRIPT_ASSET_FILE_MAGIC[I] then
      Exit(False);
end;

function ScriptTextFormatSettings: TFormatSettings;
begin
  Result := FormatSettings;
  Result.DecimalSeparator := '.';
end;

function ScriptTargetKindToText(AKind: TEngineScriptTargetKind): string;
begin
  case AKind of
    stkSceneObject: Result := 'SceneObject';
    stkShader: Result := 'Shader';
    stkMaterial: Result := 'Material';
    stkRenderTechnique: Result := 'RenderTechnique';
  else
    Result := 'Global';
  end;
end;

function TryScriptTargetKindFromText(const Value: string;
  out AKind: TEngineScriptTargetKind): Boolean;
var
  Text: string;
  OrdinalValue: Integer;
begin
  Text := LowerCase(Trim(Value));
  Result := True;
  if Text = 'global' then
    AKind := stkGlobal
  else if (Text = 'sceneobject') or (Text = 'scene object') then
    AKind := stkSceneObject
  else if Text = 'shader' then
    AKind := stkShader
  else if Text = 'material' then
    AKind := stkMaterial
  else if (Text = 'rendertechnique') or (Text = 'render technique') then
    AKind := stkRenderTechnique
  else if TryStrToInt(Text, OrdinalValue) and
    (OrdinalValue >= Ord(Low(TEngineScriptTargetKind))) and
    (OrdinalValue <= Ord(High(TEngineScriptTargetKind))) then
    AKind := TEngineScriptTargetKind(OrdinalValue)
  else
    Result := False;
end;

function EncodeScriptTextValue(const Value: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(Value) do
    case Value[I] of
      '\': Result := Result + '\\';
      #13: Result := Result + '\r';
      #10: Result := Result + '\n';
    else
      Result := Result + Value[I];
    end;
end;

function DecodeScriptTextValue(const Value: string): string;
var
  I: Integer;
begin
  Result := '';
  I := 1;
  while I <= Length(Value) do
  begin
    if (Value[I] = '\') and (I < Length(Value)) then
    begin
      Inc(I);
      case Value[I] of
        '\': Result := Result + '\';
        'r': Result := Result + #13;
        'n': Result := Result + #10;
      else
        Result := Result + Value[I];
      end;
    end
    else
      Result := Result + Value[I];
    Inc(I);
  end;
end;

function ScriptTextDateTimeToStr(const Value: TDateTime): string;
begin
  Result := FloatToStr(Value, ScriptTextFormatSettings);
end;

function ScriptTextStrToDateTime(const Value: string;
  const DefaultValue: TDateTime): TDateTime;
var
  FloatValue: Extended;
begin
  if TryStrToFloat(Value, FloatValue, ScriptTextFormatSettings) then
    Result := TDateTime(FloatValue)
  else
    Result := DefaultValue;
end;

function ReadScriptTextLine(const Text: string; var Position: Integer): string;
var
  Start: Integer;
begin
  if Position > Length(Text) then
    Exit('');

  Start := Position;
  while (Position <= Length(Text)) and
    not CharInSet(Text[Position], [#13, #10]) do
    Inc(Position);

  Result := Copy(Text, Start, Position - Start);
  if (Position <= Length(Text)) and (Text[Position] = #13) then
  begin
    Inc(Position);
    if (Position <= Length(Text)) and (Text[Position] = #10) then
      Inc(Position);
  end
  else if (Position <= Length(Text)) and (Text[Position] = #10) then
    Inc(Position);
end;

procedure SkipScriptTextBlankLines(const Text: string; var Position: Integer);
var
  SavedPosition: Integer;
  Line: string;
begin
  while Position <= Length(Text) do
  begin
    SavedPosition := Position;
    Line := ReadScriptTextLine(Text, Position);
    if Trim(Line) <> '' then
    begin
      Position := SavedPosition;
      Exit;
    end;
  end;
end;

procedure SkipScriptTextLineBreak(const Text: string; var Position: Integer);
begin
  if (Position <= Length(Text)) and (Text[Position] = #13) then
  begin
    Inc(Position);
    if (Position <= Length(Text)) and (Text[Position] = #10) then
      Inc(Position);
  end
  else if (Position <= Length(Text)) and (Text[Position] = #10) then
    Inc(Position);
end;

procedure RequireScriptTextLine(const Text: string; var Position: Integer;
  const Expected: string);
var
  Line: string;
begin
  Line := ReadScriptTextLine(Text, Position);
  if Line <> Expected then
    raise Exception.CreateFmt('Expected "%s" in script text file.', [Expected]);
end;

function ReadScriptTextField(const Text: string; var Position: Integer;
  const Key: string): string;
var
  Line: string;
  SeparatorPos: Integer;
  ActualKey: string;
begin
  Line := ReadScriptTextLine(Text, Position);
  SeparatorPos := Pos('=', Line);
  if SeparatorPos <= 0 then
    raise Exception.CreateFmt('Expected "%s" field in script text file.', [Key]);

  ActualKey := Trim(Copy(Line, 1, SeparatorPos - 1));
  if not SameText(ActualKey, Key) then
    raise Exception.CreateFmt('Expected "%s" field but found "%s".',
      [Key, ActualKey]);

  Result := DecodeScriptTextValue(Copy(Line, SeparatorPos + 1, MaxInt));
end;

procedure AppendScriptTextLine(var Text: string; const Line: string);
begin
  Text := Text + Line + sLineBreak;
end;

procedure AppendScriptTextField(var Text: string; const Key, Value: string);
begin
  AppendScriptTextLine(Text, Key + '=' + EncodeScriptTextValue(Value));
end;

function ScriptTextBoolToStr(const Value: Boolean): string;
begin
  if Value then
    Result := 'true'
  else
    Result := 'false';
end;

function ScriptTextStrToBool(const Value: string): Boolean;
begin
  Result := SameText(Value, 'true') or (Trim(Value) = '1') or
    SameText(Value, 'yes');
end;

procedure AppendScriptTextRecord(var Text: string; AScript: TEngineScriptAsset);
var
  Source: string;
begin
  if AScript = nil then
    Exit;

  AppendScriptTextField(Text, 'ID', AScript.ID);
  AppendScriptTextField(Text, 'Name', AScript.Name);
  AppendScriptTextField(Text, 'Enabled', ScriptTextBoolToStr(AScript.Enabled));
  AppendScriptTextField(Text, 'TargetKind',
    ScriptTargetKindToText(AScript.TargetKind));
  AppendScriptTextField(Text, 'TargetName', AScript.TargetName);
  AppendScriptTextField(Text, 'EntryPoint', AScript.EntryPoint);
  AppendScriptTextField(Text, 'Description', AScript.Description);
  AppendScriptTextField(Text, 'Author', AScript.Author);
  AppendScriptTextField(Text, 'Category', AScript.Category);
  AppendScriptTextField(Text, 'VersionText', AScript.VersionText);
  AppendScriptTextField(Text, 'CreatedAt',
    ScriptTextDateTimeToStr(AScript.CreatedAt));
  AppendScriptTextField(Text, 'ModifiedAt',
    ScriptTextDateTimeToStr(AScript.ModifiedAt));

  Source := AScript.Source;
  AppendScriptTextLine(Text, 'SourceLength=' + IntToStr(Length(Source)));
  AppendScriptTextLine(Text, SCRIPT_TEXT_SOURCE_BEGIN);
  Text := Text + Source;
  if (Source = '') or not CharInSet(Source[Length(Source)], [#13, #10]) then
    Text := Text + sLineBreak;
end;

procedure ReadScriptTextRecord(const Text: string; var Position: Integer;
  AScript: TEngineScriptAsset);
var
  KindText: string;
  TargetKind: TEngineScriptTargetKind;
  SourceLength: Integer;
  CreatedAtValue: TDateTime;
begin
  AScript.ID := ReadScriptTextField(Text, Position, 'ID');
  AScript.Name := ReadScriptTextField(Text, Position, 'Name');
  AScript.Enabled := ScriptTextStrToBool(
    ReadScriptTextField(Text, Position, 'Enabled'));

  KindText := ReadScriptTextField(Text, Position, 'TargetKind');
  if not TryScriptTargetKindFromText(KindText, TargetKind) then
    raise Exception.CreateFmt('Invalid script target kind: %s.', [KindText]);
  AScript.TargetKind := TargetKind;

  AScript.TargetName := ReadScriptTextField(Text, Position, 'TargetName');
  AScript.EntryPoint := ReadScriptTextField(Text, Position, 'EntryPoint');
  AScript.Description := ReadScriptTextField(Text, Position, 'Description');
  AScript.Author := ReadScriptTextField(Text, Position, 'Author');
  AScript.Category := ReadScriptTextField(Text, Position, 'Category');
  AScript.VersionText := ReadScriptTextField(Text, Position, 'VersionText');
  AScript.CreatedAt := ScriptTextStrToDateTime(
    ReadScriptTextField(Text, Position, 'CreatedAt'), Now);
  CreatedAtValue := AScript.CreatedAt;
  AScript.ModifiedAt := ScriptTextStrToDateTime(
    ReadScriptTextField(Text, Position, 'ModifiedAt'), CreatedAtValue);

  SourceLength := StrToInt(ReadScriptTextField(Text, Position, 'SourceLength'));
  if (SourceLength < 0) or (SourceLength > (Length(Text) - Position + 1)) then
    raise Exception.Create('Invalid script source length in text file.');

  RequireScriptTextLine(Text, Position, SCRIPT_TEXT_SOURCE_BEGIN);
  AScript.Source := Copy(Text, Position, SourceLength);
  Inc(Position, SourceLength);
  SkipScriptTextLineBreak(Text, Position);

  if AScript.ID = '' then
    AScript.ID := TEngineScriptAsset.NewID;
  if AScript.Name = '' then
    AScript.Name := 'Script';
  if AScript.VersionText = '' then
    AScript.VersionText := '1.0';
  AScript.RuntimeTarget := nil;
end;

function BuildScriptAssetText(AScript: TEngineScriptAsset): string;
begin
  Result := '';
  AppendScriptTextLine(Result, SCRIPT_TEXT_ASSET_HEADER);
  AppendScriptTextLine(Result, 'Version=' + IntToStr(SCRIPT_TEXT_FORMAT_VERSION));
  AppendScriptTextLine(Result, '');
  AppendScriptTextLine(Result, SCRIPT_TEXT_SCRIPT_BEGIN);
  AppendScriptTextRecord(Result, AScript);
  AppendScriptTextLine(Result, SCRIPT_TEXT_SCRIPT_END);
end;

function BuildScriptLibraryText(AManager: TEngineScriptManager): string;
var
  I: Integer;
begin
  Result := '';
  AppendScriptTextLine(Result, SCRIPT_TEXT_LIBRARY_HEADER);
  AppendScriptTextLine(Result, 'Version=' + IntToStr(SCRIPT_TEXT_FORMAT_VERSION));
  if AManager <> nil then
    AppendScriptTextLine(Result, 'Count=' + IntToStr(AManager.FScripts.Count))
  else
    AppendScriptTextLine(Result, 'Count=0');
  AppendScriptTextLine(Result, '');

  if AManager = nil then
    Exit;

  for I := 0 to AManager.FScripts.Count - 1 do
  begin
    AppendScriptTextLine(Result, SCRIPT_TEXT_SCRIPT_BEGIN);
    AppendScriptTextRecord(Result, AManager.FScripts[I]);
    AppendScriptTextLine(Result, SCRIPT_TEXT_SCRIPT_END);
    if I < AManager.FScripts.Count - 1 then
      AppendScriptTextLine(Result, '');
  end;
end;

function ReadUtf8ScriptTextFile(const AFileName: string): string;
var
  Stream: TFileStream;
  Data: TBytes;
  Size: Integer;
begin
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    if Stream.Size > 32 * 1024 * 1024 then
      raise Exception.Create('Script text file is too large.');

    Size := Integer(Stream.Size);
    SetLength(Data, Size);
    if Size > 0 then
      Stream.ReadBuffer(Data[0], Size);
  finally
    Stream.Free;
  end;

  Result := TEncoding.UTF8.GetString(Data, 0, Length(Data));
  if (Result <> '') and (Result[1] = #$FEFF) then
    Delete(Result, 1, 1);
end;

procedure WriteUtf8ScriptTextFile(const AFileName, Text: string);
var
  Stream: TFileStream;
  Data: TBytes;
begin
  Data := TEncoding.UTF8.GetBytes(Text);
  Stream := TFileStream.Create(AFileName, fmCreate);
  try
    if Length(Data) > 0 then
      Stream.WriteBuffer(Data[0], Length(Data));
  finally
    Stream.Free;
  end;
end;

function ScriptTextFirstLine(const Text: string): string;
var
  Position: Integer;
begin
  Position := 1;
  Result := ReadScriptTextLine(Text, Position);
end;

procedure LoadScriptTextAsset(const Text: string; AScript: TEngineScriptAsset);
var
  Position: Integer;
  Version: Integer;
begin
  if AScript = nil then
    raise Exception.Create('Script asset is nil.');

  Position := 1;
  if not SameText(ReadScriptTextLine(Text, Position), SCRIPT_TEXT_ASSET_HEADER) then
    raise Exception.Create('Invalid script asset text file.');

  Version := StrToInt(ReadScriptTextField(Text, Position, 'Version'));
  if Version <> SCRIPT_TEXT_FORMAT_VERSION then
    raise Exception.CreateFmt('Unsupported script text asset version: %d.',
      [Version]);

  SkipScriptTextBlankLines(Text, Position);
  RequireScriptTextLine(Text, Position, SCRIPT_TEXT_SCRIPT_BEGIN);
  ReadScriptTextRecord(Text, Position, AScript);
  RequireScriptTextLine(Text, Position, SCRIPT_TEXT_SCRIPT_END);
end;

procedure LoadScriptTextLibrary(const Text: string; AManager: TEngineScriptManager);
var
  Position: Integer;
  Version, CountValue, I: Integer;
  Script: TEngineScriptAsset;
begin
  if AManager = nil then
    raise Exception.Create('Script manager is nil.');

  Position := 1;
  if not SameText(ReadScriptTextLine(Text, Position), SCRIPT_TEXT_LIBRARY_HEADER) then
    raise Exception.Create('Invalid script library text file.');

  Version := StrToInt(ReadScriptTextField(Text, Position, 'Version'));
  if Version <> SCRIPT_TEXT_FORMAT_VERSION then
    raise Exception.CreateFmt('Unsupported script text library version: %d.',
      [Version]);

  CountValue := StrToInt(ReadScriptTextField(Text, Position, 'Count'));
  if CountValue < 0 then
    raise Exception.Create('Invalid script count in script text file.');

  if Assigned(AManager.FContext) and Assigned(AManager.FContext.SceneManager) then
    AManager.ClearSceneObjectScriptStates(AManager.FContext.SceneManager.Root);
  AManager.FScripts.Clear;
  AManager.ResetRuntimeState;

  for I := 0 to CountValue - 1 do
  begin
    SkipScriptTextBlankLines(Text, Position);
    RequireScriptTextLine(Text, Position, SCRIPT_TEXT_SCRIPT_BEGIN);

    Script := TEngineScriptAsset.Create;
    try
      ReadScriptTextRecord(Text, Position, Script);
      AManager.FScripts.Add(Script);
      Script := nil;
    finally
      Script.Free;
    end;

    RequireScriptTextLine(Text, Position, SCRIPT_TEXT_SCRIPT_END);
  end;

  AManager.ResolveScriptTargets;
end;

function TryLoadScriptTextLibraryFromFile(const AFileName: string;
  AManager: TEngineScriptManager): Boolean;
var
  Text: string;
begin
  Text := ReadUtf8ScriptTextFile(AFileName);
  Result := SameText(ScriptTextFirstLine(Text), SCRIPT_TEXT_LIBRARY_HEADER);
  if Result then
    LoadScriptTextLibrary(Text, AManager);
end;

function TryLoadScriptTextAssetFromFile(const AFileName: string;
  out AScript: TEngineScriptAsset): Boolean;
var
  Text: string;
  Script: TEngineScriptAsset;
begin
  AScript := nil;
  Text := ReadUtf8ScriptTextFile(AFileName);
  Result := SameText(ScriptTextFirstLine(Text), SCRIPT_TEXT_ASSET_HEADER);
  if not Result then
    Exit;

  Script := TEngineScriptAsset.Create;
  try
    LoadScriptTextAsset(Text, Script);
    AScript := Script;
    Script := nil;
  finally
    Script.Free;
  end;
end;

{ TEngineScriptExecutionResult }

class function TEngineScriptExecutionResult.Ok: TEngineScriptExecutionResult;
begin
  Result.Success := True;
  Result.Messages := '';
end;

class function TEngineScriptExecutionResult.Error(
  const AMessages: string): TEngineScriptExecutionResult;
begin
  Result.Success := False;
  Result.Messages := AMessages;
end;

{ TEngineScriptAsset }

constructor TEngineScriptAsset.Create;
begin
  inherited Create;
  FID := NewID;
  FName := 'Script';
  FVersionText := '1.0';
  FCreatedAt := Now;
  FModifiedAt := FCreatedAt;
  FEnabled := True;
  FTargetKind := stkGlobal;
end;

class function TEngineScriptAsset.NewID: string;
var
  Guid: TGUID;
begin
  CreateGUID(Guid);
  Result := GUIDToString(Guid);
end;

procedure TEngineScriptAsset.Assign(Source: TEngineScriptAsset);
begin
  if Source = nil then
    Exit;

  FID := Source.FID;
  FName := Source.FName;
  FSource := Source.FSource;
  FEntryPoint := Source.FEntryPoint;
  FDescription := Source.FDescription;
  FAuthor := Source.FAuthor;
  FCategory := Source.FCategory;
  FVersionText := Source.FVersionText;
  FCreatedAt := Source.FCreatedAt;
  FModifiedAt := Source.FModifiedAt;
  FEnabled := Source.FEnabled;
  FTargetKind := Source.FTargetKind;
  FTargetName := Source.FTargetName;
  FRuntimeTarget := Source.FRuntimeTarget;
end;

procedure TEngineScriptAsset.SaveToStream(Stream: TStream);
begin
  SaveToStream(Stream, SCRIPT_FILE_VERSION);
end;

procedure TEngineScriptAsset.Touch;
begin
  FModifiedAt := Now;
end;

procedure TEngineScriptAsset.SaveToStream(Stream: TStream; AVersion: Integer);
var
  KindValue: Integer;
begin
  WriteScriptString(Stream, FID);
  WriteScriptString(Stream, FName);
  if AVersion = 3 then
    WriteEncryptedScriptString(Stream, FSource)
  else
    WriteScriptString(Stream, FSource);
  WriteScriptString(Stream, FEntryPoint);
  Stream.WriteBuffer(FEnabled, SizeOf(FEnabled));
  KindValue := Ord(FTargetKind);
  Stream.WriteBuffer(KindValue, SizeOf(KindValue));
  WriteScriptString(Stream, FTargetName);

  if AVersion >= 2 then
  begin
    WriteScriptString(Stream, FDescription);
    WriteScriptString(Stream, FAuthor);
    WriteScriptString(Stream, FCategory);
    WriteScriptString(Stream, FVersionText);
    Stream.WriteBuffer(FCreatedAt, SizeOf(FCreatedAt));
    Stream.WriteBuffer(FModifiedAt, SizeOf(FModifiedAt));
  end;
end;

procedure TEngineScriptAsset.LoadFromStream(Stream: TStream);
begin
  LoadFromStream(Stream, SCRIPT_FILE_VERSION);
end;

procedure TEngineScriptAsset.LoadFromStream(Stream: TStream; AVersion: Integer);
var
  KindValue: Integer;
begin
  FID := ReadScriptString(Stream);
  FName := ReadScriptString(Stream);
  if AVersion = 3 then
    FSource := ReadEncryptedScriptString(Stream)
  else
    FSource := ReadScriptString(Stream);
  FEntryPoint := ReadScriptString(Stream);
  Stream.ReadBuffer(FEnabled, SizeOf(FEnabled));
  Stream.ReadBuffer(KindValue, SizeOf(KindValue));
  if (KindValue < Ord(Low(TEngineScriptTargetKind))) or
     (KindValue > Ord(High(TEngineScriptTargetKind))) then
    raise Exception.CreateFmt('Invalid script target kind: %d.', [KindValue]);
  FTargetKind := TEngineScriptTargetKind(KindValue);
  FTargetName := ReadScriptString(Stream);
  FRuntimeTarget := nil;

  FDescription := '';
  FAuthor := '';
  FCategory := '';
  FVersionText := '1.0';
  FCreatedAt := Now;
  FModifiedAt := FCreatedAt;

  if AVersion >= 2 then
  begin
    FDescription := ReadScriptString(Stream);
    FAuthor := ReadScriptString(Stream);
    FCategory := ReadScriptString(Stream);
    FVersionText := ReadScriptString(Stream);
    Stream.ReadBuffer(FCreatedAt, SizeOf(FCreatedAt));
    Stream.ReadBuffer(FModifiedAt, SizeOf(FModifiedAt));
  end;

  if FID = '' then
    FID := NewID;
  if FName = '' then
    FName := 'Script';
  if FVersionText = '' then
    FVersionText := '1.0';
end;

{ TEngineScriptManager }

constructor TEngineScriptManager.Create;
begin
  inherited Create;

  FScripts := System.Generics.Collections.TObjectList<TEngineScriptAsset>.Create(True);
  FProgramCache := TDictionary<string, IdwsProgram>.Create;
  FContext := TEngineScriptContext.Create;
  FDWS := TDelphiWebScript.Create(nil);
  FFastMath := TdwsFastMath.RegisterFastMath(nil, FDWS);
  FEngineUnit := TdwsEngineUnit.RegisterEngine(nil, FDWS, FContext);
end;

destructor TEngineScriptManager.Destroy;
begin
  // Cached and scene-attached programs reference DWS, so release all of them
  // before destroying the compiler/runtime component.
  ResetRuntimeState;
  FProgramCache.Free;
  FEngineUnit.Free;
  FFastMath.Free;
  FDWS.Free;
  FContext.Free;
  FScripts.Free;
  inherited Destroy;
end;

procedure TEngineScriptManager.BindEngine(ARenderer: TRenderer;
  ASceneManager: TSceneManager; AMaterialLibrary: TMaterialLibrary;
  const ADefaultMaterialName: string; ADefaultMeshRender: TOnMeshRender;
  APhysicsWorld: TPhysicsWorld; AAudioEngine: TBassAudioEngine;
  APrefabLoader: TEngineScriptPrefabLoadCallback;
  APrefabDestroyer: TEngineScriptPrefabDestroyCallback;
  ALogCallback: TEngineScriptLogCallback);
begin
  FContext.Bind(ARenderer, ASceneManager, AMaterialLibrary, ADefaultMaterialName,
    ADefaultMeshRender, APhysicsWorld, AAudioEngine, APrefabLoader,
    APrefabDestroyer, ALogCallback);
  ResolveScriptTargets;
end;

procedure TEngineScriptManager.SetFrameTiming(const ADeltaTime,
  ATimeSeconds: Double);
begin
  FContext.DeltaTime := Single(Max(0.0, ADeltaTime));
  FContext.TimeSeconds := Max(0.0, ATimeSeconds);
end;

procedure TEngineScriptManager.ResetRuntimeState;
begin
  if Assigned(FContext) then
  begin
    if Assigned(FContext.SceneManager) then
      ResetSceneObjectScriptRuntime(FContext.SceneManager.Root);
    FContext.ClearHandles;
  end;
  ClearProgramCache;
end;

function TEngineScriptManager.GetCount: Integer;
begin
  Result := FScripts.Count;
end;

function TEngineScriptManager.GetScript(const AIndex: Integer): TEngineScriptAsset;
begin
  Result := FScripts[AIndex];
end;

function TEngineScriptManager.AddScript(const AName, ASource: string;
  ATargetKind: TEngineScriptTargetKind; const ATargetName,
  AEntryPoint: string): TEngineScriptAsset;
begin
  Result := TEngineScriptAsset.Create;
  Result.Name := MakeUniqueScriptName(AName, nil);
  Result.Source := ASource;
  Result.EntryPoint := AEntryPoint;
  Result.TargetKind := ATargetKind;
  Result.TargetName := ATargetName;
  FScripts.Add(Result);
end;

function TEngineScriptManager.AddGlobalScript(const AName, ASource,
  AEntryPoint: string): TEngineScriptAsset;
begin
  Result := AddScript(AName, ASource, stkGlobal, '', AEntryPoint);
end;

function TEngineScriptManager.AddObjectScript(AObject: TSceneObject;
  const AName, ASource, AEntryPoint: string): TEngineScriptAsset;
begin
  Result := AddScript(AName, ASource, stkSceneObject,
    TargetNameFor(stkSceneObject, AObject), AEntryPoint);
  Result.RuntimeTarget := AObject;
  SyncSceneObjectScriptState(Result);
end;

function TEngineScriptManager.AddMaterialScript(AMaterial: TMaterial;
  const AName, ASource, AEntryPoint: string): TEngineScriptAsset;
begin
  Result := AddScript(AName, ASource, stkMaterial,
    TargetNameFor(stkMaterial, AMaterial), AEntryPoint);
  Result.RuntimeTarget := AMaterial;
end;

function TEngineScriptManager.AddShaderScript(AShader: TShader; const AName,
  ASource, AEntryPoint: string): TEngineScriptAsset;
begin
  Result := AddScript(AName, ASource, stkShader,
    TargetNameFor(stkShader, AShader), AEntryPoint);
  Result.RuntimeTarget := AShader;
end;

function TEngineScriptManager.AddOrReplaceAsset(
  AScript: TEngineScriptAsset): TEngineScriptAsset;
var
  Existing: TEngineScriptAsset;
begin
  Result := nil;
  if AScript = nil then
    Exit;

  Existing := nil;
  if Trim(AScript.ID) <> '' then
    Existing := FindByID(AScript.ID);

  if Existing <> nil then
  begin
    Existing.Assign(AScript);
    Existing.Name := MakeUniqueScriptName(Existing.Name, Existing);
    Existing.RuntimeTarget := nil;
    AScript.Free;
    Result := Existing;
  end
  else
  begin
    AScript.Name := MakeUniqueScriptName(AScript.Name, nil);
    FScripts.Add(AScript);
    Result := AScript;
  end;

  ResolveScriptTarget(Result);
  SyncSceneObjectScriptState(Result);
  ResetRuntimeState;
end;

procedure TEngineScriptManager.Clear;
begin
  if Assigned(FContext) and Assigned(FContext.SceneManager) then
    ClearSceneObjectScriptStates(FContext.SceneManager.Root);
  FScripts.Clear;
  ResetRuntimeState;
end;

procedure TEngineScriptManager.DeleteScript(const AIndex: Integer);
var
  Script: TEngineScriptAsset;
begin
  Script := FScripts[AIndex];
  if Assigned(Script) and (Script.TargetKind = stkSceneObject) then
  begin
    if not (Script.RuntimeTarget is TSceneObject) then
      ResolveScriptTarget(Script);
    if Script.RuntimeTarget is TSceneObject then
      TSceneObject(Script.RuntimeTarget).ScriptState.Clear;
  end;
  FScripts.Delete(AIndex);
  ResetRuntimeState;
end;

function TEngineScriptManager.FindByID(const AID: string): TEngineScriptAsset;
var
  Script: TEngineScriptAsset;
begin
  Result := nil;
  for Script in FScripts do
    if SameText(Script.ID, AID) then
      Exit(Script);
end;

function TEngineScriptManager.FindByName(const AName: string): TEngineScriptAsset;
var
  Script: TEngineScriptAsset;
begin
  Result := nil;
  for Script in FScripts do
    if SameText(Script.Name, AName) then
      Exit(Script);
end;

function TEngineScriptManager.BuildExecutableSource(
  AScript: TEngineScriptAsset): string;
begin
  if AScript = nil then
    Exit('');

  Result := BuildExecutableSource(AScript, AScript.EntryPoint);
end;

function TEngineScriptManager.BuildExecutableSource(AScript: TEngineScriptAsset;
  const AEntryPoint: string): string;
begin
  if AScript = nil then
    Exit('');

  Result := AScript.Source;
  if Trim(AEntryPoint) <> '' then
    Result := Result + sLineBreak + 'begin' + sLineBreak +
      '  ' + AEntryPoint + ';' + sLineBreak +
      'end.';
end;

function TEngineScriptManager.BuildSceneObjectPath(Obj: TSceneObject): string;
var
  Parts: TList<string>;
  Current: TSceneObject;
  I: Integer;
begin
  Result := '';
  if Obj = nil then
    Exit;

  Parts := TList<string>.Create;
  try
    Current := Obj;
    while Current <> nil do
    begin
      Parts.Insert(0, Current.Name);
      Current := Current.Parent;
    end;

    for I := 0 to Parts.Count - 1 do
    begin
      if Result <> '' then
        Result := Result + '/';
      Result := Result + Parts[I];
    end;
  finally
    Parts.Free;
  end;
end;

function TEngineScriptManager.FindSceneObjectByPath(const Path: string): TSceneObject;
var
  Parts: TArray<string>;
  Current: TSceneObject;
  I, ChildIndex: Integer;
begin
  Result := nil;
  if (FContext.SceneManager = nil) or (Trim(Path) = '') then
    Exit;

  Parts := Path.Split(['/']);
  if Length(Parts) = 0 then
    Exit;

  Current := FContext.SceneManager.Root;
  I := 0;
  if SameText(Parts[0], Current.Name) then
    I := 1;

  while I < Length(Parts) do
  begin
    Result := nil;
    for ChildIndex := 0 to Current.Count - 1 do
      if SameText(Current.ObjectList[ChildIndex].Name, Parts[I]) then
      begin
        Result := Current.ObjectList[ChildIndex];
        Break;
      end;

    if Result = nil then
      Exit;

    Current := Result;
    Inc(I);
  end;

  Result := Current;
end;

function TEngineScriptManager.TargetNameFor(ATargetKind: TEngineScriptTargetKind;
  ATarget: TObject): string;
begin
  Result := '';
  case ATargetKind of
    stkSceneObject:
      if ATarget is TSceneObject then
        Result := BuildSceneObjectPath(TSceneObject(ATarget));

    stkMaterial:
      if ATarget is TMaterial then
        Result := TMaterial(ATarget).Name;

    stkShader:
      if ATarget is TShader then
        Result := TShader(ATarget).VertexPath + '|' + TShader(ATarget).FragmentPath;

    stkRenderTechnique:
      if ATarget <> nil then
        Result := ATarget.ClassName;
  end;
end;

function TEngineScriptManager.ScriptDefinesCallable(AScript: TEngineScriptAsset;
  const ACallableName: string): Boolean;
var
  SourceText: string;
  NameText: string;
begin
  Result := False;
  if (AScript = nil) or (Trim(ACallableName) = '') then
    Exit;

  SourceText := LowerCase(AScript.Source);
  NameText := LowerCase(Trim(ACallableName));
  Result := (Pos('procedure ' + NameText, SourceText) > 0) or
    (Pos('function ' + NameText, SourceText) > 0);
end;

function TEngineScriptManager.ScriptMatchesTarget(AScript: TEngineScriptAsset;
  ATargetKind: TEngineScriptTargetKind; ATarget: TObject;
  const ATargetName: string): Boolean;
var
  NameToMatch: string;
begin
  Result := False;
  if (AScript = nil) or (not AScript.Enabled) then
    Exit;

  if AScript.TargetKind <> ATargetKind then
    Exit;

  if ATargetName <> '' then
    NameToMatch := ATargetName
  else
    NameToMatch := TargetNameFor(ATargetKind, ATarget);

  Result := (AScript.TargetName = '') or SameText(AScript.TargetName, NameToMatch);
  if Result and (AScript.RuntimeTarget = nil) then
    AScript.RuntimeTarget := ATarget;
end;

procedure TEngineScriptManager.ResolveScriptTarget(AScript: TEngineScriptAsset);
begin
  if AScript = nil then
    Exit;

  AScript.RuntimeTarget := nil;
  case AScript.TargetKind of
    stkSceneObject:
      AScript.RuntimeTarget := FindSceneObjectByPath(AScript.TargetName);

    stkMaterial:
      if Assigned(FContext.MaterialLibrary) and (AScript.TargetName <> '') then
        AScript.RuntimeTarget := FContext.MaterialLibrary.GetMaterial(AScript.TargetName);
  end;
end;

procedure TEngineScriptManager.ResolveScriptTargets;
var
  Script: TEngineScriptAsset;
begin
  for Script in FScripts do
  begin
    ResolveScriptTarget(Script);
    SyncSceneObjectScriptState(Script);
  end;

  if Assigned(FContext.SceneManager) then
    ImportSceneObjectScriptStates(FContext.SceneManager.Root);
end;

procedure TEngineScriptManager.MergeResult(var ADest: TEngineScriptExecutionResult;
  const ASource: TEngineScriptExecutionResult; const ALabel: string);
begin
  if ADest.Messages <> '' then
    ADest.Messages := ADest.Messages + sLineBreak;

  if ASource.Messages <> '' then
  begin
    if ALabel <> '' then
      ADest.Messages := ADest.Messages + ALabel + ':' + sLineBreak;
    ADest.Messages := ADest.Messages + ASource.Messages;
  end;

  ADest.Success := ADest.Success and ASource.Success;
end;

procedure TEngineScriptManager.ClearProgramCache;
begin
  if Assigned(FProgramCache) then
    FProgramCache.Clear;
end;

function TEngineScriptManager.MakeUniqueScriptName(const AName: string;
  AIgnore: TEngineScriptAsset): string;
var
  BaseName: string;
  Candidate: string;
  Counter: Integer;
  Script: TEngineScriptAsset;
  Exists: Boolean;
begin
  BaseName := Trim(AName);
  if BaseName = '' then
    BaseName := 'Script';

  Candidate := BaseName;
  Counter := 1;
  repeat
    Exists := False;
    for Script in FScripts do
      if (Script <> AIgnore) and SameText(Script.Name, Candidate) then
      begin
        Exists := True;
        Break;
      end;

    if Exists then
    begin
      Candidate := BaseName + '_' + IntToStr(Counter);
      Inc(Counter);
    end;
  until not Exists;

  Result := Candidate;
end;

function TEngineScriptManager.FindSceneObjectScriptByTarget(
  const ATargetName: string): TEngineScriptAsset;
var
  Script: TEngineScriptAsset;
begin
  Result := nil;
  for Script in FScripts do
    if Assigned(Script) and (Script.TargetKind = stkSceneObject) and
       SameText(Script.TargetName, ATargetName) then
      Exit(Script);
end;

procedure TEngineScriptManager.ImportSceneObjectScriptStates(AObject: TSceneObject);
var
  TargetName: string;
  Script: TEngineScriptAsset;
  I: Integer;
begin
  if AObject = nil then
    Exit;

  if Assigned(AObject.ScriptState) and AObject.ScriptState.Attached and
     (Trim(AObject.ScriptState.Source) <> '') then
  begin
    TargetName := TargetNameFor(stkSceneObject, AObject);
    Script := FindSceneObjectScriptByTarget(TargetName);
    if Script = nil then
    begin
      Script := AddScript(AObject.Name + ' Script', AObject.ScriptState.Source,
        stkSceneObject, TargetName, AObject.ScriptState.EntryPoint);
      Script.Enabled := AObject.ScriptState.Enabled;
      Script.RuntimeTarget := AObject;
      AObject.ScriptState.Modified := False;
    end
    else if Script.RuntimeTarget = nil then
      Script.RuntimeTarget := AObject;
  end;

  for I := 0 to AObject.Count - 1 do
    ImportSceneObjectScriptStates(AObject.ObjectList[I]);
end;

procedure TEngineScriptManager.SyncSceneObjectScriptState(AScript: TEngineScriptAsset);
var
  Obj: TSceneObject;
begin
  if (AScript = nil) or (AScript.TargetKind <> stkSceneObject) then
    Exit;

  if not (AScript.RuntimeTarget is TSceneObject) then
    ResolveScriptTarget(AScript);
  if not (AScript.RuntimeTarget is TSceneObject) then
    Exit;

  Obj := TSceneObject(AScript.RuntimeTarget);
  if Obj.ScriptState = nil then
    Exit;

  Obj.ScriptState.Attached := True;
  Obj.ScriptState.Enabled := AScript.Enabled;
  Obj.ScriptState.Source := AScript.Source;
  Obj.ScriptState.EntryPoint := AScript.EntryPoint;
  Obj.ScriptState.Modified := False;
end;

procedure TEngineScriptManager.ResetSceneObjectScriptRuntime(AObject: TSceneObject);
var
  I: Integer;
begin
  if AObject = nil then
    Exit;

  if Assigned(AObject.ScriptState) then
    AObject.ScriptState.ClearRuntime;

  for I := 0 to AObject.Count - 1 do
    ResetSceneObjectScriptRuntime(AObject.ObjectList[I]);
end;

procedure TEngineScriptManager.ClearSceneObjectScriptStates(AObject: TSceneObject);
var
  I: Integer;
begin
  if AObject = nil then
    Exit;

  if Assigned(AObject.ScriptState) then
    AObject.ScriptState.Clear;

  for I := 0 to AObject.Count - 1 do
    ClearSceneObjectScriptStates(AObject.ObjectList[I]);
end;

function TEngineScriptManager.GetCompiledProgram(const AProgramSource: string;
  out AProgram: IdwsProgram): TEngineScriptExecutionResult;
begin
  AProgram := nil;

  if Trim(AProgramSource) = '' then
    Exit(TEngineScriptExecutionResult.Error('Script source is empty.'));

  // BuildExecutableSource includes the selected entry point, so the complete
  // source string is a safe cache key for both normal and lifecycle execution.
  if FProgramCache.TryGetValue(AProgramSource, AProgram) then
    Exit(TEngineScriptExecutionResult.Ok);

  AProgram := FDWS.Compile(AProgramSource);
  if AProgram.Msgs.HasErrors then
  begin
    Result := TEngineScriptExecutionResult.Error(AProgram.Msgs.AsInfo);
    AProgram := nil;
    Exit;
  end;

  FProgramCache.Add(AProgramSource, AProgram);
  Result := TEngineScriptExecutionResult.Ok;
end;

function TEngineScriptManager.CompileScript(
  AScript: TEngineScriptAsset): TEngineScriptExecutionResult;
var
  ProgramSource: string;
  Prog: IdwsProgram;
  Obj: TSceneObject;
begin
  if AScript = nil then
    Exit(TEngineScriptExecutionResult.Error('Script is nil.'));

  ProgramSource := BuildExecutableSource(AScript);
  Obj := nil;
  SyncSceneObjectScriptState(AScript);
  if AScript.RuntimeTarget is TSceneObject then
    Obj := TSceneObject(AScript.RuntimeTarget);

  FContext.BeginScript(AScript.Name, 'Compile', AScript.TargetKind,
    AScript.TargetName, AScript.RuntimeTarget);
  try
    Result := GetCompiledProgram(ProgramSource, Prog);
    if Assigned(Obj) and Assigned(Obj.ScriptState) then
    begin
      Obj.ScriptState.ProgramSource := ProgramSource;
      Obj.ScriptState.LastMessages := Result.Messages;
      Obj.ScriptState.Running := False;
      if Result.Success then
      begin
        Obj.ScriptState.CompiledProgram := Prog;
        Obj.ScriptState.Modified := False;
      end
      else
      begin
        Obj.ScriptState.CompiledProgram := nil;
        Obj.ScriptState.Compiled := False;
      end;
    end;
  finally
    FContext.EndScript;
  end;
end;

function TEngineScriptManager.ExecuteScript(AScript: TEngineScriptAsset;
  const AEventName: string): TEngineScriptExecutionResult;
begin
  if AScript = nil then
    Exit(TEngineScriptExecutionResult.Error('Script is nil.'));

  Result := ExecuteScriptEntry(AScript, AScript.EntryPoint, AEventName);
end;

function TEngineScriptManager.ExecuteScriptEntry(AScript: TEngineScriptAsset;
  const AEntryPoint, AEventName: string): TEngineScriptExecutionResult;
var
  ProgramSource: string;
  Prog: IdwsProgram;
  Exec: IdwsProgramExecution;
  Obj: TSceneObject;
begin
  if AScript = nil then
    Exit(TEngineScriptExecutionResult.Error('Script is nil.'));

  if not AScript.Enabled then
    Exit(TEngineScriptExecutionResult.Ok);

  ProgramSource := BuildExecutableSource(AScript, AEntryPoint);
  Obj := nil;
  SyncSceneObjectScriptState(AScript);
  if AScript.RuntimeTarget is TSceneObject then
    Obj := TSceneObject(AScript.RuntimeTarget);

  FContext.BeginScript(AScript.Name, AEventName, AScript.TargetKind,
    AScript.TargetName, AScript.RuntimeTarget);
  try
    Result := GetCompiledProgram(ProgramSource, Prog);
    if Assigned(Obj) and Assigned(Obj.ScriptState) then
    begin
      Obj.ScriptState.ProgramSource := ProgramSource;
      Obj.ScriptState.LastMessages := Result.Messages;
      if Result.Success then
      begin
        Obj.ScriptState.CompiledProgram := Prog;
        Obj.ScriptState.Modified := False;
      end
      else
      begin
        Obj.ScriptState.CompiledProgram := nil;
        Obj.ScriptState.Compiled := False;
      end;
    end;
    if not Result.Success then
      Exit;

    // A fresh execution is still created for every invocation, so local/global
    // script state cannot leak between frames. Only the expensive compilation
    // step is reused.
    if Assigned(Obj) and Assigned(Obj.ScriptState) then
      Obj.ScriptState.Running := True;
    try
    Exec := Prog.Execute;
    finally
      if Assigned(Obj) and Assigned(Obj.ScriptState) then
        Obj.ScriptState.Running := False;
    end;
    if Exec.Msgs.HasErrors then
    begin
      if Assigned(Obj) and Assigned(Obj.ScriptState) then
        Obj.ScriptState.LastMessages := Exec.Msgs.AsInfo;
      Exit(TEngineScriptExecutionResult.Error(Exec.Msgs.AsInfo));
    end;

    if Assigned(Obj) and Assigned(Obj.ScriptState) then
      Obj.ScriptState.LastMessages := '';
    Result := TEngineScriptExecutionResult.Ok;
  finally
    FContext.EndScript;
  end;
end;

function TEngineScriptManager.ExecuteLifecycleEvent(
  const AEventName: string): TEngineScriptExecutionResult;
var
  Script: TEngineScriptAsset;
  ScriptResult: TEngineScriptExecutionResult;
begin
  Result := TEngineScriptExecutionResult.Ok;
  if Trim(AEventName) = '' then
    Exit;

  ResolveScriptTargets;
  for Script in FScripts do
    if Assigned(Script) and Script.Enabled and
       ScriptDefinesCallable(Script, AEventName) then
    begin
      ScriptResult := ExecuteScriptEntry(Script, AEventName, AEventName);
      MergeResult(Result, ScriptResult, Script.Name);
    end;
end;

function TEngineScriptManager.ExecuteGlobalScripts(
  const AEventName: string): TEngineScriptExecutionResult;
begin
  Result := ExecuteScriptsForTarget(stkGlobal, nil, AEventName);
end;

function TEngineScriptManager.ExecuteScriptsForTarget(
  ATargetKind: TEngineScriptTargetKind; ATarget: TObject;
  const AEventName: string): TEngineScriptExecutionResult;
var
  Script: TEngineScriptAsset;
  ScriptResult: TEngineScriptExecutionResult;
  TargetName: string;
begin
  Result := TEngineScriptExecutionResult.Ok;
  TargetName := TargetNameFor(ATargetKind, ATarget);

  for Script in FScripts do
    if ScriptMatchesTarget(Script, ATargetKind, ATarget, TargetName) then
    begin
      if (Script.RuntimeTarget = nil) and (ATarget <> nil) then
        Script.RuntimeTarget := ATarget;
      ScriptResult := ExecuteScript(Script, AEventName);
      MergeResult(Result, ScriptResult, Script.Name);
    end;
end;

procedure TEngineScriptManager.SaveToStream(Stream: TStream);
var
  Version, CountValue, I: Integer;
begin
  Stream.WriteBuffer(SCRIPT_FILE_MAGIC[0], SizeOf(SCRIPT_FILE_MAGIC));
  Version := SCRIPT_FILE_VERSION;
  Stream.WriteBuffer(Version, SizeOf(Version));

  CountValue := FScripts.Count;
  Stream.WriteBuffer(CountValue, SizeOf(CountValue));
  for I := 0 to FScripts.Count - 1 do
    FScripts[I].SaveToStream(Stream, Version);
end;

procedure TEngineScriptManager.LoadFromStream(Stream: TStream);
begin
  if not TryLoadFromStream(Stream) then
    raise Exception.Create('Invalid OpenGL Micro Engine script file.');
end;

function TEngineScriptManager.TryLoadFromStream(Stream: TStream): Boolean;
var
  StartPos: Int64;
  Magic: array[0..7] of AnsiChar;
  Version, CountValue, I: Integer;
  Script: TEngineScriptAsset;
begin
  Result := False;
  if (Stream = nil) or (Stream.Position >= Stream.Size) then
    Exit;

  StartPos := Stream.Position;
  if (Stream.Size - Stream.Position) < SizeOf(Magic) then
    Exit;

  Stream.ReadBuffer(Magic[0], SizeOf(Magic));
  if not ScriptMagicMatches(Magic) then
  begin
    Stream.Position := StartPos;
    Exit;
  end;

  Stream.ReadBuffer(Version, SizeOf(Version));
  if (Version < 1) or (Version > SCRIPT_FILE_VERSION) then
    raise Exception.CreateFmt('Unsupported script version: %d.', [Version]);

  Stream.ReadBuffer(CountValue, SizeOf(CountValue));
  if CountValue < 0 then
    raise Exception.Create('Invalid script count in script stream.');

  if Assigned(FContext) and Assigned(FContext.SceneManager) then
    ClearSceneObjectScriptStates(FContext.SceneManager.Root);
  FScripts.Clear;
  ResetRuntimeState;
  for I := 0 to CountValue - 1 do
  begin
      Script := TEngineScriptAsset.Create;
    try
      Script.LoadFromStream(Stream, Version);
      FScripts.Add(Script);
      Script := nil;
    finally
      Script.Free;
    end;
  end;

  ResolveScriptTargets;
  Result := True;
end;

procedure TEngineScriptManager.SaveToFile(const AFileName: string);
begin
  WriteUtf8ScriptTextFile(AFileName, BuildScriptLibraryText(Self));
end;

procedure TEngineScriptManager.LoadFromFile(const AFileName: string);
var
  Stream: TFileStream;
begin
  if TryLoadScriptTextLibraryFromFile(AFileName, Self) then
    Exit;

  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    LoadFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TEngineScriptManager.SaveAssetToFile(AScript: TEngineScriptAsset;
  const AFileName: string);
begin
  if AScript = nil then
    raise Exception.Create('Script asset is nil.');

  AScript.Touch;
  WriteUtf8ScriptTextFile(AFileName, BuildScriptAssetText(AScript));
end;

function TEngineScriptManager.LoadAssetFromFile(
  const AFileName: string): TEngineScriptAsset;
var
  Stream: TFileStream;
  Magic: array[0..7] of AnsiChar;
  Version: Integer;
  Script: TEngineScriptAsset;
begin
  Script := nil;
  if TryLoadScriptTextAssetFromFile(AFileName, Script) then
  begin
    try
      Result := AddOrReplaceAsset(Script);
      Script := nil;
      Exit;
    finally
      Script.Free;
    end;
  end;

  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    if (Stream.Size - Stream.Position) < SizeOf(Magic) then
      raise Exception.Create('Invalid script asset file.');

    Stream.ReadBuffer(Magic[0], SizeOf(Magic));
    if not ScriptAssetMagicMatches(Magic) then
      raise Exception.Create('Invalid script asset file.');

    Stream.ReadBuffer(Version, SizeOf(Version));
    if (Version < 1) or (Version > SCRIPT_ASSET_FILE_VERSION) then
      raise Exception.CreateFmt('Unsupported script asset version: %d.', [Version]);

    Script := TEngineScriptAsset.Create;
    try
      Script.LoadFromStream(Stream, Version);
      Result := AddOrReplaceAsset(Script);
      Script := nil;
    except
      Script.Free;
      raise;
    end;
  finally
    Stream.Free;
  end;
end;

{ TEngineScriptContext }

constructor TEngineScriptContext.Create;
begin
  inherited Create;
  FNextHandle := 1;
  FObjects := TDictionary<Integer, TObject>.Create;
  FHandles := TDictionary<TObject, Integer>.Create;
  CurrentTargetKind := stkGlobal;
  DeltaTime := 0.0;
  TimeSeconds := 0.0;
end;

destructor TEngineScriptContext.Destroy;
begin
  FHandles.Free;
  FObjects.Free;
  inherited Destroy;
end;

procedure TEngineScriptContext.Bind(ARenderer: TRenderer; ASceneManager: TSceneManager;
  AMaterialLibrary: TMaterialLibrary; const ADefaultMaterialName: string;
  ADefaultMeshRender: TOnMeshRender; APhysicsWorld: TPhysicsWorld;
  AAudioEngine: TBassAudioEngine; APrefabLoader: TEngineScriptPrefabLoadCallback;
  APrefabDestroyer: TEngineScriptPrefabDestroyCallback;
  ALogCallback: TEngineScriptLogCallback);
begin
  ClearHandles;
  Renderer := ARenderer;
  SceneManager := ASceneManager;
  MaterialLibrary := AMaterialLibrary;
  DefaultMaterialName := ADefaultMaterialName;
  DefaultMeshRender := ADefaultMeshRender;
  PhysicsWorld := APhysicsWorld;
  AudioEngine := AAudioEngine;
  PrefabLoader := APrefabLoader;
  PrefabDestroyer := APrefabDestroyer;
  LogCallback := ALogCallback;
end;

procedure TEngineScriptContext.ClearHandles;
begin
  FObjects.Clear;
  FHandles.Clear;
  FNextHandle := 1;
end;

function TEngineScriptContext.RegisterHandle(AObject: TObject): Integer;
begin
  if AObject = nil then
    Exit(0);

  if FHandles.TryGetValue(AObject, Result) then
    Exit;

  Result := FNextHandle;
  Inc(FNextHandle);
  FObjects.Add(Result, AObject);
  FHandles.Add(AObject, Result);
end;

function TEngineScriptContext.HandleOf(AObject: TObject): Integer;
begin
  Result := RegisterHandle(AObject);
end;

procedure TEngineScriptContext.Forget(AObject: TObject);
var
  Handle: Integer;
begin
  if (AObject <> nil) and FHandles.TryGetValue(AObject, Handle) then
  begin
    FHandles.Remove(AObject);
    FObjects.Remove(Handle);
  end;
end;

procedure TEngineScriptContext.ForgeTSceneObjectTree(AObject: TSceneObject);
var
  I: Integer;
begin
  if AObject = nil then
    Exit;

  for I := 0 to AObject.Count - 1 do
    ForgeTSceneObjectTree(AObject.ObjectList[I]);

  for I := 0 to AObject.MeshList.Count - 1 do
    Forget(AObject.MeshList.Item[I]);

  for I := 0 to AObject.ParticleSystemCount - 1 do
    Forget(AObject.ParticleSystemItem[I]);

  for I := 0 to AObject.BillboardCount - 1 do
    Forget(AObject.BillboardItem[I]);

  for I := 0 to AObject.AudioEmitterCount - 1 do
    Forget(AObject.AudioEmitterItem[I]);

  for I := 0 to AObject.LightsCount - 1 do
    Forget(AObject.Light[I]);

  if Assigned(PhysicsWorld) then
    Forget(PhysicsWorld.FindBody(AObject));

  Forget(AObject.Camera);
  Forget(AObject);
end;

function TEngineScriptContext.SceneObjectFromHandle(const AHandle: Integer): TSceneObject;
var
  Obj: TObject;
begin
  if (AHandle = 0) and Assigned(SceneManager) then
    Exit(SceneManager.Root);

  if FObjects.TryGetValue(AHandle, Obj) and (Obj is TSceneObject) then
    Exit(TSceneObject(Obj));

  raise Exception.CreateFmt('Invalid scene object handle: %d', [AHandle]);
end;

function TEngineScriptContext.MeshFromHandle(const AHandle: Integer): TMesh;
var
  Obj: TObject;
begin
  if FObjects.TryGetValue(AHandle, Obj) and (Obj is TMesh) then
    Exit(TMesh(Obj));

  raise Exception.CreateFmt('Invalid mesh handle: %d', [AHandle]);
end;

function TEngineScriptContext.LightFromHandle(const AHandle: Integer): TLight;
var
  Obj: TObject;
begin
  if FObjects.TryGetValue(AHandle, Obj) and (Obj is TLight) then
    Exit(TLight(Obj));

  raise Exception.CreateFmt('Invalid light handle: %d', [AHandle]);
end;

function TEngineScriptContext.CameraFromHandle(const AHandle: Integer): TCamera;
var
  Obj: TObject;
begin
  if FObjects.TryGetValue(AHandle, Obj) and (Obj is TCamera) then
    Exit(TCamera(Obj));

  raise Exception.CreateFmt('Invalid camera handle: %d', [AHandle]);
end;

function TEngineScriptContext.MaterialFromHandle(const AHandle: Integer): TMaterial;
var
  Obj: TObject;
begin
  if FObjects.TryGetValue(AHandle, Obj) and (Obj is TMaterial) then
    Exit(TMaterial(Obj));

  raise Exception.CreateFmt('Invalid material handle: %d', [AHandle]);
end;

function TEngineScriptContext.ShaderFromHandle(const AHandle: Integer): TShader;
var
  Obj: TObject;
begin
  if FObjects.TryGetValue(AHandle, Obj) and (Obj is TShader) then
    Exit(TShader(Obj));

  raise Exception.CreateFmt('Invalid shader handle: %d', [AHandle]);
end;

function TEngineScriptContext.ParticleSystemFromHandle(
  const AHandle: Integer): TParticleSystem;
var
  Obj: TObject;
begin
  if FObjects.TryGetValue(AHandle, Obj) and (Obj is TParticleSystem) then
    Exit(TParticleSystem(Obj));

  raise Exception.CreateFmt('Invalid particle system handle: %d', [AHandle]);
end;

function TEngineScriptContext.OwnerOfParticleSystem(
  AParticleSystem: TParticleSystem): TSceneObject;

  function FindInObject(AObject: TSceneObject): TSceneObject;
  var
    I: Integer;
  begin
    Result := nil;
    if AObject = nil then
      Exit;

    for I := 0 to AObject.ParticleSystemCount - 1 do
      if AObject.ParticleSystemItem[I] = AParticleSystem then
        Exit(AObject);

    for I := 0 to AObject.Count - 1 do
    begin
      Result := FindInObject(AObject.ObjectList[I]);
      if Result <> nil then
        Exit;
    end;
  end;

begin
  Result := nil;
  if (AParticleSystem = nil) or (SceneManager = nil) or
     (SceneManager.Root = nil) then
    Exit;

  Result := FindInObject(SceneManager.Root);
end;

function TEngineScriptContext.BillboardFromHandle(const AHandle: Integer): TBillboard;
var
  Obj: TObject;
begin
  if FObjects.TryGetValue(AHandle, Obj) and (Obj is TBillboard) then
    Exit(TBillboard(Obj));

  raise Exception.CreateFmt('Invalid billboard handle: %d', [AHandle]);
end;

function TEngineScriptContext.AudioEmitterFromHandle(
  const AHandle: Integer): TSceneAudioEmitter;
var
  Obj: TObject;
begin
  if FObjects.TryGetValue(AHandle, Obj) and (Obj is TSceneAudioEmitter) then
    Exit(TSceneAudioEmitter(Obj));

  raise Exception.CreateFmt('Invalid audio emitter handle: %d', [AHandle]);
end;

function TEngineScriptContext.PhysicsBodyFromHandle(
  const AHandle: Integer): TPhysicsBody;
var
  Obj: TObject;
begin
  if FObjects.TryGetValue(AHandle, Obj) and (Obj is TPhysicsBody) then
    Exit(TPhysicsBody(Obj));

  raise Exception.CreateFmt('Invalid physics body handle: %d', [AHandle]);
end;

procedure TEngineScriptContext.BeginScript(const AScriptName, AEventName: string;
  ATargetKind: TEngineScriptTargetKind; const ATargetName: string;
  ATarget: TObject);
begin
  CurrentScriptName := AScriptName;
  CurrentEventName := AEventName;
  CurrentTargetKind := ATargetKind;
  CurrentTargetName := ATargetName;
  CurrentTarget := ATarget;
  if CurrentTarget <> nil then
    HandleOf(CurrentTarget);
end;

procedure TEngineScriptContext.EndScript;
begin
  CurrentScriptName := '';
  CurrentEventName := '';
  CurrentTargetKind := stkGlobal;
  CurrentTargetName := '';
  CurrentTarget := nil;
end;

function TEngineScriptContext.CurrentTargetHandle: Integer;
begin
  Result := HandleOf(CurrentTarget);
end;

{ TdwsEngineUnit }

procedure TdwsEngineUnit.RegisterEngineFunction(const AName, AResultType: string;
  const AParamNames, AParamTypes: array of string; const AOnEval: TFuncEvalEvent;
  const AOverloaded: Boolean);
var
  Func: TdwsFunction;
  I: Integer;
  Param: TdwsParameter;
begin
  if Length(AParamNames) <> Length(AParamTypes) then
    raise Exception.Create('Engine function parameter metadata mismatch');

  Func := Functions.Add;
  Func.Name := AName;
  Func.ResultType := AResultType;
  Func.Overloaded := AOverloaded;
  Func.OnEval := AOnEval;

  for I := 0 to High(AParamNames) do
  begin
    Param := Func.Parameters.Add;
    Param.Name := AParamNames[I];
    Param.DataType := AParamTypes[I];
  end;
end;

procedure TdwsEngineUnit.RegisterMeshClass;
var
  ObjClass: TdwsClass;

  procedure AddMethod(const AName, AResultType: string;
    const AParamNames, AParamTypes: array of string; AOnEval: TMethodEvalEvent);
  var
    Method: TdwsMethod;
    Param: TdwsParameter;
    I: Integer;
  begin
    if Length(AParamNames) <> Length(AParamTypes) then
      raise Exception.Create('Mesh method parameter metadata mismatch');

    Method := ObjClass.Methods.Add;
    Method.Name := AName;
    Method.ResultType := AResultType;
    Method.OnEval := AOnEval;

    for I := 0 to High(AParamNames) do
    begin
      Param := Method.Parameters.Add;
      Param.Name := AParamNames[I];
      Param.DataType := AParamTypes[I];
    end;
  end;

  procedure AddProperty(const AName, ADataType, AReadAccess, AWriteAccess: string);
  var
    Prop: TdwsProperty;
  begin
    Prop := ObjClass.Properties.Add;
    Prop.Name := AName;
    Prop.DataType := ADataType;
    Prop.ReadAccess := AReadAccess;
    Prop.WriteAccess := AWriteAccess;
  end;

begin
  ObjClass := Classes.Add;
  ObjClass.Name := 'TMesh';
  ObjClass.OnCleanUp := DoMeshCleanup;

  AddMethod('GetHandle', 'Integer', [], [], DoMeshGetHandle);
  AddMethod('GetName', 'String', [], [], DoMeshGetName);
  AddMethod('SetName', '', ['Value'], ['String'], DoMeshSetNameObject);
  AddMethod('GetPosition', 'TVector3', [], [], DoMeshGetPosition);
  AddMethod('SetPosition', '', ['Value'], ['TVector3'], DoMeshSetPositionObject);
  AddMethod('GetRotation', 'TVector3', [], [], DoMeshGetRotation);
  AddMethod('SetRotation', '', ['Value'], ['TVector3'], DoMeshSetRotationObject);
  AddMethod('GetScale', 'TVector3', [], [], DoMeshGetScale);
  AddMethod('SetScale', '', ['Value'], ['TVector3'], DoMeshSetScaleObject);
  AddMethod('SetTransform', '', ['Position', 'Rotation', 'Scale'],
    ['TVector3', 'TVector3', 'TVector3'], DoMeshSetTransformObject);
  AddMethod('GetVisible', 'Boolean', [], [], DoMeshGetVisible);
  AddMethod('SetVisible', '', ['Value'], ['Boolean'], DoMeshSetVisibleObject);
  AddMethod('GetWireframe', 'Boolean', [], [], DoMeshGetWireframe);
  AddMethod('SetWireframe', '', ['Value'], ['Boolean'], DoMeshSetWireframeObject);
  AddMethod('GetAlwaysOnTop', 'Boolean', [], [], DoMeshGetAlwaysOnTop);
  AddMethod('SetAlwaysOnTop', '', ['Value'], ['Boolean'], DoMeshSetAlwaysOnTopObject);
  AddMethod('GetTag', 'Integer', [], [], DoMeshGetTag);
  AddMethod('SetTag', '', ['Value'], ['Integer'], DoMeshSetTagObject);
  AddMethod('GetMeshType', 'Integer', [], [], DoMeshGetMeshType);
  AddMethod('GetVertexCount', 'Integer', [], [], DoMeshGetVertexCount);
  AddMethod('GetIndexCount', 'Integer', [], [], DoMeshGetIndexCount);
  AddMethod('GetBoundingBoxMin', 'TVector3', [], [], DoMeshGetBoundingBoxMin);
  AddMethod('GetBoundingBoxMax', 'TVector3', [], [], DoMeshGetBoundingBoxMax);
  AddMethod('GetLocalMatrix', 'TMatrix4', [], [], DoMeshGetLocalMatrix);
  AddMethod('GetModelMatrix', 'TMatrix4', [], [], DoMeshGetModelMatrix);
  AddMethod('GetParentModelMatrix', 'TMatrix4', [], [], DoMeshGetParentModelMatrix);
  AddMethod('GetMaterialName', 'String', [], [], DoMeshGetMaterialName);
  AddMethod('SetMaterialName', '', ['Value'], ['String'], DoMeshSetMaterialNameObject);
  AddMethod('SetMaterial', '', ['MaterialName'], ['String'], DoMeshSetMaterialObject);
  AddMethod('ApplyTransform', 'Boolean', ['Translation', 'Rotation', 'Scale'],
    ['TVector3', 'TVector3', 'TVector3'], DoMeshApplyTransformObject);
  AddMethod('ScaleUVs', '', ['ScaleU', 'ScaleV'], ['Float', 'Float'],
    DoMeshScaleUVsObject);
  AddMethod('RecomputeBoundingBox', '', [], [], DoMeshRecomputeBoundingBoxObject);

  AddProperty('Handle', 'Integer', 'GetHandle', '');
  AddProperty('Name', 'String', 'GetName', 'SetName');
  AddProperty('Position', 'TVector3', 'GetPosition', 'SetPosition');
  AddProperty('Rotation', 'TVector3', 'GetRotation', 'SetRotation');
  AddProperty('Scale', 'TVector3', 'GetScale', 'SetScale');
  AddProperty('Visible', 'Boolean', 'GetVisible', 'SetVisible');
  AddProperty('Wireframe', 'Boolean', 'GetWireframe', 'SetWireframe');
  AddProperty('AlwaysOnTop', 'Boolean', 'GetAlwaysOnTop', 'SetAlwaysOnTop');
  AddProperty('Tag', 'Integer', 'GetTag', 'SetTag');
  AddProperty('MeshType', 'Integer', 'GetMeshType', '');
  AddProperty('VertexCount', 'Integer', 'GetVertexCount', '');
  AddProperty('IndexCount', 'Integer', 'GetIndexCount', '');
  AddProperty('BoundingBoxMin', 'TVector3', 'GetBoundingBoxMin', '');
  AddProperty('BoundingBoxMax', 'TVector3', 'GetBoundingBoxMax', '');
  AddProperty('LocalMatrix', 'TMatrix4', 'GetLocalMatrix', '');
  AddProperty('ModelMatrix', 'TMatrix4', 'GetModelMatrix', '');
  AddProperty('ParentModelMatrix', 'TMatrix4', 'GetParentModelMatrix', '');
  AddProperty('MaterialName', 'String', 'GetMaterialName', 'SetMaterialName');
end;

procedure TdwsEngineUnit.RegisterSceneObjectClass;
var
  ObjClass: TdwsClass;
  Ctor: TdwsConstructor;

  procedure AddMethod(const AName, AResultType: string;
    const AParamNames, AParamTypes: array of string; AOnEval: TMethodEvalEvent);
  var
    Method: TdwsMethod;
    Param: TdwsParameter;
    I: Integer;
  begin
    if Length(AParamNames) <> Length(AParamTypes) then
      raise Exception.Create('Scene object method parameter metadata mismatch');

    Method := ObjClass.Methods.Add;
    Method.Name := AName;
    Method.ResultType := AResultType;
    Method.OnEval := AOnEval;

    for I := 0 to High(AParamNames) do
    begin
      Param := Method.Parameters.Add;
      Param.Name := AParamNames[I];
      Param.DataType := AParamTypes[I];
    end;
  end;

  procedure AddProperty(const AName, ADataType, AReadAccess, AWriteAccess: string);
  var
    Prop: TdwsProperty;
  begin
    Prop := ObjClass.Properties.Add;
    Prop.Name := AName;
    Prop.DataType := ADataType;
    Prop.ReadAccess := AReadAccess;
    Prop.WriteAccess := AWriteAccess;
  end;

begin
  ObjClass := Classes.Add;
  ObjClass.Name := 'TSceneObject';
  ObjClass.OnCleanUp := DoSceneObjectCleanup;

  Ctor := ObjClass.Constructors.Add;
  Ctor.Name := 'Create';
  Ctor.Overloaded := True;
  Ctor.OnEval := DoSceneObjectCreate;

  Ctor := ObjClass.Constructors.Add;
  Ctor.Name := 'Create';
  Ctor.Overloaded := True;
  Ctor.Parameters.Add('Position', 'TVector3');
  Ctor.OnEval := DoSceneObjectCreateAt;

  Ctor := ObjClass.Constructors.Add;
  Ctor.Name := 'Create';
  Ctor.Overloaded := True;
  Ctor.Parameters.Add('Name', 'String');
  Ctor.OnEval := DoSceneObjectCreateNamed;

  Ctor := ObjClass.Constructors.Add;
  Ctor.Name := 'Create';
  Ctor.Overloaded := True;
  Ctor.Parameters.Add('Name', 'String');
  Ctor.Parameters.Add('Position', 'TVector3');
  Ctor.OnEval := DoSceneObjectCreateNamedAt;

  Ctor := ObjClass.Constructors.Add;
  Ctor.Name := 'Create';
  Ctor.Overloaded := True;
  Ctor.Parameters.Add('Parent', 'TSceneObject');
  Ctor.Parameters.Add('Name', 'String');
  Ctor.OnEval := DoSceneObjectCreateChild;

  Ctor := ObjClass.Constructors.Add;
  Ctor.Name := 'Create';
  Ctor.Overloaded := True;
  Ctor.Parameters.Add('Parent', 'TSceneObject');
  Ctor.Parameters.Add('Name', 'String');
  Ctor.Parameters.Add('Position', 'TVector3');
  Ctor.OnEval := DoSceneObjectCreateChildAt;

  AddMethod('Delete', '', [], [], DoSceneObjectDelete);
  AddMethod('GetHandle', 'Integer', [], [], DoSceneObjectGetHandle);
  AddMethod('GetName', 'String', [], [], DoSceneObjectGetName);
  AddMethod('SetName', '', ['Value'], ['String'], DoSceneObjectSetName);
  AddMethod('GetPosition', 'TVector3', [], [], DoSceneObjectGetPosition);
  AddMethod('SetPosition', '', ['Value'], ['TVector3'], DoSceneObjectSetPosition);
  AddMethod('GetRotation', 'TVector3', [], [], DoSceneObjectGetRotation);
  AddMethod('SetRotation', '', ['Value'], ['TVector3'], DoSceneObjectSetRotation);
  AddMethod('GetScale', 'TVector3', [], [], DoSceneObjectGetScale);
  AddMethod('SetScale', '', ['Value'], ['TVector3'], DoSceneObjectSetScale);
  AddMethod('GetMatrix', 'TMatrix4', [], [], DoSceneObjectGetMatrix);
  AddMethod('GetModelMatrix', 'TMatrix4', [], [], DoSceneObjectGetModelMatrix);
  AddMethod('GetLocalMatrix', 'TMatrix4', [], [], DoSceneObjectGetLocalMatrix);
  AddMethod('GetWorldMatrix', 'TMatrix4', [], [], DoSceneObjectGetWorldMatrix);
  AddMethod('GetWorldPosition', 'TVector3', [], [], DoSceneObjectGetWorldPosition);
  AddMethod('GetParent', 'TSceneObject', [], [], DoSceneObjectGetParent);
  AddMethod('GetChildCount', 'Integer', [], [], DoSceneObjectGetChildCount);
  AddMethod('Child', 'TSceneObject', ['Index'], ['Integer'], DoSceneObjectChild);
  AddMethod('GetWireframe', 'Boolean', [], [], DoSceneObjectGetWireframe);
  AddMethod('SetWireframe', '', ['Value'], ['Boolean'], DoSceneObjectSetWireframe);
  AddMethod('GetHasGeometry', 'Boolean', [], [], DoSceneObjectGetHasGeometry);
  AddMethod('GetHasCamera', 'Boolean', [], [], DoSceneObjectGetHasCamera);
  AddMethod('GetHasParticles', 'Boolean', [], [], DoSceneObjectGetHasParticles);
  AddMethod('GetHasBillboards', 'Boolean', [], [], DoSceneObjectGetHasBillboards);
  AddMethod('GetHasAudio', 'Boolean', [], [], DoSceneObjectGetHasAudio);
  AddMethod('GetHasSkeletonAnimation', 'Boolean', [], [],
    DoSceneObjectGetHasSkeletonAnimation);
  AddMethod('GetAnimationCount', 'Integer', [], [],
    DoSceneObjectGetAnimationCount);
  AddMethod('AnimationName', 'String', ['Index'], ['Integer'],
    DoSceneObjectAnimationName);
  AddMethod('SetAnimationName', 'Boolean', ['Index', 'Name'],
    ['Integer', 'String'], DoSceneObjectSetAnimationName);
  AddMethod('AnimationIndex', 'Integer', ['Name'], ['String'],
    DoSceneObjectAnimationIndex);
  AddMethod('GetCurrentAnimationName', 'String', [], [],
    DoSceneObjectGetCurrentAnimationName);
  AddMethod('GetCurrentAnimationIndex', 'Integer', [], [],
    DoSceneObjectGetCurrentAnimationIndex);
  AddMethod('PlayAnimation', 'Boolean', ['Name', 'Loop', 'BlendDuration'],
    ['String', 'Boolean', 'Float'], DoSceneObjectPlayAnimation);
  AddMethod('PlayAnimationIndex', 'Boolean',
    ['Index', 'Loop', 'BlendDuration'], ['Integer', 'Boolean', 'Float'],
    DoSceneObjectPlayAnimationIndex);
  AddMethod('BlendToAnimation', 'Boolean', ['Name', 'BlendDuration', 'Loop'],
    ['String', 'Float', 'Boolean'], DoSceneObjectBlendToAnimation);
  AddMethod('IsAnimationPlaying', 'Boolean', ['Name'], ['String'],
    DoSceneObjectIsAnimationPlaying);
  AddMethod('PauseAnimation', '', [], [], DoSceneObjectPauseAnimation);
  AddMethod('ResumeAnimation', '', [], [], DoSceneObjectResumeAnimation);
  AddMethod('StopAnimation', '', ['ResetToBindPose'], ['Boolean'],
    DoSceneObjectStopAnimation);
  AddMethod('GetAnimationState', 'Integer', [], [],
    DoSceneObjectGetAnimationState);
  AddMethod('GetAnimationTime', 'Float', [], [],
    DoSceneObjectGetAnimationTime);
  AddMethod('SetAnimationTime', '', ['Value'], ['Float'],
    DoSceneObjectSetAnimationTime);
  AddMethod('GetAnimationNormalizedTime', 'Float', [], [],
    DoSceneObjectGetAnimationNormalizedTime);
  AddMethod('SetAnimationNormalizedTime', '', ['Value'], ['Float'],
    DoSceneObjectSetAnimationNormalizedTime);
  AddMethod('GetAnimationDuration', 'Float', [], [],
    DoSceneObjectGetAnimationDuration);
  AddMethod('AnimationClipDuration', 'Float', ['Index'], ['Integer'],
    DoSceneObjectAnimationClipDuration);
  AddMethod('AnimationClipDurationByName', 'Float', ['Name'], ['String'],
    DoSceneObjectAnimationClipDurationByName);
  AddMethod('GetAnimationSpeed', 'Float', [], [],
    DoSceneObjectGetAnimationSpeed);
  AddMethod('SetAnimationSpeed', '', ['Value'], ['Float'],
    DoSceneObjectSetAnimationSpeed);
  AddMethod('GetAnimationLooping', 'Boolean', [], [],
    DoSceneObjectGetAnimationLooping);
  AddMethod('SetAnimationLooping', '', ['Value'], ['Boolean'],
    DoSceneObjectSetAnimationLooping);
  AddMethod('GetAnimationBlending', 'Boolean', [], [],
    DoSceneObjectGetAnimationBlending);
  AddMethod('GetMeshCount', 'Integer', [], [], DoSceneObjectGetMeshCount);
  AddMethod('Mesh', 'Integer', ['Index'], ['Integer'], DoSceneObjectMesh);
  AddMethod('MeshObject', 'TMesh', ['Index'], ['Integer'], DoSceneObjectMeshObject);
  AddMethod('AddMeshFile', 'Integer', ['FileName'], ['String'], DoSceneObjectAddMeshFile);
  AddMethod('AddMeshFileObject', 'TMesh', ['FileName'], ['String'], DoSceneObjectAddMeshFileObject);
  AddMethod('SetMaterial', '', ['MaterialName'], ['String'], DoSceneObjectSetMaterial);
  AddMethod('GetParticleSystemCount', 'Integer', [], [], DoSceneObjectGetParticleSystemCount);
  AddMethod('ParticleSystem', 'Integer', ['Index'], ['Integer'], DoSceneObjectParticleSystem);
  AddMethod('CreateParticleSystem', 'Integer', [], [], DoSceneObjectCreateParticleSystem);
  AddMethod('RemoveParticleSystem', '', ['Index'], ['Integer'], DoSceneObjectRemoveParticleSystem);
  AddMethod('GetLightCount', 'Integer', [], [], DoSceneObjectGetLightCount);
  AddMethod('Light', 'Integer', ['Index'], ['Integer'], DoSceneObjectLight);
  AddMethod('CreateLight', 'Integer', [], [], DoSceneObjectCreateLight);
  AddMethod('LightObject', 'TLight', ['Index'], ['Integer'], DoSceneObjectLightObject);
  AddMethod('CreateLightObject', 'TLight', [], [], DoSceneObjectCreateLightObject);
  AddMethod('Camera', 'Integer', [], [], DoSceneObjectCamera);
  AddMethod('CreateCamera', 'Integer', [], [], DoSceneObjectCreateCamera);

  AddProperty('Handle', 'Integer', 'GetHandle', '');
  AddProperty('Name', 'String', 'GetName', 'SetName');
  AddProperty('Position', 'TVector3', 'GetPosition', 'SetPosition');
  AddProperty('Rotation', 'TVector3', 'GetRotation', 'SetRotation');
  AddProperty('Scale', 'TVector3', 'GetScale', 'SetScale');
  AddProperty('Matrix', 'TMatrix4', 'GetMatrix', '');
  AddProperty('ModelMatrix', 'TMatrix4', 'GetModelMatrix', '');
  AddProperty('LocalMatrix', 'TMatrix4', 'GetLocalMatrix', '');
  AddProperty('WorldMatrix', 'TMatrix4', 'GetWorldMatrix', '');
  AddProperty('WorldPosition', 'TVector3', 'GetWorldPosition', '');
  AddProperty('Parent', 'TSceneObject', 'GetParent', '');
  AddProperty('ChildCount', 'Integer', 'GetChildCount', '');
  AddProperty('Wireframe', 'Boolean', 'GetWireframe', 'SetWireframe');
  AddProperty('HasGeometry', 'Boolean', 'GetHasGeometry', '');
  AddProperty('HasCamera', 'Boolean', 'GetHasCamera', '');
  AddProperty('HasParticles', 'Boolean', 'GetHasParticles', '');
  AddProperty('HasBillboards', 'Boolean', 'GetHasBillboards', '');
  AddProperty('HasAudio', 'Boolean', 'GetHasAudio', '');
  AddProperty('HasSkeletonAnimation', 'Boolean',
    'GetHasSkeletonAnimation', '');
  AddProperty('AnimationCount', 'Integer', 'GetAnimationCount', '');
  AddProperty('CurrentAnimationName', 'String', 'GetCurrentAnimationName', '');
  AddProperty('CurrentAnimationIndex', 'Integer',
    'GetCurrentAnimationIndex', '');
  AddProperty('AnimationState', 'Integer', 'GetAnimationState', '');
  AddProperty('AnimationTime', 'Float', 'GetAnimationTime', 'SetAnimationTime');
  AddProperty('AnimationNormalizedTime', 'Float',
    'GetAnimationNormalizedTime', 'SetAnimationNormalizedTime');
  AddProperty('AnimationDuration', 'Float', 'GetAnimationDuration', '');
  AddProperty('AnimationSpeed', 'Float', 'GetAnimationSpeed',
    'SetAnimationSpeed');
  AddProperty('AnimationLooping', 'Boolean', 'GetAnimationLooping',
    'SetAnimationLooping');
  AddProperty('AnimationBlending', 'Boolean', 'GetAnimationBlending', '');
  AddProperty('MeshCount', 'Integer', 'GetMeshCount', '');
  AddProperty('ParticleSystemCount', 'Integer', 'GetParticleSystemCount', '');
  AddProperty('LightCount', 'Integer', 'GetLightCount', '');
end;

procedure TdwsEngineUnit.RegisterLightClass;
var
  ObjClass: TdwsClass;

  procedure AddMethod(const AName, AResultType: string;
    const AParamNames, AParamTypes: array of string; AOnEval: TMethodEvalEvent);
  var
    Method: TdwsMethod;
    Param: TdwsParameter;
    I: Integer;
  begin
    if Length(AParamNames) <> Length(AParamTypes) then
      raise Exception.Create('Light method parameter metadata mismatch');

    Method := ObjClass.Methods.Add;
    Method.Name := AName;
    Method.ResultType := AResultType;
    Method.OnEval := AOnEval;

    for I := 0 to High(AParamNames) do
    begin
      Param := Method.Parameters.Add;
      Param.Name := AParamNames[I];
      Param.DataType := AParamTypes[I];
    end;
  end;

  procedure AddProperty(const AName, ADataType, AReadAccess, AWriteAccess: string);
  var
    Prop: TdwsProperty;
  begin
    Prop := ObjClass.Properties.Add;
    Prop.Name := AName;
    Prop.DataType := ADataType;
    Prop.ReadAccess := AReadAccess;
    Prop.WriteAccess := AWriteAccess;
  end;

begin
  ObjClass := Classes.Add;
  ObjClass.Name := 'TLight';
  ObjClass.OnCleanUp := DoLightCleanup;

  AddMethod('GetHandle', 'Integer', [], [], DoLightGetHandle);
  AddMethod('GetName', 'String', [], [], DoLightGetName);
  AddMethod('SetName', '', ['Value'], ['String'], DoLightSetName);
  AddMethod('GetLightType', 'Integer', [], [], DoLightGetType);
  AddMethod('SetLightType', '', ['Value'], ['Integer'], DoLightSetTypeObject);
  AddMethod('GetEnabled', 'Boolean', [], [], DoLightGetEnabled);
  AddMethod('SetEnabled', '', ['Value'], ['Boolean'], DoLightSetEnabledObject);
  AddMethod('GetAmbient', 'TVector3', [], [], DoLightGetAmbient);
  AddMethod('SetAmbient', '', ['Value'], ['TVector3'], DoLightSetAmbientObject);
  AddMethod('GetDiffuse', 'TVector3', [], [], DoLightGetDiffuse);
  AddMethod('SetDiffuse', '', ['Value'], ['TVector3'], DoLightSetDiffuseObject);
  AddMethod('GetSpecular', 'TVector3', [], [], DoLightGetSpecular);
  AddMethod('SetSpecular', '', ['Value'], ['TVector3'], DoLightSetSpecularObject);
  AddMethod('GetPosition', 'TVector3', [], [], DoLightGetPosition);
  AddMethod('SetPosition', '', ['Value'], ['TVector3'], DoLightSetPositionObject);
  AddMethod('GetDirection', 'TVector3', [], [], DoLightGetDirection);
  AddMethod('SetDirection', '', ['Value'], ['TVector3'], DoLightSetDirectionObject);
  AddMethod('GetUseTarget', 'Boolean', [], [], DoLightGetUseTarget);
  AddMethod('SetUseTarget', '', ['Value'], ['Boolean'], DoLightSetUseTarget);
  AddMethod('GetTargetPosition', 'TVector3', [], [], DoLightGetTargetPosition);
  AddMethod('SetTargetPosition', '', ['Value'], ['TVector3'], DoLightSetTargetPosition);
  AddMethod('GetConstantAttenuation', 'Float', [], [], DoLightGetConstantAttenuation);
  AddMethod('SetConstantAttenuation', '', ['Value'], ['Float'], DoLightSetConstantAttenuation);
  AddMethod('GetLinearAttenuation', 'Float', [], [], DoLightGetLinearAttenuation);
  AddMethod('SetLinearAttenuation', '', ['Value'], ['Float'], DoLightSetLinearAttenuation);
  AddMethod('GetQuadraticAttenuation', 'Float', [], [], DoLightGetQuadraticAttenuation);
  AddMethod('SetQuadraticAttenuation', '', ['Value'], ['Float'], DoLightSetQuadraticAttenuation);
  AddMethod('GetSpotCutoff', 'Float', [], [], DoLightGetSpotCutoff);
  AddMethod('SetSpotCutoff', '', ['Value'], ['Float'], DoLightSetSpotCutoff);
  AddMethod('GetSpotExponent', 'Float', [], [], DoLightGetSpotExponent);
  AddMethod('SetSpotExponent', '', ['Value'], ['Float'], DoLightSetSpotExponent);
  AddMethod('GetCastShadows', 'Boolean', [], [], DoLightGetCastShadows);
  AddMethod('SetCastShadows', '', ['Value'], ['Boolean'], DoLightSetCastShadowsObject);
  AddMethod('GetShadowStrength', 'Float', [], [], DoLightGetShadowStrength);
  AddMethod('SetShadowStrength', '', ['Value'], ['Float'], DoLightSetShadowStrengthObject);
  AddMethod('SetAttenuation', '', ['Constant', 'Linear', 'Quadratic'],
    ['Float', 'Float', 'Float'], DoLightSetAttenuationObject);
  AddMethod('SetSpot', '', ['CutoffDegrees', 'Exponent'],
    ['Float', 'Float'], DoLightSetSpotObject);

  AddProperty('Handle', 'Integer', 'GetHandle', '');
  AddProperty('Name', 'String', 'GetName', 'SetName');
  AddProperty('LightType', 'Integer', 'GetLightType', 'SetLightType');
  AddProperty('Enabled', 'Boolean', 'GetEnabled', 'SetEnabled');
  AddProperty('Ambient', 'TVector3', 'GetAmbient', 'SetAmbient');
  AddProperty('Diffuse', 'TVector3', 'GetDiffuse', 'SetDiffuse');
  AddProperty('Specular', 'TVector3', 'GetSpecular', 'SetSpecular');
  AddProperty('Position', 'TVector3', 'GetPosition', 'SetPosition');
  AddProperty('Direction', 'TVector3', 'GetDirection', 'SetDirection');
  AddProperty('UseTarget', 'Boolean', 'GetUseTarget', 'SetUseTarget');
  AddProperty('TargetPosition', 'TVector3', 'GetTargetPosition', 'SetTargetPosition');
  AddProperty('ConstantAttenuation', 'Float', 'GetConstantAttenuation', 'SetConstantAttenuation');
  AddProperty('LinearAttenuation', 'Float', 'GetLinearAttenuation', 'SetLinearAttenuation');
  AddProperty('QuadraticAttenuation', 'Float', 'GetQuadraticAttenuation', 'SetQuadraticAttenuation');
  AddProperty('SpotCutoff', 'Float', 'GetSpotCutoff', 'SetSpotCutoff');
  AddProperty('SpotExponent', 'Float', 'GetSpotExponent', 'SetSpotExponent');
  AddProperty('CastShadows', 'Boolean', 'GetCastShadows', 'SetCastShadows');
  AddProperty('ShadowStrength', 'Float', 'GetShadowStrength', 'SetShadowStrength');
end;

procedure TdwsEngineUnit.RegisterMaterialClass;
var
  ObjClass: TdwsClass;

  procedure AddMethod(const AName, AResultType: string;
    const AParamNames, AParamTypes: array of string; AOnEval: TMethodEvalEvent);
  var
    Method: TdwsMethod;
    Param: TdwsParameter;
    I: Integer;
  begin
    if Length(AParamNames) <> Length(AParamTypes) then
      raise Exception.Create('Material method parameter metadata mismatch');

    Method := ObjClass.Methods.Add;
    Method.Name := AName;
    Method.ResultType := AResultType;
    Method.OnEval := AOnEval;

    for I := 0 to High(AParamNames) do
    begin
      Param := Method.Parameters.Add;
      Param.Name := AParamNames[I];
      Param.DataType := AParamTypes[I];
    end;
  end;

  procedure AddProperty(const AName, ADataType, AReadAccess, AWriteAccess: string);
  var
    Prop: TdwsProperty;
  begin
    Prop := ObjClass.Properties.Add;
    Prop.Name := AName;
    Prop.DataType := ADataType;
    Prop.ReadAccess := AReadAccess;
    Prop.WriteAccess := AWriteAccess;
  end;

begin
  ObjClass := Classes.Add;
  ObjClass.Name := 'TMaterial';
  ObjClass.OnCleanUp := DoMaterialCleanup;

  AddMethod('GetHandle', 'Integer', [], [], DoMaterialGetHandle);
  AddMethod('GetName', 'String', [], [], DoMaterialGetName);
  AddMethod('SetName', '', ['Value'], ['String'], DoMaterialSetName);
  AddMethod('GetTextureCount', 'Integer', [], [], DoMaterialGetTextureCount);
  AddMethod('GetMaterialID', 'Integer', [], [], DoMaterialGetMaterialID);
  AddMethod('GetMaterialType', 'Integer', [], [], DoMaterialGetMaterialType);
  AddMethod('SetMaterialType', '', ['Value'], ['Integer'], DoMaterialSetMaterialType);
  AddMethod('GetShader', 'TShader', [], [], DoMaterialGetShader);
  AddMethod('SetShader', '', ['Value'], ['TShader'], DoMaterialSetShader);
  AddMethod('ShaderParameter', 'Float', ['Name'], ['String'], DoMaterialShaderParameterObject);
  AddMethod('SetShaderParameter', '', ['Name', 'Value'], ['String', 'Float'], DoMaterialSetShaderParameterObject);

  AddProperty('Handle', 'Integer', 'GetHandle', '');
  AddProperty('Name', 'String', 'GetName', 'SetName');
  AddProperty('TextureCount', 'Integer', 'GetTextureCount', '');
  AddProperty('MaterialID', 'Integer', 'GetMaterialID', '');
  AddProperty('MaterialType', 'Integer', 'GetMaterialType', 'SetMaterialType');
  AddProperty('Shader', 'TShader', 'GetShader', 'SetShader');
end;

procedure TdwsEngineUnit.RegisterShaderClass;
var
  ObjClass: TdwsClass;

  procedure AddMethod(const AName, AResultType: string;
    const AParamNames, AParamTypes: array of string; AOnEval: TMethodEvalEvent);
  var
    Method: TdwsMethod;
    Param: TdwsParameter;
    I: Integer;
  begin
    if Length(AParamNames) <> Length(AParamTypes) then
      raise Exception.Create('Shader method parameter metadata mismatch');

    Method := ObjClass.Methods.Add;
    Method.Name := AName;
    Method.ResultType := AResultType;
    Method.OnEval := AOnEval;

    for I := 0 to High(AParamNames) do
    begin
      Param := Method.Parameters.Add;
      Param.Name := AParamNames[I];
      Param.DataType := AParamTypes[I];
    end;
  end;

  procedure AddProperty(const AName, ADataType, AReadAccess, AWriteAccess: string);
  var
    Prop: TdwsProperty;
  begin
    Prop := ObjClass.Properties.Add;
    Prop.Name := AName;
    Prop.DataType := ADataType;
    Prop.ReadAccess := AReadAccess;
    Prop.WriteAccess := AWriteAccess;
  end;

begin
  ObjClass := Classes.Add;
  ObjClass.Name := 'TShader';
  ObjClass.OnCleanUp := DoShaderCleanup;

  AddMethod('GetHandle', 'Integer', [], [], DoShaderGetHandle);
  AddMethod('GetVertexPath', 'String', [], [], DoShaderGetVertexPath);
  AddMethod('GetFragmentPath', 'String', [], [], DoShaderGetFragmentPath);
  AddMethod('GetProgramID', 'Integer', [], [], DoShaderGetProgramID);
  AddMethod('Use', '', [], [], DoShaderUseObject);
  AddMethod('Reload', '', [], [], DoShaderReloadObject);
  AddMethod('SetUniformBoolean', '', ['Name', 'Value'], ['String', 'Boolean'], DoShaderSetUniformBooleanObject);
  AddMethod('SetUniformInteger', '', ['Name', 'Value'], ['String', 'Integer'], DoShaderSetUniformIntegerObject);
  AddMethod('SetUniformFloat', '', ['Name', 'Value'], ['String', 'Float'], DoShaderSetUniformFloatObject);
  AddMethod('SetUniformVector3', '', ['Name', 'Value'], ['String', 'TVector3'], DoShaderSetUniformVector3Object);
  AddMethod('SetUniformVector4', '', ['Name', 'Value'], ['String', 'TVector4'], DoShaderSetUniformVector4Object);
  AddMethod('SetUniformMatrix4', '', ['Name', 'Value'], ['String', 'TMatrix4'], DoShaderSetUniformMatrix4Object);

  AddProperty('Handle', 'Integer', 'GetHandle', '');
  AddProperty('VertexPath', 'String', 'GetVertexPath', '');
  AddProperty('FragmentPath', 'String', 'GetFragmentPath', '');
  AddProperty('ProgramID', 'Integer', 'GetProgramID', '');
end;

procedure TdwsEngineUnit.RequireContext;
begin
  if (FContext = nil) or (FContext.SceneManager = nil) then
    raise Exception.Create('Engine scripting context is not bound to a scene');
end;

function TdwsEngineUnit.RequireSkyDome: TSkyDome;
begin
  if (FContext = nil) or (FContext.Renderer = nil) then
    raise Exception.Create('Engine scripting context is not bound to a renderer');

  if FContext.Renderer.SkyDome = nil then
    FContext.Renderer.SkyDome := TSkyDome.Create;

  Result := FContext.Renderer.SkyDome;
end;

function TdwsEngineUnit.RootObject: TSceneObject;
begin
  RequireContext;
  Result := FContext.SceneManager.Root;
end;

function TdwsEngineUnit.ParentOrRootFromHandle(const AHandle: Integer): TSceneObject;
begin
  RequireContext;
  if AHandle = 0 then
    Result := RootObject
  else
    Result := FContext.SceneObjectFromHandle(AHandle);
end;

function TdwsEngineUnit.RequireSceneObject(ExtObject: TObject): TSceneObject;
begin
  if ExtObject is TSceneObject then
    Exit(TSceneObject(ExtObject));

  raise Exception.Create('Invalid or destroyed TSceneObject script object.');
end;

function TdwsEngineUnit.ParamAsSceneObject(Info: TProgramInfo;
  const AIndex: Integer): TSceneObject;
var
  Obj: TObject;
begin
  Obj := Info.ParamAsObject[AIndex];
  if Obj is TSceneObject then
    Exit(TSceneObject(Obj));

  Result := nil;
end;

procedure TdwsEngineUnit.SetResultSceneObject(Info: TProgramInfo; AObject: TSceneObject);
begin
  if AObject <> nil then
    Info.ResultAsVariant := Info.RegisterExternalObject(AObject, False, False)
  else
    Info.ResultAsVariant := IScriptObj(nil);
end;

function TdwsEngineUnit.RequireMesh(ExtObject: TObject): TMesh;
begin
  if ExtObject is TMesh then
    Exit(TMesh(ExtObject));

  raise Exception.Create('Invalid or destroyed TMesh script object.');
end;

function TdwsEngineUnit.ParamAsMesh(Info: TProgramInfo;
  const AIndex: Integer): TMesh;
var
  Obj: TObject;
begin
  Obj := Info.ParamAsObject[AIndex];
  if Obj is TMesh then
    Exit(TMesh(Obj));

  Result := nil;
end;

procedure TdwsEngineUnit.SetResultMesh(Info: TProgramInfo; AMesh: TMesh);
begin
  if AMesh <> nil then
    Info.ResultAsVariant := Info.RegisterExternalObject(AMesh, False, False)
  else
    Info.ResultAsVariant := IScriptObj(nil);
end;

function TdwsEngineUnit.RequireLight(ExtObject: TObject): TLight;
begin
  if ExtObject is TLight then
    Exit(TLight(ExtObject));

  raise Exception.Create('Invalid or destroyed TLight script object.');
end;

function TdwsEngineUnit.ParamAsLight(Info: TProgramInfo;
  const AIndex: Integer): TLight;
var
  Obj: TObject;
begin
  Obj := Info.ParamAsObject[AIndex];
  if Obj is TLight then
    Exit(TLight(Obj));

  Result := nil;
end;

procedure TdwsEngineUnit.SetResultLight(Info: TProgramInfo; ALight: TLight);
begin
  if ALight <> nil then
  begin
    FContext.HandleOf(ALight);
    Info.ResultAsVariant := Info.RegisterExternalObject(ALight, False, False);
  end
  else
    Info.ResultAsVariant := IScriptObj(nil);
end;

function TdwsEngineUnit.RequireMaterial(ExtObject: TObject): TMaterial;
begin
  if ExtObject is TMaterial then
    Exit(TMaterial(ExtObject));

  raise Exception.Create('Invalid or destroyed TMaterial script object.');
end;

function TdwsEngineUnit.ParamAsMaterial(Info: TProgramInfo;
  const AIndex: Integer): TMaterial;
var
  Obj: TObject;
begin
  Obj := Info.ParamAsObject[AIndex];
  if Obj is TMaterial then
    Exit(TMaterial(Obj));

  Result := nil;
end;

procedure TdwsEngineUnit.SetResultMaterial(Info: TProgramInfo; AMaterial: TMaterial);
begin
  if AMaterial <> nil then
  begin
    FContext.HandleOf(AMaterial);
    Info.ResultAsVariant := Info.RegisterExternalObject(AMaterial, False, False);
  end
  else
    Info.ResultAsVariant := IScriptObj(nil);
end;

function TdwsEngineUnit.RequireShader(ExtObject: TObject): TShader;
begin
  if ExtObject is TShader then
    Exit(TShader(ExtObject));

  raise Exception.Create('Invalid or destroyed TShader script object.');
end;

function TdwsEngineUnit.ParamAsShader(Info: TProgramInfo;
  const AIndex: Integer): TShader;
var
  Obj: TObject;
begin
  Obj := Info.ParamAsObject[AIndex];
  if Obj is TShader then
    Exit(TShader(Obj));

  Result := nil;
end;

procedure TdwsEngineUnit.SetResultShader(Info: TProgramInfo; AShader: TShader);
begin
  if AShader <> nil then
  begin
    FContext.HandleOf(AShader);
    Info.ResultAsVariant := Info.RegisterExternalObject(AShader, False, False);
  end
  else
    Info.ResultAsVariant := IScriptObj(nil);
end;

function TdwsEngineUnit.WorldMatrixOf(AObject: TSceneObject): TMatrix4;
begin
  if AObject = nil then
    Exit(TMatrix4.Identity);

  if (FContext <> nil) and (FContext.SceneManager <> nil) and
     (FContext.SceneManager.Root <> nil) then
    FContext.SceneManager.Update
  else
    AObject.UpdateWorldMatrices;

  Result := AObject.WorldMatrix;
end;

function TdwsEngineUnit.WorldPositionOf(AObject: TSceneObject): TVector3;
begin
  Result := Vector3(WorldMatrixOf(AObject).Columns[3]);
end;

function TdwsEngineUnit.DefaultObjectSpawnPosition(
  AParent: TSceneObject): TVector3;
const
  DEFAULT_OBJECT_SPAWN_DISTANCE = 5.0;
var
  CameraObject: TSceneObject;
  SpawnWorldPosition: TVector3;
begin
  Result := Vector3(0, 0, 0);
  if (FContext = nil) or (FContext.Renderer = nil) then
    Exit;

  CameraObject := FContext.Renderer.ActiveCamera;
  if (CameraObject = nil) or (CameraObject.Camera = nil) then
    Exit;

  SpawnWorldPosition := CameraObject.Camera.Position +
    (CameraObject.Camera.Front * DEFAULT_OBJECT_SPAWN_DISTANCE);
  if AParent = nil then
    Exit(SpawnWorldPosition);

  Result := Vector3(WorldMatrixOf(AParent).Inverse *
    Vector4(SpawnWorldPosition, 1));
end;

function TdwsEngineUnit.RequireHeightFieldMesh(
  const AHandle: Integer): THeightFieldMesh;
var
  Mesh: TMesh;
begin
  Mesh := FContext.MeshFromHandle(AHandle);
  if Mesh is THeightFieldMesh then
    Exit(THeightFieldMesh(Mesh));

  raise Exception.CreateFmt('Mesh handle %d is not a height field mesh.', [AHandle]);
end;

procedure TdwsEngineUnit.ReleaseAudioEmitterRuntime(AEmitter: TSceneAudioEmitter);
var
  Sound: TBassSound;
begin
  if AEmitter = nil then
    Exit;

  Sound := AEmitter.RuntimeSound;
  if FContext <> nil then
    if (FContext.AudioEngine <> nil) and (Sound <> nil) then
      FContext.AudioEngine.FreeSound(Sound);
  AEmitter.RuntimeSound := nil;
end;

procedure TdwsEngineUnit.ReleaseSceneObjectAudio(AObject: TSceneObject);
var
  I: Integer;
begin
  if AObject = nil then
    Exit;

  for I := 0 to AObject.AudioEmitterCount - 1 do
    ReleaseAudioEmitterRuntime(AObject.AudioEmitterItem[I]);

  for I := 0 to AObject.Count - 1 do
    ReleaseSceneObjectAudio(AObject.ObjectList[I]);
end;

procedure TdwsEngineUnit.DestroySceneObjectForScript(AObject: TSceneObject);
begin
  if AObject = nil then
    Exit;

  RequireContext;
  FContext.ForgeTSceneObjectTree(AObject);
  ReleaseSceneObjectAudio(AObject);
  if FContext.PhysicsWorld <> nil then
    FContext.PhysicsWorld.RemoveBodiesForScene(AObject, True);
  AObject.Free;
end;

procedure TdwsEngineUnit.SetInfoVector2(const AInfo: IInfo;
  const AVector: TVector2);
begin
  AInfo.Member['X'].Value := AVector.X;
  AInfo.Member['Y'].Value := AVector.Y;
end;

procedure TdwsEngineUnit.SetResultVector2(Info: TProgramInfo;
  const AVector: TVector2);
begin
  SetInfoVector2(Info.ResultVars, AVector);
end;

function TdwsEngineUnit.InfoAsVector3(const AInfo: IInfo): TVector3;
begin
  Result := Vector3(
    AInfo.Member['X'].ValueAsFloat,
    AInfo.Member['Y'].ValueAsFloat,
    AInfo.Member['Z'].ValueAsFloat);
end;

function TdwsEngineUnit.ParamAsVector3(Info: TProgramInfo; const AIndex: Integer): TVector3;
begin
  Result := InfoAsVector3(Info.Params[AIndex]);
end;

procedure TdwsEngineUnit.SetInfoVector3(const AInfo: IInfo; const AVector: TVector3);
begin
  AInfo.Member['X'].Value := AVector.X;
  AInfo.Member['Y'].Value := AVector.Y;
  AInfo.Member['Z'].Value := AVector.Z;
end;

procedure TdwsEngineUnit.SetResultVector3(Info: TProgramInfo; const AVector: TVector3);
begin
  SetInfoVector3(Info.ResultVars, AVector);
end;

function TdwsEngineUnit.InfoAsVector4(const AInfo: IInfo): TVector4;
begin
  Result := Vector4(
    AInfo.Member['X'].ValueAsFloat,
    AInfo.Member['Y'].ValueAsFloat,
    AInfo.Member['Z'].ValueAsFloat,
    AInfo.Member['W'].ValueAsFloat);
end;

function TdwsEngineUnit.ParamAsVector4(Info: TProgramInfo; const AIndex: Integer): TVector4;
begin
  Result := InfoAsVector4(Info.Params[AIndex]);
end;

procedure TdwsEngineUnit.SetInfoVector4(const AInfo: IInfo; const AVector: TVector4);
begin
  AInfo.Member['X'].Value := AVector.X;
  AInfo.Member['Y'].Value := AVector.Y;
  AInfo.Member['Z'].Value := AVector.Z;
  AInfo.Member['W'].Value := AVector.W;
end;

procedure TdwsEngineUnit.SetResultVector4(Info: TProgramInfo; const AVector: TVector4);
begin
  SetInfoVector4(Info.ResultVars, AVector);
end;

function TdwsEngineUnit.InfoAsMatrix4(const AInfo: IInfo): TMatrix4;
begin
  Result := Matrix4(
    AInfo.Member['M11'].ValueAsFloat, AInfo.Member['M12'].ValueAsFloat,
    AInfo.Member['M13'].ValueAsFloat, AInfo.Member['M14'].ValueAsFloat,
    AInfo.Member['M21'].ValueAsFloat, AInfo.Member['M22'].ValueAsFloat,
    AInfo.Member['M23'].ValueAsFloat, AInfo.Member['M24'].ValueAsFloat,
    AInfo.Member['M31'].ValueAsFloat, AInfo.Member['M32'].ValueAsFloat,
    AInfo.Member['M33'].ValueAsFloat, AInfo.Member['M34'].ValueAsFloat,
    AInfo.Member['M41'].ValueAsFloat, AInfo.Member['M42'].ValueAsFloat,
    AInfo.Member['M43'].ValueAsFloat, AInfo.Member['M44'].ValueAsFloat);
end;

function TdwsEngineUnit.ParamAsMatrix4(Info: TProgramInfo;
  const AIndex: Integer): TMatrix4;
begin
  Result := InfoAsMatrix4(Info.Params[AIndex]);
end;

procedure TdwsEngineUnit.SetInfoMatrix4(const AInfo: IInfo;
  const AMatrix: TMatrix4);
begin
  AInfo.Member['M11'].Value := AMatrix.m11;
  AInfo.Member['M12'].Value := AMatrix.m12;
  AInfo.Member['M13'].Value := AMatrix.m13;
  AInfo.Member['M14'].Value := AMatrix.m14;
  AInfo.Member['M21'].Value := AMatrix.m21;
  AInfo.Member['M22'].Value := AMatrix.m22;
  AInfo.Member['M23'].Value := AMatrix.m23;
  AInfo.Member['M24'].Value := AMatrix.m24;
  AInfo.Member['M31'].Value := AMatrix.m31;
  AInfo.Member['M32'].Value := AMatrix.m32;
  AInfo.Member['M33'].Value := AMatrix.m33;
  AInfo.Member['M34'].Value := AMatrix.m34;
  AInfo.Member['M41'].Value := AMatrix.m41;
  AInfo.Member['M42'].Value := AMatrix.m42;
  AInfo.Member['M43'].Value := AMatrix.m43;
  AInfo.Member['M44'].Value := AMatrix.m44;
end;

procedure TdwsEngineUnit.SetResultMatrix4(Info: TProgramInfo;
  const AMatrix: TMatrix4);
begin
  SetInfoMatrix4(Info.ResultVars, AMatrix);
end;

procedure TdwsEngineUnit.ConfigureMesh(AMesh: TMesh);
begin
  if AMesh = nil then
    Exit;

  if Assigned(FContext.MaterialLibrary) then
  begin
    AMesh.MaterialLibrary := FContext.MaterialLibrary;
    AMesh.LibMaterialname := FContext.DefaultMaterialName;
  end;

  if Assigned(FContext.DefaultMeshRender) then
    AMesh.OnRender := FContext.DefaultMeshRender;
end;

function TdwsEngineUnit.AddMeshToObject(AObject: TSceneObject; AMesh: TMesh): Integer;
begin
  if (AObject = nil) or (AMesh = nil) then
    Exit(0);

  ConfigureMesh(AMesh);
  AObject.MeshList.AddMeshToList(AMesh);
  AObject.UpdateBoundingRadiusFromMesh;
  AObject.NotifyChange;
  Result := FContext.HandleOf(AMesh);
end;

function TdwsEngineUnit.FindMeshOwnerRecursive(AObject: TSceneObject;
  AMesh: TMesh): TSceneObject;
var
  I: Integer;
begin
  Result := nil;
  if (AObject = nil) or (AMesh = nil) then
    Exit;

  for I := 0 to AObject.MeshList.Count - 1 do
    if AObject.MeshList.Item[I] = AMesh then
      Exit(AObject);

  for I := 0 to AObject.Count - 1 do
  begin
    Result := FindMeshOwnerRecursive(AObject.ObjectList[I], AMesh);
    if Result <> nil then
      Exit;
  end;
end;

procedure TdwsEngineUnit.NotifyMeshChanged(AMesh: TMesh;
  const AGeometryChanged: Boolean);
var
  Owner: TSceneObject;
begin
  if AMesh = nil then
    Exit;

  if AGeometryChanged then
    AMesh.RecomputeBoundingBox;

  if (FContext = nil) or (FContext.SceneManager = nil) or
     (FContext.SceneManager.Root = nil) then
    Exit;

  Owner := FindMeshOwnerRecursive(FContext.SceneManager.Root, AMesh);
  if Owner = nil then
    Exit;

  Owner.UpdateBoundingRadiusFromMesh;
  Owner.NotifyChange;
end;

procedure TdwsEngineUnit.SetMeshMaterialName(AMesh: TMesh;
  const AMaterialName: string);
begin
  if AMesh = nil then
    Exit;

  AMesh.MaterialLibrary := FContext.MaterialLibrary;
  AMesh.LibMaterialname := AMaterialName;
end;

function TdwsEngineUnit.FindObjectRecursive(AObject: TSceneObject; const AName: string): TSceneObject;
var
  I: Integer;
begin
  Result := nil;
  if AObject = nil then
    Exit;

  if SameText(AObject.Name, AName) then
    Exit(AObject);

  for I := 0 to AObject.Count - 1 do
  begin
    Result := FindObjectRecursive(AObject.ObjectList[I], AName);
    if Result <> nil then
      Exit;
  end;
end;

function TdwsEngineUnit.GetMaterialShaderParameter(AMaterial: TMaterial;
  const AName: string): Single;
begin
  if AMaterial = nil then
    raise Exception.Create('Material is nil.');

  if SameText(AName, 'Gamma') then
    Exit(AMaterial.ShaderParameters.Gamma);
  if SameText(AName, 'Layers') then
    Exit(AMaterial.ShaderParameters.Layers);
  if SameText(AName, 'Pivot') then
    Exit(AMaterial.ShaderParameters.Pivot);
  if SameText(AName, 'MetallicMult') or SameText(AName, 'MetalnessMult') then
    Exit(AMaterial.ShaderParameters.MetallicMult);
  if SameText(AName, 'SpecularLevel') or SameText(AName, 'Specular') then
    Exit(AMaterial.ShaderParameters.SpecularLevel);
  if SameText(AName, 'HeightScale') then
    Exit(AMaterial.ShaderParameters.HeightScale);
  if SameText(AName, 'AmbientShadowStrength') then
    Exit(AMaterial.ShaderParameters.AmbientShadowStrength);
  if SameText(AName, 'HdrExposure') or SameText(AName, 'HDRExposure') or
     SameText(AName, 'Exposure') then
    Exit(AMaterial.ShaderParameters.HdrExposure);
  if SameText(AName, 'AlphaCutoff') then
    Exit(AMaterial.ShaderParameters.AlphaCutoff);

  raise Exception.CreateFmt('Unknown material shader parameter: %s', [AName]);
end;

procedure TdwsEngineUnit.SetMaterialShaderParameter(AMaterial: TMaterial;
  const AName: string; const AValue: Single);
var
  Params: TMaterialShaderParameters;
begin
  if AMaterial = nil then
    raise Exception.Create('Material is nil.');

  Params := AMaterial.ShaderParameters;

  if SameText(AName, 'Gamma') then
    Params.Gamma := AValue
  else if SameText(AName, 'Layers') then
    Params.Layers := Max(0, Round(AValue))
  else if SameText(AName, 'Pivot') then
    Params.Pivot := AValue
  else if SameText(AName, 'MetallicMult') or SameText(AName, 'MetalnessMult') then
    Params.MetallicMult := AValue
  else if SameText(AName, 'SpecularLevel') or SameText(AName, 'Specular') then
    Params.SpecularLevel := AValue
  else if SameText(AName, 'HeightScale') then
    Params.HeightScale := AValue
  else if SameText(AName, 'AmbientShadowStrength') then
    Params.AmbientShadowStrength := AValue
  else if SameText(AName, 'HdrExposure') or SameText(AName, 'HDRExposure') or
          SameText(AName, 'Exposure') then
    Params.HdrExposure := Max(0.0, AValue)
  else if SameText(AName, 'AlphaCutoff') then
    Params.AlphaCutoff := EnsureRange(AValue, 0.0, 1.0)
  else
    raise Exception.CreateFmt('Unknown material shader parameter: %s', [AName]);

  AMaterial.ShaderParameters := Params;
end;

function TdwsEngineUnit.RequireRenderer: TRenderer;
begin
  if (FContext = nil) or (FContext.Renderer = nil) then
    raise Exception.Create('Engine scripting context is not bound to a renderer');

  Result := FContext.Renderer;
end;

function TdwsEngineUnit.RenderWindowHandle: HWND;
var
  Renderer: TRenderer;
begin
  Renderer := RequireRenderer;
  Result := 0;
  if Renderer.RenderContext <> nil then
    Result := Renderer.RenderContext.WindowHandle;

  if Result = 0 then
    raise Exception.Create('The render window handle is not available.');
end;

function TdwsEngineUnit.TryGetRenderWindowRect(out ARect: TRect): Boolean;
begin
  Result := GetWindowRect(RenderWindowHandle, ARect);
  if not Result then
    FillChar(ARect, SizeOf(ARect), 0);
end;

function TdwsEngineUnit.TryGetRenderWindowClientRect(out ARect: TRect): Boolean;
begin
  Result := GetClientRect(RenderWindowHandle, ARect);
  if not Result then
    FillChar(ARect, SizeOf(ARect), 0);
end;

function TdwsEngineUnit.TryGetMonitorRect(AHandle: HWND;
  out ARect: TRect): Boolean;
var
  MonitorHandle: HMONITOR;
  MonitorInfo: TMonitorInfo;
begin
  FillChar(ARect, SizeOf(ARect), 0);
  MonitorHandle := MonitorFromWindow(AHandle, MONITOR_DEFAULTTONEAREST);
  Result := MonitorHandle <> 0;
  if not Result then
    Exit;

  FillChar(MonitorInfo, SizeOf(MonitorInfo), 0);
  MonitorInfo.cbSize := SizeOf(MonitorInfo);
  Result := GetMonitorInfo(MonitorHandle, @MonitorInfo);
  if Result then
    ARect := MonitorInfo.rcMonitor;
end;

procedure TdwsEngineUnit.ResizeRendererFromRenderWindow;
var
  ClientRect: TRect;
begin
  if TryGetRenderWindowClientRect(ClientRect) then
    RequireRenderer.Resize(Max(1, ClientRect.Right - ClientRect.Left),
      Max(1, ClientRect.Bottom - ClientRect.Top));
end;

procedure TdwsEngineUnit.SetRenderWindowClientSize(AWidth, AHeight: Integer);
var
  WindowHandleValue: HWND;
  WindowRect: TRect;
  ClientRect: TRect;
  ExtraWidth: Integer;
  ExtraHeight: Integer;
begin
  WindowHandleValue := RenderWindowHandle;
  if RenderWindowIsFullscreen then
    SetRenderWindowFullscreen(False);

  if not GetWindowRect(WindowHandleValue, WindowRect) then
    Exit;
  if not GetClientRect(WindowHandleValue, ClientRect) then
    Exit;

  ExtraWidth := (WindowRect.Right - WindowRect.Left) -
    (ClientRect.Right - ClientRect.Left);
  ExtraHeight := (WindowRect.Bottom - WindowRect.Top) -
    (ClientRect.Bottom - ClientRect.Top);

  SetWindowPos(WindowHandleValue, 0, 0, 0, Max(1, AWidth) + ExtraWidth,
    Max(1, AHeight) + ExtraHeight, SWP_NOMOVE or SWP_NOZORDER or
    SWP_NOOWNERZORDER);
  RequireRenderer.Resize(Max(1, AWidth), Max(1, AHeight));
end;

function TdwsEngineUnit.RenderWindowIsFullscreen: Boolean;
var
  WindowHandleValue: HWND;
  WindowRect: TRect;
  MonitorRect: TRect;
  Style: NativeInt;
begin
  WindowHandleValue := RenderWindowHandle;
  if FRenderWindowFullscreen and
     (FRenderWindowFullscreenHandle = WindowHandleValue) then
    Exit(True);

  Result := False;
  if not TryGetRenderWindowRect(WindowRect) then
    Exit;
  if not TryGetMonitorRect(WindowHandleValue, MonitorRect) then
    Exit;

  Style := GetWindowLongPtr(WindowHandleValue, GWL_STYLE);
  Result := ((Style and WS_OVERLAPPEDWINDOW) = 0) and
    (WindowRect.Left <= MonitorRect.Left) and
    (WindowRect.Top <= MonitorRect.Top) and
    (WindowRect.Right >= MonitorRect.Right) and
    (WindowRect.Bottom >= MonitorRect.Bottom);
end;

procedure TdwsEngineUnit.SetRenderWindowFullscreen(AEnabled: Boolean);
var
  WindowHandleValue: HWND;
  MonitorRect: TRect;
  Style: NativeInt;
  ExStyle: NativeInt;
begin
  WindowHandleValue := RenderWindowHandle;

  if AEnabled then
  begin
    if FRenderWindowFullscreen and
       (FRenderWindowFullscreenHandle = WindowHandleValue) then
      Exit;

    FRenderWindowStoredStyle := GetWindowLongPtr(WindowHandleValue, GWL_STYLE);
    FRenderWindowStoredExStyle := GetWindowLongPtr(WindowHandleValue,
      GWL_EXSTYLE);
    FillChar(FRenderWindowStoredPlacement, SizeOf(FRenderWindowStoredPlacement),
      0);
    FRenderWindowStoredPlacement.length :=
      SizeOf(FRenderWindowStoredPlacement);
    GetWindowPlacement(WindowHandleValue, @FRenderWindowStoredPlacement);

    if not TryGetMonitorRect(WindowHandleValue, MonitorRect) then
      Exit;

    Style := (FRenderWindowStoredStyle and not WS_OVERLAPPEDWINDOW) or WS_POPUP;
    ExStyle := FRenderWindowStoredExStyle and not WS_EX_CLIENTEDGE and
      not WS_EX_WINDOWEDGE;
    SetWindowLongPtr(WindowHandleValue, GWL_STYLE, Style);
    SetWindowLongPtr(WindowHandleValue, GWL_EXSTYLE, ExStyle);
    SetWindowPos(WindowHandleValue, HWND_TOP, MonitorRect.Left,
      MonitorRect.Top, MonitorRect.Right - MonitorRect.Left,
      MonitorRect.Bottom - MonitorRect.Top, SWP_NOOWNERZORDER or
      SWP_FRAMECHANGED);
    RequireRenderer.Resize(MonitorRect.Right - MonitorRect.Left,
      MonitorRect.Bottom - MonitorRect.Top);

    FRenderWindowFullscreen := True;
    FRenderWindowFullscreenHandle := WindowHandleValue;
    Exit;
  end;

  if not FRenderWindowFullscreen or
     (FRenderWindowFullscreenHandle <> WindowHandleValue) then
    Exit;

  SetWindowLongPtr(WindowHandleValue, GWL_STYLE, FRenderWindowStoredStyle);
  SetWindowLongPtr(WindowHandleValue, GWL_EXSTYLE, FRenderWindowStoredExStyle);
  SetWindowPlacement(WindowHandleValue, @FRenderWindowStoredPlacement);
  SetWindowPos(WindowHandleValue, 0, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or
    SWP_NOZORDER or SWP_NOOWNERZORDER or SWP_FRAMECHANGED);
  FRenderWindowFullscreen := False;
  FRenderWindowFullscreenHandle := 0;
  ResizeRendererFromRenderWindow;
end;

procedure TdwsEngineUnit.DoScriptEventName(Info: TProgramInfo);
begin
  Info.ResultAsString := FContext.CurrentEventName;
end;

procedure TdwsEngineUnit.DoScriptTargetKind(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(FContext.CurrentTargetKind);
end;

procedure TdwsEngineUnit.DoScriptTargetName(Info: TProgramInfo);
begin
  Info.ResultAsString := FContext.CurrentTargetName;
end;

procedure TdwsEngineUnit.DoScriptTargetHandle(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.CurrentTargetHandle;
end;

procedure TdwsEngineUnit.DoScriptTargetObject(Info: TProgramInfo);
begin
  if FContext.CurrentTarget is TSceneObject then
    SetResultSceneObject(Info, TSceneObject(FContext.CurrentTarget))
  else
    SetResultSceneObject(Info, nil);
end;

procedure TdwsEngineUnit.DoScriptTargetMaterial(Info: TProgramInfo);
begin
  if FContext.CurrentTarget is TMaterial then
    SetResultMaterial(Info, TMaterial(FContext.CurrentTarget))
  else
    SetResultMaterial(Info, nil);
end;

procedure TdwsEngineUnit.DoScriptTargetShader(Info: TProgramInfo);
begin
  if FContext.CurrentTarget is TShader then
    SetResultShader(Info, TShader(FContext.CurrentTarget))
  else
    SetResultShader(Info, nil);
end;

procedure TdwsEngineUnit.DoDeltaTime(Info: TProgramInfo);
begin
  Info.ResultAsFloat := FContext.DeltaTime;
end;

procedure TdwsEngineUnit.DoTimeSeconds(Info: TProgramInfo);
begin
  Info.ResultAsFloat := FContext.TimeSeconds;
end;

procedure TdwsEngineUnit.DoLog(Info: TProgramInfo);
begin
  if Assigned(FContext.LogCallback) then
    FContext.LogCallback(Info.ParamAsString[0]);
end;

procedure TdwsEngineUnit.DoKeyCode(Info: TProgramInfo);
begin
  Info.ResultAsInteger := TKeyboard.KeyCode(Info.ParamAsString[0]);
end;

procedure TdwsEngineUnit.DoKeyPressedCode(Info: TProgramInfo);
begin
  Info.ResultAsBoolean := TKeyboard.IsKeyPressed(Info.ParamAsInteger[0]);
end;

procedure TdwsEngineUnit.DoKeyPressedName(Info: TProgramInfo);
begin
  Info.ResultAsBoolean := TKeyboard.IsKeyPressed(Info.ParamAsString[0]);
end;

procedure TdwsEngineUnit.DoMouseButtonCode(Info: TProgramInfo);
begin
  Info.ResultAsInteger := TMouse.ButtonCode(Info.ParamAsString[0]);
end;

procedure TdwsEngineUnit.DoMouseButtonPressedCode(Info: TProgramInfo);
begin
  Info.ResultAsBoolean := TMouse.IsButtonPressed(Info.ParamAsInteger[0]);
end;

procedure TdwsEngineUnit.DoMouseButtonPressedName(Info: TProgramInfo);
begin
  Info.ResultAsBoolean := TMouse.IsButtonPressed(Info.ParamAsString[0]);
end;

procedure TdwsEngineUnit.DoMousePosition(Info: TProgramInfo);
begin
  SetResultVector2(Info, TMouse.Position(FContext.Renderer));
end;

procedure TdwsEngineUnit.DoMouseX(Info: TProgramInfo);
begin
  Info.ResultAsFloat := TMouse.Position(FContext.Renderer).X;
end;

procedure TdwsEngineUnit.DoMouseY(Info: TProgramInfo);
begin
  Info.ResultAsFloat := TMouse.Position(FContext.Renderer).Y;
end;

procedure TdwsEngineUnit.DoMouseInsideViewport(Info: TProgramInfo);
begin
  Info.ResultAsBoolean := TMouse.IsInsideViewport(FContext.Renderer);
end;

procedure TdwsEngineUnit.DoMouseRayOrigin(Info: TProgramInfo);
var
  Origin, Direction: TVector3;
begin
  if TMouse.TryCurrentWorldRay(FContext.Renderer, Origin, Direction) then
    SetResultVector3(Info, Origin)
  else
    SetResultVector3(Info, Vector3(0.0, 0.0, 0.0));
end;

procedure TdwsEngineUnit.DoMouseRayDirection(Info: TProgramInfo);
var
  Origin, Direction: TVector3;
begin
  if TMouse.TryCurrentWorldRay(FContext.Renderer, Origin, Direction) then
    SetResultVector3(Info, Direction)
  else
    SetResultVector3(Info, Vector3(0.0, 0.0, -1.0));
end;

procedure TdwsEngineUnit.DoScreenRayOrigin(Info: TProgramInfo);
var
  Origin, Direction: TVector3;
begin
  if TMouse.TryScreenToWorldRay(FContext.Renderer, Info.ParamAsFloat[0],
    Info.ParamAsFloat[1], Origin, Direction) then
    SetResultVector3(Info, Origin)
  else
    SetResultVector3(Info, Vector3(0.0, 0.0, 0.0));
end;

procedure TdwsEngineUnit.DoScreenRayDirection(Info: TProgramInfo);
var
  Origin, Direction: TVector3;
begin
  if TMouse.TryScreenToWorldRay(FContext.Renderer, Info.ParamAsFloat[0],
    Info.ParamAsFloat[1], Origin, Direction) then
    SetResultVector3(Info, Direction)
  else
    SetResultVector3(Info, Vector3(0.0, 0.0, -1.0));
end;

procedure TdwsEngineUnit.DoMousePlaneHit(Info: TProgramInfo);
var
  HitPoint: TVector3;
  Distance: Single;
begin
  Info.ResultAsBoolean := TMouse.TryCurrentPlaneHit(FContext.Renderer,
    ParamAsVector3(Info, 0), ParamAsVector3(Info, 1), HitPoint, Distance);
end;

procedure TdwsEngineUnit.DoMousePlanePoint(Info: TProgramInfo);
var
  HitPoint: TVector3;
  Distance: Single;
begin
  if TMouse.TryCurrentPlaneHit(FContext.Renderer, ParamAsVector3(Info, 0),
    ParamAsVector3(Info, 1), HitPoint, Distance) then
    SetResultVector3(Info, HitPoint)
  else
    SetResultVector3(Info, Vector3(0.0, 0.0, 0.0));
end;

procedure TdwsEngineUnit.DoScreenPlaneHit(Info: TProgramInfo);
var
  HitPoint: TVector3;
  Distance: Single;
begin
  Info.ResultAsBoolean := TMouse.TryScreenPlaneHit(FContext.Renderer,
    Info.ParamAsFloat[0], Info.ParamAsFloat[1], ParamAsVector3(Info, 2),
    ParamAsVector3(Info, 3), HitPoint, Distance);
end;

procedure TdwsEngineUnit.DoScreenPlanePoint(Info: TProgramInfo);
var
  HitPoint: TVector3;
  Distance: Single;
begin
  if TMouse.TryScreenPlaneHit(FContext.Renderer, Info.ParamAsFloat[0],
    Info.ParamAsFloat[1], ParamAsVector3(Info, 2), ParamAsVector3(Info, 3),
    HitPoint, Distance) then
    SetResultVector3(Info, HitPoint)
  else
    SetResultVector3(Info, Vector3(0.0, 0.0, 0.0));
end;

procedure TdwsEngineUnit.DoHeightFieldLocalHeight(Info: TProgramInfo);
begin
  Info.ResultAsFloat := TMouse.HeightFieldLocalHeight(
    RequireHeightFieldMesh(Info.ParamAsInteger[0]), Info.ParamAsFloat[1],
    Info.ParamAsFloat[2]);
end;

procedure TdwsEngineUnit.DoHeightFieldWorldPoint(Info: TProgramInfo);
begin
  SetResultVector3(Info, TMouse.HeightFieldWorldPoint(
    RequireHeightFieldMesh(Info.ParamAsInteger[0]), ParamAsVector3(Info, 1)));
end;

procedure TdwsEngineUnit.DoHeightFieldWorldHeight(Info: TProgramInfo);
var
  WorldPoint: TVector3;
begin
  WorldPoint := TMouse.HeightFieldWorldPoint(
    RequireHeightFieldMesh(Info.ParamAsInteger[0]), ParamAsVector3(Info, 1));
  Info.ResultAsFloat := WorldPoint.Y;
end;

procedure TdwsEngineUnit.DoMouseHeightFieldHit(Info: TProgramInfo);
var
  WorldPoint, LocalPoint: TVector3;
  Distance: Single;
begin
  Info.ResultAsBoolean := TMouse.TryCurrentHeightFieldHit(FContext.Renderer,
    RequireHeightFieldMesh(Info.ParamAsInteger[0]), WorldPoint, LocalPoint,
    Distance);
end;

procedure TdwsEngineUnit.DoMouseHeightFieldPoint(Info: TProgramInfo);
var
  WorldPoint, LocalPoint: TVector3;
  Distance: Single;
begin
  if TMouse.TryCurrentHeightFieldHit(FContext.Renderer,
    RequireHeightFieldMesh(Info.ParamAsInteger[0]), WorldPoint, LocalPoint,
    Distance) then
    SetResultVector3(Info, WorldPoint)
  else
    SetResultVector3(Info, Vector3(0.0, 0.0, 0.0));
end;

procedure TdwsEngineUnit.DoMouseHeightFieldLocalPoint(Info: TProgramInfo);
var
  WorldPoint, LocalPoint: TVector3;
  Distance: Single;
begin
  if TMouse.TryCurrentHeightFieldHit(FContext.Renderer,
    RequireHeightFieldMesh(Info.ParamAsInteger[0]), WorldPoint, LocalPoint,
    Distance) then
    SetResultVector3(Info, LocalPoint)
  else
    SetResultVector3(Info, Vector3(0.0, 0.0, 0.0));
end;

procedure TdwsEngineUnit.DoScreenHeightFieldHit(Info: TProgramInfo);
var
  WorldPoint, LocalPoint: TVector3;
  Distance: Single;
begin
  Info.ResultAsBoolean := TMouse.TryScreenHeightFieldHit(FContext.Renderer,
    RequireHeightFieldMesh(Info.ParamAsInteger[2]), Info.ParamAsFloat[0],
    Info.ParamAsFloat[1], WorldPoint, LocalPoint, Distance);
end;

procedure TdwsEngineUnit.DoScreenHeightFieldPoint(Info: TProgramInfo);
var
  WorldPoint, LocalPoint: TVector3;
  Distance: Single;
begin
  if TMouse.TryScreenHeightFieldHit(FContext.Renderer,
    RequireHeightFieldMesh(Info.ParamAsInteger[2]), Info.ParamAsFloat[0],
    Info.ParamAsFloat[1], WorldPoint, LocalPoint, Distance) then
    SetResultVector3(Info, WorldPoint)
  else
    SetResultVector3(Info, Vector3(0.0, 0.0, 0.0));
end;

procedure TdwsEngineUnit.DoScreenHeightFieldLocalPoint(Info: TProgramInfo);
var
  WorldPoint, LocalPoint: TVector3;
  Distance: Single;
begin
  if TMouse.TryScreenHeightFieldHit(FContext.Renderer,
    RequireHeightFieldMesh(Info.ParamAsInteger[2]), Info.ParamAsFloat[0],
    Info.ParamAsFloat[1], WorldPoint, LocalPoint, Distance) then
    SetResultVector3(Info, LocalPoint)
  else
    SetResultVector3(Info, Vector3(0.0, 0.0, 0.0));
end;

procedure TdwsEngineUnit.DoViewportLeft(Info: TProgramInfo);
begin
  Info.ResultAsInteger := RequireRenderer.X;
end;

procedure TdwsEngineUnit.DoViewportTop(Info: TProgramInfo);
begin
  Info.ResultAsInteger := RequireRenderer.Y;
end;

procedure TdwsEngineUnit.DoViewportWidth(Info: TProgramInfo);
begin
  Info.ResultAsInteger := RequireRenderer.Width;
end;

procedure TdwsEngineUnit.DoViewportHeight(Info: TProgramInfo);
begin
  Info.ResultAsInteger := RequireRenderer.Height;
end;

procedure TdwsEngineUnit.DoViewportPosition(Info: TProgramInfo);
var
  Renderer: TRenderer;
begin
  Renderer := RequireRenderer;
  SetResultVector2(Info, Vector2(Renderer.X, Renderer.Y));
end;

procedure TdwsEngineUnit.DoViewportSize(Info: TProgramInfo);
var
  Renderer: TRenderer;
begin
  Renderer := RequireRenderer;
  SetResultVector2(Info, Vector2(Renderer.Width, Renderer.Height));
end;

procedure TdwsEngineUnit.DoViewportRect(Info: TProgramInfo);
var
  Renderer: TRenderer;
begin
  Renderer := RequireRenderer;
  SetResultVector4(Info, Vector4(Renderer.X, Renderer.Y, Renderer.Width,
    Renderer.Height));
end;

procedure TdwsEngineUnit.DoViewportAspectRatio(Info: TProgramInfo);
var
  Renderer: TRenderer;
begin
  Renderer := RequireRenderer;
  Info.ResultAsFloat := Max(1.0, Renderer.Width) / Max(1.0, Renderer.Height);
end;

procedure TdwsEngineUnit.DoViewportSetPosition(Info: TProgramInfo);
var
  Renderer: TRenderer;
begin
  Renderer := RequireRenderer;
  Renderer.X := Info.ParamAsInteger[0];
  Renderer.Y := Info.ParamAsInteger[1];
end;

procedure TdwsEngineUnit.DoViewportSetSize(Info: TProgramInfo);
begin
  RequireRenderer.Resize(Info.ParamAsInteger[0], Info.ParamAsInteger[1]);
end;

procedure TdwsEngineUnit.DoViewportSetRect(Info: TProgramInfo);
var
  Renderer: TRenderer;
begin
  Renderer := RequireRenderer;
  Renderer.X := Info.ParamAsInteger[0];
  Renderer.Y := Info.ParamAsInteger[1];
  Renderer.Resize(Info.ParamAsInteger[2], Info.ParamAsInteger[3]);
end;

procedure TdwsEngineUnit.DoRenderWindowLeft(Info: TProgramInfo);
var
  WindowRect: TRect;
begin
  if TryGetRenderWindowRect(WindowRect) then
    Info.ResultAsInteger := WindowRect.Left
  else
    Info.ResultAsInteger := 0;
end;

procedure TdwsEngineUnit.DoRenderWindowTop(Info: TProgramInfo);
var
  WindowRect: TRect;
begin
  if TryGetRenderWindowRect(WindowRect) then
    Info.ResultAsInteger := WindowRect.Top
  else
    Info.ResultAsInteger := 0;
end;

procedure TdwsEngineUnit.DoRenderWindowWidth(Info: TProgramInfo);
var
  ClientRect: TRect;
begin
  if TryGetRenderWindowClientRect(ClientRect) then
    Info.ResultAsInteger := ClientRect.Right - ClientRect.Left
  else
    Info.ResultAsInteger := RequireRenderer.Width;
end;

procedure TdwsEngineUnit.DoRenderWindowHeight(Info: TProgramInfo);
var
  ClientRect: TRect;
begin
  if TryGetRenderWindowClientRect(ClientRect) then
    Info.ResultAsInteger := ClientRect.Bottom - ClientRect.Top
  else
    Info.ResultAsInteger := RequireRenderer.Height;
end;

procedure TdwsEngineUnit.DoRenderWindowPosition(Info: TProgramInfo);
var
  WindowRect: TRect;
begin
  if TryGetRenderWindowRect(WindowRect) then
    SetResultVector2(Info, Vector2(WindowRect.Left, WindowRect.Top))
  else
    SetResultVector2(Info, Vector2(0.0, 0.0));
end;

procedure TdwsEngineUnit.DoRenderWindowSize(Info: TProgramInfo);
var
  ClientRect: TRect;
begin
  if TryGetRenderWindowClientRect(ClientRect) then
    SetResultVector2(Info, Vector2(ClientRect.Right - ClientRect.Left,
      ClientRect.Bottom - ClientRect.Top))
  else
    SetResultVector2(Info, Vector2(RequireRenderer.Width,
      RequireRenderer.Height));
end;

procedure TdwsEngineUnit.DoRenderWindowRect(Info: TProgramInfo);
var
  WindowRect: TRect;
  ClientRect: TRect;
begin
  if TryGetRenderWindowRect(WindowRect) and
     TryGetRenderWindowClientRect(ClientRect) then
    SetResultVector4(Info, Vector4(WindowRect.Left, WindowRect.Top,
      ClientRect.Right - ClientRect.Left, ClientRect.Bottom - ClientRect.Top))
  else
    SetResultVector4(Info, Vector4(0.0, 0.0, RequireRenderer.Width,
      RequireRenderer.Height));
end;

procedure TdwsEngineUnit.DoRenderWindowAspectRatio(Info: TProgramInfo);
var
  ClientRect: TRect;
  W, H: Single;
begin
  if TryGetRenderWindowClientRect(ClientRect) then
  begin
    W := ClientRect.Right - ClientRect.Left;
    H := ClientRect.Bottom - ClientRect.Top;
  end
  else
  begin
    W := RequireRenderer.Width;
    H := RequireRenderer.Height;
  end;
  Info.ResultAsFloat := Max(1.0, W) / Max(1.0, H);
end;

procedure TdwsEngineUnit.DoRenderWindowSetPosition(Info: TProgramInfo);
var
  WindowHandleValue: HWND;
begin
  WindowHandleValue := RenderWindowHandle;
  if RenderWindowIsFullscreen then
    SetRenderWindowFullscreen(False);

  SetWindowPos(WindowHandleValue, 0, Info.ParamAsInteger[0],
    Info.ParamAsInteger[1], 0, 0, SWP_NOSIZE or SWP_NOZORDER or
    SWP_NOOWNERZORDER);
end;

procedure TdwsEngineUnit.DoRenderWindowSetSize(Info: TProgramInfo);
begin
  SetRenderWindowClientSize(Info.ParamAsInteger[0], Info.ParamAsInteger[1]);
end;

procedure TdwsEngineUnit.DoRenderWindowSetRect(Info: TProgramInfo);
var
  WindowHandleValue: HWND;
begin
  WindowHandleValue := RenderWindowHandle;
  if RenderWindowIsFullscreen then
    SetRenderWindowFullscreen(False);

  SetRenderWindowClientSize(Info.ParamAsInteger[2], Info.ParamAsInteger[3]);
  SetWindowPos(WindowHandleValue, 0, Info.ParamAsInteger[0],
    Info.ParamAsInteger[1], 0, 0, SWP_NOSIZE or SWP_NOZORDER or
    SWP_NOOWNERZORDER);
end;

procedure TdwsEngineUnit.DoRenderWindowFullScreen(Info: TProgramInfo);
begin
  Info.ResultAsBoolean := RenderWindowIsFullscreen;
end;

procedure TdwsEngineUnit.DoRenderWindowSetFullScreen(Info: TProgramInfo);
begin
  SetRenderWindowFullscreen(Info.ParamAsBoolean[0]);
end;

procedure TdwsEngineUnit.DoRenderWindowToggleFullScreen(Info: TProgramInfo);
begin
  SetRenderWindowFullscreen(not RenderWindowIsFullscreen);
  Info.ResultAsBoolean := RenderWindowIsFullscreen;
end;

procedure TdwsEngineUnit.DoSceneRoot(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.HandleOf(RootObject);
end;

procedure TdwsEngineUnit.DoSceneRootObject(Info: TProgramInfo);
begin
  SetResultSceneObject(Info, RootObject);
end;

procedure TdwsEngineUnit.DoSceneFind(Info: TProgramInfo);
var
  Obj: TSceneObject;
begin
  RequireContext;
  Obj := FindObjectRecursive(RootObject, Info.ParamAsString[0]);
  Info.ResultAsInteger := FContext.HandleOf(Obj);
end;

procedure TdwsEngineUnit.DoSceneFindObject(Info: TProgramInfo);
begin
  RequireContext;
  SetResultSceneObject(Info, FindObjectRecursive(RootObject, Info.ParamAsString[0]));
end;

procedure TdwsEngineUnit.DoSceneUpdate(Info: TProgramInfo);
begin
  RequireContext;
  FContext.SceneManager.Update;
end;

procedure TdwsEngineUnit.DoSceneRender(Info: TProgramInfo);
begin
  RequireContext;
  if Assigned(FContext.Renderer) then
    FContext.Renderer.Render;
end;

procedure TdwsEngineUnit.DoPrefabLoad(Info: TProgramInfo);
var
  Parent, Obj: TSceneObject;
begin
  RequireContext;
  if not Assigned(FContext.PrefabLoader) then
    raise Exception.Create('Prefab loader is not bound to the script engine.');

  Parent := ParentOrRootFromHandle(Info.ParamAsInteger[1]);
  Obj := FContext.PrefabLoader(Info.ParamAsString[0], Parent);
  Info.ResultAsInteger := FContext.HandleOf(Obj);
end;

procedure TdwsEngineUnit.DoPrefabDestroy(Info: TProgramInfo);
var
  Obj: TSceneObject;
begin
  RequireContext;
  Obj := FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]);
  if Obj = RootObject then
    raise Exception.Create('Cannot destroy the scene root');

  if Assigned(FContext.PrefabDestroyer) then
  begin
    FContext.ForgeTSceneObjectTree(Obj);
    FContext.PrefabDestroyer(Obj)
  end
  else
    DestroySceneObjectForScript(Obj);
end;

procedure TdwsEngineUnit.DoObjectFromHandle(Info: TProgramInfo);
begin
  SetResultSceneObject(Info, FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]));
end;

procedure TdwsEngineUnit.DoObjectHandle(Info: TProgramInfo);
var
  Obj: TSceneObject;
begin
  Obj := ParamAsSceneObject(Info, 0);
  Info.ResultAsInteger := FContext.HandleOf(Obj);
end;

procedure TdwsEngineUnit.DoObjectCreate(Info: TProgramInfo);
var
  Parent, Obj: TSceneObject;
begin
  Parent := ParentOrRootFromHandle(Info.ParamAsInteger[0]);
  Obj := TSceneObject.Create(Parent);
  Obj.Name := Info.ParamAsString[1];
  Obj.Position := DefaultObjectSpawnPosition(Parent);
  Info.ResultAsInteger := FContext.HandleOf(Obj);
end;

procedure TdwsEngineUnit.DoObjectDelete(Info: TProgramInfo);
var
  Obj: TSceneObject;
begin
  RequireContext;
  Obj := FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]);
  if Obj = RootObject then
    raise Exception.Create('Cannot delete the scene root');

  DestroySceneObjectForScript(Obj);
end;

procedure TdwsEngineUnit.DoObjectChildCount(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).Count;
end;

procedure TdwsEngineUnit.DoObjectChild(Info: TProgramInfo);
var
  Obj: TSceneObject;
begin
  Obj := FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).ObjectList[Info.ParamAsInteger[1]];
  Info.ResultAsInteger := FContext.HandleOf(Obj);
end;

procedure TdwsEngineUnit.DoObjectParent(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.HandleOf(
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).Parent);
end;

procedure TdwsEngineUnit.DoObjectName(Info: TProgramInfo);
begin
  Info.ResultAsString := FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).Name;
end;

procedure TdwsEngineUnit.DoObjectSetName(Info: TProgramInfo);
begin
  FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).Name := Info.ParamAsString[1];
end;

procedure TdwsEngineUnit.DoObjectPosition(Info: TProgramInfo);
begin
  SetResultVector3(Info, FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).Position);
end;

procedure TdwsEngineUnit.DoObjectSetPosition(Info: TProgramInfo);
begin
  FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).Position := ParamAsVector3(Info, 1);
end;

procedure TdwsEngineUnit.DoObjectRotation(Info: TProgramInfo);
begin
  SetResultVector3(Info, FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).Rotation);
end;

procedure TdwsEngineUnit.DoObjectSetRotation(Info: TProgramInfo);
begin
  FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).Rotation := ParamAsVector3(Info, 1);
end;

procedure TdwsEngineUnit.DoObjectScale(Info: TProgramInfo);
begin
  SetResultVector3(Info, FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).Scale);
end;

procedure TdwsEngineUnit.DoObjectSetScale(Info: TProgramInfo);
begin
  FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).Scale := ParamAsVector3(Info, 1);
end;

procedure TdwsEngineUnit.DoObjectMatrix(Info: TProgramInfo);
begin
  SetResultMatrix4(Info, FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).ObjectMatrix);
end;

procedure TdwsEngineUnit.DoObjectModelMatrix(Info: TProgramInfo);
begin
  SetResultMatrix4(Info, FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).ObjectMatrix);
end;

procedure TdwsEngineUnit.DoObjectLocalMatrix(Info: TProgramInfo);
begin
  SetResultMatrix4(Info, FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).ObjectMatrix);
end;

procedure TdwsEngineUnit.DoObjectWorldMatrix(Info: TProgramInfo);
begin
  SetResultMatrix4(Info, WorldMatrixOf(FContext.SceneObjectFromHandle(Info.ParamAsInteger[0])));
end;

procedure TdwsEngineUnit.DoObjectWorldPosition(Info: TProgramInfo);
var
  Obj: TSceneObject;
begin
  Obj := FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]);
  SetResultVector3(Info, WorldPositionOf(Obj));
end;

procedure TdwsEngineUnit.DoObjectSetWireframe(Info: TProgramInfo);
begin
  FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).WireFrame := Info.ParamAsBoolean[1];
end;

procedure TdwsEngineUnit.DoObjectHasGeometry(Info: TProgramInfo);
begin
  Info.ResultAsBoolean := FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).HasGeometry;
end;

procedure TdwsEngineUnit.DoObjectHasCamera(Info: TProgramInfo);
begin
  Info.ResultAsBoolean := FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).HasCamera;
end;

procedure TdwsEngineUnit.DoObjectHasParticles(Info: TProgramInfo);
begin
  Info.ResultAsBoolean := FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).HasParticles;
end;

procedure TdwsEngineUnit.DoObjectHasBillboards(Info: TProgramInfo);
begin
  Info.ResultAsBoolean := FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).HasBillboard;
end;

procedure TdwsEngineUnit.DoObjectHasAudio(Info: TProgramInfo);
begin
  Info.ResultAsBoolean := FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).HasAudio;
end;

procedure TdwsEngineUnit.DoObjectMeshCount(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).MeshList.Count;
end;

procedure TdwsEngineUnit.DoObjectMesh(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.HandleOf(
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).MeshList.Item[Info.ParamAsInteger[1]]);
end;

procedure TdwsEngineUnit.DoObjectMeshObject(Info: TProgramInfo);
begin
  SetResultMesh(Info,
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).MeshList.Item[Info.ParamAsInteger[1]]);
end;

procedure TdwsEngineUnit.DoObjectAddMeshFile(Info: TProgramInfo);
begin
  Info.ResultAsInteger := AddMeshToObject(
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]),
    TMesh.LoadFromFile(Info.ParamAsString[1]));
end;

procedure TdwsEngineUnit.DoObjectAddMeshFileObject(Info: TProgramInfo);
var
  Mesh: TMesh;
begin
  Mesh := TMesh.LoadFromFile(Info.ParamAsString[1]);
  AddMeshToObject(FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]), Mesh);
  SetResultMesh(Info, Mesh);
end;

procedure TdwsEngineUnit.DoObjectAddPlane(Info: TProgramInfo);
begin
  Info.ResultAsInteger := AddMeshToObject(
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]),
    TMeshFactory.CreatePlane(Info.ParamAsFloat[1], Info.ParamAsFloat[2],
      Info.ParamAsInteger[3], Info.ParamAsInteger[4], Info.ParamAsString[5]));
end;

procedure TdwsEngineUnit.DoObjectAddCube(Info: TProgramInfo);
begin
  Info.ResultAsInteger := AddMeshToObject(
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]),
    TMeshFactory.CreateCube(Info.ParamAsFloat[1], Info.ParamAsFloat[2], Info.ParamAsFloat[3],
      Info.ParamAsInteger[4], Info.ParamAsInteger[5], Info.ParamAsInteger[6], Info.ParamAsString[7]));
end;

procedure TdwsEngineUnit.DoObjectAddSphere(Info: TProgramInfo);
begin
  Info.ResultAsInteger := AddMeshToObject(
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]),
    TMeshFactory.CreateSphere(Info.ParamAsFloat[1], Info.ParamAsInteger[2],
      Info.ParamAsInteger[3], Info.ParamAsString[4]));
end;

procedure TdwsEngineUnit.DoObjectAddCylinder(Info: TProgramInfo);
begin
  Info.ResultAsInteger := AddMeshToObject(
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]),
    TMeshFactory.CreateCylinder(Info.ParamAsFloat[1], Info.ParamAsFloat[2],
      Info.ParamAsInteger[3], Info.ParamAsInteger[4], Info.ParamAsString[5]));
end;

procedure TdwsEngineUnit.DoObjectAddCapsule(Info: TProgramInfo);
begin
  Info.ResultAsInteger := AddMeshToObject(
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]),
    TMeshFactory.CreateCapsule(Info.ParamAsFloat[1], Info.ParamAsFloat[2],
      Info.ParamAsInteger[3], Info.ParamAsInteger[4], Info.ParamAsString[5]));
end;

procedure TdwsEngineUnit.DoObjectAddTorus(Info: TProgramInfo);
begin
  Info.ResultAsInteger := AddMeshToObject(
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]),
    TMeshFactory.CreateTorus(Info.ParamAsFloat[1], Info.ParamAsFloat[2],
      Info.ParamAsInteger[3], Info.ParamAsInteger[4], Info.ParamAsString[5]));
end;

procedure TdwsEngineUnit.DoObjectAddCone(Info: TProgramInfo);
begin
  Info.ResultAsInteger := AddMeshToObject(
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]),
    TMeshFactory.CreateCone(Info.ParamAsFloat[1], Info.ParamAsFloat[2],
      Info.ParamAsInteger[3], Info.ParamAsInteger[4], Info.ParamAsString[5]));
end;

procedure TdwsEngineUnit.DoObjectAddPrism(Info: TProgramInfo);
begin
  Info.ResultAsInteger := AddMeshToObject(
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]),
    TMeshFactory.CreatePrism(Info.ParamAsFloat[1], Info.ParamAsFloat[2],
      Info.ParamAsInteger[3], Info.ParamAsInteger[4], Info.ParamAsString[5]));
end;

procedure TdwsEngineUnit.DoObjectAddFrustum(Info: TProgramInfo);
begin
  Info.ResultAsInteger := AddMeshToObject(
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]),
    TMeshFactory.CreateFrustum(Info.ParamAsFloat[1], Info.ParamAsFloat[2], Info.ParamAsFloat[3],
      Info.ParamAsInteger[4], Info.ParamAsInteger[5], TCapType(Info.ParamAsInteger[6]),
      TCapType(Info.ParamAsInteger[7]), Info.ParamAsString[8]));
end;

procedure TdwsEngineUnit.DoObjectAddIcosphere(Info: TProgramInfo);
begin
  Info.ResultAsInteger := AddMeshToObject(
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]),
    TMeshFactory.CreateIcosphere(Info.ParamAsFloat[1], Info.ParamAsInteger[2], Info.ParamAsString[3]));
end;

procedure TdwsEngineUnit.DoObjectAddGeodesicDome(Info: TProgramInfo);
begin
  Info.ResultAsInteger := AddMeshToObject(
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]),
    TMeshFactory.CreateGeodesicDome(Info.ParamAsFloat[1], Info.ParamAsInteger[2], Info.ParamAsString[3]));
end;

procedure TdwsEngineUnit.DoObjectAddArrow(Info: TProgramInfo);
begin
  Info.ResultAsInteger := AddMeshToObject(
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]),
    TMeshFactory.CreateArrow(Info.ParamAsFloat[1], Info.ParamAsFloat[2],
      Info.ParamAsFloat[3], Info.ParamAsFloat[4], Info.ParamAsInteger[5],
      Info.ParamAsInteger[6], Info.ParamAsString[7]));
end;

procedure TdwsEngineUnit.DoObjectAddSuperEllipsoid(Info: TProgramInfo);
begin
  Info.ResultAsInteger := AddMeshToObject(
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]),
    TMeshFactory.CreateSuperellipsoid(Info.ParamAsFloat[1], Info.ParamAsFloat[2],
      Info.ParamAsFloat[3], Info.ParamAsInteger[4], Info.ParamAsInteger[5],
      Info.ParamAsString[6]));
end;

procedure TdwsEngineUnit.DoObjectSetMaterial(Info: TProgramInfo);
var
  Obj: TSceneObject;
  I: Integer;
begin
  Obj := FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]);
  for I := 0 to Obj.MeshList.Count - 1 do
    if Assigned(Obj.MeshList.Item[I]) then
    begin
      Obj.MeshList.Item[I].MaterialLibrary := FContext.MaterialLibrary;
        Obj.MeshList.Item[I].LibMaterialname := Info.ParamAsString[1];
    end;
end;

procedure TdwsEngineUnit.DoSceneObjectCreate(Info: TProgramInfo; var ExtObject: TObject);
begin
  if ExtObject is TSceneObject then
    Exit;

  ExtObject := TSceneObject.Create(RootObject);
  TSceneObject(ExtObject).Position := DefaultObjectSpawnPosition(RootObject);
  FContext.HandleOf(ExtObject);
end;

procedure TdwsEngineUnit.DoSceneObjectCreateAt(Info: TProgramInfo;
  var ExtObject: TObject);
begin
  if ExtObject is TSceneObject then
    Exit;

  ExtObject := TSceneObject.Create(RootObject);
  TSceneObject(ExtObject).Position := ParamAsVector3(Info, 0);
  FContext.HandleOf(ExtObject);
end;

procedure TdwsEngineUnit.DoSceneObjectCreateNamed(Info: TProgramInfo;
  var ExtObject: TObject);
begin
  if ExtObject is TSceneObject then
    Exit;

  ExtObject := TSceneObject.Create(RootObject);
  TSceneObject(ExtObject).Name := Info.ParamAsString[0];
  TSceneObject(ExtObject).Position := DefaultObjectSpawnPosition(RootObject);
  FContext.HandleOf(ExtObject);
end;

procedure TdwsEngineUnit.DoSceneObjectCreateNamedAt(Info: TProgramInfo;
  var ExtObject: TObject);
begin
  if ExtObject is TSceneObject then
    Exit;

  ExtObject := TSceneObject.Create(RootObject);
  TSceneObject(ExtObject).Name := Info.ParamAsString[0];
  TSceneObject(ExtObject).Position := ParamAsVector3(Info, 1);
  FContext.HandleOf(ExtObject);
end;

procedure TdwsEngineUnit.DoSceneObjectCreateChild(Info: TProgramInfo;
  var ExtObject: TObject);
var
  Parent: TSceneObject;
begin
  if ExtObject is TSceneObject then
    Exit;

  Parent := ParamAsSceneObject(Info, 0);
  if Parent = nil then
    Parent := RootObject;

  ExtObject := TSceneObject.Create(Parent);
  TSceneObject(ExtObject).Name := Info.ParamAsString[1];
  TSceneObject(ExtObject).Position := DefaultObjectSpawnPosition(Parent);
  FContext.HandleOf(ExtObject);
end;

procedure TdwsEngineUnit.DoSceneObjectCreateChildAt(Info: TProgramInfo;
  var ExtObject: TObject);
var
  Parent: TSceneObject;
begin
  if ExtObject is TSceneObject then
    Exit;

  Parent := ParamAsSceneObject(Info, 0);
  if Parent = nil then
    Parent := RootObject;

  ExtObject := TSceneObject.Create(Parent);
  TSceneObject(ExtObject).Name := Info.ParamAsString[1];
  TSceneObject(ExtObject).Position := ParamAsVector3(Info, 2);
  FContext.HandleOf(ExtObject);
end;

procedure TdwsEngineUnit.DoSceneObjectCleanup(ExternalObject: TObject);
begin
  // Scene objects are owned by the scene graph, not by DWS adapter lifetime.
end;

procedure TdwsEngineUnit.DoSceneObjectDelete(Info: TProgramInfo; ExtObject: TObject);
var
  Obj: TSceneObject;
begin
  Obj := RequireSceneObject(ExtObject);
  if Obj = RootObject then
    raise Exception.Create('Cannot delete the scene root');

  DestroySceneObjectForScript(Obj);
end;

procedure TdwsEngineUnit.DoSceneObjectGetHandle(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsInteger := FContext.HandleOf(RequireSceneObject(ExtObject));
end;

procedure TdwsEngineUnit.DoSceneObjectGetName(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsString := RequireSceneObject(ExtObject).Name;
end;

procedure TdwsEngineUnit.DoSceneObjectSetName(Info: TProgramInfo; ExtObject: TObject);
begin
  RequireSceneObject(ExtObject).Name := Info.ParamAsString[0];
end;

procedure TdwsEngineUnit.DoSceneObjectGetPosition(Info: TProgramInfo; ExtObject: TObject);
begin
  SetResultVector3(Info, RequireSceneObject(ExtObject).Position);
end;

procedure TdwsEngineUnit.DoSceneObjectSetPosition(Info: TProgramInfo; ExtObject: TObject);
begin
  RequireSceneObject(ExtObject).Position := ParamAsVector3(Info, 0);
end;

procedure TdwsEngineUnit.DoSceneObjectGetRotation(Info: TProgramInfo; ExtObject: TObject);
begin
  SetResultVector3(Info, RequireSceneObject(ExtObject).Rotation);
end;

procedure TdwsEngineUnit.DoSceneObjectSetRotation(Info: TProgramInfo; ExtObject: TObject);
begin
  RequireSceneObject(ExtObject).Rotation := ParamAsVector3(Info, 0);
end;

procedure TdwsEngineUnit.DoSceneObjectGetScale(Info: TProgramInfo; ExtObject: TObject);
begin
  SetResultVector3(Info, RequireSceneObject(ExtObject).Scale);
end;

procedure TdwsEngineUnit.DoSceneObjectSetScale(Info: TProgramInfo; ExtObject: TObject);
begin
  RequireSceneObject(ExtObject).Scale := ParamAsVector3(Info, 0);
end;

procedure TdwsEngineUnit.DoSceneObjectGetMatrix(Info: TProgramInfo;
  ExtObject: TObject);
begin
  SetResultMatrix4(Info, RequireSceneObject(ExtObject).ObjectMatrix);
end;

procedure TdwsEngineUnit.DoSceneObjectGetModelMatrix(Info: TProgramInfo;
  ExtObject: TObject);
begin
  SetResultMatrix4(Info, RequireSceneObject(ExtObject).ObjectMatrix);
end;

procedure TdwsEngineUnit.DoSceneObjectGetLocalMatrix(Info: TProgramInfo;
  ExtObject: TObject);
begin
  SetResultMatrix4(Info, RequireSceneObject(ExtObject).ObjectMatrix);
end;

procedure TdwsEngineUnit.DoSceneObjectGetWorldMatrix(Info: TProgramInfo;
  ExtObject: TObject);
begin
  SetResultMatrix4(Info, WorldMatrixOf(RequireSceneObject(ExtObject)));
end;

procedure TdwsEngineUnit.DoSceneObjectGetWorldPosition(Info: TProgramInfo;
  ExtObject: TObject);
begin
  SetResultVector3(Info, WorldPositionOf(RequireSceneObject(ExtObject)));
end;

procedure TdwsEngineUnit.DoSceneObjectGetParent(Info: TProgramInfo; ExtObject: TObject);
begin
  SetResultSceneObject(Info, RequireSceneObject(ExtObject).Parent);
end;

procedure TdwsEngineUnit.DoSceneObjectGetChildCount(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsInteger := RequireSceneObject(ExtObject).Count;
end;

procedure TdwsEngineUnit.DoSceneObjectChild(Info: TProgramInfo; ExtObject: TObject);
begin
  SetResultSceneObject(Info,
    RequireSceneObject(ExtObject).ObjectList[Info.ParamAsInteger[0]]);
end;

procedure TdwsEngineUnit.DoSceneObjectGetWireframe(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsBoolean := RequireSceneObject(ExtObject).WireFrame;
end;

procedure TdwsEngineUnit.DoSceneObjectSetWireframe(Info: TProgramInfo;
  ExtObject: TObject);
begin
  RequireSceneObject(ExtObject).WireFrame := Info.ParamAsBoolean[0];
end;

procedure TdwsEngineUnit.DoSceneObjectGetHasGeometry(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsBoolean := RequireSceneObject(ExtObject).HasGeometry;
end;

procedure TdwsEngineUnit.DoSceneObjectGetHasCamera(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsBoolean := RequireSceneObject(ExtObject).HasCamera;
end;

procedure TdwsEngineUnit.DoSceneObjectGetHasParticles(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsBoolean := RequireSceneObject(ExtObject).HasParticles;
end;

procedure TdwsEngineUnit.DoSceneObjectGetHasBillboards(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsBoolean := RequireSceneObject(ExtObject).HasBillboard;
end;

procedure TdwsEngineUnit.DoSceneObjectGetHasAudio(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsBoolean := RequireSceneObject(ExtObject).HasAudio;
end;

procedure TdwsEngineUnit.DoSceneObjectGetHasSkeletonAnimation(
  Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsBoolean := RequireSceneObject(ExtObject).HasSkeletonAnimation;
end;

procedure TdwsEngineUnit.DoSceneObjectGetAnimationCount(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsInteger := RequireSceneObject(ExtObject).AnimationCount;
end;

procedure TdwsEngineUnit.DoSceneObjectAnimationName(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsString := RequireSceneObject(ExtObject).AnimationName(
    Info.ParamAsInteger[0]);
end;

procedure TdwsEngineUnit.DoSceneObjectSetAnimationName(Info: TProgramInfo;
  ExtObject: TObject);
var
  Animator: TSkeletonAnimator;
  Clip: TSkeletonAnimationClip;
  Index: Integer;
  ExistingIndex: Integer;
  NewName: string;
begin
  Info.ResultAsBoolean := False;
  Animator := RequireSceneObject(ExtObject).AnimationController;
  if not Assigned(Animator) then
    Exit;

  Index := Info.ParamAsInteger[0];
  Clip := Animator.Animations[Index];
  if not Assigned(Clip) then
    Exit;

  NewName := Trim(Info.ParamAsString[1]);
  if NewName = '' then
    Exit;

  ExistingIndex := Animator.AnimationIndexByName(NewName);
  if (ExistingIndex >= 0) and (ExistingIndex <> Index) then
    Exit;

  Clip.Name := NewName;
  Info.ResultAsBoolean := True;
end;

procedure TdwsEngineUnit.DoSceneObjectAnimationIndex(Info: TProgramInfo;
  ExtObject: TObject);
var
  Animator: TSkeletonAnimator;
begin
  Animator := RequireSceneObject(ExtObject).AnimationController;
  if Assigned(Animator) then
    Info.ResultAsInteger := Animator.AnimationIndexByName(Info.ParamAsString[0])
  else
    Info.ResultAsInteger := -1;
end;

procedure TdwsEngineUnit.DoSceneObjectGetCurrentAnimationName(
  Info: TProgramInfo; ExtObject: TObject);
var
  Animator: TSkeletonAnimator;
begin
  Animator := RequireSceneObject(ExtObject).AnimationController;
  if Assigned(Animator) then
    Info.ResultAsString := Animator.CurrentAnimationName
  else
    Info.ResultAsString := '';
end;

procedure TdwsEngineUnit.DoSceneObjectGetCurrentAnimationIndex(
  Info: TProgramInfo; ExtObject: TObject);
var
  Animator: TSkeletonAnimator;
begin
  Animator := RequireSceneObject(ExtObject).AnimationController;
  if Assigned(Animator) then
    Info.ResultAsInteger :=
      Animator.AnimationIndexByName(Animator.CurrentAnimationName)
  else
    Info.ResultAsInteger := -1;
end;

procedure TdwsEngineUnit.DoSceneObjectPlayAnimation(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsBoolean := RequireSceneObject(ExtObject).PlayAnimation(
    Info.ParamAsString[0], Info.ParamAsBoolean[1], Info.ParamAsFloat[2]);
end;

procedure TdwsEngineUnit.DoSceneObjectPlayAnimationIndex(Info: TProgramInfo;
  ExtObject: TObject);
var
  Animator: TSkeletonAnimator;
begin
  Animator := RequireSceneObject(ExtObject).AnimationController;
  if Assigned(Animator) then
    Info.ResultAsBoolean := Animator.Play(Info.ParamAsInteger[0],
      Info.ParamAsBoolean[1], Info.ParamAsFloat[2])
  else
    Info.ResultAsBoolean := False;
end;

procedure TdwsEngineUnit.DoSceneObjectBlendToAnimation(Info: TProgramInfo;
  ExtObject: TObject);
var
  Animator: TSkeletonAnimator;
begin
  Animator := RequireSceneObject(ExtObject).AnimationController;
  if Assigned(Animator) then
    Info.ResultAsBoolean := Animator.BlendTo(Info.ParamAsString[0],
      Info.ParamAsFloat[1], Info.ParamAsBoolean[2])
  else
    Info.ResultAsBoolean := False;
end;

procedure TdwsEngineUnit.DoSceneObjectIsAnimationPlaying(Info: TProgramInfo;
  ExtObject: TObject);
var
  Animator: TSkeletonAnimator;
begin
  Animator := RequireSceneObject(ExtObject).AnimationController;
  Info.ResultAsBoolean := Assigned(Animator) and
    (Animator.State = apsPlaying) and
    SameText(Animator.CurrentAnimationName, Info.ParamAsString[0]);
end;

procedure TdwsEngineUnit.DoSceneObjectPauseAnimation(Info: TProgramInfo;
  ExtObject: TObject);
begin
  RequireSceneObject(ExtObject).PauseAnimation;
end;

procedure TdwsEngineUnit.DoSceneObjectResumeAnimation(Info: TProgramInfo;
  ExtObject: TObject);
begin
  RequireSceneObject(ExtObject).ResumeAnimation;
end;

procedure TdwsEngineUnit.DoSceneObjectStopAnimation(Info: TProgramInfo;
  ExtObject: TObject);
begin
  RequireSceneObject(ExtObject).StopAnimation(Info.ParamAsBoolean[0]);
end;

procedure TdwsEngineUnit.DoSceneObjectGetAnimationState(Info: TProgramInfo;
  ExtObject: TObject);
var
  Animator: TSkeletonAnimator;
begin
  Animator := RequireSceneObject(ExtObject).AnimationController;
  if Assigned(Animator) then
    Info.ResultAsInteger := Ord(Animator.State)
  else
    Info.ResultAsInteger := Ord(apsStopped);
end;

procedure TdwsEngineUnit.DoSceneObjectGetAnimationTime(Info: TProgramInfo;
  ExtObject: TObject);
var
  Animator: TSkeletonAnimator;
begin
  Animator := RequireSceneObject(ExtObject).AnimationController;
  if Assigned(Animator) then
    Info.ResultAsFloat := Animator.CurrentTime
  else
    Info.ResultAsFloat := 0.0;
end;

procedure TdwsEngineUnit.DoSceneObjectSetAnimationTime(Info: TProgramInfo;
  ExtObject: TObject);
var
  Animator: TSkeletonAnimator;
begin
  Animator := RequireSceneObject(ExtObject).AnimationController;
  if Assigned(Animator) then
    Animator.Seek(Info.ParamAsFloat[0]);
end;

procedure TdwsEngineUnit.DoSceneObjectGetAnimationNormalizedTime(
  Info: TProgramInfo; ExtObject: TObject);
var
  Animator: TSkeletonAnimator;
begin
  Animator := RequireSceneObject(ExtObject).AnimationController;
  if Assigned(Animator) then
    Info.ResultAsFloat := Animator.NormalizedTime
  else
    Info.ResultAsFloat := 0.0;
end;

procedure TdwsEngineUnit.DoSceneObjectSetAnimationNormalizedTime(
  Info: TProgramInfo; ExtObject: TObject);
var
  Animator: TSkeletonAnimator;
  Duration: Single;
begin
  Animator := RequireSceneObject(ExtObject).AnimationController;
  if not Assigned(Animator) then
    Exit;

  Duration := Animator.Duration;
  if Duration > 1.0e-8 then
    Animator.Seek(EnsureRange(Info.ParamAsFloat[0], 0.0, 1.0) * Duration);
end;

procedure TdwsEngineUnit.DoSceneObjectGetAnimationDuration(Info: TProgramInfo;
  ExtObject: TObject);
var
  Animator: TSkeletonAnimator;
begin
  Animator := RequireSceneObject(ExtObject).AnimationController;
  if Assigned(Animator) then
    Info.ResultAsFloat := Animator.Duration
  else
    Info.ResultAsFloat := 0.0;
end;

procedure TdwsEngineUnit.DoSceneObjectAnimationClipDuration(
  Info: TProgramInfo; ExtObject: TObject);
var
  Animator: TSkeletonAnimator;
  Clip: TSkeletonAnimationClip;
begin
  Animator := RequireSceneObject(ExtObject).AnimationController;
  Clip := nil;
  if Assigned(Animator) then
    Clip := Animator.Animations[Info.ParamAsInteger[0]];

  if Assigned(Clip) then
    Info.ResultAsFloat := Clip.Duration
  else
    Info.ResultAsFloat := 0.0;
end;

procedure TdwsEngineUnit.DoSceneObjectAnimationClipDurationByName(
  Info: TProgramInfo; ExtObject: TObject);
var
  Animator: TSkeletonAnimator;
  Clip: TSkeletonAnimationClip;
begin
  Animator := RequireSceneObject(ExtObject).AnimationController;
  Clip := nil;
  if Assigned(Animator) then
    Clip := Animator.AnimationByName(Info.ParamAsString[0]);

  if Assigned(Clip) then
    Info.ResultAsFloat := Clip.Duration
  else
    Info.ResultAsFloat := 0.0;
end;

procedure TdwsEngineUnit.DoSceneObjectGetAnimationSpeed(Info: TProgramInfo;
  ExtObject: TObject);
var
  Animator: TSkeletonAnimator;
begin
  Animator := RequireSceneObject(ExtObject).AnimationController;
  if Assigned(Animator) then
    Info.ResultAsFloat := Animator.Speed
  else
    Info.ResultAsFloat := 1.0;
end;

procedure TdwsEngineUnit.DoSceneObjectSetAnimationSpeed(Info: TProgramInfo;
  ExtObject: TObject);
var
  Animator: TSkeletonAnimator;
begin
  Animator := RequireSceneObject(ExtObject).AnimationController;
  if Assigned(Animator) then
    Animator.Speed := Info.ParamAsFloat[0];
end;

procedure TdwsEngineUnit.DoSceneObjectGetAnimationLooping(Info: TProgramInfo;
  ExtObject: TObject);
var
  Animator: TSkeletonAnimator;
begin
  Animator := RequireSceneObject(ExtObject).AnimationController;
  Info.ResultAsBoolean := Assigned(Animator) and Animator.Looping;
end;

procedure TdwsEngineUnit.DoSceneObjectSetAnimationLooping(Info: TProgramInfo;
  ExtObject: TObject);
var
  Animator: TSkeletonAnimator;
begin
  Animator := RequireSceneObject(ExtObject).AnimationController;
  if Assigned(Animator) then
    Animator.Looping := Info.ParamAsBoolean[0];
end;

procedure TdwsEngineUnit.DoSceneObjectGetAnimationBlending(
  Info: TProgramInfo; ExtObject: TObject);
var
  Animator: TSkeletonAnimator;
begin
  Animator := RequireSceneObject(ExtObject).AnimationController;
  Info.ResultAsBoolean := Assigned(Animator) and Animator.IsBlending;
end;

procedure TdwsEngineUnit.DoSceneObjectGetMeshCount(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsInteger := RequireSceneObject(ExtObject).MeshList.Count;
end;

procedure TdwsEngineUnit.DoSceneObjectMesh(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsInteger := FContext.HandleOf(
    RequireSceneObject(ExtObject).MeshList.Item[Info.ParamAsInteger[0]]);
end;

procedure TdwsEngineUnit.DoSceneObjectMeshObject(Info: TProgramInfo;
  ExtObject: TObject);
begin
  SetResultMesh(Info,
    RequireSceneObject(ExtObject).MeshList.Item[Info.ParamAsInteger[0]]);
end;

procedure TdwsEngineUnit.DoSceneObjectAddMeshFile(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsInteger := AddMeshToObject(RequireSceneObject(ExtObject),
    TMesh.LoadFromFile(Info.ParamAsString[0]));
end;

procedure TdwsEngineUnit.DoSceneObjectAddMeshFileObject(Info: TProgramInfo;
  ExtObject: TObject);
var
  Mesh: TMesh;
begin
  Mesh := TMesh.LoadFromFile(Info.ParamAsString[0]);
  AddMeshToObject(RequireSceneObject(ExtObject), Mesh);
  SetResultMesh(Info, Mesh);
end;

procedure TdwsEngineUnit.DoSceneObjectSetMaterial(Info: TProgramInfo;
  ExtObject: TObject);
var
  Obj: TSceneObject;
  I: Integer;
begin
  Obj := RequireSceneObject(ExtObject);
  for I := 0 to Obj.MeshList.Count - 1 do
    if Assigned(Obj.MeshList.Item[I]) then
    begin
      Obj.MeshList.Item[I].MaterialLibrary := FContext.MaterialLibrary;
      Obj.MeshList.Item[I].LibMaterialname := Info.ParamAsString[0];
    end;
end;

procedure TdwsEngineUnit.DoSceneObjectGetParticleSystemCount(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsInteger := RequireSceneObject(ExtObject).ParticleSystemCount;
end;

procedure TdwsEngineUnit.DoSceneObjectParticleSystem(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsInteger := FContext.HandleOf(
    RequireSceneObject(ExtObject).ParticleSystemItem[Info.ParamAsInteger[0]]);
end;

procedure TdwsEngineUnit.DoSceneObjectCreateParticleSystem(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsInteger := FContext.HandleOf(
    RequireSceneObject(ExtObject).AddParticleSystem);
end;

procedure TdwsEngineUnit.DoSceneObjectRemoveParticleSystem(Info: TProgramInfo;
  ExtObject: TObject);
var
  Obj: TSceneObject;
  Particle: TParticleSystem;
  Index: Integer;
begin
  Obj := RequireSceneObject(ExtObject);
  Index := Info.ParamAsInteger[0];
  Particle := Obj.ParticleSystemItem[Index];
  if Obj.RemoveParticleSystem(Index) then
    FContext.Forget(Particle);
end;

procedure TdwsEngineUnit.DoSceneObjectGetLightCount(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsInteger := RequireSceneObject(ExtObject).LightsCount;
end;

procedure TdwsEngineUnit.DoSceneObjectLight(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsInteger := FContext.HandleOf(
    RequireSceneObject(ExtObject).Light[Info.ParamAsInteger[0]]);
end;

procedure TdwsEngineUnit.DoSceneObjectCreateLight(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsInteger := FContext.HandleOf(RequireSceneObject(ExtObject).CreateLight);
end;

procedure TdwsEngineUnit.DoSceneObjectLightObject(Info: TProgramInfo;
  ExtObject: TObject);
begin
  SetResultLight(Info, RequireSceneObject(ExtObject).Light[Info.ParamAsInteger[0]]);
end;

procedure TdwsEngineUnit.DoSceneObjectCreateLightObject(Info: TProgramInfo;
  ExtObject: TObject);
begin
  SetResultLight(Info, RequireSceneObject(ExtObject).CreateLight);
end;

procedure TdwsEngineUnit.DoSceneObjectCamera(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsInteger := FContext.HandleOf(RequireSceneObject(ExtObject).Camera);
end;

procedure TdwsEngineUnit.DoSceneObjectCreateCamera(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsInteger := FContext.HandleOf(RequireSceneObject(ExtObject).CreateCamera);
end;

procedure TdwsEngineUnit.DoLightCleanup(ExternalObject: TObject);
begin
  // Lights are owned by their scene objects, not by DWS adapter lifetime.
end;

procedure TdwsEngineUnit.DoLightGetHandle(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsInteger := FContext.HandleOf(RequireLight(ExtObject));
end;

procedure TdwsEngineUnit.DoLightGetName(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsString := RequireLight(ExtObject).Name;
end;

procedure TdwsEngineUnit.DoLightSetName(Info: TProgramInfo; ExtObject: TObject);
begin
  RequireLight(ExtObject).Name := Info.ParamAsString[0];
end;

procedure TdwsEngineUnit.DoLightGetType(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsInteger := Ord(RequireLight(ExtObject).LightType);
end;

procedure TdwsEngineUnit.DoLightSetTypeObject(Info: TProgramInfo; ExtObject: TObject);
var
  Value: Integer;
begin
  Value := EnsureRange(Info.ParamAsInteger[0], Ord(Low(TLightType)), Ord(High(TLightType)));
  RequireLight(ExtObject).LightType := TLightType(Value);
end;

procedure TdwsEngineUnit.DoLightGetEnabled(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsBoolean := RequireLight(ExtObject).Enabled;
end;

procedure TdwsEngineUnit.DoLightSetEnabledObject(Info: TProgramInfo; ExtObject: TObject);
begin
  RequireLight(ExtObject).Enabled := Info.ParamAsBoolean[0];
end;

procedure TdwsEngineUnit.DoLightGetAmbient(Info: TProgramInfo; ExtObject: TObject);
begin
  SetResultVector3(Info, RequireLight(ExtObject).Ambient);
end;

procedure TdwsEngineUnit.DoLightSetAmbientObject(Info: TProgramInfo; ExtObject: TObject);
begin
  RequireLight(ExtObject).Ambient := ParamAsVector3(Info, 0);
end;

procedure TdwsEngineUnit.DoLightGetDiffuse(Info: TProgramInfo; ExtObject: TObject);
begin
  SetResultVector3(Info, RequireLight(ExtObject).Diffuse);
end;

procedure TdwsEngineUnit.DoLightSetDiffuseObject(Info: TProgramInfo; ExtObject: TObject);
begin
  RequireLight(ExtObject).Diffuse := ParamAsVector3(Info, 0);
end;

procedure TdwsEngineUnit.DoLightGetSpecular(Info: TProgramInfo; ExtObject: TObject);
begin
  SetResultVector3(Info, RequireLight(ExtObject).Specular);
end;

procedure TdwsEngineUnit.DoLightSetSpecularObject(Info: TProgramInfo; ExtObject: TObject);
begin
  RequireLight(ExtObject).Specular := ParamAsVector3(Info, 0);
end;

procedure TdwsEngineUnit.DoLightGetPosition(Info: TProgramInfo; ExtObject: TObject);
begin
  SetResultVector3(Info, RequireLight(ExtObject).Position);
end;

procedure TdwsEngineUnit.DoLightSetPositionObject(Info: TProgramInfo; ExtObject: TObject);
begin
  RequireLight(ExtObject).Position := ParamAsVector3(Info, 0);
end;

procedure TdwsEngineUnit.DoLightGetDirection(Info: TProgramInfo; ExtObject: TObject);
begin
  SetResultVector3(Info, RequireLight(ExtObject).Direction);
end;

procedure TdwsEngineUnit.DoLightSetDirectionObject(Info: TProgramInfo; ExtObject: TObject);
begin
  RequireLight(ExtObject).Direction := ParamAsVector3(Info, 0);
end;

procedure TdwsEngineUnit.DoLightGetUseTarget(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsBoolean := RequireLight(ExtObject).UseTarget;
end;

procedure TdwsEngineUnit.DoLightSetUseTarget(Info: TProgramInfo; ExtObject: TObject);
begin
  RequireLight(ExtObject).UseTarget := Info.ParamAsBoolean[0];
end;

procedure TdwsEngineUnit.DoLightGetTargetPosition(Info: TProgramInfo; ExtObject: TObject);
begin
  SetResultVector3(Info, RequireLight(ExtObject).TargetPosition);
end;

procedure TdwsEngineUnit.DoLightSetTargetPosition(Info: TProgramInfo; ExtObject: TObject);
begin
  RequireLight(ExtObject).TargetPosition := ParamAsVector3(Info, 0);
end;

procedure TdwsEngineUnit.DoLightGetConstantAttenuation(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsFloat := RequireLight(ExtObject).ConstantAttenuation;
end;

procedure TdwsEngineUnit.DoLightSetConstantAttenuation(Info: TProgramInfo;
  ExtObject: TObject);
begin
  RequireLight(ExtObject).ConstantAttenuation := Info.ParamAsFloat[0];
end;

procedure TdwsEngineUnit.DoLightGetLinearAttenuation(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsFloat := RequireLight(ExtObject).LinearAttenuation;
end;

procedure TdwsEngineUnit.DoLightSetLinearAttenuation(Info: TProgramInfo;
  ExtObject: TObject);
begin
  RequireLight(ExtObject).LinearAttenuation := Info.ParamAsFloat[0];
end;

procedure TdwsEngineUnit.DoLightGetQuadraticAttenuation(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsFloat := RequireLight(ExtObject).QuadraticAttenuation;
end;

procedure TdwsEngineUnit.DoLightSetQuadraticAttenuation(Info: TProgramInfo;
  ExtObject: TObject);
begin
  RequireLight(ExtObject).QuadraticAttenuation := Info.ParamAsFloat[0];
end;

procedure TdwsEngineUnit.DoLightGetSpotCutoff(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsFloat := RequireLight(ExtObject).SpotCutoff;
end;

procedure TdwsEngineUnit.DoLightSetSpotCutoff(Info: TProgramInfo; ExtObject: TObject);
begin
  RequireLight(ExtObject).SpotCutoff := Info.ParamAsFloat[0];
end;

procedure TdwsEngineUnit.DoLightGetSpotExponent(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsFloat := RequireLight(ExtObject).SpotExponent;
end;

procedure TdwsEngineUnit.DoLightSetSpotExponent(Info: TProgramInfo; ExtObject: TObject);
begin
  RequireLight(ExtObject).SpotExponent := Info.ParamAsFloat[0];
end;

procedure TdwsEngineUnit.DoLightGetCastShadows(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsBoolean := RequireLight(ExtObject).CastShadows;
end;

procedure TdwsEngineUnit.DoLightSetCastShadowsObject(Info: TProgramInfo;
  ExtObject: TObject);
begin
  RequireLight(ExtObject).CastShadows := Info.ParamAsBoolean[0];
end;

procedure TdwsEngineUnit.DoLightGetShadowStrength(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsFloat := RequireLight(ExtObject).ShadowStrength;
end;

procedure TdwsEngineUnit.DoLightSetShadowStrengthObject(Info: TProgramInfo;
  ExtObject: TObject);
begin
  RequireLight(ExtObject).ShadowStrength := EnsureRange(Info.ParamAsFloat[0], 0.0, 1.0);
end;

procedure TdwsEngineUnit.DoLightSetAttenuationObject(Info: TProgramInfo;
  ExtObject: TObject);
var
  Light: TLight;
begin
  Light := RequireLight(ExtObject);
  Light.ConstantAttenuation := Info.ParamAsFloat[0];
  Light.LinearAttenuation := Info.ParamAsFloat[1];
  Light.QuadraticAttenuation := Info.ParamAsFloat[2];
end;

procedure TdwsEngineUnit.DoLightSetSpotObject(Info: TProgramInfo; ExtObject: TObject);
var
  Light: TLight;
begin
  Light := RequireLight(ExtObject);
  Light.SpotCutoff := DegToRad(Info.ParamAsFloat[0]);
  Light.SpotExponent := Info.ParamAsFloat[1];
end;

procedure TdwsEngineUnit.DoMaterialCleanup(ExternalObject: TObject);
begin
  // Materials are owned by the material library, not by DWS adapter lifetime.
end;

procedure TdwsEngineUnit.DoMaterialGetHandle(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsInteger := FContext.HandleOf(RequireMaterial(ExtObject));
end;

procedure TdwsEngineUnit.DoMaterialGetName(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsString := RequireMaterial(ExtObject).Name;
end;

procedure TdwsEngineUnit.DoMaterialSetName(Info: TProgramInfo; ExtObject: TObject);
begin
  RequireMaterial(ExtObject).Name := Info.ParamAsString[0];
end;

procedure TdwsEngineUnit.DoMaterialGetTextureCount(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsInteger := RequireMaterial(ExtObject).Count;
end;

procedure TdwsEngineUnit.DoMaterialGetMaterialID(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsInteger := RequireMaterial(ExtObject).MaterialID;
end;

procedure TdwsEngineUnit.DoMaterialGetMaterialType(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsInteger := Ord(RequireMaterial(ExtObject).Materialtype);
end;

procedure TdwsEngineUnit.DoMaterialSetMaterialType(Info: TProgramInfo;
  ExtObject: TObject);
var
  Value: Integer;
begin
  Value := EnsureRange(Info.ParamAsInteger[0], Ord(Low(TMaterialType)), Ord(High(TMaterialType)));
  RequireMaterial(ExtObject).Materialtype := TMaterialType(Value);
end;

procedure TdwsEngineUnit.DoMaterialGetShader(Info: TProgramInfo; ExtObject: TObject);
begin
  SetResultShader(Info, RequireMaterial(ExtObject).Shader);
end;

procedure TdwsEngineUnit.DoMaterialSetShader(Info: TProgramInfo; ExtObject: TObject);
begin
  RequireMaterial(ExtObject).Shader := ParamAsShader(Info, 0);
end;

procedure TdwsEngineUnit.DoMaterialShaderParameterObject(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsFloat := GetMaterialShaderParameter(
    RequireMaterial(ExtObject), Info.ParamAsString[0]);
end;

procedure TdwsEngineUnit.DoMaterialSetShaderParameterObject(Info: TProgramInfo;
  ExtObject: TObject);
begin
  SetMaterialShaderParameter(RequireMaterial(ExtObject),
    Info.ParamAsString[0], Info.ParamAsFloat[1]);
end;

procedure TdwsEngineUnit.DoShaderCleanup(ExternalObject: TObject);
begin
  // Shaders are owned by materials/rendering systems, not by DWS adapter lifetime.
end;

procedure TdwsEngineUnit.DoShaderGetHandle(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsInteger := FContext.HandleOf(RequireShader(ExtObject));
end;

procedure TdwsEngineUnit.DoShaderGetVertexPath(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsString := RequireShader(ExtObject).VertexPath;
end;

procedure TdwsEngineUnit.DoShaderGetFragmentPath(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsString := RequireShader(ExtObject).FragmentPath;
end;

procedure TdwsEngineUnit.DoShaderGetProgramID(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsInteger := Integer(RequireShader(ExtObject).ProgramID);
end;

procedure TdwsEngineUnit.DoShaderUseObject(Info: TProgramInfo; ExtObject: TObject);
begin
  RequireShader(ExtObject).Use;
end;

procedure TdwsEngineUnit.DoShaderReloadObject(Info: TProgramInfo; ExtObject: TObject);
begin
  RequireShader(ExtObject).Reload;
end;

procedure TdwsEngineUnit.DoShaderSetUniformBooleanObject(Info: TProgramInfo;
  ExtObject: TObject);
begin
  RequireShader(ExtObject).SetUniform(Info.ParamAsString[0], Info.ParamAsBoolean[1]);
end;

procedure TdwsEngineUnit.DoShaderSetUniformIntegerObject(Info: TProgramInfo;
  ExtObject: TObject);
begin
  RequireShader(ExtObject).SetUniform(Info.ParamAsString[0], Info.ParamAsInteger[1]);
end;

procedure TdwsEngineUnit.DoShaderSetUniformFloatObject(Info: TProgramInfo;
  ExtObject: TObject);
begin
  RequireShader(ExtObject).SetUniform(Info.ParamAsString[0], Info.ParamAsFloat[1]);
end;

procedure TdwsEngineUnit.DoShaderSetUniformVector3Object(Info: TProgramInfo;
  ExtObject: TObject);
begin
  RequireShader(ExtObject).SetUniform(Info.ParamAsString[0], ParamAsVector3(Info, 1));
end;

procedure TdwsEngineUnit.DoShaderSetUniformVector4Object(Info: TProgramInfo;
  ExtObject: TObject);
begin
  RequireShader(ExtObject).SetUniform(Info.ParamAsString[0], ParamAsVector4(Info, 1));
end;

procedure TdwsEngineUnit.DoShaderSetUniformMatrix4Object(Info: TProgramInfo;
  ExtObject: TObject);
begin
  RequireShader(ExtObject).SetUniform(Info.ParamAsString[0], ParamAsMatrix4(Info, 1));
end;

procedure TdwsEngineUnit.DoMeshFromHandle(Info: TProgramInfo);
begin
  SetResultMesh(Info, FContext.MeshFromHandle(Info.ParamAsInteger[0]));
end;

procedure TdwsEngineUnit.DoMeshHandle(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.HandleOf(ParamAsMesh(Info, 0));
end;

procedure TdwsEngineUnit.DoMeshName(Info: TProgramInfo);
begin
  Info.ResultAsString := FContext.MeshFromHandle(Info.ParamAsInteger[0]).Name;
end;

procedure TdwsEngineUnit.DoMeshSetName(Info: TProgramInfo);
var
  Mesh: TMesh;
begin
  Mesh := FContext.MeshFromHandle(Info.ParamAsInteger[0]);
  Mesh.Name := Info.ParamAsString[1];
  NotifyMeshChanged(Mesh);
end;

procedure TdwsEngineUnit.DoMeshPosition(Info: TProgramInfo);
begin
  SetResultVector3(Info, FContext.MeshFromHandle(Info.ParamAsInteger[0]).Position);
end;

procedure TdwsEngineUnit.DoMeshSetPosition(Info: TProgramInfo);
var
  Mesh: TMesh;
begin
  Mesh := FContext.MeshFromHandle(Info.ParamAsInteger[0]);
  Mesh.Position := ParamAsVector3(Info, 1);
  NotifyMeshChanged(Mesh);
end;

procedure TdwsEngineUnit.DoMeshRotation(Info: TProgramInfo);
begin
  SetResultVector3(Info, FContext.MeshFromHandle(Info.ParamAsInteger[0]).Rotation);
end;

procedure TdwsEngineUnit.DoMeshSetRotation(Info: TProgramInfo);
var
  Mesh: TMesh;
begin
  Mesh := FContext.MeshFromHandle(Info.ParamAsInteger[0]);
  Mesh.Rotation := ParamAsVector3(Info, 1);
  NotifyMeshChanged(Mesh);
end;

procedure TdwsEngineUnit.DoMeshScale(Info: TProgramInfo);
begin
  SetResultVector3(Info, FContext.MeshFromHandle(Info.ParamAsInteger[0]).Scale);
end;

procedure TdwsEngineUnit.DoMeshSetScale(Info: TProgramInfo);
var
  Mesh: TMesh;
begin
  Mesh := FContext.MeshFromHandle(Info.ParamAsInteger[0]);
  Mesh.Scale := ParamAsVector3(Info, 1);
  NotifyMeshChanged(Mesh);
end;

procedure TdwsEngineUnit.DoMeshSetTransform(Info: TProgramInfo);
var
  Mesh: TMesh;
begin
  Mesh := FContext.MeshFromHandle(Info.ParamAsInteger[0]);
  Mesh.SetTransform(ParamAsVector3(Info, 1), ParamAsVector3(Info, 2),
    ParamAsVector3(Info, 3));
  NotifyMeshChanged(Mesh);
end;

procedure TdwsEngineUnit.DoMeshVisible(Info: TProgramInfo);
begin
  Info.ResultAsBoolean := FContext.MeshFromHandle(Info.ParamAsInteger[0]).Visible;
end;

procedure TdwsEngineUnit.DoMeshSetVisible(Info: TProgramInfo);
var
  Mesh: TMesh;
begin
  Mesh := FContext.MeshFromHandle(Info.ParamAsInteger[0]);
  Mesh.Visible := Info.ParamAsBoolean[1];
  NotifyMeshChanged(Mesh);
end;

procedure TdwsEngineUnit.DoMeshWireframe(Info: TProgramInfo);
begin
  Info.ResultAsBoolean := FContext.MeshFromHandle(Info.ParamAsInteger[0]).WireFrame;
end;

procedure TdwsEngineUnit.DoMeshSetWireframe(Info: TProgramInfo);
var
  Mesh: TMesh;
begin
  Mesh := FContext.MeshFromHandle(Info.ParamAsInteger[0]);
  Mesh.WireFrame := Info.ParamAsBoolean[1];
  NotifyMeshChanged(Mesh);
end;

procedure TdwsEngineUnit.DoMeshAlwaysOnTop(Info: TProgramInfo);
begin
  Info.ResultAsBoolean := FContext.MeshFromHandle(Info.ParamAsInteger[0]).AlwaysOnTop;
end;

procedure TdwsEngineUnit.DoMeshSetAlwaysOnTop(Info: TProgramInfo);
var
  Mesh: TMesh;
begin
  Mesh := FContext.MeshFromHandle(Info.ParamAsInteger[0]);
  Mesh.AlwaysOnTop := Info.ParamAsBoolean[1];
  NotifyMeshChanged(Mesh);
end;

procedure TdwsEngineUnit.DoMeshTag(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.MeshFromHandle(Info.ParamAsInteger[0]).Tag;
end;

procedure TdwsEngineUnit.DoMeshSetTag(Info: TProgramInfo);
var
  Mesh: TMesh;
begin
  Mesh := FContext.MeshFromHandle(Info.ParamAsInteger[0]);
  Mesh.Tag := Info.ParamAsInteger[1];
  NotifyMeshChanged(Mesh);
end;

procedure TdwsEngineUnit.DoMeshType(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(FContext.MeshFromHandle(Info.ParamAsInteger[0]).MeshType);
end;

procedure TdwsEngineUnit.DoMeshVertexCount(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.MeshFromHandle(Info.ParamAsInteger[0]).VertexCount;
end;

procedure TdwsEngineUnit.DoMeshIndexCount(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.MeshFromHandle(Info.ParamAsInteger[0]).IndexCount;
end;

procedure TdwsEngineUnit.DoMeshBoundingBoxMin(Info: TProgramInfo);
begin
  SetResultVector3(Info, FContext.MeshFromHandle(Info.ParamAsInteger[0]).BoundingBoxMin);
end;

procedure TdwsEngineUnit.DoMeshBoundingBoxMax(Info: TProgramInfo);
begin
  SetResultVector3(Info, FContext.MeshFromHandle(Info.ParamAsInteger[0]).BoundingBoxMax);
end;

procedure TdwsEngineUnit.DoMeshLocalMatrix(Info: TProgramInfo);
begin
  SetResultMatrix4(Info, FContext.MeshFromHandle(Info.ParamAsInteger[0]).LocalMatrix);
end;

procedure TdwsEngineUnit.DoMeshModelMatrix(Info: TProgramInfo);
begin
  SetResultMatrix4(Info, FContext.MeshFromHandle(Info.ParamAsInteger[0]).ModelMatrix);
end;

procedure TdwsEngineUnit.DoMeshParentModelMatrix(Info: TProgramInfo);
begin
  SetResultMatrix4(Info, FContext.MeshFromHandle(Info.ParamAsInteger[0]).ParentModelMatrix);
end;

procedure TdwsEngineUnit.DoMeshMaterialName(Info: TProgramInfo);
begin
  Info.ResultAsString := FContext.MeshFromHandle(Info.ParamAsInteger[0]).LibMaterialname;
end;

procedure TdwsEngineUnit.DoMeshSetMaterialName(Info: TProgramInfo);
var
  Mesh: TMesh;
begin
  Mesh := FContext.MeshFromHandle(Info.ParamAsInteger[0]);
  SetMeshMaterialName(Mesh, Info.ParamAsString[1]);
  NotifyMeshChanged(Mesh);
end;

procedure TdwsEngineUnit.DoMeshSetMaterial(Info: TProgramInfo);
var
  Mesh: TMesh;
begin
  Mesh := FContext.MeshFromHandle(Info.ParamAsInteger[0]);
  SetMeshMaterialName(Mesh, Info.ParamAsString[1]);
  NotifyMeshChanged(Mesh);
end;

procedure TdwsEngineUnit.DoMeshApplyTransform(Info: TProgramInfo);
var
  Mesh: TMesh;
  Applied: Boolean;
begin
  Mesh := FContext.MeshFromHandle(Info.ParamAsInteger[0]);
  Applied := Mesh.ApplyTransform(ParamAsVector3(Info, 1),
    ParamAsVector3(Info, 2), ParamAsVector3(Info, 3));
  Info.ResultAsBoolean := Applied;
  if Applied then
    NotifyMeshChanged(Mesh);
end;

procedure TdwsEngineUnit.DoMeshScaleUVs(Info: TProgramInfo);
var
  Mesh: TMesh;
begin
  Mesh := FContext.MeshFromHandle(Info.ParamAsInteger[0]);
  Mesh.ScaleUVs(Info.ParamAsFloat[1], Info.ParamAsFloat[2]);
  NotifyMeshChanged(Mesh);
end;

procedure TdwsEngineUnit.DoMeshRecomputeBoundingBox(Info: TProgramInfo);
var
  Mesh: TMesh;
begin
  Mesh := FContext.MeshFromHandle(Info.ParamAsInteger[0]);
  NotifyMeshChanged(Mesh, True);
end;

procedure TdwsEngineUnit.DoMeshCleanup(ExternalObject: TObject);
begin
  // Meshes are owned by their scene object's mesh list, not by DWS adapter lifetime.
end;

procedure TdwsEngineUnit.DoMeshGetHandle(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsInteger := FContext.HandleOf(RequireMesh(ExtObject));
end;

procedure TdwsEngineUnit.DoMeshGetName(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsString := RequireMesh(ExtObject).Name;
end;

procedure TdwsEngineUnit.DoMeshSetNameObject(Info: TProgramInfo;
  ExtObject: TObject);
var
  Mesh: TMesh;
begin
  Mesh := RequireMesh(ExtObject);
  Mesh.Name := Info.ParamAsString[0];
  NotifyMeshChanged(Mesh);
end;

procedure TdwsEngineUnit.DoMeshGetPosition(Info: TProgramInfo;
  ExtObject: TObject);
begin
  SetResultVector3(Info, RequireMesh(ExtObject).Position);
end;

procedure TdwsEngineUnit.DoMeshSetPositionObject(Info: TProgramInfo;
  ExtObject: TObject);
var
  Mesh: TMesh;
begin
  Mesh := RequireMesh(ExtObject);
  Mesh.Position := ParamAsVector3(Info, 0);
  NotifyMeshChanged(Mesh);
end;

procedure TdwsEngineUnit.DoMeshGetRotation(Info: TProgramInfo;
  ExtObject: TObject);
begin
  SetResultVector3(Info, RequireMesh(ExtObject).Rotation);
end;

procedure TdwsEngineUnit.DoMeshSetRotationObject(Info: TProgramInfo;
  ExtObject: TObject);
var
  Mesh: TMesh;
begin
  Mesh := RequireMesh(ExtObject);
  Mesh.Rotation := ParamAsVector3(Info, 0);
  NotifyMeshChanged(Mesh);
end;

procedure TdwsEngineUnit.DoMeshGetScale(Info: TProgramInfo; ExtObject: TObject);
begin
  SetResultVector3(Info, RequireMesh(ExtObject).Scale);
end;

procedure TdwsEngineUnit.DoMeshSetScaleObject(Info: TProgramInfo;
  ExtObject: TObject);
var
  Mesh: TMesh;
begin
  Mesh := RequireMesh(ExtObject);
  Mesh.Scale := ParamAsVector3(Info, 0);
  NotifyMeshChanged(Mesh);
end;

procedure TdwsEngineUnit.DoMeshSetTransformObject(Info: TProgramInfo;
  ExtObject: TObject);
var
  Mesh: TMesh;
begin
  Mesh := RequireMesh(ExtObject);
  Mesh.SetTransform(ParamAsVector3(Info, 0), ParamAsVector3(Info, 1),
    ParamAsVector3(Info, 2));
  NotifyMeshChanged(Mesh);
end;

procedure TdwsEngineUnit.DoMeshGetVisible(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsBoolean := RequireMesh(ExtObject).Visible;
end;

procedure TdwsEngineUnit.DoMeshSetVisibleObject(Info: TProgramInfo;
  ExtObject: TObject);
var
  Mesh: TMesh;
begin
  Mesh := RequireMesh(ExtObject);
  Mesh.Visible := Info.ParamAsBoolean[0];
  NotifyMeshChanged(Mesh);
end;

procedure TdwsEngineUnit.DoMeshGetWireframe(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsBoolean := RequireMesh(ExtObject).WireFrame;
end;

procedure TdwsEngineUnit.DoMeshSetWireframeObject(Info: TProgramInfo;
  ExtObject: TObject);
var
  Mesh: TMesh;
begin
  Mesh := RequireMesh(ExtObject);
  Mesh.WireFrame := Info.ParamAsBoolean[0];
  NotifyMeshChanged(Mesh);
end;

procedure TdwsEngineUnit.DoMeshGetAlwaysOnTop(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsBoolean := RequireMesh(ExtObject).AlwaysOnTop;
end;

procedure TdwsEngineUnit.DoMeshSetAlwaysOnTopObject(Info: TProgramInfo;
  ExtObject: TObject);
var
  Mesh: TMesh;
begin
  Mesh := RequireMesh(ExtObject);
  Mesh.AlwaysOnTop := Info.ParamAsBoolean[0];
  NotifyMeshChanged(Mesh);
end;

procedure TdwsEngineUnit.DoMeshGetTag(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsInteger := RequireMesh(ExtObject).Tag;
end;

procedure TdwsEngineUnit.DoMeshSetTagObject(Info: TProgramInfo;
  ExtObject: TObject);
var
  Mesh: TMesh;
begin
  Mesh := RequireMesh(ExtObject);
  Mesh.Tag := Info.ParamAsInteger[0];
  NotifyMeshChanged(Mesh);
end;

procedure TdwsEngineUnit.DoMeshGetMeshType(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsInteger := Ord(RequireMesh(ExtObject).MeshType);
end;

procedure TdwsEngineUnit.DoMeshGetVertexCount(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsInteger := RequireMesh(ExtObject).VertexCount;
end;

procedure TdwsEngineUnit.DoMeshGetIndexCount(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsInteger := RequireMesh(ExtObject).IndexCount;
end;

procedure TdwsEngineUnit.DoMeshGetBoundingBoxMin(Info: TProgramInfo;
  ExtObject: TObject);
begin
  SetResultVector3(Info, RequireMesh(ExtObject).BoundingBoxMin);
end;

procedure TdwsEngineUnit.DoMeshGetBoundingBoxMax(Info: TProgramInfo;
  ExtObject: TObject);
begin
  SetResultVector3(Info, RequireMesh(ExtObject).BoundingBoxMax);
end;

procedure TdwsEngineUnit.DoMeshGetLocalMatrix(Info: TProgramInfo;
  ExtObject: TObject);
begin
  SetResultMatrix4(Info, RequireMesh(ExtObject).LocalMatrix);
end;

procedure TdwsEngineUnit.DoMeshGetModelMatrix(Info: TProgramInfo;
  ExtObject: TObject);
begin
  SetResultMatrix4(Info, RequireMesh(ExtObject).ModelMatrix);
end;

procedure TdwsEngineUnit.DoMeshGetParentModelMatrix(Info: TProgramInfo;
  ExtObject: TObject);
begin
  SetResultMatrix4(Info, RequireMesh(ExtObject).ParentModelMatrix);
end;

procedure TdwsEngineUnit.DoMeshGetMaterialName(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsString := RequireMesh(ExtObject).LibMaterialname;
end;

procedure TdwsEngineUnit.DoMeshSetMaterialNameObject(Info: TProgramInfo;
  ExtObject: TObject);
var
  Mesh: TMesh;
begin
  Mesh := RequireMesh(ExtObject);
  SetMeshMaterialName(Mesh, Info.ParamAsString[0]);
  NotifyMeshChanged(Mesh);
end;

procedure TdwsEngineUnit.DoMeshSetMaterialObject(Info: TProgramInfo;
  ExtObject: TObject);
var
  Mesh: TMesh;
begin
  Mesh := RequireMesh(ExtObject);
  SetMeshMaterialName(Mesh, Info.ParamAsString[0]);
  NotifyMeshChanged(Mesh);
end;

procedure TdwsEngineUnit.DoMeshApplyTransformObject(Info: TProgramInfo;
  ExtObject: TObject);
var
  Mesh: TMesh;
  Applied: Boolean;
begin
  Mesh := RequireMesh(ExtObject);
  Applied := Mesh.ApplyTransform(ParamAsVector3(Info, 0),
    ParamAsVector3(Info, 1), ParamAsVector3(Info, 2));
  Info.ResultAsBoolean := Applied;
  if Applied then
    NotifyMeshChanged(Mesh);
end;

procedure TdwsEngineUnit.DoMeshScaleUVsObject(Info: TProgramInfo;
  ExtObject: TObject);
var
  Mesh: TMesh;
begin
  Mesh := RequireMesh(ExtObject);
  Mesh.ScaleUVs(Info.ParamAsFloat[0], Info.ParamAsFloat[1]);
  NotifyMeshChanged(Mesh);
end;

procedure TdwsEngineUnit.DoMeshRecomputeBoundingBoxObject(Info: TProgramInfo;
  ExtObject: TObject);
begin
  NotifyMeshChanged(RequireMesh(ExtObject), True);
end;

procedure TdwsEngineUnit.DoObjectParticleSystemCount(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).ParticleSystemCount;
end;

procedure TdwsEngineUnit.DoObjectParticleSystem(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.HandleOf(
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).ParticleSystemItem[Info.ParamAsInteger[1]]);
end;

procedure TdwsEngineUnit.DoObjectCreateParticleSystem(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.HandleOf(
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).AddParticleSystem);
end;

procedure TdwsEngineUnit.DoObjectRemoveParticleSystem(Info: TProgramInfo);
var
  Obj: TSceneObject;
  Particle: TParticleSystem;
  Index: Integer;
begin
  Obj := FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]);
  Index := Info.ParamAsInteger[1];
  Particle := Obj.ParticleSystemItem[Index];
  if Obj.RemoveParticleSystem(Index) then
    FContext.Forget(Particle);
end;

procedure TdwsEngineUnit.DoParticleBlendAlpha(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(pbAlpha);
end;

procedure TdwsEngineUnit.DoParticleBlendAdditive(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(pbAdditive);
end;

procedure TdwsEngineUnit.DoParticleTextureNone(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(ptNone);
end;

procedure TdwsEngineUnit.DoParticleTextureSoftCircle(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(ptSoftCircle);
end;

procedure TdwsEngineUnit.DoParticleTexturePerlin(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(ptPerlin);
end;

procedure TdwsEngineUnit.DoParticleTextureFile(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(ptFile);
end;

procedure TdwsEngineUnit.DoParticleSpaceObject(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(psObject);
end;

procedure TdwsEngineUnit.DoParticleSpaceWorld(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(psWorld);
end;

procedure TdwsEngineUnit.DoParticleCount(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.ParticleSystemFromHandle(Info.ParamAsInteger[0]).ParticleCount;
end;

procedure TdwsEngineUnit.DoParticleClear(Info: TProgramInfo);
begin
  FContext.ParticleSystemFromHandle(Info.ParamAsInteger[0]).Clear;
end;

procedure TdwsEngineUnit.DoParticleBurst(Info: TProgramInfo);
var
  Particle: TParticleSystem;
  Owner: TSceneObject;
  Count: Integer;
begin
  Particle := FContext.ParticleSystemFromHandle(Info.ParamAsInteger[0]);
  Count := Max(0, Info.ParamAsInteger[1]);
  Owner := FContext.OwnerOfParticleSystem(Particle);
  if Owner = nil then
  begin
    Particle.Burst(Count);
    Exit;
  end;

  if FContext.SceneManager <> nil then
    FContext.SceneManager.Update
  else
    Owner.UpdateWorldMatrices;
  Particle.Burst(Count, Owner.WorldMatrix);
end;

procedure TdwsEngineUnit.DoParticleBoolean(Info: TProgramInfo);
var
  Particle: TParticleSystem;
  Name: string;
begin
  Particle := FContext.ParticleSystemFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Enabled') then
    Info.ResultAsBoolean := Particle.Enabled
  else if SameText(Name, 'AutoEmit') then
    Info.ResultAsBoolean := Particle.AutoEmit
  else
    raise Exception.CreateFmt('Unknown particle boolean property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoParticleSetBoolean(Info: TProgramInfo);
var
  Particle: TParticleSystem;
  Name: string;
begin
  Particle := FContext.ParticleSystemFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Enabled') then
    Particle.Enabled := Info.ParamAsBoolean[2]
  else if SameText(Name, 'AutoEmit') then
    Particle.AutoEmit := Info.ParamAsBoolean[2]
  else
    raise Exception.CreateFmt('Unknown particle boolean property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoParticleInteger(Info: TProgramInfo);
var
  Particle: TParticleSystem;
  Name: string;
begin
  Particle := FContext.ParticleSystemFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'MaxParticles') then
    Info.ResultAsInteger := Particle.MaxParticles
  else if SameText(Name, 'ParticlePoolSize') then
    Info.ResultAsInteger := Particle.ParticlePoolSize
  else if SameText(Name, 'SimulationSpace') then
    Info.ResultAsInteger := Ord(Particle.SimulationSpace)
  else if SameText(Name, 'BlendMode') then
    Info.ResultAsInteger := Ord(Particle.BlendMode)
  else if SameText(Name, 'TextureKind') then
    Info.ResultAsInteger := Ord(Particle.TextureKind)
  else if SameText(Name, 'TexMapSize') then
    Info.ResultAsInteger := Particle.TexMapSize
  else if SameText(Name, 'NoiseSeed') then
    Info.ResultAsInteger := Particle.NoiseSeed
  else if SameText(Name, 'NoiseScale') then
    Info.ResultAsInteger := Particle.NoiseScale
  else if SameText(Name, 'NoiseAmplitude') then
    Info.ResultAsInteger := Particle.NoiseAmplitude
  else if SameText(Name, 'ParticleCount') then
    Info.ResultAsInteger := Particle.ParticleCount
  else
    raise Exception.CreateFmt('Unknown particle integer property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoParticleSetInteger(Info: TProgramInfo);
var
  Particle: TParticleSystem;
  Name: string;
  Value: Integer;
begin
  Particle := FContext.ParticleSystemFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  Value := Info.ParamAsInteger[2];
  if SameText(Name, 'MaxParticles') then
    Particle.MaxParticles := Value
  else if SameText(Name, 'ParticlePoolSize') then
    Particle.ParticlePoolSize := Value
  else if SameText(Name, 'SimulationSpace') then
    Particle.SimulationSpace := TParticleSimulationSpace(EnsureRange(Value, Ord(Low(TParticleSimulationSpace)), Ord(High(TParticleSimulationSpace))))
  else if SameText(Name, 'BlendMode') then
    Particle.BlendMode := TParticleBlendMode(EnsureRange(Value, Ord(Low(TParticleBlendMode)), Ord(High(TParticleBlendMode))))
  else if SameText(Name, 'TextureKind') then
    Particle.TextureKind := TParticleTextureKind(EnsureRange(Value, Ord(Low(TParticleTextureKind)), Ord(High(TParticleTextureKind))))
  else if SameText(Name, 'TexMapSize') then
    Particle.TexMapSize := Value
  else if SameText(Name, 'NoiseSeed') then
    Particle.NoiseSeed := Value
  else if SameText(Name, 'NoiseScale') then
    Particle.NoiseScale := Value
  else if SameText(Name, 'NoiseAmplitude') then
    Particle.NoiseAmplitude := Value
  else
    raise Exception.CreateFmt('Unknown writable particle integer property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoParticleFloat(Info: TProgramInfo);
var
  Particle: TParticleSystem;
  Name: string;
begin
  Particle := FContext.ParticleSystemFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'EmissionRate') then
    Info.ResultAsFloat := Particle.EmissionRate
  else if SameText(Name, 'ParticleLife') then
    Info.ResultAsFloat := Particle.ParticleLife
  else if SameText(Name, 'ParticleLifeRandom') then
    Info.ResultAsFloat := Particle.ParticleLifeRandom
  else if SameText(Name, 'PositionDispersion') then
    Info.ResultAsFloat := Particle.PositionDispersion
  else if SameText(Name, 'VelocityDispersion') then
    Info.ResultAsFloat := Particle.VelocityDispersion
  else if SameText(Name, 'Friction') then
    Info.ResultAsFloat := Particle.Friction
  else if SameText(Name, 'StartSize') then
    Info.ResultAsFloat := Particle.StartSize
  else if SameText(Name, 'EndSize') then
    Info.ResultAsFloat := Particle.EndSize
  else if SameText(Name, 'SizeRandom') then
    Info.ResultAsFloat := Particle.SizeRandom
  else if SameText(Name, 'AspectRatio') then
    Info.ResultAsFloat := Particle.AspectRatio
  else if SameText(Name, 'RotationDispersion') then
    Info.ResultAsFloat := Particle.RotationDispersion
  else if SameText(Name, 'AngularVelocityDispersion') then
    Info.ResultAsFloat := Particle.AngularVelocityDispersion
  else if SameText(Name, 'Smoothness') then
    Info.ResultAsFloat := Particle.Smoothness
  else if SameText(Name, 'Brightness') then
    Info.ResultAsFloat := Particle.Brightness
  else if SameText(Name, 'Gamma') then
    Info.ResultAsFloat := Particle.Gamma
  else
    raise Exception.CreateFmt('Unknown particle float property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoParticleSetFloat(Info: TProgramInfo);
var
  Particle: TParticleSystem;
  Name: string;
  Value: Single;
begin
  Particle := FContext.ParticleSystemFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  Value := Info.ParamAsFloat[2];
  if SameText(Name, 'EmissionRate') then
    Particle.EmissionRate := Value
  else if SameText(Name, 'ParticleLife') then
    Particle.ParticleLife := Value
  else if SameText(Name, 'ParticleLifeRandom') then
    Particle.ParticleLifeRandom := Value
  else if SameText(Name, 'PositionDispersion') then
    Particle.PositionDispersion := Value
  else if SameText(Name, 'VelocityDispersion') then
    Particle.VelocityDispersion := Value
  else if SameText(Name, 'Friction') then
    Particle.Friction := Value
  else if SameText(Name, 'StartSize') then
    Particle.StartSize := Value
  else if SameText(Name, 'EndSize') then
    Particle.EndSize := Value
  else if SameText(Name, 'SizeRandom') then
    Particle.SizeRandom := Value
  else if SameText(Name, 'AspectRatio') then
    Particle.AspectRatio := Value
  else if SameText(Name, 'RotationDispersion') then
    Particle.RotationDispersion := Value
  else if SameText(Name, 'AngularVelocityDispersion') then
    Particle.AngularVelocityDispersion := Value
  else if SameText(Name, 'Smoothness') then
    Particle.Smoothness := Value
  else if SameText(Name, 'Brightness') then
    Particle.Brightness := Value
  else if SameText(Name, 'Gamma') then
    Particle.Gamma := Value
  else
    raise Exception.CreateFmt('Unknown particle float property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoParticleVector3(Info: TProgramInfo);
var
  Particle: TParticleSystem;
  Name: string;
begin
  Particle := FContext.ParticleSystemFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'InitialPosition') then
    SetResultVector3(Info, Particle.InitialPosition)
  else if SameText(Name, 'InitialVelocity') then
    SetResultVector3(Info, Particle.InitialVelocity)
  else if SameText(Name, 'PositionDispersionRange') then
    SetResultVector3(Info, Particle.PositionDispersionRange)
  else if SameText(Name, 'Acceleration') then
    SetResultVector3(Info, Particle.Acceleration)
  else
    raise Exception.CreateFmt('Unknown particle TVector3 property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoParticleSetVector3(Info: TProgramInfo);
var
  Particle: TParticleSystem;
  Name: string;
  Value: TVector3;
begin
  Particle := FContext.ParticleSystemFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  Value := ParamAsVector3(Info, 2);
  if SameText(Name, 'InitialPosition') then
    Particle.InitialPosition := Value
  else if SameText(Name, 'InitialVelocity') then
    Particle.InitialVelocity := Value
  else if SameText(Name, 'PositionDispersionRange') then
    Particle.PositionDispersionRange := Value
  else if SameText(Name, 'Acceleration') then
    Particle.Acceleration := Value
  else
    raise Exception.CreateFmt('Unknown particle TVector3 property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoParticleVector4(Info: TProgramInfo);
var
  Particle: TParticleSystem;
  Name: string;
begin
  Particle := FContext.ParticleSystemFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'StartColor') then
    SetResultVector4(Info, Particle.StartColor)
  else if SameText(Name, 'EndColor') then
    SetResultVector4(Info, Particle.EndColor)
  else
    raise Exception.CreateFmt('Unknown particle TVector4 property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoParticleSetVector4(Info: TProgramInfo);
var
  Particle: TParticleSystem;
  Name: string;
  Value: TVector4;
begin
  Particle := FContext.ParticleSystemFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  Value := ParamAsVector4(Info, 2);
  if SameText(Name, 'StartColor') then
    Particle.StartColor := Value
  else if SameText(Name, 'EndColor') then
    Particle.EndColor := Value
  else
    raise Exception.CreateFmt('Unknown particle TVector4 property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoParticleString(Info: TProgramInfo);
var
  Particle: TParticleSystem;
  Name: string;
begin
  Particle := FContext.ParticleSystemFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Name') then
    Info.ResultAsString := Particle.Name
  else if SameText(Name, 'TexturePath') then
    Info.ResultAsString := Particle.TexturePath
  else
    raise Exception.CreateFmt('Unknown particle string property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoParticleSetString(Info: TProgramInfo);
var
  Particle: TParticleSystem;
  Name: string;
begin
  Particle := FContext.ParticleSystemFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Name') then
    Particle.Name := Info.ParamAsString[2]
  else if SameText(Name, 'TexturePath') then
    Particle.TexturePath := Info.ParamAsString[2]
  else
    raise Exception.CreateFmt('Unknown particle string property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoObjectBillboardCount(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).BillboardCount;
end;

procedure TdwsEngineUnit.DoObjectBillboard(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.HandleOf(
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).BillboardItem[Info.ParamAsInteger[1]]);
end;

procedure TdwsEngineUnit.DoObjectCreateBillboard(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.HandleOf(
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).AddBillboard);
end;

procedure TdwsEngineUnit.DoObjectRemoveBillboard(Info: TProgramInfo);
var
  Obj: TSceneObject;
  Billboard: TBillboard;
  Index: Integer;
begin
  Obj := FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]);
  Index := Info.ParamAsInteger[1];
  Billboard := Obj.BillboardItem[Index];
  if Obj.RemoveBillboard(Index) then
    FContext.Forget(Billboard);
end;

procedure TdwsEngineUnit.DoBillboardBlendAlpha(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(bbAlpha);
end;

procedure TdwsEngineUnit.DoBillboardBlendAdditive(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(bbAdditive);
end;

procedure TdwsEngineUnit.DoBillboardBoolean(Info: TProgramInfo);
var
  Billboard: TBillboard;
  Name: string;
begin
  Billboard := FContext.BillboardFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Enabled') then
    Info.ResultAsBoolean := Billboard.Enabled
  else
    raise Exception.CreateFmt('Unknown billboard boolean property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoBillboardSetBoolean(Info: TProgramInfo);
var
  Billboard: TBillboard;
  Name: string;
begin
  Billboard := FContext.BillboardFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Enabled') then
    Billboard.Enabled := Info.ParamAsBoolean[2]
  else
    raise Exception.CreateFmt('Unknown billboard boolean property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoBillboardInteger(Info: TProgramInfo);
var
  Billboard: TBillboard;
  Name: string;
begin
  Billboard := FContext.BillboardFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'BlendMode') then
    Info.ResultAsInteger := Ord(Billboard.BlendMode)
  else if SameText(Name, 'TextureID') then
    Info.ResultAsInteger := Billboard.TextureID
  else if SameText(Name, 'TextureWidth') then
    Info.ResultAsInteger := Billboard.TextureWidth
  else if SameText(Name, 'TextureHeight') then
    Info.ResultAsInteger := Billboard.TextureHeight
  else
    raise Exception.CreateFmt('Unknown billboard integer property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoBillboardSetInteger(Info: TProgramInfo);
var
  Billboard: TBillboard;
  Name: string;
begin
  Billboard := FContext.BillboardFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'BlendMode') then
    Billboard.BlendMode := TBillboardBlendMode(EnsureRange(Info.ParamAsInteger[2], Ord(Low(TBillboardBlendMode)), Ord(High(TBillboardBlendMode))))
  else
    raise Exception.CreateFmt('Unknown writable billboard integer property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoBillboardFloat(Info: TProgramInfo);
var
  Billboard: TBillboard;
  Name: string;
begin
  Billboard := FContext.BillboardFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Width') then
    Info.ResultAsFloat := Billboard.Width
  else if SameText(Name, 'Height') then
    Info.ResultAsFloat := Billboard.Height
  else if SameText(Name, 'Rotation') then
    Info.ResultAsFloat := Billboard.Rotation
  else if SameText(Name, 'AlphaCutoff') then
    Info.ResultAsFloat := Billboard.AlphaCutoff
  else
    raise Exception.CreateFmt('Unknown billboard float property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoBillboardSetFloat(Info: TProgramInfo);
var
  Billboard: TBillboard;
  Name: string;
  Value: Single;
begin
  Billboard := FContext.BillboardFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  Value := Info.ParamAsFloat[2];
  if SameText(Name, 'Width') then
    Billboard.Width := Value
  else if SameText(Name, 'Height') then
    Billboard.Height := Value
  else if SameText(Name, 'Rotation') then
    Billboard.Rotation := Value
  else if SameText(Name, 'AlphaCutoff') then
    Billboard.AlphaCutoff := Value
  else
    raise Exception.CreateFmt('Unknown billboard float property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoBillboardVector3(Info: TProgramInfo);
var
  Billboard: TBillboard;
  Name: string;
begin
  Billboard := FContext.BillboardFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Offset') then
    SetResultVector3(Info, Billboard.Offset)
  else
    raise Exception.CreateFmt('Unknown billboard TVector3 property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoBillboardSetVector3(Info: TProgramInfo);
var
  Billboard: TBillboard;
  Name: string;
begin
  Billboard := FContext.BillboardFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Offset') then
    Billboard.Offset := ParamAsVector3(Info, 2)
  else
    raise Exception.CreateFmt('Unknown billboard TVector3 property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoBillboardVector4(Info: TProgramInfo);
var
  Billboard: TBillboard;
  Name: string;
begin
  Billboard := FContext.BillboardFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Color') then
    SetResultVector4(Info, Billboard.Color)
  else
    raise Exception.CreateFmt('Unknown billboard TVector4 property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoBillboardSetVector4(Info: TProgramInfo);
var
  Billboard: TBillboard;
  Name: string;
begin
  Billboard := FContext.BillboardFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Color') then
    Billboard.Color := ParamAsVector4(Info, 2)
  else
    raise Exception.CreateFmt('Unknown billboard TVector4 property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoBillboardString(Info: TProgramInfo);
var
  Billboard: TBillboard;
  Name: string;
begin
  Billboard := FContext.BillboardFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Name') then
    Info.ResultAsString := Billboard.Name
  else if SameText(Name, 'TexturePath') then
    Info.ResultAsString := Billboard.TexturePath
  else
    raise Exception.CreateFmt('Unknown billboard string property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoBillboardSetString(Info: TProgramInfo);
var
  Billboard: TBillboard;
  Name: string;
begin
  Billboard := FContext.BillboardFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Name') then
    Billboard.Name := Info.ParamAsString[2]
  else if SameText(Name, 'TexturePath') then
    Billboard.TexturePath := Info.ParamAsString[2]
  else
    raise Exception.CreateFmt('Unknown billboard string property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoObjectAudioEmitterCount(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).AudioEmitterCount;
end;

procedure TdwsEngineUnit.DoObjectAudioEmitter(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.HandleOf(
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).AudioEmitterItem[Info.ParamAsInteger[1]]);
end;

procedure TdwsEngineUnit.DoObjectCreateAudioEmitter(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.HandleOf(
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).AddAudioEmitter);
end;

procedure TdwsEngineUnit.DoObjectRemoveAudioEmitter(Info: TProgramInfo);
var
  Obj: TSceneObject;
  Emitter: TSceneAudioEmitter;
  Index: Integer;
begin
  Obj := FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]);
  Index := Info.ParamAsInteger[1];
  Emitter := Obj.AudioEmitterItem[Index];
  if Emitter = nil then
    Exit;

  ReleaseAudioEmitterRuntime(Emitter);
  if Obj.RemoveAudioEmitter(Index) then
    FContext.Forget(Emitter);
end;

procedure TdwsEngineUnit.DoObjectAudioListener(Info: TProgramInfo);
begin
  Info.ResultAsBoolean := FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).AudioListener;
end;

procedure TdwsEngineUnit.DoObjectSetAudioListener(Info: TProgramInfo);
begin
  FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).AudioListener := Info.ParamAsBoolean[1];
end;

procedure TdwsEngineUnit.DoObjectAudioVector3(Info: TProgramInfo);
var
  Obj: TSceneObject;
  Name: string;
begin
  Obj := FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Velocity') or SameText(Name, 'AudioListenerVelocity') then
    SetResultVector3(Info, Obj.AudioListenerVelocity)
  else if SameText(Name, 'Front') or SameText(Name, 'AudioListenerFront') then
    SetResultVector3(Info, Obj.AudioListenerFront)
  else if SameText(Name, 'Top') or SameText(Name, 'AudioListenerTop') then
    SetResultVector3(Info, Obj.AudioListenerTop)
  else
    raise Exception.CreateFmt('Unknown object audio TVector3 property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoObjectSetAudioVector3(Info: TProgramInfo);
var
  Obj: TSceneObject;
  Name: string;
  Value: TVector3;
begin
  Obj := FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  Value := ParamAsVector3(Info, 2);
  if SameText(Name, 'Velocity') or SameText(Name, 'AudioListenerVelocity') then
    Obj.AudioListenerVelocity := Value
  else if SameText(Name, 'Front') or SameText(Name, 'AudioListenerFront') then
    Obj.AudioListenerFront := Value
  else if SameText(Name, 'Top') or SameText(Name, 'AudioListenerTop') then
    Obj.AudioListenerTop := Value
  else
    raise Exception.CreateFmt('Unknown object audio TVector3 property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoObjectAudioFloat(Info: TProgramInfo);
var
  Obj: TSceneObject;
  Name: string;
begin
  Obj := FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'DistanceFactor') or SameText(Name, 'AudioDistanceFactor') then
    Info.ResultAsFloat := Obj.AudioDistanceFactor
  else if SameText(Name, 'RolloffFactor') or SameText(Name, 'AudioRolloffFactor') then
    Info.ResultAsFloat := Obj.AudioRolloffFactor
  else if SameText(Name, 'DopplerFactor') or SameText(Name, 'AudioDopplerFactor') then
    Info.ResultAsFloat := Obj.AudioDopplerFactor
  else
    raise Exception.CreateFmt('Unknown object audio float property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoObjectSetAudioFloat(Info: TProgramInfo);
var
  Obj: TSceneObject;
  Name: string;
begin
  Obj := FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'DistanceFactor') or SameText(Name, 'AudioDistanceFactor') then
    Obj.AudioDistanceFactor := Info.ParamAsFloat[2]
  else if SameText(Name, 'RolloffFactor') or SameText(Name, 'AudioRolloffFactor') then
    Obj.AudioRolloffFactor := Info.ParamAsFloat[2]
  else if SameText(Name, 'DopplerFactor') or SameText(Name, 'AudioDopplerFactor') then
    Obj.AudioDopplerFactor := Info.ParamAsFloat[2]
  else
    raise Exception.CreateFmt('Unknown object audio float property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoAudio3DModeNormal(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(b3dmNormal);
end;

procedure TdwsEngineUnit.DoAudio3DModeRelative(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(b3dmRelative);
end;

procedure TdwsEngineUnit.DoAudio3DModeOff(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(b3dmOff);
end;

procedure TdwsEngineUnit.DoAudioInitialized(Info: TProgramInfo);
begin
  Info.ResultAsBoolean := Assigned(FContext.AudioEngine) and FContext.AudioEngine.Initialized;
end;

procedure TdwsEngineUnit.DoAudioApply3D(Info: TProgramInfo);
begin
  if Assigned(FContext.AudioEngine) and FContext.AudioEngine.InitializedFor3D then
    FContext.AudioEngine.Apply3D;
end;

procedure TdwsEngineUnit.DoAudioMasterVolume(Info: TProgramInfo);
begin
  if Assigned(FContext.AudioEngine) and FContext.AudioEngine.Initialized then
    Info.ResultAsFloat := FContext.AudioEngine.MasterVolume
  else
    Info.ResultAsFloat := 0.0;
end;

procedure TdwsEngineUnit.DoAudioSetMasterVolume(Info: TProgramInfo);
begin
  if Assigned(FContext.AudioEngine) and FContext.AudioEngine.Initialized then
    FContext.AudioEngine.SetMasterVolume(EnsureRange(Info.ParamAsFloat[0], 0.0, 1.0));
end;

procedure TdwsEngineUnit.DoAudioEmitterBoolean(Info: TProgramInfo);
var
  Emitter: TSceneAudioEmitter;
  Name: string;
begin
  Emitter := FContext.AudioEmitterFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Enabled') then
    Info.ResultAsBoolean := Emitter.Enabled
  else if SameText(Name, 'AutoPlay') then
    Info.ResultAsBoolean := Emitter.AutoPlay
  else if SameText(Name, 'Loop') then
    Info.ResultAsBoolean := Emitter.Loop
  else if SameText(Name, 'Spatial') then
    Info.ResultAsBoolean := Emitter.Spatial
  else if SameText(Name, 'MutedAtMaxDistance') or SameText(Name, 'MuteAtMaxDistance') then
    Info.ResultAsBoolean := Emitter.MutedAtMaxDistance
  else
    raise Exception.CreateFmt('Unknown audio emitter boolean property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoAudioEmitterSetBoolean(Info: TProgramInfo);
var
  Emitter: TSceneAudioEmitter;
  Name: string;
begin
  Emitter := FContext.AudioEmitterFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Enabled') then
    Emitter.Enabled := Info.ParamAsBoolean[2]
  else if SameText(Name, 'AutoPlay') then
    Emitter.AutoPlay := Info.ParamAsBoolean[2]
  else if SameText(Name, 'Loop') then
    Emitter.Loop := Info.ParamAsBoolean[2]
  else if SameText(Name, 'Spatial') then
    Emitter.Spatial := Info.ParamAsBoolean[2]
  else if SameText(Name, 'MutedAtMaxDistance') or SameText(Name, 'MuteAtMaxDistance') then
    Emitter.MutedAtMaxDistance := Info.ParamAsBoolean[2]
  else
    raise Exception.CreateFmt('Unknown audio emitter boolean property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoAudioEmitterInteger(Info: TProgramInfo);
var
  Emitter: TSceneAudioEmitter;
  Name: string;
begin
  Emitter := FContext.AudioEmitterFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Mode') then
    Info.ResultAsInteger := Ord(Emitter.Mode)
  else if SameText(Name, 'InsideConeAngle') then
    Info.ResultAsInteger := Emitter.InsideConeAngle
  else if SameText(Name, 'OutsideConeAngle') then
    Info.ResultAsInteger := Emitter.OutsideConeAngle
  else if SameText(Name, 'OutsideVolume') then
    Info.ResultAsInteger := Emitter.OutsideVolume
  else
    raise Exception.CreateFmt('Unknown audio emitter integer property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoAudioEmitterSetInteger(Info: TProgramInfo);
var
  Emitter: TSceneAudioEmitter;
  Name: string;
begin
  Emitter := FContext.AudioEmitterFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Mode') then
    Emitter.Mode := TBass3DMode(EnsureRange(Info.ParamAsInteger[2], Ord(Low(TBass3DMode)), Ord(High(TBass3DMode))))
  else if SameText(Name, 'InsideConeAngle') then
    Emitter.InsideConeAngle := Info.ParamAsInteger[2]
  else if SameText(Name, 'OutsideConeAngle') then
    Emitter.OutsideConeAngle := Info.ParamAsInteger[2]
  else if SameText(Name, 'OutsideVolume') then
    Emitter.OutsideVolume := Info.ParamAsInteger[2]
  else
    raise Exception.CreateFmt('Unknown audio emitter integer property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoAudioEmitterFloat(Info: TProgramInfo);
var
  Emitter: TSceneAudioEmitter;
  Name: string;
begin
  Emitter := FContext.AudioEmitterFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Volume') then
    Info.ResultAsFloat := Emitter.Volume
  else if SameText(Name, 'MinDistance') then
    Info.ResultAsFloat := Emitter.MinDistance
  else if SameText(Name, 'MaxDistance') then
    Info.ResultAsFloat := Emitter.MaxDistance
  else
    raise Exception.CreateFmt('Unknown audio emitter float property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoAudioEmitterSetFloat(Info: TProgramInfo);
var
  Emitter: TSceneAudioEmitter;
  Name: string;
begin
  Emitter := FContext.AudioEmitterFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Volume') then
    Emitter.Volume := Info.ParamAsFloat[2]
  else if SameText(Name, 'MinDistance') then
    Emitter.MinDistance := Info.ParamAsFloat[2]
  else if SameText(Name, 'MaxDistance') then
    Emitter.MaxDistance := Info.ParamAsFloat[2]
  else
    raise Exception.CreateFmt('Unknown audio emitter float property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoAudioEmitterVector3(Info: TProgramInfo);
var
  Emitter: TSceneAudioEmitter;
  Name: string;
begin
  Emitter := FContext.AudioEmitterFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Offset') then
    SetResultVector3(Info, Emitter.Offset)
  else if SameText(Name, 'Velocity') then
    SetResultVector3(Info, Emitter.Velocity)
  else if SameText(Name, 'Orientation') then
    SetResultVector3(Info, Emitter.Orientation)
  else
    raise Exception.CreateFmt('Unknown audio emitter TVector3 property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoAudioEmitterSetVector3(Info: TProgramInfo);
var
  Emitter: TSceneAudioEmitter;
  Name: string;
  Value: TVector3;
begin
  Emitter := FContext.AudioEmitterFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  Value := ParamAsVector3(Info, 2);
  if SameText(Name, 'Offset') then
    Emitter.Offset := Value
  else if SameText(Name, 'Velocity') then
    Emitter.Velocity := Value
  else if SameText(Name, 'Orientation') then
    Emitter.Orientation := Value
  else
    raise Exception.CreateFmt('Unknown audio emitter TVector3 property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoAudioEmitterString(Info: TProgramInfo);
var
  Emitter: TSceneAudioEmitter;
  Name: string;
begin
  Emitter := FContext.AudioEmitterFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Name') then
    Info.ResultAsString := Emitter.Name
  else if SameText(Name, 'AudioPath') or SameText(Name, 'FileName') then
    Info.ResultAsString := Emitter.AudioPath
  else
    raise Exception.CreateFmt('Unknown audio emitter string property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoAudioEmitterSetString(Info: TProgramInfo);
var
  Emitter: TSceneAudioEmitter;
  Name: string;
begin
  Emitter := FContext.AudioEmitterFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Name') then
    Emitter.Name := Info.ParamAsString[2]
  else if SameText(Name, 'AudioPath') or SameText(Name, 'FileName') then
    Emitter.AudioPath := Info.ParamAsString[2]
  else
    raise Exception.CreateFmt('Unknown audio emitter string property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoObjectCreateLight(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.HandleOf(
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).CreateLight);
end;

procedure TdwsEngineUnit.DoObjectLightCount(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).LightsCount;
end;

procedure TdwsEngineUnit.DoObjectLight(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.HandleOf(
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).Light[Info.ParamAsInteger[1]]);
end;

procedure TdwsEngineUnit.DoLightFromHandle(Info: TProgramInfo);
begin
  SetResultLight(Info, FContext.LightFromHandle(Info.ParamAsInteger[0]));
end;

procedure TdwsEngineUnit.DoLightHandle(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.HandleOf(ParamAsLight(Info, 0));
end;

procedure TdwsEngineUnit.DoLightTypeDirectional(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(ltDirectional);
end;

procedure TdwsEngineUnit.DoLightTypePoint(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(ltPoint);
end;

procedure TdwsEngineUnit.DoLightTypeSpot(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(ltSpot);
end;

procedure TdwsEngineUnit.DoLightType(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(FContext.LightFromHandle(Info.ParamAsInteger[0]).LightType);
end;

procedure TdwsEngineUnit.DoLightSetType(Info: TProgramInfo);
var
  Value: Integer;
begin
  Value := EnsureRange(Info.ParamAsInteger[1], Ord(Low(TLightType)), Ord(High(TLightType)));
  FContext.LightFromHandle(Info.ParamAsInteger[0]).LightType := TLightType(Value);
end;

procedure TdwsEngineUnit.DoLightEnabled(Info: TProgramInfo);
begin
  Info.ResultAsBoolean := FContext.LightFromHandle(Info.ParamAsInteger[0]).Enabled;
end;

procedure TdwsEngineUnit.DoLightSetEnabled(Info: TProgramInfo);
begin
  FContext.LightFromHandle(Info.ParamAsInteger[0]).Enabled := Info.ParamAsBoolean[1];
end;

procedure TdwsEngineUnit.DoLightDiffuse(Info: TProgramInfo);
begin
  SetResultVector3(Info, FContext.LightFromHandle(Info.ParamAsInteger[0]).Diffuse);
end;

procedure TdwsEngineUnit.DoLightSetDiffuse(Info: TProgramInfo);
begin
  FContext.LightFromHandle(Info.ParamAsInteger[0]).Diffuse := ParamAsVector3(Info, 1);
end;

procedure TdwsEngineUnit.DoLightAmbient(Info: TProgramInfo);
begin
  SetResultVector3(Info, FContext.LightFromHandle(Info.ParamAsInteger[0]).Ambient);
end;

procedure TdwsEngineUnit.DoLightSetAmbient(Info: TProgramInfo);
begin
  FContext.LightFromHandle(Info.ParamAsInteger[0]).Ambient := ParamAsVector3(Info, 1);
end;

procedure TdwsEngineUnit.DoLightSpecular(Info: TProgramInfo);
begin
  SetResultVector3(Info, FContext.LightFromHandle(Info.ParamAsInteger[0]).Specular);
end;

procedure TdwsEngineUnit.DoLightSetSpecular(Info: TProgramInfo);
begin
  FContext.LightFromHandle(Info.ParamAsInteger[0]).Specular := ParamAsVector3(Info, 1);
end;

procedure TdwsEngineUnit.DoLightPosition(Info: TProgramInfo);
begin
  SetResultVector3(Info, FContext.LightFromHandle(Info.ParamAsInteger[0]).Position);
end;

procedure TdwsEngineUnit.DoLightSetPosition(Info: TProgramInfo);
begin
  FContext.LightFromHandle(Info.ParamAsInteger[0]).Position := ParamAsVector3(Info, 1);
end;

procedure TdwsEngineUnit.DoLightDirection(Info: TProgramInfo);
begin
  SetResultVector3(Info, FContext.LightFromHandle(Info.ParamAsInteger[0]).Direction);
end;

procedure TdwsEngineUnit.DoLightSetDirection(Info: TProgramInfo);
begin
  FContext.LightFromHandle(Info.ParamAsInteger[0]).Direction := ParamAsVector3(Info, 1);
end;

procedure TdwsEngineUnit.DoLightSetAttenuation(Info: TProgramInfo);
var
  Light: TLight;
begin
  Light := FContext.LightFromHandle(Info.ParamAsInteger[0]);
  Light.ConstantAttenuation := Info.ParamAsFloat[1];
  Light.LinearAttenuation := Info.ParamAsFloat[2];
  Light.QuadraticAttenuation := Info.ParamAsFloat[3];
end;

procedure TdwsEngineUnit.DoLightSetSpot(Info: TProgramInfo);
var
  Light: TLight;
begin
  Light := FContext.LightFromHandle(Info.ParamAsInteger[0]);
  Light.SpotCutoff := DegToRad(Info.ParamAsFloat[1]);
  Light.SpotExponent := Info.ParamAsFloat[2];
end;

procedure TdwsEngineUnit.DoLightCastShadows(Info: TProgramInfo);
begin
  Info.ResultAsBoolean := FContext.LightFromHandle(Info.ParamAsInteger[0]).CastShadows;
end;

procedure TdwsEngineUnit.DoLightSetCastShadows(Info: TProgramInfo);
begin
  FContext.LightFromHandle(Info.ParamAsInteger[0]).CastShadows := Info.ParamAsBoolean[1];
end;

procedure TdwsEngineUnit.DoLightShadowStrength(Info: TProgramInfo);
begin
  Info.ResultAsFloat := FContext.LightFromHandle(Info.ParamAsInteger[0]).ShadowStrength;
end;

procedure TdwsEngineUnit.DoLightSetShadowStrength(Info: TProgramInfo);
begin
  FContext.LightFromHandle(Info.ParamAsInteger[0]).ShadowStrength :=
    EnsureRange(Info.ParamAsFloat[1], 0.0, 1.0);
end;

procedure TdwsEngineUnit.DoObjectCreateCamera(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.HandleOf(
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).CreateCamera);
end;

procedure TdwsEngineUnit.DoObjectCamera(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.HandleOf(
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]).Camera);
end;

procedure TdwsEngineUnit.DoCameraLookAt(Info: TProgramInfo);
begin
  FContext.CameraFromHandle(Info.ParamAsInteger[0]).LookAt(
    ParamAsVector3(Info, 1), ParamAsVector3(Info, 2), ParamAsVector3(Info, 3));
end;

procedure TdwsEngineUnit.DoCameraMoveForward(Info: TProgramInfo);
begin
  FContext.CameraFromHandle(Info.ParamAsInteger[0]).MoveForward(Info.ParamAsFloat[1]);
end;

procedure TdwsEngineUnit.DoCameraMoveRight(Info: TProgramInfo);
begin
  FContext.CameraFromHandle(Info.ParamAsInteger[0]).MoveRight(Info.ParamAsFloat[1]);
end;

procedure TdwsEngineUnit.DoCameraMoveUp(Info: TProgramInfo);
begin
  FContext.CameraFromHandle(Info.ParamAsInteger[0]).MoveUp(Info.ParamAsFloat[1]);
end;

procedure TdwsEngineUnit.DoCameraRotateYaw(Info: TProgramInfo);
begin
  FContext.CameraFromHandle(Info.ParamAsInteger[0]).RotateYaw(Info.ParamAsFloat[1]);
end;

procedure TdwsEngineUnit.DoCameraRotatePitch(Info: TProgramInfo);
begin
  FContext.CameraFromHandle(Info.ParamAsInteger[0]).RotatePitch(Info.ParamAsFloat[1]);
end;

procedure TdwsEngineUnit.DoCameraPosition(Info: TProgramInfo);
begin
  SetResultVector3(Info, FContext.CameraFromHandle(Info.ParamAsInteger[0]).Position);
end;

procedure TdwsEngineUnit.DoCameraTarget(Info: TProgramInfo);
begin
  SetResultVector3(Info, FContext.CameraFromHandle(Info.ParamAsInteger[0]).Target);
end;

procedure TdwsEngineUnit.DoCameraViewMatrix(Info: TProgramInfo);
begin
  SetResultMatrix4(Info, FContext.CameraFromHandle(Info.ParamAsInteger[0]).ViewMatrix);
end;

procedure TdwsEngineUnit.DoCameraViewProjectionMatrix(Info: TProgramInfo);
var
  Projection: TMatrix4;
begin
  if Assigned(FContext.Renderer) then
    Projection := FContext.Renderer.ProjectionMatrix
  else
    Projection := TMatrix4.Identity;

  SetResultMatrix4(Info,
    Projection * FContext.CameraFromHandle(Info.ParamAsInteger[0]).ViewMatrix);
end;

procedure TdwsEngineUnit.DoMaterialCount(Info: TProgramInfo);
begin
  if Assigned(FContext.MaterialLibrary) then
    Info.ResultAsInteger := FContext.MaterialLibrary.Count
  else
    Info.ResultAsInteger := 0;
end;

procedure TdwsEngineUnit.DoMaterialName(Info: TProgramInfo);
var
  Mat: TMaterial;
begin
  Mat := nil;
  if Assigned(FContext.MaterialLibrary) then
    Mat := FContext.MaterialLibrary.GetMaterial(Info.ParamAsInteger[0]);

  if Assigned(Mat) then
    Info.ResultAsString := Mat.Name
  else
    Info.ResultAsString := '';
end;

procedure TdwsEngineUnit.DoMaterialByName(Info: TProgramInfo);
var
  Mat: TMaterial;
begin
  Mat := nil;
  if Assigned(FContext.MaterialLibrary) then
    Mat := FContext.MaterialLibrary.GetMaterial(Info.ParamAsString[0]);
  Info.ResultAsInteger := FContext.HandleOf(Mat);
end;

procedure TdwsEngineUnit.DoMaterialByNameObject(Info: TProgramInfo);
var
  Mat: TMaterial;
begin
  Mat := nil;
  if Assigned(FContext.MaterialLibrary) then
    Mat := FContext.MaterialLibrary.GetMaterial(Info.ParamAsString[0]);
  SetResultMaterial(Info, Mat);
end;

procedure TdwsEngineUnit.DoMaterialFromHandle(Info: TProgramInfo);
begin
  SetResultMaterial(Info, FContext.MaterialFromHandle(Info.ParamAsInteger[0]));
end;

procedure TdwsEngineUnit.DoMaterialHandle(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.HandleOf(ParamAsMaterial(Info, 0));
end;

procedure TdwsEngineUnit.DoMaterialShaderParameter(Info: TProgramInfo);
begin
  Info.ResultAsFloat := GetMaterialShaderParameter(
    FContext.MaterialFromHandle(Info.ParamAsInteger[0]), Info.ParamAsString[1]);
end;

procedure TdwsEngineUnit.DoMaterialSetShaderParameter(Info: TProgramInfo);
begin
  SetMaterialShaderParameter(FContext.MaterialFromHandle(Info.ParamAsInteger[0]),
    Info.ParamAsString[1], Info.ParamAsFloat[2]);
end;

procedure TdwsEngineUnit.DoShaderFromHandle(Info: TProgramInfo);
begin
  SetResultShader(Info, FContext.ShaderFromHandle(Info.ParamAsInteger[0]));
end;

procedure TdwsEngineUnit.DoShaderHandle(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.HandleOf(ParamAsShader(Info, 0));
end;

procedure TdwsEngineUnit.DoShaderVertexPath(Info: TProgramInfo);
begin
  Info.ResultAsString := FContext.ShaderFromHandle(Info.ParamAsInteger[0]).VertexPath;
end;

procedure TdwsEngineUnit.DoShaderFragmentPath(Info: TProgramInfo);
begin
  Info.ResultAsString := FContext.ShaderFromHandle(Info.ParamAsInteger[0]).FragmentPath;
end;

procedure TdwsEngineUnit.DoShaderUse(Info: TProgramInfo);
begin
  FContext.ShaderFromHandle(Info.ParamAsInteger[0]).Use;
end;

procedure TdwsEngineUnit.DoShaderReload(Info: TProgramInfo);
begin
  FContext.ShaderFromHandle(Info.ParamAsInteger[0]).Reload;
end;

procedure TdwsEngineUnit.DoShaderSetUniformBoolean(Info: TProgramInfo);
begin
  FContext.ShaderFromHandle(Info.ParamAsInteger[0]).SetUniform(
    Info.ParamAsString[1], Info.ParamAsBoolean[2]);
end;

procedure TdwsEngineUnit.DoShaderSetUniformInteger(Info: TProgramInfo);
begin
  FContext.ShaderFromHandle(Info.ParamAsInteger[0]).SetUniform(
    Info.ParamAsString[1], Info.ParamAsInteger[2]);
end;

procedure TdwsEngineUnit.DoShaderSetUniformFloat(Info: TProgramInfo);
begin
  FContext.ShaderFromHandle(Info.ParamAsInteger[0]).SetUniform(
    Info.ParamAsString[1], Info.ParamAsFloat[2]);
end;

procedure TdwsEngineUnit.DoShaderSetUniformVector3(Info: TProgramInfo);
begin
  FContext.ShaderFromHandle(Info.ParamAsInteger[0]).SetUniform(
    Info.ParamAsString[1], ParamAsVector3(Info, 2));
end;

procedure TdwsEngineUnit.DoShaderSetUniformVector4(Info: TProgramInfo);
begin
  FContext.ShaderFromHandle(Info.ParamAsInteger[0]).SetUniform(
    Info.ParamAsString[1], ParamAsVector4(Info, 2));
end;

procedure TdwsEngineUnit.DoShaderSetUniformMatrix4(Info: TProgramInfo);
begin
  FContext.ShaderFromHandle(Info.ParamAsInteger[0]).SetUniform(
    Info.ParamAsString[1], ParamAsMatrix4(Info, 2));
end;

procedure TdwsEngineUnit.DoRendererProjectionMatrix(Info: TProgramInfo);
begin
  if Assigned(FContext.Renderer) then
    SetResultMatrix4(Info, FContext.Renderer.ProjectionMatrix)
  else
    SetResultMatrix4(Info, TMatrix4.Identity);
end;

procedure TdwsEngineUnit.DoRendererViewMatrix(Info: TProgramInfo);
begin
  if Assigned(FContext.Renderer) and Assigned(FContext.Renderer.ActiveCamera) and
     Assigned(FContext.Renderer.ActiveCamera.Camera) then
    SetResultMatrix4(Info, FContext.Renderer.ActiveCamera.Camera.ViewMatrix)
  else
    SetResultMatrix4(Info, TMatrix4.Identity);
end;

procedure TdwsEngineUnit.DoRendererViewProjectionMatrix(Info: TProgramInfo);
begin
  if Assigned(FContext.Renderer) and Assigned(FContext.Renderer.ActiveCamera) and
     Assigned(FContext.Renderer.ActiveCamera.Camera) then
    SetResultMatrix4(Info,
      FContext.Renderer.ProjectionMatrix *
      FContext.Renderer.ActiveCamera.Camera.ViewMatrix)
  else
    SetResultMatrix4(Info, TMatrix4.Identity);
end;

procedure TdwsEngineUnit.DoRendererShadowLightViewProjection(Info: TProgramInfo);
begin
  if Assigned(FContext.Renderer) then
    SetResultMatrix4(Info, FContext.Renderer.ShadowLightViewProjection)
  else
    SetResultMatrix4(Info, TMatrix4.Identity);
end;

procedure TdwsEngineUnit.DoRendererShadowLightMatrix(Info: TProgramInfo);
begin
  if Assigned(FContext.Renderer) then
    SetResultMatrix4(Info,
      FContext.Renderer.ShadowLightMatrixForLightIndex(Info.ParamAsInteger[0]))
  else
    SetResultMatrix4(Info, TMatrix4.Identity);
end;

procedure TdwsEngineUnit.DoRendererSetBackgroundColor(Info: TProgramInfo);
begin
  if Assigned(FContext.Renderer) then
    FContext.Renderer.BackgroundColor := ParamAsVector4(Info, 0);
end;

procedure TdwsEngineUnit.DoRendererSetShadowEnabled(Info: TProgramInfo);
begin
  if Assigned(FContext.Renderer) then
    FContext.Renderer.ShadowEnabled := Info.ParamAsBoolean[0];
end;

procedure TdwsEngineUnit.DoRendererSetShadowTarget(Info: TProgramInfo);
begin
  if Assigned(FContext.Renderer) then
    FContext.Renderer.ShadowTarget := ParamAsVector3(Info, 0);
end;

procedure TdwsEngineUnit.DoRendererSetShadowDistance(Info: TProgramInfo);
begin
  if Assigned(FContext.Renderer) then
    FContext.Renderer.ShadowDistance := Max(0.1, Info.ParamAsFloat[0]);
end;

procedure TdwsEngineUnit.DoRendererSetShadowArea(Info: TProgramInfo);
begin
  if Assigned(FContext.Renderer) then
    FContext.Renderer.ShadowArea := Max(0.1, Info.ParamAsFloat[0]);
end;

procedure TdwsEngineUnit.DoRendererSetShadowMapSize(Info: TProgramInfo);
begin
  if Assigned(FContext.Renderer) then
    FContext.Renderer.SetupShadowMap(Max(64, Info.ParamAsInteger[0]));
end;

procedure TdwsEngineUnit.DoSkyDomeResetDefaults(Info: TProgramInfo);
begin
  RequireSkyDome.ResetEarthDefaults;
end;

procedure TdwsEngineUnit.DoSkyDomeBoolean(Info: TProgramInfo);
var
  Sky: TSkyDome;
  Name: string;
begin
  Sky := RequireSkyDome;
  Name := Info.ParamAsString[0];

  if SameText(Name, 'Enabled') then
    Info.ResultAsBoolean := Sky.Enabled
  else if SameText(Name, 'AnimateClouds') then
    Info.ResultAsBoolean := Sky.AnimateClouds
  else if SameText(Name, 'TwinkleStars') then
    Info.ResultAsBoolean := Sky.TwinkleStars
  else if SameText(Name, 'CloudsEnabled') then
    Info.ResultAsBoolean := Sky.CloudsEnabled
  else
    raise Exception.CreateFmt('Unknown SkyDome Boolean property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoSkyDomeSetBoolean(Info: TProgramInfo);
var
  Sky: TSkyDome;
  Name: string;
  Value: Boolean;
begin
  Sky := RequireSkyDome;
  Name := Info.ParamAsString[0];
  Value := Info.ParamAsBoolean[1];

  if SameText(Name, 'Enabled') then
    Sky.Enabled := Value
  else if SameText(Name, 'AnimateClouds') then
    Sky.AnimateClouds := Value
  else if SameText(Name, 'TwinkleStars') then
    Sky.TwinkleStars := Value
  else if SameText(Name, 'CloudsEnabled') then
    Sky.CloudsEnabled := Value
  else
    raise Exception.CreateFmt('Unknown SkyDome Boolean property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoSkyDomeInteger(Info: TProgramInfo);
var
  Sky: TSkyDome;
  Name: string;
begin
  Sky := RequireSkyDome;
  Name := Info.ParamAsString[0];

  if SameText(Name, 'Slices') then
    Info.ResultAsInteger := Sky.Slices
  else if SameText(Name, 'Stacks') then
    Info.ResultAsInteger := Sky.Stacks
  else
    raise Exception.CreateFmt('Unknown SkyDome Integer property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoSkyDomeSetInteger(Info: TProgramInfo);
var
  Sky: TSkyDome;
  Name: string;
begin
  Sky := RequireSkyDome;
  Name := Info.ParamAsString[0];

  if SameText(Name, 'Slices') then
    Sky.Slices := Info.ParamAsInteger[1]
  else if SameText(Name, 'Stacks') then
    Sky.Stacks := Info.ParamAsInteger[1]
  else
    raise Exception.CreateFmt('Unknown SkyDome Integer property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoSkyDomeFloat(Info: TProgramInfo);
var
  Sky: TSkyDome;
  Name: string;
begin
  Sky := RequireSkyDome;
  Name := Info.ParamAsString[0];

  if SameText(Name, 'Radius') then
    Info.ResultAsFloat := Sky.Radius
  else if SameText(Name, 'Time') then
    Info.ResultAsFloat := Sky.Time
  else if SameText(Name, 'SunSize') then
    Info.ResultAsFloat := Sky.SunSize
  else if SameText(Name, 'SunGlow') then
    Info.ResultAsFloat := Sky.SunGlow
  else if SameText(Name, 'SunIntensity') then
    Info.ResultAsFloat := Sky.SunIntensity
  else if SameText(Name, 'StarIntensity') then
    Info.ResultAsFloat := Sky.StarIntensity
  else if SameText(Name, 'StarDensity') then
    Info.ResultAsFloat := Sky.StarDensity
  else if SameText(Name, 'StarGlare') then
    Info.ResultAsFloat := Sky.StarGlare
  else if SameText(Name, 'StarSizeMin') or SameText(Name, 'StarSizeX') then
    Info.ResultAsFloat := Sky.StarSize.X
  else if SameText(Name, 'StarSizeMax') or SameText(Name, 'StarSizeY') then
    Info.ResultAsFloat := Sky.StarSize.Y
  else if SameText(Name, 'CloudCoverage') then
    Info.ResultAsFloat := Sky.CloudCoverage
  else if SameText(Name, 'CloudScale') then
    Info.ResultAsFloat := Sky.CloudScale
  else if SameText(Name, 'CloudSpeed') then
    Info.ResultAsFloat := Sky.CloudSpeed
  else if SameText(Name, 'CloudOpacity') then
    Info.ResultAsFloat := Sky.CloudOpacity
  else
    raise Exception.CreateFmt('Unknown SkyDome Float property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoSkyDomeSetFloat(Info: TProgramInfo);
var
  Sky: TSkyDome;
  Name: string;
  Value: Single;
begin
  Sky := RequireSkyDome;
  Name := Info.ParamAsString[0];
  Value := Info.ParamAsFloat[1];

  if SameText(Name, 'Radius') then
    Sky.Radius := Max(1.0, Value)
  else if SameText(Name, 'Time') then
    Sky.Time := Max(0.0, Value)
  else if SameText(Name, 'SunSize') then
    Sky.SunSize := Max(0.001, Value)
  else if SameText(Name, 'SunGlow') then
    Sky.SunGlow := Max(1.0, Value)
  else if SameText(Name, 'SunIntensity') then
    Sky.SunIntensity := Max(0.0, Value)
  else if SameText(Name, 'StarIntensity') then
    Sky.StarIntensity := Max(0.0, Value)
  else if SameText(Name, 'StarDensity') then
    Sky.StarDensity := Max(8.0, Value)
  else if SameText(Name, 'StarGlare') then
    Sky.StarGlare := Max(0.0, Value)
  else if SameText(Name, 'StarSizeMin') or SameText(Name, 'StarSizeX') then
    Sky.StarSize := Vector2(Value, Sky.StarSize.Y)
  else if SameText(Name, 'StarSizeMax') or SameText(Name, 'StarSizeY') then
    Sky.StarSize := Vector2(Sky.StarSize.X, Value)
  else if SameText(Name, 'CloudCoverage') then
    Sky.CloudCoverage := EnsureRange(Value, 0.0, 1.0)
  else if SameText(Name, 'CloudScale') then
    Sky.CloudScale := Max(0.01, Value)
  else if SameText(Name, 'CloudSpeed') then
    Sky.CloudSpeed := Value
  else if SameText(Name, 'CloudOpacity') then
    Sky.CloudOpacity := EnsureRange(Value, 0.0, 1.0)
  else
    raise Exception.CreateFmt('Unknown SkyDome Float property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoSkyDomeVector3(Info: TProgramInfo);
var
  Sky: TSkyDome;
  Name: string;
begin
  Sky := RequireSkyDome;
  Name := Info.ParamAsString[0];

  if SameText(Name, 'SunDirection') then
    SetResultVector3(Info, Sky.SunDirection)
  else
    raise Exception.CreateFmt('Unknown SkyDome TVector3 property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoSkyDomeSetVector3(Info: TProgramInfo);
var
  Sky: TSkyDome;
  Name: string;
begin
  Sky := RequireSkyDome;
  Name := Info.ParamAsString[0];

  if SameText(Name, 'SunDirection') then
    Sky.SunDirection := ParamAsVector3(Info, 1)
  else
    raise Exception.CreateFmt('Unknown SkyDome TVector3 property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoSkyDomeVector4(Info: TProgramInfo);
var
  Sky: TSkyDome;
  Name: string;
begin
  Sky := RequireSkyDome;
  Name := Info.ParamAsString[0];

  if SameText(Name, 'TopColor') then
    SetResultVector4(Info, Sky.TopColor)
  else if SameText(Name, 'HorizonColor') then
    SetResultVector4(Info, Sky.HorizonColor)
  else if SameText(Name, 'BottomColor') then
    SetResultVector4(Info, Sky.BottomColor)
  else if SameText(Name, 'NightColor') then
    SetResultVector4(Info, Sky.NightColor)
  else if SameText(Name, 'SunColor') then
    SetResultVector4(Info, Sky.SunColor)
  else if SameText(Name, 'CloudColor') then
    SetResultVector4(Info, Sky.CloudColor)
  else
    raise Exception.CreateFmt('Unknown SkyDome TVector4 property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoSkyDomeSetVector4(Info: TProgramInfo);
var
  Sky: TSkyDome;
  Name: string;
  Value: TVector4;
begin
  Sky := RequireSkyDome;
  Name := Info.ParamAsString[0];
  Value := ParamAsVector4(Info, 1);

  if SameText(Name, 'TopColor') then
    Sky.TopColor := Value
  else if SameText(Name, 'HorizonColor') then
    Sky.HorizonColor := Value
  else if SameText(Name, 'BottomColor') then
    Sky.BottomColor := Value
  else if SameText(Name, 'NightColor') then
    Sky.NightColor := Value
  else if SameText(Name, 'SunColor') then
    Sky.SunColor := Value
  else if SameText(Name, 'CloudColor') then
    Sky.CloudColor := Value
  else
    raise Exception.CreateFmt('Unknown SkyDome TVector4 property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoPhysicsBodyStatic(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(pbtStatic);
end;

procedure TdwsEngineUnit.DoPhysicsBodyDynamic(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(pbtDynamic);
end;

procedure TdwsEngineUnit.DoPhysicsBodyKinematic(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(pbtKinematic);
end;

procedure TdwsEngineUnit.DoPhysicsBodyCharacter(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(pbtCharacter);
end;

procedure TdwsEngineUnit.DoPhysicsBodyProjectile(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(pbtProjectile);
end;

procedure TdwsEngineUnit.DoPhysicsColliderAuto(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(pckAuto);
end;

procedure TdwsEngineUnit.DoPhysicsColliderNone(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(pckNone);
end;

procedure TdwsEngineUnit.DoPhysicsColliderSphere(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(pckSphere);
end;

procedure TdwsEngineUnit.DoPhysicsColliderCapsule(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(pckCapsule);
end;

procedure TdwsEngineUnit.DoPhysicsColliderAABB(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(pckAABB);
end;

procedure TdwsEngineUnit.DoPhysicsColliderMesh(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(pckMesh);
end;

procedure TdwsEngineUnit.DoPhysicsColliderConvexHull(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(pckConvexHull);
end;

procedure TdwsEngineUnit.DoPhysicsBodyCount(Info: TProgramInfo);
begin
  if Assigned(FContext.PhysicsWorld) then
    Info.ResultAsInteger := FContext.PhysicsWorld.BodyCount
  else
    Info.ResultAsInteger := 0;
end;

procedure TdwsEngineUnit.DoPhysicsBody(Info: TProgramInfo);
begin
  if Assigned(FContext.PhysicsWorld) then
    Info.ResultAsInteger := FContext.HandleOf(FContext.PhysicsWorld.Bodies[Info.ParamAsInteger[0]])
  else
    Info.ResultAsInteger := 0;
end;

procedure TdwsEngineUnit.DoPhysicsFindBody(Info: TProgramInfo);
begin
  if Assigned(FContext.PhysicsWorld) then
    Info.ResultAsInteger := FContext.HandleOf(
      FContext.PhysicsWorld.FindBody(FContext.SceneObjectFromHandle(Info.ParamAsInteger[0])))
  else
    Info.ResultAsInteger := 0;
end;

procedure TdwsEngineUnit.DoPhysicsAddBody(Info: TProgramInfo);
var
  BodyTypeValue, ColliderValue: Integer;
begin
  if not Assigned(FContext.PhysicsWorld) then
  begin
    Info.ResultAsInteger := 0;
    Exit;
  end;

  BodyTypeValue := EnsureRange(Info.ParamAsInteger[1], Ord(Low(TPhysicsBodyType)), Ord(High(TPhysicsBodyType)));
  ColliderValue := EnsureRange(Info.ParamAsInteger[2], Ord(Low(TPhysicsColliderKind)), Ord(High(TPhysicsColliderKind)));
  Info.ResultAsInteger := FContext.HandleOf(FContext.PhysicsWorld.AddBody(
    FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]),
    TPhysicsBodyType(BodyTypeValue), TPhysicsColliderKind(ColliderValue)));
end;

procedure TdwsEngineUnit.DoPhysicsRemoveBody(Info: TProgramInfo);
var
  Body: TPhysicsBody;
begin
  if not Assigned(FContext.PhysicsWorld) then
    Exit;
  Body := FContext.PhysicsBodyFromHandle(Info.ParamAsInteger[0]);
  FContext.Forget(Body);
  FContext.PhysicsWorld.RemoveBody(Body);
end;

procedure TdwsEngineUnit.DoPhysicsRemoveBodyForObject(Info: TProgramInfo);
var
  Body: TPhysicsBody;
  Obj: TSceneObject;
begin
  if not Assigned(FContext.PhysicsWorld) then
    Exit;
  Obj := FContext.SceneObjectFromHandle(Info.ParamAsInteger[0]);
  Body := FContext.PhysicsWorld.FindBody(Obj);
  FContext.Forget(Body);
  FContext.PhysicsWorld.RemoveBodyForObject(Obj);
end;

procedure TdwsEngineUnit.DoPhysicsClear(Info: TProgramInfo);
var
  I: Integer;
begin
  if Assigned(FContext.PhysicsWorld) then
  begin
    for I := 0 to FContext.PhysicsWorld.BodyCount - 1 do
      FContext.Forget(FContext.PhysicsWorld.Bodies[I]);
    FContext.PhysicsWorld.Clear;
  end;
end;

procedure TdwsEngineUnit.DoPhysicsStep(Info: TProgramInfo);
begin
  if Assigned(FContext.PhysicsWorld) then
    FContext.PhysicsWorld.Step(Max(0.0, Info.ParamAsFloat[0]));
end;

procedure TdwsEngineUnit.DoPhysicsEnsureNativeScene(Info: TProgramInfo);
begin
  if Assigned(FContext.PhysicsWorld) then
    FContext.PhysicsWorld.EnsureNativeScene;
end;

procedure TdwsEngineUnit.DoPhysicsGravity(Info: TProgramInfo);
begin
  if Assigned(FContext.PhysicsWorld) then
    SetResultVector3(Info, FContext.PhysicsWorld.Gravity)
  else
    SetResultVector3(Info, Vector3(0, 0, 0));
end;

procedure TdwsEngineUnit.DoPhysicsSetGravity(Info: TProgramInfo);
begin
  if Assigned(FContext.PhysicsWorld) then
    FContext.PhysicsWorld.Gravity := ParamAsVector3(Info, 0);
end;

procedure TdwsEngineUnit.DoPhysicsGroundPlaneEnabled(Info: TProgramInfo);
begin
  Info.ResultAsBoolean := Assigned(FContext.PhysicsWorld) and FContext.PhysicsWorld.GroundPlaneEnabled;
end;

procedure TdwsEngineUnit.DoPhysicsSetGroundPlaneEnabled(Info: TProgramInfo);
begin
  if Assigned(FContext.PhysicsWorld) then
    FContext.PhysicsWorld.GroundPlaneEnabled := Info.ParamAsBoolean[0];
end;

procedure TdwsEngineUnit.DoPhysicsGroundHeight(Info: TProgramInfo);
begin
  if Assigned(FContext.PhysicsWorld) then
    Info.ResultAsFloat := FContext.PhysicsWorld.GroundHeight
  else
    Info.ResultAsFloat := 0.0;
end;

procedure TdwsEngineUnit.DoPhysicsSetGroundHeight(Info: TProgramInfo);
begin
  if Assigned(FContext.PhysicsWorld) then
    FContext.PhysicsWorld.GroundHeight := Info.ParamAsFloat[0];
end;

procedure TdwsEngineUnit.DoPhysicsApplyRadialImpulse(Info: TProgramInfo);
begin
  if Assigned(FContext.PhysicsWorld) then
    FContext.PhysicsWorld.ApplyRadialImpulse(ParamAsVector3(Info, 0),
      Max(0.0, Info.ParamAsFloat[1]), Info.ParamAsFloat[2], Info.ParamAsBoolean[3]);
end;

procedure TdwsEngineUnit.DoPhysicsRaycastHit(Info: TProgramInfo);
var
  Hit: TPhysicsHit;
begin
  Info.ResultAsBoolean := Assigned(FContext.PhysicsWorld) and
    FContext.PhysicsWorld.Raycast(ParamAsVector3(Info, 0), ParamAsVector3(Info, 1),
      Max(0.0, Info.ParamAsFloat[2]), Hit);
end;

procedure TdwsEngineUnit.DoPhysicsRaycastPoint(Info: TProgramInfo);
var
  Hit: TPhysicsHit;
begin
  if Assigned(FContext.PhysicsWorld) and
    FContext.PhysicsWorld.Raycast(ParamAsVector3(Info, 0), ParamAsVector3(Info, 1),
      Max(0.0, Info.ParamAsFloat[2]), Hit) then
    SetResultVector3(Info, Hit.Point)
  else
    SetResultVector3(Info, Vector3(0, 0, 0));
end;

procedure TdwsEngineUnit.DoPhysicsRaycastNormal(Info: TProgramInfo);
var
  Hit: TPhysicsHit;
begin
  if Assigned(FContext.PhysicsWorld) and
    FContext.PhysicsWorld.Raycast(ParamAsVector3(Info, 0), ParamAsVector3(Info, 1),
      Max(0.0, Info.ParamAsFloat[2]), Hit) then
    SetResultVector3(Info, Hit.Normal)
  else
    SetResultVector3(Info, Vector3(0, 0, 0));
end;

procedure TdwsEngineUnit.DoPhysicsRaycastBody(Info: TProgramInfo);
var
  Hit: TPhysicsHit;
begin
  if Assigned(FContext.PhysicsWorld) and
    FContext.PhysicsWorld.Raycast(ParamAsVector3(Info, 0), ParamAsVector3(Info, 1),
      Max(0.0, Info.ParamAsFloat[2]), Hit) then
    Info.ResultAsInteger := FContext.HandleOf(Hit.Body)
  else
    Info.ResultAsInteger := 0;
end;

procedure TdwsEngineUnit.DoPhysicsBodyObject(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FContext.HandleOf(
    FContext.PhysicsBodyFromHandle(Info.ParamAsInteger[0]).SceneObject);
end;

procedure TdwsEngineUnit.DoPhysicsBodyType(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(FContext.PhysicsBodyFromHandle(Info.ParamAsInteger[0]).BodyType);
end;

procedure TdwsEngineUnit.DoPhysicsBodySetType(Info: TProgramInfo);
var
  Value: Integer;
begin
  Value := EnsureRange(Info.ParamAsInteger[1], Ord(Low(TPhysicsBodyType)), Ord(High(TPhysicsBodyType)));
  FContext.PhysicsBodyFromHandle(Info.ParamAsInteger[0]).BodyType := TPhysicsBodyType(Value);
end;

procedure TdwsEngineUnit.DoPhysicsBodyColliderKind(Info: TProgramInfo);
begin
  Info.ResultAsInteger := Ord(FContext.PhysicsBodyFromHandle(Info.ParamAsInteger[0]).ColliderKind);
end;

procedure TdwsEngineUnit.DoPhysicsBodySetColliderKind(Info: TProgramInfo);
var
  Value: Integer;
begin
  Value := EnsureRange(Info.ParamAsInteger[1], Ord(Low(TPhysicsColliderKind)), Ord(High(TPhysicsColliderKind)));
  FContext.PhysicsBodyFromHandle(Info.ParamAsInteger[0]).ColliderKind := TPhysicsColliderKind(Value);
end;

procedure TdwsEngineUnit.DoPhysicsBodyBoolean(Info: TProgramInfo);
var
  Body: TPhysicsBody;
  Name: string;
begin
  Body := FContext.PhysicsBodyFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Enabled') then
    Info.ResultAsBoolean := Body.Enabled
  else if SameText(Name, 'CollisionResponse') then
    Info.ResultAsBoolean := Body.CollisionResponse
  else if SameText(Name, 'UseGravity') then
    Info.ResultAsBoolean := Body.UseGravity
  else if SameText(Name, 'IsGrounded') or SameText(Name, 'Grounded') then
    Info.ResultAsBoolean := Body.IsGrounded
  else if SameText(Name, 'Sleeping') then
    Info.ResultAsBoolean := Body.Sleeping
  else if SameText(Name, 'HasContact') then
    Info.ResultAsBoolean := Body.HasContact
  else
    raise Exception.CreateFmt('Unknown physics body boolean property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoPhysicsBodySetBoolean(Info: TProgramInfo);
var
  Body: TPhysicsBody;
  Name: string;
begin
  Body := FContext.PhysicsBodyFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Enabled') then
    Body.Enabled := Info.ParamAsBoolean[2]
  else if SameText(Name, 'CollisionResponse') then
    Body.CollisionResponse := Info.ParamAsBoolean[2]
  else if SameText(Name, 'UseGravity') then
    Body.UseGravity := Info.ParamAsBoolean[2]
  else
    raise Exception.CreateFmt('Unknown writable physics body boolean property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoPhysicsBodyFloat(Info: TProgramInfo);
var
  Body: TPhysicsBody;
  Name: string;
begin
  Body := FContext.PhysicsBodyFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Mass') then
    Info.ResultAsFloat := Body.Mass
  else if SameText(Name, 'InverseMass') then
    Info.ResultAsFloat := Body.InverseMass
  else if SameText(Name, 'Restitution') then
    Info.ResultAsFloat := Body.Restitution
  else if SameText(Name, 'LinearDamping') then
    Info.ResultAsFloat := Body.LinearDamping
  else if SameText(Name, 'GravityScale') then
    Info.ResultAsFloat := Body.GravityScale
  else if SameText(Name, 'AngularDamping') then
    Info.ResultAsFloat := Body.AngularDamping
  else if SameText(Name, 'Radius') then
    Info.ResultAsFloat := Body.Radius
  else if SameText(Name, 'HalfHeight') then
    Info.ResultAsFloat := Body.HalfHeight
  else if SameText(Name, 'StepHeight') then
    Info.ResultAsFloat := Body.StepHeight
  else
    raise Exception.CreateFmt('Unknown physics body float property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoPhysicsBodySetFloat(Info: TProgramInfo);
var
  Body: TPhysicsBody;
  Name: string;
begin
  Body := FContext.PhysicsBodyFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Mass') then
    Body.Mass := Info.ParamAsFloat[2]
  else if SameText(Name, 'Restitution') then
    Body.Restitution := Info.ParamAsFloat[2]
  else if SameText(Name, 'LinearDamping') then
    Body.LinearDamping := Info.ParamAsFloat[2]
  else if SameText(Name, 'GravityScale') then
    Body.GravityScale := Info.ParamAsFloat[2]
  else if SameText(Name, 'AngularDamping') then
    Body.AngularDamping := Info.ParamAsFloat[2]
  else if SameText(Name, 'Radius') then
    Body.Radius := Info.ParamAsFloat[2]
  else if SameText(Name, 'HalfHeight') then
    Body.HalfHeight := Info.ParamAsFloat[2]
  else if SameText(Name, 'StepHeight') then
    Body.StepHeight := Info.ParamAsFloat[2]
  else
    raise Exception.CreateFmt('Unknown writable physics body float property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoPhysicsBodyVector3(Info: TProgramInfo);
var
  Body: TPhysicsBody;
  Name: string;
begin
  Body := FContext.PhysicsBodyFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  if SameText(Name, 'Velocity') then
    SetResultVector3(Info, Body.Velocity)
  else if SameText(Name, 'AngularVelocity') then
    SetResultVector3(Info, Body.AngularVelocity)
  else if SameText(Name, 'AABBHalfExtents') or SameText(Name, 'HalfExtents') then
    SetResultVector3(Info, Body.AABBHalfExtents)
  else
    raise Exception.CreateFmt('Unknown physics body TVector3 property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoPhysicsBodySetVector3(Info: TProgramInfo);
var
  Body: TPhysicsBody;
  Name: string;
  Value: TVector3;
begin
  Body := FContext.PhysicsBodyFromHandle(Info.ParamAsInteger[0]);
  Name := Info.ParamAsString[1];
  Value := ParamAsVector3(Info, 2);
  if SameText(Name, 'Velocity') then
    Body.Velocity := Value
  else if SameText(Name, 'AngularVelocity') then
    Body.AngularVelocity := Value
  else if SameText(Name, 'AABBHalfExtents') or SameText(Name, 'HalfExtents') then
    Body.AABBHalfExtents := Value
  else
    raise Exception.CreateFmt('Unknown physics body TVector3 property: %s', [Name]);
end;

procedure TdwsEngineUnit.DoPhysicsBodyConfigureSphere(Info: TProgramInfo);
begin
  FContext.PhysicsBodyFromHandle(Info.ParamAsInteger[0]).ConfigureSphere(Info.ParamAsFloat[1]);
end;

procedure TdwsEngineUnit.DoPhysicsBodyConfigureCapsule(Info: TProgramInfo);
begin
  FContext.PhysicsBodyFromHandle(Info.ParamAsInteger[0]).ConfigureCapsule(
    Info.ParamAsFloat[1], Info.ParamAsFloat[2]);
end;

procedure TdwsEngineUnit.DoPhysicsBodyConfigureAABB(Info: TProgramInfo);
begin
  FContext.PhysicsBodyFromHandle(Info.ParamAsInteger[0]).ConfigureAABB(ParamAsVector3(Info, 1));
end;

procedure TdwsEngineUnit.DoPhysicsBodyConfigureMesh(Info: TProgramInfo);
begin
  FContext.PhysicsBodyFromHandle(Info.ParamAsInteger[0]).ConfigureMesh;
end;

procedure TdwsEngineUnit.DoPhysicsBodyAutoFitCollider(Info: TProgramInfo);
begin
  FContext.PhysicsBodyFromHandle(Info.ParamAsInteger[0]).AutoFitColliderFromScene;
end;

procedure TdwsEngineUnit.DoPhysicsBodyAddForce(Info: TProgramInfo);
begin
  FContext.PhysicsBodyFromHandle(Info.ParamAsInteger[0]).AddForce(ParamAsVector3(Info, 1));
end;

procedure TdwsEngineUnit.DoPhysicsBodyAddImpulse(Info: TProgramInfo);
begin
  FContext.PhysicsBodyFromHandle(Info.ParamAsInteger[0]).AddImpulse(ParamAsVector3(Info, 1));
end;

procedure TdwsEngineUnit.DoPhysicsBodyClearForces(Info: TProgramInfo);
begin
  FContext.PhysicsBodyFromHandle(Info.ParamAsInteger[0]).ClearForces;
end;

procedure TdwsEngineUnit.DoPhysicsBodyStop(Info: TProgramInfo);
begin
  FContext.PhysicsBodyFromHandle(Info.ParamAsInteger[0]).Stop;
end;

constructor TdwsEngineUnit.RegisterEngine(AOwner: TComponent; AScript: TDelphiWebScript;
  AContext: TEngineScriptContext);
begin
  inherited Create(AOwner);

  UnitName := 'Engine';
  Dependencies.Add('FastMath');
  Script := AScript;
  ImplicitUse := True;
  FContext := AContext;

  RegisterMeshClass;
  RegisterSceneObjectClass;
  RegisterLightClass;
  RegisterMaterialClass;
  RegisterShaderClass;

  RegisterEngineFunction('ScriptEventName', 'String', [], [], DoScriptEventName);
  RegisterEngineFunction('ScriptTargetKind', 'Integer', [], [], DoScriptTargetKind);
  RegisterEngineFunction('ScriptTargetName', 'String', [], [], DoScriptTargetName);
  RegisterEngineFunction('ScriptTargetHandle', 'Integer', [], [], DoScriptTargetHandle);
  RegisterEngineFunction('ScriptTargetObject', 'TSceneObject', [], [], DoScriptTargetObject);
  RegisterEngineFunction('ScriptTargetMaterial', 'TMaterial', [], [], DoScriptTargetMaterial);
  RegisterEngineFunction('ScriptTargetShader', 'TShader', [], [], DoScriptTargetShader);
  RegisterEngineFunction('DeltaTime', 'Float', [], [], DoDeltaTime);
  RegisterEngineFunction('TimeSeconds', 'Float', [], [], DoTimeSeconds);
  RegisterEngineFunction('Log', '', ['aMessage'], ['String'], DoLog);
  RegisterEngineFunction('KeyCode', 'Integer', ['Name'], ['String'], DoKeyCode);
  RegisterEngineFunction('KeyPressed', 'Boolean', ['KeyCode'], ['Integer'], DoKeyPressedCode, True);
  RegisterEngineFunction('KeyPressed', 'Boolean', ['KeyName'], ['String'], DoKeyPressedName, True);
  RegisterEngineFunction('MouseButtonCode', 'Integer', ['Name'], ['String'], DoMouseButtonCode);
  RegisterEngineFunction('MouseButtonPressed', 'Boolean', ['ButtonCode'], ['Integer'], DoMouseButtonPressedCode, True);
  RegisterEngineFunction('MouseButtonPressed', 'Boolean', ['ButtonName'], ['String'], DoMouseButtonPressedName, True);
  RegisterEngineFunction('MousePosition', 'TVector2', [], [], DoMousePosition);
  RegisterEngineFunction('MouseX', 'Float', [], [], DoMouseX);
  RegisterEngineFunction('MouseY', 'Float', [], [], DoMouseY);
  RegisterEngineFunction('MouseInsideViewport', 'Boolean', [], [], DoMouseInsideViewport);
  RegisterEngineFunction('MouseRayOrigin', 'TVector3', [], [], DoMouseRayOrigin);
  RegisterEngineFunction('MouseRayDirection', 'TVector3', [], [], DoMouseRayDirection);
  RegisterEngineFunction('ScreenRayOrigin', 'TVector3', ['X', 'Y'], ['Float', 'Float'], DoScreenRayOrigin);
  RegisterEngineFunction('ScreenRayDirection', 'TVector3', ['X', 'Y'], ['Float', 'Float'], DoScreenRayDirection);
  RegisterEngineFunction('MousePlaneHit', 'Boolean', ['PlanePoint', 'PlaneNormal'], ['TVector3', 'TVector3'], DoMousePlaneHit);
  RegisterEngineFunction('MousePlanePoint', 'TVector3', ['PlanePoint', 'PlaneNormal'], ['TVector3', 'TVector3'], DoMousePlanePoint);
  RegisterEngineFunction('ScreenPlaneHit', 'Boolean', ['X', 'Y', 'PlanePoint', 'PlaneNormal'], ['Float', 'Float', 'TVector3', 'TVector3'], DoScreenPlaneHit);
  RegisterEngineFunction('ScreenPlanePoint', 'TVector3', ['X', 'Y', 'PlanePoint', 'PlaneNormal'], ['Float', 'Float', 'TVector3', 'TVector3'], DoScreenPlanePoint);
  RegisterEngineFunction('HeightFieldLocalHeight', 'Float', ['HeightField', 'LocalX', 'LocalZ'], ['Integer', 'Float', 'Float'], DoHeightFieldLocalHeight);
  RegisterEngineFunction('HeightFieldWorldPoint', 'TVector3', ['HeightField', 'WorldPoint'], ['Integer', 'TVector3'], DoHeightFieldWorldPoint);
  RegisterEngineFunction('HeightFieldWorldHeight', 'Float', ['HeightField', 'WorldPoint'], ['Integer', 'TVector3'], DoHeightFieldWorldHeight);
  RegisterEngineFunction('MouseHeightFieldHit', 'Boolean', ['HeightField'], ['Integer'], DoMouseHeightFieldHit);
  RegisterEngineFunction('MouseHeightFieldPoint', 'TVector3', ['HeightField'], ['Integer'], DoMouseHeightFieldPoint);
  RegisterEngineFunction('MouseHeightFieldLocalPoint', 'TVector3', ['HeightField'], ['Integer'], DoMouseHeightFieldLocalPoint);
  RegisterEngineFunction('ScreenHeightFieldHit', 'Boolean', ['X', 'Y', 'HeightField'], ['Float', 'Float', 'Integer'], DoScreenHeightFieldHit);
  RegisterEngineFunction('ScreenHeightFieldPoint', 'TVector3', ['X', 'Y', 'HeightField'], ['Float', 'Float', 'Integer'], DoScreenHeightFieldPoint);
  RegisterEngineFunction('ScreenHeightFieldLocalPoint', 'TVector3', ['X', 'Y', 'HeightField'], ['Float', 'Float', 'Integer'], DoScreenHeightFieldLocalPoint);
  RegisterEngineFunction('ViewportLeft', 'Integer', [], [], DoViewportLeft);
  RegisterEngineFunction('ViewportTop', 'Integer', [], [], DoViewportTop);
  RegisterEngineFunction('ViewportWidth', 'Integer', [], [], DoViewportWidth);
  RegisterEngineFunction('ViewportHeight', 'Integer', [], [], DoViewportHeight);
  RegisterEngineFunction('ViewportPosition', 'TVector2', [], [], DoViewportPosition);
  RegisterEngineFunction('ViewportSize', 'TVector2', [], [], DoViewportSize);
  RegisterEngineFunction('ViewportRect', 'TVector4', [], [], DoViewportRect);
  RegisterEngineFunction('ViewportAspectRatio', 'Float', [], [], DoViewportAspectRatio);
  RegisterEngineFunction('ViewportSetPosition', '', ['Left', 'Top'], ['Integer', 'Integer'], DoViewportSetPosition);
  RegisterEngineFunction('ViewportSetSize', '', ['Width', 'Height'], ['Integer', 'Integer'], DoViewportSetSize);
  RegisterEngineFunction('ViewportSetRect', '', ['Left', 'Top', 'Width', 'Height'], ['Integer', 'Integer', 'Integer', 'Integer'], DoViewportSetRect);
  RegisterEngineFunction('RenderWindowLeft', 'Integer', [], [], DoRenderWindowLeft);
  RegisterEngineFunction('RenderWindowTop', 'Integer', [], [], DoRenderWindowTop);
  RegisterEngineFunction('RenderWindowWidth', 'Integer', [], [], DoRenderWindowWidth);
  RegisterEngineFunction('RenderWindowHeight', 'Integer', [], [], DoRenderWindowHeight);
  RegisterEngineFunction('RenderWindowPosition', 'TVector2', [], [], DoRenderWindowPosition);
  RegisterEngineFunction('RenderWindowSize', 'TVector2', [], [], DoRenderWindowSize);
  RegisterEngineFunction('RenderWindowRect', 'TVector4', [], [], DoRenderWindowRect);
  RegisterEngineFunction('RenderWindowAspectRatio', 'Float', [], [], DoRenderWindowAspectRatio);
  RegisterEngineFunction('RenderWindowSetPosition', '', ['Left', 'Top'], ['Integer', 'Integer'], DoRenderWindowSetPosition);
  RegisterEngineFunction('RenderWindowSetSize', '', ['Width', 'Height'], ['Integer', 'Integer'], DoRenderWindowSetSize);
  RegisterEngineFunction('RenderWindowSetRect', '', ['Left', 'Top', 'Width', 'Height'], ['Integer', 'Integer', 'Integer', 'Integer'], DoRenderWindowSetRect);
  RegisterEngineFunction('RenderWindowFullScreen', 'Boolean', [], [], DoRenderWindowFullScreen);
  RegisterEngineFunction('RenderWindowSetFullScreen', '', ['Enabled'], ['Boolean'], DoRenderWindowSetFullScreen);
  RegisterEngineFunction('RenderWindowToggleFullScreen', 'Boolean', [], [], DoRenderWindowToggleFullScreen);

  RegisterEngineFunction('SceneRoot', 'Integer', [], [], DoSceneRoot);
  RegisterEngineFunction('SceneRootObject', 'TSceneObject', [], [], DoSceneRootObject);
  RegisterEngineFunction('SceneFind', 'Integer', ['Name'], ['String'], DoSceneFind);
  RegisterEngineFunction('SceneFindObject', 'TSceneObject', ['Name'], ['String'], DoSceneFindObject);
  RegisterEngineFunction('SceneUpdate', '', [], [], DoSceneUpdate);
  RegisterEngineFunction('SceneRender', '', [], [], DoSceneRender);
  RegisterEngineFunction('PrefabLoad', 'Integer', ['FileName', 'Parent'], ['String', 'Integer'], DoPrefabLoad);
  RegisterEngineFunction('PrefabDestroy', '', ['Obj'], ['Integer'], DoPrefabDestroy);

  RegisterEngineFunction('ObjectFromHandle', 'TSceneObject', ['Handle'], ['Integer'], DoObjectFromHandle);
  RegisterEngineFunction('ObjectHandle', 'Integer', ['Obj'], ['TSceneObject'], DoObjectHandle);
  RegisterEngineFunction('ObjectCreate', 'Integer', ['Parent', 'Name'], ['Integer', 'String'], DoObjectCreate);
  RegisterEngineFunction('ObjectDelete', '', ['Obj'], ['Integer'], DoObjectDelete);
  RegisterEngineFunction('ObjectChildCount', 'Integer', ['Obj'], ['Integer'], DoObjectChildCount);
  RegisterEngineFunction('ObjectChild', 'Integer', ['Obj', 'Index'], ['Integer', 'Integer'], DoObjectChild);
  RegisterEngineFunction('ObjectParent', 'Integer', ['Obj'], ['Integer'], DoObjectParent);
  RegisterEngineFunction('ObjectName', 'String', ['Obj'], ['Integer'], DoObjectName);
  RegisterEngineFunction('ObjectSetName', '', ['Obj', 'Name'], ['Integer', 'String'], DoObjectSetName);
  RegisterEngineFunction('ObjectPosition', 'TVector3', ['Obj'], ['Integer'], DoObjectPosition);
  RegisterEngineFunction('ObjectSetPosition', '', ['Obj', 'Position'], ['Integer', 'TVector3'], DoObjectSetPosition);
  RegisterEngineFunction('ObjectRotation', 'TVector3', ['Obj'], ['Integer'], DoObjectRotation);
  RegisterEngineFunction('ObjectSetRotation', '', ['Obj', 'Rotation'], ['Integer', 'TVector3'], DoObjectSetRotation);
  RegisterEngineFunction('ObjectScale', 'TVector3', ['Obj'], ['Integer'], DoObjectScale);
  RegisterEngineFunction('ObjectSetScale', '', ['Obj', 'Scale'], ['Integer', 'TVector3'], DoObjectSetScale);
  RegisterEngineFunction('ObjectMatrix', 'TMatrix4', ['Obj'], ['Integer'], DoObjectMatrix);
  RegisterEngineFunction('ObjectModelMatrix', 'TMatrix4', ['Obj'], ['Integer'], DoObjectModelMatrix);
  RegisterEngineFunction('ObjectLocalMatrix', 'TMatrix4', ['Obj'], ['Integer'], DoObjectLocalMatrix);
  RegisterEngineFunction('ObjectWorldMatrix', 'TMatrix4', ['Obj'], ['Integer'], DoObjectWorldMatrix);
  RegisterEngineFunction('ObjectWorldPosition', 'TVector3', ['Obj'], ['Integer'], DoObjectWorldPosition);
  RegisterEngineFunction('ObjectSetWireframe', '', ['Obj', 'Enabled'], ['Integer', 'Boolean'], DoObjectSetWireframe);
  RegisterEngineFunction('ObjectHasGeometry', 'Boolean', ['Obj'], ['Integer'], DoObjectHasGeometry);
  RegisterEngineFunction('ObjectHasCamera', 'Boolean', ['Obj'], ['Integer'], DoObjectHasCamera);
  RegisterEngineFunction('ObjectHasParticles', 'Boolean', ['Obj'], ['Integer'], DoObjectHasParticles);
  RegisterEngineFunction('ObjectHasBillboards', 'Boolean', ['Obj'], ['Integer'], DoObjectHasBillboards);
  RegisterEngineFunction('ObjectHasAudio', 'Boolean', ['Obj'], ['Integer'], DoObjectHasAudio);

  RegisterEngineFunction('ObjectMeshCount', 'Integer', ['Obj'], ['Integer'], DoObjectMeshCount);
  RegisterEngineFunction('ObjectMesh', 'Integer', ['Obj', 'Index'], ['Integer', 'Integer'], DoObjectMesh);
  RegisterEngineFunction('ObjectMeshObject', 'TMesh', ['Obj', 'Index'], ['Integer', 'Integer'], DoObjectMeshObject);
  RegisterEngineFunction('ObjectAddMeshFile', 'Integer', ['Obj', 'FileName'], ['Integer', 'String'], DoObjectAddMeshFile);
  RegisterEngineFunction('ObjectAddMeshFileObject', 'TMesh', ['Obj', 'FileName'], ['Integer', 'String'], DoObjectAddMeshFileObject);
  RegisterEngineFunction('ObjectAddPlane', 'Integer', ['Obj', 'Width', 'Depth', 'WidthSegments', 'DepthSegments', 'Name'], ['Integer', 'Float', 'Float', 'Integer', 'Integer', 'String'], DoObjectAddPlane);
  RegisterEngineFunction('ObjectAddCube', 'Integer', ['Obj', 'Width', 'Height', 'Depth', 'WidthStacks', 'HeightStacks', 'DepthStacks', 'Name'], ['Integer', 'Float', 'Float', 'Float', 'Integer', 'Integer', 'Integer', 'String'], DoObjectAddCube);
  RegisterEngineFunction('ObjectAddSphere', 'Integer', ['Obj', 'Radius', 'StackCount', 'SliceCount', 'Name'], ['Integer', 'Float', 'Integer', 'Integer', 'String'], DoObjectAddSphere);
  RegisterEngineFunction('ObjectAddCylinder', 'Integer', ['Obj', 'Radius', 'Height', 'Slices', 'Stacks', 'Name'], ['Integer', 'Float', 'Float', 'Integer', 'Integer', 'String'], DoObjectAddCylinder);
  RegisterEngineFunction('ObjectAddCapsule', 'Integer', ['Obj', 'Radius', 'Height', 'Slices', 'Stacks', 'Name'], ['Integer', 'Float', 'Float', 'Integer', 'Integer', 'String'], DoObjectAddCapsule);
  RegisterEngineFunction('ObjectAddTorus', 'Integer', ['Obj', 'MajorRadius', 'MinorRadius', 'MajorSegments', 'MinorSegments', 'Name'], ['Integer', 'Float', 'Float', 'Integer', 'Integer', 'String'], DoObjectAddTorus);
  RegisterEngineFunction('ObjectAddCone', 'Integer', ['Obj', 'Radius', 'Height', 'Sides', 'Stacks', 'Name'], ['Integer', 'Float', 'Float', 'Integer', 'Integer', 'String'], DoObjectAddCone);
  RegisterEngineFunction('ObjectAddPrism', 'Integer', ['Obj', 'Radius', 'Height', 'Sides', 'Stacks', 'Name'], ['Integer', 'Float', 'Float', 'Integer', 'Integer', 'String'], DoObjectAddPrism);
  RegisterEngineFunction('ObjectAddFrustum', 'Integer', ['Obj', 'BottomRadius', 'TopRadius', 'Height', 'Slices', 'Stacks', 'BottomCap', 'TopCap', 'Name'], ['Integer', 'Float', 'Float', 'Float', 'Integer', 'Integer', 'Integer', 'Integer', 'String'], DoObjectAddFrustum);
  RegisterEngineFunction('ObjectAddIcosphere', 'Integer', ['Obj', 'Radius', 'Subdivisions', 'Name'], ['Integer', 'Float', 'Integer', 'String'], DoObjectAddIcosphere);
  RegisterEngineFunction('ObjectAddGeodesicDome', 'Integer', ['Obj', 'Radius', 'Subdivisions', 'Name'], ['Integer', 'Float', 'Integer', 'String'], DoObjectAddGeodesicDome);
  RegisterEngineFunction('ObjectAddArrow', 'Integer', ['Obj', 'ShaftLength', 'TipLength', 'ShaftRadius', 'TipRadius', 'Slices', 'Stacks', 'Name'], ['Integer', 'Float', 'Float', 'Float', 'Float', 'Integer', 'Integer', 'String'], DoObjectAddArrow);
  RegisterEngineFunction('ObjectAddSuperEllipsoid', 'Integer', ['Obj', 'Radius', 'VCurve', 'HCurve', 'Slices', 'Stacks', 'Name'], ['Integer', 'Float', 'Float', 'Float', 'Integer', 'Integer', 'String'], DoObjectAddSuperEllipsoid);
  RegisterEngineFunction('ObjectSetMaterial', '', ['Obj', 'MaterialName'], ['Integer', 'String'], DoObjectSetMaterial);

  RegisterEngineFunction('MeshFromHandle', 'TMesh', ['Handle'], ['Integer'], DoMeshFromHandle);
  RegisterEngineFunction('MeshHandle', 'Integer', ['Mesh'], ['TMesh'], DoMeshHandle);
  RegisterEngineFunction('MeshName', 'String', ['Mesh'], ['Integer'], DoMeshName);
  RegisterEngineFunction('MeshSetName', '', ['Mesh', 'Name'], ['Integer', 'String'], DoMeshSetName);
  RegisterEngineFunction('MeshPosition', 'TVector3', ['Mesh'], ['Integer'], DoMeshPosition);
  RegisterEngineFunction('MeshSetPosition', '', ['Mesh', 'Position'], ['Integer', 'TVector3'], DoMeshSetPosition);
  RegisterEngineFunction('MeshRotation', 'TVector3', ['Mesh'], ['Integer'], DoMeshRotation);
  RegisterEngineFunction('MeshSetRotation', '', ['Mesh', 'Rotation'], ['Integer', 'TVector3'], DoMeshSetRotation);
  RegisterEngineFunction('MeshScale', 'TVector3', ['Mesh'], ['Integer'], DoMeshScale);
  RegisterEngineFunction('MeshSetScale', '', ['Mesh', 'Scale'], ['Integer', 'TVector3'], DoMeshSetScale);
  RegisterEngineFunction('MeshSetTransform', '', ['Mesh', 'Position', 'Rotation', 'Scale'], ['Integer', 'TVector3', 'TVector3', 'TVector3'], DoMeshSetTransform);
  RegisterEngineFunction('MeshVisible', 'Boolean', ['Mesh'], ['Integer'], DoMeshVisible);
  RegisterEngineFunction('MeshSetVisible', '', ['Mesh', 'Visible'], ['Integer', 'Boolean'], DoMeshSetVisible);
  RegisterEngineFunction('MeshWireframe', 'Boolean', ['Mesh'], ['Integer'], DoMeshWireframe);
  RegisterEngineFunction('MeshSetWireframe', '', ['Mesh', 'Enabled'], ['Integer', 'Boolean'], DoMeshSetWireframe);
  RegisterEngineFunction('MeshAlwaysOnTop', 'Boolean', ['Mesh'], ['Integer'], DoMeshAlwaysOnTop);
  RegisterEngineFunction('MeshSetAlwaysOnTop', '', ['Mesh', 'Value'], ['Integer', 'Boolean'], DoMeshSetAlwaysOnTop);
  RegisterEngineFunction('MeshTag', 'Integer', ['Mesh'], ['Integer'], DoMeshTag);
  RegisterEngineFunction('MeshSetTag', '', ['Mesh', 'Value'], ['Integer', 'Integer'], DoMeshSetTag);
  RegisterEngineFunction('MeshType', 'Integer', ['Mesh'], ['Integer'], DoMeshType);
  RegisterEngineFunction('MeshVertexCount', 'Integer', ['Mesh'], ['Integer'], DoMeshVertexCount);
  RegisterEngineFunction('MeshIndexCount', 'Integer', ['Mesh'], ['Integer'], DoMeshIndexCount);
  RegisterEngineFunction('MeshBoundingBoxMin', 'TVector3', ['Mesh'], ['Integer'], DoMeshBoundingBoxMin);
  RegisterEngineFunction('MeshBoundingBoxMax', 'TVector3', ['Mesh'], ['Integer'], DoMeshBoundingBoxMax);
  RegisterEngineFunction('MeshLocalMatrix', 'TMatrix4', ['Mesh'], ['Integer'], DoMeshLocalMatrix);
  RegisterEngineFunction('MeshModelMatrix', 'TMatrix4', ['Mesh'], ['Integer'], DoMeshModelMatrix);
  RegisterEngineFunction('MeshParentModelMatrix', 'TMatrix4', ['Mesh'], ['Integer'], DoMeshParentModelMatrix);
  RegisterEngineFunction('MeshMaterialName', 'String', ['Mesh'], ['Integer'], DoMeshMaterialName);
  RegisterEngineFunction('MeshSetMaterialName', '', ['Mesh', 'MaterialName'], ['Integer', 'String'], DoMeshSetMaterialName);
  RegisterEngineFunction('MeshSetMaterial', '', ['Mesh', 'MaterialName'], ['Integer', 'String'], DoMeshSetMaterial);
  RegisterEngineFunction('MeshApplyTransform', 'Boolean', ['Mesh', 'Translation', 'Rotation', 'Scale'], ['Integer', 'TVector3', 'TVector3', 'TVector3'], DoMeshApplyTransform);
  RegisterEngineFunction('MeshScaleUVs', '', ['Mesh', 'ScaleU', 'ScaleV'], ['Integer', 'Float', 'Float'], DoMeshScaleUVs);
  RegisterEngineFunction('MeshRecomputeBoundingBox', '', ['Mesh'], ['Integer'], DoMeshRecomputeBoundingBox);

  RegisterEngineFunction('ObjectParticleSystemCount', 'Integer', ['Obj'], ['Integer'], DoObjectParticleSystemCount);
  RegisterEngineFunction('ObjectParticleSystem', 'Integer', ['Obj', 'Index'], ['Integer', 'Integer'], DoObjectParticleSystem);
  RegisterEngineFunction('ObjectCreateParticleSystem', 'Integer', ['Obj'], ['Integer'], DoObjectCreateParticleSystem);
  RegisterEngineFunction('ObjectRemoveParticleSystem', '', ['Obj', 'Index'], ['Integer', 'Integer'], DoObjectRemoveParticleSystem);
  RegisterEngineFunction('ParticleBlendAlpha', 'Integer', [], [], DoParticleBlendAlpha);
  RegisterEngineFunction('ParticleBlendAdditive', 'Integer', [], [], DoParticleBlendAdditive);
  RegisterEngineFunction('ParticleTextureNone', 'Integer', [], [], DoParticleTextureNone);
  RegisterEngineFunction('ParticleTextureSoftCircle', 'Integer', [], [], DoParticleTextureSoftCircle);
  RegisterEngineFunction('ParticleTexturePerlin', 'Integer', [], [], DoParticleTexturePerlin);
  RegisterEngineFunction('ParticleTextureFile', 'Integer', [], [], DoParticleTextureFile);
  RegisterEngineFunction('ParticleSpaceObject', 'Integer', [], [], DoParticleSpaceObject);
  RegisterEngineFunction('ParticleSpaceWorld', 'Integer', [], [], DoParticleSpaceWorld);
  RegisterEngineFunction('ParticleCount', 'Integer', ['Particle'], ['Integer'], DoParticleCount);
  RegisterEngineFunction('ParticleClear', '', ['Particle'], ['Integer'], DoParticleClear);
  RegisterEngineFunction('ParticleBurst', '', ['Particle', 'Count'], ['Integer', 'Integer'], DoParticleBurst);
  RegisterEngineFunction('ParticleBoolean', 'Boolean', ['Particle', 'Name'], ['Integer', 'String'], DoParticleBoolean);
  RegisterEngineFunction('ParticleSetBoolean', '', ['Particle', 'Name', 'Value'], ['Integer', 'String', 'Boolean'], DoParticleSetBoolean);
  RegisterEngineFunction('ParticleInteger', 'Integer', ['Particle', 'Name'], ['Integer', 'String'], DoParticleInteger);
  RegisterEngineFunction('ParticleSetInteger', '', ['Particle', 'Name', 'Value'], ['Integer', 'String', 'Integer'], DoParticleSetInteger);
  RegisterEngineFunction('ParticleFloat', 'Float', ['Particle', 'Name'], ['Integer', 'String'], DoParticleFloat);
  RegisterEngineFunction('ParticleSetFloat', '', ['Particle', 'Name', 'Value'], ['Integer', 'String', 'Float'], DoParticleSetFloat);
  RegisterEngineFunction('ParticleVector3', 'TVector3', ['Particle', 'Name'], ['Integer', 'String'], DoParticleVector3);
  RegisterEngineFunction('ParticleSetVector3', '', ['Particle', 'Name', 'Value'], ['Integer', 'String', 'TVector3'], DoParticleSetVector3);
  RegisterEngineFunction('ParticleVector4', 'TVector4', ['Particle', 'Name'], ['Integer', 'String'], DoParticleVector4);
  RegisterEngineFunction('ParticleSetVector4', '', ['Particle', 'Name', 'Value'], ['Integer', 'String', 'TVector4'], DoParticleSetVector4);
  RegisterEngineFunction('ParticleString', 'String', ['Particle', 'Name'], ['Integer', 'String'], DoParticleString);
  RegisterEngineFunction('ParticleSetString', '', ['Particle', 'Name', 'Value'], ['Integer', 'String', 'String'], DoParticleSetString);

  RegisterEngineFunction('ObjectBillboardCount', 'Integer', ['Obj'], ['Integer'], DoObjectBillboardCount);
  RegisterEngineFunction('ObjectBillboard', 'Integer', ['Obj', 'Index'], ['Integer', 'Integer'], DoObjectBillboard);
  RegisterEngineFunction('ObjectCreateBillboard', 'Integer', ['Obj'], ['Integer'], DoObjectCreateBillboard);
  RegisterEngineFunction('ObjectRemoveBillboard', '', ['Obj', 'Index'], ['Integer', 'Integer'], DoObjectRemoveBillboard);
  RegisterEngineFunction('BillboardBlendAlpha', 'Integer', [], [], DoBillboardBlendAlpha);
  RegisterEngineFunction('BillboardBlendAdditive', 'Integer', [], [], DoBillboardBlendAdditive);
  RegisterEngineFunction('BillboardBoolean', 'Boolean', ['Billboard', 'Name'], ['Integer', 'String'], DoBillboardBoolean);
  RegisterEngineFunction('BillboardSetBoolean', '', ['Billboard', 'Name', 'Value'], ['Integer', 'String', 'Boolean'], DoBillboardSetBoolean);
  RegisterEngineFunction('BillboardInteger', 'Integer', ['Billboard', 'Name'], ['Integer', 'String'], DoBillboardInteger);
  RegisterEngineFunction('BillboardSetInteger', '', ['Billboard', 'Name', 'Value'], ['Integer', 'String', 'Integer'], DoBillboardSetInteger);
  RegisterEngineFunction('BillboardFloat', 'Float', ['Billboard', 'Name'], ['Integer', 'String'], DoBillboardFloat);
  RegisterEngineFunction('BillboardSetFloat', '', ['Billboard', 'Name', 'Value'], ['Integer', 'String', 'Float'], DoBillboardSetFloat);
  RegisterEngineFunction('BillboardVector3', 'TVector3', ['Billboard', 'Name'], ['Integer', 'String'], DoBillboardVector3);
  RegisterEngineFunction('BillboardSetVector3', '', ['Billboard', 'Name', 'Value'], ['Integer', 'String', 'TVector3'], DoBillboardSetVector3);
  RegisterEngineFunction('BillboardVector4', 'TVector4', ['Billboard', 'Name'], ['Integer', 'String'], DoBillboardVector4);
  RegisterEngineFunction('BillboardSetVector4', '', ['Billboard', 'Name', 'Value'], ['Integer', 'String', 'TVector4'], DoBillboardSetVector4);
  RegisterEngineFunction('BillboardString', 'String', ['Billboard', 'Name'], ['Integer', 'String'], DoBillboardString);
  RegisterEngineFunction('BillboardSetString', '', ['Billboard', 'Name', 'Value'], ['Integer', 'String', 'String'], DoBillboardSetString);

  RegisterEngineFunction('ObjectAudioEmitterCount', 'Integer', ['Obj'], ['Integer'], DoObjectAudioEmitterCount);
  RegisterEngineFunction('ObjectAudioEmitter', 'Integer', ['Obj', 'Index'], ['Integer', 'Integer'], DoObjectAudioEmitter);
  RegisterEngineFunction('ObjectCreateAudioEmitter', 'Integer', ['Obj'], ['Integer'], DoObjectCreateAudioEmitter);
  RegisterEngineFunction('ObjectRemoveAudioEmitter', '', ['Obj', 'Index'], ['Integer', 'Integer'], DoObjectRemoveAudioEmitter);
  RegisterEngineFunction('ObjectAudioListener', 'Boolean', ['Obj'], ['Integer'], DoObjectAudioListener);
  RegisterEngineFunction('ObjectSetAudioListener', '', ['Obj', 'Enabled'], ['Integer', 'Boolean'], DoObjectSetAudioListener);
  RegisterEngineFunction('ObjectAudioVector3', 'TVector3', ['Obj', 'Name'], ['Integer', 'String'], DoObjectAudioVector3);
  RegisterEngineFunction('ObjectSetAudioVector3', '', ['Obj', 'Name', 'Value'], ['Integer', 'String', 'TVector3'], DoObjectSetAudioVector3);
  RegisterEngineFunction('ObjectAudioFloat', 'Float', ['Obj', 'Name'], ['Integer', 'String'], DoObjectAudioFloat);
  RegisterEngineFunction('ObjectSetAudioFloat', '', ['Obj', 'Name', 'Value'], ['Integer', 'String', 'Float'], DoObjectSetAudioFloat);
  RegisterEngineFunction('Audio3DModeNormal', 'Integer', [], [], DoAudio3DModeNormal);
  RegisterEngineFunction('Audio3DModeRelative', 'Integer', [], [], DoAudio3DModeRelative);
  RegisterEngineFunction('Audio3DModeOff', 'Integer', [], [], DoAudio3DModeOff);
  RegisterEngineFunction('AudioInitialized', 'Boolean', [], [], DoAudioInitialized);
  RegisterEngineFunction('AudioApply3D', '', [], [], DoAudioApply3D);
  RegisterEngineFunction('AudioMasterVolume', 'Float', [], [], DoAudioMasterVolume);
  RegisterEngineFunction('AudioSetMasterVolume', '', ['Volume'], ['Float'], DoAudioSetMasterVolume);
  RegisterEngineFunction('AudioEmitterBoolean', 'Boolean', ['Emitter', 'Name'], ['Integer', 'String'], DoAudioEmitterBoolean);
  RegisterEngineFunction('AudioEmitterSetBoolean', '', ['Emitter', 'Name', 'Value'], ['Integer', 'String', 'Boolean'], DoAudioEmitterSetBoolean);
  RegisterEngineFunction('AudioEmitterInteger', 'Integer', ['Emitter', 'Name'], ['Integer', 'String'], DoAudioEmitterInteger);
  RegisterEngineFunction('AudioEmitterSetInteger', '', ['Emitter', 'Name', 'Value'], ['Integer', 'String', 'Integer'], DoAudioEmitterSetInteger);
  RegisterEngineFunction('AudioEmitterFloat', 'Float', ['Emitter', 'Name'], ['Integer', 'String'], DoAudioEmitterFloat);
  RegisterEngineFunction('AudioEmitterSetFloat', '', ['Emitter', 'Name', 'Value'], ['Integer', 'String', 'Float'], DoAudioEmitterSetFloat);
  RegisterEngineFunction('AudioEmitterVector3', 'TVector3', ['Emitter', 'Name'], ['Integer', 'String'], DoAudioEmitterVector3);
  RegisterEngineFunction('AudioEmitterSetVector3', '', ['Emitter', 'Name', 'Value'], ['Integer', 'String', 'TVector3'], DoAudioEmitterSetVector3);
  RegisterEngineFunction('AudioEmitterString', 'String', ['Emitter', 'Name'], ['Integer', 'String'], DoAudioEmitterString);
  RegisterEngineFunction('AudioEmitterSetString', '', ['Emitter', 'Name', 'Value'], ['Integer', 'String', 'String'], DoAudioEmitterSetString);

  RegisterEngineFunction('ObjectCreateLight', 'Integer', ['Obj'], ['Integer'], DoObjectCreateLight);
  RegisterEngineFunction('ObjectLightCount', 'Integer', ['Obj'], ['Integer'], DoObjectLightCount);
  RegisterEngineFunction('ObjectLight', 'Integer', ['Obj', 'Index'], ['Integer', 'Integer'], DoObjectLight);
  RegisterEngineFunction('LightFromHandle', 'TLight', ['Handle'], ['Integer'], DoLightFromHandle);
  RegisterEngineFunction('LightHandle', 'Integer', ['Light'], ['TLight'], DoLightHandle);
  RegisterEngineFunction('LightTypeDirectional', 'Integer', [], [], DoLightTypeDirectional);
  RegisterEngineFunction('LightTypePoint', 'Integer', [], [], DoLightTypePoint);
  RegisterEngineFunction('LightTypeSpot', 'Integer', [], [], DoLightTypeSpot);
  RegisterEngineFunction('LightType', 'Integer', ['Light'], ['Integer'], DoLightType);
  RegisterEngineFunction('LightSetType', '', ['Light', 'Type'], ['Integer', 'Integer'], DoLightSetType);
  RegisterEngineFunction('LightEnabled', 'Boolean', ['Light'], ['Integer'], DoLightEnabled);
  RegisterEngineFunction('LightSetEnabled', '', ['Light', 'Enabled'], ['Integer', 'Boolean'], DoLightSetEnabled);
  RegisterEngineFunction('LightDiffuse', 'TVector3', ['Light'], ['Integer'], DoLightDiffuse);
  RegisterEngineFunction('LightSetDiffuse', '', ['Light', 'Color'], ['Integer', 'TVector3'], DoLightSetDiffuse);
  RegisterEngineFunction('LightAmbient', 'TVector3', ['Light'], ['Integer'], DoLightAmbient);
  RegisterEngineFunction('LightSetAmbient', '', ['Light', 'Color'], ['Integer', 'TVector3'], DoLightSetAmbient);
  RegisterEngineFunction('LightSpecular', 'TVector3', ['Light'], ['Integer'], DoLightSpecular);
  RegisterEngineFunction('LightSetSpecular', '', ['Light', 'Color'], ['Integer', 'TVector3'], DoLightSetSpecular);
  RegisterEngineFunction('LightPosition', 'TVector3', ['Light'], ['Integer'], DoLightPosition);
  RegisterEngineFunction('LightSetPosition', '', ['Light', 'Position'], ['Integer', 'TVector3'], DoLightSetPosition);
  RegisterEngineFunction('LightDirection', 'TVector3', ['Light'], ['Integer'], DoLightDirection);
  RegisterEngineFunction('LightSetDirection', '', ['Light', 'Direction'], ['Integer', 'TVector3'], DoLightSetDirection);
  RegisterEngineFunction('LightSetAttenuation', '', ['Light', 'Constant', 'Linear', 'Quadratic'], ['Integer', 'Float', 'Float', 'Float'], DoLightSetAttenuation);
  RegisterEngineFunction('LightSetSpot', '', ['Light', 'CutoffDegrees', 'Exponent'], ['Integer', 'Float', 'Float'], DoLightSetSpot);
  RegisterEngineFunction('LightCastShadows', 'Boolean', ['Light'], ['Integer'], DoLightCastShadows);
  RegisterEngineFunction('LightSetCastShadows', '', ['Light', 'Enabled'], ['Integer', 'Boolean'], DoLightSetCastShadows);
  RegisterEngineFunction('LightShadowStrength', 'Float', ['Light'], ['Integer'], DoLightShadowStrength);
  RegisterEngineFunction('LightSetShadowStrength', '', ['Light', 'Strength'], ['Integer', 'Float'], DoLightSetShadowStrength);

  RegisterEngineFunction('ObjectCreateCamera', 'Integer', ['Obj'], ['Integer'], DoObjectCreateCamera);
  RegisterEngineFunction('ObjectCamera', 'Integer', ['Obj'], ['Integer'], DoObjectCamera);
  RegisterEngineFunction('CameraLookAt', '', ['Camera', 'Position', 'Target', 'Up'], ['Integer', 'TVector3', 'TVector3', 'TVector3'], DoCameraLookAt);
  RegisterEngineFunction('CameraMoveForward', '', ['Camera', 'Distance'], ['Integer', 'Float'], DoCameraMoveForward);
  RegisterEngineFunction('CameraMoveRight', '', ['Camera', 'Distance'], ['Integer', 'Float'], DoCameraMoveRight);
  RegisterEngineFunction('CameraMoveUp', '', ['Camera', 'Distance'], ['Integer', 'Float'], DoCameraMoveUp);
  RegisterEngineFunction('CameraRotateYaw', '', ['Camera', 'AngleRad'], ['Integer', 'Float'], DoCameraRotateYaw);
  RegisterEngineFunction('CameraRotatePitch', '', ['Camera', 'AngleRad'], ['Integer', 'Float'], DoCameraRotatePitch);
  RegisterEngineFunction('CameraPosition', 'TVector3', ['Camera'], ['Integer'], DoCameraPosition);
  RegisterEngineFunction('CameraTarget', 'TVector3', ['Camera'], ['Integer'], DoCameraTarget);
  RegisterEngineFunction('CameraViewMatrix', 'TMatrix4', ['Camera'], ['Integer'], DoCameraViewMatrix);
  RegisterEngineFunction('CameraViewProjectionMatrix', 'TMatrix4', ['Camera'], ['Integer'], DoCameraViewProjectionMatrix);

  RegisterEngineFunction('MaterialCount', 'Integer', [], [], DoMaterialCount);
  RegisterEngineFunction('MaterialName', 'String', ['Index'], ['Integer'], DoMaterialName);
  RegisterEngineFunction('MaterialByName', 'Integer', ['Name'], ['String'], DoMaterialByName);
  RegisterEngineFunction('MaterialByNameObject', 'TMaterial', ['Name'], ['String'], DoMaterialByNameObject);
  RegisterEngineFunction('MaterialFromHandle', 'TMaterial', ['Handle'], ['Integer'], DoMaterialFromHandle);
  RegisterEngineFunction('MaterialHandle', 'Integer', ['Material'], ['TMaterial'], DoMaterialHandle);
  RegisterEngineFunction('MaterialShaderParameter', 'Float', ['Material', 'Name'], ['Integer', 'String'], DoMaterialShaderParameter);
  RegisterEngineFunction('MaterialSetShaderParameter', '', ['Material', 'Name', 'Value'], ['Integer', 'String', 'Float'], DoMaterialSetShaderParameter);

  RegisterEngineFunction('ShaderFromHandle', 'TShader', ['Handle'], ['Integer'], DoShaderFromHandle);
  RegisterEngineFunction('ShaderHandle', 'Integer', ['Shader'], ['TShader'], DoShaderHandle);
  RegisterEngineFunction('ShaderVertexPath', 'String', ['Shader'], ['Integer'], DoShaderVertexPath);
  RegisterEngineFunction('ShaderFragmentPath', 'String', ['Shader'], ['Integer'], DoShaderFragmentPath);
  RegisterEngineFunction('ShaderUse', '', ['Shader'], ['Integer'], DoShaderUse);
  RegisterEngineFunction('ShaderReload', '', ['Shader'], ['Integer'], DoShaderReload);
  RegisterEngineFunction('ShaderSetUniformBoolean', '', ['Shader', 'Name', 'Value'], ['Integer', 'String', 'Boolean'], DoShaderSetUniformBoolean);
  RegisterEngineFunction('ShaderSetUniformInteger', '', ['Shader', 'Name', 'Value'], ['Integer', 'String', 'Integer'], DoShaderSetUniformInteger);
  RegisterEngineFunction('ShaderSetUniformFloat', '', ['Shader', 'Name', 'Value'], ['Integer', 'String', 'Float'], DoShaderSetUniformFloat);
  RegisterEngineFunction('ShaderSetUniformVector3', '', ['Shader', 'Name', 'Value'], ['Integer', 'String', 'TVector3'], DoShaderSetUniformVector3);
  RegisterEngineFunction('ShaderSetUniformVector4', '', ['Shader', 'Name', 'Value'], ['Integer', 'String', 'TVector4'], DoShaderSetUniformVector4);
  RegisterEngineFunction('ShaderSetUniformMatrix4', '', ['Shader', 'Name', 'Value'], ['Integer', 'String', 'TMatrix4'], DoShaderSetUniformMatrix4);

  RegisterEngineFunction('RendererProjectionMatrix', 'TMatrix4', [], [], DoRendererProjectionMatrix);
  RegisterEngineFunction('RendererViewMatrix', 'TMatrix4', [], [], DoRendererViewMatrix);
  RegisterEngineFunction('RendererViewProjectionMatrix', 'TMatrix4', [], [], DoRendererViewProjectionMatrix);
  RegisterEngineFunction('RendererShadowLightViewProjection', 'TMatrix4', [], [], DoRendererShadowLightViewProjection);
  RegisterEngineFunction('RendererShadowLightMatrix', 'TMatrix4', ['LightIndex'], ['Integer'], DoRendererShadowLightMatrix);
  RegisterEngineFunction('RendererSetBackgroundColor', '', ['Color'], ['TVector4'], DoRendererSetBackgroundColor);
  RegisterEngineFunction('RendererSetShadowEnabled', '', ['Enabled'], ['Boolean'], DoRendererSetShadowEnabled);
  RegisterEngineFunction('RendererSetShadowTarget', '', ['Target'], ['TVector3'], DoRendererSetShadowTarget);
  RegisterEngineFunction('RendererSetShadowDistance', '', ['Distance'], ['Float'], DoRendererSetShadowDistance);
  RegisterEngineFunction('RendererSetShadowArea', '', ['Area'], ['Float'], DoRendererSetShadowArea);
  RegisterEngineFunction('RendererSetShadowMapSize', '', ['Size'], ['Integer'], DoRendererSetShadowMapSize);
  RegisterEngineFunction('SkyDomeResetDefaults', '', [], [], DoSkyDomeResetDefaults);
  RegisterEngineFunction('SkyDomeBoolean', 'Boolean', ['Name'], ['String'], DoSkyDomeBoolean);
  RegisterEngineFunction('SkyDomeSetBoolean', '', ['Name', 'Value'], ['String', 'Boolean'], DoSkyDomeSetBoolean);
  RegisterEngineFunction('SkyDomeInteger', 'Integer', ['Name'], ['String'], DoSkyDomeInteger);
  RegisterEngineFunction('SkyDomeSetInteger', '', ['Name', 'Value'], ['String', 'Integer'], DoSkyDomeSetInteger);
  RegisterEngineFunction('SkyDomeFloat', 'Float', ['Name'], ['String'], DoSkyDomeFloat);
  RegisterEngineFunction('SkyDomeSetFloat', '', ['Name', 'Value'], ['String', 'Float'], DoSkyDomeSetFloat);
  RegisterEngineFunction('SkyDomeVector3', 'TVector3', ['Name'], ['String'], DoSkyDomeVector3);
  RegisterEngineFunction('SkyDomeSetVector3', '', ['Name', 'Value'], ['String', 'TVector3'], DoSkyDomeSetVector3);
  RegisterEngineFunction('SkyDomeVector4', 'TVector4', ['Name'], ['String'], DoSkyDomeVector4);
  RegisterEngineFunction('SkyDomeSetVector4', '', ['Name', 'Value'], ['String', 'TVector4'], DoSkyDomeSetVector4);

  RegisterEngineFunction('PhysicsBodyStatic', 'Integer', [], [], DoPhysicsBodyStatic);
  RegisterEngineFunction('PhysicsBodyDynamic', 'Integer', [], [], DoPhysicsBodyDynamic);
  RegisterEngineFunction('PhysicsBodyKinematic', 'Integer', [], [], DoPhysicsBodyKinematic);
  RegisterEngineFunction('PhysicsBodyCharacter', 'Integer', [], [], DoPhysicsBodyCharacter);
  RegisterEngineFunction('PhysicsBodyProjectile', 'Integer', [], [], DoPhysicsBodyProjectile);
  RegisterEngineFunction('PhysicsColliderAuto', 'Integer', [], [], DoPhysicsColliderAuto);
  RegisterEngineFunction('PhysicsColliderNone', 'Integer', [], [], DoPhysicsColliderNone);
  RegisterEngineFunction('PhysicsColliderSphere', 'Integer', [], [], DoPhysicsColliderSphere);
  RegisterEngineFunction('PhysicsColliderCapsule', 'Integer', [], [], DoPhysicsColliderCapsule);
  RegisterEngineFunction('PhysicsColliderAABB', 'Integer', [], [], DoPhysicsColliderAABB);
  RegisterEngineFunction('PhysicsColliderMesh', 'Integer', [], [], DoPhysicsColliderMesh);
  RegisterEngineFunction('PhysicsColliderConvexHull', 'Integer', [], [], DoPhysicsColliderConvexHull);
  RegisterEngineFunction('PhysicsBodyCount', 'Integer', [], [], DoPhysicsBodyCount);
  RegisterEngineFunction('PhysicsBody', 'Integer', ['Index'], ['Integer'], DoPhysicsBody);
  RegisterEngineFunction('PhysicsFindBody', 'Integer', ['Obj'], ['Integer'], DoPhysicsFindBody);
  RegisterEngineFunction('PhysicsAddBody', 'Integer', ['Obj', 'BodyType', 'ColliderKind'], ['Integer', 'Integer', 'Integer'], DoPhysicsAddBody);
  RegisterEngineFunction('PhysicsRemoveBody', '', ['Body'], ['Integer'], DoPhysicsRemoveBody);
  RegisterEngineFunction('PhysicsRemoveBodyForObject', '', ['Obj'], ['Integer'], DoPhysicsRemoveBodyForObject);
  RegisterEngineFunction('PhysicsClear', '', [], [], DoPhysicsClear);
  RegisterEngineFunction('PhysicsStep', '', ['DeltaTime'], ['Float'], DoPhysicsStep);
  RegisterEngineFunction('PhysicsEnsureNativeScene', '', [], [], DoPhysicsEnsureNativeScene);
  RegisterEngineFunction('PhysicsGravity', 'TVector3', [], [], DoPhysicsGravity);
  RegisterEngineFunction('PhysicsSetGravity', '', ['Gravity'], ['TVector3'], DoPhysicsSetGravity);
  RegisterEngineFunction('PhysicsGroundPlaneEnabled', 'Boolean', [], [], DoPhysicsGroundPlaneEnabled);
  RegisterEngineFunction('PhysicsSetGroundPlaneEnabled', '', ['Enabled'], ['Boolean'], DoPhysicsSetGroundPlaneEnabled);
  RegisterEngineFunction('PhysicsGroundHeight', 'Float', [], [], DoPhysicsGroundHeight);
  RegisterEngineFunction('PhysicsSetGroundHeight', '', ['Height'], ['Float'], DoPhysicsSetGroundHeight);
  RegisterEngineFunction('PhysicsApplyRadialImpulse', '', ['Center', 'Radius', 'Strength', 'IncludeStatic'], ['TVector3', 'Float', 'Float', 'Boolean'], DoPhysicsApplyRadialImpulse);
  RegisterEngineFunction('PhysicsRaycastHit', 'Boolean', ['StartPoint', 'Direction', 'MaxDistance'], ['TVector3', 'TVector3', 'Float'], DoPhysicsRaycastHit);
  RegisterEngineFunction('PhysicsRaycastPoint', 'TVector3', ['StartPoint', 'Direction', 'MaxDistance'], ['TVector3', 'TVector3', 'Float'], DoPhysicsRaycastPoint);
  RegisterEngineFunction('PhysicsRaycastNormal', 'TVector3', ['StartPoint', 'Direction', 'MaxDistance'], ['TVector3', 'TVector3', 'Float'], DoPhysicsRaycastNormal);
  RegisterEngineFunction('PhysicsRaycastBody', 'Integer', ['StartPoint', 'Direction', 'MaxDistance'], ['TVector3', 'TVector3', 'Float'], DoPhysicsRaycastBody);
  RegisterEngineFunction('PhysicsBodyObject', 'Integer', ['Body'], ['Integer'], DoPhysicsBodyObject);
  RegisterEngineFunction('PhysicsBodyType', 'Integer', ['Body'], ['Integer'], DoPhysicsBodyType);
  RegisterEngineFunction('PhysicsBodySetType', '', ['Body', 'BodyType'], ['Integer', 'Integer'], DoPhysicsBodySetType);
  RegisterEngineFunction('PhysicsBodyColliderKind', 'Integer', ['Body'], ['Integer'], DoPhysicsBodyColliderKind);
  RegisterEngineFunction('PhysicsBodySetColliderKind', '', ['Body', 'ColliderKind'], ['Integer', 'Integer'], DoPhysicsBodySetColliderKind);
  RegisterEngineFunction('PhysicsBodyBoolean', 'Boolean', ['Body', 'Name'], ['Integer', 'String'], DoPhysicsBodyBoolean);
  RegisterEngineFunction('PhysicsBodySetBoolean', '', ['Body', 'Name', 'Value'], ['Integer', 'String', 'Boolean'], DoPhysicsBodySetBoolean);
  RegisterEngineFunction('PhysicsBodyFloat', 'Float', ['Body', 'Name'], ['Integer', 'String'], DoPhysicsBodyFloat);
  RegisterEngineFunction('PhysicsBodySetFloat', '', ['Body', 'Name', 'Value'], ['Integer', 'String', 'Float'], DoPhysicsBodySetFloat);
  RegisterEngineFunction('PhysicsBodyVector3', 'TVector3', ['Body', 'Name'], ['Integer', 'String'], DoPhysicsBodyVector3);
  RegisterEngineFunction('PhysicsBodySetVector3', '', ['Body', 'Name', 'Value'], ['Integer', 'String', 'TVector3'], DoPhysicsBodySetVector3);
  RegisterEngineFunction('PhysicsBodyConfigureSphere', '', ['Body', 'Radius'], ['Integer', 'Float'], DoPhysicsBodyConfigureSphere);
  RegisterEngineFunction('PhysicsBodyConfigureCapsule', '', ['Body', 'Radius', 'HalfHeight'], ['Integer', 'Float', 'Float'], DoPhysicsBodyConfigureCapsule);
  RegisterEngineFunction('PhysicsBodyConfigureAABB', '', ['Body', 'HalfExtents'], ['Integer', 'TVector3'], DoPhysicsBodyConfigureAABB);
  RegisterEngineFunction('PhysicsBodyConfigureMesh', '', ['Body'], ['Integer'], DoPhysicsBodyConfigureMesh);
  RegisterEngineFunction('PhysicsBodyAutoFitCollider', '', ['Body'], ['Integer'], DoPhysicsBodyAutoFitCollider);
  RegisterEngineFunction('PhysicsBodyAddForce', '', ['Body', 'Force'], ['Integer', 'TVector3'], DoPhysicsBodyAddForce);
  RegisterEngineFunction('PhysicsBodyAddImpulse', '', ['Body', 'Impulse'], ['Integer', 'TVector3'], DoPhysicsBodyAddImpulse);
  RegisterEngineFunction('PhysicsBodyClearForces', '', ['Body'], ['Integer'], DoPhysicsBodyClearForces);
  RegisterEngineFunction('PhysicsBodyStop', '', ['Body'], ['Integer'], DoPhysicsBodyStop);
end;

end.
