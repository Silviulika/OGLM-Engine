unit Engine.Wind;

interface

uses
  System.Classes, System.SysUtils, System.Math,
  Neslib.FastMath,
  Engine.Animation;

type
  TWindActorKind = (wakNone, wakTree, wakVertexTree);

  TWindActorSettings = record
    Enabled: Boolean;
    Kind: TWindActorKind;
    Direction: TVector3;
    Strength: Single;
    Frequency: Single;
    GustStrength: Single;
    GustFrequency: Single;
    PhaseOffset: Single;
    TrunkFlex: Single;
    BranchFlex: Single;
    LeafFlutter: Single;

    class function Disabled: TWindActorSettings; static;
    class function DefaultTree: TWindActorSettings; static;
    class function DefaultVertexTree: TWindActorSettings; static;
    procedure Sanitize;
    procedure SaveToStream(AStream: TStream);
    procedure LoadFromStream(AStream: TStream);
  end;

  TTreeWindSystem = class
  public
    class function Apply(AAnimator: TSkeletonAnimator;
      const ASettings: TWindActorSettings; ATimeSeconds: Single;
      AUseCurrentPoseAsBase: Boolean = False): Boolean; static;
  end;

implementation

const
  WIND_SETTINGS_STREAM_VERSION = 1;
  TWO_PI: Single = 6.2831853071795864769;

function AxisAngleQuaternion(const AAxis: TVector3; AAngle: Single): TQuaternion;
var
  Axis: TVector3;
begin
  Axis := AAxis;
  if Axis.LengthSquared < 1.0e-8 then
    Axis := Vector3(0.0, 0.0, 1.0)
  else
    Axis := Axis.Normalize;

  Result.Init(Axis, AAngle);
  Result := Result.Normalize;
end;

function SafeHorizontalDirection(const ADirection: TVector3): TVector3;
begin
  Result := ADirection;
  Result.Y := 0.0;
  if Result.LengthSquared < 1.0e-8 then
    Result := Vector3(1.0, 0.0, 0.0)
  else
    Result := Result.Normalize;
end;

function BoneNameContains(const AName: string;
  const AFragments: array of string): Boolean;
var
  LowerName: string;
  Fragment: string;
begin
  LowerName := LowerCase(AName);
  for Fragment in AFragments do
    if Pos(Fragment, LowerName) > 0 then
      Exit(True);
  Result := False;
end;

function BoneFlexMultiplier(ABone: TSkeletonBone;
  const ASettings: TWindActorSettings): Single;
begin
  Result := ASettings.BranchFlex;
  if ABone = nil then
    Exit;

  if BoneNameContains(ABone.Name, ['leaf', 'leaves', 'foliage', 'needle',
    'needles', 'frond', 'fronds']) then
    Result := ASettings.LeafFlutter
  else if BoneNameContains(ABone.Name, ['trunk', 'stem', 'root']) then
    Result := ASettings.TrunkFlex
  else if BoneNameContains(ABone.Name, ['branch', 'bough', 'twig']) then
    Result := ASettings.BranchFlex;
end;

{ TWindActorSettings }

class function TWindActorSettings.Disabled: TWindActorSettings;
begin
  Result.Enabled := False;
  Result.Kind := wakNone;
  Result.Direction := Vector3(1.0, 0.0, 0.0);
  Result.Strength := 0.0;
  Result.Frequency := 0.7;
  Result.GustStrength := 0.0;
  Result.GustFrequency := 0.17;
  Result.PhaseOffset := 0.0;
  Result.TrunkFlex := 0.35;
  Result.BranchFlex := 0.85;
  Result.LeafFlutter := 1.25;
end;

class function TWindActorSettings.DefaultTree: TWindActorSettings;
begin
  Result := Disabled;
  Result.Enabled := True;
  Result.Kind := wakTree;
  Result.Direction := Vector3(1.0, 0.0, 0.35);
  Result.Strength := 5.0 * Pi / 180.0;
  Result.Frequency := 0.55;
  Result.GustStrength := 0.35;
  Result.GustFrequency := 0.11;
  Result.PhaseOffset := 0.0;
  Result.TrunkFlex := 0.30;
  Result.BranchFlex := 0.90;
  Result.LeafFlutter := 1.45;
  Result.Sanitize;
end;

class function TWindActorSettings.DefaultVertexTree: TWindActorSettings;
begin
  Result := DefaultTree;
  Result.Kind := wakVertexTree;
  Result.TrunkFlex := 0.32;
  Result.BranchFlex := 0.85;
  Result.LeafFlutter := 0.65;
  Result.Sanitize;
end;

procedure TWindActorSettings.Sanitize;
begin
  if not Enabled then
  begin
    Kind := wakNone;
    Exit;
  end;

  if Kind = wakNone then
    Kind := wakTree;

  Direction := SafeHorizontalDirection(Direction);
  Strength := System.Math.EnsureRange(Strength, 0.0, Pi * 0.5);
  Frequency := System.Math.Max(0.0, Frequency);
  GustStrength := System.Math.EnsureRange(GustStrength, 0.0, 4.0);
  GustFrequency := System.Math.Max(0.0, GustFrequency);
  TrunkFlex := System.Math.EnsureRange(TrunkFlex, 0.0, 4.0);
  BranchFlex := System.Math.EnsureRange(BranchFlex, 0.0, 4.0);
  LeafFlutter := System.Math.EnsureRange(LeafFlutter, 0.0, 8.0);
end;

procedure TWindActorSettings.SaveToStream(AStream: TStream);
var
  Version: Integer;
  KindValue: Integer;
begin
  Version := WIND_SETTINGS_STREAM_VERSION;
  AStream.WriteBuffer(Version, SizeOf(Version));
  AStream.WriteBuffer(Enabled, SizeOf(Enabled));
  KindValue := Ord(Kind);
  AStream.WriteBuffer(KindValue, SizeOf(KindValue));
  AStream.WriteBuffer(Direction, SizeOf(Direction));
  AStream.WriteBuffer(Strength, SizeOf(Strength));
  AStream.WriteBuffer(Frequency, SizeOf(Frequency));
  AStream.WriteBuffer(GustStrength, SizeOf(GustStrength));
  AStream.WriteBuffer(GustFrequency, SizeOf(GustFrequency));
  AStream.WriteBuffer(PhaseOffset, SizeOf(PhaseOffset));
  AStream.WriteBuffer(TrunkFlex, SizeOf(TrunkFlex));
  AStream.WriteBuffer(BranchFlex, SizeOf(BranchFlex));
  AStream.WriteBuffer(LeafFlutter, SizeOf(LeafFlutter));
end;

procedure TWindActorSettings.LoadFromStream(AStream: TStream);
var
  Version: Integer;
  KindValue: Integer;
begin
  AStream.ReadBuffer(Version, SizeOf(Version));
  if Version <> WIND_SETTINGS_STREAM_VERSION then
    raise Exception.CreateFmt('Unsupported wind settings stream version %d.',
      [Version]);

  AStream.ReadBuffer(Enabled, SizeOf(Enabled));
  AStream.ReadBuffer(KindValue, SizeOf(KindValue));
  if (KindValue < Ord(Low(TWindActorKind))) or
     (KindValue > Ord(High(TWindActorKind))) then
    raise Exception.Create('Invalid wind actor kind in scene stream.');
  Kind := TWindActorKind(KindValue);

  AStream.ReadBuffer(Direction, SizeOf(Direction));
  AStream.ReadBuffer(Strength, SizeOf(Strength));
  AStream.ReadBuffer(Frequency, SizeOf(Frequency));
  AStream.ReadBuffer(GustStrength, SizeOf(GustStrength));
  AStream.ReadBuffer(GustFrequency, SizeOf(GustFrequency));
  AStream.ReadBuffer(PhaseOffset, SizeOf(PhaseOffset));
  AStream.ReadBuffer(TrunkFlex, SizeOf(TrunkFlex));
  AStream.ReadBuffer(BranchFlex, SizeOf(BranchFlex));
  AStream.ReadBuffer(LeafFlutter, SizeOf(LeafFlutter));
  Sanitize;
end;

{ TTreeWindSystem }

class function TTreeWindSystem.Apply(AAnimator: TSkeletonAnimator;
  const ASettings: TWindActorSettings; ATimeSeconds: Single;
  AUseCurrentPoseAsBase: Boolean): Boolean;
var
  Settings: TWindActorSettings;
  Skeleton: TSkeleton;
  BindGlobals: TArray<TMatrix4>;
  BindPositions: TArray<TVector3>;
  BindReady: TArray<Boolean>;
  BoneDepths: TArray<Integer>;
  BoneRoots: TArray<Integer>;
  ChildCounts: TArray<Integer>;
  Pose: TArray<TSkeletonTransform>;
  WindDir, TreeAxis, BendAxis, TwistAxis: TVector3;
  MinHeight, MaxHeight, HeightRange: Single;
  I, MaxDepth: Integer;

  procedure BuildBindGlobal(ABoneIndex: Integer);
  var
    Bone: TSkeletonBone;
  begin
    if (ABoneIndex < 0) or (ABoneIndex >= Skeleton.BoneCount) then
      Exit;
    if BindReady[ABoneIndex] then
      Exit;

    Bone := Skeleton.Bones[ABoneIndex];
    if (Bone <> nil) and (Bone.ParentIndex >= 0) then
    begin
      BuildBindGlobal(Bone.ParentIndex);
      BindGlobals[ABoneIndex] := BindGlobals[Bone.ParentIndex] *
        Bone.BindTransform.ToMatrix;
    end
    else if Bone <> nil then
      BindGlobals[ABoneIndex] := Bone.BindTransform.ToMatrix
    else
      BindGlobals[ABoneIndex] := TMatrix4.Identity;

    BindReady[ABoneIndex] := True;
  end;

  function BoneDepth(ABoneIndex: Integer): Integer;
  var
    Bone: TSkeletonBone;
  begin
    if (ABoneIndex < 0) or (ABoneIndex >= Skeleton.BoneCount) then
      Exit(0);
    if BoneDepths[ABoneIndex] >= 0 then
      Exit(BoneDepths[ABoneIndex]);

    Bone := Skeleton.Bones[ABoneIndex];
    if (Bone <> nil) and (Bone.ParentIndex >= 0) then
      Result := BoneDepth(Bone.ParentIndex) + 1
    else
      Result := 0;
    BoneDepths[ABoneIndex] := Result;
  end;

  function BoneRoot(ABoneIndex: Integer): Integer;
  var
    Bone: TSkeletonBone;
  begin
    if (ABoneIndex < 0) or (ABoneIndex >= Skeleton.BoneCount) then
      Exit(-1);
    if BoneRoots[ABoneIndex] >= -1 then
      Exit(BoneRoots[ABoneIndex]);

    Bone := Skeleton.Bones[ABoneIndex];
    if (Bone <> nil) and (Bone.ParentIndex >= 0) then
      Result := BoneRoot(Bone.ParentIndex)
    else
      Result := ABoneIndex;
    BoneRoots[ABoneIndex] := Result;
  end;

  function AxisInParentSpace(ABone: TSkeletonBone;
    const AAxis: TVector3): TVector3;
  var
    Axis4: TVector4;
  begin
    Result := AAxis;
    if (ABone <> nil) and (ABone.ParentIndex >= 0) and
       (ABone.ParentIndex < Skeleton.BoneCount) then
    begin
      Axis4 := BindGlobals[ABone.ParentIndex].Inverse *
        Vector4(AAxis, 0.0);
      Result := Vector3(Axis4);
    end;

    if Result.LengthSquared < 1.0e-8 then
      Result := AAxis;
    if Result.LengthSquared < 1.0e-8 then
      Result := Vector3(0.0, 1.0, 0.0)
    else
      Result := Result.Normalize;
  end;

var
  Bone: TSkeletonBone;
  BindPosition: TVector3;
  AxisCandidate, BestAxis: TVector3;
  HeightCoord, HeightWeight, DepthWeight, Weight, Flex: Single;
  AxisLengthSq, BestAxisLengthSq: Single;
  Wave, Gust, BendAngle, TwistAngle, BonePhase: Single;
  BendQ, TwistQ: TQuaternion;
  RootIndex: Integer;
begin
  Result := False;
  Settings := ASettings;
  Settings.Sanitize;

  if (not Settings.Enabled) or (Settings.Kind <> wakTree) or
     (AAnimator = nil) or (AAnimator.Skeleton = nil) then
    Exit;

  Skeleton := AAnimator.Skeleton;
  if Skeleton.BoneCount <= 0 then
    Exit;

  if AUseCurrentPoseAsBase then
    Skeleton.GetCurrentPose(Pose)
  else
    Skeleton.GetBindPose(Pose);

  SetLength(BindGlobals, Skeleton.BoneCount);
  SetLength(BindPositions, Skeleton.BoneCount);
  SetLength(BindReady, Skeleton.BoneCount);
  SetLength(BoneDepths, Skeleton.BoneCount);
  SetLength(BoneRoots, Skeleton.BoneCount);
  SetLength(ChildCounts, Skeleton.BoneCount);
  for I := 0 to High(BoneDepths) do
  begin
    BoneDepths[I] := -1;
    BoneRoots[I] := -2;
  end;

  for I := 0 to Skeleton.BoneCount - 1 do
  begin
    Bone := Skeleton.Bones[I];
    if (Bone <> nil) and (Bone.ParentIndex >= 0) and
       (Bone.ParentIndex < Skeleton.BoneCount) then
      Inc(ChildCounts[Bone.ParentIndex]);
  end;

  MaxDepth := 0;
  for I := 0 to Skeleton.BoneCount - 1 do
  begin
    BuildBindGlobal(I);
    BindPositions[I] := Vector3(BindGlobals[I].Columns[3]);
    MaxDepth := System.Math.Max(MaxDepth, BoneDepth(I));
    BoneRoot(I);
  end;

  TreeAxis := Vector3(0.0, 1.0, 0.0);
  BestAxis := TreeAxis;
  BestAxisLengthSq := 0.0;
  for I := 0 to Skeleton.BoneCount - 1 do
  begin
    RootIndex := BoneRoot(I);
    if (RootIndex < 0) or (RootIndex = I) or
       (ChildCounts[RootIndex] <= 0) then
      Continue;

    AxisCandidate := BindPositions[I] - BindPositions[RootIndex];
    AxisLengthSq := AxisCandidate.LengthSquared;
    if AxisLengthSq > BestAxisLengthSq then
    begin
      BestAxis := AxisCandidate;
      BestAxisLengthSq := AxisLengthSq;
    end;
  end;
  if BestAxisLengthSq > 1.0e-8 then
    TreeAxis := BestAxis.Normalize;

  MinHeight := MaxSingle;
  MaxHeight := -MaxSingle;
  for I := 0 to Skeleton.BoneCount - 1 do
  begin
    HeightCoord := BindPositions[I].Dot(TreeAxis);
    MinHeight := System.Math.Min(MinHeight, HeightCoord);
    MaxHeight := System.Math.Max(MaxHeight, HeightCoord);
  end;

  HeightRange := MaxHeight - MinHeight;
  WindDir := Settings.Direction - TreeAxis *
    Settings.Direction.Dot(TreeAxis);
  if WindDir.LengthSquared < 1.0e-8 then
  begin
    WindDir := Vector3(1.0, 0.0, 0.0);
    if Abs(WindDir.Dot(TreeAxis)) > 0.85 then
      WindDir := Vector3(0.0, 1.0, 0.0);
    if Abs(WindDir.Dot(TreeAxis)) > 0.85 then
      WindDir := Vector3(0.0, 0.0, 1.0);
    WindDir := WindDir - TreeAxis * WindDir.Dot(TreeAxis);
  end;
  if WindDir.LengthSquared < 1.0e-8 then
    WindDir := SafeHorizontalDirection(Settings.Direction)
  else
    WindDir := WindDir.Normalize;

  BendAxis := TreeAxis.Cross(WindDir);
  if BendAxis.LengthSquared < 1.0e-8 then
    BendAxis := Vector3(0.0, 0.0, 1.0)
  else
    BendAxis := BendAxis.Normalize;
  TwistAxis := TreeAxis;

  for I := 0 to Skeleton.BoneCount - 1 do
  begin
    Bone := Skeleton.Bones[I];
    if Bone = nil then
      Continue;

    BindPosition := BindPositions[I];
    HeightCoord := BindPosition.Dot(TreeAxis);
    if HeightRange > 1.0e-5 then
      HeightWeight := System.Math.EnsureRange((HeightCoord - MinHeight) /
        HeightRange, 0.0, 1.0)
    else if MaxDepth > 0 then
      HeightWeight := System.Math.EnsureRange(BoneDepths[I] / MaxDepth, 0.0, 1.0)
    else
      HeightWeight := 0.0;

    if MaxDepth > 0 then
      DepthWeight := System.Math.EnsureRange(BoneDepths[I] / MaxDepth, 0.0, 1.0)
    else
      DepthWeight := HeightWeight;

    Weight := Power(System.Math.Max(HeightWeight, DepthWeight * 0.65), 0.9);
    if Weight <= 1.0e-4 then
      Continue;

    Flex := BoneFlexMultiplier(Bone, Settings);
    BonePhase := Settings.PhaseOffset + I * 0.713 +
      BindPosition.X * 0.21 + BindPosition.Z * 0.17 + BoneDepths[I] * 0.37;
    Wave := Sin((ATimeSeconds * Settings.Frequency * TWO_PI) + BonePhase) *
      0.70 +
      Sin((ATimeSeconds * Settings.Frequency * TWO_PI * 1.73) +
      BonePhase * 1.91) * 0.30;
    Gust := 1.0 + Settings.GustStrength *
      (0.5 + 0.5 * Sin((ATimeSeconds * Settings.GustFrequency * TWO_PI) +
      BonePhase * 0.43));

    BendAngle := Settings.Strength * Flex * Weight * Gust * Wave;
    TwistAngle := Settings.Strength * Settings.LeafFlutter * Weight * 0.16 *
      Sin((ATimeSeconds * Settings.Frequency * TWO_PI * 4.0) +
      BonePhase * 2.3);

    BendQ := AxisAngleQuaternion(AxisInParentSpace(Bone, BendAxis),
      BendAngle);
    TwistQ := AxisAngleQuaternion(AxisInParentSpace(Bone, TwistAxis),
      TwistAngle);
    Pose[I].Rotation := (BendQ * TwistQ * Pose[I].Rotation).Normalize;
  end;

  AAnimator.SetProceduralPose(Pose);
  Result := True;
end;

end.
