unit Engine;

interface

uses
  Winapi.Windows,
  System.Classes,
  System.SysUtils,
  System.IOUtils,
  System.Math,
  Vcl.Controls,
  dglOpenGL,
  Neslib.FastMath,
  Engine.Paths,
  Engine.Types,
  Engine.Audio,
  Engine.Physics,
  Engine.Scripting,
  Managers.Material,
  Managers.Scene,
  Renderer.Camera,
  Renderer.Light,
  Renderer.Mesh,
  Renderer.Renderer,
  Renderer.Shader,
  Renderer.SkyDome;

type
  TEngineSettings = record
    Width: Integer;
    Height: Integer;
    FullScreen: Boolean;
    AntialiasingSamples: Integer;
    BackgroundColor: TVector4;
    FieldOfViewDegrees: Single;
    NearPlane: Single;
    FarPlane: Single;
    EnableFog: Boolean;
    EnableShadows: Boolean;
    EnableSkyDome: Boolean;
    EnableAudio: Boolean;
    EnableScripts: Boolean;

    class function Default: TEngineSettings; static;
  end;

  TGameEngine = class
  private
    FHost: TWinControl;
    FSettings: TEngineSettings;
    FRenderer: TRenderer;
    FSceneManager: TSceneManager;
    FRoot: TSceneObject;
    FSceneWorld: TSceneObject;
    FMainLight: TSceneObject;
    FCamera: TSceneObject;
    FMaterialLibraries: TMaterialLibraries;
    FDefaultShader: TShader;
    FActorShader: TShader;
    FTreeLeafShader: TShader;
    FTreeTrunkShader: TShader;
    FHeightFieldShader: TShader;
    FPhysicsWorld: TPhysicsWorld;
    FAudioEngine: TBassAudioEngine;
    FScriptManager: TEngineScriptManager;
    FCameraUp: TVector3;
    FPhysicsRunning: Boolean;
    FPrefabLoader: TEngineScriptPrefabLoadCallback;
    FPrefabDestroyer: TEngineScriptPrefabDestroyCallback;
    FScriptLogCallback: TEngineScriptLogCallback;
    FRunningScriptLifecycleEvent: Boolean;
    FLastScriptLifecycleError: string;

    procedure LoadCoreShaders;
    procedure ResetMaterialLibraries;
    procedure ConfigureRenderer;
    procedure LoadDefaultSceneIfPresent;
    function TryLoadSceneRenderSettingsFromStream(Stream: TStream): Boolean;
    function TryLoadScenePhysicsFromStream(Stream: TStream): Boolean;
    function TryLoadScenePhysicsCacheFromStream(Stream: TStream): Boolean;
    function TryLoadSceneMaterialsFromStream(Stream: TStream): Boolean;
    function TryLoadSceneScriptsFromStream(Stream: TStream): Boolean;
    procedure SaveSceneRenderSettingsToStream(Stream: TStream);
    procedure SaveScenePhysicsToStream(Stream: TStream);
    procedure SaveScenePhysicsCacheToStream(Stream: TStream);
    procedure SaveSceneScriptsToStream(Stream: TStream);
  public
    constructor Create(AHost: TWinControl); overload;
    constructor Create(AHost: TWinControl; const ASettings: TEngineSettings); overload;
    destructor Destroy; override;

    procedure Resize(AWidth, AHeight: Integer);
    procedure ActivateRenderContext;
    procedure ResetScene;
    procedure LoadSceneFromFile(const AFileName: string);
    function TryLoadSceneFromFile(const AFileName: string;
      out AErrorMessage: string): Boolean;
    procedure SaveSceneToFile(const AFileName: string;
      const AExcludedMaterialName: string = '');
    procedure Update(const DeltaTime, NewTime: Double);
    procedure StartPhysics;
    procedure PausePhysics;
    procedure StopPhysics;
    procedure ResetPhysics;
    function ResolveAudioPath(const AStoredPath: string): string;
    procedure LoadSceneAudioEmitter(AObject: TSceneObject;
      AEmitter: TSceneAudioEmitter);
    procedure ReleaseSceneAudioEmitter(AEmitter: TSceneAudioEmitter);
    procedure ReleaseSceneObjectAudio(Obj: TSceneObject);
    procedure UpdateSceneAudio;
    procedure SetScriptPrefabCallbacks(
      const APrefabLoader: TEngineScriptPrefabLoadCallback;
      const APrefabDestroyer: TEngineScriptPrefabDestroyCallback);
    procedure SetScriptLogCallback(const ALogCallback: TEngineScriptLogCallback);
    procedure Render;

    function EnsureDefaultMaterialLibrary: TMaterialLibrary;
    function DefaultRenderableMaterialName: string;
    function ShaderForMaterialType(AMaterialType: TMaterialType): TShader;
    procedure AssignShaderToMaterial(AMaterial: TMaterial);
    function MaterialIndexInLibrary(ALib: TMaterialLibrary;
      const AMaterialName: string): Integer;
    function FirstRenderableMaterialIndex(ALib: TMaterialLibrary): Integer;
    function FindFirstLightSceneObject(Obj: TSceneObject): TSceneObject;
    procedure LoadDefaultTextures;
    procedure ConfigureLightDefaults(Light: TLight; ALightType: TLightType);
    procedure CreateDefaultScene;
    procedure ClearSceneObjects;
    procedure RestoreSceneAfterLoad;
    procedure BindScriptEngine;
    procedure ExecuteScriptLifecycleEvent(const AEventName: string);
    procedure ApplyFrameUniformsToShader(Shader: TShader);
    procedure ApplyLightToShader(Shader: TShader; Light: TLight; Index: Integer);
    procedure ApplySceneLightsToShader(Shader: TShader);
    procedure OnUpdateShader(Shader: TShader);
    procedure MeshRenderHandler(Mesh: TMesh; Shader: TShader);
    procedure RendererBeforeRender(Sender: TObject);
    procedure RendererRender(Sender: TObject);
    procedure RendererAfterRender(Sender: TObject);
    procedure SetupRenderableMesh(Mesh: TMesh);

    property Host: TWinControl read FHost;
    property Settings: TEngineSettings read FSettings;
    property Renderer: TRenderer read FRenderer;
    property SceneManager: TSceneManager read FSceneManager;
    property Root: TSceneObject read FRoot;
    property SceneWorld: TSceneObject read FSceneWorld;
    property MainLight: TSceneObject read FMainLight;
    property Camera: TSceneObject read FCamera;
    property MaterialLibraries: TMaterialLibraries read FMaterialLibraries;
    property DefaultShader: TShader read FDefaultShader;
    property ActorShader: TShader read FActorShader;
    property TreeLeafShader: TShader read FTreeLeafShader;
    property TreeTrunkShader: TShader read FTreeTrunkShader;
    property HeightFieldShader: TShader read FHeightFieldShader;
    property PhysicsWorld: TPhysicsWorld read FPhysicsWorld;
    property PhysicsRunning: Boolean read FPhysicsRunning;
    property AudioEngine: TBassAudioEngine read FAudioEngine;
    property ScriptManager: TEngineScriptManager read FScriptManager;
    property LastScriptLifecycleError: string read FLastScriptLifecycleError;
  end;

function Create(AHost: TWinControl): TGameEngine; overload;
function Create(AHost: TWinControl; const ASettings: TEngineSettings): TGameEngine; overload;

implementation

const
  DEFAULT_ENGINE_SCENE_NAME = 'Scene';
  DEFAULT_ENGINE_MATERIAL_LIBRARY_NAME = 'fDefaultMaterialLib';
  DEFAULT_ENGINE_PBR_MATERIAL_NAME = 'DefaultPBRMaterial';
  DEFAULT_ENGINE_SCENE_FILE_NAME = 'Default.omescn';
  MAX_ENGINE_SHADER_LIGHTS = 8;
  SCENE_FILE_EXTENSION = '.omescn';
  SCENE_RENDER_SETTINGS_VERSION = 3;
  SCENE_RENDER_SETTINGS_MAGIC: array[0..7] of AnsiChar =
    ('O', 'M', 'E', 'R', 'N', 'D', '0', '1');
  SCENE_PHYSICS_VERSION = 1;
  SCENE_PHYSICS_MAGIC: array[0..7] of AnsiChar =
    ('O', 'M', 'E', 'P', 'H', 'Y', '0', '1');
  SCENE_PHYSICS_CACHE_VERSION = 1;
  SCENE_PHYSICS_CACHE_MAGIC: array[0..7] of AnsiChar =
    ('O', 'M', 'E', 'P', 'H', 'C', '0', '1');
  SCENE_SCRIPTS_VERSION = 1;
  SCENE_SCRIPTS_MAGIC: array[0..7] of AnsiChar =
    ('O', 'M', 'E', 'S', 'C', 'P', '0', '1');
  MATERIAL_LIBRARY_MAGIC: array[0..7] of AnsiChar =
    ('O', 'M', 'E', 'M', 'L', 'B', '0', '1');

function EngineMagicMatches(const A, B: array of AnsiChar): Boolean;
var
  I: Integer;
begin
  Result := Length(A) = Length(B);
  if not Result then
    Exit;

  for I := Low(A) to High(A) do
    if A[I] <> B[I - Low(A) + Low(B)] then
      Exit(False);
end;

function StreamStartsWithMagic(Stream: TStream; const ExpectedMagic: array of AnsiChar): Boolean;
var
  StartPos: Int64;
  Magic: array[0..7] of AnsiChar;
begin
  Result := False;
  if (Stream = nil) or ((Stream.Size - Stream.Position) < SizeOf(Magic)) then
    Exit;

  StartPos := Stream.Position;
  try
    Stream.ReadBuffer(Magic[0], SizeOf(Magic));
    Result := EngineMagicMatches(Magic, ExpectedMagic);
  finally
    Stream.Position := StartPos;
  end;
end;

function TryBeginSceneChunk(Stream: TStream; const ExpectedMagic: array of AnsiChar;
  ExpectedVersion: Integer; const ChunkName: string; out PayloadEnd: Int64): Boolean;
var
  StartPos: Int64;
  PayloadSize: Int64;
  Magic: array[0..7] of AnsiChar;
  Version: Integer;
begin
  Result := False;
  PayloadEnd := 0;
  if Stream = nil then
    Exit;

  StartPos := Stream.Position;
  if (Stream.Size - Stream.Position) < SizeOf(Magic) then
    Exit;

  Stream.ReadBuffer(Magic[0], SizeOf(Magic));
  if not EngineMagicMatches(Magic, ExpectedMagic) then
  begin
    Stream.Position := StartPos;
    Exit;
  end;

  Result := True;
  if (Stream.Size - Stream.Position) < (SizeOf(Version) + SizeOf(PayloadSize)) then
    raise Exception.CreateFmt('Invalid %s header.', [ChunkName]);

  Stream.ReadBuffer(Version, SizeOf(Version));
  Stream.ReadBuffer(PayloadSize, SizeOf(PayloadSize));
  if (Version < 1) or (Version > ExpectedVersion) then
    raise Exception.CreateFmt('Unsupported %s version: %d.', [ChunkName, Version]);
  if (PayloadSize < 0) or (PayloadSize > (Stream.Size - Stream.Position)) then
    raise Exception.CreateFmt('Invalid %s payload size.', [ChunkName]);

  PayloadEnd := Stream.Position + PayloadSize;
end;

function TrySkipSceneChunk(Stream: TStream; const ExpectedMagic: array of AnsiChar;
  ExpectedVersion: Integer; const ChunkName: string): Boolean;
var
  PayloadEnd: Int64;
begin
  Result := TryBeginSceneChunk(Stream, ExpectedMagic, ExpectedVersion,
    ChunkName, PayloadEnd);
  if Result then
    Stream.Position := PayloadEnd;
end;

{ TEngineSettings }

class function TEngineSettings.Default: TEngineSettings;
begin
  Result.Width := 1280;
  Result.Height := 720;
  Result.FullScreen := False;
  Result.AntialiasingSamples := 4;
  Result.BackgroundColor := Vector4(0.56, 0.73, 0.92, 1.0);
  Result.FieldOfViewDegrees := 45.0; // 60
  Result.NearPlane := 0.1;
  Result.FarPlane := 1000.0;
  Result.EnableFog := True;
  Result.EnableShadows := True;
  Result.EnableSkyDome := True;
  Result.EnableAudio := True;
  Result.EnableScripts := True;
end;

{ TGameEngine }

constructor TGameEngine.Create(AHost: TWinControl);
begin
  Create(AHost, TEngineSettings.Default);
end;

constructor TGameEngine.Create(AHost: TWinControl; const ASettings: TEngineSettings);
var
  WidthValue: Integer;
  HeightValue: Integer;
begin
  inherited Create;

  if AHost = nil then
    raise EArgumentNilException.Create('AHost');

  FHost := AHost;
  FSettings := ASettings;
  FCameraUp := Vector3(0, -1, 0);

  TEnginePaths.Initialize(ExtractFilePath(ParamStr(0)));
  TEnginePaths.EnsureDirectories;

  WidthValue := FSettings.Width;
  HeightValue := FSettings.Height;
  if WidthValue <= 0 then
    WidthValue := Max(1, FHost.ClientWidth);
  if HeightValue <= 0 then
    HeightValue := Max(1, FHost.ClientHeight);

  FRenderer := TRenderer.Create(FHost.Handle, 0, 0, WidthValue, HeightValue,
    FSettings.BackgroundColor, FSettings.AntialiasingSamples);
  FRenderer.ActivateContext;
  FRenderer.EmptyObjectMarkersEnabled := False;

  if FSettings.EnableScripts then
  begin
    FRenderer.OnBeforeRender := RendererBeforeRender;
    FRenderer.OnRender := RendererRender;
    FRenderer.OnAfterRender := RendererAfterRender;
  end;

  if FSettings.EnableAudio then
    FAudioEngine := TBassAudioEngine.Create;
  if FSettings.EnableScripts then
    FScriptManager := TEngineScriptManager.Create;

  if FSettings.EnableSkyDome then
  begin
    FRenderer.SkyDome := TSkyDome.Create;
    FRenderer.SkyDome.CloudCoverage := 0.23;
    FRenderer.SkyDome.CloudScale := 0.30;
    FRenderer.SkyDome.CloudOpacity := 0.70;
    FRenderer.SkyDome.TwinkleStars := False;
    FRenderer.SkyDome.StarSize := Vector2(0.045, 0.125);
    FRenderer.SkyDome.StarGlare := 0.45;
    FRenderer.SkyDome.StarIntensity := 0.95;
    FRenderer.SkyDome.StarDensity := 220.0;
  end;

  LoadCoreShaders;

  FMaterialLibraries := TMaterialLibraries.Create;
  EnsureDefaultMaterialLibrary;
  LoadDefaultTextures;

  ConfigureRenderer;

  FSceneManager := FRenderer.SceneManager;
  FRoot := FSceneManager.Root;
  FPhysicsWorld := TPhysicsWorld.Create(FRoot);

  CreateDefaultScene;
  BindScriptEngine;
  LoadDefaultSceneIfPresent;
end;

destructor TGameEngine.Destroy;
begin
  if Assigned(FRenderer) then
    FRenderer.ActivateContext;

  FreeAndNil(FScriptManager);
  FreeAndNil(FAudioEngine);
  FreeAndNil(FPhysicsWorld);
  FreeAndNil(FDefaultShader);
  FreeAndNil(FActorShader);
  FreeAndNil(FTreeLeafShader);
  FreeAndNil(FTreeTrunkShader);
  FreeAndNil(FHeightFieldShader);
  FreeAndNil(FMaterialLibraries);
  FreeAndNil(FRenderer);

  inherited Destroy;
end;

procedure TGameEngine.LoadDefaultSceneIfPresent;
var
  DefaultFileName: string;
  ErrorMessage: string;
begin
  DefaultFileName := TEnginePaths.Combine(TEnginePaths.DataDir,
    DEFAULT_ENGINE_SCENE_FILE_NAME);
  if FileExists(DefaultFileName) then
    TryLoadSceneFromFile(DefaultFileName, ErrorMessage);
end;

procedure TGameEngine.ConfigureRenderer;
begin
  FRenderer.InitFOV(DegToRad(FSettings.FieldOfViewDegrees), FSettings.NearPlane,
    FSettings.FarPlane);
  FRenderer.FogEnabled := FSettings.EnableFog;
  FRenderer.FogStart := 50;
  FRenderer.FogEnd := 200;
  FRenderer.ShadowEnabled := FSettings.EnableShadows;
  FRenderer.ShadowTarget := Vector3(0, 0, 0);
  FRenderer.ShadowAutoFit := True;
  FRenderer.ShadowFitPadding := 1.25;
  FRenderer.ShadowDistance := 35.0;
  FRenderer.ShadowArea := 24.0;
end;

procedure TGameEngine.LoadCoreShaders;
begin
  FDefaultShader := TShader.Create(TEnginePaths.Shader('PBR_POM_4.vert'),
    TEnginePaths.Shader('PBR_POM_4.frag'));
  FActorShader := TShader.Create(TEnginePaths.Shader('Actor_PBR.vert'),
    TEnginePaths.Shader('Actor_PBR.frag'));
  FTreeLeafShader := TShader.Create(TEnginePaths.Shader('PBR_POM_4.vert'),
    TEnginePaths.Shader('TreeLeaf.frag'));
  FTreeTrunkShader := TShader.Create(TEnginePaths.Shader('PBR_POM_4.vert'),
    TEnginePaths.Shader('TreeTrunk.frag'));
  FHeightFieldShader := TShader.Create(TEnginePaths.Shader('HeightField_MultiMaterial.vert'),
    TEnginePaths.Shader('HeightField_MultiMaterial.frag'));

  FDefaultShader.OnUpdateShader := OnUpdateShader;
  FActorShader.OnUpdateShader := OnUpdateShader;
  FTreeLeafShader.OnUpdateShader := OnUpdateShader;
  FTreeTrunkShader.OnUpdateShader := OnUpdateShader;
  FHeightFieldShader.OnUpdateShader := OnUpdateShader;

  FRenderer.LoadShadowShaderFromFile(TEnginePaths.Shader('ShadowDepth.vert'),
    TEnginePaths.Shader('ShadowDepth.frag'));
  FRenderer.LoadWaterShaderFromFile(TEnginePaths.Shader('Water.vert'),
    TEnginePaths.Shader('Water.frag'));
  FRenderer.LoadPostProcessShaderFromFile(TEnginePaths.Shader('PostProcessHDR.vert'),
    TEnginePaths.Shader('PostProcessHDR.frag'));
end;

function TGameEngine.EnsureDefaultMaterialLibrary: TMaterialLibrary;
begin
  if FMaterialLibraries = nil then
    FMaterialLibraries := TMaterialLibraries.Create;

  Result := FMaterialLibraries.GetMaterialLibrary(
    DEFAULT_ENGINE_MATERIAL_LIBRARY_NAME);
  if Result = nil then
  begin
    Result := TMaterialLibrary.Create;
    Result.Name := DEFAULT_ENGINE_MATERIAL_LIBRARY_NAME;
    FMaterialLibraries.AddMaterialLibrary(Result);
  end;
end;

function TGameEngine.DefaultRenderableMaterialName: string;
var
  Lib: TMaterialLibrary;
  I: Integer;
begin
  Lib := EnsureDefaultMaterialLibrary;
  if (Lib <> nil) and
     (Lib.GetMaterial(DEFAULT_ENGINE_PBR_MATERIAL_NAME) <> nil) then
    Exit(DEFAULT_ENGINE_PBR_MATERIAL_NAME);

  LoadDefaultTextures;
  if (Lib <> nil) and
     (Lib.GetMaterial(DEFAULT_ENGINE_PBR_MATERIAL_NAME) <> nil) then
    Exit(DEFAULT_ENGINE_PBR_MATERIAL_NAME);

  Result := '';
  if Lib = nil then
    Exit;
  for I := 0 to Lib.Count - 1 do
    if Assigned(Lib.Material[I]) and (Lib.Material[I].Materialtype <> mtShadow) then
      Exit(Lib.Material[I].Name);
end;

procedure TGameEngine.ResetMaterialLibraries;
begin
  if Assigned(FRenderer) then
    FRenderer.ActivateContext;

  FreeAndNil(FMaterialLibraries);
  FMaterialLibraries := TMaterialLibraries.Create;
  EnsureDefaultMaterialLibrary;
  LoadDefaultTextures;
end;

function TGameEngine.ShaderForMaterialType(AMaterialType: TMaterialType): TShader;
begin
  case AMaterialType of
    mtActor:
      Result := FActorShader;
    mtTreeLeaf:
      Result := FTreeLeafShader;
    mtTreeTrunk:
      Result := FTreeTrunkShader;
    mtHeightFieldMaterial:
      Result := FHeightFieldShader;
  else
    Result := FDefaultShader;
  end;
end;

procedure TGameEngine.AssignShaderToMaterial(AMaterial: TMaterial);
begin
  if AMaterial <> nil then
    AMaterial.Shader := ShaderForMaterialType(AMaterial.Materialtype);
end;

function TGameEngine.MaterialIndexInLibrary(ALib: TMaterialLibrary;
  const AMaterialName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  if (ALib = nil) or (Trim(AMaterialName) = '') then
    Exit;

  for I := 0 to ALib.Count - 1 do
    if Assigned(ALib.Material[I]) and SameText(ALib.Material[I].Name, AMaterialName) then
      Exit(I);
end;

function TGameEngine.FirstRenderableMaterialIndex(ALib: TMaterialLibrary): Integer;
var
  I: Integer;
begin
  Result := -1;
  if ALib = nil then
    Exit;

  for I := 0 to ALib.Count - 1 do
    if Assigned(ALib.Material[I]) and (ALib.Material[I].Materialtype <> mtShadow) then
      Exit(I);
end;

function TGameEngine.FindFirstLightSceneObject(Obj: TSceneObject): TSceneObject;
var
  I: Integer;
begin
  Result := nil;
  if Obj = nil then
    Exit;

  if Obj.LightsCount > 0 then
    Exit(Obj);

  for I := 0 to Obj.Count - 1 do
  begin
    Result := FindFirstLightSceneObject(Obj.ObjectList[I]);
    if Result <> nil then
      Exit;
  end;
end;

procedure TGameEngine.LoadDefaultTextures;
var
  I: Integer;
  Mat: TMaterial;
  Lib: TMaterialLibrary;
  Tex: TArray<TMaterialTexture>;

  procedure LoadTex(Index: Integer; const FileName, UniformName: string;
    SRGB: Boolean; InternalFormat: GLint; WrapMode: GLint);
  begin
    Tex[Index].LoadTexTGA(TEnginePaths.Texture(FileName), SRGB, UniformName,
      InternalFormat, WrapMode, False);
  end;

begin
  Lib := EnsureDefaultMaterialLibrary;
  if Lib = nil then
    Exit;

  if Lib.GetMaterial(DEFAULT_ENGINE_PBR_MATERIAL_NAME) = nil then
  begin
    Mat := TMaterial.Create(mtPBR);
    try
      Mat.Name := DEFAULT_ENGINE_PBR_MATERIAL_NAME;
      Mat.Shader := FDefaultShader;

      SetLength(Tex, 8);
      for I := 0 to High(Tex) do
      begin
        Tex[I].Texture.DiffuseColor := Vector3(0.5, 0.5, 0.5);
        Tex[I].Texture.SpecularColor := Vector3(1.0, 1.0, 1.0);
        Tex[I].Texture.Shininess := 64.0;
      end;

      LoadTex(0, 'DefaultColor.tga', 'albedoTexture', True, GL_SRGB8_ALPHA8, GL_REPEAT);
      LoadTex(1, 'DefaultNormal.tga', 'normalTexture', True, GL_RGBA8, GL_REPEAT);
      LoadTex(2, 'DefaultHeight.tga', 'heightTexture', True, GL_RGBA8, GL_REPEAT);
      LoadTex(3, 'DefaultMetallic.tga', 'metalnessTexture', True, GL_RGBA8, GL_REPEAT);
      LoadTex(4, 'DefaultRoughness.tga', 'roughnessTexture', True, GL_RGBA8, GL_REPEAT);
      LoadTex(5, 'DefaultEdge.tga', 'specularTexture', True, GL_RGBA8, GL_REPEAT);
      LoadTex(6, 'DefaultAmbient.tga', 'ambientOcclusionTexture', True, GL_RGBA8, GL_REPEAT);
      LoadTex(7, 'DefaultIrradiance.tga', 'specularBRDF_LUT', False, GL_RGBA8, GL_CLAMP_TO_EDGE);

      Mat.AddTextures(Tex);
      Lib.AddMaterial(Mat);
      Mat := nil;
    finally
      Mat.Free;
    end;
  end;

end;

procedure TGameEngine.ConfigureLightDefaults(Light: TLight; ALightType: TLightType);
begin
  if Light = nil then
    Exit;

  Light.Enabled := True;
  Light.LightType := ALightType;
  Light.Ambient := Vector3(0.04, 0.04, 0.04);
  Light.Diffuse := Vector3(3.0, 3.0, 3.0);
  Light.Specular := Vector3(1.0, 1.0, 1.0);
  Light.TargetPosition := Vector3(0, 0, 0);
  Light.UseTarget := ALightType in [ltDirectional, ltSpot];
  Light.ConstantAttenuation := 1.0;
  Light.LinearAttenuation := 0.09;
  Light.QuadraticAttenuation := 0.032;
  Light.SpotCutoff := DegToRad(30.0);
  Light.SpotExponent := 1.0;
  Light.CastShadows := ALightType <> ltPoint;
  Light.ShadowStrength := 0.90;

  case ALightType of
    ltDirectional:
      Light.Name := 'Directional Light';
    ltPoint:
      begin
        Light.Name := 'Point Light';
        Light.Diffuse := Vector3(2.0, 2.0, 2.0);
      end;
    ltSpot:
      Light.Name := 'Spot Light';
  end;
end;

procedure TGameEngine.ClearSceneObjects;
var
  Obj: TSceneObject;
begin
  FPhysicsRunning := False;
  if Assigned(FPhysicsWorld) then
    FPhysicsWorld.Clear;
  if Assigned(FAudioEngine) then
    FAudioEngine.ClearSounds;

  if FRoot = nil then
    Exit;

  while FRoot.Count > 0 do
  begin
    Obj := FRoot.ObjectList[FRoot.Count - 1];
    Obj.Free;
  end;

  FSceneWorld := nil;
  FMainLight := nil;
  FCamera := nil;
end;

procedure TGameEngine.CreateDefaultScene;
begin
  ClearSceneObjects;

  if Assigned(FSceneManager) then
    FSceneManager.Name := DEFAULT_ENGINE_SCENE_NAME;

  FSceneWorld := TSceneObject.Create(FRoot);
  FSceneWorld.Name := DEFAULT_ENGINE_SCENE_NAME;

  FMainLight := TSceneObject.Create(FRoot);
  FMainLight.Name := 'Light_1';
  FMainLight.CreateLight;
  FMainLight.Position := Vector3(10, 10.0, 10.0);
  FMainLight.Rotation := Vector3(DegToRad(-45), DegToRad(35), 0);
  ConfigureLightDefaults(FMainLight.Light[0], ltDirectional);

  FCamera := TSceneObject.Create(FRoot);
  FCamera.Name := 'Camera';
  FCamera.CreateCamera;
  FCamera.Camera.LookAt(Vector3(5, 5, -11), Vector3(0, 0, 0), FCameraUp);
  FCamera.AudioListener := True;

  FRenderer.ActiveCamera := FCamera;
  FRenderer.ShadowLight := FMainLight;
  FRenderer.ShadowTarget := Vector3(0, 0, 0);

  if Assigned(FScriptManager) then
  begin
    FScriptManager.Clear;
    BindScriptEngine;
  end;
end;

procedure TGameEngine.RestoreSceneAfterLoad;
var
  DefaultLib: TMaterialLibrary;

  function FindMaterialLibraryByMaterialName(const MaterialName: string): TMaterialLibrary;
  var
    I: Integer;
    Candidate: TMaterialLibrary;
  begin
    Result := nil;
    if (FMaterialLibraries = nil) or (Trim(MaterialName) = '') then
      Exit;

    for I := 0 to FMaterialLibraries.Count - 1 do
    begin
      Candidate := FMaterialLibraries.MaterialLibrary[I];
      if (Candidate <> nil) and (MaterialIndexInLibrary(Candidate, MaterialName) >= 0) then
        Exit(Candidate);
    end;
  end;

  function ResolveMeshMaterialLibrary(Mesh: TMesh;
    const MaterialName: string): TMaterialLibrary;
  begin
    Result := nil;
    if Mesh = nil then
      Exit;

    if (Mesh.MaterialLibrary <> nil) and
       ((MaterialName = '') or
        (MaterialIndexInLibrary(Mesh.MaterialLibrary, MaterialName) >= 0)) then
      Exit(Mesh.MaterialLibrary);

    if (FMaterialLibraries <> nil) and (Trim(Mesh.MaterialLibraryName) <> '') then
    begin
      Result := FMaterialLibraries.GetMaterialLibrary(Mesh.MaterialLibraryName);
      if (Result <> nil) and
         ((MaterialName = '') or (MaterialIndexInLibrary(Result, MaterialName) >= 0)) then
        Exit;
    end;

    Result := FindMaterialLibraryByMaterialName(MaterialName);
    if Result = nil then
      Result := DefaultLib;
  end;

  procedure RestoreObject(Obj: TSceneObject);
  var
    I: Integer;
    Mesh: TMesh;
    MaterialName: string;
    MeshLib: TMaterialLibrary;
    FallbackIndex: Integer;
  begin
    if Obj = nil then
      Exit;

    for I := 0 to Obj.MeshList.Count - 1 do
    begin
      Mesh := Obj.MeshList.Item[I];
      if Mesh = nil then
        Continue;

      Mesh.OnRender := MeshRenderHandler;
      MaterialName := Mesh.LibMaterialname;
      MeshLib := ResolveMeshMaterialLibrary(Mesh, MaterialName);
      if MeshLib = nil then
        MeshLib := DefaultLib;

      if (MaterialName = '') or (MaterialIndexInLibrary(MeshLib, MaterialName) < 0) then
      begin
        FallbackIndex := FirstRenderableMaterialIndex(MeshLib);
        if (FallbackIndex < 0) and (MeshLib <> DefaultLib) then
        begin
          MeshLib := DefaultLib;
          FallbackIndex := FirstRenderableMaterialIndex(MeshLib);
        end;

        if FallbackIndex >= 0 then
          MaterialName := MeshLib.Material[FallbackIndex].Name
        else
          MaterialName := DEFAULT_ENGINE_PBR_MATERIAL_NAME;
      end;

      Mesh.MaterialLibrary := MeshLib;
      Mesh.LibMaterialname := MaterialName;
    end;

    Obj.UpdateBoundingRadiusFromMesh;
    for I := 0 to Obj.AudioEmitterCount - 1 do
      LoadSceneAudioEmitter(Obj, Obj.AudioEmitterItem[I]);
    for I := 0 to Obj.Count - 1 do
      RestoreObject(Obj.ObjectList[I]);
  end;

begin
  if FSceneManager = nil then
    Exit;

  FRoot := FSceneManager.Root;
  if Assigned(FPhysicsWorld) then
    FPhysicsWorld.SceneRoot := FRoot;
  LoadDefaultTextures;
  DefaultLib := EnsureDefaultMaterialLibrary;

  FSceneWorld := FSceneManager.FindSceneObject(DEFAULT_ENGINE_SCENE_NAME);
  if FSceneWorld = nil then
  begin
    FSceneWorld := TSceneObject.Create(FRoot);
    FSceneWorld.Name := DEFAULT_ENGINE_SCENE_NAME;
  end;

  FCamera := FSceneManager.FindCamera;
  if FCamera = nil then
  begin
    FCamera := TSceneObject.Create(FRoot);
    FCamera.Name := 'Camera';
    FCamera.CreateCamera;
    FCamera.Camera.LookAt(Vector3(0, 0, -11), Vector3(0, 0, 0), FCameraUp);
  end;
  FCamera.AudioListener := True;

  FMainLight := FindFirstLightSceneObject(FRoot);
  if FMainLight = nil then
  begin
    FMainLight := TSceneObject.Create(FRoot);
    FMainLight.Name := 'Light_1';
    FMainLight.CreateLight;
    FMainLight.Position := Vector3(10, 10.0, 10.0);
    ConfigureLightDefaults(FMainLight.Light[0], ltDirectional);
  end;

  RestoreObject(FRoot);
  FSceneManager.Update;

  if Assigned(FRenderer) then
  begin
    FRenderer.ActiveCamera := FCamera;
    FRenderer.ShadowLight := FMainLight;
    FRenderer.ShadowTarget := Vector3(0, 0, 0);
  end;
end;

function TGameEngine.TryLoadSceneRenderSettingsFromStream(Stream: TStream): Boolean;
var
  PayloadEnd: Int64;
  BoolValue: Boolean;
  IntValue: Integer;
  FloatValue: Single;
  ColorValue: TVector4;
  HasSkyDome: Boolean;

  procedure RequirePayloadBytes(ByteCount: Int64);
  begin
    if (ByteCount < 0) or ((PayloadEnd - Stream.Position) < ByteCount) then
      raise Exception.Create('Invalid scene render settings block.');
  end;

begin
  Result := TryBeginSceneChunk(Stream, SCENE_RENDER_SETTINGS_MAGIC,
    SCENE_RENDER_SETTINGS_VERSION, 'scene render settings', PayloadEnd);
  if not Result then
    Exit;

  try
    if FRenderer = nil then
      Exit;

    RequirePayloadBytes(SizeOf(BoolValue));
    Stream.ReadBuffer(BoolValue, SizeOf(BoolValue));
    FRenderer.HDREnabled := BoolValue;

    RequirePayloadBytes(SizeOf(IntValue));
    Stream.ReadBuffer(IntValue, SizeOf(IntValue));
    IntValue := System.Math.EnsureRange(IntValue,
      Ord(Low(TToneMappingMode)), Ord(High(TToneMappingMode)));
    FRenderer.ToneMappingMode := TToneMappingMode(IntValue);

    RequirePayloadBytes(SizeOf(FloatValue));
    Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
    FRenderer.ToneExposure := System.Math.EnsureRange(FloatValue, 0.0, 16.0);

    RequirePayloadBytes(SizeOf(FloatValue));
    Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
    FRenderer.ToneGamma := System.Math.EnsureRange(FloatValue, 0.1, 5.0);

    RequirePayloadBytes(SizeOf(BoolValue));
    Stream.ReadBuffer(BoolValue, SizeOf(BoolValue));
    FRenderer.GodRaysEnabled := BoolValue;

    RequirePayloadBytes(SizeOf(IntValue));
    Stream.ReadBuffer(IntValue, SizeOf(IntValue));
    FRenderer.GodRaySamples := System.Math.EnsureRange(IntValue, 1, 128);

    RequirePayloadBytes(SizeOf(FloatValue));
    Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
    FRenderer.GodRayDensity := System.Math.EnsureRange(FloatValue, 0.0, 3.0);

    RequirePayloadBytes(SizeOf(FloatValue));
    Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
    FRenderer.GodRayExposure := System.Math.EnsureRange(FloatValue, 0.0, 4.0);

    RequirePayloadBytes(SizeOf(FloatValue));
    Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
    FRenderer.GodRayDecay := System.Math.EnsureRange(FloatValue, 0.0, 1.0);

    RequirePayloadBytes(SizeOf(FloatValue));
    Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
    FRenderer.GodRayWeight := System.Math.EnsureRange(FloatValue, 0.0, 2.0);

    RequirePayloadBytes(SizeOf(FloatValue));
    Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
    FRenderer.GodRayIntensity := System.Math.EnsureRange(FloatValue, 0.0, 8.0);

    { Version 2 added SkyDome and version 3 added fog. Checking the remaining
      payload keeps the reader compatible with all historical scene files. }
    if (PayloadEnd - Stream.Position) >= SizeOf(HasSkyDome) then
    begin
      Stream.ReadBuffer(HasSkyDome, SizeOf(HasSkyDome));
      if HasSkyDome then
      begin
        if FRenderer.SkyDome = nil then
          FRenderer.SkyDome := TSkyDome.Create;
        FRenderer.SkyDome.LoadFromStream(Stream);
      end
      else
        FRenderer.SkyDome := nil;
    end;

    if (PayloadEnd - Stream.Position) >=
       (SizeOf(BoolValue) + SizeOf(ColorValue) + (3 * SizeOf(FloatValue))) then
    begin
      Stream.ReadBuffer(BoolValue, SizeOf(BoolValue));
      FRenderer.FogEnabled := BoolValue;

      Stream.ReadBuffer(ColorValue, SizeOf(ColorValue));
      FRenderer.FogColor := Vector4(
        System.Math.EnsureRange(ColorValue.X, 0.0, 1.0),
        System.Math.EnsureRange(ColorValue.Y, 0.0, 1.0),
        System.Math.EnsureRange(ColorValue.Z, 0.0, 1.0),
        System.Math.EnsureRange(ColorValue.W, 0.0, 1.0));

      Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
      FRenderer.FogDensity := System.Math.EnsureRange(FloatValue, 0.0, 1.0);
      Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
      FRenderer.FogStart := System.Math.Max(0.0, FloatValue);
      Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
      FRenderer.FogEnd := System.Math.Max(FRenderer.FogStart, FloatValue);
    end;
  finally
    Stream.Position := PayloadEnd;
  end;
end;

function TGameEngine.TryLoadScenePhysicsFromStream(Stream: TStream): Boolean;
var
  PayloadEnd: Int64;
  BodyCountValue: Integer;
  I: Integer;
  Obj: TSceneObject;
  Body: TPhysicsBody;
  GravityValue: TVector3;
  GroundNormalValue: TVector3;
  FloatValue: Single;
  IntValue: Integer;
  BoolValue: Boolean;
  State: TPhysicsBodyState;

  procedure RequirePayloadBytes(ByteCount: Int64);
  begin
    if (ByteCount < 0) or ((PayloadEnd - Stream.Position) < ByteCount) then
      raise Exception.Create('Invalid scene physics block.');
  end;

  function ReadObjectPath: TSceneObject;
  var
    CountValue: Integer;
    Index: Integer;
    PathIndex: Integer;
  begin
    Result := FRoot;

    RequirePayloadBytes(SizeOf(CountValue));
    Stream.ReadBuffer(CountValue, SizeOf(CountValue));
    if (CountValue < 0) or (CountValue > 4096) then
      raise Exception.Create('Invalid physics object path.');

    for PathIndex := 0 to CountValue - 1 do
    begin
      RequirePayloadBytes(SizeOf(Index));
      Stream.ReadBuffer(Index, SizeOf(Index));

      if (Result <> nil) and (Index >= 0) and (Index < Result.Count) then
        Result := Result.ObjectList[Index]
      else
        Result := nil;
    end;
  end;

  function ReadPhysicsBodyState: TPhysicsBodyState;
  var
    BodyTypeValue: Integer;
    ColliderValue: Integer;
  begin
    RequirePayloadBytes(SizeOf(BodyTypeValue) + SizeOf(ColliderValue));
    Stream.ReadBuffer(BodyTypeValue, SizeOf(BodyTypeValue));
    Stream.ReadBuffer(ColliderValue, SizeOf(ColliderValue));

    if (BodyTypeValue < Ord(Low(TPhysicsBodyType))) or
       (BodyTypeValue > Ord(High(TPhysicsBodyType))) then
      raise Exception.Create('Invalid physics body type in scene physics block.');

    if (ColliderValue < Ord(Low(TPhysicsColliderKind))) or
       (ColliderValue > Ord(High(TPhysicsColliderKind))) then
      raise Exception.Create('Invalid physics collider type in scene physics block.');

    Result.BodyType := TPhysicsBodyType(BodyTypeValue);
    Result.ColliderKind := TPhysicsColliderKind(ColliderValue);

    RequirePayloadBytes(SizeOf(Result.Enabled));
    Stream.ReadBuffer(Result.Enabled, SizeOf(Result.Enabled));
    RequirePayloadBytes(SizeOf(Result.CollisionResponse));
    Stream.ReadBuffer(Result.CollisionResponse, SizeOf(Result.CollisionResponse));
    RequirePayloadBytes(SizeOf(Result.UseGravity));
    Stream.ReadBuffer(Result.UseGravity, SizeOf(Result.UseGravity));
    RequirePayloadBytes(SizeOf(Result.Mass));
    Stream.ReadBuffer(Result.Mass, SizeOf(Result.Mass));
    RequirePayloadBytes(SizeOf(Result.Restitution));
    Stream.ReadBuffer(Result.Restitution, SizeOf(Result.Restitution));
    RequirePayloadBytes(SizeOf(Result.LinearDamping));
    Stream.ReadBuffer(Result.LinearDamping, SizeOf(Result.LinearDamping));
    RequirePayloadBytes(SizeOf(Result.GravityScale));
    Stream.ReadBuffer(Result.GravityScale, SizeOf(Result.GravityScale));
    RequirePayloadBytes(SizeOf(Result.Velocity));
    Stream.ReadBuffer(Result.Velocity, SizeOf(Result.Velocity));
    RequirePayloadBytes(SizeOf(Result.AngularVelocity));
    Stream.ReadBuffer(Result.AngularVelocity, SizeOf(Result.AngularVelocity));
    RequirePayloadBytes(SizeOf(Result.AngularDamping));
    Stream.ReadBuffer(Result.AngularDamping, SizeOf(Result.AngularDamping));
    RequirePayloadBytes(SizeOf(Result.Radius));
    Stream.ReadBuffer(Result.Radius, SizeOf(Result.Radius));
    RequirePayloadBytes(SizeOf(Result.HalfHeight));
    Stream.ReadBuffer(Result.HalfHeight, SizeOf(Result.HalfHeight));
    RequirePayloadBytes(SizeOf(Result.AABBHalfExtents));
    Stream.ReadBuffer(Result.AABBHalfExtents, SizeOf(Result.AABBHalfExtents));
    RequirePayloadBytes(SizeOf(Result.StepHeight));
    Stream.ReadBuffer(Result.StepHeight, SizeOf(Result.StepHeight));
  end;

begin
  Result := TryBeginSceneChunk(Stream, SCENE_PHYSICS_MAGIC, SCENE_PHYSICS_VERSION,
    'scene physics', PayloadEnd);
  if not Result then
    Exit;

  try
    if FPhysicsWorld = nil then
      FPhysicsWorld := TPhysicsWorld.Create(FRoot);

    FPhysicsWorld.Clear;
    FPhysicsWorld.SceneRoot := FRoot;

    RequirePayloadBytes(SizeOf(GravityValue));
    Stream.ReadBuffer(GravityValue, SizeOf(GravityValue));
    FPhysicsWorld.Gravity := GravityValue;

    RequirePayloadBytes(SizeOf(FloatValue));
    Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
    FPhysicsWorld.GlobalDamping := System.Math.EnsureRange(FloatValue, 0.0, 1.0);

    RequirePayloadBytes(SizeOf(FloatValue));
    Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
    FPhysicsWorld.MaxSubStep := System.Math.EnsureRange(FloatValue, 1.0 / 1000.0, 1.0 / 10.0);

    RequirePayloadBytes(SizeOf(IntValue));
    Stream.ReadBuffer(IntValue, SizeOf(IntValue));
    FPhysicsWorld.MaxSubSteps := System.Math.EnsureRange(IntValue, 1, 64);

    RequirePayloadBytes(SizeOf(IntValue));
    Stream.ReadBuffer(IntValue, SizeOf(IntValue));
    FPhysicsWorld.SolverIterations := System.Math.EnsureRange(IntValue, 1, 128);

    RequirePayloadBytes(SizeOf(BoolValue));
    Stream.ReadBuffer(BoolValue, SizeOf(BoolValue));
    FPhysicsWorld.GroundPlaneEnabled := BoolValue;

    RequirePayloadBytes(SizeOf(FloatValue));
    Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
    FPhysicsWorld.GroundHeight := FloatValue;

    RequirePayloadBytes(SizeOf(GroundNormalValue));
    Stream.ReadBuffer(GroundNormalValue, SizeOf(GroundNormalValue));
    FPhysicsWorld.GroundNormal := GroundNormalValue;

    RequirePayloadBytes(SizeOf(FloatValue));
    Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
    FPhysicsWorld.CollisionSlop := System.Math.EnsureRange(FloatValue, 0.0, 1.0);

    RequirePayloadBytes(SizeOf(BodyCountValue));
    Stream.ReadBuffer(BodyCountValue, SizeOf(BodyCountValue));
    if (BodyCountValue < 0) or (BodyCountValue > 100000) then
      raise Exception.Create('Invalid physics body count in scene physics block.');

    for I := 0 to BodyCountValue - 1 do
    begin
      Obj := ReadObjectPath;
      State := ReadPhysicsBodyState;

      if Obj = nil then
        Continue;

      Body := FPhysicsWorld.AddBody(Obj, State.BodyType, State.ColliderKind);
      Body.ApplyState(State);
    end;
  finally
    Stream.Position := PayloadEnd;
  end;
end;

function TGameEngine.TryLoadScenePhysicsCacheFromStream(Stream: TStream): Boolean;
var
  PayloadEnd: Int64;
  BodyCountValue: Integer;
  I: Integer;
  Obj: TSceneObject;
  Signature: UInt64;
  CacheSize: Int64;
  Data: TBytes;

  procedure RequirePayloadBytes(ByteCount: Int64);
  begin
    if (ByteCount < 0) or ((PayloadEnd - Stream.Position) < ByteCount) then
      raise Exception.Create('Invalid scene physics cache block.');
  end;

  function ReadObjectPath: TSceneObject;
  var
    CountValue: Integer;
    Index: Integer;
    PathIndex: Integer;
  begin
    Result := FRoot;
    RequirePayloadBytes(SizeOf(CountValue));
    Stream.ReadBuffer(CountValue, SizeOf(CountValue));
    if (CountValue < 0) or (CountValue > 4096) then
      raise Exception.Create('Invalid physics cache object path.');

    for PathIndex := 0 to CountValue - 1 do
    begin
      RequirePayloadBytes(SizeOf(Index));
      Stream.ReadBuffer(Index, SizeOf(Index));
      if (Result <> nil) and (Index >= 0) and (Index < Result.Count) then
        Result := Result.ObjectList[Index]
      else
        Result := nil;
    end;
  end;

begin
  Result := TryBeginSceneChunk(Stream, SCENE_PHYSICS_CACHE_MAGIC,
    SCENE_PHYSICS_CACHE_VERSION, 'scene physics cache', PayloadEnd);
  if not Result then
    Exit;

  try
    if FPhysicsWorld = nil then
      FPhysicsWorld := TPhysicsWorld.Create(FRoot);
    FPhysicsWorld.SceneRoot := FRoot;

    RequirePayloadBytes(SizeOf(BodyCountValue));
    Stream.ReadBuffer(BodyCountValue, SizeOf(BodyCountValue));
    if (BodyCountValue < 0) or (BodyCountValue > 100000) then
      raise Exception.Create('Invalid physics cache count in scene stream.');

    for I := 0 to BodyCountValue - 1 do
    begin
      Obj := ReadObjectPath;

      RequirePayloadBytes(SizeOf(Signature));
      Stream.ReadBuffer(Signature, SizeOf(Signature));
      RequirePayloadBytes(SizeOf(CacheSize));
      Stream.ReadBuffer(CacheSize, SizeOf(CacheSize));
      if (CacheSize < 0) or (CacheSize > MaxInt) then
        raise Exception.Create('Invalid physics cache payload size in scene stream.');

      RequirePayloadBytes(CacheSize);
      SetLength(Data, Integer(CacheSize));
      if CacheSize > 0 then
        Stream.ReadBuffer(Data[0], CacheSize);

      if (Obj <> nil) and (Signature <> 0) and (Length(Data) > 0) then
        FPhysicsWorld.StoreCookedMeshCache(Obj, Signature, Data);
    end;
  finally
    Stream.Position := PayloadEnd;
  end;
end;

function TGameEngine.TryLoadSceneMaterialsFromStream(Stream: TStream): Boolean;
var
  I, J: Integer;
  Lib: TMaterialLibrary;
begin
  Result := False;
  if (Stream = nil) or (Stream.Position >= Stream.Size) or
     (not StreamStartsWithMagic(Stream, MATERIAL_LIBRARY_MAGIC)) then
    Exit;

  if FMaterialLibraries = nil then
    FMaterialLibraries := TMaterialLibraries.Create;

  FMaterialLibraries.LoadFromStream(Stream, FDefaultShader);
  for I := 0 to FMaterialLibraries.Count - 1 do
  begin
    Lib := FMaterialLibraries.MaterialLibrary[I];
    if Lib = nil then
      Continue;

    for J := 0 to Lib.Count - 1 do
      AssignShaderToMaterial(Lib.Material[J]);
  end;

  // Keep loaded bindings intact while restoring the engine-reserved material
  // used exclusively by meshes created after the scene is open.
  LoadDefaultTextures;

  Result := True;
end;

function TGameEngine.TryLoadSceneScriptsFromStream(Stream: TStream): Boolean;
var
  PayloadEnd: Int64;
begin
  Result := TryBeginSceneChunk(Stream, SCENE_SCRIPTS_MAGIC,
    SCENE_SCRIPTS_VERSION, 'scene scripts', PayloadEnd);
  if not Result then
    Exit;

  try
    if not FSettings.EnableScripts then
      Exit;

    if FScriptManager = nil then
      FScriptManager := TEngineScriptManager.Create;

    if PayloadEnd > Stream.Position then
      FScriptManager.LoadFromStream(Stream)
    else
      FScriptManager.Clear;

    BindScriptEngine;
  finally
    Stream.Position := PayloadEnd;
  end;
end;

procedure TGameEngine.BindScriptEngine;
begin
  if not FSettings.EnableScripts then
    Exit;

  if FScriptManager = nil then
    FScriptManager := TEngineScriptManager.Create;

  FScriptManager.BindEngine(FRenderer, FSceneManager, EnsureDefaultMaterialLibrary,
    DefaultRenderableMaterialName, MeshRenderHandler, FPhysicsWorld, FAudioEngine,
    FPrefabLoader, FPrefabDestroyer, FScriptLogCallback);
end;

procedure TGameEngine.ExecuteScriptLifecycleEvent(const AEventName: string);
var
  RunResult: TEngineScriptExecutionResult;
begin
  if (FScriptManager = nil) or FRunningScriptLifecycleEvent then
    Exit;

  FRunningScriptLifecycleEvent := True;
  try
    BindScriptEngine;
    RunResult := FScriptManager.ExecuteLifecycleEvent(AEventName);
    if RunResult.Success then
      FLastScriptLifecycleError := ''
    else
      FLastScriptLifecycleError := RunResult.Messages;
  finally
    FRunningScriptLifecycleEvent := False;
  end;
end;

procedure TGameEngine.ApplyFrameUniformsToShader(Shader: TShader);
var
  RenderCamera: TSceneObject;
begin
  if (Shader = nil) or (FRenderer = nil) then
    Exit;

  RenderCamera := FRenderer.ActiveCamera;
  if RenderCamera = nil then
    RenderCamera := FCamera;

  if (RenderCamera = nil) or (RenderCamera.Camera = nil) then
    Exit;

  Shader.Use;
  Shader.SetUniform('eyePosition', RenderCamera.Camera.Position);
  Shader.SetUniform('viewProjection',
    FRenderer.ProjectionMatrix * RenderCamera.Camera.ViewMatrix);
  Shader.SetUniform('useFog', GLint(Ord(FRenderer.FogEnabled)));
  Shader.SetUniform('fogColor', FRenderer.EffectiveFogColor);
  Shader.SetUniform('fogStart', FRenderer.FogStart);
  Shader.SetUniform('fogEnd', FRenderer.FogEnd);
  Shader.SetUniform('fogDensity', FRenderer.FogDensity);
  Shader.SetUniform('usePostToneMapping', GLint(Ord(FRenderer.HDRPostProcessActive)));

  if FRenderer.SceneClipPlaneEnabled then
  begin
    Shader.SetUniform('useClipPlane', GLint(1));
    Shader.SetUniform('clipPlane', FRenderer.SceneClipPlane);
  end
  else
  begin
    Shader.SetUniform('useClipPlane', GLint(0));
    Shader.SetUniform('clipPlane', Vector4(0.0, 1.0, 0.0, 0.0));
  end;

  ApplySceneLightsToShader(Shader);
  Shader.SetUniform('lightSpaceMatrix', FRenderer.ShadowLightViewProjection);

  if FRenderer.ShadowEnabled and (FRenderer.ShadowDepthTexture <> 0) and
     (FRenderer.ShadowMapCount > 0) then
  begin
    glActiveTexture(GL_TEXTURE8);
    glBindTexture(GL_TEXTURE_2D_ARRAY, FRenderer.ShadowDepthTexture);

    Shader.SetUniform('shadowMap', GLint(8));
    Shader.SetUniform('useShadowMap', GLint(1));
  end
  else
  begin
    Shader.SetUniform('useShadowMap', GLint(0));
    Shader.SetUniform('shadowLightIndex', GLint(-1));
    Shader.SetUniform('shadowStrength', GLfloat(0.0));
  end;
end;

procedure TGameEngine.ApplyLightToShader(Shader: TShader; Light: TLight; Index: Integer);
var
  Prefix: string;
  TypeInt: Integer;
  CosCutoff: Single;
  Direction: TVector3;
begin
  if Shader = nil then
    Exit;

  Prefix := Format('lights[%d].', [Index]);

  if Light = nil then
  begin
    Shader.SetUniform(Prefix + 'enabled', 0);
    Exit;
  end;

  case Light.LightType of
    ltDirectional:
      TypeInt := 0;
    ltPoint:
      TypeInt := 1;
    ltSpot:
      TypeInt := 2;
  else
    TypeInt := 0;
  end;

  Shader.SetUniform(Prefix + 'enabled', Ord(Light.Enabled));
  Shader.SetUniform(Prefix + 'type', TypeInt);
  Shader.SetUniform(Prefix + 'ambient', Light.Ambient);
  Shader.SetUniform(Prefix + 'diffuse', Light.Diffuse);
  Shader.SetUniform(Prefix + 'specular', Light.Specular);
  Shader.SetUniform(Prefix + 'position', Light.Position);

  Direction := Light.Direction;
  if (Light.LightType in [ltDirectional, ltSpot]) and Light.UseTarget then
  begin
    if Light.ResolveTargetDirection(Direction) then
      Light.Direction := Direction
    else
      Direction := Light.Direction;
  end;

  if (Light.LightType = ltDirectional) and (Direction.LengthSquared < 1e-6) then
    Direction := Vector3(-0.35, -1.0, -0.35);

  if Direction.LengthSquared > 1e-6 then
    Direction.Normalize;

  Shader.SetUniform(Prefix + 'direction', Direction);
  Shader.SetUniform(Prefix + 'constantAttenuation', Light.ConstantAttenuation);
  Shader.SetUniform(Prefix + 'linearAttenuation', Light.LinearAttenuation);
  Shader.SetUniform(Prefix + 'quadraticAttenuation', Light.QuadraticAttenuation);

  CosCutoff := Cos(Light.SpotCutoff);
  Shader.SetUniform(Prefix + 'spotCutoff', CosCutoff);
  Shader.SetUniform(Prefix + 'spotExponent', Light.SpotExponent);
end;

procedure TGameEngine.ApplySceneLightsToShader(Shader: TShader);
var
  Lights: TArray<TLight>;
  LightCount: Integer;
  ShadowLightIndex: Integer;
  ShadowLayer: Integer;
  ShadowStrength: Single;
  LayerStrength: Single;
  ShadowMatrix: TMatrix4;
  I: Integer;
begin
  if Shader = nil then
    Exit;

  if FSceneManager = nil then
  begin
    Shader.SetUniform('lightCount', 0);
    Shader.SetUniform('shadowLightIndex', -1);
    Shader.SetUniform('shadowStrength', 0.0);
    Shader.SetUniform('shadowMapCount', 0);
    Exit;
  end;

  Lights := FSceneManager.GetLights;
  LightCount := Min(Length(Lights), MAX_ENGINE_SHADER_LIGHTS);
  Shader.SetUniform('lightCount', LightCount);

  ShadowLightIndex := -1;
  ShadowStrength := 0.0;

  if Assigned(FRenderer) then
    Shader.SetUniform('shadowMapCount', FRenderer.ShadowMapCount)
  else
    Shader.SetUniform('shadowMapCount', 0);

  for I := 0 to MAX_ENGINE_SHADER_LIGHTS - 1 do
  begin
    ShadowLayer := -1;
    LayerStrength := 0.0;
    ShadowMatrix := TMatrix4.Identity;

    if Assigned(FRenderer) then
    begin
      ShadowLayer := FRenderer.ShadowMapLayerForLightIndex(I);
      if ShadowLayer >= 0 then
      begin
        ShadowMatrix := FRenderer.ShadowLightMatrixForLightIndex(I);
        LayerStrength := FRenderer.ShadowStrengthForLightIndex(I);
        if ShadowLightIndex < 0 then
        begin
          ShadowLightIndex := I;
          ShadowStrength := LayerStrength;
        end;
      end;
    end;

    Shader.SetUniform(Format('shadowMapIndices[%d]', [I]), ShadowLayer);
    Shader.SetUniform(Format('shadowStrengths[%d]', [I]), LayerStrength);
    Shader.SetUniform(Format('lightSpaceMatrices[%d]', [I]), ShadowMatrix);
  end;

  Shader.SetUniform('shadowLightIndex', ShadowLightIndex);
  Shader.SetUniform('shadowStrength', ShadowStrength);

  for I := 0 to LightCount - 1 do
    ApplyLightToShader(Shader, Lights[I], I);

  for I := LightCount to MAX_ENGINE_SHADER_LIGHTS - 1 do
    Shader.SetUniform(Format('lights[%d].enabled', [I]), 0);
end;

procedure TGameEngine.OnUpdateShader(Shader: TShader);
begin
  ApplyFrameUniformsToShader(Shader);
end;

procedure TGameEngine.MeshRenderHandler(Mesh: TMesh; Shader: TShader);
begin
  if (Mesh = nil) or (Shader = nil) then
    Exit;

  ApplyFrameUniformsToShader(Shader);
  Shader.SetUniform('modelMatrix', Mesh.ModelMatrix);
  Shader.SetUniform('alpha', 1.0);
  if (FRenderer <> nil) and (FRenderer.CurrentSceneObject <> nil) then
    FRenderer.CurrentSceneObject.ApplyVertexWindUniforms(Shader)
  else
    Shader.SetUniform('useVertexWind', GLint(0));
end;

procedure TGameEngine.RendererBeforeRender(Sender: TObject);
begin
  ExecuteScriptLifecycleEvent('OnBeforeRender');
end;

procedure TGameEngine.RendererRender(Sender: TObject);
begin
  ExecuteScriptLifecycleEvent('OnRender');
end;

procedure TGameEngine.RendererAfterRender(Sender: TObject);
begin
  ExecuteScriptLifecycleEvent('OnAfterRender');
end;

procedure TGameEngine.SaveSceneRenderSettingsToStream(Stream: TStream);
var
  Payload: TMemoryStream;
  Version: Integer;
  PayloadSize: Int64;
  BoolValue: Boolean;
  IntValue: Integer;
  FloatValue: Single;
  ColorValue: TVector4;
begin
  if (Stream = nil) or (FRenderer = nil) then
    Exit;

  Payload := TMemoryStream.Create;
  try
    BoolValue := FRenderer.HDREnabled;
    Payload.WriteBuffer(BoolValue, SizeOf(BoolValue));
    IntValue := Ord(FRenderer.ToneMappingMode);
    Payload.WriteBuffer(IntValue, SizeOf(IntValue));
    FloatValue := FRenderer.ToneExposure;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));
    FloatValue := FRenderer.ToneGamma;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));
    BoolValue := FRenderer.GodRaysEnabled;
    Payload.WriteBuffer(BoolValue, SizeOf(BoolValue));
    IntValue := FRenderer.GodRaySamples;
    Payload.WriteBuffer(IntValue, SizeOf(IntValue));
    FloatValue := FRenderer.GodRayDensity;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));
    FloatValue := FRenderer.GodRayExposure;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));
    FloatValue := FRenderer.GodRayDecay;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));
    FloatValue := FRenderer.GodRayWeight;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));
    FloatValue := FRenderer.GodRayIntensity;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));

    BoolValue := FRenderer.SkyDome <> nil;
    Payload.WriteBuffer(BoolValue, SizeOf(BoolValue));
    if BoolValue then
      FRenderer.SkyDome.SaveToStream(Payload);

    BoolValue := FRenderer.FogEnabled;
    Payload.WriteBuffer(BoolValue, SizeOf(BoolValue));
    ColorValue := FRenderer.FogColor;
    Payload.WriteBuffer(ColorValue, SizeOf(ColorValue));
    FloatValue := FRenderer.FogDensity;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));
    FloatValue := FRenderer.FogStart;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));
    FloatValue := FRenderer.FogEnd;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));

    Stream.WriteBuffer(SCENE_RENDER_SETTINGS_MAGIC[0],
      SizeOf(SCENE_RENDER_SETTINGS_MAGIC));
    Version := SCENE_RENDER_SETTINGS_VERSION;
    Stream.WriteBuffer(Version, SizeOf(Version));
    PayloadSize := Payload.Size;
    Stream.WriteBuffer(PayloadSize, SizeOf(PayloadSize));
    Payload.Position := 0;
    if PayloadSize > 0 then
      Stream.CopyFrom(Payload, PayloadSize);
  finally
    Payload.Free;
  end;
end;

procedure TGameEngine.SaveScenePhysicsToStream(Stream: TStream);
var
  Payload: TMemoryStream;
  Version: Integer;
  PayloadSize: Int64;
  BodyCountValue: Integer;
  I: Integer;
  Body: TPhysicsBody;
  GravityValue: TVector3;
  GroundNormalValue: TVector3;
  FloatValue: Single;
  IntValue: Integer;
  BoolValue: Boolean;

  function HasSerializableObjectPath(Obj: TSceneObject): Boolean;
  var
    Cur: TSceneObject;
  begin
    Result := False;
    Cur := Obj;
    if (Cur = nil) or Cur.IsGizmo or (Cur = FRoot) then
      Exit;

    while (Cur <> nil) and (Cur.Parent <> nil) do
      Cur := Cur.Parent;
    Result := Cur = FRoot;
  end;

  procedure WriteObjectPath(OutStream: TStream; Obj: TSceneObject);
  var
    Indices: TArray<Integer>;
    Cur: TSceneObject;
    Index: Integer;
    CountValue: Integer;
  begin
    SetLength(Indices, 0);
    Cur := Obj;
    while (Cur <> nil) and (Cur.Parent <> nil) do
    begin
      Index := Cur.Parent.IndexOfObject(Cur);
      if Index < 0 then
        raise Exception.Create('Cannot save physics for a detached scene object.');
      SetLength(Indices, Length(Indices) + 1);
      Indices[High(Indices)] := Index;
      Cur := Cur.Parent;
    end;

    CountValue := Length(Indices);
    OutStream.WriteBuffer(CountValue, SizeOf(CountValue));
    for Index := CountValue - 1 downto 0 do
      OutStream.WriteBuffer(Indices[Index], SizeOf(Integer));
  end;

begin
  if (Stream = nil) or (FPhysicsWorld = nil) then
    Exit;

  Payload := TMemoryStream.Create;
  try
    GravityValue := FPhysicsWorld.Gravity;
    Payload.WriteBuffer(GravityValue, SizeOf(GravityValue));
    FloatValue := FPhysicsWorld.GlobalDamping;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));
    FloatValue := FPhysicsWorld.MaxSubStep;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));
    IntValue := FPhysicsWorld.MaxSubSteps;
    Payload.WriteBuffer(IntValue, SizeOf(IntValue));
    IntValue := FPhysicsWorld.SolverIterations;
    Payload.WriteBuffer(IntValue, SizeOf(IntValue));
    BoolValue := FPhysicsWorld.GroundPlaneEnabled;
    Payload.WriteBuffer(BoolValue, SizeOf(BoolValue));
    FloatValue := FPhysicsWorld.GroundHeight;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));
    GroundNormalValue := FPhysicsWorld.GroundNormal;
    Payload.WriteBuffer(GroundNormalValue, SizeOf(GroundNormalValue));
    FloatValue := FPhysicsWorld.CollisionSlop;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));

    BodyCountValue := 0;
    for I := 0 to FPhysicsWorld.BodyCount - 1 do
    begin
      Body := FPhysicsWorld.Bodies[I];
      if (Body <> nil) and HasSerializableObjectPath(Body.SceneObject) then
        Inc(BodyCountValue);
    end;
    Payload.WriteBuffer(BodyCountValue, SizeOf(BodyCountValue));

    for I := 0 to FPhysicsWorld.BodyCount - 1 do
    begin
      Body := FPhysicsWorld.Bodies[I];
      if (Body = nil) or (not HasSerializableObjectPath(Body.SceneObject)) then
        Continue;
      WriteObjectPath(Payload, Body.SceneObject);
      WritePhysicsBodyStateToStream(Payload, Body.GetState);
    end;

    Stream.WriteBuffer(SCENE_PHYSICS_MAGIC[0], SizeOf(SCENE_PHYSICS_MAGIC));
    Version := SCENE_PHYSICS_VERSION;
    Stream.WriteBuffer(Version, SizeOf(Version));
    PayloadSize := Payload.Size;
    Stream.WriteBuffer(PayloadSize, SizeOf(PayloadSize));
    Payload.Position := 0;
    if PayloadSize > 0 then
      Stream.CopyFrom(Payload, PayloadSize);
  finally
    Payload.Free;
  end;
end;

procedure TGameEngine.SaveScenePhysicsCacheToStream(Stream: TStream);
var
  Payload: TMemoryStream;
  Version: Integer;
  PayloadSize: Int64;
  BodyCountValue: Integer;
  I: Integer;
  Body: TPhysicsBody;
  Signature: UInt64;
  CacheSize: Int64;
  CacheStream: TMemoryStream;

  function HasSerializableObjectPath(Obj: TSceneObject): Boolean;
  var
    Cur: TSceneObject;
    Index: Integer;
  begin
    Result := False;
    Cur := Obj;
    if (Cur = nil) or Cur.IsGizmo or (Cur = FRoot) then
      Exit;

    while (Cur <> nil) and (Cur.Parent <> nil) do
    begin
      Index := Cur.Parent.IndexOfObject(Cur);
      if Index < 0 then
        Exit;
      Cur := Cur.Parent;
    end;
    Result := Cur = FRoot;
  end;

  procedure WriteObjectPath(OutStream: TStream; Obj: TSceneObject);
  var
    Indices: TArray<Integer>;
    Cur: TSceneObject;
    Index: Integer;
    CountValue: Integer;
  begin
    SetLength(Indices, 0);
    Cur := Obj;
    while (Cur <> nil) and (Cur.Parent <> nil) do
    begin
      Index := Cur.Parent.IndexOfObject(Cur);
      if Index < 0 then
        raise Exception.Create('Cannot save physics cache for a detached scene object.');
      SetLength(Indices, Length(Indices) + 1);
      Indices[High(Indices)] := Index;
      Cur := Cur.Parent;
    end;

    CountValue := Length(Indices);
    OutStream.WriteBuffer(CountValue, SizeOf(CountValue));
    for Index := CountValue - 1 downto 0 do
      OutStream.WriteBuffer(Indices[Index], SizeOf(Integer));
  end;

begin
  if (Stream = nil) or (FPhysicsWorld = nil) then
    Exit;

  Payload := TMemoryStream.Create;
  try
    BodyCountValue := 0;
    Payload.WriteBuffer(BodyCountValue, SizeOf(BodyCountValue));

    for I := 0 to FPhysicsWorld.BodyCount - 1 do
    begin
      Body := FPhysicsWorld.Bodies[I];
      if (Body = nil) or (not HasSerializableObjectPath(Body.SceneObject)) or
         (not FPhysicsWorld.BodyUsesCookedMeshCache(Body)) then
        Continue;

      CacheStream := TMemoryStream.Create;
      try
        if not FPhysicsWorld.TrySaveCookedMeshCache(Body, CacheStream, Signature) then
          Continue;

        CacheSize := CacheStream.Size;
        if (Signature = 0) or (CacheSize <= 0) then
          Continue;

        WriteObjectPath(Payload, Body.SceneObject);
        Payload.WriteBuffer(Signature, SizeOf(Signature));
        Payload.WriteBuffer(CacheSize, SizeOf(CacheSize));
        CacheStream.Position := 0;
        Payload.CopyFrom(CacheStream, CacheSize);
        Inc(BodyCountValue);
      finally
        CacheStream.Free;
      end;
    end;

    Payload.Position := 0;
    Payload.WriteBuffer(BodyCountValue, SizeOf(BodyCountValue));
    Payload.Position := 0;
    Stream.WriteBuffer(SCENE_PHYSICS_CACHE_MAGIC[0], SizeOf(SCENE_PHYSICS_CACHE_MAGIC));
    Version := SCENE_PHYSICS_CACHE_VERSION;
    Stream.WriteBuffer(Version, SizeOf(Version));
    PayloadSize := Payload.Size;
    Stream.WriteBuffer(PayloadSize, SizeOf(PayloadSize));
    if PayloadSize > 0 then
      Stream.CopyFrom(Payload, PayloadSize);
  finally
    Payload.Free;
  end;
end;

procedure TGameEngine.SaveSceneScriptsToStream(Stream: TStream);
var
  Payload: TMemoryStream;
  Version: Integer;
  PayloadSize: Int64;
begin
  if (Stream = nil) or (FScriptManager = nil) or (FScriptManager.Count = 0) then
    Exit;

  Payload := TMemoryStream.Create;
  try
    FScriptManager.SaveToStream(Payload);
    Stream.WriteBuffer(SCENE_SCRIPTS_MAGIC[0], SizeOf(SCENE_SCRIPTS_MAGIC));
    Version := SCENE_SCRIPTS_VERSION;
    Stream.WriteBuffer(Version, SizeOf(Version));
    PayloadSize := Payload.Size;
    Stream.WriteBuffer(PayloadSize, SizeOf(PayloadSize));
    Payload.Position := 0;
    if PayloadSize > 0 then
      Stream.CopyFrom(Payload, PayloadSize);
  finally
    Payload.Free;
  end;
end;

procedure TGameEngine.SaveSceneToFile(const AFileName: string;
  const AExcludedMaterialName: string);
var
  Stream: TFileStream;
  ResolvedFileName: string;
begin
  if FSceneManager = nil then
    raise Exception.Create('No scene manager is available.');

  if TPath.IsPathRooted(AFileName) then
    ResolvedFileName := AFileName
  else
    ResolvedFileName := TEnginePaths.Scene(ChangeFileExt(ExtractFileName(AFileName),
      SCENE_FILE_EXTENSION));
  if ExtractFileName(ResolvedFileName) = '' then
    raise Exception.Create('A scene file name is required.');

  ForceDirectories(ExtractFilePath(ResolvedFileName));
  FSceneManager.Name := ChangeFileExt(ExtractFileName(ResolvedFileName), '');
  Stream := TFileStream.Create(ResolvedFileName, fmCreate);
  try
    FSceneManager.SaveToStream(Stream);
    SaveSceneRenderSettingsToStream(Stream);
    SaveScenePhysicsToStream(Stream);
    SaveScenePhysicsCacheToStream(Stream);
    if FMaterialLibraries <> nil then
      FMaterialLibraries.SaveToStream(Stream, AExcludedMaterialName);
    SaveSceneScriptsToStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TGameEngine.LoadSceneFromFile(const AFileName: string);
var
  Stream: TFileStream;
  ResolvedFileName: string;
begin
  if FSceneManager = nil then
    raise Exception.Create('No scene manager is available.');

  if TPath.IsPathRooted(AFileName) then
    ResolvedFileName := AFileName
  else if SameText(ExtractFileExt(AFileName), SCENE_FILE_EXTENSION) then
    ResolvedFileName := TEnginePaths.Scene(ExtractFileName(AFileName))
  else
    ResolvedFileName := TEnginePaths.Scene(ChangeFileExt(ExtractFileName(AFileName),
      SCENE_FILE_EXTENSION));

  if not FileExists(ResolvedFileName) then
    raise Exception.Create('Scene file not found: ' + ResolvedFileName);

  if Assigned(FRenderer) then
    FRenderer.ActivateContext;

  FPhysicsRunning := False;

  Stream := TFileStream.Create(ResolvedFileName, fmOpenRead or fmShareDenyWrite);
  try
    FSceneManager.LoadFromStream(Stream);
    FRoot := FSceneManager.Root;

    if Assigned(FPhysicsWorld) then
      FPhysicsWorld.Clear;
    if Assigned(FAudioEngine) then
      FAudioEngine.ClearSounds;
    if Assigned(FScriptManager) then
      FScriptManager.Clear;

    if FPhysicsWorld = nil then
      FPhysicsWorld := TPhysicsWorld.Create(FRoot)
    else
      FPhysicsWorld.SceneRoot := FRoot;

    if not TryLoadSceneRenderSettingsFromStream(Stream) and Assigned(FRenderer) then
      FRenderer.ResetPostEffectsToDefaults;

    TryLoadScenePhysicsFromStream(Stream);
    TryLoadScenePhysicsCacheFromStream(Stream);
    ResetMaterialLibraries;
    TryLoadSceneMaterialsFromStream(Stream);
    TryLoadSceneScriptsFromStream(Stream);
  finally
    Stream.Free;
  end;

  RestoreSceneAfterLoad;
  BindScriptEngine;
end;

function TGameEngine.TryLoadSceneFromFile(const AFileName: string;
  out AErrorMessage: string): Boolean;
begin
  AErrorMessage := '';
  try
    LoadSceneFromFile(AFileName);
    Result := True;
  except
    on E: Exception do
    begin
      AErrorMessage := E.Message;
      Result := False;
    end;
  end;
end;

procedure TGameEngine.Resize(AWidth, AHeight: Integer);
begin
  if FRenderer = nil then
    Exit;

  FRenderer.Resize(AWidth, AHeight);
  FRenderer.InitFOV(DegToRad(FSettings.FieldOfViewDegrees),
    FSettings.NearPlane, FSettings.FarPlane);
end;

procedure TGameEngine.ActivateRenderContext;
begin
  if FRenderer <> nil then
    FRenderer.ActivateContext;
end;

procedure TGameEngine.ResetScene;
begin
  CreateDefaultScene;
  if Assigned(FRenderer) then
    FRenderer.ResetPostEffectsToDefaults;
  ResetMaterialLibraries;
  RestoreSceneAfterLoad;
  BindScriptEngine;
end;

procedure TGameEngine.Update(const DeltaTime, NewTime: Double);
var
  Light: TLight;
  SunDirection: TVector3;
begin
  if FScriptManager <> nil then
  begin
    FScriptManager.SetFrameTiming(DeltaTime, NewTime);
    ExecuteScriptLifecycleEvent('OnUpdate');
  end;

  if FRoot <> nil then
  begin
    // CPU-skinned meshes upload their deformed vertices during this update.
    ActivateRenderContext;
    FRoot.UpdateAnimations(Single(Max(0.0, DeltaTime)));
  end;

  if FPhysicsRunning and (FPhysicsWorld <> nil) then
  begin
    FPhysicsWorld.Step(Single(DeltaTime));
    if FSceneManager <> nil then
      FSceneManager.Update;
  end;

  UpdateSceneAudio;

  if (FRenderer = nil) or (FRenderer.SkyDome = nil) or
     (FRenderer.ShadowLight = nil) or
     (FRenderer.ShadowLight.LightsCount = 0) then
    Exit;

  Light := FRenderer.ShadowLight.Light[0];
  if (Light = nil) or not (Light.LightType in [ltDirectional, ltSpot]) then
    Exit;

  SunDirection := Light.Direction;
  if SunDirection.LengthSquared < 1e-8 then
    Exit;
  SunDirection.Normalize;
  FRenderer.SkyDome.SunDirection := -SunDirection;
end;

procedure TGameEngine.StartPhysics;
var
  FreshStart: Boolean;
begin
  if FRoot = nil then
    Exit;

  if FPhysicsWorld = nil then
    FPhysicsWorld := TPhysicsWorld.Create(FRoot)
  else
    FPhysicsWorld.SceneRoot := FRoot;

  FreshStart := not FPhysicsWorld.HasTransformBackup;
  FPhysicsWorld.ApplyStagedBodyStates;
  FPhysicsWorld.EnsureNativeScene;
  if FreshStart then
  begin
    FPhysicsWorld.ResetBodiesToSceneTransforms(True);
    FPhysicsWorld.CaptureSceneTransforms;
  end;
  FPhysicsRunning := True;
end;

procedure TGameEngine.PausePhysics;
begin
  FPhysicsRunning := False;
end;

procedure TGameEngine.StopPhysics;
begin
  FPhysicsRunning := False;
  if FPhysicsWorld <> nil then
  begin
    if FPhysicsWorld.HasTransformBackup then
      FPhysicsWorld.RestoreSceneTransforms(False)
    else
    begin
      FPhysicsWorld.ApplyStagedBodyStates;
      FPhysicsWorld.EnsureNativeScene;
      FPhysicsWorld.ResetBodiesToSceneTransforms(True);
    end;
  end;
  if FSceneManager <> nil then
    FSceneManager.Update;
end;

procedure TGameEngine.ResetPhysics;
begin
  StopPhysics;
end;

function TGameEngine.ResolveAudioPath(const AStoredPath: string): string;
var
  FileName: string;
begin
  FileName := Trim(AStoredPath);
  if FileName = '' then
    Exit('');

  if TPath.IsPathRooted(FileName) then
    Exit(FileName);

  Result := TEnginePaths.Audio(FileName);
  if not FileExists(Result) then
    Result := TEnginePaths.ResolveAssetPath(FileName);
end;

procedure TGameEngine.ReleaseSceneAudioEmitter(AEmitter: TSceneAudioEmitter);
var
  Sound: TBassSound;
begin
  if AEmitter = nil then
    Exit;

  Sound := AEmitter.RuntimeSound;
  if (FAudioEngine <> nil) and (Sound <> nil) then
    FAudioEngine.FreeSound(Sound);
  AEmitter.RuntimeSound := nil;
end;

procedure TGameEngine.ReleaseSceneObjectAudio(Obj: TSceneObject);
var
  I: Integer;
begin
  if Obj = nil then
    Exit;

  for I := 0 to Obj.AudioEmitterCount - 1 do
    ReleaseSceneAudioEmitter(Obj.AudioEmitterItem[I]);
  for I := 0 to Obj.Count - 1 do
    ReleaseSceneObjectAudio(Obj.ObjectList[I]);
end;

procedure TGameEngine.LoadSceneAudioEmitter(AObject: TSceneObject;
  AEmitter: TSceneAudioEmitter);
var
  Candidate: string;
  NewSound: TBassSound;
  PositionValue: TVector3;
  OrientationValue: TVector3;
  WorldPosition: TVector4;
  WorldOrientation: TVector4;

  function BassVector(const V: TVector3): TBass3DVector;
  begin
    Result := TBass3DVector.Create(V.X, V.Y, V.Z);
  end;

begin
  if (not FSettings.EnableAudio) or (AObject = nil) or (AEmitter = nil) then
    Exit;

  Candidate := ResolveAudioPath(AEmitter.AudioPath);
  if (Candidate = '') or (not FileExists(Candidate)) then
    Exit;

  if FAudioEngine = nil then
    FAudioEngine := TBassAudioEngine.Create;
  if AEmitter.Spatial then
    FAudioEngine.Initialize3D(FHost.Handle)
  else if not FAudioEngine.Initialized then
    FAudioEngine.Initialize(FHost.Handle);

  ReleaseSceneAudioEmitter(AEmitter);
  NewSound := FAudioEngine.LoadSound(Candidate, AEmitter.Loop,
    AEmitter.Spatial, AEmitter.MutedAtMaxDistance);
  AEmitter.RuntimeSound := NewSound;
  NewSound.Volume := AEmitter.Volume;
  NewSound.Loop := AEmitter.Loop;

  if AEmitter.Spatial and NewSound.Spatial then
  begin
    NewSound.Set3DAttributes(AEmitter.Mode, AEmitter.MinDistance,
      AEmitter.MaxDistance, AEmitter.InsideConeAngle, AEmitter.OutsideConeAngle,
      AEmitter.OutsideVolume);
    WorldPosition := AObject.WorldMatrix * Vector4(AEmitter.Offset, 1.0);
    PositionValue := Vector3(WorldPosition);
    WorldOrientation := AObject.WorldMatrix * Vector4(AEmitter.Orientation, 0.0);
    OrientationValue := Vector3(WorldOrientation);
    if OrientationValue.LengthSquared < 1e-8 then
      OrientationValue := Vector3(0, 0, -1)
    else
      OrientationValue.Normalize;
    NewSound.Set3DPosition(BassVector(PositionValue),
      BassVector(OrientationValue), BassVector(AEmitter.Velocity));
  end;

  AEmitter.AudioPath := TEnginePaths.ToAssetRelativePath(Candidate);
  if AEmitter.AutoPlay then
    NewSound.Play(False);
end;

procedure TGameEngine.UpdateSceneAudio;
var
  ListenerObj: TSceneObject;
  ListenerPosition: TVector3;
  ListenerVelocity: TVector3;
  ListenerFront: TVector3;
  ListenerTop: TVector3;

  function BassVector(const V: TVector3): TBass3DVector;
  begin
    Result := TBass3DVector.Create(V.X, V.Y, V.Z);
  end;

  function TransformDirection(Obj: TSceneObject; const LocalDir,
    Fallback: TVector3): TVector3;
  var
    Direction4: TVector4;
  begin
    Result := Fallback;
    if Obj = nil then
      Exit;
    Direction4 := Obj.WorldMatrix * Vector4(LocalDir, 0.0);
    Result := Vector3(Direction4);
    if Result.LengthSquared < 1e-8 then
      Result := Fallback
    else
      Result.Normalize;
  end;

  function FindAudioListener(Obj: TSceneObject): TSceneObject;
  var
    I: Integer;
  begin
    Result := nil;
    if Obj = nil then
      Exit;
    if Obj.AudioListener then
      Exit(Obj);
    for I := 0 to Obj.Count - 1 do
    begin
      Result := FindAudioListener(Obj.ObjectList[I]);
      if Result <> nil then
        Exit;
    end;
  end;

  procedure UpdateEmitters(Obj: TSceneObject);
  var
    I: Integer;
    Emitter: TSceneAudioEmitter;
    PositionValue: TVector3;
    OrientationValue: TVector3;
    WorldPosition: TVector4;
    WorldOrientation: TVector4;
  begin
    if Obj = nil then
      Exit;
    for I := 0 to Obj.AudioEmitterCount - 1 do
    begin
      Emitter := Obj.AudioEmitterItem[I];
      if (Emitter = nil) or (not Emitter.Enabled) or
         (Emitter.RuntimeSound = nil) then
        Continue;
      Emitter.RuntimeSound.Loop := Emitter.Loop;
      Emitter.RuntimeSound.Volume := Emitter.Volume;
      if Emitter.Spatial and Emitter.RuntimeSound.Spatial then
      begin
        Emitter.RuntimeSound.Set3DAttributes(Emitter.Mode, Emitter.MinDistance,
          Emitter.MaxDistance, Emitter.InsideConeAngle,
          Emitter.OutsideConeAngle, Emitter.OutsideVolume);
        WorldPosition := Obj.WorldMatrix * Vector4(Emitter.Offset, 1.0);
        PositionValue := Vector3(WorldPosition);
        WorldOrientation := Obj.WorldMatrix * Vector4(Emitter.Orientation, 0.0);
        OrientationValue := Vector3(WorldOrientation);
        if OrientationValue.LengthSquared < 1e-8 then
          OrientationValue := Vector3(0, 0, -1)
        else
          OrientationValue.Normalize;
        Emitter.RuntimeSound.Set3DPosition(BassVector(PositionValue),
          BassVector(OrientationValue), BassVector(Emitter.Velocity));
      end;
    end;
    for I := 0 to Obj.Count - 1 do
      UpdateEmitters(Obj.ObjectList[I]);
  end;

begin
  if (FAudioEngine = nil) or (not FAudioEngine.Initialized) then
    Exit;

  ListenerObj := FindAudioListener(FRoot);
  if ListenerObj <> nil then
  begin
    ListenerPosition := Vector3(ListenerObj.WorldMatrix.Columns[3]);
    ListenerVelocity := ListenerObj.AudioListenerVelocity;
    ListenerFront := TransformDirection(ListenerObj,
      ListenerObj.AudioListenerFront, Vector3(0, 0, -1));
    ListenerTop := TransformDirection(ListenerObj,
      ListenerObj.AudioListenerTop, Vector3(0, 1, 0));
    FAudioEngine.Set3DFactors(ListenerObj.AudioDistanceFactor,
      ListenerObj.AudioRolloffFactor, ListenerObj.AudioDopplerFactor);
  end
  else if (FRenderer <> nil) and (FRenderer.ActiveCamera <> nil) and
          (FRenderer.ActiveCamera.Camera <> nil) then
  begin
    ListenerPosition := FRenderer.ActiveCamera.Camera.Position;
    ListenerVelocity := Vector3(0, 0, 0);
    ListenerFront := FRenderer.ActiveCamera.Camera.Front;
    ListenerTop := FRenderer.ActiveCamera.Camera.Up;
  end
  else
    Exit;

  if ListenerFront.LengthSquared < 1e-8 then
    ListenerFront := Vector3(0, 0, -1)
  else
    ListenerFront.Normalize;
  if ListenerTop.LengthSquared < 1e-8 then
    ListenerTop := Vector3(0, 1, 0)
  else
    ListenerTop.Normalize;

  FAudioEngine.SetListener3D(BassVector(ListenerPosition),
    BassVector(ListenerVelocity), BassVector(ListenerFront),
    BassVector(ListenerTop));
  UpdateEmitters(FRoot);
  FAudioEngine.Apply3D;
end;

procedure TGameEngine.SetScriptPrefabCallbacks(
  const APrefabLoader: TEngineScriptPrefabLoadCallback;
  const APrefabDestroyer: TEngineScriptPrefabDestroyCallback);
begin
  FPrefabLoader := APrefabLoader;
  FPrefabDestroyer := APrefabDestroyer;
  BindScriptEngine;
end;

procedure TGameEngine.SetScriptLogCallback(
  const ALogCallback: TEngineScriptLogCallback);
begin
  FScriptLogCallback := ALogCallback;
  BindScriptEngine;
end;

procedure TGameEngine.Render;
begin
  if FRenderer <> nil then
    FRenderer.Render;
end;

procedure TGameEngine.SetupRenderableMesh(Mesh: TMesh);
begin
  if Mesh = nil then
    Exit;

  Mesh.MaterialLibrary := EnsureDefaultMaterialLibrary;
  Mesh.LibMaterialname := DefaultRenderableMaterialName;
  Mesh.OnRender := MeshRenderHandler;

  if Mesh.MaterialLibraryName = '' then
    Mesh.MaterialLibraryName := DEFAULT_ENGINE_MATERIAL_LIBRARY_NAME;
end;

function Create(AHost: TWinControl): TGameEngine;
begin
  Result := TGameEngine.Create(AHost);
end;

function Create(AHost: TWinControl; const ASettings: TEngineSettings): TGameEngine;
begin
  Result := TGameEngine.Create(AHost, ASettings);
end;

end.
