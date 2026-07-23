unit Renderer.Mesh;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, System.Generics.Collections, Vcl.Graphics,
  Vcl.Imaging.pngimage, Vcl.Imaging.jpeg,
  dglOpenGL, Vcl.ExtCtrls, Vcl.StdCtrls,
  System.Math, Renderer.Shader, Neslib.FastMath, Engine.Types, Managers.Material,
  Engine.Generators, Utility.Functions, Loader.OBJ, Loader.GLTF;

const
  HEIGHTFIELD_MAX_LOD_LEVELS = 8;
  HEIGHTFIELD_EDGE_TOP = 0;
  HEIGHTFIELD_EDGE_BOTTOM = 1;
  HEIGHTFIELD_EDGE_LEFT = 2;
  HEIGHTFIELD_EDGE_RIGHT = 3;

type
  TMesh = class;
  TOnMeshRender = procedure(Mesh: TMesh; Shader: TShader) of object;

  THeightFieldTileLOD = record
    EBO: GLuint;
    MorphVBO: GLuint;
    IndexCount: Integer;
    Step: Integer;
    SkirtEBOs: array[0..3] of GLuint;
    SkirtIndexCounts: array[0..3] of Integer;
  end;

  THeightFieldTile = record
    VAO: GLuint;
    VBO: GLuint;
    LODs: array[0..HEIGHTFIELD_MAX_LOD_LEVELS - 1] of THeightFieldTileLOD;
    LODCount: Integer;
    CurrentLOD: Integer;
    CurrentMorph: Single;
    TileX: Integer;
    TileZ: Integer;
    TopSkirtOffset: Integer;
    BottomSkirtOffset: Integer;
    LeftSkirtOffset: Integer;
    RightSkirtOffset: Integer;
    Bounds: TAABB;
  end;

  TMesh = class
  protected
    fVAO: GLuint;
    fVBO: GLuint;
    fEBO: GLuint;
    fVertexBufferSize: NativeInt;
    // true if EBO present
    fUseElements: Boolean;
    // Parent scene matrix * mesh-local transform. TMesh is owned by TSceneObject.
    fModelMatrix: TMatrix4;
    fParentModelMatrix: TMatrix4;
    fLocalMatrix: TMatrix4;
    fPosition: TVector3;
    fRotation: TVector3;
    fScale: TVector3;

    // Dynamic storage for mesh data
    fVertices: TArray<TVertex>;
    fIndices: TArray<GLuint>;

    fVertexAttributes: TArray<TVertexAttribute>;
    fStaticGeometry: Boolean;

    fMeshType: TMeshType;

    fMaterialLibrary: TMaterialLibrary;
    fLibMaterialLibraryName: String;
    fLibMaterialname: String;

    fName: String;
    fVisible: Boolean;
    fAlwaysOnTop: Boolean;
    fTag: Integer;

    fWireFrame: Boolean;

    fOnRender: TOnMeshRender;

    fBoundingBoxMin: TVector3;
    fBoundingBoxMax: TVector3;

    procedure ComputeBoundingBox;

    function GetVertexCount: Integer;
    function GetIndexCount: Integer;

    function GetVerticesCount: Integer;
    procedure RebuildModelMatrix;
    procedure SetModelMatrix(const Value: TMatrix4);
    procedure SetParentModelMatrix(const Value: TMatrix4);
    procedure SetPosition(const Value: TVector3);
    procedure SetRotation(const Value: TVector3);
    procedure SetScale(const Value: TVector3);
    procedure SetMaterialLibrary(const Value: TMaterialLibrary);

    // Creates GPU buffers and uploads current data
    procedure CreateBuffers;
    procedure SetGeometry(const Vertices: TArray<TVertex>; const Indices: TArray<GLuint>;
      BuildTangentsAndBitangents: Boolean = False);
    procedure CopyRenderStateTo(ADest: TMesh); virtual;
    procedure SaveShapeData(Stream: TStream); virtual;
  public
    constructor Create(const Vertices: TArray<TVertex>; const Indices: TArray<GLuint>; aName: String; aMeshType: TMeshType; IsStatic: Boolean = True); overload;
    destructor Destroy; override;

    // Clone: creates an exact copy of the mesh (geometry, material link,
    // model matrix) but not the OnRender event. GPU buffers are recreated.
    function Clone: TMesh; virtual;

    property AlwaysOnTop: Boolean read fAlwaysOnTop write fAlwaysOnTop;
    property Tag: Integer read fTag write fTag;

    property BoundingBoxMin: TVector3 read fBoundingBoxMin;
    property BoundingBoxMax: TVector3 read fBoundingBoxMax;
    function GetBoundingBox: TAABB;
    procedure RecomputeBoundingBox;

    function GetPointAtPreset(Preset: TMeshCenterPreset): TVector3;
    function GetWorldPointAtPreset(Preset: TMeshCenterPreset): TVector3;

    // Moves the mesh geometry so that the specified preset point (in mesh-local
    // space) becomes located at TargetPos (also mesh-local/object-local space).
    // Uses ApplyTransform, so it bakes the move into vertices and refreshes AABB.
    procedure SetPositionByPreset(Preset: TMeshCenterPreset; const TargetPos: TVector3);
    // Determines which preset matches the given local point.
    // Returns cpCenter if the point is not one of the 25 presets.
    function GetPresetAtPoint(const Point: TVector3): TMeshCenterPreset;

    // Access to raw data (read-only)
    property Vertices: TArray<TVertex> read fVertices;
    property VerticesCount: Integer read GetVerticesCount;
    property Indices: TArray<GLuint> read fIndices;
    property VertexCount: Integer read GetVertexCount;
    property IndexCount: Integer read GetIndexCount;

    procedure BuildTangentsAndBitangents;
    // Call this after modifying fVertices or fIndices to update GPU data
    procedure RefreshVertexBuffer;
    procedure RefreshBuffers;

    procedure SetUVs(const NewUVs: TArray<TVector2>);
    procedure ScaleUVs(ScaleU, ScaleV: Single);
    procedure SetTransform(const APosition, ARotation, AScale: TVector3);
    function ApplyMatrix(const Matrix: TMatrix4): Boolean;
    function ApplyTransform(const Translation: TVector3; const RotationRad: TVector3; const Scale: TVector3): Boolean; overload;
    function ApplyTransform(const Translation: TVector3; const Rotation: TQuaternion; const Scale: TVector3): Boolean; overload;

    class function LoadFromFile(const AFileName: string): TMesh;
    procedure SaveToStream(Stream: TStream);
    class function LoadFromStream(Stream: TStream; MeshListVersion: Integer = 1): TMesh;

    property OnRender: TOnMeshRender read fOnRender write fOnRender;
    procedure PrepareShader(AShader: TShader); virtual;
    procedure Draw(); virtual;
    procedure DrawCulled(const AFrustumPlanes: TFrustumPlanes;
      AUseFrustum: Boolean); virtual;
    procedure DrawGeometryOnly;
    procedure DrawGeometryOnlyCulled(const AFrustumPlanes: TFrustumPlanes;
      AUseFrustum: Boolean); virtual;

    property MaterialLibrary: TMaterialLibrary read fMaterialLibrary write SetMaterialLibrary;
    property MaterialLibraryName: String read fLibMaterialLibraryName write fLibMaterialLibraryName;
    property LibMaterialname: String read fLibMaterialname write fLibMaterialname;

    property Name: String read fName write fName;
    property IsStatic: Boolean read fStaticGeometry;

    property Position: TVector3 read fPosition write SetPosition;
    property Rotation: TVector3 read fRotation write SetRotation;
    property Scale: TVector3 read fScale write SetScale;
    property LocalMatrix: TMatrix4 read fLocalMatrix;
    property ParentModelMatrix: TMatrix4 read fParentModelMatrix write SetParentModelMatrix;
    property ModelMatrix: TMatrix4 read fModelMatrix write SetModelMatrix;

    property Visible: Boolean read fVisible write fVisible;
    property WireFrame: Boolean read fWireFrame write fWireFrame;
    property MeshType: TMeshType read fMeshType;
  end;

  TFileMesh = class(TMesh)
  private
    fSourceFile: string;
    procedure SetSourceFile(const Value: string);
  protected
    procedure SaveShapeData(Stream: TStream); override;
  public
    constructor Create(const Vertices: TArray<TVertex>; const Indices: TArray<GLuint>;
      const aName, ASourceFile: string; IsStatic: Boolean = True);
    function Clone: TMesh; override;
    property SourceFile: string read fSourceFile write SetSourceFile;
  end;

  TPlaneMesh = class(TMesh)
  private
    fWidth, fDepth: Single;
    fWidthSegments, fDepthSegments: Integer;
    procedure SetWidth(const Value: Single);
    procedure SetDepth(const Value: Single);
    procedure SetWidthSegments(const Value: Integer);
    procedure SetDepthSegments(const Value: Integer);
  protected
    procedure SaveShapeData(Stream: TStream); override;
  public
    constructor Create(Width, Depth: Single; WidthSegments, DepthSegments: Integer;
      const aName: string; IsStatic: Boolean = True);
    function Clone: TMesh; override;
    procedure RebuildGeometry;
    property Width: Single read fWidth write SetWidth;
    property Depth: Single read fDepth write SetDepth;
    property WidthSegments: Integer read fWidthSegments write SetWidthSegments;
    property DepthSegments: Integer read fDepthSegments write SetDepthSegments;
  end;

  TWaterPlaneMesh = class(TPlaneMesh)
  private
    fTintColor: TVector4;
    fDeepColor: TVector4;
    fReflectionStrength: Single;
    fWaveScale: Single;
    fWaveSpeed: Single;
    fWaveStrength: Single;
    fFresnelPower: Single;
    fAlpha: Single;
  protected
    procedure SaveShapeData(Stream: TStream); override;
  public
    constructor Create(Width, Depth: Single; WidthSegments, DepthSegments: Integer;
      const aName: string; IsStatic: Boolean = True);
    function Clone: TMesh; override;
    property TintColor: TVector4 read fTintColor write fTintColor;
    property DeepColor: TVector4 read fDeepColor write fDeepColor;
    property ReflectionStrength: Single read fReflectionStrength write fReflectionStrength;
    property WaveScale: Single read fWaveScale write fWaveScale;
    property WaveSpeed: Single read fWaveSpeed write fWaveSpeed;
    property WaveStrength: Single read fWaveStrength write fWaveStrength;
    property FresnelPower: Single read fFresnelPower write fFresnelPower;
    property Alpha: Single read fAlpha write fAlpha;
  end;

  THeightFieldMesh = class(TMesh)
  private
    fWidth, fDepth: Single;
    fHeightScale, fUVScale: Single;
    fHeightMapWidth, fHeightMapDepth: Integer;
    fHeights: TArray<Single>;
    fSourceFile: string;
    fTileSize: Integer;
    fLODEnabled: Boolean;
    fLODCount: Integer;
    fLODDistance: Single;
    fLODCameraPosition: TVector3;
    fTileColumns: Integer;
    fTileRows: Integer;
    fTiles: TArray<THeightFieldTile>;
    function GetHeights: TArray<Single>;
    procedure AssignHeights(const Values: TArray<Single>; HeightMapWidth,
      HeightMapDepth: Integer; Rebuild: Boolean);
    procedure ClearTiles;
    procedure BuildTiles;
    function SelectTileLOD(var Tile: THeightFieldTile): Integer;
    procedure SetTileSize(const Value: Integer);
    procedure SetLODEnabled(const Value: Boolean);
    procedure SetLODCount(const Value: Integer);
    procedure SetLODDistance(const Value: Single);
    procedure SetWidth(const Value: Single);
    procedure SetDepth(const Value: Single);
    procedure SetHeightScale(const Value: Single);
    procedure SetUVScale(const Value: Single);
    procedure SetSourceFile(const Value: string);
  protected
    procedure SaveShapeData(Stream: TStream); override;
  public
    destructor Destroy; override;
    constructor Create(const Heights: TArray<Single>; HeightMapWidth,
      HeightMapDepth: Integer; Width, Depth, HeightScale, UVScale: Single;
      const aName: string; IsStatic: Boolean = True);
    class function FromBitmap(const AFileName: string; Width, Depth,
      HeightScale: Single; UVScale: Single = 1.0; const aName: string = '';
      IsStatic: Boolean = True): THeightFieldMesh; static;
    function Clone: TMesh; override;
    procedure RebuildGeometry;
    procedure SetHeights(const Values: TArray<Single>; HeightMapWidth,
      HeightMapDepth: Integer);
    function HeightAtSample(X, Z: Integer): Single;
    function InterpolatedHeight(LocalX, LocalZ: Single): Single;
    function NormalAtSample(X, Z: Integer): TVector3;
    procedure Draw; override;
    procedure DrawCulled(const AFrustumPlanes: TFrustumPlanes;
      AUseFrustum: Boolean); override;
    procedure DrawGeometryOnlyCulled(const AFrustumPlanes: TFrustumPlanes;
      AUseFrustum: Boolean); override;
    procedure UpsampleHeights(Factor: Integer);
    property Width: Single read fWidth write SetWidth;
    property Depth: Single read fDepth write SetDepth;
    property HeightScale: Single read fHeightScale write SetHeightScale;
    property UVScale: Single read fUVScale write SetUVScale;
    property TileSize: Integer read fTileSize write SetTileSize;
    property LODEnabled: Boolean read fLODEnabled write SetLODEnabled;
    property LODCount: Integer read fLODCount write SetLODCount;
    property LODDistance: Single read fLODDistance write SetLODDistance;
    property LODCameraPosition: TVector3 read fLODCameraPosition write fLODCameraPosition;
    property HeightMapWidth: Integer read fHeightMapWidth;
    property HeightMapDepth: Integer read fHeightMapDepth;
    property Heights: TArray<Single> read GetHeights;
    property SourceFile: string read fSourceFile write SetSourceFile;
  end;

  TCubeMesh = class(TMesh)
  private
    fWidth, fHeight, fDepth: Single;
    fWidthStacks, fHeightStacks, fDepthStacks: Integer;
    procedure SetWidth(const Value: Single);
    procedure SetHeight(const Value: Single);
    procedure SetDepth(const Value: Single);
    procedure SetWidthStacks(const Value: Integer);
    procedure SetHeightStacks(const Value: Integer);
    procedure SetDepthStacks(const Value: Integer);
  protected
    procedure SaveShapeData(Stream: TStream); override;
  public
    constructor Create(Width, Height, Depth: Single; WidthStacks, HeightStacks,
      DepthStacks: Integer; const aName: string; IsStatic: Boolean = True);
    function Clone: TMesh; override;
    procedure RebuildGeometry;
    property Width: Single read fWidth write SetWidth;
    property Height: Single read fHeight write SetHeight;
    property Depth: Single read fDepth write SetDepth;
    property WidthStacks: Integer read fWidthStacks write SetWidthStacks;
    property HeightStacks: Integer read fHeightStacks write SetHeightStacks;
    property DepthStacks: Integer read fDepthStacks write SetDepthStacks;
  end;

  TSphereMesh = class(TMesh)
  private
    fRadius: Single;
    fStackCount, fSliceCount: Integer;
    procedure SetRadius(const Value: Single);
    procedure SetStackCount(const Value: Integer);
    procedure SetSliceCount(const Value: Integer);
  protected
    procedure SaveShapeData(Stream: TStream); override;
  public
    constructor Create(Radius: Single; StackCount, SliceCount: Integer;
      const aName: string; IsStatic: Boolean = True);
    function Clone: TMesh; override;
    procedure RebuildGeometry;
    property Radius: Single read fRadius write SetRadius;
    property StackCount: Integer read fStackCount write SetStackCount;
    property SliceCount: Integer read fSliceCount write SetSliceCount;
  end;

  TCylinderMesh = class(TMesh)
  private
    fRadius, fHeight: Single;
    fSlices, fStacks: Integer;
    fBottomCap, fTopCap: TCapType;
    procedure SetRadius(const Value: Single);
    procedure SetHeight(const Value: Single);
    procedure SetSlices(const Value: Integer);
    procedure SetStacks(const Value: Integer);
    procedure SetBottomCap(const Value: TCapType);
    procedure SetTopCap(const Value: TCapType);
  protected
    procedure SaveShapeData(Stream: TStream); override;
  public
    constructor Create(Radius, Height: Single; Slices, Stacks: Integer;
      const aName: string; BottomCap: TCapType = ctFlat; TopCap: TCapType = ctFlat;
      IsStatic: Boolean = True);
    function Clone: TMesh; override;
    procedure RebuildGeometry;
    property Radius: Single read fRadius write SetRadius;
    property Height: Single read fHeight write SetHeight;
    property Slices: Integer read fSlices write SetSlices;
    property Stacks: Integer read fStacks write SetStacks;
    property BottomCap: TCapType read fBottomCap write SetBottomCap;
    property TopCap: TCapType read fTopCap write SetTopCap;
  end;

  TCapsuleMesh = class(TMesh)
  private
    fRadius, fHeight: Single;
    fSlices, fStacks: Integer;
    procedure SetRadius(const Value: Single);
    procedure SetHeight(const Value: Single);
    procedure SetSlices(const Value: Integer);
    procedure SetStacks(const Value: Integer);
  protected
    procedure SaveShapeData(Stream: TStream); override;
  public
    constructor Create(Radius, Height: Single; Slices, Stacks: Integer;
      const aName: string; IsStatic: Boolean = True);
    function Clone: TMesh; override;
    procedure RebuildGeometry;
    property Radius: Single read fRadius write SetRadius;
    property Height: Single read fHeight write SetHeight;
    property Slices: Integer read fSlices write SetSlices;
    property Stacks: Integer read fStacks write SetStacks;
  end;

  TTorusMesh = class(TMesh)
  private
    fMajorRadius, fMinorRadius: Single;
    fMajorSegments, fMinorSegments: Integer;
    procedure SetMajorRadius(const Value: Single);
    procedure SetMinorRadius(const Value: Single);
    procedure SetMajorSegments(const Value: Integer);
    procedure SetMinorSegments(const Value: Integer);
  protected
    procedure SaveShapeData(Stream: TStream); override;
  public
    constructor Create(MajorRadius, MinorRadius: Single; MajorSegments,
      MinorSegments: Integer; const aName: string; IsStatic: Boolean = True);
    function Clone: TMesh; override;
    procedure RebuildGeometry;
    property MajorRadius: Single read fMajorRadius write SetMajorRadius;
    property MinorRadius: Single read fMinorRadius write SetMinorRadius;
    property MajorSegments: Integer read fMajorSegments write SetMajorSegments;
    property MinorSegments: Integer read fMinorSegments write SetMinorSegments;
  end;

  TConeMesh = class(TMesh)
  private
    fRadius, fHeight: Single;
    fSides, fStacks: Integer;
    fBottomCap: TCapType;
    procedure SetRadius(const Value: Single);
    procedure SetHeight(const Value: Single);
    procedure SetSides(const Value: Integer);
    procedure SetStacks(const Value: Integer);
    procedure SetBottomCap(const Value: TCapType);
  protected
    procedure SaveShapeData(Stream: TStream); override;
  public
    constructor Create(Radius, Height: Single; Sides, Stacks: Integer;
      const aName: string; BottomCap: TCapType = ctFlat; IsStatic: Boolean = True);
    function Clone: TMesh; override;
    procedure RebuildGeometry;
    property Radius: Single read fRadius write SetRadius;
    property Height: Single read fHeight write SetHeight;
    property Sides: Integer read fSides write SetSides;
    property Stacks: Integer read fStacks write SetStacks;
    property BottomCap: TCapType read fBottomCap write SetBottomCap;
  end;

  TPrismMesh = class(TMesh)
  private
    fRadius, fHeight: Single;
    fSides, fStacks: Integer;
    procedure SetRadius(const Value: Single);
    procedure SetHeight(const Value: Single);
    procedure SetSides(const Value: Integer);
    procedure SetStacks(const Value: Integer);
  protected
    procedure SaveShapeData(Stream: TStream); override;
  public
    constructor Create(Radius, Height: Single; Sides, Stacks: Integer;
      const aName: string; IsStatic: Boolean = True);
    function Clone: TMesh; override;
    procedure RebuildGeometry;
    property Radius: Single read fRadius write SetRadius;
    property Height: Single read fHeight write SetHeight;
    property Sides: Integer read fSides write SetSides;
    property Stacks: Integer read fStacks write SetStacks;
  end;

  TFrustumMesh = class(TMesh)
  private
    fBottomRadius, fTopRadius, fHeight: Single;
    fSlices, fStacks: Integer;
    fBottomCap, fTopCap: TCapType;
    procedure SetBottomRadius(const Value: Single);
    procedure SetTopRadius(const Value: Single);
    procedure SetHeight(const Value: Single);
    procedure SetSlices(const Value: Integer);
    procedure SetStacks(const Value: Integer);
    procedure SetBottomCap(const Value: TCapType);
    procedure SetTopCap(const Value: TCapType);
  protected
    procedure SaveShapeData(Stream: TStream); override;
  public
    constructor Create(BottomRadius, TopRadius, Height: Single; Slices, Stacks: Integer;
      BottomCap, TopCap: TCapType; const aName: string; IsStatic: Boolean = True);
    function Clone: TMesh; override;
    procedure RebuildGeometry;
    property BottomRadius: Single read fBottomRadius write SetBottomRadius;
    property TopRadius: Single read fTopRadius write SetTopRadius;
    property Height: Single read fHeight write SetHeight;
    property Slices: Integer read fSlices write SetSlices;
    property Stacks: Integer read fStacks write SetStacks;
    property BottomCap: TCapType read fBottomCap write SetBottomCap;
    property TopCap: TCapType read fTopCap write SetTopCap;
  end;

  TIcosphereMesh = class(TMesh)
  protected
    fRadius: Single;
    fSubdivisions: Integer;
    procedure SetRadius(const Value: Single);
    procedure SetSubdivisions(const Value: Integer);
  protected
    procedure SaveShapeData(Stream: TStream); override;
  public
    constructor Create(Radius: Single; Subdivisions: Integer; const aName: string;
      IsStatic: Boolean = True);
    function Clone: TMesh; override;
    procedure RebuildGeometry;
    property Radius: Single read fRadius write SetRadius;
    property Subdivisions: Integer read fSubdivisions write SetSubdivisions;
  end;

  TGeodesicDomeMesh = class(TMesh)
  private
    fRadius: Single;
    fSubdivisions: Integer;
    procedure SetRadius(const Value: Single);
    procedure SetSubdivisions(const Value: Integer);
  protected
    procedure SaveShapeData(Stream: TStream); override;
  public
    constructor Create(Radius: Single; Subdivisions: Integer; const aName: string;
      IsStatic: Boolean = True);
    function Clone: TMesh; override;
    procedure RebuildGeometry;
    property Radius: Single read fRadius write SetRadius;
    property Subdivisions: Integer read fSubdivisions write SetSubdivisions;
  end;

  TArrowMesh = class(TMesh)
  protected
    fShaftLength, fTipLength, fShaftRadius, fTipRadius: Single;
    fSlices, fStacks: Integer;
    procedure SetShaftLength(const Value: Single);
    procedure SetTipLength(const Value: Single);
    procedure SetShaftRadius(const Value: Single);
    procedure SetTipRadius(const Value: Single);
    procedure SetSlices(const Value: Integer);
    procedure SetStacks(const Value: Integer);
  protected
    procedure SaveShapeData(Stream: TStream); override;
  public
    constructor Create(ShaftLength, TipLength, ShaftRadius, TipRadius: Single;
      Slices, Stacks: Integer; const aName: string; IsStatic: Boolean = True);
    function Clone: TMesh; override;
    procedure RebuildGeometry; virtual;
    property ShaftLength: Single read fShaftLength write SetShaftLength;
    property TipLength: Single read fTipLength write SetTipLength;
    property ShaftRadius: Single read fShaftRadius write SetShaftRadius;
    property TipRadius: Single read fTipRadius write SetTipRadius;
    property Slices: Integer read fSlices write SetSlices;
    property Stacks: Integer read fStacks write SetStacks;
  end;

  TGizmoMesh = class(TArrowMesh)
  protected
    procedure SaveShapeData(Stream: TStream); override;
  public
    constructor Create(ArrowLength, ShaftRadius, TipRadius, TipLength: Single;
      Slices, Stacks: Integer; const aName: string; IsStatic: Boolean = True);
    function Clone: TMesh; override;
    procedure RebuildGeometry; override;
  end;

  TSuperEllipsoidMesh = class(TMesh)
  private
    fRadius, fVCurve, fHCurve: Single;
    fSlices, fStacks: Integer;
    procedure SetRadius(const Value: Single);
    procedure SetVCurve(const Value: Single);
    procedure SetHCurve(const Value: Single);
    procedure SetSlices(const Value: Integer);
    procedure SetStacks(const Value: Integer);
  protected
    procedure SaveShapeData(Stream: TStream); override;
  public
    constructor Create(Radius, VCurve, HCurve: Single; Slices, Stacks: Integer;
      const aName: string; IsStatic: Boolean = True);
    function Clone: TMesh; override;
    procedure RebuildGeometry;
    property Radius: Single read fRadius write SetRadius;
    property VCurve: Single read fVCurve write SetVCurve;
    property HCurve: Single read fHCurve write SetHCurve;
    property Slices: Integer read fSlices write SetSlices;
    property Stacks: Integer read fStacks write SetStacks;
  end;

  procedure ApplyMaterial(const Materials: Tarray<TMaterialTexture>; Shader: TShader);

implementation

uses
  Renderer.RenderTechnique;

const
  MESH_SHAPE_DATA_VERSION = 1;
  WATER_PLANE_MIN_SEGMENTS = 64;
  MAX_SERIALIZED_STRING_CHARS = 1048576;
  MAX_SERIALIZED_HEIGHT_SAMPLES = 16777216;
  MAX_SERIALIZED_VERTICES = 16777216;
  MAX_SERIALIZED_INDICES = 50331648;

function AABBVisibleInFrustum(const Bounds: TAABB; const ModelMatrix: TMatrix4;
  const FrustumPlanes: TFrustumPlanes; UseFrustum: Boolean): Boolean;
var
  WorldBounds: TAABB;
  Center: TVector3;
  Extents: TVector3;
  Plane: TVector4;
  Distance: Single;
  Radius: Single;
  PlaneIndex: Integer;
begin
  if (not UseFrustum) or (not Bounds.IsValid) then
    Exit(True);

  WorldBounds := Bounds.Transform(ModelMatrix);
  if not WorldBounds.IsValid then
    Exit(True);

  Center := WorldBounds.Center;
  Extents := WorldBounds.Extents;

  for PlaneIndex := Low(FrustumPlanes) to High(FrustumPlanes) do
  begin
    Plane := FrustumPlanes[PlaneIndex];
    Distance := Plane.X * Center.X + Plane.Y * Center.Y +
      Plane.Z * Center.Z + Plane.W;
    Radius := Abs(Plane.X) * Extents.X + Abs(Plane.Y) * Extents.Y +
      Abs(Plane.Z) * Extents.Z;

    if Distance < -Radius then
      Exit(False);
  end;

  Result := True;
end;

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
    raise Exception.Create('Invalid string length in mesh stream.');
  ByteCount := Int64(Len) * SizeOf(Char);
  if ByteCount > Stream.Size - Stream.Position then
    raise Exception.Create('Truncated string in mesh stream.');
  SetLength(Result, Len);
  if Len > 0 then
    Stream.ReadBuffer(Result[1], ByteCount);
end;
{ TMesh }
constructor TMesh.Create(const Vertices: TArray<TVertex>; const Indices: TArray<GLuint>; aName: String; aMeshType: TMeshType; IsStatic: Boolean = True);
begin
  fName := aName;
  fMeshType := aMeshType;
  fStaticGeometry := IsStatic;

  fWireFrame := False;
  fMaterialLibrary := nil;
  fLibMaterialLibraryName := '';
  fLibMaterialname := '';

  fAlwaysOnTop := False;
  fVisible := True;
  fTag := 0;
  fPosition := Vector3(0, 0, 0);
  fRotation := Vector3(0, 0, 0);
  fScale := Vector3(1, 1, 1);
  fParentModelMatrix := TMatrix4.Identity;
  fLocalMatrix := TMatrix4.Identity;
  fModelMatrix := TMatrix4.Identity;

  SetGeometry(Vertices, Indices, False);
end;

destructor TMesh.Destroy;
begin
  if fVAO <> 0 then glDeleteVertexArrays(1, @fVAO);
  if fVBO <> 0 then glDeleteBuffers(1, @fVBO);
  if fEBO <> 0 then glDeleteBuffers(1, @fEBO);

  inherited;
end;

procedure TMesh.RebuildModelMatrix;
var
  MScale: TMatrix4;
  MRotX: TMatrix4;
  MRotY: TMatrix4;
  MRotZ: TMatrix4;
  MTrans: TMatrix4;
begin
  MScale.InitScaling(fScale);
  MRotX.InitRotationX(fRotation.X);
  MRotY.InitRotationY(fRotation.Y);
  MRotZ.InitRotationZ(fRotation.Z);
  MTrans.InitTranslation(fPosition);

  fLocalMatrix := MTrans * MRotZ * MRotY * MRotX * MScale;
  fModelMatrix := fParentModelMatrix * fLocalMatrix;
end;

procedure TMesh.SetModelMatrix(const Value: TMatrix4);
begin
  SetParentModelMatrix(Value);
end;

procedure TMesh.SetParentModelMatrix(const Value: TMatrix4);
begin
  fParentModelMatrix := Value;
  RebuildModelMatrix;
end;

procedure TMesh.SetPosition(const Value: TVector3);
begin
  fPosition := Value;
  RebuildModelMatrix;
end;

procedure TMesh.SetRotation(const Value: TVector3);
begin
  fRotation := Value;
  RebuildModelMatrix;
end;

procedure TMesh.SetScale(const Value: TVector3);
begin
  fScale := Value;
  RebuildModelMatrix;
end;

procedure TMesh.SetMaterialLibrary(const Value: TMaterialLibrary);
begin
  fMaterialLibrary := Value;
  if Value <> nil then
    fLibMaterialLibraryName := Value.Name;
end;

procedure TMesh.SetTransform(const APosition, ARotation, AScale: TVector3);
begin
  fPosition := APosition;
  fRotation := ARotation;
  fScale := AScale;
  RebuildModelMatrix;
end;

// ---------------------------------------------------------------------------
// TMesh.Clone
// ---------------------------------------------------------------------------
function TMesh.Clone: TMesh;
begin
  // Create a new mesh with the same vertex/index data
  Result := TMesh.Create(fVertices, fIndices, fName + '_Clone', fMeshType);
  CopyRenderStateTo(Result);
end;

procedure TMesh.CopyRenderStateTo(ADest: TMesh);
begin
  if ADest = nil then
    Exit;

  // Clone must preserve baked mesh edits too: UV scaling, origin changes, and
  // editor-applied vertex transforms are stored in the vertex/index arrays.
  ADest.SetGeometry(fVertices, fIndices, False);

  ADest.fMaterialLibrary := fMaterialLibrary;
  ADest.fLibMaterialLibraryName := fLibMaterialLibraryName;
  ADest.fLibMaterialname := fLibMaterialname;
  ADest.fPosition := fPosition;
  ADest.fRotation := fRotation;
  ADest.fScale := fScale;
  ADest.fParentModelMatrix := fParentModelMatrix;
  ADest.RebuildModelMatrix;
  ADest.fBoundingBoxMin := fBoundingBoxMin;
  ADest.fBoundingBoxMax := fBoundingBoxMax;
  ADest.fVisible := fVisible;
  ADest.fAlwaysOnTop := fAlwaysOnTop;
  ADest.fTag := fTag;
  ADest.fWireFrame := fWireFrame;
  ADest.fOnRender := fOnRender;
end;

procedure TMesh.SaveShapeData(Stream: TStream);
begin
  // Baked/custom meshes do not have parametric shape data.
end;

function TMesh.GetBoundingBox: TAABB;
begin
  Result.Min := fBoundingBoxMin;
  Result.Max := fBoundingBoxMax;
end;

procedure TMesh.RecomputeBoundingBox;
begin
  ComputeBoundingBox;
end;

function TMesh.GetPointAtPreset(Preset: TMeshCenterPreset): TVector3;
var
  Min, Max, Mid: TVector3;
begin
  Min := fBoundingBoxMin;
  Max := fBoundingBoxMax;
  Mid := (Min + Max) * 0.5;

  case Preset of
    cpCenter:
      Result := Mid;

    // X-axis variations (Left/Right) with Y = Top/Bottom, Z = Middle
    cpLeftTopMiddle:    Result := Vector3(Min.X, Max.Y, Mid.Z);
    cpLeftMiddleMiddle: Result := Vector3(Min.X, Mid.Y, Mid.Z);
    cpLeftBottomMiddle: Result := Vector3(Min.X, Min.Y, Mid.Z);
    cpRightTopMiddle:   Result := Vector3(Max.X, Max.Y, Mid.Z);
    cpRightMiddleMiddle:Result := Vector3(Max.X, Mid.Y, Mid.Z);
    cpRightBottomMiddle:Result := Vector3(Max.X, Min.Y, Mid.Z);

    // Z-axis variations (Front/Back) with Y = Top/Bottom, X = Middle
    cpFrontTopMiddle:    Result := Vector3(Mid.X, Max.Y, Min.Z);
    cpFrontMiddleLeft:   Result := Vector3(Min.X, Mid.Y, Min.Z);
    cpFrontMiddleMiddle: Result := Vector3(Mid.X, Mid.Y, Min.Z);
    cpFrontMiddleRight:  Result := Vector3(Max.X, Mid.Y, Min.Z);
    cpFrontBottomMiddle: Result := Vector3(Mid.X, Min.Y, Min.Z);
    cpBackTopMiddle:     Result := Vector3(Mid.X, Max.Y, Max.Z);
    cpBackMiddleLeft:    Result := Vector3(Min.X, Mid.Y, Max.Z);
    cpBackMiddleMiddle:  Result := Vector3(Mid.X, Mid.Y, Max.Z);
    cpBackMiddleRight:   Result := Vector3(Max.X, Mid.Y, Max.Z);
    cpBackBottomMiddle:  Result := Vector3(Mid.X, Min.Y, Max.Z);

    // Top/Bottom face centers, if the enum contains them.
    cpTopMiddleMiddle:    Result := Vector3(Mid.X, Max.Y, Mid.Z);
    cpBottomMiddleMiddle: Result := Vector3(Mid.X, Min.Y, Mid.Z);

    // Corners (all axes)
    cpFrontTopLeft:     Result := Vector3(Min.X, Max.Y, Min.Z);
    cpFrontTopRight:    Result := Vector3(Max.X, Max.Y, Min.Z);
    cpFrontBottomLeft:  Result := Vector3(Min.X, Min.Y, Min.Z);
    cpFrontBottomRight: Result := Vector3(Max.X, Min.Y, Min.Z);
    cpBackTopLeft:      Result := Vector3(Min.X, Max.Y, Max.Z);
    cpBackTopRight:     Result := Vector3(Max.X, Max.Y, Max.Z);
    cpBackBottomLeft:   Result := Vector3(Min.X, Min.Y, Max.Z);
    cpBackBottomRight:  Result := Vector3(Max.X, Min.Y, Max.Z);
  else
    Result := Mid;  // fallback (should never happen)
  end;
end;

function TMesh.GetWorldPointAtPreset(Preset: TMeshCenterPreset): TVector3;
begin
  Result := Vector3(fModelMatrix * Vector4(GetPointAtPreset(Preset), 1.0));
end;

procedure TMesh.SetPositionByPreset(Preset: TMeshCenterPreset; const TargetPos: TVector3);
var
  CurrentPos: TVector3;
  Delta: TVector3;
begin
  // Both positions are mesh-local/object-local. Editor.Mesh uses this to move
  // the chosen origin preset to (0,0,0), then Apply/Cancel decides whether that
  // staged geometry edit is kept or restored.
  CurrentPos := GetPointAtPreset(Preset);
  Delta := TargetPos - CurrentPos;

  // Apply the translation to all vertices (no rotation, no scaling).
  ApplyTransform(Delta, Vector3(0, 0, 0), Vector3(1, 1, 1));
end;

function TMesh.GetPresetAtPoint(const Point: TVector3): TMeshCenterPreset;
const
  EPS = 1e-5;
type
  // Index by [cx+1, cy+1, cz+1] where each axis is -1 (min), 0 (mid), 1 (max)
  TPresetGrid = array[0..2, 0..2, 0..2] of TMeshCenterPreset;
const
  // Axis convention: X = Left(-)/Right(+), Y = Bottom(-)/Top(+), Z = Front(-)/Back(+)
  PRESETS: TPresetGrid = (
    // cx = -1 (Left)
    (
      ( cpFrontBottomLeft,   cpLeftBottomMiddle,  cpBackBottomLeft   ), // cy = -1
      ( cpFrontMiddleLeft,   cpLeftMiddleMiddle,  cpBackMiddleLeft   ), // cy =  0
      ( cpFrontTopLeft,      cpLeftTopMiddle,     cpBackTopLeft      )  // cy = +1
    ),
    // cx = 0 (Middle)
    (
      ( cpFrontBottomMiddle, cpBottomMiddleMiddle, cpBackBottomMiddle ),
      ( cpFrontMiddleMiddle, cpCenter,             cpBackMiddleMiddle ),
      ( cpFrontTopMiddle,    cpTopMiddleMiddle,    cpBackTopMiddle    )
    ),
    // cx = +1 (Right)
    (
      ( cpFrontBottomRight,  cpRightBottomMiddle, cpBackBottomRight  ),
      ( cpFrontMiddleRight,  cpRightMiddleMiddle, cpBackMiddleRight  ),
      ( cpFrontTopRight,     cpRightTopMiddle,    cpBackTopRight     )
    )
  );
var
  Min, Max, Mid: TVector3;

  function Classify(Value, MinV, MidV, MaxV: Single): Integer; inline;
  begin
    if Abs(Value - MinV) <= EPS then Result := -1
    else if Abs(Value - MaxV) <= EPS then Result :=  1
    else if Abs(Value - MidV) <= EPS then Result :=  0
    else Result := -2; // not a preset point
  end;

var
  cx, cy, cz: Integer;
begin
  Min := fBoundingBoxMin;
  Max := fBoundingBoxMax;
  Mid := (Min + Max) * 0.5;

  cx := Classify(Point.X, Min.X, Mid.X, Max.X);
  cy := Classify(Point.Y, Min.Y, Mid.Y, Max.Y);
  cz := Classify(Point.Z, Min.Z, Mid.Z, Max.Z);

  if (cx < -1) or (cy < -1) or (cz < -1) then
    Exit(cpCenter);

  Result := PRESETS[cx + 1, cy + 1, cz + 1];
end;

procedure TMesh.SetGeometry(const Vertices: TArray<TVertex>; const Indices: TArray<GLuint>;
  BuildTangentsAndBitangents: Boolean);
begin
  fVertices := Copy(Vertices, 0, Length(Vertices));
  fIndices := Copy(Indices, 0, Length(Indices));
  fUseElements := Length(fIndices) > 0;
  SetLength(fVertexAttributes, 5);
  ComputeBoundingBox;

  if fVAO = 0 then
    CreateBuffers
  else
    RefreshBuffers;

  if BuildTangentsAndBitangents then
    Self.BuildTangentsAndBitangents;
end;


procedure TMesh.CreateBuffers;
var
  BufferSize: NativeInt;
begin
  glGenVertexArrays(1, @fVAO);
  glBindVertexArray(fVAO);

  glGenBuffers(1, @fVBO);

  // Bind and allocate
  glBindBuffer(GL_ARRAY_BUFFER, fVBO);
  BufferSize := Length(fVertices) * SizeOf(TVertex);

  if fStaticGeometry then
    glBufferData(GL_ARRAY_BUFFER, BufferSize, fVertices, GL_STATIC_DRAW)
  else
    glBufferData(GL_ARRAY_BUFFER, BufferSize, fVertices, GL_STREAM_DRAW);
  fVertexBufferSize := BufferSize;

  // layout(location=0) in vec3 position;
  fVertexAttributes[0].Initialize(0, 3, GL_FLOAT, GL_FALSE, Pointer(0));
  // layout(location=1) in vec3 normal;
  fVertexAttributes[1].Initialize(1, 3, GL_FLOAT, GL_FALSE, Pointer(SizeOf(TVector3)));
  // layout(location=2) in vec3 tangent;
  fVertexAttributes[2].Initialize(2, 3, GL_FLOAT, GL_FALSE, Pointer(SizeOf(TVector3) * 2));
  // layout(location=3) in vec3 bitangent;
  fVertexAttributes[3].Initialize(3, 3, GL_FLOAT, GL_FALSE, Pointer(SizeOf(TVector3) * 3));
  // layout(location=4) in vec2 texcoord;
  fVertexAttributes[4].Initialize(4, 2, GL_FLOAT, GL_FALSE, Pointer(SizeOf(TVector3) * 4));

  // Create EBO if indices exist
  if Length(fIndices) > 0 then
  begin
    glGenBuffers(1, @fEBO);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, fEBO);
    if fStaticGeometry then
      glBufferData(GL_ELEMENT_ARRAY_BUFFER, Length(fIndices) * SizeOf(GLuint), fIndices, GL_STATIC_DRAW)
    else
      glBufferData(GL_ELEMENT_ARRAY_BUFFER, Length(fIndices) * SizeOf(GLuint), fIndices, GL_DYNAMIC_DRAW);
  end;

  glBindVertexArray(0);
  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
end;

procedure TMesh.BuildTangentsAndBitangents;
var
  i, idx0, idx1, idx2: Integer;
  v0, v1, v2: TVertex;
  Edge1, Edge2: TVector3;
  dUV1, dUV2: TVector2;
  r, det: Single;
  TangentTri, BitangentTri: TVector3;
  AccumTangents, AccumBitangents: TArray<TVector3>;
  HasValidUV: Boolean;
begin
  if (Length(fVertices) = 0) or (Length(fIndices) = 0) then
    Exit;

  SetLength(AccumTangents, Length(fVertices));
  SetLength(AccumBitangents, Length(fVertices));

  // Zero accumulators
  for i := 0 to Length(fVertices) - 1 do
  begin
    AccumTangents[i] := Vector3(0, 0, 0);
    AccumBitangents[i] := Vector3(0, 0, 0);
  end;

  // Process each triangle
  i := 0;
  while i < Length(fIndices) do
  begin
    idx0 := fIndices[i];
    idx1 := fIndices[i+1];
    idx2 := fIndices[i+2];

    v0 := fVertices[idx0];
    v1 := fVertices[idx1];
    v2 := fVertices[idx2];

    Edge1 := v1.Position - v0.Position;
    Edge2 := v2.Position - v0.Position;

    dUV1 := v1.TexCoord - v0.TexCoord;
    dUV2 := v2.TexCoord - v0.TexCoord;

    det := dUV1.X * dUV2.Y - dUV1.Y * dUV2.X;

    // Check if UVs are valid (non-zero area in UV space)
    HasValidUV := (Abs(det) > 1e-6);

    if HasValidUV then
    begin
      r := 1.0 / det;
      TangentTri := ((Edge1 * dUV2.Y) - (Edge2 * dUV1.Y)) * r;
      BitangentTri := ((Edge2 * dUV1.X) - (Edge1 * dUV2.X)) * r;
    end
    else
    begin
      // Fallback: use an arbitrary tangent direction (e.g., (1,0,0))
      // and derive bitangent as cross(normal, tangent)
      // For simplicity, choose a tangent orthogonal to the normal.
      var Norm := v0.Normal.Normalize;
      var TangentDefault := Vector3(1, 0, 0);
      // Make sure tangent is not parallel to normal
      if Abs(Norm.Dot(TangentDefault)) > 0.9999 then
        TangentDefault := Vector3(0, 1, 0);
      // Gram-Schmidt orthogonalize
      TangentTri := (TangentDefault - Norm * Norm.Dot(TangentDefault)).Normalize;
      BitangentTri := Norm.Cross(TangentTri).Normalize;
    end;

    AccumTangents[idx0] := AccumTangents[idx0] + TangentTri;
    AccumTangents[idx1] := AccumTangents[idx1] + TangentTri;
    AccumTangents[idx2] := AccumTangents[idx2] + TangentTri;

    AccumBitangents[idx0] := AccumBitangents[idx0] + BitangentTri;
    AccumBitangents[idx1] := AccumBitangents[idx1] + BitangentTri;
    AccumBitangents[idx2] := AccumBitangents[idx2] + BitangentTri;

    Inc(i, 3);
  end;

  // Normalise and orthogonalise per vertex
  for i := 0 to Length(fVertices) - 1 do
  begin
    if AccumTangents[i].LengthSquared > 1e-9 then
      AccumTangents[i].Normalize
    else
      AccumTangents[i] := Vector3(1, 0, 0); // fallback

    // Gram-Schmidt: make tangent orthogonal to normal
    AccumTangents[i] := (AccumTangents[i] - (fVertices[i].Normal * AccumTangents[i].Dot(fVertices[i].Normal))).Normalize;

    // Recompute bitangent as cross(normal, tangent) to ensure orthogonality
    AccumBitangents[i] := fVertices[i].Normal.Cross(AccumTangents[i]).Normalize;

    fVertices[i].Tangent := AccumTangents[i];
    fVertices[i].Bitangent := AccumBitangents[i];
  end;

  RefreshBuffers;
end;

procedure TMesh.RefreshVertexBuffer;
var
  BufferSize: NativeInt;
  MappedData: Pointer;
begin
  if fVBO = 0 then Exit; // not yet initialized

  BufferSize := Length(fVertices) * SizeOf(TVertex);
  glBindBuffer(GL_ARRAY_BUFFER, fVBO);
  if fStaticGeometry then
    glBufferData(GL_ARRAY_BUFFER, BufferSize, fVertices, GL_STATIC_DRAW)
  else if BufferSize <> fVertexBufferSize then
    glBufferData(GL_ARRAY_BUFFER, BufferSize, fVertices, GL_STREAM_DRAW)
  else if BufferSize > 0 then
  begin
    MappedData := glMapBufferRange(GL_ARRAY_BUFFER, 0, BufferSize,
      GL_MAP_WRITE_BIT or GL_MAP_INVALIDATE_BUFFER_BIT);
    if MappedData <> nil then
    begin
      Move(fVertices[0], MappedData^, BufferSize);
      glUnmapBuffer(GL_ARRAY_BUFFER);
    end
    else
      glBufferSubData(GL_ARRAY_BUFFER, 0, BufferSize, @fVertices[0]);
  end;
  fVertexBufferSize := BufferSize;
  glBindBuffer(GL_ARRAY_BUFFER, 0);
end;

procedure TMesh.RefreshBuffers;
begin
  if fVBO = 0 then Exit; // not yet initialized

  RefreshVertexBuffer;

  glBindVertexArray(fVAO);
  if Length(fIndices) > 0 then
  begin
    if fEBO = 0 then
      glGenBuffers(1, @fEBO);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, fEBO);
    if fStaticGeometry then
      glBufferData(GL_ELEMENT_ARRAY_BUFFER, Length(fIndices) * SizeOf(GLuint), fIndices, GL_STATIC_DRAW)
    else
      glBufferData(GL_ELEMENT_ARRAY_BUFFER, Length(fIndices) * SizeOf(GLuint), fIndices, GL_DYNAMIC_DRAW);
    fUseElements := True;
  end
  else
  begin
    if fEBO <> 0 then
    begin
      glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
      glDeleteBuffers(1, @fEBO);
      fEBO := 0;
    end;
    fUseElements := False;
  end;
  glBindVertexArray(0);
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
end;

procedure TMesh.SetUVs(const NewUVs: TArray<TVector2>);
var
  i: Integer;
begin
  if Length(NewUVs) <> Length(fVertices) then
    raise Exception.Create('SetUVs: array length must match vertex count');

  for i := 0 to High(fVertices) do
    fVertices[i].TexCoord := NewUVs[i];

  // Upload to GPU
  RefreshBuffers;

  // UVs changed -> tangents/bitangents are now invalid
  // Auto-rebuild
  BuildTangentsAndBitangents;
end;

procedure TMesh.ScaleUVs(ScaleU, ScaleV: Single);
var
  i: Integer;
begin
  for i := 0 to High(fVertices) do
  begin
    fVertices[i].TexCoord.X := fVertices[i].TexCoord.X * ScaleU;
    fVertices[i].TexCoord.Y := fVertices[i].TexCoord.Y * ScaleV;
  end;

  RefreshBuffers;
  BuildTangentsAndBitangents;
end;

function TMesh.ApplyMatrix(const Matrix: TMatrix4): Boolean;
var
  I: Integer;
  NormalMatrix: TMatrix4;
  V: TVertex;
begin
  if Length(fVertices) = 0 then
    Exit(True);

  NormalMatrix := Matrix.Inverse.Transpose;

  for I := 0 to High(fVertices) do
  begin
    V := fVertices[I];
    V.Position := Vector3(Matrix * Vector4(V.Position, 1.0));
    V.Normal := Vector3(NormalMatrix * Vector4(V.Normal, 0.0)).Normalize;
    V.Tangent := Vector3(Matrix * Vector4(V.Tangent, 0.0)).Normalize;
    V.Bitangent := Vector3(Matrix * Vector4(V.Bitangent, 0.0)).Normalize;
    fVertices[I] := V;
  end;

  BuildTangentsAndBitangents;
  ComputeBoundingBox;
  Result := True;
end;

function TMesh.ApplyTransform(const Translation: TVector3; const RotationRad: TVector3; const Scale: TVector3): Boolean;
var
  i: Integer;
  Q: TQuaternion;
  RotMat: TMatrix4;
  v: TVertex;
  scaledPos: TVector3;
  rotatedNormal: TVector3;
begin
  if Length(fVertices) = 0 then
    Exit(True);   // Nothing to transform, but not an error

  Q := EulerToQuaternionXYZ(RotationRad);
  RotMat := Q.ToMatrix;

  for i := 0 to High(fVertices) do
  begin
    v := fVertices[i];

    scaledPos := Vector3(v.Position.X * Scale.X,
                         v.Position.Y * Scale.Y,
                         v.Position.Z * Scale.Z);

    v.Position := Vector3(RotMat * Vector4(scaledPos, 0)) + Translation;

    rotatedNormal := Vector3(RotMat * Vector4(v.Normal, 0));

    v.Normal := Vector3(rotatedNormal.X / IfThen(Scale.X = 0, 1, Scale.X),
                        rotatedNormal.Y / IfThen(Scale.Y = 0, 1, Scale.Y),
                        rotatedNormal.Z / IfThen(Scale.Z = 0, 1, Scale.Z)).Normalize;

    fVertices[i] := v;
  end;

  BuildTangentsAndBitangents;
  ComputeBoundingBox;
  Result := True;
end;

function TMesh.ApplyTransform(const Translation: TVector3; const Rotation: TQuaternion; const Scale: TVector3): Boolean;
var
  i: Integer;
  RotMat: TMatrix4;
  v: TVertex;
  scaledPos: TVector3;
  rotatedNormal: TVector3;
begin
  if Length(fVertices) = 0 then
    Exit(True);   // Nothing to transform, but not an error

  RotMat := Rotation.ToMatrix;

  for i := 0 to High(fVertices) do
  begin
    v := fVertices[i];

    scaledPos := Vector3(v.Position.X * Scale.X,
                         v.Position.Y * Scale.Y,
                         v.Position.Z * Scale.Z);

    v.Position := Vector3(RotMat * Vector4(scaledPos, 0)) + Translation;

    rotatedNormal := Vector3(RotMat * Vector4(v.Normal, 0));

    v.Normal := Vector3(rotatedNormal.X / IfThen(Scale.X = 0, 1, Scale.X),
                        rotatedNormal.Y / IfThen(Scale.Y = 0, 1, Scale.Y),
                        rotatedNormal.Z / IfThen(Scale.Z = 0, 1, Scale.Z)).Normalize;

    fVertices[i] := v;
  end;

  BuildTangentsAndBitangents;
  ComputeBoundingBox;
  Result := True;
end;

{ TFileMesh }
constructor TFileMesh.Create(const Vertices: TArray<TVertex>; const Indices: TArray<GLuint>;
  const aName, ASourceFile: string; IsStatic: Boolean);
begin
  inherited Create(Vertices, Indices, aName, mtFile, IsStatic);
  SetSourceFile(ASourceFile);
end;

procedure TFileMesh.SetSourceFile(const Value: string);
begin
  fSourceFile := Value;
  if (fName = '') and (Value <> '') then
    fName := ExtractFileName(Value);
end;

function TFileMesh.Clone: TMesh;
begin
  Result := TFileMesh.Create(fVertices, fIndices, fName + '_Clone', fSourceFile, fStaticGeometry);
  CopyRenderStateTo(Result);
end;

procedure TFileMesh.SaveShapeData(Stream: TStream);
begin
  WriteStringToStream(Stream, fSourceFile);
end;

{ TPlaneMesh }
constructor TPlaneMesh.Create(Width, Depth: Single; WidthSegments, DepthSegments: Integer;
  const aName: string; IsStatic: Boolean);
begin
  inherited Create(nil, nil, aName, mtPlane, IsStatic);
  fWidth := Width;
  fDepth := Depth;
  fWidthSegments := System.Math.Max(1, WidthSegments);
  fDepthSegments := System.Math.Max(1, DepthSegments);
  RebuildGeometry;
end;


procedure TPlaneMesh.SetWidth(const Value: Single);
begin
  if SameValue(fWidth, Value) then Exit;
  fWidth := Value;
  RebuildGeometry;
end;

procedure TPlaneMesh.SetDepth(const Value: Single);
begin
  if SameValue(fDepth, Value) then Exit;
  fDepth := Value;
  RebuildGeometry;
end;

procedure TPlaneMesh.SetWidthSegments(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := System.Math.Max(1, Value);
  if fWidthSegments = NewValue then Exit;
  fWidthSegments := NewValue;
  RebuildGeometry;
end;

procedure TPlaneMesh.SetDepthSegments(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := System.Math.Max(1, Value);
  if fDepthSegments = NewValue then Exit;
  fDepthSegments := NewValue;
  RebuildGeometry;
end;

procedure TPlaneMesh.RebuildGeometry;
var
  Vertices: TArray<TVertex>;
  Indices: TArray<GLuint>;
begin
  CreatePlaneVertices(Vertices, Indices, fWidth, fDepth, fWidthSegments, fDepthSegments);
  SetGeometry(Vertices, Indices, True);
end;

function TPlaneMesh.Clone: TMesh;
begin
  Result := TPlaneMesh.Create(fWidth, fDepth, fWidthSegments, fDepthSegments, fName + '_Clone', fStaticGeometry);
  CopyRenderStateTo(Result);
end;

procedure TPlaneMesh.SaveShapeData(Stream: TStream);
begin
  Stream.WriteBuffer(fWidth, SizeOf(fWidth));
  Stream.WriteBuffer(fDepth, SizeOf(fDepth));
  Stream.WriteBuffer(fWidthSegments, SizeOf(fWidthSegments));
  Stream.WriteBuffer(fDepthSegments, SizeOf(fDepthSegments));
end;

{ TWaterPlaneMesh }
constructor TWaterPlaneMesh.Create(Width, Depth: Single; WidthSegments,
  DepthSegments: Integer; const aName: string; IsStatic: Boolean);
begin
  inherited Create(Width, Depth, System.Math.Max(WATER_PLANE_MIN_SEGMENTS, WidthSegments),
    System.Math.Max(WATER_PLANE_MIN_SEGMENTS, DepthSegments), aName, IsStatic);
  fMeshType := mtWater;
  fTintColor := Vector4(0.03, 0.28, 0.36, 1.0);
  fDeepColor := Vector4(0.0, 0.08, 0.12, 1.0);
  fReflectionStrength := 0.72;
  fWaveScale := 0.5;
  fWaveSpeed := 0.5;
  fWaveStrength := 0.35;
  fFresnelPower := 5.0;
  fAlpha := 0.82;
end;

function TWaterPlaneMesh.Clone: TMesh;
var
  Water: TWaterPlaneMesh;
begin
  Water := TWaterPlaneMesh.Create(Width, Depth, WidthSegments, DepthSegments,
    fName + '_Clone', fStaticGeometry);
  Water.fTintColor := fTintColor;
  Water.fDeepColor := fDeepColor;
  Water.fReflectionStrength := fReflectionStrength;
  Water.fWaveScale := fWaveScale;
  Water.fWaveSpeed := fWaveSpeed;
  Water.fWaveStrength := fWaveStrength;
  Water.fFresnelPower := fFresnelPower;
  Water.fAlpha := fAlpha;
  CopyRenderStateTo(Water);
  Result := Water;
end;

procedure TWaterPlaneMesh.SaveShapeData(Stream: TStream);
begin
  inherited SaveShapeData(Stream);
  Stream.WriteBuffer(fTintColor, SizeOf(fTintColor));
  Stream.WriteBuffer(fDeepColor, SizeOf(fDeepColor));
  Stream.WriteBuffer(fReflectionStrength, SizeOf(fReflectionStrength));
  Stream.WriteBuffer(fWaveScale, SizeOf(fWaveScale));
  Stream.WriteBuffer(fWaveSpeed, SizeOf(fWaveSpeed));
  Stream.WriteBuffer(fWaveStrength, SizeOf(fWaveStrength));
  Stream.WriteBuffer(fFresnelPower, SizeOf(fFresnelPower));
  Stream.WriteBuffer(fAlpha, SizeOf(fAlpha));
end;

{ THeightFieldMesh }
constructor THeightFieldMesh.Create(const Heights: TArray<Single>; HeightMapWidth,
  HeightMapDepth: Integer; Width, Depth, HeightScale, UVScale: Single;
  const aName: string; IsStatic: Boolean);
begin
  inherited Create(nil, nil, aName, mtHeightField, IsStatic);
  fTileSize := 64; //32
  fWidth := Width;
  fDepth := Depth;
  fHeightScale := HeightScale;
  fUVScale := UVScale;
  fLODEnabled := True;
  fLODCount := 5;
  //fLODDistance := System.Math.Max(4.0, System.Math.Max(Abs(fWidth), Abs(fDepth)) * 0.15);
  fLODDistance := System.Math.Max(8.0, System.Math.Max(Abs(fWidth), Abs(fDepth)) * 0.35);
  //fLODDistance := System.Math.Max(12.0, System.Math.Max(Abs(fWidth), Abs(fDepth)) * 0.50);
  fLODCameraPosition := Vector3(0, 0, 0);
  AssignHeights(Heights, HeightMapWidth, HeightMapDepth, False);
  RebuildGeometry;
end;

destructor THeightFieldMesh.Destroy;
begin
  ClearTiles;
  inherited;
end;

class function THeightFieldMesh.FromBitmap(const AFileName: string; Width,
  Depth, HeightScale, UVScale: Single; const aName: string;
  IsStatic: Boolean): THeightFieldMesh;
var
  Picture: TPicture;
  Bitmap: TBitmap;
  Heights: TArray<Single>;
  X, Y: Integer;
  ColorValue: TColor;
  R, G, B: Byte;
  MeshName: string;
begin
  Picture := TPicture.Create;
  Bitmap := TBitmap.Create;
  try
    Picture.LoadFromFile(AFileName);

    if (Picture.Width < 2) or (Picture.Height < 2) then
      raise Exception.Create('Heightfield bitmap must be at least 2x2 pixels.');

    Bitmap.PixelFormat := pf32bit;
    Bitmap.SetSize(Picture.Width, Picture.Height);
    Bitmap.Canvas.Draw(0, 0, Picture.Graphic);

    SetLength(Heights, Bitmap.Width * Bitmap.Height);
    for Y := 0 to Bitmap.Height - 1 do
      for X := 0 to Bitmap.Width - 1 do
      begin
        ColorValue := ColorToRGB(Bitmap.Canvas.Pixels[X, Y]);
        R := GetRValue(ColorValue);
        G := GetGValue(ColorValue);
        B := GetBValue(ColorValue);
        Heights[Y * Bitmap.Width + X] :=
          (0.2126 * R + 0.7152 * G + 0.0722 * B) / 255.0;
      end;

    MeshName := aName;
    if MeshName = '' then
      MeshName := ExtractFileName(AFileName);

    Result := THeightFieldMesh.Create(Heights, Bitmap.Width, Bitmap.Height,
      Width, Depth, HeightScale, UVScale, MeshName, IsStatic);
    Result.SourceFile := AFileName;
  finally
    Bitmap.Free;
    Picture.Free;
  end;
end;

procedure THeightFieldMesh.AssignHeights(const Values: TArray<Single>;
  HeightMapWidth, HeightMapDepth: Integer; Rebuild: Boolean);
var
  HeightCount64: Int64;
  HeightCount: Integer;
begin
  if (HeightMapWidth < 2) or (HeightMapDepth < 2) then
    raise EArgumentException.Create('Heightfield dimensions must be at least 2x2 samples.');

  HeightCount64 := Int64(HeightMapWidth) * Int64(HeightMapDepth);
  if HeightCount64 > MaxInt then
    raise EArgumentException.Create('Heightfield sample count is too large.');

  HeightCount := Integer(HeightCount64);
  if (Length(Values) > 0) and (Length(Values) < HeightCount) then
    raise EArgumentException.Create('Heightfield height array is smaller than the requested dimensions.');

  fHeightMapWidth := HeightMapWidth;
  fHeightMapDepth := HeightMapDepth;
  SetLength(fHeights, HeightCount);
  if (Length(Values) > 0) and (HeightCount > 0) then
    Move(Values[0], fHeights[0], HeightCount * SizeOf(Single));

  if Rebuild then
    RebuildGeometry;
end;

function THeightFieldMesh.GetHeights: TArray<Single>;
begin
  Result := Copy(fHeights, 0, Length(fHeights));
end;

procedure THeightFieldMesh.SetWidth(const Value: Single);
begin
  if SameValue(fWidth, Value) then Exit;
  fWidth := Value;
  RebuildGeometry;
end;

procedure THeightFieldMesh.SetDepth(const Value: Single);
begin
  if SameValue(fDepth, Value) then Exit;
  fDepth := Value;
  RebuildGeometry;
end;

procedure THeightFieldMesh.SetHeightScale(const Value: Single);
begin
  if SameValue(fHeightScale, Value) then Exit;
  fHeightScale := Value;
  RebuildGeometry;
end;

procedure THeightFieldMesh.SetUVScale(const Value: Single);
begin
  if SameValue(fUVScale, Value) then Exit;
  fUVScale := Value;
  RebuildGeometry;
end;

procedure THeightFieldMesh.SetTileSize(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := System.Math.Max(1, Value);
  if fTileSize = NewValue then
    Exit;

  fTileSize := NewValue;
  BuildTiles;
end;

procedure THeightFieldMesh.SetLODEnabled(const Value: Boolean);
begin
  fLODEnabled := Value;
end;

procedure THeightFieldMesh.SetLODCount(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := System.Math.Min(System.Math.Max(1, Value), HEIGHTFIELD_MAX_LOD_LEVELS);
  if fLODCount = NewValue then
    Exit;

  fLODCount := NewValue;
  BuildTiles;
end;

procedure THeightFieldMesh.SetLODDistance(const Value: Single);
var
  NewValue: Single;
begin
  NewValue := System.Math.Max(0.001, Value);
  if SameValue(fLODDistance, NewValue) then
    Exit;

  fLODDistance := NewValue;
end;

procedure THeightFieldMesh.SetSourceFile(const Value: string);
begin
  fSourceFile := Value;
  if (fName = '') and (Value <> '') then
    fName := ExtractFileName(Value);
end;

procedure THeightFieldMesh.SetHeights(const Values: TArray<Single>;
  HeightMapWidth, HeightMapDepth: Integer);
begin
  AssignHeights(Values, HeightMapWidth, HeightMapDepth, True);
end;

procedure THeightFieldMesh.ClearTiles;
var
  I: Integer;
  LODIndex: Integer;
  EdgeIndex: Integer;
begin
  for I := 0 to High(fTiles) do
  begin
    if fTiles[I].VAO <> 0 then
      glDeleteVertexArrays(1, @fTiles[I].VAO);
    if fTiles[I].VBO <> 0 then
      glDeleteBuffers(1, @fTiles[I].VBO);
    for LODIndex := 0 to High(fTiles[I].LODs) do
    begin
      if fTiles[I].LODs[LODIndex].EBO <> 0 then
        glDeleteBuffers(1, @fTiles[I].LODs[LODIndex].EBO);
      if fTiles[I].LODs[LODIndex].MorphVBO <> 0 then
        glDeleteBuffers(1, @fTiles[I].LODs[LODIndex].MorphVBO);
      for EdgeIndex := 0 to 3 do
        if fTiles[I].LODs[LODIndex].SkirtEBOs[EdgeIndex] <> 0 then
          glDeleteBuffers(1, @fTiles[I].LODs[LODIndex].SkirtEBOs[EdgeIndex]);
    end;
  end;

  SetLength(fTiles, 0);
  fTileColumns := 0;
  fTileRows := 0;
end;

procedure THeightFieldMesh.BuildTiles;
var
  TileX, TileZ: Integer;
  StartX, StartZ: Integer;
  EndX, EndZ: Integer;
  LocalWidth, LocalDepth: Integer;
  LocalVertexCount: Integer;
  LocalX, LocalZ: Integer;
  SourceIndex: Integer;
  LocalIndex: Integer;
  TileIndex: Integer;
  LODIndex: Integer;
  LODStep: Integer;
  EdgeIndex: Integer;
  SkirtDepth: Single;
  SkirtVertexIndex: Integer;
  Vertices: TArray<TVertex>;
  Indices: TArray<GLuint>;
  MorphPositions: TArray<TVector3>;
  Usage: GLenum;

  procedure InitBounds(var Bounds: TAABB);
  begin
    Bounds.Min := Vector3(MaxSingle, MaxSingle, MaxSingle);
    Bounds.Max := Vector3(-MaxSingle, -MaxSingle, -MaxSingle);
  end;

  procedure AddTriangle(var Target: TArray<GLuint>; var Offset: Integer;
    A, B, C: Integer);
  begin
    Target[Offset] := GLuint(A); Inc(Offset);
    Target[Offset] := GLuint(B); Inc(Offset);
    Target[Offset] := GLuint(C); Inc(Offset);
  end;

  procedure AddBlock(var Target: TArray<GLuint>; var Offset: Integer;
    X0, Z0, X1, Z1: Integer);
  var
    TopLeft, BottomLeft, BottomRight, TopRight: Integer;
  begin
    TopLeft := Z0 * LocalWidth + X0;
    BottomLeft := Z1 * LocalWidth + X0;
    BottomRight := Z1 * LocalWidth + X1;
    TopRight := Z0 * LocalWidth + X1;

    AddTriangle(Target, Offset, TopLeft, BottomLeft, BottomRight);
    AddTriangle(Target, Offset, TopLeft, BottomRight, TopRight);
  end;

  function BuildLODIndices(Step: Integer): TArray<GLuint>;
  var
    CellX, CellZ: Integer;
    NextX, NextZ: Integer;
    Offset: Integer;
    MaxIndexCount: Integer;
  begin
    Step := System.Math.Max(1, Step);
    MaxIndexCount :=
      (((LocalWidth - 2) div Step) + 1) *
      (((LocalDepth - 2) div Step) + 1) * 6;
    SetLength(Result, MaxIndexCount);

    Offset := 0;
    CellZ := 0;
    while CellZ < LocalDepth - 1 do
    begin
      NextZ := System.Math.Min(CellZ + Step, LocalDepth - 1);

      CellX := 0;
      while CellX < LocalWidth - 1 do
      begin
        NextX := System.Math.Min(CellX + Step, LocalWidth - 1);
        AddBlock(Result, Offset, CellX, CellZ, NextX, NextZ);
        CellX := NextX;
      end;

      CellZ := NextZ;
    end;

    SetLength(Result, Offset);
  end;

  procedure AddLoweredSkirtVertex(SourceLocalIndex: Integer);
  begin
    Vertices[SkirtVertexIndex] := Vertices[SourceLocalIndex];
    Vertices[SkirtVertexIndex].Position.Y :=
      Vertices[SkirtVertexIndex].Position.Y - SkirtDepth;
    fTiles[TileIndex].Bounds.Include(Vertices[SkirtVertexIndex].Position);
    Inc(SkirtVertexIndex);
  end;

  function BuildSkirtIndices(Edge, Step: Integer): TArray<GLuint>;
  var
    Pos, NextPos: Integer;
    Count: Integer;
    Offset: Integer;
    MaxIndexCount: Integer;
    Original0, Original1: Integer;
    Skirt0, Skirt1: Integer;
  begin
    Step := System.Math.Max(1, Step);
    if (Edge = HEIGHTFIELD_EDGE_TOP) or (Edge = HEIGHTFIELD_EDGE_BOTTOM) then
      Count := LocalWidth
    else
      Count := LocalDepth;

    MaxIndexCount := (((Count - 2) div Step) + 1) * 6;
    SetLength(Result, MaxIndexCount);

    Offset := 0;
    Pos := 0;
    while Pos < Count - 1 do
    begin
      NextPos := System.Math.Min(Pos + Step, Count - 1);

      case Edge of
        HEIGHTFIELD_EDGE_TOP:
          begin
            Original0 := Pos;
            Original1 := NextPos;
            Skirt0 := fTiles[TileIndex].TopSkirtOffset + Pos;
            Skirt1 := fTiles[TileIndex].TopSkirtOffset + NextPos;
          end;

        HEIGHTFIELD_EDGE_BOTTOM:
          begin
            Original0 := (LocalDepth - 1) * LocalWidth + Pos;
            Original1 := (LocalDepth - 1) * LocalWidth + NextPos;
            Skirt0 := fTiles[TileIndex].BottomSkirtOffset + Pos;
            Skirt1 := fTiles[TileIndex].BottomSkirtOffset + NextPos;
          end;

        HEIGHTFIELD_EDGE_LEFT:
          begin
            Original0 := Pos * LocalWidth;
            Original1 := NextPos * LocalWidth;
            Skirt0 := fTiles[TileIndex].LeftSkirtOffset + Pos;
            Skirt1 := fTiles[TileIndex].LeftSkirtOffset + NextPos;
          end;
      else
        begin
          Original0 := Pos * LocalWidth + (LocalWidth - 1);
          Original1 := NextPos * LocalWidth + (LocalWidth - 1);
          Skirt0 := fTiles[TileIndex].RightSkirtOffset + Pos;
          Skirt1 := fTiles[TileIndex].RightSkirtOffset + NextPos;
        end;
      end;

      AddTriangle(Result, Offset, Original0, Skirt0, Skirt1);
      AddTriangle(Result, Offset, Original0, Skirt1, Original1);
      Pos := NextPos;
    end;

    SetLength(Result, Offset);
  end;

  function CoarseSurfacePosition(LocalX, LocalZ, Step: Integer): TVector3;
  var
    X0, X1, Z0, Z1: Integer;
    U, V: Single;
    H00, H10, H01, H11: Single;
  begin
    Step := System.Math.Max(1, Step);

    X0 := (LocalX div Step) * Step;
    Z0 := (LocalZ div Step) * Step;
    X1 := System.Math.Min(X0 + Step, LocalWidth - 1);
    Z1 := System.Math.Min(Z0 + Step, LocalDepth - 1);

    if X1 = X0 then
      U := 0.0
    else
      U := (LocalX - X0) / (X1 - X0);

    if Z1 = Z0 then
      V := 0.0
    else
      V := (LocalZ - Z0) / (Z1 - Z0);

    H00 := Vertices[Z0 * LocalWidth + X0].Position.Y;
    H10 := Vertices[Z0 * LocalWidth + X1].Position.Y;
    H01 := Vertices[Z1 * LocalWidth + X0].Position.Y;
    H11 := Vertices[Z1 * LocalWidth + X1].Position.Y;

    Result := Vertices[LocalZ * LocalWidth + LocalX].Position;

    // Match AddBlock's diagonal so the morphed fine LOD converges exactly to
    // the next coarser LOD before the index buffer switches.
    if V >= U then
      Result.Y := H00 * (1.0 - V) + H01 * (V - U) + H11 * U
    else
      Result.Y := H00 * (1.0 - U) + H11 * V + H10 * (U - V);
  end;

  function BuildMorphPositions(Step: Integer): TArray<TVector3>;
  var
    MorphStep: Integer;
    LocalIndex: Integer;
    SourceLocalIndex: Integer;
    LocalX, LocalZ: Integer;
  begin
    MorphStep := System.Math.Max(1, Step * 2);
    SetLength(Result, Length(Vertices));

    for LocalZ := 0 to LocalDepth - 1 do
      for LocalX := 0 to LocalWidth - 1 do
      begin
        LocalIndex := LocalZ * LocalWidth + LocalX;
        Result[LocalIndex] := CoarseSurfacePosition(LocalX, LocalZ, MorphStep);
      end;

    for LocalX := 0 to LocalWidth - 1 do
    begin
      SourceLocalIndex := LocalX;
      Result[fTiles[TileIndex].TopSkirtOffset + LocalX] := Result[SourceLocalIndex];
      Result[fTiles[TileIndex].TopSkirtOffset + LocalX].Y :=
        Result[fTiles[TileIndex].TopSkirtOffset + LocalX].Y - SkirtDepth;

      SourceLocalIndex := (LocalDepth - 1) * LocalWidth + LocalX;
      Result[fTiles[TileIndex].BottomSkirtOffset + LocalX] := Result[SourceLocalIndex];
      Result[fTiles[TileIndex].BottomSkirtOffset + LocalX].Y :=
        Result[fTiles[TileIndex].BottomSkirtOffset + LocalX].Y - SkirtDepth;
    end;

    for LocalZ := 0 to LocalDepth - 1 do
    begin
      SourceLocalIndex := LocalZ * LocalWidth;
      Result[fTiles[TileIndex].LeftSkirtOffset + LocalZ] := Result[SourceLocalIndex];
      Result[fTiles[TileIndex].LeftSkirtOffset + LocalZ].Y :=
        Result[fTiles[TileIndex].LeftSkirtOffset + LocalZ].Y - SkirtDepth;

      SourceLocalIndex := LocalZ * LocalWidth + (LocalWidth - 1);
      Result[fTiles[TileIndex].RightSkirtOffset + LocalZ] := Result[SourceLocalIndex];
      Result[fTiles[TileIndex].RightSkirtOffset + LocalZ].Y :=
        Result[fTiles[TileIndex].RightSkirtOffset + LocalZ].Y - SkirtDepth;
    end;
  end;

begin
  ClearTiles;

  if (fTileSize <= 0) or (fHeightMapWidth < 2) or (fHeightMapDepth < 2) or
     (Length(fVertices) < fHeightMapWidth * fHeightMapDepth) then
    Exit;

  if fStaticGeometry then
    Usage := GL_STATIC_DRAW
  else
    Usage := GL_DYNAMIC_DRAW;

  fTileColumns := ((fHeightMapWidth - 2) div fTileSize) + 1;
  fTileRows := ((fHeightMapDepth - 2) div fTileSize) + 1;
  SkirtDepth := System.Math.Max(0.01, Abs(fHeightScale));
  SkirtDepth := System.Math.Max(SkirtDepth,
    System.Math.Max(Abs(fWidth), Abs(fDepth)) * 0.001);

  for TileZ := 0 to fTileRows - 1 do
  begin
    StartZ := TileZ * fTileSize;
    EndZ := System.Math.Min(StartZ + fTileSize, fHeightMapDepth - 1);
    LocalDepth := EndZ - StartZ + 1;

    for TileX := 0 to fTileColumns - 1 do
    begin
      StartX := TileX * fTileSize;
      EndX := System.Math.Min(StartX + fTileSize, fHeightMapWidth - 1);
      LocalWidth := EndX - StartX + 1;

      if (LocalWidth < 2) or (LocalDepth < 2) then
        Continue;

      LocalVertexCount := LocalWidth * LocalDepth;
      SetLength(Vertices, LocalVertexCount + LocalWidth * 2 + LocalDepth * 2);

      TileIndex := Length(fTiles);
      SetLength(fTiles, TileIndex + 1);
      FillChar(fTiles[TileIndex], SizeOf(THeightFieldTile), 0);
      fTiles[TileIndex].TileX := TileX;
      fTiles[TileIndex].TileZ := TileZ;
      InitBounds(fTiles[TileIndex].Bounds);

      LocalIndex := 0;
      for LocalZ := 0 to LocalDepth - 1 do
        for LocalX := 0 to LocalWidth - 1 do
        begin
          SourceIndex := (StartZ + LocalZ) * fHeightMapWidth + (StartX + LocalX);
          Vertices[LocalIndex] := fVertices[SourceIndex];
          fTiles[TileIndex].Bounds.Include(Vertices[LocalIndex].Position);
          Inc(LocalIndex);
        end;

      SkirtVertexIndex := LocalVertexCount;

      fTiles[TileIndex].TopSkirtOffset := SkirtVertexIndex;
      for LocalX := 0 to LocalWidth - 1 do
        AddLoweredSkirtVertex(LocalX);

      fTiles[TileIndex].BottomSkirtOffset := SkirtVertexIndex;
      for LocalX := 0 to LocalWidth - 1 do
        AddLoweredSkirtVertex((LocalDepth - 1) * LocalWidth + LocalX);

      fTiles[TileIndex].LeftSkirtOffset := SkirtVertexIndex;
      for LocalZ := 0 to LocalDepth - 1 do
        AddLoweredSkirtVertex(LocalZ * LocalWidth);

      fTiles[TileIndex].RightSkirtOffset := SkirtVertexIndex;
      for LocalZ := 0 to LocalDepth - 1 do
        AddLoweredSkirtVertex(LocalZ * LocalWidth + (LocalWidth - 1));

      glGenVertexArrays(1, @fTiles[TileIndex].VAO);
      glBindVertexArray(fTiles[TileIndex].VAO);

      glGenBuffers(1, @fTiles[TileIndex].VBO);
      glBindBuffer(GL_ARRAY_BUFFER, fTiles[TileIndex].VBO);
      glBufferData(GL_ARRAY_BUFFER, Length(Vertices) * SizeOf(TVertex),
        Vertices, Usage);

      glEnableVertexAttribArray(0);
      glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, SizeOf(TVertex), Pointer(0));
      glEnableVertexAttribArray(1);
      glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, SizeOf(TVertex), Pointer(SizeOf(TVector3)));
      glEnableVertexAttribArray(2);
      glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, SizeOf(TVertex), Pointer(SizeOf(TVector3) * 2));
      glEnableVertexAttribArray(3);
      glVertexAttribPointer(3, 3, GL_FLOAT, GL_FALSE, SizeOf(TVertex), Pointer(SizeOf(TVector3) * 3));
      glEnableVertexAttribArray(4);
      glVertexAttribPointer(4, 2, GL_FLOAT, GL_FALSE, SizeOf(TVertex), Pointer(SizeOf(TVector3) * 4));

      for LODIndex := 0 to fLODCount - 1 do
      begin
        LODStep := 1 shl LODIndex;
        Indices := BuildLODIndices(LODStep);
        if Length(Indices) = 0 then
          Continue;

        fTiles[TileIndex].LODs[LODIndex].Step := LODStep;
        fTiles[TileIndex].LODs[LODIndex].IndexCount := Length(Indices);
        glGenBuffers(1, @fTiles[TileIndex].LODs[LODIndex].EBO);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, fTiles[TileIndex].LODs[LODIndex].EBO);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, Length(Indices) * SizeOf(GLuint),
          Indices, Usage);

        MorphPositions := BuildMorphPositions(LODStep);
        glGenBuffers(1, @fTiles[TileIndex].LODs[LODIndex].MorphVBO);
        glBindBuffer(GL_ARRAY_BUFFER, fTiles[TileIndex].LODs[LODIndex].MorphVBO);
        glBufferData(GL_ARRAY_BUFFER, Length(MorphPositions) * SizeOf(TVector3),
          MorphPositions, Usage);

        for EdgeIndex := 0 to 3 do
        begin
          Indices := BuildSkirtIndices(EdgeIndex, LODStep);
          if Length(Indices) = 0 then
            Continue;

          fTiles[TileIndex].LODs[LODIndex].SkirtIndexCounts[EdgeIndex] :=
            Length(Indices);
          glGenBuffers(1,
            @fTiles[TileIndex].LODs[LODIndex].SkirtEBOs[EdgeIndex]);
          glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,
            fTiles[TileIndex].LODs[LODIndex].SkirtEBOs[EdgeIndex]);
          glBufferData(GL_ELEMENT_ARRAY_BUFFER,
            Length(Indices) * SizeOf(GLuint), Indices, Usage);
        end;

        fTiles[TileIndex].LODCount := LODIndex + 1;
      end;

      glBindVertexArray(0);
      glBindBuffer(GL_ARRAY_BUFFER, 0);
      glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    end;
  end;
end;

function THeightFieldMesh.SelectTileLOD(var Tile: THeightFieldTile): Integer;
const
  LOD_MORPH_BAND = 0.35; // 35% fade band around each LOD threshold.
var
  WorldBounds: TAABB;
  Center, Extents: TVector3;
  Distance: Single;
  Radius: Single;
  EffectiveDistance: Single;
  Current: Integer;
  StartDistance: Single;
  EndDistance: Single;
  T: Single;

  function SmoothStep(Value: Single): Single;
  begin
    Value := System.Math.Min(1.0, System.Math.Max(0.0, Value));
    Result := Value * Value * (3.0 - 2.0 * Value);
  end;
begin
  Result := 0;

  if (not fLODEnabled) or (Tile.LODCount <= 1) then
  begin
    Tile.CurrentLOD := 0;
    Tile.CurrentMorph := 0.0;
    Exit;
  end;

  EffectiveDistance := fLODDistance;
  if EffectiveDistance <= 0.001 then
    EffectiveDistance := System.Math.Max(4.0,
      System.Math.Max(Abs(fWidth), Abs(fDepth)) * 0.15);

  WorldBounds := Tile.Bounds.Transform(fModelMatrix);
  Center := WorldBounds.Center;
  Extents := WorldBounds.Extents;

  Distance := Sqrt(
    Sqr(Center.X - fLODCameraPosition.X) +
    Sqr(Center.Y - fLODCameraPosition.Y) +
    Sqr(Center.Z - fLODCameraPosition.Z));

  Radius := Sqrt(Sqr(Extents.X) + Sqr(Extents.Y) + Sqr(Extents.Z));
  Distance := System.Math.Max(0.0, Distance - Radius);

  Current := Tile.CurrentLOD;

  if Current < 0 then
    Current := 0;
  if Current >= Tile.LODCount then
    Current := Tile.LODCount - 1;

  while (Current < Tile.LODCount - 1) and
        (Distance > (Current + 1) * EffectiveDistance * (1.0 + LOD_MORPH_BAND)) do
    Inc(Current);

  while (Current > 0) and
        (Distance < Current * EffectiveDistance * (1.0 + LOD_MORPH_BAND)) do
    Dec(Current);

  Tile.CurrentLOD := Current;
  Tile.CurrentMorph := 0.0;
  if Current < Tile.LODCount - 1 then
  begin
    StartDistance := (Current + 1) * EffectiveDistance * (1.0 - LOD_MORPH_BAND);
    EndDistance := (Current + 1) * EffectiveDistance * (1.0 + LOD_MORPH_BAND);
    if EndDistance > StartDistance then
    begin
      T := (Distance - StartDistance) / (EndDistance - StartDistance);
      Tile.CurrentMorph := SmoothStep(T);
    end;
  end;

  Result := Current;
end;

procedure THeightFieldMesh.RebuildGeometry;
var
  Vertices: TArray<TVertex>;
  Indices: TArray<GLuint>;
begin
  CreateHeightFieldVertices(Vertices, Indices, fHeights, fHeightMapWidth,
    fHeightMapDepth, fWidth, fDepth, fHeightScale, fUVScale);
  SetGeometry(Vertices, Indices, True);
  BuildTiles;
end;

function THeightFieldMesh.Clone: TMesh;
begin
  Result := THeightFieldMesh.Create(fHeights, fHeightMapWidth, fHeightMapDepth,
    fWidth, fDepth, fHeightScale, fUVScale, fName + '_Clone', fStaticGeometry);
  THeightFieldMesh(Result).fSourceFile := fSourceFile;
  THeightFieldMesh(Result).fTileSize := fTileSize;
  THeightFieldMesh(Result).fLODEnabled := fLODEnabled;
  THeightFieldMesh(Result).fLODCount := fLODCount;
  THeightFieldMesh(Result).fLODDistance := fLODDistance;
  THeightFieldMesh(Result).fLODCameraPosition := fLODCameraPosition;
  THeightFieldMesh(Result).BuildTiles;
  CopyRenderStateTo(Result);
end;

function THeightFieldMesh.HeightAtSample(X, Z: Integer): Single;
begin
  Result := 0.0;
  if (Length(fHeights) = 0) or (fHeightMapWidth < 1) or (fHeightMapDepth < 1) then
    Exit;

  if X < 0 then X := 0
  else if X >= fHeightMapWidth then X := fHeightMapWidth - 1;

  if Z < 0 then Z := 0
  else if Z >= fHeightMapDepth then Z := fHeightMapDepth - 1;

  Result := fHeights[Z * fHeightMapWidth + X] * fHeightScale;
end;

function THeightFieldMesh.InterpolatedHeight(LocalX, LocalZ: Single): Single;
var
  U, V: Single;
  SampleX, SampleZ: Single;
  X0, X1, Z0, Z1: Integer;
  Tx, Tz: Single;
  H00, H10, H01, H11: Single;
  H0, H1: Single;
begin
  Result := 0.0;
  if (fHeightMapWidth < 2) or (fHeightMapDepth < 2) or
     SameValue(fWidth, 0.0) or SameValue(fDepth, 0.0) then
    Exit;

  U := (LocalX / fWidth) + 0.5;
  V := (LocalZ / fDepth) + 0.5;
  U := System.Math.Min(1.0, System.Math.Max(0.0, U));
  V := System.Math.Min(1.0, System.Math.Max(0.0, V));

  SampleX := U * (fHeightMapWidth - 1);
  SampleZ := V * (fHeightMapDepth - 1);

  X0 := Trunc(SampleX);
  Z0 := Trunc(SampleZ);
  X1 := System.Math.Min(X0 + 1, fHeightMapWidth - 1);
  Z1 := System.Math.Min(Z0 + 1, fHeightMapDepth - 1);
  Tx := SampleX - X0;
  Tz := SampleZ - Z0;

  H00 := HeightAtSample(X0, Z0);
  H10 := HeightAtSample(X1, Z0);
  H01 := HeightAtSample(X0, Z1);
  H11 := HeightAtSample(X1, Z1);

  H0 := H00 + (H10 - H00) * Tx;
  H1 := H01 + (H11 - H01) * Tx;
  Result := H0 + (H1 - H0) * Tz;
end;

function THeightFieldMesh.NormalAtSample(X, Z: Integer): TVector3;
var
  StepX, StepZ: Single;
  LeftH, RightH, DownH, UpH: Single;
  Dx, Dz, N: TVector3;
  Len: Single;
begin
  if (fHeightMapWidth < 2) or (fHeightMapDepth < 2) then
    Exit(Vector3(0.0, 1.0, 0.0));

  if SameValue(fWidth, 0.0) then
    StepX := 1.0
  else
    StepX := fWidth / (fHeightMapWidth - 1);

  if SameValue(fDepth, 0.0) then
    StepZ := 1.0
  else
    StepZ := fDepth / (fHeightMapDepth - 1);

  LeftH := HeightAtSample(X - 1, Z);
  RightH := HeightAtSample(X + 1, Z);
  DownH := HeightAtSample(X, Z - 1);
  UpH := HeightAtSample(X, Z + 1);

  Dx := Vector3(2.0 * StepX, RightH - LeftH, 0.0);
  Dz := Vector3(0.0, UpH - DownH, 2.0 * StepZ);
  N := Vector3(
    Dz.Y * Dx.Z - Dz.Z * Dx.Y,
    Dz.Z * Dx.X - Dz.X * Dx.Z,
    Dz.X * Dx.Y - Dz.Y * Dx.X
  );

  Len := Sqrt(N.X * N.X + N.Y * N.Y + N.Z * N.Z);
  if Len > 1e-6 then
    Result := Vector3(N.X / Len, N.Y / Len, N.Z / Len)
  else
    Result := Vector3(0.0, 1.0, 0.0);
end;

procedure THeightFieldMesh.Draw;
var
  Planes: TFrustumPlanes;
begin
  FillChar(Planes, SizeOf(Planes), 0);
  DrawCulled(Planes, False);
end;

procedure THeightFieldMesh.DrawCulled(const AFrustumPlanes: TFrustumPlanes;
  AUseFrustum: Boolean);
var
  Mat: TMaterial;
  Technique: TRenderTechnique;
  RenderState: TRenderTechniqueState;
  OldDepthFunc: GLint;
  OldDepthMask: GLboolean;
  I: Integer;
  LODIndex: Integer;
  EdgeIndex: Integer;
  TileLODs: TArray<Integer>;
  TileVisibleFlags: TArray<Boolean>;
  MorphFactor: Single;
  UseMorph: Boolean;

  function UsesHeightFieldMultiMaterialShader(AShader: TShader): Boolean;
  begin
    Result := Assigned(AShader) and
      (SameText(ChangeFileExt(ExtractFileName(AShader.VertexPath), ''),
          'HeightField_MultiMaterial') or
       SameText(ChangeFileExt(ExtractFileName(AShader.FragmentPath), ''),
          'HeightField_MultiMaterial'));
  end;

  function TileVisible(const Tile: THeightFieldTile): Boolean;
  begin
    Result := AABBVisibleInFrustum(Tile.Bounds, fModelMatrix,
      AFrustumPlanes, AUseFrustum);
  end;

  function TileIndexAt(ATileX, ATileZ: Integer): Integer;
  begin
    if (ATileX < 0) or (ATileZ < 0) or
       (ATileX >= fTileColumns) or (ATileZ >= fTileRows) then
      Exit(-1);

    Result := ATileZ * fTileColumns + ATileX;
    if (Result < 0) or (Result > High(fTiles)) then
      Result := -1;
  end;

  function NeighborLODForEdge(const Tile: THeightFieldTile; Edge: Integer): Integer;
  var
    NeighborIndex: Integer;
  begin
    case Edge of
      HEIGHTFIELD_EDGE_TOP:
        NeighborIndex := TileIndexAt(Tile.TileX, Tile.TileZ - 1);
      HEIGHTFIELD_EDGE_BOTTOM:
        NeighborIndex := TileIndexAt(Tile.TileX, Tile.TileZ + 1);
      HEIGHTFIELD_EDGE_LEFT:
        NeighborIndex := TileIndexAt(Tile.TileX - 1, Tile.TileZ);
    else
      NeighborIndex := TileIndexAt(Tile.TileX + 1, Tile.TileZ);
    end;

    if NeighborIndex < 0 then
      Result := -1
    else if not TileVisibleFlags[NeighborIndex] then
      Result := -1
    else
      Result := TileLODs[NeighborIndex];
  end;

  procedure DrawEdgeSkirtIfNeeded(const Tile: THeightFieldTile; CurrentLOD,
    Edge: Integer);
  var
    NeighborLOD: Integer;
  begin
    NeighborLOD := NeighborLODForEdge(Tile, Edge);
    if (NeighborLOD < 0) or (CurrentLOD <= NeighborLOD) then
      Exit;

    if (Tile.LODs[CurrentLOD].SkirtEBOs[Edge] = 0) or
       (Tile.LODs[CurrentLOD].SkirtIndexCounts[Edge] <= 0) then
      Exit;

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, Tile.LODs[CurrentLOD].SkirtEBOs[Edge]);
    glDrawElements(GL_TRIANGLES, Tile.LODs[CurrentLOD].SkirtIndexCounts[Edge],
      GL_UNSIGNED_INT, nil);
  end;

  procedure BindLODMorphAttributes(const Tile: THeightFieldTile;
    CurrentLOD: Integer; Morph: Single);
  begin
    UseMorph := (CurrentLOD >= 0) and (CurrentLOD < Tile.LODCount - 1) and
      (Tile.LODs[CurrentLOD].MorphVBO <> 0) and (Morph > 0.0001);

    Technique.Shader.SetUniform('heightFieldUseMorph', GLint(Ord(UseMorph)));
    Technique.Shader.SetUniform('heightFieldMorphFactor', GLfloat(Morph));

    if UseMorph then
    begin
      glBindBuffer(GL_ARRAY_BUFFER, Tile.LODs[CurrentLOD].MorphVBO);
      glEnableVertexAttribArray(5);
      glVertexAttribPointer(5, 3, GL_FLOAT, GL_FALSE, SizeOf(TVector3), Pointer(0));
    end;
  end;
begin
  if not fVisible then Exit;

  if Length(fTiles) = 0 then
  begin
    inherited Draw;
    Exit;
  end;

  if fMaterialLibrary = nil then Exit;
  if (fLibMaterialname = '') and (fMaterialLibrary.Count > 0) then
    fLibMaterialname := fMaterialLibrary.Material[0].Name;
  Mat := fMaterialLibrary.GetMaterial(fLibMaterialname);
  if (Mat = nil) or (Mat.Shader = nil) then Exit;

  case Mat.Materialtype of
    mtShadow:
      Technique := TShadowDepthTechnique.Create(Mat.Shader);
  else
    if (Mat.Materialtype = mtHeightFieldMaterial) or
       UsesHeightFieldMultiMaterialShader(Mat.Shader) then
      Technique := THeightFieldMultiMaterialTechnique.Create(Mat.Shader)
    else
      Technique := TPBRRenderTechnique.Create(Mat.Shader);
  end;

  try
    RenderState := Technique.State;
    RenderState.CullFace := False;
    RenderState.Blend := True;
    Technique.State := RenderState;

    Technique.BeginTechnique;
    Technique.ApplyMaterial(Mat);
    Technique.ApplyObject(fModelMatrix);
    Technique.Shader.SetUniform('terrainUVScale', GLfloat(fUVScale));
    Technique.Shader.SetUniform('heightFieldUseMorph', GLint(0));
    Technique.Shader.SetUniform('heightFieldMorphFactor', GLfloat(0.0));
    if Assigned(fOnRender) then fOnRender(Self, Technique.Shader);

    if fWireFrame then glPolygonMode(GL_FRONT_AND_BACK, GL_LINE)
                  else glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

    if fAlwaysOnTop then
    begin
      glGetIntegerv(GL_DEPTH_FUNC, @OldDepthFunc);
      glGetBooleanv(GL_DEPTH_WRITEMASK, @OldDepthMask);
      glDepthFunc(GL_ALWAYS);
      glDepthMask(GL_FALSE);
    end;
    try
      SetLength(TileLODs, Length(fTiles));
      SetLength(TileVisibleFlags, Length(fTiles));

      for I := 0 to High(fTiles) do
      begin
        TileVisibleFlags[I] := TileVisible(fTiles[I]);

        if TileVisibleFlags[I] then
          TileLODs[I] := SelectTileLOD(fTiles[I])
        else
          TileLODs[I] := -1;
      end;

      for I := 0 to High(fTiles) do
      begin
        if not TileVisibleFlags[I] then
          Continue;

        LODIndex := TileLODs[I];

        if (LODIndex < 0) or
           (fTiles[I].VAO = 0) or
           (fTiles[I].LODCount <= 0) or
           (fTiles[I].LODs[LODIndex].EBO = 0) or
           (fTiles[I].LODs[LODIndex].IndexCount <= 0) then
          Continue;

        glBindVertexArray(fTiles[I].VAO);
        MorphFactor := fTiles[I].CurrentMorph;
        BindLODMorphAttributes(fTiles[I], LODIndex, MorphFactor);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, fTiles[I].LODs[LODIndex].EBO);
        glDrawElements(GL_TRIANGLES, fTiles[I].LODs[LODIndex].IndexCount,
          GL_UNSIGNED_INT, nil);

        for EdgeIndex := 0 to 3 do
          DrawEdgeSkirtIfNeeded(fTiles[I], LODIndex, EdgeIndex);
      end;
      glBindVertexArray(0);
      Technique.Shader.SetUniform('heightFieldUseMorph', GLint(0));
      Technique.Shader.SetUniform('heightFieldMorphFactor', GLfloat(0.0));
    finally
      if fAlwaysOnTop then
      begin
        glDepthFunc(OldDepthFunc);
        glDepthMask(OldDepthMask);
      end;
      if fWireFrame then glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
    end;
  finally
    Technique.EndTechnique;
    Technique.Free;
  end;
end;

procedure THeightFieldMesh.DrawGeometryOnlyCulled(
  const AFrustumPlanes: TFrustumPlanes; AUseFrustum: Boolean);
var
  I: Integer;
  LODIndex: Integer;
  EdgeIndex: Integer;
  TileLODs: TArray<Integer>;
  TileVisibleFlags: TArray<Boolean>;

  function TileVisible(const Tile: THeightFieldTile): Boolean;
  begin
    Result := AABBVisibleInFrustum(Tile.Bounds, fModelMatrix,
      AFrustumPlanes, AUseFrustum);
  end;

  function TileIndexAt(ATileX, ATileZ: Integer): Integer;
  begin
    if (ATileX < 0) or (ATileZ < 0) or
       (ATileX >= fTileColumns) or (ATileZ >= fTileRows) then
      Exit(-1);

    Result := ATileZ * fTileColumns + ATileX;
    if (Result < 0) or (Result > High(fTiles)) then
      Result := -1;
  end;

  function NeighborLODForEdge(const Tile: THeightFieldTile; Edge: Integer): Integer;
  var
    NeighborIndex: Integer;
  begin
    case Edge of
      HEIGHTFIELD_EDGE_TOP:
        NeighborIndex := TileIndexAt(Tile.TileX, Tile.TileZ - 1);
      HEIGHTFIELD_EDGE_BOTTOM:
        NeighborIndex := TileIndexAt(Tile.TileX, Tile.TileZ + 1);
      HEIGHTFIELD_EDGE_LEFT:
        NeighborIndex := TileIndexAt(Tile.TileX - 1, Tile.TileZ);
    else
      NeighborIndex := TileIndexAt(Tile.TileX + 1, Tile.TileZ);
    end;

    if NeighborIndex < 0 then
      Result := -1
    else if not TileVisibleFlags[NeighborIndex] then
      Result := -1
    else
      Result := TileLODs[NeighborIndex];
  end;

  procedure DrawEdgeSkirtIfNeeded(const Tile: THeightFieldTile; CurrentLOD,
    Edge: Integer);
  var
    NeighborLOD: Integer;
  begin
    NeighborLOD := NeighborLODForEdge(Tile, Edge);
    if (NeighborLOD < 0) or (CurrentLOD <= NeighborLOD) then
      Exit;

    if (Tile.LODs[CurrentLOD].SkirtEBOs[Edge] = 0) or
       (Tile.LODs[CurrentLOD].SkirtIndexCounts[Edge] <= 0) then
      Exit;

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, Tile.LODs[CurrentLOD].SkirtEBOs[Edge]);
    glDrawElements(GL_TRIANGLES, Tile.LODs[CurrentLOD].SkirtIndexCounts[Edge],
      GL_UNSIGNED_INT, nil);
  end;
begin
  if not fVisible then
    Exit;

  if Length(fTiles) = 0 then
  begin
    inherited DrawGeometryOnlyCulled(AFrustumPlanes, AUseFrustum);
    Exit;
  end;

  SetLength(TileLODs, Length(fTiles));
  SetLength(TileVisibleFlags, Length(fTiles));

  for I := 0 to High(fTiles) do
  begin
    TileVisibleFlags[I] := TileVisible(fTiles[I]);
    if TileVisibleFlags[I] then
      TileLODs[I] := SelectTileLOD(fTiles[I])
    else
      TileLODs[I] := -1;
  end;

  try
    for I := 0 to High(fTiles) do
    begin
      if not TileVisibleFlags[I] then
        Continue;

      LODIndex := TileLODs[I];
      if (LODIndex < 0) or
         (fTiles[I].VAO = 0) or
         (fTiles[I].LODCount <= 0) or
         (fTiles[I].LODs[LODIndex].EBO = 0) or
         (fTiles[I].LODs[LODIndex].IndexCount <= 0) then
        Continue;

      glBindVertexArray(fTiles[I].VAO);
      glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, fTiles[I].LODs[LODIndex].EBO);
      glDrawElements(GL_TRIANGLES, fTiles[I].LODs[LODIndex].IndexCount,
        GL_UNSIGNED_INT, nil);

      for EdgeIndex := 0 to 3 do
        DrawEdgeSkirtIfNeeded(fTiles[I], LODIndex, EdgeIndex);
    end;
  finally
    glBindVertexArray(0);
  end;
end;

procedure THeightFieldMesh.UpsampleHeights(Factor: Integer);
var
  OldHeights, NewHeights: TArray<Single>;
  OldW, OldD, NewW, NewD: Integer;
  X, Z: Integer;
  SX, SZ: Single;

  function ClampI(Value, MinV, MaxV: Integer): Integer;
  begin
    if Value < MinV then
      Result := MinV
    else if Value > MaxV then
      Result := MaxV
    else
      Result := Value;
  end;

  function H(IX, IZ: Integer): Single;
  begin
    IX := ClampI(IX, 0, OldW - 1);
    IZ := ClampI(IZ, 0, OldD - 1);
    Result := OldHeights[IZ * OldW + IX];
  end;

  function CatmullRom(P0, P1, P2, P3, T: Single): Single;
  var
    T2, T3: Single;
  begin
    T2 := T * T;
    T3 := T2 * T;

    Result := 0.5 * (
      (2.0 * P1) +
      (-P0 + P2) * T +
      (2.0 * P0 - 5.0 * P1 + 4.0 * P2 - P3) * T2 +
      (-P0 + 3.0 * P1 - 3.0 * P2 + P3) * T3
    );
  end;

  function SampleBicubic(AX, AZ: Single): Single;
  var
    IX, IZ: Integer;
    TX, TZ: Single;
    R0, R1, R2, R3: Single;
  begin
    IX := Trunc(AX);
    IZ := Trunc(AZ);

    TX := AX - IX;
    TZ := AZ - IZ;

    R0 := CatmullRom(H(IX - 1, IZ - 1), H(IX, IZ - 1), H(IX + 1, IZ - 1), H(IX + 2, IZ - 1), TX);
    R1 := CatmullRom(H(IX - 1, IZ    ), H(IX, IZ    ), H(IX + 1, IZ    ), H(IX + 2, IZ    ), TX);
    R2 := CatmullRom(H(IX - 1, IZ + 1), H(IX, IZ + 1), H(IX + 1, IZ + 1), H(IX + 2, IZ + 1), TX);
    R3 := CatmullRom(H(IX - 1, IZ + 2), H(IX, IZ + 2), H(IX + 1, IZ + 2), H(IX + 2, IZ + 2), TX);

    Result := CatmullRom(R0, R1, R2, R3, TZ);

    // Catmull-Rom can overshoot slightly
    if Result < 0.0 then Result := 0.0;
    if Result > 1.0 then Result := 1.0;
  end;

begin
  Factor := System.Math.Max(1, Factor);
  if Factor = 1 then
    Exit;

  if (fHeightMapWidth < 2) or (fHeightMapDepth < 2) or (Length(fHeights) = 0) then
    Exit;

  OldW := fHeightMapWidth;
  OldD := fHeightMapDepth;
  OldHeights := Copy(fHeights, 0, Length(fHeights));

  NewW := (OldW - 1) * Factor + 1;
  NewD := (OldD - 1) * Factor + 1;

  SetLength(NewHeights, NewW * NewD);

  for Z := 0 to NewD - 1 do
  begin
    SZ := (Z / (NewD - 1)) * (OldD - 1);

    for X := 0 to NewW - 1 do
    begin
      SX := (X / (NewW - 1)) * (OldW - 1);
      NewHeights[Z * NewW + X] := SampleBicubic(SX, SZ);
    end;
  end;

  AssignHeights(NewHeights, NewW, NewD, True);
end;

procedure THeightFieldMesh.SaveShapeData(Stream: TStream);
var
  HeightCount: Integer;
begin
  Stream.WriteBuffer(fWidth, SizeOf(fWidth));
  Stream.WriteBuffer(fDepth, SizeOf(fDepth));
  Stream.WriteBuffer(fHeightScale, SizeOf(fHeightScale));
  Stream.WriteBuffer(fUVScale, SizeOf(fUVScale));
  Stream.WriteBuffer(fHeightMapWidth, SizeOf(fHeightMapWidth));
  Stream.WriteBuffer(fHeightMapDepth, SizeOf(fHeightMapDepth));

  HeightCount := Length(fHeights);
  Stream.WriteBuffer(HeightCount, SizeOf(HeightCount));
  if HeightCount > 0 then
    Stream.WriteBuffer(fHeights[0], HeightCount * SizeOf(Single));

  WriteStringToStream(Stream, fSourceFile);
end;

{ TCubeMesh }
constructor TCubeMesh.Create(Width, Height, Depth: Single; WidthStacks, HeightStacks,
  DepthStacks: Integer; const aName: string; IsStatic: Boolean);
begin
  inherited Create(nil, nil, aName, mtCube, IsStatic);
  fWidth := Width;
  fHeight := Height;
  fDepth := Depth;
  fWidthStacks := System.Math.Max(1, WidthStacks);
  fHeightStacks := System.Math.Max(1, HeightStacks);
  fDepthStacks := System.Math.Max(1, DepthStacks);
  RebuildGeometry;
end;


procedure TCubeMesh.SetWidth(const Value: Single);
begin
  if SameValue(fWidth, Value) then Exit;
  fWidth := Value;
  RebuildGeometry;
end;

procedure TCubeMesh.SetHeight(const Value: Single);
begin
  if SameValue(fHeight, Value) then Exit;
  fHeight := Value;
  RebuildGeometry;
end;

procedure TCubeMesh.SetDepth(const Value: Single);
begin
  if SameValue(fDepth, Value) then Exit;
  fDepth := Value;
  RebuildGeometry;
end;

procedure TCubeMesh.SetWidthStacks(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := System.Math.Max(1, Value);
  if fWidthStacks = NewValue then Exit;
  fWidthStacks := NewValue;
  RebuildGeometry;
end;

procedure TCubeMesh.SetHeightStacks(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := System.Math.Max(1, Value);
  if fHeightStacks = NewValue then Exit;
  fHeightStacks := NewValue;
  RebuildGeometry;
end;

procedure TCubeMesh.SetDepthStacks(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := System.Math.Max(1, Value);
  if fDepthStacks = NewValue then Exit;
  fDepthStacks := NewValue;
  RebuildGeometry;
end;

procedure TCubeMesh.RebuildGeometry;
var
  Vertices: TArray<TVertex>;
  Indices: TArray<GLuint>;
begin
  CreateCubeVertices(Vertices, Indices, fWidth, fHeight, fDepth,
    fWidthStacks, fHeightStacks, fDepthStacks);
  SetGeometry(Vertices, Indices, True);
end;

function TCubeMesh.Clone: TMesh;
begin
  Result := TCubeMesh.Create(fWidth, fHeight, fDepth, fWidthStacks, fHeightStacks,
    fDepthStacks, fName + '_Clone', fStaticGeometry);
  CopyRenderStateTo(Result);
end;

procedure TCubeMesh.SaveShapeData(Stream: TStream);
begin
  Stream.WriteBuffer(fWidth, SizeOf(fWidth));
  Stream.WriteBuffer(fHeight, SizeOf(fHeight));
  Stream.WriteBuffer(fDepth, SizeOf(fDepth));
  Stream.WriteBuffer(fWidthStacks, SizeOf(fWidthStacks));
  Stream.WriteBuffer(fHeightStacks, SizeOf(fHeightStacks));
  Stream.WriteBuffer(fDepthStacks, SizeOf(fDepthStacks));
end;

{ TSphereMesh }
constructor TSphereMesh.Create(Radius: Single; StackCount, SliceCount: Integer;
  const aName: string; IsStatic: Boolean);
begin
  inherited Create(nil, nil, aName, mtSphere, IsStatic);
  fRadius := Radius;
  fStackCount := System.Math.Max(1, StackCount);
  fSliceCount := System.Math.Max(3, SliceCount);
  RebuildGeometry;
end;


procedure TSphereMesh.SetRadius(const Value: Single);
begin
  if SameValue(fRadius, Value) then Exit;
  fRadius := Value;
  RebuildGeometry;
end;

procedure TSphereMesh.SetStackCount(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := System.Math.Max(1, Value);
  if fStackCount = NewValue then Exit;
  fStackCount := NewValue;
  RebuildGeometry;
end;

procedure TSphereMesh.SetSliceCount(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := System.Math.Max(3, Value);
  if fSliceCount = NewValue then Exit;
  fSliceCount := NewValue;
  RebuildGeometry;
end;

procedure TSphereMesh.RebuildGeometry;
var
  Vertices: TArray<TVertex>;
  Indices: TArray<GLuint>;
begin
  CreateSphereVertices(Vertices, Indices, fRadius, fStackCount, fSliceCount);
  SetGeometry(Vertices, Indices, True);
end;

function TSphereMesh.Clone: TMesh;
begin
  Result := TSphereMesh.Create(fRadius, fStackCount, fSliceCount, fName + '_Clone', fStaticGeometry);
  CopyRenderStateTo(Result);
end;

procedure TSphereMesh.SaveShapeData(Stream: TStream);
begin
  Stream.WriteBuffer(fRadius, SizeOf(fRadius));
  Stream.WriteBuffer(fStackCount, SizeOf(fStackCount));
  Stream.WriteBuffer(fSliceCount, SizeOf(fSliceCount));
end;

{ TCylinderMesh }
constructor TCylinderMesh.Create(Radius, Height: Single; Slices, Stacks: Integer;
  const aName: string; BottomCap, TopCap: TCapType; IsStatic: Boolean);
begin
  inherited Create(nil, nil, aName, mtCylinder, IsStatic);
  fRadius := Radius;
  fHeight := Height;
  fSlices := System.Math.Max(3, Slices);
  fStacks := System.Math.Max(1, Stacks);
  fBottomCap := BottomCap;
  fTopCap := TopCap;
  RebuildGeometry;
end;


procedure TCylinderMesh.SetRadius(const Value: Single);
begin
  if SameValue(fRadius, Value) then Exit;
  fRadius := Value;
  RebuildGeometry;
end;

procedure TCylinderMesh.SetHeight(const Value: Single);
begin
  if SameValue(fHeight, Value) then Exit;
  fHeight := Value;
  RebuildGeometry;
end;

procedure TCylinderMesh.SetSlices(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := System.Math.Max(3, Value);
  if fSlices = NewValue then Exit;
  fSlices := NewValue;
  RebuildGeometry;
end;

procedure TCylinderMesh.SetStacks(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := System.Math.Max(1, Value);
  if fStacks = NewValue then Exit;
  fStacks := NewValue;
  RebuildGeometry;
end;

procedure TCylinderMesh.SetBottomCap(const Value: TCapType);
begin
  if fBottomCap = Value then Exit;
  fBottomCap := Value;
  RebuildGeometry;
end;

procedure TCylinderMesh.SetTopCap(const Value: TCapType);
begin
  if fTopCap = Value then Exit;
  fTopCap := Value;
  RebuildGeometry;
end;

procedure TCylinderMesh.RebuildGeometry;
var
  Vertices: TArray<TVertex>;
  Indices: TArray<GLuint>;
begin
  CreateFrustumVertices(Vertices, Indices, fRadius, fRadius, fHeight, fSlices, fStacks, fBottomCap, fTopCap);
  SetGeometry(Vertices, Indices, True);
end;

function TCylinderMesh.Clone: TMesh;
begin
  Result := TCylinderMesh.Create(fRadius, fHeight, fSlices, fStacks, fName + '_Clone',
    fBottomCap, fTopCap, fStaticGeometry);
  CopyRenderStateTo(Result);
end;

procedure TCylinderMesh.SaveShapeData(Stream: TStream);
var
  CapValue: Integer;
begin
  Stream.WriteBuffer(fRadius, SizeOf(fRadius));
  Stream.WriteBuffer(fHeight, SizeOf(fHeight));
  Stream.WriteBuffer(fSlices, SizeOf(fSlices));
  Stream.WriteBuffer(fStacks, SizeOf(fStacks));
  CapValue := Ord(fBottomCap);
  Stream.WriteBuffer(CapValue, SizeOf(CapValue));
  CapValue := Ord(fTopCap);
  Stream.WriteBuffer(CapValue, SizeOf(CapValue));
end;

{ TCapsuleMesh }
constructor TCapsuleMesh.Create(Radius, Height: Single; Slices, Stacks: Integer;
  const aName: string; IsStatic: Boolean);
begin
  inherited Create(nil, nil, aName, mtCapsule, IsStatic);
  fRadius := Radius;
  fHeight := Height;
  fSlices := System.Math.Max(3, Slices);
  fStacks := System.Math.Max(1, Stacks);
  RebuildGeometry;
end;


procedure TCapsuleMesh.SetRadius(const Value: Single);
begin
  if SameValue(fRadius, Value) then Exit;
  fRadius := Value;
  RebuildGeometry;
end;

procedure TCapsuleMesh.SetHeight(const Value: Single);
begin
  if SameValue(fHeight, Value) then Exit;
  fHeight := Value;
  RebuildGeometry;
end;

procedure TCapsuleMesh.SetSlices(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := System.Math.Max(3, Value);
  if fSlices = NewValue then Exit;
  fSlices := NewValue;
  RebuildGeometry;
end;

procedure TCapsuleMesh.SetStacks(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := System.Math.Max(1, Value);
  if fStacks = NewValue then Exit;
  fStacks := NewValue;
  RebuildGeometry;
end;

procedure TCapsuleMesh.RebuildGeometry;
var
  Vertices: TArray<TVertex>;
  Indices: TArray<GLuint>;
begin
  CreateCapsuleVertices(Vertices, Indices, fRadius, fHeight, fSlices, fStacks);
  SetGeometry(Vertices, Indices, True);
end;

function TCapsuleMesh.Clone: TMesh;
begin
  Result := TCapsuleMesh.Create(fRadius, fHeight, fSlices, fStacks, fName + '_Clone', fStaticGeometry);
  CopyRenderStateTo(Result);
end;

procedure TCapsuleMesh.SaveShapeData(Stream: TStream);
begin
  Stream.WriteBuffer(fRadius, SizeOf(fRadius));
  Stream.WriteBuffer(fHeight, SizeOf(fHeight));
  Stream.WriteBuffer(fSlices, SizeOf(fSlices));
  Stream.WriteBuffer(fStacks, SizeOf(fStacks));
end;

{ TTorusMesh }
constructor TTorusMesh.Create(MajorRadius, MinorRadius: Single; MajorSegments,
  MinorSegments: Integer; const aName: string; IsStatic: Boolean);
begin
  inherited Create(nil, nil, aName, mtTorus, IsStatic);
  fMajorRadius := MajorRadius;
  fMinorRadius := MinorRadius;
  fMajorSegments := System.Math.Max(3, MajorSegments);
  fMinorSegments := System.Math.Max(3, MinorSegments);
  RebuildGeometry;
end;


procedure TTorusMesh.SetMajorRadius(const Value: Single);
begin
  if SameValue(fMajorRadius, Value) then Exit;
  fMajorRadius := Value;
  RebuildGeometry;
end;

procedure TTorusMesh.SetMinorRadius(const Value: Single);
begin
  if SameValue(fMinorRadius, Value) then Exit;
  fMinorRadius := Value;
  RebuildGeometry;
end;

procedure TTorusMesh.SetMajorSegments(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := System.Math.Max(3, Value);
  if fMajorSegments = NewValue then Exit;
  fMajorSegments := NewValue;
  RebuildGeometry;
end;

procedure TTorusMesh.SetMinorSegments(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := System.Math.Max(3, Value);
  if fMinorSegments = NewValue then Exit;
  fMinorSegments := NewValue;
  RebuildGeometry;
end;

procedure TTorusMesh.RebuildGeometry;
var
  Vertices: TArray<TVertex>;
  Indices: TArray<GLuint>;
begin
  CreateTorusVertices(Vertices, Indices, fMajorRadius, fMinorRadius, fMajorSegments, fMinorSegments);
  SetGeometry(Vertices, Indices, True);
end;

function TTorusMesh.Clone: TMesh;
begin
  Result := TTorusMesh.Create(fMajorRadius, fMinorRadius, fMajorSegments, fMinorSegments,
    fName + '_Clone', fStaticGeometry);
  CopyRenderStateTo(Result);
end;

procedure TTorusMesh.SaveShapeData(Stream: TStream);
begin
  Stream.WriteBuffer(fMajorRadius, SizeOf(fMajorRadius));
  Stream.WriteBuffer(fMinorRadius, SizeOf(fMinorRadius));
  Stream.WriteBuffer(fMajorSegments, SizeOf(fMajorSegments));
  Stream.WriteBuffer(fMinorSegments, SizeOf(fMinorSegments));
end;

{ TConeMesh }
constructor TConeMesh.Create(Radius, Height: Single; Sides, Stacks: Integer;
  const aName: string; BottomCap: TCapType; IsStatic: Boolean);
begin
  inherited Create(nil, nil, aName, mtCone, IsStatic);
  fRadius := Radius;
  fHeight := Height;
  fSides := System.Math.Max(3, Sides);
  fStacks := System.Math.Max(1, Stacks);
  fBottomCap := BottomCap;
  RebuildGeometry;
end;


procedure TConeMesh.SetRadius(const Value: Single);
begin
  if SameValue(fRadius, Value) then Exit;
  fRadius := Value;
  RebuildGeometry;
end;

procedure TConeMesh.SetHeight(const Value: Single);
begin
  if SameValue(fHeight, Value) then Exit;
  fHeight := Value;
  RebuildGeometry;
end;

procedure TConeMesh.SetSides(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := System.Math.Max(3, Value);
  if fSides = NewValue then Exit;
  fSides := NewValue;
  RebuildGeometry;
end;

procedure TConeMesh.SetStacks(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := System.Math.Max(1, Value);
  if fStacks = NewValue then Exit;
  fStacks := NewValue;
  RebuildGeometry;
end;

procedure TConeMesh.SetBottomCap(const Value: TCapType);
begin
  if fBottomCap = Value then Exit;
  fBottomCap := Value;
  RebuildGeometry;
end;

procedure TConeMesh.RebuildGeometry;
var
  Vertices: TArray<TVertex>;
  Indices: TArray<GLuint>;
begin
  CreateFrustumVertices(Vertices, Indices, fRadius, 0.0, fHeight, fSides, fStacks, fBottomCap, ctNone);
  SetGeometry(Vertices, Indices, True);
end;

function TConeMesh.Clone: TMesh;
begin
  Result := TConeMesh.Create(fRadius, fHeight, fSides, fStacks, fName + '_Clone',
    fBottomCap, fStaticGeometry);
  CopyRenderStateTo(Result);
end;

procedure TConeMesh.SaveShapeData(Stream: TStream);
var
  CapValue: Integer;
begin
  Stream.WriteBuffer(fRadius, SizeOf(fRadius));
  Stream.WriteBuffer(fHeight, SizeOf(fHeight));
  Stream.WriteBuffer(fSides, SizeOf(fSides));
  Stream.WriteBuffer(fStacks, SizeOf(fStacks));
  CapValue := Ord(fBottomCap);
  Stream.WriteBuffer(CapValue, SizeOf(CapValue));
end;

{ TPrismMesh }
constructor TPrismMesh.Create(Radius, Height: Single; Sides, Stacks: Integer;
  const aName: string; IsStatic: Boolean);
begin
  inherited Create(nil, nil, aName, mtPrism, IsStatic);
  fRadius := Radius;
  fHeight := Height;
  fSides := System.Math.Max(3, Sides);
  fStacks := System.Math.Max(1, Stacks);
  RebuildGeometry;
end;


procedure TPrismMesh.SetRadius(const Value: Single);
begin
  if SameValue(fRadius, Value) then Exit;
  fRadius := Value;
  RebuildGeometry;
end;

procedure TPrismMesh.SetHeight(const Value: Single);
begin
  if SameValue(fHeight, Value) then Exit;
  fHeight := Value;
  RebuildGeometry;
end;

procedure TPrismMesh.SetSides(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := System.Math.Max(3, Value);
  if fSides = NewValue then Exit;
  fSides := NewValue;
  RebuildGeometry;
end;

procedure TPrismMesh.SetStacks(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := System.Math.Max(1, Value);
  if fStacks = NewValue then Exit;
  fStacks := NewValue;
  RebuildGeometry;
end;

procedure TPrismMesh.RebuildGeometry;
var
  Vertices: TArray<TVertex>;
  Indices: TArray<GLuint>;
begin
  CreatePrismVertices(Vertices, Indices, fRadius, fHeight, fSides, fStacks);
  SetGeometry(Vertices, Indices, True);
end;

function TPrismMesh.Clone: TMesh;
begin
  Result := TPrismMesh.Create(fRadius, fHeight, fSides, fStacks, fName + '_Clone', fStaticGeometry);
  CopyRenderStateTo(Result);
end;

procedure TPrismMesh.SaveShapeData(Stream: TStream);
begin
  Stream.WriteBuffer(fRadius, SizeOf(fRadius));
  Stream.WriteBuffer(fHeight, SizeOf(fHeight));
  Stream.WriteBuffer(fSides, SizeOf(fSides));
  Stream.WriteBuffer(fStacks, SizeOf(fStacks));
end;

{ TFrustumMesh }
constructor TFrustumMesh.Create(BottomRadius, TopRadius, Height: Single; Slices, Stacks: Integer;
  BottomCap, TopCap: TCapType; const aName: string; IsStatic: Boolean);
begin
  inherited Create(nil, nil, aName, mtFrustum, IsStatic);
  fBottomRadius := BottomRadius;
  fTopRadius := TopRadius;
  fHeight := Height;
  fSlices := System.Math.Max(3, Slices);
  fStacks := System.Math.Max(1, Stacks);
  fBottomCap := BottomCap;
  fTopCap := TopCap;
  RebuildGeometry;
end;


procedure TFrustumMesh.SetBottomRadius(const Value: Single);
begin
  if SameValue(fBottomRadius, Value) then Exit;
  fBottomRadius := Value;
  RebuildGeometry;
end;

procedure TFrustumMesh.SetTopRadius(const Value: Single);
begin
  if SameValue(fTopRadius, Value) then Exit;
  fTopRadius := Value;
  RebuildGeometry;
end;

procedure TFrustumMesh.SetHeight(const Value: Single);
begin
  if SameValue(fHeight, Value) then Exit;
  fHeight := Value;
  RebuildGeometry;
end;

procedure TFrustumMesh.SetSlices(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := System.Math.Max(3, Value);
  if fSlices = NewValue then Exit;
  fSlices := NewValue;
  RebuildGeometry;
end;

procedure TFrustumMesh.SetStacks(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := System.Math.Max(1, Value);
  if fStacks = NewValue then Exit;
  fStacks := NewValue;
  RebuildGeometry;
end;

procedure TFrustumMesh.SetBottomCap(const Value: TCapType);
begin
  if fBottomCap = Value then Exit;
  fBottomCap := Value;
  RebuildGeometry;
end;

procedure TFrustumMesh.SetTopCap(const Value: TCapType);
begin
  if fTopCap = Value then Exit;
  fTopCap := Value;
  RebuildGeometry;
end;

procedure TFrustumMesh.RebuildGeometry;
var
  Vertices: TArray<TVertex>;
  Indices: TArray<GLuint>;
begin
  CreateFrustumVertices(Vertices, Indices, fBottomRadius, fTopRadius, fHeight,
    fSlices, fStacks, fBottomCap, fTopCap);
  SetGeometry(Vertices, Indices, True);
end;

function TFrustumMesh.Clone: TMesh;
begin
  Result := TFrustumMesh.Create(fBottomRadius, fTopRadius, fHeight, fSlices, fStacks,
    fBottomCap, fTopCap, fName + '_Clone', fStaticGeometry);
  CopyRenderStateTo(Result);
end;

procedure TFrustumMesh.SaveShapeData(Stream: TStream);
var
  CapValue: Integer;
begin
  Stream.WriteBuffer(fBottomRadius, SizeOf(fBottomRadius));
  Stream.WriteBuffer(fTopRadius, SizeOf(fTopRadius));
  Stream.WriteBuffer(fHeight, SizeOf(fHeight));
  Stream.WriteBuffer(fSlices, SizeOf(fSlices));
  Stream.WriteBuffer(fStacks, SizeOf(fStacks));
  CapValue := Ord(fBottomCap);
  Stream.WriteBuffer(CapValue, SizeOf(CapValue));
  CapValue := Ord(fTopCap);
  Stream.WriteBuffer(CapValue, SizeOf(CapValue));
end;

{ TIcosphereMesh }
constructor TIcosphereMesh.Create(Radius: Single; Subdivisions: Integer; const aName: string;
  IsStatic: Boolean);
begin
  inherited Create(nil, nil, aName, mtIcosphere, IsStatic);
  fRadius := Radius;
  fSubdivisions := System.Math.Max(0, Subdivisions);
  RebuildGeometry;
end;


procedure TIcosphereMesh.SetRadius(const Value: Single);
begin
  if SameValue(fRadius, Value) then Exit;
  fRadius := Value;
  RebuildGeometry;
end;

procedure TIcosphereMesh.SetSubdivisions(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := System.Math.Max(0, Value);
  if fSubdivisions = NewValue then Exit;
  fSubdivisions := NewValue;
  RebuildGeometry;
end;

procedure TIcosphereMesh.RebuildGeometry;
var
  Vertices: TArray<TVertex>;
  Indices: TArray<GLuint>;
begin
  CreateIcosphereVertices(Vertices, Indices, fRadius, fSubdivisions);
  SetGeometry(Vertices, Indices, True);
end;

function TIcosphereMesh.Clone: TMesh;
begin
  Result := TIcosphereMesh.Create(fRadius, fSubdivisions, fName + '_Clone', fStaticGeometry);
  CopyRenderStateTo(Result);
end;

procedure TIcosphereMesh.SaveShapeData(Stream: TStream);
begin
  Stream.WriteBuffer(fRadius, SizeOf(fRadius));
  Stream.WriteBuffer(fSubdivisions, SizeOf(fSubdivisions));
end;

{ TGeodesicDomeMesh }
constructor TGeodesicDomeMesh.Create(Radius: Single; Subdivisions: Integer; const aName: string;
  IsStatic: Boolean);
begin
  inherited Create(nil, nil, aName, mtGeodesicDome, IsStatic);
  fRadius := Radius;
  fSubdivisions := System.Math.Max(0, Subdivisions);
  RebuildGeometry;
end;


procedure TGeodesicDomeMesh.SetRadius(const Value: Single);
begin
  if SameValue(fRadius, Value) then Exit;
  fRadius := Value;
  RebuildGeometry;
end;

procedure TGeodesicDomeMesh.SetSubdivisions(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := System.Math.Max(0, Value);
  if fSubdivisions = NewValue then Exit;
  fSubdivisions := NewValue;
  RebuildGeometry;
end;

procedure TGeodesicDomeMesh.RebuildGeometry;
var
  Vertices: TArray<TVertex>;
  Indices: TArray<GLuint>;
begin
  CreateGeodesicDomeVertices(Vertices, Indices, Radius, Subdivisions);
  SetGeometry(Vertices, Indices, True);
end;

function TGeodesicDomeMesh.Clone: TMesh;
begin
  Result := TGeodesicDomeMesh.Create(Radius, Subdivisions, fName + '_Clone', fStaticGeometry);
  CopyRenderStateTo(Result);
end;

procedure TGeodesicDomeMesh.SaveShapeData(Stream: TStream);
begin
  Stream.WriteBuffer(fRadius, SizeOf(fRadius));
  Stream.WriteBuffer(fSubdivisions, SizeOf(fSubdivisions));
end;

{ TArrowMesh }
constructor TArrowMesh.Create(ShaftLength, TipLength, ShaftRadius, TipRadius: Single;
  Slices, Stacks: Integer; const aName: string; IsStatic: Boolean);
begin
  inherited Create(nil, nil, aName, mtArrow, IsStatic);
  fShaftLength := ShaftLength;
  fTipLength := TipLength;
  fShaftRadius := ShaftRadius;
  fTipRadius := TipRadius;
  fSlices := System.Math.Max(3, Slices);
  fStacks := System.Math.Max(1, Stacks);
  RebuildGeometry;
end;


procedure TArrowMesh.SetShaftLength(const Value: Single);
begin
  if SameValue(fShaftLength, Value) then Exit;
  fShaftLength := Value;
  RebuildGeometry;
end;

procedure TArrowMesh.SetTipLength(const Value: Single);
begin
  if SameValue(fTipLength, Value) then Exit;
  fTipLength := Value;
  RebuildGeometry;
end;

procedure TArrowMesh.SetShaftRadius(const Value: Single);
begin
  if SameValue(fShaftRadius, Value) then Exit;
  fShaftRadius := Value;
  RebuildGeometry;
end;

procedure TArrowMesh.SetTipRadius(const Value: Single);
begin
  if SameValue(fTipRadius, Value) then Exit;
  fTipRadius := Value;
  RebuildGeometry;
end;

procedure TArrowMesh.SetSlices(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := System.Math.Max(3, Value);
  if fSlices = NewValue then Exit;
  fSlices := NewValue;
  RebuildGeometry;
end;

procedure TArrowMesh.SetStacks(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := System.Math.Max(1, Value);
  if fStacks = NewValue then Exit;
  fStacks := NewValue;
  RebuildGeometry;
end;

procedure TArrowMesh.RebuildGeometry;
var
  Vertices: TArray<TVertex>;
  Indices: TArray<GLuint>;
begin
  CreateArrowVertices(Vertices, Indices, fShaftLength, fTipLength,
    fShaftRadius, fTipRadius, fSlices, fStacks);
  SetGeometry(Vertices, Indices, True);
end;

function TArrowMesh.Clone: TMesh;
begin
  Result := TArrowMesh.Create(fShaftLength, fTipLength, fShaftRadius, fTipRadius,
    fSlices, fStacks, fName + '_Clone', fStaticGeometry);
  CopyRenderStateTo(Result);
end;

procedure TArrowMesh.SaveShapeData(Stream: TStream);
begin
  Stream.WriteBuffer(fShaftLength, SizeOf(fShaftLength));
  Stream.WriteBuffer(fTipLength, SizeOf(fTipLength));
  Stream.WriteBuffer(fShaftRadius, SizeOf(fShaftRadius));
  Stream.WriteBuffer(fTipRadius, SizeOf(fTipRadius));
  Stream.WriteBuffer(fSlices, SizeOf(fSlices));
  Stream.WriteBuffer(fStacks, SizeOf(fStacks));
end;

{ TGizmoMesh }
constructor TGizmoMesh.Create(ArrowLength, ShaftRadius, TipRadius, TipLength: Single;
  Slices, Stacks: Integer; const aName: string; IsStatic: Boolean);
begin
  inherited Create(ArrowLength, TipLength, ShaftRadius, TipRadius, Slices, Stacks, aName, IsStatic);
  fMeshType := mtGizmo;
  RebuildGeometry;
end;

procedure TGizmoMesh.RebuildGeometry;
var
  Vertices: TArray<TVertex>;
  Indices: TArray<GLuint>;
begin
  CreateGizmoVertices(Vertices, Indices, fShaftLength, fShaftRadius, fTipRadius,
    fTipLength, fSlices, fStacks);
  SetGeometry(Vertices, Indices, True);
end;

function TGizmoMesh.Clone: TMesh;
begin
  Result := TGizmoMesh.Create(fShaftLength, fShaftRadius, fTipRadius, fTipLength,
    fSlices, fStacks, fName + '_Clone', fStaticGeometry);
  CopyRenderStateTo(Result);
end;

procedure TGizmoMesh.SaveShapeData(Stream: TStream);
begin
  inherited SaveShapeData(Stream);
end;

{ TSuperEllipsoidMesh }
constructor TSuperEllipsoidMesh.Create(Radius, VCurve, HCurve: Single; Slices, Stacks: Integer;
  const aName: string; IsStatic: Boolean);
begin
  inherited Create(nil, nil, aName, mtSuperEllipsoid, IsStatic);
  fRadius := Radius;
  fVCurve := VCurve;
  fHCurve := HCurve;
  fSlices := System.Math.Max(3, Slices);
  fStacks := System.Math.Max(3, Stacks);
  RebuildGeometry;
end;


procedure TSuperEllipsoidMesh.SetRadius(const Value: Single);
begin
  if SameValue(fRadius, Value) then Exit;
  fRadius := Value;
  RebuildGeometry;
end;

procedure TSuperEllipsoidMesh.SetVCurve(const Value: Single);
begin
  if SameValue(fVCurve, Value) then Exit;
  fVCurve := Value;
  RebuildGeometry;
end;

procedure TSuperEllipsoidMesh.SetHCurve(const Value: Single);
begin
  if SameValue(fHCurve, Value) then Exit;
  fHCurve := Value;
  RebuildGeometry;
end;

procedure TSuperEllipsoidMesh.SetSlices(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := System.Math.Max(3, Value);
  if fSlices = NewValue then Exit;
  fSlices := NewValue;
  RebuildGeometry;
end;

procedure TSuperEllipsoidMesh.SetStacks(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := System.Math.Max(3, Value);
  if fStacks = NewValue then Exit;
  fStacks := NewValue;
  RebuildGeometry;
end;

procedure TSuperEllipsoidMesh.RebuildGeometry;
var
  Vertices: TArray<TVertex>;
  Indices: TArray<GLuint>;
begin
  CreateSuperellipsoidVertices(Vertices, Indices, fRadius, fVCurve, fHCurve, fSlices, fStacks);
  SetGeometry(Vertices, Indices, True);
end;

function TSuperEllipsoidMesh.Clone: TMesh;
begin
  Result := TSuperEllipsoidMesh.Create(fRadius, fVCurve, fHCurve, fSlices, fStacks,
    fName + '_Clone', fStaticGeometry);
  CopyRenderStateTo(Result);
end;

procedure TSuperEllipsoidMesh.SaveShapeData(Stream: TStream);
begin
  Stream.WriteBuffer(fRadius, SizeOf(fRadius));
  Stream.WriteBuffer(fVCurve, SizeOf(fVCurve));
  Stream.WriteBuffer(fHCurve, SizeOf(fHCurve));
  Stream.WriteBuffer(fSlices, SizeOf(fSlices));
  Stream.WriteBuffer(fStacks, SizeOf(fStacks));
end;

class function TMesh.LoadFromFile(const AFileName: string): TMesh;
var
  ext: string;
  Vertices: TArray<TVertex>;
  Indices: TArray<GLuint>;
  HasTangents: Boolean;
begin
  ext := LowerCase(ExtractFileExt(AFileName));
  if ext = '.obj' then
  begin
    LoadObjFromFile(AFileName, Vertices, Indices);
    Result := TFileMesh.Create(Vertices, Indices, ExtractFileName(AFileName), AFileName, True);
    Result.BuildTangentsAndBitangents; // OBJ never has tangents
  end
  else if (ext = '.gltf') or (ext = '.glb') then
  begin
    LoadGLTFFromFile(AFileName, Vertices, Indices);
    Result := TFileMesh.Create(Vertices, Indices, ExtractFileName(AFileName), AFileName, True);

    // Check if the loaded vertices have non-default tangents (e.g., not (1,0,0) and not zero)
    HasTangents := False;
    for var v in Vertices do
      if (Abs(v.Tangent.X - 1.0) > 1e-4) or (Abs(v.Tangent.Y) > 1e-4) or (Abs(v.Tangent.Z) > 1e-4) then
      begin
        HasTangents := True;
        Break;
      end;

    if not HasTangents then
      Result.BuildTangentsAndBitangents;
  end
  else
    raise Exception.Create('Unsupported file format: ' + ext);
end;

procedure TMesh.SaveToStream(Stream: TStream);
var
  MeshTypeValue: Integer;
  ShapeDataVersion: Integer;
  VertexCountValue: Integer;
  IndexCountValue: Integer;
begin
  WriteStringToStream(Stream, fName);
  MeshTypeValue := Ord(fMeshType);
  Stream.WriteBuffer(MeshTypeValue, SizeOf(MeshTypeValue));
  Stream.WriteBuffer(fStaticGeometry, SizeOf(fStaticGeometry));
  Stream.WriteBuffer(fVisible, SizeOf(fVisible));
  Stream.WriteBuffer(fAlwaysOnTop, SizeOf(fAlwaysOnTop));
  Stream.WriteBuffer(fTag, SizeOf(fTag));
  Stream.WriteBuffer(fWireFrame, SizeOf(fWireFrame));
  if fMaterialLibrary <> nil then
    WriteStringToStream(Stream, fMaterialLibrary.Name)
  else
    WriteStringToStream(Stream, fLibMaterialLibraryName);
  WriteStringToStream(Stream, fLibMaterialname);
  Stream.WriteBuffer(fParentModelMatrix, SizeOf(fParentModelMatrix));
  Stream.WriteBuffer(fBoundingBoxMin, SizeOf(fBoundingBoxMin));
  Stream.WriteBuffer(fBoundingBoxMax, SizeOf(fBoundingBoxMax));
  Stream.WriteBuffer(fPosition, SizeOf(fPosition));
  Stream.WriteBuffer(fRotation, SizeOf(fRotation));
  Stream.WriteBuffer(fScale, SizeOf(fScale));
  ShapeDataVersion := MESH_SHAPE_DATA_VERSION;
  Stream.WriteBuffer(ShapeDataVersion, SizeOf(ShapeDataVersion));
  SaveShapeData(Stream);

  VertexCountValue := Length(fVertices);
  Stream.WriteBuffer(VertexCountValue, SizeOf(VertexCountValue));
  if VertexCountValue > 0 then
    Stream.WriteBuffer(fVertices[0], VertexCountValue * SizeOf(TVertex));

  IndexCountValue := Length(fIndices);
  Stream.WriteBuffer(IndexCountValue, SizeOf(IndexCountValue));
  if IndexCountValue > 0 then
    Stream.WriteBuffer(fIndices[0], IndexCountValue * SizeOf(GLuint));
end;

class function TMesh.LoadFromStream(Stream: TStream; MeshListVersion: Integer): TMesh;
var
  SavedName: string;
  SavedMaterialLibraryName: string;
  SavedMaterialName: string;
  MeshTypeValue: Integer;
  SavedMeshType: TMeshType;
  SavedStaticGeometry: Boolean;
  SavedVisible: Boolean;
  SavedAlwaysOnTop: Boolean;
  SavedTag: Integer;
  SavedWireFrame: Boolean;
  SavedModelMatrix: TMatrix4;
  SavedBoundingBoxMin: TVector3;
  SavedBoundingBoxMax: TVector3;
  SavedPosition: TVector3;
  SavedRotation: TVector3;
  SavedScale: TVector3;
  VertexCountValue: Integer;
  IndexCountValue: Integer;
  LoadedVertices: TArray<TVertex>;
  LoadedIndices: TArray<GLuint>;
  ShapeDataVersion: Integer;

  procedure ValidateArrayCount(const ACount, AElementSize, AMaximum: Integer;
    const ADescription: string);
  var
    ByteCount: Int64;
  begin
    if (ACount < 0) or (ACount > AMaximum) then
      raise Exception.CreateFmt('Invalid %s in scene stream.', [ADescription]);
    ByteCount := Int64(ACount) * AElementSize;
    if ByteCount > Stream.Size - Stream.Position then
      raise Exception.CreateFmt('Truncated %s in scene stream.', [ADescription]);
  end;

  function ReadCap: TCapType;
  var
    CapValue: Integer;
  begin
    Stream.ReadBuffer(CapValue, SizeOf(CapValue));
    if (CapValue < Ord(Low(TCapType))) or (CapValue > Ord(High(TCapType))) then
      Result := ctNone
    else
      Result := TCapType(CapValue);
  end;

  function CreateMeshFromShapeData: TMesh;
  var
    SourceFile: string;
    Width, Height, Depth: Single;
    Radius, MajorRadius, MinorRadius: Single;
    BottomRadius, TopRadius: Single;
    ShaftLength, TipLength, ShaftRadius, TipRadius: Single;
    VCurve, HCurve: Single;
    MapHeightScale, MapUVScale: Single;
    ReflectionStrength, WaveScale, WaveSpeed, WaveStrength: Single;
    FresnelPower, Alpha: Single;
    TintColor, DeepColor: TVector4;
    A, B, C: Integer;
    HeightCount: Integer;
    HeightValues: TArray<Single>;
    BottomCap, TopCap: TCapType;
  begin
    Result := nil;
    Stream.ReadBuffer(ShapeDataVersion, SizeOf(ShapeDataVersion));

    case SavedMeshType of
      mtFile:
        begin
          SourceFile := ReadStringFromStream(Stream);
          Result := TFileMesh.Create(nil, nil, SavedName, SourceFile, SavedStaticGeometry);
        end;

      mtPlane:
        begin
          Stream.ReadBuffer(Width, SizeOf(Width));
          Stream.ReadBuffer(Depth, SizeOf(Depth));
          Stream.ReadBuffer(A, SizeOf(A));
          Stream.ReadBuffer(B, SizeOf(B));
          Result := TPlaneMesh.Create(Width, Depth, A, B, SavedName, SavedStaticGeometry);
        end;

      mtWater:
        begin
          Stream.ReadBuffer(Width, SizeOf(Width));
          Stream.ReadBuffer(Depth, SizeOf(Depth));
          Stream.ReadBuffer(A, SizeOf(A));
          Stream.ReadBuffer(B, SizeOf(B));
          Stream.ReadBuffer(TintColor, SizeOf(TintColor));
          Stream.ReadBuffer(DeepColor, SizeOf(DeepColor));
          Stream.ReadBuffer(ReflectionStrength, SizeOf(ReflectionStrength));
          Stream.ReadBuffer(WaveScale, SizeOf(WaveScale));
          Stream.ReadBuffer(WaveSpeed, SizeOf(WaveSpeed));
          Stream.ReadBuffer(WaveStrength, SizeOf(WaveStrength));
          Stream.ReadBuffer(FresnelPower, SizeOf(FresnelPower));
          Stream.ReadBuffer(Alpha, SizeOf(Alpha));
          Result := TWaterPlaneMesh.Create(Width, Depth, A, B, SavedName,
            SavedStaticGeometry);
          TWaterPlaneMesh(Result).TintColor := TintColor;
          TWaterPlaneMesh(Result).DeepColor := DeepColor;
          TWaterPlaneMesh(Result).ReflectionStrength := ReflectionStrength;
          TWaterPlaneMesh(Result).WaveScale := WaveScale;
          TWaterPlaneMesh(Result).WaveSpeed := WaveSpeed;
          TWaterPlaneMesh(Result).WaveStrength := WaveStrength;
          TWaterPlaneMesh(Result).FresnelPower := FresnelPower;
          TWaterPlaneMesh(Result).Alpha := Alpha;
        end;

      mtHeightField:
        begin
          Stream.ReadBuffer(Width, SizeOf(Width));
          Stream.ReadBuffer(Depth, SizeOf(Depth));
          Stream.ReadBuffer(MapHeightScale, SizeOf(MapHeightScale));
          Stream.ReadBuffer(MapUVScale, SizeOf(MapUVScale));
          Stream.ReadBuffer(A, SizeOf(A));
          Stream.ReadBuffer(B, SizeOf(B));
          Stream.ReadBuffer(HeightCount, SizeOf(HeightCount));
          ValidateArrayCount(HeightCount, SizeOf(Single), MAX_SERIALIZED_HEIGHT_SAMPLES,
            'heightfield sample count');
          SetLength(HeightValues, HeightCount);
          if HeightCount > 0 then
            Stream.ReadBuffer(HeightValues[0], HeightCount * SizeOf(Single));
          SourceFile := ReadStringFromStream(Stream);

          Result := THeightFieldMesh.Create(HeightValues, A, B, Width, Depth,
            MapHeightScale, MapUVScale, SavedName, SavedStaticGeometry);
          THeightFieldMesh(Result).fSourceFile := SourceFile;
        end;

      mtCube:
        begin
          Stream.ReadBuffer(Width, SizeOf(Width));
          Stream.ReadBuffer(Height, SizeOf(Height));
          Stream.ReadBuffer(Depth, SizeOf(Depth));
          Stream.ReadBuffer(A, SizeOf(A));
          Stream.ReadBuffer(B, SizeOf(B));
          Stream.ReadBuffer(C, SizeOf(C));
          Result := TCubeMesh.Create(Width, Height, Depth, A, B, C, SavedName, SavedStaticGeometry);
        end;

      mtSphere:
        begin
          Stream.ReadBuffer(Radius, SizeOf(Radius));
          Stream.ReadBuffer(A, SizeOf(A));
          Stream.ReadBuffer(B, SizeOf(B));
          Result := TSphereMesh.Create(Radius, A, B, SavedName, SavedStaticGeometry);
        end;

      mtCylinder:
        begin
          Stream.ReadBuffer(Radius, SizeOf(Radius));
          Stream.ReadBuffer(Height, SizeOf(Height));
          Stream.ReadBuffer(A, SizeOf(A));
          Stream.ReadBuffer(B, SizeOf(B));
          BottomCap := ReadCap;
          TopCap := ReadCap;
          Result := TCylinderMesh.Create(Radius, Height, A, B, SavedName, BottomCap, TopCap, SavedStaticGeometry);
        end;

      mtCapsule:
        begin
          Stream.ReadBuffer(Radius, SizeOf(Radius));
          Stream.ReadBuffer(Height, SizeOf(Height));
          Stream.ReadBuffer(A, SizeOf(A));
          Stream.ReadBuffer(B, SizeOf(B));
          Result := TCapsuleMesh.Create(Radius, Height, A, B, SavedName, SavedStaticGeometry);
        end;

      mtTorus:
        begin
          Stream.ReadBuffer(MajorRadius, SizeOf(MajorRadius));
          Stream.ReadBuffer(MinorRadius, SizeOf(MinorRadius));
          Stream.ReadBuffer(A, SizeOf(A));
          Stream.ReadBuffer(B, SizeOf(B));
          Result := TTorusMesh.Create(MajorRadius, MinorRadius, A, B, SavedName, SavedStaticGeometry);
        end;

      mtCone:
        begin
          Stream.ReadBuffer(Radius, SizeOf(Radius));
          Stream.ReadBuffer(Height, SizeOf(Height));
          Stream.ReadBuffer(A, SizeOf(A));
          Stream.ReadBuffer(B, SizeOf(B));
          BottomCap := ReadCap;
          Result := TConeMesh.Create(Radius, Height, A, B, SavedName, BottomCap, SavedStaticGeometry);
        end;

      mtPrism:
        begin
          Stream.ReadBuffer(Radius, SizeOf(Radius));
          Stream.ReadBuffer(Height, SizeOf(Height));
          Stream.ReadBuffer(A, SizeOf(A));
          Stream.ReadBuffer(B, SizeOf(B));
          Result := TPrismMesh.Create(Radius, Height, A, B, SavedName, SavedStaticGeometry);
        end;

      mtFrustum:
        begin
          Stream.ReadBuffer(BottomRadius, SizeOf(BottomRadius));
          Stream.ReadBuffer(TopRadius, SizeOf(TopRadius));
          Stream.ReadBuffer(Height, SizeOf(Height));
          Stream.ReadBuffer(A, SizeOf(A));
          Stream.ReadBuffer(B, SizeOf(B));
          BottomCap := ReadCap;
          TopCap := ReadCap;
          Result := TFrustumMesh.Create(BottomRadius, TopRadius, Height, A, B,
            BottomCap, TopCap, SavedName, SavedStaticGeometry);
        end;

      mtIcosphere:
        begin
          Stream.ReadBuffer(Radius, SizeOf(Radius));
          Stream.ReadBuffer(A, SizeOf(A));
          Result := TIcosphereMesh.Create(Radius, A, SavedName, SavedStaticGeometry);
        end;

      mtGeodesicDome:
        begin
          Stream.ReadBuffer(Radius, SizeOf(Radius));
          Stream.ReadBuffer(A, SizeOf(A));
          Result := TGeodesicDomeMesh.Create(Radius, A, SavedName, SavedStaticGeometry);
        end;

      mtGizmo:
        begin
          Stream.ReadBuffer(ShaftLength, SizeOf(ShaftLength));
          Stream.ReadBuffer(TipLength, SizeOf(TipLength));
          Stream.ReadBuffer(ShaftRadius, SizeOf(ShaftRadius));
          Stream.ReadBuffer(TipRadius, SizeOf(TipRadius));
          Stream.ReadBuffer(A, SizeOf(A));
          Stream.ReadBuffer(B, SizeOf(B));
          Result := TGizmoMesh.Create(ShaftLength, ShaftRadius, TipRadius, TipLength,
            A, B, SavedName, SavedStaticGeometry);
        end;

      mtArrow:
        begin
          Stream.ReadBuffer(ShaftLength, SizeOf(ShaftLength));
          Stream.ReadBuffer(TipLength, SizeOf(TipLength));
          Stream.ReadBuffer(ShaftRadius, SizeOf(ShaftRadius));
          Stream.ReadBuffer(TipRadius, SizeOf(TipRadius));
          Stream.ReadBuffer(A, SizeOf(A));
          Stream.ReadBuffer(B, SizeOf(B));
          Result := TArrowMesh.Create(ShaftLength, TipLength, ShaftRadius, TipRadius,
            A, B, SavedName, SavedStaticGeometry);
        end;

      mtSuperEllipsoid:
        begin
          Stream.ReadBuffer(Radius, SizeOf(Radius));
          Stream.ReadBuffer(VCurve, SizeOf(VCurve));
          Stream.ReadBuffer(HCurve, SizeOf(HCurve));
          Stream.ReadBuffer(A, SizeOf(A));
          Stream.ReadBuffer(B, SizeOf(B));
          Result := TSuperEllipsoidMesh.Create(Radius, VCurve, HCurve, A, B, SavedName, SavedStaticGeometry);
        end;
    end;

    if Result = nil then
      Result := TMesh.Create(nil, nil, SavedName, SavedMeshType, SavedStaticGeometry);
  end;
begin
  Result := nil;
  SavedName := ReadStringFromStream(Stream);
  Stream.ReadBuffer(MeshTypeValue, SizeOf(MeshTypeValue));
  if (MeshTypeValue < Ord(Low(TMeshType))) or (MeshTypeValue > Ord(High(TMeshType))) then
    raise Exception.Create('Invalid mesh type in scene stream.');
  SavedMeshType := TMeshType(MeshTypeValue);
  Stream.ReadBuffer(SavedStaticGeometry, SizeOf(SavedStaticGeometry));
  Stream.ReadBuffer(SavedVisible, SizeOf(SavedVisible));
  Stream.ReadBuffer(SavedAlwaysOnTop, SizeOf(SavedAlwaysOnTop));
  Stream.ReadBuffer(SavedTag, SizeOf(SavedTag));
  Stream.ReadBuffer(SavedWireFrame, SizeOf(SavedWireFrame));
  SavedMaterialLibraryName := '';
  if MeshListVersion >= 6 then
    SavedMaterialLibraryName := ReadStringFromStream(Stream);
  SavedMaterialName := ReadStringFromStream(Stream);
  Stream.ReadBuffer(SavedModelMatrix, SizeOf(SavedModelMatrix));
  Stream.ReadBuffer(SavedBoundingBoxMin, SizeOf(SavedBoundingBoxMin));
  Stream.ReadBuffer(SavedBoundingBoxMax, SizeOf(SavedBoundingBoxMax));
  SavedPosition := Vector3(0, 0, 0);
  SavedRotation := Vector3(0, 0, 0);
  SavedScale := Vector3(1, 1, 1);
  if MeshListVersion >= 5 then
  begin
    Stream.ReadBuffer(SavedPosition, SizeOf(SavedPosition));
    Stream.ReadBuffer(SavedRotation, SizeOf(SavedRotation));
    Stream.ReadBuffer(SavedScale, SizeOf(SavedScale));
  end;

  if MeshListVersion >= 2 then
    Result := CreateMeshFromShapeData;

  Stream.ReadBuffer(VertexCountValue, SizeOf(VertexCountValue));
  ValidateArrayCount(VertexCountValue, SizeOf(TVertex), MAX_SERIALIZED_VERTICES,
    'vertex count');
  SetLength(LoadedVertices, VertexCountValue);
  if VertexCountValue > 0 then
    Stream.ReadBuffer(LoadedVertices[0], VertexCountValue * SizeOf(TVertex));

  Stream.ReadBuffer(IndexCountValue, SizeOf(IndexCountValue));
  ValidateArrayCount(IndexCountValue, SizeOf(GLuint), MAX_SERIALIZED_INDICES,
    'index count');
  SetLength(LoadedIndices, IndexCountValue);
  if IndexCountValue > 0 then
    Stream.ReadBuffer(LoadedIndices[0], IndexCountValue * SizeOf(GLuint));

  if Result = nil then
  begin
    if SavedMeshType = mtFile then
      Result := TFileMesh.Create(LoadedVertices, LoadedIndices, SavedName, '', SavedStaticGeometry)
    else
      Result := TMesh.Create(LoadedVertices, LoadedIndices, SavedName, SavedMeshType, SavedStaticGeometry);
  end
  else
    Result.SetGeometry(LoadedVertices, LoadedIndices, False);

  Result.fVisible := SavedVisible;
  Result.fAlwaysOnTop := SavedAlwaysOnTop;
  Result.fTag := SavedTag;
  Result.fWireFrame := SavedWireFrame;
  Result.fLibMaterialLibraryName := SavedMaterialLibraryName;
  Result.fLibMaterialname := SavedMaterialName;
  Result.fPosition := SavedPosition;
  Result.fRotation := SavedRotation;
  Result.fScale := SavedScale;
  Result.fParentModelMatrix := SavedModelMatrix;
  Result.RebuildModelMatrix;
  Result.fBoundingBoxMin := SavedBoundingBoxMin;
  Result.fBoundingBoxMax := SavedBoundingBoxMax;
end;
procedure TMesh.ComputeBoundingBox;
var
  i: Integer;
  v: TVector3;
begin
  if Length(fVertices) = 0 then
  begin
    fBoundingBoxMin := Vector3(0,0,0);
    fBoundingBoxMax := Vector3(0,0,0);
    Exit;
  end;

  fBoundingBoxMin := fVertices[0].Position;
  fBoundingBoxMax := fVertices[0].Position;

  for i := 1 to Length(fVertices) - 1 do
  begin
    v := fVertices[i].Position;
    if v.X < fBoundingBoxMin.X then fBoundingBoxMin.X := v.X;
    if v.Y < fBoundingBoxMin.Y then fBoundingBoxMin.Y := v.Y;
    if v.Z < fBoundingBoxMin.Z then fBoundingBoxMin.Z := v.Z;
    if v.X > fBoundingBoxMax.X then fBoundingBoxMax.X := v.X;
    if v.Y > fBoundingBoxMax.Y then fBoundingBoxMax.Y := v.Y;
    if v.Z > fBoundingBoxMax.Z then fBoundingBoxMax.Z := v.Z;
  end;
end;

function TMesh.GetVertexCount: Integer;
begin
  Result := Length(fVertices);
end;

function TMesh.GetIndexCount: Integer;
begin
  Result := Length(fIndices);
end;

function TMesh.GetVerticesCount: Integer;
begin
  Result := Length(fVertices);
end;

procedure TMesh.Draw;
var
  Mat: TMaterial;
  Technique: TRenderTechnique;
  RenderState: TRenderTechniqueState;
  OldDepthFunc: GLint;
  OldDepthMask: GLboolean;

  function UsesHeightFieldMultiMaterialShader(AShader: TShader): Boolean;
  begin
    Result := Assigned(AShader) and
      (SameText(ChangeFileExt(ExtractFileName(AShader.VertexPath), ''),
          'HeightField_MultiMaterial') or
       SameText(ChangeFileExt(ExtractFileName(AShader.FragmentPath), ''),
          'HeightField_MultiMaterial'));
  end;
begin
  if not fVisible then Exit;
  if fMaterialLibrary = nil then Exit;
  if (fLibMaterialname = '') and (fMaterialLibrary.Count > 0) then
    fLibMaterialname := fMaterialLibrary.Material[0].Name;
  Mat := fMaterialLibrary.GetMaterial(fLibMaterialname);
  if (Mat = nil) or (Mat.Shader = nil) then Exit;

  case Mat.Materialtype of
    mtShadow:
      Technique := TShadowDepthTechnique.Create(Mat.Shader);
  else
    if (Mat.Materialtype = mtHeightFieldMaterial) or (fMeshType = mtHeightField) or
       UsesHeightFieldMultiMaterialShader(Mat.Shader) then
      Technique := THeightFieldMultiMaterialTechnique.Create(Mat.Shader)
    else
      Technique := TPBRRenderTechnique.Create(Mat.Shader);
  end;

  try
    RenderState := Technique.State;
    RenderState.CullFace := False;
    RenderState.Blend := True;
    Technique.State := RenderState;

    Technique.BeginTechnique;
    Technique.ApplyMaterial(Mat);
    Technique.ApplyObject(fModelMatrix);
    PrepareShader(Technique.Shader);
    if Self is THeightFieldMesh then
      Technique.Shader.SetUniform('terrainUVScale',
        GLfloat(THeightFieldMesh(Self).UVScale))
    else
      Technique.Shader.SetUniform('terrainUVScale', GLfloat(1.0));
    if Assigned(fOnRender) then fOnRender(Self, Technique.Shader);

    if fWireFrame then glPolygonMode(GL_FRONT_AND_BACK, GL_LINE)
                  else glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

    if fAlwaysOnTop then
    begin
      glGetIntegerv(GL_DEPTH_FUNC, @OldDepthFunc);
      glGetBooleanv(GL_DEPTH_WRITEMASK, @OldDepthMask);
      glDepthFunc(GL_ALWAYS);
      glDepthMask(GL_FALSE);
    end;
    try
      glBindVertexArray(fVAO);
      if fUseElements then
        glDrawElements(GL_TRIANGLES, Length(fIndices), GL_UNSIGNED_INT, nil)
      else
        glDrawArrays(GL_TRIANGLES, 0, Length(fVertices));
      glBindVertexArray(0);
    finally
      if fAlwaysOnTop then
      begin
        glDepthFunc(OldDepthFunc);
        glDepthMask(OldDepthMask);
      end;
      if fWireFrame then glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
    end;
  finally
    Technique.EndTechnique;
    Technique.Free;
  end;
end;

procedure TMesh.PrepareShader(AShader: TShader);
begin
  if AShader <> nil then
    AShader.SetUniform('useSkinning', GLint(0));
end;

procedure TMesh.DrawCulled(const AFrustumPlanes: TFrustumPlanes;
  AUseFrustum: Boolean);
begin
  if not AABBVisibleInFrustum(GetBoundingBox, fModelMatrix, AFrustumPlanes,
    AUseFrustum) then
    Exit;

  Draw;
end;

procedure TMesh.DrawGeometryOnly;
begin
  if not fVisible then Exit;

  glBindVertexArray(fVAO);
  try
    if fUseElements then
      glDrawElements(GL_TRIANGLES, Length(fIndices), GL_UNSIGNED_INT, nil)
    else
      glDrawArrays(GL_TRIANGLES, 0, Length(fVertices));
  finally
    glBindVertexArray(0);
  end;
end;

procedure TMesh.DrawGeometryOnlyCulled(const AFrustumPlanes: TFrustumPlanes;
  AUseFrustum: Boolean);
begin
  if not AABBVisibleInFrustum(GetBoundingBox, fModelMatrix, AFrustumPlanes,
    AUseFrustum) then
    Exit;

  DrawGeometryOnly;
end;

{ General Methods}
procedure ApplyMaterial(const Materials: Tarray<TMaterialTexture>; Shader: TShader);
  var
    i: Integer;
begin
  for i := 0 to Length(Materials) - 1 do
  begin
    if Materials[i].Texture.TexID <> 0 then
    begin
      glActiveTexture(GL_TEXTURE0 + i);
      glBindTexture(GL_TEXTURE_2D, Materials[i].Texture.TexID);
      Shader.SetUniform(Materials[i].Texture.Name, i);
    end;
  end;

end;

end.
