unit Editor.Commands;

interface

uses
  Managers.Scene, Renderer.Mesh;

type
  TPrimitiveKind = (
    pkCube,
    pkPlane,
    pkGrass,
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
    PlaneCount: Integer;
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
    WaterFoamColor: array[0..3] of Single;
    WaterFoamIntensity: Single;
    WaterShoreFoamDistance: Single;
    WaterShoreFoamFeather: Single;
    WaterShoreLineSmoothness: Single;
    WaterFoamNoiseScale: Single;
    WaterCrestFoamThreshold: Single;
    WaterCrestFoamIntensity: Single;
    Position: array[0..2] of Single;
    RotationDeg: array[0..2] of Single;
    Scale: array[0..2] of Single;
    OriginalMesh: TMesh;
  end;

implementation

end.