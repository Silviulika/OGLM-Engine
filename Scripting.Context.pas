unit Scripting.Context;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections,
  Managers.Scene, Managers.Material,
  Renderer.Camera, Renderer.Light, Renderer.Mesh, Renderer.Renderer,
  Renderer.Shader, Renderer.Particles, Renderer.Billboards,
  Renderer.AnimatedSprites,
  Engine.Audio, Engine.Physics,
  Scripting.Serialization;

type
  TEngineScriptPrefabLoadCallback = function(const AFileName: string;
    AParent: TSceneObject): TSceneObject of object;
  TEngineScriptPrefabDestroyCallback = procedure(AObject: TSceneObject) of object;
  TEngineScriptLogCallback = procedure(const AMessage: string) of object;
  TEngineScriptSceneFileCallback = function(const AFileName: string;
    out AErrorMessage: string): Boolean of object;
  TEngineScriptShutdownCallback = procedure of object;


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
    SceneSaveCallback: TEngineScriptSceneFileCallback;
    SceneLoadCallback: TEngineScriptSceneFileCallback;
    ShutdownCallback: TEngineScriptShutdownCallback;
    EngineLastError: string;
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
      ALogCallback: TEngineScriptLogCallback = nil;
      ASceneSaveCallback: TEngineScriptSceneFileCallback = nil;
      ASceneLoadCallback: TEngineScriptSceneFileCallback = nil;
      AShutdownCallback: TEngineScriptShutdownCallback = nil);
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
    function AnimatedSpriteFromHandle(const AHandle: Integer): TAnimatedSprite;
    function AudioEmitterFromHandle(const AHandle: Integer): TSceneAudioEmitter;
    function PhysicsBodyFromHandle(const AHandle: Integer): TPhysicsBody;

    procedure BeginScript(const AScriptName, AEventName: string;
      ATargetKind: TEngineScriptTargetKind; const ATargetName: string;
      ATarget: TObject);
    procedure EndScript;
    function CurrentTargetHandle: Integer;
  end;

implementation

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
  ALogCallback: TEngineScriptLogCallback;
  ASceneSaveCallback: TEngineScriptSceneFileCallback;
  ASceneLoadCallback: TEngineScriptSceneFileCallback;
  AShutdownCallback: TEngineScriptShutdownCallback);
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
  SceneSaveCallback := ASceneSaveCallback;
  SceneLoadCallback := ASceneLoadCallback;
  ShutdownCallback := AShutdownCallback;
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

  for I := 0 to AObject.AnimatedSpriteCount - 1 do
    Forget(AObject.AnimatedSpriteItem[I]);

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

function TEngineScriptContext.AnimatedSpriteFromHandle(
  const AHandle: Integer): TAnimatedSprite;
var
  Obj: TObject;
begin
  if FObjects.TryGetValue(AHandle, Obj) and (Obj is TAnimatedSprite) then
    Exit(TAnimatedSprite(Obj));

  raise Exception.CreateFmt('Invalid animated sprite handle: %d', [AHandle]);
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


end.