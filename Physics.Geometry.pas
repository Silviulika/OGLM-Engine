unit Physics.Geometry;

interface

uses
  System.Math,
  Neslib.FastMath,
  Physics.Math;

type
  //----------------------------------------------------------------------------
  // TPhysicAABB
  //----------------------------------------------------------------------------
  TPhysicAABB = record
  public
    min: TVector3;
    max: TVector3;

    function Contains(const other: TPhysicAABB): Boolean; overload;
    function Contains(const point: TVector3): Boolean; overload;
    function SurfaceArea: Single;
  end;

  //----------------------------------------------------------------------------
  // TPhysicHalfSpace
  //----------------------------------------------------------------------------
  TPhysicHalfSpace = record
  public
    normal: TVector3;
    distance: Single;

    constructor Create(const n: TVector3; d: Single);

    procedure SetFromTriangle(const a, b, c: TVector3);
    procedure SetFromNormalAndPoint(const n, p: TVector3);
    function Origin: TVector3;
    function DistanceToPoint(const p: TVector3): Single;
    function Projected(const p: TVector3): TVector3;
  end;

  //----------------------------------------------------------------------------
  // TPhysicRaycastData
  //----------------------------------------------------------------------------
  TPhysicRaycastData = record
  public
    start: TVector3;   // Beginning point of the ray
    dir: TVector3;     // Direction of the ray (normalized)
    t: Single;         // Time specifying ray endpoint

    toi: Single;       // Solved time of impact
    normal: TVector3;  // Surface normal at impact

    procedure SetData(const startPoint, direction: TVector3; endPointTime: Single);
    function GetImpactPoint: TVector3;
  end;

//----------------------------------------------------------------------------
// Utilities
//----------------------------------------------------------------------------
function PhysicCombine(const a, b: TPhysicAABB): TPhysicAABB;
function PhysicAABBToAABB(const a, b: TPhysicAABB): Boolean;
procedure PhysicComputeBasis(const a: TVector3; out b, c: TVector3);

implementation

//============================================================================
// TPhysicAABB
//============================================================================

function TPhysicAABB.Contains(const other: TPhysicAABB): Boolean;
begin
  Result := (other.min.X >= min.X) and (other.min.Y >= min.Y) and (other.min.Z >= min.Z) and
            (other.max.X <= max.X) and (other.max.Y <= max.Y) and (other.max.Z <= max.Z);
end;

function TPhysicAABB.Contains(const point: TVector3): Boolean;
begin
  Result := (point.X >= min.X) and (point.X <= max.X) and
            (point.Y >= min.Y) and (point.Y <= max.Y) and
            (point.Z >= min.Z) and (point.Z <= max.Z);
end;

function TPhysicAABB.SurfaceArea: Single;
var
  dx, dy, dz: Single;
begin
  dx := max.X - min.X;
  dy := max.Y - min.Y;
  dz := max.Z - min.Z;
  Result := 2.0 * (dx * dy + dx * dz + dy * dz);
end;

//============================================================================
// TPhysicHalfSpace
//============================================================================

constructor TPhysicHalfSpace.Create(const n: TVector3; d: Single);
begin
  normal := n;
  distance := d;
end;

procedure TPhysicHalfSpace.SetFromTriangle(const a, b, c: TVector3);
var
  v1: TVector3;
begin
  v1 := b - a;
  normal := PhysicNormalize(PhysicCross(v1, c - a));
  distance := PhysicDot(normal, a);
end;

procedure TPhysicHalfSpace.SetFromNormalAndPoint(const n, p: TVector3);
begin
  normal := PhysicNormalize(n);
  distance := PhysicDot(normal, p);
end;

function TPhysicHalfSpace.Origin: TVector3;
begin
  Result := normal * distance;
end;

function TPhysicHalfSpace.DistanceToPoint(const p: TVector3): Single;
begin
  Result := PhysicDot(normal, p) - distance;
end;

function TPhysicHalfSpace.Projected(const p: TVector3): TVector3;
begin
  Result := p - normal * DistanceToPoint(p);
end;

//============================================================================
// TPhysicRaycastData
//============================================================================

procedure TPhysicRaycastData.SetData(const startPoint, direction: TVector3; endPointTime: Single);
begin
  start := startPoint;
  dir := direction;
  t := endPointTime;
  // toi and normal are left uninitialized (as in C++)
end;

function TPhysicRaycastData.GetImpactPoint: TVector3;
begin
  Result := start + dir * toi;
end;

//============================================================================
// Utilities
//============================================================================

function PhysicCombine(const a, b: TPhysicAABB): TPhysicAABB;
begin
  Result.min := PhysicMin(a.min, b.min);
  Result.max := PhysicMax(a.max, b.max);
end;

function PhysicAABBToAABB(const a, b: TPhysicAABB): Boolean;
begin
  if (a.max.X < b.min.X) or (a.min.X > b.max.X) then
    Exit(False);

  if (a.max.Y < b.min.Y) or (a.min.Y > b.max.Y) then
    Exit(False);

  if (a.max.Z < b.min.Z) or (a.min.Z > b.max.Z) then
    Exit(False);

  Result := True;
end;

procedure PhysicComputeBasis(const a: TVector3; out b, c: TVector3);
begin
  if (PhysicAbs(a.X) >= 0.57735027) then
    b := PhysicVec3(a.Y, -a.X, 0.0)
  else
    b := PhysicVec3(0.0, a.Z, -a.Y);

  b := PhysicNormalize(b);
  c := PhysicCross(a, b);
end;

end.
