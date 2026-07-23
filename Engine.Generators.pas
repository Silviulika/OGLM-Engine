unit Engine.Generators;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, dglOpenGL, Vcl.ExtCtrls, Vcl.StdCtrls, System.Math,
  System.Generics.Collections, System.Generics.Defaults,
  Engine.Types,
  Renderer.Shader, Managers.Material, Neslib.FastMath;

// -------------------------------------------------------------------------
/// <summary>Global texture seam fix for indexed meshes. Duplicates vertices at texture seams (U discontinuity)
///   so that the seam becomes invisible. Works on any indexed mesh with TVertex layout.</summary>
/// <param name="Vertices">Input/output array of vertices. May be expanded with seam copies.</param>
/// <param name="Indices">Input/output indices. Updated to reference new vertices at seams.</param>
/// <remarks>Uses a heuristic based on average U per triangle to detect crossing the 0/1 boundary.
///   Vertices near the seam are duplicated with U adjusted by +1 or -1.</remarks>
// -------------------------------------------------------------------------
procedure FixTextureSeam(var Vertices: TArray<TVertex>; var Indices: TArray<GLuint>);

//-------------------------------------------------------------------------------
/// <summary>Creates a subdivided plane mesh lying in the XZ plane (Y = 0).</summary>
/// <param name="Vertices">Output array of vertex structures (position, normal, texcoord, tangent, bitangent).</param>
/// <param name="Indices">Output array of triangle indices (GLuint) referencing vertices.</param>
/// <param name="Width">Total width of the plane along the X axis.</param>
/// <param name="Depth">Total depth of the plane along the Z axis.</param>
/// <param name="WidthSegments">Number of subdivisions along the X direction.</param>
/// <param name="DepthSegments">Number of subdivisions along the Z direction.</param>
/// <remarks>The plane is centered at the origin. Normals point upward (0,1,0).
///  UV coordinates range from (0,0) at the corner (-Width/2, -Depth/2) to (1,1)
///  at the corner (+Width/2, +Depth/2). Tangents and bitangents are set to zero vectors.</remarks>
//-------------------------------------------------------------------------------
procedure CreatePlaneVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Width, Depth: Single; WidthSegments, DepthSegments: Integer);

//-------------------------------------------------------------------------------
/// <summary>Creates a heightfield terrain mesh from a regular height sample grid.</summary>
/// <param name="Vertices">Output vertex array with positions, normals, UVs, tangents, and bitangents.</param>
/// <param name="Indices">Output triangle index array.</param>
/// <param name="Heights">Height samples in row-major order: Z row * HeightMapWidth + X column.</param>
/// <param name="HeightMapWidth">Number of samples along the X axis. Minimum 2.</param>
/// <param name="HeightMapDepth">Number of samples along the Z axis. Minimum 2.</param>
/// <param name="Width">World-space width along X.</param>
/// <param name="Depth">World-space depth along Z.</param>
/// <param name="HeightScale">Multiplier applied to stored height values.</param>
/// <param name="UVScale">Texture coordinate tiling multiplier over the whole heightfield.</param>
/// <remarks>The mesh is centered at the origin, lies on the XZ plane, and uses Y for height.
///  Normals are generated from neighboring sample slopes.</remarks>
//-------------------------------------------------------------------------------
procedure CreateHeightFieldVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  const Heights: TArray<Single>; HeightMapWidth, HeightMapDepth: Integer;
  Width, Depth, HeightScale, UVScale: Single);

//-------------------------------------------------------------------------------
/// <summary>Creates a subdivided cube mesh with individual faces and flat normals.</summary>
/// <param name="Vertices">Output array of vertex structures (position, normal, texcoord, tangent, bitangent).</param>
/// <param name="Indices">Output array of triangle indices (GLuint) referencing vertices.</param>
/// <param name="Width">Total width of the cube along the X axis.</param>
/// <param name="Height">Total height of the cube along the Y axis.</param>
/// <param name="Depth">Total depth of the cube along the Z axis.</param>
/// <param name="WidthStacks">Number of subdivisions along the X direction per face.</param>
/// <param name="HeightStacks">Number of subdivisions along the Y direction per face.</param>
/// <param name="DepthStacks">Number of subdivisions along the Z direction for the side faces.</param>
/// <remarks>The cube is centered at the origin. Each face is generated independently with hard edges.
///  UV coordinates range from (0,0) at bottom-left to (1,1) at top-right for each face.</remarks>
//-------------------------------------------------------------------------------
procedure CreateCubeVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Width, Height, Depth: Single; WidthStacks, HeightStacks, DepthStacks: Integer);

//-------------------------------------------------------------------------------
/// <summary>Creates a UV sphere (longitude/latitude style) with smooth normals.</summary>
/// <param name="Vertices">Output vertex array with positions, normals (radial), and UVs.</param>
/// <param name="Indices">Output triangle index array.</param>
/// <param name="Radius">Radius of the sphere.</param>
/// <param name="StackCount">Number of vertical divisions (stacks) from south pole to north pole.</param>
/// <param name="SliceCount">Number of horizontal divisions (slices) around the equator.</param>
/// <remarks>The sphere is centered at (0,0,0). UV coordinates:
///  U = longitude / (2PI), V = (latitude + PI/2) / PI. Normals are smooth and radial.</remarks>
//-------------------------------------------------------------------------------
procedure CreateSphereVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Radius: Single; StackCount, SliceCount: Integer);

//-------------------------------------------------------------------------------
/// <summary>Generates a cylinder with side walls and optional bottom/top caps.</summary>
/// <param name="Vertices">Output vertex data including normals for side and caps.</param>
/// <param name="Indices">Output index buffer for triangles.</param>
/// <param name="Radius">Radius of the cylinder.</param>
/// <param name="Height">Total height of the cylinder (extent from -Height/2 to +Height/2 on Y axis).</param>
/// <param name="Slices">Number of radial subdivisions (around the circumference).</param>
/// <param name="Stacks">Number of vertical subdivisions along the cylinder body.</param>
/// <param name="BottomCap">Cap style for the bottom opening (ctNone, ctCenter, ctFlat).</param>
/// <param name="TopCap">Cap style for the top opening.</param>
/// <remarks>The cylinder can be closed with triangle fans for the caps. Caps have flat normals pointing outward.
///  UV mapping: U runs around the side, V runs from bottom to top. Caps use radial UV mapping.</remarks>
//-------------------------------------------------------------------------------
procedure CreateCylinderVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Radius, Height: Single; Slices, Stacks: Integer; BottomCap: TCapType = ctFlat;
  TopCap: TCapType = ctFlat);

//-------------------------------------------------------------------------------
/// <summary>Creates a capsule mesh consisting of a cylindrical body and two hemispherical end caps.</summary>
/// <param name="Vertices">Output vertex array with positions, normals, and UVs.</param>
/// <param name="Indices">Output index array.</param>
/// <param name="Radius">Radius of the cylindrical body and hemispheres.</param>
/// <param name="Height">Height of the cylindrical part (excluding hemispheres). Total capsule height = Height + 2*Radius.</param>
/// <param name="Slices">Number of radial subdivisions around the Y axis.</param>
/// <param name="Stacks">Number of subdivisions along the cylinder height and also used for each hemisphere (from equator to pole).</param>
/// <remarks>The capsule is centered vertically. Normals are smooth across the cylinder�hemisphere transition.
/// UV mapping: U around the circumference, V from bottom pole to top pole.</remarks>
//-------------------------------------------------------------------------------
procedure CreateCapsuleVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Radius, Height: Single; Slices, Stacks: Integer);

//-------------------------------------------------------------------------------
/// <summary>Generates a torus (donut shape) with configurable major and minor radii.</summary>
/// <param name="Vertices">Output vertex data for the torus.</param>
/// <param name="Indices">Output index data.</param>
/// <param name="MajorRadius">Distance from the center of the torus to the center of the tube (ring radius).</param>
/// <param name="MinorRadius">Radius of the tube cross-section.</param>
/// <param name="MajorSegments">Number of subdivisions around the main ring (U direction).</param>
/// <param name="MinorSegments">Number of subdivisions around the tube cross-section (V direction).</param>
/// <remarks>The torus lies in the XY plane (vertical axis is Z). Normals point outward from the tube center.
/// UV mapping: U wraps around the major ring, V wraps around the tube.</remarks>
//-------------------------------------------------------------------------------
procedure CreateTorusVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  MajorRadius, MinorRadius: Single; MajorSegments, MinorSegments: Integer);

//-------------------------------------------------------------------------------
/// <summary>Constructs a cone with a pointed tip and a flat bottom cap.</summary>
/// <param name="Vertices">Output vertex array.</param>
/// <param name="Indices">Output index array.</param>
/// <param name="Radius">Base radius of the cone.</param>
/// <param name="Height">Total height of the cone (tip at +Height/2, base at -Height/2).</param>
/// <param name="Sides">Number of radial subdivisions (polygonal base).</param>
/// <param name="Stacks">Number of vertical subdivisions along the cone body.</param>
/// <remarks>The cone is centered at origin. The side uses smooth normals based on the slope,
///  the bottom cap is a triangle fan with downward normal. UV mapping: U around the base, V from base to tip.</remarks>
//-------------------------------------------------------------------------------
procedure CreateConeVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Radius, Height: Single; Sides, Stacks: Integer);

//-------------------------------------------------------------------------------
/// <summary>Creates a regular prism with a polygonal base and top, and vertical sides.</summary>
/// <param name="Vertices">Output vertex data for the prism.</param>
/// <param name="Indices">Output index data.</param>
/// <param name="Radius">Distance from the center to each corner of the polygon (circumradius).</param>
/// <param name="Height">Total height of the prism (extent from -Height/2 to +Height/2).</param>
/// <param name="Sides">Number of edges of the polygonal base (e.g., 4 for a square prism).</param>
/// <param name="Stacks">Number of vertical subdivisions along the prism height.</param>
/// <remarks>The prism has flat top and bottom caps (triangle fans). Side faces are quads per edge,
///  with normals radial to the prism axis. UV mapping: U around the perimeter, V along height.
///  Caps have simple planar UVs.</remarks>
//-------------------------------------------------------------------------------
procedure CreatePrismVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Radius, Height: Single; Sides, Stacks: Integer);

//-------------------------------------------------------------------------------
/// <summary>Creates a frustum (truncated pyramid/cone) mesh with optional caps.</summary>
/// <param name="Vertices">Output vertex array (position, normal, texcoord, tangent, bitangent).</param>
/// <param name="Indices">Output triangle index array.</param>
/// <param name="BottomRadius">Radius at the bottom (Y = -Height/2).</param>
/// <param name="TopRadius">Radius at the top (Y = +Height/2).</param>
/// <param name="Height">Total height of the frustum.</param>
/// <param name="Slices">Number of radial subdivisions around the Y axis.</param>
/// <param name="Stacks">Number of vertical subdivisions along the height.</param>
/// <param name="BottomCap">Cap style for the bottom opening (ctNone, ctCenter, ctFlat).</param>
/// <param name="TopCap">Cap style for the top opening.</param>
/// <remarks>The frustum is centered at the origin. Side normals are correctly computed
///   from the slope. Caps, when enabled, are generated as triangle fans with flat normals.
///   UV mapping: U wraps around the circumference, V goes from bottom (0) to top (1).</remarks>
//-------------------------------------------------------------------------------
procedure CreateFrustumVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  BottomRadius, TopRadius, Height: Single; Slices, Stacks: Integer; BottomCap, TopCap: TCapType);

//-------------------------------------------------------------------------------
/// <summary>Creates an icosphere (subdivided icosahedron).</summary>
/// <param name="Vertices">Output array of vertex structures (position, normal, texcoord, tangent, bitangent).</param>
/// <param name="Indices">Output array of triangle indices (GLuint) referencing vertices.</param>
/// <param name="Radius">Radius of the sphere.</param>
/// <param name="Subdivisions">Number of subdivision iterations. Each subdivision quadruples the triangle count.</param>
/// <remarks>The icosphere starts from an icosahedron and subdivides each triangle edge, normalizing vertices to the sphere surface.
///  This produces a more even triangle distribution than a UV sphere. Normals are smooth. UV coordinates are computed
///  spherically (U = atan2(z,x)/2PI+0.5, V = asin(y/R)/PI+0.5). The mesh is watertight and seam?fixed.</remarks>
//-------------------------------------------------------------------------------
procedure CreateIcosphereVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Radius: Single; Subdivisions: Integer);

//-------------------------------------------------------------------------------
/// <summary>Generates a geodesic dome (half icosphere) with a flat bottom cap.</summary>
/// <param name="Vertices">Output vertex array with positions, normals, and UVs for the dome and its flat cap.</param>
/// <param name="Indices">Output index array.</param>
/// <param name="Radius">Radius of the dome.</param>
/// <param name="Subdivisions">Number of subdivision iterations for the underlying icosphere.</param>
/// <remarks>This procedure creates a hemisphere using <c>CreateIcosphereVertices</c> with hemisphere clipping,
///  then adds a triangle fan to close the bottom opening. The bottom cap vertices are flattened to the lowest Y
///  coordinate (the equator) and have a downward normal (0,-1,0). UVs for the cap are projected from the XZ plane.
///  The result is a closed, watertight geodesic dome suitable for terrain, planetarium domes, or architectural elements.</remarks>
//-------------------------------------------------------------------------------
procedure CreateGeodesicDomeVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Radius: Single; Subdivisions: Integer);

//-------------------------------------------------------------------------------
/// <summary>Creates a gizmo (3?axis translation widget) with a central sphere and three arrows.</summary>
/// <param name="Vertices">Output vertex array for the complete gizmo mesh.</param>
/// <param name="Indices">Output index array.</param>
/// <param name="ArrowLength">Total length from center to arrow tip.</param>
/// <param name="ShaftRadius">Radius of the cylindrical shaft of each arrow.</param>
/// <param name="TipRadius">Radius at the base of the cone tip (usually > ShaftRadius).</param>
/// <param name="TipLength">Length of the conical tip.</param>
/// <param name="Slices">Radial subdivisions (around each axis).</param>
/// <param name="Stacks">Axial subdivisions for cylinder/cone and sphere resolution.</param>
/// <remarks>The central sphere radius is automatically set to 1.5 � ShaftRadius for a balanced appearance.
///  Each arrow is generated along the positive X, Y, and Z axes. Normals are correctly generated for all parts.</remarks>
//-------------------------------------------------------------------------------
procedure CreateGizmoVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  ArrowLength, ShaftRadius, TipRadius, TipLength: Single; Slices, Stacks: Integer);

//-------------------------------------------------------------------------------
/// <summary>Generates a single arrow (cylinder shaft + cone tip) as an indexed mesh.</summary>
/// <param name="Vertices">Output vertex array for the arrow.</param>
/// <param name="Indices">Output index array.</param>
/// <param name="ShaftLength">Length of the cylindrical part.</param>
/// <param name="TipLength">Length of the conical tip.</param>
/// <param name="ShaftRadius">Radius of the cylinder.</param>
/// <param name="TipRadius">Radius at the base of the cone (usually larger than ShaftRadius).</param>
/// <param name="Slices">Radial subdivisions around the Y axis.</param>
/// <param name="Stacks">Axial subdivisions for both cylinder and cone.</param>
/// <remarks>The arrow points upward (positive Y). Base at Y = 0, tip at Y = ShaftLength + TipLength.
///  The mesh includes cylinder side, cylinder bottom cap, cylinder top cap, cone side, and cone base cap.</remarks>
//-------------------------------------------------------------------------------
procedure CreateArrowVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  ShaftLength, TipLength, ShaftRadius, TipRadius: Single; Slices, Stacks: Integer);

//-------------------------------------------------------------------------------
/// <summary>Generates a superellipsoid mesh with independent horizontal and vertical "roundness".</summary>
/// <param name="Vertices">Output vertex array (position, normal, texcoord, tangent, bitangent).</param>
/// <param name="Indices">Output triangle index array.</param>
/// <param name="Radius">Overall radius of the superellipsoid.</param>
/// <param name="VCurve">Vertical roundness (1.0 = sphere, <1 = pinch, >1 = square).</param>
/// <param name="HCurve">Horizontal roundness (1.0 = sphere, <1 = star?like, >1 = blocky).</param>
/// <param name="Slices">Number of horizontal subdivisions (around Y axis).</param>
/// <param name="Stacks">Number of vertical subdivisions (from bottom to top).</param>
/// <remarks>The shape is defined by: x = r * cos(phi)^V * cos(theta)^H,
///                                    y = r * sin(phi)^V,
///                                    z = r * cos(phi)^V * sin(theta)^H,
///  with phi in [-pi/2, pi/2] and theta in [0, 2pi].
///  Normals are radial (pointing outward from origin). UVs: U = theta/(2pi), V = (phi+pi/2)/pi.</remarks>
//-------------------------------------------------------------------------------
procedure CreateSuperEllipsoidVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Radius: Single; VCurve, HCurve: Single; Slices, Stacks: Integer);

//-------------------------------------------------------------------------------
/// <summary>Generates a superellipsoid mesh with angular limits and optional caps.</summary>
/// <param name="Vertices">Output vertex array.</param>
/// <param name="Indices">Output triangle index array.</param>
/// <param name="Radius">Overall radius.</param>
/// <param name="VCurve">Vertical roundness (0..INFINITY).</param>
/// <param name="HCurve">Horizontal roundness (0..INFINITY).</param>
/// <param name="Slices">Horizontal subdivisions (around Y axis).</param>
/// <param name="Stacks">Vertical subdivisions (from bottom to top).</param>
/// <param name="TopAngle">Top cut angle in degrees (max 90).</param>
/// <param name="BottomAngle">Bottom cut angle in degrees (min -90).</param>
/// <param name="StartAngle">Start longitude angle in degrees (0..360).</param>
/// <param name="StopAngle">Stop longitude angle in degrees (0..360).</param>
/// <param name="TopCap">Type of cap at the top cut.</param>
/// <param name="BottomCap">Type of cap at the bottom cut.</param>
/// <remarks>The shape is defined in spherical coordinates (phi = vertical, theta = horizontal).
///  Phi ranges from BottomAngle to TopAngle, theta from StartAngle to StopAngle.
///  UV mapping: U = (theta - StartAngle)/(StopAngle - StartAngle), V = (phi - BottomAngle)/(TopAngle - BottomAngle).
///  Normals are radial from the origin.</remarks>
//-------------------------------------------------------------------------------
procedure CreateSuperEllipsoidOpenedVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Radius, VCurve, HCurve: Single; Slices, Stacks: Integer;
  TopAngle, BottomAngle: Single; StartAngle, StopAngle: Single;
  TopCap, BottomCap: TCapType);

implementation

// -----------------------------------------------------------------------------
// FixTextureSeam: global seam correction for indexed meshes.
// -----------------------------------------------------------------------------
procedure FixTextureSeam(var Vertices: TArray<TVertex>; var Indices: TArray<GLuint>);
var
  NewVertices: TList<TVertex>;
  NewIndices: TList<GLuint>;
  Cache: TDictionary<TVertexKey, Integer>;

  function GetVertexKey(const V: TVertex; UAdj: Single): TVertexKey;
  begin
    Result.Pos := V.Position;
    Result.Norm := V.Normal;
    Result.UAdj := UAdj;
  end;

  function AddVertex(const V: TVertex; UAdj: Single): Integer;
  var
    key: TVertexKey;
    newV: TVertex;
  begin
    key := GetVertexKey(V, UAdj);
    if not Cache.TryGetValue(key, Result) then
    begin
      newV := V;
      newV.TexCoord.X := UAdj;
      Result := NewVertices.Count;
      NewVertices.Add(newV);
      Cache.Add(key, Result);
    end;
  end;

var
  iTri, k: Integer;
  tri: array[0..2] of TVertex;
  uOrig: array[0..2] of Single;
  avgU: Single;
  uAdj: array[0..2] of Single;
  triLocalIdx: array[0..2] of Integer;
begin
  NewVertices := TList<TVertex>.Create;
  NewIndices := TList<GLuint>.Create;
  Cache := TDictionary<TVertexKey, Integer>.Create;
  try
    for iTri := 0 to (Length(Indices) div 3) - 1 do
    begin
      for k := 0 to 2 do
        tri[k] := Vertices[Indices[iTri*3 + k]];
      for k := 0 to 2 do
        uOrig[k] := tri[k].TexCoord.X;

      avgU := (uOrig[0] + uOrig[1] + uOrig[2]) / 3.0;

      for k := 0 to 2 do
      begin
        if avgU > 0.5 then
        begin
          if uOrig[k] < 0.25 then
            uAdj[k] := uOrig[k] + 1.0
          else
            uAdj[k] := uOrig[k];
        end
        else
        begin
          if uOrig[k] > 0.75 then
            uAdj[k] := uOrig[k] - 1.0
          else
            uAdj[k] := uOrig[k];
        end;
      end;

      for k := 0 to 2 do
        triLocalIdx[k] := AddVertex(tri[k], uAdj[k]);

      NewIndices.Add(triLocalIdx[0]);
      NewIndices.Add(triLocalIdx[1]);
      NewIndices.Add(triLocalIdx[2]);
    end;

    Vertices := NewVertices.ToArray;
    Indices := NewIndices.ToArray;
  finally
    NewVertices.Free;
    NewIndices.Free;
    Cache.Free;
  end;
end;

// -----------------------------------------------------------------------------
// TVertexBuilder: helper record to accumulate vertices and indices efficiently.
// -----------------------------------------------------------------------------
type
  TVertexBuilder = record
    Vertices: TList<TVertex>;
    Indices: TList<GLuint>;
    function AddVertex(const V: TVertex): Integer;
    procedure AddTriangle(i1, i2, i3: Integer);
  end;

function TVertexBuilder.AddVertex(const V: TVertex): Integer;
begin
  Result := Vertices.Count;
  Vertices.Add(V);
end;

procedure TVertexBuilder.AddTriangle(i1, i2, i3: Integer);
begin
  Indices.Add(i1);
  Indices.Add(i2);
  Indices.Add(i3);
end;

// -----------------------------------------------------------------------------
// Helper: builds a sorted edge key from two vertex indices.
// -----------------------------------------------------------------------------
function EdgeKey(a, b: Integer): TEdgeKey;
begin
  if a < b then
  begin
    Result.Min := a;
    Result.Max := b;
  end
  else
  begin
    Result.Min := b;
    Result.Max := a;
  end;
end;

// -----------------------------------------------------------------------------
// CreatePlaneVertices: generates a subdivided plane in the XZ plane.
// -----------------------------------------------------------------------------
procedure CreatePlaneVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Width, Depth: Single; WidthSegments, DepthSegments: Integer);
var
  Builder: TVertexBuilder;
  x, z: Integer;
  xPos, zPos: Single;
  stepX, stepZ: Single;
  halfW, halfD: Single;
  vert: TVertex;
  idx00, idx01, idx10, idx11: Integer;
begin
  Builder.Vertices := TList<TVertex>.Create;
  Builder.Indices := TList<GLuint>.Create;
  try
    halfW := Width * 0.5;
    halfD := Depth * 0.5;
    stepX := Width / WidthSegments;
    stepZ := Depth / DepthSegments;

    // Generate vertices
    for z := 0 to DepthSegments do
    begin
      zPos := -halfD + z * stepZ;
      for x := 0 to WidthSegments do
      begin
        xPos := -halfW + x * stepX;

        vert.Position := Vector3(xPos, 0.0, zPos);
        vert.Normal   := Vector3(0.0, 1.0, 0.0);
        vert.TexCoord := Vector2(x * Width / WidthSegments, z * Depth / DepthSegments);
        vert.Tangent  := Vector3(0.0, 0.0, 0.0);
        vert.Bitangent := Vector3(0.0, 0.0, 0.0);
        Builder.AddVertex(vert);
      end;
    end;

    // Generate indices (two triangles per grid cell)
    for z := 0 to DepthSegments - 1 do
      for x := 0 to WidthSegments - 1 do
      begin
        idx00 := z * (WidthSegments + 1) + x;            // bottom-left
        idx01 := z * (WidthSegments + 1) + (x + 1);      // bottom-right
        idx10 := (z + 1) * (WidthSegments + 1) + x;      // top-left
        idx11 := (z + 1) * (WidthSegments + 1) + (x + 1);// top-right

        // First triangle: bottom-left, top-left, top-right
        Builder.AddTriangle(idx00, idx10, idx11);
        // Second triangle: bottom-left, top-right, bottom-right
        Builder.AddTriangle(idx00, idx11, idx01);
      end;

    Vertices := Builder.Vertices.ToArray;
    Indices := Builder.Indices.ToArray;
  finally
    Builder.Vertices.Free;
    Builder.Indices.Free;
  end;
end;

// -----------------------------------------------------------------------------
// CreateHeightFieldVertices: generates a sampled terrain in the XZ plane.
// -----------------------------------------------------------------------------
procedure CreateHeightFieldVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  const Heights: TArray<Single>; HeightMapWidth, HeightMapDepth: Integer;
  Width, Depth, HeightScale, UVScale: Single);
var
  x, z: Integer;
  VertexIndex: Integer;
  IndexOffset: Integer;
  VertexCount64: Int64;
  IndexCount64: Int64;
  HalfWidth, HalfDepth: Single;
  StepX, StepZ: Single;
  XPos, ZPos: Single;
  idx00, idx01, idx10, idx11: GLuint;
  Vert: TVertex;

  function ClampInt(Value, MinValue, MaxValue: Integer): Integer;
  begin
    if Value < MinValue then
      Result := MinValue
    else if Value > MaxValue then
      Result := MaxValue
    else
      Result := Value;
  end;

  function SampleHeight(SampleX, SampleZ: Integer): Single;
  begin
    SampleX := ClampInt(SampleX, 0, HeightMapWidth - 1);
    SampleZ := ClampInt(SampleZ, 0, HeightMapDepth - 1);
    Result := Heights[SampleZ * HeightMapWidth + SampleX] * HeightScale;
  end;

  function CrossProduct(const A, B: TVector3): TVector3;
  begin
    Result := Vector3(
      A.Y * B.Z - A.Z * B.Y,
      A.Z * B.X - A.X * B.Z,
      A.X * B.Y - A.Y * B.X
    );
  end;

  function NormalizeVector(const Value: TVector3): TVector3;
  var
    Len: Single;
  begin
    Len := Sqrt(Value.X * Value.X + Value.Y * Value.Y + Value.Z * Value.Z);
    if Len > 1e-6 then
      Result := Vector3(Value.X / Len, Value.Y / Len, Value.Z / Len)
    else
      Result := Vector3(0.0, 1.0, 0.0);
  end;

  function SampleNormal(SampleX, SampleZ: Integer): TVector3;
  var
    LeftH, RightH, DownH, UpH: Single;
    Dx, Dz: TVector3;
  begin
    LeftH := SampleHeight(SampleX - 1, SampleZ);
    RightH := SampleHeight(SampleX + 1, SampleZ);
    DownH := SampleHeight(SampleX, SampleZ - 1);
    UpH := SampleHeight(SampleX, SampleZ + 1);

    Dx := Vector3(2.0 * StepX, RightH - LeftH, 0.0);
    Dz := Vector3(0.0, UpH - DownH, 2.0 * StepZ);
    Result := NormalizeVector(CrossProduct(Dz, Dx));
  end;
begin
  SetLength(Vertices, 0);
  SetLength(Indices, 0);

  if (HeightMapWidth < 2) or (HeightMapDepth < 2) then
    Exit;

  VertexCount64 := Int64(HeightMapWidth) * Int64(HeightMapDepth);
  IndexCount64 := Int64(HeightMapWidth - 1) * Int64(HeightMapDepth - 1) * 6;

  if (VertexCount64 > MaxInt) or (IndexCount64 > MaxInt) or
     (Length(Heights) < VertexCount64) then
    Exit;

  if SameValue(Width, 0.0) then
    Width := 1.0;
  if SameValue(Depth, 0.0) then
    Depth := 1.0;

  HalfWidth := Width * 0.5;
  HalfDepth := Depth * 0.5;
  StepX := Width / (HeightMapWidth - 1);
  StepZ := Depth / (HeightMapDepth - 1);

  SetLength(Vertices, Integer(VertexCount64));
  SetLength(Indices, Integer(IndexCount64));

  VertexIndex := 0;
  for z := 0 to HeightMapDepth - 1 do
  begin
    ZPos := -HalfDepth + z * StepZ;
    for x := 0 to HeightMapWidth - 1 do
    begin
      XPos := -HalfWidth + x * StepX;

      Vert.Position := Vector3(XPos, SampleHeight(x, z), ZPos);
      Vert.Normal := SampleNormal(x, z);
      Vert.Tangent := Vector3(1.0, 0.0, 0.0);
      Vert.Bitangent := Vector3(0.0, 0.0, 1.0);
      Vert.TexCoord := Vector2(
        (x / (HeightMapWidth - 1)) * UVScale,
        (z / (HeightMapDepth - 1)) * UVScale
      );

      Vertices[VertexIndex] := Vert;
      Inc(VertexIndex);
    end;
  end;

  IndexOffset := 0;
  for z := 0 to HeightMapDepth - 2 do
    for x := 0 to HeightMapWidth - 2 do
    begin
      idx00 := GLuint(z * HeightMapWidth + x);
      idx01 := GLuint(z * HeightMapWidth + x + 1);
      idx10 := GLuint((z + 1) * HeightMapWidth + x);
      idx11 := GLuint((z + 1) * HeightMapWidth + x + 1);

      Indices[IndexOffset] := idx00; Inc(IndexOffset);
      Indices[IndexOffset] := idx10; Inc(IndexOffset);
      Indices[IndexOffset] := idx11; Inc(IndexOffset);

      Indices[IndexOffset] := idx00; Inc(IndexOffset);
      Indices[IndexOffset] := idx11; Inc(IndexOffset);
      Indices[IndexOffset] := idx01; Inc(IndexOffset);
    end;
end;

// -----------------------------------------------------------------------------
// CreateCubeVertices: generates a subdivided cube with individual faces.
// -----------------------------------------------------------------------------
procedure CreateCubeVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Width, Height, Depth: Single; WidthStacks, HeightStacks, DepthStacks: Integer);
var
  Builder: TVertexBuilder;
  left, right, bottom, top, front, back: Single;
  i, j: Integer;
  v0, v1, v2, v3: TVertex;
  idx0, idx1, idx2, idx3: Integer;
begin
  Builder.Vertices := TList<TVertex>.Create;
  Builder.Indices := TList<GLuint>.Create;
  try
    left   := -Width / 2;
    right  :=  Width / 2;
    bottom := -Height / 2;
    top    :=  Height / 2;
    front  :=  Depth / 2;
    back   := -Depth / 2;

    // ------------------- Front Face (Z = +front) -------------------
    for i := 0 to WidthStacks - 1 do
      for j := 0 to HeightStacks - 1 do
      begin
        // bottom-left
        v0.Position := Vector3(left + i * Width / WidthStacks, bottom + j * Height / HeightStacks, front);
        v0.Normal := Vector3(0, 0, 1);
        v0.TexCoord := Vector2((WidthStacks - i) * Width / WidthStacks, j * Height / HeightStacks);
        v0.Tangent := Vector3(0,0,0);
        v0.Bitangent := Vector3(0,0,0);
        idx0 := Builder.AddVertex(v0);

        // bottom-right
        v1.Position := Vector3(left + (i+1) * Width / WidthStacks, bottom + j * Height / HeightStacks, front);
        v1.Normal := Vector3(0, 0, 1);
        v1.TexCoord := Vector2((WidthStacks - (i+1)) * Width / WidthStacks, j * Height / HeightStacks);
        v1.Tangent := Vector3(0,0,0);
        v1.Bitangent := Vector3(0,0,0);
        idx1 := Builder.AddVertex(v1);

        // top-right
        v2.Position := Vector3(left + (i+1) * Width / WidthStacks, bottom + (j+1) * Height / HeightStacks, front);
        v2.Normal := Vector3(0, 0, 1);
        v2.TexCoord := Vector2((WidthStacks - (i+1)) * Width / WidthStacks, (j+1) * Height / HeightStacks);
        v2.Tangent := Vector3(0,0,0);
        v2.Bitangent := Vector3(0,0,0);
        idx2 := Builder.AddVertex(v2);

        // top-left
        v3.Position := Vector3(left + i * Width / WidthStacks, bottom + (j+1) * Height / HeightStacks, front);
        v3.Normal := Vector3(0, 0, 1);
        v3.TexCoord := Vector2((WidthStacks - i) * Width / WidthStacks, (j+1) * Height / HeightStacks);
        v3.Tangent := Vector3(0,0,0);
        v3.Bitangent := Vector3(0,0,0);
        idx3 := Builder.AddVertex(v3);

        Builder.AddTriangle(idx0, idx1, idx2);
        Builder.AddTriangle(idx0, idx2, idx3);
      end;

    // ------------------- Back Face (Z = back) -------------------
    for i := 0 to WidthStacks - 1 do
      for j := 0 to HeightStacks - 1 do
      begin
        v0.Position := Vector3(left + i * Width / WidthStacks, bottom + j * Height / HeightStacks, back);
        v0.Normal := Vector3(0, 0, -1);
        v0.TexCoord := Vector2(i * Width / WidthStacks, j * Height / HeightStacks);
        v0.Tangent := Vector3(0,0,0);
        v0.Bitangent := Vector3(0,0,0);
        idx0 := Builder.AddVertex(v0);

        v1.Position := Vector3(left + (i+1) * Width / WidthStacks, bottom + j * Height / HeightStacks, back);
        v1.Normal := Vector3(0, 0, -1);
        v1.TexCoord := Vector2((i+1) * Width / WidthStacks, j * Height / HeightStacks);
        v1.Tangent := Vector3(0,0,0);
        v1.Bitangent := Vector3(0,0,0);
        idx1 := Builder.AddVertex(v1);

        v2.Position := Vector3(left + (i+1) * Width / WidthStacks, bottom + (j+1) * Height / HeightStacks, back);
        v2.Normal := Vector3(0, 0, -1);
        v2.TexCoord := Vector2((i+1) * Width / WidthStacks, (j+1) * Height / HeightStacks);
        v2.Tangent := Vector3(0,0,0);
        v2.Bitangent := Vector3(0,0,0);
        idx2 := Builder.AddVertex(v2);

        v3.Position := Vector3(left + i * Width / WidthStacks, bottom + (j+1) * Height / HeightStacks, back);
        v3.Normal := Vector3(0, 0, -1);
        v3.TexCoord := Vector2(i * Width / WidthStacks, (j+1) * Height / HeightStacks);
        v3.Tangent := Vector3(0,0,0);
        v3.Bitangent := Vector3(0,0,0);
        idx3 := Builder.AddVertex(v3);

        // Reverse winding for outward facing
        Builder.AddTriangle(idx1, idx0, idx3);
        Builder.AddTriangle(idx1, idx3, idx2);
      end;

    // ------------------- Right Face (X = right) -------------------
    for i := 0 to DepthStacks - 1 do
      for j := 0 to HeightStacks - 1 do
      begin
        v0.Position := Vector3(right, bottom + j * Height / HeightStacks, back + i * Depth / DepthStacks);
        v0.Normal := Vector3(1, 0, 0);
        v0.TexCoord := Vector2(i * Depth / DepthStacks, j * Height / HeightStacks);
        v0.Tangent := Vector3(0,0,0);
        v0.Bitangent := Vector3(0,0,0);
        idx0 := Builder.AddVertex(v0);

        v1.Position := Vector3(right, bottom + j * Height / HeightStacks, back + (i+1) * Depth / DepthStacks);
        v1.Normal := Vector3(1, 0, 0);
        v1.TexCoord := Vector2((i+1) * Depth / DepthStacks, j * Height / HeightStacks);
        v1.Tangent := Vector3(0,0,0);
        v1.Bitangent := Vector3(0,0,0);
        idx1 := Builder.AddVertex(v1);

        v2.Position := Vector3(right, bottom + (j+1) * Height / HeightStacks, back + (i+1) * Depth / DepthStacks);
        v2.Normal := Vector3(1, 0, 0);
        v2.TexCoord := Vector2((i+1) * Depth / DepthStacks, (j+1) * Height / HeightStacks);
        v2.Tangent := Vector3(0,0,0);
        v2.Bitangent := Vector3(0,0,0);
        idx2 := Builder.AddVertex(v2);

        v3.Position := Vector3(right, bottom + (j+1) * Height / HeightStacks, back + i * Depth / DepthStacks);
        v3.Normal := Vector3(1, 0, 0);
        v3.TexCoord := Vector2(i * Depth / DepthStacks, (j+1) * Height / HeightStacks);
        v3.Tangent := Vector3(0,0,0);
        v3.Bitangent := Vector3(0,0,0);
        idx3 := Builder.AddVertex(v3);

        Builder.AddTriangle(idx0, idx1, idx2);
        Builder.AddTriangle(idx0, idx2, idx3);
      end;

    // ------------------- Left Face (X = left) -------------------
    for i := 0 to DepthStacks - 1 do
      for j := 0 to HeightStacks - 1 do
      begin
        v0.Position := Vector3(left, bottom + j * Height / HeightStacks, back + i * Depth / DepthStacks);
        v0.Normal := Vector3(-1, 0, 0);
        v0.TexCoord := Vector2((DepthStacks - i) * Depth / DepthStacks, j * Height / HeightStacks);
        v0.Tangent := Vector3(0,0,0);
        v0.Bitangent := Vector3(0,0,0);
        idx0 := Builder.AddVertex(v0);

        v1.Position := Vector3(left, bottom + j * Height / HeightStacks, back + (i+1) * Depth / DepthStacks);
        v1.Normal := Vector3(-1, 0, 0);
        v1.TexCoord := Vector2((DepthStacks - (i+1)) * Depth / DepthStacks, j * Height / HeightStacks);
        v1.Tangent := Vector3(0,0,0);
        v1.Bitangent := Vector3(0,0,0);
        idx1 := Builder.AddVertex(v1);

        v2.Position := Vector3(left, bottom + (j+1) * Height / HeightStacks, back + (i+1) * Depth / DepthStacks);
        v2.Normal := Vector3(-1, 0, 0);
        v2.TexCoord := Vector2((DepthStacks - (i+1)) * Depth / DepthStacks, (j+1) * Height / HeightStacks);
        v2.Tangent := Vector3(0,0,0);
        v2.Bitangent := Vector3(0,0,0);
        idx2 := Builder.AddVertex(v2);

        v3.Position := Vector3(left, bottom + (j+1) * Height / HeightStacks, back + i * Depth / DepthStacks);
        v3.Normal := Vector3(-1, 0, 0);
        v3.TexCoord := Vector2((DepthStacks - i) * Depth / DepthStacks, (j+1) * Height / HeightStacks);
        v3.Tangent := Vector3(0,0,0);
        v3.Bitangent := Vector3(0,0,0);
        idx3 := Builder.AddVertex(v3);

        // Reverse winding for outward facing
        Builder.AddTriangle(idx1, idx0, idx3);
        Builder.AddTriangle(idx1, idx3, idx2);
      end;

    // ------------------- Top Face (Y = top) -------------------
    for i := 0 to WidthStacks - 1 do
      for j := 0 to DepthStacks - 1 do
      begin
        v0.Position := Vector3(left + i * Width / WidthStacks, top, back + j * Depth / DepthStacks);
        v0.Normal := Vector3(0, 1, 0);
        v0.TexCoord := Vector2(i * Width / WidthStacks, j * Depth / DepthStacks);
        v0.Tangent := Vector3(0,0,0);
        v0.Bitangent := Vector3(0,0,0);
        idx0 := Builder.AddVertex(v0);

        v1.Position := Vector3(left + (i+1) * Width / WidthStacks, top, back + j * Depth / DepthStacks);
        v1.Normal := Vector3(0, 1, 0);
        v1.TexCoord := Vector2((i+1) * Width / WidthStacks, j * Depth / DepthStacks);
        v1.Tangent := Vector3(0,0,0);
        v1.Bitangent := Vector3(0,0,0);
        idx1 := Builder.AddVertex(v1);

        v2.Position := Vector3(left + (i+1) * Width / WidthStacks, top, back + (j+1) * Depth / DepthStacks);
        v2.Normal := Vector3(0, 1, 0);
        v2.TexCoord := Vector2((i+1) * Width / WidthStacks, (j+1) * Depth / DepthStacks);
        v2.Tangent := Vector3(0,0,0);
        v2.Bitangent := Vector3(0,0,0);
        idx2 := Builder.AddVertex(v2);

        v3.Position := Vector3(left + i * Width / WidthStacks, top, back + (j+1) * Depth / DepthStacks);
        v3.Normal := Vector3(0, 1, 0);
        v3.TexCoord := Vector2(i * Width / WidthStacks, (j+1) * Depth / DepthStacks);
        v3.Tangent := Vector3(0,0,0);
        v3.Bitangent := Vector3(0,0,0);
        idx3 := Builder.AddVertex(v3);

        Builder.AddTriangle(idx0, idx1, idx2);
        Builder.AddTriangle(idx0, idx2, idx3);
      end;

    // ------------------- Bottom Face (Y = bottom) -------------------
    for i := 0 to WidthStacks - 1 do
      for j := 0 to DepthStacks - 1 do
      begin
        v0.Position := Vector3(left + i * Width / WidthStacks, bottom, back + j * Depth / DepthStacks);
        v0.Normal := Vector3(0, -1, 0);
        v0.TexCoord := Vector2((WidthStacks - i) * Width / WidthStacks, j * Depth / DepthStacks);
        v0.Tangent := Vector3(0,0,0);
        v0.Bitangent := Vector3(0,0,0);
        idx0 := Builder.AddVertex(v0);

        v1.Position := Vector3(left + (i+1) * Width / WidthStacks, bottom, back + j * Depth / DepthStacks);
        v1.Normal := Vector3(0, -1, 0);
        v1.TexCoord := Vector2((WidthStacks - (i+1)) * Width / WidthStacks, j * Depth / DepthStacks);
        v1.Tangent := Vector3(0,0,0);
        v1.Bitangent := Vector3(0,0,0);
        idx1 := Builder.AddVertex(v1);

        v2.Position := Vector3(left + (i+1) * Width / WidthStacks, bottom, back + (j+1) * Depth / DepthStacks);
        v2.Normal := Vector3(0, -1, 0);
        v2.TexCoord := Vector2((WidthStacks - (i+1)) * Width / WidthStacks, (j+1) * Depth / DepthStacks);
        v2.Tangent := Vector3(0,0,0);
        v2.Bitangent := Vector3(0,0,0);
        idx2 := Builder.AddVertex(v2);

        v3.Position := Vector3(left + i * Width / WidthStacks, bottom, back + (j+1) * Depth / DepthStacks);
        v3.Normal := Vector3(0, -1, 0);
        v3.TexCoord := Vector2((WidthStacks - i) * Width / WidthStacks, (j+1) * Depth / DepthStacks);
        v3.Tangent := Vector3(0,0,0);
        v3.Bitangent := Vector3(0,0,0);
        idx3 := Builder.AddVertex(v3);

        Builder.AddTriangle(idx1, idx0, idx3);
        Builder.AddTriangle(idx1, idx3, idx2);
      end;

    Vertices := Builder.Vertices.ToArray;
    Indices := Builder.Indices.ToArray;
  finally
    Builder.Vertices.Free;
    Builder.Indices.Free;
  end;
end;

// -----------------------------------------------------------------------------
// CreateSphereVertices: creates a UV sphere (longitude/latitude) with smooth normals.
// -----------------------------------------------------------------------------
procedure CreateSphereVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Radius: Single; StackCount, SliceCount: Integer);
var
  Builder: TVertexBuilder;
  i, j: Integer;
  phi, nextPhi: Single;
  theta, nextTheta: Single;
  x, y, z, nx, ny, nz, u, v: Single;
  vert: TVertex;
  idxBottomLeft, idxBottomRight, idxTopLeft, idxTopRight: Integer;
begin
  Builder.Vertices := TList<TVertex>.Create;
  Builder.Indices := TList<GLuint>.Create;
  try
    // Generate vertices
    for i := 0 to StackCount do
    begin
      phi := -PI/2 + i * PI / StackCount;   // -90� to +90�
      v := i * PI * Radius / StackCount;       // V follows arc length from south pole to north pole
      for j := 0 to SliceCount do
      begin
        theta := j * 2 * PI / SliceCount;   // 0 to 2PI
        u := j * (2 * PI * Radius) / SliceCount; // U follows equator circumference

        x := Radius * Cos(phi) * Cos(theta);
        y := Radius * Sin(phi);
        z := Radius * Cos(phi) * Sin(theta);
        nx := Cos(phi) * Cos(theta);
        ny := Sin(phi);
        nz := Cos(phi) * Sin(theta);

        vert.Position := Vector3(x, y, z);
        vert.Normal := Vector3(nx, ny, nz);
        vert.TexCoord := Vector2(u, v);
        vert.Tangent := Vector3(0,0,0);
        vert.Bitangent := Vector3(0,0,0);
        Builder.AddVertex(vert);
      end;
    end;

    // Generate indices (two triangles per quad)
    for i := 0 to StackCount - 1 do
      for j := 0 to SliceCount - 1 do
      begin
        idxBottomLeft := i * (SliceCount+1) + j;
        idxBottomRight := i * (SliceCount+1) + j+1;
        idxTopLeft := (i+1) * (SliceCount+1) + j;
        idxTopRight := (i+1) * (SliceCount+1) + j+1;

        Builder.AddTriangle(idxBottomLeft, idxBottomRight, idxTopRight);
        Builder.AddTriangle(idxBottomLeft, idxTopRight, idxTopLeft);
      end;

    Vertices := Builder.Vertices.ToArray;
    Indices := Builder.Indices.ToArray;
  finally
    Builder.Vertices.Free;
    Builder.Indices.Free;
  end;
end;

// -----------------------------------------------------------------------------
// CreateCylinderVertices: generates a cylinder with side and optional caps.
// -----------------------------------------------------------------------------
procedure CreateCylinderVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Radius, Height: Single; Slices, Stacks: Integer; BottomCap: TCapType; TopCap: TCapType);
var
  Builder: TVertexBuilder;
  i, j: Integer;
  theta: Single;
  yBottom, yTop, y: Single;
  x, z, nx, nz, u, v: Single;
  vert: TVertex;

  procedure AddCap(const IsTop: Boolean; const Cap: TCapType);
  var
    capY: Single;
    normal: TVector3;
    rimIndices: TArray<Integer>;
    centerIdx: Integer;
    capTheta, capX, capZ: Single;
    k: Integer;
  begin
    if (Cap = ctNone) or (Radius <= 0) then
      Exit;

    if IsTop then
    begin
      capY := yTop;
      normal := Vector3(0, 1, 0);
    end
    else
    begin
      capY := yBottom;
      normal := Vector3(0, -1, 0);
    end;

    SetLength(rimIndices, Slices);
    for k := 0 to Slices - 1 do
    begin
      capTheta := k * 2 * PI / Slices;
      capX := Radius * Cos(capTheta);
      capZ := Radius * Sin(capTheta);

      vert.Position := Vector3(capX, capY, capZ);
      vert.Normal := normal;
      vert.TexCoord := Vector2(capX + Radius, capZ + Radius);
      vert.Tangent := Vector3(0,0,0);
      vert.Bitangent := Vector3(0,0,0);
      rimIndices[k] := Builder.AddVertex(vert);
    end;

    vert.Position := Vector3(0, capY, 0);
    vert.Normal := normal;
    vert.TexCoord := Vector2(Radius, Radius);
    vert.Tangent := Vector3(0,0,0);
    vert.Bitangent := Vector3(0,0,0);
    centerIdx := Builder.AddVertex(vert);

    for k := 0 to Slices - 1 do
    begin
      if IsTop then
        Builder.AddTriangle(centerIdx, rimIndices[(k + 1) mod Slices], rimIndices[k])
      else
        Builder.AddTriangle(centerIdx, rimIndices[k], rimIndices[(k + 1) mod Slices]);
    end;
  end;
begin
  Builder.Vertices := TList<TVertex>.Create;
  Builder.Indices := TList<GLuint>.Create;
  try
    yBottom := -Height / 2;
    yTop := Height / 2;

    // ----- Side vertices -----
    for i := 0 to Stacks do
    begin
      y := yBottom + i * Height / Stacks;
      v := i * Height / Stacks;
      for j := 0 to Slices do
      begin
        theta := j * 2 * PI / Slices;
        u := j * (2 * PI * Radius) / Slices;
        x := Radius * Cos(theta);
        z := Radius * Sin(theta);
        nx := Cos(theta);
        nz := Sin(theta);

        vert.Position := Vector3(x, y, z);
        vert.Normal := Vector3(nx, 0, nz);
        vert.TexCoord := Vector2(u, v);
        vert.Tangent := Vector3(0,0,0);
        vert.Bitangent := Vector3(0,0,0);
        Builder.AddVertex(vert);
      end;
    end;

    // Side indices
    for i := 0 to Stacks - 1 do
      for j := 0 to Slices - 1 do
      begin
        var idxBL := i * (Slices+1) + j;
        var idxBR := i * (Slices+1) + j+1;
        var idxTL := (i+1) * (Slices+1) + j;
        var idxTR := (i+1) * (Slices+1) + j+1;
        Builder.AddTriangle(idxBL, idxBR, idxTR);
        Builder.AddTriangle(idxBL, idxTR, idxTL);
      end;

    AddCap(False, BottomCap);
    AddCap(True, TopCap);

    Vertices := Builder.Vertices.ToArray;
    Indices := Builder.Indices.ToArray;
  finally
    Builder.Vertices.Free;
    Builder.Indices.Free;
  end;
end;

// -----------------------------------------------------------------------------
// CreateCapsuleVertices: builds a capsule (cylinder + two hemispheres).
// -----------------------------------------------------------------------------
procedure CreateCapsuleVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Radius, Height: Single; Slices, Stacks: Integer);
var
  Builder: TVertexBuilder;
  yBottomCyl, yTopCyl: Single;
  i, j: Integer;
  theta, phi, phiStep: Single;
  x, y, z, nx, ny, nz, u, v: Single;
  vert: TVertex;
  idxBL, idxBR, idxTL, idxTR: Integer;
  baseIdx: Integer;
begin
  Builder.Vertices := TList<TVertex>.Create;
  Builder.Indices := TList<GLuint>.Create;
  try
    yBottomCyl := -Height / 2;
    yTopCyl    :=  Height / 2;

    // -----------------------------------------------------------------
    // 1. Cylinder side (without flat caps)
    // -----------------------------------------------------------------
    for i := 0 to Stacks do
    begin
      y := yBottomCyl + i * Height / Stacks;
      v := (PI * Radius * 0.5) + i * Height / Stacks;

      for j := 0 to Slices do
      begin
        theta := j * 2 * PI / Slices;
        u := j * (2 * PI * Radius) / Slices;

        x := Radius * Cos(theta);
        z := Radius * Sin(theta);
        nx := Cos(theta);
        nz := Sin(theta);

        vert.Position := Vector3(x, y, z);
        vert.Normal   := Vector3(nx, 0, nz);
        vert.TexCoord := Vector2(u, v);
        vert.Tangent  := Vector3(0, 0, 0);
        vert.Bitangent := Vector3(0, 0, 0);
        Builder.AddVertex(vert);
      end;
    end;

    // Indices for cylinder side
    for i := 0 to Stacks - 1 do
      for j := 0 to Slices - 1 do
      begin
        idxBL := i * (Slices + 1) + j;
        idxBR := i * (Slices + 1) + j + 1;
        idxTL := (i + 1) * (Slices + 1) + j;
        idxTR := (i + 1) * (Slices + 1) + j + 1;

        Builder.AddTriangle(idxBL, idxBR, idxTR);
        Builder.AddTriangle(idxBL, idxTR, idxTL);
      end;

    // -----------------------------------------------------------------
    // 2. Bottom hemisphere (centered at yBottomCyl, phi = -PI/2 .. 0)
    // -----------------------------------------------------------------
    phiStep := (PI / 2) / Stacks;   // from -PI/2 up to 0
    for i := 0 to Stacks do
    begin
      phi := -PI/2 + i * phiStep;
      v := i * (PI * Radius * 0.5) / Stacks;

      for j := 0 to Slices do
      begin
        theta := j * 2 * PI / Slices;
        u := j * (2 * PI * Radius) / Slices;

        // Position relative to sphere center (0, yBottomCyl, 0)
        x := Radius * Cos(phi) * Cos(theta);
        y := yBottomCyl + Radius * Sin(phi);
        z := Radius * Cos(phi) * Sin(theta);

        // Normal is the same as direction from sphere center
        nx := Cos(phi) * Cos(theta);
        ny := Sin(phi);
        nz := Cos(phi) * Sin(theta);

        vert.Position := Vector3(x, y, z);
        vert.Normal   := Vector3(nx, ny, nz);
        vert.TexCoord := Vector2(u, v);
        vert.Tangent  := Vector3(0, 0, 0);
        vert.Bitangent := Vector3(0, 0, 0);
        Builder.AddVertex(vert);
      end;
    end;

    // Indices for bottom hemisphere (same pattern as sphere)
    baseIdx := Builder.Vertices.Count - (Stacks+1)*(Slices+1);
    for i := 0 to Stacks - 1 do
      for j := 0 to Slices - 1 do
      begin
        idxBL := baseIdx + i * (Slices + 1) + j;
        idxBR := baseIdx + i * (Slices + 1) + j + 1;
        idxTL := baseIdx + (i + 1) * (Slices + 1) + j;
        idxTR := baseIdx + (i + 1) * (Slices + 1) + j + 1;

        Builder.AddTriangle(idxBL, idxBR, idxTR);
        Builder.AddTriangle(idxBL, idxTR, idxTL);
      end;

    // -----------------------------------------------------------------
    // 3. Top hemisphere (centered at yTopCyl, phi = 0 .. PI/2)
    // -----------------------------------------------------------------
    phiStep := (PI / 2) / Stacks;   // from 0 up to PI/2
    for i := 0 to Stacks do
    begin
      phi := i * phiStep;
      v := (PI * Radius * 0.5) + Height + i * (PI * Radius * 0.5) / Stacks;

      for j := 0 to Slices do
      begin
        theta := j * 2 * PI / Slices;
        u := j * (2 * PI * Radius) / Slices;

        x := Radius * Cos(phi) * Cos(theta);
        y := yTopCyl + Radius * Sin(phi);
        z := Radius * Cos(phi) * Sin(theta);

        nx := Cos(phi) * Cos(theta);
        ny := Sin(phi);
        nz := Cos(phi) * Sin(theta);

        vert.Position := Vector3(x, y, z);
        vert.Normal   := Vector3(nx, ny, nz);
        vert.TexCoord := Vector2(u, v);
        vert.Tangent  := Vector3(0, 0, 0);
        vert.Bitangent := Vector3(0, 0, 0);
        Builder.AddVertex(vert);
      end;
    end;

    // Indices for top hemisphere
    baseIdx := Builder.Vertices.Count - (Stacks+1)*(Slices+1);
    for i := 0 to Stacks - 1 do
      for j := 0 to Slices - 1 do
      begin
        idxBL := baseIdx + i * (Slices + 1) + j;
        idxBR := baseIdx + i * (Slices + 1) + j + 1;
        idxTL := baseIdx + (i + 1) * (Slices + 1) + j;
        idxTR := baseIdx + (i + 1) * (Slices + 1) + j + 1;

        Builder.AddTriangle(idxBL, idxBR, idxTR);
        Builder.AddTriangle(idxBL, idxTR, idxTL);
      end;

    // -----------------------------------------------------------------
    // Output
    // -----------------------------------------------------------------
    Vertices := Builder.Vertices.ToArray;
    Indices  := Builder.Indices.ToArray;
  finally
    Builder.Vertices.Free;
    Builder.Indices.Free;
  end;
end;

// -----------------------------------------------------------------------------
// CreateTorusVertices: generates a torus with given major/minor radii.
// -----------------------------------------------------------------------------
procedure CreateTorusVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  MajorRadius, MinorRadius: Single; MajorSegments, MinorSegments: Integer);
var
  Builder: TVertexBuilder;
  i, j: Integer;
  theta, phi: Single;
  thetaStep, phiStep: Single;
  cosTheta, sinTheta: Single;
  cosPhi, sinPhi: Single;
  x, y, z: Single;
  nx, ny, nz: Single;
  u, v: Single;
  vert: TVertex;
  idxBL, idxBR, idxTL, idxTR: Integer;
begin
  Builder.Vertices := TList<TVertex>.Create;
  Builder.Indices := TList<GLuint>.Create;
  try
    thetaStep := 2 * PI / MajorSegments;   // around the ring
    phiStep   := 2 * PI / MinorSegments;   // around the tube cross-section

    // Generate vertices
    for i := 0 to MajorSegments do
    begin
      theta := i * thetaStep;
      u := i * (2 * PI * MajorRadius) / MajorSegments;

      cosTheta := Cos(theta);
      sinTheta := Sin(theta);

      for j := 0 to MinorSegments do
      begin
        phi := j * phiStep;
        v := j * (2 * PI * MinorRadius) / MinorSegments;

        cosPhi := Cos(phi);
        sinPhi := Sin(phi);

        // Position on the torus surface
        x := (MajorRadius + MinorRadius * cosPhi) * cosTheta;
        y := (MajorRadius + MinorRadius * cosPhi) * sinTheta;
        z := MinorRadius * sinPhi;

        // Normal points outward from the tube surface
        // (point on tube circle relative to major ring center)
        nx := cosPhi * cosTheta;
        ny := cosPhi * sinTheta;
        nz := sinPhi;

        vert.Position := Vector3(x, y, z);
        vert.Normal   := Vector3(nx, ny, nz);
        vert.TexCoord := Vector2(u, v);
        vert.Tangent  := Vector3(0, 0, 0);
        vert.Bitangent := Vector3(0, 0, 0);
        Builder.AddVertex(vert);
      end;
    end;

    // Generate indices (two triangles per quad)
    for i := 0 to MajorSegments - 1 do
      for j := 0 to MinorSegments - 1 do
      begin
        idxBL := i * (MinorSegments + 1) + j;
        idxBR := i * (MinorSegments + 1) + j + 1;
        idxTL := (i + 1) * (MinorSegments + 1) + j;
        idxTR := (i + 1) * (MinorSegments + 1) + j + 1;

        Builder.AddTriangle(idxBL, idxBR, idxTR);
        Builder.AddTriangle(idxBL, idxTR, idxTL);
      end;

    Vertices := Builder.Vertices.ToArray;
    Indices  := Builder.Indices.ToArray;
  finally
    Builder.Vertices.Free;
    Builder.Indices.Free;
  end;
end;

// -----------------------------------------------------------------------------
// CreateConeVertices: constructs a cone with flat bottom cap.
// -----------------------------------------------------------------------------
procedure CreateConeVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Radius, Height: Single; Sides, Stacks: Integer);
var
  Builder: TVertexBuilder;
  i, j: Integer;
  theta, nextTheta: Single;
  y, yNext: Single;
  r, rNext: Single;
  x, z, nx, nz, ny: Single;
  u, v: Single;
  vert: TVertex;
  idx0, idx1, idx2, idx3: Integer;
  centerBottomIdx: Integer;
  factor: Single;
begin
  Builder.Vertices := TList<TVertex>.Create;
  Builder.Indices := TList<GLuint>.Create;
  try
    // ----- Side vertices -----
    for i := 0 to Stacks do
    begin
      // y from -Height/2 (base) to +Height/2 (tip)
      y := -Height/2 + i * Height / Stacks;
      v := i * Height / Stacks;

      // radius at this height: linear from Radius at base to 0 at tip
      r := Radius * (1 - i / Stacks);

      for j := 0 to Sides do
      begin
        theta := j * 2 * PI / Sides;
        u := j * (2 * PI * Radius) / Sides;

        x := r * Cos(theta);
        z := r * Sin(theta);

        // Normal for side: (x/r, R/H, z/r) normalized
        // where R = Radius, H = Height, and r is current radius
        if r > 0 then
        begin
          factor := 1 / Sqrt(x*x + z*z + (Radius/Height)*(Radius/Height));
          nx := (x / r) * factor;
          ny := (Radius / Height) * factor;
          nz := (z / r) * factor;
        end
        else
        begin
          // at tip, normal is straight up
          nx := 0;
          ny := 1;
          nz := 0;
        end;

        vert.Position := Vector3(x, y, z);
        vert.Normal   := Vector3(nx, ny, nz);
        vert.TexCoord := Vector2(u, v);
        vert.Tangent  := Vector3(0, 0, 0);
        vert.Bitangent := Vector3(0, 0, 0);
        Builder.AddVertex(vert);
      end;
    end;

    // Side indices (two triangles per quad)
    for i := 0 to Stacks - 1 do
      for j := 0 to Sides - 1 do
      begin
        idx0 := i * (Sides + 1) + j;
        idx1 := i * (Sides + 1) + j + 1;
        idx2 := (i + 1) * (Sides + 1) + j;
        idx3 := (i + 1) * (Sides + 1) + j + 1;

        Builder.AddTriangle(idx0, idx1, idx3);
        Builder.AddTriangle(idx0, idx3, idx2);
      end;

    // ----- Bottom cap (triangle fan from center) -----
    centerBottomIdx := Builder.Vertices.Count;
    vert.Position := Vector3(0, -Height/2, 0);
    vert.Normal   := Vector3(0, -1, 0);
    vert.TexCoord := Vector2(Radius, Radius);
    vert.Tangent  := Vector3(0, 0, 0);
    vert.Bitangent := Vector3(0, 0, 0);
    Builder.AddVertex(vert);

    for j := 0 to Sides - 1 do
    begin
      theta := j * 2 * PI / Sides;
      nextTheta := (j + 1) * 2 * PI / Sides;

      x := Radius * Cos(theta);
      z := Radius * Sin(theta);
      u := x + Radius;
      v := z + Radius;
      vert.Position := Vector3(x, -Height/2, z);
      vert.Normal   := Vector3(0, -1, 0);
      vert.TexCoord := Vector2(u, v);
      vert.Tangent  := Vector3(0, 0, 0);
      vert.Bitangent := Vector3(0, 0, 0);
      idx1 := Builder.AddVertex(vert);

      x := Radius * Cos(nextTheta);
      z := Radius * Sin(nextTheta);
      u := x + Radius;
      v := z + Radius;
      vert.Position := Vector3(x, -Height/2, z);
      vert.Normal   := Vector3(0, -1, 0);
      vert.TexCoord := Vector2(u, v);
      vert.Tangent  := Vector3(0, 0, 0);
      vert.Bitangent := Vector3(0, 0, 0);
      idx2 := Builder.AddVertex(vert);

      Builder.AddTriangle(centerBottomIdx, idx1, idx2);
    end;

    Vertices := Builder.Vertices.ToArray;
    Indices  := Builder.Indices.ToArray;
  finally
    Builder.Vertices.Free;
    Builder.Indices.Free;
  end;
end;

// -----------------------------------------------------------------------------
// CreatePrismVertices: creates a regular polygonal prism.
// -----------------------------------------------------------------------------
procedure CreatePrismVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Radius, Height: Single; Sides, Stacks: Integer);
var
  Builder: TVertexBuilder;
  i, j: Integer;
  theta: Single;
  x, z, nx, nz: Single;
  y, yNext: Single;
  u, v: Single;
  vert: TVertex;
  idxBL, idxBR, idxTL, idxTR: Integer;
  centerBottomIdx, centerTopIdx: Integer;
  baseVertices: array of Integer;
begin
  Builder.Vertices := TList<TVertex>.Create;
  Builder.Indices := TList<GLuint>.Create;
  try
    // ----- Side vertices (one vertical strip per polygon edge) -----
    for i := 0 to Stacks do
    begin
      y := -Height/2 + i * Height / Stacks;
      v := i * Height / Stacks;

      for j := 0 to Sides do
      begin
        theta := j * 2 * PI / Sides;
        u := j * (2 * PI * Radius) / Sides;

        x := Radius * Cos(theta);
        z := Radius * Sin(theta);

        // Radial normal (smooth across edges)
        nx := Cos(theta);
        nz := Sin(theta);

        vert.Position := Vector3(x, y, z);
        vert.Normal   := Vector3(nx, 0, nz);
        vert.TexCoord := Vector2(u, v);
        vert.Tangent  := Vector3(0, 0, 0);
        vert.Bitangent := Vector3(0, 0, 0);
        Builder.AddVertex(vert);
      end;
    end;

    // Side indices (two triangles per quad)
    for i := 0 to Stacks - 1 do
      for j := 0 to Sides - 1 do
      begin
        idxBL := i * (Sides + 1) + j;
        idxBR := i * (Sides + 1) + j + 1;
        idxTL := (i + 1) * (Sides + 1) + j;
        idxTR := (i + 1) * (Sides + 1) + j + 1;

        Builder.AddTriangle(idxBL, idxBR, idxTR);
        Builder.AddTriangle(idxBL, idxTR, idxTL);
      end;

    // ----- Bottom cap (triangle fan from center) -----
    centerBottomIdx := Builder.Vertices.Count;
    vert.Position := Vector3(0, -Height/2, 0);
    vert.Normal   := Vector3(0, -1, 0);
    vert.TexCoord := Vector2(Radius, Radius);
    vert.Tangent  := Vector3(0, 0, 0);
    vert.Bitangent := Vector3(0, 0, 0);
    Builder.AddVertex(vert);

    SetLength(baseVertices, Sides);
    for j := 0 to Sides - 1 do
    begin
      theta := j * 2 * PI / Sides;
      x := Radius * Cos(theta);
      z := Radius * Sin(theta);
      u := x + Radius;
      v := z + Radius;

      vert.Position := Vector3(x, -Height/2, z);
      vert.Normal   := Vector3(0, -1, 0);
      vert.TexCoord := Vector2(u, v);
      vert.Tangent  := Vector3(0, 0, 0);
      vert.Bitangent := Vector3(0, 0, 0);
      baseVertices[j] := Builder.AddVertex(vert);
    end;

    for j := 0 to Sides - 1 do
    begin
      Builder.AddTriangle(centerBottomIdx, baseVertices[j], baseVertices[(j+1) mod Sides]);
    end;

    // ----- Top cap (triangle fan from center) -----
    centerTopIdx := Builder.Vertices.Count;
    vert.Position := Vector3(0, Height/2, 0);
    vert.Normal   := Vector3(0, 1, 0);
    vert.TexCoord := Vector2(Radius, Radius);
    vert.Tangent  := Vector3(0, 0, 0);
    vert.Bitangent := Vector3(0, 0, 0);
    Builder.AddVertex(vert);

    for j := 0 to Sides - 1 do
    begin
      theta := j * 2 * PI / Sides;
      x := Radius * Cos(theta);
      z := Radius * Sin(theta);
      u := x + Radius;
      v := z + Radius;

      vert.Position := Vector3(x, Height/2, z);
      vert.Normal   := Vector3(0, 1, 0);
      vert.TexCoord := Vector2(u, v);
      vert.Tangent  := Vector3(0, 0, 0);
      vert.Bitangent := Vector3(0, 0, 0);
      baseVertices[j] := Builder.AddVertex(vert);
    end;

    for j := 0 to Sides - 1 do
    begin
      Builder.AddTriangle(centerTopIdx, baseVertices[(j+1) mod Sides], baseVertices[j]);
      // Note: reversed order to maintain outward winding (top cap faces up)
    end;

    Vertices := Builder.Vertices.ToArray;
    Indices  := Builder.Indices.ToArray;
  finally
    Builder.Vertices.Free;
    Builder.Indices.Free;
  end;
end;

procedure CreateFrustumVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  BottomRadius, TopRadius, Height: Single; Slices, Stacks: Integer;
  BottomCap, TopCap: TCapType);
var
  Builder: TVertexBuilder;
  i, j: Integer;
  yBottom, yTop: Single;
  theta, nextTheta: Single;
  y, r, rNext: Single;
  t, u, v: Single;
  x, z, nx, nz: Single;
  slope, ny: Single;
  vert: TVertex;
  idxBL, idxBR, idxTL, idxTR: Integer;
  rimBottomIndices, rimTopIndices: TArray<Integer>;
  centerIdx: Integer;
begin
  Builder.Vertices := TList<TVertex>.Create;
  Builder.Indices := TList<GLuint>.Create;
  try
    yBottom := -Height / 2;
    yTop    :=  Height / 2;
    slope   := (TopRadius - BottomRadius) / Height;   // radial change per unit Y

    // -----------------------------------------------------------------
    // 1. Side vertices (positions, normals, UVs)
    // -----------------------------------------------------------------
    for i := 0 to Stacks do
    begin
      t := i / Stacks;                 // 0 at bottom, 1 at top
      y := yBottom + t * Height;       // actual Y coordinate
      r := BottomRadius + t * (TopRadius - BottomRadius);   // radius at this Y

      v := t * Height;                   // V follows actual height

      for j := 0 to Slices do
      begin
        theta := j * 2 * PI / Slices;
        u := j * (2 * PI * System.Math.Max(BottomRadius, TopRadius)) / Slices;  // U follows cap circumference

        x := r * Cos(theta);
        z := r * Sin(theta);

        // Normal for slanted side: (x/r, -slope, z/r) normalized
        if r > 0 then
        begin
          nx := x / r;
          nz := z / r;
          ny := -slope;
          var len := Sqrt(nx*nx + ny*ny + nz*nz);
          if len > 0 then
          begin
            nx := nx / len;
            ny := ny / len;
            nz := nz / len;
          end
          else
          begin
            nx := 0; ny := 1; nz := 0;
          end;
        end
        else
        begin
          // Degenerate case (radius = 0 at this stack) � normal points straight up
          nx := 0; ny := 1; nz := 0;
        end;

        vert.Position := Vector3(x, y, z);
        vert.Normal   := Vector3(nx, ny, nz);
        vert.TexCoord := Vector2(u, v);
        vert.Tangent  := Vector3(0,0,0);
        vert.Bitangent := Vector3(0,0,0);
        Builder.AddVertex(vert);
      end;
    end;

    // Side indices (two triangles per quad)
    for i := 0 to Stacks - 1 do
      for j := 0 to Slices - 1 do
      begin
        idxBL := i * (Slices + 1) + j;
        idxBR := i * (Slices + 1) + j + 1;
        idxTL := (i + 1) * (Slices + 1) + j;
        idxTR := (i + 1) * (Slices + 1) + j + 1;

        Builder.AddTriangle(idxBL, idxBR, idxTR);
        Builder.AddTriangle(idxBL, idxTR, idxTL);
      end;

    // -----------------------------------------------------------------
    // 2. Bottom cap (optional)
    // -----------------------------------------------------------------
    if (BottomCap <> ctNone) and (BottomRadius > 0) then
    begin
      // Collect rim vertices from the bottom row (i = 0) in angular order
      SetLength(rimBottomIndices, Slices);
      for j := 0 to Slices - 1 do
      begin
        theta := j * 2 * PI / Slices;
        x := BottomRadius * Cos(theta);
        z := BottomRadius * Sin(theta);
        vert.Position := Vector3(x, yBottom, z);
        vert.Normal   := Vector3(0, -1, 0);
        vert.TexCoord := Vector2(x + BottomRadius, z + BottomRadius);
        vert.Tangent  := Vector3(0,0,0);
        vert.Bitangent := Vector3(0,0,0);
        rimBottomIndices[j] := Builder.AddVertex(vert);
      end;

      if BottomCap = ctCenter then
      begin
        // Center vertex
        vert.Position := Vector3(0, yBottom, 0);
        vert.Normal   := Vector3(0, -1, 0);
        vert.TexCoord := Vector2(BottomRadius, BottomRadius);
        vert.Tangent  := Vector3(0,0,0);
        vert.Bitangent := Vector3(0,0,0);
        centerIdx := Builder.AddVertex(vert);

        // Fan from center to each edge
        for j := 0 to Slices - 1 do
          Builder.AddTriangle(centerIdx, rimBottomIndices[j], rimBottomIndices[(j+1) mod Slices]);
      end
      else if BottomCap = ctFlat then
      begin
        // Flat disc: generate a separate set of vertices for the disc (same positions as rim)
        // but we already have rim vertices with correct UVs; just need a center and fan.
        // Actually ctFlat should produce a planar disc with its own UV mapping; same as center fan.
        // The only difference from ctCenter is the UV mapping on the rim (radial vs planar).
        // Here we use radial mapping already, which is fine for ctFlat as well.
        // For simplicity, treat ctFlat same as ctCenter for caps (center + fan).
        vert.Position := Vector3(0, yBottom, 0);
        vert.Normal   := Vector3(0, -1, 0);
        vert.TexCoord := Vector2(BottomRadius, BottomRadius);
        vert.Tangent  := Vector3(0,0,0);
        vert.Bitangent := Vector3(0,0,0);
        centerIdx := Builder.AddVertex(vert);

        for j := 0 to Slices - 1 do
          Builder.AddTriangle(centerIdx, rimBottomIndices[j], rimBottomIndices[(j+1) mod Slices]);
      end;
    end;

    // -----------------------------------------------------------------
    // 3. Top cap (optional)
    // -----------------------------------------------------------------
    if (TopCap <> ctNone) and (TopRadius > 0) then
    begin
      SetLength(rimTopIndices, Slices);
      for j := 0 to Slices - 1 do
      begin
        theta := j * 2 * PI / Slices;
        x := TopRadius * Cos(theta);
        z := TopRadius * Sin(theta);
        vert.Position := Vector3(x, yTop, z);
        vert.Normal   := Vector3(0, 1, 0);
        vert.TexCoord := Vector2(x + TopRadius, z + TopRadius);
        vert.Tangent  := Vector3(0,0,0);
        vert.Bitangent := Vector3(0,0,0);
        rimTopIndices[j] := Builder.AddVertex(vert);
      end;

      if TopCap = ctCenter then
      begin
        vert.Position := Vector3(0, yTop, 0);
        vert.Normal   := Vector3(0, 1, 0);
        vert.TexCoord := Vector2(TopRadius, TopRadius);
        vert.Tangent  := Vector3(0,0,0);
        vert.Bitangent := Vector3(0,0,0);
        centerIdx := Builder.AddVertex(vert);

        for j := 0 to Slices - 1 do
          Builder.AddTriangle(centerIdx, rimTopIndices[(j+1) mod Slices], rimTopIndices[j]);
        // Reverse order to keep outward normal (upward)
      end
      else if TopCap = ctFlat then
      begin
        vert.Position := Vector3(0, yTop, 0);
        vert.Normal   := Vector3(0, 1, 0);
        vert.TexCoord := Vector2(TopRadius, TopRadius);
        vert.Tangent  := Vector3(0,0,0);
        vert.Bitangent := Vector3(0,0,0);
        centerIdx := Builder.AddVertex(vert);

        for j := 0 to Slices - 1 do
          Builder.AddTriangle(centerIdx, rimTopIndices[(j+1) mod Slices], rimTopIndices[j]);
      end;
    end;

    // -----------------------------------------------------------------
    // Output
    // -----------------------------------------------------------------
    Vertices := Builder.Vertices.ToArray;
    Indices  := Builder.Indices.ToArray;
  finally
    Builder.Vertices.Free;
    Builder.Indices.Free;
  end;
end;

// -----------------------------------------------------------------------------
// CreateIcosphereVertices: builds an icosphere (subdivided icosahedron) with seam fixing.
// -----------------------------------------------------------------------------
procedure CreateIcosphereVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Radius: Single; Subdivisions: Integer);
const
  // GLScene icosahedron data (raw, not yet normalized)
  GL_ICOSAHEDRON_VERTICES: array[0..11] of TVector3 = (
    (X: 0.0;            Y: -0.309017; Z: -0.5),
    (X: 0.0;            Y: -0.309017; Z:  0.5),
    (X: 0.0;            Y:  0.309017; Z: -0.5),
    (X: 0.0;            Y:  0.309017; Z:  0.5),
    (X: -0.5;           Y:  0.0;      Z: -0.309017),
    (X: -0.5;           Y:  0.0;      Z:  0.309017),
    (X:  0.5;           Y:  0.0;      Z: -0.309017),
    (X:  0.5;           Y:  0.0;      Z:  0.309017),
    (X: -0.309017;      Y: -0.5;      Z:  0.0),
    (X: -0.309017;      Y:  0.5;      Z:  0.0),
    (X:  0.309017;      Y: -0.5;      Z:  0.0),
    (X:  0.309017;      Y:  0.5;      Z:  0.0)
  );
  GL_ICOSAHEDRON_INDICES: array[0..19] of array[0..2] of Integer = (
    (2, 9, 11), (3, 11, 9), (3, 5, 1), (3, 1, 7),
    (2, 6, 0), (2, 0, 4), (1, 8, 10), (0, 10, 8),
    (9, 4, 5), (8, 5, 4), (11, 7, 6), (10, 6, 7),
    (3, 9, 5), (3, 7, 11), (2, 4, 9), (2, 11, 6),
    (0, 8, 4), (0, 6, 10), (1, 5, 8), (1, 10, 7)
  );
  MAX_SUBDIVISIONS = 5;
  EPS = 1e-6;
type
  TFace = record V0, V1, V2: Integer; end;
var
  Builder: TVertexBuilder;
  MidPointCache: TDictionary<TEdgeKey, Integer>;
  InputVertices: TList<TVector3>;
  InputFaces: TList<TFace>;
  i, j: Integer;
  v0, v1, v2, mid: TVector3;
  idxA, idxB, idxC: Integer;
  key01, key12, key20: TEdgeKey;
  OldToNew: TDictionary<Integer, Integer>;
  p, norm: TVector3;
  vert: TVertex;
  newIdx: Integer;
  scale: Single;
begin
  if Subdivisions > MAX_SUBDIVISIONS then
    Subdivisions := MAX_SUBDIVISIONS;

  Builder.Vertices := TList<TVertex>.Create;
  Builder.Indices := TList<GLuint>.Create;
  MidPointCache := TDictionary<TEdgeKey, Integer>.Create;
  InputVertices := TList<TVector3>.Create;
  InputFaces := TList<TFace>.Create;
  try
    // 1. Load and normalize icosahedron vertices
    for i := 0 to 11 do
    begin
      v0 := GL_ICOSAHEDRON_VERTICES[i];
      scale := v0.Length;
      if scale = 0 then Continue;
      v0 := v0 / scale;
      InputVertices.Add(v0);
    end;
    for i := 0 to 19 do
    begin
      var f: TFace;
      f.V0 := GL_ICOSAHEDRON_INDICES[i][0];
      f.V1 := GL_ICOSAHEDRON_INDICES[i][1];
      f.V2 := GL_ICOSAHEDRON_INDICES[i][2];
      InputFaces.Add(f);
    end;

    // 2. Subdivide
    for i := 1 to Subdivisions do
    begin
      MidPointCache.Clear;
      var NewVertices := TList<TVector3>.Create;
      var NewFaces := TList<TFace>.Create;
      try
        NewVertices.AddRange(InputVertices);
        for j := 0 to InputFaces.Count - 1 do
        begin
          var tri := InputFaces[j];
          v0 := InputVertices[tri.V0];
          v1 := InputVertices[tri.V1];
          v2 := InputVertices[tri.V2];

          key01 := EdgeKey(tri.V0, tri.V1);
          if not MidPointCache.TryGetValue(key01, idxA) then
          begin
            mid := (v0 + v1).Normalize;
            idxA := NewVertices.Count;
            NewVertices.Add(mid);
            MidPointCache.Add(key01, idxA);
          end;

          key12 := EdgeKey(tri.V1, tri.V2);
          if not MidPointCache.TryGetValue(key12, idxB) then
          begin
            mid := (v1 + v2).Normalize;
            idxB := NewVertices.Count;
            NewVertices.Add(mid);
            MidPointCache.Add(key12, idxB);
          end;

          key20 := EdgeKey(tri.V2, tri.V0);
          if not MidPointCache.TryGetValue(key20, idxC) then
          begin
            mid := (v2 + v0).Normalize;
            idxC := NewVertices.Count;
            NewVertices.Add(mid);
            MidPointCache.Add(key20, idxC);
          end;

          var f1, f2, f3, f4: TFace;
          f1.V0 := tri.V0; f1.V1 := idxA; f1.V2 := idxC;
          f2.V0 := tri.V1; f2.V1 := idxB; f2.V2 := idxA;
          f3.V0 := tri.V2; f3.V1 := idxC; f3.V2 := idxB;
          f4.V0 := idxA; f4.V1 := idxB; f4.V2 := idxC;
          NewFaces.Add(f1);
          NewFaces.Add(f2);
          NewFaces.Add(f3);
          NewFaces.Add(f4);
        end;
        InputVertices.Free;
        InputVertices := NewVertices;
        InputFaces.Free;
        InputFaces := NewFaces;
      except
        NewVertices.Free;
        NewFaces.Free;
        raise;
      end;
    end;

    // 3. Build initial vertex buffer (shared vertices, raw UVs)
    OldToNew := TDictionary<Integer, Integer>.Create;
    try
      for i := 0 to InputFaces.Count - 1 do
      begin
        var tri := InputFaces[i];
        for j := 0 to 2 do
        begin
          var idx: Integer;
          case j of
            0: idx := tri.V0;
            1: idx := tri.V1;
            2: idx := tri.V2;
          end;
          if not OldToNew.ContainsKey(idx) then
          begin
            p := InputVertices[idx] * Radius;
            norm := p.Normalize;
            vert.Position := p;
            vert.Normal := norm;
            var yc := p.Y / Radius;
            if yc < -1 then yc := -1 else if yc > 1 then yc := 1;
            vert.TexCoord := Vector2(
              System.Math.ArcTan2(p.Z, p.X) / (2*PI) + 0.5,
              System.Math.ArcSin(yc) / PI + 0.5);
            vert.Tangent := Vector3(0,0,0);
            vert.Bitangent := Vector3(0,0,0);
            newIdx := Builder.AddVertex(vert);
            OldToNew.Add(idx, newIdx);
          end;
        end;
      end;
      for i := 0 to InputFaces.Count - 1 do
      begin
        var tri := InputFaces[i];
        Builder.AddTriangle(OldToNew[tri.V0], OldToNew[tri.V1], OldToNew[tri.V2]);
      end;
    finally
      OldToNew.Free;
    end;

    Vertices := Builder.Vertices.ToArray;
    Indices := Builder.Indices.ToArray;

    // 4. Fix the texture seam
    FixTextureSeam(Vertices, Indices);
  finally
    Builder.Vertices.Free;
    Builder.Indices.Free;
    MidPointCache.Free;
    InputVertices.Free;
    InputFaces.Free;
  end;
end;

// -----------------------------------------------------------------------------
// CreateGeodesicDomeVertices: generates a geodesic dome (half icosphere) with flat cap.
// -----------------------------------------------------------------------------
procedure CreateGeodesicDomeVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Radius: Single; Subdivisions: Integer);
type
  TFaceRec = record V0, V1, V2: Integer; end;
const
  EPS = 1e-6;
var
  FullSphereVertices: TArray<TVertex>;
  FullSphereIndices: TArray<GLuint>;
  Builder: TVertexBuilder;
  ClippedVerts: TList<TVector3>;
  ClippedUVs: TList<TVector2>;        // store original UVs
  ClippedNormals: TList<TVector3>;
  ClippedFaces: TList<TFaceRec>;
  PosMap: TDictionary<string, Integer>;
  i, j: Integer;

  function AddClippedVertex(const P: TVector3; const UV: TVector2; const N: TVector3): Integer;
  var
    key: string;
  begin
    key := Format('%.6f:%.6f:%.6f', [P.X, P.Y, P.Z]);
    if not PosMap.TryGetValue(key, Result) then
    begin
      Result := ClippedVerts.Count;
      ClippedVerts.Add(P);
      ClippedUVs.Add(UV);
      ClippedNormals.Add(N);
      PosMap.Add(key, Result);
    end;
  end;

  procedure ClipTriangle(const A, B, C: TVertex);
  var
    inputPoly: array[0..2] of TVertex;
    outputPolyVerts: TList<TVertex>;
    prev, curr: TVertex;
    prevInside, currInside: Boolean;
    t: Single;
    inter: TVector3;
    interUV: TVector2;
    interNorm: TVector3;
    k: Integer;
  begin
    inputPoly[0] := A; inputPoly[1] := B; inputPoly[2] := C;
    outputPolyVerts := TList<TVertex>.Create;
    try
      prev := inputPoly[2];
      prevInside := prev.Position.Y >= -EPS;
      for k := 0 to 2 do
      begin
        curr := inputPoly[k];
        currInside := curr.Position.Y >= -EPS;
        if currInside then
        begin
          if not prevInside then
          begin
            t := -prev.Position.Y / (curr.Position.Y - prev.Position.Y);
            inter := prev.Position + (curr.Position - prev.Position) * t;
            inter := inter.Normalize * Radius;   // project onto sphere
            interNorm := inter.Normalize;
            // Interpolate UVs linearly
            interUV.X := prev.TexCoord.X + (curr.TexCoord.X - prev.TexCoord.X) * t;
            interUV.Y := prev.TexCoord.Y + (curr.TexCoord.Y - prev.TexCoord.Y) * t;
            // Ensure U is continuous (avoid wrap in the middle of a triangle)
            // For a triangle that crosses the equator, we keep raw interpolation.
            var outVert: TVertex;
            outVert.Position := inter;
            outVert.Normal := interNorm;
            outVert.TexCoord := interUV;
            outVert.Tangent := Vector3(0,0,0);
            outVert.Bitangent := Vector3(0,0,0);
            outputPolyVerts.Add(outVert);
          end;
          outputPolyVerts.Add(curr);
        end
        else
        begin
          if prevInside then
          begin
            t := -prev.Position.Y / (curr.Position.Y - prev.Position.Y);
            inter := prev.Position + (curr.Position - prev.Position) * t;
            inter := inter.Normalize * Radius;
            interNorm := inter.Normalize;
            interUV.X := prev.TexCoord.X + (curr.TexCoord.X - prev.TexCoord.X) * t;
            interUV.Y := prev.TexCoord.Y + (curr.TexCoord.Y - prev.TexCoord.Y) * t;
            var outVert: TVertex;
            outVert.Position := inter;
            outVert.Normal := interNorm;
            outVert.TexCoord := interUV;
            outVert.Tangent := Vector3(0,0,0);
            outVert.Bitangent := Vector3(0,0,0);
            outputPolyVerts.Add(outVert);
          end;
        end;
        prev := curr;
        prevInside := currInside;
      end;

      // Triangulate convex polygon (fan from first vertex)
      if outputPolyVerts.Count >= 3 then
        for k := 1 to outputPolyVerts.Count - 2 do
        begin
          var f: TFaceRec;
          f.V0 := AddClippedVertex(outputPolyVerts[0].Position, outputPolyVerts[0].TexCoord, outputPolyVerts[0].Normal);
          f.V1 := AddClippedVertex(outputPolyVerts[k].Position, outputPolyVerts[k].TexCoord, outputPolyVerts[k].Normal);
          f.V2 := AddClippedVertex(outputPolyVerts[k+1].Position, outputPolyVerts[k+1].TexCoord, outputPolyVerts[k+1].Normal);
          ClippedFaces.Add(f);
        end;
    finally
      outputPolyVerts.Free;
    end;
  end;

var
  RimIndices: TList<Integer>;
  Angles: TList<Double>;
  SortedOrder: TArray<Integer>;
  NewRimIndices: TArray<Integer>;
  CenterIdx: Integer;
  v: TVertex;
  rimVert: TVector3;
  minY: Single;
  idx: Integer;
begin
  // 1. Generate a full seam-fixed icosphere
  CreateIcosphereVertices(FullSphereVertices, FullSphereIndices, Radius, Subdivisions);

  // 2. Clip sphere to Y >= 0
  ClippedVerts := TList<TVector3>.Create;
  ClippedUVs := TList<TVector2>.Create;
  ClippedNormals := TList<TVector3>.Create;
  ClippedFaces := TList<TFaceRec>.Create;
  PosMap := TDictionary<string, Integer>.Create;
  try
    for i := 0 to (Length(FullSphereIndices) div 3) - 1 do
    begin
      var v0 := FullSphereVertices[FullSphereIndices[i*3]];
      var v1 := FullSphereVertices[FullSphereIndices[i*3+1]];
      var v2 := FullSphereVertices[FullSphereIndices[i*3+2]];
      ClipTriangle(v0, v1, v2);
    end;

    // Build final vertex buffer from clipped data
    Builder.Vertices := TList<TVertex>.Create;
    Builder.Indices := TList<GLuint>.Create;
    try
      for i := 0 to ClippedVerts.Count - 1 do
      begin
        v.Position := ClippedVerts[i];
        v.Normal := ClippedNormals[i];
        v.TexCoord := ClippedUVs[i];
        v.Tangent := Vector3(0,0,0);
        v.Bitangent := Vector3(0,0,0);
        Builder.AddVertex(v);
      end;
      for i := 0 to ClippedFaces.Count - 1 do
        Builder.AddTriangle(ClippedFaces[i].V0, ClippedFaces[i].V1, ClippedFaces[i].V2);

      // 3. Add bottom cap (triangle fan)
      RimIndices := TList<Integer>.Create;
      Angles := TList<Double>.Create;
      try
        // Find equator vertices (Y approx 0)
        for i := 0 to Builder.Vertices.Count - 1 do
          if Abs(Builder.Vertices[i].Position.Y) < EPS then
          begin
            RimIndices.Add(i);
            Angles.Add(System.Math.ArcTan2(Builder.Vertices[i].Position.Z, Builder.Vertices[i].Position.X));
          end;
        if RimIndices.Count >= 3 then
        begin
          // Sort by angle around Y axis
          SetLength(SortedOrder, RimIndices.Count);
          for i := 0 to RimIndices.Count - 1 do SortedOrder[i] := i;
          TArray.Sort<Integer>(SortedOrder,
            TComparer<Integer>.Construct(
              function(const L, R: Integer): Integer
              begin
                if Angles[L] < Angles[R] then Result := -1
                else if Angles[L] > Angles[R] then Result := 1
                else Result := 0;
              end
            )
          );
          // Create new vertices for the cap (flattened to Y=0, normal down)
          SetLength(NewRimIndices, RimIndices.Count);
          for i := 0 to RimIndices.Count - 1 do
          begin
            var origPos := Builder.Vertices[RimIndices[SortedOrder[i]]].Position;
            v.Position := Vector3(origPos.X, 0, origPos.Z);
            v.Normal := Vector3(0, -1, 0);
            // Planar UV mapping for the cap
            v.TexCoord := Vector2((origPos.X / Radius + 1) * 0.5, (origPos.Z / Radius + 1) * 0.5);
            v.Tangent := Vector3(0,0,0);
            v.Bitangent := Vector3(0,0,0);
            NewRimIndices[i] := Builder.AddVertex(v);
          end;
          // Center vertex
          v.Position := Vector3(0, 0, 0);
          v.Normal := Vector3(0, -1, 0);
          v.TexCoord := Vector2(0.5, 0.5);
          v.Tangent := Vector3(0,0,0);
          v.Bitangent := Vector3(0,0,0);
          CenterIdx := Builder.AddVertex(v);
          // Fan triangles (clockwise to face down)
          for i := 0 to RimIndices.Count - 1 do
          begin
            var iNext := (i + 1) mod RimIndices.Count;
            Builder.AddTriangle(CenterIdx, NewRimIndices[iNext], NewRimIndices[i]);
          end;
        end;
      finally
        RimIndices.Free;
        Angles.Free;
      end;

      Vertices := Builder.Vertices.ToArray;
      Indices := Builder.Indices.ToArray;
    finally
      Builder.Vertices.Free;
      Builder.Indices.Free;
    end;
  finally
    ClippedVerts.Free;
    ClippedUVs.Free;
    ClippedNormals.Free;
    ClippedFaces.Free;
    PosMap.Free;
  end;

  // 4. Apply the same seam-fixing to the final dome (handles any leftover discontinuities)
  FixTextureSeam(Vertices, Indices);
end;

// -----------------------------------------------------------------------------
// CreateGizmoVertices: creates a 3-axis translation gizmo (sphere + three arrows).
// -----------------------------------------------------------------------------
procedure CreateGizmoVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  ArrowLength, ShaftRadius, TipRadius, TipLength: Single;
  Slices, Stacks: Integer);
var
  Builder: TVertexBuilder;
  CenterRadius: Single;

  // ----- helper to add a cylinder side (without caps) along a given axis -----
  procedure AddCylinderSide(StartPos, EndPos: TVector3; Radius: Single;
    Axis: Integer; Slices, Stacks: Integer);
  var
    i, j: Integer;
    t, theta: Single;
    u, v: Single;
    pos, norm: TVector3;
    vert: TVertex;
    idxBL, idxBR, idxTL, idxTR: Integer;
    baseIdx: Integer;
    dirVec: TVector3;
    length: Single;
  begin
    // direction vector and length
    dirVec := EndPos - StartPos;
    length := dirVec.Length;
    if length = 0 then Exit;

    baseIdx := Builder.Vertices.Count;

    // generate vertices
    for i := 0 to Stacks do
    begin
      t := i / Stacks;                // 0 at StartPos, 1 at EndPos
      v := t;                         // V texture coordinate along axis
      for j := 0 to Slices do
      begin
        theta := j * 2 * PI / Slices;
        u := j / Slices;              // U texture coordinate around axis

        // position: linear interpolation between start and end, plus radial offset
        pos := StartPos + dirVec * t;
        case Axis of
          0: // X axis
            begin
              pos.Y := pos.Y + Radius * Cos(theta);
              pos.Z := pos.Z + Radius * Sin(theta);
              norm := Vector3(0, Cos(theta), Sin(theta));
            end;
          1: // Y axis
            begin
              pos.X := pos.X + Radius * Cos(theta);
              pos.Z := pos.Z + Radius * Sin(theta);
              norm := Vector3(Cos(theta), 0, Sin(theta));
            end;
          2: // Z axis
            begin
              pos.X := pos.X + Radius * Cos(theta);
              pos.Y := pos.Y + Radius * Sin(theta);
              norm := Vector3(Cos(theta), Sin(theta), 0);
            end;
        end;
        norm.Normalize;        // ensure unit length

        vert.Position := pos;
        vert.Normal   := norm;
        vert.TexCoord := Vector2(u, v);
        vert.Tangent  := Vector3(0,0,0);
        vert.Bitangent := Vector3(0,0,0);
        Builder.AddVertex(vert);
      end;
    end;

    // indices (two triangles per quad)
    for i := 0 to Stacks - 1 do
      for j := 0 to Slices - 1 do
      begin
        idxBL := baseIdx + i * (Slices + 1) + j;
        idxBR := baseIdx + i * (Slices + 1) + j + 1;
        idxTL := baseIdx + (i + 1) * (Slices + 1) + j;
        idxTR := baseIdx + (i + 1) * (Slices + 1) + j + 1;
        Builder.AddTriangle(idxBL, idxBR, idxTR);
        Builder.AddTriangle(idxBL, idxTR, idxTL);
      end;
  end;

  // ----- helper to add a cone side (without base cap) along a given axis -----
  procedure AddConeSide(BasePos, TipPos: TVector3; BaseRadius: Single;
    Axis: Integer; Slices, Stacks: Integer);
  var
    i, j: Integer;
    t, theta: Single;
    r, u, v: Single;
    pos, norm: TVector3;
    vert: TVertex;
    idxBL, idxBR, idxTL, idxTR: Integer;
    baseIdx: Integer;
    dirVec: TVector3;
    length: Single;
    nxComp: Single;
  begin
    dirVec := TipPos - BasePos;
    length := dirVec.Length;
    if length = 0 then Exit;

    baseIdx := Builder.Vertices.Count;

    // pre-compute the X component of the normal (same for all points on the cone)
    // Equation: gradient of sqrt(y(2)+z(2)) - (BaseRadius/length)*(tipX - x) = 0
    // For arbitrary axis we use the direction vector component.
    // The normal is (dirVec scaled by (BaseRadius/length), radial components)
    nxComp := BaseRadius / length;

    for i := 0 to Stacks do
    begin
      t := i / Stacks;           // 0 at base, 1 at tip
      v := t;                    // V coordinate along axis
      r := BaseRadius * (1 - t); // radius at this height
      for j := 0 to Slices do
      begin
        theta := j * 2 * PI / Slices;
        u := j / Slices;         // U coordinate around axis

        // position along axis + radial offset
        pos := BasePos + dirVec * t;
        case Axis of
          0: // X axis
            begin
              pos.Y := pos.Y + r * Cos(theta);
              pos.Z := pos.Z + r * Sin(theta);
              // normal: (nxComp, y/r, z/r) normalized; at tip (r=0) use (1,0,0)
              if r > 0 then
                norm := Vector3(nxComp, Cos(theta), Sin(theta))
              else
                norm := Vector3(1, 0, 0);
            end;
          1: // Y axis
            begin
              pos.X := pos.X + r * Cos(theta);
              pos.Z := pos.Z + r * Sin(theta);
              if r > 0 then
                norm := Vector3(Cos(theta), nxComp, Sin(theta))
              else
                norm := Vector3(0, 1, 0);
            end;
          2: // Z axis
            begin
              pos.X := pos.X + r * Cos(theta);
              pos.Y := pos.Y + r * Sin(theta);
              if r > 0 then
                norm := Vector3(Cos(theta), Sin(theta), nxComp)
              else
                norm := Vector3(0, 0, 1);
            end;
        end;
        norm.Normalize;

        vert.Position := pos;
        vert.Normal   := norm;
        vert.TexCoord := Vector2(u, v);
        vert.Tangent  := Vector3(0,0,0);
        vert.Bitangent := Vector3(0,0,0);
        Builder.AddVertex(vert);
      end;
    end;

    // indices (two triangles per quad)
    for i := 0 to Stacks - 1 do
      for j := 0 to Slices - 1 do
      begin
        idxBL := baseIdx + i * (Slices + 1) + j;
        idxBR := baseIdx + i * (Slices + 1) + j + 1;
        idxTL := baseIdx + (i + 1) * (Slices + 1) + j;
        idxTR := baseIdx + (i + 1) * (Slices + 1) + j + 1;
        Builder.AddTriangle(idxBL, idxBR, idxTR);
        Builder.AddTriangle(idxBL, idxTR, idxTL);
      end;
  end;

  // ----- helper to add a UV sphere (identical to CreateSphereVertices) -----
  procedure AddSphere(Radius: Single; Slices, Stacks: Integer);
  var
    i, j: Integer;
    phi, theta: Single;
    x, y, z, nx, ny, nz, u, v: Single;
    vert: TVertex;
    baseIdx: Integer;
    idxBL, idxBR, idxTL, idxTR: Integer;
  begin
    baseIdx := Builder.Vertices.Count;

    // generate vertices
    for i := 0 to Stacks do
    begin
      phi := -PI/2 + i * PI / Stacks;   // -90degree to +90degree
      v := i / Stacks;
      for j := 0 to Slices do
      begin
        theta := j * 2 * PI / Slices;
        u := j / Slices;

        x := Radius * Cos(phi) * Cos(theta);
        y := Radius * Sin(phi);
        z := Radius * Cos(phi) * Sin(theta);
        nx := Cos(phi) * Cos(theta);
        ny := Sin(phi);
        nz := Cos(phi) * Sin(theta);

        vert.Position := Vector3(x, y, z);
        vert.Normal   := Vector3(nx, ny, nz);
        vert.TexCoord := Vector2(u, v);
        vert.Tangent  := Vector3(0,0,0);
        vert.Bitangent := Vector3(0,0,0);
        Builder.AddVertex(vert);
      end;
    end;

    // indices
    for i := 0 to Stacks - 1 do
      for j := 0 to Slices - 1 do
      begin
        idxBL := baseIdx + i * (Slices + 1) + j;
        idxBR := baseIdx + i * (Slices + 1) + j + 1;
        idxTL := baseIdx + (i + 1) * (Slices + 1) + j;
        idxTR := baseIdx + (i + 1) * (Slices + 1) + j + 1;
        Builder.AddTriangle(idxBL, idxBR, idxTR);
        Builder.AddTriangle(idxBL, idxTR, idxTL);
      end;
  end;

// ---------------------------------------------------------------------------
// Main procedure body
// ---------------------------------------------------------------------------
begin
  Builder.Vertices := TList<TVertex>.Create;
  Builder.Indices := TList<GLuint>.Create;
  try
    // centre sphere radius � you can adjust the factor to your taste
    CenterRadius := ShaftRadius * 1.5;
    AddSphere(CenterRadius, Slices, Stacks);

    // ----- X-axis arrow (red) -----
    // shaft from sphere surface to end of shaft
    AddCylinderSide(
      Vector3(CenterRadius, 0, 0),
      Vector3(ArrowLength - TipLength, 0, 0),
      ShaftRadius, 0, Slices, Stacks);
    // cone tip
    AddConeSide(
      Vector3(ArrowLength - TipLength, 0, 0),
      Vector3(ArrowLength, 0, 0),
      TipRadius, 0, Slices, Stacks);

    // ----- Y-axis arrow (green) -----
    AddCylinderSide(
      Vector3(0, CenterRadius, 0),
      Vector3(0, ArrowLength - TipLength, 0),
      ShaftRadius, 1, Slices, Stacks);
    AddConeSide(
      Vector3(0, ArrowLength - TipLength, 0),
      Vector3(0, ArrowLength, 0),
      TipRadius, 1, Slices, Stacks);

    // ----- Z-axis arrow (blue) -----
    AddCylinderSide(
      Vector3(0, 0, CenterRadius),
      Vector3(0, 0, ArrowLength - TipLength),
      ShaftRadius, 2, Slices, Stacks);
    AddConeSide(
      Vector3(0, 0, ArrowLength - TipLength),
      Vector3(0, 0, ArrowLength),
      TipRadius, 2, Slices, Stacks);

    Vertices := Builder.Vertices.ToArray;
    Indices := Builder.Indices.ToArray;
  finally
    Builder.Vertices.Free;
    Builder.Indices.Free;
  end;
end;

// -----------------------------------------------------------------------------
// CreateArrowVertices: generates a single arrow pointing upward.
// -----------------------------------------------------------------------------
procedure CreateArrowVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  ShaftLength, TipLength, ShaftRadius, TipRadius: Single;
  Slices, Stacks: Integer);
var
  Builder: TVertexBuilder;
  i, j: Integer;
  theta, y, r, u, v: Single;
  vert: TVertex;
  idxBL, idxBR, idxTL, idxTR: Integer;
  baseIdx, centerIdx: Integer;
  ringIndices: array of Integer;
begin
  Builder.Vertices := TList<TVertex>.Create;
  Builder.Indices := TList<GLuint>.Create;
  try
    // =======================================================================
    // 1. Cylinder shaft (side, no caps yet)
    // =======================================================================
    for i := 0 to Stacks do
    begin
      y := i * ShaftLength / Stacks;        // 0 .. ShaftLength
      v := i / Stacks;

      for j := 0 to Slices do
      begin
        theta := j * 2 * PI / Slices;
        u := j / Slices;

        vert.Position := Vector3(ShaftRadius * Cos(theta), y, ShaftRadius * Sin(theta));
        vert.Normal := Vector3(Cos(theta), 0, Sin(theta));
        vert.TexCoord := Vector2(u, v);
        vert.Tangent := Vector3(0,0,0);
        vert.Bitangent := Vector3(0,0,0);
        Builder.AddVertex(vert);
      end;
    end;

    // Indices for cylinder side
    for i := 0 to Stacks - 1 do
      for j := 0 to Slices - 1 do
      begin
        idxBL := i * (Slices + 1) + j;
        idxBR := i * (Slices + 1) + j + 1;
        idxTL := (i + 1) * (Slices + 1) + j;
        idxTR := (i + 1) * (Slices + 1) + j + 1;
        Builder.AddTriangle(idxBL, idxBR, idxTR);
        Builder.AddTriangle(idxBL, idxTR, idxTL);
      end;

    // -----------------------------------------------------------------------
    // 2. Cylinder bottom cap (y = 0, pointing down)
    // -----------------------------------------------------------------------
    centerIdx := Builder.Vertices.Count;
    vert.Position := Vector3(0, 0, 0);
    vert.Normal := Vector3(0, -1, 0);
    vert.TexCoord := Vector2(0.5, 0.5);
    vert.Tangent := Vector3(0,0,0);
    vert.Bitangent := Vector3(0,0,0);
    Builder.AddVertex(vert);

    SetLength(ringIndices, Slices);
    for j := 0 to Slices - 1 do
    begin
      theta := j * 2 * PI / Slices;
      vert.Position := Vector3(ShaftRadius * Cos(theta), 0, ShaftRadius * Sin(theta));
      vert.Normal := Vector3(0, -1, 0);
      // radial texture mapping: (x+1)/2 , (z+1)/2  (but using radius)
      vert.TexCoord := Vector2( (Cos(theta)+1)/2, (Sin(theta)+1)/2 );
      vert.Tangent := Vector3(0,0,0);
      vert.Bitangent := Vector3(0,0,0);
      ringIndices[j] := Builder.AddVertex(vert);
    end;
    for j := 0 to Slices - 1 do
      Builder.AddTriangle(centerIdx, ringIndices[j], ringIndices[(j+1) mod Slices]);

    // -----------------------------------------------------------------------
    // 3. Cylinder top cap (y = ShaftLength, pointing up)
    //    (This cap will be inside the cone's base if you render the cone cap.
    //     It is included per your request; you can comment it out if not needed.)
    // -----------------------------------------------------------------------
    centerIdx := Builder.Vertices.Count;
    vert.Position := Vector3(0, ShaftLength, 0);
    vert.Normal := Vector3(0, 1, 0);
    vert.TexCoord := Vector2(0.5, 0.5);
    vert.Tangent := Vector3(0,0,0);
    vert.Bitangent := Vector3(0,0,0);
    Builder.AddVertex(vert);

    for j := 0 to Slices - 1 do
    begin
      theta := j * 2 * PI / Slices;
      vert.Position := Vector3(ShaftRadius * Cos(theta), ShaftLength, ShaftRadius * Sin(theta));
      vert.Normal := Vector3(0, 1, 0);
      vert.TexCoord := Vector2( (Cos(theta)+1)/2, (Sin(theta)+1)/2 );
      vert.Tangent := Vector3(0,0,0);
      vert.Bitangent := Vector3(0,0,0);
      ringIndices[j] := Builder.AddVertex(vert);
    end;
    for j := 0 to Slices - 1 do
      Builder.AddTriangle(centerIdx, ringIndices[j], ringIndices[(j+1) mod Slices]);

    // =======================================================================
    // 4. Cone tip (side, no cap at tip)
    // =======================================================================
    baseIdx := Builder.Vertices.Count;

    for i := 0 to Stacks do
    begin
      y := ShaftLength + i * TipLength / Stacks;
      v := i / Stacks;
      r := TipRadius * (1 - i / Stacks);   // radius decreases to 0

      for j := 0 to Slices do
      begin
        theta := j * 2 * PI / Slices;
        u := j / Slices;

        vert.Position := Vector3(r * Cos(theta), y, r * Sin(theta));

        if r > 0 then
        begin
          var factor := 1 / Sqrt(Sqr(Cos(theta)) + Sqr(Sin(theta)) + Sqr(TipRadius/TipLength));
          vert.Normal := Vector3(Cos(theta) * factor, (TipRadius/TipLength) * factor, Sin(theta) * factor);
        end
        else
          vert.Normal := Vector3(0, 1, 0);

        vert.TexCoord := Vector2(u, v);
        vert.Tangent := Vector3(0,0,0);
        vert.Bitangent := Vector3(0,0,0);
        Builder.AddVertex(vert);
      end;
    end;

    // Indices for cone side
    for i := 0 to Stacks - 1 do
      for j := 0 to Slices - 1 do
      begin
        idxBL := baseIdx + i * (Slices + 1) + j;
        idxBR := baseIdx + i * (Slices + 1) + j + 1;
        idxTL := baseIdx + (i + 1) * (Slices + 1) + j;
        idxTR := baseIdx + (i + 1) * (Slices + 1) + j + 1;
        Builder.AddTriangle(idxBL, idxBR, idxTR);
        Builder.AddTriangle(idxBL, idxTR, idxTL);
      end;

    // -----------------------------------------------------------------------
    // 5. Cone base cap (y = ShaftLength, disc, pointing down)
    //    This cap closes the bottom of the cone. It faces downward because
    //    the cone sits above the cylinder. The cone base and cylinder top
    //    cap would overlap � you may disable one of them.
    // -----------------------------------------------------------------------
    centerIdx := Builder.Vertices.Count;
    vert.Position := Vector3(0, ShaftLength, 0);
    vert.Normal := Vector3(0, -1, 0);   // point down (inside the cone, but outward for the cap)
    vert.TexCoord := Vector2(0.5, 0.5);
    vert.Tangent := Vector3(0,0,0);
    vert.Bitangent := Vector3(0,0,0);
    Builder.AddVertex(vert);

    for j := 0 to Slices - 1 do
    begin
      theta := j * 2 * PI / Slices;
      vert.Position := Vector3(TipRadius * Cos(theta), ShaftLength, TipRadius * Sin(theta));
      vert.Normal := Vector3(0, -1, 0);
      vert.TexCoord := Vector2( (Cos(theta)+1)/2, (Sin(theta)+1)/2 );
      vert.Tangent := Vector3(0,0,0);
      vert.Bitangent := Vector3(0,0,0);
      ringIndices[j] := Builder.AddVertex(vert);
    end;
    for j := 0 to Slices - 1 do
      Builder.AddTriangle(centerIdx, ringIndices[j], ringIndices[(j+1) mod Slices]);

    // -----------------------------------------------------------------------
    // Output
    // -----------------------------------------------------------------------
    Vertices := Builder.Vertices.ToArray;
    Indices  := Builder.Indices.ToArray;
  finally
    Builder.Vertices.Free;
    Builder.Indices.Free;
  end;
end;

// -----------------------------------------------------------------------------
// CreateSuperEllipsoidVertices: generates a full superellipsoid.
// -----------------------------------------------------------------------------
// Notes:
// -----------------------------------------------------------------------------
// Sphere        (VCurve = 1.0, HCurve = 1.0)
// Cylinder-like (VCurve = 0.5, HCurve = 1.0) � pinched top/bottom
// Star          (VCurve = 4.0, HCurve = 4.0) � rounded cube
// Cube-like     (VCurve = 0.3, HCurve = 0.3) � concave shapes
//-------------------------------------------------------------------------------
procedure CreateSuperEllipsoidVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Radius: Single; VCurve, HCurve: Single; Slices, Stacks: Integer);

  // Helper: signed power function (works for any real exponent)
  function PowSign(const Base, Exponent: Single): Single;
  begin
    if Base = 0 then
      Result := 0
    else if Base > 0 then
      Result := System.Math.Power(Base, Exponent)
    else
      Result := -Power(-Base, Exponent);
  end;

var
  Builder: TVertexBuilder;
  i, j: Integer;
  phi, theta: Single;
  phiStep, thetaStep: Single;
  sinPhi, cosPhi, sinTheta, cosTheta: Single;
  x, y, z: Single;
  nx, ny, nz: Single;
  u, v: Single;
  vert: TVertex;
  idx00, idx01, idx10, idx11: Integer;
begin
  Builder.Vertices := TList<TVertex>.Create;
  Builder.Indices := TList<GLuint>.Create;
  try
    phiStep := PI / Stacks;      // from -PI/2 to +PI/2
    thetaStep := 2 * PI / Slices;

    // Generate vertices
    for i := 0 to Stacks do
    begin
      phi := -PI/2 + i * phiStep;
      v := (phi + PI/2) / PI;    // V texture coordinate (0 at bottom, 1 at top)

      // Pre?compute phi powers for this row
      sinPhi := Sin(phi);
      cosPhi := Cos(phi);
      var sinPhiPow := PowSign(sinPhi, VCurve);
      var cosPhiPow := PowSign(cosPhi, VCurve);

      for j := 0 to Slices do
      begin
        theta := j * thetaStep;
        u := j / Slices;          // U texture coordinate (0..1 around)

        sinTheta := Sin(theta);
        cosTheta := Cos(theta);

        // Position on unit superellipsoid
        x := cosPhiPow * PowSign(sinTheta, HCurve);
        y := sinPhiPow;
        z := cosPhiPow * PowSign(cosTheta, HCurve);

        // Normal is radial direction (same as unit position)
        var len := Sqrt(x*x + y*y + z*z);
        if len > 0 then
        begin
          nx := x / len;
          ny := y / len;
          nz := z / len;
        end
        else
        begin
          nx := 0; ny := 1; nz := 0;
        end;

        vert.Position := Vector3(x * Radius, y * Radius, z * Radius);
        vert.Normal   := Vector3(nx, ny, nz);
        vert.TexCoord := Vector2(u, v);
        vert.Tangent  := Vector3(0, 0, 0);
        vert.Bitangent := Vector3(0, 0, 0);
        Builder.AddVertex(vert);
      end;
    end;

    // Generate indices (two triangles per quad)
    for i := 0 to Stacks - 1 do
      for j := 0 to Slices - 1 do
      begin
        idx00 := i * (Slices + 1) + j;
        idx01 := i * (Slices + 1) + j + 1;
        idx10 := (i + 1) * (Slices + 1) + j;
        idx11 := (i + 1) * (Slices + 1) + j + 1;

        Builder.AddTriangle(idx00, idx01, idx11);
        Builder.AddTriangle(idx00, idx11, idx10);
      end;

    Vertices := Builder.Vertices.ToArray;
    Indices := Builder.Indices.ToArray;
  finally
    Builder.Vertices.Free;
    Builder.Indices.Free;
  end;
end;

// -----------------------------------------------------------------------------
// CreateSuperEllipsoidOpenedVertices: generates a superellipsoid with angular limits and caps.
// -----------------------------------------------------------------------------
procedure CreateSuperEllipsoidOpenedVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Radius, VCurve, HCurve: Single; Slices, Stacks: Integer;
  TopAngle, BottomAngle: Single; StartAngle, StopAngle: Single;
  TopCap, BottomCap: TCapType);

  function PowSign(const Base, Exponent: Single): Single;
  begin
    if Base = 0 then Result := 0
    else if Base > 0 then Result := System.Math.Power(Base, Exponent)
    else Result := -Power(-Base, Exponent);
  end;

  function DegToRad(d: Single): Single;
  begin
    Result := d * PI / 180;
  end;

var
  Builder: TVertexBuilder;
  i, j: Integer;
  phi, theta: Single;
  phiStart, phiEnd, thetaStart, thetaEnd: Single;
  phiStep, thetaStep: Single;
  sinPhi, cosPhi, sinTheta, cosTheta: Single;
  x, y, z, nx, ny, nz, len: Single;
  u, v: Single;
  vert: TVertex;
  idx00, idx01, idx10, idx11: Integer;
  // For caps
  type TRimVertex = record
    Pos: TVector3;
    Normal: TVector3;
    TexCoord: TVector2;
  end;
  var
  BottomRim, TopRim: TList<TRimVertex>;
  rimAngles: TList<Double>;
  centerIdx: Integer;
  sorted: TArray<Integer>;
  k: Integer;
  rimVert: TRimVertex;
begin
  Builder.Vertices := TList<TVertex>.Create;
  Builder.Indices := TList<GLuint>.Create;
  BottomRim := TList<TRimVertex>.Create;
  TopRim := TList<TRimVertex>.Create;
  try
    // Convert angles to radians
    phiStart := DegToRad(BottomAngle);
    phiEnd   := DegToRad(TopAngle);
    thetaStart := DegToRad(StartAngle);
    thetaEnd   := DegToRad(StopAngle);

    // Avoid zero ranges
    if phiStart = phiEnd then phiEnd := phiStart + 0.001;
    if thetaStart = thetaEnd then thetaEnd := thetaStart + 0.001;

    phiStep := (phiEnd - phiStart) / Stacks;
    thetaStep := (thetaEnd - thetaStart) / Slices;

    // =====================================================================
    // 1. Main body vertices
    // =====================================================================
    for i := 0 to Stacks do
    begin
      phi := phiStart + i * phiStep;
      v := (phi - phiStart) / (phiEnd - phiStart);

      sinPhi := Sin(phi);
      cosPhi := Cos(phi);
      var sinPhiPow := PowSign(sinPhi, VCurve);
      var cosPhiPow := PowSign(cosPhi, VCurve);

      for j := 0 to Slices do
      begin
        theta := thetaStart + j * thetaStep;
        u := (theta - thetaStart) / (thetaEnd - thetaStart);

        sinTheta := Sin(theta);
        cosTheta := Cos(theta);

        x := cosPhiPow * PowSign(sinTheta, HCurve);
        y := sinPhiPow;
        z := cosPhiPow * PowSign(cosTheta, HCurve);

        len := Sqrt(x*x + y*y + z*z);
        if len > 0 then
        begin
          nx := x / len;
          ny := y / len;
          nz := z / len;
        end
        else
        begin
          nx := 0; ny := 1; nz := 0;
        end;

        vert.Position := Vector3(x * Radius, y * Radius, z * Radius);
        vert.Normal   := Vector3(nx, ny, nz);
        vert.TexCoord := Vector2(u, v);
        vert.Tangent  := Vector3(0,0,0);
        vert.Bitangent := Vector3(0,0,0);
        Builder.AddVertex(vert);

        // Store rim vertices for caps (first and last stack rows)
        if i = 0 then
        begin
          rimVert.Pos := vert.Position;
          rimVert.Normal := vert.Normal;
          rimVert.TexCoord := Vector2(u, 0);
          BottomRim.Add(rimVert);
        end;
        if i = Stacks then
        begin
          rimVert.Pos := vert.Position;
          rimVert.Normal := vert.Normal;
          rimVert.TexCoord := Vector2(u, 1);
          TopRim.Add(rimVert);
        end;
      end;
    end;

    // =====================================================================
    // 2. Indices for main body
    // =====================================================================
    for i := 0 to Stacks - 1 do
      for j := 0 to Slices - 1 do
      begin
        idx00 := i * (Slices + 1) + j;
        idx01 := i * (Slices + 1) + j + 1;
        idx10 := (i + 1) * (Slices + 1) + j;
        idx11 := (i + 1) * (Slices + 1) + j + 1;
        Builder.AddTriangle(idx00, idx01, idx11);
        Builder.AddTriangle(idx00, idx11, idx10);
      end;

    // =====================================================================
    // 3. Bottom cap
    // =====================================================================
    if (BottomCap <> ctNone) and (BottomRim.Count > 0) then
    begin
      rimAngles := TList<Double>.Create;
      try
        for i := 0 to BottomRim.Count - 1 do
          rimAngles.Add(System.Math.ArcTan2(BottomRim[i].Pos.Z, BottomRim[i].Pos.X));
        SetLength(sorted, BottomRim.Count);
        for i := 0 to BottomRim.Count - 1 do sorted[i] := i;
        TArray.Sort<Integer>(sorted,
          TComparer<Integer>.Construct(
            function(const L, R: Integer): Integer
            begin
              if rimAngles[L] < rimAngles[R] then Result := -1
              else if rimAngles[L] > rimAngles[R] then Result := 1
              else Result := 0;
            end
          )
        );
      finally
        rimAngles.Free;
      end;

      if BottomCap = ctCenter then
      begin
        // Center vertex
        vert.Position := Vector3(0, BottomRim[0].Pos.Y, 0);
        vert.Normal   := Vector3(0, -1, 0);
        vert.TexCoord := Vector2(0.5, 0.5);
        vert.Tangent  := Vector3(0,0,0);
        vert.Bitangent := Vector3(0,0,0);
        centerIdx := Builder.AddVertex(vert);

        // Add rim vertices and create fan
        for i := 0 to BottomRim.Count - 1 do
        begin
          // Convert TRimVertex to TVertex
          rimVert := BottomRim[sorted[i]];
          vert.Position := rimVert.Pos;
          vert.Normal   := rimVert.Normal;
          vert.TexCoord := rimVert.TexCoord;
          vert.Tangent  := Vector3(0,0,0);
          vert.Bitangent := Vector3(0,0,0);
          var idxCurr := Builder.AddVertex(vert);

          rimVert := BottomRim[sorted[(i+1) mod BottomRim.Count]];
          vert.Position := rimVert.Pos;
          vert.Normal   := rimVert.Normal;
          vert.TexCoord := rimVert.TexCoord;
          vert.Tangent  := Vector3(0,0,0);
          vert.Bitangent := Vector3(0,0,0);
          var idxNext := Builder.AddVertex(vert);

          Builder.AddTriangle(centerIdx, idxNext, idxCurr); // downward normal
        end;
      end
      else if BottomCap = ctFlat then
      begin
        // Center vertex
        vert.Position := Vector3(0, BottomRim[0].Pos.Y, 0);
        vert.Normal   := Vector3(0, -1, 0);
        vert.TexCoord := Vector2(0.5, 0.5);
        vert.Tangent  := Vector3(0,0,0);
        vert.Bitangent := Vector3(0,0,0);
        centerIdx := Builder.AddVertex(vert);

        // Flattened rim vertices
        var rimIndices: TArray<Integer>;
        SetLength(rimIndices, BottomRim.Count);
        for i := 0 to BottomRim.Count - 1 do
        begin
          var pos := BottomRim[sorted[i]].Pos;
          pos.Y := BottomRim[0].Pos.Y; // ensure flat
          vert.Position := pos;
          vert.Normal   := Vector3(0, -1, 0);
          vert.TexCoord := Vector2((pos.X/Radius + 1)/2, (pos.Z/Radius + 1)/2);
          vert.Tangent  := Vector3(0,0,0);
          vert.Bitangent := Vector3(0,0,0);
          rimIndices[i] := Builder.AddVertex(vert);
        end;
        for i := 0 to BottomRim.Count - 1 do
        begin
          var iNext := (i + 1) mod BottomRim.Count;
          Builder.AddTriangle(centerIdx, rimIndices[iNext], rimIndices[i]);
        end;
      end;
    end;

    // =====================================================================
    // 4. Top cap
    // =====================================================================
    if (TopCap <> ctNone) and (TopRim.Count > 0) then
    begin
      rimAngles := TList<Double>.Create;
      try
        for i := 0 to TopRim.Count - 1 do
          rimAngles.Add(System.Math.ArcTan2(TopRim[i].Pos.Z, TopRim[i].Pos.X));
        SetLength(sorted, TopRim.Count);
        for i := 0 to TopRim.Count - 1 do sorted[i] := i;
        TArray.Sort<Integer>(sorted,
          TComparer<Integer>.Construct(
            function(const L, R: Integer): Integer
            begin
              if rimAngles[L] < rimAngles[R] then Result := -1
              else if rimAngles[L] > rimAngles[R] then Result := 1
              else Result := 0;
            end
          )
        );
      finally
        rimAngles.Free;
      end;

      if TopCap = ctCenter then
      begin
        vert.Position := Vector3(0, TopRim[0].Pos.Y, 0);
        vert.Normal   := Vector3(0, 1, 0);
        vert.TexCoord := Vector2(0.5, 0.5);
        vert.Tangent  := Vector3(0,0,0);
        vert.Bitangent := Vector3(0,0,0);
        centerIdx := Builder.AddVertex(vert);

        for i := 0 to TopRim.Count - 1 do
        begin
          rimVert := TopRim[sorted[i]];
          vert.Position := rimVert.Pos;
          vert.Normal   := rimVert.Normal;
          vert.TexCoord := rimVert.TexCoord;
          vert.Tangent  := Vector3(0,0,0);
          vert.Bitangent := Vector3(0,0,0);
          var idxCurr := Builder.AddVertex(vert);

          rimVert := TopRim[sorted[(i+1) mod TopRim.Count]];
          vert.Position := rimVert.Pos;
          vert.Normal   := rimVert.Normal;
          vert.TexCoord := rimVert.TexCoord;
          vert.Tangent  := Vector3(0,0,0);
          vert.Bitangent := Vector3(0,0,0);
          var idxNext := Builder.AddVertex(vert);

          Builder.AddTriangle(centerIdx, idxCurr, idxNext); // upward normal
        end;
      end
      else if TopCap = ctFlat then
      begin
        vert.Position := Vector3(0, TopRim[0].Pos.Y, 0);
        vert.Normal   := Vector3(0, 1, 0);
        vert.TexCoord := Vector2(0.5, 0.5);
        vert.Tangent  := Vector3(0,0,0);
        vert.Bitangent := Vector3(0,0,0);
        centerIdx := Builder.AddVertex(vert);

        var rimIndices: TArray<Integer>;
        SetLength(rimIndices, TopRim.Count);
        for i := 0 to TopRim.Count - 1 do
        begin
          var pos := TopRim[sorted[i]].Pos;
          pos.Y := TopRim[0].Pos.Y;
          vert.Position := pos;
          vert.Normal   := Vector3(0, 1, 0);
          vert.TexCoord := Vector2((pos.X/Radius + 1)/2, (pos.Z/Radius + 1)/2);
          vert.Tangent  := Vector3(0,0,0);
          vert.Bitangent := Vector3(0,0,0);
          rimIndices[i] := Builder.AddVertex(vert);
        end;
        for i := 0 to TopRim.Count - 1 do
        begin
          var iNext := (i + 1) mod TopRim.Count;
          Builder.AddTriangle(centerIdx, rimIndices[i], rimIndices[iNext]);
        end;
      end;
    end;

    Vertices := Builder.Vertices.ToArray;
    Indices := Builder.Indices.ToArray;
  finally
    Builder.Vertices.Free;
    Builder.Indices.Free;
    BottomRim.Free;
    TopRim.Free;
  end;
end;

end.
