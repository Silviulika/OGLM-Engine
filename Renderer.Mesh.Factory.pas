unit Renderer.Mesh.Factory;

interface

uses
  System.SysUtils, dglOpenGL, Neslib.FastMath, Renderer.Mesh, Engine.Types, Engine.Generators;

type
  TMeshFactory = class
  public
    class function CreateMesh(const Vertices: TArray<TVertex>; const Indices: TArray<GLuint>; aName: String;
      aMeshType: TMeshType; BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;

    class function CreatePlane(Width, Depth: Single; WidthSegments, DepthSegments: Integer; aName: String;
      BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
    class function CreateWaterPlane(Width, Depth: Single; WidthSegments,
      DepthSegments: Integer; aName: String;
      BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
    class function CreateHeightField(const Heights: TArray<Single>; HeightMapWidth,
      HeightMapDepth: Integer; Width, Depth, HeightScale, UVScale: Single;
      aName: String; BuildTangentsAndBitangents: Boolean = True;
      IsStatic: Boolean = True): TMesh;
    class function CreateHeightFieldFromFile(const AFileName: string; Width,
      Depth, HeightScale, UVScale: Single; aName: String;
      BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
    class function CreateCube(Width, Height, Depth: Single; WidthStacks, HeightStacks, DepthStacks: Integer; aName: String;
      BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
    class function CreateSphere(Radius: Single; StackCount, SliceCount: Integer; aName: String;
      BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
    class function CreateCylinder(Radius, Height: Single; Slices, Stacks: Integer; aName: String;
      BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
    class function CreateCapsule(Radius, Height: Single; Slices, Stacks: Integer; aName: String;
      BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
    class function CreateTorus(MajorRadius, MinorRadius: Single; MajorSegments, MinorSegments: Integer; aName: String;
      BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
    class function CreateCone(Radius, Height: Single; Sides, Stacks: Integer; aName: String;
      BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
    class function CreatePrism(Radius, Height: Single; Sides, Stacks: Integer; aName: String;
      BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
    class function CreateFrustum(BottomRadius, TopRadius, Height: Single; Slices, Stacks: Integer;
      BottomCap, TopCap: TCapType; aName: String;
      BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
    class function CreateIcosphere(Radius: Single; Subdivisions: Integer; aName: String;
      BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh; // fix this
    class function CreateGeodesicDome(Radius: Single; Subdivisions: Integer; aName: String;
      BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh; // fix this
    class function CreateGizmo(ArrowLength, ShaftRadius, TipRadius, TipLength: Single; Slices, Stacks: Integer; aName: String;
      BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
    class function CreateArrow(ShaftLength, TipLength, ShaftRadius, TipRadius: Single; Slices, Stacks: Integer; aName: String;
      BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
    class function CreateSuperellipsoid(Radius: Single; VCurve, HCurve: Single; Slices, Stacks: Integer; aName: String;
      BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
  end;

implementation

{ TMeshFactory }
class function TMeshFactory.CreateMesh(const Vertices: TArray<TVertex>; const Indices: TArray<GLuint>; aName: String;
  aMeshType: TMeshType; BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
begin
  if aMeshType = mtFile then
    Result := TFileMesh.Create(Vertices, Indices, aName, '', IsStatic)
  else
    Result := TMesh.Create(Vertices, Indices, aName, aMeshType, IsStatic);

  if BuildTangentsAndBitangents then
    Result.BuildTangentsAndBitangents;
end;

class function TMeshFactory.CreatePlane(Width, Depth: Single; WidthSegments, DepthSegments: Integer; aName: String;
  BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
begin
  Result := TPlaneMesh.Create(Width, Depth, WidthSegments, DepthSegments, aName, IsStatic);
  if BuildTangentsAndBitangents then
    Result.BuildTangentsAndBitangents;
end;

class function TMeshFactory.CreateWaterPlane(Width, Depth: Single;
  WidthSegments, DepthSegments: Integer; aName: String;
  BuildTangentsAndBitangents, IsStatic: Boolean): TMesh;
begin
  Result := TWaterPlaneMesh.Create(Width, Depth, WidthSegments, DepthSegments,
    aName, IsStatic);
  if BuildTangentsAndBitangents then
    Result.BuildTangentsAndBitangents;
end;

class function TMeshFactory.CreateHeightField(const Heights: TArray<Single>;
  HeightMapWidth, HeightMapDepth: Integer; Width, Depth, HeightScale,
  UVScale: Single; aName: String; BuildTangentsAndBitangents,
  IsStatic: Boolean): TMesh;
begin
  Result := THeightFieldMesh.Create(Heights, HeightMapWidth, HeightMapDepth,
    Width, Depth, HeightScale, UVScale, aName, IsStatic);
  if BuildTangentsAndBitangents then
    Result.BuildTangentsAndBitangents;
end;

class function TMeshFactory.CreateHeightFieldFromFile(const AFileName: string;
  Width, Depth, HeightScale, UVScale: Single; aName: String;
  BuildTangentsAndBitangents, IsStatic: Boolean): TMesh;
begin
  if not FileExists(AFileName) then Exit(nil);

  Result := THeightFieldMesh.FromBitmap(AFileName, Width, Depth, HeightScale,
    UVScale, aName, IsStatic);
  if BuildTangentsAndBitangents then
    Result.BuildTangentsAndBitangents;
end;

class function TMeshFactory.CreateCube(Width, Height, Depth: Single; WidthStacks, HeightStacks, DepthStacks: Integer; aName: String;
  BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
begin
  Result := TCubeMesh.Create(Width, Height, Depth, WidthStacks, HeightStacks, DepthStacks, aName, IsStatic);
  if BuildTangentsAndBitangents then
    Result.BuildTangentsAndBitangents;
end;

class function TMeshFactory.CreateSphere(Radius: Single; StackCount, SliceCount: Integer; aName: String;
  BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
begin
  Result := TSphereMesh.Create(Radius, StackCount, SliceCount, aName, IsStatic);
  if BuildTangentsAndBitangents then
    Result.BuildTangentsAndBitangents;
end;

class function TMeshFactory.CreateCylinder(Radius, Height: Single; Slices, Stacks: Integer; aName: String;
  BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
begin
  Result := TCylinderMesh.Create(Radius, Height, Slices, Stacks, aName, ctFlat, ctFlat, IsStatic);
  if BuildTangentsAndBitangents then
    Result.BuildTangentsAndBitangents;
end;

class function TMeshFactory.CreateCapsule(Radius, Height: Single; Slices, Stacks: Integer; aName: String;
  BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
begin
  Result := TCapsuleMesh.Create(Radius, Height, Slices, Stacks, aName, IsStatic);
  if BuildTangentsAndBitangents then
    Result.BuildTangentsAndBitangents;
end;

class function TMeshFactory.CreateTorus(MajorRadius, MinorRadius: Single; MajorSegments, MinorSegments: Integer; aName: String;
  BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
begin
  Result := TTorusMesh.Create(MajorRadius, MinorRadius, MajorSegments, MinorSegments, aName, IsStatic);
  if BuildTangentsAndBitangents then
    Result.BuildTangentsAndBitangents;
end;

class function TMeshFactory.CreateCone(Radius, Height: Single; Sides, Stacks: Integer; aName: String;
  BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
begin
  Result := TConeMesh.Create(Radius, Height, Sides, Stacks, aName, ctFlat, IsStatic);
  if BuildTangentsAndBitangents then
    Result.BuildTangentsAndBitangents;
end;

class function TMeshFactory.CreatePrism(Radius, Height: Single; Sides, Stacks: Integer; aName: String;
  BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
begin
  Result := TPrismMesh.Create(Radius, Height, Sides, Stacks, aName, IsStatic);
  if BuildTangentsAndBitangents then
    Result.BuildTangentsAndBitangents;
end;

class function TMeshFactory.CreateFrustum(BottomRadius, TopRadius, Height: Single; Slices, Stacks: Integer;
  BottomCap, TopCap: TCapType; aName: String;
  BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
begin
  Result := TFrustumMesh.Create(BottomRadius, TopRadius, Height, Slices, Stacks,
    BottomCap, TopCap, aName, IsStatic);
  if BuildTangentsAndBitangents then
    Result.BuildTangentsAndBitangents;
end;

class function TMeshFactory.CreateIcosphere(Radius: Single; Subdivisions: Integer; aName: String;
  BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
begin
  Result := TIcosphereMesh.Create(Radius, Subdivisions, aName, IsStatic);
  if BuildTangentsAndBitangents then
    Result.BuildTangentsAndBitangents;
end;

class function TMeshFactory.CreateGeodesicDome(Radius: Single; Subdivisions: Integer; aName: String;
  BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
begin
  Result := TGeodesicDomeMesh.Create(Radius, Subdivisions, aName, IsStatic);
  if BuildTangentsAndBitangents then
    Result.BuildTangentsAndBitangents;
end;

class function TMeshFactory.CreateGizmo(ArrowLength, ShaftRadius, TipRadius, TipLength: Single; Slices, Stacks: Integer; aName: String;
  BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
begin
  Result := TGizmoMesh.Create(ArrowLength, ShaftRadius, TipRadius, TipLength, Slices, Stacks, aName, IsStatic);
  if BuildTangentsAndBitangents then
    Result.BuildTangentsAndBitangents;
end;

class function TMeshFactory.CreateArrow(ShaftLength, TipLength, ShaftRadius, TipRadius: Single; Slices, Stacks: Integer; aName: String;
  BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
begin
  Result := TArrowMesh.Create(ShaftLength, TipLength, ShaftRadius, TipRadius, Slices, Stacks, aName, IsStatic);
  if BuildTangentsAndBitangents then
    Result.BuildTangentsAndBitangents;
end;

class function TMeshFactory.CreateSuperEllipsoid(Radius: Single; VCurve, HCurve: Single; Slices, Stacks: Integer; aName: String;
  BuildTangentsAndBitangents: Boolean = True; IsStatic: Boolean = True): TMesh;
begin
  Result := TSuperEllipsoidMesh.Create(Radius, VCurve, HCurve, Slices, Stacks, aName, IsStatic);
  if BuildTangentsAndBitangents then
    Result.BuildTangentsAndBitangents;
end;

end.
