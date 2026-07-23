unit Engine.Animation;

interface

uses
  System.Classes, System.SysUtils, System.Math, System.Generics.Collections,
  Neslib.FastMath;

const
  MAX_VERTEX_BONE_INFLUENCES = 8;

type
  TAnimationInterpolation = (aiLinear, aiStep, aiCubicSpline);
  TAnimationChannelTarget = (actTranslation, actRotation, actScale);
  TAnimationPlaybackState = (apsStopped, apsPlaying, apsPaused);

  TBoneInfluence = packed record
    Joint: Integer;
    Weight: Single;
  end;

  TVertexSkinWeights = packed record
    Influences: array[0..MAX_VERTEX_BONE_INFLUENCES - 1] of TBoneInfluence;
    procedure Clear;
    procedure Normalize;
  end;

  TSkeletonTransform = record
    Translation: TVector3;
    Rotation: TQuaternion;
    Scale: TVector3;
    class function Identity: TSkeletonTransform; static;
    function ToMatrix: TMatrix4;
  end;

  TSkeletonBoneData = record
    Name: string;
    ParentIndex: Integer;
    BindTransform: TSkeletonTransform;
  end;

  TSkeletonBone = class
  private
    FIndex: Integer;
    FName: string;
    FParentIndex: Integer;
    FBindTransform: TSkeletonTransform;
    FLocalTransform: TSkeletonTransform;
    FGlobalMatrix: TMatrix4;
  public
    constructor Create(AIndex: Integer; const AData: TSkeletonBoneData);

    property Index: Integer read FIndex;
    property Name: string read FName;
    property ParentIndex: Integer read FParentIndex;
    property BindTransform: TSkeletonTransform read FBindTransform;
    property LocalTransform: TSkeletonTransform read FLocalTransform write FLocalTransform;
    property GlobalMatrix: TMatrix4 read FGlobalMatrix;
  end;

  TSkeleton = class
  private
    FBones: TObjectList<TSkeletonBone>;
    function GetBone(Index: Integer): TSkeletonBone;
    function GetBoneCount: Integer;
  public
    constructor Create(const ABones: TArray<TSkeletonBoneData>);
    destructor Destroy; override;

    function Clone: TSkeleton;
    function BoneByName(const AName: string): TSkeletonBone;
    procedure GetBindPose(out APose: TArray<TSkeletonTransform>);
    procedure GetCurrentPose(out APose: TArray<TSkeletonTransform>);
    procedure SetPose(const APose: TArray<TSkeletonTransform>);
    procedure ResetPose;
    procedure UpdateGlobalMatrices;

    property Bones[Index: Integer]: TSkeletonBone read GetBone; default;
    property BoneCount: Integer read GetBoneCount;
  end;

  TSkeletonAnimationChannel = class
  private
    FBoneIndex: Integer;
    FTarget: TAnimationChannelTarget;
    FInterpolation: TAnimationInterpolation;
    FTimes: TArray<Single>;
    FValues: TArray<TVector4>;
    FInTangents: TArray<TVector4>;
    FOutTangents: TArray<TVector4>;
    function FindKeyInterval(ATime: Single): Integer;
    function SampleValue(ATime: Single): TVector4;
  public
    constructor Create(ABoneIndex: Integer; ATarget: TAnimationChannelTarget;
      AInterpolation: TAnimationInterpolation; const ATimes: TArray<Single>;
      const AValues, AInTangents, AOutTangents: TArray<TVector4>);

    procedure Apply(ATime: Single; var ATransform: TSkeletonTransform);

    property BoneIndex: Integer read FBoneIndex;
    property Target: TAnimationChannelTarget read FTarget;
    property Interpolation: TAnimationInterpolation read FInterpolation;
    property Times: TArray<Single> read FTimes;
    property Values: TArray<TVector4> read FValues;
    property InTangents: TArray<TVector4> read FInTangents;
    property OutTangents: TArray<TVector4> read FOutTangents;
  end;

  TSkeletonAnimationClip = class
  private
    FName: string;
    FDuration: Single;
    FChannels: TObjectList<TSkeletonAnimationChannel>;
    function GetChannel(Index: Integer): TSkeletonAnimationChannel;
    function GetChannelCount: Integer;
  public
    constructor Create(const AName: string);
    destructor Destroy; override;

    function AddChannel(AChannel: TSkeletonAnimationChannel): Integer;
    procedure Evaluate(ATime: Single; ASkeleton: TSkeleton;
      out APose: TArray<TSkeletonTransform>);

    property Name: string read FName write FName;
    property Duration: Single read FDuration write FDuration;
    property Channels[Index: Integer]: TSkeletonAnimationChannel read GetChannel;
    property ChannelCount: Integer read GetChannelCount;
  end;

  TAnimationFinishedEvent = procedure(Sender: TObject;
    const AnimationName: string) of object;

  TSkeletonAnimator = class
  private
    FSkeleton: TSkeleton;
    FAnimations: TObjectList<TSkeletonAnimationClip>;
    FState: TAnimationPlaybackState;
    FCurrentAnimationIndex: Integer;
    FCurrentTime: Single;
    FPreviousAnimationIndex: Integer;
    FPreviousTime: Single;
    FBlendDuration: Single;
    FBlendElapsed: Single;
    FLoop: Boolean;
    FSpeed: Single;
    FPoseVersion: UInt64;
    FOnAnimationFinished: TAnimationFinishedEvent;
    function GetAnimation(Index: Integer): TSkeletonAnimationClip;
    function GetAnimationCount: Integer;
    function GetCurrentAnimation: TSkeletonAnimationClip;
    function GetCurrentAnimationName: string;
    function GetDuration: Single;
    function GetNormalizedTime: Single;
    function GetIsBlending: Boolean;
    function AdvanceClipTime(AClip: TSkeletonAnimationClip; var ATime: Single;
      ADelta: Single; ALoop: Boolean): Boolean;
    procedure EvaluateCurrentPose;
    procedure SetCurrentTime(const Value: Single);
    procedure SetSpeed(const Value: Single);
  public
    constructor Create(ASkeleton: TSkeleton);
    destructor Destroy; override;

    function Clone: TSkeletonAnimator;
    function AddAnimation(AAnimation: TSkeletonAnimationClip): Integer;
    function AnimationByName(const AName: string): TSkeletonAnimationClip;
    function AnimationIndexByName(const AName: string): Integer;

    function Play(const AAnimationName: string; ALoop: Boolean = True;
      ABlendDuration: Single = 0.0): Boolean; overload;
    function Play(AAnimationIndex: Integer; ALoop: Boolean = True;
      ABlendDuration: Single = 0.0): Boolean; overload;
    function BlendTo(const AAnimationName: string; ABlendDuration: Single;
      ALoop: Boolean = True): Boolean;
    procedure Pause;
    procedure Resume;
    procedure Stop(AResetToBindPose: Boolean = True);
    procedure Seek(ATime: Single);
    procedure Update(ADeltaTime: Single);
    procedure SetProceduralPose(const APose: TArray<TSkeletonTransform>);

    procedure SaveToStream(AStream: TStream);
    class function LoadFromStream(AStream: TStream): TSkeletonAnimator; static;

    property Skeleton: TSkeleton read FSkeleton;
    property Animations[Index: Integer]: TSkeletonAnimationClip read GetAnimation;
    property AnimationCount: Integer read GetAnimationCount;
    property CurrentAnimation: TSkeletonAnimationClip read GetCurrentAnimation;
    property CurrentAnimationName: string read GetCurrentAnimationName;
    property State: TAnimationPlaybackState read FState;
    property CurrentTime: Single read FCurrentTime write SetCurrentTime;
    property Duration: Single read GetDuration;
    property NormalizedTime: Single read GetNormalizedTime;
    property Looping: Boolean read FLoop write FLoop;
    property Speed: Single read FSpeed write SetSpeed;
    property PoseVersion: UInt64 read FPoseVersion;
    property IsBlending: Boolean read GetIsBlending;
    property OnAnimationFinished: TAnimationFinishedEvent read FOnAnimationFinished
      write FOnAnimationFinished;
  end;

implementation

const
  ANIMATOR_STREAM_VERSION = 1;
  MAX_SERIALIZED_BONES = 65536;
  MAX_SERIALIZED_ANIMATIONS = 16384;
  MAX_SERIALIZED_CHANNELS = 1048576;
  MAX_SERIALIZED_KEYS = 16777216;
  MAX_SERIALIZED_STRING_CHARS = 1048576;

procedure WriteStringToStream(AStream: TStream; const AValue: string);
var
  L: Integer;
begin
  L := Length(AValue);
  AStream.WriteBuffer(L, SizeOf(L));
  if L > 0 then
    AStream.WriteBuffer(AValue[1], L * SizeOf(Char));
end;

function ReadStringFromStream(AStream: TStream): string;
var
  L: Integer;
  ByteCount: Int64;
begin
  AStream.ReadBuffer(L, SizeOf(L));
  if (L < 0) or (L > MAX_SERIALIZED_STRING_CHARS) then
    raise Exception.Create('Invalid string length in animation stream.');
  ByteCount := Int64(L) * SizeOf(Char);
  if ByteCount > AStream.Size - AStream.Position then
    raise Exception.Create('Truncated string in animation stream.');
  SetLength(Result, L);
  if L > 0 then
    AStream.ReadBuffer(Result[1], ByteCount);
end;

procedure ValidateArrayCount(AStream: TStream; ACount, AElementSize,
  AMaximum: Integer; const ADescription: string);
var
  ByteCount: Int64;
begin
  if (ACount < 0) or (ACount > AMaximum) then
    raise Exception.CreateFmt('Invalid %s in animation stream.', [ADescription]);
  ByteCount := Int64(ACount) * AElementSize;
  if ByteCount > AStream.Size - AStream.Position then
    raise Exception.CreateFmt('Truncated %s in animation stream.', [ADescription]);
end;

function QuaternionSlerp(const A, B: TQuaternion; T: Single): TQuaternion;
var
  Q1, Q2: TQuaternion;
  DotValue, Theta, SinTheta, W1, W2: Single;
begin
  Q1 := A.Normalize;
  Q2 := B.Normalize;
  DotValue := Q1.X * Q2.X + Q1.Y * Q2.Y + Q1.Z * Q2.Z + Q1.W * Q2.W;

  if DotValue < 0.0 then
  begin
    DotValue := -DotValue;
    Q2.Init(-Q2.X, -Q2.Y, -Q2.Z, -Q2.W);
  end;

  if DotValue > 0.9995 then
  begin
    Result.Init(
      Q1.X + (Q2.X - Q1.X) * T,
      Q1.Y + (Q2.Y - Q1.Y) * T,
      Q1.Z + (Q2.Z - Q1.Z) * T,
      Q1.W + (Q2.W - Q1.W) * T);
    Result := Result.Normalize;
    Exit;
  end;

  DotValue := EnsureRange(DotValue, -1.0, 1.0);
  Theta := System.Math.ArcCos(DotValue);
  SinTheta := Sin(Theta);
  if Abs(SinTheta) < 1.0e-7 then
    Exit(Q1);

  W1 := Sin((1.0 - T) * Theta) / SinTheta;
  W2 := Sin(T * Theta) / SinTheta;
  Result.Init(
    Q1.X * W1 + Q2.X * W2,
    Q1.Y * W1 + Q2.Y * W2,
    Q1.Z * W1 + Q2.Z * W2,
    Q1.W * W1 + Q2.W * W2);
  Result := Result.Normalize;
end;

function LerpTransform(const A, B: TSkeletonTransform;
  T: Single): TSkeletonTransform;
begin
  Result.Translation := A.Translation + (B.Translation - A.Translation) * T;
  Result.Rotation := QuaternionSlerp(A.Rotation, B.Rotation, T);
  Result.Scale := A.Scale + (B.Scale - A.Scale) * T;
end;

function HermiteVector4(const P0, M0, P1, M1: TVector4;
  T, DeltaTime: Single): TVector4;
var
  T2, T3, H00, H10, H01, H11: Single;
begin
  T2 := T * T;
  T3 := T2 * T;
  H00 := 2.0 * T3 - 3.0 * T2 + 1.0;
  H10 := T3 - 2.0 * T2 + T;
  H01 := -2.0 * T3 + 3.0 * T2;
  H11 := T3 - T2;
  Result.X := H00 * P0.X + H10 * DeltaTime * M0.X +
    H01 * P1.X + H11 * DeltaTime * M1.X;
  Result.Y := H00 * P0.Y + H10 * DeltaTime * M0.Y +
    H01 * P1.Y + H11 * DeltaTime * M1.Y;
  Result.Z := H00 * P0.Z + H10 * DeltaTime * M0.Z +
    H01 * P1.Z + H11 * DeltaTime * M1.Z;
  Result.W := H00 * P0.W + H10 * DeltaTime * M0.W +
    H01 * P1.W + H11 * DeltaTime * M1.W;
end;

{ TVertexSkinWeights }

procedure TVertexSkinWeights.Clear;
var
  I: Integer;
begin
  for I := Low(Influences) to High(Influences) do
  begin
    Influences[I].Joint := -1;
    Influences[I].Weight := 0.0;
  end;
end;

procedure TVertexSkinWeights.Normalize;
var
  I: Integer;
  Total: Single;
begin
  Total := 0.0;
  for I := Low(Influences) to High(Influences) do
  begin
    if (Influences[I].Joint < 0) or (Influences[I].Weight <= 0.0) or
       IsNan(Influences[I].Weight) or IsInfinite(Influences[I].Weight) then
    begin
      Influences[I].Joint := -1;
      Influences[I].Weight := 0.0;
    end;
    Total := Total + Influences[I].Weight;
  end;

  if Total <= 1.0e-8 then
  begin
    Clear;
    Exit;
  end;

  for I := Low(Influences) to High(Influences) do
    Influences[I].Weight := Influences[I].Weight / Total;
end;

{ TSkeletonTransform }

class function TSkeletonTransform.Identity: TSkeletonTransform;
begin
  Result.Translation := Vector3(0.0, 0.0, 0.0);
  Result.Rotation.Init;
  Result.Scale := Vector3(1.0, 1.0, 1.0);
end;

function TSkeletonTransform.ToMatrix: TMatrix4;
var
  TranslationMatrix, ScaleMatrix: TMatrix4;
begin
  TranslationMatrix.InitTranslation(Translation);
  ScaleMatrix.InitScaling(Scale);
  Result := TranslationMatrix * Rotation.Normalize.ToMatrix * ScaleMatrix;
end;

{ TSkeletonBone }

constructor TSkeletonBone.Create(AIndex: Integer; const AData: TSkeletonBoneData);
begin
  inherited Create;
  FIndex := AIndex;
  FName := AData.Name;
  FParentIndex := AData.ParentIndex;
  FBindTransform := AData.BindTransform;
  FLocalTransform := FBindTransform;
  FGlobalMatrix := TMatrix4.Identity;
end;

{ TSkeleton }

constructor TSkeleton.Create(const ABones: TArray<TSkeletonBoneData>);
var
  I: Integer;
begin
  inherited Create;
  FBones := TObjectList<TSkeletonBone>.Create(True);
  for I := 0 to High(ABones) do
    FBones.Add(TSkeletonBone.Create(I, ABones[I]));
  UpdateGlobalMatrices;
end;

destructor TSkeleton.Destroy;
begin
  FBones.Free;
  inherited;
end;

function TSkeleton.GetBone(Index: Integer): TSkeletonBone;
begin
  if (Index >= 0) and (Index < FBones.Count) then
    Result := FBones[Index]
  else
    Result := nil;
end;

function TSkeleton.GetBoneCount: Integer;
begin
  Result := FBones.Count;
end;

function TSkeleton.Clone: TSkeleton;
var
  Data: TArray<TSkeletonBoneData>;
  Pose: TArray<TSkeletonTransform>;
  I: Integer;
begin
  SetLength(Data, BoneCount);
  for I := 0 to BoneCount - 1 do
  begin
    Data[I].Name := Bones[I].Name;
    Data[I].ParentIndex := Bones[I].ParentIndex;
    Data[I].BindTransform := Bones[I].BindTransform;
  end;
  Result := TSkeleton.Create(Data);
  GetCurrentPose(Pose);
  Result.SetPose(Pose);
end;

function TSkeleton.BoneByName(const AName: string): TSkeletonBone;
var
  I: Integer;
begin
  for I := 0 to BoneCount - 1 do
    if SameText(Bones[I].Name, AName) then
      Exit(Bones[I]);
  Result := nil;
end;

procedure TSkeleton.GetBindPose(out APose: TArray<TSkeletonTransform>);
var
  I: Integer;
begin
  SetLength(APose, BoneCount);
  for I := 0 to BoneCount - 1 do
    APose[I] := Bones[I].BindTransform;
end;

procedure TSkeleton.GetCurrentPose(out APose: TArray<TSkeletonTransform>);
var
  I: Integer;
begin
  SetLength(APose, BoneCount);
  for I := 0 to BoneCount - 1 do
    APose[I] := Bones[I].LocalTransform;
end;

procedure TSkeleton.SetPose(const APose: TArray<TSkeletonTransform>);
var
  I: Integer;
begin
  if Length(APose) <> BoneCount then
    raise Exception.CreateFmt('Skeleton pose has %d transforms; expected %d.',
      [Length(APose), BoneCount]);
  for I := 0 to BoneCount - 1 do
    Bones[I].FLocalTransform := APose[I];
  UpdateGlobalMatrices;
end;

procedure TSkeleton.ResetPose;
var
  I: Integer;
begin
  for I := 0 to BoneCount - 1 do
    Bones[I].FLocalTransform := Bones[I].BindTransform;
  UpdateGlobalMatrices;
end;

procedure TSkeleton.UpdateGlobalMatrices;
var
  States: TArray<Byte>;

  procedure UpdateBone(ABoneIndex: Integer);
  var
    Bone, ParentBone: TSkeletonBone;
  begin
    if States[ABoneIndex] = 2 then
      Exit;
    if States[ABoneIndex] = 1 then
      raise Exception.CreateFmt('Cycle detected at skeleton bone %d.', [ABoneIndex]);

    States[ABoneIndex] := 1;
    Bone := Bones[ABoneIndex];
    if Bone.ParentIndex >= 0 then
    begin
      if Bone.ParentIndex >= BoneCount then
        raise Exception.CreateFmt('Skeleton bone %d has invalid parent %d.',
          [ABoneIndex, Bone.ParentIndex]);
      UpdateBone(Bone.ParentIndex);
      ParentBone := Bones[Bone.ParentIndex];
      Bone.FGlobalMatrix := ParentBone.GlobalMatrix * Bone.LocalTransform.ToMatrix;
    end
    else
      Bone.FGlobalMatrix := Bone.LocalTransform.ToMatrix;
    States[ABoneIndex] := 2;
  end;

var
  I: Integer;
begin
  SetLength(States, BoneCount);
  for I := 0 to BoneCount - 1 do
    UpdateBone(I);
end;

{ TSkeletonAnimationChannel }

constructor TSkeletonAnimationChannel.Create(ABoneIndex: Integer;
  ATarget: TAnimationChannelTarget; AInterpolation: TAnimationInterpolation;
  const ATimes: TArray<Single>; const AValues, AInTangents,
  AOutTangents: TArray<TVector4>);
var
  I: Integer;
begin
  inherited Create;
  if Length(ATimes) <> Length(AValues) then
    raise Exception.Create('Animation channel time/value counts do not match.');
  if (AInterpolation = aiCubicSpline) and
     ((Length(AInTangents) <> Length(ATimes)) or
      (Length(AOutTangents) <> Length(ATimes))) then
    raise Exception.Create('Cubic animation channel tangent counts do not match.');

  for I := 1 to High(ATimes) do
    if ATimes[I] < ATimes[I - 1] then
      raise Exception.Create('Animation channel key times are not sorted.');

  FBoneIndex := ABoneIndex;
  FTarget := ATarget;
  FInterpolation := AInterpolation;
  FTimes := Copy(ATimes);
  FValues := Copy(AValues);
  FInTangents := Copy(AInTangents);
  FOutTangents := Copy(AOutTangents);
end;

function TSkeletonAnimationChannel.FindKeyInterval(ATime: Single): Integer;
var
  LowIndex, HighIndex, Mid: Integer;
begin
  if Length(FTimes) < 2 then
    Exit(0);
  if ATime <= FTimes[0] then
    Exit(0);
  if ATime >= FTimes[High(FTimes)] then
    Exit(High(FTimes) - 1);

  LowIndex := 0;
  HighIndex := High(FTimes) - 1;
  while LowIndex <= HighIndex do
  begin
    Mid := (LowIndex + HighIndex) div 2;
    if (ATime >= FTimes[Mid]) and (ATime < FTimes[Mid + 1]) then
      Exit(Mid);
    if ATime < FTimes[Mid] then
      HighIndex := Mid - 1
    else
      LowIndex := Mid + 1;
  end;
  Result := EnsureRange(LowIndex, 0, High(FTimes) - 1);
end;

function TSkeletonAnimationChannel.SampleValue(ATime: Single): TVector4;
var
  KeyIndex: Integer;
  KeyDelta, T: Single;
  Q0, Q1, Q: TQuaternion;
begin
  Result := TVector4.Zero;
  if Length(FValues) = 0 then
    Exit;
  if Length(FValues) = 1 then
    Exit(FValues[0]);
  if ATime <= FTimes[0] then
    Exit(FValues[0]);
  if ATime >= FTimes[High(FTimes)] then
    Exit(FValues[High(FValues)]);

  KeyIndex := FindKeyInterval(ATime);
  KeyDelta := FTimes[KeyIndex + 1] - FTimes[KeyIndex];
  if KeyDelta <= 1.0e-8 then
    Exit(FValues[KeyIndex]);
  T := EnsureRange((ATime - FTimes[KeyIndex]) / KeyDelta, 0.0, 1.0);

  case FInterpolation of
    aiStep:
      Result := FValues[KeyIndex];
    aiCubicSpline:
      Result := HermiteVector4(FValues[KeyIndex], FOutTangents[KeyIndex],
        FValues[KeyIndex + 1], FInTangents[KeyIndex + 1], T, KeyDelta);
  else
    if FTarget = actRotation then
    begin
      Q0.Init(FValues[KeyIndex].X, FValues[KeyIndex].Y,
        FValues[KeyIndex].Z, FValues[KeyIndex].W);
      Q1.Init(FValues[KeyIndex + 1].X, FValues[KeyIndex + 1].Y,
        FValues[KeyIndex + 1].Z, FValues[KeyIndex + 1].W);
      Q := QuaternionSlerp(Q0, Q1, T);
      Result := Vector4(Q.X, Q.Y, Q.Z, Q.W);
    end
    else
      Result := FValues[KeyIndex] +
        (FValues[KeyIndex + 1] - FValues[KeyIndex]) * T;
  end;

  if (FTarget = actRotation) and (FInterpolation = aiCubicSpline) then
  begin
    Q.Init(Result.X, Result.Y, Result.Z, Result.W);
    Q := Q.Normalize;
    Result := Vector4(Q.X, Q.Y, Q.Z, Q.W);
  end;
end;

procedure TSkeletonAnimationChannel.Apply(ATime: Single;
  var ATransform: TSkeletonTransform);
var
  Value: TVector4;
  Q: TQuaternion;
begin
  if Length(FValues) = 0 then
    Exit;
  Value := SampleValue(ATime);
  case FTarget of
    actTranslation:
      ATransform.Translation := Vector3(Value.X, Value.Y, Value.Z);
    actRotation:
      begin
        Q.Init(Value.X, Value.Y, Value.Z, Value.W);
        ATransform.Rotation := Q.Normalize;
      end;
    actScale:
      ATransform.Scale := Vector3(Value.X, Value.Y, Value.Z);
  end;
end;

{ TSkeletonAnimationClip }

constructor TSkeletonAnimationClip.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
  FDuration := 0.0;
  FChannels := TObjectList<TSkeletonAnimationChannel>.Create(True);
end;

destructor TSkeletonAnimationClip.Destroy;
begin
  FChannels.Free;
  inherited;
end;

function TSkeletonAnimationClip.GetChannel(Index: Integer): TSkeletonAnimationChannel;
begin
  if (Index >= 0) and (Index < FChannels.Count) then
    Result := FChannels[Index]
  else
    Result := nil;
end;

function TSkeletonAnimationClip.GetChannelCount: Integer;
begin
  Result := FChannels.Count;
end;

function TSkeletonAnimationClip.AddChannel(
  AChannel: TSkeletonAnimationChannel): Integer;
begin
  if AChannel = nil then
    raise Exception.Create('Cannot add a nil animation channel.');
  if Length(AChannel.Times) > 0 then
    FDuration := System.Math.Max(FDuration,
      AChannel.Times[High(AChannel.Times)]);
  Result := FChannels.Add(AChannel);
end;

procedure TSkeletonAnimationClip.Evaluate(ATime: Single; ASkeleton: TSkeleton;
  out APose: TArray<TSkeletonTransform>);
var
  I, BoneIndex: Integer;
  Transform: TSkeletonTransform;
begin
  if ASkeleton = nil then
  begin
    APose := nil;
    Exit;
  end;

  ASkeleton.GetBindPose(APose);
  for I := 0 to ChannelCount - 1 do
  begin
    BoneIndex := Channels[I].BoneIndex;
    if (BoneIndex < 0) or (BoneIndex >= Length(APose)) then
      Continue;
    Transform := APose[BoneIndex];
    Channels[I].Apply(ATime, Transform);
    APose[BoneIndex] := Transform;
  end;
end;

{ TSkeletonAnimator }

constructor TSkeletonAnimator.Create(ASkeleton: TSkeleton);
begin
  inherited Create;
  if ASkeleton = nil then
    raise Exception.Create('A skeleton animator requires a skeleton.');
  FSkeleton := ASkeleton;
  FAnimations := TObjectList<TSkeletonAnimationClip>.Create(True);
  FState := apsStopped;
  FCurrentAnimationIndex := -1;
  FPreviousAnimationIndex := -1;
  FCurrentTime := 0.0;
  FPreviousTime := 0.0;
  FBlendDuration := 0.0;
  FBlendElapsed := 0.0;
  FLoop := True;
  FSpeed := 1.0;
  FPoseVersion := 1;
end;

destructor TSkeletonAnimator.Destroy;
begin
  FAnimations.Free;
  FSkeleton.Free;
  inherited;
end;

function TSkeletonAnimator.GetAnimation(Index: Integer): TSkeletonAnimationClip;
begin
  if (Index >= 0) and (Index < FAnimations.Count) then
    Result := FAnimations[Index]
  else
    Result := nil;
end;

function TSkeletonAnimator.GetAnimationCount: Integer;
begin
  Result := FAnimations.Count;
end;

function TSkeletonAnimator.GetCurrentAnimation: TSkeletonAnimationClip;
begin
  Result := GetAnimation(FCurrentAnimationIndex);
end;

function TSkeletonAnimator.GetCurrentAnimationName: string;
begin
  if CurrentAnimation <> nil then
    Result := CurrentAnimation.Name
  else
    Result := '';
end;

function TSkeletonAnimator.GetDuration: Single;
begin
  if CurrentAnimation <> nil then
    Result := CurrentAnimation.Duration
  else
    Result := 0.0;
end;

function TSkeletonAnimator.GetNormalizedTime: Single;
begin
  if Duration > 1.0e-8 then
    Result := EnsureRange(FCurrentTime / Duration, 0.0, 1.0)
  else
    Result := 0.0;
end;

function TSkeletonAnimator.GetIsBlending: Boolean;
begin
  Result := (FPreviousAnimationIndex >= 0) and (FBlendDuration > 0.0);
end;

procedure TSkeletonAnimator.SetCurrentTime(const Value: Single);
begin
  Seek(Value);
end;

procedure TSkeletonAnimator.SetSpeed(const Value: Single);
begin
  if IsNan(Value) or IsInfinite(Value) then
    Exit;
  FSpeed := Value;
end;

function TSkeletonAnimator.Clone: TSkeletonAnimator;
var
  Stream: TMemoryStream;
begin
  Stream := TMemoryStream.Create;
  try
    SaveToStream(Stream);
    Stream.Position := 0;
    Result := LoadFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

function TSkeletonAnimator.AddAnimation(
  AAnimation: TSkeletonAnimationClip): Integer;
begin
  if AAnimation = nil then
    raise Exception.Create('Cannot add a nil animation.');
  Result := FAnimations.Add(AAnimation);
end;

function TSkeletonAnimator.AnimationByName(
  const AName: string): TSkeletonAnimationClip;
var
  Index: Integer;
begin
  Index := AnimationIndexByName(AName);
  Result := GetAnimation(Index);
end;

function TSkeletonAnimator.AnimationIndexByName(const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to AnimationCount - 1 do
    if SameText(Animations[I].Name, AName) then
      Exit(I);
  Result := -1;
end;

function TSkeletonAnimator.Play(const AAnimationName: string; ALoop: Boolean;
  ABlendDuration: Single): Boolean;
begin
  Result := Play(AnimationIndexByName(AAnimationName), ALoop, ABlendDuration);
end;

function TSkeletonAnimator.Play(AAnimationIndex: Integer; ALoop: Boolean;
  ABlendDuration: Single): Boolean;
var
  NewAnimation: TSkeletonAnimationClip;
begin
  NewAnimation := GetAnimation(AAnimationIndex);
  if NewAnimation = nil then
    Exit(False);

  ABlendDuration := System.Math.Max(0.0, ABlendDuration);
  if (ABlendDuration > 0.0) and (CurrentAnimation <> nil) then
  begin
    FPreviousAnimationIndex := FCurrentAnimationIndex;
    FPreviousTime := FCurrentTime;
    FBlendDuration := ABlendDuration;
    FBlendElapsed := 0.0;
  end
  else
  begin
    FPreviousAnimationIndex := -1;
    FPreviousTime := 0.0;
    FBlendDuration := 0.0;
    FBlendElapsed := 0.0;
  end;

  FCurrentAnimationIndex := AAnimationIndex;
  FLoop := ALoop;
  if FSpeed < 0.0 then
    FCurrentTime := NewAnimation.Duration
  else
    FCurrentTime := 0.0;
  FState := apsPlaying;
  EvaluateCurrentPose;
  Result := True;
end;

function TSkeletonAnimator.BlendTo(const AAnimationName: string;
  ABlendDuration: Single; ALoop: Boolean): Boolean;
begin
  Result := Play(AAnimationName, ALoop,
    System.Math.Max(0.0, ABlendDuration));
end;

procedure TSkeletonAnimator.Pause;
begin
  if FState = apsPlaying then
    FState := apsPaused;
end;

procedure TSkeletonAnimator.Resume;
begin
  if (FState = apsPaused) and (CurrentAnimation <> nil) then
    FState := apsPlaying;
end;

procedure TSkeletonAnimator.Stop(AResetToBindPose: Boolean);
begin
  FState := apsStopped;
  FPreviousAnimationIndex := -1;
  FPreviousTime := 0.0;
  FBlendDuration := 0.0;
  FBlendElapsed := 0.0;
  if AResetToBindPose then
  begin
    FCurrentTime := 0.0;
    FSkeleton.ResetPose;
    Inc(FPoseVersion);
  end;
end;

procedure TSkeletonAnimator.Seek(ATime: Single);
var
  Clip: TSkeletonAnimationClip;
begin
  Clip := CurrentAnimation;
  if Clip = nil then
    Exit;

  if Clip.Duration <= 1.0e-8 then
    FCurrentTime := 0.0
  else if FLoop then
  begin
    FCurrentTime := ATime - System.Math.Floor(ATime / Clip.Duration) *
      Clip.Duration;
    if FCurrentTime < 0.0 then
      FCurrentTime := FCurrentTime + Clip.Duration;
  end
  else
    FCurrentTime := EnsureRange(ATime, 0.0, Clip.Duration);
  EvaluateCurrentPose;
end;

function TSkeletonAnimator.AdvanceClipTime(AClip: TSkeletonAnimationClip;
  var ATime: Single; ADelta: Single; ALoop: Boolean): Boolean;
begin
  Result := False;
  if (AClip = nil) or (AClip.Duration <= 1.0e-8) then
  begin
    ATime := 0.0;
    Exit(not ALoop);
  end;

  ATime := ATime + ADelta;
  if ALoop then
  begin
    ATime := ATime - System.Math.Floor(ATime / AClip.Duration) *
      AClip.Duration;
    if ATime < 0.0 then
      ATime := ATime + AClip.Duration;
  end
  else if ATime >= AClip.Duration then
  begin
    ATime := AClip.Duration;
    Result := ADelta >= 0.0;
  end
  else if ATime <= 0.0 then
  begin
    ATime := 0.0;
    Result := ADelta < 0.0;
  end;
end;

procedure TSkeletonAnimator.EvaluateCurrentPose;
var
  CurrentPose, PreviousPose, FinalPose: TArray<TSkeletonTransform>;
  CurrentClip, PreviousClip: TSkeletonAnimationClip;
  Alpha: Single;
  I: Integer;
begin
  CurrentClip := CurrentAnimation;
  if CurrentClip = nil then
  begin
    FSkeleton.ResetPose;
    Inc(FPoseVersion);
    Exit;
  end;

  CurrentClip.Evaluate(FCurrentTime, FSkeleton, CurrentPose);
  PreviousClip := GetAnimation(FPreviousAnimationIndex);
  if (PreviousClip <> nil) and (FBlendDuration > 1.0e-8) then
  begin
    PreviousClip.Evaluate(FPreviousTime, FSkeleton, PreviousPose);
    Alpha := EnsureRange(FBlendElapsed / FBlendDuration, 0.0, 1.0);
    SetLength(FinalPose, Length(CurrentPose));
    for I := 0 to High(FinalPose) do
      FinalPose[I] := LerpTransform(PreviousPose[I], CurrentPose[I], Alpha);
    FSkeleton.SetPose(FinalPose);
  end
  else
    FSkeleton.SetPose(CurrentPose);
  Inc(FPoseVersion);
end;

procedure TSkeletonAnimator.Update(ADeltaTime: Single);
var
  Finished: Boolean;
  FinishedName: string;
  Delta: Single;
begin
  if (FState <> apsPlaying) or (CurrentAnimation = nil) then
    Exit;
  if IsNan(ADeltaTime) or IsInfinite(ADeltaTime) then
    Exit;

  Delta := ADeltaTime * FSpeed;
  Finished := AdvanceClipTime(CurrentAnimation, FCurrentTime, Delta, FLoop);

  if FPreviousAnimationIndex >= 0 then
  begin
    AdvanceClipTime(GetAnimation(FPreviousAnimationIndex), FPreviousTime,
      Delta, True);
    FBlendElapsed := FBlendElapsed + Abs(ADeltaTime);
    if FBlendElapsed >= FBlendDuration then
    begin
      FPreviousAnimationIndex := -1;
      FPreviousTime := 0.0;
      FBlendDuration := 0.0;
      FBlendElapsed := 0.0;
    end;
  end;

  EvaluateCurrentPose;
  if Finished then
  begin
    FinishedName := CurrentAnimationName;
    FState := apsStopped;
    if Assigned(FOnAnimationFinished) then
      FOnAnimationFinished(Self, FinishedName);
  end;
end;

procedure TSkeletonAnimator.SetProceduralPose(
  const APose: TArray<TSkeletonTransform>);
begin
  if FSkeleton = nil then
    Exit;

  FSkeleton.SetPose(APose);
  Inc(FPoseVersion);
end;

procedure TSkeletonAnimator.SaveToStream(AStream: TStream);
var
  Version, BoneCountValue, AnimationCountValue, ChannelCountValue: Integer;
  KeyCount, I, J: Integer;
  Bone: TSkeletonBone;
  Clip: TSkeletonAnimationClip;
  Channel: TSkeletonAnimationChannel;
  TargetValue, InterpolationValue, StateValue: Integer;
begin
  Version := ANIMATOR_STREAM_VERSION;
  AStream.WriteBuffer(Version, SizeOf(Version));

  BoneCountValue := FSkeleton.BoneCount;
  AStream.WriteBuffer(BoneCountValue, SizeOf(BoneCountValue));
  for I := 0 to BoneCountValue - 1 do
  begin
    Bone := FSkeleton.Bones[I];
    WriteStringToStream(AStream, Bone.Name);
    AStream.WriteBuffer(Bone.FParentIndex, SizeOf(Bone.FParentIndex));
    AStream.WriteBuffer(Bone.FBindTransform, SizeOf(Bone.FBindTransform));
  end;

  AnimationCountValue := AnimationCount;
  AStream.WriteBuffer(AnimationCountValue, SizeOf(AnimationCountValue));
  for I := 0 to AnimationCountValue - 1 do
  begin
    Clip := Animations[I];
    WriteStringToStream(AStream, Clip.Name);
    AStream.WriteBuffer(Clip.FDuration, SizeOf(Clip.FDuration));
    ChannelCountValue := Clip.ChannelCount;
    AStream.WriteBuffer(ChannelCountValue, SizeOf(ChannelCountValue));
    for J := 0 to ChannelCountValue - 1 do
    begin
      Channel := Clip.Channels[J];
      AStream.WriteBuffer(Channel.FBoneIndex, SizeOf(Channel.FBoneIndex));
      TargetValue := Ord(Channel.Target);
      InterpolationValue := Ord(Channel.Interpolation);
      AStream.WriteBuffer(TargetValue, SizeOf(TargetValue));
      AStream.WriteBuffer(InterpolationValue, SizeOf(InterpolationValue));
      KeyCount := Length(Channel.FTimes);
      AStream.WriteBuffer(KeyCount, SizeOf(KeyCount));
      if KeyCount > 0 then
      begin
        AStream.WriteBuffer(Channel.FTimes[0], KeyCount * SizeOf(Single));
        AStream.WriteBuffer(Channel.FValues[0], KeyCount * SizeOf(TVector4));
        if Channel.Interpolation = aiCubicSpline then
        begin
          AStream.WriteBuffer(Channel.FInTangents[0], KeyCount * SizeOf(TVector4));
          AStream.WriteBuffer(Channel.FOutTangents[0], KeyCount * SizeOf(TVector4));
        end;
      end;
    end;
  end;

  StateValue := Ord(FState);
  AStream.WriteBuffer(StateValue, SizeOf(StateValue));
  AStream.WriteBuffer(FCurrentAnimationIndex, SizeOf(FCurrentAnimationIndex));
  AStream.WriteBuffer(FCurrentTime, SizeOf(FCurrentTime));
  AStream.WriteBuffer(FPreviousAnimationIndex, SizeOf(FPreviousAnimationIndex));
  AStream.WriteBuffer(FPreviousTime, SizeOf(FPreviousTime));
  AStream.WriteBuffer(FBlendDuration, SizeOf(FBlendDuration));
  AStream.WriteBuffer(FBlendElapsed, SizeOf(FBlendElapsed));
  AStream.WriteBuffer(FLoop, SizeOf(FLoop));
  AStream.WriteBuffer(FSpeed, SizeOf(FSpeed));
end;

class function TSkeletonAnimator.LoadFromStream(
  AStream: TStream): TSkeletonAnimator;
var
  Version, BoneCountValue, AnimationCountValue, ChannelCountValue: Integer;
  KeyCount, I, J: Integer;
  BoneData: TArray<TSkeletonBoneData>;
  Clip: TSkeletonAnimationClip;
  Channel: TSkeletonAnimationChannel;
  Times: TArray<Single>;
  Values, InTangents, OutTangents: TArray<TVector4>;
  BoneIndex, TargetValue, InterpolationValue, StateValue: Integer;
  SavedDuration: Single;
begin
  Result := nil;
  AStream.ReadBuffer(Version, SizeOf(Version));
  if Version <> ANIMATOR_STREAM_VERSION then
    raise Exception.CreateFmt('Unsupported animator stream version %d.', [Version]);

  AStream.ReadBuffer(BoneCountValue, SizeOf(BoneCountValue));
  if (BoneCountValue < 0) or (BoneCountValue > MAX_SERIALIZED_BONES) then
    raise Exception.Create('Invalid bone count in animation stream.');
  SetLength(BoneData, BoneCountValue);
  for I := 0 to BoneCountValue - 1 do
  begin
    BoneData[I].Name := ReadStringFromStream(AStream);
    AStream.ReadBuffer(BoneData[I].ParentIndex, SizeOf(Integer));
    AStream.ReadBuffer(BoneData[I].BindTransform,
      SizeOf(TSkeletonTransform));
  end;

  Result := TSkeletonAnimator.Create(TSkeleton.Create(BoneData));
  try
    AStream.ReadBuffer(AnimationCountValue, SizeOf(AnimationCountValue));
    if (AnimationCountValue < 0) or
       (AnimationCountValue > MAX_SERIALIZED_ANIMATIONS) then
      raise Exception.Create('Invalid animation count in animation stream.');

    for I := 0 to AnimationCountValue - 1 do
    begin
      Clip := TSkeletonAnimationClip.Create(ReadStringFromStream(AStream));
      try
        AStream.ReadBuffer(SavedDuration, SizeOf(SavedDuration));
        AStream.ReadBuffer(ChannelCountValue, SizeOf(ChannelCountValue));
        if (ChannelCountValue < 0) or
           (ChannelCountValue > MAX_SERIALIZED_CHANNELS) then
          raise Exception.Create('Invalid channel count in animation stream.');

        for J := 0 to ChannelCountValue - 1 do
        begin
          AStream.ReadBuffer(BoneIndex, SizeOf(BoneIndex));
          AStream.ReadBuffer(TargetValue, SizeOf(TargetValue));
          AStream.ReadBuffer(InterpolationValue, SizeOf(InterpolationValue));
          if (TargetValue < Ord(Low(TAnimationChannelTarget))) or
             (TargetValue > Ord(High(TAnimationChannelTarget))) or
             (InterpolationValue < Ord(Low(TAnimationInterpolation))) or
             (InterpolationValue > Ord(High(TAnimationInterpolation))) then
            raise Exception.Create('Invalid animation channel type in stream.');

          AStream.ReadBuffer(KeyCount, SizeOf(KeyCount));
          ValidateArrayCount(AStream, KeyCount, SizeOf(Single),
            MAX_SERIALIZED_KEYS, 'animation key count');
          SetLength(Times, KeyCount);
          if KeyCount > 0 then
            AStream.ReadBuffer(Times[0], KeyCount * SizeOf(Single));

          ValidateArrayCount(AStream, KeyCount, SizeOf(TVector4),
            MAX_SERIALIZED_KEYS, 'animation value count');
          SetLength(Values, KeyCount);
          if KeyCount > 0 then
            AStream.ReadBuffer(Values[0], KeyCount * SizeOf(TVector4));

          InTangents := nil;
          OutTangents := nil;
          if TAnimationInterpolation(InterpolationValue) = aiCubicSpline then
          begin
            ValidateArrayCount(AStream, KeyCount, SizeOf(TVector4),
              MAX_SERIALIZED_KEYS, 'animation in-tangent count');
            SetLength(InTangents, KeyCount);
            if KeyCount > 0 then
              AStream.ReadBuffer(InTangents[0], KeyCount * SizeOf(TVector4));
            ValidateArrayCount(AStream, KeyCount, SizeOf(TVector4),
              MAX_SERIALIZED_KEYS, 'animation out-tangent count');
            SetLength(OutTangents, KeyCount);
            if KeyCount > 0 then
              AStream.ReadBuffer(OutTangents[0], KeyCount * SizeOf(TVector4));
          end;

          Channel := TSkeletonAnimationChannel.Create(BoneIndex,
            TAnimationChannelTarget(TargetValue),
            TAnimationInterpolation(InterpolationValue), Times, Values,
            InTangents, OutTangents);
          Clip.AddChannel(Channel);
        end;
        Clip.FDuration := System.Math.Max(Clip.FDuration, SavedDuration);
        Result.AddAnimation(Clip);
        Clip := nil;
      finally
        Clip.Free;
      end;
    end;

    AStream.ReadBuffer(StateValue, SizeOf(StateValue));
    if (StateValue < Ord(Low(TAnimationPlaybackState))) or
       (StateValue > Ord(High(TAnimationPlaybackState))) then
      raise Exception.Create('Invalid playback state in animation stream.');
    Result.FState := TAnimationPlaybackState(StateValue);
    AStream.ReadBuffer(Result.FCurrentAnimationIndex,
      SizeOf(Result.FCurrentAnimationIndex));
    AStream.ReadBuffer(Result.FCurrentTime, SizeOf(Result.FCurrentTime));
    AStream.ReadBuffer(Result.FPreviousAnimationIndex,
      SizeOf(Result.FPreviousAnimationIndex));
    AStream.ReadBuffer(Result.FPreviousTime, SizeOf(Result.FPreviousTime));
    AStream.ReadBuffer(Result.FBlendDuration, SizeOf(Result.FBlendDuration));
    AStream.ReadBuffer(Result.FBlendElapsed, SizeOf(Result.FBlendElapsed));
    AStream.ReadBuffer(Result.FLoop, SizeOf(Result.FLoop));
    AStream.ReadBuffer(Result.FSpeed, SizeOf(Result.FSpeed));

    if Result.GetAnimation(Result.FCurrentAnimationIndex) = nil then
    begin
      Result.FCurrentAnimationIndex := -1;
      Result.FState := apsStopped;
    end;
    if Result.GetAnimation(Result.FPreviousAnimationIndex) = nil then
      Result.FPreviousAnimationIndex := -1;
    Result.EvaluateCurrentPose;
  except
    Result.Free;
    raise;
  end;
end;

end.
