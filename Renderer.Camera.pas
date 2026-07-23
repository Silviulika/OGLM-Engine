unit Renderer.Camera;

interface

uses
  System.SysUtils, System.Classes, System.Math, Neslib.FastMath;

type
  TCamera = class
  private
    fPosition: TVector3;
    fTarget: TVector3;
    fUp: TVector3;
    fWorldUp: TVector3;
    fViewMatrix: TMatrix4;
    fNeedUpdate: Boolean;
    procedure UpdateViewMatrix;
    function GetViewMatrix: TMatrix4;
    function GetFront: TVector3;
    procedure SetFront(const Value: TVector3);
    function GetLeft: TVector3;
    procedure SetLeft(const Value: TVector3);
  public
    constructor Create;
    procedure LookAt(const aPosition, Target, Up: TVector3);
    procedure SaveToStream(Stream: TStream);
    procedure LoadFromStream(Stream: TStream);
    procedure MoveForward(Distance: Single);
    procedure MoveRight(Distance: Single);
    procedure MoveUp(Distance: Single);
    procedure RotateYaw(AngleRad: Single);   // rotate around world Y
    procedure RotatePitch(AngleRad: Single); // rotate around local X (right axis)

    property Position: TVector3 read fPosition write fPosition;
    property Target: TVector3 read fTarget write fTarget;
    property Up: TVector3 read fUp write fUp;
    property ViewMatrix: TMatrix4 read GetViewMatrix;

    property Front: TVector3 read GetFront write SetFront;
    property Left: TVector3 read GetLeft write SetLeft;
  end;

implementation

{ TCamera }
constructor TCamera.Create;
begin
  inherited Create;
  fWorldUp := Vector3(0, 1, 0);
  fPosition := Vector3(0, 0, 0);
  fTarget := Vector3(0, 0, 0);
  fUp := fWorldUp;
  fNeedUpdate := True;
end;

procedure TCamera.UpdateViewMatrix;
begin
  fViewMatrix.InitLookAtRH(fPosition, fTarget, fUp);
  fNeedUpdate := False;
end;

function TCamera.GetViewMatrix: TMatrix4;
begin
  if fNeedUpdate then
    UpdateViewMatrix;
  Result := fViewMatrix;
end;

procedure TCamera.LookAt(const aPosition, Target, Up: TVector3);
begin
  fPosition := aPosition;
  fTarget := Target;
  fUp := Up;
  fNeedUpdate := True;
end;

procedure TCamera.SaveToStream(Stream: TStream);
begin
  Stream.WriteBuffer(fPosition, SizeOf(fPosition));
  Stream.WriteBuffer(fTarget, SizeOf(fTarget));
  Stream.WriteBuffer(fUp, SizeOf(fUp));
end;

procedure TCamera.LoadFromStream(Stream: TStream);
var
  SavedPosition: TVector3;
  SavedTarget: TVector3;
  SavedUp: TVector3;
begin
  Stream.ReadBuffer(SavedPosition, SizeOf(SavedPosition));
  Stream.ReadBuffer(SavedTarget, SizeOf(SavedTarget));
  Stream.ReadBuffer(SavedUp, SizeOf(SavedUp));
  LookAt(SavedPosition, SavedTarget, SavedUp);
end;
procedure TCamera.MoveForward(Distance: Single);
var
  ForwardVec: TVector3;
begin
  ForwardVec := fTarget - fPosition;
  ForwardVec.Normalize;
  fPosition := fPosition + (ForwardVec * Distance);
  fTarget := fTarget + (ForwardVec * Distance);
  fNeedUpdate := True;
end;

procedure TCamera.MoveRight(Distance: Single);
var
  RightVec: TVector3;
  ForwardVec: TVector3;
begin
  ForwardVec := fTarget - fPosition;
  ForwardVec.Normalize;
  RightVec := ForwardVec.Cross(fUp);
  RightVec.Normalize;
  fPosition := fPosition + (RightVec * Distance);
  fTarget := fTarget + (RightVec * Distance);
  fNeedUpdate := True;
end;

procedure TCamera.MoveUp(Distance: Single);
begin
  fPosition := fPosition + (fUp * Distance);
  fTarget := fTarget + (fUp * Distance);
  fNeedUpdate := True;
end;

procedure TCamera.RotateYaw(AngleRad: Single);
var
  Direction: TVector3;
  RotMat: TMatrix4;
begin
  Direction := fTarget - fPosition;
  Direction.Normalize;
  RotMat.InitRotationY(AngleRad);
  Direction := Vector3(RotMat * Vector4(Direction, 0));
  fTarget := fPosition + Direction;
  fUp := fWorldUp;
  fNeedUpdate := True;
end;

procedure TCamera.RotatePitch(AngleRad: Single);
var
  Direction: TVector3;
  RightAxis: TVector3;
  RotMat: TMatrix4;
begin
  Direction := fTarget - fPosition;
  Direction.Normalize;
  RightAxis := Direction.Cross(fWorldUp);
  RightAxis.Normalize;
  RotMat.InitRotation(RightAxis, AngleRad);
  Direction := Vector3(RotMat * Vector4(Direction, 0));
  fTarget := fPosition + Direction;
  fUp := Vector3(RotMat * Vector4(fUp, 0));
  fUp.Normalize;
  fNeedUpdate := True;
end;

{ Front property }
function TCamera.GetFront: TVector3;
var
  Dir: TVector3;
begin
  Dir := fTarget - fPosition;
  if Dir.LengthSquared < 1e-8 then
    Result := Vector3(0, 0, 1)   // fallback
  else
    Result := Dir.Normalize;
end;

procedure TCamera.SetFront(const Value: TVector3);
var
  NewFront: TVector3;
begin
  NewFront := Value.Normalize;
  fTarget := fPosition + NewFront;
  fNeedUpdate := True;
end;

{ Left property }
function TCamera.GetLeft: TVector3;
var
  FrontVec: TVector3;
begin
  FrontVec := GetFront;
  Result := FrontVec.Cross(fUp).Normalize;
end;

procedure TCamera.SetLeft(const Value: TVector3);
var
  NewLeft: TVector3;
  NewFront: TVector3;
begin
  NewLeft := Value.Normalize;
  // Compute new front direction from left and current up:
  // For a right-handed system: front = left � up
  NewFront := NewLeft.Cross(fUp).Normalize;
  fTarget := fPosition + NewFront;
  // Up remains unchanged (no need to recalc, as it stays orthogonal)
  fNeedUpdate := True;
end;

end.
