unit Loader.OBJ;

interface

uses
  Neslib.FastMath, dglOpenGL, Engine.Types,
  System.Classes, System.SysUtils, System.Generics.Collections,
  System.Generics.Defaults, System.Math;

// Single merged mesh (kept for compatibility)
procedure LoadObjFromFile(const AFileName: string; out Vertices: TArray<TVertex>;
  out Indices: TArray<GLuint>);

// Multiple meshes � one per object/group
procedure LoadObjFileV2(const AFileName: string;
  out VerticesArr: TArray<TArray<TVertex>>; out IndicesArr: TArray<TArray<GLuint>>); overload;
procedure LoadObjFileV2(const AFileName: string;
  out VerticesArr: TArray<TArray<TVertex>>; out IndicesArr: TArray<TArray<GLuint>>;
  out MaterialNames: TArray<string>); overload;

implementation

type
  TVector3List = TList<TVector3>;
  TVector2List = TList<TVector2>;

  TVertexIndex = record
    PosIdx, TexIdx, NormIdx: Integer;
  end;
  TTriangle = array[0..2] of TVertexIndex;
  TTriangleList = TList<TTriangle>;

  // Local mesh data � no external dependencies
  TObjMeshData = record
    Name: string;
    MaterialName: string;
    Triangles: TTriangleList;
  end;
  TObjMeshDataList = TList<TObjMeshData>;

// ----------------------------------------------------------------------------
// Generate planar UVs for a triangle given its vertices and face normal
// ----------------------------------------------------------------------------
procedure GenerateUVsForTriangle(const p0, p1, p2: TVector3; const normal: TVector3;
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

  uv0 := Vector2(p0.Dot(uAxis), p0.Dot(vAxis));
  uv1 := Vector2(p1.Dot(uAxis), p1.Dot(vAxis));
  uv2 := Vector2(p2.Dot(uAxis), p2.Dot(vAxis));
end;

// ----------------------------------------------------------------------------
// Parse a single face vertex entry (e.g. "1/2/3", "1//3", "1/2", "1")
// ----------------------------------------------------------------------------
function ParseFaceVertex(const S: string): TVertexIndex;
var
  Parts: TArray<string>;
begin
  Parts := S.Split(['/']);
  Result.PosIdx := StrToInt(Parts[0]) - 1;
  if Length(Parts) > 1 then
  begin
    if Parts[1] <> '' then
      Result.TexIdx := StrToInt(Parts[1]) - 1
    else
      Result.TexIdx := -1;
  end
  else
    Result.TexIdx := -1;

  if Length(Parts) > 2 then
  begin
    if Parts[2] <> '' then
      Result.NormIdx := StrToInt(Parts[2]) - 1
    else
      Result.NormIdx := -1;
  end
  else
    Result.NormIdx := -1;
end;

// ----------------------------------------------------------------------------
// Single merged mesh version (original)
// ----------------------------------------------------------------------------
procedure LoadObjFromFile(const AFileName: string; out Vertices: TArray<TVertex>;
  out Indices: TArray<GLuint>);
var
  PosList: TVector3List;
  TexList: TVector2List;
  NormList: TVector3List;
  Triangles: TTriangleList;
  Reader: TStreamReader;
  Line, Token: string;
  Parts: TArray<string>;
  i, j: Integer;
  Poly: TList<TVertexIndex>;
  FaceVert: TVertexIndex;
  tri: TTriangle;
  p0, p1, p2: TVector3;
  hasTex, hasNorm: Boolean;
  uv0, uv1, uv2: TVector2;
  faceNormal: TVector3;
  VertexList: TList<TVertex>;
  vtx: TVertex;
  idx: Integer;
begin
  Vertices := nil;
  Indices := nil;
  if not FileExists(AFileName) then
    raise Exception.Create('OBJ file not found: ' + AFileName);

  PosList := TVector3List.Create;
  TexList := TVector2List.Create;
  NormList := TVector3List.Create;
  Triangles := TTriangleList.Create;
  Poly := TList<TVertexIndex>.Create;
  try
    Reader := TStreamReader.Create(AFileName, TEncoding.UTF8);
    try
      while not Reader.EndOfStream do
      begin
        Line := Trim(Reader.ReadLine);
        if (Line = '') or (Line.StartsWith('#')) then Continue;
        Parts := Line.Split([' ', #9], TStringSplitOptions.ExcludeEmpty);
        if Length(Parts) = 0 then Continue;
        Token := LowerCase(Parts[0]);

        if Token = 'v' then
        begin
          if Length(Parts) >= 4 then
            PosList.Add(Vector3(StrToFloat(Parts[1]), StrToFloat(Parts[2]), StrToFloat(Parts[3])))
          else
            PosList.Add(TVector3.Zero);
        end
        else if Token = 'vt' then
        begin
          if Length(Parts) >= 3 then
            TexList.Add(Vector2(StrToFloat(Parts[1]), StrToFloat(Parts[2])))
          else
            TexList.Add(TVector2.Zero);
        end
        else if Token = 'vn' then
        begin
          if Length(Parts) >= 4 then
            NormList.Add(Vector3(StrToFloat(Parts[1]), StrToFloat(Parts[2]), StrToFloat(Parts[3])))
          else
            NormList.Add(TVector3.Zero);
        end
        else if Token = 'f' then
        begin
          Poly.Clear;
          for i := 1 to High(Parts) do
          begin
            FaceVert := ParseFaceVertex(Parts[i]);
            Poly.Add(FaceVert);
          end;
          for j := 1 to Poly.Count - 2 do
          begin
            tri[0] := Poly[0];
            tri[1] := Poly[j];
            tri[2] := Poly[j+1];
            Triangles.Add(tri);
          end;
        end;
      end;
    finally
      Reader.Free;
    end;

    if Triangles.Count = 0 then
      raise Exception.Create('No geometry found in OBJ file: ' + AFileName);

    VertexList := TList<TVertex>.Create;
    try
      for tri in Triangles do
      begin
        p0 := PosList[tri[0].PosIdx];
        p1 := PosList[tri[1].PosIdx];
        p2 := PosList[tri[2].PosIdx];
        faceNormal := (p1 - p0).Cross(p2 - p0).Normalize;

        hasTex := (tri[0].TexIdx >= 0) and (tri[0].TexIdx < TexList.Count) and
                  (tri[1].TexIdx >= 0) and (tri[1].TexIdx < TexList.Count) and
                  (tri[2].TexIdx >= 0) and (tri[2].TexIdx < TexList.Count);
        if hasTex then
        begin
          uv0 := TexList[tri[0].TexIdx];
          uv1 := TexList[tri[1].TexIdx];
          uv2 := TexList[tri[2].TexIdx];
        end
        else
          GenerateUVsForTriangle(p0, p1, p2, faceNormal, uv0, uv1, uv2);

        hasNorm := (tri[0].NormIdx >= 0) and (tri[0].NormIdx < NormList.Count) and
                   (tri[1].NormIdx >= 0) and (tri[1].NormIdx < NormList.Count) and
                   (tri[2].NormIdx >= 0) and (tri[2].NormIdx < NormList.Count);

        for i := 0 to 2 do
        begin
          vtx.Position := PosList[tri[i].PosIdx];
          if hasNorm then
            vtx.Normal := NormList[tri[i].NormIdx]
          else
            vtx.Normal := faceNormal;

          case i of
            0: vtx.TexCoord := uv0;
            1: vtx.TexCoord := uv1;
            2: vtx.TexCoord := uv2;
          end;

          vtx.Tangent   := TVector3.Zero;
          vtx.Bitangent := TVector3.Zero;
          VertexList.Add(vtx);
        end;
      end;

      SetLength(Vertices, VertexList.Count);
      for idx := 0 to VertexList.Count - 1 do
        Vertices[idx] := VertexList[idx];

      SetLength(Indices, VertexList.Count);
      for idx := 0 to VertexList.Count - 1 do
        Indices[idx] := idx;
    finally
      VertexList.Free;
    end;
  finally
    PosList.Free;
    TexList.Free;
    NormList.Free;
    Triangles.Free;
    Poly.Free;
  end;
end;

// ----------------------------------------------------------------------------
// Multi-mesh version: splits geometry by "o" (object) or "g" (group)
// ----------------------------------------------------------------------------
{procedure LoadObjFileV2(const AFileName: string;
  out VerticesArr: TArray<TArray<TVertex>>; out IndicesArr: TArray<TArray<GLuint>>);
var
  PosList: TVector3List;
  TexList: TVector2List;
  NormList: TVector3List;
  Meshes: TObjMeshDataList;
  CurrentMesh: TObjMeshData;
  Reader: TStreamReader;
  Line, Token: string;
  Parts: TArray<string>;
  i, j, k: Integer;
  Poly: TList<TVertexIndex>;
  FaceVert: TVertexIndex;
  tri: TTriangle;
  p0, p1, p2: TVector3;
  hasTex, hasNorm: Boolean;
  uv0, uv1, uv2: TVector2;
  faceNormal: TVector3;
  VertexList: TList<TVertex>;
  vtx: TVertex;
  idx: Integer;
begin
  VerticesArr := nil;
  IndicesArr := nil;
  if not FileExists(AFileName) then
    raise Exception.Create('OBJ file not found: ' + AFileName);

  PosList := TVector3List.Create;
  TexList := TVector2List.Create;
  NormList := TVector3List.Create;
  Meshes := TObjMeshDataList.Create;
  Poly := TList<TVertexIndex>.Create;
  try
    // Initialise first mesh (unnamed)
    CurrentMesh.Name := '';
    CurrentMesh.Triangles := TTriangleList.Create;
    Meshes.Add(CurrentMesh);

    Reader := TStreamReader.Create(AFileName, TEncoding.UTF8);
    try
      while not Reader.EndOfStream do
      begin
        Line := Trim(Reader.ReadLine);
        if (Line = '') or (Line.StartsWith('#')) then Continue;
        Parts := Line.Split([' ', #9], TStringSplitOptions.ExcludeEmpty);
        if Length(Parts) = 0 then Continue;
        Token := LowerCase(Parts[0]);

        if Token = 'v' then
        begin
          if Length(Parts) >= 4 then
            PosList.Add(Vector3(StrToFloat(Parts[1]), StrToFloat(Parts[2]), StrToFloat(Parts[3])))
          else
            PosList.Add(TVector3.Zero);
        end
        else if Token = 'vt' then
        begin
          if Length(Parts) >= 3 then
            TexList.Add(Vector2(StrToFloat(Parts[1]), StrToFloat(Parts[2])))
          else
            TexList.Add(TVector2.Zero);
        end
        else if Token = 'vn' then
        begin
          if Length(Parts) >= 4 then
            NormList.Add(Vector3(StrToFloat(Parts[1]), StrToFloat(Parts[2]), StrToFloat(Parts[3])))
          else
            NormList.Add(TVector3.Zero);
        end
        else if (Token = 'o') or (Token = 'g') then
        begin
          // Start a new mesh. "o" (object) has priority, otherwise "g" (group)
          if Length(Parts) > 1 then
          begin
            CurrentMesh.Name := Parts[1];
          end
          else
          begin
            CurrentMesh.Name := '';
          end;
          CurrentMesh.Triangles := TTriangleList.Create;
          Meshes.Add(CurrentMesh);
        end
        else if Token = 'f' then
        begin
          // Add face to the current mesh (the last one in the list)
          if Meshes.Count = 0 then
          begin
            CurrentMesh.Name := '';
            CurrentMesh.Triangles := TTriangleList.Create;
            Meshes.Add(CurrentMesh);
          end;
          Poly.Clear;
          for i := 1 to High(Parts) do
          begin
            FaceVert := ParseFaceVertex(Parts[i]);
            Poly.Add(FaceVert);
          end;
          // Triangulate polygon
          for j := 1 to Poly.Count - 2 do
          begin
            tri[0] := Poly[0];
            tri[1] := Poly[j];
            tri[2] := Poly[j+1];
            Meshes.Last.Triangles.Add(tri);
          end;
        end;
      end;
    finally
      Reader.Free;
    end;

    // Remove any empty mesh (no triangles) at the end
    while (Meshes.Count > 0) and (Meshes.Last.Triangles.Count = 0) do
    begin
      Meshes.Last.Triangles.Free;
      Meshes.Delete(Meshes.Count - 1);
    end;

    // Build final arrays
    SetLength(VerticesArr, Meshes.Count);
    SetLength(IndicesArr, Meshes.Count);

    for i := 0 to Meshes.Count - 1 do
    begin
      VertexList := TList<TVertex>.Create;
      try
        for tri in Meshes[i].Triangles do
        begin
          p0 := PosList[tri[0].PosIdx];
          p1 := PosList[tri[1].PosIdx];
          p2 := PosList[tri[2].PosIdx];
          faceNormal := (p1 - p0).Cross(p2 - p0).Normalize;

          hasTex := (tri[0].TexIdx >= 0) and (tri[0].TexIdx < TexList.Count) and
                    (tri[1].TexIdx >= 0) and (tri[1].TexIdx < TexList.Count) and
                    (tri[2].TexIdx >= 0) and (tri[2].TexIdx < TexList.Count);
          if hasTex then
          begin
            uv0 := TexList[tri[0].TexIdx];
            uv1 := TexList[tri[1].TexIdx];
            uv2 := TexList[tri[2].TexIdx];
          end
          else
            GenerateUVsForTriangle(p0, p1, p2, faceNormal, uv0, uv1, uv2);

          hasNorm := (tri[0].NormIdx >= 0) and (tri[0].NormIdx < NormList.Count) and
                     (tri[1].NormIdx >= 0) and (tri[1].NormIdx < NormList.Count) and
                     (tri[2].NormIdx >= 0) and (tri[2].NormIdx < NormList.Count);

          for k := 0 to 2 do
          begin
            vtx.Position := PosList[tri[k].PosIdx];
            if hasNorm then
              vtx.Normal := NormList[tri[k].NormIdx]
            else
              vtx.Normal := faceNormal;

            case k of
              0: vtx.TexCoord := uv0;
              1: vtx.TexCoord := uv1;
              2: vtx.TexCoord := uv2;
            end;

            vtx.Tangent   := TVector3.Zero;
            vtx.Bitangent := TVector3.Zero;
            VertexList.Add(vtx);
          end;
        end;

        SetLength(VerticesArr[i], VertexList.Count);
        for idx := 0 to VertexList.Count - 1 do
          VerticesArr[i][idx] := VertexList[idx];

        SetLength(IndicesArr[i], VertexList.Count);
        for idx := 0 to VertexList.Count - 1 do
          IndicesArr[i][idx] := idx;
      finally
        VertexList.Free;
      end;
    end;
  finally
    PosList.Free;
    TexList.Free;
    NormList.Free;
    for i := 0 to Meshes.Count - 1 do
      Meshes[i].Triangles.Free;
    Meshes.Free;
    Poly.Free;
  end;
end;}

procedure LoadObjFileV2(const AFileName: string;
  out VerticesArr: TArray<TArray<TVertex>>; out IndicesArr: TArray<TArray<GLuint>>);
var
  MaterialNames: TArray<string>;
begin
  LoadObjFileV2(AFileName, VerticesArr, IndicesArr, MaterialNames);
end;

procedure LoadObjFileV2(const AFileName: string;
  out VerticesArr: TArray<TArray<TVertex>>; out IndicesArr: TArray<TArray<GLuint>>;
  out MaterialNames: TArray<string>);
var
  PosList: TVector3List;
  TexList: TVector2List;
  NormList: TVector3List;
  Meshes: TObjMeshDataList;
  CurrentMesh: TObjMeshData;
  Reader: TStreamReader;
  Line, Token: string;
  Parts: TArray<string>;
  i, j, k: Integer;
  Poly: TList<TVertexIndex>;
  FaceVert: TVertexIndex;
  tri: TTriangle;
  p0, p1, p2: TVector3;
  hasTex, hasNorm: Boolean;
  uv0, uv1, uv2: TVector2;
  faceNormal: TVector3;
  VertexList: TList<TVertex>;
  vtx: TVertex;
  idx: Integer;

  CurrentObjectName: string;
  CurrentMaterialName: string;

  procedure StartCurrentMesh;
  begin
    CurrentMesh.Name := CurrentObjectName;
    CurrentMesh.MaterialName := CurrentMaterialName;
    CurrentMesh.Triangles := TTriangleList.Create;
    Meshes.Add(CurrentMesh);
  end;

  procedure EnsureCurrentMeshForFace;
  var
    LastMesh: TObjMeshData;
  begin
    if Meshes.Count = 0 then
    begin
      StartCurrentMesh;
      Exit;
    end;

    LastMesh := Meshes[Meshes.Count - 1];
    if LastMesh.Triangles.Count = 0 then
    begin
      LastMesh.Name := CurrentObjectName;
      LastMesh.MaterialName := CurrentMaterialName;
      Meshes[Meshes.Count - 1] := LastMesh;
      Exit;
    end;

    if (LastMesh.Name <> CurrentObjectName) or
       (LastMesh.MaterialName <> CurrentMaterialName) then
      StartCurrentMesh;
  end;
begin
  VerticesArr := nil;
  IndicesArr := nil;
  MaterialNames := nil;
  if not FileExists(AFileName) then
    raise Exception.Create('OBJ file not found: ' + AFileName);

  PosList := TVector3List.Create;
  TexList := TVector2List.Create;
  NormList := TVector3List.Create;
  Meshes := TObjMeshDataList.Create;
  Poly := TList<TVertexIndex>.Create;
  try
    CurrentObjectName := '';
    CurrentMaterialName := '';

    Reader := TStreamReader.Create(AFileName, TEncoding.UTF8);
    try
      while not Reader.EndOfStream do
      begin
        Line := Trim(Reader.ReadLine);
        if (Line = '') or (Line.StartsWith('#')) then Continue;
        Parts := Line.Split([' ', #9], TStringSplitOptions.ExcludeEmpty);
        if Length(Parts) = 0 then Continue;
        Token := LowerCase(Parts[0]);

        if Token = 'v' then
        begin
          if Length(Parts) >= 4 then
            PosList.Add(Vector3(StrToFloat(Parts[1]), StrToFloat(Parts[2]), StrToFloat(Parts[3])))
          else
            PosList.Add(TVector3.Zero);
        end
        else if Token = 'vt' then
        begin
          if Length(Parts) >= 3 then
            TexList.Add(Vector2(StrToFloat(Parts[1]), StrToFloat(Parts[2])))
          else
            TexList.Add(TVector2.Zero);
        end
        else if Token = 'vn' then
        begin
          if Length(Parts) >= 4 then
            NormList.Add(Vector3(StrToFloat(Parts[1]), StrToFloat(Parts[2]), StrToFloat(Parts[3])))
          else
            NormList.Add(TVector3.Zero);
        end
        else if Token = 'o' then
        begin
          CurrentObjectName := '';
          if Length(Parts) > 1 then
            CurrentObjectName := Parts[1];
        end
        else if Token = 'g' then
        begin
          // Groups do NOT create new meshes � they are ignored for splitting
          // (you may optionally store group names per mesh if needed)
          Continue;
        end
        else if Token = 'usemtl' then
        begin
          CurrentMaterialName := Trim(Copy(Line, Length(Parts[0]) + 1, MaxInt));
        end
        else if Token = 'f' then
        begin
          EnsureCurrentMeshForFace;

          Poly.Clear;
          for i := 1 to High(Parts) do
          begin
            FaceVert := ParseFaceVertex(Parts[i]);
            Poly.Add(FaceVert);
          end;
          // Triangulate polygon
          for j := 1 to Poly.Count - 2 do
          begin
            tri[0] := Poly[0];
            tri[1] := Poly[j];
            tri[2] := Poly[j+1];
            Meshes.Last.Triangles.Add(tri);
          end;
        end;
      end;
    finally
      Reader.Free;
    end;

    // Remove any empty mesh (no triangles) at the end
    while (Meshes.Count > 0) and (Meshes.Last.Triangles.Count = 0) do
    begin
      Meshes.Last.Triangles.Free;
      Meshes.Delete(Meshes.Count - 1);
    end;

    // Build final arrays
    SetLength(VerticesArr, Meshes.Count);
    SetLength(IndicesArr, Meshes.Count);
    SetLength(MaterialNames, Meshes.Count);

    for i := 0 to Meshes.Count - 1 do
    begin
      MaterialNames[i] := Meshes[i].MaterialName;
      VertexList := TList<TVertex>.Create;
      try
        for tri in Meshes[i].Triangles do
        begin
          p0 := PosList[tri[0].PosIdx];
          p1 := PosList[tri[1].PosIdx];
          p2 := PosList[tri[2].PosIdx];
          faceNormal := (p1 - p0).Cross(p2 - p0).Normalize;

          hasTex := (tri[0].TexIdx >= 0) and (tri[0].TexIdx < TexList.Count) and
                    (tri[1].TexIdx >= 0) and (tri[1].TexIdx < TexList.Count) and
                    (tri[2].TexIdx >= 0) and (tri[2].TexIdx < TexList.Count);
          if hasTex then
          begin
            uv0 := TexList[tri[0].TexIdx];
            uv1 := TexList[tri[1].TexIdx];
            uv2 := TexList[tri[2].TexIdx];
          end
          else
            GenerateUVsForTriangle(p0, p1, p2, faceNormal, uv0, uv1, uv2);

          hasNorm := (tri[0].NormIdx >= 0) and (tri[0].NormIdx < NormList.Count) and
                     (tri[1].NormIdx >= 0) and (tri[1].NormIdx < NormList.Count) and
                     (tri[2].NormIdx >= 0) and (tri[2].NormIdx < NormList.Count);

          for k := 0 to 2 do
          begin
            vtx.Position := PosList[tri[k].PosIdx];
            if hasNorm then
              vtx.Normal := NormList[tri[k].NormIdx]
            else
              vtx.Normal := faceNormal;

            case k of
              0: vtx.TexCoord := uv0;
              1: vtx.TexCoord := uv1;
              2: vtx.TexCoord := uv2;
            end;

            vtx.Tangent   := TVector3.Zero;
            vtx.Bitangent := TVector3.Zero;
            VertexList.Add(vtx);
          end;
        end;

        SetLength(VerticesArr[i], VertexList.Count);
        for idx := 0 to VertexList.Count - 1 do
          VerticesArr[i][idx] := VertexList[idx];

        SetLength(IndicesArr[i], VertexList.Count);
        for idx := 0 to VertexList.Count - 1 do
          IndicesArr[i][idx] := idx;
      finally
        VertexList.Free;
      end;
    end;
  finally
    PosList.Free;
    TexList.Free;
    NormList.Free;
    for i := 0 to Meshes.Count - 1 do
      Meshes[i].Triangles.Free;
    Meshes.Free;
    Poly.Free;
  end;
end;

end.
