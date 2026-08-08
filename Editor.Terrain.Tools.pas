unit Editor.Terrain.Tools;

interface

uses
  System.SysUtils, dglOpenGL, Neslib.FastMath,
  Managers.Material, Renderer.Mesh;

const
  TERRAIN_PAINT_LAYER_COUNT = 5;
  TERRAIN_MASK_DEFAULT_RESOLUTION = 512;

type
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

  TTerrainEditTool = (
    tetAdd,
    tetSubtract,
    tetGrow,
    tetErode,
    tetSmooth,
    tetAverage,
    tetFlatten,
    tetZero,
    tetSeaLevel,
    tetTexturePaint
  );

  TTerrainBrushShape = (
    tbsCircle,
    tbsSquare
  );

  TTerrainBrushFalloff = (
    tbfSmooth,
    tbfLinear,
    tbfConstant
  );

  TTerrainMaskLayerState = record
    Valid: Boolean;
    Dirty: Boolean;
    Width: Integer;
    Height: Integer;
    TextureIndex: Integer;
    FileName: string;
    Pixels: TBytes;
  end;

  TTerrainEditState = record
    Active: Boolean;
    Painting: Boolean;
    HoverValid: Boolean;
    Tool: TTerrainEditTool;
    BrushShape: TTerrainBrushShape;
    Falloff: TTerrainBrushFalloff;
    Radius: Single;
    Strength: Single;
    TargetHeight: Single;
    SeaLevel: Single;
    TextureOpacity: Single;
    PaintLayer: Integer;
    PaintNormalize: Boolean;
    MaskResolution: Integer;
    MaskMaterial: TMaterial;
    MaskMesh: THeightFieldMesh;
    ExportMesh: THeightFieldMesh;
    ExportName: array[0..127] of AnsiChar;
    MaskLayers: array[0..TERRAIN_PAINT_LAYER_COUNT - 1] of TTerrainMaskLayerState;
    LastMouseX: Integer;
    LastMouseY: Integer;
    HitWorld: TVector3;
    HitLocal: TVector3;
    LastError: string;
  end;

implementation

end.
