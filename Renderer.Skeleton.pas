unit Renderer.Skeleton;

interface

uses
  System.Classes, System.SysUtils, System.Math,
  dglOpenGL, Neslib.FastMath,
  Engine.Types, Engine.Animation, Renderer.Mesh, Renderer.Shader,
  Managers.Material;

type
  TGPUSkinVertex = packed record
    Joints0: array[0..3] of GLuint;
    Weights0: array[0..3] of GLfloat;
    Joints1: array[0..3] of GLuint;
    Weights1: array[0..3] of GLfloat;
  end;

  TSkeletalMesh = class(TFileMesh)
  private
    FBindVertices: TArray<TVertex>;
    FSkinWeights: TArray<TVertexSkinWeights>;
    FJointBoneIndices: TArray<Integer>;
    FInverseBindMatrices: TArray<TMatrix4>;
    FBindMeshMatrix: TMatrix4;
    FInverseBindMeshMatrix: TMatrix4;
    FAnimator: TSkeletonAnimator;
    FLastPoseVersion: UInt64;
    FSkinVBO: GLuint;
    FBonePaletteBuffer: GLuint;
    FBonePaletteBufferSize: NativeInt;
    FJointMatrices: TArray<TMatrix4>;
    FGPUSkinningActive: Boolean;
    procedure SetAnimator(const Value: TSkeletonAnimator);
    procedure CreateSkinBuffers;
    procedure DestroySkinBuffers;
    function UsesGPUSkinning: Boolean;
    procedure ActivateGPUSkinning;
    procedure BuildJointMatrices;
    procedure UpdateGPUPose(AForce: Boolean);
    procedure ApplyCPUPose(AForce: Boolean);
  public
    constructor Create(const AVertices: TArray<TVertex>;
      const AIndices: TArray<GLuint>;
      const ASkinWeights: TArray<TVertexSkinWeights>;
      const AJointBoneIndices: TArray<Integer>;
      const AInverseBindMatrices: TArray<TMatrix4>;
      const ABindMeshMatrix: TMatrix4; AAnimator: TSkeletonAnimator;
      const AName, ASourceFile: string);
    destructor Destroy; override;

    function Clone: TMesh; override;
    function CloneForAnimator(AAnimator: TSkeletonAnimator): TSkeletalMesh;
    procedure CaptureBindGeometry;
    procedure ApplyPose(AForce: Boolean = False);
    procedure PrepareShader(AShader: TShader); override;
    procedure DrawCulled(const AFrustumPlanes: TFrustumPlanes;
      AUseFrustum: Boolean); override;
    procedure DrawGeometryOnlyCulled(const AFrustumPlanes: TFrustumPlanes;
      AUseFrustum: Boolean); override;

    procedure SaveSkinData(AStream: TStream);
    class function LoadSkinData(ABaseMesh: TMesh; AStream: TStream;
      AAnimator: TSkeletonAnimator): TSkeletalMesh; static;

    property BindVertices: TArray<TVertex> read FBindVertices;
    property SkinWeights: TArray<TVertexSkinWeights> read FSkinWeights;
    property JointBoneIndices: TArray<Integer> read FJointBoneIndices;
    property InverseBindMatrices: TArray<TMatrix4> read FInverseBindMatrices;
    property BindMeshMatrix: TMatrix4 read FBindMeshMatrix;
    property Animator: TSkeletonAnimator read FAnimator write SetAnimator;
  end;

implementation

uses
  Loader.GLTF;

const
  SKELETAL_MESH_STREAM_VERSION = 2;
  MAX_SERIALIZED_SKIN_VERTICES = 16777216;
  MAX_SERIALIZED_SKIN_JOINTS = 65536;
  SKIN_PALETTE_BUFFER_BINDING = 3;

procedure ValidateArrayCount(AStream: TStream; ACount, AElementSize,
  AMaximum: Integer; const ADescription: string);
var
  ByteCount: Int64;
begin
  if (ACount < 0) or (ACount > AMaximum) then
    raise Exception.CreateFmt('Invalid %s in skeletal mesh stream.',
      [ADescription]);
  ByteCount := Int64(ACount) * AElementSize;
  if ByteCount > AStream.Size - AStream.Position then
    raise Exception.CreateFmt('Truncated %s in skeletal mesh stream.',
      [ADescription]);
end;

constructor TSkeletalMesh.Create(const AVertices: TArray<TVertex>;
  const AIndices: TArray<GLuint>;
  const ASkinWeights: TArray<TVertexSkinWeights>;
  const AJointBoneIndices: TArray<Integer>;
  const AInverseBindMatrices: TArray<TMatrix4>;
  const ABindMeshMatrix: TMatrix4; AAnimator: TSkeletonAnimator;
  const AName, ASourceFile: string);
begin
  if Length(ASkinWeights) <> Length(AVertices) then
    raise Exception.CreateFmt(
      'Skeletal mesh has %d vertices but %d skin-weight records.',
      [Length(AVertices), Length(ASkinWeights)]);
  if Length(AJointBoneIndices) <> Length(AInverseBindMatrices) then
    raise Exception.CreateFmt(
      'Skeletal mesh has %d joints but %d inverse bind matrices.',
      [Length(AJointBoneIndices), Length(AInverseBindMatrices)]);

  inherited Create(AVertices, AIndices, AName, ASourceFile, False);
  FBindVertices := Copy(AVertices);
  FSkinWeights := Copy(ASkinWeights);
  FJointBoneIndices := Copy(AJointBoneIndices);
  FInverseBindMatrices := Copy(AInverseBindMatrices);
  FBindMeshMatrix := ABindMeshMatrix;
  FInverseBindMeshMatrix := FBindMeshMatrix.Inverse;
  FAnimator := AAnimator;
  FSkinVBO := 0;
  FBonePaletteBuffer := 0;
  FBonePaletteBufferSize := 0;
  FGPUSkinningActive := False;
  FLastPoseVersion := 0;
  CreateSkinBuffers;
  ApplyPose(True);
end;

destructor TSkeletalMesh.Destroy;
begin
  DestroySkinBuffers;
  SetLength(FJointMatrices, 0);
  inherited Destroy;
end;

procedure TSkeletalMesh.CreateSkinBuffers;
var
  GPUData: TArray<TGPUSkinVertex>;
  VertexIndex, InfluenceIndex, JointSlot: Integer;
  Influence: TBoneInfluence;
  BufferData: Pointer;
begin
  DestroySkinBuffers;
  if (fVAO = 0) or (Length(FSkinWeights) <> Length(FBindVertices)) then
    Exit;

  SetLength(GPUData, Length(FSkinWeights));
  if Length(GPUData) > 0 then
    FillChar(GPUData[0], Length(GPUData) * SizeOf(TGPUSkinVertex), 0);

  for VertexIndex := 0 to High(FSkinWeights) do
    for InfluenceIndex := 0 to MAX_VERTEX_BONE_INFLUENCES - 1 do
    begin
      Influence := FSkinWeights[VertexIndex].Influences[InfluenceIndex];
      JointSlot := Influence.Joint;
      if (Influence.Weight <= 0.0) or (JointSlot < 0) or
         (JointSlot >= Length(FJointBoneIndices)) or
         (JointSlot >= Length(FInverseBindMatrices)) then
        Continue;

      if InfluenceIndex < 4 then
      begin
        GPUData[VertexIndex].Joints0[InfluenceIndex] := GLuint(JointSlot);
        GPUData[VertexIndex].Weights0[InfluenceIndex] := Influence.Weight;
      end
      else
      begin
        GPUData[VertexIndex].Joints1[InfluenceIndex - 4] := GLuint(JointSlot);
        GPUData[VertexIndex].Weights1[InfluenceIndex - 4] := Influence.Weight;
      end;
    end;

  glBindVertexArray(fVAO);
  glGenBuffers(1, @FSkinVBO);
  glBindBuffer(GL_ARRAY_BUFFER, FSkinVBO);
  if Length(GPUData) > 0 then
    BufferData := @GPUData[0]
  else
    BufferData := nil;
  glBufferData(GL_ARRAY_BUFFER, Length(GPUData) * SizeOf(TGPUSkinVertex),
    BufferData, GL_STATIC_DRAW);

  glEnableVertexAttribArray(6);
  glVertexAttribIPointer(6, 4, GL_UNSIGNED_INT, SizeOf(TGPUSkinVertex),
    Pointer(0));
  glEnableVertexAttribArray(7);
  glVertexAttribPointer(7, 4, GL_FLOAT, GL_FALSE, SizeOf(TGPUSkinVertex),
    Pointer(SizeOf(GLuint) * 4));
  glEnableVertexAttribArray(8);
  glVertexAttribIPointer(8, 4, GL_UNSIGNED_INT, SizeOf(TGPUSkinVertex),
    Pointer((SizeOf(GLuint) + SizeOf(GLfloat)) * 4));
  glEnableVertexAttribArray(9);
  glVertexAttribPointer(9, 4, GL_FLOAT, GL_FALSE, SizeOf(TGPUSkinVertex),
    Pointer((SizeOf(GLuint) * 2 + SizeOf(GLfloat)) * 4));

  glBindVertexArray(0);
  glBindBuffer(GL_ARRAY_BUFFER, 0);

  if Length(FJointBoneIndices) > 0 then
  begin
    FBonePaletteBufferSize := Length(FJointBoneIndices) * SizeOf(TMatrix4);
    glGenBuffers(1, @FBonePaletteBuffer);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, FBonePaletteBuffer);
    glBufferData(GL_SHADER_STORAGE_BUFFER, FBonePaletteBufferSize, nil,
      GL_DYNAMIC_DRAW);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);
  end;
end;

procedure TSkeletalMesh.DestroySkinBuffers;
begin
  if FSkinVBO <> 0 then
  begin
    glDeleteBuffers(1, @FSkinVBO);
    FSkinVBO := 0;
  end;
  if FBonePaletteBuffer <> 0 then
  begin
    glDeleteBuffers(1, @FBonePaletteBuffer);
    FBonePaletteBuffer := 0;
  end;
  FBonePaletteBufferSize := 0;
end;

procedure TSkeletalMesh.SetAnimator(const Value: TSkeletonAnimator);
begin
  if FAnimator = Value then
    Exit;
  FAnimator := Value;
  FLastPoseVersion := 0;
  ApplyPose(True);
end;

function ShaderSupportsGPUSkinning(AShader: TShader): Boolean;
var
  VertexShaderName: string;
begin
  Result := False;
  if AShader = nil then
    Exit;

  VertexShaderName := ChangeFileExt(ExtractFileName(AShader.VertexPath), '');
  Result := SameText(VertexShaderName, 'Actor_PBR') or
    SameText(VertexShaderName, 'PBR_POM_4');
end;

function TSkeletalMesh.UsesGPUSkinning: Boolean;
var
  Mat: TMaterial;
begin
  Result := False;
  if (FAnimator = nil) or (FSkinVBO = 0) or (FBonePaletteBuffer = 0) or
     (fMaterialLibrary = nil) then
    Exit;

  if fLibMaterialname <> '' then
    Mat := fMaterialLibrary.GetMaterial(fLibMaterialname)
  else if fMaterialLibrary.Count > 0 then
    Mat := fMaterialLibrary.Material[0]
  else
    Mat := nil;

  Result := Assigned(Mat) and Assigned(Mat.Shader) and
    ((Mat.Materialtype = mtActor) or ShaderSupportsGPUSkinning(Mat.Shader));
end;

procedure TSkeletalMesh.ActivateGPUSkinning;
begin
  if FGPUSkinningActive then
    Exit;

  fVertices := Copy(FBindVertices);
  ComputeBoundingBox;
  RefreshVertexBuffer;
  FGPUSkinningActive := True;
  FLastPoseVersion := 0;
end;

procedure TSkeletalMesh.BuildJointMatrices;
var
  JointSlot, BoneIndex: Integer;
  Bone: TSkeletonBone;
begin
  SetLength(FJointMatrices, Length(FJointBoneIndices));
  for JointSlot := 0 to High(FJointMatrices) do
  begin
    FJointMatrices[JointSlot] := TMatrix4.Identity;
    if (FAnimator = nil) or
       (JointSlot >= Length(FInverseBindMatrices)) then
      Continue;

    BoneIndex := FJointBoneIndices[JointSlot];
    if (BoneIndex < 0) or (BoneIndex >= FAnimator.Skeleton.BoneCount) then
      Continue;
    Bone := FAnimator.Skeleton.Bones[BoneIndex];
    if Bone = nil then
      Continue;

    FJointMatrices[JointSlot] := Bone.GlobalMatrix *
      FInverseBindMatrices[JointSlot] * FInverseBindMeshMatrix;
  end;
end;

procedure TSkeletalMesh.UpdateGPUPose(AForce: Boolean);
var
  RequiredSize: NativeInt;
begin
  if (FAnimator = nil) or (FBonePaletteBuffer = 0) then
    Exit;

  ActivateGPUSkinning;
  if (not AForce) and (FLastPoseVersion = FAnimator.PoseVersion) then
    Exit;

  BuildJointMatrices;
  if Length(FJointMatrices) = 0 then
    Exit;

  RequiredSize := Length(FJointMatrices) * SizeOf(TMatrix4);
  glBindBuffer(GL_SHADER_STORAGE_BUFFER, FBonePaletteBuffer);
  if RequiredSize <> FBonePaletteBufferSize then
  begin
    glBufferData(GL_SHADER_STORAGE_BUFFER, RequiredSize, @FJointMatrices[0],
      GL_DYNAMIC_DRAW);
    FBonePaletteBufferSize := RequiredSize;
  end
  else
    glBufferSubData(GL_SHADER_STORAGE_BUFFER, 0, RequiredSize,
      @FJointMatrices[0]);
  glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);
  FLastPoseVersion := FAnimator.PoseVersion;
end;

procedure TSkeletalMesh.PrepareShader(AShader: TShader);
begin
  if AShader = nil then
    Exit;

  if UsesGPUSkinning then
  begin
    UpdateGPUPose(False);
    if FGPUSkinningActive then
    begin
      AShader.SetUniform('useSkinning', GLint(1));
      AShader.SetUniform('skinMatrixCount', GLint(Length(FJointMatrices)));
      glBindBufferBase(GL_SHADER_STORAGE_BUFFER, SKIN_PALETTE_BUFFER_BINDING,
        FBonePaletteBuffer);
      Exit;
    end;
  end
  else if FGPUSkinningActive then
    ApplyCPUPose(True);

  inherited PrepareShader(AShader);
end;

procedure TSkeletalMesh.DrawCulled(const AFrustumPlanes: TFrustumPlanes;
  AUseFrustum: Boolean);
begin
  if UsesGPUSkinning then
    Draw
  else
    inherited DrawCulled(AFrustumPlanes, AUseFrustum);
end;

procedure TSkeletalMesh.DrawGeometryOnlyCulled(
  const AFrustumPlanes: TFrustumPlanes; AUseFrustum: Boolean);
begin
  if UsesGPUSkinning then
    DrawGeometryOnly
  else
    inherited DrawGeometryOnlyCulled(AFrustumPlanes, AUseFrustum);
end;

function TSkeletalMesh.Clone: TMesh;
begin
  Result := CloneForAnimator(FAnimator);
end;

function TSkeletalMesh.CloneForAnimator(
  AAnimator: TSkeletonAnimator): TSkeletalMesh;
begin
  Result := TSkeletalMesh.Create(FBindVertices, fIndices, FSkinWeights,
    FJointBoneIndices, FInverseBindMatrices, FBindMeshMatrix, AAnimator,
    fName + '_Clone', SourceFile);
  CopyRenderStateTo(Result);
  Result.FBindVertices := Copy(FBindVertices);
  Result.FLastPoseVersion := 0;
  Result.ApplyPose(True);
end;

procedure TSkeletalMesh.CaptureBindGeometry;
begin
  FBindVertices := Copy(fVertices);
  CreateSkinBuffers;
  FGPUSkinningActive := False;
  FLastPoseVersion := 0;
  ApplyPose(True);
end;

procedure TSkeletalMesh.ApplyPose(AForce: Boolean);
begin
  if UsesGPUSkinning then
    UpdateGPUPose(AForce)
  else
    ApplyCPUPose(AForce);
end;

procedure TSkeletalMesh.ApplyCPUPose(AForce: Boolean);
var
  VertexIndex, InfluenceIndex, JointSlot, BoneIndex: Integer;
  Influence: TBoneInfluence;
  Bone: TSkeletonBone;
  SkinMatrix: TMatrix4;
  JointMatrices: TArray<TMatrix4>;
  JointMatrixValid: TArray<Boolean>;
  Position4, Normal4, Tangent4, Bitangent4: TVector4;
  Position, Normal, Tangent, Bitangent: TVector3;
  TotalWeight: Single;
  Vertex: TVertex;
  BoundsInitialized: Boolean;
begin
  if FGPUSkinningActive then
  begin
    FGPUSkinningActive := False;
    FLastPoseVersion := 0;
  end;
  if FAnimator = nil then
    Exit;
  if (not AForce) and (FLastPoseVersion = FAnimator.PoseVersion) then
    Exit;
  if Length(FBindVertices) <> Length(FSkinWeights) then
    Exit;

  // A joint matrix is shared by every vertex influenced by that joint. Build
  // it once per pose instead of repeating two matrix multiplies per influence.
  SetLength(JointMatrices, Length(FJointBoneIndices));
  SetLength(JointMatrixValid, Length(FJointBoneIndices));
  for JointSlot := 0 to High(FJointBoneIndices) do
  begin
    if JointSlot >= Length(FInverseBindMatrices) then
      Continue;
    BoneIndex := FJointBoneIndices[JointSlot];
    if (BoneIndex < 0) or (BoneIndex >= FAnimator.Skeleton.BoneCount) then
      Continue;
    Bone := FAnimator.Skeleton.Bones[BoneIndex];
    if Bone = nil then
      Continue;
    JointMatrices[JointSlot] := Bone.GlobalMatrix *
      FInverseBindMatrices[JointSlot] * FInverseBindMeshMatrix;
    JointMatrixValid[JointSlot] := True;
  end;

  SetLength(fVertices, Length(FBindVertices));
  BoundsInitialized := False;
  for VertexIndex := 0 to High(FBindVertices) do
  begin
    Position := Vector3(0.0, 0.0, 0.0);
    Normal := Vector3(0.0, 0.0, 0.0);
    Tangent := Vector3(0.0, 0.0, 0.0);
    Bitangent := Vector3(0.0, 0.0, 0.0);
    TotalWeight := 0.0;

    for InfluenceIndex := Low(FSkinWeights[VertexIndex].Influences) to
      High(FSkinWeights[VertexIndex].Influences) do
    begin
      Influence := FSkinWeights[VertexIndex].Influences[InfluenceIndex];
      if (Influence.Weight <= 0.0) or (Influence.Joint < 0) then
        Continue;
      JointSlot := Influence.Joint;
      if (JointSlot >= Length(FJointBoneIndices)) or
         (JointSlot >= Length(FInverseBindMatrices)) then
        Continue;
      if not JointMatrixValid[JointSlot] then
        Continue;

      SkinMatrix := JointMatrices[JointSlot];
      Position4 := SkinMatrix * Vector4(FBindVertices[VertexIndex].Position, 1.0);
      Normal4 := SkinMatrix * Vector4(FBindVertices[VertexIndex].Normal, 0.0);
      Tangent4 := SkinMatrix * Vector4(FBindVertices[VertexIndex].Tangent, 0.0);
      Bitangent4 := SkinMatrix * Vector4(FBindVertices[VertexIndex].Bitangent, 0.0);

      Position := Position + Vector3(Position4) * Influence.Weight;
      Normal := Normal + Vector3(Normal4) * Influence.Weight;
      Tangent := Tangent + Vector3(Tangent4) * Influence.Weight;
      Bitangent := Bitangent + Vector3(Bitangent4) * Influence.Weight;
      TotalWeight := TotalWeight + Influence.Weight;
    end;

    Vertex := FBindVertices[VertexIndex];
    if TotalWeight > 1.0e-8 then
    begin
      if Abs(TotalWeight - 1.0) > 1.0e-5 then
      begin
        Position := Position / TotalWeight;
        Normal := Normal / TotalWeight;
        Tangent := Tangent / TotalWeight;
        Bitangent := Bitangent / TotalWeight;
      end;
      Vertex.Position := Position;
      if Normal.LengthSquared > 1.0e-10 then
        Vertex.Normal := Normal.Normalize;
      if Tangent.LengthSquared > 1.0e-10 then
        Vertex.Tangent := Tangent.Normalize;
      if Bitangent.LengthSquared > 1.0e-10 then
        Vertex.Bitangent := Bitangent.Normalize;
    end;
    fVertices[VertexIndex] := Vertex;

    if not BoundsInitialized then
    begin
      fBoundingBoxMin := Vertex.Position;
      fBoundingBoxMax := Vertex.Position;
      BoundsInitialized := True;
    end
    else
    begin
      if Vertex.Position.X < fBoundingBoxMin.X then fBoundingBoxMin.X := Vertex.Position.X;
      if Vertex.Position.Y < fBoundingBoxMin.Y then fBoundingBoxMin.Y := Vertex.Position.Y;
      if Vertex.Position.Z < fBoundingBoxMin.Z then fBoundingBoxMin.Z := Vertex.Position.Z;
      if Vertex.Position.X > fBoundingBoxMax.X then fBoundingBoxMax.X := Vertex.Position.X;
      if Vertex.Position.Y > fBoundingBoxMax.Y then fBoundingBoxMax.Y := Vertex.Position.Y;
      if Vertex.Position.Z > fBoundingBoxMax.Z then fBoundingBoxMax.Z := Vertex.Position.Z;
    end;
  end;

  if not BoundsInitialized then
  begin
    fBoundingBoxMin := Vector3(0.0, 0.0, 0.0);
    fBoundingBoxMax := fBoundingBoxMin;
  end;
  RefreshVertexBuffer;
  FLastPoseVersion := FAnimator.PoseVersion;
end;

procedure TSkeletalMesh.SaveSkinData(AStream: TStream);
var
  Version, CountValue: Integer;
begin
  Version := SKELETAL_MESH_STREAM_VERSION;
  AStream.WriteBuffer(Version, SizeOf(Version));

  CountValue := Length(FBindVertices);
  AStream.WriteBuffer(CountValue, SizeOf(CountValue));
  if CountValue > 0 then
    AStream.WriteBuffer(FBindVertices[0], CountValue * SizeOf(TVertex));

  CountValue := Length(FSkinWeights);
  AStream.WriteBuffer(CountValue, SizeOf(CountValue));
  if CountValue > 0 then
    AStream.WriteBuffer(FSkinWeights[0],
      CountValue * SizeOf(TVertexSkinWeights));

  CountValue := Length(FJointBoneIndices);
  AStream.WriteBuffer(CountValue, SizeOf(CountValue));
  if CountValue > 0 then
  begin
    AStream.WriteBuffer(FJointBoneIndices[0], CountValue * SizeOf(Integer));
    AStream.WriteBuffer(FInverseBindMatrices[0], CountValue * SizeOf(TMatrix4));
  end;
  AStream.WriteBuffer(FBindMeshMatrix, SizeOf(FBindMeshMatrix));
end;

class function TSkeletalMesh.LoadSkinData(ABaseMesh: TMesh; AStream: TStream;
  AAnimator: TSkeletonAnimator): TSkeletalMesh;
var
  Version, CountValue, JointCount: Integer;
  BindVertices: TArray<TVertex>;
  SkinWeights: TArray<TVertexSkinWeights>;
  JointBoneIndices: TArray<Integer>;
  InverseBindMatrices: TArray<TMatrix4>;
  BindMeshMatrix: TMatrix4;
  SourceFileName: string;
begin
  if ABaseMesh = nil then
    raise Exception.Create('Cannot load skeletal data without a base mesh.');
  if AAnimator = nil then
    raise Exception.Create('Cannot load skeletal data without an animator.');

  AStream.ReadBuffer(Version, SizeOf(Version));
  if (Version < 1) or (Version > SKELETAL_MESH_STREAM_VERSION) then
    raise Exception.CreateFmt('Unsupported skeletal mesh stream version %d.',
      [Version]);

  AStream.ReadBuffer(CountValue, SizeOf(CountValue));
  ValidateArrayCount(AStream, CountValue, SizeOf(TVertex),
    MAX_SERIALIZED_SKIN_VERTICES, 'bind vertex count');
  SetLength(BindVertices, CountValue);
  if CountValue > 0 then
    AStream.ReadBuffer(BindVertices[0], CountValue * SizeOf(TVertex));

  AStream.ReadBuffer(CountValue, SizeOf(CountValue));
  ValidateArrayCount(AStream, CountValue, SizeOf(TVertexSkinWeights),
    MAX_SERIALIZED_SKIN_VERTICES, 'skin-weight count');
  SetLength(SkinWeights, CountValue);
  if CountValue > 0 then
    AStream.ReadBuffer(SkinWeights[0],
      CountValue * SizeOf(TVertexSkinWeights));

  AStream.ReadBuffer(JointCount, SizeOf(JointCount));
  ValidateArrayCount(AStream, JointCount, SizeOf(Integer),
    MAX_SERIALIZED_SKIN_JOINTS, 'skin joint count');
  SetLength(JointBoneIndices, JointCount);
  if JointCount > 0 then
    AStream.ReadBuffer(JointBoneIndices[0], JointCount * SizeOf(Integer));
  ValidateArrayCount(AStream, JointCount, SizeOf(TMatrix4),
    MAX_SERIALIZED_SKIN_JOINTS, 'inverse bind matrix count');
  SetLength(InverseBindMatrices, JointCount);
  if JointCount > 0 then
    AStream.ReadBuffer(InverseBindMatrices[0], JointCount * SizeOf(TMatrix4));
  AStream.ReadBuffer(BindMeshMatrix, SizeOf(BindMeshMatrix));

  SourceFileName := '';
  if ABaseMesh is TFileMesh then
    SourceFileName := TFileMesh(ABaseMesh).SourceFile;
  if (Version = 1) and
     GLTFUsesLegacyKhronos3DSMaxSkinLayout(SourceFileName) then
    for CountValue := 0 to High(BindVertices) do
      BindVertices[CountValue].Position := BindVertices[CountValue].Position -
        Vector3(BindMeshMatrix.Columns[3]);
  Result := TSkeletalMesh.Create(BindVertices, ABaseMesh.Indices, SkinWeights,
    JointBoneIndices, InverseBindMatrices, BindMeshMatrix, AAnimator,
    ABaseMesh.Name, SourceFileName);
  Result.MaterialLibrary := ABaseMesh.MaterialLibrary;
  Result.MaterialLibraryName := ABaseMesh.MaterialLibraryName;
  Result.LibMaterialname := ABaseMesh.LibMaterialname;
  Result.Position := ABaseMesh.Position;
  Result.Rotation := ABaseMesh.Rotation;
  Result.Scale := ABaseMesh.Scale;
  Result.ParentModelMatrix := ABaseMesh.ParentModelMatrix;
  Result.Visible := ABaseMesh.Visible;
  Result.WireFrame := ABaseMesh.WireFrame;
  Result.AlwaysOnTop := ABaseMesh.AlwaysOnTop;
  Result.Tag := ABaseMesh.Tag;
  Result.OnRender := ABaseMesh.OnRender;
  Result.ApplyPose(True);
end;

end.
