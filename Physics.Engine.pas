unit Physics.Engine;

interface

uses
  System.SysUtils,
  Neslib.FastMath,
  Physics.Math,
  Physics.Geometry,
  Physics.Settings;

type
  TPhysicScene = class;
  TPhysicBody = class;
  TPhysicBox = class;
  TPhysicContactConstraint = class;
  TPhysicContactManager = class;

  TPhysicBodyType = (PhysicStaticBody, PhysicDynamicBody, PhysicKinematicBody);

  //----------------------------------------------------------------------------
  // User callbacks
  //----------------------------------------------------------------------------
  TPhysicContactListener = class abstract
  public
    procedure BeginContact(const contact: TPhysicContactConstraint); virtual; abstract;
    procedure EndContact(const contact: TPhysicContactConstraint); virtual; abstract;
  end;

  TPhysicQueryCallback = class abstract
  public
    function ReportShape(box: TPhysicBox): Boolean; virtual; abstract;
  end;

  //----------------------------------------------------------------------------
  // Mass and shape definitions
  //----------------------------------------------------------------------------
  TPhysicMassData = record
  public
    inertia: TPhysicMat3;
    center: TVector3;
    mass: Single;
  end;

  TPhysicBoxDef = record
  private
    m_tx: TPhysicTransform;
    m_e: TVector3;
    m_friction: Single;
    m_restitution: Single;
    m_density: Single;
    m_sensor: Boolean;
  public
    class function Create: TPhysicBoxDef; static;

    procedure SetData(const tx: TPhysicTransform; const extents: TVector3);
    procedure SetFriction(friction: Single);
    procedure SetRestitution(restitution: Single);
    procedure SetDensity(density: Single);
    procedure SetSensor(sensor: Boolean);
  end;

  //----------------------------------------------------------------------------
  // Contacts
  //----------------------------------------------------------------------------
  TPhysicFeaturePair = packed record
    case Integer of
      0: (inR: Byte; outR: Byte; inI: Byte; outI: Byte);
      1: (key: Integer);
  end;

  TPhysicContact = record
  public
    position: TVector3;
    penetration: Single;
    normalImpulse: Single;
    tangentImpulse: array[0..1] of Single;
    bias: Single;
    normalMass: Single;
    tangentMass: array[0..1] of Single;
    fp: TPhysicFeaturePair;
    warmStarted: Byte;
  end;

  TPhysicManifold = record
  public
    A: TPhysicBox;
    B: TPhysicBox;
    normal: TVector3;
    tangentVectors: array[0..1] of TVector3;
    contacts: array[0..7] of TPhysicContact;
    contactCount: Integer;
    next: Pointer;
    prev: Pointer;
    sensor: Boolean;

    procedure SetPair(a, b: TPhysicBox);
  end;

  PPhysicContactEdge = ^TPhysicContactEdge;
  TPhysicContactEdge = record
  public
    other: TPhysicBody;
    constraint: TPhysicContactConstraint;
    next: PPhysicContactEdge;
    prev: PPhysicContactEdge;
  end;

  TPhysicContactConstraint = class
  public const
    eColliding = $00000001;
    eWasColliding = $00000002;
    eIsland = $00000004;
  public
    A: TPhysicBox;
    B: TPhysicBox;
    bodyA: TPhysicBody;
    bodyB: TPhysicBody;
    edgeA: TPhysicContactEdge;
    edgeB: TPhysicContactEdge;
    next: TPhysicContactConstraint;
    prev: TPhysicContactConstraint;
    friction: Single;
    restitution: Single;
    manifold: TPhysicManifold;
    m_flags: Integer;

    procedure SolveCollision;
  end;

  //----------------------------------------------------------------------------
  // Box shape
  //----------------------------------------------------------------------------
  TPhysicBox = class
  public
    local: TPhysicTransform;
    e: TVector3;
    next: TPhysicBox;
    body: TPhysicBody;
    friction: Single;
    restitution: Single;
    density: Single;
    broadPhaseIndex: Integer;
    userData: Pointer;
    sensor: Boolean;

    procedure SetUserdata(data: Pointer);
    function GetUserdata: Pointer;
    procedure SetSensor(isSensor: Boolean);

    function TestPoint(const tx: TPhysicTransform; const p: TVector3): Boolean;
    function Raycast(const tx: TPhysicTransform; var raycast: TPhysicRaycastData): Boolean;
    procedure ComputeAABB(const tx: TPhysicTransform; out aabb: TPhysicAABB);
    procedure ComputeMass(out md: TPhysicMassData);

    function GetBody: TPhysicBody;
    function GetNext: TPhysicBox;
  end;

  //----------------------------------------------------------------------------
  // Body definition and body
  //----------------------------------------------------------------------------
  TPhysicBodyDef = record
  public
    axis: TVector3;
    angle: Single;
    position: TVector3;
    linearVelocity: TVector3;
    angularVelocity: TVector3;
    gravityScale: Single;
    layers: Integer;
    userData: Pointer;
    linearDamping: Single;
    angularDamping: Single;
    bodyType: TPhysicBodyType;
    allowSleep: Boolean;
    awake: Boolean;
    active: Boolean;
    lockAxisX: Boolean;
    lockAxisY: Boolean;
    lockAxisZ: Boolean;

    class function Create: TPhysicBodyDef; static;
  end;

  TPhysicBody = class
  public const
    eAwake = $001;
    eActive = $002;
    eAllowSleep = $004;
    eIsland = $010;
    eStatic = $020;
    eDynamic = $040;
    eKinematic = $080;
    eLockAxisX = $100;
    eLockAxisY = $200;
    eLockAxisZ = $400;
  private
    m_invInertiaModel: TPhysicMat3;
    m_invInertiaWorld: TPhysicMat3;
    m_mass: Single;
    m_invMass: Single;
    m_linearVelocity: TVector3;
    m_angularVelocity: TVector3;
    m_force: TVector3;
    m_torque: TVector3;
    m_tx: TPhysicTransform;
    m_q: TPhysicQuaternion;
    m_localCenter: TVector3;
    m_worldCenter: TVector3;
    m_sleepTime: Single;
    m_gravityScale: Single;
    m_layers: Integer;
    m_flags: Integer;
    m_boxes: TPhysicBox;
    m_userData: Pointer;
    m_scene: TPhysicScene;
    m_next: TPhysicBody;
    m_prev: TPhysicBody;
    m_islandIndex: Integer;
    m_linearDamping: Single;
    m_angularDamping: Single;
    m_contactList: PPhysicContactEdge;

    constructor Create(const def: TPhysicBodyDef; scene: TPhysicScene);
    procedure CalculateMassData;
    procedure SynchronizeProxies;
  public
    destructor Destroy; override;

    function AddBox(const def: TPhysicBoxDef): TPhysicBox;
    procedure RemoveBox(box: TPhysicBox);
    procedure RemoveAllBoxes;

    procedure ApplyLinearForce(const force: TVector3);
    procedure ApplyForceAtWorldPoint(const force, point: TVector3);
    procedure ApplyLinearImpulse(const impulse: TVector3);
    procedure ApplyLinearImpulseAtWorldPoint(const impulse, point: TVector3);
    procedure ApplyTorque(const torque: TVector3);
    procedure SetToAwake;
    procedure SetToSleep;
    function IsAwake: Boolean;
    function GetGravityScale: Single;
    procedure SetGravityScale(scale: Single);
    function GetLocalPoint(const p: TVector3): TVector3;
    function GetLocalVector(const v: TVector3): TVector3;
    function GetWorldPoint(const p: TVector3): TVector3;
    function GetWorldVector(const v: TVector3): TVector3;
    function GetLinearVelocity: TVector3;
    function GetVelocityAtWorldPoint(const p: TVector3): TVector3;
    procedure SetLinearVelocity(const v: TVector3);
    function GetAngularVelocity: TVector3;
    procedure SetAngularVelocity(const v: TVector3);
    function CanCollide(other: TPhysicBody): Boolean;
    function GetTransform: TPhysicTransform;
    function GetFlags: Integer;
    procedure SetLayers(layers: Integer);
    function GetLayers: Integer;
    function GetQuaternion: TPhysicQuaternion;
    function GetUserData: Pointer;
    procedure SetLinearDamping(damping: Single);
    function GetLinearDamping: Single;
    procedure SetAngularDamping(damping: Single);
    function GetAngularDamping: Single;
    procedure SetTransform(const position: TVector3); overload;
    procedure SetTransform(const position, axis: TVector3; angle: Single); overload;
    function GetMass: Single;
    function GetInvMass: Single;
    function GetFirstBox: TPhysicBox;
    function GetNext: TPhysicBody;
  end;

  //----------------------------------------------------------------------------
  // Broadphase internals
  //----------------------------------------------------------------------------
  TPhysicTreeQueryCallback = class abstract
  public
    function TreeCallBack(index: Integer): Boolean; virtual; abstract;
  end;

  TPhysicTreeNode = record
  public
    aabb: TPhysicAABB;
    parent: Integer;
    next: Integer;
    left: Integer;
    right: Integer;
    userData: TPhysicBox;
    height: Integer;

    function IsLeaf: Boolean;
  end;

  TPhysicDynamicAABBTree = class
  private
    m_root: Integer;
    m_nodes: array of TPhysicTreeNode;
    m_count: Integer;
    m_capacity: Integer;
    m_freeList: Integer;

    function AllocateNode: Integer;
    procedure DeallocateNode(index: Integer);
    function Balance(index: Integer): Integer;
    procedure InsertLeaf(index: Integer);
    procedure RemoveLeaf(index: Integer);
    procedure SyncHierarchy(index: Integer);
    procedure AddToFreeList(index: Integer);
  public
    constructor Create;

    function Insert(const aabb: TPhysicAABB; userData: TPhysicBox): Integer;
    procedure Remove(id: Integer);
    function Update(id: Integer; const aabb: TPhysicAABB): Boolean;
    function GetUserData(id: Integer): TPhysicBox;
    function GetFatAABB(id: Integer): TPhysicAABB;
    procedure Query(cb: TPhysicTreeQueryCallback; const aabb: TPhysicAABB); overload;
    procedure Query(cb: TPhysicTreeQueryCallback; var rayCast: TPhysicRaycastData); overload;
    procedure Validate;
  end;

  TPhysicContactPair = record
  public
    A: Integer;
    B: Integer;
  end;

  TPhysicBroadPhase = class(TPhysicTreeQueryCallback)
  private
    m_manager: TPhysicContactManager;
    m_pairBuffer: array of TPhysicContactPair;
    m_pairCount: Integer;
    m_moveBuffer: array of Integer;
    m_moveCount: Integer;
    m_tree: TPhysicDynamicAABBTree;
    m_currentIndex: Integer;

    procedure BufferMove(id: Integer);
    procedure SortPairs;
  public
    constructor Create(manager: TPhysicContactManager);
    destructor Destroy; override;

    procedure InsertBox(box: TPhysicBox; const aabb: TPhysicAABB);
    procedure RemoveBox(box: TPhysicBox);
    procedure UpdatePairs;
    procedure Update(id: Integer; const aabb: TPhysicAABB);
    function TestOverlap(A, B: Integer): Boolean;
    function TreeCallBack(index: Integer): Boolean; override;
  end;

  TPhysicContactManager = class
  private
    m_contactList: TPhysicContactConstraint;
    m_contactCount: Integer;
    m_broadphase: TPhysicBroadPhase;
    m_contactListener: TPhysicContactListener;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddContact(A, B: TPhysicBox);
    procedure FindNewContacts;
    procedure RemoveContact(contact: TPhysicContactConstraint);
    procedure RemoveContactsFromBody(body: TPhysicBody);
    procedure RemoveFromBroadphase(body: TPhysicBody);
    procedure TestCollisions;
  end;

  //----------------------------------------------------------------------------
  // Scene
  //----------------------------------------------------------------------------
  TPhysicScene = class
  private
    m_contactManager: TPhysicContactManager;
    m_bodyCount: Integer;
    m_bodyList: TPhysicBody;
    m_gravity: TVector3;
    m_dt: Single;
    m_iterations: Integer;
    m_newBox: Boolean;
    m_allowSleep: Boolean;
    m_enableFriction: Boolean;
  public
    constructor Create(dt: Single; iterations: Integer = 20); overload;
    constructor Create(dt: Single; const gravity: TVector3; iterations: Integer = 20); overload;
    destructor Destroy; override;

    procedure Step;
    function CreateBody(const def: TPhysicBodyDef): TPhysicBody;
    procedure RemoveBody(body: TPhysicBody);
    procedure RemoveAllBodies;
    procedure SetAllowSleep(allowSleep: Boolean);
    procedure SetIterations(iterations: Integer);
    procedure SetEnableFriction(enabled: Boolean);
    function GetGravity: TVector3;
    procedure SetGravity(const gravity: TVector3);
    procedure Shutdown;
    procedure SetContactListener(listener: TPhysicContactListener);
    procedure QueryAABB(cb: TPhysicQueryCallback; const aabb: TPhysicAABB);
    procedure QueryPoint(cb: TPhysicQueryCallback; const point: TVector3);
    procedure RayCast(cb: TPhysicQueryCallback; var rayCast: TPhysicRaycastData);
    function GetFirstBody: TPhysicBody;
    function GetBodyCount: Integer;
  end;

procedure PhysicBoxToBox(var m: TPhysicManifold; a, b: TPhysicBox);

implementation

const
  PhysicTreeNull = -1;

type
  TPhysicClipVertex = record
    v: TVector3;
    f: TPhysicFeaturePair;
  end;

  TPhysicVelocityState = record
    w: TVector3;
    v: TVector3;
  end;

  TPhysicContactState = record
    ra: TVector3;
    rb: TVector3;
    penetration: Single;
    normalImpulse: Single;
    tangentImpulse: array[0..1] of Single;
    bias: Single;
    normalMass: Single;
    tangentMass: array[0..1] of Single;
  end;

  TPhysicContactConstraintState = record
    contacts: array[0..7] of TPhysicContactState;
    contactCount: Integer;
    tangentVectors: array[0..1] of TVector3;
    normal: TVector3;
    centerA: TVector3;
    centerB: TVector3;
    iA: TPhysicMat3;
    iB: TPhysicMat3;
    mA: Single;
    mB: Single;
    restitution: Single;
    friction: Single;
    indexA: Integer;
    indexB: Integer;
  end;

  PPhysicIsland = ^TPhysicIsland;
  TPhysicIsland = record
    m_bodies: array of TPhysicBody;
    m_velocities: array of TPhysicVelocityState;
    m_bodyCapacity: Integer;
    m_bodyCount: Integer;
    m_contacts: array of TPhysicContactConstraint;
    m_contactStates: array of TPhysicContactConstraintState;
    m_contactCount: Integer;
    m_contactCapacity: Integer;
    m_dt: Single;
    m_gravity: TVector3;
    m_iterations: Integer;
    m_allowSleep: Boolean;
    m_enableFriction: Boolean;

    procedure Solve;
    procedure AddBody(body: TPhysicBody);
    procedure AddContact(contact: TPhysicContactConstraint);
    procedure Initialize;
  end;

  TPhysicContactSolver = record
    m_island: PPhysicIsland;
    m_contactCount: Integer;
    m_enableFriction: Boolean;

    procedure Initialize(var island: TPhysicIsland);
    procedure ShutDown;
    procedure PreSolve(dt: Single);
    procedure Solve;
  end;

  TPhysicSceneAABBQuery = class(TPhysicTreeQueryCallback)
  public
    cb: TPhysicQueryCallback;
    broadPhase: TPhysicBroadPhase;
    aabb: TPhysicAABB;
    function TreeCallBack(index: Integer): Boolean; override;
  end;

  TPhysicScenePointQuery = class(TPhysicTreeQueryCallback)
  public
    cb: TPhysicQueryCallback;
    broadPhase: TPhysicBroadPhase;
    point: TVector3;
    function TreeCallBack(index: Integer): Boolean; override;
  end;

  PPhysicRaycastData = ^TPhysicRaycastData;
  TPhysicSceneRayQuery = class(TPhysicTreeQueryCallback)
  public
    cb: TPhysicQueryCallback;
    broadPhase: TPhysicBroadPhase;
    rayCast: PPhysicRaycastData;
    function TreeCallBack(index: Integer): Boolean; override;
  end;

function PhysicMixRestitution(A, B: TPhysicBox): Single; inline;
begin
  Result := PhysicMax(A.restitution, B.restitution);
end;

function PhysicMixFriction(A, B: TPhysicBox): Single; inline;
begin
  Result := Sqrt(A.friction * B.friction);
end;

procedure PhysicSwapByte(var a, b: Byte); inline;
var
  temp: Byte;
begin
  temp := a;
  a := b;
  b := temp;
end;

//============================================================================
// TPhysicBoxDef
//============================================================================

class function TPhysicBoxDef.Create: TPhysicBoxDef;
begin
  PhysicIdentity(Result.m_tx);
  PhysicIdentity(Result.m_e);
  Result.m_friction := 0.4;
  Result.m_restitution := 0.2;
  Result.m_density := 1.0;
  Result.m_sensor := False;
end;

procedure TPhysicBoxDef.SetData(const tx: TPhysicTransform; const extents: TVector3);
begin
  m_tx := tx;
  m_e := extents * 0.5;
end;

procedure TPhysicBoxDef.SetFriction(friction: Single);
begin
  m_friction := friction;
end;

procedure TPhysicBoxDef.SetRestitution(restitution: Single);
begin
  m_restitution := restitution;
end;

procedure TPhysicBoxDef.SetDensity(density: Single);
begin
  m_density := density;
end;

procedure TPhysicBoxDef.SetSensor(sensor: Boolean);
begin
  m_sensor := sensor;
end;

//============================================================================
// TPhysicManifold / TPhysicContactConstraint
//============================================================================

procedure TPhysicManifold.SetPair(a, b: TPhysicBox);
begin
  A := a;
  B := b;
  sensor := A.sensor or B.sensor;
end;

procedure TPhysicContactConstraint.SolveCollision;
begin
  manifold.contactCount := 0;
  PhysicBoxToBox(manifold, A, B);

  if (manifold.contactCount > 0) then
  begin
    if ((m_flags and eColliding) <> 0) then
      m_flags := m_flags or eWasColliding
    else
      m_flags := m_flags or eColliding;
  end
  else
  begin
    if ((m_flags and eColliding) <> 0) then
    begin
      m_flags := m_flags and not eColliding;
      m_flags := m_flags or eWasColliding;
    end
    else
      m_flags := m_flags and not eWasColliding;
  end;
end;

//============================================================================
// TPhysicBox
//============================================================================

procedure TPhysicBox.SetUserdata(data: Pointer);
begin
  userData := data;
end;

function TPhysicBox.GetUserdata: Pointer;
begin
  Result := userData;
end;

procedure TPhysicBox.SetSensor(isSensor: Boolean);
begin
  sensor := isSensor;
end;

function TPhysicBox.TestPoint(const tx: TPhysicTransform; const p: TVector3): Boolean;
var
  world: TPhysicTransform;
  p0: TVector3;
  i: Integer;
  d, ei: Single;
begin
  world := PhysicMul(tx, local);
  p0 := PhysicMulT(world, p);

  for i := 0 to 2 do
  begin
    d := PhysicVecGet(p0, i);
    ei := PhysicVecGet(e, i);
    if (d > ei) or (d < -ei) then
      Exit(False);
  end;

  Result := True;
end;

function TPhysicBox.Raycast(const tx: TPhysicTransform; var raycast: TPhysicRaycastData): Boolean;
const
  Epsilon: Single = 1.0e-8;
var
  world: TPhysicTransform;
  d, p, n0, n: TVector3;
  tmin, tmax, t0, t1, d0, s, ei: Single;
  i: Integer;
begin
  world := PhysicMul(tx, local);
  d := PhysicMulT(world.rotation, raycast.dir);
  p := PhysicMulT(world, raycast.start);
  tmin := 0.0;
  tmax := raycast.t;
  PhysicIdentity(n0);

  for i := 0 to 2 do
  begin
    if (PhysicAbs(PhysicVecGet(d, i)) < Epsilon) then
    begin
      if (PhysicVecGet(p, i) < -PhysicVecGet(e, i)) or
         (PhysicVecGet(p, i) > PhysicVecGet(e, i)) then
        Exit(False);
    end
    else
    begin
      d0 := 1.0 / PhysicVecGet(d, i);
      s := PhysicSign(PhysicVecGet(d, i));
      ei := PhysicVecGet(e, i) * s;
      PhysicIdentity(n);
      PhysicVecSet(n, i, -s);

      t0 := -(ei + PhysicVecGet(p, i)) * d0;
      t1 := (ei - PhysicVecGet(p, i)) * d0;

      if (t0 > tmin) then
      begin
        n0 := n;
        tmin := t0;
      end;

      tmax := PhysicMin(tmax, t1);
      if (tmin > tmax) then
        Exit(False);
    end;
  end;

  raycast.normal := world.rotation * n0;
  raycast.toi := tmin;
  Result := True;
end;

procedure TPhysicBox.ComputeAABB(const tx: TPhysicTransform; out aabb: TPhysicAABB);
var
  world: TPhysicTransform;
  v: array[0..7] of TVector3;
  minVec, maxVec: TVector3;
  i: Integer;
begin
  world := PhysicMul(tx, local);

  v[0] := PhysicVec3(-e.X, -e.Y, -e.Z);
  v[1] := PhysicVec3(-e.X, -e.Y,  e.Z);
  v[2] := PhysicVec3(-e.X,  e.Y, -e.Z);
  v[3] := PhysicVec3(-e.X,  e.Y,  e.Z);
  v[4] := PhysicVec3( e.X, -e.Y, -e.Z);
  v[5] := PhysicVec3( e.X, -e.Y,  e.Z);
  v[6] := PhysicVec3( e.X,  e.Y, -e.Z);
  v[7] := PhysicVec3( e.X,  e.Y,  e.Z);

  for i := 0 to 7 do
    v[i] := PhysicMul(world, v[i]);

  minVec := PhysicVec3(Q3_R32_MAX, Q3_R32_MAX, Q3_R32_MAX);
  maxVec := PhysicVec3(-Q3_R32_MAX, -Q3_R32_MAX, -Q3_R32_MAX);

  for i := 0 to 7 do
  begin
    minVec := PhysicMin(minVec, v[i]);
    maxVec := PhysicMax(maxVec, v[i]);
  end;

  aabb.min := minVec;
  aabb.max := maxVec;
end;

procedure TPhysicBox.ComputeMass(out md: TPhysicMassData);
var
  ex2, ey2, ez2, boxMass, xValue, yValue, zValue: Single;
  inertia, identity: TPhysicMat3;
begin
  ex2 := 4.0 * e.X * e.X;
  ey2 := 4.0 * e.Y * e.Y;
  ez2 := 4.0 * e.Z * e.Z;
  boxMass := 8.0 * e.X * e.Y * e.Z * density;
  xValue := (1.0 / 12.0) * boxMass * (ey2 + ez2);
  yValue := (1.0 / 12.0) * boxMass * (ex2 + ez2);
  zValue := (1.0 / 12.0) * boxMass * (ex2 + ey2);
  inertia := PhysicDiagonal(xValue, yValue, zValue);

  inertia := local.rotation * inertia * PhysicTranspose(local.rotation);
  PhysicIdentity(identity);
  inertia := inertia + (identity * PhysicDot(local.position, local.position) -
    PhysicOuterProduct(local.position, local.position)) * boxMass;

  md.center := local.position;
  md.inertia := inertia;
  md.mass := boxMass;
end;

function TPhysicBox.GetBody: TPhysicBody;
begin
  Result := body;
end;

function TPhysicBox.GetNext: TPhysicBox;
begin
  Result := next;
end;

//============================================================================
// Collision
//============================================================================

function PhysicTrackFaceAxis(var axis: Integer; n: Integer; s: Single; var sMax: Single;
  const normal: TVector3; var axisNormal: TVector3): Boolean;
begin
  if (s > 0.0) then
    Exit(True);

  if (s > sMax) then
  begin
    sMax := s;
    axis := n;
    axisNormal := normal;
  end;

  Result := False;
end;

function PhysicTrackEdgeAxis(var axis: Integer; n: Integer; s: Single; var sMax: Single;
  const normal: TVector3; var axisNormal: TVector3): Boolean;
var
  l: Single;
begin
  if (s > 0.0) then
    Exit(True);

  l := 1.0 / PhysicLength(normal);
  s := s * l;

  if (s > sMax) then
  begin
    sMax := s;
    axis := n;
    axisNormal := normal * l;
  end;

  Result := False;
end;

procedure PhysicComputeReferenceEdgesAndBasis(const eR: TVector3; const rtx: TPhysicTransform;
  n: TVector3; axis: Integer; out clipEdges: array of Byte; out basis: TPhysicMat3; out e: TVector3);
begin
  n := PhysicMulT(rtx.rotation, n);

  if (axis >= 3) then
    Dec(axis, 3);

  case axis of
    0:
      if (n.X > 0.0) then
      begin
        clipEdges[0] := 1;
        clipEdges[1] := 8;
        clipEdges[2] := 7;
        clipEdges[3] := 9;
        e := PhysicVec3(eR.Y, eR.Z, eR.X);
        basis.SetRows(rtx.rotation.ey, rtx.rotation.ez, rtx.rotation.ex);
      end
      else
      begin
        clipEdges[0] := 11;
        clipEdges[1] := 3;
        clipEdges[2] := 10;
        clipEdges[3] := 5;
        e := PhysicVec3(eR.Z, eR.Y, eR.X);
        basis.SetRows(rtx.rotation.ez, rtx.rotation.ey, rtx.rotation.ex * -1.0);
      end;
    1:
      if (n.Y > 0.0) then
      begin
        clipEdges[0] := 0;
        clipEdges[1] := 1;
        clipEdges[2] := 2;
        clipEdges[3] := 3;
        e := PhysicVec3(eR.Z, eR.X, eR.Y);
        basis.SetRows(rtx.rotation.ez, rtx.rotation.ex, rtx.rotation.ey);
      end
      else
      begin
        clipEdges[0] := 4;
        clipEdges[1] := 5;
        clipEdges[2] := 6;
        clipEdges[3] := 7;
        e := PhysicVec3(eR.Z, eR.X, eR.Y);
        basis.SetRows(rtx.rotation.ez, rtx.rotation.ex * -1.0, rtx.rotation.ey * -1.0);
      end;
    2:
      if (n.Z > 0.0) then
      begin
        clipEdges[0] := 11;
        clipEdges[1] := 4;
        clipEdges[2] := 8;
        clipEdges[3] := 0;
        e := PhysicVec3(eR.Y, eR.X, eR.Z);
        basis.SetRows(rtx.rotation.ey * -1.0, rtx.rotation.ex, rtx.rotation.ez);
      end
      else
      begin
        clipEdges[0] := 6;
        clipEdges[1] := 10;
        clipEdges[2] := 2;
        clipEdges[3] := 9;
        e := PhysicVec3(eR.Y, eR.X, eR.Z);
        basis.SetRows(rtx.rotation.ey * -1.0, rtx.rotation.ex * -1.0, rtx.rotation.ez * -1.0);
      end;
  end;
end;

procedure PhysicComputeIncidentFace(const itx: TPhysicTransform; const e: TVector3;
  n: TVector3; var outVerts: array of TPhysicClipVertex);
var
  absN: TVector3;
  i: Integer;
begin
  n := PhysicMulT(itx.rotation, n) * -1.0;
  absN := PhysicAbs(n);

  if (absN.X > absN.Y) and (absN.X > absN.Z) then
  begin
    if (n.X > 0.0) then
    begin
      outVerts[0].v := PhysicVec3( e.X,  e.Y, -e.Z);
      outVerts[1].v := PhysicVec3( e.X,  e.Y,  e.Z);
      outVerts[2].v := PhysicVec3( e.X, -e.Y,  e.Z);
      outVerts[3].v := PhysicVec3( e.X, -e.Y, -e.Z);
      outVerts[0].f.inI := 9;  outVerts[0].f.outI := 1;
      outVerts[1].f.inI := 1;  outVerts[1].f.outI := 8;
      outVerts[2].f.inI := 8;  outVerts[2].f.outI := 7;
      outVerts[3].f.inI := 7;  outVerts[3].f.outI := 9;
    end
    else
    begin
      outVerts[0].v := PhysicVec3(-e.X, -e.Y,  e.Z);
      outVerts[1].v := PhysicVec3(-e.X,  e.Y,  e.Z);
      outVerts[2].v := PhysicVec3(-e.X,  e.Y, -e.Z);
      outVerts[3].v := PhysicVec3(-e.X, -e.Y, -e.Z);
      outVerts[0].f.inI := 5;  outVerts[0].f.outI := 11;
      outVerts[1].f.inI := 11; outVerts[1].f.outI := 3;
      outVerts[2].f.inI := 3;  outVerts[2].f.outI := 10;
      outVerts[3].f.inI := 10; outVerts[3].f.outI := 5;
    end;
  end
  else if (absN.Y > absN.X) and (absN.Y > absN.Z) then
  begin
    if (n.Y > 0.0) then
    begin
      outVerts[0].v := PhysicVec3(-e.X,  e.Y,  e.Z);
      outVerts[1].v := PhysicVec3( e.X,  e.Y,  e.Z);
      outVerts[2].v := PhysicVec3( e.X,  e.Y, -e.Z);
      outVerts[3].v := PhysicVec3(-e.X,  e.Y, -e.Z);
      outVerts[0].f.inI := 3; outVerts[0].f.outI := 0;
      outVerts[1].f.inI := 0; outVerts[1].f.outI := 1;
      outVerts[2].f.inI := 1; outVerts[2].f.outI := 2;
      outVerts[3].f.inI := 2; outVerts[3].f.outI := 3;
    end
    else
    begin
      outVerts[0].v := PhysicVec3( e.X, -e.Y,  e.Z);
      outVerts[1].v := PhysicVec3(-e.X, -e.Y,  e.Z);
      outVerts[2].v := PhysicVec3(-e.X, -e.Y, -e.Z);
      outVerts[3].v := PhysicVec3( e.X, -e.Y, -e.Z);
      outVerts[0].f.inI := 7; outVerts[0].f.outI := 4;
      outVerts[1].f.inI := 4; outVerts[1].f.outI := 5;
      outVerts[2].f.inI := 5; outVerts[2].f.outI := 6;
      outVerts[3].f.inI := 5; outVerts[3].f.outI := 6;
    end;
  end
  else
  begin
    if (n.Z > 0.0) then
    begin
      outVerts[0].v := PhysicVec3(-e.X,  e.Y,  e.Z);
      outVerts[1].v := PhysicVec3(-e.X, -e.Y,  e.Z);
      outVerts[2].v := PhysicVec3( e.X, -e.Y,  e.Z);
      outVerts[3].v := PhysicVec3( e.X,  e.Y,  e.Z);
      outVerts[0].f.inI := 0;  outVerts[0].f.outI := 11;
      outVerts[1].f.inI := 11; outVerts[1].f.outI := 4;
      outVerts[2].f.inI := 4;  outVerts[2].f.outI := 8;
      outVerts[3].f.inI := 8;  outVerts[3].f.outI := 0;
    end
    else
    begin
      outVerts[0].v := PhysicVec3( e.X, -e.Y, -e.Z);
      outVerts[1].v := PhysicVec3(-e.X, -e.Y, -e.Z);
      outVerts[2].v := PhysicVec3(-e.X,  e.Y, -e.Z);
      outVerts[3].v := PhysicVec3( e.X,  e.Y, -e.Z);
      outVerts[0].f.inI := 9;  outVerts[0].f.outI := 6;
      outVerts[1].f.inI := 6;  outVerts[1].f.outI := 10;
      outVerts[2].f.inI := 10; outVerts[2].f.outI := 2;
      outVerts[3].f.inI := 2;  outVerts[3].f.outI := 9;
    end;
  end;

  for i := 0 to 3 do
    outVerts[i].v := PhysicMul(itx, outVerts[i].v);
end;

function PhysicOrthographic(sign, e: Single; axis, clipEdge: Integer;
  const inVerts: array of TPhysicClipVertex; inCount: Integer;
  var outVerts: array of TPhysicClipVertex): Integer;
var
  outCount, i: Integer;
  a, b, cv: TPhysicClipVertex;
  da, db: Single;
begin
  outCount := 0;
  a := inVerts[inCount - 1];

  for i := 0 to inCount - 1 do
  begin
    b := inVerts[i];
    da := sign * PhysicVecGet(a.v, axis) - e;
    db := sign * PhysicVecGet(b.v, axis) - e;

    if (((da < 0.0) and (db < 0.0)) or
        ((da < 0.005) and (da > -0.005)) or
        ((db < 0.005) and (db > -0.005))) then
    begin
      outVerts[outCount] := b;
      Inc(outCount);
    end
    else if ((da < 0.0) and (db >= 0.0)) then
    begin
      cv.f := b.f;
      cv.v := a.v + (b.v - a.v) * (da / (da - db));
      cv.f.outR := clipEdge;
      cv.f.outI := 0;
      outVerts[outCount] := cv;
      Inc(outCount);
    end
    else if ((da >= 0.0) and (db < 0.0)) then
    begin
      cv.f := a.f;
      cv.v := a.v + (b.v - a.v) * (da / (da - db));
      cv.f.inR := clipEdge;
      cv.f.inI := 0;
      outVerts[outCount] := cv;
      Inc(outCount);

      outVerts[outCount] := b;
      Inc(outCount);
    end;

    a := b;
  end;

  Result := outCount;
end;

function PhysicClip(const rPos, e: TVector3; const clipEdges: array of Byte;
  const basis: TPhysicMat3; const incident: array of TPhysicClipVertex;
  var outVerts: array of TPhysicClipVertex; var outDepths: array of Single): Integer;
var
  inCount, outCount, i: Integer;
  inVerts, outTemp: array[0..7] of TPhysicClipVertex;
  d: Single;
begin
  inCount := 4;
  for i := 0 to 7 do
  begin
    inVerts[i].f.key := -1;
    outTemp[i].f.key := -1;
  end;

  for i := 0 to 3 do
  begin
    inVerts[i].v := PhysicMulT(basis, incident[i].v - rPos);
    inVerts[i].f := incident[i].f;
  end;

  outCount := PhysicOrthographic(1.0, e.X, 0, clipEdges[0], inVerts, inCount, outTemp);
  if (outCount = 0) then
    Exit(0);

  inCount := PhysicOrthographic(1.0, e.Y, 1, clipEdges[1], outTemp, outCount, inVerts);
  if (inCount = 0) then
    Exit(0);

  outCount := PhysicOrthographic(-1.0, e.X, 0, clipEdges[2], inVerts, inCount, outTemp);
  if (outCount = 0) then
    Exit(0);

  inCount := PhysicOrthographic(-1.0, e.Y, 1, clipEdges[3], outTemp, outCount, inVerts);

  outCount := 0;
  for i := 0 to inCount - 1 do
  begin
    d := inVerts[i].v.Z - e.Z;
    if (d <= 0.0) then
    begin
      outVerts[outCount].v := basis * inVerts[i].v + rPos;
      outVerts[outCount].f := inVerts[i].f;
      outDepths[outCount] := d;
      Inc(outCount);
    end;
  end;

  Result := outCount;
end;

procedure PhysicEdgesContact(out CA, CB: TVector3; const PA, QA, PB, QB: TVector3);
var
  DA, DB, r: TVector3;
  a, e, f, c, b, denom, TA, TB: Single;
begin
  DA := QA - PA;
  DB := QB - PB;
  r := PA - PB;
  a := PhysicDot(DA, DA);
  e := PhysicDot(DB, DB);
  f := PhysicDot(DB, r);
  c := PhysicDot(DA, r);
  b := PhysicDot(DA, DB);
  denom := a * e - b * b;
  TA := (b * f - c * e) / denom;
  TB := (b * TA + f) / e;
  CA := PA + DA * TA;
  CB := PB + DB * TB;
end;

procedure PhysicSupportEdge(const tx: TPhysicTransform; const e: TVector3; n: TVector3;
  out aOut, bOut: TVector3);
var
  absN, a, b: TVector3;
  signx, signy, signz: Single;
begin
  n := PhysicMulT(tx.rotation, n);
  absN := PhysicAbs(n);

  if (absN.X > absN.Y) then
  begin
    if (absN.Y > absN.Z) then
    begin
      a := PhysicVec3(e.X, e.Y, e.Z);
      b := PhysicVec3(e.X, e.Y, -e.Z);
    end
    else
    begin
      a := PhysicVec3(e.X, e.Y, e.Z);
      b := PhysicVec3(e.X, -e.Y, e.Z);
    end;
  end
  else
  begin
    if (absN.X > absN.Z) then
    begin
      a := PhysicVec3(e.X, e.Y, e.Z);
      b := PhysicVec3(e.X, e.Y, -e.Z);
    end
    else
    begin
      a := PhysicVec3(e.X, e.Y, e.Z);
      b := PhysicVec3(-e.X, e.Y, e.Z);
    end;
  end;

  signx := PhysicSign(n.X);
  signy := PhysicSign(n.Y);
  signz := PhysicSign(n.Z);

  a.X := a.X * signx;
  a.Y := a.Y * signy;
  a.Z := a.Z * signz;
  b.X := b.X * signx;
  b.Y := b.Y * signy;
  b.Z := b.Z * signz;

  aOut := PhysicMul(tx, a);
  bOut := PhysicMul(tx, b);
end;

procedure PhysicBoxToBox(var m: TPhysicManifold; a, b: TPhysicBox);
const
  kCosTol: Single = 1.0e-6;
  kRelTol: Single = 0.95;
  kAbsTol: Single = 0.01;
var
  atx, btx, aL, bL, rtx, itx: TPhysicTransform;
  eA, eB, eR, eI, eClip: TVector3;
  C, absC, basis: TPhysicMat3;
  parallel, flip: Boolean;
  i, j, axis, outNum: Integer;
  t, nA, nB, nE, n, PA, QA, PB, QB, CA, CB: TVector3;
  s, aMax, bMax, eMax, faceMax, sMax, rA, rB, val: Single;
  aAxis, bAxis, eAxis: Integer;
  incident: array[0..3] of TPhysicClipVertex;
  clipEdges: array[0..3] of Byte;
  outVerts: array[0..7] of TPhysicClipVertex;
  depths: array[0..7] of Single;
  contact: ^TPhysicContact;
  pair: TPhysicFeaturePair;
begin
  atx := a.body.GetTransform;
  btx := b.body.GetTransform;
  aL := a.local;
  bL := b.local;
  atx := PhysicMul(atx, aL);
  btx := PhysicMul(btx, bL);
  eA := a.e;
  eB := b.e;

  C := PhysicTranspose(atx.rotation) * btx.rotation;

  parallel := False;
  PhysicZero(absC);
  for i := 0 to 2 do
  begin
    for j := 0 to 2 do
    begin
      val := PhysicAbs(PhysicMatGet(C, i, j));
      PhysicMatSet(absC, i, j, val);
      if (val + kCosTol >= 1.0) then
        parallel := True;
    end;
  end;

  t := PhysicMulT(atx.rotation, btx.position - atx.position);
  aMax := -Q3_R32_MAX;
  bMax := -Q3_R32_MAX;
  eMax := -Q3_R32_MAX;
  aAxis := -1;
  bAxis := -1;
  eAxis := -1;

  s := PhysicAbs(t.X) - (eA.X + PhysicDot(absC.Column0, eB));
  if PhysicTrackFaceAxis(aAxis, 0, s, aMax, atx.rotation.ex, nA) then Exit;

  s := PhysicAbs(t.Y) - (eA.Y + PhysicDot(absC.Column1, eB));
  if PhysicTrackFaceAxis(aAxis, 1, s, aMax, atx.rotation.ey, nA) then Exit;

  s := PhysicAbs(t.Z) - (eA.Z + PhysicDot(absC.Column2, eB));
  if PhysicTrackFaceAxis(aAxis, 2, s, aMax, atx.rotation.ez, nA) then Exit;

  s := PhysicAbs(PhysicDot(t, C.ex)) - (eB.X + PhysicDot(absC.ex, eA));
  if PhysicTrackFaceAxis(bAxis, 3, s, bMax, btx.rotation.ex, nB) then Exit;

  s := PhysicAbs(PhysicDot(t, C.ey)) - (eB.Y + PhysicDot(absC.ey, eA));
  if PhysicTrackFaceAxis(bAxis, 4, s, bMax, btx.rotation.ey, nB) then Exit;

  s := PhysicAbs(PhysicDot(t, C.ez)) - (eB.Z + PhysicDot(absC.ez, eA));
  if PhysicTrackFaceAxis(bAxis, 5, s, bMax, btx.rotation.ez, nB) then Exit;

  if (not parallel) then
  begin
    rA := eA.Y * PhysicMatGet(absC, 0, 2) + eA.Z * PhysicMatGet(absC, 0, 1);
    rB := eB.Y * PhysicMatGet(absC, 2, 0) + eB.Z * PhysicMatGet(absC, 1, 0);
    s := PhysicAbs(t.Z * PhysicMatGet(C, 0, 1) - t.Y * PhysicMatGet(C, 0, 2)) - (rA + rB);
    if PhysicTrackEdgeAxis(eAxis, 6, s, eMax, PhysicVec3(0.0, -PhysicMatGet(C, 0, 2), PhysicMatGet(C, 0, 1)), nE) then Exit;

    rA := eA.Y * PhysicMatGet(absC, 1, 2) + eA.Z * PhysicMatGet(absC, 1, 1);
    rB := eB.X * PhysicMatGet(absC, 2, 0) + eB.Z * PhysicMatGet(absC, 0, 0);
    s := PhysicAbs(t.Z * PhysicMatGet(C, 1, 1) - t.Y * PhysicMatGet(C, 1, 2)) - (rA + rB);
    if PhysicTrackEdgeAxis(eAxis, 7, s, eMax, PhysicVec3(0.0, -PhysicMatGet(C, 1, 2), PhysicMatGet(C, 1, 1)), nE) then Exit;

    rA := eA.Y * PhysicMatGet(absC, 2, 2) + eA.Z * PhysicMatGet(absC, 2, 1);
    rB := eB.X * PhysicMatGet(absC, 1, 0) + eB.Y * PhysicMatGet(absC, 0, 0);
    s := PhysicAbs(t.Z * PhysicMatGet(C, 2, 1) - t.Y * PhysicMatGet(C, 2, 2)) - (rA + rB);
    if PhysicTrackEdgeAxis(eAxis, 8, s, eMax, PhysicVec3(0.0, -PhysicMatGet(C, 2, 2), PhysicMatGet(C, 2, 1)), nE) then Exit;

    rA := eA.X * PhysicMatGet(absC, 0, 2) + eA.Z * PhysicMatGet(absC, 0, 0);
    rB := eB.Y * PhysicMatGet(absC, 2, 1) + eB.Z * PhysicMatGet(absC, 1, 1);
    s := PhysicAbs(t.X * PhysicMatGet(C, 0, 2) - t.Z * PhysicMatGet(C, 0, 0)) - (rA + rB);
    if PhysicTrackEdgeAxis(eAxis, 9, s, eMax, PhysicVec3(PhysicMatGet(C, 0, 2), 0.0, -PhysicMatGet(C, 0, 0)), nE) then Exit;

    rA := eA.X * PhysicMatGet(absC, 1, 2) + eA.Z * PhysicMatGet(absC, 1, 0);
    rB := eB.X * PhysicMatGet(absC, 2, 1) + eB.Z * PhysicMatGet(absC, 0, 1);
    s := PhysicAbs(t.X * PhysicMatGet(C, 1, 2) - t.Z * PhysicMatGet(C, 1, 0)) - (rA + rB);
    if PhysicTrackEdgeAxis(eAxis, 10, s, eMax, PhysicVec3(PhysicMatGet(C, 1, 2), 0.0, -PhysicMatGet(C, 1, 0)), nE) then Exit;

    rA := eA.X * PhysicMatGet(absC, 2, 2) + eA.Z * PhysicMatGet(absC, 2, 0);
    rB := eB.X * PhysicMatGet(absC, 1, 1) + eB.Y * PhysicMatGet(absC, 0, 1);
    s := PhysicAbs(t.X * PhysicMatGet(C, 2, 2) - t.Z * PhysicMatGet(C, 2, 0)) - (rA + rB);
    if PhysicTrackEdgeAxis(eAxis, 11, s, eMax, PhysicVec3(PhysicMatGet(C, 2, 2), 0.0, -PhysicMatGet(C, 2, 0)), nE) then Exit;

    rA := eA.X * PhysicMatGet(absC, 0, 1) + eA.Y * PhysicMatGet(absC, 0, 0);
    rB := eB.Y * PhysicMatGet(absC, 2, 2) + eB.Z * PhysicMatGet(absC, 1, 2);
    s := PhysicAbs(t.Y * PhysicMatGet(C, 0, 0) - t.X * PhysicMatGet(C, 0, 1)) - (rA + rB);
    if PhysicTrackEdgeAxis(eAxis, 12, s, eMax, PhysicVec3(-PhysicMatGet(C, 0, 1), PhysicMatGet(C, 0, 0), 0.0), nE) then Exit;

    rA := eA.X * PhysicMatGet(absC, 1, 1) + eA.Y * PhysicMatGet(absC, 1, 0);
    rB := eB.X * PhysicMatGet(absC, 2, 2) + eB.Z * PhysicMatGet(absC, 0, 2);
    s := PhysicAbs(t.Y * PhysicMatGet(C, 1, 0) - t.X * PhysicMatGet(C, 1, 1)) - (rA + rB);
    if PhysicTrackEdgeAxis(eAxis, 13, s, eMax, PhysicVec3(-PhysicMatGet(C, 1, 1), PhysicMatGet(C, 1, 0), 0.0), nE) then Exit;

    rA := eA.X * PhysicMatGet(absC, 2, 1) + eA.Y * PhysicMatGet(absC, 2, 0);
    rB := eB.X * PhysicMatGet(absC, 1, 2) + eB.Y * PhysicMatGet(absC, 0, 2);
    s := PhysicAbs(t.Y * PhysicMatGet(C, 2, 0) - t.X * PhysicMatGet(C, 2, 1)) - (rA + rB);
    if PhysicTrackEdgeAxis(eAxis, 14, s, eMax, PhysicVec3(-PhysicMatGet(C, 2, 1), PhysicMatGet(C, 2, 0), 0.0), nE) then Exit;
  end;

  faceMax := PhysicMax(aMax, bMax);
  if (kRelTol * eMax > faceMax + kAbsTol) then
  begin
    axis := eAxis;
    sMax := eMax;
    n := nE;
  end
  else if (kRelTol * bMax > aMax + kAbsTol) then
  begin
    axis := bAxis;
    sMax := bMax;
    n := nB;
  end
  else
  begin
    axis := aAxis;
    sMax := aMax;
    n := nA;
  end;

  if (PhysicDot(n, btx.position - atx.position) < 0.0) then
    n := n * -1.0;

  if (axis = -1) then
    Exit;

  if (axis < 6) then
  begin
    if (axis < 3) then
    begin
      rtx := atx;
      itx := btx;
      eR := eA;
      eI := eB;
      flip := False;
    end
    else
    begin
      rtx := btx;
      itx := atx;
      eR := eB;
      eI := eA;
      flip := True;
      n := n * -1.0;
    end;

    PhysicComputeIncidentFace(itx, eI, n, incident);
    PhysicComputeReferenceEdgesAndBasis(eR, rtx, n, axis, clipEdges, basis, eClip);
    outNum := PhysicClip(rtx.position, eClip, clipEdges, basis, incident, outVerts, depths);

    if (outNum <> 0) then
    begin
      m.contactCount := outNum;
      if flip then
        m.normal := n * -1.0
      else
        m.normal := n;

      for i := 0 to outNum - 1 do
      begin
        contact := @m.contacts[i];
        pair := outVerts[i].f;
        if flip then
        begin
          PhysicSwapByte(pair.inI, pair.inR);
          PhysicSwapByte(pair.outI, pair.outR);
        end;

        contact^.fp := pair;
        contact^.position := outVerts[i].v;
        contact^.penetration := depths[i];
      end;
    end;
  end
  else
  begin
    n := atx.rotation * n;
    if (PhysicDot(n, btx.position - atx.position) < 0.0) then
      n := n * -1.0;

    PhysicSupportEdge(atx, eA, n, PA, QA);
    PhysicSupportEdge(btx, eB, n * -1.0, PB, QB);
    PhysicEdgesContact(CA, CB, PA, QA, PB, QB);

    m.normal := n;
    m.contactCount := 1;
    m.contacts[0].fp.key := axis;
    m.contacts[0].penetration := sMax;
    m.contacts[0].position := (CA + CB) * 0.5;
  end;
end;

//============================================================================
// TPhysicTreeNode / TPhysicDynamicAABBTree
//============================================================================

function TPhysicTreeNode.IsLeaf: Boolean;
begin
  Result := right = PhysicTreeNull;
end;

procedure PhysicFattenAABB(var aabb: TPhysicAABB); inline;
var
  v: TVector3;
begin
  v := PhysicVec3(0.5, 0.5, 0.5);
  aabb.min := aabb.min - v;
  aabb.max := aabb.max + v;
end;

constructor TPhysicDynamicAABBTree.Create;
begin
  inherited Create;
  m_root := PhysicTreeNull;
  m_capacity := 1024;
  m_count := 0;
  SetLength(m_nodes, m_capacity);
  AddToFreeList(0);
end;

procedure TPhysicDynamicAABBTree.AddToFreeList(index: Integer);
var
  i: Integer;
begin
  for i := index to m_capacity - 2 do
  begin
    m_nodes[i].next := i + 1;
    m_nodes[i].height := PhysicTreeNull;
  end;

  m_nodes[m_capacity - 1].next := PhysicTreeNull;
  m_nodes[m_capacity - 1].height := PhysicTreeNull;
  m_freeList := index;
end;

function TPhysicDynamicAABBTree.AllocateNode: Integer;
begin
  if (m_freeList = PhysicTreeNull) then
  begin
    m_capacity := m_capacity * 2;
    SetLength(m_nodes, m_capacity);
    AddToFreeList(m_count);
  end;

  Result := m_freeList;
  m_freeList := m_nodes[m_freeList].next;
  m_nodes[Result].height := 0;
  m_nodes[Result].left := PhysicTreeNull;
  m_nodes[Result].right := PhysicTreeNull;
  m_nodes[Result].parent := PhysicTreeNull;
  m_nodes[Result].userData := nil;
  Inc(m_count);
end;

procedure TPhysicDynamicAABBTree.DeallocateNode(index: Integer);
begin
  m_nodes[index].next := m_freeList;
  m_nodes[index].height := PhysicTreeNull;
  m_freeList := index;
  Dec(m_count);
end;

function TPhysicDynamicAABBTree.Insert(const aabb: TPhysicAABB; userData: TPhysicBox): Integer;
begin
  Result := AllocateNode;
  m_nodes[Result].aabb := aabb;
  PhysicFattenAABB(m_nodes[Result].aabb);
  m_nodes[Result].userData := userData;
  m_nodes[Result].height := 0;
  InsertLeaf(Result);
end;

procedure TPhysicDynamicAABBTree.Remove(id: Integer);
begin
  RemoveLeaf(id);
  DeallocateNode(id);
end;

function TPhysicDynamicAABBTree.Update(id: Integer; const aabb: TPhysicAABB): Boolean;
begin
  if m_nodes[id].aabb.Contains(aabb) then
    Exit(False);

  RemoveLeaf(id);
  m_nodes[id].aabb := aabb;
  PhysicFattenAABB(m_nodes[id].aabb);
  InsertLeaf(id);
  Result := True;
end;

function TPhysicDynamicAABBTree.GetUserData(id: Integer): TPhysicBox;
begin
  Result := m_nodes[id].userData;
end;

function TPhysicDynamicAABBTree.GetFatAABB(id: Integer): TPhysicAABB;
begin
  Result := m_nodes[id].aabb;
end;

procedure TPhysicDynamicAABBTree.Query(cb: TPhysicTreeQueryCallback; const aabb: TPhysicAABB);
var
  stack: array[0..255] of Integer;
  sp, id: Integer;
begin
  if (m_root = PhysicTreeNull) then
    Exit;

  sp := 1;
  stack[0] := m_root;

  while (sp <> 0) do
  begin
    Dec(sp);
    id := stack[sp];

    if PhysicAABBToAABB(aabb, m_nodes[id].aabb) then
    begin
      if m_nodes[id].IsLeaf then
      begin
        if not cb.TreeCallBack(id) then
          Exit;
      end
      else
      begin
        stack[sp] := m_nodes[id].left;
        Inc(sp);
        stack[sp] := m_nodes[id].right;
        Inc(sp);
      end;
    end;
  end;
end;

procedure TPhysicDynamicAABBTree.Query(cb: TPhysicTreeQueryCallback; var rayCast: TPhysicRaycastData);
const
  Epsilon: Single = 1.0e-6;
var
  stack: array[0..255] of Integer;
  sp, id: Integer;
  p0, p1, e, d, m: TVector3;
  adx, ady, adz: Single;
begin
  if (m_root = PhysicTreeNull) then
    Exit;

  sp := 1;
  stack[0] := m_root;
  p0 := rayCast.start;
  p1 := p0 + rayCast.dir * rayCast.t;

  while (sp <> 0) do
  begin
    Dec(sp);
    id := stack[sp];

    if (id = PhysicTreeNull) then
      Continue;

    e := m_nodes[id].aabb.max - m_nodes[id].aabb.min;
    d := p1 - p0;
    m := p0 + p1 - m_nodes[id].aabb.min - m_nodes[id].aabb.max;

    adx := PhysicAbs(d.X);
    if (PhysicAbs(m.X) > e.X + adx) then Continue;
    ady := PhysicAbs(d.Y);
    if (PhysicAbs(m.Y) > e.Y + ady) then Continue;
    adz := PhysicAbs(d.Z);
    if (PhysicAbs(m.Z) > e.Z + adz) then Continue;

    adx := adx + Epsilon;
    ady := ady + Epsilon;
    adz := adz + Epsilon;

    if (PhysicAbs(m.Y * d.Z - m.Z * d.Y) > e.Y * adz + e.Z * ady) then Continue;
    if (PhysicAbs(m.Z * d.X - m.X * d.Z) > e.X * adz + e.Z * adx) then Continue;
    if (PhysicAbs(m.X * d.Y - m.Y * d.X) > e.X * ady + e.Y * adx) then Continue;

    if m_nodes[id].IsLeaf then
    begin
      if not cb.TreeCallBack(id) then
        Exit;
    end
    else
    begin
      stack[sp] := m_nodes[id].left;
      Inc(sp);
      stack[sp] := m_nodes[id].right;
      Inc(sp);
    end;
  end;
end;

function TPhysicDynamicAABBTree.Balance(index: Integer): Integer;
var
  iA, iB, iC, iD, iE, iNodeF, iG: Integer;
  balance: Integer;
begin
  iA := index;
  if m_nodes[iA].IsLeaf or (m_nodes[iA].height = 1) then
    Exit(iA);

  iB := m_nodes[iA].left;
  iC := m_nodes[iA].right;
  balance := m_nodes[iC].height - m_nodes[iB].height;

  if (balance > 1) then
  begin
    iNodeF := m_nodes[iC].left;
    iG := m_nodes[iC].right;

    if (m_nodes[iA].parent <> PhysicTreeNull) then
    begin
      if (m_nodes[m_nodes[iA].parent].left = iA) then
        m_nodes[m_nodes[iA].parent].left := iC
      else
        m_nodes[m_nodes[iA].parent].right := iC;
    end
    else
      m_root := iC;

    m_nodes[iC].left := iA;
    m_nodes[iC].parent := m_nodes[iA].parent;
    m_nodes[iA].parent := iC;

    if (m_nodes[iNodeF].height > m_nodes[iG].height) then
    begin
      m_nodes[iC].right := iNodeF;
      m_nodes[iA].right := iG;
      m_nodes[iG].parent := iA;
      m_nodes[iA].aabb := PhysicCombine(m_nodes[iB].aabb, m_nodes[iG].aabb);
      m_nodes[iC].aabb := PhysicCombine(m_nodes[iA].aabb, m_nodes[iNodeF].aabb);
      m_nodes[iA].height := 1 + PhysicMax(m_nodes[iB].height, m_nodes[iG].height);
      m_nodes[iC].height := 1 + PhysicMax(m_nodes[iA].height, m_nodes[iNodeF].height);
    end
    else
    begin
      m_nodes[iC].right := iG;
      m_nodes[iA].right := iNodeF;
      m_nodes[iNodeF].parent := iA;
      m_nodes[iA].aabb := PhysicCombine(m_nodes[iB].aabb, m_nodes[iNodeF].aabb);
      m_nodes[iC].aabb := PhysicCombine(m_nodes[iA].aabb, m_nodes[iG].aabb);
      m_nodes[iA].height := 1 + PhysicMax(m_nodes[iB].height, m_nodes[iNodeF].height);
      m_nodes[iC].height := 1 + PhysicMax(m_nodes[iA].height, m_nodes[iG].height);
    end;

    Exit(iC);
  end
  else if (balance < -1) then
  begin
    iD := m_nodes[iB].left;
    iE := m_nodes[iB].right;

    if (m_nodes[iA].parent <> PhysicTreeNull) then
    begin
      if (m_nodes[m_nodes[iA].parent].left = iA) then
        m_nodes[m_nodes[iA].parent].left := iB
      else
        m_nodes[m_nodes[iA].parent].right := iB;
    end
    else
      m_root := iB;

    m_nodes[iB].right := iA;
    m_nodes[iB].parent := m_nodes[iA].parent;
    m_nodes[iA].parent := iB;

    if (m_nodes[iD].height > m_nodes[iE].height) then
    begin
      m_nodes[iB].left := iD;
      m_nodes[iA].left := iE;
      m_nodes[iE].parent := iA;
      m_nodes[iA].aabb := PhysicCombine(m_nodes[iC].aabb, m_nodes[iE].aabb);
      m_nodes[iB].aabb := PhysicCombine(m_nodes[iA].aabb, m_nodes[iD].aabb);
      m_nodes[iA].height := 1 + PhysicMax(m_nodes[iC].height, m_nodes[iE].height);
      m_nodes[iB].height := 1 + PhysicMax(m_nodes[iA].height, m_nodes[iD].height);
    end
    else
    begin
      m_nodes[iB].left := iE;
      m_nodes[iA].left := iD;
      m_nodes[iD].parent := iA;
      m_nodes[iA].aabb := PhysicCombine(m_nodes[iC].aabb, m_nodes[iD].aabb);
      m_nodes[iB].aabb := PhysicCombine(m_nodes[iA].aabb, m_nodes[iE].aabb);
      m_nodes[iA].height := 1 + PhysicMax(m_nodes[iC].height, m_nodes[iD].height);
      m_nodes[iB].height := 1 + PhysicMax(m_nodes[iA].height, m_nodes[iE].height);
    end;

    Exit(iB);
  end;

  Result := iA;
end;

procedure TPhysicDynamicAABBTree.InsertLeaf(index: Integer);
var
  searchIndex, sibling, oldParent, newParent, left, right: Integer;
  leafAABB, combined: TPhysicAABB;
  combinedArea, branchCost, inheritedCost, leftDescentCost, rightDescentCost, inflated, branchArea: Single;
begin
  if (m_root = PhysicTreeNull) then
  begin
    m_root := index;
    m_nodes[m_root].parent := PhysicTreeNull;
    Exit;
  end;

  searchIndex := m_root;
  leafAABB := m_nodes[index].aabb;
  while (not m_nodes[searchIndex].IsLeaf) do
  begin
    combined := PhysicCombine(leafAABB, m_nodes[searchIndex].aabb);
    combinedArea := combined.SurfaceArea;
    branchCost := 2.0 * combinedArea;
    inheritedCost := 2.0 * (combinedArea - m_nodes[searchIndex].aabb.SurfaceArea);

    left := m_nodes[searchIndex].left;
    right := m_nodes[searchIndex].right;

    if m_nodes[left].IsLeaf then
      leftDescentCost := PhysicCombine(leafAABB, m_nodes[left].aabb).SurfaceArea + inheritedCost
    else
    begin
      inflated := PhysicCombine(leafAABB, m_nodes[left].aabb).SurfaceArea;
      branchArea := m_nodes[left].aabb.SurfaceArea;
      leftDescentCost := inflated - branchArea + inheritedCost;
    end;

    if m_nodes[right].IsLeaf then
      rightDescentCost := PhysicCombine(leafAABB, m_nodes[right].aabb).SurfaceArea + inheritedCost
    else
    begin
      inflated := PhysicCombine(leafAABB, m_nodes[right].aabb).SurfaceArea;
      branchArea := m_nodes[right].aabb.SurfaceArea;
      rightDescentCost := inflated - branchArea + inheritedCost;
    end;

    if (branchCost < leftDescentCost) and (branchCost < rightDescentCost) then
      Break;

    if (leftDescentCost < rightDescentCost) then
      searchIndex := left
    else
      searchIndex := right;
  end;

  sibling := searchIndex;
  oldParent := m_nodes[sibling].parent;
  newParent := AllocateNode;
  m_nodes[newParent].parent := oldParent;
  m_nodes[newParent].userData := nil;
  m_nodes[newParent].aabb := PhysicCombine(leafAABB, m_nodes[sibling].aabb);
  m_nodes[newParent].height := m_nodes[sibling].height + 1;

  if (oldParent = PhysicTreeNull) then
  begin
    m_nodes[newParent].left := sibling;
    m_nodes[newParent].right := index;
    m_nodes[sibling].parent := newParent;
    m_nodes[index].parent := newParent;
    m_root := newParent;
  end
  else
  begin
    if (m_nodes[oldParent].left = sibling) then
      m_nodes[oldParent].left := newParent
    else
      m_nodes[oldParent].right := newParent;

    m_nodes[newParent].left := sibling;
    m_nodes[newParent].right := index;
    m_nodes[sibling].parent := newParent;
    m_nodes[index].parent := newParent;
  end;

  SyncHierarchy(m_nodes[index].parent);
end;

procedure TPhysicDynamicAABBTree.RemoveLeaf(index: Integer);
var
  parent, grandParent, sibling: Integer;
begin
  if (index = m_root) then
  begin
    m_root := PhysicTreeNull;
    Exit;
  end;

  parent := m_nodes[index].parent;
  grandParent := m_nodes[parent].parent;

  if (m_nodes[parent].left = index) then
    sibling := m_nodes[parent].right
  else
    sibling := m_nodes[parent].left;

  if (grandParent <> PhysicTreeNull) then
  begin
    if (m_nodes[grandParent].left = parent) then
      m_nodes[grandParent].left := sibling
    else
      m_nodes[grandParent].right := sibling;

    m_nodes[sibling].parent := grandParent;
  end
  else
  begin
    m_root := sibling;
    m_nodes[sibling].parent := PhysicTreeNull;
  end;

  DeallocateNode(parent);
  SyncHierarchy(grandParent);
end;

procedure TPhysicDynamicAABBTree.SyncHierarchy(index: Integer);
var
  left, right: Integer;
begin
  while (index <> PhysicTreeNull) do
  begin
    index := Balance(index);
    left := m_nodes[index].left;
    right := m_nodes[index].right;
    m_nodes[index].height := 1 + PhysicMax(m_nodes[left].height, m_nodes[right].height);
    m_nodes[index].aabb := PhysicCombine(m_nodes[left].aabb, m_nodes[right].aabb);
    index := m_nodes[index].parent;
  end;
end;

procedure TPhysicDynamicAABBTree.Validate;
begin
end;

//============================================================================
// TPhysicBroadPhase
//============================================================================

constructor TPhysicBroadPhase.Create(manager: TPhysicContactManager);
begin
  inherited Create;
  m_manager := manager;
  SetLength(m_pairBuffer, 64);
  SetLength(m_moveBuffer, 64);
  m_pairCount := 0;
  m_moveCount := 0;
  m_tree := TPhysicDynamicAABBTree.Create;
end;

destructor TPhysicBroadPhase.Destroy;
begin
  m_tree.Free;
  inherited;
end;

procedure TPhysicBroadPhase.InsertBox(box: TPhysicBox; const aabb: TPhysicAABB);
var
  id: Integer;
begin
  id := m_tree.Insert(aabb, box);
  box.broadPhaseIndex := id;
  BufferMove(id);
end;

procedure TPhysicBroadPhase.RemoveBox(box: TPhysicBox);
begin
  m_tree.Remove(box.broadPhaseIndex);
end;

function PhysicContactPairLess(const lhs, rhs: TPhysicContactPair): Boolean; inline;
begin
  if (lhs.A < rhs.A) then
    Exit(True);
  if (lhs.A = rhs.A) then
    Exit(lhs.B < rhs.B);
  Result := False;
end;

procedure TPhysicBroadPhase.SortPairs;
var
  i, j: Integer;
  key: TPhysicContactPair;
begin
  for i := 1 to m_pairCount - 1 do
  begin
    key := m_pairBuffer[i];
    j := i - 1;
    while (j >= 0) and PhysicContactPairLess(key, m_pairBuffer[j]) do
    begin
      m_pairBuffer[j + 1] := m_pairBuffer[j];
      Dec(j);
    end;
    m_pairBuffer[j + 1] := key;
  end;
end;

procedure TPhysicBroadPhase.UpdatePairs;
var
  i: Integer;
  aabb: TPhysicAABB;
  pair, potentialDup: TPhysicContactPair;
  boxA, boxB: TPhysicBox;
begin
  m_pairCount := 0;

  for i := 0 to m_moveCount - 1 do
  begin
    m_currentIndex := m_moveBuffer[i];
    aabb := m_tree.GetFatAABB(m_currentIndex);
    m_tree.Query(Self, aabb);
  end;

  m_moveCount := 0;
  SortPairs;

  i := 0;
  while (i < m_pairCount) do
  begin
    pair := m_pairBuffer[i];
    boxA := m_tree.GetUserData(pair.A);
    boxB := m_tree.GetUserData(pair.B);
    m_manager.AddContact(boxA, boxB);
    Inc(i);

    while (i < m_pairCount) do
    begin
      potentialDup := m_pairBuffer[i];
      if (pair.A <> potentialDup.A) or (pair.B <> potentialDup.B) then
        Break;
      Inc(i);
    end;
  end;

  m_tree.Validate;
end;

procedure TPhysicBroadPhase.Update(id: Integer; const aabb: TPhysicAABB);
begin
  if m_tree.Update(id, aabb) then
    BufferMove(id);
end;

function TPhysicBroadPhase.TestOverlap(A, B: Integer): Boolean;
begin
  Result := PhysicAABBToAABB(m_tree.GetFatAABB(A), m_tree.GetFatAABB(B));
end;

function TPhysicBroadPhase.TreeCallBack(index: Integer): Boolean;
begin
  if (index = m_currentIndex) then
    Exit(True);

  if (m_pairCount = Length(m_pairBuffer)) then
    SetLength(m_pairBuffer, Length(m_pairBuffer) * 2);

  m_pairBuffer[m_pairCount].A := PhysicMin(index, m_currentIndex);
  m_pairBuffer[m_pairCount].B := PhysicMax(index, m_currentIndex);
  Inc(m_pairCount);
  Result := True;
end;

procedure TPhysicBroadPhase.BufferMove(id: Integer);
begin
  if (m_moveCount = Length(m_moveBuffer)) then
    SetLength(m_moveBuffer, Length(m_moveBuffer) * 2);

  m_moveBuffer[m_moveCount] := id;
  Inc(m_moveCount);
end;

//============================================================================
// TPhysicContactManager
//============================================================================

constructor TPhysicContactManager.Create;
begin
  inherited Create;
  m_contactList := nil;
  m_contactCount := 0;
  m_contactListener := nil;
  m_broadphase := TPhysicBroadPhase.Create(Self);
end;

destructor TPhysicContactManager.Destroy;
begin
  while (m_contactList <> nil) do
    RemoveContact(m_contactList);

  m_broadphase.Free;
  inherited;
end;

procedure TPhysicContactManager.AddContact(A, B: TPhysicBox);
var
  bodyA, bodyB: TPhysicBody;
  edge: PPhysicContactEdge;
  contact: TPhysicContactConstraint;
  i: Integer;
begin
  bodyA := A.body;
  bodyB := B.body;
  if not bodyA.CanCollide(bodyB) then
    Exit;

  edge := bodyA.m_contactList;
  while (edge <> nil) do
  begin
    if (edge^.other = bodyB) then
    begin
      if (A = edge^.constraint.A) and (B = edge^.constraint.B) then
        Exit;
    end;
    edge := edge^.next;
  end;

  contact := TPhysicContactConstraint.Create;
  contact.A := A;
  contact.B := B;
  contact.bodyA := bodyA;
  contact.bodyB := bodyB;
  contact.manifold.SetPair(A, B);
  contact.m_flags := 0;
  contact.friction := PhysicMixFriction(A, B);
  contact.restitution := PhysicMixRestitution(A, B);
  contact.manifold.contactCount := 0;

  for i := 0 to 7 do
    contact.manifold.contacts[i].warmStarted := 0;

  contact.prev := nil;
  contact.next := m_contactList;
  if (m_contactList <> nil) then
    m_contactList.prev := contact;
  m_contactList := contact;

  contact.edgeA.constraint := contact;
  contact.edgeA.other := bodyB;
  contact.edgeA.prev := nil;
  contact.edgeA.next := bodyA.m_contactList;
  if (bodyA.m_contactList <> nil) then
    bodyA.m_contactList^.prev := @contact.edgeA;
  bodyA.m_contactList := @contact.edgeA;

  contact.edgeB.constraint := contact;
  contact.edgeB.other := bodyA;
  contact.edgeB.prev := nil;
  contact.edgeB.next := bodyB.m_contactList;
  if (bodyB.m_contactList <> nil) then
    bodyB.m_contactList^.prev := @contact.edgeB;
  bodyB.m_contactList := @contact.edgeB;

  bodyA.SetToAwake;
  bodyB.SetToAwake;
  Inc(m_contactCount);
end;

procedure TPhysicContactManager.FindNewContacts;
begin
  m_broadphase.UpdatePairs;
end;

procedure TPhysicContactManager.RemoveContact(contact: TPhysicContactConstraint);
var
  A, B: TPhysicBody;
begin
  A := contact.bodyA;
  B := contact.bodyB;

  if (contact.edgeA.prev <> nil) then
    contact.edgeA.prev^.next := contact.edgeA.next;
  if (contact.edgeA.next <> nil) then
    contact.edgeA.next^.prev := contact.edgeA.prev;
  if (@contact.edgeA = A.m_contactList) then
    A.m_contactList := contact.edgeA.next;

  if (contact.edgeB.prev <> nil) then
    contact.edgeB.prev^.next := contact.edgeB.next;
  if (contact.edgeB.next <> nil) then
    contact.edgeB.next^.prev := contact.edgeB.prev;
  if (@contact.edgeB = B.m_contactList) then
    B.m_contactList := contact.edgeB.next;

  A.SetToAwake;
  B.SetToAwake;

  if (contact.prev <> nil) then
    contact.prev.next := contact.next;
  if (contact.next <> nil) then
    contact.next.prev := contact.prev;
  if (contact = m_contactList) then
    m_contactList := contact.next;

  Dec(m_contactCount);
  contact.Free;
end;

procedure TPhysicContactManager.RemoveContactsFromBody(body: TPhysicBody);
var
  edge, nextEdge: PPhysicContactEdge;
begin
  edge := body.m_contactList;
  while (edge <> nil) do
  begin
    nextEdge := edge^.next;
    RemoveContact(edge^.constraint);
    edge := nextEdge;
  end;
end;

procedure TPhysicContactManager.RemoveFromBroadphase(body: TPhysicBody);
var
  box: TPhysicBox;
begin
  box := body.m_boxes;
  while (box <> nil) do
  begin
    m_broadphase.RemoveBox(box);
    box := box.next;
  end;
end;

procedure TPhysicContactManager.TestCollisions;
var
  constraint, nextConstraint: TPhysicContactConstraint;
  A, B: TPhysicBox;
  bodyA, bodyB: TPhysicBody;
  manifold, oldManifold: TPhysicManifold;
  ot0, ot1, friction: TVector3;
  i, j: Integer;
  c, oc: ^TPhysicContact;
  oldWarmStart: Byte;
  nowColliding, wasColliding: Boolean;
begin
  constraint := m_contactList;
  while (constraint <> nil) do
  begin
    A := constraint.A;
    B := constraint.B;
    bodyA := A.body;
    bodyB := B.body;
    constraint.m_flags := constraint.m_flags and not TPhysicContactConstraint.eIsland;

    if (not bodyA.IsAwake) and (not bodyB.IsAwake) then
    begin
      constraint := constraint.next;
      Continue;
    end;

    if not bodyA.CanCollide(bodyB) then
    begin
      nextConstraint := constraint.next;
      RemoveContact(constraint);
      constraint := nextConstraint;
      Continue;
    end;

    if not m_broadphase.TestOverlap(A.broadPhaseIndex, B.broadPhaseIndex) then
    begin
      nextConstraint := constraint.next;
      RemoveContact(constraint);
      constraint := nextConstraint;
      Continue;
    end;

    oldManifold := constraint.manifold;
    ot0 := oldManifold.tangentVectors[0];
    ot1 := oldManifold.tangentVectors[1];
    constraint.SolveCollision;
    manifold := constraint.manifold;
    PhysicComputeBasis(manifold.normal, manifold.tangentVectors[0], manifold.tangentVectors[1]);
    constraint.manifold.tangentVectors[0] := manifold.tangentVectors[0];
    constraint.manifold.tangentVectors[1] := manifold.tangentVectors[1];

    for i := 0 to constraint.manifold.contactCount - 1 do
    begin
      c := @constraint.manifold.contacts[i];
      c^.tangentImpulse[0] := 0.0;
      c^.tangentImpulse[1] := 0.0;
      c^.normalImpulse := 0.0;
      oldWarmStart := c^.warmStarted;
      c^.warmStarted := 0;

      for j := 0 to oldManifold.contactCount - 1 do
      begin
        oc := @oldManifold.contacts[j];
        if (c^.fp.key = oc^.fp.key) then
        begin
          c^.normalImpulse := oc^.normalImpulse;
          friction := ot0 * oc^.tangentImpulse[0] + ot1 * oc^.tangentImpulse[1];
          c^.tangentImpulse[0] := PhysicDot(friction, constraint.manifold.tangentVectors[0]);
          c^.tangentImpulse[1] := PhysicDot(friction, constraint.manifold.tangentVectors[1]);
          c^.warmStarted := PhysicMax(oldWarmStart, Byte(oldWarmStart + 1));
          Break;
        end;
      end;
    end;

    if (m_contactListener <> nil) then
    begin
      nowColliding := (constraint.m_flags and TPhysicContactConstraint.eColliding) <> 0;
      wasColliding := (constraint.m_flags and TPhysicContactConstraint.eWasColliding) <> 0;
      if nowColliding and (not wasColliding) then
        m_contactListener.BeginContact(constraint)
      else if (not nowColliding) and wasColliding then
        m_contactListener.EndContact(constraint);
    end;

    constraint := constraint.next;
  end;
end;

//============================================================================
// TPhysicBodyDef / TPhysicBody
//============================================================================

class function TPhysicBodyDef.Create: TPhysicBodyDef;
begin
  PhysicIdentity(Result.axis);
  Result.angle := 0.0;
  PhysicIdentity(Result.position);
  PhysicIdentity(Result.linearVelocity);
  PhysicIdentity(Result.angularVelocity);
  Result.gravityScale := 1.0;
  Result.bodyType := PhysicStaticBody;
  Result.layers := $00000001;
  Result.userData := nil;
  Result.allowSleep := True;
  Result.awake := True;
  Result.active := True;
  Result.lockAxisX := False;
  Result.lockAxisY := False;
  Result.lockAxisZ := False;
  Result.linearDamping := 0.0;
  Result.angularDamping := 0.1;
end;

constructor TPhysicBody.Create(const def: TPhysicBodyDef; scene: TPhysicScene);
begin
  inherited Create;
  m_linearVelocity := def.linearVelocity;
  m_angularVelocity := def.angularVelocity;
  PhysicIdentity(m_force);
  PhysicIdentity(m_torque);
  m_q.SetAxisAngle(PhysicNormalize(def.axis), def.angle);
  m_tx.rotation := m_q.ToMat3;
  m_tx.position := def.position;
  m_sleepTime := 0.0;
  m_gravityScale := def.gravityScale;
  m_layers := def.layers;
  m_userData := def.userData;
  m_scene := scene;
  m_flags := 0;
  m_linearDamping := def.linearDamping;
  m_angularDamping := def.angularDamping;
  m_mass := 0.0;
  m_invMass := 0.0;
  PhysicZero(m_invInertiaModel);
  PhysicZero(m_invInertiaWorld);

  case def.bodyType of
    PhysicDynamicBody:
      m_flags := m_flags or eDynamic;
    PhysicStaticBody:
      begin
        m_flags := m_flags or eStatic;
        PhysicIdentity(m_linearVelocity);
        PhysicIdentity(m_angularVelocity);
        PhysicIdentity(m_force);
        PhysicIdentity(m_torque);
      end;
    PhysicKinematicBody:
      m_flags := m_flags or eKinematic;
  end;

  if def.allowSleep then m_flags := m_flags or eAllowSleep;
  if def.awake then m_flags := m_flags or eAwake;
  if def.active then m_flags := m_flags or eActive;
  if def.lockAxisX then m_flags := m_flags or eLockAxisX;
  if def.lockAxisY then m_flags := m_flags or eLockAxisY;
  if def.lockAxisZ then m_flags := m_flags or eLockAxisZ;

  m_boxes := nil;
  m_contactList := nil;
  m_next := nil;
  m_prev := nil;
end;

destructor TPhysicBody.Destroy;
begin
  RemoveAllBoxes;
  inherited;
end;

function TPhysicBody.AddBox(const def: TPhysicBoxDef): TPhysicBox;
var
  aabb: TPhysicAABB;
begin
  Result := TPhysicBox.Create;
  Result.local := def.m_tx;
  Result.e := def.m_e;
  Result.next := m_boxes;
  m_boxes := Result;
  Result.ComputeAABB(m_tx, aabb);
  Result.body := Self;
  Result.friction := def.m_friction;
  Result.restitution := def.m_restitution;
  Result.density := def.m_density;
  Result.sensor := def.m_sensor;
  Result.userData := nil;

  CalculateMassData;
  m_scene.m_contactManager.m_broadphase.InsertBox(Result, aabb);
  m_scene.m_newBox := True;
end;

procedure TPhysicBody.RemoveBox(box: TPhysicBox);
var
  node: TPhysicBox;
  edge: PPhysicContactEdge;
  contact: TPhysicContactConstraint;
begin
  if (box = nil) then
    Exit;

  if (m_boxes = box) then
    m_boxes := box.next
  else
  begin
    node := m_boxes;
    while (node <> nil) and (node.next <> box) do
      node := node.next;
    if (node <> nil) then
      node.next := box.next;
  end;

  edge := m_contactList;
  while (edge <> nil) do
  begin
    contact := edge^.constraint;
    edge := edge^.next;
    if (box = contact.A) or (box = contact.B) then
      m_scene.m_contactManager.RemoveContact(contact);
  end;

  m_scene.m_contactManager.m_broadphase.RemoveBox(box);
  CalculateMassData;
  box.Free;
end;

procedure TPhysicBody.RemoveAllBoxes;
var
  box, nextBox: TPhysicBox;
begin
  if (m_scene <> nil) then
    m_scene.m_contactManager.RemoveContactsFromBody(Self);

  box := m_boxes;
  while (box <> nil) do
  begin
    nextBox := box.next;
    if (m_scene <> nil) then
      m_scene.m_contactManager.m_broadphase.RemoveBox(box);
    box.Free;
    box := nextBox;
  end;

  m_boxes := nil;
end;

procedure TPhysicBody.ApplyLinearForce(const force: TVector3);
begin
  m_force := m_force + force * m_mass;
  SetToAwake;
end;

procedure TPhysicBody.ApplyForceAtWorldPoint(const force, point: TVector3);
begin
  m_force := m_force + force * m_mass;
  m_torque := m_torque + PhysicCross(point - m_worldCenter, force);
  SetToAwake;
end;

procedure TPhysicBody.ApplyLinearImpulse(const impulse: TVector3);
begin
  m_linearVelocity := m_linearVelocity + impulse * m_invMass;
  SetToAwake;
end;

procedure TPhysicBody.ApplyLinearImpulseAtWorldPoint(const impulse, point: TVector3);
begin
  m_linearVelocity := m_linearVelocity + impulse * m_invMass;
  m_angularVelocity := m_angularVelocity + m_invInertiaWorld * PhysicCross(point - m_worldCenter, impulse);
  SetToAwake;
end;

procedure TPhysicBody.ApplyTorque(const torque: TVector3);
begin
  m_torque := m_torque + torque;
end;

procedure TPhysicBody.SetToAwake;
begin
  if ((m_flags and eAwake) = 0) then
  begin
    m_flags := m_flags or eAwake;
    m_sleepTime := 0.0;
  end;
end;

procedure TPhysicBody.SetToSleep;
begin
  m_flags := m_flags and not eAwake;
  m_sleepTime := 0.0;
  PhysicIdentity(m_linearVelocity);
  PhysicIdentity(m_angularVelocity);
  PhysicIdentity(m_force);
  PhysicIdentity(m_torque);
end;

function TPhysicBody.IsAwake: Boolean;
begin
  Result := (m_flags and eAwake) <> 0;
end;

function TPhysicBody.GetMass: Single;
begin
  Result := m_mass;
end;

function TPhysicBody.GetInvMass: Single;
begin
  Result := m_invMass;
end;

function TPhysicBody.GetGravityScale: Single;
begin
  Result := m_gravityScale;
end;

procedure TPhysicBody.SetGravityScale(scale: Single);
begin
  m_gravityScale := scale;
end;

function TPhysicBody.GetLocalPoint(const p: TVector3): TVector3;
begin
  Result := PhysicMulT(m_tx, p);
end;

function TPhysicBody.GetLocalVector(const v: TVector3): TVector3;
begin
  Result := PhysicMulT(m_tx.rotation, v);
end;

function TPhysicBody.GetWorldPoint(const p: TVector3): TVector3;
begin
  Result := PhysicMul(m_tx, p);
end;

function TPhysicBody.GetWorldVector(const v: TVector3): TVector3;
begin
  Result := m_tx.rotation * v;
end;

function TPhysicBody.GetLinearVelocity: TVector3;
begin
  Result := m_linearVelocity;
end;

function TPhysicBody.GetVelocityAtWorldPoint(const p: TVector3): TVector3;
begin
  Result := m_linearVelocity + PhysicCross(m_angularVelocity, p - m_worldCenter);
end;

procedure TPhysicBody.SetLinearVelocity(const v: TVector3);
begin
  if ((m_flags and eStatic) <> 0) then
    Assert(False);

  if (PhysicDot(v, v) > 0.0) then
    SetToAwake;

  m_linearVelocity := v;
end;

function TPhysicBody.GetAngularVelocity: TVector3;
begin
  Result := m_angularVelocity;
end;

procedure TPhysicBody.SetAngularVelocity(const v: TVector3);
begin
  if ((m_flags and eStatic) <> 0) then
    Assert(False);

  if (PhysicDot(v, v) > 0.0) then
    SetToAwake;

  m_angularVelocity := v;
end;

function TPhysicBody.CanCollide(other: TPhysicBody): Boolean;
begin
  if (Self = other) then
    Exit(False);

  if ((m_flags and eDynamic) = 0) and ((other.m_flags and eDynamic) = 0) then
    Exit(False);

  if ((m_layers and other.m_layers) = 0) then
    Exit(False);

  Result := True;
end;

function TPhysicBody.GetTransform: TPhysicTransform;
begin
  Result := m_tx;
end;

procedure TPhysicBody.SetTransform(const position: TVector3);
begin
  m_worldCenter := position;
  SynchronizeProxies;
end;

procedure TPhysicBody.SetTransform(const position, axis: TVector3; angle: Single);
begin
  m_worldCenter := position;
  m_q.SetAxisAngle(axis, angle);
  m_tx.rotation := m_q.ToMat3;
  SynchronizeProxies;
end;

function TPhysicBody.GetFlags: Integer;
begin
  Result := m_flags;
end;

procedure TPhysicBody.SetLayers(layers: Integer);
begin
  m_layers := layers;
end;

function TPhysicBody.GetLayers: Integer;
begin
  Result := m_layers;
end;

function TPhysicBody.GetQuaternion: TPhysicQuaternion;
begin
  Result := m_q;
end;

function TPhysicBody.GetUserData: Pointer;
begin
  Result := m_userData;
end;

procedure TPhysicBody.SetLinearDamping(damping: Single);
begin
  m_linearDamping := damping;
end;

function TPhysicBody.GetLinearDamping: Single;
begin
  Result := m_linearDamping;
end;

procedure TPhysicBody.SetAngularDamping(damping: Single);
begin
  m_angularDamping := damping;
end;

function TPhysicBody.GetAngularDamping: Single;
begin
  Result := m_angularDamping;
end;

function TPhysicBody.GetFirstBox: TPhysicBox;
begin
  Result := m_boxes;
end;

function TPhysicBody.GetNext: TPhysicBody;
begin
  Result := m_next;
end;

procedure TPhysicBody.CalculateMassData;
var
  inertia, identity: TPhysicMat3;
  mass: Single;
  lc: TVector3;
  box: TPhysicBox;
  md: TPhysicMassData;
begin
  inertia := PhysicDiagonal(0.0);
  m_invInertiaModel := PhysicDiagonal(0.0);
  m_invInertiaWorld := PhysicDiagonal(0.0);
  m_invMass := 0.0;
  m_mass := 0.0;
  mass := 0.0;

  if ((m_flags and eStatic) <> 0) or ((m_flags and eKinematic) <> 0) then
  begin
    PhysicIdentity(m_localCenter);
    m_worldCenter := m_tx.position;
    Exit;
  end;

  PhysicIdentity(lc);
  box := m_boxes;
  while (box <> nil) do
  begin
    if (box.density <> 0.0) then
    begin
      box.ComputeMass(md);
      mass := mass + md.mass;
      inertia := inertia + md.inertia;
      lc := lc + md.center * md.mass;
    end;
    box := box.next;
  end;

  if (mass > 0.0) then
  begin
    m_mass := mass;
    m_invMass := 1.0 / mass;
    lc := lc * m_invMass;
    PhysicIdentity(identity);
    inertia := inertia - (identity * PhysicDot(lc, lc) - PhysicOuterProduct(lc, lc)) * mass;
    m_invInertiaModel := PhysicInverse(inertia);

    if ((m_flags and eLockAxisX) <> 0) then PhysicIdentity(m_invInertiaModel.ex);
    if ((m_flags and eLockAxisY) <> 0) then PhysicIdentity(m_invInertiaModel.ey);
    if ((m_flags and eLockAxisZ) <> 0) then PhysicIdentity(m_invInertiaModel.ez);
  end
  else
  begin
    m_invMass := 1.0;
    m_invInertiaModel := PhysicDiagonal(0.0);
    m_invInertiaWorld := PhysicDiagonal(0.0);
  end;

  m_localCenter := lc;
  m_worldCenter := PhysicMul(m_tx, lc);
end;

procedure TPhysicBody.SynchronizeProxies;
var
  aabb: TPhysicAABB;
  box: TPhysicBox;
begin
  m_tx.position := m_worldCenter - m_tx.rotation * m_localCenter;

  box := m_boxes;
  while (box <> nil) do
  begin
    box.ComputeAABB(m_tx, aabb);
    m_scene.m_contactManager.m_broadphase.Update(box.broadPhaseIndex, aabb);
    box := box.next;
  end;
end;

//============================================================================
// TPhysicContactSolver / TPhysicIsland
//============================================================================

procedure TPhysicContactSolver.Initialize(var island: TPhysicIsland);
begin
  m_island := @island;
  m_contactCount := island.m_contactCount;
  m_enableFriction := island.m_enableFriction;
end;

procedure TPhysicContactSolver.ShutDown;
var
  i, j: Integer;
  c: ^TPhysicContactConstraintState;
  cc: TPhysicContactConstraint;
begin
  for i := 0 to m_contactCount - 1 do
  begin
    c := @m_island^.m_contactStates[i];
    cc := m_island^.m_contacts[i];
    for j := 0 to c^.contactCount - 1 do
    begin
      cc.manifold.contacts[j].normalImpulse := c^.contacts[j].normalImpulse;
      cc.manifold.contacts[j].tangentImpulse[0] := c^.contacts[j].tangentImpulse[0];
      cc.manifold.contacts[j].tangentImpulse[1] := c^.contacts[j].tangentImpulse[1];
    end;
  end;
end;

procedure TPhysicContactSolver.PreSolve(dt: Single);
var
  i, j, k: Integer;
  cs: ^TPhysicContactConstraintState;
  c: ^TPhysicContactState;
  vA, wA, vB, wB, raCn, rbCn, raCt, rbCt, P: TVector3;
  nm, dv: Single;
  tm: array[0..1] of Single;
begin
  for i := 0 to m_contactCount - 1 do
  begin
    cs := @m_island^.m_contactStates[i];
    vA := m_island^.m_velocities[cs^.indexA].v;
    wA := m_island^.m_velocities[cs^.indexA].w;
    vB := m_island^.m_velocities[cs^.indexB].v;
    wB := m_island^.m_velocities[cs^.indexB].w;

    for j := 0 to cs^.contactCount - 1 do
    begin
      c := @cs^.contacts[j];
      raCn := PhysicCross(c^.ra, cs^.normal);
      rbCn := PhysicCross(c^.rb, cs^.normal);
      nm := cs^.mA + cs^.mB;
      tm[0] := nm;
      tm[1] := nm;
      nm := nm + PhysicDot(raCn, cs^.iA * raCn) + PhysicDot(rbCn, cs^.iB * rbCn);
      c^.normalMass := PhysicInvert(nm);

      for k := 0 to 1 do
      begin
        raCt := PhysicCross(cs^.tangentVectors[k], c^.ra);
        rbCt := PhysicCross(cs^.tangentVectors[k], c^.rb);
        tm[k] := tm[k] + PhysicDot(raCt, cs^.iA * raCt) + PhysicDot(rbCt, cs^.iB * rbCt);
        c^.tangentMass[k] := PhysicInvert(tm[k]);
      end;

      c^.bias := -Q3_BAUMGARTE * (1.0 / dt) * PhysicMin(0.0, c^.penetration + Q3_PENETRATION_SLOP);
      P := cs^.normal * c^.normalImpulse;

      if m_enableFriction then
      begin
        P := P + cs^.tangentVectors[0] * c^.tangentImpulse[0];
        P := P + cs^.tangentVectors[1] * c^.tangentImpulse[1];
      end;

      vA := vA - P * cs^.mA;
      wA := wA - cs^.iA * PhysicCross(c^.ra, P);
      vB := vB + P * cs^.mB;
      wB := wB + cs^.iB * PhysicCross(c^.rb, P);

      dv := PhysicDot(vB + PhysicCross(wB, c^.rb) - vA - PhysicCross(wA, c^.ra), cs^.normal);
      if (dv < -1.0) then
        c^.bias := c^.bias + -(cs^.restitution) * dv;
    end;

    m_island^.m_velocities[cs^.indexA].v := vA;
    m_island^.m_velocities[cs^.indexA].w := wA;
    m_island^.m_velocities[cs^.indexB].v := vB;
    m_island^.m_velocities[cs^.indexB].w := wB;
  end;
end;

procedure TPhysicContactSolver.Solve;
var
  i, j, k: Integer;
  cs: ^TPhysicContactConstraintState;
  c: ^TPhysicContactState;
  vA, wA, vB, wB, dv, impulse: TVector3;
  lambda, maxLambda, oldPT, vn, tempPN: Single;
begin
  for i := 0 to m_contactCount - 1 do
  begin
    cs := @m_island^.m_contactStates[i];
    vA := m_island^.m_velocities[cs^.indexA].v;
    wA := m_island^.m_velocities[cs^.indexA].w;
    vB := m_island^.m_velocities[cs^.indexB].v;
    wB := m_island^.m_velocities[cs^.indexB].w;

    for j := 0 to cs^.contactCount - 1 do
    begin
      c := @cs^.contacts[j];
      dv := vB + PhysicCross(wB, c^.rb) - vA - PhysicCross(wA, c^.ra);

      if m_enableFriction then
      begin
        for k := 0 to 1 do
        begin
          lambda := -PhysicDot(dv, cs^.tangentVectors[k]) * c^.tangentMass[k];
          maxLambda := cs^.friction * c^.normalImpulse;
          oldPT := c^.tangentImpulse[k];
          c^.tangentImpulse[k] := PhysicClamp(-maxLambda, maxLambda, oldPT + lambda);
          lambda := c^.tangentImpulse[k] - oldPT;

          impulse := cs^.tangentVectors[k] * lambda;
          vA := vA - impulse * cs^.mA;
          wA := wA - cs^.iA * PhysicCross(c^.ra, impulse);
          vB := vB + impulse * cs^.mB;
          wB := wB + cs^.iB * PhysicCross(c^.rb, impulse);
        end;
      end;

      dv := vB + PhysicCross(wB, c^.rb) - vA - PhysicCross(wA, c^.ra);
      vn := PhysicDot(dv, cs^.normal);
      lambda := c^.normalMass * (-vn + c^.bias);
      tempPN := c^.normalImpulse;
      c^.normalImpulse := PhysicMax(tempPN + lambda, 0.0);
      lambda := c^.normalImpulse - tempPN;

      impulse := cs^.normal * lambda;
      vA := vA - impulse * cs^.mA;
      wA := wA - cs^.iA * PhysicCross(c^.ra, impulse);
      vB := vB + impulse * cs^.mB;
      wB := wB + cs^.iB * PhysicCross(c^.rb, impulse);
    end;

    m_island^.m_velocities[cs^.indexA].v := vA;
    m_island^.m_velocities[cs^.indexA].w := wA;
    m_island^.m_velocities[cs^.indexB].v := vB;
    m_island^.m_velocities[cs^.indexB].w := wB;
  end;
end;

procedure TPhysicIsland.Solve;
var
  i: Integer;
  body: TPhysicBody;
  velocity: ^TPhysicVelocityState;
  r: TPhysicMat3;
  contactSolver: TPhysicContactSolver;
  minSleepTime, sqrLinVel, cbAngVel: Single;
begin
  for i := 0 to m_bodyCount - 1 do
  begin
    body := m_bodies[i];
    velocity := @m_velocities[i];

    if ((body.m_flags and TPhysicBody.eDynamic) <> 0) then
    begin
      body.ApplyLinearForce(m_gravity * body.m_gravityScale);
      r := body.m_tx.rotation;
      body.m_invInertiaWorld := r * body.m_invInertiaModel * PhysicTranspose(r);
      body.m_linearVelocity := body.m_linearVelocity + (body.m_force * body.m_invMass) * m_dt;
      body.m_angularVelocity := body.m_angularVelocity + (body.m_invInertiaWorld * body.m_torque) * m_dt;
      body.m_linearVelocity := body.m_linearVelocity * (1.0 / (1.0 + m_dt * body.m_linearDamping));
      body.m_angularVelocity := body.m_angularVelocity * (1.0 / (1.0 + m_dt * body.m_angularDamping));
    end;

    velocity^.v := body.m_linearVelocity;
    velocity^.w := body.m_angularVelocity;
  end;

  contactSolver.Initialize(Self);
  contactSolver.PreSolve(m_dt);
  for i := 0 to m_iterations - 1 do
    contactSolver.Solve;
  contactSolver.ShutDown;

  for i := 0 to m_bodyCount - 1 do
  begin
    body := m_bodies[i];
    velocity := @m_velocities[i];

    if ((body.m_flags and TPhysicBody.eStatic) <> 0) then
      Continue;

    body.m_linearVelocity := velocity^.v;
    body.m_angularVelocity := velocity^.w;
    body.m_worldCenter := body.m_worldCenter + body.m_linearVelocity * m_dt;
    body.m_q.Integrate(body.m_angularVelocity, m_dt);
    body.m_q := PhysicNormalize(body.m_q);
    body.m_tx.rotation := body.m_q.ToMat3;
  end;

  if m_allowSleep then
  begin
    minSleepTime := Q3_R32_MAX;
    for i := 0 to m_bodyCount - 1 do
    begin
      body := m_bodies[i];
      if ((body.m_flags and TPhysicBody.eStatic) <> 0) then
        Continue;

      sqrLinVel := PhysicDot(body.m_linearVelocity, body.m_linearVelocity);
      cbAngVel := PhysicDot(body.m_angularVelocity, body.m_angularVelocity);

      if (sqrLinVel > Q3_SLEEP_LINEAR) or (cbAngVel > Q3_SLEEP_ANGULAR) then
      begin
        minSleepTime := 0.0;
        body.m_sleepTime := 0.0;
      end
      else
      begin
        body.m_sleepTime := body.m_sleepTime + m_dt;
        minSleepTime := PhysicMin(minSleepTime, body.m_sleepTime);
      end;
    end;

    if (minSleepTime > Q3_SLEEP_TIME) then
      for i := 0 to m_bodyCount - 1 do
        m_bodies[i].SetToSleep;
  end;
end;

procedure TPhysicIsland.AddBody(body: TPhysicBody);
begin
  body.m_islandIndex := m_bodyCount;
  m_bodies[m_bodyCount] := body;
  Inc(m_bodyCount);
end;

procedure TPhysicIsland.AddContact(contact: TPhysicContactConstraint);
begin
  m_contacts[m_contactCount] := contact;
  Inc(m_contactCount);
end;

procedure TPhysicIsland.Initialize;
var
  i, j: Integer;
  cc: TPhysicContactConstraint;
  c: ^TPhysicContactConstraintState;
  s: ^TPhysicContactState;
  cp: ^TPhysicContact;
begin
  for i := 0 to m_contactCount - 1 do
  begin
    cc := m_contacts[i];
    c := @m_contactStates[i];
    c^.centerA := cc.bodyA.m_worldCenter;
    c^.centerB := cc.bodyB.m_worldCenter;
    c^.iA := cc.bodyA.m_invInertiaWorld;
    c^.iB := cc.bodyB.m_invInertiaWorld;
    c^.mA := cc.bodyA.m_invMass;
    c^.mB := cc.bodyB.m_invMass;
    c^.restitution := cc.restitution;
    c^.friction := cc.friction;
    c^.indexA := cc.bodyA.m_islandIndex;
    c^.indexB := cc.bodyB.m_islandIndex;
    c^.normal := cc.manifold.normal;
    c^.tangentVectors[0] := cc.manifold.tangentVectors[0];
    c^.tangentVectors[1] := cc.manifold.tangentVectors[1];
    c^.contactCount := cc.manifold.contactCount;

    for j := 0 to c^.contactCount - 1 do
    begin
      s := @c^.contacts[j];
      cp := @cc.manifold.contacts[j];
      s^.ra := cp^.position - c^.centerA;
      s^.rb := cp^.position - c^.centerB;
      s^.penetration := cp^.penetration;
      s^.normalImpulse := cp^.normalImpulse;
      s^.tangentImpulse[0] := cp^.tangentImpulse[0];
      s^.tangentImpulse[1] := cp^.tangentImpulse[1];
    end;
  end;
end;

//============================================================================
// TPhysicScene queries
//============================================================================

function TPhysicSceneAABBQuery.TreeCallBack(index: Integer): Boolean;
var
  box: TPhysicBox;
  worldAABB: TPhysicAABB;
begin
  box := broadPhase.m_tree.GetUserData(index);
  box.ComputeAABB(box.body.GetTransform, worldAABB);
  if PhysicAABBToAABB(aabb, worldAABB) then
    Exit(cb.ReportShape(box));

  Result := True;
end;

function TPhysicScenePointQuery.TreeCallBack(index: Integer): Boolean;
var
  box: TPhysicBox;
begin
  box := broadPhase.m_tree.GetUserData(index);
  if box.TestPoint(box.body.GetTransform, point) then
    cb.ReportShape(box);
  Result := True;
end;

function TPhysicSceneRayQuery.TreeCallBack(index: Integer): Boolean;
var
  box: TPhysicBox;
begin
  box := broadPhase.m_tree.GetUserData(index);
  if box.Raycast(box.body.GetTransform, rayCast^) then
    Exit(cb.ReportShape(box));
  Result := True;
end;

//============================================================================
// TPhysicScene
//============================================================================

constructor TPhysicScene.Create(dt: Single; iterations: Integer);
begin
  Create(dt, PhysicVec3(0.0, -9.8, 0.0), iterations);
end;

constructor TPhysicScene.Create(dt: Single; const gravity: TVector3; iterations: Integer);
begin
  inherited Create;
  m_contactManager := TPhysicContactManager.Create;
  m_bodyCount := 0;
  m_bodyList := nil;
  m_gravity := gravity;
  m_dt := dt;
  m_iterations := iterations;
  m_newBox := False;
  m_allowSleep := True;
  m_enableFriction := True;
end;

destructor TPhysicScene.Destroy;
begin
  Shutdown;
  m_contactManager.Free;
  inherited;
end;

procedure TPhysicScene.Step;
var
  body, seed, other: TPhysicBody;
  island: TPhysicIsland;
  stack: array of TPhysicBody;
  stackCount, stackSize, i: Integer;
  edge: PPhysicContactEdge;
  contact: TPhysicContactConstraint;
begin
  if m_newBox then
  begin
    m_contactManager.m_broadphase.UpdatePairs;
    m_newBox := False;
  end;

  m_contactManager.TestCollisions;

  body := m_bodyList;
  while (body <> nil) do
  begin
    body.m_flags := body.m_flags and not TPhysicBody.eIsland;
    body := body.m_next;
  end;

  island.m_bodyCapacity := m_bodyCount;
  island.m_contactCapacity := m_contactManager.m_contactCount;
  SetLength(island.m_bodies, island.m_bodyCapacity);
  SetLength(island.m_velocities, island.m_bodyCapacity);
  SetLength(island.m_contacts, island.m_contactCapacity);
  SetLength(island.m_contactStates, island.m_contactCapacity);
  island.m_allowSleep := m_allowSleep;
  island.m_enableFriction := m_enableFriction;
  island.m_dt := m_dt;
  island.m_gravity := m_gravity;
  island.m_iterations := m_iterations;

  stackSize := m_bodyCount;
  SetLength(stack, stackSize);
  seed := m_bodyList;
  while (seed <> nil) do
  begin
    if ((seed.m_flags and TPhysicBody.eIsland) <> 0) or
       ((seed.m_flags and TPhysicBody.eAwake) = 0) or
       ((seed.m_flags and TPhysicBody.eStatic) <> 0) then
    begin
      seed := seed.m_next;
      Continue;
    end;

    stackCount := 0;
    stack[stackCount] := seed;
    Inc(stackCount);
    island.m_bodyCount := 0;
    island.m_contactCount := 0;
    seed.m_flags := seed.m_flags or TPhysicBody.eIsland;

    while (stackCount > 0) do
    begin
      Dec(stackCount);
      body := stack[stackCount];
      island.AddBody(body);
      body.SetToAwake;

      if ((body.m_flags and TPhysicBody.eStatic) <> 0) then
        Continue;

      edge := body.m_contactList;
      while (edge <> nil) do
      begin
        contact := edge^.constraint;
        if ((contact.m_flags and TPhysicContactConstraint.eIsland) <> 0) or
           ((contact.m_flags and TPhysicContactConstraint.eColliding) = 0) or
           contact.A.sensor or contact.B.sensor then
        begin
          edge := edge^.next;
          Continue;
        end;

        contact.m_flags := contact.m_flags or TPhysicContactConstraint.eIsland;
        island.AddContact(contact);
        other := edge^.other;
        if ((other.m_flags and TPhysicBody.eIsland) = 0) then
        begin
          stack[stackCount] := other;
          Inc(stackCount);
          other.m_flags := other.m_flags or TPhysicBody.eIsland;
        end;
        edge := edge^.next;
      end;
    end;

    island.Initialize;
    island.Solve;

    for i := 0 to island.m_bodyCount - 1 do
    begin
      body := island.m_bodies[i];
      if ((body.m_flags and TPhysicBody.eStatic) <> 0) then
        body.m_flags := body.m_flags and not TPhysicBody.eIsland;
    end;

    seed := seed.m_next;
  end;

  body := m_bodyList;
  while (body <> nil) do
  begin
    if ((body.m_flags and TPhysicBody.eStatic) = 0) then
      body.SynchronizeProxies;
    body := body.m_next;
  end;

  m_contactManager.FindNewContacts;

  body := m_bodyList;
  while (body <> nil) do
  begin
    PhysicIdentity(body.m_force);
    PhysicIdentity(body.m_torque);
    body := body.m_next;
  end;
end;

function TPhysicScene.CreateBody(const def: TPhysicBodyDef): TPhysicBody;
begin
  Result := TPhysicBody.Create(def, Self);
  Result.m_prev := nil;
  Result.m_next := m_bodyList;
  if (m_bodyList <> nil) then
    m_bodyList.m_prev := Result;
  m_bodyList := Result;
  Inc(m_bodyCount);
end;

procedure TPhysicScene.RemoveBody(body: TPhysicBody);
begin
  if (body = nil) then
    Exit;

  m_contactManager.RemoveContactsFromBody(body);
  body.RemoveAllBoxes;

  if (body.m_next <> nil) then
    body.m_next.m_prev := body.m_prev;
  if (body.m_prev <> nil) then
    body.m_prev.m_next := body.m_next;
  if (body = m_bodyList) then
    m_bodyList := body.m_next;

  Dec(m_bodyCount);
  body.m_scene := nil;
  body.Free;
end;

procedure TPhysicScene.RemoveAllBodies;
var
  body, nextBody: TPhysicBody;
begin
  body := m_bodyList;
  while (body <> nil) do
  begin
    nextBody := body.m_next;
    body.m_scene := Self;
    body.RemoveAllBoxes;
    body.m_scene := nil;
    body.Free;
    body := nextBody;
  end;

  m_bodyList := nil;
  m_bodyCount := 0;
end;

procedure TPhysicScene.SetAllowSleep(allowSleep: Boolean);
var
  body: TPhysicBody;
begin
  m_allowSleep := allowSleep;
  if not allowSleep then
  begin
    body := m_bodyList;
    while (body <> nil) do
    begin
      body.SetToAwake;
      body := body.m_next;
    end;
  end;
end;

procedure TPhysicScene.SetIterations(iterations: Integer);
begin
  m_iterations := PhysicMax(1, iterations);
end;

procedure TPhysicScene.SetEnableFriction(enabled: Boolean);
begin
  m_enableFriction := enabled;
end;

function TPhysicScene.GetGravity: TVector3;
begin
  Result := m_gravity;
end;

procedure TPhysicScene.SetGravity(const gravity: TVector3);
begin
  m_gravity := gravity;
end;

procedure TPhysicScene.Shutdown;
begin
  RemoveAllBodies;
end;

procedure TPhysicScene.SetContactListener(listener: TPhysicContactListener);
begin
  m_contactManager.m_contactListener := listener;
end;

procedure TPhysicScene.QueryAABB(cb: TPhysicQueryCallback; const aabb: TPhysicAABB);
var
  wrapper: TPhysicSceneAABBQuery;
begin
  wrapper := TPhysicSceneAABBQuery.Create;
  try
    wrapper.cb := cb;
    wrapper.broadPhase := m_contactManager.m_broadphase;
    wrapper.aabb := aabb;
    m_contactManager.m_broadphase.m_tree.Query(wrapper, aabb);
  finally
    wrapper.Free;
  end;
end;

procedure TPhysicScene.QueryPoint(cb: TPhysicQueryCallback; const point: TVector3);
var
  wrapper: TPhysicScenePointQuery;
  aabb: TPhysicAABB;
  v: TVector3;
begin
  wrapper := TPhysicScenePointQuery.Create;
  try
    wrapper.cb := cb;
    wrapper.broadPhase := m_contactManager.m_broadphase;
    wrapper.point := point;
    v := PhysicVec3(0.5, 0.5, 0.5);
    aabb.min := point - v;
    aabb.max := point + v;
    m_contactManager.m_broadphase.m_tree.Query(wrapper, aabb);
  finally
    wrapper.Free;
  end;
end;

procedure TPhysicScene.RayCast(cb: TPhysicQueryCallback; var rayCast: TPhysicRaycastData);
var
  wrapper: TPhysicSceneRayQuery;
begin
  wrapper := TPhysicSceneRayQuery.Create;
  try
    wrapper.cb := cb;
    wrapper.broadPhase := m_contactManager.m_broadphase;
    wrapper.rayCast := @rayCast;
    m_contactManager.m_broadphase.m_tree.Query(wrapper, rayCast);
  finally
    wrapper.Free;
  end;
end;

function TPhysicScene.GetFirstBody: TPhysicBody;
begin
  Result := m_bodyList;
end;

function TPhysicScene.GetBodyCount: Integer;
begin
  Result := m_bodyCount;
end;

end.
