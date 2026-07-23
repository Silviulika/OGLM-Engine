unit Renderer.Shader;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  System.Generics.Collections, dglOpenGL, GraphicEx, Neslib.FastMath;

type
  TShader = class;

  TOnUpdateShader = procedure(Shader: TShader) of object;

  TShader = class
  private
    fProgram: GLuint;
    fOnUpdateShader: TOnUpdateShader;

    fVertexPath: string;
    fFragmentPath: string;

    fUniformLocations: TDictionary<string, GLint>;

    function LoadTextFileUTF8(const AFileName: string): string;
    function CompileShader(ShaderType: GLenum; const Source, SourceName: string): GLuint;
    function LinkProgram(VertexShader, FragmentShader: GLuint): GLuint;

    function GetShaderTypeName(ShaderType: GLenum): string;
    //function GetShaderInfoLog(Shader: GLuint): string;
    function GetProgramInfoLog(ProgramID: GLuint): string;

    procedure ClearUniformCache;

  public
    constructor Create(const AVertexFileName: string; const AFragmentFileName: string);
    destructor Destroy; override;

    //function GetShaderTypeName(ShaderType: GLenum): string;
    function GetShaderInfoLog(Shader: GLuint): string;

    procedure Reload;

    procedure Use;
    class procedure Unuse; static;

    function GetUniformLocation(const Name: string): GLint;

    procedure SetUniform(const Name: string; Value: Boolean); overload;
    procedure SetUniform(const Name: string; Value: GLint); overload;
    procedure SetUniform(const Name: string; Value: GLuint); overload;
    procedure SetUniform(const Name: string; Value: GLfloat); overload;

    procedure SetUniform(const Name: string; X, Y: GLfloat); overload;
    procedure SetUniform(const Name: string; X, Y, Z: GLfloat); overload;
    procedure SetUniform(const Name: string; X, Y, Z, W: GLfloat); overload;

    procedure SetUniform(const Name: string; const Value: TVector2); overload;
    procedure SetUniform(const Name: string; const Value: TVector3); overload;
    procedure SetUniform(const Name: string; const Value: TVector4); overload;
    procedure SetUniform(const Name: string; const Value: TMatrix3); overload;
    procedure SetUniform(const Name: string; const Value: TMatrix4); overload;

    procedure SetTexture(const UniformName: string; TextureUnit: GLint; TextureTarget: GLenum; TextureID: GLuint);

    procedure UpdateUniforms;

    property ProgramID: GLuint read fProgram;
    property OnUpdateShader: TOnUpdateShader read fOnUpdateShader write fOnUpdateShader;

    property VertexPath: string read fVertexPath;
    property FragmentPath: string read fFragmentPath;
  end;

implementation

constructor TShader.Create(const AVertexFileName, AFragmentFileName: string);
begin
  inherited Create;

  fProgram := 0;
  fVertexPath := AVertexFileName;
  fFragmentPath := AFragmentFileName;
  fUniformLocations := TDictionary<string, GLint>.Create;

  Reload;
end;

destructor TShader.Destroy;
begin
  ClearUniformCache;
  fUniformLocations.Free;

  if fProgram <> 0 then
  begin
    glDeleteProgram(fProgram);
    fProgram := 0;
  end;

  inherited Destroy;
end;

procedure TShader.ClearUniformCache;
begin
  if Assigned(fUniformLocations) then
    fUniformLocations.Clear;
end;

function TShader.LoadTextFileUTF8(const AFileName: string): string;
var
  Lines: TStringList;
begin
  if not FileExists(AFileName) then
    raise Exception.Create('Shader file not found: ' + AFileName);

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(AFileName, TEncoding.UTF8);
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

function TShader.GetShaderTypeName(ShaderType: GLenum): string;
begin
  case ShaderType of
    GL_VERTEX_SHADER:
      Result := 'vertex';
    GL_FRAGMENT_SHADER:
      Result := 'fragment';
    GL_GEOMETRY_SHADER:
      Result := 'geometry';
  else
    Result := 'unknown';
  end;
end;

function TShader.GetShaderInfoLog(Shader: GLuint): string;
var
  Len: GLint;
  Log: TBytes;
begin
  Result := '';

  glGetShaderiv(Shader, GL_INFO_LOG_LENGTH, @Len);

  if Len <= 1 then
    Exit;

  SetLength(Log, Len);
  glGetShaderInfoLog(Shader, Len, nil, PAnsiChar(Log));

  Result := string(AnsiString(PAnsiChar(Log)));
end;

function TShader.GetProgramInfoLog(ProgramID: GLuint): string;
var
  Len: GLint;
  Log: TBytes;
begin
  Result := '';

  glGetProgramiv(ProgramID, GL_INFO_LOG_LENGTH, @Len);

  if Len <= 1 then
    Exit;

  SetLength(Log, Len);
  glGetProgramInfoLog(ProgramID, Len, nil, PAnsiChar(Log));

  Result := string(AnsiString(PAnsiChar(Log)));
end;

function TShader.CompileShader(ShaderType: GLenum; const Source, SourceName: string): GLuint;
var
  Shader: GLuint;
  Success: GLint;
  AnsiSource: UTF8String;
  PSource: PAnsiChar;
  SourceLength: GLint;
  InfoLog: string;
begin
  Shader := glCreateShader(ShaderType);

  if Shader = 0 then
    raise Exception.Create('Could not create ' + GetShaderTypeName(ShaderType) + ' shader.');

  AnsiSource := UTF8String(Source);
  PSource := PAnsiChar(AnsiSource);
  SourceLength := Length(AnsiSource);

  glShaderSource(Shader, 1, @PSource, @SourceLength);
  glCompileShader(Shader);

  glGetShaderiv(Shader, GL_COMPILE_STATUS, @Success);

  if Success = 0 then
  begin
    InfoLog := GetShaderInfoLog(Shader);
    glDeleteShader(Shader);

    raise Exception.CreateFmt(
      'Shader compile error in %s shader:'#13#10'%s'#13#10'%s',
      [GetShaderTypeName(ShaderType), SourceName, InfoLog]
    );
  end;

  Result := Shader;
end;

function TShader.LinkProgram(VertexShader, FragmentShader: GLuint): GLuint;
var
  ProgramID: GLuint;
  Success: GLint;
  InfoLog: string;
begin
  ProgramID := glCreateProgram;

  if ProgramID = 0 then
    raise Exception.Create('Could not create shader program.');

  glAttachShader(ProgramID, VertexShader);
  glAttachShader(ProgramID, FragmentShader);

  glLinkProgram(ProgramID);

  glGetProgramiv(ProgramID, GL_LINK_STATUS, @Success);

  if Success = 0 then
  begin
    InfoLog := GetProgramInfoLog(ProgramID);
    glDeleteProgram(ProgramID);

    raise Exception.CreateFmt(
      'Shader link error:'#13#10'Vertex: %s'#13#10'Fragment: %s'#13#10'%s',
      [fVertexPath, fFragmentPath, InfoLog]
    );
  end;

  Result := ProgramID;
end;

procedure TShader.Reload;
var
  VS: GLuint;
  FS: GLuint;
  NewProgram: GLuint;
  VertexSource: string;
  FragmentSource: string;
begin
  VS := 0;
  FS := 0;
  NewProgram := 0;

  VertexSource := LoadTextFileUTF8(fVertexPath);
  FragmentSource := LoadTextFileUTF8(fFragmentPath);

  try
    VS := CompileShader(GL_VERTEX_SHADER, VertexSource, fVertexPath);
    FS := CompileShader(GL_FRAGMENT_SHADER, FragmentSource, fFragmentPath);

    NewProgram := LinkProgram(VS, FS);

    if fProgram <> 0 then
      glDeleteProgram(fProgram);

    fProgram := NewProgram;
    NewProgram := 0;

    ClearUniformCache;
  finally
    if VS <> 0 then
      glDeleteShader(VS);

    if FS <> 0 then
      glDeleteShader(FS);

    if NewProgram <> 0 then
      glDeleteProgram(NewProgram);
  end;
end;

procedure TShader.Use;
begin
  if fProgram <> 0 then
    glUseProgram(fProgram);
end;

class procedure TShader.Unuse;
begin
  glUseProgram(0);
end;

function TShader.GetUniformLocation(const Name: string): GLint;
begin
  if fUniformLocations.TryGetValue(Name, Result) then
    Exit;

  Result := glGetUniformLocation(fProgram, PAnsiChar(AnsiString(Name)));

  fUniformLocations.Add(Name, Result);
end;

procedure TShader.SetUniform(const Name: string; Value: Boolean);
begin
  SetUniform(Name, GLint(Ord(Value)));
end;

procedure TShader.SetUniform(const Name: string; Value: GLint);
var
  Loc: GLint;
begin
  Loc := GetUniformLocation(Name);

  if Loc <> -1 then
    glUniform1i(Loc, Value);
end;

procedure TShader.SetUniform(const Name: string; Value: GLuint);
var
  Loc: GLint;
begin
  Loc := GetUniformLocation(Name);

  if Loc <> -1 then
    glUniform1ui(Loc, Value);
end;

procedure TShader.SetUniform(const Name: string; Value: GLfloat);
var
  Loc: GLint;
begin
  Loc := GetUniformLocation(Name);

  if Loc <> -1 then
    glUniform1f(Loc, Value);
end;

procedure TShader.SetUniform(const Name: string; X, Y: GLfloat);
var
  Loc: GLint;
begin
  Loc := GetUniformLocation(Name);

  if Loc <> -1 then
    glUniform2f(Loc, X, Y);
end;

procedure TShader.SetUniform(const Name: string; X, Y, Z: GLfloat);
var
  Loc: GLint;
begin
  Loc := GetUniformLocation(Name);

  if Loc <> -1 then
    glUniform3f(Loc, X, Y, Z);
end;

procedure TShader.SetUniform(const Name: string; X, Y, Z, W: GLfloat);
var
  Loc: GLint;
begin
  Loc := GetUniformLocation(Name);

  if Loc <> -1 then
    glUniform4f(Loc, X, Y, Z, W);
end;

procedure TShader.SetUniform(const Name: string; const Value: TVector2);
begin
  SetUniform(Name, Value.X, Value.Y);
end;

procedure TShader.SetUniform(const Name: string; const Value: TVector3);
begin
  SetUniform(Name, Value.X, Value.Y, Value.Z);
end;

procedure TShader.SetUniform(const Name: string; const Value: TVector4);
begin
  SetUniform(Name, Value.X, Value.Y, Value.Z, Value.W);
end;

procedure TShader.SetUniform(const Name: string; const Value: TMatrix3);
var
  Loc: GLint;
begin
  Loc := GetUniformLocation(Name);

  if Loc <> -1 then
    glUniformMatrix3fv(Loc, 1, GL_FALSE, @Value);
end;

procedure TShader.SetUniform(const Name: string; const Value: TMatrix4);
var
  Loc: GLint;
begin
  Loc := GetUniformLocation(Name);

  if Loc <> -1 then
    glUniformMatrix4fv(Loc, 1, GL_FALSE, @Value);
end;

procedure TShader.SetTexture(const UniformName: string; TextureUnit: GLint;
  TextureTarget: GLenum; TextureID: GLuint);
begin
  glActiveTexture(GL_TEXTURE0 + TextureUnit);
  glBindTexture(TextureTarget, TextureID);
  SetUniform(UniformName, TextureUnit);
end;

procedure TShader.UpdateUniforms;
begin
  if Assigned(fOnUpdateShader) then
    fOnUpdateShader(Self);
end;

end.
