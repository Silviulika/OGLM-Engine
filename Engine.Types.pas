unit Engine.Types;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, dglOpenGL, Vcl.ExtCtrls, Vcl.StdCtrls, System.Math,
  Vcl.Imaging.pngimage, Vcl.Imaging.jpeg, GraphicEx, Neslib.FastMath;

function LoadDDS2DTexture(const AFileName: string; MipMap: Boolean;
  InternalFormat, Param: GLint; InvertNormals: Boolean; out TextureID: GLuint;
  out TextureWidth, TextureHeight: Integer): Boolean;

type
  TVertexAttribute = record
  strict private
    f_index: GLuint;
    f_size: GLint;
    f_type: GLenum;
    f_normalized: GLboolean;

    function Get_index: GLuint;
    function Get_size: GLint;
    function Get_type: GLenum;
    function Get_normalized: GLboolean;
  public
    procedure Initialize(index: GLuint; size: GLint; _type: GLenum; normalized: GLboolean; const _pointer: PGLvoid);

    property VA_index: GLuint read Get_index;
    property VA_size: GLint read Get_size;
    property VA_type: GLenum read Get_type;
    property VA_normalized: GLboolean read Get_normalized;

  end;

type
  TTexture = record
    DiffuseColor: TVector3;   // used in some shaders textures, kept for compatibility
    SpecularColor: TVector3;
    Shininess: GLfloat;
    TexID: GLuint;
    Name: string;              // uniform name in the shader (e.g. "albedoTexture")
  public
    function LoadTexTGA(const AFileName: string; MipMap: Boolean; const AUniformName: string; internalFormat, param: GLint; InvertNormals: Boolean): Boolean;
    function LoadTexPNG(const AFileName: string; MipMap: Boolean; const AUniformName: string; internalFormat, param: GLint; InvertNormals: Boolean): Boolean;
    function LoadTexJPG(const AFileName: string; MipMap: Boolean; const AUniformName: string; internalFormat, param: GLint; InvertNormals: Boolean): Boolean;
    function LoadTexDDS(const AFileName: string; MipMap: Boolean; const AUniformName: string; internalFormat, param: GLint; InvertNormals: Boolean): Boolean;
  end;

type
  TMaterialTexture = record
    Texture: TTexture;
    Path: string;

    function LoadTexTGA(const AFileName: string; MipMap: Boolean; const AUniformName: string; internalFormat, param: GLint; InvertNormals: Boolean): Boolean;
    function LoadTexPNG(const AFileName: string; MipMap: Boolean; const AUniformName: string; internalFormat, param: GLint; InvertNormals: Boolean): Boolean;
    function LoadTexJPG(const AFileName: string; MipMap: Boolean; const AUniformName: string; internalFormat, param: GLint; InvertNormals: Boolean): Boolean;
    function LoadTexDDS(const AFileName: string; MipMap: Boolean; const AUniformName: string; internalFormat, param: GLint; InvertNormals: Boolean): Boolean;
  end;

type
  TVertex = packed record
    Position: TVector3;  // 3 floats
    Normal: TVector3;    // 3 floats
    Tangent: TVector3;   // 3 floats � tangent (aligned with U axis)
    Bitangent: TVector3; // 3 floats � bitangent (aligned with V axis)
    TexCoord: TVector2;  // 2 floats
  end;

type
  /// <summary>Key for edge caching in mesh subdivision (stores vertex indices in sorted order).</summary>
  TEdgeKey = record
    Min, Max: Integer;
  end;

type
  /// <summary>Simple triplet of three integer indices for face representation.</summary>
  TTriplet = record
    I0, I1, I2: Integer;
    constructor Create(A, B, C: Integer);
  end;

type
  /// <summary>Cap generation style for cut superellipsoids.</summary>
  TCapType = (ctNone   = 0,  // No cap generated
              ctCenter = 1,  // Fan from rim to a single center vertex
              ctFlat   = 2); // Fan from rim to a flattened disc (planar UVs)

type
  /// <summary>Key for texture seam fix cache (position, normal, adjusted U coordinate).</summary>
  TVertexKey = record
    Pos: TVector3;
    Norm: TVector3;
    UAdj: Single;
  end;

type
  TGizmoMode = (gmTranslate, gmRotate, gmScale);

type
  TViewport = record
    X: Integer;
    Y: Integer;
    Width: Integer;
    Height: Integer;
  end;

type
  TFrustumPlanes = array[0..5] of TVector4;

type
  TAABB = record
    Min: TVector3;
    Max: TVector3;
    procedure Include(const Point: TVector3); overload;
    procedure Include(const Other: TAABB); overload;
    function Transform(const Matrix: TMatrix4): TAABB;
    function Center: TVector3;
    function Extents: TVector3;
    function IsValid: Boolean;
  end;

type
  TMeshCenterPreset = (
    cpCenter,

    // X = Left/Right, Y = Top/Bottom, Z = Middle
    cpLeftTopMiddle, cpLeftMiddleMiddle, cpLeftBottomMiddle,
    cpRightTopMiddle, cpRightMiddleMiddle, cpRightBottomMiddle,

    // Y = Top/Bottom, Z = Front/Back, X = Middle
    cpFrontTopMiddle, cpFrontMiddleMiddle, cpFrontBottomMiddle,
    cpBackTopMiddle,  cpBackMiddleMiddle,  cpBackBottomMiddle,

    // NEW: Y = Middle, X = Left/Right, Z = Front/Back  (4 vertical-edge midpoints)
    cpFrontMiddleLeft, cpFrontMiddleRight,
    cpBackMiddleLeft,  cpBackMiddleRight,

    // NEW: X = Middle, Z = Middle, Y = Top/Bottom  (top & bottom face centers)
    cpTopMiddleMiddle, cpBottomMiddleMiddle,

    // Corners
    cpFrontTopLeft, cpFrontTopRight, cpFrontBottomLeft, cpFrontBottomRight,
    cpBackTopLeft,  cpBackTopRight,  cpBackBottomLeft,  cpBackBottomRight
  );

type
  TMeshType = (mtEmpty,
               mtFile,
               mtPlane,
               mtCube,
               mtSphere,
               mtCylinder,
               mtCapsule,
               mtTorus,
               mtCone,
               mtPrism,
               mtFrustum,
               mtIcosphere,
               mtGeodesicDome,
               mtGizmo,
               mtArrow,
               mtSuperEllipsoid,
               mtHeightField,
               mtWater);

type
  TMeshTransformDescriptor = record
    Valid: Boolean;
    Position: TVector3;
    Rotation: TVector3; // editor/UI degrees
    Scale: TVector3;
  end;

function DefaultMeshTransformDescriptor: TMeshTransformDescriptor;
function UnknownMeshTransformDescriptor: TMeshTransformDescriptor;

type
  TTerrainMeshDescriptor = record
    Name: String;
    Width: Single;
    Depth: Single;
    HeightScale: Single;
    HeightMapWidth: Integer;
    HeightMapDepth: Integer;
    UVScale: Single;
    TileSize: Integer;
    LODEnabled: Boolean;
    LODCount: Integer;
    LODDistance: Single;
    SourceFile: string;
    Position: TVector3;
    Rotation: TVector3;
    Scale:    TVector3;
  end;

type
  TPlaneMeshDescriptor = record
    Name: String;
    Width: Single;
    WidthSegments: Integer;
    Depth: Single;
    DepthSegments: Integer;
    Position: TVector3;
    Rotation: TVector3;
    Scale:    TVector3;
  end;

type
  TWaterPlaneMeshDescriptor = record
    Name: String;
    Width: Single;
    WidthSegments: Integer;
    Depth: Single;
    DepthSegments: Integer;
    TintColor: TVector4;
    DeepColor: TVector4;
    ReflectionStrength: Single;
    WaveScale: Single;
    WaveSpeed: Single;
    WaveStrength: Single;
    FresnelPower: Single;
    Alpha: Single;
    Position: TVector3;
    Rotation: TVector3;
    Scale:    TVector3;
  end;

type
  TCubeMeshDescriptor = record
    Name: String;
    Width: Single;
    WidthSegments: Integer;
    Depth: Single;
    DepthSegments: Integer;
    Height: Single;
    HeightSegments: Integer;
    Position: TVector3;
    Rotation: TVector3;
    Scale:    TVector3;
  end;

type
  TSphereMeshDescriptor = record
    Name: String;
    Radius: Single;
    StackCount: Integer;
    SliceCount: Integer;
    Position: TVector3;
    Rotation: TVector3;
    Scale:    TVector3;
  end;

type
  TCilinderMeshDescriptor = record
    Name: String;
    Radius: Single;
    Height: Single;
    Slices: Integer;
    Stacks: Integer;
    Position: TVector3;
    Rotation: TVector3;
    Scale:    TVector3;
  end;

type
  TCapsuleMeshDescriptor = record
    Name: String;
    Radius: Single;
    Height: Single;
    Slices: Integer;
    Stacks: Integer;
    Position: TVector3;
    Rotation: TVector3;
    Scale:    TVector3;
  end;

type
  TTorusMeshDescriptor = record
    Name: String;
    MajorRadius: Single;
    MinorRadius: Single;
    MajorSegments: Integer;
    MinorSegments: Integer;
    Position: TVector3;
    Rotation: TVector3;
    Scale:    TVector3;
  end;

type
  TConeMeshDescriptor = record
    Name: String;
    Radius: Single;
    Height: Single;
    Sides: Integer;
    Stacks: Integer;
    Position: TVector3;
    Rotation: TVector3;
    Scale:    TVector3;
  end;

type
  TPrismMeshDescriptor = record
    Name: String;
    Radius: Single;
    Height: Single;
    Sides: Integer;
    Stacks: Integer;
    Position: TVector3;
    Rotation: TVector3;
    Scale:    TVector3;
  end;

type
  TFrustumMeshDescriptor = record
    Name: String;
    BottomRadius: Single;
    TopRadius: Single;
    Height: Single;
    Slices: Integer;
    Stacks: Integer;
    BottomCap: TCapType;
    TopCap: TCapType;
    Position: TVector3;
    Rotation: TVector3;
    Scale:    TVector3;
  end;

type
  TArrowMeshDescriptor = record
    Name: String;
    ShaftLength: Single;
    TipLength: Single;
    ShaftRadius: Single;
    TipRadius: Single;
    Slices: Integer;
    Stacks: Integer;
    Position: TVector3;
    Rotation: TVector3;
    Scale:    TVector3;
  end;

type
  TIcosphereMeshDescriptor = record
    Name: String;
    Radius: Single;
    Subdivisions: Integer;
    Position: TVector3;
    Rotation: TVector3;
    Scale:    TVector3;
  end;

type
  TGeodesicDomeMeshDescriptor = record
    Name: String;
    Radius: Single;
    Subdivisions: Integer;
    Position: TVector3;
    Rotation: TVector3;
    Scale:    TVector3;
  end;

type
  TSuperEllipsoidMeshDescriptor = record
    Name: String;
    Radius: Single;
    VCurve: Single;
    HCurve: Single;
    Slices: Integer;
    Stacks: Integer;
    Position: TVector3;
    Rotation: TVector3;
    Scale:    TVector3;
  end;

type
  TPhysicsBodyType = (
    pbtStatic,
    pbtDynamic,
    pbtKinematic,
    pbtCharacter,
    pbtProjectile
  );

  TPhysicsColliderKind = (
    pckAuto,
    pckNone,
    pckSphere,
    pckCapsule,
    pckAABB,
    pckMesh,
    pckConvexHull
  );


implementation

type
  TDDSPixelFormat = packed record
    Size: Cardinal;
    Flags: Cardinal;
    FourCC: Cardinal;
    RGBBitCount: Cardinal;
    RBitMask: Cardinal;
    GBitMask: Cardinal;
    BBitMask: Cardinal;
    ABitMask: Cardinal;
  end;

  TDDSHeader = packed record
    Size: Cardinal;
    Flags: Cardinal;
    Height: Cardinal;
    Width: Cardinal;
    PitchOrLinearSize: Cardinal;
    Depth: Cardinal;
    MipMapCount: Cardinal;
    Reserved1: array[0..10] of Cardinal;
    PixelFormat: TDDSPixelFormat;
    Caps: Cardinal;
    Caps2: Cardinal;
    Caps3: Cardinal;
    Caps4: Cardinal;
    Reserved2: Cardinal;
  end;

  TDDSHeaderDX10 = packed record
    DXGIFormat: Cardinal;
    ResourceDimension: Cardinal;
    MiscFlag: Cardinal;
    ArraySize: Cardinal;
    MiscFlags2: Cardinal;
  end;

const
  DDS_MAGIC = $20534444;
  DDS_HEADER_SIZE = 124;
  DDS_PIXEL_FORMAT_SIZE = 32;
  DDSD_PITCH = $00000008;
  DDPF_ALPHAPIXELS = $00000001;
  DDPF_FOURCC = $00000004;
  DDPF_RGB = $00000040;
  DDSCAPS2_CUBEMAP = $00000200;
  DDSCAPS2_VOLUME = $00200000;
  DDS_FOURCC_DXT1 = $31545844;
  DDS_FOURCC_DXT3 = $33545844;
  DDS_FOURCC_DXT5 = $35545844;
  DDS_FOURCC_DX10 = $30315844;
  D3D10_RESOURCE_DIMENSION_TEXTURE2D = 3;
  D3D10_RESOURCE_MISC_TEXTURECUBE = $4;
  DXGI_FORMAT_R8G8B8A8_UNORM = 28;
  DXGI_FORMAT_R8G8B8A8_UNORM_SRGB = 29;
  DXGI_FORMAT_BC1_UNORM = 71;
  DXGI_FORMAT_BC1_UNORM_SRGB = 72;
  DXGI_FORMAT_BC2_UNORM = 74;
  DXGI_FORMAT_BC2_UNORM_SRGB = 75;
  DXGI_FORMAT_BC3_UNORM = 77;
  DXGI_FORMAT_BC3_UNORM_SRGB = 78;
  DXGI_FORMAT_B8G8R8A8_UNORM = 87;
  DXGI_FORMAT_B8G8R8A8_UNORM_SRGB = 91;
  DXGI_FORMAT_BC7_UNORM = 98;
  DXGI_FORMAT_BC7_UNORM_SRGB = 99;
  GL_COMPRESSED_SRGB_S3TC_DXT1_EXT = $8C4C;
  GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT = $8C4E;
  GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT = $8C4F;
  GL_COMPRESSED_RGBA_BPTC_UNORM = $8E8C;
  GL_COMPRESSED_SRGB_ALPHA_BPTC_UNORM = $8E8D;
  MAX_TEXTURE_ANISOTROPY_CAP = 8.0;

function DDSChannelToByte(const Pixel, Mask: Cardinal; const DefaultValue: Byte): Byte;
var
  Shift: Integer;
  BitCount: Integer;
  Value: Cardinal;
  MaxValue: Cardinal;
begin
  if Mask = 0 then
    Exit(DefaultValue);

  Shift := 0;
  while ((Mask shr Shift) and 1) = 0 do
    Inc(Shift);

  BitCount := 0;
  while (((Mask shr (Shift + BitCount)) and 1) <> 0) do
    Inc(BitCount);

  Value := (Pixel and Mask) shr Shift;
  if BitCount >= 8 then
    Exit(Byte(Value shr (BitCount - 8)));

  MaxValue := (Cardinal(1) shl BitCount) - 1;
  Result := Byte((Value * 255 + (MaxValue div 2)) div MaxValue);
end;

function DDSPixelValue(const Data: TBytes; Offset, ByteCount: Integer): Cardinal;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to ByteCount - 1 do
    Result := Result or (Cardinal(Data[Offset + I]) shl (I * 8));
end;

procedure UploadDDSCompressedLevel(Target: GLenum; Level: GLint;
  InternalFormat: GLenum; Width, Height, ImageSize: Integer; const Data: TBytes);
begin
  if Assigned(glCompressedTexImage2D) then
    glCompressedTexImage2D(Target, Level, InternalFormat, Width, Height, 0,
      ImageSize, @Data[0])
  else if Assigned(glCompressedTexImage2DARB) then
    glCompressedTexImage2DARB(Target, Level, InternalFormat, Width, Height,
      0, ImageSize, @Data[0])
  else
    raise Exception.Create('OpenGL compressed texture upload is unavailable.');
end;

procedure ApplyTextureAnisotropy(Target: GLenum; Enabled: Boolean);
var
  MaxAnisotropy: GLfloat;
  DesiredAnisotropy: GLfloat;
begin
  if (not Enabled) or (not GL_EXT_texture_filter_anisotropic) or
     (not Assigned(glTexParameterf)) then
    Exit;

  MaxAnisotropy := 1.0;
  glGetFloatv(GL_MAX_TEXTURE_MAX_ANISOTROPY, @MaxAnisotropy);
  if MaxAnisotropy <= 1.0 then
    Exit;

  DesiredAnisotropy := MaxAnisotropy;
  if DesiredAnisotropy > MAX_TEXTURE_ANISOTROPY_CAP then
    DesiredAnisotropy := MAX_TEXTURE_ANISOTROPY_CAP;
  glTexParameterf(Target, GL_TEXTURE_MAX_ANISOTROPY, DesiredAnisotropy);
end;

function LoadDDS2DTexture(const AFileName: string; MipMap: Boolean;
  InternalFormat, Param: GLint; InvertNormals: Boolean; out TextureID: GLuint;
  out TextureWidth, TextureHeight: Integer): Boolean;
var
  Stream: TFileStream;
  Magic: Cardinal;
  Header: TDDSHeader;
  HeaderDX10: TDDSHeaderDX10;
  IsCompressed: Boolean;
  IsSRGB: Boolean;
  IsDXT3: Boolean;
  IsBC7: Boolean;
  CompressedFormat: GLenum;
  BlockSize: Integer;
  BytesPerPixel: Integer;
  MipLevels: Integer;
  Level: Integer;
  Width, Height: Integer;
  BlocksWide, BlocksHigh: Integer;
  RowPitch, MinimumRowPitch: Integer;
  LevelSize: Integer;
  SourceData: TBytes;
  RGBAData: TBytes;
  X, Y: Integer;
  SourceOffset, DestinationOffset: Integer;
  Pixel: Cardinal;
  UseMipMapFilter: Boolean;
  function IsDX10Header: Boolean;
  begin
    Result := ((Header.PixelFormat.Flags and DDPF_FOURCC) <> 0) and
      (Header.PixelFormat.FourCC = DDS_FOURCC_DX10);
  end;
  procedure SetDX10RGBAFormat(const IsBGRA: Boolean);
  begin
    IsCompressed := False;
    BytesPerPixel := 4;
    Header.PixelFormat.RGBBitCount := 32;
    Header.PixelFormat.ABitMask := $FF000000;
    if IsBGRA then
    begin
      Header.PixelFormat.RBitMask := $00FF0000;
      Header.PixelFormat.GBitMask := $0000FF00;
      Header.PixelFormat.BBitMask := $000000FF;
    end
    else
    begin
      Header.PixelFormat.RBitMask := $000000FF;
      Header.PixelFormat.GBitMask := $0000FF00;
      Header.PixelFormat.BBitMask := $00FF0000;
    end;
  end;
  procedure RequireStreamBytes(const ByteCount: Integer);
  begin
    if (ByteCount < 0) or (Int64(ByteCount) > (Stream.Size - Stream.Position)) then
      raise EReadError.Create('DDS payload is truncated.');
  end;
begin
  Result := False;
  TextureID := 0;
  TextureWidth := 0;
  TextureHeight := 0;
  if not FileExists(AFileName) then
    Exit;

  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    if Stream.Size < (SizeOf(Magic) + SizeOf(Header)) then
      Exit;
    Stream.ReadBuffer(Magic, SizeOf(Magic));
    Stream.ReadBuffer(Header, SizeOf(Header));
    if (Magic <> DDS_MAGIC) or (Header.Size <> DDS_HEADER_SIZE) or
       (Header.PixelFormat.Size <> DDS_PIXEL_FORMAT_SIZE) or
       (Header.Width = 0) or (Header.Height = 0) then
      Exit;

    if ((Header.Caps2 and DDSCAPS2_CUBEMAP) <> 0) or
       ((Header.Caps2 and DDSCAPS2_VOLUME) <> 0) then
      Exit;

    IsCompressed := False;
    IsSRGB := False;
    IsDXT3 := False;
    IsBC7 := False;
    CompressedFormat := 0;
    BlockSize := 0;
    BytesPerPixel := 0;

    if IsDX10Header then
    begin
      if (Stream.Size - Stream.Position) < SizeOf(HeaderDX10) then
        Exit;
      Stream.ReadBuffer(HeaderDX10, SizeOf(HeaderDX10));
      if (HeaderDX10.ResourceDimension <> D3D10_RESOURCE_DIMENSION_TEXTURE2D) or
         (HeaderDX10.ArraySize <> 1) or
         ((HeaderDX10.MiscFlag and D3D10_RESOURCE_MISC_TEXTURECUBE) <> 0) then
        Exit;

      case HeaderDX10.DXGIFormat of
        DXGI_FORMAT_BC1_UNORM,
        DXGI_FORMAT_BC1_UNORM_SRGB:
          begin
            IsCompressed := True;
            IsSRGB := HeaderDX10.DXGIFormat = DXGI_FORMAT_BC1_UNORM_SRGB;
            CompressedFormat := GL_COMPRESSED_RGBA_S3TC_DXT1_EXT;
            BlockSize := 8;
          end;
        DXGI_FORMAT_BC2_UNORM,
        DXGI_FORMAT_BC2_UNORM_SRGB:
          begin
            IsCompressed := True;
            IsSRGB := HeaderDX10.DXGIFormat = DXGI_FORMAT_BC2_UNORM_SRGB;
            IsDXT3 := True;
            CompressedFormat := GL_COMPRESSED_RGBA_S3TC_DXT3_EXT;
            BlockSize := 16;
          end;
        DXGI_FORMAT_BC3_UNORM,
        DXGI_FORMAT_BC3_UNORM_SRGB:
          begin
            IsCompressed := True;
            IsSRGB := HeaderDX10.DXGIFormat = DXGI_FORMAT_BC3_UNORM_SRGB;
            CompressedFormat := GL_COMPRESSED_RGBA_S3TC_DXT5_EXT;
            BlockSize := 16;
          end;
        DXGI_FORMAT_BC7_UNORM,
        DXGI_FORMAT_BC7_UNORM_SRGB:
          begin
            IsCompressed := True;
            IsSRGB := HeaderDX10.DXGIFormat = DXGI_FORMAT_BC7_UNORM_SRGB;
            IsBC7 := True;
            CompressedFormat := GL_COMPRESSED_RGBA_BPTC_UNORM;
            BlockSize := 16;
          end;
        DXGI_FORMAT_R8G8B8A8_UNORM,
        DXGI_FORMAT_R8G8B8A8_UNORM_SRGB:
          begin
            IsSRGB := HeaderDX10.DXGIFormat = DXGI_FORMAT_R8G8B8A8_UNORM_SRGB;
            SetDX10RGBAFormat(False);
          end;
        DXGI_FORMAT_B8G8R8A8_UNORM,
        DXGI_FORMAT_B8G8R8A8_UNORM_SRGB:
          begin
            IsSRGB := HeaderDX10.DXGIFormat = DXGI_FORMAT_B8G8R8A8_UNORM_SRGB;
            SetDX10RGBAFormat(True);
          end;
      else
        Exit;
      end;
    end
    else if (Header.PixelFormat.Flags and DDPF_FOURCC) <> 0 then
    begin
      IsCompressed := True;
      case Header.PixelFormat.FourCC of
        DDS_FOURCC_DXT1:
          begin
            CompressedFormat := GL_COMPRESSED_RGBA_S3TC_DXT1_EXT;
            BlockSize := 8;
          end;
        DDS_FOURCC_DXT3:
          begin
            IsDXT3 := True;
            CompressedFormat := GL_COMPRESSED_RGBA_S3TC_DXT3_EXT;
            BlockSize := 16;
          end;
        DDS_FOURCC_DXT5:
          begin
            CompressedFormat := GL_COMPRESSED_RGBA_S3TC_DXT5_EXT;
            BlockSize := 16;
          end;
      else
        Exit;
      end;
    end
    else
    begin
      if (Header.PixelFormat.Flags and DDPF_RGB) = 0 then
        Exit;
      if not (Header.PixelFormat.RGBBitCount in [16, 24, 32]) then
        Exit;
      BytesPerPixel := Header.PixelFormat.RGBBitCount div 8;
    end;

    if IsCompressed and InvertNormals then
      Exit;

    if IsCompressed and
       ((InternalFormat = GL_SRGB8_ALPHA8) or IsSRGB) then
      if IsBC7 then
        CompressedFormat := GL_COMPRESSED_SRGB_ALPHA_BPTC_UNORM
      else if BlockSize = 8 then
        CompressedFormat := GL_COMPRESSED_SRGB_S3TC_DXT1_EXT
      else if IsDXT3 then
        CompressedFormat := GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT
      else
        CompressedFormat := GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT;

    MipLevels := Header.MipMapCount;
    if MipLevels = 0 then
      MipLevels := 1;
    if MipLevels > 16 then
      Exit;

    TextureWidth := Header.Width;
    TextureHeight := Header.Height;
    glGenTextures(1, @TextureID);
    if TextureID = 0 then
      Exit;

    try
      glBindTexture(GL_TEXTURE_2D, TextureID);
      for Level := 0 to MipLevels - 1 do
      begin
        Width := Max(1, TextureWidth shr Level);
        Height := Max(1, TextureHeight shr Level);
        if IsCompressed then
        begin
          BlocksWide := Max(1, (Width + 3) div 4);
          BlocksHigh := Max(1, (Height + 3) div 4);
          LevelSize := BlocksWide * BlocksHigh * BlockSize;
          RequireStreamBytes(LevelSize);
          SetLength(SourceData, LevelSize);
          Stream.ReadBuffer(SourceData[0], LevelSize);
          UploadDDSCompressedLevel(GL_TEXTURE_2D, Level, CompressedFormat,
            Width, Height, LevelSize, SourceData);
        end
        else
        begin
          MinimumRowPitch := Width * BytesPerPixel;
          if (Level = 0) and ((Header.Flags and DDSD_PITCH) <> 0) then
            RowPitch := Max(MinimumRowPitch, Integer(Header.PitchOrLinearSize))
          else
            RowPitch := MinimumRowPitch;
          LevelSize := RowPitch * Height;
          RequireStreamBytes(LevelSize);
          SetLength(SourceData, LevelSize);
          Stream.ReadBuffer(SourceData[0], LevelSize);

          SetLength(RGBAData, Width * Height * 4);
          for Y := 0 to Height - 1 do
            for X := 0 to Width - 1 do
            begin
              SourceOffset := Y * RowPitch + X * BytesPerPixel;
              DestinationOffset := (Y * Width + X) * 4;
              Pixel := DDSPixelValue(SourceData, SourceOffset, BytesPerPixel);
              RGBAData[DestinationOffset + 0] := DDSChannelToByte(Pixel,
                Header.PixelFormat.RBitMask, 0);
              RGBAData[DestinationOffset + 1] := DDSChannelToByte(Pixel,
                Header.PixelFormat.GBitMask, 0);
              RGBAData[DestinationOffset + 2] := DDSChannelToByte(Pixel,
                Header.PixelFormat.BBitMask, 0);
              RGBAData[DestinationOffset + 3] := DDSChannelToByte(Pixel,
                Header.PixelFormat.ABitMask, 255);
              if InvertNormals then
                RGBAData[DestinationOffset + 1] :=
                  255 - RGBAData[DestinationOffset + 1];
            end;
          glTexImage2D(GL_TEXTURE_2D, Level, InternalFormat, Width, Height,
            0, GL_RGBA, GL_UNSIGNED_BYTE, @RGBAData[0]);
        end;
      end;

      UseMipMapFilter := MipMap and (MipLevels > 1);
      if MipMap and (MipLevels = 1) then
      begin
        glGenerateMipmap(GL_TEXTURE_2D);
        UseMipMapFilter := True;
      end;

      if UseMipMapFilter then
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER,
          GL_LINEAR_MIPMAP_LINEAR)
      else
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, Param);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, Param);
      ApplyTextureAnisotropy(GL_TEXTURE_2D, UseMipMapFilter);
      glBindTexture(GL_TEXTURE_2D, 0);
      Result := True;
    except
      glBindTexture(GL_TEXTURE_2D, 0);
      glDeleteTextures(1, @TextureID);
      TextureID := 0;
      TextureWidth := 0;
      TextureHeight := 0;
      Result := False;
    end;
  finally
    Stream.Free;
  end;
end;

function DefaultMeshTransformDescriptor: TMeshTransformDescriptor;
begin
  Result.Valid := True;
  Result.Position := Vector3(0, 0, 0);
  Result.Rotation := Vector3(0, 0, 0);
  Result.Scale := Vector3(1, 1, 1);
end;

function UnknownMeshTransformDescriptor: TMeshTransformDescriptor;
begin
  Result := DefaultMeshTransformDescriptor;
  Result.Valid := False;
end;

{ TVertexAttribute }
function TVertexAttribute.Get_index: GLuint;
begin
  Result := f_index;
end;

function TVertexAttribute.Get_size: GLint;
begin
  Result := f_size;
end;

function TVertexAttribute.Get_type: GLenum;
begin
  Result := f_type;
end;

function TVertexAttribute.Get_normalized: GLboolean;
begin
  Result := f_normalized;
end;

procedure TVertexAttribute.Initialize(index: GLuint; size: GLint; _type: GLenum; normalized: GLboolean; const _pointer: PGLvoid);
begin
  f_index      := index;
  f_size       := size;
  f_type       := _type;
  f_normalized := normalized;

  glVertexAttribPointer(f_index, f_size, f_type, f_normalized, SizeOf(TVertex), _pointer);
  glEnableVertexAttribArray(f_index);
end;


{ TTexture }
function TTexture.LoadTexTGA(const AFileName: string; MipMap: Boolean; const AUniformName: string; internalFormat, param: GLint; InvertNormals: Boolean): Boolean;
var
  Graphic: TGraphic;
  Bitmap: TBitmap;
  Data: TBytes;
  RowSize: Integer;
  y: Integer;
  i: Integer;
begin
  Result := False;
  Name := AUniformName;

  Graphic := TGraphicClass(TTargaGraphic).Create;
  try
    Graphic.LoadFromFile(AFileName);
    Bitmap := TBitmap.Create;
    try
      Bitmap.PixelFormat := pf32bit;
      Bitmap.SetSize(Graphic.Width, Graphic.Height);
      Bitmap.Canvas.Draw(0, 0, Graphic);

      RowSize := Bitmap.Width * 4;
      SetLength(Data, RowSize * Bitmap.Height);
      for y := 0 to Bitmap.Height - 1 do
        Move(Bitmap.ScanLine[Bitmap.Height - 1 - y]^, Data[y * RowSize], RowSize);

      // Invert Normals
      if InvertNormals then
        begin
          for i := 0 to Length(Data) div 4 - 1 do
            Data[i*4 + 1] := 255 - Data[i*4 + 1];   // invert G
        end;

      glGenTextures(1, @TexID);
      glBindTexture(GL_TEXTURE_2D, TexID);
                                  // GL_RGBA
      glTexImage2D(GL_TEXTURE_2D, 0, internalFormat, Bitmap.Width, Bitmap.Height, 0,
                   GL_BGRA, GL_UNSIGNED_BYTE, @Data[0]);
                // GL_BGRA
      if MipMap then
      begin
        glGenerateMipmap(GL_TEXTURE_2D);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
      end
      else
      begin
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
      end;

      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, param);  // GL_REPEAT
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, param);  // GL_REPEAT
      ApplyTextureAnisotropy(GL_TEXTURE_2D, MipMap);

      Result := True;
    finally
      Bitmap.Free;
    end;
  finally
    Graphic.Free;
  end;
end;

function TTexture.LoadTexPNG(const AFileName: string; MipMap: Boolean; const AUniformName: string; internalFormat, param: GLint; InvertNormals: Boolean): Boolean;
var
  Graphic: TGraphic;
  Bitmap: TBitmap;
  Data: TBytes;
  RowSize: Integer;
  y: Integer;
  i: Integer;
begin
  Result := False;
  Name := AUniformName;

  Graphic := TGraphicClass(TPNGGraphic).Create;
  try
    Graphic.LoadFromFile(AFileName);
    Bitmap := TBitmap.Create;
    try
      Bitmap.PixelFormat := pf32bit;
      Bitmap.SetSize(Graphic.Width, Graphic.Height);
      Bitmap.Canvas.Draw(0, 0, Graphic);

      RowSize := Bitmap.Width * 4;
      SetLength(Data, RowSize * Bitmap.Height);
      for y := 0 to Bitmap.Height - 1 do
        Move(Bitmap.ScanLine[Bitmap.Height - 1 - y]^, Data[y * RowSize], RowSize);

      // Invert Normals
      if InvertNormals then
        begin
          for i := 0 to Length(Data) div 4 - 1 do
            Data[i*4 + 1] := 255 - Data[i*4 + 1];   // invert G
        end;

      glGenTextures(1, @TexID);
      glBindTexture(GL_TEXTURE_2D, TexID);
      glTexImage2D(GL_TEXTURE_2D, 0, internalFormat, Bitmap.Width, Bitmap.Height, 0,
                   GL_BGRA, GL_UNSIGNED_BYTE, @Data[0]);

      if MipMap then
      begin
        glGenerateMipmap(GL_TEXTURE_2D);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
      end
      else
      begin
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
      end;

      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, param);  // GL_REPEAT
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, param);  // GL_REPEAT
      ApplyTextureAnisotropy(GL_TEXTURE_2D, MipMap);
      Result := True;
    finally
      Bitmap.Free;
    end;
  finally
    Graphic.Free;
  end;
end;

function TTexture.LoadTexJPG(const AFileName: string; MipMap: Boolean; const AUniformName: string; internalFormat, param: GLint; InvertNormals: Boolean): Boolean;
var
  Graphic: TGraphic;
  Bitmap: TBitmap;
  Data: TBytes;
  RowSize: Integer;
  y: Integer;
  i: Integer;
begin
  Result := False;
  Name := AUniformName;

  Graphic := TJPEGImage.Create;
  try
    Graphic.LoadFromFile(AFileName);
    Bitmap := TBitmap.Create;
    try
      Bitmap.PixelFormat := pf32bit;
      Bitmap.SetSize(Graphic.Width, Graphic.Height);
      Bitmap.Canvas.Draw(0, 0, Graphic);

      RowSize := Bitmap.Width * 4;
      SetLength(Data, RowSize * Bitmap.Height);
      for y := 0 to Bitmap.Height - 1 do
        Move(Bitmap.ScanLine[Bitmap.Height - 1 - y]^, Data[y * RowSize], RowSize);

      for i := 0 to Length(Data) div 4 - 1 do
        Data[i*4 + 3] := 255;

      // Invert Normals
      if InvertNormals then
        begin
          for i := 0 to Length(Data) div 4 - 1 do
            Data[i*4 + 1] := 255 - Data[i*4 + 1];   // invert G
        end;

      glGenTextures(1, @TexID);
      glBindTexture(GL_TEXTURE_2D, TexID);
      glTexImage2D(GL_TEXTURE_2D, 0, internalFormat, Bitmap.Width, Bitmap.Height, 0,
                   GL_BGRA, GL_UNSIGNED_BYTE, @Data[0]);

      if MipMap then
      begin
        glGenerateMipmap(GL_TEXTURE_2D);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
      end
      else
      begin
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
      end;

      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, param);  // GL_REPEAT
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, param);  // GL_REPEAT
      ApplyTextureAnisotropy(GL_TEXTURE_2D, MipMap);
      Result := True;
    finally
      Bitmap.Free;
    end;
  finally
    Graphic.Free;
  end;
end;

function TTexture.LoadTexDDS(const AFileName: string; MipMap: Boolean;
  const AUniformName: string; internalFormat, param: GLint;
  InvertNormals: Boolean): Boolean;
var
  Width, Height: Integer;
begin
  Name := AUniformName;
  Result := LoadDDS2DTexture(AFileName, MipMap, internalFormat, param,
    InvertNormals, TexID, Width, Height);
end;

{ TMaterialTexture }
function TMaterialTexture.LoadTexTGA(const AFileName: string; MipMap: Boolean; const AUniformName: string; internalFormat, param: GLint; InvertNormals: Boolean): Boolean;
begin
  if Texture.LoadTexTGA(AFileName, MipMap, AUniformName, internalFormat, param, InvertNormals) then
  begin
    Path := AFileName;
    Exit(True);
  end
  else
    Exit(False);
end;

function TMaterialTexture.LoadTexPNG(const AFileName: string; MipMap: Boolean; const AUniformName: string; internalFormat, param: GLint; InvertNormals: Boolean): Boolean;
begin
  if Texture.LoadTexPNG(AFileName, MipMap, AUniformName, internalFormat, param, InvertNormals) then
    begin
      Path := AFileName;
      Exit(True);
    end
  else
    Exit(False);
end;

function TMaterialTexture.LoadTexJPG(const AFileName: string; MipMap: Boolean; const AUniformName: string; internalFormat, param: GLint; InvertNormals: Boolean): Boolean;
begin
  if Texture.LoadTexJPG(AFileName, MipMap, AUniformName, internalFormat, param, InvertNormals) then
    begin
      Path := AFileName;
      Exit(True);
    end
  else
    Exit(False);
end;

function TMaterialTexture.LoadTexDDS(const AFileName: string; MipMap: Boolean;
  const AUniformName: string; internalFormat, param: GLint;
  InvertNormals: Boolean): Boolean;
begin
  if Texture.LoadTexDDS(AFileName, MipMap, AUniformName, internalFormat,
    param, InvertNormals) then
  begin
    Path := AFileName;
    Exit(True);
  end;

  Result := False;
end;

// -----------------------------------------------------------------------------
// TTriplet.Create: constructs a triplet with the three given indices.
// -----------------------------------------------------------------------------
constructor TTriplet.Create(A, B, C: Integer);
begin
  I0 := A;
  I1 := B;
  I2 := C;
end;

{ TAABB }
procedure TAABB.Include(const Point: TVector3);
begin
  if Point.X < Min.X then Min.X := Point.X;
  if Point.Y < Min.Y then Min.Y := Point.Y;
  if Point.Z < Min.Z then Min.Z := Point.Z;
  if Point.X > Max.X then Max.X := Point.X;
  if Point.Y > Max.Y then Max.Y := Point.Y;
  if Point.Z > Max.Z then Max.Z := Point.Z;
end;

procedure TAABB.Include(const Other: TAABB);
begin
  Include(Other.Min);
  Include(Other.Max);
end;

function TAABB.Transform(const Matrix: TMatrix4): TAABB;
var
  Corners: array[0..7] of TVector3;
  i: Integer;
begin
  // 8 corners of the AABB
  Corners[0] := Vector3(Min.X, Min.Y, Min.Z);
  Corners[1] := Vector3(Min.X, Min.Y, Max.Z);
  Corners[2] := Vector3(Min.X, Max.Y, Min.Z);
  Corners[3] := Vector3(Min.X, Max.Y, Max.Z);
  Corners[4] := Vector3(Max.X, Min.Y, Min.Z);
  Corners[5] := Vector3(Max.X, Min.Y, Max.Z);
  Corners[6] := Vector3(Max.X, Max.Y, Min.Z);
  Corners[7] := Vector3(Max.X, Max.Y, Max.Z);

  Result.Min := Vector3(MaxSingle, MaxSingle, MaxSingle);
  Result.Max := Vector3(-MaxSingle, -MaxSingle, -MaxSingle);
  for i := 0 to 7 do
    Result.Include(Vector3(Matrix * Vector4(Corners[i], 1.0)));
end;

function TAABB.Center: TVector3;
begin
  Result := (Min + Max) * 0.5;
end;

function TAABB.Extents: TVector3;
begin
  Result := (Max - Min) * 0.5;
end;

function TAABB.IsValid: Boolean;
begin
  Result := (Min.X <= Max.X) and (Min.Y <= Max.Y) and (Min.Z <= Max.Z);
end;

end.
