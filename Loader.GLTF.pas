unit Loader.GLTF;

interface

uses
  System.Classes, System.SysUtils,
  Engine.Types, Engine.Animation, Neslib.FastMath, dglOpenGL, PasGLTF;

type
  TGLTFModelMeshData = record
    Name: string;
    Vertices: TArray<TVertex>;
    Indices: TArray<GLuint>;
    MaterialName: string;
    IsSkinned: Boolean;
    SkinWeights: TArray<TVertexSkinWeights>;
    JointBoneIndices: TArray<Integer>;
    InverseBindMatrices: TArray<TMatrix4>;
    BindMeshMatrix: TMatrix4;
  end;

{ Returns a single merged mesh (all geometry combined) }
procedure LoadGLTFFromFile(const AFileName: string;
  out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>);

{ Returns multiple meshes – one per primitive, each with its own vertex/index arrays }
procedure LoadGLTFFileV2(const AFileName: string;
  out VerticesArr: TArray<TArray<TVertex>>; out IndicesArr: TArray<TArray<GLuint>>); overload;

{ Returns multiple meshes plus the glTF material name referenced by each mesh
  primitive. No engine materials or textures are created here. }
procedure LoadGLTFFileV2(const AFileName: string;
  out VerticesArr: TArray<TArray<TVertex>>; out IndicesArr: TArray<TArray<GLuint>>;
  out MaterialNames: TArray<string>); overload;

{ Loads static and skinned primitives together. Animator is owned by the caller
  and is nil when the file has no valid skin. }
procedure LoadGLTFModelFile(const AFileName: string;
  out Meshes: TArray<TGLTFModelMeshData>; out Animator: TSkeletonAnimator);

{ Loads only animation clips and remaps their target nodes onto an existing
  skeleton by bone name. Returned clips are owned by the caller. }
procedure LoadGLTFAnimationClips(const AFileName: string;
  ATargetSkeleton: TSkeleton; out Clips: TArray<TSkeletonAnimationClip>);

{ Used only to migrate skeletal meshes saved before the legacy 3ds Max pivot
  correction was introduced. Invalid or unavailable files return False. }
function GLTFUsesLegacyKhronos3DSMaxSkinLayout(
  const AFileName: string): Boolean;

implementation

uses
  System.Math,
  Utility.Functions,
  PasJSON;

type
  TTextureCoordinateMapping = record
    Offset: TVector2;
    Scale: TVector2;
    Rotation: Single;
    TexCoordSet: Integer;
  end;

  TMeshData = record
    Name: string;
    Vertices: TArray<TVertex>;
    Indices: TArray<GLuint>;
    MaterialIndex: Integer;
    IsSkinned: Boolean;
    SkinWeights: TArray<TVertexSkinWeights>;
    JointBoneIndices: TArray<Integer>;
    InverseBindMatrices: TArray<TMatrix4>;
    BindMeshMatrix: TMatrix4;
  end;

procedure InitializeTextureCoordinateMapping(
  out Mapping: TTextureCoordinateMapping);
begin
  Mapping.Offset := Vector2(0.0, 0.0);
  Mapping.Scale := Vector2(1.0, 1.0);
  Mapping.Rotation := 0.0;
  Mapping.TexCoordSet := 0;
end;

procedure ReadTextureCoordinateMapping(
  const TextureInfo: TPasGLTF.TMaterial.TTexture;
  out Mapping: TTextureCoordinateMapping);
var
  ExtensionItem, ValueItem: TPasJSONItem;
  ExtensionObject: TPasJSONItemObject;
  ValueArray: TPasJSONItemArray;
begin
  InitializeTextureCoordinateMapping(Mapping);
  if not Assigned(TextureInfo) then
    Exit;

  Mapping.TexCoordSet := TextureInfo.TexCoord;
  ExtensionItem := TextureInfo.Extensions.Properties['KHR_texture_transform'];
  if not (Assigned(ExtensionItem) and
    (ExtensionItem is TPasJSONItemObject)) then
    Exit;

  ExtensionObject := TPasJSONItemObject(ExtensionItem);

  ValueItem := ExtensionObject.Properties['offset'];
  if Assigned(ValueItem) and (ValueItem is TPasJSONItemArray) then
  begin
    ValueArray := TPasJSONItemArray(ValueItem);
    if ValueArray.Count = 2 then
    begin
      Mapping.Offset.X := TPasJSON.GetNumber(ValueArray.Items[0], 0.0);
      Mapping.Offset.Y := TPasJSON.GetNumber(ValueArray.Items[1], 0.0);
    end;
  end;

  ValueItem := ExtensionObject.Properties['scale'];
  if Assigned(ValueItem) and (ValueItem is TPasJSONItemArray) then
  begin
    ValueArray := TPasJSONItemArray(ValueItem);
    if ValueArray.Count = 2 then
    begin
      Mapping.Scale.X := TPasJSON.GetNumber(ValueArray.Items[0], 1.0);
      Mapping.Scale.Y := TPasJSON.GetNumber(ValueArray.Items[1], 1.0);
    end;
  end;

  Mapping.Rotation := TPasJSON.GetNumber(
    ExtensionObject.Properties['rotation'], 0.0);
  Mapping.TexCoordSet := TPasJSON.GetInt64(
    ExtensionObject.Properties['texCoord'], Mapping.TexCoordSet);
end;

procedure GetMaterialTextureCoordinateMapping(
  const Doc: TPasGLTF.TDocument; MaterialIndex: Integer;
  out Mapping: TTextureCoordinateMapping);
var
  Material: TPasGLTF.TMaterial;
  TextureInfo: TPasGLTF.TMaterial.TTexture;
begin
  InitializeTextureCoordinateMapping(Mapping);
  if (MaterialIndex < 0) or (MaterialIndex >= Doc.Materials.Count) then
    Exit;

  Material := Doc.Materials[MaterialIndex];
  TextureInfo := nil;
  if not Material.PBRMetallicRoughness.BaseColorTexture.Empty then
    TextureInfo := Material.PBRMetallicRoughness.BaseColorTexture
  else if not Material.NormalTexture.Empty then
    TextureInfo := Material.NormalTexture
  else if not Material.PBRMetallicRoughness.MetallicRoughnessTexture.Empty then
    TextureInfo := Material.PBRMetallicRoughness.MetallicRoughnessTexture
  else if not Material.OcclusionTexture.Empty then
    TextureInfo := Material.OcclusionTexture
  else if not Material.EmissiveTexture.Empty then
    TextureInfo := Material.EmissiveTexture;

  if Assigned(TextureInfo) then
    ReadTextureCoordinateMapping(TextureInfo, Mapping);
end;

function ApplyTextureCoordinateMapping(const TexCoord: TVector2;
  const Mapping: TTextureCoordinateMapping): TVector2;
var
  Scaled: TVector2;
  SinRotation, CosRotation: Single;
begin
  Scaled := Vector2(
    TexCoord.X * Mapping.Scale.X,
    TexCoord.Y * Mapping.Scale.Y);
  SinRotation := System.Sin(Mapping.Rotation);
  CosRotation := System.Cos(Mapping.Rotation);
  Result := Vector2(
    Mapping.Offset.X + CosRotation * Scaled.X - SinRotation * Scaled.Y,
    Mapping.Offset.Y + SinRotation * Scaled.X + CosRotation * Scaled.Y);
end;

{ ---------------------------------------------------------------------------- }
{ Generate planar UVs for a triangle (used when TEXCOORD_0 is missing) }
procedure GeneratePlanarUVs(const v0, v1, v2, normal: TVector3;
  out uv0, uv1, uv2: TVector2);
var
  absN: TVector3;
  uAxis, vAxis: TVector3;
begin
  absN := Vector3(Abs(normal.X), Abs(normal.Y), Abs(normal.Z));
  if (absN.X >= absN.Y) and (absN.X >= absN.Z) then
  begin
    uAxis := Vector3(0, 0, 1);
    vAxis := Vector3(0, 1, 0);
  end
  else if (absN.Y >= absN.X) and (absN.Y >= absN.Z) then
  begin
    uAxis := Vector3(1, 0, 0);
    vAxis := Vector3(0, 0, 1);
  end
  else
  begin
    uAxis := Vector3(1, 0, 0);
    vAxis := Vector3(0, 1, 0);
  end;
  uv0 := Vector2(v0.Dot(uAxis), v0.Dot(vAxis));
  uv1 := Vector2(v1.Dot(uAxis), v1.Dot(vAxis));
  uv2 := Vector2(v2.Dot(uAxis), v2.Dot(vAxis));
end;

procedure BuildTangentBasis(var Vertices: TArray<TVertex>;
  const Indices: TArray<GLuint>);
const
  VECTOR_EPSILON = 1.0e-10;
  UV_EPSILON = 1.0e-8;
var
  AccumTangents, AccumBitangents: TArray<TVector3>;
  TriangleCount, TriangleIndex, I0, I1, I2, I: Integer;
  Edge1, Edge2: TVector3;
  DeltaUV1, DeltaUV2: TVector2;
  Tangent, Bitangent, Normal, Axis: TVector3;
  Determinant, InvDeterminant: Single;

  function TriangleVertexIndex(AOffset: Integer): Integer;
  begin
    if Length(Indices) > 0 then
      Result := Integer(Indices[TriangleIndex * 3 + AOffset])
    else
      Result := TriangleIndex * 3 + AOffset;
  end;

  function UsableVector(const V: TVector3): Boolean;
  begin
    // A NaN length also fails this comparison.
    Result := V.LengthSquared > VECTOR_EPSILON;
  end;

  function OrthogonalTangent(const N: TVector3): TVector3;
  begin
    if Abs(N.X) < 0.9 then
      Axis := Vector3(1.0, 0.0, 0.0)
    else
      Axis := Vector3(0.0, 1.0, 0.0);
    Result := Axis - N * N.Dot(Axis);
    if not UsableVector(Result) then
      Result := Vector3(0.0, 0.0, 1.0);
    Result := Result.Normalize;
  end;
begin
  if Length(Vertices) = 0 then
    Exit;

  SetLength(AccumTangents, Length(Vertices));
  SetLength(AccumBitangents, Length(Vertices));

  if Length(Indices) > 0 then
    TriangleCount := Length(Indices) div 3
  else
    TriangleCount := Length(Vertices) div 3;

  for TriangleIndex := 0 to TriangleCount - 1 do
  begin
    I0 := TriangleVertexIndex(0);
    I1 := TriangleVertexIndex(1);
    I2 := TriangleVertexIndex(2);
    if (I0 < 0) or (I0 >= Length(Vertices)) or
       (I1 < 0) or (I1 >= Length(Vertices)) or
       (I2 < 0) or (I2 >= Length(Vertices)) then
      Continue;

    Edge1 := Vertices[I1].Position - Vertices[I0].Position;
    Edge2 := Vertices[I2].Position - Vertices[I0].Position;
    DeltaUV1 := Vertices[I1].TexCoord - Vertices[I0].TexCoord;
    DeltaUV2 := Vertices[I2].TexCoord - Vertices[I0].TexCoord;
    // The shared material shader flips V before sampling. Build the tangent
    // basis in that final UV orientation so normal maps use the same axes.
    DeltaUV1.Y := -DeltaUV1.Y;
    DeltaUV2.Y := -DeltaUV2.Y;
    Determinant := DeltaUV1.X * DeltaUV2.Y - DeltaUV1.Y * DeltaUV2.X;

    if Abs(Determinant) > UV_EPSILON then
    begin
      InvDeterminant := 1.0 / Determinant;
      Tangent := (Edge1 * DeltaUV2.Y - Edge2 * DeltaUV1.Y) * InvDeterminant;
      Bitangent := (Edge2 * DeltaUV1.X - Edge1 * DeltaUV2.X) * InvDeterminant;
    end
    else
    begin
      Normal := Edge1.Cross(Edge2);
      if not UsableVector(Normal) then
        Normal := Vertices[I0].Normal;
      if not UsableVector(Normal) then
        Normal := Vector3(0.0, 1.0, 0.0)
      else
        Normal := Normal.Normalize;
      Tangent := OrthogonalTangent(Normal);
      Bitangent := Normal.Cross(Tangent).Normalize;
    end;

    if not UsableVector(Tangent) or not UsableVector(Bitangent) then
      Continue;
    AccumTangents[I0] := AccumTangents[I0] + Tangent;
    AccumTangents[I1] := AccumTangents[I1] + Tangent;
    AccumTangents[I2] := AccumTangents[I2] + Tangent;
    AccumBitangents[I0] := AccumBitangents[I0] + Bitangent;
    AccumBitangents[I1] := AccumBitangents[I1] + Bitangent;
    AccumBitangents[I2] := AccumBitangents[I2] + Bitangent;
  end;

  for I := 0 to High(Vertices) do
  begin
    Normal := Vertices[I].Normal;
    if not UsableVector(Normal) then
      Normal := Vector3(0.0, 1.0, 0.0)
    else
      Normal := Normal.Normalize;

    Tangent := AccumTangents[I] - Normal * AccumTangents[I].Dot(Normal);
    if not UsableVector(Tangent) then
      Tangent := OrthogonalTangent(Normal)
    else
      Tangent := Tangent.Normalize;

    Bitangent := Normal.Cross(Tangent);
    if UsableVector(AccumBitangents[I]) and
       (Bitangent.Dot(AccumBitangents[I]) < 0.0) then
      Bitangent := Bitangent * -1.0;

    Vertices[I].Normal := Normal;
    Vertices[I].Tangent := Tangent;
    Vertices[I].Bitangent := Bitangent.Normalize;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ glTF and this FastMath build are both column-major. Assign columns explicitly
  so conversion does not depend on the scalar Init overload's storage details. }
function ConvertMatrix(const M: TPasGLTF.TMatrix4x4): TMatrix4;
begin
  Result := TMatrix4.Identity;
  Result.Columns[0] := Vector4(M[0], M[1], M[2], M[3]);
  Result.Columns[1] := Vector4(M[4], M[5], M[6], M[7]);
  Result.Columns[2] := Vector4(M[8], M[9], M[10], M[11]);
  Result.Columns[3] := Vector4(M[12], M[13], M[14], M[15]);
end;

{ Check identity (diagonal indices 0,5,10,15 are same in both orders) }
function IsIdentityMatrix(const M: TPasGLTF.TMatrix4x4): Boolean;
const
  EPS = 1e-6;
begin
  Result := (Abs(M[0]  - 1.0) <= EPS) and (Abs(M[5]  - 1.0) <= EPS) and
            (Abs(M[10] - 1.0) <= EPS) and (Abs(M[15] - 1.0) <= EPS) and
            (Abs(M[1]) <= EPS) and (Abs(M[2]) <= EPS) and (Abs(M[3]) <= EPS) and
            (Abs(M[4]) <= EPS) and (Abs(M[6]) <= EPS) and (Abs(M[7]) <= EPS) and
            (Abs(M[8]) <= EPS) and (Abs(M[9]) <= EPS) and (Abs(M[11]) <= EPS) and
            (Abs(M[12]) <= EPS) and (Abs(M[13]) <= EPS) and (Abs(M[14]) <= EPS);
end;

function IsLegacyKhronos3DSMaxExport(const Doc: TPasGLTF.TDocument): Boolean;
const
  EXPORTER_PREFIX = 'khronos gltf exporter for 3dsmax ';
var
  Generator: string;
begin
  Generator := LowerCase(Trim(String(Doc.Asset.Generator)));
  Result := Pos(EXPORTER_PREFIX, Generator) = 1;
end;

function GLTFUsesLegacyKhronos3DSMaxSkinLayout(
  const AFileName: string): Boolean;
var
  Stream: TFileStream;
  Doc: TPasGLTF.TDocument;
begin
  Result := False;
  if not FileExists(AFileName) then
    Exit;

  Stream := nil;
  Doc := nil;
  try
    Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
    Doc := TPasGLTF.TDocument.Create;
    Doc.RootPath := ExtractFilePath(AFileName);
    Doc.LoadFromStream(Stream);
    Result := IsLegacyKhronos3DSMaxExport(Doc);
  except
    Result := False;
  end;
  Doc.Free;
  Stream.Free;
end;

{ ---------------------------------------------------------------------------- }
{ Process node recursively, collecting each primitive as a separate mesh }
procedure ProcessNodeMulti(const Doc: TPasGLTF.TDocument; NodeIdx: Integer;
  const ParentTransform: TMatrix4; var MeshList: TArray<TMeshData>);
var
  Node: TPasGLTF.TNode;
  LocalMat, GlobalMat, NormalMat: TMatrix4;
  TransMat, RotMat, ScaleMat: TMatrix4;
  Mesh: TPasGLTF.TMesh;
  Primitive: TPasGLTF.TMesh.TPrimitive;
  Accessor: TPasGLTF.TAccessor;
  Positions: TPasGLTF.TVector3DynamicArray;
  Normals: TPasGLTF.TVector3DynamicArray;
  TexCoords: TPasGLTF.TVector2DynamicArray;
  Tangents: TPasGLTF.TVector4DynamicArray;
  Joints0, Joints1: TPasGLTF.TUInt32Vector4DynamicArray;
  Weights0, Weights1: TPasGLTF.TVector4DynamicArray;
  InverseMatricesRaw: TPasGLTF.TMatrix4x4DynamicArray;
  IndicesArr: TPasGLTFUInt32DynamicArray;
  i, j, k, PrimitiveIndex, SkinJointCount: Integer;
  AttrIdx: TPasGLTFSizeInt;
  vtx: TVertex;
  LocalVertices: TArray<TVertex>;
  LocalIndices: TArray<GLuint>;
  SourceVertices: TArray<TVertex>;
  LocalSkinWeights, SourceSkinWeights: TArray<TVertexSkinWeights>;
  Skin: TPasGLTF.TSkin;
  HasTexCoords, HasSkin, HasJoints0, HasWeights0,
    HasJoints1, HasWeights1: Boolean;
  StripSkinnedNodeTranslation: Boolean;
  MeshBaseName, TexCoordAttribute: string;
  TextureCoordinateMapping: TTextureCoordinateMapping;
  m11, m12, m13, m21, m22, m23, m31, m32, m33, Det: Single;
  inv11, inv12, inv13, inv21, inv22, inv23, inv31, inv32, inv33: Single;
begin
  if (NodeIdx < 0) or (NodeIdx >= Doc.Nodes.Count) then
    Exit;

  Node := Doc.Nodes[NodeIdx];

  // ----- Local transformation matrix -----
  if not IsIdentityMatrix(Node.Matrix) then
    LocalMat := ConvertMatrix(Node.Matrix)
  else
  begin
    var Trans := Vector3(Node.Translation[0], Node.Translation[1], Node.Translation[2]);
    TransMat.InitTranslation(Trans);
    var Rot: TQuaternion;
    Rot.Init(Node.Rotation[0], Node.Rotation[1], Node.Rotation[2], Node.Rotation[3]);
    RotMat := Rot.ToMatrix;
    var Scale := Vector3(Node.Scale[0], Node.Scale[1], Node.Scale[2]);
    ScaleMat.InitScaling(Scale);
    LocalMat := TransMat * RotMat * ScaleMat;
  end;

  GlobalMat := ParentTransform * LocalMat;

  // ----- Normal matrix = inverse transpose of 3x3 part -----
  m11 := GlobalMat.m11; m12 := GlobalMat.m12; m13 := GlobalMat.m13;
  m21 := GlobalMat.m21; m22 := GlobalMat.m22; m23 := GlobalMat.m23;
  m31 := GlobalMat.m31; m32 := GlobalMat.m32; m33 := GlobalMat.m33;
  Det := m11 * (m22 * m33 - m23 * m32) -
         m12 * (m21 * m33 - m23 * m31) +
         m13 * (m21 * m32 - m22 * m31);
  if Abs(Det) < 1e-9 then Det := 1.0 else Det := 1.0 / Det;
  inv11 := (m22 * m33 - m23 * m32) * Det;
  inv12 := (m13 * m32 - m12 * m33) * Det;
  inv13 := (m12 * m23 - m13 * m22) * Det;
  inv21 := (m23 * m31 - m21 * m33) * Det;
  inv22 := (m11 * m33 - m13 * m31) * Det;
  inv23 := (m13 * m21 - m11 * m23) * Det;
  inv31 := (m21 * m32 - m22 * m31) * Det;
  inv32 := (m12 * m31 - m11 * m32) * Det;
  inv33 := (m11 * m22 - m12 * m21) * Det;
  // Transpose the inverse
  NormalMat.Init(
    inv11, inv21, inv31, 0,
    inv12, inv22, inv32, 0,
    inv13, inv23, inv33, 0,
    0,     0,     0,     1
  );

  // ----- Process mesh primitives -----
  if (Node.Mesh >= 0) and (Node.Mesh < Doc.Meshes.Count) then
  begin
    Mesh := Doc.Meshes[Node.Mesh];
    MeshBaseName := Trim(String(Mesh.Name));
    if MeshBaseName = '' then
      MeshBaseName := Trim(String(Node.Name));
    if MeshBaseName = '' then
      MeshBaseName := Format('Mesh_%d', [Node.Mesh]);
    PrimitiveIndex := 0;
    for Primitive in Mesh.Primitives do
    begin
      // The engine's mesh path is triangle-only.  Reject other glTF primitive
      // modes instead of silently treating lines or strips as triangles.
      if Primitive.Mode <> TPasGLTF.TMesh.TPrimitive.TMode.Triangles then
        raise Exception.CreateFmt('Unsupported glTF primitive mode %d (only TRIANGLES is supported).',
          [Ord(Primitive.Mode)]);

      // Indices
      if Primitive.Indices >= 0 then
      begin
        if Primitive.Indices >= Doc.Accessors.Count then
          raise Exception.CreateFmt('glTF index accessor %d is out of range.',
            [Primitive.Indices]);
        Accessor := Doc.Accessors[Primitive.Indices];
        // Index accessors are tightly packed scalar data. PasGLTF's vertex
        // mode rounds strides to four bytes, which is incorrect for U8/U16
        // index buffers without an explicit byteStride.
        IndicesArr := Accessor.DecodeAsUInt32Array(False);
      end
      else
        SetLength(IndicesArr, 0);

      // Positions
      if not Primitive.Attributes.TryGet('POSITION', AttrIdx) then
        raise Exception.Create('Missing POSITION attribute');
      if (AttrIdx < 0) or (AttrIdx >= Doc.Accessors.Count) then
        raise Exception.CreateFmt('glTF POSITION accessor %d is out of range.', [AttrIdx]);
      Accessor := Doc.Accessors[AttrIdx];
      Positions := Accessor.DecodeAsVector3Array;
      if Length(Positions) = 0 then
        raise Exception.Create('glTF primitive contains no POSITION data.');

      // A JOINTS_n value is an index into the skin's joint table, not a node
      // index. Keep it in that form here; the table is copied onto the mesh.
      Skin := nil;
      SkinJointCount := 0;
      HasSkin := Node.Skin >= 0;
      if HasSkin then
      begin
        if Node.Skin >= Doc.Skins.Count then
          raise Exception.CreateFmt('glTF skin %d is out of range.', [Node.Skin]);
        Skin := Doc.Skins[Node.Skin];
        SkinJointCount := Skin.Joints.Count;
        if SkinJointCount = 0 then
          raise Exception.CreateFmt('glTF skin %d contains no joints.', [Node.Skin]);

        HasJoints0 := Primitive.Attributes.TryGet('JOINTS_0', AttrIdx);
        if HasJoints0 then
        begin
          if (AttrIdx < 0) or (AttrIdx >= Doc.Accessors.Count) then
            raise Exception.CreateFmt('glTF JOINTS_0 accessor %d is out of range.',
              [AttrIdx]);
          Joints0 := Doc.Accessors[AttrIdx].DecodeAsUInt32Vector4Array;
        end
        else
          SetLength(Joints0, 0);

        HasWeights0 := Primitive.Attributes.TryGet('WEIGHTS_0', AttrIdx);
        if HasWeights0 then
        begin
          if (AttrIdx < 0) or (AttrIdx >= Doc.Accessors.Count) then
            raise Exception.CreateFmt('glTF WEIGHTS_0 accessor %d is out of range.',
              [AttrIdx]);
          Weights0 := Doc.Accessors[AttrIdx].DecodeAsVector4Array;
        end
        else
          SetLength(Weights0, 0);

        if not (HasJoints0 and HasWeights0) then
          raise Exception.CreateFmt(
            'Skinned glTF primitive on node %d requires JOINTS_0 and WEIGHTS_0.',
            [NodeIdx]);
        if (Length(Joints0) <> Length(Positions)) or
           (Length(Weights0) <> Length(Positions)) then
          raise Exception.Create('glTF JOINTS_0/WEIGHTS_0 counts do not match POSITION.');

        HasJoints1 := Primitive.Attributes.TryGet('JOINTS_1', AttrIdx);
        HasWeights1 := Primitive.Attributes.TryGet('WEIGHTS_1', AttrIdx);
        if HasJoints1 <> HasWeights1 then
          raise Exception.Create('glTF JOINTS_1 and WEIGHTS_1 must be provided together.');
        if HasJoints1 then
        begin
          Primitive.Attributes.TryGet('JOINTS_1', AttrIdx);
          if (AttrIdx < 0) or (AttrIdx >= Doc.Accessors.Count) then
            raise Exception.CreateFmt('glTF JOINTS_1 accessor %d is out of range.',
              [AttrIdx]);
          Joints1 := Doc.Accessors[AttrIdx].DecodeAsUInt32Vector4Array;
          Primitive.Attributes.TryGet('WEIGHTS_1', AttrIdx);
          if (AttrIdx < 0) or (AttrIdx >= Doc.Accessors.Count) then
            raise Exception.CreateFmt('glTF WEIGHTS_1 accessor %d is out of range.',
              [AttrIdx]);
          Weights1 := Doc.Accessors[AttrIdx].DecodeAsVector4Array;
          if (Length(Joints1) <> Length(Positions)) or
             (Length(Weights1) <> Length(Positions)) then
            raise Exception.Create('glTF JOINTS_1/WEIGHTS_1 counts do not match POSITION.');
        end
        else
        begin
          SetLength(Joints1, 0);
          SetLength(Weights1, 0);
        end;

        SetLength(LocalSkinWeights, Length(Positions));
        for j := 0 to High(LocalSkinWeights) do
        begin
          LocalSkinWeights[j].Clear;
          for k := 0 to 3 do
          begin
            if (Joints0[j][k] >= TPasGLTFUInt32(SkinJointCount)) and
               (Weights0[j][k] > 0.0) then
              raise Exception.CreateFmt(
                'glTF vertex %d references joint slot %d outside skin %d.',
                [j, Joints0[j][k], Node.Skin]);
            LocalSkinWeights[j].Influences[k].Joint := Integer(Joints0[j][k]);
            LocalSkinWeights[j].Influences[k].Weight := Weights0[j][k];
            if HasJoints1 then
            begin
              if (Joints1[j][k] >= TPasGLTFUInt32(SkinJointCount)) and
                 (Weights1[j][k] > 0.0) then
                raise Exception.CreateFmt(
                  'glTF vertex %d references secondary joint slot %d outside skin %d.',
                  [j, Joints1[j][k], Node.Skin]);
              LocalSkinWeights[j].Influences[k + 4].Joint := Integer(Joints1[j][k]);
              LocalSkinWeights[j].Influences[k + 4].Weight := Weights1[j][k];
            end;
          end;
          LocalSkinWeights[j].Normalize;
        end;
      end
      else
        SetLength(LocalSkinWeights, 0);

      // The legacy Khronos 3ds Max exporter duplicates the skinned object's
      // pivot offset in its mesh node. Baking that translation into bind
      // vertices makes the offset rotate independently with every joint.
      StripSkinnedNodeTranslation := HasSkin and
        IsLegacyKhronos3DSMaxExport(Doc);

      // Normals (optional)
      if Primitive.Attributes.TryGet('NORMAL', AttrIdx) then
      begin
        if (AttrIdx < 0) or (AttrIdx >= Doc.Accessors.Count) then
          raise Exception.CreateFmt('glTF NORMAL accessor %d is out of range.', [AttrIdx]);
        Accessor := Doc.Accessors[AttrIdx];
        Normals := Accessor.DecodeAsVector3Array;
        if Length(Normals) <> Length(Positions) then
          raise Exception.CreateFmt('glTF NORMAL count (%d) does not match POSITION count (%d).',
            [Length(Normals), Length(Positions)]);
      end
      else
        SetLength(Normals, 0);

      // Select the material's effective UV set. KHR_texture_transform may
      // override textureInfo.texCoord, as used by the legacy 3ds Max exporter.
      GetMaterialTextureCoordinateMapping(
        Doc, Primitive.Material, TextureCoordinateMapping);
      TexCoordAttribute := Format(
        'TEXCOORD_%d', [TextureCoordinateMapping.TexCoordSet]);
      HasTexCoords := Primitive.Attributes.TryGet(TexCoordAttribute, AttrIdx);
      if HasTexCoords then
      begin
        if (AttrIdx < 0) or (AttrIdx >= Doc.Accessors.Count) then
          raise Exception.CreateFmt(
            'glTF %s accessor %d is out of range.',
            [TexCoordAttribute, AttrIdx]);
        Accessor := Doc.Accessors[AttrIdx];
        TexCoords := Accessor.DecodeAsVector2Array;
        if Length(TexCoords) <> Length(Positions) then
          raise Exception.CreateFmt(
            'glTF %s count (%d) does not match POSITION count (%d).',
            [TexCoordAttribute, Length(TexCoords), Length(Positions)]);
      end
      else
        SetLength(TexCoords, 0);

      // Tangents (optional)
      if Primitive.Attributes.TryGet('TANGENT', AttrIdx) then
      begin
        if (AttrIdx < 0) or (AttrIdx >= Doc.Accessors.Count) then
          raise Exception.CreateFmt('glTF TANGENT accessor %d is out of range.', [AttrIdx]);
        Accessor := Doc.Accessors[AttrIdx];
        Tangents := Accessor.DecodeAsVector4Array;
        if Length(Tangents) <> Length(Positions) then
          raise Exception.CreateFmt('glTF TANGENT count (%d) does not match POSITION count (%d).',
            [Length(Tangents), Length(Positions)]);
      end
      else
        SetLength(Tangents, 0);

      if (Length(IndicesArr) > 0) and ((Length(IndicesArr) mod 3) <> 0) then
        raise Exception.CreateFmt('glTF triangle index count %d is not divisible by 3.',
          [Length(IndicesArr)]);
      if (Length(IndicesArr) = 0) and ((Length(Positions) mod 3) <> 0) then
        raise Exception.CreateFmt('glTF non-indexed triangle vertex count %d is not divisible by 3.',
          [Length(Positions)]);
      for i := 0 to High(IndicesArr) do
        if IndicesArr[i] >= TPasGLTFUInt32(Length(Positions)) then
          raise Exception.CreateFmt('glTF index %d is outside the %d-vertex POSITION array.',
            [i, Length(Positions)]);

      // NORMAL is optional in glTF.  Generate smooth normals so a valid
      // triangle mesh never reaches the renderer with a zero normal.
      if Length(Normals) = 0 then
      begin
        SetLength(Normals, Length(Positions));
        for j := 0 to High(Normals) do
        begin
          Normals[j][0] := 0.0; Normals[j][1] := 0.0; Normals[j][2] := 0.0;
        end;
        var TriangleCount := Length(IndicesArr) div 3;
        if Length(IndicesArr) = 0 then
          TriangleCount := Length(Positions) div 3;
        for i := 0 to TriangleCount - 1 do
        begin
          var I0 := i * 3;
          var I1 := I0 + 1;
          var I2 := I0 + 2;
          if Length(IndicesArr) > 0 then
          begin
            I0 := IndicesArr[i * 3]; I1 := IndicesArr[i * 3 + 1]; I2 := IndicesArr[i * 3 + 2];
          end;
          var P0 := Vector3(Positions[I0][0], Positions[I0][1], Positions[I0][2]);
          var P1 := Vector3(Positions[I1][0], Positions[I1][1], Positions[I1][2]);
          var P2 := Vector3(Positions[I2][0], Positions[I2][1], Positions[I2][2]);
          var FaceNormal := (P1 - P0).Cross(P2 - P0);
          Normals[I0][0] := Normals[I0][0] + FaceNormal.X;
          Normals[I0][1] := Normals[I0][1] + FaceNormal.Y;
          Normals[I0][2] := Normals[I0][2] + FaceNormal.Z;
          Normals[I1][0] := Normals[I1][0] + FaceNormal.X;
          Normals[I1][1] := Normals[I1][1] + FaceNormal.Y;
          Normals[I1][2] := Normals[I1][2] + FaceNormal.Z;
          Normals[I2][0] := Normals[I2][0] + FaceNormal.X;
          Normals[I2][1] := Normals[I2][1] + FaceNormal.Y;
          Normals[I2][2] := Normals[I2][2] + FaceNormal.Z;
        end;
        for j := 0 to High(Normals) do
        begin
          var NormalLength := Sqrt(Normals[j][0] * Normals[j][0] +
            Normals[j][1] * Normals[j][1] + Normals[j][2] * Normals[j][2]);
          if NormalLength > 1e-6 then
          begin
            Normals[j][0] := Normals[j][0] / NormalLength;
            Normals[j][1] := Normals[j][1] / NormalLength;
            Normals[j][2] := Normals[j][2] / NormalLength;
          end
          else
          begin
            Normals[j][0] := 0.0; Normals[j][1] := 1.0; Normals[j][2] := 0.0;
          end;
        end;
      end;

      // Transform vertices for this primitive
      SetLength(LocalVertices, Length(Positions));
      for j := 0 to Length(Positions) - 1 do
      begin
        // Position
        var PosVec := Vector4(Positions[j][0], Positions[j][1], Positions[j][2], 1.0);
        PosVec := GlobalMat * PosVec;
        if StripSkinnedNodeTranslation then
          PosVec := PosVec - Vector4(Vector3(GlobalMat.Columns[3]), 0.0);
        vtx.Position := Vector3(PosVec.X, PosVec.Y, PosVec.Z);

        // Normal
        var NormVec: TVector4;
        if j < Length(Normals) then
          NormVec := Vector4(Normals[j][0], Normals[j][1], Normals[j][2], 0.0)
        else
          NormVec := Vector4(0, 0, 0, 0);
        NormVec := NormalMat * NormVec;
        var NormLen := Sqrt(NormVec.X*NormVec.X + NormVec.Y*NormVec.Y + NormVec.Z*NormVec.Z);
        if NormLen > 1e-6 then
          NormVec := NormVec / NormLen;
        vtx.Normal := Vector3(NormVec.X, NormVec.Y, NormVec.Z);

        // TexCoord
        if HasTexCoords then
          // Bake the glTF texture transform before the material shader flips V
          // for OpenGL textures uploaded from top-origin images.
          vtx.TexCoord := ApplyTextureCoordinateMapping(
            Vector2(TexCoords[j][0], TexCoords[j][1]),
            TextureCoordinateMapping)
        else
          vtx.TexCoord := Vector2(0.0, 0.0);

        // Tangent
        var TangVec: TVector4;
        if j < Length(Tangents) then
          TangVec := Vector4(Tangents[j][0], Tangents[j][1], Tangents[j][2], 0.0)
        else
          TangVec := Vector4(1, 0, 0, 0);
        TangVec := NormalMat * TangVec;
        var TangLen := Sqrt(TangVec.X*TangVec.X + TangVec.Y*TangVec.Y + TangVec.Z*TangVec.Z);
        if TangLen > 1e-6 then
          TangVec := TangVec / TangLen;
        vtx.Tangent := Vector3(TangVec.X, TangVec.Y, TangVec.Z);

        vtx.Bitangent := TVector3.Zero;
        LocalVertices[j] := vtx;
      end;

      // Build indices (with offset 0 for this primitive)
      SetLength(LocalIndices, Length(IndicesArr));
      for i := 0 to High(IndicesArr) do
        LocalIndices[i] := IndicesArr[i];

      if not HasTexCoords then
      begin
        SourceVertices := Copy(LocalVertices);
        if HasSkin then
          SourceSkinWeights := Copy(LocalSkinWeights)
        else
          SetLength(SourceSkinWeights, 0);

        var TriangleCount := Length(IndicesArr) div 3;
        if Length(IndicesArr) = 0 then
          TriangleCount := Length(SourceVertices) div 3;

        SetLength(LocalVertices, TriangleCount * 3);
        SetLength(LocalIndices, TriangleCount * 3);
        if HasSkin then
          SetLength(LocalSkinWeights, TriangleCount * 3);
        for i := 0 to TriangleCount - 1 do
        begin
          var Src0 := i * 3;
          var Src1 := Src0 + 1;
          var Src2 := Src0 + 2;
          if Length(IndicesArr) > 0 then
          begin
            Src0 := Integer(IndicesArr[i * 3]);
            Src1 := Integer(IndicesArr[i * 3 + 1]);
            Src2 := Integer(IndicesArr[i * 3 + 2]);
          end;

          var FaceNormal := (SourceVertices[Src1].Position - SourceVertices[Src0].Position).
            Cross(SourceVertices[Src2].Position - SourceVertices[Src0].Position);
          var FaceNormalLen := Sqrt(FaceNormal.X * FaceNormal.X +
            FaceNormal.Y * FaceNormal.Y + FaceNormal.Z * FaceNormal.Z);
          if FaceNormalLen <= 1e-6 then
            FaceNormal := SourceVertices[Src0].Normal;

          var UV0: TVector2;
          var UV1: TVector2;
          var UV2: TVector2;
          GeneratePlanarUVs(SourceVertices[Src0].Position, SourceVertices[Src1].Position,
            SourceVertices[Src2].Position, FaceNormal, UV0, UV1, UV2);

          var Dest := i * 3;
          LocalVertices[Dest] := SourceVertices[Src0];
          LocalVertices[Dest].TexCoord := UV0;
          LocalVertices[Dest + 1] := SourceVertices[Src1];
          LocalVertices[Dest + 1].TexCoord := UV1;
          LocalVertices[Dest + 2] := SourceVertices[Src2];
          LocalVertices[Dest + 2].TexCoord := UV2;

          if HasSkin then
          begin
            LocalSkinWeights[Dest] := SourceSkinWeights[Src0];
            LocalSkinWeights[Dest + 1] := SourceSkinWeights[Src1];
            LocalSkinWeights[Dest + 2] := SourceSkinWeights[Src2];
          end;

          LocalIndices[Dest] := GLuint(Dest);
          LocalIndices[Dest + 1] := GLuint(Dest + 1);
          LocalIndices[Dest + 2] := GLuint(Dest + 2);
        end;
      end;

      // Some exporters emit a TANGENT accessor filled with zeroes. Rebuild the
      // complete basis from geometry and UVs so normal mapping remains valid,
      // and do it before the vertices become a skeletal mesh's bind geometry.
      BuildTangentBasis(LocalVertices, LocalIndices);

      // Add to mesh list
      var NewMesh: TMeshData;
      NewMesh := Default(TMeshData);
      NewMesh.Name := Format('%s_%d', [MeshBaseName, PrimitiveIndex]);
      NewMesh.Vertices := LocalVertices;
      NewMesh.Indices := LocalIndices;
      NewMesh.MaterialIndex := Primitive.Material;
      NewMesh.IsSkinned := HasSkin;
      NewMesh.BindMeshMatrix := GlobalMat;
      if HasSkin then
      begin
        NewMesh.SkinWeights := Copy(LocalSkinWeights);
        SetLength(NewMesh.JointBoneIndices, SkinJointCount);
        SetLength(NewMesh.InverseBindMatrices, SkinJointCount);
        for k := 0 to SkinJointCount - 1 do
        begin
          if Skin.Joints[k] >= TPasGLTFSizeUInt(Doc.Nodes.Count) then
            raise Exception.CreateFmt('glTF skin %d joint node %d is out of range.',
              [Node.Skin, Skin.Joints[k]]);
          NewMesh.JointBoneIndices[k] := Integer(Skin.Joints[k]);
          NewMesh.InverseBindMatrices[k] := TMatrix4.Identity;
        end;

        if Skin.InverseBindMatrices >= 0 then
        begin
          if Skin.InverseBindMatrices >= Doc.Accessors.Count then
            raise Exception.CreateFmt(
              'glTF inverse-bind accessor %d is out of range.',
              [Skin.InverseBindMatrices]);
          InverseMatricesRaw :=
            Doc.Accessors[Skin.InverseBindMatrices].DecodeAsMatrix4x4Array;
          if Length(InverseMatricesRaw) <> SkinJointCount then
            raise Exception.CreateFmt(
              'glTF skin %d has %d joints but %d inverse bind matrices.',
              [Node.Skin, SkinJointCount, Length(InverseMatricesRaw)]);
          for k := 0 to SkinJointCount - 1 do
            NewMesh.InverseBindMatrices[k] := ConvertMatrix(InverseMatricesRaw[k]);
        end;
      end;
      MeshList := MeshList + [NewMesh];
      Inc(PrimitiveIndex);
    end;
  end;

  // Recurse into children
  for i := 0 to Node.Children.Count - 1 do
    ProcessNodeMulti(Doc, Node.Children[i], GlobalMat, MeshList);
end;

function NodeBindTransform(Node: TPasGLTF.TNode): TSkeletonTransform; forward;
procedure InferSkinHierarchy(const Doc: TPasGLTF.TDocument;
  var Parents: TArray<Integer>); forward;

procedure BuildMaterialNameList(const Doc: TPasGLTF.TDocument;
  out MaterialNamesByIndex: TArray<string>);
var
  I: Integer;
begin
  SetLength(MaterialNamesByIndex, Doc.Materials.Count);
  for I := 0 to Doc.Materials.Count - 1 do
    MaterialNamesByIndex[I] := Trim(String(Doc.Materials[I].Name));
end;

procedure DecodeAnimationChannelValues(const Doc: TPasGLTF.TDocument;
  Sampler: TPasGLTF.TAnimation.TSampler; Target: TAnimationChannelTarget;
  Interpolation: TAnimationInterpolation; KeyCount: Integer;
  out Values, InTangents, OutTangents: TArray<TVector4>);
var
  SourceIndex, I, ValueStride: Integer;
  Vector3Values: TPasGLTF.TVector3DynamicArray;
  Vector4Values: TPasGLTF.TVector4DynamicArray;

  function SourceVector(AIndex: Integer): TVector4;
  begin
    if Target = actRotation then
      Result := Vector4(Vector4Values[AIndex][0], Vector4Values[AIndex][1],
        Vector4Values[AIndex][2], Vector4Values[AIndex][3])
    else
      Result := Vector4(Vector3Values[AIndex][0], Vector3Values[AIndex][1],
        Vector3Values[AIndex][2], 0.0);
  end;

begin
  Values := nil;
  InTangents := nil;
  OutTangents := nil;
  if (Sampler.Output < 0) or (Sampler.Output >= Doc.Accessors.Count) then
    raise Exception.CreateFmt('glTF animation output accessor %d is out of range.',
      [Sampler.Output]);

  if Target = actRotation then
    Vector4Values := Doc.Accessors[Sampler.Output].DecodeAsVector4Array
  else
    Vector3Values := Doc.Accessors[Sampler.Output].DecodeAsVector3Array;

  ValueStride := 1;
  if Interpolation = aiCubicSpline then
    ValueStride := 3;
  if Target = actRotation then
    SourceIndex := Length(Vector4Values)
  else
    SourceIndex := Length(Vector3Values);
  if SourceIndex <> KeyCount * ValueStride then
    raise Exception.CreateFmt(
      'glTF animation output has %d values; expected %d.',
      [SourceIndex, KeyCount * ValueStride]);

  SetLength(Values, KeyCount);
  if Interpolation = aiCubicSpline then
  begin
    SetLength(InTangents, KeyCount);
    SetLength(OutTangents, KeyCount);
    for I := 0 to KeyCount - 1 do
    begin
      SourceIndex := I * 3;
      InTangents[I] := SourceVector(SourceIndex);
      Values[I] := SourceVector(SourceIndex + 1);
      OutTangents[I] := SourceVector(SourceIndex + 2);
    end;
  end
  else
    for I := 0 to KeyCount - 1 do
      Values[I] := SourceVector(I);
end;

function BuildAnimatorFromDocument(
  const Doc: TPasGLTF.TDocument): TSkeletonAnimator;
var
  Parents: TArray<Integer>;
  BoneData: TArray<TSkeletonBoneData>;
  I, J, K, ChildIndex, SamplerIndex, NodeIndex: Integer;
  Node: TPasGLTF.TNode;
  Animation: TPasGLTF.TAnimation;
  GLTFChannel: TPasGLTF.TAnimation.TChannel;
  Sampler: TPasGLTF.TAnimation.TSampler;
  Clip: TSkeletonAnimationClip;
  Channel: TSkeletonAnimationChannel;
  Times: TArray<Single>;
  RawTimes: TPasGLTFFloatDynamicArray;
  Values, InTangents, OutTangents: TArray<TVector4>;
  Path, ClipName: string;
  Target: TAnimationChannelTarget;
  Interpolation: TAnimationInterpolation;
begin
  Result := nil;
  SetLength(Parents, Doc.Nodes.Count);
  for I := 0 to High(Parents) do
    Parents[I] := -1;

  for I := 0 to Doc.Nodes.Count - 1 do
  begin
    Node := Doc.Nodes[I];
    for J := 0 to Node.Children.Count - 1 do
    begin
      ChildIndex := Integer(Node.Children[J]);
      if (ChildIndex < 0) or (ChildIndex >= Doc.Nodes.Count) then
        raise Exception.CreateFmt('glTF node %d has invalid child %d.',
          [I, ChildIndex]);
      if (Parents[ChildIndex] >= 0) and (Parents[ChildIndex] <> I) then
        raise Exception.CreateFmt('glTF node %d has more than one parent.',
          [ChildIndex]);
      Parents[ChildIndex] := I;
    end;
  end;

  // Some 3ds Max exporters write all skin joints as scene roots and omit the
  // node children array. Reconstruct only missing joint parents from the
  // inverse-bind matrices; explicit glTF hierarchy data always wins.
  InferSkinHierarchy(Doc, Parents);

  SetLength(BoneData, Doc.Nodes.Count);
  for I := 0 to Doc.Nodes.Count - 1 do
  begin
    BoneData[I].Name := Trim(String(Doc.Nodes[I].Name));
    if BoneData[I].Name = '' then
      BoneData[I].Name := Format('Node_%d', [I]);
    BoneData[I].ParentIndex := Parents[I];
    BoneData[I].BindTransform := NodeBindTransform(Doc.Nodes[I]);
  end;

  Result := TSkeletonAnimator.Create(TSkeleton.Create(BoneData));
  try
    for I := 0 to Doc.Animations.Count - 1 do
    begin
      Animation := Doc.Animations[I];
      ClipName := Trim(String(Animation.Name));
      if ClipName = '' then
        ClipName := Format('Animation_%d', [I]);
      Clip := TSkeletonAnimationClip.Create(ClipName);
      try
        for J := 0 to Animation.Channels.Count - 1 do
        begin
          GLTFChannel := Animation.Channels[J];
          SamplerIndex := GLTFChannel.Sampler;
          NodeIndex := GLTFChannel.Target.Node;
          if (SamplerIndex < 0) or (SamplerIndex >= Animation.Samplers.Count) then
            raise Exception.CreateFmt(
              'glTF animation %d channel %d has invalid sampler %d.',
              [I, J, SamplerIndex]);
          if (NodeIndex < 0) or (NodeIndex >= Doc.Nodes.Count) then
            raise Exception.CreateFmt(
              'glTF animation %d channel %d has invalid target node %d.',
              [I, J, NodeIndex]);

          Path := LowerCase(Trim(String(GLTFChannel.Target.Path)));
          if Path = 'translation' then
            Target := actTranslation
          else if Path = 'rotation' then
            Target := actRotation
          else if Path = 'scale' then
            Target := actScale
          else if Path = 'weights' then
            Continue
          else
            raise Exception.CreateFmt('Unsupported glTF animation path "%s".',
              [Path]);

          Sampler := Animation.Samplers[SamplerIndex];
          case Sampler.Interpolation of
            TPasGLTF.TAnimation.TSampler.TType.Step:
              Interpolation := aiStep;
            TPasGLTF.TAnimation.TSampler.TType.CubicSpline:
              Interpolation := aiCubicSpline;
          else
            Interpolation := aiLinear;
          end;

          if (Sampler.Input < 0) or (Sampler.Input >= Doc.Accessors.Count) then
            raise Exception.CreateFmt(
              'glTF animation input accessor %d is out of range.',
              [Sampler.Input]);
          RawTimes := Doc.Accessors[Sampler.Input].DecodeAsFloatArray;
          if Length(RawTimes) = 0 then
            Continue;
          SetLength(Times, Length(RawTimes));
          for K := 0 to High(RawTimes) do
            Times[K] := RawTimes[K];
          DecodeAnimationChannelValues(Doc, Sampler, Target, Interpolation,
            Length(Times), Values, InTangents, OutTangents);
          Channel := TSkeletonAnimationChannel.Create(NodeIndex, Target,
            Interpolation, Times, Values, InTangents, OutTangents);
          Clip.AddChannel(Channel);
        end;
        Result.AddAnimation(Clip);
        Clip := nil;
      finally
        Clip.Free;
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function NormalizedSkeletonNodeName(const AName: string): string;
var
  P: Integer;
  LowerName: string;
begin
  Result := Trim(AName);
  P := LastDelimiter(':', Result);
  if P > 0 then
    Result := Copy(Result, P + 1, MaxInt);

  LowerName := LowerCase(Result);
  if Copy(LowerName, 1, 10) = 'mixamorig:' then
    Delete(Result, 1, 10)
  else if Copy(LowerName, 1, 10) = 'mixamorig_' then
    Delete(Result, 1, 10);
end;

function FindTargetSkeletonBone(ATargetSkeleton: TSkeleton;
  const ASourceNodeName: string): TSkeletonBone;
var
  NormalizedSourceName: string;
  I: Integer;
begin
  Result := nil;
  if ATargetSkeleton = nil then
    Exit;

  Result := ATargetSkeleton.BoneByName(ASourceNodeName);
  if Result <> nil then
    Exit;

  NormalizedSourceName := NormalizedSkeletonNodeName(ASourceNodeName);
  if NormalizedSourceName = '' then
    Exit;

  Result := ATargetSkeleton.BoneByName(NormalizedSourceName);
  if Result <> nil then
    Exit;

  for I := 0 to ATargetSkeleton.BoneCount - 1 do
    if SameText(NormalizedSkeletonNodeName(ATargetSkeleton.Bones[I].Name),
       NormalizedSourceName) then
      Exit(ATargetSkeleton.Bones[I]);
end;

function GLTFNodeAnimationTarget(
  const GLTFChannel: TPasGLTF.TAnimation.TChannel;
  out ATarget: TAnimationChannelTarget): Boolean;
var
  Path: string;
begin
  Result := False;
  Path := LowerCase(Trim(String(GLTFChannel.Target.Path)));
  if Path = 'translation' then
    ATarget := actTranslation
  else if Path = 'rotation' then
    ATarget := actRotation
  else if Path = 'scale' then
    ATarget := actScale
  else
    Exit;
  Result := True;
end;

procedure LoadGLTFAnimationClips(const AFileName: string;
  ATargetSkeleton: TSkeleton; out Clips: TArray<TSkeletonAnimationClip>);
var
  Stream: TFileStream;
  Doc: TPasGLTF.TDocument;
  Animation: TPasGLTF.TAnimation;
  GLTFChannel: TPasGLTF.TAnimation.TChannel;
  Sampler: TPasGLTF.TAnimation.TSampler;
  Clip: TSkeletonAnimationClip;
  Channel: TSkeletonAnimationChannel;
  TargetBone: TSkeletonBone;
  Times: TArray<Single>;
  RawTimes: TPasGLTFFloatDynamicArray;
  Values, InTangents, OutTangents: TArray<TVector4>;
  ClipName, BaseClipName, SourceNodeName: string;
  Target: TAnimationChannelTarget;
  Interpolation: TAnimationInterpolation;
  I, J, K, SamplerIndex, NodeIndex, ClipCount: Integer;

  procedure AddClip(AClip: TSkeletonAnimationClip);
  begin
    SetLength(Clips, ClipCount + 1);
    Clips[ClipCount] := AClip;
    Inc(ClipCount);
  end;

  procedure FreeLoadedClips;
  var
    ClipIndex: Integer;
  begin
    for ClipIndex := 0 to High(Clips) do
      Clips[ClipIndex].Free;
    Clips := nil;
    ClipCount := 0;
  end;

begin
  Clips := nil;
  ClipCount := 0;

  if ATargetSkeleton = nil then
    raise Exception.Create('A target skeleton is required to load animation clips.');
  if not FileExists(AFileName) then
    raise Exception.Create('GLTF file not found: ' + AFileName);

  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Doc := TPasGLTF.TDocument.Create;
    try
      Doc.RootPath := ExtractFilePath(AFileName);
      Doc.LoadFromStream(Stream);
      if Doc.Animations.Count = 0 then
        raise Exception.Create('The glTF file contains no animation clips.');

      BaseClipName := ChangeFileExt(ExtractFileName(AFileName), '');
      if BaseClipName = '' then
        BaseClipName := 'Animation';

      try
        for I := 0 to Doc.Animations.Count - 1 do
        begin
          Animation := Doc.Animations[I];
          ClipName := Trim(String(Animation.Name));
          if ClipName = '' then
          begin
            ClipName := BaseClipName;
            if Doc.Animations.Count > 1 then
              ClipName := Format('%s_%d', [ClipName, I + 1]);
          end;

          Clip := TSkeletonAnimationClip.Create(ClipName);
          try
            for J := 0 to Animation.Channels.Count - 1 do
            begin
              GLTFChannel := Animation.Channels[J];
              if not GLTFNodeAnimationTarget(GLTFChannel, Target) then
                Continue;

              NodeIndex := GLTFChannel.Target.Node;
              if (NodeIndex < 0) or (NodeIndex >= Doc.Nodes.Count) then
                raise Exception.CreateFmt(
                  'glTF animation %d channel %d has invalid target node %d.',
                  [I, J, NodeIndex]);

              SourceNodeName := Trim(String(Doc.Nodes[NodeIndex].Name));
              if SourceNodeName = '' then
                SourceNodeName := Format('Node_%d', [NodeIndex]);
              TargetBone := FindTargetSkeletonBone(ATargetSkeleton,
                SourceNodeName);
              if TargetBone = nil then
                Continue;

              SamplerIndex := GLTFChannel.Sampler;
              if (SamplerIndex < 0) or (SamplerIndex >= Animation.Samplers.Count) then
                raise Exception.CreateFmt(
                  'glTF animation %d channel %d has invalid sampler %d.',
                  [I, J, SamplerIndex]);
              Sampler := Animation.Samplers[SamplerIndex];

              case Sampler.Interpolation of
                TPasGLTF.TAnimation.TSampler.TType.Step:
                  Interpolation := aiStep;
                TPasGLTF.TAnimation.TSampler.TType.CubicSpline:
                  Interpolation := aiCubicSpline;
              else
                Interpolation := aiLinear;
              end;

              if (Sampler.Input < 0) or (Sampler.Input >= Doc.Accessors.Count) then
                raise Exception.CreateFmt(
                  'glTF animation input accessor %d is out of range.',
                  [Sampler.Input]);
              RawTimes := Doc.Accessors[Sampler.Input].DecodeAsFloatArray;
              if Length(RawTimes) = 0 then
                Continue;

              SetLength(Times, Length(RawTimes));
              for K := 0 to High(RawTimes) do
                Times[K] := RawTimes[K];

              DecodeAnimationChannelValues(Doc, Sampler, Target, Interpolation,
                Length(Times), Values, InTangents, OutTangents);
              Channel := TSkeletonAnimationChannel.Create(TargetBone.Index,
                Target, Interpolation, Times, Values, InTangents, OutTangents);
              Clip.AddChannel(Channel);
            end;

            if Clip.ChannelCount > 0 then
            begin
              AddClip(Clip);
              Clip := nil;
            end;
          finally
            Clip.Free;
          end;
        end;
      except
        FreeLoadedClips;
        raise;
      end;

      if ClipCount = 0 then
        raise Exception.Create(
          'No animation channels matched the target skeleton bone names.');
    finally
      Doc.Free;
    end;
  finally
    Stream.Free;
  end;
end;

function DecomposeNodeMatrix(const M: TMatrix4): TSkeletonTransform;
var
  AxisX, AxisY, AxisZ: TVector3;
  RotationMatrix: TMatrix4;
  Q: TQuaternion;
begin
  Result := TSkeletonTransform.Identity;
  Result.Translation := Vector3(M.Columns[3]);

  AxisX := Vector3(M.Columns[0]);
  AxisY := Vector3(M.Columns[1]);
  AxisZ := Vector3(M.Columns[2]);
  Result.Scale := Vector3(Sqrt(AxisX.LengthSquared), Sqrt(AxisY.LengthSquared),
    Sqrt(AxisZ.LengthSquared));

  if AxisX.Cross(AxisY).Dot(AxisZ) < 0.0 then
    Result.Scale.X := -Result.Scale.X;
  if Abs(Result.Scale.X) > 1.0e-8 then
    AxisX := AxisX / Result.Scale.X;
  if Abs(Result.Scale.Y) > 1.0e-8 then
    AxisY := AxisY / Result.Scale.Y;
  if Abs(Result.Scale.Z) > 1.0e-8 then
    AxisZ := AxisZ / Result.Scale.Z;

  RotationMatrix := TMatrix4.Identity;
  RotationMatrix.Columns[0] := Vector4(AxisX, 0.0);
  RotationMatrix.Columns[1] := Vector4(AxisY, 0.0);
  RotationMatrix.Columns[2] := Vector4(AxisZ, 0.0);
  Q.Init(RotationMatrix);
  Result.Rotation := Q.Normalize;
end;

function NodeBindTransform(Node: TPasGLTF.TNode): TSkeletonTransform;
var
  Q: TQuaternion;
begin
  if not IsIdentityMatrix(Node.Matrix) then
    Exit(DecomposeNodeMatrix(ConvertMatrix(Node.Matrix)));

  Result.Translation := Vector3(Node.Translation[0], Node.Translation[1],
    Node.Translation[2]);
  Q.Init(Node.Rotation[0], Node.Rotation[1], Node.Rotation[2],
    Node.Rotation[3]);
  Result.Rotation := Q.Normalize;
  Result.Scale := Vector3(Node.Scale[0], Node.Scale[1], Node.Scale[2]);
end;

procedure InferSkinHierarchy(const Doc: TPasGLTF.TDocument;
  var Parents: TArray<Integer>);
const
  SKIN_HIERARCHY_POSITION_TOLERANCE = 5.0e-3;
var
  JointGlobalMatrices: TArray<TMatrix4>;
  HasJointGlobalMatrix: TArray<Boolean>;
  IsSkinRoot: TArray<Boolean>;
  InverseMatrices: TPasGLTF.TMatrix4x4DynamicArray;
  Skin: TPasGLTF.TSkin;
  ChildLocalMatrix, CandidateGlobalMatrix: TMatrix4;
  CandidatePosition, ChildPosition, PositionDelta: TVector3;
  ChildNodeIndex, ParentNodeIndex, JointIndex: Integer;
  BestParentIndex: Integer;
  BestPositionError, PositionError, BestMatrixError, MatrixError: Single;

  function MatrixDifference(const A, B: TMatrix4): Single;
  var
    ColumnIndex, RowIndex: Integer;
  begin
    Result := 0.0;
    for ColumnIndex := 0 to 3 do
      for RowIndex := 0 to 3 do
        Result := System.Math.Max(Result,
          Abs(A.Columns[ColumnIndex][RowIndex] -
              B.Columns[ColumnIndex][RowIndex]));
  end;

begin
  if Doc.Skins.Count = 0 then
    Exit;

  SetLength(JointGlobalMatrices, Doc.Nodes.Count);
  SetLength(HasJointGlobalMatrix, Doc.Nodes.Count);
  SetLength(IsSkinRoot, Doc.Nodes.Count);

  for Skin in Doc.Skins do
  begin
    if (Skin.Skeleton >= 0) and (Skin.Skeleton < Doc.Nodes.Count) then
      IsSkinRoot[Skin.Skeleton] := True;
    if Skin.InverseBindMatrices < 0 then
      Continue;
    if Skin.InverseBindMatrices >= Doc.Accessors.Count then
      Continue;

    InverseMatrices :=
      Doc.Accessors[Skin.InverseBindMatrices].DecodeAsMatrix4x4Array;
    if Length(InverseMatrices) <> Skin.Joints.Count then
      Continue;

    for JointIndex := 0 to Skin.Joints.Count - 1 do
    begin
      ChildNodeIndex := Integer(Skin.Joints[JointIndex]);
      if (ChildNodeIndex < 0) or (ChildNodeIndex >= Doc.Nodes.Count) then
        Continue;
      JointGlobalMatrices[ChildNodeIndex] :=
        ConvertMatrix(InverseMatrices[JointIndex]).Inverse;
      HasJointGlobalMatrix[ChildNodeIndex] := True;
    end;
  end;

  for ChildNodeIndex := 0 to Doc.Nodes.Count - 1 do
  begin
    if (Parents[ChildNodeIndex] >= 0) or
       (not HasJointGlobalMatrix[ChildNodeIndex]) or
       IsSkinRoot[ChildNodeIndex] then
      Continue;

    ChildLocalMatrix := NodeBindTransform(Doc.Nodes[ChildNodeIndex]).ToMatrix;
    ChildPosition := Vector3(JointGlobalMatrices[ChildNodeIndex].Columns[3]);
    BestParentIndex := -1;
    BestPositionError := 1.0e30;
    BestMatrixError := 1.0e30;
    for ParentNodeIndex := 0 to Doc.Nodes.Count - 1 do
    begin
      if (ParentNodeIndex = ChildNodeIndex) or
         (not HasJointGlobalMatrix[ParentNodeIndex]) then
        Continue;

      CandidateGlobalMatrix :=
        JointGlobalMatrices[ParentNodeIndex] * ChildLocalMatrix;
      CandidatePosition := Vector3(CandidateGlobalMatrix.Columns[3]);
      PositionDelta := CandidatePosition - ChildPosition;
      PositionError := Sqrt(PositionDelta.LengthSquared);
      MatrixError := MatrixDifference(CandidateGlobalMatrix,
        JointGlobalMatrices[ChildNodeIndex]);
      if (PositionError < BestPositionError) or
         ((Abs(PositionError - BestPositionError) <= 1.0e-6) and
          (MatrixError < BestMatrixError)) then
      begin
        BestPositionError := PositionError;
        BestMatrixError := MatrixError;
        BestParentIndex := ParentNodeIndex;
      end;
    end;

    // Baked animation can leave node rotations different from the inverse-bind
    // pose. Bone offsets remain stable, so use the reconstructed joint position
    // as the hierarchy invariant and use the full matrix only as a tie-breaker.
    if (BestParentIndex >= 0) and
       (BestPositionError <= SKIN_HIERARCHY_POSITION_TOLERANCE) then
      Parents[ChildNodeIndex] := BestParentIndex;
  end;
end;

procedure LoadGLTFData(const AFileName: string;
  out MeshDataList: TArray<TMeshData>;
  out MaterialNamesByIndex: TArray<string>);
var
  Stream: TFileStream;
  Doc: TPasGLTF.TDocument;
  Scene: TPasGLTF.TScene;
  i: Integer;
begin
  MeshDataList := nil;
  MaterialNamesByIndex := nil;

  if not FileExists(AFileName) then
    raise Exception.Create('GLTF file not found: ' + AFileName);

  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Doc := TPasGLTF.TDocument.Create;
    try
      Doc.RootPath := ExtractFilePath(AFileName);
      Doc.LoadFromStream(Stream);
      if Doc.Scene >= 0 then
        Scene := Doc.Scenes[Doc.Scene]
      else if Doc.Scenes.Count > 0 then
        Scene := Doc.Scenes[0]
      else
        Exit;

      MeshDataList := nil;
      for i := 0 to Scene.Nodes.Count - 1 do
        ProcessNodeMulti(Doc, Scene.Nodes[i], TMatrix4.Identity, MeshDataList);

      BuildMaterialNameList(Doc, MaterialNamesByIndex);
    finally
      Doc.Free;
    end;
  finally
    Stream.Free;
  end;
end;

procedure LoadGLTFModelFile(const AFileName: string;
  out Meshes: TArray<TGLTFModelMeshData>; out Animator: TSkeletonAnimator);
var
  Stream: TFileStream;
  Doc: TPasGLTF.TDocument;
  Scene: TPasGLTF.TScene;
  MeshDataList: TArray<TMeshData>;
  MaterialNamesByIndex: TArray<string>;
  I: Integer;
  HasSkinnedMeshes: Boolean;
begin
  Meshes := nil;
  Animator := nil;
  if not FileExists(AFileName) then
    raise Exception.Create('GLTF file not found: ' + AFileName);

  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Doc := TPasGLTF.TDocument.Create;
    try
      Doc.RootPath := ExtractFilePath(AFileName);
      Doc.LoadFromStream(Stream);
      if Doc.Scene >= 0 then
        Scene := Doc.Scenes[Doc.Scene]
      else if Doc.Scenes.Count > 0 then
        Scene := Doc.Scenes[0]
      else
        Exit;

      MeshDataList := nil;
      for I := 0 to Scene.Nodes.Count - 1 do
        ProcessNodeMulti(Doc, Integer(Scene.Nodes[I]), TMatrix4.Identity,
          MeshDataList);
      BuildMaterialNameList(Doc, MaterialNamesByIndex);

      HasSkinnedMeshes := False;
      for I := 0 to High(MeshDataList) do
        HasSkinnedMeshes := HasSkinnedMeshes or MeshDataList[I].IsSkinned;
      if HasSkinnedMeshes then
        Animator := BuildAnimatorFromDocument(Doc);

      SetLength(Meshes, Length(MeshDataList));
      for I := 0 to High(MeshDataList) do
      begin
        Meshes[I].Name := MeshDataList[I].Name;
        Meshes[I].Vertices := MeshDataList[I].Vertices;
        Meshes[I].Indices := MeshDataList[I].Indices;
        Meshes[I].IsSkinned := MeshDataList[I].IsSkinned;
        Meshes[I].SkinWeights := MeshDataList[I].SkinWeights;
        Meshes[I].JointBoneIndices := MeshDataList[I].JointBoneIndices;
        Meshes[I].InverseBindMatrices := MeshDataList[I].InverseBindMatrices;
        Meshes[I].BindMeshMatrix := MeshDataList[I].BindMeshMatrix;
        if (MeshDataList[I].MaterialIndex >= 0) and
           (MeshDataList[I].MaterialIndex < Length(MaterialNamesByIndex)) then
          Meshes[I].MaterialName :=
            MaterialNamesByIndex[MeshDataList[I].MaterialIndex]
        else
          Meshes[I].MaterialName := '';
      end;
    finally
      Doc.Free;
    end;
  except
    Animator.Free;
    Animator := nil;
    Meshes := nil;
    Stream.Free;
    raise;
  end;
  Stream.Free;
end;

{ ---------------------------------------------------------------------------- }
{ Public: load multiple meshes (one per primitive) }
procedure LoadGLTFFileV2(const AFileName: string;
  out VerticesArr: TArray<TArray<TVertex>>; out IndicesArr: TArray<TArray<GLuint>>);
var
  MeshDataList: TArray<TMeshData>;
  MaterialNamesByIndex: TArray<string>;
  i: Integer;
begin
  VerticesArr := nil;
  IndicesArr := nil;
  LoadGLTFData(AFileName, MeshDataList, MaterialNamesByIndex);

  SetLength(VerticesArr, Length(MeshDataList));
  SetLength(IndicesArr, Length(MeshDataList));
  for i := 0 to High(MeshDataList) do
  begin
    VerticesArr[i] := MeshDataList[i].Vertices;
    IndicesArr[i] := MeshDataList[i].Indices;
  end;
end;

procedure LoadGLTFFileV2(const AFileName: string;
  out VerticesArr: TArray<TArray<TVertex>>; out IndicesArr: TArray<TArray<GLuint>>;
  out MaterialNames: TArray<string>);
var
  MeshDataList: TArray<TMeshData>;
  MaterialNamesByIndex: TArray<string>;
  i: Integer;
begin
  VerticesArr := nil;
  IndicesArr := nil;
  MaterialNames := nil;

  LoadGLTFData(AFileName, MeshDataList, MaterialNamesByIndex);

  SetLength(VerticesArr, Length(MeshDataList));
  SetLength(IndicesArr, Length(MeshDataList));
  SetLength(MaterialNames, Length(MeshDataList));
  for i := 0 to High(MeshDataList) do
  begin
    VerticesArr[i] := MeshDataList[i].Vertices;
    IndicesArr[i] := MeshDataList[i].Indices;
    if (MeshDataList[i].MaterialIndex >= 0) and
       (MeshDataList[i].MaterialIndex < Length(MaterialNamesByIndex)) then
      MaterialNames[i] := MaterialNamesByIndex[MeshDataList[i].MaterialIndex]
    else
      MaterialNames[i] := '';
  end;
end;

{ ---------------------------------------------------------------------------- }
{ Single merged mesh version (kept as is) – uses the same helper functions }
procedure LoadGLTFFromFile(const AFileName: string;
  out Vertices: TArray<TVertex>; out Indices: TArray<GLuint>);
var
  MultiVertices: TArray<TArray<TVertex>>;
  MultiIndices: TArray<TArray<GLuint>>;
  i, j, VertexOffset, IndexOffset: Integer;
begin
  LoadGLTFFileV2(AFileName, MultiVertices, MultiIndices);
  if Length(MultiVertices) = 0 then
  begin
    Vertices := nil;
    Indices := nil;
    Exit;
  end;

  var TotalVerts := 0;
  var TotalIndices := 0;
  for i := 0 to High(MultiVertices) do
  begin
    TotalVerts := TotalVerts + Length(MultiVertices[i]);
    TotalIndices := TotalIndices + Length(MultiIndices[i]);
  end;

  SetLength(Vertices, TotalVerts);
  SetLength(Indices, TotalIndices);

  VertexOffset := 0;
  IndexOffset := 0;
  for i := 0 to High(MultiVertices) do
  begin
    var VCount := Length(MultiVertices[i]);
    var ICount := Length(MultiIndices[i]);

    // Copy vertices
    if VCount > 0 then
      Move(MultiVertices[i][0], Vertices[VertexOffset], VCount * SizeOf(TVertex));

    // Copy indices with offset
    for j := 0 to ICount - 1 do
      Indices[IndexOffset + j] := MultiIndices[i][j] + GLuint(VertexOffset);

    Inc(VertexOffset, VCount);
    Inc(IndexOffset, ICount);
  end;
end;

end.
