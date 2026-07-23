unit Renderer.SkyDome;

interface

uses
  System.SysUtils, System.Math, System.Classes,
  dglOpenGL, Neslib.FastMath,
  Engine.Paths, Renderer.Shader;

type
  TSkyDome = class
  private
    fEnabled: Boolean;
    fShader: TShader;
    fVertexShaderFile: string;
    fFragmentShaderFile: string;
    fVAO: GLuint;
    fVBO: GLuint;
    fEBO: GLuint;
    fIndexCount: Integer;
    fSlices: Integer;
    fStacks: Integer;
    fRadius: Single;
    fTime: Single;
    fAnimateClouds: Boolean;
    fTwinkleStars: Boolean;
    fGeometryDirty: Boolean;

    fTopColor: TVector4;
    fHorizonColor: TVector4;
    fBottomColor: TVector4;
    fNightColor: TVector4;
    fSunColor: TVector4;
    fSunDirection: TVector3;
    fSunSize: Single;
    fSunGlow: Single;
    fSunIntensity: Single;
    fStarIntensity: Single;
    fStarDensity: Single;
    fStarGlare: Single;
    fStarSize: TVector2;

    fCloudsEnabled: Boolean;
    fCloudCoverage: Single;
    fCloudScale: Single;
    fCloudSpeed: Single;
    fCloudOpacity: Single;
    fCloudColor: TVector4;

    procedure DestroyGeometry;
    procedure DestroyShader;
    procedure EnsureGeometry;
    procedure EnsureShader;
    procedure SetSlices(const Value: Integer);
    procedure SetStacks(const Value: Integer);
    procedure SetSunDirection(const Value: TVector3);
    procedure SetStarSize(const Value: TVector2);
  public
    constructor Create;
    destructor Destroy; override;

    procedure LoadShaderFromFile(const VertexFileName, FragmentFileName: string);
    procedure ResetEarthDefaults;
    procedure SaveToStream(Stream: TStream);
    procedure LoadFromStream(Stream: TStream);
    procedure Render(const ViewProjection: TMatrix4; const CameraPosition: TVector3;
      DeltaTime: Single = 0.0);

    property Enabled: Boolean read fEnabled write fEnabled;
    property Radius: Single read fRadius write fRadius;
    property Slices: Integer read fSlices write SetSlices;
    property Stacks: Integer read fStacks write SetStacks;
    property Time: Single read fTime write fTime;
    property AnimateClouds: Boolean read fAnimateClouds write fAnimateClouds;

    property TopColor: TVector4 read fTopColor write fTopColor;
    property HorizonColor: TVector4 read fHorizonColor write fHorizonColor;
    property BottomColor: TVector4 read fBottomColor write fBottomColor;
    property NightColor: TVector4 read fNightColor write fNightColor;
    property SunColor: TVector4 read fSunColor write fSunColor;
    property SunDirection: TVector3 read fSunDirection write SetSunDirection;
    property SunSize: Single read fSunSize write fSunSize;
    property SunGlow: Single read fSunGlow write fSunGlow;
    property SunIntensity: Single read fSunIntensity write fSunIntensity;
    property StarIntensity: Single read fStarIntensity write fStarIntensity;
    property StarDensity: Single read fStarDensity write fStarDensity;
    property StarGlare: Single read fStarGlare write fStarGlare;
    property StarSize: TVector2 read fStarSize write SetStarSize;
    property TwinkleStars: Boolean read fTwinkleStars write fTwinkleStars;

    property CloudsEnabled: Boolean read fCloudsEnabled write fCloudsEnabled;
    property CloudCoverage: Single read fCloudCoverage write fCloudCoverage;
    property CloudScale: Single read fCloudScale write fCloudScale;
    property CloudSpeed: Single read fCloudSpeed write fCloudSpeed;
    property CloudOpacity: Single read fCloudOpacity write fCloudOpacity;
    property CloudColor: TVector4 read fCloudColor write fCloudColor;
  end;

implementation

const
  SKYDOME_STREAM_VERSION = 1;

constructor TSkyDome.Create;
begin
  inherited Create;

  fEnabled := True;
  fVertexShaderFile := TEnginePaths.Shader('SkyDome.vert');
  fFragmentShaderFile := TEnginePaths.Shader('SkyDome.frag');
  fSlices := 64;
  fStacks := 32;
  fRadius := 500.0;
  fGeometryDirty := True;

  ResetEarthDefaults;
end;

destructor TSkyDome.Destroy;
begin
  DestroyGeometry;
  DestroyShader;
  inherited Destroy;
end;

procedure TSkyDome.DestroyGeometry;
begin
  if fEBO <> 0 then
  begin
    glDeleteBuffers(1, @fEBO);
    fEBO := 0;
  end;

  if fVBO <> 0 then
  begin
    glDeleteBuffers(1, @fVBO);
    fVBO := 0;
  end;

  if fVAO <> 0 then
  begin
    glDeleteVertexArrays(1, @fVAO);
    fVAO := 0;
  end;

  fIndexCount := 0;
end;

procedure TSkyDome.DestroyShader;
begin
  if fShader <> nil then
    FreeAndNil(fShader);
end;

procedure TSkyDome.EnsureGeometry;
var
  Vertices: TArray<TVector3>;
  Indices: TArray<Cardinal>;
  Stack: Integer;
  Slice: Integer;
  VertexIndex: Integer;
  IndexIndex: Integer;
  First: Cardinal;
  Second: Cardinal;
  Phi: Single;
  Theta: Single;
  RingRadius: Single;
begin
  if (not fGeometryDirty) and (fVAO <> 0) and (fIndexCount > 0) then
    Exit;

  DestroyGeometry;

  SetLength(Vertices, (fStacks + 1) * (fSlices + 1));
  VertexIndex := 0;
  for Stack := 0 to fStacks do
  begin
    Phi := -Pi * 0.5 + Pi * Stack / fStacks;
    RingRadius := Cos(Phi);

    for Slice := 0 to fSlices do
    begin
      Theta := 2.0 * Pi * Slice / fSlices;
      Vertices[VertexIndex] := Vector3(
        Cos(Theta) * RingRadius,
        Sin(Phi),
        Sin(Theta) * RingRadius);
      Inc(VertexIndex);
    end;
  end;

  SetLength(Indices, fStacks * fSlices * 6);
  IndexIndex := 0;
  for Stack := 0 to fStacks - 1 do
  begin
    for Slice := 0 to fSlices - 1 do
    begin
      First := Cardinal(Stack * (fSlices + 1) + Slice);
      Second := First + Cardinal(fSlices + 1);

      Indices[IndexIndex] := First;
      Inc(IndexIndex);
      Indices[IndexIndex] := Second;
      Inc(IndexIndex);
      Indices[IndexIndex] := First + 1;
      Inc(IndexIndex);

      Indices[IndexIndex] := Second;
      Inc(IndexIndex);
      Indices[IndexIndex] := Second + 1;
      Inc(IndexIndex);
      Indices[IndexIndex] := First + 1;
      Inc(IndexIndex);
    end;
  end;

  fIndexCount := Length(Indices);

  glGenVertexArrays(1, @fVAO);
  glBindVertexArray(fVAO);

  glGenBuffers(1, @fVBO);
  glBindBuffer(GL_ARRAY_BUFFER, fVBO);
  glBufferData(GL_ARRAY_BUFFER, Length(Vertices) * SizeOf(TVector3),
    @Vertices[0], GL_STATIC_DRAW);

  glGenBuffers(1, @fEBO);
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, fEBO);
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, Length(Indices) * SizeOf(Cardinal),
    @Indices[0], GL_STATIC_DRAW);

  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, SizeOf(TVector3), nil);

  glBindVertexArray(0);
  glBindBuffer(GL_ARRAY_BUFFER, 0);

  fGeometryDirty := False;
end;

procedure TSkyDome.EnsureShader;
begin
  if fShader = nil then
    fShader := TShader.Create(fVertexShaderFile, fFragmentShaderFile);
end;

procedure TSkyDome.LoadShaderFromFile(const VertexFileName,
  FragmentFileName: string);
begin
  fVertexShaderFile := VertexFileName;
  fFragmentShaderFile := FragmentFileName;
  DestroyShader;
end;

procedure TSkyDome.SaveToStream(Stream: TStream);
var
  Version: Integer;
begin
  if Stream = nil then
    Exit;

  Version := SKYDOME_STREAM_VERSION;
  Stream.WriteBuffer(Version, SizeOf(Version));

  Stream.WriteBuffer(fEnabled, SizeOf(fEnabled));
  Stream.WriteBuffer(fRadius, SizeOf(fRadius));
  Stream.WriteBuffer(fSlices, SizeOf(fSlices));
  Stream.WriteBuffer(fStacks, SizeOf(fStacks));
  Stream.WriteBuffer(fTime, SizeOf(fTime));
  Stream.WriteBuffer(fAnimateClouds, SizeOf(fAnimateClouds));

  Stream.WriteBuffer(fTopColor, SizeOf(fTopColor));
  Stream.WriteBuffer(fHorizonColor, SizeOf(fHorizonColor));
  Stream.WriteBuffer(fBottomColor, SizeOf(fBottomColor));
  Stream.WriteBuffer(fNightColor, SizeOf(fNightColor));
  Stream.WriteBuffer(fSunColor, SizeOf(fSunColor));
  Stream.WriteBuffer(fSunDirection, SizeOf(fSunDirection));
  Stream.WriteBuffer(fSunSize, SizeOf(fSunSize));
  Stream.WriteBuffer(fSunGlow, SizeOf(fSunGlow));
  Stream.WriteBuffer(fSunIntensity, SizeOf(fSunIntensity));
  Stream.WriteBuffer(fStarIntensity, SizeOf(fStarIntensity));
  Stream.WriteBuffer(fStarDensity, SizeOf(fStarDensity));
  Stream.WriteBuffer(fStarGlare, SizeOf(fStarGlare));
  Stream.WriteBuffer(fStarSize, SizeOf(fStarSize));
  Stream.WriteBuffer(fTwinkleStars, SizeOf(fTwinkleStars));

  Stream.WriteBuffer(fCloudsEnabled, SizeOf(fCloudsEnabled));
  Stream.WriteBuffer(fCloudCoverage, SizeOf(fCloudCoverage));
  Stream.WriteBuffer(fCloudScale, SizeOf(fCloudScale));
  Stream.WriteBuffer(fCloudSpeed, SizeOf(fCloudSpeed));
  Stream.WriteBuffer(fCloudOpacity, SizeOf(fCloudOpacity));
  Stream.WriteBuffer(fCloudColor, SizeOf(fCloudColor));
end;

procedure TSkyDome.LoadFromStream(Stream: TStream);
var
  Version: Integer;
  SlicesValue: Integer;
  StacksValue: Integer;
  SunDirectionValue: TVector3;
  StarSizeValue: TVector2;
begin
  if Stream = nil then
    Exit;

  Stream.ReadBuffer(Version, SizeOf(Version));
  if (Version < 1) or (Version > SKYDOME_STREAM_VERSION) then
    raise Exception.CreateFmt('Unsupported SkyDome stream version: %d.', [Version]);

  ResetEarthDefaults;

  Stream.ReadBuffer(fEnabled, SizeOf(fEnabled));
  Stream.ReadBuffer(fRadius, SizeOf(fRadius));
  Stream.ReadBuffer(SlicesValue, SizeOf(SlicesValue));
  Stream.ReadBuffer(StacksValue, SizeOf(StacksValue));
  Stream.ReadBuffer(fTime, SizeOf(fTime));
  Stream.ReadBuffer(fAnimateClouds, SizeOf(fAnimateClouds));

  Stream.ReadBuffer(fTopColor, SizeOf(fTopColor));
  Stream.ReadBuffer(fHorizonColor, SizeOf(fHorizonColor));
  Stream.ReadBuffer(fBottomColor, SizeOf(fBottomColor));
  Stream.ReadBuffer(fNightColor, SizeOf(fNightColor));
  Stream.ReadBuffer(fSunColor, SizeOf(fSunColor));
  Stream.ReadBuffer(SunDirectionValue, SizeOf(SunDirectionValue));
  Stream.ReadBuffer(fSunSize, SizeOf(fSunSize));
  Stream.ReadBuffer(fSunGlow, SizeOf(fSunGlow));
  Stream.ReadBuffer(fSunIntensity, SizeOf(fSunIntensity));
  Stream.ReadBuffer(fStarIntensity, SizeOf(fStarIntensity));
  Stream.ReadBuffer(fStarDensity, SizeOf(fStarDensity));
  Stream.ReadBuffer(fStarGlare, SizeOf(fStarGlare));
  Stream.ReadBuffer(StarSizeValue, SizeOf(StarSizeValue));
  Stream.ReadBuffer(fTwinkleStars, SizeOf(fTwinkleStars));

  Stream.ReadBuffer(fCloudsEnabled, SizeOf(fCloudsEnabled));
  Stream.ReadBuffer(fCloudCoverage, SizeOf(fCloudCoverage));
  Stream.ReadBuffer(fCloudScale, SizeOf(fCloudScale));
  Stream.ReadBuffer(fCloudSpeed, SizeOf(fCloudSpeed));
  Stream.ReadBuffer(fCloudOpacity, SizeOf(fCloudOpacity));
  Stream.ReadBuffer(fCloudColor, SizeOf(fCloudColor));

  Slices := SlicesValue;
  Stacks := StacksValue;
  SunDirection := SunDirectionValue;
  StarSize := StarSizeValue;
  fRadius := Max(1.0, fRadius);
  fSunSize := Max(0.001, fSunSize);
  fSunGlow := Max(1.0, fSunGlow);
  fSunIntensity := Max(0.0, fSunIntensity);
  fStarIntensity := Max(0.0, fStarIntensity);
  fStarDensity := Max(8.0, fStarDensity);
  fStarGlare := Max(0.0, fStarGlare);
  fCloudCoverage := EnsureRange(fCloudCoverage, 0.0, 1.0);
  fCloudScale := Max(0.01, fCloudScale);
  fCloudOpacity := EnsureRange(fCloudOpacity, 0.0, 1.0);
end;

procedure TSkyDome.Render(const ViewProjection: TMatrix4;
  const CameraPosition: TVector3; DeltaTime: Single);
var
  OldDepthFunc: GLint;
  OldDepthMask: GLboolean;
  OldDepthTestEnabled: GLboolean;
  OldCullEnabled: GLboolean;
  OldBlendEnabled: GLboolean;
begin
  if not fEnabled then
    Exit;

  EnsureShader;
  EnsureGeometry;

  if (fShader = nil) or (fVAO = 0) or (fIndexCount <= 0) then
    Exit;

  if fAnimateClouds then
    fTime := fTime + Max(0.0, DeltaTime);

  glGetIntegerv(GL_DEPTH_FUNC, @OldDepthFunc);
  glGetBooleanv(GL_DEPTH_WRITEMASK, @OldDepthMask);
  OldDepthTestEnabled := glIsEnabled(GL_DEPTH_TEST);
  OldCullEnabled := glIsEnabled(GL_CULL_FACE);
  OldBlendEnabled := glIsEnabled(GL_BLEND);

  glEnable(GL_DEPTH_TEST);
  glDepthFunc(GL_LEQUAL);
  glDepthMask(GL_FALSE);
  glDisable(GL_CULL_FACE);
  glDisable(GL_BLEND);

  fShader.Use;
  fShader.SetUniform('viewProjection', ViewProjection);
  fShader.SetUniform('cameraPosition', CameraPosition);
  fShader.SetUniform('radius', Max(1.0, fRadius));
  fShader.SetUniform('topColor', fTopColor);
  fShader.SetUniform('horizonColor', fHorizonColor);
  fShader.SetUniform('bottomColor', fBottomColor);
  fShader.SetUniform('nightColor', fNightColor);
  fShader.SetUniform('sunColor', fSunColor);
  fShader.SetUniform('sunDirection', fSunDirection);
  fShader.SetUniform('sunSize', Max(0.001, fSunSize));
  fShader.SetUniform('sunGlow', Max(1.0, fSunGlow));
  fShader.SetUniform('sunIntensity', Max(0.0, fSunIntensity));
  fShader.SetUniform('starIntensity', Max(0.0, fStarIntensity));
  fShader.SetUniform('starDensity', Max(8.0, fStarDensity));
  fShader.SetUniform('starGlare', Max(0.0, fStarGlare));
  fShader.SetUniform('starSize', fStarSize);
  fShader.SetUniform('twinkleStars', fTwinkleStars);
  fShader.SetUniform('time', fTime);
  fShader.SetUniform('cloudsEnabled', fCloudsEnabled);
  fShader.SetUniform('cloudCoverage', EnsureRange(fCloudCoverage, 0.0, 1.0));
  fShader.SetUniform('cloudScale', Max(0.01, fCloudScale));
  fShader.SetUniform('cloudSpeed', fCloudSpeed);
  fShader.SetUniform('cloudOpacity', EnsureRange(fCloudOpacity, 0.0, 1.0));
  fShader.SetUniform('cloudColor', fCloudColor);

  glBindVertexArray(fVAO);
  try
    glDrawElements(GL_TRIANGLES, fIndexCount, GL_UNSIGNED_INT, nil);
  finally
    glBindVertexArray(0);
    glDepthFunc(OldDepthFunc);
    glDepthMask(OldDepthMask);
    if OldDepthTestEnabled = GL_TRUE then
      glEnable(GL_DEPTH_TEST)
    else
      glDisable(GL_DEPTH_TEST);
    if OldCullEnabled = GL_TRUE then
      glEnable(GL_CULL_FACE)
    else
      glDisable(GL_CULL_FACE);
    if OldBlendEnabled = GL_TRUE then
      glEnable(GL_BLEND)
    else
      glDisable(GL_BLEND);
  end;
end;

procedure TSkyDome.ResetEarthDefaults;
begin
  fTopColor := Vector4(0.10, 0.34, 0.70, 1.0);
  fHorizonColor := Vector4(0.62, 0.78, 0.95, 1.0);
  fBottomColor := Vector4(0.28, 0.36, 0.42, 1.0);
  fNightColor := Vector4(0.015, 0.025, 0.075, 1.0);
  fSunColor := Vector4(1.0, 0.82, 0.48, 1.0);
  SetSunDirection(Vector3(-0.35, 0.65, -0.45));
  fSunSize := 0.018;
  fSunGlow := 36.0;
  fSunIntensity := 1.25;
  fStarIntensity := 0.75;
  fStarDensity := 220.0;
  fStarGlare := 0.75;
  fStarSize := Vector2(0.045, 0.135);
  fTwinkleStars := True;

  fCloudsEnabled := True;
  fCloudCoverage := 0.34;
  fCloudScale := 1.45;
  fCloudSpeed := 0.018;
  fCloudOpacity := 0.42;
  fCloudColor := Vector4(1.0, 1.0, 1.0, 1.0);
  fAnimateClouds := True;
  fTime := 0.0;
end;

procedure TSkyDome.SetSlices(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := Max(8, Value);
  if fSlices = NewValue then
    Exit;

  fSlices := NewValue;
  fGeometryDirty := True;
end;

procedure TSkyDome.SetStacks(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := Max(4, Value);
  if fStacks = NewValue then
    Exit;

  fStacks := NewValue;
  fGeometryDirty := True;
end;

procedure TSkyDome.SetSunDirection(const Value: TVector3);
begin
  if Value.LengthSquared < 1e-8 then
    fSunDirection := Vector3(-0.35, 0.65, -0.45).Normalize
  else
    fSunDirection := Value.Normalize;
end;

procedure TSkyDome.SetStarSize(const Value: TVector2);
begin
  fStarSize.X := System.Math.Max(0.001, System.Math.Min(Value.X, Value.Y));
  fStarSize.Y := System.Math.Max(fStarSize.X, System.Math.Max(Value.X, Value.Y));
end;

end.
