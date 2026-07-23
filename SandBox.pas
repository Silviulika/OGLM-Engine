unit SandBox;

{-------------------------------------------------------------------------------
  SandBox_ImGuiEditorHost.pas

  Transitional Dear ImGui-only editor host.

  What this unit intentionally keeps:
    * TSandBoxForm = class(TForm) as the one native/VCL window.
    * Existing OpenGL renderer, scene manager, shader/material/mesh pipeline.
    * Dear ImGui panels for toolbar, scene tree, inspector, mesh list, log, cube editor.

  What this unit intentionally removes:
    * DFM dependency for SandBoxForm.
    * Hidden VCL controls used as editor state holders.
    * Extra editor forms such as mesh creator, material editor, particle editor, GUI editor.
    * VCL menus/toolbars/tree/list/edit panels.

  Sandbox intent:
    * This unit owns the editor/custom-editor layer.
    * MainUnit remains only as a tiny compatibility startup host.
    * Game-mode projects should use Engine.pas and avoid this unit entirely.
-------------------------------------------------------------------------------}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  System.Math, System.Types, System.IOUtils, System.DateUtils,
  System.Generics.Collections,
  Vcl.Controls, Vcl.Forms,
  Vcl.Graphics, Vcl.Imaging.pngimage, Vcl.Imaging.jpeg, GraphicEx,
  dglOpenGL, Neslib.FastMath, PasImGui, Editor.ImGuiBackend,
  PasImGui.Utils,
  Renderer.Mesh, Renderer.Particles, Renderer.Billboards, Renderer.AnimatedSprites,
  Renderer.Shader, Renderer.Light, Renderer.SkyDome,
  Engine.Types, Engine.Physics, Managers.Material, Renderer.Camera, Engine.Generators,
  Managers.Scene, Renderer.Renderer, Utility.Functions, Engine.Time,
  Renderer.Mesh.Factory, Renderer.Mesh.List, Engine.Paths, Engine.Audio,
  Engine.Animation, Engine.Wind, Engine.Scripting, Engine, Loader.GLTF;

type
  TPrimitiveKind = (
    pkCube,
    pkPlane,
    pkWaterPlane,
    pkSphere,
    pkCylinder,
    pkCapsule,
    pkTorus,
    pkCone,
    pkPrism,
    pkFrustum,
    pkIcosphere,
    pkGeodesicDome,
    pkArrow,
    pkSuperEllipsoid
  );

  { Editor-only infinite XZ-plane grid. It deliberately owns no scene data and
    is rendered through the sandbox's pre-scene render hook. }
  T3DGrid = class
  private
    fShader: TShader;
    fVAO: GLuint;
    fVBO: GLuint;
    fEnabled: Boolean;
    procedure CreateGeometry;
    procedure DestroyGeometry;
  public
    constructor Create(const AVertexFileName, AFragmentFileName: string);
    destructor Destroy; override;
    procedure Render(const AView, AProjection: TMatrix4;
      const ACameraPosition: TVector3);
    property Enabled: Boolean read fEnabled write fEnabled;
  end;

  TMeshImState = record
    Active: Boolean;
    CreatedObject: Boolean;
    CreatedMesh: Boolean;
    TargetObject: TSceneObject;
    Kind: TPrimitiveKind;
    PreviousObject: TSceneObject;
    PreviousMesh: TMesh;
    PreviousMeshIndex: Integer;
    MeshIndex: Integer;
    Name: array[0..127] of AnsiChar;
    Width: Single;
    Height: Single;
    Depth: Single;
    Radius: Single;
    TopRadius: Single;
    BottomRadius: Single;
    MajorRadius: Single;
    MinorRadius: Single;
    ShaftLength: Single;
    TipLength: Single;
    ShaftRadius: Single;
    TipRadius: Single;
    VCurve: Single;
    HCurve: Single;
    WidthSegments: Integer;
    HeightSegments: Integer;
    DepthSegments: Integer;
    Slices: Integer;
    Stacks: Integer;
    Sides: Integer;
    StackCount: Integer;
    SliceCount: Integer;
    MajorSegments: Integer;
    MinorSegments: Integer;
    Subdivisions: Integer;
    WaterTintColor: array[0..3] of Single;
    WaterDeepColor: array[0..3] of Single;
    WaterReflectionStrength: Single;
    WaterWaveScale: Single;
    WaterWaveSpeed: Single;
    WaterWaveStrength: Single;
    WaterFresnelPower: Single;
    WaterAlpha: Single;
    Position: array[0..2] of Single;
    RotationDeg: array[0..2] of Single;
    Scale: array[0..2] of Single;
    OriginalMesh: TMesh;
  end;

  THeightFieldMapInfo = record
    FileName: string;
    RelativePath: string;
    DisplayName: string;
    TextureID: GLuint;
    Width: Integer;
    Height: Integer;
    PreviewReady: Boolean;
  end;

  THeightFieldImState = record
    Active: Boolean;
    CreateAsObject: Boolean;
    NeedsRefresh: Boolean;
    SelectedIndex: Integer;
    Name: array[0..127] of AnsiChar;
    FileName: array[0..511] of AnsiChar;
    Width: Single;
    Depth: Single;
    HeightScale: Single;
    UVScale: Single;
    TileSize: Integer;
    LODEnabled: Boolean;
    LODCount: Integer;
    LODDistance: Single;
    Position: array[0..2] of Single;
    RotationDeg: array[0..2] of Single;
    Scale: array[0..2] of Single;
    Maps: TArray<THeightFieldMapInfo>;
    LastError: string;
  end;

  TMaterialFileBrowserMode = (
    mfbNone,
    mfbLoadMaterial,
    mfbSaveMaterial,
    mfbLoadLibrary,
    mfbSaveLibrary
  );

  TSceneFileBrowserMode = (
    sfbNone,
    sfbLoadScene,
    sfbSaveScene
  );

  TParticleFileBrowserMode = (
    pfbNone,
    pfbLoadParticle,
    pfbSaveParticle
  );

  TModelFileInfo = record
    FileName: string;
    RelativePath: string;
    DisplayName: string;
    Summary: string;
    FileSize: Int64;
    ModifiedText: string;
    Selected: Boolean;
  end;

  TModelFileBrowserMode = (
    modelBrowserLoadObject,
    modelBrowserLoadWindTree,
    modelBrowserLoadVertexWindTree,
    modelBrowserAddMesh,
    modelBrowserLoadAnimationClips
  );

  TModelFileBrowserState = record
    Active: Boolean;
    Mode: TModelFileBrowserMode;
    CreateAsObject: Boolean;
    CreateWindTree: Boolean;
    CreateVertexWindTree: Boolean;
    AutoPlayFirstAnimation: Boolean;
    NeedsRefresh: Boolean;
    SelectedIndex: Integer;
    Search: array[0..127] of AnsiChar;
    Items: TArray<TModelFileInfo>;
    LastError: string;
  end;

  TTextureAssetInfo = record
    FileName: string;
    RelativePath: string;
    DisplayName: string;
    CacheFileName: string;
    FileSize: Int64;
    LastWriteStamp: Int64;
    TextureID: GLuint;
    Width: Integer;
    Height: Integer;
    PreviewReady: Boolean;
  end;

  TTextureBrowserState = record
    Active: Boolean;
    NeedsRefresh: Boolean;
    SelectedIndex: Integer;
    Search: array[0..127] of AnsiChar;
    LibraryIndex: Integer;
    MaterialIndex: Integer;
    TextureIndex: Integer;
    Items: TArray<TTextureAssetInfo>;
    LastError: string;
  end;

  TMaterialFileInfo = record
    FileName: string;
    RelativePath: string;
    DisplayName: string;
    Summary: string;
    PreviewTexturePath: string;
    IsLibrary: Boolean;
    TextureID: GLuint;
    Width: Integer;
    Height: Integer;
    PreviewReady: Boolean;
  end;

  TMaterialFileBrowserState = record
    Active: Boolean;
    NeedsRefresh: Boolean;
    Mode: TMaterialFileBrowserMode;
    SelectedIndex: Integer;
    PendingOverwrite: Boolean;
    Search: array[0..127] of AnsiChar;
    FileName: array[0..255] of AnsiChar;
    PendingOverwriteFileName: string;
    Items: TArray<TMaterialFileInfo>;
    LastError: string;
  end;

  TSceneFileInfo = record
    FileName: string;
    RelativePath: string;
    DisplayName: string;
    SceneName: string;
    Summary: string;
    FileSize: Int64;
    ModifiedText: string;
    ValidScene: Boolean;
  end;

  TSceneFileBrowserState = record
    Active: Boolean;
    NeedsRefresh: Boolean;
    Mode: TSceneFileBrowserMode;
    SelectedIndex: Integer;
    PendingOverwrite: Boolean;
    Search: array[0..127] of AnsiChar;
    FileName: array[0..255] of AnsiChar;
    PendingOverwriteFileName: string;
    Items: TArray<TSceneFileInfo>;
    LastError: string;
  end;

  TParticleFileInfo = record
    FileName: string;
    RelativePath: string;
    DisplayName: string;
    Summary: string;
    PreviewTexturePath: string;
    TextureID: GLuint;
    Width: Integer;
    Height: Integer;
    PreviewReady: Boolean;
    FileSize: Int64;
    ModifiedText: string;
    ValidParticleSystem: Boolean;
  end;

  TParticleFileBrowserState = record
    Active: Boolean;
    NeedsRefresh: Boolean;
    Mode: TParticleFileBrowserMode;
    SelectedIndex: Integer;
    PendingOverwrite: Boolean;
    Search: array[0..127] of AnsiChar;
    FileName: array[0..255] of AnsiChar;
    PendingOverwriteFileName: string;
    Items: TArray<TParticleFileInfo>;
    LastError: string;
  end;

  TParticleTextureFileInfo = record
    FileName: string;
    RelativePath: string;
    DisplayName: string;
    CacheFileName: string;
    FileSize: Int64;
    LastWriteStamp: Int64;
    TextureID: GLuint;
    Width: Integer;
    Height: Integer;
    PreviewReady: Boolean;
  end;

  TParticleTextureBrowserState = record
    Active: Boolean;
    NeedsRefresh: Boolean;
    SelectedIndex: Integer;
    Search: array[0..127] of AnsiChar;
    Items: TArray<TParticleTextureFileInfo>;
    LastError: string;
  end;

  TBillboardTextureFileInfo = record
    FileName: string;
    RelativePath: string;
    DisplayName: string;
    CacheFileName: string;
    FileSize: Int64;
    LastWriteStamp: Int64;
    TextureID: GLuint;
    Width: Integer;
    Height: Integer;
    PreviewReady: Boolean;
  end;

  TBillboardTextureBrowserState = record
    Active: Boolean;
    NeedsRefresh: Boolean;
    SelectedIndex: Integer;
    Search: array[0..127] of AnsiChar;
    Items: TArray<TBillboardTextureFileInfo>;
    LastError: string;
  end;

  TAudioFileInfo = record
    FileName: string;
    RelativePath: string;
    DisplayName: string;
    FileSize: Int64;
    ModifiedText: string;
  end;

  TAudioTestState = record
    NeedsRefresh: Boolean;
    SelectedIndex: Integer;
    Search: array[0..127] of AnsiChar;
    FileName: array[0..511] of AnsiChar;
    Loop: Boolean;
    Volume: Single;
    MasterVolume: Single;
    Items: TArray<TAudioFileInfo>;
    LastError: string;
  end;

  TScriptEditorOverwriteKind = (
    sowNone,
    sowLibrary,
    sowAsset
  );

  TScriptFileKind = (
    sfkLibrary,
    sfkAsset
  );

  TScriptFileInfo = record
    FileName: string;
    RelativePath: string;
    DisplayName: string;
    Kind: TScriptFileKind;
    FileSize: Int64;
    ModifiedText: string;
  end;

  TPrefabFileBrowserMode = (
    prefabNone,
    prefabSave,
    prefabLoad
  );

  TPrefabFileInfo = record
    FileName: string;
    RelativePath: string;
    DisplayName: string;
    FileSize: Int64;
    ModifiedText: string;
  end;

  TPrefabFileBrowserState = record
    Active: Boolean;
    Mode: TPrefabFileBrowserMode;
    NeedsRefresh: Boolean;
    SelectedIndex: Integer;
    PendingOverwrite: Boolean;
    PendingOverwriteFileName: string;
    Search: array[0..127] of AnsiChar;
    FileName: array[0..255] of AnsiChar;
    Items: TArray<TPrefabFileInfo>;
    LastError: string;
  end;

  TScriptEditorState = record
    NeedsFileRefresh: Boolean;
    SelectedFileIndex: Integer;
    SelectedIndex: Integer;
    PendingOverwrite: Boolean;
    PendingOverwriteKind: TScriptEditorOverwriteKind;
    PendingOverwriteFileName: string;
    SourceEditorActive: Boolean;
    SourceEditorHovered: Boolean;
    SourceRectMinX: Single;
    SourceRectMinY: Single;
    SourceRectMaxX: Single;
    SourceRectMaxY: Single;
    Search: array[0..127] of AnsiChar;
    NewScriptName: array[0..127] of AnsiChar;
    Name: array[0..127] of AnsiChar;
    Description: array[0..255] of AnsiChar;
    Author: array[0..127] of AnsiChar;
    Category: array[0..127] of AnsiChar;
    VersionText: array[0..63] of AnsiChar;
    EntryPoint: array[0..127] of AnsiChar;
    TargetName: array[0..255] of AnsiChar;
    LibraryFileName: array[0..255] of AnsiChar;
    AssetFileName: array[0..255] of AnsiChar;
    Source: array[0..65535] of AnsiChar;
    Files: TArray<TScriptFileInfo>;
    Status: string;
    LastError: string;
    Dirty: Boolean;
  end;

  TRenderTextureToolState = record
    Active: Boolean;
    Pending: Boolean;
    Width: Integer;
    Height: Integer;
    AntialiasingSamples: Integer;
    FileName: array[0..255] of AnsiChar;
    LastOutputFileName: string;
    LastError: string;
  end;

  TMaterialEditorImState = record
    Active: Boolean;
    SelectedLibraryIndex: Integer;
    SelectedMaterialIndex: Integer;
    SelectedTextureIndex: Integer;
    NewLibraryName: array[0..127] of AnsiChar;
    NewMaterialName: array[0..127] of AnsiChar;
    NewMaterialType: Integer;
  end;

  TSandBoxSettings = record
    StartMaximized: Boolean;
    ShowOnTaskbar: Boolean;

    class function Default: TSandBoxSettings; static;
  end;

  TSandBoxForm = class;

  TSandBox = class sealed
  public
    class function Create(AOwner: TComponent): TSandBoxForm; overload; static;
    class function Create(AOwner: TComponent;
      const ASettings: TSandBoxSettings): TSandBoxForm; overload; static;
  end;

  TSandBoxForm = class(TForm)
  private const
    GIZMO_MATERIAL_NAME = 'GizmoColorMaterial';
    DEFAULT_PBR_MATERIAL_NAME = 'DefaultPBRMaterial';
    HEIGHTFIELD_THUMB_SIZE = 64;
    MATERIAL_TEXTURE_THUMB_SIZE = 64;
    MATERIAL_FILE_THUMB_SIZE = 64;
    PARTICLE_TEXTURE_THUMB_SIZE = 64;
    BILLBOARD_TEXTURE_THUMB_SIZE = 64;
    PARTICLE_FILE_THUMB_SIZE = 64;
    WATER_EDITOR_MIN_SEGMENTS = 64;
    IMGUI_PROP_SCALAR_WIDTH = 120.0;
    IMGUI_PROP_VECTOR3_WIDTH = 210.0;
    IMGUI_PROP_TEXT_WIDTH = 240.0;
    GIZMO_SCREEN_SIZE_PX = 70.0;
    GIZMO_PICK_TOLERANCE_PX = 10.0;
    GIZMO_CLONE_DRAG_THRESHOLD_PX = 2;
    VIEWPORT_CONTEXT_POPUP_NAME = 'ViewportObjectContextPopup';
    RIGHT_CLICK_DRAG_THRESHOLD_PX = 3;
    LIGHT_BILLBOARD_TEXTURE_PATH = 'Billboards\Textures\LIGHT.tga';
    LIGHT_BILLBOARD_NAME = 'Light Glyph';
    LIGHT_BILLBOARD_SIZE = 0.75;
    BILLBOARD_PICK_RADIUS_PX = 18.0;
    ANIMATED_SPRITE_PICK_RADIUS_PX = 18.0;

    // Gizmo pick tags. Axis tags 0..2 are kept for shader compatibility.
    GIZMO_TAG_X = 0;
    GIZMO_TAG_Y = 1;
    GIZMO_TAG_Z = 2;
    GIZMO_TAG_CENTER = 3;
    GIZMO_TAG_XY = 4;
    GIZMO_TAG_YZ = 5;
    GIZMO_TAG_XZ = 6;
  private
    fEngine: TGameEngine;
    { Non-owning engine references used by editor panels and selection tools. }
    fRenderer: TRenderer;
    fGrid: T3DGrid;
    fSceneManager: TSceneManager;
    fRoot: TSceneObject;
    fSceneWorld: TSceneObject;
    fLight: TSceneObject;
    fCamera: TSceneObject;
    fCameraUp: TVector3;

    fShader: TShader;
    fActorShader: TShader;
    fTreeLeafShader: TShader;
    fTreeTrunkShader: TShader;
    fHeightFieldShader: TShader;
    fGizmoShader: TShader;
    fGizmoMaterialLibrary: TMaterialLibrary;
    MaterialLibraries: TMaterialLibraries;

    fImGui: TEditorImGuiBackend;
    fUseImGuiEditor: Boolean;
    fShowImGuiDemo: Boolean;
    fShowPostEffects: Boolean;
    fShowSkyDome: Boolean;
    fShowSelectedBounds: Boolean;
    fShowPhysics: Boolean;
    fShowAudioTest: Boolean;
    fShowScriptEditor: Boolean;
    fPhysicsRunning: Boolean;
    fPhysicsStatusMessage: string;
    fParticleEditorActive: Boolean;
    fParticleEditorExpandAllOnNextOpen: Boolean;
    fImGuiMouseCaptured: Boolean;
    fImGuiKeyboardCaptured: Boolean;
    fImGuiMouseBlockScene: Boolean;

    fLog: TStringList;
    fSelectedObject: TSceneObject;
    fSelectedMesh: TMesh;
    fSelectedMeshIndex: Integer;
    fSelectedParticleSystemIndex: Integer;
    fSelectedBillboardIndex: Integer;
    fSelectedAnimatedSpriteIndex: Integer;
    fSelectedAudioEmitterIndex: Integer;
    fAnimationBlendDuration: Single;
    fObjectClipboard: TSceneObject;
    fObjectClipboardBaseName: string;
    fObjectClipboardPhysicsValid: Boolean;
    fObjectClipboardPhysicsState: TPhysicsBodyState;
    fPhysicsWorld: TPhysicsWorld;
    fAudioEngine: TBassAudioEngine;
    fAudioTestSound: TBassSound;
    fScriptManager: TEngineScriptManager;
    fRunningScriptLifecycleEvent: Boolean;
    fLastScriptLifecycleError: string;

    fCurrentGizmo: TSceneObject;
    fGizmoOwner: TSceneObject;
    fBuiltGizmoMode: TGizmoMode;
    fGizmoMode: TGizmoMode;
    fHoveredAxis: Integer;

    fDraggingGizmo: Boolean;
    fDraggedAxis: Integer;
    fGizmoClonePending: Boolean;
    fGizmoCloneSource: TSceneObject;
    fDragStartMousePos: TPoint;
    fDragStartObjectPos: TVector3;
    fDragAxisWorldDir: TVector3;
    fDragOffsetWorld: TVector3;
    fDragAxisMask: Integer;
    fDragPlaneNormal: TVector3;
    fDragStartPlaneHit: TVector3;
    fScalePlaneStartVector: TVector3;
    fRotateStartAngle: Single;
    fRotateStartAngleSet: Boolean;
    fDragStartHandlePos: TVector3;
    fInitialScale: TVector3;
    fMeshDragStartTranslation: TVector3;
    fMeshDragStartRotationDeg: TVector3;
    fMeshDragStartScale: TVector3;
    fDragStartScreenPos: TPoint;
    fDragStartScreenAxis: TVector2;
    fDragStartPixelDelta: Single;
    fEditSelectedMeshTransform: Boolean;

    fInImGuiFrame: Boolean;
    fRenderRequested: Boolean;

    Timer: TEngineTimer;

    fMouseDown: Boolean;
    fLastMouseX: Integer;
    fLastMouseY: Integer;
    fRightMouseDownPos: TPoint;
    fRightMouseDragMoved: Boolean;
    fViewportObjectPopupPending: Boolean;
    fViewportObjectPopupPos: TPoint;
    fViewportObjectPopupObject: TSceneObject;
    fOrbitTarget: TVector3;
    fCurrentRadius: Single;
    fCurrentAzimuth: Single;
    fCurrentPolar: Single;
    fTargetRadius: Single;
    fTargetAzimuth: Single;
    fTargetPolar: Single;
    fRotateSpeed: Single;
    fZoomSpeed: Single;
    fFOVRadians: Single;
    fCameraMoveSpeed: Single;

    fPanActive: Boolean;
    fLastPanX: Integer;
    fLastPanY: Integer;
    fPanSpeed: Single;

    fMeshEditor: TMeshImState;
    fHeightFieldPicker: THeightFieldImState;
    fMaterialEditor: TMaterialEditorImState;
    fTextureBrowser: TTextureBrowserState;
    fMaterialFileBrowser: TMaterialFileBrowserState;
    fModelFileBrowser: TModelFileBrowserState;
    fSceneFileBrowser: TSceneFileBrowserState;
    fParticleFileBrowser: TParticleFileBrowserState;
    fPrefabFileBrowser: TPrefabFileBrowserState;
    fParticleTextureBrowser: TParticleTextureBrowserState;
    fBillboardTextureBrowser: TBillboardTextureBrowserState;
    fAudioTest: TAudioTestState;
    fScriptEditor: TScriptEditorState;
    fRenderTextureTool: TRenderTextureToolState;

    procedure InitializeEditor;
    procedure ShutdownEditor;
    procedure CreateDefaultScene;
    procedure BuildDefaultScene;
    procedure ClearSceneObjects;

    function EditorViewportWidth: Integer;
    function EditorViewportHeight: Integer;
    procedure ActivateMainRenderContext;
    procedure RequestRender;
    procedure LogLine(const Text: string);
    function ImGuiWantsKeyboardCapture: Boolean;
    function ImGuiBlocksSceneMouse: Boolean;
    procedure UpdateImGuiCaptureState;

    function EnsureDefaultMaterialLibrary: TMaterialLibrary;
    function DefaultRenderableMaterialName: string;
    function IsEditorOnlyMaterial(AMaterial: TMaterial): Boolean;
    procedure AssignShaderToMaterial(AMaterial: TMaterial);
    procedure EnsureGizmoMaterial;
    function ShaderForMaterialType(AMaterialType: TMaterialType): TShader;
    procedure LoadDefaultTextures;
    procedure AddDefaultPBRTextures(AMaterial: TMaterial);
    procedure AddDefaultTreeLeafTextures(AMaterial: TMaterial);
    procedure AddDefaultTreeTrunkTextures(AMaterial: TMaterial);
    procedure AddDefaultHeightFieldTextures(AMaterial: TMaterial);
    function TextureDisplayName(const ATex: TMaterialTexture; AIndex: Integer): string;
    function MaterialTypeDisplayName(AMaterialType: TMaterialType): string;
    procedure GetTextureLoadParams(const AUniformName: string;
      out AMipMap: Boolean; out AInternalFormat, AParam: GLint;
      out AInvertNormals: Boolean);
    function MakeUniqueMaterialLibraryName(const BaseName: string): string;
    function MakeUniqueMaterialName(ALib: TMaterialLibrary; const BaseName: string): string;
    function CreateMaterialLibraryWithDefaultMaterial(const BaseName: string): TMaterialLibrary;
    procedure ReplaceMaterialReferencesInScene(ALib: TMaterialLibrary;
      const OldName, NewName: string);
    procedure ReplaceLibraryReferencesInScene(OldLib, NewLib: TMaterialLibrary;
      const NewMaterialName: string);
    function SceneUsesMaterialLibrary(ALib: TMaterialLibrary): Boolean;
    function SceneUsesMaterial(ALib: TMaterialLibrary;
      const MaterialName: string): Boolean;
    procedure DeleteMaterialLibraryAt(AIndex: Integer);
    procedure DeleteMaterialAt(ALib: TMaterialLibrary; AIndex: Integer);
    procedure EnsureMaterialEditorSelection;
    function SelectedMaterialEditorLibrary: TMaterialLibrary;
    function SelectedMaterialEditorMaterial: TMaterial;
    function SelectedMaterialEditorTexture(out AMaterial: TMaterial;
      out ATexture: TMaterialTexture; out ATextureIndex: Integer): Boolean;
    function IsTextureAssetFile(const AFileName: string): Boolean;
    function IsParticleTextureAssetFile(const AFileName: string): Boolean;
    function IsBillboardTextureAssetFile(const AFileName: string): Boolean;
    function IsMaterialAssetFile(const AFileName: string): Boolean;
    function TextureFileDisplayName(const AStoredPath: string): string;
    procedure SyncTextureAssetSelectionToCurrentTexture;
    function TexturePreviewMetadataDir: string;
    function TexturePreviewCacheDir: string;
    function TexturePreviewMetadataFile: string;
    function TexturePreviewCacheFileName(const ARelativePath: string): string;
    function TextureAssetFileStamp(const AFileName: string): Int64;
    function FindTextureAssetIndex(const AItems: TArray<TTextureAssetInfo>;
      const ARelativePath: string): Integer;
    function TextureInventoryMatchesCurrent(const AItems: TArray<TTextureAssetInfo>): Boolean;
    procedure ReleaseTextureAssetPreviews(var AItems: TArray<TTextureAssetInfo>);
    procedure LoadTexturePreviewMetadata(out AItems: TArray<TTextureAssetInfo>);
    procedure SaveTexturePreviewMetadata(const AItems: TArray<TTextureAssetInfo>);
    function ScanTextureAssetFiles(out AItems: TArray<TTextureAssetInfo>): Boolean;
    function TryBuildImageThumbnailBitmap(const AFileName: string;
      AThumbSize: Integer; out Thumb: TBitmap; out ImageWidth,
      ImageHeight: Integer): Boolean;
    function TryCreateGLTextureFromBitmap(ABitmap: TBitmap;
      out TextureID: GLuint): Boolean;
    function TryCreateGLTextureFromPixels(const Pixels: TBytes; AWidth,
      AHeight: Integer; out TextureID: GLuint): Boolean;
    function TryCopyBitmapToRGBAPixels(ABitmap: TBitmap;
      out Pixels: TBytes): Boolean;
    function TryLoadThumbnailBinaryFromFile(const AFileName: string;
      ExpectedFileSize, ExpectedStamp: Int64; out TextureID: GLuint;
      out ThumbWidth, ThumbHeight: Integer): Boolean;
    procedure SaveThumbnailBitmapToBinaryFile(ABitmap: TBitmap;
      const AFileName: string; SourceFileSize, SourceStamp: Int64);
    procedure SaveThumbnailPixelsToBinaryFile(const Pixels: TBytes; AWidth,
      AHeight: Integer; const AFileName: string; SourceFileSize,
      SourceStamp: Int64);
    function TryCreateImagePreviewTexture(const AFileName: string; AThumbSize: Integer;
      out TextureID: GLuint; out ImageWidth, ImageHeight: Integer): Boolean;
    function TryCreateDDSPreviewTexture(const AFileName: string; AThumbSize: Integer;
      out TextureID: GLuint; out ImageWidth, ImageHeight: Integer): Boolean;
    procedure ClearTextureBrowserPreviews;
    procedure RefreshTextureBrowserList(const ForceRebuild: Boolean = False);
    procedure ResetTextureBrowser;
    procedure OpenParticleEditor;
    procedure OpenTextureBrowser(ALibraryIndex, AMaterialIndex, ATextureIndex: Integer);
    procedure OpenParticleTextureBrowser;
    procedure OpenBillboardTextureBrowser;
    procedure ApplyTextureAssetToSelectedTexture(const AFileName: string);
    procedure ApplyParticleTextureToSelectedParticle(const AFileName: string);
    procedure ApplyBillboardTextureToSelectedObject(const AFileName: string);
    function ResolveParticleTexturePreviewPath(const AStoredPath: string): string;
    function ResolveBillboardTexturePreviewPath(const AStoredPath: string): string;
    function ParticleTexturePreviewMetadataDir: string;
    function ParticleTexturePreviewCacheDir: string;
    function ParticleTexturePreviewMetadataFile: string;
    function ParticleTexturePreviewCacheFileName(const ARelativePath: string): string;
    function FindParticleTextureIndex(
      const AItems: TArray<TParticleTextureFileInfo>;
      const ARelativePath: string): Integer;
    function ParticleTextureInventoryMatchesCurrent(
      const AItems: TArray<TParticleTextureFileInfo>): Boolean;
    procedure ReleaseParticleTexturePreviews(
      var AItems: TArray<TParticleTextureFileInfo>);
    procedure LoadParticleTexturePreviewMetadata(
      out AItems: TArray<TParticleTextureFileInfo>);
    procedure SaveParticleTexturePreviewMetadata(
      const AItems: TArray<TParticleTextureFileInfo>);
    function ScanParticleTextureFiles(
      out AItems: TArray<TParticleTextureFileInfo>): Boolean;
    function BillboardTexturePreviewMetadataDir: string;
    function BillboardTexturePreviewCacheDir: string;
    function BillboardTexturePreviewMetadataFile: string;
    function BillboardTexturePreviewCacheFileName(const ARelativePath: string): string;
    function FindBillboardTextureIndex(
      const AItems: TArray<TBillboardTextureFileInfo>;
      const ARelativePath: string): Integer;
    function BillboardTextureInventoryMatchesCurrent(
      const AItems: TArray<TBillboardTextureFileInfo>): Boolean;
    procedure ReleaseBillboardTexturePreviews(
      var AItems: TArray<TBillboardTextureFileInfo>);
    procedure LoadBillboardTexturePreviewMetadata(
      out AItems: TArray<TBillboardTextureFileInfo>);
    procedure SaveBillboardTexturePreviewMetadata(
      const AItems: TArray<TBillboardTextureFileInfo>);
    function ScanBillboardTextureFiles(
      out AItems: TArray<TBillboardTextureFileInfo>): Boolean;
    function TryCreateParticleTexturePreview(const AFileName: string;
      AThumbSize: Integer; out TextureID: GLuint; out ImageWidth,
      ImageHeight: Integer): Boolean;
    procedure ClearParticleTexturePreviews;
    procedure ClearBillboardTexturePreviews;
    procedure RefreshParticleTextureList(const ForceRebuild: Boolean = False);
    procedure RefreshBillboardTextureList(const ForceRebuild: Boolean = False);
    procedure ResetParticleTextureBrowser;
    procedure ResetBillboardTextureBrowser;
    procedure DrawOverwriteConfirmation(const AFileName, AKind,
      AIdSuffix: string; out ReplaceClicked, CancelClicked: Boolean);
    procedure ClearMaterialFilePreviews;
    procedure RefreshMaterialFileList;
    procedure ResetMaterialFileBrowser;
    procedure OpenMaterialFileBrowser(AMode: TMaterialFileBrowserMode);
    function TryReadMaterialPreviewInfo(const AFileName: string;
      out DisplayName, Summary, PreviewTexturePath: string;
      out IsLibrary: Boolean): Boolean;
    procedure ExecuteMaterialFileBrowserAction;
    procedure SaveSelectedMaterialToFile(const AFileName: string);
    procedure SaveSelectedMaterialLibraryToFile(const AFileName: string);
    procedure LoadMaterialIntoSelectedLibrary(const AFileName: string);
    procedure LoadMaterialLibraryFromFile(const AFileName: string);
    function IsModelAssetFile(const AFileName: string): Boolean;
    procedure RefreshModelFileList;
    procedure ResetModelFileBrowser;
    procedure OpenModelFileBrowser(CreateAsObject: Boolean;
      CreateWindTree: Boolean = False;
      CreateVertexWindTree: Boolean = False);
    procedure OpenAnimationFileBrowser;
    procedure ExecuteModelFileBrowserAction;
    function MakeUniqueAnimationClipName(Animator: TSkeletonAnimator;
      const ABaseName: string): string;
    procedure ImportAnimationFilesFromImGui(const AFileNames: TArray<string>);
    function IsSceneAssetFile(const AFileName: string): Boolean;
    procedure RefreshSceneFileList;
    procedure ResetSceneFileBrowser;
    procedure OpenSceneFileBrowser(AMode: TSceneFileBrowserMode);
    function TryReadScenePreviewInfo(const AFileName: string;
      out SceneName, Summary: string; out FileSize: Int64;
      out ModifiedText: string): Boolean;
    procedure RestoreSceneAfterLoad;
    procedure SaveSceneRenderSettingsToStream(Stream: TStream);
    function TryLoadSceneRenderSettingsFromStream(Stream: TStream): Boolean;
    procedure SaveScenePhysicsToStream(Stream: TStream);
    function TryLoadScenePhysicsFromStream(Stream: TStream): Boolean;
    procedure SaveScenePhysicsCacheToStream(Stream: TStream);
    function TryLoadScenePhysicsCacheFromStream(Stream: TStream): Boolean;
    procedure SaveSceneScriptsToStream(Stream: TStream);
    function TryLoadSceneScriptsFromStream(Stream: TStream): Boolean;
    procedure SaveSceneToFile(const AFileName: string);
    procedure LoadSceneFromFile(const AFileName: string);
    function TryLoadDefaultSceneFromDisk(const AFileName: string): Boolean;
    procedure SaveDefaultSceneToDisk(const AFileName: string);
    procedure ExecuteSceneFileBrowserAction;
    function FindFirstLightSceneObject(Obj: TSceneObject): TSceneObject;
    procedure ConfigureLightDefaults(Light: TLight; ALightType: TLightType);
    function EnsureLightBillboard(Obj: TSceneObject): TBillboard;
    procedure EnsureLightBillboards(Obj: TSceneObject);
    function IsPrefabAssetFile(const AFileName: string): Boolean;
    function ResolvePrefabFileName(const AFileName: string): string;
    procedure RefreshPrefabFileList;
    procedure ResetPrefabFileBrowser;
    procedure OpenPrefabFileBrowser(AMode: TPrefabFileBrowserMode);
    procedure SaveSelectedObjectPrefabToFile(const AFileName: string);
    function LoadPrefabFromFile(const AFileName: string;
      AParent: TSceneObject): TSceneObject;
    procedure ExecutePrefabFileBrowserAction;
    procedure DrawImGuiPrefabFileBrowser;
    function SceneObjectPath(Obj: TSceneObject): string;
    function LoadPrefabForScript(const AFileName: string;
      AParent: TSceneObject): TSceneObject;
    procedure DestroyPrefabForScript(AObject: TSceneObject);
    function SelectedParticleObject: TSceneObject;
    function SelectedParticleSystem: TParticleSystem;
    function SelectedBillboard: TBillboard;
    function SelectedAnimatedSprite: TAnimatedSprite;
    function SelectedAudioEmitter: TSceneAudioEmitter;
    function IsParticleAssetFile(const AFileName: string): Boolean;
    procedure RefreshParticleFileList;
    procedure ResetParticleFileBrowser;
    procedure OpenParticleFileBrowser(AMode: TParticleFileBrowserMode);
    function TryReadParticlePreviewInfo(const AFileName: string;
      out DisplayName, Summary, PreviewTexturePath: string;
      out FileSize: Int64; out ModifiedText: string): Boolean;
    procedure ClearParticleFilePreviews;
    procedure SaveSelectedParticleSystemToFile(const AFileName: string);
    procedure LoadParticleSystemIntoSelectedObject(const AFileName: string);
    procedure ExecuteParticleFileBrowserAction;
    procedure DrawImGuiMaterialEditor;
    procedure DrawImGuiParticleEditor;
    procedure DrawImGuiTextureBrowser;
    procedure DrawImGuiParticleTextureBrowser;
    procedure DrawImGuiBillboardTextureBrowser;
    procedure DrawImGuiMaterialFileBrowser;
    procedure DrawImGuiModelFileBrowser;
    procedure DrawImGuiSceneFileBrowser;
    procedure DrawImGuiParticleFileBrowser;
    function IsAudioAssetFile(const AFileName: string): Boolean;
    procedure RefreshAudioFileList;
    procedure LoadAudioTestFile(const AFileName: string);
    procedure DrawImGuiAudioTest;
    function ResolveAudioPath(const AStoredPath: string): string;
    procedure LoadSceneAudioEmitter(AEmitter: TSceneAudioEmitter);
    procedure ReleaseSceneAudioEmitter(AEmitter: TSceneAudioEmitter);
    procedure ReleaseSceneObjectAudio(Obj: TSceneObject);
    procedure ApplySceneAudioEmitterRuntimeState(Obj: TSceneObject;
      AEmitter: TSceneAudioEmitter);
    procedure UpdateSceneAudio;
    procedure BindScriptEngine;
    function ResolveScriptFileName(const AFileName, AExtension: string): string;
    function SelectedScriptAsset: TEngineScriptAsset;
    procedure SyncScriptEditorFromSelected;
    procedure SyncSelectedScriptFromEditor;
    procedure SelectScriptIndex(const AIndex: Integer);
    procedure AddNewScriptFromEditor;
    procedure DeleteSelectedScript;
    procedure SaveScriptLibraryToFile(const AFileName: string);
    procedure LoadScriptLibraryFromFile(const AFileName: string);
    procedure SaveSelectedScriptAssetToFile(const AFileName: string);
    procedure LoadScriptAssetFromFile(const AFileName: string);
    procedure LoadScriptFile(const AFileName: string);
    procedure RefreshScriptFileList;
    procedure ResetScriptSourceEditorTracking;
    procedure ResetScriptEditorForSceneChange;
    function ScriptSourceEditorContainsPoint(X, Y: Integer): Boolean;
    procedure ExecuteScriptLifecycleEvent(const AEventName: string);
    procedure RendererBeforeRender(Sender: TObject);
    procedure RendererRender(Sender: TObject);
    procedure RendererAfterRender(Sender: TObject);
    procedure RenderEditorGrid(Sender: TObject);
    function ResolveGeneratedTextureFileName(const AFileName: string): string;
    procedure QueueRenderTextureCapture;
    procedure ProcessRenderTextureCapture;

    procedure UpdateScene(const DeltaTime, NewTime: Double);
    procedure UpdateKeyboardCameraMovement(const DeltaTime: Double);
    procedure SyncOrbitFromCamera;
    procedure UpdateOrbitCamera;
    procedure SyncSkyDomeToMainLight;

    procedure ApplyFrameUniformsToShader(Shader: TShader);
    procedure ApplyLightToShader(Shader: TShader; Light: TLight; Index: Integer);
    procedure ApplySceneLightsToShader(Shader: TShader);
    procedure OnUpdateShader(Shader: TShader);
    procedure OnUpdateGizmoShader(Shader: TShader);
    procedure MeshRenderHandler(Mesh: TMesh; Shader: TShader);
    procedure GizmoMeshRenderHandler(Mesh: TMesh; Shader: TShader);

    function GetGizmoTargetWorldPosition: TVector3;
    function CreateTranslateGizmo(ParentObj: TSceneObject): TSceneObject;
    function CreateRotateGizmo(ParentObj: TSceneObject): TSceneObject;
    function CreateScaleGizmo(ParentObj: TSceneObject): TSceneObject;
    procedure ReleaseCurrentGizmo;
    procedure RefreshGizmo;
    procedure UpdateGizmoScale;
    function IsMeshEditModeActive: Boolean;
    function GetMeshEditorTransformValues(out Translation, RotationDeg, Scale: TVector3): Boolean;
    procedure SetMeshEditorTransformValues(const Translation, RotationDeg, Scale: TVector3;
      const Preview: Boolean);
    function PickGizmoAxis(X, Y: Integer; out AxisTag: Integer): Boolean;
    function PickRotateAxis(X, Y: Integer; out AxisTag: Integer): Boolean;
    function PickScaleGizmoAxis(X, Y: Integer; out AxisTag: Integer): Boolean;
    function GizmoAxisMask(AxisTag: Integer): Integer;
    function IsSingleAxisGizmoTag(AxisTag: Integer): Boolean;
    function IsPlaneGizmoTag(AxisTag: Integer): Boolean;
    function IsCenterGizmoTag(AxisTag: Integer): Boolean;
    function GetGizmoPlaneNormalByTag(AxisTag: Integer): TVector3;
    function RayPlaneIntersectionAtScreen(X, Y: Integer; const PlanePoint,
      PlaneNormal: TVector3; out HitPoint: TVector3): Boolean;
    function GetArrowTipByTag(AxisTag: Integer): TVector3;
    function GetScaleTipByTag(AxisTag: Integer): TVector3;
    function GetScaleHandleWorldPosition(AxisTag: Integer): TVector3;
    function GetDragParameter(CurrentX, CurrentY: Integer; out U: Single): Boolean;
    procedure CheckGizmoHover(X, Y: Integer);
    function SelectObjectAtScreenPos(X, Y: Integer): Boolean;
    procedure DeselectObject;
    procedure RenderGizmoOverlay;
    procedure RenderGizmoOverlayObject(Obj: TSceneObject);

    procedure ApplyImGuiStyle;
    procedure RenderImGuiEditor(Sender: TObject);
    procedure DrawImGuiEditor;
    procedure DrawImGuiToolbar;
    procedure DrawImGuiViewportToolbar;
    procedure DrawImGuiSceneTree;
    procedure DrawImGuiSceneObjectNode(Obj: TSceneObject);
    function DrawSceneObjectContextMenu(Obj: TSceneObject): Boolean;
    procedure DrawViewportObjectContextPopup;
    procedure DrawImGuiInspector;
    procedure DrawImGuiPostEffects;
    procedure DrawImGuiSkyDome;
    procedure DrawImGuiRenderTextureTool;
    procedure DrawImGuiPhysics;
    procedure DrawImGuiPhysicsBodyEditor(Obj: TSceneObject; Compact: Boolean);
    procedure DrawImGuiScriptEditor;
    procedure DrawImGuiObjectProperties;
    procedure DrawImGuiAnimationProperties;
    procedure DrawImGuiWindProperties;
    procedure DrawImGuiLightProperties;
    procedure DrawImGuiBillboardProperties;
    procedure DrawImGuiAnimatedSpriteProperties;
    procedure DrawImGuiAudioProperties;
    procedure DrawImGuiMeshProperties(Mesh: TMesh);
    procedure DrawImGuiMeshGeometryProperties(Mesh: TMesh);
    procedure NotifyInspectorObjectEdited;
    procedure NotifyInspectorMeshEdited(Mesh: TMesh; GeometryChanged: Boolean = False);
    procedure DrawImGuiLog;
    procedure DrawImGuiMeshEditor;
    procedure DrawImGuiHeightFieldBrowser;

    procedure SelectObjectFromImGui(Obj: TSceneObject);
    procedure FocusCameraOnSceneObject(Obj: TSceneObject);
    procedure StartPhysicsSimulation;
    procedure PausePhysicsSimulation;
    procedure StopPhysicsSimulation;
    procedure ResetPhysicsSimulation;
    function IsProtectedSceneObject(Obj: TSceneObject): Boolean;
    function CanUseSceneObjectAsParent(Obj: TSceneObject): Boolean;
    procedure CopySelectedObjectToClipboard;
    procedure CutSelectedObjectToClipboard;
    procedure PasteObjectFromClipboard;
    function CloneObjectForGizmo(SourceObj: TSceneObject): TSceneObject;
    function CanReparentSceneObject(SourceObj, ParentObj: TSceneObject): Boolean;
    procedure MoveSceneObjectToParent(SourceObj, ParentObj: TSceneObject);
    procedure CreateInstanceFromSelectedObject;
    procedure DeleteObjectFromImGui(Obj: TSceneObject);
    procedure OpenViewportObjectContextPopup(X, Y: Integer; Obj: TSceneObject);
    procedure SelectMeshIndex(const MeshIndex: Integer);
    procedure SelectParticleSystemIndex(const ParticleSystemIndex: Integer);
    procedure SelectBillboardIndex(const BillboardIndex: Integer);
    procedure SelectAnimatedSpriteIndex(const AnimatedSpriteIndex: Integer);
    procedure SelectAudioEmitterIndex(const AudioEmitterIndex: Integer);
    procedure DeleteSelectedMesh;
    procedure DeleteSelectedParticleSystem;
    procedure DeleteSelectedBillboard;
    procedure DeleteSelectedAnimatedSprite;
    procedure DeleteSelectedAudioEmitter;
    procedure SetGizmoModeFromToolbar(AMode: TGizmoMode);

    function MaterialLibraryDisplayName(ALib: TMaterialLibrary; Index: Integer): string;
    function MaterialDisplayName(AMat: TMaterial; Index: Integer): string;
    function MaterialLibraryIndexOf(ALib: TMaterialLibrary): Integer;
    function MaterialIndexInLibrary(ALib: TMaterialLibrary; const MaterialName: string): Integer;
    function FirstRenderableMaterialIndex(ALib: TMaterialLibrary): Integer;

    procedure AssignMaterialToSelectedMesh(ALib: TMaterialLibrary; AMat: TMaterial);
    procedure AssignMaterialToSelectedObject(ALib: TMaterialLibrary; AMat: TMaterial);
    procedure DrawImGuiMaterialAssignment;

    // object / primitive creation
    procedure PrepareImportedMeshList(Meshes: TMeshList; ALib: TMaterialLibrary);
    procedure ImportMeshFileFromImGui(const AFileName: string;
      CreateAsObject: Boolean; CreateAsWindTree: Boolean = False;
      CreateAsVertexWindTree: Boolean = False);
    procedure BeginCreateEmptyObjectFromImGui;
    procedure BeginCreateLightObjectFromImGui(ALightType: TLightType);
    procedure BeginCreatePrimitiveObjectFromImGui(AKind: TPrimitiveKind);
    procedure BeginCreatePrimitiveMeshFromImGui(AKind: TPrimitiveKind);
    procedure BeginCreateMeshFileObjectFromImGui;
    procedure BeginCreateWindTreeObjectFromImGui;
    procedure BeginCreateVertexWindTreeObjectFromImGui;
    procedure BeginCreateMeshFileMeshFromImGui;
    procedure BeginEditSelectedMeshFromImGui;
    procedure BeginPrimitiveEditor(AKind: TPrimitiveKind; Obj: TSceneObject; Mesh: TMesh;
      CreatedObject, CreatedMesh: Boolean);
    procedure DrawAddObjectMenuItems;
    procedure DrawAddMeshMenuItems;
    procedure BeginCreateHeightFieldObjectFromImGui;
    procedure BeginCreateHeightFieldMeshFromImGui;
    procedure OpenHeightFieldBrowser(CreateAsObject: Boolean);
    procedure ResetHeightFieldBrowser;
    function DefaultObjectSpawnPosition(ParentObj: TSceneObject): TVector3;
    procedure RefreshHeightFieldMapList;
    procedure ClearHeightFieldMapPreviews;
    procedure SelectHeightFieldMapFromBrowser(Index: Integer);
    function IsHeightFieldMapFile(const AFileName: string): Boolean;
    function TryCreateHeightFieldPreviewTexture(const AFileName: string;
      out TextureID: GLuint; out ImageWidth, ImageHeight: Integer): Boolean;
    function CreateHeightFieldMeshFromBrowser(const MeshName, AFileName: string): TMesh;
    procedure SetupHeightFieldMesh(Mesh: TMesh);
    procedure CreateSelectedHeightFieldFromBrowser;
    procedure SetupRenderableMesh(Mesh: TMesh);
    procedure InitPrimitiveEditorDefaults(AKind: TPrimitiveKind; Mesh: TMesh);
    function PrimitiveKindDisplayName(AKind: TPrimitiveKind): string;
    function PrimitiveBaseName(AKind: TPrimitiveKind): string;
    function TryGetPrimitiveKindForMesh(Mesh: TMesh; out AKind: TPrimitiveKind): Boolean;
    function CreateDefaultPrimitiveMesh(AKind: TPrimitiveKind; const MeshName: string): TMesh;
    function CreatePrimitiveMeshFromEditor(const MeshName: string): TMesh;

    // cube-compatible wrappers/editor entry points
    procedure BeginCreateCubeObjectFromImGui;
    procedure BeginCreateCubeMeshFromImGui;
    procedure BeginCubeEditor(Obj: TSceneObject; Mesh: TMesh; CreatedObject, CreatedMesh: Boolean);
    procedure ApplyMeshEditorPreview;
    procedure EndMeshEditor(Accept: Boolean);
    function MeshEditorName: string;

    function MakeUniqueObjectName(ParentObj: TSceneObject; const BaseName: string): string;
    function GenMeshName(const AName: string): string;

    procedure DoProgress(Sender: TObject; const DeltaTime, NewTime: Double);

    procedure FormResizeHandler(Sender: TObject);
    procedure FormCloseHandler(Sender: TObject; var Action: TCloseAction);
    procedure FormMouseWheelHandler(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure FormMouseDownHandler(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormMouseMoveHandler(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure FormMouseUpHandler(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure EditorShortcutKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditorShortcutKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditorShortcutKeyPress(Sender: TObject; var Key: Char);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  public
    PATH: string;
    GLSL_PATH: string;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  SandBoxForm: TSandBoxForm;

function Create(AOwner: TComponent): TSandBoxForm; overload;
function Create(AOwner: TComponent; const ASettings: TSandBoxSettings): TSandBoxForm; overload;

implementation

{ T3DGrid }

constructor T3DGrid.Create(const AVertexFileName, AFragmentFileName: string);
begin
  inherited Create;
  fVAO := 0;
  fVBO := 0;
  fEnabled := True;
  fShader := TShader.Create(AVertexFileName, AFragmentFileName);
  CreateGeometry;
end;

destructor T3DGrid.Destroy;
begin
  DestroyGeometry;
  FreeAndNil(fShader);
  inherited Destroy;
end;

procedure T3DGrid.CreateGeometry;
const
  Vertices: array[0..17] of GLfloat = (
    -1.0, -1.0, 0.0,
     1.0, -1.0, 0.0,
     1.0,  1.0, 0.0,
    -1.0, -1.0, 0.0,
     1.0,  1.0, 0.0,
    -1.0,  1.0, 0.0
  );
begin
  glGenVertexArrays(1, @fVAO);
  glGenBuffers(1, @fVBO);

  glBindVertexArray(fVAO);
  try
    glBindBuffer(GL_ARRAY_BUFFER, fVBO);
    glBufferData(GL_ARRAY_BUFFER, SizeOf(Vertices), @Vertices[0],
      GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE,
      3 * SizeOf(GLfloat), nil);
  finally
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
  end;
end;

procedure T3DGrid.DestroyGeometry;
begin
  if fVBO <> 0 then
  begin
    glDeleteBuffers(1, @fVBO);
    fVBO := 0;
  end;

  if fVAO <> 0 then
  begin
    glDeleteVertexArrays(1, @fVAO);
    fVAO := 0;
  end;
end;

procedure T3DGrid.Render(const AView, AProjection: TMatrix4;
  const ACameraPosition: TVector3);
var
  OldDepthFunc: GLint;
  OldDepthMask: GLboolean;
  OldDepthTestEnabled: GLboolean;
  OldCullEnabled: GLboolean;
  OldBlendEnabled: GLboolean;
  OldBlendSrcRGB: GLint;
  OldBlendDstRGB: GLint;
  OldBlendSrcAlpha: GLint;
  OldBlendDstAlpha: GLint;
begin
  if (not fEnabled) or (fShader = nil) or (fVAO = 0) then
    Exit;

  glGetIntegerv(GL_DEPTH_FUNC, @OldDepthFunc);
  glGetBooleanv(GL_DEPTH_WRITEMASK, @OldDepthMask);
  OldDepthTestEnabled := glIsEnabled(GL_DEPTH_TEST);
  OldCullEnabled := glIsEnabled(GL_CULL_FACE);
  OldBlendEnabled := glIsEnabled(GL_BLEND);
  glGetIntegerv(GL_BLEND_SRC_RGB, @OldBlendSrcRGB);
  glGetIntegerv(GL_BLEND_DST_RGB, @OldBlendDstRGB);
  glGetIntegerv(GL_BLEND_SRC_ALPHA, @OldBlendSrcAlpha);
  glGetIntegerv(GL_BLEND_DST_ALPHA, @OldBlendDstAlpha);

  try
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
    glDepthMask(GL_TRUE);
    glDisable(GL_CULL_FACE);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    fShader.Use;
    fShader.SetUniform('view', AView);
    fShader.SetUniform('projection', AProjection);
    fShader.SetUniform('cameraPosition', ACameraPosition);

    glBindVertexArray(fVAO);
    glDrawArrays(GL_TRIANGLES, 0, 6);
  finally
    glBindVertexArray(0);
    glUseProgram(0);
    glDepthFunc(OldDepthFunc);
    glDepthMask(OldDepthMask);

    if OldDepthTestEnabled = GL_TRUE then
      glEnable(GL_DEPTH_TEST)
    else
      glDisable(GL_DEPTH_TEST);

    if OldCullEnabled = GL_TRUE then
      glEnable(GL_CULL_FACE)
    else
      glDisable(GL_CULL_FACE);

    if OldBlendEnabled = GL_TRUE then
      glEnable(GL_BLEND)
    else
      glDisable(GL_BLEND);

    glBlendFuncSeparate(GLenum(OldBlendSrcRGB), GLenum(OldBlendDstRGB),
      GLenum(OldBlendSrcAlpha), GLenum(OldBlendDstAlpha));
  end;
end;

{ TSandBoxSettings }

class function TSandBoxSettings.Default: TSandBoxSettings;
begin
  Result.StartMaximized := True;
  Result.ShowOnTaskbar := True;
end;

{ TSandBox }

class function TSandBox.Create(AOwner: TComponent): TSandBoxForm;
begin
  Result := Create(AOwner, TSandBoxSettings.Default);
end;

class function TSandBox.Create(AOwner: TComponent;
  const ASettings: TSandBoxSettings): TSandBoxForm;
begin
  Application.MainFormOnTaskbar := ASettings.ShowOnTaskbar;

  Result := TSandBoxForm.Create(AOwner);
  if ASettings.StartMaximized then
    Result.WindowState := wsMaximized
  else
    Result.WindowState := wsNormal;
end;

function Create(AOwner: TComponent): TSandBoxForm;
begin
  Result := TSandBox.Create(AOwner);
end;

function Create(AOwner: TComponent; const ASettings: TSandBoxSettings): TSandBoxForm;
begin
  Result := TSandBox.Create(AOwner, ASettings);
end;

function ImStr(const S: string): PAnsiChar;
begin
  Result := PAnsiChar(AnsiString(S));
end;

procedure SetAnsiBuffer(var Buffer: array of AnsiChar; const Value: string);
var
  A: AnsiString;
  N: Integer;
begin
  if Length(Buffer) = 0 then
    Exit;

  FillChar(Buffer[0], Length(Buffer) * SizeOf(AnsiChar), 0);

  A := AnsiString(Value);
  N := System.Math.Min(Length(A), Length(Buffer) - 1);

  if N > 0 then
    Move(A[1], Buffer[0], N * SizeOf(AnsiChar));
end;

function AnsiBufferText(var Buffer: array of AnsiChar): string;
begin
  if Length(Buffer) = 0 then
    Exit('');

  Result := Trim(string(AnsiString(PAnsiChar(@Buffer[0]))));
end;

function AnsiBufferRawText(var Buffer: array of AnsiChar): string;
begin
  if Length(Buffer) = 0 then
    Exit('');

  Result := string(AnsiString(PAnsiChar(@Buffer[0])));
end;

procedure SetImGuiColorU8(AColor: ImGuiCol; R, G, B, A: Byte);
var
  C: PImVec4;
begin
  C := igGetStyleColorVec4(AColor);

  if C = nil then
    Exit;

  C^.x := R / 255.0;
  C^.y := G / 255.0;
  C^.z := B / 255.0;
  C^.w := A / 255.0;
end;

const
  SCENE_FILE_EXTENSION_LOCAL = '.omescn';
  SCENE_FILE_VERSION_LOCAL = 11;
  SCENE_FILE_MAGIC_LOCAL: array[0..7] of AnsiChar =
    ('O', 'M', 'E', 'S', 'C', 'N', '0', '1');
  SCENE_RENDER_SETTINGS_VERSION_LOCAL = 3;
  SCENE_RENDER_SETTINGS_MAGIC_LOCAL: array[0..7] of AnsiChar =
    ('O', 'M', 'E', 'R', 'N', 'D', '0', '1');
  SCENE_PHYSICS_VERSION_LOCAL = 1;
  SCENE_PHYSICS_MAGIC_LOCAL: array[0..7] of AnsiChar =
    ('O', 'M', 'E', 'P', 'H', 'Y', '0', '1');
  SCENE_PHYSICS_CACHE_VERSION_LOCAL = 1;
  SCENE_PHYSICS_CACHE_MAGIC_LOCAL: array[0..7] of AnsiChar =
    ('O', 'M', 'E', 'P', 'H', 'C', '0', '1');
  SCENE_SCRIPTS_VERSION_LOCAL = 1;
  SCENE_SCRIPTS_MAGIC_LOCAL: array[0..7] of AnsiChar =
    ('O', 'M', 'E', 'S', 'C', 'P', '0', '1');
  PREFAB_FILE_EXTENSION_LOCAL = '.omeprefab';
  PREFAB_FILE_VERSION_LOCAL = 2;
  PREFAB_FILE_MAGIC_LOCAL: array[0..7] of AnsiChar =
    ('O', 'M', 'E', 'P', 'R', 'F', '0', '1');
  SCRIPT_LIBRARY_FILE_EXTENSION_LOCAL = '.omeslib';
  SCRIPT_ASSET_FILE_EXTENSION_LOCAL = '.omescr';
  SCENE_OBJECT_DND_PAYLOAD_LOCAL = 'OME_SCENE_OBJECT';
  PARTICLE_FILE_EXTENSION_LOCAL = '.omepar';
  PARTICLE_FILE_VERSION_LOCAL = 1;
  PARTICLE_FILE_MAGIC_LOCAL: array[0..7] of AnsiChar =
    ('O', 'M', 'E', 'P', 'A', 'R', '0', '1');
  MATERIAL_FILE_VERSION_LOCAL = 4;
  MATERIAL_FILE_MAGIC_LOCAL: array[0..7] of AnsiChar =
    ('O', 'M', 'E', 'M', 'A', 'T', '0', '1');
  MATERIAL_LIBRARY_MAGIC_LOCAL: array[0..7] of AnsiChar =
    ('O', 'M', 'E', 'M', 'L', 'B', '0', '1');
  TEXTURE_THUMB_CACHE_VERSION_LOCAL = 1;
  TEXTURE_THUMB_CACHE_MAGIC_LOCAL: array[0..7] of AnsiChar =
    ('O', 'M', 'E', 'T', 'H', 'B', '0', '1');
  TEXTURE_PREVIEW_METADATA_DIRNAME = '.metadata';
  TEXTURE_PREVIEW_CACHE_DIRNAME = 'TextureThumbs';
  TEXTURE_PREVIEW_METADATA_FILENAME = 'texture_previews.tsv';

function PreviewMagicMatches(const Actual, Expected: array of AnsiChar): Boolean;
var
  I: Integer;
begin
  Result := Length(Actual) = Length(Expected);
  if not Result then
    Exit;

  for I := 0 to High(Expected) do
    if Actual[I] <> Expected[I] then
      Exit(False);
end;

function ScriptTargetKindDisplayName(AKind: TEngineScriptTargetKind): string;
begin
  case AKind of
    stkSceneObject: Result := 'Scene Object';
    stkShader: Result := 'Shader';
    stkMaterial: Result := 'Material';
    stkRenderTechnique: Result := 'Render Technique';
  else
    Result := 'Global';
  end;
end;

function DefaultScriptSource: string;
begin
  Result :=
    'procedure Main;' + sLineBreak +
    'begin' + sLineBreak +
    '  // Manual Run button entry point.' + sLineBreak +
    '  // Optional automatic callbacks: OnUpdate, OnBeforeRender, OnRender, OnAfterRender.' + sLineBreak +
    'end;' + sLineBreak;
end;

function HashTextFNV1a32(const Value: string): Cardinal;
var
  I: Integer;
  HashValue: UInt64;
begin
  HashValue := $811C9DC5;
  for I := 1 to Length(Value) do
  begin
    HashValue := HashValue xor Ord(Value[I]);
    HashValue := (HashValue * 16777619) and $FFFFFFFF;
  end;
  Result := Cardinal(HashValue);
end;

function ReadPreviewString(Stream: TStream): string;
var
  Len: Integer;
begin
  Result := '';
  Stream.ReadBuffer(Len, SizeOf(Len));
  if Len < 0 then
    raise Exception.Create('Invalid preview string length.');

  SetLength(Result, Len);
  if Len > 0 then
    Stream.ReadBuffer(Result[1], Len * SizeOf(Char));
end;

procedure WritePreviewString(Stream: TStream; const Value: string);
var
  Len: Integer;
begin
  Len := Length(Value);
  Stream.WriteBuffer(Len, SizeOf(Len));
  if Len > 0 then
    Stream.WriteBuffer(Value[1], Len * SizeOf(Char));
end;

function TryLoadTargaPixelsRGBA(const AFileName: string; out Pixels: TBytes;
  out Width, Height: Integer): Boolean;
var
  Stream: TFileStream;
  Header: array[0..17] of Byte;
  IDLength, ColorMapType, ImageType, BitsPerPixel, Descriptor: Byte;
  BytesPerPixel: Integer;
  PixelCount, PixelIndex: Integer;
  TopOrigin, RightOrigin: Boolean;
  PacketHeader: Byte;
  RunLength, I: Integer;
  B, G, R, A: Byte;

  function WordAt(Offset: Integer): Word;
  begin
    Result := Word(Header[Offset]) or (Word(Header[Offset + 1]) shl 8);
  end;

  function ReadPixel(out B, G, R, A: Byte): Boolean;
  var
    FilePixel: array[0..3] of Byte;
  begin
    Result := Stream.Read(FilePixel[0], BytesPerPixel) = BytesPerPixel;
    if not Result then
      Exit;

    B := FilePixel[0];
    G := FilePixel[1];
    R := FilePixel[2];
    if BytesPerPixel = 4 then
      A := FilePixel[3]
    else
      A := 255;
  end;

  procedure StorePixel(SourceIndex: Integer; B, G, R, A: Byte);
  var
    SourceX, SourceY, DestX, DestY, DestIndex: Integer;
  begin
    SourceX := SourceIndex mod Width;
    SourceY := SourceIndex div Width;

    if RightOrigin then
      DestX := Width - 1 - SourceX
    else
      DestX := SourceX;

    if TopOrigin then
      DestY := SourceY
    else
      DestY := Height - 1 - SourceY;

    DestIndex := (DestY * Width + DestX) * 4;
    Pixels[DestIndex + 0] := R;
    Pixels[DestIndex + 1] := G;
    Pixels[DestIndex + 2] := B;
    Pixels[DestIndex + 3] := A;
  end;

begin
  Result := False;
  Pixels := nil;
  Width := 0;
  Height := 0;

  try
    Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
    try
      if Stream.Read(Header[0], SizeOf(Header)) <> SizeOf(Header) then
        Exit;

      IDLength := Header[0];
      ColorMapType := Header[1];
      ImageType := Header[2];
      Width := WordAt(12);
      Height := WordAt(14);
      BitsPerPixel := Header[16];
      Descriptor := Header[17];

      if (ColorMapType <> 0) or not (ImageType in [2, 10]) or
         not (BitsPerPixel in [24, 32]) or (Width <= 0) or (Height <= 0) or
         (Width > MaxInt div Height) then
        Exit;

      PixelCount := Width * Height;
      if PixelCount > MaxInt div 4 then
        Exit;

      BytesPerPixel := BitsPerPixel div 8;
      TopOrigin := (Descriptor and $20) <> 0;
      RightOrigin := (Descriptor and $10) <> 0;
      SetLength(Pixels, PixelCount * 4);

      if Stream.Size < SizeOf(Header) + IDLength then
        Exit;
      Stream.Position := SizeOf(Header) + IDLength;

      PixelIndex := 0;
      if ImageType = 2 then
      begin
        while PixelIndex < PixelCount do
        begin
          if not ReadPixel(B, G, R, A) then
            Exit;
          StorePixel(PixelIndex, B, G, R, A);
          Inc(PixelIndex);
        end;
      end
      else
      begin
        while PixelIndex < PixelCount do
        begin
          if Stream.Read(PacketHeader, SizeOf(PacketHeader)) <> SizeOf(PacketHeader) then
            Exit;

          RunLength := (PacketHeader and $7F) + 1;
          if (PacketHeader and $80) <> 0 then
          begin
            if not ReadPixel(B, G, R, A) then
              Exit;

            for I := 0 to RunLength - 1 do
            begin
              if PixelIndex >= PixelCount then
                Exit;
              StorePixel(PixelIndex, B, G, R, A);
              Inc(PixelIndex);
            end;
          end
          else
          begin
            for I := 0 to RunLength - 1 do
            begin
              if PixelIndex >= PixelCount then
                Exit;
              if not ReadPixel(B, G, R, A) then
                Exit;
              StorePixel(PixelIndex, B, G, R, A);
              Inc(PixelIndex);
            end;
          end;
        end;
      end;

      Result := PixelIndex = PixelCount;
    finally
      Stream.Free;
    end;
  except
    Result := False;
  end;

  if not Result then
  begin
    Pixels := nil;
    Width := 0;
    Height := 0;
  end;
end;

function TryBuildParticlePreviewPixels(const SourcePixels: TBytes; SourceWidth,
  SourceHeight, ThumbSize: Integer; out ThumbPixels: TBytes): Boolean;
var
  X, Y, SrcX, SrcY, SrcIndex, DestIndex: Integer;
  AlphaValue, CheckerValue: Integer;
begin
  Result := False;
  ThumbPixels := nil;
  if (SourceWidth < 1) or (SourceHeight < 1) or (ThumbSize < 1) or
     (Length(SourcePixels) < SourceWidth * SourceHeight * 4) then
    Exit;

  SetLength(ThumbPixels, ThumbSize * ThumbSize * 4);
  for Y := 0 to ThumbSize - 1 do
    for X := 0 to ThumbSize - 1 do
    begin
      SrcX := System.Math.Min(SourceWidth - 1, (X * SourceWidth) div ThumbSize);
      SrcY := System.Math.Min(SourceHeight - 1, (Y * SourceHeight) div ThumbSize);
      SrcIndex := (SrcY * SourceWidth + SrcX) * 4;
      DestIndex := (Y * ThumbSize + X) * 4;

      if (((X div 8) + (Y div 8)) and 1) = 0 then
        CheckerValue := 50
      else
        CheckerValue := 88;

      AlphaValue := SourcePixels[SrcIndex + 3];
      ThumbPixels[DestIndex + 0] :=
        Byte((SourcePixels[SrcIndex + 0] * AlphaValue + CheckerValue * (255 - AlphaValue) + 127) div 255);
      ThumbPixels[DestIndex + 1] :=
        Byte((SourcePixels[SrcIndex + 1] * AlphaValue + CheckerValue * (255 - AlphaValue) + 127) div 255);
      ThumbPixels[DestIndex + 2] :=
        Byte((SourcePixels[SrcIndex + 2] * AlphaValue + CheckerValue * (255 - AlphaValue) + 127) div 255);
      ThumbPixels[DestIndex + 3] := 255;
    end;

  Result := True;
end;

function InspectorInputFloat(const LabelText: PAnsiChar; Value: System.PSingle;
  Step, MinValue, MaxValue: Single; const FormatText: PAnsiChar): Boolean; forward;
function InspectorInputFloat3(const LabelText: PAnsiChar; Value: System.PSingle;
  Step, MinValue, MaxValue: Single; const FormatText: PAnsiChar): Boolean; forward;
function InspectorInputInt(const LabelText: PAnsiChar; Value: System.PInteger;
  Step: Single; MinValue, MaxValue: Integer; const FormatText: PAnsiChar;
  Flags: ImGuiSliderFlags): Boolean; forward;

function TryReadMaterialPreviewFromStream(Stream: TStream; out MaterialName,
  PreviewTexturePath: string; out MaterialType: TMaterialType): Boolean;
var
  Magic: array[0..7] of AnsiChar;
  Version: Integer;
  MaterialTypeValue: Integer;
  TextureCount: Integer;
  TextureName: string;
  TexturePath: string;
  I: Integer;
  LowerName: string;
  CandidatePath: string;

  function IsAlbedoName(const AName: string): Boolean;
  begin
    Result := SameText(AName, 'albedoTexture') or
      SameText(Copy(AName, 1, Length('albedoTexture')), 'albedoTexture');
  end;
begin
  Result := False;
  MaterialName := '';
  PreviewTexturePath := '';
  MaterialType := mtPBR;

  if (Stream = nil) or ((Stream.Size - Stream.Position) < SizeOf(Magic)) then
    Exit;

  Stream.ReadBuffer(Magic[0], SizeOf(Magic));
  if not PreviewMagicMatches(Magic, MATERIAL_FILE_MAGIC_LOCAL) then
    Exit;

  Stream.ReadBuffer(Version, SizeOf(Version));
  if (Version < 1) or (Version > MATERIAL_FILE_VERSION_LOCAL) then
    Exit;

  MaterialName := ReadPreviewString(Stream);

  Stream.ReadBuffer(MaterialTypeValue, SizeOf(MaterialTypeValue));
  if (MaterialTypeValue >= Ord(Low(TMaterialType))) and
     (MaterialTypeValue <= Ord(High(TMaterialType))) then
    MaterialType := TMaterialType(MaterialTypeValue);

  Stream.Position := Stream.Position + SizeOf(Single);  // Gamma
  Stream.Position := Stream.Position + SizeOf(Integer); // Layers
  Stream.Position := Stream.Position + SizeOf(Single);  // Pivot
  Stream.Position := Stream.Position + SizeOf(Single);  // MetallicMult
  if Version >= 2 then
    Stream.Position := Stream.Position + SizeOf(Single); // SpecularLevel
  Stream.Position := Stream.Position + SizeOf(Single);  // HeightScale
  Stream.Position := Stream.Position + SizeOf(Single);  // AmbientShadowStrength
  if Version >= 3 then
    Stream.Position := Stream.Position + SizeOf(Single);  // HdrExposure
  if Version >= 4 then
    Stream.Position := Stream.Position + SizeOf(Single);  // AlphaCutoff

  Stream.ReadBuffer(TextureCount, SizeOf(TextureCount));
  if TextureCount < 0 then
    Exit;

  for I := 0 to TextureCount - 1 do
  begin
    TextureName := ReadPreviewString(Stream);
    TexturePath := ReadPreviewString(Stream);
    CandidatePath := TEnginePaths.ResolveAssetPath(TexturePath);
    LowerName := LowerCase(TextureName);

    if (PreviewTexturePath = '') and FileExists(CandidatePath) and
       (IsAlbedoName(LowerName) or (I = 0)) then
      PreviewTexturePath := CandidatePath;

    Stream.Position := Stream.Position + SizeOf(TVector3); // DiffuseColor
    Stream.Position := Stream.Position + SizeOf(TVector3); // SpecularColor
    Stream.Position := Stream.Position + SizeOf(Single);   // Shininess
  end;

  Result := True;
end;

{ TSandBoxForm }
constructor TSandBoxForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner, 0);

  Application.MainFormOnTaskbar := True;
  Caption := 'OpenGL Micro Engine';
  Width := Screen.Width;
  Height := Screen.Height;
  Top := 0;
  Left := 0;

  Position := poScreenCenter;
  DoubleBuffered := False;
  KeyPreview := True;
  BorderStyle := bsSizeable;
  WindowState := wsMaximized;

  OnResize := FormResizeHandler;
  OnClose := FormCloseHandler;
  OnMouseWheel := FormMouseWheelHandler;
  OnMouseDown := FormMouseDownHandler;
  OnMouseMove := FormMouseMoveHandler;
  OnMouseUp := FormMouseUpHandler;
  OnKeyDown := EditorShortcutKeyDown;
  OnKeyUp := EditorShortcutKeyUp;
  OnKeyPress := EditorShortcutKeyPress;

  InitializeEditor;
end;

destructor TSandBoxForm.Destroy;
begin
  ShutdownEditor;
  inherited Destroy;
end;

procedure TSandBoxForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);

  { Force the editor host onto the taskbar even though it is a CreateNew/no-DFM form. }
  Params.WndParent := 0;
  Params.ExStyle := Params.ExStyle or WS_EX_APPWINDOW;
end;

procedure TSandBoxForm.InitializeEditor;
var
  EngineSettings: TEngineSettings;
begin
  DisableFloatingPointExceptions;

  PATH := ExtractFilePath(Application.ExeName);
  GLSL_PATH := IncludeTrailingPathDelimiter(PATH) + 'Data\GLSL\';

  TEnginePaths.Initialize(PATH);
  TEnginePaths.EnsureDirectories;

  fLog := TStringList.Create;
  fSelectedMeshIndex := -1;
  fSelectedParticleSystemIndex := -1;
  fSelectedBillboardIndex := -1;
  fSelectedAnimatedSpriteIndex := -1;
  fSelectedAudioEmitterIndex := -1;
  fAnimationBlendDuration := 0.2;
  fGizmoMode := gmTranslate;
  fBuiltGizmoMode := gmTranslate;
  fHoveredAxis := -1;
  fDraggedAxis := -1;
  fGizmoClonePending := False;
  fGizmoCloneSource := nil;
  fDragAxisMask := 0;
  fDragPlaneNormal := Vector3(0, 0, 1);
  fDragStartPlaneHit := Vector3(0, 0, 0);
  fEditSelectedMeshTransform := False;
  fMaterialEditor.Active := False;
  fMaterialEditor.SelectedLibraryIndex := -1;
  fMaterialEditor.SelectedMaterialIndex := -1;
  fMaterialEditor.SelectedTextureIndex := -1;
  SetAnsiBuffer(fMaterialEditor.NewLibraryName, 'MaterialLibrary');
  SetAnsiBuffer(fMaterialEditor.NewMaterialName, 'Material');
  fMaterialEditor.NewMaterialType := 0;
  fTextureBrowser.Active := False;
  fTextureBrowser.NeedsRefresh := False;
  fTextureBrowser.SelectedIndex := -1;
  fTextureBrowser.LibraryIndex := -1;
  fTextureBrowser.MaterialIndex := -1;
  fTextureBrowser.TextureIndex := -1;
  SetAnsiBuffer(fTextureBrowser.Search, '');
  fMaterialFileBrowser.Active := False;
  fMaterialFileBrowser.NeedsRefresh := False;
  fMaterialFileBrowser.Mode := mfbNone;
  fMaterialFileBrowser.SelectedIndex := -1;
  SetAnsiBuffer(fMaterialFileBrowser.Search, '');
  SetAnsiBuffer(fMaterialFileBrowser.FileName, '');
  fModelFileBrowser.Active := False;
  fModelFileBrowser.CreateAsObject := True;
  fModelFileBrowser.CreateWindTree := False;
  fModelFileBrowser.AutoPlayFirstAnimation := True;
  fModelFileBrowser.NeedsRefresh := False;
  fModelFileBrowser.SelectedIndex := -1;
  fModelFileBrowser.LastError := '';
  SetAnsiBuffer(fModelFileBrowser.Search, '');
  fSceneFileBrowser.Active := False;
  fSceneFileBrowser.NeedsRefresh := False;
  fSceneFileBrowser.Mode := sfbNone;
  fSceneFileBrowser.SelectedIndex := -1;
  SetAnsiBuffer(fSceneFileBrowser.Search, '');
  SetAnsiBuffer(fSceneFileBrowser.FileName, '');
  fParticleFileBrowser.Active := False;
  fParticleFileBrowser.NeedsRefresh := False;
  fParticleFileBrowser.Mode := pfbNone;
  fParticleFileBrowser.SelectedIndex := -1;
  SetAnsiBuffer(fParticleFileBrowser.Search, '');
  SetAnsiBuffer(fParticleFileBrowser.FileName, '');
  fPrefabFileBrowser.Active := False;
  fPrefabFileBrowser.NeedsRefresh := False;
  fPrefabFileBrowser.Mode := prefabNone;
  fPrefabFileBrowser.SelectedIndex := -1;
  fPrefabFileBrowser.PendingOverwrite := False;
  fPrefabFileBrowser.PendingOverwriteFileName := '';
  fPrefabFileBrowser.LastError := '';
  SetAnsiBuffer(fPrefabFileBrowser.Search, '');
  SetAnsiBuffer(fPrefabFileBrowser.FileName, '');
  fParticleTextureBrowser.Active := False;
  fParticleTextureBrowser.NeedsRefresh := False;
  fParticleTextureBrowser.SelectedIndex := -1;
  SetAnsiBuffer(fParticleTextureBrowser.Search, '');
  fBillboardTextureBrowser.Active := False;
  fBillboardTextureBrowser.NeedsRefresh := False;
  fBillboardTextureBrowser.SelectedIndex := -1;
  SetAnsiBuffer(fBillboardTextureBrowser.Search, '');
  fAudioTest.NeedsRefresh := True;
  fAudioTest.SelectedIndex := -1;
  fAudioTest.Loop := False;
  fAudioTest.Volume := 1.0;
  fAudioTest.MasterVolume := 1.0;
  fAudioTest.LastError := '';
  SetAnsiBuffer(fAudioTest.Search, '');
  SetAnsiBuffer(fAudioTest.FileName, '');
  fScriptEditor.NeedsFileRefresh := True;
  fScriptEditor.SelectedFileIndex := -1;
  fScriptEditor.SelectedIndex := -1;
  fScriptEditor.PendingOverwrite := False;
  fScriptEditor.PendingOverwriteKind := sowNone;
  fScriptEditor.PendingOverwriteFileName := '';
  ResetScriptSourceEditorTracking;
  fScriptEditor.Status := '';
  fScriptEditor.LastError := '';
  fScriptEditor.Dirty := False;
  fRunningScriptLifecycleEvent := False;
  fLastScriptLifecycleError := '';
  SetAnsiBuffer(fScriptEditor.Search, '');
  SetAnsiBuffer(fScriptEditor.NewScriptName, 'Script');
  SetAnsiBuffer(fScriptEditor.Name, '');
  SetAnsiBuffer(fScriptEditor.Description, '');
  SetAnsiBuffer(fScriptEditor.Author, '');
  SetAnsiBuffer(fScriptEditor.Category, '');
  SetAnsiBuffer(fScriptEditor.VersionText, '1.0');
  SetAnsiBuffer(fScriptEditor.EntryPoint, 'Main');
  SetAnsiBuffer(fScriptEditor.TargetName, '');
  SetAnsiBuffer(fScriptEditor.LibraryFileName,
    ChangeFileExt('ScriptLibrary', SCRIPT_LIBRARY_FILE_EXTENSION_LOCAL));
  SetAnsiBuffer(fScriptEditor.AssetFileName,
    ChangeFileExt('Script', SCRIPT_ASSET_FILE_EXTENSION_LOCAL));
  SetAnsiBuffer(fScriptEditor.Source, DefaultScriptSource);

  EngineSettings := TEngineSettings.Default;
  EngineSettings.Width := EditorViewportWidth;
  EngineSettings.Height := EditorViewportHeight;
  EngineSettings.AntialiasingSamples := 16;
  fEngine := TGameEngine.Create(Self, EngineSettings);
  fEngine.SetScriptPrefabCallbacks(LoadPrefabForScript, DestroyPrefabForScript);
  fEngine.SetScriptLogCallback(LogLine);
  fRenderer := fEngine.Renderer;
  fSceneManager := fEngine.SceneManager;
  fRoot := fEngine.Root;
  fSceneWorld := fEngine.SceneWorld;
  fLight := fEngine.MainLight;
  fCamera := fEngine.Camera;
  fPhysicsWorld := fEngine.PhysicsWorld;
  fAudioEngine := fEngine.AudioEngine;
  fScriptManager := fEngine.ScriptManager;
  MaterialLibraries := fEngine.MaterialLibraries;
  fShader := fEngine.DefaultShader;
  fActorShader := fEngine.ActorShader;
  fTreeLeafShader := fEngine.TreeLeafShader;
  fTreeTrunkShader := fEngine.TreeTrunkShader;
  fHeightFieldShader := fEngine.HeightFieldShader;

  fImGui := TEditorImGuiBackend.Create;
  ApplyImGuiStyle;
  fUseImGuiEditor := True;
  fShowImGuiDemo := False;
  fShowPostEffects := False;
  fShowSkyDome := False;
  fShowSelectedBounds := True;
  fShowPhysics := False;
  fShowAudioTest := False;
  fShowScriptEditor := False;
  fRenderTextureTool.Active := False;
  fRenderTextureTool.Pending := False;
  fRenderTextureTool.Width := 1024;
  fRenderTextureTool.Height := 1024;
  fRenderTextureTool.AntialiasingSamples := 4;
  SetAnsiBuffer(fRenderTextureTool.FileName, 'RenderTexture.png');
  fRenderTextureTool.LastOutputFileName := '';
  fRenderTextureTool.LastError := '';
  fPhysicsRunning := False;
  fPhysicsStatusMessage := '';
  fParticleEditorActive := False;
  fParticleEditorExpandAllOnNextOpen := False;
  fImGuiMouseCaptured := False;
  fImGuiKeyboardCaptured := False;
  fImGuiMouseBlockScene := False;
  fRenderer.OnBeforeSceneRender := RenderEditorGrid;
  fRenderer.OnBeforePresent := RenderImGuiEditor;

  LogLine('Vendor: ' + string(glGetString(GL_VENDOR)));
  LogLine('Renderer: ' + string(glGetString(GL_RENDERER)));
  LogLine('Version: ' + string(glGetString(GL_VERSION)));

  fGizmoShader := TShader.Create(TEnginePaths.Shader('Gizmo.vert'),
    TEnginePaths.Shader('Gizmo.frag'));
  fGrid := T3DGrid.Create(TEnginePaths.Shader('Grid.vert'),
    TEnginePaths.Shader('Grid.frag'));

  fGizmoShader.OnUpdateShader := OnUpdateGizmoShader;

  fRenderer.LoadEmptyObjectMarkerShaderFromFile(TEnginePaths.Shader('EmptyObjectMarker.vert'),
    TEnginePaths.Shader('EmptyObjectMarker.frag'));
  EnsureGizmoMaterial;
  EnsureLightBillboard(fLight);
  fSelectedObject := fSceneWorld;
  fSelectedMesh := nil;
  fSelectedMeshIndex := -1;
  fSelectedParticleSystemIndex := -1;
  fSelectedBillboardIndex := -1;
  fSelectedAnimatedSpriteIndex := -1;
  fSelectedAudioEmitterIndex := -1;

  fFOVRadians := DegToRad(60.0);
  SyncOrbitFromCamera;

  fRotateSpeed := 0.003;
  fZoomSpeed := 0.90;
  fPanSpeed := 0.0005;
  fCameraMoveSpeed := 8.0;
  fMouseDown := False;
  fRightMouseDownPos := Point(0, 0);
  fRightMouseDragMoved := False;
  fViewportObjectPopupPending := False;
  fViewportObjectPopupPos := Point(0, 0);
  fViewportObjectPopupObject := nil;
  fPanActive := False;

  FormResizeHandler(Self);

  Timer := TEngineTimer.Create;
  Timer.Enabled := False;
  Timer.OnProgress := DoProgress;
  Timer.Mode := tmASAP;
  Timer.Enabled := True;

  LogLine('Dear ImGui editor initialized.');
end;

procedure TSandBoxForm.ShutdownEditor;
begin
  if Assigned(Timer) then
  begin
    Timer.Enabled := False;
    Timer.OnProgress := nil;
    FreeAndNil(Timer);
  end;

  if Assigned(fLog) then
  begin
    try
      fLog.SaveToFile(IncludeTrailingPathDelimiter(PATH) + 'Log.txt');
    except
      // Do not raise during form destruction.
    end;
  end;

  if Assigned(fCurrentGizmo) then
    FreeAndNil(fCurrentGizmo);
  FreeAndNil(fObjectClipboard);

  if Assigned(fRenderer) then
    fRenderer.ActivateContext;

  ClearHeightFieldMapPreviews;
  ClearTextureBrowserPreviews;
  ClearMaterialFilePreviews;
  ClearParticleTexturePreviews;
  ClearBillboardTexturePreviews;
  ClearParticleFilePreviews;

  fAudioTestSound := nil;
  FreeAndNil(fImGui);
  FreeAndNil(fGrid);
  FreeAndNil(fGizmoMaterialLibrary);
  FreeAndNil(fGizmoShader);
  FreeAndNil(fEngine);
  fRenderer := nil;
  fSceneManager := nil;
  fRoot := nil;
  fSceneWorld := nil;
  fLight := nil;
  fCamera := nil;
  fPhysicsWorld := nil;
  fAudioEngine := nil;
  fScriptManager := nil;
  MaterialLibraries := nil;
  fShader := nil;
  fActorShader := nil;
  fTreeLeafShader := nil;
  fTreeTrunkShader := nil;
  fHeightFieldShader := nil;
  FreeAndNil(fLog);
end;

procedure TSandBoxForm.BuildDefaultScene;
begin
  if fEngine = nil then
    Exit;

  ReleaseCurrentGizmo;
  fEngine.ResetScene;
  fSceneManager := fEngine.SceneManager;
  fRoot := fEngine.Root;
  fSceneWorld := fEngine.SceneWorld;
  fLight := fEngine.MainLight;
  fCamera := fEngine.Camera;
  fPhysicsWorld := fEngine.PhysicsWorld;
  MaterialLibraries := fEngine.MaterialLibraries;
  EnsureLightBillboard(fLight);
  SyncOrbitFromCamera;

  // Start with an empty scene. Objects/meshes are now created from the ImGui
  // +Object / +Mesh menus instead of spawning a cube automatically.
  fSelectedObject := fSceneWorld;
  fSelectedMesh := nil;
  fSelectedMeshIndex := -1;
  fSelectedParticleSystemIndex := -1;
  fSelectedBillboardIndex := -1;
  fSelectedAnimatedSpriteIndex := -1;
  fSelectedAudioEmitterIndex := -1;

  ResetScriptEditorForSceneChange;

  RefreshGizmo;
end;

procedure TSandBoxForm.CreateDefaultScene;
begin
  BuildDefaultScene;
end;

procedure TSandBoxForm.ClearSceneObjects;
begin
  fPhysicsRunning := False;

  ReleaseCurrentGizmo;

  if fEngine <> nil then
  begin
    fEngine.ClearSceneObjects;
    fRoot := fEngine.Root;
    fSceneWorld := fEngine.SceneWorld;
    fLight := fEngine.MainLight;
    fCamera := fEngine.Camera;
  end;

  fSelectedObject := nil;
  fSelectedMesh := nil;
  fSelectedMeshIndex := -1;
  fSelectedParticleSystemIndex := -1;
  fSelectedBillboardIndex := -1;
  fSelectedAnimatedSpriteIndex := -1;
  fSelectedAudioEmitterIndex := -1;
end;

function TSandBoxForm.EditorViewportWidth: Integer;
begin
  Result := ClientWidth;
end;

function TSandBoxForm.EditorViewportHeight: Integer;
begin
  Result := ClientHeight;
end;

procedure TSandBoxForm.ActivateMainRenderContext;
begin
  if fEngine <> nil then
    fEngine.ActivateRenderContext;
end;

procedure TSandBoxForm.ReleaseCurrentGizmo;
begin
  ActivateMainRenderContext;

  if Assigned(fCurrentGizmo) then
    FreeAndNil(fCurrentGizmo);

  fGizmoOwner := nil;
  fHoveredAxis := -1;
  fDraggingGizmo := False;
  fDraggedAxis := -1;
  fGizmoClonePending := False;
  fGizmoCloneSource := nil;
end;

procedure TSandBoxForm.RequestRender;
begin
  fRenderRequested := True;

  if fInImGuiFrame then
    Exit;

  if fEngine <> nil then
  begin
    fRenderRequested := False;
    fEngine.Render;
  end;
end;

procedure TSandBoxForm.LogLine(const Text: string);
begin
  if fLog = nil then
    Exit;

  fLog.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + Text);
end;

function TSandBoxForm.ImGuiWantsKeyboardCapture: Boolean;
begin
  Result := False;

  if (not fUseImGuiEditor) or (fImGui = nil) then
    Exit;

  Result := fImGuiKeyboardCaptured or fImGui.WantCaptureKeyboard;

  if fInImGuiFrame then
    Result := Result or ImGui.IsAnyItemActive;
end;

function TSandBoxForm.ImGuiBlocksSceneMouse: Boolean;
begin
  Result := False;

  if (not fUseImGuiEditor) or (fImGui = nil) then
    Exit;

  Result := fImGuiMouseBlockScene or fImGuiMouseCaptured or
    fImGui.WantCaptureMouse;

  if fInImGuiFrame then
    Result := Result or fImGui.MouseOverUi;
end;

procedure TSandBoxForm.UpdateImGuiCaptureState;
begin
  if (not fUseImGuiEditor) or (fImGui = nil) then
  begin
    fImGuiKeyboardCaptured := False;
    fImGuiMouseBlockScene := False;
    Exit;
  end;

  fImGuiKeyboardCaptured := fImGui.WantCaptureKeyboard or
    ImGui.IsAnyItemActive;
  fImGuiMouseBlockScene := fImGui.WantCaptureMouse or fImGui.MouseOverUi;
end;

function TSandBoxForm.IsEditorOnlyMaterial(AMaterial: TMaterial): Boolean;
begin
  Result := (AMaterial = nil) or SameText(AMaterial.Name, GIZMO_MATERIAL_NAME) or
    (AMaterial.Materialtype = mtShadow);
end;

function TSandBoxForm.EnsureDefaultMaterialLibrary: TMaterialLibrary;
begin
  if fEngine <> nil then
    Exit(fEngine.EnsureDefaultMaterialLibrary);

  if MaterialLibraries = nil then
    MaterialLibraries := TMaterialLibraries.Create;

  if MaterialLibraries.Count = 0 then
    MaterialLibraries.CreateMaterialLibrary('fDefaultMaterialLib');

  Result := MaterialLibraries.MaterialLibrary[0];
  if Result = nil then
  begin
    Result := TMaterialLibrary.Create;
    MaterialLibraries.MaterialLibrary[0] := Result;
  end;

  if Result.Name = '' then
    Result.Name := 'fDefaultMaterialLib';
end;

function TSandBoxForm.DefaultRenderableMaterialName: string;
var
  Lib: TMaterialLibrary;
  I: Integer;
begin
  if fEngine <> nil then
    Exit(fEngine.DefaultRenderableMaterialName);

  Result := '';
  Lib := EnsureDefaultMaterialLibrary;
  if Lib = nil then
    Exit;

  for I := 0 to Lib.Count - 1 do
    if Assigned(Lib.Material[I]) and not IsEditorOnlyMaterial(Lib.Material[I]) then
      Exit(Lib.Material[I].Name);
end;

procedure TSandBoxForm.AssignShaderToMaterial(AMaterial: TMaterial);
begin
  if AMaterial = nil then
    Exit;

  if SameText(AMaterial.Name, GIZMO_MATERIAL_NAME) then
    AMaterial.Shader := fGizmoShader
  else if fEngine <> nil then
    fEngine.AssignShaderToMaterial(AMaterial)
  else
    AMaterial.Shader := ShaderForMaterialType(AMaterial.Materialtype);
end;

procedure TSandBoxForm.EnsureGizmoMaterial;
var
  Lib: TMaterialLibrary;
  Mat: TMaterial;
  I: Integer;
  GizmoIndex: Integer;
begin
  if fGizmoMaterialLibrary = nil then
  begin
    fGizmoMaterialLibrary := TMaterialLibrary.Create;
    fGizmoMaterialLibrary.Name := 'fEditorGizmoMaterialLib';
  end;
  Lib := fGizmoMaterialLibrary;

  Mat := nil;
  GizmoIndex := -1;

  for I := 0 to Lib.Count - 1 do
    if Assigned(Lib.Material[I]) and SameText(Lib.Material[I].Name, GIZMO_MATERIAL_NAME) then
    begin
      Mat := Lib.Material[I];
      GizmoIndex := I;
      Break;
    end;

  if Mat = nil then
  begin
    Mat := TMaterial.Create(mtPBR);
    Mat.Name := GIZMO_MATERIAL_NAME;
    GizmoIndex := Lib.AddMaterial(Mat);
  end;

  Mat.Name := GIZMO_MATERIAL_NAME;
  Mat.Materialtype := mtPBR;
  Mat.Shader := fGizmoShader;

  while GizmoIndex > 0 do
  begin
    Lib.ExchangeMaterials(GizmoIndex, GizmoIndex - 1);
    Dec(GizmoIndex);
  end;
end;

procedure TSandBoxForm.LoadDefaultTextures;
var
  Lib: TMaterialLibrary;
  Mat: TMaterial;
begin
  if fEngine <> nil then
    Exit;

  Lib := EnsureDefaultMaterialLibrary;
  if Lib = nil then
    Exit;

  if Lib.GetMaterial(DEFAULT_PBR_MATERIAL_NAME) = nil then
  begin
    Mat := TMaterial.Create(mtPBR);
    try
      Mat.Name := DEFAULT_PBR_MATERIAL_NAME;
      Mat.Shader := fShader;
      AddDefaultPBRTextures(Mat);
      Lib.AddMaterial(Mat);
      Mat := nil;
    finally
      Mat.Free;
    end;
  end;

end;

function TSandBoxForm.ShaderForMaterialType(AMaterialType: TMaterialType): TShader;
begin
  if fEngine <> nil then
    Exit(fEngine.ShaderForMaterialType(AMaterialType));

  case AMaterialType of
    mtActor:
      Result := fActorShader;
    mtTreeLeaf:
      Result := fTreeLeafShader;
    mtTreeTrunk:
      Result := fTreeTrunkShader;
    mtHeightFieldMaterial:
      Result := fHeightFieldShader;
  else
    Result := fShader;
  end;
end;

procedure TSandBoxForm.GetTextureLoadParams(const AUniformName: string;
  out AMipMap: Boolean; out AInternalFormat, AParam: GLint;
  out AInvertNormals: Boolean);
var
  U: string;

  function HasPrefix(const APrefix: string): Boolean;
  begin
    Result := Copy(U, 1, Length(APrefix)) = APrefix;
  end;

  function IsTerrainAlphaTextureName: Boolean;
  begin
    Result :=
      HasPrefix('alphatexture') or
      HasPrefix('alphatextures[') or
      HasPrefix('masktexture') or
      HasPrefix('masktextures[') or
      HasPrefix('blendtexture') or
      HasPrefix('blendtextures[') or
      HasPrefix('blendmap') or
      HasPrefix('blendmaps[') or
      HasPrefix('splatmap') or
      HasPrefix('splatmaps[');
  end;
begin
  U := LowerCase(AUniformName);

  AMipMap := True;
  AInternalFormat := GL_RGBA8;
  AParam := GL_REPEAT;
  AInvertNormals := False;

  if (U = LowerCase('albedoTexture')) or
     (Copy(U, 1, Length('albedotexture')) = 'albedotexture') or
     (Copy(U, 1, Length('albedotextures[')) = 'albedotextures[') then
    AInternalFormat := GL_SRGB8_ALPHA8
  else if IsTerrainAlphaTextureName then
  begin
    AMipMap := False;
    AParam := GL_CLAMP_TO_EDGE;
  end
  else if U = LowerCase('specularBRDF_LUT') then
  begin
    AMipMap := False;
    AParam := GL_CLAMP_TO_EDGE;
  end;
end;

procedure TSandBoxForm.AddDefaultPBRTextures(AMaterial: TMaterial);
var
  I: Integer;
  Tex: TArray<TMaterialTexture>;

  procedure LoadTex(Index: Integer; const FileName, UniformName: string;
    SRGB: Boolean; InternalFormat: GLint; WrapMode: GLint);
  begin
    if Tex[Index].LoadTexTGA(TEnginePaths.Texture(FileName), SRGB, UniformName,
      InternalFormat, WrapMode, False) then
      LogLine('Texture loaded: Data\Tex\' + FileName)
    else
      LogLine('Texture missing or failed: Data\Tex\' + FileName);
  end;
begin
  if AMaterial = nil then
    Exit;

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

  AMaterial.AddTextures(Tex);
end;

procedure TSandBoxForm.AddDefaultTreeLeafTextures(AMaterial: TMaterial);
var
  I: Integer;
  Tex: TArray<TMaterialTexture>;

  procedure LoadTex(Index: Integer; const FileName, UniformName: string;
    InternalFormat: GLint);
  begin
    if Tex[Index].LoadTexTGA(TEnginePaths.Texture(FileName), True, UniformName,
      InternalFormat, GL_REPEAT, False) then
      LogLine('Texture loaded: Data\Tex\' + FileName)
    else
      LogLine('Texture missing or failed: Data\Tex\' + FileName);
  end;
begin
  if AMaterial = nil then
    Exit;

  SetLength(Tex, 3);
  for I := 0 to High(Tex) do
  begin
    Tex[I].Texture.DiffuseColor := Vector3(0.5, 0.65, 0.35);
    Tex[I].Texture.SpecularColor := Vector3(0.55, 0.6, 0.5);
    Tex[I].Texture.Shininess := 48.0;
  end;

  LoadTex(0, 'DefaultColor.tga', 'albedoTexture', GL_SRGB8_ALPHA8);
  LoadTex(1, 'DefaultNormal.tga', 'normalTexture', GL_RGBA8);
  LoadTex(2, 'DefaultEdge.tga', 'specularTexture', GL_RGBA8);

  AMaterial.AddTextures(Tex);
end;

procedure TSandBoxForm.AddDefaultTreeTrunkTextures(AMaterial: TMaterial);
var
  I: Integer;
  Tex: TArray<TMaterialTexture>;

  procedure LoadTex(Index: Integer; const FileName, UniformName: string;
    InternalFormat: GLint);
  begin
    if Tex[Index].LoadTexTGA(TEnginePaths.Texture(FileName), True, UniformName,
      InternalFormat, GL_REPEAT, False) then
      LogLine('Texture loaded: Data\Tex\' + FileName)
    else
      LogLine('Texture missing or failed: Data\Tex\' + FileName);
  end;
begin
  if AMaterial = nil then
    Exit;

  SetLength(Tex, 4);
  for I := 0 to High(Tex) do
  begin
    Tex[I].Texture.DiffuseColor := Vector3(0.42, 0.28, 0.16);
    Tex[I].Texture.SpecularColor := Vector3(0.4, 0.4, 0.4);
    Tex[I].Texture.Shininess := 32.0;
  end;

  LoadTex(0, 'DefaultColor.tga', 'albedoTexture', GL_SRGB8_ALPHA8);
  LoadTex(1, 'DefaultNormal.tga', 'normalTexture', GL_RGBA8);
  LoadTex(2, 'DefaultEdge.tga', 'specularTexture', GL_RGBA8);
  LoadTex(3, 'DefaultAmbient.tga', 'ambientOcclusionTexture', GL_RGBA8);

  AMaterial.AddTextures(Tex);
end;

procedure TSandBoxForm.AddDefaultHeightFieldTextures(AMaterial: TMaterial);
var
  I: Integer;
  Tex: TArray<TMaterialTexture>;

  procedure LoadTex(Index: Integer; const FileName, UniformName: string;
    InternalFormat: GLint);
  begin
    if Tex[Index].LoadTexTGA(TEnginePaths.Texture(FileName), True, UniformName,
      InternalFormat, GL_REPEAT, False) then
      LogLine('Texture loaded: Data\Tex\' + FileName)
    else
      LogLine('Texture missing or failed: Data\Tex\' + FileName);
  end;
begin
  if AMaterial = nil then
    Exit;

  SetLength(Tex, 30);
  for I := 0 to High(Tex) do
  begin
    Tex[I].Texture.DiffuseColor := Vector3(0.5, 0.5, 0.5);
    Tex[I].Texture.SpecularColor := Vector3(1.0, 1.0, 1.0);
    Tex[I].Texture.Shininess := 64.0;
  end;

  LoadTex(0, 'DefaultColor.tga', 'alphaTexture0', GL_RGBA8);
  LoadTex(1, 'DefaultMetallic.tga', 'alphaTexture1', GL_RGBA8);
  LoadTex(2, 'DefaultMetallic.tga', 'alphaTexture2', GL_RGBA8);
  LoadTex(3, 'DefaultMetallic.tga', 'alphaTexture3', GL_RGBA8);
  LoadTex(4, 'DefaultMetallic.tga', 'alphaTexture4', GL_RGBA8);

  LoadTex(5, 'DefaultColor.tga', 'albedoTexture0', GL_SRGB8_ALPHA8);
  LoadTex(6, 'DefaultColor.tga', 'albedoTexture1', GL_SRGB8_ALPHA8);
  LoadTex(7, 'DefaultColor.tga', 'albedoTexture2', GL_SRGB8_ALPHA8);
  LoadTex(8, 'DefaultColor.tga', 'albedoTexture3', GL_SRGB8_ALPHA8);
  LoadTex(9, 'DefaultColor.tga', 'albedoTexture4', GL_SRGB8_ALPHA8);

  LoadTex(10, 'DefaultNormal.tga', 'normalTexture0', GL_RGBA8);
  LoadTex(11, 'DefaultNormal.tga', 'normalTexture1', GL_RGBA8);
  LoadTex(12, 'DefaultNormal.tga', 'normalTexture2', GL_RGBA8);
  LoadTex(13, 'DefaultNormal.tga', 'normalTexture3', GL_RGBA8);
  LoadTex(14, 'DefaultNormal.tga', 'normalTexture4', GL_RGBA8);

  LoadTex(15, 'DefaultHeight.tga', 'heightTexture0', GL_RGBA8);
  LoadTex(16, 'DefaultHeight.tga', 'heightTexture1', GL_RGBA8);
  LoadTex(17, 'DefaultHeight.tga', 'heightTexture2', GL_RGBA8);
  LoadTex(18, 'DefaultHeight.tga', 'heightTexture3', GL_RGBA8);
  LoadTex(19, 'DefaultHeight.tga', 'heightTexture4', GL_RGBA8);

  LoadTex(20, 'DefaultMetallic.tga', 'metalnessTexture0', GL_RGBA8);
  LoadTex(21, 'DefaultMetallic.tga', 'metalnessTexture1', GL_RGBA8);
  LoadTex(22, 'DefaultMetallic.tga', 'metalnessTexture2', GL_RGBA8);
  LoadTex(23, 'DefaultMetallic.tga', 'metalnessTexture3', GL_RGBA8);
  LoadTex(24, 'DefaultMetallic.tga', 'metalnessTexture4', GL_RGBA8);

  LoadTex(25, 'DefaultRoughness.tga', 'roughnessTexture0', GL_RGBA8);
  LoadTex(26, 'DefaultRoughness.tga', 'roughnessTexture1', GL_RGBA8);
  LoadTex(27, 'DefaultRoughness.tga', 'roughnessTexture2', GL_RGBA8);
  LoadTex(28, 'DefaultRoughness.tga', 'roughnessTexture3', GL_RGBA8);
  LoadTex(29, 'DefaultRoughness.tga', 'roughnessTexture4', GL_RGBA8);

  AMaterial.AddTextures(Tex);
end;

function TSandBoxForm.TextureDisplayName(const ATex: TMaterialTexture;
  AIndex: Integer): string;
begin
  Result := Trim(ATex.Texture.Name);

  if SameText(Result, 'irradianceTexture') or
     SameText(Result, 'ambientTexture') then
    Result := 'ambientOcclusionTexture';

  if Result = '' then
    Result := ExtractFileName(ATex.Path);

  if Result = '' then
    Result := Format('Texture_%.2d', [AIndex + 1]);
end;

function TSandBoxForm.MaterialTypeDisplayName(AMaterialType: TMaterialType): string;
begin
  case AMaterialType of
    mtActor: Result := 'Actor';
    mtTreeLeaf: Result := 'Tree Leaf';
    mtTreeTrunk: Result := 'Tree Trunk';
    mtHeightFieldMaterial: Result := 'Terrain';
    mtShadow: Result := 'Shadow';
  else
    Result := 'PBR';
  end;
end;

function TSandBoxForm.MakeUniqueMaterialLibraryName(const BaseName: string): string;
var
  Prefix: string;
  Candidate: string;
  Index: Integer;
begin
  Result := Trim(BaseName);
  if Result = '' then
    Result := 'MaterialLibrary';

  if (MaterialLibraries = nil) or (MaterialLibraries.IndexOf(Result) < 0) then
    Exit(Result);

  Prefix := Result;
  Index := 1;
  repeat
    Candidate := Format('%s_%.2d', [Prefix, Index]);
    Inc(Index);
  until (MaterialLibraries = nil) or (MaterialLibraries.IndexOf(Candidate) < 0);

  Result := Candidate;
end;

function TSandBoxForm.MakeUniqueMaterialName(ALib: TMaterialLibrary;
  const BaseName: string): string;
var
  Prefix: string;
  Candidate: string;
  Index: Integer;
begin
  Result := Trim(BaseName);
  if Result = '' then
    Result := 'Material';

  if (ALib = nil) or (ALib.GetMaterial(Result) = nil) then
    Exit(Result);

  Prefix := Result;
  Index := 1;
  repeat
    Candidate := Format('%s_%.2d', [Prefix, Index]);
    Inc(Index);
  until (ALib = nil) or (ALib.GetMaterial(Candidate) = nil);

  Result := Candidate;
end;

function TSandBoxForm.CreateMaterialLibraryWithDefaultMaterial(
  const BaseName: string): TMaterialLibrary;
var
  Mat: TMaterial;
begin
  if MaterialLibraries = nil then
    MaterialLibraries := TMaterialLibraries.Create;

  Result := TMaterialLibrary.Create;
  Result.Name := MakeUniqueMaterialLibraryName(BaseName);

  Mat := TMaterial.Create(mtPBR);
  Mat.Name := DEFAULT_PBR_MATERIAL_NAME;
  AssignShaderToMaterial(Mat);
  AddDefaultPBRTextures(Mat);
  Result.AddMaterial(Mat);

  MaterialLibraries.AddMaterialLibrary(Result);
end;

procedure TSandBoxForm.ReplaceMaterialReferencesInScene(ALib: TMaterialLibrary;
  const OldName, NewName: string);

  procedure VisitObject(Obj: TSceneObject);
  var
    I: Integer;
    Mesh: TMesh;
    Meshes: TMeshList;
  begin
    if Obj = nil then
      Exit;

    Meshes := Obj.EffectiveMeshList;
    if Assigned(Meshes) then
    for I := 0 to Meshes.Count - 1 do
    begin
      Mesh := Meshes.Item[I];
      if (Mesh <> nil) and (Mesh.MaterialLibrary = ALib) and
         SameText(Mesh.LibMaterialname, OldName) then
      begin
        Mesh.LibMaterialname := NewName;
        Mesh.OnRender := MeshRenderHandler;
      end;
    end;

    for I := 0 to Obj.Count - 1 do
      VisitObject(Obj.ObjectList[I]);
  end;
begin
  if (ALib = nil) or SameText(OldName, NewName) then
    Exit;

  VisitObject(fRoot);

  if Assigned(fSelectedObject) then
    fSelectedObject.NotifyChange;

  if Assigned(fSceneManager) then
    fSceneManager.Update;
end;

procedure TSandBoxForm.ReplaceLibraryReferencesInScene(OldLib, NewLib: TMaterialLibrary;
  const NewMaterialName: string);

  procedure VisitObject(Obj: TSceneObject);
  var
    I: Integer;
    Mesh: TMesh;
    Meshes: TMeshList;
  begin
    if Obj = nil then
      Exit;

    Meshes := Obj.EffectiveMeshList;
    if Assigned(Meshes) then
    for I := 0 to Meshes.Count - 1 do
    begin
      Mesh := Meshes.Item[I];
      if (Mesh <> nil) and (Mesh.MaterialLibrary = OldLib) then
      begin
        Mesh.MaterialLibrary := NewLib;
        Mesh.LibMaterialname := NewMaterialName;
        Mesh.OnRender := MeshRenderHandler;
      end;
    end;

    for I := 0 to Obj.Count - 1 do
      VisitObject(Obj.ObjectList[I]);
  end;
begin
  if (OldLib = nil) or (NewLib = nil) then
    Exit;

  VisitObject(fRoot);

  if Assigned(fSelectedObject) then
    fSelectedObject.NotifyChange;

  if Assigned(fSceneManager) then
    fSceneManager.Update;
end;

function TSandBoxForm.SceneUsesMaterialLibrary(ALib: TMaterialLibrary): Boolean;

  function VisitObject(Obj: TSceneObject): Boolean;
  var
    I: Integer;
    Mesh: TMesh;
    Meshes: TMeshList;
  begin
    Result := False;
    if Obj = nil then
      Exit;
    if Obj.IsGizmo then
      Exit;

    Meshes := Obj.EffectiveMeshList;
    if Assigned(Meshes) then
    for I := 0 to Meshes.Count - 1 do
    begin
      Mesh := Meshes.Item[I];
      if (Mesh <> nil) and (Mesh.MaterialLibrary = ALib) then
        Exit(True);
    end;

    for I := 0 to Obj.Count - 1 do
      if VisitObject(Obj.ObjectList[I]) then
        Exit(True);
  end;
begin
  Result := (ALib <> nil) and VisitObject(fRoot);
end;

function TSandBoxForm.SceneUsesMaterial(ALib: TMaterialLibrary;
  const MaterialName: string): Boolean;

  function VisitObject(Obj: TSceneObject): Boolean;
  var
    I: Integer;
    Mesh: TMesh;
    Meshes: TMeshList;
  begin
    Result := False;
    if Obj = nil then
      Exit;
    if Obj.IsGizmo then
      Exit;

    Meshes := Obj.EffectiveMeshList;
    if Assigned(Meshes) then
    for I := 0 to Meshes.Count - 1 do
    begin
      Mesh := Meshes.Item[I];
      if (Mesh <> nil) and (Mesh.MaterialLibrary = ALib) and
         SameText(Mesh.LibMaterialname, MaterialName) then
        Exit(True);
    end;

    for I := 0 to Obj.Count - 1 do
      if VisitObject(Obj.ObjectList[I]) then
        Exit(True);
  end;
begin
  Result := (ALib <> nil) and (Trim(MaterialName) <> '') and VisitObject(fRoot);
end;

procedure TSandBoxForm.DeleteMaterialLibraryAt(AIndex: Integer);
var
  LibToDelete: TMaterialLibrary;
  FallbackLib: TMaterialLibrary;
  FallbackMatIndex: Integer;
  FallbackMat: TMaterial;
  Mat: TMaterial;
  DeletedName: string;
  NeedsFallback: Boolean;
  NextLib: TMaterialLibrary;
begin
  if (MaterialLibraries = nil) or (AIndex < 0) or (AIndex >= MaterialLibraries.Count) then
    Exit;

  LibToDelete := MaterialLibraries.MaterialLibrary[AIndex];
  if LibToDelete = nil then
    Exit;
  DeletedName := MaterialLibraryDisplayName(LibToDelete, AIndex);
  NeedsFallback := SceneUsesMaterialLibrary(LibToDelete);

  FallbackLib := nil;
  if MaterialLibraries.Count > 1 then
  begin
    if AIndex = 0 then
      FallbackLib := MaterialLibraries.MaterialLibrary[1]
    else
      FallbackLib := MaterialLibraries.MaterialLibrary[0];
  end
  else if NeedsFallback then
    FallbackLib := CreateMaterialLibraryWithDefaultMaterial('MaterialLibrary');

  if NeedsFallback then
  begin
    if FallbackLib = nil then
      Exit;

    FallbackMatIndex := FirstRenderableMaterialIndex(FallbackLib);
    if FallbackMatIndex < 0 then
    begin
      Mat := TMaterial.Create(mtPBR);
      Mat.Name := MakeUniqueMaterialName(FallbackLib, DEFAULT_PBR_MATERIAL_NAME);
      AssignShaderToMaterial(Mat);
      AddDefaultPBRTextures(Mat);
      FallbackMatIndex := FallbackLib.AddMaterial(Mat);
    end;

    FallbackMat := FallbackLib.Material[FallbackMatIndex];
    if FallbackMat = nil then
      Exit;

    ReplaceLibraryReferencesInScene(LibToDelete, FallbackLib, FallbackMat.Name);
  end;

  MaterialLibraries.Delete(AIndex);

  if MaterialLibraries.Count = 0 then
  begin
    fMaterialEditor.SelectedLibraryIndex := -1;
    fMaterialEditor.SelectedMaterialIndex := -1;
    fMaterialEditor.SelectedTextureIndex := -1;
  end
  else if NeedsFallback and (FallbackLib <> nil) then
  begin
    fMaterialEditor.SelectedLibraryIndex := MaterialLibraryIndexOf(FallbackLib);
    fMaterialEditor.SelectedMaterialIndex := MaterialIndexInLibrary(FallbackLib, FallbackMat.Name);
    fMaterialEditor.SelectedTextureIndex := 0;
  end
  else
  begin
    if AIndex >= MaterialLibraries.Count then
      fMaterialEditor.SelectedLibraryIndex := MaterialLibraries.Count - 1
    else
      fMaterialEditor.SelectedLibraryIndex := AIndex;

    NextLib := SelectedMaterialEditorLibrary;
    if NextLib <> nil then
      fMaterialEditor.SelectedMaterialIndex := FirstRenderableMaterialIndex(NextLib)
    else
      fMaterialEditor.SelectedMaterialIndex := -1;

    if fMaterialEditor.SelectedMaterialIndex >= 0 then
      fMaterialEditor.SelectedTextureIndex := 0
    else
      fMaterialEditor.SelectedTextureIndex := -1;
  end;

  SyncTextureAssetSelectionToCurrentTexture;
  LogLine('Deleted material library: ' + DeletedName);
  RequestRender;
end;

procedure TSandBoxForm.DeleteMaterialAt(ALib: TMaterialLibrary; AIndex: Integer);
var
  DeletedMat: TMaterial;
  DeletedName: string;
  FallbackIndex: Integer;
  FallbackName: string;
  I: Integer;
  NewMat: TMaterial;
  NeedsFallback: Boolean;
  NextIndex: Integer;
begin
  if (ALib = nil) or (AIndex < 0) or (AIndex >= ALib.Count) then
    Exit;

  DeletedMat := ALib.Material[AIndex];
  if (DeletedMat = nil) or IsEditorOnlyMaterial(DeletedMat) then
    Exit;

  DeletedName := DeletedMat.Name;
  NeedsFallback := SceneUsesMaterial(ALib, DeletedName);
  FallbackIndex := -1;

  for I := 0 to ALib.Count - 1 do
    if (I <> AIndex) and Assigned(ALib.Material[I]) and
       not IsEditorOnlyMaterial(ALib.Material[I]) then
    begin
      FallbackIndex := I;
      Break;
    end;

  if (FallbackIndex < 0) and NeedsFallback then
  begin
    NewMat := TMaterial.Create(mtPBR);
    NewMat.Name := MakeUniqueMaterialName(ALib, 'Material');
    AssignShaderToMaterial(NewMat);
    AddDefaultPBRTextures(NewMat);
    FallbackIndex := ALib.AddMaterial(NewMat);
  end;

  if NeedsFallback then
  begin
    if FallbackIndex < 0 then
      Exit;

    FallbackName := ALib.Material[FallbackIndex].Name;
    ReplaceMaterialReferencesInScene(ALib, DeletedName, FallbackName);
  end;

  ALib.DeleteMaterial(AIndex);

  if ALib.Count = 0 then
  begin
    fMaterialEditor.SelectedMaterialIndex := -1;
    fMaterialEditor.SelectedTextureIndex := -1;
  end
  else if NeedsFallback then
  begin
    fMaterialEditor.SelectedMaterialIndex := MaterialIndexInLibrary(ALib, FallbackName);
    fMaterialEditor.SelectedTextureIndex := 0;
  end
  else
  begin
    NextIndex := AIndex;
    if NextIndex >= ALib.Count then
      NextIndex := ALib.Count - 1;

    if (NextIndex >= 0) and IsEditorOnlyMaterial(ALib.Material[NextIndex]) then
      NextIndex := FirstRenderableMaterialIndex(ALib);

    fMaterialEditor.SelectedMaterialIndex := NextIndex;
    if NextIndex >= 0 then
      fMaterialEditor.SelectedTextureIndex := 0
    else
      fMaterialEditor.SelectedTextureIndex := -1;
  end;

  SyncTextureAssetSelectionToCurrentTexture;
  LogLine('Deleted material: ' + DeletedName);
  RequestRender;
end;

procedure TSandBoxForm.EnsureMaterialEditorSelection;
var
  Lib: TMaterialLibrary;
begin
  if (MaterialLibraries = nil) or (MaterialLibraries.Count = 0) then
  begin
    fMaterialEditor.SelectedLibraryIndex := -1;
    fMaterialEditor.SelectedMaterialIndex := -1;
    fMaterialEditor.SelectedTextureIndex := -1;
    Exit;
  end;

  if fMaterialEditor.SelectedLibraryIndex < 0 then
    fMaterialEditor.SelectedLibraryIndex := 0
  else if fMaterialEditor.SelectedLibraryIndex >= MaterialLibraries.Count then
    fMaterialEditor.SelectedLibraryIndex := MaterialLibraries.Count - 1;

  Lib := MaterialLibraries.MaterialLibrary[fMaterialEditor.SelectedLibraryIndex];
  if (Lib = nil) or (Lib.Count = 0) then
  begin
    fMaterialEditor.SelectedMaterialIndex := -1;
    fMaterialEditor.SelectedTextureIndex := -1;
    Exit;
  end;

  if (fMaterialEditor.SelectedMaterialIndex < 0) or
     (fMaterialEditor.SelectedMaterialIndex >= Lib.Count) or
     IsEditorOnlyMaterial(Lib.Material[fMaterialEditor.SelectedMaterialIndex]) then
    fMaterialEditor.SelectedMaterialIndex := FirstRenderableMaterialIndex(Lib);

  if fMaterialEditor.SelectedMaterialIndex < 0 then
  begin
    fMaterialEditor.SelectedTextureIndex := -1;
    Exit;
  end;

  if (Lib.Material[fMaterialEditor.SelectedMaterialIndex] = nil) or
     (Lib.Material[fMaterialEditor.SelectedMaterialIndex].Count = 0) then
    fMaterialEditor.SelectedTextureIndex := -1
  else if fMaterialEditor.SelectedTextureIndex < 0 then
    fMaterialEditor.SelectedTextureIndex := 0
  else if fMaterialEditor.SelectedTextureIndex >=
          Lib.Material[fMaterialEditor.SelectedMaterialIndex].Count then
    fMaterialEditor.SelectedTextureIndex :=
      Lib.Material[fMaterialEditor.SelectedMaterialIndex].Count - 1;
end;

function TSandBoxForm.SelectedMaterialEditorLibrary: TMaterialLibrary;
begin
  EnsureMaterialEditorSelection;

  Result := nil;
  if (MaterialLibraries <> nil) and
     (fMaterialEditor.SelectedLibraryIndex >= 0) and
     (fMaterialEditor.SelectedLibraryIndex < MaterialLibraries.Count) then
    Result := MaterialLibraries.MaterialLibrary[fMaterialEditor.SelectedLibraryIndex];
end;

function TSandBoxForm.SelectedMaterialEditorMaterial: TMaterial;
var
  Lib: TMaterialLibrary;
begin
  EnsureMaterialEditorSelection;

  Result := nil;
  Lib := SelectedMaterialEditorLibrary;
  if (Lib <> nil) and
     (fMaterialEditor.SelectedMaterialIndex >= 0) and
     (fMaterialEditor.SelectedMaterialIndex < Lib.Count) then
    Result := Lib.Material[fMaterialEditor.SelectedMaterialIndex];
end;

function TSandBoxForm.SelectedMaterialEditorTexture(out AMaterial: TMaterial;
  out ATexture: TMaterialTexture; out ATextureIndex: Integer): Boolean;
begin
  Result := False;
  AMaterial := SelectedMaterialEditorMaterial;
  ATextureIndex := fMaterialEditor.SelectedTextureIndex;
  if (AMaterial = nil) or (ATextureIndex < 0) or (ATextureIndex >= AMaterial.Count) then
    Exit;

  ATexture := AMaterial.TextureList[ATextureIndex];
  Result := True;
end;

function TSandBoxForm.IsTextureAssetFile(const AFileName: string): Boolean;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(AFileName));
  Result := (Ext = '.tga') or (Ext = '.png') or (Ext = '.dds');
end;

function TSandBoxForm.IsParticleTextureAssetFile(const AFileName: string): Boolean;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(AFileName));
  Result := (Ext = '.tga') or (Ext = '.png') or (Ext = '.dds');
end;

function TSandBoxForm.IsBillboardTextureAssetFile(const AFileName: string): Boolean;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(AFileName));
  Result := (Ext = '.tga') or (Ext = '.png') or (Ext = '.dds');
end;

function TSandBoxForm.IsMaterialAssetFile(const AFileName: string): Boolean;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(AFileName));
  Result := (Ext = '.omemat') or (Ext = '.omeml');
end;

function TSandBoxForm.TextureFileDisplayName(const AStoredPath: string): string;
begin
  Result := ExtractFileName(Trim(AStoredPath));
  if Result = '' then
    Result := '<no texture file>';
end;

procedure TSandBoxForm.SyncTextureAssetSelectionToCurrentTexture;
var
  Mat: TMaterial;
  Tex: TMaterialTexture;
  TextureIndex: Integer;
  TargetPath: string;
  TargetFullPath: string;
  I: Integer;
begin
  fTextureBrowser.SelectedIndex := -1;

  if not SelectedMaterialEditorTexture(Mat, Tex, TextureIndex) then
    Exit;

  TargetPath := Trim(Tex.Path);
  if TargetPath = '' then
    Exit;

  TargetFullPath := TEnginePaths.ResolveAssetPath(TargetPath);
  for I := 0 to High(fTextureBrowser.Items) do
    if SameText(fTextureBrowser.Items[I].FileName, TargetFullPath) or
       SameText(fTextureBrowser.Items[I].RelativePath, TargetPath) or
       SameText(ExtractFileName(fTextureBrowser.Items[I].FileName),
         ExtractFileName(TargetPath)) then
    begin
      fTextureBrowser.SelectedIndex := I;
      Exit;
    end;
end;

function TSandBoxForm.TexturePreviewMetadataDir: string;
begin
  Result := TPath.Combine(TEnginePaths.TexturesDir,
    TEXTURE_PREVIEW_METADATA_DIRNAME);
end;

function TSandBoxForm.TexturePreviewCacheDir: string;
begin
  Result := TPath.Combine(TexturePreviewMetadataDir,
    TEXTURE_PREVIEW_CACHE_DIRNAME);
end;

function TSandBoxForm.TexturePreviewMetadataFile: string;
begin
  Result := TPath.Combine(TexturePreviewMetadataDir,
    TEXTURE_PREVIEW_METADATA_FILENAME);
end;

function TSandBoxForm.TexturePreviewCacheFileName(const ARelativePath: string): string;
var
  BaseName: string;
begin
  BaseName := ChangeFileExt(ExtractFileName(ARelativePath), '');
  if BaseName = '' then
    BaseName := 'texture';

  Result := TPath.Combine(TexturePreviewCacheDir,
    BaseName + '_' + IntToHex(HashTextFNV1a32(LowerCase(ARelativePath)), 8) +
    '.thumbbin');
end;

function TSandBoxForm.TextureAssetFileStamp(const AFileName: string): Int64;
begin
  Result := 0;
  if not FileExists(AFileName) then
    Exit;

  try
    Result := DateTimeToUnix(TFile.GetLastWriteTimeUtc(AFileName), False);
  except
    Result := 0;
  end;
end;

function TSandBoxForm.FindTextureAssetIndex(const AItems: TArray<TTextureAssetInfo>;
  const ARelativePath: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(AItems) do
    if SameText(AItems[I].RelativePath, ARelativePath) then
      Exit(I);

  Result := -1;
end;

function TSandBoxForm.TextureInventoryMatchesCurrent(
  const AItems: TArray<TTextureAssetInfo>): Boolean;
var
  I: Integer;
begin
  Result := Length(AItems) = Length(fTextureBrowser.Items);
  if not Result then
    Exit;

  for I := 0 to High(AItems) do
    if not SameText(AItems[I].RelativePath, fTextureBrowser.Items[I].RelativePath) or
       (AItems[I].FileSize <> fTextureBrowser.Items[I].FileSize) or
       (AItems[I].LastWriteStamp <> fTextureBrowser.Items[I].LastWriteStamp) then
      Exit(False);
end;

procedure TSandBoxForm.ReleaseTextureAssetPreviews(var AItems: TArray<TTextureAssetInfo>);
var
  I: Integer;
  TexID: GLuint;
begin
  for I := 0 to High(AItems) do
  begin
    TexID := AItems[I].TextureID;
    if TexID <> 0 then
    begin
      glDeleteTextures(1, @TexID);
      AItems[I].TextureID := 0;
    end;
  end;
end;

procedure TSandBoxForm.LoadTexturePreviewMetadata(out AItems: TArray<TTextureAssetInfo>);
var
  Lines: TStringList;
  Parts: TStringList;
  I, Count: Integer;
  Item: TTextureAssetInfo;
begin
  SetLength(AItems, 0);
  if not FileExists(TexturePreviewMetadataFile) then
    Exit;

  Lines := TStringList.Create;
  Parts := TStringList.Create;
  try
    Lines.LoadFromFile(TexturePreviewMetadataFile);
    Parts.StrictDelimiter := True;
    Parts.Delimiter := #9;
    Count := 0;

    for I := 0 to Lines.Count - 1 do
    begin
      Parts.DelimitedText := Lines[I];
      if Parts.Count < 5 then
        Continue;

      Item := Default(TTextureAssetInfo);
      Item.RelativePath := Parts[0];
      Item.DisplayName := ExtractFileName(Item.RelativePath);
      Item.CacheFileName := TexturePreviewCacheFileName(Item.RelativePath);
      Item.FileSize := StrToInt64Def(Parts[1], 0);
      Item.LastWriteStamp := StrToInt64Def(Parts[2], 0);
      Item.Width := StrToIntDef(Parts[3], 0);
      Item.Height := StrToIntDef(Parts[4], 0);

      SetLength(AItems, Count + 1);
      AItems[Count] := Item;
      Inc(Count);
    end;
  finally
    Parts.Free;
    Lines.Free;
  end;
end;

procedure TSandBoxForm.SaveTexturePreviewMetadata(
  const AItems: TArray<TTextureAssetInfo>);
var
  Lines: TStringList;
  I: Integer;
begin
  ForceDirectories(TexturePreviewMetadataDir);
  ForceDirectories(TexturePreviewCacheDir);

  Lines := TStringList.Create;
  try
    for I := 0 to High(AItems) do
      if AItems[I].RelativePath <> '' then
        Lines.Add(AItems[I].RelativePath + #9 +
          IntToStr(AItems[I].FileSize) + #9 +
          IntToStr(AItems[I].LastWriteStamp) + #9 +
          IntToStr(AItems[I].Width) + #9 +
          IntToStr(AItems[I].Height));

    Lines.SaveToFile(TexturePreviewMetadataFile);
  finally
    Lines.Free;
  end;
end;

function TSandBoxForm.ScanTextureAssetFiles(out AItems: TArray<TTextureAssetInfo>): Boolean;
var
  Files: TArray<string>;
  SortedFiles: TStringList;
  MetadataRoot: string;
  I, Count: Integer;
  FileName: string;
  Item: TTextureAssetInfo;
begin
  Result := False;
  SetLength(AItems, 0);
  fTextureBrowser.LastError := '';

  TEnginePaths.EnsureDirectories;
  if not TDirectory.Exists(TEnginePaths.TexturesDir) then
  begin
    fTextureBrowser.LastError := 'Texture folder does not exist: ' +
      TEnginePaths.TexturesDir;
    Exit;
  end;

  try
    Files := TDirectory.GetFiles(TEnginePaths.TexturesDir, '*.*',
      TSearchOption.soAllDirectories);
  except
    on E: Exception do
    begin
      fTextureBrowser.LastError := 'Could not scan texture folder: ' + E.Message;
      Exit;
    end;
  end;

  SortedFiles := TStringList.Create;
  try
    SortedFiles.CaseSensitive := False;
    SortedFiles.Sorted := True;
    SortedFiles.Duplicates := dupIgnore;
    for I := 0 to High(Files) do
      SortedFiles.Add(ExpandFileName(Files[I]));

    MetadataRoot := IncludeTrailingPathDelimiter(
      ExpandFileName(TexturePreviewMetadataDir));

    Count := 0;
    for I := 0 to SortedFiles.Count - 1 do
    begin
      FileName := SortedFiles[I];
      if not IsTextureAssetFile(FileName) then
        Continue;
      if SameText(Copy(FileName, 1, Length(MetadataRoot)), MetadataRoot) then
        Continue;

      Item := Default(TTextureAssetInfo);
      Item.FileName := FileName;
      Item.RelativePath := TEnginePaths.ToAssetRelativePath(FileName);
      Item.DisplayName := ExtractFileName(FileName);
      Item.CacheFileName := TexturePreviewCacheFileName(Item.RelativePath);
      try
        Item.FileSize := TFile.GetSize(FileName);
      except
        Item.FileSize := 0;
      end;
      Item.LastWriteStamp := TextureAssetFileStamp(FileName);

      SetLength(AItems, Count + 1);
      AItems[Count] := Item;
      Inc(Count);
    end;
  finally
    SortedFiles.Free;
  end;

  Result := True;
end;

function TSandBoxForm.TryBuildImageThumbnailBitmap(const AFileName: string;
  AThumbSize: Integer; out Thumb: TBitmap; out ImageWidth,
  ImageHeight: Integer): Boolean;
var
  Picture: TPicture;
  Bitmap: TBitmap;
begin
  Result := False;
  Thumb := nil;
  ImageWidth := 0;
  ImageHeight := 0;

  if (AThumbSize <= 0) or (not FileExists(AFileName)) then
    Exit;

  Picture := TPicture.Create;
  Bitmap := TBitmap.Create;
  try
    try
      Picture.LoadFromFile(AFileName);

      ImageWidth := Picture.Width;
      ImageHeight := Picture.Height;
      if (ImageWidth < 1) or (ImageHeight < 1) then
        Exit(False);

      Bitmap.PixelFormat := pf32bit;
      Bitmap.SetSize(ImageWidth, ImageHeight);
      Bitmap.Canvas.Draw(0, 0, Picture.Graphic);

      Thumb := TBitmap.Create;
      Thumb.PixelFormat := pf32bit;
      Thumb.SetSize(AThumbSize, AThumbSize);
      Thumb.Canvas.Brush.Color := clBlack;
      Thumb.Canvas.FillRect(Rect(0, 0, AThumbSize, AThumbSize));
      Thumb.Canvas.StretchDraw(Rect(0, 0, AThumbSize, AThumbSize), Bitmap);
      Result := True;
    except
      Thumb.Free;
      Thumb := nil;
      Result := False;
    end;
  finally
    Bitmap.Free;
    Picture.Free;
  end;
end;

function TSandBoxForm.TryCreateGLTextureFromBitmap(ABitmap: TBitmap;
  out TextureID: GLuint): Boolean;
var
  Pixels: TBytes;
begin
  Result := TryCopyBitmapToRGBAPixels(ABitmap, Pixels);
  if not Result then
  begin
    TextureID := 0;
    Exit;
  end;

  Result := TryCreateGLTextureFromPixels(Pixels, ABitmap.Width, ABitmap.Height,
    TextureID);
end;

function TSandBoxForm.TryCreateGLTextureFromPixels(const Pixels: TBytes; AWidth,
  AHeight: Integer; out TextureID: GLuint): Boolean;
var
  ExpectedByteCount: Int64;
begin
  Result := False;
  TextureID := 0;
  if (AWidth < 1) or (AHeight < 1) then
    Exit;

  ExpectedByteCount := Int64(AWidth) * AHeight * 4;
  if (ExpectedByteCount < 4) or (ExpectedByteCount > Length(Pixels)) then
    Exit;

  glGenTextures(1, @TextureID);
  glBindTexture(GL_TEXTURE_2D, TextureID);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, AWidth, AHeight, 0,
    GL_RGBA, GL_UNSIGNED_BYTE, @Pixels[0]);
  glBindTexture(GL_TEXTURE_2D, 0);

  Result := TextureID <> 0;
end;

function TSandBoxForm.TryCopyBitmapToRGBAPixels(ABitmap: TBitmap;
  out Pixels: TBytes): Boolean;
var
  X, Y, Index: Integer;
  ColorValue: TColor;
  ByteCount: Int64;
begin
  Result := False;
  SetLength(Pixels, 0);
  if (ABitmap = nil) or (ABitmap.Width < 1) or (ABitmap.Height < 1) then
    Exit;

  ByteCount := Int64(ABitmap.Width) * ABitmap.Height * 4;
  if (ByteCount < 4) or (ByteCount > MaxInt) then
    Exit;

  try
    SetLength(Pixels, Integer(ByteCount));
    for Y := 0 to ABitmap.Height - 1 do
      for X := 0 to ABitmap.Width - 1 do
      begin
        ColorValue := ColorToRGB(ABitmap.Canvas.Pixels[X, Y]);
        Index := ((Y * ABitmap.Width) + X) * 4;
        Pixels[Index + 0] := GetRValue(ColorValue);
        Pixels[Index + 1] := GetGValue(ColorValue);
        Pixels[Index + 2] := GetBValue(ColorValue);
        Pixels[Index + 3] := 255;
      end;
    Result := True;
  except
    SetLength(Pixels, 0);
    Result := False;
  end;
end;

function TSandBoxForm.TryLoadThumbnailBinaryFromFile(const AFileName: string;
  ExpectedFileSize, ExpectedStamp: Int64; out TextureID: GLuint; out ThumbWidth,
  ThumbHeight: Integer): Boolean;
var
  Stream: TFileStream;
  Magic: array[0..7] of AnsiChar;
  Version: Integer;
  CachedFileSize: Int64;
  CachedStamp: Int64;
  PixelByteCount: Integer;
  ExpectedByteCount: Int64;
  Pixels: TBytes;
begin
  Result := False;
  TextureID := 0;
  ThumbWidth := 0;
  ThumbHeight := 0;
  if (AFileName = '') or (not FileExists(AFileName)) then
    Exit;

  try
    Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
    try
      if Stream.Size < SizeOf(Magic) + SizeOf(Version) +
        (2 * SizeOf(Integer)) + (2 * SizeOf(Int64)) + SizeOf(Integer) then
        Exit;

      Stream.ReadBuffer(Magic[0], SizeOf(Magic));
      if not PreviewMagicMatches(Magic, TEXTURE_THUMB_CACHE_MAGIC_LOCAL) then
        Exit;

      Stream.ReadBuffer(Version, SizeOf(Version));
      if Version <> TEXTURE_THUMB_CACHE_VERSION_LOCAL then
        Exit;

      Stream.ReadBuffer(ThumbWidth, SizeOf(ThumbWidth));
      Stream.ReadBuffer(ThumbHeight, SizeOf(ThumbHeight));
      if (ThumbWidth < 1) or (ThumbWidth > 4096) or
         (ThumbHeight < 1) or (ThumbHeight > 4096) then
        Exit;

      Stream.ReadBuffer(CachedFileSize, SizeOf(CachedFileSize));
      Stream.ReadBuffer(CachedStamp, SizeOf(CachedStamp));
      if (CachedFileSize <> ExpectedFileSize) or
         (CachedStamp <> ExpectedStamp) then
        Exit;

      Stream.ReadBuffer(PixelByteCount, SizeOf(PixelByteCount));
      ExpectedByteCount := Int64(ThumbWidth) * ThumbHeight * 4;
      if (ExpectedByteCount < 4) or (ExpectedByteCount > MaxInt) or
         (PixelByteCount <> ExpectedByteCount) or
         ((Stream.Size - Stream.Position) < PixelByteCount) then
        Exit;

      SetLength(Pixels, PixelByteCount);
      Stream.ReadBuffer(Pixels[0], PixelByteCount);
      Result := TryCreateGLTextureFromPixels(Pixels, ThumbWidth, ThumbHeight,
        TextureID);
    finally
      Stream.Free;
    end;
  except
    Result := False;
    TextureID := 0;
    ThumbWidth := 0;
    ThumbHeight := 0;
  end;
end;

procedure TSandBoxForm.SaveThumbnailBitmapToBinaryFile(ABitmap: TBitmap;
  const AFileName: string; SourceFileSize, SourceStamp: Int64);
var
  Stream: TFileStream;
  Version: Integer;
  ThumbWidth: Integer;
  ThumbHeight: Integer;
  PixelByteCount: Integer;
  Pixels: TBytes;
begin
  if (ABitmap = nil) or (AFileName = '') then
    Exit;

  if not TryCopyBitmapToRGBAPixels(ABitmap, Pixels) then
    Exit;

  try
    ForceDirectories(ExtractFilePath(AFileName));
    Stream := TFileStream.Create(AFileName, fmCreate);
    try
      Version := TEXTURE_THUMB_CACHE_VERSION_LOCAL;
      ThumbWidth := ABitmap.Width;
      ThumbHeight := ABitmap.Height;
      PixelByteCount := Length(Pixels);

      Stream.WriteBuffer(TEXTURE_THUMB_CACHE_MAGIC_LOCAL[0],
        SizeOf(TEXTURE_THUMB_CACHE_MAGIC_LOCAL));
      Stream.WriteBuffer(Version, SizeOf(Version));
      Stream.WriteBuffer(ThumbWidth, SizeOf(ThumbWidth));
      Stream.WriteBuffer(ThumbHeight, SizeOf(ThumbHeight));
      Stream.WriteBuffer(SourceFileSize, SizeOf(SourceFileSize));
      Stream.WriteBuffer(SourceStamp, SizeOf(SourceStamp));
      Stream.WriteBuffer(PixelByteCount, SizeOf(PixelByteCount));
      if PixelByteCount > 0 then
        Stream.WriteBuffer(Pixels[0], PixelByteCount);
    finally
      Stream.Free;
    end;
  except
    // Preview cache failures should not block the editor.
  end;
end;

procedure TSandBoxForm.SaveThumbnailPixelsToBinaryFile(const Pixels: TBytes;
  AWidth, AHeight: Integer; const AFileName: string; SourceFileSize,
  SourceStamp: Int64);
var
  Stream: TFileStream;
  Version: Integer;
  PixelByteCount: Integer;
  ExpectedByteCount: Int64;
begin
  if (AFileName = '') or (AWidth < 1) or (AHeight < 1) then
    Exit;

  ExpectedByteCount := Int64(AWidth) * AHeight * 4;
  if (ExpectedByteCount < 4) or (ExpectedByteCount > MaxInt) or
     (Length(Pixels) < ExpectedByteCount) then
    Exit;

  try
    ForceDirectories(ExtractFilePath(AFileName));
    Stream := TFileStream.Create(AFileName, fmCreate);
    try
      Version := TEXTURE_THUMB_CACHE_VERSION_LOCAL;
      PixelByteCount := Integer(ExpectedByteCount);

      Stream.WriteBuffer(TEXTURE_THUMB_CACHE_MAGIC_LOCAL[0],
        SizeOf(TEXTURE_THUMB_CACHE_MAGIC_LOCAL));
      Stream.WriteBuffer(Version, SizeOf(Version));
      Stream.WriteBuffer(AWidth, SizeOf(AWidth));
      Stream.WriteBuffer(AHeight, SizeOf(AHeight));
      Stream.WriteBuffer(SourceFileSize, SizeOf(SourceFileSize));
      Stream.WriteBuffer(SourceStamp, SizeOf(SourceStamp));
      Stream.WriteBuffer(PixelByteCount, SizeOf(PixelByteCount));
      Stream.WriteBuffer(Pixels[0], PixelByteCount);
    finally
      Stream.Free;
    end;
  except
    // Preview cache failures should not block the editor.
  end;
end;

function TSandBoxForm.TryCreateImagePreviewTexture(const AFileName: string;
  AThumbSize: Integer; out TextureID: GLuint; out ImageWidth,
  ImageHeight: Integer): Boolean;
var
  Thumb: TBitmap;
begin
  Thumb := nil;
  Result := TryBuildImageThumbnailBitmap(AFileName, AThumbSize, Thumb,
    ImageWidth, ImageHeight);
  if not Result then
    Exit(False);

  try
    Result := TryCreateGLTextureFromBitmap(Thumb, TextureID);
  finally
    Thumb.Free;
  end;
end;

function TSandBoxForm.TryCreateDDSPreviewTexture(const AFileName: string;
  AThumbSize: Integer; out TextureID: GLuint; out ImageWidth,
  ImageHeight: Integer): Boolean;
var
  SourceTextureID: GLuint;
  SourcePixels: TBytes;
  ThumbPixels: TBytes;
  ByteCount: Int64;
begin
  Result := False;
  TextureID := 0;
  ImageWidth := 0;
  ImageHeight := 0;
  SourceTextureID := 0;

  if not LoadDDS2DTexture(AFileName, False, GL_RGBA8, GL_CLAMP_TO_EDGE,
    False, SourceTextureID, ImageWidth, ImageHeight) then
    Exit;

  try
    ByteCount := Int64(ImageWidth) * ImageHeight * 4;
    if (ByteCount < 4) or (ByteCount > 128 * 1024 * 1024) then
      Exit;

    SetLength(SourcePixels, Integer(ByteCount));
    glBindTexture(GL_TEXTURE_2D, SourceTextureID);
    glGetTexImage(GL_TEXTURE_2D, 0, GL_RGBA, GL_UNSIGNED_BYTE,
      @SourcePixels[0]);
    glBindTexture(GL_TEXTURE_2D, 0);

    if not TryBuildParticlePreviewPixels(SourcePixels, ImageWidth, ImageHeight,
      AThumbSize, ThumbPixels) then
      Exit;

    Result := TryCreateGLTextureFromPixels(ThumbPixels, AThumbSize,
      AThumbSize, TextureID);
  finally
    glBindTexture(GL_TEXTURE_2D, 0);
    if SourceTextureID <> 0 then
      glDeleteTextures(1, @SourceTextureID);
  end;
end;

procedure TSandBoxForm.ClearTextureBrowserPreviews;
begin
  ReleaseTextureAssetPreviews(fTextureBrowser.Items);
  SetLength(fTextureBrowser.Items, 0);
end;

procedure TSandBoxForm.RefreshTextureBrowserList(const ForceRebuild: Boolean);
var
  OldItems: TArray<TTextureAssetInfo>;
  NewItems: TArray<TTextureAssetInfo>;
  CachedItems: TArray<TTextureAssetInfo>;
  I: Integer;
  OldIndex: Integer;
  CacheIndex: Integer;
  TexID: GLuint;
  W, H: Integer;
  CacheW, CacheH: Integer;
  Thumb: TBitmap;
  Ext: string;
begin
  fTextureBrowser.NeedsRefresh := False;
  fTextureBrowser.LastError := '';
  if not ScanTextureAssetFiles(NewItems) then
    Exit;

  if Length(NewItems) = 0 then
  begin
    ClearTextureBrowserPreviews;
    fTextureBrowser.SelectedIndex := -1;
    fTextureBrowser.LastError := 'No TGA/PNG textures found in ' +
      TEnginePaths.TexturesDir;
    Exit;
  end;

  if (not ForceRebuild) and TextureInventoryMatchesCurrent(NewItems) then
  begin
    SyncTextureAssetSelectionToCurrentTexture;
    Exit;
  end;

  ActivateMainRenderContext;
  OldItems := fTextureBrowser.Items;
  LoadTexturePreviewMetadata(CachedItems);

  for I := 0 to High(NewItems) do
  begin
    OldIndex := FindTextureAssetIndex(OldItems, NewItems[I].RelativePath);
    if (OldIndex >= 0) and
       (OldItems[OldIndex].FileSize = NewItems[I].FileSize) and
       (OldItems[OldIndex].LastWriteStamp = NewItems[I].LastWriteStamp) and
       (OldItems[OldIndex].TextureID <> 0) then
    begin
      NewItems[I].TextureID := OldItems[OldIndex].TextureID;
      NewItems[I].Width := OldItems[OldIndex].Width;
      NewItems[I].Height := OldItems[OldIndex].Height;
      NewItems[I].PreviewReady := OldItems[OldIndex].PreviewReady;
      OldItems[OldIndex].TextureID := 0;
      Continue;
    end;

    CacheIndex := FindTextureAssetIndex(CachedItems, NewItems[I].RelativePath);
    if (CacheIndex >= 0) and
       (CachedItems[CacheIndex].FileSize = NewItems[I].FileSize) and
       (CachedItems[CacheIndex].LastWriteStamp = NewItems[I].LastWriteStamp) and
       FileExists(NewItems[I].CacheFileName) then
    begin
      TexID := 0;
      CacheW := 0;
      CacheH := 0;
      if TryLoadThumbnailBinaryFromFile(NewItems[I].CacheFileName,
        NewItems[I].FileSize, NewItems[I].LastWriteStamp, TexID, CacheW,
        CacheH) then
      begin
        NewItems[I].TextureID := TexID;
        NewItems[I].Width := CachedItems[CacheIndex].Width;
        NewItems[I].Height := CachedItems[CacheIndex].Height;
        NewItems[I].PreviewReady := True;
        Continue;
      end;
    end;

    Ext := LowerCase(ExtractFileExt(NewItems[I].FileName));
    if Ext = '.dds' then
    begin
      TexID := 0;
      if TryCreateDDSPreviewTexture(NewItems[I].FileName,
        MATERIAL_TEXTURE_THUMB_SIZE, TexID, W, H) then
      begin
        NewItems[I].TextureID := TexID;
        NewItems[I].Width := W;
        NewItems[I].Height := H;
        NewItems[I].PreviewReady := True;
      end;
    end
    else
    begin
      Thumb := nil;
      if TryBuildImageThumbnailBitmap(NewItems[I].FileName,
        MATERIAL_TEXTURE_THUMB_SIZE, Thumb, W, H) then
      begin
        try
          TexID := 0;
          if TryCreateGLTextureFromBitmap(Thumb, TexID) then
          begin
            NewItems[I].TextureID := TexID;
            NewItems[I].Width := W;
            NewItems[I].Height := H;
            NewItems[I].PreviewReady := True;
          end;
          SaveThumbnailBitmapToBinaryFile(Thumb, NewItems[I].CacheFileName,
            NewItems[I].FileSize, NewItems[I].LastWriteStamp);
        finally
          Thumb.Free;
        end;
      end;
    end;
  end;

  ReleaseTextureAssetPreviews(OldItems);
  fTextureBrowser.Items := NewItems;
  SaveTexturePreviewMetadata(fTextureBrowser.Items);
  SyncTextureAssetSelectionToCurrentTexture;
end;

procedure TSandBoxForm.ResetTextureBrowser;
begin
  fTextureBrowser.Active := False;
  fTextureBrowser.NeedsRefresh := False;
  fTextureBrowser.SelectedIndex := -1;
  fTextureBrowser.LibraryIndex := -1;
  fTextureBrowser.MaterialIndex := -1;
  fTextureBrowser.TextureIndex := -1;
  fTextureBrowser.LastError := '';
  SetAnsiBuffer(fTextureBrowser.Search, '');

  if not fInImGuiFrame then
    ClearTextureBrowserPreviews;
end;

procedure TSandBoxForm.OpenParticleEditor;
begin
  if not fParticleEditorActive then
    fParticleEditorExpandAllOnNextOpen := True;

  fParticleEditorActive := True;
  RequestRender;
end;

procedure TSandBoxForm.OpenTextureBrowser(ALibraryIndex, AMaterialIndex,
  ATextureIndex: Integer);
begin
  fTextureBrowser.Active := True;
  fTextureBrowser.NeedsRefresh := True;
  fTextureBrowser.LibraryIndex := ALibraryIndex;
  fTextureBrowser.MaterialIndex := AMaterialIndex;
  fTextureBrowser.TextureIndex := ATextureIndex;
  fTextureBrowser.SelectedIndex := -1;
  fTextureBrowser.LastError := '';
end;

procedure TSandBoxForm.OpenParticleTextureBrowser;
begin
  if (fSelectedObject <> nil) and (fSelectedObject.ParticleSystemCount > 0) and
     ((fSelectedParticleSystemIndex < 0) or
      (fSelectedParticleSystemIndex >= fSelectedObject.ParticleSystemCount)) then
    SelectParticleSystemIndex(0);

  fParticleTextureBrowser.Active := True;
  fParticleTextureBrowser.NeedsRefresh := True;
  fParticleTextureBrowser.SelectedIndex := -1;
  fParticleTextureBrowser.LastError := '';
  SetAnsiBuffer(fParticleTextureBrowser.Search, '');
end;

procedure TSandBoxForm.OpenBillboardTextureBrowser;
begin
  if (fSelectedObject <> nil) and (fSelectedObject.BillboardCount > 0) and
     ((fSelectedBillboardIndex < 0) or
      (fSelectedBillboardIndex >= fSelectedObject.BillboardCount)) then
    SelectBillboardIndex(0);

  fBillboardTextureBrowser.Active := True;
  fBillboardTextureBrowser.NeedsRefresh := True;
  fBillboardTextureBrowser.SelectedIndex := -1;
  fBillboardTextureBrowser.LastError := '';
  SetAnsiBuffer(fBillboardTextureBrowser.Search, '');
end;

procedure TSandBoxForm.ApplyTextureAssetToSelectedTexture(const AFileName: string);
var
  Mat: TMaterial;
  Tex: TMaterialTexture;
  TextureIndex: Integer;
  UniformName: string;
  FullPath: string;
  StoredPath: string;
  MipMap: Boolean;
  InternalFormat: GLint;
  Param: GLint;
  InvertNormals: Boolean;
  Loaded: Boolean;
  Ext: string;
begin
  fTextureBrowser.LastError := '';
  if not SelectedMaterialEditorTexture(Mat, Tex, TextureIndex) then
  begin
    fTextureBrowser.LastError := 'Select a texture slot first.';
    Exit;
  end;

  FullPath := TEnginePaths.ResolveAssetPath(AFileName);
  if not FileExists(FullPath) then
  begin
    fTextureBrowser.LastError := 'Texture file not found: ' + AFileName;
    Exit;
  end;

  StoredPath := TEnginePaths.ToAssetRelativePath(FullPath);
  UniformName := Trim(Tex.Texture.Name);
  if UniformName = '' then
    UniformName := TextureDisplayName(Tex, TextureIndex);

  GetTextureLoadParams(UniformName, MipMap, InternalFormat, Param, InvertNormals);
  ActivateMainRenderContext;

  Loaded := False;
  Ext := LowerCase(ExtractFileExt(FullPath));
  if Ext = '.tga' then
    Loaded := Tex.LoadTexTGA(FullPath, MipMap, UniformName, InternalFormat,
      Param, InvertNormals)
  else if Ext = '.png' then
    Loaded := Tex.LoadTexPNG(FullPath, MipMap, UniformName, InternalFormat,
      Param, InvertNormals)
  else if Ext = '.dds' then
    Loaded := Tex.LoadTexDDS(FullPath, MipMap, UniformName, InternalFormat,
      Param, InvertNormals);

  if Loaded then
  begin
    Tex.Path := StoredPath;
    Tex.Texture.Name := UniformName;
    Mat.TextureList[TextureIndex] := Tex;
    AssignShaderToMaterial(Mat);
    LogLine('Texture assigned: ' + StoredPath + ' -> ' + Mat.Name);
    SyncTextureAssetSelectionToCurrentTexture;
    RequestRender;
  end
  else
    fTextureBrowser.LastError := 'Could not load texture: ' + FullPath;
end;

procedure TSandBoxForm.ApplyParticleTextureToSelectedParticle(const AFileName: string);
var
  Obj: TSceneObject;
  ParticleSystem: TParticleSystem;
  FullPath: string;
  StoredPath: string;
  Ext: string;
begin
  fParticleTextureBrowser.LastError := '';

  Obj := SelectedParticleObject;
  if Obj = nil then
  begin
    fParticleTextureBrowser.LastError := 'Select an object first.';
    Exit;
  end;

  FullPath := TEnginePaths.ResolveAssetPath(AFileName);
  if not FileExists(FullPath) then
  begin
    fParticleTextureBrowser.LastError := 'Texture file not found: ' + AFileName;
    Exit;
  end;

  Ext := LowerCase(ExtractFileExt(FullPath));
  if (Ext <> '.tga') and (Ext <> '.png') and (Ext <> '.dds') then
  begin
    fParticleTextureBrowser.LastError := 'Particle textures support .tga, .png, and .dds files.';
    Exit;
  end;

  ParticleSystem := SelectedParticleSystem;
  if ParticleSystem = nil then
  begin
    ParticleSystem := Obj.AddParticleSystem;
    SelectParticleSystemIndex(Obj.ParticleSystemCount - 1);
  end;

  StoredPath := TEnginePaths.ToAssetRelativePath(FullPath);
  ParticleSystem.TexturePath := StoredPath;
  ParticleSystem.TextureKind := ptFile;
  LogLine('Particle texture assigned: ' + StoredPath + ' -> ' +
    Obj.Name + ' / ' + ParticleSystem.Name);
  NotifyInspectorObjectEdited;
end;

procedure TSandBoxForm.ApplyBillboardTextureToSelectedObject(const AFileName: string);
var
  Obj: TSceneObject;
  Billboard: TBillboard;
  FullPath: string;
  StoredPath: string;
  Ext: string;
begin
  fBillboardTextureBrowser.LastError := '';

  Obj := fSelectedObject;
  if (Obj = nil) or Obj.IsGizmo then
  begin
    fBillboardTextureBrowser.LastError := 'Select an object first.';
    Exit;
  end;

  FullPath := TEnginePaths.ResolveAssetPath(AFileName);
  if not FileExists(FullPath) then
  begin
    fBillboardTextureBrowser.LastError := 'Texture file not found: ' + AFileName;
    Exit;
  end;

  Ext := LowerCase(ExtractFileExt(FullPath));
  if (Ext <> '.tga') and (Ext <> '.png') and (Ext <> '.dds') then
  begin
    fBillboardTextureBrowser.LastError := 'Billboard textures support .tga, .png, and .dds files.';
    Exit;
  end;

  Billboard := SelectedBillboard;
  if Billboard = nil then
  begin
    Billboard := Obj.AddBillboard;
    SelectBillboardIndex(Obj.BillboardCount - 1);
  end;
  StoredPath := TEnginePaths.ToAssetRelativePath(FullPath);
  Billboard.TexturePath := StoredPath;
  LogLine('Billboard texture assigned: ' + StoredPath + ' -> ' +
    Obj.Name + ' / ' + Billboard.Name);
  NotifyInspectorObjectEdited;
end;

function TSandBoxForm.ResolveParticleTexturePreviewPath(
  const AStoredPath: string): string;
var
  S: string;
  Candidate: string;
begin
  Result := '';
  S := Trim(AStoredPath);
  if S = '' then
    Exit;

  Candidate := TEnginePaths.ResolveAssetPath(S);
  if FileExists(Candidate) then
    Exit(Candidate);

  if (not TPath.IsPathRooted(S)) and (ExtractFilePath(S) = '') then
  begin
    Candidate := TEnginePaths.ParticleTexture(S);
    if FileExists(Candidate) then
      Exit(Candidate);
  end;

  Result := Candidate;
end;

function TSandBoxForm.ResolveBillboardTexturePreviewPath(
  const AStoredPath: string): string;
var
  S: string;
  Candidate: string;
begin
  S := Trim(AStoredPath);
  if S = '' then
    Exit('');

  Candidate := TEnginePaths.ResolveAssetPath(S);
  if FileExists(Candidate) then
    Exit(Candidate);

  if (not TPath.IsPathRooted(S)) and (ExtractFilePath(S) = '') then
  begin
    Candidate := TEnginePaths.BillboardTexture(S);
    if FileExists(Candidate) then
      Exit(Candidate);
  end;

  Result := Candidate;
end;

function TSandBoxForm.ParticleTexturePreviewMetadataDir: string;
begin
  Result := TPath.Combine(TEnginePaths.ParticleTexturesDir,
    TEXTURE_PREVIEW_METADATA_DIRNAME);
end;

function TSandBoxForm.ParticleTexturePreviewCacheDir: string;
begin
  Result := TPath.Combine(ParticleTexturePreviewMetadataDir,
    TEXTURE_PREVIEW_CACHE_DIRNAME);
end;

function TSandBoxForm.ParticleTexturePreviewMetadataFile: string;
begin
  Result := TPath.Combine(ParticleTexturePreviewMetadataDir,
    TEXTURE_PREVIEW_METADATA_FILENAME);
end;

function TSandBoxForm.ParticleTexturePreviewCacheFileName(
  const ARelativePath: string): string;
var
  BaseName: string;
begin
  BaseName := ChangeFileExt(ExtractFileName(ARelativePath), '');
  if BaseName = '' then
    BaseName := 'particle_texture';

  Result := TPath.Combine(ParticleTexturePreviewCacheDir,
    BaseName + '_' + IntToHex(HashTextFNV1a32(LowerCase(ARelativePath)), 8) +
    '.thumbbin');
end;

function TSandBoxForm.FindParticleTextureIndex(
  const AItems: TArray<TParticleTextureFileInfo>;
  const ARelativePath: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(AItems) do
    if SameText(AItems[I].RelativePath, ARelativePath) then
      Exit(I);

  Result := -1;
end;

function TSandBoxForm.ParticleTextureInventoryMatchesCurrent(
  const AItems: TArray<TParticleTextureFileInfo>): Boolean;
var
  I: Integer;
begin
  Result := Length(AItems) = Length(fParticleTextureBrowser.Items);
  if not Result then
    Exit;

  for I := 0 to High(AItems) do
    if not SameText(AItems[I].RelativePath,
         fParticleTextureBrowser.Items[I].RelativePath) or
       (AItems[I].FileSize <> fParticleTextureBrowser.Items[I].FileSize) or
       (AItems[I].LastWriteStamp <>
         fParticleTextureBrowser.Items[I].LastWriteStamp) then
      Exit(False);
end;

procedure TSandBoxForm.ReleaseParticleTexturePreviews(
  var AItems: TArray<TParticleTextureFileInfo>);
var
  I: Integer;
  TexID: GLuint;
begin
  for I := 0 to High(AItems) do
  begin
    TexID := AItems[I].TextureID;
    if TexID <> 0 then
    begin
      glDeleteTextures(1, @TexID);
      AItems[I].TextureID := 0;
    end;
  end;
end;

procedure TSandBoxForm.LoadParticleTexturePreviewMetadata(
  out AItems: TArray<TParticleTextureFileInfo>);
var
  Lines: TStringList;
  Parts: TStringList;
  I, Count: Integer;
  Item: TParticleTextureFileInfo;
begin
  SetLength(AItems, 0);
  if not FileExists(ParticleTexturePreviewMetadataFile) then
    Exit;

  Lines := TStringList.Create;
  Parts := TStringList.Create;
  try
    Lines.LoadFromFile(ParticleTexturePreviewMetadataFile);
    Parts.StrictDelimiter := True;
    Parts.Delimiter := #9;
    Count := 0;

    for I := 0 to Lines.Count - 1 do
    begin
      Parts.DelimitedText := Lines[I];
      if Parts.Count < 5 then
        Continue;

      Item := Default(TParticleTextureFileInfo);
      Item.RelativePath := Parts[0];
      Item.DisplayName := ExtractFileName(Item.RelativePath);
      Item.CacheFileName := ParticleTexturePreviewCacheFileName(
        Item.RelativePath);
      Item.FileSize := StrToInt64Def(Parts[1], 0);
      Item.LastWriteStamp := StrToInt64Def(Parts[2], 0);
      Item.Width := StrToIntDef(Parts[3], 0);
      Item.Height := StrToIntDef(Parts[4], 0);

      SetLength(AItems, Count + 1);
      AItems[Count] := Item;
      Inc(Count);
    end;
  finally
    Parts.Free;
    Lines.Free;
  end;
end;

procedure TSandBoxForm.SaveParticleTexturePreviewMetadata(
  const AItems: TArray<TParticleTextureFileInfo>);
var
  Lines: TStringList;
  I: Integer;
begin
  ForceDirectories(ParticleTexturePreviewMetadataDir);
  ForceDirectories(ParticleTexturePreviewCacheDir);

  Lines := TStringList.Create;
  try
    for I := 0 to High(AItems) do
      if AItems[I].RelativePath <> '' then
        Lines.Add(AItems[I].RelativePath + #9 +
          IntToStr(AItems[I].FileSize) + #9 +
          IntToStr(AItems[I].LastWriteStamp) + #9 +
          IntToStr(AItems[I].Width) + #9 +
          IntToStr(AItems[I].Height));

    Lines.SaveToFile(ParticleTexturePreviewMetadataFile);
  finally
    Lines.Free;
  end;
end;

function TSandBoxForm.ScanParticleTextureFiles(
  out AItems: TArray<TParticleTextureFileInfo>): Boolean;
var
  Files: TArray<string>;
  SortedFiles: TStringList;
  MetadataRoot: string;
  I, Count: Integer;
  FileName: string;
  RelPath: string;
  Item: TParticleTextureFileInfo;
begin
  Result := False;
  SetLength(AItems, 0);
  fParticleTextureBrowser.LastError := '';

  TEnginePaths.EnsureDirectories;
  if not TDirectory.Exists(TEnginePaths.ParticleTexturesDir) then
  begin
    fParticleTextureBrowser.LastError := 'Particle texture folder does not exist: ' +
      TEnginePaths.ParticleTexturesDir;
    Exit;
  end;

  try
    Files := TDirectory.GetFiles(TEnginePaths.ParticleTexturesDir, '*.*',
      TSearchOption.soAllDirectories);
  except
    on E: Exception do
    begin
      fParticleTextureBrowser.LastError := 'Could not scan particle texture folder: ' +
        E.Message;
      Exit;
    end;
  end;

  SortedFiles := TStringList.Create;
  try
    SortedFiles.CaseSensitive := False;
    SortedFiles.Sorted := True;
    SortedFiles.Duplicates := dupIgnore;
    for I := 0 to High(Files) do
      SortedFiles.Add(ExpandFileName(Files[I]));

    MetadataRoot := IncludeTrailingPathDelimiter(
      ExpandFileName(ParticleTexturePreviewMetadataDir));

    Count := 0;
    for I := 0 to SortedFiles.Count - 1 do
    begin
      FileName := SortedFiles[I];
      if not IsParticleTextureAssetFile(FileName) then
        Continue;
      if SameText(Copy(FileName, 1, Length(MetadataRoot)), MetadataRoot) then
        Continue;

      RelPath := ExtractRelativePath(TEnginePaths.ParticleTexturesDir,
        FileName);
      if Trim(RelPath) = '' then
        RelPath := ExtractFileName(FileName);

      Item := Default(TParticleTextureFileInfo);
      Item.FileName := FileName;
      Item.RelativePath := RelPath;
      Item.DisplayName := ExtractFileName(FileName);
      Item.CacheFileName := ParticleTexturePreviewCacheFileName(RelPath);
      try
        Item.FileSize := TFile.GetSize(FileName);
      except
        Item.FileSize := 0;
      end;
      Item.LastWriteStamp := TextureAssetFileStamp(FileName);

      SetLength(AItems, Count + 1);
      AItems[Count] := Item;
      Inc(Count);
    end;
  finally
    SortedFiles.Free;
  end;

  Result := True;
end;

function TSandBoxForm.BillboardTexturePreviewMetadataDir: string;
begin
  Result := TPath.Combine(TEnginePaths.BillboardTexturesDir,
    TEXTURE_PREVIEW_METADATA_DIRNAME);
end;

function TSandBoxForm.BillboardTexturePreviewCacheDir: string;
begin
  Result := TPath.Combine(BillboardTexturePreviewMetadataDir,
    TEXTURE_PREVIEW_CACHE_DIRNAME);
end;

function TSandBoxForm.BillboardTexturePreviewMetadataFile: string;
begin
  Result := TPath.Combine(BillboardTexturePreviewMetadataDir,
    TEXTURE_PREVIEW_METADATA_FILENAME);
end;

function TSandBoxForm.BillboardTexturePreviewCacheFileName(
  const ARelativePath: string): string;
var
  BaseName: string;
begin
  BaseName := ChangeFileExt(ExtractFileName(ARelativePath), '');
  if BaseName = '' then
    BaseName := 'billboard_texture';

  Result := TPath.Combine(BillboardTexturePreviewCacheDir,
    BaseName + '_' + IntToHex(HashTextFNV1a32(LowerCase(ARelativePath)), 8) +
    '.thumbbin');
end;

function TSandBoxForm.FindBillboardTextureIndex(
  const AItems: TArray<TBillboardTextureFileInfo>;
  const ARelativePath: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(AItems) do
    if SameText(AItems[I].RelativePath, ARelativePath) then
      Exit(I);

  Result := -1;
end;

function TSandBoxForm.BillboardTextureInventoryMatchesCurrent(
  const AItems: TArray<TBillboardTextureFileInfo>): Boolean;
var
  I: Integer;
begin
  Result := Length(AItems) = Length(fBillboardTextureBrowser.Items);
  if not Result then
    Exit;

  for I := 0 to High(AItems) do
    if not SameText(AItems[I].RelativePath,
         fBillboardTextureBrowser.Items[I].RelativePath) or
       (AItems[I].FileSize <> fBillboardTextureBrowser.Items[I].FileSize) or
       (AItems[I].LastWriteStamp <>
         fBillboardTextureBrowser.Items[I].LastWriteStamp) then
      Exit(False);
end;

procedure TSandBoxForm.ReleaseBillboardTexturePreviews(
  var AItems: TArray<TBillboardTextureFileInfo>);
var
  I: Integer;
  TexID: GLuint;
begin
  for I := 0 to High(AItems) do
  begin
    TexID := AItems[I].TextureID;
    if TexID <> 0 then
    begin
      glDeleteTextures(1, @TexID);
      AItems[I].TextureID := 0;
    end;
  end;
end;

procedure TSandBoxForm.LoadBillboardTexturePreviewMetadata(
  out AItems: TArray<TBillboardTextureFileInfo>);
var
  Lines: TStringList;
  Parts: TStringList;
  I, Count: Integer;
  Item: TBillboardTextureFileInfo;
begin
  SetLength(AItems, 0);
  if not FileExists(BillboardTexturePreviewMetadataFile) then
    Exit;

  Lines := TStringList.Create;
  Parts := TStringList.Create;
  try
    Lines.LoadFromFile(BillboardTexturePreviewMetadataFile);
    Parts.StrictDelimiter := True;
    Parts.Delimiter := #9;
    Count := 0;

    for I := 0 to Lines.Count - 1 do
    begin
      Parts.DelimitedText := Lines[I];
      if Parts.Count < 5 then
        Continue;

      Item := Default(TBillboardTextureFileInfo);
      Item.RelativePath := Parts[0];
      Item.DisplayName := ExtractFileName(Item.RelativePath);
      Item.CacheFileName := BillboardTexturePreviewCacheFileName(
        Item.RelativePath);
      Item.FileSize := StrToInt64Def(Parts[1], 0);
      Item.LastWriteStamp := StrToInt64Def(Parts[2], 0);
      Item.Width := StrToIntDef(Parts[3], 0);
      Item.Height := StrToIntDef(Parts[4], 0);

      SetLength(AItems, Count + 1);
      AItems[Count] := Item;
      Inc(Count);
    end;
  finally
    Parts.Free;
    Lines.Free;
  end;
end;

procedure TSandBoxForm.SaveBillboardTexturePreviewMetadata(
  const AItems: TArray<TBillboardTextureFileInfo>);
var
  Lines: TStringList;
  I: Integer;
begin
  ForceDirectories(BillboardTexturePreviewMetadataDir);
  ForceDirectories(BillboardTexturePreviewCacheDir);

  Lines := TStringList.Create;
  try
    for I := 0 to High(AItems) do
      if AItems[I].RelativePath <> '' then
        Lines.Add(AItems[I].RelativePath + #9 +
          IntToStr(AItems[I].FileSize) + #9 +
          IntToStr(AItems[I].LastWriteStamp) + #9 +
          IntToStr(AItems[I].Width) + #9 +
          IntToStr(AItems[I].Height));

    Lines.SaveToFile(BillboardTexturePreviewMetadataFile);
  finally
    Lines.Free;
  end;
end;

function TSandBoxForm.ScanBillboardTextureFiles(
  out AItems: TArray<TBillboardTextureFileInfo>): Boolean;
var
  Files: TArray<string>;
  SortedFiles: TStringList;
  MetadataRoot: string;
  I, Count: Integer;
  FileName: string;
  RelPath: string;
  Item: TBillboardTextureFileInfo;
begin
  Result := False;
  SetLength(AItems, 0);
  fBillboardTextureBrowser.LastError := '';

  TEnginePaths.EnsureDirectories;
  if not TDirectory.Exists(TEnginePaths.BillboardTexturesDir) then
  begin
    fBillboardTextureBrowser.LastError := 'Billboard texture folder does not exist: ' +
      TEnginePaths.BillboardTexturesDir;
    Exit;
  end;

  try
    Files := TDirectory.GetFiles(TEnginePaths.BillboardTexturesDir, '*.*',
      TSearchOption.soAllDirectories);
  except
    on E: Exception do
    begin
      fBillboardTextureBrowser.LastError := 'Could not scan billboard texture folder: ' +
        E.Message;
      Exit;
    end;
  end;

  SortedFiles := TStringList.Create;
  try
    SortedFiles.CaseSensitive := False;
    SortedFiles.Sorted := True;
    SortedFiles.Duplicates := dupIgnore;
    for I := 0 to High(Files) do
      SortedFiles.Add(ExpandFileName(Files[I]));

    MetadataRoot := IncludeTrailingPathDelimiter(
      ExpandFileName(BillboardTexturePreviewMetadataDir));

    Count := 0;
    for I := 0 to SortedFiles.Count - 1 do
    begin
      FileName := SortedFiles[I];
      if not IsBillboardTextureAssetFile(FileName) then
        Continue;
      if SameText(Copy(FileName, 1, Length(MetadataRoot)), MetadataRoot) then
        Continue;

      RelPath := ExtractRelativePath(TEnginePaths.BillboardTexturesDir,
        FileName);
      if Trim(RelPath) = '' then
        RelPath := ExtractFileName(FileName);

      Item := Default(TBillboardTextureFileInfo);
      Item.FileName := FileName;
      Item.RelativePath := RelPath;
      Item.DisplayName := ExtractFileName(FileName);
      Item.CacheFileName := BillboardTexturePreviewCacheFileName(RelPath);
      try
        Item.FileSize := TFile.GetSize(FileName);
      except
        Item.FileSize := 0;
      end;
      Item.LastWriteStamp := TextureAssetFileStamp(FileName);

      SetLength(AItems, Count + 1);
      AItems[Count] := Item;
      Inc(Count);
    end;
  finally
    SortedFiles.Free;
  end;

  Result := True;
end;

function TSandBoxForm.TryCreateParticleTexturePreview(const AFileName: string;
  AThumbSize: Integer; out TextureID: GLuint; out ImageWidth,
  ImageHeight: Integer): Boolean;
var
  SourcePixels: TBytes;
  ThumbPixels: TBytes;
  Ext: string;
begin
  Result := False;
  TextureID := 0;
  ImageWidth := 0;
  ImageHeight := 0;

  if (AFileName = '') or (not FileExists(AFileName)) then
    Exit;

  Ext := LowerCase(ExtractFileExt(AFileName));
  if Ext = '.dds' then
    Result := TryCreateDDSPreviewTexture(AFileName, AThumbSize, TextureID,
      ImageWidth, ImageHeight)
  else if Ext = '.tga' then
  begin
    if not TryLoadTargaPixelsRGBA(AFileName, SourcePixels, ImageWidth,
      ImageHeight) then
      Exit;

    if not TryBuildParticlePreviewPixels(SourcePixels, ImageWidth, ImageHeight,
      AThumbSize, ThumbPixels) then
      Exit;

    Result := TryCreateGLTextureFromPixels(ThumbPixels, AThumbSize, AThumbSize,
      TextureID);
  end
  else
    Result := TryCreateImagePreviewTexture(AFileName, AThumbSize, TextureID,
      ImageWidth, ImageHeight);
end;

procedure TSandBoxForm.ClearParticleTexturePreviews;
begin
  ReleaseParticleTexturePreviews(fParticleTextureBrowser.Items);
  SetLength(fParticleTextureBrowser.Items, 0);
end;

procedure TSandBoxForm.ClearBillboardTexturePreviews;
begin
  ReleaseBillboardTexturePreviews(fBillboardTextureBrowser.Items);
  SetLength(fBillboardTextureBrowser.Items, 0);
end;

procedure TSandBoxForm.RefreshParticleTextureList(const ForceRebuild: Boolean);
var
  OldItems: TArray<TParticleTextureFileInfo>;
  NewItems: TArray<TParticleTextureFileInfo>;
  CachedItems: TArray<TParticleTextureFileInfo>;
  I: Integer;
  OldIndex: Integer;
  CacheIndex: Integer;
  TexID: GLuint;
  W, H: Integer;
  CacheW, CacheH: Integer;
  Thumb: TBitmap;
  SourcePixels: TBytes;
  ThumbPixels: TBytes;
  Ext: string;
  SelectedRelativePath: string;
begin
  fParticleTextureBrowser.NeedsRefresh := False;
  fParticleTextureBrowser.LastError := '';
  if not ScanParticleTextureFiles(NewItems) then
    Exit;

  if Length(NewItems) = 0 then
  begin
    ClearParticleTexturePreviews;
    fParticleTextureBrowser.SelectedIndex := -1;
    fParticleTextureBrowser.LastError := 'No TGA/PNG particle textures found in ' +
      TEnginePaths.ParticleTexturesDir;
    Exit;
  end;

  if (not ForceRebuild) and ParticleTextureInventoryMatchesCurrent(NewItems) then
    Exit;

  SelectedRelativePath := '';
  if (fParticleTextureBrowser.SelectedIndex >= 0) and
     (fParticleTextureBrowser.SelectedIndex <=
      High(fParticleTextureBrowser.Items)) then
    SelectedRelativePath :=
      fParticleTextureBrowser.Items[fParticleTextureBrowser.SelectedIndex].RelativePath;

  ActivateMainRenderContext;
  OldItems := fParticleTextureBrowser.Items;
  LoadParticleTexturePreviewMetadata(CachedItems);

  for I := 0 to High(NewItems) do
  begin
    if not ForceRebuild then
    begin
      OldIndex := FindParticleTextureIndex(OldItems, NewItems[I].RelativePath);
      if (OldIndex >= 0) and
         (OldItems[OldIndex].FileSize = NewItems[I].FileSize) and
         (OldItems[OldIndex].LastWriteStamp = NewItems[I].LastWriteStamp) and
         (OldItems[OldIndex].TextureID <> 0) then
      begin
        NewItems[I].TextureID := OldItems[OldIndex].TextureID;
        NewItems[I].Width := OldItems[OldIndex].Width;
        NewItems[I].Height := OldItems[OldIndex].Height;
        NewItems[I].PreviewReady := OldItems[OldIndex].PreviewReady;
        OldItems[OldIndex].TextureID := 0;
        Continue;
      end;

      CacheIndex := FindParticleTextureIndex(CachedItems,
        NewItems[I].RelativePath);
      if (CacheIndex >= 0) and
         (CachedItems[CacheIndex].FileSize = NewItems[I].FileSize) and
         (CachedItems[CacheIndex].LastWriteStamp =
           NewItems[I].LastWriteStamp) and
         FileExists(NewItems[I].CacheFileName) then
      begin
        TexID := 0;
        CacheW := 0;
        CacheH := 0;
        if TryLoadThumbnailBinaryFromFile(NewItems[I].CacheFileName,
          NewItems[I].FileSize, NewItems[I].LastWriteStamp, TexID, CacheW,
          CacheH) then
        begin
          NewItems[I].TextureID := TexID;
          NewItems[I].Width := CachedItems[CacheIndex].Width;
          NewItems[I].Height := CachedItems[CacheIndex].Height;
          NewItems[I].PreviewReady := True;
          Continue;
        end;
      end;
    end;

    Ext := LowerCase(ExtractFileExt(NewItems[I].FileName));
    if Ext = '.dds' then
    begin
      TexID := 0;
      if TryCreateDDSPreviewTexture(NewItems[I].FileName,
        PARTICLE_TEXTURE_THUMB_SIZE, TexID, W, H) then
      begin
        NewItems[I].TextureID := TexID;
        NewItems[I].Width := W;
        NewItems[I].Height := H;
        NewItems[I].PreviewReady := True;
      end;
    end
    else if Ext = '.tga' then
    begin
      SourcePixels := nil;
      ThumbPixels := nil;
      if TryLoadTargaPixelsRGBA(NewItems[I].FileName, SourcePixels, W, H) and
         TryBuildParticlePreviewPixels(SourcePixels, W, H,
           PARTICLE_TEXTURE_THUMB_SIZE, ThumbPixels) then
      begin
        TexID := 0;
        if TryCreateGLTextureFromPixels(ThumbPixels,
          PARTICLE_TEXTURE_THUMB_SIZE, PARTICLE_TEXTURE_THUMB_SIZE,
          TexID) then
        begin
          NewItems[I].TextureID := TexID;
          NewItems[I].Width := W;
          NewItems[I].Height := H;
          NewItems[I].PreviewReady := True;
        end;
        SaveThumbnailPixelsToBinaryFile(ThumbPixels,
          PARTICLE_TEXTURE_THUMB_SIZE, PARTICLE_TEXTURE_THUMB_SIZE,
          NewItems[I].CacheFileName, NewItems[I].FileSize,
          NewItems[I].LastWriteStamp);
      end;
    end
    else
    begin
      Thumb := nil;
      if TryBuildImageThumbnailBitmap(NewItems[I].FileName,
        PARTICLE_TEXTURE_THUMB_SIZE, Thumb, W, H) then
      begin
        try
          TexID := 0;
          if TryCreateGLTextureFromBitmap(Thumb, TexID) then
          begin
            NewItems[I].TextureID := TexID;
            NewItems[I].Width := W;
            NewItems[I].Height := H;
            NewItems[I].PreviewReady := True;
          end;
          SaveThumbnailBitmapToBinaryFile(Thumb, NewItems[I].CacheFileName,
            NewItems[I].FileSize, NewItems[I].LastWriteStamp);
        finally
          Thumb.Free;
        end;
      end;
    end;
  end;

  ReleaseParticleTexturePreviews(OldItems);
  fParticleTextureBrowser.Items := NewItems;
  SaveParticleTexturePreviewMetadata(fParticleTextureBrowser.Items);
  fParticleTextureBrowser.SelectedIndex := FindParticleTextureIndex(
    fParticleTextureBrowser.Items, SelectedRelativePath);
end;

procedure TSandBoxForm.RefreshBillboardTextureList(const ForceRebuild: Boolean);
var
  OldItems: TArray<TBillboardTextureFileInfo>;
  NewItems: TArray<TBillboardTextureFileInfo>;
  CachedItems: TArray<TBillboardTextureFileInfo>;
  I: Integer;
  OldIndex: Integer;
  CacheIndex: Integer;
  TexID: GLuint;
  W, H: Integer;
  CacheW, CacheH: Integer;
  Thumb: TBitmap;
  SourcePixels: TBytes;
  ThumbPixels: TBytes;
  Ext: string;
  SelectedRelativePath: string;
begin
  fBillboardTextureBrowser.NeedsRefresh := False;
  fBillboardTextureBrowser.LastError := '';
  if not ScanBillboardTextureFiles(NewItems) then
    Exit;

  if Length(NewItems) = 0 then
  begin
    ClearBillboardTexturePreviews;
    fBillboardTextureBrowser.SelectedIndex := -1;
    fBillboardTextureBrowser.LastError := 'No TGA/PNG billboard textures found in ' +
      TEnginePaths.BillboardTexturesDir;
    Exit;
  end;

  if (not ForceRebuild) and BillboardTextureInventoryMatchesCurrent(NewItems) then
    Exit;

  SelectedRelativePath := '';
  if (fBillboardTextureBrowser.SelectedIndex >= 0) and
     (fBillboardTextureBrowser.SelectedIndex <=
      High(fBillboardTextureBrowser.Items)) then
    SelectedRelativePath :=
      fBillboardTextureBrowser.Items[fBillboardTextureBrowser.SelectedIndex].RelativePath;

  ActivateMainRenderContext;
  OldItems := fBillboardTextureBrowser.Items;
  LoadBillboardTexturePreviewMetadata(CachedItems);

  for I := 0 to High(NewItems) do
  begin
    if not ForceRebuild then
    begin
      OldIndex := FindBillboardTextureIndex(OldItems, NewItems[I].RelativePath);
      if (OldIndex >= 0) and
         (OldItems[OldIndex].FileSize = NewItems[I].FileSize) and
         (OldItems[OldIndex].LastWriteStamp = NewItems[I].LastWriteStamp) and
         (OldItems[OldIndex].TextureID <> 0) then
      begin
        NewItems[I].TextureID := OldItems[OldIndex].TextureID;
        NewItems[I].Width := OldItems[OldIndex].Width;
        NewItems[I].Height := OldItems[OldIndex].Height;
        NewItems[I].PreviewReady := OldItems[OldIndex].PreviewReady;
        OldItems[OldIndex].TextureID := 0;
        Continue;
      end;

      CacheIndex := FindBillboardTextureIndex(CachedItems,
        NewItems[I].RelativePath);
      if (CacheIndex >= 0) and
         (CachedItems[CacheIndex].FileSize = NewItems[I].FileSize) and
         (CachedItems[CacheIndex].LastWriteStamp =
           NewItems[I].LastWriteStamp) and
         FileExists(NewItems[I].CacheFileName) then
      begin
        TexID := 0;
        CacheW := 0;
        CacheH := 0;
        if TryLoadThumbnailBinaryFromFile(NewItems[I].CacheFileName,
          NewItems[I].FileSize, NewItems[I].LastWriteStamp, TexID, CacheW,
          CacheH) then
        begin
          NewItems[I].TextureID := TexID;
          NewItems[I].Width := CachedItems[CacheIndex].Width;
          NewItems[I].Height := CachedItems[CacheIndex].Height;
          NewItems[I].PreviewReady := True;
          Continue;
        end;
      end;

      Continue;
    end;

    Ext := LowerCase(ExtractFileExt(NewItems[I].FileName));
    if Ext = '.dds' then
    begin
      TexID := 0;
      if TryCreateDDSPreviewTexture(NewItems[I].FileName,
        BILLBOARD_TEXTURE_THUMB_SIZE, TexID, W, H) then
      begin
        NewItems[I].TextureID := TexID;
        NewItems[I].Width := W;
        NewItems[I].Height := H;
        NewItems[I].PreviewReady := True;
      end;
    end
    else if Ext = '.tga' then
    begin
      SourcePixels := nil;
      ThumbPixels := nil;
      if TryLoadTargaPixelsRGBA(NewItems[I].FileName, SourcePixels, W, H) and
         TryBuildParticlePreviewPixels(SourcePixels, W, H,
           BILLBOARD_TEXTURE_THUMB_SIZE, ThumbPixels) then
      begin
        TexID := 0;
        if TryCreateGLTextureFromPixels(ThumbPixels,
          BILLBOARD_TEXTURE_THUMB_SIZE, BILLBOARD_TEXTURE_THUMB_SIZE,
          TexID) then
        begin
          NewItems[I].TextureID := TexID;
          NewItems[I].Width := W;
          NewItems[I].Height := H;
          NewItems[I].PreviewReady := True;
        end;
        SaveThumbnailPixelsToBinaryFile(ThumbPixels,
          BILLBOARD_TEXTURE_THUMB_SIZE, BILLBOARD_TEXTURE_THUMB_SIZE,
          NewItems[I].CacheFileName, NewItems[I].FileSize,
          NewItems[I].LastWriteStamp);
      end;
    end
    else
    begin
      Thumb := nil;
      if TryBuildImageThumbnailBitmap(NewItems[I].FileName,
        BILLBOARD_TEXTURE_THUMB_SIZE, Thumb, W, H) then
      begin
        try
          TexID := 0;
          if TryCreateGLTextureFromBitmap(Thumb, TexID) then
          begin
            NewItems[I].TextureID := TexID;
            NewItems[I].Width := W;
            NewItems[I].Height := H;
            NewItems[I].PreviewReady := True;
          end;
          SaveThumbnailBitmapToBinaryFile(Thumb, NewItems[I].CacheFileName,
            NewItems[I].FileSize, NewItems[I].LastWriteStamp);
        finally
          Thumb.Free;
        end;
      end;
    end;
  end;

  ReleaseBillboardTexturePreviews(OldItems);
  fBillboardTextureBrowser.Items := NewItems;
  SaveBillboardTexturePreviewMetadata(fBillboardTextureBrowser.Items);
  fBillboardTextureBrowser.SelectedIndex := FindBillboardTextureIndex(
    fBillboardTextureBrowser.Items, SelectedRelativePath);
end;

procedure TSandBoxForm.ResetParticleTextureBrowser;
begin
  fParticleTextureBrowser.Active := False;
  fParticleTextureBrowser.NeedsRefresh := False;
  fParticleTextureBrowser.SelectedIndex := -1;
  fParticleTextureBrowser.LastError := '';
  SetAnsiBuffer(fParticleTextureBrowser.Search, '');
  if not fInImGuiFrame then
    ClearParticleTexturePreviews;
end;

procedure TSandBoxForm.ResetBillboardTextureBrowser;
begin
  fBillboardTextureBrowser.Active := False;
  fBillboardTextureBrowser.NeedsRefresh := False;
  fBillboardTextureBrowser.SelectedIndex := -1;
  fBillboardTextureBrowser.LastError := '';
  SetAnsiBuffer(fBillboardTextureBrowser.Search, '');
  if not fInImGuiFrame then
    ClearBillboardTexturePreviews;
end;

procedure TSandBoxForm.DrawOverwriteConfirmation(const AFileName, AKind,
  AIdSuffix: string; out ReplaceClicked, CancelClicked: Boolean);
begin
  ReplaceClicked := False;
  CancelClicked := False;

  ImGui.Separator;
  ImGui.TextWrapped(PAnsiChar(AnsiString(AKind + ' already exists.')));
  ImGui.TextWrapped(PAnsiChar(AnsiString(ExtractFileName(AFileName))));
  ImGui.TextWrapped(PAnsiChar(AnsiString('Replace it, or enter a different file name above.')));

  ReplaceClicked := ImGui.Button(PAnsiChar(AnsiString('Replace##Overwrite' +
    AIdSuffix)), ImVec2.New(-1, 0));

  if ImGui.Button(PAnsiChar(AnsiString('Cancel Replace##Overwrite' +
    AIdSuffix)), ImVec2.New(-1, 0)) then
    CancelClicked := True;
end;

procedure TSandBoxForm.ClearMaterialFilePreviews;
var
  I: Integer;
  TexID: GLuint;
begin
  for I := 0 to High(fMaterialFileBrowser.Items) do
  begin
    TexID := fMaterialFileBrowser.Items[I].TextureID;
    if TexID <> 0 then
    begin
      glDeleteTextures(1, @TexID);
      fMaterialFileBrowser.Items[I].TextureID := 0;
    end;
  end;

  SetLength(fMaterialFileBrowser.Items, 0);
end;

function TSandBoxForm.TryReadMaterialPreviewInfo(const AFileName: string;
  out DisplayName, Summary, PreviewTexturePath: string; out IsLibrary: Boolean): Boolean;
var
  Stream: TFileStream;
  Magic: array[0..7] of AnsiChar;
  Version: Integer;
  LibraryName: string;
  MaterialCount: Integer;
  MaterialName: string;
  MaterialType: TMaterialType;
  I: Integer;
  MaterialPreviewPath: string;
begin
  Result := False;
  DisplayName := ChangeFileExt(ExtractFileName(AFileName), '');
  Summary := '';
  PreviewTexturePath := '';
  IsLibrary := False;

  if not FileExists(AFileName) then
    Exit;

  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    if Stream.Size < SizeOf(Magic) + SizeOf(Version) then
      Exit;

    Stream.ReadBuffer(Magic[0], SizeOf(Magic));
    Stream.Position := 0;

    if PreviewMagicMatches(Magic, MATERIAL_FILE_MAGIC_LOCAL) then
    begin
      if not TryReadMaterialPreviewFromStream(Stream, MaterialName,
        MaterialPreviewPath, MaterialType) then
        Exit;

      if Trim(MaterialName) <> '' then
        DisplayName := MaterialName;

      Summary := MaterialTypeDisplayName(MaterialType) + ' material';
      PreviewTexturePath := MaterialPreviewPath;
      Result := True;
    end
    else if PreviewMagicMatches(Magic, MATERIAL_LIBRARY_MAGIC_LOCAL) then
    begin
      IsLibrary := True;
      Stream.ReadBuffer(Magic[0], SizeOf(Magic));
      Stream.ReadBuffer(Version, SizeOf(Version));
      if (Version < 1) or (Version > MATERIAL_FILE_VERSION_LOCAL) then
        Exit;

      LibraryName := ReadPreviewString(Stream);
      if Trim(LibraryName) <> '' then
        DisplayName := LibraryName;

      Stream.ReadBuffer(MaterialCount, SizeOf(MaterialCount));
      if MaterialCount < 0 then
        Exit;

      Summary := Format('%d material(s)', [MaterialCount]);
      for I := 0 to MaterialCount - 1 do
      begin
        MaterialName := '';
        MaterialPreviewPath := '';
        if not TryReadMaterialPreviewFromStream(Stream, MaterialName,
          MaterialPreviewPath, MaterialType) then
          Break;

        if (PreviewTexturePath = '') and FileExists(MaterialPreviewPath) then
          PreviewTexturePath := MaterialPreviewPath;
      end;

      Result := True;
    end;
  finally
    Stream.Free;
  end;
end;

procedure TSandBoxForm.RefreshMaterialFileList;
var
  Files: TArray<string>;
  I: Integer;
  Count: Integer;
  Item: TMaterialFileInfo;
  TexID: GLuint;
  W, H: Integer;
  PreviewCacheFileName: string;
  PreviewFileSize: Int64;
  PreviewStamp: Int64;
  Thumb: TBitmap;
  Ext: string;
begin
  ActivateMainRenderContext;
  ClearMaterialFilePreviews;

  fMaterialFileBrowser.NeedsRefresh := False;
  fMaterialFileBrowser.SelectedIndex := -1;
  fMaterialFileBrowser.LastError := '';

  TEnginePaths.EnsureDirectories;
  if not TDirectory.Exists(TEnginePaths.MaterialsDir) then
  begin
    fMaterialFileBrowser.LastError := 'Materials folder does not exist: ' +
      TEnginePaths.MaterialsDir;
    Exit;
  end;

  try
    Files := TDirectory.GetFiles(TEnginePaths.MaterialsDir, '*.*',
      TSearchOption.soAllDirectories);
  except
    on E: Exception do
    begin
      fMaterialFileBrowser.LastError := 'Could not scan materials folder: ' +
        E.Message;
      Exit;
    end;
  end;

  Count := 0;
  for I := 0 to High(Files) do
  begin
    if not IsMaterialAssetFile(Files[I]) then
      Continue;

    Item := Default(TMaterialFileInfo);
    Item.FileName := Files[I];
    Item.RelativePath := TEnginePaths.ToAssetRelativePath(Files[I]);

    if not TryReadMaterialPreviewInfo(Files[I], Item.DisplayName, Item.Summary,
      Item.PreviewTexturePath, Item.IsLibrary) then
    begin
      Item.DisplayName := ChangeFileExt(ExtractFileName(Files[I]), '');
      if SameText(ExtractFileExt(Files[I]), '.omeml') then
      begin
        Item.Summary := 'Material library';
        Item.IsLibrary := True;
      end
      else
        Item.Summary := 'Material';
    end;

    TexID := 0;
    W := 0;
    H := 0;
    if (Item.PreviewTexturePath <> '') and FileExists(Item.PreviewTexturePath) then
    begin
      try
        PreviewFileSize := TFile.GetSize(Item.PreviewTexturePath);
      except
        PreviewFileSize := 0;
      end;
      PreviewStamp := TextureAssetFileStamp(Item.PreviewTexturePath);
      PreviewCacheFileName := TexturePreviewCacheFileName(
        TEnginePaths.ToAssetRelativePath(Item.PreviewTexturePath));

      if TryLoadThumbnailBinaryFromFile(PreviewCacheFileName, PreviewFileSize,
        PreviewStamp, TexID, W, H) then
      begin
        Item.TextureID := TexID;
        Item.Width := W;
        Item.Height := H;
        Item.PreviewReady := True;
      end
      else
      begin
        Ext := LowerCase(ExtractFileExt(Item.PreviewTexturePath));
        if Ext = '.dds' then
        begin
          if TryCreateDDSPreviewTexture(Item.PreviewTexturePath,
            MATERIAL_FILE_THUMB_SIZE, TexID, W, H) then
          begin
            Item.TextureID := TexID;
            Item.Width := W;
            Item.Height := H;
            Item.PreviewReady := True;
          end;
        end
        else
        begin
          Thumb := nil;
          if TryBuildImageThumbnailBitmap(Item.PreviewTexturePath,
            MATERIAL_FILE_THUMB_SIZE, Thumb, W, H) then
          begin
            try
              if TryCreateGLTextureFromBitmap(Thumb, TexID) then
              begin
                Item.TextureID := TexID;
                Item.Width := W;
                Item.Height := H;
                Item.PreviewReady := True;
              end;
              SaveThumbnailBitmapToBinaryFile(Thumb, PreviewCacheFileName,
                PreviewFileSize, PreviewStamp);
            finally
              Thumb.Free;
            end;
          end;
        end;
      end;
    end;

    SetLength(fMaterialFileBrowser.Items, Count + 1);
    fMaterialFileBrowser.Items[Count] := Item;
    Inc(Count);
  end;

  if Count = 0 then
    fMaterialFileBrowser.LastError := 'No material files found in ' +
      TEnginePaths.MaterialsDir;
end;

procedure TSandBoxForm.ResetMaterialFileBrowser;
begin
  fMaterialFileBrowser.Active := False;
  fMaterialFileBrowser.NeedsRefresh := False;
  fMaterialFileBrowser.Mode := mfbNone;
  fMaterialFileBrowser.SelectedIndex := -1;
  fMaterialFileBrowser.PendingOverwrite := False;
  fMaterialFileBrowser.PendingOverwriteFileName := '';
  fMaterialFileBrowser.LastError := '';
  SetAnsiBuffer(fMaterialFileBrowser.Search, '');
  SetAnsiBuffer(fMaterialFileBrowser.FileName, '');

  if not fInImGuiFrame then
    ClearMaterialFilePreviews;
end;

procedure TSandBoxForm.OpenMaterialFileBrowser(AMode: TMaterialFileBrowserMode);
var
  Mat: TMaterial;
  Lib: TMaterialLibrary;
begin
  fMaterialFileBrowser.Active := True;
  fMaterialFileBrowser.NeedsRefresh := True;
  fMaterialFileBrowser.Mode := AMode;
  fMaterialFileBrowser.SelectedIndex := -1;
  fMaterialFileBrowser.PendingOverwrite := False;
  fMaterialFileBrowser.PendingOverwriteFileName := '';
  fMaterialFileBrowser.LastError := '';

  case AMode of
    mfbSaveMaterial:
      begin
        Mat := SelectedMaterialEditorMaterial;
        if Mat <> nil then
          SetAnsiBuffer(fMaterialFileBrowser.FileName, Mat.Name + '.omemat')
        else
          SetAnsiBuffer(fMaterialFileBrowser.FileName, 'Material.omemat');
      end;

    mfbSaveLibrary:
      begin
        Lib := SelectedMaterialEditorLibrary;
        if Lib <> nil then
          SetAnsiBuffer(fMaterialFileBrowser.FileName, Lib.Name + '.omeml')
        else
          SetAnsiBuffer(fMaterialFileBrowser.FileName, 'MaterialLibrary.omeml');
      end;
  else
    SetAnsiBuffer(fMaterialFileBrowser.FileName, '');
  end;
end;

procedure TSandBoxForm.SaveSelectedMaterialToFile(const AFileName: string);
var
  Mat: TMaterial;
  TargetDir: string;
begin
  fMaterialFileBrowser.LastError := '';
  Mat := SelectedMaterialEditorMaterial;
  if Mat = nil then
  begin
    fMaterialFileBrowser.LastError := 'Select a material first.';
    Exit;
  end;

  if IsEditorOnlyMaterial(Mat) then
  begin
    fMaterialFileBrowser.LastError := 'Editor-only materials cannot be saved.';
    Exit;
  end;

  TargetDir := ExtractFilePath(AFileName);
  if TargetDir <> '' then
    ForceDirectories(TargetDir);

  AssignShaderToMaterial(Mat);
  Mat.SaveToFile(AFileName);
  LogLine('Material saved: ' + AFileName);
end;

procedure TSandBoxForm.SaveSelectedMaterialLibraryToFile(const AFileName: string);
var
  Lib: TMaterialLibrary;
  Stream: TFileStream;
  Version: Integer;
begin
  fMaterialFileBrowser.LastError := '';
  Lib := SelectedMaterialEditorLibrary;
  if Lib = nil then
  begin
    fMaterialFileBrowser.LastError := 'Select a material library first.';
    Exit;
  end;

  ForceDirectories(ExtractFilePath(AFileName));
  Stream := TFileStream.Create(AFileName, fmCreate);
  try
    Stream.WriteBuffer(MATERIAL_LIBRARY_MAGIC_LOCAL[0], SizeOf(MATERIAL_LIBRARY_MAGIC_LOCAL));
    Version := MATERIAL_FILE_VERSION_LOCAL;
    Stream.WriteBuffer(Version, SizeOf(Version));
    Lib.SaveToStream(Stream, GIZMO_MATERIAL_NAME);
  finally
    Stream.Free;
  end;

  LogLine('Material library saved: ' + AFileName);
end;

procedure TSandBoxForm.LoadMaterialIntoSelectedLibrary(const AFileName: string);
var
  Lib: TMaterialLibrary;
  Mat: TMaterial;
begin
  fMaterialFileBrowser.LastError := '';
  Lib := SelectedMaterialEditorLibrary;
  if Lib = nil then
  begin
    fMaterialFileBrowser.LastError := 'Select a material library first.';
    Exit;
  end;

  Mat := TMaterial.LoadFromFile(AFileName, fShader);
  try
    Mat.Name := MakeUniqueMaterialName(Lib, Mat.Name);
    AssignShaderToMaterial(Mat);
    fMaterialEditor.SelectedMaterialIndex := Lib.AddMaterial(Mat);
    fMaterialEditor.SelectedTextureIndex := 0;
    SyncTextureAssetSelectionToCurrentTexture;
    Mat := nil;
  finally
    Mat.Free;
  end;

  LogLine('Material loaded: ' + AFileName);
end;

procedure TSandBoxForm.LoadMaterialLibraryFromFile(const AFileName: string);
var
  Lib: TMaterialLibrary;
  I: Integer;
begin
  Lib := TMaterialLibrary.Create;
  try
    Lib.LoadFromFile(AFileName, fShader);
    Lib.Name := MakeUniqueMaterialLibraryName(Lib.Name);
    for I := 0 to Lib.Count - 1 do
      if Assigned(Lib.Material[I]) then
        AssignShaderToMaterial(Lib.Material[I]);

    if MaterialLibraries = nil then
      MaterialLibraries := TMaterialLibraries.Create;

    MaterialLibraries.AddMaterialLibrary(Lib);
    fMaterialEditor.SelectedLibraryIndex := MaterialLibraries.Count - 1;
    fMaterialEditor.SelectedMaterialIndex :=
      FirstRenderableMaterialIndex(MaterialLibraries.MaterialLibrary[fMaterialEditor.SelectedLibraryIndex]);
    fMaterialEditor.SelectedTextureIndex := 0;
    SyncTextureAssetSelectionToCurrentTexture;
    Lib := nil;
  finally
    Lib.Free;
  end;

  LogLine('Material library loaded: ' + AFileName);
end;

procedure TSandBoxForm.ExecuteMaterialFileBrowserAction;
var
  FileName: string;
  Ext: string;
  Item: TMaterialFileInfo;
begin
  fMaterialFileBrowser.LastError := '';
  FileName := '';

  case fMaterialFileBrowser.Mode of
    mfbLoadMaterial, mfbLoadLibrary:
      begin
        if (fMaterialFileBrowser.SelectedIndex < 0) or
           (fMaterialFileBrowser.SelectedIndex > High(fMaterialFileBrowser.Items)) then
        begin
          fMaterialFileBrowser.LastError := 'Select a file first.';
          Exit;
        end;

        Item := fMaterialFileBrowser.Items[fMaterialFileBrowser.SelectedIndex];
        FileName := Item.FileName;
      end;

    mfbSaveMaterial, mfbSaveLibrary:
      begin
        FileName := Trim(AnsiBufferText(fMaterialFileBrowser.FileName));
        if FileName = '' then
        begin
          fMaterialFileBrowser.LastError := 'Enter a file name first.';
          Exit;
        end;

        if not TPath.IsPathRooted(FileName) then
          FileName := TPath.Combine(TEnginePaths.MaterialsDir, FileName);

        Ext := LowerCase(ExtractFileExt(FileName));
        if (fMaterialFileBrowser.Mode = mfbSaveMaterial) and (Ext = '') then
          FileName := ChangeFileExt(FileName, '.omemat')
        else if (fMaterialFileBrowser.Mode = mfbSaveLibrary) and (Ext = '') then
          FileName := ChangeFileExt(FileName, '.omeml');

        if FileExists(FileName) and
           ((not fMaterialFileBrowser.PendingOverwrite) or
            (not SameText(fMaterialFileBrowser.PendingOverwriteFileName, FileName))) then
        begin
          fMaterialFileBrowser.PendingOverwrite := True;
          fMaterialFileBrowser.PendingOverwriteFileName := FileName;
          fMaterialFileBrowser.LastError := '';
          Exit;
        end;
      end;
  end;

  case fMaterialFileBrowser.Mode of
    mfbLoadMaterial: LoadMaterialIntoSelectedLibrary(FileName);
    mfbSaveMaterial: SaveSelectedMaterialToFile(FileName);
    mfbLoadLibrary: LoadMaterialLibraryFromFile(FileName);
    mfbSaveLibrary: SaveSelectedMaterialLibraryToFile(FileName);
  end;

  if fMaterialFileBrowser.LastError <> '' then
    Exit;

  ResetMaterialFileBrowser;
  RequestRender;
end;

function TSandBoxForm.IsModelAssetFile(const AFileName: string): Boolean;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(AFileName));
  Result := (Ext = '.obj') or (Ext = '.gltf') or (Ext = '.glb');
end;

procedure TSandBoxForm.RefreshModelFileList;
var
  Files: TArray<string>;
  I: Integer;
  Count: Integer;
  Item: TModelFileInfo;
  ModifiedAt: TDateTime;

  function FormatFileSize(const Size: Int64): string;
  begin
    if Size >= 1024 * 1024 then
      Result := FormatFloat('0.0 MB', Size / (1024 * 1024))
    else if Size >= 1024 then
      Result := FormatFloat('0.0 KB', Size / 1024)
    else
      Result := IntToStr(Size) + ' B';
  end;

begin
  fModelFileBrowser.NeedsRefresh := False;
  fModelFileBrowser.SelectedIndex := -1;
  fModelFileBrowser.LastError := '';
  SetLength(fModelFileBrowser.Items, 0);

  TEnginePaths.EnsureDirectories;
  if not TDirectory.Exists(TEnginePaths.ModelsDir) then
  begin
    fModelFileBrowser.LastError := 'Models folder does not exist: ' +
      TEnginePaths.ModelsDir;
    Exit;
  end;

  try
    Files := TDirectory.GetFiles(TEnginePaths.ModelsDir, '*.*',
      TSearchOption.soAllDirectories);
  except
    on E: Exception do
    begin
      fModelFileBrowser.LastError := 'Could not scan models folder: ' +
        E.Message;
      Exit;
    end;
  end;

  Count := 0;
  for I := 0 to High(Files) do
  begin
    if not IsModelAssetFile(Files[I]) then
      Continue;
    if (fModelFileBrowser.Mode in [modelBrowserLoadWindTree,
         modelBrowserLoadAnimationClips]) and
       (not (SameText(ExtractFileExt(Files[I]), '.gltf') or
             SameText(ExtractFileExt(Files[I]), '.glb'))) then
      Continue;

    Item := Default(TModelFileInfo);
    Item.FileName := Files[I];
    Item.RelativePath := TEnginePaths.ToAssetRelativePath(Files[I]);
    Item.DisplayName := ChangeFileExt(ExtractFileName(Files[I]), '');
    Item.FileSize := 0;
    try
      Item.FileSize := TFile.GetSize(Files[I]);
      ModifiedAt := TFile.GetLastWriteTime(Files[I]);
      Item.ModifiedText := FormatDateTime('yyyy-mm-dd hh:nn', ModifiedAt);
    except
      Item.ModifiedText := '';
    end;

    if fModelFileBrowser.Mode = modelBrowserLoadAnimationClips then
      Item.Summary := UpperCase(Copy(ExtractFileExt(Files[I]), 2, MaxInt)) +
        ' animation, ' + FormatFileSize(Item.FileSize)
    else if fModelFileBrowser.Mode = modelBrowserLoadWindTree then
      Item.Summary := UpperCase(Copy(ExtractFileExt(Files[I]), 2, MaxInt)) +
        ' skinned tree model, ' + FormatFileSize(Item.FileSize)
    else if fModelFileBrowser.Mode = modelBrowserLoadVertexWindTree then
      Item.Summary := UpperCase(Copy(ExtractFileExt(Files[I]), 2, MaxInt)) +
        ' vertex-wind tree model, ' + FormatFileSize(Item.FileSize)
    else
      Item.Summary := UpperCase(Copy(ExtractFileExt(Files[I]), 2, MaxInt)) +
        ' model, ' + FormatFileSize(Item.FileSize);
    if Item.ModifiedText <> '' then
      Item.Summary := Item.Summary + ', modified ' + Item.ModifiedText;
    Item.Selected := False;

    SetLength(fModelFileBrowser.Items, Count + 1);
    fModelFileBrowser.Items[Count] := Item;
    Inc(Count);
  end;

  if Count = 0 then
  begin
    if fModelFileBrowser.Mode = modelBrowserLoadAnimationClips then
      fModelFileBrowser.LastError := 'No glTF/GLB animation files found in ' +
        TEnginePaths.ModelsDir
    else if fModelFileBrowser.Mode = modelBrowserLoadWindTree then
      fModelFileBrowser.LastError := 'No glTF/GLB tree model files found in ' +
        TEnginePaths.ModelsDir
    else if fModelFileBrowser.Mode = modelBrowserLoadVertexWindTree then
      fModelFileBrowser.LastError := 'No OBJ/glTF tree model files found in ' +
        TEnginePaths.ModelsDir
    else
      fModelFileBrowser.LastError := 'No OBJ/glTF model files found in ' +
        TEnginePaths.ModelsDir;
  end;
end;

procedure TSandBoxForm.ResetModelFileBrowser;
begin
  fModelFileBrowser.Active := False;
  fModelFileBrowser.Mode := modelBrowserLoadObject;
  fModelFileBrowser.CreateAsObject := True;
  fModelFileBrowser.CreateWindTree := False;
  fModelFileBrowser.CreateVertexWindTree := False;
  fModelFileBrowser.NeedsRefresh := False;
  fModelFileBrowser.SelectedIndex := -1;
  fModelFileBrowser.LastError := '';
  SetAnsiBuffer(fModelFileBrowser.Search, '');
  SetLength(fModelFileBrowser.Items, 0);
end;

procedure TSandBoxForm.OpenModelFileBrowser(CreateAsObject,
  CreateWindTree, CreateVertexWindTree: Boolean);
begin
  fModelFileBrowser.Active := True;
  if CreateWindTree then
    fModelFileBrowser.Mode := modelBrowserLoadWindTree
  else if CreateVertexWindTree then
    fModelFileBrowser.Mode := modelBrowserLoadVertexWindTree
  else if CreateAsObject then
    fModelFileBrowser.Mode := modelBrowserLoadObject
  else
    fModelFileBrowser.Mode := modelBrowserAddMesh;
  fModelFileBrowser.CreateAsObject := CreateAsObject;
  fModelFileBrowser.CreateWindTree := CreateWindTree;
  fModelFileBrowser.CreateVertexWindTree := CreateVertexWindTree;
  fModelFileBrowser.AutoPlayFirstAnimation := not (CreateWindTree or
    CreateVertexWindTree);
  fModelFileBrowser.NeedsRefresh := True;
  fModelFileBrowser.SelectedIndex := -1;
  fModelFileBrowser.LastError := '';
  SetAnsiBuffer(fModelFileBrowser.Search, '');
end;

procedure TSandBoxForm.OpenAnimationFileBrowser;
begin
  fModelFileBrowser.Active := True;
  fModelFileBrowser.Mode := modelBrowserLoadAnimationClips;
  fModelFileBrowser.CreateAsObject := False;
  fModelFileBrowser.CreateWindTree := False;
  fModelFileBrowser.CreateVertexWindTree := False;
  fModelFileBrowser.NeedsRefresh := True;
  fModelFileBrowser.SelectedIndex := -1;
  fModelFileBrowser.LastError := '';
  SetAnsiBuffer(fModelFileBrowser.Search, '');
end;

procedure TSandBoxForm.ExecuteModelFileBrowserAction;
var
  Item: TModelFileInfo;
  FileNames: TArray<string>;
  I, Count: Integer;
begin
  fModelFileBrowser.LastError := '';
  if fModelFileBrowser.Mode = modelBrowserLoadAnimationClips then
  begin
    Count := 0;
    for I := 0 to High(fModelFileBrowser.Items) do
      if fModelFileBrowser.Items[I].Selected then
      begin
        SetLength(FileNames, Count + 1);
        FileNames[Count] := fModelFileBrowser.Items[I].FileName;
        Inc(Count);
      end;

    if Count = 0 then
    begin
      fModelFileBrowser.LastError := 'Select one or more animation files first.';
      Exit;
    end;

    ImportAnimationFilesFromImGui(FileNames);
    Exit;
  end;

  if (fModelFileBrowser.SelectedIndex < 0) or
     (fModelFileBrowser.SelectedIndex > High(fModelFileBrowser.Items)) then
  begin
    fModelFileBrowser.LastError := 'Select a model file first.';
    Exit;
  end;

  Item := fModelFileBrowser.Items[fModelFileBrowser.SelectedIndex];
  ImportMeshFileFromImGui(Item.FileName, fModelFileBrowser.CreateAsObject,
    fModelFileBrowser.CreateWindTree,
    fModelFileBrowser.CreateVertexWindTree);
end;

function TSandBoxForm.IsSceneAssetFile(const AFileName: string): Boolean;
begin
  Result := SameText(ExtractFileExt(AFileName), SCENE_FILE_EXTENSION_LOCAL);
end;

function TSandBoxForm.TryReadScenePreviewInfo(const AFileName: string;
  out SceneName, Summary: string; out FileSize: Int64;
  out ModifiedText: string): Boolean;
var
  Stream: TFileStream;
  Magic: array[0..7] of AnsiChar;
  Version: Integer;
  ModifiedAt: TDateTime;

  function FormatFileSize(const Size: Int64): string;
  begin
    if Size >= 1024 * 1024 then
      Result := FormatFloat('0.0 MB', Size / (1024 * 1024))
    else if Size >= 1024 then
      Result := FormatFloat('0.0 KB', Size / 1024)
    else
      Result := IntToStr(Size) + ' B';
  end;
begin
  Result := False;
  SceneName := ChangeFileExt(ExtractFileName(AFileName), '');
  Summary := '';
  FileSize := 0;
  ModifiedText := '';

  if not FileExists(AFileName) then
    Exit;

  try
    FileSize := TFile.GetSize(AFileName);
    ModifiedAt := TFile.GetLastWriteTime(AFileName);
    ModifiedText := FormatDateTime('yyyy-mm-dd hh:nn', ModifiedAt);
  except
    ModifiedText := '';
  end;

  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    if Stream.Size < SizeOf(Magic) + SizeOf(Version) then
      Exit;

    Stream.ReadBuffer(Magic[0], SizeOf(Magic));
    if not PreviewMagicMatches(Magic, SCENE_FILE_MAGIC_LOCAL) then
      Exit;

    Stream.ReadBuffer(Version, SizeOf(Version));
    if (Version < 1) or (Version > SCENE_FILE_VERSION_LOCAL) then
      Exit;

    SceneName := ReadPreviewString(Stream);
    if Trim(SceneName) = '' then
      SceneName := ChangeFileExt(ExtractFileName(AFileName), '');

    Summary := Format('Scene file, version %d, %s', [Version,
      FormatFileSize(FileSize)]);
    if ModifiedText <> '' then
      Summary := Summary + ', modified ' + ModifiedText;

    Result := True;
  finally
    Stream.Free;
  end;
end;

procedure TSandBoxForm.RefreshSceneFileList;
var
  Files: TArray<string>;
  I: Integer;
  Count: Integer;
  Item: TSceneFileInfo;
begin
  fSceneFileBrowser.NeedsRefresh := False;
  fSceneFileBrowser.SelectedIndex := -1;
  fSceneFileBrowser.LastError := '';
  SetLength(fSceneFileBrowser.Items, 0);

  TEnginePaths.EnsureDirectories;
  if not TDirectory.Exists(TEnginePaths.ScenesDir) then
  begin
    fSceneFileBrowser.LastError := 'Scenes folder does not exist: ' +
      TEnginePaths.ScenesDir;
    Exit;
  end;

  try
    Files := TDirectory.GetFiles(TEnginePaths.ScenesDir,
      '*' + SCENE_FILE_EXTENSION_LOCAL, TSearchOption.soTopDirectoryOnly);
  except
    on E: Exception do
    begin
      fSceneFileBrowser.LastError := 'Could not scan scenes folder: ' +
        E.Message;
      Exit;
    end;
  end;

  Count := 0;
  for I := 0 to High(Files) do
  begin
    if not IsSceneAssetFile(Files[I]) then
      Continue;

    Item := Default(TSceneFileInfo);
    Item.FileName := Files[I];
    Item.RelativePath := ExtractFileName(Files[I]);
    Item.DisplayName := ChangeFileExt(ExtractFileName(Files[I]), '');
    Item.ValidScene := TryReadScenePreviewInfo(Files[I], Item.SceneName,
      Item.Summary, Item.FileSize, Item.ModifiedText);

    if Item.SceneName <> '' then
      Item.DisplayName := Item.SceneName;
    if Item.Summary = '' then
      Item.Summary := 'Scene file';

    SetLength(fSceneFileBrowser.Items, Count + 1);
    fSceneFileBrowser.Items[Count] := Item;
    Inc(Count);
  end;

  if Count = 0 then
    fSceneFileBrowser.LastError := 'No scene files found in ' +
      TEnginePaths.ScenesDir;
end;

procedure TSandBoxForm.ResetSceneFileBrowser;
begin
  fSceneFileBrowser.Active := False;
  fSceneFileBrowser.NeedsRefresh := False;
  fSceneFileBrowser.Mode := sfbNone;
  fSceneFileBrowser.SelectedIndex := -1;
  fSceneFileBrowser.PendingOverwrite := False;
  fSceneFileBrowser.PendingOverwriteFileName := '';
  fSceneFileBrowser.LastError := '';
  SetAnsiBuffer(fSceneFileBrowser.Search, '');
  SetAnsiBuffer(fSceneFileBrowser.FileName, '');
  SetLength(fSceneFileBrowser.Items, 0);
end;

procedure TSandBoxForm.OpenSceneFileBrowser(AMode: TSceneFileBrowserMode);
var
  DefaultName: string;
begin
  fSceneFileBrowser.Active := True;
  fSceneFileBrowser.NeedsRefresh := True;
  fSceneFileBrowser.Mode := AMode;
  fSceneFileBrowser.SelectedIndex := -1;
  fSceneFileBrowser.PendingOverwrite := False;
  fSceneFileBrowser.PendingOverwriteFileName := '';
  fSceneFileBrowser.LastError := '';

  if AMode = sfbSaveScene then
  begin
    DefaultName := '';
    if Assigned(fSceneManager) then
      DefaultName := Trim(fSceneManager.Name);
    if DefaultName = '' then
      DefaultName := 'Scene';
    SetAnsiBuffer(fSceneFileBrowser.FileName,
      ChangeFileExt(DefaultName, SCENE_FILE_EXTENSION_LOCAL));
  end
  else
    SetAnsiBuffer(fSceneFileBrowser.FileName, '');
end;

function TSandBoxForm.FindFirstLightSceneObject(Obj: TSceneObject): TSceneObject;
var
  I: Integer;
begin
  if fEngine <> nil then
    Exit(fEngine.FindFirstLightSceneObject(Obj));

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

procedure TSandBoxForm.ConfigureLightDefaults(Light: TLight; ALightType: TLightType);
begin
  if fEngine <> nil then
  begin
    fEngine.ConfigureLightDefaults(Light, ALightType);
    Exit;
  end;

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

function TSandBoxForm.EnsureLightBillboard(Obj: TSceneObject): TBillboard;
var
  I: Integer;
  Billboard: TBillboard;
begin
  Result := nil;
  if (Obj = nil) or (Obj.LightsCount <= 0) then
    Exit;

  for I := 0 to Obj.BillboardCount - 1 do
  begin
    Billboard := Obj.BillboardItem[I];
    if Billboard = nil then
      Continue;

    if SameText(Billboard.TexturePath, LIGHT_BILLBOARD_TEXTURE_PATH) or
       SameText(Billboard.Name, LIGHT_BILLBOARD_NAME) then
    begin
      Result := Billboard;
      Break;
    end;
  end;

  if Result = nil then
  begin
    Result := Obj.AddBillboard;
    Result.Name := LIGHT_BILLBOARD_NAME;
    Result.Width := LIGHT_BILLBOARD_SIZE;
    Result.Height := LIGHT_BILLBOARD_SIZE;
    Result.Offset := Vector3(0, 0, 0);
    Result.Color := Vector4(1, 1, 1, 1);
    Result.BlendMode := bbAlpha;
    Result.AlphaCutoff := 0.05;
  end;

  Result.TexturePath := LIGHT_BILLBOARD_TEXTURE_PATH;
  Result.Enabled := True;
end;

procedure TSandBoxForm.EnsureLightBillboards(Obj: TSceneObject);
var
  I: Integer;
begin
  if Obj = nil then
    Exit;

  EnsureLightBillboard(Obj);

  for I := 0 to Obj.Count - 1 do
    EnsureLightBillboards(Obj.ObjectList[I]);
end;

procedure TSandBoxForm.RestoreSceneAfterLoad;
var
  Lib: TMaterialLibrary;

  function FindMaterialLibraryByMaterialName(const MaterialName: string): TMaterialLibrary;
  var
    I: Integer;
    Candidate: TMaterialLibrary;
  begin
    Result := nil;
    if (MaterialLibraries = nil) or (Trim(MaterialName) = '') then
      Exit;

    for I := 0 to MaterialLibraries.Count - 1 do
    begin
      Candidate := MaterialLibraries.MaterialLibrary[I];
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

    if (MaterialLibraries <> nil) and (Trim(Mesh.MaterialLibraryName) <> '') then
    begin
      Result := MaterialLibraries.GetMaterialLibrary(Mesh.MaterialLibraryName);
      if (Result <> nil) and
         ((MaterialName = '') or (MaterialIndexInLibrary(Result, MaterialName) >= 0)) then
        Exit;
    end;

    Result := FindMaterialLibraryByMaterialName(MaterialName);
    if Result = nil then
      Result := Lib;
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
        MeshLib := Lib;

      if (MaterialName = '') or (MaterialIndexInLibrary(MeshLib, MaterialName) < 0) then
      begin
        FallbackIndex := FirstRenderableMaterialIndex(MeshLib);
        if (FallbackIndex < 0) and (MeshLib <> Lib) then
        begin
          MeshLib := Lib;
          FallbackIndex := FirstRenderableMaterialIndex(MeshLib);
        end;

        if FallbackIndex >= 0 then
          MaterialName := MeshLib.Material[FallbackIndex].Name
        else
          MaterialName := DEFAULT_PBR_MATERIAL_NAME;
      end;

      Mesh.MaterialLibrary := MeshLib;
      Mesh.LibMaterialname := MaterialName;
    end;

    Obj.UpdateBoundingRadiusFromMesh;
    for I := 0 to Obj.Count - 1 do
      RestoreObject(Obj.ObjectList[I]);
  end;
begin
  if fSceneManager = nil then
    Exit;

  fRoot := fSceneManager.Root;
  fPhysicsRunning := False;
  if Assigned(fPhysicsWorld) then
    fPhysicsWorld.SceneRoot := fRoot;
  Lib := EnsureDefaultMaterialLibrary;

  fSceneWorld := fSceneManager.FindSceneObject('Scene');
  if fSceneWorld = nil then
  begin
    fSceneWorld := TSceneObject.Create(fRoot);
    fSceneWorld.Name := 'Scene';
  end;

  fCamera := fSceneManager.FindCamera;
  if fCamera = nil then
  begin
    fCamera := TSceneObject.Create(fRoot);
    fCamera.Name := 'Camera';
    fCamera.CreateCamera;
    fCamera.Camera.LookAt(Vector3(0, 0, -11), Vector3(0, 0, 0), fCameraUp);
  end;

  fLight := FindFirstLightSceneObject(fRoot);
  if fLight = nil then
  begin
    fLight := TSceneObject.Create(fRoot);
    fLight.Name := 'Light_1';
    fLight.CreateLight;
    fLight.Position := Vector3(10, 10.0, 10.0);
    ConfigureLightDefaults(fLight.Light[0], ltDirectional);
  end;

  EnsureLightBillboards(fRoot);
  RestoreObject(fRoot);
  fSceneManager.Update;

  if Assigned(fRenderer) then
  begin
    fRenderer.ActiveCamera := fCamera;
    fRenderer.ShadowLight := fLight;
    fRenderer.ShadowTarget := fOrbitTarget;
  end;

  fSelectedObject := fSceneWorld;
  fSelectedMesh := nil;
  fSelectedMeshIndex := -1;
  fSelectedParticleSystemIndex := -1;
  fSelectedBillboardIndex := -1;
  fSelectedAnimatedSpriteIndex := -1;
  fSelectedAudioEmitterIndex := -1;
  fGizmoOwner := nil;
  RefreshGizmo;
end;

procedure TSandBoxForm.SaveSceneRenderSettingsToStream(Stream: TStream);
var
  Payload: TMemoryStream;
  Version: Integer;
  PayloadSize: Int64;
  BoolValue: Boolean;
  IntValue: Integer;
  FloatValue: Single;
  ColorValue: TVector4;
begin
  if (Stream = nil) or (fRenderer = nil) then
    Exit;

  Payload := TMemoryStream.Create;
  try
    BoolValue := fRenderer.HDREnabled;
    Payload.WriteBuffer(BoolValue, SizeOf(BoolValue));

    IntValue := Ord(fRenderer.ToneMappingMode);
    Payload.WriteBuffer(IntValue, SizeOf(IntValue));

    FloatValue := fRenderer.ToneExposure;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));

    FloatValue := fRenderer.ToneGamma;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));

    BoolValue := fRenderer.GodRaysEnabled;
    Payload.WriteBuffer(BoolValue, SizeOf(BoolValue));

    IntValue := fRenderer.GodRaySamples;
    Payload.WriteBuffer(IntValue, SizeOf(IntValue));

    FloatValue := fRenderer.GodRayDensity;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));

    FloatValue := fRenderer.GodRayExposure;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));

    FloatValue := fRenderer.GodRayDecay;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));

    FloatValue := fRenderer.GodRayWeight;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));

    FloatValue := fRenderer.GodRayIntensity;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));

    BoolValue := fRenderer.SkyDome <> nil;
    Payload.WriteBuffer(BoolValue, SizeOf(BoolValue));
    if BoolValue then
      fRenderer.SkyDome.SaveToStream(Payload);

    BoolValue := fRenderer.FogEnabled;
    Payload.WriteBuffer(BoolValue, SizeOf(BoolValue));

    ColorValue := fRenderer.FogColor;
    Payload.WriteBuffer(ColorValue, SizeOf(ColorValue));

    FloatValue := fRenderer.FogDensity;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));

    FloatValue := fRenderer.FogStart;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));

    FloatValue := fRenderer.FogEnd;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));

    Stream.WriteBuffer(SCENE_RENDER_SETTINGS_MAGIC_LOCAL[0],
      SizeOf(SCENE_RENDER_SETTINGS_MAGIC_LOCAL));
    Version := SCENE_RENDER_SETTINGS_VERSION_LOCAL;
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

function TSandBoxForm.TryLoadSceneRenderSettingsFromStream(Stream: TStream): Boolean;
var
  StartPos: Int64;
  PayloadSize: Int64;
  PayloadEnd: Int64;
  Magic: array[0..7] of AnsiChar;
  Version: Integer;
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
  Result := False;
  if Stream = nil then
    Exit;

  StartPos := Stream.Position;
  if (Stream.Size - Stream.Position) < SizeOf(Magic) then
    Exit;

  Stream.ReadBuffer(Magic[0], SizeOf(Magic));
  if not PreviewMagicMatches(Magic, SCENE_RENDER_SETTINGS_MAGIC_LOCAL) then
  begin
    Stream.Position := StartPos;
    Exit;
  end;

  Result := True;
  if (Stream.Size - Stream.Position) < (SizeOf(Version) + SizeOf(PayloadSize)) then
    raise Exception.Create('Invalid scene render settings header.');

  Stream.ReadBuffer(Version, SizeOf(Version));
  Stream.ReadBuffer(PayloadSize, SizeOf(PayloadSize));
  if (PayloadSize < 0) or (PayloadSize > (Stream.Size - Stream.Position)) then
    raise Exception.Create('Invalid scene render settings payload size.');

  PayloadEnd := Stream.Position + PayloadSize;
  try
    if (Version < 1) or (Version > SCENE_RENDER_SETTINGS_VERSION_LOCAL) then
      raise Exception.CreateFmt('Unsupported scene render settings version: %d.', [Version]);

    if Assigned(fRenderer) then
    begin
      RequirePayloadBytes(SizeOf(BoolValue));
      Stream.ReadBuffer(BoolValue, SizeOf(BoolValue));
      fRenderer.HDREnabled := BoolValue;

      RequirePayloadBytes(SizeOf(IntValue));
      Stream.ReadBuffer(IntValue, SizeOf(IntValue));
      IntValue := System.Math.EnsureRange(IntValue,
        Ord(Low(TToneMappingMode)), Ord(High(TToneMappingMode)));
      fRenderer.ToneMappingMode := TToneMappingMode(IntValue);

      RequirePayloadBytes(SizeOf(FloatValue));
      Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
      fRenderer.ToneExposure := System.Math.EnsureRange(FloatValue, 0.0, 16.0);

      RequirePayloadBytes(SizeOf(FloatValue));
      Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
      fRenderer.ToneGamma := System.Math.EnsureRange(FloatValue, 0.1, 5.0);

      RequirePayloadBytes(SizeOf(BoolValue));
      Stream.ReadBuffer(BoolValue, SizeOf(BoolValue));
      fRenderer.GodRaysEnabled := BoolValue;

      RequirePayloadBytes(SizeOf(IntValue));
      Stream.ReadBuffer(IntValue, SizeOf(IntValue));
      fRenderer.GodRaySamples := System.Math.EnsureRange(IntValue, 1, 128);

      RequirePayloadBytes(SizeOf(FloatValue));
      Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
      fRenderer.GodRayDensity := System.Math.EnsureRange(FloatValue, 0.0, 3.0);

      RequirePayloadBytes(SizeOf(FloatValue));
      Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
      fRenderer.GodRayExposure := System.Math.EnsureRange(FloatValue, 0.0, 4.0);

      RequirePayloadBytes(SizeOf(FloatValue));
      Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
      fRenderer.GodRayDecay := System.Math.EnsureRange(FloatValue, 0.0, 1.0);

      RequirePayloadBytes(SizeOf(FloatValue));
      Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
      fRenderer.GodRayWeight := System.Math.EnsureRange(FloatValue, 0.0, 2.0);

      RequirePayloadBytes(SizeOf(FloatValue));
      Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
      fRenderer.GodRayIntensity := System.Math.EnsureRange(FloatValue, 0.0, 8.0);

      if Version >= 2 then
      begin
        RequirePayloadBytes(SizeOf(HasSkyDome));
        Stream.ReadBuffer(HasSkyDome, SizeOf(HasSkyDome));

        if HasSkyDome then
        begin
          if fRenderer.SkyDome = nil then
            fRenderer.SkyDome := TSkyDome.Create;
          fRenderer.SkyDome.LoadFromStream(Stream);
        end
        else
          fRenderer.SkyDome := nil;
      end;

      if Version >= 3 then
      begin
        RequirePayloadBytes(SizeOf(BoolValue));
        Stream.ReadBuffer(BoolValue, SizeOf(BoolValue));
        fRenderer.FogEnabled := BoolValue;

        RequirePayloadBytes(SizeOf(ColorValue));
        Stream.ReadBuffer(ColorValue, SizeOf(ColorValue));
        fRenderer.FogColor := Vector4(
          System.Math.EnsureRange(ColorValue.X, 0.0, 1.0),
          System.Math.EnsureRange(ColorValue.Y, 0.0, 1.0),
          System.Math.EnsureRange(ColorValue.Z, 0.0, 1.0),
          System.Math.EnsureRange(ColorValue.W, 0.0, 1.0));

        RequirePayloadBytes(SizeOf(FloatValue));
        Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
        fRenderer.FogDensity := System.Math.EnsureRange(FloatValue, 0.0, 1.0);

        RequirePayloadBytes(SizeOf(FloatValue));
        Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
        fRenderer.FogStart := System.Math.Max(0.0, FloatValue);

        RequirePayloadBytes(SizeOf(FloatValue));
        Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
        fRenderer.FogEnd := System.Math.Max(fRenderer.FogStart, FloatValue);
      end;
    end;
  finally
    Stream.Position := PayloadEnd;
  end;
end;

procedure TSandBoxForm.SaveScenePhysicsToStream(Stream: TStream);
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
    Index: Integer;
  begin
    Result := False;
    Cur := Obj;
    if (Cur = nil) or Cur.IsGizmo or (Cur = fRoot) then
      Exit;

    while (Cur <> nil) and (Cur.Parent <> nil) do
    begin
      Index := Cur.Parent.IndexOfObject(Cur);
      if Index < 0 then
        Exit;
      Cur := Cur.Parent;
    end;

    Result := Cur = fRoot;
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
        raise Exception.Create('Cannot save physics body for detached scene object.');

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
  if (Stream = nil) or (fPhysicsWorld = nil) then
    Exit;

  Payload := TMemoryStream.Create;
  try
    GravityValue := fPhysicsWorld.Gravity;
    Payload.WriteBuffer(GravityValue, SizeOf(GravityValue));

    FloatValue := fPhysicsWorld.GlobalDamping;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));

    FloatValue := fPhysicsWorld.MaxSubStep;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));

    IntValue := fPhysicsWorld.MaxSubSteps;
    Payload.WriteBuffer(IntValue, SizeOf(IntValue));

    IntValue := fPhysicsWorld.SolverIterations;
    Payload.WriteBuffer(IntValue, SizeOf(IntValue));

    BoolValue := fPhysicsWorld.GroundPlaneEnabled;
    Payload.WriteBuffer(BoolValue, SizeOf(BoolValue));

    FloatValue := fPhysicsWorld.GroundHeight;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));

    GroundNormalValue := fPhysicsWorld.GroundNormal;
    Payload.WriteBuffer(GroundNormalValue, SizeOf(GroundNormalValue));

    FloatValue := fPhysicsWorld.CollisionSlop;
    Payload.WriteBuffer(FloatValue, SizeOf(FloatValue));

    BodyCountValue := 0;
    for I := 0 to fPhysicsWorld.BodyCount - 1 do
    begin
      Body := fPhysicsWorld.Bodies[I];
      if (Body <> nil) and HasSerializableObjectPath(Body.SceneObject) then
        Inc(BodyCountValue);
    end;
    Payload.WriteBuffer(BodyCountValue, SizeOf(BodyCountValue));

    for I := 0 to fPhysicsWorld.BodyCount - 1 do
    begin
      Body := fPhysicsWorld.Bodies[I];
      if (Body = nil) or (not HasSerializableObjectPath(Body.SceneObject)) then
        Continue;

      WriteObjectPath(Payload, Body.SceneObject);
      WritePhysicsBodyStateToStream(Payload, Body.GetState);
    end;

    Stream.WriteBuffer(SCENE_PHYSICS_MAGIC_LOCAL[0], SizeOf(SCENE_PHYSICS_MAGIC_LOCAL));
    Version := SCENE_PHYSICS_VERSION_LOCAL;
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

function TSandBoxForm.TryLoadScenePhysicsFromStream(Stream: TStream): Boolean;
var
  StartPos: Int64;
  PayloadSize: Int64;
  PayloadEnd: Int64;
  Magic: array[0..7] of AnsiChar;
  Version: Integer;
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
    Result := fRoot;

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
  Result := False;
  if Stream = nil then
    Exit;

  StartPos := Stream.Position;
  if (Stream.Size - Stream.Position) < SizeOf(Magic) then
    Exit;

  Stream.ReadBuffer(Magic[0], SizeOf(Magic));
  if not PreviewMagicMatches(Magic, SCENE_PHYSICS_MAGIC_LOCAL) then
  begin
    Stream.Position := StartPos;
    Exit;
  end;

  Result := True;
  if (Stream.Size - Stream.Position) < (SizeOf(Version) + SizeOf(PayloadSize)) then
    raise Exception.Create('Invalid scene physics header.');

  Stream.ReadBuffer(Version, SizeOf(Version));
  Stream.ReadBuffer(PayloadSize, SizeOf(PayloadSize));
  if (PayloadSize < 0) or (PayloadSize > (Stream.Size - Stream.Position)) then
    raise Exception.Create('Invalid scene physics payload size.');

  PayloadEnd := Stream.Position + PayloadSize;
  try
    if Version = 1 then
    begin
      if fPhysicsWorld = nil then
        raise Exception.Create('The game engine physics world is not available.');

      fPhysicsWorld.Clear;
      fPhysicsWorld.SceneRoot := fRoot;

      RequirePayloadBytes(SizeOf(GravityValue));
      Stream.ReadBuffer(GravityValue, SizeOf(GravityValue));
      fPhysicsWorld.Gravity := GravityValue;

      RequirePayloadBytes(SizeOf(FloatValue));
      Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
      fPhysicsWorld.GlobalDamping := System.Math.EnsureRange(FloatValue, 0.0, 1.0);

      RequirePayloadBytes(SizeOf(FloatValue));
      Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
      fPhysicsWorld.MaxSubStep := System.Math.EnsureRange(FloatValue, 1.0 / 1000.0, 1.0 / 10.0);

      RequirePayloadBytes(SizeOf(IntValue));
      Stream.ReadBuffer(IntValue, SizeOf(IntValue));
      fPhysicsWorld.MaxSubSteps := System.Math.EnsureRange(IntValue, 1, 64);

      RequirePayloadBytes(SizeOf(IntValue));
      Stream.ReadBuffer(IntValue, SizeOf(IntValue));
      fPhysicsWorld.SolverIterations := System.Math.EnsureRange(IntValue, 1, 128);

      RequirePayloadBytes(SizeOf(BoolValue));
      Stream.ReadBuffer(BoolValue, SizeOf(BoolValue));
      fPhysicsWorld.GroundPlaneEnabled := BoolValue;

      RequirePayloadBytes(SizeOf(FloatValue));
      Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
      fPhysicsWorld.GroundHeight := FloatValue;

      RequirePayloadBytes(SizeOf(GroundNormalValue));
      Stream.ReadBuffer(GroundNormalValue, SizeOf(GroundNormalValue));
      fPhysicsWorld.GroundNormal := GroundNormalValue;

      RequirePayloadBytes(SizeOf(FloatValue));
      Stream.ReadBuffer(FloatValue, SizeOf(FloatValue));
      fPhysicsWorld.CollisionSlop := System.Math.EnsureRange(FloatValue, 0.0, 1.0);

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

        Body := fPhysicsWorld.AddBody(Obj, State.BodyType, State.ColliderKind);
        Body.ApplyState(State);
      end;
    end;
  finally
    Stream.Position := PayloadEnd;
  end;
end;

procedure TSandBoxForm.SaveScenePhysicsCacheToStream(Stream: TStream);
var
  Version: Integer;
  PayloadSize: Int64;
  PayloadSizePos: Int64;
  PayloadStart: Int64;
  PayloadEnd: Int64;
  BodyCountPos: Int64;
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
    if (Cur = nil) or Cur.IsGizmo or (Cur = fRoot) then
      Exit;

    while (Cur <> nil) and (Cur.Parent <> nil) do
    begin
      Index := Cur.Parent.IndexOfObject(Cur);
      if Index < 0 then
        Exit;
      Cur := Cur.Parent;
    end;

    Result := Cur = fRoot;
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
        raise Exception.Create('Cannot save physics cache for detached scene object.');

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
  if (Stream = nil) or (fPhysicsWorld = nil) then
    Exit;

  Stream.WriteBuffer(SCENE_PHYSICS_CACHE_MAGIC_LOCAL[0],
    SizeOf(SCENE_PHYSICS_CACHE_MAGIC_LOCAL));
  Version := SCENE_PHYSICS_CACHE_VERSION_LOCAL;
  Stream.WriteBuffer(Version, SizeOf(Version));

  PayloadSize := 0;
  PayloadSizePos := Stream.Position;
  Stream.WriteBuffer(PayloadSize, SizeOf(PayloadSize));

  PayloadStart := Stream.Position;
  BodyCountValue := 0;
  BodyCountPos := Stream.Position;
  Stream.WriteBuffer(BodyCountValue, SizeOf(BodyCountValue));

  for I := 0 to fPhysicsWorld.BodyCount - 1 do
  begin
    Body := fPhysicsWorld.Bodies[I];
    if (Body = nil) or (not HasSerializableObjectPath(Body.SceneObject)) or
       (not fPhysicsWorld.BodyUsesCookedMeshCache(Body)) then
      Continue;

    CacheStream := TMemoryStream.Create;
    try
      if not fPhysicsWorld.TrySaveCookedMeshCache(Body, CacheStream, Signature) then
        Continue;

      CacheSize := CacheStream.Size;
      if (Signature = 0) or (CacheSize <= 0) then
        Continue;

      WriteObjectPath(Stream, Body.SceneObject);
      Stream.WriteBuffer(Signature, SizeOf(Signature));
      Stream.WriteBuffer(CacheSize, SizeOf(CacheSize));
      CacheStream.Position := 0;
      Stream.CopyFrom(CacheStream, CacheSize);
      Inc(BodyCountValue);
    finally
      CacheStream.Free;
    end;
  end;

  PayloadEnd := Stream.Position;
  PayloadSize := PayloadEnd - PayloadStart;

  Stream.Position := BodyCountPos;
  Stream.WriteBuffer(BodyCountValue, SizeOf(BodyCountValue));

  Stream.Position := PayloadSizePos;
  Stream.WriteBuffer(PayloadSize, SizeOf(PayloadSize));

  Stream.Position := PayloadEnd;

  if BodyCountValue > 0 then
    LogLine(Format('Saved %d cooked heightfield physics cache(s).',
      [BodyCountValue]));
end;

function TSandBoxForm.TryLoadScenePhysicsCacheFromStream(Stream: TStream): Boolean;
var
  StartPos: Int64;
  PayloadSize: Int64;
  PayloadEnd: Int64;
  Magic: array[0..7] of AnsiChar;
  Version: Integer;
  BodyCountValue: Integer;
  I: Integer;
  Obj: TSceneObject;
  Signature: UInt64;
  CacheSize: Int64;
  Data: TBytes;
  LoadedCount: Integer;

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
    Result := fRoot;

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
  Result := False;
  LoadedCount := 0;

  if Stream = nil then
    Exit;

  StartPos := Stream.Position;
  if (Stream.Size - Stream.Position) < SizeOf(Magic) then
    Exit;

  Stream.ReadBuffer(Magic[0], SizeOf(Magic));
  if not PreviewMagicMatches(Magic, SCENE_PHYSICS_CACHE_MAGIC_LOCAL) then
  begin
    Stream.Position := StartPos;
    Exit;
  end;

  Result := True;
  if (Stream.Size - Stream.Position) < (SizeOf(Version) + SizeOf(PayloadSize)) then
    raise Exception.Create('Invalid scene physics cache header.');

  Stream.ReadBuffer(Version, SizeOf(Version));
  Stream.ReadBuffer(PayloadSize, SizeOf(PayloadSize));
  if (PayloadSize < 0) or (PayloadSize > (Stream.Size - Stream.Position)) then
    raise Exception.Create('Invalid scene physics cache payload size.');

  PayloadEnd := Stream.Position + PayloadSize;
  try
    if Version = 1 then
    begin
      if fPhysicsWorld = nil then
        raise Exception.Create('The game engine physics world is not available.');
      fPhysicsWorld.SceneRoot := fRoot;

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
        begin
          fPhysicsWorld.StoreCookedMeshCache(Obj, Signature, Data);
          Inc(LoadedCount);
        end;
      end;
    end;
  finally
    Stream.Position := PayloadEnd;
  end;

  if LoadedCount > 0 then
    LogLine(Format('Loaded %d cooked heightfield physics cache(s).',
      [LoadedCount]));
end;

procedure TSandBoxForm.SaveSceneScriptsToStream(Stream: TStream);
var
  Payload: TMemoryStream;
  Version: Integer;
  PayloadSize: Int64;
begin
  if Stream = nil then
    Exit;

  if fScriptEditor.Dirty then
    SyncSelectedScriptFromEditor;

  if (fScriptManager = nil) or (fScriptManager.Count = 0) then
    Exit;

  Payload := TMemoryStream.Create;
  try
    fScriptManager.SaveToStream(Payload);

    Stream.WriteBuffer(SCENE_SCRIPTS_MAGIC_LOCAL[0],
      SizeOf(SCENE_SCRIPTS_MAGIC_LOCAL));
    Version := SCENE_SCRIPTS_VERSION_LOCAL;
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

function TSandBoxForm.TryLoadSceneScriptsFromStream(Stream: TStream): Boolean;
var
  StartPos: Int64;
  PayloadSize: Int64;
  PayloadEnd: Int64;
  Magic: array[0..7] of AnsiChar;
  Version: Integer;
begin
  Result := False;
  if Stream = nil then
    Exit;

  StartPos := Stream.Position;
  if (Stream.Size - Stream.Position) < SizeOf(Magic) then
    Exit;

  Stream.ReadBuffer(Magic[0], SizeOf(Magic));
  if not PreviewMagicMatches(Magic, SCENE_SCRIPTS_MAGIC_LOCAL) then
  begin
    Stream.Position := StartPos;
    Exit;
  end;

  Result := True;
  if (Stream.Size - Stream.Position) < (SizeOf(Version) + SizeOf(PayloadSize)) then
    raise Exception.Create('Invalid scene scripts header.');

  Stream.ReadBuffer(Version, SizeOf(Version));
  Stream.ReadBuffer(PayloadSize, SizeOf(PayloadSize));
  if (PayloadSize < 0) or (PayloadSize > (Stream.Size - Stream.Position)) then
    raise Exception.Create('Invalid scene scripts payload size.');

  PayloadEnd := Stream.Position + PayloadSize;
  try
    if Version <> SCENE_SCRIPTS_VERSION_LOCAL then
      raise Exception.CreateFmt('Unsupported scene scripts version: %d.',
        [Version]);

    if fScriptManager = nil then
      raise Exception.Create('The game engine script manager is not available.');

    if PayloadSize > 0 then
      fScriptManager.LoadFromStream(Stream)
    else
      fScriptManager.Clear;

    BindScriptEngine;
    if fScriptManager.Count > 0 then
      SelectScriptIndex(0)
    else
      SelectScriptIndex(-1);
  finally
    Stream.Position := PayloadEnd;
  end;

  if Assigned(fScriptManager) and (fScriptManager.Count > 0) then
    LogLine(Format('Loaded %d scene script(s).', [fScriptManager.Count]));
end;

procedure TSandBoxForm.SaveSceneToFile(const AFileName: string);
begin
  fSceneFileBrowser.LastError := '';
  try
    if fEngine = nil then
      raise Exception.Create('The game engine is not available.');

    fEngine.SaveSceneToFile(AFileName, GIZMO_MATERIAL_NAME);
    LogLine('Scene saved: ' + AFileName);
  except
    on E: Exception do
    begin
      fSceneFileBrowser.LastError := E.Message;
      LogLine('Scene save failed: ' + E.Message);
    end;
  end;
end;

procedure TSandBoxForm.LoadSceneFromFile(const AFileName: string);
begin
  fSceneFileBrowser.LastError := '';
  try
    if fEngine = nil then
      raise Exception.Create('The game engine is not available.');

    ReleaseCurrentGizmo;
    fEngine.LoadSceneFromFile(AFileName);
    fRenderer := fEngine.Renderer;
    fSceneManager := fEngine.SceneManager;
    fRoot := fEngine.Root;
    fSceneWorld := fEngine.SceneWorld;
    fLight := fEngine.MainLight;
    fCamera := fEngine.Camera;
    fPhysicsWorld := fEngine.PhysicsWorld;
    fAudioEngine := fEngine.AudioEngine;
    fScriptManager := fEngine.ScriptManager;
    MaterialLibraries := fEngine.MaterialLibraries;
    fShader := fEngine.DefaultShader;
    fActorShader := fEngine.ActorShader;
    fTreeLeafShader := fEngine.TreeLeafShader;
    fTreeTrunkShader := fEngine.TreeTrunkShader;
    fHeightFieldShader := fEngine.HeightFieldShader;
    fPhysicsRunning := fEngine.PhysicsRunning;
    SyncOrbitFromCamera;
    EnsureLightBillboards(fRoot);
    fSelectedObject := fSceneWorld;
    fSelectedMesh := nil;
    fSelectedMeshIndex := -1;
    fSelectedParticleSystemIndex := -1;
    fSelectedBillboardIndex := -1;
    fSelectedAnimatedSpriteIndex := -1;
    fSelectedAudioEmitterIndex := -1;
    ResetScriptEditorForSceneChange;
    RefreshGizmo;
    LogLine('Scene loaded: ' + AFileName);
  except
    on E: Exception do
    begin
      fSceneFileBrowser.LastError := E.Message;
      LogLine('Scene load failed: ' + E.Message);
    end;
  end;
end;

function TSandBoxForm.TryLoadDefaultSceneFromDisk(const AFileName: string): Boolean;
begin
  Result := False;

  if (Trim(AFileName) = '') or (not FileExists(AFileName)) then
    Exit;

  fSceneFileBrowser.LastError := '';
  try
    LoadSceneFromFile(AFileName);
    Result := fSceneFileBrowser.LastError = '';
    if not Result then
      LogLine('Default scene load skipped: ' + fSceneFileBrowser.LastError);
  except
    on E: Exception do
    begin
      fSceneFileBrowser.LastError := '';
      LogLine('Default scene could not be loaded; recreating it: ' + E.Message);
    end;
  end;
end;

procedure TSandBoxForm.SaveDefaultSceneToDisk(const AFileName: string);
var
  FileName: string;
begin
  if fEngine = nil then
    Exit;

  if TPath.IsPathRooted(AFileName) then
    FileName := AFileName
  else
    FileName := ExpandFileName(AFileName);

  fEngine.SaveSceneToFile(FileName, GIZMO_MATERIAL_NAME);
  LogLine('Default scene saved: ' + FileName);
end;

procedure TSandBoxForm.ExecuteSceneFileBrowserAction;
var
  FileName: string;
  Ext: string;
  Item: TSceneFileInfo;
begin
  fSceneFileBrowser.LastError := '';
  FileName := '';

  case fSceneFileBrowser.Mode of
    sfbLoadScene:
      begin
        if (fSceneFileBrowser.SelectedIndex < 0) or
           (fSceneFileBrowser.SelectedIndex > High(fSceneFileBrowser.Items)) then
        begin
          fSceneFileBrowser.LastError := 'Select a scene first.';
          Exit;
        end;

        Item := fSceneFileBrowser.Items[fSceneFileBrowser.SelectedIndex];
        FileName := Item.FileName;
      end;

    sfbSaveScene:
      begin
        FileName := Trim(AnsiBufferText(fSceneFileBrowser.FileName));
        if FileName = '' then
        begin
          fSceneFileBrowser.LastError := 'Enter a file name first.';
          Exit;
        end;

        FileName := ExtractFileName(FileName);

        Ext := LowerCase(ExtractFileExt(FileName));
        if Ext = '' then
          FileName := ChangeFileExt(FileName, SCENE_FILE_EXTENSION_LOCAL)
        else if Ext <> SCENE_FILE_EXTENSION_LOCAL then
        begin
          fSceneFileBrowser.LastError := 'Scene files use ' + SCENE_FILE_EXTENSION_LOCAL;
          Exit;
        end;

        FileName := TEnginePaths.Scene(FileName);

        if FileExists(FileName) and
           ((not fSceneFileBrowser.PendingOverwrite) or
            (not SameText(fSceneFileBrowser.PendingOverwriteFileName, FileName))) then
        begin
          fSceneFileBrowser.PendingOverwrite := True;
          fSceneFileBrowser.PendingOverwriteFileName := FileName;
          fSceneFileBrowser.LastError := '';
          Exit;
        end;
      end;
  else
    Exit;
  end;

  case fSceneFileBrowser.Mode of
    sfbLoadScene: LoadSceneFromFile(FileName);
    sfbSaveScene: SaveSceneToFile(FileName);
  end;

  if fSceneFileBrowser.LastError <> '' then
    Exit;

  ResetSceneFileBrowser;
  RequestRender;
end;

function TSandBoxForm.SceneObjectPath(Obj: TSceneObject): string;
begin
  Result := '';
  if Obj = nil then
    Exit;

  if Obj.Parent <> nil then
    Result := SceneObjectPath(Obj.Parent);

  if Result <> '' then
    Result := Result + '/';
  Result := Result + Obj.Name;
end;

function TSandBoxForm.IsPrefabAssetFile(const AFileName: string): Boolean;
begin
  Result := SameText(ExtractFileExt(AFileName), PREFAB_FILE_EXTENSION_LOCAL);
end;

function TSandBoxForm.ResolvePrefabFileName(const AFileName: string): string;
var
  FileName: string;
  Ext: string;
begin
  Result := '';
  fPrefabFileBrowser.LastError := '';

  FileName := Trim(AFileName);
  if FileName = '' then
  begin
    fPrefabFileBrowser.LastError := 'Enter a prefab file name first.';
    Exit;
  end;

  FileName := StringReplace(FileName, '/', PathDelim, [rfReplaceAll]);
  if TPath.IsPathRooted(FileName) then
  begin
    if SameText(Copy(IncludeTrailingPathDelimiter(ExpandFileName(FileName)), 1,
      Length(TEnginePaths.PrefabsDir)), TEnginePaths.PrefabsDir) then
      FileName := ExtractRelativePath(TEnginePaths.PrefabsDir, FileName)
    else
      FileName := ExtractFileName(FileName);
  end;

  if SameText(Copy(FileName, 1, Length('Data' + PathDelim + 'Prefabs' +
    PathDelim)), 'Data' + PathDelim + 'Prefabs' + PathDelim) then
    Delete(FileName, 1, Length('Data' + PathDelim + 'Prefabs' + PathDelim));

  if (FileName = '..') or (Pos('..' + PathDelim, FileName) > 0) or
     (Pos(PathDelim + '..', FileName) > 0) then
  begin
    fPrefabFileBrowser.LastError := 'Prefab file names must stay inside Data\Prefabs.';
    Exit;
  end;

  Ext := LowerCase(ExtractFileExt(FileName));
  if Ext = '' then
    FileName := ChangeFileExt(FileName, PREFAB_FILE_EXTENSION_LOCAL)
  else if Ext <> PREFAB_FILE_EXTENSION_LOCAL then
  begin
    fPrefabFileBrowser.LastError := 'Prefab files use ' + PREFAB_FILE_EXTENSION_LOCAL;
    Exit;
  end;

  Result := TEnginePaths.Prefab(FileName);
end;

procedure TSandBoxForm.RefreshPrefabFileList;
var
  FoundFile: string;
  Count: Integer;
  Item: TPrefabFileInfo;
begin
  ForceDirectories(TEnginePaths.PrefabsDir);
  fPrefabFileBrowser.NeedsRefresh := False;
  fPrefabFileBrowser.SelectedIndex := -1;
  fPrefabFileBrowser.LastError := '';
  SetLength(fPrefabFileBrowser.Items, 0);

  Count := 0;
  try
    for FoundFile in TDirectory.GetFiles(TEnginePaths.PrefabsDir,
      '*' + PREFAB_FILE_EXTENSION_LOCAL, TSearchOption.soAllDirectories) do
    begin
      Item.FileName := FoundFile;
      Item.RelativePath := ExtractRelativePath(TEnginePaths.PrefabsDir, FoundFile);
      Item.DisplayName := ChangeFileExt(Item.RelativePath, '');
      Item.FileSize := TFile.GetSize(FoundFile);
      Item.ModifiedText := FormatDateTime('yyyy-mm-dd hh:nn',
        TFile.GetLastWriteTime(FoundFile));

      SetLength(fPrefabFileBrowser.Items, Count + 1);
      fPrefabFileBrowser.Items[Count] := Item;
      Inc(Count);
    end;
  except
    on E: Exception do
      fPrefabFileBrowser.LastError := 'Could not scan prefabs folder: ' + E.Message;
  end;

  if (Count = 0) and (fPrefabFileBrowser.LastError = '') then
    fPrefabFileBrowser.LastError := 'No prefab files found in ' +
      TEnginePaths.PrefabsDir;
end;

procedure TSandBoxForm.ResetPrefabFileBrowser;
begin
  fPrefabFileBrowser.Active := False;
  fPrefabFileBrowser.NeedsRefresh := False;
  fPrefabFileBrowser.Mode := prefabNone;
  fPrefabFileBrowser.SelectedIndex := -1;
  fPrefabFileBrowser.PendingOverwrite := False;
  fPrefabFileBrowser.PendingOverwriteFileName := '';
  fPrefabFileBrowser.LastError := '';
  SetAnsiBuffer(fPrefabFileBrowser.Search, '');
  SetAnsiBuffer(fPrefabFileBrowser.FileName, '');
  SetLength(fPrefabFileBrowser.Items, 0);
end;

procedure TSandBoxForm.OpenPrefabFileBrowser(AMode: TPrefabFileBrowserMode);
var
  DefaultName: string;
begin
  fPrefabFileBrowser.Active := True;
  fPrefabFileBrowser.NeedsRefresh := True;
  fPrefabFileBrowser.Mode := AMode;
  fPrefabFileBrowser.SelectedIndex := -1;
  fPrefabFileBrowser.PendingOverwrite := False;
  fPrefabFileBrowser.PendingOverwriteFileName := '';
  fPrefabFileBrowser.LastError := '';

  if AMode = prefabSave then
  begin
    if not IsProtectedSceneObject(fSelectedObject) then
      DefaultName := fSelectedObject.Name
    else
      DefaultName := 'Prefab';
    SetAnsiBuffer(fPrefabFileBrowser.FileName,
      ChangeFileExt(DefaultName, PREFAB_FILE_EXTENSION_LOCAL));
  end
  else
    SetAnsiBuffer(fPrefabFileBrowser.FileName, '');
end;

procedure TSandBoxForm.SaveSelectedObjectPrefabToFile(const AFileName: string);
var
  Stream: TFileStream;
  Payload: TMemoryStream;
  Version: Integer;
  HasMaterials: Boolean;
  PayloadSize: Int64;
  Body: TPhysicsBody;
  BodyCountValue: Integer;
  I: Integer;
  Script: TEngineScriptAsset;
  ScriptCopy: TEngineScriptAsset;
  RootPath: string;
  TargetPath: string;
  RelativeTarget: string;
  ScriptCountValue: Integer;

  function IsObjectInPrefab(Obj: TSceneObject): Boolean;
  begin
    Result := (Obj <> nil) and (fSelectedObject <> nil) and
      ((Obj = fSelectedObject) or Obj.IsDescendantOf(fSelectedObject));
  end;

  function RelativeObjectPath(Obj, RootObj: TSceneObject): string;
  var
    Parts: TList<string>;
    Cur: TSceneObject;
    J: Integer;
  begin
    Result := '';
    if (Obj = nil) or (RootObj = nil) or (Obj = RootObj) then
      Exit;

    Parts := TList<string>.Create;
    try
      Cur := Obj;
      while (Cur <> nil) and (Cur <> RootObj) do
      begin
        Parts.Insert(0, Cur.Name);
        Cur := Cur.Parent;
      end;

      for J := 0 to Parts.Count - 1 do
      begin
        if Result <> '' then
          Result := Result + '/';
        Result := Result + Parts[J];
      end;
    finally
      Parts.Free;
    end;
  end;

begin
  fPrefabFileBrowser.LastError := '';
  if fScriptEditor.Dirty then
    SyncSelectedScriptFromEditor;

  if IsProtectedSceneObject(fSelectedObject) then
  begin
    fPrefabFileBrowser.LastError := 'Select a scene object to save as prefab.';
    Exit;
  end;

  ForceDirectories(ExtractFilePath(AFileName));
  Stream := TFileStream.Create(AFileName, fmCreate);
  try
    Stream.WriteBuffer(PREFAB_FILE_MAGIC_LOCAL[0], SizeOf(PREFAB_FILE_MAGIC_LOCAL));
    Version := PREFAB_FILE_VERSION_LOCAL;
    Stream.WriteBuffer(Version, SizeOf(Version));
    WritePreviewString(Stream, fSelectedObject.Name);

    fSelectedObject.SaveToStream(Stream);

    HasMaterials := (MaterialLibraries <> nil) and (MaterialLibraries.Count > 0);
    Stream.WriteBuffer(HasMaterials, SizeOf(HasMaterials));
    if HasMaterials then
    begin
      Payload := TMemoryStream.Create;
      try
        MaterialLibraries.SaveToStream(Payload, GIZMO_MATERIAL_NAME);
        PayloadSize := Payload.Size;
        Stream.WriteBuffer(PayloadSize, SizeOf(PayloadSize));
        Payload.Position := 0;
        if PayloadSize > 0 then
          Stream.CopyFrom(Payload, PayloadSize);
      finally
        Payload.Free;
      end;
    end;

    Payload := TMemoryStream.Create;
    try
      BodyCountValue := 0;
      if fPhysicsWorld <> nil then
        for I := 0 to fPhysicsWorld.BodyCount - 1 do
        begin
          Body := fPhysicsWorld.Bodies[I];
          if (Body = nil) or (not IsObjectInPrefab(Body.SceneObject)) then
            Continue;

          WritePreviewString(Payload,
            RelativeObjectPath(Body.SceneObject, fSelectedObject));
          WritePhysicsBodyStateToStream(Payload, Body.GetState);
          Inc(BodyCountValue);
        end;

      Stream.WriteBuffer(BodyCountValue, SizeOf(BodyCountValue));
      Payload.Position := 0;
      if Payload.Size > 0 then
        Stream.CopyFrom(Payload, Payload.Size);
    finally
      Payload.Free;
    end;

    Payload := TMemoryStream.Create;
    try
      ScriptCountValue := 0;
      RootPath := SceneObjectPath(fSelectedObject);
      if fScriptManager <> nil then
        for I := 0 to fScriptManager.Count - 1 do
        begin
          Script := fScriptManager.Script[I];
          if (Script = nil) or (Script.TargetKind <> stkSceneObject) then
            Continue;

          TargetPath := Trim(Script.TargetName);
          if SameText(TargetPath, RootPath) then
            RelativeTarget := ''
          else if SameText(Copy(TargetPath, 1, Length(RootPath) + 1),
            RootPath + '/') then
            RelativeTarget := Copy(TargetPath, Length(RootPath) + 2, MaxInt)
          else
            Continue;

          ScriptCopy := TEngineScriptAsset.Create;
          try
            ScriptCopy.Assign(Script);
            ScriptCopy.TargetName := RelativeTarget;
            ScriptCopy.SaveToStream(Payload);
            Inc(ScriptCountValue);
          finally
            ScriptCopy.Free;
          end;
        end;

      Stream.WriteBuffer(ScriptCountValue, SizeOf(ScriptCountValue));
      Payload.Position := 0;
      if Payload.Size > 0 then
        Stream.CopyFrom(Payload, Payload.Size);
    finally
      Payload.Free;
    end;
  finally
    Stream.Free;
  end;

  fPrefabFileBrowser.NeedsRefresh := True;
  LogLine('Prefab saved: ' + AFileName);
end;

function TSandBoxForm.LoadPrefabFromFile(const AFileName: string;
  AParent: TSceneObject): TSceneObject;
var
  Stream: TFileStream;
  Magic: array[0..7] of AnsiChar;
  Version: Integer;
  StoredName: string;
  ParentObj: TSceneObject;
  OriginalName: string;
  HasMaterials: Boolean;
  PayloadSize: Int64;
  PayloadEnd: Int64;
  TempMaterials: TMaterialLibraries;
  SourceLib, DestLib: TMaterialLibrary;
  SourceMat, NewMat: TMaterial;
  MatStream: TMemoryStream;
  I, J: Integer;
  BodyCountValue: Integer;
  State: TPhysicsBodyState;
  Body: TPhysicsBody;
  TargetObj: TSceneObject;
  RelativePath: string;
  ScriptCountValue: Integer;
  Script: TEngineScriptAsset;
  Guid: TGUID;
  RootPath: string;
  ObjectSceneVersion: Integer;

  function FindRelativeObject(RootObj: TSceneObject;
    const ARelativePath: string): TSceneObject;
  var
    Parts: TStringList;
    Cur: TSceneObject;
    PartIndex: Integer;
    ChildIndex: Integer;
  begin
    Result := RootObj;
    if (RootObj = nil) or (Trim(ARelativePath) = '') then
      Exit;

    Parts := TStringList.Create;
    try
      Parts.StrictDelimiter := True;
      Parts.Delimiter := '/';
      Parts.DelimitedText := StringReplace(ARelativePath, '\', '/', [rfReplaceAll]);
      Cur := RootObj;
      for PartIndex := 0 to Parts.Count - 1 do
      begin
        Result := nil;
        for ChildIndex := 0 to Cur.Count - 1 do
          if SameText(Cur.ObjectList[ChildIndex].Name, Parts[PartIndex]) then
          begin
            Cur := Cur.ObjectList[ChildIndex];
            Result := Cur;
            Break;
          end;

        if Result = nil then
          Exit;
      end;
    finally
      Parts.Free;
    end;
  end;

  function UniqueScriptName(const BaseName: string): string;
  var
    Base: string;
    N: Integer;
  begin
    Base := Trim(BaseName);
    if Base = '' then
      Base := 'PrefabScript';

    Result := Base;
    N := 1;
    while (fScriptManager <> nil) and (fScriptManager.FindByName(Result) <> nil) do
    begin
      Result := Base + '_' + IntToStr(N);
      Inc(N);
    end;
  end;

begin
  Result := nil;
  fPrefabFileBrowser.LastError := '';
  if not FileExists(AFileName) then
  begin
    fPrefabFileBrowser.LastError := 'Prefab file not found: ' + AFileName;
    Exit;
  end;

  ParentObj := AParent;
  if ParentObj = nil then
  begin
    if fSceneWorld <> nil then
      ParentObj := fSceneWorld
    else
      ParentObj := fRoot;
  end;

  if ParentObj = nil then
  begin
    fPrefabFileBrowser.LastError := 'No scene parent is available for prefab load.';
    Exit;
  end;

  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Stream.ReadBuffer(Magic[0], SizeOf(Magic));
    if not PreviewMagicMatches(Magic, PREFAB_FILE_MAGIC_LOCAL) then
      raise Exception.Create('Invalid prefab file.');

    Stream.ReadBuffer(Version, SizeOf(Version));
    if (Version < 1) or (Version > PREFAB_FILE_VERSION_LOCAL) then
      raise Exception.CreateFmt('Unsupported prefab version: %d.', [Version]);

    StoredName := ReadPreviewString(Stream);
    if Version >= 2 then
      ObjectSceneVersion := SCENE_FILE_VERSION_LOCAL
    else
      ObjectSceneVersion := 9;
    Result := TSceneObject.LoadFromStream(Stream, ParentObj, ObjectSceneVersion);
    if Trim(Result.Name) = '' then
      Result.Name := StoredName;
    OriginalName := Result.Name;
    Result.Name := '';
    Result.Name := OriginalName;

    Stream.ReadBuffer(HasMaterials, SizeOf(HasMaterials));
    if HasMaterials then
    begin
      Stream.ReadBuffer(PayloadSize, SizeOf(PayloadSize));
      if (PayloadSize < 0) or (PayloadSize > (Stream.Size - Stream.Position)) then
        raise Exception.Create('Invalid prefab material payload size.');

      PayloadEnd := Stream.Position + PayloadSize;
      TempMaterials := TMaterialLibraries.Create;
      try
        TempMaterials.LoadFromStream(Stream, fShader);
        if MaterialLibraries = nil then
          MaterialLibraries := TMaterialLibraries.Create;

        for I := 0 to TempMaterials.Count - 1 do
        begin
          SourceLib := TempMaterials.MaterialLibrary[I];
          if SourceLib = nil then
            Continue;

          DestLib := MaterialLibraries.GetMaterialLibrary(SourceLib.Name);
          if DestLib = nil then
          begin
            DestLib := TMaterialLibrary.Create;
            DestLib.Name := SourceLib.Name;
            MaterialLibraries.AddMaterialLibrary(DestLib);
          end;

          for J := 0 to SourceLib.Count - 1 do
          begin
            SourceMat := SourceLib.Material[J];
            if (SourceMat = nil) or (DestLib.GetMaterial(SourceMat.Name) <> nil) then
              Continue;

            MatStream := TMemoryStream.Create;
            try
              SourceMat.SaveToStream(MatStream);
              MatStream.Position := 0;
              NewMat := TMaterial.LoadFromStream(MatStream, fShader);
              AssignShaderToMaterial(NewMat);
              DestLib.AddMaterial(NewMat);
            finally
              MatStream.Free;
            end;
          end;
        end;
      finally
        TempMaterials.Free;
        Stream.Position := PayloadEnd;
      end;
    end;

    Stream.ReadBuffer(BodyCountValue, SizeOf(BodyCountValue));
    if BodyCountValue < 0 then
      raise Exception.Create('Invalid prefab physics body count.');

    if fPhysicsWorld = nil then
      raise Exception.Create('The game engine physics world is not available.');
    fPhysicsWorld.SceneRoot := fRoot;

    for I := 0 to BodyCountValue - 1 do
    begin
      RelativePath := ReadPreviewString(Stream);
      State := ReadPhysicsBodyStateFromStream(Stream);
      TargetObj := FindRelativeObject(Result, RelativePath);
      if TargetObj <> nil then
      begin
        Body := fPhysicsWorld.AddBody(TargetObj, State.BodyType, State.ColliderKind);
        Body.ApplyState(State);
      end;
    end;

    Stream.ReadBuffer(ScriptCountValue, SizeOf(ScriptCountValue));
    if ScriptCountValue < 0 then
      raise Exception.Create('Invalid prefab script count.');

    if fScriptManager = nil then
      raise Exception.Create('The game engine script manager is not available.');
    RootPath := SceneObjectPath(Result);

    for I := 0 to ScriptCountValue - 1 do
    begin
      Script := TEngineScriptAsset.Create;
      try
        Script.LoadFromStream(Stream);
        CreateGUID(Guid);
        Script.ID := GUIDToString(Guid);
        Script.Name := UniqueScriptName(Script.Name);
        if Script.TargetKind = stkSceneObject then
        begin
          if Trim(Script.TargetName) = '' then
            Script.TargetName := RootPath
          else
            Script.TargetName := RootPath + '/' +
              StringReplace(Script.TargetName, '\', '/', [rfReplaceAll]);
        end;
        fScriptManager.AddOrReplaceAsset(Script);
        Script := nil;
      finally
        Script.Free;
      end;
    end;
  finally
    Stream.Free;
  end;

  RestoreSceneAfterLoad;
  BindScriptEngine;
  SelectObjectFromImGui(Result);
  LogLine('Prefab loaded: ' + AFileName);
end;

procedure TSandBoxForm.ExecutePrefabFileBrowserAction;
var
  FileName: string;
  Item: TPrefabFileInfo;
  ParentObj: TSceneObject;
begin
  fPrefabFileBrowser.LastError := '';
  FileName := '';

  case fPrefabFileBrowser.Mode of
    prefabLoad:
      begin
        if (fPrefabFileBrowser.SelectedIndex < 0) or
           (fPrefabFileBrowser.SelectedIndex > High(fPrefabFileBrowser.Items)) then
        begin
          fPrefabFileBrowser.LastError := 'Select a prefab first.';
          Exit;
        end;

        Item := fPrefabFileBrowser.Items[fPrefabFileBrowser.SelectedIndex];
        FileName := Item.FileName;
      end;

    prefabSave:
      begin
        FileName := ResolvePrefabFileName(AnsiBufferText(fPrefabFileBrowser.FileName));
        if FileName = '' then
          Exit;

        if FileExists(FileName) and
           ((not fPrefabFileBrowser.PendingOverwrite) or
            (not SameText(fPrefabFileBrowser.PendingOverwriteFileName, FileName))) then
        begin
          fPrefabFileBrowser.PendingOverwrite := True;
          fPrefabFileBrowser.PendingOverwriteFileName := FileName;
          fPrefabFileBrowser.LastError := '';
          Exit;
        end;
      end;
  else
    Exit;
  end;

  case fPrefabFileBrowser.Mode of
    prefabLoad:
      begin
        ParentObj := fSelectedObject;
        if not CanUseSceneObjectAsParent(ParentObj) then
          ParentObj := fSceneWorld;
        LoadPrefabFromFile(FileName, ParentObj);
      end;
    prefabSave:
      SaveSelectedObjectPrefabToFile(FileName);
  end;

  if fPrefabFileBrowser.LastError <> '' then
    Exit;

  ResetPrefabFileBrowser;
  RequestRender;
end;

function TSandBoxForm.LoadPrefabForScript(const AFileName: string;
  AParent: TSceneObject): TSceneObject;
var
  FileName: string;
begin
  FileName := ResolvePrefabFileName(AFileName);
  if (FileName = '') or (not FileExists(FileName)) then
    raise Exception.Create('Prefab file not found: ' + AFileName);

  Result := LoadPrefabFromFile(FileName, AParent);
  if Result = nil then
    raise Exception.Create(fPrefabFileBrowser.LastError);
end;

procedure TSandBoxForm.DestroyPrefabForScript(AObject: TSceneObject);
begin
  if IsProtectedSceneObject(AObject) then
    Exit;

  DeleteObjectFromImGui(AObject);
end;

procedure TSandBoxForm.DrawImGuiPrefabFileBrowser;
var
  OpenWindow: Boolean;
  TitleText: string;
  ActionText: string;
  SearchText: string;
  I: Integer;
  Selected: Boolean;
  Item: TPrefabFileInfo;
  ReplaceClicked: Boolean;
  CancelClicked: Boolean;
begin
  if not fPrefabFileBrowser.Active then
    Exit;

  if fPrefabFileBrowser.NeedsRefresh then
    RefreshPrefabFileList;

  case fPrefabFileBrowser.Mode of
    prefabLoad:
      begin
        TitleText := 'Load Prefab';
        ActionText := 'Load Prefab';
      end;
    prefabSave:
      begin
        TitleText := 'Save Prefab';
        ActionText := 'Save Prefab';
      end;
  else
    TitleText := 'Prefab Browser';
    ActionText := 'OK';
  end;

  OpenWindow := True;
  ImGui.SetNextWindowSize(ImVec2.New(640, 420), ImGuiCond_FirstUseEver);
  if not ImGui.Begin_(PAnsiChar(AnsiString(TitleText)), @OpenWindow) then
  begin
    fPrefabFileBrowser.Active := OpenWindow;
    ImGui.End_;
    Exit;
  end;

  ImGui.Text(PAnsiChar(AnsiString('Prefab directory: ' +
    TEnginePaths.PrefabsDir)));

  if fPrefabFileBrowser.Mode = prefabSave then
  begin
    ImGui.PushItemWidth(-1);
    if ImGui.InputText('File name##PrefabFileName',
      @fPrefabFileBrowser.FileName[0],
      SizeOf(fPrefabFileBrowser.FileName)) then
    begin
      fPrefabFileBrowser.PendingOverwrite := False;
      fPrefabFileBrowser.PendingOverwriteFileName := '';
      fPrefabFileBrowser.LastError := '';
    end;
    ImGui.PopItemWidth;

    if fPrefabFileBrowser.PendingOverwrite then
    begin
      DrawOverwriteConfirmation(fPrefabFileBrowser.PendingOverwriteFileName,
        'prefab', 'Prefab', ReplaceClicked, CancelClicked);
      if ReplaceClicked then
      begin
        try
          ExecutePrefabFileBrowserAction;
        except
          on E: Exception do
            fPrefabFileBrowser.LastError := E.Message;
        end;
        if not fPrefabFileBrowser.Active then
        begin
          ImGui.End_;
          Exit;
        end;
      end
      else if CancelClicked then
      begin
        fPrefabFileBrowser.PendingOverwrite := False;
        fPrefabFileBrowser.PendingOverwriteFileName := '';
        fPrefabFileBrowser.LastError := '';
      end;
    end;
  end;

  if ImGui.Button(PAnsiChar(AnsiString(ActionText))) then
  begin
    try
      ExecutePrefabFileBrowserAction;
    except
      on E: Exception do
        fPrefabFileBrowser.LastError := E.Message;
    end;
    if not fPrefabFileBrowser.Active then
    begin
      ImGui.End_;
      Exit;
    end;
  end;
  ImGui.SameLine;
  if ImGui.Button('Cancel##PrefabBrowserCancel') then
  begin
    ResetPrefabFileBrowser;
    ImGui.End_;
    Exit;
  end;
  ImGui.SameLine;
  if ImGui.Button('Refresh##PrefabBrowserRefresh') then
    RefreshPrefabFileList;

  if fPrefabFileBrowser.LastError <> '' then
  begin
    ImGui.Separator;
    ImGui.TextWrapped(PAnsiChar(AnsiString(fPrefabFileBrowser.LastError)));
  end;

  ImGui.Separator;
  ImGui.InputText('Search##PrefabSearch', @fPrefabFileBrowser.Search[0],
    SizeOf(fPrefabFileBrowser.Search));

  SearchText := LowerCase(Trim(AnsiBufferText(fPrefabFileBrowser.Search)));
  if ImGui.BeginChild('PrefabFileList', ImVec2.New(-1, 0),
    ImGuiChildFlags_Border) then
  begin
    for I := 0 to High(fPrefabFileBrowser.Items) do
    begin
      Item := fPrefabFileBrowser.Items[I];
      if (SearchText <> '') and
         (Pos(SearchText, LowerCase(Item.DisplayName)) = 0) and
         (Pos(SearchText, LowerCase(Item.RelativePath)) = 0) then
        Continue;

      Selected := I = fPrefabFileBrowser.SelectedIndex;
      if ImGui.Selectable(PAnsiChar(AnsiString(Item.DisplayName)), Selected) then
      begin
        fPrefabFileBrowser.SelectedIndex := I;
        if fPrefabFileBrowser.Mode = prefabSave then
        begin
          SetAnsiBuffer(fPrefabFileBrowser.FileName, Item.RelativePath);
          fPrefabFileBrowser.PendingOverwrite := False;
          fPrefabFileBrowser.PendingOverwriteFileName := '';
          fPrefabFileBrowser.LastError := '';
        end;
      end;

      if ImGui.IsItemHovered then
        ImGui.SetTooltip(AnsiString(Item.RelativePath + sLineBreak +
          Format('%d bytes, modified %s', [Item.FileSize, Item.ModifiedText])));
    end;
  end;
  ImGui.EndChild;

  fPrefabFileBrowser.Active := OpenWindow;
  ImGui.End_;
end;

function ParticleBlendModeDisplayName(ABlendMode: TParticleBlendMode): string;
begin
  case ABlendMode of
    pbAdditive: Result := 'Additive';
  else
    Result := 'Alpha';
  end;
end;

function ParticleTextureKindDisplayName(ATextureKind: TParticleTextureKind): string;
begin
  case ATextureKind of
    ptSoftCircle: Result := 'Soft Circle';
    ptPerlin: Result := 'Perlin';
    ptFile: Result := 'Texture File';
  else
    Result := 'None';
  end;
end;

function TSandBoxForm.SelectedParticleObject: TSceneObject;
begin
  Result := fSelectedObject;
  if Assigned(Result) and Result.IsGizmo then
    Result := nil;
end;

function TSandBoxForm.SelectedParticleSystem: TParticleSystem;
var
  Obj: TSceneObject;
begin
  Result := nil;
  Obj := SelectedParticleObject;
  if Obj = nil then
    Exit;

  if (fSelectedParticleSystemIndex >= 0) and
     (fSelectedParticleSystemIndex < Obj.ParticleSystemCount) then
    Result := Obj.ParticleSystemItem[fSelectedParticleSystemIndex];
end;

function TSandBoxForm.SelectedBillboard: TBillboard;
begin
  Result := nil;
  if (fSelectedObject = nil) or fSelectedObject.IsGizmo then
    Exit;

  if (fSelectedBillboardIndex >= 0) and
     (fSelectedBillboardIndex < fSelectedObject.BillboardCount) then
    Result := fSelectedObject.BillboardItem[fSelectedBillboardIndex];
end;

function TSandBoxForm.SelectedAnimatedSprite: TAnimatedSprite;
begin
  Result := nil;
  if (fSelectedObject = nil) or fSelectedObject.IsGizmo then
    Exit;

  if (fSelectedAnimatedSpriteIndex >= 0) and
     (fSelectedAnimatedSpriteIndex < fSelectedObject.AnimatedSpriteCount) then
    Result := fSelectedObject.AnimatedSpriteItem[fSelectedAnimatedSpriteIndex];
end;

function TSandBoxForm.SelectedAudioEmitter: TSceneAudioEmitter;
begin
  Result := nil;
  if (fSelectedObject = nil) or fSelectedObject.IsGizmo then
    Exit;

  if (fSelectedAudioEmitterIndex >= 0) and
     (fSelectedAudioEmitterIndex < fSelectedObject.AudioEmitterCount) then
    Result := fSelectedObject.AudioEmitterItem[fSelectedAudioEmitterIndex];
end;

function TSandBoxForm.IsParticleAssetFile(const AFileName: string): Boolean;
begin
  Result := SameText(ExtractFileExt(AFileName), PARTICLE_FILE_EXTENSION_LOCAL);
end;

function TSandBoxForm.TryReadParticlePreviewInfo(const AFileName: string;
  out DisplayName, Summary, PreviewTexturePath: string; out FileSize: Int64;
  out ModifiedText: string): Boolean;
var
  Stream: TFileStream;
  Magic: array[0..7] of AnsiChar;
  Version: Integer;
  ModifiedAt: TDateTime;
  ParticleSystem: TParticleSystem;
  StoredTexturePath: string;

  function FormatFileSize(const Size: Int64): string;
  begin
    if Size >= 1024 * 1024 then
      Result := FormatFloat('0.0 MB', Size / (1024 * 1024))
    else if Size >= 1024 then
      Result := FormatFloat('0.0 KB', Size / 1024)
    else
      Result := IntToStr(Size) + ' B';
  end;
begin
  Result := False;
  DisplayName := ChangeFileExt(ExtractFileName(AFileName), '');
  Summary := '';
  PreviewTexturePath := '';
  FileSize := 0;
  ModifiedText := '';

  if not FileExists(AFileName) then
    Exit;

  try
    FileSize := TFile.GetSize(AFileName);
    ModifiedAt := TFile.GetLastWriteTime(AFileName);
    ModifiedText := FormatDateTime('yyyy-mm-dd hh:nn', ModifiedAt);
  except
    ModifiedText := '';
  end;

  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    if Stream.Size < SizeOf(Magic) + SizeOf(Version) then
      Exit;

    Stream.ReadBuffer(Magic[0], SizeOf(Magic));
    if not PreviewMagicMatches(Magic, PARTICLE_FILE_MAGIC_LOCAL) then
      Exit;

    Stream.ReadBuffer(Version, SizeOf(Version));
    if (Version < 1) or (Version > PARTICLE_FILE_VERSION_LOCAL) then
      Exit;

    ReadPreviewString(Stream); // Stored source object name; display the file stem.

    ParticleSystem := TParticleSystem.Create;
    try
      ParticleSystem.LoadFromStream(Stream);
      Summary := Format('%d max, %.1f emit/s, life %.2fs, %s, %s, %s',
        [ParticleSystem.MaxParticles, ParticleSystem.EmissionRate,
         ParticleSystem.ParticleLife,
         ParticleBlendModeDisplayName(ParticleSystem.BlendMode),
         ParticleTextureKindDisplayName(ParticleSystem.TextureKind),
         FormatFileSize(FileSize)]);
      if (ParticleSystem.TextureKind = ptFile) and
         (Trim(ParticleSystem.TexturePath) <> '') then
      begin
        StoredTexturePath := Trim(ParticleSystem.TexturePath);
        PreviewTexturePath := ResolveParticleTexturePreviewPath(StoredTexturePath);
        Summary := Summary + ', tex ' +
          TextureFileDisplayName(StoredTexturePath);
      end;
      if ModifiedText <> '' then
        Summary := Summary + ', modified ' + ModifiedText;
    finally
      ParticleSystem.Free;
    end;

    Result := True;
  finally
    Stream.Free;
  end;
end;

procedure TSandBoxForm.ClearParticleFilePreviews;
var
  I: Integer;
  TexID: GLuint;
begin
  for I := 0 to High(fParticleFileBrowser.Items) do
  begin
    TexID := fParticleFileBrowser.Items[I].TextureID;
    if TexID <> 0 then
    begin
      glDeleteTextures(1, @TexID);
      fParticleFileBrowser.Items[I].TextureID := 0;
    end;
  end;

  SetLength(fParticleFileBrowser.Items, 0);
end;

procedure TSandBoxForm.RefreshParticleFileList;
var
  Files: TArray<string>;
  I: Integer;
  Count: Integer;
  Item: TParticleFileInfo;
begin
  ActivateMainRenderContext;
  ClearParticleFilePreviews;

  fParticleFileBrowser.NeedsRefresh := False;
  fParticleFileBrowser.SelectedIndex := -1;
  fParticleFileBrowser.LastError := '';

  TEnginePaths.EnsureDirectories;
  if not TDirectory.Exists(TEnginePaths.ParticlesDir) then
  begin
    fParticleFileBrowser.LastError := 'Particles folder does not exist: ' +
      TEnginePaths.ParticlesDir;
    Exit;
  end;

  try
    Files := TDirectory.GetFiles(TEnginePaths.ParticlesDir,
      '*' + PARTICLE_FILE_EXTENSION_LOCAL, TSearchOption.soAllDirectories);
  except
    on E: Exception do
    begin
      fParticleFileBrowser.LastError := 'Could not scan particles folder: ' +
        E.Message;
      Exit;
    end;
  end;

  Count := 0;
  for I := 0 to High(Files) do
  begin
    if not IsParticleAssetFile(Files[I]) then
      Continue;

    Item := Default(TParticleFileInfo);
    Item.FileName := Files[I];
    Item.RelativePath := ExtractRelativePath(TEnginePaths.ParticlesDir,
      Files[I]);
    if Trim(Item.RelativePath) = '' then
      Item.RelativePath := ExtractFileName(Files[I]);
    Item.DisplayName := ChangeFileExt(ExtractFileName(Files[I]), '');
    Item.ValidParticleSystem := TryReadParticlePreviewInfo(Files[I],
      Item.DisplayName, Item.Summary, Item.PreviewTexturePath, Item.FileSize,
      Item.ModifiedText);
    if Item.Summary = '' then
      Item.Summary := 'Particle system';

    if (Item.PreviewTexturePath <> '') and FileExists(Item.PreviewTexturePath) then
      Item.PreviewReady := TryCreateParticleTexturePreview(
        Item.PreviewTexturePath, PARTICLE_FILE_THUMB_SIZE, Item.TextureID,
        Item.Width, Item.Height);

    SetLength(fParticleFileBrowser.Items, Count + 1);
    fParticleFileBrowser.Items[Count] := Item;
    Inc(Count);
  end;

  if Count = 0 then
    fParticleFileBrowser.LastError := 'No particle files found in ' +
      TEnginePaths.ParticlesDir;
end;

procedure TSandBoxForm.ResetParticleFileBrowser;
begin
  fParticleFileBrowser.Active := False;
  fParticleFileBrowser.NeedsRefresh := False;
  fParticleFileBrowser.Mode := pfbNone;
  fParticleFileBrowser.SelectedIndex := -1;
  fParticleFileBrowser.PendingOverwrite := False;
  fParticleFileBrowser.PendingOverwriteFileName := '';
  fParticleFileBrowser.LastError := '';
  SetAnsiBuffer(fParticleFileBrowser.Search, '');
  SetAnsiBuffer(fParticleFileBrowser.FileName, '');
  if not fInImGuiFrame then
    ClearParticleFilePreviews;
end;

procedure TSandBoxForm.OpenParticleFileBrowser(AMode: TParticleFileBrowserMode);
var
  Obj: TSceneObject;
  ParticleSystem: TParticleSystem;
  DefaultName: string;
begin
  fParticleFileBrowser.Active := True;
  fParticleFileBrowser.NeedsRefresh := True;
  fParticleFileBrowser.Mode := AMode;
  fParticleFileBrowser.SelectedIndex := -1;
  fParticleFileBrowser.PendingOverwrite := False;
  fParticleFileBrowser.PendingOverwriteFileName := '';
  fParticleFileBrowser.LastError := '';

  if AMode = pfbSaveParticle then
  begin
    Obj := SelectedParticleObject;
    DefaultName := '';
    ParticleSystem := SelectedParticleSystem;
    if Assigned(ParticleSystem) then
      DefaultName := Trim(ParticleSystem.Name);
    if (DefaultName = '') and Assigned(Obj) then
      DefaultName := Trim(Obj.Name);
    if DefaultName = '' then
      DefaultName := 'ParticleSystem';
    SetAnsiBuffer(fParticleFileBrowser.FileName,
      ChangeFileExt(DefaultName, PARTICLE_FILE_EXTENSION_LOCAL));
  end
  else
    SetAnsiBuffer(fParticleFileBrowser.FileName, '');
end;

procedure TSandBoxForm.SaveSelectedParticleSystemToFile(const AFileName: string);
var
  Obj: TSceneObject;
  ParticleSystem: TParticleSystem;
  ResolvedFileName: string;
  Stream: TFileStream;
  Version: Integer;
begin
  fParticleFileBrowser.LastError := '';
  Obj := SelectedParticleObject;
  if Obj = nil then
  begin
    fParticleFileBrowser.LastError := 'Select an object first.';
    Exit;
  end;

  ParticleSystem := SelectedParticleSystem;
  if ParticleSystem = nil then
  begin
    fParticleFileBrowser.LastError := 'Selected object has no selected particle system.';
    Exit;
  end;

  ResolvedFileName := Trim(AFileName);
  if ResolvedFileName = '' then
  begin
    fParticleFileBrowser.LastError := 'Enter a file name first.';
    Exit;
  end;

  if not TPath.IsPathRooted(ResolvedFileName) then
    ResolvedFileName := TPath.Combine(TEnginePaths.ParticlesDir,
      ResolvedFileName);

  try
    ForceDirectories(ExtractFilePath(ResolvedFileName));
    Stream := TFileStream.Create(ResolvedFileName, fmCreate);
    try
      Stream.WriteBuffer(PARTICLE_FILE_MAGIC_LOCAL[0],
        SizeOf(PARTICLE_FILE_MAGIC_LOCAL));
      Version := PARTICLE_FILE_VERSION_LOCAL;
      Stream.WriteBuffer(Version, SizeOf(Version));
      WritePreviewString(Stream, Obj.Name + ' / ' + ParticleSystem.Name);
      ParticleSystem.SaveToStream(Stream);
    finally
      Stream.Free;
    end;
  except
    on E: Exception do
    begin
      fParticleFileBrowser.LastError := 'Could not save particle system: ' +
        E.Message;
      Exit;
    end;
  end;

  LogLine('Particle system saved: ' + ResolvedFileName);
end;

procedure TSandBoxForm.LoadParticleSystemIntoSelectedObject(const AFileName: string);
var
  Obj: TSceneObject;
  ParticleSystem: TParticleSystem;
  ResolvedFileName: string;
  Stream: TFileStream;
  Magic: array[0..7] of AnsiChar;
  Version: Integer;
begin
  fParticleFileBrowser.LastError := '';
  Obj := SelectedParticleObject;
  if Obj = nil then
  begin
    fParticleFileBrowser.LastError := 'Select an object first.';
    Exit;
  end;

  ResolvedFileName := Trim(AFileName);
  if ResolvedFileName = '' then
  begin
    fParticleFileBrowser.LastError := 'Select a particle file first.';
    Exit;
  end;

  if not TPath.IsPathRooted(ResolvedFileName) then
    ResolvedFileName := TPath.Combine(TEnginePaths.ParticlesDir,
      ResolvedFileName);

  if not FileExists(ResolvedFileName) then
  begin
    fParticleFileBrowser.LastError := 'Particle file not found: ' +
      ResolvedFileName;
    Exit;
  end;

  try
    Stream := TFileStream.Create(ResolvedFileName, fmOpenRead or fmShareDenyWrite);
    try
      if Stream.Size < SizeOf(Magic) + SizeOf(Version) then
      begin
        fParticleFileBrowser.LastError := 'Invalid particle file.';
        Exit;
      end;

      Stream.ReadBuffer(Magic[0], SizeOf(Magic));
      if not PreviewMagicMatches(Magic, PARTICLE_FILE_MAGIC_LOCAL) then
      begin
        fParticleFileBrowser.LastError := 'Invalid particle file magic.';
        Exit;
      end;

      Stream.ReadBuffer(Version, SizeOf(Version));
      if (Version < 1) or (Version > PARTICLE_FILE_VERSION_LOCAL) then
      begin
        fParticleFileBrowser.LastError := Format(
          'Unsupported particle file version: %d.', [Version]);
        Exit;
      end;

      ReadPreviewString(Stream); // Stored source object/particle name.
      ParticleSystem := SelectedParticleSystem;
      if ParticleSystem = nil then
      begin
        ParticleSystem := Obj.AddParticleSystem;
        SelectParticleSystemIndex(Obj.ParticleSystemCount - 1);
      end;
      ParticleSystem.LoadFromStream(Stream);
    finally
      Stream.Free;
    end;
  except
    on E: Exception do
    begin
      fParticleFileBrowser.LastError := 'Could not load particle system: ' +
        E.Message;
      Exit;
    end;
  end;

  LogLine('Particle system loaded: ' + ResolvedFileName + ' -> ' +
    Obj.Name + ' / ' + ParticleSystem.Name);
  NotifyInspectorObjectEdited;
end;

procedure TSandBoxForm.ExecuteParticleFileBrowserAction;
var
  FileName: string;
  Ext: string;
  Item: TParticleFileInfo;
begin
  fParticleFileBrowser.LastError := '';
  FileName := '';

  case fParticleFileBrowser.Mode of
    pfbLoadParticle:
      begin
        if (fParticleFileBrowser.SelectedIndex < 0) or
           (fParticleFileBrowser.SelectedIndex > High(fParticleFileBrowser.Items)) then
        begin
          fParticleFileBrowser.LastError := 'Select a particle file first.';
          Exit;
        end;

        Item := fParticleFileBrowser.Items[fParticleFileBrowser.SelectedIndex];
        FileName := Item.FileName;
      end;

    pfbSaveParticle:
      begin
        FileName := Trim(AnsiBufferText(fParticleFileBrowser.FileName));
        if FileName = '' then
        begin
          fParticleFileBrowser.LastError := 'Enter a file name first.';
          Exit;
        end;

        if not TPath.IsPathRooted(FileName) then
          FileName := TPath.Combine(TEnginePaths.ParticlesDir, FileName);

        Ext := LowerCase(ExtractFileExt(FileName));
        if Ext = '' then
          FileName := ChangeFileExt(FileName, PARTICLE_FILE_EXTENSION_LOCAL)
        else if Ext <> PARTICLE_FILE_EXTENSION_LOCAL then
        begin
          fParticleFileBrowser.LastError := 'Particle files use ' +
            PARTICLE_FILE_EXTENSION_LOCAL;
          Exit;
        end;

        if FileExists(FileName) and
           ((not fParticleFileBrowser.PendingOverwrite) or
            (not SameText(fParticleFileBrowser.PendingOverwriteFileName, FileName))) then
        begin
          fParticleFileBrowser.PendingOverwrite := True;
          fParticleFileBrowser.PendingOverwriteFileName := FileName;
          fParticleFileBrowser.LastError := '';
          Exit;
        end;
      end;
  else
    Exit;
  end;

  case fParticleFileBrowser.Mode of
    pfbLoadParticle: LoadParticleSystemIntoSelectedObject(FileName);
    pfbSaveParticle: SaveSelectedParticleSystemToFile(FileName);
  end;

  if fParticleFileBrowser.LastError <> '' then
    Exit;

  ResetParticleFileBrowser;
  RequestRender;
end;

procedure TSandBoxForm.DrawImGuiParticleEditor;
var
  OpenWindow: Boolean;
  ExpandAll: Boolean;
  Obj: TSceneObject;
  ParticleSystem: TParticleSystem;
  EnabledValue: Boolean;
  AutoEmitValue: Boolean;
  IntValue: Integer;
  FloatValue: Single;
  VectorValue: array[0..2] of Single;
  ColorValue: array[0..3] of Single;
  SpaceValue: Integer;
  BlendValue: Integer;
  TextureValue: Integer;
  TexturePathBuf: array[0..255] of AnsiChar;
  TextureFullPath: string;
  I: Integer;
  NameBuf: array[0..127] of AnsiChar;
  DisplayName: string;

  procedure MarkParticleEdited;
  begin
    RequestRender;
  end;
begin
  if not fParticleEditorActive then
    Exit;

  OpenWindow := fParticleEditorActive;
  ExpandAll := fParticleEditorExpandAllOnNextOpen;

  ImGui.SetNextWindowPos(ImVec2.New(EditorViewportWidth - 372, 665),
    ImGuiCond_FirstUseEver);
  ImGui.SetNextWindowSize(ImVec2.New(360, 540), ImGuiCond_FirstUseEver);

  if ImGui.Begin_('Particle System', @OpenWindow) then
  begin
    Obj := SelectedParticleObject;
    if Obj = nil then
      ImGui.TextWrapped('Select a scene object to edit its particle system.')
    else
    begin
      ImGui.Text(PAnsiChar(AnsiString('Selected: ' + Obj.Name)));
      ImGui.PushId(Pointer(Obj));
      try
        ParticleSystem := nil;
        if ImGui.Button('+ Particle System') then
        begin
          ParticleSystem := Obj.AddParticleSystem;
          SelectParticleSystemIndex(Obj.ParticleSystemCount - 1);
          LogLine('Particle system created on object: ' + Obj.Name +
            ' / ' + ParticleSystem.Name);
          NotifyInspectorObjectEdited;
        end;

        if Obj.ParticleSystemCount = 0 then
        begin
          ImGui.TextWrapped('This object does not have a particle system yet.');
          if ImGui.Button('Load Particle System...') then
            OpenParticleFileBrowser(pfbLoadParticle);
          ParticleSystem := nil;
        end;
        if Obj.ParticleSystemCount > 0 then
        begin
          if (fSelectedParticleSystemIndex < 0) or
             (fSelectedParticleSystemIndex >= Obj.ParticleSystemCount) then
            SelectParticleSystemIndex(0);

          if ImGui.BeginListBox('##ParticleSystemList', ImVec2.New(-1, 100)) then
          begin
            for I := 0 to Obj.ParticleSystemCount - 1 do
            begin
              ParticleSystem := Obj.ParticleSystemItem[I];
              if ParticleSystem = nil then
                Continue;

              DisplayName := Trim(ParticleSystem.Name);
              if DisplayName = '' then
                DisplayName := Format('Particle System %d', [I + 1]);

              if ImGui.Selectable(PAnsiChar(AnsiString(DisplayName)),
                I = fSelectedParticleSystemIndex) then
                SelectParticleSystemIndex(I);
            end;
            ImGui.EndListBox;
          end;

          ParticleSystem := SelectedParticleSystem;
          if ParticleSystem <> nil then
          begin
            if ImGui.Button('Load...##Particle') then
              OpenParticleFileBrowser(pfbLoadParticle);

            ImGui.SameLine;
            if ImGui.Button('Save...##Particle') then
              OpenParticleFileBrowser(pfbSaveParticle);

            ImGui.SameLine;
            if ImGui.Button('Delete##ParticleSystem') then
            begin
              DeleteSelectedParticleSystem;
              ParticleSystem := SelectedParticleSystem;
            end;

            if ParticleSystem <> nil then
            begin
              ImGui.Text(PAnsiChar(AnsiString('Selected particle system: ' +
                ParticleSystem.Name)));
              SetAnsiBuffer(NameBuf, ParticleSystem.Name);
              ImGui.PushItemWidth(IMGUI_PROP_TEXT_WIDTH);
              if ImGui.InputText('Name##ParticleSystemName', @NameBuf[0],
                SizeOf(NameBuf)) then
              begin
                ParticleSystem.Name := Trim(AnsiBufferText(NameBuf));
                if ParticleSystem.Name = '' then
                  ParticleSystem.Name := 'ParticleSystem';
                MarkParticleEdited;
              end;
              ImGui.PopItemWidth;
            end;
          end;
        end;

        if ParticleSystem <> nil then
        begin
          if ImGui.Button('Burst 32') then
          begin
            if Assigned(fSceneManager) then
              fSceneManager.Update;
            ParticleSystem.Burst(32, Obj.WorldMatrix);
            MarkParticleEdited;
          end;

          ImGui.SameLine;
          if ImGui.Button('Clear##Particle') then
          begin
            ParticleSystem.Clear;
            MarkParticleEdited;
          end;

          ImGui.Text(PAnsiChar(AnsiString(Format('Live particles: %d / %d',
            [ParticleSystem.ParticleCount, ParticleSystem.MaxParticles]))));

          if ExpandAll then
            ImGui.SetNextTreeNodeOpen(True, ImGuiCond_Always);
          if ImGui.CollapsingHeader('General', ImGuiTreeNodeFlags_DefaultOpen) then
          begin
            EnabledValue := ParticleSystem.Enabled;
            if ImGui.Checkbox('Enabled', @EnabledValue) then
            begin
              ParticleSystem.Enabled := EnabledValue;
              MarkParticleEdited;
            end;

            AutoEmitValue := ParticleSystem.AutoEmit;
            if ImGui.Checkbox('Auto emit', @AutoEmitValue) then
            begin
              ParticleSystem.AutoEmit := AutoEmitValue;
              MarkParticleEdited;
            end;

            ImGui.Text('Simulation space');
            SpaceValue := Ord(ParticleSystem.SimulationSpace);
            ImGui.RadioButton('Object##ParticleSimulationSpace', @SpaceValue,
              Ord(psObject));
            ImGui.SameLine;
            ImGui.RadioButton('World##ParticleSimulationSpace', @SpaceValue,
              Ord(psWorld));
            if SpaceValue <> Ord(ParticleSystem.SimulationSpace) then
            begin
              ParticleSystem.SimulationSpace :=
                TParticleSimulationSpace(SpaceValue);
              MarkParticleEdited;
            end;

            if ParticleSystem.SimulationSpace = psWorld then
              ImGui.TextWrapped('World space: emitted particles stay in world coordinates and can form trails.')
            else
              ImGui.TextWrapped('Object space: emitted particles remain relative to the owner object.');
          end;

          if ExpandAll then
            ImGui.SetNextTreeNodeOpen(True, ImGuiCond_Always);
          if ImGui.CollapsingHeader('Emission', ImGuiTreeNodeFlags_DefaultOpen) then
          begin
            ImGui.PushItemWidth(IMGUI_PROP_SCALAR_WIDTH);

            IntValue := ParticleSystem.MaxParticles;
            if InspectorInputInt('Max particles', @IntValue, 1.0, 0, 100000,
              '%d', ImGuiSliderFlags_None) then
            begin
              ParticleSystem.MaxParticles := IntValue;
              MarkParticleEdited;
            end;

            IntValue := ParticleSystem.ParticlePoolSize;
            if InspectorInputInt('Pool size', @IntValue, 1.0, 0, 100000,
              '%d', ImGuiSliderFlags_None) then
            begin
              ParticleSystem.ParticlePoolSize := IntValue;
              MarkParticleEdited;
            end;

            FloatValue := ParticleSystem.EmissionRate;
            if InspectorInputFloat('Emission rate', @FloatValue, 0.1, 0.0,
              100000.0, '%.2f') then
            begin
              ParticleSystem.EmissionRate := FloatValue;
              MarkParticleEdited;
            end;

            FloatValue := ParticleSystem.ParticleLife;
            if InspectorInputFloat('Life', @FloatValue, 0.05, 0.001, 100000.0,
              '%.3f') then
            begin
              ParticleSystem.ParticleLife := FloatValue;
              MarkParticleEdited;
            end;

            FloatValue := ParticleSystem.ParticleLifeRandom;
            if InspectorInputFloat('Life random', @FloatValue, 0.05, 0.0,
              100000.0, '%.3f') then
            begin
              ParticleSystem.ParticleLifeRandom := FloatValue;
              MarkParticleEdited;
            end;

            ImGui.PopItemWidth;
          end;

          if ExpandAll then
            ImGui.SetNextTreeNodeOpen(True, ImGuiCond_Always);
          if ImGui.CollapsingHeader('Spawn', ImGuiTreeNodeFlags_DefaultOpen) then
          begin
            VectorValue[0] := ParticleSystem.InitialPosition.X;
            VectorValue[1] := ParticleSystem.InitialPosition.Y;
            VectorValue[2] := ParticleSystem.InitialPosition.Z;
            ImGui.PushItemWidth(IMGUI_PROP_VECTOR3_WIDTH);
            if InspectorInputFloat3('Initial position', @VectorValue[0], 0.05,
              -100000.0, 100000.0, '%.2f') then
            begin
              ParticleSystem.InitialPosition := Vector3(VectorValue[0],
                VectorValue[1], VectorValue[2]);
              MarkParticleEdited;
            end;

            VectorValue[0] := ParticleSystem.InitialVelocity.X;
            VectorValue[1] := ParticleSystem.InitialVelocity.Y;
            VectorValue[2] := ParticleSystem.InitialVelocity.Z;
            if InspectorInputFloat3('Initial velocity', @VectorValue[0], 0.05,
              -100000.0, 100000.0, '%.2f') then
            begin
              ParticleSystem.InitialVelocity := Vector3(VectorValue[0],
                VectorValue[1], VectorValue[2]);
              MarkParticleEdited;
            end;

            VectorValue[0] := ParticleSystem.PositionDispersionRange.X;
            VectorValue[1] := ParticleSystem.PositionDispersionRange.Y;
            VectorValue[2] := ParticleSystem.PositionDispersionRange.Z;
            if InspectorInputFloat3('Dispersion range', @VectorValue[0], 0.05,
              0.0, 100000.0, '%.2f') then
            begin
              ParticleSystem.PositionDispersionRange := Vector3(VectorValue[0],
                VectorValue[1], VectorValue[2]);
              MarkParticleEdited;
            end;
            ImGui.PopItemWidth;

            ImGui.PushItemWidth(IMGUI_PROP_SCALAR_WIDTH);
            FloatValue := ParticleSystem.PositionDispersion;
            if InspectorInputFloat('Position dispersion', @FloatValue, 0.05,
              0.0, 100000.0, '%.3f') then
            begin
              ParticleSystem.PositionDispersion := FloatValue;
              MarkParticleEdited;
            end;

            FloatValue := ParticleSystem.VelocityDispersion;
            if InspectorInputFloat('Velocity dispersion', @FloatValue, 0.05,
              0.0, 100000.0, '%.3f') then
            begin
              ParticleSystem.VelocityDispersion := FloatValue;
              MarkParticleEdited;
            end;
            ImGui.PopItemWidth;
          end;

          if ExpandAll then
            ImGui.SetNextTreeNodeOpen(True, ImGuiCond_Always);
          if ImGui.CollapsingHeader('Motion', ImGuiTreeNodeFlags_DefaultOpen) then
          begin
            VectorValue[0] := ParticleSystem.Acceleration.X;
            VectorValue[1] := ParticleSystem.Acceleration.Y;
            VectorValue[2] := ParticleSystem.Acceleration.Z;
            ImGui.PushItemWidth(IMGUI_PROP_VECTOR3_WIDTH);
            if InspectorInputFloat3('Acceleration', @VectorValue[0], 0.05,
              -100000.0, 100000.0, '%.2f') then
            begin
              ParticleSystem.Acceleration := Vector3(VectorValue[0],
                VectorValue[1], VectorValue[2]);
              MarkParticleEdited;
            end;
            ImGui.PopItemWidth;

            ImGui.PushItemWidth(IMGUI_PROP_SCALAR_WIDTH);
            FloatValue := ParticleSystem.Friction;
            if InspectorInputFloat('Friction', @FloatValue, 0.01, 0.0,
              100000.0, '%.3f') then
            begin
              ParticleSystem.Friction := FloatValue;
              MarkParticleEdited;
            end;

            FloatValue := ParticleSystem.RotationDispersion;
            if InspectorInputFloat('Rotation dispersion', @FloatValue, 0.05,
              0.0, 100000.0, '%.3f') then
            begin
              ParticleSystem.RotationDispersion := FloatValue;
              MarkParticleEdited;
            end;

            FloatValue := ParticleSystem.AngularVelocityDispersion;
            if InspectorInputFloat('Angular velocity dispersion', @FloatValue,
              0.05, 0.0, 100000.0, '%.3f') then
            begin
              ParticleSystem.AngularVelocityDispersion := FloatValue;
              MarkParticleEdited;
            end;
            ImGui.PopItemWidth;
          end;

          if ExpandAll then
            ImGui.SetNextTreeNodeOpen(True, ImGuiCond_Always);
          if ImGui.CollapsingHeader('Appearance', ImGuiTreeNodeFlags_DefaultOpen) then
          begin
            ColorValue[0] := ParticleSystem.StartColor.X;
            ColorValue[1] := ParticleSystem.StartColor.Y;
            ColorValue[2] := ParticleSystem.StartColor.Z;
            ColorValue[3] := ParticleSystem.StartColor.W;
            if ImGui.ColorEdit4('Start color', @ColorValue[0]) then
            begin
              ParticleSystem.StartColor := Vector4(ColorValue[0], ColorValue[1],
                ColorValue[2], ColorValue[3]);
              MarkParticleEdited;
            end;

            ColorValue[0] := ParticleSystem.EndColor.X;
            ColorValue[1] := ParticleSystem.EndColor.Y;
            ColorValue[2] := ParticleSystem.EndColor.Z;
            ColorValue[3] := ParticleSystem.EndColor.W;
            if ImGui.ColorEdit4('End color', @ColorValue[0]) then
            begin
              ParticleSystem.EndColor := Vector4(ColorValue[0], ColorValue[1],
                ColorValue[2], ColorValue[3]);
              MarkParticleEdited;
            end;

            ImGui.PushItemWidth(IMGUI_PROP_SCALAR_WIDTH);
            FloatValue := ParticleSystem.StartSize;
            if InspectorInputFloat('Start size', @FloatValue, 0.01, 0.0,
              100000.0, '%.3f') then
            begin
              ParticleSystem.StartSize := FloatValue;
              MarkParticleEdited;
            end;

            FloatValue := ParticleSystem.EndSize;
            if InspectorInputFloat('End size', @FloatValue, 0.01, 0.0,
              100000.0, '%.3f') then
            begin
              ParticleSystem.EndSize := FloatValue;
              MarkParticleEdited;
            end;

            FloatValue := ParticleSystem.SizeRandom;
            if InspectorInputFloat('Size random', @FloatValue, 0.01, 0.0,
              100000.0, '%.3f') then
            begin
              ParticleSystem.SizeRandom := FloatValue;
              MarkParticleEdited;
            end;

            FloatValue := ParticleSystem.AspectRatio;
            if InspectorInputFloat('Aspect ratio', @FloatValue, 0.01, 0.001,
              1000.0, '%.3f') then
            begin
              ParticleSystem.AspectRatio := FloatValue;
              MarkParticleEdited;
            end;
            ImGui.PopItemWidth;
          end;

          if ExpandAll then
            ImGui.SetNextTreeNodeOpen(True, ImGuiCond_Always);
          if ImGui.CollapsingHeader('Rendering', ImGuiTreeNodeFlags_DefaultOpen) then
          begin
            BlendValue := Ord(ParticleSystem.BlendMode);
            ImGui.Text('Blend mode');
            ImGui.RadioButton('Alpha##ParticleBlend', @BlendValue,
              Ord(pbAlpha));
            ImGui.SameLine;
            ImGui.RadioButton('Additive##ParticleBlend', @BlendValue,
              Ord(pbAdditive));
            if BlendValue <> Ord(ParticleSystem.BlendMode) then
            begin
              ParticleSystem.BlendMode := TParticleBlendMode(BlendValue);
              MarkParticleEdited;
            end;

            TextureValue := Ord(ParticleSystem.TextureKind);
            ImGui.Text('Texture');
            ImGui.RadioButton('None##ParticleTexture', @TextureValue,
              Ord(ptNone));
            ImGui.SameLine;
            ImGui.RadioButton('Soft Circle##ParticleTexture', @TextureValue,
              Ord(ptSoftCircle));
            ImGui.RadioButton('Perlin##ParticleTexture', @TextureValue,
              Ord(ptPerlin));
            ImGui.SameLine;
            ImGui.RadioButton('File##ParticleTexture', @TextureValue,
              Ord(ptFile));
            if TextureValue <> Ord(ParticleSystem.TextureKind) then
            begin
              ParticleSystem.TextureKind :=
                TParticleTextureKind(TextureValue);
              MarkParticleEdited;
            end;
          end;

          if ParticleSystem.TextureKind = ptFile then
          begin
            if ExpandAll then
              ImGui.SetNextTreeNodeOpen(True, ImGuiCond_Always);
            if ImGui.CollapsingHeader('Texture File',
              ImGuiTreeNodeFlags_DefaultOpen) then
            begin
              SetAnsiBuffer(TexturePathBuf, ParticleSystem.TexturePath);
              ImGui.PushItemWidth(-1);
              if ImGui.InputText('Asset path', @TexturePathBuf[0],
                SizeOf(TexturePathBuf)) then
              begin
                ParticleSystem.TexturePath := Trim(AnsiBufferText(TexturePathBuf));
                MarkParticleEdited;
              end;
              ImGui.PopItemWidth;

              TextureFullPath := TEnginePaths.ResolveAssetPath(
                ParticleSystem.TexturePath);
              if Trim(ParticleSystem.TexturePath) = '' then
                ImGui.TextWrapped('Pick a .tga or .png texture from the texture library.')
              else
              begin
                ImGui.TextWrapped(AnsiString('Texture: ' +
                  TextureFileDisplayName(ParticleSystem.TexturePath)));
                if FileExists(TextureFullPath) then
                  ImGui.TextWrapped(AnsiString(TextureFullPath))
                else
                  ImGui.TextWrapped('Texture file is missing. Choose another asset or clear the path.');
              end;

              if ImGui.Button('Browse Texture...') then
                OpenParticleTextureBrowser;

              ImGui.SameLine;
              if ImGui.Button('Clear File##ParticleTexture') then
              begin
                ParticleSystem.TexturePath := '';
                MarkParticleEdited;
              end;
            end;
          end;

          if ParticleSystem.TextureKind in [ptSoftCircle, ptPerlin] then
          begin
            if ExpandAll then
              ImGui.SetNextTreeNodeOpen(True, ImGuiCond_Always);
            if ImGui.CollapsingHeader('Texture Generator',
              ImGuiTreeNodeFlags_DefaultOpen) then
            begin
              ImGui.Text(PAnsiChar(AnsiString(Format('Generated size: %d x %d',
                [1 shl ParticleSystem.TexMapSize,
                 1 shl ParticleSystem.TexMapSize]))));

              ImGui.PushItemWidth(IMGUI_PROP_SCALAR_WIDTH);
              IntValue := ParticleSystem.TexMapSize;
              if InspectorInputInt('Texture size exp', @IntValue, 1.0, 3, 10,
                '%d', ImGuiSliderFlags_None) then
              begin
                ParticleSystem.TexMapSize := IntValue;
                MarkParticleEdited;
              end;

              IntValue := ParticleSystem.NoiseSeed;
              if InspectorInputInt('Noise seed', @IntValue, 1.0, -2147483647,
                2147483647, '%d', ImGuiSliderFlags_None) then
              begin
                ParticleSystem.NoiseSeed := IntValue;
                MarkParticleEdited;
              end;

              IntValue := ParticleSystem.NoiseScale;
              if InspectorInputInt('Noise scale', @IntValue, 1.0, 0, 1000000,
                '%d', ImGuiSliderFlags_None) then
              begin
                ParticleSystem.NoiseScale := IntValue;
                MarkParticleEdited;
              end;

              IntValue := ParticleSystem.NoiseAmplitude;
              if InspectorInputInt('Noise amplitude', @IntValue, 1.0, 0, 100,
                '%d', ImGuiSliderFlags_None) then
              begin
                ParticleSystem.NoiseAmplitude := IntValue;
                MarkParticleEdited;
              end;

              FloatValue := ParticleSystem.Smoothness;
              if InspectorInputFloat('Smoothness', @FloatValue, 0.05, 0.001,
                1000.0, '%.3f') then
              begin
                ParticleSystem.Smoothness := FloatValue;
                MarkParticleEdited;
              end;

              FloatValue := ParticleSystem.Brightness;
              if InspectorInputFloat('Brightness', @FloatValue, 0.05, 0.001,
                1000.0, '%.3f') then
              begin
                ParticleSystem.Brightness := FloatValue;
                MarkParticleEdited;
              end;

              FloatValue := ParticleSystem.Gamma;
              if InspectorInputFloat('Gamma', @FloatValue, 0.05, 0.1, 10.0,
                '%.3f') then
              begin
                ParticleSystem.Gamma := FloatValue;
                MarkParticleEdited;
              end;
              ImGui.PopItemWidth;
            end;
          end;
        end;
      finally
        ImGui.PopId;
      end;
    end;
  end;

  ImGui.End_;

  fParticleEditorActive := OpenWindow;
  if ExpandAll then
    fParticleEditorExpandAllOnNextOpen := False;
end;

procedure TSandBoxForm.DrawImGuiParticleFileBrowser;
var
  OpenWindow: Boolean;
  I: Integer;
  SearchText: string;
  Item: TParticleFileInfo;
  Selected: Boolean;
  TitleText: string;
  ActionText: string;
  ListTitleText: string;
  TitleAnsi: AnsiString;
  Texture: ImTextureID;
  ReplaceClicked: Boolean;
  CancelOverwriteClicked: Boolean;
begin
  if not fParticleFileBrowser.Active then
    Exit;

  if fParticleFileBrowser.NeedsRefresh then
    RefreshParticleFileList;

  case fParticleFileBrowser.Mode of
    pfbLoadParticle:
      begin
        TitleText := 'Load Particle System';
        ActionText := 'Load Particle System';
        ListTitleText := 'Search Particle Systems';
      end;
    pfbSaveParticle:
      begin
        TitleText := 'Save Particle System';
        ActionText := 'Save Particle System';
        ListTitleText := 'Search Particle Systems';
      end;
  else
    Exit;
  end;

  TitleAnsi := AnsiString(TitleText);
  ImGui.SetNextWindowSize(ImVec2.New(720, 460), ImGuiCond_Appearing);
  ImGui.SetNextWindowPosCenter(ImGuiCond_Appearing);
  ImGui.OpenPopup(PAnsiChar(TitleAnsi));
  OpenWindow := True;
  if ImGui.BeginPopupModal(PAnsiChar(TitleAnsi), @OpenWindow,
    ImGuiWindowFlags_NoResize) then
  begin
    if ImGui.BeginChild('ParticleFileActionPane', ImVec2.New(240, -1)) then
    begin
      ImGui.TextWrapped(AnsiString('Particle systems are saved in: ' +
        TEnginePaths.ParticlesDir));
      ImGui.Separator;

      if (fParticleFileBrowser.SelectedIndex >= 0) and
         (fParticleFileBrowser.SelectedIndex <= High(fParticleFileBrowser.Items)) then
      begin
        Item := fParticleFileBrowser.Items[fParticleFileBrowser.SelectedIndex];
        if Item.TextureID <> 0 then
        begin
          Texture := ImTextureID(NativeUInt(Item.TextureID));
          ImGui.Image(Texture, ImVec2.New(160, 160), ImVec2.New(0, 0),
            ImVec2.New(1, 1), ImVec4.New(1, 1, 1, 1), ImVec4.New(0, 0, 0, 0));
        end
        else if Item.PreviewTexturePath <> '' then
          ImGui.TextWrapped('Texture preview is unavailable.');

        ImGui.Text(PAnsiChar(AnsiString(Item.DisplayName)));
        ImGui.TextWrapped(AnsiString(Item.Summary));
        ImGui.TextWrapped(AnsiString(Item.RelativePath));
        if not Item.ValidParticleSystem then
          ImGui.TextWrapped('Particle preview is unavailable.');
      end
      else if fParticleFileBrowser.Mode = pfbLoadParticle then
        ImGui.TextWrapped('Select a particle system file.')
      else
        ImGui.TextWrapped('Choose an existing particle file or enter a new file name.');

      if fParticleFileBrowser.Mode = pfbSaveParticle then
      begin
        ImGui.Separator;
        ImGui.PushItemWidth(-1);
        if ImGui.InputText(PAnsiChar(AnsiString('File name')),
          @fParticleFileBrowser.FileName[0],
          SizeOf(fParticleFileBrowser.FileName)) then
        begin
          fParticleFileBrowser.PendingOverwrite := False;
          fParticleFileBrowser.PendingOverwriteFileName := '';
          fParticleFileBrowser.LastError := '';
        end;
        ImGui.PopItemWidth;
      end;

      if fParticleFileBrowser.PendingOverwrite then
      begin
        DrawOverwriteConfirmation(fParticleFileBrowser.PendingOverwriteFileName,
          'Particle file', 'ParticleFiles', ReplaceClicked,
          CancelOverwriteClicked);

        if ReplaceClicked then
        begin
          try
            ExecuteParticleFileBrowserAction;
            if not fParticleFileBrowser.Active then
              ImGui.CloseCurrentPopup;
          except
            on E: Exception do
              fParticleFileBrowser.LastError := E.Message;
          end;
        end;

        if CancelOverwriteClicked then
        begin
          fParticleFileBrowser.PendingOverwrite := False;
          fParticleFileBrowser.PendingOverwriteFileName := '';
          fParticleFileBrowser.LastError := '';
        end;
      end
      else
      begin
        ImGui.Separator;
        if ImGui.Button(AnsiString(ActionText), ImVec2.New(-1, 0)) then
        begin
          try
            ExecuteParticleFileBrowserAction;
            if not fParticleFileBrowser.Active then
              ImGui.CloseCurrentPopup;
          except
            on E: Exception do
              fParticleFileBrowser.LastError := E.Message;
          end;
        end;
      end;

      if ImGui.Button('Cancel##ParticleFiles', ImVec2.New(-1, 0)) then
      begin
        ImGui.CloseCurrentPopup;
        ResetParticleFileBrowser;
      end;

      if ImGui.Button('Refresh##ParticleFiles', ImVec2.New(-1, 0)) then
        RefreshParticleFileList;

      if fParticleFileBrowser.LastError <> '' then
      begin
        ImGui.Separator;
        ImGui.TextWrapped(AnsiString(fParticleFileBrowser.LastError));
      end;
    end;
    ImGui.EndChild;

    ImGui.SameLine;

    if ImGui.BeginChild('ParticleFileListPane', ImVec2.New(0, -1)) then
    begin
      ImGui.Text(PAnsiChar(AnsiString(ListTitleText)));
      ImGui.PushItemWidth(-1);
      ImGui.InputText(PAnsiChar(AnsiString('##ParticleFileSearch')),
        @fParticleFileBrowser.Search[0], SizeOf(fParticleFileBrowser.Search));
      ImGui.PopItemWidth;
      ImGui.Separator;

      SearchText := LowerCase(Trim(AnsiBufferText(fParticleFileBrowser.Search)));
      if ImGui.BeginChild('ParticleFileListItems', ImVec2.New(-1, -1)) then
      begin
        for I := 0 to High(fParticleFileBrowser.Items) do
        begin
          Item := fParticleFileBrowser.Items[I];
          if (SearchText <> '') and
             (Pos(SearchText, LowerCase(Item.DisplayName)) = 0) and
             (Pos(SearchText, LowerCase(Item.RelativePath)) = 0) and
             (Pos(SearchText, LowerCase(Item.Summary)) = 0) then
            Continue;

          Selected := I = fParticleFileBrowser.SelectedIndex;
          ImGui.PushId(I);
          ImGui.BeginGroup;
          if Item.TextureID <> 0 then
          begin
            Texture := ImTextureID(NativeUInt(Item.TextureID));
            if ImGui.ImageButton(PAnsiChar(AnsiString('preview')), Texture,
              ImVec2.New(PARTICLE_FILE_THUMB_SIZE, PARTICLE_FILE_THUMB_SIZE),
              ImVec2.New(0, 0), ImVec2.New(1, 1), ImVec4.New(0, 0, 0, 0),
              ImVec4.New(1, 1, 1, 1)) then
            begin
              fParticleFileBrowser.SelectedIndex := I;
              if fParticleFileBrowser.Mode = pfbSaveParticle then
              begin
                SetAnsiBuffer(fParticleFileBrowser.FileName,
                  ExtractFileName(Item.FileName));
                fParticleFileBrowser.PendingOverwrite := False;
                fParticleFileBrowser.PendingOverwriteFileName := '';
                fParticleFileBrowser.LastError := '';
              end;
            end;
          end
          else if ImGui.Button('[no texture]',
            ImVec2.New(PARTICLE_FILE_THUMB_SIZE, PARTICLE_FILE_THUMB_SIZE)) then
          begin
            fParticleFileBrowser.SelectedIndex := I;
            if fParticleFileBrowser.Mode = pfbSaveParticle then
            begin
              SetAnsiBuffer(fParticleFileBrowser.FileName,
                ExtractFileName(Item.FileName));
              fParticleFileBrowser.PendingOverwrite := False;
              fParticleFileBrowser.PendingOverwriteFileName := '';
              fParticleFileBrowser.LastError := '';
            end;
          end;

          ImGui.SameLine;
          ImGui.BeginGroup;
          if ImGui.Selectable(AnsiString(Item.DisplayName + '##particlefile' +
            IntToStr(I)), Selected) then
          begin
            fParticleFileBrowser.SelectedIndex := I;
            if fParticleFileBrowser.Mode = pfbSaveParticle then
            begin
              SetAnsiBuffer(fParticleFileBrowser.FileName,
                ExtractFileName(Item.FileName));
              fParticleFileBrowser.PendingOverwrite := False;
              fParticleFileBrowser.PendingOverwriteFileName := '';
              fParticleFileBrowser.LastError := '';
            end;
          end;

          ImGui.TextWrapped(AnsiString(Item.Summary));
          ImGui.TextWrapped(AnsiString(Item.RelativePath));
          ImGui.EndGroup;
          ImGui.EndGroup;
          ImGui.Separator;
          ImGui.PopId;
        end;
      end;
      ImGui.EndChild;
    end;
    ImGui.EndChild;
    ImGui.EndPopup;
  end;

  if not OpenWindow then
    ResetParticleFileBrowser;
end;

procedure TSandBoxForm.UpdateScene(const DeltaTime, NewTime: Double);
const
  SMOOTH_SPEED = 40.0;
var
  Alpha: Single;
begin
  if fEngine <> nil then
    fEngine.Update(DeltaTime, NewTime);

  if DeltaTime > 0 then
  begin
    Alpha := 1 - Power(0.01, DeltaTime * SMOOTH_SPEED);

    fCurrentRadius := fCurrentRadius + (fTargetRadius - fCurrentRadius) * Alpha;
    fCurrentAzimuth := fCurrentAzimuth + (fTargetAzimuth - fCurrentAzimuth) * Alpha;
    fCurrentPolar := fCurrentPolar + (fTargetPolar - fCurrentPolar) * Alpha;

    if fCurrentPolar < 0.01 then
      fCurrentPolar := 0.01;
    if fCurrentPolar > Pi - 0.01 then
      fCurrentPolar := Pi - 0.01;
  end;

  UpdateKeyboardCameraMovement(DeltaTime);

  if Assigned(fRenderer) then
    fRenderer.ShadowTarget := fOrbitTarget;

  UpdateOrbitCamera;

  if Assigned(fCurrentGizmo) then
    UpdateGizmoScale;
end;

procedure TSandBoxForm.UpdateKeyboardCameraMovement(const DeltaTime: Double);
var
  MoveDir: TVector3;
  ForwardVec: TVector3;
  LeftVec: TVector3;
  MoveDistance: Single;
  SpeedMultiplier: Single;
begin
  if DeltaTime <= 0 then
    Exit;

  if not Active then
    Exit;

  if (fCamera = nil) or (fCamera.Camera = nil) then
    Exit;

  if ImGuiWantsKeyboardCapture then
    Exit;

  ForwardVec := Vector3(-Cos(fCurrentAzimuth), 0, -Sin(fCurrentAzimuth));
  if ForwardVec.LengthSquared <= 1e-6 then
    Exit;
  ForwardVec.SetNormalized;

  LeftVec := ForwardVec.Cross(Vector3(0, 1, 0));
  if LeftVec.LengthSquared <= 1e-6 then
    Exit;
  LeftVec.SetNormalized;

  MoveDir := Vector3(0, 0, 0);

  if (GetAsyncKeyState(Ord('W')) and $8000) <> 0 then
    MoveDir := MoveDir + ForwardVec;
  if (GetAsyncKeyState(Ord('S')) and $8000) <> 0 then
    MoveDir := MoveDir - ForwardVec;
  if (GetAsyncKeyState(Ord('A')) and $8000) <> 0 then
    MoveDir := MoveDir - LeftVec;
  if (GetAsyncKeyState(Ord('D')) and $8000) <> 0 then
    MoveDir := MoveDir + LeftVec;
  if (GetAsyncKeyState(Ord('E')) and $8000) <> 0 then
    MoveDir := MoveDir + Vector3(0, 1, 0);
  if (GetAsyncKeyState(Ord('Q')) and $8000) <> 0 then
    MoveDir := MoveDir - Vector3(0, 1, 0);

  if MoveDir.LengthSquared <= 1e-6 then
    Exit;

  MoveDir.SetNormalized;
  SpeedMultiplier := 1.0;

  if (GetAsyncKeyState(VK_SHIFT) and $8000) <> 0 then
    SpeedMultiplier := SpeedMultiplier * 5.0;
  if (GetAsyncKeyState(VK_CONTROL) and $8000) <> 0 then
    SpeedMultiplier := SpeedMultiplier / 5.0;

  MoveDistance := fCameraMoveSpeed * SpeedMultiplier * DeltaTime;
  fOrbitTarget := fOrbitTarget + (MoveDir * MoveDistance);
end;

procedure TSandBoxForm.SyncOrbitFromCamera;
var
  Direction: TVector3;
begin
  if (fCamera = nil) or (fCamera.Camera = nil) then
    Exit;

  fOrbitTarget := fCamera.Camera.Target;
  fCameraUp := fCamera.Camera.Up;
  if fCameraUp.LengthSquared < 1e-8 then
    fCameraUp := Vector3(0, -1, 0)
  else
    fCameraUp.Normalize;

  Direction := fCamera.Camera.Position - fOrbitTarget;
  fCurrentRadius := Direction.Length;
  if fCurrentRadius < 0.001 then
    fCurrentRadius := 0.001;

  fCurrentAzimuth := System.Math.ArcTan2(Direction.Z, Direction.X);
  fCurrentPolar := ArcCos(System.Math.EnsureRange(
    Direction.Y / fCurrentRadius, -1.0, 1.0));
  fTargetRadius := fCurrentRadius;
  fTargetAzimuth := fCurrentAzimuth;
  fTargetPolar := fCurrentPolar;

  if Assigned(fRenderer) then
    fRenderer.ShadowTarget := fOrbitTarget;
end;

procedure TSandBoxForm.UpdateOrbitCamera;
var
  X, Y, Z: Single;
  Pos: TVector3;
begin
  if (fCamera = nil) or (fCamera.Camera = nil) then
    Exit;

  X := fCurrentRadius * Sin(fCurrentPolar) * Cos(fCurrentAzimuth);
  Y := fCurrentRadius * Cos(fCurrentPolar);
  Z := fCurrentRadius * Sin(fCurrentPolar) * Sin(fCurrentAzimuth);

  Pos := Vector3(X, Y, Z) + fOrbitTarget;
  fCamera.Camera.LookAt(Pos, fOrbitTarget, fCameraUp);
end;

procedure TSandBoxForm.SyncSkyDomeToMainLight;
var
  LightObj: TSceneObject;
  Light: TLight;
  SunDir: TVector3;
begin
  if (fRenderer = nil) or (fRenderer.SkyDome = nil) then
    Exit;

  LightObj := fRenderer.ShadowLight;
  if LightObj = nil then
    LightObj := fLight;

  if (LightObj = nil) or (LightObj.LightsCount <= 0) then
    Exit;

  Light := LightObj.Light[0];
  if Light = nil then
    Exit;

  if not (Light.LightType in [ltDirectional, ltSpot]) then
    Exit;

  SunDir := Light.Direction;
  if SunDir.LengthSquared < 1e-8 then
    Exit;

  SunDir.Normalize;
  fRenderer.SkyDome.SunDirection := -SunDir;
end;

procedure TSandBoxForm.ApplyFrameUniformsToShader(Shader: TShader);
var
  RenderCamera: TSceneObject;
begin
  if fEngine <> nil then
  begin
    fEngine.ApplyFrameUniformsToShader(Shader);
    Exit;
  end;

  if (Shader = nil) or (fRenderer = nil) then
    Exit;

  RenderCamera := fRenderer.ActiveCamera;
  if RenderCamera = nil then
    RenderCamera := fCamera;

  if (RenderCamera = nil) or (RenderCamera.Camera = nil) then
    Exit;

  Shader.Use;
  Shader.SetUniform('eyePosition', RenderCamera.Camera.Position);
  Shader.SetUniform('viewProjection',
    fRenderer.ProjectionMatrix * RenderCamera.Camera.ViewMatrix);
  Shader.SetUniform('useFog', GLint(Ord(fRenderer.FogEnabled)));
  Shader.SetUniform('fogColor', fRenderer.EffectiveFogColor);
  Shader.SetUniform('fogStart', fRenderer.FogStart);
  Shader.SetUniform('fogEnd', fRenderer.FogEnd);
  Shader.SetUniform('fogDensity', fRenderer.FogDensity);
  Shader.SetUniform('usePostToneMapping', GLint(Ord(fRenderer.HDRPostProcessActive)));

  // Restored from the old MainUnit shadow path.  Water/reflection passes can
  // enable a clip plane on the renderer, so keep those uniforms in sync too.
  if fRenderer.SceneClipPlaneEnabled then
  begin
    Shader.SetUniform('useClipPlane', GLint(1));
    Shader.SetUniform('clipPlane', fRenderer.SceneClipPlane);
  end
  else
  begin
    Shader.SetUniform('useClipPlane', GLint(0));
    Shader.SetUniform('clipPlane', Vector4(0.0, 1.0, 0.0, 0.0));
  end;

  ApplySceneLightsToShader(Shader);
  Shader.SetUniform('lightSpaceMatrix', fRenderer.ShadowLightViewProjection);

  if fRenderer.ShadowEnabled and (fRenderer.ShadowDepthTexture <> 0) and
     (fRenderer.ShadowMapCount > 0) then
  begin
    glActiveTexture(GL_TEXTURE8);
    glBindTexture(GL_TEXTURE_2D_ARRAY, fRenderer.ShadowDepthTexture);

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

procedure TSandBoxForm.ApplyLightToShader(Shader: TShader; Light: TLight; Index: Integer);
var
  Prefix: string;
  TypeInt: Integer;
  CosCutoff: Single;
  Direction: TVector3;
begin
  if fEngine <> nil then
  begin
    fEngine.ApplyLightToShader(Shader, Light, Index);
    Exit;
  end;

  if not Assigned(Shader) then
    Exit;

  Prefix := Format('lights[%d].', [Index]);

  if not Assigned(Light) then
  begin
    Shader.SetUniform(Prefix + 'enabled', 0);
    Exit;
  end;

  case Light.LightType of
    ltDirectional: TypeInt := 0;
    ltPoint: TypeInt := 1;
    ltSpot: TypeInt := 2;
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

procedure TSandBoxForm.ApplySceneLightsToShader(Shader: TShader);
const
  MAX_SHADER_LIGHTS = 8;
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
  if fEngine <> nil then
  begin
    fEngine.ApplySceneLightsToShader(Shader);
    Exit;
  end;

  if not Assigned(Shader) then
    Exit;

  if not Assigned(fSceneManager) then
  begin
    Shader.SetUniform('lightCount', 0);
    Shader.SetUniform('shadowLightIndex', -1);
    Shader.SetUniform('shadowStrength', 0.0);
    Shader.SetUniform('shadowMapCount', 0);
    Exit;
  end;

  Lights := fSceneManager.GetLights;
  LightCount := Min(Length(Lights), MAX_SHADER_LIGHTS);
  Shader.SetUniform('lightCount', LightCount);

  ShadowLightIndex := -1;
  ShadowStrength := 0.0;

  if Assigned(fRenderer) then
    Shader.SetUniform('shadowMapCount', fRenderer.ShadowMapCount)
  else
    Shader.SetUniform('shadowMapCount', 0);

  for I := 0 to MAX_SHADER_LIGHTS - 1 do
  begin
    ShadowLayer := -1;
    LayerStrength := 0.0;
    ShadowMatrix := TMatrix4.Identity;

    if Assigned(fRenderer) then
    begin
      ShadowLayer := fRenderer.ShadowMapLayerForLightIndex(I);
      if ShadowLayer >= 0 then
      begin
        ShadowMatrix := fRenderer.ShadowLightMatrixForLightIndex(I);
        LayerStrength := fRenderer.ShadowStrengthForLightIndex(I);
        if ShadowLightIndex < 0 then
        begin
          ShadowLightIndex := I;
          ShadowStrength := LayerStrength;
        end;
      end;
    end;

    Shader.SetUniform(Format('shadowMapIndices[%d]', [I]), ShadowLayer);
    Shader.SetUniform(Format('shadowStrengths[%d]', [I]),
      LayerStrength);
    Shader.SetUniform(Format('lightSpaceMatrices[%d]', [I]), ShadowMatrix);
  end;

  Shader.SetUniform('shadowLightIndex', ShadowLightIndex);
  Shader.SetUniform('shadowStrength', ShadowStrength);

  for I := 0 to LightCount - 1 do
    ApplyLightToShader(Shader, Lights[I], I);

  for I := LightCount to MAX_SHADER_LIGHTS - 1 do
    Shader.SetUniform(Format('lights[%d].enabled', [I]), 0);
end;

procedure TSandBoxForm.OnUpdateShader(Shader: TShader);
begin
  if fEngine <> nil then
  begin
    fEngine.OnUpdateShader(Shader);
    Exit;
  end;

  ApplyFrameUniformsToShader(Shader);
end;

procedure TSandBoxForm.OnUpdateGizmoShader(Shader: TShader);
var
  RenderCamera: TSceneObject;
begin
  if (Shader = nil) or (fRenderer = nil) then
    Exit;

  RenderCamera := fRenderer.ActiveCamera;
  if RenderCamera = nil then
    RenderCamera := fCamera;

  if (RenderCamera = nil) or (RenderCamera.Camera = nil) then
    Exit;

  Shader.Use;
  Shader.SetUniform('viewProjection', fRenderer.ProjectionMatrix * RenderCamera.Camera.ViewMatrix);
end;

procedure TSandBoxForm.MeshRenderHandler(Mesh: TMesh; Shader: TShader);
begin
  if fEngine <> nil then
  begin
    fEngine.MeshRenderHandler(Mesh, Shader);
    Exit;
  end;

  if (Mesh = nil) or (Shader = nil) then
    Exit;

  ApplyFrameUniformsToShader(Shader);
  Shader.SetUniform('modelMatrix', Mesh.ModelMatrix);
  Shader.SetUniform('alpha', 1.0);
  if (fRenderer <> nil) and (fRenderer.CurrentSceneObject <> nil) then
    fRenderer.CurrentSceneObject.ApplyVertexWindUniforms(Shader)
  else
    Shader.SetUniform('useVertexWind', GLint(0));
end;

procedure TSandBoxForm.GizmoMeshRenderHandler(Mesh: TMesh; Shader: TShader);
var
  IsHovered: Boolean;
  IsSelected: Boolean;
begin
  if (Mesh = nil) or (Shader = nil) then
    Exit;

  IsHovered := (fHoveredAxis <> -1) and (Mesh.Tag = fHoveredAxis);
  IsSelected := fDraggingGizmo and (fDraggedAxis <> -1) and (Mesh.Tag = fDraggedAxis);

  Shader.SetUniform('modelMatrix', Mesh.ModelMatrix);
  Shader.SetUniform('activeColor', Mesh.Tag);

  { These uniforms are ignored by older gizmo shaders, but the updated
    Gizmo.frag uses them to make the hovered/dragged axis obvious. }
  Shader.SetUniform('gizmoHoverColor', 1.0, 1.0, 0.0, 1.0);
  Shader.SetUniform('gizmoSelectedColor', 1.0, 0.55, 0.05, 1.0);

  if IsHovered then
    Shader.SetUniform('hoverFactor', 1.0)
  else
    Shader.SetUniform('hoverFactor', 0.0);

  if IsSelected then
    Shader.SetUniform('selectedFactor', 1.0)
  else
    Shader.SetUniform('selectedFactor', 0.0);
end;

procedure TSandBoxForm.ApplyImGuiStyle;
var
  Style: PImGuiStyle;
begin
  Style := ImGui.GetStyle;

  Style^.Alpha := 1.0;

  SetImGuiColorU8(ImGuiCol_WindowBg, 15, 15, 15, 150);

  // Border fully opaque.
  SetImGuiColorU8(ImGuiCol_Border, 110, 110, 128, 15);

  SetImGuiColorU8(ImGuiCol_ChildBg, 15, 15, 15, 160);
  SetImGuiColorU8(ImGuiCol_PopupBg, 15, 15, 15, 230);

  SetImGuiColorU8(ImGuiCol_TitleBg, 10, 10, 10, 255);
  SetImGuiColorU8(ImGuiCol_TitleBgActive, 10, 10, 10, 255);
  SetImGuiColorU8(ImGuiCol_TitleBgCollapsed, 10, 10, 10, 255);

  Style^.WindowBorderSize := 2.0;
  Style^.FrameBorderSize := 1.0;
  Style^.FramePadding := ImVec2.New(1.0, 1.0);
  Style^.ItemSpacing := ImVec2.New(3.0, 3.0);
  Style^.IndentSpacing := 22.0;
  Style^.ScrollbarSize := 12.0;
  Style^.SeparatorTextBorderSize := 1.0;
end;

procedure TSandBoxForm.RenderImGuiEditor(Sender: TObject);
begin
  if (not fUseImGuiEditor) or (fImGui = nil) then
    Exit;

  // Draw scene overlay gizmo after the 3D scene but before ImGui.
  RenderGizmoOverlay;

  fInImGuiFrame := True;
  try
    fImGui.NewFrame(EditorViewportWidth, EditorViewportHeight);
    DrawImGuiEditor;
    UpdateImGuiCaptureState;
    fImGui.Render;
  finally
    fInImGuiFrame := False;
  end;
end;

procedure TSandBoxForm.DrawImGuiEditor;
begin
  DrawImGuiToolbar;
  DrawImGuiViewportToolbar;
  DrawImGuiSceneTree;
  DrawViewportObjectContextPopup;
  DrawImGuiInspector;
  DrawImGuiPostEffects;
  DrawImGuiSkyDome;
  DrawImGuiRenderTextureTool;
  DrawImGuiPhysics;
  DrawImGuiAudioTest;
  DrawImGuiScriptEditor;
  DrawImGuiParticleEditor;
  DrawImGuiLog;
  DrawImGuiMaterialEditor;
  DrawImGuiMeshEditor;
  DrawImGuiHeightFieldBrowser;
  DrawImGuiTextureBrowser;
  DrawImGuiParticleTextureBrowser;
  DrawImGuiBillboardTextureBrowser;
  DrawImGuiMaterialFileBrowser;
  DrawImGuiModelFileBrowser;
  DrawImGuiSceneFileBrowser;
  DrawImGuiPrefabFileBrowser;
  DrawImGuiParticleFileBrowser;

  if fShowImGuiDemo then
    ImGui.ShowDemoWindow(@fShowImGuiDemo);
end;

procedure TSandBoxForm.DrawImGuiToolbar;
var
  ToolbarWidth: Single;
  CanEditSelectedObject: Boolean;
  HasSelectedBillboard: Boolean;
  HasSelectedAnimatedSprite: Boolean;
begin
  CanEditSelectedObject := not IsProtectedSceneObject(fSelectedObject);
  HasSelectedBillboard := False;
  HasSelectedAnimatedSprite := False;
  if CanEditSelectedObject then
  begin
    HasSelectedBillboard := fSelectedObject.BillboardCount > 0;
    HasSelectedAnimatedSprite := fSelectedObject.AnimatedSpriteCount > 0;
  end;

  ToolbarWidth := System.Math.Min(520.0, System.Math.Max(360.0,
    EditorViewportWidth - 32.0));
  ImGui.SetNextWindowPos(ImVec2.New((EditorViewportWidth - ToolbarWidth) * 0.5,
    8), ImGuiCond_Always);
  ImGui.SetNextWindowSize(ImVec2.New(ToolbarWidth, 48), ImGuiCond_Always);

  if ImGui.Begin_('Toolbar', nil, ImGuiWindowFlags_MenuBar or
    ImGuiWindowFlags_NoMove or ImGuiWindowFlags_NoResize or
    ImGuiWindowFlags_NoCollapse or ImGuiWindowFlags_NoSavedSettings) then
  begin
    if ImGui.BeginMenuBar then
    begin
      if ImGui.BeginMenu('Scene') then
      begin
        if ImGui.MenuItem('New') then
        begin
          CreateDefaultScene;
          LogLine('New scene created.');
        end;

        if ImGui.MenuItem('Save') then
          OpenSceneFileBrowser(sfbSaveScene);

        if ImGui.MenuItem('Load') then
          OpenSceneFileBrowser(sfbLoadScene);

        ImGui.EndMenu;
      end;

      if ImGui.BeginMenu('Object') then
      begin
        if ImGui.BeginMenu('Create Object') then
        begin
          DrawAddObjectMenuItems;
          ImGui.EndMenu;
        end;

        if ImGui.BeginMenu('Create Mesh',
          (fSelectedObject <> nil) and (not fSelectedObject.IsInstance)) then
        begin
          DrawAddMeshMenuItems;
          ImGui.EndMenu;
        end;

        ImGui.Separator;

        if ImGui.MenuItem('Cut', nil, False,
          not IsProtectedSceneObject(fSelectedObject)) then
          CutSelectedObjectToClipboard;

        if ImGui.MenuItem('Copy', nil, False,
          not IsProtectedSceneObject(fSelectedObject)) then
          CopySelectedObjectToClipboard;

        if ImGui.MenuItem('Paste as Child', nil, False,
          fObjectClipboard <> nil) then
          PasteObjectFromClipboard;

        if ImGui.MenuItem('Create Instance', nil, False,
          (not IsProtectedSceneObject(fSelectedObject)) and fSelectedObject.HasGeometry) then
          CreateInstanceFromSelectedObject;

        ImGui.Separator;

        if ImGui.MenuItem('Save Selected as Prefab...', nil, False,
          not IsProtectedSceneObject(fSelectedObject)) then
          OpenPrefabFileBrowser(prefabSave);

        if ImGui.MenuItem('Load Prefab...') then
          OpenPrefabFileBrowser(prefabLoad);

        ImGui.Separator;

        if ImGui.MenuItem('Add Billboard', nil, False,
          CanEditSelectedObject) then
        begin
          fSelectedObject.AddBillboard;
          SelectBillboardIndex(fSelectedObject.BillboardCount - 1);
          LogLine('Billboard created on object: ' + fSelectedObject.Name);
          NotifyInspectorObjectEdited;
        end;

        if ImGui.MenuItem('Browse Billboard Texture...', nil, False,
          CanEditSelectedObject) then
          OpenBillboardTextureBrowser;

        if ImGui.MenuItem('Remove Selected Billboard', nil, False,
          HasSelectedBillboard) then
          DeleteSelectedBillboard;

        ImGui.Separator;

        if ImGui.MenuItem('Add Animated Sprite', nil, False,
          CanEditSelectedObject) then
        begin
          fSelectedObject.AddAnimatedSprite;
          SelectAnimatedSpriteIndex(fSelectedObject.AnimatedSpriteCount - 1);
          LogLine('Animated sprite created on object: ' + fSelectedObject.Name);
          NotifyInspectorObjectEdited;
        end;

        if ImGui.MenuItem('Remove Selected Animated Sprite', nil, False,
          HasSelectedAnimatedSprite) then
          DeleteSelectedAnimatedSprite;

        ImGui.Separator;

        if ImGui.MenuItem('Delete Object', nil, False,
          not IsProtectedSceneObject(fSelectedObject)) then
          DeleteObjectFromImGui(fSelectedObject);

        ImGui.EndMenu;
      end;

      if ImGui.BeginMenu('Tools') then
      begin
        if ImGui.MenuItem('Material Editor', nil, fMaterialEditor.Active) then
        begin
          fMaterialEditor.Active := not fMaterialEditor.Active;
          if fMaterialEditor.Active then
          begin
            fTextureBrowser.LastError := '';
            fTextureBrowser.NeedsRefresh := True;
            SyncTextureAssetSelectionToCurrentTexture;
          end;
        end;

        if ImGui.MenuItem('Particle Editor', nil, fParticleEditorActive) then
          OpenParticleEditor;

        if ImGui.MenuItem('Post Effects', nil, fShowPostEffects) then
          fShowPostEffects := not fShowPostEffects;

        if ImGui.MenuItem('SkyDome', nil, fShowSkyDome) then
          fShowSkyDome := not fShowSkyDome;

        if ImGui.MenuItem('Render Texture', nil, fRenderTextureTool.Active) then
          fRenderTextureTool.Active := not fRenderTextureTool.Active;

        if ImGui.MenuItem('Physics', nil, fShowPhysics) then
          fShowPhysics := not fShowPhysics;

        if ImGui.MenuItem('Audio Test', nil, fShowAudioTest) then
          fShowAudioTest := not fShowAudioTest;

        if ImGui.MenuItem('Script Editor', nil, fShowScriptEditor) then
          fShowScriptEditor := not fShowScriptEditor;

        ImGui.Separator;

        if ImGui.MenuItem('Dear ImGui Demo', nil, fShowImGuiDemo) then
          fShowImGuiDemo := not fShowImGuiDemo;

        ImGui.EndMenu;
      end;

      ImGui.EndMenuBar;
    end;
  end;

  ImGui.End_;
end;

procedure TSandBoxForm.DrawImGuiViewportToolbar;
var
  SceneWireframe: Boolean;
  GridEnabled: Boolean;
  ModeValue: Integer;
begin
  ImGui.SetNextWindowPos(ImVec2.New(8, 8), ImGuiCond_Always);

  if ImGui.Begin_('Viewport Tools##LockedToolbar', nil,
    ImGuiWindowFlags_NoTitleBar or ImGuiWindowFlags_NoResize or
    ImGuiWindowFlags_NoMove or ImGuiWindowFlags_NoCollapse or
    ImGuiWindowFlags_NoSavedSettings or ImGuiWindowFlags_AlwaysAutoResize) then
  begin
    ModeValue := Ord(fGizmoMode);
    if ImGui.RadioButton('Move##ViewportTool', @ModeValue, Ord(gmTranslate)) then
      SetGizmoModeFromToolbar(gmTranslate);
    ImGui.SameLine;
    if ImGui.RadioButton('Rotate##ViewportTool', @ModeValue, Ord(gmRotate)) then
      SetGizmoModeFromToolbar(gmRotate);
    ImGui.SameLine;
    if ImGui.RadioButton('Scale##ViewportTool', @ModeValue, Ord(gmScale)) then
      SetGizmoModeFromToolbar(gmScale);

    if Assigned(fSceneManager) then
    begin
      ImGui.SameLine;
      SceneWireframe := fSceneManager.WireFrame;
      if ImGui.Checkbox('Scene wireframe##ViewportTool', @SceneWireframe) then
      begin
        fSceneManager.WireFrame := SceneWireframe;
        RequestRender;
      end;

      if Assigned(fGrid) then
      begin
        ImGui.SameLine;
        GridEnabled := fGrid.Enabled;
        if ImGui.Checkbox('Grid##ViewportTool', @GridEnabled) then
        begin
          fGrid.Enabled := GridEnabled;
          RequestRender;
        end;
      end;
    end;
  end;

  ImGui.End_;
end;

procedure TSandBoxForm.DrawImGuiSceneTree;
var
  I: Integer;
begin
  ImGui.SetNextWindowPos(ImVec2.New(8, 58), ImGuiCond_FirstUseEver);
  ImGui.SetNextWindowSize(ImVec2.New(280, 520), ImGuiCond_FirstUseEver);

  if ImGui.Begin_('Scene', nil) then
  begin
    if ImGui.Button('+ Object') then
      ImGui.OpenPopup('AddObjectPopup');

    ImGui.Separator();

    if ImGui.BeginPopup('AddObjectPopup') then
    begin
      DrawAddObjectMenuItems;
      ImGui.EndPopup;
    end;

    if Assigned(fRoot) then
      for I := 0 to fRoot.Count - 1 do
        DrawImGuiSceneObjectNode(fRoot.ObjectList[I]);
  end;

  ImGui.End_;
end;

function TSandBoxForm.DrawSceneObjectContextMenu(Obj: TSceneObject): Boolean;
begin
  Result := False;

  if Obj = nil then
    Exit;

  SelectObjectFromImGui(Obj);
  ImGui.Text(PAnsiChar(AnsiString(Obj.Name)));
  ImGui.Separator;

  if ImGui.BeginMenu('Create Object', CanUseSceneObjectAsParent(Obj)) then
  begin
    DrawAddObjectMenuItems;
    ImGui.EndMenu;
  end;

  ImGui.Separator;

  if ImGui.MenuItem('Cut', nil, False, not IsProtectedSceneObject(Obj)) then
  begin
    if fViewportObjectPopupObject = Obj then
      fViewportObjectPopupObject := nil;
    CutSelectedObjectToClipboard;
    Result := True;
    Exit;
  end;

  if ImGui.MenuItem('Copy', nil, False, not IsProtectedSceneObject(Obj)) then
    CopySelectedObjectToClipboard;

  if ImGui.MenuItem('Paste as Child', nil, False,
    (fObjectClipboard <> nil) and CanUseSceneObjectAsParent(Obj)) then
    PasteObjectFromClipboard;

  if ImGui.MenuItem('Create Instance', nil, False,
    (not IsProtectedSceneObject(Obj)) and Obj.HasGeometry) then
    CreateInstanceFromSelectedObject;

  ImGui.Separator;

  if ImGui.MenuItem('Save as Prefab...', nil, False,
    not IsProtectedSceneObject(Obj)) then
    OpenPrefabFileBrowser(prefabSave);

  if ImGui.MenuItem('Load Prefab as Child...', nil, False,
    CanUseSceneObjectAsParent(Obj)) then
    OpenPrefabFileBrowser(prefabLoad);

  ImGui.Separator;

  if ImGui.MenuItem('Delete', nil, False, not IsProtectedSceneObject(Obj)) then
  begin
    if fViewportObjectPopupObject = Obj then
      fViewportObjectPopupObject := nil;
    DeleteObjectFromImGui(Obj);
    Result := True;
    Exit;
  end;
end;

procedure TSandBoxForm.DrawViewportObjectContextPopup;
var
  Obj: TSceneObject;
  PopupName: AnsiString;
begin
  PopupName := AnsiString(VIEWPORT_CONTEXT_POPUP_NAME);

  if fViewportObjectPopupPending then
  begin
    ImGui.SetNextWindowPos(ImVec2.New(fViewportObjectPopupPos.X,
      fViewportObjectPopupPos.Y), ImGuiCond_Always);
    ImGui.OpenPopup(PAnsiChar(PopupName));
    fViewportObjectPopupPending := False;
  end;

  Obj := fViewportObjectPopupObject;
  if ImGui.BeginPopup(PAnsiChar(PopupName)) then
  begin
    DrawSceneObjectContextMenu(Obj);
    ImGui.EndPopup;
  end
  else if not fViewportObjectPopupPending then
    fViewportObjectPopupObject := nil;
end;

procedure TSandBoxForm.DrawImGuiSceneObjectNode(Obj: TSceneObject);
type
  PSceneObjectDragPayload = ^TSceneObject;
var
  Flags: ImGuiTreeNodeFlags;
  Opened: Boolean;
  I: Integer;
  DraggedObj: TSceneObject;
  Payload: PImGuiPayload;
begin
  if Obj = nil then
    Exit;

  if Obj.IsGizmo then
    Exit;

  Flags := ImGuiTreeNodeFlags_OpenOnArrow or ImGuiTreeNodeFlags_SpanAvailWidth;

  if Obj = fSelectedObject then
    Flags := Flags or ImGuiTreeNodeFlags_Selected;

  if Obj.Count = 0 then
    Flags := Flags or ImGuiTreeNodeFlags_Leaf;

  if (Obj = fSelectedObject) or
     (Assigned(fSelectedObject) and fSelectedObject.IsDescendantOf(Obj)) then
    ImGui.SetNextTreeNodeOpen(True, ImGuiCond_Always);

  Opened := ImGui.TreeNodeEx(Pointer(Obj), Flags, PAnsiChar(AnsiString(Obj.Name)));

  if ImGui.IsItemClicked(ImGuiMouseButton_Left) then
    SelectObjectFromImGui(Obj);

  if ImGui.IsItemHovered and ImGui.IsMouseDoubleClicked(ImGuiMouseButton_Left) then
  begin
    SelectObjectFromImGui(Obj);
    FocusCameraOnSceneObject(Obj);
  end;

  if ImGui.IsItemClicked(ImGuiMouseButton_Right) then
    SelectObjectFromImGui(Obj);

  if (not IsProtectedSceneObject(Obj)) and
     igBeginDragDropSource(ImGuiDragDropFlags_None) then
  begin
    DraggedObj := Obj;
    igSetDragDropPayload(PAnsiChar(AnsiString(SCENE_OBJECT_DND_PAYLOAD_LOCAL)),
      @DraggedObj, SizeOf(DraggedObj), ImGuiCond_Always);
    ImGui.Text(PAnsiChar(AnsiString('Move ' + Obj.Name)));
    igEndDragDropSource;
  end;

  if igBeginDragDropTarget then
  begin
    Payload := igAcceptDragDropPayload(
      PAnsiChar(AnsiString(SCENE_OBJECT_DND_PAYLOAD_LOCAL)),
      ImGuiDragDropFlags_None);
    if (Payload <> nil) and Payload^.Delivery and
       (Payload^.DataSize = SizeOf(DraggedObj)) then
    begin
      DraggedObj := PSceneObjectDragPayload(Payload^.Data)^;
      MoveSceneObjectToParent(DraggedObj, Obj);
    end;
    igEndDragDropTarget;
  end;

  if ImGui.BeginPopupContextItem(nil) then
  begin
    if DrawSceneObjectContextMenu(Obj) then
    begin
      ImGui.EndPopup;
      Exit;
    end;
    ImGui.EndPopup;
  end;

  if Opened then
  begin
    for I := 0 to Obj.Count - 1 do
      DrawImGuiSceneObjectNode(Obj.ObjectList[I]);
    ImGui.TreePop;
  end;
end;

procedure TSandBoxForm.NotifyInspectorObjectEdited;
var
  Body: TPhysicsBody;
begin
  if Assigned(fSelectedObject) then
    fSelectedObject.NotifyChange;

  if Assigned(fSceneManager) then
    fSceneManager.Update;

  if (not fPhysicsRunning) and Assigned(fPhysicsWorld) and Assigned(fSelectedObject) then
  begin
    Body := fPhysicsWorld.FindBody(fSelectedObject);
    if Body <> nil then
      fPhysicsWorld.ResetBodyToSceneTransform(Body, True);
  end;

  RefreshGizmo;
  RequestRender;
end;

procedure TSandBoxForm.NotifyInspectorMeshEdited(Mesh: TMesh; GeometryChanged: Boolean);
begin
  if Mesh = nil then
    Exit;

  if Assigned(fSelectedObject) then
  begin
    fSelectedObject.UpdateBoundingRadiusFromMesh;
    fSelectedObject.NotifyChange;
  end;

  if Assigned(fSceneManager) then
    fSceneManager.Update;

  if Assigned(fPhysicsWorld) and Assigned(fSelectedObject) then
  begin
    if GeometryChanged then
      fPhysicsWorld.MarkObjectDirty(fSelectedObject, False)
    else if not fPhysicsRunning then
      fPhysicsWorld.ResetBodyToSceneTransform(fPhysicsWorld.FindBody(fSelectedObject), True);
  end;

  RefreshGizmo;
  RequestRender;
end;

type
  TInspectorFloat3Values = array[0..2] of Single;
  PInspectorFloat3Values = ^TInspectorFloat3Values;

function ClampInspectorFloat(Value, MinValue, MaxValue: Single): Single;
begin
  Result := Value;
  if Result < MinValue then
    Result := MinValue
  else if Result > MaxValue then
    Result := MaxValue;
end;

function ClampInspectorInt(Value, MinValue, MaxValue: Integer): Integer;
begin
  Result := Value;
  if Result < MinValue then
    Result := MinValue
  else if Result > MaxValue then
    Result := MaxValue;
end;

function InspectorInputFloat(const LabelText: PAnsiChar; Value: System.PSingle;
  Step, MinValue, MaxValue: Single; const FormatText: PAnsiChar): Boolean;
begin
  Result := ImGui.InputFloat(LabelText, Value, 0.0, 0.0, FormatText,
    ImGuiInputTextFlags_None);
  if Result and (MinValue < MaxValue) then
    Value^ := ClampInspectorFloat(Value^, MinValue, MaxValue);
end;

function InspectorInputFloat3(const LabelText: PAnsiChar; Value: System.PSingle;
  Step, MinValue, MaxValue: Single; const FormatText: PAnsiChar): Boolean;
var
  I: Integer;
  Values: PInspectorFloat3Values;
begin
  Result := ImGui.InputFloat3(LabelText, Value, FormatText,
    ImGuiInputTextFlags_None);
  if Result and (MinValue < MaxValue) then
  begin
    Values := PInspectorFloat3Values(Value);
    for I := 0 to 2 do
      Values^[I] := ClampInspectorFloat(Values^[I], MinValue, MaxValue);
  end;
end;

function InspectorInputInt(const LabelText: PAnsiChar; Value: System.PInteger;
  Step: Single; MinValue, MaxValue: Integer; const FormatText: PAnsiChar;
  Flags: ImGuiSliderFlags): Boolean;
begin
  Result := ImGui.InputInt(LabelText, Value, 0, 0, ImGuiInputTextFlags_None);
  if Result and (MinValue < MaxValue) then
    Value^ := ClampInspectorInt(Value^, MinValue, MaxValue);
end;

procedure TSandBoxForm.DrawImGuiObjectProperties;
var
  NameBuf: array[0..127] of AnsiChar;
  Wireframe: Boolean;
  IsInstance: Boolean;
  Meshes: TMeshList;
  PreviousMeshIndex: Integer;
begin
  if fSelectedObject = nil then
    Exit;

  ImGui.PushId(Pointer(fSelectedObject));
  try
    if ImGui.CollapsingHeader('Object Properties', ImGuiTreeNodeFlags_DefaultOpen) then
    begin
    ImGui.PushItemWidth(IMGUI_PROP_TEXT_WIDTH);
    SetAnsiBuffer(NameBuf, fSelectedObject.Name);
    if ImGui.InputText('Name', @NameBuf[0], SizeOf(NameBuf)) then
    begin
      fSelectedObject.Name := AnsiBufferText(NameBuf);
      NotifyInspectorObjectEdited;
    end;
    ImGui.PopItemWidth;

    ImGui.Text(PAnsiChar(AnsiString('Class: ' + fSelectedObject.ClassName)));
    ImGui.Text(PAnsiChar(AnsiString(Format('Children: %d', [fSelectedObject.Count]))));
    Meshes := fSelectedObject.EffectiveMeshList;
    if Assigned(Meshes) then
      ImGui.Text(PAnsiChar(AnsiString(Format('Meshes: %d', [Meshes.Count]))))
    else
      ImGui.Text('Meshes: 0');
    ImGui.Text(PAnsiChar(AnsiString(Format('Lights: %d', [fSelectedObject.LightsCount]))));
    ImGui.Text(PAnsiChar(AnsiString(Format('Bounding radius: %.3f', [fSelectedObject.BoundingRadius]))));

    Wireframe := fSelectedObject.WireFrame;
    if ImGui.Checkbox('Wireframe', @Wireframe) then
    begin
      fSelectedObject.WireFrame := Wireframe;
      NotifyInspectorObjectEdited;
    end;

    IsInstance := fSelectedObject.IsInstance;
    if ImGui.Checkbox('Is instance', @IsInstance) then
    begin
      if (not IsInstance) and fSelectedObject.IsInstance then
      begin
        PreviousMeshIndex := fSelectedMeshIndex;
        fSelectedObject.MakeUniqueFromInstance;
        if PreviousMeshIndex >= 0 then
          SelectMeshIndex(PreviousMeshIndex);
        if Assigned(fPhysicsWorld) then
          fPhysicsWorld.MarkObjectDirty(fSelectedObject, False);
        LogLine('Converted instance to a unique object: ' + fSelectedObject.Name);
      end
      else if IsInstance and (not fSelectedObject.IsInstance) then
        LogLine('Use Object > Create Instance to create a new instance from a source object.');
      NotifyInspectorObjectEdited;
    end;

    if fSelectedObject.IsInstance and Assigned(fSelectedObject.InstanceSource) then
      ImGui.Text(PAnsiChar(AnsiString('Instance source: ' +
        fSelectedObject.InstanceSource.Name)));

      ImGui.Text(PAnsiChar(AnsiString('Has camera: ' + BoolToStr(fSelectedObject.HasCamera, True))));
      ImGui.Text(PAnsiChar(AnsiString(Format('Particle systems: %d',
        [fSelectedObject.ParticleSystemCount]))));
      ImGui.Text(PAnsiChar(AnsiString(Format('Billboards: %d',
        [fSelectedObject.BillboardCount]))));
      ImGui.Text(PAnsiChar(AnsiString(Format('Animated sprites: %d',
        [fSelectedObject.AnimatedSpriteCount]))));
      ImGui.Text(PAnsiChar(AnsiString(Format('Audio emitters: %d',
        [fSelectedObject.AudioEmitterCount]))));
      ImGui.Text(PAnsiChar(AnsiString('Audio listener: ' +
        BoolToStr(fSelectedObject.AudioListener, True))));
    end;
  finally
    ImGui.PopId;
  end;
end;

procedure TSandBoxForm.DrawImGuiAnimationProperties;
var
  Animator: TSkeletonAnimator;
  Clip: TSkeletonAnimationClip;
  I, CurrentIndex, PlayIndex: Integer;
  IsSelected, LoopValue, DuplicateName: Boolean;
  SpeedValue, TimeValue: Single;
  StateText, NewClipName: string;
  NameBuf: array[0..127] of AnsiChar;
begin
  if fSelectedObject = nil then
    Exit;

  Animator := fSelectedObject.AnimationController;
  if (Animator = nil) and (not fSelectedObject.HasGeometry) then
    Exit;
  if not ImGui.CollapsingHeader('Animation', ImGuiTreeNodeFlags_DefaultOpen) then
    Exit;

  if Animator = nil then
  begin
    ImGui.TextDisabled('No skeleton or animation clips in this model.');
    Exit;
  end;

  ImGui.PushId(Pointer(Animator));
  try
    ImGui.Text(PAnsiChar(AnsiString(Format('Bones: %d   Clips: %d',
      [Animator.Skeleton.BoneCount, Animator.AnimationCount]))));

    case Animator.State of
      apsPlaying: StateText := 'Playing';
      apsPaused: StateText := 'Paused';
    else
      StateText := 'Stopped';
    end;
    if Animator.IsBlending then
      StateText := StateText + ' (blending)';
    ImGui.Text(PAnsiChar(AnsiString('State: ' + StateText)));

    if ImGui.Button('Load Animation(s)##SkeletonAnimation') then
      OpenAnimationFileBrowser;

    CurrentIndex := Animator.AnimationIndexByName(Animator.CurrentAnimationName);
    if Animator.AnimationCount = 0 then
      ImGui.TextDisabled('This skeleton contains no animation clips.')
    else if ImGui.BeginListBox('##AnimationClips', ImVec2.New(-1, 90)) then
    begin
      for I := 0 to Animator.AnimationCount - 1 do
      begin
        Clip := Animator.Animations[I];
        if Clip = nil then
          Continue;
        IsSelected := I = CurrentIndex;
        if ImGui.Selectable(PAnsiChar(AnsiString(Clip.Name)), IsSelected) then
        begin
          if (CurrentIndex >= 0) and (I <> CurrentIndex) and
             (Animator.State <> apsStopped) then
            Animator.Play(I, Animator.Looping, fAnimationBlendDuration)
          else
            Animator.Play(I, Animator.Looping, 0.0);
          CurrentIndex := I;
          RequestRender;
        end;
      end;
      ImGui.EndListBox;
    end;

    if (CurrentIndex >= 0) and (CurrentIndex < Animator.AnimationCount) then
    begin
      Clip := Animator.Animations[CurrentIndex];
      if Clip <> nil then
      begin
        SetAnsiBuffer(NameBuf, Clip.Name);
        ImGui.PushItemWidth(-1);
        try
          if ImGui.InputText('Name##SkeletonAnimationClipName', @NameBuf[0],
            SizeOf(NameBuf)) then
          begin
            NewClipName := Trim(AnsiBufferText(NameBuf));
            if NewClipName <> '' then
            begin
              DuplicateName := False;
              for I := 0 to Animator.AnimationCount - 1 do
                if (I <> CurrentIndex) and Assigned(Animator.Animations[I]) and
                   SameText(Animator.Animations[I].Name, NewClipName) then
                begin
                  DuplicateName := True;
                  Break;
                end;

              if not DuplicateName then
              begin
                Clip.Name := NewClipName;
                RequestRender;
              end;
            end;
          end;
        finally
          ImGui.PopItemWidth;
        end;
      end;
    end;

    LoopValue := Animator.Looping;
    if ImGui.Checkbox('Loop##SkeletonAnimation', @LoopValue) then
      Animator.Looping := LoopValue;

    SpeedValue := Animator.Speed;
    ImGui.PushItemWidth(IMGUI_PROP_SCALAR_WIDTH);
    if InspectorInputFloat('Speed##SkeletonAnimation', @SpeedValue, 0.05,
      -100.0, 100.0, '%.2f') then
      Animator.Speed := SpeedValue;
    if InspectorInputFloat('Blend time##SkeletonAnimation',
      @fAnimationBlendDuration, 0.05, 0.0, 60.0, '%.2f s') then
      fAnimationBlendDuration := Max(0.0, fAnimationBlendDuration);
    ImGui.PopItemWidth;

    if ImGui.Button('Play##SkeletonAnimation') then
    begin
      PlayIndex := CurrentIndex;
      if PlayIndex < 0 then
        PlayIndex := 0;
      Animator.Play(PlayIndex, Animator.Looping, 0.0);
      RequestRender;
    end;
    ImGui.SameLine;
    if Animator.State = apsPaused then
    begin
      if ImGui.Button('Resume##SkeletonAnimation') then
        Animator.Resume;
    end
    else if ImGui.Button('Pause##SkeletonAnimation') then
      Animator.Pause;
    ImGui.SameLine;
    if ImGui.Button('Stop##SkeletonAnimation') then
    begin
      Animator.Stop(False);
      RequestRender;
    end;
    ImGui.SameLine;
    if ImGui.Button('Bind Pose##SkeletonAnimation') then
    begin
      Animator.Stop(True);
      RequestRender;
    end;

    if Animator.Duration > 0.0 then
    begin
      TimeValue := Animator.CurrentTime;
      if ImGui.SliderFloat('Time##SkeletonAnimation', @TimeValue, 0.0,
        Animator.Duration, '%.2f s', ImGuiSliderFlags_None) then
      begin
        Animator.Seek(TimeValue);
        RequestRender;
      end;
    end;
  finally
    ImGui.PopId;
  end;
end;

procedure TSandBoxForm.DrawImGuiWindProperties;
var
  Animator: TSkeletonAnimator;
  Wind: TWindActorSettings;
  Enabled: Boolean;
  ModeValue: Integer;
  FloatValue: Single;
  DirectionValue: array[0..2] of Single;

  procedure CommitWindSettings;
  begin
    fSelectedObject.WindSettings := Wind;
    NotifyInspectorObjectEdited;
    RequestRender;
  end;

begin
  if fSelectedObject = nil then
    Exit;

  Animator := fSelectedObject.AnimationController;
  if (not fSelectedObject.HasGeometry) and (Animator = nil) and
     (not fSelectedObject.HasWindAnimation) then
    Exit;
  if not ImGui.CollapsingHeader('Wind', ImGuiTreeNodeFlags_DefaultOpen) then
    Exit;

  Wind := fSelectedObject.WindSettings;
  Enabled := Wind.Enabled;
  if ImGui.Checkbox('Enabled##Wind', @Enabled) then
  begin
    if Enabled then
    begin
      if not Wind.Enabled then
        Wind := TWindActorSettings.DefaultVertexTree;
    end;

    Wind.Enabled := Enabled;
    if not Enabled then
      Wind.Kind := wakNone;
    CommitWindSettings;
  end;

  if not Wind.Enabled then
    Exit;

  ModeValue := Ord(Wind.Kind);
  if ImGui.RadioButton('Vertex shader##WindMode', @ModeValue,
    Ord(wakVertexTree)) then
  begin
    Wind.Kind := wakVertexTree;
    CommitWindSettings;
  end;
  ImGui.SameLine;
  if ImGui.RadioButton('Bones##WindMode', @ModeValue, Ord(wakTree)) then
  begin
    if (Animator = nil) or (Animator.Skeleton = nil) or
       (Animator.Skeleton.BoneCount = 0) then
    begin
      LogLine('Bone wind requires a skinned object with bones.');
      ModeValue := Ord(wakVertexTree);
    end
    else
    begin
      Wind.Kind := wakTree;
      CommitWindSettings;
    end;
  end;

  if (Wind.Kind = wakTree) and (Animator <> nil) and
     (Animator.Skeleton <> nil) then
    ImGui.Text(PAnsiChar(AnsiString(Format('Bones: %d',
      [Animator.Skeleton.BoneCount]))));

  DirectionValue[0] := Wind.Direction.X;
  DirectionValue[1] := Wind.Direction.Y;
  DirectionValue[2] := Wind.Direction.Z;
  ImGui.PushItemWidth(IMGUI_PROP_TEXT_WIDTH);
  try
    if InspectorInputFloat3('Direction##Wind', @DirectionValue[0], 0.0,
      -1.0, 1.0, '%.2f') then
    begin
      Wind.Direction := Vector3(DirectionValue[0], DirectionValue[1],
        DirectionValue[2]);
      CommitWindSettings;
    end;
  finally
    ImGui.PopItemWidth;
  end;

  ImGui.PushItemWidth(IMGUI_PROP_SCALAR_WIDTH);
  try
    FloatValue := Wind.Strength * 180.0 / Pi;
    if InspectorInputFloat('Strength##Wind', @FloatValue, 0.25,
      0.0, 45.0, '%.2f deg') then
    begin
      Wind.Strength := FloatValue * Pi / 180.0;
      CommitWindSettings;
    end;

    FloatValue := Wind.Frequency;
    if InspectorInputFloat('Frequency##Wind', @FloatValue, 0.05,
      0.0, 20.0, '%.2f Hz') then
    begin
      Wind.Frequency := FloatValue;
      CommitWindSettings;
    end;

    FloatValue := Wind.GustStrength;
    if InspectorInputFloat('Gust strength##Wind', @FloatValue, 0.05,
      0.0, 4.0, '%.2f') then
    begin
      Wind.GustStrength := FloatValue;
      CommitWindSettings;
    end;

    FloatValue := Wind.GustFrequency;
    if InspectorInputFloat('Gust frequency##Wind', @FloatValue, 0.02,
      0.0, 5.0, '%.2f Hz') then
    begin
      Wind.GustFrequency := FloatValue;
      CommitWindSettings;
    end;

    FloatValue := Wind.PhaseOffset * 180.0 / Pi;
    if InspectorInputFloat('Phase##Wind', @FloatValue, 1.0,
      -360.0, 360.0, '%.1f deg') then
    begin
      Wind.PhaseOffset := FloatValue * Pi / 180.0;
      CommitWindSettings;
    end;

    FloatValue := Wind.TrunkFlex;
    if InspectorInputFloat('Trunk flex##Wind', @FloatValue, 0.05,
      0.0, 4.0, '%.2f') then
    begin
      Wind.TrunkFlex := FloatValue;
      CommitWindSettings;
    end;

    FloatValue := Wind.BranchFlex;
    if InspectorInputFloat('Branch flex##Wind', @FloatValue, 0.05,
      0.0, 4.0, '%.2f') then
    begin
      Wind.BranchFlex := FloatValue;
      CommitWindSettings;
    end;

    FloatValue := Wind.LeafFlutter;
    if InspectorInputFloat('Leaf flutter##Wind', @FloatValue, 0.05,
      0.0, 8.0, '%.2f') then
    begin
      Wind.LeafFlutter := FloatValue;
      CommitWindSettings;
    end;
  finally
    ImGui.PopItemWidth;
  end;
end;

procedure TSandBoxForm.DrawImGuiLightProperties;
var
  Light: TLight;
  I: Integer;
  TypeValue: Integer;
  BoolValue: Boolean;
  FloatValue: Single;
  ColorValue: array[0..2] of Single;
  VectorValue: array[0..2] of Single;
  NameBuf: array[0..127] of AnsiChar;
  Changed: Boolean;

  function LightTypeName(ALightType: TLightType): string;
  begin
    case ALightType of
      ltDirectional: Result := 'Directional';
      ltPoint: Result := 'Point';
      ltSpot: Result := 'Spot';
    else
      Result := 'Light';
    end;
  end;

  procedure MarkLightEdited;
  begin
    EnsureLightBillboard(fSelectedObject);
    NotifyInspectorObjectEdited;
  end;

begin
  if fSelectedObject = nil then
    Exit;

  if not ImGui.CollapsingHeader('Light', ImGuiTreeNodeFlags_DefaultOpen) then
    Exit;

  ImGui.PushId(Pointer(fSelectedObject));
  try
    if fSelectedObject.LightsCount = 0 then
    begin
      if ImGui.Button('+ Light') then
      begin
        Light := fSelectedObject.CreateLight;
        ConfigureLightDefaults(Light, ltPoint);
        EnsureLightBillboard(fSelectedObject);
        if fLight = nil then
          fLight := fSelectedObject;
        if Assigned(fRenderer) and (fRenderer.ShadowLight = nil) then
          fRenderer.ShadowLight := fLight;
        LogLine('Light component created on object: ' + fSelectedObject.Name);
        MarkLightEdited;
      end
      else
        ImGui.TextDisabled('No light on this object.');
      Exit;
    end;

    for I := 0 to fSelectedObject.LightsCount - 1 do
    begin
      Light := fSelectedObject.Light[I];
      if Light = nil then
        Continue;

      ImGui.PushId(I);
      try
        if fSelectedObject.LightsCount > 1 then
        begin
          if not ImGui.TreeNodeEx(PAnsiChar(AnsiString(LightTypeName(Light.LightType) +
            '##LightNode' + IntToStr(I))), ImGuiTreeNodeFlags_DefaultOpen) then
            Continue;
        end;

        SetAnsiBuffer(NameBuf, Light.Name);
        ImGui.PushItemWidth(IMGUI_PROP_TEXT_WIDTH);
        if ImGui.InputText('Name##LightName', @NameBuf[0], SizeOf(NameBuf)) then
        begin
          Light.Name := Trim(AnsiBufferText(NameBuf));
          if Light.Name = '' then
            Light.Name := LightTypeName(Light.LightType) + ' Light';
          MarkLightEdited;
        end;
        ImGui.PopItemWidth;

        BoolValue := Light.Enabled;
        if ImGui.Checkbox('Enabled##Light', @BoolValue) then
        begin
          Light.Enabled := BoolValue;
          MarkLightEdited;
        end;

        TypeValue := Ord(Light.LightType);
        Changed := False;
        Changed := ImGui.RadioButton('Directional##LightType', @TypeValue,
          Ord(ltDirectional)) or Changed;
        ImGui.SameLine;
        Changed := ImGui.RadioButton('Point##LightType', @TypeValue,
          Ord(ltPoint)) or Changed;
        ImGui.SameLine;
        Changed := ImGui.RadioButton('Spot##LightType', @TypeValue,
          Ord(ltSpot)) or Changed;
        if Changed then
        begin
          Light.LightType := TLightType(System.Math.EnsureRange(TypeValue,
            Ord(Low(TLightType)), Ord(High(TLightType))));
          if Light.LightType = ltPoint then
            Light.UseTarget := False
          else if Light.LightType in [ltDirectional, ltSpot] then
            Light.UseTarget := True;
          MarkLightEdited;
        end;

        ColorValue[0] := Light.Diffuse.X;
        ColorValue[1] := Light.Diffuse.Y;
        ColorValue[2] := Light.Diffuse.Z;
        if ImGui.ColorEdit3('Diffuse##Light', @ColorValue[0]) then
        begin
          Light.Diffuse := Vector3(ColorValue[0], ColorValue[1], ColorValue[2]);
          MarkLightEdited;
        end;

        ColorValue[0] := Light.Ambient.X;
        ColorValue[1] := Light.Ambient.Y;
        ColorValue[2] := Light.Ambient.Z;
        if ImGui.ColorEdit3('Ambient##Light', @ColorValue[0]) then
        begin
          Light.Ambient := Vector3(ColorValue[0], ColorValue[1], ColorValue[2]);
          MarkLightEdited;
        end;

        ColorValue[0] := Light.Specular.X;
        ColorValue[1] := Light.Specular.Y;
        ColorValue[2] := Light.Specular.Z;
        if ImGui.ColorEdit3('Specular##Light', @ColorValue[0]) then
        begin
          Light.Specular := Vector3(ColorValue[0], ColorValue[1], ColorValue[2]);
          MarkLightEdited;
        end;

        if Light.LightType in [ltPoint, ltSpot] then
        begin
          ImGui.PushItemWidth(IMGUI_PROP_SCALAR_WIDTH);
          FloatValue := Light.ConstantAttenuation;
          if InspectorInputFloat('Constant attenuation##Light', @FloatValue,
            0.01, 0.0, 100000, '%.3f') then
          begin
            Light.ConstantAttenuation := FloatValue;
            MarkLightEdited;
          end;

          FloatValue := Light.LinearAttenuation;
          if InspectorInputFloat('Linear attenuation##Light', @FloatValue,
            0.01, 0.0, 100000, '%.3f') then
          begin
            Light.LinearAttenuation := FloatValue;
            MarkLightEdited;
          end;

          FloatValue := Light.QuadraticAttenuation;
          if InspectorInputFloat('Quadratic attenuation##Light', @FloatValue,
            0.01, 0.0, 100000, '%.3f') then
          begin
            Light.QuadraticAttenuation := FloatValue;
            MarkLightEdited;
          end;
          ImGui.PopItemWidth;
        end;

        if Light.LightType in [ltDirectional, ltSpot] then
        begin
          BoolValue := Light.UseTarget;
          if ImGui.Checkbox('Use target##Light', @BoolValue) then
          begin
            Light.UseTarget := BoolValue;
            MarkLightEdited;
          end;

          VectorValue[0] := Light.TargetPosition.X;
          VectorValue[1] := Light.TargetPosition.Y;
          VectorValue[2] := Light.TargetPosition.Z;
          ImGui.PushItemWidth(IMGUI_PROP_VECTOR3_WIDTH);
          if InspectorInputFloat3('Target##Light', @VectorValue[0], 0.05,
            -100000, 100000, '%.2f') then
          begin
            Light.TargetPosition := Vector3(VectorValue[0], VectorValue[1],
              VectorValue[2]);
            MarkLightEdited;
          end;
          ImGui.PopItemWidth;
        end;

        if Light.LightType = ltSpot then
        begin
          ImGui.PushItemWidth(IMGUI_PROP_SCALAR_WIDTH);
          FloatValue := RadToDeg(Light.SpotCutoff);
          if InspectorInputFloat('Spot cutoff##Light', @FloatValue, 0.5,
            0.1, 179.0, '%.2f') then
          begin
            Light.SpotCutoff := DegToRad(FloatValue);
            MarkLightEdited;
          end;

          FloatValue := Light.SpotExponent;
          if InspectorInputFloat('Spot exponent##Light', @FloatValue, 0.05,
            0.0, 100000, '%.3f') then
          begin
            Light.SpotExponent := FloatValue;
            MarkLightEdited;
          end;
          ImGui.PopItemWidth;
        end;

        BoolValue := Light.CastShadows;
        if ImGui.Checkbox('Cast shadows##Light', @BoolValue) then
        begin
          Light.CastShadows := BoolValue;
          if BoolValue and Assigned(fRenderer) then
            fRenderer.ShadowLight := fSelectedObject;
          MarkLightEdited;
        end;

        FloatValue := Light.ShadowStrength;
        ImGui.PushItemWidth(IMGUI_PROP_SCALAR_WIDTH);
        if InspectorInputFloat('Shadow strength##Light', @FloatValue, 0.01,
          0.0, 1.0, '%.3f') then
        begin
          Light.ShadowStrength := FloatValue;
          MarkLightEdited;
        end;
        ImGui.PopItemWidth;

        if Assigned(fRenderer) then
        begin
          BoolValue := fRenderer.ShadowLight = fSelectedObject;
          if ImGui.Checkbox('Primary shadow light##Light', @BoolValue) then
          begin
            if BoolValue then
              fRenderer.ShadowLight := fSelectedObject
            else if fRenderer.ShadowLight = fSelectedObject then
              fRenderer.ShadowLight := FindFirstLightSceneObject(fRoot);
            RequestRender;
          end;
        end;

        if fSelectedObject.LightsCount > 1 then
          ImGui.TreePop;
      finally
        ImGui.PopId;
      end;
    end;
  finally
    ImGui.PopId;
  end;
end;

procedure TSandBoxForm.DrawImGuiBillboardProperties;
var
  Billboard: TBillboard;
  I: Integer;
  EnabledValue: Boolean;
  FloatValue: Single;
  VectorValue: array[0..2] of Single;
  ColorValue: array[0..3] of Single;
  BlendValue: Integer;
  NameBuf: array[0..127] of AnsiChar;
  TexturePathBuf: array[0..255] of AnsiChar;
  TextureFullPath: string;
  DisplayName: string;

  procedure MarkBillboardEdited;
  begin
    NotifyInspectorObjectEdited;
  end;

begin
  if fSelectedObject = nil then
    Exit;

  if not ImGui.CollapsingHeader('Billboard', ImGuiTreeNodeFlags_DefaultOpen) then
    Exit;

  ImGui.PushId(Pointer(fSelectedObject));
  try
    if ImGui.Button('+ Billboard') then
    begin
      fSelectedObject.AddBillboard;
      SelectBillboardIndex(fSelectedObject.BillboardCount - 1);
      LogLine('Billboard created on object: ' + fSelectedObject.Name);
      MarkBillboardEdited;
    end;

    if fSelectedObject.BillboardCount = 0 then
    begin
      ImGui.TextWrapped('This object does not have a billboard yet.');
      if ImGui.Button('Create With Texture...') then
      begin
        fSelectedObject.AddBillboard;
        SelectBillboardIndex(fSelectedObject.BillboardCount - 1);
        OpenBillboardTextureBrowser;
        MarkBillboardEdited;
      end;
      Exit;
    end;

    if (fSelectedBillboardIndex < 0) or
       (fSelectedBillboardIndex >= fSelectedObject.BillboardCount) then
      SelectBillboardIndex(0);

    if ImGui.BeginListBox('##BillboardList', ImVec2.New(-1, 100)) then
    begin
      for I := 0 to fSelectedObject.BillboardCount - 1 do
      begin
        Billboard := fSelectedObject.BillboardItem[I];
        if Billboard = nil then
          Continue;

        DisplayName := Trim(Billboard.Name);
        if DisplayName = '' then
          DisplayName := Format('Billboard %d', [I + 1]);

        if ImGui.Selectable(PAnsiChar(AnsiString(DisplayName)),
          I = fSelectedBillboardIndex) then
          SelectBillboardIndex(I);
      end;
      ImGui.EndListBox;
    end;

    Billboard := SelectedBillboard;
    if Billboard = nil then
      Exit;

    if ImGui.Button('Delete Billboard') then
    begin
      DeleteSelectedBillboard;
      Exit;
    end;

    ImGui.Text(PAnsiChar(AnsiString('Selected billboard: ' + Billboard.Name)));
    ImGui.PushId(Pointer(Billboard));
    try
    SetAnsiBuffer(NameBuf, Billboard.Name);
    ImGui.PushItemWidth(IMGUI_PROP_TEXT_WIDTH);
    if ImGui.InputText('Name##BillboardName', @NameBuf[0],
      SizeOf(NameBuf)) then
    begin
      Billboard.Name := Trim(AnsiBufferText(NameBuf));
      if Billboard.Name = '' then
        Billboard.Name := 'Billboard';
      MarkBillboardEdited;
    end;
    ImGui.PopItemWidth;

    EnabledValue := Billboard.Enabled;
    if ImGui.Checkbox('Enabled##Billboard', @EnabledValue) then
    begin
      Billboard.Enabled := EnabledValue;
      MarkBillboardEdited;
    end;

    FloatValue := Billboard.Width;
    if InspectorInputFloat('Width##Billboard', @FloatValue, 0.05, 0.001,
      100000.0, '%.3f') then
    begin
      Billboard.Width := FloatValue;
      MarkBillboardEdited;
    end;

    FloatValue := Billboard.Height;
    if InspectorInputFloat('Height##Billboard', @FloatValue, 0.05, 0.001,
      100000.0, '%.3f') then
    begin
      Billboard.Height := FloatValue;
      MarkBillboardEdited;
    end;

    VectorValue[0] := Billboard.Offset.X;
    VectorValue[1] := Billboard.Offset.Y;
    VectorValue[2] := Billboard.Offset.Z;
    if InspectorInputFloat3('Offset##Billboard', @VectorValue[0], 0.05,
      -100000.0, 100000.0, '%.3f') then
    begin
      Billboard.Offset := Vector3(VectorValue[0], VectorValue[1],
        VectorValue[2]);
      MarkBillboardEdited;
    end;

    FloatValue := RadToDeg(Billboard.Rotation);
    if InspectorInputFloat('Rotation##Billboard', @FloatValue, 1.0,
      -360000.0, 360000.0, '%.2f deg') then
    begin
      Billboard.Rotation := DegToRad(FloatValue);
      MarkBillboardEdited;
    end;

    ColorValue[0] := Billboard.Color.X;
    ColorValue[1] := Billboard.Color.Y;
    ColorValue[2] := Billboard.Color.Z;
    ColorValue[3] := Billboard.Color.W;
    if ImGui.ColorEdit4('Color##Billboard', @ColorValue[0]) then
    begin
      Billboard.Color := Vector4(ColorValue[0], ColorValue[1],
        ColorValue[2], ColorValue[3]);
      MarkBillboardEdited;
    end;

    ImGui.Text('Blend');
    BlendValue := Ord(Billboard.BlendMode);
    ImGui.RadioButton('Alpha##BillboardBlend', @BlendValue, Ord(bbAlpha));
    ImGui.SameLine;
    ImGui.RadioButton('Additive##BillboardBlend', @BlendValue, Ord(bbAdditive));
    if BlendValue <> Ord(Billboard.BlendMode) then
    begin
      Billboard.BlendMode := TBillboardBlendMode(EnsureRange(BlendValue,
        Ord(Low(TBillboardBlendMode)), Ord(High(TBillboardBlendMode))));
      MarkBillboardEdited;
    end;

    FloatValue := Billboard.AlphaCutoff;
    if InspectorInputFloat('Alpha cutoff##Billboard', @FloatValue, 0.005,
      0.0, 1.0, '%.3f') then
    begin
      Billboard.AlphaCutoff := FloatValue;
      MarkBillboardEdited;
    end;

    ImGui.Separator;
    ImGui.Text('Texture');
    SetAnsiBuffer(TexturePathBuf, Billboard.TexturePath);
    ImGui.PushItemWidth(-1);
    if ImGui.InputText('Asset path##BillboardTexture', @TexturePathBuf[0],
      SizeOf(TexturePathBuf)) then
    begin
      Billboard.TexturePath := Trim(AnsiBufferText(TexturePathBuf));
      MarkBillboardEdited;
    end;
    ImGui.PopItemWidth;

    TextureFullPath := ResolveBillboardTexturePreviewPath(Billboard.TexturePath);
    if Trim(Billboard.TexturePath) = '' then
      ImGui.TextWrapped('Pick a .tga or .png texture from the billboard texture library.')
    else
    begin
      ImGui.TextWrapped(AnsiString('Texture: ' +
        TextureFileDisplayName(Billboard.TexturePath)));
      if FileExists(TextureFullPath) then
        ImGui.TextWrapped(AnsiString(TextureFullPath))
      else
        ImGui.TextWrapped('Texture file is missing. Choose another asset or clear the path.');
    end;

    if ImGui.Button('Browse Texture...##Billboard') then
      OpenBillboardTextureBrowser;

    ImGui.SameLine;
    if ImGui.Button('Clear Texture##Billboard') then
    begin
      Billboard.TexturePath := '';
      MarkBillboardEdited;
    end;

    ImGui.Separator;
    if ImGui.Button('Remove Selected Billboard') then
      DeleteSelectedBillboard;
    finally
      ImGui.PopId;
    end;
  finally
    ImGui.PopId;
  end;
end;

procedure TSandBoxForm.DrawImGuiAnimatedSpriteProperties;
var
  AnimatedSprite: TAnimatedSprite;
  I: Integer;
  EnabledValue: Boolean;
  BoolValue: Boolean;
  FloatValue: Single;
  IntValue: Integer;
  VectorValue: array[0..2] of Single;
  ColorValue: array[0..3] of Single;
  BlendValue: Integer;
  NameBuf: array[0..127] of AnsiChar;
  TexturePathBuf: array[0..511] of AnsiChar;
  DisplayName: string;
  TexturePath: string;
  FullTexturePath: string;
  RootDir: string;
  Files: TArray<string>;
  TextureList: TStringList;
  FileName: string;
  RelativePath: string;
  GridCapacity: Integer;

  procedure MarkAnimatedSpriteEdited;
  begin
    NotifyInspectorObjectEdited;
  end;

begin
  if fSelectedObject = nil then
    Exit;

  if not ImGui.CollapsingHeader('Animated Sprite', ImGuiTreeNodeFlags_DefaultOpen) then
    Exit;

  ImGui.PushId(Pointer(fSelectedObject));
  try
    if ImGui.Button('+ Animated Sprite') then
    begin
      fSelectedObject.AddAnimatedSprite;
      SelectAnimatedSpriteIndex(fSelectedObject.AnimatedSpriteCount - 1);
      LogLine('Animated sprite created on object: ' + fSelectedObject.Name);
      MarkAnimatedSpriteEdited;
    end;

    if fSelectedObject.AnimatedSpriteCount = 0 then
    begin
      ImGui.TextWrapped('This object does not have an animated sprite yet.');
      Exit;
    end;

    if (fSelectedAnimatedSpriteIndex < 0) or
       (fSelectedAnimatedSpriteIndex >= fSelectedObject.AnimatedSpriteCount) then
      SelectAnimatedSpriteIndex(0);

    if ImGui.BeginListBox('##AnimatedSpriteList', ImVec2.New(-1, 90)) then
    begin
      for I := 0 to fSelectedObject.AnimatedSpriteCount - 1 do
      begin
        AnimatedSprite := fSelectedObject.AnimatedSpriteItem[I];
        if AnimatedSprite = nil then
          Continue;

        DisplayName := Trim(AnimatedSprite.Name);
        if DisplayName = '' then
          DisplayName := Format('Animated Sprite %d', [I + 1]);

        if ImGui.Selectable(PAnsiChar(AnsiString(DisplayName)),
          I = fSelectedAnimatedSpriteIndex) then
          SelectAnimatedSpriteIndex(I);
      end;
      ImGui.EndListBox;
    end;

    AnimatedSprite := SelectedAnimatedSprite;
    if AnimatedSprite = nil then
      Exit;

    if ImGui.Button('Delete Animated Sprite') then
    begin
      DeleteSelectedAnimatedSprite;
      Exit;
    end;

    ImGui.Text(PAnsiChar(AnsiString('Selected animated sprite: ' +
      AnimatedSprite.Name)));
    ImGui.PushId(Pointer(AnimatedSprite));
    try
      SetAnsiBuffer(NameBuf, AnimatedSprite.Name);
      ImGui.PushItemWidth(IMGUI_PROP_TEXT_WIDTH);
      if ImGui.InputText('Name##AnimatedSpriteName', @NameBuf[0],
        SizeOf(NameBuf)) then
      begin
        AnimatedSprite.Name := Trim(AnsiBufferText(NameBuf));
        if AnimatedSprite.Name = '' then
          AnimatedSprite.Name := 'AnimatedSprite';
        MarkAnimatedSpriteEdited;
      end;
      ImGui.PopItemWidth;

      EnabledValue := AnimatedSprite.Enabled;
      if ImGui.Checkbox('Enabled##AnimatedSprite', @EnabledValue) then
      begin
        AnimatedSprite.Enabled := EnabledValue;
        MarkAnimatedSpriteEdited;
      end;

      BoolValue := AnimatedSprite.Playing;
      if ImGui.Checkbox('Playing##AnimatedSprite', @BoolValue) then
      begin
        AnimatedSprite.Playing := BoolValue;
        MarkAnimatedSpriteEdited;
      end;
      ImGui.SameLine;
      if ImGui.Button('Restart##AnimatedSprite') then
      begin
        AnimatedSprite.Restart;
        MarkAnimatedSpriteEdited;
      end;

      BoolValue := AnimatedSprite.Loop;
      if ImGui.Checkbox('Loop##AnimatedSprite', @BoolValue) then
      begin
        AnimatedSprite.Loop := BoolValue;
        MarkAnimatedSpriteEdited;
      end;

      FloatValue := AnimatedSprite.FrameRate;
      if InspectorInputFloat('Frame rate##AnimatedSprite', @FloatValue, 0.25,
        0.001, 240.0, '%.3f fps') then
      begin
        AnimatedSprite.FrameRate := FloatValue;
        MarkAnimatedSpriteEdited;
      end;

      IntValue := AnimatedSprite.GridColumns;
      if InspectorInputInt('Columns##AnimatedSprite', @IntValue, 1.0,
        1, 1024, '%d', ImGuiSliderFlags_None) then
      begin
        AnimatedSprite.GridColumns := IntValue;
        MarkAnimatedSpriteEdited;
      end;

      IntValue := AnimatedSprite.GridRows;
      if InspectorInputInt('Rows##AnimatedSprite', @IntValue, 1.0,
        1, 1024, '%d', ImGuiSliderFlags_None) then
      begin
        AnimatedSprite.GridRows := IntValue;
        MarkAnimatedSpriteEdited;
      end;

      GridCapacity := AnimatedSprite.GridFrameCapacity;
      IntValue := AnimatedSprite.FirstFrame;
      if InspectorInputInt('First frame##AnimatedSprite', @IntValue, 1.0,
        0, Max(0, GridCapacity - 1), '%d', ImGuiSliderFlags_None) then
      begin
        AnimatedSprite.FirstFrame := IntValue;
        MarkAnimatedSpriteEdited;
      end;

      IntValue := AnimatedSprite.FrameCount;
      if InspectorInputInt('Frame count##AnimatedSprite', @IntValue, 1.0,
        1, Max(1, GridCapacity - AnimatedSprite.FirstFrame), '%d',
        ImGuiSliderFlags_None) then
      begin
        AnimatedSprite.FrameCount := IntValue;
        MarkAnimatedSpriteEdited;
      end;

      if AnimatedSprite.FrameCount > 0 then
      begin
        IntValue := AnimatedSprite.CurrentFrameIndex;
        if InspectorInputInt('Current frame##AnimatedSprite', @IntValue, 1.0,
          0, AnimatedSprite.FrameCount - 1, '%d', ImGuiSliderFlags_None) then
        begin
          AnimatedSprite.CurrentFrameIndex := IntValue;
          MarkAnimatedSpriteEdited;
        end;
      end;

      ImGui.Text(PAnsiChar(AnsiString(Format(
        'Sheet frame: %d / %d',
        [AnimatedSprite.CurrentSheetFrameIndex,
         Max(0, AnimatedSprite.GridFrameCapacity - 1)]))));

      ImGui.Separator;
      ImGui.Text('Sprite sheet');
      SetAnsiBuffer(TexturePathBuf, AnimatedSprite.TexturePath);
      ImGui.PushItemWidth(-1);
      if ImGui.InputText('Asset path##AnimatedSpriteTexture',
        @TexturePathBuf[0], SizeOf(TexturePathBuf)) then
      begin
        AnimatedSprite.TexturePath := Trim(AnsiBufferText(TexturePathBuf));
        MarkAnimatedSpriteEdited;
      end;
      ImGui.PopItemWidth;

      TexturePath := AnimatedSprite.TexturePath;
      FullTexturePath := TEnginePaths.ResolveAssetPath(TexturePath);
      if Trim(TexturePath) = '' then
        ImGui.TextWrapped('Pick a .tga or .png sprite sheet from the animated sprite assets.')
      else
      begin
        ImGui.TextWrapped(PAnsiChar(AnsiString('Texture: ' +
          TextureFileDisplayName(TexturePath))));
        if FileExists(FullTexturePath) then
          ImGui.TextWrapped(PAnsiChar(AnsiString(FullTexturePath)))
        else
          ImGui.TextWrapped('Sprite sheet file is missing.');
      end;

      if ImGui.Button('Clear Texture##AnimatedSprite') then
      begin
        AnimatedSprite.TexturePath := '';
        MarkAnimatedSpriteEdited;
      end;

      ImGui.TextWrapped(PAnsiChar(AnsiString('Sprite sheets: ' +
        TEnginePaths.AnimatedSpritesDir)));
      TextureList := TStringList.Create;
      try
        TextureList.CaseSensitive := False;
        TextureList.Sorted := True;
        TextureList.Duplicates := dupIgnore;

        TEnginePaths.EnsureDirectories;
        RootDir := IncludeTrailingPathDelimiter(
          ExpandFileName(TEnginePaths.AnimatedSpritesDir));
        if TDirectory.Exists(RootDir) then
        begin
          Files := TDirectory.GetFiles(RootDir, '*.*',
            TSearchOption.soAllDirectories);
          for I := 0 to High(Files) do
          begin
            FileName := ExpandFileName(Files[I]);
            if IsTextureAssetFile(FileName) then
              TextureList.Add(FileName);
          end;
        end;

        if ImGui.BeginListBox('##AnimatedSpriteTextureList',
          ImVec2.New(-1, 120)) then
        begin
          for I := 0 to TextureList.Count - 1 do
          begin
            FileName := TextureList[I];
            RelativePath := TEnginePaths.ToAssetRelativePath(FileName);
            DisplayName := ExtractRelativePath(RootDir, FileName);
            if DisplayName = '' then
              DisplayName := ExtractFileName(FileName);

            if ImGui.Selectable(PAnsiChar(AnsiString(DisplayName +
              '##AnimatedSpriteTexture' + IntToStr(I))),
              SameText(RelativePath, AnimatedSprite.TexturePath)) then
            begin
              if AnimatedSprite.LoadTexture(FileName) then
              begin
                if (Trim(AnimatedSprite.Name) = '') or
                   SameText(AnimatedSprite.Name, 'AnimatedSprite') then
                begin
                  AnimatedSprite.Name := ChangeFileExt(
                    ExtractFileName(FileName), '');
                end;
                LogLine('Animated sprite sheet selected: ' + DisplayName);
                MarkAnimatedSpriteEdited;
              end;
            end;
          end;
          ImGui.EndListBox;
        end;
      finally
        TextureList.Free;
      end;

      ImGui.Separator;
      FloatValue := AnimatedSprite.Width;
      if InspectorInputFloat('Width##AnimatedSprite', @FloatValue, 0.05,
        0.001, 100000.0, '%.3f') then
      begin
        AnimatedSprite.Width := FloatValue;
        MarkAnimatedSpriteEdited;
      end;

      FloatValue := AnimatedSprite.Height;
      if InspectorInputFloat('Height##AnimatedSprite', @FloatValue, 0.05,
        0.001, 100000.0, '%.3f') then
      begin
        AnimatedSprite.Height := FloatValue;
        MarkAnimatedSpriteEdited;
      end;

      VectorValue[0] := AnimatedSprite.Offset.X;
      VectorValue[1] := AnimatedSprite.Offset.Y;
      VectorValue[2] := AnimatedSprite.Offset.Z;
      if InspectorInputFloat3('Offset##AnimatedSprite', @VectorValue[0],
        0.05, -100000.0, 100000.0, '%.3f') then
      begin
        AnimatedSprite.Offset := Vector3(VectorValue[0], VectorValue[1],
          VectorValue[2]);
        MarkAnimatedSpriteEdited;
      end;

      FloatValue := RadToDeg(AnimatedSprite.Rotation);
      if InspectorInputFloat('Rotation##AnimatedSprite', @FloatValue, 1.0,
        -360000.0, 360000.0, '%.2f deg') then
      begin
        AnimatedSprite.Rotation := DegToRad(FloatValue);
        MarkAnimatedSpriteEdited;
      end;

      ColorValue[0] := AnimatedSprite.Color.X;
      ColorValue[1] := AnimatedSprite.Color.Y;
      ColorValue[2] := AnimatedSprite.Color.Z;
      ColorValue[3] := AnimatedSprite.Color.W;
      if ImGui.ColorEdit4('Color##AnimatedSprite', @ColorValue[0]) then
      begin
        AnimatedSprite.Color := Vector4(ColorValue[0], ColorValue[1],
          ColorValue[2], ColorValue[3]);
        MarkAnimatedSpriteEdited;
      end;

      ImGui.Text('Blend');
      BlendValue := Ord(AnimatedSprite.BlendMode);
      ImGui.RadioButton('Alpha##AnimatedSpriteBlend', @BlendValue,
        Ord(asAlpha));
      ImGui.SameLine;
      ImGui.RadioButton('Additive##AnimatedSpriteBlend', @BlendValue,
        Ord(asAdditive));
      if BlendValue <> Ord(AnimatedSprite.BlendMode) then
      begin
        AnimatedSprite.BlendMode := TAnimatedSpriteBlendMode(EnsureRange(
          BlendValue, Ord(Low(TAnimatedSpriteBlendMode)),
          Ord(High(TAnimatedSpriteBlendMode))));
        MarkAnimatedSpriteEdited;
      end;

      FloatValue := AnimatedSprite.AlphaCutoff;
      if InspectorInputFloat('Alpha cutoff##AnimatedSprite', @FloatValue,
        0.005, 0.0, 1.0, '%.3f') then
      begin
        AnimatedSprite.AlphaCutoff := FloatValue;
        MarkAnimatedSpriteEdited;
      end;

      ImGui.Separator;
      if ImGui.Button('Remove Selected Animated Sprite') then
        DeleteSelectedAnimatedSprite;
    finally
      ImGui.PopId;
    end;
  finally
    ImGui.PopId;
  end;
end;

procedure TSandBoxForm.DrawImGuiAudioProperties;
var
  Emitter: TSceneAudioEmitter;
  I: Integer;
  EnabledValue: Boolean;
  BoolValue: Boolean;
  FloatValue: Single;
  IntValue: Integer;
  VectorValue: array[0..2] of Single;
  NameBuf: array[0..127] of AnsiChar;
  PathBuf: array[0..511] of AnsiChar;
  DisplayName: string;
  ModeValue: Integer;
  Item: TAudioFileInfo;

  procedure MarkAudioEdited;
  begin
    NotifyInspectorObjectEdited;
    ApplySceneAudioEmitterRuntimeState(fSelectedObject, Emitter);
  end;

  procedure LogAudioActionError(const AAction: string; E: Exception);
  begin
    LogLine(AAction + ' failed: ' + E.Message);
  end;

begin
  if fSelectedObject = nil then
    Exit;

  if not ImGui.CollapsingHeader('Audio', ImGuiTreeNodeFlags_DefaultOpen) then
    Exit;

  ImGui.PushId(Pointer(fSelectedObject));
  try
    BoolValue := fSelectedObject.AudioListener;
    if ImGui.Checkbox('Listener##SceneAudio', @BoolValue) then
    begin
      fSelectedObject.AudioListener := BoolValue;
      NotifyInspectorObjectEdited;
    end;

    if fSelectedObject.AudioListener then
    begin
      VectorValue[0] := fSelectedObject.AudioListenerVelocity.X;
      VectorValue[1] := fSelectedObject.AudioListenerVelocity.Y;
      VectorValue[2] := fSelectedObject.AudioListenerVelocity.Z;
      if InspectorInputFloat3('Listener velocity##SceneAudio', @VectorValue[0],
        0.05, -100000.0, 100000.0, '%.3f') then
      begin
        fSelectedObject.AudioListenerVelocity := Vector3(VectorValue[0],
          VectorValue[1], VectorValue[2]);
        NotifyInspectorObjectEdited;
      end;

      VectorValue[0] := fSelectedObject.AudioListenerFront.X;
      VectorValue[1] := fSelectedObject.AudioListenerFront.Y;
      VectorValue[2] := fSelectedObject.AudioListenerFront.Z;
      if InspectorInputFloat3('Listener front##SceneAudio', @VectorValue[0],
        0.05, -1.0, 1.0, '%.3f') then
      begin
        fSelectedObject.AudioListenerFront := Vector3(VectorValue[0],
          VectorValue[1], VectorValue[2]);
        NotifyInspectorObjectEdited;
      end;

      VectorValue[0] := fSelectedObject.AudioListenerTop.X;
      VectorValue[1] := fSelectedObject.AudioListenerTop.Y;
      VectorValue[2] := fSelectedObject.AudioListenerTop.Z;
      if InspectorInputFloat3('Listener top##SceneAudio', @VectorValue[0],
        0.05, -1.0, 1.0, '%.3f') then
      begin
        fSelectedObject.AudioListenerTop := Vector3(VectorValue[0],
          VectorValue[1], VectorValue[2]);
        NotifyInspectorObjectEdited;
      end;

      FloatValue := fSelectedObject.AudioDistanceFactor;
      if InspectorInputFloat('Distance factor##SceneAudio', @FloatValue,
        0.05, 0.0, 1000.0, '%.3f') then
      begin
        fSelectedObject.AudioDistanceFactor := FloatValue;
        NotifyInspectorObjectEdited;
      end;

      FloatValue := fSelectedObject.AudioRolloffFactor;
      if InspectorInputFloat('Rolloff factor##SceneAudio', @FloatValue,
        0.05, 0.0, 1000.0, '%.3f') then
      begin
        fSelectedObject.AudioRolloffFactor := FloatValue;
        NotifyInspectorObjectEdited;
      end;

      FloatValue := fSelectedObject.AudioDopplerFactor;
      if InspectorInputFloat('Doppler factor##SceneAudio', @FloatValue,
        0.05, 0.0, 1000.0, '%.3f') then
      begin
        fSelectedObject.AudioDopplerFactor := FloatValue;
        NotifyInspectorObjectEdited;
      end;
    end;

    ImGui.Separator;
    if ImGui.Button('+ Audio Emitter') then
    begin
      fSelectedObject.AddAudioEmitter;
      SelectAudioEmitterIndex(fSelectedObject.AudioEmitterCount - 1);
      LogLine('Audio emitter created on object: ' + fSelectedObject.Name);
      NotifyInspectorObjectEdited;
    end;

    if fSelectedObject.AudioEmitterCount = 0 then
    begin
      ImGui.TextWrapped('Add an emitter to play positional audio from this object.');
      Exit;
    end;

    if (fSelectedAudioEmitterIndex < 0) or
       (fSelectedAudioEmitterIndex >= fSelectedObject.AudioEmitterCount) then
      SelectAudioEmitterIndex(0);

    if ImGui.BeginListBox('##AudioEmitterList', ImVec2.New(-1, 90)) then
    begin
      for I := 0 to fSelectedObject.AudioEmitterCount - 1 do
      begin
        Emitter := fSelectedObject.AudioEmitterItem[I];
        if Emitter = nil then
          Continue;

        DisplayName := Trim(Emitter.Name);
        if DisplayName = '' then
          DisplayName := Format('AudioEmitter %d', [I + 1]);

        if ImGui.Selectable(PAnsiChar(AnsiString(DisplayName)),
          I = fSelectedAudioEmitterIndex) then
          SelectAudioEmitterIndex(I);
      end;
      ImGui.EndListBox;
    end;

    Emitter := SelectedAudioEmitter;
    if Emitter = nil then
      Exit;

    ImGui.PushId(Pointer(Emitter));
    try
      SetAnsiBuffer(NameBuf, Emitter.Name);
      ImGui.PushItemWidth(IMGUI_PROP_TEXT_WIDTH);
      if ImGui.InputText('Name##AudioEmitter', @NameBuf[0],
        SizeOf(NameBuf)) then
      begin
        Emitter.Name := Trim(AnsiBufferText(NameBuf));
        if Emitter.Name = '' then
          Emitter.Name := 'AudioEmitter';
        MarkAudioEdited;
      end;
      ImGui.PopItemWidth;

      EnabledValue := Emitter.Enabled;
      if ImGui.Checkbox('Enabled##AudioEmitter', @EnabledValue) then
      begin
        Emitter.Enabled := EnabledValue;
        if (not Emitter.Enabled) and (Emitter.RuntimeSound <> nil) then
          try
            Emitter.RuntimeSound.Stop;
          except
            on E: Exception do
              LogAudioActionError('Stop disabled scene audio emitter', E);
          end;
        MarkAudioEdited;
      end;

      SetAnsiBuffer(PathBuf, Emitter.AudioPath);
      ImGui.PushItemWidth(-1);
      if ImGui.InputText('Audio path##AudioEmitter', @PathBuf[0],
        SizeOf(PathBuf)) then
      begin
        Emitter.AudioPath := Trim(AnsiBufferText(PathBuf));
        ReleaseSceneAudioEmitter(Emitter);
        MarkAudioEdited;
      end;
      ImGui.PopItemWidth;

      if fAudioTest.NeedsRefresh then
        RefreshAudioFileList;

      if ImGui.Button('Refresh Audio Assets##Emitter') then
        RefreshAudioFileList;

      if ImGui.BeginListBox('##AudioEmitterAssets', ImVec2.New(-1, 90)) then
      begin
        for I := 0 to High(fAudioTest.Items) do
        begin
          Item := fAudioTest.Items[I];
          if ImGui.Selectable(PAnsiChar(AnsiString(Item.DisplayName +
            '##EmitterAudioAsset' + IntToStr(I))),
            SameText(Item.RelativePath, Emitter.AudioPath)) then
          begin
            Emitter.AudioPath := Item.RelativePath;
            ReleaseSceneAudioEmitter(Emitter);
            MarkAudioEdited;
          end;

          ImGui.TextWrapped(PAnsiChar(AnsiString(Item.RelativePath)));
        end;
        ImGui.EndListBox;
      end;

      if fAudioTest.LastError <> '' then
        ImGui.TextWrapped(PAnsiChar(AnsiString(fAudioTest.LastError)));

      BoolValue := Emitter.AutoPlay;
      if ImGui.Checkbox('Auto play after load##AudioEmitter', @BoolValue) then
      begin
        Emitter.AutoPlay := BoolValue;
        MarkAudioEdited;
      end;

      BoolValue := Emitter.Loop;
      if ImGui.Checkbox('Loop##AudioEmitter', @BoolValue) then
      begin
        Emitter.Loop := BoolValue;
        MarkAudioEdited;
      end;

      BoolValue := Emitter.Spatial;
      if ImGui.Checkbox('Spatial 3D##AudioEmitter', @BoolValue) then
      begin
        Emitter.Spatial := BoolValue;
        ReleaseSceneAudioEmitter(Emitter);
        MarkAudioEdited;
      end;

      BoolValue := Emitter.MutedAtMaxDistance;
      if ImGui.Checkbox('Mute at max distance##AudioEmitter', @BoolValue) then
      begin
        Emitter.MutedAtMaxDistance := BoolValue;
        ReleaseSceneAudioEmitter(Emitter);
        MarkAudioEdited;
      end;

      FloatValue := Emitter.Volume;
      if ImGui.SliderFloat('Volume##AudioEmitter', @FloatValue, 0.0, 1.0,
        '%.2f', ImGuiSliderFlags_None) then
      begin
        Emitter.Volume := FloatValue;
        MarkAudioEdited;
      end;

      ImGui.Text('3D mode');
      ModeValue := Ord(Emitter.Mode);
      ImGui.RadioButton('Normal##Audio3DMode', @ModeValue, Ord(b3dmNormal));
      ImGui.SameLine;
      ImGui.RadioButton('Relative##Audio3DMode', @ModeValue, Ord(b3dmRelative));
      ImGui.SameLine;
      ImGui.RadioButton('Off##Audio3DMode', @ModeValue, Ord(b3dmOff));
      if ModeValue <> Ord(Emitter.Mode) then
      begin
        Emitter.Mode := TBass3DMode(EnsureRange(ModeValue,
          Ord(Low(TBass3DMode)), Ord(High(TBass3DMode))));
        MarkAudioEdited;
      end;

      FloatValue := Emitter.MinDistance;
      if InspectorInputFloat('Min distance##AudioEmitter', @FloatValue,
        0.05, 0.0, 100000.0, '%.3f') then
      begin
        Emitter.MinDistance := FloatValue;
        MarkAudioEdited;
      end;

      FloatValue := Emitter.MaxDistance;
      if InspectorInputFloat('Max distance##AudioEmitter', @FloatValue,
        0.05, 0.0, 100000.0, '%.3f') then
      begin
        Emitter.MaxDistance := FloatValue;
        MarkAudioEdited;
      end;

      IntValue := Emitter.InsideConeAngle;
      if InspectorInputInt('Inside cone##AudioEmitter', @IntValue, 1.0,
        0, 360, '%d deg', ImGuiSliderFlags_None) then
      begin
        Emitter.InsideConeAngle := IntValue;
        MarkAudioEdited;
      end;

      IntValue := Emitter.OutsideConeAngle;
      if InspectorInputInt('Outside cone##AudioEmitter', @IntValue, 1.0,
        0, 360, '%d deg', ImGuiSliderFlags_None) then
      begin
        Emitter.OutsideConeAngle := IntValue;
        MarkAudioEdited;
      end;

      IntValue := Emitter.OutsideVolume;
      if InspectorInputInt('Outside volume##AudioEmitter', @IntValue, 1.0,
        0, 100, '%d %%', ImGuiSliderFlags_None) then
      begin
        Emitter.OutsideVolume := IntValue;
        MarkAudioEdited;
      end;

      VectorValue[0] := Emitter.Offset.X;
      VectorValue[1] := Emitter.Offset.Y;
      VectorValue[2] := Emitter.Offset.Z;
      if InspectorInputFloat3('Offset##AudioEmitter', @VectorValue[0],
        0.05, -100000.0, 100000.0, '%.3f') then
      begin
        Emitter.Offset := Vector3(VectorValue[0], VectorValue[1],
          VectorValue[2]);
        MarkAudioEdited;
      end;

      VectorValue[0] := Emitter.Velocity.X;
      VectorValue[1] := Emitter.Velocity.Y;
      VectorValue[2] := Emitter.Velocity.Z;
      if InspectorInputFloat3('Velocity##AudioEmitter', @VectorValue[0],
        0.05, -100000.0, 100000.0, '%.3f') then
      begin
        Emitter.Velocity := Vector3(VectorValue[0], VectorValue[1],
          VectorValue[2]);
        MarkAudioEdited;
      end;

      VectorValue[0] := Emitter.Orientation.X;
      VectorValue[1] := Emitter.Orientation.Y;
      VectorValue[2] := Emitter.Orientation.Z;
      if InspectorInputFloat3('Orientation##AudioEmitter', @VectorValue[0],
        0.05, -1.0, 1.0, '%.3f') then
      begin
        Emitter.Orientation := Vector3(VectorValue[0], VectorValue[1],
          VectorValue[2]);
        MarkAudioEdited;
      end;

      ImGui.Separator;
      if Emitter.RuntimeSound <> nil then
        ImGui.Text(PAnsiChar(AnsiString('State: ' +
          TBassAudioEngine.PlaybackStateText(Emitter.RuntimeSound.State))))
      else
        ImGui.Text('State: not loaded');

      if ImGui.Button('Load##AudioEmitter') then
        LoadSceneAudioEmitter(Emitter);

      ImGui.SameLine;
      if ImGui.Button('Play##AudioEmitter') then
      begin
        try
          if Emitter.RuntimeSound = nil then
            LoadSceneAudioEmitter(Emitter);
          if Emitter.RuntimeSound <> nil then
            Emitter.RuntimeSound.Play(False);
        except
          on E: Exception do
            LogAudioActionError('Play scene audio emitter', E);
        end;
      end;

      ImGui.SameLine;
      if ImGui.Button('Pause##AudioEmitter') then
      begin
        try
          if Emitter.RuntimeSound <> nil then
            Emitter.RuntimeSound.Pause;
        except
          on E: Exception do
            LogAudioActionError('Pause scene audio emitter', E);
        end;
      end;

      ImGui.SameLine;
      if ImGui.Button('Stop##AudioEmitter') then
      begin
        try
          if Emitter.RuntimeSound <> nil then
            Emitter.RuntimeSound.Stop;
        except
          on E: Exception do
            LogAudioActionError('Stop scene audio emitter', E);
        end;
      end;

      if ImGui.Button('Unload##AudioEmitter') then
        ReleaseSceneAudioEmitter(Emitter);

      ImGui.SameLine;
      if ImGui.Button('Delete Audio Emitter') then
      begin
        DeleteSelectedAudioEmitter;
        Exit;
      end;
    finally
      ImGui.PopId;
    end;
  finally
    ImGui.PopId;
  end;
end;

procedure TSandBoxForm.DrawImGuiMeshProperties(Mesh: TMesh);
var
  NameBuf: array[0..127] of AnsiChar;
  SourceBuf: array[0..511] of AnsiChar;
  P, R, S: array[0..2] of Single;
  Visible: Boolean;
  AlwaysOnTop: Boolean;
  TagValue: Integer;
  TransformChanged: Boolean;
begin
  if Mesh = nil then
    Exit;

  ImGui.PushId(Pointer(Mesh));
  try
    if ImGui.CollapsingHeader('Mesh Properties', ImGuiTreeNodeFlags_DefaultOpen) then
    begin
    ImGui.PushItemWidth(IMGUI_PROP_TEXT_WIDTH);
    SetAnsiBuffer(NameBuf, Mesh.Name);
    if ImGui.InputText('Name', @NameBuf[0], SizeOf(NameBuf)) then
    begin
      Mesh.Name := AnsiBufferText(NameBuf);
      NotifyInspectorMeshEdited(Mesh, False);
    end;
    ImGui.PopItemWidth;

    ImGui.Text(PAnsiChar(AnsiString('Class: ' + Mesh.ClassName)));
    ImGui.Text(PAnsiChar(AnsiString(Format('Mesh type: %d', [Ord(Mesh.MeshType)]))));
    ImGui.Text(PAnsiChar(AnsiString(Format('Vertices: %d', [Mesh.VertexCount]))));
    ImGui.Text(PAnsiChar(AnsiString(Format('Indices: %d', [Mesh.IndexCount]))));
    ImGui.Text(PAnsiChar(AnsiString('Static geometry: ' + BoolToStr(Mesh.IsStatic, True))));

    Visible := Mesh.Visible;
    if ImGui.Checkbox('Visible', @Visible) then
    begin
      Mesh.Visible := Visible;
      NotifyInspectorMeshEdited(Mesh, False);
    end;

    AlwaysOnTop := Mesh.AlwaysOnTop;
    if ImGui.Checkbox('Always on top', @AlwaysOnTop) then
    begin
      Mesh.AlwaysOnTop := AlwaysOnTop;
      NotifyInspectorMeshEdited(Mesh, False);
    end;

    ImGui.PushItemWidth(IMGUI_PROP_SCALAR_WIDTH);
    TagValue := Mesh.Tag;
    if InspectorInputInt('Tag', @TagValue, 1.0, -2147483647, 2147483647,
      '%d', ImGuiSliderFlags_None) then
    begin
      Mesh.Tag := TagValue;
      NotifyInspectorMeshEdited(Mesh, False);
    end;
    ImGui.PopItemWidth;

    if Mesh is TFileMesh then
    begin
      ImGui.PushItemWidth(IMGUI_PROP_TEXT_WIDTH);
      SetAnsiBuffer(SourceBuf, TFileMesh(Mesh).SourceFile);
      if ImGui.InputText('Source file', @SourceBuf[0], SizeOf(SourceBuf)) then
      begin
        TFileMesh(Mesh).SourceFile := AnsiBufferText(SourceBuf);
        NotifyInspectorMeshEdited(Mesh, False);
      end;
      ImGui.PopItemWidth;
    end
    else if Mesh is THeightFieldMesh then
    begin
      ImGui.PushItemWidth(IMGUI_PROP_TEXT_WIDTH);
      SetAnsiBuffer(SourceBuf, THeightFieldMesh(Mesh).SourceFile);
      if ImGui.InputText('Source file', @SourceBuf[0], SizeOf(SourceBuf)) then
      begin
        THeightFieldMesh(Mesh).SourceFile := AnsiBufferText(SourceBuf);
        NotifyInspectorMeshEdited(Mesh, False);
      end;
      ImGui.PopItemWidth;
    end;
  end;

  if ImGui.CollapsingHeader('Mesh Transform', ImGuiTreeNodeFlags_DefaultOpen) then
  begin
    P[0] := Mesh.Position.X;
    P[1] := Mesh.Position.Y;
    P[2] := Mesh.Position.Z;
    R[0] := RadToDeg(Mesh.Rotation.X);
    R[1] := RadToDeg(Mesh.Rotation.Y);
    R[2] := RadToDeg(Mesh.Rotation.Z);
    S[0] := Mesh.Scale.X;
    S[1] := Mesh.Scale.Y;
    S[2] := Mesh.Scale.Z;

    ImGui.PushItemWidth(IMGUI_PROP_VECTOR3_WIDTH);
    TransformChanged := False;
    TransformChanged := InspectorInputFloat3('Position', @P[0], 0.05,
      -100000, 100000, '%.2f') or TransformChanged;
    TransformChanged := InspectorInputFloat3('Rotation', @R[0], 0.25,
      -360, 360, '%.2f') or TransformChanged;
    TransformChanged := InspectorInputFloat3('Scale', @S[0], 0.05,
      0.001, 100000, '%.2f') or TransformChanged;
    ImGui.PopItemWidth;

    if TransformChanged then
    begin
      Mesh.SetTransform(Vector3(P[0], P[1], P[2]),
        Vector3(DegToRad(R[0]), DegToRad(R[1]), DegToRad(R[2])),
        Vector3(S[0], S[1], S[2]));
      NotifyInspectorMeshEdited(Mesh, False);
    end;
  end;

    if ImGui.CollapsingHeader('Mesh Geometry Properties', ImGuiTreeNodeFlags_DefaultOpen) then
      DrawImGuiMeshGeometryProperties(Mesh);
  finally
    ImGui.PopId;
  end;
end;

procedure TSandBoxForm.DrawImGuiMeshGeometryProperties(Mesh: TMesh);
var
  GeometryChanged: Boolean;
  F: Single;
  I: Integer;
  C: array[0..3] of Single;
  V: array[0..2] of Single;
  B: Boolean;
begin
  if Mesh = nil then
    Exit;

  GeometryChanged := False;
  ImGui.PushItemWidth(IMGUI_PROP_SCALAR_WIDTH);

  if Mesh is THeightFieldMesh then
  begin
    F := THeightFieldMesh(Mesh).Width;
    if InspectorInputFloat('Width', @F, 0.25, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      THeightFieldMesh(Mesh).Width := F;
      GeometryChanged := True;
    end;

    F := THeightFieldMesh(Mesh).Depth;
    if InspectorInputFloat('Depth', @F, 0.25, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      THeightFieldMesh(Mesh).Depth := F;
      GeometryChanged := True;
    end;

    F := THeightFieldMesh(Mesh).HeightScale;
    if InspectorInputFloat('Height scale', @F, 0.05, 0.001, 100000, '%.3f') then
    begin
      ActivateMainRenderContext;
      THeightFieldMesh(Mesh).HeightScale := F;
      GeometryChanged := True;
    end;

    F := THeightFieldMesh(Mesh).UVScale;
    if InspectorInputFloat('UV scale', @F, 0.05, 0.001, 100000, '%.3f') then
    begin
      ActivateMainRenderContext;
      THeightFieldMesh(Mesh).UVScale := F;
      GeometryChanged := True;
    end;

    ImGui.Separator;
    ImGui.TextWrapped('Smooth sharp height-map corners by bicubic upsampling the stored height samples.');
    if ImGui.Button('Smooth x2') then
    begin
      ActivateMainRenderContext;
      THeightFieldMesh(Mesh).UpsampleHeights(2);
      GeometryChanged := True;
    end;
    ImGui.SameLine;
    if ImGui.Button('Smooth x4') then
    begin
      ActivateMainRenderContext;
      THeightFieldMesh(Mesh).UpsampleHeights(4);
      GeometryChanged := True;
    end;
    ImGui.Text(PAnsiChar(AnsiString(Format('Height map samples: %d x %d',
      [THeightFieldMesh(Mesh).HeightMapWidth, THeightFieldMesh(Mesh).HeightMapDepth]))));

    if ImGui.TreeNode('LOD') then
    begin
      B := THeightFieldMesh(Mesh).LODEnabled;
      if ImGui.Checkbox('LOD enabled', @B) then
      begin
        THeightFieldMesh(Mesh).LODEnabled := B;
        GeometryChanged := True;
      end;

      I := THeightFieldMesh(Mesh).LODCount;
      if InspectorInputInt('LOD count', @I, 1.0, 1, HEIGHTFIELD_MAX_LOD_LEVELS, '%d', ImGuiSliderFlags_None) then
      begin
        ActivateMainRenderContext;
        THeightFieldMesh(Mesh).LODCount := I;
        GeometryChanged := True;
      end;

      F := THeightFieldMesh(Mesh).LODDistance;
      if InspectorInputFloat('LOD distance', @F, 0.25, 0.001, 100000, '%.2f') then
      begin
        THeightFieldMesh(Mesh).LODDistance := F;
        GeometryChanged := True;
      end;

      I := THeightFieldMesh(Mesh).TileSize;
      if InspectorInputInt('Tile size', @I, 1.0, 1, 4096, '%d', ImGuiSliderFlags_None) then
      begin
        ActivateMainRenderContext;
        THeightFieldMesh(Mesh).TileSize := I;
        GeometryChanged := True;
      end;

      V[0] := THeightFieldMesh(Mesh).LODCameraPosition.X;
      V[1] := THeightFieldMesh(Mesh).LODCameraPosition.Y;
      V[2] := THeightFieldMesh(Mesh).LODCameraPosition.Z;
      ImGui.Text(PAnsiChar(AnsiString(Format('LOD camera: %.2f, %.2f, %.2f', [V[0], V[1], V[2]]))));
      ImGui.TreePop;
    end;
  end
  else if Mesh is TWaterPlaneMesh then
  begin
    F := TWaterPlaneMesh(Mesh).Width;
    if InspectorInputFloat('Width', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TWaterPlaneMesh(Mesh).Width := F;
      GeometryChanged := True;
    end;

    F := TWaterPlaneMesh(Mesh).Depth;
    if InspectorInputFloat('Depth', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TWaterPlaneMesh(Mesh).Depth := F;
      GeometryChanged := True;
    end;

    I := TWaterPlaneMesh(Mesh).WidthSegments;
    if InspectorInputInt('Width segments', @I, 1.0, WATER_EDITOR_MIN_SEGMENTS,
      512, '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TWaterPlaneMesh(Mesh).WidthSegments := I;
      GeometryChanged := True;
    end;

    I := TWaterPlaneMesh(Mesh).DepthSegments;
    if InspectorInputInt('Depth segments', @I, 1.0, WATER_EDITOR_MIN_SEGMENTS,
      512, '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TWaterPlaneMesh(Mesh).DepthSegments := I;
      GeometryChanged := True;
    end;

    C[0] := TWaterPlaneMesh(Mesh).TintColor.X;
    C[1] := TWaterPlaneMesh(Mesh).TintColor.Y;
    C[2] := TWaterPlaneMesh(Mesh).TintColor.Z;
    C[3] := TWaterPlaneMesh(Mesh).TintColor.W;
    if ImGui.ColorEdit4('Tint color', @C[0]) then
    begin
      TWaterPlaneMesh(Mesh).TintColor := Vector4(C[0], C[1], C[2], C[3]);
      NotifyInspectorMeshEdited(Mesh, False);
    end;

    C[0] := TWaterPlaneMesh(Mesh).DeepColor.X;
    C[1] := TWaterPlaneMesh(Mesh).DeepColor.Y;
    C[2] := TWaterPlaneMesh(Mesh).DeepColor.Z;
    C[3] := TWaterPlaneMesh(Mesh).DeepColor.W;
    if ImGui.ColorEdit4('Deep color', @C[0]) then
    begin
      TWaterPlaneMesh(Mesh).DeepColor := Vector4(C[0], C[1], C[2], C[3]);
      NotifyInspectorMeshEdited(Mesh, False);
    end;

    F := TWaterPlaneMesh(Mesh).ReflectionStrength;
    if InspectorInputFloat('Reflection strength', @F, 0.01, 0, 100000, '%.3f') then
    begin
      TWaterPlaneMesh(Mesh).ReflectionStrength := F;
      NotifyInspectorMeshEdited(Mesh, False);
    end;

    F := TWaterPlaneMesh(Mesh).WaveScale;
    if InspectorInputFloat('Wave scale', @F, 0.01, 0, 100000, '%.3f') then
    begin
      TWaterPlaneMesh(Mesh).WaveScale := F;
      NotifyInspectorMeshEdited(Mesh, False);
    end;

    F := TWaterPlaneMesh(Mesh).WaveSpeed;
    if InspectorInputFloat('Wave speed', @F, 0.01, 0, 100000, '%.3f') then
    begin
      TWaterPlaneMesh(Mesh).WaveSpeed := F;
      NotifyInspectorMeshEdited(Mesh, False);
    end;

    F := TWaterPlaneMesh(Mesh).WaveStrength;
    if InspectorInputFloat('Wave strength', @F, 0.01, 0, 100000, '%.3f') then
    begin
      TWaterPlaneMesh(Mesh).WaveStrength := F;
      NotifyInspectorMeshEdited(Mesh, False);
    end;

    F := TWaterPlaneMesh(Mesh).FresnelPower;
    if InspectorInputFloat('Fresnel power', @F, 0.01, 0, 100000, '%.3f') then
    begin
      TWaterPlaneMesh(Mesh).FresnelPower := F;
      NotifyInspectorMeshEdited(Mesh, False);
    end;

    F := TWaterPlaneMesh(Mesh).Alpha;
    if InspectorInputFloat('Alpha', @F, 0.01, 0, 1, '%.3f') then
    begin
      TWaterPlaneMesh(Mesh).Alpha := F;
      NotifyInspectorMeshEdited(Mesh, False);
    end;
  end
  else if Mesh is TPlaneMesh then
  begin
    F := TPlaneMesh(Mesh).Width;
    if InspectorInputFloat('Width', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TPlaneMesh(Mesh).Width := F;
      GeometryChanged := True;
    end;

    F := TPlaneMesh(Mesh).Depth;
    if InspectorInputFloat('Depth', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TPlaneMesh(Mesh).Depth := F;
      GeometryChanged := True;
    end;

    I := TPlaneMesh(Mesh).WidthSegments;
    if InspectorInputInt('Width segments', @I, 1.0, 1, 512, '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TPlaneMesh(Mesh).WidthSegments := I;
      GeometryChanged := True;
    end;

    I := TPlaneMesh(Mesh).DepthSegments;
    if InspectorInputInt('Depth segments', @I, 1.0, 1, 512, '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TPlaneMesh(Mesh).DepthSegments := I;
      GeometryChanged := True;
    end;
  end
  else if Mesh is TCubeMesh then
  begin
    F := TCubeMesh(Mesh).Width;
    if InspectorInputFloat('Width', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TCubeMesh(Mesh).Width := F;
      GeometryChanged := True;
    end;

    F := TCubeMesh(Mesh).Height;
    if InspectorInputFloat('Height', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TCubeMesh(Mesh).Height := F;
      GeometryChanged := True;
    end;

    F := TCubeMesh(Mesh).Depth;
    if InspectorInputFloat('Depth', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TCubeMesh(Mesh).Depth := F;
      GeometryChanged := True;
    end;

    I := TCubeMesh(Mesh).WidthStacks;
    if InspectorInputInt('Width segments', @I, 1.0, 1, 512, '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TCubeMesh(Mesh).WidthStacks := I;
      GeometryChanged := True;
    end;

    I := TCubeMesh(Mesh).HeightStacks;
    if InspectorInputInt('Height segments', @I, 1.0, 1, 512, '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TCubeMesh(Mesh).HeightStacks := I;
      GeometryChanged := True;
    end;

    I := TCubeMesh(Mesh).DepthStacks;
    if InspectorInputInt('Depth segments', @I, 1.0, 1, 512, '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TCubeMesh(Mesh).DepthStacks := I;
      GeometryChanged := True;
    end;
  end
  else if Mesh is TSphereMesh then
  begin
    F := TSphereMesh(Mesh).Radius;
    if InspectorInputFloat('Radius', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TSphereMesh(Mesh).Radius := F;
      GeometryChanged := True;
    end;

    I := TSphereMesh(Mesh).StackCount;
    if InspectorInputInt('Stacks', @I, 1.0, 2, 512, '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TSphereMesh(Mesh).StackCount := I;
      GeometryChanged := True;
    end;

    I := TSphereMesh(Mesh).SliceCount;
    if InspectorInputInt('Slices', @I, 1.0, 3, 512, '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TSphereMesh(Mesh).SliceCount := I;
      GeometryChanged := True;
    end;
  end
  else if Mesh is TCylinderMesh then
  begin
    F := TCylinderMesh(Mesh).Radius;
    if InspectorInputFloat('Radius', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TCylinderMesh(Mesh).Radius := F;
      GeometryChanged := True;
    end;

    F := TCylinderMesh(Mesh).Height;
    if InspectorInputFloat('Height', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TCylinderMesh(Mesh).Height := F;
      GeometryChanged := True;
    end;

    I := TCylinderMesh(Mesh).Slices;
    if InspectorInputInt('Slices', @I, 1.0, 3, 512, '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TCylinderMesh(Mesh).Slices := I;
      GeometryChanged := True;
    end;

    I := TCylinderMesh(Mesh).Stacks;
    if InspectorInputInt('Stacks', @I, 1.0, 1, 512, '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TCylinderMesh(Mesh).Stacks := I;
      GeometryChanged := True;
    end;

    I := Ord(TCylinderMesh(Mesh).BottomCap);
    if InspectorInputInt('Bottom cap', @I, 1.0, Ord(Low(TCapType)), Ord(High(TCapType)), '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TCylinderMesh(Mesh).BottomCap := TCapType(I);
      GeometryChanged := True;
    end;

    I := Ord(TCylinderMesh(Mesh).TopCap);
    if InspectorInputInt('Top cap', @I, 1.0, Ord(Low(TCapType)), Ord(High(TCapType)), '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TCylinderMesh(Mesh).TopCap := TCapType(I);
      GeometryChanged := True;
    end;
  end
  else if Mesh is TCapsuleMesh then
  begin
    F := TCapsuleMesh(Mesh).Radius;
    if InspectorInputFloat('Radius', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TCapsuleMesh(Mesh).Radius := F;
      GeometryChanged := True;
    end;

    F := TCapsuleMesh(Mesh).Height;
    if InspectorInputFloat('Height', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TCapsuleMesh(Mesh).Height := F;
      GeometryChanged := True;
    end;

    I := TCapsuleMesh(Mesh).Slices;
    if InspectorInputInt('Slices', @I, 1.0, 3, 512, '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TCapsuleMesh(Mesh).Slices := I;
      GeometryChanged := True;
    end;

    I := TCapsuleMesh(Mesh).Stacks;
    if InspectorInputInt('Stacks', @I, 1.0, 1, 512, '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TCapsuleMesh(Mesh).Stacks := I;
      GeometryChanged := True;
    end;
  end
  else if Mesh is TTorusMesh then
  begin
    F := TTorusMesh(Mesh).MajorRadius;
    if InspectorInputFloat('Major radius', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TTorusMesh(Mesh).MajorRadius := F;
      GeometryChanged := True;
    end;

    F := TTorusMesh(Mesh).MinorRadius;
    if InspectorInputFloat('Minor radius', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TTorusMesh(Mesh).MinorRadius := F;
      GeometryChanged := True;
    end;

    I := TTorusMesh(Mesh).MajorSegments;
    if InspectorInputInt('Major segments', @I, 1.0, 3, 512, '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TTorusMesh(Mesh).MajorSegments := I;
      GeometryChanged := True;
    end;

    I := TTorusMesh(Mesh).MinorSegments;
    if InspectorInputInt('Minor segments', @I, 1.0, 3, 512, '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TTorusMesh(Mesh).MinorSegments := I;
      GeometryChanged := True;
    end;
  end
  else if Mesh is TConeMesh then
  begin
    F := TConeMesh(Mesh).Radius;
    if InspectorInputFloat('Radius', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TConeMesh(Mesh).Radius := F;
      GeometryChanged := True;
    end;

    F := TConeMesh(Mesh).Height;
    if InspectorInputFloat('Height', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TConeMesh(Mesh).Height := F;
      GeometryChanged := True;
    end;

    I := TConeMesh(Mesh).Sides;
    if InspectorInputInt('Sides', @I, 1.0, 3, 512, '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TConeMesh(Mesh).Sides := I;
      GeometryChanged := True;
    end;

    I := TConeMesh(Mesh).Stacks;
    if InspectorInputInt('Stacks', @I, 1.0, 1, 512, '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TConeMesh(Mesh).Stacks := I;
      GeometryChanged := True;
    end;

    I := Ord(TConeMesh(Mesh).BottomCap);
    if InspectorInputInt('Bottom cap', @I, 1.0, Ord(Low(TCapType)), Ord(High(TCapType)), '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TConeMesh(Mesh).BottomCap := TCapType(I);
      GeometryChanged := True;
    end;
  end
  else if Mesh is TPrismMesh then
  begin
    F := TPrismMesh(Mesh).Radius;
    if InspectorInputFloat('Radius', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TPrismMesh(Mesh).Radius := F;
      GeometryChanged := True;
    end;

    F := TPrismMesh(Mesh).Height;
    if InspectorInputFloat('Height', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TPrismMesh(Mesh).Height := F;
      GeometryChanged := True;
    end;

    I := TPrismMesh(Mesh).Sides;
    if InspectorInputInt('Sides', @I, 1.0, 3, 512, '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TPrismMesh(Mesh).Sides := I;
      GeometryChanged := True;
    end;

    I := TPrismMesh(Mesh).Stacks;
    if InspectorInputInt('Stacks', @I, 1.0, 1, 512, '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TPrismMesh(Mesh).Stacks := I;
      GeometryChanged := True;
    end;
  end
  else if Mesh is TFrustumMesh then
  begin
    F := TFrustumMesh(Mesh).BottomRadius;
    if InspectorInputFloat('Bottom radius', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TFrustumMesh(Mesh).BottomRadius := F;
      GeometryChanged := True;
    end;

    F := TFrustumMesh(Mesh).TopRadius;
    if InspectorInputFloat('Top radius', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TFrustumMesh(Mesh).TopRadius := F;
      GeometryChanged := True;
    end;

    F := TFrustumMesh(Mesh).Height;
    if InspectorInputFloat('Height', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TFrustumMesh(Mesh).Height := F;
      GeometryChanged := True;
    end;

    I := TFrustumMesh(Mesh).Slices;
    if InspectorInputInt('Slices', @I, 1.0, 3, 512, '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TFrustumMesh(Mesh).Slices := I;
      GeometryChanged := True;
    end;

    I := TFrustumMesh(Mesh).Stacks;
    if InspectorInputInt('Stacks', @I, 1.0, 1, 512, '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TFrustumMesh(Mesh).Stacks := I;
      GeometryChanged := True;
    end;

    I := Ord(TFrustumMesh(Mesh).BottomCap);
    if InspectorInputInt('Bottom cap', @I, 1.0, Ord(Low(TCapType)), Ord(High(TCapType)), '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TFrustumMesh(Mesh).BottomCap := TCapType(I);
      GeometryChanged := True;
    end;

    I := Ord(TFrustumMesh(Mesh).TopCap);
    if InspectorInputInt('Top cap', @I, 1.0, Ord(Low(TCapType)), Ord(High(TCapType)), '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TFrustumMesh(Mesh).TopCap := TCapType(I);
      GeometryChanged := True;
    end;
  end
  else if Mesh is TIcosphereMesh then
  begin
    F := TIcosphereMesh(Mesh).Radius;
    if InspectorInputFloat('Radius', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TIcosphereMesh(Mesh).Radius := F;
      GeometryChanged := True;
    end;

    I := TIcosphereMesh(Mesh).Subdivisions;
    if InspectorInputInt('Subdivisions', @I, 1.0, 0, 6, '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TIcosphereMesh(Mesh).Subdivisions := I;
      GeometryChanged := True;
    end;
  end
  else if Mesh is TGeodesicDomeMesh then
  begin
    F := TGeodesicDomeMesh(Mesh).Radius;
    if InspectorInputFloat('Radius', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TGeodesicDomeMesh(Mesh).Radius := F;
      GeometryChanged := True;
    end;

    I := TGeodesicDomeMesh(Mesh).Subdivisions;
    if InspectorInputInt('Subdivisions', @I, 1.0, 0, 6, '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TGeodesicDomeMesh(Mesh).Subdivisions := I;
      GeometryChanged := True;
    end;
  end
  else if Mesh is TArrowMesh then
  begin
    F := TArrowMesh(Mesh).ShaftLength;
    if InspectorInputFloat('Shaft length', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TArrowMesh(Mesh).ShaftLength := F;
      GeometryChanged := True;
    end;

    F := TArrowMesh(Mesh).TipLength;
    if InspectorInputFloat('Tip length', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TArrowMesh(Mesh).TipLength := F;
      GeometryChanged := True;
    end;

    F := TArrowMesh(Mesh).ShaftRadius;
    if InspectorInputFloat('Shaft radius', @F, 0.005, 0.001, 100000, '%.3f') then
    begin
      ActivateMainRenderContext;
      TArrowMesh(Mesh).ShaftRadius := F;
      GeometryChanged := True;
    end;

    F := TArrowMesh(Mesh).TipRadius;
    if InspectorInputFloat('Tip radius', @F, 0.005, 0.001, 100000, '%.3f') then
    begin
      ActivateMainRenderContext;
      TArrowMesh(Mesh).TipRadius := F;
      GeometryChanged := True;
    end;

    I := TArrowMesh(Mesh).Slices;
    if InspectorInputInt('Slices', @I, 1.0, 3, 512, '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TArrowMesh(Mesh).Slices := I;
      GeometryChanged := True;
    end;

    I := TArrowMesh(Mesh).Stacks;
    if InspectorInputInt('Stacks', @I, 1.0, 1, 512, '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TArrowMesh(Mesh).Stacks := I;
      GeometryChanged := True;
    end;
  end
  else if Mesh is TSuperEllipsoidMesh then
  begin
    F := TSuperEllipsoidMesh(Mesh).Radius;
    if InspectorInputFloat('Radius', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TSuperEllipsoidMesh(Mesh).Radius := F;
      GeometryChanged := True;
    end;

    F := TSuperEllipsoidMesh(Mesh).VCurve;
    if InspectorInputFloat('Vertical curve', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TSuperEllipsoidMesh(Mesh).VCurve := F;
      GeometryChanged := True;
    end;

    F := TSuperEllipsoidMesh(Mesh).HCurve;
    if InspectorInputFloat('Horizontal curve', @F, 0.05, 0.001, 100000, '%.2f') then
    begin
      ActivateMainRenderContext;
      TSuperEllipsoidMesh(Mesh).HCurve := F;
      GeometryChanged := True;
    end;

    I := TSuperEllipsoidMesh(Mesh).Slices;
    if InspectorInputInt('Slices', @I, 1.0, 3, 512, '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TSuperEllipsoidMesh(Mesh).Slices := I;
      GeometryChanged := True;
    end;

    I := TSuperEllipsoidMesh(Mesh).Stacks;
    if InspectorInputInt('Stacks', @I, 1.0, 2, 512, '%d', ImGuiSliderFlags_None) then
    begin
      ActivateMainRenderContext;
      TSuperEllipsoidMesh(Mesh).Stacks := I;
      GeometryChanged := True;
    end;
  end
  else
    ImGui.Text('No editable geometry properties for this mesh type.');

  ImGui.PopItemWidth;

  if GeometryChanged then
    NotifyInspectorMeshEdited(Mesh, True);
end;


function ToneMappingModeDisplayName(Mode: TToneMappingMode): string;
begin
  case Mode of
    tmLinear: Result := 'Linear';
    tmExponential: Result := 'Exp';
    tmReinhard: Result := 'Reinhard';
    tmUncharted2: Result := 'Uncharted 2';
    tmMGSV: Result := 'MGSV';
    tmUchimura: Result := 'Uchimura';
    tmFilmic: Result := 'Filmic';
    tmACES: Result := 'ACES';
    tmPBRNeutral: Result := 'PBR neutral';
    tmFlim: Result := 'flim';
    tmAGX: Result := 'AGX';
  else
    Result := 'ACES';
  end;
end;

function FormatAudioSeconds(ASeconds: Double): string;
var
  TotalSeconds: Integer;
begin
  if ASeconds < 0 then
    ASeconds := 0;

  TotalSeconds := Round(ASeconds);
  Result := Format('%.2d:%.2d', [TotalSeconds div 60, TotalSeconds mod 60]);
end;

function TSandBoxForm.IsAudioAssetFile(const AFileName: string): Boolean;
begin
  Result := TBassAudioEngine.IsSupportedAudioFile(AFileName);
end;

procedure TSandBoxForm.RefreshAudioFileList;
var
  Files: TArray<string>;
  I: Integer;
  Count: Integer;
  Item: TAudioFileInfo;

  function FormatFileSize(const Size: Int64): string;
  begin
    if Size >= 1024 * 1024 then
      Result := FormatFloat('0.0 MB', Size / (1024 * 1024))
    else if Size >= 1024 then
      Result := FormatFloat('0.0 KB', Size / 1024)
    else
      Result := IntToStr(Size) + ' B';
  end;

begin
  fAudioTest.NeedsRefresh := False;
  fAudioTest.LastError := '';
  SetLength(fAudioTest.Items, 0);

  ForceDirectories(TEnginePaths.AudioDir);

  try
    Files := TDirectory.GetFiles(TEnginePaths.AudioDir, '*.*',
      TSearchOption.soTopDirectoryOnly);
  except
    on E: Exception do
    begin
      fAudioTest.LastError := 'Could not scan audio directory: ' + E.Message;
      Exit;
    end;
  end;

  Count := 0;
  for I := 0 to High(Files) do
  begin
    if not IsAudioAssetFile(Files[I]) then
      Continue;

    Item.FileName := Files[I];
    Item.RelativePath := TEnginePaths.ToAssetRelativePath(Files[I]);
    Item.DisplayName := ChangeFileExt(ExtractFileName(Files[I]), '');
    try
      Item.FileSize := TFile.GetSize(Files[I]);
      Item.ModifiedText := FormatDateTime('yyyy-mm-dd hh:nn',
        TFile.GetLastWriteTime(Files[I]));
    except
      Item.FileSize := 0;
      Item.ModifiedText := '';
    end;

    if Item.DisplayName = '' then
      Item.DisplayName := ExtractFileName(Files[I]);

    if Item.ModifiedText <> '' then
      Item.ModifiedText := FormatFileSize(Item.FileSize) + ', modified ' +
        Item.ModifiedText
    else
      Item.ModifiedText := FormatFileSize(Item.FileSize);

    SetLength(fAudioTest.Items, Count + 1);
    fAudioTest.Items[Count] := Item;
    Inc(Count);
  end;

  if Count = 0 then
    fAudioTest.LastError := 'No supported audio files found in ' +
      TEnginePaths.AudioDir;
end;

procedure TSandBoxForm.LoadAudioTestFile(const AFileName: string);
var
  FileName: string;
  Candidate: string;
begin
  fAudioTest.LastError := '';
  FileName := Trim(AFileName);

  if FileName = '' then
  begin
    fAudioTest.LastError := 'Choose or enter an audio file first.';
    Exit;
  end;

  if TPath.IsPathRooted(FileName) then
    Candidate := FileName
  else
  begin
    Candidate := TEnginePaths.Audio(FileName);
    if not FileExists(Candidate) then
      Candidate := TEnginePaths.ResolveAssetPath(FileName);
  end;

  if not FileExists(Candidate) then
  begin
    fAudioTest.LastError := 'Audio file not found: ' + FileName;
    Exit;
  end;

  try
    if fAudioEngine = nil then
      raise Exception.Create('The game engine audio service is not available.');

    if not fAudioEngine.Initialized then
      fAudioEngine.Initialize3D(Handle);

    fAudioEngine.FreeSound(fAudioTestSound);
    fAudioTestSound := fAudioEngine.LoadSound(Candidate, fAudioTest.Loop);
    fAudioTestSound.Volume := fAudioTest.Volume;
    SetAnsiBuffer(fAudioTest.FileName,
      TEnginePaths.ToAssetRelativePath(Candidate));
    LogLine('Audio loaded: ' + Candidate);
  except
    on E: Exception do
    begin
      fAudioTest.LastError := E.Message;
      LogLine('Audio load failed: ' + E.Message);
    end;
  end;
end;

function TSandBoxForm.ResolveAudioPath(const AStoredPath: string): string;
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

procedure TSandBoxForm.LoadSceneAudioEmitter(AEmitter: TSceneAudioEmitter);
var
  Candidate: string;
  NewSound: TBassSound;
begin
  if fEngine <> nil then
  begin
    fEngine.LoadSceneAudioEmitter(fSelectedObject, AEmitter);
    Exit;
  end;

  if AEmitter = nil then
    Exit;

  Candidate := ResolveAudioPath(AEmitter.AudioPath);
  if (Candidate = '') or (not FileExists(Candidate)) then
  begin
    LogLine('Audio emitter file not found: ' + AEmitter.AudioPath);
    Exit;
  end;

  try
    if fAudioEngine = nil then
      raise Exception.Create('The game engine audio service is not available.');

    if AEmitter.Spatial then
      fAudioEngine.Initialize3D(Handle)
    else if not fAudioEngine.Initialized then
      fAudioEngine.Initialize(Handle);

    ReleaseSceneAudioEmitter(AEmitter);
    NewSound := fAudioEngine.LoadSound(Candidate, AEmitter.Loop,
      AEmitter.Spatial, AEmitter.MutedAtMaxDistance);
    AEmitter.RuntimeSound := NewSound;
    AEmitter.RuntimeSound.Volume := AEmitter.Volume;
    ApplySceneAudioEmitterRuntimeState(fSelectedObject, AEmitter);

    if AEmitter.AutoPlay then
      AEmitter.RuntimeSound.Play(False);

    AEmitter.AudioPath := TEnginePaths.ToAssetRelativePath(Candidate);
    LogLine('Scene audio emitter loaded: ' + Candidate);
  except
    on E: Exception do
      LogLine('Scene audio emitter load failed: ' + E.Message);
  end;
end;

procedure TSandBoxForm.ReleaseSceneAudioEmitter(AEmitter: TSceneAudioEmitter);
var
  Sound: TBassSound;
begin
  if fEngine <> nil then
  begin
    fEngine.ReleaseSceneAudioEmitter(AEmitter);
    Exit;
  end;

  if AEmitter = nil then
    Exit;

  Sound := AEmitter.RuntimeSound;
  if (fAudioEngine <> nil) and (Sound <> nil) then
    fAudioEngine.FreeSound(Sound);
  AEmitter.RuntimeSound := nil;
end;

procedure TSandBoxForm.ReleaseSceneObjectAudio(Obj: TSceneObject);
var
  I: Integer;
begin
  if fEngine <> nil then
  begin
    fEngine.ReleaseSceneObjectAudio(Obj);
    Exit;
  end;

  if Obj = nil then
    Exit;

  for I := 0 to Obj.AudioEmitterCount - 1 do
    ReleaseSceneAudioEmitter(Obj.AudioEmitterItem[I]);

  for I := 0 to Obj.Count - 1 do
    ReleaseSceneObjectAudio(Obj.ObjectList[I]);
end;

procedure TSandBoxForm.ApplySceneAudioEmitterRuntimeState(Obj: TSceneObject;
  AEmitter: TSceneAudioEmitter);
var
  PositionValue: TVector3;
  OrientationValue: TVector3;
  WorldPosition: TVector4;
  WorldOrientation: TVector4;

  function BassVector(const V: TVector3): TBass3DVector;
  begin
    Result := TBass3DVector.Create(V.X, V.Y, V.Z);
  end;

begin
  if fEngine <> nil then
  begin
    fEngine.UpdateSceneAudio;
    Exit;
  end;

  if (Obj = nil) or (AEmitter = nil) or
     (AEmitter.RuntimeSound = nil) then
    Exit;

  try
    AEmitter.RuntimeSound.Loop := AEmitter.Loop;
    AEmitter.RuntimeSound.Volume := AEmitter.Volume;

    if AEmitter.Spatial and AEmitter.RuntimeSound.Spatial then
    begin
      AEmitter.RuntimeSound.Set3DAttributes(AEmitter.Mode,
        AEmitter.MinDistance, AEmitter.MaxDistance,
        AEmitter.InsideConeAngle, AEmitter.OutsideConeAngle,
        AEmitter.OutsideVolume);

      WorldPosition := Obj.WorldMatrix * Vector4(AEmitter.Offset, 1.0);
      PositionValue := Vector3(WorldPosition);

      WorldOrientation := Obj.WorldMatrix * Vector4(AEmitter.Orientation, 0.0);
      OrientationValue := Vector3(WorldOrientation);
      if OrientationValue.LengthSquared < 1e-8 then
        OrientationValue := Vector3(0, 0, -1)
      else
        OrientationValue.Normalize;

      AEmitter.RuntimeSound.Set3DPosition(BassVector(PositionValue),
        BassVector(OrientationValue), BassVector(AEmitter.Velocity));
    end;
  except
    on E: Exception do
      LogLine('Scene audio update failed: ' + E.Message);
  end;
end;

procedure TSandBoxForm.UpdateSceneAudio;
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
    D: TVector4;
  begin
    Result := Fallback;
    if Obj = nil then
      Exit;

    D := Obj.WorldMatrix * Vector4(LocalDir, 0.0);
    Result := Vector3(D);
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
  begin
    if Obj = nil then
      Exit;

    for I := 0 to Obj.AudioEmitterCount - 1 do
    begin
      Emitter := Obj.AudioEmitterItem[I];
      if Assigned(Emitter) and Emitter.Enabled then
        ApplySceneAudioEmitterRuntimeState(Obj, Emitter);
    end;

    for I := 0 to Obj.Count - 1 do
      UpdateEmitters(Obj.ObjectList[I]);
  end;

begin
  if fEngine <> nil then
  begin
    fEngine.UpdateSceneAudio;
    Exit;
  end;

  if (fAudioEngine = nil) or (not fAudioEngine.Initialized) then
    Exit;

  ListenerObj := FindAudioListener(fRoot);
  if ListenerObj <> nil then
  begin
    ListenerPosition := Vector3(ListenerObj.WorldMatrix.Columns[3]);
    ListenerVelocity := ListenerObj.AudioListenerVelocity;
    ListenerFront := TransformDirection(ListenerObj,
      ListenerObj.AudioListenerFront, Vector3(0, 0, -1));
    ListenerTop := TransformDirection(ListenerObj,
      ListenerObj.AudioListenerTop, Vector3(0, 1, 0));
    fAudioEngine.Set3DFactors(ListenerObj.AudioDistanceFactor,
      ListenerObj.AudioRolloffFactor, ListenerObj.AudioDopplerFactor);
  end
  else if (fRenderer <> nil) and (fRenderer.ActiveCamera <> nil) and
          (fRenderer.ActiveCamera.Camera <> nil) then
  begin
    ListenerPosition := fRenderer.ActiveCamera.Camera.Position;
    ListenerVelocity := Vector3(0, 0, 0);
    ListenerFront := fRenderer.ActiveCamera.Camera.Front;
    ListenerTop := fRenderer.ActiveCamera.Camera.Up;
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

  try
    fAudioEngine.SetListener3D(BassVector(ListenerPosition),
      BassVector(ListenerVelocity), BassVector(ListenerFront),
      BassVector(ListenerTop));
    UpdateEmitters(fRoot);
    fAudioEngine.Apply3D;
  except
    on E: Exception do
      LogLine('Scene audio listener update failed: ' + E.Message);
  end;
end;

procedure TSandBoxForm.BindScriptEngine;
begin
  if fScriptManager = nil then
    raise Exception.Create('The game engine script manager is not available.');

  fScriptManager.BindEngine(fRenderer, fSceneManager, EnsureDefaultMaterialLibrary,
    DefaultRenderableMaterialName, MeshRenderHandler, fPhysicsWorld, fAudioEngine,
    LoadPrefabForScript, DestroyPrefabForScript);
end;

function TSandBoxForm.ResolveScriptFileName(const AFileName,
  AExtension: string): string;
var
  FileName: string;
  Ext: string;
begin
  Result := '';
  fScriptEditor.LastError := '';

  FileName := Trim(AFileName);
  if FileName = '' then
  begin
    fScriptEditor.LastError := 'Enter a script file name first.';
    Exit;
  end;

  FileName := StringReplace(FileName, '/', PathDelim, [rfReplaceAll]);
  if TPath.IsPathRooted(FileName) then
  begin
    if SameText(Copy(IncludeTrailingPathDelimiter(ExpandFileName(FileName)), 1,
      Length(TEnginePaths.ScriptsDir)), TEnginePaths.ScriptsDir) then
      FileName := ExtractRelativePath(TEnginePaths.ScriptsDir, FileName)
    else
      FileName := ExtractFileName(FileName);
  end;

  if SameText(Copy(FileName, 1, Length('Data' + PathDelim + 'Scripts' +
    PathDelim)), 'Data' + PathDelim + 'Scripts' + PathDelim) then
    Delete(FileName, 1, Length('Data' + PathDelim + 'Scripts' + PathDelim));

  if (FileName = '..') or (Pos('..' + PathDelim, FileName) > 0) or
     (Pos(PathDelim + '..', FileName) > 0) then
  begin
    fScriptEditor.LastError := 'Script file names must stay inside Data\Scripts.';
    Exit;
  end;

  Ext := LowerCase(ExtractFileExt(FileName));
  if Ext = '' then
    FileName := ChangeFileExt(FileName, AExtension)
  else if Ext <> AExtension then
  begin
    fScriptEditor.LastError := 'Script files use ' + AExtension;
    Exit;
  end;

  Result := TEnginePaths.Script(FileName);
end;

function TSandBoxForm.SelectedScriptAsset: TEngineScriptAsset;
begin
  Result := nil;
  if (fScriptManager = nil) or
     (fScriptEditor.SelectedIndex < 0) or
     (fScriptEditor.SelectedIndex >= fScriptManager.Count) then
    Exit;

  Result := fScriptManager.Script[fScriptEditor.SelectedIndex];
end;

procedure TSandBoxForm.SyncScriptEditorFromSelected;
var
  Script: TEngineScriptAsset;
begin
  Script := SelectedScriptAsset;
  if Script = nil then
  begin
    SetAnsiBuffer(fScriptEditor.Name, '');
    SetAnsiBuffer(fScriptEditor.Description, '');
    SetAnsiBuffer(fScriptEditor.Author, '');
    SetAnsiBuffer(fScriptEditor.Category, '');
    SetAnsiBuffer(fScriptEditor.VersionText, '1.0');
    SetAnsiBuffer(fScriptEditor.EntryPoint, 'Main');
    SetAnsiBuffer(fScriptEditor.TargetName, '');
    SetAnsiBuffer(fScriptEditor.AssetFileName,
      ChangeFileExt('Script', SCRIPT_ASSET_FILE_EXTENSION_LOCAL));
    SetAnsiBuffer(fScriptEditor.Source, DefaultScriptSource);
    fScriptEditor.Dirty := False;
    Exit;
  end;

  SetAnsiBuffer(fScriptEditor.Name, Script.Name);
  SetAnsiBuffer(fScriptEditor.Description, Script.Description);
  SetAnsiBuffer(fScriptEditor.Author, Script.Author);
  SetAnsiBuffer(fScriptEditor.Category, Script.Category);
  SetAnsiBuffer(fScriptEditor.VersionText, Script.VersionText);
  SetAnsiBuffer(fScriptEditor.EntryPoint, Script.EntryPoint);
  SetAnsiBuffer(fScriptEditor.TargetName, Script.TargetName);
  SetAnsiBuffer(fScriptEditor.AssetFileName,
    ChangeFileExt(Script.Name, SCRIPT_ASSET_FILE_EXTENSION_LOCAL));
  SetAnsiBuffer(fScriptEditor.Source, Script.Source);
  fScriptEditor.Dirty := False;
end;

procedure TSandBoxForm.SyncSelectedScriptFromEditor;
var
  Script: TEngineScriptAsset;
  NameText: string;
begin
  Script := SelectedScriptAsset;
  if Script = nil then
    Exit;

  NameText := Trim(AnsiBufferText(fScriptEditor.Name));
  if NameText = '' then
    NameText := 'Script';

  Script.Name := NameText;
  Script.Description := AnsiBufferText(fScriptEditor.Description);
  Script.Author := AnsiBufferText(fScriptEditor.Author);
  Script.Category := AnsiBufferText(fScriptEditor.Category);
  Script.VersionText := AnsiBufferText(fScriptEditor.VersionText);
  if Script.VersionText = '' then
    Script.VersionText := '1.0';
  Script.EntryPoint := AnsiBufferText(fScriptEditor.EntryPoint);
  Script.TargetName := AnsiBufferText(fScriptEditor.TargetName);
  Script.Source := AnsiBufferRawText(fScriptEditor.Source);
  Script.Touch;
  fScriptManager.ResetRuntimeState;
  fScriptManager.ResolveScriptTargets;
  fScriptEditor.Dirty := False;
end;

procedure TSandBoxForm.SelectScriptIndex(const AIndex: Integer);
begin
  if (fScriptManager <> nil) and (AIndex >= 0) and
     (AIndex < fScriptManager.Count) then
    fScriptEditor.SelectedIndex := AIndex
  else
    fScriptEditor.SelectedIndex := -1;

  SyncScriptEditorFromSelected;
end;

procedure TSandBoxForm.AddNewScriptFromEditor;
var
  Script: TEngineScriptAsset;
  ScriptName: string;
begin
  if fScriptManager = nil then
    raise Exception.Create('The game engine script manager is not available.');

  BindScriptEngine;
  ScriptName := Trim(AnsiBufferText(fScriptEditor.NewScriptName));
  if ScriptName = '' then
    ScriptName := 'Script';

  Script := fScriptManager.AddScript(ScriptName, DefaultScriptSource,
    stkGlobal, '', 'Main');
  Script.Description := 'Created from the ImGui script editor.';
  Script.Touch;

  SelectScriptIndex(fScriptManager.Count - 1);
  SetAnsiBuffer(fScriptEditor.AssetFileName,
    ChangeFileExt(Script.Name, SCRIPT_ASSET_FILE_EXTENSION_LOCAL));
  fScriptEditor.Status := 'Script created: ' + Script.Name;
  fScriptEditor.LastError := '';
  LogLine(fScriptEditor.Status);
end;

procedure TSandBoxForm.DeleteSelectedScript;
var
  Index: Integer;
begin
  if fScriptManager = nil then
    Exit;

  Index := fScriptEditor.SelectedIndex;
  if (Index < 0) or (Index >= fScriptManager.Count) then
  begin
    fScriptEditor.LastError := 'Select a script first.';
    Exit;
  end;

  fScriptManager.DeleteScript(Index);
  if Index >= fScriptManager.Count then
    Index := fScriptManager.Count - 1;
  SelectScriptIndex(Index);
  fScriptEditor.Status := 'Script deleted.';
  fScriptEditor.LastError := '';
  LogLine(fScriptEditor.Status);
end;

procedure TSandBoxForm.SaveScriptLibraryToFile(const AFileName: string);
var
  FileName: string;
begin
  if fScriptManager = nil then
  begin
    fScriptEditor.LastError := 'No script manager is available.';
    Exit;
  end;

  SyncSelectedScriptFromEditor;
  FileName := ResolveScriptFileName(AFileName, SCRIPT_LIBRARY_FILE_EXTENSION_LOCAL);
  if FileName = '' then
    Exit;

  try
    ForceDirectories(ExtractFilePath(FileName));
    fScriptManager.SaveToFile(FileName);
    fScriptEditor.PendingOverwrite := False;
    fScriptEditor.PendingOverwriteKind := sowNone;
    fScriptEditor.PendingOverwriteFileName := '';
    fScriptEditor.NeedsFileRefresh := True;
    fScriptEditor.Status := 'Script library saved: ' + FileName;
    fScriptEditor.LastError := '';
    LogLine(fScriptEditor.Status);
  except
    on E: Exception do
    begin
      fScriptEditor.LastError := 'Save script library failed: ' + E.Message;
      LogLine(fScriptEditor.LastError);
    end;
  end;
end;

procedure TSandBoxForm.LoadScriptLibraryFromFile(const AFileName: string);
var
  FileName: string;
begin
  FileName := ResolveScriptFileName(AFileName, SCRIPT_LIBRARY_FILE_EXTENSION_LOCAL);
  if FileName = '' then
    Exit;

  if not FileExists(FileName) then
  begin
    fScriptEditor.LastError := 'Script library not found: ' + FileName;
    Exit;
  end;

  if fScriptManager = nil then
    raise Exception.Create('The game engine script manager is not available.');

  try
    fScriptManager.LoadFromFile(FileName);
    BindScriptEngine;
    if fScriptManager.Count > 0 then
      SelectScriptIndex(0)
    else
      SelectScriptIndex(-1);

    fScriptEditor.Status := 'Script library loaded: ' + FileName;
    fScriptEditor.LastError := '';
    LogLine(fScriptEditor.Status);
  except
    on E: Exception do
    begin
      fScriptEditor.LastError := 'Load script library failed: ' + E.Message;
      LogLine(fScriptEditor.LastError);
    end;
  end;
end;

procedure TSandBoxForm.SaveSelectedScriptAssetToFile(const AFileName: string);
var
  Script: TEngineScriptAsset;
  FileName: string;
begin
  Script := SelectedScriptAsset;
  if Script = nil then
  begin
    fScriptEditor.LastError := 'Select a script first.';
    Exit;
  end;

  SyncSelectedScriptFromEditor;
  Script := SelectedScriptAsset;
  FileName := ResolveScriptFileName(AFileName, SCRIPT_ASSET_FILE_EXTENSION_LOCAL);
  if FileName = '' then
    Exit;

  try
    ForceDirectories(ExtractFilePath(FileName));
    fScriptManager.SaveAssetToFile(Script, FileName);
    fScriptEditor.PendingOverwrite := False;
    fScriptEditor.PendingOverwriteKind := sowNone;
    fScriptEditor.PendingOverwriteFileName := '';
    fScriptEditor.NeedsFileRefresh := True;
    fScriptEditor.Status := 'Script asset saved: ' + FileName;
    fScriptEditor.LastError := '';
    LogLine(fScriptEditor.Status);
  except
    on E: Exception do
    begin
      fScriptEditor.LastError := 'Save script asset failed: ' + E.Message;
      LogLine(fScriptEditor.LastError);
    end;
  end;
end;

procedure TSandBoxForm.LoadScriptAssetFromFile(const AFileName: string);
var
  Script: TEngineScriptAsset;
  FileName: string;
  I: Integer;
begin
  FileName := ResolveScriptFileName(AFileName, SCRIPT_ASSET_FILE_EXTENSION_LOCAL);
  if FileName = '' then
    Exit;

  if not FileExists(FileName) then
  begin
    fScriptEditor.LastError := 'Script asset not found: ' + FileName;
    Exit;
  end;

  if fScriptManager = nil then
    raise Exception.Create('The game engine script manager is not available.');

  try
    Script := fScriptManager.LoadAssetFromFile(FileName);
    BindScriptEngine;

    for I := 0 to fScriptManager.Count - 1 do
      if fScriptManager.Script[I] = Script then
      begin
        SelectScriptIndex(I);
        Break;
      end;

    fScriptEditor.Status := 'Script asset loaded: ' + FileName;
    fScriptEditor.LastError := '';
    LogLine(fScriptEditor.Status);
  except
    on E: Exception do
    begin
      fScriptEditor.LastError := 'Load script asset failed: ' + E.Message;
      LogLine(fScriptEditor.LastError);
    end;
  end;
end;

procedure TSandBoxForm.LoadScriptFile(const AFileName: string);
var
  FileName: string;
  Ext: string;
  AssetPath: string;
  LibraryPath: string;
begin
  FileName := Trim(AFileName);
  if FileName = '' then
  begin
    fScriptEditor.LastError := 'Enter a script file name first.';
    Exit;
  end;

  Ext := LowerCase(ExtractFileExt(FileName));
  if (Ext <> '') and (Ext <> SCRIPT_ASSET_FILE_EXTENSION_LOCAL) and
     (Ext <> SCRIPT_LIBRARY_FILE_EXTENSION_LOCAL) then
  begin
    fScriptEditor.LastError := 'Script files use ' +
      SCRIPT_ASSET_FILE_EXTENSION_LOCAL + ' or ' +
      SCRIPT_LIBRARY_FILE_EXTENSION_LOCAL;
    Exit;
  end;

  if Ext = SCRIPT_LIBRARY_FILE_EXTENSION_LOCAL then
  begin
    LoadScriptLibraryFromFile(FileName);
    Exit;
  end;

  if Ext = SCRIPT_ASSET_FILE_EXTENSION_LOCAL then
  begin
    LoadScriptAssetFromFile(FileName);
    Exit;
  end;

  AssetPath := ResolveScriptFileName(FileName, SCRIPT_ASSET_FILE_EXTENSION_LOCAL);
  if AssetPath = '' then
    Exit;
  LibraryPath := ResolveScriptFileName(FileName,
    SCRIPT_LIBRARY_FILE_EXTENSION_LOCAL);
  if LibraryPath = '' then
    Exit;

  if FileExists(LibraryPath) and (not FileExists(AssetPath)) then
    LoadScriptLibraryFromFile(FileName)
  else
    LoadScriptAssetFromFile(FileName);
end;

procedure TSandBoxForm.RefreshScriptFileList;
var
  Files: TList<TScriptFileInfo>;
  Info: TScriptFileInfo;
  SearchOptions: TSearchOption;

  procedure AddFiles(const AExtension: string; AKind: TScriptFileKind);
  var
    FoundFile: string;
  begin
    for FoundFile in TDirectory.GetFiles(TEnginePaths.ScriptsDir,
      '*' + AExtension, SearchOptions) do
    begin
      Info.FileName := FoundFile;
      Info.RelativePath := ExtractRelativePath(TEnginePaths.ScriptsDir, FoundFile);
      Info.DisplayName := ChangeFileExt(Info.RelativePath, '');
      Info.Kind := AKind;
      Info.FileSize := 0;
      if FileExists(FoundFile) then
        Info.FileSize := TFile.GetSize(FoundFile);
      Info.ModifiedText := FormatDateTime('yyyy-mm-dd hh:nn',
        TFile.GetLastWriteTime(FoundFile));
      Files.Add(Info);
    end;
  end;

begin
  ForceDirectories(TEnginePaths.ScriptsDir);
  Files := TList<TScriptFileInfo>.Create;
  try
    SearchOptions := TSearchOption.soAllDirectories;
    AddFiles(SCRIPT_LIBRARY_FILE_EXTENSION_LOCAL, sfkLibrary);
    AddFiles(SCRIPT_ASSET_FILE_EXTENSION_LOCAL, sfkAsset);
    fScriptEditor.Files := Files.ToArray;
  finally
    Files.Free;
  end;

  if fScriptEditor.SelectedFileIndex > High(fScriptEditor.Files) then
    fScriptEditor.SelectedFileIndex := -1;
  fScriptEditor.NeedsFileRefresh := False;
end;

procedure TSandBoxForm.ResetScriptSourceEditorTracking;
begin
  fScriptEditor.SourceEditorActive := False;
  fScriptEditor.SourceEditorHovered := False;
  fScriptEditor.SourceRectMinX := 0;
  fScriptEditor.SourceRectMinY := 0;
  fScriptEditor.SourceRectMaxX := 0;
  fScriptEditor.SourceRectMaxY := 0;
end;

procedure TSandBoxForm.ResetScriptEditorForSceneChange;
begin
  SelectScriptIndex(-1);
  fScriptEditor.PendingOverwrite := False;
  fScriptEditor.PendingOverwriteKind := sowNone;
  fScriptEditor.PendingOverwriteFileName := '';
  fScriptEditor.Status := '';
  fScriptEditor.LastError := '';
  fScriptEditor.Dirty := False;
  fLastScriptLifecycleError := '';
  ResetScriptSourceEditorTracking;
end;

function TSandBoxForm.ScriptSourceEditorContainsPoint(X, Y: Integer): Boolean;
begin
  Result := fShowScriptEditor and
    (fScriptEditor.SourceRectMaxX > fScriptEditor.SourceRectMinX) and
    (fScriptEditor.SourceRectMaxY > fScriptEditor.SourceRectMinY) and
    (X >= fScriptEditor.SourceRectMinX) and
    (X < fScriptEditor.SourceRectMaxX) and
    (Y >= fScriptEditor.SourceRectMinY) and
    (Y < fScriptEditor.SourceRectMaxY);
end;

procedure TSandBoxForm.ExecuteScriptLifecycleEvent(const AEventName: string);
var
  RunResult: TEngineScriptExecutionResult;
begin
  if (fScriptManager = nil) or fRunningScriptLifecycleEvent then
    Exit;

  fRunningScriptLifecycleEvent := True;
  try
    BindScriptEngine;
    RunResult := fScriptManager.ExecuteLifecycleEvent(AEventName);
    if RunResult.Success then
    begin
      if fLastScriptLifecycleError <> '' then
        fLastScriptLifecycleError := '';
    end
    else if RunResult.Messages <> fLastScriptLifecycleError then
    begin
      fLastScriptLifecycleError := RunResult.Messages;
      LogLine('Script ' + AEventName + ' failed: ' + RunResult.Messages);
    end;
  finally
    fRunningScriptLifecycleEvent := False;
  end;
end;

procedure TSandBoxForm.RendererBeforeRender(Sender: TObject);
begin
  ExecuteScriptLifecycleEvent('OnBeforeRender');
end;

procedure TSandBoxForm.RendererRender(Sender: TObject);
begin
  ExecuteScriptLifecycleEvent('OnRender');
end;

procedure TSandBoxForm.RendererAfterRender(Sender: TObject);
begin
  ExecuteScriptLifecycleEvent('OnAfterRender');
end;

procedure TSandBoxForm.RenderEditorGrid(Sender: TObject);
var
  RenderCamera: TSceneObject;
begin
  if (fGrid = nil) or (fRenderer = nil) then
    Exit;

  RenderCamera := fRenderer.ActiveCamera;
  if RenderCamera = nil then
    RenderCamera := fCamera;

  if (RenderCamera = nil) or (RenderCamera.Camera = nil) then
    Exit;

  fGrid.Render(RenderCamera.Camera.ViewMatrix, fRenderer.ProjectionMatrix,
    RenderCamera.Camera.Position);
end;

function TSandBoxForm.ResolveGeneratedTextureFileName(
  const AFileName: string): string;
begin
  Result := TEnginePaths.ResolveGeneratedTextureFileName(AFileName);
end;

procedure TSandBoxForm.QueueRenderTextureCapture;
var
  MaxSamples: Integer;
begin
  fRenderTextureTool.Width := EnsureRange(fRenderTextureTool.Width, 1, 16384);
  fRenderTextureTool.Height := EnsureRange(fRenderTextureTool.Height, 1, 16384);
  MaxSamples := 16;
  if fRenderer <> nil then
    MaxSamples := Max(1, fRenderer.MaxRenderTextureAntialiasingSamples);
  fRenderTextureTool.AntialiasingSamples :=
    EnsureRange(fRenderTextureTool.AntialiasingSamples, 1, MaxSamples);
  fRenderTextureTool.Pending := True;
  fRenderTextureTool.LastError := '';
  fRenderTextureTool.LastOutputFileName := '';
  RequestRender;
end;

procedure TSandBoxForm.ProcessRenderTextureCapture;
var
  FileName: string;
  ErrorText: string;
  AAText: string;
begin
  if not fRenderTextureTool.Pending then
    Exit;

  fRenderTextureTool.Pending := False;
  if fRenderer = nil then
  begin
    fRenderTextureTool.LastError := 'Renderer is not available.';
    LogLine('Render texture failed: ' + fRenderTextureTool.LastError);
    Exit;
  end;

  FileName := ResolveGeneratedTextureFileName(
    AnsiBufferText(fRenderTextureTool.FileName));
  TEnginePaths.EnsureDirectories;

  if fRenderer.RenderToTextureFile(fRenderTextureTool.Width,
    fRenderTextureTool.Height, FileName, ErrorText,
    fRenderTextureTool.AntialiasingSamples) then
  begin
    fRenderTextureTool.LastOutputFileName := FileName;
    fRenderTextureTool.LastError := '';
    if fRenderTextureTool.AntialiasingSamples > 1 then
      AAText := Format(', %dx AA', [fRenderTextureTool.AntialiasingSamples])
    else
      AAText := ', AA off';
    LogLine(Format('Render texture saved (%d x %d%s): %s',
      [fRenderTextureTool.Width, fRenderTextureTool.Height, AAText,
      FileName]));
  end
  else
  begin
    fRenderTextureTool.LastOutputFileName := '';
    fRenderTextureTool.LastError := ErrorText;
    if fRenderTextureTool.LastError = '' then
      fRenderTextureTool.LastError := 'Unknown render texture error.';
    LogLine('Render texture failed: ' + fRenderTextureTool.LastError);
  end;
end;

procedure TSandBoxForm.DrawImGuiAudioTest;
var
  OpenWindow: Boolean;
  I: Integer;
  Selected: Boolean;
  SearchText: string;
  FileText: string;
  Item: TAudioFileInfo;
  B: Boolean;
  F: Single;
  PosSeconds: Single;
  LenSeconds: Single;
  LeftLevel: Single;
  RightLevel: Single;

  procedure SetAudioError(const ADescription: string; E: Exception);
  begin
    fAudioTest.LastError := E.Message;
    LogLine(ADescription + ' failed: ' + E.Message);
  end;

begin
  if not fShowAudioTest then
    Exit;

  if fAudioTest.NeedsRefresh then
    RefreshAudioFileList;

  if fAudioEngine = nil then
    raise Exception.Create('The game engine audio service is not available.');

  ImGui.SetNextWindowPos(ImVec2.New(380, 110), ImGuiCond_FirstUseEver);
  ImGui.SetNextWindowSize(ImVec2.New(520, 560), ImGuiCond_FirstUseEver);

  OpenWindow := True;
  if not ImGui.Begin_('Audio Test (BASS)', @OpenWindow) then
  begin
    fShowAudioTest := OpenWindow;
    ImGui.End_;
    Exit;
  end;

  if fAudioEngine.Initialized then
    ImGui.Text(PAnsiChar(AnsiString(Format('BASS initialized: device %d, %d Hz',
      [fAudioEngine.Device, fAudioEngine.Frequency]))))
  else
    ImGui.Text('BASS is not initialized.');

  if fAudioEngine.Initialized then
  begin
    if ImGui.Button('Shutdown BASS') then
    begin
      ReleaseSceneObjectAudio(fRoot);
      fAudioTestSound := nil;
      fAudioEngine.Shutdown;
      LogLine('BASS audio shut down.');
    end;

    ImGui.SameLine;
    ImGui.Text(PAnsiChar(AnsiString(Format('CPU: %.2f%%',
      [fAudioEngine.CPUUsage]))));

    F := fAudioEngine.MasterVolume;
    if ImGui.SliderFloat('Master volume', @F, 0.0, 1.0, '%.2f',
      ImGuiSliderFlags_None) then
    begin
      fAudioTest.MasterVolume := F;
      fAudioTest.LastError := '';
      try
        fAudioEngine.SetMasterVolume(F);
      except
        on E: Exception do
          SetAudioError('Set master volume', E);
      end;
    end;
  end
  else if ImGui.Button('Initialize BASS') then
  begin
    fAudioTest.LastError := '';
    try
      fAudioEngine.Initialize(Handle);
      fAudioTest.MasterVolume := fAudioEngine.MasterVolume;
      LogLine('BASS audio initialized.');
    except
      on E: Exception do
        SetAudioError('Initialize BASS', E);
    end;
  end;

  ImGui.Separator;
  ImGui.TextWrapped(PAnsiChar(AnsiString('Audio directory: ' +
    TEnginePaths.AudioDir)));

  if ImGui.Button('Refresh Audio List') then
    RefreshAudioFileList;

  ImGui.PushItemWidth(-1);
  ImGui.InputText('Search##AudioSearch', @fAudioTest.Search[0],
    SizeOf(fAudioTest.Search));
  ImGui.PopItemWidth;

  SearchText := LowerCase(Trim(AnsiBufferText(fAudioTest.Search)));
  if ImGui.BeginListBox('##AudioFiles', ImVec2.New(-1, 150)) then
  begin
    for I := 0 to High(fAudioTest.Items) do
    begin
      Item := fAudioTest.Items[I];
      if (SearchText <> '') and
         (Pos(SearchText, LowerCase(Item.DisplayName)) = 0) and
         (Pos(SearchText, LowerCase(Item.RelativePath)) = 0) then
        Continue;

      Selected := I = fAudioTest.SelectedIndex;
      if ImGui.Selectable(PAnsiChar(AnsiString(Item.DisplayName + '##audio' +
        IntToStr(I))), Selected) then
      begin
        fAudioTest.SelectedIndex := I;
        SetAnsiBuffer(fAudioTest.FileName, Item.RelativePath);
      end;

      if Selected then
        ImGui.SetItemDefaultFocus;

      ImGui.TextWrapped(PAnsiChar(AnsiString(Item.RelativePath)));
      ImGui.TextWrapped(PAnsiChar(AnsiString(Item.ModifiedText)));
      ImGui.Separator;
    end;
    ImGui.EndListBox;
  end;

  ImGui.PushItemWidth(-1);
  ImGui.InputText('File##AudioFileName', @fAudioTest.FileName[0],
    SizeOf(fAudioTest.FileName));
  ImGui.PopItemWidth;

  B := fAudioTest.Loop;
  if ImGui.Checkbox('Loop', @B) then
  begin
    fAudioTest.Loop := B;
    if fAudioTestSound <> nil then
      fAudioTestSound.Loop := B;
  end;

  F := fAudioTest.Volume;
  if ImGui.SliderFloat('Channel volume', @F, 0.0, 1.0, '%.2f',
    ImGuiSliderFlags_None) then
  begin
    fAudioTest.Volume := F;
    if fAudioTestSound <> nil then
    begin
      fAudioTest.LastError := '';
      try
        fAudioTestSound.Volume := F;
      except
        on E: Exception do
          SetAudioError('Set channel volume', E);
      end;
    end;
  end;

  if ImGui.Button('Load Path') then
  begin
    FileText := AnsiBufferText(fAudioTest.FileName);
    LoadAudioTestFile(FileText);
  end;

  ImGui.SameLine;
  if ImGui.Button('Load Selected') then
  begin
    if (fAudioTest.SelectedIndex >= 0) and
       (fAudioTest.SelectedIndex <= High(fAudioTest.Items)) then
      LoadAudioTestFile(fAudioTest.Items[fAudioTest.SelectedIndex].FileName)
    else
      fAudioTest.LastError := 'Select an audio file first.';
  end;

  ImGui.Separator;

  if fAudioTestSound <> nil then
  begin
    ImGui.TextWrapped(PAnsiChar(AnsiString('Loaded: ' +
      ExtractFileName(fAudioTestSound.FileName))));
    if fAudioTestSound.IsMusic then
      ImGui.Text('Type: tracker/module music')
    else
      ImGui.Text('Type: stream/sample');

    ImGui.Text(PAnsiChar(AnsiString('State: ' +
      TBassAudioEngine.PlaybackStateText(fAudioTestSound.State))));

    if ImGui.Button('Play') then
    begin
      fAudioTest.LastError := '';
      try
        fAudioTestSound.Play(False);
      except
        on E: Exception do
          SetAudioError('Play audio', E);
      end;
    end;

    ImGui.SameLine;
    if ImGui.Button('Restart') then
    begin
      fAudioTest.LastError := '';
      try
        fAudioTestSound.Play(True);
      except
        on E: Exception do
          SetAudioError('Restart audio', E);
      end;
    end;

    ImGui.SameLine;
    if ImGui.Button('Pause') then
    begin
      fAudioTest.LastError := '';
      try
        fAudioTestSound.Pause;
      except
        on E: Exception do
          SetAudioError('Pause audio', E);
      end;
    end;

    ImGui.SameLine;
    if ImGui.Button('Stop') then
    begin
      fAudioTest.LastError := '';
      try
        fAudioTestSound.Stop;
      except
        on E: Exception do
          SetAudioError('Stop audio', E);
      end;
    end;

    LenSeconds := fAudioTestSound.LengthSeconds;
    PosSeconds := fAudioTestSound.PositionSeconds;
    if LenSeconds > 0.0 then
    begin
      if ImGui.SliderFloat('Position', @PosSeconds, 0.0, LenSeconds,
        PAnsiChar(AnsiString(FormatAudioSeconds(PosSeconds))),
        ImGuiSliderFlags_None) then
      begin
        fAudioTest.LastError := '';
        try
          fAudioTestSound.PositionSeconds := PosSeconds;
        except
          on E: Exception do
            SetAudioError('Seek audio', E);
        end;
      end;

      ImGui.Text(PAnsiChar(AnsiString(Format('%s / %s',
        [FormatAudioSeconds(PosSeconds), FormatAudioSeconds(LenSeconds)]))));
    end
    else
      ImGui.Text('Length: unknown');

    if fAudioTestSound.GetLevel(LeftLevel, RightLevel) then
    begin
      ImGui.Text('Levels');
      ImGui.ProgressBar(LeftLevel, ImVec2.New(-1, 0), 'Left');
      ImGui.ProgressBar(RightLevel, ImVec2.New(-1, 0), 'Right');
    end;
  end
  else
    ImGui.TextWrapped('Load an audio file, then use Play/Pause/Stop here.');

  if fAudioTest.LastError <> '' then
  begin
    ImGui.Separator;
    ImGui.TextWrapped(PAnsiChar(AnsiString(fAudioTest.LastError)));
  end;

  fShowAudioTest := OpenWindow;
  ImGui.End_;
end;

procedure TSandBoxForm.DrawImGuiScriptEditor;
var
  OpenWindow: Boolean;
  Script: TEngineScriptAsset;
  I: Integer;
  Selected: Boolean;
  LabelText: string;
  SearchText: string;
  KindText: string;
  FileItem: TScriptFileInfo;
  B: Boolean;
  KindValue: Integer;
  CompileResult: TEngineScriptExecutionResult;
  FileName: string;
  ReplaceClicked: Boolean;
  CancelClicked: Boolean;
  SourceActive: Boolean;
  SourceRectMin: ImVec2;
  SourceRectMax: ImVec2;
  Style: PImGuiStyle;
  ButtonWidth: Single;
  RunButtonText: string;

  function BuildSceneObjectPath(Obj: TSceneObject): string;
  begin
    Result := '';
    if Obj = nil then
      Exit;

    if Obj.Parent <> nil then
      Result := BuildSceneObjectPath(Obj.Parent);

    if Result <> '' then
      Result := Result + '/';
    Result := Result + Obj.Name;
  end;

  procedure BeginScriptOverwrite(AKind: TScriptEditorOverwriteKind;
    const AFileName: string);
  begin
    fScriptEditor.PendingOverwrite := True;
    fScriptEditor.PendingOverwriteKind := AKind;
    fScriptEditor.PendingOverwriteFileName := AFileName;
    fScriptEditor.LastError := '';
  end;

  procedure SaveLibraryClicked;
  begin
    FileName := ResolveScriptFileName(AnsiBufferText(fScriptEditor.LibraryFileName),
      SCRIPT_LIBRARY_FILE_EXTENSION_LOCAL);
    if FileName = '' then
      Exit;

    if FileExists(FileName) and
       ((not fScriptEditor.PendingOverwrite) or
        (not SameText(fScriptEditor.PendingOverwriteFileName, FileName))) then
    begin
      BeginScriptOverwrite(sowLibrary, FileName);
      Exit;
    end;

    SaveScriptLibraryToFile(FileName);
  end;

  procedure SaveAssetClicked;
  begin
    FileName := ResolveScriptFileName(AnsiBufferText(fScriptEditor.AssetFileName),
      SCRIPT_ASSET_FILE_EXTENSION_LOCAL);
    if FileName = '' then
      Exit;

    if FileExists(FileName) and
       ((not fScriptEditor.PendingOverwrite) or
        (not SameText(fScriptEditor.PendingOverwriteFileName, FileName))) then
    begin
      BeginScriptOverwrite(sowAsset, FileName);
      Exit;
    end;

    SaveSelectedScriptAssetToFile(FileName);
  end;

  procedure LoadFileClicked;
  begin
    LoadScriptFile(AnsiBufferText(fScriptEditor.AssetFileName));
  end;

begin
  if not fShowScriptEditor then
  begin
    ResetScriptSourceEditorTracking;
    Exit;
  end;

  if fScriptManager = nil then
    raise Exception.Create('The game engine script manager is not available.');
  if fScriptEditor.NeedsFileRefresh then
    RefreshScriptFileList;

  Style := ImGui.GetStyle;
  ImGui.SetNextWindowPos(ImVec2.New(420, 120), ImGuiCond_FirstUseEver);
  ImGui.SetNextWindowSize(ImVec2.New(760, 620), ImGuiCond_FirstUseEver);

  OpenWindow := True;
  if not ImGui.Begin_('Script Editor', @OpenWindow) then
  begin
    ResetScriptSourceEditorTracking;
    fShowScriptEditor := OpenWindow;
    ImGui.End_;
    Exit;
  end;

  ImGui.TextWrapped(PAnsiChar(AnsiString('Script directory: ' +
    TEnginePaths.ScriptsDir)));
  ImGui.Separator;

  if ImGui.BeginChild('ScriptListPane', ImVec2.New(250, -1)) then
  begin
    ImGui.Text(PAnsiChar(AnsiString(Format('Scripts: %d',
      [fScriptManager.Count]))));

    ImGui.PushItemWidth(-1);
    ImGui.InputText('New name##ScriptNewName',
      @fScriptEditor.NewScriptName[0], SizeOf(fScriptEditor.NewScriptName));
    ImGui.PopItemWidth;

    ButtonWidth := (ImGui.GetContentRegionAvail.x - Style^.ItemSpacing.x) * 0.5;
    if ImGui.Button('Add Script##ScriptAdd', ImVec2.New(ButtonWidth, 0)) then
      AddNewScriptFromEditor;

    ImGui.SameLine;
    if ImGui.Button('Delete Script##ScriptDelete', ImVec2.New(ButtonWidth, 0)) then
      DeleteSelectedScript;

    ImGui.Separator;

    if ImGui.BeginListBox('##ScriptAssetList', ImVec2.New(-1, 190)) then
    begin
      for I := 0 to fScriptManager.Count - 1 do
      begin
        Script := fScriptManager.Script[I];
        Selected := I = fScriptEditor.SelectedIndex;
        LabelText := Script.Name + '##ScriptAsset' + IntToStr(I);
        if ImGui.Selectable(PAnsiChar(AnsiString(LabelText)), Selected) then
          SelectScriptIndex(I);

        if Selected then
          ImGui.SetItemDefaultFocus;
      end;
      ImGui.EndListBox;
    end;

    ImGui.Separator;
    ImGui.TextWrapped('Whole library');
    ImGui.PushItemWidth(-1);
    ImGui.InputText('File##ScriptLibraryFile',
      @fScriptEditor.LibraryFileName[0], SizeOf(fScriptEditor.LibraryFileName));
    ImGui.PopItemWidth;

    ButtonWidth := (ImGui.GetContentRegionAvail.x - Style^.ItemSpacing.x) * 0.5;
    if ImGui.Button('Save Library##ScriptSaveLibrary', ImVec2.New(ButtonWidth, 0)) then
      SaveLibraryClicked;

    ImGui.SameLine;
    if ImGui.Button('Load Library##ScriptLoadLibrary', ImVec2.New(ButtonWidth, 0)) then
      LoadScriptLibraryFromFile(AnsiBufferText(fScriptEditor.LibraryFileName));

    ImGui.Separator;
    ImGui.TextWrapped('Current script');
    ImGui.PushItemWidth(-1);
    ImGui.InputText('File##ScriptAssetFile',
      @fScriptEditor.AssetFileName[0], SizeOf(fScriptEditor.AssetFileName));
    ImGui.PopItemWidth;

    ButtonWidth := (ImGui.GetContentRegionAvail.x - Style^.ItemSpacing.x) * 0.5;
    if ImGui.Button('Save Asset##ScriptSaveAsset', ImVec2.New(ButtonWidth, 0)) then
      SaveAssetClicked;

    ImGui.SameLine;
    if ImGui.Button('Load##ScriptLoadAsset', ImVec2.New(ButtonWidth, 0)) then
      LoadFileClicked;

    ImGui.Separator;
    ImGui.TextWrapped('Files');
    if ImGui.Button('Refresh Files##ScriptRefreshFiles', ImVec2.New(-1, 0)) then
      RefreshScriptFileList;

    ImGui.PushItemWidth(-1);
    ImGui.InputText('Search##ScriptFileSearch',
      @fScriptEditor.Search[0], SizeOf(fScriptEditor.Search));
    ImGui.PopItemWidth;

    SearchText := LowerCase(AnsiBufferText(fScriptEditor.Search));
    if ImGui.BeginListBox('##ScriptFileList', ImVec2.New(-1, 140)) then
    begin
      for I := 0 to High(fScriptEditor.Files) do
      begin
        FileItem := fScriptEditor.Files[I];
        if FileItem.Kind = sfkLibrary then
          KindText := 'Library'
        else
          KindText := 'Asset';

        if (SearchText <> '') and
           (Pos(SearchText, LowerCase(FileItem.DisplayName)) = 0) and
           (Pos(SearchText, LowerCase(FileItem.RelativePath)) = 0) and
           (Pos(SearchText, LowerCase(KindText)) = 0) then
          Continue;

        Selected := I = fScriptEditor.SelectedFileIndex;
        LabelText := Format('%s [%s]##ScriptFile%d',
          [FileItem.DisplayName, KindText, I]);
        if ImGui.Selectable(PAnsiChar(AnsiString(LabelText)), Selected) then
        begin
          fScriptEditor.SelectedFileIndex := I;
          SetAnsiBuffer(fScriptEditor.LibraryFileName, FileItem.RelativePath);
          SetAnsiBuffer(fScriptEditor.AssetFileName, FileItem.RelativePath);
        end;

        if Selected then
          ImGui.SetItemDefaultFocus;
      end;
      ImGui.EndListBox;
    end;

    if fScriptEditor.PendingOverwrite then
    begin
      DrawOverwriteConfirmation(fScriptEditor.PendingOverwriteFileName,
        'Script file', 'ScriptEditor', ReplaceClicked, CancelClicked);
      if ReplaceClicked then
      begin
        case fScriptEditor.PendingOverwriteKind of
          sowLibrary:
            SaveScriptLibraryToFile(fScriptEditor.PendingOverwriteFileName);
          sowAsset:
            SaveSelectedScriptAssetToFile(fScriptEditor.PendingOverwriteFileName);
        end;
      end
      else if CancelClicked then
      begin
        fScriptEditor.PendingOverwrite := False;
        fScriptEditor.PendingOverwriteKind := sowNone;
        fScriptEditor.PendingOverwriteFileName := '';
      end;
    end;
  end;
  ImGui.EndChild;

  ImGui.SameLine;

  if ImGui.BeginChild('ScriptEditorPane', ImVec2.New(0, -1)) then
  begin
    Script := SelectedScriptAsset;
    if Script = nil then
    begin
      ResetScriptSourceEditorTracking;
      ImGui.TextWrapped('Create or load a script to edit it here.');
      ImGui.EndChild;
      fShowScriptEditor := OpenWindow;
      ImGui.End_;
      Exit;
    end;

    ImGui.Text(PAnsiChar(AnsiString('Selected: ' + Script.Name)));
    if Script.RuntimeTarget <> nil then
      ImGui.Text(PAnsiChar(AnsiString('Resolved target: ' +
        Script.RuntimeTarget.ClassName)))
    else if Script.TargetKind = stkGlobal then
      ImGui.Text('Resolved target: global')
    else
      ImGui.Text('Resolved target: not found yet');

    B := Script.Enabled;
    if ImGui.Checkbox('Enabled##ScriptEnabled', @B) then
    begin
      Script.Enabled := B;
      Script.Touch;
      fScriptManager.ResetRuntimeState;
    end;

    ImGui.PushItemWidth(-1);
    if ImGui.InputText('Name##ScriptName', @fScriptEditor.Name[0],
      SizeOf(fScriptEditor.Name)) then
      fScriptEditor.Dirty := True;
    if ImGui.InputText('Description##ScriptDescription',
      @fScriptEditor.Description[0], SizeOf(fScriptEditor.Description)) then
      fScriptEditor.Dirty := True;
    if ImGui.InputText('Author##ScriptAuthor', @fScriptEditor.Author[0],
      SizeOf(fScriptEditor.Author)) then
      fScriptEditor.Dirty := True;
    if ImGui.InputText('Category##ScriptCategory',
      @fScriptEditor.Category[0], SizeOf(fScriptEditor.Category)) then
      fScriptEditor.Dirty := True;
    if ImGui.InputText('Version##ScriptVersion',
      @fScriptEditor.VersionText[0], SizeOf(fScriptEditor.VersionText)) then
      fScriptEditor.Dirty := True;
    if ImGui.InputText('Entry point##ScriptEntryPoint',
      @fScriptEditor.EntryPoint[0], SizeOf(fScriptEditor.EntryPoint)) then
      fScriptEditor.Dirty := True;
    ImGui.PopItemWidth;

    ImGui.Text(PAnsiChar(AnsiString('Created: ' +
      FormatDateTime('yyyy-mm-dd hh:nn:ss', Script.CreatedAt))));
    ImGui.Text(PAnsiChar(AnsiString('Modified: ' +
      FormatDateTime('yyyy-mm-dd hh:nn:ss', Script.ModifiedAt))));

    ImGui.Separator;
    ImGui.Text('Target');
    KindValue := Ord(Script.TargetKind);
    if ImGui.RadioButton('Global##ScriptTargetKind', @KindValue,
      Ord(stkGlobal)) then
      Script.TargetKind := stkGlobal;
    ImGui.SameLine;
    if ImGui.RadioButton('Object##ScriptTargetKind', @KindValue,
      Ord(stkSceneObject)) then
      Script.TargetKind := stkSceneObject;
    ImGui.SameLine;
    if ImGui.RadioButton('Shader##ScriptTargetKind', @KindValue,
      Ord(stkShader)) then
      Script.TargetKind := stkShader;
    ImGui.SameLine;
    if ImGui.RadioButton('Material##ScriptTargetKind', @KindValue,
      Ord(stkMaterial)) then
      Script.TargetKind := stkMaterial;

    KindValue := Ord(Script.TargetKind);
    if ImGui.RadioButton('Render Technique##ScriptTargetKind', @KindValue,
      Ord(stkRenderTechnique)) then
      Script.TargetKind := stkRenderTechnique;

    ImGui.PushItemWidth(-1);
    if ImGui.InputText('Target name##ScriptTargetName',
      @fScriptEditor.TargetName[0], SizeOf(fScriptEditor.TargetName)) then
      fScriptEditor.Dirty := True;
    ImGui.PopItemWidth;

    if ImGui.Button('Use Selected Object as Target##ScriptUseObject') then
    begin
      if (fSelectedObject <> nil) and (not fSelectedObject.IsGizmo) then
      begin
        Script.TargetKind := stkSceneObject;
        SetAnsiBuffer(fScriptEditor.TargetName,
          BuildSceneObjectPath(fSelectedObject));
        SyncSelectedScriptFromEditor;
        fScriptEditor.Status := 'Script target set to selected object.';
        fScriptEditor.LastError := '';
      end
      else
        fScriptEditor.LastError := 'Select a scene object first.';
    end;

    ImGui.SameLine;
    ImGui.Text(PAnsiChar(AnsiString('Mode: ' +
      ScriptTargetKindDisplayName(Script.TargetKind))));

    ImGui.Separator;
    ImGui.Text('Source');
    if ImGui.InputTextMultiline(PAnsiChar(AnsiString('Source##ScriptSource')),
      @fScriptEditor.Source[0], SizeOf(fScriptEditor.Source),
      ImVec2.New(-1, 250), ImGuiInputTextFlags_AllowTabInput, nil, nil) then
      fScriptEditor.Dirty := True;

    SourceActive := ImGui.IsItemActive;
    SourceRectMin := ImGui.GetItemRectMin;
    SourceRectMax := ImGui.GetItemRectMax;
    fScriptEditor.SourceEditorActive := SourceActive;
    fScriptEditor.SourceEditorHovered := ImGui.IsItemHovered;
    fScriptEditor.SourceRectMinX := SourceRectMin.x;
    fScriptEditor.SourceRectMinY := SourceRectMin.y;
    fScriptEditor.SourceRectMaxX := SourceRectMax.x;
    fScriptEditor.SourceRectMaxY := SourceRectMax.y;

    if fScriptEditor.Dirty then
      ImGui.TextWrapped('Unsaved editor changes. Apply, Compile, Run, or Save will sync them.');

    ImGui.TextWrapped(
      'Apply syncs editor changes. Compile validates the script. Run enables it and executes the entry point once; Pause disables it.');

    if ImGui.Button('Apply##ScriptApply') then
    begin
      SyncSelectedScriptFromEditor;
      fScriptEditor.Status := 'Script changes applied.';
      fScriptEditor.LastError := '';
    end;

    ImGui.SameLine;
    if ImGui.Button('Compile##ScriptCompile') then
    begin
      SyncSelectedScriptFromEditor;
      BindScriptEngine;
      CompileResult := fScriptManager.CompileScript(SelectedScriptAsset);
      if CompileResult.Success then
      begin
        fScriptEditor.Status := 'Script compiled successfully.';
        fScriptEditor.LastError := '';
      end
      else
      begin
        fScriptEditor.Status := 'Script compile failed.';
        fScriptEditor.LastError := CompileResult.Messages;
      end;
      LogLine(fScriptEditor.Status);
    end;

    ImGui.SameLine;
    if Script.Enabled then
      RunButtonText := 'Pause##ScriptRun'
    else
      RunButtonText := 'Run##ScriptRun';

    if ImGui.Button(PAnsiChar(AnsiString(RunButtonText))) then
    begin
      if Script.Enabled then
      begin
        Script.Enabled := False;
        Script.Touch;
        fScriptManager.ResetRuntimeState;
        fScriptEditor.Status := 'Script paused.';
        fScriptEditor.LastError := '';
        LogLine(fScriptEditor.Status);
      end
      else
      begin
        SyncSelectedScriptFromEditor;
        SelectedScriptAsset.Enabled := True;
        SelectedScriptAsset.Touch;
        BindScriptEngine;
        CompileResult := fScriptManager.ExecuteScript(SelectedScriptAsset,
          'EditorRun');
        if CompileResult.Success then
        begin
          fScriptEditor.Status := 'Script enabled and executed successfully.';
          fScriptEditor.LastError := '';
        end
        else
        begin
          fScriptEditor.Status := 'Script enabled, but execution failed.';
          fScriptEditor.LastError := CompileResult.Messages;
        end;
        LogLine(fScriptEditor.Status);
      end;
    end;

    if fScriptEditor.Status <> '' then
    begin
      ImGui.Separator;
      ImGui.TextWrapped(PAnsiChar(AnsiString(fScriptEditor.Status)));
    end;

    if fScriptEditor.LastError <> '' then
      ImGui.TextWrapped(PAnsiChar(AnsiString(fScriptEditor.LastError)));
  end;
  ImGui.EndChild;

  fShowScriptEditor := OpenWindow;
  ImGui.End_;
end;

procedure TSandBoxForm.DrawImGuiPostEffects;
var
  OpenWindow: Boolean;
  B: Boolean;
  F: Single;
  I: Integer;
  Mode: TToneMappingMode;
  Selected: Boolean;
  LabelText: string;
  Changed: Boolean;
begin
  if (not fShowPostEffects) or (fRenderer = nil) then
    Exit;

  ImGui.SetNextWindowPos(ImVec2.New(360, 98), ImGuiCond_FirstUseEver);
  ImGui.SetNextWindowSize(ImVec2.New(360, 520), ImGuiCond_FirstUseEver);

  OpenWindow := True;
  if not ImGui.Begin_('Post Effects', @OpenWindow) then
  begin
    fShowPostEffects := OpenWindow;
    ImGui.End_;
    Exit;
  end;

  Changed := False;

  B := fRenderer.HDREnabled;
  if ImGui.Checkbox('HDR tone mapping', @B) then
  begin
    fRenderer.HDREnabled := B;
    Changed := True;
  end;

  if fRenderer.HDRPostProcessActive then
    ImGui.Text(PAnsiChar(AnsiString('Active tone mapper: ' +
      ToneMappingModeDisplayName(fRenderer.ToneMappingMode))))
  else
    ImGui.Text('Post pass is off.');

  if ImGui.BeginListBox('##ToneMappingModes', ImVec2.New(-1, 180)) then // -1, 118
  begin
    for Mode := Low(TToneMappingMode) to High(TToneMappingMode) do
    begin
      Selected := Mode = fRenderer.ToneMappingMode;
      LabelText := Format('%s##tonemap%d',
        [ToneMappingModeDisplayName(Mode), Ord(Mode)]);
      if ImGui.Selectable(PAnsiChar(AnsiString(LabelText)), Selected) then
      begin
        fRenderer.ToneMappingMode := Mode;
        Changed := True;
      end;
    end;
    ImGui.EndListBox;
  end;

  F := fRenderer.ToneExposure;
  if ImGui.DragFloat('Exposure', @F, 0.01, 0.0, 16.0, '%.2f') then
  begin
    fRenderer.ToneExposure := System.Math.EnsureRange(F, 0.0, 16.0);
    Changed := True;
  end;

  F := fRenderer.ToneGamma;
  if ImGui.DragFloat('Output gamma', @F, 0.01, 0.1, 5.0, '%.2f') then
  begin
    fRenderer.ToneGamma := System.Math.EnsureRange(F, 0.1, 5.0);
    Changed := True;
  end;

  ImGui.Separator;

  B := fRenderer.GodRaysEnabled;
  if ImGui.Checkbox('Screen Space God Rays', @B) then
  begin
    fRenderer.GodRaysEnabled := B;
    if B then
      fRenderer.HDREnabled := True;
    Changed := True;
  end;

  if fRenderer.GodRaysEnabled and (not fRenderer.HDRPostProcessActive) then
    ImGui.TextWrapped('God rays use the HDR post pass; load the post-process shader to render them.');

  I := fRenderer.GodRaySamples;
  if ImGui.DragInt('Ray samples', @I, 1.0, 1, 128, '%d',
    ImGuiSliderFlags_None) then
  begin
    fRenderer.GodRaySamples := System.Math.EnsureRange(I, 1, 128);
    Changed := True;
  end;

  F := fRenderer.GodRayDensity;
  if ImGui.DragFloat('Ray density', @F, 0.01, 0.0, 3.0, '%.2f') then
  begin
    fRenderer.GodRayDensity := System.Math.EnsureRange(F, 0.0, 3.0);
    Changed := True;
  end;

  F := fRenderer.GodRayExposure;
  if ImGui.DragFloat('Ray exposure', @F, 0.01, 0.0, 4.0, '%.2f') then
  begin
    fRenderer.GodRayExposure := System.Math.EnsureRange(F, 0.0, 4.0);
    Changed := True;
  end;

  F := fRenderer.GodRayDecay;
  if ImGui.DragFloat('Ray decay', @F, 0.005, 0.0, 1.0, '%.3f') then
  begin
    fRenderer.GodRayDecay := System.Math.EnsureRange(F, 0.0, 1.0);
    Changed := True;
  end;

  F := fRenderer.GodRayWeight;
  if ImGui.DragFloat('Ray weight', @F, 0.01, 0.0, 2.0, '%.2f') then
  begin
    fRenderer.GodRayWeight := System.Math.EnsureRange(F, 0.0, 2.0);
    Changed := True;
  end;

  F := fRenderer.GodRayIntensity;
  if ImGui.DragFloat('Ray intensity', @F, 0.01, 0.0, 8.0, '%.2f') then
  begin
    fRenderer.GodRayIntensity := System.Math.EnsureRange(F, 0.0, 8.0);
    Changed := True;
  end;

  if Changed then
    RequestRender;

  fShowPostEffects := OpenWindow;
  ImGui.End_;
end;

procedure TSandBoxForm.DrawImGuiSkyDome;
var
  OpenWindow: Boolean;
  Sky: TSkyDome;
  B: Boolean;
  I: Integer;
  F: Single;
  V2: array[0..1] of Single;
  V3: array[0..2] of Single;
  ColorValue: TVector4;
  Changed: Boolean;

  function EditColor4(const LabelText: string; const Value: TVector4;
    out NewValue: TVector4): Boolean;
  var
    C: array[0..3] of Single;
  begin
    C[0] := Value.X;
    C[1] := Value.Y;
    C[2] := Value.Z;
    C[3] := Value.W;
    Result := ImGui.ColorEdit4(PAnsiChar(AnsiString(LabelText)), @C[0],
      ImGuiColorEditFlags_None);
    if Result then
      NewValue := Vector4(C[0], C[1], C[2], C[3])
    else
      NewValue := Value;
  end;

begin
  if (not fShowSkyDome) or (fRenderer = nil) then
    Exit;

  ImGui.SetNextWindowPos(ImVec2.New(735, 98), ImGuiCond_FirstUseEver);
  ImGui.SetNextWindowSize(ImVec2.New(390, 610), ImGuiCond_FirstUseEver);

  OpenWindow := True;
  if not ImGui.Begin_('SkyDome', @OpenWindow) then
  begin
    fShowSkyDome := OpenWindow;
    ImGui.End_;
    Exit;
  end;

  Changed := False;

  if fRenderer.SkyDome = nil then
  begin
    if ImGui.Button('Create SkyDome') then
    begin
      fRenderer.SkyDome := TSkyDome.Create;
      Changed := True;
    end;

    if Changed then
      RequestRender;
    fShowSkyDome := OpenWindow;
    ImGui.End_;
    Exit;
  end;

  Sky := fRenderer.SkyDome;

  B := Sky.Enabled;
  if ImGui.Checkbox('Enabled', @B) then
  begin
    Sky.Enabled := B;
    Changed := True;
  end;

  ImGui.SameLine;
  if ImGui.Button('Reset Earth Defaults') then
  begin
    Sky.ResetEarthDefaults;
    Changed := True;
  end;

  if ImGui.CollapsingHeader('Geometry', ImGuiTreeNodeFlags_DefaultOpen) then
  begin
    ImGui.PushItemWidth(IMGUI_PROP_SCALAR_WIDTH);
    F := Sky.Radius;
    if ImGui.DragFloat('Radius', @F, 1.0, 1.0, 100000.0, '%.1f') then
    begin
      Sky.Radius := System.Math.Max(1.0, F);
      Changed := True;
    end;

    I := Sky.Slices;
    if ImGui.DragInt('Slices', @I, 1.0, 8, 512, '%d',
      ImGuiSliderFlags_None) then
    begin
      Sky.Slices := I;
      Changed := True;
    end;

    I := Sky.Stacks;
    if ImGui.DragInt('Stacks', @I, 1.0, 4, 256, '%d',
      ImGuiSliderFlags_None) then
    begin
      Sky.Stacks := I;
      Changed := True;
    end;
    ImGui.PopItemWidth;
  end;

  if ImGui.CollapsingHeader('Sky Colors', ImGuiTreeNodeFlags_DefaultOpen) then
  begin
    if EditColor4('Top color', Sky.TopColor, ColorValue) then
    begin
      Sky.TopColor := ColorValue;
      Changed := True;
    end;

    if EditColor4('Horizon color', Sky.HorizonColor, ColorValue) then
    begin
      Sky.HorizonColor := ColorValue;
      Changed := True;
    end;

    if EditColor4('Bottom color', Sky.BottomColor, ColorValue) then
    begin
      Sky.BottomColor := ColorValue;
      Changed := True;
    end;

    if EditColor4('Night color', Sky.NightColor, ColorValue) then
    begin
      Sky.NightColor := ColorValue;
      Changed := True;
    end;
  end;

  if ImGui.CollapsingHeader('Fog', ImGuiTreeNodeFlags_DefaultOpen) then
  begin
    B := fRenderer.FogEnabled;
    if ImGui.Checkbox('Fog enabled', @B) then
    begin
      fRenderer.FogEnabled := B;
      Changed := True;
    end;

    ImGui.SameLine;
    if ImGui.Button('Match horizon') then
    begin
      fRenderer.FogColor := Vector4(Sky.HorizonColor.X, Sky.HorizonColor.Y,
        Sky.HorizonColor.Z, fRenderer.FogColor.W);
      Changed := True;
    end;

    if EditColor4('Fog color', fRenderer.FogColor, ColorValue) then
    begin
      fRenderer.FogColor := ColorValue;
      Changed := True;
    end;

    ImGui.PushItemWidth(IMGUI_PROP_SCALAR_WIDTH);
    F := fRenderer.FogDensity;
    if ImGui.DragFloat('Fog density', @F, 0.00005, 0.0, 1.0, '%.6f') then
    begin
      fRenderer.FogDensity := System.Math.EnsureRange(F, 0.0, 1.0);
      Changed := True;
    end;

    F := fRenderer.FogStart;
    if ImGui.DragFloat('Fog start', @F, 1.0, 0.0, 100000.0, '%.1f') then
    begin
      fRenderer.FogStart := System.Math.Max(0.0, F);
      if fRenderer.FogEnd < fRenderer.FogStart then
        fRenderer.FogEnd := fRenderer.FogStart;
      Changed := True;
    end;

    F := fRenderer.FogEnd;
    if ImGui.DragFloat('Fog end', @F, 1.0, 0.0, 100000.0, '%.1f') then
    begin
      fRenderer.FogEnd := System.Math.Max(fRenderer.FogStart, F);
      Changed := True;
    end;
    ImGui.PopItemWidth;
  end;

  if ImGui.CollapsingHeader('Sun', ImGuiTreeNodeFlags_DefaultOpen) then
  begin
    V3[0] := Sky.SunDirection.X;
    V3[1] := Sky.SunDirection.Y;
    V3[2] := Sky.SunDirection.Z;
    ImGui.PushItemWidth(IMGUI_PROP_VECTOR3_WIDTH);
    if ImGui.DragFloat3('Direction', @V3[0], 0.01, -1.0, 1.0, '%.3f') then
    begin
      Sky.SunDirection := Vector3(V3[0], V3[1], V3[2]);
      Changed := True;
    end;
    ImGui.PopItemWidth;

    if EditColor4('Sun color', Sky.SunColor, ColorValue) then
    begin
      Sky.SunColor := ColorValue;
      Changed := True;
    end;

    ImGui.PushItemWidth(IMGUI_PROP_SCALAR_WIDTH);
    F := Sky.SunSize;
    if ImGui.DragFloat('Sun size', @F, 0.001, 0.001, 1.0, '%.3f') then
    begin
      Sky.SunSize := System.Math.Max(0.001, F);
      Changed := True;
    end;

    F := Sky.SunGlow;
    if ImGui.DragFloat('Sun glow', @F, 0.25, 1.0, 256.0, '%.2f') then
    begin
      Sky.SunGlow := System.Math.Max(1.0, F);
      Changed := True;
    end;

    F := Sky.SunIntensity;
    if ImGui.DragFloat('Sun intensity', @F, 0.01, 0.0, 64.0, '%.2f') then
    begin
      Sky.SunIntensity := System.Math.Max(0.0, F);
      Changed := True;
    end;
    ImGui.PopItemWidth;
  end;

  if ImGui.CollapsingHeader('Stars', ImGuiTreeNodeFlags_DefaultOpen) then
  begin
    B := Sky.TwinkleStars;
    if ImGui.Checkbox('Twinkle stars', @B) then
    begin
      Sky.TwinkleStars := B;
      Changed := True;
    end;

    ImGui.PushItemWidth(IMGUI_PROP_SCALAR_WIDTH);
    F := Sky.StarIntensity;
    if ImGui.DragFloat('Star intensity', @F, 0.01, 0.0, 64.0, '%.2f') then
    begin
      Sky.StarIntensity := System.Math.Max(0.0, F);
      Changed := True;
    end;

    F := Sky.StarDensity;
    if ImGui.DragFloat('Star density', @F, 1.0, 8.0, 5000.0, '%.0f') then
    begin
      Sky.StarDensity := System.Math.Max(8.0, F);
      Changed := True;
    end;

    F := Sky.StarGlare;
    if ImGui.DragFloat('Star glare', @F, 0.01, 0.0, 8.0, '%.2f') then
    begin
      Sky.StarGlare := System.Math.Max(0.0, F);
      Changed := True;
    end;

    V2[0] := Sky.StarSize.X;
    V2[1] := Sky.StarSize.Y;
    if ImGui.DragFloat2('Star size', @V2[0], 0.001, 0.001, 1.0, '%.3f') then
    begin
      Sky.StarSize := Vector2(V2[0], V2[1]);
      Changed := True;
    end;
    ImGui.PopItemWidth;
  end;

  if ImGui.CollapsingHeader('Clouds', ImGuiTreeNodeFlags_DefaultOpen) then
  begin
    B := Sky.CloudsEnabled;
    if ImGui.Checkbox('Clouds enabled', @B) then
    begin
      Sky.CloudsEnabled := B;
      Changed := True;
    end;

    B := Sky.AnimateClouds;
    if ImGui.Checkbox('Animate clouds', @B) then
    begin
      Sky.AnimateClouds := B;
      Changed := True;
    end;

    if EditColor4('Cloud color', Sky.CloudColor, ColorValue) then
    begin
      Sky.CloudColor := ColorValue;
      Changed := True;
    end;

    ImGui.PushItemWidth(IMGUI_PROP_SCALAR_WIDTH);
    F := Sky.CloudCoverage;
    if ImGui.DragFloat('Coverage', @F, 0.01, 0.0, 1.0, '%.2f') then
    begin
      Sky.CloudCoverage := System.Math.EnsureRange(F, 0.0, 1.0);
      Changed := True;
    end;

    F := Sky.CloudScale;
    if ImGui.DragFloat('Scale', @F, 0.01, 0.01, 32.0, '%.2f') then
    begin
      Sky.CloudScale := System.Math.Max(0.01, F);
      Changed := True;
    end;

    F := Sky.CloudSpeed;
    if ImGui.DragFloat('Speed', @F, 0.001, -8.0, 8.0, '%.3f') then
    begin
      Sky.CloudSpeed := F;
      Changed := True;
    end;

    F := Sky.CloudOpacity;
    if ImGui.DragFloat('Opacity', @F, 0.01, 0.0, 1.0, '%.2f') then
    begin
      Sky.CloudOpacity := System.Math.EnsureRange(F, 0.0, 1.0);
      Changed := True;
    end;

    F := Sky.Time;
    if ImGui.DragFloat('Time', @F, 0.01, 0.0, 1000000.0, '%.2f') then
    begin
      Sky.Time := System.Math.Max(0.0, F);
      Changed := True;
    end;
    ImGui.PopItemWidth;
  end;

  if Changed then
    RequestRender;

  fShowSkyDome := OpenWindow;
  ImGui.End_;
end;

procedure TSandBoxForm.DrawImGuiRenderTextureTool;
var
  OpenWindow: Boolean;
  IntValue: Integer;
  MaxSamples: Integer;
  OutputFileName: string;
begin
  if not fRenderTextureTool.Active then
    Exit;

  ImGui.SetNextWindowPos(ImVec2.New(735, 98), ImGuiCond_FirstUseEver);
  ImGui.SetNextWindowSize(ImVec2.New(400, 300), ImGuiCond_FirstUseEver);

  OpenWindow := True;
  if not ImGui.Begin_('Render Texture', @OpenWindow) then
  begin
    fRenderTextureTool.Active := OpenWindow;
    ImGui.End_;
    Exit;
  end;

  IntValue := fRenderTextureTool.Width;
  if InspectorInputInt('Width##RenderTexture', @IntValue, 64.0, 1, 16384,
    '%d', ImGuiSliderFlags_None) then
    fRenderTextureTool.Width := EnsureRange(IntValue, 1, 16384);

  IntValue := fRenderTextureTool.Height;
  if InspectorInputInt('Height##RenderTexture', @IntValue, 64.0, 1, 16384,
    '%d', ImGuiSliderFlags_None) then
    fRenderTextureTool.Height := EnsureRange(IntValue, 1, 16384);

  MaxSamples := 16;
  if fRenderer <> nil then
    MaxSamples := Max(1, fRenderer.MaxRenderTextureAntialiasingSamples);
  fRenderTextureTool.AntialiasingSamples :=
    EnsureRange(fRenderTextureTool.AntialiasingSamples, 1, MaxSamples);

  IntValue := fRenderTextureTool.AntialiasingSamples;
  if InspectorInputInt('Anti aliasing samples##RenderTexture', @IntValue, 1.0,
    1, MaxSamples, '%d', ImGuiSliderFlags_None) then
    fRenderTextureTool.AntialiasingSamples :=
      EnsureRange(IntValue, 1, MaxSamples);
  if MaxSamples < 2 then
    ImGui.Text('MSAA render textures are not supported by this context.')
  else
    ImGui.Text('1 disables anti aliasing.');

  ImGui.PushItemWidth(-1);
  ImGui.InputText('File name##RenderTexture',
    @fRenderTextureTool.FileName[0], SizeOf(fRenderTextureTool.FileName));
  ImGui.PopItemWidth;

  OutputFileName := ResolveGeneratedTextureFileName(
    AnsiBufferText(fRenderTextureTool.FileName));
  ImGui.TextWrapped(PAnsiChar(AnsiString('Output: ' + OutputFileName)));

  ImGui.Separator;
  if fRenderTextureTool.Pending then
    ImGui.Text('Capture queued...')
  else if ImGui.Button('Render and Save##RenderTexture') then
    QueueRenderTextureCapture;

  if fRenderTextureTool.LastOutputFileName <> '' then
    ImGui.TextWrapped(PAnsiChar(AnsiString('Saved: ' +
      fRenderTextureTool.LastOutputFileName)));

  if fRenderTextureTool.LastError <> '' then
    ImGui.TextWrapped(PAnsiChar(AnsiString('Error: ' +
      fRenderTextureTool.LastError)));

  fRenderTextureTool.Active := OpenWindow;
  ImGui.End_;
end;

function PhysicsBodyTypeDisplayName(AType: TPhysicsBodyType): string;
begin
  case AType of
    pbtStatic: Result := 'Static';
    pbtDynamic: Result := 'Dynamic';
    pbtKinematic: Result := 'Kinematic';
    pbtCharacter: Result := 'Character';
    pbtProjectile: Result := 'Projectile';
  else
    Result := 'Unknown';
  end;
end;

function PhysicsColliderKindDisplayName(AKind: TPhysicsColliderKind): string;
begin
  case AKind of
    pckAuto: Result := 'Auto';
    pckNone: Result := 'None';
    pckSphere: Result := 'Sphere';
    pckCapsule: Result := 'Capsule';
    pckAABB: Result := 'AABB';
    pckMesh: Result := 'Mesh';
    pckConvexHull: Result := 'Convex hull';
  else
    Result := 'Unknown';
  end;
end;

procedure TSandBoxForm.DrawImGuiPhysicsBodyEditor(Obj: TSceneObject; Compact: Boolean);
var
  Body: TPhysicsBody;
  State: TPhysicsBodyState;
  BodyTypeValue: Integer;
  ColliderValue: Integer;
  BodyType: TPhysicsBodyType;
  ColliderKind: TPhysicsColliderKind;
  BoolValue: Boolean;
  FloatValue: Single;
  VectorValue: array[0..2] of Single;
  Changed: Boolean;
  PendingState: Boolean;
begin
  if (Obj = nil) or Obj.IsGizmo then
    Exit;

  if Compact and
     (not ImGui.CollapsingHeader('Physics', ImGuiTreeNodeFlags_DefaultOpen)) then
    Exit;

  if fPhysicsWorld = nil then
    raise Exception.Create('The game engine physics world is not available.');
  fPhysicsWorld.SceneRoot := fRoot;

  ImGui.PushId(Pointer(Obj));
  try
    Body := fPhysicsWorld.FindBody(Obj);

    if Body = nil then
    begin
      ImGui.TextWrapped('No physics body on this object yet.');

      if ImGui.Button('Add Dynamic Body') then
      begin
        Body := fPhysicsWorld.AddBody(Obj, pbtDynamic, pckAuto);
        Body.Enabled := True;
        fPhysicsStatusMessage := 'Added dynamic physics body.';
        RequestRender;
      end;

      ImGui.SameLine;
      if ImGui.Button('Add Static Mesh Body') then
      begin
        if Obj.HasGeometry then
          Body := fPhysicsWorld.AddBody(Obj, pbtStatic, pckMesh)
        else
          Body := fPhysicsWorld.AddBody(Obj, pbtStatic, pckAABB);
        Body.Enabled := True;
        fPhysicsStatusMessage := 'Added static physics body.';
        RequestRender;
      end;

      if not Compact then
      begin
        ImGui.SameLine;
        if ImGui.Button('Add Kinematic Body') then
        begin
          Body := fPhysicsWorld.AddBody(Obj, pbtKinematic, pckAuto);
          Body.Enabled := True;
          fPhysicsStatusMessage := 'Added kinematic physics body.';
          RequestRender;
        end;
      end;

      Exit;
    end;

    PendingState := fPhysicsWorld.TryGetStagedBodyState(Obj, State);
    if not PendingState then
      State := Body.GetState;

    if PendingState then
      ImGui.TextWrapped('Pending changes: apply them or press Play/Reset to rebuild only what changed.');

    ImGui.Text(PAnsiChar(AnsiString('Body: ' +
      PhysicsBodyTypeDisplayName(State.BodyType) + ', ' +
      PhysicsColliderKindDisplayName(State.ColliderKind))));
    ImGui.Text(PAnsiChar(AnsiString(Format('Inverse mass: %.4f',
      [PhysicsInverseMassForState(State)]))));

    if ImGui.Button('Apply Body Changes') then
    begin
      fPhysicsWorld.ApplyStagedBodyStates;
      Body := fPhysicsWorld.FindBody(Obj);
      if Body <> nil then
        fPhysicsWorld.ResetBodyToSceneTransform(Body, True);
      fPhysicsStatusMessage := 'Physics body changes applied.';
      RequestRender;
    end;

    ImGui.SameLine;
    if ImGui.Button('Rebuild Collider Now') then
    begin
      fPhysicsWorld.ApplyStagedBodyStates;
      Body := fPhysicsWorld.FindBody(Obj);
      if Body <> nil then
      begin
        fPhysicsWorld.MarkBodyDirty(Body);
        fPhysicsWorld.EnsureNativeScene;
        fPhysicsWorld.ResetBodyToSceneTransform(Body, True);
      end;
      fPhysicsStatusMessage := 'Physics collider rebuilt.';
      RequestRender;
    end;

    ImGui.SameLine;
    if ImGui.Button('Remove Body') then
    begin
      fPhysicsWorld.RemoveBody(Body);
      fPhysicsStatusMessage := 'Removed physics body.';
      RequestRender;
      Exit;
    end;

    Changed := False;

    if ImGui.CollapsingHeader('Body Type', ImGuiTreeNodeFlags_DefaultOpen) then
    begin
      BodyTypeValue := Ord(State.BodyType);
      for BodyType := Low(TPhysicsBodyType) to High(TPhysicsBodyType) do
      begin
        if Ord(BodyType) > Ord(Low(TPhysicsBodyType)) then
          ImGui.SameLine;
        ImGui.RadioButton(PAnsiChar(AnsiString(PhysicsBodyTypeDisplayName(BodyType) +
          '##PhysicsBodyType' + IntToStr(Ord(BodyType)))),
          @BodyTypeValue, Ord(BodyType));
      end;
      if BodyTypeValue <> Ord(State.BodyType) then
      begin
        State.BodyType := TPhysicsBodyType(BodyTypeValue);
        Changed := True;
      end;
    end;

    if ImGui.CollapsingHeader('Collider', ImGuiTreeNodeFlags_DefaultOpen) then
    begin
      ColliderValue := Ord(State.ColliderKind);
      for ColliderKind := Low(TPhysicsColliderKind) to High(TPhysicsColliderKind) do
      begin
        if (Ord(ColliderKind) > Ord(Low(TPhysicsColliderKind))) and
           ((Ord(ColliderKind) mod 4) <> 0) then
          ImGui.SameLine;
        ImGui.RadioButton(PAnsiChar(AnsiString(PhysicsColliderKindDisplayName(ColliderKind) +
          '##PhysicsCollider' + IntToStr(Ord(ColliderKind)))),
          @ColliderValue, Ord(ColliderKind));
      end;
      if ColliderValue <> Ord(State.ColliderKind) then
      begin
        State.ColliderKind := TPhysicsColliderKind(ColliderValue);
        Changed := True;
      end;

      if ImGui.Button('Auto-fit from mesh bounds') then
      begin
        Body.AutoFitColliderFromScene;
        State.Radius := Body.Radius;
        State.HalfHeight := Body.HalfHeight;
        State.AABBHalfExtents := Body.AABBHalfExtents;
        Changed := True;
      end;

      ImGui.PushItemWidth(IMGUI_PROP_SCALAR_WIDTH);
      FloatValue := State.Radius;
      if InspectorInputFloat('Radius', @FloatValue, 0.01, 0.01, 100000, '%.3f') then
      begin
        State.Radius := System.Math.Max(0.01, FloatValue);
        Changed := True;
      end;

      FloatValue := State.HalfHeight;
      if InspectorInputFloat('Half height', @FloatValue, 0.01, 0.01, 100000, '%.3f') then
      begin
        State.HalfHeight := System.Math.Max(0.01, FloatValue);
        Changed := True;
      end;
      ImGui.PopItemWidth;

      VectorValue[0] := State.AABBHalfExtents.X;
      VectorValue[1] := State.AABBHalfExtents.Y;
      VectorValue[2] := State.AABBHalfExtents.Z;
      ImGui.PushItemWidth(IMGUI_PROP_VECTOR3_WIDTH);
      if InspectorInputFloat3('AABB half extents', @VectorValue[0], 0.01,
        0.01, 100000, '%.3f') then
      begin
        State.AABBHalfExtents := Vector3(
          System.Math.Max(0.01, VectorValue[0]),
          System.Math.Max(0.01, VectorValue[1]),
          System.Math.Max(0.01, VectorValue[2]));
        Changed := True;
      end;
      ImGui.PopItemWidth;

      ImGui.PushItemWidth(IMGUI_PROP_SCALAR_WIDTH);
      FloatValue := State.StepHeight;
      if InspectorInputFloat('Step height', @FloatValue, 0.01, 0.0, 100000, '%.3f') then
      begin
        State.StepHeight := System.Math.Max(0.0, FloatValue);
        Changed := True;
      end;
      ImGui.PopItemWidth;
    end;

    if ImGui.CollapsingHeader('Simulation', ImGuiTreeNodeFlags_DefaultOpen) then
    begin
      BoolValue := State.Enabled;
      if ImGui.Checkbox('Enabled', @BoolValue) then
      begin
        State.Enabled := BoolValue;
        Changed := True;
      end;

      BoolValue := State.CollisionResponse;
      if ImGui.Checkbox('Collision response', @BoolValue) then
      begin
        State.CollisionResponse := BoolValue;
        Changed := True;
      end;

      BoolValue := State.UseGravity;
      if ImGui.Checkbox('Use gravity', @BoolValue) then
      begin
        State.UseGravity := BoolValue;
        Changed := True;
      end;

      ImGui.PushItemWidth(IMGUI_PROP_SCALAR_WIDTH);
      FloatValue := State.Mass;
      if InspectorInputFloat('Mass', @FloatValue, 0.05, 0.0, 100000, '%.3f') then
      begin
        State.Mass := System.Math.Max(0.0, FloatValue);
        Changed := True;
      end;

      FloatValue := State.Restitution;
      if InspectorInputFloat('Restitution', @FloatValue, 0.01, 0.0, 10.0, '%.3f') then
      begin
        State.Restitution := System.Math.Max(0.0, FloatValue);
        Changed := True;
      end;

      FloatValue := State.LinearDamping;
      if InspectorInputFloat('Linear damping', @FloatValue, 0.01, 0.0, 1.0, '%.3f') then
      begin
        State.LinearDamping := System.Math.EnsureRange(FloatValue, 0.0, 1.0);
        Changed := True;
      end;

      FloatValue := State.GravityScale;
      if InspectorInputFloat('Gravity scale', @FloatValue, 0.01, -1000.0, 1000.0, '%.3f') then
      begin
        State.GravityScale := FloatValue;
        Changed := True;
      end;
      ImGui.PopItemWidth;

      VectorValue[0] := State.Velocity.X;
      VectorValue[1] := State.Velocity.Y;
      VectorValue[2] := State.Velocity.Z;
      ImGui.PushItemWidth(IMGUI_PROP_VECTOR3_WIDTH);
      if InspectorInputFloat3('Initial velocity', @VectorValue[0], 0.05,
        -100000, 100000, '%.3f') then
      begin
        State.Velocity := Vector3(VectorValue[0], VectorValue[1], VectorValue[2]);
        Changed := True;
      end;

      VectorValue[0] := State.AngularVelocity.X;
      VectorValue[1] := State.AngularVelocity.Y;
      VectorValue[2] := State.AngularVelocity.Z;
      if InspectorInputFloat3('Angular velocity', @VectorValue[0], 0.05,
        -100000, 100000, '%.3f') then
      begin
        State.AngularVelocity := Vector3(VectorValue[0], VectorValue[1], VectorValue[2]);
        Changed := True;
      end;
      ImGui.PopItemWidth;

      ImGui.PushItemWidth(IMGUI_PROP_SCALAR_WIDTH);
      FloatValue := State.AngularDamping;
      if InspectorInputFloat('Angular damping', @FloatValue, 0.01, 0.0, 1.0, '%.3f') then
      begin
        State.AngularDamping := System.Math.EnsureRange(FloatValue, 0.0, 1.0);
        Changed := True;
      end;
      ImGui.PopItemWidth;
    end;

    if Changed then
    begin
      fPhysicsWorld.StageBodyState(Obj, State);
      fPhysicsStatusMessage := 'Pending physics body changes.';
      RequestRender;
    end;
  finally
    ImGui.PopId;
  end;
end;

procedure TSandBoxForm.DrawImGuiPhysics;
var
  OpenWindow: Boolean;
  GravityValue: array[0..2] of Single;
  GroundNormalValue: array[0..2] of Single;
  FloatValue: Single;
  IntValue: Integer;
  BoolValue: Boolean;
  Changed: Boolean;
begin
  if not fShowPhysics then
    Exit;

  if fPhysicsWorld = nil then
    raise Exception.Create('The game engine physics world is not available.');
  fPhysicsWorld.SceneRoot := fRoot;

  ImGui.SetNextWindowPos(ImVec2.New(345, 130), ImGuiCond_FirstUseEver);
  ImGui.SetNextWindowSize(ImVec2.New(460, 680), ImGuiCond_FirstUseEver);

  OpenWindow := True;
  if not ImGui.Begin_('Physics', @OpenWindow) then
  begin
    fShowPhysics := OpenWindow;
    ImGui.End_;
    Exit;
  end;

  if fPhysicsRunning then
    ImGui.Text('Simulation: Running')
  else
    ImGui.Text('Simulation: Stopped / Paused');

  ImGui.Text(PAnsiChar(AnsiString(Format('Bodies: %d total, %d active dynamic',
    [fPhysicsWorld.BodyCount, fPhysicsWorld.ActiveSimulationBodyCount]))));

  if fPhysicsStatusMessage <> '' then
    ImGui.TextWrapped(PAnsiChar(AnsiString(fPhysicsStatusMessage)));

  if fPhysicsRunning then
  begin
    if ImGui.Button('Pause') then
      PausePhysicsSimulation;
  end
  else if ImGui.Button('Play') then
    StartPhysicsSimulation;

  ImGui.SameLine;
  if ImGui.Button('Stop') then
    StopPhysicsSimulation;

  ImGui.SameLine;
  if ImGui.Button('Reset') then
    ResetPhysicsSimulation;

  ImGui.SameLine;
  if ImGui.Button('Apply Pending') then
  begin
    fPhysicsWorld.ApplyStagedBodyStates;
    fPhysicsWorld.EnsureNativeScene;
    fPhysicsWorld.ResetBodiesToSceneTransforms(True);
    fPhysicsStatusMessage := 'Pending physics changes applied.';
    RequestRender;
  end;

  ImGui.Separator;

  if ImGui.CollapsingHeader('World Settings', ImGuiTreeNodeFlags_DefaultOpen) then
  begin
    Changed := False;

    GravityValue[0] := fPhysicsWorld.Gravity.X;
    GravityValue[1] := fPhysicsWorld.Gravity.Y;
    GravityValue[2] := fPhysicsWorld.Gravity.Z;
    ImGui.PushItemWidth(IMGUI_PROP_VECTOR3_WIDTH);
    if InspectorInputFloat3('Gravity', @GravityValue[0], 0.05,
      -1000, 1000, '%.3f') then
    begin
      fPhysicsWorld.Gravity := Vector3(GravityValue[0], GravityValue[1], GravityValue[2]);
      Changed := True;
    end;
    ImGui.PopItemWidth;

    ImGui.PushItemWidth(IMGUI_PROP_SCALAR_WIDTH);
    FloatValue := fPhysicsWorld.GlobalDamping;
    if InspectorInputFloat('Global damping', @FloatValue, 0.01, 0.0, 1.0, '%.3f') then
    begin
      fPhysicsWorld.GlobalDamping := System.Math.EnsureRange(FloatValue, 0.0, 1.0);
      Changed := True;
    end;

    FloatValue := fPhysicsWorld.MaxSubStep;
    if InspectorInputFloat('Fixed step', @FloatValue, 0.001, 1.0 / 1000.0,
      1.0 / 10.0, '%.5f') then
    begin
      fPhysicsWorld.MaxSubStep := System.Math.EnsureRange(FloatValue, 1.0 / 1000.0, 1.0 / 10.0);
      Changed := True;
    end;

    IntValue := fPhysicsWorld.MaxSubSteps;
    if InspectorInputInt('Max substeps', @IntValue, 1.0, 1, 64, '%d',
      ImGuiSliderFlags_None) then
    begin
      fPhysicsWorld.MaxSubSteps := System.Math.EnsureRange(IntValue, 1, 64);
      Changed := True;
    end;

    IntValue := fPhysicsWorld.SolverIterations;
    if InspectorInputInt('Solver iterations', @IntValue, 1.0, 1, 128, '%d',
      ImGuiSliderFlags_None) then
    begin
      fPhysicsWorld.SolverIterations := System.Math.EnsureRange(IntValue, 1, 128);
      Changed := True;
    end;

    FloatValue := fPhysicsWorld.CollisionSlop;
    if InspectorInputFloat('Collision slop', @FloatValue, 0.005, 0.0, 1.0, '%.3f') then
    begin
      fPhysicsWorld.CollisionSlop := System.Math.EnsureRange(FloatValue, 0.0, 1.0);
      Changed := True;
    end;
    ImGui.PopItemWidth;

    BoolValue := fPhysicsWorld.GroundPlaneEnabled;
    if ImGui.Checkbox('Ground plane enabled', @BoolValue) then
    begin
      fPhysicsWorld.GroundPlaneEnabled := BoolValue;
      Changed := True;
    end;

    ImGui.PushItemWidth(IMGUI_PROP_SCALAR_WIDTH);
    FloatValue := fPhysicsWorld.GroundHeight;
    if InspectorInputFloat('Ground height', @FloatValue, 0.05, -100000, 100000, '%.3f') then
    begin
      fPhysicsWorld.GroundHeight := FloatValue;
      Changed := True;
    end;
    ImGui.PopItemWidth;

    GroundNormalValue[0] := fPhysicsWorld.GroundNormal.X;
    GroundNormalValue[1] := fPhysicsWorld.GroundNormal.Y;
    GroundNormalValue[2] := fPhysicsWorld.GroundNormal.Z;
    ImGui.PushItemWidth(IMGUI_PROP_VECTOR3_WIDTH);
    if InspectorInputFloat3('Ground normal', @GroundNormalValue[0], 0.05,
      -1, 1, '%.3f') then
    begin
      fPhysicsWorld.GroundNormal := Vector3(GroundNormalValue[0],
        GroundNormalValue[1], GroundNormalValue[2]);
      Changed := True;
    end;
    ImGui.PopItemWidth;

    if Changed then
    begin
      fPhysicsStatusMessage := 'Physics world settings changed.';
      RequestRender;
    end;
  end;

  if ImGui.CollapsingHeader('Selected Object', ImGuiTreeNodeFlags_DefaultOpen) then
  begin
    if fSelectedObject = nil then
      ImGui.Text('No object selected.')
    else
    begin
      ImGui.Text(PAnsiChar(AnsiString('Selected: ' + fSelectedObject.Name)));
      DrawImGuiPhysicsBodyEditor(fSelectedObject, False);
    end;
  end;

  fShowPhysics := OpenWindow;
  ImGui.End_;
end;

procedure TSandBoxForm.DrawImGuiInspector;
var
  P, R, S: array[0..2] of Single;
  I: Integer;
  Mesh: TMesh;
  Meshes: TMeshList;
begin
  ImGui.SetNextWindowPos(ImVec2.New(EditorViewportWidth - 340, 58), ImGuiCond_FirstUseEver);
  ImGui.SetNextWindowSize(ImVec2.New(330, 600), ImGuiCond_FirstUseEver);

  if ImGui.Begin_('Inspector', nil) then
  begin
    if fSelectedObject = nil then
    begin
      ImGui.Text('No object selected.');
      ImGui.End_;
      Exit;
    end;

    ImGui.TextWrapped(PAnsiChar(AnsiString('Selected: ' + fSelectedObject.Name)));
    if ImGui.Button('Particle Editor##Inspector') then
      OpenParticleEditor;
    ImGui.SameLine;
    if ImGui.Button('Physics##Inspector') then
      fShowPhysics := True;

    DrawImGuiObjectProperties;

    ImGui.Separator;
    DrawImGuiAnimationProperties;

    ImGui.Separator;
    DrawImGuiWindProperties;

    ImGui.Separator;
    DrawImGuiLightProperties;

    ImGui.Separator;
    DrawImGuiBillboardProperties;

    ImGui.Separator;
    DrawImGuiAnimatedSpriteProperties;

    ImGui.Separator;
    DrawImGuiAudioProperties;

    ImGui.Separator;

    P[0] := fSelectedObject.Position.X;
    P[1] := fSelectedObject.Position.Y;
    P[2] := fSelectedObject.Position.Z;

    R[0] := RadToDeg(fSelectedObject.Rotation.X);
    R[1] := RadToDeg(fSelectedObject.Rotation.Y);
    R[2] := RadToDeg(fSelectedObject.Rotation.Z);

    S[0] := fSelectedObject.Scale.X;
    S[1] := fSelectedObject.Scale.Y;
    S[2] := fSelectedObject.Scale.Z;

    if ImGui.CollapsingHeader('Transform', ImGuiTreeNodeFlags_DefaultOpen) then
    begin
      ImGui.PushItemWidth(IMGUI_PROP_VECTOR3_WIDTH);
      if InspectorInputFloat3('Position', @P[0], 0.05, -100000, 100000,
        '%.2f') then
      begin
        fSelectedObject.Position := Vector3(P[0], P[1], P[2]);
        fSelectedObject.NotifyChange;
        if Assigned(fSceneManager) then
          fSceneManager.Update;
        RefreshGizmo;
        RequestRender;
      end;

      if InspectorInputFloat3('Rotation', @R[0], 0.25, -360, 360,
        '%.2f') then
      begin
        fSelectedObject.Rotation := Vector3(DegToRad(R[0]), DegToRad(R[1]), DegToRad(R[2]));
        fSelectedObject.NotifyChange;
        if Assigned(fSceneManager) then
          fSceneManager.Update;
        RefreshGizmo;
        RequestRender;
      end;

      if InspectorInputFloat3('Scale', @S[0], 0.05, 0.001, 100000,
        '%.2f') then
      begin
        fSelectedObject.Scale := Vector3(S[0], S[1], S[2]);
        fSelectedObject.NotifyChange;
        if Assigned(fSceneManager) then
          fSceneManager.Update;
        RefreshGizmo;
        RequestRender;
      end;
      ImGui.PopItemWidth;
    end;

    DrawImGuiPhysicsBodyEditor(fSelectedObject, True);

    if ImGui.CollapsingHeader('Meshes', ImGuiTreeNodeFlags_DefaultOpen) then
    begin
      Meshes := fSelectedObject.EffectiveMeshList;
      if (Meshes = nil) or (Meshes.Count = 0) then
        ImGui.Text('No meshes.');

      if ImGui.BeginListBox('##MeshList', ImVec2.New(-1, 120)) then
      begin
        if Assigned(Meshes) then
        for I := 0 to Meshes.Count - 1 do
        begin
          Mesh := Meshes.Item[I];
          if Mesh = nil then
            Continue;

          if ImGui.Selectable(PAnsiChar(AnsiString(Mesh.Name)), I = fSelectedMeshIndex) then
            SelectMeshIndex(I);
        end;
        ImGui.EndListBox;
      end;

      if fSelectedObject.IsInstance then
        ImGui.Text('Instance meshes are shared. Uncheck "Is instance" to make this object unique.')
      else
      begin
        if ImGui.Button('+ Mesh') then
          ImGui.OpenPopup('InspectorAddMeshPopup');

        if ImGui.BeginPopup('InspectorAddMeshPopup') then
        begin
          DrawAddMeshMenuItems;
          ImGui.EndPopup;
        end;

        ImGui.SameLine;
        if ImGui.Button('Delete Mesh') then
          DeleteSelectedMesh;
      end;

      if Assigned(fSelectedMesh) then
      begin
        if not fSelectedObject.IsInstance then
        begin
          ImGui.SameLine;
          if ImGui.Button('Edit Mesh') then
            BeginEditSelectedMeshFromImGui;
        end;

        ImGui.Text(PAnsiChar(AnsiString('Selected mesh: ' + fSelectedMesh.Name)));

        if (not fSelectedObject.IsInstance) and
           ImGui.Checkbox('Gizmo edits selected mesh', @fEditSelectedMeshTransform) then
        begin
          RefreshGizmo;
          RequestRender;
        end;

        DrawImGuiMeshProperties(fSelectedMesh);
        DrawImGuiMaterialAssignment;
      end;
    end;

  end;

  ImGui.End_;
end;

procedure TSandBoxForm.DrawImGuiLog;
var
  I: Integer;
  FirstLine: Integer;
begin
  if fLog = nil then
    Exit;

  ImGui.SetNextWindowPos(ImVec2.New(8, EditorViewportHeight - 210), ImGuiCond_FirstUseEver);
  ImGui.SetNextWindowSize(ImVec2.New(560, 190), ImGuiCond_FirstUseEver);

  if ImGui.Begin_('Log', nil) then
  begin
    FirstLine := System.Math.Max(0, fLog.Count - 80);
    for I := FirstLine to fLog.Count - 1 do
      ImGui.Text(PAnsiChar(AnsiString(fLog[I])));
  end;

  ImGui.End_;
end;

procedure TSandBoxForm.DrawImGuiMaterialEditor;
var
  OpenWindow: Boolean;
  OpenAddLibraryPopup: Boolean;
  OpenAddMaterialPopup: Boolean;
  Lib: TMaterialLibrary;
  Mat: TMaterial;
  Tex: TMaterialTexture;
  TextureIndex: Integer;
  I: Integer;
  LabelText: string;
  Params: TMaterialShaderParameters;
  Selected: Boolean;
  Texture: ImTextureID;
  DiffuseColor: array[0..2] of Single;
  SpecularColor: array[0..2] of Single;
  Shininess: Single;
  MaterialType: TMaterialType;
  NewName: string;
  SearchText: string;
  TextureItem: TTextureAssetInfo;
  TexturePanelsHeight: Single;
  LayerLimit: Integer;
begin
  if not fMaterialEditor.Active then
    Exit;

  EnsureMaterialEditorSelection;
  if fTextureBrowser.NeedsRefresh then
    RefreshTextureBrowserList;

  ImGui.SetNextWindowPos(ImVec2.New(295, 58), ImGuiCond_FirstUseEver);
  ImGui.SetNextWindowSize(ImVec2.New(980, 690), ImGuiCond_FirstUseEver);

  OpenWindow := True;
  OpenAddLibraryPopup := False;
  OpenAddMaterialPopup := False;
  if ImGui.Begin_('Material Editor', @OpenWindow) then
  begin
    if ImGui.BeginChild('MaterialSidebarPane', ImVec2.New(220, -1)) then //320
    begin
      if ImGui.BeginChild('MaterialLibrariesPane', ImVec2.New(-1, 400)) then //250
      begin
        ImGui.Text('Material Libraries');
        if ImGui.Button('Add##MaterialLibrary') then
          OpenAddLibraryPopup := True;

        ImGui.SameLine;
        if ImGui.Button('Delete##MaterialLibrary') then
        begin
          if fMaterialEditor.SelectedLibraryIndex >= 0 then
            DeleteMaterialLibraryAt(fMaterialEditor.SelectedLibraryIndex);
        end;

        if ImGui.Button('Load##MaterialLibrary') then
          OpenMaterialFileBrowser(mfbLoadLibrary);

        ImGui.SameLine;
        if ImGui.Button('Save##MaterialLibrary') then
          OpenMaterialFileBrowser(mfbSaveLibrary);

        ImGui.Separator;
        if ImGui.BeginListBox('##MaterialLibraryList', ImVec2.New(-1, -1)) then
        begin
          if MaterialLibraries <> nil then
            for I := 0 to MaterialLibraries.Count - 1 do
            begin
              Lib := MaterialLibraries.MaterialLibrary[I];
              if Lib = nil then
                Continue;

              LabelText := Format('%s (%d)##lib%d',
                [MaterialLibraryDisplayName(Lib, I), Lib.Count, I]);
              Selected := I = fMaterialEditor.SelectedLibraryIndex;
              if ImGui.Selectable(AnsiString(LabelText), Selected) then
              begin
                fMaterialEditor.SelectedLibraryIndex := I;
                fMaterialEditor.SelectedMaterialIndex := FirstRenderableMaterialIndex(Lib);
                fMaterialEditor.SelectedTextureIndex := 0;
                SyncTextureAssetSelectionToCurrentTexture;
              end;
            end;
          ImGui.EndListBox;
        end;
      end;
      ImGui.EndChild;

      if ImGui.BeginChild('MaterialListPane', ImVec2.New(-1, -1)) then
      begin
        Lib := SelectedMaterialEditorLibrary;
        ImGui.Text('Materials');

        if ImGui.Button('Add##Material') then
        begin
          if Lib <> nil then
            OpenAddMaterialPopup := True;
        end;

        ImGui.SameLine;
        if ImGui.Button('Delete##Material') then
        begin
          if (Lib <> nil) and (fMaterialEditor.SelectedMaterialIndex >= 0) then
            DeleteMaterialAt(Lib, fMaterialEditor.SelectedMaterialIndex);
        end;

        if ImGui.Button('Load##Material') then
        begin
          if Lib <> nil then
            OpenMaterialFileBrowser(mfbLoadMaterial);
        end;

        ImGui.SameLine;
        if ImGui.Button('Save##Material') then
        begin
          if SelectedMaterialEditorMaterial <> nil then
            OpenMaterialFileBrowser(mfbSaveMaterial);
        end;

        ImGui.Separator;
        if ImGui.BeginListBox('##MaterialList', ImVec2.New(-1, -1)) then
        begin
          if Lib <> nil then
            for I := 0 to Lib.Count - 1 do
            begin
              Mat := Lib.Material[I];
              if (Mat = nil) or IsEditorOnlyMaterial(Mat) then
                Continue;

              LabelText := Format('%s [%s]##mat%d',
                [MaterialDisplayName(Mat, I), MaterialTypeDisplayName(Mat.Materialtype), I]);
              Selected := I = fMaterialEditor.SelectedMaterialIndex;
              if ImGui.Selectable(AnsiString(LabelText), Selected) then
              begin
                fMaterialEditor.SelectedMaterialIndex := I;
                fMaterialEditor.SelectedTextureIndex := 0;
                SyncTextureAssetSelectionToCurrentTexture;
              end;
            end;
          ImGui.EndListBox;
        end;
      end;
      ImGui.EndChild;
    end;
    ImGui.EndChild;

    ImGui.SameLine;

    if ImGui.BeginChild('MaterialPropertiesPane', ImVec2.New(0, -1)) then
    begin
      Mat := SelectedMaterialEditorMaterial;
      if Mat = nil then
        ImGui.Text('Select a material to edit it.')
      else
      begin
        ImGui.Text(PAnsiChar(AnsiString('Material: ' +
          MaterialDisplayName(Mat, fMaterialEditor.SelectedMaterialIndex))));
        ImGui.Text(PAnsiChar(AnsiString('Type: ' +
          MaterialTypeDisplayName(Mat.Materialtype))));

        if ImGui.CollapsingHeader('Shader Parameters',
          ImGuiTreeNodeFlags_DefaultOpen) then
        begin
          Params := Mat.ShaderParameters;
          if Mat.Materialtype = mtActor then
            LayerLimit := 6
          else
            LayerLimit := 256;
          if Mat.Materialtype = mtTreeLeaf then
          begin
            if ImGui.BeginTable('TreeLeafShaderParamsTable', 2) then
            begin
              ImGui.TableNextRow(0, 0);
              ImGui.TableSetColumnIndex(0);
              ImGui.PushItemWidth(-1);
              if ImGui.DragFloat('Alpha Cutoff', @Params.AlphaCutoff, 0.01,
                0.0, 1.0, '%.2f') then
              begin
                Mat.ShaderParameters := Params;
                RequestRender;
              end;
              ImGui.PopItemWidth;

              ImGui.TableSetColumnIndex(1);
              ImGui.PushItemWidth(-1);
              if ImGui.DragFloat('Specular Level', @Params.SpecularLevel, 0.01,
                0.0, 8.0, '%.2f') then
              begin
                Mat.ShaderParameters := Params;
                RequestRender;
              end;
              ImGui.PopItemWidth;

              ImGui.TableNextRow(0, 0);
              ImGui.TableSetColumnIndex(0);
              ImGui.PushItemWidth(-1);
              if ImGui.DragFloat('Gamma', @Params.Gamma, 0.05,
                0.1, 8.0, '%.2f') then
              begin
                Mat.ShaderParameters := Params;
                RequestRender;
              end;
              ImGui.PopItemWidth;

              ImGui.TableSetColumnIndex(1);
              ImGui.PushItemWidth(-1);
              if ImGui.DragFloat('HDR Exposure', @Params.HdrExposure, 0.01,
                0.0, 16.0, '%.2f') then
              begin
                Mat.ShaderParameters := Params;
                RequestRender;
              end;
              ImGui.PopItemWidth;
              ImGui.EndTable;
            end;
          end
          else if Mat.Materialtype = mtTreeTrunk then
          begin
            if ImGui.BeginTable('TreeTrunkShaderParamsTable', 2) then
            begin
              ImGui.TableNextRow(0, 0);
              ImGui.TableSetColumnIndex(0);
              ImGui.PushItemWidth(-1);
              if ImGui.DragFloat('Specular Level', @Params.SpecularLevel, 0.01,
                0.0, 8.0, '%.2f') then
              begin
                Mat.ShaderParameters := Params;
                RequestRender;
              end;
              ImGui.PopItemWidth;

              ImGui.TableSetColumnIndex(1);
              ImGui.PushItemWidth(-1);
              if ImGui.DragFloat('AO Strength', @Params.AmbientShadowStrength,
                0.01, 0.0, 1.0, '%.2f') then
              begin
                Mat.ShaderParameters := Params;
                RequestRender;
              end;
              ImGui.PopItemWidth;

              ImGui.TableNextRow(0, 0);
              ImGui.TableSetColumnIndex(0);
              ImGui.PushItemWidth(-1);
              if ImGui.DragFloat('Gamma', @Params.Gamma, 0.05,
                0.1, 8.0, '%.2f') then
              begin
                Mat.ShaderParameters := Params;
                RequestRender;
              end;
              ImGui.PopItemWidth;

              ImGui.TableSetColumnIndex(1);
              ImGui.PushItemWidth(-1);
              if ImGui.DragFloat('HDR Exposure', @Params.HdrExposure, 0.01,
                0.0, 16.0, '%.2f') then
              begin
                Mat.ShaderParameters := Params;
                RequestRender;
              end;
              ImGui.PopItemWidth;
              ImGui.EndTable;
            end;
          end
          else if ImGui.BeginTable('MaterialShaderParamsTable', 2) then
          begin
            ImGui.TableNextRow(0, 0);
            ImGui.TableSetColumnIndex(0);
            ImGui.PushItemWidth(-1);
            if ImGui.DragFloat('Gamma', @Params.Gamma, 0.05, 0.0, 8.0, '%.2f') then
            begin
              Mat.ShaderParameters := Params;
              RequestRender;
            end;
            ImGui.PopItemWidth;

            ImGui.TableSetColumnIndex(1);
            ImGui.PushItemWidth(-1);
            if ImGui.DragInt('Layers', @Params.Layers, 1.0, 1, LayerLimit, '%d',
              ImGuiSliderFlags_None) then
            begin
              Mat.ShaderParameters := Params;
              RequestRender;
            end;
            ImGui.PopItemWidth;

            ImGui.TableNextRow(0, 0);
            ImGui.TableSetColumnIndex(0);
            ImGui.PushItemWidth(-1);
            if ImGui.DragFloat('Specular Level', @Params.SpecularLevel, 0.01,
              0.0, 8.0, '%.2f') then
            begin
              Mat.ShaderParameters := Params;
              RequestRender;
            end;
            ImGui.PopItemWidth;

            ImGui.TableSetColumnIndex(1);
            ImGui.PushItemWidth(-1);
            if ImGui.DragFloat('Ambient Shadow', @Params.AmbientShadowStrength,
              0.01, 0.0, 1.0, '%.2f') then
            begin
              Mat.ShaderParameters := Params;
              RequestRender;
            end;
            ImGui.PopItemWidth;

            ImGui.TableNextRow(0, 0);
            ImGui.TableSetColumnIndex(0);
            ImGui.PushItemWidth(-1);
            if ImGui.DragFloat('HDR Exposure', @Params.HdrExposure, 0.01,
              0.0, 16.0, '%.2f') then
            begin
              Mat.ShaderParameters := Params;
              RequestRender;
            end;
            ImGui.PopItemWidth;
            ImGui.EndTable;
          end;
        end;

        ImGui.Separator;
        if ImGui.CollapsingHeader('Textures', ImGuiTreeNodeFlags_DefaultOpen) then
        begin
          TexturePanelsHeight := System.Math.Max(380.0, //380
            ImGui.GetContentRegionAvail.y - 140.0);

          if ImGui.BeginChild('MaterialTextureSlotPane',
            ImVec2.New(320, TexturePanelsHeight)) then
          begin
            for I := 0 to Mat.Count - 1 do
            begin
              Tex := Mat.TextureList[I];
              Selected := I = fMaterialEditor.SelectedTextureIndex;

              ImGui.PushId(I);
              ImGui.BeginGroup;
              if Tex.Texture.TexID <> 0 then
              begin
                Texture := ImTextureID(NativeUInt(Tex.Texture.TexID));
                if ImGui.ImageButton(PAnsiChar(AnsiString('preview')), Texture,
                  ImVec2.New(MATERIAL_TEXTURE_THUMB_SIZE,
                    MATERIAL_TEXTURE_THUMB_SIZE), ImVec2.New(0, 0),
                  ImVec2.New(1, 1), ImVec4.New(0, 0, 0, 0),
                  ImVec4.New(1, 1, 1, 1)) then
                begin
                  fMaterialEditor.SelectedTextureIndex := I;
                  SyncTextureAssetSelectionToCurrentTexture;
                end;
              end
              else if ImGui.Button('[no preview]',
                ImVec2.New(MATERIAL_TEXTURE_THUMB_SIZE,
                  MATERIAL_TEXTURE_THUMB_SIZE)) then
              begin
                fMaterialEditor.SelectedTextureIndex := I;
                SyncTextureAssetSelectionToCurrentTexture;
              end;

              ImGui.SameLine;
              ImGui.BeginGroup;
              LabelText := TextureDisplayName(Tex, I) + '##texslot' + IntToStr(I);
              if ImGui.Selectable(AnsiString(LabelText), Selected) then
              begin
                fMaterialEditor.SelectedTextureIndex := I;
                SyncTextureAssetSelectionToCurrentTexture;
              end;

              if Tex.Path <> '' then
                ImGui.TextWrapped(AnsiString(TextureFileDisplayName(Tex.Path)))
              else
                ImGui.TextDisabled('<no texture file>');
              ImGui.EndGroup;
              ImGui.EndGroup;
              ImGui.Separator;
              ImGui.PopId;
            end;
          end;
          ImGui.EndChild;

          ImGui.SameLine;

          if ImGui.BeginChild('MaterialTextureAssetPane',
            ImVec2.New(0, TexturePanelsHeight)) then
          begin
            ImGui.Text('Search Texture Assets');
            ImGui.PushItemWidth(220);
            ImGui.InputText(PAnsiChar(AnsiString('##TextureAssetSearch')),
              @fTextureBrowser.Search[0], SizeOf(fTextureBrowser.Search));
            ImGui.PopItemWidth;

            if SelectedMaterialEditorTexture(Mat, Tex, TextureIndex) then
            begin
              ImGui.Text(PAnsiChar(AnsiString('Target slot: ' +
                TextureDisplayName(Tex, TextureIndex))));
              ImGui.Text(PAnsiChar(AnsiString('Uniform: ' + Tex.Texture.Name)));
              ImGui.Text(PAnsiChar(AnsiString('ID: ' +
                UIntToStr(Tex.Texture.TexID))));
              if ImGui.Button('Refresh##TextureAssets') then
                RefreshTextureBrowserList(True);
            end
            else
            begin
              ImGui.TextDisabled('Select a texture slot.');
              if ImGui.Button('Refresh##TextureAssets') then
                RefreshTextureBrowserList(True);
            end;

            if fTextureBrowser.LastError <> '' then
            begin
              ImGui.Separator;
              ImGui.TextWrapped(AnsiString(fTextureBrowser.LastError));
            end;

            ImGui.Separator;
            SearchText := LowerCase(Trim(AnsiBufferText(fTextureBrowser.Search)));
            if ImGui.BeginChild('MaterialTextureAssetList', ImVec2.New(-1, -1)) then
            begin
              for I := 0 to High(fTextureBrowser.Items) do
              begin
                TextureItem := fTextureBrowser.Items[I];
                if (SearchText <> '') and
                   (Pos(SearchText, LowerCase(TextureItem.DisplayName)) = 0) and
                   (Pos(SearchText, LowerCase(TextureItem.RelativePath)) = 0) then
                  Continue;

                Selected := I = fTextureBrowser.SelectedIndex;
                ImGui.PushId(1000 + I);
                ImGui.BeginGroup;
                if TextureItem.TextureID <> 0 then
                begin
                  Texture := ImTextureID(NativeUInt(TextureItem.TextureID));
                  if ImGui.ImageButton(PAnsiChar(AnsiString('preview')), Texture,
                    ImVec2.New(MATERIAL_TEXTURE_THUMB_SIZE,
                      MATERIAL_TEXTURE_THUMB_SIZE), ImVec2.New(0, 0),
                    ImVec2.New(1, 1), ImVec4.New(0, 0, 0, 0),
                    ImVec4.New(1, 1, 1, 1)) then
                  begin
                    fTextureBrowser.SelectedIndex := I;
                    try
                      ApplyTextureAssetToSelectedTexture(TextureItem.FileName);
                    except
                      on E: Exception do
                        fTextureBrowser.LastError := E.Message;
                    end;
                  end;
                end
                else if ImGui.Button('[no preview]',
                  ImVec2.New(MATERIAL_TEXTURE_THUMB_SIZE,
                    MATERIAL_TEXTURE_THUMB_SIZE)) then
                begin
                  fTextureBrowser.SelectedIndex := I;
                  try
                    ApplyTextureAssetToSelectedTexture(TextureItem.FileName);
                  except
                    on E: Exception do
                      fTextureBrowser.LastError := E.Message;
                  end;
                end;

                ImGui.SameLine;
                ImGui.BeginGroup;
                if ImGui.Selectable(AnsiString(TextureItem.DisplayName +
                  '##textureasset' + IntToStr(I)), Selected) then
                begin
                  fTextureBrowser.SelectedIndex := I;
                  try
                    ApplyTextureAssetToSelectedTexture(TextureItem.FileName);
                  except
                    on E: Exception do
                      fTextureBrowser.LastError := E.Message;
                  end;
                end;
                if (TextureItem.Width > 0) and (TextureItem.Height > 0) then
                  ImGui.Text(PAnsiChar(AnsiString(Format('%dx%d',
                    [TextureItem.Width, TextureItem.Height]))));
                ImGui.EndGroup;
                ImGui.EndGroup;
                ImGui.Separator;
                ImGui.PopId;
              end;
            end;
            ImGui.EndChild;
          end;
          ImGui.EndChild;

          if SelectedMaterialEditorTexture(Mat, Tex, TextureIndex) then
          begin
            ImGui.Separator;

            DiffuseColor[0] := Tex.Texture.DiffuseColor.X;
            DiffuseColor[1] := Tex.Texture.DiffuseColor.Y;
            DiffuseColor[2] := Tex.Texture.DiffuseColor.Z;
            if ImGui.ColorEdit3(PAnsiChar(AnsiString('Diffuse color')),
              @DiffuseColor[0], ImGuiColorEditFlags_None) then
            begin
              Tex.Texture.DiffuseColor := Vector3(DiffuseColor[0],
                DiffuseColor[1], DiffuseColor[2]);
              Mat.TextureList[TextureIndex] := Tex;
              RequestRender;
            end;

            SpecularColor[0] := Tex.Texture.SpecularColor.X;
            SpecularColor[1] := Tex.Texture.SpecularColor.Y;
            SpecularColor[2] := Tex.Texture.SpecularColor.Z;
            if ImGui.ColorEdit3(PAnsiChar(AnsiString('Specular color')),
              @SpecularColor[0], ImGuiColorEditFlags_None) then
            begin
              Tex.Texture.SpecularColor := Vector3(SpecularColor[0],
                SpecularColor[1], SpecularColor[2]);
              Mat.TextureList[TextureIndex] := Tex;
              RequestRender;
            end;

            Shininess := Tex.Texture.Shininess;
            if ImGui.DragFloat('Shininess', @Shininess, 0.25, 0.0, 4096.0,
              '%.2f') then
            begin
              Tex.Texture.Shininess := Shininess;
              Mat.TextureList[TextureIndex] := Tex;
              RequestRender;
            end;
          end;
        end;
      end;
    end;
    ImGui.EndChild;

    if OpenAddLibraryPopup then
      ImGui.OpenPopup('Add Material Library');
    if OpenAddMaterialPopup then
      ImGui.OpenPopup('Add Material');

    if ImGui.BeginPopupModal('Add Material Library', nil,
      ImGuiWindowFlags_AlwaysAutoResize) then
    begin
      ImGui.Text('Create a new material library.');
      ImGui.PushItemWidth(IMGUI_PROP_TEXT_WIDTH);
      ImGui.InputText(PAnsiChar(AnsiString('Name')), @fMaterialEditor.NewLibraryName[0],
        SizeOf(fMaterialEditor.NewLibraryName));
      ImGui.PopItemWidth;

      if ImGui.Button('Create') then
      begin
        if MaterialLibraries = nil then
          MaterialLibraries := TMaterialLibraries.Create;

        NewName := MakeUniqueMaterialLibraryName(
          AnsiBufferText(fMaterialEditor.NewLibraryName));
        fMaterialEditor.SelectedLibraryIndex := MaterialLibraries.CreateMaterialLibrary(NewName);
        fMaterialEditor.SelectedMaterialIndex := -1;
        fMaterialEditor.SelectedTextureIndex := -1;
        SetAnsiBuffer(fMaterialEditor.NewLibraryName, 'MaterialLibrary');
        SyncTextureAssetSelectionToCurrentTexture;
        ImGui.CloseCurrentPopup;
      end;

      ImGui.SameLine;
      if ImGui.Button('Cancel##AddMaterialLibrary') then
        ImGui.CloseCurrentPopup;

      ImGui.EndPopup;
    end;

    if ImGui.BeginPopupModal('Add Material', nil,
      ImGuiWindowFlags_AlwaysAutoResize) then
    begin
      ImGui.Text('Create a new material.');
      ImGui.PushItemWidth(IMGUI_PROP_TEXT_WIDTH);
      ImGui.InputText(PAnsiChar(AnsiString('Name')), @fMaterialEditor.NewMaterialName[0],
        SizeOf(fMaterialEditor.NewMaterialName));
      ImGui.PopItemWidth;

      ImGui.RadioButton(PAnsiChar(AnsiString('PBR')),
        @fMaterialEditor.NewMaterialType, 0);
      ImGui.SameLine;
      ImGui.RadioButton(PAnsiChar(AnsiString('Actor')),
        @fMaterialEditor.NewMaterialType, 2);
      ImGui.SameLine;
      ImGui.RadioButton(PAnsiChar(AnsiString('Terrain')),
        @fMaterialEditor.NewMaterialType, 1);
      ImGui.SameLine;
      ImGui.RadioButton(PAnsiChar(AnsiString('Tree Leaf')),
        @fMaterialEditor.NewMaterialType, 3);
      ImGui.SameLine;
      ImGui.RadioButton(PAnsiChar(AnsiString('Tree Trunk')),
        @fMaterialEditor.NewMaterialType, 4);

      if ImGui.Button('Create##AddMaterial') then
      begin
        Lib := SelectedMaterialEditorLibrary;
        if Lib <> nil then
        begin
          NewName := MakeUniqueMaterialName(Lib,
            AnsiBufferText(fMaterialEditor.NewMaterialName));
          case fMaterialEditor.NewMaterialType of
            1: MaterialType := mtHeightFieldMaterial;
            2: MaterialType := mtActor;
            3: MaterialType := mtTreeLeaf;
            4: MaterialType := mtTreeTrunk;
          else
            MaterialType := mtPBR;
          end;

          Mat := TMaterial.Create(MaterialType);
          Mat.Name := NewName;
          AssignShaderToMaterial(Mat);
          if MaterialType = mtHeightFieldMaterial then
            AddDefaultHeightFieldTextures(Mat)
          else if MaterialType = mtTreeLeaf then
            AddDefaultTreeLeafTextures(Mat)
          else if MaterialType = mtTreeTrunk then
            AddDefaultTreeTrunkTextures(Mat)
          else
            AddDefaultPBRTextures(Mat);

          fMaterialEditor.SelectedMaterialIndex := Lib.AddMaterial(Mat);
          fMaterialEditor.SelectedTextureIndex := 0;
          SetAnsiBuffer(fMaterialEditor.NewMaterialName, 'Material');
          fMaterialEditor.NewMaterialType := 0;
          SyncTextureAssetSelectionToCurrentTexture;
          ImGui.CloseCurrentPopup;
        end;
      end;

      ImGui.SameLine;
      if ImGui.Button('Cancel##AddMaterial') then
        ImGui.CloseCurrentPopup;

      ImGui.EndPopup;
    end;
  end;

  ImGui.End_;
  fMaterialEditor.Active := OpenWindow;
end;

procedure TSandBoxForm.DrawImGuiTextureBrowser;
var
  OpenWindow: Boolean;
  I: Integer;
  SearchText: string;
  Item: TTextureAssetInfo;
  Selected: Boolean;
  Texture: ImTextureID;
  Mat: TMaterial;
  Tex: TMaterialTexture;
  TextureIndex: Integer;
begin
  if not fTextureBrowser.Active then
    Exit;

  if fTextureBrowser.NeedsRefresh then
    RefreshTextureBrowserList;

  ImGui.SetNextWindowSize(ImVec2.New(860, 620), ImGuiCond_FirstUseEver);
  ImGui.SetNextWindowPos(ImVec2.New(320, 90), ImGuiCond_FirstUseEver);

  OpenWindow := True;
  if ImGui.Begin_('Texture Browser', @OpenWindow) then
  begin
    ImGui.TextWrapped(AnsiString('Textures are scanned from: ' + TEnginePaths.TexturesDir));
    ImGui.PushItemWidth(260);
    ImGui.InputText(PAnsiChar(AnsiString('Search')), @fTextureBrowser.Search[0],
      SizeOf(fTextureBrowser.Search));
    ImGui.PopItemWidth;
    ImGui.SameLine;
    if ImGui.Button('Refresh') then
      RefreshTextureBrowserList(True);

    ImGui.Separator;
    SearchText := LowerCase(Trim(AnsiBufferText(fTextureBrowser.Search)));

    if ImGui.BeginChild('TextureBrowserList', ImVec2.New(420, 0)) then
    begin
      for I := 0 to High(fTextureBrowser.Items) do
      begin
        Item := fTextureBrowser.Items[I];
        if (SearchText <> '') and
           (Pos(SearchText, LowerCase(Item.DisplayName)) = 0) and
           (Pos(SearchText, LowerCase(Item.RelativePath)) = 0) then
          Continue;

        Selected := I = fTextureBrowser.SelectedIndex;
        ImGui.PushId(I);
        ImGui.BeginGroup;
        if Item.TextureID <> 0 then
        begin
          Texture := ImTextureID(NativeUInt(Item.TextureID));
          if ImGui.ImageButton(PAnsiChar(AnsiString('preview')), Texture,
            ImVec2.New(MATERIAL_TEXTURE_THUMB_SIZE, MATERIAL_TEXTURE_THUMB_SIZE),
            ImVec2.New(0, 0), ImVec2.New(1, 1), ImVec4.New(0, 0, 0, 0),
            ImVec4.New(1, 1, 1, 1)) then
            fTextureBrowser.SelectedIndex := I;
        end
        else if ImGui.Button('[no preview]',
          ImVec2.New(MATERIAL_TEXTURE_THUMB_SIZE, MATERIAL_TEXTURE_THUMB_SIZE)) then
          fTextureBrowser.SelectedIndex := I;

        ImGui.SameLine;
        ImGui.BeginGroup;
        if ImGui.Selectable(AnsiString(Item.DisplayName + '##textureasset' + IntToStr(I)), Selected) then
          fTextureBrowser.SelectedIndex := I;
        ImGui.TextWrapped(AnsiString(Item.RelativePath));
        ImGui.EndGroup;
        ImGui.EndGroup;
        ImGui.Separator;
        ImGui.PopId;
      end;
    end;
    ImGui.EndChild;

    ImGui.SameLine;

    ImGui.BeginGroup;
    if (fTextureBrowser.SelectedIndex >= 0) and
       (fTextureBrowser.SelectedIndex <= High(fTextureBrowser.Items)) then
    begin
      Item := fTextureBrowser.Items[fTextureBrowser.SelectedIndex];
      if Item.TextureID <> 0 then
      begin
        Texture := ImTextureID(NativeUInt(Item.TextureID));
        ImGui.Image(Texture, ImVec2.New(160, 160), ImVec2.New(0, 0),
          ImVec2.New(1, 1), ImVec4.New(1, 1, 1, 1), ImVec4.New(0, 0, 0, 0));
      end;

      ImGui.Text(PAnsiChar(AnsiString(Item.DisplayName)));
      ImGui.TextWrapped(AnsiString(Item.RelativePath));
      if (Item.Width > 0) and (Item.Height > 0) then
        ImGui.Text(PAnsiChar(AnsiString(Format('%dx%d', [Item.Width, Item.Height]))));
    end
    else
      ImGui.Text('Select a texture from the list.');

    ImGui.Separator;
    if SelectedMaterialEditorTexture(Mat, Tex, TextureIndex) then
    begin
      ImGui.Text(PAnsiChar(AnsiString('Target material: ' + Mat.Name)));
      ImGui.Text(PAnsiChar(AnsiString('Target slot: ' +
        TextureDisplayName(Tex, TextureIndex))));
    end;

    if ImGui.Button('Apply to selected texture') then
    begin
      try
        if (fTextureBrowser.SelectedIndex >= 0) and
           (fTextureBrowser.SelectedIndex <= High(fTextureBrowser.Items)) then
        begin
          ApplyTextureAssetToSelectedTexture(
            fTextureBrowser.Items[fTextureBrowser.SelectedIndex].FileName);
          ResetTextureBrowser;
        end
        else
          fTextureBrowser.LastError := 'Select a texture first.';
      except
        on E: Exception do
          fTextureBrowser.LastError := E.Message;
      end;
    end;

    ImGui.SameLine;
    if ImGui.Button('Cancel##TextureBrowser') then
      ResetTextureBrowser;

    if fTextureBrowser.LastError <> '' then
    begin
      ImGui.Separator;
      ImGui.TextWrapped(AnsiString(fTextureBrowser.LastError));
    end;

    ImGui.EndGroup;
  end;
  ImGui.End_;

  if not OpenWindow then
    ResetTextureBrowser;
end;

procedure TSandBoxForm.DrawImGuiParticleTextureBrowser;
var
  OpenWindow: Boolean;
  I: Integer;
  SearchText: string;
  Item: TParticleTextureFileInfo;
  Selected: Boolean;
  Obj: TSceneObject;
  ParticleSystem: TParticleSystem;
  Texture: ImTextureID;
begin
  if not fParticleTextureBrowser.Active then
    Exit;

  if fParticleTextureBrowser.NeedsRefresh then
    RefreshParticleTextureList;

  ImGui.SetNextWindowSize(ImVec2.New(780, 520), ImGuiCond_Appearing);
  ImGui.SetNextWindowPosCenter(ImGuiCond_Appearing);

  OpenWindow := True;
  if ImGui.Begin_('Particle Texture', @OpenWindow, ImGuiWindowFlags_NoCollapse) then
  begin
    Obj := SelectedParticleObject;
    if Obj <> nil then
    begin
      if (Obj.ParticleSystemCount > 0) and
         ((fSelectedParticleSystemIndex < 0) or
          (fSelectedParticleSystemIndex >= Obj.ParticleSystemCount)) then
        SelectParticleSystemIndex(0);
      ParticleSystem := SelectedParticleSystem;
    end
    else
      ParticleSystem := nil;

    ImGui.TextWrapped(AnsiString('Particle textures are scanned from: ' +
      TEnginePaths.ParticleTexturesDir));
    if Obj <> nil then
      ImGui.Text(PAnsiChar(AnsiString('Target object: ' + Obj.Name)))
    else
      ImGui.TextDisabled('Select an object first.');

    if ParticleSystem <> nil then
      ImGui.TextWrapped(AnsiString('Target particle system: ' +
        ParticleSystem.Name + ', current: ' +
        TextureFileDisplayName(ParticleSystem.TexturePath)))
    else
      ImGui.TextWrapped('A particle system will be created when a texture is applied.');

    ImGui.Separator;
    ImGui.PushItemWidth(-1);
    ImGui.InputText(PAnsiChar(AnsiString('Search##ParticleTextureSearch')),
      @fParticleTextureBrowser.Search[0],
      SizeOf(fParticleTextureBrowser.Search));
    ImGui.PopItemWidth;

    ImGui.Separator;
    SearchText := LowerCase(Trim(AnsiBufferText(fParticleTextureBrowser.Search)));
    if ImGui.BeginChild('ParticleTextureList', ImVec2.New(390, 300)) then
    begin
      for I := 0 to High(fParticleTextureBrowser.Items) do
      begin
        Item := fParticleTextureBrowser.Items[I];
        if (SearchText <> '') and
           (Pos(SearchText, LowerCase(Item.DisplayName)) = 0) and
           (Pos(SearchText, LowerCase(Item.RelativePath)) = 0) then
          Continue;

        Selected := I = fParticleTextureBrowser.SelectedIndex;
        ImGui.PushId(I);
        ImGui.BeginGroup;
        if Item.TextureID <> 0 then
        begin
          Texture := ImTextureID(NativeUInt(Item.TextureID));
          if ImGui.ImageButton(PAnsiChar(AnsiString('preview')), Texture,
            ImVec2.New(PARTICLE_TEXTURE_THUMB_SIZE, PARTICLE_TEXTURE_THUMB_SIZE),
            ImVec2.New(0, 0), ImVec2.New(1, 1), ImVec4.New(0, 0, 0, 0),
            ImVec4.New(1, 1, 1, 1)) then
            fParticleTextureBrowser.SelectedIndex := I;
        end
        else if ImGui.Button('[no preview]',
          ImVec2.New(PARTICLE_TEXTURE_THUMB_SIZE, PARTICLE_TEXTURE_THUMB_SIZE)) then
          fParticleTextureBrowser.SelectedIndex := I;

        ImGui.SameLine;
        ImGui.BeginGroup;
        if ImGui.Selectable(AnsiString(Item.DisplayName + '##particletex' +
          IntToStr(I)), Selected) then
          fParticleTextureBrowser.SelectedIndex := I;

        if Selected then
          ImGui.SetItemDefaultFocus;

        if Item.RelativePath <> Item.DisplayName then
          ImGui.TextWrapped(AnsiString(Item.RelativePath));
        if (Item.Width > 0) and (Item.Height > 0) then
          ImGui.Text(PAnsiChar(AnsiString(Format('%dx%d',
            [Item.Width, Item.Height]))));
        ImGui.EndGroup;
        ImGui.EndGroup;
        ImGui.Separator;
        ImGui.PopId;
      end;
    end;
    ImGui.EndChild;

    ImGui.SameLine;
    ImGui.BeginGroup;
    if (fParticleTextureBrowser.SelectedIndex >= 0) and
       (fParticleTextureBrowser.SelectedIndex <= High(fParticleTextureBrowser.Items)) then
    begin
      Item := fParticleTextureBrowser.Items[fParticleTextureBrowser.SelectedIndex];
      if Item.TextureID <> 0 then
      begin
        Texture := ImTextureID(NativeUInt(Item.TextureID));
        ImGui.Image(Texture, ImVec2.New(160, 160), ImVec2.New(0, 0),
          ImVec2.New(1, 1), ImVec4.New(1, 1, 1, 1), ImVec4.New(0, 0, 0, 0));
      end
      else
        ImGui.TextWrapped('Preview unavailable.');

      ImGui.Text(PAnsiChar(AnsiString(Item.DisplayName)));
      ImGui.TextWrapped(AnsiString(Item.RelativePath));
      if (Item.Width > 0) and (Item.Height > 0) then
        ImGui.Text(PAnsiChar(AnsiString(Format('%dx%d',
          [Item.Width, Item.Height]))));
    end
    else
      ImGui.TextWrapped('Select a particle texture to preview it.');

    ImGui.EndGroup;

    if fParticleTextureBrowser.LastError <> '' then
    begin
      ImGui.Separator;
      ImGui.TextWrapped(AnsiString(fParticleTextureBrowser.LastError));
    end;

    ImGui.Separator;
    if ImGui.Button('Apply##ParticleTexture') then
    begin
      if (fParticleTextureBrowser.SelectedIndex >= 0) and
         (fParticleTextureBrowser.SelectedIndex <= High(fParticleTextureBrowser.Items)) then
      begin
        Item := fParticleTextureBrowser.Items[fParticleTextureBrowser.SelectedIndex];
        ApplyParticleTextureToSelectedParticle(Item.FileName);
        if fParticleTextureBrowser.LastError = '' then
          ResetParticleTextureBrowser;
      end
      else
        fParticleTextureBrowser.LastError := 'Select a particle texture first.';
    end;

    ImGui.SameLine;
    if ImGui.Button('Refresh##ParticleTexture') then
      RefreshParticleTextureList(True);

    ImGui.SameLine;
    if ImGui.Button('Cancel##ParticleTexture') then
      ResetParticleTextureBrowser;
  end;
  ImGui.End_;

  if not OpenWindow then
    ResetParticleTextureBrowser;
end;

procedure TSandBoxForm.DrawImGuiBillboardTextureBrowser;
var
  OpenWindow: Boolean;
  I: Integer;
  SearchText: string;
  Item: TBillboardTextureFileInfo;
  Selected: Boolean;
  Obj: TSceneObject;
  Billboard: TBillboard;
  Texture: ImTextureID;
begin
  if not fBillboardTextureBrowser.Active then
    Exit;

  if fBillboardTextureBrowser.NeedsRefresh then
    RefreshBillboardTextureList;

  ImGui.SetNextWindowSize(ImVec2.New(780, 520), ImGuiCond_Appearing);
  ImGui.SetNextWindowPosCenter(ImGuiCond_Appearing);

  OpenWindow := True;
  if ImGui.Begin_('Billboard Texture', @OpenWindow, ImGuiWindowFlags_NoCollapse) then
  begin
    Obj := fSelectedObject;
    if Assigned(Obj) and Obj.IsGizmo then
      Obj := nil;

    if Obj <> nil then
    begin
      if (Obj.BillboardCount > 0) and
         ((fSelectedBillboardIndex < 0) or
          (fSelectedBillboardIndex >= Obj.BillboardCount)) then
        SelectBillboardIndex(0);
      Billboard := SelectedBillboard;
    end
    else
      Billboard := nil;

    ImGui.TextWrapped(AnsiString('Billboard textures are scanned from: ' +
      TEnginePaths.BillboardTexturesDir));
    if Obj <> nil then
      ImGui.Text(PAnsiChar(AnsiString('Target object: ' + Obj.Name)))
    else
      ImGui.TextDisabled('Select an object first.');

    if Billboard <> nil then
      ImGui.TextWrapped(AnsiString('Target billboard: ' + Billboard.Name +
        ', current: ' + TextureFileDisplayName(Billboard.TexturePath)))
    else
      ImGui.TextWrapped('A billboard will be created when a texture is applied.');

    ImGui.Separator;
    ImGui.PushItemWidth(-1);
    ImGui.InputText(PAnsiChar(AnsiString('Search##BillboardTextureSearch')),
      @fBillboardTextureBrowser.Search[0],
      SizeOf(fBillboardTextureBrowser.Search));
    ImGui.PopItemWidth;

    ImGui.Separator;
    SearchText := LowerCase(Trim(AnsiBufferText(fBillboardTextureBrowser.Search)));
    if ImGui.BeginChild('BillboardTextureList', ImVec2.New(390, 300)) then
    begin
      for I := 0 to High(fBillboardTextureBrowser.Items) do
      begin
        Item := fBillboardTextureBrowser.Items[I];
        if (SearchText <> '') and
           (Pos(SearchText, LowerCase(Item.DisplayName)) = 0) and
           (Pos(SearchText, LowerCase(Item.RelativePath)) = 0) then
          Continue;

        Selected := I = fBillboardTextureBrowser.SelectedIndex;
        ImGui.PushId(I);
        ImGui.BeginGroup;
        if Item.TextureID <> 0 then
        begin
          Texture := ImTextureID(NativeUInt(Item.TextureID));
          if ImGui.ImageButton(PAnsiChar(AnsiString('preview')), Texture,
            ImVec2.New(BILLBOARD_TEXTURE_THUMB_SIZE, BILLBOARD_TEXTURE_THUMB_SIZE),
            ImVec2.New(0, 0), ImVec2.New(1, 1), ImVec4.New(0, 0, 0, 0),
            ImVec4.New(1, 1, 1, 1)) then
            fBillboardTextureBrowser.SelectedIndex := I;
        end
        else if ImGui.Button('[no preview]',
          ImVec2.New(BILLBOARD_TEXTURE_THUMB_SIZE, BILLBOARD_TEXTURE_THUMB_SIZE)) then
          fBillboardTextureBrowser.SelectedIndex := I;

        ImGui.SameLine;
        ImGui.BeginGroup;
        if ImGui.Selectable(AnsiString(Item.DisplayName + '##billboardtex' +
          IntToStr(I)), Selected) then
          fBillboardTextureBrowser.SelectedIndex := I;

        if Selected then
          ImGui.SetItemDefaultFocus;

        if Item.RelativePath <> Item.DisplayName then
          ImGui.TextWrapped(AnsiString(Item.RelativePath));
        if (Item.Width > 0) and (Item.Height > 0) then
          ImGui.Text(PAnsiChar(AnsiString(Format('%dx%d',
            [Item.Width, Item.Height]))));
        ImGui.EndGroup;
        ImGui.EndGroup;
        ImGui.Separator;
        ImGui.PopId;
      end;
    end;
    ImGui.EndChild;

    ImGui.SameLine;
    ImGui.BeginGroup;
    if (fBillboardTextureBrowser.SelectedIndex >= 0) and
       (fBillboardTextureBrowser.SelectedIndex <= High(fBillboardTextureBrowser.Items)) then
    begin
      Item := fBillboardTextureBrowser.Items[fBillboardTextureBrowser.SelectedIndex];
      if Item.TextureID <> 0 then
      begin
        Texture := ImTextureID(NativeUInt(Item.TextureID));
        ImGui.Image(Texture, ImVec2.New(160, 160), ImVec2.New(0, 0),
          ImVec2.New(1, 1), ImVec4.New(1, 1, 1, 1), ImVec4.New(0, 0, 0, 0));
      end
      else
        ImGui.TextWrapped('Preview unavailable.');

      ImGui.Text(PAnsiChar(AnsiString(Item.DisplayName)));
      ImGui.TextWrapped(AnsiString(Item.RelativePath));
      if (Item.Width > 0) and (Item.Height > 0) then
        ImGui.Text(PAnsiChar(AnsiString(Format('%dx%d',
          [Item.Width, Item.Height]))));
    end
    else
      ImGui.TextWrapped('Select a billboard texture to preview it.');

    ImGui.EndGroup;

    if fBillboardTextureBrowser.LastError <> '' then
    begin
      ImGui.Separator;
      ImGui.TextWrapped(AnsiString(fBillboardTextureBrowser.LastError));
    end;

    ImGui.Separator;
    if ImGui.Button('Apply##BillboardTexture') then
    begin
      if (fBillboardTextureBrowser.SelectedIndex >= 0) and
         (fBillboardTextureBrowser.SelectedIndex <= High(fBillboardTextureBrowser.Items)) then
      begin
        Item := fBillboardTextureBrowser.Items[fBillboardTextureBrowser.SelectedIndex];
        ApplyBillboardTextureToSelectedObject(Item.FileName);
        if fBillboardTextureBrowser.LastError = '' then
          ResetBillboardTextureBrowser;
      end
      else
        fBillboardTextureBrowser.LastError := 'Select a billboard texture first.';
    end;

    ImGui.SameLine;
    if ImGui.Button('Refresh##BillboardTexture') then
      RefreshBillboardTextureList(True);

    ImGui.SameLine;
    if ImGui.Button('Cancel##BillboardTexture') then
      ResetBillboardTextureBrowser;
  end;
  ImGui.End_;

  if not OpenWindow then
    ResetBillboardTextureBrowser;
end;

procedure TSandBoxForm.DrawImGuiMaterialFileBrowser;
var
  OpenWindow: Boolean;
  I: Integer;
  SearchText: string;
  Item: TMaterialFileInfo;
  Selected: Boolean;
  Texture: ImTextureID;
  TitleText: string;
  ActionText: string;
  ListTitleText: string;
  TitleAnsi: AnsiString;
  OverwriteKind: string;
  ReplaceClicked: Boolean;
  CancelOverwriteClicked: Boolean;
begin
  if not fMaterialFileBrowser.Active then
    Exit;

  if fMaterialFileBrowser.NeedsRefresh then
    RefreshMaterialFileList;

  case fMaterialFileBrowser.Mode of
    mfbLoadMaterial:
      begin
        TitleText := 'Load Material';
        ActionText := 'Load Material';
        ListTitleText := 'Search Materials';
      end;
    mfbSaveMaterial:
      begin
        TitleText := 'Save Material';
        ActionText := 'Save Material';
        ListTitleText := 'Search Materials';
      end;
    mfbLoadLibrary:
      begin
        TitleText := 'Load Material Library';
        ActionText := 'Load Library';
        ListTitleText := 'Search Material Libraries';
      end;
    mfbSaveLibrary:
      begin
        TitleText := 'Save Material Library';
        ActionText := 'Save Library';
        ListTitleText := 'Search Material Libraries';
      end;
  else
    Exit;
  end;

  if fMaterialFileBrowser.Mode = mfbSaveLibrary then
    OverwriteKind := 'Material library file'
  else
    OverwriteKind := 'Material file';

  TitleAnsi := AnsiString(TitleText);
  ImGui.SetNextWindowSize(ImVec2.New(720, 460), ImGuiCond_Appearing);
  ImGui.SetNextWindowPosCenter(ImGuiCond_Appearing);
  ImGui.OpenPopup(PAnsiChar(TitleAnsi));
  OpenWindow := True;
  if ImGui.BeginPopupModal(PAnsiChar(TitleAnsi), @OpenWindow,
    ImGuiWindowFlags_NoResize) then
  begin
    if ImGui.BeginChild('MaterialFileActionPane', ImVec2.New(230, -1)) then
    begin
      ImGui.TextWrapped(AnsiString('Files are scanned from: ' +
        TEnginePaths.MaterialsDir));
      ImGui.Separator;

      if (fMaterialFileBrowser.SelectedIndex >= 0) and
         (fMaterialFileBrowser.SelectedIndex <= High(fMaterialFileBrowser.Items)) then
      begin
        Item := fMaterialFileBrowser.Items[fMaterialFileBrowser.SelectedIndex];
        if Item.TextureID <> 0 then
        begin
          Texture := ImTextureID(NativeUInt(Item.TextureID));
          ImGui.Image(Texture, ImVec2.New(160, 160), ImVec2.New(0, 0),
            ImVec2.New(1, 1), ImVec4.New(1, 1, 1, 1), ImVec4.New(0, 0, 0, 0));
        end;
        ImGui.Text(PAnsiChar(AnsiString(Item.DisplayName)));
        ImGui.TextWrapped(AnsiString(Item.Summary));
        ImGui.TextWrapped(AnsiString(Item.RelativePath));
      end
      else
        ImGui.TextWrapped('Select a material or library file.');

      if fMaterialFileBrowser.Mode in [mfbSaveMaterial, mfbSaveLibrary] then
      begin
        ImGui.Separator;
        ImGui.PushItemWidth(-1);
        if ImGui.InputText(PAnsiChar(AnsiString('File name')),
          @fMaterialFileBrowser.FileName[0], SizeOf(fMaterialFileBrowser.FileName)) then
        begin
          fMaterialFileBrowser.PendingOverwrite := False;
          fMaterialFileBrowser.PendingOverwriteFileName := '';
          fMaterialFileBrowser.LastError := '';
        end;
        ImGui.PopItemWidth;
      end;

      if fMaterialFileBrowser.PendingOverwrite then
      begin
        DrawOverwriteConfirmation(fMaterialFileBrowser.PendingOverwriteFileName,
          OverwriteKind, 'MaterialFiles', ReplaceClicked,
          CancelOverwriteClicked);

        if ReplaceClicked then
        begin
          try
            ExecuteMaterialFileBrowserAction;
            if not fMaterialFileBrowser.Active then
              ImGui.CloseCurrentPopup;
          except
            on E: Exception do
              fMaterialFileBrowser.LastError := E.Message;
          end;
        end;

        if CancelOverwriteClicked then
        begin
          fMaterialFileBrowser.PendingOverwrite := False;
          fMaterialFileBrowser.PendingOverwriteFileName := '';
          fMaterialFileBrowser.LastError := '';
        end;
      end
      else
      begin
        ImGui.Separator;
        if ImGui.Button(AnsiString(ActionText), ImVec2.New(-1, 0)) then
        begin
          try
            ExecuteMaterialFileBrowserAction;
            if not fMaterialFileBrowser.Active then
              ImGui.CloseCurrentPopup;
          except
            on E: Exception do
              fMaterialFileBrowser.LastError := E.Message;
          end;
        end;
      end;

      if ImGui.Button('Cancel##MaterialFiles', ImVec2.New(-1, 0)) then
      begin
        ImGui.CloseCurrentPopup;
        ResetMaterialFileBrowser;
      end;

      if ImGui.Button('Refresh##MaterialFiles', ImVec2.New(-1, 0)) then
        RefreshMaterialFileList;

      if fMaterialFileBrowser.LastError <> '' then
      begin
        ImGui.Separator;
        ImGui.TextWrapped(AnsiString(fMaterialFileBrowser.LastError));
      end;
    end;
    ImGui.EndChild;

    ImGui.SameLine;

    if ImGui.BeginChild('MaterialFileListPane', ImVec2.New(0, -1)) then
    begin
      ImGui.Text(PAnsiChar(AnsiString(ListTitleText)));
      ImGui.PushItemWidth(-1);
      ImGui.InputText(PAnsiChar(AnsiString('##MaterialFileSearch')),
        @fMaterialFileBrowser.Search[0], SizeOf(fMaterialFileBrowser.Search));
      ImGui.PopItemWidth;
      ImGui.Separator;

      SearchText := LowerCase(Trim(AnsiBufferText(fMaterialFileBrowser.Search)));
      if ImGui.BeginChild('MaterialFileListItems', ImVec2.New(-1, -1)) then
      begin
        for I := 0 to High(fMaterialFileBrowser.Items) do
        begin
          Item := fMaterialFileBrowser.Items[I];
          if (fMaterialFileBrowser.Mode in [mfbLoadMaterial, mfbSaveMaterial]) and
             Item.IsLibrary then
            Continue;
          if (fMaterialFileBrowser.Mode in [mfbLoadLibrary, mfbSaveLibrary]) and
             (not Item.IsLibrary) then
            Continue;

          if (SearchText <> '') and
             (Pos(SearchText, LowerCase(Item.DisplayName)) = 0) and
             (Pos(SearchText, LowerCase(Item.RelativePath)) = 0) and
             (Pos(SearchText, LowerCase(Item.Summary)) = 0) then
            Continue;

          Selected := I = fMaterialFileBrowser.SelectedIndex;
          ImGui.PushId(I);
          ImGui.BeginGroup;
          if Item.TextureID <> 0 then
          begin
            Texture := ImTextureID(NativeUInt(Item.TextureID));
            if ImGui.ImageButton(PAnsiChar(AnsiString('preview')), Texture,
              ImVec2.New(MATERIAL_FILE_THUMB_SIZE, MATERIAL_FILE_THUMB_SIZE),
              ImVec2.New(0, 0), ImVec2.New(1, 1), ImVec4.New(0, 0, 0, 0),
              ImVec4.New(1, 1, 1, 1)) then
            begin
              fMaterialFileBrowser.SelectedIndex := I;
              if fMaterialFileBrowser.Mode in [mfbSaveMaterial, mfbSaveLibrary] then
              begin
                SetAnsiBuffer(fMaterialFileBrowser.FileName,
                  ExtractFileName(Item.FileName));
                fMaterialFileBrowser.PendingOverwrite := False;
                fMaterialFileBrowser.PendingOverwriteFileName := '';
                fMaterialFileBrowser.LastError := '';
              end;
            end;
          end
          else if ImGui.Button('[no preview]',
            ImVec2.New(MATERIAL_FILE_THUMB_SIZE, MATERIAL_FILE_THUMB_SIZE)) then
          begin
            fMaterialFileBrowser.SelectedIndex := I;
            if fMaterialFileBrowser.Mode in [mfbSaveMaterial, mfbSaveLibrary] then
            begin
              SetAnsiBuffer(fMaterialFileBrowser.FileName,
                ExtractFileName(Item.FileName));
              fMaterialFileBrowser.PendingOverwrite := False;
              fMaterialFileBrowser.PendingOverwriteFileName := '';
              fMaterialFileBrowser.LastError := '';
            end;
          end;

          ImGui.SameLine;
          ImGui.BeginGroup;
          if ImGui.Selectable(AnsiString(Item.DisplayName + '##materialfile' +
            IntToStr(I)), Selected) then
          begin
            fMaterialFileBrowser.SelectedIndex := I;
            if fMaterialFileBrowser.Mode in [mfbSaveMaterial, mfbSaveLibrary] then
            begin
              SetAnsiBuffer(fMaterialFileBrowser.FileName,
                ExtractFileName(Item.FileName));
              fMaterialFileBrowser.PendingOverwrite := False;
              fMaterialFileBrowser.PendingOverwriteFileName := '';
              fMaterialFileBrowser.LastError := '';
            end;
          end;
          ImGui.TextWrapped(AnsiString(Item.Summary));
          ImGui.TextWrapped(AnsiString(Item.RelativePath));
          ImGui.EndGroup;
          ImGui.EndGroup;
          ImGui.Separator;
          ImGui.PopId;
        end;
      end;
      ImGui.EndChild;
    end;
    ImGui.EndChild;
    ImGui.EndPopup;
  end;

  if not OpenWindow then
  begin
    ResetMaterialFileBrowser;
  end;
end;

procedure TSandBoxForm.DrawImGuiModelFileBrowser;
var
  OpenWindow: Boolean;
  I: Integer;
  SearchText: string;
  Item: TModelFileInfo;
  Selected: Boolean;
  TitleText: string;
  ActionText: string;
  ListTitleText: string;
  TitleAnsi: AnsiString;
  SelectedFileCount: Integer;
begin
  if not fModelFileBrowser.Active then
    Exit;

  if fModelFileBrowser.NeedsRefresh then
    RefreshModelFileList;

  case fModelFileBrowser.Mode of
    modelBrowserLoadWindTree:
      begin
        TitleText := 'Load Bone Wind Tree';
        ActionText := 'Load Bone Tree';
        ListTitleText := 'Search Trees';
      end;
    modelBrowserLoadVertexWindTree:
      begin
        TitleText := 'Load Vertex Wind Tree';
        ActionText := 'Load Vertex Tree';
        ListTitleText := 'Search Trees';
      end;
    modelBrowserLoadAnimationClips:
      begin
        TitleText := 'Load Animation Clips';
        ActionText := 'Load Animation(s)';
        ListTitleText := 'Search Animations';
      end;
    modelBrowserAddMesh:
      begin
        TitleText := 'Load Model as Mesh';
        ActionText := 'Add Mesh';
        ListTitleText := 'Search Models';
      end;
  else
    TitleText := 'Load Model as Object';
    ActionText := 'Load Object';
    ListTitleText := 'Search Models';
  end;

  TitleAnsi := AnsiString(TitleText);
  ImGui.SetNextWindowSize(ImVec2.New(720, 460), ImGuiCond_Appearing);
  ImGui.SetNextWindowPosCenter(ImGuiCond_Appearing);
  ImGui.OpenPopup(PAnsiChar(TitleAnsi));
  OpenWindow := True;
  if ImGui.BeginPopupModal(PAnsiChar(TitleAnsi), @OpenWindow,
    ImGuiWindowFlags_NoResize) then
  begin
    if ImGui.BeginChild('ModelFileActionPane', ImVec2.New(230, -1)) then
    begin
      ImGui.TextWrapped(AnsiString('Models are scanned from: ' +
        TEnginePaths.ModelsDir));
      ImGui.TextWrapped(AnsiString('glTF textures resolve through: ' +
        TEnginePaths.TexturesDir));
      ImGui.Separator;

      if fModelFileBrowser.Mode = modelBrowserLoadAnimationClips then
        ImGui.Checkbox('Auto play first imported clip',
          @fModelFileBrowser.AutoPlayFirstAnimation)
      else if fModelFileBrowser.Mode in [modelBrowserLoadWindTree,
        modelBrowserLoadVertexWindTree] then
        fModelFileBrowser.AutoPlayFirstAnimation := False
      else
        ImGui.Checkbox('Auto play first animation',
          @fModelFileBrowser.AutoPlayFirstAnimation);
      ImGui.Separator;

      if fModelFileBrowser.Mode = modelBrowserLoadAnimationClips then
      begin
        SelectedFileCount := 0;
        for I := 0 to High(fModelFileBrowser.Items) do
          if fModelFileBrowser.Items[I].Selected then
            Inc(SelectedFileCount);
        ImGui.Text(PAnsiChar(AnsiString(Format('Selected files: %d',
          [SelectedFileCount]))));
        if Assigned(fSelectedObject) then
          ImGui.TextWrapped(AnsiString('Target: ' + fSelectedObject.Name));
      end
      else if (fModelFileBrowser.SelectedIndex >= 0) and
         (fModelFileBrowser.SelectedIndex <= High(fModelFileBrowser.Items)) then
      begin
        Item := fModelFileBrowser.Items[fModelFileBrowser.SelectedIndex];
        ImGui.Text(PAnsiChar(AnsiString(Item.DisplayName)));
        ImGui.TextWrapped(AnsiString(Item.Summary));
        ImGui.TextWrapped(AnsiString(Item.RelativePath));
      end
      else
        ImGui.TextWrapped('Select a model file.');

      ImGui.Separator;
      if ImGui.Button(AnsiString(ActionText), ImVec2.New(-1, 0)) then
      begin
        try
          ExecuteModelFileBrowserAction;
          if not fModelFileBrowser.Active then
            ImGui.CloseCurrentPopup;
        except
          on E: Exception do
            fModelFileBrowser.LastError := E.Message;
        end;
      end;

      if ImGui.Button('Cancel##ModelFiles', ImVec2.New(-1, 0)) then
      begin
        ImGui.CloseCurrentPopup;
        ResetModelFileBrowser;
      end;

      if ImGui.Button('Refresh##ModelFiles', ImVec2.New(-1, 0)) then
        RefreshModelFileList;

      if fModelFileBrowser.LastError <> '' then
      begin
        ImGui.Separator;
        ImGui.TextWrapped(AnsiString(fModelFileBrowser.LastError));
      end;
    end;
    ImGui.EndChild;

    ImGui.SameLine;

    if ImGui.BeginChild('ModelFileListPane', ImVec2.New(0, -1)) then
    begin
      ImGui.Text(PAnsiChar(AnsiString(ListTitleText)));
      ImGui.PushItemWidth(-1);
      ImGui.InputText(PAnsiChar(AnsiString('##ModelFileSearch')),
        @fModelFileBrowser.Search[0], SizeOf(fModelFileBrowser.Search));
      ImGui.PopItemWidth;
      ImGui.Separator;

      SearchText := LowerCase(Trim(AnsiBufferText(fModelFileBrowser.Search)));
      if ImGui.BeginChild('ModelFileListItems', ImVec2.New(-1, -1)) then
      begin
        for I := 0 to High(fModelFileBrowser.Items) do
        begin
          Item := fModelFileBrowser.Items[I];
          if (SearchText <> '') and
             (Pos(SearchText, LowerCase(Item.DisplayName)) = 0) and
             (Pos(SearchText, LowerCase(Item.RelativePath)) = 0) and
             (Pos(SearchText, LowerCase(Item.Summary)) = 0) then
            Continue;

          if fModelFileBrowser.Mode = modelBrowserLoadAnimationClips then
            Selected := fModelFileBrowser.Items[I].Selected
          else
            Selected := I = fModelFileBrowser.SelectedIndex;
          ImGui.PushId(I);
          if ImGui.Selectable(AnsiString(Item.DisplayName + '##modelfile' +
            IntToStr(I)), Selected) then
          begin
            fModelFileBrowser.SelectedIndex := I;
            if fModelFileBrowser.Mode = modelBrowserLoadAnimationClips then
              fModelFileBrowser.Items[I].Selected :=
                not fModelFileBrowser.Items[I].Selected;
            fModelFileBrowser.LastError := '';
          end;
          ImGui.TextWrapped(AnsiString(Item.Summary));
          ImGui.TextWrapped(AnsiString(Item.RelativePath));
          ImGui.Separator;
          ImGui.PopId;
        end;
      end;
      ImGui.EndChild;
    end;
    ImGui.EndChild;
    ImGui.EndPopup;
  end;

  if not OpenWindow then
    ResetModelFileBrowser;
end;

procedure TSandBoxForm.DrawImGuiSceneFileBrowser;
var
  OpenWindow: Boolean;
  I: Integer;
  SearchText: string;
  Item: TSceneFileInfo;
  Selected: Boolean;
  TitleText: string;
  ActionText: string;
  ListTitleText: string;
  TitleAnsi: AnsiString;
  ReplaceClicked: Boolean;
  CancelOverwriteClicked: Boolean;
begin
  if not fSceneFileBrowser.Active then
    Exit;

  if fSceneFileBrowser.NeedsRefresh then
    RefreshSceneFileList;

  case fSceneFileBrowser.Mode of
    sfbLoadScene:
      begin
        TitleText := 'Load Scene';
        ActionText := 'Load Scene';
        ListTitleText := 'Search Scenes';
      end;
    sfbSaveScene:
      begin
        TitleText := 'Save Scene';
        ActionText := 'Save Scene';
        ListTitleText := 'Search Scenes';
      end;
  else
    Exit;
  end;

  TitleAnsi := AnsiString(TitleText);
  ImGui.SetNextWindowSize(ImVec2.New(720, 460), ImGuiCond_Appearing);
  ImGui.SetNextWindowPosCenter(ImGuiCond_Appearing);
  ImGui.OpenPopup(PAnsiChar(TitleAnsi));
  OpenWindow := True;
  if ImGui.BeginPopupModal(PAnsiChar(TitleAnsi), @OpenWindow,
    ImGuiWindowFlags_NoResize) then
  begin
    if ImGui.BeginChild('SceneFileActionPane', ImVec2.New(240, -1)) then
    begin
      ImGui.TextWrapped(AnsiString('Scenes are saved in: ' +
        TEnginePaths.ScenesDir));
      ImGui.Separator;

      if (fSceneFileBrowser.SelectedIndex >= 0) and
         (fSceneFileBrowser.SelectedIndex <= High(fSceneFileBrowser.Items)) then
      begin
        Item := fSceneFileBrowser.Items[fSceneFileBrowser.SelectedIndex];
        ImGui.Text(PAnsiChar(AnsiString(Item.DisplayName)));
        ImGui.TextWrapped(AnsiString(Item.Summary));
        ImGui.TextWrapped(AnsiString(Item.RelativePath));
        if not Item.ValidScene then
          ImGui.TextWrapped('Scene preview is unavailable.');
      end
      else if fSceneFileBrowser.Mode = sfbLoadScene then
        ImGui.TextWrapped('Select a scene file.')
      else
        ImGui.TextWrapped('Choose an existing scene or enter a new file name.');

      if fSceneFileBrowser.Mode = sfbSaveScene then
      begin
        ImGui.Separator;
        ImGui.PushItemWidth(-1);
        if ImGui.InputText(PAnsiChar(AnsiString('File name')),
          @fSceneFileBrowser.FileName[0], SizeOf(fSceneFileBrowser.FileName)) then
        begin
          fSceneFileBrowser.PendingOverwrite := False;
          fSceneFileBrowser.PendingOverwriteFileName := '';
          fSceneFileBrowser.LastError := '';
        end;
        ImGui.PopItemWidth;
      end;

      if fSceneFileBrowser.PendingOverwrite then
      begin
        DrawOverwriteConfirmation(fSceneFileBrowser.PendingOverwriteFileName,
          'Scene file', 'SceneFiles', ReplaceClicked, CancelOverwriteClicked);

        if ReplaceClicked then
        begin
          try
            ExecuteSceneFileBrowserAction;
            if not fSceneFileBrowser.Active then
              ImGui.CloseCurrentPopup;
          except
            on E: Exception do
              fSceneFileBrowser.LastError := E.Message;
          end;
        end;

        if CancelOverwriteClicked then
        begin
          fSceneFileBrowser.PendingOverwrite := False;
          fSceneFileBrowser.PendingOverwriteFileName := '';
          fSceneFileBrowser.LastError := '';
        end;
      end
      else
      begin
        ImGui.Separator;
        if ImGui.Button(AnsiString(ActionText), ImVec2.New(-1, 0)) then
        begin
          try
            ExecuteSceneFileBrowserAction;
            if not fSceneFileBrowser.Active then
              ImGui.CloseCurrentPopup;
          except
            on E: Exception do
              fSceneFileBrowser.LastError := E.Message;
          end;
        end;
      end;

      if ImGui.Button('Cancel##SceneFiles', ImVec2.New(-1, 0)) then
      begin
        ImGui.CloseCurrentPopup;
        ResetSceneFileBrowser;
      end;

      if ImGui.Button('Refresh##SceneFiles', ImVec2.New(-1, 0)) then
        RefreshSceneFileList;

      if fSceneFileBrowser.LastError <> '' then
      begin
        ImGui.Separator;
        ImGui.TextWrapped(AnsiString(fSceneFileBrowser.LastError));
      end;
    end;
    ImGui.EndChild;

    ImGui.SameLine;

    if ImGui.BeginChild('SceneFileListPane', ImVec2.New(0, -1)) then
    begin
      ImGui.Text(PAnsiChar(AnsiString(ListTitleText)));
      ImGui.PushItemWidth(-1);
      ImGui.InputText(PAnsiChar(AnsiString('##SceneFileSearch')),
        @fSceneFileBrowser.Search[0], SizeOf(fSceneFileBrowser.Search));
      ImGui.PopItemWidth;
      ImGui.Separator;

      SearchText := LowerCase(Trim(AnsiBufferText(fSceneFileBrowser.Search)));
      if ImGui.BeginChild('SceneFileListItems', ImVec2.New(-1, -1)) then
      begin
        for I := 0 to High(fSceneFileBrowser.Items) do
        begin
          Item := fSceneFileBrowser.Items[I];
          if (SearchText <> '') and
             (Pos(SearchText, LowerCase(Item.DisplayName)) = 0) and
             (Pos(SearchText, LowerCase(Item.RelativePath)) = 0) and
             (Pos(SearchText, LowerCase(Item.Summary)) = 0) then
            Continue;

          Selected := I = fSceneFileBrowser.SelectedIndex;
          ImGui.PushId(I);
          if ImGui.Selectable(AnsiString(Item.DisplayName + '##scenefile' +
            IntToStr(I)), Selected) then
          begin
            fSceneFileBrowser.SelectedIndex := I;
            if fSceneFileBrowser.Mode = sfbSaveScene then
            begin
              SetAnsiBuffer(fSceneFileBrowser.FileName,
                ExtractFileName(Item.FileName));
              fSceneFileBrowser.PendingOverwrite := False;
              fSceneFileBrowser.PendingOverwriteFileName := '';
              fSceneFileBrowser.LastError := '';
            end;
          end;

          ImGui.TextWrapped(AnsiString(Item.Summary));
          ImGui.TextWrapped(AnsiString(Item.RelativePath));
          ImGui.Separator;
          ImGui.PopId;
        end;
      end;
      ImGui.EndChild;
    end;
    ImGui.EndChild;
    ImGui.EndPopup;
  end;

  if not OpenWindow then
    ResetSceneFileBrowser;
end;

procedure TSandBoxForm.SelectObjectFromImGui(Obj: TSceneObject);
var
  Meshes: TMeshList;
begin
  if Obj = nil then
    Exit;

  if Obj.IsGizmo then
    Exit;

  fSelectedObject := Obj;
  fSelectedMesh := nil;
  fSelectedMeshIndex := -1;
  fSelectedParticleSystemIndex := -1;
  fSelectedBillboardIndex := -1;
  fSelectedAnimatedSpriteIndex := -1;
  fSelectedAudioEmitterIndex := -1;

  Meshes := Obj.EffectiveMeshList;
  if Assigned(Meshes) and (Meshes.Count > 0) then
    SelectMeshIndex(0);
  if Obj.ParticleSystemCount > 0 then
    SelectParticleSystemIndex(0);
  if Obj.BillboardCount > 0 then
    SelectBillboardIndex(0);
  if Obj.AnimatedSpriteCount > 0 then
    SelectAnimatedSpriteIndex(0);
  if Obj.AudioEmitterCount > 0 then
    SelectAudioEmitterIndex(0);

  RefreshGizmo;
  RequestRender;
end;

procedure TSandBoxForm.FocusCameraOnSceneObject(Obj: TSceneObject);
begin
  if Obj = nil then
    Exit;

  if Obj.IsGizmo then
    Exit;

  if Assigned(fSceneManager) then
    fSceneManager.Update
  else if Assigned(fRoot) then
    fRoot.UpdateWorldMatrices
  else
    Obj.UpdateWorldMatrices;

  fOrbitTarget := Vector3(Obj.WorldMatrix.Columns[3]);
  if Assigned(fRenderer) then
    fRenderer.ShadowTarget := fOrbitTarget;

  RequestRender;
end;

procedure TSandBoxForm.OpenViewportObjectContextPopup(X, Y: Integer; Obj: TSceneObject);
begin
  if Obj = nil then
    Exit;

  fViewportObjectPopupObject := Obj;
  fViewportObjectPopupPos := Point(X, Y);
  fViewportObjectPopupPending := True;
  RequestRender;
end;

procedure TSandBoxForm.StartPhysicsSimulation;
begin
  if fEngine = nil then
    Exit;
  fEngine.StartPhysics;
  fPhysicsRunning := fEngine.PhysicsRunning;
  fPhysicsStatusMessage := Format('Physics running: %d active dynamic bodies.',
    [fPhysicsWorld.ActiveSimulationBodyCount]);
  RequestRender;
end;

procedure TSandBoxForm.PausePhysicsSimulation;
begin
  if fEngine <> nil then
    fEngine.PausePhysics;
  fPhysicsRunning := False;
  fPhysicsStatusMessage := 'Physics paused.';
  RequestRender;
end;

procedure TSandBoxForm.StopPhysicsSimulation;
begin
  if fEngine <> nil then
    fEngine.StopPhysics;
  fPhysicsRunning := False;

  RefreshGizmo;
  fPhysicsStatusMessage := 'Physics stopped and restored to the start pose.';
  RequestRender;
end;

procedure TSandBoxForm.ResetPhysicsSimulation;
begin
  if fEngine <> nil then
    fEngine.ResetPhysics;
  fPhysicsRunning := False;

  RefreshGizmo;
  fPhysicsStatusMessage := 'Physics reset.';
  RequestRender;
end;

function TSandBoxForm.IsProtectedSceneObject(Obj: TSceneObject): Boolean;
begin
  Result := (Obj = nil) or Obj.IsGizmo or (Obj = fRoot) or
    (Obj = fSceneWorld) or (Obj = fCamera);
end;

function TSandBoxForm.CanUseSceneObjectAsParent(Obj: TSceneObject): Boolean;
begin
  Result := False;
  if Obj = nil then
    Exit;

  Result := (not Obj.IsGizmo) and (Obj <> fRoot) and (Obj <> fCamera);
end;

procedure TSandBoxForm.CopySelectedObjectToClipboard;
var
  Body: TPhysicsBody;
begin
  if IsProtectedSceneObject(fSelectedObject) then
  begin
    LogLine('Select a regular object before copying.');
    Exit;
  end;

  FreeAndNil(fObjectClipboard);
  fObjectClipboard := fSelectedObject.Clone;
  fObjectClipboardBaseName := fSelectedObject.Name;
  fObjectClipboardPhysicsValid := False;

  if Assigned(fPhysicsWorld) then
  begin
    Body := fPhysicsWorld.FindBody(fSelectedObject);
    if Body <> nil then
    begin
      fObjectClipboardPhysicsState := Body.GetState;
      fObjectClipboardPhysicsValid := True;
    end;
  end;

  LogLine('Copied object: ' + fSelectedObject.Name);
end;

procedure TSandBoxForm.CutSelectedObjectToClipboard;
var
  CutObj: TSceneObject;
  CutName: string;
begin
  CutObj := fSelectedObject;
  if IsProtectedSceneObject(CutObj) then
  begin
    LogLine('Select a regular object before cutting.');
    Exit;
  end;

  CutName := CutObj.Name;
  CopySelectedObjectToClipboard;
  if fObjectClipboard = nil then
    Exit;

  DeleteObjectFromImGui(CutObj);
  LogLine('Cut object: ' + CutName);
end;

procedure TSandBoxForm.PasteObjectFromClipboard;
var
  ParentObj: TSceneObject;
  NewObj: TSceneObject;
  BaseName: string;
  Body: TPhysicsBody;
begin
  if fObjectClipboard = nil then
  begin
    LogLine('Copy an object before pasting.');
    Exit;
  end;

  ParentObj := nil;
  if CanUseSceneObjectAsParent(fSelectedObject) then
    ParentObj := fSelectedObject;

  if (ParentObj = nil) or (ParentObj = fRoot) then
    ParentObj := fSceneWorld;
  if ParentObj = nil then
    ParentObj := fRoot;
  if ParentObj = nil then
    Exit;

  NewObj := fObjectClipboard.Clone;
  try
    BaseName := Trim(fObjectClipboardBaseName);
    if BaseName = '' then
      BaseName := 'Object';

    NewObj.Name := MakeUniqueObjectName(ParentObj, BaseName + '_Copy');
    ParentObj.AttachObject(ParentObj.Count, NewObj);
    if NewObj.LightsCount > 0 then
      EnsureLightBillboards(NewObj);
    NewObj.NotifyChange;

    if fObjectClipboardPhysicsValid then
    begin
      if fPhysicsWorld = nil then
        raise Exception.Create('The game engine physics world is not available.');
      fPhysicsWorld.SceneRoot := fRoot;

      Body := fPhysicsWorld.AddBody(NewObj, fObjectClipboardPhysicsState.BodyType,
        fObjectClipboardPhysicsState.ColliderKind);
      Body.ApplyState(fObjectClipboardPhysicsState);
    end;
  except
    on E: Exception do
    begin
      NewObj.Free;
      LogLine('Could not paste object: ' + E.Message);
      Exit;
    end;
  end;

  if NewObj.LightsCount > 0 then
  begin
    if fLight = nil then
      fLight := NewObj;
    if Assigned(fRenderer) and (fRenderer.ShadowLight = nil) then
      fRenderer.ShadowLight := fLight;
  end;

  SelectObjectFromImGui(NewObj);
  LogLine('Pasted object: ' + NewObj.Name);
end;

function TSandBoxForm.CloneObjectForGizmo(SourceObj: TSceneObject): TSceneObject;
var
  ParentObj: TSceneObject;
  NewObj: TSceneObject;
  SourceBody: TPhysicsBody;
  ClonedBody: TPhysicsBody;
  PhysicsState: TPhysicsBodyState;
  InsertIndex: Integer;
  BaseName: string;
begin
  Result := nil;
  if IsProtectedSceneObject(SourceObj) then
    Exit;

  ParentObj := SourceObj.Parent;
  if ParentObj = nil then
    Exit;

  NewObj := SourceObj.Clone;
  try
    BaseName := Trim(SourceObj.Name);
    if BaseName = '' then
      BaseName := 'Object';

    InsertIndex := ParentObj.IndexOfObject(SourceObj);
    if InsertIndex < 0 then
      InsertIndex := ParentObj.Count
    else
      Inc(InsertIndex);

    NewObj.Name := MakeUniqueObjectName(ParentObj, BaseName + '_Copy');
    ParentObj.AttachObject(InsertIndex, NewObj);
    if NewObj.LightsCount > 0 then
      EnsureLightBillboards(NewObj);
    NewObj.NotifyChange;

    if Assigned(fPhysicsWorld) then
    begin
      SourceBody := fPhysicsWorld.FindBody(SourceObj);
      if SourceBody <> nil then
      begin
        PhysicsState := SourceBody.GetState;
        fPhysicsWorld.SceneRoot := fRoot;
        ClonedBody := fPhysicsWorld.AddBody(NewObj, PhysicsState.BodyType,
          PhysicsState.ColliderKind);
        ClonedBody.ApplyState(PhysicsState);
      end;
    end;
  except
    on E: Exception do
    begin
      NewObj.Free;
      LogLine('Could not clone object: ' + E.Message);
      Exit;
    end;
  end;

  SelectObjectFromImGui(NewObj);
  LogLine('Cloned object: ' + NewObj.Name);
  Result := NewObj;
end;

function TSandBoxForm.CanReparentSceneObject(SourceObj,
  ParentObj: TSceneObject): Boolean;
begin
  Result := False;
  if IsProtectedSceneObject(SourceObj) then
    Exit;
  if not CanUseSceneObjectAsParent(ParentObj) then
    Exit;
  if SourceObj = ParentObj then
    Exit;
  if ParentObj.IsDescendantOf(SourceObj) then
    Exit;

  Result := True;
end;

procedure TSandBoxForm.MoveSceneObjectToParent(SourceObj, ParentObj: TSceneObject);
var
  OldParent: TSceneObject;
  OldPath: string;
begin
  if SourceObj = ParentObj then
    Exit;

  if not CanReparentSceneObject(SourceObj, ParentObj) then
  begin
    LogLine('Cannot move object there.');
    Exit;
  end;

  OldParent := SourceObj.Parent;
  OldPath := SceneObjectPath(SourceObj);
  if OldParent <> ParentObj then
    SourceObj.Name := MakeUniqueObjectName(ParentObj, SourceObj.Name);

  ParentObj.AttachObject(ParentObj.Count, SourceObj);
  SourceObj.NotifyChange;
  ParentObj.NotifyChange;

  if Assigned(fPhysicsWorld) then
    fPhysicsWorld.MarkObjectDirty(SourceObj, True);

  SelectObjectFromImGui(SourceObj);
  LogLine(Format('Moved object "%s" under "%s".', [OldPath, SceneObjectPath(ParentObj)]));
end;

procedure TSandBoxForm.CreateInstanceFromSelectedObject;
var
  SourceObj: TSceneObject;
  ParentObj: TSceneObject;
  NewObj: TSceneObject;
  BaseName: string;
begin
  SourceObj := fSelectedObject;
  if IsProtectedSceneObject(SourceObj) then
  begin
    LogLine('Select a regular object before creating an instance.');
    Exit;
  end;

  if not SourceObj.HasGeometry then
  begin
    LogLine('Selected object has no geometry to instance.');
    Exit;
  end;

  ParentObj := SourceObj.Parent;
  if (ParentObj = nil) or (ParentObj = fRoot) then
    ParentObj := fSceneWorld;
  if ParentObj = nil then
    ParentObj := fRoot;
  if ParentObj = nil then
    Exit;

  NewObj := TSceneObject.Create(ParentObj);
  try
    BaseName := Trim(SourceObj.Name);
    if BaseName = '' then
      BaseName := 'Object';

    NewObj.Name := MakeUniqueObjectName(ParentObj, BaseName + '_Instance');
    NewObj.Position := SourceObj.Position + Vector3(1.5, 0.0, 0.0);
    NewObj.Scale := SourceObj.Scale;
    NewObj.Orientation := SourceObj.Orientation;
    NewObj.MakeInstanceOf(SourceObj);
    NewObj.NotifyChange;
  except
    on E: Exception do
    begin
      NewObj.Free;
      LogLine('Could not create instance: ' + E.Message);
      Exit;
    end;
  end;

  if Assigned(fPhysicsWorld) then
    fPhysicsWorld.MarkObjectDirty(NewObj, False);

  SelectObjectFromImGui(NewObj);
  LogLine(Format('Created instance "%s" from "%s".', [NewObj.Name, SourceObj.Name]));
end;

procedure TSandBoxForm.DeleteObjectFromImGui(Obj: TSceneObject);
var
  ParentObj: TSceneObject;
  Meshes: TMeshList;
begin
  if Obj = nil then
    Exit;

  if IsProtectedSceneObject(Obj) then
  begin
    LogLine('Cannot delete root scene or camera.');
    Exit;
  end;

  ParentObj := Obj.Parent;

  if fSelectedObject = Obj then
    fSelectedObject := ParentObj;

  if Assigned(fLight) and ((fLight = Obj) or fLight.IsDescendantOf(Obj)) then
    fLight := nil;

  if Assigned(fRenderer) and Assigned(fRenderer.ShadowLight) and
     ((fRenderer.ShadowLight = Obj) or fRenderer.ShadowLight.IsDescendantOf(Obj)) then
    fRenderer.ShadowLight := nil;

  fSelectedMesh := nil;
  fSelectedMeshIndex := -1;
  fSelectedParticleSystemIndex := -1;
  fSelectedBillboardIndex := -1;
  fSelectedAnimatedSpriteIndex := -1;
  fSelectedAudioEmitterIndex := -1;

  ReleaseSceneObjectAudio(Obj);

  if Assigned(fPhysicsWorld) then
    fPhysicsWorld.RemoveBodiesForScene(Obj, True);

  Obj.Free;

  if fLight = nil then
    fLight := FindFirstLightSceneObject(fRoot);
  if Assigned(fRenderer) and (fRenderer.ShadowLight = nil) then
    fRenderer.ShadowLight := fLight;

  if Assigned(fSelectedObject) then
  begin
    Meshes := fSelectedObject.EffectiveMeshList;
    if Assigned(Meshes) and (Meshes.Count > 0) then
      SelectMeshIndex(0);
    if fSelectedObject.ParticleSystemCount > 0 then
      SelectParticleSystemIndex(0);
    if fSelectedObject.BillboardCount > 0 then
      SelectBillboardIndex(0);
    if fSelectedObject.AnimatedSpriteCount > 0 then
      SelectAnimatedSpriteIndex(0);
    if fSelectedObject.AudioEmitterCount > 0 then
      SelectAudioEmitterIndex(0);
  end;

  RefreshGizmo;
  RequestRender;
end;

procedure TSandBoxForm.SetGizmoModeFromToolbar(AMode: TGizmoMode);
begin
  if fGizmoMode = AMode then
    Exit;

  fGizmoMode := AMode;
  RefreshGizmo;
  RequestRender;
end;

procedure TSandBoxForm.SelectMeshIndex(const MeshIndex: Integer);
var
  Meshes: TMeshList;
begin
  Meshes := nil;
  if fSelectedObject <> nil then
    Meshes := fSelectedObject.EffectiveMeshList;

  if (fSelectedObject = nil) or (Meshes = nil) or
     (MeshIndex < 0) or (MeshIndex >= Meshes.Count) then
  begin
    fSelectedMeshIndex := -1;
    fSelectedMesh := nil;
    if fEditSelectedMeshTransform then
      RefreshGizmo;
    Exit;
  end;

  fSelectedMeshIndex := MeshIndex;
  fSelectedMesh := Meshes.Item[MeshIndex];

  if fEditSelectedMeshTransform then
    RefreshGizmo;

  RequestRender;
end;

procedure TSandBoxForm.SelectParticleSystemIndex(const ParticleSystemIndex: Integer);
begin
  if (fSelectedObject = nil) or fSelectedObject.IsGizmo or
     (ParticleSystemIndex < 0) or
     (ParticleSystemIndex >= fSelectedObject.ParticleSystemCount) then
  begin
    fSelectedParticleSystemIndex := -1;
    Exit;
  end;

  fSelectedParticleSystemIndex := ParticleSystemIndex;
  RequestRender;
end;

procedure TSandBoxForm.SelectBillboardIndex(const BillboardIndex: Integer);
begin
  if (fSelectedObject = nil) or fSelectedObject.IsGizmo or
     (BillboardIndex < 0) or
     (BillboardIndex >= fSelectedObject.BillboardCount) then
  begin
    fSelectedBillboardIndex := -1;
    Exit;
  end;

  fSelectedBillboardIndex := BillboardIndex;
  RequestRender;
end;

procedure TSandBoxForm.SelectAnimatedSpriteIndex(
  const AnimatedSpriteIndex: Integer);
begin
  if (fSelectedObject = nil) or fSelectedObject.IsGizmo or
     (AnimatedSpriteIndex < 0) or
     (AnimatedSpriteIndex >= fSelectedObject.AnimatedSpriteCount) then
  begin
    fSelectedAnimatedSpriteIndex := -1;
    Exit;
  end;

  fSelectedAnimatedSpriteIndex := AnimatedSpriteIndex;
  RequestRender;
end;

procedure TSandBoxForm.SelectAudioEmitterIndex(const AudioEmitterIndex: Integer);
begin
  if (fSelectedObject = nil) or fSelectedObject.IsGizmo or
     (AudioEmitterIndex < 0) or
     (AudioEmitterIndex >= fSelectedObject.AudioEmitterCount) then
  begin
    fSelectedAudioEmitterIndex := -1;
    Exit;
  end;

  fSelectedAudioEmitterIndex := AudioEmitterIndex;
  RequestRender;
end;

procedure TSandBoxForm.DeleteSelectedMesh;
var
  DeleteIndex: Integer;
begin
  if (fSelectedObject = nil) or (fSelectedMeshIndex < 0) then
    Exit;

  if fSelectedObject.IsInstance then
  begin
    LogLine('Convert the instance to a unique object before deleting shared meshes.');
    Exit;
  end;

  DeleteIndex := fSelectedMeshIndex;
  fSelectedObject.MeshList.DeleteMesh(DeleteIndex);
  fSelectedObject.UpdateBoundingRadiusFromMesh;
  fSelectedObject.NotifyChange;

  if DeleteIndex >= fSelectedObject.MeshList.Count then
    DeleteIndex := fSelectedObject.MeshList.Count - 1;

  SelectMeshIndex(DeleteIndex);
end;

procedure TSandBoxForm.DeleteSelectedParticleSystem;
var
  DeleteIndex: Integer;
begin
  if (fSelectedObject = nil) or (fSelectedParticleSystemIndex < 0) then
    Exit;

  DeleteIndex := fSelectedParticleSystemIndex;
  if not fSelectedObject.RemoveParticleSystem(DeleteIndex) then
    Exit;

  if DeleteIndex >= fSelectedObject.ParticleSystemCount then
    DeleteIndex := fSelectedObject.ParticleSystemCount - 1;
  SelectParticleSystemIndex(DeleteIndex);
  LogLine('Particle system removed from object: ' + fSelectedObject.Name);
  NotifyInspectorObjectEdited;
end;

procedure TSandBoxForm.DeleteSelectedBillboard;
var
  DeleteIndex: Integer;
begin
  if (fSelectedObject = nil) or (fSelectedBillboardIndex < 0) then
    Exit;

  DeleteIndex := fSelectedBillboardIndex;
  if not fSelectedObject.RemoveBillboard(DeleteIndex) then
    Exit;

  if DeleteIndex >= fSelectedObject.BillboardCount then
    DeleteIndex := fSelectedObject.BillboardCount - 1;
  SelectBillboardIndex(DeleteIndex);
  LogLine('Billboard removed from object: ' + fSelectedObject.Name);
  NotifyInspectorObjectEdited;
end;

procedure TSandBoxForm.DeleteSelectedAnimatedSprite;
var
  DeleteIndex: Integer;
begin
  if (fSelectedObject = nil) or (fSelectedAnimatedSpriteIndex < 0) then
    Exit;

  DeleteIndex := fSelectedAnimatedSpriteIndex;
  if not fSelectedObject.RemoveAnimatedSprite(DeleteIndex) then
    Exit;

  if DeleteIndex >= fSelectedObject.AnimatedSpriteCount then
    DeleteIndex := fSelectedObject.AnimatedSpriteCount - 1;
  SelectAnimatedSpriteIndex(DeleteIndex);
  LogLine('Animated sprite removed from object: ' + fSelectedObject.Name);
  NotifyInspectorObjectEdited;
end;

procedure TSandBoxForm.DeleteSelectedAudioEmitter;
var
  DeleteIndex: Integer;
  Emitter: TSceneAudioEmitter;
begin
  if (fSelectedObject = nil) or (fSelectedAudioEmitterIndex < 0) then
    Exit;

  DeleteIndex := fSelectedAudioEmitterIndex;
  Emitter := fSelectedObject.AudioEmitterItem[DeleteIndex];
  ReleaseSceneAudioEmitter(Emitter);
  if not fSelectedObject.RemoveAudioEmitter(DeleteIndex) then
    Exit;

  if DeleteIndex >= fSelectedObject.AudioEmitterCount then
    DeleteIndex := fSelectedObject.AudioEmitterCount - 1;
  SelectAudioEmitterIndex(DeleteIndex);
  LogLine('Audio emitter removed from object: ' + fSelectedObject.Name);
  NotifyInspectorObjectEdited;
end;

function TSandBoxForm.MaterialLibraryDisplayName(ALib: TMaterialLibrary;
  Index: Integer): string;
begin
  if ALib = nil then
    Exit(Format('Library %d <nil>', [Index]));

  Result := Trim(ALib.Name);

  if Result = '' then
    Result := Format('Library %d', [Index]);
end;

function TSandBoxForm.MaterialDisplayName(AMat: TMaterial; Index: Integer): string;
begin
  if AMat = nil then
    Exit(Format('Material %d <nil>', [Index]));

  Result := Trim(AMat.Name);

  if Result = '' then
    Result := Format('Material %d', [Index]);
end;

function TSandBoxForm.MaterialLibraryIndexOf(ALib: TMaterialLibrary): Integer;
var
  I: Integer;
begin
  Result := -1;

  if (MaterialLibraries = nil) or (ALib = nil) then
    Exit;

  for I := 0 to MaterialLibraries.Count - 1 do
    if MaterialLibraries.MaterialLibrary[I] = ALib then
      Exit(I);
end;

function TSandBoxForm.MaterialIndexInLibrary(ALib: TMaterialLibrary;
  const MaterialName: string): Integer;
var
  I: Integer;
begin
  Result := -1;

  if ALib = nil then
    Exit;

  for I := 0 to ALib.Count - 1 do
    if Assigned(ALib.Material[I]) and SameText(ALib.Material[I].Name, MaterialName) then
      Exit(I);
end;

function TSandBoxForm.FirstRenderableMaterialIndex(ALib: TMaterialLibrary): Integer;
var
  I: Integer;
begin
  Result := -1;

  if ALib = nil then
    Exit;

  for I := 0 to ALib.Count - 1 do
    if Assigned(ALib.Material[I]) and not IsEditorOnlyMaterial(ALib.Material[I]) then
      Exit(I);
end;

procedure TSandBoxForm.AssignMaterialToSelectedMesh(ALib: TMaterialLibrary;
  AMat: TMaterial);
begin
  if fSelectedMesh = nil then
    Exit;

  if (ALib = nil) or (AMat = nil) then
    Exit;

  if IsEditorOnlyMaterial(AMat) then
    Exit;

  AssignShaderToMaterial(AMat);

  fSelectedMesh.MaterialLibrary := ALib;
  fSelectedMesh.LibMaterialname := AMat.Name;
  fSelectedMesh.OnRender := MeshRenderHandler;

  if Assigned(fSelectedObject) then
    fSelectedObject.NotifyChange;

  LogLine(Format('Assigned material "%s" to mesh "%s".',
    [AMat.Name, fSelectedMesh.Name]));

  RequestRender;
end;

procedure TSandBoxForm.AssignMaterialToSelectedObject(ALib: TMaterialLibrary;
  AMat: TMaterial);
var
  I: Integer;
  Mesh: TMesh;
  Meshes: TMeshList;
begin
  if fSelectedObject = nil then
    Exit;

  if (ALib = nil) or (AMat = nil) then
    Exit;

  if IsEditorOnlyMaterial(AMat) then
    Exit;

  AssignShaderToMaterial(AMat);

  Meshes := fSelectedObject.EffectiveMeshList;
  if not Assigned(Meshes) then
    Exit;

  for I := 0 to Meshes.Count - 1 do
  begin
    Mesh := Meshes.Item[I];

    if Mesh = nil then
      Continue;

    Mesh.MaterialLibrary := ALib;
    Mesh.LibMaterialname := AMat.Name;
    Mesh.OnRender := MeshRenderHandler;
  end;

  fSelectedObject.NotifyChange;

  LogLine(Format('Assigned material "%s" to all meshes in object "%s".',
    [AMat.Name, fSelectedObject.Name]));

  RequestRender;
end;

procedure TSandBoxForm.DrawImGuiMaterialAssignment;
var
  I: Integer;
  Lib: TMaterialLibrary;
  Mat: TMaterial;
  CurrentLib: TMaterialLibrary;
  CurrentLibIndex: Integer;
  CurrentMatIndex: Integer;
  NewMatIndex: Integer;
  LabelText: string;
begin
  if fSelectedMesh = nil then
    Exit;

  if MaterialLibraries = nil then
    Exit;

  CurrentLib := fSelectedMesh.MaterialLibrary;

  if CurrentLib = nil then
  begin
    CurrentLib := EnsureDefaultMaterialLibrary;
    fSelectedMesh.MaterialLibrary := CurrentLib;
  end;

  CurrentLibIndex := MaterialLibraryIndexOf(CurrentLib);
  CurrentMatIndex := MaterialIndexInLibrary(CurrentLib, fSelectedMesh.LibMaterialname);

  ImGui.Separator;

  if ImGui.TreeNode('Material') then
  begin
    ImGui.Text(PAnsiChar(AnsiString('Mesh: ' + fSelectedMesh.Name)));

    if CurrentLib <> nil then
      ImGui.Text(PAnsiChar(AnsiString('Library: ' + MaterialLibraryDisplayName(CurrentLib, CurrentLibIndex))))
    else
      ImGui.Text('Library: <none>');

    if CurrentMatIndex >= 0 then
      ImGui.Text(PAnsiChar(AnsiString('Material: ' + MaterialDisplayName(CurrentLib.Material[CurrentMatIndex], CurrentMatIndex))))
    else
      ImGui.Text(PAnsiChar(AnsiString('Material: ' + fSelectedMesh.LibMaterialname + ' <not found>')));

    ImGui.Separator;

    ImGui.Text('Material Library');

    if ImGui.BeginListBox('##MaterialLibraries', ImVec2.New(-1, 85)) then
    begin
      for I := 0 to MaterialLibraries.Count - 1 do
      begin
        Lib := MaterialLibraries.MaterialLibrary[I];

        if Lib = nil then
          Continue;

        LabelText := MaterialLibraryDisplayName(Lib, I) + '##matlib' + IntToStr(I);

        if ImGui.Selectable(PAnsiChar(AnsiString(LabelText)), I = CurrentLibIndex) then
        begin
          CurrentLib := Lib;
          CurrentLibIndex := I;
          fSelectedMesh.MaterialLibrary := CurrentLib;

          if MaterialIndexInLibrary(CurrentLib, fSelectedMesh.LibMaterialname) < 0 then
          begin
            NewMatIndex := FirstRenderableMaterialIndex(CurrentLib);

            if NewMatIndex >= 0 then
              AssignMaterialToSelectedMesh(CurrentLib, CurrentLib.Material[NewMatIndex])
            else
              RequestRender;
          end
          else
            RequestRender;
        end;
      end;

      ImGui.EndListBox;
    end;

    ImGui.Text('Material');

    if CurrentLib <> nil then
    begin
      CurrentMatIndex := MaterialIndexInLibrary(CurrentLib, fSelectedMesh.LibMaterialname);

      if ImGui.BeginListBox('##Materials', ImVec2.New(-1, 120)) then
      begin
        for I := 0 to CurrentLib.Count - 1 do
        begin
          Mat := CurrentLib.Material[I];

          if Mat = nil then
            Continue;

          if IsEditorOnlyMaterial(Mat) then
            Continue;

          LabelText := MaterialDisplayName(Mat, I) + '##mat' + IntToStr(I);

          if ImGui.Selectable(PAnsiChar(AnsiString(LabelText)), I = CurrentMatIndex) then
            AssignMaterialToSelectedMesh(CurrentLib, Mat);
        end;

        ImGui.EndListBox;
      end;

      ImGui.Text('Click a material below to');
      ImGui.Text('assign it only to the selected mesh.');
      if ImGui.Button('Apply material to all meshes in selected object') then
      begin
        CurrentMatIndex := MaterialIndexInLibrary(CurrentLib, fSelectedMesh.LibMaterialname);

        if CurrentMatIndex >= 0 then
          AssignMaterialToSelectedObject(CurrentLib, CurrentLib.Material[CurrentMatIndex]);
      end;
    end
    else
      ImGui.Text('No material library.');

    ImGui.TreePop;
  end;
end;

procedure TSandBoxForm.SetupRenderableMesh(Mesh: TMesh);
begin
  if fEngine <> nil then
  begin
    fEngine.SetupRenderableMesh(Mesh);
    Exit;
  end;

  if Mesh = nil then
    Exit;

  Mesh.MaterialLibrary := EnsureDefaultMaterialLibrary;
  Mesh.LibMaterialname := DefaultRenderableMaterialName;
  Mesh.OnRender := MeshRenderHandler;
end;

function TSandBoxForm.PrimitiveKindDisplayName(AKind: TPrimitiveKind): string;
begin
  case AKind of
    pkCube: Result := 'Cube';
    pkPlane: Result := 'Plane';
    pkWaterPlane: Result := 'Water Plane';
    pkSphere: Result := 'Sphere';
    pkCylinder: Result := 'Cylinder';
    pkCapsule: Result := 'Capsule';
    pkTorus: Result := 'Torus';
    pkCone: Result := 'Cone';
    pkPrism: Result := 'Prism';
    pkFrustum: Result := 'Frustum';
    pkIcosphere: Result := 'Icosphere';
    pkGeodesicDome: Result := 'Geodesic Dome';
    pkArrow: Result := 'Arrow';
    pkSuperEllipsoid: Result := 'Super Ellipsoid';
  else
    Result := 'Primitive';
  end;
end;

function TSandBoxForm.PrimitiveBaseName(AKind: TPrimitiveKind): string;
begin
  case AKind of
    pkWaterPlane: Result := 'WaterPlane';
    pkGeodesicDome: Result := 'GeodesicDome';
    pkSuperEllipsoid: Result := 'SuperEllipsoid';
  else
    Result := StringReplace(PrimitiveKindDisplayName(AKind), ' ', '', [rfReplaceAll]);
  end;
end;

function TSandBoxForm.TryGetPrimitiveKindForMesh(Mesh: TMesh;
  out AKind: TPrimitiveKind): Boolean;
begin
  Result := True;

  if Mesh is TWaterPlaneMesh then
    AKind := pkWaterPlane
  else if Mesh is TCubeMesh then
    AKind := pkCube
  else if Mesh is TPlaneMesh then
    AKind := pkPlane
  else if Mesh is TSphereMesh then
    AKind := pkSphere
  else if Mesh is TCapsuleMesh then
    AKind := pkCapsule
  else if Mesh is TCylinderMesh then
    AKind := pkCylinder
  else if Mesh is TTorusMesh then
    AKind := pkTorus
  else if Mesh is TConeMesh then
    AKind := pkCone
  else if Mesh is TPrismMesh then
    AKind := pkPrism
  else if Mesh is TFrustumMesh then
    AKind := pkFrustum
  else if Mesh is TIcosphereMesh then
    AKind := pkIcosphere
  else if Mesh is TGeodesicDomeMesh then
    AKind := pkGeodesicDome
  else if Mesh is TArrowMesh then
    AKind := pkArrow
  else if Mesh is TSuperEllipsoidMesh then
    AKind := pkSuperEllipsoid
  else
    Result := False;
end;

function TSandBoxForm.CreateDefaultPrimitiveMesh(AKind: TPrimitiveKind;
  const MeshName: string): TMesh;
begin
  Result := nil;

  case AKind of
    pkCube:
      Result := TMeshFactory.CreateCube(1, 1, 1, 1, 1, 1, MeshName);

    pkPlane:
      Result := TMeshFactory.CreatePlane(10, 10, 1, 1, MeshName);

    pkWaterPlane:
      Result := TMeshFactory.CreateWaterPlane(20, 20, 64, 64, MeshName);

    pkSphere:
      Result := TMeshFactory.CreateSphere(1, 24, 32, MeshName);

    pkCylinder:
      Result := TMeshFactory.CreateCylinder(0.5, 1, 32, 1, MeshName);

    pkCapsule:
      Result := TMeshFactory.CreateCapsule(0.5, 1, 32, 8, MeshName);

    pkTorus:
      Result := TMeshFactory.CreateTorus(0.75, 0.25, 48, 16, MeshName);

    pkCone:
      Result := TMeshFactory.CreateCone(0.5, 1, 32, 1, MeshName);

    pkPrism:
      Result := TMeshFactory.CreatePrism(0.5, 1, 6, 1, MeshName);

    pkFrustum:
      Result := TMeshFactory.CreateFrustum(0.6, 0.3, 1, 32, 1, ctFlat, ctFlat, MeshName);

    pkIcosphere:
      Result := TMeshFactory.CreateIcosphere(1, 2, MeshName);

    pkGeodesicDome:
      Result := TMeshFactory.CreateGeodesicDome(1, 2, MeshName);

    pkArrow:
      Result := TMeshFactory.CreateArrow(0.8, 0.2, 0.03, 0.08, 16, 1, MeshName);

    pkSuperEllipsoid:
      Result := TMeshFactory.CreateSuperellipsoid(1, 1, 1, 32, 16, MeshName);
  end;

  SetupRenderableMesh(Result);
end;

procedure TSandBoxForm.InitPrimitiveEditorDefaults(AKind: TPrimitiveKind; Mesh: TMesh);
begin
  fMeshEditor.Kind := AKind;

  fMeshEditor.Width := 1.0;
  fMeshEditor.Height := 1.0;
  fMeshEditor.Depth := 1.0;
  fMeshEditor.Radius := 1.0;
  fMeshEditor.BottomRadius := 0.6;
  fMeshEditor.TopRadius := 0.3;
  fMeshEditor.MajorRadius := 0.75;
  fMeshEditor.MinorRadius := 0.25;
  fMeshEditor.ShaftLength := 0.8;
  fMeshEditor.TipLength := 0.2;
  fMeshEditor.ShaftRadius := 0.03;
  fMeshEditor.TipRadius := 0.08;
  fMeshEditor.VCurve := 1.0;
  fMeshEditor.HCurve := 1.0;

  fMeshEditor.WidthSegments := 1;
  fMeshEditor.HeightSegments := 1;
  fMeshEditor.DepthSegments := 1;
  fMeshEditor.Slices := 32;
  fMeshEditor.Stacks := 1;
  fMeshEditor.Sides := 6;
  fMeshEditor.StackCount := 24;
  fMeshEditor.SliceCount := 32;
  fMeshEditor.MajorSegments := 48;
  fMeshEditor.MinorSegments := 16;
  fMeshEditor.Subdivisions := 2;
  fMeshEditor.WaterTintColor[0] := 0.03;
  fMeshEditor.WaterTintColor[1] := 0.28;
  fMeshEditor.WaterTintColor[2] := 0.36;
  fMeshEditor.WaterTintColor[3] := 1.0;
  fMeshEditor.WaterDeepColor[0] := 0.0;
  fMeshEditor.WaterDeepColor[1] := 0.08;
  fMeshEditor.WaterDeepColor[2] := 0.12;
  fMeshEditor.WaterDeepColor[3] := 1.0;
  fMeshEditor.WaterReflectionStrength := 0.72;
  fMeshEditor.WaterWaveScale := 0.5;
  fMeshEditor.WaterWaveSpeed := 0.5;
  fMeshEditor.WaterWaveStrength := 0.35;
  fMeshEditor.WaterFresnelPower := 5.0;
  fMeshEditor.WaterAlpha := 0.82;

  case AKind of
    pkPlane:
      begin
        fMeshEditor.Width := 10.0;
        fMeshEditor.Depth := 10.0;
      end;

    pkWaterPlane:
      begin
        fMeshEditor.Width := 20.0;
        fMeshEditor.Depth := 20.0;
        fMeshEditor.WidthSegments := 64;
        fMeshEditor.DepthSegments := 64;
      end;

    pkSphere:
      begin
        fMeshEditor.StackCount := 24;
        fMeshEditor.SliceCount := 32;
      end;

    pkCapsule:
      fMeshEditor.Stacks := 8;
  end;

  if Mesh is TCubeMesh then
  begin
    fMeshEditor.Width := TCubeMesh(Mesh).Width;
    fMeshEditor.Height := TCubeMesh(Mesh).Height;
    fMeshEditor.Depth := TCubeMesh(Mesh).Depth;
    fMeshEditor.WidthSegments := TCubeMesh(Mesh).WidthStacks;
    fMeshEditor.HeightSegments := TCubeMesh(Mesh).HeightStacks;
    fMeshEditor.DepthSegments := TCubeMesh(Mesh).DepthStacks;
  end
  else if Mesh is TWaterPlaneMesh then
  begin
    fMeshEditor.Width := TWaterPlaneMesh(Mesh).Width;
    fMeshEditor.Depth := TWaterPlaneMesh(Mesh).Depth;
    fMeshEditor.WidthSegments := TWaterPlaneMesh(Mesh).WidthSegments;
    fMeshEditor.DepthSegments := TWaterPlaneMesh(Mesh).DepthSegments;
    fMeshEditor.WaterTintColor[0] := TWaterPlaneMesh(Mesh).TintColor.X;
    fMeshEditor.WaterTintColor[1] := TWaterPlaneMesh(Mesh).TintColor.Y;
    fMeshEditor.WaterTintColor[2] := TWaterPlaneMesh(Mesh).TintColor.Z;
    fMeshEditor.WaterTintColor[3] := TWaterPlaneMesh(Mesh).TintColor.W;
    fMeshEditor.WaterDeepColor[0] := TWaterPlaneMesh(Mesh).DeepColor.X;
    fMeshEditor.WaterDeepColor[1] := TWaterPlaneMesh(Mesh).DeepColor.Y;
    fMeshEditor.WaterDeepColor[2] := TWaterPlaneMesh(Mesh).DeepColor.Z;
    fMeshEditor.WaterDeepColor[3] := TWaterPlaneMesh(Mesh).DeepColor.W;
    fMeshEditor.WaterReflectionStrength := TWaterPlaneMesh(Mesh).ReflectionStrength;
    fMeshEditor.WaterWaveScale := TWaterPlaneMesh(Mesh).WaveScale;
    fMeshEditor.WaterWaveSpeed := TWaterPlaneMesh(Mesh).WaveSpeed;
    fMeshEditor.WaterWaveStrength := TWaterPlaneMesh(Mesh).WaveStrength;
    fMeshEditor.WaterFresnelPower := TWaterPlaneMesh(Mesh).FresnelPower;
    fMeshEditor.WaterAlpha := TWaterPlaneMesh(Mesh).Alpha;
  end
  else if Mesh is TPlaneMesh then
  begin
    fMeshEditor.Width := TPlaneMesh(Mesh).Width;
    fMeshEditor.Depth := TPlaneMesh(Mesh).Depth;
    fMeshEditor.WidthSegments := TPlaneMesh(Mesh).WidthSegments;
    fMeshEditor.DepthSegments := TPlaneMesh(Mesh).DepthSegments;
  end;

  if Mesh is TSphereMesh then
  begin
    fMeshEditor.Radius := TSphereMesh(Mesh).Radius;
    fMeshEditor.StackCount := TSphereMesh(Mesh).StackCount;
    fMeshEditor.SliceCount := TSphereMesh(Mesh).SliceCount;
  end
  else if Mesh is TCylinderMesh then
  begin
    fMeshEditor.Radius := TCylinderMesh(Mesh).Radius;
    fMeshEditor.Height := TCylinderMesh(Mesh).Height;
    fMeshEditor.Slices := TCylinderMesh(Mesh).Slices;
    fMeshEditor.Stacks := TCylinderMesh(Mesh).Stacks;
  end
  else if Mesh is TCapsuleMesh then
  begin
    fMeshEditor.Radius := TCapsuleMesh(Mesh).Radius;
    fMeshEditor.Height := TCapsuleMesh(Mesh).Height;
    fMeshEditor.Slices := TCapsuleMesh(Mesh).Slices;
    fMeshEditor.Stacks := TCapsuleMesh(Mesh).Stacks;
  end
  else if Mesh is TTorusMesh then
  begin
    fMeshEditor.MajorRadius := TTorusMesh(Mesh).MajorRadius;
    fMeshEditor.MinorRadius := TTorusMesh(Mesh).MinorRadius;
    fMeshEditor.MajorSegments := TTorusMesh(Mesh).MajorSegments;
    fMeshEditor.MinorSegments := TTorusMesh(Mesh).MinorSegments;
  end
  else if Mesh is TConeMesh then
  begin
    fMeshEditor.Radius := TConeMesh(Mesh).Radius;
    fMeshEditor.Height := TConeMesh(Mesh).Height;
    fMeshEditor.Sides := TConeMesh(Mesh).Sides;
    fMeshEditor.Stacks := TConeMesh(Mesh).Stacks;
  end
  else if Mesh is TPrismMesh then
  begin
    fMeshEditor.Radius := TPrismMesh(Mesh).Radius;
    fMeshEditor.Height := TPrismMesh(Mesh).Height;
    fMeshEditor.Sides := TPrismMesh(Mesh).Sides;
    fMeshEditor.Stacks := TPrismMesh(Mesh).Stacks;
  end
  else if Mesh is TFrustumMesh then
  begin
    fMeshEditor.BottomRadius := TFrustumMesh(Mesh).BottomRadius;
    fMeshEditor.TopRadius := TFrustumMesh(Mesh).TopRadius;
    fMeshEditor.Height := TFrustumMesh(Mesh).Height;
    fMeshEditor.Slices := TFrustumMesh(Mesh).Slices;
    fMeshEditor.Stacks := TFrustumMesh(Mesh).Stacks;
  end
  else if Mesh is TIcosphereMesh then
  begin
    fMeshEditor.Radius := TIcosphereMesh(Mesh).Radius;
    fMeshEditor.Subdivisions := TIcosphereMesh(Mesh).Subdivisions;
  end
  else if Mesh is TGeodesicDomeMesh then
  begin
    fMeshEditor.Radius := TGeodesicDomeMesh(Mesh).Radius;
    fMeshEditor.Subdivisions := TGeodesicDomeMesh(Mesh).Subdivisions;
  end
  else if Mesh is TArrowMesh then
  begin
    fMeshEditor.ShaftLength := TArrowMesh(Mesh).ShaftLength;
    fMeshEditor.TipLength := TArrowMesh(Mesh).TipLength;
    fMeshEditor.ShaftRadius := TArrowMesh(Mesh).ShaftRadius;
    fMeshEditor.TipRadius := TArrowMesh(Mesh).TipRadius;
    fMeshEditor.Slices := TArrowMesh(Mesh).Slices;
    fMeshEditor.Stacks := TArrowMesh(Mesh).Stacks;
  end
  else if Mesh is TSuperEllipsoidMesh then
  begin
    fMeshEditor.Radius := TSuperEllipsoidMesh(Mesh).Radius;
    fMeshEditor.VCurve := TSuperEllipsoidMesh(Mesh).VCurve;
    fMeshEditor.HCurve := TSuperEllipsoidMesh(Mesh).HCurve;
    fMeshEditor.Slices := TSuperEllipsoidMesh(Mesh).Slices;
    fMeshEditor.Stacks := TSuperEllipsoidMesh(Mesh).Stacks;
  end;
end;

function TSandBoxForm.CreatePrimitiveMeshFromEditor(const MeshName: string): TMesh;

  function Positive(var Value: Single): Single;
  begin
    if Value < 0.001 then
      Value := 0.001;
    Result := Value;
  end;

  function MinInt(var Value: Integer; const MinValue: Integer): Integer;
  begin
    if Value < MinValue then
      Value := MinValue;
    Result := Value;
  end;

  procedure ApplyWaterEditorSettings(Water: TWaterPlaneMesh);
  begin
    if Water = nil then
      Exit;

    Water.TintColor := Vector4(fMeshEditor.WaterTintColor[0],
      fMeshEditor.WaterTintColor[1], fMeshEditor.WaterTintColor[2],
      fMeshEditor.WaterTintColor[3]);
    Water.DeepColor := Vector4(fMeshEditor.WaterDeepColor[0],
      fMeshEditor.WaterDeepColor[1], fMeshEditor.WaterDeepColor[2],
      fMeshEditor.WaterDeepColor[3]);
    Water.ReflectionStrength := fMeshEditor.WaterReflectionStrength;
    Water.WaveScale := fMeshEditor.WaterWaveScale;
    Water.WaveSpeed := fMeshEditor.WaterWaveSpeed;
    Water.WaveStrength := fMeshEditor.WaterWaveStrength;
    Water.FresnelPower := fMeshEditor.WaterFresnelPower;
    Water.Alpha := fMeshEditor.WaterAlpha;
  end;

begin
  Result := nil;

  case fMeshEditor.Kind of
    pkCube:
      Result := TMeshFactory.CreateCube(
        Positive(fMeshEditor.Width),
        Positive(fMeshEditor.Height),
        Positive(fMeshEditor.Depth),
        MinInt(fMeshEditor.WidthSegments, 1),
        MinInt(fMeshEditor.HeightSegments, 1),
        MinInt(fMeshEditor.DepthSegments, 1),
        MeshName);

    pkPlane:
      Result := TMeshFactory.CreatePlane(
        Positive(fMeshEditor.Width),
        Positive(fMeshEditor.Depth),
        MinInt(fMeshEditor.WidthSegments, 1),
        MinInt(fMeshEditor.DepthSegments, 1),
        MeshName);

    pkWaterPlane:
      Result := TMeshFactory.CreateWaterPlane(
        Positive(fMeshEditor.Width),
        Positive(fMeshEditor.Depth),
        MinInt(fMeshEditor.WidthSegments, WATER_EDITOR_MIN_SEGMENTS),
        MinInt(fMeshEditor.DepthSegments, WATER_EDITOR_MIN_SEGMENTS),
        MeshName);

    pkSphere:
      Result := TMeshFactory.CreateSphere(
        Positive(fMeshEditor.Radius),
        MinInt(fMeshEditor.StackCount, 2),
        MinInt(fMeshEditor.SliceCount, 3),
        MeshName);

    pkCylinder:
      Result := TMeshFactory.CreateCylinder(
        Positive(fMeshEditor.Radius),
        Positive(fMeshEditor.Height),
        MinInt(fMeshEditor.Slices, 3),
        MinInt(fMeshEditor.Stacks, 1),
        MeshName);

    pkCapsule:
      Result := TMeshFactory.CreateCapsule(
        Positive(fMeshEditor.Radius),
        Positive(fMeshEditor.Height),
        MinInt(fMeshEditor.Slices, 3),
        MinInt(fMeshEditor.Stacks, 1),
        MeshName);

    pkTorus:
      Result := TMeshFactory.CreateTorus(
        Positive(fMeshEditor.MajorRadius),
        Positive(fMeshEditor.MinorRadius),
        MinInt(fMeshEditor.MajorSegments, 3),
        MinInt(fMeshEditor.MinorSegments, 3),
        MeshName);

    pkCone:
      Result := TMeshFactory.CreateCone(
        Positive(fMeshEditor.Radius),
        Positive(fMeshEditor.Height),
        MinInt(fMeshEditor.Sides, 3),
        MinInt(fMeshEditor.Stacks, 1),
        MeshName);

    pkPrism:
      Result := TMeshFactory.CreatePrism(
        Positive(fMeshEditor.Radius),
        Positive(fMeshEditor.Height),
        MinInt(fMeshEditor.Sides, 3),
        MinInt(fMeshEditor.Stacks, 1),
        MeshName);

    pkFrustum:
      Result := TMeshFactory.CreateFrustum(
        Positive(fMeshEditor.BottomRadius),
        Positive(fMeshEditor.TopRadius),
        Positive(fMeshEditor.Height),
        MinInt(fMeshEditor.Slices, 3),
        MinInt(fMeshEditor.Stacks, 1),
        ctFlat,
        ctFlat,
        MeshName);

    pkIcosphere:
      Result := TMeshFactory.CreateIcosphere(
        Positive(fMeshEditor.Radius),
        MinInt(fMeshEditor.Subdivisions, 0),
        MeshName);

    pkGeodesicDome:
      Result := TMeshFactory.CreateGeodesicDome(
        Positive(fMeshEditor.Radius),
        MinInt(fMeshEditor.Subdivisions, 0),
        MeshName);

    pkArrow:
      Result := TMeshFactory.CreateArrow(
        Positive(fMeshEditor.ShaftLength),
        Positive(fMeshEditor.TipLength),
        Positive(fMeshEditor.ShaftRadius),
        Positive(fMeshEditor.TipRadius),
        MinInt(fMeshEditor.Slices, 3),
        MinInt(fMeshEditor.Stacks, 1),
        MeshName);

    pkSuperEllipsoid:
      Result := TMeshFactory.CreateSuperellipsoid(
        Positive(fMeshEditor.Radius),
        Positive(fMeshEditor.VCurve),
        Positive(fMeshEditor.HCurve),
        MinInt(fMeshEditor.Slices, 3),
        MinInt(fMeshEditor.Stacks, 2),
        MeshName);
  end;

  if Result is TWaterPlaneMesh then
    ApplyWaterEditorSettings(TWaterPlaneMesh(Result));
end;

procedure TSandBoxForm.DrawAddObjectMenuItems;
begin
  if ImGui.MenuItem('Empty Object') then
    BeginCreateEmptyObjectFromImGui;

  ImGui.Separator;

  if ImGui.BeginMenu('Light') then
  begin
    if ImGui.MenuItem('Directional Light') then
      BeginCreateLightObjectFromImGui(ltDirectional);
    if ImGui.MenuItem('Point Light') then
      BeginCreateLightObjectFromImGui(ltPoint);
    if ImGui.MenuItem('Spot Light') then
      BeginCreateLightObjectFromImGui(ltSpot);
    ImGui.EndMenu;
  end;

  ImGui.Separator;

  if ImGui.MenuItem('Mesh File...') then
    BeginCreateMeshFileObjectFromImGui;
  if ImGui.MenuItem('Vertex Wind Tree...') then
    BeginCreateVertexWindTreeObjectFromImGui;
  if ImGui.MenuItem('Bone Wind Tree...') then
    BeginCreateWindTreeObjectFromImGui;

  ImGui.Separator;

  if ImGui.MenuItem('Cube') then BeginCreatePrimitiveObjectFromImGui(pkCube);
  if ImGui.MenuItem('Plane') then BeginCreatePrimitiveObjectFromImGui(pkPlane);
  if ImGui.MenuItem('Sphere') then BeginCreatePrimitiveObjectFromImGui(pkSphere);
  if ImGui.MenuItem('Cylinder') then BeginCreatePrimitiveObjectFromImGui(pkCylinder);
  if ImGui.MenuItem('Capsule') then BeginCreatePrimitiveObjectFromImGui(pkCapsule);
  if ImGui.MenuItem('Torus') then BeginCreatePrimitiveObjectFromImGui(pkTorus);
  if ImGui.MenuItem('Cone') then BeginCreatePrimitiveObjectFromImGui(pkCone);
  if ImGui.MenuItem('Prism') then BeginCreatePrimitiveObjectFromImGui(pkPrism);
  if ImGui.MenuItem('Frustum') then BeginCreatePrimitiveObjectFromImGui(pkFrustum);
  if ImGui.MenuItem('Icosphere') then BeginCreatePrimitiveObjectFromImGui(pkIcosphere);
  if ImGui.MenuItem('Geodesic Dome') then BeginCreatePrimitiveObjectFromImGui(pkGeodesicDome);
  if ImGui.MenuItem('Arrow') then BeginCreatePrimitiveObjectFromImGui(pkArrow);
  if ImGui.MenuItem('Super Ellipsoid') then BeginCreatePrimitiveObjectFromImGui(pkSuperEllipsoid);

  ImGui.Separator;
  if ImGui.MenuItem('Water Plane') then BeginCreatePrimitiveObjectFromImGui(pkWaterPlane);
  if ImGui.MenuItem('Height Field Terrain...') then BeginCreateHeightFieldObjectFromImGui;
end;

procedure TSandBoxForm.DrawAddMeshMenuItems;
begin
  if fSelectedObject = nil then
  begin
    ImGui.Text('Select an object first.');
    Exit;
  end;

  if fSelectedObject.IsInstance then
  begin
    ImGui.Text('Convert the instance to a unique object before adding meshes.');
    Exit;
  end;

  if ImGui.MenuItem('Mesh File...') then
    BeginCreateMeshFileMeshFromImGui;

  ImGui.Separator;

  if ImGui.MenuItem('Cube') then BeginCreatePrimitiveMeshFromImGui(pkCube);
  if ImGui.MenuItem('Plane') then BeginCreatePrimitiveMeshFromImGui(pkPlane);
  if ImGui.MenuItem('Sphere') then BeginCreatePrimitiveMeshFromImGui(pkSphere);
  if ImGui.MenuItem('Cylinder') then BeginCreatePrimitiveMeshFromImGui(pkCylinder);
  if ImGui.MenuItem('Capsule') then BeginCreatePrimitiveMeshFromImGui(pkCapsule);
  if ImGui.MenuItem('Torus') then BeginCreatePrimitiveMeshFromImGui(pkTorus);
  if ImGui.MenuItem('Cone') then BeginCreatePrimitiveMeshFromImGui(pkCone);
  if ImGui.MenuItem('Prism') then BeginCreatePrimitiveMeshFromImGui(pkPrism);
  if ImGui.MenuItem('Frustum') then BeginCreatePrimitiveMeshFromImGui(pkFrustum);
  if ImGui.MenuItem('Icosphere') then BeginCreatePrimitiveMeshFromImGui(pkIcosphere);
  if ImGui.MenuItem('Geodesic Dome') then BeginCreatePrimitiveMeshFromImGui(pkGeodesicDome);
  if ImGui.MenuItem('Arrow') then BeginCreatePrimitiveMeshFromImGui(pkArrow);
  if ImGui.MenuItem('Super Ellipsoid') then BeginCreatePrimitiveMeshFromImGui(pkSuperEllipsoid);

  ImGui.Separator;
  if ImGui.MenuItem('Water Plane') then BeginCreatePrimitiveMeshFromImGui(pkWaterPlane);
  if ImGui.MenuItem('Height Field Terrain...') then BeginCreateHeightFieldMeshFromImGui;
end;

procedure TSandBoxForm.BeginCreateHeightFieldObjectFromImGui;
begin
  OpenHeightFieldBrowser(True);
end;

procedure TSandBoxForm.BeginCreateHeightFieldMeshFromImGui;
begin
  if fSelectedObject = nil then
  begin
    LogLine('Select an object before adding a height field mesh.');
    Exit;
  end;

  if fSelectedObject.IsInstance then
  begin
    LogLine('Convert the instance to a unique object before adding a height field mesh.');
    Exit;
  end;

  OpenHeightFieldBrowser(False);
end;

procedure TSandBoxForm.OpenHeightFieldBrowser(CreateAsObject: Boolean);
begin
  ActivateMainRenderContext;
  ClearHeightFieldMapPreviews;

  fHeightFieldPicker.Active := True;
  fHeightFieldPicker.CreateAsObject := CreateAsObject;
  fHeightFieldPicker.NeedsRefresh := True;
  fHeightFieldPicker.SelectedIndex := -1;
  fHeightFieldPicker.LastError := '';
  SetLength(fHeightFieldPicker.Maps, 0);

  SetAnsiBuffer(fHeightFieldPicker.Name, 'HeightField');
  SetAnsiBuffer(fHeightFieldPicker.FileName, '');

  fHeightFieldPicker.Width := 100.0;
  fHeightFieldPicker.Depth := 100.0;
  fHeightFieldPicker.HeightScale := 10.0;
  fHeightFieldPicker.UVScale := 1.0;
  fHeightFieldPicker.TileSize := 64;
  fHeightFieldPicker.LODEnabled := True;
  fHeightFieldPicker.LODCount := 5;
  fHeightFieldPicker.LODDistance := System.Math.Max(8.0,
    System.Math.Max(Abs(fHeightFieldPicker.Width), Abs(fHeightFieldPicker.Depth)) * 0.35);

  fHeightFieldPicker.Position[0] := 0.0;
  fHeightFieldPicker.Position[1] := 0.0;
  fHeightFieldPicker.Position[2] := 0.0;
  fHeightFieldPicker.RotationDeg[0] := 0.0;
  fHeightFieldPicker.RotationDeg[1] := 0.0;
  fHeightFieldPicker.RotationDeg[2] := 0.0;
  fHeightFieldPicker.Scale[0] := 1.0;
  fHeightFieldPicker.Scale[1] := 1.0;
  fHeightFieldPicker.Scale[2] := 1.0;

  RefreshHeightFieldMapList;
end;

procedure TSandBoxForm.ResetHeightFieldBrowser;
begin
  fHeightFieldPicker.Active := False;
  fHeightFieldPicker.CreateAsObject := False;
  fHeightFieldPicker.NeedsRefresh := False;
  fHeightFieldPicker.SelectedIndex := -1;
  fHeightFieldPicker.LastError := '';
  SetAnsiBuffer(fHeightFieldPicker.Name, '');
  SetAnsiBuffer(fHeightFieldPicker.FileName, '');

  // Avoid deleting thumbnail GL textures while the current ImGui draw list may
  // still reference them. The next open/refresh or ShutdownEditor releases them.
  if not fInImGuiFrame then
    ClearHeightFieldMapPreviews;
end;

function TSandBoxForm.IsHeightFieldMapFile(const AFileName: string): Boolean;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(AFileName));
  Result := (Ext = '.png') or (Ext = '.jpg') or (Ext = '.jpeg') or
            (Ext = '.bmp');
end;

procedure TSandBoxForm.ClearHeightFieldMapPreviews;
var
  I: Integer;
  TexID: GLuint;
begin
  for I := 0 to High(fHeightFieldPicker.Maps) do
  begin
    TexID := fHeightFieldPicker.Maps[I].TextureID;
    if TexID <> 0 then
    begin
      glDeleteTextures(1, @TexID);
      fHeightFieldPicker.Maps[I].TextureID := 0;
    end;
  end;

  SetLength(fHeightFieldPicker.Maps, 0);
end;

function TSandBoxForm.TryCreateHeightFieldPreviewTexture(const AFileName: string;
  out TextureID: GLuint; out ImageWidth, ImageHeight: Integer): Boolean;
begin
  Result := TryCreateImagePreviewTexture(AFileName, HEIGHTFIELD_THUMB_SIZE,
    TextureID, ImageWidth, ImageHeight);
end;

procedure TSandBoxForm.RefreshHeightFieldMapList;
var
  Files: TArray<string>;
  I: Integer;
  Count: Integer;
  TexID: GLuint;
  W, H: Integer;
  FileName: string;
begin
  ActivateMainRenderContext;
  ClearHeightFieldMapPreviews;

  fHeightFieldPicker.NeedsRefresh := False;
  fHeightFieldPicker.SelectedIndex := -1;
  fHeightFieldPicker.LastError := '';

  TEnginePaths.EnsureDirectories;

  if not TDirectory.Exists(TEnginePaths.TerrainDir) then
  begin
    fHeightFieldPicker.LastError := 'Terrain folder does not exist: ' + TEnginePaths.TerrainDir;
    Exit;
  end;

  try
    Files := TDirectory.GetFiles(TEnginePaths.TerrainDir, '*.*', TSearchOption.soAllDirectories);
  except
    on E: Exception do
    begin
      fHeightFieldPicker.LastError := 'Could not scan terrain folder: ' + E.Message;
      Exit;
    end;
  end;

  Count := 0;
  for I := 0 to High(Files) do
  begin
    FileName := Files[I];
    if not IsHeightFieldMapFile(FileName) then
      Continue;

    SetLength(fHeightFieldPicker.Maps, Count + 1);
    fHeightFieldPicker.Maps[Count].FileName := FileName;
    fHeightFieldPicker.Maps[Count].RelativePath := TEnginePaths.ToAssetRelativePath(FileName);
    fHeightFieldPicker.Maps[Count].DisplayName := ChangeFileExt(ExtractFileName(FileName), '');
    fHeightFieldPicker.Maps[Count].TextureID := 0;
    fHeightFieldPicker.Maps[Count].Width := 0;
    fHeightFieldPicker.Maps[Count].Height := 0;
    fHeightFieldPicker.Maps[Count].PreviewReady := False;

    TexID := 0;
    W := 0;
    H := 0;
    if TryCreateHeightFieldPreviewTexture(FileName, TexID, W, H) then
    begin
      fHeightFieldPicker.Maps[Count].TextureID := TexID;
      fHeightFieldPicker.Maps[Count].Width := W;
      fHeightFieldPicker.Maps[Count].Height := H;
      fHeightFieldPicker.Maps[Count].PreviewReady := True;
    end;

    Inc(Count);
  end;

  if Count = 0 then
    fHeightFieldPicker.LastError := 'No PNG/JPG/BMP height maps found in ' + TEnginePaths.TerrainDir;
end;

procedure TSandBoxForm.SelectHeightFieldMapFromBrowser(Index: Integer);
var
  BaseName: string;
begin
  if (Index < 0) or (Index > High(fHeightFieldPicker.Maps)) then
    Exit;

  fHeightFieldPicker.SelectedIndex := Index;
  SetAnsiBuffer(fHeightFieldPicker.FileName, fHeightFieldPicker.Maps[Index].FileName);

  BaseName := fHeightFieldPicker.Maps[Index].DisplayName;
  if BaseName = '' then
    BaseName := ChangeFileExt(ExtractFileName(fHeightFieldPicker.Maps[Index].FileName), '');
  if BaseName = '' then
    BaseName := 'HeightField';

  SetAnsiBuffer(fHeightFieldPicker.Name, BaseName);
end;

function TSandBoxForm.CreateHeightFieldMeshFromBrowser(const MeshName, AFileName: string): TMesh;
var
  SourcePath: string;
  HeightField: THeightFieldMesh;
begin
  SourcePath := TEnginePaths.ResolveAssetPath(AFileName);

  Result := TMeshFactory.CreateHeightFieldFromFile(SourcePath,
    System.Math.Max(0.001, fHeightFieldPicker.Width),
    System.Math.Max(0.001, fHeightFieldPicker.Depth),
    System.Math.Max(0.001, fHeightFieldPicker.HeightScale),
    System.Math.Max(0.001, fHeightFieldPicker.UVScale),
    MeshName);

  if Result is THeightFieldMesh then
  begin
    HeightField := THeightFieldMesh(Result);
    HeightField.SourceFile := TEnginePaths.ToAssetRelativePath(SourcePath);
    HeightField.TileSize := System.Math.Max(1, fHeightFieldPicker.TileSize);
    HeightField.LODEnabled := fHeightFieldPicker.LODEnabled;
    HeightField.LODCount := fHeightFieldPicker.LODCount;
    HeightField.LODDistance := System.Math.Max(0.001, fHeightFieldPicker.LODDistance);
  end;

  SetupHeightFieldMesh(Result);
end;

procedure TSandBoxForm.SetupHeightFieldMesh(Mesh: TMesh);
begin
  if Mesh = nil then
    Exit;

  Mesh.MaterialLibrary := EnsureDefaultMaterialLibrary;
  Mesh.LibMaterialname := DEFAULT_PBR_MATERIAL_NAME;
  Mesh.OnRender := MeshRenderHandler;
end;

function TSandBoxForm.DefaultObjectSpawnPosition(
  ParentObj: TSceneObject): TVector3;
const
  DEFAULT_OBJECT_SPAWN_DISTANCE = 5.0;
var
  CameraObject: TSceneObject;
  SpawnWorldPosition: TVector3;
begin
  Result := Vector3(0, 0, 0);

  CameraObject := fCamera;
  if Assigned(fRenderer) and Assigned(fRenderer.ActiveCamera) then
    CameraObject := fRenderer.ActiveCamera;

  if (CameraObject = nil) or (CameraObject.Camera = nil) then
    Exit;

  SpawnWorldPosition := CameraObject.Camera.Position +
    (CameraObject.Camera.Front * DEFAULT_OBJECT_SPAWN_DISTANCE);
  if ParentObj = nil then
    Exit(SpawnWorldPosition);

  if Assigned(fSceneManager) then
    fSceneManager.Update
  else
    ParentObj.UpdateWorldMatrices;

  Result := Vector3(ParentObj.WorldMatrix.Inverse *
    Vector4(SpawnWorldPosition, 1));
end;

procedure TSandBoxForm.CreateSelectedHeightFieldFromBrowser;
var
  ParentObj: TSceneObject;
  NewObj: TSceneObject;
  Mesh: TMesh;
  MeshIndex: Integer;
  FileName: string;
  BaseName: string;
  ObjName: string;
begin
  FileName := AnsiBufferText(fHeightFieldPicker.FileName);
  if FileName = '' then
  begin
    fHeightFieldPicker.LastError := 'Select a height map first.';
    Exit;
  end;

  FileName := TEnginePaths.ResolveAssetPath(FileName);
  if not FileExists(FileName) then
  begin
    fHeightFieldPicker.LastError := 'Height map not found: ' + FileName;
    Exit;
  end;

  BaseName := AnsiBufferText(fHeightFieldPicker.Name);
  if BaseName = '' then
    BaseName := ChangeFileExt(ExtractFileName(FileName), '');
  if BaseName = '' then
    BaseName := 'HeightField';

  ActivateMainRenderContext;

  if fHeightFieldPicker.CreateAsObject then
  begin
    if CanUseSceneObjectAsParent(fSelectedObject) then
      ParentObj := fSelectedObject
    else
      ParentObj := fSceneWorld;

    if ParentObj = nil then
      ParentObj := fRoot;

    if ParentObj = nil then
      Exit;

    ObjName := MakeUniqueObjectName(ParentObj, BaseName);

    try
      Mesh := CreateHeightFieldMeshFromBrowser(ObjName, FileName);
    except
      on E: Exception do
      begin
        fHeightFieldPicker.LastError := 'Could not create height field: ' + E.Message;
        Exit;
      end;
    end;

    if Mesh = nil then
    begin
      fHeightFieldPicker.LastError := 'Could not create height field from: ' + FileName;
      Exit;
    end;

    Mesh.Position := Vector3(fHeightFieldPicker.Position[0], fHeightFieldPicker.Position[1], fHeightFieldPicker.Position[2]);
    Mesh.Rotation := Vector3(DegToRad(fHeightFieldPicker.RotationDeg[0]),
      DegToRad(fHeightFieldPicker.RotationDeg[1]),
      DegToRad(fHeightFieldPicker.RotationDeg[2]));
    Mesh.Scale := Vector3(fHeightFieldPicker.Scale[0], fHeightFieldPicker.Scale[1], fHeightFieldPicker.Scale[2]);

    NewObj := TSceneObject.Create(ParentObj);
    NewObj.Name := ObjName;
    NewObj.Position := DefaultObjectSpawnPosition(ParentObj);
    NewObj.MeshList.AddMeshToList(Mesh);
    NewObj.UpdateBoundingRadiusFromMesh;
    NewObj.NotifyChange;

    SelectObjectFromImGui(NewObj);
    LogLine('Created height field terrain: ' + ObjName);
  end
  else
  begin
    if fSelectedObject = nil then
    begin
      fHeightFieldPicker.LastError := 'Select an object before adding a height field mesh.';
      Exit;
    end;

    if fSelectedObject.IsInstance then
    begin
      fHeightFieldPicker.LastError :=
        'Convert the instance to a unique object before adding a height field mesh.';
      Exit;
    end;

    ObjName := GenMeshName(BaseName + '_');

    try
      Mesh := CreateHeightFieldMeshFromBrowser(ObjName, FileName);
    except
      on E: Exception do
      begin
        fHeightFieldPicker.LastError := 'Could not create height field: ' + E.Message;
        Exit;
      end;
    end;

    if Mesh = nil then
    begin
      fHeightFieldPicker.LastError := 'Could not create height field from: ' + FileName;
      Exit;
    end;

    Mesh.Position := Vector3(fHeightFieldPicker.Position[0], fHeightFieldPicker.Position[1], fHeightFieldPicker.Position[2]);
    Mesh.Rotation := Vector3(DegToRad(fHeightFieldPicker.RotationDeg[0]),
      DegToRad(fHeightFieldPicker.RotationDeg[1]),
      DegToRad(fHeightFieldPicker.RotationDeg[2]));
    Mesh.Scale := Vector3(fHeightFieldPicker.Scale[0], fHeightFieldPicker.Scale[1], fHeightFieldPicker.Scale[2]);

    MeshIndex := fSelectedObject.MeshList.AddMeshToList(Mesh);
    fSelectedObject.UpdateBoundingRadiusFromMesh;
    fSelectedObject.NotifyChange;
    SelectMeshIndex(MeshIndex);

    LogLine('Added height field mesh: ' + ObjName);
  end;

  ResetHeightFieldBrowser;
  RefreshGizmo;
  RequestRender;
end;

procedure TSandBoxForm.DrawImGuiHeightFieldBrowser;
var
  OpenWindow: Boolean;
  I: Integer;
  Selected: Boolean;
  Item: THeightFieldMapInfo;
  InfoText: string;
  Texture: ImTextureID;
begin
  if not fHeightFieldPicker.Active then
    Exit;

  if fHeightFieldPicker.NeedsRefresh then
    RefreshHeightFieldMapList;

  ImGui.SetNextWindowSize(ImVec2.New(700, 620), ImGuiCond_FirstUseEver);
  ImGui.SetNextWindowPos(ImVec2.New(EditorViewportWidth - 730, 90), ImGuiCond_FirstUseEver);

  OpenWindow := True;
  if ImGui.Begin_('Height Field Browser', @OpenWindow) then
  begin
    ImGui.TextWrapped(AnsiString('Maps are scanned from: ' + TEnginePaths.TerrainDir));

    if ImGui.Button('Refresh') then
      RefreshHeightFieldMapList;

    ImGui.Separator;

    if ImGui.BeginChild('HeightFieldMapList', ImVec2.New(320, 360)) then
    begin
      for I := 0 to High(fHeightFieldPicker.Maps) do
      begin
        Item := fHeightFieldPicker.Maps[I];
        Selected := I = fHeightFieldPicker.SelectedIndex;

        ImGui.PushId(I);
        ImGui.BeginGroup;

        if Item.TextureID <> 0 then
        begin
          Texture := ImTextureID(NativeUInt(Item.TextureID));
          if ImGui.ImageButton(PAnsiChar(AnsiString('preview')), Texture, ImVec2.New(HEIGHTFIELD_THUMB_SIZE, HEIGHTFIELD_THUMB_SIZE),
            ImVec2.New(0, 0), ImVec2.New(1, 1),
            ImVec4.New(0, 0, 0, 0), ImVec4.New(1, 1, 1, 1)) then
            SelectHeightFieldMapFromBrowser(I);
        end
        else if ImGui.Button('[no preview]', ImVec2.New(HEIGHTFIELD_THUMB_SIZE, HEIGHTFIELD_THUMB_SIZE)) then
          SelectHeightFieldMapFromBrowser(I);

        ImGui.SameLine;
        ImGui.BeginGroup;
        if ImGui.Selectable(AnsiString(Item.DisplayName), Selected) then
          SelectHeightFieldMapFromBrowser(I);

        InfoText := Item.RelativePath;
        if (Item.Width > 0) and (Item.Height > 0) then
          InfoText := Format('%dx%d  %s', [Item.Width, Item.Height, Item.RelativePath]);
        ImGui.TextWrapped(AnsiString(InfoText));
        ImGui.EndGroup;

        ImGui.EndGroup;
        ImGui.Separator;
        ImGui.PopId;
      end;
    end;
    ImGui.EndChild;

    ImGui.SameLine;

    ImGui.BeginGroup;
    if fHeightFieldPicker.CreateAsObject then
      ImGui.Text('Create as: Object')
    else
      ImGui.Text('Create as: Mesh');

    ImGui.TextDisabled('Identity');
    ImGui.PushItemWidth(IMGUI_PROP_TEXT_WIDTH);
    ImGui.InputText(PAnsiChar(AnsiString('Name')), @fHeightFieldPicker.Name[0], SizeOf(fHeightFieldPicker.Name));
    if ImGui.InputText(PAnsiChar(AnsiString('Height map file')), @fHeightFieldPicker.FileName[0], SizeOf(fHeightFieldPicker.FileName)) then
      fHeightFieldPicker.SelectedIndex := -1;
    ImGui.PopItemWidth;

    ImGui.Separator;
    if ImGui.CollapsingHeader('Height Field Properties', ImGuiTreeNodeFlags_DefaultOpen) then
    begin
      ImGui.TextDisabled('Source and dimensions');
      ImGui.PushItemWidth(IMGUI_PROP_SCALAR_WIDTH);
      ImGui.DragFloat('Terrain width', @fHeightFieldPicker.Width, 0.25, 0.001, 100000, '%.2f');
      ImGui.DragFloat('Terrain depth', @fHeightFieldPicker.Depth, 0.25, 0.001, 100000, '%.2f');
      ImGui.DragFloat('Height scale', @fHeightFieldPicker.HeightScale, 0.05, 0.001, 100000, '%.3f');
      ImGui.DragFloat('UV scale', @fHeightFieldPicker.UVScale, 0.05, 0.001, 100000, '%.3f');
      ImGui.PopItemWidth;
    end;

    ImGui.Separator;
    if ImGui.CollapsingHeader('LOD Properties', ImGuiTreeNodeFlags_DefaultOpen) then
    begin
      ImGui.Checkbox('LOD enabled', @fHeightFieldPicker.LODEnabled);
      ImGui.PushItemWidth(IMGUI_PROP_SCALAR_WIDTH);
      ImGui.DragInt('LOD count', @fHeightFieldPicker.LODCount, 1.0, 1, HEIGHTFIELD_MAX_LOD_LEVELS, '%d', ImGuiSliderFlags_None);
      ImGui.DragFloat('LOD distance', @fHeightFieldPicker.LODDistance, 0.25, 0.001, 100000, '%.2f');
      ImGui.DragInt('Tile size', @fHeightFieldPicker.TileSize, 1.0, 1, 4096, '%d', ImGuiSliderFlags_None);
      ImGui.PopItemWidth;
    end;

    ImGui.Separator;
    if ImGui.CollapsingHeader('Transform', ImGuiTreeNodeFlags_DefaultOpen) then
    begin
      ImGui.PushItemWidth(IMGUI_PROP_VECTOR3_WIDTH);
      ImGui.DragFloat3('Position', @fHeightFieldPicker.Position[0], 0.05, -100000, 100000, '%.2f');
      ImGui.DragFloat3('Rotation', @fHeightFieldPicker.RotationDeg[0], 0.25, -360, 360, '%.2f');
      ImGui.DragFloat3('Scale', @fHeightFieldPicker.Scale[0], 0.05, 0.001, 100000, '%.2f');
      ImGui.PopItemWidth;
    end;

    if fHeightFieldPicker.LastError <> '' then
    begin
      ImGui.Separator;
      ImGui.TextWrapped(AnsiString(fHeightFieldPicker.LastError));
    end;

    ImGui.Separator;
    if ImGui.Button('Create') then
      CreateSelectedHeightFieldFromBrowser;

    ImGui.SameLine;
    if ImGui.Button('Cancel') then
      ResetHeightFieldBrowser;

    ImGui.EndGroup;
  end;
  ImGui.End_;

  if not OpenWindow then
    ResetHeightFieldBrowser;
end;

procedure TSandBoxForm.PrepareImportedMeshList(Meshes: TMeshList;
  ALib: TMaterialLibrary);
var
  I: Integer;
  MatIndex: Integer;
  Mesh: TMesh;
begin
  if Meshes = nil then
    Exit;

  if ALib <> nil then
    for I := 0 to ALib.Count - 1 do
      AssignShaderToMaterial(ALib.Material[I]);

  for I := 0 to Meshes.Count - 1 do
  begin
    Mesh := Meshes.Item[I];
    if Mesh = nil then
      Continue;

    Mesh.OnRender := MeshRenderHandler;

    if Mesh.MaterialLibrary = nil then
      Mesh.MaterialLibrary := ALib;

    if (Mesh.LibMaterialname = '') and Assigned(Mesh.MaterialLibrary) then
    begin
      MatIndex := FirstRenderableMaterialIndex(Mesh.MaterialLibrary);
      if MatIndex >= 0 then
        Mesh.LibMaterialname := Mesh.MaterialLibrary.Material[MatIndex].Name;
    end;

    if Assigned(Mesh.MaterialLibrary) and (Mesh.MaterialLibraryName = '') then
      Mesh.MaterialLibraryName := Mesh.MaterialLibrary.Name;
  end;
end;

function TSandBoxForm.MakeUniqueAnimationClipName(Animator: TSkeletonAnimator;
  const ABaseName: string): string;
var
  BaseName: string;
  Suffix: Integer;
begin
  BaseName := Trim(ABaseName);
  if BaseName = '' then
    BaseName := 'Animation';

  Result := BaseName;
  Suffix := 2;
  while Assigned(Animator) and (Animator.AnimationIndexByName(Result) >= 0) do
  begin
    Result := Format('%s_%d', [BaseName, Suffix]);
    Inc(Suffix);
  end;
end;

procedure TSandBoxForm.ImportAnimationFilesFromImGui(
  const AFileNames: TArray<string>);
var
  Animator: TSkeletonAnimator;
  Clips: TArray<TSkeletonAnimationClip>;
  Clip: TSkeletonAnimationClip;
  FileName: string;
  ResolvedFileName: string;
  Ext: string;
  I: Integer;
  AddedCount: Integer;
  FirstAddedIndex: Integer;
  AddedIndex: Integer;
  ErrorText: string;
begin
  fModelFileBrowser.LastError := '';

  if fSelectedObject = nil then
  begin
    fModelFileBrowser.LastError := 'Select a skeletal object before loading animations.';
    Exit;
  end;

  Animator := fSelectedObject.AnimationController;
  if Animator = nil then
  begin
    fModelFileBrowser.LastError := 'Selected object has no skeleton.';
    Exit;
  end;

  AddedCount := 0;
  FirstAddedIndex := -1;
  ErrorText := '';

  for FileName in AFileNames do
  begin
    ResolvedFileName := TEnginePaths.ResolveAssetPath(FileName);
    Ext := LowerCase(ExtractFileExt(ResolvedFileName));
    if not ((Ext = '.gltf') or (Ext = '.glb')) then
    begin
      if ErrorText <> '' then
        ErrorText := ErrorText + sLineBreak;
      ErrorText := ErrorText + ExtractFileName(ResolvedFileName) +
        ': expected glTF/GLB.';
      Continue;
    end;

    Clips := nil;
    try
      LoadGLTFAnimationClips(ResolvedFileName, Animator.Skeleton, Clips);
      for I := 0 to High(Clips) do
      begin
        Clip := Clips[I];
        if Clip = nil then
          Continue;

        Clip.Name := MakeUniqueAnimationClipName(Animator, Clip.Name);
        AddedIndex := Animator.AddAnimation(Clip);
        Clips[I] := nil;
        if FirstAddedIndex < 0 then
          FirstAddedIndex := AddedIndex;
        Inc(AddedCount);
      end;

      LogLine(Format('Loaded animation clip file: %s (%d clip(s)).',
        [ResolvedFileName, Length(Clips)]));
    except
      on E: Exception do
      begin
        if ErrorText <> '' then
          ErrorText := ErrorText + sLineBreak;
        ErrorText := ErrorText + ExtractFileName(ResolvedFileName) + ': ' +
          E.Message;
        LogLine('Could not load animation clips: ' + ResolvedFileName + ' - ' +
          E.Message);
      end;
    end;

    for I := 0 to High(Clips) do
      Clips[I].Free;
  end;

  if AddedCount = 0 then
  begin
    if ErrorText = '' then
      ErrorText := 'No animation clips were loaded.';
    fModelFileBrowser.LastError := ErrorText;
    Exit;
  end;

  if (FirstAddedIndex >= 0) and fModelFileBrowser.AutoPlayFirstAnimation then
    Animator.Play(FirstAddedIndex, True, fAnimationBlendDuration);

  LogLine(Format('Added %d animation clip(s) to "%s".',
    [AddedCount, fSelectedObject.Name]));
  if ErrorText <> '' then
    LogLine('Animation clip import skipped some files: ' +
      StringReplace(ErrorText, sLineBreak, ' | ', [rfReplaceAll]));

  RequestRender;
  if fModelFileBrowser.Active then
    ResetModelFileBrowser;
end;

procedure TSandBoxForm.ImportMeshFileFromImGui(const AFileName: string;
  CreateAsObject, CreateAsWindTree, CreateAsVertexWindTree: Boolean);
var
  FileName: string;
  BaseName: string;
  ObjName: string;
  ParentObj: TSceneObject;
  NewObj: TSceneObject;
  TempMeshes: TMeshList;
  ImportLib: TMaterialLibrary;
  ImportLibIndex: Integer;
  OldMeshCount: Integer;
  ImportedAnimator: TSkeletonAnimator;
begin
  if CreateAsWindTree or CreateAsVertexWindTree then
    CreateAsObject := True;

  FileName := TEnginePaths.ResolveAssetPath(AFileName);

  if not IsModelAssetFile(FileName) then
  begin
    fModelFileBrowser.LastError := 'Unsupported mesh file: ' + FileName;
    LogLine('Unsupported mesh file: ' + FileName);
    Exit;
  end;

  if not FileExists(FileName) then
  begin
    fModelFileBrowser.LastError := 'Model file not found: ' + FileName;
    LogLine('Model file not found: ' + FileName);
    Exit;
  end;

  if not CreateAsObject then
  begin
    if fSelectedObject = nil then
    begin
      fModelFileBrowser.LastError := 'Select an object before loading a mesh file.';
      LogLine('Select an object before loading a mesh file.');
      Exit;
    end;

    if fSelectedObject.IsInstance then
    begin
      fModelFileBrowser.LastError :=
        'Convert the instance to a unique object before adding mesh files.';
      LogLine('Convert the instance to a unique object before adding mesh files.');
      Exit;
    end;
  end;

  ActivateMainRenderContext;

  BaseName := ChangeFileExt(ExtractFileName(FileName), '');
  if BaseName = '' then
    BaseName := 'ImportedMesh';

  TempMeshes := nil;
  try
    ImportLib := EnsureDefaultMaterialLibrary;

    TempMeshes := TMeshList.Create;
    TempMeshes.LoadFromFile(FileName, ImportLib, fShader);
    PrepareImportedMeshList(TempMeshes, ImportLib);
    ImportedAnimator := TempMeshes.AnimationController;

    if TempMeshes.Count = 0 then
      raise Exception.Create('The file did not contain any loadable meshes.');

    if CreateAsWindTree and
       ((ImportedAnimator = nil) or (ImportedAnimator.Skeleton = nil) or
        (ImportedAnimator.Skeleton.BoneCount = 0)) then
      raise Exception.Create(
        'Wind Tree actors require a skinned glTF/GLB model with bones.');

    if CreateAsObject then
    begin
      if CanUseSceneObjectAsParent(fSelectedObject) then
        ParentObj := fSelectedObject
      else
        ParentObj := fSceneWorld;

      if ParentObj = nil then
        ParentObj := fRoot;

      if ParentObj = nil then
        raise Exception.Create('No scene parent is available for the imported object.');

      ObjName := MakeUniqueObjectName(ParentObj, BaseName);
      NewObj := TSceneObject.Create(ParentObj);
      try
        NewObj.Name := ObjName;
        NewObj.Position := DefaultObjectSpawnPosition(ParentObj);

        if not NewObj.MeshList.CombineLists(TempMeshes) then
          raise Exception.Create('Could not attach imported meshes to the new object.');

        if CreateAsWindTree then
        begin
          NewObj.EnableTreeWind;
          if Assigned(ImportedAnimator) then
            ImportedAnimator.Stop(True);
        end;
        if CreateAsVertexWindTree then
        begin
          NewObj.EnableVertexTreeWind;
          if Assigned(ImportedAnimator) then
            ImportedAnimator.Stop(True);
        end;

        NewObj.UpdateBoundingRadiusFromMesh;
        NewObj.NotifyChange;
        SelectObjectFromImGui(NewObj);
        if CreateAsVertexWindTree then
          LogLine(Format('Loaded vertex-wind tree actor: %s (%d mesh(es))',
            [FileName, NewObj.MeshList.Count]))
        else if CreateAsWindTree then
          LogLine(Format('Loaded bone-wind tree actor: %s (%d mesh(es))',
            [FileName, NewObj.MeshList.Count]))
        else
          LogLine(Format('Loaded mesh file as object: %s (%d mesh(es))',
            [FileName, NewObj.MeshList.Count]));

        if Assigned(ImportedAnimator) then
        begin
          LogLine(Format('Skeletal model: %d bone(s), %d animation clip(s).',
            [ImportedAnimator.Skeleton.BoneCount,
             ImportedAnimator.AnimationCount]));
          if CreateAsVertexWindTree then
            LogLine('Vertex wind enabled; skeletal clips are left stopped.')
          else if CreateAsWindTree then
            LogLine('Bone wind enabled; skeletal clips are left stopped.')
          else if fModelFileBrowser.AutoPlayFirstAnimation and
             (ImportedAnimator.AnimationCount > 0) then
            ImportedAnimator.Play(0, True);
        end
        else if SameText(ExtractFileExt(FileName), '.gltf') or
                SameText(ExtractFileExt(FileName), '.glb') then
          LogLine('The glTF model contains no skin or skeletal animation data.');
      except
        NewObj.Free;
        raise;
      end;
    end
    else
    begin
      OldMeshCount := fSelectedObject.MeshList.Count;
      if not fSelectedObject.MeshList.CombineLists(TempMeshes) then
        raise Exception.Create('Could not attach imported meshes to the selected object.');

      fSelectedObject.UpdateBoundingRadiusFromMesh;
      fSelectedObject.NotifyChange;
      SelectMeshIndex(OldMeshCount);
      LogLine(Format('Loaded mesh file into object: %s (%d mesh(es))',
        [FileName, fSelectedObject.MeshList.Count - OldMeshCount]));

      if Assigned(ImportedAnimator) then
      begin
        LogLine(Format('Skeletal model: %d bone(s), %d animation clip(s).',
          [ImportedAnimator.Skeleton.BoneCount,
           ImportedAnimator.AnimationCount]));
        if fModelFileBrowser.AutoPlayFirstAnimation and
           (ImportedAnimator.AnimationCount > 0) then
          ImportedAnimator.Play(0, True);
      end
      else if SameText(ExtractFileExt(FileName), '.gltf') or
              SameText(ExtractFileExt(FileName), '.glb') then
        LogLine('The glTF model contains no skin or skeletal animation data.');
    end;

    ImportLibIndex := MaterialLibraries.IndexOf(ImportLib);
    if ImportLibIndex >= 0 then
    begin
      fMaterialEditor.SelectedLibraryIndex := ImportLibIndex;
      fMaterialEditor.SelectedMaterialIndex := FirstRenderableMaterialIndex(ImportLib);
    end;

    RefreshGizmo;
    RequestRender;
    if fModelFileBrowser.Active then
      ResetModelFileBrowser;
  except
    on E: Exception do
    begin
      fModelFileBrowser.LastError := 'Could not load mesh file: ' + E.Message;
      LogLine('Could not load mesh file: ' + E.Message);
    end;
  end;

  TempMeshes.Free;
end;

procedure TSandBoxForm.BeginCreateEmptyObjectFromImGui;
var
  ParentObj: TSceneObject;
  NewObj: TSceneObject;
begin
  if CanUseSceneObjectAsParent(fSelectedObject) then
    ParentObj := fSelectedObject
  else
    ParentObj := fSceneWorld;

  if ParentObj = nil then
    ParentObj := fRoot;

  if ParentObj = nil then
    Exit;

  NewObj := TSceneObject.Create(ParentObj);
  NewObj.Name := MakeUniqueObjectName(ParentObj, 'Empty');
  NewObj.Position := DefaultObjectSpawnPosition(ParentObj);
  NewObj.NotifyChange;

  LogLine('Created empty object: ' + NewObj.Name);
  SelectObjectFromImGui(NewObj);
end;

procedure TSandBoxForm.BeginCreateLightObjectFromImGui(ALightType: TLightType);
var
  ParentObj: TSceneObject;
  NewObj: TSceneObject;
  Light: TLight;
  BaseName: string;
begin
  if CanUseSceneObjectAsParent(fSelectedObject) then
    ParentObj := fSelectedObject
  else
    ParentObj := fSceneWorld;

  if ParentObj = nil then
    ParentObj := fRoot;

  if ParentObj = nil then
    Exit;

  case ALightType of
    ltDirectional: BaseName := 'DirectionalLight';
    ltPoint: BaseName := 'PointLight';
    ltSpot: BaseName := 'SpotLight';
  else
    BaseName := 'Light';
  end;

  NewObj := TSceneObject.Create(ParentObj);
  try
    NewObj.Name := MakeUniqueObjectName(ParentObj, BaseName);
    NewObj.Position := DefaultObjectSpawnPosition(ParentObj);
    if ALightType = ltDirectional then
    begin
      NewObj.Rotation := Vector3(DegToRad(-45), DegToRad(35), 0);
    end;

    Light := NewObj.CreateLight;
    ConfigureLightDefaults(Light, ALightType);
    EnsureLightBillboard(NewObj);
    NewObj.NotifyChange;
  except
    on E: Exception do
    begin
      NewObj.Free;
      LogLine('Could not create light: ' + E.Message);
      Exit;
    end;
  end;

  if fLight = nil then
    fLight := NewObj;
  if Assigned(fRenderer) and (fRenderer.ShadowLight = nil) then
    fRenderer.ShadowLight := fLight;

  SelectObjectFromImGui(NewObj);
  LogLine('Created light: ' + NewObj.Name);
end;

procedure TSandBoxForm.BeginCreatePrimitiveObjectFromImGui(AKind: TPrimitiveKind);
var
  ParentObj: TSceneObject;
  NewObj: TSceneObject;
  Mesh: TMesh;
  ObjName: string;
  PreviousObject: TSceneObject;
  PreviousMesh: TMesh;
  PreviousMeshIndex: Integer;
begin
  PreviousObject := fSelectedObject;
  PreviousMesh := fSelectedMesh;
  PreviousMeshIndex := fSelectedMeshIndex;

  if CanUseSceneObjectAsParent(fSelectedObject) then
    ParentObj := fSelectedObject
  else
    ParentObj := fSceneWorld;

  if ParentObj = nil then
    ParentObj := fRoot;

  if ParentObj = nil then
    Exit;

  ObjName := MakeUniqueObjectName(ParentObj, PrimitiveBaseName(AKind));

  NewObj := TSceneObject.Create(ParentObj);
  NewObj.Name := ObjName;
  NewObj.Position := DefaultObjectSpawnPosition(ParentObj);

  ActivateMainRenderContext;

  Mesh := CreateDefaultPrimitiveMesh(AKind, ObjName);
  if Mesh = nil then
  begin
    NewObj.Free;
    Exit;
  end;

  NewObj.MeshList.AddMeshToList(Mesh);
  NewObj.UpdateBoundingRadiusFromMesh;
  NewObj.NotifyChange;

  SelectObjectFromImGui(NewObj);

  BeginPrimitiveEditor(AKind, NewObj, Mesh, True, True);
  fMeshEditor.PreviousObject := PreviousObject;
  fMeshEditor.PreviousMesh := PreviousMesh;
  fMeshEditor.PreviousMeshIndex := PreviousMeshIndex;

  RefreshGizmo;
  RequestRender;
end;

procedure TSandBoxForm.BeginCreatePrimitiveMeshFromImGui(AKind: TPrimitiveKind);
var
  Mesh: TMesh;
  NewIndex: Integer;
  PreviousObject: TSceneObject;
  PreviousMesh: TMesh;
  PreviousMeshIndex: Integer;
begin
  if fSelectedObject = nil then
    Exit;

  if fSelectedObject.IsInstance then
  begin
    LogLine('Convert the instance to a unique object before adding meshes.');
    Exit;
  end;

  PreviousObject := fSelectedObject;
  PreviousMesh := fSelectedMesh;
  PreviousMeshIndex := fSelectedMeshIndex;

  ActivateMainRenderContext;

  Mesh := CreateDefaultPrimitiveMesh(AKind, GenMeshName(PrimitiveBaseName(AKind) + '_'));
  if Mesh = nil then
    Exit;

  NewIndex := fSelectedObject.MeshList.AddMeshToList(Mesh);

  fSelectedObject.UpdateBoundingRadiusFromMesh;
  fSelectedObject.NotifyChange;
  SelectMeshIndex(NewIndex);

  BeginPrimitiveEditor(AKind, fSelectedObject, Mesh, False, True);
  fMeshEditor.PreviousObject := PreviousObject;
  fMeshEditor.PreviousMesh := PreviousMesh;
  fMeshEditor.PreviousMeshIndex := PreviousMeshIndex;

  RefreshGizmo;
  RequestRender;
end;

procedure TSandBoxForm.BeginCreateMeshFileObjectFromImGui;
begin
  OpenModelFileBrowser(True);
end;

procedure TSandBoxForm.BeginCreateWindTreeObjectFromImGui;
begin
  OpenModelFileBrowser(True, True);
end;

procedure TSandBoxForm.BeginCreateVertexWindTreeObjectFromImGui;
begin
  OpenModelFileBrowser(True, False, True);
end;

procedure TSandBoxForm.BeginCreateMeshFileMeshFromImGui;
begin
  OpenModelFileBrowser(False);
end;

procedure TSandBoxForm.BeginEditSelectedMeshFromImGui;
var
  Kind: TPrimitiveKind;
begin
  if (fSelectedObject = nil) or (fSelectedMesh = nil) then
    Exit;

  if fSelectedObject.IsInstance then
  begin
    LogLine('Convert the instance to a unique object before editing shared mesh geometry.');
    Exit;
  end;

  if not TryGetPrimitiveKindForMesh(fSelectedMesh, Kind) then
  begin
    LogLine('Selected mesh type is not supported by the primitive editor: ' +
      fSelectedMesh.ClassName);
    Exit;
  end;

  BeginPrimitiveEditor(Kind, fSelectedObject, fSelectedMesh, False, False);
  fMeshEditor.OriginalMesh := fSelectedMesh.Clone;
  if Assigned(fMeshEditor.OriginalMesh) then
    fMeshEditor.OriginalMesh.Name := fSelectedMesh.Name;
end;

procedure TSandBoxForm.BeginCreateCubeObjectFromImGui;
begin
  BeginCreatePrimitiveObjectFromImGui(pkCube);
end;

procedure TSandBoxForm.BeginCreateCubeMeshFromImGui;
begin
  BeginCreatePrimitiveMeshFromImGui(pkCube);
end;

procedure TSandBoxForm.BeginPrimitiveEditor(AKind: TPrimitiveKind; Obj: TSceneObject;
  Mesh: TMesh; CreatedObject, CreatedMesh: Boolean);
begin
  if (Obj = nil) or (Mesh = nil) then
    Exit;

  FreeAndNil(fMeshEditor.OriginalMesh);
  FillChar(fMeshEditor, SizeOf(fMeshEditor), 0);

  fMeshEditor.Active := True;
  fMeshEditor.Kind := AKind;
  fMeshEditor.CreatedObject := CreatedObject;
  fMeshEditor.CreatedMesh := CreatedMesh;
  fMeshEditor.TargetObject := Obj;
  fMeshEditor.PreviousObject := fSelectedObject;
  fMeshEditor.PreviousMesh := fSelectedMesh;
  fMeshEditor.PreviousMeshIndex := fSelectedMeshIndex;
  fMeshEditor.MeshIndex := Obj.MeshList.IndexOf(Mesh);

  SetAnsiBuffer(fMeshEditor.Name, Mesh.Name);
  InitPrimitiveEditorDefaults(AKind, Mesh);

  fMeshEditor.Position[0] := Mesh.Position.X;
  fMeshEditor.Position[1] := Mesh.Position.Y;
  fMeshEditor.Position[2] := Mesh.Position.Z;

  fMeshEditor.RotationDeg[0] := RadToDeg(Mesh.Rotation.X);
  fMeshEditor.RotationDeg[1] := RadToDeg(Mesh.Rotation.Y);
  fMeshEditor.RotationDeg[2] := RadToDeg(Mesh.Rotation.Z);

  fMeshEditor.Scale[0] := Mesh.Scale.X;
  fMeshEditor.Scale[1] := Mesh.Scale.Y;
  fMeshEditor.Scale[2] := Mesh.Scale.Z;
end;

procedure TSandBoxForm.BeginCubeEditor(Obj: TSceneObject; Mesh: TMesh;
  CreatedObject, CreatedMesh: Boolean);
begin
  BeginPrimitiveEditor(pkCube, Obj, Mesh, CreatedObject, CreatedMesh);
end;

procedure TSandBoxForm.DrawImGuiMeshEditor;
var
  Changed: Boolean;
  WindowTitle: AnsiString;
begin
  if not fMeshEditor.Active then
    Exit;

  ImGui.SetNextWindowSize(ImVec2.New(400, 560), ImGuiCond_FirstUseEver);
  ImGui.SetNextWindowPos(ImVec2.New(EditorViewportWidth - 410, 90), ImGuiCond_FirstUseEver);

  WindowTitle := AnsiString(PrimitiveKindDisplayName(fMeshEditor.Kind) + ' Editor');

  if ImGui.Begin_(PAnsiChar(WindowTitle), nil) then
  begin
    Changed := False;

    ImGui.PushItemWidth(IMGUI_PROP_TEXT_WIDTH);
    Changed := ImGui.InputText(PAnsiChar(AnsiString('Name')), @fMeshEditor.Name[0], SizeOf(fMeshEditor.Name)) or Changed;
    ImGui.PopItemWidth;

    ImGui.Separator;

    ImGui.PushItemWidth(IMGUI_PROP_SCALAR_WIDTH);
    case fMeshEditor.Kind of
      pkCube:
        begin
          Changed := ImGui.DragFloat('Width', @fMeshEditor.Width, 0.05, 0.001, 100000, '%.2f') or Changed;
          Changed := ImGui.DragFloat('Height', @fMeshEditor.Height, 0.05, 0.001, 100000, '%.2f') or Changed;
          Changed := ImGui.DragFloat('Depth', @fMeshEditor.Depth, 0.05, 0.001, 100000, '%.2f') or Changed;
          Changed := ImGui.DragInt('Width Segments', @fMeshEditor.WidthSegments, 1.0, 1, 512, '%d', ImGuiSliderFlags_None) or Changed;
          Changed := ImGui.DragInt('Height Segments', @fMeshEditor.HeightSegments, 1.0, 1, 512, '%d', ImGuiSliderFlags_None) or Changed;
          Changed := ImGui.DragInt('Depth Segments', @fMeshEditor.DepthSegments, 1.0, 1, 512, '%d', ImGuiSliderFlags_None) or Changed;
        end;

      pkPlane:
        begin
          Changed := ImGui.DragFloat('Width', @fMeshEditor.Width, 0.05, 0.001, 100000, '%.2f') or Changed;
          Changed := ImGui.DragFloat('Depth', @fMeshEditor.Depth, 0.05, 0.001, 100000, '%.2f') or Changed;
          Changed := ImGui.DragInt('Width Segments', @fMeshEditor.WidthSegments, 1.0, 1, 512, '%d', ImGuiSliderFlags_None) or Changed;
          Changed := ImGui.DragInt('Depth Segments', @fMeshEditor.DepthSegments, 1.0, 1, 512, '%d', ImGuiSliderFlags_None) or Changed;
        end;

      pkWaterPlane:
        begin
          Changed := ImGui.DragFloat('Width', @fMeshEditor.Width, 0.05, 0.001, 100000, '%.2f') or Changed;
          Changed := ImGui.DragFloat('Depth', @fMeshEditor.Depth, 0.05, 0.001, 100000, '%.2f') or Changed;
          Changed := ImGui.DragInt('Width Segments', @fMeshEditor.WidthSegments, 1.0, WATER_EDITOR_MIN_SEGMENTS, 512, '%d', ImGuiSliderFlags_None) or Changed;
          Changed := ImGui.DragInt('Depth Segments', @fMeshEditor.DepthSegments, 1.0, WATER_EDITOR_MIN_SEGMENTS, 512, '%d', ImGuiSliderFlags_None) or Changed;
          ImGui.Text(PAnsiChar(AnsiString(Format('Water uses minimum %d x %d segments.',
            [WATER_EDITOR_MIN_SEGMENTS, WATER_EDITOR_MIN_SEGMENTS]))));
          ImGui.Separator;
          Changed := ImGui.ColorEdit4('Tint Color', @fMeshEditor.WaterTintColor[0],
            ImGuiColorEditFlags_None) or Changed;
          Changed := ImGui.ColorEdit4('Deep Color', @fMeshEditor.WaterDeepColor[0],
            ImGuiColorEditFlags_None) or Changed;
          Changed := ImGui.DragFloat('Reflection Strength',
            @fMeshEditor.WaterReflectionStrength, 0.01, 0, 1, '%.3f') or Changed;
          Changed := ImGui.DragFloat('Wave Scale', @fMeshEditor.WaterWaveScale,
            0.01, 0.001, 100000, '%.3f') or Changed;
          Changed := ImGui.DragFloat('Wave Speed', @fMeshEditor.WaterWaveSpeed,
            0.01, 0, 100000, '%.3f') or Changed;
          Changed := ImGui.DragFloat('Wave Strength',
            @fMeshEditor.WaterWaveStrength, 0.01, 0, 100000, '%.3f') or Changed;
          Changed := ImGui.DragFloat('Fresnel Power',
            @fMeshEditor.WaterFresnelPower, 0.01, 0.001, 100000, '%.3f') or Changed;
          Changed := ImGui.DragFloat('Alpha', @fMeshEditor.WaterAlpha, 0.01,
            0, 1, '%.3f') or Changed;
        end;

      pkSphere:
        begin
          Changed := ImGui.DragFloat('Radius', @fMeshEditor.Radius, 0.05, 0.001, 100000, '%.2f') or Changed;
          Changed := ImGui.DragInt('Stacks', @fMeshEditor.StackCount, 1.0, 2, 512, '%d', ImGuiSliderFlags_None) or Changed;
          Changed := ImGui.DragInt('Slices', @fMeshEditor.SliceCount, 1.0, 3, 512, '%d', ImGuiSliderFlags_None) or Changed;
        end;

      pkCylinder, pkCapsule:
        begin
          Changed := ImGui.DragFloat('Radius', @fMeshEditor.Radius, 0.05, 0.001, 100000, '%.2f') or Changed;
          Changed := ImGui.DragFloat('Height', @fMeshEditor.Height, 0.05, 0.001, 100000, '%.2f') or Changed;
          Changed := ImGui.DragInt('Slices', @fMeshEditor.Slices, 1.0, 3, 512, '%d', ImGuiSliderFlags_None) or Changed;
          Changed := ImGui.DragInt('Stacks', @fMeshEditor.Stacks, 1.0, 1, 512, '%d', ImGuiSliderFlags_None) or Changed;
        end;

      pkTorus:
        begin
          Changed := ImGui.DragFloat('Major Radius', @fMeshEditor.MajorRadius, 0.05, 0.001, 100000, '%.2f') or Changed;
          Changed := ImGui.DragFloat('Minor Radius', @fMeshEditor.MinorRadius, 0.05, 0.001, 100000, '%.2f') or Changed;
          Changed := ImGui.DragInt('Major Segments', @fMeshEditor.MajorSegments, 1.0, 3, 512, '%d', ImGuiSliderFlags_None) or Changed;
          Changed := ImGui.DragInt('Minor Segments', @fMeshEditor.MinorSegments, 1.0, 3, 512, '%d', ImGuiSliderFlags_None) or Changed;
        end;

      pkCone, pkPrism:
        begin
          Changed := ImGui.DragFloat('Radius', @fMeshEditor.Radius, 0.05, 0.001, 100000, '%.2f') or Changed;
          Changed := ImGui.DragFloat('Height', @fMeshEditor.Height, 0.05, 0.001, 100000, '%.2f') or Changed;
          Changed := ImGui.DragInt('Sides', @fMeshEditor.Sides, 1.0, 3, 512, '%d', ImGuiSliderFlags_None) or Changed;
          Changed := ImGui.DragInt('Stacks', @fMeshEditor.Stacks, 1.0, 1, 512, '%d', ImGuiSliderFlags_None) or Changed;
        end;

      pkFrustum:
        begin
          Changed := ImGui.DragFloat('Bottom Radius', @fMeshEditor.BottomRadius, 0.05, 0.001, 100000, '%.2f') or Changed;
          Changed := ImGui.DragFloat('Top Radius', @fMeshEditor.TopRadius, 0.05, 0.001, 100000, '%.2f') or Changed;
          Changed := ImGui.DragFloat('Height', @fMeshEditor.Height, 0.05, 0.001, 100000, '%.2f') or Changed;
          Changed := ImGui.DragInt('Slices', @fMeshEditor.Slices, 1.0, 3, 512, '%d', ImGuiSliderFlags_None) or Changed;
          Changed := ImGui.DragInt('Stacks', @fMeshEditor.Stacks, 1.0, 1, 512, '%d', ImGuiSliderFlags_None) or Changed;
        end;

      pkIcosphere, pkGeodesicDome:
        begin
          Changed := ImGui.DragFloat('Radius', @fMeshEditor.Radius, 0.05, 0.001, 100000, '%.2f') or Changed;
          Changed := ImGui.DragInt('Subdivisions', @fMeshEditor.Subdivisions, 1.0, 0, 6, '%d', ImGuiSliderFlags_None) or Changed;
        end;

      pkArrow:
        begin
          Changed := ImGui.DragFloat('Shaft Length', @fMeshEditor.ShaftLength, 0.05, 0.001, 100000, '%.2f') or Changed;
          Changed := ImGui.DragFloat('Tip Length', @fMeshEditor.TipLength, 0.05, 0.001, 100000, '%.2f') or Changed;
          Changed := ImGui.DragFloat('Shaft Radius', @fMeshEditor.ShaftRadius, 0.005, 0.001, 100000, '%.3f') or Changed;
          Changed := ImGui.DragFloat('Tip Radius', @fMeshEditor.TipRadius, 0.005, 0.001, 100000, '%.3f') or Changed;
          Changed := ImGui.DragInt('Slices', @fMeshEditor.Slices, 1.0, 3, 512, '%d', ImGuiSliderFlags_None) or Changed;
          Changed := ImGui.DragInt('Stacks', @fMeshEditor.Stacks, 1.0, 1, 512, '%d', ImGuiSliderFlags_None) or Changed;
        end;

      pkSuperEllipsoid:
        begin
          Changed := ImGui.DragFloat('Radius', @fMeshEditor.Radius, 0.05, 0.001, 100000, '%.2f') or Changed;
          Changed := ImGui.DragFloat('Vertical Curve', @fMeshEditor.VCurve, 0.05, 0.001, 100000, '%.2f') or Changed;
          Changed := ImGui.DragFloat('Horizontal Curve', @fMeshEditor.HCurve, 0.05, 0.001, 100000, '%.2f') or Changed;
          Changed := ImGui.DragInt('Slices', @fMeshEditor.Slices, 1.0, 3, 512, '%d', ImGuiSliderFlags_None) or Changed;
          Changed := ImGui.DragInt('Stacks', @fMeshEditor.Stacks, 1.0, 2, 512, '%d', ImGuiSliderFlags_None) or Changed;
        end;
    end;
    ImGui.PopItemWidth;

    ImGui.Separator;

    ImGui.PushItemWidth(IMGUI_PROP_VECTOR3_WIDTH);
    Changed := ImGui.DragFloat3('Position', @fMeshEditor.Position[0], 0.05, -100000, 100000, '%.2f') or Changed;
    Changed := ImGui.DragFloat3('Rotation', @fMeshEditor.RotationDeg[0], 0.25, -360, 360, '%.2f') or Changed;
    Changed := ImGui.DragFloat3('Scale', @fMeshEditor.Scale[0], 0.05, 0.001, 100000, '%.2f') or Changed;
    ImGui.PopItemWidth;

    if Changed then
      ApplyMeshEditorPreview;

    ImGui.Separator;

    if ImGui.Button('OK') then
      EndMeshEditor(True);

    ImGui.SameLine;

    if ImGui.Button('Cancel') then
      EndMeshEditor(False);
  end;

  ImGui.End_;
end;

procedure TSandBoxForm.ApplyMeshEditorPreview;
var
  Obj: TSceneObject;
  OldMesh: TMesh;
  NewMesh: TMesh;
  Index: Integer;
  MatLib: TMaterialLibrary;
  MatName: string;
  OnRender: TOnMeshRender;
  Wire: Boolean;
  Visible: Boolean;
  AlwaysOnTop: Boolean;
  TagValue: Integer;
  ParentModel: TMatrix4;
  MeshName: string;
begin
  Obj := fMeshEditor.TargetObject;
  if Obj = nil then
    Exit;

  Index := fMeshEditor.MeshIndex;
  if (Index < 0) or (Index >= Obj.MeshList.Count) then
    Exit;

  OldMesh := Obj.MeshList.Item[Index];
  if OldMesh = nil then
    Exit;

  MatLib := OldMesh.MaterialLibrary;
  MatName := OldMesh.LibMaterialname;
  OnRender := OldMesh.OnRender;
  Wire := OldMesh.WireFrame;
  Visible := OldMesh.Visible;
  AlwaysOnTop := OldMesh.AlwaysOnTop;
  TagValue := OldMesh.Tag;
  ParentModel := OldMesh.ParentModelMatrix;
  MeshName := MeshEditorName;

  NewMesh := CreatePrimitiveMeshFromEditor(MeshName);
  if NewMesh = nil then
    Exit;

  try
    NewMesh.MaterialLibrary := MatLib;
    NewMesh.LibMaterialname := MatName;
    NewMesh.OnRender := OnRender;
    NewMesh.WireFrame := Wire;
    NewMesh.Visible := Visible;
    NewMesh.AlwaysOnTop := AlwaysOnTop;
    NewMesh.Tag := TagValue;
    NewMesh.ParentModelMatrix := ParentModel;
    NewMesh.Position := Vector3(fMeshEditor.Position[0], fMeshEditor.Position[1], fMeshEditor.Position[2]);
    NewMesh.Rotation := Vector3(DegToRad(fMeshEditor.RotationDeg[0]), DegToRad(fMeshEditor.RotationDeg[1]), DegToRad(fMeshEditor.RotationDeg[2]));
    NewMesh.Scale := Vector3(fMeshEditor.Scale[0], fMeshEditor.Scale[1], fMeshEditor.Scale[2]);

    fSelectedMesh := nil;

    if not Obj.MeshList.DeleteMesh(Index) then
      Exit;

    Obj.MeshList.InsertMesh(Index, NewMesh);
    fSelectedMesh := NewMesh;
    fSelectedMeshIndex := Index;
    NewMesh := nil;

    if fMeshEditor.CreatedObject then
      Obj.Name := MeshName;

    Obj.UpdateBoundingRadiusFromMesh;
    Obj.NotifyChange;

    fSelectedObject := Obj;
    fSelectedParticleSystemIndex := -1;
    fSelectedBillboardIndex := -1;
    fSelectedAnimatedSpriteIndex := -1;
    fSelectedAudioEmitterIndex := -1;

    RefreshGizmo;
    RequestRender;
  finally
    NewMesh.Free;
  end;
end;

procedure TSandBoxForm.EndMeshEditor(Accept: Boolean);
var
  Obj: TSceneObject;
  Index: Integer;
  RestoreMesh: TMesh;
begin
  Obj := fMeshEditor.TargetObject;
  Index := fMeshEditor.MeshIndex;

  if not Accept then
  begin
    if fMeshEditor.CreatedObject and Assigned(Obj) then
    begin
      if fSelectedObject = Obj then
      begin
        fSelectedObject := fMeshEditor.PreviousObject;
        fSelectedParticleSystemIndex := -1;
        fSelectedBillboardIndex := -1;
        fSelectedAnimatedSpriteIndex := -1;
        fSelectedAudioEmitterIndex := -1;
      end;

      fSelectedMesh := fMeshEditor.PreviousMesh;
      fSelectedMeshIndex := fMeshEditor.PreviousMeshIndex;

      Obj.Free;
    end
    else if fMeshEditor.CreatedMesh and Assigned(Obj) then
    begin
      if (Index >= 0) and (Index < Obj.MeshList.Count) then
        Obj.MeshList.DeleteMesh(Index);

      fSelectedMesh := fMeshEditor.PreviousMesh;
      fSelectedMeshIndex := fMeshEditor.PreviousMeshIndex;
      Obj.UpdateBoundingRadiusFromMesh;
      Obj.NotifyChange;
    end
    else if Assigned(fMeshEditor.OriginalMesh) and Assigned(Obj) then
    begin
      RestoreMesh := fMeshEditor.OriginalMesh;
      fMeshEditor.OriginalMesh := nil;

      if (Index >= 0) and (Index < Obj.MeshList.Count) and
         Obj.MeshList.DeleteMesh(Index) then
      begin
        Obj.MeshList.InsertMesh(Index, RestoreMesh);
        fSelectedObject := Obj;
        fSelectedMesh := RestoreMesh;
        fSelectedMeshIndex := Index;
        fSelectedParticleSystemIndex := -1;
        fSelectedBillboardIndex := -1;
        fSelectedAnimatedSpriteIndex := -1;
        fSelectedAudioEmitterIndex := -1;
        RestoreMesh := nil;

        Obj.UpdateBoundingRadiusFromMesh;
        Obj.NotifyChange;
      end;

      RestoreMesh.Free;
    end;
  end;

  FreeAndNil(fMeshEditor.OriginalMesh);
  fMeshEditor.Active := False;
  fMeshEditor.TargetObject := nil;
  fMeshEditor.PreviousObject := nil;
  fMeshEditor.PreviousMesh := nil;
  fMeshEditor.PreviousMeshIndex := -1;
  fMeshEditor.MeshIndex := -1;

  RefreshGizmo;
  RequestRender;
end;

function TSandBoxForm.MeshEditorName: string;
begin
  Result := AnsiBufferText(fMeshEditor.Name);

  if Result = '' then
    Result := PrimitiveBaseName(fMeshEditor.Kind);
end;

function TSandBoxForm.MakeUniqueObjectName(ParentObj: TSceneObject; const BaseName: string): string;
var
  I, N: Integer;
  Exists: Boolean;
begin
  N := 1;

  repeat
    Result := BaseName + '_' + IntToStr(N);
    Exists := False;

    if Assigned(ParentObj) then
      for I := 0 to ParentObj.Count - 1 do
        if Assigned(ParentObj.ObjectList[I]) and
           SameText(ParentObj.ObjectList[I].Name, Result) then
        begin
          Exists := True;
          Break;
        end;

    Inc(N);
  until not Exists;
end;

function TSandBoxForm.GenMeshName(const AName: string): string;
var
  I, N: Integer;
  Exists: Boolean;
begin
  N := 1;

  repeat
    Result := AName + IntToStr(N);
    Exists := False;

    if Assigned(fSelectedObject) then
      for I := 0 to fSelectedObject.MeshList.Count - 1 do
        if Assigned(fSelectedObject.MeshList.Item[I]) and
           SameText(fSelectedObject.MeshList.Item[I].Name, Result) then
        begin
          Exists := True;
          Break;
        end;

    Inc(N);
  until not Exists;
end;

function TSandBoxForm.IsMeshEditModeActive: Boolean;
begin
  Result := fEditSelectedMeshTransform and Assigned(fSelectedObject) and
    (not fSelectedObject.IsInstance) and Assigned(fSelectedMesh);
end;

function TSandBoxForm.GetMeshEditorTransformValues(out Translation, RotationDeg,
  Scale: TVector3): Boolean;
begin
  Result := Assigned(fSelectedMesh);
  if not Result then
    Exit;

  Translation := fSelectedMesh.Position;
  RotationDeg := Vector3(RadToDeg(fSelectedMesh.Rotation.X),
    RadToDeg(fSelectedMesh.Rotation.Y), RadToDeg(fSelectedMesh.Rotation.Z));
  Scale := fSelectedMesh.Scale;
end;

procedure TSandBoxForm.SetMeshEditorTransformValues(const Translation, RotationDeg,
  Scale: TVector3; const Preview: Boolean);
begin
  if (fSelectedObject = nil) or (fSelectedMesh = nil) then
    Exit;

  fSelectedObject.UpdateWorldMatrices;
  fSelectedMesh.ParentModelMatrix := fSelectedObject.WorldMatrix;
  fSelectedMesh.SetTransform(Translation,
    Vector3(DegToRad(RotationDeg.X), DegToRad(RotationDeg.Y), DegToRad(RotationDeg.Z)),
    Scale);

  fSelectedObject.UpdateBoundingRadiusFromMesh;
  fSelectedObject.NotifyChange;

  if Assigned(fSceneManager) then
    fSceneManager.Update;

  RefreshGizmo;

  if Preview then
    RequestRender;
end;

function TSandBoxForm.GetGizmoTargetWorldPosition: TVector3;
var
  LocalCenter: TVector3;
begin
  if IsMeshEditModeActive then
  begin
    fSelectedObject.UpdateWorldMatrices;
    fSelectedMesh.ParentModelMatrix := fSelectedObject.WorldMatrix;
    LocalCenter := (fSelectedMesh.BoundingBoxMin + fSelectedMesh.BoundingBoxMax) * 0.5;
    Result := Vector3(fSelectedMesh.ModelMatrix * Vector4(LocalCenter, 1.0));
    Exit;
  end;

  if Assigned(fSelectedObject) then
  begin
    fSelectedObject.UpdateWorldMatrices;
    Result := Vector3(fSelectedObject.WorldMatrix.Columns[3]);
  end
  else
    Result := Vector3(0, 0, 0);
end;

function TSandBoxForm.CreateTranslateGizmo(ParentObj: TSceneObject): TSceneObject;
const
  ArrowLen = 0.5;
  ShaftRad = 0.01;
  TipRad = 0.03;
  TipLen = 0.1;
  CubeSize = 0.1;
  PlaneSize = 0.3;
  PlaneOffset = 0.18;
  PlaneThickness = 0.008;
var
  GizmoRoot, ArrowX, ArrowY, ArrowZ: TSceneObject;
  CenterCube, PlaneXY, PlaneYZ, PlaneXZ: TSceneObject;
  Mesh: TMesh;

  procedure SetupGizmoMesh(AMesh: TMesh; ATag: Integer);
  begin
    AMesh.MaterialLibrary := fGizmoMaterialLibrary;
    AMesh.LibMaterialname := GIZMO_MATERIAL_NAME;
    AMesh.Tag := ATag;
    AMesh.OnRender := GizmoMeshRenderHandler;
    AMesh.AlwaysOnTop := True;
  end;
begin
  EnsureGizmoMaterial;

  GizmoRoot := TSceneObject.Create(fRoot);
  GizmoRoot.Name := 'TranslateGizmo';
  GizmoRoot.IsGizmo := True;
  GizmoRoot.Position := GetGizmoTargetWorldPosition;
  GizmoRoot.Rotation := Vector3(0, 0, 0);

  ArrowX := TSceneObject.Create(GizmoRoot);
  ArrowX.Name := 'Gizmo_X';
  ArrowX.IsGizmo := True;
  Mesh := TMeshFactory.CreateArrow(ArrowLen, TipLen, ShaftRad, TipRad, 12, 4, ArrowX.Name);
  ArrowX.MeshList.AddMeshToList(Mesh);
  SetupGizmoMesh(Mesh, GIZMO_TAG_X);
  ArrowX.Rotation := Vector3(0, 0, DegToRad(90));

  ArrowY := TSceneObject.Create(GizmoRoot);
  ArrowY.Name := 'Gizmo_Y';
  ArrowY.IsGizmo := True;
  Mesh := TMeshFactory.CreateArrow(ArrowLen, TipLen, ShaftRad, TipRad, 12, 4, ArrowY.Name);
  ArrowY.MeshList.AddMeshToList(Mesh);
  SetupGizmoMesh(Mesh, GIZMO_TAG_Y);

  ArrowZ := TSceneObject.Create(GizmoRoot);
  ArrowZ.Name := 'Gizmo_Z';
  ArrowZ.IsGizmo := True;
  Mesh := TMeshFactory.CreateArrow(ArrowLen, TipLen, ShaftRad, TipRad, 12, 4, ArrowZ.Name);
  ArrowZ.MeshList.AddMeshToList(Mesh);
  SetupGizmoMesh(Mesh, GIZMO_TAG_Z);
  ArrowZ.Rotation := Vector3(DegToRad(-90), 0, 0);

  { 2-axis move handles. These are tiny flat cubes, so we can keep using the
    existing mesh ray picker instead of adding a separate 2D handle picker. }
  PlaneXY := TSceneObject.Create(GizmoRoot);
  PlaneXY.Name := 'Gizmo_Move_XY';
  PlaneXY.IsGizmo := True;
  PlaneXY.Position := Vector3(-PlaneOffset, PlaneOffset, 0);
  Mesh := TMeshFactory.CreateCube(PlaneSize, PlaneSize, PlaneThickness, 1, 1, 1, PlaneXY.Name);
  PlaneXY.MeshList.AddMeshToList(Mesh);
  SetupGizmoMesh(Mesh, GIZMO_TAG_XY);

  PlaneYZ := TSceneObject.Create(GizmoRoot);
  PlaneYZ.Name := 'Gizmo_Move_YZ';
  PlaneYZ.IsGizmo := True;
  PlaneYZ.Position := Vector3(0, PlaneOffset, -PlaneOffset);
  Mesh := TMeshFactory.CreateCube(PlaneThickness, PlaneSize, PlaneSize, 1, 1, 1, PlaneYZ.Name);
  PlaneYZ.MeshList.AddMeshToList(Mesh);
  SetupGizmoMesh(Mesh, GIZMO_TAG_YZ);

  PlaneXZ := TSceneObject.Create(GizmoRoot);
  PlaneXZ.Name := 'Gizmo_Move_XZ';
  PlaneXZ.IsGizmo := True;
  PlaneXZ.Position := Vector3(-PlaneOffset, 0, -PlaneOffset);
  Mesh := TMeshFactory.CreateCube(PlaneSize, PlaneThickness, PlaneSize, 1, 1, 1, PlaneXZ.Name);
  PlaneXZ.MeshList.AddMeshToList(Mesh);
  SetupGizmoMesh(Mesh, GIZMO_TAG_XZ);

  CenterCube := TSceneObject.Create(GizmoRoot);
  CenterCube.Name := 'Gizmo_Center';
  CenterCube.IsGizmo := True;
  Mesh := TMeshFactory.CreateCube(CubeSize, CubeSize, CubeSize, 1, 1, 1, CenterCube.Name);
  CenterCube.MeshList.AddMeshToList(Mesh);
  SetupGizmoMesh(Mesh, GIZMO_TAG_CENTER);

  Result := GizmoRoot;
end;

function TSandBoxForm.CreateRotateGizmo(ParentObj: TSceneObject): TSceneObject;
const
  RingRadius = 0.6;
  RingThickness = 0.01;
var
  GizmoRoot, RingX, RingY, RingZ: TSceneObject;
  Mesh: TMesh;
begin
  EnsureGizmoMaterial;

  GizmoRoot := TSceneObject.Create(fRoot);
  GizmoRoot.Name := 'RotateGizmo';
  GizmoRoot.IsGizmo := True;
  GizmoRoot.Position := GetGizmoTargetWorldPosition;
  GizmoRoot.Rotation := Vector3(0, 0, 0);

  RingX := TSceneObject.Create(GizmoRoot);
  RingX.Name := 'Gizmo_RingX';
  RingX.IsGizmo := True;
  Mesh := TMeshFactory.CreateTorus(RingRadius, RingThickness, 32, 16, RingX.Name);
  RingX.MeshList.AddMeshToList(Mesh);
  Mesh.MaterialLibrary := fGizmoMaterialLibrary;
  Mesh.LibMaterialname := GIZMO_MATERIAL_NAME;
  Mesh.Tag := 0;
  Mesh.OnRender := GizmoMeshRenderHandler;
  Mesh.AlwaysOnTop := True;
  RingX.Rotation := Vector3(0, DegToRad(90), 0);

  RingY := TSceneObject.Create(GizmoRoot);
  RingY.Name := 'Gizmo_RingY';
  RingY.IsGizmo := True;
  Mesh := TMeshFactory.CreateTorus(RingRadius, RingThickness, 32, 16, RingY.Name);
  RingY.MeshList.AddMeshToList(Mesh);
  Mesh.MaterialLibrary := fGizmoMaterialLibrary;
  Mesh.LibMaterialname := GIZMO_MATERIAL_NAME;
  Mesh.Tag := 1;
  Mesh.OnRender := GizmoMeshRenderHandler;
  Mesh.AlwaysOnTop := True;
  RingY.Rotation := Vector3(DegToRad(90), 0, 0);

  RingZ := TSceneObject.Create(GizmoRoot);
  RingZ.Name := 'Gizmo_RingZ';
  RingZ.IsGizmo := True;
  Mesh := TMeshFactory.CreateTorus(RingRadius, RingThickness, 32, 16, RingZ.Name);
  RingZ.MeshList.AddMeshToList(Mesh);
  Mesh.MaterialLibrary := fGizmoMaterialLibrary;
  Mesh.LibMaterialname := GIZMO_MATERIAL_NAME;
  Mesh.Tag := 2;
  Mesh.OnRender := GizmoMeshRenderHandler;
  Mesh.AlwaysOnTop := True;

  Result := GizmoRoot;
end;

function TSandBoxForm.CreateScaleGizmo(ParentObj: TSceneObject): TSceneObject;
const
  AxisLen = 0.5;
  ShaftRad = 0.01;
  TipRad = 0.02;
  TipLen = 0.01;
  CubeSize = 0.06;
  CenterCubeSize = 0.1;
  PlaneSize = 0.3;
  PlaneOffset = 0.18;
  PlaneThickness = 0.008;
var
  GizmoRoot, ArrowX, ArrowY, ArrowZ, CubeX, CubeY, CubeZ: TSceneObject;
  CenterCube, PlaneXY, PlaneYZ, PlaneXZ: TSceneObject;
  Mesh: TMesh;

  procedure SetupGizmoMesh(AMesh: TMesh; ATag: Integer);
  begin
    AMesh.MaterialLibrary := fGizmoMaterialLibrary;
    AMesh.LibMaterialname := GIZMO_MATERIAL_NAME;
    AMesh.Tag := ATag;
    AMesh.OnRender := GizmoMeshRenderHandler;
    AMesh.AlwaysOnTop := True;
  end;
begin
  EnsureGizmoMaterial;

  GizmoRoot := TSceneObject.Create(fRoot);
  GizmoRoot.Name := 'ScaleGizmo';
  GizmoRoot.IsGizmo := True;
  GizmoRoot.Position := GetGizmoTargetWorldPosition;
  GizmoRoot.Rotation := Vector3(0, 0, 0);

  ArrowX := TSceneObject.Create(GizmoRoot);
  ArrowX.Name := 'Gizmo_ScaleX_Arrow';
  ArrowX.IsGizmo := True;
  ArrowX.Rotation := Vector3(0, 0, DegToRad(90));
  Mesh := TMeshFactory.CreateArrow(AxisLen, TipLen, ShaftRad, TipRad, 12, 1, ArrowX.Name);
  ArrowX.MeshList.AddMeshToList(Mesh);
  SetupGizmoMesh(Mesh, GIZMO_TAG_X);

  ArrowY := TSceneObject.Create(GizmoRoot);
  ArrowY.Name := 'Gizmo_ScaleY_Arrow';
  ArrowY.IsGizmo := True;
  Mesh := TMeshFactory.CreateArrow(AxisLen, TipLen, ShaftRad, TipRad, 12, 1, ArrowY.Name);
  ArrowY.MeshList.AddMeshToList(Mesh);
  SetupGizmoMesh(Mesh, GIZMO_TAG_Y);

  ArrowZ := TSceneObject.Create(GizmoRoot);
  ArrowZ.Name := 'Gizmo_ScaleZ_Arrow';
  ArrowZ.IsGizmo := True;
  ArrowZ.Rotation := Vector3(DegToRad(-90), 0, 0);
  Mesh := TMeshFactory.CreateArrow(AxisLen, TipLen, ShaftRad, TipRad, 12, 1, ArrowZ.Name);
  ArrowZ.MeshList.AddMeshToList(Mesh);
  SetupGizmoMesh(Mesh, GIZMO_TAG_Z);

  CubeX := TSceneObject.Create(GizmoRoot);
  CubeX.Name := 'Gizmo_ScaleX_Cube';
  CubeX.IsGizmo := True;
  CubeX.Position := Vector3(-AxisLen, 0, 0);
  Mesh := TMeshFactory.CreateCube(CubeSize, CubeSize, CubeSize, 1, 1, 1, CubeX.Name);
  CubeX.MeshList.AddMeshToList(Mesh);
  SetupGizmoMesh(Mesh, GIZMO_TAG_X);

  CubeY := TSceneObject.Create(GizmoRoot);
  CubeY.Name := 'Gizmo_ScaleY_Cube';
  CubeY.IsGizmo := True;
  CubeY.Position := Vector3(0, AxisLen, 0);
  Mesh := TMeshFactory.CreateCube(CubeSize, CubeSize, CubeSize, 1, 1, 1, CubeY.Name);
  CubeY.MeshList.AddMeshToList(Mesh);
  SetupGizmoMesh(Mesh, GIZMO_TAG_Y);

  CubeZ := TSceneObject.Create(GizmoRoot);
  CubeZ.Name := 'Gizmo_ScaleZ_Cube';
  CubeZ.IsGizmo := True;
  CubeZ.Position := Vector3(0, 0, -AxisLen);
  Mesh := TMeshFactory.CreateCube(CubeSize, CubeSize, CubeSize, 1, 1, 1, CubeZ.Name);
  CubeZ.MeshList.AddMeshToList(Mesh);
  SetupGizmoMesh(Mesh, GIZMO_TAG_Z);

  { 2-axis scale handles. Dragging one of these scales the two matching axes
    together. Dragging the center cube scales uniformly on all three axes. }
  PlaneXY := TSceneObject.Create(GizmoRoot);
  PlaneXY.Name := 'Gizmo_Scale_XY';
  PlaneXY.IsGizmo := True;
  PlaneXY.Position := Vector3(-PlaneOffset, PlaneOffset, 0);
  Mesh := TMeshFactory.CreateCube(PlaneSize, PlaneSize, PlaneThickness, 1, 1, 1, PlaneXY.Name);
  PlaneXY.MeshList.AddMeshToList(Mesh);
  SetupGizmoMesh(Mesh, GIZMO_TAG_XY);

  PlaneYZ := TSceneObject.Create(GizmoRoot);
  PlaneYZ.Name := 'Gizmo_Scale_YZ';
  PlaneYZ.IsGizmo := True;
  PlaneYZ.Position := Vector3(0, PlaneOffset, -PlaneOffset);
  Mesh := TMeshFactory.CreateCube(PlaneThickness, PlaneSize, PlaneSize, 1, 1, 1, PlaneYZ.Name);
  PlaneYZ.MeshList.AddMeshToList(Mesh);
  SetupGizmoMesh(Mesh, GIZMO_TAG_YZ);

  PlaneXZ := TSceneObject.Create(GizmoRoot);
  PlaneXZ.Name := 'Gizmo_Scale_XZ';
  PlaneXZ.IsGizmo := True;
  PlaneXZ.Position := Vector3(-PlaneOffset, 0, -PlaneOffset);
  Mesh := TMeshFactory.CreateCube(PlaneSize, PlaneThickness, PlaneSize, 1, 1, 1, PlaneXZ.Name);
  PlaneXZ.MeshList.AddMeshToList(Mesh);
  SetupGizmoMesh(Mesh, GIZMO_TAG_XZ);

  CenterCube := TSceneObject.Create(GizmoRoot);
  CenterCube.Name := 'Gizmo_Scale_Center';
  CenterCube.IsGizmo := True;
  Mesh := TMeshFactory.CreateCube(CenterCubeSize, CenterCubeSize, CenterCubeSize, 1, 1, 1, CenterCube.Name);
  CenterCube.MeshList.AddMeshToList(Mesh);
  SetupGizmoMesh(Mesh, GIZMO_TAG_CENTER);

  Result := GizmoRoot;
end;

procedure TSandBoxForm.RefreshGizmo;
var
  NeedRebuild: Boolean;
begin
  if (fSelectedObject = nil) or fSelectedObject.IsGizmo or (fRoot = nil) or
     (fSelectedObject = fSceneWorld) or (fSelectedObject = fCamera) then
  begin
    if Assigned(fCurrentGizmo) then
      FreeAndNil(fCurrentGizmo);
    fGizmoOwner := nil;
    fHoveredAxis := -1;
    Exit;
  end;

  NeedRebuild := (fCurrentGizmo = nil) or
    (fGizmoOwner <> fSelectedObject) or
    (fBuiltGizmoMode <> fGizmoMode);

  if NeedRebuild then
  begin
    if Assigned(fCurrentGizmo) then
      FreeAndNil(fCurrentGizmo);

    case fGizmoMode of
      gmTranslate: fCurrentGizmo := CreateTranslateGizmo(fSelectedObject);
      gmRotate: fCurrentGizmo := CreateRotateGizmo(fSelectedObject);
      gmScale: fCurrentGizmo := CreateScaleGizmo(fSelectedObject);
    end;

    fGizmoOwner := fSelectedObject;
    fBuiltGizmoMode := fGizmoMode;
  end;

  if Assigned(fCurrentGizmo) then
  begin
    fCurrentGizmo.Position := GetGizmoTargetWorldPosition;
    fCurrentGizmo.Rotation := Vector3(0, 0, 0);
    UpdateGizmoScale;
    fCurrentGizmo.UpdateWorldMatrices;
  end;
end;

procedure TSandBoxForm.UpdateGizmoScale;
const
  GIZMO_REF_SIZE = 0.6;
var
  Dist: Single;
  WorldSizeDesired: Single;
  ScaleFactor: Single;
  ViewportHeight: Integer;
  WorldPos: TVector3;
begin
  if (fCurrentGizmo = nil) or (fSelectedObject = nil) or
     (fCamera = nil) or (fCamera.Camera = nil) or (fRenderer = nil) then
    Exit;

  WorldPos := GetGizmoTargetWorldPosition;
  Dist := (fCamera.Camera.Position - WorldPos).Length;
  if Dist < 0.01 then
    Dist := 0.01;

  ViewportHeight := fRenderer.Height;
  if ViewportHeight <= 0 then
    ViewportHeight := EditorViewportHeight;
  if ViewportHeight <= 0 then
    Exit;

  WorldSizeDesired := (GIZMO_SCREEN_SIZE_PX * Dist * 2 * Tan(fFOVRadians * 0.5)) / ViewportHeight;
  ScaleFactor := WorldSizeDesired / GIZMO_REF_SIZE;
  if ScaleFactor < 0.000001 then
    ScaleFactor := 0.000001;

  fCurrentGizmo.Scale := Vector3(ScaleFactor, ScaleFactor, ScaleFactor);
  fCurrentGizmo.NotifyChange;
  fCurrentGizmo.UpdateWorldMatrices;

  if Assigned(fSceneManager) then
    fSceneManager.Update;
end;

function TSandBoxForm.PickGizmoAxis(X, Y: Integer; out AxisTag: Integer): Boolean;
var
  RayOrigin, RayDir: TVector3;
  BestT: Single;
  I: Integer;
  Obj: TSceneObject;
  Mesh: TMesh;
  HitT: Single;

  function ProjectWorldToScreen(const P: TVector3; out S: TVector2): Boolean;
  var
    Clip: TVector4;
    NDC: TVector3;
  begin
    Result := False;

    if (fCamera = nil) or (fCamera.Camera = nil) or (fRenderer = nil) then
      Exit;

    Clip := fRenderer.ProjectionMatrix * (fCamera.Camera.ViewMatrix * Vector4(P, 1));
    if Abs(Clip.W) < 1e-6 then
      Exit;

    NDC := Vector3(Clip.X / Clip.W, Clip.Y / Clip.W, Clip.Z / Clip.W);
    S := Vector2(
      (NDC.X * 0.5 + 0.5) * EditorViewportWidth,
      (1.0 - (NDC.Y * 0.5 + 0.5)) * EditorViewportHeight
    );
    Result := True;
  end;

  function DistancePointToSegmentSq(const P, A, B: TVector2): Single;
  var
    VX, VY, WX, WY: Single;
    C1, C2, T: Single;
    ClosestX, ClosestY: Single;
    DX, DY: Single;
  begin
    VX := B.X - A.X;
    VY := B.Y - A.Y;
    WX := P.X - A.X;
    WY := P.Y - A.Y;

    C1 := WX * VX + WY * VY;
    C2 := VX * VX + VY * VY;

    if C2 <= 0.0001 then
    begin
      DX := P.X - A.X;
      DY := P.Y - A.Y;
      Result := DX * DX + DY * DY;
      Exit;
    end;

    T := C1 / C2;
    if T < 0.0 then
      T := 0.0
    else if T > 1.0 then
      T := 1.0;

    ClosestX := A.X + VX * T;
    ClosestY := A.Y + VY * T;
    DX := P.X - ClosestX;
    DY := P.Y - ClosestY;
    Result := DX * DX + DY * DY;
  end;

  function PickScreenSpaceAxis(out ScreenAxisTag: Integer): Boolean;
  const
    AxisStartOffset = 0.04;
    AxisEndOffset = 0.62;
  var
    MousePos, Start2D, End2D: TVector2;
    Center, AxisVec, WorldStart, WorldEnd: TVector3;
    ScaleFactor: Single;
    Tag: Integer;
    DistSq, BestDistSq: Single;
  begin
    Result := False;
    ScreenAxisTag := -1;
    MousePos := Vector2(X, Y);
    BestDistSq := Sqr(GIZMO_PICK_TOLERANCE_PX);

    Center := GetGizmoTargetWorldPosition;
    ScaleFactor := 1.0;
    if Assigned(fCurrentGizmo) then
      ScaleFactor := fCurrentGizmo.Scale.X;

    for Tag := GIZMO_TAG_X to GIZMO_TAG_Z do
    begin
      case Tag of
        GIZMO_TAG_X: AxisVec := Vector3(1, 0, 0);
        GIZMO_TAG_Y: AxisVec := Vector3(0, 1, 0);
        GIZMO_TAG_Z: AxisVec := Vector3(0, 0, 1);
      else
        AxisVec := Vector3(0, 0, 0);
      end;

      WorldStart := Center + AxisVec * (AxisStartOffset * ScaleFactor);
      WorldEnd := Center + AxisVec * (AxisEndOffset * ScaleFactor);

      if not ProjectWorldToScreen(WorldStart, Start2D) then
        Continue;
      if not ProjectWorldToScreen(WorldEnd, End2D) then
        Continue;

      DistSq := DistancePointToSegmentSq(MousePos, Start2D, End2D);
      if DistSq < BestDistSq then
      begin
        BestDistSq := DistSq;
        ScreenAxisTag := Tag;
        Result := True;
      end;
    end;
  end;

begin
  Result := False;
  AxisTag := -1;

  if (fCurrentGizmo = nil) or (fSelectedObject = nil) or
     (fCamera = nil) or (fCamera.Camera = nil) or (fRenderer = nil) then
    Exit;

  ScreenToWorldRay(X, Y, EditorViewportWidth, EditorViewportHeight,
    fCamera.Camera.ViewMatrix, fRenderer.ProjectionMatrix, RayOrigin, RayDir);

  BestT := MaxSingle;

  for I := 0 to fCurrentGizmo.Count - 1 do
  begin
    Obj := fCurrentGizmo.ObjectList[I];
    if (Obj = nil) or (Obj.MeshList.Count = 0) then
      Continue;

    Mesh := Obj.MeshList.Item[0];
    if (Mesh = nil) or not (Mesh.Tag in [GIZMO_TAG_X, GIZMO_TAG_Y, GIZMO_TAG_Z,
      GIZMO_TAG_CENTER, GIZMO_TAG_XY, GIZMO_TAG_YZ, GIZMO_TAG_XZ]) then
      Continue;

    if RayIntersectsMesh(RayOrigin, RayDir, Mesh.Indices, Mesh.Vertices,
      Mesh.ModelMatrix, HitT) and (HitT < BestT) then
    begin
      BestT := HitT;
      AxisTag := Mesh.Tag;
    end;
  end;

  { The real mesh hit test is very exact; thin gizmo arrows can be annoying to
    hover/select. If the mouse did not hit a gizmo mesh, fall back to a small
    screen-space distance test against the visible X/Y/Z axis lines. }
  if (AxisTag = -1) and (fGizmoMode <> gmRotate) and PickScreenSpaceAxis(AxisTag) then
  begin
    Result := True;
    Exit;
  end;

  Result := AxisTag <> -1;
end;

function TSandBoxForm.PickRotateAxis(X, Y: Integer; out AxisTag: Integer): Boolean;
begin
  Result := PickGizmoAxis(X, Y, AxisTag) and IsSingleAxisGizmoTag(AxisTag);
end;

function TSandBoxForm.PickScaleGizmoAxis(X, Y: Integer; out AxisTag: Integer): Boolean;
begin
  Result := PickGizmoAxis(X, Y, AxisTag);
end;

function TSandBoxForm.GizmoAxisMask(AxisTag: Integer): Integer;
begin
  case AxisTag of
    GIZMO_TAG_X: Result := 1;
    GIZMO_TAG_Y: Result := 2;
    GIZMO_TAG_Z: Result := 4;
    GIZMO_TAG_CENTER: Result := 1 or 2 or 4;
    GIZMO_TAG_XY: Result := 1 or 2;
    GIZMO_TAG_YZ: Result := 2 or 4;
    GIZMO_TAG_XZ: Result := 1 or 4;
  else
    Result := 0;
  end;
end;

function TSandBoxForm.IsSingleAxisGizmoTag(AxisTag: Integer): Boolean;
begin
  Result := AxisTag in [GIZMO_TAG_X, GIZMO_TAG_Y, GIZMO_TAG_Z];
end;

function TSandBoxForm.IsPlaneGizmoTag(AxisTag: Integer): Boolean;
begin
  Result := AxisTag in [GIZMO_TAG_XY, GIZMO_TAG_YZ, GIZMO_TAG_XZ];
end;

function TSandBoxForm.IsCenterGizmoTag(AxisTag: Integer): Boolean;
begin
  Result := AxisTag = GIZMO_TAG_CENTER;
end;

function TSandBoxForm.GetGizmoPlaneNormalByTag(AxisTag: Integer): TVector3;
begin
  case AxisTag of
    GIZMO_TAG_XY: Result := Vector3(0, 0, 1);
    GIZMO_TAG_YZ: Result := Vector3(1, 0, 0);
    GIZMO_TAG_XZ: Result := Vector3(0, 1, 0);
  else
    begin
      if Assigned(fCamera) and Assigned(fCamera.Camera) then
      begin
        Result := fCamera.Camera.Front;
        if Result.Length > 0.0001 then
          Result.SetNormalized
        else
          Result := Vector3(0, 0, 1);
      end
      else
        Result := Vector3(0, 0, 1);
    end;
  end;
end;

function TSandBoxForm.RayPlaneIntersectionAtScreen(X, Y: Integer; const PlanePoint,
  PlaneNormal: TVector3; out HitPoint: TVector3): Boolean;
var
  RayOrigin, RayDir: TVector3;
  Denom: Single;
  T: Single;
begin
  Result := False;
  HitPoint := PlanePoint;

  if (fCamera = nil) or (fCamera.Camera = nil) or (fRenderer = nil) then
    Exit;

  ScreenToWorldRay(X, Y, EditorViewportWidth, EditorViewportHeight,
    fCamera.Camera.ViewMatrix, fRenderer.ProjectionMatrix, RayOrigin, RayDir);

  Denom := PlaneNormal.Dot(RayDir);
  if Abs(Denom) < 1e-5 then
    Exit;

  T := PlaneNormal.Dot(PlanePoint - RayOrigin) / Denom;
  if T < 0 then
    Exit;

  HitPoint := RayOrigin + RayDir * T;
  Result := True;
end;

function TSandBoxForm.GetArrowTipByTag(AxisTag: Integer): TVector3;
const
  ArrowLen = 0.5;
var
  Axis: TVector3;
  ScaleFactor: Single;
begin
  case AxisTag of
    GIZMO_TAG_X: Axis := Vector3(1, 0, 0);
    GIZMO_TAG_Y: Axis := Vector3(0, 1, 0);
    GIZMO_TAG_Z: Axis := Vector3(0, 0, 1);
  else
    Axis := Vector3(0, 0, 0);
  end;

  ScaleFactor := 1.0;
  if Assigned(fCurrentGizmo) then
    ScaleFactor := fCurrentGizmo.Scale.X;

  Result := GetGizmoTargetWorldPosition + Axis * (ArrowLen * ScaleFactor);
end;

function TSandBoxForm.GetScaleTipByTag(AxisTag: Integer): TVector3;
begin
  Result := GetScaleHandleWorldPosition(AxisTag);
end;

function TSandBoxForm.GetScaleHandleWorldPosition(AxisTag: Integer): TVector3;
const
  PlaneOffset = 0.18;
var
  ScaleFactor: Single;
  Center: TVector3;
begin
  Center := GetGizmoTargetWorldPosition;

  if IsSingleAxisGizmoTag(AxisTag) then
  begin
    Result := GetArrowTipByTag(AxisTag);
    Exit;
  end;

  ScaleFactor := 1.0;
  if Assigned(fCurrentGizmo) then
    ScaleFactor := fCurrentGizmo.Scale.X;

  case AxisTag of
    GIZMO_TAG_XY:
      Result := Center + Vector3(-PlaneOffset, PlaneOffset, 0) * ScaleFactor;
    GIZMO_TAG_YZ:
      Result := Center + Vector3(0, PlaneOffset, -PlaneOffset) * ScaleFactor;
    GIZMO_TAG_XZ:
      Result := Center + Vector3(-PlaneOffset, 0, -PlaneOffset) * ScaleFactor;
  else
    Result := Center;
  end;
end;

function TSandBoxForm.GetDragParameter(CurrentX, CurrentY: Integer; out U: Single): Boolean;
var
  RayOrigin, RayDir: TVector3;
  W: TVector3;
  A, B, C, D, E, Denom: Single;
begin
  Result := False;
  U := 0;

  if (fCamera = nil) or (fCamera.Camera = nil) or (fRenderer = nil) then
    Exit;

  ScreenToWorldRay(CurrentX, CurrentY, EditorViewportWidth, EditorViewportHeight,
    fCamera.Camera.ViewMatrix, fRenderer.ProjectionMatrix, RayOrigin, RayDir);

  W := RayOrigin - fDragStartObjectPos;
  A := RayDir.Dot(RayDir);
  B := RayDir.Dot(fDragAxisWorldDir);
  C := fDragAxisWorldDir.Dot(fDragAxisWorldDir);
  D := RayDir.Dot(W);
  E := fDragAxisWorldDir.Dot(W);
  Denom := A * C - B * B;

  if Abs(Denom) < 1e-4 then
    Exit;

  U := (A * E - B * D) / Denom;
  Result := True;
end;

procedure TSandBoxForm.CheckGizmoHover(X, Y: Integer);
var
  Axis: Integer;
  OldHoveredAxis: Integer;
begin
  OldHoveredAxis := fHoveredAxis;

  if fCurrentGizmo = nil then
  begin
    fHoveredAxis := -1;
    if OldHoveredAxis <> fHoveredAxis then
      RequestRender;
    Exit;
  end;

  case fGizmoMode of
    gmTranslate:
      if PickGizmoAxis(X, Y, Axis) then
        fHoveredAxis := Axis
      else
        fHoveredAxis := -1;

    gmRotate:
      if PickRotateAxis(X, Y, Axis) then
        fHoveredAxis := Axis
      else
        fHoveredAxis := -1;

    gmScale:
      if PickScaleGizmoAxis(X, Y, Axis) then
        fHoveredAxis := Axis
      else
        fHoveredAxis := -1;
  else
    fHoveredAxis := -1;
  end;

  if OldHoveredAxis <> fHoveredAxis then
    RequestRender;
end;

function TSandBoxForm.SelectObjectAtScreenPos(X, Y: Integer): Boolean;
const
  PICK_TIE_EPSILON = 1e-4;
var
  RayOrigin, RayDir: TVector3;
  BestHit: TSceneObject;
  BestMeshIndex: Integer;
  BestT: Single;
  BestBillboardHit: TSceneObject;
  BestBillboardIndex: Integer;
  BestBillboardDistSq: Single;
  BestAnimatedSpriteHit: TSceneObject;
  BestAnimatedSpriteIndex: Integer;
  BestAnimatedSpriteDistSq: Single;

  function ProjectWorldToScreen(const P: TVector3; out S: TVector2): Boolean;
  var
    Clip: TVector4;
    NDC: TVector3;
  begin
    Result := False;
    if (fCamera = nil) or (fCamera.Camera = nil) or (fRenderer = nil) then
      Exit;

    Clip := fRenderer.ProjectionMatrix * (fCamera.Camera.ViewMatrix * Vector4(P, 1));
    if Abs(Clip.W) < 1e-6 then
      Exit;

    NDC := Vector3(Clip.X / Clip.W, Clip.Y / Clip.W, Clip.Z / Clip.W);
    if (NDC.Z < -1.0) or (NDC.Z > 1.0) then
      Exit;

    S := Vector2(
      (NDC.X * 0.5 + 0.5) * EditorViewportWidth,
      (1.0 - (NDC.Y * 0.5 + 0.5)) * EditorViewportHeight
    );
    Result := True;
  end;

  procedure TestMesh(Obj: TSceneObject);
  var
    I, J: Integer;
    Mesh: TMesh;
    Meshes: TMeshList;
    WorldV0, WorldV1, WorldV2: TVector3;
    T, U, V: Single;
    SphereDist: Single;
    WorldCenter: TVector3;
    Indices: TArray<GLuint>;
    Vertices: TArray<TVertex>;
  begin
    if (Obj = nil) or Obj.IsGizmo or (Obj = fRoot) or (Obj = fSceneWorld) or
       (Obj = fCamera) then
      Exit;

    Meshes := Obj.EffectiveMeshList;
    if (Meshes = nil) or (Meshes.Count = 0) then
      Exit;

    WorldCenter := Vector3(Obj.WorldMatrix.Columns[3]);
    if (Obj.BoundingRadius > 0) and
       (not IntersectRaySphere(RayOrigin, RayDir, WorldCenter, Obj.BoundingRadius, SphereDist)) then
      Exit;

    if (Obj.BoundingRadius > 0) and (SphereDist > BestT) then
      Exit;

    for I := 0 to Meshes.Count - 1 do
    begin
      Mesh := Meshes.Item[I];
      if Mesh = nil then
        Continue;

      Mesh.ParentModelMatrix := Obj.WorldMatrix;

      Indices := Mesh.Indices;
      Vertices := Mesh.Vertices;
      J := 0;
      while J + 2 < Length(Indices) do
      begin
        WorldV0 := Vector3(Mesh.ModelMatrix * Vector4(Vertices[Indices[J]].Position, 1));
        WorldV1 := Vector3(Mesh.ModelMatrix * Vector4(Vertices[Indices[J + 1]].Position, 1));
        WorldV2 := Vector3(Mesh.ModelMatrix * Vector4(Vertices[Indices[J + 2]].Position, 1));

        if IntersectRayTriangle(RayOrigin, RayDir, WorldV0, WorldV1, WorldV2, T, U, V) then
          if (BestHit = nil) or (T < BestT - PICK_TIE_EPSILON) or
             (Abs(T - BestT) <= PICK_TIE_EPSILON) then
          begin
            BestHit := Obj;
            BestMeshIndex := I;
            BestT := T;
          end;

        Inc(J, 3);
      end;
    end;
  end;

  procedure TestBillboards(Obj: TSceneObject);
  var
    B: Integer;
    Billboard: TBillboard;
    WorldPos: TVector3;
    ScreenPos: TVector2;
    DX, DY, DistSq: Single;
  begin
    if (Obj = nil) or Obj.IsGizmo or (Obj = fRoot) or (Obj = fSceneWorld) or
       (Obj = fCamera) then
      Exit;

    for B := 0 to Obj.BillboardCount - 1 do
    begin
      Billboard := Obj.BillboardItem[B];
      if (Billboard = nil) or (not Billboard.Enabled) or
         (Billboard.Color.W <= 0.001) then
        Continue;

      WorldPos := Vector3(Obj.WorldMatrix * Vector4(Billboard.Offset, 1.0));
      if not ProjectWorldToScreen(WorldPos, ScreenPos) then
        Continue;

      DX := ScreenPos.X - X;
      DY := ScreenPos.Y - Y;
      DistSq := DX * DX + DY * DY;
      if (DistSq <= Sqr(BILLBOARD_PICK_RADIUS_PX)) and
         ((BestBillboardHit = nil) or (DistSq < BestBillboardDistSq)) then
      begin
        BestBillboardHit := Obj;
        BestBillboardIndex := B;
        BestBillboardDistSq := DistSq;
      end;
    end;
  end;

  procedure TestAnimatedSprites(Obj: TSceneObject);
  var
    S: Integer;
    AnimatedSprite: TAnimatedSprite;
    WorldPos: TVector3;
    ScreenPos: TVector2;
    DX, DY, DistSq: Single;
  begin
    if (Obj = nil) or Obj.IsGizmo or (Obj = fRoot) or (Obj = fSceneWorld) or
       (Obj = fCamera) then
      Exit;

    for S := 0 to Obj.AnimatedSpriteCount - 1 do
    begin
      AnimatedSprite := Obj.AnimatedSpriteItem[S];
      if (AnimatedSprite = nil) or (not AnimatedSprite.Enabled) or
         (AnimatedSprite.Color.W <= 0.001) then
        Continue;

      WorldPos := Vector3(Obj.WorldMatrix * Vector4(AnimatedSprite.Offset, 1.0));
      if not ProjectWorldToScreen(WorldPos, ScreenPos) then
        Continue;

      DX := ScreenPos.X - X;
      DY := ScreenPos.Y - Y;
      DistSq := DX * DX + DY * DY;
      if (DistSq <= Sqr(ANIMATED_SPRITE_PICK_RADIUS_PX)) and
         ((BestAnimatedSpriteHit = nil) or
          (DistSq < BestAnimatedSpriteDistSq)) then
      begin
        BestAnimatedSpriteHit := Obj;
        BestAnimatedSpriteIndex := S;
        BestAnimatedSpriteDistSq := DistSq;
      end;
    end;
  end;

  procedure Traverse(Obj: TSceneObject);
  var
    K: Integer;
  begin
    if Obj = nil then
      Exit;

    TestMesh(Obj);
    TestBillboards(Obj);
    TestAnimatedSprites(Obj);
    for K := 0 to Obj.Count - 1 do
      Traverse(Obj.ObjectList[K]);
  end;
var
  I: Integer;
begin
  Result := False;

  if (fRoot = nil) or (fSceneManager = nil) or (fCamera = nil) or
     (fCamera.Camera = nil) or (fRenderer = nil) then
    Exit;

  fSceneManager.Update;
  ScreenToWorldRay(X, Y, EditorViewportWidth, EditorViewportHeight,
    fCamera.Camera.ViewMatrix, fRenderer.ProjectionMatrix, RayOrigin, RayDir);

  BestHit := nil;
  BestMeshIndex := -1;
  BestT := MaxSingle;
  BestBillboardHit := nil;
  BestBillboardIndex := -1;
  BestBillboardDistSq := MaxSingle;
  BestAnimatedSpriteHit := nil;
  BestAnimatedSpriteIndex := -1;
  BestAnimatedSpriteDistSq := MaxSingle;

  for I := 0 to fRoot.Count - 1 do
    Traverse(fRoot.ObjectList[I]);

  if (BestAnimatedSpriteHit <> nil) and
     ((BestBillboardHit = nil) or
      (BestAnimatedSpriteDistSq < BestBillboardDistSq)) then
  begin
    SelectObjectFromImGui(BestAnimatedSpriteHit);
    SelectAnimatedSpriteIndex(BestAnimatedSpriteIndex);
    Exit(True);
  end;

  if BestBillboardHit <> nil then
  begin
    SelectObjectFromImGui(BestBillboardHit);
    SelectBillboardIndex(BestBillboardIndex);
    Exit(True);
  end;

  Result := BestHit <> nil;
  if not Result then
    Exit;

  SelectObjectFromImGui(BestHit);
  if BestMeshIndex >= 0 then
    SelectMeshIndex(BestMeshIndex);
end;

procedure TSandBoxForm.DeselectObject;
begin
  fSelectedObject := nil;
  fSelectedMesh := nil;
  fSelectedMeshIndex := -1;
  fSelectedParticleSystemIndex := -1;
  fSelectedBillboardIndex := -1;
  fSelectedAnimatedSpriteIndex := -1;
  fSelectedAudioEmitterIndex := -1;
  //fPhysicsBody := nil;
  //fTransformObject := nil;
  fGizmoOwner := nil;

  //fLastPickedMeshIndex := -1;
  fHoveredAxis := -1;
  fDraggingGizmo := False;
  fGizmoClonePending := False;
  fGizmoCloneSource := nil;
  //fNewObjectMode := False;

  if Assigned(fCurrentGizmo) then
    FreeAndNil(fCurrentGizmo);

  //ClearPhysicsDebugHull;
  //RefreshSelectedBoundingBox;
  //UpdateObjectCommandStates;
  //UpdateSceneStatusBar;

  if Assigned(fRenderer) then
    fRenderer.Render;
end;

procedure TSandBoxForm.RenderGizmoOverlay;
var
  OldDepthFunc: GLint;
  OldDepthMask: GLboolean;
  OldDepthTestEnabled: GLboolean;
  OldBlendEnabled: GLboolean;
begin
  if fCurrentGizmo = nil then
    Exit;

  if fRenderer = nil then
    Exit;

  // Save current GL state.
  glGetIntegerv(GL_DEPTH_FUNC, @OldDepthFunc);
  glGetBooleanv(GL_DEPTH_WRITEMASK, @OldDepthMask);
  OldDepthTestEnabled := glIsEnabled(GL_DEPTH_TEST);
  OldBlendEnabled := glIsEnabled(GL_BLEND);

  try
    // Key trick:
    // Remove scene depth, but keep color.
    // The gizmo will now draw on top of the scene, but because depth testing
    // and depth writing are enabled, gizmo parts still sort against each other.
    glClear(GL_DEPTH_BUFFER_BIT);

    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
    glDepthMask(GL_TRUE);

    // Use solid gizmo pass. If your gizmo shader uses alpha, you may enable blend,
    // but for the standard axis gizmo this should stay disabled.
    glDisable(GL_BLEND);

    fCurrentGizmo.UpdateWorldMatrices;
    RenderGizmoOverlayObject(fCurrentGizmo);
  finally
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

procedure TSandBoxForm.RenderGizmoOverlayObject(Obj: TSceneObject);
var
  I: Integer;
  Mesh: TMesh;
  OldAlwaysOnTop: Boolean;
begin
  if Obj = nil then
    Exit;

  for I := 0 to Obj.MeshList.Count - 1 do
  begin
    Mesh := Obj.MeshList.Item[I];

    if Mesh = nil then
      Continue;

    // Important:
    // Temporarily disable AlwaysOnTop so TMesh.Draw does NOT use GL_ALWAYS.
    // We already handled "on top" by clearing the depth buffer before this pass.
    OldAlwaysOnTop := Mesh.AlwaysOnTop;
    Mesh.AlwaysOnTop := False;
    try
      Mesh.Draw;
    finally
      Mesh.AlwaysOnTop := OldAlwaysOnTop;
    end;
  end;

  for I := 0 to Obj.Count - 1 do
    RenderGizmoOverlayObject(Obj.ObjectList[I]);
end;

procedure TSandBoxForm.DoProgress(Sender: TObject; const DeltaTime, NewTime: Double);
begin
  try
    UpdateScene(DeltaTime, NewTime);
    ProcessRenderTextureCapture;

    if fEngine <> nil then
    begin
      fRenderRequested := False;
      fEngine.Render;
      Caption := Format('OpenGL Micro Engine - FPS: %d - Shadow meshes: %d',
        [fRenderer.FPS, fRenderer.ShadowDrawCount]);
    end;
  except
    on E: Exception do
    begin
      if Assigned(Timer) then
        Timer.Enabled := False;
      LogLine('Exception in DoProgress: ' + E.ClassName + ': ' + E.Message);
      raise;
    end;
  end;
end;

procedure TSandBoxForm.FormResizeHandler(Sender: TObject);
begin
  if (EditorViewportWidth = 0) or (EditorViewportHeight = 0) then
    Exit;

  if fEngine <> nil then
  begin
    fEngine.Resize(EditorViewportWidth, EditorViewportHeight);
    fEngine.Render;
  end;
end;

procedure TSandBoxForm.FormCloseHandler(Sender: TObject; var Action: TCloseAction);
begin
  // Save confirmation can be implemented as an ImGui modal once scene saving is ported.
  Action := caFree;
end;

procedure TSandBoxForm.FormMouseWheelHandler(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
var
  Pt: TPoint;
  ZoomSteps: Single;
  WheelBelongsToImGui: Boolean;
begin
  Pt := ScreenToClient(MousePos);
  WheelBelongsToImGui := False;

  if fUseImGuiEditor and Assigned(fImGui) then
  begin
    fImGui.MouseMove(Pt.X, Pt.Y);

    {
      Do this test before applying the editor zoom.

      WantCaptureMouse is updated by ImGui during NewFrame, so during a VCL
      mouse-wheel event it can be one frame behind. MouseOverUi also checks
      hovered/active ImGui windows/items, which is exactly what we need for
      scrolling child windows, panels, list boxes, tree views, combo popups, etc.
    }
    WheelBelongsToImGui := ScriptSourceEditorContainsPoint(Pt.X, Pt.Y) or
      ImGuiBlocksSceneMouse or fImGui.MouseOverUi or fImGui.WantCaptureMouse;

    fImGui.MouseWheel(WheelDelta);

    if WheelBelongsToImGui then
    begin
      Handled := True;
      RequestRender;
      Exit;
    end;
  end;

  ZoomSteps := WheelDelta / WHEEL_DELTA;

  if ZoomSteps <> 0 then
    fTargetRadius := fTargetRadius * System.Math.Power(fZoomSpeed, ZoomSteps);

  if fTargetRadius < 0.001 then
    fTargetRadius := 0.001;

  Handled := True;
end;

procedure TSandBoxForm.FormMouseDownHandler(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Axis: Integer;
  Hit: Boolean;
  ImGuiHit: Boolean;
  Viewport: array[0..3] of GLint;
  ModelView, Proj: TMatrix4;
  Clip: TVector4;
  NDC: TVector3;
  WorldAxisEnd: TVector3;
  EndX, EndY: Integer;
  InitDeltaX, InitDeltaY: Integer;
  GrabU: Single;
  PlaneHit: TVector3;
begin
  if CanFocus then
    SetFocus;

  if fUseImGuiEditor and Assigned(fImGui) then
  begin
    fImGui.MouseMove(X, Y);
    ImGuiHit := ScriptSourceEditorContainsPoint(X, Y) or
      ImGuiBlocksSceneMouse or fImGui.MouseOverUi or fImGui.WantCaptureMouse;
    fImGui.MouseDown(Button);

    if ImGuiHit or fImGui.WantCaptureMouse then
    begin
      fImGuiMouseCaptured := True;
      SetCapture(Handle);
      RequestRender;
      Exit;
    end;
  end;

  if Button = mbLeft then
  begin
    RefreshGizmo;
    Hit := False;

    case fGizmoMode of
      gmTranslate: Hit := PickGizmoAxis(X, Y, Axis);
      gmRotate: Hit := PickRotateAxis(X, Y, Axis);
      gmScale: Hit := PickScaleGizmoAxis(X, Y, Axis);
    end;

    if Hit then
    begin
      fDraggingGizmo := True;
      fDraggedAxis := Axis;
      fHoveredAxis := Axis;
      fGizmoClonePending := (ssShift in Shift) and
        (not IsMeshEditModeActive) and (not IsProtectedSceneObject(fSelectedObject));
      if fGizmoClonePending then
        fGizmoCloneSource := fSelectedObject
      else
        fGizmoCloneSource := nil;
      fDragStartMousePos := Point(X, Y);
      fDragStartObjectPos := GetGizmoTargetWorldPosition;
      fDragAxisMask := GizmoAxisMask(Axis);

      case Axis of
        GIZMO_TAG_X: fDragAxisWorldDir := Vector3(1, 0, 0);
        GIZMO_TAG_Y: fDragAxisWorldDir := Vector3(0, 1, 0);
        GIZMO_TAG_Z: fDragAxisWorldDir := Vector3(0, 0, 1);
      else
        fDragAxisWorldDir := Vector3(0, 0, 0);
      end;

      if IsSingleAxisGizmoTag(Axis) then
        fDragAxisWorldDir.SetNormalized;

      if IsMeshEditModeActive then
        GetMeshEditorTransformValues(fMeshDragStartTranslation,
          fMeshDragStartRotationDeg, fMeshDragStartScale);

      if fGizmoMode = gmTranslate then
      begin
        if IsSingleAxisGizmoTag(Axis) then
        begin
          { Keep the exact grabbed point on the axis under the cursor.
            Without this, dragging starts from the gizmo tip/origin and the
            selected object or mesh jumps as soon as the mouse moves. }
          if GetDragParameter(X, Y, GrabU) then
            fDragOffsetWorld := fDragAxisWorldDir * GrabU
          else
            fDragOffsetWorld := Vector3(0, 0, 0);
        end
        else
        begin
          { 2-axis move and center free-move use a drag plane. XY/YZ/XZ use
            their matching world plane; center uses the camera-facing plane. }
          fDragPlaneNormal := GetGizmoPlaneNormalByTag(Axis);
          if not RayPlaneIntersectionAtScreen(X, Y, fDragStartObjectPos,
            fDragPlaneNormal, fDragStartPlaneHit) then
            fDragStartPlaneHit := fDragStartObjectPos;
        end;
      end
      else if fGizmoMode = gmRotate then
        fRotateStartAngleSet := False
      else if fGizmoMode = gmScale then
      begin
        fDragStartHandlePos := GetScaleHandleWorldPosition(Axis);

        if IsMeshEditModeActive then
          fInitialScale := fMeshDragStartScale
        else if Assigned(fSelectedObject) then
          fInitialScale := fSelectedObject.Scale
        else
          fInitialScale := Vector3(1, 1, 1);

        Viewport[0] := 0;
        Viewport[1] := 0;
        Viewport[2] := EditorViewportWidth;
        Viewport[3] := EditorViewportHeight;
        ModelView := fCamera.Camera.ViewMatrix;
        Proj := fRenderer.ProjectionMatrix;

        if IsCenterGizmoTag(Axis) then
        begin
          fDragStartScreenPos := Point(X, Y);
          fDragStartScreenAxis := Vector2(0, -1); // drag up = larger
          fDragStartPixelDelta := 0;
        end
        else if IsPlaneGizmoTag(Axis) then
        begin
          fDragPlaneNormal := GetGizmoPlaneNormalByTag(Axis);

          if not RayPlaneIntersectionAtScreen(X, Y, fDragStartObjectPos,
            fDragPlaneNormal, PlaneHit) then
            PlaneHit := fDragStartHandlePos;

          fScalePlaneStartVector := PlaneHit - fDragStartObjectPos;

          if (fDragAxisMask and 1) = 0 then
            fScalePlaneStartVector.X := 0;
          if (fDragAxisMask and 2) = 0 then
            fScalePlaneStartVector.Y := 0;
          if (fDragAxisMask and 4) = 0 then
            fScalePlaneStartVector.Z := 0;

          if fScalePlaneStartVector.Length <= 0.0001 then
          begin
            fScalePlaneStartVector := fDragStartHandlePos - fDragStartObjectPos;

            if (fDragAxisMask and 1) = 0 then
              fScalePlaneStartVector.X := 0;
            if (fDragAxisMask and 2) = 0 then
              fScalePlaneStartVector.Y := 0;
            if (fDragAxisMask and 4) = 0 then
              fScalePlaneStartVector.Z := 0;
          end;

          if fScalePlaneStartVector.Length <= 0.0001 then
          begin
            case Axis of
              GIZMO_TAG_XY: fScalePlaneStartVector := Vector3(-1, 1, 0);
              GIZMO_TAG_YZ: fScalePlaneStartVector := Vector3(0, 1, -1);
              GIZMO_TAG_XZ: fScalePlaneStartVector := Vector3(-1, 0, -1);
            else
              fScalePlaneStartVector := Vector3(1, 1, 0);
            end;
          end;

          fDragStartScreenPos := Point(X, Y);
          fDragStartScreenAxis := Vector2(0, 0);
          fDragStartPixelDelta := 0;
        end
        else
        begin
          { Keep the v7 single-axis scale behavior unchanged. }
          Clip := Proj * (ModelView * Vector4(fDragStartHandlePos, 1));
          if Clip.W <> 0 then
          begin
            NDC := Vector3(Clip.X / Clip.W, Clip.Y / Clip.W, Clip.Z / Clip.W);
            fDragStartScreenPos.X := Round((NDC.X * 0.5 + 0.5) * Viewport[2] + Viewport[0]);
            fDragStartScreenPos.Y := Round((1 - (NDC.Y * 0.5 + 0.5)) * Viewport[3] + Viewport[1]);
          end;

          WorldAxisEnd := fDragStartHandlePos + fDragAxisWorldDir;
          Clip := Proj * (ModelView * Vector4(WorldAxisEnd, 1));
          if Clip.W <> 0 then
          begin
            NDC := Vector3(Clip.X / Clip.W, Clip.Y / Clip.W, Clip.Z / Clip.W);
            EndX := Round((NDC.X * 0.5 + 0.5) * Viewport[2] + Viewport[0]);
            EndY := Round((1 - (NDC.Y * 0.5 + 0.5)) * Viewport[3] + Viewport[1]);
            fDragStartScreenAxis := Vector2(EndX - fDragStartScreenPos.X,
              EndY - fDragStartScreenPos.Y);
            if fDragStartScreenAxis.Length > 0.0001 then
              fDragStartScreenAxis.SetNormalized
            else
              fDragStartScreenAxis := Vector2(1, 0);
          end;

          InitDeltaX := X - fDragStartScreenPos.X;
          InitDeltaY := Y - fDragStartScreenPos.Y;
          fDragStartPixelDelta := InitDeltaX * fDragStartScreenAxis.X +
            InitDeltaY * fDragStartScreenAxis.Y;
        end;
      end;

      SetCapture(Handle);
      RequestRender;
      Exit;
    end;

    if SelectObjectAtScreenPos(X, Y) then
      begin
        RequestRender;
        Exit;
      end
    else
      DeselectObject;
  end;

  if Button = mbRight then
  begin
    fMouseDown := True;
    fLastMouseX := X;
    fLastMouseY := Y;
    fRightMouseDownPos := Point(X, Y);
    fRightMouseDragMoved := False;
    SetCapture(Handle);
  end
  else if Button = mbMiddle then
  begin
    fPanActive := True;
    fLastPanX := X;
    fLastPanY := Y;
    SetCapture(Handle);
  end;
end;

procedure TSandBoxForm.FormMouseMoveHandler(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  DeltaX, DeltaY: Integer;
  TotalDeltaX, TotalDeltaY: Integer;
  RightVec, UpVec: TVector3;
  PanFactor: Single;
  U: Single;
  NewWorldPos: TVector3;
  DeltaWorld: TVector3;
  ConstrainedDelta: TVector3;
  PlaneHit: TVector3;
  ParentInv: TMatrix4;
  LocalDelta: TVector3;
  ModelView, Proj: TMatrix4;
  Viewport: array[0..3] of GLint;
  Clip: TVector4;
  NDC: TVector3;
  CenterWorld: TVector3;
  CenterScreen: TPoint;
  CurrentAngle: Single;
  AngleDelta: Single;
  RotAngle: Single;
  MeshTranslation, MeshRotationDeg, MeshScale: TVector3;
  CurDeltaX, CurDeltaY: Integer;
  CurPixelDelta: Single;
  PixelDelta: Single;
  Factor: Single;
  NewScale: TVector3;
  CurrentScalePlaneVector: TVector3;
  StartLenSq: Single;

  function WorldToScreen(const P: TVector3): TPoint;
  begin
    Clip := Proj * (ModelView * Vector4(P, 1));
    if Clip.W = 0 then
      Exit(Point(0, 0));

    NDC := Vector3(Clip.X / Clip.W, Clip.Y / Clip.W, Clip.Z / Clip.W);
    Result.X := Round((NDC.X * 0.5 + 0.5) * Viewport[2] + Viewport[0]);
    Result.Y := Round((1 - (NDC.Y * 0.5 + 0.5)) * Viewport[3] + Viewport[1]);
  end;
begin
  if fUseImGuiEditor and Assigned(fImGui) then
  begin
    fImGui.MouseMove(X, Y);

    if fImGuiMouseCaptured then
    begin
      RequestRender;
      Exit;
    end;

    if (not fDraggingGizmo) and (not fMouseDown) and (not fPanActive) and
       (ScriptSourceEditorContainsPoint(X, Y) or ImGuiBlocksSceneMouse or
       fImGui.MouseOverUi or fImGui.WantCaptureMouse) then
    begin
      RequestRender;
      Exit;
    end;
  end;

  if (not fDraggingGizmo) and (not fMouseDown) and (not fPanActive) then
  begin
    if Assigned(fCurrentGizmo) then
      UpdateGizmoScale;
    CheckGizmoHover(X, Y);
  end;

  if fDraggingGizmo then
  begin
    if fGizmoClonePending and not (ssShift in Shift) then
    begin
      fGizmoClonePending := False;
      fGizmoCloneSource := nil;
    end
    else if fGizmoClonePending and
      ((System.Abs(X - fDragStartMousePos.X) > GIZMO_CLONE_DRAG_THRESHOLD_PX) or
       (System.Abs(Y - fDragStartMousePos.Y) > GIZMO_CLONE_DRAG_THRESHOLD_PX)) then
    begin
      CloneObjectForGizmo(fGizmoCloneSource);
      fGizmoClonePending := False;
      fGizmoCloneSource := nil;
    end;

    if fGizmoMode = gmTranslate then
    begin
      if IsSingleAxisGizmoTag(fDraggedAxis) then
      begin
        if GetDragParameter(X, Y, U) then
          NewWorldPos := fDragStartObjectPos + fDragAxisWorldDir * U - fDragOffsetWorld
        else
          NewWorldPos := fDragStartObjectPos;
      end
      else
      begin
        if RayPlaneIntersectionAtScreen(X, Y, fDragStartObjectPos,
          fDragPlaneNormal, PlaneHit) then
        begin
          DeltaWorld := PlaneHit - fDragStartPlaneHit;

          if IsCenterGizmoTag(fDraggedAxis) then
            ConstrainedDelta := DeltaWorld
          else
          begin
            ConstrainedDelta := Vector3(0, 0, 0);
            if (fDragAxisMask and 1) <> 0 then
              ConstrainedDelta.X := DeltaWorld.X;
            if (fDragAxisMask and 2) <> 0 then
              ConstrainedDelta.Y := DeltaWorld.Y;
            if (fDragAxisMask and 4) <> 0 then
              ConstrainedDelta.Z := DeltaWorld.Z;
          end;

          NewWorldPos := fDragStartObjectPos + ConstrainedDelta;
        end
        else
          NewWorldPos := fDragStartObjectPos;
      end;

      if IsMeshEditModeActive then
      begin
        fSelectedObject.UpdateWorldMatrices;
        LocalDelta := Vector3(fSelectedObject.WorldMatrix.Inverse *
          Vector4(NewWorldPos - fDragStartObjectPos, 0));
        SetMeshEditorTransformValues(fMeshDragStartTranslation + LocalDelta,
          fMeshDragStartRotationDeg, fMeshDragStartScale, False);
      end
      else if Assigned(fSelectedObject) then
      begin
        if Assigned(fSelectedObject.Parent) then
          ParentInv := fSelectedObject.Parent.WorldMatrix.Inverse
        else
          ParentInv := TMatrix4.Identity;

        fSelectedObject.Position := Vector3(ParentInv * Vector4(NewWorldPos, 1));
        fSelectedObject.NotifyChange;
        if Assigned(fSceneManager) then
          fSceneManager.Update;
      end;
    end
    else if fGizmoMode = gmRotate then
    begin
      ModelView := fCamera.Camera.ViewMatrix;
      Proj := fRenderer.ProjectionMatrix;
      Viewport[0] := 0;
      Viewport[1] := 0;
      Viewport[2] := EditorViewportWidth;
      Viewport[3] := EditorViewportHeight;

      CenterWorld := GetGizmoTargetWorldPosition;
      CenterScreen := WorldToScreen(CenterWorld);
      CurrentAngle := System.Math.ArcTan2(Y - CenterScreen.Y, X - CenterScreen.X);

      if not fRotateStartAngleSet then
      begin
        fRotateStartAngle := CurrentAngle;
        fRotateStartAngleSet := True;
        RequestRender;
        Exit;
      end;

      AngleDelta := CurrentAngle - fRotateStartAngle;
      if AngleDelta > Pi then
        AngleDelta := AngleDelta - 2 * Pi;
      if AngleDelta < -Pi then
        AngleDelta := AngleDelta + 2 * Pi;

      RotAngle := AngleDelta;
      if fDraggedAxis = 1 then
        RotAngle := -RotAngle;

      if Abs(RotAngle) > 0.001 then
      begin
        if IsMeshEditModeActive then
        begin
          if GetMeshEditorTransformValues(MeshTranslation, MeshRotationDeg, MeshScale) then
          begin
            case fDraggedAxis of
              0: MeshRotationDeg.X := MeshRotationDeg.X + RotAngle * 180.0 / Pi;
              1: MeshRotationDeg.Y := MeshRotationDeg.Y + RotAngle * 180.0 / Pi;
              2: MeshRotationDeg.Z := MeshRotationDeg.Z + RotAngle * 180.0 / Pi;
            end;
            SetMeshEditorTransformValues(MeshTranslation, MeshRotationDeg, MeshScale, False);
          end;
        end
        else if Assigned(fSelectedObject) then
        begin
          case fDraggedAxis of
            0: fSelectedObject.Rotation := fSelectedObject.Rotation + Vector3(RotAngle, 0, 0);
            1: fSelectedObject.Rotation := fSelectedObject.Rotation + Vector3(0, RotAngle, 0);
            2: fSelectedObject.Rotation := fSelectedObject.Rotation + Vector3(0, 0, RotAngle);
          end;
          fSelectedObject.NotifyChange;
          if Assigned(fSceneManager) then
            fSceneManager.Update;
        end;

        fRotateStartAngle := CurrentAngle;
      end;
    end
    else if fGizmoMode = gmScale then
    begin
      CurDeltaX := X - fDragStartScreenPos.X;
      CurDeltaY := Y - fDragStartScreenPos.Y;
      CurPixelDelta := CurDeltaX * fDragStartScreenAxis.X + CurDeltaY * fDragStartScreenAxis.Y;
      PixelDelta := CurPixelDelta - fDragStartPixelDelta;

      if IsSingleAxisGizmoTag(fDraggedAxis) then
      begin
        { Keep v7 single-axis signs: X/Z use the projected-axis sign; Y is the
          only one that needs the opposite sign. }
        if fDraggedAxis = GIZMO_TAG_Y then
          Factor := 1.0 + PixelDelta * 0.01
        else
          Factor := 1.0 - PixelDelta * 0.01;
      end
      else if IsPlaneGizmoTag(fDraggedAxis) then
      begin
        { World-space plane scale: compare the current grabbed vector against
          the original grabbed vector. Moving away from the gizmo center grows;
          moving toward the center shrinks. No per-plane sign special cases. }
        fDragPlaneNormal := GetGizmoPlaneNormalByTag(fDraggedAxis);

        if RayPlaneIntersectionAtScreen(X, Y, fDragStartObjectPos,
          fDragPlaneNormal, PlaneHit) then
          CurrentScalePlaneVector := PlaneHit - fDragStartObjectPos
        else
          CurrentScalePlaneVector := fScalePlaneStartVector;

        if (fDragAxisMask and 1) = 0 then
          CurrentScalePlaneVector.X := 0;
        if (fDragAxisMask and 2) = 0 then
          CurrentScalePlaneVector.Y := 0;
        if (fDragAxisMask and 4) = 0 then
          CurrentScalePlaneVector.Z := 0;

        StartLenSq := fScalePlaneStartVector.Dot(fScalePlaneStartVector);
        if StartLenSq > 0.000001 then
          Factor := CurrentScalePlaneVector.Dot(fScalePlaneStartVector) / StartLenSq
        else
          Factor := 1.0;
      end
      else
      begin
        { Center uniform scale keeps the v8 behavior: drag up = larger. }
        Factor := 1.0 + PixelDelta * 0.01;
      end;

      if Factor < 0.01 then
        Factor := 0.01;

      NewScale := fInitialScale;
      if (fDragAxisMask and 1) <> 0 then
        NewScale.X := fInitialScale.X * Factor;
      if (fDragAxisMask and 2) <> 0 then
        NewScale.Y := fInitialScale.Y * Factor;
      if (fDragAxisMask and 4) <> 0 then
        NewScale.Z := fInitialScale.Z * Factor;

      if IsMeshEditModeActive then
        SetMeshEditorTransformValues(fMeshDragStartTranslation,
          fMeshDragStartRotationDeg, NewScale, False)
      else if Assigned(fSelectedObject) then
      begin
        fSelectedObject.Scale := NewScale;
        fSelectedObject.NotifyChange;
        if Assigned(fSceneManager) then
          fSceneManager.Update;
      end;
    end;

    RefreshGizmo;
    RequestRender;
    Exit;
  end;

  if fMouseDown then
  begin
    TotalDeltaX := System.Abs(X - fRightMouseDownPos.X);
    TotalDeltaY := System.Abs(Y - fRightMouseDownPos.Y);

    if (not fRightMouseDragMoved) and
       ((TotalDeltaX > RIGHT_CLICK_DRAG_THRESHOLD_PX) or
       (TotalDeltaY > RIGHT_CLICK_DRAG_THRESHOLD_PX)) then
      fRightMouseDragMoved := True;

    if not fRightMouseDragMoved then
    begin
      fLastMouseX := X;
      fLastMouseY := Y;
      Exit;
    end;

    DeltaX := X - fLastMouseX;
    DeltaY := Y - fLastMouseY;

    fTargetAzimuth := fTargetAzimuth + DeltaX * fRotateSpeed;
    fTargetPolar := fTargetPolar - DeltaY * fRotateSpeed;

    if fTargetPolar < 0.01 then
      fTargetPolar := 0.01;
    if fTargetPolar > Pi - 0.01 then
      fTargetPolar := Pi - 0.01;

    fLastMouseX := X;
    fLastMouseY := Y;
  end
  else if fPanActive and Assigned(fCamera) and Assigned(fCamera.Camera) then
  begin
    DeltaX := X - fLastPanX;
    DeltaY := Y - fLastPanY;

    RightVec := -fCamera.Camera.Left;
    UpVec := fCamera.Camera.Up;
    PanFactor := fCurrentRadius * fPanSpeed;

    fOrbitTarget := fOrbitTarget - ((RightVec * Single(DeltaX)) + (UpVec * Single(DeltaY))) * PanFactor;

    fLastPanX := X;
    fLastPanY := Y;
  end;
end;

procedure TSandBoxForm.FormMouseUpHandler(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  TotalDeltaX, TotalDeltaY: Integer;
begin
  if fUseImGuiEditor and Assigned(fImGui) then
  begin
    fImGui.MouseMove(X, Y);
    fImGui.MouseUp(Button);

    if fImGuiMouseCaptured then
    begin
      fImGuiMouseCaptured := False;
      ReleaseCapture;
      RequestRender;
      Exit;
    end;
  end;

  if fDraggingGizmo then
  begin
    fDraggingGizmo := False;
    fDraggedAxis := -1;
    fDragAxisMask := 0;
    fHoveredAxis := -1;
    fGizmoClonePending := False;
    fGizmoCloneSource := nil;
    fRotateStartAngleSet := False;
    fDragStartPixelDelta := 0;
    fScalePlaneStartVector := Vector3(0, 0, 0);
    RefreshGizmo;
    CheckGizmoHover(X, Y);
    ReleaseCapture;
    RequestRender;
    Exit;
  end;

  if Button = mbRight then
  begin
    fMouseDown := False;
    ReleaseCapture;

    if not fRightMouseDragMoved then
    begin
      TotalDeltaX := System.Abs(X - fRightMouseDownPos.X);
      TotalDeltaY := System.Abs(Y - fRightMouseDownPos.Y);
      fRightMouseDragMoved := (TotalDeltaX > RIGHT_CLICK_DRAG_THRESHOLD_PX) or
        (TotalDeltaY > RIGHT_CLICK_DRAG_THRESHOLD_PX);
    end;

    if not fRightMouseDragMoved then
      if SelectObjectAtScreenPos(X, Y) then
        OpenViewportObjectContextPopup(X, Y, fSelectedObject);

    fRightMouseDragMoved := False;
  end
  else if Button = mbMiddle then
  begin
    fPanActive := False;
    ReleaseCapture;
  end;
end;

procedure TSandBoxForm.EditorShortcutKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if fUseImGuiEditor and Assigned(fImGui) then
  begin
    fImGui.KeyDown(Key);
    if ImGuiWantsKeyboardCapture then
    begin
      Key := 0;
      Exit;
    end;
  end;

  case Key of
    VK_F9:
      begin
        if fPhysicsRunning then
          PausePhysicsSimulation
        else
          StartPhysicsSimulation;
        Key := 0;
      end;
    VK_F10:
      begin
        StopPhysicsSimulation;
        Key := 0;
      end;
    VK_F11:
      begin
        ResetPhysicsSimulation;
        Key := 0;
      end;
    VK_DELETE:
      DeleteObjectFromImGui(fSelectedObject);
    Ord('F'):
      if Assigned(fSelectedObject) then
      begin
        FocusCameraOnSceneObject(fSelectedObject);
        Key := 0;
      end;
  end;
end;

procedure TSandBoxForm.EditorShortcutKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if fUseImGuiEditor and Assigned(fImGui) then
  begin
    fImGui.KeyUp(Key);
    if ImGuiWantsKeyboardCapture then
      Key := 0;
  end;
end;

procedure TSandBoxForm.EditorShortcutKeyPress(Sender: TObject; var Key: Char);
begin
  if fUseImGuiEditor and Assigned(fImGui) then
  begin
    fImGui.KeyPress(Key);
    if ImGuiWantsKeyboardCapture then
      Key := #0;
  end;
end;

end.
