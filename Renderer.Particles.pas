unit Renderer.Particles;

interface

uses
  System.SysUtils, System.Classes, System.Math, System.Generics.Collections,
  System.IOUtils, System.Types, Vcl.Graphics, Vcl.Imaging.pngimage, GraphicEx,
  dglOpenGL,
  Neslib.FastMath, Renderer.Shader, Engine.Paths, Engine.Types;

type
  TParticleBlendMode = (pbAlpha, pbAdditive);
  TParticleTextureKind = (ptNone, ptSoftCircle, ptPerlin, ptFile);
  TParticleSimulationSpace = (psObject, psWorld);

  TParticle = class
  private
    FID: Integer;
    FTag: Integer;
    FPosition: TVector3;
    FVelocity: TVector3;
    FAge: Single;
    FLifeTime: Single;
    FSizeScale: Single;
    FRotation: Single;
    FAngularVelocity: Single;
    FColor: TVector4;
  public
    constructor Create;
    procedure Reset;

    property ID: Integer read FID;
    property Tag: Integer read FTag write FTag;
    property Position: TVector3 read FPosition write FPosition;
    property Velocity: TVector3 read FVelocity write FVelocity;
    property Age: Single read FAge write FAge;
    property LifeTime: Single read FLifeTime write FLifeTime;
    property SizeScale: Single read FSizeScale write FSizeScale;
    property Rotation: Single read FRotation write FRotation;
    property AngularVelocity: Single read FAngularVelocity write FAngularVelocity;
    property Color: TVector4 read FColor write FColor;
  end;

  TParticleEvent = procedure(Sender: TObject; Particle: TParticle) of object;
  TParticleProgressEvent = procedure(Sender: TObject; Particle: TParticle;
    DeltaTime: Single; var KillParticle: Boolean) of object;

  TParticleSystem = class
  private type
    TParticleVertex = packed record
      Position: TVector3;
      Color: TVector4;
      TexCoord: TVector2;
    end;

    TParticleRenderRef = record
      Particle: TParticle;
      DistanceSq: Single;
    end;

    TParticleRenderRefs = TArray<TParticleRenderRef>;
  private
    FName: string;
    FParticles: TObjectList<TParticle>;
    FParticlePool: TObjectList<TParticle>;
    FParticlePoolSize: Integer;
    FNextID: Integer;
    FEmissionAccumulator: Double;

    FEnabled: Boolean;
    FAutoEmit: Boolean;
    FMaxParticles: Integer;
    FEmissionRate: Single;
    FParticleLife: Single;
    FParticleLifeRandom: Single;
    FInitialPosition: TVector3;
    FInitialVelocity: TVector3;
    FPositionDispersion: Single;
    FPositionDispersionRange: TVector3;
    FVelocityDispersion: Single;
    FAcceleration: TVector3;
    FFriction: Single;
    FStartColor: TVector4;
    FEndColor: TVector4;
    FStartSize: Single;
    FEndSize: Single;
    FSizeRandom: Single;
    FAspectRatio: Single;
    FRotationDispersion: Single;
    FAngularVelocityDispersion: Single;
    FSimulationSpace: TParticleSimulationSpace;
    FBlendMode: TParticleBlendMode;
    FTextureKind: TParticleTextureKind;
    FTexturePath: string;

    FTexMapSize: Integer;
    FNoiseSeed: Integer;
    FNoiseScale: Integer;
    FNoiseAmplitude: Integer;
    FSmoothness: Single;
    FBrightness: Single;
    FGamma: Single;

    FVAO: GLuint;
    FVBO: GLuint;
    FTextureID: GLuint;
    FTextureDirty: Boolean;
    FShader: TShader;

    FOnCreateParticle: TParticleEvent;
    FOnActivateParticle: TParticleEvent;
    FOnKillParticle: TParticleEvent;
    FOnDestroyParticle: TParticleEvent;
    FOnParticleProgress: TParticleProgressEvent;

    function GetParticleCount: Integer;
    procedure SetMaxParticles(const Value: Integer);
    procedure SetParticlePoolSize(const Value: Integer);
    procedure SetParticleLife(const Value: Single);
    procedure SetParticleLifeRandom(const Value: Single);
    procedure SetEmissionRate(const Value: Single);
    procedure SetFriction(const Value: Single);
    procedure SetStartSize(const Value: Single);
    procedure SetEndSize(const Value: Single);
    procedure SetSizeRandom(const Value: Single);
    procedure SetAspectRatio(const Value: Single);
    procedure SetSimulationSpace(const Value: TParticleSimulationSpace);
    procedure SetTextureKind(const Value: TParticleTextureKind);
    procedure SetTexturePath(const Value: string);
    procedure SetTexMapSize(const Value: Integer);
    procedure SetNoiseSeed(const Value: Integer);
    procedure SetNoiseScale(const Value: Integer);
    procedure SetNoiseAmplitude(const Value: Integer);
    procedure SetSmoothness(const Value: Single);
    procedure SetBrightness(const Value: Single);
    procedure SetGamma(const Value: Single);

    procedure EnsureBuffers;
    procedure EnsureShader;
    procedure EnsureTexture;
    procedure DestroyBuffers;
    procedure DestroyTexture;
    procedure DestroyShader;
    procedure MarkTextureDirty;

    procedure KillParticle(AParticle: TParticle);
    function EvaluateColor(AParticle: TParticle): TVector4;
    function EvaluateSize(AParticle: TParticle): Single;
    function RandomSigned: Single;
    function RandomUnitVector: TVector3;
    function NewParticlePosition: TVector3;
    function NewParticleVelocity: TVector3;
    function SimulationPosition(const LocalPosition: TVector3;
      const OwnerWorldMatrix: TMatrix4): TVector3;
    function SimulationVelocity(const LocalVelocity: TVector3;
      const OwnerWorldMatrix: TMatrix4): TVector3;
    function RenderPosition(AParticle: TParticle;
      const OwnerWorldMatrix: TMatrix4): TVector3;
    procedure SortRenderRefs(var Refs: TParticleRenderRefs);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Assign(Source: TParticleSystem);
    function Clone: TParticleSystem;

    function CreateParticle: TParticle; overload;
    function CreateParticle(const OwnerWorldMatrix: TMatrix4): TParticle; overload;
    procedure Burst(Count: Integer); overload;
    procedure Burst(Count: Integer; const OwnerWorldMatrix: TMatrix4); overload;
    procedure Clear;
    procedure Update(DeltaTime: Single; NewTime: Double); overload;
    procedure Update(DeltaTime: Single; NewTime: Double;
      const OwnerWorldMatrix: TMatrix4); overload;
    procedure Render(const ViewProjection: TMatrix4; const OwnerWorldMatrix: TMatrix4;
      const CameraPosition, CameraRight, CameraUp: TVector3);

    procedure SaveToStream(Stream: TStream);
    procedure LoadFromStream(Stream: TStream);

    property Particles: TObjectList<TParticle> read FParticles;
    property ParticleCount: Integer read GetParticleCount;

    property Name: string read FName write FName;
    property Enabled: Boolean read FEnabled write FEnabled;
    property AutoEmit: Boolean read FAutoEmit write FAutoEmit;
    property MaxParticles: Integer read FMaxParticles write SetMaxParticles;
    property ParticlePoolSize: Integer read FParticlePoolSize write SetParticlePoolSize;
    property EmissionRate: Single read FEmissionRate write SetEmissionRate;
    property ParticleLife: Single read FParticleLife write SetParticleLife;
    property ParticleLifeRandom: Single read FParticleLifeRandom write SetParticleLifeRandom;
    property InitialPosition: TVector3 read FInitialPosition write FInitialPosition;
    property InitialVelocity: TVector3 read FInitialVelocity write FInitialVelocity;
    property PositionDispersion: Single read FPositionDispersion write FPositionDispersion;
    property PositionDispersionRange: TVector3 read FPositionDispersionRange write FPositionDispersionRange;
    property VelocityDispersion: Single read FVelocityDispersion write FVelocityDispersion;
    property Acceleration: TVector3 read FAcceleration write FAcceleration;
    property Friction: Single read FFriction write SetFriction;
    property StartColor: TVector4 read FStartColor write FStartColor;
    property EndColor: TVector4 read FEndColor write FEndColor;
    property StartSize: Single read FStartSize write SetStartSize;
    property EndSize: Single read FEndSize write SetEndSize;
    property SizeRandom: Single read FSizeRandom write SetSizeRandom;
    property AspectRatio: Single read FAspectRatio write SetAspectRatio;
    property RotationDispersion: Single read FRotationDispersion write FRotationDispersion;
    property AngularVelocityDispersion: Single read FAngularVelocityDispersion write FAngularVelocityDispersion;
    property SimulationSpace: TParticleSimulationSpace read FSimulationSpace write SetSimulationSpace;
    property BlendMode: TParticleBlendMode read FBlendMode write FBlendMode;
    property TextureKind: TParticleTextureKind read FTextureKind write SetTextureKind;
    property TexturePath: string read FTexturePath write SetTexturePath;

    property TexMapSize: Integer read FTexMapSize write SetTexMapSize;
    property NoiseSeed: Integer read FNoiseSeed write SetNoiseSeed;
    property NoiseScale: Integer read FNoiseScale write SetNoiseScale;
    property NoiseAmplitude: Integer read FNoiseAmplitude write SetNoiseAmplitude;
    property Smoothness: Single read FSmoothness write SetSmoothness;
    property Brightness: Single read FBrightness write SetBrightness;
    property Gamma: Single read FGamma write SetGamma;

    property OnCreateParticle: TParticleEvent read FOnCreateParticle write FOnCreateParticle;
    property OnActivateParticle: TParticleEvent read FOnActivateParticle write FOnActivateParticle;
    property OnKillParticle: TParticleEvent read FOnKillParticle write FOnKillParticle;
    property OnDestroyParticle: TParticleEvent read FOnDestroyParticle write FOnDestroyParticle;
    property OnParticleProgress: TParticleProgressEvent read FOnParticleProgress write FOnParticleProgress;
  end;

  TParticleSystemList = class(TObjectList<TParticleSystem>)
  private
    function GetItem(AIndex: Integer): TParticleSystem;
  public
    function AddParticleSystemToList(AParticleSystem: TParticleSystem): Integer;
    function CreateParticleSystem: TParticleSystem;
    function NameIsUnique(const AName: string): Boolean;
    function GenerateUniqueName: string;
    function DeleteParticleSystem(AIndex: Integer): Boolean; overload;
    function DeleteParticleSystem(AParticleSystem: TParticleSystem): Boolean; overload;
    function Clone: TParticleSystemList;
    procedure SaveToStream(Stream: TStream);
    procedure LoadFromStream(Stream: TStream);

    property Item[Index: Integer]: TParticleSystem read GetItem; default;
  end;

  TPerlin3DNoise = class
  private const
    TABLE_SIZE = 256;
    TABLE_MASK = TABLE_SIZE - 1;
  private
    FPermutations: array[0..TABLE_SIZE - 1] of Integer;
    FGradients: array[0..TABLE_SIZE * 3 - 1] of Single;
    function Lattice(IX, IY, IZ: Integer; FX, FY, FZ: Single): Single; overload;
    function Lattice(IX, IY: Integer; FX, FY: Single): Single; overload;
    function Smooth(X: Single): Single;
  public
    constructor Create(RandomSeed: Integer);
    procedure Initialize(RandomSeed: Integer);
    function Noise(X, Y: Single): Single; overload;
    function Noise(X, Y, Z: Single): Single; overload;
  end;

implementation

const
  PARTICLE_SYSTEM_STREAM_VERSION = 4;
  PARTICLE_SYSTEM_LIST_STREAM_VERSION = 1;

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
    raise Exception.Create('Invalid string length in particle stream.');

  SetLength(Result, Len);
  if Len > 0 then
    Stream.ReadBuffer(Result[1], Len * SizeOf(Char));
end;

function TryLoadTargaTexture(const AFileName: string; out Pixels: TBytes;
  out Width, Height: Integer): Boolean;
var
  Stream: TFileStream;
  Header: array[0..17] of Byte;
  IDLength, ColorMapType, ImageType, BitsPerPixel, Descriptor: Byte;
  BytesPerPixel: Integer;
  PixelCount, PixelIndex: Integer;
  TopOrigin, RightOrigin: Boolean;
  PacketHeader: Byte;
  RunLength, I: Integer;
  B, G, R, A: Byte;

  function WordAt(Offset: Integer): Word;
  begin
    Result := Word(Header[Offset]) or (Word(Header[Offset + 1]) shl 8);
  end;

  function ReadPixel(out B, G, R, A: Byte): Boolean;
  var
    FilePixel: array[0..3] of Byte;
  begin
    Result := Stream.Read(FilePixel[0], BytesPerPixel) = BytesPerPixel;
    if not Result then
      Exit;

    B := FilePixel[0];
    G := FilePixel[1];
    R := FilePixel[2];
    if BytesPerPixel = 4 then
      A := FilePixel[3]
    else
      A := 255;
  end;

  procedure StorePixel(SourceIndex: Integer; B, G, R, A: Byte);
  var
    SourceX, SourceY, DestX, DestY, DestIndex: Integer;
  begin
    SourceX := SourceIndex mod Width;
    SourceY := SourceIndex div Width;

    if RightOrigin then
      DestX := Width - 1 - SourceX
    else
      DestX := SourceX;

    if TopOrigin then
      DestY := SourceY
    else
      DestY := Height - 1 - SourceY;

    DestIndex := (DestY * Width + DestX) * 4;
    Pixels[DestIndex + 0] := B;
    Pixels[DestIndex + 1] := G;
    Pixels[DestIndex + 2] := R;
    Pixels[DestIndex + 3] := A;
  end;

begin
  Result := False;
  Pixels := nil;
  Width := 0;
  Height := 0;

  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    if Stream.Read(Header[0], SizeOf(Header)) <> SizeOf(Header) then
      Exit;

    IDLength := Header[0];
    ColorMapType := Header[1];
    ImageType := Header[2];
    Width := WordAt(12);
    Height := WordAt(14);
    BitsPerPixel := Header[16];
    Descriptor := Header[17];

    if (ColorMapType <> 0) or not (ImageType in [2, 10]) or
       not (BitsPerPixel in [24, 32]) or (Width <= 0) or (Height <= 0) or
       (Width > MaxInt div Height) then
      Exit;

    PixelCount := Width * Height;
    if PixelCount > MaxInt div 4 then
      Exit;

    BytesPerPixel := BitsPerPixel div 8;
    TopOrigin := (Descriptor and $20) <> 0;
    RightOrigin := (Descriptor and $10) <> 0;
    SetLength(Pixels, PixelCount * 4);

    if Stream.Size < SizeOf(Header) + IDLength then
      Exit;
    Stream.Position := SizeOf(Header) + IDLength;

    PixelIndex := 0;
    if ImageType = 2 then
    begin
      while PixelIndex < PixelCount do
      begin
        if not ReadPixel(B, G, R, A) then
          Exit;
        StorePixel(PixelIndex, B, G, R, A);
        Inc(PixelIndex);
      end;
    end
    else
    begin
      while PixelIndex < PixelCount do
      begin
        if Stream.Read(PacketHeader, SizeOf(PacketHeader)) <> SizeOf(PacketHeader) then
          Exit;

        RunLength := (PacketHeader and $7F) + 1;
        if (PacketHeader and $80) <> 0 then
        begin
          if not ReadPixel(B, G, R, A) then
            Exit;

          for I := 0 to RunLength - 1 do
          begin
            if PixelIndex >= PixelCount then
              Exit;
            StorePixel(PixelIndex, B, G, R, A);
            Inc(PixelIndex);
          end;
        end
        else
        begin
          for I := 0 to RunLength - 1 do
          begin
            if PixelIndex >= PixelCount then
              Exit;
            if not ReadPixel(B, G, R, A) then
              Exit;
            StorePixel(PixelIndex, B, G, R, A);
            Inc(PixelIndex);
          end;
        end;
      end;
    end;

    Result := PixelIndex = PixelCount;
  finally
    if not Result then
    begin
      Pixels := nil;
      Width := 0;
      Height := 0;
    end;
    Stream.Free;
  end;
end;

function ClampSingle(Value, MinValue, MaxValue: Single): Single;
begin
  if Value < MinValue then
    Result := MinValue
  else if Value > MaxValue then
    Result := MaxValue
  else
    Result := Value;
end;

function LerpSingle(A, B, T: Single): Single;
begin
  Result := A + (B - A) * T;
end;

function LerpVector4(const A, B: TVector4; T: Single): TVector4;
begin
  Result := Vector4(
    LerpSingle(A.X, B.X, T),
    LerpSingle(A.Y, B.Y, T),
    LerpSingle(A.Z, B.Z, T),
    LerpSingle(A.W, B.W, T));
end;

{ TParticle }

constructor TParticle.Create;
begin
  inherited Create;
  Reset;
end;

procedure TParticle.Reset;
begin
  FID := 0;
  FTag := 0;
  FPosition := Vector3(0, 0, 0);
  FVelocity := Vector3(0, 0, 0);
  FAge := 0;
  FLifeTime := 1;
  FSizeScale := 1;
  FRotation := 0;
  FAngularVelocity := 0;
  FColor := Vector4(1, 1, 1, 1);
end;

{ TParticleSystem }

constructor TParticleSystem.Create;
begin
  inherited Create;

  FParticles := TObjectList<TParticle>.Create(True);
  FParticlePool := TObjectList<TParticle>.Create(True);
  FParticlePoolSize := 256;

  FName := 'ParticleSystem';
  FEnabled := True;
  FAutoEmit := True;
  FMaxParticles := 512;
  FEmissionRate := 20.0;
  FParticleLife := 2.0;
  FParticleLifeRandom := 0.5;
  FInitialPosition := Vector3(0, 0, 0);
  FInitialVelocity := Vector3(0, 1.2, 0);
  FPositionDispersion := 0.0;
  FPositionDispersionRange := Vector3(0.15, 0.15, 0.15);
  FVelocityDispersion := 0.35;
  FAcceleration := Vector3(0, -0.2, 0);
  FFriction := 0.0;
  FStartColor := Vector4(1.0, 0.65, 0.25, 0.9);
  FEndColor := Vector4(0.25, 0.25, 0.25, 0.0);
  FStartSize := 0.25;
  FEndSize := 1.0;
  FSizeRandom := 0.15;
  FAspectRatio := 1.0;
  FRotationDispersion := Pi;
  FAngularVelocityDispersion := 1.25;
  FSimulationSpace := psObject;
  FBlendMode := pbAlpha;
  FTextureKind := ptPerlin;
  FTexturePath := '';

  FTexMapSize := 7;
  FNoiseSeed := 0;
  FNoiseScale := 100;
  FNoiseAmplitude := 50;
  FSmoothness := 1.0;
  FBrightness := 1.0;
  FGamma := 1.0;

  FVAO := 0;
  FVBO := 0;
  FTextureID := 0;
  FTextureDirty := True;
  FShader := nil;
end;

destructor TParticleSystem.Destroy;
var
  Particle: TParticle;
begin
  if Assigned(FOnDestroyParticle) then
  begin
    for Particle in FParticles do
      FOnDestroyParticle(Self, Particle);
    for Particle in FParticlePool do
      FOnDestroyParticle(Self, Particle);
  end;

  DestroyBuffers;
  DestroyTexture;
  DestroyShader;
  FParticles.Free;
  FParticlePool.Free;

  inherited Destroy;
end;

procedure TParticleSystem.Assign(Source: TParticleSystem);
begin
  if Source = nil then
    Exit;

  Clear;
  FParticlePool.Clear;

  FParticlePoolSize := Source.FParticlePoolSize;
  FName := Source.FName;
  FEnabled := Source.FEnabled;
  FAutoEmit := Source.FAutoEmit;
  FMaxParticles := Source.FMaxParticles;
  FEmissionRate := Source.FEmissionRate;
  FParticleLife := Source.FParticleLife;
  FParticleLifeRandom := Source.FParticleLifeRandom;
  FInitialPosition := Source.FInitialPosition;
  FInitialVelocity := Source.FInitialVelocity;
  FPositionDispersion := Source.FPositionDispersion;
  FPositionDispersionRange := Source.FPositionDispersionRange;
  FVelocityDispersion := Source.FVelocityDispersion;
  FAcceleration := Source.FAcceleration;
  FFriction := Source.FFriction;
  FStartColor := Source.FStartColor;
  FEndColor := Source.FEndColor;
  FStartSize := Source.FStartSize;
  FEndSize := Source.FEndSize;
  FSizeRandom := Source.FSizeRandom;
  FAspectRatio := Source.FAspectRatio;
  FRotationDispersion := Source.FRotationDispersion;
  FAngularVelocityDispersion := Source.FAngularVelocityDispersion;
  FSimulationSpace := Source.FSimulationSpace;
  FBlendMode := Source.FBlendMode;
  FTextureKind := Source.FTextureKind;
  FTexturePath := Source.FTexturePath;
  FTexMapSize := Source.FTexMapSize;
  FNoiseSeed := Source.FNoiseSeed;
  FNoiseScale := Source.FNoiseScale;
  FNoiseAmplitude := Source.FNoiseAmplitude;
  FSmoothness := Source.FSmoothness;
  FBrightness := Source.FBrightness;
  FGamma := Source.FGamma;
  MarkTextureDirty;
end;

function TParticleSystem.GetParticleCount: Integer;
begin
  Result := FParticles.Count;
end;

function TParticleSystem.Clone: TParticleSystem;
begin
  Result := TParticleSystem.Create;
  Result.Assign(Self);
end;

procedure TParticleSystem.SetMaxParticles(const Value: Integer);
begin
  FMaxParticles := Max(0, Value);
  while FParticles.Count > FMaxParticles do
    KillParticle(FParticles[FParticles.Count - 1]);
end;

procedure TParticleSystem.SetParticlePoolSize(const Value: Integer);
begin
  FParticlePoolSize := Max(0, Value);
  while FParticlePool.Count > FParticlePoolSize do
    FParticlePool.Delete(FParticlePool.Count - 1);
end;

procedure TParticleSystem.SetParticleLife(const Value: Single);
begin
  FParticleLife := Max(0.001, Value);
end;

procedure TParticleSystem.SetParticleLifeRandom(const Value: Single);
begin
  FParticleLifeRandom := Max(0.0, Value);
end;

procedure TParticleSystem.SetEmissionRate(const Value: Single);
begin
  FEmissionRate := Max(0.0, Value);
end;

procedure TParticleSystem.SetFriction(const Value: Single);
begin
  FFriction := Max(0.0, Value);
end;

procedure TParticleSystem.SetStartSize(const Value: Single);
begin
  FStartSize := Max(0.0, Value);
end;

procedure TParticleSystem.SetEndSize(const Value: Single);
begin
  FEndSize := Max(0.0, Value);
end;

procedure TParticleSystem.SetSizeRandom(const Value: Single);
begin
  FSizeRandom := Max(0.0, Value);
end;

procedure TParticleSystem.SetAspectRatio(const Value: Single);
begin
  FAspectRatio := ClampSingle(Value, 0.001, 1000.0);
end;

procedure TParticleSystem.SetSimulationSpace(const Value: TParticleSimulationSpace);
begin
  if FSimulationSpace = Value then
    Exit;

  FSimulationSpace := Value;
  Clear;
end;

procedure TParticleSystem.SetTextureKind(const Value: TParticleTextureKind);
begin
  if FTextureKind <> Value then
  begin
    FTextureKind := Value;
    MarkTextureDirty;
  end;
end;

procedure TParticleSystem.SetTexturePath(const Value: string);
var
  Normalized: string;
begin
  Normalized := Trim(Value);
  if FTexturePath <> Normalized then
  begin
    FTexturePath := Normalized;
    MarkTextureDirty;
  end;
end;

procedure TParticleSystem.SetTexMapSize(const Value: Integer);
begin
  FTexMapSize := EnsureRange(Value, 3, 10);
  MarkTextureDirty;
end;

procedure TParticleSystem.SetNoiseSeed(const Value: Integer);
begin
  if FNoiseSeed <> Value then
  begin
    FNoiseSeed := Value;
    MarkTextureDirty;
  end;
end;

procedure TParticleSystem.SetNoiseScale(const Value: Integer);
begin
  if FNoiseScale <> Value then
  begin
    FNoiseScale := Max(0, Value);
    MarkTextureDirty;
  end;
end;

procedure TParticleSystem.SetNoiseAmplitude(const Value: Integer);
begin
  FNoiseAmplitude := EnsureRange(Value, 0, 100);
  MarkTextureDirty;
end;

procedure TParticleSystem.SetSmoothness(const Value: Single);
begin
  FSmoothness := ClampSingle(Value, 0.001, 1000.0);
  MarkTextureDirty;
end;

procedure TParticleSystem.SetBrightness(const Value: Single);
begin
  FBrightness := ClampSingle(Value, 0.001, 1000.0);
  MarkTextureDirty;
end;

procedure TParticleSystem.SetGamma(const Value: Single);
begin
  FGamma := ClampSingle(Value, 0.1, 10.0);
  MarkTextureDirty;
end;

procedure TParticleSystem.MarkTextureDirty;
begin
  FTextureDirty := True;
end;

procedure TParticleSystem.EnsureBuffers;
begin
  if FVAO <> 0 then
    Exit;

  glGenVertexArrays(1, @FVAO);
  glBindVertexArray(FVAO);

  glGenBuffers(1, @FVBO);
  glBindBuffer(GL_ARRAY_BUFFER, FVBO);
  glBufferData(GL_ARRAY_BUFFER, 0, nil, GL_DYNAMIC_DRAW);

  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, SizeOf(TParticleVertex), nil);

  glEnableVertexAttribArray(1);
  glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, SizeOf(TParticleVertex),
    Pointer(NativeUInt(SizeOf(TVector3))));

  glEnableVertexAttribArray(2);
  glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, SizeOf(TParticleVertex),
    Pointer(NativeUInt(SizeOf(TVector3) + SizeOf(TVector4))));

  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glBindVertexArray(0);
end;

procedure TParticleSystem.EnsureShader;
begin
  if FShader = nil then
    FShader := TShader.Create(TEnginePaths.Shader('ParticleBillboard.vert'),
      TEnginePaths.Shader('ParticleBillboard.frag'));
end;

procedure TParticleSystem.EnsureTexture;
var
  Graphic: TGraphic;
  Bitmap: TBitmap;
  TextureFileName: string;
  Ext: string;
  Size, X, Y, Center: Integer;
  Data: TBytes;
  Index: Integer;
  TextureWidth, TextureHeight: Integer;
  RowSize: Integer;
  I: Integer;
  AlphaOffset: Integer;
  HasNonZeroAlpha: Boolean;
  FX, FY, Dist, Intensity, AlphaValue: Single;
  Noise: TPerlin3DNoise;
  NoiseValue, NoiseAmount, InvGamma: Single;
begin
  if FTextureKind = ptNone then
  begin
    DestroyTexture;
    FTextureDirty := False;
    Exit;
  end;

  if (FTextureID <> 0) and (not FTextureDirty) then
    Exit;

  DestroyTexture;

  if FTextureKind = ptFile then
  begin
    TextureFileName := TEnginePaths.ResolveAssetPath(FTexturePath);
    if (TextureFileName = '') or (not FileExists(TextureFileName)) then
    begin
      FTextureDirty := False;
      Exit;
    end;

    Ext := LowerCase(ExtractFileExt(TextureFileName));
    Graphic := nil;
    Bitmap := nil;
    try
      TextureWidth := 0;
      TextureHeight := 0;

      if Ext = '.tga' then
      begin
        if not TryLoadTargaTexture(TextureFileName, Data, TextureWidth,
          TextureHeight) then
        begin
          FTextureDirty := False;
          Exit;
        end;
      end
      else if Ext = '.png' then
      begin
        Graphic := TGraphicClass(TPNGGraphic).Create;

        Graphic.LoadFromFile(TextureFileName);
        Bitmap := TBitmap.Create;
        Bitmap.PixelFormat := pf32bit;
        Bitmap.SetSize(Graphic.Width, Graphic.Height);
        Bitmap.Canvas.Brush.Color := clBlack;
        Bitmap.Canvas.FillRect(Rect(0, 0, Graphic.Width, Graphic.Height));
        Bitmap.Canvas.Draw(0, 0, Graphic);

        TextureWidth := Bitmap.Width;
        TextureHeight := Bitmap.Height;
        RowSize := Bitmap.Width * 4;
        SetLength(Data, RowSize * Bitmap.Height);
        for Y := 0 to Bitmap.Height - 1 do
          Move(Bitmap.ScanLine[Bitmap.Height - 1 - Y]^, Data[Y * RowSize],
            RowSize);
      end
      else if Ext = '.dds' then
      begin
        if not LoadDDS2DTexture(TextureFileName, True, GL_RGBA8,
          GL_CLAMP_TO_EDGE, False, FTextureID, TextureWidth, TextureHeight) then
        begin
          FTextureDirty := False;
          Exit;
        end;

        FTextureDirty := False;
        Exit;
      end
      else
      begin
        FTextureDirty := False;
        Exit;
      end;

      HasNonZeroAlpha := False;
      for I := 0 to (Length(Data) div 4) - 1 do
      begin
        AlphaOffset := I * 4 + 3;
        if Data[AlphaOffset] <> 0 then
        begin
          HasNonZeroAlpha := True;
          Break;
        end;
      end;

      if not HasNonZeroAlpha then
        for I := 0 to (Length(Data) div 4) - 1 do
          Data[I * 4 + 3] := 255;

      glGenTextures(1, @FTextureID);
      glBindTexture(GL_TEXTURE_2D, FTextureID);
      glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, TextureWidth, TextureHeight, 0,
        GL_BGRA, GL_UNSIGNED_BYTE, @Data[0]);
      glGenerateMipmap(GL_TEXTURE_2D);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
      glBindTexture(GL_TEXTURE_2D, 0);

      FTextureDirty := False;
      Exit;
    finally
      Bitmap.Free;
      Graphic.Free;
    end;
  end;

  Size := 1 shl EnsureRange(FTexMapSize, 3, 10);
  Center := Size div 2;
  SetLength(Data, Size * Size * 4);
  Noise := nil;
  try
    if FTextureKind = ptPerlin then
      Noise := TPerlin3DNoise.Create(FNoiseSeed);

    NoiseAmount := FNoiseAmplitude * 0.01;
    InvGamma := 1.0 / ClampSingle(FGamma, 0.1, 10.0);

    for Y := 0 to Size - 1 do
      for X := 0 to Size - 1 do
      begin
        FX := (X + 0.5 - Center) / Center;
        FY := (Y + 0.5 - Center) / Center;
        Dist := Sqrt(FX * FX + FY * FY);

        Index := (Y * Size + X) * 4;
        if Dist < 1.0 then
        begin
          AlphaValue := Power(1.0 - Dist, FSmoothness);
          Intensity := 1.0;
          if Assigned(Noise) then
          begin
            NoiseValue := Noise.Noise(X * FNoiseScale * 0.0005,
              Y * FNoiseScale * 0.0005);
            NoiseValue := NoiseValue * 0.5 + 0.5;
            Intensity := (1.0 - NoiseAmount * 0.5) + NoiseValue * NoiseAmount;
          end;

          Intensity := ClampSingle(Power(Max(0.0, Intensity), InvGamma) *
            FBrightness, 0.0, 1.0);
          AlphaValue := ClampSingle(AlphaValue, 0.0, 1.0);

          Data[Index + 0] := Round(Intensity * 255);
          Data[Index + 1] := Round(Intensity * 255);
          Data[Index + 2] := Round(Intensity * 255);
          Data[Index + 3] := Round(AlphaValue * 255);
        end
        else
        begin
          Data[Index + 0] := 0;
          Data[Index + 1] := 0;
          Data[Index + 2] := 0;
          Data[Index + 3] := 0;
        end;
      end;
  finally
    Noise.Free;
  end;

  glGenTextures(1, @FTextureID);
  glBindTexture(GL_TEXTURE_2D, FTextureID);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, Size, Size, 0, GL_RGBA,
    GL_UNSIGNED_BYTE, @Data[0]);
  glBindTexture(GL_TEXTURE_2D, 0);

  FTextureDirty := False;
end;

procedure TParticleSystem.DestroyBuffers;
begin
  if FVBO <> 0 then
  begin
    glDeleteBuffers(1, @FVBO);
    FVBO := 0;
  end;

  if FVAO <> 0 then
  begin
    glDeleteVertexArrays(1, @FVAO);
    FVAO := 0;
  end;
end;

procedure TParticleSystem.DestroyTexture;
begin
  if FTextureID <> 0 then
  begin
    glDeleteTextures(1, @FTextureID);
    FTextureID := 0;
  end;
end;

procedure TParticleSystem.DestroyShader;
begin
  FreeAndNil(FShader);
end;

function TParticleSystem.RandomSigned: Single;
begin
  Result := Random * 2.0 - 1.0;
end;

function TParticleSystem.RandomUnitVector: TVector3;
var
  Z, A, R: Single;
begin
  Z := RandomSigned;
  A := Random * 2.0 * Pi;
  R := Sqrt(Max(0.0, 1.0 - Z * Z));
  Result := Vector3(Cos(A) * R, Sin(A) * R, Z);
end;

function TParticleSystem.NewParticlePosition: TVector3;
begin
  Result := FInitialPosition +
    Vector3(RandomSigned * FPositionDispersionRange.X,
            RandomSigned * FPositionDispersionRange.Y,
            RandomSigned * FPositionDispersionRange.Z);

  if FPositionDispersion > 0 then
    Result := Result + RandomUnitVector * (Random * FPositionDispersion);
end;

function TParticleSystem.NewParticleVelocity: TVector3;
begin
  Result := FInitialVelocity;
  if FVelocityDispersion > 0 then
    Result := Result + RandomUnitVector * (Random * FVelocityDispersion);
end;

function TParticleSystem.SimulationPosition(const LocalPosition: TVector3;
  const OwnerWorldMatrix: TMatrix4): TVector3;
begin
  if FSimulationSpace = psWorld then
    // World-space settings are global offsets. The owner determines where an
    // emitter starts, but its rotation and scale must not rotate the emission.
    Result := Vector3(OwnerWorldMatrix.Columns[3]) + LocalPosition
  else
    Result := LocalPosition;
end;

function TParticleSystem.SimulationVelocity(const LocalVelocity: TVector3;
  const OwnerWorldMatrix: TMatrix4): TVector3;
begin
  // Velocity is stored in the active simulation coordinate system. In world
  // mode it must remain aligned to global axes, regardless of owner rotation.
  Result := LocalVelocity;
end;

function TParticleSystem.RenderPosition(AParticle: TParticle;
  const OwnerWorldMatrix: TMatrix4): TVector3;
begin
  if FSimulationSpace = psWorld then
    Result := AParticle.Position
  else
    Result := Vector3(OwnerWorldMatrix * Vector4(AParticle.Position, 1.0));
end;

function TParticleSystem.CreateParticle: TParticle;
begin
  Result := CreateParticle(TMatrix4.Identity);
end;

function TParticleSystem.CreateParticle(const OwnerWorldMatrix: TMatrix4): TParticle;
var
  NewlyCreated: Boolean;
begin
  Result := nil;
  if (FMaxParticles <= 0) or (FParticles.Count >= FMaxParticles) then
    Exit;

  NewlyCreated := False;
  if FParticlePool.Count > 0 then
  begin
    Result := FParticlePool[FParticlePool.Count - 1];
    FParticlePool.Extract(Result);
  end
  else
  begin
    Result := TParticle.Create;
    NewlyCreated := True;
  end;

  Result.Reset;
  Result.FID := FNextID;
  Inc(FNextID);
  Result.Position := SimulationPosition(NewParticlePosition, OwnerWorldMatrix);
  Result.Velocity := SimulationVelocity(NewParticleVelocity, OwnerWorldMatrix);
  Result.LifeTime := Max(0.001, FParticleLife + RandomSigned * FParticleLifeRandom);
  Result.SizeScale := Max(0.001, 1.0 + RandomSigned * FSizeRandom);
  Result.Rotation := RandomSigned * FRotationDispersion;
  Result.AngularVelocity := RandomSigned * FAngularVelocityDispersion;

  if NewlyCreated and Assigned(FOnCreateParticle) then
    FOnCreateParticle(Self, Result);

  FParticles.Add(Result);

  if Assigned(FOnActivateParticle) then
    FOnActivateParticle(Self, Result);
end;

procedure TParticleSystem.KillParticle(AParticle: TParticle);
begin
  if AParticle = nil then
    Exit;

  if Assigned(FOnKillParticle) then
    FOnKillParticle(Self, AParticle);

  if FParticles.IndexOf(AParticle) >= 0 then
    FParticles.Extract(AParticle);

  if FParticlePool.Count < FParticlePoolSize then
    FParticlePool.Add(AParticle)
  else
  begin
    if Assigned(FOnDestroyParticle) then
      FOnDestroyParticle(Self, AParticle);
    AParticle.Free;
  end;
end;

procedure TParticleSystem.Burst(Count: Integer);
begin
  Burst(Count, TMatrix4.Identity);
end;

procedure TParticleSystem.Burst(Count: Integer; const OwnerWorldMatrix: TMatrix4);
var
  I: Integer;
begin
  for I := 1 to Count do
    if CreateParticle(OwnerWorldMatrix) = nil then
      Break;
end;

procedure TParticleSystem.Clear;
begin
  while FParticles.Count > 0 do
    KillParticle(FParticles[FParticles.Count - 1]);
  FEmissionAccumulator := 0;
end;

procedure TParticleSystem.Update(DeltaTime: Single; NewTime: Double);
begin
  Update(DeltaTime, NewTime, TMatrix4.Identity);
end;

procedure TParticleSystem.Update(DeltaTime: Single; NewTime: Double;
  const OwnerWorldMatrix: TMatrix4);
var
  I, EmitCount: Integer;
  Particle: TParticle;
  Kill: Boolean;
  FrictionFactor: Single;
begin
  if not FEnabled then
    Exit;

  DeltaTime := Max(0.0, DeltaTime);

  if FAutoEmit and (FEmissionRate > 0) and (DeltaTime > 0) then
  begin
    FEmissionAccumulator := FEmissionAccumulator + FEmissionRate * DeltaTime;
    EmitCount := Trunc(FEmissionAccumulator);
    if EmitCount > 0 then
    begin
      FEmissionAccumulator := FEmissionAccumulator - EmitCount;
      Burst(EmitCount, OwnerWorldMatrix);
    end;
  end;

  if FFriction > 0 then
    FrictionFactor := Max(0.0, 1.0 - FFriction * DeltaTime)
  else
    FrictionFactor := 1.0;

  for I := FParticles.Count - 1 downto 0 do
  begin
    Particle := FParticles[I];
    Particle.Age := Particle.Age + DeltaTime;
    Particle.Velocity := (Particle.Velocity + FAcceleration * DeltaTime) *
      FrictionFactor;
    Particle.Position := Particle.Position + Particle.Velocity * DeltaTime;
    Particle.Rotation := Particle.Rotation + Particle.AngularVelocity * DeltaTime;

    Kill := Particle.Age >= Particle.LifeTime;
    if Assigned(FOnParticleProgress) then
      FOnParticleProgress(Self, Particle, DeltaTime, Kill);

    if Kill then
      KillParticle(Particle);
  end;
end;

function TParticleSystem.EvaluateColor(AParticle: TParticle): TVector4;
var
  T: Single;
begin
  if AParticle.LifeTime > 0 then
    T := ClampSingle(AParticle.Age / AParticle.LifeTime, 0.0, 1.0)
  else
    T := 1.0;

  Result := LerpVector4(FStartColor, FEndColor, T);
  Result.X := Result.X * AParticle.Color.X;
  Result.Y := Result.Y * AParticle.Color.Y;
  Result.Z := Result.Z * AParticle.Color.Z;
  Result.W := Result.W * AParticle.Color.W;
end;

function TParticleSystem.EvaluateSize(AParticle: TParticle): Single;
var
  T: Single;
begin
  if AParticle.LifeTime > 0 then
    T := ClampSingle(AParticle.Age / AParticle.LifeTime, 0.0, 1.0)
  else
    T := 1.0;

  Result := LerpSingle(FStartSize, FEndSize, T) * AParticle.SizeScale;
end;

procedure TParticleSystem.SortRenderRefs(var Refs: TParticleRenderRefs);

  procedure QuickSort(L, R: Integer);
  var
    I, J: Integer;
    Pivot: Single;
    Temp: TParticleRenderRef;
  begin
    I := L;
    J := R;
    Pivot := Refs[(L + R) div 2].DistanceSq;
    repeat
      while Refs[I].DistanceSq > Pivot do
        Inc(I);
      while Refs[J].DistanceSq < Pivot do
        Dec(J);
      if I <= J then
      begin
        Temp := Refs[I];
        Refs[I] := Refs[J];
        Refs[J] := Temp;
        Inc(I);
        Dec(J);
      end;
    until I > J;

    if L < J then
      QuickSort(L, J);
    if I < R then
      QuickSort(I, R);
  end;

begin
  if Length(Refs) > 1 then
    QuickSort(0, High(Refs));
end;

procedure TParticleSystem.Render(const ViewProjection: TMatrix4;
  const OwnerWorldMatrix: TMatrix4; const CameraPosition, CameraRight,
  CameraUp: TVector3);
const
  TEX: array[0..5] of TVector2 = (
    (X: 0; Y: 0), (X: 1; Y: 0), (X: 1; Y: 1),
    (X: 0; Y: 0), (X: 1; Y: 1), (X: 0; Y: 1)
  );
var
  Refs: TParticleRenderRefs;
  Vertices: TArray<TParticleVertex>;
  I, V: Integer;
  Particle: TParticle;
  WorldPosition, ToCamera: TVector3;
  Right, Up, RotRight, RotUp: TVector3;
  Corners: array[0..3] of TVector3;
  Color: TVector4;
  SizeValue, HalfWidth, HalfHeight, S, C: Single;
  OldDepthMask, OldBlendEnabled, OldCullEnabled, OldDepthTestEnabled: GLboolean;
  OldSrcRGB, OldDstRGB, OldSrcAlpha, OldDstAlpha: GLint;
begin
  if (not FEnabled) or (FParticles.Count = 0) then
    Exit;

  EnsureShader;
  EnsureBuffers;
  EnsureTexture;

  SetLength(Refs, FParticles.Count);
  for I := 0 to FParticles.Count - 1 do
  begin
    Particle := FParticles[I];
    WorldPosition := RenderPosition(Particle, OwnerWorldMatrix);
    ToCamera := WorldPosition - CameraPosition;
    Refs[I].Particle := Particle;
    Refs[I].DistanceSq := ToCamera.LengthSquared;
  end;
  SortRenderRefs(Refs);

  SetLength(Vertices, Length(Refs) * 6);
  V := 0;
  for I := 0 to High(Refs) do
  begin
    Particle := Refs[I].Particle;
    WorldPosition := RenderPosition(Particle, OwnerWorldMatrix);
    Color := EvaluateColor(Particle);
    SizeValue := EvaluateSize(Particle);
    HalfWidth := SizeValue * Sqrt(FAspectRatio) * 0.5;
    HalfHeight := SizeValue / Max(0.001, Sqrt(FAspectRatio)) * 0.5;

    Right := CameraRight.Normalize * HalfWidth;
    Up := CameraUp.Normalize * HalfHeight;
    S := Sin(Particle.Rotation);
    C := Cos(Particle.Rotation);
    RotRight := Right * C + Up * S;
    RotUp := Up * C - Right * S;

    Corners[0] := WorldPosition - RotRight - RotUp;
    Corners[1] := WorldPosition + RotRight - RotUp;
    Corners[2] := WorldPosition + RotRight + RotUp;
    Corners[3] := WorldPosition - RotRight + RotUp;

    Vertices[V].Position := Corners[0]; Vertices[V].Color := Color; Vertices[V].TexCoord := TEX[0]; Inc(V);
    Vertices[V].Position := Corners[1]; Vertices[V].Color := Color; Vertices[V].TexCoord := TEX[1]; Inc(V);
    Vertices[V].Position := Corners[2]; Vertices[V].Color := Color; Vertices[V].TexCoord := TEX[2]; Inc(V);
    Vertices[V].Position := Corners[0]; Vertices[V].Color := Color; Vertices[V].TexCoord := TEX[3]; Inc(V);
    Vertices[V].Position := Corners[2]; Vertices[V].Color := Color; Vertices[V].TexCoord := TEX[4]; Inc(V);
    Vertices[V].Position := Corners[3]; Vertices[V].Color := Color; Vertices[V].TexCoord := TEX[5]; Inc(V);
  end;

  OldDepthTestEnabled := glIsEnabled(GL_DEPTH_TEST);
  OldBlendEnabled := glIsEnabled(GL_BLEND);
  OldCullEnabled := glIsEnabled(GL_CULL_FACE);
  glGetBooleanv(GL_DEPTH_WRITEMASK, @OldDepthMask);
  glGetIntegerv(GL_BLEND_SRC_RGB, @OldSrcRGB);
  glGetIntegerv(GL_BLEND_DST_RGB, @OldDstRGB);
  glGetIntegerv(GL_BLEND_SRC_ALPHA, @OldSrcAlpha);
  glGetIntegerv(GL_BLEND_DST_ALPHA, @OldDstAlpha);

  glEnable(GL_DEPTH_TEST);
  glDepthMask(GL_FALSE);
  glDisable(GL_CULL_FACE);
  glEnable(GL_BLEND);
  case FBlendMode of
    pbAdditive: glBlendFunc(GL_SRC_ALPHA, GL_ONE);
  else
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  end;

  FShader.Use;
  FShader.SetUniform('viewProjection', ViewProjection);
  if (FTextureKind <> ptNone) and (FTextureID <> 0) then
  begin
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, FTextureID);
    FShader.SetUniform('particleTexture', 0);
    FShader.SetUniform('useTexture', 1);
  end
  else
    FShader.SetUniform('useTexture', 0);

  glBindVertexArray(FVAO);
  glBindBuffer(GL_ARRAY_BUFFER, FVBO);
  glBufferData(GL_ARRAY_BUFFER, Length(Vertices) * SizeOf(TParticleVertex),
    @Vertices[0], GL_DYNAMIC_DRAW);
  glDrawArrays(GL_TRIANGLES, 0, Length(Vertices));
  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glBindVertexArray(0);
  glBindTexture(GL_TEXTURE_2D, 0);

  glBlendFuncSeparate(OldSrcRGB, OldDstRGB, OldSrcAlpha, OldDstAlpha);
  glDepthMask(OldDepthMask);
  if OldDepthTestEnabled = GL_TRUE then glEnable(GL_DEPTH_TEST) else glDisable(GL_DEPTH_TEST);
  if OldBlendEnabled = GL_TRUE then glEnable(GL_BLEND) else glDisable(GL_BLEND);
  if OldCullEnabled = GL_TRUE then glEnable(GL_CULL_FACE) else glDisable(GL_CULL_FACE);
end;

procedure TParticleSystem.SaveToStream(Stream: TStream);
var
  Version: Integer;
  BlendValue, TextureValue, SimulationValue: Integer;
begin
  Version := PARTICLE_SYSTEM_STREAM_VERSION;
  Stream.WriteBuffer(Version, SizeOf(Version));
  WriteStringToStream(Stream, FName);
  Stream.WriteBuffer(FEnabled, SizeOf(FEnabled));
  Stream.WriteBuffer(FAutoEmit, SizeOf(FAutoEmit));
  Stream.WriteBuffer(FMaxParticles, SizeOf(FMaxParticles));
  Stream.WriteBuffer(FParticlePoolSize, SizeOf(FParticlePoolSize));
  Stream.WriteBuffer(FEmissionRate, SizeOf(FEmissionRate));
  Stream.WriteBuffer(FParticleLife, SizeOf(FParticleLife));
  Stream.WriteBuffer(FParticleLifeRandom, SizeOf(FParticleLifeRandom));
  Stream.WriteBuffer(FInitialPosition, SizeOf(FInitialPosition));
  Stream.WriteBuffer(FInitialVelocity, SizeOf(FInitialVelocity));
  Stream.WriteBuffer(FPositionDispersion, SizeOf(FPositionDispersion));
  Stream.WriteBuffer(FPositionDispersionRange, SizeOf(FPositionDispersionRange));
  Stream.WriteBuffer(FVelocityDispersion, SizeOf(FVelocityDispersion));
  Stream.WriteBuffer(FAcceleration, SizeOf(FAcceleration));
  Stream.WriteBuffer(FFriction, SizeOf(FFriction));
  Stream.WriteBuffer(FStartColor, SizeOf(FStartColor));
  Stream.WriteBuffer(FEndColor, SizeOf(FEndColor));
  Stream.WriteBuffer(FStartSize, SizeOf(FStartSize));
  Stream.WriteBuffer(FEndSize, SizeOf(FEndSize));
  Stream.WriteBuffer(FSizeRandom, SizeOf(FSizeRandom));
  Stream.WriteBuffer(FAspectRatio, SizeOf(FAspectRatio));
  Stream.WriteBuffer(FRotationDispersion, SizeOf(FRotationDispersion));
  Stream.WriteBuffer(FAngularVelocityDispersion, SizeOf(FAngularVelocityDispersion));
  BlendValue := Ord(FBlendMode);
  TextureValue := Ord(FTextureKind);
  SimulationValue := Ord(FSimulationSpace);
  Stream.WriteBuffer(BlendValue, SizeOf(BlendValue));
  Stream.WriteBuffer(TextureValue, SizeOf(TextureValue));
  Stream.WriteBuffer(FTexMapSize, SizeOf(FTexMapSize));
  Stream.WriteBuffer(FNoiseSeed, SizeOf(FNoiseSeed));
  Stream.WriteBuffer(FNoiseScale, SizeOf(FNoiseScale));
  Stream.WriteBuffer(FNoiseAmplitude, SizeOf(FNoiseAmplitude));
  Stream.WriteBuffer(FSmoothness, SizeOf(FSmoothness));
  Stream.WriteBuffer(FBrightness, SizeOf(FBrightness));
  Stream.WriteBuffer(FGamma, SizeOf(FGamma));
  Stream.WriteBuffer(SimulationValue, SizeOf(SimulationValue));
  WriteStringToStream(Stream, FTexturePath);
end;

procedure TParticleSystem.LoadFromStream(Stream: TStream);
var
  Version: Integer;
  BlendValue, TextureValue, SimulationValue: Integer;
begin
  Clear;
  FParticlePool.Clear;

  Stream.ReadBuffer(Version, SizeOf(Version));
  if (Version < 1) or (Version > PARTICLE_SYSTEM_STREAM_VERSION) then
    raise Exception.CreateFmt('Unsupported particle system version: %d.', [Version]);

  if Version >= 4 then
    FName := ReadStringFromStream(Stream)
  else
    FName := 'ParticleSystem';

  Stream.ReadBuffer(FEnabled, SizeOf(FEnabled));
  Stream.ReadBuffer(FAutoEmit, SizeOf(FAutoEmit));
  Stream.ReadBuffer(FMaxParticles, SizeOf(FMaxParticles));
  Stream.ReadBuffer(FParticlePoolSize, SizeOf(FParticlePoolSize));
  Stream.ReadBuffer(FEmissionRate, SizeOf(FEmissionRate));
  Stream.ReadBuffer(FParticleLife, SizeOf(FParticleLife));
  Stream.ReadBuffer(FParticleLifeRandom, SizeOf(FParticleLifeRandom));
  Stream.ReadBuffer(FInitialPosition, SizeOf(FInitialPosition));
  Stream.ReadBuffer(FInitialVelocity, SizeOf(FInitialVelocity));
  Stream.ReadBuffer(FPositionDispersion, SizeOf(FPositionDispersion));
  Stream.ReadBuffer(FPositionDispersionRange, SizeOf(FPositionDispersionRange));
  Stream.ReadBuffer(FVelocityDispersion, SizeOf(FVelocityDispersion));
  Stream.ReadBuffer(FAcceleration, SizeOf(FAcceleration));
  Stream.ReadBuffer(FFriction, SizeOf(FFriction));
  Stream.ReadBuffer(FStartColor, SizeOf(FStartColor));
  Stream.ReadBuffer(FEndColor, SizeOf(FEndColor));
  Stream.ReadBuffer(FStartSize, SizeOf(FStartSize));
  Stream.ReadBuffer(FEndSize, SizeOf(FEndSize));
  Stream.ReadBuffer(FSizeRandom, SizeOf(FSizeRandom));
  Stream.ReadBuffer(FAspectRatio, SizeOf(FAspectRatio));
  Stream.ReadBuffer(FRotationDispersion, SizeOf(FRotationDispersion));
  Stream.ReadBuffer(FAngularVelocityDispersion, SizeOf(FAngularVelocityDispersion));
  Stream.ReadBuffer(BlendValue, SizeOf(BlendValue));
  Stream.ReadBuffer(TextureValue, SizeOf(TextureValue));
  FBlendMode := TParticleBlendMode(EnsureRange(BlendValue, Ord(Low(TParticleBlendMode)), Ord(High(TParticleBlendMode))));
  FTextureKind := TParticleTextureKind(EnsureRange(TextureValue, Ord(Low(TParticleTextureKind)), Ord(High(TParticleTextureKind))));
  Stream.ReadBuffer(FTexMapSize, SizeOf(FTexMapSize));
  Stream.ReadBuffer(FNoiseSeed, SizeOf(FNoiseSeed));
  Stream.ReadBuffer(FNoiseScale, SizeOf(FNoiseScale));
  Stream.ReadBuffer(FNoiseAmplitude, SizeOf(FNoiseAmplitude));
  Stream.ReadBuffer(FSmoothness, SizeOf(FSmoothness));
  Stream.ReadBuffer(FBrightness, SizeOf(FBrightness));
  Stream.ReadBuffer(FGamma, SizeOf(FGamma));
  if Version >= 3 then
  begin
    Stream.ReadBuffer(SimulationValue, SizeOf(SimulationValue));
    FSimulationSpace := TParticleSimulationSpace(EnsureRange(SimulationValue,
      Ord(Low(TParticleSimulationSpace)), Ord(High(TParticleSimulationSpace))));
  end
  else
    FSimulationSpace := psObject;

  if Version >= 2 then
    FTexturePath := ReadStringFromStream(Stream)
  else
    FTexturePath := '';

  FMaxParticles := Max(0, FMaxParticles);
  FParticlePoolSize := Max(0, FParticlePoolSize);
  FParticleLife := Max(0.001, FParticleLife);
  FParticleLifeRandom := Max(0.0, FParticleLifeRandom);
  FEmissionRate := Max(0.0, FEmissionRate);
  FFriction := Max(0.0, FFriction);
  FStartSize := Max(0.0, FStartSize);
  FEndSize := Max(0.0, FEndSize);
  FSizeRandom := Max(0.0, FSizeRandom);
  FAspectRatio := ClampSingle(FAspectRatio, 0.001, 1000.0);
  FTexMapSize := EnsureRange(FTexMapSize, 3, 10);
  FNoiseAmplitude := EnsureRange(FNoiseAmplitude, 0, 100);
  FNoiseScale := Max(0, FNoiseScale);
  FSmoothness := ClampSingle(FSmoothness, 0.001, 1000.0);
  FBrightness := ClampSingle(FBrightness, 0.001, 1000.0);
  FGamma := ClampSingle(FGamma, 0.1, 10.0);
  MarkTextureDirty;
end;

{ TParticleSystemList }

function TParticleSystemList.GetItem(AIndex: Integer): TParticleSystem;
begin
  if (AIndex >= 0) and (AIndex < Count) then
    Result := Items[AIndex]
  else
    Result := nil;
end;

function TParticleSystemList.AddParticleSystemToList(
  AParticleSystem: TParticleSystem): Integer;
begin
  if AParticleSystem = nil then
    Exit(-1);

  if Trim(AParticleSystem.Name) = '' then
    AParticleSystem.Name := GenerateUniqueName
  else if not NameIsUnique(AParticleSystem.Name) then
    AParticleSystem.Name := GenerateUniqueName;

  Result := inherited Add(AParticleSystem);
end;

function TParticleSystemList.CreateParticleSystem: TParticleSystem;
begin
  Result := TParticleSystem.Create;
  AddParticleSystemToList(Result);
end;

function TParticleSystemList.NameIsUnique(const AName: string): Boolean;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if SameText(Items[I].Name, AName) then
      Exit(False);
  Result := True;
end;

function TParticleSystemList.GenerateUniqueName: string;
var
  Counter: Integer;
begin
  Counter := 1;
  repeat
    Result := 'ParticleSystem_' + Counter.ToString;
    Inc(Counter);
  until NameIsUnique(Result);
end;

function TParticleSystemList.DeleteParticleSystem(AIndex: Integer): Boolean;
begin
  if (AIndex < 0) or (AIndex >= Count) then
    Exit(False);
  Delete(AIndex);
  Result := True;
end;

function TParticleSystemList.DeleteParticleSystem(
  AParticleSystem: TParticleSystem): Boolean;
var
  Index: Integer;
begin
  Index := IndexOf(AParticleSystem);
  Result := DeleteParticleSystem(Index);
end;

function TParticleSystemList.Clone: TParticleSystemList;
var
  I: Integer;
begin
  Result := TParticleSystemList.Create;
  for I := 0 to Count - 1 do
    if Items[I] <> nil then
      Result.AddParticleSystemToList(Items[I].Clone);
end;

procedure TParticleSystemList.SaveToStream(Stream: TStream);
var
  I: Integer;
  Version: Integer;
  ParticleSystemCount: Integer;
begin
  Version := PARTICLE_SYSTEM_LIST_STREAM_VERSION;
  Stream.WriteBuffer(Version, SizeOf(Version));
  ParticleSystemCount := Count;
  Stream.WriteBuffer(ParticleSystemCount, SizeOf(ParticleSystemCount));
  for I := 0 to ParticleSystemCount - 1 do
    Items[I].SaveToStream(Stream);
end;

procedure TParticleSystemList.LoadFromStream(Stream: TStream);
var
  I: Integer;
  Version: Integer;
  ParticleSystemCount: Integer;
  ParticleSystem: TParticleSystem;
begin
  Clear;
  Stream.ReadBuffer(Version, SizeOf(Version));
  if (Version < 1) or (Version > PARTICLE_SYSTEM_LIST_STREAM_VERSION) then
    raise Exception.CreateFmt('Unsupported particle-system-list version: %d.',
      [Version]);

  Stream.ReadBuffer(ParticleSystemCount, SizeOf(ParticleSystemCount));
  if (ParticleSystemCount < 0) or (ParticleSystemCount > 100000) then
    raise Exception.Create('Invalid particle-system-list count in scene stream.');

  for I := 0 to ParticleSystemCount - 1 do
  begin
    ParticleSystem := TParticleSystem.Create;
    try
      ParticleSystem.LoadFromStream(Stream);
      AddParticleSystemToList(ParticleSystem);
    except
      ParticleSystem.Free;
      raise;
    end;
  end;
end;

{ TPerlin3DNoise }

constructor TPerlin3DNoise.Create(RandomSeed: Integer);
begin
  inherited Create;
  Initialize(RandomSeed);
end;

procedure TPerlin3DNoise.Initialize(RandomSeed: Integer);
var
  SeedBackup: Integer;
  I, J, T: Integer;
  Z, R, A: Single;
begin
  SeedBackup := RandSeed;
  RandSeed := RandomSeed;
  try
    for I := 0 to TABLE_SIZE - 1 do
    begin
      Z := 1.0 - 2.0 * Random;
      R := Sqrt(Max(0.0, 1.0 - Z * Z));
      A := Random * 2.0 * Pi;
      FGradients[I * 3 + 0] := Cos(A) * R;
      FGradients[I * 3 + 1] := Sin(A) * R;
      FGradients[I * 3 + 2] := Z;
      FPermutations[I] := I;
    end;

    for I := 0 to TABLE_SIZE - 1 do
    begin
      J := Random(TABLE_SIZE);
      T := FPermutations[I];
      FPermutations[I] := FPermutations[J];
      FPermutations[J] := T;
    end;
  finally
    RandSeed := SeedBackup;
  end;
end;

function TPerlin3DNoise.Smooth(X: Single): Single;
begin
  Result := X * X * (3.0 - 2.0 * X);
end;

function TPerlin3DNoise.Lattice(IX, IY, IZ: Integer; FX, FY,
  FZ: Single): Single;
var
  G: Integer;
begin
  G := FPermutations[(IX + FPermutations[(IY + FPermutations[IZ and TABLE_MASK]) and
    TABLE_MASK]) and TABLE_MASK] * 3;
  Result := FGradients[G] * FX + FGradients[G + 1] * FY + FGradients[G + 2] * FZ;
end;

function TPerlin3DNoise.Lattice(IX, IY: Integer; FX, FY: Single): Single;
var
  G: Integer;
begin
  G := FPermutations[(IX + FPermutations[(IY + FPermutations[0]) and TABLE_MASK])
    and TABLE_MASK] * 3;
  Result := FGradients[G] * FX + FGradients[G + 1] * FY;
end;

function TPerlin3DNoise.Noise(X, Y: Single): Single;
var
  IX, IY: Integer;
  FX0, FX1, FY0, FY1, WX, WY, V0, V1: Single;
begin
  IX := System.Math.Floor(X);
  IY := System.Math.Floor(Y);
  FX0 := X - IX;
  FY0 := Y - IY;
  FX1 := FX0 - 1.0;
  FY1 := FY0 - 1.0;
  WX := Smooth(FX0);
  WY := Smooth(FY0);

  V0 := LerpSingle(Lattice(IX, IY, FX0, FY0),
                   Lattice(IX + 1, IY, FX1, FY0), WX);
  V1 := LerpSingle(Lattice(IX, IY + 1, FX0, FY1),
                   Lattice(IX + 1, IY + 1, FX1, FY1), WX);
  Result := LerpSingle(V0, V1, WY);
end;

function TPerlin3DNoise.Noise(X, Y, Z: Single): Single;
var
  IX, IY, IZ: Integer;
  FX0, FX1, FY0, FY1, FZ0, FZ1, WX, WY, WZ: Single;
  VY0, VY1, VZ0, VZ1: Single;
begin
  IX := System.Math.Floor(X);
  IY := System.Math.Floor(Y);
  IZ := System.Math.Floor(Z);
  FX0 := X - IX; FX1 := FX0 - 1.0; WX := Smooth(FX0);
  FY0 := Y - IY; FY1 := FY0 - 1.0; WY := Smooth(FY0);
  FZ0 := Z - IZ; FZ1 := FZ0 - 1.0; WZ := Smooth(FZ0);

  VY0 := LerpSingle(Lattice(IX, IY, IZ, FX0, FY0, FZ0),
                    Lattice(IX + 1, IY, IZ, FX1, FY0, FZ0), WX);
  VY1 := LerpSingle(Lattice(IX, IY + 1, IZ, FX0, FY1, FZ0),
                    Lattice(IX + 1, IY + 1, IZ, FX1, FY1, FZ0), WX);
  VZ0 := LerpSingle(VY0, VY1, WY);

  VY0 := LerpSingle(Lattice(IX, IY, IZ + 1, FX0, FY0, FZ1),
                    Lattice(IX + 1, IY, IZ + 1, FX1, FY0, FZ1), WX);
  VY1 := LerpSingle(Lattice(IX, IY + 1, IZ + 1, FX0, FY1, FZ1),
                    Lattice(IX + 1, IY + 1, IZ + 1, FX1, FY1, FZ1), WX);
  VZ1 := LerpSingle(VY0, VY1, WY);

  Result := LerpSingle(VZ0, VZ1, WZ);
end;

end.
