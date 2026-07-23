unit Engine.Physics;

interface

uses
  System.SysUtils, System.Classes, System.Math, System.Generics.Collections, Winapi.Windows,
  dglOpenGL,
  Neslib.FastMath,
  Managers.Scene, Renderer.Mesh, Renderer.Mesh.List, Engine.Types,
  Kraft, PasMP;

type
  TPhysicsBody = class;
  TPhysicsWorld = class;

  TPhysicsBodyState = record
    BodyType: TPhysicsBodyType;
    ColliderKind: TPhysicsColliderKind;
    Enabled: Boolean;
    CollisionResponse: Boolean;
    UseGravity: Boolean;
    Mass: Single;
    Restitution: Single;
    LinearDamping: Single;
    GravityScale: Single;
    Velocity: TVector3;
    AngularVelocity: TVector3;
    AngularDamping: Single;
    Radius: Single;
    HalfHeight: Single;
    AABBHalfExtents: TVector3;
    StepHeight: Single;
  end;

  TPhysicsHit = record
    Hit: Boolean;
    Body: TPhysicsBody;
    Point: TVector3;
    Normal: TVector3;
    Time: Single;
    Penetration: Single;
    procedure Clear;
  end;

  TPhysicsCollision = record
    BodyA: TPhysicsBody;
    BodyB: TPhysicsBody;
    Point: TVector3;
    Normal: TVector3;
    Penetration: Single;
  end;

  TPhysicsTransformSnapshot = record
    Body: TPhysicsBody;
    SceneObject: TSceneObject;
    Position: TVector3;
    Scale: TVector3;
    Orientation: TQuaternion;
    Velocity: TVector3;
    BodyState: TPhysicsBodyState;
  end;

  TPhysicsCookedMeshCacheEntry = class
  public
    Signature: UInt64;
    Data: TBytes;
  end;

  TPhysicsCollisionEvent = procedure(const Collision: TPhysicsCollision) of object;

  TEnginePhysicsContactListener = class
  private
    fWorld: TPhysicsWorld;
  public
    constructor Create(AWorld: TPhysicsWorld);
    procedure BeginContact(const ContactPair: PKraftContactPair);
    procedure EndContact(const ContactPair: PKraftContactPair);
  end;

  TPhysicsBody = class
  private
    fSceneObject: TSceneObject;
    fBodyType: TPhysicsBodyType;
    fColliderKind: TPhysicsColliderKind;
    fEnabled: Boolean;
    fCollisionResponse: Boolean;
    fUseGravity: Boolean;
    fIsGrounded: Boolean;
    fSleeping: Boolean;
    fHasContact: Boolean;

    fMass: Single;
    fInverseMass: Single;
    fRestitution: Single;
    fLinearDamping: Single;
    fGravityScale: Single;

    fVelocity: TVector3;
    fAngularVelocity: TVector3;
    fForce: TVector3;
    fAngularDamping: Single;

    fRadius: Single;
    fHalfHeight: Single;
    fAABBHalfExtents: TVector3;
    fStepHeight: Single;

    fNativeBody: TKraftRigidBody;
    fNativeShape: TKraftShape;
    fNativeMeshes: TObjectList<TKraftMesh>;
    fNativeConvexHulls: TObjectList<TKraftConvexHull>;
    fLastNativeTransform: TKraftMatrix4x4;
    fLastNativeMeshSignature: UInt64;

    fOnCollision: TPhysicsCollisionEvent;

    fLastNativePosition: TVector3;
    fLastNativeScale: TVector3;
    fWorld: TPhysicsWorld;

    procedure SetBodyType(const Value: TPhysicsBodyType);
    procedure SetMass(const Value: Single);
    procedure UpdateInverseMass;
    procedure Wake;

    procedure SetVelocity(const Value: TVector3);
    procedure SetAngularVelocity(const Value: TVector3);

    procedure SetColliderKind(const Value: TPhysicsColliderKind);
    procedure SetEnabled(const Value: Boolean);
    procedure SetCollisionResponse(const Value: Boolean);
    procedure SetRadius(const Value: Single);
    procedure SetHalfHeight(const Value: Single);
    procedure SetAABBHalfExtents(const Value: TVector3);
    procedure SetUseGravity(const Value: Boolean);
    procedure SetRestitution(const Value: Single);
    procedure SetLinearDamping(const Value: Single);
    procedure SetGravityScale(const Value: Single);
    procedure SetAngularDamping(const Value: Single);

    procedure NativeShapeChanged;
    procedure RemoveNativeBody;
  public
    constructor Create(AWorld: TPhysicsWorld; ASceneObject: TSceneObject);
    destructor Destroy; override;

    function IsDynamic: Boolean;
    function HasFiniteMass: Boolean;
    function EffectiveColliderKind: TPhysicsColliderKind;

    procedure AutoFitColliderFromScene;
    procedure ConfigureSphere(ARadius: Single);
    procedure ConfigureCapsule(ARadius, AHalfHeight: Single);
    procedure ConfigureAABB(const AHalfExtents: TVector3);
    procedure ConfigureMesh;

    procedure AddForce(const Force: TVector3);
    procedure AddImpulse(const Impulse: TVector3);
    procedure ClearForces;
    procedure Stop;

    procedure SaveToStream(Stream: TStream);
    procedure LoadFromStream(Stream: TStream);
    function GetState: TPhysicsBodyState;
    procedure ApplyState(const State: TPhysicsBodyState);

    property SceneObject: TSceneObject read fSceneObject;
    property BodyType: TPhysicsBodyType read fBodyType write SetBodyType;
    property ColliderKind: TPhysicsColliderKind read fColliderKind write SetColliderKind;
    property Enabled: Boolean read fEnabled write SetEnabled;
    property CollisionResponse: Boolean read fCollisionResponse write SetCollisionResponse;
    property UseGravity: Boolean read fUseGravity write SetUseGravity;
    property IsGrounded: Boolean read fIsGrounded;
    property Sleeping: Boolean read fSleeping;
    property HasContact: Boolean read fHasContact;

    property Mass: Single read fMass write SetMass;
    property InverseMass: Single read fInverseMass;
    property Restitution: Single read fRestitution write SetRestitution;
    property LinearDamping: Single read fLinearDamping write SetLinearDamping;
    property GravityScale: Single read fGravityScale write SetGravityScale;
    property Velocity: TVector3 read fVelocity write SetVelocity;
    property AngularVelocity: TVector3 read fAngularVelocity write SetAngularVelocity;
    property AngularDamping: Single read fAngularDamping write SetAngularDamping;

    property Radius: Single read fRadius write SetRadius;
    property HalfHeight: Single read fHalfHeight write SetHalfHeight;
    property AABBHalfExtents: TVector3 read fAABBHalfExtents write SetAABBHalfExtents;
    property StepHeight: Single read fStepHeight write fStepHeight;

    property OnCollision: TPhysicsCollisionEvent read fOnCollision write fOnCollision;
  end;

  TPhysicsWorld = class
  private
    fSceneRoot: TSceneObject;
    fBodies: TObjectList<TPhysicsBody>;
    fGravity: TVector3;
    fGlobalDamping: Single;
    fMaxSubStep: Single;
    fMaxSubSteps: Integer;
    fSolverIterations: Integer;
    fGroundPlaneEnabled: Boolean;
    fGroundHeight: Single;
    fGroundNormal: TVector3;
    fCollisionSlop: Single;
    fTransformBackup: TList<TPhysicsTransformSnapshot>;
    fStagedBodyStates: TDictionary<TSceneObject, TPhysicsBodyState>;
    fCookedMeshCaches: TObjectDictionary<TSceneObject, TPhysicsCookedMeshCacheEntry>;
    fHasTransformBackup: Boolean;
    fNativeScene: TKraft;
    fNativeStep: Single;
    fAccumulator: Single;
    fNativeContactListener: TEnginePhysicsContactListener;
    fPasMP: TPasMP;

    function GetBody(Index: Integer): TPhysicsBody;
    function GetBodyCount: Integer;

    function GetWorldPosition(Obj: TSceneObject): TVector3;
    procedure SetWorldPosition(Obj: TSceneObject; const WorldPosition: TVector3);
    function GetWorldScale(Obj: TSceneObject): TVector3;
    function BuildBodyMeshSignature(Body: TPhysicsBody): UInt64;
    function TryGetCookedMeshCache(ASceneObject: TSceneObject;
      Signature: UInt64; out Data: TBytes): Boolean;

    function BodyAABBHalfExtents(Body: TPhysicsBody): TVector3;
    function TryBuildBodyAABB(Body: TPhysicsBody; out MinBounds, MaxBounds: TVector3): Boolean;
    function TryBuildObjectMeshAABB(Obj: TSceneObject; out MinBounds, MaxBounds: TVector3): Boolean;
    procedure RemoveSceneReferencesForObject(ASceneObject: TSceneObject; ABody: TPhysicsBody = nil);
    procedure ClearNativeScene;
    procedure RebuildNativeScene;
    procedure ClearBodyNativeGeometry(Body: TPhysicsBody);
    procedure SyncBodyFromNative(Body: TPhysicsBody);
    procedure SyncNativeBodiesToScene;

    function TestSphereAgainstBody(const Center: TVector3; Radius: Single;
      Body: TPhysicsBody; out Point, Normal: TVector3; out Penetration: Single): Boolean;
    function TestCapsuleAgainstBody(const SegmentA, SegmentB: TVector3; Radius: Single;
      Body: TPhysicsBody; out Point, Normal: TVector3; out Penetration: Single): Boolean;
    function TestSphereWorld(const Center: TVector3; Radius: Single; IgnoreBody: TPhysicsBody;
      out Hit: TPhysicsHit): Boolean;
    function TestCapsuleWorld(const SegmentA, SegmentB: TVector3; Radius: Single; IgnoreBody: TPhysicsBody;
      out Hit: TPhysicsHit): Boolean;
    function HasActiveSimulationBodies: Boolean;

    function CreateNativeBody(Body: TPhysicsBody): Boolean;
    procedure RecreateNativeBody(Body: TPhysicsBody);

    procedure QueryNativeAABB(const MinBounds, MaxBounds: TVector3;
      IgnoreBody: TPhysicsBody; Candidates: TList<TPhysicsBody>);
    function RaycastNative(const StartPoint, Direction: TVector3; MaxDistance: Single;
      out Hit: TPhysicsHit; IgnoreBody: TPhysicsBody = nil): Boolean;
  public
    constructor Create(ASceneRoot: TSceneObject);
    destructor Destroy; override;

    function AddBody(ASceneObject: TSceneObject; ABodyType: TPhysicsBodyType = pbtStatic;
      AColliderKind: TPhysicsColliderKind = pckAuto): TPhysicsBody;
    procedure RemoveBody(Body: TPhysicsBody);
    procedure RemoveBodyForObject(ASceneObject: TSceneObject);
    procedure RemoveBodiesForScene(ASceneObject: TSceneObject; Recursive: Boolean = True);
    procedure EnsureNativeScene;
    function FindBody(ASceneObject: TSceneObject): TPhysicsBody;
    procedure Clear;

    procedure CaptureSceneTransforms;
    procedure RestoreSceneTransforms(DisableDynamicBodies: Boolean = False);
    procedure ClearTransformBackup;
    function TryGetStagedBodyState(ASceneObject: TSceneObject; out State: TPhysicsBodyState): Boolean;
    procedure StageBodyState(ASceneObject: TSceneObject; const State: TPhysicsBodyState);
    procedure ApplyStagedBodyStates;
    procedure ClearStagedBodyStates;
    function ActiveSimulationBodyCount: Integer;
    function BodyUsesCookedMeshCache(Body: TPhysicsBody): Boolean;
    function BuildBodyCookedMeshSignature(Body: TPhysicsBody): UInt64;
    procedure StoreCookedMeshCache(ASceneObject: TSceneObject;
      Signature: UInt64; const Data: TBytes);
    procedure ClearCookedMeshCaches;
    function TrySaveCookedMeshCache(Body: TPhysicsBody; Stream: TStream;
      out Signature: UInt64): Boolean;

    procedure RegisterStaticMeshes(ASceneObject: TSceneObject; Recursive: Boolean = True;
      AColliderKind: TPhysicsColliderKind = pckMesh);

    procedure Step(DeltaTime: Single);

    function SweepSphere(const StartPosition, Delta: TVector3; Radius: Single;
      out Hit: TPhysicsHit; IgnoreBody: TPhysicsBody = nil): Boolean;
    function SweepCapsule(const StartPosition, Delta: TVector3; Radius, HalfHeight: Single;
      out Hit: TPhysicsHit; IgnoreBody: TPhysicsBody = nil): Boolean;
    function MoveCharacter(Body: TPhysicsBody; const DesiredDisplacement: TVector3;
      DeltaTime: Single; out Hit: TPhysicsHit): Boolean;

    procedure ApplyRadialImpulse(const Center: TVector3; Radius, Strength: Single;
      IncludeStatic: Boolean = False);

    procedure SyncSceneBodyToNative(Body: TPhysicsBody; DeltaTime: Single);
    procedure SyncSceneToNative(DeltaTime: Single);
    procedure ResetBodyToSceneTransform(Body: TPhysicsBody; ClearMotion: Boolean = True);
    procedure ResetBodiesToSceneTransforms(ClearMotion: Boolean = True);
    procedure MarkBodyDirty(Body: TPhysicsBody);
    procedure MarkObjectDirty(ASceneObject: TSceneObject; Recursive: Boolean = True);

    function Raycast(const StartPoint, Direction: TVector3; MaxDistance: Single;
      out Hit: TPhysicsHit; IgnoreBody: TPhysicsBody = nil): Boolean;
    function CreateColliderDebugMesh(Body: TPhysicsBody;
      const MeshName: string = 'PhysicsColliderDebug'): TMesh;
    function CreateConvexHullDebugMesh(Body: TPhysicsBody;
      const MeshName: string = 'PhysicsConvexHullDebug'): TMesh;

    property SceneRoot: TSceneObject read fSceneRoot write fSceneRoot;
    property Gravity: TVector3 read fGravity write fGravity;
    property GlobalDamping: Single read fGlobalDamping write fGlobalDamping;
    property MaxSubStep: Single read fMaxSubStep write fMaxSubStep;
    property MaxSubSteps: Integer read fMaxSubSteps write fMaxSubSteps;
    property SolverIterations: Integer read fSolverIterations write fSolverIterations;
    property GroundPlaneEnabled: Boolean read fGroundPlaneEnabled write fGroundPlaneEnabled;
    property GroundHeight: Single read fGroundHeight write fGroundHeight;
    property GroundNormal: TVector3 read fGroundNormal write fGroundNormal;
    property CollisionSlop: Single read fCollisionSlop write fCollisionSlop;
    property HasTransformBackup: Boolean read fHasTransformBackup;

    property Bodies[Index: Integer]: TPhysicsBody read GetBody;
    property BodyCount: Integer read GetBodyCount;
  end;

procedure WritePhysicsBodyStateToStream(Stream: TStream;
  const State: TPhysicsBodyState);
function ReadPhysicsBodyStateFromStream(Stream: TStream): TPhysicsBodyState;
function PhysicsInverseMassForState(const State: TPhysicsBodyState): Single;

implementation

uses
  Engine.Generators;

const
  PHYSICS_EPSILON = 1e-5;
  PHYSICS_DEFAULT_FRICTION = 0.55;
  PHYSICS_SWEEP_STEPS = 12;
  PHYSICS_HULL_VERTEX_EPSILON = 1e-4;
  PHYSICS_HULL_MIN_THICKNESS = 0.02;
  PHYSICS_HULL_MAX_ABS_COORD = 1.0e12;

type
  TPhysicsRaycastFilter = class
  private
    fIgnoreBody: TPhysicsBody;
  public
    constructor Create(AIgnoreBody: TPhysicsBody);
    function AcceptHit(const Point, Normal: TKraftVector3; const Time: TKraftScalar;
      const Shape: TKraftShape): Boolean;
  end;

function ClampFloat(Value, MinValue, MaxValue: Single): Single;
begin
  if Value < MinValue then
    Result := MinValue
  else if Value > MaxValue then
    Result := MaxValue
  else
    Result := Value;
end;

function SafeNormalize(const V: TVector3; const Fallback: TVector3): TVector3;
begin
  if V.LengthSquared <= PHYSICS_EPSILON * PHYSICS_EPSILON then
    Result := Fallback
  else
    Result := V.Normalize;
end;

function MinVector(const A, B: TVector3): TVector3;
begin
  Result := Neslib.FastMath.Vector3(System.Math.Min(A.X, B.X),
                                    System.Math.Min(A.Y, B.Y),
                                    System.Math.Min(A.Z, B.Z));
end;

function MaxVector(const A, B: TVector3): TVector3;
begin
  Result := Neslib.FastMath.Vector3(
    System.Math.Max(A.X, B.X),
    System.Math.Max(A.Y, B.Y),
    System.Math.Max(A.Z, B.Z));
end;

constructor TPhysicsRaycastFilter.Create(AIgnoreBody: TPhysicsBody);
begin
  inherited Create;
  fIgnoreBody := AIgnoreBody;
end;

function TPhysicsRaycastFilter.AcceptHit(const Point, Normal: TKraftVector3;
  const Time: TKraftScalar; const Shape: TKraftShape): Boolean;
var
  Body: TPhysicsBody;
begin
  Result := True;
  if (fIgnoreBody = nil) or (Shape = nil) then
    Exit;

  Body := nil;
  if Shape.UserData <> nil then
    Body := TPhysicsBody(Shape.UserData)
  else if (Shape.RigidBody <> nil) and (Shape.RigidBody.UserData <> nil) then
    Body := TPhysicsBody(Shape.RigidBody.UserData);

  Result := Body <> fIgnoreBody;
end;

function ToKraftVector3(const V: TVector3): TKraftVector3;
begin
  Result := Kraft.Vector3(V.X, V.Y, V.Z);
end;

function FromKraftVector3(const V: TKraftVector3): TVector3;
begin
  Result := Neslib.FastMath.Vector3(V.X, V.Y, V.Z);
end;

function SceneMatrixToKraft(const M: TMatrix4): TKraftMatrix4x4;
var
  XAxis, YAxis, ZAxis: TVector3;
begin
  XAxis := SafeNormalize(Neslib.FastMath.Vector3(M.Columns[0]), Neslib.FastMath.Vector3(1, 0, 0));
  YAxis := SafeNormalize(Neslib.FastMath.Vector3(M.Columns[1]), Neslib.FastMath.Vector3(0, 1, 0));
  ZAxis := SafeNormalize(Neslib.FastMath.Vector3(M.Columns[2]), Neslib.FastMath.Vector3(0, 0, 1));

  Result := Matrix4x4Identity;
  Result[0, 0] := XAxis.X;
  Result[0, 1] := XAxis.Y;
  Result[0, 2] := XAxis.Z;
  Result[1, 0] := YAxis.X;
  Result[1, 1] := YAxis.Y;
  Result[1, 2] := YAxis.Z;
  Result[2, 0] := ZAxis.X;
  Result[2, 1] := ZAxis.Y;
  Result[2, 2] := ZAxis.Z;
  Result[3, 0] := M.Columns[3].X;
  Result[3, 1] := M.Columns[3].Y;
  Result[3, 2] := M.Columns[3].Z;
end;

function KraftMatrixToPosition(const M: TKraftMatrix4x4): TVector3;
begin
  Result := Neslib.FastMath.Vector3(M[3, 0], M[3, 1], M[3, 2]);
end;

procedure HashUInt64(var Hash: UInt64; const Value: UInt64);
var
  Mixed: UInt64;
begin
  // Keep this overflow-check friendly: no wrapping multiply/add here.
  Mixed := Value xor (Value shr 33);
  Mixed := Mixed xor (Mixed shl 17);
  Mixed := Mixed xor (Mixed shr 29);
  Hash := Hash xor Mixed;
  Hash := (Hash shl 13) or (Hash shr 51);
  Hash := Hash xor (Mixed shl 7) xor (Mixed shr 11);
end;

procedure HashSingle(var Hash: UInt64; const Value: Single);
var
  Bits: UInt32;
begin
  Move(Value, Bits, SizeOf(Bits));
  HashUInt64(Hash, Bits);
end;

procedure HashVector3(var Hash: UInt64; const Value: TVector3);
begin
  HashSingle(Hash, Value.X);
  HashSingle(Hash, Value.Y);
  HashSingle(Hash, Value.Z);
end;

procedure HashMatrix4(var Hash: UInt64; const Value: TMatrix4);
var
  I: Integer;
begin
  for I := 0 to 3 do
  begin
    HashSingle(Hash, Value.Columns[I].X);
    HashSingle(Hash, Value.Columns[I].Y);
    HashSingle(Hash, Value.Columns[I].Z);
    HashSingle(Hash, Value.Columns[I].W);
  end;
end;

function KraftMatrixToFastQuaternion(const M: TKraftMatrix4x4): TQuaternion;
var
  Trace, S: Single;
  X, Y, Z, W: Single;
  Axis: TVector3;
  Angle, Len: Single;
begin
  Trace := M[0, 0] + M[1, 1] + M[2, 2];
  if Trace > 0.0 then
  begin
    S := Sqrt(Trace + 1.0) * 2.0;
    W := 0.25 * S;
    X := (M[1, 2] - M[2, 1]) / S;
    Y := (M[2, 0] - M[0, 2]) / S;
    Z := (M[0, 1] - M[1, 0]) / S;
  end
  else if (M[0, 0] > M[1, 1]) and (M[0, 0] > M[2, 2]) then
  begin
    S := Sqrt(1.0 + M[0, 0] - M[1, 1] - M[2, 2]) * 2.0;
    W := (M[1, 2] - M[2, 1]) / S;
    X := 0.25 * S;
    Y := (M[1, 0] + M[0, 1]) / S;
    Z := (M[2, 0] + M[0, 2]) / S;
  end
  else if M[1, 1] > M[2, 2] then
  begin
    S := Sqrt(1.0 + M[1, 1] - M[0, 0] - M[2, 2]) * 2.0;
    W := (M[2, 0] - M[0, 2]) / S;
    X := (M[1, 0] + M[0, 1]) / S;
    Y := 0.25 * S;
    Z := (M[2, 1] + M[1, 2]) / S;
  end
  else
  begin
    S := Sqrt(1.0 + M[2, 2] - M[0, 0] - M[1, 1]) * 2.0;
    W := (M[0, 1] - M[1, 0]) / S;
    X := (M[2, 0] + M[0, 2]) / S;
    Y := (M[2, 1] + M[1, 2]) / S;
    Z := 0.25 * S;
  end;

  Angle := 2.0 * System.Math.ArcCos(System.Math.EnsureRange(W, -1.0, 1.0));
  Len := Sqrt(System.Math.Max(0.0, 1.0 - W * W));
  if Len <= PHYSICS_EPSILON then
    Axis := Neslib.FastMath.Vector3(0, 1, 0)
  else
    Axis := Neslib.FastMath.Vector3(X / Len, Y / Len, Z / Len);
  Result.Init(Axis, Angle);
end;

function SameKraftMatrix(const A, B: TKraftMatrix4x4): Boolean;
var
  Row, Col: Integer;
begin
  Result := True;
  for Row := 0 to 3 do
    for Col := 0 to 3 do
      if Abs(A[Row, Col] - B[Row, Col]) > PHYSICS_EPSILON then
        Exit(False);
end;

function ClosestPointOnAABB(const Point, MinBounds, MaxBounds: TVector3): TVector3;
begin
  Result := Neslib.FastMath.Vector3(
    ClampFloat(Point.X, MinBounds.X, MaxBounds.X),
    ClampFloat(Point.Y, MinBounds.Y, MaxBounds.Y),
    ClampFloat(Point.Z, MinBounds.Z, MaxBounds.Z));
end;

function ClosestPointOnSegment(const Point, SegmentA, SegmentB: TVector3): TVector3;
var
  AB: TVector3;
  T: Single;
begin
  AB := SegmentB - SegmentA;
  if AB.LengthSquared <= PHYSICS_EPSILON then
    Exit(SegmentA);

  T := (Point - SegmentA).Dot(AB) / AB.Dot(AB);
  T := ClampFloat(T, 0.0, 1.0);
  Result := SegmentA + AB * T;
end;

function BodyTypeToNative(BodyType: TPhysicsBodyType): TKraftRigidBodyType;
begin
  case BodyType of
    pbtStatic:
      Result := krbtSTATIC;
    pbtKinematic:
      Result := krbtKINEMATIC;
  else
    Result := krbtDYNAMIC;
  end;
end;

function DampingToNative(DampingRetentionPerFrame: Single): Single;
const
  ReferenceDt: Single = 1.0 / 60.0;
var
  Retention: Single;
begin
  Retention := ClampFloat(DampingRetentionPerFrame, 0.001, 1.0);
  Result := (1.0 / Retention - 1.0) / ReferenceDt;
end;

function SameFloat(A, B: Single): Boolean; inline;
begin
  Result := Abs(A - B) <= PHYSICS_EPSILON;
end;

function SameVector(const A, B: TVector3): Boolean; inline;
begin
  Result :=
    SameFloat(A.X, B.X) and
    SameFloat(A.Y, B.Y) and
    SameFloat(A.Z, B.Z);
end;

procedure WritePhysicsBodyStateToStream(Stream: TStream;
  const State: TPhysicsBodyState);
var
  BodyTypeValue: Integer;
  ColliderValue: Integer;
begin
  BodyTypeValue := Ord(State.BodyType);
  ColliderValue := Ord(State.ColliderKind);
  Stream.WriteBuffer(BodyTypeValue, SizeOf(BodyTypeValue));
  Stream.WriteBuffer(ColliderValue, SizeOf(ColliderValue));
  Stream.WriteBuffer(State.Enabled, SizeOf(State.Enabled));
  Stream.WriteBuffer(State.CollisionResponse, SizeOf(State.CollisionResponse));
  Stream.WriteBuffer(State.UseGravity, SizeOf(State.UseGravity));
  Stream.WriteBuffer(State.Mass, SizeOf(State.Mass));
  Stream.WriteBuffer(State.Restitution, SizeOf(State.Restitution));
  Stream.WriteBuffer(State.LinearDamping, SizeOf(State.LinearDamping));
  Stream.WriteBuffer(State.GravityScale, SizeOf(State.GravityScale));
  Stream.WriteBuffer(State.Velocity, SizeOf(State.Velocity));
  Stream.WriteBuffer(State.AngularVelocity, SizeOf(State.AngularVelocity));
  Stream.WriteBuffer(State.AngularDamping, SizeOf(State.AngularDamping));
  Stream.WriteBuffer(State.Radius, SizeOf(State.Radius));
  Stream.WriteBuffer(State.HalfHeight, SizeOf(State.HalfHeight));
  Stream.WriteBuffer(State.AABBHalfExtents, SizeOf(State.AABBHalfExtents));
  Stream.WriteBuffer(State.StepHeight, SizeOf(State.StepHeight));
end;

function ReadPhysicsBodyStateFromStream(Stream: TStream): TPhysicsBodyState;
var
  BodyTypeValue: Integer;
  ColliderValue: Integer;
begin
  Stream.ReadBuffer(BodyTypeValue, SizeOf(BodyTypeValue));
  Stream.ReadBuffer(ColliderValue, SizeOf(ColliderValue));
  if (BodyTypeValue < Ord(Low(TPhysicsBodyType))) or
     (BodyTypeValue > Ord(High(TPhysicsBodyType))) then
    raise Exception.Create('Invalid physics body type in stream.');
  if (ColliderValue < Ord(Low(TPhysicsColliderKind))) or
     (ColliderValue > Ord(High(TPhysicsColliderKind))) then
    raise Exception.Create('Invalid physics collider kind in stream.');

  Result.BodyType := TPhysicsBodyType(BodyTypeValue);
  Result.ColliderKind := TPhysicsColliderKind(ColliderValue);
  Stream.ReadBuffer(Result.Enabled, SizeOf(Result.Enabled));
  Stream.ReadBuffer(Result.CollisionResponse, SizeOf(Result.CollisionResponse));
  Stream.ReadBuffer(Result.UseGravity, SizeOf(Result.UseGravity));
  Stream.ReadBuffer(Result.Mass, SizeOf(Result.Mass));
  Stream.ReadBuffer(Result.Restitution, SizeOf(Result.Restitution));
  Stream.ReadBuffer(Result.LinearDamping, SizeOf(Result.LinearDamping));
  Stream.ReadBuffer(Result.GravityScale, SizeOf(Result.GravityScale));
  Stream.ReadBuffer(Result.Velocity, SizeOf(Result.Velocity));
  Stream.ReadBuffer(Result.AngularVelocity, SizeOf(Result.AngularVelocity));
  Stream.ReadBuffer(Result.AngularDamping, SizeOf(Result.AngularDamping));
  Stream.ReadBuffer(Result.Radius, SizeOf(Result.Radius));
  Stream.ReadBuffer(Result.HalfHeight, SizeOf(Result.HalfHeight));
  Stream.ReadBuffer(Result.AABBHalfExtents, SizeOf(Result.AABBHalfExtents));
  Stream.ReadBuffer(Result.StepHeight, SizeOf(Result.StepHeight));
end;

function PhysicsInverseMassForState(const State: TPhysicsBodyState): Single;
begin
  if (State.BodyType in [pbtStatic, pbtKinematic]) or
     (State.Mass <= PHYSICS_EPSILON) then
    Result := 0.0
  else
    Result := 1.0 / State.Mass;
end;

{ TEnginePhysicsContactListener }
constructor TEnginePhysicsContactListener.Create(AWorld: TPhysicsWorld);
begin
  inherited Create;
  fWorld := AWorld;
end;

procedure TEnginePhysicsContactListener.BeginContact(const ContactPair: PKraftContactPair);
var
  BodyA, BodyB: TPhysicsBody;
  Collision: TPhysicsCollision;
  SolverManifold: TKraftSolverContactManifold;
  I: Integer;
begin
  if (ContactPair = nil) or
     (ContactPair^.RigidBodies[0] = nil) or
     (ContactPair^.RigidBodies[1] = nil) then
    Exit;

  BodyA := TPhysicsBody(ContactPair^.RigidBodies[0].UserData);
  BodyB := TPhysicsBody(ContactPair^.RigidBodies[1].UserData);

  if (BodyA = nil) or (BodyB = nil) then
    Exit;

  Collision.BodyA := BodyA;
  Collision.BodyB := BodyB;
  Collision.Normal := Neslib.FastMath.Vector3(0, 1, 0);
  Collision.Point := Neslib.FastMath.Vector3(0, 0, 0);
  Collision.Penetration := 0.0;

  ContactPair^.GetSolverContactManifold(
    SolverManifold,
    ContactPair^.RigidBodies[0].WorldTransform,
    ContactPair^.RigidBodies[1].WorldTransform,
    kcpcmmVelocitySolver);

  Collision.Normal := FromKraftVector3(SolverManifold.Normal);
  if SolverManifold.CountContacts > 0 then
  begin
    BodyA.fHasContact := True;
    BodyB.fHasContact := True;

    for I := 0 to SolverManifold.CountContacts - 1 do
    begin
      Collision.Point := Collision.Point + FromKraftVector3(SolverManifold.Contacts[I].Point);
      Collision.Penetration := System.Math.Max(
        Collision.Penetration,
        Abs(SolverManifold.Contacts[I].Separation));
    end;

    Collision.Point := Collision.Point * (1.0 / SolverManifold.CountContacts);

    // Grounded is a support-contact property, not a low-vertical-velocity
    // heuristic.  Pick the body above a sufficiently horizontal contact;
    // this is independent of the native solver's normal orientation.
    if (Abs(Collision.Normal.Y) >= 0.55) and
       Assigned(BodyA.SceneObject) and Assigned(BodyB.SceneObject) then
    begin
      if fWorld.GetWorldPosition(BodyA.SceneObject).Y >
         fWorld.GetWorldPosition(BodyB.SceneObject).Y then
        BodyA.fIsGrounded := True
      else if fWorld.GetWorldPosition(BodyB.SceneObject).Y >
              fWorld.GetWorldPosition(BodyA.SceneObject).Y then
        BodyB.fIsGrounded := True;
    end;
  end;

  if Assigned(BodyA.fOnCollision) then
    BodyA.fOnCollision(Collision);

  if Assigned(BodyB.fOnCollision) then
  begin
    Collision.BodyA := BodyB;
    Collision.BodyB := BodyA;
    Collision.Normal := Collision.Normal * -1.0;
    BodyB.fOnCollision(Collision);
  end;
end;

procedure TEnginePhysicsContactListener.EndContact(const ContactPair: PKraftContactPair);
begin
  // Your public wrapper only has OnCollision, not OnCollisionEnd.
  // Add OnCollisionEnd later if you need separation events.
end;

{ TPhysicsHit }
procedure TPhysicsHit.Clear;
begin
  Hit := False;
  Body := nil;
  Point := Neslib.FastMath.Vector3(0, 0, 0);
  Normal := Neslib.FastMath.Vector3(0, 1, 0);
  Time := 1.0;
  Penetration := 0.0;
end;

{ TPhysicsBody }
constructor TPhysicsBody.Create(AWorld: TPhysicsWorld; ASceneObject: TSceneObject);
begin
  inherited Create;

  fWorld := AWorld;
  fSceneObject := ASceneObject;
  fBodyType := pbtStatic;
  fColliderKind := pckAuto;
  fEnabled := False;
  fCollisionResponse := True;
  fUseGravity := True;
  fIsGrounded := False;
  fSleeping := False;
  fHasContact := False;
  //fSleepCounter := 0;
  fMass := 1.0;
  fInverseMass := 0.0;
  fRestitution := 0.15;
  fLinearDamping := 0.985;
  fGravityScale := 1.0;
  fVelocity := Neslib.FastMath.Vector3(0, 0, 0);
  fAngularVelocity := Neslib.FastMath.Vector3(0, 0, 0);
  fForce := Neslib.FastMath.Vector3(0, 0, 0);
  fAngularDamping := 0.985;
  fRadius := 0.5;
  fHalfHeight := 0.5;
  fAABBHalfExtents := Neslib.FastMath.Vector3(0.5, 0.5, 0.5);
  fStepHeight := 0.35;
  fNativeBody := nil;
  fNativeShape := nil;
  //fNativeMeshes := TObjectList<TKraftMesh>.Create(True);
  //fNativeConvexHulls := TObjectList<TKraftConvexHull>.Create(True);

  fNativeMeshes := TObjectList<TKraftMesh>.Create(False);
  fNativeConvexHulls := TObjectList<TKraftConvexHull>.Create(False);

  fLastNativeTransform := Matrix4x4Identity;
  fLastNativeMeshSignature := 0;
  UpdateInverseMass;
  AutoFitColliderFromScene;
end;

destructor TPhysicsBody.Destroy;
begin
  RemoveNativeBody;
  fNativeMeshes.Free;
  fNativeConvexHulls.Free;
  inherited;
end;

procedure TPhysicsBody.SetBodyType(const Value: TPhysicsBodyType);
begin
  if fBodyType = Value then
    Exit;

  fBodyType := Value;

  if fBodyType = pbtCharacter then
  begin
    fRestitution := 0.0;
    if fColliderKind = pckAuto then
      fColliderKind := pckCapsule;
  end
  else if fBodyType = pbtProjectile then
    fUseGravity := False;

  UpdateInverseMass;
  NativeShapeChanged;
end;

procedure TPhysicsBody.SetMass(const Value: Single);
var
  NewMass: Single;
begin
  NewMass := System.Math.Max(0.0, Value);

  if SameFloat(fMass, NewMass) then
    Exit;

  fMass := NewMass;
  UpdateInverseMass;
  NativeShapeChanged;
end;

procedure TPhysicsBody.UpdateInverseMass;
var
  State: TPhysicsBodyState;
begin
  State.BodyType := fBodyType;
  State.Mass := fMass;
  fInverseMass := PhysicsInverseMassForState(State);
end;

procedure TPhysicsBody.Wake;
begin
  fSleeping := False;

  if fNativeBody <> nil then
    if not fNativeBody.IsStatic then
      fNativeBody.SetToAwake;
end;

procedure TPhysicsBody.SetVelocity(const Value: TVector3);
begin
  fVelocity := Value;

  if fNativeBody <> nil then
  begin
    if not fNativeBody.IsStatic then
    begin
      fNativeBody.LinearVelocity := ToKraftVector3(Value);

      if Value.LengthSquared > PHYSICS_EPSILON * PHYSICS_EPSILON then
        Wake;
    end;
  end;
end;

procedure TPhysicsBody.SetAngularVelocity(const Value: TVector3);
begin
  fAngularVelocity := Value;

  if fNativeBody <> nil then
  begin
    if not fNativeBody.IsStatic then
    begin
      fNativeBody.AngularVelocity := ToKraftVector3(Value);

      if Value.LengthSquared > PHYSICS_EPSILON * PHYSICS_EPSILON then
        Wake;
    end;
  end;
end;

procedure TPhysicsBody.RemoveNativeBody;
begin
  {if fNativeBody <> nil then
  begin
    fNativeBody.Free;
    fNativeBody := nil;
    fNativeShape := nil;
    if fWorld <> nil then
      fWorld.ClearBodyNativeGeometry(Self)
    else
    begin
      fNativeMeshes.Clear;
      fNativeConvexHulls.Clear;
    end;
  end;}

  if fNativeBody = nil then
    Exit;

  if fWorld <> nil then
  begin
    // Native bodies/shapes belong to the TKraft scene.
    // Rebuild the whole native scene instead of freeing one registered body.
    fWorld.ClearNativeScene;
    Exit;
  end;

  // Fallback only for the unlikely case where the body has no world.
  fNativeBody := nil;
  fNativeShape := nil;
  fLastNativeMeshSignature := 0;
  fNativeMeshes.Clear;
  fNativeConvexHulls.Clear;
end;

procedure TPhysicsBody.SetColliderKind(const Value: TPhysicsColliderKind);
begin
  if fColliderKind = Value then
    Exit;

  fColliderKind := Value;

  if fColliderKind = pckAuto then
    AutoFitColliderFromScene;

  NativeShapeChanged;
end;

procedure TPhysicsBody.SetEnabled(const Value: Boolean);
begin
  if fEnabled = Value then
    Exit;

  fEnabled := Value;

  if not fEnabled then
  begin
    fIsGrounded := False;
    fHasContact := False;
    ClearForces;
    RemoveNativeBody;
    Exit;
  end;

  fSleeping := False;

  if fColliderKind = pckAuto then
    AutoFitColliderFromScene;

  if (fWorld <> nil) and (fWorld.fNativeScene <> nil) and (fNativeBody = nil) then
    fWorld.CreateNativeBody(Self);

  Wake;
end;

procedure TPhysicsBody.SetCollisionResponse(const Value: Boolean);
begin
  if fCollisionResponse = Value then
    Exit;

  fCollisionResponse := Value;

  if fNativeShape <> nil then
  begin
    if fCollisionResponse then
      fNativeShape.Flags := fNativeShape.Flags - [ksfSensor]
    else
      fNativeShape.Flags := fNativeShape.Flags + [ksfSensor];
  end;

  Wake;
end;

procedure TPhysicsBody.SetRadius(const Value: Single);
var
  NewRadius: Single;
begin
  NewRadius := System.Math.Max(Value, 0.01);

  if SameFloat(fRadius, NewRadius) then
    Exit;

  fRadius := NewRadius;

  case fColliderKind of
    pckSphere:
      begin
        fHalfHeight := 0.01;
        fAABBHalfExtents := Neslib.FastMath.Vector3(fRadius, fRadius, fRadius);
      end;

    pckCapsule:
      begin
        fAABBHalfExtents := Neslib.FastMath.Vector3(fRadius, fHalfHeight + fRadius, fRadius);
      end;
  end;

  NativeShapeChanged;
end;

procedure TPhysicsBody.SetHalfHeight(const Value: Single);
var
  NewHalfHeight: Single;
begin
  NewHalfHeight := System.Math.Max(Value, 0.01);

  if SameFloat(fHalfHeight, NewHalfHeight) then
    Exit;

  fHalfHeight := NewHalfHeight;

  if fColliderKind = pckCapsule then
    fAABBHalfExtents := Neslib.FastMath.Vector3(fRadius, fHalfHeight + fRadius, fRadius);

  NativeShapeChanged;
end;

procedure TPhysicsBody.SetAABBHalfExtents(const Value: TVector3);
var
  NewExtents: TVector3;
begin
  NewExtents := Neslib.FastMath.Vector3(
    System.Math.Max(Value.X, 0.01),
    System.Math.Max(Value.Y, 0.01),
    System.Math.Max(Value.Z, 0.01));

  if SameVector(fAABBHalfExtents, NewExtents) then
    Exit;

  fAABBHalfExtents := NewExtents;

  NativeShapeChanged;
end;

procedure TPhysicsBody.SetUseGravity(const Value: Boolean);
begin
  if fUseGravity = Value then
    Exit;

  fUseGravity := Value;

  if fNativeBody <> nil then
  begin
    if fUseGravity then
      fNativeBody.GravityScale := fGravityScale
    else
      fNativeBody.GravityScale := 0.0;
    Wake;
  end;
end;

procedure TPhysicsBody.SetRestitution(const Value: Single);
var
  NewValue: Single;
begin
  NewValue := System.Math.Max(0.0, Value);

  if SameFloat(fRestitution, NewValue) then
    Exit;

  fRestitution := NewValue;

  if fNativeShape <> nil then
    fNativeShape.Restitution := fRestitution;

  Wake;
end;

procedure TPhysicsBody.SetLinearDamping(const Value: Single);
var
  NewValue: Single;
  EffectiveDamping: Single;
begin
  NewValue := ClampFloat(Value, 0.0, 1.0);

  if SameFloat(fLinearDamping, NewValue) then
    Exit;

  fLinearDamping := NewValue;

  if fNativeBody <> nil then
  begin
    if not fNativeBody.IsStatic then
    begin
      EffectiveDamping := fLinearDamping;

      if fWorld <> nil then
        EffectiveDamping := EffectiveDamping * fWorld.fGlobalDamping;

      EffectiveDamping := ClampFloat(EffectiveDamping, 0.0, 1.0);

      fNativeBody.LinearVelocityDamp := DampingToNative(EffectiveDamping);
    end;
  end;

  Wake;
end;

procedure TPhysicsBody.SetGravityScale(const Value: Single);
begin
  if SameFloat(fGravityScale, Value) then
    Exit;

  fGravityScale := Value;

  if fNativeBody <> nil then
  begin
    if fUseGravity then
      fNativeBody.GravityScale := fGravityScale
    else
      fNativeBody.GravityScale := 0.0;
    Wake;
  end;
end;

procedure TPhysicsBody.SetAngularDamping(const Value: Single);
begin
  if SameFloat(fAngularDamping, ClampFloat(Value, 0.0, 1.0)) then
    Exit;

  fAngularDamping := ClampFloat(Value, 0.0, 1.0);

  if fNativeBody <> nil then
    if not fNativeBody.IsStatic then
      fNativeBody.AngularVelocityDamp := DampingToNative(fAngularDamping);

  Wake;
end;

procedure TPhysicsBody.NativeShapeChanged;
begin
  fSleeping := False;
  fIsGrounded := False;

  if fWorld = nil then
    Exit;

  if fWorld.fNativeScene = nil then
    Exit;

  if fEnabled then
    fWorld.RecreateNativeBody(Self)
  else
    RemoveNativeBody;
end;

function TPhysicsBody.IsDynamic: Boolean;
begin
  Result := fBodyType in [pbtDynamic, pbtCharacter, pbtProjectile];
end;

function TPhysicsBody.HasFiniteMass: Boolean;
begin
  Result := fInverseMass > 0.0;
end;

function TPhysicsBody.EffectiveColliderKind: TPhysicsColliderKind;
begin
  Result := fColliderKind;
  if Result = pckAuto then
  begin
    if (fSceneObject <> nil) and fSceneObject.HasGeometry then
      Result := pckMesh
    else
      Result := pckAABB;
  end;
end;

procedure TPhysicsBody.AutoFitColliderFromScene;
var
  MinBounds, MaxBounds, Extents: TVector3;
  I: Integer;
  Mesh: TMesh;
  Meshes: TMeshList;
  MeshBox: TAABB;
  HasBounds: Boolean;
begin
  if fSceneObject = nil then
    Exit;

  HasBounds := False;
  Meshes := fSceneObject.EffectiveMeshList;
  if not Assigned(Meshes) then
    Exit;

  for I := 0 to Meshes.Count - 1 do
  begin
    Mesh := Meshes.Item[I];
    if Mesh = nil then
      Continue;
    MeshBox := Mesh.GetBoundingBox.Transform(Mesh.LocalMatrix);
    if not HasBounds then
    begin
      MinBounds := MeshBox.Min;
      MaxBounds := MeshBox.Max;
      HasBounds := True;
    end
    else
    begin
      MinBounds := MinVector(MinBounds, MeshBox.Min);
      MaxBounds := MaxVector(MaxBounds, MeshBox.Max);
    end;
  end;

  if not HasBounds then
    Exit;

  Extents := (MaxBounds - MinBounds) * 0.5;
  fAABBHalfExtents := Neslib.FastMath.Vector3(
    System.Math.Max(Extents.X, 0.05),
    System.Math.Max(Extents.Y, 0.05),
    System.Math.Max(Extents.Z, 0.05));
  fRadius := System.Math.Max(System.Math.Max(fAABBHalfExtents.X, fAABBHalfExtents.Z), 0.05);
  fHalfHeight := System.Math.Max(fAABBHalfExtents.Y - fRadius, 0.05);
end;

procedure TPhysicsBody.ConfigureSphere(ARadius: Single);
begin
  fColliderKind := pckSphere;
  fRadius := System.Math.Max(ARadius, 0.01);
  fHalfHeight := 0.01;
  fAABBHalfExtents := Neslib.FastMath.Vector3(fRadius, fRadius, fRadius);
  NativeShapeChanged;
end;

procedure TPhysicsBody.ConfigureCapsule(ARadius, AHalfHeight: Single);
begin
  fColliderKind := pckCapsule;
  fRadius := System.Math.Max(ARadius, 0.01);
  fHalfHeight := System.Math.Max(AHalfHeight, 0.01);
  fAABBHalfExtents := Neslib.FastMath.Vector3(fRadius, fHalfHeight + fRadius, fRadius);
  NativeShapeChanged;
end;

procedure TPhysicsBody.ConfigureAABB(const AHalfExtents: TVector3);
begin
  fColliderKind := pckAABB;
  fAABBHalfExtents := Neslib.FastMath.Vector3(
    System.Math.Max(AHalfExtents.X, 0.01),
    System.Math.Max(AHalfExtents.Y, 0.01),
    System.Math.Max(AHalfExtents.Z, 0.01));
  NativeShapeChanged;
end;

procedure TPhysicsBody.ConfigureMesh;
begin
  fColliderKind := pckMesh;
  AutoFitColliderFromScene;
  NativeShapeChanged;
end;

procedure TPhysicsBody.AddForce(const Force: TVector3);
begin
  if not HasFiniteMass then
    Exit;

  if Force.LengthSquared > PHYSICS_EPSILON * PHYSICS_EPSILON then
    Wake;

  fForce := fForce + Force;

  if (fNativeBody <> nil) and (not fNativeBody.IsStatic) then
    fNativeBody.AddWorldForce(ToKraftVector3(Force), kfmForce);
end;

procedure TPhysicsBody.AddImpulse(const Impulse: TVector3);
begin
  if not HasFiniteMass then
    Exit;
  if Impulse.LengthSquared > PHYSICS_EPSILON * PHYSICS_EPSILON then
    Wake;
  fVelocity := fVelocity + Impulse * fInverseMass;
  if fNativeBody <> nil then
    //fNativeBody.ApplyImpulseAtPosition(KraftMatrixToPosition(fNativeBody.WorldTransform), ToKraftVector3(Impulse));
    fNativeBody.ApplyImpulseAtPosition(ToKraftVector3(KraftMatrixToPosition(fNativeBody.WorldTransform)), ToKraftVector3(Impulse));
end;

procedure TPhysicsBody.ClearForces;
begin
  fForce := Neslib.FastMath.Vector3(0, 0, 0);
end;

procedure TPhysicsBody.Stop;
begin
  fVelocity := Neslib.FastMath.Vector3(0, 0, 0);
  fAngularVelocity := Neslib.FastMath.Vector3(0, 0, 0);
  fSleeping := False;

  if fNativeBody <> nil then
  begin
    if not fNativeBody.IsStatic then
    begin
      fNativeBody.LinearVelocity := Kraft.Vector3(0, 0, 0);
      fNativeBody.AngularVelocity := Kraft.Vector3(0, 0, 0);
      fNativeBody.SetToAwake;
    end;
  end;

  ClearForces;
end;

function TPhysicsBody.GetState: TPhysicsBodyState;
begin
  Result.BodyType := fBodyType;
  Result.ColliderKind := fColliderKind;
  Result.Enabled := fEnabled;
  Result.CollisionResponse := fCollisionResponse;
  Result.UseGravity := fUseGravity;
  Result.Mass := fMass;
  Result.Restitution := fRestitution;
  Result.LinearDamping := fLinearDamping;
  Result.GravityScale := fGravityScale;
  Result.Velocity := fVelocity;
  Result.AngularVelocity := fAngularVelocity;
  Result.AngularDamping := fAngularDamping;
  Result.Radius := fRadius;
  Result.HalfHeight := fHalfHeight;
  Result.AABBHalfExtents := fAABBHalfExtents;
  Result.StepHeight := fStepHeight;
end;

procedure TPhysicsBody.ApplyState(const State: TPhysicsBodyState);
begin
  fBodyType := State.BodyType;
  fColliderKind := State.ColliderKind;
  fEnabled := State.Enabled;
  fCollisionResponse := State.CollisionResponse;
  fUseGravity := State.UseGravity;
  fMass := System.Math.Max(0.0, State.Mass);
  fRestitution := System.Math.Max(0.0, State.Restitution);
  fLinearDamping := ClampFloat(State.LinearDamping, 0.0, 1.0);
  fGravityScale := State.GravityScale;
  fVelocity := State.Velocity;
  fAngularVelocity := State.AngularVelocity;
  fAngularDamping := ClampFloat(State.AngularDamping, 0.0, 1.0);
  fRadius := System.Math.Max(0.01, State.Radius);
  fHalfHeight := System.Math.Max(0.01, State.HalfHeight);
  fAABBHalfExtents := Neslib.FastMath.Vector3(
    System.Math.Max(0.01, State.AABBHalfExtents.X),
    System.Math.Max(0.01, State.AABBHalfExtents.Y),
    System.Math.Max(0.01, State.AABBHalfExtents.Z));
  fStepHeight := System.Math.Max(0.0, State.StepHeight);
  fIsGrounded := False;
  fHasContact := False;
  UpdateInverseMass;
  ClearForces;
  NativeShapeChanged;
end;

procedure TPhysicsBody.SaveToStream(Stream: TStream);
var
  BodyTypeValue: Integer;
  ColliderValue: Integer;
begin
  BodyTypeValue := Ord(fBodyType);
  ColliderValue := Ord(fColliderKind);
  Stream.WriteBuffer(BodyTypeValue, SizeOf(BodyTypeValue));
  Stream.WriteBuffer(ColliderValue, SizeOf(ColliderValue));
  Stream.WriteBuffer(fEnabled, SizeOf(fEnabled));
  Stream.WriteBuffer(fCollisionResponse, SizeOf(fCollisionResponse));
  Stream.WriteBuffer(fUseGravity, SizeOf(fUseGravity));
  Stream.WriteBuffer(fMass, SizeOf(fMass));
  Stream.WriteBuffer(fRestitution, SizeOf(fRestitution));
  Stream.WriteBuffer(fLinearDamping, SizeOf(fLinearDamping));
  Stream.WriteBuffer(fGravityScale, SizeOf(fGravityScale));
  Stream.WriteBuffer(fVelocity, SizeOf(fVelocity));

  Stream.WriteBuffer(fAngularVelocity, SizeOf(fAngularVelocity));
  Stream.WriteBuffer(fAngularDamping, SizeOf(fAngularDamping));

  Stream.WriteBuffer(fRadius, SizeOf(fRadius));
  Stream.WriteBuffer(fHalfHeight, SizeOf(fHalfHeight));
  Stream.WriteBuffer(fAABBHalfExtents, SizeOf(fAABBHalfExtents));
  Stream.WriteBuffer(fStepHeight, SizeOf(fStepHeight));
end;

procedure TPhysicsBody.LoadFromStream(Stream: TStream);
var
  BodyTypeValue: Integer;
  ColliderValue: Integer;
begin
  Stream.ReadBuffer(BodyTypeValue, SizeOf(BodyTypeValue));
  Stream.ReadBuffer(ColliderValue, SizeOf(ColliderValue));
  if (BodyTypeValue < Ord(Low(TPhysicsBodyType))) or
     (BodyTypeValue > Ord(High(TPhysicsBodyType))) then
    raise Exception.Create('Invalid physics body type in stream.');
  if (ColliderValue < Ord(Low(TPhysicsColliderKind))) or
     (ColliderValue > Ord(High(TPhysicsColliderKind))) then
    raise Exception.Create('Invalid physics collider type in stream.');

  fBodyType := TPhysicsBodyType(BodyTypeValue);
  fColliderKind := TPhysicsColliderKind(ColliderValue);
  Stream.ReadBuffer(fEnabled, SizeOf(fEnabled));
  Stream.ReadBuffer(fCollisionResponse, SizeOf(fCollisionResponse));
  Stream.ReadBuffer(fUseGravity, SizeOf(fUseGravity));
  Stream.ReadBuffer(fMass, SizeOf(fMass));
  Stream.ReadBuffer(fRestitution, SizeOf(fRestitution));
  Stream.ReadBuffer(fLinearDamping, SizeOf(fLinearDamping));
  Stream.ReadBuffer(fGravityScale, SizeOf(fGravityScale));
  Stream.ReadBuffer(fVelocity, SizeOf(fVelocity));

  Stream.ReadBuffer(fAngularVelocity, SizeOf(fAngularVelocity));
  Stream.ReadBuffer(fAngularDamping, SizeOf(fAngularDamping));

  Stream.ReadBuffer(fRadius, SizeOf(fRadius));
  Stream.ReadBuffer(fHalfHeight, SizeOf(fHalfHeight));
  Stream.ReadBuffer(fAABBHalfExtents, SizeOf(fAABBHalfExtents));
  Stream.ReadBuffer(fStepHeight, SizeOf(fStepHeight));
  UpdateInverseMass;
  Wake;
end;

constructor TPhysicsWorld.Create(ASceneRoot: TSceneObject);
begin
  inherited Create;
  fSceneRoot := ASceneRoot;
  fBodies := TObjectList<TPhysicsBody>.Create(True);
  fTransformBackup := TList<TPhysicsTransformSnapshot>.Create;
  fStagedBodyStates := TDictionary<TSceneObject, TPhysicsBodyState>.Create;
  fCookedMeshCaches := TObjectDictionary<TSceneObject, TPhysicsCookedMeshCacheEntry>.Create([doOwnsValues]);
  fGravity := Neslib.FastMath.Vector3(0, -9.81, 0);
  fGlobalDamping := 1.0;
  fMaxSubStep := 1.0 / 120.0;
  fMaxSubSteps := 8;
  fSolverIterations := 20;
  fGroundPlaneEnabled := False;
  fGroundHeight := -1000000.0;
  fGroundNormal := Neslib.FastMath.Vector3(0, 1, 0);
  fCollisionSlop := 0.05;
  fNativeScene := nil;
  fNativeStep := 0.0;
  fAccumulator := 0.0;
  fPasMP := TPasMP.Create(-1, -1, -1, 0, False);
  fNativeContactListener := TEnginePhysicsContactListener.Create(Self);
end;

destructor TPhysicsWorld.Destroy;
begin
  ClearNativeScene;
  fStagedBodyStates.Free;
  fCookedMeshCaches.Free;
  fTransformBackup.Free;
  fBodies.Free;
  fNativeContactListener.Free;
  fPasMP.Free;

  inherited;
end;

function TPhysicsWorld.GetBody(Index: Integer): TPhysicsBody;
begin
  Result := fBodies[Index];
end;

function TPhysicsWorld.GetBodyCount: Integer;
begin
  Result := fBodies.Count;
end;

function TPhysicsWorld.AddBody(ASceneObject: TSceneObject; ABodyType: TPhysicsBodyType;
  AColliderKind: TPhysicsColliderKind): TPhysicsBody;
begin
  Result := FindBody(ASceneObject);
  if Result <> nil then
  begin
    Result.BodyType := ABodyType;
    Result.ColliderKind := AColliderKind;
    if Result.ColliderKind = pckAuto then
      Result.AutoFitColliderFromScene;
    ClearNativeScene;
    Exit;
  end;

  Result := TPhysicsBody.Create(Self, ASceneObject);
  Result.BodyType := ABodyType;
  Result.ColliderKind := AColliderKind;
  if Result.ColliderKind = pckAuto then
    Result.AutoFitColliderFromScene;
  fBodies.Add(Result);
  ClearNativeScene;
end;

procedure TPhysicsWorld.RemoveBody(Body: TPhysicsBody);
begin
  if Body <> nil then
  begin
    RemoveSceneReferencesForObject(Body.SceneObject, Body);
    Body.RemoveNativeBody;
    fBodies.Remove(Body);
  end;
end;

procedure TPhysicsWorld.RemoveBodyForObject(ASceneObject: TSceneObject);
var
  Body: TPhysicsBody;
begin
  RemoveSceneReferencesForObject(ASceneObject);

  Body := FindBody(ASceneObject);
  if Body <> nil then
    RemoveBody(Body);
end;

procedure TPhysicsWorld.RemoveBodiesForScene(ASceneObject: TSceneObject; Recursive: Boolean);
var
  I: Integer;
begin
  if ASceneObject = nil then
    Exit;

  if Recursive then
    for I := 0 to ASceneObject.Count - 1 do
      RemoveBodiesForScene(ASceneObject.ObjectList[I], True);

  RemoveBodyForObject(ASceneObject);
end;

procedure TPhysicsWorld.EnsureNativeScene;
begin
  if fNativeScene = nil then
    RebuildNativeScene;
end;

function TPhysicsWorld.FindBody(ASceneObject: TSceneObject): TPhysicsBody;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to fBodies.Count - 1 do
    if fBodies[I].SceneObject = ASceneObject then
      Exit(fBodies[I]);
end;

procedure TPhysicsWorld.Clear;
begin
  ClearNativeScene;
  fBodies.Clear;
  ClearTransformBackup;
  ClearStagedBodyStates;
  ClearCookedMeshCaches;
end;

function TPhysicsWorld.HasActiveSimulationBodies: Boolean;
var
  Body: TPhysicsBody;
begin
  Result := False;
  for Body in fBodies do
    if (Body <> nil) and Body.Enabled and Body.IsDynamic then
      Exit(True);
end;

function TPhysicsWorld.CreateNativeBody(Body: TPhysicsBody): Boolean;
var
  Kind: TPhysicsColliderKind;
  HalfExtents, WorldScale: TVector3;
  Volume, Density: Single;
  Shape: TKraftShape;
  KraftBody: TKraftRigidBody;

  function MeshVertexPosition(Mesh: TMesh; VertexIndex: Integer): TVector3;
  var
    P: TVector3;
  begin
    P := Vector3(Mesh.LocalMatrix * Vector4(Mesh.Vertices[VertexIndex].Position, 1.0));
    Result := Neslib.FastMath.Vector3(P.X * WorldScale.X, P.Y * WorldScale.Y, P.Z * WorldScale.Z);
  end;
// New
  function CrossVector(const A, B: TVector3): TVector3;
  begin
    Result := Neslib.FastMath.Vector3(
      A.Y * B.Z - A.Z * B.Y,
      A.Z * B.X - A.X * B.Z,
      A.X * B.Y - A.Y * B.X);
  end;

  function IsUsableScalar(const S: Single): Boolean;
  begin
    Result := (S = S) and (Abs(S) < PHYSICS_HULL_MAX_ABS_COORD);
  end;

  function IsUsableVertex(const V: TVector3): Boolean;
  begin
    Result := IsUsableScalar(V.X) and IsUsableScalar(V.Y) and IsUsableScalar(V.Z);
  end;

  function SameHullVertex(const A, B: TVector3): Boolean;
  begin
    Result := (A - B).LengthSquared <=
      PHYSICS_HULL_VERTEX_EPSILON * PHYSICS_HULL_VERTEX_EPSILON;
  end;

  procedure AddUniqueHullVertex(var Vertices: TArray<TVector3>; const V: TVector3);
  var
    I, N: Integer;
  begin
    if not IsUsableVertex(V) then
      Exit;

    for I := 0 to High(Vertices) do
      if SameHullVertex(Vertices[I], V) then
        Exit;

    N := Length(Vertices);
    SetLength(Vertices, N + 1);
    Vertices[N] := V;
  end;

  function HasHullVolume(const Vertices: TArray<TVector3>): Boolean;
  var
    I, J, K, L: Integer;
    A, B, C, D: TVector3;
    AB, AC, AD, N: TVector3;
  begin
    Result := False;

    if Length(Vertices) < 4 then
      Exit;

    for I := 0 to High(Vertices) do
    begin
      A := Vertices[I];

      for J := 0 to High(Vertices) do
      begin
        B := Vertices[J];
        AB := B - A;
        if AB.LengthSquared <= PHYSICS_HULL_VERTEX_EPSILON * PHYSICS_HULL_VERTEX_EPSILON then
          Continue;

        for K := 0 to High(Vertices) do
        begin
          C := Vertices[K];
          AC := C - A;
          N := CrossVector(AB, AC);

          if N.LengthSquared <= PHYSICS_HULL_VERTEX_EPSILON * PHYSICS_HULL_VERTEX_EPSILON then
            Continue;

          N := SafeNormalize(N, Neslib.FastMath.Vector3(0, 1, 0));

          for L := 0 to High(Vertices) do
          begin
            D := Vertices[L];
            AD := D - A;

            if Abs(N.Dot(AD)) > PHYSICS_HULL_MIN_THICKNESS * 0.25 then
              Exit(True);
          end;
        end;
      end;
    end;
  end;

  procedure BuildFallbackBoxHullVertices(var Vertices: TArray<TVector3>; const DefaultHalfExtents: TVector3);
  var
    I: Integer;
    MinB, MaxB, Center, Ext: TVector3;
  begin
    if Length(Vertices) > 0 then
    begin
      MinB := Vertices[0];
      MaxB := Vertices[0];

      for I := 1 to High(Vertices) do
      begin
        MinB := MinVector(MinB, Vertices[I]);
        MaxB := MaxVector(MaxB, Vertices[I]);
      end;

      Center := (MinB + MaxB) * 0.5;
      Ext := (MaxB - MinB) * 0.5;
    end
    else
    begin
      Center := Neslib.FastMath.Vector3(0, 0, 0);
      Ext := DefaultHalfExtents;
    end;

    Ext := Neslib.FastMath.Vector3(
      System.Math.Max(Ext.X, PHYSICS_HULL_MIN_THICKNESS),
      System.Math.Max(Ext.Y, PHYSICS_HULL_MIN_THICKNESS),
      System.Math.Max(Ext.Z, PHYSICS_HULL_MIN_THICKNESS));

    SetLength(Vertices, 8);

    Vertices[0] := Center + Neslib.FastMath.Vector3(-Ext.X, -Ext.Y, -Ext.Z);
    Vertices[1] := Center + Neslib.FastMath.Vector3( Ext.X, -Ext.Y, -Ext.Z);
    Vertices[2] := Center + Neslib.FastMath.Vector3(-Ext.X,  Ext.Y, -Ext.Z);
    Vertices[3] := Center + Neslib.FastMath.Vector3( Ext.X,  Ext.Y, -Ext.Z);
    Vertices[4] := Center + Neslib.FastMath.Vector3(-Ext.X, -Ext.Y,  Ext.Z);
    Vertices[5] := Center + Neslib.FastMath.Vector3( Ext.X, -Ext.Y,  Ext.Z);
    Vertices[6] := Center + Neslib.FastMath.Vector3(-Ext.X,  Ext.Y,  Ext.Z);
    Vertices[7] := Center + Neslib.FastMath.Vector3( Ext.X,  Ext.Y,  Ext.Z);
  end;
// End New
  function AddConvexHullShape: TKraftShape;
  var
    Hull: TKraftConvexHull;
    I, J: Integer;
    Mesh: TMesh;
    Meshes: TMeshList;
    V: TVector3;
    HullVertices: TArray<TVector3>;
  begin
    Result := nil;
    SetLength(HullVertices, 0);

    if Body.SceneObject = nil then
      Exit;

    Meshes := Body.SceneObject.EffectiveMeshList;
    if (Meshes = nil) or (Meshes.Count = 0) then
      Exit;

    for I := 0 to Meshes.Count - 1 do
    begin
      Mesh := Meshes.Item[I];
      if Mesh = nil then
        Continue;

      for J := 0 to Mesh.VertexCount - 1 do
      begin
        V := MeshVertexPosition(Mesh, J);
        AddUniqueHullVertex(HullVertices, V);
      end;
    end;

    if (Length(HullVertices) < 4) or (not HasHullVolume(HullVertices)) then
      BuildFallbackBoxHullVertices(HullVertices, HalfExtents);

    if (Length(HullVertices) < 4) or (not HasHullVolume(HullVertices)) then
      Exit;

    Hull := TKraftConvexHull.Create(fNativeScene);
    Body.fNativeConvexHulls.Add(Hull);

    for I := 0 to High(HullVertices) do
      Hull.AddVertex(ToKraftVector3(HullVertices[I]));

    Hull.Build;
    Hull.Finish;

    Result := TKraftShapeConvexHull.Create(fNativeScene, KraftBody, Hull);
  end;
  // New
  function AddTriangleMeshShape: TKraftShape;
  const
    MESH_EPSILON = 1e-6;
    MESH_MAX_ABS_COORD = 1.0e12;
  var
    KMesh: TKraftMesh;
    I, J: Integer;
    Mesh: TMesh;
    Meshes: TMeshList;
    TriangleCount: Integer;
    CacheSignature: UInt64;
    CacheData: TBytes;

    function CrossVector(const A, B: TVector3): TVector3;
    begin
      Result := Neslib.FastMath.Vector3(
        A.Y * B.Z - A.Z * B.Y,
        A.Z * B.X - A.X * B.Z,
        A.X * B.Y - A.Y * B.X);
    end;

    function IsUsableScalar(const S: Single): Boolean;
    begin
      Result := (S = S) and (Abs(S) < MESH_MAX_ABS_COORD);
    end;

    function IsUsableVertex(const V: TVector3): Boolean;
    begin
      Result :=
        IsUsableScalar(V.X) and
        IsUsableScalar(V.Y) and
        IsUsableScalar(V.Z);
    end;

    function IsValidTriangle(const A, B, C: TVector3): Boolean;
    var
      AB, AC, N: TVector3;
    begin
      Result := False;

      if not IsUsableVertex(A) or
         not IsUsableVertex(B) or
         not IsUsableVertex(C) then
        Exit;

      AB := B - A;
      AC := C - A;
      N := CrossVector(AB, AC);

      Result := N.LengthSquared > MESH_EPSILON * MESH_EPSILON;
    end;

    function IsValidMeshIndex(Mesh: TMesh; Index: Cardinal): Boolean;
    begin
      Result := Index < Cardinal(Mesh.VertexCount);
    end;

    procedure AddCollisionTriangle(const A, B, C: TVector3);
    var
      IA, IB, IC: Integer;
    begin
      if not IsValidTriangle(A, B, C) then
        Exit;

      if KMesh = nil then
      begin
        KMesh := TKraftMesh.Create(fNativeScene);
        Body.fNativeMeshes.Add(KMesh);
      end;

      IA := KMesh.AddVertex(ToKraftVector3(A), False);
      IB := KMesh.AddVertex(ToKraftVector3(B), False);
      IC := KMesh.AddVertex(ToKraftVector3(C), False);

      if (IA < 0) or (IB < 0) or (IC < 0) then
        Exit;

      if (IA = IB) or (IB = IC) or (IA = IC) then
        Exit;

      KMesh.AddTriangle(IA, IB, IC);

      Inc(TriangleCount);
    end;

  var
    I0, I1, I2: Cardinal;
    CacheStream: TBytesStream;
  begin
    Result := nil;
    KMesh := nil;
    TriangleCount := 0;

    if Body.SceneObject = nil then
      Exit;

    Meshes := Body.SceneObject.EffectiveMeshList;
    if (Meshes = nil) or (Meshes.Count = 0) then
      Exit;

    if BodyUsesCookedMeshCache(Body) then
    begin
      CacheSignature := BuildBodyCookedMeshSignature(Body);
      if TryGetCookedMeshCache(Body.SceneObject, CacheSignature, CacheData) then
      begin
        KMesh := TKraftMesh.Create(fNativeScene);
        try
          CacheStream := TBytesStream.Create(CacheData);
          try
            KMesh.LoadFromStream(CacheStream);
          finally
            CacheStream.Free;
          end;

          Body.fNativeMeshes.Add(KMesh);
          OutputDebugString(PChar(Format('Kraft mesh collider loaded from cache: %d triangles, %d vertices',
            [KMesh.CountTriangles, KMesh.CountVertices])));
          Exit(TKraftShapeMesh.Create(fNativeScene, KraftBody, KMesh));
        except
          on E: Exception do
          begin
            Body.fNativeMeshes.Remove(KMesh);
            KMesh.Free;
            KMesh := nil;
            fCookedMeshCaches.Remove(Body.SceneObject);
            OutputDebugString(PChar('Kraft mesh cache rejected: ' + E.Message));
          end;
        end;
      end;
    end;

    for I := 0 to Meshes.Count - 1 do
    begin
      Mesh := Meshes.Item[I];
      if Mesh = nil then
        Continue;

      if Mesh.VertexCount < 3 then
        Continue;

      if Mesh.IndexCount >= 3 then
      begin
        J := 0;
        while J + 2 < Mesh.IndexCount do
        begin
          I0 := Mesh.Indices[J];
          I1 := Mesh.Indices[J + 1];
          I2 := Mesh.Indices[J + 2];

          if IsValidMeshIndex(Mesh, I0) and
             IsValidMeshIndex(Mesh, I1) and
             IsValidMeshIndex(Mesh, I2) then
          begin
            AddCollisionTriangle(
              MeshVertexPosition(Mesh, Integer(I0)),
              MeshVertexPosition(Mesh, Integer(I1)),
              MeshVertexPosition(Mesh, Integer(I2)));
          end;

          Inc(J, 3);
        end;
      end
      else
      begin
        J := 0;
        while J + 2 < Mesh.VertexCount do
        begin
          AddCollisionTriangle(
            MeshVertexPosition(Mesh, J),
            MeshVertexPosition(Mesh, J + 1),
            MeshVertexPosition(Mesh, J + 2));

          Inc(J, 3);
        end;
      end;
    end;

    if (KMesh = nil) or (TriangleCount = 0) then
      Exit;

    OutputDebugString(PChar(Format('Kraft mesh collider before Finish: %d triangles, %d vertices',
      [TriangleCount, KMesh.CountVertices])));

    KMesh.Finish;

    OutputDebugString(PChar(Format('Kraft mesh collider after Finish: %d triangles, %d vertices',
      [KMesh.CountTriangles, KMesh.CountVertices])));

    Result := TKraftShapeMesh.Create(fNativeScene, KraftBody, KMesh);
  end;
  // End New
begin
  Result := False;

  if (fNativeScene = nil) or
     (Body = nil) or
     (not Body.Enabled) or
     (Body.SceneObject = nil) or
     (Body.EffectiveColliderKind = pckNone) then
    Exit;

  ClearBodyNativeGeometry(Body);

  KraftBody := TKraftRigidBody.Create(fNativeScene);
  Body.fNativeBody := KraftBody;
  KraftBody.UserData := Pointer(Body);
  KraftBody.SetRigidBodyType(BodyTypeToNative(Body.BodyType));
  if Body.UseGravity then
    KraftBody.GravityScale := Body.GravityScale
  else
    KraftBody.GravityScale := 0.0;
  KraftBody.LinearVelocityDamp := DampingToNative(Body.LinearDamping * fGlobalDamping);
  KraftBody.AngularVelocityDamp := DampingToNative(Body.AngularDamping);
  KraftBody.LinearVelocity := ToKraftVector3(Body.Velocity);
  KraftBody.AngularVelocity := ToKraftVector3(Body.AngularVelocity);
  KraftBody.CollisionGroups := [0];
  KraftBody.CollideWithCollisionGroups := [Low(TKraftRigidBodyCollisionGroup)..High(TKraftRigidBodyCollisionGroup)];

  WorldScale := GetWorldScale(Body.SceneObject);
  HalfExtents := BodyAABBHalfExtents(Body);
  Volume := System.Math.Max((HalfExtents.X * 2.0) * (HalfExtents.Y * 2.0) * (HalfExtents.Z * 2.0), PHYSICS_EPSILON);

  if Body.IsDynamic then
    Density := System.Math.Max(Body.Mass, PHYSICS_EPSILON) / Volume
  else
    Density := 0.0;

  Kind := Body.EffectiveColliderKind;
  if (Kind = pckMesh) and Body.IsDynamic then // MARK
    Kind := pckConvexHull;

  case Kind of
    pckSphere:
      Shape := TKraftShapeSphere.Create(fNativeScene, KraftBody,
        System.Math.Max(Body.Radius * System.Math.Max(Abs(WorldScale.X), System.Math.Max(Abs(WorldScale.Y), Abs(WorldScale.Z))), 0.01));

    pckCapsule:
      Shape := TKraftShapeCapsule.Create(fNativeScene, KraftBody,
        System.Math.Max(Body.Radius * System.Math.Max(Abs(WorldScale.X), Abs(WorldScale.Z)), 0.01),
        System.Math.Max(Body.HalfHeight * 2.0 * Abs(WorldScale.Y), 0.02));

    pckConvexHull:
      Shape := AddConvexHullShape;

    pckMesh:
      Shape := AddTriangleMeshShape;
  else
      Shape := TKraftShapeBox.Create(fNativeScene, KraftBody, ToKraftVector3(HalfExtents));
  end;

  if Shape = nil then
    Shape := TKraftShapeBox.Create(fNativeScene, KraftBody, ToKraftVector3(HalfExtents));

  Shape.UserData := Pointer(Body);
  Shape.Density := Density;
  Shape.Friction := PHYSICS_DEFAULT_FRICTION;
  Shape.Restitution := Body.Restitution;
  if not Body.CollisionResponse then
    Shape.Flags := Shape.Flags + [ksfSensor];

  Shape.Finish;

  KraftBody.ForcedMass := IfThen(Body.IsDynamic, System.Math.Max(Body.Mass, PHYSICS_EPSILON), 0.0);
  KraftBody.Finish;
  KraftBody.SetWorldTransformation(SceneMatrixToKraft(Body.SceneObject.WorldMatrix));
  if Body.fSleeping then
    KraftBody.SetToSleep
  else
    KraftBody.SetToAwake;

  Body.fNativeShape := Shape;
  Body.fLastNativeTransform := KraftBody.WorldTransform;
  Body.fLastNativePosition := GetWorldPosition(Body.SceneObject);
  Body.fLastNativeScale := GetWorldScale(Body.SceneObject);
  Body.fLastNativeMeshSignature := BuildBodyMeshSignature(Body);

  Result := True;
end;

procedure TPhysicsWorld.RecreateNativeBody(Body: TPhysicsBody);
begin
  {if (fNativeScene = nil) or (Body = nil) then
    Exit;

  if Body.fNativeBody <> nil then
    Body.fNativeBody.Free;

  Body.fNativeBody := nil;
  Body.fNativeShape := nil;
  ClearBodyNativeGeometry(Body);

  CreateNativeBody(Body);}

  if (fNativeScene = nil) or (Body = nil) then
    Exit;

  // Do not call Body.fNativeBody.Free here.
  // TKraft likely owns objects created with TKraftRigidBody.Create(fNativeScene).
  RebuildNativeScene;
end;

function TPhysicsWorld.CreateColliderDebugMesh(Body: TPhysicsBody;
  const MeshName: string): TMesh;
const
  DEBUG_SLICES = 32;
  DEBUG_STACKS = 12;
var
  Kind: TPhysicsColliderKind;
  Vertices: TArray<TVertex>;
  Indices: TArray<GLuint>;
  WorldMatrix: TMatrix4;
  Center, WorldScale, HalfExtents: TVector3;
  XAxis, YAxis, ZAxis: TVector3;

  function AbsMax3(const A, B, C: Single): Single;
  begin
    Result := System.Math.Max(Abs(A), System.Math.Max(Abs(B), Abs(C)));
  end;

  function AbsMax2(const A, B: Single): Single;
  begin
    Result := System.Math.Max(Abs(A), Abs(B));
  end;

  procedure SetWorldBasis;
  begin
    WorldMatrix := Body.SceneObject.WorldMatrix;
    Center := Neslib.FastMath.Vector3(WorldMatrix.Columns[3]);
    XAxis := SafeNormalize(Neslib.FastMath.Vector3(WorldMatrix.Columns[0]),
      Neslib.FastMath.Vector3(1, 0, 0));
    YAxis := SafeNormalize(Neslib.FastMath.Vector3(WorldMatrix.Columns[1]),
      Neslib.FastMath.Vector3(0, 1, 0));
    ZAxis := SafeNormalize(Neslib.FastMath.Vector3(WorldMatrix.Columns[2]),
      Neslib.FastMath.Vector3(0, 0, 1));
  end;

  function ToBodyWorld(const P: TVector3): TVector3;
  begin
    Result := Center + (XAxis * P.X) + (YAxis * P.Y) + (ZAxis * P.Z);
  end;

  function ToBodyWorldNormal(const N: TVector3): TVector3;
  begin
    Result := SafeNormalize((XAxis * N.X) + (YAxis * N.Y) + (ZAxis * N.Z),
      Neslib.FastMath.Vector3(0, 1, 0));
  end;

  procedure TransformGeneratedVerticesToWorld;
  var
    I: Integer;
  begin
    for I := 0 to High(Vertices) do
    begin
      Vertices[I].Position := ToBodyWorld(Vertices[I].Position);
      Vertices[I].Normal := ToBodyWorldNormal(Vertices[I].Normal);
      Vertices[I].Tangent := ToBodyWorldNormal(Vertices[I].Tangent);
      Vertices[I].Bitangent := ToBodyWorldNormal(Vertices[I].Bitangent);
    end;
  end;

  function BuildMeshColliderDebug: Boolean;
  var
    Mesh: TMesh;
    Meshes: TMeshList;
    SourceVertex: TVertex;
    I, J, VertexOffset, BaseIndex: Integer;
    NativeIndex: GLuint;
    WorldNormal: TVector3;
  begin
    Result := False;
    SetLength(Vertices, 0);
    SetLength(Indices, 0);

    if Body.SceneObject = nil then
      Exit;

    Meshes := Body.SceneObject.EffectiveMeshList;
    if not Assigned(Meshes) then
      Exit;

    for I := 0 to Meshes.Count - 1 do
    begin
      Mesh := Meshes.Item[I];
      if (Mesh = nil) or (Mesh.VertexCount = 0) then
        Continue;

      Mesh.ParentModelMatrix := Body.SceneObject.WorldMatrix;

      VertexOffset := Length(Vertices);
      SetLength(Vertices, VertexOffset + Mesh.VertexCount);
      for J := 0 to Mesh.VertexCount - 1 do
      begin
        SourceVertex := Mesh.Vertices[J];
        SourceVertex.Position := Neslib.FastMath.Vector3(
          Mesh.ModelMatrix * Vector4(SourceVertex.Position, 1.0));
        WorldNormal := Neslib.FastMath.Vector3(
          Mesh.ModelMatrix * Vector4(SourceVertex.Normal, 0.0));
        SourceVertex.Normal := SafeNormalize(WorldNormal,
          Neslib.FastMath.Vector3(0, 1, 0));
        SourceVertex.Tangent := Neslib.FastMath.Vector3(1, 0, 0);
        SourceVertex.Bitangent := Neslib.FastMath.Vector3(0, 0, 1);
        Vertices[VertexOffset + J] := SourceVertex;
      end;

      if Mesh.IndexCount > 0 then
      begin
        BaseIndex := Length(Indices);
        SetLength(Indices, BaseIndex + Mesh.IndexCount);
        for J := 0 to Mesh.IndexCount - 1 do
        begin
          NativeIndex := Mesh.Indices[J];
          if NativeIndex < GLuint(Mesh.VertexCount) then
            Indices[BaseIndex + J] := GLuint(VertexOffset) + NativeIndex
          else
            Indices[BaseIndex + J] := GLuint(VertexOffset);
        end;
      end
      else
      begin
        BaseIndex := Length(Indices);
        SetLength(Indices, BaseIndex + Mesh.VertexCount);
        for J := 0 to Mesh.VertexCount - 1 do
          Indices[BaseIndex + J] := GLuint(VertexOffset + J);
      end;
    end;

    Result := (Length(Vertices) > 0) and (Length(Indices) > 0);
  end;

begin
  Result := nil;

  if (Body = nil) or (Body.SceneObject = nil) or (not Body.Enabled) then
    Exit;

  if Assigned(fSceneRoot) then
    fSceneRoot.UpdateWorldMatrices;

  Kind := Body.EffectiveColliderKind;
  if Kind = pckNone then
    Exit;

  if (Kind = pckMesh) and Body.IsDynamic then
    Kind := pckConvexHull;

  if Kind = pckConvexHull then
    Exit(CreateConvexHullDebugMesh(Body, MeshName));

  SetWorldBasis;

  case Kind of
    pckSphere:
      begin
        WorldScale := GetWorldScale(Body.SceneObject);
        CreateSphereVertices(Vertices, Indices,
          System.Math.Max(Body.Radius * AbsMax3(WorldScale.X, WorldScale.Y,
          WorldScale.Z), 0.01), DEBUG_STACKS, DEBUG_SLICES);
        TransformGeneratedVerticesToWorld;
      end;

    pckCapsule:
      begin
        WorldScale := GetWorldScale(Body.SceneObject);
        CreateCapsuleVertices(Vertices, Indices,
          System.Math.Max(Body.Radius * AbsMax2(WorldScale.X, WorldScale.Z), 0.01),
          System.Math.Max(Body.HalfHeight * 2.0 * Abs(WorldScale.Y), 0.02),
          DEBUG_SLICES, DEBUG_STACKS);
        TransformGeneratedVerticesToWorld;
      end;

    pckMesh:
      begin
        if not BuildMeshColliderDebug then
          Exit;
      end;
  else
      begin
        HalfExtents := BodyAABBHalfExtents(Body);
        CreateCubeVertices(Vertices, Indices, HalfExtents.X * 2.0,
          HalfExtents.Y * 2.0, HalfExtents.Z * 2.0, 1, 1, 1);
        TransformGeneratedVerticesToWorld;
      end;
  end;

  if (Length(Vertices) = 0) or (Length(Indices) = 0) then
    Exit;

  Result := TMesh.Create(Vertices, Indices, MeshName, mtEmpty, True);
  Result.WireFrame := True;
  Result.AlwaysOnTop := False;
end;

function TPhysicsWorld.CreateConvexHullDebugMesh(Body: TPhysicsBody;
  const MeshName: string): TMesh;
var
  HullShape: TKraftShapeConvexHull;
  Hull: TKraftConvexHull;
  Vertices: TArray<TVertex>;
  Indices: TArray<GLuint>;
  WorldTransform: TKraftMatrix4x4;
  CurrentTransform: TKraftMatrix4x4;
  Face: TKraftConvexHullFace;
  FaceIndex, FanIndex: Integer;

  function AddDebugVertex(VertexIndex: Integer; const NativeNormal: TKraftVector3): GLuint;
  var
    NewIndex: Integer;
    NativePosition, WorldPosition, WorldNormal: TKraftVector3;
  begin
    NewIndex := Length(Vertices);
    SetLength(Vertices, NewIndex + 1);

    NativePosition := Hull.Vertices[VertexIndex].Position;
    WorldPosition := Kraft.Vector3TermMatrixMul(NativePosition, WorldTransform);
    WorldNormal := Kraft.Vector3TermMatrixMulBasis(NativeNormal, WorldTransform);

    Vertices[NewIndex].Position := FromKraftVector3(WorldPosition);
    Vertices[NewIndex].Normal := SafeNormalize(FromKraftVector3(WorldNormal),
      Neslib.FastMath.Vector3(0, 1, 0));
    Vertices[NewIndex].Tangent := Neslib.FastMath.Vector3(1, 0, 0);
    Vertices[NewIndex].Bitangent := Neslib.FastMath.Vector3(0, 0, 1);
    Vertices[NewIndex].TexCoord := Neslib.FastMath.Vector2(0, 0);

    Result := GLuint(NewIndex);
  end;

  procedure AddDebugTriangle(I0, I1, I2: Integer; const NativeNormal: TKraftVector3);
  var
    BaseIndex: Integer;
  begin
    if (I0 < 0) or (I1 < 0) or (I2 < 0) or
       (I0 >= Hull.CountVertices) or
       (I1 >= Hull.CountVertices) or
       (I2 >= Hull.CountVertices) then
      Exit;

    BaseIndex := Length(Indices);
    SetLength(Indices, BaseIndex + 3);
    Indices[BaseIndex] := AddDebugVertex(I0, NativeNormal);
    Indices[BaseIndex + 1] := AddDebugVertex(I1, NativeNormal);
    Indices[BaseIndex + 2] := AddDebugVertex(I2, NativeNormal);
  end;

begin
  Result := nil;

  if (Body = nil) or (Body.SceneObject = nil) or (not Body.Enabled) then
    Exit;

  if Assigned(fSceneRoot) then
    fSceneRoot.UpdateWorldMatrices;

  if fNativeScene = nil then
    RebuildNativeScene;

  if (fNativeScene = nil) or (Body.fNativeBody = nil) or
     (Body.fNativeShape = nil) then
    Exit;

  if not fHasTransformBackup then
  begin
    SyncSceneBodyToNative(Body, 0.0);

    if (Body.fNativeBody = nil) or (Body.fNativeShape = nil) then
      Exit;

    if Body.IsDynamic then
    begin
      CurrentTransform := SceneMatrixToKraft(Body.SceneObject.WorldMatrix);
      Body.fNativeBody.SetWorldTransformation(CurrentTransform);
      Body.fLastNativeTransform := CurrentTransform;
      Body.fLastNativePosition := GetWorldPosition(Body.SceneObject);
    end;
  end;

  if (Body.fNativeShape = nil) or
     (not (Body.fNativeShape is TKraftShapeConvexHull)) then
    Exit;

  HullShape := TKraftShapeConvexHull(Body.fNativeShape);
  Hull := HullShape.ConvexHull;

  if (Hull = nil) or (Hull.CountVertices <= 0) or (Hull.CountFaces <= 0) then
    Exit;

  Body.fNativeShape.SynchronizeTransform;
  WorldTransform := Body.fNativeShape.WorldTransform;

  SetLength(Vertices, 0);
  SetLength(Indices, 0);

  for FaceIndex := 0 to Hull.CountFaces - 1 do
  begin
    Face := Hull.Faces[FaceIndex];
    if Face.CountVertices < 3 then
      Continue;

    for FanIndex := 1 to Face.CountVertices - 2 do
      AddDebugTriangle(Face.Vertices[0], Face.Vertices[FanIndex],
        Face.Vertices[FanIndex + 1], Face.Plane.Normal);
  end;

  if (Length(Vertices) = 0) or (Length(Indices) = 0) then
    Exit;

  Result := TMesh.Create(Vertices, Indices, MeshName, mtEmpty, True);
  Result.WireFrame := True;
  Result.AlwaysOnTop := False;
end;

procedure TPhysicsWorld.QueryNativeAABB(const MinBounds, MaxBounds: TVector3;
  IgnoreBody: TPhysicsBody; Candidates: TList<TPhysicsBody>);
var
  AABB: TKraftAABB;
  Shapes: TKraftShapeDynamicArray;
  Count: TKraftSizeInt;
  I: Integer;
  Shape: TKraftShape;
  Body: TPhysicsBody;
begin
  if Candidates = nil then
    Exit;

  Candidates.Clear;

  if fNativeScene = nil then
    RebuildNativeScene;

  if fNativeScene = nil then
    Exit;

  AABB.Min := ToKraftVector3(MinBounds);
  AABB.Max := ToKraftVector3(MaxBounds);

  Shapes := nil;
  Count := 0;
  if not fNativeScene.IntersectionQuery(AABB, Shapes, Count) then
    Exit;

  for I := 0 to Count - 1 do
  begin
    Shape := Shapes[I];
    Body := nil;
    if (Shape <> nil) and (Shape.UserData <> nil) then
      Body := TPhysicsBody(Shape.UserData)
    else if (Shape <> nil) and (Shape.RigidBody <> nil) and (Shape.RigidBody.UserData <> nil) then
      Body := TPhysicsBody(Shape.RigidBody.UserData);

    if (Body <> nil) and (Body <> IgnoreBody) and (Candidates.IndexOf(Body) < 0) then
      Candidates.Add(Body);
  end;
end;

function TPhysicsWorld.RaycastNative(const StartPoint, Direction: TVector3;
  MaxDistance: Single; out Hit: TPhysicsHit; IgnoreBody: TPhysicsBody): Boolean;
var
  Dir: TVector3;
  Shape: TKraftShape;
  Time: TKraftScalar;
  Point, Normal: TKraftVector3;
  Filter: TPhysicsRaycastFilter;
  Body: TPhysicsBody;
begin
  Hit.Clear;

  if MaxDistance <= PHYSICS_EPSILON then
    Exit(False);

  if fNativeScene = nil then
    RebuildNativeScene;

  if fNativeScene = nil then
    Exit(False);

  Dir := SafeNormalize(Direction, Neslib.FastMath.Vector3(0, 0, 1));
  Filter := TPhysicsRaycastFilter.Create(IgnoreBody);
  try
    Result := fNativeScene.RayCast(ToKraftVector3(StartPoint), ToKraftVector3(Dir), MaxDistance,
      Shape, Time, Point, Normal, [Low(TKraftRigidBodyCollisionGroup)..High(TKraftRigidBodyCollisionGroup)],
      Filter.AcceptHit, nil);
  finally
    Filter.Free;
  end;

  if not Result then
    Exit;

  Body := nil;
  if (Shape <> nil) and (Shape.UserData <> nil) then
    Body := TPhysicsBody(Shape.UserData)
  else if (Shape <> nil) and (Shape.RigidBody <> nil) and (Shape.RigidBody.UserData <> nil) then
    Body := TPhysicsBody(Shape.RigidBody.UserData);

  Hit.Hit := True;
  Hit.Body := Body;
  Hit.Point := FromKraftVector3(Point);
  Hit.Normal := SafeNormalize(FromKraftVector3(Normal), Neslib.FastMath.Vector3(0, 1, 0));
  Hit.Time := ClampFloat(Time / MaxDistance, 0.0, 1.0);
  Hit.Penetration := 0.0;

  if (Hit.Body = nil) or (Hit.Body = IgnoreBody) then
  begin
    Hit.Clear;
    Result := False;
  end;
end;

function TPhysicsWorld.ActiveSimulationBodyCount: Integer;
var
  Body: TPhysicsBody;
begin
  Result := 0;
  for Body in fBodies do
    if (Body <> nil) and Body.Enabled and Body.IsDynamic then
      Inc(Result);
end;

function TPhysicsWorld.BodyUsesCookedMeshCache(Body: TPhysicsBody): Boolean;
var
  I: Integer;
  Mesh: TMesh;
  Meshes: TMeshList;
begin
  Result := False;

  if (Body = nil) or (Body.SceneObject = nil) or (not Body.Enabled) or
     Body.IsDynamic or (Body.EffectiveColliderKind <> pckMesh) then
    Exit;

  Meshes := Body.SceneObject.EffectiveMeshList;
  if not Assigned(Meshes) then
    Exit;

  for I := 0 to Meshes.Count - 1 do
  begin
    Mesh := Meshes.Item[I];
    if Mesh is THeightFieldMesh then
      Exit(True);
  end;
end;

function TPhysicsWorld.BuildBodyCookedMeshSignature(Body: TPhysicsBody): UInt64;
const
  FNV_OFFSET_BASIS: UInt64 = 14695981039346656037;
var
  I, J: Integer;
  Mesh: TMesh;
  Meshes: TMeshList;
  WorldScale: TVector3;
begin
  Result := FNV_OFFSET_BASIS;

  if (Body = nil) or (Body.SceneObject = nil) then
    Exit;

  if Assigned(fSceneRoot) then
    fSceneRoot.UpdateWorldMatrices;

  WorldScale := GetWorldScale(Body.SceneObject);
  HashUInt64(Result, UInt64(Ord(Body.EffectiveColliderKind)));
  HashVector3(Result, WorldScale);
  Meshes := Body.SceneObject.EffectiveMeshList;
  if not Assigned(Meshes) then
  begin
    HashUInt64(Result, 0);
    Exit;
  end;

  HashUInt64(Result, UInt64(Meshes.Count));
  for I := 0 to Meshes.Count - 1 do
  begin
    Mesh := Meshes.Item[I];
    if Mesh = nil then
    begin
      HashUInt64(Result, 0);
      Continue;
    end;

    HashUInt64(Result, UInt64(Ord(Mesh.MeshType)));
    HashUInt64(Result, UInt64(Mesh.VertexCount));
    HashUInt64(Result, UInt64(Mesh.IndexCount));
    HashMatrix4(Result, Mesh.LocalMatrix);
    HashVector3(Result, Mesh.BoundingBoxMin);
    HashVector3(Result, Mesh.BoundingBoxMax);

    for J := 0 to Mesh.VertexCount - 1 do
      HashVector3(Result, Mesh.Vertices[J].Position);

    for J := 0 to Mesh.IndexCount - 1 do
      HashUInt64(Result, UInt64(Mesh.Indices[J]));
  end;
end;

procedure TPhysicsWorld.StoreCookedMeshCache(ASceneObject: TSceneObject;
  Signature: UInt64; const Data: TBytes);
var
  Entry: TPhysicsCookedMeshCacheEntry;
begin
  if (ASceneObject = nil) or (Signature = 0) or (Length(Data) = 0) then
    Exit;

  Entry := TPhysicsCookedMeshCacheEntry.Create;
  Entry.Signature := Signature;
  Entry.Data := Copy(Data);

  fCookedMeshCaches.Remove(ASceneObject);
  fCookedMeshCaches.Add(ASceneObject, Entry);
end;

procedure TPhysicsWorld.ClearCookedMeshCaches;
begin
  fCookedMeshCaches.Clear;
end;

function TPhysicsWorld.TryGetCookedMeshCache(ASceneObject: TSceneObject;
  Signature: UInt64; out Data: TBytes): Boolean;
var
  Entry: TPhysicsCookedMeshCacheEntry;
begin
  Result := False;
  SetLength(Data, 0);

  if (ASceneObject = nil) or (Signature = 0) then
    Exit;

  if not fCookedMeshCaches.TryGetValue(ASceneObject, Entry) then
    Exit;

  if (Entry = nil) or (Entry.Signature <> Signature) or
     (Length(Entry.Data) = 0) then
    Exit;

  Data := Copy(Entry.Data);
  Result := True;
end;

function TPhysicsWorld.TrySaveCookedMeshCache(Body: TPhysicsBody;
  Stream: TStream; out Signature: UInt64): Boolean;
var
  Data: TBytes;
  NativeMesh: TKraftMesh;
  RuntimeSignature: UInt64;
begin
  Result := False;
  Signature := 0;

  if (Stream = nil) or (not BodyUsesCookedMeshCache(Body)) then
    Exit;

  Signature := BuildBodyCookedMeshSignature(Body);
  if Signature = 0 then
    Exit;

  if TryGetCookedMeshCache(Body.SceneObject, Signature, Data) then
  begin
    Stream.WriteBuffer(Data[0], Length(Data));
    Exit(True);
  end;

  EnsureNativeScene;

  RuntimeSignature := BuildBodyMeshSignature(Body);
  if (Body.fNativeBody = nil) or (Body.fNativeMeshes.Count = 0) or
     (Body.fLastNativeMeshSignature <> RuntimeSignature) then
  begin
    RecreateNativeBody(Body);
    Signature := BuildBodyCookedMeshSignature(Body);
  end;

  if Body.fNativeMeshes.Count = 0 then
    Exit;

  NativeMesh := Body.fNativeMeshes[0];
  if NativeMesh = nil then
    Exit;

  NativeMesh.SaveToStream(Stream);
  Result := True;
end;

procedure TPhysicsWorld.CaptureSceneTransforms;
var
  Body: TPhysicsBody;
  Snapshot: TPhysicsTransformSnapshot;
begin
  //ClearNativeScene;
  fTransformBackup.Clear;
  for Body in fBodies do
  begin
    if (Body = nil) or (Body.SceneObject = nil) or (not Body.Enabled) then
      Continue;

    if Body.ColliderKind = pckAuto then
      Body.AutoFitColliderFromScene;

    Snapshot.Body := Body;
    Snapshot.SceneObject := Body.SceneObject;
    Snapshot.Position := Body.SceneObject.Position;
    Snapshot.Scale := Body.SceneObject.Scale;
    Snapshot.Orientation := Body.SceneObject.Orientation;
    Snapshot.Velocity := Body.Velocity;
    Snapshot.BodyState := Body.GetState;
    fTransformBackup.Add(Snapshot);
  end;
  fHasTransformBackup := fTransformBackup.Count > 0;
end;

procedure TPhysicsWorld.RestoreSceneTransforms(DisableDynamicBodies: Boolean);
var
  Snapshot: TPhysicsTransformSnapshot;

  procedure RestoreBodyStateFast(Body: TPhysicsBody; const State: TPhysicsBodyState);
  begin
    Body.fBodyType := State.BodyType;
    Body.fColliderKind := State.ColliderKind;
    Body.fEnabled := State.Enabled;
    Body.fCollisionResponse := State.CollisionResponse;
    Body.fUseGravity := State.UseGravity;
    Body.fMass := System.Math.Max(0.0, State.Mass);
    Body.fRestitution := System.Math.Max(0.0, State.Restitution);
    Body.fLinearDamping := ClampFloat(State.LinearDamping, 0.0, 1.0);
    Body.fGravityScale := State.GravityScale;
    Body.fVelocity := Neslib.FastMath.Vector3(0, 0, 0);
    Body.fAngularVelocity := Neslib.FastMath.Vector3(0, 0, 0);
    Body.fAngularDamping := ClampFloat(State.AngularDamping, 0.0, 1.0);
    Body.fRadius := System.Math.Max(0.01, State.Radius);
    Body.fHalfHeight := System.Math.Max(0.01, State.HalfHeight);
    Body.fAABBHalfExtents := Neslib.FastMath.Vector3(
      System.Math.Max(0.01, State.AABBHalfExtents.X),
      System.Math.Max(0.01, State.AABBHalfExtents.Y),
      System.Math.Max(0.01, State.AABBHalfExtents.Z));
    Body.fStepHeight := System.Math.Max(0.0, State.StepHeight);

    Body.fIsGrounded := False;
    Body.fHasContact := False;
    Body.fSleeping := False;

    Body.UpdateInverseMass;
    Body.ClearForces;
  end;

  procedure PushBodyToNative(Body: TPhysicsBody);
  var
    Tx: TKraftMatrix4x4;
  begin
    if (Body = nil) or
       (Body.SceneObject = nil) or
       (Body.fNativeBody = nil) or
       (not Body.Enabled) then
      Exit;

    Tx := SceneMatrixToKraft(Body.SceneObject.WorldMatrix);

    Body.fNativeBody.SetWorldTransformation(Tx);
    Body.fNativeBody.LinearVelocity := ToKraftVector3(Body.fVelocity);
    Body.fNativeBody.AngularVelocity := ToKraftVector3(Body.fAngularVelocity);

    if Body.UseGravity then
      Body.fNativeBody.GravityScale := Body.GravityScale
    else
      Body.fNativeBody.GravityScale := 0.0;

    if Body.fNativeShape <> nil then
    begin
      Body.fNativeShape.Restitution := Body.Restitution;

      if Body.CollisionResponse then
        Body.fNativeShape.Flags := Body.fNativeShape.Flags - [ksfSensor]
      else
        Body.fNativeShape.Flags := Body.fNativeShape.Flags + [ksfSensor];
    end;

    Body.fLastNativeTransform := Tx;
    Body.fLastNativePosition := GetWorldPosition(Body.SceneObject);
    Body.fLastNativeScale := GetWorldScale(Body.SceneObject);

    if Body.IsDynamic then
      Body.fNativeBody.SetToAwake;
  end;

begin
  // Do NOT clear the native scene for normal stop/reset.

  for Snapshot in fTransformBackup do
  begin
    if Snapshot.SceneObject = nil then
      Continue;

    Snapshot.SceneObject.Position := Snapshot.Position;
    Snapshot.SceneObject.Scale := Snapshot.Scale;
    Snapshot.SceneObject.Orientation := Snapshot.Orientation;

    if Snapshot.Body <> nil then
    begin
      RestoreBodyStateFast(Snapshot.Body, Snapshot.BodyState);

      if DisableDynamicBodies and Snapshot.Body.IsDynamic then
        Snapshot.Body.fEnabled := False;
    end;
  end;

  if Assigned(fSceneRoot) then
    fSceneRoot.UpdateWorldMatrices;

  fAccumulator := 0.0;

  if DisableDynamicBodies then
  begin
    // Only do this when you really want the native bodies gone.
    ClearNativeScene;
  end
  else
  begin
    for Snapshot in fTransformBackup do
      PushBodyToNative(Snapshot.Body);
  end;

  ClearTransformBackup;
end;

procedure TPhysicsWorld.ClearTransformBackup;
begin
  fTransformBackup.Clear;
  fHasTransformBackup := False;
end;

function TPhysicsWorld.TryGetStagedBodyState(ASceneObject: TSceneObject;
  out State: TPhysicsBodyState): Boolean;
begin
  Result := (ASceneObject <> nil) and fStagedBodyStates.TryGetValue(ASceneObject, State);
end;

procedure TPhysicsWorld.StageBodyState(ASceneObject: TSceneObject;
  const State: TPhysicsBodyState);
begin
  if ASceneObject <> nil then
    fStagedBodyStates.AddOrSetValue(ASceneObject, State);
end;

{procedure TPhysicsWorld.ApplyStagedBodyStates;
var
  Pair: TPair<TSceneObject, TPhysicsBodyState>;
  Body: TPhysicsBody;
begin
  ClearNativeScene;
  for Pair in fStagedBodyStates do
  begin
    Body := FindBody(Pair.Key);
    if Body = nil then
      Body := AddBody(Pair.Key, Pair.Value.BodyType, Pair.Value.ColliderKind);
    Body.ApplyState(Pair.Value);
  end;
end;}

procedure TPhysicsWorld.ApplyStagedBodyStates;
var
  Pair: TPair<TSceneObject, TPhysicsBodyState>;
  Body: TPhysicsBody;
begin
  if fStagedBodyStates.Count = 0 then
    Exit;

  // Only clear/rebuild when something actually changed.
  ClearNativeScene;

  for Pair in fStagedBodyStates do
  begin
    Body := FindBody(Pair.Key);

    if Body = nil then
      Body := AddBody(Pair.Key, Pair.Value.BodyType, Pair.Value.ColliderKind);

    Body.ApplyState(Pair.Value);
  end;

  // Important: otherwise every Play applies the same staged states again
  // and keeps forcing a native rebuild.
  fStagedBodyStates.Clear;
end;

procedure TPhysicsWorld.ClearStagedBodyStates;
begin
  fStagedBodyStates.Clear;
end;

procedure TPhysicsWorld.RegisterStaticMeshes(ASceneObject: TSceneObject; Recursive: Boolean;
  AColliderKind: TPhysicsColliderKind);
var
  I: Integer;
  Body: TPhysicsBody;
begin
  if ASceneObject = nil then
    Exit;

  if ASceneObject.HasGeometry then
  begin
    Body := AddBody(ASceneObject, pbtStatic, AColliderKind);
    Body.Enabled := True;
    Body.CollisionResponse := True;
  end;

  if Recursive then
    for I := 0 to ASceneObject.Count - 1 do
      RegisterStaticMeshes(ASceneObject.ObjectList[I], True, AColliderKind);
end;

function TPhysicsWorld.GetWorldPosition(Obj: TSceneObject): TVector3;
begin
  if Obj = nil then
    Exit(Neslib.FastMath.Vector3(0, 0, 0));
  Result := Vector3(Obj.WorldMatrix.Columns[3]);
end;

procedure TPhysicsWorld.SetWorldPosition(Obj: TSceneObject; const WorldPosition: TVector3);
var
  Local: TVector4;
begin
  if Obj = nil then
    Exit;

  if Obj.Parent <> nil then
  begin
    Local := Obj.Parent.WorldMatrix.Inverse * Vector4(WorldPosition, 1.0);
    Obj.Position := Vector3(Local);
  end
  else
    Obj.Position := WorldPosition;
end;

function TPhysicsWorld.GetWorldScale(Obj: TSceneObject): TVector3;
var
  ParentScale: TVector3;
begin
  if Obj = nil then
    Exit(Neslib.FastMath.Vector3(1, 1, 1));

  Result := Obj.Scale;
  if Obj.Parent <> nil then
  begin
    ParentScale := GetWorldScale(Obj.Parent);
    Result := Neslib.FastMath.Vector3(Result.X * ParentScale.X, Result.Y * ParentScale.Y, Result.Z * ParentScale.Z);
  end;
end;

function TPhysicsWorld.BuildBodyMeshSignature(Body: TPhysicsBody): UInt64;
const
  FNV_OFFSET_BASIS: UInt64 = 14695981039346656037;
var
  I: Integer;
  Mesh: TMesh;
  Meshes: TMeshList;
begin
  Result := FNV_OFFSET_BASIS;

  if (Body = nil) or (Body.SceneObject = nil) then
    Exit;

  Meshes := Body.SceneObject.EffectiveMeshList;
  if not Assigned(Meshes) then
  begin
    HashUInt64(Result, 0);
    Exit;
  end;

  HashUInt64(Result, UInt64(Meshes.Count));
  for I := 0 to Meshes.Count - 1 do
  begin
    Mesh := Meshes.Item[I];
    if Mesh = nil then
    begin
      HashUInt64(Result, 0);
      Continue;
    end;

    HashUInt64(Result, UInt64(NativeUInt(Pointer(Mesh))));
    HashUInt64(Result, UInt64(Mesh.VertexCount));
    HashUInt64(Result, UInt64(Mesh.IndexCount));
    HashMatrix4(Result, Mesh.LocalMatrix);
    HashVector3(Result, Mesh.BoundingBoxMin);
    HashVector3(Result, Mesh.BoundingBoxMax);
  end;
end;

function TPhysicsWorld.BodyAABBHalfExtents(Body: TPhysicsBody): TVector3;
var
  S: TVector3;
begin
  Result := Neslib.FastMath.Vector3(0.5, 0.5, 0.5);
  if Body = nil then
    Exit;

  S := GetWorldScale(Body.SceneObject);
  Result := Neslib.FastMath.Vector3(
    System.Math.Max(Body.AABBHalfExtents.X * Abs(S.X), 0.02),
    System.Math.Max(Body.AABBHalfExtents.Y * Abs(S.Y), 0.02),
    System.Math.Max(Body.AABBHalfExtents.Z * Abs(S.Z), 0.02));
end;

function TPhysicsWorld.TryBuildBodyAABB(Body: TPhysicsBody; out MinBounds,
  MaxBounds: TVector3): Boolean;
var
  AABB: TKraftAABB;
  Center, Extents: TVector3;
begin
  Result := False;
  if (Body = nil) or (Body.SceneObject = nil) or (not Body.Enabled) then
    Exit;

  if Body.fNativeShape <> nil then
  begin
    AABB := Body.fNativeShape.WorldAABB;
    MinBounds := FromKraftVector3(AABB.Min);
    MaxBounds := FromKraftVector3(AABB.Max);
    Exit(True);
  end;

  if (Body.ColliderKind in [pckAuto, pckMesh, pckConvexHull]) and
     TryBuildObjectMeshAABB(Body.SceneObject, MinBounds, MaxBounds) then
    Exit(True);

  Center := GetWorldPosition(Body.SceneObject);
  Extents := BodyAABBHalfExtents(Body);
  MinBounds := Center - Extents;
  MaxBounds := Center + Extents;
  Result := True;
end;

function TPhysicsWorld.TryBuildObjectMeshAABB(Obj: TSceneObject; out MinBounds,
  MaxBounds: TVector3): Boolean;
var
  I: Integer;
  Mesh: TMesh;
  Meshes: TMeshList;
  Box: TAABB;
begin
  Result := False;
  if Obj = nil then
    Exit;

  Meshes := Obj.EffectiveMeshList;
  if not Assigned(Meshes) then
    Exit;

  for I := 0 to Meshes.Count - 1 do
  begin
    Mesh := Meshes.Item[I];
    if Mesh = nil then
      Continue;
    Mesh.ParentModelMatrix := Obj.WorldMatrix;
    Box := Mesh.GetBoundingBox.Transform(Mesh.ModelMatrix);
    if not Result then
    begin
      MinBounds := Box.Min;
      MaxBounds := Box.Max;
      Result := True;
    end
    else
    begin
      MinBounds := MinVector(MinBounds, Box.Min);
      MaxBounds := MaxVector(MaxBounds, Box.Max);
    end;
  end;
end;

procedure TPhysicsWorld.RemoveSceneReferencesForObject(ASceneObject: TSceneObject;
  ABody: TPhysicsBody);
var
  I: Integer;
  Snapshot: TPhysicsTransformSnapshot;
begin
  if (ASceneObject = nil) and (ABody = nil) then
    Exit;

  if ASceneObject <> nil then
  begin
    fStagedBodyStates.Remove(ASceneObject);
    fCookedMeshCaches.Remove(ASceneObject);
  end;

  for I := fTransformBackup.Count - 1 downto 0 do
  begin
    Snapshot := fTransformBackup[I];
    if ((ASceneObject <> nil) and (Snapshot.SceneObject = ASceneObject)) or
       ((ABody <> nil) and (Snapshot.Body = ABody)) then
      fTransformBackup.Delete(I);
  end;

  fHasTransformBackup := fTransformBackup.Count > 0;
end;

procedure TPhysicsWorld.ClearNativeScene;
var
  Body: TPhysicsBody;
  Scene: TKraft;
begin

  for Body in fBodies do
    if Body <> nil then
    begin
      Body.fNativeBody := nil;
      Body.fNativeShape := nil;
      Body.fLastNativeMeshSignature := 0;
      Body.fHasContact := False;
      ClearBodyNativeGeometry(Body);
    end;

  Scene := fNativeScene;
  fNativeScene := nil;

  if Scene <> nil then
    Scene.Free;
end;

procedure TPhysicsWorld.ClearBodyNativeGeometry(Body: TPhysicsBody);
begin
  if Body = nil then
    Exit;
  Body.fNativeMeshes.Clear;
  Body.fNativeConvexHulls.Clear;
end;

procedure TPhysicsWorld.RebuildNativeScene;
var
  Body: TPhysicsBody;
begin
  ClearNativeScene;

  fNativeStep := System.Math.Max(fMaxSubStep, 1.0 / 240.0);
  fAccumulator := 0.0;

  fNativeScene := TKraft.Create(fPasMP);
  fNativeScene.SetFrequency(1.0 / fNativeStep);
  fNativeScene.Gravity.Vector := ToKraftVector3(fGravity);
  fNativeScene.ContinuousMode := kcmTimeOfImpactSubSteps;
  fNativeScene.SpeculativeIterations := 8;
  fNativeScene.TimeOfImpactIterations := 20;
  fNativeScene.ContactManager.OnContactBegin := fNativeContactListener.BeginContact;
  fNativeScene.ContactManager.OnContactStay := fNativeContactListener.BeginContact;
  fNativeScene.ContactManager.OnContactEnd := fNativeContactListener.EndContact;

  if Assigned(fSceneRoot) then
    fSceneRoot.UpdateWorldMatrices;

  for Body in fBodies do
  begin
    if (Body <> nil) and (Body.ColliderKind = pckAuto) then
      Body.AutoFitColliderFromScene;

    CreateNativeBody(Body);

  end;
end;

procedure TPhysicsWorld.SyncBodyFromNative(Body: TPhysicsBody);
var
  Tx: TKraftMatrix4x4;
begin
  if (Body = nil) or (Body.fNativeBody = nil) or (Body.SceneObject = nil) then
    Exit;

  Body.fVelocity := FromKraftVector3(Body.fNativeBody.LinearVelocity);
  Body.fAngularVelocity := FromKraftVector3(Body.fNativeBody.AngularVelocity);
  Body.fSleeping := not (krbfAwake in Body.fNativeBody.Flags);

  if not Body.IsDynamic then
    Exit;

  Tx := Body.fNativeBody.WorldTransform;
  SetWorldPosition(Body.SceneObject, KraftMatrixToPosition(Tx));
  Body.SceneObject.Orientation := KraftMatrixToFastQuaternion(Tx);
  Body.fLastNativeTransform := Tx;
  Body.fLastNativePosition := KraftMatrixToPosition(Tx);
  if Body.SceneObject.Parent <> nil then
    Body.SceneObject.UpdateWorldMatrices(Body.SceneObject.Parent.WorldMatrix)
  else
    Body.SceneObject.UpdateWorldMatrices;
end;

procedure TPhysicsWorld.SyncNativeBodiesToScene;
var
  Body: TPhysicsBody;
begin
  for Body in fBodies do
    SyncBodyFromNative(Body);
end;

procedure TPhysicsWorld.Step(DeltaTime: Single);
var
  I: Integer;
  StepsDone: Integer;
  ClampedDelta: Single;
begin
  if DeltaTime <= 0.0 then
    Exit;

  if Assigned(fSceneRoot) then
    fSceneRoot.UpdateWorldMatrices;

  if (not fHasTransformBackup) and HasActiveSimulationBodies then
    CaptureSceneTransforms;

  if (fNativeScene = nil) or
     (Abs(fNativeStep - System.Math.Max(fMaxSubStep, 1.0 / 240.0)) > PHYSICS_EPSILON) then
    RebuildNativeScene;

  if fNativeScene = nil then
    Exit;

  fNativeScene.Gravity.Vector := ToKraftVector3(fGravity);
  fNativeScene.ContinuousMode := kcmTimeOfImpactSubSteps;
  fNativeScene.VelocityIterations := System.Math.Max(fSolverIterations, 1);
  fNativeScene.PositionIterations := System.Math.Max(fSolverIterations div 2, 1);
  fNativeScene.SpeculativeIterations := 8;
  fNativeScene.TimeOfImpactIterations := 20;

  // Prevent death-spiral after a pause/debug break.
  ClampedDelta := System.Math.Min(DeltaTime, fNativeStep * fMaxSubSteps);
  fAccumulator := fAccumulator + ClampedDelta;

  // Clear contact state immediately before the first native step.  Clearing
  // before DeltaTime was accumulated let contacts remain latched on common
  // fixed-step frame timings.
  if fAccumulator + PHYSICS_EPSILON >= fNativeStep then
    for I := 0 to fBodies.Count - 1 do
      if fBodies[I] <> nil then
      begin
        fBodies[I].fHasContact := False;
        fBodies[I].fIsGrounded := False;
      end;

  StepsDone := 0;

  {while (fAccumulator + PHYSICS_EPSILON >= fNativeStep) and
        (StepsDone < fMaxSubSteps) do
  begin
    SyncSceneToNative(fNativeStep);
    fNativeScene.Step(fNativeStep);
    fAccumulator := fAccumulator - fNativeStep;
    Inc(StepsDone);
  end;}

  while (fAccumulator + PHYSICS_EPSILON >= fNativeStep) and
        (StepsDone < fMaxSubSteps) do
  begin
    SyncSceneToNative(fNativeStep);
    fNativeScene.Step(fNativeStep);
    fAccumulator := fAccumulator - fNativeStep;
    Inc(StepsDone);
  end;

  if StepsDone > 0 then
    SyncNativeBodiesToScene;

  if StepsDone >= fMaxSubSteps then
    fAccumulator := 0.0;

  for I := 0 to fBodies.Count - 1 do
    if fBodies[I] <> nil then
      fBodies[I].ClearForces;
end;

function TPhysicsWorld.TestSphereAgainstBody(const Center: TVector3; Radius: Single;
  Body: TPhysicsBody; out Point, Normal: TVector3; out Penetration: Single): Boolean;
var
  MinB, MaxB, Closest, Delta: TVector3;
  DistSq, Dist: Single;
begin
  Result := False;
  if (Body = nil) or (not Body.Enabled) or
     (not TryBuildBodyAABB(Body, MinB, MaxB)) then
    Exit;

  Closest := ClosestPointOnAABB(Center, MinB, MaxB);
  Delta := Center - Closest;
  DistSq := Delta.LengthSquared;
  if DistSq > Sqr(Radius) then
    Exit;

  Dist := Sqrt(System.Math.Max(DistSq, 0.0));
  Point := Closest;
  Normal := SafeNormalize(Delta, Neslib.FastMath.Vector3(0, 1, 0));
  Penetration := Radius - Dist;
  Result := True;
end;

function TPhysicsWorld.TestCapsuleAgainstBody(const SegmentA, SegmentB: TVector3; Radius: Single;
  Body: TPhysicsBody; out Point, Normal: TVector3; out Penetration: Single): Boolean;
var
  I: Integer;
  Sample, TestPoint, TestNormal: TVector3;
  TestPenetration, BestPenetration: Single;
begin
  Result := False;
  BestPenetration := -MaxSingle;
  for I := 0 to 2 do
  begin
    case I of
      0: Sample := SegmentA;
      1: Sample := SegmentB;
    else
      Sample := (SegmentA + SegmentB) * 0.5;
    end;

    if TestSphereAgainstBody(Sample, Radius, Body, TestPoint, TestNormal, TestPenetration) and
       (TestPenetration > BestPenetration) then
    begin
      BestPenetration := TestPenetration;
      Point := TestPoint;
      Normal := TestNormal;
      Penetration := TestPenetration;
      Result := True;
    end;
  end;
end;

function TPhysicsWorld.TestSphereWorld(const Center: TVector3; Radius: Single;
  IgnoreBody: TPhysicsBody; out Hit: TPhysicsHit): Boolean;
var
  Candidates: TList<TPhysicsBody>;
  Body: TPhysicsBody;
  Point, Normal: TVector3;
  Penetration, BestPenetration: Single;
  Extents: TVector3;
begin
  Hit.Clear;
  BestPenetration := -MaxSingle;

  Extents := Neslib.FastMath.Vector3(Radius, Radius, Radius);

  Candidates := TList<TPhysicsBody>.Create;
  try
    QueryNativeAABB(
      Center - Extents,
      Center + Extents,
      IgnoreBody,
      Candidates);

    for Body in Candidates do
    begin
      if TestSphereAgainstBody(Center, Radius, Body, Point, Normal, Penetration) and
         (Penetration > BestPenetration) then
      begin
        BestPenetration := Penetration;

        Hit.Hit := True;
        Hit.Body := Body;
        Hit.Point := Point;
        Hit.Normal := Normal;
        Hit.Penetration := Penetration;
      end;
    end;
  finally
    Candidates.Free;
  end;

  Result := Hit.Hit;
end;

function TPhysicsWorld.TestCapsuleWorld(const SegmentA, SegmentB: TVector3;
  Radius: Single; IgnoreBody: TPhysicsBody; out Hit: TPhysicsHit): Boolean;
var
  Candidates: TList<TPhysicsBody>;
  Body: TPhysicsBody;
  Point, Normal: TVector3;
  Penetration, BestPenetration: Single;
  MinBounds, MaxBounds, RadiusVec: TVector3;
begin
  Hit.Clear;
  BestPenetration := -MaxSingle;

  RadiusVec := Neslib.FastMath.Vector3(Radius, Radius, Radius);
  MinBounds := MinVector(SegmentA, SegmentB) - RadiusVec;
  MaxBounds := MaxVector(SegmentA, SegmentB) + RadiusVec;

  Candidates := TList<TPhysicsBody>.Create;
  try
    QueryNativeAABB(MinBounds, MaxBounds, IgnoreBody, Candidates);

    for Body in Candidates do
    begin
      if TestCapsuleAgainstBody(SegmentA, SegmentB, Radius, Body, Point, Normal, Penetration) and
         (Penetration > BestPenetration) then
      begin
        BestPenetration := Penetration;

        Hit.Hit := True;
        Hit.Body := Body;
        Hit.Point := Point;
        Hit.Normal := Normal;
        Hit.Penetration := Penetration;
      end;
    end;
  finally
    Candidates.Free;
  end;

  Result := Hit.Hit;
end;

function TPhysicsWorld.SweepSphere(const StartPosition, Delta: TVector3; Radius: Single;
  out Hit: TPhysicsHit; IgnoreBody: TPhysicsBody): Boolean;
var
  I: Integer;
  T: Single;
  TestHit: TPhysicsHit;
begin
  Hit.Clear;
  for I := 1 to PHYSICS_SWEEP_STEPS do
  begin
    T := I / PHYSICS_SWEEP_STEPS;
    if TestSphereWorld(StartPosition + Delta * T, Radius, IgnoreBody, TestHit) then
    begin
      Hit := TestHit;
      Hit.Time := T;
      Exit(True);
    end;
  end;
  Result := False;
end;

function TPhysicsWorld.SweepCapsule(const StartPosition, Delta: TVector3; Radius,
  HalfHeight: Single; out Hit: TPhysicsHit; IgnoreBody: TPhysicsBody): Boolean;
var
  I: Integer;
  T: Single;
  Center, SegmentA, SegmentB: TVector3;
  TestHit: TPhysicsHit;
begin
  Hit.Clear;
  for I := 1 to PHYSICS_SWEEP_STEPS do
  begin
    T := I / PHYSICS_SWEEP_STEPS;
    Center := StartPosition + Delta * T;
    SegmentA := Center + Neslib.FastMath.Vector3(0, HalfHeight, 0);
    SegmentB := Center - Neslib.FastMath.Vector3(0, HalfHeight, 0);
    if TestCapsuleWorld(SegmentA, SegmentB, Radius, IgnoreBody, TestHit) then
    begin
      Hit := TestHit;
      Hit.Time := T;
      Exit(True);
    end;
  end;
  Result := False;
end;

function TPhysicsWorld.MoveCharacter(Body: TPhysicsBody; const DesiredDisplacement: TVector3;
  DeltaTime: Single; out Hit: TPhysicsHit): Boolean;
var
  StartPos, Move, Slide: TVector3;
begin
  Hit.Clear;
  Result := False;
  if (Body = nil) or (Body.SceneObject = nil) then
    Exit;

  StartPos := GetWorldPosition(Body.SceneObject);
  Move := DesiredDisplacement;
  if SweepCapsule(StartPos, Move, Body.Radius, Body.HalfHeight, Hit, Body) then
  begin
    SetWorldPosition(Body.SceneObject, StartPos + Move * System.Math.Max(Hit.Time - 0.02, 0.0));
    Slide := Move - Hit.Normal * Move.Dot(Hit.Normal);
    SetWorldPosition(Body.SceneObject, GetWorldPosition(Body.SceneObject) + Slide * (1.0 - Hit.Time));
    Result := True;
  end
  else
    SetWorldPosition(Body.SceneObject, StartPos + Move);
end;

procedure TPhysicsWorld.ApplyRadialImpulse(const Center: TVector3; Radius, Strength: Single;
  IncludeStatic: Boolean);
var
  Body: TPhysicsBody;
  ToBody: TVector3;
  Dist, Falloff: Single;
begin
  if Radius <= PHYSICS_EPSILON then
    Exit;

  for Body in fBodies do
  begin
    if (Body = nil) or (not Body.Enabled) or ((not IncludeStatic) and (not Body.IsDynamic)) then
      Continue;

    ToBody := GetWorldPosition(Body.SceneObject) - Center;
    Dist := ToBody.Length;
    if Dist > Radius then
      Continue;

    Falloff := 1.0 - Dist / Radius;
    Body.AddImpulse(SafeNormalize(ToBody, Neslib.FastMath.Vector3(0, 1, 0)) * Strength * Falloff);
  end;
end;

procedure TPhysicsWorld.ResetBodyToSceneTransform(Body: TPhysicsBody; ClearMotion: Boolean);
var
  Tx: TKraftMatrix4x4;
  WorldScale: TVector3;
  MeshSignature: UInt64;
begin
  if (Body = nil) or (Body.SceneObject = nil) or (not Body.Enabled) then
    Exit;

  if Assigned(fSceneRoot) then
    fSceneRoot.UpdateWorldMatrices;

  if fNativeScene = nil then
    Exit;

  if Body.fNativeBody = nil then
    if not CreateNativeBody(Body) then
      Exit;

  WorldScale := GetWorldScale(Body.SceneObject);
  if (Abs(WorldScale.X - Body.fLastNativeScale.X) > PHYSICS_EPSILON) or
     (Abs(WorldScale.Y - Body.fLastNativeScale.Y) > PHYSICS_EPSILON) or
     (Abs(WorldScale.Z - Body.fLastNativeScale.Z) > PHYSICS_EPSILON) then
  begin
    RecreateNativeBody(Body);
    Exit;
  end;

  if Body.EffectiveColliderKind in [pckMesh, pckConvexHull] then
  begin
    MeshSignature := BuildBodyMeshSignature(Body);
    if MeshSignature <> Body.fLastNativeMeshSignature then
    begin
      RecreateNativeBody(Body);
      Exit;
    end;
  end;

  Tx := SceneMatrixToKraft(Body.SceneObject.WorldMatrix);
  Body.fNativeBody.SetWorldTransformation(Tx);

  if ClearMotion then
  begin
    Body.fVelocity := Neslib.FastMath.Vector3(0, 0, 0);
    Body.fAngularVelocity := Neslib.FastMath.Vector3(0, 0, 0);
    Body.ClearForces;
  end;

  Body.fNativeBody.LinearVelocity := ToKraftVector3(Body.fVelocity);
  Body.fNativeBody.AngularVelocity := ToKraftVector3(Body.fAngularVelocity);
  if Body.UseGravity then
    Body.fNativeBody.GravityScale := Body.GravityScale
  else
    Body.fNativeBody.GravityScale := 0.0;

  if Body.fNativeShape <> nil then
  begin
    Body.fNativeShape.Restitution := Body.Restitution;
    if Body.CollisionResponse then
      Body.fNativeShape.Flags := Body.fNativeShape.Flags - [ksfSensor]
    else
      Body.fNativeShape.Flags := Body.fNativeShape.Flags + [ksfSensor];
  end;

  Body.fLastNativeTransform := Tx;
  Body.fLastNativePosition := GetWorldPosition(Body.SceneObject);
  Body.fLastNativeScale := WorldScale;
  Body.fIsGrounded := False;
  Body.fHasContact := False;
  Body.fSleeping := False;

  if Body.IsDynamic then
    Body.fNativeBody.SetToAwake;
end;

procedure TPhysicsWorld.ResetBodiesToSceneTransforms(ClearMotion: Boolean);
var
  Body: TPhysicsBody;
begin
  for Body in fBodies do
    ResetBodyToSceneTransform(Body, ClearMotion);
  fAccumulator := 0.0;
end;

procedure TPhysicsWorld.MarkBodyDirty(Body: TPhysicsBody);
begin
  if Body = nil then
    Exit;

  Body.fLastNativeMeshSignature := 0;
  Body.fIsGrounded := False;
  Body.fHasContact := False;
  Body.fSleeping := False;

  if Body.ColliderKind = pckAuto then
    Body.AutoFitColliderFromScene;

  if fNativeScene = nil then
    Exit;

  if Body.Enabled then
    RecreateNativeBody(Body)
  else
    Body.RemoveNativeBody;
end;

procedure TPhysicsWorld.MarkObjectDirty(ASceneObject: TSceneObject; Recursive: Boolean);
var
  I: Integer;
begin
  if ASceneObject = nil then
    Exit;

  MarkBodyDirty(FindBody(ASceneObject));

  if Recursive then
    for I := 0 to ASceneObject.Count - 1 do
      MarkObjectDirty(ASceneObject.ObjectList[I], True);
end;

procedure TPhysicsWorld.SyncSceneBodyToNative(Body: TPhysicsBody; DeltaTime: Single);
var
  WorldPos: TVector3;
  WorldScale: TVector3;
  Velocity: TVector3;
  CurrentTransform: TKraftMatrix4x4;
  MeshSignature: UInt64;
begin
  if (Body = nil) or
     (Body.fNativeBody = nil) or
     (Body.SceneObject = nil) or
     (not Body.Enabled) then
    Exit;

  WorldPos := GetWorldPosition(Body.SceneObject);
  WorldScale := GetWorldScale(Body.SceneObject);
  CurrentTransform := SceneMatrixToKraft(Body.SceneObject.WorldMatrix);

  if (Abs(WorldScale.X - Body.fLastNativeScale.X) > PHYSICS_EPSILON) or
     (Abs(WorldScale.Y - Body.fLastNativeScale.Y) > PHYSICS_EPSILON) or
     (Abs(WorldScale.Z - Body.fLastNativeScale.Z) > PHYSICS_EPSILON) then
  begin
    RecreateNativeBody(Body);
    Exit;
  end;

  if Body.EffectiveColliderKind in [pckMesh, pckConvexHull] then
  begin
    MeshSignature := BuildBodyMeshSignature(Body);
    if MeshSignature <> Body.fLastNativeMeshSignature then
    begin
      RecreateNativeBody(Body);
      Exit;
    end;
  end;

  if SameKraftMatrix(CurrentTransform, Body.fLastNativeTransform) then
    Exit;

  case Body.BodyType of
    pbtStatic:
      begin
        Body.fNativeBody.SetWorldTransformation(CurrentTransform);
        Body.fLastNativeTransform := CurrentTransform;
        Body.fLastNativePosition := WorldPos;
      end;

    pbtKinematic:
      begin
        if DeltaTime > PHYSICS_EPSILON then
          Velocity := (WorldPos - Body.fLastNativePosition) * (1.0 / DeltaTime)
        else
          Velocity := Neslib.FastMath.Vector3(0, 0, 0);

        Body.fNativeBody.SetWorldTransformation(CurrentTransform);
        Body.fNativeBody.LinearVelocity := ToKraftVector3(Velocity);
        Body.fNativeBody.SetToAwake;
        Body.fLastNativeTransform := CurrentTransform;
        Body.fLastNativePosition := WorldPos;
      end;
  end;
end;

procedure TPhysicsWorld.SyncSceneToNative(DeltaTime: Single);
var
  Body: TPhysicsBody;
begin
  for Body in fBodies do
    if (Body <> nil) and (Body.BodyType in [pbtStatic, pbtKinematic]) then
      SyncSceneBodyToNative(Body, DeltaTime);
end;

function TPhysicsWorld.Raycast(const StartPoint, Direction: TVector3;
  MaxDistance: Single; out Hit: TPhysicsHit; IgnoreBody: TPhysicsBody): Boolean;
begin
  Result := RaycastNative(StartPoint, Direction, MaxDistance, Hit, IgnoreBody);
end;

end.
