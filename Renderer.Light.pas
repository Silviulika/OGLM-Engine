unit Renderer.Light;

interface

uses
  System.SysUtils, System.Classes, System.Math, Neslib.FastMath, Renderer.Shader;

type
  TLightType = (ltDirectional, ltPoint, ltSpot);
  TOnApplyShaderLight = procedure(Shader: TShader; Index: Integer) of Object;

  TLight = class
  private
    fEnabled: Boolean;
    fLightType: TLightType;

    // Colours
    fAmbient: TVector3;   // ambient contribution
    fDiffuse: TVector3;   // diffuse / radiance colour
    fSpecular: TVector3;  // specular colour (if needed)

    // Geometric properties
    fPosition: TVector3;  // world position (point / spot)
    fDirection: TVector3; // direction (directional / spot), normalized
    fUseTarget: Boolean;
    fTargetPosition: TVector3;

    // Attenuation (point / spot)
    fConstAtten: Single;
    fLinearAtten: Single;
    fQuadAtten: Single;

    // Spot light specific
    fSpotCutoff: Single;   // angle in radians (outer cone)
    fSpotExponent: Single; // falloff exponent (inner/outer edge sharpness)

    fCastShadows: Boolean;
    fShadowStrength: Single;

    fOnApplyShaderLight: TOnApplyShaderLight;

    fName: String;

    // Helper: normalise direction when set
    procedure SetDirection(const Value: TVector3);
    procedure SetLightType(const Value: TLightType);
  public
    constructor Create;

    // -----------------------------------------------------------------
    // Assign: copies all light properties from another TLight instance.
    // The OnApplyShaderLight event is NOT copied.
    // -----------------------------------------------------------------
    procedure Assign(aLight: TLight);
    procedure SaveToStream(Stream: TStream);
    procedure LoadFromStream(Stream: TStream; SceneVersion: Integer = 3);

    // Convenience setup methods
    procedure SetupDirectional(const ADirection: TVector3; const ARadiance: TVector3);
    procedure SetupPoint(const APosition: TVector3; const ARadiance: TVector3;
      AConstAtten: Single = 1.0; ALinearAtten: Single = 0.0; AQuadAtten: Single = 0.0);
    procedure SetupSpot(const APosition: TVector3; const ADirection: TVector3;
      const ARadiance: TVector3; ASpotCutoffDegrees: Single; ASpotExponent: Single = 1.0;
      AConstAtten: Single = 1.0; ALinearAtten: Single = 0.0; AQuadAtten: Single = 0.0);

    function ResolveTargetDirection(out ADirection: TVector3): Boolean;
    procedure Progress(aShader: TShader; aIndex: Integer);

    // Upload uniforms to a shader for a given light index
    // Assumes shader uses a struct array named "lights[]" with fields:
    //   int type;           (0 = directional, 1 = point, 2 = spot)
    //   vec3 ambient;       (optional)
    //   vec3 diffuse;
    //   vec3 specular;
    //   vec3 position;
    //   vec3 direction;
    //   float constantAttenuation;
    //   float linearAttenuation;
    //   float quadraticAttenuation;
    //   float spotCutoff;    (cosine of cutoff angle)
    //   float spotExponent;
    // If your shader uses different naming, adjust the method or add parameters.
    //procedure ApplyToShader(Shader: TShader; Index: Integer);

    // Properties
    property Enabled: Boolean read fEnabled write fEnabled;
    property LightType: TLightType read fLightType write SetLightType;
    property Ambient: TVector3 read fAmbient write fAmbient;
    property Diffuse: TVector3 read fDiffuse write fDiffuse;
    property Specular: TVector3 read fSpecular write fSpecular;
    property Position: TVector3 read fPosition write fPosition;
    property Direction: TVector3 read fDirection write SetDirection;
    property UseTarget: Boolean read fUseTarget write fUseTarget;
    property TargetPosition: TVector3 read fTargetPosition write fTargetPosition;
    property ConstantAttenuation: Single read fConstAtten write fConstAtten;
    property LinearAttenuation: Single read fLinearAtten write fLinearAtten;
    property QuadraticAttenuation: Single read fQuadAtten write fQuadAtten;
    property SpotCutoff: Single read fSpotCutoff write fSpotCutoff;        // radians
    property SpotExponent: Single read fSpotExponent write fSpotExponent;
    property CastShadows: Boolean read fCastShadows write fCastShadows;
    property ShadowStrength: Single read fShadowStrength write fShadowStrength;
    property Name: String read fName write fName;

    property OnApplyShaderLight: TOnApplyShaderLight read fOnApplyShaderLight write fOnApplyShaderLight;
  end;

implementation

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
begin
  Stream.ReadBuffer(Len, SizeOf(Len));
  if Len < 0 then
    raise Exception.Create('Invalid string length in light stream.');
  SetLength(Result, Len);
  if Len > 0 then
    Stream.ReadBuffer(Result[1], Len * SizeOf(Char));
end;
{ TLight }

constructor TLight.Create;
begin
  inherited Create;
  fEnabled := True;
  fLightType := ltDirectional;
  fAmbient := Vector3(0.0, 0.0, 0.0);
  fDiffuse := Vector3(1.0, 1.0, 1.0);
  fSpecular := Vector3(1.0, 1.0, 1.0);
  fPosition := Vector3(0.0, 0.0, 0.0);
  fDirection := Vector3(0.0, -1.0, 0.0); // default downward
  fUseTarget := True;
  fTargetPosition := Vector3(0.0, 0.0, 0.0);
  fConstAtten := 1.0;
  fLinearAtten := 0.0;
  fQuadAtten := 0.0;
  fSpotCutoff := Pi / 2;   // 90 degrees
  fSpotExponent := 1.0;
  fCastShadows := True;
  fShadowStrength := 0.75;
end;

// ---------------------------------------------------------------------------
// TLight.Assign
// ---------------------------------------------------------------------------
procedure TLight.Assign(aLight: TLight);
begin
  if aLight = Self then Exit;

  fEnabled := aLight.fEnabled;
  fLightType := aLight.fLightType;
  fAmbient := aLight.fAmbient;
  fDiffuse := aLight.fDiffuse;
  fSpecular := aLight.fSpecular;
  fPosition := aLight.fPosition;
  fDirection := aLight.fDirection;
  fUseTarget := aLight.fUseTarget;
  fTargetPosition := aLight.fTargetPosition;
  fConstAtten := aLight.fConstAtten;
  fLinearAtten := aLight.fLinearAtten;
  fQuadAtten := aLight.fQuadAtten;
  fSpotCutoff := aLight.fSpotCutoff;
  fSpotExponent := aLight.fSpotExponent;
  fCastShadows := aLight.fCastShadows;
  fShadowStrength := aLight.fShadowStrength;
  fName := aLight.fName;
  // Do NOT copy the event handler (fOnApplyShaderLight)
end;

procedure TLight.SaveToStream(Stream: TStream);
var
  LightTypeValue: Integer;
begin
  Stream.WriteBuffer(fEnabled, SizeOf(fEnabled));
  LightTypeValue := Ord(fLightType);
  Stream.WriteBuffer(LightTypeValue, SizeOf(LightTypeValue));
  Stream.WriteBuffer(fAmbient, SizeOf(fAmbient));
  Stream.WriteBuffer(fDiffuse, SizeOf(fDiffuse));
  Stream.WriteBuffer(fSpecular, SizeOf(fSpecular));
  Stream.WriteBuffer(fPosition, SizeOf(fPosition));
  Stream.WriteBuffer(fDirection, SizeOf(fDirection));
  Stream.WriteBuffer(fConstAtten, SizeOf(fConstAtten));
  Stream.WriteBuffer(fLinearAtten, SizeOf(fLinearAtten));
  Stream.WriteBuffer(fQuadAtten, SizeOf(fQuadAtten));
  Stream.WriteBuffer(fSpotCutoff, SizeOf(fSpotCutoff));
  Stream.WriteBuffer(fSpotExponent, SizeOf(fSpotExponent));
  Stream.WriteBuffer(fCastShadows, SizeOf(fCastShadows));
  Stream.WriteBuffer(fShadowStrength, SizeOf(fShadowStrength));
  WriteStringToStream(Stream, fName);
  Stream.WriteBuffer(fUseTarget, SizeOf(fUseTarget));
  Stream.WriteBuffer(fTargetPosition, SizeOf(fTargetPosition));
end;

procedure TLight.LoadFromStream(Stream: TStream; SceneVersion: Integer);
var
  LightTypeValue: Integer;
begin
  Stream.ReadBuffer(fEnabled, SizeOf(fEnabled));
  Stream.ReadBuffer(LightTypeValue, SizeOf(LightTypeValue));
  if (LightTypeValue < Ord(Low(TLightType))) or (LightTypeValue > Ord(High(TLightType))) then
    raise Exception.Create('Invalid light type in scene stream.');
  fLightType := TLightType(LightTypeValue);
  Stream.ReadBuffer(fAmbient, SizeOf(fAmbient));
  Stream.ReadBuffer(fDiffuse, SizeOf(fDiffuse));
  Stream.ReadBuffer(fSpecular, SizeOf(fSpecular));
  Stream.ReadBuffer(fPosition, SizeOf(fPosition));
  Stream.ReadBuffer(fDirection, SizeOf(fDirection));
  Stream.ReadBuffer(fConstAtten, SizeOf(fConstAtten));
  Stream.ReadBuffer(fLinearAtten, SizeOf(fLinearAtten));
  Stream.ReadBuffer(fQuadAtten, SizeOf(fQuadAtten));
  Stream.ReadBuffer(fSpotCutoff, SizeOf(fSpotCutoff));
  Stream.ReadBuffer(fSpotExponent, SizeOf(fSpotExponent));
  Stream.ReadBuffer(fCastShadows, SizeOf(fCastShadows));
  Stream.ReadBuffer(fShadowStrength, SizeOf(fShadowStrength));
  fName := ReadStringFromStream(Stream);
  if SceneVersion >= 3 then
  begin
    Stream.ReadBuffer(fUseTarget, SizeOf(fUseTarget));
    Stream.ReadBuffer(fTargetPosition, SizeOf(fTargetPosition));
  end
  else
  begin
    fUseTarget := True;
    fTargetPosition := Vector3(0.0, 0.0, 0.0);
  end;
end;
procedure TLight.SetDirection(const Value: TVector3);
begin
  fDirection := Value;
  if fDirection.LengthSquared > 1e-6 then
    fDirection.Normalize
  else
    fDirection := Vector3(0.0, -1.0, 0.0);
end;

procedure TLight.SetLightType(const Value: TLightType);
begin
  fLightType := Value;
end;

procedure TLight.SetupDirectional(const ADirection: TVector3; const ARadiance: TVector3);
begin
  fLightType := ltDirectional;
  Direction := ADirection;
  fDiffuse := ARadiance;
  // Ambient and specular can be left at defaults or set separately
end;

procedure TLight.SetupPoint(const APosition: TVector3; const ARadiance: TVector3;
  AConstAtten, ALinearAtten, AQuadAtten: Single);
begin
  fLightType := ltPoint;
  fPosition := APosition;
  fDiffuse := ARadiance;
  fConstAtten := AConstAtten;
  fLinearAtten := ALinearAtten;
  fQuadAtten := AQuadAtten;
end;

procedure TLight.SetupSpot(const APosition, ADirection: TVector3;
  const ARadiance: TVector3; ASpotCutoffDegrees, ASpotExponent: Single;
  AConstAtten, ALinearAtten, AQuadAtten: Single);
begin
  fLightType := ltSpot;
  fPosition := APosition;
  Direction := ADirection;
  fDiffuse := ARadiance;
  fSpotCutoff := DegToRad(ASpotCutoffDegrees);
  fSpotExponent := ASpotExponent;
  fConstAtten := AConstAtten;
  fLinearAtten := ALinearAtten;
  fQuadAtten := AQuadAtten;
end;

function TLight.ResolveTargetDirection(out ADirection: TVector3): Boolean;
begin
  ADirection := fTargetPosition - fPosition;
  Result := ADirection.LengthSquared > 1e-6;
  if not Result then
    Exit;

  ADirection.Normalize;
end;

procedure TLight.Progress(aShader: TShader; aIndex: Integer);
begin
  if Assigned(fOnApplyShaderLight) then
    fOnApplyShaderLight(aShader, aIndex);
end;

{procedure TLight.ApplyToShader(Shader: TShader; Index: Integer);
var
  Prefix: string;
  TypeInt: Integer;
  CosCutoff: Single;
begin
  if not Assigned(Shader) then
    Exit;

  Prefix := Format('lights[%d].', [Index]);

  // Light type: 0 = directional, 1 = point, 2 = spot
  case fLightType of
    ltDirectional: TypeInt := 0;
    ltPoint:       TypeInt := 1;
    ltSpot:        TypeInt := 2;
  else
    TypeInt := 0;
  end;

  Shader.SetUniform(Prefix + 'type', TypeInt);

  Shader.SetUniform(Prefix + 'ambient',  fAmbient);
  Shader.SetUniform(Prefix + 'diffuse',  fDiffuse);
  Shader.SetUniform(Prefix + 'specular', fSpecular);
  Shader.SetUniform(Prefix + 'position', fPosition);
  Shader.SetUniform(Prefix + 'direction', fDirection);
  Shader.SetUniform(Prefix + 'constantAttenuation',  fConstAtten);
  Shader.SetUniform(Prefix + 'linearAttenuation',    fLinearAtten);
  Shader.SetUniform(Prefix + 'quadraticAttenuation', fQuadAtten);

  // For spot light, also pass the cosine of cutoff angle (GPU side will compare dot product)
  CosCutoff := Cos(fSpotCutoff);
  Shader.SetUniform(Prefix + 'spotCutoff', CosCutoff);
  Shader.SetUniform(Prefix + 'spotExponent', fSpotExponent);
end;}

end.
