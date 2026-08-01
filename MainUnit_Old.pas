unit MainUnit;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, dglOpenGL, Vcl.ExtCtrls, Vcl.StdCtrls, System.Math,
  Renderer.Mesh, Renderer.Shader, Renderer.Light, Renderer.SkyDome,
  Engine.Types, Managers.Material,
  Renderer.Camera, Engine.Generators, Managers.Scene, Renderer.Renderer, Utility.Functions,
  GraphicEx, Neslib.FastMath, Editor.NewComponent, Engine.Time,
  Engine.Physics, Engine.Scripting, Renderer.Mesh.Factory, Engine.Paths,
  Vcl.Samples.Spin, System.Generics.Collections, Vcl.Buttons, Vcl.ComCtrls, Vcl.Menus,
  System.ImageList, Vcl.ImgList, Vcl.Grids, Winapi.ShellAPI, Vcl.CategoryButtons,
  Vcl.ButtonGroup, System.IOUtils, Vcl.ExtDlgs, Vcl.Imaging.pngimage,
  Vcl.Imaging.jpeg;

type
  TMainForm = class(TForm)
    Timer1: TTimer;
    pnlRenderingSurface: TPanel;
    PopupMenu1: TPopupMenu;
    puNew: TMenuItem;
    N1: TMenuItem;
    puCut: TMenuItem;
    puCopy: TMenuItem;
    puPaste: TMenuItem;
    N2: TMenuItem;
    puRename: TMenuItem;
    puNewCube: TMenuItem;
    puNewSphere: TMenuItem;
    puNewCylinder: TMenuItem;
    puNewCapsule: TMenuItem;
    puNewTorus: TMenuItem;
    puNewCone: TMenuItem;
    puNewPrism: TMenuItem;
    puDelete: TMenuItem;
    N3: TMenuItem;
    puNewFrustum: TMenuItem;
    puNewEmptyObject: TMenuItem;
    puNewArrow: TMenuItem;
    puNewPlane: TMenuItem;
    N4: TMenuItem;
    puCombineGeometry: TMenuItem;
    N5: TMenuItem;
    puNewSphereEllipsoid: TMenuItem;
    N6: TMenuItem;
    puNewCylinderEllipsoid: TMenuItem;
    puNewCubeEllipsoid: TMenuItem;
    puNewStarEllipsoid: TMenuItem;
    Ellipsoid1: TMenuItem;
    puNewPillEllipsoid: TMenuItem;
    puNewIcosphere: TMenuItem;
    puNewGeodesicDome: TMenuItem;
    ImageList1: TImageList;
    PlusMenu: TPopupMenu;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    miPlane: TMenuItem;
    MenuItem5: TMenuItem;
    MenuItem6: TMenuItem;
    MenuItem7: TMenuItem;
    MenuItem8: TMenuItem;
    MenuItem9: TMenuItem;
    MenuItem10: TMenuItem;
    MenuItem11: TMenuItem;
    MenuItem12: TMenuItem;
    MenuItem13: TMenuItem;
    MenuItem14: TMenuItem;
    MenuItem15: TMenuItem;
    MenuItem16: TMenuItem;
    MenuItem17: TMenuItem;
    MenuItem18: TMenuItem;
    MenuItem19: TMenuItem;
    MenuItem20: TMenuItem;
    MenuItem21: TMenuItem;
    MenuItem22: TMenuItem;
    ColorDialog1: TColorDialog;
    SaveSceneDialog: TSaveDialog;
    OpenSceneDialog: TOpenDialog;
    Panel10: TPanel;
    mLog: TMemo;
    pnlObjects: TPanel;
    pnlEditNodes: TPanel;
    spbAddObject: TSpeedButton;
    scTree: TTreeView;
    Splitter1: TSplitter;
    Splitter2: TSplitter;
    Splitter3: TSplitter;
    CentralEditor: TCategoryPanelGroup;
    cpPosition: TCategoryPanel;
    lblPositionX: TLabel;
    ePositionX: TEdit;
    ePositionY: TEdit;
    lblPositionY: TLabel;
    ePositionZ: TEdit;
    lblPositionZ: TLabel;
    cpRotation: TCategoryPanel;
    lblRotationX: TLabel;
    lblRotationY: TLabel;
    lblRotationZ: TLabel;
    eRotationX: TEdit;
    eRotationY: TEdit;
    eRotationZ: TEdit;
    cpScale: TCategoryPanel;
    lblScaleX: TLabel;
    lblScaleY: TLabel;
    lblScaleZ: TLabel;
    eScaleX: TEdit;
    eScaleY: TEdit;
    eScaleZ: TEdit;
    cpMeshes: TCategoryPanel;
    lbMeshes: TListBox;
    ilButtons: TImageList;
    cpPhysics: TCategoryPanel;
    pnl1BodyType: TPanel;
    lblBodyType: TLabel;
    cbBodyType: TComboBox;
    pnl2ColliderKind: TPanel;
    lblColliderKind: TLabel;
    cbColliderKind: TComboBox;
    pnl3BooleanProperties: TPanel;
    chbEnabled: TCheckBox;
    chbCollisionResponse: TCheckBox;
    chbUseGravity: TCheckBox;
    pnl4Mass: TPanel;
    lblMass: TLabel;
    lblInverseMass: TLabel;
    lblInverseMassInfo: TLabel;
    eMass: TEdit;
    pnl5PhysicMaterial: TPanel;
    lblPhysicMaterial: TLabel;
    lblRestitution: TLabel;
    lblLinearDamping: TLabel;
    lblGravityScale: TLabel;
    lblAngularDamping: TLabel;
    pnlDivider_1: TPanel;
    eRestitution: TEdit;
    eLinearDamping: TEdit;
    eGravityScale: TEdit;
    pnlVelocity: TPanel;
    lblVelocity: TLabel;
    lblVelocityX: TLabel;
    lblVelocityY: TLabel;
    lblVelocityZ: TLabel;
    eVelocityX: TEdit;
    eVelocityY: TEdit;
    eVelocityZ: TEdit;
    pnlAngularVelocity: TPanel;
    lblAngularVelocity: TLabel;
    lnlAngularVelocityX: TLabel;
    lnlAngularVelocityY: TLabel;
    lnlAngularVelocityZ: TLabel;
    eAngularVelocityX: TEdit;
    eAngularVelocityY: TEdit;
    eAngularVelocityZ: TEdit;
    eAngularDamping: TEdit;
    pnl6Detection: TPanel;
    lblDetection: TLabel;
    lblRadius: TLabel;
    lblHalfHeight: TLabel;
    lblStepHeight: TLabel;
    Panel1: TPanel;
    eRadius: TEdit;
    eHalfHeight: TEdit;
    pnlAABBHalfExtents: TPanel;
    lblAABBHalfExtents: TLabel;
    lblAABBHalfExtentsX: TLabel;
    lblAABBHalfExtentsY: TLabel;
    lblAABBHalfExtentsZ: TLabel;
    eAABBHalfExtentsX: TEdit;
    eAABBHalfExtentsY: TEdit;
    eAABBHalfExtentsZ: TEdit;
    eStepHeight: TEdit;
    pnl7Confirm: TPanel;
    btnApply: TButton;
    btnCancel: TButton;
    pumAddMesh: TPopupMenu;
    puNewEmpty: TMenuItem;
    MenuItem1: TMenuItem;
    MenuItem4: TMenuItem;
    MenuItem23: TMenuItem;
    MenuItem24: TMenuItem;
    MenuItem25: TMenuItem;
    MenuItem26: TMenuItem;
    MenuItem27: TMenuItem;
    MenuItem28: TMenuItem;
    MenuItem29: TMenuItem;
    puNewPyramid: TMenuItem;
    MenuItem30: TMenuItem;
    MenuItem31: TMenuItem;
    MenuItem32: TMenuItem;
    subMenuEllipsoid: TMenuItem;
    MenuItem33: TMenuItem;
    MenuItem34: TMenuItem;
    MenuItem35: TMenuItem;
    MenuItem36: TMenuItem;
    MenuItem37: TMenuItem;
    OpenMaterialsDialog: TOpenDialog;
    MainControlBar: TControlBar;
    pnlGlobalScene: TPanel;
    spbNewScene: TSpeedButton;
    spbOpenScene: TSpeedButton;
    spbSaveScene: TSpeedButton;
    DebugControlBar: TControlBar;
    chbDebugWireframe: TCheckBox;
    chbDebugPhysics: TCheckBox;
    EditModeControlBar: TControlBar;
    pnlEditMode: TPanel;
    spbMove: TSpeedButton;
    spbRotate: TSpeedButton;
    spbScale: TSpeedButton;
    sbScene: TStatusBar;
    spbCutObject: TSpeedButton;
    spbDeleteObject: TSpeedButton;
    spbPasteObject: TSpeedButton;
    spbCopyObject: TSpeedButton;
    visualSplit2: TPanel;
    visualSplit1: TPanel;
    ilEditNodes: TImageList;
    spbUpObject: TSpeedButton;
    spbDownObject: TSpeedButton;
    spbSaveAsScene: TSpeedButton;
    visualSplit3: TPanel;
    visualSplit4: TPanel;
    MainMenu: TMainMenu;
    mmFile: TMenuItem;
    mmNewScene: TMenuItem;
    mmOpenScene: TMenuItem;
    N7: TMenuItem;
    mmSaveScene: TMenuItem;
    mmSaveSceneAs: TMenuItem;
    N8: TMenuItem;
    mmCloseScene: TMenuItem;
    N9: TMenuItem;
    mmExit: TMenuItem;
    mmEdit: TMenuItem;
    mmCut: TMenuItem;
    mmCopy: TMenuItem;
    mmPaste: TMenuItem;
    mmDelete: TMenuItem;
    N10: TMenuItem;
    mmMoveUp: TMenuItem;
    mmMoveDown: TMenuItem;
    N11: TMenuItem;
    mmEditPosition: TMenuItem;
    mmEditRotation: TMenuItem;
    mmEditScale: TMenuItem;
    mmView: TMenuItem;
    mmDebug: TMenuItem;
    mmDebugWireframe: TMenuItem;
    mmDebugPhysics: TMenuItem;
    mmTools: TMenuItem;
    mmMaterialEditor: TMenuItem;
    mmScriptEditor: TMenuItem;
    mmRun: TMenuItem;
    mmPhysicsSimulation: TMenuItem;
    mmOptions: TMenuItem;
    mmBackgroundColor: TMenuItem;
    mmNewSceneObject: TMenuItem;
    mmEmptyObject: TMenuItem;
    N13: TMenuItem;
    mmNewPlane: TMenuItem;
    mmNewCube: TMenuItem;
    mmNewSphere: TMenuItem;
    mmNewCylinder: TMenuItem;
    mmNewCapsule: TMenuItem;
    mmNewTorus: TMenuItem;
    mmNewCone: TMenuItem;
    mmNewPrism: TMenuItem;
    mmNewFrustum: TMenuItem;
    mmNewArrow: TMenuItem;
    mmNewIcosphere: TMenuItem;
    mmNewGeodesicDome: TMenuItem;
    mmNewEllipsoid: TMenuItem;
    mmNewSphereEllipsoid: TMenuItem;
    mmNewCylinderEllipsoid: TMenuItem;
    mmNewCubeEllipsoid: TMenuItem;
    mmNewStarEllipsoid: TMenuItem;
    mmNewPillEllipsoid: TMenuItem;
    N14: TMenuItem;
    N12: TMenuItem;
    mmImportMaterials: TMenuItem;
    pnlMeshlistControl: TPanel;
    spbUpMesh: TSpeedButton;
    spbLoadMesh: TSpeedButton;
    spbDownMesh: TSpeedButton;
    spbDeleteMesh: TSpeedButton;
    spbAddMesh: TSpeedButton;
    newMeshEditor: TCategoryPanelGroup;
    cpCapsuleMesh: TCategoryPanel;
    pnlCapsuleMesh: TPanel;
    Label15: TLabel;
    Label16: TLabel;
    Label17: TLabel;
    Label18: TLabel;
    eCapsuleMeshStacks: TEdit;
    eCapsuleMeshHeight: TEdit;
    eCapsuleMeshSlices: TEdit;
    eCapsuleMeshRadius: TEdit;
    cpCylinderMesh: TCategoryPanel;
    pnlCylinderMesh: TPanel;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    Label14: TLabel;
    Label151: TLabel;
    Label150: TLabel;
    eCylinderMeshStacks: TEdit;
    eCylinderMeshHeight: TEdit;
    eCylinderMeshSlices: TEdit;
    eCylinderMeshRadius: TEdit;
    cbCylinderMeshTopCap: TComboBox;
    cbCylinderMeshBottomCap: TComboBox;
    cpSphereMesh: TCategoryPanel;
    pnlSphereMesh: TPanel;
    Label30: TLabel;
    Label32: TLabel;
    Label33: TLabel;
    eSphereMeshStacks: TEdit;
    eSphereMeshSlices: TEdit;
    eSphereMeshRadius: TEdit;
    cpCubeMesh: TCategoryPanel;
    pnlCubeMesh: TPanel;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    eCubeMeshHeightStacks: TEdit;
    eCubeMeshHeight: TEdit;
    eCubeMeshStacks: TEdit;
    eCubeMeshWidth: TEdit;
    eCubeMeshDepthStacks: TEdit;
    eCubeMeshDepth: TEdit;
    cpPlaneMesh: TCategoryPanel;
    pnlPlaneMesh: TPanel;
    Label10: TLabel;
    Label11: TLabel;
    Label12: TLabel;
    Label13: TLabel;
    ePlaneDepthSegments: TEdit;
    ePlaneDepth: TEdit;
    ePlaneWidthSegments: TEdit;
    ePlaneWidth: TEdit;
    cpMeshTransforms: TCategoryPanel;
    pnlScaleMesh: TPanel;
    lblScale: TLabel;
    lblMeshScaleX: TLabel;
    lblMeshScaleY: TLabel;
    lblMeshScaleZ: TLabel;
    eMeshScaleX: TEdit;
    eMeshScaleY: TEdit;
    eMeshScaleZ: TEdit;
    pnlRotationMesh: TPanel;
    lblRotation: TLabel;
    lblMeshRotationX: TLabel;
    lblMeshRotationY: TLabel;
    lblMeshRotationZ: TLabel;
    eMeshRotationX: TEdit;
    eMeshRotationY: TEdit;
    eMeshRotationZ: TEdit;
    pnlPositionMesh: TPanel;
    lblPosition: TLabel;
    lblMeshPositionX: TLabel;
    lblMeshPositionY: TLabel;
    lblMeshPositionZ: TLabel;
    eMeshPositionX: TEdit;
    eMeshPositionY: TEdit;
    eMeshPositionZ: TEdit;
    cpMeshBase: TCategoryPanel;
    pnlMeshBase: TPanel;
    lblMehName: TLabel;
    lblOrigin: TLabel;
    lblMaterialLibrary: TLabel;
    lblLibraryName: TLabel;
    lblV: TLabel;
    lblU: TLabel;
    eMeshName: TEdit;
    cbOrigin: TComboBox;
    cbMaterialLibrary: TComboBox;
    cbLibraryName: TComboBox;
    pnlDivider_2: TPanel;
    btnApplyUV: TButton;
    eV: TEdit;
    eU: TEdit;
    cpTorusMesh: TCategoryPanel;
    pnlTorusMesh: TPanel;
    Label19: TLabel;
    Label20: TLabel;
    Label21: TLabel;
    Label22: TLabel;
    eTorusMeshMinorSegments: TEdit;
    eTorusMeshMinor: TEdit;
    eTorusMeshMajorSegments: TEdit;
    eTorusMeshMajor: TEdit;
    cpConeMesh: TCategoryPanel;
    pnlConeMesh: TPanel;
    Label23: TLabel;
    Label24: TLabel;
    Label25: TLabel;
    Label26: TLabel;
    Label28: TLabel;
    eConeMeshStacks: TEdit;
    eConeMeshHeight: TEdit;
    eConeMeshSides: TEdit;
    eConeMeshRadius: TEdit;
    cbConeMeshBottomCap: TComboBox;
    cpPrismMesh: TCategoryPanel;
    pnlPrismMesh: TPanel;
    Label27: TLabel;
    Label29: TLabel;
    Label31: TLabel;
    Label34: TLabel;
    ePrismMeshStacks: TEdit;
    ePrismMeshHeight: TEdit;
    ePrismMeshSides: TEdit;
    ePrismMeshRadius: TEdit;
    cpFrustumMesh: TCategoryPanel;
    pnlFrustumMesh: TPanel;
    Label35: TLabel;
    Label36: TLabel;
    Label37: TLabel;
    Label38: TLabel;
    Label39: TLabel;
    Label40: TLabel;
    eFrustumMeshStacks: TEdit;
    eFrustumMeshTopRadius: TEdit;
    eFrustumMeshSlices: TEdit;
    eFrustumMeshBottomRadius: TEdit;
    cbFrustumMeshTopCap: TComboBox;
    cbFrustumMeshBottomCap: TComboBox;
    eFrustumMeshHeight: TEdit;
    Label41: TLabel;
    cpIcosphereMesh: TCategoryPanel;
    pnlIcosphereMesh: TPanel;
    Label44: TLabel;
    Label45: TLabel;
    eIcosphereMeshSubdivisions: TEdit;
    eIcosphereMeshRadius: TEdit;
    cpGeodesicDomeMesh: TCategoryPanel;
    pnlGeodesicDomeMesh: TPanel;
    Label42: TLabel;
    Label43: TLabel;
    eGeodesicDomeMeshSubdivisions: TEdit;
    eGeodesicDomeMeshRadius: TEdit;
    cpArrowMesh: TCategoryPanel;
    pnlArrowMesh: TPanel;
    Label46: TLabel;
    Label47: TLabel;
    Label48: TLabel;
    Label49: TLabel;
    Label50: TLabel;
    Label51: TLabel;
    eArrowMeshTipRadius: TEdit;
    eArrowMeshTipLength: TEdit;
    eArrowMeshShaftRadius: TEdit;
    eArrowMeshShaftLength: TEdit;
    eArrowMeshStacks: TEdit;
    eArrowMeshSlices: TEdit;
    cpSuperEllipsoidMesh: TCategoryPanel;
    pnlSuperEllipsoidMesh: TPanel;
    Label52: TLabel;
    Label53: TLabel;
    Label54: TLabel;
    Label55: TLabel;
    Label57: TLabel;
    eSuperEllipsoidMeshStacks: TEdit;
    eSuperEllipsoidMeshRadius: TEdit;
    eSuperEllipsoidMeshHCurve: TEdit;
    eSuperEllipsoidMeshVCurve: TEdit;
    eSuperEllipsoidMeshSlices: TEdit;
    cpFileMesh: TCategoryPanel;
    pnlFileMesh: TPanel;
    Label60: TLabel;
    eFileMeshFileName: TEdit;
    SpeedButton1: TSpeedButton;
    StartPhysicsControlBar: TControlBar;
    spbPlay: TSpeedButton;
    il_StartPhysics: TImageList;
    mmGUIEditor: TMenuItem;
    N15: TMenuItem;
    puNewTerrain: TMenuItem;
    N16: TMenuItem;
    miTerrain: TMenuItem;
    N17: TMenuItem;
    mmNewTerrain: TMenuItem;
    cpHeightFieldMesh: TCategoryPanel;
    pnlHeightFieldMesh: TPanel;
    Label56: TLabel;
    Label58: TLabel;
    Label59: TLabel;
    Label61: TLabel;
    Label62: TLabel;
    eHeightFieldMeshMapDepth: TEdit;
    eHeightFieldMeshHeightScale: TEdit;
    eHeightFieldMeshMapWidth: TEdit;
    eHeightFieldMeshWidth: TEdit;
    eHeightFieldMeshDepth: TEdit;
    Label63: TLabel;
    eHeightFieldMeshSourceFile: TEdit;
    sbHeightFieldMeshSourceFile: TSpeedButton;
    eHeightFieldMeshUVScale: TEdit;
    Label64: TLabel;
    mmParticleEditor: TMenuItem;
    SpeedButton2: TSpeedButton;
    SpeedButton3: TSpeedButton;
    Panel2: TPanel;
    chbHeightFieldMeshEnableLOD: TCheckBox;
    eHeightFieldMeshTileSize: TEdit;
    Label241: TLabel;
    eHeightFieldMeshLODCount: TEdit;
    Label240: TLabel;
    eHeightFieldMeshLODDistance: TEdit;
    Label239: TLabel;
    chbShowBoundingBox: TCheckBox;
    miWaterPlane: TMenuItem;
    puNewWaterPlane: TMenuItem;
    chbEnableFog: TCheckBox;
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure mmExitClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure scTreeDeletion(Sender: TObject; Node: TTreeNode);
    procedure pnlRenderingSurfaceMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure pnlRenderingSurfaceMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure pnlRenderingSurfaceMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure EditorShortcutKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FormMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure scTreeDblClick(Sender: TObject);
    procedure scTreeClick(Sender: TObject);
    procedure puRenameClick(Sender: TObject);
    procedure puCutClick(Sender: TObject);
    procedure puCopyClick(Sender: TObject);
    procedure puPasteClick(Sender: TObject);
    procedure PopupMenu1Popup(Sender: TObject);
    procedure scTreeDragOver(Sender, Source: TObject; X, Y: Integer;
      State: TDragState; var Accept: Boolean);
    procedure scTreeDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure puDeleteClick(Sender: TObject);
    procedure puNewCubeClick(Sender: TObject);
    procedure puNewSphereClick(Sender: TObject);
    procedure puNewCylinderClick(Sender: TObject);
    procedure puNewCapsuleClick(Sender: TObject);
    procedure puNewTorusClick(Sender: TObject);
    procedure puNewConeClick(Sender: TObject);
    procedure puNewPrismClick(Sender: TObject);
    procedure puNewEmptyObjectClick(Sender: TObject);
    procedure scTreeEdited(Sender: TObject; Node: TTreeNode; var S: string);
    procedure puNewArrowClick(Sender: TObject);
    procedure pnlRenderingSurfaceMouseLeave(Sender: TObject);
    procedure puNewPlaneClick(Sender: TObject);
    procedure puCombineGeometryClick(Sender: TObject);
    procedure chbDebugWireframeClick(Sender: TObject);
    procedure chbDebugPhysicsClick(Sender: TObject);
    procedure chbShowBoundingBoxClick(Sender: TObject);
    procedure puNewSphereEllipsoidClick(Sender: TObject);
    procedure puNewCylinderEllipsoidClick(Sender: TObject);
    procedure puNewCubeEllipsoidClick(Sender: TObject);
    procedure puNewStarEllipsoidClick(Sender: TObject);
    procedure puNewPillEllipsoidClick(Sender: TObject);
    procedure puNewIcosphereClick(Sender: TObject);
    procedure puNewGeodesicDomeClick(Sender: TObject);
    procedure puNewFrustumClick(Sender: TObject);
    procedure TransformEditChange(Sender: TObject);
    procedure lbMeshesClick(Sender: TObject);
    procedure lbMeshesDblClick(Sender: TObject);
    procedure spbAddMeshClick(Sender: TObject);
    procedure spbDeleteMeshClick(Sender: TObject);
    procedure spbUpMeshClick(Sender: TObject);
    procedure spbDownMeshClick(Sender: TObject);
    procedure spbLoadMeshClick(Sender: TObject);
    procedure MeshNewEmptyClick(Sender: TObject);
    procedure MeshNewPlaneClick(Sender: TObject);
    procedure MeshNewCubeClick(Sender: TObject);
    procedure MeshNewSphereClick(Sender: TObject);
    procedure MeshNewCylinderClick(Sender: TObject);
    procedure MeshNewCapsuleClick(Sender: TObject);
    procedure MeshNewTorusClick(Sender: TObject);
    procedure MeshNewConeClick(Sender: TObject);
    procedure MeshNewPrismClick(Sender: TObject);
    procedure MeshNewPyramidClick(Sender: TObject);
    procedure MeshNewArrowClick(Sender: TObject);
    procedure MeshNewSphereEllipsoidClick(Sender: TObject);
    procedure MeshNewCylinderEllipsoidClick(Sender: TObject);
    procedure MeshNewCubeEllipsoidClick(Sender: TObject);
    procedure MeshNewStarEllipsoidClick(Sender: TObject);
    procedure MeshNewPillEllipsoidClick(Sender: TObject);
    procedure MeshNewIcosphereClick(Sender: TObject);
    procedure MeshNewGeodesicDomeClick(Sender: TObject);
    procedure btnApplyClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure CentralEditorMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure spbNewSceneClick(Sender: TObject);
    procedure spbSaveSceneClick(Sender: TObject);
    procedure spbSaveAsSceneClick(Sender: TObject);
    procedure spbOpenSceneClick(Sender: TObject);
    procedure spbMoveClick(Sender: TObject);
    procedure spbRotateClick(Sender: TObject);
    procedure spbScaleClick(Sender: TObject);
    procedure spbAddObjectClick(Sender: TObject);
    procedure spbUpObjectClick(Sender: TObject);
    procedure spbDownObjectClick(Sender: TObject);
    procedure pnlRenderingSurfaceResize(Sender: TObject);
    procedure mmBackgroundColorClick(Sender: TObject);
    procedure mmMaterialEditorClick(Sender: TObject);
    procedure mmDebugWireframeClick(Sender: TObject);
    procedure mmDebugPhysicsClick(Sender: TObject);
    procedure mmImportMaterialsClick(Sender: TObject);
    procedure cpPhysicsMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure mmPhysicsSimulationClick(Sender: TObject);
    procedure mmGUIEditorClick(Sender: TObject);
    procedure mmParticleEditorClick(Sender: TObject);
    procedure puNewTerrainClick(Sender: TObject);
    procedure puNewWaterClick(Sender: TObject);
    procedure puNewWaterPlaneClick(Sender: TObject);
    procedure chbEnableFogClick(Sender: TObject);
  private
    // Helper methods
    procedure LoadDefaultTextures;
    procedure LoadCustomTextures;
    function EnsureDefaultMaterialLibrary: TMaterialLibrary;
    procedure EnsureGizmoMaterial;
    function DefaultRenderableMaterialName: string;
    function ShaderForMaterialType(AMaterialType: TMaterialType): TShader;
    procedure AssignShaderToMaterial(AMaterial: TMaterial);
    procedure AssignShadersToMaterialLibrary(ALib: TMaterialLibrary);
    function CloneMaterialForMainShader(AMaterial: TMaterial): TMaterial;
    procedure ClearUserMaterialsFromLibrary(ALib: TMaterialLibrary);
    function CopyUserMaterialsFromLibrary(ASource, ADest: TMaterialLibrary): Integer;
    procedure ReplaceDefaultUserMaterialsFromLibrary(ASource: TMaterialLibrary);
    procedure ReplaceUserMaterialLibraries(ASource: TMaterialLibraries);
    function SceneMaterialPrefix(const ASceneFileName: string): string;
    function SceneMaterialFileName(const ASceneFileName: string): string;
    function SafeMaterialFileNamePart(const Value: string): string;
    procedure SaveSceneMaterialsToFiles(const ASceneFileName: string);
    procedure LoadSceneMaterialsForFile(const ASceneFileName: string);
    procedure BindScriptManager;
    procedure ActivateMainRenderContext;

    procedure UpdateScene(deltaTime: Double);

    procedure OnUpdateShader(Shader: TShader);
    procedure ApplyFrameUniformsToShader(Shader: TShader);
    procedure OnUpdateGizmoShader(Shader: TShader);
    procedure GizmoMeshRenderHandler(Mesh: TMesh; Shader: TShader);
    procedure SyncSkyDomeToMainLight;

    procedure MeshRenderHandler(Mesh: TMesh; Shader: TShader);

    procedure UpdateOrbitCamera;
    procedure ApplyToShader(Shader: TShader; Index: Integer);
    procedure ApplyLightToShader(Shader: TShader; Light: TLight; Index: Integer);
    procedure ApplySceneLightsToShader(Shader: TShader);

    function CreateTranslateGizmo(ParentObj: TSceneObject): TSceneObject;
    function CreateRotateGizmo(ParentObj: TSceneObject): TSceneObject;
    function CreateScaleGizmo(ParentObj: TSceneObject): TSceneObject;

    procedure SynchronizeTreeViewSelection(Obj: TSceneObject);

    procedure RotateObjectAroundWorldAxis(Obj: TSceneObject; const WorldAxis: TVector3; AngleRad: Single);
    function ProjectMouseToAxisPlane(X, Y: Integer; const AxisDir, PlanePoint: TVector3; out PointOnAxis: TVector3): Boolean;

    function SelectObjectAtScreenPos(X, Y: Integer): Boolean;
    procedure DeselectObject;
    function PickGizmoAxis(X, Y: Integer; out AxisTag: Integer): Boolean;
    function PickRotateAxis(X, Y: Integer; out AxisTag: Integer): Boolean;
    function PickScaleGizmoAxis(X, Y: Integer; out AxisTag: Integer): Boolean;

    function IsMeshEditModeActive: Boolean;
    function GetGizmoTargetWorldPosition: TVector3;

    function SceneDirectory: string;
    procedure ConfigureSceneDialogs;
    procedure PrepareSceneReplacement;
    procedure CreateDefaulTSceneObjects;
    procedure NewScene;
    function CaptureSceneSnapshot(out Snapshot: TBytes): Boolean;
    procedure RememberSavedSceneSnapshot;
    function SceneHasUnsavedChanges: Boolean;
    function ConfirmSaveDirtyScene: Boolean;
    function SaveSceneToFile(const AFileName: string): Boolean;
    function SaveCurrentScene(ForceDialog: Boolean): Boolean;
    function MaterialDirectory: string;
    procedure ConfigureMaterialDialogs;
    function FindFirstLightObject(aObject: TSceneObject; RequireShadowCaster: Boolean): TSceneObject;
    procedure AttachRuntimeSceneData(aObject: TSceneObject);
    procedure RestoreLoadedSceneRuntimeState;
    procedure ResetPhysicsWorldForScene;
    function EnsurePhysicsBodyForObject(Obj: TSceneObject): TPhysicsBody;
    procedure EnsurePhysicsBodiesForScene(Obj: TSceneObject);
    procedure SetPhysicsSimulationMode(Value: Boolean);
    function BuildSceneObjectPath(Obj: TSceneObject): string;
    function FindSceneObjectByPath(const Path: string): TSceneObject;
    procedure SavePhysicsStatesToStream(Stream: TStream);
    procedure LoadPhysicsStatesFromStream(Stream: TStream);

    function GetArrowTipByTag(AxisTag: Integer): TVector3;
    function GetScaleTipByTag(AxisTag: Integer): TVector3;
    function GetDragParameter(CurrentX, CurrentY: Integer; out u: Single): Boolean;
    procedure CheckGizmoHover(X, Y: Integer);
    procedure RefreshGizmo;
    procedure RefreshSelectedBoundingBox;
    procedure UpdateGizmoScale;
    procedure SyncGizmoModeButtons;
    procedure ClearPhysicsDebugHull;
    procedure RefreshPhysicsDebugHull;
    function IsNewObjectEditorActive: Boolean;

    // UI custom
    procedure AddToTree(ParentNode: TTreeNode; SceneObject: TSceneObject);
    procedure PopulateTreeView;
    function GetSelectedObjectOrder(out ParentObj: TSceneObject; out Index: Integer): Boolean;
    function CanMoveSelectedObject(Delta: Integer): Boolean;
    procedure MoveSelectedObject(Delta: Integer);
    procedure UpdateObjectCommandStates;
    procedure UpdateUI;
    procedure UpdateSceneStatusBar;
    procedure Old_ReadTransform;
    procedure Old_ReadMeshes;
    procedure Old_ReadPhysics;

    procedure UpdateMeshEditor(const aClassName: String);
    procedure ReadProperties(aMesh: TMesh);
    procedure ReadMeshBase(aMesh: TMesh);
    procedure ReadTransform(aMesh: TMesh);
    procedure ReadPlane(aMesh: TPlaneMesh);
    procedure ReadCube(aMesh: TCubeMesh);
    procedure ReadSphere(aMesh: TSphereMesh);
    procedure ReadCylinder(aMesh: TCylinderMesh);
    procedure ReadCapsule(aMesh: TCapsuleMesh);
    procedure ReadTorus(aMesh: TTorusMesh);
    procedure ReadCone(aMesh: TConeMesh);
    procedure ReadPrism(aMesh: TPrismMesh);
    procedure ReadFrustum(aMesh: TFrustumMesh);
    procedure ReadIcosphere(aMesh: TIcosphereMesh);
    procedure ReadGeodesicDome(aMesh: TGeodesicDomeMesh);
    procedure ReadArrow(aMesh: TArrowMesh);
    procedure ReadSuperEllipsoid(aMesh: TSuperEllipsoidMesh);
    procedure ReadHeightField(aMesh: THeightFieldMesh);
    procedure ReadFile(aMesh: TFileMesh);
    procedure ResetMeshEditor;
    procedure UnhookMeshEditorEvents;
    procedure HookMeshEditorEvents;
    procedure NotifyMeshEditorChanged(const RefreshProperties: Boolean = False);
    function SelectedMeshIndex: Integer;
    function GetMeshEditorTransformValues(out Translation, RotationDeg, Scale: TVector3): Boolean;
    procedure SetMeshEditorTransformValues(const Translation, RotationDeg, Scale: TVector3;
      const Preview: Boolean);
    procedure MeshNameChange(Sender: TObject);
    procedure MeshOriginChange(Sender: TObject);
    procedure MeshMaterialLibraryChange(Sender: TObject);
    procedure MeshLibraryNameChange(Sender: TObject);
    procedure MeshTransformChange(Sender: TObject);
    procedure MeshShapeChange(Sender: TObject);
    procedure HeightFieldMeshSourceFileClick(Sender: TObject);
    procedure MeshApplyUVClick(Sender: TObject);
    function MeshCenterPresetByIndex(const AIndex: Integer): TMeshCenterPreset;
    function MeshCenterPresetIndex(aPreset: TMeshCenterPreset): Integer;
    function MeshCapFromCombo(Combo: TComboBox): TCapType;
    procedure SetMeshCapCombo(Combo: TComboBox; Cap: TCapType);
    procedure FillMeshMaterialControls(aMesh: TMesh);

    // New System
    procedure HookMainEditorEvents;
    procedure EnsureWaterMenuItems;

    function TryReadEditorFloat(Edit: TEdit; const FieldName: string;
      out Value: Single; const ShowError: Boolean = True): Boolean;
    function TryReadEditorInteger(Edit: TEdit; const FieldName: string;
      out Value: Integer; const ShowError: Boolean = True): Boolean;

    procedure ReadTransformControls(aSceneObject: TSceneObject);
    procedure ResetTransformControls;

    procedure ReadMeshes(aSceneObject: TSceneObject);
    procedure ResetMeshes;
    procedure RefreshMeshList;
    procedure SelectMeshIndex(const MeshIndex: Integer);
    procedure SetMeshButtonsEnabled(const AHasObject, AHasMesh: Boolean);
    procedure AddCreatedMesh(NewMesh: TMesh);
    procedure EnsureMeshCreatorForm;
    procedure ShowMeshCreatorForNewMesh(NewMesh: TMesh; const ACaption: string; APanel: TPanel);
    procedure MeshCreatorClose(Sender: TObject; var Action: TCloseAction);
    procedure MaterialEditorClose(Sender: TObject);
    function GenMeshName(const aName: String): String;

    procedure ReadPhysicsBody(Body: TPhysicsBody);
    procedure ResetPhysicsControls;
    procedure RefreshPhysicsControls;
    function CommitPhysicsChanges: Boolean;
    function ApplyPhysicsControlsToBody: Boolean;
    function CloneMeshForListMove(Source: TMesh): TMesh;


    // Cut, Copy, Paste
    procedure CutNode;
    procedure CopyNode;
    procedure PasteNode;
    procedure ClearClipboard;
    procedure SyncShortcutTreeSelection(Sender: TObject);

    procedure DoProgress(Sender: TObject; const deltaTime, newTime: Double);
    procedure DoTotalProgress(Sender: TObject; const deltaTime, newTime: Double);

    const
      GIZMO_SCREEN_SIZE_PX = 70.0;

    var
    fLight: TSceneObject;
    fCamera: TSceneObject;
    fCameraUp: TVector3;

    fShader, fHeightFieldShader, fGizmoShader: TShader;
    MaterialLibraries: TMaterialLibraries;

    fSceneManager: TSceneManager;
    fRoot: TSceneObject;
    fSceneWorld: TSceneObject;

    Timer: TEngineTimer;
    fSelectedObject: TSceneObject;
    fCurrentGizmo: TSceneObject;
    fGizmoOwner: TSceneObject;
    fPhysicsDebugHull: TSceneObject;
    fPhysicsDebugHullOwner: TPhysicsBody;
    fBuiltGizmoMode: TGizmoMode;
    fLastPickedMeshIndex: Integer;

    // Mouse navigation
    fMouseDown: Boolean;
    fLastMouseX, fLastMouseY: Integer;
    fOrbitTarget: TVector3;
    // ---- SMOOTH NAVIGATION: current values drive the camera ----
    fCurrentRadius: Single;
    fCurrentAzimuth: Single;
    fCurrentPolar: Single;
    // ---- target values updated by user input ----
    fTargetRadius: Single;
    fTargetAzimuth: Single;
    fTargetPolar: Single;
    fSmoothSpeed: Single;          // interpolation factor (units per second)
    // -----------------------------------------------------------
    fRotateSpeed: Single;
    fZoomSpeed: Single;
    fFOVRadians: Single;

    fPanActive: Boolean;
    fLastPanX, fLastPanY: Integer;
    fPanSpeed: Single;

    fRenderer: TRenderer;
    fPhysicsWorld: TPhysicsWorld;
    fScriptManager: TEngineScriptManager;
    fSimulatePhysics: Boolean;
    fPhysicsRestorePending: Boolean;
    fCurrentSceneFileName: string;
    fSavedSceneSnapshot: TBytes;

    // Cut, Copy, Paste
    FClipboardNode: TTreeNode;       // node that is cut/copied
    FClipboardObject: TSceneObject;
    FClipboardParent: TSceneObject;
    FClipboardIndex: Integer;        // original index inside parent
    FIsCut: Boolean;                 // True = cut, False = copy

    // Gizmo dragging
    fDraggingGizmo: Boolean;
    fDraggedAxis: Integer;        // 0 = X, 1 = Y, 2 = Z
    fDragStartMousePos: TPoint;
    fDragStartObjectPos: TVector3;
    fDragAxisWorldDir: TVector3;  // world direction of the selected axis
    fDragOffsetWorld: TVector3;
    fHoveredAxis: Integer;
    // Gizmo rotation
    fGizmoMode: TGizmoMode;
    fRotateSensitivity: Single;      // degrees per pixel
    fIsRotateGizmo: Boolean;
    fRotateStartAngle: Single;
    fRotateStartAngleSet: Boolean;
    fDragStartHandlePos: TVector3;   // world position of the handle at drag start
    fInitialScale: TVector3;          // initial scale of the object
    fMeshDragStartTranslation: TVector3;
    fMeshDragStartRotationDeg: TVector3;
    fMeshDragStartScale: TVector3;
    fDragStartScreenPos: TPoint;        // screen position of handle at drag start
    fDragStartScreenAxis: TVector2;     // screen projection of axis direction
    fDragStartPixelDelta: Single;

    //NewComponent: TfNewComponent;
    fTransformObject: TSceneObject;
    fSuppressTransformChange: Boolean;
    fSelectedMesh: TMesh;
    fSuppressMeshEditorChange: Boolean;
    fPhysicsBody: TPhysicsBody;
    fSuppressPhysicsControls: Boolean;
    fNewObjectMode: Boolean;
  public
    PATH: string;
    GLSL_PATH: String;

    property PhysicsWorld: TPhysicsWorld read fPhysicsWorld;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

uses InternalMeshCreator, DWSTestingUnit, Editor.Material, Editor.ParticleEditor, MainFormUnit;

const
  PHYSICS_SCENE_CHUNK_VERSION = 1;
  PHYSICS_SCENE_CHUNK_MAGIC: array[0..7] of AnsiChar = ('O', 'M', 'E', 'P', 'H', 'Y', '0', '1');
  GIZMO_MATERIAL_NAME = 'GizmoColorMaterial';

function IsGizmoMaterialName(const AName: string): Boolean;
begin
  Result := SameText(AName, GIZMO_MATERIAL_NAME);
end;

function IsEditorOnlyMaterial(AMaterial: TMaterial): Boolean;
begin
  Result := (AMaterial = nil) or IsGizmoMaterialName(AMaterial.Name) or
    (AMaterial.Materialtype = mtShadow);
end;

function TMainForm.EnsureDefaultMaterialLibrary: TMaterialLibrary;
begin
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

procedure TMainForm.EnsureGizmoMaterial;
var
  Lib: TMaterialLibrary;
  Mat: TMaterial;
  I: Integer;
  GizmoIndex: Integer;
begin
  Lib := EnsureDefaultMaterialLibrary;
  if Lib = nil then
    Exit;

  Mat := nil;
  GizmoIndex := -1;
  for I := 0 to Lib.Count - 1 do
  begin
    if Assigned(Lib.Material[I]) and IsGizmoMaterialName(Lib.Material[I].Name) then
    begin
      Mat := Lib.Material[I];
      GizmoIndex := I;
      Break;
    end;
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

function TMainForm.DefaultRenderableMaterialName: string;
var
  Lib: TMaterialLibrary;
  I: Integer;
begin
  Result := '';
  Lib := EnsureDefaultMaterialLibrary;
  if Lib = nil then
    Exit;

  for I := 0 to Lib.Count - 1 do
    if Assigned(Lib.Material[I]) and (not IsEditorOnlyMaterial(Lib.Material[I])) then
    begin
      Result := Lib.Material[I].Name;
      Exit;
    end;

end;

function TMainForm.ShaderForMaterialType(AMaterialType: TMaterialType): TShader;
begin
  case AMaterialType of
    mtHeightFieldMaterial:
      Result := fHeightFieldShader;
  else
    Result := fShader;
  end;
end;

procedure TMainForm.AssignShaderToMaterial(AMaterial: TMaterial);
begin
  if AMaterial = nil then
    Exit;

  if IsGizmoMaterialName(AMaterial.Name) then
    AMaterial.Shader := fGizmoShader
  else
    AMaterial.Shader := ShaderForMaterialType(AMaterial.Materialtype);
end;

procedure TMainForm.AssignShadersToMaterialLibrary(ALib: TMaterialLibrary);
var
  I: Integer;
begin
  if ALib = nil then
    Exit;

  for I := 0 to ALib.Count - 1 do
    AssignShaderToMaterial(ALib.Material[I]);
end;

function TMainForm.CloneMaterialForMainShader(AMaterial: TMaterial): TMaterial;
var
  Stream: TMemoryStream;
begin
  Result := nil;
  if AMaterial = nil then
    Exit;

  Stream := TMemoryStream.Create;
  try
    AMaterial.SaveToStream(Stream);
    Stream.Position := 0;
    Result := TMaterial.LoadFromStream(Stream, fShader);
    AssignShaderToMaterial(Result);
  finally
    Stream.Free;
  end;
end;

procedure TMainForm.ClearUserMaterialsFromLibrary(ALib: TMaterialLibrary);
var
  I: Integer;
begin
  if ALib = nil then
    Exit;

  for I := ALib.Count - 1 downto 0 do
    if Assigned(ALib.Material[I]) and (not IsEditorOnlyMaterial(ALib.Material[I])) then
      ALib.DeleteMaterial(I);
end;

function TMainForm.CopyUserMaterialsFromLibrary(ASource, ADest: TMaterialLibrary): Integer;
var
  I: Integer;
  Mat: TMaterial;
begin
  Result := 0;
  if (ASource = nil) or (ADest = nil) then
    Exit;

  for I := 0 to ASource.Count - 1 do
  begin
    if IsEditorOnlyMaterial(ASource.Material[I]) then
      Continue;

    Mat := CloneMaterialForMainShader(ASource.Material[I]);
    try
      if Mat = nil then
        Continue;

      AssignShaderToMaterial(Mat);
      ADest.AddMaterial(Mat);
      Mat := nil;
      Inc(Result);
    finally
      Mat.Free;
    end;
  end;
end;

procedure TMainForm.cpPhysicsMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  newMeshEditor.Visible := False;
end;

procedure TMainForm.ReplaceDefaultUserMaterialsFromLibrary(ASource: TMaterialLibrary);
var
  Lib: TMaterialLibrary;
begin
  EnsureGizmoMaterial;
  Lib := EnsureDefaultMaterialLibrary;
  ClearUserMaterialsFromLibrary(Lib);
  CopyUserMaterialsFromLibrary(ASource, Lib);
  EnsureGizmoMaterial;
end;

procedure TMainForm.ReplaceUserMaterialLibraries(ASource: TMaterialLibraries);
var
  I: Integer;
  NewLib: TMaterialLibrary;
begin
  EnsureGizmoMaterial;

  while MaterialLibraries.Count > 1 do
    MaterialLibraries.Delete(MaterialLibraries.Count - 1);

  ClearUserMaterialsFromLibrary(MaterialLibraries.MaterialLibrary[0]);

  if (ASource <> nil) and (ASource.Count > 0) then
  begin
    CopyUserMaterialsFromLibrary(ASource.MaterialLibrary[0], MaterialLibraries.MaterialLibrary[0]);

    for I := 1 to ASource.Count - 1 do
    begin
      NewLib := TMaterialLibrary.Create;
      try
        NewLib.Name := ASource.MaterialLibrary[I].Name;
        CopyUserMaterialsFromLibrary(ASource.MaterialLibrary[I], NewLib);
        MaterialLibraries.AddMaterialLibrary(NewLib);
        NewLib := nil;
      finally
        NewLib.Free;
      end;
    end;
  end;

  EnsureGizmoMaterial;
end;

function TMainForm.SafeMaterialFileNamePart(const Value: string): string;
var
  I: Integer;
  Ch: Char;
begin
  Result := Trim(Value);
  if Result = '' then
    Result := 'Material';

  for I := 1 to Length(Result) do
  begin
    Ch := Result[I];
    if (Ord(Ch) < 32) or CharInSet(Ch, ['\', '/', ':', '*', '?', '"', '<', '>', '|']) then
      Result[I] := '_';
  end;
end;

function TMainForm.SceneMaterialPrefix(const ASceneFileName: string): string;
begin
  Result := SafeMaterialFileNamePart(ChangeFileExt(ExtractFileName(ASceneFileName), ''));
  if Result = '' then
    Result := 'Scene';
  Result := Result + '_';
end;

function TMainForm.SceneMaterialFileName(const ASceneFileName: string): string;
begin
  Result := TPath.Combine(MaterialDirectory, SceneMaterialPrefix(ASceneFileName) + 'Materials.omeml');
end;

procedure TMainForm.SaveSceneMaterialsToFiles(const ASceneFileName: string);
var
  Dir: string;
  Prefix: string;
  FileName: string;
  ExportLibraries: TMaterialLibraries;
  SourceLib: TMaterialLibrary;
  ExportLib: TMaterialLibrary;
  Stream: TFileStream;
  I: Integer;
  SavedCount: Integer;
begin
  if MaterialLibraries = nil then
    Exit;

  Dir := MaterialDirectory;
  ForceDirectories(Dir);
  Prefix := SceneMaterialPrefix(ASceneFileName);
  FileName := SceneMaterialFileName(ASceneFileName);

  for var ExistingFile in TDirectory.GetFiles(Dir, Prefix + '*.omemat') do
    TFile.Delete(ExistingFile);

  ExportLibraries := TMaterialLibraries.Create;
  try
    SavedCount := 0;
    for I := 0 to MaterialLibraries.Count - 1 do
    begin
      SourceLib := MaterialLibraries.MaterialLibrary[I];
      if SourceLib = nil then
        Continue;

      ExportLib := TMaterialLibrary.Create;
      try
        ExportLib.Name := SourceLib.Name;
        Inc(SavedCount, CopyUserMaterialsFromLibrary(SourceLib, ExportLib));
        ExportLibraries.AddMaterialLibrary(ExportLib);
        ExportLib := nil;
      finally
        ExportLib.Free;
      end;
    end;

    Stream := TFileStream.Create(FileName, fmCreate);
    try
      ExportLibraries.SaveToStream(Stream);
    finally
      Stream.Free;
    end;
  finally
    ExportLibraries.Free;
  end;

  mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) +
    Format('Scene material list saved: %s (%d material(s)).', [ExtractFileName(FileName), SavedCount]));
end;
procedure TMainForm.LoadSceneMaterialsForFile(const ASceneFileName: string);
var
  FileName: string;
  LoadedLibraries: TMaterialLibraries;
  Stream: TFileStream;
  I, J: Integer;
  LoadedCount: Integer;
begin
  ForceDirectories(MaterialDirectory);
  FileName := SceneMaterialFileName(ASceneFileName);

  ActivateMainRenderContext;
  EnsureGizmoMaterial;

  if not FileExists(FileName) then
  begin
    ClearUserMaterialsFromLibrary(EnsureDefaultMaterialLibrary);
    LoadDefaultTextures;
    EnsureGizmoMaterial;
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) +
      'Scene material list not found, default materials loaded.');
    Exit;
  end;

  LoadedLibraries := TMaterialLibraries.Create;
  try
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      LoadedLibraries.LoadFromStream(Stream, fShader);
    finally
      Stream.Free;
    end;

    LoadedCount := 0;
    for I := 0 to LoadedLibraries.Count - 1 do
    begin
      AssignShadersToMaterialLibrary(LoadedLibraries.MaterialLibrary[I]);
      for J := 0 to LoadedLibraries.MaterialLibrary[I].Count - 1 do
        if not IsEditorOnlyMaterial(LoadedLibraries.MaterialLibrary[I].Material[J]) then
          Inc(LoadedCount);
    end;

    ReplaceUserMaterialLibraries(LoadedLibraries);
    if LoadedCount = 0 then
      LoadDefaultTextures;
  finally
    LoadedLibraries.Free;
  end;

  EnsureGizmoMaterial;
  mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) +
    Format('Scene material list loaded: %s.', [ExtractFileName(FileName)]));
end;
procedure TMainForm.BindScriptManager;
var
  Lib: TMaterialLibrary;
  DefaultMaterial: string;
begin
  if fScriptManager = nil then
    Exit;

  Lib := nil;
  DefaultMaterial := '';
  if MaterialLibraries <> nil then
  begin
    Lib := EnsureDefaultMaterialLibrary;
    DefaultMaterial := DefaultRenderableMaterialName;
  end;

  fScriptManager.BindEngine(fRenderer, fSceneManager, Lib, DefaultMaterial,
    MeshRenderHandler);
end;

const
  MESH_DEG_TO_RAD: Single = Pi / 180.0;

function EditorFloatToText(Value: Single): string;
var
  FS: TFormatSettings;
begin
  FS := TFormatSettings.Create;
  FS.DecimalSeparator := '.';
  FS.ThousandSeparator := ',';
  Result := FloatToStrF(Value, ffGeneral, 7, 4, FS);
end;

function PhysicsInverseMassForState(const State: TPhysicsBodyState): Single;
begin
  if (State.BodyType in [pbtStatic, pbtKinematic]) or (State.Mass <= 1e-5) then
    Result := 0.0
  else
    Result := 1.0 / State.Mass;
end;

function TMainForm.TryReadEditorFloat(Edit: TEdit; const FieldName: string;
  out Value: Single; const ShowError: Boolean): Boolean;
var
  Text: string;
  Parsed: Extended;
  FS: TFormatSettings;
begin
  Text := Trim(Edit.Text);
  FS := TFormatSettings.Create;

  Result := TryStrToFloat(Text, Parsed, FS);
  if not Result then
  begin
    FS.DecimalSeparator := '.';
    FS.ThousandSeparator := ',';
    Result := TryStrToFloat(Text, Parsed, FS);
  end;
  if not Result then
  begin
    FS.DecimalSeparator := ',';
    FS.ThousandSeparator := '.';
    Result := TryStrToFloat(Text, Parsed, FS);
  end;

  if Result then
    Value := Parsed
  else if ShowError then
  begin
    ShowMessage(Format('%s must be a valid number.', [FieldName]));
    Edit.SetFocus;
  end;
end;

function TMainForm.TryReadEditorInteger(Edit: TEdit; const FieldName: string;
  out Value: Integer; const ShowError: Boolean): Boolean;
var
  Text: string;
begin
  Text := Trim(Edit.Text);
  Result := TryStrToInt(Text, Value);
  if (not Result) and ShowError then
  begin
    ShowMessage(Format('%s must be a valid integer.', [FieldName]));
    Edit.SetFocus;
  end;
end;

procedure TMainForm.EnsureWaterMenuItems;
  procedure AddWaterItem(AParent: TMenuItem);
  var
    I: Integer;
    Item: TMenuItem;
  begin
    if AParent = nil then
      Exit;

    for I := 0 to AParent.Count - 1 do
      if SameText(AParent.Items[I].Caption, 'Water Plane') then
      begin
        AParent.Items[I].OnClick := puNewWaterPlaneClick;
        Exit;
      end;

    Item := TMenuItem.Create(Self);
    Item.Caption := 'Water Plane';
    Item.OnClick := puNewWaterPlaneClick;
    AParent.Add(Item);
  end;
begin
  AddWaterItem(puNew);
  if Assigned(PlusMenu) then
    AddWaterItem(PlusMenu.Items);
  AddWaterItem(mmNewSceneObject);
end;

procedure TMainForm.HookMainEditorEvents;
begin
  KeyPreview := True;
  OnKeyDown := EditorShortcutKeyDown;
  EnsureWaterMenuItems;

  scTree.OnKeyDown := EditorShortcutKeyDown;
  pnlRenderingSurface.TabStop := True;

  ePositionX.OnChange := TransformEditChange;
  ePositionY.OnChange := TransformEditChange;
  ePositionZ.OnChange := TransformEditChange;
  eRotationX.OnChange := TransformEditChange;
  eRotationY.OnChange := TransformEditChange;
  eRotationZ.OnChange := TransformEditChange;
  eScaleX.OnChange := TransformEditChange;
  eScaleY.OnChange := TransformEditChange;
  eScaleZ.OnChange := TransformEditChange;

  lbMeshes.OnClick := lbMeshesClick;
  lbMeshes.OnDblClick := lbMeshesDblClick;
  spbAddMesh.OnClick := spbAddMeshClick;
  spbDeleteMesh.OnClick := spbDeleteMeshClick;
  spbUpMesh.OnClick := spbUpMeshClick;
  spbDownMesh.OnClick := spbDownMeshClick;
  spbLoadMesh.OnClick := spbLoadMeshClick;

  puNewWaterPlane.OnClick := puNewWaterPlaneClick;
  miWaterPlane.OnClick := puNewWaterPlaneClick;

  puNewEmpty.OnClick := MeshNewEmptyClick;
  MenuItem4.OnClick := MeshNewPlaneClick;
  MenuItem23.OnClick := MeshNewCubeClick;
  MenuItem24.OnClick := MeshNewSphereClick;
  MenuItem25.OnClick := MeshNewCylinderClick;
  MenuItem26.OnClick := MeshNewCapsuleClick;
  MenuItem27.OnClick := MeshNewTorusClick;
  MenuItem28.OnClick := MeshNewConeClick;
  MenuItem29.OnClick := MeshNewPrismClick;
  puNewPyramid.OnClick := MeshNewPyramidClick;
  MenuItem30.OnClick := MeshNewArrowClick;
  MenuItem31.OnClick := MeshNewIcosphereClick;
  MenuItem32.OnClick := MeshNewGeodesicDomeClick;
  MenuItem33.OnClick := MeshNewSphereEllipsoidClick;
  MenuItem34.OnClick := MeshNewCylinderEllipsoidClick;
  MenuItem35.OnClick := MeshNewCubeEllipsoidClick;
  MenuItem36.OnClick := MeshNewStarEllipsoidClick;
  MenuItem37.OnClick := MeshNewPillEllipsoidClick;

  btnApply.OnClick := btnApplyClick;
  btnCancel.OnClick := btnCancelClick;
  spbNewScene.OnClick := spbNewSceneClick;
  spbOpenScene.OnClick := spbOpenSceneClick;
  spbSaveScene.OnClick := spbSaveSceneClick;
  spbSaveAsScene.OnClick := spbSaveAsSceneClick;
  spbUpObject.OnClick := spbUpObjectClick;
  spbDownObject.OnClick := spbDownObjectClick;
  mmExit.OnClick := mmExitClick;
  chbDebugPhysics.OnClick := chbDebugPhysicsClick;
  chbShowBoundingBox.OnClick := chbShowBoundingBoxClick;
  HookMeshEditorEvents;

  if cbColliderKind.Items.Count = 0 then
  begin
    cbColliderKind.Items.Add('Auto');
    cbColliderKind.Items.Add('None');
    cbColliderKind.Items.Add('Sphere');
    cbColliderKind.Items.Add('Capsule');
    cbColliderKind.Items.Add('AABB');
    cbColliderKind.Items.Add('Mesh');
    cbColliderKind.Items.Add('ConvexHull');
  end;
end;

procedure TMainForm.ReadTransformControls(aSceneObject: TSceneObject);
begin
  fTransformObject := aSceneObject;
  fSuppressTransformChange := True;
  try
    cpPosition.Enabled := Assigned(fTransformObject);
    cpRotation.Enabled := Assigned(fTransformObject);
    cpScale.Enabled := Assigned(fTransformObject);

    if not Assigned(fTransformObject) then
    begin
      ePositionX.Text := '0.00';
      ePositionY.Text := '0.00';
      ePositionZ.Text := '0.00';
      eRotationX.Text := '0.00';
      eRotationY.Text := '0.00';
      eRotationZ.Text := '0.00';
      eScaleX.Text := '0.00';
      eScaleY.Text := '0.00';
      eScaleZ.Text := '0.00';
      Exit;
    end;

    ePositionX.Text := FloatToStrF(fTransformObject.Position.X, ffFixed, 4, 2);
    ePositionY.Text := FloatToStrF(fTransformObject.Position.Y, ffFixed, 4, 2);
    ePositionZ.Text := FloatToStrF(fTransformObject.Position.Z, ffFixed, 4, 2);
    eRotationX.Text := FloatToStrF(RadToDeg(fTransformObject.Rotation.X), ffFixed, 4, 2);
    eRotationY.Text := FloatToStrF(RadToDeg(fTransformObject.Rotation.Y), ffFixed, 4, 2);
    eRotationZ.Text := FloatToStrF(RadToDeg(fTransformObject.Rotation.Z), ffFixed, 4, 2);
    eScaleX.Text := FloatToStrF(fTransformObject.Scale.X, ffFixed, 4, 2);
    eScaleY.Text := FloatToStrF(fTransformObject.Scale.Y, ffFixed, 4, 2);
    eScaleZ.Text := FloatToStrF(fTransformObject.Scale.Z, ffFixed, 4, 2);
  finally
    fSuppressTransformChange := False;
  end;
end;

procedure TMainForm.ResetTransformControls;
begin
  ReadTransformControls(nil);
end;

procedure TMainForm.TransformEditChange(Sender: TObject);
var
  PX, PY, PZ, RX, RY, RZ, SX, SY, SZ: Single;
begin
  if fSuppressTransformChange or (not Assigned(fTransformObject)) then
    Exit;

  if (ePositionX.Text = '') or (ePositionY.Text = '') or (ePositionZ.Text = '') or
     (eRotationX.Text = '') or (eRotationY.Text = '') or (eRotationZ.Text = '') or
     (eScaleX.Text = '') or (eScaleY.Text = '') or (eScaleZ.Text = '') then
    Exit;

  if TryReadEditorFloat(ePositionX, 'Position X', PX, False) and
     TryReadEditorFloat(ePositionY, 'Position Y', PY, False) and
     TryReadEditorFloat(ePositionZ, 'Position Z', PZ, False) then
    fTransformObject.Position := Vector3(PX, PY, PZ);

  if TryReadEditorFloat(eRotationX, 'Rotation X', RX, False) and
     TryReadEditorFloat(eRotationY, 'Rotation Y', RY, False) and
     TryReadEditorFloat(eRotationZ, 'Rotation Z', RZ, False) then
    fTransformObject.Rotation := Vector3(DegToRad(RX), DegToRad(RY), DegToRad(RZ));

  if TryReadEditorFloat(eScaleX, 'Scale X', SX, False) and
     TryReadEditorFloat(eScaleY, 'Scale Y', SY, False) and
     TryReadEditorFloat(eScaleZ, 'Scale Z', SZ, False) then
    fTransformObject.Scale := Vector3(SX, SY, SZ);

  fTransformObject.NotifyChange;
  fSceneManager.Update;
  RefreshGizmo;
  if Assigned(fRenderer) then
    fRenderer.Render;
end;

procedure TMainForm.SetMeshButtonsEnabled(const AHasObject, AHasMesh: Boolean);
begin
  cpMeshes.Enabled := AHasObject;
  spbAddMesh.Enabled := AHasObject;
  spbLoadMesh.Enabled := AHasObject;
  spbDeleteMesh.Enabled := AHasMesh;
  spbUpMesh.Enabled := AHasMesh and (lbMeshes.ItemIndex > 0);
  spbDownMesh.Enabled := AHasMesh and (lbMeshes.ItemIndex >= 0) and
    (lbMeshes.ItemIndex < lbMeshes.Items.Count - 1);
end;

procedure TMainForm.RefreshMeshList;
var
  I: Integer;
begin
  lbMeshes.Items.BeginUpdate;
  try
    lbMeshes.Clear;
    if fSelectedObject <> nil then
      for I := 0 to fSelectedObject.MeshList.Count - 1 do
        lbMeshes.Items.Add(fSelectedObject.MeshList.Item[I].Name);
  finally
    lbMeshes.Items.EndUpdate;
  end;
end;

procedure TMainForm.SelectMeshIndex(const MeshIndex: Integer);
begin
  if (fSelectedObject = nil) or (MeshIndex < 0) or
     (MeshIndex >= fSelectedObject.MeshList.Count) then
    Exit;

  lbMeshes.ItemIndex := MeshIndex;
  lbMeshesClick(Self);
end;

procedure TMainForm.ReadMeshes(aSceneObject: TSceneObject);
var
  SelectIndex: Integer;
begin
  fSelectedMesh := nil;
  ResetMeshEditor;

  RefreshMeshList;
  SelectIndex := -1;

  if (aSceneObject <> nil) and (aSceneObject.MeshList.Count > 0) then
  begin
    SelectIndex := 0;
    if (fLastPickedMeshIndex >= 0) and
       (fLastPickedMeshIndex < aSceneObject.MeshList.Count) then
      SelectIndex := fLastPickedMeshIndex;

    lbMeshes.ItemIndex := SelectIndex;
    lbMeshesClick(Self);
  end
  else
  begin
    lbMeshes.ItemIndex := -1;
    SetMeshButtonsEnabled(aSceneObject <> nil, False);
  end;
end;

procedure TMainForm.ResetMeshes;
begin
  fSelectedMesh := nil;
  lbMeshes.Clear;
  SetMeshButtonsEnabled(False, False);
  ResetMeshEditor;
end;

procedure TMainForm.lbMeshesClick(Sender: TObject);
begin
  if (fSelectedObject = nil) or (lbMeshes.ItemIndex < 0) or
     (lbMeshes.ItemIndex >= fSelectedObject.MeshList.Count) then
  begin
    fSelectedMesh := nil;
    SetMeshButtonsEnabled(fSelectedObject <> nil, False);
    ResetMeshEditor;
    Exit;
  end;

  fSelectedMesh := fSelectedObject.MeshList.Item[lbMeshes.ItemIndex];
  SetMeshButtonsEnabled(True, fSelectedMesh <> nil);
  if (Sender = lbMeshes) or newMeshEditor.Visible then
    ReadProperties(fSelectedMesh);
end;

procedure TMainForm.lbMeshesDblClick(Sender: TObject);
begin
  if (fSelectedObject = nil) or (lbMeshes.ItemIndex < 0) or
     (lbMeshes.ItemIndex >= fSelectedObject.MeshList.Count) then
    Exit;

  fSelectedMesh := fSelectedObject.MeshList.Item[lbMeshes.ItemIndex];
  ReadProperties(fSelectedMesh);

  mLog.Lines.Add(fSelectedMesh.ClassName);

  RefreshGizmo;
  if Assigned(fRenderer) then
    fRenderer.Render;
end;

function TMainForm.GenMeshName(const aName: String): String;
begin
  if fSelectedObject <> nil then
    Result := aName + IntToStr(fSelectedObject.MeshList.Count)
  else
    Result := aName + '0';
end;

procedure TMainForm.ActivateMainRenderContext;
begin
  if Assigned(fRenderer) then
    fRenderer.ActivateContext;
end;

procedure TMainForm.AddCreatedMesh(NewMesh: TMesh);
var
  NewIndex: Integer;
begin
  if NewMesh = nil then
    Exit;

  if fSelectedObject = nil then
  begin
    NewMesh.Free;
    Exit;
  end;

  NewMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  if (MaterialLibraries.MaterialLibrary[0] <> nil) and (MaterialLibraries.MaterialLibrary[0].Count > 0) and
     (NewMesh.LibMaterialname = '') then
    NewMesh.LibMaterialname := DefaultRenderableMaterialName;
  NewMesh.OnRender := MeshRenderHandler;

  NewIndex := fSelectedObject.MeshList.AddMeshToList(NewMesh);
  fSelectedObject.UpdateBoundingRadiusFromMesh;
  fSelectedObject.NotifyChange;
  RefreshMeshList;
  lbMeshes.ItemIndex := NewIndex;
  lbMeshesClick(Self);
  RefreshGizmo;
  UpdateSceneStatusBar;
  if Assigned(fRenderer) then
    fRenderer.Render;
end;


procedure TMainForm.EnsureMeshCreatorForm;
begin
  if not Assigned(frmMeshCreator) then
    frmMeshCreator := TfrmMeshCreator.Create(Self);
end;

procedure TMainForm.MeshCreatorClose(Sender: TObject; var Action: TCloseAction);
var
  Obj: TSceneObject;
  Mesh: TMesh;
  MeshIndex: Integer;
begin
  Obj := nil;
  Mesh := nil;
  MeshIndex := -1;

  if Assigned(frmMeshCreator) then
  begin
    Obj := frmMeshCreator.InternalObject;
    Mesh := frmMeshCreator.SelectedMesh;
    if Assigned(Obj) and Assigned(Mesh) then
      MeshIndex := Obj.MeshList.IndexOf(Mesh);

    // Keep the original TfrmMeshCreator close logic.
    frmMeshCreator.FormClose(Sender, Action);
    frmMeshCreator.OnClose := frmMeshCreator.FormClose;
  end;

  fNewObjectMode := False;

  if Assigned(Obj) then
  begin
    fSelectedObject := Obj;
    fLastPickedMeshIndex := -1;
    SynchronizeTreeViewSelection(Obj);
    Obj.UpdateWorldMatrices;
    RefreshMeshList;
    if (MeshIndex >= 0) and (MeshIndex < lbMeshes.Items.Count) then
      lbMeshes.ItemIndex := MeshIndex;
    lbMeshesClick(Self);

    if Assigned(fCurrentGizmo) then
      FreeAndNil(fCurrentGizmo);
    fGizmoOwner := nil;
    RefreshGizmo;
    UpdateUI;
    RefreshPhysicsDebugHull;
    if Assigned(fRenderer) then
      fRenderer.Render;
  end;
end;

procedure TMainForm.ShowMeshCreatorForNewMesh(NewMesh: TMesh; const ACaption: string; APanel: TPanel);
var
  NewIndex: Integer;
begin
  if NewMesh = nil then
    Exit;

  if fSelectedObject = nil then
  begin
    NewMesh.Free;
    Exit;
  end;

  EnsureMeshCreatorForm;

  AddCreatedMesh(NewMesh);
  NewIndex := fSelectedObject.MeshList.IndexOf(NewMesh);
  if NewIndex >= 0 then
  begin
    lbMeshes.ItemIndex := NewIndex;
    lbMeshesClick(Self);
  end;

  frmMeshCreator.Visible := False;
  frmMeshCreator.OnClose := MeshCreatorClose;
  frmMeshCreator.InternalObject := fSelectedObject;
  frmMeshCreator.SelectedMesh := NewMesh;
  frmMeshCreator.SelectedTreeNode := scTree.Selected;
  frmMeshCreator.Caption := ACaption;

  frmMeshCreator.ClientWidth := 426;
  frmMeshCreator.ClientHeight := APanel.Height;
  APanel.Top := 0;
  APanel.Left := 0;

  // This is the right-side equivalent of: pnlObjects.Width + 10.
  // It opens the creator next to the right editor panel instead of next to pnlObjects.
  frmMeshCreator.Top := pnlObjects.Top + 45;
  frmMeshCreator.Left := CentralEditor.Left - frmMeshCreator.Width - 10;
  if frmMeshCreator.Left < pnlObjects.Width + 10 then
    frmMeshCreator.Left := pnlObjects.Width + 10;

  frmMeshCreator.Visible := True;
  frmMeshCreator.BringToFront;
end;

procedure TMainForm.spbAddMeshClick(Sender: TObject);
var
  P: TPoint;
begin
  if fSelectedObject = nil then
    Exit;

  P := spbAddMesh.ClientToScreen(Point(0, spbAddMesh.Height));
  pumAddMesh.Popup(P.X, P.Y);
end;

procedure TMainForm.spbAddObjectClick(Sender: TObject);
var
  Pt: TPoint;
begin
  if not spbAddObject.Enabled then
    Exit;

  Pt := spbAddObject.ClientToScreen(Point(0, spbAddObject.Height));
  PlusMenu.Popup(Pt.X, Pt.Y);
end;

procedure TMainForm.spbUpObjectClick(Sender: TObject);
begin
  MoveSelectedObject(-1);
end;

procedure TMainForm.spbDownObjectClick(Sender: TObject);
begin
  MoveSelectedObject(1);
end;

procedure TMainForm.spbDeleteMeshClick(Sender: TObject);
var
  DeleteIndex: Integer;
begin
  if (fSelectedObject = nil) or (lbMeshes.ItemIndex < 0) then
    Exit;

  DeleteIndex := lbMeshes.ItemIndex;
  if not fSelectedObject.MeshList.DeleteMesh(DeleteIndex) then
    Exit;

  fSelectedObject.UpdateBoundingRadiusFromMesh;
  fSelectedObject.NotifyChange;
  RefreshMeshList;

  if lbMeshes.Items.Count > 0 then
  begin
    if DeleteIndex >= lbMeshes.Items.Count then
      DeleteIndex := lbMeshes.Items.Count - 1;
    lbMeshes.ItemIndex := DeleteIndex;
    lbMeshesClick(Self);
  end
  else
  begin
    fSelectedMesh := nil;
    SetMeshButtonsEnabled(True, False);
    ResetMeshEditor;
  end;

  RefreshGizmo;
  UpdateSceneStatusBar;
  if Assigned(fRenderer) then
    fRenderer.Render;
end;

procedure TMainForm.spbUpMeshClick(Sender: TObject);
var
  Index: Integer;
  MeshA, MeshB: TMesh;
begin
  if (fSelectedObject = nil) or (lbMeshes.ItemIndex <= 0) then
    Exit;

  Index := lbMeshes.ItemIndex;
  MeshA := CloneMeshForListMove(fSelectedObject.MeshList.Item[Index]);
  MeshB := CloneMeshForListMove(fSelectedObject.MeshList.Item[Index - 1]);
  try
    if (MeshA = nil) or (MeshB = nil) then
      Exit;
    if not fSelectedObject.MeshList.DeleteMesh(Index) then Exit;
    if not fSelectedObject.MeshList.DeleteMesh(Index - 1) then Exit;
    fSelectedObject.MeshList.InsertMesh(Index - 1, MeshA);
    MeshA := nil;
    fSelectedObject.MeshList.InsertMesh(Index, MeshB);
    MeshB := nil;
    fSelectedObject.NotifyChange;
    RefreshMeshList;
    lbMeshes.ItemIndex := Index - 1;
    lbMeshesClick(Self);
  finally
    MeshA.Free;
    MeshB.Free;
  end;
end;

procedure TMainForm.spbDownMeshClick(Sender: TObject);
var
  Index: Integer;
  MeshA, MeshB: TMesh;
begin
  if (fSelectedObject = nil) or (lbMeshes.ItemIndex < 0) or
     (lbMeshes.ItemIndex >= fSelectedObject.MeshList.Count - 1) then
    Exit;

  Index := lbMeshes.ItemIndex;
  MeshA := CloneMeshForListMove(fSelectedObject.MeshList.Item[Index]);
  MeshB := CloneMeshForListMove(fSelectedObject.MeshList.Item[Index + 1]);
  try
    if (MeshA = nil) or (MeshB = nil) then
      Exit;
    if not fSelectedObject.MeshList.DeleteMesh(Index + 1) then Exit;
    if not fSelectedObject.MeshList.DeleteMesh(Index) then Exit;
    fSelectedObject.MeshList.InsertMesh(Index, MeshB);
    MeshB := nil;
    fSelectedObject.MeshList.InsertMesh(Index + 1, MeshA);
    MeshA := nil;
    fSelectedObject.NotifyChange;
    RefreshMeshList;
    lbMeshes.ItemIndex := Index + 1;
    lbMeshesClick(Self);
  finally
    MeshA.Free;
    MeshB.Free;
  end;
end;

procedure TMainForm.spbLoadMeshClick(Sender: TObject);
var
  I: Integer;
  Dlg: TOpenDialog;
begin
  if fSelectedObject = nil then
    Exit;

  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.InitialDir := ExtractFilePath(Application.ExeName);
    Dlg.Filter := 'Mesh files|*.obj;*.mesh;*.meshes|All files|*.*';
    if not Dlg.Execute then
      Exit;

    ActivateMainRenderContext;
    fSelectedObject.MeshList.LoadFromFile(Dlg.FileName);
    for I := 0 to fSelectedObject.MeshList.Count - 1 do
    begin
      fSelectedObject.MeshList.Item[I].MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
      if (MaterialLibraries.MaterialLibrary[0] <> nil) and (MaterialLibraries.MaterialLibrary[0].Count > 0) then
        fSelectedObject.MeshList.Item[I].LibMaterialname := DefaultRenderableMaterialName;
      fSelectedObject.MeshList.Item[I].OnRender := MeshRenderHandler;
    end;
  finally
    Dlg.Free;
  end;

  fSelectedObject.UpdateBoundingRadiusFromMesh;
  fSelectedObject.NotifyChange;
  RefreshMeshList;
  if lbMeshes.Items.Count > 0 then
  begin
    lbMeshes.ItemIndex := 0;
    lbMeshesClick(Self);
  end;
  UpdateSceneStatusBar;
end;

procedure TMainForm.spbMoveClick(Sender: TObject);
begin
  fGizmoMode := gmTranslate;
  SyncGizmoModeButtons;
  RefreshGizmo;
end;

procedure TMainForm.spbOpenSceneClick(Sender: TObject);
var
  Stream: TFileStream;
begin
  if fSimulatePhysics then
    Exit;

  ConfigureSceneDialogs;
  if not OpenSceneDialog.Execute then
    Exit;

  try
    PrepareSceneReplacement;

    Stream := TFileStream.Create(OpenSceneDialog.FileName, fmOpenRead or fmShareDenyWrite);
    try
      ActivateMainRenderContext;
      fSceneManager.LoadFromStream(Stream);
      LoadSceneMaterialsForFile(OpenSceneDialog.FileName);
      RestoreLoadedSceneRuntimeState;
      LoadPhysicsStatesFromStream(Stream);
      if Assigned(fScriptManager) then
        fScriptManager.TryLoadFromStream(Stream);
    finally
      Stream.Free;
    end;

    fCurrentSceneFileName := OpenSceneDialog.FileName;
    SaveSceneDialog.FileName := fCurrentSceneFileName;
    RememberSavedSceneSnapshot;
    UpdateSceneStatusBar;
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Scene loaded: ' + OpenSceneDialog.FileName);
  except
    on E: Exception do
    begin
      PopulateTreeView;
      UpdateUI;
      fRenderer.Render;
      ShowMessage(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Could not open scene: ' + E.Message);
    end;
  end;
end;

procedure TMainForm.spbRotateClick(Sender: TObject);
begin
  fGizmoMode := gmRotate;
  SyncGizmoModeButtons;
  RefreshGizmo;
end;

procedure TMainForm.spbNewSceneClick(Sender: TObject);
begin
  if fSimulatePhysics then
    Exit;

  if not ConfirmSaveDirtyScene then
    Exit;

  NewScene;
end;

procedure TMainForm.spbSaveSceneClick(Sender: TObject);
begin
  SaveCurrentScene(False);
end;

procedure TMainForm.spbSaveAsSceneClick(Sender: TObject);
begin
  SaveCurrentScene(True);
end;

procedure TMainForm.spbScaleClick(Sender: TObject);
begin
  fGizmoMode := gmScale;
  SyncGizmoModeButtons;
  RefreshGizmo;
end;

procedure TMainForm.MeshNewEmptyClick(Sender: TObject);
var
  Vertices: TArray<TVertex>;
  Indices: TArray<GLuint>;
begin
  SetLength(Vertices, 0);
  SetLength(Indices, 0);
  ActivateMainRenderContext;
  AddCreatedMesh(TMeshFactory.CreateMesh(Vertices, Indices, GenMeshName('Empty_'), mtEmpty, False));
end;

procedure TMainForm.MeshNewPlaneClick(Sender: TObject);
var
  tmpMesh: TMesh;
begin
  EnsureMeshCreatorForm;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreatePlane(1, 1, 1, 1, GenMeshName('Plane_'));

  frmMeshCreator.DisablePlaneEvents(True);
  frmMeshCreator.ePlaneWidth.Text := '1.00';
  frmMeshCreator.ePlaneDepth.Text := '1.00';
  frmMeshCreator.ePlaneWidthSegments.Text := '1';
  frmMeshCreator.ePlaneDepthSegments.Text := '1';
  frmMeshCreator.ePlaneName.Text := tmpMesh.Name;
  frmMeshCreator.DisablePlaneEvents(False);

  ShowMeshCreatorForNewMesh(tmpMesh, 'Create Plane', frmMeshCreator.pnlNewPlaneMesh);
end;

procedure TMainForm.MeshNewCubeClick(Sender: TObject);
var
  tmpMesh: TMesh;
begin
  EnsureMeshCreatorForm;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateCube(1, 1, 1, 1, 1, 1, GenMeshName('Cube_'));

  frmMeshCreator.DisableCubeEvents(True);
  frmMeshCreator.eCubeWidth.Text := '1.00';
  frmMeshCreator.eCubeHeight.Text := '1.00';
  frmMeshCreator.eCubeDepth.Text := '1.00';
  frmMeshCreator.eCubeWidthSegments.Text := '1';
  frmMeshCreator.eCubeHeightSegments.Text := '1';
  frmMeshCreator.eCubeDepthSegments.Text := '1';
  frmMeshCreator.eCubeName.Text := tmpMesh.Name;
  frmMeshCreator.DisableCubeEvents(False);

  ShowMeshCreatorForNewMesh(tmpMesh, 'Create Cube', frmMeshCreator.pnlNewCubeMesh);
end;

procedure TMainForm.MeshNewSphereClick(Sender: TObject);
var
  tmpMesh: TMesh;
begin
  EnsureMeshCreatorForm;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateSphere(0.5, 18, 18, GenMeshName('Sphere_'));

  frmMeshCreator.DisableSphereEvents(True);
  frmMeshCreator.eSphereRadius.Text := '0.50';
  frmMeshCreator.eSphereStackCount.Text := '18';
  frmMeshCreator.eSphereSliceCount.Text := '18';
  frmMeshCreator.eSphereName.Text := tmpMesh.Name;
  frmMeshCreator.DisableSphereEvents(False);

  ShowMeshCreatorForNewMesh(tmpMesh, 'Create Sphere', frmMeshCreator.pnlNewSphereMesh);
end;

procedure TMainForm.MeshNewCylinderClick(Sender: TObject);
var
  tmpMesh: TMesh;
begin
  EnsureMeshCreatorForm;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateCylinder(0.5, 1.0, 12, 12, GenMeshName('Cylinder_'));

  frmMeshCreator.DisableCylinderEvents(True);
  frmMeshCreator.eCylinderRadius.Text := '0.50';
  frmMeshCreator.eCylinderHeight.Text := '1.00';
  frmMeshCreator.eCylinderStacks.Text := '12';
  frmMeshCreator.eCylinderSlices.Text := '12';
  frmMeshCreator.eCylinderName.Text := tmpMesh.Name;
  frmMeshCreator.DisableCylinderEvents(False);

  ShowMeshCreatorForNewMesh(tmpMesh, 'Create Cylinder', frmMeshCreator.pnlNewCylinderMesh);
end;

procedure TMainForm.MeshNewCapsuleClick(Sender: TObject);
var
  tmpMesh: TMesh;
begin
  EnsureMeshCreatorForm;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateCapsule(0.5, 0.5, 12, 12, GenMeshName('Capsule_'));

  frmMeshCreator.DisableCapsuleEvents(True);
  frmMeshCreator.eCapsuleRadius.Text := '0.50';
  frmMeshCreator.eCapsuleHeight.Text := '0.50';
  frmMeshCreator.eCapsuleStacks.Text := '12';
  frmMeshCreator.eCapsuleSlices.Text := '12';
  frmMeshCreator.eCapsuleName.Text := tmpMesh.Name;
  frmMeshCreator.DisableCapsuleEvents(False);

  ShowMeshCreatorForNewMesh(tmpMesh, 'Create Capsule', frmMeshCreator.pnlNewCapsuleMesh);
end;

procedure TMainForm.MeshNewTorusClick(Sender: TObject);
var
  tmpMesh: TMesh;
begin
  EnsureMeshCreatorForm;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateTorus(0.5, 0.2, 18, 12, GenMeshName('Torus_'));

  frmMeshCreator.DisableTorusEvents(True);
  frmMeshCreator.eTorusMajorRadius.Text := '0.50';
  frmMeshCreator.eTorusMinorRadius.Text := '0.20';
  frmMeshCreator.eTorusMajorSegments.Text := '18';
  frmMeshCreator.eTorusMinorSegments.Text := '12';
  frmMeshCreator.eTorusName.Text := tmpMesh.Name;
  frmMeshCreator.DisableTorusEvents(False);

  ShowMeshCreatorForNewMesh(tmpMesh, 'Create Torus', frmMeshCreator.pnlNewTorusMesh);
end;

procedure TMainForm.MeshNewConeClick(Sender: TObject);
var
  tmpMesh: TMesh;
begin
  EnsureMeshCreatorForm;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateCone(0.5, 1, 12, 1, GenMeshName('Cone_'));

  frmMeshCreator.DisableConeEvents(True);
  frmMeshCreator.eConeRadius.Text := '0.50';
  frmMeshCreator.eConeHeight.Text := '1.00';
  frmMeshCreator.eConeSides.Text := '12';
  frmMeshCreator.eConeStacks.Text := '1';
  frmMeshCreator.eConeName.Text := tmpMesh.Name;
  frmMeshCreator.DisableConeEvents(False);

  ShowMeshCreatorForNewMesh(tmpMesh, 'Create Cone', frmMeshCreator.pnlNewConeMesh);
end;

procedure TMainForm.MeshNewPrismClick(Sender: TObject);
var
  tmpMesh: TMesh;
begin
  EnsureMeshCreatorForm;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreatePrism(0.5, 1, 3, 1, GenMeshName('Prism_'));

  frmMeshCreator.DisablePrismEvents(True);
  frmMeshCreator.ePrismRadius.Text := '0.50';
  frmMeshCreator.ePrismHeight.Text := '1.00';
  frmMeshCreator.ePrismSides.Text := '3';
  frmMeshCreator.ePrismStacks.Text := '1';
  frmMeshCreator.ePrismName.Text := tmpMesh.Name;
  frmMeshCreator.DisablePrismEvents(False);

  ShowMeshCreatorForNewMesh(tmpMesh, 'Create Prism', frmMeshCreator.pnlNewPrismMesh);
end;

procedure TMainForm.MeshNewPyramidClick(Sender: TObject);
var
  tmpMesh: TMesh;
begin
  EnsureMeshCreatorForm;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateCone(0.5, 1, 4, 1, GenMeshName('Pyramid_'));

  frmMeshCreator.DisableConeEvents(True);
  frmMeshCreator.eConeRadius.Text := '0.50';
  frmMeshCreator.eConeHeight.Text := '1.00';
  frmMeshCreator.eConeSides.Text := '4';
  frmMeshCreator.eConeStacks.Text := '1';
  frmMeshCreator.eConeName.Text := tmpMesh.Name;
  frmMeshCreator.DisableConeEvents(False);

  ShowMeshCreatorForNewMesh(tmpMesh, 'Create Pyramid', frmMeshCreator.pnlNewConeMesh);
end;

procedure TMainForm.MeshNewArrowClick(Sender: TObject);
var
  tmpMesh: TMesh;
begin
  EnsureMeshCreatorForm;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateArrow(1.0, 0.4, 0.05, 0.12, 12, 2, GenMeshName('Arrow_'));

  frmMeshCreator.DisableArrowEvents(True);
  frmMeshCreator.eArrowShaftLength.Text := '1.00';
  frmMeshCreator.eArrowTipLength.Text := '0.40';
  frmMeshCreator.eArrowShaftRadius.Text := '0.05';
  frmMeshCreator.eArrowTipRadius.Text := '0.12';
  frmMeshCreator.eArrowSlices.Text := '12';
  frmMeshCreator.eArrowStacks.Text := '2';
  frmMeshCreator.eArrowName.Text := tmpMesh.Name;
  frmMeshCreator.DisableArrowEvents(False);

  ShowMeshCreatorForNewMesh(tmpMesh, 'Create Arrow', frmMeshCreator.pnlNewArrowMesh);
end;

procedure TMainForm.MeshNewSphereEllipsoidClick(Sender: TObject);
var
  tmpMesh: TMesh;
begin
  EnsureMeshCreatorForm;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateSuperellipsoid(1.0, 1.0, 1.0, 32, 32, GenMeshName('SphereEllipsoid_'));

  frmMeshCreator.DisableSuperEllipsoidEvents(True);
  frmMeshCreator.eSuperEllipsoidRadius.Text := '1.00';
  frmMeshCreator.eSuperEllipsoidVCurve.Text := '1.00';
  frmMeshCreator.eSuperEllipsoidHCurve.Text := '1.00';
  frmMeshCreator.eSuperEllipsoidSlices.Text := '32';
  frmMeshCreator.eSuperEllipsoidStacks.Text := '32';
  frmMeshCreator.eSuperEllipsoidName.Text := tmpMesh.Name;
  frmMeshCreator.DisableSuperEllipsoidEvents(False);

  ShowMeshCreatorForNewMesh(tmpMesh, 'Create Sphere Ellipsoid', frmMeshCreator.pnlNewSuperEllipsoidMesh);
end;

procedure TMainForm.MeshNewCylinderEllipsoidClick(Sender: TObject);
var
  tmpMesh: TMesh;
begin
  EnsureMeshCreatorForm;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateSuperellipsoid(1.0, 0.5, 1.0, 32, 32, GenMeshName('CylinderEllipsoid_'));

  frmMeshCreator.DisableSuperEllipsoidEvents(True);
  frmMeshCreator.eSuperEllipsoidRadius.Text := '1.00';
  frmMeshCreator.eSuperEllipsoidVCurve.Text := '0.50';
  frmMeshCreator.eSuperEllipsoidHCurve.Text := '1.00';
  frmMeshCreator.eSuperEllipsoidSlices.Text := '32';
  frmMeshCreator.eSuperEllipsoidStacks.Text := '32';
  frmMeshCreator.eSuperEllipsoidName.Text := tmpMesh.Name;
  frmMeshCreator.DisableSuperEllipsoidEvents(False);

  ShowMeshCreatorForNewMesh(tmpMesh, 'Create Cylinder Ellipsoid', frmMeshCreator.pnlNewSuperEllipsoidMesh);
end;

procedure TMainForm.MeshNewCubeEllipsoidClick(Sender: TObject);
var
  tmpMesh: TMesh;
begin
  EnsureMeshCreatorForm;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateSuperellipsoid(1.0, 0.3, 0.3, 32, 32, GenMeshName('CubeEllipsoid_'));

  frmMeshCreator.DisableSuperEllipsoidEvents(True);
  frmMeshCreator.eSuperEllipsoidRadius.Text := '1.00';
  frmMeshCreator.eSuperEllipsoidVCurve.Text := '0.30';
  frmMeshCreator.eSuperEllipsoidHCurve.Text := '0.30';
  frmMeshCreator.eSuperEllipsoidSlices.Text := '32';
  frmMeshCreator.eSuperEllipsoidStacks.Text := '32';
  frmMeshCreator.eSuperEllipsoidName.Text := tmpMesh.Name;
  frmMeshCreator.DisableSuperEllipsoidEvents(False);

  ShowMeshCreatorForNewMesh(tmpMesh, 'Create Cube Ellipsoid', frmMeshCreator.pnlNewSuperEllipsoidMesh);
end;

procedure TMainForm.MeshNewStarEllipsoidClick(Sender: TObject);
var
  tmpMesh: TMesh;
begin
  EnsureMeshCreatorForm;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateSuperellipsoid(1.0, 3.0, 3.0, 32, 32, GenMeshName('StarEllipsoid_'));

  frmMeshCreator.DisableSuperEllipsoidEvents(True);
  frmMeshCreator.eSuperEllipsoidRadius.Text := '1.00';
  frmMeshCreator.eSuperEllipsoidVCurve.Text := '3.00';
  frmMeshCreator.eSuperEllipsoidHCurve.Text := '3.00';
  frmMeshCreator.eSuperEllipsoidSlices.Text := '32';
  frmMeshCreator.eSuperEllipsoidStacks.Text := '32';
  frmMeshCreator.eSuperEllipsoidName.Text := tmpMesh.Name;
  frmMeshCreator.DisableSuperEllipsoidEvents(False);

  ShowMeshCreatorForNewMesh(tmpMesh, 'Create Star Ellipsoid', frmMeshCreator.pnlNewSuperEllipsoidMesh);
end;

procedure TMainForm.MeshNewPillEllipsoidClick(Sender: TObject);
var
  tmpMesh: TMesh;
begin
  EnsureMeshCreatorForm;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateSuperellipsoid(1.0, 1.0, 0.5, 32, 32, GenMeshName('PillEllipsoid_'));

  frmMeshCreator.DisableSuperEllipsoidEvents(True);
  frmMeshCreator.eSuperEllipsoidRadius.Text := '1.00';
  frmMeshCreator.eSuperEllipsoidVCurve.Text := '1.00';
  frmMeshCreator.eSuperEllipsoidHCurve.Text := '0.50';
  frmMeshCreator.eSuperEllipsoidSlices.Text := '32';
  frmMeshCreator.eSuperEllipsoidStacks.Text := '32';
  frmMeshCreator.eSuperEllipsoidName.Text := tmpMesh.Name;
  frmMeshCreator.DisableSuperEllipsoidEvents(False);

  ShowMeshCreatorForNewMesh(tmpMesh, 'Create Pill Ellipsoid', frmMeshCreator.pnlNewSuperEllipsoidMesh);
end;

procedure TMainForm.MeshNewIcosphereClick(Sender: TObject);
var
  tmpMesh: TMesh;
begin
  EnsureMeshCreatorForm;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateIcosphere(1.0, 2, GenMeshName('Icosphere_'));

  frmMeshCreator.DisableIcosphereEvents(True);
  frmMeshCreator.eIcosphereRadius.Text := '1.00';
  frmMeshCreator.eIcosphereSubdivisions.Text := '2';
  frmMeshCreator.eIcosphereName.Text := tmpMesh.Name;
  frmMeshCreator.DisableIcosphereEvents(False);

  ShowMeshCreatorForNewMesh(tmpMesh, 'Create Icosphere', frmMeshCreator.pnlNewIcosphereMesh);
end;

procedure TMainForm.MeshNewGeodesicDomeClick(Sender: TObject);
var
  tmpMesh: TMesh;
begin
  EnsureMeshCreatorForm;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateGeodesicDome(1.0, 2, GenMeshName('GeodesicDome_'));

  frmMeshCreator.DisableGeodesicDomeEvents(True);
  frmMeshCreator.eGeodesicDomeRadius.Text := '1.00';
  frmMeshCreator.eGeodesicDomeSubdivisions.Text := '2';
  frmMeshCreator.eGeodesicDomeName.Text := tmpMesh.Name;
  frmMeshCreator.DisableGeodesicDomeEvents(False);

  ShowMeshCreatorForNewMesh(tmpMesh, 'Create Geodesic Dome', frmMeshCreator.pnlNewGeodesicDomeMesh);
end;

procedure TMainForm.ReadPhysicsBody(Body: TPhysicsBody);
begin
  fPhysicsBody := Body;
  RefreshPhysicsControls;
end;

procedure TMainForm.ResetPhysicsControls;
begin
  fPhysicsBody := nil;
  fSuppressPhysicsControls := True;
  try
    cpPhysics.Enabled := False;
    cbBodyType.ItemIndex := Ord(pbtStatic);
    cbColliderKind.ItemIndex := Ord(pckAuto);
    chbEnabled.Checked := False;
    chbCollisionResponse.Checked := True;
    chbUseGravity.Checked := True;
    eMass.Text := '1.00';
    lblInverseMassInfo.Caption := '0.00';
    eRestitution.Text := '0.35';
    eLinearDamping.Text := '0.98';
    eGravityScale.Text := '1.00';
    eVelocityX.Text := '0.00';
    eVelocityY.Text := '0.00';
    eVelocityZ.Text := '0.00';
    eAngularVelocityX.Text := '0';
    eAngularVelocityY.Text := '0';
    eAngularVelocityZ.Text := '0';
    eAngularDamping.Text := '1.00';
    eRadius.Text := '0.50';
    eHalfHeight.Text := '0.80';
    eAABBHalfExtentsX.Text := '0.50';
    eAABBHalfExtentsY.Text := '0.50';
    eAABBHalfExtentsZ.Text := '0.50';
    eStepHeight.Text := '0.35';
  finally
    fSuppressPhysicsControls := False;
  end;
end;

procedure TMainForm.RefreshPhysicsControls;
var
  State: TPhysicsBodyState;
begin
  if fSuppressPhysicsControls then
    Exit;

  if not Assigned(fPhysicsBody) then
  begin
    ResetPhysicsControls;
    Exit;
  end;

  fSuppressPhysicsControls := True;
  try
    if (not Assigned(fPhysicsWorld)) or
       (not fPhysicsWorld.TryGetStagedBodyState(fPhysicsBody.SceneObject, State)) then
      State := fPhysicsBody.GetState;

    cpPhysics.Enabled := True;
    cbBodyType.ItemIndex := Ord(State.BodyType);
    cbColliderKind.ItemIndex := Ord(State.ColliderKind);
    chbEnabled.Checked := State.Enabled;
    chbCollisionResponse.Checked := State.CollisionResponse;
    chbUseGravity.Checked := State.UseGravity;
    eMass.Text := EditorFloatToText(State.Mass);
    lblInverseMassInfo.Caption := EditorFloatToText(PhysicsInverseMassForState(State));
    eRestitution.Text := EditorFloatToText(State.Restitution);
    eLinearDamping.Text := EditorFloatToText(State.LinearDamping);
    eGravityScale.Text := EditorFloatToText(State.GravityScale);
    eVelocityX.Text := EditorFloatToText(State.Velocity.X);
    eVelocityY.Text := EditorFloatToText(State.Velocity.Y);
    eVelocityZ.Text := EditorFloatToText(State.Velocity.Z);
    eAngularVelocityX.Text := EditorFloatToText(State.AngularVelocity.X);
    eAngularVelocityY.Text := EditorFloatToText(State.AngularVelocity.Y);
    eAngularVelocityZ.Text := EditorFloatToText(State.AngularVelocity.Z);
    eAngularDamping.Text := EditorFloatToText(State.AngularDamping);
    eRadius.Text := EditorFloatToText(State.Radius);
    eHalfHeight.Text := EditorFloatToText(State.HalfHeight);
    eAABBHalfExtentsX.Text := EditorFloatToText(State.AABBHalfExtents.X);
    eAABBHalfExtentsY.Text := EditorFloatToText(State.AABBHalfExtents.Y);
    eAABBHalfExtentsZ.Text := EditorFloatToText(State.AABBHalfExtents.Z);
    eStepHeight.Text := EditorFloatToText(State.StepHeight);
  finally
    fSuppressPhysicsControls := False;
  end;
end;

function TMainForm.ApplyPhysicsControlsToBody: Boolean;
var
  BodyTypeIndex, ColliderIndex: Integer;
  Mass, Restitution, LinearDamping, GravityScale: Single;
  VelocityX, VelocityY, VelocityZ: Single;
  AngularVelocityX, AngularVelocityY, AngularVelocityZ: Single;
  AngularDamping: Single;
  Radius, HalfHeight: Single;
  AABBX, AABBY, AABBZ: Single;
  StepHeight: Single;
  State: TPhysicsBodyState;
begin
  Result := False;
  if not Assigned(fPhysicsBody) then
    Exit;

  BodyTypeIndex := cbBodyType.ItemIndex;
  if BodyTypeIndex < 0 then
    BodyTypeIndex := Ord(pbtStatic);
  ColliderIndex := cbColliderKind.ItemIndex;
  if ColliderIndex < 0 then
    ColliderIndex := Ord(pckAuto);

  if not TryReadEditorFloat(eMass, 'Mass', Mass) then Exit;
  if not TryReadEditorFloat(eRestitution, 'Restitution', Restitution) then Exit;
  if not TryReadEditorFloat(eLinearDamping, 'Linear damping', LinearDamping) then Exit;
  if not TryReadEditorFloat(eGravityScale, 'Gravity scale', GravityScale) then Exit;
  if not TryReadEditorFloat(eVelocityX, 'Velocity X', VelocityX) then Exit;
  if not TryReadEditorFloat(eVelocityY, 'Velocity Y', VelocityY) then Exit;
  if not TryReadEditorFloat(eVelocityZ, 'Velocity Z', VelocityZ) then Exit;
  if not TryReadEditorFloat(eAngularVelocityX, 'AngularVelocity X', AngularVelocityX) then Exit;
  if not TryReadEditorFloat(eAngularVelocityY, 'AngularVelocity Y', AngularVelocityY) then Exit;
  if not TryReadEditorFloat(eAngularVelocityZ, 'AngularVelocity Z', AngularVelocityZ) then Exit;
  if not TryReadEditorFloat(eAngularDamping, 'Angular Damping', AngularDamping) then Exit;
  if not TryReadEditorFloat(eRadius, 'Radius', Radius) then Exit;
  if not TryReadEditorFloat(eHalfHeight, 'Half height', HalfHeight) then Exit;
  if not TryReadEditorFloat(eAABBHalfExtentsX, 'AABB half extents X', AABBX) then Exit;
  if not TryReadEditorFloat(eAABBHalfExtentsY, 'AABB half extents Y', AABBY) then Exit;
  if not TryReadEditorFloat(eAABBHalfExtentsZ, 'AABB half extents Z', AABBZ) then Exit;
  if not TryReadEditorFloat(eStepHeight, 'Step height', StepHeight) then Exit;

  if (not Assigned(fPhysicsWorld)) or
     (not fPhysicsWorld.TryGetStagedBodyState(fPhysicsBody.SceneObject, State)) then
    State := fPhysicsBody.GetState;

  State.BodyType := TPhysicsBodyType(BodyTypeIndex);
  State.ColliderKind := TPhysicsColliderKind(ColliderIndex);
  State.Enabled := chbEnabled.Checked;
  State.CollisionResponse := chbCollisionResponse.Checked;
  State.UseGravity := chbUseGravity.Checked;
  State.Mass := System.Math.Max(0.0, Mass);
  State.Restitution := System.Math.Max(0.0, Restitution);
  State.LinearDamping := System.Math.EnsureRange(LinearDamping, 0.0, 1.0);
  State.GravityScale := GravityScale;
  State.Velocity := Vector3(VelocityX, VelocityY, VelocityZ);
  State.AngularVelocity := Vector3(AngularVelocityX, AngularVelocityY, AngularVelocityZ);
  State.AngularDamping := AngularDamping;
  State.Radius := System.Math.Max(0.01, Radius);
  State.HalfHeight := System.Math.Max(0.01, HalfHeight);
  State.AABBHalfExtents := Vector3(
    System.Math.Max(0.01, AABBX),
    System.Math.Max(0.01, AABBY),
    System.Math.Max(0.01, AABBZ));
  State.StepHeight := System.Math.Max(0.0, StepHeight);

  if Assigned(fPhysicsWorld) then
    fPhysicsWorld.StageBodyState(fPhysicsBody.SceneObject, State)
  else
    fPhysicsBody.ApplyState(State);

  Result := True;
end;

function TMainForm.CloneMeshForListMove(Source: TMesh): TMesh;
begin
  Result := nil;

  if Source = nil then
    Exit;

  Result := Source.Clone;
  Result.Name := Source.Name;
  Result.MaterialLibrary := Source.MaterialLibrary;
  Result.LibMaterialname := Source.LibMaterialname;
  Result.OnRender := Source.OnRender;
  Result.WireFrame := Source.WireFrame;
  Result.AlwaysOnTop := Source.AlwaysOnTop;
  Result.Visible := Source.Visible;
  Result.Tag := Source.Tag;
  Result.ParentModelMatrix := Source.ParentModelMatrix;
end;

function TMainForm.CommitPhysicsChanges: Boolean;
begin
  Result := ApplyPhysicsControlsToBody;
  if Result then
    RefreshPhysicsControls;
end;

procedure TMainForm.btnApplyClick(Sender: TObject);
begin
  CommitPhysicsChanges;
end;

procedure TMainForm.btnCancelClick(Sender: TObject);
begin
  if Assigned(fPhysicsWorld) and fPhysicsWorld.HasTransformBackup then
    fPhysicsWorld.RestoreSceneTransforms(False);
  RefreshPhysicsControls;
end;

{ TForm1 }
procedure TMainForm.PrepareSceneReplacement;
begin
  if Assigned(fCurrentGizmo) then
    FreeAndNil(fCurrentGizmo);
  ClearPhysicsDebugHull;

  fSelectedObject := nil;
  fSelectedMesh := nil;
  fPhysicsBody := nil;
  fLastPickedMeshIndex := -1;
  fNewObjectMode := False;
  fDraggingGizmo := False;
  fHoveredAxis := -1;
  RefreshSelectedBoundingBox;
  ClearClipboard;
  ResetMeshEditor;

  if Assigned(fPhysicsWorld) then
    fPhysicsWorld.Clear;
  if Assigned(fScriptManager) then
    fScriptManager.Clear;
end;

procedure TMainForm.CreateDefaulTSceneObjects;
var
  Dir: TVector3;
  Ratio: Single;
begin
  fSceneWorld := TSceneObject.Create(fRoot);
  fSceneWorld.Name := 'Scene';

  fLight := TSceneObject.Create(fRoot);
  fLight.Name := 'Light_1';
  fLight.CreateLight;
  fLight.Position := Vector3(10, 10.0, 10.0);
  fLight.Rotation := Vector3(DegToRad(-45), DegToRad(35), 0);

  fLight.Light[0].LightType := ltDirectional;
  fLight.Light[0].UseTarget := True;
  fLight.Light[0].TargetPosition := Vector3(0, 0, 0);
  fLight.Light[0].CastShadows := True;
  fLight.Light[0].ShadowStrength := 0.9;
  fLight.Light[0].Diffuse := Vector3(3.0, 3.0, 3.0);
  fLight.Light[0].Ambient := Vector3(0.025, 0.025, 0.025);
  fLight.Light[0].Specular := Vector3(1.0, 1.0, 1.0);

  fCameraUp := Vector3(0, -1, 0);
  fCamera := TSceneObject.Create(fRoot);
  fCamera.Name := 'Camera';
  fCamera.CreateCamera;
  fCamera.Camera.LookAt(Vector3(0, 0, -11), Vector3(0, 0, 0), fCameraUp);
  fRenderer.ActiveCamera := fCamera;

  fOrbitTarget := Vector3(0, 0, 0);
  fRenderer.ShadowLight := fLight;
  fRenderer.ShadowTarget := fOrbitTarget;
  fRenderer.ShadowDistance := 35.0;
  fRenderer.ShadowArea := 32.0;
  fRenderer.ShadowEnabled := True;

  Dir := fCamera.Camera.Position - fOrbitTarget;
  fCurrentRadius := Dir.Length;
  if fCurrentRadius < 0.001 then
    fCurrentRadius := 0.001;
  fTargetRadius := fCurrentRadius;
  fCurrentAzimuth := System.Math.ArcTan2(Dir.Z, Dir.X);
  fTargetAzimuth := fCurrentAzimuth;
  Ratio := System.Math.EnsureRange(Dir.Y / fCurrentRadius, -1.0, 1.0);
  fCurrentPolar := System.Math.ArcCos(Ratio);
  fTargetPolar := fCurrentPolar;
end;

procedure TMainForm.NewScene;
var
  NewRoot: TSceneObject;
begin
  PrepareSceneReplacement;
  EnsureGizmoMaterial;

  NewRoot := TSceneObject.Create(nil);
  NewRoot.Name := 'ROOT';
  fSceneManager.Root := NewRoot;
  fRoot := fSceneManager.Root;

  CreateDefaulTSceneObjects;
  RestoreLoadedSceneRuntimeState;

  fCurrentSceneFileName := '';
  SaveSceneDialog.FileName := 'Scene.omes';
  RememberSavedSceneSnapshot;
  UpdateSceneStatusBar;

  mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'New scene created.');
end;

function TMainForm.CaptureSceneSnapshot(out Snapshot: TBytes): Boolean;
var
  Stream: TMemoryStream;
begin
  Result := False;
  SetLength(Snapshot, 0);

  if (fSceneManager = nil) or (MaterialLibraries = nil) then
    Exit;

  Stream := TMemoryStream.Create;
  try
    EnsureGizmoMaterial;
    fSceneManager.SaveToStream(Stream);
    MaterialLibraries.SaveToStream(Stream, GIZMO_MATERIAL_NAME);
    SavePhysicsStatesToStream(Stream);
    if Assigned(fScriptManager) then
      fScriptManager.SaveToStream(Stream);

    if Stream.Size > MaxInt then
      Exit;

    SetLength(Snapshot, Integer(Stream.Size));
    if Length(Snapshot) > 0 then
    begin
      Stream.Position := 0;
      Stream.ReadBuffer(Snapshot[0], Length(Snapshot));
    end;
    Result := True;
  finally
    Stream.Free;
  end;
end;

procedure TMainForm.RememberSavedSceneSnapshot;
begin
  if not CaptureSceneSnapshot(fSavedSceneSnapshot) then
    SetLength(fSavedSceneSnapshot, 0);
end;

function TMainForm.SceneHasUnsavedChanges: Boolean;
var
  CurrentSnapshot: TBytes;
begin
  Result := False;
  if not CaptureSceneSnapshot(CurrentSnapshot) then
    Exit;

  if Length(CurrentSnapshot) <> Length(fSavedSceneSnapshot) then
    Exit(True);

  if Length(CurrentSnapshot) = 0 then
    Exit(False);

  Result := not CompareMem(@CurrentSnapshot[0], @fSavedSceneSnapshot[0],
    Length(CurrentSnapshot));
end;

function TMainForm.SaveSceneToFile(const AFileName: string): Boolean;
var
  Stream: TFileStream;
  FileName: string;
begin
  Result := False;
  FileName := AFileName;
  if ExtractFileExt(FileName) = '' then
    FileName := ChangeFileExt(FileName, '.omes');

  try
    EnsureGizmoMaterial;
    Stream := TFileStream.Create(FileName, fmCreate);
    try
      fSceneManager.SaveToStream(Stream);
      SavePhysicsStatesToStream(Stream);
      if Assigned(fScriptManager) then
        fScriptManager.SaveToStream(Stream);
    finally
      Stream.Free;
    end;

    SaveSceneMaterialsToFiles(FileName);

    fCurrentSceneFileName := FileName;
    SaveSceneDialog.FileName := FileName;
    RememberSavedSceneSnapshot;
    UpdateSceneStatusBar;
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Scene saved: ' + FileName);
    Result := True;
  except
    on E: Exception do
      ShowMessage(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Could not save scene: ' + E.Message);
  end;
end;

function TMainForm.SaveCurrentScene(ForceDialog: Boolean): Boolean;
var
  FileName: string;
begin
  Result := False;
  if fSimulatePhysics then
    Exit;

  ConfigureSceneDialogs;

  if Assigned(fPhysicsBody) and (not CommitPhysicsChanges) then
    Exit;

  FileName := fCurrentSceneFileName;
  if ForceDialog or (FileName = '') then
  begin
    if FileName <> '' then
      SaveSceneDialog.FileName := FileName;
    if not SaveSceneDialog.Execute then
      Exit;
    FileName := SaveSceneDialog.FileName;
  end;

  Result := SaveSceneToFile(FileName);
end;

function TMainForm.ConfirmSaveDirtyScene: Boolean;
begin
  Result := True;
  if not SceneHasUnsavedChanges then
    Exit;

  case MessageDlg('Save changes to the current scene before creating a new scene?',
    mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
    mrYes:
      Result := SaveCurrentScene(False);
    mrNo:
      Result := True;
  else
  end;
end;

function TMainForm.SceneDirectory: string;
begin
  //Result := IncludeTrailingPathDelimiter(PATH + 'Data\Scenes');
  Result := TEnginePaths.ScenesDir;
end;

procedure TMainForm.ConfigureSceneDialogs;
var
  Dir: string;
begin
  Dir := SceneDirectory;
  ForceDirectories(Dir);

  SaveSceneDialog.InitialDir := Dir;
  SaveSceneDialog.DefaultExt := 'omes';
  SaveSceneDialog.Filter := 'OpenGL Micro Engine Scene (*.omes)|*.omes|All files (*.*)|*.*';
  SaveSceneDialog.Options := SaveSceneDialog.Options + [ofOverwritePrompt, ofPathMustExist];
  if SaveSceneDialog.FileName = '' then
    SaveSceneDialog.FileName := 'Scene.omes';

  OpenSceneDialog.InitialDir := Dir;
  OpenSceneDialog.DefaultExt := 'omes';
  OpenSceneDialog.Filter := SaveSceneDialog.Filter;
  OpenSceneDialog.Options := OpenSceneDialog.Options + [ofFileMustExist, ofPathMustExist];
end;

function TMainForm.MaterialDirectory: string;
begin
  //Result := IncludeTrailingPathDelimiter(PATH + 'Data\Materials');
  Result := TEnginePaths.MaterialsDir;
end;

procedure TMainForm.ConfigureMaterialDialogs;
var
  Dir: string;
begin
  Dir := MaterialDirectory;
  ForceDirectories(Dir);

  OpenMaterialsDialog.InitialDir := Dir;
  OpenMaterialsDialog.DefaultExt := 'omeml';
  OpenMaterialsDialog.Filter :=
    'OpenGL Micro Engine Material Library (*.omeml)|*.omeml|' +
    'OpenGL Micro Engine Material (*.omemat)|*.omemat|All files (*.*)|*.*';
  OpenMaterialsDialog.Options := OpenMaterialsDialog.Options + [ofFileMustExist, ofPathMustExist];
end;

function TMainForm.FindFirstLightObject(aObject: TSceneObject; RequireShadowCaster: Boolean): TSceneObject;
var
  I: Integer;
  Light: TLight;
begin
  Result := nil;
  if aObject = nil then
    Exit;

  for I := 0 to aObject.LightsCount - 1 do
  begin
    Light := aObject.Light[I];
    if Assigned(Light) and
       ((not RequireShadowCaster) or (Light.Enabled and Light.CastShadows)) then
      Exit(aObject);
  end;

  for I := 0 to aObject.Count - 1 do
  begin
    Result := FindFirstLightObject(aObject.ObjectList[I], RequireShadowCaster);
    if Result <> nil then
      Exit;
  end;
end;

procedure TMainForm.AttachRuntimeSceneData(aObject: TSceneObject);
var
  I: Integer;
  Mesh: TMesh;
begin
  if aObject = nil then
    Exit;

  if not aObject.IsGizmo then
  begin
    for I := 0 to aObject.MeshList.Count - 1 do
    begin
      Mesh := aObject.MeshList.Item[I];
      if Mesh = nil then
        Continue;

      Mesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
      if (MaterialLibraries.MaterialLibrary[0] <> nil) and (MaterialLibraries.MaterialLibrary[0].Count > 0) then
      begin
        if (Mesh.LibMaterialname = '') or
           (MaterialLibraries.MaterialLibrary[0].GetMaterial(Mesh.LibMaterialname) = nil) then
          Mesh.LibMaterialname := DefaultRenderableMaterialName;
      end;
      Mesh.OnRender := MeshRenderHandler;
    end;
    aObject.UpdateBoundingRadiusFromMesh;
  end;

  for I := 0 to aObject.Count - 1 do
    AttachRuntimeSceneData(aObject.ObjectList[I]);
end;

procedure TMainForm.RestoreLoadedSceneRuntimeState;
var
  CameraObject: TSceneObject;
  ShadowLightObject: TSceneObject;
  Dir: TVector3;
  Ratio: Single;
begin
  fRoot := fSceneManager.Root;
  ResetPhysicsWorldForScene;
  fSceneWorld := fSceneManager.FindSceneObject('Scene');
  AttachRuntimeSceneData(fRoot);
  BindScriptManager;

  fSelectedObject := nil;
  fLastPickedMeshIndex := -1;
  fNewObjectMode := False;
  fSimulatePhysics := False;
  fPhysicsRestorePending := False;
  if Assigned(fCurrentGizmo) then
    FreeAndNil(fCurrentGizmo);

  CameraObject := fSceneManager.FindCamera;
  if CameraObject = nil then
  begin
    fCameraUp := Vector3(0, -1, 0);
    fCamera := TSceneObject.Create(fRoot);
    fCamera.Name := 'Camera';
    fCamera.CreateCamera;
    fCamera.Camera.LookAt(Vector3(0, 0, -11), Vector3(0, 0, 0), fCameraUp);
  end
  else
  begin
    fCamera := CameraObject;
    fCameraUp := fCamera.Camera.Up;
  end;
  fRenderer.ActiveCamera := fCamera;

  fLight := FindFirstLightObject(fRoot, True);
  if fLight = nil then
    fLight := FindFirstLightObject(fRoot, False);

  ShadowLightObject := FindFirstLightObject(fRoot, True);
  fRenderer.ShadowLight := ShadowLightObject;

  fOrbitTarget := fCamera.Camera.Target;
  Dir := fCamera.Camera.Position - fOrbitTarget;
  fCurrentRadius := Dir.Length;
  if fCurrentRadius < 0.001 then
    fCurrentRadius := 0.001;
  fTargetRadius := fCurrentRadius;
  fCurrentAzimuth := System.Math.ArcTan2(Dir.Z, Dir.X);
  fTargetAzimuth := fCurrentAzimuth;
  Ratio := Dir.Y / fCurrentRadius;
  Ratio := System.Math.EnsureRange(Ratio, -1.0, 1.0);
  fCurrentPolar := System.Math.ArcCos(Ratio);
  fTargetPolar := fCurrentPolar;
  fRenderer.ShadowTarget := fOrbitTarget;

  fSceneManager.Update;
  PopulateTreeView;
  ResetTransformControls;
  ResetMeshes;

  ResetPhysicsControls;
  SetPhysicsSimulationMode(False);
  fRenderer.Render;
end;

procedure TMainForm.ResetPhysicsWorldForScene;
begin
  if fPhysicsWorld = nil then
    Exit;

  fPhysicsWorld.Clear;
  fPhysicsWorld.SceneRoot := fRoot;
  fPhysicsWorld.GroundPlaneEnabled := False;
  fPhysicsWorld.GroundHeight := -1000000.0;
  EnsurePhysicsBodiesForScene(fRoot);
end;

function TMainForm.EnsurePhysicsBodyForObject(Obj: TSceneObject): TPhysicsBody;
begin
  Result := nil;
  if (fPhysicsWorld = nil) or (Obj = nil) then
    Exit;
  if Obj.IsGizmo or (Obj = fRoot) or Obj.HasCamera or (Obj.LightsCount > 0) then
    Exit;

  Result := fPhysicsWorld.FindBody(Obj);
  if Result = nil then
  begin
    Result := fPhysicsWorld.AddBody(Obj, pbtStatic, pckAuto);
    if Result <> nil then
    begin
      Result.Enabled := False;
      Result.CollisionResponse := True;
      Result.UseGravity := True;
      Result.AutoFitColliderFromScene;
    end;
  end;
  if (Result <> nil) and (Result.ColliderKind = pckAuto) then
    Result.AutoFitColliderFromScene;
end;

procedure TMainForm.EnsurePhysicsBodiesForScene(Obj: TSceneObject);
var
  I: Integer;
begin
  if Obj = nil then
    Exit;

  EnsurePhysicsBodyForObject(Obj);
  for I := 0 to Obj.Count - 1 do
    EnsurePhysicsBodiesForScene(Obj.ObjectList[I]);
end;

function TMainForm.BuildSceneObjectPath(Obj: TSceneObject): string;
var
  ParentObj, CurrentObj: TSceneObject;
  I: Integer;
  Segment: string;
begin
  Result := '';
  CurrentObj := Obj;
  while Assigned(CurrentObj) and (CurrentObj <> fRoot) do
  begin
    ParentObj := CurrentObj.Parent;
    if ParentObj = nil then
      Exit('');

    Segment := '';
    for I := 0 to ParentObj.Count - 1 do
      if ParentObj.ObjectList[I] = CurrentObj then
      begin
        Segment := IntToStr(I);
        Break;
      end;

    if Segment = '' then
      Exit('');

    if Result = '' then
      Result := Segment
    else
      Result := Segment + '/' + Result;
    CurrentObj := ParentObj;
  end;
end;

function TMainForm.FindSceneObjectByPath(const Path: string): TSceneObject;
var
  CurrentObj: TSceneObject;
  Remaining, Token: string;
  SepPos: Integer;
  Index: Integer;
begin
  Result := nil;
  if fRoot = nil then
    Exit;

  CurrentObj := fRoot;
  Remaining := Path;
  while Remaining <> '' do
  begin
    SepPos := Pos('/', Remaining);
    if SepPos > 0 then
    begin
      Token := Copy(Remaining, 1, SepPos - 1);
      Delete(Remaining, 1, SepPos);
    end
    else
    begin
      Token := Remaining;
      Remaining := '';
    end;

    Index := StrToIntDef(Token, -1);
    if (Index < 0) or (Index >= CurrentObj.Count) then
      Exit(nil);
    CurrentObj := CurrentObj.ObjectList[Index];
    if CurrentObj = nil then
      Exit(nil);
  end;

  Result := CurrentObj;
end;

procedure WritePhysicsString(Stream: TStream; const Value: string);
var
  Len: Integer;
begin
  Len := Length(Value);
  Stream.WriteBuffer(Len, SizeOf(Len));
  if Len > 0 then
    Stream.WriteBuffer(Value[1], Len * SizeOf(Char));
end;

function ReadPhysicsString(Stream: TStream): string;
var
  Len: Integer;
begin
  Stream.ReadBuffer(Len, SizeOf(Len));
  if Len < 0 then
    raise Exception.Create('Invalid physics string length in scene stream.');
  SetLength(Result, Len);
  if Len > 0 then
    Stream.ReadBuffer(Result[1], Len * SizeOf(Char));
end;

function PhysicsChunkMagicMatches(const Magic: array of AnsiChar): Boolean;
var
  I: Integer;
begin
  Result := Length(Magic) = Length(PHYSICS_SCENE_CHUNK_MAGIC);
  if not Result then
    Exit;

  for I := Low(PHYSICS_SCENE_CHUNK_MAGIC) to High(PHYSICS_SCENE_CHUNK_MAGIC) do
    if Magic[I] <> PHYSICS_SCENE_CHUNK_MAGIC[I] then
      Exit(False);
end;

procedure TMainForm.SavePhysicsStatesToStream(Stream: TStream);
var
  Entries: TList<TSceneObject>;
  Version, I, Count: Integer;
  Obj: TSceneObject;
  Body: TPhysicsBody;
  State: TPhysicsBodyState;
  Path: string;

  procedure Collect(Obj: TSceneObject);
  var
    State: TPhysicsBodyState;
    ChildIndex: Integer;
  begin
    if Obj = nil then
      Exit;

    if (not Obj.IsGizmo) and (Obj <> fRoot) and (not Obj.HasCamera) and
       (Obj.LightsCount = 0) then
    begin
      var FoundBody := fPhysicsWorld.FindBody(Obj);
      if (FoundBody <> nil) or fPhysicsWorld.TryGetStagedBodyState(Obj, State) then
        Entries.Add(Obj);
    end;

    for ChildIndex := 0 to Obj.Count - 1 do
      Collect(Obj.ObjectList[ChildIndex]);
  end;

begin
  if (Stream = nil) or (fPhysicsWorld = nil) then
    Exit;

  Entries := TList<TSceneObject>.Create;
  try
    Collect(fRoot);

    Stream.WriteBuffer(PHYSICS_SCENE_CHUNK_MAGIC[0], SizeOf(PHYSICS_SCENE_CHUNK_MAGIC));
    Version := PHYSICS_SCENE_CHUNK_VERSION;
    Stream.WriteBuffer(Version, SizeOf(Version));
    Count := Entries.Count;
    Stream.WriteBuffer(Count, SizeOf(Count));

    for I := 0 to Entries.Count - 1 do
    begin
      Obj := Entries[I];
      Body := fPhysicsWorld.FindBody(Obj);
      if (not fPhysicsWorld.TryGetStagedBodyState(Obj, State)) and (Body <> nil) then
        State := Body.GetState;

      Path := BuildSceneObjectPath(Obj);
      WritePhysicsString(Stream, Path);
      Stream.WriteBuffer(State, SizeOf(State));
    end;
  finally
    Entries.Free;
  end;
end;

procedure TMainForm.LoadPhysicsStatesFromStream(Stream: TStream);
var
  StartPos: Int64;
  Magic: array[0..7] of AnsiChar;
  Version, Count, I: Integer;
  Path: string;
  Obj: TSceneObject;
  Body: TPhysicsBody;
  State: TPhysicsBodyState;
begin
  if (Stream = nil) or (fPhysicsWorld = nil) or (Stream.Position >= Stream.Size) then
    Exit;

  StartPos := Stream.Position;
  if (Stream.Size - Stream.Position) < SizeOf(Magic) then
    Exit;

  Stream.ReadBuffer(Magic[0], SizeOf(Magic));
  if not PhysicsChunkMagicMatches(Magic) then
  begin
    Stream.Position := StartPos;
    Exit;
  end;

  Stream.ReadBuffer(Version, SizeOf(Version));
  if Version <> PHYSICS_SCENE_CHUNK_VERSION then
    raise Exception.CreateFmt('Unsupported physics scene chunk version: %d.', [Version]);

  Stream.ReadBuffer(Count, SizeOf(Count));
  if Count < 0 then
    raise Exception.Create('Invalid physics body count in scene stream.');

  for I := 0 to Count - 1 do
  begin
    Path := ReadPhysicsString(Stream);
    Stream.ReadBuffer(State, SizeOf(State));
    Obj := FindSceneObjectByPath(Path);
    if Obj = nil then
      Continue;

    Body := EnsurePhysicsBodyForObject(Obj);
    if Body <> nil then
      Body.ApplyState(State);
    fPhysicsWorld.StageBodyState(Obj, State);
  end;
end;

procedure TMainForm.SetPhysicsSimulationMode(Value: Boolean);
begin
  fSimulatePhysics := Value;
  if Value then
    fPhysicsRestorePending := False;

  pnlObjects.Enabled := not Value;
  CentralEditor.Enabled := not Value;
  //btnScriptTest.Enabled := not Value;
  spbNewScene.Enabled := not Value;
  spbSaveScene.Enabled := not Value;
  spbSaveAsScene.Enabled := not Value;
  spbOpenScene.Enabled := not Value;
  EditModeControlBar.Enabled := not Value;
  //chbDebugWireframe.Enabled := not Value;
  chbDebugWireframe.Enabled := True;
  spbPlay.Enabled := True;

  if Assigned(frmMeshCreator) then
    frmMeshCreator.Enabled := not Value;

  if Value then
  begin
    //scTree.Color := clRed;
    //scTree.Repaint;

    MainControlBar.Color := clRed;
    MainControlBar.Repaint;
    StartPhysicsControlBar.Color := clRed;
    StartPhysicsControlBar.Repaint;
    //MainForm.Invalidate;
    //MainForm.Repaint;

    spbPlay.ImageIndex := 1;
    fDraggingGizmo := False;
    fHoveredAxis := -1;
    if Assigned(fCurrentGizmo) then
      FreeAndNil(fCurrentGizmo);
  end
  else
  begin
    //scTree.Color := clWindow;
    //scTree.Repaint;

    MainControlBar.Color := clBtnFace;
    MainControlBar.Repaint;
    StartPhysicsControlBar.Color := clBtnFace;
    StartPhysicsControlBar.Repaint;
    //MainForm.Invalidate;
    //MainForm.Repaint;

    spbPlay.ImageIndex := 0;
    if Assigned(fSceneManager) then
      fSceneManager.Update;
    if fSelectedObject <> nil then
      RefreshGizmo;
    UpdateUI;
  end;
end;

procedure TMainForm.AddToTree(ParentNode: TTreeNode; SceneObject: TSceneObject);
var
  Node: TTreeNode;
  i: Integer;
  DisplayName: string;
begin
  if not Assigned(SceneObject) then
    Exit;

  if SceneObject.IsGizmo then
    Exit;

  if SceneObject is TSceneObject then
    DisplayName := SceneObject.Name;

  Node := scTree.Items.AddChild(ParentNode, DisplayName);
  Node.Data := SceneObject;

  for i := 0 to SceneObject.Count - 1 do
    AddToTree(Node, SceneObject.ObjectList[i]);
end;

procedure TMainForm.PopulateTreeView;
var
  i: Integer;
begin
  scTree.Items.BeginUpdate;
  try
    scTree.Items.Clear;

    for i := 0 to fSceneManager.Count - 1 do
      AddToTree(nil, fSceneManager.Root.ObjectList[i]);

    scTree.FullExpand;
  finally
    scTree.Items.EndUpdate;
  end;
end;

function TMainForm.GetSelectedObjectOrder(out ParentObj: TSceneObject; out Index: Integer): Boolean;
begin
  Result := False;
  ParentObj := nil;
  Index := -1;

  if fSimulatePhysics or IsNewObjectEditorActive then
    Exit;
  if (fSelectedObject = nil) or fSelectedObject.IsGizmo then
    Exit;

  ParentObj := fSelectedObject.Parent;
  if ParentObj = nil then
    Exit;

  Index := ParentObj.IndexOfObject(fSelectedObject);
  Result := Index >= 0;
  if not Result then
    ParentObj := nil;
end;

function TMainForm.CanMoveSelectedObject(Delta: Integer): Boolean;
var
  ParentObj: TSceneObject;
  Index, TargetIndex: Integer;
begin
  Result := False;
  if not GetSelectedObjectOrder(ParentObj, Index) then
    Exit;

  TargetIndex := Index + Delta;
  Result := (TargetIndex >= 0) and (TargetIndex < ParentObj.Count);
end;

procedure TMainForm.MoveSelectedObject(Delta: Integer);
var
  ParentObj: TSceneObject;
  Obj: TSceneObject;
  Index, TargetIndex: Integer;
begin
  if not GetSelectedObjectOrder(ParentObj, Index) then
    Exit;

  TargetIndex := Index + Delta;
  if (TargetIndex < 0) or (TargetIndex >= ParentObj.Count) then
    Exit;

  Obj := fSelectedObject;
  if not ParentObj.MoveObject(Obj, TargetIndex) then
    Exit;

  fSceneManager.Update;
  PopulateTreeView;
  SynchronizeTreeViewSelection(Obj);

  if Assigned(scTree.Selected) and (scTree.Selected.Data = Obj) then
    scTreeClick(scTree)
  else
  begin
    UpdateUI;
    RefreshPhysicsDebugHull;
    if Assigned(fRenderer) then
      fRenderer.Render;
  end;
end;

procedure TMainForm.UpdateObjectCommandStates;
var
  Obj: TSceneObject;
  CanUseSelection: Boolean;
  CanAddObject: Boolean;
  CanPaste: Boolean;
  CanDelete: Boolean;
  CanMoveUp: Boolean;
  CanMoveDown: Boolean;
begin
  CanPaste := False;
  CanUseSelection := False;
  CanAddObject := False;
  CanDelete := False;
  CanMoveUp := False;
  CanMoveDown := False;
  Obj := nil;

  if not fSimulatePhysics then
  begin
    CanPaste := Assigned(FClipboardObject);

    if Assigned(fSelectedObject) then
      Obj := fSelectedObject;

    CanUseSelection := Assigned(Obj) and Assigned(scTree.Selected) and
      (scTree.Selected.Data = Obj);
    CanAddObject := CanUseSelection;

    if CanUseSelection then
      CanDelete := (Obj <> fRoot) and (Obj <> fCamera);

    CanMoveUp := CanMoveSelectedObject(-1);
    CanMoveDown := CanMoveSelectedObject(1);
  end;

  puPaste.Enabled := CanPaste;
  puCut.Enabled := CanUseSelection;
  puCopy.Enabled := CanUseSelection;
  puRename.Enabled := CanUseSelection;
  puDelete.Enabled := CanDelete;

  spbAddObject.Enabled := CanAddObject;

  spbPasteObject.Enabled := puPaste.Enabled;
  mmPaste.Enabled := puPaste.Enabled;

  spbCutObject.Enabled := puCut.Enabled;
  mmCut.Enabled := puCut.Enabled;

  spbCopyObject.Enabled := puCopy.Enabled;
  mmCopy.Enabled := puCopy.Enabled;

  spbDeleteObject.Enabled := puDelete.Enabled;
  mmDelete.Enabled := puDelete.Enabled;

  spbUpObject.Enabled := CanMoveUp;
  mmMoveUp.Enabled := CanMoveUp;

  spbDownObject.Enabled := CanMoveDown;
  mmMoveDown.Enabled := CanMoveDown;
end;

procedure TMainForm.PopupMenu1Popup(Sender: TObject);
begin
  UpdateObjectCommandStates;
end;

procedure TMainForm.puCombineGeometryClick(Sender: TObject);
var
  tmpObject: TSceneObject;
  ParentNode: TTreeNode;
  Node: TTreeNode;
begin
  if fSelectedObject <> nil then
  begin
    tmpObject := fSelectedObject;
    if Assigned(fCurrentGizmo) then
      DeselectObject;
    tmpObject.CombineMeshLists;
    fSelectedObject := tmpObject;

    // Find the parent node in the tree
    ParentNode := nil;
    for Node in scTree.Items do
      if Node.Data = tmpObject then
      begin
        ParentNode := Node;
        Break;
      end;

    // Delete all child nodes (if parent found)
    if Assigned(ParentNode) then
    begin
      // Delete from last child backwards to avoid index issues
      while ParentNode.HasChildren do
        ParentNode.GetLastChild.Delete;
    end;

    // Re-select the parent
    SynchronizeTreeViewSelection(fSelectedObject);
    tmpObject := nil;

    scTreeClick(Self);
  end;
end;

procedure TMainForm.puCopyClick(Sender: TObject);
begin
  CopyNode;
end;

procedure TMainForm.puCutClick(Sender: TObject);
begin
  CutNode;
end;

procedure TMainForm.puDeleteClick(Sender: TObject);
var
  node: TTreeNode;
  obj: TSceneObject;
  parentNode: TTreeNode;
  oldClick: TNotifyEvent;
begin
  node := scTree.Selected;
  if not Assigned(node) or not Assigned(node.Data) then
    Exit;

  obj := TSceneObject(node.Data);

  if (obj = fRoot) or (obj = fCamera) then
  begin
    ShowMessage('Cannot delete the root or camera object.');
    Exit;
  end;

  parentNode := node.Parent;

  oldClick := scTree.OnClick;
  scTree.OnClick := nil;
  try
    if Assigned(fCurrentGizmo) then
      FreeAndNil(fCurrentGizmo);
    ClearPhysicsDebugHull;
    ClearClipboard;

    fSelectedObject := nil;
    fSelectedMesh := nil;
    fPhysicsBody := nil;
    fTransformObject := nil;
    fGizmoOwner := nil;
    fLastPickedMeshIndex := -1;
    fNewObjectMode := False;
    RefreshSelectedBoundingBox;

    ResetTransformControls;
    ResetMeshes;
    ResetPhysicsControls;
    ResetMeshEditor;

    if Assigned(fPhysicsWorld) then
      fPhysicsWorld.RemoveBodiesForScene(obj, True);

    node.Delete;
    obj.Free;

    if Assigned(parentNode) and Assigned(parentNode.Data) then
      scTree.Selected := parentNode
    else
      scTree.Selected := nil;
  finally
    scTree.OnClick := oldClick;
  end;

  if Assigned(scTree.Selected) and Assigned(scTree.Selected.Data) then
    scTreeClick(Self)
  else
  begin
    UpdateUI;
    ClearPhysicsDebugHull;
    fRenderer.Render;
  end;

  UpdateGizmoScale;
end;

procedure TMainForm.puNewArrowClick(Sender: TObject);
var
  parentNode: TTreeNode;
  parentObj: TSceneObject;
  newNode: TTreeNode;
  newObj: TSceneObject;
  baseName: string;
  idx: Integer;
  tmpMesh: TMesh;
begin
  if not Assigned(scTree.Selected) then
    parentNode := nil
  else
    parentNode := scTree.Selected;

  if Assigned(parentNode) and Assigned(parentNode.Data) then
    parentObj := TSceneObject(parentNode.Data)
  else
    parentObj := fRoot;

  fNewObjectMode := True;

  baseName := 'Arrow';
  idx := 1;
  newObj := nil;

  // Create the object
  newObj := TSceneObject.Create(parentObj);
  newObj.Name := baseName;

  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateArrow(1.0, 0.4, 0.05, 0.12, 12, 2, baseName);
  newObj.MeshList.AddMeshToList(tmpMesh);
  EnsurePhysicsBodyForObject(newObj);

  // Form preparation
  frmMeshCreator.Top := pnlObjects.Top + 45;
  frmMeshCreator.Left := pnlObjects.Width + 10;
  frmMeshCreator.ClientWidth := 426;
  frmMeshCreator.ClientHeight := frmMeshCreator.pnlNewArrowMesh.Height;
  frmMeshCreator.pnlNewArrowMesh.Top := 0;
  frmMeshCreator.pnlNewArrowMesh.Left := 0;
  frmMeshCreator.DisableArrowEvents(True);
  frmMeshCreator.InternalObject := newObj;
  frmMeshCreator.SelectedMesh := tmpMesh;
  frmMeshCreator.Caption := 'Create Arrow';
  frmMeshCreator.eArrowShaftLength.Text := '1.00';
  frmMeshCreator.eArrowTipLength.Text := '0.40';
  frmMeshCreator.eArrowShaftRadius.Text := '0.05';
  frmMeshCreator.eArrowTipRadius.Text := '0.12';
  frmMeshCreator.eArrowSlices.Text := '12';
  frmMeshCreator.eArrowStacks.Text := '2';
  frmMeshCreator.eArrowName.Text := tmpMesh.Name;
  frmMeshCreator.DisableArrowEvents(False);
  frmMeshCreator.Visible := True;

  newObj.UpdateBoundingRadiusFromMesh;
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'DefaultPBRMaterial';
  tmpMesh.OnRender := MeshRenderHandler;
  newObj.NotifyChange;
  tmpMesh := nil;

  // Add to tree view
  if Assigned(parentNode) then
    newNode := scTree.Items.AddChild(parentNode, newObj.Name)
  else
    newNode := scTree.Items.Add(nil, newObj.Name);
  newNode.Data := newObj;

  scTree.FullExpand;
  scTree.Selected := newNode;

  frmMeshCreator.SelectedTreeNode := newNode;
  scTreeClick(scTree);
end;

procedure TMainForm.puNewCapsuleClick(Sender: TObject);
var
  parentNode: TTreeNode;
  parentObj: TSceneObject;
  newNode: TTreeNode;
  newObj: TSceneObject;
  baseName: string;
  idx: Integer;
  tmpMesh: TMesh;
begin
  if not Assigned(scTree.Selected) then
    parentNode := nil
  else
    parentNode := scTree.Selected;

  if Assigned(parentNode) and Assigned(parentNode.Data) then
    parentObj := TSceneObject(parentNode.Data)
  else
    parentObj := fRoot;

  fNewObjectMode := True;

  baseName := 'Capsule';
  idx := 1;
  newObj := nil;

  // Create the object
  newObj := TSceneObject.Create(parentObj);
  newObj.Name := baseName;

  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateCapsule(0.5, 0.5, 12, 12, baseName);
  newObj.MeshList.AddMeshToList(tmpMesh);
  EnsurePhysicsBodyForObject(newObj);

  // Form preparation
  frmMeshCreator.Top := pnlObjects.Top + 45;
  frmMeshCreator.Left := pnlObjects.Width + 10;
  frmMeshCreator.ClientWidth := 426;
  frmMeshCreator.ClientHeight := frmMeshCreator.pnlNewCapsuleMesh.Height;
  frmMeshCreator.pnlNewCapsuleMesh.Top := 0;
  frmMeshCreator.pnlNewCapsuleMesh.Left := 0;
  frmMeshCreator.DisableCapsuleEvents(True);
  frmMeshCreator.InternalObject := newObj;
  frmMeshCreator.SelectedMesh := tmpMesh;
  frmMeshCreator.Caption := 'Create Capsule';

  frmMeshCreator.eCapsuleRadius.Text := '0.50';
  frmMeshCreator.eCapsuleHeight.Text := '0.50';
  frmMeshCreator.eCapsuleStacks.Text := '12';
  frmMeshCreator.eCapsuleSlices.Text := '12';
  frmMeshCreator.eCapsuleName.Text := tmpMesh.Name;
  frmMeshCreator.DisableCapsuleEvents(False);
  frmMeshCreator.Visible := True;

  newObj.UpdateBoundingRadiusFromMesh;
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'DefaultPBRMaterial';
  tmpMesh.OnRender := MeshRenderHandler;
  newObj.NotifyChange;
  tmpMesh := nil;

  // Add to tree view
  if Assigned(parentNode) then
    newNode := scTree.Items.AddChild(parentNode, newObj.Name)
  else
    newNode := scTree.Items.Add(nil, newObj.Name);
  newNode.Data := newObj;

  scTree.FullExpand;
  scTree.Selected := newNode;

  frmMeshCreator.SelectedTreeNode := newNode;
  scTreeClick(scTree);
end;

procedure TMainForm.puNewConeClick(Sender: TObject);
var
  parentNode: TTreeNode;
  parentObj: TSceneObject;
  newNode: TTreeNode;
  newObj: TSceneObject;
  baseName: string;
  idx: Integer;
  tmpMesh: TMesh;
begin
  if not Assigned(scTree.Selected) then
    parentNode := nil
  else
    parentNode := scTree.Selected;

  if Assigned(parentNode) and Assigned(parentNode.Data) then
    parentObj := TSceneObject(parentNode.Data)
  else
    parentObj := fRoot;

  fNewObjectMode := True;

  baseName := 'Cone';
  idx := 1;
  newObj := nil;

  // Create the object
  newObj := TSceneObject.Create(parentObj);
  newObj.Name := baseName;

  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateCone(0.5, 1, 12, 1, baseName);
  newObj.MeshList.AddMeshToList(tmpMesh);
  EnsurePhysicsBodyForObject(newObj);

  // Form preparation
  frmMeshCreator.Top := pnlObjects.Top + 45;
  frmMeshCreator.Left := pnlObjects.Width + 10;
  frmMeshCreator.ClientWidth := 426;
  frmMeshCreator.ClientHeight := frmMeshCreator.pnlNewConeMesh.Height;
  frmMeshCreator.pnlNewConeMesh.Top := 0;
  frmMeshCreator.pnlNewConeMesh.Left := 0;
  frmMeshCreator.DisableConeEvents(True);
  frmMeshCreator.InternalObject := newObj;
  frmMeshCreator.SelectedMesh := tmpMesh;
  frmMeshCreator.Caption := 'Create Cone';

  frmMeshCreator.eConeRadius.Text := '0.50';
  frmMeshCreator.eConeHeight.Text := '1.00';
  frmMeshCreator.eConeSides.Text := '12';
  frmMeshCreator.eConeStacks.Text := '1';

  frmMeshCreator.eConeName.Text := tmpMesh.Name;
  frmMeshCreator.DisableConeEvents(False);
  frmMeshCreator.Visible := True;

  newObj.UpdateBoundingRadiusFromMesh;
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'DefaultPBRMaterial';
  tmpMesh.OnRender := MeshRenderHandler;
  newObj.NotifyChange;
  tmpMesh := nil;

  // Add to tree view
  if Assigned(parentNode) then
    newNode := scTree.Items.AddChild(parentNode, newObj.Name)
  else
    newNode := scTree.Items.Add(nil, newObj.Name);
  newNode.Data := newObj;

  scTree.FullExpand;
  scTree.Selected := newNode;

  frmMeshCreator.SelectedTreeNode := newNode;
  scTreeClick(scTree);
end;

procedure TMainForm.puNewCubeClick(Sender: TObject);
var
  parentNode: TTreeNode;
  parentObj: TSceneObject;
  newNode: TTreeNode;
  newObj: TSceneObject;
  baseName: string;
  idx, i: Integer;
  tmpMesh: TMesh;
begin
  if not Assigned(scTree.Selected) then
    parentNode := nil
  else
    parentNode := scTree.Selected;

  if Assigned(parentNode) and Assigned(parentNode.Data) then
    parentObj := TSceneObject(parentNode.Data)
  else
    parentObj := fRoot;

  fNewObjectMode := True;

  baseName := 'Cube';
  idx := 1;
  newObj := nil;

  // Create the object
  newObj := TSceneObject.Create(parentObj);
  newObj.Name := baseName;

  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateCube(1, 1, 1, 1, 1, 1, baseName);
  newObj.MeshList.AddMeshToList(tmpMesh);
  EnsurePhysicsBodyForObject(newObj);

  // Form preparation
  frmMeshCreator.Top := pnlObjects.Top + 45;
  frmMeshCreator.Left := pnlObjects.Width + 10;
  frmMeshCreator.ClientWidth := 426;
  frmMeshCreator.ClientHeight := frmMeshCreator.pnlNewCubeMesh.Height;
  frmMeshCreator.pnlNewCubeMesh.Top := 0;
  frmMeshCreator.pnlNewCubeMesh.Left := 0;
  frmMeshCreator.DisableCubeEvents(True);
  frmMeshCreator.InternalObject := newObj;
  frmMeshCreator.SelectedMesh := tmpMesh;
  frmMeshCreator.Caption := 'Create Cube';
  frmMeshCreator.eCubeWidth.Text := '1.00';
  frmMeshCreator.eCubeHeight.Text := '1.00';
  frmMeshCreator.eCubeDepth.Text := '1.00';
  frmMeshCreator.eCubeWidthSegments.Text := '1';
  frmMeshCreator.eCubeDepthSegments.Text := '1';
  frmMeshCreator.eCubeDepthSegments.Text := '1';
  frmMeshCreator.eCubeName.Text := tmpMesh.Name;
  frmMeshCreator.DisableCubeEvents(False);
  frmMeshCreator.Visible := True;

  newObj.UpdateBoundingRadiusFromMesh;
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'DefaultPBRMaterial';
  tmpMesh.OnRender := MeshRenderHandler;
  newObj.NotifyChange;
  tmpMesh := nil;

  // Add to tree view
  if Assigned(parentNode) then
    newNode := scTree.Items.AddChild(parentNode, newObj.Name)
  else
    newNode := scTree.Items.Add(nil, newObj.Name);
  newNode.Data := newObj;

  scTree.FullExpand;
  scTree.Selected := newNode;

  frmMeshCreator.SelectedTreeNode := newNode;
  scTreeClick(scTree);
end;

procedure TMainForm.puNewCubeEllipsoidClick(Sender: TObject);
var
  parentNode: TTreeNode;
  parentObj: TSceneObject;
  newNode: TTreeNode;
  newObj: TSceneObject;
  baseName: string;
  idx: Integer;
  tmpMesh: TMesh;
begin
  if not Assigned(scTree.Selected) then
    parentNode := nil
  else
    parentNode := scTree.Selected;

  if Assigned(parentNode) and Assigned(parentNode.Data) then
    parentObj := TSceneObject(parentNode.Data)
  else
    parentObj := fRoot;

  fNewObjectMode := True;

  baseName := 'CubeEllipsoid';
  idx := 1;
  newObj := nil;

  // Create the object
  newObj := TSceneObject.Create(parentObj);
  newObj.Name := baseName;

  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateSuperellipsoid(1.0, 0.3, 0.3, 32, 32, baseName);
  newObj.MeshList.AddMeshToList(tmpMesh);
  EnsurePhysicsBodyForObject(newObj);

  // Form preparation
  frmMeshCreator.Top := pnlObjects.Top + 45;
  frmMeshCreator.Left := pnlObjects.Width + 10;
  frmMeshCreator.ClientWidth := 426;
  frmMeshCreator.ClientHeight := frmMeshCreator.pnlNewSuperEllipsoidMesh.Height;
  frmMeshCreator.pnlNewSuperEllipsoidMesh.Top := 0;
  frmMeshCreator.pnlNewSuperEllipsoidMesh.Left := 0;
  frmMeshCreator.DisableSuperEllipsoidEvents(True);
  frmMeshCreator.InternalObject := newObj;
  frmMeshCreator.SelectedMesh := tmpMesh;
  frmMeshCreator.Caption := 'Create GeodesicDome';
  frmMeshCreator.eSuperEllipsoidRadius.Text := '1.00';
  frmMeshCreator.eSuperEllipsoidVCurve.Text := '0.30';
  frmMeshCreator.eSuperEllipsoidHCurve.Text := '0.30';
  frmMeshCreator.eSuperEllipsoidSlices.Text := '32';
  frmMeshCreator.eSuperEllipsoidStacks.Text := '32';
  frmMeshCreator.eSuperEllipsoidName.Text := tmpMesh.Name;
  frmMeshCreator.DisableSuperEllipsoidEvents(False);
  frmMeshCreator.Visible := True;

  newObj.UpdateBoundingRadiusFromMesh;
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'DefaultPBRMaterial';
  tmpMesh.OnRender := MeshRenderHandler;
  newObj.NotifyChange;
  tmpMesh := nil;

  // Add to tree view
  if Assigned(parentNode) then
    newNode := scTree.Items.AddChild(parentNode, newObj.Name)
  else
    newNode := scTree.Items.Add(nil, newObj.Name);
  newNode.Data := newObj;

  scTree.FullExpand;
  scTree.Selected := newNode;

  frmMeshCreator.SelectedTreeNode := newNode;
  scTreeClick(scTree);
end;

procedure TMainForm.puNewCylinderClick(Sender: TObject);
var
  parentNode: TTreeNode;
  parentObj: TSceneObject;
  newNode: TTreeNode;
  newObj: TSceneObject;
  baseName: string;
  idx: Integer;
  tmpMesh: TMesh;
begin
  if not Assigned(scTree.Selected) then
    parentNode := nil
  else
    parentNode := scTree.Selected;

  if Assigned(parentNode) and Assigned(parentNode.Data) then
    parentObj := TSceneObject(parentNode.Data)
  else
    parentObj := fRoot;

  fNewObjectMode := True;

  baseName := 'Cylinder';
  idx := 1;
  newObj := nil;

  // Create the object
  newObj := TSceneObject.Create(parentObj);
  newObj.Name := baseName;

  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateCylinder(0.5, 1.0, 12, 12, baseName);
  newObj.MeshList.AddMeshToList(tmpMesh);
  EnsurePhysicsBodyForObject(newObj);

  // Form preparation
  frmMeshCreator.Top := pnlObjects.Top + 45;
  frmMeshCreator.Left := pnlObjects.Width + 10;
  frmMeshCreator.ClientWidth := 426;
  frmMeshCreator.ClientHeight := frmMeshCreator.pnlNewCylinderMesh.Height;
  frmMeshCreator.pnlNewCylinderMesh.Top := 0;
  frmMeshCreator.pnlNewCylinderMesh.Left := 0;
  frmMeshCreator.DisableCylinderEvents(True);
  frmMeshCreator.InternalObject := newObj;
  frmMeshCreator.SelectedMesh := tmpMesh;
  frmMeshCreator.Caption := 'Create Cylinder';

  frmMeshCreator.eCylinderRadius.Text := '0.50';
  frmMeshCreator.eCylinderHeight.Text := '1.0';
  frmMeshCreator.eCylinderStacks.Text := '12';
  frmMeshCreator.eCylinderSlices.Text := '12';
  frmMeshCreator.eCylinderName.Text := tmpMesh.Name;
  frmMeshCreator.DisableCylinderEvents(False);
  frmMeshCreator.Visible := True;

  newObj.UpdateBoundingRadiusFromMesh;
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'DefaultPBRMaterial';
  tmpMesh.OnRender := MeshRenderHandler;
  newObj.NotifyChange;
  tmpMesh := nil;

  // Add to tree view
  if Assigned(parentNode) then
    newNode := scTree.Items.AddChild(parentNode, newObj.Name)
  else
    newNode := scTree.Items.Add(nil, newObj.Name);
  newNode.Data := newObj;

  scTree.FullExpand;
  scTree.Selected := newNode;

  frmMeshCreator.SelectedTreeNode := newNode;
  scTreeClick(scTree);
end;

procedure TMainForm.puNewCylinderEllipsoidClick(Sender: TObject);
var
  parentNode: TTreeNode;
  parentObj: TSceneObject;
  newNode: TTreeNode;
  newObj: TSceneObject;
  baseName: string;
  idx: Integer;
  tmpMesh: TMesh;
begin
  if not Assigned(scTree.Selected) then
    parentNode := nil
  else
    parentNode := scTree.Selected;

  if Assigned(parentNode) and Assigned(parentNode.Data) then
    parentObj := TSceneObject(parentNode.Data)
  else
    parentObj := fRoot;

  fNewObjectMode := True;

  baseName := 'CylinderEllipsoid';
  idx := 1;
  newObj := nil;

  // Create the object
  newObj := TSceneObject.Create(parentObj);
  newObj.Name := baseName;

  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateSuperellipsoid(1.0, 0.5, 1.0, 32, 32, baseName);
  newObj.MeshList.AddMeshToList(tmpMesh);
  EnsurePhysicsBodyForObject(newObj);

  // Form preparation
  frmMeshCreator.Top := pnlObjects.Top + 45;
  frmMeshCreator.Left := pnlObjects.Width + 10;
  frmMeshCreator.ClientWidth := 426;
  frmMeshCreator.ClientHeight := frmMeshCreator.pnlNewSuperEllipsoidMesh.Height;
  frmMeshCreator.pnlNewSuperEllipsoidMesh.Top := 0;
  frmMeshCreator.pnlNewSuperEllipsoidMesh.Left := 0;
  frmMeshCreator.DisableSuperEllipsoidEvents(True);
  frmMeshCreator.InternalObject := newObj;
  frmMeshCreator.SelectedMesh := tmpMesh;
  frmMeshCreator.Caption := 'Create GeodesicDome';
  frmMeshCreator.eSuperEllipsoidRadius.Text := '1.00';
  frmMeshCreator.eSuperEllipsoidVCurve.Text := '0.50';
  frmMeshCreator.eSuperEllipsoidHCurve.Text := '1.00';
  frmMeshCreator.eSuperEllipsoidSlices.Text := '32';
  frmMeshCreator.eSuperEllipsoidStacks.Text := '32';
  frmMeshCreator.eSuperEllipsoidName.Text := tmpMesh.Name;
  frmMeshCreator.DisableSuperEllipsoidEvents(False);
  frmMeshCreator.Visible := True;

  newObj.UpdateBoundingRadiusFromMesh;
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'DefaultPBRMaterial';
  tmpMesh.OnRender := MeshRenderHandler;
  newObj.NotifyChange;
  tmpMesh := nil;

  // Add to tree view
  if Assigned(parentNode) then
    newNode := scTree.Items.AddChild(parentNode, newObj.Name)
  else
    newNode := scTree.Items.Add(nil, newObj.Name);
  newNode.Data := newObj;

  scTree.FullExpand;
  scTree.Selected := newNode;

  frmMeshCreator.SelectedTreeNode := newNode;
  scTreeClick(scTree);
end;

procedure TMainForm.puNewEmptyObjectClick(Sender: TObject);
var
  parentNode: TTreeNode;
  parentObj: TSceneObject;
  newNode: TTreeNode;
  newObj: TSceneObject;
begin

  if not Assigned(scTree.Selected) then
    parentNode := nil
  else
    parentNode := scTree.Selected;

  if Assigned(parentNode) and Assigned(parentNode.Data) then
    parentObj := TSceneObject(parentNode.Data)
  else
    parentObj := fRoot;

  newObj := TSceneObject.Create(parentObj);
  newObj.Name := 'Dummy';   // uniqueness handled in SetName
  EnsurePhysicsBodyForObject(newObj);
  // No mesh creation

  if Assigned(parentNode) then
    newNode := scTree.Items.AddChild(parentNode, newObj.Name)
  else
    newNode := scTree.Items.Add(nil, newObj.Name);
  newNode.Data := newObj;

  scTree.FullExpand;
  scTree.Selected := newNode;
  scTreeClick(scTree);
end;

procedure TMainForm.puNewFrustumClick(Sender: TObject);
var
  parentNode: TTreeNode;
  parentObj: TSceneObject;
  newNode: TTreeNode;
  newObj: TSceneObject;
  baseName: string;
  idx: Integer;
  tmpMesh: TMesh;
begin

  if not Assigned(scTree.Selected) then
    parentNode := nil
  else
    parentNode := scTree.Selected;

  if Assigned(parentNode) and Assigned(parentNode.Data) then
    parentObj := TSceneObject(parentNode.Data)
  else
    parentObj := fRoot;

  fNewObjectMode := True;

  baseName := 'Frustum';
  idx := 1;
  newObj := nil;

  // Create the object
  newObj := TSceneObject.Create(parentObj);
  newObj.Name := baseName;

  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateFrustum(1.0, 0.5, 1, 12, 2, ctFlat, ctFlat, baseName);
  newObj.MeshList.AddMeshToList(tmpMesh);
  EnsurePhysicsBodyForObject(newObj);

  // Form preparation
  frmMeshCreator.Top := pnlObjects.Top + 45;
  frmMeshCreator.Left := pnlObjects.Width + 10;
  frmMeshCreator.ClientWidth := 426;
  frmMeshCreator.ClientHeight := frmMeshCreator.pnlNewFrustumMesh.Height;
  frmMeshCreator.pnlNewFrustumMesh.Top := 0;
  frmMeshCreator.pnlNewFrustumMesh.Left := 0;
  frmMeshCreator.DisableFrustumEvents(True);
  frmMeshCreator.InternalObject := newObj;
  frmMeshCreator.SelectedMesh := tmpMesh;
  frmMeshCreator.Caption := 'Create Frustum';

  frmMeshCreator.eFrustumBottomRadius.Text := '1.00';
  frmMeshCreator.eFrustumTopRadius.Text := '0.50';
  frmMeshCreator.eFrustumHeight.Text := '1';
  frmMeshCreator.eFrustumSlices.Text := '12';
  frmMeshCreator.eFrustumStacks.Text := '2';
  frmMeshCreator.cbFrustumBottomCap.ItemIndex := 2;
  frmMeshCreator.cbFrustumTopCap.ItemIndex := 2;
  frmMeshCreator.eFrustumName.Text := tmpMesh.Name;
  frmMeshCreator.DisableFrustumEvents(False);
  frmMeshCreator.Visible := True;

  newObj.UpdateBoundingRadiusFromMesh;
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'DefaultPBRMaterial';
  tmpMesh.OnRender := MeshRenderHandler;
  newObj.NotifyChange;
  tmpMesh := nil;

  // Add to tree view
  if Assigned(parentNode) then
    newNode := scTree.Items.AddChild(parentNode, newObj.Name)
  else
    newNode := scTree.Items.Add(nil, newObj.Name);
  newNode.Data := newObj;

  scTree.FullExpand;
  scTree.Selected := newNode;

  frmMeshCreator.SelectedTreeNode := newNode;
  scTreeClick(scTree);
end;

procedure TMainForm.puNewGeodesicDomeClick(Sender: TObject);
var
  parentNode: TTreeNode;
  parentObj: TSceneObject;
  newNode: TTreeNode;
  newObj: TSceneObject;
  baseName: string;
  idx: Integer;
  tmpMesh: TMesh;
begin
  if not Assigned(scTree.Selected) then
    parentNode := nil
  else
    parentNode := scTree.Selected;

  if Assigned(parentNode) and Assigned(parentNode.Data) then
    parentObj := TSceneObject(parentNode.Data)
  else
    parentObj := fRoot;

  fNewObjectMode := True;

  baseName := 'GeodesicDome';
  idx := 1;
  newObj := nil;

  // Create the object
  newObj := TSceneObject.Create(parentObj);
  newObj.Name := baseName;

  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateGeodesicDome(1.0, 2, baseName);
  newObj.MeshList.AddMeshToList(tmpMesh);
  EnsurePhysicsBodyForObject(newObj);

  // Form preparation
  frmMeshCreator.Top := pnlObjects.Top + 45;
  frmMeshCreator.Left := pnlObjects.Width + 10;
  frmMeshCreator.ClientWidth := 426;
  frmMeshCreator.ClientHeight := frmMeshCreator.pnlNewGeodesicDomeMesh.Height;
  frmMeshCreator.pnlNewGeodesicDomeMesh.Top := 0;
  frmMeshCreator.pnlNewGeodesicDomeMesh.Left := 0;
  frmMeshCreator.DisableGeodesicDomeEvents(True);
  frmMeshCreator.InternalObject := newObj;
  frmMeshCreator.SelectedMesh := tmpMesh;
  frmMeshCreator.Caption := 'Create GeodesicDome';
  frmMeshCreator.eGeodesicDomeRadius.Text := '1.00';
  frmMeshCreator.eGeodesicDomeSubdivisions.Text := '2';
  frmMeshCreator.eGeodesicDomeName.Text := tmpMesh.Name;
  frmMeshCreator.DisableGeodesicDomeEvents(False);
  frmMeshCreator.Visible := True;

  newObj.UpdateBoundingRadiusFromMesh;
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'DefaultPBRMaterial';
  tmpMesh.OnRender := MeshRenderHandler;
  newObj.NotifyChange;
  tmpMesh := nil;

  // Add to tree view
  if Assigned(parentNode) then
    newNode := scTree.Items.AddChild(parentNode, newObj.Name)
  else
    newNode := scTree.Items.Add(nil, newObj.Name);
  newNode.Data := newObj;

  scTree.FullExpand;
  scTree.Selected := newNode;

  frmMeshCreator.SelectedTreeNode := newNode;
  scTreeClick(scTree);
end;

procedure TMainForm.puNewIcosphereClick(Sender: TObject);
var
  parentNode: TTreeNode;
  parentObj: TSceneObject;
  newNode: TTreeNode;
  newObj: TSceneObject;
  baseName: string;
  idx: Integer;
  tmpMesh: TMesh;
begin
  if not Assigned(scTree.Selected) then
    parentNode := nil
  else
    parentNode := scTree.Selected;

  if Assigned(parentNode) and Assigned(parentNode.Data) then
    parentObj := TSceneObject(parentNode.Data)
  else
    parentObj := fRoot;

  fNewObjectMode := True;

  baseName := 'Icosphere';
  idx := 1;
  newObj := nil;

  // Create the object
  newObj := TSceneObject.Create(parentObj);
  newObj.Name := baseName;

  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateIcosphere(1.0, 2, baseName);
  newObj.MeshList.AddMeshToList(tmpMesh);
  EnsurePhysicsBodyForObject(newObj);

  // Form preparation
  frmMeshCreator.Top := pnlObjects.Top + 45;
  frmMeshCreator.Left := pnlObjects.Width + 10;
  frmMeshCreator.ClientWidth := 426;
  frmMeshCreator.ClientHeight := frmMeshCreator.pnlNewIcosphereMesh.Height;
  frmMeshCreator.pnlNewIcosphereMesh.Top := 0;
  frmMeshCreator.pnlNewIcosphereMesh.Left := 0;
  frmMeshCreator.DisableIcosphereEvents(True);
  frmMeshCreator.InternalObject := newObj;
  frmMeshCreator.SelectedMesh := tmpMesh;
  frmMeshCreator.Caption := 'Create Icosphere';
  frmMeshCreator.eIcosphereRadius.Text := '1.00';
  frmMeshCreator.eIcosphereSubdivisions.Text := '2';
  frmMeshCreator.eIcosphereName.Text := tmpMesh.Name;
  frmMeshCreator.DisableIcosphereEvents(False);
  frmMeshCreator.Visible := True;

  newObj.UpdateBoundingRadiusFromMesh;
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'DefaultPBRMaterial';
  tmpMesh.OnRender := MeshRenderHandler;
  newObj.NotifyChange;
  tmpMesh := nil;

  // Add to tree view
  if Assigned(parentNode) then
    newNode := scTree.Items.AddChild(parentNode, newObj.Name)
  else
    newNode := scTree.Items.Add(nil, newObj.Name);
  newNode.Data := newObj;

  scTree.FullExpand;
  scTree.Selected := newNode;

  frmMeshCreator.SelectedTreeNode := newNode;
  scTreeClick(scTree);
end;

procedure TMainForm.puNewPillEllipsoidClick(Sender: TObject);
var
  parentNode: TTreeNode;
  parentObj: TSceneObject;
  newNode: TTreeNode;
  newObj: TSceneObject;
  baseName: string;
  idx: Integer;
  tmpMesh: TMesh;
begin
  if not Assigned(scTree.Selected) then
    parentNode := nil
  else
    parentNode := scTree.Selected;

  if Assigned(parentNode) and Assigned(parentNode.Data) then
    parentObj := TSceneObject(parentNode.Data)
  else
    parentObj := fRoot;

  fNewObjectMode := True;

  baseName := 'PillEllipsoid';
  idx := 1;
  newObj := nil;

  // Create the object
  newObj := TSceneObject.Create(parentObj);
  newObj.Name := baseName;

  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateSuperellipsoid(1.0, 1.0, 0.5, 32, 32, baseName);
  newObj.MeshList.AddMeshToList(tmpMesh);
  EnsurePhysicsBodyForObject(newObj);

  // Form preparation
  frmMeshCreator.Top := pnlObjects.Top + 45;
  frmMeshCreator.Left := pnlObjects.Width + 10;
  frmMeshCreator.ClientWidth := 426;
  frmMeshCreator.ClientHeight := frmMeshCreator.pnlNewSuperEllipsoidMesh.Height;
  frmMeshCreator.pnlNewSuperEllipsoidMesh.Top := 0;
  frmMeshCreator.pnlNewSuperEllipsoidMesh.Left := 0;
  frmMeshCreator.DisableSuperEllipsoidEvents(True);
  frmMeshCreator.InternalObject := newObj;
  frmMeshCreator.SelectedMesh := tmpMesh;
  frmMeshCreator.Caption := 'Create GeodesicDome';
  frmMeshCreator.eSuperEllipsoidRadius.Text := '1.00';
  frmMeshCreator.eSuperEllipsoidVCurve.Text := '1.00';
  frmMeshCreator.eSuperEllipsoidHCurve.Text := '0.50';
  frmMeshCreator.eSuperEllipsoidSlices.Text := '32';
  frmMeshCreator.eSuperEllipsoidStacks.Text := '32';
  frmMeshCreator.eSuperEllipsoidName.Text := tmpMesh.Name;
  frmMeshCreator.DisableSuperEllipsoidEvents(False);
  frmMeshCreator.Visible := True;

  newObj.UpdateBoundingRadiusFromMesh;
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'DefaultPBRMaterial';
  tmpMesh.OnRender := MeshRenderHandler;
  newObj.NotifyChange;
  tmpMesh := nil;

  // Add to tree view
  if Assigned(parentNode) then
    newNode := scTree.Items.AddChild(parentNode, newObj.Name)
  else
    newNode := scTree.Items.Add(nil, newObj.Name);
  newNode.Data := newObj;

  scTree.FullExpand;
  scTree.Selected := newNode;

  frmMeshCreator.SelectedTreeNode := newNode;
  scTreeClick(scTree);
end;

procedure TMainForm.puNewPlaneClick(Sender: TObject);
var
  parentNode: TTreeNode;
  parentObj: TSceneObject;
  newNode: TTreeNode;
  newObj: TSceneObject;
  baseName: string;
  idx: Integer;
  tmpMesh: TMesh;
begin
  if not Assigned(scTree.Selected) then
    parentNode := nil
  else
    parentNode := scTree.Selected;

  if Assigned(parentNode) and Assigned(parentNode.Data) then
    parentObj := TSceneObject(parentNode.Data)
  else
    parentObj := fRoot;

  fNewObjectMode := True;

  baseName := 'Plane';
  idx := 1;
  newObj := nil;

  // Create the object
  newObj := TSceneObject.Create(parentObj);
  newObj.Name := baseName;

  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreatePlane(1, 1, 1, 1, baseName);
  newObj.MeshList.AddMeshToList(tmpMesh);
  EnsurePhysicsBodyForObject(newObj);

  // Form preparation
  frmMeshCreator.Top := pnlObjects.Top + 45;
  frmMeshCreator.Left := pnlObjects.Width + 10;
  frmMeshCreator.ClientWidth := 426;
  frmMeshCreator.ClientHeight := frmMeshCreator.pnlNewPlaneMesh.Height;
  frmMeshCreator.pnlNewPlaneMesh.Top := 0;
  frmMeshCreator.pnlNewPlaneMesh.Left := 0;
  frmMeshCreator.DisablePlaneEvents(True);
  frmMeshCreator.InternalObject := newObj;
  frmMeshCreator.SelectedMesh := tmpMesh;
  frmMeshCreator.Caption := 'Create Plane';
  frmMeshCreator.ePlaneWidth.Text := '1.00';
  frmMeshCreator.ePlaneDepth.Text := '1.00';
  frmMeshCreator.ePlaneWidthSegments.Text := '1';
  frmMeshCreator.ePlaneDepthSegments.Text := '1';
  frmMeshCreator.ePlaneName.Text := tmpMesh.Name;
  frmMeshCreator.DisablePlaneEvents(False);
  frmMeshCreator.Visible := True;

  newObj.UpdateBoundingRadiusFromMesh;
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'DefaultPBRMaterial';
  tmpMesh.OnRender := MeshRenderHandler;
  newObj.NotifyChange;

  tmpMesh := nil;

  // Add to tree view
  if Assigned(parentNode) then
    newNode := scTree.Items.AddChild(parentNode, newObj.Name)
  else
    newNode := scTree.Items.Add(nil, newObj.Name);
  newNode.Data := newObj;

  scTree.FullExpand;
  scTree.Selected := newNode;

  frmMeshCreator.SelectedTreeNode := newNode;
  scTreeClick(scTree);
end;

procedure TMainForm.puNewPrismClick(Sender: TObject);
var
  parentNode: TTreeNode;
  parentObj: TSceneObject;
  newNode: TTreeNode;
  newObj: TSceneObject;
  baseName: string;
  idx: Integer;
  tmpMesh: TMesh;
begin
  if not Assigned(scTree.Selected) then
    parentNode := nil
  else
    parentNode := scTree.Selected;

  if Assigned(parentNode) and Assigned(parentNode.Data) then
    parentObj := TSceneObject(parentNode.Data)
  else
    parentObj := fRoot;

  fNewObjectMode := True;

  baseName := 'Prism';
  idx := 1;
  newObj := nil;

  // Create the object
  newObj := TSceneObject.Create(parentObj);
  newObj.Name := baseName;

  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreatePrism(0.5, 1, 3, 1, baseName);
  newObj.MeshList.AddMeshToList(tmpMesh);
  EnsurePhysicsBodyForObject(newObj);

  // Form preparation
  frmMeshCreator.Top := pnlObjects.Top + 45;
  frmMeshCreator.Left := pnlObjects.Width + 10;
  frmMeshCreator.ClientWidth := 426;
  frmMeshCreator.ClientHeight := frmMeshCreator.pnlNewPrismMesh.Height;
  frmMeshCreator.pnlNewPrismMesh.Top := 0;
  frmMeshCreator.pnlNewPrismMesh.Left := 0;
  frmMeshCreator.DisablePrismEvents(True);
  frmMeshCreator.InternalObject := newObj;
  frmMeshCreator.SelectedMesh := tmpMesh;
  frmMeshCreator.Caption := 'Create Prism';
  frmMeshCreator.ePrismRadius.Text := '0.50';
  frmMeshCreator.ePrismHeight.Text := '1.00';
  frmMeshCreator.ePrismSides.Text := '3';
  frmMeshCreator.ePrismStacks.Text := '1';
  frmMeshCreator.ePrismName.Text := tmpMesh.Name;
  frmMeshCreator.DisablePrismEvents(False);
  frmMeshCreator.Visible := True;

  newObj.UpdateBoundingRadiusFromMesh;
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'DefaultPBRMaterial';
  tmpMesh.OnRender := MeshRenderHandler;
  newObj.NotifyChange;
  tmpMesh := nil;

  // Add to tree view
  if Assigned(parentNode) then
    newNode := scTree.Items.AddChild(parentNode, newObj.Name)
  else
    newNode := scTree.Items.Add(nil, newObj.Name);
  newNode.Data := newObj;

  scTree.FullExpand;
  scTree.Selected := newNode;

  frmMeshCreator.SelectedTreeNode := newNode;
  scTreeClick(scTree);
end;

procedure TMainForm.puNewSphereClick(Sender: TObject);
var
  parentNode: TTreeNode;
  parentObj: TSceneObject;
  newNode: TTreeNode;
  newObj: TSceneObject;
  baseName: string;
  idx: Integer;
  tmpMesh: TMesh;
begin
  if not Assigned(scTree.Selected) then
    parentNode := nil
  else
    parentNode := scTree.Selected;

  if Assigned(parentNode) and Assigned(parentNode.Data) then
    parentObj := TSceneObject(parentNode.Data)
  else
    parentObj := fRoot;

  fNewObjectMode := True;

  baseName := 'Sphere';
  idx := 1;
  newObj := nil;

  // Create the object
  newObj := TSceneObject.Create(parentObj);
  newObj.Name := baseName;

  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateSphere(0.5, 18, 18, baseName);
  newObj.MeshList.AddMeshToList(tmpMesh);
  EnsurePhysicsBodyForObject(newObj);

  // Form preparation
  frmMeshCreator.Top := pnlObjects.Top + 45;
  frmMeshCreator.Left := pnlObjects.Width + 10;
  frmMeshCreator.ClientWidth := 426;
  frmMeshCreator.ClientHeight := frmMeshCreator.pnlNewSphereMesh.Height;
  frmMeshCreator.pnlNewSphereMesh.Top := 0;
  frmMeshCreator.pnlNewSphereMesh.Left := 0;
  frmMeshCreator.DisableSphereEvents(True);
  frmMeshCreator.InternalObject := newObj;
  frmMeshCreator.SelectedMesh := tmpMesh;
  frmMeshCreator.Caption := 'Create Sphere';
  frmMeshCreator.eSphereRadius.Text := '0.50';
  frmMeshCreator.eSphereStackCount.Text := '18';
  frmMeshCreator.eSphereSliceCount.Text := '18';
  frmMeshCreator.eSphereName.Text := tmpMesh.Name;
  frmMeshCreator.DisableSphereEvents(False);
  frmMeshCreator.Visible := True;

  newObj.UpdateBoundingRadiusFromMesh;
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'DefaultPBRMaterial';
  tmpMesh.OnRender := MeshRenderHandler;
  newObj.NotifyChange;
  tmpMesh := nil;

  // Add to tree view
  if Assigned(parentNode) then
    newNode := scTree.Items.AddChild(parentNode, newObj.Name)
  else
    newNode := scTree.Items.Add(nil, newObj.Name);
  newNode.Data := newObj;

  scTree.FullExpand;
  scTree.Selected := newNode;

  frmMeshCreator.SelectedTreeNode := newNode;
  scTreeClick(scTree);
end;

procedure TMainForm.puNewSphereEllipsoidClick(Sender: TObject);
var
  parentNode: TTreeNode;
  parentObj: TSceneObject;
  newNode: TTreeNode;
  newObj: TSceneObject;
  baseName: string;
  idx: Integer;
  tmpMesh: TMesh;
begin
  if not Assigned(scTree.Selected) then
    parentNode := nil
  else
    parentNode := scTree.Selected;

  if Assigned(parentNode) and Assigned(parentNode.Data) then
    parentObj := TSceneObject(parentNode.Data)
  else
    parentObj := fRoot;

  fNewObjectMode := True;

  baseName := 'SphereEllipsoid';
  idx := 1;
  newObj := nil;

  // Create the object
  newObj := TSceneObject.Create(parentObj);
  newObj.Name := baseName;

  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateSuperellipsoid(1.0, 1.0, 1.0, 32, 32, baseName);
  newObj.MeshList.AddMeshToList(tmpMesh);
  EnsurePhysicsBodyForObject(newObj);

  // Form preparation
  frmMeshCreator.Top := pnlObjects.Top + 45;
  frmMeshCreator.Left := pnlObjects.Width + 10;
  frmMeshCreator.ClientWidth := 426;
  frmMeshCreator.ClientHeight := frmMeshCreator.pnlNewSuperEllipsoidMesh.Height;
  frmMeshCreator.pnlNewSuperEllipsoidMesh.Top := 0;
  frmMeshCreator.pnlNewSuperEllipsoidMesh.Left := 0;
  frmMeshCreator.DisableSuperEllipsoidEvents(True);
  frmMeshCreator.InternalObject := newObj;
  frmMeshCreator.SelectedMesh := tmpMesh;
  frmMeshCreator.Caption := 'Create GeodesicDome';
  frmMeshCreator.eSuperEllipsoidRadius.Text := '1.00';
  frmMeshCreator.eSuperEllipsoidVCurve.Text := '1.00';
  frmMeshCreator.eSuperEllipsoidHCurve.Text := '1.00';
  frmMeshCreator.eSuperEllipsoidSlices.Text := '32';
  frmMeshCreator.eSuperEllipsoidStacks.Text := '32';
  frmMeshCreator.eSuperEllipsoidName.Text := tmpMesh.Name;
  frmMeshCreator.DisableSuperEllipsoidEvents(False);
  frmMeshCreator.Visible := True;

  newObj.UpdateBoundingRadiusFromMesh;
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'DefaultPBRMaterial';
  tmpMesh.OnRender := MeshRenderHandler;
  newObj.NotifyChange;
  tmpMesh := nil;

  // Add to tree view
  if Assigned(parentNode) then
    newNode := scTree.Items.AddChild(parentNode, newObj.Name)
  else
    newNode := scTree.Items.Add(nil, newObj.Name);
  newNode.Data := newObj;

  scTree.FullExpand;
  scTree.Selected := newNode;

  frmMeshCreator.SelectedTreeNode := newNode;
  scTreeClick(scTree);
end;

procedure TMainForm.puNewStarEllipsoidClick(Sender: TObject);
var
  parentNode: TTreeNode;
  parentObj: TSceneObject;
  newNode: TTreeNode;
  newObj: TSceneObject;
  baseName: string;
  idx: Integer;
  tmpMesh: TMesh;
begin
  if not Assigned(scTree.Selected) then
    parentNode := nil
  else
    parentNode := scTree.Selected;

  if Assigned(parentNode) and Assigned(parentNode.Data) then
    parentObj := TSceneObject(parentNode.Data)
  else
    parentObj := fRoot;

  fNewObjectMode := True;

  baseName := 'StarEllipsoid';
  idx := 1;
  newObj := nil;

  // Create the object
  newObj := TSceneObject.Create(parentObj);
  newObj.Name := baseName;

  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateSuperellipsoid(1.0, 3.0, 3.0, 32, 32, baseName);
  newObj.MeshList.AddMeshToList(tmpMesh);
  EnsurePhysicsBodyForObject(newObj);

  // Form preparation
  frmMeshCreator.Top := pnlObjects.Top + 45;
  frmMeshCreator.Left := pnlObjects.Width + 10;
  frmMeshCreator.ClientWidth := 426;
  frmMeshCreator.ClientHeight := frmMeshCreator.pnlNewSuperEllipsoidMesh.Height;
  frmMeshCreator.pnlNewSuperEllipsoidMesh.Top := 0;
  frmMeshCreator.pnlNewSuperEllipsoidMesh.Left := 0;
  frmMeshCreator.DisableSuperEllipsoidEvents(True);
  frmMeshCreator.InternalObject := newObj;
  frmMeshCreator.SelectedMesh := tmpMesh;
  frmMeshCreator.Caption := 'Create GeodesicDome';
  frmMeshCreator.eSuperEllipsoidRadius.Text := '1.00';
  frmMeshCreator.eSuperEllipsoidVCurve.Text := '3.00';
  frmMeshCreator.eSuperEllipsoidHCurve.Text := '3.00';
  frmMeshCreator.eSuperEllipsoidSlices.Text := '32';
  frmMeshCreator.eSuperEllipsoidStacks.Text := '32';
  frmMeshCreator.eSuperEllipsoidName.Text := tmpMesh.Name;
  frmMeshCreator.DisableSuperEllipsoidEvents(False);
  frmMeshCreator.Visible := True;

  newObj.UpdateBoundingRadiusFromMesh;
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'DefaultPBRMaterial';
  tmpMesh.OnRender := MeshRenderHandler;
  newObj.NotifyChange;
  tmpMesh := nil;

  // Add to tree view
  if Assigned(parentNode) then
    newNode := scTree.Items.AddChild(parentNode, newObj.Name)
  else
    newNode := scTree.Items.Add(nil, newObj.Name);
  newNode.Data := newObj;

  scTree.FullExpand;
  scTree.Selected := newNode;

  frmMeshCreator.SelectedTreeNode := newNode;
  scTreeClick(scTree);
end;

procedure TMainForm.puNewTerrainClick(Sender: TObject);
var
  parentNode: TTreeNode;
  parentObj: TSceneObject;
  newNode: TTreeNode;
  newObj: TSceneObject;
  baseName: string;
  idx, i: Integer;
  tmpMesh: TMesh;
begin
  if not Assigned(scTree.Selected) then
    parentNode := nil
  else
    parentNode := scTree.Selected;

  if Assigned(parentNode) and Assigned(parentNode.Data) then
    parentObj := TSceneObject(parentNode.Data)
  else
    parentObj := fRoot;

  fNewObjectMode := True;

  baseName := 'Terrain';
  idx := 1;
  newObj := nil;

  // Create the object
  newObj := TSceneObject.Create(parentObj);
  newObj.Name := baseName;

  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateHeightFieldFromFile(TEnginePaths.Terrain('Default.bmp'), 32, 32, 5, 1, baseName);

  (tmpMesh as THeightFieldMesh).UpsampleHeights(4);
  //HeightField.TileSize := 64;

  newObj.MeshList.AddMeshToList(tmpMesh);
  EnsurePhysicsBodyForObject(newObj);

  // Form preparation
  frmMeshCreator.Top := pnlObjects.Top + 45;
  frmMeshCreator.Left := pnlObjects.Width + 10;
  frmMeshCreator.ClientWidth := 426;
  frmMeshCreator.ClientHeight := frmMeshCreator.pnlNewTerrainMesh.Height;
  frmMeshCreator.pnlNewTerrainMesh.Top := 0;
  frmMeshCreator.pnlNewTerrainMesh.Left := 0;
  frmMeshCreator.DisableTerrainEvents(True);
  frmMeshCreator.InternalObject := newObj;
  frmMeshCreator.SelectedMesh := tmpMesh;
  frmMeshCreator.Caption := 'Create Terrain';
  frmMeshCreator.eTerrainWidth.Text := '32.00';
  frmMeshCreator.eTerrainDepth.Text := '32.00';
  frmMeshCreator.eTerrainHeightScale.Text := '5.00';
  frmMeshCreator.eTerrainHeightMapWidth.Text := '32';
  frmMeshCreator.eTerrainHeightMapDepth.Text := '32';
  frmMeshCreator.eTerrainTileSize.Text := '64';
  frmMeshCreator.eTerrainSourceFile.Text := 'Default.bmp';
  frmMeshCreator.eTerrainName.Text := tmpMesh.Name;
  frmMeshCreator.DisableTerrainEvents(False);
  frmMeshCreator.Visible := True;

  newObj.UpdateBoundingRadiusFromMesh;
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'DefaultPBRMaterial';
  tmpMesh.OnRender := MeshRenderHandler;
  newObj.NotifyChange;
  tmpMesh := nil;

  // Add to tree view
  if Assigned(parentNode) then
    newNode := scTree.Items.AddChild(parentNode, newObj.Name)
  else
    newNode := scTree.Items.Add(nil, newObj.Name);
  newNode.Data := newObj;

  scTree.FullExpand;
  scTree.Selected := newNode;

  frmMeshCreator.SelectedTreeNode := newNode;
  scTreeClick(scTree);
end;

procedure TMainForm.puNewWaterClick(Sender: TObject);
var
  ParentNode: TTreeNode;
  ParentObj: TSceneObject;
  NewNode: TTreeNode;
  NewObj: TSceneObject;
  WaterMesh: TMesh;
begin
  if not Assigned(scTree.Selected) then
    ParentNode := nil
  else
    ParentNode := scTree.Selected;

  if Assigned(ParentNode) and Assigned(ParentNode.Data) then
    ParentObj := TSceneObject(ParentNode.Data)
  else
    ParentObj := fRoot;

  fNewObjectMode := False;

  NewObj := TSceneObject.Create(ParentObj);
  NewObj.Name := 'Water';

  ActivateMainRenderContext;
  WaterMesh := TMeshFactory.CreateWaterPlane(32.0, 32.0, 128, 128, 'WaterPlane');
  if Assigned(WaterMesh) then
  begin
    WaterMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
    WaterMesh.LibMaterialname := DefaultRenderableMaterialName;
    WaterMesh.OnRender := MeshRenderHandler;
    NewObj.MeshList.AddMeshToList(WaterMesh);
  end;

  NewObj.UpdateBoundingRadiusFromMesh;
  NewObj.NotifyChange;

  if Assigned(ParentNode) then
    NewNode := scTree.Items.AddChild(ParentNode, NewObj.Name)
  else
    NewNode := scTree.Items.Add(nil, NewObj.Name);
  NewNode.Data := NewObj;

  scTree.FullExpand;
  scTree.Selected := NewNode;
  scTreeClick(scTree);
end;

procedure TMainForm.puNewWaterPlaneClick(Sender: TObject);
var
  ParentNode: TTreeNode;
  ParentObj: TSceneObject;
  NewNode: TTreeNode;
  NewObj: TSceneObject;
  BaseName: string;
  TmpMesh: TMesh;
  WaterMesh: TWaterPlaneMesh;
begin
  if not Assigned(scTree.Selected) then
    ParentNode := nil
  else
    ParentNode := scTree.Selected;

  if Assigned(ParentNode) and Assigned(ParentNode.Data) then
    ParentObj := TSceneObject(ParentNode.Data)
  else
    ParentObj := fRoot;

  fNewObjectMode := True;

  BaseName := 'WaterPlane';
  NewObj := TSceneObject.Create(ParentObj);
  NewObj.Name := BaseName;

  ActivateMainRenderContext;
  TmpMesh := TMeshFactory.CreateWaterPlane(32.0, 32.0, 128, 128, BaseName);
  NewObj.MeshList.AddMeshToList(TmpMesh);

  TmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  TmpMesh.LibMaterialname := DefaultRenderableMaterialName;
  TmpMesh.OnRender := MeshRenderHandler;
  NewObj.UpdateBoundingRadiusFromMesh;
  NewObj.NotifyChange;

  EnsureMeshCreatorForm;
  frmMeshCreator.Top := pnlObjects.Top + 45;
  frmMeshCreator.Left := pnlObjects.Width + 10;
  frmMeshCreator.ClientWidth := 426;
  frmMeshCreator.ClientHeight := frmMeshCreator.pnlNewWaterPlaneMesh.Height;
  frmMeshCreator.pnlNewWaterPlaneMesh.Top := 0;
  frmMeshCreator.pnlNewWaterPlaneMesh.Left := 0;
  frmMeshCreator.DisableWaterPlaneEvents(True);
  frmMeshCreator.InternalObject := NewObj;
  frmMeshCreator.SelectedMesh := TmpMesh;
  frmMeshCreator.Caption := 'Create Water Plane';

  WaterMesh := TmpMesh as TWaterPlaneMesh;
  frmMeshCreator.eWaterPlaneName.Text := TmpMesh.Name;
  frmMeshCreator.eWaterPlaneWidth.Text := EditorFloatToText(WaterMesh.Width);
  frmMeshCreator.eWaterPlaneWidthSegments.Text := IntToStr(WaterMesh.WidthSegments);
  frmMeshCreator.eWaterPlaneDepth.Text := EditorFloatToText(WaterMesh.Depth);
  frmMeshCreator.eWaterPlaneDepthSegments.Text := IntToStr(WaterMesh.DepthSegments);
  frmMeshCreator.shpWaterPlaneTintColor.Brush.Color := Vec4ToColor(WaterMesh.TintColor);
  frmMeshCreator.shpWaterPlaneDeepthColor.Brush.Color := Vec4ToColor(WaterMesh.DeepColor);
  frmMeshCreator.eWaterPlaneReflectionStrength.Text := EditorFloatToText(WaterMesh.ReflectionStrength);
  frmMeshCreator.eWaterPlaneWaveScale.Text := EditorFloatToText(WaterMesh.WaveScale);
  frmMeshCreator.eWaterPlaneWaveSpeed.Text := EditorFloatToText(WaterMesh.WaveSpeed);
  frmMeshCreator.eWaterPlaneWaveStrength.Text := EditorFloatToText(WaterMesh.WaveStrength);
  frmMeshCreator.eWaterPlaneFrenselPower.Text := EditorFloatToText(WaterMesh.FresnelPower);
  frmMeshCreator.eWaterPlaneAlpha.Text := EditorFloatToText(WaterMesh.Alpha);
  frmMeshCreator.ResetWaterPlaneTransform;
  frmMeshCreator.DisableWaterPlaneEvents(False);
  frmMeshCreator.Visible := True;

  if Assigned(ParentNode) then
    NewNode := scTree.Items.AddChild(ParentNode, NewObj.Name)
  else
    NewNode := scTree.Items.Add(nil, NewObj.Name);
  NewNode.Data := NewObj;

  scTree.FullExpand;
  scTree.Selected := NewNode;

  frmMeshCreator.SelectedTreeNode := NewNode;
  scTreeClick(scTree);
end;

procedure TMainForm.puNewTorusClick(Sender: TObject);
var
  parentNode: TTreeNode;
  parentObj: TSceneObject;
  newNode: TTreeNode;
  newObj: TSceneObject;
  baseName: string;
  idx: Integer;
  tmpMesh: TMesh;
begin
  if not Assigned(scTree.Selected) then
    parentNode := nil
  else
    parentNode := scTree.Selected;

  if Assigned(parentNode) and Assigned(parentNode.Data) then
    parentObj := TSceneObject(parentNode.Data)
  else
    parentObj := fRoot;

  fNewObjectMode := True;

  baseName := 'Torus';
  idx := 1;
  newObj := nil;

  // Create the object
  newObj := TSceneObject.Create(parentObj);
  newObj.Name := baseName;

  ActivateMainRenderContext;
  tmpMesh := TMeshfactory.CreateTorus(0.5, 0.2, 18, 12, baseName);
  newObj.MeshList.AddMeshToList(tmpMesh);
  EnsurePhysicsBodyForObject(newObj);

  // Form preparation
  frmMeshCreator.Top := pnlObjects.Top + 45;
  frmMeshCreator.Left := pnlObjects.Width + 10;
  frmMeshCreator.ClientWidth := 426;
  frmMeshCreator.ClientHeight := frmMeshCreator.pnlNewTorusMesh.Height;
  frmMeshCreator.pnlNewTorusMesh.Top := 0;
  frmMeshCreator.pnlNewTorusMesh.Left := 0;
  frmMeshCreator.DisableTorusEvents(True);
  frmMeshCreator.InternalObject := newObj;
  frmMeshCreator.SelectedMesh := tmpMesh;
  frmMeshCreator.Caption := 'Create Torus';

  frmMeshCreator.eTorusMajorRadius.Text := '0.50';
  frmMeshCreator.eTorusMinorRadius.Text := '0.20';
  frmMeshCreator.eTorusMajorSegments.Text := '18';
  frmMeshCreator.eTorusMinorSegments.Text := '12';
  frmMeshCreator.eTorusName.Text := tmpMesh.Name;
  frmMeshCreator.DisableTorusEvents(False);
  frmMeshCreator.Visible := True;

  newObj.UpdateBoundingRadiusFromMesh;
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'DefaultPBRMaterial';
  tmpMesh.OnRender := MeshRenderHandler;
  newObj.NotifyChange;
  tmpMesh := nil;

  // Add to tree view
  if Assigned(parentNode) then
    newNode := scTree.Items.AddChild(parentNode, newObj.Name)
  else
    newNode := scTree.Items.Add(nil, newObj.Name);
  newNode.Data := newObj;

  scTree.FullExpand;
  scTree.Selected := newNode;

  frmMeshCreator.SelectedTreeNode := newNode;
  scTreeClick(scTree);
end;

procedure TMainForm.puPasteClick(Sender: TObject);
begin
  PasteNode;
end;

procedure TMainForm.puRenameClick(Sender: TObject);
begin
  if Assigned(scTree.Selected) then
    scTree.Selected.EditText;
end;

procedure TMainForm.UpdateUI;
begin
  if Assigned(fSelectedObject) then
  begin
    Old_ReadTransform;
    Old_ReadMeshes;
    Old_ReadPhysics;
  end
  else
  begin
    ResetTransformControls;
    ResetMeshes;
    ResetPhysicsControls;
  end;

  UpdateObjectCommandStates;
  UpdateSceneStatusBar;
end;

procedure TMainForm.UpdateSceneStatusBar;
var
  Obj: TSceneObject;
  FileName: string;

  function Fmt(Value: Single): string;
  begin
    Result := FormatFloat('0.##', Value);
  end;

  function VecText(const Prefix: string; const V: TVector3): string;
  begin
    Result := Format('%s X: %s Y: %s Z: %s',
      [Prefix, Fmt(V.X), Fmt(V.Y), Fmt(V.Z)]);
  end;

begin
  if sbScene = nil then
    Exit;

  Obj := fSelectedObject;

  if sbScene.Panels.Count > 0 then
  begin
    if Assigned(Obj) then
      sbScene.Panels[0].Text := 'Selected: ' + Obj.Name
    else
      sbScene.Panels[0].Text := 'Selected: ';
  end;

  if sbScene.Panels.Count > 1 then
  begin
    if Assigned(Obj) then
      sbScene.Panels[1].Text := VecText('Position:', Obj.Position)
    else
      sbScene.Panels[1].Text := 'Position:';
  end;

  if sbScene.Panels.Count > 2 then
  begin
    if Assigned(Obj) then
      sbScene.Panels[2].Text := VecText('Rotation:',
        Vector3(RadToDeg(Obj.Rotation.X), RadToDeg(Obj.Rotation.Y), RadToDeg(Obj.Rotation.Z)))
    else
      sbScene.Panels[2].Text := 'Rotation:';
  end;

  if sbScene.Panels.Count > 3 then
  begin
    if Assigned(Obj) then
      sbScene.Panels[3].Text := VecText('Scale:', Obj.Scale)
    else
      sbScene.Panels[3].Text := 'Scale:';
  end;

  if sbScene.Panels.Count > 4 then
  begin
    FileName := ExtractFileName(fCurrentSceneFileName);
    if FileName = '' then
      FileName := 'Untitled';
    sbScene.Panels[4].Text := 'File: ' + FileName;
  end;

  if sbScene.Panels.Count > 5 then
  begin
    if Assigned(fRenderer) then
    begin
      fRenderer.UpdateTriangleCount;
      sbScene.Panels[5].Text := Format('Triangles: %d', [fRenderer.TriangleCount]);
    end
    else
      sbScene.Panels[5].Text := 'Triangles: 0';
  end;
end;

procedure TMainForm.Old_ReadTransform;
begin
  ReadTransformControls(fSelectedObject);
end;

procedure TMainForm.Old_ReadMeshes;
begin
  ReadMeshes(fSelectedObject);
  if fLastPickedMeshIndex >= 0 then
    SelectMeshIndex(fLastPickedMeshIndex);
end;

procedure TMainForm.Old_ReadPhysics;
begin
  ReadPhysicsBody(EnsurePhysicsBodyForObject(fSelectedObject));
end;

procedure TMainForm.UpdateMeshEditor(const aClassName: String);
  function PanelClassName(const PanelName: String): String;
  begin
    Result := '';
    if Copy(PanelName, 1, 2) = 'cp' then
      Result := 'T' + Copy(PanelName, 3, MaxInt);
  end;
var
  i: Integer;
  h1, h2, h3: Integer;
  Panel: TCategoryPanel;
begin
  h1 := 0;
  h2 := 0;
  h3 := 0;

  for i := 0 to newMeshEditor.ControlCount -1 do
  begin
    if not (newMeshEditor.Controls[i] is TCategoryPanel) then
      Continue;

    Panel := TCategoryPanel(newMeshEditor.Controls[i]);
    if Panel.Name = 'cpMeshBase' then
    begin
      Panel.Collapsed := False;
      Panel.Visible := True;
      h1 := Panel.Height;
    end
    else if Panel.Name = 'cpMeshTransforms' then
    begin
      Panel.Collapsed := False;
      Panel.Visible := True;
      h2 := Panel.Height;
    end
    else if PanelClassName(Panel.Name) = aClassName then
    begin
      Panel.Collapsed := False;
      Panel.Visible := True;
      h3 := Panel.Height;
    end
    else
    begin
      Panel.Collapsed := True;
      Panel.Visible := False;
    end;
  end;

  newMeshEditor.Height := h1 + h2 + h3 + 2;
  newMeshEditor.Top := DebugControlBar.Height + 2;
  newMeshEditor.Left := pnlRenderingSurface.Width - newMeshEditor.Width;
  newMeshEditor.Visible := True;
end;

procedure TMainForm.ReadProperties(aMesh: TMesh); // MARK
var
  OldSuppress: Boolean;
begin
  if aMesh = nil then
  begin
    ResetMeshEditor;
    Exit;
  end;

  fSelectedMesh := aMesh;
  OldSuppress := fSuppressMeshEditorChange;
  UnhookMeshEditorEvents;
  fSuppressMeshEditorChange := True;
  try
    if aMesh.MeshType = mtWater then
      UpdateMeshEditor('TPlaneMesh')
    else
      UpdateMeshEditor(aMesh.ClassName);
    ReadMeshBase(aMesh);
    ReadTransform(aMesh);

    case aMesh.MeshType of
      mtEmpty: ;
      mtFile: ReadFile(aMesh as TFileMesh);
      mtPlane: ReadPlane(aMesh as TPlaneMesh);
      mtWater: ReadPlane(aMesh as TPlaneMesh);
      mtCube: ReadCube(aMesh as TCubeMesh);
      mtSphere: ReadSphere(aMesh as TSphereMesh);
      mtCylinder: ReadCylinder(aMesh as TCylinderMesh);
      mtCapsule: ReadCapsule(aMesh as TCapsuleMesh);
      mtTorus: ReadTorus(aMesh as TTorusMesh);
      mtCone: ReadCone(aMesh as TConeMesh);
      mtPrism: ReadPrism(aMesh as TPrismMesh);
      mtFrustum: ReadFrustum(aMesh as TFrustumMesh);
      mtIcosphere: ReadIcosphere(aMesh as TIcosphereMesh);
      mtGeodesicDome: ReadGeodesicDome(aMesh as TGeodesicDomeMesh);
      mtGizmo: ;
      mtArrow: ReadArrow(aMesh as TArrowMesh);
      mtSuperEllipsoid: ReadSuperEllipsoid(aMesh as TSuperEllipsoidMesh);
      mtHeightField: ReadHeightField(aMesh as THeightFieldMesh);
    end;
  finally
    fSuppressMeshEditorChange := OldSuppress;
    HookMeshEditorEvents;
  end;
end;

procedure TMainForm.ReadMeshBase(aMesh: TMesh);
begin
  eMeshName.Text := aMesh.Name;
  cbOrigin.ItemIndex := MeshCenterPresetIndex(aMesh.GetPresetAtPoint(Vector3(0, 0, 0)));
  FillMeshMaterialControls(aMesh);
  eU.Text := '1.00';
  eV.Text := '1.00';
end;

procedure TMainForm.ReadTransform(aMesh: TMesh);
begin
  SetMeshEditorTransformValues(aMesh.Position,
    Vector3(RadToDeg(aMesh.Rotation.X), RadToDeg(aMesh.Rotation.Y), RadToDeg(aMesh.Rotation.Z)),
    aMesh.Scale, False);
end;


procedure TMainForm.ReadPlane(aMesh: TPlaneMesh);
begin
  ePlaneWidth.Text := EditorFloatToText(aMesh.Width);
  ePlaneDepth.Text := EditorFloatToText(aMesh.Depth);
  ePlaneWidthSegments.Text := IntToStr(aMesh.WidthSegments);
  ePlaneDepthSegments.Text := IntToStr(aMesh.DepthSegments);
end;

procedure TMainForm.ReadCube(aMesh: TCubeMesh);
begin
  eCubeMeshWidth.Text := EditorFloatToText(aMesh.Width);
  eCubeMeshHeight.Text := EditorFloatToText(aMesh.Height);
  eCubeMeshDepth.Text := EditorFloatToText(aMesh.Depth);
  eCubeMeshStacks.Text := IntToStr(aMesh.WidthStacks);
  eCubeMeshHeightStacks.Text := IntToStr(aMesh.HeightStacks);
  eCubeMeshDepthStacks.Text := IntToStr(aMesh.DepthStacks);
end;

procedure TMainForm.ReadSphere(aMesh: TSphereMesh);
begin
  eSphereMeshRadius.Text := EditorFloatToText(aMesh.Radius);
  eSphereMeshStacks.Text := IntToStr(aMesh.StackCount);
  eSphereMeshSlices.Text := IntToStr(aMesh.SliceCount);
end;

procedure TMainForm.ReadCylinder(aMesh: TCylinderMesh);
begin
  eCylinderMeshRadius.Text := EditorFloatToText(aMesh.Radius);
  eCylinderMeshHeight.Text := EditorFloatToText(aMesh.Height);
  eCylinderMeshSlices.Text := IntToStr(aMesh.Slices);
  eCylinderMeshStacks.Text := IntToStr(aMesh.Stacks);
  SetMeshCapCombo(cbCylinderMeshBottomCap, aMesh.BottomCap);
  SetMeshCapCombo(cbCylinderMeshTopCap, aMesh.TopCap);
end;

procedure TMainForm.ReadCapsule(aMesh: TCapsuleMesh);
begin
  eCapsuleMeshRadius.Text := EditorFloatToText(aMesh.Radius);
  eCapsuleMeshHeight.Text := EditorFloatToText(aMesh.Height);
  eCapsuleMeshSlices.Text := IntToStr(aMesh.Slices);
  eCapsuleMeshStacks.Text := IntToStr(aMesh.Stacks);
end;

procedure TMainForm.ReadTorus(aMesh: TTorusMesh);
begin
  eTorusMeshMajor.Text := EditorFloatToText(aMesh.MajorRadius);
  eTorusMeshMinor.Text := EditorFloatToText(aMesh.MinorRadius);
  eTorusMeshMajorSegments.Text := IntToStr(aMesh.MajorSegments);
  eTorusMeshMinorSegments.Text := IntToStr(aMesh.MinorSegments);
end;

procedure TMainForm.ReadCone(aMesh: TConeMesh);
begin
  eConeMeshRadius.Text := EditorFloatToText(aMesh.Radius);
  eConeMeshHeight.Text := EditorFloatToText(aMesh.Height);
  eConeMeshSides.Text := IntToStr(aMesh.Sides);
  eConeMeshStacks.Text := IntToStr(aMesh.Stacks);
  SetMeshCapCombo(cbConeMeshBottomCap, aMesh.BottomCap);
end;

procedure TMainForm.ReadPrism(aMesh: TPrismMesh);
begin
  ePrismMeshRadius.Text := EditorFloatToText(aMesh.Radius);
  ePrismMeshHeight.Text := EditorFloatToText(aMesh.Height);
  ePrismMeshSides.Text := IntToStr(aMesh.Sides);
  ePrismMeshStacks.Text := IntToStr(aMesh.Stacks);
end;

procedure TMainForm.ReadFrustum(aMesh: TFrustumMesh);
begin
  eFrustumMeshBottomRadius.Text := EditorFloatToText(aMesh.BottomRadius);
  eFrustumMeshTopRadius.Text := EditorFloatToText(aMesh.TopRadius);
  eFrustumMeshHeight.Text := EditorFloatToText(aMesh.Height);
  eFrustumMeshSlices.Text := IntToStr(aMesh.Slices);
  eFrustumMeshStacks.Text := IntToStr(aMesh.Stacks);
  SetMeshCapCombo(cbFrustumMeshBottomCap, aMesh.BottomCap);
  SetMeshCapCombo(cbFrustumMeshTopCap, aMesh.TopCap);
end;

procedure TMainForm.ReadIcosphere(aMesh: TIcosphereMesh);
begin
  eIcosphereMeshRadius.Text := EditorFloatToText(aMesh.Radius);
  eIcosphereMeshSubdivisions.Text := IntToStr(aMesh.Subdivisions);
end;

procedure TMainForm.ReadGeodesicDome(aMesh: TGeodesicDomeMesh);
begin
  eGeodesicDomeMeshRadius.Text := EditorFloatToText(aMesh.Radius);
  eGeodesicDomeMeshSubdivisions.Text := IntToStr(aMesh.Subdivisions);
end;

procedure TMainForm.ReadArrow(aMesh: TArrowMesh);
begin
  eArrowMeshShaftLength.Text := EditorFloatToText(aMesh.ShaftLength);
  eArrowMeshTipLength.Text := EditorFloatToText(aMesh.TipLength);
  eArrowMeshShaftRadius.Text := EditorFloatToText(aMesh.ShaftRadius);
  eArrowMeshTipRadius.Text := EditorFloatToText(aMesh.TipRadius);
  eArrowMeshSlices.Text := IntToStr(aMesh.Slices);
  eArrowMeshStacks.Text := IntToStr(aMesh.Stacks);
end;

procedure TMainForm.ReadSuperEllipsoid(aMesh: TSuperEllipsoidMesh);
begin
  eSuperEllipsoidMeshRadius.Text := EditorFloatToText(aMesh.Radius);
  eSuperEllipsoidMeshVCurve.Text := EditorFloatToText(aMesh.VCurve);
  eSuperEllipsoidMeshHCurve.Text := EditorFloatToText(aMesh.HCurve);
  eSuperEllipsoidMeshSlices.Text := IntToStr(aMesh.Slices);
  eSuperEllipsoidMeshStacks.Text := IntToStr(aMesh.Stacks);
end;

procedure TMainForm.ReadHeightField(aMesh: THeightFieldMesh);
begin
  eHeightFieldMeshWidth.Text := EditorFloatToText(aMesh.Width);
  eHeightFieldMeshDepth.Text := EditorFloatToText(aMesh.Depth);
  eHeightFieldMeshHeightScale.Text := EditorFloatToText(aMesh.HeightScale);
  eHeightFieldMeshUVScale.Text := EditorFloatToText(aMesh.UVScale);
  eHeightFieldMeshMapWidth.Text := IntToStr(aMesh.HeightMapWidth);
  eHeightFieldMeshMapDepth.Text := IntToStr(aMesh.HeightMapDepth);
  eHeightFieldMeshSourceFile.Text := ExtractFileName(aMesh.SourceFile);
  eHeightFieldMeshTileSize.Text := IntToStr(aMesh.TileSize);
  chbHeightFieldMeshEnableLOD.Checked := aMesh.LODEnabled;
  eHeightFieldMeshLODDistance.Text := EditorFloatToText(aMesh.LODDistance);
  eHeightFieldMeshLODCount.Text := IntToStr(aMesh.LODCount);
  eHeightFieldMeshLODDistance.Enabled := aMesh.LODEnabled;
  eHeightFieldMeshLODCount.Enabled := aMesh.LODEnabled;
end;

procedure TMainForm.ReadFile(aMesh: TFileMesh);
begin
  eFileMeshFileName.Text := aMesh.SourceFile;
end;

procedure TMainForm.ResetMeshEditor;
var
  I: Integer;
  Panel: TCategoryPanel;
  OldSuppress: Boolean;
begin
  OldSuppress := fSuppressMeshEditorChange;
  UnhookMeshEditorEvents;
  fSuppressMeshEditorChange := True;
  try
    newMeshEditor.Visible := False;
    for I := 0 to newMeshEditor.ControlCount - 1 do
      if newMeshEditor.Controls[I] is TCategoryPanel then
      begin
        Panel := TCategoryPanel(newMeshEditor.Controls[I]);
        Panel.Collapsed := True;
        Panel.Visible := False;
      end;

    eMeshName.Text := '';
    cbMaterialLibrary.Clear;
    cbMaterialLibrary.Repaint;
    cbLibraryName.Clear;
    cbLibraryName.Repaint;
    cbOrigin.ItemIndex := 0;
    eU.Text := '1.00';
    eV.Text := '1.00';
    eMeshPositionX.Text := '0.00';
    eMeshPositionY.Text := '0.00';
    eMeshPositionZ.Text := '0.00';
    eMeshRotationX.Text := '0.00';
    eMeshRotationY.Text := '0.00';
    eMeshRotationZ.Text := '0.00';
    eMeshScaleX.Text := '1.00';
    eMeshScaleY.Text := '1.00';
    eMeshScaleZ.Text := '1.00';
    eHeightFieldMeshWidth.Text := '1.00';
    eHeightFieldMeshDepth.Text := '1.00';
    eHeightFieldMeshHeightScale.Text := '1.00';
    eHeightFieldMeshUVScale.Text := '1.00';
    eHeightFieldMeshMapWidth.Text := '';
    eHeightFieldMeshMapDepth.Text := '';
    eHeightFieldMeshSourceFile.Text := '';
    eHeightFieldMeshTileSize.Text := '32';
    chbHeightFieldMeshEnableLOD.Checked := True;
    eHeightFieldMeshLODDistance.Text := '4.00';
    eHeightFieldMeshLODCount.Text := '5';
    eHeightFieldMeshLODDistance.Enabled := True;
    eHeightFieldMeshLODCount.Enabled := True;
  finally
    fSuppressMeshEditorChange := OldSuppress;
    HookMeshEditorEvents;
    pnlMeshBase.Repaint;
  end;
end;

procedure TMainForm.UnhookMeshEditorEvents;
begin
  eMeshName.OnChange := nil;
  cbOrigin.OnChange := nil;
  cbMaterialLibrary.OnChange := nil;
  cbLibraryName.OnChange := nil;
  btnApplyUV.OnClick := nil;

  eMeshPositionX.OnChange := nil;
  eMeshPositionY.OnChange := nil;
  eMeshPositionZ.OnChange := nil;
  eMeshRotationX.OnChange := nil;
  eMeshRotationY.OnChange := nil;
  eMeshRotationZ.OnChange := nil;
  eMeshScaleX.OnChange := nil;
  eMeshScaleY.OnChange := nil;
  eMeshScaleZ.OnChange := nil;

  ePlaneWidth.OnChange := nil;
  ePlaneDepth.OnChange := nil;
  ePlaneWidthSegments.OnChange := nil;
  ePlaneDepthSegments.OnChange := nil;

  eCubeMeshWidth.OnChange := nil;
  eCubeMeshHeight.OnChange := nil;
  eCubeMeshDepth.OnChange := nil;
  eCubeMeshStacks.OnChange := nil;
  eCubeMeshHeightStacks.OnChange := nil;
  eCubeMeshDepthStacks.OnChange := nil;

  eSphereMeshRadius.OnChange := nil;
  eSphereMeshStacks.OnChange := nil;
  eSphereMeshSlices.OnChange := nil;

  eCylinderMeshRadius.OnChange := nil;
  eCylinderMeshHeight.OnChange := nil;
  eCylinderMeshSlices.OnChange := nil;
  eCylinderMeshStacks.OnChange := nil;
  cbCylinderMeshBottomCap.OnChange := nil;
  cbCylinderMeshTopCap.OnChange := nil;

  eCapsuleMeshRadius.OnChange := nil;
  eCapsuleMeshHeight.OnChange := nil;
  eCapsuleMeshSlices.OnChange := nil;
  eCapsuleMeshStacks.OnChange := nil;

  eTorusMeshMajor.OnChange := nil;
  eTorusMeshMinor.OnChange := nil;
  eTorusMeshMajorSegments.OnChange := nil;
  eTorusMeshMinorSegments.OnChange := nil;

  eConeMeshRadius.OnChange := nil;
  eConeMeshHeight.OnChange := nil;
  eConeMeshSides.OnChange := nil;
  eConeMeshStacks.OnChange := nil;
  cbConeMeshBottomCap.OnChange := nil;

  ePrismMeshRadius.OnChange := nil;
  ePrismMeshHeight.OnChange := nil;
  ePrismMeshSides.OnChange := nil;
  ePrismMeshStacks.OnChange := nil;

  eFrustumMeshBottomRadius.OnChange := nil;
  eFrustumMeshTopRadius.OnChange := nil;
  eFrustumMeshHeight.OnChange := nil;
  eFrustumMeshSlices.OnChange := nil;
  eFrustumMeshStacks.OnChange := nil;
  cbFrustumMeshBottomCap.OnChange := nil;
  cbFrustumMeshTopCap.OnChange := nil;

  eIcosphereMeshRadius.OnChange := nil;
  eIcosphereMeshSubdivisions.OnChange := nil;
  eGeodesicDomeMeshRadius.OnChange := nil;
  eGeodesicDomeMeshSubdivisions.OnChange := nil;

  eArrowMeshShaftLength.OnChange := nil;
  eArrowMeshTipLength.OnChange := nil;
  eArrowMeshShaftRadius.OnChange := nil;
  eArrowMeshTipRadius.OnChange := nil;
  eArrowMeshSlices.OnChange := nil;
  eArrowMeshStacks.OnChange := nil;

  eSuperEllipsoidMeshRadius.OnChange := nil;
  eSuperEllipsoidMeshVCurve.OnChange := nil;
  eSuperEllipsoidMeshHCurve.OnChange := nil;
  eSuperEllipsoidMeshSlices.OnChange := nil;
  eSuperEllipsoidMeshStacks.OnChange := nil;

  eHeightFieldMeshWidth.OnChange := nil;
  eHeightFieldMeshDepth.OnChange := nil;
  eHeightFieldMeshHeightScale.OnChange := nil;
  eHeightFieldMeshUVScale.OnChange := nil;
  eHeightFieldMeshMapWidth.OnChange := nil;
  eHeightFieldMeshMapDepth.OnChange := nil;
  eHeightFieldMeshSourceFile.OnChange := nil;
  eHeightFieldMeshTileSize.OnChange := nil;
  chbHeightFieldMeshEnableLOD.OnClick := nil;
  eHeightFieldMeshLODDistance.OnChange := nil;
  eHeightFieldMeshLODCount.OnChange := nil;
  sbHeightFieldMeshSourceFile.OnClick := nil;

  eFileMeshFileName.OnChange := nil;
end;

procedure TMainForm.HookMeshEditorEvents;
begin
  eMeshName.OnChange := MeshNameChange;
  cbOrigin.OnChange := MeshOriginChange;
  cbMaterialLibrary.OnChange := MeshMaterialLibraryChange;
  cbLibraryName.OnChange := MeshLibraryNameChange;
  btnApplyUV.OnClick := MeshApplyUVClick;

  eMeshPositionX.OnChange := MeshTransformChange;
  eMeshPositionY.OnChange := MeshTransformChange;
  eMeshPositionZ.OnChange := MeshTransformChange;
  eMeshRotationX.OnChange := MeshTransformChange;
  eMeshRotationY.OnChange := MeshTransformChange;
  eMeshRotationZ.OnChange := MeshTransformChange;
  eMeshScaleX.OnChange := MeshTransformChange;
  eMeshScaleY.OnChange := MeshTransformChange;
  eMeshScaleZ.OnChange := MeshTransformChange;

  ePlaneWidth.OnChange := MeshShapeChange;
  ePlaneDepth.OnChange := MeshShapeChange;
  ePlaneWidthSegments.OnChange := MeshShapeChange;
  ePlaneDepthSegments.OnChange := MeshShapeChange;

  eCubeMeshWidth.OnChange := MeshShapeChange;
  eCubeMeshHeight.OnChange := MeshShapeChange;
  eCubeMeshDepth.OnChange := MeshShapeChange;
  eCubeMeshStacks.OnChange := MeshShapeChange;
  eCubeMeshHeightStacks.OnChange := MeshShapeChange;
  eCubeMeshDepthStacks.OnChange := MeshShapeChange;

  eSphereMeshRadius.OnChange := MeshShapeChange;
  eSphereMeshStacks.OnChange := MeshShapeChange;
  eSphereMeshSlices.OnChange := MeshShapeChange;

  eCylinderMeshRadius.OnChange := MeshShapeChange;
  eCylinderMeshHeight.OnChange := MeshShapeChange;
  eCylinderMeshSlices.OnChange := MeshShapeChange;
  eCylinderMeshStacks.OnChange := MeshShapeChange;
  cbCylinderMeshBottomCap.OnChange := MeshShapeChange;
  cbCylinderMeshTopCap.OnChange := MeshShapeChange;

  eCapsuleMeshRadius.OnChange := MeshShapeChange;
  eCapsuleMeshHeight.OnChange := MeshShapeChange;
  eCapsuleMeshSlices.OnChange := MeshShapeChange;
  eCapsuleMeshStacks.OnChange := MeshShapeChange;

  eTorusMeshMajor.OnChange := MeshShapeChange;
  eTorusMeshMinor.OnChange := MeshShapeChange;
  eTorusMeshMajorSegments.OnChange := MeshShapeChange;
  eTorusMeshMinorSegments.OnChange := MeshShapeChange;

  eConeMeshRadius.OnChange := MeshShapeChange;
  eConeMeshHeight.OnChange := MeshShapeChange;
  eConeMeshSides.OnChange := MeshShapeChange;
  eConeMeshStacks.OnChange := MeshShapeChange;
  cbConeMeshBottomCap.OnChange := MeshShapeChange;

  ePrismMeshRadius.OnChange := MeshShapeChange;
  ePrismMeshHeight.OnChange := MeshShapeChange;
  ePrismMeshSides.OnChange := MeshShapeChange;
  ePrismMeshStacks.OnChange := MeshShapeChange;

  eFrustumMeshBottomRadius.OnChange := MeshShapeChange;
  eFrustumMeshTopRadius.OnChange := MeshShapeChange;
  eFrustumMeshHeight.OnChange := MeshShapeChange;
  eFrustumMeshSlices.OnChange := MeshShapeChange;
  eFrustumMeshStacks.OnChange := MeshShapeChange;
  cbFrustumMeshBottomCap.OnChange := MeshShapeChange;
  cbFrustumMeshTopCap.OnChange := MeshShapeChange;

  eIcosphereMeshRadius.OnChange := MeshShapeChange;
  eIcosphereMeshSubdivisions.OnChange := MeshShapeChange;
  eGeodesicDomeMeshRadius.OnChange := MeshShapeChange;
  eGeodesicDomeMeshSubdivisions.OnChange := MeshShapeChange;

  eArrowMeshShaftLength.OnChange := MeshShapeChange;
  eArrowMeshTipLength.OnChange := MeshShapeChange;
  eArrowMeshShaftRadius.OnChange := MeshShapeChange;
  eArrowMeshTipRadius.OnChange := MeshShapeChange;
  eArrowMeshSlices.OnChange := MeshShapeChange;
  eArrowMeshStacks.OnChange := MeshShapeChange;

  eSuperEllipsoidMeshRadius.OnChange := MeshShapeChange;
  eSuperEllipsoidMeshVCurve.OnChange := MeshShapeChange;
  eSuperEllipsoidMeshHCurve.OnChange := MeshShapeChange;
  eSuperEllipsoidMeshSlices.OnChange := MeshShapeChange;
  eSuperEllipsoidMeshStacks.OnChange := MeshShapeChange;

  eHeightFieldMeshWidth.OnChange := MeshShapeChange;
  eHeightFieldMeshDepth.OnChange := MeshShapeChange;
  eHeightFieldMeshHeightScale.OnChange := MeshShapeChange;
  eHeightFieldMeshUVScale.OnChange := MeshShapeChange;
  eHeightFieldMeshMapWidth.OnChange := MeshShapeChange;
  eHeightFieldMeshMapDepth.OnChange := MeshShapeChange;
  eHeightFieldMeshSourceFile.OnChange := MeshShapeChange;
  eHeightFieldMeshTileSize.OnChange := MeshShapeChange;
  chbHeightFieldMeshEnableLOD.OnClick := MeshShapeChange;
  eHeightFieldMeshLODDistance.OnChange := MeshShapeChange;
  eHeightFieldMeshLODCount.OnChange := MeshShapeChange;
  sbHeightFieldMeshSourceFile.OnClick := HeightFieldMeshSourceFileClick;

  eFileMeshFileName.OnChange := MeshShapeChange;
end;

procedure TMainForm.NotifyMeshEditorChanged(const RefreshProperties: Boolean);
begin
  if Assigned(fSelectedObject) then
  begin
    fSelectedObject.UpdateWorldMatrices;
    if Assigned(fSelectedMesh) then
      fSelectedMesh.ParentModelMatrix := fSelectedObject.WorldMatrix;
    fSelectedObject.UpdateBoundingRadiusFromMesh;
    fSelectedObject.NotifyChange;
  end;

  if Assigned(fSceneManager) then
    fSceneManager.Update;

  RefreshPhysicsDebugHull;
  if RefreshProperties and Assigned(fSelectedMesh) then
    ReadProperties(fSelectedMesh);
  RefreshGizmo;
  UpdateSceneStatusBar;
  if Assigned(fRenderer) then
    fRenderer.Render;
end;

function TMainForm.SelectedMeshIndex: Integer;
begin
  Result := -1;
  if Assigned(fSelectedObject) and Assigned(fSelectedMesh) then
    Result := fSelectedObject.MeshList.IndexOf(fSelectedMesh);

  if (Result < 0) and Assigned(fSelectedObject) and
     (lbMeshes.ItemIndex >= 0) and (lbMeshes.ItemIndex < fSelectedObject.MeshList.Count) then
    Result := lbMeshes.ItemIndex;
end;

function TMainForm.GetMeshEditorTransformValues(out Translation, RotationDeg,
  Scale: TVector3): Boolean;
var
  PX, PY, PZ: Single;
  RX, RY, RZ: Single;
  SX, SY, SZ: Single;
begin
  Result := False;

  if not TryReadEditorFloat(eMeshPositionX, 'Mesh position X', PX, False) then Exit;
  if not TryReadEditorFloat(eMeshPositionY, 'Mesh position Y', PY, False) then Exit;
  if not TryReadEditorFloat(eMeshPositionZ, 'Mesh position Z', PZ, False) then Exit;
  if not TryReadEditorFloat(eMeshRotationX, 'Mesh rotation X', RX, False) then Exit;
  if not TryReadEditorFloat(eMeshRotationY, 'Mesh rotation Y', RY, False) then Exit;
  if not TryReadEditorFloat(eMeshRotationZ, 'Mesh rotation Z', RZ, False) then Exit;
  if not TryReadEditorFloat(eMeshScaleX, 'Mesh scale X', SX, False) then Exit;
  if not TryReadEditorFloat(eMeshScaleY, 'Mesh scale Y', SY, False) then Exit;
  if not TryReadEditorFloat(eMeshScaleZ, 'Mesh scale Z', SZ, False) then Exit;

  Translation := Vector3(PX, PY, PZ);
  RotationDeg := Vector3(RX, RY, RZ);
  Scale := Vector3(SX, SY, SZ);
  Result := True;
end;

procedure TMainForm.SetMeshEditorTransformValues(const Translation, RotationDeg,
  Scale: TVector3; const Preview: Boolean);
var
  OldSuppress: Boolean;
begin
  OldSuppress := fSuppressMeshEditorChange;
  fSuppressMeshEditorChange := True;
  try
    eMeshPositionX.Text := EditorFloatToText(Translation.X);
    eMeshPositionY.Text := EditorFloatToText(Translation.Y);
    eMeshPositionZ.Text := EditorFloatToText(Translation.Z);
    eMeshRotationX.Text := EditorFloatToText(RotationDeg.X);
    eMeshRotationY.Text := EditorFloatToText(RotationDeg.Y);
    eMeshRotationZ.Text := EditorFloatToText(RotationDeg.Z);
    eMeshScaleX.Text := EditorFloatToText(Scale.X);
    eMeshScaleY.Text := EditorFloatToText(Scale.Y);
    eMeshScaleZ.Text := EditorFloatToText(Scale.Z);
  finally
    fSuppressMeshEditorChange := OldSuppress;
  end;

  if Preview then
    MeshTransformChange(nil);
end;

function TMainForm.MeshCenterPresetIndex(aPreset: TMeshCenterPreset): Integer;
begin
  case aPreset of
    cpCenter: Result := 0;
    cpLeftTopMiddle: Result := 1;
    cpLeftMiddleMiddle: Result := 2;
    cpLeftBottomMiddle: Result := 3;
    cpFrontTopLeft: Result := 4;
    cpFrontTopMiddle: Result := 5;
    cpFrontTopRight: Result := 6;
    cpFrontMiddleLeft: Result := 7;
    cpFrontMiddleMiddle: Result := 8;
    cpFrontMiddleRight: Result := 9;
    cpFrontBottomLeft: Result := 10;
    cpFrontBottomMiddle: Result := 11;
    cpFrontBottomRight: Result := 12;
    cpRightTopMiddle: Result := 13;
    cpRightMiddleMiddle: Result := 14;
    cpRightBottomMiddle: Result := 15;
    cpBackTopLeft: Result := 16;
    cpBackTopMiddle: Result := 17;
    cpBackTopRight: Result := 18;
    cpBackMiddleLeft: Result := 19;
    cpBackMiddleMiddle: Result := 20;
    cpBackMiddleRight: Result := 21;
    cpBackBottomLeft: Result := 22;
    cpBackBottomMiddle: Result := 23;
    cpBackBottomRight: Result := 24;
  else
    Result := 0;
  end;
end;

function TMainForm.MeshCenterPresetByIndex(const AIndex: Integer): TMeshCenterPreset;
begin
  case AIndex of
    0: Result := cpCenter;
    1: Result := cpLeftTopMiddle;
    2: Result := cpLeftMiddleMiddle;
    3: Result := cpLeftBottomMiddle;
    4: Result := cpFrontTopLeft;
    5: Result := cpFrontTopMiddle;
    6: Result := cpFrontTopRight;
    7: Result := cpFrontMiddleLeft;
    8: Result := cpFrontMiddleMiddle;
    9: Result := cpFrontMiddleRight;
    10: Result := cpFrontBottomLeft;
    11: Result := cpFrontBottomMiddle;
    12: Result := cpFrontBottomRight;
    13: Result := cpRightTopMiddle;
    14: Result := cpRightMiddleMiddle;
    15: Result := cpRightBottomMiddle;
    16: Result := cpBackTopLeft;
    17: Result := cpBackTopMiddle;
    18: Result := cpBackTopRight;
    19: Result := cpBackMiddleLeft;
    20: Result := cpBackMiddleMiddle;
    21: Result := cpBackMiddleRight;
    22: Result := cpBackBottomLeft;
    23: Result := cpBackBottomMiddle;
    24: Result := cpBackBottomRight;
  else
    Result := cpCenter;
  end;
end;

function TMainForm.MeshCapFromCombo(Combo: TComboBox): TCapType;
begin
  case Combo.ItemIndex of
    1: Result := Engine.Types.ctCenter;
    2: Result := Engine.Types.ctFlat;
  else
    Result := Engine.Types.ctNone;
  end;
end;

procedure TMainForm.SetMeshCapCombo(Combo: TComboBox; Cap: TCapType);
begin
  Combo.ItemIndex := Ord(Cap);
end;

procedure TMainForm.FillMeshMaterialControls(aMesh: TMesh);
var
  I: Integer;
  Lib: TMaterialLibrary;
  LibIndex: Integer;
begin
  EnsureDefaultMaterialLibrary;
  cbMaterialLibrary.Items.BeginUpdate;
  cbMaterialLibrary.Repaint;
  cbLibraryName.Items.BeginUpdate;
  cbLibraryName.Repaint;
  try
    cbMaterialLibrary.Clear;
    cbMaterialLibrary.Repaint;
    cbLibraryName.Clear;
    cbLibraryName.Repaint;

    if Assigned(MaterialLibraries) then
      for I := 0 to MaterialLibraries.Count - 1 do
      begin
        Lib := MaterialLibraries.MaterialLibrary[I];
        if Assigned(Lib) then
          cbMaterialLibrary.Items.AddObject(Lib.Name, Lib);
      end;

    LibIndex := -1;
    if Assigned(aMesh.MaterialLibrary) then
      LibIndex := cbMaterialLibrary.Items.IndexOfObject(aMesh.MaterialLibrary);
    if (LibIndex < 0) and (cbMaterialLibrary.Items.Count > 0) then
      LibIndex := 0;
    cbMaterialLibrary.ItemIndex := LibIndex;

    if LibIndex >= 0 then
    begin
      Lib := TMaterialLibrary(cbMaterialLibrary.Items.Objects[LibIndex]);
      for I := 0 to Lib.Count - 1 do
        if Assigned(Lib.Material[I]) and (not IsEditorOnlyMaterial(Lib.Material[I])) then
          cbLibraryName.Items.Add(Lib.Material[I].Name);
      cbLibraryName.ItemIndex := cbLibraryName.Items.IndexOf(aMesh.LibMaterialname);
    end;
  finally
    cbLibraryName.Items.EndUpdate;
    cbLibraryName.Repaint;
    cbMaterialLibrary.Items.EndUpdate;
    cbMaterialLibrary.Repaint;
    pnlMeshBase.Repaint;
  end;
end;

procedure TMainForm.MeshNameChange(Sender: TObject);
var
  Index: Integer;
begin
  if fSuppressMeshEditorChange or not Assigned(fSelectedMesh) then
    Exit;

  fSelectedMesh.Name := eMeshName.Text;
  Index := SelectedMeshIndex;
  RefreshMeshList;
  if (Index >= 0) and (Index < lbMeshes.Items.Count) then
    lbMeshes.ItemIndex := Index;
  NotifyMeshEditorChanged(False);
end;

procedure TMainForm.MeshOriginChange(Sender: TObject);
begin
  if fSuppressMeshEditorChange or not Assigned(fSelectedMesh) or
     (cbOrigin.ItemIndex < 0) then
    Exit;

  fSelectedMesh.SetPositionByPreset(MeshCenterPresetByIndex(cbOrigin.ItemIndex),
    Vector3(0, 0, 0));
  NotifyMeshEditorChanged(True);
end;

procedure TMainForm.MeshMaterialLibraryChange(Sender: TObject);
var
  Lib: TMaterialLibrary;
  I, NameIndex: Integer;
  OldSuppress: Boolean;
begin
  if fSuppressMeshEditorChange or not Assigned(fSelectedMesh) or
     (cbMaterialLibrary.ItemIndex < 0) then
    Exit;

  Lib := TMaterialLibrary(cbMaterialLibrary.Items.Objects[cbMaterialLibrary.ItemIndex]);
  fSelectedMesh.MaterialLibrary := Lib;
  fSelectedMesh.OnRender := MeshRenderHandler;

  OldSuppress := fSuppressMeshEditorChange;
  fSuppressMeshEditorChange := True;
  try
    cbLibraryName.Clear;
    for I := 0 to Lib.Count - 1 do
      if Assigned(Lib.Material[I]) and (not IsEditorOnlyMaterial(Lib.Material[I])) then
        cbLibraryName.Items.Add(Lib.Material[I].Name);

    NameIndex := cbLibraryName.Items.IndexOf(fSelectedMesh.LibMaterialname);
    if (NameIndex < 0) and (cbLibraryName.Items.Count > 0) then
      NameIndex := 0;
    cbLibraryName.ItemIndex := NameIndex;
    if NameIndex >= 0 then
      fSelectedMesh.LibMaterialname := cbLibraryName.Items[NameIndex]
    else
      fSelectedMesh.LibMaterialname := '';
  finally
    fSuppressMeshEditorChange := OldSuppress;
  end;

  NotifyMeshEditorChanged(False);
end;

procedure TMainForm.MeshLibraryNameChange(Sender: TObject);
begin
  if fSuppressMeshEditorChange or not Assigned(fSelectedMesh) or
     (cbLibraryName.ItemIndex < 0) then
    Exit;

  fSelectedMesh.LibMaterialname := cbLibraryName.Items[cbLibraryName.ItemIndex];
  NotifyMeshEditorChanged(False);
end;

procedure TMainForm.MeshTransformChange(Sender: TObject);
var
  Translation, RotationDeg, Scale: TVector3;
begin
  if fSuppressMeshEditorChange or not Assigned(fSelectedMesh) or not Assigned(fSelectedObject) then
    Exit;

  if not GetMeshEditorTransformValues(Translation, RotationDeg, Scale) then
    Exit;

  fSelectedObject.UpdateWorldMatrices;
  fSelectedMesh.ParentModelMatrix := fSelectedObject.WorldMatrix;
  fSelectedMesh.SetTransform(Translation, RotationDeg * MESH_DEG_TO_RAD, Scale);
  NotifyMeshEditorChanged(False);
end;

procedure TMainForm.MeshShapeChange(Sender: TObject);
var
  F1, F2, F3, F4, F5: Single;
  I1, I2, I3: Integer;
  HeightField, LoadedHeightField: THeightFieldMesh;
  SourceName, CurrentSourceName, SourcePath, TerrainFile: string;
  OldSuppress: Boolean;
  SourceReload: Boolean;
begin
  if fSuppressMeshEditorChange or not Assigned(fSelectedMesh) then
    Exit;

  case fSelectedMesh.MeshType of
    mtFile:
      TFileMesh(fSelectedMesh).SourceFile := eFileMeshFileName.Text;

    mtPlane, mtWater:
      begin
        if not TryReadEditorFloat(ePlaneWidth, 'Plane width', F1, False) then Exit;
        if not TryReadEditorFloat(ePlaneDepth, 'Plane depth', F2, False) then Exit;
        if not TryReadEditorInteger(ePlaneWidthSegments, 'Plane width segments', I1, False) then Exit;
        if not TryReadEditorInteger(ePlaneDepthSegments, 'Plane depth segments', I2, False) then Exit;
        TPlaneMesh(fSelectedMesh).Width := F1;
        TPlaneMesh(fSelectedMesh).Depth := F2;
        TPlaneMesh(fSelectedMesh).WidthSegments := I1;
        TPlaneMesh(fSelectedMesh).DepthSegments := I2;
      end;

    mtCube:
      begin
        if not TryReadEditorFloat(eCubeMeshWidth, 'Cube width', F1, False) then Exit;
        if not TryReadEditorFloat(eCubeMeshHeight, 'Cube height', F2, False) then Exit;
        if not TryReadEditorFloat(eCubeMeshDepth, 'Cube depth', F3, False) then Exit;
        if not TryReadEditorInteger(eCubeMeshStacks, 'Cube width stacks', I1, False) then Exit;
        if not TryReadEditorInteger(eCubeMeshHeightStacks, 'Cube height stacks', I2, False) then Exit;
        if not TryReadEditorInteger(eCubeMeshDepthStacks, 'Cube depth stacks', I3, False) then Exit;
        TCubeMesh(fSelectedMesh).Width := F1;
        TCubeMesh(fSelectedMesh).Height := F2;
        TCubeMesh(fSelectedMesh).Depth := F3;
        TCubeMesh(fSelectedMesh).WidthStacks := I1;
        TCubeMesh(fSelectedMesh).HeightStacks := I2;
        TCubeMesh(fSelectedMesh).DepthStacks := I3;
      end;

    mtSphere:
      begin
        if not TryReadEditorFloat(eSphereMeshRadius, 'Sphere radius', F1, False) then Exit;
        if not TryReadEditorInteger(eSphereMeshStacks, 'Sphere stacks', I1, False) then Exit;
        if not TryReadEditorInteger(eSphereMeshSlices, 'Sphere slices', I2, False) then Exit;
        TSphereMesh(fSelectedMesh).Radius := F1;
        TSphereMesh(fSelectedMesh).StackCount := I1;
        TSphereMesh(fSelectedMesh).SliceCount := I2;
      end;

    mtCylinder:
      begin
        if not TryReadEditorFloat(eCylinderMeshRadius, 'Cylinder radius', F1, False) then Exit;
        if not TryReadEditorFloat(eCylinderMeshHeight, 'Cylinder height', F2, False) then Exit;
        if not TryReadEditorInteger(eCylinderMeshSlices, 'Cylinder slices', I1, False) then Exit;
        if not TryReadEditorInteger(eCylinderMeshStacks, 'Cylinder stacks', I2, False) then Exit;
        TCylinderMesh(fSelectedMesh).Radius := F1;
        TCylinderMesh(fSelectedMesh).Height := F2;
        TCylinderMesh(fSelectedMesh).Slices := I1;
        TCylinderMesh(fSelectedMesh).Stacks := I2;
        TCylinderMesh(fSelectedMesh).BottomCap := MeshCapFromCombo(cbCylinderMeshBottomCap);
        TCylinderMesh(fSelectedMesh).TopCap := MeshCapFromCombo(cbCylinderMeshTopCap);
      end;

    mtCapsule:
      begin
        if not TryReadEditorFloat(eCapsuleMeshRadius, 'Capsule radius', F1, False) then Exit;
        if not TryReadEditorFloat(eCapsuleMeshHeight, 'Capsule height', F2, False) then Exit;
        if not TryReadEditorInteger(eCapsuleMeshSlices, 'Capsule slices', I1, False) then Exit;
        if not TryReadEditorInteger(eCapsuleMeshStacks, 'Capsule stacks', I2, False) then Exit;
        TCapsuleMesh(fSelectedMesh).Radius := F1;
        TCapsuleMesh(fSelectedMesh).Height := F2;
        TCapsuleMesh(fSelectedMesh).Slices := I1;
        TCapsuleMesh(fSelectedMesh).Stacks := I2;
      end;

    mtTorus:
      begin
        if not TryReadEditorFloat(eTorusMeshMajor, 'Torus major radius', F1, False) then Exit;
        if not TryReadEditorFloat(eTorusMeshMinor, 'Torus minor radius', F2, False) then Exit;
        if not TryReadEditorInteger(eTorusMeshMajorSegments, 'Torus major segments', I1, False) then Exit;
        if not TryReadEditorInteger(eTorusMeshMinorSegments, 'Torus minor segments', I2, False) then Exit;
        TTorusMesh(fSelectedMesh).MajorRadius := F1;
        TTorusMesh(fSelectedMesh).MinorRadius := F2;
        TTorusMesh(fSelectedMesh).MajorSegments := I1;
        TTorusMesh(fSelectedMesh).MinorSegments := I2;
      end;

    mtCone:
      begin
        if not TryReadEditorFloat(eConeMeshRadius, 'Cone radius', F1, False) then Exit;
        if not TryReadEditorFloat(eConeMeshHeight, 'Cone height', F2, False) then Exit;
        if not TryReadEditorInteger(eConeMeshSides, 'Cone sides', I1, False) then Exit;
        if not TryReadEditorInteger(eConeMeshStacks, 'Cone stacks', I2, False) then Exit;
        TConeMesh(fSelectedMesh).Radius := F1;
        TConeMesh(fSelectedMesh).Height := F2;
        TConeMesh(fSelectedMesh).Sides := I1;
        TConeMesh(fSelectedMesh).Stacks := I2;
        TConeMesh(fSelectedMesh).BottomCap := MeshCapFromCombo(cbConeMeshBottomCap);
      end;

    mtPrism:
      begin
        if not TryReadEditorFloat(ePrismMeshRadius, 'Prism radius', F1, False) then Exit;
        if not TryReadEditorFloat(ePrismMeshHeight, 'Prism height', F2, False) then Exit;
        if not TryReadEditorInteger(ePrismMeshSides, 'Prism sides', I1, False) then Exit;
        if not TryReadEditorInteger(ePrismMeshStacks, 'Prism stacks', I2, False) then Exit;
        TPrismMesh(fSelectedMesh).Radius := F1;
        TPrismMesh(fSelectedMesh).Height := F2;
        TPrismMesh(fSelectedMesh).Sides := I1;
        TPrismMesh(fSelectedMesh).Stacks := I2;
      end;

    mtFrustum:
      begin
        if not TryReadEditorFloat(eFrustumMeshBottomRadius, 'Frustum bottom radius', F1, False) then Exit;
        if not TryReadEditorFloat(eFrustumMeshTopRadius, 'Frustum top radius', F2, False) then Exit;
        if not TryReadEditorFloat(eFrustumMeshHeight, 'Frustum height', F3, False) then Exit;
        if not TryReadEditorInteger(eFrustumMeshSlices, 'Frustum slices', I1, False) then Exit;
        if not TryReadEditorInteger(eFrustumMeshStacks, 'Frustum stacks', I2, False) then Exit;
        TFrustumMesh(fSelectedMesh).BottomRadius := F1;
        TFrustumMesh(fSelectedMesh).TopRadius := F2;
        TFrustumMesh(fSelectedMesh).Height := F3;
        TFrustumMesh(fSelectedMesh).Slices := I1;
        TFrustumMesh(fSelectedMesh).Stacks := I2;
        TFrustumMesh(fSelectedMesh).BottomCap := MeshCapFromCombo(cbFrustumMeshBottomCap);
        TFrustumMesh(fSelectedMesh).TopCap := MeshCapFromCombo(cbFrustumMeshTopCap);
      end;

    mtIcosphere:
      begin
        if not TryReadEditorFloat(eIcosphereMeshRadius, 'Icosphere radius', F1, False) then Exit;
        if not TryReadEditorInteger(eIcosphereMeshSubdivisions, 'Icosphere subdivisions', I1, False) then Exit;
        TIcosphereMesh(fSelectedMesh).Radius := F1;
        TIcosphereMesh(fSelectedMesh).Subdivisions := I1;
      end;

    mtGeodesicDome:
      begin
        if not TryReadEditorFloat(eGeodesicDomeMeshRadius, 'Geodesic dome radius', F1, False) then Exit;
        if not TryReadEditorInteger(eGeodesicDomeMeshSubdivisions, 'Geodesic dome subdivisions', I1, False) then Exit;
        TGeodesicDomeMesh(fSelectedMesh).Radius := F1;
        TGeodesicDomeMesh(fSelectedMesh).Subdivisions := I1;
      end;

    mtHeightField:
      begin
        if not TryReadEditorFloat(eHeightFieldMeshWidth, 'Terrain width', F1, False) then Exit;
        if not TryReadEditorFloat(eHeightFieldMeshDepth, 'Terrain depth', F2, False) then Exit;
        if not TryReadEditorFloat(eHeightFieldMeshHeightScale, 'Terrain height scale', F3, False) then Exit;
        if not TryReadEditorFloat(eHeightFieldMeshUVScale, 'Terrain UV scale', F4, False) then Exit;
        if not TryReadEditorInteger(eHeightFieldMeshTileSize, 'Terrain tile size', I1, False) then Exit;

        HeightField := THeightFieldMesh(fSelectedMesh);
        if chbHeightFieldMeshEnableLOD.Checked then
        begin
          if not TryReadEditorFloat(eHeightFieldMeshLODDistance, 'Terrain LOD distance', F5, False) then Exit;
          if not TryReadEditorInteger(eHeightFieldMeshLODCount, 'Terrain LOD count', I2, False) then Exit;
        end
        else
        begin
          F5 := HeightField.LODDistance;
          I2 := HeightField.LODCount;
        end;

        SourceName := Trim(eHeightFieldMeshSourceFile.Text);
        CurrentSourceName := ExtractFileName(HeightField.SourceFile);
        SourceReload := (SourceName <> '') and
          ((Sender = sbHeightFieldMeshSourceFile) or
           not SameText(ExtractFileName(SourceName), CurrentSourceName));

        if SourceReload then
        begin
          SourcePath := TEnginePaths.Terrain(SourceName);
          TerrainFile := TEnginePaths.Terrain(ExtractFileName(SourceName));
          if FileExists(SourcePath) and
             not SameText(ExpandFileName(SourcePath), ExpandFileName(TerrainFile)) then
          begin
            TEnginePaths.EnsureDirectories;
            TFile.Copy(SourcePath, TerrainFile, True);
            SourcePath := TerrainFile;
          end;

          if not FileExists(SourcePath) then
            Exit;
        end;

        HeightField.Width := F1;
        HeightField.Depth := F2;
        HeightField.HeightScale := F3;
        HeightField.UVScale := F4;
        HeightField.TileSize := I1;
        HeightField.LODEnabled := chbHeightFieldMeshEnableLOD.Checked;
        HeightField.LODDistance := F5;
        HeightField.LODCount := I2;
        eHeightFieldMeshLODDistance.Enabled := HeightField.LODEnabled;
        eHeightFieldMeshLODCount.Enabled := HeightField.LODEnabled;

        if SourceReload then
        begin
          LoadedHeightField := THeightFieldMesh.FromBitmap(SourcePath, F1, F2,
            F3, F4, HeightField.Name, HeightField.IsStatic);
          LoadedHeightField.UpsampleHeights(4);
          try
            HeightField.SetHeights(LoadedHeightField.Heights,
              LoadedHeightField.HeightMapWidth, LoadedHeightField.HeightMapDepth);
            HeightField.SourceFile := ExtractFileName(SourceName);
          finally
            LoadedHeightField.Free;
          end;
        end;

        if SourceName <> '' then
          HeightField.SourceFile := ExtractFileName(SourceName);

        OldSuppress := fSuppressMeshEditorChange;
        fSuppressMeshEditorChange := True;
        try
          eHeightFieldMeshMapWidth.Text := IntToStr(HeightField.HeightMapWidth);
          eHeightFieldMeshMapDepth.Text := IntToStr(HeightField.HeightMapDepth);
          eHeightFieldMeshSourceFile.Text := ExtractFileName(HeightField.SourceFile);
        finally
          fSuppressMeshEditorChange := OldSuppress;
        end;
      end;

    mtArrow:
      begin
        if not TryReadEditorFloat(eArrowMeshShaftLength, 'Arrow shaft length', F1, False) then Exit;
        if not TryReadEditorFloat(eArrowMeshTipLength, 'Arrow tip length', F2, False) then Exit;
        if not TryReadEditorFloat(eArrowMeshShaftRadius, 'Arrow shaft radius', F3, False) then Exit;
        if not TryReadEditorFloat(eArrowMeshTipRadius, 'Arrow tip radius', F4, False) then Exit;
        if not TryReadEditorInteger(eArrowMeshSlices, 'Arrow slices', I1, False) then Exit;
        if not TryReadEditorInteger(eArrowMeshStacks, 'Arrow stacks', I2, False) then Exit;
        TArrowMesh(fSelectedMesh).ShaftLength := F1;
        TArrowMesh(fSelectedMesh).TipLength := F2;
        TArrowMesh(fSelectedMesh).ShaftRadius := F3;
        TArrowMesh(fSelectedMesh).TipRadius := F4;
        TArrowMesh(fSelectedMesh).Slices := I1;
        TArrowMesh(fSelectedMesh).Stacks := I2;
      end;

    mtSuperEllipsoid:
      begin
        if not TryReadEditorFloat(eSuperEllipsoidMeshRadius, 'Super ellipsoid radius', F1, False) then Exit;
        if not TryReadEditorFloat(eSuperEllipsoidMeshVCurve, 'Super ellipsoid V curve', F2, False) then Exit;
        if not TryReadEditorFloat(eSuperEllipsoidMeshHCurve, 'Super ellipsoid H curve', F3, False) then Exit;
        if not TryReadEditorInteger(eSuperEllipsoidMeshSlices, 'Super ellipsoid slices', I1, False) then Exit;
        if not TryReadEditorInteger(eSuperEllipsoidMeshStacks, 'Super ellipsoid stacks', I2, False) then Exit;
        TSuperEllipsoidMesh(fSelectedMesh).Radius := F1;
        TSuperEllipsoidMesh(fSelectedMesh).VCurve := F2;
        TSuperEllipsoidMesh(fSelectedMesh).HCurve := F3;
        TSuperEllipsoidMesh(fSelectedMesh).Slices := I1;
        TSuperEllipsoidMesh(fSelectedMesh).Stacks := I2;
      end;
  end;

  NotifyMeshEditorChanged(False);
end;

procedure TMainForm.HeightFieldMeshSourceFileClick(Sender: TObject);
var
  Dialog: TOpenPictureDialog;
  Picture: TPicture;
  SourceFile, StoredFileName, TerrainFile: string;
  OldSuppress: Boolean;
begin
  if not Assigned(fSelectedMesh) or not (fSelectedMesh is THeightFieldMesh) then
    Exit;

  TEnginePaths.EnsureDirectories;

  Dialog := TOpenPictureDialog.Create(Self);
  Picture := TPicture.Create;
  try
    Dialog.Title := 'Load Terrain Heightmap';
    Dialog.InitialDir := TEnginePaths.TerrainDir;
    Dialog.Filter := 'Heightmap images (*.bmp;*.png;*.jpg;*.jpeg)|*.bmp;*.png;*.jpg;*.jpeg|Bitmap files (*.bmp)|*.bmp|PNG files (*.png)|*.png|JPEG files (*.jpg;*.jpeg)|*.jpg;*.jpeg|All files (*.*)|*.*';
    Dialog.DefaultExt := 'bmp';
    Dialog.Options := Dialog.Options + [ofFileMustExist, ofPathMustExist];
    if Trim(eHeightFieldMeshSourceFile.Text) <> '' then
      Dialog.FileName := TEnginePaths.Terrain(eHeightFieldMeshSourceFile.Text);

    if not Dialog.Execute then
      Exit;

    SourceFile := Dialog.FileName;
    StoredFileName := ExtractFileName(SourceFile);
    TerrainFile := TEnginePaths.Terrain(StoredFileName);

    if not SameText(ExpandFileName(SourceFile), ExpandFileName(TerrainFile)) then
      TFile.Copy(SourceFile, TerrainFile, True);

    Picture.LoadFromFile(TerrainFile);
    if (Picture.Width < 2) or (Picture.Height < 2) then
      raise Exception.Create('Heightfield bitmap must be at least 2x2 pixels.');

    OldSuppress := fSuppressMeshEditorChange;
    fSuppressMeshEditorChange := True;
    try
      eHeightFieldMeshSourceFile.Text := StoredFileName;
      eHeightFieldMeshMapWidth.Text := IntToStr(Picture.Width);
      eHeightFieldMeshMapDepth.Text := IntToStr(Picture.Height);
    finally
      fSuppressMeshEditorChange := OldSuppress;
    end;

    MeshShapeChange(sbHeightFieldMeshSourceFile);
  finally
    Picture.Free;
    Dialog.Free;
  end;
end;

procedure TMainForm.MeshApplyUVClick(Sender: TObject);
var
  ScaleU, ScaleV: Single;
begin
  if not Assigned(fSelectedMesh) then
    Exit;

  if not TryReadEditorFloat(eU, 'UV U scale', ScaleU, True) then Exit;
  if not TryReadEditorFloat(eV, 'UV V scale', ScaleV, True) then Exit;

  fSelectedMesh.ScaleUVs(ScaleU, ScaleV);
  NotifyMeshEditorChanged(False);
end;

procedure TMainForm.CutNode;
var
  node: TTreeNode;
  i: Integer;
begin
  node := scTree.Selected;
  if not Assigned(node) or not Assigned(node.Data) then
    Exit;

  // Clear any previous clipboard
  ClearClipboard;

  FClipboardNode := node;
  FClipboardObject := TSceneObject(node.Data);
  FClipboardParent := FClipboardObject.Parent;
  // Find index in parent's ObjectList
  if Assigned(FClipboardParent) then
  begin
    for i := 0 to FClipboardParent.Count - 1 do
      begin
        FClipboardIndex := i;
        if FClipboardParent.ObjectList[i] = FClipboardObject then
          Break;
      end;
  end
  else
    FClipboardIndex := -1;

  if fSelectedObject = FClipboardObject then
    fSelectedObject := nil;

  FIsCut := True;
  UpdateObjectCommandStates;
end;

procedure TMainForm.CopyNode;
var
  node: TTreeNode;
begin
  node := scTree.Selected;
  if not Assigned(node) or not Assigned(node.Data) then
    Exit;

  ClearClipboard;
  FClipboardObject := TSceneObject(node.Data);
  FIsCut := False;   // copy, not cut
  UpdateObjectCommandStates;
end;

procedure TMainForm.PasteNode;
var
  targetNode: TTreeNode;
  targetParentObj: TSceneObject;
  newObject: TSceneObject;
begin
  if not Assigned(FClipboardObject) then
    Exit;

  targetNode := scTree.Selected;
  if not Assigned(targetNode) then
    targetParentObj := nil
  else
    targetParentObj := TSceneObject(targetNode.Data);

  if FIsCut then
  begin
    // --- MOVE ---
    // Cannot move an object into its own descendant
    if (targetParentObj <> nil) and FClipboardObject.IsDescendantOf(targetParentObj) then
    begin
      ShowMessage('Cannot move an object into its own descendant.');
      Exit;
    end;

    // Detach from old parent
    if Assigned(FClipboardParent) then
      FClipboardParent.DetachObject(FClipboardObject);

    // Attach to new parent (or root)
    if Assigned(targetParentObj) then
      targetParentObj.AttachObject(targetParentObj.Count, FClipboardObject)
    else
      fSceneManager.AddSceneObject(FClipboardObject);   // assumes root list

    // Update tree view: remove old node and insert under new parent
    if Assigned(targetNode) then
      FClipboardNode.MoveTo(targetNode, naAddChild)
    else
      FClipboardNode.MoveTo(nil, naAdd);  // move to root

    ClearClipboard;
  end
  else
  begin
    // --- COPY (deep clone) ---
    if not Assigned(targetParentObj) then
      targetParentObj := fRoot;   // or appropriate root

    newObject := FClipboardObject.Clone;
    if Assigned(targetParentObj) then
      targetParentObj.AttachObject(targetParentObj.Count, newObject)
    else
      fSceneManager.AddSceneObject(newObject);

    AttachRuntimeSceneData(newObject);
    EnsurePhysicsBodiesForScene(newObject);

    PopulateTreeView;
    SynchronizeTreeViewSelection(newObject);
    if Assigned(scTree.Selected) and (scTree.Selected.Data = newObject) then
      scTreeClick(scTree);
  end;

  scTree.FullExpand;
  UpdateObjectCommandStates;
end;

procedure TMainForm.ClearClipboard;
begin
  FClipboardNode := nil;
  FClipboardObject := nil;
  FClipboardParent := nil;
  FClipboardIndex := -1;
  FIsCut := False;
  UpdateObjectCommandStates;
end;

procedure TMainForm.SyncShortcutTreeSelection(Sender: TObject);
begin
  if ((Sender = pnlRenderingSurface) or
     ((Sender = Self) and (ActiveControl = pnlRenderingSurface))) and
     Assigned(fSelectedObject) then
    SynchronizeTreeViewSelection(fSelectedObject);
end;

procedure TMainForm.EditorShortcutKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if fSimulatePhysics then
    Exit;

  if (Sender = Self) and
     (ActiveControl <> scTree) and
     (ActiveControl <> pnlRenderingSurface) then
    Exit;

  if ssCtrl in Shift then
  begin
    case Key of
      Ord('C'):
        begin
          SyncShortcutTreeSelection(Sender);
          CopyNode;
          Key := 0;
        end;

      Ord('X'):
        begin
          SyncShortcutTreeSelection(Sender);
          CutNode;
          Key := 0;
        end;

      Ord('V'):
        begin
          SyncShortcutTreeSelection(Sender);
          PasteNode;
          Key := 0;
        end;
    end;

    Exit;
  end;

  case Key of
    VK_DELETE:
      begin
        SyncShortcutTreeSelection(Sender);
        puDeleteClick(Self);
        Key := 0;
      end;

    VK_F2:
      begin
        SyncShortcutTreeSelection(Sender);
        puRenameClick(Self);
        Key := 0;
      end;
  end;
end;

procedure TMainForm.DoProgress(Sender: TObject; const deltaTime, newTime: Double);
begin
  {UpdateScene(deltaTime);

  if Assigned(fPhysicsWorld) then
  begin
    if fSimulatePhysics then
      fPhysicsWorld.Step(Single(deltaTime))
    else if fPhysicsRestorePending then
    begin
      fPhysicsWorld.RestoreSceneTransforms(False);
      fPhysicsRestorePending := False;
      SetPhysicsSimulationMode(False);
      mLog.Lines.Add('Physics simulation restored.');
    end;
  end;

  fRenderer.Render;

  Caption := Format('OpenGL 4.5 - FPS: %d - Shadow meshes: %d', [fRenderer.FPS, fRenderer.ShadowDrawCount]);}

  try
    UpdateScene(deltaTime);

    if Assigned(fPhysicsWorld) then
    begin
      if fSimulatePhysics then
        fPhysicsWorld.Step(Single(deltaTime))
      else if fPhysicsRestorePending then
      begin
        fPhysicsWorld.RestoreSceneTransforms(False);
        fPhysicsRestorePending := False;
        SetPhysicsSimulationMode(False);
        mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Physics simulation restored.');
      end;
    end;

    RefreshPhysicsDebugHull;
    UpdateSceneStatusBar;

    if Assigned(fRenderer) then
      fRenderer.Render;

    if Assigned(fRenderer) then
      Caption := Format('OpenGL 4.5 - FPS: %d - Shadow meshes: %d',
        [fRenderer.FPS, fRenderer.ShadowDrawCount]);
  except
    on E: Exception do
    begin
      Timer.Enabled := False;
      mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Exception in DoProgress: ' + E.ClassName + ': ' + E.Message);
      raise;
    end;
  end;
end;

procedure TMainForm.DoTotalProgress(Sender: TObject; const deltaTime, newTime: Double);
begin

end;

procedure TMainForm.LoadDefaultTextures;
  var
    i: Integer;
    Mat: TMaterial;
    matTexArr: TArray<TMaterialTexture>;
begin
  Mat := TMaterial.Create(mtPBR);
  Mat.Name := 'DefaultPBRMaterial';

  SetLength(matTexArr, 8);
  for i := 0 to Length(matTexArr) -1 do
    begin
      matTexArr[i].Texture.DiffuseColor := Vector3(0.5, 0.5, 0.5);
      matTexArr[i].Texture.SpecularColor := Vector3(1.0, 1.0, 1.0);
      matTexArr[i].Texture.Shininess := 64.0;
    end;

  if matTexArr[0].LoadTexTGA(TEnginePaths.Texture('DefaultColor.tga'), True, 'albedoTexture', GL_SRGB8_ALPHA8, GL_REPEAT, False) = False then
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Failed to load texture')
  else
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + Format('Texture: %s successfully loaded.', ['Data\Tex\DefaultColor.tga']));

  if matTexArr[1].LoadTexTGA(TEnginePaths.Texture('DefaultNormal.tga'), True, 'normalTexture', GL_RGBA8, GL_REPEAT, False) = False then
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Failed to load texture')
  else
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + Format('Texture: %s successfully loaded.', ['Data\Tex\DefaultNormal.tga']));

  if matTexArr[2].LoadTexTGA(TEnginePaths.Texture('DefaultHeight.tga'), True, 'heightTexture', GL_RGBA8, GL_REPEAT, False) = False then
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Failed to load texture')
  else
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + Format('Texture: %s successfully loaded.', ['Data\Tex\DefaultHeight.tga']));

  if matTexArr[3].LoadTexTGA(TEnginePaths.Texture('DefaultMetallic.tga'), True, 'metalnessTexture', GL_RGBA8, GL_REPEAT, False) = False then
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Failed to load texture')
  else
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + Format('Texture: %s successfully loaded.', ['Data\Tex\DefaultMetallic.tga']));

  if matTexArr[4].LoadTexTGA(TEnginePaths.Texture('DefaultRoughness.tga'), True, 'roughnessTexture', GL_RGBA8, GL_REPEAT, False) = False then
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Failed to load texture')
  else
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + Format('Texture: %s successfully loaded.', ['Data\Tex\DefaultRoughness.tga']));

  if matTexArr[5].LoadTexTGA(TEnginePaths.Texture('DefaultEdge.tga'), True, 'specularTexture', GL_RGBA8, GL_REPEAT, False) = False then
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Failed to load texture')
  else
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + Format('Texture: %s successfully loaded.', ['Data\Tex\DefaultEdge.tga']));

  if matTexArr[6].LoadTexTGA(TEnginePaths.Texture('DefaultAmbient.tga'), True, 'ambientOcclusionTexture', GL_RGBA8, GL_REPEAT, False) = False then
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Failed to load texture')
  else
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + Format('Texture: %s successfully loaded.', ['Data\Tex\DefaultAmbient.tga']));

  if matTexArr[7].LoadTexTGA(TEnginePaths.Texture('DefaultIrradiance.tga'), False, 'specularBRDF_LUT', GL_RGBA8, GL_CLAMP_TO_EDGE, False) = False then
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Failed to load texture')
  else
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + Format('Texture: %s successfully loaded.', ['Data\Tex\DefaultIrradiance.tga']));

  Mat.Shader := fShader;
  Mat.AddTextures(matTexArr);
  MaterialLibraries.MaterialLibrary[0].AddMaterial(Mat);
end;

procedure TMainForm.LoadCustomTextures;
  var
    i: Integer;
    Mat: TMaterial;
    matTexArr: TArray<TMaterialTexture>;
begin
  Mat := TMaterial.Create(mtPBR);
  Mat.Name := 'DefaultPBRMaterial';

  SetLength(matTexArr, 8);
  for i := 0 to Length(matTexArr) -1 do
    begin
      matTexArr[i].Texture.DiffuseColor := Vector3(0.5, 0.5, 0.5);
      matTexArr[i].Texture.SpecularColor := Vector3(1.0, 1.0, 1.0);
      matTexArr[i].Texture.Shininess := 64.0;
    end;

  if matTexArr[0].LoadTexTGA(TEnginePaths.Texture('StoneColor.tga'), True, 'albedoTexture', GL_SRGB8_ALPHA8, GL_REPEAT, False) = False then
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Failed to load texture 0')
  else
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + Format('Texture: %s successfully loaded.', ['Data\Tex\StoneColor.tga']));

  if matTexArr[1].LoadTexTGA(TEnginePaths.Texture('StoneNormal.tga'), False, 'normalTexture', GL_RGBA8_SNORM, GL_REPEAT, False) = False then
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Failed to load texture 1')
  else
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + Format('Texture: %s successfully loaded.', ['Data\Tex\StoneNormal.tga']));

  if matTexArr[2].LoadTexTGA(TEnginePaths.Texture('StoneHeight2.tga'), False, 'heightTexture', GL_RGBA8, GL_REPEAT, False) = False then
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Failed to load texture 2')
  else
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + Format('Texture: %s successfully loaded.', ['Data\Tex\StoneHeight.tga']));

  if matTexArr[3].LoadTexTGA(TEnginePaths.Texture('StoneMetallic_2.tga'), False, 'metalnessTexture', GL_RGBA8, GL_REPEAT, False) = False then
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Failed to load texture 3')
  else
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + Format('Texture: %s successfully loaded.', ['Data\Tex\StoneMetallic_2.tga']));

  if matTexArr[4].LoadTexTGA(TEnginePaths.Texture('StoneRoughness.tga'), False, 'roughnessTexture', GL_RGBA8, GL_REPEAT, False) = False then
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Failed to load texture 4')
  else
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + Format('Texture: %s successfully loaded.', ['Data\Tex\StoneRoughness.tga']));

  if matTexArr[5].LoadTexTGA(TEnginePaths.Texture('StoneSpecular.tga'), False, 'specularTexture', GL_RGBA8, GL_REPEAT, False) = False then
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Failed to load texture 5')
  else
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + Format('Texture: %s successfully loaded.', ['Data\Tex\StoneSpecular.tga']));

  if matTexArr[6].LoadTexTGA(TEnginePaths.Texture('StoneAmbient.tga'), False, 'ambientOcclusionTexture', GL_RGBA8, GL_REPEAT, False) = False then
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Failed to load texture 6')
  else
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + Format('Texture: %s successfully loaded.', ['Data\Tex\StoneAmbient.tga']));

  if matTexArr[7].LoadTexTGA(TEnginePaths.Texture('BRDF_LUT.tga'), False, 'specularBRDF_LUT', GL_RGBA8, GL_CLAMP_TO_EDGE, False) = False then
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Failed to load texture 7')
  else
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + Format('Texture: %s successfully loaded.', ['Data\Tex\BRDF_LUT.tga']));

  Mat.Shader := fShader;
  Mat.AddTextures(matTexArr);
  MaterialLibraries.MaterialLibrary[0].AddMaterial(Mat);
end;

procedure TMainForm.scTreeClick(Sender: TObject);
var
  NewObj: TSceneObject;
begin
  if fSimulatePhysics then
    Exit;

  if (scTree.Selected = nil) or (scTree.Selected.Data = nil) then Exit;
  NewObj := TSceneObject(scTree.Selected.Data);
  if IsNewObjectEditorActive and (NewObj <> frmMeshCreator.InternalObject) then
  begin
    if Assigned(frmMeshCreator.InternalObject) then
      SynchronizeTreeViewSelection(frmMeshCreator.InternalObject)
    else if Assigned(fSelectedObject) then
      SynchronizeTreeViewSelection(fSelectedObject);
    Exit;
  end;

  fLastPickedMeshIndex := -1;
  fSelectedObject := NewObj;
  if (fSelectedObject <> fLight) and (fSelectedObject <> fCamera) then
    fSelectedObject.UpdateWorldMatrices;

  if Assigned(fCurrentGizmo) then
    FreeAndNil(fCurrentGizmo);
  fGizmoOwner := nil;
  fHoveredAxis := -1;

  if (fSelectedObject <> nil) and
     (not fSelectedObject.IsGizmo) and
     (fSelectedObject <> fLight) and
     (fSelectedObject <> fCamera) then
    RefreshGizmo;

  RefreshSelectedBoundingBox;
  UpdateUI;
  Old_ReadMeshes;
  RefreshPhysicsDebugHull;
  fRenderer.Render;
end;

procedure TMainForm.scTreeDblClick(Sender: TObject);
begin
  if fSimulatePhysics then
    Exit;

  if IsNewObjectEditorActive then Exit;
  if scTree.Items.Count > 0 then
    begin
      if (scTree.Selected <> nil) and (scTree.Selected.Data <> nil) then
        begin
          fSelectedObject := TSceneObject(scTree.Selected.Data);

          if (fSelectedObject <> fCamera) then
            begin
              fOrbitTarget := fSelectedObject.Position;
              UpdateOrbitCamera;
              ReadTransformControls(fSelectedObject);
            end;

        end;
    end;
end;

procedure TMainForm.scTreeDeletion(Sender: TObject; Node: TTreeNode);
begin
  Node.Data := nil;
end;

procedure TMainForm.scTreeDragDrop(Sender, Source: TObject; X, Y: Integer);
var
  sourceNode, targetNode: TTreeNode;
  sourceObj, targetParentObj: TSceneObject;
  newParent: TSceneObject;
  insertIndex: Integer;
begin
  if fSimulatePhysics then
    Exit;

  sourceNode := scTree.Selected;
  targetNode := scTree.GetNodeAt(X, Y);
  if not Assigned(sourceNode) or not Assigned(sourceNode.Data) then
    Exit;

  sourceObj := TSceneObject(sourceNode.Data);
  if Assigned(targetNode) then
    targetParentObj := TSceneObject(targetNode.Data)
  else
    targetParentObj := nil;

  // Determine new parent
  if Assigned(targetParentObj) then
    newParent := targetParentObj
  else
    newParent := nil;   // becomes root of the scene

  // Detach from old parent
  if Assigned(sourceObj.Parent) then
    sourceObj.Parent.DetachObject(sourceObj);

  // Attach to new parent
  if Assigned(newParent) then
    newParent.AttachObject(newParent.Count, sourceObj)
  else
    fSceneManager.AddSceneObject(sourceObj);   // move to root

  // Update the tree view: move the node
  if Assigned(targetNode) then
    sourceNode.MoveTo(targetNode, naAddChild)
  else
    sourceNode.MoveTo(nil, naAdd);   // move to top level

  scTree.FullExpand;
end;

procedure TMainForm.scTreeDragOver(Sender, Source: TObject; X, Y: Integer;
  State: TDragState; var Accept: Boolean);
var
  targetNode: TTreeNode;
  sourceNode: TTreeNode;
begin
  Accept := False;
  if fSimulatePhysics then
    Exit;

  if not (Source is TTreeView) then
    Exit;
  targetNode := scTree.GetNodeAt(X, Y);
  if not Assigned(targetNode) then
    Exit;
  sourceNode := scTree.Selected;
  if not Assigned(sourceNode) or (sourceNode = targetNode) then
    Exit;

  // Do not allow dropping onto a descendant of the source node
  if targetNode.HasAsParent(sourceNode) then
    Exit;

  Accept := True;
end;

procedure TMainForm.scTreeEdited(Sender: TObject; Node: TTreeNode; var S: string);
var
  obj: TSceneObject;
begin
  if fSimulatePhysics then
    Exit;

  if not Assigned(Node) or not Assigned(Node.Data) then
    Exit;
  obj := TSceneObject(Node.Data);
  obj.Name := S;
  Node.Text := obj.Name;   // update node text to the final name (after possible uniqueness adjustment)
end;

// MODIFIED: Smooth interpolation for zoom & rotation
procedure TMainForm.UpdateScene(deltaTime: Double);
const
  SMOOTH_SPEED = 40.0;   // units per second
begin
  // Smoothly move current orbit parameters toward target values
  if deltaTime > 0 then
  begin
    // Interpolate radius (zoom)
    fCurrentRadius := fCurrentRadius + (fTargetRadius - fCurrentRadius) * (1 - Power(0.01, deltaTime * SMOOTH_SPEED));
    // Interpolate azimuth and polar
    fCurrentAzimuth := fCurrentAzimuth + (fTargetAzimuth - fCurrentAzimuth) * (1 - Power(0.01, deltaTime * SMOOTH_SPEED));
    fCurrentPolar   := fCurrentPolar   + (fTargetPolar   - fCurrentPolar)   * (1 - Power(0.01, deltaTime * SMOOTH_SPEED));

    // Keep polar within valid range (avoid camera flip)
    if fCurrentPolar < 0.01 then fCurrentPolar := 0.01;
    if fCurrentPolar > Pi - 0.01 then fCurrentPolar := Pi - 0.01;
  end;

  fRenderer.ShadowTarget := fOrbitTarget;

  SyncSkyDomeToMainLight;

  UpdateOrbitCamera;
end;

procedure TMainForm.ApplyFrameUniformsToShader(Shader: TShader);
var
  RenderCamera: TSceneObject;
begin
  if Shader = nil then
    Exit;
  if fRenderer = nil then
    Exit;

  RenderCamera := fRenderer.ActiveCamera;
  if RenderCamera = nil then
    RenderCamera := fCamera;

  if RenderCamera = nil then
    Exit;
  if RenderCamera.Camera = nil then
    Exit;

  Shader.Use;

  Shader.SetUniform('eyePosition', RenderCamera.Camera.Position);
  Shader.SetUniform('viewProjection',
    fRenderer.ProjectionMatrix * RenderCamera.Camera.ViewMatrix);
  Shader.SetUniform('useFog', GLint(Ord(fRenderer.FogEnabled)));
  Shader.SetUniform('fogColor', fRenderer.EffectiveFogColor);
  Shader.SetUniform('fogDensity', GLfloat(fRenderer.FogDensity));
  Shader.SetUniform('fogStart', GLfloat(fRenderer.FogStart));
  Shader.SetUniform('fogEnd', GLfloat(fRenderer.FogEnd));

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

  if fRenderer.ShadowEnabled and (fRenderer.ShadowDepthTexture <> 0) then
  begin
    glActiveTexture(GL_TEXTURE8);
    glBindTexture(GL_TEXTURE_2D, fRenderer.ShadowDepthTexture);

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

procedure TMainForm.OnUpdateShader(Shader: TShader);
begin
  ApplyFrameUniformsToShader(Shader);
end;

procedure TMainForm.OnUpdateGizmoShader(Shader: TShader);
var
  RenderCamera: TSceneObject;
begin
  if Shader = nil then
    Exit;
  if fRenderer = nil then
    Exit;

  RenderCamera := fRenderer.ActiveCamera;
  if RenderCamera = nil then
    RenderCamera := fCamera;
  if RenderCamera = nil then
    Exit;
  if RenderCamera.Camera = nil then
    Exit;

  Shader.Use;
  Shader.SetUniform('viewProjection', fRenderer.ProjectionMatrix * RenderCamera.Camera.ViewMatrix);
end;

procedure TMainForm.GizmoMeshRenderHandler(Mesh: TMesh; Shader: TShader);
begin
  Shader.SetUniform('modelMatrix', Mesh.ModelMatrix);
  Shader.SetUniform('activeColor', Mesh.Tag);
  // Pass hover factor: 1.0 if this axis is under the mouse, else 0.0
  if Mesh.AlwaysOnTop and (fHoveredAxis <> -1) and (Mesh.Tag = fHoveredAxis) then
    Shader.SetUniform('hoverFactor', 1.0)
  else
    Shader.SetUniform('hoverFactor', 0.0);
end;

procedure TMainForm.SyncSkyDomeToMainLight;
var
  LightObj: TSceneObject;
  Light: TLight;
  SunDir: TVector3;
begin
  if (fRenderer = nil) or (fRenderer.SkyDome = nil) then
    Exit;

  // Your "sun/moon" light object.
  // Prefer ShadowLight because you already use it as the main directional light.
  LightObj := fRenderer.ShadowLight;
  if LightObj = nil then
    LightObj := fLight;

  if (LightObj = nil) or (LightObj.LightsCount <= 0) then
    Exit;

  // Always use light[0], as requested.
  Light := LightObj.Light[0];
  if Light = nil then
    Exit;

  if not (Light.LightType in [ltDirectional, ltSpot]) then
    Exit;

  SunDir := Light.Direction;

  if SunDir.LengthSquared < 1e-8 then
    Exit;

  SunDir.Normalize;

  // Light.Direction = direction light travels.
  // SkyDome.SunDirection = direction from camera/world toward sun disc.
  fRenderer.SkyDome.SunDirection := -SunDir;
end;

procedure TMainForm.pnlRenderingSurfaceMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Axis: Integer;
  Hit: Boolean;
begin
  if pnlRenderingSurface.CanFocus then
    pnlRenderingSurface.SetFocus;

  if Button = mbLeft then
  begin
    if fSimulatePhysics then
      Exit;

    RefreshGizmo;
    Hit := False;
    // Try to pick the active gizmo
      if fGizmoMode = gmTranslate then
        Hit := PickGizmoAxis(X, Y, Axis)
      else if fGizmoMode = gmRotate then
        Hit := PickRotateAxis(X, Y, Axis)
      else if fGizmoMode = gmScale then
        Hit := PickScaleGizmoAxis(X, Y, Axis);

    if Hit then
    begin
      fDraggingGizmo := True;
      fDraggedAxis := Axis;
      fHoveredAxis := Axis;
      fDragStartMousePos := Point(X, Y);

      if fGizmoMode = gmTranslate then
      begin
        // Store translation drag data
        fDragStartObjectPos := GetGizmoTargetWorldPosition;
        if IsMeshEditModeActive then
          GetMeshEditorTransformValues(fMeshDragStartTranslation,
            fMeshDragStartRotationDeg, fMeshDragStartScale);
        case Axis of
          0: fDragAxisWorldDir := Vector3(1, 0, 0);  // world X
          1: fDragAxisWorldDir := Vector3(0, 1, 0);  // world Y
          2: fDragAxisWorldDir := Vector3(0, 0, 1);  // world Z
        end;
        fDragAxisWorldDir.SetNormalized;
        var TipPos := GetArrowTipByTag(Axis);
        fDragOffsetWorld := TipPos - fDragStartObjectPos;
      end
    else
      if fGizmoMode = gmRotate then // gmRotate
        begin
          fRotateStartAngleSet := False;
          if IsMeshEditModeActive then
            GetMeshEditorTransformValues(fMeshDragStartTranslation,
              fMeshDragStartRotationDeg, fMeshDragStartScale);
        end
    else
      if fGizmoMode = gmScale then
        begin
          fDragStartObjectPos := GetGizmoTargetWorldPosition;
          fDragStartHandlePos := GetScaleTipByTag(Axis);
          fDragAxisWorldDir := Vector3(0,0,0);
            case Axis of
              0: fDragAxisWorldDir := Vector3(1,0,0);
              1: fDragAxisWorldDir := Vector3(0,1,0);
              2: fDragAxisWorldDir := Vector3(0,0,1);
            end;
          if IsMeshEditModeActive then
          begin
            GetMeshEditorTransformValues(fMeshDragStartTranslation,
              fMeshDragStartRotationDeg, fMeshDragStartScale);
            fInitialScale := fMeshDragStartScale;
          end
          else
            fInitialScale := fSelectedObject.Scale;
          // Project the handle tip to screen space
          var Viewport: array[0..3] of GLint;
          Viewport[0] := 0; Viewport[1] := 0;
          Viewport[2] := pnlRenderingSurface.Width; Viewport[3] := pnlRenderingSurface.Height;
          var ModelView := fCamera.Camera.ViewMatrix;
          var Proj := fRenderer.ProjectionMatrix;
          var Clip := Proj * (ModelView * Vector4(fDragStartHandlePos, 1));
          if Clip.W <> 0 then
            begin
              var NDC := Vector3(Clip.X / Clip.W, Clip.Y / Clip.W, Clip.Z / Clip.W);
              fDragStartScreenPos.X := Round((NDC.X * 0.5 + 0.5) * Viewport[2] + Viewport[0]);
              fDragStartScreenPos.Y := Round((1 - (NDC.Y * 0.5 + 0.5)) * Viewport[3] + Viewport[1]);
            end;

          // Project the axis direction to screen space
          var WorldAxisEnd := fDragStartHandlePos + fDragAxisWorldDir;
          Clip := Proj * (ModelView * Vector4(WorldAxisEnd, 1));
          if Clip.W <> 0 then
            begin
              var NDC := Vector3(Clip.X / Clip.W, Clip.Y / Clip.W, Clip.Z / Clip.W);
              var endX := Round((NDC.X * 0.5 + 0.5) * Viewport[2] + Viewport[0]);
              var endY := Round((1 - (NDC.Y * 0.5 + 0.5)) * Viewport[3] + Viewport[1]);
              fDragStartScreenAxis := Vector2(endX - fDragStartScreenPos.X, endY - fDragStartScreenPos.Y);
              fDragStartScreenAxis.SetNormalized;
            end;

          var initDeltaX := X - fDragStartScreenPos.X;
          var initDeltaY := Y - fDragStartScreenPos.Y;
          fDragStartPixelDelta := initDeltaX * fDragStartScreenAxis.X + initDeltaY * fDragStartScreenAxis.Y;
        end;

      SetCapture(pnlRenderingSurface.Handle);
      Exit;
    end;

    RefreshGizmo;
    if IsMeshEditModeActive then
    begin
      ResetMeshEditor;
      RefreshGizmo;
    end;

    if IsNewObjectEditorActive then
      Exit;

    if SelectObjectAtScreenPos(X, Y) then
      Old_ReadMeshes
    else
      DeselectObject;
  end;

  if Button = mbRight then
  begin
    fMouseDown := True;
    fLastMouseX := X;
    fLastMouseY := Y;
    SetCapture(pnlRenderingSurface.Handle);
  end;
  if Button = mbMiddle then
  begin
    fPanActive := True;
    fLastPanX := X;
    fLastPanY := Y;
    SetCapture(pnlRenderingSurface.Handle);
  end;
end;

procedure TMainForm.pnlRenderingSurfaceMouseLeave(Sender: TObject);
begin
  fHoveredAxis := -1;
  if fSimulatePhysics then
    Exit;
  RefreshGizmo;
end;

procedure TMainForm.pnlRenderingSurfaceMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
  deltaX, deltaY: Integer;
  translation, NewWorldPos, NewLocalPos: TVector3;
  rightVec, upVec: TVector3;
  panFactor: Single;
  ParentInv, Proj, ModelView: TMatrix4;
  angleDelta: Single;
  sensitivity: Single;
  newRot: TVector3;
  Viewport: array[0..3] of GLint;

  // Local helper: world to screen coordinates
  function WorldToScreen(const P: TVector3): TPoint;
  var
    Clip: TVector4;
    NDC: TVector3;
  begin
    Clip := Proj * (ModelView * Vector4(P, 1));
    if Clip.W = 0 then Exit(Point(0,0));
    NDC.X := Clip.X / Clip.W;
    NDC.Y := Clip.Y / Clip.W;
    NDC.Z := Clip.Z / Clip.W;
    Result.X := Round((NDC.X * 0.5 + 0.5) * Viewport[2] + Viewport[0]);
    Result.Y := Round((1 - (NDC.Y * 0.5 + 0.5)) * Viewport[3] + Viewport[1]);
  end;

begin
  // Update hover only while idle. Do not rebuild gizmo meshes on every mouse move.
  if (not fSimulatePhysics) and (not fDraggingGizmo) and
     (not fMouseDown) and (not fPanActive) then
  begin
    if Assigned(fCurrentGizmo) then
      UpdateGizmoScale;
    CheckGizmoHover(X, Y);
  end;

  if (not fSimulatePhysics) and fDraggingGizmo then
    begin
    if fGizmoMode = gmTranslate then
      begin
        var u: Single;
        if GetDragParameter(X, Y, u) then
          begin
            var NewHitPointOnAxis := fDragStartObjectPos + fDragAxisWorldDir * u;
            NewWorldPos := NewHitPointOnAxis - fDragOffsetWorld;

            if IsMeshEditModeActive then
            begin
              fSelectedObject.UpdateWorldMatrices;
              var LocalDelta := Vector3(fSelectedObject.WorldMatrix.Inverse *
                Vector4(NewWorldPos - fDragStartObjectPos, 0));
              SetMeshEditorTransformValues(fMeshDragStartTranslation + LocalDelta,
                fMeshDragStartRotationDeg, fMeshDragStartScale, True);
              //fSceneManager.Update;
              if fCurrentGizmo <> nil then
                fCurrentGizmo.Position := GetGizmoTargetWorldPosition;
              if Assigned(fRenderer) then
                fRenderer.Render;
            end
            else
            begin
              ParentInv := fSelectedObject.Parent.WorldMatrix.Inverse;
              fSelectedObject.Position := Vector3(ParentInv * Vector4(NewWorldPos, 1));

              fSelectedObject.NotifyChange;
              fSceneManager.Update;
              // The gizmo is a sibling (not a child), keep it in sync
              fCurrentGizmo.Position := Vector3(fSelectedObject.WorldMatrix.Columns[3]);

              ReadTransformControls(fSelectedObject);
            end;
          end;
      end
    else
      if (fGizmoMode = gmRotate) and (not fMouseDown) then
      begin
        ModelView := fCamera.Camera.ViewMatrix;
        Proj := fRenderer.ProjectionMatrix;
        Viewport[0] := 0;
        Viewport[1] := 0;
        Viewport[2] := pnlRenderingSurface.Width;
        Viewport[3] := pnlRenderingSurface.Height;

        var CenterWorld := GetGizmoTargetWorldPosition;
        var CenterScreen := WorldToScreen(CenterWorld);
        var dx := X - CenterScreen.X;
        var dy := Y - CenterScreen.Y;
        var CurrentAngle := System.Math.ArcTan2(dy, dx);

        if not fRotateStartAngleSet then
        begin
          fRotateStartAngle := CurrentAngle;
          fRotateStartAngleSet := True;
          fDragStartMousePos := Point(X, Y);
          Exit;
        end;

        AngleDelta := CurrentAngle - fRotateStartAngle;
        if AngleDelta > Pi then AngleDelta := AngleDelta - 2*Pi;
        if AngleDelta < -Pi then AngleDelta := AngleDelta + 2*Pi;

        var angleRad := AngleDelta * 1.0; // sensitivity

        if Abs(angleRad) > 0.001 then
        begin
          var WorldAxis: TVector3;
          var RotAngle := angleRad;
          case fDraggedAxis of
            0: WorldAxis := Vector3(1, 0, 0);
            1:
            begin
              WorldAxis := Vector3(0, 1, 0);
              RotAngle := -angleRad;
            end;
            2: WorldAxis := Vector3(0, 0, 1);
          else
            WorldAxis := Vector3(0,0,0);
          end;

          if IsMeshEditModeActive then
          begin
            var MeshTranslation, MeshRotationDeg, MeshScale: TVector3;
            if GetMeshEditorTransformValues(MeshTranslation, MeshRotationDeg, MeshScale) then
            begin
              case fDraggedAxis of
                0: MeshRotationDeg.X := MeshRotationDeg.X + RotAngle * 180.0 / Pi;
                1: MeshRotationDeg.Y := MeshRotationDeg.Y + RotAngle * 180.0 / Pi;
                2: MeshRotationDeg.Z := MeshRotationDeg.Z + RotAngle * 180.0 / Pi;
              end;
              SetMeshEditorTransformValues(MeshTranslation, MeshRotationDeg, MeshScale, True);
              fSceneManager.Update;
              if fCurrentGizmo <> nil then
                fCurrentGizmo.Position := GetGizmoTargetWorldPosition;
            end;
          end
          else
          begin
            RotateObjectAroundWorldAxis(fSelectedObject, WorldAxis, RotAngle);
            fCurrentGizmo.Position := Vector3(fSelectedObject.WorldMatrix.Columns[3]);
            ReadTransformControls(fSelectedObject);
          end;
          fRotateStartAngle := CurrentAngle;
        end;

      end
    else
      if fGizmoMode = gmScale then
        begin
          // Compute current delta from handle screen position
          var curDeltaX := X - fDragStartScreenPos.X;
          var curDeltaY := Y - fDragStartScreenPos.Y;
          var curPixelDelta := curDeltaX * fDragStartScreenAxis.X + curDeltaY * fDragStartScreenAxis.Y;

          // Subtract the initial offset so factor starts at 1.0
          var pixelDelta := curPixelDelta - fDragStartPixelDelta;

          // Sensitivity (adjust as desired)
          Sensitivity := 0.01;
          var factor := 1.0 + pixelDelta * Sensitivity;
          if factor < 0.01 then factor := 0.01;

          var newScale := fInitialScale;
            case fDraggedAxis of
              0: newScale.X := fInitialScale.X * factor;
              1: newScale.Y := fInitialScale.Y * factor;
              2: newScale.Z := fInitialScale.Z * factor;
            end;

          if IsMeshEditModeActive then
          begin
            SetMeshEditorTransformValues(fMeshDragStartTranslation,
              fMeshDragStartRotationDeg, newScale, True);
            fSceneManager.Update;
            if fCurrentGizmo <> nil then
              fCurrentGizmo.Position := GetGizmoTargetWorldPosition;
          end
          else
          begin
            fSelectedObject.Scale := newScale;
            fSelectedObject.NotifyChange;
            if fCurrentGizmo <> nil then
              fCurrentGizmo.Position := Vector3(fSelectedObject.WorldMatrix.Columns[3]);

            ReadTransformControls(fSelectedObject);
          end;
          Exit;
        end;

      Exit;
    end;
  // Right-button orbit
  if fMouseDown then
  begin
    deltaX := X - fLastMouseX;
    deltaY := Y - fLastMouseY;

    if fCamera.Camera.Up = fCameraUp then
      begin
        if deltaX <> 0 then
          fTargetAzimuth := fTargetAzimuth + deltaX * fRotateSpeed;
        if deltaY <> 0 then
          fTargetPolar := fTargetPolar - deltaY * fRotateSpeed;
      end
    else
    if fCamera.Camera.Up = fCameraUp then
      begin
        if deltaX <> 0 then
          fTargetAzimuth := fTargetAzimuth - deltaX * fRotateSpeed;
        if deltaY <> 0 then
          fTargetPolar := fTargetPolar + deltaY * fRotateSpeed;
      end;

    // Clamp target polar angle (to avoid flipping)
    if fTargetPolar < 0.01 then fTargetPolar := 0.01;
    if fTargetPolar > Pi - 0.01 then fTargetPolar := Pi - 0.01;

    fLastMouseX := X;
    fLastMouseY := Y;
  end
  // Middle-button pan
  else if fPanActive then
  begin
    deltaX := X - fLastPanX;
    deltaY := Y - fLastPanY;
    if (deltaX <> 0) or (deltaY <> 0) then
    begin
      rightVec := -fCamera.Camera.Left;   // Right vector
      upVec := fCamera.Camera.Up;
      panFactor := fCurrentRadius * fPanSpeed;   // use current radius for consistent pan speed
      translation := -((rightVec * Single(deltaX)) + (upVec * Single(deltaY)));
      fOrbitTarget := fOrbitTarget + translation * panFactor;
      // No need to clamp orbit target
    end;
    fLastPanX := X;
    fLastPanY := Y;
  end;
end;

procedure TMainForm.pnlRenderingSurfaceMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if fDraggingGizmo then
  begin
    fDraggingGizmo := False;
    fHoveredAxis := -1;
    fDragStartPixelDelta := 0;
    RefreshGizmo;

    if not IsMeshEditModeActive then
      ReadTransformControls(fSelectedObject);

    ReleaseCapture;
    Exit;
  end;

  if Button = mbRight then
  begin
    fMouseDown := False;
    ReleaseCapture;
  end
  else if Button = mbMiddle then
  begin
    fPanActive := False;
    ReleaseCapture;
  end;
end;

procedure TMainForm.pnlRenderingSurfaceResize(Sender: TObject);
begin
  DebugControlBar.Left := pnlRenderingSurface.Width - (DebugControlBar.Width);
  StartPhysicsControlBar.Left := (pnlRenderingSurface.Width - StartPhysicsControlBar.Width) div 2;
end;

procedure TMainForm.MeshRenderHandler(Mesh: TMesh; Shader: TShader);
var
  RenderCamera: TSceneObject;
begin
  ApplyFrameUniformsToShader(Shader);

  Shader.SetUniform('modelMatrix', Mesh.ModelMatrix);

  if Mesh is THeightFieldMesh then
  begin
    RenderCamera := fRenderer.ActiveCamera;
    if RenderCamera = nil then
      RenderCamera := fCamera;

    if Assigned(RenderCamera) and Assigned(RenderCamera.Camera) then
      THeightFieldMesh(Mesh).LODCameraPosition := RenderCamera.Camera.Position;
  end;

  Shader.SetUniform('alpha', 1.0);
end;

procedure TMainForm.mmBackgroundColorClick(Sender: TObject);
var
  aColor: TColor;
  r, g, b: Single;
  r1, g1, b1: Byte;
begin
  // Clamp and convert to 0..255
  r1 := Round(System.Math.EnsureRange(fRenderer.BackgroundColor.R, 0, 1) * 255);
  g1 := Round(System.Math.EnsureRange(fRenderer.BackgroundColor.G, 0, 1) * 255);
  b1 := Round(System.Math.EnsureRange(fRenderer.BackgroundColor.B, 0, 1) * 255);
  // Combine as $00BBGGRR
  ColorDialog1.Color := RGB(r1, g1, b1);

  if ColorDialog1.Execute then
  begin
    aColor := ColorDialog1.Color;
    r := (aColor and $FF) / 255;           // Red
    g := ((aColor shr 8) and $FF) / 255;   // Green
    b := ((aColor shr 16) and $FF) / 255;  // Blue
    fRenderer.BackgroundColor := Vector4(r, g, b, 1.0);
    fRenderer.FogColor := fRenderer.BackgroundColor;
  end;
end;

procedure TMainForm.mmDebugPhysicsClick(Sender: TObject);
begin
  chbDebugPhysics.Checked := mmDebugPhysics.Checked;
  chbDebugPhysics.OnClick(Sender);
end;

procedure TMainForm.mmDebugWireframeClick(Sender: TObject);
begin
  chbDebugWireframe.Checked := mmDebugWireframe.Checked;
  chbDebugWireframe.OnClick(Sender);
end;

procedure TMainForm.MaterialEditorClose(Sender: TObject);
var
  OldSuppress: Boolean;
begin
  if fSelectedMesh = nil then
    Exit;

  OldSuppress := fSuppressMeshEditorChange;
  UnhookMeshEditorEvents;
  fSuppressMeshEditorChange := True;
  try
    FillMeshMaterialControls(fSelectedMesh);
  finally
    fSuppressMeshEditorChange := OldSuppress;
    HookMeshEditorEvents;
  end;
end;
procedure TMainForm.mmMaterialEditorClick(Sender: TObject);
begin
  if not Assigned(frmMaterialEditor) then
  begin
    frmMaterialEditor := TfrmMaterialEditor.Create(Application);
    frmMaterialEditor.UseSharedMaterials(MaterialLibraries, fShader,
      fHeightFieldShader, fRenderer);
  end;

  frmMaterialEditor.OnMaterialEditorClosed := MaterialEditorClose;

  if frmMaterialEditor.WindowState = wsMinimized then
    frmMaterialEditor.WindowState := wsNormal;

  frmMaterialEditor.Show;
  frmMaterialEditor.BringToFront;
end;

procedure TMainForm.mmPhysicsSimulationClick(Sender: TObject);
begin
  if fPhysicsWorld = nil then
    Exit;

  if not fSimulatePhysics then
  begin
    if Assigned(fPhysicsBody) and (not CommitPhysicsChanges) then
      Exit;

    fPhysicsRestorePending := False;

    fPhysicsWorld.ApplyStagedBodyStates;

    if not fPhysicsWorld.HasTransformBackup then
      fPhysicsWorld.CaptureSceneTransforms;

    if fPhysicsWorld.ActiveSimulationBodyCount = 0 then
    begin
      fPhysicsWorld.RestoreSceneTransforms(False);
      mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) +
        'Physics simulation not started: no enabled dynamic bodies.');
      Exit;
    end;

    fPhysicsWorld.EnsureNativeScene;

    SetPhysicsSimulationMode(True);
    mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) +
      'Physics simulation started.');
  end
  else
  begin
    // This is STOP, not pause.
    fSimulatePhysics := False;
    fPhysicsRestorePending := True;
  end;
end;

procedure TMainForm.UpdateOrbitCamera;
var
  x, y, z: Single;
  pos: TVector3;
begin
  // Spherical to Cartesian using current (smoothed) parameters
  x := fCurrentRadius * Sin(fCurrentPolar) * Cos(fCurrentAzimuth);
  y := fCurrentRadius * Cos(fCurrentPolar);
  z := fCurrentRadius * Sin(fCurrentPolar) * Sin(fCurrentAzimuth);
  pos := Vector3(x, y, z) + fOrbitTarget;
  fCamera.Camera.LookAt(pos, fOrbitTarget, fCameraUp);
  UpdateGizmoScale;
end;

procedure TMainForm.ApplyToShader(Shader: TShader; Index: Integer);
begin
  if Assigned(fLight) and (fLight.LightsCount > 0) then
    ApplyLightToShader(Shader, fLight.Light[0], Index);
end;

procedure TMainForm.ApplyLightToShader(Shader: TShader; Light: TLight; Index: Integer);
var
  Prefix: string;
  TypeInt: Integer;
  CosCutoff: Single;
  Direction: TVector3;
begin
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
    ltPoint:       TypeInt := 1;
    ltSpot:        TypeInt := 2;
  else
    TypeInt := 0;
  end;

  Shader.SetUniform(Prefix + 'enabled', Ord(Light.Enabled));
  Shader.SetUniform(Prefix + 'type', TypeInt);
  Shader.SetUniform(Prefix + 'ambient',  Light.Ambient);
  Shader.SetUniform(Prefix + 'diffuse',  Light.Diffuse);
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
  Shader.SetUniform(Prefix + 'constantAttenuation',  Light.ConstantAttenuation);
  Shader.SetUniform(Prefix + 'linearAttenuation',    Light.LinearAttenuation);
  Shader.SetUniform(Prefix + 'quadraticAttenuation', Light.QuadraticAttenuation);

  CosCutoff := Cos(Light.SpotCutoff);
  Shader.SetUniform(Prefix + 'spotCutoff', CosCutoff);
  Shader.SetUniform(Prefix + 'spotExponent', Light.SpotExponent);
end;

procedure TMainForm.ApplySceneLightsToShader(Shader: TShader);
const
  MAX_SHADER_LIGHTS = 8;
var
  Lights: TArray<TLight>;
  ShadowCaster: TLight;
  LightCount: Integer;
  ShadowLightIndex: Integer;
  I: Integer;
begin
  if not Assigned(Shader) then
    Exit;

  if not Assigned(fSceneManager) then
  begin
    Shader.SetUniform('lightCount', 0);
    Shader.SetUniform('shadowLightIndex', -1);
    Shader.SetUniform('shadowStrength', 0.0);
    Exit;
  end;

  Lights := fSceneManager.GetLights;
  LightCount := Min(Length(Lights), MAX_SHADER_LIGHTS);
  Shader.SetUniform('lightCount', LightCount);

  ShadowCaster := nil;
  ShadowLightIndex := -1;

  if Assigned(fRenderer) and Assigned(fRenderer.ShadowLight) and
     (fRenderer.ShadowLight.LightsCount > 0) then
  begin
    ShadowCaster := fRenderer.ShadowLight.Light[0];
    if Assigned(ShadowCaster) and
       ((not ShadowCaster.Enabled) or (not ShadowCaster.CastShadows)) then
      ShadowCaster := nil;
  end;

  if ShadowCaster = nil then
  begin
    for I := 0 to LightCount - 1 do
      if Assigned(Lights[I]) and Lights[I].Enabled and Lights[I].CastShadows then
      begin
        ShadowCaster := Lights[I];
        Break;
      end;
  end;

  if Assigned(ShadowCaster) then
  begin
    for I := 0 to LightCount - 1 do
      if Lights[I] = ShadowCaster then
      begin
        ShadowLightIndex := I;
        Break;
      end;
    Shader.SetUniform('shadowStrength', ShadowCaster.ShadowStrength);
  end
  else
    Shader.SetUniform('shadowStrength', 0.0);

  Shader.SetUniform('shadowLightIndex', ShadowLightIndex);

  for I := 0 to LightCount - 1 do
    ApplyLightToShader(Shader, Lights[I], I);

  for I := LightCount to MAX_SHADER_LIGHTS - 1 do
    Shader.SetUniform(Format('lights[%d].enabled', [I]), 0);
end;

function TMainForm.CreateTranslateGizmo(ParentObj: TSceneObject): TSceneObject;
const
  ArrowLen = 0.5;
  ShaftRad = 0.01;
  TipRad   = 0.03;
  TipLen   = 0.1;
  CubeSize = 0.08;
var
  GizmoRoot, ArrowX, ArrowY, ArrowZ, CenterCube: TSceneObject;
  tmpMesh: TMesh;
begin
  GizmoRoot := TSceneObject.Create(fRoot);
  GizmoRoot.Name := 'TranslateGizmo';
  GizmoRoot.IsGizmo := True;
  // Set world position to the selected object's world position
  GizmoRoot.Position := GetGizmoTargetWorldPosition;
  GizmoRoot.Rotation := Vector3(0, 0, 0);   // world-aligned

  // X axis (Red) - points world X
  ArrowX := TSceneObject.Create(GizmoRoot);
  ArrowX.Name := 'Gizmo_X';
  ArrowX.IsGizmo := True;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateArrow(ArrowLen, TipLen, ShaftRad, TipRad, 12, 4, ArrowX.Name);
  ArrowX.MeshList.AddMeshToList(tmpMesh);

  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'GizmoColorMaterial';
  tmpMesh.Tag := 0;
  tmpMesh.OnRender := GizmoMeshRenderHandler;
  ArrowX.Rotation := Vector3(0, 0, DegToRad(90));
  tmpMesh.AlwaysOnTop := True;
  tmpMesh := nil;

  // Y axis (Green) - points world Y
  ArrowY := TSceneObject.Create(GizmoRoot);
  ArrowY.Name := 'Gizmo_Y';
  ArrowY.IsGizmo := True;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateArrow(ArrowLen, TipLen, ShaftRad, TipRad, 12, 4, ArrowY.Name);
  ArrowY.MeshList.AddMeshToList(tmpMesh);
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'GizmoColorMaterial';
  tmpMesh.Tag := 1;
  tmpMesh.OnRender := GizmoMeshRenderHandler;
  tmpMesh.AlwaysOnTop := True;
  tmpMesh := nil;

  // Z axis (Blue) - points world Z
  ArrowZ := TSceneObject.Create(GizmoRoot);
  ArrowZ.Name := 'Gizmo_Z';
  ArrowZ.IsGizmo := True;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateArrow(ArrowLen, TipLen, ShaftRad, TipRad, 12, 4, ArrowZ.Name);
  ArrowZ.MeshList.AddMeshToList(tmpMesh);
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'GizmoColorMaterial';
  tmpMesh.Tag := 2;
  tmpMesh.OnRender := GizmoMeshRenderHandler;
  ArrowZ.Rotation := Vector3(DegToRad(-90), 0, 0);
  tmpMesh.AlwaysOnTop := True;
  tmpMesh := nil;

  // Center cube (Yellow)
  CenterCube := TSceneObject.Create(GizmoRoot);
  CenterCube.Name := 'Gizmo_Center';
  CenterCube.IsGizmo := True;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateCube(CubeSize, CubeSize, CubeSize, 4, 4, 4, CenterCube.Name);
  CenterCube.MeshList.AddMeshToList(tmpMesh);
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'GizmoColorMaterial';
  tmpMesh.Tag := 3;
  tmpMesh.OnRender := GizmoMeshRenderHandler;
  tmpMesh.AlwaysOnTop := True;
  tmpMesh := nil;

  Result := GizmoRoot;
end;

function TMainForm.CreateRotateGizmo(ParentObj: TSceneObject): TSceneObject;
const
  RingRadius = 0.6;
  RingThickness = 0.01;
var
  GizmoRoot, RingX, RingY, RingZ, CenterSphere: TSceneObject;
  tmpMesh: TMesh;
begin
  // Attach to world root ? no inherited rotation
  GizmoRoot := TSceneObject.Create(fRoot);
  GizmoRoot.Name := 'RotateGizmo';
  GizmoRoot.IsGizmo := True;
  GizmoRoot.Position := GetGizmoTargetWorldPosition; // world position
  GizmoRoot.Rotation := Vector3(0,0,0); // world-aligned

  // X-axis ring (Red) ? lies in YZ plane
  RingX := TSceneObject.Create(GizmoRoot);
  RingX.Name := 'Gizmo_RingX';
  RingX.IsGizmo := True;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateTorus(RingRadius, RingThickness, 32, 16, RingX.Name);
  RingX.MeshList.AddMeshToList(tmpMesh);
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'GizmoColorMaterial';
  tmpMesh.Tag := 0;
  tmpMesh.OnRender := GizmoMeshRenderHandler;
  RingX.Rotation := Vector3(0, DegToRad(90), 0); // rotate to YZ plane
  tmpMesh.AlwaysOnTop := True;
  tmpMesh := nil;

  // Y-axis ring (Green) ? lies in XZ plane
  RingY := TSceneObject.Create(GizmoRoot);
  RingY.Name := 'Gizmo_RingY';
  RingY.IsGizmo := True;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateTorus(RingRadius, RingThickness, 32, 16, RingY.Name);
  RingY.MeshList.AddMeshToList(tmpMesh);
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'GizmoColorMaterial';
  tmpMesh.Tag := 1;
  tmpMesh.OnRender := GizmoMeshRenderHandler;
  RingY.Rotation := Vector3(DegToRad(90), 0, 0); // rotate to XZ plane
  tmpMesh.AlwaysOnTop := True;
  tmpMesh := nil;

  // Z-axis ring (Blue) ? lies in XY plane (default torus orientation)
  RingZ := TSceneObject.Create(GizmoRoot);
  RingZ.Name := 'Gizmo_RingZ';
  RingZ.IsGizmo := True;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateTorus(RingRadius, RingThickness, 32, 16, RingZ.Name);
  RingZ.MeshList.AddMeshToList(tmpMesh);
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'GizmoColorMaterial';
  tmpMesh.Tag := 2;
  tmpMesh.OnRender := GizmoMeshRenderHandler;
  tmpMesh.AlwaysOnTop := True;
  tmpMesh := nil;

  // Center sphere (Yellow)
  CenterSphere := TSceneObject.Create(GizmoRoot);
  CenterSphere.Name := 'Gizmo_CenterSphere';
  CenterSphere.IsGizmo := True;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateSphere(0.03, 1, 1, CenterSphere.Name);
  CenterSphere.MeshList.AddMeshToList(tmpMesh);
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'GizmoColorMaterial';
  tmpMesh.Tag := 3;
  tmpMesh.OnRender := GizmoMeshRenderHandler;
  tmpMesh.AlwaysOnTop := True;

  Result := GizmoRoot;
end;

function TMainForm.CreateScaleGizmo(ParentObj: TSceneObject): TSceneObject;
const
  AxisLen = 0.5;           // total length from center to tip (cube position)
  ShaftRad = 0.01;
  TipRad   = 0.02;
  TipLen   = 0.01;
  CubeSize = 0.06;
  Gap = 0.05;              // gap between center and arrow base
var
  GizmoRoot, ArrowX, ArrowY, ArrowZ, CubeX, CubeY, CubeZ, CenterCube: TSceneObject;
  ArrowLen: Single;
  tmpMesh: TMesh;
begin
  GizmoRoot := TSceneObject.Create(fRoot);
  GizmoRoot.Name := 'ScaleGizmo';
  GizmoRoot.IsGizmo := True;
  GizmoRoot.Position := GetGizmoTargetWorldPosition;
  GizmoRoot.Scale := Vector3(1,1,1);
  GizmoRoot.Rotation := Vector3(0,0,0);

  ArrowLen := AxisLen - Gap;   // length of the arrow (base to tip)

  // ---- X axis (red) ----
  ArrowX := TSceneObject.Create(GizmoRoot);
  ArrowX.Name := 'Gizmo_xArrow';
  ArrowX.IsGizmo := True;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateArrow(ArrowLen, TipLen, ShaftRad, TipRad, 12, 1, ArrowX.Name);
  ArrowX.MeshList.AddMeshToList(tmpMesh);
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'GizmoColorMaterial';
  tmpMesh.Tag := 0;
  tmpMesh.OnRender := GizmoMeshRenderHandler;
  ArrowX.Rotation := Vector3(0, 0, DegToRad(-90));  // point +X
  ArrowX.Position := Vector3(Gap, 0, 0);            // base at Gap
  tmpMesh.AlwaysOnTop := True;
  tmpMesh := nil;

  CubeX := TSceneObject.Create(GizmoRoot);
  CubeX.Name := 'Gizmo_xCube';
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateCube(CubeSize, CubeSize, CubeSize, 1,1,1, CubeX.Name);
  CubeX.MeshList.AddMeshToList(tmpMesh);
  CubeX.Position := Vector3(AxisLen, 0, 0);         // tip at AxisLen
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'GizmoColorMaterial';
  tmpMesh.Tag := 0;
  tmpMesh.OnRender := GizmoMeshRenderHandler;
  tmpMesh.AlwaysOnTop := True;
  tmpMesh := nil;

  // ---- Y axis (green) ----
  ArrowY := TSceneObject.Create(GizmoRoot);
  ArrowY.Name := 'Gizmo_yArrow';
  ArrowY.IsGizmo := True;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateArrow(ArrowLen, TipLen, ShaftRad, TipRad, 12, 4, ArrowY.Name);
  ArrowY.MeshList.AddMeshToList(tmpMesh);
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'GizmoColorMaterial';
  tmpMesh.Tag := 1;
  tmpMesh.OnRender := GizmoMeshRenderHandler;
  // No rotation needed (arrow points +Y by default)
  ArrowY.Position := Vector3(0, Gap, 0);            // base at Gap
  tmpMesh.AlwaysOnTop := True;
  tmpMesh := nil;

  CubeY := TSceneObject.Create(GizmoRoot);
  CubeY.Name := 'Gizmo_yCube';
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateCube(CubeSize, CubeSize, CubeSize, 1,1,1, CubeY.Name);
  CubeY.MeshList.AddMeshToList(tmpMesh);
  CubeY.Position := Vector3(0, AxisLen, 0);
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'GizmoColorMaterial';
  tmpMesh.Tag := 1;
  tmpMesh.OnRender := GizmoMeshRenderHandler;
  tmpMesh.AlwaysOnTop := True;
  tmpMesh := nil;

  // ---- Z axis (blue) ----
  ArrowZ := TSceneObject.Create(GizmoRoot);
  ArrowZ.Name := 'Gizmo_zArrow';
  ArrowZ.IsGizmo := True;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateArrow(ArrowLen, TipLen, ShaftRad, TipRad, 12, 4, ArrowZ.Name);
  ArrowZ.MeshList.AddMeshToList(tmpMesh);
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'GizmoColorMaterial';
  tmpMesh.Tag := 2;
  tmpMesh.OnRender := GizmoMeshRenderHandler;
  ArrowZ.Rotation := Vector3(DegToRad(90), 0, 0);   // point +Z
  ArrowZ.Position := Vector3(0, 0, Gap);            // base at Gap
  tmpMesh.AlwaysOnTop := True;
  tmpMesh := nil;

  CubeZ := TSceneObject.Create(GizmoRoot);
  CubeZ.Name := 'Gizmo_zCube';
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateCube(CubeSize, CubeSize, CubeSize, 1,1,1, CubeZ.Name);
  CubeZ.MeshList.AddMeshToList(tmpMesh);
  CubeZ.Position := Vector3(0, 0, AxisLen);
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'GizmoColorMaterial';
  tmpMesh.Tag := 2;
  tmpMesh.OnRender := GizmoMeshRenderHandler;
  tmpMesh.AlwaysOnTop := True;
  tmpMesh := nil;

  // Center cube (Yellow)
  CenterCube := TSceneObject.Create(GizmoRoot);
  CenterCube.Name := 'Gizmo_CenterCube';
  CenterCube.IsGizmo := True;
  ActivateMainRenderContext;
  tmpMesh := TMeshFactory.CreateCube(CubeSize +0.02, CubeSize+0.02, CubeSize+0.02, 1, 1, 1, CenterCube.Name);
  CenterCube.MeshList.AddMeshToList(tmpMesh);
  tmpMesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
  tmpMesh.LibMaterialname := 'GizmoColorMaterial';
  tmpMesh.Tag := 3;
  tmpMesh.OnRender := GizmoMeshRenderHandler;
  tmpMesh.AlwaysOnTop := True;
  tmpMesh := nil;

  Result := GizmoRoot;
end;

procedure TMainForm.SynchronizeTreeViewSelection(Obj: TSceneObject);
var
  Node: TTreeNode;
  OldOnClick: TNotifyEvent;
begin
  // Find the tree node that holds this object
  Node := nil;
  for var N in scTree.Items do
    if N.Data = Obj then
    begin
      Node := N;
      Break;
    end;
  if Node = nil then Exit;

  // Expand all parent nodes so the node becomes visible
  var Parent := Node.Parent;
  while Parent <> nil do
  begin
    Parent.Expanded := True;
    Parent := Parent.Parent;
  end;

  // Temporarily remove the OnClick handler to prevent recursion
  OldOnClick := scTree.OnClick;
  scTree.OnClick := nil;
  try
    scTree.Selected := Node;
    Node.MakeVisible;
  finally
    scTree.OnClick := OldOnClick;
  end;
end;

procedure TMainForm.RotateObjectAroundWorldAxis(Obj: TSceneObject; const WorldAxis: TVector3; AngleRad: Single);
var
  LocalAxis: TVector3;
  ParentInv: TMatrix4;
  DeltaQuat: TQuaternion;
begin
  if Obj.Parent <> nil then
    ParentInv := Obj.Parent.WorldMatrix.Inverse
  else
    ParentInv := TMatrix4.Identity;

  LocalAxis := Vector3(ParentInv * Vector4(WorldAxis, 0));
  LocalAxis.SetNormalized;

  DeltaQuat.Init(LocalAxis, AngleRad);
  Obj.Orientation := DeltaQuat * Obj.Orientation; // world-space rotation
  Obj.NotifyChange;
  fSceneManager.Update;
end;

function TMainForm.ProjectMouseToAxisPlane(X, Y: Integer; const AxisDir, PlanePoint: TVector3; out PointOnAxis: TVector3): Boolean;
var
  RayOrigin, RayDir: TVector3;
  PlaneNormal: TVector3;
  Denom, t: Single;
  Q: TVector3;
begin
  ScreenToWorldRay(X, Y, pnlRenderingSurface.Width, pnlRenderingSurface.Height,
    fCamera.Camera.ViewMatrix, fRenderer.ProjectionMatrix, RayOrigin, RayDir);
  // Plane through PlanePoint, perpendicular to camera view direction
  PlaneNormal := fCamera.Camera.Front;
  Denom := RayDir.Dot(PlaneNormal);
  if Abs(Denom) < 1e-6 then Exit(False);
  t := (PlanePoint - RayOrigin).Dot(PlaneNormal) / Denom;
  Q := RayOrigin + RayDir * t;   // point on plane under mouse
  // Project Q onto the axis line (through object center)
  var w := Q - fDragStartObjectPos;
  var tAxis := w.Dot(AxisDir);   // AxisDir is normalized
  PointOnAxis := fDragStartObjectPos + AxisDir * tAxis;
  Result := True;
end;

function TMainForm.IsMeshEditModeActive: Boolean;
begin
  Result := newMeshEditor.Visible and Assigned(fSelectedObject) and Assigned(fSelectedMesh);
end;

function TMainForm.GetGizmoTargetWorldPosition: TVector3;
var
  LocalCenter: TVector3;
begin
  if IsMeshEditModeActive then
  begin
    fSelectedObject.UpdateWorldMatrices;
    LocalCenter := (fSelectedMesh.BoundingBoxMin + fSelectedMesh.BoundingBoxMax) * 0.5;
    Exit(Vector3(fSelectedMesh.ModelMatrix * Vector4(LocalCenter, 1.0)));
  end;

  if Assigned(fSelectedObject) then
    Result := Vector3(fSelectedObject.WorldMatrix.Columns[3])
  else
    Result := Vector3(0, 0, 0);
end;

function TMainForm.SelectObjectAtScreenPos(X, Y: Integer): Boolean;
const
  PICK_TIE_EPSILON = 1e-4;
var
  RayOrigin, RayDir: TVector3;
  BestHit: TSceneObject;
  BestMeshIndex: Integer;
  BestT: Single;

  procedure TestMesh(Obj: TSceneObject);
  var
    i, j: Integer;
    Mesh: TMesh;
    WorldV0, WorldV1, WorldV2: TVector3;
    t, u, v: Single;
    WorldMat: TMatrix4;
    SphereDist: Single;
    WorldCenter: TVector3;
    Indices: TArray<GLuint>;
    Vertices: TArray<TVertex>;
  begin
    if (Obj = nil) or (Obj.IsGizmo) then Exit;

    // Broad phase using object?s bounding sphere
    WorldCenter := Vector3(Obj.WorldMatrix.Columns[3]);
    if not IntersectRaySphere(RayOrigin, RayDir, WorldCenter, Obj.BoundingRadius, SphereDist) then
      Exit;
    if SphereDist > BestT then
      Exit;

    // Iterate over all meshes in the list
    for i := 0 to Obj.MeshList.Count - 1 do
    begin
      Mesh := Obj.MeshList.Item[i];
      if Mesh = nil then Continue;

      WorldMat := Mesh.ModelMatrix;
      Indices := Mesh.Indices;
      Vertices := Mesh.Vertices;

      j := 0;
      while j < Length(Indices) do
      begin
        WorldV0 := Vector3(WorldMat * Vector4(Vertices[Indices[j]].Position, 1));
        WorldV1 := Vector3(WorldMat * Vector4(Vertices[Indices[j+1]].Position, 1));
        WorldV2 := Vector3(WorldMat * Vector4(Vertices[Indices[j+2]].Position, 1));

        if IntersectRayTriangle(RayOrigin, RayDir, WorldV0, WorldV1, WorldV2, t, u, v) then
          if (BestHit = nil) or
             (t < BestT - PICK_TIE_EPSILON) or
             (Abs(t - BestT) <= PICK_TIE_EPSILON) then
          begin
            BestHit := Obj;
            BestMeshIndex := i;
            BestT := t;
          end;
        Inc(j, 3);
      end;
    end;
  end;

  procedure Traverse(Obj: TSceneObject);
  var
    k: Integer;
  begin
    TestMesh(Obj);
    for k := 0 to Obj.Count - 1 do
      Traverse(Obj.ObjectList[k]);
  end;

var
  i: Integer;
begin
  fSceneManager.Update;
  ScreenToWorldRay(X, Y, pnlRenderingSurface.Width, pnlRenderingSurface.Height,
    fCamera.Camera.ViewMatrix, fRenderer.ProjectionMatrix, RayOrigin, RayDir);
  BestHit := nil;
  BestMeshIndex := -1;
  BestT := MaxSingle;

  for i := 0 to fSceneManager.Count - 1 do
    Traverse(fSceneManager.Root.ObjectList[i]);

  Result := (BestHit <> nil);
  if not Result then
    Exit;

  // --- Update selection ---
  fSelectedObject := BestHit;
  fLastPickedMeshIndex := BestMeshIndex;
  fSelectedObject.UpdateWorldMatrices;
  if Assigned(fCurrentGizmo) then
    FreeAndNil(fCurrentGizmo);
  RefreshSelectedBoundingBox;

  if not fSelectedObject.IsGizmo then
  begin
    case fGizmoMode of
      gmTranslate: fCurrentGizmo := CreateTranslateGizmo(fSelectedObject);
      gmRotate:    fCurrentGizmo := CreateRotateGizmo(fSelectedObject);
      gmScale:     fCurrentGizmo := CreateScaleGizmo(fSelectedObject);
    end;
    if fCurrentGizmo <> nil then
    begin
      fCurrentGizmo.UpdateWorldMatrices;
      RefreshPhysicsDebugHull;
      fRenderer.Render;
    end;
  end
  else
    fCurrentGizmo := nil;

  SynchronizeTreeViewSelection(fSelectedObject);
  UpdateUI;
  RefreshPhysicsDebugHull;
end;

procedure TMainForm.DeselectObject;
var
  OldClick: TNotifyEvent;
begin
  if fSelectedObject = nil then
  begin
    ClearPhysicsDebugHull;
    RefreshSelectedBoundingBox;
    if Assigned(fRenderer) then
      fRenderer.Render;
    Exit;
  end;
  fSelectedObject := nil;
  fLastPickedMeshIndex := -1;
  RefreshSelectedBoundingBox;

  if Assigned(fCurrentGizmo) then
    FreeAndNil(fCurrentGizmo);
  ClearPhysicsDebugHull;
  UpdateUI;

  OldClick := scTree.OnClick;
  scTree.OnClick := nil;
  try
    scTree.Selected := nil;
    ResetTransformControls;
    ResetMeshes;
    ResetPhysicsControls;
    fNewObjectMode := False;
    UpdateObjectCommandStates;
  finally
    scTree.OnClick := OldClick;
  end;

  if Assigned(fRenderer) then
    fRenderer.Render;
end;

function TMainForm.PickGizmoAxis(X, Y: Integer; out AxisTag: Integer): Boolean;
var
  RayOrigin, RayDir: TVector3;
  BestT: Single;
  i: Integer;
  Obj: TSceneObject;
  HitT: Single;
begin
  Result := False;
  if (fCurrentGizmo = nil) or (fSelectedObject = nil) then Exit;

  ScreenToWorldRay(X, Y, fRenderer.Width, fRenderer.Height,
    fCamera.Camera.ViewMatrix, fRenderer.ProjectionMatrix, RayOrigin, RayDir);

  BestT := MaxSingle;
  AxisTag := -1;

  for i := 0 to fCurrentGizmo.Count - 1 do
  begin
    Obj := fCurrentGizmo.ObjectList[i];
    if (Obj = nil) then Continue;

    if not (Obj.MeshList.Item[0].Tag in [0,1,2]) then Continue;

    if RayIntersectsMesh(RayOrigin, RayDir, Obj.MeshList.Item[0].Indices, Obj.MeshList.Item[0].Vertices,
      Obj.MeshList.Item[0].ModelMatrix, HitT) then
      if HitT < BestT then
      begin
        BestT := HitT;
        AxisTag := Obj.MeshList.Item[0].Tag;
      end;
  end;

  Result := (AxisTag <> -1);
end;

function TMainForm.PickRotateAxis(X, Y: Integer; out AxisTag: Integer): Boolean;
var
  RayOrigin, RayDir: TVector3;
  BestT: Single;
  i: Integer;
  Obj: TSceneObject;
  HitT: Single;
begin
  Result := False;
  if (fCurrentGizmo = nil) or (fSelectedObject = nil) then Exit;

  ScreenToWorldRay(X, Y, pnlRenderingSurface.Width, pnlRenderingSurface.Height,
    fCamera.Camera.ViewMatrix, fRenderer.ProjectionMatrix, RayOrigin, RayDir);

  BestT := MaxSingle;
  AxisTag := -1;

  for i := 0 to fCurrentGizmo.Count - 1 do
  begin
    Obj := fCurrentGizmo.ObjectList[i];
    if (Obj = nil) then Continue;
    // Tags: 0=X-ring, 1=Y-ring, 2=Z-ring, 3=center sphere (ignore)
    if not (Obj.MeshList.Item[0].Tag in [0,1,2]) then Continue;

    if RayIntersectsMesh(RayOrigin, RayDir, Obj.MeshList.Item[0].Indices, Obj.MeshList.Item[0].Vertices,
      Obj.MeshList.Item[0].ModelMatrix, HitT) then
      if HitT < BestT then
      begin
        BestT := HitT;
        AxisTag := Obj.MeshList.Item[0].Tag;
      end;
  end;

  Result := (AxisTag <> -1);
end;

function TMainForm.PickScaleGizmoAxis(X, Y: Integer; out AxisTag: Integer): Boolean;
var
  RayOrigin, RayDir: TVector3;
  BestT: Single;
  i: Integer;
  Obj: TSceneObject;
  HitT: Single;
begin
  Result := False;
  if (fCurrentGizmo = nil) or (fSelectedObject = nil) then Exit;

  ScreenToWorldRay(X, Y, pnlRenderingSurface.Width, pnlRenderingSurface.Height,
    fCamera.Camera.ViewMatrix, fRenderer.ProjectionMatrix, RayOrigin, RayDir);

  BestT := MaxSingle;
  AxisTag := -1;

  for i := 0 to fCurrentGizmo.Count - 1 do
  begin
    Obj := fCurrentGizmo.ObjectList[i];
    if (Obj = nil) then Continue;

    if not (Obj.MeshList.Item[0].Tag in [0,1,2]) then Continue;

    if RayIntersectsMesh(RayOrigin, RayDir, Obj.MeshList.Item[0].Indices, Obj.MeshList.Item[0].Vertices,
      Obj.MeshList.Item[0].ModelMatrix, HitT) then
      if HitT < BestT then
      begin
        BestT := HitT;
        AxisTag := Obj.MeshList.Item[0].Tag;
      end;
  end;

  Result := (AxisTag <> -1);
end;

function TMainForm.GetArrowTipByTag(AxisTag: Integer): TVector3;
const
  ArrowLen = 0.5;
var
  i: Integer;
begin
  Result := Vector3(0,0,0);
  if fCurrentGizmo = nil then Exit;
  for i := 0 to fCurrentGizmo.Count - 1 do
    if fCurrentGizmo.ObjectList[i].MeshList.Item[0].Tag = AxisTag then
    begin
      Result := Vector3(fCurrentGizmo.ObjectList[i].WorldMatrix * Vector4(0, ArrowLen, 0, 1));
      Exit;
    end;
end;

function TMainForm.GetScaleTipByTag(AxisTag: Integer): TVector3;
var
  i: Integer;
  Obj: TSceneObject;
begin
  Result := Vector3(0,0,0);
  if fCurrentGizmo = nil then Exit;
  for i := 0 to fCurrentGizmo.Count - 1 do
  begin
    Obj := fCurrentGizmo.ObjectList[i];
    if (Obj <> nil) and (Obj.HasGeometry <> True) and (Obj.MeshList.Item[0].Tag = AxisTag) then
    begin
      Result := Vector3(Obj.WorldMatrix.Columns[3]);
      Break;
    end;
  end;
end;

function TMainForm.GetDragParameter(CurrentX, CurrentY: Integer; out u: Single): Boolean;
var
  RayOrigin, RayDir: TVector3;
  w: TVector3;
  a, b, c, d, e, denom: Single;
begin
  Result := False;
  ScreenToWorldRay(CurrentX, CurrentY, pnlRenderingSurface.Width, pnlRenderingSurface.Height,
    fCamera.Camera.ViewMatrix, fRenderer.ProjectionMatrix, RayOrigin, RayDir);

  w := RayOrigin - fDragStartObjectPos;
  a := RayDir.Dot(RayDir);
  b := RayDir.Dot(fDragAxisWorldDir);
  c := fDragAxisWorldDir.Dot(fDragAxisWorldDir);
  d := RayDir.Dot(w);
  e := fDragAxisWorldDir.Dot(w);
  denom := a * c - b * b;
  if Abs(denom) < 1e-4 then Exit;
  u := (a * e - b * d) / denom;
  Result := True;
end;

procedure TMainForm.CentralEditorMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
const
  ScrollSpeed = 30;   // pixels per WHEEL_DELTA (120) unit � change to taste
begin
  Handled := True;
  CentralEditor.VertScrollBar.Position :=
    CentralEditor.VertScrollBar.Position -
    (WheelDelta div WHEEL_DELTA) * ScrollSpeed;
end;

procedure TMainForm.chbDebugWireframeClick(Sender: TObject);
begin
  fSceneManager.WireFrame := chbDebugWireframe.Checked;
end;

procedure TMainForm.chbEnableFogClick(Sender: TObject);
begin
  fRenderer.FogEnabled := chbEnableFog.Checked;
end;

procedure TMainForm.chbDebugPhysicsClick(Sender: TObject);
begin
  if chbDebugPhysics.Checked then
    RefreshPhysicsDebugHull
  else
    ClearPhysicsDebugHull;

  if Assigned(fRenderer) then
    fRenderer.Render;
end;

procedure TMainForm.chbShowBoundingBoxClick(Sender: TObject);
begin
  RefreshSelectedBoundingBox;
  if Assigned(fRenderer) then
    fRenderer.Render;
end;

function TMainForm.IsNewObjectEditorActive: Boolean;
begin
  Result := fNewObjectMode and Assigned(frmMeshCreator) and frmMeshCreator.Visible;
end;

procedure TMainForm.CheckGizmoHover(X, Y: Integer);
var
  DummyAxis: Integer;
begin
  if fCurrentGizmo = nil then
    begin
      fHoveredAxis := -1;
      Exit;
    end;

  if fGizmoMode = gmTranslate then
    begin
      if PickGizmoAxis(X, Y, DummyAxis) then
        fHoveredAxis := DummyAxis
      else
        fHoveredAxis := -1;
    end
  else if fGizmoMode = gmRotate then
    begin
      if PickRotateAxis(X, Y, DummyAxis) then
        fHoveredAxis := DummyAxis
      else
        fHoveredAxis := -1;
    end
  else if fGizmoMode = gmScale then
    begin
      if PickScaleGizmoAxis(X, Y, DummyAxis) then
        fHoveredAxis := DummyAxis
      else
        fHoveredAxis := -1;
    end;
end;

procedure TMainForm.RefreshSelectedBoundingBox;
begin
  if not Assigned(fRenderer) then
    Exit;

  fRenderer.SelectedBoundingBoxEnabled := chbShowBoundingBox.Checked;
  fRenderer.SelectedBoundingBoxColor := Vector4(0.0, 1.0, 0.0, 1.0);

  if chbShowBoundingBox.Checked and Assigned(fSelectedObject) and
     (not fSelectedObject.IsGizmo) then
    fRenderer.SelectedBoundingBoxObject := fSelectedObject
  else
    fRenderer.SelectedBoundingBoxObject := nil;
end;

procedure TMainForm.RefreshGizmo;
var
  NeedRebuild: Boolean;
begin
  RefreshSelectedBoundingBox;

  if fSimulatePhysics then
  begin
    if Assigned(fCurrentGizmo) then
      FreeAndNil(fCurrentGizmo);
    fGizmoOwner := nil;
    fHoveredAxis := -1;
    Exit;
  end;

  if (fSelectedObject = nil) or fSelectedObject.IsGizmo then
  begin
    if Assigned(fCurrentGizmo) then
      FreeAndNil(fCurrentGizmo);
    fGizmoOwner := nil;
    fHoveredAxis := -1;
    Exit;
  end;

  NeedRebuild :=
    (fCurrentGizmo = nil) or
    (fGizmoOwner <> fSelectedObject) or
    (fBuiltGizmoMode <> fGizmoMode);

  if NeedRebuild then
  begin
    if Assigned(fCurrentGizmo) then
      FreeAndNil(fCurrentGizmo);

    case fGizmoMode of
      gmTranslate: fCurrentGizmo := CreateTranslateGizmo(fSelectedObject);
      gmRotate:    fCurrentGizmo := CreateRotateGizmo(fSelectedObject);
      gmScale:     fCurrentGizmo := CreateScaleGizmo(fSelectedObject);
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

procedure TMainForm.SyncGizmoModeButtons;
begin
  spbMove.Down := fGizmoMode = gmTranslate;
  spbRotate.Down := fGizmoMode = gmRotate;
  spbScale.Down := fGizmoMode = gmScale;

  mmEditPosition.Checked := fGizmoMode = gmTranslate;
  mmEditRotation.Checked := fGizmoMode = gmRotate;
  mmEditScale.Checked := fGizmoMode = gmScale;
end;

procedure TMainForm.ClearPhysicsDebugHull;
begin
  if Assigned(fPhysicsDebugHull) then
    FreeAndNil(fPhysicsDebugHull);
  fPhysicsDebugHullOwner := nil;
end;

procedure TMainForm.RefreshPhysicsDebugHull;
var
  Body: TPhysicsBody;
  Mesh: TMesh;
  I: Integer;

  function PhysicsDebugColorTag(ABody: TPhysicsBody): Integer;
  begin
    if not fSimulatePhysics then
      Exit(3); // Yellow: simulation is stopped.

    if (ABody <> nil) and ABody.HasContact then
      Exit(0); // Red: body is touching another body.

    if (ABody = nil) or (not ABody.IsDynamic) or ABody.Sleeping then
      Exit(1); // Green: static or sleeping/resting.

    Result := 2; // Blue: awake and moving/free.
  end;
begin
  if (not chbDebugPhysics.Checked) or
     (fPhysicsWorld = nil) or (fRoot = nil) then
  begin
    ClearPhysicsDebugHull;
    Exit;
  end;

  ClearPhysicsDebugHull;
  fPhysicsDebugHullOwner := nil;
  fPhysicsDebugHull := TSceneObject.Create(fRoot);
  fPhysicsDebugHull.Name := 'PhysicsColliderDebug';
  fPhysicsDebugHull.IsGizmo := True;

  for I := 0 to fPhysicsWorld.BodyCount - 1 do
  begin
    Body := fPhysicsWorld.Bodies[I];
    Mesh := fPhysicsWorld.CreateColliderDebugMesh(Body);
    if Mesh = nil then
      Continue;

    fPhysicsDebugHull.MeshList.AddMeshToList(Mesh);
    Mesh.MaterialLibrary := MaterialLibraries.MaterialLibrary[0];
    Mesh.LibMaterialname := 'GizmoColorMaterial';
    Mesh.Tag := PhysicsDebugColorTag(Body);
    Mesh.WireFrame := True;
    Mesh.AlwaysOnTop := False;
    Mesh.OnRender := GizmoMeshRenderHandler;
  end;

  if fPhysicsDebugHull.MeshList.Count = 0 then
  begin
    ClearPhysicsDebugHull;
    Exit;
  end;

  fPhysicsDebugHull.UpdateWorldMatrices;
end;

procedure TMainForm.UpdateGizmoScale;
var
  Dist: Single;
  WorldSizeDesired: Single;
  ScaleFactor: Single;
  ViewportHeight: Integer;
  WorldPos: TVector3;
begin
  if (fCurrentGizmo = nil) or (fSelectedObject = nil) then Exit;

  WorldPos := GetGizmoTargetWorldPosition;
  Dist := (fCamera.Camera.Position - WorldPos).Length;
  if Dist < 0.01 then Dist := 0.01;

  ViewportHeight := fRenderer.Height;
  if ViewportHeight = 0 then Exit;

  WorldSizeDesired := (GIZMO_SCREEN_SIZE_PX * Dist * 2 * Tan(fFOVRadians * 0.5)) / ViewportHeight;

  const GIZMO_REF_SIZE = 0.6;   // reference size of the gizmo when scale = 1
  ScaleFactor := WorldSizeDesired / GIZMO_REF_SIZE;
  if ScaleFactor < 0.000001 then
    ScaleFactor := 0.000001;
  fCurrentGizmo.Scale := Vector3(ScaleFactor, ScaleFactor, ScaleFactor);

  fCurrentGizmo.NotifyChange;
  fCurrentGizmo.UpdateWorldMatrices;

  fSceneManager.Update;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  DisableFloatingPointExceptions;

  TEnginePaths.Initialize(ExtractFilePath(Application.ExeName));
  TEnginePaths.EnsureDirectories;

  fRenderer := TRenderer.Create(pnlRenderingSurface.Handle, 0, 0, pnlRenderingSurface.Width, pnlRenderingSurface.Height, Vector4(0.56, 0.73, 0.92, 1.0), 16);
  fRenderer.SkyDome := TSkyDome.Create;

  // Natural big cumulus
  {fRenderer.SkyDome.CloudCoverage := 0.58;
  fRenderer.SkyDome.CloudScale := 0.24;
  fRenderer.SkyDome.CloudOpacity := 0.78;}

  // More dramatic / rainy, but bigger
  {fRenderer.SkyDome.CloudCoverage := 0.88;
  fRenderer.SkyDome.CloudScale := 0.16;
  fRenderer.SkyDome.CloudOpacity := 0.88;}

  // Sparse fluffy clouds
  fRenderer.SkyDome.CloudCoverage := 0.23;
  fRenderer.SkyDome.CloudScale := 0.30;
  fRenderer.SkyDome.CloudOpacity := 0.70;

  fRenderer.SkyDome.TwinkleStars := False;
  fRenderer.SkyDome.StarSize := Vector2(0.045, 0.125);
  fRenderer.SkyDome.StarGlare := 0.45;
  fRenderer.SkyDome.StarIntensity := 0.95;
  fRenderer.SkyDome.StarDensity := 220.0;

  // Log OpenGL info
  mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Vendor: ' + string(glGetString(GL_VENDOR)));
  mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Renderer: ' + string(glGetString(GL_RENDERER)));
  mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Version: ' + string(glGetString(GL_VERSION)));

  // Load shaders from file
  fShader := TShader.Create(TEnginePaths.Shader('PBR_POM_4.vert'), TEnginePaths.Shader('PBR_POM_4.frag'));
  fHeightFieldShader := TShader.Create(TEnginePaths.Shader('HeightField_MultiMaterial.vert'), TEnginePaths.Shader('HeightField_MultiMaterial.frag'));
  fGizmoShader := TShader.Create(TEnginePaths.Shader('Gizmo.vert'), TEnginePaths.Shader('Gizmo.frag'));
  fRenderer.LoadShadowShaderFromFile(TEnginePaths.Shader('ShadowDepth.vert'), TEnginePaths.Shader('ShadowDepth.frag'));
  fRenderer.LoadEmptyObjectMarkerShaderFromFile(TEnginePaths.Shader('EmptyObjectMarker.vert'), TEnginePaths.Shader('EmptyObjectMarker.frag'));
  fRenderer.LoadWaterShaderFromFile(TEnginePaths.Shader('Water.vert'), TEnginePaths.Shader('Water.frag'));

  MaterialLibraries := TMaterialLibraries.Create();
  EnsureDefaultMaterialLibrary;
  EnsureGizmoMaterial;

  fRenderer.FogEnabled := True;
  fRenderer.FogStart := 60;
  fRenderer.FogEnd := 500;

  // Create Scene Manager
  fSceneManager := fRenderer.SceneManager;
  // Create root
  fRoot := fSceneManager.Root;
  fPhysicsWorld := TPhysicsWorld.Create(fRoot);
  fSceneWorld := TSceneObject.Create(fRoot);
  fSceneWorld.Name := 'Scene';

  fLight := TSceneObject.Create(fRoot);
  fLight.Name := 'Light_1';
  fLight.CreateLight;
  fLight.Position := Vector3(10, 10.0, 10.0);
  fLight.Rotation := Vector3(DegToRad(-45), DegToRad(35), 0);

  fLight.Light[0].LightType := ltDirectional;
  fLight.Light[0].TargetPosition := Vector3(0, 0, 0);
  fLight.Light[0].UseTarget := True;
  fLight.Light[0].CastShadows := True;
  fLight.Light[0].ShadowStrength := 0.90;
  fLight.Light[0].Diffuse := Vector3(3.0, 3.0, 3.0);
  fLight.Light[0].Ambient := Vector3(0.04, 0.04, 0.04);
  fLight.Light[0].Specular := Vector3(1.0, 1.0, 1.0);

  //LoadCustomTextures;
  LoadDefaultTextures;
  fScriptManager := TEngineScriptManager.Create;
  BindScriptManager;

  fCameraUp := Vector3(0, -1, 0);
  fCamera := TSceneObject.Create(fRoot);
  fCamera.Name := 'Camera';
  fCamera.CreateCamera;
  fCamera.Camera.LookAt(Vector3(0, 0, -11), Vector3(0, 0, 0), fCameraUp);
  fRenderer.ActiveCamera := fCamera;

  fOrbitTarget := Vector3(0, 0, 0);
  fRenderer.ShadowLight := fLight;
  fRenderer.ShadowTarget := fOrbitTarget;

  fRenderer.ShadowAutoFit := True;
  fRenderer.ShadowFitPadding := 2.0;

  fRenderer.ShadowDistance := 35.0;
  fRenderer.ShadowArea := 32.0;
  fRenderer.ShadowEnabled := True;

  var dir := fCamera.Camera.Position - fOrbitTarget;
  // Initialise current and target values from the camera position
  fCurrentRadius := dir.Length;
  fTargetRadius := fCurrentRadius;
  fCurrentAzimuth := System.Math.ArcTan2(dir.Z, dir.X);
  fTargetAzimuth := fCurrentAzimuth;
  fCurrentPolar := ArcCos(dir.Y / fCurrentRadius);
  fTargetPolar := fCurrentPolar;

  fRotateSpeed := 0.003;
  fZoomSpeed := 0.90;
  fPanSpeed := 0.0005;

  pnlRenderingSurface.OnMouseDown := pnlRenderingSurfaceMouseDown;
  pnlRenderingSurface.OnMouseMove := pnlRenderingSurfaceMouseMove;
  pnlRenderingSurface.OnMouseUp := pnlRenderingSurfaceMouseUp;
  Self.OnMouseWheel := FormMouseWheel;

  fDraggingGizmo := False;
  fHoveredAxis := -1;
  fLastPickedMeshIndex := -1;

  fGizmoMode := gmTranslate;
  SyncGizmoModeButtons;
  fRotateStartAngleSet := False;

  fFOVRadians := DegToRad(60.0);
  FormResize(Self);

  fShader.OnUpdateShader := OnUpdateShader;
  fHeightFieldShader.OnUpdateShader := OnUpdateShader;

  fGizmoShader.OnUpdateShader := OnUpdateGizmoShader;

  fTransformObject := nil;
  fSuppressTransformChange := False;
  fSelectedMesh := nil;
  fSuppressMeshEditorChange := False;
  fGizmoOwner := nil;
  fPhysicsDebugHull := nil;
  fPhysicsDebugHullOwner := nil;
  fBuiltGizmoMode := fGizmoMode;
  fPhysicsBody := nil;
  fSuppressPhysicsControls := False;
  fCurrentSceneFileName := '';
  SetLength(fSavedSceneSnapshot, 0);
  HookMainEditorEvents;
  ResetTransformControls;
  ResetMeshes;
  ResetPhysicsControls;
  UpdateSceneStatusBar;

  fNewObjectMode := False;

  Timer := TEngineTimer.Create;
  Timer.Enabled := False;
  Timer.OnProgress := DoProgress;
  Timer.Mode := tmASAP;
  Timer.Enabled := True;

  fSimulatePhysics := False;
  fPhysicsRestorePending := False;
  SetPhysicsSimulationMode(False);

  PopulateTreeView;
  RememberSavedSceneSnapshot;
end;

procedure TMainForm.FormResize(Sender: TObject);
begin
  if (pnlRenderingSurface.Width = 0) or (pnlRenderingSurface.Height = 0) then
    Exit;

  if Assigned(fRenderer) then
    begin
      fRenderer.Width := pnlRenderingSurface.Width;
      fRenderer.Height := pnlRenderingSurface.Height;
      fRenderer.InitFOV(fFOVRadians, 0.01, 10000);
      UpdateGizmoScale;
      fRenderer.Render;
    end;
end;

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if not SceneHasUnsavedChanges then
    Exit;

  case MessageDlg('Save changes to the current scene before closing?',
    mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
    mrYes:
      if not SaveCurrentScene(False) then
        Action := caNone;
    mrNo:
      ; // Close without saving.
  else
    Action := caNone;
  end;
end;

procedure TMainForm.mmExitClick(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.mmGUIEditorClick(Sender: TObject);
begin
  GuiEditorSharedRenderer := fRenderer;

  if not Assigned(Form1) then
    Form1 := TForm1.Create(Application);

  if Form1.WindowState = wsMinimized then
    Form1.WindowState := wsNormal;

  Form1.Show;
  Form1.BringToFront;
end;

procedure TMainForm.mmParticleEditorClick(Sender: TObject);
begin
  if not Assigned(frmParticleEditor) then
    frmParticleEditor := TfrmParticleEditor.Create(Application);

  frmParticleEditor.UseSharedRenderer(fRenderer);

  if frmParticleEditor.WindowState = wsMinimized then
    frmParticleEditor.WindowState := wsNormal;

  frmParticleEditor.Show;
  frmParticleEditor.BringToFront;
end;
procedure TMainForm.mmImportMaterialsClick(Sender: TObject);
var
  FileName: string;
  Ext: string;
  Lib: TMaterialLibrary;
  Mat: TMaterial;
  DefaultLib: TMaterialLibrary;
  ImportedLibraries: TMaterialLibraries;
  I: Integer;

  function TryLoadMaterialLibraryList(out ALibraries: TMaterialLibraries): Boolean;
  var
    Stream: TFileStream;
    K: Integer;
  begin
    ALibraries := TMaterialLibraries.Create;
    try
      Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
      try
        ALibraries.LoadFromStream(Stream, fShader);
      finally
        Stream.Free;
      end;

      Result := ALibraries.Count > 0;
      if Result then
        for K := 0 to ALibraries.Count - 1 do
          AssignShadersToMaterialLibrary(ALibraries.MaterialLibrary[K]);
    except
      FreeAndNil(ALibraries);
      Result := False;
    end;

    if not Result then
      FreeAndNil(ALibraries);
  end;
begin
  if fSimulatePhysics then
    Exit;

  ConfigureMaterialDialogs;
  if not OpenMaterialsDialog.Execute then
    Exit;

  FileName := OpenMaterialsDialog.FileName;
  Ext := LowerCase(ExtractFileExt(FileName));

  try
    EnsureGizmoMaterial;

    if Ext = '.omemat' then
    begin
      Mat := TMaterial.LoadFromFile(FileName, fShader);
      AssignShaderToMaterial(Mat);
      try
        if IsEditorOnlyMaterial(Mat) then
        begin
          mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Skipped editor-only material: ' + Mat.Name);
          Exit;
        end;

        DefaultLib := EnsureDefaultMaterialLibrary;
        for I := DefaultLib.Count - 1 downto 0 do
          if Assigned(DefaultLib.Material[I]) and
             (not IsEditorOnlyMaterial(DefaultLib.Material[I])) and
             SameText(DefaultLib.Material[I].Name, Mat.Name) then
            DefaultLib.DeleteMaterial(I);

        AssignShaderToMaterial(Mat);
        DefaultLib.AddMaterial(Mat);
        Mat := nil;
        EnsureGizmoMaterial;
        mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Material loaded: ' + FileName);
      finally
        Mat.Free;
      end;
    end
    else if TryLoadMaterialLibraryList(ImportedLibraries) then
    begin
      try
        ReplaceUserMaterialLibraries(ImportedLibraries);
        mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Material library list loaded: ' + FileName);
      finally
        ImportedLibraries.Free;
      end;
    end
    else
    begin
      Lib := TMaterialLibrary.Create;
      try
        Lib.LoadFromFile(FileName, fShader);
        AssignShadersToMaterialLibrary(Lib);
        ReplaceDefaultUserMaterialsFromLibrary(Lib);
        mLog.Lines.Add(FormatDateTime('[yyyy-mm-dd hh:nn:ss] ', Now) + 'Material library loaded: ' + FileName);
      finally
        Lib.Free;
      end;
    end;

    AttachRuntimeSceneData(fRoot);
    UpdateUI;
    RefreshGizmo;
    if Assigned(fRenderer) then
      fRenderer.Render;
  except
    on E: Exception do
      ShowMessage('Could not load materials: ' + E.Message);
  end;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  if Assigned(Timer) then
  begin
    Timer.Enabled := False;
    Timer.OnProgress := nil;
    FreeAndNil(Timer);
  end;

  ClearPhysicsDebugHull;
  FreeAndNil(fScriptManager);
  FreeAndNil(fPhysicsWorld);

  FreeAndNil(fShader);
  FreeAndNil(fHeightFieldShader);
  FreeAndNil(fGizmoShader);
  FreeAndNil(MaterialLibraries);

  FreeAndNil(fRenderer);
end;

// MODIFIED: Removed zoom limits, only a tiny lower bound to avoid flip
procedure TMainForm.FormMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
var
  pt: TPoint;
  ZoomSteps: Single;
begin
  // Convert screen coordinates of MousePos to client coordinates of pnlRenderingSurface
  pt := pnlRenderingSurface.ScreenToClient(MousePos);
  // Check if the mouse is inside pnlRenderingSurface's client area
  if (pt.X >= 0) and (pt.Y >= 0) and (pt.X <= pnlRenderingSurface.Width) and (pt.Y <= pnlRenderingSurface.Height) then
  begin
    ZoomSteps := WheelDelta / WHEEL_DELTA;
    if ZoomSteps <> 0 then
      fTargetRadius := fTargetRadius * System.Math.Power(fZoomSpeed, ZoomSteps);

    // Remove upper limit, only protect against extremely small radii (prevent camera flip)
    if fTargetRadius < 0.001 then
      fTargetRadius := 0.001;

    Handled := True;  // Prevent the wheel event from being passed further
  end;
end;

procedure TMainForm.Timer1Timer(Sender: TObject);
begin
  mLog.Lines.SaveToFile(PATH + 'Log.txt');
end;

end.













