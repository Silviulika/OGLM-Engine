unit Renderer.RenderTechnique;

interface

uses
  System.SysUtils, dglOpenGL, Neslib.FastMath, Engine.Types,
  Renderer.Shader, Managers.Material;

type
  TRenderTechniqueState = record
    DepthTest: Boolean;
    DepthWrite: Boolean;
    DepthFunc: GLenum;

    CullFace: Boolean;
    CullFaceMode: GLenum;

    Blend: Boolean;
    BlendSrc: GLenum;
    BlendDst: GLenum;

    class function DefaultOpaque: TRenderTechniqueState; static;
    class function DefaultTransparent: TRenderTechniqueState; static;
    class function DefaultShadow: TRenderTechniqueState; static;
  end;

  TRenderTechnique = class
  private
    fShader: TShader;
    fOwnsShader: Boolean;
    fState: TRenderTechniqueState;

  protected
    procedure ApplyRenderState; virtual;

    procedure SetTexture(const AUniformName: string; ATextureUnit: GLint; ATextureTarget: GLenum; ATextureID: GLuint);

  public
    constructor Create(AShader: TShader; AOwnsShader: Boolean = False); virtual;
    destructor Destroy; override;

    procedure BeginTechnique; virtual;
    procedure EndTechnique; virtual;

    procedure ApplyGlobalUniforms; virtual;
    procedure ApplyMaterial(AMaterial: TMaterial); virtual;

    procedure ApplyObject(const AModelMatrix: TMatrix4); overload; virtual;
    procedure ApplyObject(const AModelMatrix: TMatrix4; const ANormalMatrix: TMatrix3); overload; virtual;

    property Shader: TShader read fShader;
    property OwnsShader: Boolean read fOwnsShader write fOwnsShader;
    property State: TRenderTechniqueState read fState write fState;
  end;

  TPBRRenderTechnique = class(TRenderTechnique)
  private
    function TerrainTextureBinding(const AUniformName: string;
      out AShaderUniformName: string; out ATextureUnit: GLint): Boolean;
    function TextureUnitForUniform(const AUniformName: string; var AExtraUnit: GLint): GLint;
    procedure ResetTextureUsageUniforms;
    procedure MarkTextureUniformUsed(const AUniformName: string; AUsed: Boolean);

  public
    constructor Create(AShader: TShader; AOwnsShader: Boolean = False); override;

    procedure ApplyMaterial(AMaterial: TMaterial); override;
  end;

  THeightFieldMultiMaterialTechnique = class(TPBRRenderTechnique)
  public
    constructor Create(AShader: TShader; AOwnsShader: Boolean = False); override;

    procedure ApplyMaterial(AMaterial: TMaterial); override;
  end;

  TShadowDepthTechnique = class(TRenderTechnique)
  public
    constructor Create(AShader: TShader; AOwnsShader: Boolean = False); override;

    procedure ApplyMaterial(AMaterial: TMaterial); override;
  end;

implementation

const
  TERRAIN_LAYER_COUNT = 5;
  TERRAIN_ALPHA_TEXTURE_GROUP = 0;
  TERRAIN_ALBEDO_TEXTURE_GROUP = 1;
  TERRAIN_NORMAL_TEXTURE_GROUP = 2;
  TERRAIN_HEIGHT_TEXTURE_GROUP = 3;
  TERRAIN_METALNESS_TEXTURE_GROUP = 4;
  TERRAIN_ROUGHNESS_TEXTURE_GROUP = 5;
  TERRAIN_TEXTURE_GROUP_COUNT = 6;
  SHADOW_TEXTURE_UNIT = 8;
  TERRAIN_EXTRA_TEXTURE_UNIT = TERRAIN_TEXTURE_GROUP_COUNT * TERRAIN_LAYER_COUNT + 1;

function TerrainTextureUnit(AGroupIndex, ALayerIndex: Integer): GLint;
begin
  Result := AGroupIndex * TERRAIN_LAYER_COUNT + ALayerIndex;
  if Result >= SHADOW_TEXTURE_UNIT then
    Inc(Result);
end;

{ TRenderTechniqueState }

class function TRenderTechniqueState.DefaultOpaque: TRenderTechniqueState;
begin
  Result.DepthTest := True;
  Result.DepthWrite := True;
  Result.DepthFunc := GL_LEQUAL;

  Result.CullFace := True;
  Result.CullFaceMode := GL_BACK;

  Result.Blend := False;
  Result.BlendSrc := GL_SRC_ALPHA;
  Result.BlendDst := GL_ONE_MINUS_SRC_ALPHA;
end;

class function TRenderTechniqueState.DefaultTransparent: TRenderTechniqueState;
begin
  Result := DefaultOpaque;

  Result.DepthWrite := False;

  Result.Blend := True;
  Result.BlendSrc := GL_SRC_ALPHA;
  Result.BlendDst := GL_ONE_MINUS_SRC_ALPHA;
end;

class function TRenderTechniqueState.DefaultShadow: TRenderTechniqueState;
begin
  Result.DepthTest := True;
  Result.DepthWrite := True;
  Result.DepthFunc := GL_LESS;

  Result.CullFace := True;
  Result.CullFaceMode := GL_BACK;

  Result.Blend := False;
  Result.BlendSrc := GL_ONE;
  Result.BlendDst := GL_ZERO;
end;

{ TRenderTechnique }

constructor TRenderTechnique.Create(AShader: TShader; AOwnsShader: Boolean);
begin
  inherited Create;

  if not Assigned(AShader) then
    raise Exception.Create('TRenderTechnique requires a valid shader.');

  fShader := AShader;
  fOwnsShader := AOwnsShader;
  fState := TRenderTechniqueState.DefaultOpaque;
end;

destructor TRenderTechnique.Destroy;
begin
  if fOwnsShader then
    FreeAndNil(fShader);

  inherited Destroy;
end;

procedure TRenderTechnique.ApplyRenderState;
begin
  if fState.DepthTest then
    glEnable(GL_DEPTH_TEST)
  else
    glDisable(GL_DEPTH_TEST);

  if fState.DepthWrite then
    glDepthMask(GL_TRUE)
  else
    glDepthMask(GL_FALSE);

  glDepthFunc(fState.DepthFunc);

  if fState.CullFace then
  begin
    glEnable(GL_CULL_FACE);
    glCullFace(fState.CullFaceMode);
  end
  else
    glDisable(GL_CULL_FACE);

  if fState.Blend then
  begin
    glEnable(GL_BLEND);
    glBlendFunc(fState.BlendSrc, fState.BlendDst);
  end
  else
    glDisable(GL_BLEND);
end;

procedure TRenderTechnique.BeginTechnique;
begin
  ApplyRenderState;

  fShader.Use;

  ApplyGlobalUniforms;
end;

procedure TRenderTechnique.EndTechnique;
begin
  // Optional. Leave shader bound, or unbind if you prefer:
  // glUseProgram(0);
end;

procedure TRenderTechnique.ApplyGlobalUniforms;
begin
  // Your current TShader calls the global shader callback through Progress.
  // If you later rename Progress to ApplyGlobalUniforms, change this line.
  fShader.UpdateUniforms;
end;

procedure TRenderTechnique.ApplyMaterial(AMaterial: TMaterial);
begin
  // Base class does nothing.
  // Derived classes decide how material data is sent to the shader.
end;

procedure TRenderTechnique.ApplyObject(const AModelMatrix: TMatrix4);
begin
  fShader.SetUniform('modelMatrix', AModelMatrix);
end;

procedure TRenderTechnique.ApplyObject(const AModelMatrix: TMatrix4;
  const ANormalMatrix: TMatrix3);
begin
  fShader.SetUniform('modelMatrix', AModelMatrix);
  fShader.SetUniform('normalMatrix', ANormalMatrix);
end;

procedure TRenderTechnique.SetTexture(const AUniformName: string; ATextureUnit: GLint; ATextureTarget: GLenum; ATextureID: GLuint);
begin
  if ATextureID = 0 then
    Exit;

  glActiveTexture(GL_TEXTURE0 + ATextureUnit);
  glBindTexture(ATextureTarget, ATextureID);

  fShader.SetUniform(AUniformName, ATextureUnit);
end;

{ TPBRRenderTechnique }
constructor TPBRRenderTechnique.Create(AShader: TShader; AOwnsShader: Boolean);
begin
  inherited Create(AShader, AOwnsShader);

  State := TRenderTechniqueState.DefaultOpaque;
end;

function TPBRRenderTechnique.TerrainTextureBinding(const AUniformName: string;
  out AShaderUniformName: string; out ATextureUnit: GLint): Boolean;
var
  UniformLower: string;
  Suffix: string;
  Index: Integer;

  function ParseIndexed(const SingularPrefix, ArrayPrefix: string;
    GroupIndex: Integer; const ArrayUniform: string): Boolean;
  var
    Prefix: string;
  begin
    Result := False;

    Prefix := LowerCase(SingularPrefix);
    if (Length(UniformLower) > Length(Prefix)) and
       (Copy(UniformLower, 1, Length(Prefix)) = Prefix) then
    begin
      Suffix := Copy(UniformLower, Length(Prefix) + 1, MaxInt);
      if TryStrToInt(Suffix, Index) and (Index >= 0) and
         (Index < TERRAIN_LAYER_COUNT) then
      begin
        AShaderUniformName := Format('%s[%d]', [ArrayUniform, Index]);
        ATextureUnit := TerrainTextureUnit(GroupIndex, Index);
        Exit(True);
      end;
    end;

    Prefix := LowerCase(ArrayPrefix) + '[';
    if Copy(UniformLower, 1, Length(Prefix)) = Prefix then
    begin
      Suffix := Copy(UniformLower, Length(Prefix) + 1, MaxInt);
      if (Suffix <> '') and (Suffix[Length(Suffix)] = ']') then
        Delete(Suffix, Length(Suffix), 1);

      if TryStrToInt(Suffix, Index) and (Index >= 0) and
         (Index < TERRAIN_LAYER_COUNT) then
      begin
        AShaderUniformName := Format('%s[%d]', [ArrayUniform, Index]);
        ATextureUnit := TerrainTextureUnit(GroupIndex, Index);
        Exit(True);
      end;
    end;
  end;
begin
  Result := False;
  AShaderUniformName := AUniformName;
  ATextureUnit := -1;
  UniformLower := LowerCase(Trim(AUniformName));

  if ParseIndexed('alphaTexture', 'alphaTextures', TERRAIN_ALPHA_TEXTURE_GROUP, 'alphaTextures') then
    Exit(True);
  if ParseIndexed('maskTexture', 'maskTextures', TERRAIN_ALPHA_TEXTURE_GROUP, 'alphaTextures') then
    Exit(True);
  if ParseIndexed('blendTexture', 'blendTextures', TERRAIN_ALPHA_TEXTURE_GROUP, 'alphaTextures') then
    Exit(True);
  if ParseIndexed('blendMap', 'blendMaps', TERRAIN_ALPHA_TEXTURE_GROUP, 'alphaTextures') then
    Exit(True);
  if ParseIndexed('splatMap', 'splatMaps', TERRAIN_ALPHA_TEXTURE_GROUP, 'alphaTextures') then
    Exit(True);

  if ParseIndexed('albedoTexture', 'albedoTextures', TERRAIN_ALBEDO_TEXTURE_GROUP, 'albedoTextures') then
    Exit(True);
  if ParseIndexed('normalTexture', 'normalTextures', TERRAIN_NORMAL_TEXTURE_GROUP, 'normalTextures') then
    Exit(True);
  if ParseIndexed('heightTexture', 'heightTextures', TERRAIN_HEIGHT_TEXTURE_GROUP, 'heightTextures') then
    Exit(True);
  if ParseIndexed('heightMap', 'heightMaps', TERRAIN_HEIGHT_TEXTURE_GROUP, 'heightTextures') then
    Exit(True);
  if ParseIndexed('displaceTexture', 'displaceTextures', TERRAIN_HEIGHT_TEXTURE_GROUP, 'heightTextures') then
    Exit(True);
  if ParseIndexed('displacementTexture', 'displacementTextures', TERRAIN_HEIGHT_TEXTURE_GROUP, 'heightTextures') then
    Exit(True);
  if ParseIndexed('displaceMap', 'displaceMaps', TERRAIN_HEIGHT_TEXTURE_GROUP, 'heightTextures') then
    Exit(True);
  if ParseIndexed('displacementMap', 'displacementMaps', TERRAIN_HEIGHT_TEXTURE_GROUP, 'heightTextures') then
    Exit(True);
  if ParseIndexed('metalnessTexture', 'metalnessTextures', TERRAIN_METALNESS_TEXTURE_GROUP, 'metalnessTextures') then
    Exit(True);
  if ParseIndexed('metallicTexture', 'metalnessTextures', TERRAIN_METALNESS_TEXTURE_GROUP, 'metalnessTextures') then
    Exit(True);
  if ParseIndexed('metallicTexture', 'metallicTextures', TERRAIN_METALNESS_TEXTURE_GROUP, 'metalnessTextures') then
    Exit(True);
  if ParseIndexed('roughnessTexture', 'roughnessTextures', TERRAIN_ROUGHNESS_TEXTURE_GROUP, 'roughnessTextures') then
    Exit(True);
end;

function TPBRRenderTechnique.TextureUnitForUniform(const AUniformName: string;
  var AExtraUnit: GLint): GLint;
begin
  // Keep this mapping stable.
  // Your shadow map currently uses texture unit 8, so extra material textures start at 9.

  if SameText(AUniformName, 'albedoTexture') then
    Exit(0);

  if SameText(AUniformName, 'normalTexture') then
    Exit(1);

  if SameText(AUniformName, 'heightTexture') then
    Exit(2);

  if SameText(AUniformName, 'metalnessTexture') or
     SameText(AUniformName, 'metallicTexture') then
    Exit(3);

  if SameText(AUniformName, 'roughnessTexture') then
    Exit(4);

  if SameText(AUniformName, 'specularTexture') then
    Exit(5);

  if SameText(AUniformName, 'ambientOcclusionTexture') or
     SameText(AUniformName, 'irradianceTexture') or
     SameText(AUniformName, 'ambientTexture') then
    Exit(6);

  if SameText(AUniformName, 'specularBRDF_LUT') or
     SameText(AUniformName, 'brdfLUTTexture') then
    Exit(7);

  Result := AExtraUnit;
  Inc(AExtraUnit);
end;

procedure TPBRRenderTechnique.ResetTextureUsageUniforms;
begin
  // These uniforms are optional. If your GLSL does not have them,
  // TShader.SetUniform safely ignores location -1.

  Shader.SetUniform('useAlbedoTexture', False);
  Shader.SetUniform('useNormalTexture', False);
  Shader.SetUniform('useHeightTexture', False);
  Shader.SetUniform('useMetalnessTexture', False);
  Shader.SetUniform('useMetallicTexture', False);
  Shader.SetUniform('useRoughnessTexture', False);
  Shader.SetUniform('useSpecularTexture', False);
  Shader.SetUniform('useAmbientOcclusionTexture', False);
  Shader.SetUniform('useSpecularBRDFLUT', False);
  Shader.SetUniform('useBlendTexture', False);
  Shader.SetUniform('useTerrainAlphaMasks', False);

  for var i := 0 to TERRAIN_LAYER_COUNT - 1 do
  begin
    Shader.SetUniform(Format('useAlphaTextures[%d]', [i]), False);
    Shader.SetUniform(Format('useHeightTextures[%d]', [i]), False);
  end;
end;

procedure TPBRRenderTechnique.MarkTextureUniformUsed(const AUniformName: string;
  AUsed: Boolean);
var
  UniformLower: string;

  function MarkIndexedTexture(const SingularPrefix, ArrayPrefix,
    UseUniformName: string; ASetTerrainAlphaMask: Boolean): Boolean;
  var
    Prefix: string;
    Suffix: string;
    Index: Integer;
  begin
    Result := False;

    Prefix := LowerCase(SingularPrefix);
    if (Length(UniformLower) > Length(Prefix)) and
       (Copy(UniformLower, 1, Length(Prefix)) = Prefix) then
    begin
      Suffix := Copy(UniformLower, Length(Prefix) + 1, MaxInt);
      if TryStrToInt(Suffix, Index) and (Index >= 0) and
         (Index < TERRAIN_LAYER_COUNT) then
      begin
        Shader.SetUniform(Format('%s[%d]', [UseUniformName, Index]), AUsed);
        if ASetTerrainAlphaMask then
          Shader.SetUniform('useTerrainAlphaMasks', AUsed);
        Exit(True);
      end;
    end;

    Prefix := LowerCase(ArrayPrefix) + '[';
    if Copy(UniformLower, 1, Length(Prefix)) = Prefix then
    begin
      Suffix := Copy(UniformLower, Length(Prefix) + 1, MaxInt);
      if (Suffix <> '') and (Suffix[Length(Suffix)] = ']') then
        Delete(Suffix, Length(Suffix), 1);

      if TryStrToInt(Suffix, Index) and (Index >= 0) and
         (Index < TERRAIN_LAYER_COUNT) then
      begin
        Shader.SetUniform(Format('%s[%d]', [UseUniformName, Index]), AUsed);
        if ASetTerrainAlphaMask then
          Shader.SetUniform('useTerrainAlphaMasks', AUsed);
        Exit(True);
      end;
    end;
  end;
begin
  UniformLower := LowerCase(Trim(AUniformName));

  if MarkIndexedTexture('alphaTexture', 'alphaTextures', 'useAlphaTextures', True) or
     MarkIndexedTexture('maskTexture', 'maskTextures', 'useAlphaTextures', True) or
     MarkIndexedTexture('blendTexture', 'blendTextures', 'useAlphaTextures', True) or
     MarkIndexedTexture('blendMap', 'blendMaps', 'useAlphaTextures', True) or
     MarkIndexedTexture('splatMap', 'splatMaps', 'useAlphaTextures', True) then
    Exit;

  if MarkIndexedTexture('heightTexture', 'heightTextures', 'useHeightTextures', False) or
     MarkIndexedTexture('heightMap', 'heightMaps', 'useHeightTextures', False) or
     MarkIndexedTexture('displaceTexture', 'displaceTextures', 'useHeightTextures', False) or
     MarkIndexedTexture('displacementTexture', 'displacementTextures', 'useHeightTextures', False) or
     MarkIndexedTexture('displaceMap', 'displaceMaps', 'useHeightTextures', False) or
     MarkIndexedTexture('displacementMap', 'displacementMaps', 'useHeightTextures', False) then
    Exit;

  if SameText(AUniformName, 'albedoTexture') then
    Shader.SetUniform('useAlbedoTexture', AUsed)
  else if SameText(AUniformName, 'blendTexture') or
          SameText(AUniformName, 'blendMap') or
          SameText(AUniformName, 'splatMap') then
    Shader.SetUniform('useBlendTexture', AUsed)
  else if SameText(AUniformName, 'normalTexture') then
    Shader.SetUniform('useNormalTexture', AUsed)
  else if SameText(AUniformName, 'heightTexture') then
    Shader.SetUniform('useHeightTexture', AUsed)
  else if SameText(AUniformName, 'metalnessTexture') then
    Shader.SetUniform('useMetalnessTexture', AUsed)
  else if SameText(AUniformName, 'metallicTexture') then
    Shader.SetUniform('useMetallicTexture', AUsed)
  else if SameText(AUniformName, 'roughnessTexture') then
    Shader.SetUniform('useRoughnessTexture', AUsed)
  else if SameText(AUniformName, 'specularTexture') then
    Shader.SetUniform('useSpecularTexture', AUsed)
  else if SameText(AUniformName, 'ambientOcclusionTexture') or
          SameText(AUniformName, 'irradianceTexture') or
          SameText(AUniformName, 'ambientTexture') then
    Shader.SetUniform('useAmbientOcclusionTexture', AUsed)
  else if SameText(AUniformName, 'specularBRDF_LUT') then
    Shader.SetUniform('useSpecularBRDFLUT', AUsed);
end;

procedure TPBRRenderTechnique.ApplyMaterial(AMaterial: TMaterial);
var
  i: Integer;
  Tex: TMaterialTexture;
  UniformName: string;
  ShaderUniformName: string;
  TextureUnit: GLint;
  ExtraTextureUnit: GLint;
  UseParallaxMapping: Boolean;
  HeightTextureFileName: string;
begin
  inherited ApplyMaterial(AMaterial);

  if not Assigned(AMaterial) then
    Exit;

  Shader.SetUniform('materialType', Ord(AMaterial.Materialtype));
  Shader.SetUniform('gamma', AMaterial.ShaderParameters.Gamma);
  Shader.SetUniform('layers', AMaterial.ShaderParameters.Layers);
  Shader.SetUniform('pivot', AMaterial.ShaderParameters.Pivot);
  Shader.SetUniform('metallicMult', AMaterial.ShaderParameters.MetallicMult);
  Shader.SetUniform('specularLevel', AMaterial.ShaderParameters.SpecularLevel);
  Shader.SetUniform('heightScale', AMaterial.ShaderParameters.HeightScale);
  Shader.SetUniform('ambientShadowStrength', AMaterial.ShaderParameters.AmbientShadowStrength);
  Shader.SetUniform('hdrExposure', AMaterial.ShaderParameters.HdrExposure);
  Shader.SetUniform('alphaCutoff', AMaterial.ShaderParameters.AlphaCutoff);

  ResetTextureUsageUniforms;

  // Your current material scalar data lives inside TMaterialTexture.Texture.
  // Use the first texture as the fallback source for common material values.
  if AMaterial.Count > 0 then
  begin
    Tex := AMaterial.TextureList[0];

    Shader.SetUniform('diffuseColor', Tex.Texture.DiffuseColor);
    Shader.SetUniform('specularColor', Tex.Texture.SpecularColor);
    Shader.SetUniform('shininess', Tex.Texture.Shininess);

    // Optional alternative names.
    Shader.SetUniform('material.diffuseColor', Tex.Texture.DiffuseColor);
    Shader.SetUniform('material.specularColor', Tex.Texture.SpecularColor);
    Shader.SetUniform('material.shininess', Tex.Texture.Shininess);
  end;

  if AMaterial.Materialtype = mtHeightFieldMaterial then
    ExtraTextureUnit := TERRAIN_EXTRA_TEXTURE_UNIT
  else
    ExtraTextureUnit := 9;

  UseParallaxMapping := False;
  for i := 0 to AMaterial.Count - 1 do
  begin
    Tex := AMaterial.TextureList[i];

    UniformName := Trim(Tex.Texture.Name);

    if UniformName = '' then
      Continue;

    if Tex.Texture.TexID = 0 then
      Continue;

    if not TerrainTextureBinding(UniformName, ShaderUniformName, TextureUnit) then
    begin
      TextureUnit := TextureUnitForUniform(UniformName, ExtraTextureUnit);

      if SameText(UniformName, 'irradianceTexture') or
         SameText(UniformName, 'ambientTexture') then
        ShaderUniformName := 'ambientOcclusionTexture'
      else
        ShaderUniformName := UniformName;
    end;

    SetTexture(
      ShaderUniformName,
      TextureUnit,
      GL_TEXTURE_2D,
      Tex.Texture.TexID
    );

    if SameText(UniformName, 'heightTexture') then
    begin
      HeightTextureFileName := LowerCase(ExtractFileName(Tex.Path));
      UseParallaxMapping := (HeightTextureFileName = '') or
        (Pos('defaultheight', HeightTextureFileName) <> 1);
    end;

    MarkTextureUniformUsed(UniformName, True);
  end;

  // Skinned actor meshes use tightly packed glTF atlases. Keep their sampled
  // UVs exactly at TEXCOORD_0: POM can move a fragment across an island edge
  // into an unrelated body part or the black atlas background. Normal mapping
  // remains active and provides the appropriate animated-surface detail.
  UseParallaxMapping := UseParallaxMapping and
    (AMaterial.Materialtype <> mtActor) and
    (Abs(AMaterial.ShaderParameters.HeightScale) > 1.0e-8) and
    (AMaterial.ShaderParameters.Layers > 0);
  Shader.SetUniform('useParallaxMapping', UseParallaxMapping);
end;

{ THeightFieldMultiMaterialTechnique }

constructor THeightFieldMultiMaterialTechnique.Create(AShader: TShader;
  AOwnsShader: Boolean);
begin
  inherited Create(AShader, AOwnsShader);

  State := TRenderTechniqueState.DefaultOpaque;
end;

procedure THeightFieldMultiMaterialTechnique.ApplyMaterial(AMaterial: TMaterial);
begin
  inherited ApplyMaterial(AMaterial);

  // HeightField_MultiMaterial.frag samples alphaTextures[0..4],
  // albedoTextures[0..4], normalTextures[0..4], heightTextures[0..4],
  // metalnessTextures[0..4], and roughnessTextures[0..4]. TPBRRenderTechnique maps texture names such
  // as alphaTexture0 or albedoTextures[0] onto those exact uniforms and units.
end;

{ TShadowDepthTechnique }

constructor TShadowDepthTechnique.Create(AShader: TShader; AOwnsShader: Boolean);
begin
  inherited Create(AShader, AOwnsShader);

  State := TRenderTechniqueState.DefaultShadow;
end;

procedure TShadowDepthTechnique.ApplyMaterial(AMaterial: TMaterial);
begin
  // Shadow depth usually does not need material textures.
  // You normally only need modelMatrix + lightSpaceMatrix.
end;

end.
