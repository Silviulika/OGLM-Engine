unit Generators;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, dglOpenGL, Vcl.ExtCtrls, Vcl.StdCtrls, System.Math,
  System.Generics.Collections, Engine.Types,
  Renderer.Shader, Managers.Material, Neslib.FastMath;

{-------------------------------------------------------------------------------
  Icosahedron base data (vertices and indices).
-------------------------------------------------------------------------------}
const
  ICOSAHEDRON_VERTICES: array[0..11] of TVector3 = (
    (X: -0.525731112119; Y: 0.000000000000; Z: 0.850650808352),
    (X: 0.525731112119;  Y: 0.000000000000; Z: 0.850650808352),
    (X: -0.525731112119; Y: 0.000000000000; Z: -0.850650808352),
    (X: 0.525731112119;  Y: 0.000000000000; Z: -0.850650808352),
    (X: 0.000000000000;  Y: 0.850650808352; Z: 0.525731112119),
    (X: 0.000000000000;  Y: 0.850650808352; Z: -0.525731112119),
    (X: 0.000000000000;  Y: -0.850650808352; Z: 0.525731112119),
    (X: 0.000000000000;  Y: -0.850650808352; Z: -0.525731112119),
    (X: 0.850650808352;  Y: 0.525731112119; Z: 0.000000000000),
    (X: 0.850650808352;  Y: -0.525731112119; Z: 0.000000000000),
    (X: -0.850650808352; Y: 0.525731112119; Z: 0.000000000000),
    (X: -0.850650808352; Y: -0.525731112119; Z: 0.000000000000)
  );

  ICOSAHEDRON_INDICES: array[0..19, 0..2] of Integer = (
    (0, 4, 1), (0, 9, 4), (9, 5, 4), (4, 5, 8), (4, 8, 1),
    (8, 10, 1), (8, 3, 10), (5, 3, 8), (5, 2, 3), (2, 7, 3),
    (7, 10, 3), (7, 6, 10), (7, 11, 6), (11, 0, 6), (0, 1, 6),
    (6, 1, 10), (9, 0, 11), (9, 11, 2), (9, 2, 5), (7, 2, 11)
  );

type
  TEdgeKey = record
    Min, Max: Integer;
  end;

type
  TTriplet = record
    I0, I1, I2: Integer;
    constructor Create(A, B, C: Integer);
  end;

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
  /// <summary>Generates a cylinder with side walls, bottom cap, and top cap.</summary>
  /// <param name="Vertices">Output vertex data including normals for side and caps.</param>
  /// <param name="Indices">Output index buffer for triangles.</param>
  /// <param name="Radius">Radius of the cylinder.</param>
  /// <param name="Height">Total height of the cylinder (extent from -Height/2 to +Height/2 on Y axis).</param>
  /// <param name="Slices">Number of radial subdivisions (around the circumference).</param>
  /// <param name="Stacks">Number of vertical subdivisions along the cylinder body.</param>
  /// <remarks>The cylinder is closed with triangle fans for the caps. Caps have flat normals pointing outward.
  ///  UV mapping: U runs around the side, V runs from bottom to top. Caps use radial UV mapping.</remarks>
//-------------------------------------------------------------------------------
procedure CreateCylinderVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Radius, Height: Single; Slices, Stacks: Integer);

//-------------------------------------------------------------------------------
  /// <summary>Creates a capsule mesh consisting of a cylindrical body and two hemispherical end caps.</summary>
  /// <param name="Vertices">Output vertex array with positions, normals, and UVs.</param>
  /// <param name="Indices">Output index array.</param>
  /// <param name="Radius">Radius of the cylindrical body and hemispheres.</param>
  /// <param name="Height">Height of the cylindrical part (excluding hemispheres). Total capsule height = Height + 2*Radius.</param>
  /// <param name="Slices">Number of radial subdivisions around the Y axis.</param>
  /// <param name="Stacks">Number of subdivisions along the cylinder height and also used for each hemisphere (from equator to pole).</param>
  /// <remarks>The capsule is centered vertically. Normals are smooth across the cylinder–hemisphere transition.
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
  /// <summary>Creates an icosphere (subdivided icosahedron) with optional hemisphere clipping.</summary>
  /// <param name="Vertices">Output array of vertex structures (position, normal, texcoord, tangent, bitangent).</param>
  /// <param name="Indices">Output array of triangle indices (GLuint) referencing vertices.</param>
  /// <param name="Radius">Radius of the sphere.</param>
  /// <param name="Subdivisions">Number of subdivision iterations. Each subdivision quadruples the triangle count.</param>
  /// <param name="Hemisphere">If True, only the upper half (Y >= 0) of the icosphere is generated.</param>
  /// <remarks>The icosphere starts from an icosahedron and subdivides each triangle edge, normalizing vertices to the sphere surface.
  ///  This produces a more even triangle distribution than a UV sphere. Normals are smooth. UV coordinates are computed
  ///  spherically (U = atan2(z,x)/2PI+0.5, V = asin(y/R)/PI+0.5). When Hemisphere=True, the resulting mesh is open at the equator.</remarks>
//-------------------------------------------------------------------------------
procedure CreateIcosphereVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Radius: Single; Subdivisions: Integer; Hemisphere: Boolean = False);

//-------------------------------------------------------------------------------
  /// <summary>Generates a geodesic dome (half icosphere) with a flat bottom cap.</summary>
  /// <param name="Vertices">Output vertex array with positions, normals, and UVs for the dome and its flat cap.</param>
  /// <param name="Indices">Output index array.</param>
  /// <param name="Radius">Radius of the dome.</param>
  /// <param name="Subdivisions">Number of subdivision iterations for the underlying icosphere.</param>
  /// <remarks>This procedure creates a hemisphere using <c>CreateIcosphereVertices</c> with Hemisphere=True,
  ///  then adds a triangle fan to close the bottom opening. The bottom cap vertices are flattened to the lowest Y
  ///  coordinate (the equator) and have a downward normal (0,-1,0). UVs for the cap are projected from the XZ plane.
  ///  The result is a closed, watertight geodesic dome suitable for terrain, planetarium domes, or architectural elements.</remarks>
//-------------------------------------------------------------------------------
procedure CreateGeodesicDomeVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Radius: Single; Subdivisions: Integer);

//-------------------------------------------------------------------------------
  /// <summary>Gizmo (3-axis translation widget) with a central sphere and three arrows.
  /// Center: sphere of radius CenterRadius.
  /// Each arrow: cylinder (shaft) + cone (tip) along positive axis.</summary>
  /// <param name="ArrowLength">Total length from center to arrow tip.</param>
  /// <param name="ShaftRadius">Radius of the cylindrical shaft.</param>
  /// <param name="TipRadius">Radius at the base of the cone (usually > ShaftRadius for a
  ///   classic arrow look, can be equal or slightly larger).</param>
  /// <param name="TipLength">Length of the conical tip.</param>
  /// <param name="Slices">Radial subdivisions (around each axis).</param>
  /// <param name="Stacks">Axial subdivisions for cylinder/cone and sphere resolution.</param>
  /// <remarks>The central sphere radius is automatically set to 1.5 × ShaftRadius for a
  ///   balanced appearance, but you can easily change it inside the procedure.</remarks>
//-------------------------------------------------------------------------------
procedure CreateGizmoVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  ArrowLength, ShaftRadius, TipRadius, TipLength: Single; Slices, Stacks: Integer);

//-------------------------------------------------------------------------------
  /// <summary>Generate a single arrow (cylinder shaft + cone tip) as an indexed mesh.
  /// Arrow points upward (positive Y). Base at Y = 0, tip at Y = ShaftLength + TipLength.</summary>
  /// <param name="ShaftLength"> : length of the cylindrical part</param>
  /// <param name="TipLength">   : length of the conical tip</param>
  /// <param name="ShaftRadius"> : radius of the cylinder</param>
  /// <param name="TipRadius">   : radius at the base of the cone (usually larger than ShaftRadius)</param>
  /// <param name="Slices">      : radial subdivisions (around the Y axis)</param>
  /// <param name="Stacks">      : axial subdivisions for both cylinder and cone</param>
//-------------------------------------------------------------------------------
procedure CreateArrowVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  ShaftLength, TipLength, ShaftRadius, TipRadius: Single; Slices, Stacks: Integer);

implementation

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

constructor TTriplet.Create(A, B, C: Integer);
begin
  I0 := A;
  I1 := B;
  I2 := C;
end;

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
        vert.TexCoord := Vector2(x / WidthSegments, z / DepthSegments);
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

{-------------------------------------------------------------------------------
  Cube with subdivisions (width, height, depth stacks)
  Each face is generated independently (hard edges), but vertices are shared
  within each face grid. Indices form two triangles per quad.
-------------------------------------------------------------------------------}
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
        v0.TexCoord := Vector2(i / WidthStacks, j / HeightStacks);
        v0.Tangent := Vector3(0,0,0);
        v0.Bitangent := Vector3(0,0,0);
        idx0 := Builder.AddVertex(v0);

        // bottom-right
        v1.Position := Vector3(left + (i+1) * Width / WidthStacks, bottom + j * Height / HeightStacks, front);
        v1.Normal := Vector3(0, 0, 1);
        v1.TexCoord := Vector2((i+1) / WidthStacks, j / HeightStacks);
        v1.Tangent := Vector3(0,0,0);
        v1.Bitangent := Vector3(0,0,0);
        idx1 := Builder.AddVertex(v1);

        // top-right
        v2.Position := Vector3(left + (i+1) * Width / WidthStacks, bottom + (j+1) * Height / HeightStacks, front);
        v2.Normal := Vector3(0, 0, 1);
        v2.TexCoord := Vector2((i+1) / WidthStacks, (j+1) / HeightStacks);
        v2.Tangent := Vector3(0,0,0);
        v2.Bitangent := Vector3(0,0,0);
        idx2 := Builder.AddVertex(v2);

        // top-left
        v3.Position := Vector3(left + i * Width / WidthStacks, bottom + (j+1) * Height / HeightStacks, front);
        v3.Normal := Vector3(0, 0, 1);
        v3.TexCoord := Vector2(i / WidthStacks, (j+1) / HeightStacks);
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
        v0.TexCoord := Vector2(i / WidthStacks, j / HeightStacks);
        v0.Tangent := Vector3(0,0,0);
        v0.Bitangent := Vector3(0,0,0);
        idx0 := Builder.AddVertex(v0);

        v1.Position := Vector3(left + (i+1) * Width / WidthStacks, bottom + j * Height / HeightStacks, back);
        v1.Normal := Vector3(0, 0, -1);
        v1.TexCoord := Vector2((i+1) / WidthStacks, j / HeightStacks);
        v1.Tangent := Vector3(0,0,0);
        v1.Bitangent := Vector3(0,0,0);
        idx1 := Builder.AddVertex(v1);

        v2.Position := Vector3(left + (i+1) * Width / WidthStacks, bottom + (j+1) * Height / HeightStacks, back);
        v2.Normal := Vector3(0, 0, -1);
        v2.TexCoord := Vector2((i+1) / WidthStacks, (j+1) / HeightStacks);
        v2.Tangent := Vector3(0,0,0);
        v2.Bitangent := Vector3(0,0,0);
        idx2 := Builder.AddVertex(v2);

        v3.Position := Vector3(left + i * Width / WidthStacks, bottom + (j+1) * Height / HeightStacks, back);
        v3.Normal := Vector3(0, 0, -1);
        v3.TexCoord := Vector2(i / WidthStacks, (j+1) / HeightStacks);
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
        v0.TexCoord := Vector2(i / DepthStacks, j / HeightStacks);
        v0.Tangent := Vector3(0,0,0);
        v0.Bitangent := Vector3(0,0,0);
        idx0 := Builder.AddVertex(v0);

        v1.Position := Vector3(right, bottom + j * Height / HeightStacks, back + (i+1) * Depth / DepthStacks);
        v1.Normal := Vector3(1, 0, 0);
        v1.TexCoord := Vector2((i+1) / DepthStacks, j / HeightStacks);
        v1.Tangent := Vector3(0,0,0);
        v1.Bitangent := Vector3(0,0,0);
        idx1 := Builder.AddVertex(v1);

        v2.Position := Vector3(right, bottom + (j+1) * Height / HeightStacks, back + (i+1) * Depth / DepthStacks);
        v2.Normal := Vector3(1, 0, 0);
        v2.TexCoord := Vector2((i+1) / DepthStacks, (j+1) / HeightStacks);
        v2.Tangent := Vector3(0,0,0);
        v2.Bitangent := Vector3(0,0,0);
        idx2 := Builder.AddVertex(v2);

        v3.Position := Vector3(right, bottom + (j+1) * Height / HeightStacks, back + i * Depth / DepthStacks);
        v3.Normal := Vector3(1, 0, 0);
        v3.TexCoord := Vector2(i / DepthStacks, (j+1) / HeightStacks);
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
        v0.TexCoord := Vector2(i / DepthStacks, j / HeightStacks);
        v0.Tangent := Vector3(0,0,0);
        v0.Bitangent := Vector3(0,0,0);
        idx0 := Builder.AddVertex(v0);

        v1.Position := Vector3(left, bottom + j * Height / HeightStacks, back + (i+1) * Depth / DepthStacks);
        v1.Normal := Vector3(-1, 0, 0);
        v1.TexCoord := Vector2((i+1) / DepthStacks, j / HeightStacks);
        v1.Tangent := Vector3(0,0,0);
        v1.Bitangent := Vector3(0,0,0);
        idx1 := Builder.AddVertex(v1);

        v2.Position := Vector3(left, bottom + (j+1) * Height / HeightStacks, back + (i+1) * Depth / DepthStacks);
        v2.Normal := Vector3(-1, 0, 0);
        v2.TexCoord := Vector2((i+1) / DepthStacks, (j+1) / HeightStacks);
        v2.Tangent := Vector3(0,0,0);
        v2.Bitangent := Vector3(0,0,0);
        idx2 := Builder.AddVertex(v2);

        v3.Position := Vector3(left, bottom + (j+1) * Height / HeightStacks, back + i * Depth / DepthStacks);
        v3.Normal := Vector3(-1, 0, 0);
        v3.TexCoord := Vector2(i / DepthStacks, (j+1) / HeightStacks);
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
        v0.TexCoord := Vector2(i / WidthStacks, j / DepthStacks);
        v0.Tangent := Vector3(0,0,0);
        v0.Bitangent := Vector3(0,0,0);
        idx0 := Builder.AddVertex(v0);

        v1.Position := Vector3(left + (i+1) * Width / WidthStacks, top, back + j * Depth / DepthStacks);
        v1.Normal := Vector3(0, 1, 0);
        v1.TexCoord := Vector2((i+1) / WidthStacks, j / DepthStacks);
        v1.Tangent := Vector3(0,0,0);
        v1.Bitangent := Vector3(0,0,0);
        idx1 := Builder.AddVertex(v1);

        v2.Position := Vector3(left + (i+1) * Width / WidthStacks, top, back + (j+1) * Depth / DepthStacks);
        v2.Normal := Vector3(0, 1, 0);
        v2.TexCoord := Vector2((i+1) / WidthStacks, (j+1) / DepthStacks);
        v2.Tangent := Vector3(0,0,0);
        v2.Bitangent := Vector3(0,0,0);
        idx2 := Builder.AddVertex(v2);

        v3.Position := Vector3(left + i * Width / WidthStacks, top, back + (j+1) * Depth / DepthStacks);
        v3.Normal := Vector3(0, 1, 0);
        v3.TexCoord := Vector2(i / WidthStacks, (j+1) / DepthStacks);
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
        v0.TexCoord := Vector2(i / WidthStacks, j / DepthStacks);
        v0.Tangent := Vector3(0,0,0);
        v0.Bitangent := Vector3(0,0,0);
        idx0 := Builder.AddVertex(v0);

        v1.Position := Vector3(left + (i+1) * Width / WidthStacks, bottom, back + j * Depth / DepthStacks);
        v1.Normal := Vector3(0, -1, 0);
        v1.TexCoord := Vector2((i+1) / WidthStacks, j / DepthStacks);
        v1.Tangent := Vector3(0,0,0);
        v1.Bitangent := Vector3(0,0,0);
        idx1 := Builder.AddVertex(v1);

        v2.Position := Vector3(left + (i+1) * Width / WidthStacks, bottom, back + (j+1) * Depth / DepthStacks);
        v2.Normal := Vector3(0, -1, 0);
        v2.TexCoord := Vector2((i+1) / WidthStacks, (j+1) / DepthStacks);
        v2.Tangent := Vector3(0,0,0);
        v2.Bitangent := Vector3(0,0,0);
        idx2 := Builder.AddVertex(v2);

        v3.Position := Vector3(left + i * Width / WidthStacks, bottom, back + (j+1) * Depth / DepthStacks);
        v3.Normal := Vector3(0, -1, 0);
        v3.TexCoord := Vector2(i / WidthStacks, (j+1) / DepthStacks);
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

{-------------------------------------------------------------------------------
  Sphere with stacks (vertical) and slices (horizontal).
  Generates indexed vertices with proper UV mapping.
-------------------------------------------------------------------------------}
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
      phi := -PI/2 + i * PI / StackCount;   // -90° to +90°
      v := i / StackCount;                  // V texture coordinate (0 at south pole, 1 at north)
      for j := 0 to SliceCount do
      begin
        theta := j * 2 * PI / SliceCount;   // 0 to 2PI
        u := j / SliceCount;                // U texture coordinate

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

{-------------------------------------------------------------------------------
  Cylinder with side, bottom and top caps (indexed).
-------------------------------------------------------------------------------}
procedure CreateCylinderVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Radius, Height: Single; Slices, Stacks: Integer);
var
  Builder: TVertexBuilder;
  i, j: Integer;
  theta, nextTheta: Single;
  yBottom, yTop, y, nextY: Single;
  x, z, nx, nz, u, v: Single;
  vert: TVertex;
  ringBase, ringNext: array of Integer;
  centerBottomIdx, centerTopIdx: Integer;
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
      v := i / Stacks;
      for j := 0 to Slices do
      begin
        theta := j * 2 * PI / Slices;
        u := j / Slices;
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

    // ----- Bottom cap (triangles fan from center) -----
    centerBottomIdx := Builder.Vertices.Count;
    vert.Position := Vector3(0, yBottom, 0);
    vert.Normal := Vector3(0, -1, 0);
    vert.TexCoord := Vector2(0.5, 0.5);
    vert.Tangent := Vector3(0,0,0);
    vert.Bitangent := Vector3(0,0,0);
    Builder.AddVertex(vert);

    for j := 0 to Slices - 1 do
    begin
      theta := j * 2 * PI / Slices;
      nextTheta := (j+1) * 2 * PI / Slices;
      x := Radius * Cos(theta);
      z := Radius * Sin(theta);
      u := (x/Radius + 1)/2;
      v := (z/Radius + 1)/2;
      vert.Position := Vector3(x, yBottom, z);
      vert.Normal := Vector3(0, -1, 0);
      vert.TexCoord := Vector2(u, v);
      vert.Tangent := Vector3(0,0,0);
      vert.Bitangent := Vector3(0,0,0);
      var idx1 := Builder.AddVertex(vert);

      x := Radius * Cos(nextTheta);
      z := Radius * Sin(nextTheta);
      u := (x/Radius + 1)/2;
      v := (z/Radius + 1)/2;
      vert.Position := Vector3(x, yBottom, z);
      vert.Normal := Vector3(0, -1, 0);
      vert.TexCoord := Vector2(u, v);
      vert.Tangent := Vector3(0,0,0);
      vert.Bitangent := Vector3(0,0,0);
      var idx2 := Builder.AddVertex(vert);

      Builder.AddTriangle(centerBottomIdx, idx1, idx2);
    end;

    // ----- Top cap -----
    centerTopIdx := Builder.Vertices.Count;
    vert.Position := Vector3(0, yTop, 0);
    vert.Normal := Vector3(0, 1, 0);
    vert.TexCoord := Vector2(0.5, 0.5);
    vert.Tangent := Vector3(0,0,0);
    vert.Bitangent := Vector3(0,0,0);
    Builder.AddVertex(vert);

    for j := 0 to Slices - 1 do
    begin
      theta := j * 2 * PI / Slices;
      nextTheta := (j+1) * 2 * PI / Slices;
      x := Radius * Cos(theta);
      z := Radius * Sin(theta);
      u := (x/Radius + 1)/2;
      v := (z/Radius + 1)/2;
      vert.Position := Vector3(x, yTop, z);
      vert.Normal := Vector3(0, 1, 0);
      vert.TexCoord := Vector2(u, v);
      vert.Tangent := Vector3(0,0,0);
      vert.Bitangent := Vector3(0,0,0);
      var idx1 := Builder.AddVertex(vert);

      x := Radius * Cos(nextTheta);
      z := Radius * Sin(nextTheta);
      u := (x/Radius + 1)/2;
      v := (z/Radius + 1)/2;
      vert.Position := Vector3(x, yTop, z);
      vert.Normal := Vector3(0, 1, 0);
      vert.TexCoord := Vector2(u, v);
      vert.Tangent := Vector3(0,0,0);
      vert.Bitangent := Vector3(0,0,0);
      var idx2 := Builder.AddVertex(vert);

      Builder.AddTriangle(centerTopIdx, idx1, idx2);
    end;

    Vertices := Builder.Vertices.ToArray;
    Indices := Builder.Indices.ToArray;
  finally
    Builder.Vertices.Free;
    Builder.Indices.Free;
  end;
end;

{-------------------------------------------------------------------------------
  Capsule with cylindrical body and hemispherical end caps.
  Total height = Height + 2*Radius.
  Slices = radial subdivisions, Stacks = subdivisions along cylinder height
  and also number of stacks from equator to pole on each hemisphere.
-------------------------------------------------------------------------------}
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
      v := i / Stacks;   // V texture coordinate (0 at bottom, 1 at top)

      for j := 0 to Slices do
      begin
        theta := j * 2 * PI / Slices;
        u := j / Slices;   // U texture coordinate (0..1 around)

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
      v := i / Stacks;   // V: 0 at south pole, 1 at equator

      for j := 0 to Slices do
      begin
        theta := j * 2 * PI / Slices;
        u := j / Slices;

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
      v := i / Stacks;   // V: 0 at equator, 1 at north pole

      for j := 0 to Slices do
      begin
        theta := j * 2 * PI / Slices;
        u := j / Slices;

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

{-------------------------------------------------------------------------------
  Torus (donut) with major radius R, minor radius r.
  MajorSegments = divisions around the ring, MinorSegments = divisions around the tube.
  UV mapping: U around the ring (0..1), V around the tube cross-section (0..1).
-------------------------------------------------------------------------------}
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
      u := i / MajorSegments;               // U coordinate (0..1)

      cosTheta := Cos(theta);
      sinTheta := Sin(theta);

      for j := 0 to MinorSegments do
      begin
        phi := j * phiStep;
        v := j / MinorSegments;             // V coordinate (0..1)

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

{-------------------------------------------------------------------------------
  Cone with base radius, height, and polygonal base (sides).
  Tip at y = +Height/2, base at y = -Height/2.
  Sides = radial subdivisions, Stacks = vertical subdivisions.
-------------------------------------------------------------------------------}
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
      v := i / Stacks;   // V texture: 0 at base, 1 at tip

      // radius at this height: linear from Radius at base to 0 at tip
      r := Radius * (1 - i / Stacks);

      for j := 0 to Sides do
      begin
        theta := j * 2 * PI / Sides;
        u := j / Sides;   // U texture around circumference

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
    vert.TexCoord := Vector2(0.5, 0.5);
    vert.Tangent  := Vector3(0, 0, 0);
    vert.Bitangent := Vector3(0, 0, 0);
    Builder.AddVertex(vert);

    for j := 0 to Sides - 1 do
    begin
      theta := j * 2 * PI / Sides;
      nextTheta := (j + 1) * 2 * PI / Sides;

      x := Radius * Cos(theta);
      z := Radius * Sin(theta);
      u := (x / Radius + 1) / 2;
      v := (z / Radius + 1) / 2;
      vert.Position := Vector3(x, -Height/2, z);
      vert.Normal   := Vector3(0, -1, 0);
      vert.TexCoord := Vector2(u, v);
      vert.Tangent  := Vector3(0, 0, 0);
      vert.Bitangent := Vector3(0, 0, 0);
      idx1 := Builder.AddVertex(vert);

      x := Radius * Cos(nextTheta);
      z := Radius * Sin(nextTheta);
      u := (x / Radius + 1) / 2;
      v := (z / Radius + 1) / 2;
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

{-------------------------------------------------------------------------------
  Prism with polygonal base (sides), radius, height.
  Sides = number of edges, Stacks = vertical subdivisions.
  Caps are triangle fans.
-------------------------------------------------------------------------------}
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
      v := i / Stacks;   // V coordinate along height

      for j := 0 to Sides do
      begin
        theta := j * 2 * PI / Sides;
        u := j / Sides;   // U coordinate around the prism

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
    vert.TexCoord := Vector2(0.5, 0.5);
    vert.Tangent  := Vector3(0, 0, 0);
    vert.Bitangent := Vector3(0, 0, 0);
    Builder.AddVertex(vert);

    SetLength(baseVertices, Sides);
    for j := 0 to Sides - 1 do
    begin
      theta := j * 2 * PI / Sides;
      x := Radius * Cos(theta);
      z := Radius * Sin(theta);
      u := (x / Radius + 1) / 2;
      v := (z / Radius + 1) / 2;

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
    vert.TexCoord := Vector2(0.5, 0.5);
    vert.Tangent  := Vector3(0, 0, 0);
    vert.Bitangent := Vector3(0, 0, 0);
    Builder.AddVertex(vert);

    for j := 0 to Sides - 1 do
    begin
      theta := j * 2 * PI / Sides;
      x := Radius * Cos(theta);
      z := Radius * Sin(theta);
      u := (x / Radius + 1) / 2;
      v := (z / Radius + 1) / 2;

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

procedure CreateIcosphereVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Radius: Single; Subdivisions: Integer; Hemisphere: Boolean = False);
var
  Builder: TVertexBuilder;
  MidPointCache: TDictionary<TEdgeKey, Integer>;
  InputVertices: TList<TVector3>;
  InputFaces: TList<TArray<Integer>>; // each item is array[0..2] of Integer
  i, j, k: Integer;
  v0, v1, v2: TVector3;
  mid01, mid12, mid20: TVector3;
  idxA, idxB, idxC: Integer;
  key01, key12, key20: TEdgeKey;
  FaceKept: TArray<Boolean>;
  OldToNew: TDictionary<Integer, Integer>;
  p, norm: TVector3;
  vert: TVertex;
  newIdx: Integer;
begin
  Builder.Vertices := TList<TVertex>.Create;
  Builder.Indices := TList<GLuint>.Create;
  MidPointCache := TDictionary<TEdgeKey, Integer>.Create;
  InputVertices := TList<TVector3>.Create;
  InputFaces := TList<TArray<Integer>>.Create;
  try
    // Load icosahedron vertices
    for i := 0 to 11 do
      InputVertices.Add(ICOSAHEDRON_VERTICES[i]);

    // Load faces as array[0..2] of Integer
    for i := 0 to 19 do
    begin
      var face: TArray<Integer>;
      SetLength(face, 3);
      face[0] := ICOSAHEDRON_INDICES[i][0];
      face[1] := ICOSAHEDRON_INDICES[i][1];
      face[2] := ICOSAHEDRON_INDICES[i][2];
      InputFaces.Add(face);
    end;

    // Subdivision
    for i := 1 to Subdivisions do
    begin
      MidPointCache.Clear;
      var NewVertices := TList<TVector3>.Create;
      var NewFaces := TList<TArray<Integer>>.Create;
      try
        NewVertices.AddRange(InputVertices);

        for j := 0 to InputFaces.Count - 1 do
        begin
          var tri := InputFaces[j];
          v0 := InputVertices[tri[0]];
          v1 := InputVertices[tri[1]];
          v2 := InputVertices[tri[2]];

          key01 := EdgeKey(tri[0], tri[1]);
          if not MidPointCache.TryGetValue(key01, idxA) then
          begin
            mid01 := (v0 + v1).Normalize;
            idxA := NewVertices.Count;
            NewVertices.Add(mid01);
            MidPointCache.Add(key01, idxA);
          end;

          key12 := EdgeKey(tri[1], tri[2]);
          if not MidPointCache.TryGetValue(key12, idxB) then
          begin
            mid12 := (v1 + v2).Normalize;
            idxB := NewVertices.Count;
            NewVertices.Add(mid12);
            MidPointCache.Add(key12, idxB);
          end;

          key20 := EdgeKey(tri[2], tri[0]);
          if not MidPointCache.TryGetValue(key20, idxC) then
          begin
            mid20 := (v2 + v0).Normalize;
            idxC := NewVertices.Count;
            NewVertices.Add(mid20);
            MidPointCache.Add(key20, idxC);
          end;

          // Create 4 new faces
          var f1, f2, f3, f4: TArray<Integer>;
          SetLength(f1, 3); f1[0] := tri[0]; f1[1] := idxA; f1[2] := idxC;
          SetLength(f2, 3); f2[0] := tri[1]; f2[1] := idxB; f2[2] := idxA;
          SetLength(f3, 3); f3[0] := tri[2]; f3[1] := idxC; f3[2] := idxB;
          SetLength(f4, 3); f4[0] := idxA; f4[1] := idxB; f4[2] := idxC;
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

    // Determine which faces to keep (for hemisphere)
    SetLength(FaceKept, InputFaces.Count);
    if Hemisphere then
    begin
      for i := 0 to InputFaces.Count - 1 do
      begin
        var tri := InputFaces[i];
        var center := (InputVertices[tri[0]] +
                       InputVertices[tri[1]] +
                       InputVertices[tri[2]]) / 3;
        FaceKept[i] := center.Y >= -0.001;
      end;
    end
    else
      for i := 0 to InputFaces.Count - 1 do
        FaceKept[i] := True;

    // Build final vertices and indices
    OldToNew := TDictionary<Integer, Integer>.Create;
    try
      for i := 0 to InputFaces.Count - 1 do
      begin
        if not FaceKept[i] then Continue;
        var tri := InputFaces[i];
        for j := 0 to 2 do
        begin
          if not OldToNew.ContainsKey(tri[j]) then
          begin
            p := InputVertices[tri[j]] * Radius;
            norm := p.Normalize;
            vert.Position := p;
            vert.Normal := norm;
            // Simple UV mapping (spherical)
            vert.TexCoord := Vector2(
              System.Math.ArcTan2(p.Z, p.X) / (2*PI) + 0.5,
              ArcSin(p.Y / Radius) / PI + 0.5
            );
            vert.Tangent := Vector3(0,0,0);
            vert.Bitangent := Vector3(0,0,0);
            newIdx := Builder.AddVertex(vert);
            OldToNew.Add(tri[j], newIdx);
          end;
        end;
      end;

      for i := 0 to InputFaces.Count - 1 do
      begin
        if not FaceKept[i] then Continue;
        var tri := InputFaces[i];
        Builder.AddTriangle(OldToNew[tri[0]], OldToNew[tri[1]], OldToNew[tri[2]]);
      end;
    finally
      OldToNew.Free;
    end;

    Vertices := Builder.Vertices.ToArray;
    Indices := Builder.Indices.ToArray;
  finally
    Builder.Vertices.Free;
    Builder.Indices.Free;
    MidPointCache.Free;
    InputVertices.Free;
    InputFaces.Free;
  end;
end;

{-------------------------------------------------------------------------------
  Geodesic dome = half icosphere (Hemisphere=True) with optional bottom cap.
  Please add a simple flat cap using the lowest edge ring.
-------------------------------------------------------------------------------}
procedure CreateGeodesicDomeVertices(out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>;
  Radius: Single; Subdivisions: Integer);
var
  DomeVertices: TArray<TVertex>;
  DomeIndices: TArray<GLuint>;
  Builder: TVertexBuilder;
  i, j: Integer;
  RimIndices: TList<Integer>;
  Angles: TList<Double>;
  CenterIdx: Integer;
  Epsilon: Single;
  MinY: Single;
  v: TVertex;
  SortedOrder: TArray<Integer>;
  NewRimIndices: TArray<Integer>;
begin
  // Generate the open hemisphere (icosphere with hemisphere = True)
  CreateIcosphereVertices(DomeVertices, DomeIndices, Radius, Subdivisions, True);

  Builder.Vertices := TList<TVertex>.Create;
  Builder.Indices := TList<GLuint>.Create;
  try
    // Add all dome vertices and indices
    for i := 0 to Length(DomeVertices) - 1 do
      Builder.AddVertex(DomeVertices[i]);
    for i := 0 to Length(DomeIndices) - 1 do
      Builder.Indices.Add(DomeIndices[i]);

    if Builder.Vertices.Count = 0 then
      Exit;

    // Find the minimum Y coordinate (lowest point of the dome)
    MinY := Builder.Vertices[0].Position.Y;
    for i := 1 to Builder.Vertices.Count - 1 do
      if Builder.Vertices[i].Position.Y < MinY then
        MinY := Builder.Vertices[i].Position.Y;

    // Collect vertices that lie on or near the bottom edge (rim)
    Epsilon := 0.01 * Radius;
    RimIndices := TList<Integer>.Create;
    Angles := TList<Double>.Create;
    try
      for i := 0 to Builder.Vertices.Count - 1 do
        if Builder.Vertices[i].Position.Y <= MinY + Epsilon then
        begin
          RimIndices.Add(i);
          Angles.Add(System.Math.ArcTan2(Builder.Vertices[i].Position.Z, Builder.Vertices[i].Position.X));
        end;

      if RimIndices.Count < 3 then
        Exit; // Not enough vertices for a cap

      // Sort rim indices by angle around Y axis
      SetLength(SortedOrder, RimIndices.Count);
      for i := 0 to RimIndices.Count - 1 do
        SortedOrder[i] := i;
      for i := 0 to RimIndices.Count - 2 do
        for j := i + 1 to RimIndices.Count - 1 do
          if Angles[SortedOrder[i]] > Angles[SortedOrder[j]] then
          begin
            var Tmp := SortedOrder[i];
            SortedOrder[i] := SortedOrder[j];
            SortedOrder[j] := Tmp;
          end;

      // Create new vertices for the cap (flattened to Y = MinY, normal = (0,-1,0))
      SetLength(NewRimIndices, RimIndices.Count);
      for i := 0 to RimIndices.Count - 1 do
      begin
        var OrigIdx := RimIndices[SortedOrder[i]];
        var OrigPos := Builder.Vertices[OrigIdx].Position;
        v.Position := Vector3(OrigPos.X, MinY, OrigPos.Z);
        v.Normal := Vector3(0, -1, 0);
        // Simple UV mapping: map XZ plane to [0,1]²
        v.TexCoord := Vector2((OrigPos.X / Radius + 1) * 0.5, (OrigPos.Z / Radius + 1) * 0.5);
        v.Tangent := Vector3(0, 0, 0);
        v.Bitangent := Vector3(0, 0, 0);
        NewRimIndices[i] := Builder.AddVertex(v);
      end;

      // Add center vertex of the cap
      v.Position := Vector3(0, MinY, 0);
      v.Normal := Vector3(0, -1, 0);
      v.TexCoord := Vector2(0.5, 0.5);
      v.Tangent := Vector3(0, 0, 0);
      v.Bitangent := Vector3(0, 0, 0);
      CenterIdx := Builder.AddVertex(v);

      // Create triangle fan (center, next rim, current rim) for correct outward winding (downward)
      for i := 0 to RimIndices.Count - 1 do
      begin
        var iNext := (i + 1) mod RimIndices.Count;
        Builder.AddTriangle(CenterIdx, NewRimIndices[iNext], NewRimIndices[i]);
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
end;

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
    // centre sphere radius – you can adjust the factor to your taste
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
    //    cap would overlap – you may disable one of them.
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

end.
