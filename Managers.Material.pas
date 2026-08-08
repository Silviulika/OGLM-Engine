unit Managers.Material;

interface

uses
  System.Generics.Collections, System.Classes, System.SysUtils, Neslib.FastMath,
  dglOpenGL, Renderer.Camera, Renderer.Light, Renderer.Shader, Engine.Types,
  Engine.Paths;

type
  TMaterialShaderParameters = record
    Gamma: Single;
    Layers: Integer;
    Pivot: Single;
    MetallicMult: Single;
    SpecularLevel: Single;
    HeightScale: Single;
    AmbientShadowStrength: Single;
    HdrExposure: Single;
    AlphaCutoff: Single;

    class function DefaultPBR: TMaterialShaderParameters; static;
    class function DefaultActor: TMaterialShaderParameters; static;
    class function DefaultTreeLeaf: TMaterialShaderParameters; static;
    class function DefaultTreeTrunk: TMaterialShaderParameters; static;
    class function DefaultGrass: TMaterialShaderParameters; static;
  end;

  TMaterial = class;
  TMaterials = TArray<TMaterial>;
  // Append new values so material files keep their existing ordinal mapping.
  TMaterialType = (mtPBR, mtShadow, mtHeightFieldMaterial, mtActor,
    mtTreeLeaf, mtTreeTrunk, mtGrass);

  TMaterial = class
  private
    fTextures: TArray<TMaterialTexture>;
    fShader: TShader;
    fMaterialType: TMaterialType;
    fShaderParameters: TMaterialShaderParameters;
    fName: String;

    fMaterialID: Integer;

    function CreateTexture: Integer;

    function GetTexture(aIndex: Integer): TMaterialTexture;
    procedure SetTexture(aIndex: Integer; aTexture: TMaterialTexture);

    function GetCount: Integer;
  public
    constructor Create(aMaterialType: TMaterialType);
    destructor Destroy; override;

    function AddTexture(aTexture: TMaterialTexture): Integer;
    procedure AddTextures(Textures: TArray<TMaterialTexture>);
    function IndexOf(aTextureName: String): Integer;       overload;
    function IndexOf(aTexture: TMaterialTexture): Integer; overload;
    function IndexOfPath(const aPath: string): Integer;
    function IndicesOfPath(const aPath: string): TArray<Integer>;
    function GetTextureArray: TArray<TMaterialTexture>;

    procedure ExchangeTextures(aIndex1, aIndex2: Integer);
    procedure DeleteTexture(aIndex: Integer);
    procedure SaveToStream(Stream: TStream);
    class function LoadFromStream(Stream: TStream; AShader: TShader): TMaterial;
    procedure SaveToFile(const AFileName: string);
    class function LoadFromFile(const AFileName: string; AShader: TShader): TMaterial;
    class function TryReadNameFromFile(const AFileName: string;
      out AMaterialName: string): Boolean; static;

    property TextureList[Index: Integer]: TMaterialTexture read GetTexture write SetTexture;
    property Count: Integer read GetCount;
    property Name: String read fName write fName;
    property Shader: TShader read fShader write fShader;
    property ShaderParameters: TMaterialShaderParameters read fShaderParameters write fShaderParameters;

    property Materialtype: TMaterialType read fMaterialType write fMaterialType;
    property MaterialID: Integer read fMaterialID;
  end;

  TMaterialLibrary = class
  private
    fMaterialList: TMaterials;

    fName: String;

    function GetMat(aIndex: Integer): TMaterial;
    procedure SetMat(aIndex: Integer; aMaterial: TMaterial);

    function GetCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    function CreateMaterial(aMaterialType: TMaterialType): Integer;
    function AddMaterial(aMaterial: TMaterial): Integer;
    function ExtractMaterial(aIndex: Integer): TMaterial;
    procedure DeleteMaterial(aIndex: Integer);

    function GetMaterial(aName: String): TMaterial; overload;
    function GetMaterial(aIndex: Integer): TMaterial; overload;

    procedure ExchangeMaterials(aIndex1, aIndex2: Integer);
    procedure SaveToStream(Stream: TStream; const ExcludeMaterialName: string = '');
    procedure LoadFromStream(Stream: TStream; AShader: TShader);
    procedure SaveToFile(const AFileName: string);
    procedure LoadFromFile(const AFileName: string; AShader: TShader);
    class function TryReadMaterialNamesFromFile(const AFileName: string;
      out AMaterialNames: TArray<string>): Boolean; static;
    class function TryLoadMaterialFromFileByName(const AFileName,
      AMaterialName: string; AShader: TShader; out AMaterial: TMaterial): Boolean; static;

    property Material[intex: Integer]: TMaterial read GetMat write SetMat;
    property Count: Integer read GetCount;
    property Name: String read fname write fName;
  end;

  TMaterialLibraries = class(TObjectList<TMaterialLibrary>)
  private
    function GetLib(aIndex: Integer): TMaterialLibrary;
    procedure SetLib(aIndex: Integer; aMaterialLibrary: TMaterialLibrary);
  public
    constructor Create(aOwnsObjects: Boolean = True);

    function CreateMaterialLibrary(const aName: String = ''): Integer;
    function AddMaterialLibrary(aMaterialLibrary: TMaterialLibrary): Integer;

    function IndexOf(aMaterialLibrary: TMaterialLibrary): Integer; reintroduce; overload;
    function IndexOf(const aName: String): Integer; reintroduce; overload;

    function GetMaterialLibrary(const aName: String): TMaterialLibrary; overload;
    function GetMaterialLibrary(aIndex: Integer): TMaterialLibrary; overload;
    procedure SaveToStream(Stream: TStream; const ExcludeMaterialName: string = '');
    procedure LoadFromStream(Stream: TStream; AShader: TShader);

    property MaterialLibrary[Index: Integer]: TMaterialLibrary read GetLib write SetLib; default;
  end;

implementation

const
  MATERIAL_FILE_VERSION = 4;
  MAX_SERIALIZED_STRING_CHARS = 1048576;
  MAX_MATERIAL_TEXTURES = 4096;
  MAX_MATERIALS_PER_LIBRARY = 65536;
  MAX_MATERIAL_LIBRARIES = 4096;
  MATERIAL_FILE_MAGIC: array[0..7] of AnsiChar = ('O', 'M', 'E', 'M', 'A', 'T', '0', '1');
  MATERIAL_LIBRARY_CHUNK_MAGIC: array[0..7] of AnsiChar = ('O', 'M', 'E', 'M', 'L', 'B', '0', '1');

type
  TMaterialTextureCacheEntry = class
  public
    TextureID: GLuint;
    RefCount: Integer;
    destructor Destroy; override;
  end;

var
  GMaterialTextureCache: TObjectDictionary<string, TMaterialTextureCacheEntry> = nil;

function MaterialTextureCache: TObjectDictionary<string, TMaterialTextureCacheEntry>;
begin
  if GMaterialTextureCache = nil then
    GMaterialTextureCache := TObjectDictionary<string, TMaterialTextureCacheEntry>.Create([doOwnsValues]);
  Result := GMaterialTextureCache;
end;

destructor TMaterialTextureCacheEntry.Destroy;
begin
  if TextureID <> 0 then
  begin
    glDeleteTextures(1, @TextureID);
    TextureID := 0;
  end;

  inherited Destroy;
end;

function BuildMaterialTextureCacheKey(const AFileName: string; MipMap: Boolean;
  InternalFormat, Param: GLint; InvertNormals: Boolean): string;
var
  SearchRec: TSearchRec;
begin
  Result := LowerCase(ExpandFileName(AFileName));
  if FindFirst(AFileName, faAnyFile, SearchRec) = 0 then
  try
    Result := Result + '|' + IntToStr(SearchRec.Size) + '|' +
      FloatToStr(SearchRec.TimeStamp);
  finally
    FindClose(SearchRec);
  end;

  Result := Result + '|' + IntToStr(InternalFormat) + '|' +
    IntToStr(Param) + '|' + BoolToStr(MipMap, True) + '|' +
    BoolToStr(InvertNormals, True);
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
    raise Exception.Create('Invalid string length in material stream.');
  ByteCount := Int64(Len) * SizeOf(Char);
  if ByteCount > Stream.Size - Stream.Position then
    raise Exception.Create('Truncated string in material stream.');
  SetLength(Result, Len);
  if Len > 0 then
    Stream.ReadBuffer(Result[1], ByteCount);
end;

function MagicMatches(const Actual, Expected: array of AnsiChar): Boolean;
var
  I: Integer;
begin
  Result := Length(Actual) = Length(Expected);
  if not Result then
    Exit;

  for I := 0 to High(Expected) do
    if Actual[I] <> Expected[I] then
      Exit(False);
end;

procedure SkipStreamBytes(Stream: TStream; ByteCount: Int64);
begin
  if (ByteCount < 0) or (ByteCount > Stream.Size - Stream.Position) then
    raise Exception.Create('Truncated material stream.');

  Stream.Position := Stream.Position + ByteCount;
end;

procedure SkipSerializedShaderParameters(Stream: TStream; Version: Integer);
begin
  SkipStreamBytes(Stream, SizeOf(Single));  // Gamma
  SkipStreamBytes(Stream, SizeOf(Integer)); // Layers
  SkipStreamBytes(Stream, SizeOf(Single));  // Pivot
  SkipStreamBytes(Stream, SizeOf(Single));  // Metallic multiplier
  if Version >= 2 then
    SkipStreamBytes(Stream, SizeOf(Single)); // Specular level
  SkipStreamBytes(Stream, SizeOf(Single));   // Height scale
  SkipStreamBytes(Stream, SizeOf(Single));   // Ambient shadow strength
  if Version >= 3 then
    SkipStreamBytes(Stream, SizeOf(Single)); // HDR exposure
  if Version >= 4 then
    SkipStreamBytes(Stream, SizeOf(Single)); // Alpha cutoff
end;

procedure ReadSerializedMaterialNameAndSkip(Stream: TStream; out AMaterialName: string);
var
  Magic: array[0..7] of AnsiChar;
  Version: Integer;
  TextureCount: Integer;
  MaterialTypeValue: Integer;
  I: Integer;
begin
  Stream.ReadBuffer(Magic[0], SizeOf(Magic));
  if not MagicMatches(Magic, MATERIAL_FILE_MAGIC) then
    raise Exception.Create('Invalid OpenGL Micro Engine material file.');

  Stream.ReadBuffer(Version, SizeOf(Version));
  if (Version < 1) or (Version > MATERIAL_FILE_VERSION) then
    raise Exception.CreateFmt('Unsupported material file version: %d.', [Version]);

  AMaterialName := ReadStringFromStream(Stream);

  Stream.ReadBuffer(MaterialTypeValue, SizeOf(MaterialTypeValue));
  if (MaterialTypeValue < Ord(Low(TMaterialType))) or
     (MaterialTypeValue > Ord(High(TMaterialType))) then
    raise Exception.Create('Invalid material type in material stream.');

  SkipSerializedShaderParameters(Stream, Version);

  Stream.ReadBuffer(TextureCount, SizeOf(TextureCount));
  if (TextureCount < 0) or (TextureCount > MAX_MATERIAL_TEXTURES) then
    raise Exception.Create('Invalid texture count in material stream.');

  for I := 0 to TextureCount - 1 do
  begin
    ReadStringFromStream(Stream); // texture uniform name
    ReadStringFromStream(Stream); // texture asset path
    SkipStreamBytes(Stream, SizeOf(TVector3)); // diffuse color
    SkipStreamBytes(Stream, SizeOf(TVector3)); // specular color
    SkipStreamBytes(Stream, SizeOf(Single));   // shininess
  end;
end;

function EmptyMaterialTexture: TMaterialTexture;
begin
  Result.Texture.DiffuseColor := Vector3(0.0);
  Result.Texture.SpecularColor := Vector3(0.0);
  Result.Texture.Shininess := 0.0;
  Result.Texture.TexID := 0;
  Result.Texture.Name := '';
  Result.Path := '';
  Result.CacheKey := '';
end;

procedure ReleaseMaterialTexture(var MatTex: TMaterialTexture);
var
  Entry: TMaterialTextureCacheEntry;
  TextureID: GLuint;
  ReleasedFromCache: Boolean;
begin
  if MatTex.Texture.TexID <> 0 then
  begin
    ReleasedFromCache := False;
    if (MatTex.CacheKey <> '') and Assigned(GMaterialTextureCache) and
       GMaterialTextureCache.TryGetValue(MatTex.CacheKey, Entry) then
    begin
      Dec(Entry.RefCount);
      if Entry.RefCount <= 0 then
      begin
        TextureID := Entry.TextureID;
        if TextureID <> 0 then
        begin
          glDeleteTextures(1, @TextureID);
          Entry.TextureID := 0;
        end;
        GMaterialTextureCache.Remove(MatTex.CacheKey);
        if GMaterialTextureCache.Count = 0 then
          FreeAndNil(GMaterialTextureCache);
      end;
      ReleasedFromCache := True;
    end;

    if not ReleasedFromCache then
    begin
      TextureID := MatTex.Texture.TexID;
      glDeleteTextures(1, @TextureID);
    end;
  end;

  MatTex.Texture.TexID := 0;
  MatTex.CacheKey := '';
end;

procedure ReleaseMaterialTextures(var Textures: TArray<TMaterialTexture>);
var
  I: Integer;
begin
  for I := 0 to Length(Textures) - 1 do
    ReleaseMaterialTexture(Textures[I]);
end;

procedure GetTextureLoadParams(const AUniformName: string;
  AMaterialType: TMaterialType; out AMipMap: Boolean;
  out AInternalFormat, AParam: GLint; out AInvertNormals: Boolean);
var
  U: string;

  function HasPrefix(const APrefix: string): Boolean;
  begin
    Result := Copy(U, 1, Length(APrefix)) = APrefix;
  end;

  function IsTerrainAlphaTextureName: Boolean;
  begin
    Result :=
      HasPrefix('alphatexture') or
      HasPrefix('alphatextures[') or
      HasPrefix('masktexture') or
      HasPrefix('masktextures[') or
      HasPrefix('blendtexture') or
      HasPrefix('blendtextures[') or
      HasPrefix('blendmap') or
      HasPrefix('blendmaps[') or
      HasPrefix('splatmap') or
      HasPrefix('splatmaps[');
  end;
begin
  U := LowerCase(AUniformName);

  AMipMap := True;
  AInternalFormat := GL_RGBA8;
  AParam := GL_REPEAT;
  AInvertNormals := False;

  if (U = LowerCase('albedoTexture')) or
     ((Copy(U, 1, Length('albedotexture')) = 'albedotexture') and
     (Length(U) > Length('albedotexture'))) or
     (Copy(U, 1, Length('albedotextures[')) = 'albedotextures[') then
    AInternalFormat := GL_SRGB8_ALPHA8
  else if IsTerrainAlphaTextureName then
  begin
    AMipMap := False;
    AParam := GL_CLAMP_TO_EDGE;
  end
  else if U = LowerCase('specularBRDF_LUT') then
  begin
    AMipMap := False;
    AParam := GL_CLAMP_TO_EDGE;
  end;

  if (AMaterialType = mtActor) and
     ((U = LowerCase('albedoTexture')) or
      (U = LowerCase('normalTexture')) or
      (U = LowerCase('heightTexture')) or
      (U = LowerCase('metalnessTexture')) or
      (U = LowerCase('metallicTexture')) or
      (U = LowerCase('roughnessTexture')) or
      (U = LowerCase('specularTexture')) or
      (U = LowerCase('ambientOcclusionTexture'))) then
    AMipMap := False;
end;

procedure ReloadMaterialTexture(var MatTex: TMaterialTexture;
  AMaterialType: TMaterialType);
var
  Ext: string;
  MipMap: Boolean;
  InternalFormat: GLint;
  Param: GLint;
  InvertNormals: Boolean;
  UniformName: string;
  LoadedTex: TMaterialTexture;
  Loaded: Boolean;
  CacheKey: string;
  Cache: TObjectDictionary<string, TMaterialTextureCacheEntry>;
  Entry: TMaterialTextureCacheEntry;
begin
  MatTex.Path := TEnginePaths.ResolveAssetPath(MatTex.Path);

  if (MatTex.Path = '') or (not FileExists(MatTex.Path)) then
    Exit;

  UniformName := Trim(MatTex.Texture.Name);
  GetTextureLoadParams(UniformName, AMaterialType, MipMap, InternalFormat,
    Param, InvertNormals);

  Ext := LowerCase(ExtractFileExt(MatTex.Path));
  CacheKey := BuildMaterialTextureCacheKey(MatTex.Path, MipMap, InternalFormat,
    Param, InvertNormals);
  Cache := MaterialTextureCache;
  if Cache.TryGetValue(CacheKey, Entry) then
  begin
    LoadedTex := MatTex;
    LoadedTex.Texture.TexID := Entry.TextureID;
    LoadedTex.Texture.Name := UniformName;
    LoadedTex.CacheKey := CacheKey;
    Inc(Entry.RefCount);
    ReleaseMaterialTexture(MatTex);
    MatTex := LoadedTex;
    Exit;
  end;

  LoadedTex := MatTex;
  LoadedTex.Texture.TexID := 0;
  LoadedTex.CacheKey := '';
  try
    if Ext = '.tga' then
      Loaded := LoadedTex.LoadTexTGA(MatTex.Path, MipMap, UniformName,
        InternalFormat, Param, InvertNormals)
    else if Ext = '.png' then
      Loaded := LoadedTex.LoadTexPNG(MatTex.Path, MipMap, UniformName,
        InternalFormat, Param, InvertNormals)
    else if (Ext = '.jpg') or (Ext = '.jpeg') then
      Loaded := LoadedTex.LoadTexJPG(MatTex.Path, MipMap, UniformName,
        InternalFormat, Param, InvertNormals)
    else if Ext = '.dds' then
      Loaded := LoadedTex.LoadTexDDS(MatTex.Path, MipMap, UniformName,
        InternalFormat, Param, InvertNormals)
    else
      Exit;
  except
    ReleaseMaterialTexture(LoadedTex);
    raise;
  end;

  if Loaded then
  begin
    Entry := TMaterialTextureCacheEntry.Create;
    Entry.TextureID := LoadedTex.Texture.TexID;
    Entry.RefCount := 1;
    Cache.Add(CacheKey, Entry);
    LoadedTex.CacheKey := CacheKey;
    ReleaseMaterialTexture(MatTex);
    MatTex := LoadedTex;
  end
  else
    ReleaseMaterialTexture(LoadedTex);
end;

{ TMaterialShaderParameters }

class function TMaterialShaderParameters.DefaultPBR: TMaterialShaderParameters;
begin
  Result.Gamma := 2.4;
  Result.Layers := 48;
  Result.Pivot := 0.5;
  Result.MetallicMult := 0.02;
  Result.SpecularLevel := 1.0;
  Result.HeightScale := 0.015;
  Result.AmbientShadowStrength := 0.45;
  Result.HdrExposure := 2.2;
  Result.AlphaCutoff := 0.45;
end;

class function TMaterialShaderParameters.DefaultActor: TMaterialShaderParameters;
begin
  Result := DefaultPBR;
  Result.Layers := 6;
  // Actor UVs normally address tightly packed glTF atlases. Parallax offsets
  // can cross island boundaries, so actors default to exact TEXCOORD_0 UVs;
  // their normal maps still provide surface detail.
  Result.HeightScale := 0.0;
end;

class function TMaterialShaderParameters.DefaultTreeLeaf: TMaterialShaderParameters;
begin
  Result := DefaultPBR;
  Result.SpecularLevel := 0.55;
  Result.HeightScale := 0.0;
  Result.AlphaCutoff := 0.35;
end;

class function TMaterialShaderParameters.DefaultTreeTrunk: TMaterialShaderParameters;
begin
  Result := DefaultPBR;
  Result.SpecularLevel := 0.45;
  Result.HeightScale := 0.0;
  Result.AmbientShadowStrength := 0.65;
end;

class function TMaterialShaderParameters.DefaultGrass: TMaterialShaderParameters;
begin
  Result := DefaultPBR;
  Result.SpecularLevel := 0.35;
  Result.HeightScale := 0.0;
  Result.AlphaCutoff := 0.42;
  Result.AmbientShadowStrength := 0.55;
end;

{ TMaterial }
function TMaterial.CreateTexture: Integer;
  var
    indx: Integer;
begin
  indx := Length(fTextures);
  SetLength(fTextures, indx +1);

  fTextures[indx] := EmptyMaterialTexture;

  Result := indx;
end;

function TMaterial.GetTexture(aIndex: Integer): TMaterialTexture;
begin
  Result := EmptyMaterialTexture;

  if (aIndex >= 0) and (aIndex <= Length(fTextures) -1) then
    Result := fTextures[aIndex];

end;

procedure TMaterial.SetTexture(aIndex: Integer; aTexture: TMaterialTexture);
begin
  if (aIndex >= 0) and (aIndex <= Length(fTextures) -1) then
  begin
    if fTextures[aIndex].Texture.TexID <> aTexture.Texture.TexID then
      ReleaseMaterialTexture(fTextures[aIndex]);
    fTextures[aIndex] := aTexture;
  end;
end;

function TMaterial.GetCount: Integer;
begin
  Result := Length(fTextures);
end;

constructor TMaterial.Create(aMaterialType: TMaterialType);
begin
  inherited Create;

  SetLength(fTextures, 0);

  fMaterialType := aMaterialType;
  case aMaterialType of
    mtActor:
      fShaderParameters := TMaterialShaderParameters.DefaultActor;
    mtTreeLeaf:
      fShaderParameters := TMaterialShaderParameters.DefaultTreeLeaf;
    mtTreeTrunk:
      fShaderParameters := TMaterialShaderParameters.DefaultTreeTrunk;
    mtGrass:
      fShaderParameters := TMaterialShaderParameters.DefaultGrass;
  else
    fShaderParameters := TMaterialShaderParameters.DefaultPBR;
  end;
  fMaterialID := 0;
end;

destructor TMaterial.Destroy;
begin
  ReleaseMaterialTextures(fTextures);
  SetLength(fTextures, 0);

  inherited Destroy;
end;

function TMaterial.AddTexture(aTexture: TMaterialTexture): Integer;
  var
    indx: Integer;
begin
  indx := Length(fTextures);
  SetLength(fTextures, indx +1);
  fTextures[indx] := aTexture;

  Result := indx;
end;

procedure TMaterial.AddTextures(Textures: TArray<TMaterialTexture>);
  var
    i: integer;
begin
  ReleaseMaterialTextures(fTextures);
  SetLength(fTextures, Length(Textures));

  for i := 0 to Length(Textures) -1 do
    begin
      fTextures[i] := Textures[i];
    end;

end;

function TMaterial.IndexOf(aTextureName: String): Integer;
  var
    i: Integer;
begin
  for i := 0 to Length(fTextures) -1 do
    begin
      if fTextures[i].Texture.Name = aTextureName then
        begin
          Exit(i);
        end;
    end;
  Result := -1;
end;

function TMaterial.IndexOf(aTexture: TMaterialTexture): Integer;
  var
    i: Integer;
begin
  for i := 0 to Length(fTextures) -1 do
    begin
      if fTextures[i].Texture.Name = aTexture.Texture.Name then
        begin
          Exit(i);
        end;
    end;
  Result := -1;
end;

function TMaterial.IndexOfPath(const aPath: string): Integer;
var
  i: Integer;
begin
  for i := 0 to Length(fTextures) - 1 do
  begin
    if SameText(fTextures[i].Path, aPath) then
      Exit(i);
  end;

  Result := -1;
end;

function TMaterial.IndicesOfPath(const aPath: string): TArray<Integer>;
var
  i, n: Integer;
begin
  SetLength(Result, 0);
  n := 0;

  for i := 0 to Length(fTextures) - 1 do
  begin
    if SameText(fTextures[i].Path, aPath) then
    begin
      SetLength(Result, n + 1);
      Result[n] := i;
      Inc(n);
    end;
  end;
end;

function TMaterial.GetTextureArray: TArray<TMaterialTexture>;
begin
  Result := fTextures;
end;

procedure TMaterial.ExchangeTextures(aIndex1, aIndex2: Integer);
var
  Tmp: TMaterialTexture;
begin
  if (aIndex1 < 0) or (aIndex1 >= Length(fTextures)) then
    Exit;

  if (aIndex2 < 0) or (aIndex2 >= Length(fTextures)) then
    Exit;

  if aIndex1 = aIndex2 then
    Exit;

  Tmp := fTextures[aIndex1];
  fTextures[aIndex1] := fTextures[aIndex2];
  fTextures[aIndex2] := Tmp;
end;

procedure TMaterial.DeleteTexture(aIndex: Integer);
var
  I: Integer;
begin
  if (aIndex < 0) or (aIndex >= Length(fTextures)) then
    Exit;

  ReleaseMaterialTexture(fTextures[aIndex]);
  for I := aIndex to Length(fTextures) - 2 do
    fTextures[I] := fTextures[I + 1];
  SetLength(fTextures, Length(fTextures) - 1);
end;

procedure TMaterial.SaveToStream(Stream: TStream);
var
  I, Version, TextureCount, MaterialTypeValue: Integer;
  Tex: TMaterialTexture;

  procedure WriteShaderParameters(const Params: TMaterialShaderParameters);
  begin
    Stream.WriteBuffer(Params.Gamma, SizeOf(Params.Gamma));
    Stream.WriteBuffer(Params.Layers, SizeOf(Params.Layers));
    Stream.WriteBuffer(Params.Pivot, SizeOf(Params.Pivot));
    Stream.WriteBuffer(Params.MetallicMult, SizeOf(Params.MetallicMult));
    Stream.WriteBuffer(Params.SpecularLevel, SizeOf(Params.SpecularLevel));
    Stream.WriteBuffer(Params.HeightScale, SizeOf(Params.HeightScale));
    Stream.WriteBuffer(Params.AmbientShadowStrength, SizeOf(Params.AmbientShadowStrength));
    Stream.WriteBuffer(Params.HdrExposure, SizeOf(Params.HdrExposure));
    Stream.WriteBuffer(Params.AlphaCutoff, SizeOf(Params.AlphaCutoff));
  end;
begin
  Stream.WriteBuffer(MATERIAL_FILE_MAGIC[0], SizeOf(MATERIAL_FILE_MAGIC));
  Version := MATERIAL_FILE_VERSION;
  Stream.WriteBuffer(Version, SizeOf(Version));

  WriteStringToStream(Stream, fName);
  MaterialTypeValue := Ord(fMaterialType);
  Stream.WriteBuffer(MaterialTypeValue, SizeOf(MaterialTypeValue));
  WriteShaderParameters(fShaderParameters);

  TextureCount := Length(fTextures);
  Stream.WriteBuffer(TextureCount, SizeOf(TextureCount));
  for I := 0 to TextureCount - 1 do
  begin
    Tex := fTextures[I];
    WriteStringToStream(Stream, Tex.Texture.Name);
    WriteStringToStream(Stream, TEnginePaths.ToAssetRelativePath(Tex.Path));
    Stream.WriteBuffer(Tex.Texture.DiffuseColor, SizeOf(Tex.Texture.DiffuseColor));
    Stream.WriteBuffer(Tex.Texture.SpecularColor, SizeOf(Tex.Texture.SpecularColor));
    Stream.WriteBuffer(Tex.Texture.Shininess, SizeOf(Tex.Texture.Shininess));
  end;
end;

class function TMaterial.LoadFromStream(Stream: TStream; AShader: TShader): TMaterial;
var
  Magic: array[0..7] of AnsiChar;
  Version, I, TextureCount, MaterialTypeValue: Integer;
  Tex: TMaterialTexture;

  procedure ReadShaderParameters(var Params: TMaterialShaderParameters);
  begin
    Params := TMaterialShaderParameters.DefaultPBR;
    Stream.ReadBuffer(Params.Gamma, SizeOf(Params.Gamma));
    Stream.ReadBuffer(Params.Layers, SizeOf(Params.Layers));
    Stream.ReadBuffer(Params.Pivot, SizeOf(Params.Pivot));
    Stream.ReadBuffer(Params.MetallicMult, SizeOf(Params.MetallicMult));
    if Version >= 2 then
      Stream.ReadBuffer(Params.SpecularLevel, SizeOf(Params.SpecularLevel))
    else
      Params.SpecularLevel := 1.0;
    Stream.ReadBuffer(Params.HeightScale, SizeOf(Params.HeightScale));
    Stream.ReadBuffer(Params.AmbientShadowStrength, SizeOf(Params.AmbientShadowStrength));
    if Version >= 3 then
      Stream.ReadBuffer(Params.HdrExposure, SizeOf(Params.HdrExposure))
    else
      Params.HdrExposure := 2.2;
    if Version >= 4 then
      Stream.ReadBuffer(Params.AlphaCutoff, SizeOf(Params.AlphaCutoff))
    else
      Params.AlphaCutoff := 0.45;
  end;
begin
  Stream.ReadBuffer(Magic[0], SizeOf(Magic));
  if not MagicMatches(Magic, MATERIAL_FILE_MAGIC) then
    raise Exception.Create('Invalid OpenGL Micro Engine material file.');

  Stream.ReadBuffer(Version, SizeOf(Version));
  if (Version < 1) or (Version > MATERIAL_FILE_VERSION) then
    raise Exception.CreateFmt('Unsupported material file version: %d.', [Version]);

  Result := TMaterial.Create(mtPBR);
  try
    Result.fName := ReadStringFromStream(Stream);
    Stream.ReadBuffer(MaterialTypeValue, SizeOf(MaterialTypeValue));
    if (MaterialTypeValue < Ord(Low(TMaterialType))) or
       (MaterialTypeValue > Ord(High(TMaterialType))) then
      raise Exception.Create('Invalid material type in material stream.');

    Result.fMaterialType := TMaterialType(MaterialTypeValue);
    ReadShaderParameters(Result.fShaderParameters);
    Result.fShader := AShader;

    Stream.ReadBuffer(TextureCount, SizeOf(TextureCount));
    if (TextureCount < 0) or (TextureCount > MAX_MATERIAL_TEXTURES) then
      raise Exception.Create('Invalid texture count in material stream.');

    SetLength(Result.fTextures, TextureCount);
    for I := 0 to TextureCount - 1 do
    begin
      Tex.Texture.Name := ReadStringFromStream(Stream);
      Tex.Path := TEnginePaths.ResolveAssetPath(ReadStringFromStream(Stream));

      Stream.ReadBuffer(Tex.Texture.DiffuseColor, SizeOf(Tex.Texture.DiffuseColor));
      Stream.ReadBuffer(Tex.Texture.SpecularColor, SizeOf(Tex.Texture.SpecularColor));
      Stream.ReadBuffer(Tex.Texture.Shininess, SizeOf(Tex.Texture.Shininess));

      Tex.Texture.TexID := 0;
      ReloadMaterialTexture(Tex, Result.fMaterialType);
      Result.fTextures[I] := Tex;
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure TMaterial.SaveToFile(const AFileName: string);
var
  Stream: TFileStream;
begin
  ForceDirectories(ExtractFilePath(AFileName));
  Stream := TFileStream.Create(AFileName, fmCreate);
  try
    SaveToStream(Stream);
  finally
    Stream.Free;
  end;
end;

class function TMaterial.LoadFromFile(const AFileName: string; AShader: TShader): TMaterial;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := LoadFromStream(Stream, AShader);
  finally
    Stream.Free;
  end;
end;

class function TMaterial.TryReadNameFromFile(const AFileName: string;
  out AMaterialName: string): Boolean;
var
  Stream: TFileStream;
begin
  Result := False;
  AMaterialName := '';

  if not FileExists(AFileName) then
    Exit;

  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    try
      ReadSerializedMaterialNameAndSkip(Stream, AMaterialName);
      Result := True;
    except
      AMaterialName := '';
      Result := False;
    end;
  finally
    Stream.Free;
  end;
end;

{ TMaterialLibrary }
function TMaterialLibrary.GetMat(aIndex: Integer): TMaterial;
begin
  Result := nil;

  if (aIndex >= 0) and (aIndex <= Length(fMaterialList) -1) then
    Result := fMaterialList[aIndex];
end;

procedure TMaterialLibrary.SetMat(aIndex: Integer; aMaterial: TMaterial);
begin
  if (aIndex >= 0) and (aIndex <= Length(fMaterialList) -1) then
  begin
    if fMaterialList[aIndex] = aMaterial then
      Exit;

    fMaterialList[aIndex].Free;
    fMaterialList[aIndex] := aMaterial;
    if Assigned(aMaterial) then
      aMaterial.fMaterialID := aIndex;
  end;
end;

function TMaterialLibrary.GetCount: Integer;
begin
  Result := Length(fMaterialList);
end;

constructor TMaterialLibrary.Create;
begin
  inherited Create;

  SetLength(fMaterialList, 0);
end;

destructor TMaterialLibrary.Destroy;
  var
    i: Integer;
begin
  for i := 0 to Length(fMaterialList) -1 do
    begin
      fMaterialList[i].Free;
    end;

  SetLength(fMaterialList, 0);

  inherited Destroy;
end;

function TMaterialLibrary.CreateMaterial(aMaterialType: TMaterialType): Integer;
  var
    indx: Integer;
begin
  indx := Length(fMaterialList);
  SetLength(fMaterialList, indx +1);
  fMaterialList[indx] := TMaterial.Create(aMaterialType);
  fMaterialList[indx].fMaterialID := indx;

  Result := indx;
end;

function TMaterialLibrary.AddMaterial(aMaterial: TMaterial): Integer;
  var
    indx: Integer;
begin
  indx := Length(fMaterialList);
  SetLength(fMaterialList, indx +1);
  fMaterialList[indx] := aMaterial;
  fMaterialList[indx].fMaterialID := indx;

  Result := indx;
end;

function TMaterialLibrary.ExtractMaterial(aIndex: Integer): TMaterial;
var
  I: Integer;
begin
  Result := nil;
  if (aIndex < 0) or (aIndex >= Length(fMaterialList)) then
    Exit;

  Result := fMaterialList[aIndex];
  for I := aIndex to Length(fMaterialList) - 2 do
  begin
    fMaterialList[I] := fMaterialList[I + 1];
    if Assigned(fMaterialList[I]) then
      fMaterialList[I].fMaterialID := I;
  end;
  SetLength(fMaterialList, Length(fMaterialList) - 1);
end;

procedure TMaterialLibrary.DeleteMaterial(aIndex: Integer);
var
  I: Integer;
begin
  if (aIndex < 0) or (aIndex >= Length(fMaterialList)) then
    Exit;

  fMaterialList[aIndex].Free;
  for I := aIndex to Length(fMaterialList) - 2 do
  begin
    fMaterialList[I] := fMaterialList[I + 1];
    if Assigned(fMaterialList[I]) then
      fMaterialList[I].fMaterialID := I;
  end;
  SetLength(fMaterialList, Length(fMaterialList) - 1);
end;

function TMaterialLibrary.GetMaterial(aName: String): TMaterial;
  var
    i: Integer;
begin
  for i := 0 to Length(fMaterialList) -1 do
    begin
      if fMaterialList[i].Name = aName then
        begin
          Result := fMaterialList[i];
          Exit;
        end;
    end;

  Result := nil;
end;

function TMaterialLibrary.GetMaterial(aIndex: Integer): TMaterial;
begin
  Result := GetMat(aIndex);
end;

procedure TMaterialLibrary.ExchangeMaterials(aIndex1, aIndex2: Integer);
var
  Tmp: TMaterial;
begin
  if (aIndex1 < 0) or (aIndex1 >= Length(fMaterialList)) then
    Exit;

  if (aIndex2 < 0) or (aIndex2 >= Length(fMaterialList)) then
    Exit;

  if aIndex1 = aIndex2 then
    Exit;

  Tmp := fMaterialList[aIndex1];
  fMaterialList[aIndex1] := fMaterialList[aIndex2];
  fMaterialList[aIndex2] := Tmp;

  // Keep MaterialID matching the current position
  if Assigned(fMaterialList[aIndex1]) then
    fMaterialList[aIndex1].fMaterialID := aIndex1;

  if Assigned(fMaterialList[aIndex2]) then
    fMaterialList[aIndex2].fMaterialID := aIndex2;
end;

procedure TMaterialLibrary.SaveToStream(Stream: TStream; const ExcludeMaterialName: string);
var
  I, CountValue: Integer;
begin
  WriteStringToStream(Stream, fName);
  CountValue := 0;
  for I := 0 to Length(fMaterialList) - 1 do
    if Assigned(fMaterialList[I]) and
       ((ExcludeMaterialName = '') or (not SameText(fMaterialList[I].Name, ExcludeMaterialName))) then
      Inc(CountValue);

  Stream.WriteBuffer(CountValue, SizeOf(CountValue));
  for I := 0 to Length(fMaterialList) - 1 do
    if Assigned(fMaterialList[I]) and
       ((ExcludeMaterialName = '') or (not SameText(fMaterialList[I].Name, ExcludeMaterialName))) then
      fMaterialList[I].SaveToStream(Stream);
end;

procedure TMaterialLibrary.LoadFromStream(Stream: TStream; AShader: TShader);
var
  I, CountValue: Integer;
  Mat: TMaterial;
begin
  for I := 0 to Length(fMaterialList) - 1 do
    fMaterialList[I].Free;
  SetLength(fMaterialList, 0);

  fName := ReadStringFromStream(Stream);
  Stream.ReadBuffer(CountValue, SizeOf(CountValue));
  if (CountValue < 0) or (CountValue > MAX_MATERIALS_PER_LIBRARY) then
    raise Exception.Create('Invalid material count in library stream.');

  SetLength(fMaterialList, CountValue);
  for I := 0 to CountValue - 1 do
  begin
    Mat := TMaterial.LoadFromStream(Stream, AShader);
    Mat.fMaterialID := I;
    fMaterialList[I] := Mat;
  end;
end;

procedure TMaterialLibrary.SaveToFile(const AFileName: string);
var
  Stream: TFileStream;
  Version: Integer;
begin
  ForceDirectories(ExtractFilePath(AFileName));
  Stream := TFileStream.Create(AFileName, fmCreate);
  try
    Stream.WriteBuffer(MATERIAL_LIBRARY_CHUNK_MAGIC[0], SizeOf(MATERIAL_LIBRARY_CHUNK_MAGIC));
    Version := MATERIAL_FILE_VERSION;
    Stream.WriteBuffer(Version, SizeOf(Version));
    SaveToStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TMaterialLibrary.LoadFromFile(const AFileName: string; AShader: TShader);
var
  Stream: TFileStream;
  Magic: array[0..7] of AnsiChar;
  Version: Integer;
begin
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Stream.ReadBuffer(Magic[0], SizeOf(Magic));
    if not MagicMatches(Magic, MATERIAL_LIBRARY_CHUNK_MAGIC) then
      raise Exception.Create('Invalid OpenGL Micro Engine material library file.');

    Stream.ReadBuffer(Version, SizeOf(Version));
    if (Version < 1) or (Version > MATERIAL_FILE_VERSION) then
      raise Exception.CreateFmt('Unsupported material library version: %d.', [Version]);

    LoadFromStream(Stream, AShader);
  finally
    Stream.Free;
  end;
end;

class function TMaterialLibrary.TryReadMaterialNamesFromFile(
  const AFileName: string; out AMaterialNames: TArray<string>): Boolean;
var
  Stream: TFileStream;
  Magic: array[0..7] of AnsiChar;
  Version: Integer;
  CountValue: Integer;
  I: Integer;
  MaterialName: string;
begin
  Result := False;
  AMaterialNames := nil;

  if not FileExists(AFileName) then
    Exit;

  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    try
      Stream.ReadBuffer(Magic[0], SizeOf(Magic));
      if not MagicMatches(Magic, MATERIAL_LIBRARY_CHUNK_MAGIC) then
        Exit;

      Stream.ReadBuffer(Version, SizeOf(Version));
      if (Version < 1) or (Version > MATERIAL_FILE_VERSION) then
        Exit;

      ReadStringFromStream(Stream); // library name
      Stream.ReadBuffer(CountValue, SizeOf(CountValue));
      if (CountValue < 0) or (CountValue > MAX_MATERIALS_PER_LIBRARY) then
        Exit;

      SetLength(AMaterialNames, CountValue);
      for I := 0 to CountValue - 1 do
      begin
        ReadSerializedMaterialNameAndSkip(Stream, MaterialName);
        AMaterialNames[I] := MaterialName;
      end;

      Result := True;
    except
      AMaterialNames := nil;
      Result := False;
    end;
  finally
    Stream.Free;
  end;
end;

class function TMaterialLibrary.TryLoadMaterialFromFileByName(const AFileName,
  AMaterialName: string; AShader: TShader; out AMaterial: TMaterial): Boolean;
var
  Stream: TFileStream;
  Magic: array[0..7] of AnsiChar;
  Version: Integer;
  CountValue: Integer;
  I: Integer;
  MaterialName: string;
  MaterialStart: Int64;
begin
  Result := False;
  AMaterial := nil;

  if (Trim(AMaterialName) = '') or (not FileExists(AFileName)) then
    Exit;

  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    try
      Stream.ReadBuffer(Magic[0], SizeOf(Magic));
      if not MagicMatches(Magic, MATERIAL_LIBRARY_CHUNK_MAGIC) then
        Exit;

      Stream.ReadBuffer(Version, SizeOf(Version));
      if (Version < 1) or (Version > MATERIAL_FILE_VERSION) then
        Exit;

      ReadStringFromStream(Stream); // library name
      Stream.ReadBuffer(CountValue, SizeOf(CountValue));
      if (CountValue < 0) or (CountValue > MAX_MATERIALS_PER_LIBRARY) then
        Exit;

      for I := 0 to CountValue - 1 do
      begin
        MaterialStart := Stream.Position;
        ReadSerializedMaterialNameAndSkip(Stream, MaterialName);
        if SameText(MaterialName, AMaterialName) then
        begin
          Stream.Position := MaterialStart;
          AMaterial := TMaterial.LoadFromStream(Stream, AShader);
          Result := AMaterial <> nil;
          Exit;
        end;
      end;
    except
      FreeAndNil(AMaterial);
      Result := False;
    end;
  finally
    Stream.Free;
  end;
end;

{ TMaterialLibraries }
constructor TMaterialLibraries.Create(aOwnsObjects: Boolean);
begin
  inherited Create(aOwnsObjects);
end;

function TMaterialLibraries.GetLib(aIndex: Integer): TMaterialLibrary;
begin
  Result := nil;

  if (aIndex >= 0) and (aIndex < Count) then
    Result := Items[aIndex];
end;

procedure TMaterialLibraries.SetLib(aIndex: Integer; aMaterialLibrary: TMaterialLibrary);
begin
  if (aIndex >= 0) and (aIndex < Count) then
    Items[aIndex] := aMaterialLibrary;
end;

function TMaterialLibraries.CreateMaterialLibrary(const aName: String): Integer;
var
  Lib: TMaterialLibrary;
begin
  Lib := TMaterialLibrary.Create;
  Lib.Name := aName;

  Result := AddMaterialLibrary(Lib);
end;

function TMaterialLibraries.AddMaterialLibrary(
  aMaterialLibrary: TMaterialLibrary): Integer;
begin
  if aMaterialLibrary = nil then
    Exit(-1);

  Result := inherited Add(aMaterialLibrary);
end;

function TMaterialLibraries.IndexOf(
  aMaterialLibrary: TMaterialLibrary): Integer;
begin
  Result := inherited IndexOf(aMaterialLibrary);
end;

function TMaterialLibraries.IndexOf(const aName: String): Integer;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
  begin
    if SameText(Items[i].Name, aName) then
      Exit(i);
  end;

  Result := -1;
end;

function TMaterialLibraries.GetMaterialLibrary(
  const aName: String): TMaterialLibrary;
var
  Index: Integer;
begin
  Result := nil;

  Index := IndexOf(aName);

  if Index <> -1 then
    Result := Items[Index];
end;

function TMaterialLibraries.GetMaterialLibrary(
  aIndex: Integer): TMaterialLibrary;
begin
  Result := GetLib(aIndex);
end;

procedure TMaterialLibraries.SaveToStream(Stream: TStream; const ExcludeMaterialName: string);
var
  I, Version, CountValue: Integer;
begin
  Stream.WriteBuffer(MATERIAL_LIBRARY_CHUNK_MAGIC[0], SizeOf(MATERIAL_LIBRARY_CHUNK_MAGIC));
  Version := MATERIAL_FILE_VERSION;
  Stream.WriteBuffer(Version, SizeOf(Version));
  CountValue := Count;
  Stream.WriteBuffer(CountValue, SizeOf(CountValue));
  for I := 0 to Count - 1 do
    Items[I].SaveToStream(Stream, ExcludeMaterialName);
end;

procedure TMaterialLibraries.LoadFromStream(Stream: TStream; AShader: TShader);
var
  StartPos: Int64;
  Magic: array[0..7] of AnsiChar;
  Version, I, CountValue: Integer;
  Lib: TMaterialLibrary;
begin
  if (Stream = nil) or (Stream.Position >= Stream.Size) then
    Exit;

  StartPos := Stream.Position;
  if (Stream.Size - Stream.Position) < SizeOf(Magic) then
    Exit;

  Stream.ReadBuffer(Magic[0], SizeOf(Magic));
  if not MagicMatches(Magic, MATERIAL_LIBRARY_CHUNK_MAGIC) then
  begin
    Stream.Position := StartPos;
    Exit;
  end;

  Stream.ReadBuffer(Version, SizeOf(Version));
  if (Version < 1) or (Version > MATERIAL_FILE_VERSION) then
    raise Exception.CreateFmt('Unsupported material library version: %d.', [Version]);

  Stream.ReadBuffer(CountValue, SizeOf(CountValue));
  if (CountValue < 0) or (CountValue > MAX_MATERIAL_LIBRARIES) then
    raise Exception.Create('Invalid material library count in stream.');

  Clear;
  for I := 0 to CountValue - 1 do
  begin
    Lib := TMaterialLibrary.Create;
    try
      Lib.LoadFromStream(Stream, AShader);
      AddMaterialLibrary(Lib);
    except
      Lib.Free;
      raise;
    end;
  end;
end;



end.
