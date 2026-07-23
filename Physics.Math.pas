unit Physics.Math;

interface

uses
  System.Math,
  Neslib.FastMath;

const
  Q3_R32_MAX: Single = 3.40282346638528860e+38;
  Q3_PI: Single = 3.14159265;

type
  //----------------------------------------------------------------------------
  // TPhysicMat3
  //----------------------------------------------------------------------------
  TPhysicMat3 = record
  public
    ex: TVector3;
    ey: TVector3;
    ez: TVector3;

    constructor Create(a, b, c, d, e, f, g, h, i: Single); overload;
    constructor Create(const x, y, z: TVector3); overload;

    procedure SetValues(a, b, c, d, e, f, g, h, i: Single);
    procedure SetAxisAngle(const axis: TVector3; angle: Single);
    procedure SetRows(const x, y, z: TVector3);

    function Axis(index: Integer): TVector3;
    procedure SetAxis(index: Integer; const value: TVector3);
    function Column0: TVector3;
    function Column1: TVector3;
    function Column2: TVector3;

    class operator Add(const a, b: TPhysicMat3): TPhysicMat3;
    class operator Subtract(const a, b: TPhysicMat3): TPhysicMat3;
    class operator Multiply(const a, b: TPhysicMat3): TPhysicMat3; overload;
    class operator Multiply(const a: TPhysicMat3; const v: TVector3): TVector3; overload;
    class operator Multiply(const a: TPhysicMat3; f: Single): TPhysicMat3; overload;
  end;

  //----------------------------------------------------------------------------
  // TPhysicQuaternion
  //----------------------------------------------------------------------------
  TPhysicQuaternion = record
  public
    x: Single;
    y: Single;
    z: Single;
    w: Single;

    constructor Create(a, b, c, d: Single); overload;
    constructor Create(const axis: TVector3; radians: Single); overload;

    procedure SetAxisAngle(const axis: TVector3; radians: Single);
    procedure ToAxisAngle(out axis: TVector3; out angle: Single);
    procedure Integrate(const dv: TVector3; dt: Single);
    function ToMat3: TPhysicMat3;

    class operator Multiply(const a, b: TPhysicQuaternion): TPhysicQuaternion;
  end;

  //----------------------------------------------------------------------------
  // TPhysicTransform
  //----------------------------------------------------------------------------
  TPhysicTransform = record
  public
    position: TVector3;
    rotation: TPhysicMat3;
  end;

function PhysicVec3(x, y, z: Single): TVector3; inline;
function PhysicVecGet(const v: TVector3; index: Integer): Single; inline;
procedure PhysicVecSet(var v: TVector3; index: Integer; value: Single); inline;
function PhysicDot(const a, b: TVector3): Single; inline;
function PhysicCross(const a, b: TVector3): TVector3; inline;
function PhysicLength(const v: TVector3): Single; inline;
function PhysicLengthSq(const v: TVector3): Single; inline;
function PhysicNormalize(const v: TVector3): TVector3; overload;
function PhysicNormalize(const q: TPhysicQuaternion): TPhysicQuaternion; overload;
function PhysicAbs(a: Single): Single; overload; inline;
function PhysicAbs(const v: TVector3): TVector3; overload; inline;
function PhysicMin(a, b: Integer): Integer; overload; inline;
function PhysicMin(a, b: Single): Single; overload; inline;
function PhysicMin(const a, b: TVector3): TVector3; overload; inline;
function PhysicMax(a, b: Integer): Integer; overload; inline;
function PhysicMax(a, b: Byte): Byte; overload; inline;
function PhysicMax(a, b: Single): Single; overload; inline;
function PhysicMax(const a, b: TVector3): TVector3; overload; inline;
function PhysicMinPerElem(const v: TVector3): Single; inline;
function PhysicMaxPerElem(const v: TVector3): Single; inline;
function PhysicInvert(a: Single): Single; inline;
function PhysicSign(a: Single): Single; inline;
function PhysicClamp(minValue, maxValue, value: Single): Single; inline;
function PhysicClamp01(value: Single): Single; inline;
function PhysicLerp(a, b, t: Single): Single; overload; inline;
function PhysicLerp(const a, b: TVector3; t: Single): TVector3; overload; inline;
function PhysicMul(const a, b: TVector3): TVector3; overload; inline;
function PhysicMul(const tx: TPhysicTransform; const v: TVector3): TVector3; overload; inline;
function PhysicMul(const tx: TPhysicTransform; const scale, v: TVector3): TVector3; overload; inline;
function PhysicMul(const r: TPhysicMat3; const v: TVector3): TVector3; overload; inline;
function PhysicMul(const r, q: TPhysicMat3): TPhysicMat3; overload; inline;
function PhysicMul(const t, u: TPhysicTransform): TPhysicTransform; overload; inline;
function PhysicMulT(const tx: TPhysicTransform; const v: TVector3): TVector3; overload; inline;
function PhysicMulT(const r: TPhysicMat3; const v: TVector3): TVector3; overload; inline;
function PhysicMulT(const r, q: TPhysicMat3): TPhysicMat3; overload; inline;
function PhysicMulT(const t, u: TPhysicTransform): TPhysicTransform; overload; inline;
function PhysicMatGet(const m: TPhysicMat3; row, column: Integer): Single; inline;
procedure PhysicMatSet(var m: TPhysicMat3; row, column: Integer; value: Single); inline;
function PhysicTranspose(const m: TPhysicMat3): TPhysicMat3; inline;
function PhysicDiagonal(a: Single): TPhysicMat3; overload; inline;
function PhysicDiagonal(a, b, c: Single): TPhysicMat3; overload; inline;
function PhysicOuterProduct(const u, v: TVector3): TPhysicMat3; inline;
function PhysicInverse(const m: TPhysicMat3): TPhysicMat3; overload; inline;
function PhysicInverse(const tx: TPhysicTransform): TPhysicTransform; overload; inline;
procedure PhysicIdentity(var v: TVector3); overload; inline;
procedure PhysicIdentity(var m: TPhysicMat3); overload; inline;
procedure PhysicIdentity(var tx: TPhysicTransform); overload; inline;
procedure PhysicZero(var m: TPhysicMat3); inline;

implementation

//============================================================================
// Vector helpers
//============================================================================

function PhysicVec3(x, y, z: Single): TVector3;
begin
  Result.X := x;
  Result.Y := y;
  Result.Z := z;
end;

function PhysicVecGet(const v: TVector3; index: Integer): Single;
begin
  case index of
    0: Result := v.X;
    1: Result := v.Y;
    2: Result := v.Z;
  else
    Result := v.X;
  end;
end;

procedure PhysicVecSet(var v: TVector3; index: Integer; value: Single);
begin
  case index of
    0: v.X := value;
    1: v.Y := value;
    2: v.Z := value;
  end;
end;

function PhysicDot(const a, b: TVector3): Single;
begin
  Result := a.X * b.X + a.Y * b.Y + a.Z * b.Z;
end;

function PhysicCross(const a, b: TVector3): TVector3;
begin
  Result.X := (a.Y * b.Z) - (b.Y * a.Z);
  Result.Y := (b.X * a.Z) - (a.X * b.Z);
  Result.Z := (a.X * b.Y) - (b.X * a.Y);
end;

function PhysicLength(const v: TVector3): Single;
begin
  Result := Sqrt(PhysicLengthSq(v));
end;

function PhysicLengthSq(const v: TVector3): Single;
begin
  Result := v.X * v.X + v.Y * v.Y + v.Z * v.Z;
end;

function PhysicNormalize(const v: TVector3): TVector3;
var
  l: Single;
begin
  l := PhysicLength(v);
  if (l <> 0.0) then
    Result := v * (1.0 / l)
  else
    Result := v;
end;

function PhysicNormalize(const q: TPhysicQuaternion): TPhysicQuaternion;
var
  d: Single;
begin
  Result := q;
  d := q.w * q.w + q.x * q.x + q.y * q.y + q.z * q.z;

  if (d = 0.0) then
    Result.w := 1.0;

  d := 1.0 / Sqrt(d);
  if (d > 1.0e-8) then
  begin
    Result.x := Result.x * d;
    Result.y := Result.y * d;
    Result.z := Result.z * d;
    Result.w := Result.w * d;
  end;
end;

function PhysicAbs(a: Single): Single;
begin
  if (a < 0.0) then
    Result := -a
  else
    Result := a;
end;

function PhysicAbs(const v: TVector3): TVector3;
begin
  Result := PhysicVec3(PhysicAbs(v.X), PhysicAbs(v.Y), PhysicAbs(v.Z));
end;

function PhysicMin(a, b: Integer): Integer;
begin
  if (a < b) then
    Result := a
  else
    Result := b;
end;

function PhysicMin(a, b: Single): Single;
begin
  if (a < b) then
    Result := a
  else
    Result := b;
end;

function PhysicMin(const a, b: TVector3): TVector3;
begin
  Result := PhysicVec3(PhysicMin(a.X, b.X), PhysicMin(a.Y, b.Y), PhysicMin(a.Z, b.Z));
end;

function PhysicMax(a, b: Integer): Integer;
begin
  if (a > b) then
    Result := a
  else
    Result := b;
end;

function PhysicMax(a, b: Byte): Byte;
begin
  if (a > b) then
    Result := a
  else
    Result := b;
end;

function PhysicMax(a, b: Single): Single;
begin
  if (a > b) then
    Result := a
  else
    Result := b;
end;

function PhysicMax(const a, b: TVector3): TVector3;
begin
  Result := PhysicVec3(PhysicMax(a.X, b.X), PhysicMax(a.Y, b.Y), PhysicMax(a.Z, b.Z));
end;

function PhysicMinPerElem(const v: TVector3): Single;
begin
  Result := PhysicMin(v.X, PhysicMin(v.Y, v.Z));
end;

function PhysicMaxPerElem(const v: TVector3): Single;
begin
  Result := PhysicMax(v.X, PhysicMax(v.Y, v.Z));
end;

function PhysicInvert(a: Single): Single;
begin
  if (a <> 0.0) then
    Result := 1.0 / a
  else
    Result := 0.0;
end;

function PhysicSign(a: Single): Single;
begin
  if (a >= 0.0) then
    Result := 1.0
  else
    Result := -1.0;
end;

function PhysicClamp(minValue, maxValue, value: Single): Single;
begin
  if (value < minValue) then
    Result := minValue
  else if (value > maxValue) then
    Result := maxValue
  else
    Result := value;
end;

function PhysicClamp01(value: Single): Single;
begin
  Result := PhysicClamp(0.0, 1.0, value);
end;

function PhysicLerp(a, b, t: Single): Single;
begin
  Result := a * (1.0 - t) + b * t;
end;

function PhysicLerp(const a, b: TVector3; t: Single): TVector3;
begin
  Result := a * (1.0 - t) + b * t;
end;

function PhysicMul(const a, b: TVector3): TVector3;
begin
  Result := PhysicVec3(a.X * b.X, a.Y * b.Y, a.Z * b.Z);
end;

//============================================================================
// TPhysicMat3
//============================================================================

constructor TPhysicMat3.Create(a, b, c, d, e, f, g, h, i: Single);
begin
  SetValues(a, b, c, d, e, f, g, h, i);
end;

constructor TPhysicMat3.Create(const x, y, z: TVector3);
begin
  ex := x;
  ey := y;
  ez := z;
end;

procedure TPhysicMat3.SetValues(a, b, c, d, e, f, g, h, i: Single);
begin
  ex := PhysicVec3(a, b, c);
  ey := PhysicVec3(d, e, f);
  ez := PhysicVec3(g, h, i);
end;

procedure TPhysicMat3.SetAxisAngle(const axis: TVector3; angle: Single);
var
  s, c, x, y, z, xy, yz, zx, t: Single;
begin
  s := Sin(angle);
  c := Cos(angle);
  x := axis.X;
  y := axis.Y;
  z := axis.Z;
  xy := x * y;
  yz := y * z;
  zx := z * x;
  t := 1.0 - c;

  SetValues(
    x * x * t + c, xy * t + z * s, zx * t - y * s,
    xy * t - z * s, y * y * t + c, yz * t + x * s,
    zx * t + y * s, yz * t - x * s, z * z * t + c);
end;

procedure TPhysicMat3.SetRows(const x, y, z: TVector3);
begin
  ex := x;
  ey := y;
  ez := z;
end;

function TPhysicMat3.Axis(index: Integer): TVector3;
begin
  case index of
    0: Result := ex;
    1: Result := ey;
    2: Result := ez;
  else
    Result := ex;
  end;
end;

procedure TPhysicMat3.SetAxis(index: Integer; const value: TVector3);
begin
  case index of
    0: ex := value;
    1: ey := value;
    2: ez := value;
  end;
end;

function TPhysicMat3.Column0: TVector3;
begin
  Result := PhysicVec3(ex.X, ey.X, ez.X);
end;

function TPhysicMat3.Column1: TVector3;
begin
  Result := PhysicVec3(ex.Y, ey.Y, ez.Y);
end;

function TPhysicMat3.Column2: TVector3;
begin
  Result := PhysicVec3(ex.Z, ey.Z, ez.Z);
end;

class operator TPhysicMat3.Add(const a, b: TPhysicMat3): TPhysicMat3;
begin
  Result := TPhysicMat3.Create(a.ex + b.ex, a.ey + b.ey, a.ez + b.ez);
end;

class operator TPhysicMat3.Subtract(const a, b: TPhysicMat3): TPhysicMat3;
begin
  Result := TPhysicMat3.Create(a.ex - b.ex, a.ey - b.ey, a.ez - b.ez);
end;

class operator TPhysicMat3.Multiply(const a, b: TPhysicMat3): TPhysicMat3;
begin
  Result := TPhysicMat3.Create(a * b.ex, a * b.ey, a * b.ez);
end;

class operator TPhysicMat3.Multiply(const a: TPhysicMat3; const v: TVector3): TVector3;
begin
  Result := PhysicVec3(
    a.ex.X * v.X + a.ey.X * v.Y + a.ez.X * v.Z,
    a.ex.Y * v.X + a.ey.Y * v.Y + a.ez.Y * v.Z,
    a.ex.Z * v.X + a.ey.Z * v.Y + a.ez.Z * v.Z);
end;

class operator TPhysicMat3.Multiply(const a: TPhysicMat3; f: Single): TPhysicMat3;
begin
  Result := TPhysicMat3.Create(a.ex * f, a.ey * f, a.ez * f);
end;

//============================================================================
// Matrix helpers
//============================================================================

function PhysicMul(const tx: TPhysicTransform; const v: TVector3): TVector3;
begin
  Result := tx.rotation * v + tx.position;
end;

function PhysicMul(const tx: TPhysicTransform; const scale, v: TVector3): TVector3;
begin
  Result := tx.rotation * PhysicMul(scale, v) + tx.position;
end;

function PhysicMul(const r: TPhysicMat3; const v: TVector3): TVector3;
begin
  Result := r * v;
end;

function PhysicMul(const r, q: TPhysicMat3): TPhysicMat3;
begin
  Result := r * q;
end;

function PhysicMul(const t, u: TPhysicTransform): TPhysicTransform;
begin
  Result.rotation := t.rotation * u.rotation;
  Result.position := t.rotation * u.position + t.position;
end;

function PhysicMulT(const tx: TPhysicTransform; const v: TVector3): TVector3;
begin
  Result := PhysicTranspose(tx.rotation) * (v - tx.position);
end;

function PhysicMulT(const r: TPhysicMat3; const v: TVector3): TVector3;
begin
  Result := PhysicTranspose(r) * v;
end;

function PhysicMulT(const r, q: TPhysicMat3): TPhysicMat3;
begin
  Result := PhysicTranspose(r) * q;
end;

function PhysicMulT(const t, u: TPhysicTransform): TPhysicTransform;
begin
  Result.rotation := PhysicMulT(t.rotation, u.rotation);
  Result.position := PhysicMulT(t.rotation, u.position - t.position);
end;

function PhysicMatGet(const m: TPhysicMat3; row, column: Integer): Single;
begin
  Result := PhysicVecGet(m.Axis(row), column);
end;

procedure PhysicMatSet(var m: TPhysicMat3; row, column: Integer; value: Single);
var
  v: TVector3;
begin
  v := m.Axis(row);
  PhysicVecSet(v, column, value);
  m.SetAxis(row, v);
end;

function PhysicTranspose(const m: TPhysicMat3): TPhysicMat3;
begin
  Result := TPhysicMat3.Create(
    m.ex.X, m.ey.X, m.ez.X,
    m.ex.Y, m.ey.Y, m.ez.Y,
    m.ex.Z, m.ey.Z, m.ez.Z);
end;

function PhysicDiagonal(a: Single): TPhysicMat3;
begin
  Result := TPhysicMat3.Create(
    a,   0.0, 0.0,
    0.0, a,   0.0,
    0.0, 0.0, a);
end;

function PhysicDiagonal(a, b, c: Single): TPhysicMat3;
begin
  Result := TPhysicMat3.Create(
    a,   0.0, 0.0,
    0.0, b,   0.0,
    0.0, 0.0, c);
end;

function PhysicOuterProduct(const u, v: TVector3): TPhysicMat3;
var
  a, b, c: TVector3;
begin
  a := v * u.X;
  b := v * u.Y;
  c := v * u.Z;

  Result := TPhysicMat3.Create(
    a.X, a.Y, a.Z,
    b.X, b.Y, b.Z,
    c.X, c.Y, c.Z);
end;

function PhysicInverse(const m: TPhysicMat3): TPhysicMat3;
var
  tmp0, tmp1, tmp2: TVector3;
  detinv: Single;
begin
  tmp0 := PhysicCross(m.ey, m.ez);
  tmp1 := PhysicCross(m.ez, m.ex);
  tmp2 := PhysicCross(m.ex, m.ey);
  detinv := 1.0 / PhysicDot(m.ez, tmp2);

  Result := TPhysicMat3.Create(
    tmp0.X * detinv, tmp1.X * detinv, tmp2.X * detinv,
    tmp0.Y * detinv, tmp1.Y * detinv, tmp2.Y * detinv,
    tmp0.Z * detinv, tmp1.Z * detinv, tmp2.Z * detinv);
end;

function PhysicInverse(const tx: TPhysicTransform): TPhysicTransform;
begin
  Result.rotation := PhysicTranspose(tx.rotation);
  Result.position := Result.rotation * (tx.position * -1.0);
end;

procedure PhysicIdentity(var v: TVector3);
begin
  v := PhysicVec3(0.0, 0.0, 0.0);
end;

procedure PhysicIdentity(var m: TPhysicMat3);
begin
  m := TPhysicMat3.Create(
    1.0, 0.0, 0.0,
    0.0, 1.0, 0.0,
    0.0, 0.0, 1.0);
end;

procedure PhysicIdentity(var tx: TPhysicTransform);
begin
  PhysicIdentity(tx.position);
  PhysicIdentity(tx.rotation);
end;

procedure PhysicZero(var m: TPhysicMat3);
begin
  m := TPhysicMat3.Create(
    0.0, 0.0, 0.0,
    0.0, 0.0, 0.0,
    0.0, 0.0, 0.0);
end;

//============================================================================
// TPhysicQuaternion
//============================================================================

constructor TPhysicQuaternion.Create(a, b, c, d: Single);
begin
  x := a;
  y := b;
  z := c;
  w := d;
end;

constructor TPhysicQuaternion.Create(const axis: TVector3; radians: Single);
begin
  SetAxisAngle(axis, radians);
end;

procedure TPhysicQuaternion.SetAxisAngle(const axis: TVector3; radians: Single);
var
  halfAngle, s: Single;
begin
  halfAngle := 0.5 * radians;
  s := Sin(halfAngle);
  x := s * axis.X;
  y := s * axis.Y;
  z := s * axis.Z;
  w := Cos(halfAngle);
end;

procedure TPhysicQuaternion.ToAxisAngle(out axis: TVector3; out angle: Single);
var
  l: Single;
begin
  angle := 2.0 * System.Math.ArcCos(System.Math.EnsureRange(w, -1.0, 1.0));
  l := Sqrt(System.Math.Max(0.0, 1.0 - w * w));

  if (l = 0.0) then
    axis := PhysicVec3(0.0, 0.0, 0.0)
  else
  begin
    l := 1.0 / l;
    axis := PhysicVec3(x * l, y * l, z * l);
  end;
end;

procedure TPhysicQuaternion.Integrate(const dv: TVector3; dt: Single);
var
  q: TPhysicQuaternion;
begin
  q := TPhysicQuaternion.Create(dv.X * dt, dv.Y * dt, dv.Z * dt, 0.0);
  q := q * Self;

  x := x + q.x * 0.5;
  y := y + q.y * 0.5;
  z := z + q.z * 0.5;
  w := w + q.w * 0.5;

  Self := PhysicNormalize(Self);
end;

function TPhysicQuaternion.ToMat3: TPhysicMat3;
var
  qx2, qy2, qz2: Single;
  qxqx2, qxqy2, qxqz2, qxqw2: Single;
  qyqy2, qyqz2, qyqw2: Single;
  qzqz2, qzqw2: Single;
begin
  qx2 := x + x;
  qy2 := y + y;
  qz2 := z + z;
  qxqx2 := x * qx2;
  qxqy2 := x * qy2;
  qxqz2 := x * qz2;
  qxqw2 := w * qx2;
  qyqy2 := y * qy2;
  qyqz2 := y * qz2;
  qyqw2 := w * qy2;
  qzqz2 := z * qz2;
  qzqw2 := w * qz2;

  Result := TPhysicMat3.Create(
    PhysicVec3(1.0 - qyqy2 - qzqz2, qxqy2 + qzqw2, qxqz2 - qyqw2),
    PhysicVec3(qxqy2 - qzqw2, 1.0 - qxqx2 - qzqz2, qyqz2 + qxqw2),
    PhysicVec3(qxqz2 + qyqw2, qyqz2 - qxqw2, 1.0 - qxqx2 - qyqy2));
end;

class operator TPhysicQuaternion.Multiply(const a, b: TPhysicQuaternion): TPhysicQuaternion;
begin
  Result := TPhysicQuaternion.Create(
    a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
    a.w * b.y + a.y * b.w + a.z * b.x - a.x * b.z,
    a.w * b.z + a.z * b.w + a.x * b.y - a.y * b.x,
    a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z);
end;

end.
