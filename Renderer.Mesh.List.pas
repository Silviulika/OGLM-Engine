unit Renderer.Mesh.List;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  dglOpenGL, Neslib.FastMath, Renderer.Mesh, Renderer.Mesh.Factory, Engine.Types, Engine.Generators,
  Engine.Animation, Managers.Material, Renderer.Shader, Loader.GLTF, Loader.OBJ;

type
  TMeshList = class(TObjectList<TMesh>)
  private
    FAnimator: TSkeletonAnimator;
    procedure ValidateMeshAnimator(AMesh: TMesh);
    // Helper function for merging an array of meshes
    function MergeMeshesInternal(const Meshes: TArray<TMesh>; IsStatic: Boolean = True): TMesh;

    function GetItem(aIndex: Integer): TMesh;
    procedure SetItem(aIndex: Integer; aMesh: TMesh);
    function GetCount: Integer;

    function GetList: TArray<TMesh>;
    procedure SetList(const Value: TArray<TMesh>);
  public
    destructor Destroy; override;
    // Clears the list, freeing all meshes (inherited Clear does this)
    procedure Clear; reintroduce;
    // Clears the list but does NOT free the meshes - they are extracted and ownership is released
    procedure ClearList;

    // Adds an existing mesh to the end of the list. The list takes ownership.
    function AddMeshToList(aMesh: TMesh): Integer;

    procedure InsertMesh(Index: Integer; Mesh: TMesh);

    function NameOf(aMesh: TMesh): String;                       overload;
    function NameOf(aIndex: Integer): String;                    overload;

    function GetMeshByName(aName: String): TMesh;
    function GetMeshByIndex(aIndex: Integer): TMesh;

    function IndexOf(aName: String): Integer;                    overload;
    function IndexOf(aMesh: TMesh): Integer;                     overload;

    function SetNameOf(aMesh: TMesh; aName: String): Boolean;    overload;
    function SetNameOf(aIndex: Integer; aName: String): Boolean; overload;

    function NameIsUnique(aName: String): Boolean;
    function GenerateUniqueName: String;

    function DeleteMesh(aName: String): Boolean;                 overload;
    function DeleteMesh(aIndex: Integer): Boolean;               overload;

    // Transform methods
    function ApplyTransform(aIndex: Integer; const Translation: TVector3; const RotationRad: TVector3; const Scale: TVector3): Boolean; overload;
    function ApplyTransform(aIndex: Integer; const Translation: TVector3; const Rotation: TQuaternion; const Scale: TVector3): Boolean; overload;
    function GetTransformDescriptor(aIndex: Integer): TMeshTransformDescriptor;
    procedure SetTransformDescriptor(aIndex: Integer; const Descriptor: TMeshTransformDescriptor);

    // Combines another array/list into this one. Takes ownership of the combined meshes.
    function CombineLists(var aList: TArray<TMesh>): Boolean;    overload;
    function CombineLists(aList: TMeshList): Boolean;            overload;

    // Merging methods
    function MergeMeshes(IsStatic: Boolean = True): TMesh; overload;
    function MergeMeshes(const WithList: TArray<TMesh>; IsStatic: Boolean = True): TMesh; overload;
    function MergeMeshes(const WithList: TMeshList; IsStatic: Boolean = True): TMesh;     overload;

    function GetBoundingRadius: Single;
    // Deep clone: creates a new TMeshList with copies of all meshes.
    function Clone: TMeshList;

    procedure UpdateAnimations(ADeltaTime: Single);
    procedure ApplyCurrentPose(AForce: Boolean = False);

    procedure LoadFromFile(const AFileName: string); overload;
    procedure LoadFromFile(const AFileName: string; AMaterialLibrary: TMaterialLibrary;
      AShader: TShader = nil); overload;
    procedure SaveToStream(Stream: TStream);
    procedure LoadFromStream(Stream: TStream);

    property Item[Index: Integer]: TMesh read GetItem write SetItem; default;
    // Returns a copy of the internal list as an array. Use with care � the array does NOT own the meshes.
    property List: TArray<TMesh> read GetList write SetList;
    property Count: Integer read GetCount;
    property AnimationController: TSkeletonAnimator read FAnimator;
  end;

implementation

uses
  System.Math, System.IOUtils, Engine.Paths, Utility.Functions,
  Renderer.Skeleton;

const
  MESH_LIST_VERSION_SENTINEL = -2;
  MESH_LIST_FORMAT_VERSION = 7;
  MESH_KIND_STATIC = 0;
  MESH_KIND_SKELETAL = 1;
  MAX_MESH_LIST_COUNT = 100000;
  DEG_TO_RAD: Single = Pi / 180.0;

function FirstMaterialShader(MaterialLibrary: TMaterialLibrary): TShader;
var
  I: Integer;
  Mat: TMaterial;
begin
  Result := nil;
  if MaterialLibrary = nil then
    Exit;

  for I := 0 to MaterialLibrary.Count - 1 do
  begin
    Mat := MaterialLibrary.Material[I];
    if Assigned(Mat) and Assigned(Mat.Shader) then
      Exit(Mat.Shader);
  end;
end;

function IsIgnoredAssetPath(const AFileName: string): Boolean;
var
  Normalized: string;
begin
  Normalized := StringReplace(ExpandFileName(AFileName), '/', PathDelim, [rfReplaceAll]);
  Normalized := LowerCase(IncludeTrailingPathDelimiter(ExtractFilePath(Normalized)));

  Result := (Pos(PathDelim + 'backup' + PathDelim, Normalized) > 0) or
            (Pos(PathDelim + 'external' + PathDelim, Normalized) > 0);
end;

function IsMaterialAssetFile(const AFileName: string): Boolean;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(AFileName));
  Result := (Ext = '.omemat') or (Ext = '.omeml');
end;

function FindMaterialNameInLibrary(MaterialLibrary: TMaterialLibrary;
  const MaterialName: string): string;
var
  I: Integer;
begin
  Result := '';
  if (MaterialLibrary = nil) or (Trim(MaterialName) = '') then
    Exit;

  for I := 0 to MaterialLibrary.Count - 1 do
    if Assigned(MaterialLibrary.Material[I]) and
       SameText(MaterialLibrary.Material[I].Name, MaterialName) then
      Exit(MaterialLibrary.Material[I].Name);
end;

function DefaultMaterialName(MaterialLibrary: TMaterialLibrary): string;
begin
  Result := '';
  if (MaterialLibrary <> nil) and (MaterialLibrary.Count > 0) and
     Assigned(MaterialLibrary.Material[0]) then
    Result := MaterialLibrary.Material[0].Name;
end;

function AddResolvedMaterial(MaterialLibrary: TMaterialLibrary; Material: TMaterial): string;
begin
  Result := '';
  if (MaterialLibrary = nil) or (Material = nil) then
    Exit;

  Result := FindMaterialNameInLibrary(MaterialLibrary, Material.Name);
  if Result <> '' then
  begin
    Material.Free;
    Exit;
  end;

  Result := Material.Name;
  MaterialLibrary.AddMaterial(Material);
end;

function TryLoadMaterialAssetMatch(const AFileName, MaterialName: string;
  MaterialLibrary: TMaterialLibrary; AShader: TShader; out ResolvedName: string): Boolean;
var
  Ext: string;
  AssetName: string;
  Mat: TMaterial;
begin
  Result := False;
  ResolvedName := '';

  Ext := LowerCase(ExtractFileExt(AFileName));
  if Ext = '.omemat' then
  begin
    if not TMaterial.TryReadNameFromFile(AFileName, AssetName) then
      Exit;
    if not SameText(AssetName, MaterialName) then
      Exit;

    try
      Mat := TMaterial.LoadFromFile(AFileName, AShader);
    except
      Exit;
    end;
    try
      ResolvedName := AddResolvedMaterial(MaterialLibrary, Mat);
      Mat := nil;
      Result := ResolvedName <> '';
    finally
      Mat.Free;
    end;
  end
  else if Ext = '.omeml' then
  begin
    if not TMaterialLibrary.TryLoadMaterialFromFileByName(AFileName,
      MaterialName, AShader, Mat) then
      Exit;

    try
      ResolvedName := AddResolvedMaterial(MaterialLibrary, Mat);
      Mat := nil;
      Result := ResolvedName <> '';
    finally
      Mat.Free;
    end;
  end;
end;

function ResolveMaterialAssetName(const MaterialName: string;
  MaterialLibrary: TMaterialLibrary; AShader: TShader): string;
var
  Files: TArray<string>;
  FileName: string;
  ShaderForImport: TShader;
begin
  Result := DefaultMaterialName(MaterialLibrary);
  if (MaterialLibrary = nil) or (Trim(MaterialName) = '') then
    Exit;

  Result := FindMaterialNameInLibrary(MaterialLibrary, MaterialName);
  if Result <> '' then
    Exit;

  Result := DefaultMaterialName(MaterialLibrary);
  if not TDirectory.Exists(TEnginePaths.MaterialsDir) then
    Exit;

  ShaderForImport := AShader;
  if ShaderForImport = nil then
    ShaderForImport := FirstMaterialShader(MaterialLibrary);

  try
    Files := TDirectory.GetFiles(TEnginePaths.MaterialsDir, '*.*',
      TSearchOption.soAllDirectories);
  except
    Exit;
  end;

  for FileName in Files do
  begin
    if (not IsMaterialAssetFile(FileName)) or IsIgnoredAssetPath(FileName) then
      Continue;

    if TryLoadMaterialAssetMatch(FileName, MaterialName, MaterialLibrary,
      ShaderForImport, Result) then
      Exit;
  end;

  Result := DefaultMaterialName(MaterialLibrary);
end;

{ TMeshList }
destructor TMeshList.Destroy;
begin
  FreeAndNil(FAnimator);
  inherited;
end;

procedure TMeshList.Clear;
begin
  inherited Clear;
  FreeAndNil(FAnimator);
end;

procedure TMeshList.ClearList;
begin
  if Assigned(FAnimator) then
    raise EInvalidOperation.Create(
      'Cannot release meshes from an animated mesh list without transferring its animation controller.');
  // Extract all meshes without freeing them
  while Count > 0 do
    ExtractAt(0);  // Removes and returns the item; we ignore the returned reference
end;

procedure TMeshList.ValidateMeshAnimator(AMesh: TMesh);
begin
  if not (AMesh is TSkeletalMesh) then
    Exit;

  if FAnimator = nil then
    raise EInvalidOperation.Create(
      'A skeletal mesh must be added through its owning animated mesh list.');
  if TSkeletalMesh(AMesh).Animator <> FAnimator then
    raise EInvalidOperation.Create(
      'The skeletal mesh belongs to a different animation controller.');
end;

function TMeshList.AddMeshToList(aMesh: TMesh): Integer;
begin
  if not Assigned(aMesh) then Exit(-1);
  ValidateMeshAnimator(aMesh);
  if not NameIsUnique(aMesh.Name) then
    aMesh.Name := GenerateUniqueName;
  Result := inherited Add(aMesh);
end;

procedure TMeshList.InsertMesh(Index: Integer; Mesh: TMesh);
begin
  if Mesh = nil then
    Exit;
  ValidateMeshAnimator(Mesh);
  if not NameIsUnique(Mesh.Name) then
    Mesh.Name := GenerateUniqueName;
  if Index < 0 then Index := 0;
  if Index > Count then Index := Count;
  inherited Insert(Index, Mesh);
end;

function TMeshList.NameOf(aMesh: TMesh): String;
begin
  if aMesh <> nil then
    Result := aMesh.Name
  else
    Result := 'NameOf method error: Mesh is nil!';
end;

function TMeshList.NameOf(aIndex: Integer): String;
begin
  if (aIndex >= 0) and (aIndex < Count) then
    Result := Items[aIndex].Name
  else
    Result := 'NameOf method error: Index out of bounds!';
end;

function TMeshList.GetMeshByName(aName: String): TMesh;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
    if SameText(Items[i].Name, aName) then
      Exit(Items[i]);
  Result := nil;
end;

function TMeshList.GetMeshByIndex(aIndex: Integer): TMesh;
begin
  if (aIndex >= 0) and (aIndex < Count) then
    Result := Items[aIndex]
  else
    Result := nil;
end;

function TMeshList.IndexOf(aName: String): Integer;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
    if SameText(Items[i].Name, aName) then
      Exit(i);
  Result := -1;
end;

function TMeshList.IndexOf(aMesh: TMesh): Integer;
begin
  Result := inherited IndexOf(aMesh);
end;

function TMeshList.SetNameOf(aMesh: TMesh; aName: String): Boolean;
begin
  if aMesh = nil then Exit(False);
  if NameIsUnique(aName) then
    aMesh.Name := aName
  else
    aMesh.Name := GenerateUniqueName;
  Result := True;
end;

function TMeshList.SetNameOf(aIndex: Integer; aName: String): Boolean;
begin
  if (aIndex < 0) or (aIndex >= Count) then Exit(False);
  if NameIsUnique(aName) then
    Items[aIndex].Name := aName
  else
    Items[aIndex].Name := GenerateUniqueName;
  Result := True;
end;

function TMeshList.NameIsUnique(aName: String): Boolean;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
    if SameText(Items[i].Name, aName) then
      Exit(False);
  Result := True;
end;

function TMeshList.GenerateUniqueName: String;
var
  Counter: Integer;
begin
  Counter := 1;
  repeat
    Result := 'MeshObject_' + Counter.ToString;
    Inc(Counter);
  until NameIsUnique(Result);
end;

function TMeshList.DeleteMesh(aName: String): Boolean;
var
  Idx: Integer;
begin
  Idx := IndexOf(aName);
  if Idx >= 0 then
    Result := DeleteMesh(Idx)
  else
    Result := False;
end;

function TMeshList.DeleteMesh(aIndex: Integer): Boolean;
begin
  if (aIndex < 0) or (aIndex >= Count) then
    Exit(False);
  Delete(aIndex); // TObjectList.Delete frees the object
  Result := True;
end;

function TMeshList.ApplyTransform(aIndex: Integer; const Translation: TVector3; const RotationRad: TVector3; const Scale: TVector3): Boolean;
begin
  if (aIndex < 0) or (aIndex >= Count) then Exit(False);
  Items[aIndex].SetTransform(Translation, RotationRad, Scale);
  Result := True;
end;

function TMeshList.ApplyTransform(aIndex: Integer; const Translation: TVector3; const Rotation: TQuaternion; const Scale: TVector3): Boolean;
begin
  if (aIndex < 0) or (aIndex >= Count) then Exit(False);
  Items[aIndex].SetTransform(Translation, QuaternionToEulerXYZ(Rotation), Scale);
  Result := True;
end;

function TMeshList.GetTransformDescriptor(aIndex: Integer): TMeshTransformDescriptor;
begin
  if (aIndex >= 0) and (aIndex < Count) and Assigned(Items[aIndex]) then
  begin
    Result.Valid := True;
    Result.Position := Items[aIndex].Position;
    Result.Rotation := Items[aIndex].Rotation * (180.0 / Pi);
    Result.Scale := Items[aIndex].Scale;
  end
  else
    Result := UnknownMeshTransformDescriptor;
end;

procedure TMeshList.SetTransformDescriptor(aIndex: Integer; const Descriptor: TMeshTransformDescriptor);
begin
  if (aIndex >= 0) and (aIndex < Count) and Assigned(Items[aIndex]) and
     Descriptor.Valid then
    Items[aIndex].SetTransform(Descriptor.Position,
      Descriptor.Rotation * DEG_TO_RAD, Descriptor.Scale);
end;

function TMeshList.CombineLists(var aList: TArray<TMesh>): Boolean;
var
  Mesh: TMesh;
  NewName: string;
  BaseName: string;
  Counter: Integer;
begin
  Result := False;
  if Length(aList) = 0 then
    Exit(True);

  for Mesh in aList do
    if Mesh is TSkeletalMesh then
      raise EInvalidOperation.Create(
        'Combine the owning TMeshList to preserve skeletal animation data.');

  for Mesh in aList do
  begin
    if Mesh = nil then Continue;
    if not NameIsUnique(Mesh.Name) then
    begin
      BaseName := Mesh.Name;
      Counter := 1;
      repeat
        NewName := BaseName + '_' + Counter.ToString;
        Inc(Counter);
      until NameIsUnique(NewName);
      Mesh.Name := NewName;
    end;
    AddMeshToList(Mesh);
  end;

  SetLength(aList, 0);
  Result := True;
end;

function TMeshList.CombineLists(aList: TMeshList): Boolean;
var
  TempArray: TArray<TMesh>;
  I: Integer;
begin
  if not Assigned(aList) then Exit(False);
  if aList.Count = 0 then Exit(False);

  // A model's skinned primitives must keep their one shared controller.
  if Assigned(aList.FAnimator) then
  begin
    if Assigned(FAnimator) then
      Exit(False);
    FAnimator := aList.FAnimator;
    aList.FAnimator := nil;
  end;

  // Extract all meshes from aList into a temporary array without freeing them
  TempArray := aList.ToArray;
  aList.ClearList;  // aList now no longer owns the meshes

  for I := 0 to High(TempArray) do
    AddMeshToList(TempArray[I]);

  SetLength(TempArray, 0);
  Result := True;
end;

function TMeshList.MergeMeshesInternal(const Meshes: TArray<TMesh>; IsStatic: Boolean): TMesh;
var
  TotalVerts, TotalIndices, i, vertOffset, idx: Integer;
  CombinedVerts: TArray<TVertex>;
  CombinedIndices: TArray<GLuint>;
  UseIndices: Boolean;
  m: TMesh;
  LocalMatrix: TMatrix4;
  NormalMatrix: TMatrix4;
  V: TVertex;
begin
  Result := nil;
  TotalVerts := 0;
  TotalIndices := 0;
  UseIndices := False;

  for m in Meshes do
  begin
    if m = nil then Continue;
    if m is TSkeletalMesh then
      raise EInvalidOperation.Create(
        'Skeletal meshes cannot be merged because that would discard skin weights and animation data.');
    TotalVerts := TotalVerts + m.VertexCount;
    if m.IndexCount > 0 then
      UseIndices := True;
  end;

  if TotalVerts = 0 then Exit;

  SetLength(CombinedVerts, TotalVerts);

  if UseIndices then
  begin
    for m in Meshes do
    begin
      if m = nil then Continue;
      if m.IndexCount > 0 then
        TotalIndices := TotalIndices + m.IndexCount
      else
        TotalIndices := TotalIndices + m.VertexCount;
    end;
    SetLength(CombinedIndices, TotalIndices);
  end;

  vertOffset := 0;
  idx := 0;

  for m in Meshes do
  begin
    if m = nil then Continue;

    LocalMatrix := m.LocalMatrix;
    NormalMatrix := LocalMatrix.Inverse.Transpose;
    for i := 0 to m.VertexCount - 1 do
    begin
      V := m.Vertices[i];
      V.Position := Vector3(LocalMatrix * Vector4(V.Position, 1.0));
      V.Normal := Vector3(NormalMatrix * Vector4(V.Normal, 0.0)).Normalize;
      V.Tangent := Vector3(NormalMatrix * Vector4(V.Tangent, 0.0)).Normalize;
      V.Bitangent := Vector3(NormalMatrix * Vector4(V.Bitangent, 0.0)).Normalize;
      CombinedVerts[vertOffset + i] := V;
    end;

    if UseIndices then
    begin
      if m.IndexCount > 0 then
      begin
        for i := 0 to m.IndexCount - 1 do
          CombinedIndices[idx + i] := m.Indices[i] + vertOffset;
        Inc(idx, m.IndexCount);
      end
      else
      begin
        for i := 0 to m.VertexCount - 1 do
          CombinedIndices[idx + i] := vertOffset + i;
        Inc(idx, m.VertexCount);
      end;
    end;

    Inc(vertOffset, m.VertexCount);
  end;

  // Use the factory to create the merged mesh
  if UseIndices then
    Result := TMeshFactory.CreateMesh(CombinedVerts, CombinedIndices, 'MergedMesh', mtFile, True, IsStatic)
  else
    Result := TMeshFactory.CreateMesh(CombinedVerts, [], 'MergedMesh', mtFile, True, IsStatic);

  Result.Name := 'MergedMesh_' + IntToStr(Random(999999));
  Result.MaterialLibrary := nil;
  Result.LibMaterialname := '';
end;

function TMeshList.MergeMeshes(IsStatic: Boolean): TMesh;
begin
  Result := MergeMeshesInternal(Self.ToArray, IsStatic);
end;

function TMeshList.MergeMeshes(const WithList: TArray<TMesh>; IsStatic: Boolean): TMesh;
var
  Combined: TArray<TMesh>;
  LenSelf, LenOther, i: Integer;
begin
  LenSelf := Self.Count;
  LenOther := Length(WithList);
  SetLength(Combined, LenSelf + LenOther);

  // Copy self references
  for i := 0 to LenSelf - 1 do
    Combined[i] := Self[i];

  // Copy other references
  for i := 0 to LenOther - 1 do
    Combined[LenSelf + i] := WithList[i];

  Result := MergeMeshesInternal(Combined, IsStatic);
end;

function TMeshList.MergeMeshes(const WithList: TMeshList; IsStatic: Boolean): TMesh;
begin
  if WithList = nil then
    Result := nil
  else
    Result := MergeMeshes(WithList.ToArray, IsStatic);
end;

function TMeshList.GetBoundingRadius: Single;
var
  i, j: Integer;
  MaxSq, DistSq: Single;
  V: TVector3;
  LocalMatrix: TMatrix4;
begin
  MaxSq := 0;
  for i := 0 to Count - 1 do
  begin
    if Items[i] = nil then
      Continue;
    LocalMatrix := Items[i].LocalMatrix;
    for j := 0 to High(Items[i].Vertices) do
    begin
      V := Vector3(LocalMatrix * Vector4(Items[i].Vertices[j].Position, 1.0));
      DistSq := V.X*V.X + V.Y*V.Y + V.Z*V.Z;
      if DistSq > MaxSq then MaxSq := DistSq;
    end;
  end;
  Result := Sqrt(MaxSq);
end;

function TMeshList.Clone: TMeshList;
var
  i: Integer;
  NewMesh: TMesh;
begin
  Result := TMeshList.Create;
  if Assigned(FAnimator) then
    Result.FAnimator := FAnimator.Clone;
  for i := 0 to Count - 1 do
  begin
    if Items[i] is TSkeletalMesh then
      NewMesh := TSkeletalMesh(Items[i]).CloneForAnimator(Result.FAnimator)
    else
      NewMesh := Items[i].Clone;
    Result.AddMeshToList(NewMesh);
  end;
end;

procedure TMeshList.UpdateAnimations(ADeltaTime: Single);
begin
  if FAnimator = nil then
    Exit;

  FAnimator.Update(ADeltaTime);
  ApplyCurrentPose;
end;

procedure TMeshList.ApplyCurrentPose(AForce: Boolean);
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if Items[I] is TSkeletalMesh then
      TSkeletalMesh(Items[I]).ApplyPose(AForce);
end;

procedure TMeshList.LoadFromFile(const AFileName: string);
begin
  LoadFromFile(AFileName, nil, nil);
end;

procedure TMeshList.LoadFromFile(const AFileName: string; AMaterialLibrary: TMaterialLibrary;
  AShader: TShader);
var
  ext: string;
  VerticesArr: TArray<TArray<TVertex>>;
  IndicesArr: TArray<TArray<GLuint>>;
  MaterialNames: TArray<string>;
  ModelMeshes: TArray<TGLTFModelMeshData>;
  LoadedAnimator: TSkeletonAnimator;
  SkeletalMesh: TSkeletalMesh;
  i: Integer;
  Mesh: TMesh;
begin
  Clear;
  ext := LowerCase(ExtractFileExt(AFileName));

  if ext = '.obj' then
  begin
    if Assigned(AMaterialLibrary) then
      LoadObjFileV2(AFileName, VerticesArr, IndicesArr, MaterialNames)
    else
      LoadObjFileV2(AFileName, VerticesArr, IndicesArr);

    for i := 0 to High(VerticesArr) do
    begin
      Mesh := TMeshFactory.CreateMesh(VerticesArr[i], IndicesArr[i],
        Format('%s_%d', [ExtractFileName(AFileName), i]), mtFile, True, True);
      if Assigned(AMaterialLibrary) then
      begin
        Mesh.MaterialLibrary := AMaterialLibrary;
        if i <= High(MaterialNames) then
          Mesh.LibMaterialname := ResolveMaterialAssetName(MaterialNames[i],
            AMaterialLibrary, AShader)
        else
          Mesh.LibMaterialname := DefaultMaterialName(AMaterialLibrary);
      end;
      AddMeshToList(Mesh);
    end;
  end
  else if (ext = '.gltf') or (ext = '.glb') then
  begin
    LoadedAnimator := nil;
    try
      LoadGLTFModelFile(AFileName, ModelMeshes, LoadedAnimator);
      FAnimator := LoadedAnimator;
      LoadedAnimator := nil;

      for i := 0 to High(ModelMeshes) do
      begin
        if ModelMeshes[i].IsSkinned then
        begin
          SkeletalMesh := TSkeletalMesh.Create(ModelMeshes[i].Vertices,
            ModelMeshes[i].Indices, ModelMeshes[i].SkinWeights,
            ModelMeshes[i].JointBoneIndices,
            ModelMeshes[i].InverseBindMatrices,
            ModelMeshes[i].BindMeshMatrix, FAnimator,
            ModelMeshes[i].Name, AFileName);
          Mesh := SkeletalMesh;
        end
        else
          Mesh := TMeshFactory.CreateMesh(ModelMeshes[i].Vertices,
            ModelMeshes[i].Indices, ModelMeshes[i].Name, mtFile, False, True);

        if Assigned(AMaterialLibrary) then
        begin
          Mesh.MaterialLibrary := AMaterialLibrary;
          Mesh.LibMaterialname := ResolveMaterialAssetName(
            ModelMeshes[i].MaterialName, AMaterialLibrary, AShader);
        end;
        AddMeshToList(Mesh);
      end;
    except
      LoadedAnimator.Free;
      Clear;
      raise;
    end;
  end
  else
    raise Exception.Create('Unsupported file format: ' + ext);
end;

procedure TMeshList.SaveToStream(Stream: TStream);
var
  I: Integer;
  MeshCount: Integer;
  Version: Integer;
  MeshKind: Byte;
  HasAnimator: Boolean;
begin
  Version := MESH_LIST_VERSION_SENTINEL;
  Stream.WriteBuffer(Version, SizeOf(Version));
  Version := MESH_LIST_FORMAT_VERSION;
  Stream.WriteBuffer(Version, SizeOf(Version));
  HasAnimator := Assigned(FAnimator);
  Stream.WriteBuffer(HasAnimator, SizeOf(HasAnimator));
  if HasAnimator then
    FAnimator.SaveToStream(Stream);
  MeshCount := Count;
  Stream.WriteBuffer(MeshCount, SizeOf(MeshCount));
  for I := 0 to MeshCount - 1 do
  begin
    if Items[I] is TSkeletalMesh then
      MeshKind := MESH_KIND_SKELETAL
    else
      MeshKind := MESH_KIND_STATIC;
    Stream.WriteBuffer(MeshKind, SizeOf(MeshKind));
    Items[I].SaveToStream(Stream);
    if MeshKind = MESH_KIND_SKELETAL then
      TSkeletalMesh(Items[I]).SaveSkinData(Stream);
  end;
end;

procedure ApplyLegacyTransformDescriptorToMesh(Mesh: TMesh;
  const Descriptor: TMeshTransformDescriptor);
var
  MScale: TMatrix4;
  MTrans: TMatrix4;
  RotationRad: TVector3;
  TransformMatrix: TMatrix4;
begin
  if (Mesh = nil) or (not Descriptor.Valid) then
    Exit;

  RotationRad := Descriptor.Rotation * DEG_TO_RAD;
  MScale.InitScaling(Descriptor.Scale);
  MTrans.InitTranslation(Descriptor.Position);
  TransformMatrix := MTrans * EulerToQuaternionXYZ(RotationRad).ToMatrix * MScale;

  // v4 stored mesh transforms as baked vertices plus a descriptor. Convert that
  // representation to unbaked vertices plus native TMesh transform state.
  Mesh.ApplyMatrix(TransformMatrix.Inverse);
  Mesh.SetTransform(Descriptor.Position, RotationRad, Descriptor.Scale);
end;

procedure TMeshList.LoadFromStream(Stream: TStream);
var
  I: Integer;
  MeshCount: Integer;
  MeshListVersion: Integer;
  Mesh: TMesh;
  BaseMesh: TMesh;
  Descriptor: TMeshTransformDescriptor;
  MeshKind: Byte;
  HasAnimator: Boolean;
begin
  Clear;
  Stream.ReadBuffer(MeshCount, SizeOf(MeshCount));
  MeshListVersion := 1;
  if MeshCount = MESH_LIST_VERSION_SENTINEL then
  begin
    Stream.ReadBuffer(MeshListVersion, SizeOf(MeshListVersion));
    if MeshListVersion >= 7 then
    begin
      Stream.ReadBuffer(HasAnimator, SizeOf(HasAnimator));
      if HasAnimator then
        FAnimator := TSkeletonAnimator.LoadFromStream(Stream);
    end;
    Stream.ReadBuffer(MeshCount, SizeOf(MeshCount));
  end;

  if (MeshListVersion < 1) or (MeshListVersion > MESH_LIST_FORMAT_VERSION) then
    raise Exception.CreateFmt('Unsupported mesh-list version %d in scene stream.',
      [MeshListVersion]);
  if (MeshCount < 0) or (MeshCount > MAX_MESH_LIST_COUNT) then
    raise Exception.Create('Invalid mesh-list count in scene stream.');

  for I := 0 to MeshCount - 1 do
  begin
    MeshKind := MESH_KIND_STATIC;
    if MeshListVersion >= 7 then
    begin
      Stream.ReadBuffer(MeshKind, SizeOf(MeshKind));
      if not (MeshKind in [MESH_KIND_STATIC, MESH_KIND_SKELETAL]) then
        raise Exception.CreateFmt('Unsupported mesh kind %d in scene stream.',
          [MeshKind]);
    end;

    BaseMesh := TMesh.LoadFromStream(Stream, MeshListVersion);
    if MeshKind = MESH_KIND_SKELETAL then
    begin
      try
        Mesh := TSkeletalMesh.LoadSkinData(BaseMesh, Stream, FAnimator);
      finally
        BaseMesh.Free;
      end;
    end
    else
      Mesh := BaseMesh;
    inherited Add(Mesh);
    if (MeshListVersion >= 4) and (MeshListVersion < 5) then
    begin
      Stream.ReadBuffer(Descriptor, SizeOf(Descriptor));
      ApplyLegacyTransformDescriptorToMesh(Mesh, Descriptor);
    end;
  end;
end;
// Private property getters/setters
function TMeshList.GetItem(aIndex: Integer): TMesh;
begin
  Result := GetMeshByIndex(aIndex);
end;

procedure TMeshList.SetItem(aIndex: Integer; aMesh: TMesh);
begin
  if (aIndex >= 0) and (aIndex < Count) and Assigned(aMesh) then
  begin
    ValidateMeshAnimator(aMesh);
    if not NameIsUnique(aMesh.Name) then
      aMesh.Name := GenerateUniqueName;
    Items[aIndex] := aMesh;
  end;
end;

function TMeshList.GetCount: Integer;
begin
  Result := inherited Count;
end;

function TMeshList.GetList: TArray<TMesh>;
begin
  Result := Self.ToArray;
end;

procedure TMeshList.SetList(const Value: TArray<TMesh>);
var
  m: TMesh;
begin
  for m in Value do
    if m is TSkeletalMesh then
      raise EInvalidOperation.Create(
        'Assign the owning animated TMeshList instead of a skeletal mesh array.');

  Clear;
  for m in Value do
    AddMeshToList(m);
end;

end.
