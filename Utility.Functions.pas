unit Utility.Functions;

interface

uses
  dglOpenGL, Neslib.FastMath, System.Math, Engine.Types;

function CopySign(const X, Y: Single): Single; overload;
function CopySign(const X, Y: Double): Double; overload;
function CopySign(const X, Y: Extended): Extended; overload;
function Clamp(const Value, Min, Max: Single): Single; inline;


function UnProject(winX, winY, winZ: Single; const modelview, projection: TMatrix4; const viewport: array of GLint): TVector3;
procedure ScreenToWorldRay(X, Y, ViewportWidth, ViewportHeight: Integer; const ViewMatrix, ProjMatrix: TMatrix4; out RayOrigin, RayDirection: TVector3);
function IntersectRaySphere(const RayOrigin, RayDir: TVector3; const SphereCenter: TVector3; SphereRadius: Single; out t: Single): Boolean;

function RayIntersectsRing(const RayOrigin, RayDir, Center, AxisDir: TVector3; MajorRadius, TubeRadius: Single; out t: Single): Boolean;
function IntersectRayTriangle(const RayOrigin, RayDir: TVector3; const V0, V1, V2: TVector3; out t: Single; out u, v: Single): Boolean;

function RayIntersectsMesh(const RayOrigin, RayDir: TVector3;
  const Indices: TArray<GLuint>; Vertices: TArray<TVertex>; WorldMatrix: TMatrix4;
  out HitT: Single): Boolean;


function EulerToQuaternion(const EulerRad: TVector3): TQuaternion;
function QuaternionToEuler(const Q: TQuaternion): TVector3;

procedure MatrixToEuler(const M: TMatrix4; out Roll, Pitch, Yaw: Single);

function EulerToQuaternionXYZ(const E: TVector3): TQuaternion;
function QuaternionToEulerXYZ(const Q: TQuaternion): TVector3;

implementation

function CopySign(const X, Y: Single): Single; overload;
begin
  Result := Abs(X) * System.Math.Sign(Y);
end;

function CopySign(const X, Y: Double): Double; overload;
begin
  Result := Abs(X) * Sign(Y);
end;

function CopySign(const X, Y: Extended): Extended; overload;
begin
  Result := Abs(X) * Sign(Y);
end;

function Clamp(const Value, Min, Max: Single): Single;
begin
  // Inline assignment
  if Value < Min then
    Result := Min
  else if Value > Max then
    Result := Max
  else
    Result := Value;
end;

function UnProject(winX, winY, winZ: Single; const modelview, projection: TMatrix4; const viewport: array of GLint): TVector3;
var
  mat, inv: TMatrix4;
  inVec, outVec: TVector4;
begin
  // Convert screen to normalized device coordinates (NDC)
  inVec.X := (winX - viewport[0]) / viewport[2] * 2.0 - 1.0;
  inVec.Y := (winY - viewport[1]) / viewport[3] * 2.0 - 1.0;
  inVec.Z := winZ * 2.0 - 1.0;
  inVec.W := 1.0;

  // Compute inverse of (projection * modelview)
  mat := projection * modelview;
  inv := mat.Inverse;

  outVec := inv * inVec;
  if outVec.W <> 0 then
    outVec := outVec / outVec.W;

  Result := Vector3(outVec.X, outVec.Y, outVec.Z);
end;

procedure ScreenToWorldRay(X, Y, ViewportWidth, ViewportHeight: Integer; const ViewMatrix, ProjMatrix: TMatrix4; out RayOrigin, RayDirection: TVector3);
var
  Viewport: array[0..3] of GLint;
  NearPoint, FarPoint: TVector3;
begin
  Viewport[0] := 0;
  Viewport[1] := 0;
  Viewport[2] := ViewportWidth;
  Viewport[3] := ViewportHeight;
  // Flip Y
  Y := ViewportHeight - Y;
  NearPoint := UnProject(X, Y, 0, ViewMatrix, ProjMatrix, Viewport);
  FarPoint  := UnProject(X, Y, 1, ViewMatrix, ProjMatrix, Viewport);
  RayOrigin := NearPoint;
  RayDirection := (FarPoint - NearPoint).Normalize;
end;

function IntersectRaySphere(const RayOrigin, RayDir: TVector3; const SphereCenter: TVector3; SphereRadius: Single; out t: Single): Boolean;
var
  OC: TVector3;
  b, c, disc: Single;
begin
  OC := RayOrigin - SphereCenter;
  b := 2.0 * RayDir.Dot(OC);
  c := OC.Dot(OC) - SphereRadius * SphereRadius;
  disc := b * b - 4.0 * c;
  if disc < 0 then
    Exit(False);
  disc := Sqrt(disc);
  t := (-b - disc) * 0.5;
  if t < 0 then
    t := (-b + disc) * 0.5;
  Result := t >= 0;
end;

function RayIntersectsRing(const RayOrigin, RayDir, Center, AxisDir: TVector3; MajorRadius, TubeRadius: Single; out t: Single): Boolean;
var
  PlaneNormal: TVector3;
  Denom, D: Single;
  HitPoint, ToCenter, ProjPoint: TVector3;
  DistFromCenter, DistToCircle: Single;
begin
  Result := False;
  PlaneNormal := AxisDir.Normalize;
  Denom := RayDir.Dot(PlaneNormal);
  if Abs(Denom) < 1e-6 then Exit; // ray parallel to ring plane

  D := (Center - RayOrigin).Dot(PlaneNormal) / Denom;
  if D <= 0 then Exit;  // intersection behind ray

  HitPoint := RayOrigin + RayDir * D;
  ToCenter := HitPoint - Center;
  // Project on to the ring plane (remove component along plane normal)
  ProjPoint := ToCenter - PlaneNormal * ToCenter.Dot(PlaneNormal);
  DistFromCenter := ProjPoint.Length;
  DistToCircle := Abs(DistFromCenter - MajorRadius);
  if DistToCircle <= TubeRadius then
  begin
    t := D;
    Result := True;
  end;
end;

function IntersectRayTriangle(const RayOrigin, RayDir: TVector3; const V0, V1, V2: TVector3; out t: Single; out u, v: Single): Boolean;
var
  Edge1, Edge2, H, S, Q: TVector3;
  A, F, Epsilon: Single;
begin
  Epsilon := 1e-6;
  Edge1 := V1 - V0;
  Edge2 := V2 - V0;
  H := RayDir.Cross(Edge2);
  A := Edge1.Dot(H);
  if (A > -Epsilon) and (A < Epsilon) then Exit(False);
  F := 1 / A;
  S := RayOrigin - V0;
  u := F * (S.Dot(H));
  if (u < 0) or (u > 1) then Exit(False);
  Q := S.Cross(Edge1);
  v := F * (RayDir.Dot(Q));
  if (v < 0) or (u + v > 1) then Exit(False);
  t := F * (Edge2.Dot(Q));
  Result := (t > Epsilon);
end;

function RayIntersectsMesh(const RayOrigin, RayDir: TVector3;
  const Indices: TArray<GLuint>; Vertices: TArray<TVertex>; WorldMatrix: TMatrix4;
  out HitT: Single): Boolean;
var
  i: Integer;
  WorldMat: TMatrix4;
  v0, v1, v2: TVector3;
  t, u, v: Single;
  bestT: Single;
begin
  Result := False;
  bestT := MaxSingle;
  if (Indices = nil) or (Vertices = nil) then
    Exit;

  WorldMat := WorldMatrix;  // the TBaseSceneObject that owns this mesh

  i := 0;
  while i < Length(Indices) do
  begin
    // Transform each vertex to world space
    v0 := Vector3(WorldMat * Vector4(Vertices[Indices[i  ]].Position, 1));
    v1 := Vector3(WorldMat * Vector4(Vertices[Indices[i+1]].Position, 1));
    v2 := Vector3(WorldMat * Vector4(Vertices[Indices[i+2]].Position, 1));

    if IntersectRayTriangle(RayOrigin, RayDir, v0, v1, v2, t, u, v) then
      if t < bestT then
      begin
        bestT := t;
        Result := True;
      end;
    Inc(i, 3);
  end;
  if Result then
    HitT := bestT;
end;

// Converts object Euler angles (X=roll, Y=pitch, Z=yaw) to a quaternion
function EulerToQuaternion(const EulerRad: TVector3): TQuaternion;
begin
  // FastMath.Init expects (yaw, pitch, roll)
  Result.Init(EulerRad.Z, EulerRad.Y, EulerRad.X);
end;

function QuaternionToEuler(const Q: TQuaternion): TVector3;
var
  NormQ: TQuaternion;
  SinRCosP, CosRCosP, SinP, SinYCosP, CosYCosP: Single;
begin
  // Normalize the quaternion to avoid numerical issues
  NormQ := Q.Normalize;

  // Roll (X-axis)
  SinRCosP := 2 * (NormQ.W * NormQ.X + NormQ.Y * NormQ.Z);
  CosRCosP := 1 - 2 * (NormQ.X * NormQ.X + NormQ.Y * NormQ.Y);
  Result.X := System.Math.ArcTan2(SinRCosP, CosRCosP);

  // Pitch (Y-axis) - clamp SinP to valid range
  SinP := 2 * (NormQ.W * NormQ.Y - NormQ.Z * NormQ.X);
  if SinP > 1 then
    SinP := 1
  else if SinP < -1 then
    SinP := -1;
  Result.Y := System.Math.ArcSin(SinP);

  // Yaw (Z-axis)
  SinYCosP := 2 * (NormQ.W * NormQ.Z + NormQ.X * NormQ.Y);
  CosYCosP := 1 - 2 * (NormQ.Y * NormQ.Y + NormQ.Z * NormQ.Z);
  Result.Z := System.Math.ArcTan2(SinYCosP, CosYCosP);
end;

procedure MatrixToEuler(const M: TMatrix4; out Roll, Pitch, Yaw: Single);
begin
  // Extract from rotation matrix (assuming XYZ order)
  Pitch := System.Math.ArcSin(M[2,0]);  // M[2,0] is sin(pitch)
  if Abs(Pitch) < Pi/2 - 0.001 then
  begin
    Roll := ArcTan2(-M[2,1], M[2,2]);
    Yaw  := ArcTan2(-M[1,0], M[0,0]);
  end
  else
  begin
    // Gimbal lock case
    Roll := System.Math.ArcTan2(M[1,2], M[1,1]);
    Yaw  := 0;
  end;
end;

function EulerToQuaternionXYZ(const E: TVector3): TQuaternion;
var
  Qx, Qy, Qz: TQuaternion;
begin
  Qx.Init(Vector3(1,0,0), E.X); // roll
  Qy.Init(Vector3(0,1,0), E.Y); // pitch
  Qz.Init(Vector3(0,0,1), E.Z); // yaw
  // Multiply in the order that matches the matrix:
  // Matrix does RotX * RotY * RotZ (column-major) => applies Z first, then Y, then X.
  // So quaternion = Qx * Qy * Qz
  Result := Qx * Qy * Qz;
end;

function QuaternionToEulerXYZ(const Q: TQuaternion): TVector3;
var
  N: TQuaternion;
  M: TMatrix4;
  R, P, Y: Single;
  SinPitch: Single;
begin
  // A non-unit quaternion can produce matrix terms just outside [-1, 1].
  // Normalize first and clamp the ArcSin input to prevent NaN values.
  N := Q.Normalize;
  M := N.ToMatrix;

  SinPitch := EnsureRange(M[2,0], -1.0, 1.0);
  P := System.Math.ArcSin(SinPitch);

  if Abs(SinPitch) < 1.0 - 0.000001 then
  begin
    R := System.Math.ArcTan2(-M[2,1], M[2,2]);
    Y := System.Math.ArcTan2(-M[1,0], M[0,0]);
  end
  else
  begin
    // Gimbal-lock case: choose one stable equivalent representation.
    R := System.Math.ArcTan2(M[1,2], M[1,1]);
    Y := 0.0;
  end;

  Result := Vector3(R, P, Y); // roll, pitch, yaw in radians
end;

end.
