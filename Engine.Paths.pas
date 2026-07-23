unit Engine.Paths;

interface

uses
  System.SysUtils,
  System.IOUtils;

type
  TEnginePathKind = (
    epRoot,
    epData,
    epTextures,
    epModels,
    epShaders,
    epMaterials,
    epParticles,
    epParticleTextures,
    epAnimatedSprites,
    epBillboards,
    epBillboardTextures,
    epAudio,
    epScripts,
    epPrefabs,
    epScenes,
    epTerrain,
    epGenerated,
    epEngineGUI
  );

  TEnginePaths = class sealed
  strict private
    class var FRootDir: string;
    class var FDataDir: string;
    class var FTexturesDir: string;
    class var FModelsDir: string;
    class var FShadersDir: string;
    class var FMaterialsDir: string;
    class var FParticlesDir: string;
    class var FParticleTexturesDir: string;
    class var FAnimatedSpritesDir: string;
    class var FBillboardsDir: string;
    class var FBillboardTexturesDir: string;
    class var FAudioDir: string;
    class var FScriptsDir: string;
    class var FPrefabsDir: string;
    class var FScenesDir: string;
    class var FTerrainDir: string;
    class var FGeneratedDir: string;
    class var FEngineGUIDir: string;

    class function NormalizeDir(const ADir: string): string; static;
    class function NormalizeSeparators(const APath: string): string; static;
    class function StartsWithPath(const APath, ABasePath: string): Boolean; static;
    class procedure SetRootDir(const ADir: string); static;
  public
    class constructor Create;

    class procedure Initialize(const ARootDir: string = ''); static;
    class procedure EnsureDirectories; static;

    class function Combine(const ADir, AFileName: string): string; static;

    class function Texture(const AFileName: string): string; static;
    class function Model(const AFileName: string): string; static;
    class function Shader(const AFileName: string): string; static;
    class function Material(const AFileName: string): string; static;
    class function Particle(const AFileName: string): string; static;
    class function ParticleTexture(const AFileName: string): string; static;
    class function AnimatedSprite(const AFileName: string): string; static;
    class function Billboard(const AFileName: string): string; static;
    class function BillboardTexture(const AFileName: string): string; static;
    class function Audio(const AFileName: string): string; static;
    class function Script(const AFileName: string): string; static;
    class function Prefab(const AFileName: string): string; static;
    class function Scene(const AFileName: string): string; static;
    class function Terrain(const AFileName: string): string; static;
    class function Generated(const AFileName: string): string; static;
    class function ResolveGeneratedTextureFileName(
      const AFileName: string): string; static;
    class function EngineGUI(const AFileName: string): string; static;

    class function ToAssetRelativePath(const APath: string): string; static;
    class function ResolveAssetPath(const AStoredPath: string): string; static;
    class function IsInsideDataDir(const APath: string): Boolean; static;

    class function Dir(AKind: TEnginePathKind): string; static;

    class property RootDir: string read FRootDir write SetRootDir;
    class property DataDir: string read FDataDir;
    class property TexturesDir: string read FTexturesDir;
    class property ModelsDir: string read FModelsDir;
    class property ShadersDir: string read FShadersDir;
    class property MaterialsDir: string read FMaterialsDir;
    class property ParticlesDir: string read FParticlesDir;
    class property ParticleTexturesDir: string read FParticleTexturesDir;
    class property AnimatedSpritesDir: string read FAnimatedSpritesDir;
    class property BillboardsDir: string read FBillboardsDir;
    class property BillboardTexturesDir: string read FBillboardTexturesDir;
    class property AudioDir: string read FAudioDir;
    class property ScriptsDir: string read FScriptsDir;
    class property PrefabsDir: string read FPrefabsDir;
    class property ScenesDir: string read FScenesDir;
    class property TerrainDir: string read FTerrainDir;
    class property GeneratedDir: string read FGeneratedDir;
    class property EngineGUIDir: string read FEngineGUIDir;
  end;

implementation

class constructor TEnginePaths.Create;
begin
  Initialize;
end;

class function TEnginePaths.NormalizeDir(const ADir: string): string;
begin
  Result := Trim(ADir);

  if Result = '' then
    Exit('');

  Result := ExpandFileName(Result);
  Result := IncludeTrailingPathDelimiter(Result);
end;

class function TEnginePaths.NormalizeSeparators(const APath: string): string;
begin
  Result := StringReplace(APath, '/', PathDelim, [rfReplaceAll]);
  Result := StringReplace(Result, '\', PathDelim, [rfReplaceAll]);
end;

class function TEnginePaths.StartsWithPath(const APath, ABasePath: string): Boolean;
var
  P, B: string;
begin
  P := NormalizeSeparators(ExpandFileName(APath));
  B := IncludeTrailingPathDelimiter(NormalizeSeparators(ExpandFileName(ABasePath)));

  Result := SameText(Copy(P, 1, Length(B)), B);
end;

class procedure TEnginePaths.Initialize(const ARootDir: string);
begin
  if ARootDir <> '' then
    SetRootDir(ARootDir)
  else
    SetRootDir(ExtractFilePath(ParamStr(0)));
end;

class procedure TEnginePaths.SetRootDir(const ADir: string);
begin
  FRootDir := NormalizeDir(ADir);

  FDataDir      := IncludeTrailingPathDelimiter(TPath.Combine(FRootDir, 'Data'));
  FTexturesDir  := IncludeTrailingPathDelimiter(TPath.Combine(FDataDir, 'Tex'));
  FModelsDir    := IncludeTrailingPathDelimiter(TPath.Combine(FDataDir, 'Models'));
  FShadersDir   := IncludeTrailingPathDelimiter(TPath.Combine(FDataDir, 'GLSL'));
  FMaterialsDir := IncludeTrailingPathDelimiter(TPath.Combine(FDataDir, 'Materials'));
  FParticlesDir := IncludeTrailingPathDelimiter(TPath.Combine(FDataDir, 'Particles'));
  FParticleTexturesDir := IncludeTrailingPathDelimiter(TPath.Combine(FParticlesDir, 'Textures'));
  FAnimatedSpritesDir := IncludeTrailingPathDelimiter(TPath.Combine(FDataDir, 'AnimatedSprites'));
  FBillboardsDir := IncludeTrailingPathDelimiter(TPath.Combine(FDataDir, 'Billboards'));
  FBillboardTexturesDir := IncludeTrailingPathDelimiter(TPath.Combine(FBillboardsDir, 'Textures'));
  FAudioDir     := IncludeTrailingPathDelimiter(TPath.Combine(FDataDir, 'Audio'));
  FScriptsDir   := IncludeTrailingPathDelimiter(TPath.Combine(FDataDir, 'Scripts'));
  FPrefabsDir   := IncludeTrailingPathDelimiter(TPath.Combine(FDataDir, 'Prefabs'));
  FScenesDir    := IncludeTrailingPathDelimiter(TPath.Combine(FDataDir, 'Scenes'));
  FTerrainDir   := IncludeTrailingPathDelimiter(TPath.Combine(FDataDir, 'Terrain'));
  FGeneratedDir := IncludeTrailingPathDelimiter(TPath.Combine(FDataDir, 'Generated'));
  FEngineGUIDir := IncludeTrailingPathDelimiter(TPath.Combine(FDataDir, 'EngineGUI'));
end;

class procedure TEnginePaths.EnsureDirectories;
begin
  ForceDirectories(FDataDir);
  ForceDirectories(FTexturesDir);
  ForceDirectories(FModelsDir);
  ForceDirectories(FShadersDir);
  ForceDirectories(FMaterialsDir);
  ForceDirectories(FParticlesDir);
  ForceDirectories(FParticleTexturesDir);
  ForceDirectories(FAnimatedSpritesDir);
  ForceDirectories(FBillboardsDir);
  ForceDirectories(FBillboardTexturesDir);
  ForceDirectories(FAudioDir);
  ForceDirectories(FScriptsDir);
  ForceDirectories(FPrefabsDir);
  ForceDirectories(FScenesDir);
  ForceDirectories(FTerrainDir);
  ForceDirectories(FGeneratedDir);
  ForceDirectories(FEngineGUIDir);
end;

class function TEnginePaths.Combine(const ADir, AFileName: string): string;
begin
  if AFileName = '' then
    Exit(ADir);

  if TPath.IsPathRooted(AFileName) then
    Exit(AFileName);

  Result := TPath.Combine(ADir, AFileName);
end;

class function TEnginePaths.Texture(const AFileName: string): string;
begin
  Result := Combine(FTexturesDir, AFileName);
end;

class function TEnginePaths.Model(const AFileName: string): string;
begin
  Result := Combine(FModelsDir, AFileName);
end;

class function TEnginePaths.Shader(const AFileName: string): string;
begin
  Result := Combine(FShadersDir, AFileName);
end;

class function TEnginePaths.Material(const AFileName: string): string;
begin
  Result := Combine(FMaterialsDir, AFileName);
end;

class function TEnginePaths.Particle(const AFileName: string): string;
begin
  Result := Combine(FParticlesDir, AFileName);
end;

class function TEnginePaths.ParticleTexture(const AFileName: string): string;
begin
  Result := Combine(FParticleTexturesDir, AFileName);
end;

class function TEnginePaths.AnimatedSprite(const AFileName: string): string;
begin
  Result := Combine(FAnimatedSpritesDir, AFileName);
end;

class function TEnginePaths.Billboard(const AFileName: string): string;
begin
  Result := Combine(FBillboardsDir, AFileName);
end;

class function TEnginePaths.BillboardTexture(const AFileName: string): string;
begin
  Result := Combine(FBillboardTexturesDir, AFileName);
end;

class function TEnginePaths.Audio(const AFileName: string): string;
begin
  Result := Combine(FAudioDir, AFileName);
end;

class function TEnginePaths.Script(const AFileName: string): string;
begin
  Result := Combine(FScriptsDir, AFileName);
end;

class function TEnginePaths.Prefab(const AFileName: string): string;
begin
  Result := Combine(FPrefabsDir, AFileName);
end;

class function TEnginePaths.Scene(const AFileName: string): string;
begin
  Result := Combine(FScenesDir, AFileName);
end;

class function TEnginePaths.Terrain(const AFileName: string): string;
begin
  Result := Combine(FTerrainDir, AFileName);
end;

class function TEnginePaths.Generated(const AFileName: string): string;
begin
  Result := Combine(FGeneratedDir, AFileName);
end;

class function TEnginePaths.ResolveGeneratedTextureFileName(
  const AFileName: string): string;
var
  S: string;
  Ext: string;
  GeneratedRoot: string;
  Candidate: string;
begin
  S := Trim(NormalizeSeparators(AFileName));
  if TPath.IsPathRooted(S) then
    S := ExtractFileName(S);

  if S = '' then
    S := FormatDateTime('Render_yyyymmdd_hhnnss', Now);

  Ext := ExtractFileExt(S);
  if not SameText(Ext, '.png') then
    S := ChangeFileExt(S, '.png');

  GeneratedRoot := IncludeTrailingPathDelimiter(
    ExpandFileName(FGeneratedDir));
  Candidate := ExpandFileName(Generated(S));
  if not SameText(Copy(Candidate, 1, Length(GeneratedRoot)), GeneratedRoot) then
    Candidate := Generated(ExtractFileName(S));

  Result := Candidate;
end;

class function TEnginePaths.EngineGUI(const AFileName: string): string;
begin
  Result := Combine(FEngineGUIDir, AFileName);
end;

class function TEnginePaths.ToAssetRelativePath(const APath: string): string;
var
  S, FullPath, DataPath: string;
begin
  S := Trim(NormalizeSeparators(APath));

  if S = '' then
    Exit('');

  // Already relative. Store it normalized and without leading "Data\".
  if not TPath.IsPathRooted(S) then
  begin
    if SameText(Copy(S, 1, Length('Data' + PathDelim)), 'Data' + PathDelim) then
      Delete(S, 1, Length('Data' + PathDelim));

    Exit(S);
  end;

  FullPath := NormalizeSeparators(ExpandFileName(S));
  DataPath := IncludeTrailingPathDelimiter(NormalizeSeparators(ExpandFileName(FDataDir)));

  // If the file is inside current Data\, store path relative to Data\.
  if SameText(Copy(FullPath, 1, Length(DataPath)), DataPath) then
    Exit(Copy(FullPath, Length(DataPath) + 1, MaxInt));

  // External files remain absolute because the engine cannot safely make them portable.
  Result := FullPath;
end;

class function TEnginePaths.ResolveAssetPath(const AStoredPath: string): string;
var
  S, LowerS, Marker, RelPath, Candidate: string;
  P: Integer;
begin
  S := Trim(NormalizeSeparators(AStoredPath));

  if S = '' then
    Exit('');

  // If the stored path exists as-is, use it. This supports old projects
  // on the same machine and intentionally external files.
  if FileExists(S) then
    Exit(ExpandFileName(S));

  // New portable format: "Tex\StoneColor.tga", "Models\Ship.obj", etc.
  if not TPath.IsPathRooted(S) then
  begin
    if SameText(Copy(S, 1, Length('Data' + PathDelim)), 'Data' + PathDelim) then
      Delete(S, 1, Length('Data' + PathDelim));

    Exit(TPath.Combine(FDataDir, S));
  end;

  // Old broken format from another machine:
  // C:\OldProject\Data\Tex\StoneColor.tga
  // Convert everything after "\Data\" to current Data\.
  LowerS := LowerCase(S);
  Marker := LowerCase(PathDelim + 'Data' + PathDelim);
  P := Pos(Marker, LowerS);

  if P > 0 then
  begin
    RelPath := Copy(S, P + Length(Marker), MaxInt);
    Candidate := TPath.Combine(FDataDir, RelPath);
    Exit(Candidate);
  end;

  // Unknown absolute path outside Data\. Return it unchanged.
  // ReloadMaterialTexture will fail gracefully if it does not exist.
  Result := S;
end;

class function TEnginePaths.IsInsideDataDir(const APath: string): Boolean;
begin
  Result := StartsWithPath(APath, FDataDir);
end;

class function TEnginePaths.Dir(AKind: TEnginePathKind): string;
begin
  case AKind of
    epRoot:      Result := FRootDir;
    epData:      Result := FDataDir;
    epTextures:  Result := FTexturesDir;
    epModels:    Result := FModelsDir;
    epShaders:   Result := FShadersDir;
    epMaterials: Result := FMaterialsDir;
    epParticles: Result := FParticlesDir;
    epParticleTextures: Result := FParticleTexturesDir;
    epAnimatedSprites: Result := FAnimatedSpritesDir;
    epBillboards: Result := FBillboardsDir;
    epBillboardTextures: Result := FBillboardTexturesDir;
    epAudio:     Result := FAudioDir;
    epScripts:   Result := FScriptsDir;
    epPrefabs:   Result := FPrefabsDir;
    epScenes:    Result := FScenesDir;
    epTerrain:   Result := FTerrainDir;
    epGenerated: Result := FGeneratedDir;
    epEngineGUI: Result := FEngineGUIDir;
  else
    Result := FRootDir;
  end;
end;

end.
