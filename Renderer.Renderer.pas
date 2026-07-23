unit Renderer.Renderer;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Imaging.pngimage,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  dglOpenGL, Vcl.ExtCtrls, Vcl.StdCtrls, System.Math,
  Renderer.Mesh, Renderer.Particles, Renderer.Billboards, Renderer.AnimatedSprites,
  Renderer.Shader, Renderer.Light, Renderer.SkyDome,
  Engine.Types,
  Managers.Material, Renderer.Camera, Engine.Generators, Managers.Scene,
  Renderer.Mesh.List, GraphicEx, Neslib.FastMath, Engine.Gui,
  System.Generics.Collections, Vcl.Buttons, Vcl.ComCtrls;

const
  MAX_RENDERER_SHADER_LIGHTS = 8;
  MAX_RENDERER_SHADOW_MAPS = 4;

type
  TRenderContext = class
  private
    fWindowHandle: HWND;
    fDeviceContext: HDC;
    fRenderingContext: HGLRC;
  public
    constructor Create(AWindowHandle: HWND; ARequestedSamples: Integer;
      out AActualSamples: Integer; ASharedContext: TRenderContext = nil);
    destructor Destroy; override;

    procedure Activate;
    procedure Deactivate;
    procedure Swap;
    function IsCurrent: Boolean;

    property WindowHandle: HWND read fWindowHandle;
    property DeviceContext: HDC read fDeviceContext;
    property RenderingContext: HGLRC read fRenderingContext;
  end;

  TBillboardRenderItem = record
    SceneObject: TSceneObject;
    Billboard: TBillboard;
    AnimatedSprite: TAnimatedSprite;
    DistanceSq: Single;
  end;

  TBillboardRenderList = TArray<TBillboardRenderItem>;

  TShadowMapRenderEntry = record
    Light: TLight;
    LightIndex: Integer;
    Matrix: TMatrix4;
    Strength: Single;
  end;

  TToneMappingMode = (
    tmLinear,
    tmExponential,
    tmReinhard,
    tmUncharted2,
    tmMGSV,
    tmUchimura,
    tmFilmic,
    tmACES,
    tmPBRNeutral,
    tmFlim,
    tmAGX
  );

  TRenderer = class
  private
    fBackgroundColor: TVector4;

    fViewport: TViewport;
    fRenderTargetOverrideActive: Boolean;
    fRenderTargetOverrideFBO: GLuint;
    fRenderTargetOverrideViewport: TViewport;
    fRenderTargetOverrideSamples: Integer;
    fSuppressBeforePresent: Boolean;
    fRenderContext: TRenderContext;
    fAntialiasingSamples: Integer;
    fAntialiasingEnabled: Boolean;
    fSwapInterval: GLint;
    fSwapIntervalSupported: Boolean;
    fFrustumCullingEnabled: Boolean;
    fViewFrustumValid: Boolean;
    fViewFrustumPlanes: TFrustumPlanes;
    fShadowFrustumValid: Boolean;
    fShadowFrustumPlanes: TFrustumPlanes;
    fFogEnabled: Boolean;
    fFogColor: TVector4;
    fFogDensity: Single;
    fFogStart: Single;
    fFogEnd: Single;

    fSceneManager: TSceneManager;
    fActiveCamera: TSceneObject;
    fCurrentSceneObject: TSceneObject;

    fHandle: HWND;

    fProjectionMatrix: TMatrix4;
    fFieldOfView: Single;
    fNearPlaneDistance: Single;
    fFarPlaneDistance: Single;

    fShadowEnabled: Boolean;
    fShadowMapSize: Integer;
    fShadowFBO: GLuint;
    fShadowDepthTexture: GLuint;
    fShadowShader: TShader;
    fShadowLight: TSceneObject;
    fShadowLightViewProjection: TMatrix4;
    fShadowMapCount: Integer;
    fShadowMaps: array[0..MAX_RENDERER_SHADOW_MAPS - 1] of TShadowMapRenderEntry;
    fShadowTarget: TVector3;
    fShadowDistance: Single;
    fShadowArea: Single;
    fShadowAutoFit: Boolean;
    fShadowFitPadding: Single;
    fShadowDrawCount: Integer;

    fWaterReflectionEnabled: Boolean;
    fWaterReflectionFBO: GLuint;
    fWaterReflectionTexture: GLuint;
    fWaterReflectionDepthRBO: GLuint;
    fWaterReflectionWidth: Integer;
    fWaterReflectionHeight: Integer;
    fWaterShader: TShader;
    fWaterReflectionCameraObject: TSceneObject;
    fRenderingWaterReflection: Boolean;
    fSceneClipPlaneEnabled: Boolean;
    fSceneClipPlane: TVector4;
    fWaterTime: Single;

    fHDREnabled: Boolean;
    fToneMappingMode: TToneMappingMode;
    fToneExposure: Single;
    fToneGamma: Single;
    fPostProcessShader: TShader;
    fPostProcessFBO: GLuint;
    fPostProcessColorTexture: GLuint;
    fPostProcessDepthRBO: GLuint;
    fPostProcessWidth: Integer;
    fPostProcessHeight: Integer;
    fFullscreenVAO: GLuint;
    fFullscreenVBO: GLuint;
    fGodRaysEnabled: Boolean;
    fGodRaySamples: Integer;
    fGodRayDensity: Single;
    fGodRayExposure: Single;
    fGodRayDecay: Single;
    fGodRayWeight: Single;
    fGodRayIntensity: Single;

    fEmptyObjectMarkersEnabled: Boolean;
    fEmptyObjectMarkerSize: Single;
    fEmptyObjectMarkerColor: TVector4;
    fEmptyObjectMarkerVAO: GLuint;
    fEmptyObjectMarkerVBO: GLuint;
    fEmptyObjectMarkerVertexCount: Integer;
    fEmptyObjectMarkerShader: TShader;
    fGuiRenderer: TGuiRenderer;
    fSkyDome: TSkyDome;
    fSelectedBoundingBoxEnabled: Boolean;
    fSelectedBoundingBoxObject: TSceneObject;
    fSelectedBoundingBoxColor: TVector4;
    fSelectedBoundingBoxVAO: GLuint;
    fSelectedBoundingBoxVBO: GLuint;
    fSelectedBoundingBoxVertexCount: Integer;

    fFPSCounter: Int64;        // performance counter frequency
    fLastTime: Int64;          // timestamp of previous frame
    fLastParticleTime: Int64;
    fFrameCount: Cardinal;
    fTimeAccum: Double;
    fCurrentFPS: Integer;
    fTriangleCount: Int64;

    fOnBeforeRender: TNotifyEvent;
    fOnRender: TNotifyEvent;
    fOnBeforeSceneRender: TNotifyEvent;
    fOnAfterRender: TNotifyEvent;
    fOnBeforePresent: TNotifyEvent;

    procedure UpdateFPS;

    procedure SetupScene;
    function CountMeshTriangles(AMesh: TMesh): Int64;
    function CountSceneObjectTriangles(aObject: TSceneObject): Int64;
    procedure RenderSceneObject(aObject: TSceneObject);
    procedure CollectSceneObjectBillboards(aObject: TSceneObject;
      var Items: TBillboardRenderList);
    procedure SortBillboardRenderItems(var Items: TBillboardRenderList);
    procedure RenderSceneBillboards;
    procedure RenderSceneObjectParticles(aObject: TSceneObject);
    procedure RenderSceneObjectDepth(aObject: TSceneObject);
    procedure ApplyShadowMaterial(AMesh: TMesh);
    function MeshCastsShadowByDefault(AMesh: TMesh;
      const AWorldBounds: TAABB): Boolean;
    function FindFirstLightObject(aObject: TSceneObject): TSceneObject;
    function FindShadowLightObject(aObject: TSceneObject): TSceneObject;
    function TryGetShadowCasterBounds(out Bounds: TAABB): Boolean;
    function TryGetMainLightHeight(out AHeight: Single): Boolean;
    procedure RenderShadowPass;
    function AddShadowMapLight(ALight: TLight; ALightIndex: Integer): Boolean;
    function CalculateShadowLightMatrix(ALight: TLight): TMatrix4;
    procedure UpdateShadowLightMatrix(aLightObject: TSceneObject);
    procedure DestroyShadowMap;
    procedure DestroyWaterReflection;
    procedure SetupWaterReflection(AWidth, AHeight: Integer);
    procedure EnsureWaterReflectionResources;
    procedure DestroyPostProcessResources;
    procedure SetupPostProcessResources(AWidth, AHeight: Integer);
    procedure SetupFullscreenQuad;
    procedure RenderPostProcess;
    function TryGetGodRayLightScreenPosition(out AScreenPosition: TVector2): Boolean;
    function FindFirstWaterMesh(aObject: TSceneObject; out AWaterMesh: TWaterPlaneMesh): Boolean;
    procedure RenderWaterReflectionPass(DeltaTime: Single);
    procedure RenderWaterMeshes;
    procedure RenderSceneObjectWater(aObject: TSceneObject);
    procedure RenderWaterMesh(AWaterMesh: TWaterPlaneMesh);
    procedure SetupEmptyObjectMarkerGeometry;
    procedure DestroyEmptyObjectMarker;
    procedure RenderEmptyObjectMarkers;
    procedure RenderEmptyObjectMarker(aObject: TSceneObject);
    procedure SetupSelectedBoundingBoxGeometry;
    procedure DestroySelectedBoundingBox;
    procedure RenderSelectedBoundingBox;
    function RequireGuiRenderer: TGuiRenderer;
    function BuildFrustumFromViewProjection(const AViewProjection: TMatrix4;
      out APlanes: TFrustumPlanes): Boolean;
    function BuildViewFrustum: Boolean;
    function BuildShadowFrustum: Boolean;
    function IsSphereVisibleInViewFrustum(const ACenter: TVector3;
      ARadius: Single): Boolean;
    function IsSceneObjectGeometryVisible(aObject: TSceneObject): Boolean;
    procedure ApplySwapInterval;
    function GetVSyncEnabled: Boolean;
    function GetPostProcessActive: Boolean;
    function PresentFramebuffer: GLuint;
    procedure ApplyPresentViewport;
    function ActiveAntialiasingSamples: Integer;
    procedure ApplyAntialiasingState;
    procedure SetSwapInterval(const Value: GLint);
    procedure SetVSyncEnabled(const Value: Boolean);
    procedure SetHDREnabled(const Value: Boolean);
    procedure SetSkyDome(const Value: TSkyDome);

  public
    constructor Create(handleWindow: HWND; X, Y, aWidth, aHeight: Integer;
      clearColor: TVector4; AAntialiasingSamples: Integer = 4;
      ASharedRenderer: TRenderer = nil);
    destructor Destroy; override;

    procedure ActivateContext;
    procedure FlushGLColor(const aColor: TVector4); overload;
    procedure FlushGLColor;                         overload;

    procedure BeginFrame;
    procedure EndFrame;
    procedure Render;
    procedure Resize(AWidth, AHeight: Integer);
    function RenderToTexture(AWidth, AHeight: Integer; out ATextureID: GLuint;
      out AError: string; AAntialiasingSamples: Integer = 1): Boolean;
    function SaveTextureToPNG(ATextureID: GLuint; AWidth, AHeight: Integer;
      const AFileName: string; out AError: string): Boolean;
    function RenderToTextureFile(AWidth, AHeight: Integer;
      const AFileName: string; out AError: string;
      AAntialiasingSamples: Integer = 1): Boolean;
    function MaxRenderTextureAntialiasingSamples: Integer;
    procedure UpdateTriangleCount;
    function EffectiveFogColor: TVector4;
    procedure ResetPostEffectsToDefaults;

    property FPS: Integer read fCurrentFPS;
    property TriangleCount: Int64 read fTriangleCount;
    property AntialiasingEnabled: Boolean read fAntialiasingEnabled write fAntialiasingEnabled;
    property AntialiasingSamples: Integer read fAntialiasingSamples;
    property SwapInterval: GLint read fSwapInterval write SetSwapInterval;
    property SwapIntervalSupported: Boolean read fSwapIntervalSupported;
    property VSyncEnabled: Boolean read GetVSyncEnabled write SetVSyncEnabled;
    property FrustumCullingEnabled: Boolean read fFrustumCullingEnabled write fFrustumCullingEnabled;
    property FogEnabled: Boolean read fFogEnabled write fFogEnabled;
    property FogColor: TVector4 read fFogColor write fFogColor;
    property FogDensity: Single read fFogDensity write fFogDensity;
    property FogStart: Single read fFogStart write fFogStart;
    property FogEnd: Single read fFogEnd write fFogEnd;

    procedure InitFOV(AFieldOfView, ANearPlaneDistance, AFarPlaneDistance: Single);
    procedure LoadShadowShaderFromFile(const VertexFileName, FragmentFileName: string);
    procedure LoadEmptyObjectMarkerShaderFromFile(const VertexFileName, FragmentFileName: string);
    procedure LoadWaterShaderFromFile(const VertexFileName, FragmentFileName: string);
    procedure LoadPostProcessShaderFromFile(const VertexFileName, FragmentFileName: string);
    procedure LoadGuiShaderFromFile(const VertexFileName, FragmentFileName: string);
    procedure SetupShadowMap(ASize: Integer = 4096); // 2048
    function ShadowMapLayerForLightIndex(ALightIndex: Integer): Integer;
    function ShadowLightMatrixForLightIndex(ALightIndex: Integer): TMatrix4;
    function ShadowStrengthForLightIndex(ALightIndex: Integer): Single;
    procedure RenderGuiSolidRect(AX, AY, AWidth, AHeight: Single;
      const AColor: TVector4);
    procedure RenderGuiVertices(const AVertices: TArray<TGuiVertex>;
      ATextureID: GLuint; const ATint: TVector4);
    procedure RenderGuiComponent(AComponent: TGuiComponent; ATexture: TGuiTexture;
      AX, AY, AWidth, AHeight: Single; const ATint: TVector4;
      AScale: Single = 1.0);
    procedure RenderGuiLayout(ALayout: TGuiLayout; const AComponentName: string;
      AX, AY, AWidth, AHeight: Single; const ATint: TVector4;
      AScale: Single = 1.0);
    procedure RenderGuiControl(AControl: TGuiControl);

    property SceneManager: TSceneManager read fSceneManager write fSceneManager;
    property ActiveCamera: TSceneObject read fActiveCamera write fActiveCamera;
    property CurrentSceneObject: TSceneObject read fCurrentSceneObject;
    property RenderContext: TRenderContext read fRenderContext;

    property BackgroundColor: TVector4 read fBackgroundColor write fBackgroundColor;

    property X: Integer read fViewport.X write fViewport.X;
    property Y: Integer read fViewport.Y write fViewport.Y;
    property Width: Integer read fViewport.Width write fViewport.Width;
    property Height: Integer read fViewport.Height write fViewport.Height;

    //temporary properties
    //property DeviceContext: HDC read fDeviceContext write fDeviceContext;
    //property RenderingContext: HGLRC read fRenderingContext write fRenderingContext;

    //property Shader: TShader read fShader write fShader;
    property OnBeforeRender: TNotifyEvent read fOnBeforeRender write fOnBeforeRender;
    property OnRender: TNotifyEvent read fOnRender write fOnRender;
    property OnBeforeSceneRender: TNotifyEvent read fOnBeforeSceneRender write fOnBeforeSceneRender;
    property OnAfterRender: TNotifyEvent read fOnAfterRender write fOnAfterRender;
    property OnBeforePresent: TNotifyEvent read fOnBeforePresent write fOnBeforePresent;

    property ProjectionMatrix: TMatrix4 read fProjectionMatrix write fProjectionMatrix;

    property ShadowEnabled: Boolean read fShadowEnabled write fShadowEnabled;
    property ShadowLight: TSceneObject read fShadowLight write fShadowLight;
    property ShadowDepthTexture: GLuint read fShadowDepthTexture;
    property ShadowLightViewProjection: TMatrix4 read fShadowLightViewProjection;
    property ShadowMapCount: Integer read fShadowMapCount;
    property ShadowTarget: TVector3 read fShadowTarget write fShadowTarget;
    property ShadowDistance: Single read fShadowDistance write fShadowDistance;
    property ShadowArea: Single read fShadowArea write fShadowArea;
    property ShadowAutoFit: Boolean read fShadowAutoFit write fShadowAutoFit;
    property ShadowFitPadding: Single read fShadowFitPadding write fShadowFitPadding;
    property ShadowDrawCount: Integer read fShadowDrawCount;
    property WaterReflectionEnabled: Boolean read fWaterReflectionEnabled write fWaterReflectionEnabled;
    property WaterReflectionTexture: GLuint read fWaterReflectionTexture;
    property RenderingWaterReflection: Boolean read fRenderingWaterReflection;
    property SceneClipPlaneEnabled: Boolean read fSceneClipPlaneEnabled;
    property SceneClipPlane: TVector4 read fSceneClipPlane;
    property HDRPostProcessActive: Boolean read GetPostProcessActive;
    property HDREnabled: Boolean read fHDREnabled write SetHDREnabled;
    property ToneMappingMode: TToneMappingMode read fToneMappingMode write fToneMappingMode;
    property ToneExposure: Single read fToneExposure write fToneExposure;
    property ToneGamma: Single read fToneGamma write fToneGamma;
    property GodRaysEnabled: Boolean read fGodRaysEnabled write fGodRaysEnabled;
    property GodRaySamples: Integer read fGodRaySamples write fGodRaySamples;
    property GodRayDensity: Single read fGodRayDensity write fGodRayDensity;
    property GodRayExposure: Single read fGodRayExposure write fGodRayExposure;
    property GodRayDecay: Single read fGodRayDecay write fGodRayDecay;
    property GodRayWeight: Single read fGodRayWeight write fGodRayWeight;
    property GodRayIntensity: Single read fGodRayIntensity write fGodRayIntensity;
    property EmptyObjectMarkersEnabled: Boolean read fEmptyObjectMarkersEnabled write fEmptyObjectMarkersEnabled;
    property EmptyObjectMarkerSize: Single read fEmptyObjectMarkerSize write fEmptyObjectMarkerSize;
    property EmptyObjectMarkerColor: TVector4 read fEmptyObjectMarkerColor write fEmptyObjectMarkerColor;
    property SelectedBoundingBoxEnabled: Boolean read fSelectedBoundingBoxEnabled write fSelectedBoundingBoxEnabled;
    property SelectedBoundingBoxObject: TSceneObject read fSelectedBoundingBoxObject write fSelectedBoundingBoxObject;
    property SelectedBoundingBoxColor: TVector4 read fSelectedBoundingBoxColor write fSelectedBoundingBoxColor;
    property GuiRenderer: TGuiRenderer read fGuiRenderer;
    property SkyDome: TSkyDome read fSkyDome write SetSkyDome;
  end;

implementation

const
  LIGHT_GLYPH_TEXTURE_PATH = 'Billboards\Textures\LIGHT.tga';
  LIGHT_GLYPH_NAME = 'Light Glyph';
  LIGHT_GLYPH_SCREEN_SIZE_PX = 40.0;
  DEFAULT_ANTIALIASING_SAMPLES = 4;
  DUMMY_GL_WINDOW_CLASS = 'OGLMicroEngineDummyGLWindow';

function RendererDummyWndProc(hWnd: HWND; Msg: UINT; wParam: WPARAM;
  lParam: LPARAM): LRESULT; stdcall;
begin
  Result := DefWindowProc(hWnd, Msg, wParam, lParam);
end;

function EnsureDummyGLWindowClass: Boolean;
var
  WndClass: Winapi.Windows.TWndClass;
begin
  FillChar(WndClass, SizeOf(WndClass), 0);
  WndClass.style := CS_OWNDC;
  WndClass.lpfnWndProc := @RendererDummyWndProc;
  WndClass.hInstance := HInstance;
  WndClass.lpszClassName := PChar(DUMMY_GL_WINDOW_CLASS);

  Result := Winapi.Windows.RegisterClass(WndClass) <> 0;
  if (not Result) and (GetLastError = ERROR_CLASS_ALREADY_EXISTS) then
    Result := True;
end;

function TrySetMultisamplePixelFormat(DC: HDC; RequestedSamples: Integer;
  out ActualSamples: Integer): Boolean; forward;

function TrySetMultisamplePixelFormatUsingDummyContext(DC: HDC;
  RequestedSamples: Integer; out ActualSamples: Integer): Boolean;
var
  DummyWindow: HWND;
  DummyDC: HDC;
  DummyRC: HGLRC;
begin
  Result := False;
  ActualSamples := 0;
  DummyRC := 0;

  if not EnsureDummyGLWindowClass then
    Exit;

  DummyWindow := CreateWindowEx(0, PChar(DUMMY_GL_WINDOW_CLASS), PChar(''),
    WS_POPUP, 0, 0, 1, 1, 0, 0, HInstance, nil);
  if DummyWindow = 0 then
    Exit;

  try
    DummyDC := GetDC(DummyWindow);
    if DummyDC = 0 then
      Exit;

    try
      try
        DummyRC := CreateRenderingContext(DummyDC, [opDoubleBuffered], 32, 24, 0, 0, 0, 0);
        if DummyRC = 0 then
          Exit;

        ActivateRenderingContext(DummyDC, DummyRC);
        if WGL_ARB_pixel_format and WGL_ARB_multisample and
           Assigned(wglChoosePixelFormatARB) then
          Result := TrySetMultisamplePixelFormat(DC, RequestedSamples,
            ActualSamples);
      except
        Result := False;
      end;
    finally
      if DummyRC <> 0 then
      begin
        wglMakeCurrent(0, 0);
        wglDeleteContext(DummyRC);
      end;
      ReleaseDC(DummyWindow, DummyDC);
    end;
  finally
    DestroyWindow(DummyWindow);
  end;
end;

function NextLowerSampleCount(Samples: Integer): Integer;
begin
  if Samples > 8 then
    Result := 8
  else if Samples > 4 then
    Result := 4
  else if Samples > 2 then
    Result := 2
  else
    Result := 0;
end;

function TrySetMultisamplePixelFormat(DC: HDC; RequestedSamples: Integer;
  out ActualSamples: Integer): Boolean;
var
  Attribs: array[0..23] of GLint;
  PixelFormatGL: GLint;
  PixelFormat: Integer;
  NumFormats: GLuint;
  Samples: Integer;
  PFDescriptor: Winapi.Windows.TPixelFormatDescriptor;
  QueryAttrib, QueryValue: GLint;
begin
  Result := False;
  ActualSamples := 0;

  if (RequestedSamples < 2) or (GetPixelFormat(DC) <> 0) or
     (not WGL_ARB_pixel_format) or (not WGL_ARB_multisample) or
     (not Assigned(wglChoosePixelFormatARB)) then
    Exit;

  Samples := RequestedSamples;
  if Samples > 8 then
    Samples := 8;

  while Samples >= 2 do
  begin
    FillChar(Attribs, SizeOf(Attribs), 0);
    Attribs[0] := WGL_DRAW_TO_WINDOW_ARB;  Attribs[1] := 1;
    Attribs[2] := WGL_SUPPORT_OPENGL_ARB;  Attribs[3] := 1;
    Attribs[4] := WGL_DOUBLE_BUFFER_ARB;   Attribs[5] := 1;
    Attribs[6] := WGL_ACCELERATION_ARB;    Attribs[7] := WGL_FULL_ACCELERATION_ARB;
    Attribs[8] := WGL_PIXEL_TYPE_ARB;      Attribs[9] := WGL_TYPE_RGBA_ARB;
    Attribs[10] := WGL_COLOR_BITS_ARB;     Attribs[11] := 32;
    Attribs[12] := WGL_DEPTH_BITS_ARB;     Attribs[13] := 24;
    Attribs[14] := WGL_STENCIL_BITS_ARB;   Attribs[15] := 0;
    Attribs[16] := WGL_SAMPLE_BUFFERS_ARB; Attribs[17] := 1;
    Attribs[18] := WGL_SAMPLES_ARB;        Attribs[19] := Samples;
    Attribs[20] := 0;

    PixelFormatGL := 0;
    NumFormats := 0;
    if Boolean(wglChoosePixelFormatARB(DC, @Attribs[0], nil, 1, @PixelFormatGL,
      @NumFormats)) and (NumFormats > 0) and (PixelFormatGL <> 0) then
    begin
      PixelFormat := PixelFormatGL;
      FillChar(PFDescriptor, SizeOf(PFDescriptor), 0);
      if Winapi.Windows.DescribePixelFormat(DC, PixelFormat, SizeOf(PFDescriptor),
        PFDescriptor) then
      begin
        QueryValue := Samples;
        if Assigned(wglGetPixelFormatAttribivARB) then
        begin
          QueryAttrib := WGL_SAMPLES_ARB;
          wglGetPixelFormatAttribivARB(DC, PixelFormatGL, 0, 1,
            @QueryAttrib, @QueryValue);
        end;

        if SetPixelFormat(DC, PixelFormat, @PFDescriptor) then
        begin
          ActualSamples := QueryValue;
          Exit(True);
        end;
      end;
    end;

    Samples := NextLowerSampleCount(Samples);
  end;
end;

function CreateOrthographicRH(AWidth, AHeight, ANearPlane, AFarPlane: Single): TMatrix4;
begin
  Result.InitOrthoOffCenterRH(
    -AWidth * 0.5,
     AHeight * 0.5,
     AWidth * 0.5,
    -AHeight * 0.5,
    ANearPlane,
    AFarPlane);
end;

{ TRenderContext }

constructor TRenderContext.Create(AWindowHandle: HWND; ARequestedSamples: Integer;
  out AActualSamples: Integer; ASharedContext: TRenderContext);
var
  OldContext: HGLRC;
  Attribs: array[0..6] of GLint;
  MultisamplePixelFormatSet: Boolean;
begin
  inherited Create;

  fWindowHandle := AWindowHandle;
  fDeviceContext := GetDC(fWindowHandle);
  if fDeviceContext = 0 then
    raise Exception.Create('Failed to get OpenGL device context');

  AActualSamples := 0;
  if not InitOpenGL then
    raise Exception.Create('Failed to initialize OpenGL');

  MultisamplePixelFormatSet := False;
  if ARequestedSamples > 1 then
    MultisamplePixelFormatSet := TrySetMultisamplePixelFormatUsingDummyContext(
      fDeviceContext, ARequestedSamples, AActualSamples);

  if MultisamplePixelFormatSet or (GetPixelFormat(fDeviceContext) <> 0) then
    OldContext := wglCreateContext(fDeviceContext)
  else
    OldContext := CreateRenderingContext(fDeviceContext, [opDoubleBuffered], 32, 24, 0, 0, 0, 0);

  if OldContext = 0 then
    raise Exception.Create('Failed to create temporary OpenGL context');

  ActivateRenderingContext(fDeviceContext, OldContext);
  try
    if Assigned(wglCreateContextAttribsARB) then
    begin
      Attribs[0] := WGL_CONTEXT_MAJOR_VERSION_ARB; Attribs[1] := 4;
      Attribs[2] := WGL_CONTEXT_MINOR_VERSION_ARB; Attribs[3] := 5;
      Attribs[4] := WGL_CONTEXT_PROFILE_MASK_ARB;  Attribs[5] := WGL_CONTEXT_CORE_PROFILE_BIT_ARB;
      Attribs[6] := 0;
      fRenderingContext := wglCreateContextAttribsARB(fDeviceContext, OldContext, @Attribs);
    end;

    if fRenderingContext = 0 then
      fRenderingContext := wglCreateContext(fDeviceContext);

    if fRenderingContext = 0 then
      raise Exception.Create('Failed to create OpenGL context');

    if Assigned(ASharedContext) and (ASharedContext.RenderingContext <> 0) then
      wglShareLists(ASharedContext.RenderingContext, fRenderingContext);
  finally
    wglMakeCurrent(0, 0);
    wglDeleteContext(OldContext);
  end;

  Activate;
end;

destructor TRenderContext.Destroy;
begin
  if fRenderingContext <> 0 then
  begin
    if not IsCurrent then
      Activate;
    wglMakeCurrent(0, 0);
    wglDeleteContext(fRenderingContext);
    fRenderingContext := 0;
  end;

  if fDeviceContext <> 0 then
  begin
    ReleaseDC(fWindowHandle, fDeviceContext);
    fDeviceContext := 0;
  end;

  inherited Destroy;
end;

procedure TRenderContext.Activate;
begin
  if (fDeviceContext <> 0) and (fRenderingContext <> 0) and (not IsCurrent) then
    wglMakeCurrent(fDeviceContext, fRenderingContext);
end;

procedure TRenderContext.Deactivate;
begin
  if IsCurrent then
    wglMakeCurrent(0, 0);
end;

function TRenderContext.IsCurrent: Boolean;
begin
  Result := (fDeviceContext <> 0) and (fRenderingContext <> 0) and
    (wglGetCurrentDC = fDeviceContext) and
    (wglGetCurrentContext = fRenderingContext);
end;

procedure TRenderContext.Swap;
begin
  if fDeviceContext <> 0 then
    SwapBuffers(fDeviceContext);
end;

{ TRenderer }
procedure TRenderer.UpdateFPS;
var
  nowTick: Int64;
  deltaSeconds: Double;
begin
  QueryPerformanceCounter(nowTick);
  Inc(fFrameCount);
  deltaSeconds := (nowTick - fLastTime) / fFPSCounter;
  fTimeAccum := fTimeAccum + deltaSeconds;
  fLastTime := nowTick;

  if fTimeAccum >= 1.0 then
  begin
    fCurrentFPS := Round(fFrameCount / fTimeAccum);
    fFrameCount := 0;
    fTimeAccum := 0.0;
  end;
end;

procedure TRenderer.SetupScene;
begin
  glBindFramebuffer(GL_FRAMEBUFFER, PresentFramebuffer);
  ApplyPresentViewport;

  FlushGLColor;

  glEnable(GL_DEPTH_TEST);
  glDepthFunc(GL_LEQUAL);

  glDisable(GL_CULL_FACE);

  ApplyAntialiasingState;

  glEnable(GL_BLEND);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
end;
                         // Replace with TObject
constructor TRenderer.Create(handleWindow: HWND; X, Y, aWidth, aHeight: Integer;
  clearColor: TVector4; AAntialiasingSamples: Integer; ASharedRenderer: TRenderer);
var
  RequestedSamples: Integer;
  SharedContext: TRenderContext;
begin
  inherited Create;

  fViewport.X := X;
  fViewport.Y := Y;
  fViewport.Width := aWidth;
  fViewport.Height := aHeight;
  fRenderTargetOverrideActive := False;
  fRenderTargetOverrideFBO := 0;
  fRenderTargetOverrideViewport.X := 0;
  fRenderTargetOverrideViewport.Y := 0;
  fRenderTargetOverrideViewport.Width := 0;
  fRenderTargetOverrideViewport.Height := 0;
  fRenderTargetOverrideSamples := 1;
  fSuppressBeforePresent := False;

  fBackgroundColor := clearColor;
  RequestedSamples := Max(0, AAntialiasingSamples);
  if AAntialiasingSamples = 0 then
    RequestedSamples := 0
  else if RequestedSamples < 2 then
    RequestedSamples := DEFAULT_ANTIALIASING_SAMPLES;
  fAntialiasingSamples := 0;
  fAntialiasingEnabled := RequestedSamples > 1;
  fSwapInterval := 0;
  fSwapIntervalSupported := False;
  fFrustumCullingEnabled := True;
  fViewFrustumValid := False;
  fShadowFrustumValid := False;
  fFogEnabled := True;
  fFogColor := clearColor;
  fFogDensity := 0.00045;
  fFogStart := 350.0;
  fFogEnd := 3200.0;

  fHandle := handleWindow;
  SharedContext := nil;
  if Assigned(ASharedRenderer) then
    SharedContext := ASharedRenderer.RenderContext;
  fRenderContext := TRenderContext.Create(fHandle, RequestedSamples,
    fAntialiasingSamples, SharedContext);

  ReadExtensions;
  ReadImplementationProperties;
  ApplySwapInterval;

  if fAntialiasingSamples <= 1 then
    fAntialiasingEnabled := False;

  fSceneManager := TSceneManager.Create;
  fCurrentSceneObject := nil;

  fFieldOfView := DegToRad(60.0);
  fNearPlaneDistance := 0.1;
  fFarPlaneDistance := 1000.0;
  fProjectionMatrix.InitPerspectiveFovRH(-fFieldOfView,
    Max(1.0, fViewport.Width) / Max(1.0, fViewport.Height),
    fNearPlaneDistance, fFarPlaneDistance);
  fShadowEnabled := True;
  fShadowMapSize := 4096; //;  8192
  fShadowFBO := 0;
  fShadowDepthTexture := 0;
  fShadowShader := nil;
  fShadowLight := nil;
  fShadowLightViewProjection := TMatrix4.Identity;
  fShadowMapCount := 0;
  fShadowTarget := Vector3(0, 0, 0);
  fShadowDistance := 25.0;
  fShadowArea := 24.0;
  fShadowAutoFit := True;
  fShadowFitPadding := 1.25;
  fShadowDrawCount := 0;
  fWaterReflectionEnabled := True;
  fWaterReflectionFBO := 0;
  fWaterReflectionTexture := 0;
  fWaterReflectionDepthRBO := 0;
  fWaterReflectionWidth := 0;
  fWaterReflectionHeight := 0;
  fWaterShader := nil;
  fWaterReflectionCameraObject := nil;
  fRenderingWaterReflection := False;
  fSceneClipPlaneEnabled := False;
  fSceneClipPlane := Vector4(0.0, 1.0, 0.0, 0.0);
  fWaterTime := 0.0;
  fPostProcessShader := nil;
  fPostProcessFBO := 0;
  fPostProcessColorTexture := 0;
  fPostProcessDepthRBO := 0;
  fPostProcessWidth := 0;
  fPostProcessHeight := 0;
  fFullscreenVAO := 0;
  fFullscreenVBO := 0;
  ResetPostEffectsToDefaults;
  fEmptyObjectMarkersEnabled := True;
  fEmptyObjectMarkerSize := 0.22;
  fEmptyObjectMarkerColor := Vector4(1.0, 0.86, 0.2, 0.95);
  fEmptyObjectMarkerVAO := 0;
  fEmptyObjectMarkerVBO := 0;
  fEmptyObjectMarkerVertexCount := 0;
  fEmptyObjectMarkerShader := nil;
  fGuiRenderer := nil;
  fSkyDome := nil;
  fSelectedBoundingBoxEnabled := False;
  fSelectedBoundingBoxObject := nil;
  fSelectedBoundingBoxColor := Vector4(0.0, 1.0, 0.0, 1.0);
  fSelectedBoundingBoxVAO := 0;
  fSelectedBoundingBoxVBO := 0;
  fSelectedBoundingBoxVertexCount := 0;

  SetupScene;
  SetupShadowMap(fShadowMapSize);
  SetupEmptyObjectMarkerGeometry;
  SetupSelectedBoundingBoxGeometry;

  // Initialize FPS counters
  QueryPerformanceFrequency(fFPSCounter);
  QueryPerformanceCounter(fLastTime);
  fLastParticleTime := fLastTime;
  fFrameCount := 0;
  fTimeAccum := 0.0;
  fCurrentFPS := 0;
  fTriangleCount := 0;
end;

destructor TRenderer.Destroy;
begin
  ActivateContext;

  if fGuiRenderer <> nil then
    FreeAndNil(fGuiRenderer);

  if fSkyDome <> nil then
    FreeAndNil(fSkyDome);

  DestroySelectedBoundingBox;
  DestroyEmptyObjectMarker;
  DestroyWaterReflection;
  DestroyPostProcessResources;
  if fFullscreenVBO <> 0 then
  begin
    glDeleteBuffers(1, @fFullscreenVBO);
    fFullscreenVBO := 0;
  end;
  if fFullscreenVAO <> 0 then
  begin
    glDeleteVertexArrays(1, @fFullscreenVAO);
    fFullscreenVAO := 0;
  end;
  if fPostProcessShader <> nil then
    FreeAndNil(fPostProcessShader);
  DestroyShadowMap;

  if fSceneManager <> nil then
    fSceneManager.Free;

  FreeAndNil(fRenderContext);

  inherited Destroy;
end;

procedure TRenderer.FlushGLColor(const aColor: TVector4);
begin
  fBackgroundColor := aColor;
  glClearColor(fBackgroundColor.R,
               fBackgroundColor.G,
               fBackgroundColor.B,
               fBackgroundColor.A);
end;

procedure TRenderer.FlushGLColor;
begin
  glClearColor(fBackgroundColor.R,
               fBackgroundColor.G,
               fBackgroundColor.B,
               fBackgroundColor.A);
end;

procedure TRenderer.ApplySwapInterval;
begin
  fSwapIntervalSupported := WGL_EXT_swap_control and Assigned(wglSwapIntervalEXT);
  if not fSwapIntervalSupported then
    Exit;

  wglSwapIntervalEXT(fSwapInterval);

  if Assigned(wglGetSwapIntervalEXT) then
    fSwapInterval := wglGetSwapIntervalEXT;
end;

function TRenderer.GetVSyncEnabled: Boolean;
begin
  Result := fSwapInterval <> 0;
end;

procedure TRenderer.SetSwapInterval(const Value: GLint);
begin
  fSwapInterval := Value;
  ActivateContext;
  ApplySwapInterval;
end;

procedure TRenderer.SetVSyncEnabled(const Value: Boolean);
begin
  if Value then
    SetSwapInterval(1)
  else
    SetSwapInterval(0);
end;

function TRenderer.GetPostProcessActive: Boolean;
begin
  Result := fHDREnabled and (fPostProcessShader <> nil) and
    (fViewport.Width > 0) and (fViewport.Height > 0);
end;

procedure TRenderer.SetHDREnabled(const Value: Boolean);
begin
  if fHDREnabled = Value then
  begin
    if Value or ((fPostProcessFBO = 0) and (fPostProcessColorTexture = 0) and
       (fPostProcessDepthRBO = 0)) then
      Exit;
  end
  else
    fHDREnabled := Value;

  if not Value then
  begin
    ActivateContext;
    glBindFramebuffer(GL_FRAMEBUFFER, PresentFramebuffer);
    ApplyPresentViewport;
    DestroyPostProcessResources;
  end;
end;

function TRenderer.PresentFramebuffer: GLuint;
begin
  if fRenderTargetOverrideActive then
    Result := fRenderTargetOverrideFBO
  else
    Result := 0;
end;

procedure TRenderer.ApplyPresentViewport;
begin
  if fRenderTargetOverrideActive then
    glViewport(fRenderTargetOverrideViewport.X,
      fRenderTargetOverrideViewport.Y,
      fRenderTargetOverrideViewport.Width,
      fRenderTargetOverrideViewport.Height)
  else
    glViewport(fViewport.X, fViewport.Y, fViewport.Width, fViewport.Height);
end;

function TRenderer.ActiveAntialiasingSamples: Integer;
begin
  if fRenderTargetOverrideActive then
    Result := fRenderTargetOverrideSamples
  else if fAntialiasingEnabled then
    Result := fAntialiasingSamples
  else
    Result := 1;

  if Result < 1 then
    Result := 1;
end;

procedure TRenderer.ApplyAntialiasingState;
begin
  if ActiveAntialiasingSamples > 1 then
    glEnable(GL_MULTISAMPLE)
  else
    glDisable(GL_MULTISAMPLE);
end;

procedure TRenderer.ResetPostEffectsToDefaults;
begin
  SetHDREnabled(False);
  fToneMappingMode := tmACES;
  fToneExposure := 1.0;
  fToneGamma := 2.2;
  fGodRaysEnabled := False;
  fGodRaySamples := 64;
  fGodRayDensity := 0.85;
  fGodRayExposure := 0.24;
  fGodRayDecay := 0.94;
  fGodRayWeight := 0.22;
  fGodRayIntensity := 1.0;
end;

procedure TRenderer.SetSkyDome(const Value: TSkyDome);
begin
  if fSkyDome = Value then
    Exit;

  if fSkyDome <> nil then
    FreeAndNil(fSkyDome);

  fSkyDome := Value;
end;

procedure TRenderer.ActivateContext;
begin
  if Assigned(fRenderContext) then
  begin
    fRenderContext.Activate;
    ApplySwapInterval;
  end;
end;

procedure TRenderer.BeginFrame;
begin
  ActivateContext;

  if GetPostProcessActive then
  begin
    SetupPostProcessResources(fViewport.Width, fViewport.Height);
    glBindFramebuffer(GL_FRAMEBUFFER, fPostProcessFBO);
    glViewport(0, 0, fPostProcessWidth, fPostProcessHeight);
    glDisable(GL_MULTISAMPLE);
  end
  else
  begin
    glBindFramebuffer(GL_FRAMEBUFFER, PresentFramebuffer);
    ApplyPresentViewport;

    ApplyAntialiasingState;
  end;

  FlushGLColor;

  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
end;

procedure TRenderer.EndFrame;
begin
  ActivateContext;
  if (not fRenderTargetOverrideActive) and Assigned(fRenderContext) then
    fRenderContext.Swap;
end;

procedure TRenderer.DestroyEmptyObjectMarker;
begin
  if fEmptyObjectMarkerVBO <> 0 then
  begin
    glDeleteBuffers(1, @fEmptyObjectMarkerVBO);
    fEmptyObjectMarkerVBO := 0;
  end;

  if fEmptyObjectMarkerVAO <> 0 then
  begin
    glDeleteVertexArrays(1, @fEmptyObjectMarkerVAO);
    fEmptyObjectMarkerVAO := 0;
  end;

  if fEmptyObjectMarkerShader <> nil then
    FreeAndNil(fEmptyObjectMarkerShader);

  fEmptyObjectMarkerVertexCount := 0;
end;

procedure TRenderer.SetupEmptyObjectMarkerGeometry;
const
  H = 0.5;
var
  Vertices: array[0..23] of TVector3;
begin
  if fEmptyObjectMarkerVAO <> 0 then
    Exit;

  Vertices[0] := Vector3(-H, -H, -H); Vertices[1] := Vector3( H, -H, -H);
  Vertices[2] := Vector3( H, -H, -H); Vertices[3] := Vector3( H,  H, -H);
  Vertices[4] := Vector3( H,  H, -H); Vertices[5] := Vector3(-H,  H, -H);
  Vertices[6] := Vector3(-H,  H, -H); Vertices[7] := Vector3(-H, -H, -H);

  Vertices[8] := Vector3(-H, -H,  H); Vertices[9] := Vector3( H, -H,  H);
  Vertices[10] := Vector3( H, -H,  H); Vertices[11] := Vector3( H,  H,  H);
  Vertices[12] := Vector3( H,  H,  H); Vertices[13] := Vector3(-H,  H,  H);
  Vertices[14] := Vector3(-H,  H,  H); Vertices[15] := Vector3(-H, -H,  H);

  Vertices[16] := Vector3(-H, -H, -H); Vertices[17] := Vector3(-H, -H,  H);
  Vertices[18] := Vector3( H, -H, -H); Vertices[19] := Vector3( H, -H,  H);
  Vertices[20] := Vector3( H,  H, -H); Vertices[21] := Vector3( H,  H,  H);
  Vertices[22] := Vector3(-H,  H, -H); Vertices[23] := Vector3(-H,  H,  H);

  fEmptyObjectMarkerVertexCount := Length(Vertices);

  glGenVertexArrays(1, @fEmptyObjectMarkerVAO);
  glBindVertexArray(fEmptyObjectMarkerVAO);

  glGenBuffers(1, @fEmptyObjectMarkerVBO);
  glBindBuffer(GL_ARRAY_BUFFER, fEmptyObjectMarkerVBO);
  glBufferData(GL_ARRAY_BUFFER, SizeOf(Vertices), @Vertices[0], GL_STATIC_DRAW);

  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, SizeOf(TVector3), nil);

  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glBindVertexArray(0);
end;

procedure TRenderer.DestroySelectedBoundingBox;
begin
  if fSelectedBoundingBoxVBO <> 0 then
  begin
    glDeleteBuffers(1, @fSelectedBoundingBoxVBO);
    fSelectedBoundingBoxVBO := 0;
  end;

  if fSelectedBoundingBoxVAO <> 0 then
  begin
    glDeleteVertexArrays(1, @fSelectedBoundingBoxVAO);
    fSelectedBoundingBoxVAO := 0;
  end;

  fSelectedBoundingBoxVertexCount := 0;
end;

procedure TRenderer.SetupSelectedBoundingBoxGeometry;
begin
  if fSelectedBoundingBoxVAO <> 0 then
    Exit;

  fSelectedBoundingBoxVertexCount := 24;

  glGenVertexArrays(1, @fSelectedBoundingBoxVAO);
  glBindVertexArray(fSelectedBoundingBoxVAO);

  glGenBuffers(1, @fSelectedBoundingBoxVBO);
  glBindBuffer(GL_ARRAY_BUFFER, fSelectedBoundingBoxVBO);
  glBufferData(GL_ARRAY_BUFFER, fSelectedBoundingBoxVertexCount * SizeOf(TVector3),
    nil, GL_DYNAMIC_DRAW);

  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, SizeOf(TVector3), nil);

  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glBindVertexArray(0);
end;

procedure TRenderer.DestroyShadowMap;
begin
  fShadowMapCount := 0;

  if fShadowFBO <> 0 then
  begin
    glDeleteFramebuffers(1, @fShadowFBO);
    fShadowFBO := 0;
  end;

  if fShadowDepthTexture <> 0 then
  begin
    glDeleteTextures(1, @fShadowDepthTexture);
    fShadowDepthTexture := 0;
  end;

  if fShadowShader <> nil then
    FreeAndNil(fShadowShader);
end;

procedure TRenderer.DestroyWaterReflection;
begin
  if fWaterReflectionDepthRBO <> 0 then
  begin
    glDeleteRenderbuffers(1, @fWaterReflectionDepthRBO);
    fWaterReflectionDepthRBO := 0;
  end;

  if fWaterReflectionTexture <> 0 then
  begin
    glDeleteTextures(1, @fWaterReflectionTexture);
    fWaterReflectionTexture := 0;
  end;

  if fWaterReflectionFBO <> 0 then
  begin
    glDeleteFramebuffers(1, @fWaterReflectionFBO);
    fWaterReflectionFBO := 0;
  end;

  if fWaterShader <> nil then
    FreeAndNil(fWaterShader);

  if fWaterReflectionCameraObject <> nil then
    FreeAndNil(fWaterReflectionCameraObject);

  fWaterReflectionWidth := 0;
  fWaterReflectionHeight := 0;
end;

procedure TRenderer.LoadShadowShaderFromFile(const VertexFileName, FragmentFileName: string);
begin
  if fShadowShader <> nil then
    FreeAndNil(fShadowShader);

  fShadowShader := TShader.Create(VertexFileName, FragmentFileName);
end;

procedure TRenderer.LoadWaterShaderFromFile(const VertexFileName,
  FragmentFileName: string);
begin
  if fWaterShader <> nil then
    FreeAndNil(fWaterShader);

  fWaterShader := TShader.Create(VertexFileName, FragmentFileName);
end;

procedure TRenderer.LoadPostProcessShaderFromFile(const VertexFileName,
  FragmentFileName: string);
begin
  if fPostProcessShader <> nil then
    FreeAndNil(fPostProcessShader);

  fPostProcessShader := TShader.Create(VertexFileName, FragmentFileName);
end;

procedure TRenderer.LoadEmptyObjectMarkerShaderFromFile(const VertexFileName, FragmentFileName: string);
begin
  if fEmptyObjectMarkerShader <> nil then
    FreeAndNil(fEmptyObjectMarkerShader);

  fEmptyObjectMarkerShader := TShader.Create(VertexFileName, FragmentFileName);
end;

procedure TRenderer.SetupWaterReflection(AWidth, AHeight: Integer);
var
  Status: GLenum;
begin
  ActivateContext;

  AWidth := System.Math.Max(64, AWidth);
  AHeight := System.Math.Max(64, AHeight);

  if (fWaterReflectionFBO <> 0) and (fWaterReflectionTexture <> 0) and
     (fWaterReflectionDepthRBO <> 0) and
     (fWaterReflectionWidth = AWidth) and
     (fWaterReflectionHeight = AHeight) then
    Exit;

  if fWaterReflectionDepthRBO <> 0 then
  begin
    glDeleteRenderbuffers(1, @fWaterReflectionDepthRBO);
    fWaterReflectionDepthRBO := 0;
  end;

  if fWaterReflectionTexture <> 0 then
  begin
    glDeleteTextures(1, @fWaterReflectionTexture);
    fWaterReflectionTexture := 0;
  end;

  if fWaterReflectionFBO <> 0 then
  begin
    glDeleteFramebuffers(1, @fWaterReflectionFBO);
    fWaterReflectionFBO := 0;
  end;

  fWaterReflectionWidth := AWidth;
  fWaterReflectionHeight := AHeight;

  glGenFramebuffers(1, @fWaterReflectionFBO);
  glBindFramebuffer(GL_FRAMEBUFFER, fWaterReflectionFBO);

  glGenTextures(1, @fWaterReflectionTexture);
  glBindTexture(GL_TEXTURE_2D, fWaterReflectionTexture);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, fWaterReflectionWidth,
    fWaterReflectionHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, nil);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D,
    fWaterReflectionTexture, 0);

  glGenRenderbuffers(1, @fWaterReflectionDepthRBO);
  glBindRenderbuffer(GL_RENDERBUFFER, fWaterReflectionDepthRBO);
  glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24,
    fWaterReflectionWidth, fWaterReflectionHeight);
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,
    GL_RENDERBUFFER, fWaterReflectionDepthRBO);

  Status := glCheckFramebufferStatus(GL_FRAMEBUFFER);

  glBindRenderbuffer(GL_RENDERBUFFER, 0);
  glBindTexture(GL_TEXTURE_2D, 0);
  glBindFramebuffer(GL_FRAMEBUFFER, 0);

  if Status <> GL_FRAMEBUFFER_COMPLETE then
    raise Exception.CreateFmt('Water reflection framebuffer incomplete: %d',
      [Status]);
end;

procedure TRenderer.DestroyPostProcessResources;
begin
  if fPostProcessDepthRBO <> 0 then
  begin
    glDeleteRenderbuffers(1, @fPostProcessDepthRBO);
    fPostProcessDepthRBO := 0;
  end;

  if fPostProcessColorTexture <> 0 then
  begin
    glDeleteTextures(1, @fPostProcessColorTexture);
    fPostProcessColorTexture := 0;
  end;

  if fPostProcessFBO <> 0 then
  begin
    glDeleteFramebuffers(1, @fPostProcessFBO);
    fPostProcessFBO := 0;
  end;

  fPostProcessWidth := 0;
  fPostProcessHeight := 0;
end;

procedure TRenderer.SetupPostProcessResources(AWidth, AHeight: Integer);
var
  Status: GLenum;
begin
  ActivateContext;

  AWidth := System.Math.Max(64, AWidth);
  AHeight := System.Math.Max(64, AHeight);

  if (fPostProcessFBO <> 0) and (fPostProcessColorTexture <> 0) and
     (fPostProcessDepthRBO <> 0) and (fPostProcessWidth = AWidth) and
     (fPostProcessHeight = AHeight) then
    Exit;

  DestroyPostProcessResources;

  fPostProcessWidth := AWidth;
  fPostProcessHeight := AHeight;

  glGenFramebuffers(1, @fPostProcessFBO);
  glBindFramebuffer(GL_FRAMEBUFFER, fPostProcessFBO);

  glGenTextures(1, @fPostProcessColorTexture);
  glBindTexture(GL_TEXTURE_2D, fPostProcessColorTexture);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA16F, fPostProcessWidth,
    fPostProcessHeight, 0, GL_RGBA, GL_FLOAT, nil);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D,
    fPostProcessColorTexture, 0);

  glGenRenderbuffers(1, @fPostProcessDepthRBO);
  glBindRenderbuffer(GL_RENDERBUFFER, fPostProcessDepthRBO);
  glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24,
    fPostProcessWidth, fPostProcessHeight);
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,
    GL_RENDERBUFFER, fPostProcessDepthRBO);

  Status := glCheckFramebufferStatus(GL_FRAMEBUFFER);

  glBindRenderbuffer(GL_RENDERBUFFER, 0);
  glBindTexture(GL_TEXTURE_2D, 0);
  glBindFramebuffer(GL_FRAMEBUFFER, 0);

  if Status <> GL_FRAMEBUFFER_COMPLETE then
    raise Exception.CreateFmt('HDR post-process framebuffer incomplete: %d',
      [Status]);
end;

procedure TRenderer.SetupFullscreenQuad;
const
  Vertices: array[0..23] of GLfloat = (
    -1.0, -1.0, 0.0, 0.0,
     1.0, -1.0, 1.0, 0.0,
     1.0,  1.0, 1.0, 1.0,
    -1.0, -1.0, 0.0, 0.0,
     1.0,  1.0, 1.0, 1.0,
    -1.0,  1.0, 0.0, 1.0
  );
begin
  if fFullscreenVAO <> 0 then
    Exit;

  glGenVertexArrays(1, @fFullscreenVAO);
  glBindVertexArray(fFullscreenVAO);

  glGenBuffers(1, @fFullscreenVBO);
  glBindBuffer(GL_ARRAY_BUFFER, fFullscreenVBO);
  glBufferData(GL_ARRAY_BUFFER, SizeOf(Vertices), @Vertices[0], GL_STATIC_DRAW);

  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * SizeOf(GLfloat), nil);
  glEnableVertexAttribArray(1);
  glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * SizeOf(GLfloat),
    Pointer(NativeUInt(2 * SizeOf(GLfloat))));

  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glBindVertexArray(0);
end;

procedure TRenderer.EnsureWaterReflectionResources;
begin
  if not fWaterReflectionEnabled then
    Exit;

  SetupWaterReflection(fViewport.Width, fViewport.Height);

  if fWaterReflectionCameraObject = nil then
  begin
    fWaterReflectionCameraObject := TSceneObject.Create(nil);
    fWaterReflectionCameraObject.Name := 'WaterReflectionCamera';
    fWaterReflectionCameraObject.CreateCamera;
  end;
end;

procedure TRenderer.LoadGuiShaderFromFile(const VertexFileName,
  FragmentFileName: string);
begin
  if fGuiRenderer <> nil then
    FreeAndNil(fGuiRenderer);

  fGuiRenderer := TGuiRenderer.Create(VertexFileName, FragmentFileName);
end;

function TRenderer.RequireGuiRenderer: TGuiRenderer;
begin
  ActivateContext;
  Result := fGuiRenderer;
  if Result = nil then
    raise Exception.Create('GUI renderer is not initialized. Call LoadGuiShaderFromFile first.');
end;

procedure TRenderer.RenderGuiSolidRect(AX, AY, AWidth, AHeight: Single;
  const AColor: TVector4);
begin
  RequireGuiRenderer.RenderSolidRect(AX, AY, AWidth, AHeight,
    fViewport.Width, fViewport.Height, AColor);
end;

procedure TRenderer.RenderGuiVertices(const AVertices: TArray<TGuiVertex>;
  ATextureID: GLuint; const ATint: TVector4);
begin
  RequireGuiRenderer.RenderVertices(AVertices, ATextureID, fViewport.Width,
    fViewport.Height, ATint);
end;

procedure TRenderer.RenderGuiComponent(AComponent: TGuiComponent;
  ATexture: TGuiTexture; AX, AY, AWidth, AHeight: Single;
  const ATint: TVector4; AScale: Single);
begin
  RequireGuiRenderer.RenderComponent(AComponent, ATexture, AX, AY, AWidth,
    AHeight, fViewport.Width, fViewport.Height, ATint, AScale);
end;

procedure TRenderer.RenderGuiLayout(ALayout: TGuiLayout;
  const AComponentName: string; AX, AY, AWidth, AHeight: Single;
  const ATint: TVector4; AScale: Single);
begin
  RequireGuiRenderer.RenderLayout(ALayout, AComponentName, AX, AY, AWidth,
    AHeight, fViewport.Width, fViewport.Height, ATint, AScale);
end;

procedure TRenderer.RenderGuiControl(AControl: TGuiControl);
begin
  if AControl = nil then
    Exit;

  AControl.Render(RequireGuiRenderer, fViewport.Width, fViewport.Height);
end;

procedure TRenderer.SetupShadowMap(ASize: Integer);
var
  BorderColor: array[0..3] of GLfloat;
  Status: GLenum;
begin
  ActivateContext;

  if ASize < 64 then
    ASize := 64;

  fShadowMapSize := ASize;

  if fShadowFBO <> 0 then
  begin
    glDeleteFramebuffers(1, @fShadowFBO);
    fShadowFBO := 0;
  end;

  if fShadowDepthTexture <> 0 then
  begin
    glDeleteTextures(1, @fShadowDepthTexture);
    fShadowDepthTexture := 0;
  end;
  fShadowMapCount := 0;

  glGenFramebuffers(1, @fShadowFBO);
  glGenTextures(1, @fShadowDepthTexture);
  glBindTexture(GL_TEXTURE_2D_ARRAY, fShadowDepthTexture);
  glTexImage3D(GL_TEXTURE_2D_ARRAY, 0, GL_DEPTH_COMPONENT32F,
    fShadowMapSize, fShadowMapSize, MAX_RENDERER_SHADOW_MAPS, 0,
    GL_DEPTH_COMPONENT, GL_FLOAT, nil);
  glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
  glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
  glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_COMPARE_MODE, GL_NONE);
  BorderColor[0] := 1.0;
  BorderColor[1] := 1.0;
  BorderColor[2] := 1.0;
  BorderColor[3] := 1.0;
  glTexParameterfv(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_BORDER_COLOR, @BorderColor[0]);

  glBindFramebuffer(GL_FRAMEBUFFER, fShadowFBO);
  glFramebufferTextureLayer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,
    fShadowDepthTexture, 0, 0);
  glDrawBuffer(GL_NONE);
  glReadBuffer(GL_NONE);

  Status := glCheckFramebufferStatus(GL_FRAMEBUFFER);
  glBindFramebuffer(GL_FRAMEBUFFER, 0);
  glBindTexture(GL_TEXTURE_2D_ARRAY, 0);

  if Status <> GL_FRAMEBUFFER_COMPLETE then
    raise Exception.CreateFmt('Shadow framebuffer incomplete: %d', [Status]);
end;

function TRenderer.MeshCastsShadowByDefault(AMesh: TMesh;
  const AWorldBounds: TAABB): Boolean;
var
  Extents: TVector3;
  HorizontalExtent: Single;
begin
  Result := Assigned(AMesh);
  if not Result then
    Exit;

  if not AWorldBounds.IsValid then
    Exit(False);

  if AMesh.MeshType in [mtPlane, mtWater, mtHeightField] then
    Exit(False);

  Extents := AWorldBounds.Extents;
  HorizontalExtent := System.Math.Max(Extents.X, Extents.Z);
  if (Extents.Y < 0.05) and (HorizontalExtent > 4.0) then
    Exit(False);
end;

function TRenderer.TryGetShadowCasterBounds(out Bounds: TAABB): Boolean;
var
  AllBounds: TAABB;
  CasterBounds: TAABB;
  HasAllBounds: Boolean;
  HasCasterBounds: Boolean;

  procedure InitBounds(var ABounds: TAABB);
  begin
    ABounds.Min := Vector3(MaxSingle, MaxSingle, MaxSingle);
    ABounds.Max := Vector3(-MaxSingle, -MaxSingle, -MaxSingle);
  end;

  procedure IncludeBounds(var ABounds: TAABB; var AHasBounds: Boolean;
    const AIncludeBounds: TAABB);
  begin
    if not AIncludeBounds.IsValid then
      Exit;

    if not AHasBounds then
    begin
      ABounds := AIncludeBounds;
      AHasBounds := True;
    end
  else
      ABounds.Include(AIncludeBounds);
  end;

  procedure IncludeObject(aObject: TSceneObject);
  var
    I: Integer;
    Meshes: TMeshList;
    Mesh: TMesh;
    WorldBounds: TAABB;
  begin
    if (aObject = nil) or aObject.IsGizmo then
      Exit;

    Meshes := aObject.EffectiveMeshList;
    if Assigned(Meshes) then
    for I := 0 to Meshes.Count - 1 do
    begin
      Mesh := Meshes.Item[I];
      if (Mesh = nil) or (not Mesh.Visible) then
        Continue;

      Mesh.ParentModelMatrix := aObject.WorldMatrix;
      WorldBounds := Mesh.GetBoundingBox.Transform(Mesh.ModelMatrix);
      IncludeBounds(AllBounds, HasAllBounds, WorldBounds);

      if MeshCastsShadowByDefault(Mesh, WorldBounds) then
        IncludeBounds(CasterBounds, HasCasterBounds, WorldBounds);
    end;

    for I := 0 to aObject.Count - 1 do
      IncludeObject(aObject.ObjectList[I]);
  end;

begin
  InitBounds(AllBounds);
  InitBounds(CasterBounds);
  HasAllBounds := False;
  HasCasterBounds := False;

  if (fSceneManager = nil) or (fSceneManager.Root = nil) then
    Exit(False);

  IncludeObject(fSceneManager.Root);

  if HasCasterBounds then
    Bounds := CasterBounds
  else if HasAllBounds then
    Bounds := AllBounds
  else
    Exit(False);

  Result := Bounds.IsValid;
end;

function TRenderer.CalculateShadowLightMatrix(ALight: TLight): TMatrix4;
var
  ViewMatrix, ProjectionMatrix: TMatrix4;
  Eye, Target, Up, Direction, SceneCenter: TVector3;
  SceneRadius, EffectiveArea, EffectiveDistance, EffectiveFar: Single;
  SceneBounds: TAABB;
  HasSceneBounds: Boolean;

  function StableDirectionalShadowDirection(const ADirection: TVector3): TVector3;
  begin
    Result := ADirection;
    if Result.LengthSquared < 1e-6 then
      Result := Vector3(-0.35, -1.0, -0.35);

    Result.Normalize;
  end;

  procedure ExpandBoundsForProjectedDirectionalShadow(var ABounds: TAABB;
    const ADirection: TVector3);
  var
    Corners: array[0..7] of TVector3;
    I: Integer;
    ReceiverY: Single;
    T: Single;
    MaxProjectionDistance: Single;
  begin
    if (not ABounds.IsValid) or (Abs(ADirection.Y) < 1e-4) then
      Exit;

    Corners[0] := Vector3(ABounds.Min.X, ABounds.Min.Y, ABounds.Min.Z);
    Corners[1] := Vector3(ABounds.Min.X, ABounds.Min.Y, ABounds.Max.Z);
    Corners[2] := Vector3(ABounds.Min.X, ABounds.Max.Y, ABounds.Min.Z);
    Corners[3] := Vector3(ABounds.Min.X, ABounds.Max.Y, ABounds.Max.Z);
    Corners[4] := Vector3(ABounds.Max.X, ABounds.Min.Y, ABounds.Min.Z);
    Corners[5] := Vector3(ABounds.Max.X, ABounds.Min.Y, ABounds.Max.Z);
    Corners[6] := Vector3(ABounds.Max.X, ABounds.Max.Y, ABounds.Min.Z);
    Corners[7] := Vector3(ABounds.Max.X, ABounds.Max.Y, ABounds.Max.Z);

    ReceiverY := System.Math.Min(ABounds.Min.Y, 0.0);
    MaxProjectionDistance := System.Math.Max(fShadowDistance * 4.0,
      fShadowArea * 4.0);

    for I := Low(Corners) to High(Corners) do
    begin
      T := (ReceiverY - Corners[I].Y) / ADirection.Y;
      if (T > 0.0) and (T <= MaxProjectionDistance) then
        ABounds.Include(Corners[I] + ADirection * T);
    end;
  end;
begin
  Target := fShadowTarget;
  EffectiveArea := fShadowArea;
  EffectiveDistance := fShadowDistance;
  EffectiveFar := fShadowDistance * 3.0;
  HasSceneBounds := fShadowAutoFit and TryGetShadowCasterBounds(SceneBounds);

  if HasSceneBounds then
    Target := SceneBounds.Center;

  EffectiveArea := Max(EffectiveArea, 1.0);
  EffectiveDistance := Max(EffectiveDistance, 1.0);
  EffectiveFar := Max(EffectiveFar, EffectiveDistance + 1.0);

  Direction := Vector3(-0.35, -1.0, -0.35);
  Direction.Normalize;
  Eye := Target - Direction * EffectiveDistance;

  if Assigned(ALight) then
  begin
    case ALight.LightType of
      ltDirectional:
        begin
          if ALight.UseTarget then
          begin
            if ALight.ResolveTargetDirection(Direction) then
              ALight.Direction := Direction;
          end;
          Direction := StableDirectionalShadowDirection(ALight.Direction);
          Eye := Target - Direction * EffectiveDistance;
        end;
      ltPoint, ltSpot:
        begin
          if (ALight.LightType = ltSpot) and ALight.UseTarget then
          begin
            Target := ALight.TargetPosition;
            if ALight.ResolveTargetDirection(Direction) then
              ALight.Direction := Direction;
          end;
          Eye := ALight.Position;
          Direction := Target - Eye;
          if Direction.LengthSquared < 1e-6 then
            Direction := Vector3(-0.35, -1.0, -0.35);
          Direction.Normalize;
        end;
    end;
  end;

  if HasSceneBounds and ((ALight = nil) or
     (ALight.LightType = ltDirectional)) then
  begin
    ExpandBoundsForProjectedDirectionalShadow(SceneBounds, Direction);
    SceneCenter := SceneBounds.Center;
    SceneRadius := Max((SceneBounds.Max - SceneBounds.Min).Length * 0.5, 1.0);
    Target := SceneCenter;
    EffectiveArea := Max(EffectiveArea, SceneRadius * 2.0 * fShadowFitPadding);
    EffectiveDistance := Max(EffectiveDistance,
      SceneRadius * 2.0 * fShadowFitPadding);
    EffectiveFar := Max(EffectiveFar,
      EffectiveDistance + SceneRadius * 2.0 * fShadowFitPadding);
  end;

  Up := Vector3(0, 1, 0);
  if Abs(Direction.Dot(Up)) > 0.95 then
    Up := Vector3(1, 0, 0);

  {ViewMatrix.InitLookAtRH(Eye, Target, Up);
  ProjectionMatrix := CreateOrthographicRH(EffectiveArea, EffectiveArea, 0.1, EffectiveFar);
  fShadowLightViewProjection := ProjectionMatrix * ViewMatrix;}
  // Directional shadow maps should be centered around the target.
  // Do not put the target deep at +distance or -distance in light-view Z.
  if (ALight = nil) or (ALight.LightType = ltDirectional) then
    Eye := Target - Direction; // unit offset; direction only matters for directional light

  ViewMatrix.InitLookAtRH(Eye, Target, Up);

  // Center the shadow depth range around the target.
  // This is the important part: allow both negative and positive light-view Z.
  EffectiveFar := Max(EffectiveFar, EffectiveArea * 2.0);
  ProjectionMatrix := CreateOrthographicRH(
    EffectiveArea,
    EffectiveArea,
    -EffectiveFar,
     EffectiveFar);

  Result := ProjectionMatrix * ViewMatrix;
end;

procedure TRenderer.UpdateShadowLightMatrix(aLightObject: TSceneObject);
var
  Light: TLight;
begin
  Light := nil;
  if Assigned(aLightObject) and (aLightObject.LightsCount > 0) then
    Light := aLightObject.Light[0];

  fShadowLightViewProjection := CalculateShadowLightMatrix(Light);
end;

function TRenderer.FindShadowLightObject(aObject: TSceneObject): TSceneObject;
var
  i: Integer;
  Light: TLight;
begin
  Result := nil;
  if aObject = nil then
    Exit;

  for i := 0 to aObject.LightsCount - 1 do
  begin
    Light := aObject.Light[i];
    if Assigned(Light) and Light.Enabled and Light.CastShadows then
      Exit(aObject);
  end;

  for i := 0 to aObject.Count - 1 do
  begin
    Result := FindShadowLightObject(aObject.ObjectList[i]);
    if Result <> nil then
      Exit;
  end;
end;

function TRenderer.AddShadowMapLight(ALight: TLight; ALightIndex: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;

  if (ALight = nil) or (ALightIndex < 0) or
     (fShadowMapCount >= MAX_RENDERER_SHADOW_MAPS) then
    Exit;

  if (not ALight.Enabled) or (not ALight.CastShadows) or
     (not (ALight.LightType in [ltDirectional, ltSpot])) then
    Exit;

  for I := 0 to fShadowMapCount - 1 do
    if fShadowMaps[I].Light = ALight then
      Exit;

  fShadowMaps[fShadowMapCount].Light := ALight;
  fShadowMaps[fShadowMapCount].LightIndex := ALightIndex;
  fShadowMaps[fShadowMapCount].Matrix := TMatrix4.Identity;
  fShadowMaps[fShadowMapCount].Strength := ALight.ShadowStrength;
  Inc(fShadowMapCount);
  Result := True;
end;

function TRenderer.ShadowMapLayerForLightIndex(ALightIndex: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to fShadowMapCount - 1 do
    if fShadowMaps[I].LightIndex = ALightIndex then
      Exit(I);
end;

function TRenderer.ShadowLightMatrixForLightIndex(ALightIndex: Integer): TMatrix4;
var
  I: Integer;
begin
  Result := TMatrix4.Identity;
  for I := 0 to fShadowMapCount - 1 do
    if fShadowMaps[I].LightIndex = ALightIndex then
      Exit(fShadowMaps[I].Matrix);
end;

function TRenderer.ShadowStrengthForLightIndex(ALightIndex: Integer): Single;
var
  I: Integer;
begin
  Result := 0.0;
  for I := 0 to fShadowMapCount - 1 do
    if fShadowMaps[I].LightIndex = ALightIndex then
      Exit(fShadowMaps[I].Strength);
end;

function TRenderer.FindFirstLightObject(aObject: TSceneObject): TSceneObject;
var
  i: Integer;
  Light: TLight;
begin
  Result := nil;
  if aObject = nil then
    Exit;

  for i := 0 to aObject.LightsCount - 1 do
  begin
    Light := aObject.Light[i];
    if Assigned(Light) and Light.Enabled then
      Exit(aObject);
  end;

  for i := 0 to aObject.Count - 1 do
  begin
    Result := FindFirstLightObject(aObject.ObjectList[i]);
    if Result <> nil then
      Exit;
  end;
end;

function TRenderer.TryGetMainLightHeight(out AHeight: Single): Boolean;
var
  LightObj: TSceneObject;
  Light: TLight;
begin
  Result := False;
  AHeight := 0.0;

  LightObj := fShadowLight;
  if (LightObj = nil) or (LightObj.LightsCount <= 0) then
  begin
    if (fSceneManager <> nil) and (fSceneManager.Root <> nil) then
      LightObj := FindFirstLightObject(fSceneManager.Root)
    else
      LightObj := nil;
  end;

  if (LightObj = nil) or (LightObj.LightsCount <= 0) then
    Exit;

  Light := LightObj.Light[0];
  if Light = nil then
    Exit;

  AHeight := Light.Position.Y;
  Result := True;
end;

function TRenderer.EffectiveFogColor: TVector4;
var
  LightHeight: Single;
  DayAmount: Single;
  T: Single;
  NightFog: TVector4;

  function SmoothStep(Edge0, Edge1, Value: Single): Single;
  var
    LocalT: Single;
  begin
    if SameValue(Edge0, Edge1) then
    begin
      if Value >= Edge1 then
        Exit(1.0);
      Exit(0.0);
    end;

    LocalT := EnsureRange((Value - Edge0) / (Edge1 - Edge0), 0.0, 1.0);
    Result := LocalT * LocalT * (3.0 - 2.0 * LocalT);
  end;

begin
  Result := fFogColor;

  if not TryGetMainLightHeight(LightHeight) then
    Exit;

  DayAmount := SmoothStep(0.0, 6.0, LightHeight);
  if DayAmount >= 0.999 then
    Exit;

  if fSkyDome <> nil then
    NightFog := fSkyDome.NightColor
  else
    NightFog := Vector4(0.014, 0.020, 0.052, fFogColor.A);

  // Keep night fog blue-black instead of pure black, but remove the daytime glow.
  NightFog := Vector4(
    Max(0.010, NightFog.R * 1.35),
    Max(0.014, NightFog.G * 1.35),
    Max(0.036, NightFog.B * 1.18),
    fFogColor.A);

  T := DayAmount;
  Result := Vector4(
    NightFog.R + (fFogColor.R - NightFog.R) * T,
    NightFog.G + (fFogColor.G - NightFog.G) * T,
    NightFog.B + (fFogColor.B - NightFog.B) * T,
    fFogColor.A);
end;

function TRenderer.TryGetGodRayLightScreenPosition(
  out AScreenPosition: TVector2): Boolean;
var
  LightObject: TSceneObject;
  Light: TLight;
  WorldPosition, Direction: TVector3;
  Clip: TVector4;
  ViewProjection: TMatrix4;
  InvW: Single;
begin
  Result := False;
  AScreenPosition := Vector2(0.5, 0.5);

  if (fActiveCamera = nil) or (fActiveCamera.Camera = nil) then
    Exit;

  LightObject := fShadowLight;
  if ((LightObject = nil) or (LightObject.LightsCount <= 0)) and
     (fSceneManager <> nil) and (fSceneManager.Root <> nil) then
    LightObject := FindFirstLightObject(fSceneManager.Root);

  if (LightObject = nil) or (LightObject.LightsCount <= 0) then
    Exit;

  Light := LightObject.Light[0];
  if (Light = nil) or (not Light.Enabled) then
    Exit;

  if Light.LightType = ltDirectional then
  begin
    Direction := Light.Direction;
    if Direction.LengthSquared < 1e-8 then
      Direction := Vector3(-0.35, -1.0, -0.35)
    else
      Direction.Normalize;

    WorldPosition := fActiveCamera.Camera.Position - Direction * 1000.0;
  end
  else
    WorldPosition := Light.Position;

  ViewProjection := fProjectionMatrix * fActiveCamera.Camera.ViewMatrix;
  Clip := ViewProjection * Vector4(WorldPosition, 1.0);
  if Abs(Clip.W) < 1e-6 then
    Exit;

  InvW := 1.0 / Clip.W;
  AScreenPosition := Vector2(
    Clip.X * InvW * 0.5 + 0.5,
    Clip.Y * InvW * 0.5 + 0.5);
  Result := True;
end;

procedure TRenderer.RenderPostProcess;
var
  OldDepthTestEnabled, OldBlendEnabled, OldCullEnabled: GLboolean;
  OldDepthMask: GLboolean;
  LightPosition: TVector2;
  HasGodRayLight: Boolean;
  Samples: Integer;
begin
  if not GetPostProcessActive then
    Exit;
  if (fPostProcessColorTexture = 0) or (fPostProcessFBO = 0) then
    Exit;

  SetupFullscreenQuad;
  if fFullscreenVAO = 0 then
    Exit;

  OldDepthTestEnabled := glIsEnabled(GL_DEPTH_TEST);
  OldBlendEnabled := glIsEnabled(GL_BLEND);
  OldCullEnabled := glIsEnabled(GL_CULL_FACE);
  glGetBooleanv(GL_DEPTH_WRITEMASK, @OldDepthMask);

  glBindFramebuffer(GL_FRAMEBUFFER, PresentFramebuffer);
  ApplyPresentViewport;
  FlushGLColor;
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);

  glDisable(GL_DEPTH_TEST);
  glDepthMask(GL_FALSE);
  glDisable(GL_BLEND);
  glDisable(GL_CULL_FACE);

  fPostProcessShader.Use;
  fPostProcessShader.SetTexture('sceneTexture', 0, GL_TEXTURE_2D,
    fPostProcessColorTexture);
  fPostProcessShader.SetUniform('toneMappingMode', GLint(Ord(fToneMappingMode)));
  fPostProcessShader.SetUniform('exposure', GLfloat(Max(0.0, fToneExposure)));
  fPostProcessShader.SetUniform('outputGamma', GLfloat(Max(0.0001, fToneGamma)));
  fPostProcessShader.SetUniform('viewportSize',
    Vector2(fViewport.Width, fViewport.Height));

  HasGodRayLight := fGodRaysEnabled and TryGetGodRayLightScreenPosition(LightPosition);
  if not HasGodRayLight then
    LightPosition := Vector2(0.5, 0.5);

  Samples := System.Math.EnsureRange(fGodRaySamples, 1, 128);
  fPostProcessShader.SetUniform('godRaysEnabled', GLint(Ord(HasGodRayLight)));
  fPostProcessShader.SetUniform('godRayLightPosition', LightPosition);
  fPostProcessShader.SetUniform('godRaySamples', GLint(Samples));
  fPostProcessShader.SetUniform('godRayDensity',
    GLfloat(Max(0.0, fGodRayDensity)));
  fPostProcessShader.SetUniform('godRayExposure',
    GLfloat(Max(0.0, fGodRayExposure)));
  fPostProcessShader.SetUniform('godRayDecay',
    GLfloat(System.Math.EnsureRange(fGodRayDecay, 0.0, 1.0)));
  fPostProcessShader.SetUniform('godRayWeight',
    GLfloat(Max(0.0, fGodRayWeight)));
  fPostProcessShader.SetUniform('godRayIntensity',
    GLfloat(Max(0.0, fGodRayIntensity)));

  glBindVertexArray(fFullscreenVAO);
  try
    glDrawArrays(GL_TRIANGLES, 0, 6);
  finally
    glBindVertexArray(0);
    glUseProgram(0);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, 0);
    glDepthMask(OldDepthMask);
    if OldDepthTestEnabled = GL_TRUE then
      glEnable(GL_DEPTH_TEST)
    else
      glDisable(GL_DEPTH_TEST);
    if OldBlendEnabled = GL_TRUE then
      glEnable(GL_BLEND)
    else
      glDisable(GL_BLEND);
    if OldCullEnabled = GL_TRUE then
      glEnable(GL_CULL_FACE)
    else
      glDisable(GL_CULL_FACE);
  end;
end;

procedure TRenderer.ApplyShadowMaterial(AMesh: TMesh);
const
  LEAF_ALPHA_TEXTURE_UNIT = 9;
var
  Mat: TMaterial;
  Tex: TMaterialTexture;
  I: Integer;
begin
  if fShadowShader = nil then
    Exit;

  fShadowShader.SetUniform('useAlphaCutout', GLint(0));
  if (AMesh = nil) or (AMesh.MaterialLibrary = nil) then
    Exit;

  if Trim(AMesh.LibMaterialname) <> '' then
    Mat := AMesh.MaterialLibrary.GetMaterial(AMesh.LibMaterialname)
  else if AMesh.MaterialLibrary.Count > 0 then
    Mat := AMesh.MaterialLibrary.Material[0]
  else
    Mat := nil;

  if (Mat = nil) or (Mat.Materialtype <> mtTreeLeaf) then
    Exit;

  for I := 0 to Mat.Count - 1 do
  begin
    Tex := Mat.TextureList[I];
    if SameText(Trim(Tex.Texture.Name), 'albedoTexture') and
       (Tex.Texture.TexID <> 0) then
    begin
      glActiveTexture(GL_TEXTURE0 + LEAF_ALPHA_TEXTURE_UNIT);
      glBindTexture(GL_TEXTURE_2D, Tex.Texture.TexID);
      fShadowShader.SetUniform('leafAlphaTexture',
        GLint(LEAF_ALPHA_TEXTURE_UNIT));
      fShadowShader.SetUniform('alphaCutoff',
        GLfloat(Mat.ShaderParameters.AlphaCutoff));
      fShadowShader.SetUniform('useAlphaCutout', GLint(1));
      Exit;
    end;
  end;
end;

procedure TRenderer.RenderSceneObjectDepth(aObject: TSceneObject);
var
  i: Integer;
  Mesh: TMesh;
  Meshes: TMeshList;
  WorldBounds: TAABB;
begin
  if (aObject = nil) or aObject.IsGizmo then
    Exit;

  Meshes := aObject.EffectiveMeshList;
  if Assigned(Meshes) then
  for i := 0 to Meshes.Count - 1 do
  begin
    Mesh := Meshes.Item[i];
    if Assigned(Mesh) and Mesh.Visible then
    begin
      Mesh.ParentModelMatrix := aObject.WorldMatrix;
      WorldBounds := Mesh.GetBoundingBox.Transform(Mesh.ModelMatrix);
      if not MeshCastsShadowByDefault(Mesh, WorldBounds) then
        Continue;

      if (Mesh is THeightFieldMesh) and Assigned(fActiveCamera) and
         Assigned(fActiveCamera.Camera) then
        THeightFieldMesh(Mesh).LODCameraPosition := fActiveCamera.Camera.Position;

      fCurrentSceneObject := aObject;
      try
        fShadowShader.SetUniform('modelMatrix', Mesh.ModelMatrix);
        Mesh.PrepareShader(fShadowShader);
        aObject.ApplyVertexWindUniforms(fShadowShader);
        ApplyShadowMaterial(Mesh);
        Mesh.DrawGeometryOnlyCulled(fShadowFrustumPlanes,
          fFrustumCullingEnabled and fShadowFrustumValid and
          (not aObject.HasVertexWindAnimation));
        Inc(fShadowDrawCount);
      finally
        fCurrentSceneObject := nil;
      end;
    end;
  end;

  for i := 0 to aObject.Count - 1 do
    RenderSceneObjectDepth(aObject.ObjectList[i]);
end;

procedure TRenderer.RenderShadowPass;
var
  I, Layer: Integer;
  Lights: TArray<TLight>;
  Light: TLight;
  PrimaryLight: TLight;
  ShaderLightCount: Integer;
  OldDepthFunc: GLint;
  OldDepthMask: GLboolean;
  OldBlendEnabled: GLboolean;
  OldCullEnabled: GLboolean;
  OldCullFaceMode: GLint;
  OldPolygonOffsetEnabled: GLboolean;
  OldPolygonOffsetFactor: GLfloat;
  OldPolygonOffsetUnits: GLfloat;
begin
  fShadowDrawCount := 0;
  fShadowMapCount := 0;
  fShadowLightViewProjection := TMatrix4.Identity;

  if (not fShadowEnabled) or (fShadowFBO = 0) or (fShadowShader = nil) or
     (fSceneManager = nil) then
    Exit;

  Lights := fSceneManager.GetLights;
  ShaderLightCount := Min(Length(Lights), MAX_RENDERER_SHADER_LIGHTS);

  PrimaryLight := nil;
  if Assigned(fShadowLight) and (fShadowLight.LightsCount > 0) then
    PrimaryLight := fShadowLight.Light[0];

  if Assigned(PrimaryLight) then
    for I := 0 to ShaderLightCount - 1 do
      if Lights[I] = PrimaryLight then
      begin
        AddShadowMapLight(Lights[I], I);
        Break;
      end;

  for I := 0 to ShaderLightCount - 1 do
    AddShadowMapLight(Lights[I], I);

  if fShadowMapCount <= 0 then
    Exit;

  glGetIntegerv(GL_DEPTH_FUNC, @OldDepthFunc);
  glGetBooleanv(GL_DEPTH_WRITEMASK, @OldDepthMask);
  OldBlendEnabled := glIsEnabled(GL_BLEND);
  OldCullEnabled := glIsEnabled(GL_CULL_FACE);
  glGetIntegerv(GL_CULL_FACE_MODE, @OldCullFaceMode);
  OldPolygonOffsetEnabled := glIsEnabled(GL_POLYGON_OFFSET_FILL);
  glGetFloatv(GL_POLYGON_OFFSET_FACTOR, @OldPolygonOffsetFactor);
  glGetFloatv(GL_POLYGON_OFFSET_UNITS, @OldPolygonOffsetUnits);

  glViewport(0, 0, fShadowMapSize, fShadowMapSize);
  glBindFramebuffer(GL_FRAMEBUFFER, fShadowFBO);
  glEnable(GL_DEPTH_TEST);
  glDepthFunc(GL_LESS);
  glDepthMask(GL_TRUE);
  glDisable(GL_BLEND);
  glDisable(GL_CULL_FACE);
  glEnable(GL_POLYGON_OFFSET_FILL);
  glPolygonOffset(1.2, 4.0);

  fShadowShader.Use;

  for Layer := 0 to fShadowMapCount - 1 do
  begin
    Light := fShadowMaps[Layer].Light;
    fShadowMaps[Layer].Matrix := CalculateShadowLightMatrix(Light);
    fShadowMaps[Layer].Strength := Light.ShadowStrength;
    fShadowLightViewProjection := fShadowMaps[Layer].Matrix;

    fShadowFrustumValid := False;
    if fFrustumCullingEnabled then
      BuildShadowFrustum;

    glFramebufferTextureLayer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,
      fShadowDepthTexture, 0, Layer);
    glClear(GL_DEPTH_BUFFER_BIT);

    fShadowShader.SetUniform('lightSpaceMatrix', fShadowMaps[Layer].Matrix);

    for I := 0 to fSceneManager.Count - 1 do
      RenderSceneObjectDepth(fSceneManager.Root.ObjectList[I]);
  end;

  fShadowLightViewProjection := fShadowMaps[0].Matrix;

  glBindFramebuffer(GL_FRAMEBUFFER, 0);
  glDepthFunc(OldDepthFunc);
  glDepthMask(OldDepthMask);
  glPolygonOffset(OldPolygonOffsetFactor, OldPolygonOffsetUnits);
  if OldPolygonOffsetEnabled = GL_TRUE then
    glEnable(GL_POLYGON_OFFSET_FILL)
  else
    glDisable(GL_POLYGON_OFFSET_FILL);
  if OldBlendEnabled = GL_TRUE then
    glEnable(GL_BLEND)
  else
    glDisable(GL_BLEND);
  glCullFace(OldCullFaceMode);
  if OldCullEnabled = GL_TRUE then
    glEnable(GL_CULL_FACE)
  else
    glDisable(GL_CULL_FACE);
  glViewport(fViewport.X, fViewport.Y, fViewport.Width, fViewport.Height);
end;

function TRenderer.BuildFrustumFromViewProjection(
  const AViewProjection: TMatrix4; out APlanes: TFrustumPlanes): Boolean;
var
  InverseViewProjection: TMatrix4;
  Corners: array[0..7] of TVector3;
  FrustumCenter: TVector3;

  function CrossProduct(const A, B: TVector3): TVector3;
  begin
    Result := Vector3(
      A.Y * B.Z - A.Z * B.Y,
      A.Z * B.X - A.X * B.Z,
      A.X * B.Y - A.Y * B.X
    );
  end;

  function UnprojectNDC(AX, AY, AZ: Single): TVector3;
  var
    Clip, World: TVector4;
  begin
    Clip := Vector4(AX, AY, AZ, 1.0);
    World := InverseViewProjection * Clip;
    if Abs(World.W) > 1e-6 then
      World := World / World.W;
    Result := Vector3(World.X, World.Y, World.Z);
  end;

  procedure SetPlane(AIndex: Integer; const A, B, C: TVector3);
  var
    Normal: TVector3;
    D, Len: Single;
  begin
    Normal := CrossProduct(B - A, C - A);
    Len := Normal.Length;
    if Len > 1e-6 then
      Normal := Normal / Len
    else
      Normal := Vector3(0.0, 1.0, 0.0);

    D := -Normal.Dot(A);

    if Normal.Dot(FrustumCenter) + D < 0.0 then
    begin
      Normal := -Normal;
      D := -D;
    end;

    APlanes[AIndex] := Vector4(Normal.X, Normal.Y, Normal.Z, D);
  end;
begin
  InverseViewProjection := AViewProjection.Inverse;

  Corners[0] := UnprojectNDC(-1.0, -1.0, -1.0);
  Corners[1] := UnprojectNDC( 1.0, -1.0, -1.0);
  Corners[2] := UnprojectNDC( 1.0,  1.0, -1.0);
  Corners[3] := UnprojectNDC(-1.0,  1.0, -1.0);
  Corners[4] := UnprojectNDC(-1.0, -1.0,  1.0);
  Corners[5] := UnprojectNDC( 1.0, -1.0,  1.0);
  Corners[6] := UnprojectNDC( 1.0,  1.0,  1.0);
  Corners[7] := UnprojectNDC(-1.0,  1.0,  1.0);

  FrustumCenter := Vector3(0.0, 0.0, 0.0);
  for var i := Low(Corners) to High(Corners) do
    FrustumCenter := FrustumCenter + Corners[i];
  FrustumCenter := FrustumCenter / Length(Corners);

  SetPlane(0, Corners[0], Corners[3], Corners[7]); // left
  SetPlane(1, Corners[1], Corners[5], Corners[6]); // right
  SetPlane(2, Corners[0], Corners[4], Corners[5]); // bottom
  SetPlane(3, Corners[3], Corners[2], Corners[6]); // top
  SetPlane(4, Corners[0], Corners[1], Corners[2]); // near
  SetPlane(5, Corners[4], Corners[7], Corners[6]); // far

  Result := True;
end;

function TRenderer.BuildViewFrustum: Boolean;
var
  Forward: TVector3;
begin
  fViewFrustumValid := False;

  if (fActiveCamera = nil) or (fActiveCamera.Camera = nil) then
    Exit(False);

  fViewFrustumValid := BuildFrustumFromViewProjection(
    fProjectionMatrix * fActiveCamera.Camera.ViewMatrix, fViewFrustumPlanes);

  if fViewFrustumValid then
  begin
    Forward := fActiveCamera.Camera.Front;
    if Forward.LengthSquared > 1e-8 then
    begin
      Forward.Normalize;
      fViewFrustumPlanes[4] := Vector4(Forward.X, Forward.Y, Forward.Z,
        -Forward.Dot(fActiveCamera.Camera.Position));
    end;
  end;

  Result := fViewFrustumValid;
end;

function TRenderer.BuildShadowFrustum: Boolean;
begin
  fShadowFrustumValid := False;

  fShadowFrustumValid := BuildFrustumFromViewProjection(
    fShadowLightViewProjection, fShadowFrustumPlanes);
  Result := fShadowFrustumValid;
end;

function TRenderer.IsSphereVisibleInViewFrustum(const ACenter: TVector3;
  ARadius: Single): Boolean;
var
  i: Integer;
  Plane: TVector4;
  Distance: Single;
begin
  if (not fFrustumCullingEnabled) or (not fViewFrustumValid) then
    Exit(True);

  ARadius := System.Math.Max(0.0, ARadius);

  for i := Low(fViewFrustumPlanes) to High(fViewFrustumPlanes) do
  begin
    Plane := fViewFrustumPlanes[i];
    Distance := Plane.X * ACenter.X + Plane.Y * ACenter.Y +
      Plane.Z * ACenter.Z + Plane.W;
    if Distance < -ARadius then
      Exit(False);
  end;

  Result := True;
end;

function TRenderer.IsSceneObjectGeometryVisible(aObject: TSceneObject): Boolean;
var
  Center, AxisX, AxisY, AxisZ: TVector3;
  Radius, LocalMaxScale, WorldMaxScale: Single;
begin
  if (aObject = nil) or (not fFrustumCullingEnabled) or
     (not fViewFrustumValid) then
    Exit(True);

  Radius := aObject.BoundingRadius;
  if Radius <= 0.0 then
    Exit(True);

  AxisX := Vector3(aObject.WorldMatrix.Columns[0]);
  AxisY := Vector3(aObject.WorldMatrix.Columns[1]);
  AxisZ := Vector3(aObject.WorldMatrix.Columns[2]);
  WorldMaxScale := System.Math.Max(AxisX.Length,
    System.Math.Max(AxisY.Length, AxisZ.Length));
  LocalMaxScale := System.Math.Max(Abs(aObject.Scale.X),
    System.Math.Max(Abs(aObject.Scale.Y), Abs(aObject.Scale.Z)));

  if LocalMaxScale > 1e-6 then
    Radius := Radius * (WorldMaxScale / LocalMaxScale);

  Center := Vector3(aObject.WorldMatrix.Columns[3]);
  Result := IsSphereVisibleInViewFrustum(Center, Radius);
end;

function TRenderer.CountMeshTriangles(AMesh: TMesh): Int64;
begin
  Result := 0;
  if AMesh = nil then
    Exit;
  if not AMesh.Visible then
    Exit;

  if AMesh.IndexCount > 0 then
    Result := AMesh.IndexCount div 3
  else
    Result := AMesh.VertexCount div 3;
end;

function TRenderer.CountSceneObjectTriangles(aObject: TSceneObject): Int64;
var
  I: Integer;
  Meshes: TMeshList;
begin
  Result := 0;
  if aObject = nil then
    Exit;
  if aObject.IsGizmo then
    Exit;

  Meshes := aObject.EffectiveMeshList;
  if Assigned(Meshes) then
    for I := 0 to Meshes.Count - 1 do
      Result := Result + CountMeshTriangles(Meshes.Item[I]);

  for I := 0 to aObject.Count - 1 do
    Result := Result + CountSceneObjectTriangles(aObject.ObjectList[I]);
end;

procedure TRenderer.UpdateTriangleCount;
begin
  fTriangleCount := 0;
  if fSceneManager = nil then
    Exit;
  if fSceneManager.Root = nil then
    Exit;

  fTriangleCount := CountSceneObjectTriangles(fSceneManager.Root);
end;

function TRenderer.FindFirstWaterMesh(aObject: TSceneObject;
  out AWaterMesh: TWaterPlaneMesh): Boolean;
var
  I: Integer;
  Mesh: TMesh;
  Meshes: TMeshList;
begin
  Result := False;
  AWaterMesh := nil;

  if aObject = nil then
    Exit;
  if aObject.IsGizmo then
    Exit;

  Meshes := aObject.EffectiveMeshList;
  if Assigned(Meshes) then
  for I := 0 to Meshes.Count - 1 do
  begin
    Mesh := Meshes.Item[I];
    if Mesh = nil then
      Continue;
    if not (Mesh is TWaterPlaneMesh) then
      Continue;
    if Mesh.Visible then
    begin
      Mesh.ParentModelMatrix := aObject.WorldMatrix;
      AWaterMesh := TWaterPlaneMesh(Mesh);
      Exit(True);
    end;
  end;

  for I := 0 to aObject.Count - 1 do
    if FindFirstWaterMesh(aObject.ObjectList[I], AWaterMesh) then
      Exit(True);
end;

procedure TRenderer.RenderWaterReflectionPass(DeltaTime: Single);
var
  I: Integer;
  WaterMesh: TWaterPlaneMesh;
  WaterY: Single;
  WaterNormal: TVector3;
  OldActiveCamera: TSceneObject;
  MainCamera: TCamera;
  ReflectedPosition, ReflectedTarget, ReflectedUp: TVector3;
  OldFramebuffer: GLint;
  OldViewport: array[0..3] of GLint;
  OldDepthTestEnabled, OldBlendEnabled, OldCullEnabled: GLboolean;
  OldClipDistance0Enabled: GLboolean;
  OldCullFaceMode: GLint;
  OldSceneClipPlaneEnabled: Boolean;
  OldSceneClipPlane: TVector4;
begin
  if not fWaterReflectionEnabled then
    Exit;
  if fWaterShader = nil then
    Exit;
  if fSceneManager = nil then
    Exit;
  if fActiveCamera = nil then
    Exit;
  if fActiveCamera.Camera = nil then
    Exit;

  WaterMesh := nil;
  for I := 0 to fSceneManager.Count - 1 do
    if FindFirstWaterMesh(fSceneManager.Root.ObjectList[I], WaterMesh) then
      Break;

  if WaterMesh = nil then
    Exit;

  WaterNormal := Vector3(WaterMesh.ModelMatrix.Columns[1]);
  if WaterNormal.LengthSquared > 1e-8 then
    WaterNormal.Normalize
  else
    WaterNormal := Vector3(0, 1, 0);

  // Reflection currently mirrors around a horizontal XZ water plane.
  if Abs(WaterNormal.Y) < 0.999 then
    Exit;

  EnsureWaterReflectionResources;
  if fWaterReflectionFBO = 0 then
    Exit;
  if fWaterReflectionTexture = 0 then
    Exit;
  if fWaterReflectionCameraObject = nil then
    Exit;
  if fWaterReflectionCameraObject.Camera = nil then
    Exit;

  WaterY := WaterMesh.ModelMatrix.Columns[3].Y;
  MainCamera := fActiveCamera.Camera;

  ReflectedPosition := MainCamera.Position;
  ReflectedPosition.Y := (2.0 * WaterY) - ReflectedPosition.Y;
  ReflectedTarget := MainCamera.Target;
  ReflectedTarget.Y := (2.0 * WaterY) - ReflectedTarget.Y;
  ReflectedUp := MainCamera.Up;
  ReflectedUp.Y := -ReflectedUp.Y;
  if ReflectedUp.LengthSquared < 1e-8 then
    ReflectedUp := Vector3(0, 1, 0);

  fWaterReflectionCameraObject.Camera.LookAt(ReflectedPosition,
    ReflectedTarget, ReflectedUp);

  glGetIntegerv(GL_FRAMEBUFFER_BINDING, @OldFramebuffer);
  glGetIntegerv(GL_VIEWPORT, @OldViewport[0]);
  OldDepthTestEnabled := glIsEnabled(GL_DEPTH_TEST);
  OldBlendEnabled := glIsEnabled(GL_BLEND);
  OldCullEnabled := glIsEnabled(GL_CULL_FACE);
  OldClipDistance0Enabled := glIsEnabled(GL_CLIP_DISTANCE0);
  glGetIntegerv(GL_CULL_FACE_MODE, @OldCullFaceMode);

  OldActiveCamera := fActiveCamera;
  OldSceneClipPlaneEnabled := fSceneClipPlaneEnabled;
  OldSceneClipPlane := fSceneClipPlane;
  fActiveCamera := fWaterReflectionCameraObject;
  fRenderingWaterReflection := True;
  try
    fViewFrustumValid := False;
    if fFrustumCullingEnabled then
      BuildViewFrustum;

    glBindFramebuffer(GL_FRAMEBUFFER, fWaterReflectionFBO);
    glViewport(0, 0, fWaterReflectionWidth, fWaterReflectionHeight);
    glEnable(GL_DEPTH_TEST);
    glDisable(GL_BLEND);
    glDisable(GL_CULL_FACE);
    FlushGLColor;
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);

    if fSkyDome <> nil then
      fSkyDome.Render(fProjectionMatrix * fActiveCamera.Camera.ViewMatrix,
        fActiveCamera.Camera.Position, DeltaTime);

    fSceneClipPlaneEnabled := True;
    fSceneClipPlane := Vector4(0.0, 1.0, 0.0, -WaterY - 0.05);
    glEnable(GL_CLIP_DISTANCE0);
    try
      for I := 0 to fSceneManager.Count - 1 do
        RenderSceneObject(fSceneManager.Root.ObjectList[I]);
    finally
      fSceneClipPlaneEnabled := OldSceneClipPlaneEnabled;
      fSceneClipPlane := OldSceneClipPlane;
      if OldClipDistance0Enabled = GL_TRUE then
        glEnable(GL_CLIP_DISTANCE0)
      else
        glDisable(GL_CLIP_DISTANCE0);
    end;

    RenderSceneBillboards;

    for I := 0 to fSceneManager.Count - 1 do
      RenderSceneObjectParticles(fSceneManager.Root.ObjectList[I]);
  finally
    fSceneClipPlaneEnabled := OldSceneClipPlaneEnabled;
    fSceneClipPlane := OldSceneClipPlane;
    fRenderingWaterReflection := False;
    fActiveCamera := OldActiveCamera;
    fViewFrustumValid := False;

    glBindFramebuffer(GL_FRAMEBUFFER, OldFramebuffer);
    glViewport(OldViewport[0], OldViewport[1], OldViewport[2], OldViewport[3]);
    glCullFace(OldCullFaceMode);
    if OldDepthTestEnabled = GL_TRUE then
      glEnable(GL_DEPTH_TEST)
    else
      glDisable(GL_DEPTH_TEST);
    if OldBlendEnabled = GL_TRUE then
      glEnable(GL_BLEND)
    else
      glDisable(GL_BLEND);
    if OldCullEnabled = GL_TRUE then
      glEnable(GL_CULL_FACE)
    else
      glDisable(GL_CULL_FACE);
    if OldClipDistance0Enabled = GL_TRUE then
      glEnable(GL_CLIP_DISTANCE0)
    else
      glDisable(GL_CLIP_DISTANCE0);
  end;
end;

procedure TRenderer.RenderWaterMesh(AWaterMesh: TWaterPlaneMesh);
var
  OldDepthTestEnabled, OldBlendEnabled, OldCullEnabled: GLboolean;
  OldDepthMask: GLboolean;
  OldCullFaceMode: GLint;
begin
  if AWaterMesh = nil then
    Exit;
  if not AWaterMesh.Visible then
    Exit;
  if fWaterShader = nil then
    Exit;
  if fWaterReflectionTexture = 0 then
    Exit;
  if fActiveCamera = nil then
    Exit;
  if fActiveCamera.Camera = nil then
    Exit;

  OldDepthTestEnabled := glIsEnabled(GL_DEPTH_TEST);
  OldBlendEnabled := glIsEnabled(GL_BLEND);
  OldCullEnabled := glIsEnabled(GL_CULL_FACE);
  glGetBooleanv(GL_DEPTH_WRITEMASK, @OldDepthMask);
  glGetIntegerv(GL_CULL_FACE_MODE, @OldCullFaceMode);

  glEnable(GL_DEPTH_TEST);
  glDepthMask(GL_FALSE);
  glEnable(GL_BLEND);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  glDisable(GL_CULL_FACE);

  fWaterShader.Use;
  fWaterShader.SetUniform('modelMatrix', AWaterMesh.ModelMatrix);
  fWaterShader.SetUniform('viewProjection',
    fProjectionMatrix * fActiveCamera.Camera.ViewMatrix);
  fWaterShader.SetUniform('eyePosition', fActiveCamera.Camera.Position);
  fWaterShader.SetUniform('waterColor', AWaterMesh.TintColor);
  fWaterShader.SetUniform('deepColor', AWaterMesh.DeepColor);
  fWaterShader.SetUniform('reflectionStrength',
    GLfloat(AWaterMesh.ReflectionStrength));
  fWaterShader.SetUniform('waveScale', GLfloat(AWaterMesh.WaveScale));
  fWaterShader.SetUniform('waveSpeed', GLfloat(AWaterMesh.WaveSpeed));
  fWaterShader.SetUniform('waveStrength', GLfloat(AWaterMesh.WaveStrength));
  fWaterShader.SetUniform('fresnelPower', GLfloat(AWaterMesh.FresnelPower));
  fWaterShader.SetUniform('alpha', GLfloat(AWaterMesh.Alpha));
  fWaterShader.SetUniform('time', GLfloat(fWaterTime));
  fWaterShader.SetUniform('useFog', GLint(Ord(fFogEnabled)));
  fWaterShader.SetUniform('fogColor', EffectiveFogColor);
  fWaterShader.SetUniform('fogDensity', GLfloat(fFogDensity));
  fWaterShader.SetUniform('fogStart', GLfloat(fFogStart));
  fWaterShader.SetUniform('fogEnd', GLfloat(fFogEnd));
  fWaterShader.SetUniform('reflectionTextureSize',
    Vector2(fWaterReflectionWidth, fWaterReflectionHeight));
  fWaterShader.SetUniform('reflectionViewport',
    Vector4(fViewport.X, fViewport.Y, fViewport.Width, fViewport.Height));
  fWaterShader.SetTexture('reflectionTexture', 0, GL_TEXTURE_2D,
    fWaterReflectionTexture);

  try
    AWaterMesh.DrawGeometryOnlyCulled(fViewFrustumPlanes,
      fFrustumCullingEnabled and fViewFrustumValid);
  finally
    glDepthMask(OldDepthMask);
    glCullFace(OldCullFaceMode);
    if OldDepthTestEnabled = GL_TRUE then
      glEnable(GL_DEPTH_TEST)
    else
      glDisable(GL_DEPTH_TEST);
    if OldBlendEnabled = GL_TRUE then
      glEnable(GL_BLEND)
    else
      glDisable(GL_BLEND);
    if OldCullEnabled = GL_TRUE then
      glEnable(GL_CULL_FACE)
    else
      glDisable(GL_CULL_FACE);
  end;
end;

procedure TRenderer.RenderSceneObjectWater(aObject: TSceneObject);
var
  I: Integer;
  Mesh: TMesh;
  Meshes: TMeshList;
begin
  if aObject = nil then
    Exit;
  if aObject.IsGizmo then
    Exit;

  Meshes := aObject.EffectiveMeshList;
  if Assigned(Meshes) then
  for I := 0 to Meshes.Count - 1 do
  begin
    Mesh := Meshes.Item[I];
    if Mesh is TWaterPlaneMesh then
    begin
      Mesh.ParentModelMatrix := aObject.WorldMatrix;
      RenderWaterMesh(TWaterPlaneMesh(Mesh));
    end;
  end;

  for I := 0 to aObject.Count - 1 do
    RenderSceneObjectWater(aObject.ObjectList[I]);
end;

procedure TRenderer.RenderWaterMeshes;
var
  I: Integer;
begin
  if not fWaterReflectionEnabled then
    Exit;
  if fWaterShader = nil then
    Exit;
  if fWaterReflectionTexture = 0 then
    Exit;
  if fSceneManager = nil then
    Exit;

  for I := 0 to fSceneManager.Count - 1 do
    RenderSceneObjectWater(fSceneManager.Root.ObjectList[I]);
end;

procedure TRenderer.RenderSceneObject(aObject: TSceneObject);
var
  i: Integer;
  HasObjectGeometry: Boolean;
  Mesh: TMesh;
  Meshes: TMeshList;
begin
  if aObject = nil then
    Exit;
  if fRenderingWaterReflection and aObject.IsGizmo then
    Exit;

  HasObjectGeometry := aObject.HasGeometry;

  if (not HasObjectGeometry) or IsSceneObjectGeometryVisible(aObject) then
  begin
    {if aObject.Mesh <> nil then
      aObject.Mesh.Draw;}
    Meshes := aObject.EffectiveMeshList;
    if Assigned(Meshes) then
    for i := 0 to Meshes.Count -1 do
      begin
        Mesh := Meshes.Item[i];
        if Mesh = nil then
          Continue;

        // Gizmo meshes are rendered later in MainUnit after clearing only depth.
        // Do not draw them during normal scene rendering, because TMesh.Draw
        // currently uses GL_ALWAYS for AlwaysOnTop meshes.
        if Mesh.AlwaysOnTop then
          Continue;

        if Mesh is TWaterPlaneMesh then
          Continue;

        if (Mesh is THeightFieldMesh) and Assigned(fActiveCamera) and
           Assigned(fActiveCamera.Camera) then
          THeightFieldMesh(Mesh).LODCameraPosition := fActiveCamera.Camera.Position;

        Mesh.ParentModelMatrix := aObject.WorldMatrix;
        fCurrentSceneObject := aObject;
        try
          Mesh.DrawCulled(fViewFrustumPlanes,
            fFrustumCullingEnabled and fViewFrustumValid and
            (not aObject.HasVertexWindAnimation));
        finally
          fCurrentSceneObject := nil;
        end;
      end;
  end;

  for i := 0 to aObject.Count - 1 do
    RenderSceneObject(aObject.ObjectList[i]);
end;

procedure TRenderer.RenderSceneObjectParticles(aObject: TSceneObject);
var
  I: Integer;
  P: Integer;
  ParticleSystem: TParticleSystem;
  ViewProjection: TMatrix4;
  ForwardVec, UpVec, RightVec: TVector3;
begin
  if (aObject = nil) or (fActiveCamera = nil) or
     (fActiveCamera.Camera = nil) then
    Exit;

  if aObject.ParticleSystemCount > 0 then
  begin
    ViewProjection := fProjectionMatrix * fActiveCamera.Camera.ViewMatrix;
    ForwardVec := fActiveCamera.Camera.Front.Normalize;
    UpVec := fActiveCamera.Camera.Up.Normalize;
    RightVec := ForwardVec.Cross(UpVec);
    if RightVec.LengthSquared < 1e-8 then
      RightVec := Vector3(1, 0, 0)
    else
    RightVec.Normalize;

    for P := 0 to aObject.ParticleSystemCount - 1 do
    begin
      ParticleSystem := aObject.ParticleSystemItem[P];
      if Assigned(ParticleSystem) then
        ParticleSystem.Render(ViewProjection, aObject.WorldMatrix,
          fActiveCamera.Camera.Position, RightVec, UpVec);
    end;
  end;

  for I := 0 to aObject.Count - 1 do
    RenderSceneObjectParticles(aObject.ObjectList[I]);
end;

procedure TRenderer.CollectSceneObjectBillboards(aObject: TSceneObject;
  var Items: TBillboardRenderList);
var
  I: Integer;
  B: Integer;
  S: Integer;
  Index: Integer;
  Billboard: TBillboard;
  AnimatedSprite: TAnimatedSprite;
  SpritePosition, Delta: TVector3;
begin
  if (aObject = nil) or (fActiveCamera = nil) or
     (fActiveCamera.Camera = nil) then
    Exit;

  for B := 0 to aObject.BillboardCount - 1 do
  begin
    Billboard := aObject.BillboardItem[B];
    if Assigned(Billboard) and Billboard.Enabled and
       (Billboard.Color.W > 0.001) then
    begin
      Index := Length(Items);
      SetLength(Items, Index + 1);
      Items[Index].SceneObject := aObject;
      Items[Index].Billboard := Billboard;
      Items[Index].AnimatedSprite := nil;
      SpritePosition := Vector3(aObject.WorldMatrix *
        Vector4(Billboard.Offset, 1.0));
      Delta := SpritePosition - fActiveCamera.Camera.Position;
      Items[Index].DistanceSq := Delta.LengthSquared;
    end;
  end;

  for S := 0 to aObject.AnimatedSpriteCount - 1 do
  begin
    AnimatedSprite := aObject.AnimatedSpriteItem[S];
    if Assigned(AnimatedSprite) and AnimatedSprite.Enabled and
       (AnimatedSprite.Color.W > 0.001) then
    begin
      Index := Length(Items);
      SetLength(Items, Index + 1);
      Items[Index].SceneObject := aObject;
      Items[Index].Billboard := nil;
      Items[Index].AnimatedSprite := AnimatedSprite;
      SpritePosition := Vector3(aObject.WorldMatrix *
        Vector4(AnimatedSprite.Offset, 1.0));
      Delta := SpritePosition - fActiveCamera.Camera.Position;
      Items[Index].DistanceSq := Delta.LengthSquared;
    end;
  end;

  for I := 0 to aObject.Count - 1 do
    CollectSceneObjectBillboards(aObject.ObjectList[I], Items);
end;

procedure TRenderer.SortBillboardRenderItems(var Items: TBillboardRenderList);
var
  I, J: Integer;
  Temp: TBillboardRenderItem;
begin
  for I := 0 to High(Items) - 1 do
    for J := I + 1 to High(Items) do
      if Items[J].DistanceSq > Items[I].DistanceSq then
      begin
        Temp := Items[I];
        Items[I] := Items[J];
        Items[J] := Temp;
      end;
end;

procedure TRenderer.RenderSceneBillboards;
var
  I: Integer;
  Items: TBillboardRenderList;
  ViewProjection: TMatrix4;
  ForwardVec, UpVec, RightVec: TVector3;
  Obj: TSceneObject;
  Billboard: TBillboard;
  AnimatedSprite: TAnimatedSprite;
  OverrideSize: Single;

  function IsLightGlyph(ABillboard: TBillboard): Boolean;
  var
    TexturePath: string;
  begin
    Result := False;
    if ABillboard = nil then
      Exit;

    TexturePath := StringReplace(ABillboard.TexturePath, '/', '\', [rfReplaceAll]);
    Result := SameText(ABillboard.Name, LIGHT_GLYPH_NAME) or
      SameText(TexturePath, LIGHT_GLYPH_TEXTURE_PATH);
  end;

  function LightGlyphWorldSize(AObject: TSceneObject; ABillboard: TBillboard): Single;
  var
    WorldPosition, Delta: TVector3;
    Dist: Single;
    ViewportHeight: Single;
  begin
    Result := 0.0;
    if (AObject = nil) or (ABillboard = nil) or
       (fActiveCamera = nil) or (fActiveCamera.Camera = nil) then
      Exit;

    WorldPosition := Vector3(AObject.WorldMatrix *
      Vector4(ABillboard.Offset, 1.0));
    Delta := WorldPosition - fActiveCamera.Camera.Position;
    Dist := Delta.Length;
    if Dist < 0.01 then
      Dist := 0.01;

    ViewportHeight := Max(1.0, Single(fViewport.Height));
    Result := (LIGHT_GLYPH_SCREEN_SIZE_PX * Dist * 2.0 *
      Tan(Abs(fFieldOfView) * 0.5)) / ViewportHeight;
    if Result < 0.001 then
      Result := 0.001;
  end;
begin
  if (fSceneManager = nil) or (fActiveCamera = nil) or
     (fActiveCamera.Camera = nil) then
    Exit;

  SetLength(Items, 0);
  for I := 0 to fSceneManager.Count - 1 do
    CollectSceneObjectBillboards(fSceneManager.Root.ObjectList[I], Items);

  if Length(Items) = 0 then
    Exit;

  SortBillboardRenderItems(Items);

  ViewProjection := fProjectionMatrix * fActiveCamera.Camera.ViewMatrix;
  ForwardVec := fActiveCamera.Camera.Front.Normalize;
  UpVec := fActiveCamera.Camera.Up.Normalize;
  RightVec := ForwardVec.Cross(UpVec);
  if RightVec.LengthSquared < 1e-8 then
    RightVec := Vector3(1, 0, 0)
  else
    RightVec.Normalize;

  for I := 0 to High(Items) do
  begin
    Obj := Items[I].SceneObject;
    Billboard := Items[I].Billboard;
    AnimatedSprite := Items[I].AnimatedSprite;
    if Assigned(Obj) and Assigned(Billboard) then
    begin
      OverrideSize := 0.0;
      if IsLightGlyph(Billboard) then
        OverrideSize := LightGlyphWorldSize(Obj, Billboard);

      if OverrideSize > 0.0 then
        Billboard.Render(ViewProjection, Obj.WorldMatrix, RightVec, UpVec,
          OverrideSize, OverrideSize)
      else
        Billboard.Render(ViewProjection, Obj.WorldMatrix, RightVec, UpVec);
    end;
    if Assigned(Obj) and Assigned(AnimatedSprite) then
      AnimatedSprite.Render(ViewProjection, Obj.WorldMatrix, RightVec, UpVec);
  end;
end;

procedure TRenderer.RenderEmptyObjectMarker(aObject: TSceneObject);
var
  i: Integer;
  Position: TVector3;
  Translation, Scale, ModelMatrix: TMatrix4;
begin
  if (aObject = nil) or aObject.IsGizmo then
    Exit;

  if (not aObject.HasGeometry) and (not aObject.HasParticles) and
     (not aObject.HasBillboard) and (not aObject.HasAnimatedSprite) then
  begin
    Position := Vector3(aObject.WorldMatrix.Columns[3]);
    Translation.InitTranslation(Position);
    Scale.InitScaling(Vector3(fEmptyObjectMarkerSize, fEmptyObjectMarkerSize,
      fEmptyObjectMarkerSize));
    ModelMatrix := Translation * Scale;

    fEmptyObjectMarkerShader.SetUniform('modelMatrix', ModelMatrix);
    glDrawArrays(GL_LINES, 0, fEmptyObjectMarkerVertexCount);
  end;

  for i := 0 to aObject.Count - 1 do
    RenderEmptyObjectMarker(aObject.ObjectList[i]);
end;

procedure TRenderer.RenderEmptyObjectMarkers;
var
  i: Integer;
  OldDepthTestEnabled, OldBlendEnabled: GLboolean;
  OldDepthMask: GLboolean;
  OldLineWidth: GLfloat;
begin
  if (not fEmptyObjectMarkersEnabled) or (fEmptyObjectMarkerShader = nil) or
     (fEmptyObjectMarkerVAO = 0) or (fEmptyObjectMarkerVertexCount = 0) or
     (fSceneManager = nil) or (fActiveCamera = nil) or (fActiveCamera.Camera = nil) then
    Exit;

  OldDepthTestEnabled := glIsEnabled(GL_DEPTH_TEST);
  OldBlendEnabled := glIsEnabled(GL_BLEND);
  glGetBooleanv(GL_DEPTH_WRITEMASK, @OldDepthMask);
  glGetFloatv(GL_LINE_WIDTH, @OldLineWidth);

  glDisable(GL_DEPTH_TEST);
  glDepthMask(GL_FALSE);
  glEnable(GL_BLEND);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  glLineWidth(1.5);

  fEmptyObjectMarkerShader.Use;
  fEmptyObjectMarkerShader.SetUniform('viewProjection',
    fProjectionMatrix * fActiveCamera.Camera.ViewMatrix);
  fEmptyObjectMarkerShader.SetUniform('markerColor', fEmptyObjectMarkerColor);

  glBindVertexArray(fEmptyObjectMarkerVAO);
  try
    for i := 0 to fSceneManager.Count -1 do
      RenderEmptyObjectMarker(fSceneManager.Root.ObjectList[i]);
  finally
    glBindVertexArray(0);
    glLineWidth(OldLineWidth);
    glDepthMask(OldDepthMask);
    if OldDepthTestEnabled = GL_TRUE then
      glEnable(GL_DEPTH_TEST)
    else
      glDisable(GL_DEPTH_TEST);
    if OldBlendEnabled = GL_TRUE then
      glEnable(GL_BLEND)
    else
      glDisable(GL_BLEND);
  end;
end;

procedure TRenderer.RenderSelectedBoundingBox;
var
  Vertices: array[0..23] of TVector3;
  BoundsMin, BoundsMax: TVector3;
  HasBounds: Boolean;
  OldDepthFunc: GLint;
  OldDepthTestEnabled, OldBlendEnabled: GLboolean;
  OldDepthMask: GLboolean;
  OldLineWidth: GLfloat;

  procedure IncludePoint(const APoint: TVector3);
  begin
    if not HasBounds then
    begin
      BoundsMin := APoint;
      BoundsMax := APoint;
      HasBounds := True;
      Exit;
    end;

    BoundsMin.X := System.Math.Min(BoundsMin.X, APoint.X);
    BoundsMin.Y := System.Math.Min(BoundsMin.Y, APoint.Y);
    BoundsMin.Z := System.Math.Min(BoundsMin.Z, APoint.Z);
    BoundsMax.X := System.Math.Max(BoundsMax.X, APoint.X);
    BoundsMax.Y := System.Math.Max(BoundsMax.Y, APoint.Y);
    BoundsMax.Z := System.Math.Max(BoundsMax.Z, APoint.Z);
  end;

  procedure IncludeMesh(AMesh: TMesh);
  var
    Min, Max: TVector3;
    Corners: array[0..7] of TVector3;
    I: Integer;
  begin
    if (AMesh = nil) or (not AMesh.Visible) then
      Exit;

    Min := AMesh.BoundingBoxMin;
    Max := AMesh.BoundingBoxMax;

    Corners[0] := Vector3(Min.X, Min.Y, Min.Z);
    Corners[1] := Vector3(Max.X, Min.Y, Min.Z);
    Corners[2] := Vector3(Max.X, Max.Y, Min.Z);
    Corners[3] := Vector3(Min.X, Max.Y, Min.Z);
    Corners[4] := Vector3(Min.X, Min.Y, Max.Z);
    Corners[5] := Vector3(Max.X, Min.Y, Max.Z);
    Corners[6] := Vector3(Max.X, Max.Y, Max.Z);
    Corners[7] := Vector3(Min.X, Max.Y, Max.Z);

    for I := Low(Corners) to High(Corners) do
      IncludePoint(Vector3(AMesh.ModelMatrix * Vector4(Corners[I], 1.0)));
  end;

  procedure IncludeObject(AObject: TSceneObject);
  var
    I: Integer;
    Meshes: TMeshList;
    Mesh: TMesh;
  begin
    if (AObject = nil) or AObject.IsGizmo then
      Exit;

    Meshes := AObject.EffectiveMeshList;
    if Assigned(Meshes) then
      for I := 0 to Meshes.Count - 1 do
      begin
        Mesh := Meshes.Item[I];
        if Assigned(Mesh) then
          Mesh.ParentModelMatrix := AObject.WorldMatrix;
        IncludeMesh(Mesh);
      end;

    for I := 0 to AObject.Count - 1 do
      IncludeObject(AObject.ObjectList[I]);
  end;

  procedure BuildLineVertices;
  begin
    Vertices[0] := Vector3(BoundsMin.X, BoundsMin.Y, BoundsMin.Z);
    Vertices[1] := Vector3(BoundsMax.X, BoundsMin.Y, BoundsMin.Z);
    Vertices[2] := Vector3(BoundsMax.X, BoundsMin.Y, BoundsMin.Z);
    Vertices[3] := Vector3(BoundsMax.X, BoundsMax.Y, BoundsMin.Z);
    Vertices[4] := Vector3(BoundsMax.X, BoundsMax.Y, BoundsMin.Z);
    Vertices[5] := Vector3(BoundsMin.X, BoundsMax.Y, BoundsMin.Z);
    Vertices[6] := Vector3(BoundsMin.X, BoundsMax.Y, BoundsMin.Z);
    Vertices[7] := Vector3(BoundsMin.X, BoundsMin.Y, BoundsMin.Z);

    Vertices[8] := Vector3(BoundsMin.X, BoundsMin.Y, BoundsMax.Z);
    Vertices[9] := Vector3(BoundsMax.X, BoundsMin.Y, BoundsMax.Z);
    Vertices[10] := Vector3(BoundsMax.X, BoundsMin.Y, BoundsMax.Z);
    Vertices[11] := Vector3(BoundsMax.X, BoundsMax.Y, BoundsMax.Z);
    Vertices[12] := Vector3(BoundsMax.X, BoundsMax.Y, BoundsMax.Z);
    Vertices[13] := Vector3(BoundsMin.X, BoundsMax.Y, BoundsMax.Z);
    Vertices[14] := Vector3(BoundsMin.X, BoundsMax.Y, BoundsMax.Z);
    Vertices[15] := Vector3(BoundsMin.X, BoundsMin.Y, BoundsMax.Z);

    Vertices[16] := Vector3(BoundsMin.X, BoundsMin.Y, BoundsMin.Z);
    Vertices[17] := Vector3(BoundsMin.X, BoundsMin.Y, BoundsMax.Z);
    Vertices[18] := Vector3(BoundsMax.X, BoundsMin.Y, BoundsMin.Z);
    Vertices[19] := Vector3(BoundsMax.X, BoundsMin.Y, BoundsMax.Z);
    Vertices[20] := Vector3(BoundsMax.X, BoundsMax.Y, BoundsMin.Z);
    Vertices[21] := Vector3(BoundsMax.X, BoundsMax.Y, BoundsMax.Z);
    Vertices[22] := Vector3(BoundsMin.X, BoundsMax.Y, BoundsMin.Z);
    Vertices[23] := Vector3(BoundsMin.X, BoundsMax.Y, BoundsMax.Z);
  end;
begin
  if (not fSelectedBoundingBoxEnabled) or (fSelectedBoundingBoxObject = nil) or
     (fEmptyObjectMarkerShader = nil) or (fActiveCamera = nil) or
     (fActiveCamera.Camera = nil) then
    Exit;

  SetupSelectedBoundingBoxGeometry;
  if (fSelectedBoundingBoxVAO = 0) or (fSelectedBoundingBoxVBO = 0) then
    Exit;

  HasBounds := False;
  IncludeObject(fSelectedBoundingBoxObject);
  if not HasBounds then
    Exit;

  BuildLineVertices;

  glGetIntegerv(GL_DEPTH_FUNC, @OldDepthFunc);
  OldDepthTestEnabled := glIsEnabled(GL_DEPTH_TEST);
  OldBlendEnabled := glIsEnabled(GL_BLEND);
  glGetBooleanv(GL_DEPTH_WRITEMASK, @OldDepthMask);
  glGetFloatv(GL_LINE_WIDTH, @OldLineWidth);

  glEnable(GL_DEPTH_TEST);
  glDepthFunc(GL_LEQUAL);
  glDepthMask(GL_FALSE);
  glEnable(GL_BLEND);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  glLineWidth(2.0);

  fEmptyObjectMarkerShader.Use;
  fEmptyObjectMarkerShader.SetUniform('viewProjection',
    fProjectionMatrix * fActiveCamera.Camera.ViewMatrix);
  fEmptyObjectMarkerShader.SetUniform('modelMatrix', TMatrix4.Identity);
  fEmptyObjectMarkerShader.SetUniform('markerColor', fSelectedBoundingBoxColor);

  glBindVertexArray(fSelectedBoundingBoxVAO);
  glBindBuffer(GL_ARRAY_BUFFER, fSelectedBoundingBoxVBO);
  glBufferSubData(GL_ARRAY_BUFFER, 0, SizeOf(Vertices), @Vertices[0]);
  try
    glDrawArrays(GL_LINES, 0, fSelectedBoundingBoxVertexCount);
  finally
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
    glLineWidth(OldLineWidth);
    glDepthFunc(OldDepthFunc);
    glDepthMask(OldDepthMask);
    if OldDepthTestEnabled = GL_TRUE then
      glEnable(GL_DEPTH_TEST)
    else
      glDisable(GL_DEPTH_TEST);
    if OldBlendEnabled = GL_TRUE then
      glEnable(GL_BLEND)
    else
      glDisable(GL_BLEND);
  end;
end;

procedure TRenderer.Render;
var
  i: Integer;
  NowTick: Int64;
  ParticleDeltaTime: Double;
begin
  ActivateContext;
  if Assigned(fOnBeforeRender) then
    fOnBeforeRender(Self);

  if (fSceneManager = nil) or
     //(fShader = nil) or
     (fActiveCamera = nil) then
  begin
    BeginFrame;
    if Assigned(fOnRender) then
      fOnRender(Self);
    RenderPostProcess;
    if Assigned(fOnAfterRender) then
      fOnAfterRender(Self);
    if (not fSuppressBeforePresent) and Assigned(fOnBeforePresent) then
      fOnBeforePresent(Self);
    EndFrame;
    UpdateFPS;
    Exit;
  end;

  QueryPerformanceCounter(NowTick);
  if fFPSCounter > 0 then
    ParticleDeltaTime := (NowTick - fLastParticleTime) / fFPSCounter
  else
    ParticleDeltaTime := 0.0;
  fLastParticleTime := NowTick;
  if ParticleDeltaTime > 0.25 then
    ParticleDeltaTime := 0.25;

  fSceneManager.UpdateParticles(Single(Max(0.0, ParticleDeltaTime)),
    NowTick / Max(1.0, fFPSCounter));
  fSceneManager.Update;
  fWaterTime := fWaterTime + Single(Max(0.0, ParticleDeltaTime));
  RenderShadowPass;

  RenderWaterReflectionPass(Single(Max(0.0, ParticleDeltaTime)));

  fViewFrustumValid := False;
  if fFrustumCullingEnabled then
    BuildViewFrustum;

  BeginFrame;
  if Assigned(fOnRender) then
    fOnRender(Self);

  if (fSkyDome <> nil) and Assigned(fActiveCamera.Camera) then
    fSkyDome.Render(fProjectionMatrix * fActiveCamera.Camera.ViewMatrix,
      fActiveCamera.Camera.Position, Single(Max(0.0, ParticleDeltaTime)));

  if Assigned(fOnBeforeSceneRender) then
    fOnBeforeSceneRender(Self);

  //fShader.Use;

  for i := 0 to fSceneManager.Count -1 do
    RenderSceneObject(fSceneManager.Root.ObjectList[i]);

  RenderSceneBillboards;

  for i := 0 to fSceneManager.Count -1 do
    RenderSceneObjectParticles(fSceneManager.Root.ObjectList[i]);

  RenderWaterMeshes;
  RenderEmptyObjectMarkers;
  RenderSelectedBoundingBox;
  RenderPostProcess;
  if Assigned(fOnAfterRender) then
    fOnAfterRender(Self);

  if (not fSuppressBeforePresent) and Assigned(fOnBeforePresent) then
    fOnBeforePresent(Self);

  EndFrame;
  UpdateFPS;
end;

function TRenderer.MaxRenderTextureAntialiasingSamples: Integer;
var
  MaxSamples: GLint;
begin
  Result := 1;
  try
    ActivateContext;
    if (not Assigned(glRenderbufferStorageMultisample)) or
       (not Assigned(glBlitFramebuffer)) then
      Exit;

    MaxSamples := 1;
    glGetIntegerv(GL_MAX_SAMPLES, @MaxSamples);
    if MaxSamples > 1 then
      Result := MaxSamples;
  except
    Result := 1;
  end;
end;

function TRenderer.RenderToTexture(AWidth, AHeight: Integer;
  out ATextureID: GLuint; out AError: string;
  AAntialiasingSamples: Integer): Boolean;
var
  MaxTextureSize: GLint;
  MaxSamples: Integer;
  RenderFBO: GLuint;
  ResolveFBO: GLuint;
  ColorRBO: GLuint;
  DepthRBO: GLuint;
  Status: GLenum;
  OldFramebuffer: GLint;
  OldGLViewport: array[0..3] of GLint;
  OldViewport: TViewport;
  OldProjection: TMatrix4;
  OldOverrideActive: Boolean;
  OldOverrideFBO: GLuint;
  OldOverrideViewport: TViewport;
  OldOverrideSamples: Integer;
  OldSuppressBeforePresent: Boolean;
  OldMultisampleEnabled: GLboolean;
  ActualSamples: Integer;
  UseMultisample: Boolean;
begin
  Result := False;
  ATextureID := 0;
  AError := '';
  RenderFBO := 0;
  ResolveFBO := 0;
  ColorRBO := 0;
  DepthRBO := 0;
  OldFramebuffer := 0;
  OldGLViewport[0] := 0;
  OldGLViewport[1] := 0;
  OldGLViewport[2] := Max(1, fViewport.Width);
  OldGLViewport[3] := Max(1, fViewport.Height);
  OldMultisampleEnabled := GL_FALSE;
  ActualSamples := 1;

  try
    ActivateContext;

    glGetIntegerv(GL_MAX_TEXTURE_SIZE, @MaxTextureSize);
    if MaxTextureSize <= 0 then
      MaxTextureSize := 16384;

    if (AWidth <= 0) or (AHeight <= 0) then
    begin
      AError := 'Render texture size must be greater than zero.';
      Exit;
    end;

    if (AWidth > MaxTextureSize) or (AHeight > MaxTextureSize) then
    begin
      AError := Format('Render texture size exceeds GL_MAX_TEXTURE_SIZE (%d).',
        [MaxTextureSize]);
      Exit;
    end;

    if AAntialiasingSamples > 1 then
    begin
      MaxSamples := MaxRenderTextureAntialiasingSamples;
      if MaxSamples < 2 then
      begin
        AError := 'Render texture anti aliasing is not supported by this OpenGL context.';
        Exit;
      end;
      ActualSamples := EnsureRange(AAntialiasingSamples, 2, MaxSamples);
    end;
    UseMultisample := ActualSamples > 1;

    glGetIntegerv(GL_FRAMEBUFFER_BINDING, @OldFramebuffer);
    glGetIntegerv(GL_VIEWPORT, @OldGLViewport[0]);
    OldMultisampleEnabled := glIsEnabled(GL_MULTISAMPLE);

    glGenTextures(1, @ATextureID);
    glBindTexture(GL_TEXTURE_2D, ATextureID);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, AWidth, AHeight, 0,
      GL_RGBA, GL_UNSIGNED_BYTE, nil);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    if UseMultisample then
    begin
      glGenFramebuffers(1, @ResolveFBO);
      glBindFramebuffer(GL_FRAMEBUFFER, ResolveFBO);
      glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
        GL_TEXTURE_2D, ATextureID, 0);

      Status := glCheckFramebufferStatus(GL_FRAMEBUFFER);
      if Status <> GL_FRAMEBUFFER_COMPLETE then
        raise Exception.CreateFmt('Render texture resolve framebuffer incomplete: %d',
          [Status]);

      glGenFramebuffers(1, @RenderFBO);
      glBindFramebuffer(GL_FRAMEBUFFER, RenderFBO);

      glGenRenderbuffers(1, @ColorRBO);
      glBindRenderbuffer(GL_RENDERBUFFER, ColorRBO);
      glRenderbufferStorageMultisample(GL_RENDERBUFFER, ActualSamples,
        GL_RGBA8, AWidth, AHeight);
      glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
        GL_RENDERBUFFER, ColorRBO);
    end
    else
    begin
      glGenFramebuffers(1, @RenderFBO);
      glBindFramebuffer(GL_FRAMEBUFFER, RenderFBO);
      glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
        GL_TEXTURE_2D, ATextureID, 0);
    end;

    glGenRenderbuffers(1, @DepthRBO);
    glBindRenderbuffer(GL_RENDERBUFFER, DepthRBO);
    if UseMultisample then
      glRenderbufferStorageMultisample(GL_RENDERBUFFER, ActualSamples,
        GL_DEPTH_COMPONENT24, AWidth, AHeight)
    else
      glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24,
        AWidth, AHeight);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,
      GL_RENDERBUFFER, DepthRBO);

    Status := glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if Status <> GL_FRAMEBUFFER_COMPLETE then
      raise Exception.CreateFmt('Render texture framebuffer incomplete: %d',
        [Status]);

    OldViewport := fViewport;
    OldProjection := fProjectionMatrix;
    OldOverrideActive := fRenderTargetOverrideActive;
    OldOverrideFBO := fRenderTargetOverrideFBO;
    OldOverrideViewport := fRenderTargetOverrideViewport;
    OldOverrideSamples := fRenderTargetOverrideSamples;
    OldSuppressBeforePresent := fSuppressBeforePresent;
    try
      fViewport.X := 0;
      fViewport.Y := 0;
      fViewport.Width := AWidth;
      fViewport.Height := AHeight;
      fProjectionMatrix.InitPerspectiveFovRH(-fFieldOfView,
        AWidth / Max(1.0, AHeight), fNearPlaneDistance, fFarPlaneDistance);

      fRenderTargetOverrideActive := True;
      fRenderTargetOverrideFBO := RenderFBO;
      fRenderTargetOverrideViewport.X := 0;
      fRenderTargetOverrideViewport.Y := 0;
      fRenderTargetOverrideViewport.Width := AWidth;
      fRenderTargetOverrideViewport.Height := AHeight;
      fRenderTargetOverrideSamples := ActualSamples;
      fSuppressBeforePresent := True;

      Render;
      if UseMultisample then
      begin
        glBindFramebuffer(GL_READ_FRAMEBUFFER, RenderFBO);
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, ResolveFBO);
        glBlitFramebuffer(0, 0, AWidth, AHeight, 0, 0, AWidth, AHeight,
          GL_COLOR_BUFFER_BIT, GL_NEAREST);
        glBindFramebuffer(GL_FRAMEBUFFER, ResolveFBO);
      end
      else
        glBindFramebuffer(GL_FRAMEBUFFER, RenderFBO);
      glFlush;
      Result := True;
    finally
      fViewport := OldViewport;
      fProjectionMatrix := OldProjection;
      fRenderTargetOverrideActive := OldOverrideActive;
      fRenderTargetOverrideFBO := OldOverrideFBO;
      fRenderTargetOverrideViewport := OldOverrideViewport;
      fRenderTargetOverrideSamples := OldOverrideSamples;
      fSuppressBeforePresent := OldSuppressBeforePresent;
    end;
  except
    on E: Exception do
    begin
      AError := E.Message;
      Result := False;
    end;
  end;

  glBindRenderbuffer(GL_RENDERBUFFER, 0);
  glBindTexture(GL_TEXTURE_2D, 0);
  glBindFramebuffer(GL_FRAMEBUFFER, OldFramebuffer);
  glViewport(OldGLViewport[0], OldGLViewport[1], OldGLViewport[2],
    OldGLViewport[3]);
  if OldMultisampleEnabled = GL_TRUE then
    glEnable(GL_MULTISAMPLE)
  else
    glDisable(GL_MULTISAMPLE);

  if ColorRBO <> 0 then
    glDeleteRenderbuffers(1, @ColorRBO);
  if DepthRBO <> 0 then
    glDeleteRenderbuffers(1, @DepthRBO);
  if ResolveFBO <> 0 then
    glDeleteFramebuffers(1, @ResolveFBO);
  if RenderFBO <> 0 then
    glDeleteFramebuffers(1, @RenderFBO);

  if (not Result) and (ATextureID <> 0) then
  begin
    glDeleteTextures(1, @ATextureID);
    ATextureID := 0;
  end;
end;

function TRenderer.SaveTextureToPNG(ATextureID: GLuint; AWidth,
  AHeight: Integer; const AFileName: string; out AError: string): Boolean;
var
  Pixels: TBytes;
  Png: TPngImage;
  RGBLine: pRGBLine;
  AlphaLine: pByteArray;
  X, Y: Integer;
  SourceY: Integer;
  SourceIndex: Integer;
  OldTexture: GLint;
  OldPackAlignment: GLint;
  OutputDir: string;
begin
  Result := False;
  AError := '';

  if ATextureID = 0 then
  begin
    AError := 'No render texture to save.';
    Exit;
  end;

  if (AWidth <= 0) or (AHeight <= 0) then
  begin
    AError := 'Invalid render texture size.';
    Exit;
  end;

  try
    ActivateContext;
    OutputDir := ExtractFilePath(AFileName);
    if OutputDir <> '' then
      ForceDirectories(OutputDir);

    SetLength(Pixels, AWidth * AHeight * 4);

    glGetIntegerv(GL_TEXTURE_BINDING_2D, @OldTexture);
    glGetIntegerv(GL_PACK_ALIGNMENT, @OldPackAlignment);
    try
      glPixelStorei(GL_PACK_ALIGNMENT, 1);
      glBindTexture(GL_TEXTURE_2D, ATextureID);
      glGetTexImage(GL_TEXTURE_2D, 0, GL_RGBA, GL_UNSIGNED_BYTE,
        @Pixels[0]);
    finally
      glPixelStorei(GL_PACK_ALIGNMENT, OldPackAlignment);
      glBindTexture(GL_TEXTURE_2D, OldTexture);
    end;

    Png := TPngImage.CreateBlank(COLOR_RGBALPHA, 8, AWidth, AHeight);
    try
      for Y := 0 to AHeight - 1 do
      begin
        SourceY := AHeight - 1 - Y;
        RGBLine := pRGBLine(Png.Scanline[Y]);
        AlphaLine := Png.AlphaScanline[Y];
        for X := 0 to AWidth - 1 do
        begin
          SourceIndex := (SourceY * AWidth + X) * 4;
          RGBLine^[X].rgbtRed := Pixels[SourceIndex + 0];
          RGBLine^[X].rgbtGreen := Pixels[SourceIndex + 1];
          RGBLine^[X].rgbtBlue := Pixels[SourceIndex + 2];
          if AlphaLine <> nil then
            AlphaLine^[X] := Pixels[SourceIndex + 3];
        end;
      end;
      Png.SaveToFile(AFileName);
    finally
      Png.Free;
    end;

    Result := True;
  except
    on E: Exception do
    begin
      AError := E.Message;
      Result := False;
    end;
  end;
end;

function TRenderer.RenderToTextureFile(AWidth, AHeight: Integer;
  const AFileName: string; out AError: string;
  AAntialiasingSamples: Integer): Boolean;
var
  TextureID: GLuint;
begin
  TextureID := 0;
  Result := RenderToTexture(AWidth, AHeight, TextureID, AError,
    AAntialiasingSamples);
  if Result then
    Result := SaveTextureToPNG(TextureID, AWidth, AHeight, AFileName, AError);

  if TextureID <> 0 then
    glDeleteTextures(1, @TextureID);
end;

procedure TRenderer.InitFOV(AFieldOfView, ANearPlaneDistance, AFarPlaneDistance: Single);
begin
  fFieldOfView := Abs(AFieldOfView);
  fNearPlaneDistance := Max(0.0001, ANearPlaneDistance);
  fFarPlaneDistance := Max(fNearPlaneDistance + 0.0001, AFarPlaneDistance);
  fProjectionMatrix.InitPerspectiveFovRH(-AFieldOfView,
    Max(1.0, fViewport.Width) / Max(1.0, fViewport.Height),
    fNearPlaneDistance, fFarPlaneDistance);
end;

procedure TRenderer.Resize(AWidth, AHeight: Integer);
begin
  fViewport.Width := Max(1, AWidth);
  fViewport.Height := Max(1, AHeight);
  InitFOV(fFieldOfView, fNearPlaneDistance, fFarPlaneDistance);
end;

end.
