unit Editor.Gizmos;

interface

uses
  dglOpenGL, Neslib.FastMath, Renderer.Shader;

type
  T3DGrid = class
  private
    fShader: TShader;
    fVAO: GLuint;
    fVBO: GLuint;
    fEnabled: Boolean;
    procedure CreateGeometry;
    procedure DestroyGeometry;
  public
    constructor Create(const AVertexFileName, AFragmentFileName: string);
    destructor Destroy; override;
    procedure Render(const AView, AProjection: TMatrix4;
      const ACameraPosition: TVector3);
    property Enabled: Boolean read fEnabled write fEnabled;
  end;

implementation

uses
  System.SysUtils;

{ T3DGrid }

constructor T3DGrid.Create(const AVertexFileName, AFragmentFileName: string);
begin
  inherited Create;
  fVAO := 0;
  fVBO := 0;
  fEnabled := True;
  fShader := TShader.Create(AVertexFileName, AFragmentFileName);
  CreateGeometry;
end;

destructor T3DGrid.Destroy;
begin
  DestroyGeometry;
  FreeAndNil(fShader);
  inherited Destroy;
end;

procedure T3DGrid.CreateGeometry;
const
  Vertices: array[0..17] of GLfloat = (
    -1.0, -1.0, 0.0,
     1.0, -1.0, 0.0,
     1.0,  1.0, 0.0,
    -1.0, -1.0, 0.0,
     1.0,  1.0, 0.0,
    -1.0,  1.0, 0.0
  );
begin
  glGenVertexArrays(1, @fVAO);
  glGenBuffers(1, @fVBO);

  glBindVertexArray(fVAO);
  try
    glBindBuffer(GL_ARRAY_BUFFER, fVBO);
    glBufferData(GL_ARRAY_BUFFER, SizeOf(Vertices), @Vertices[0],
      GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE,
      3 * SizeOf(GLfloat), nil);
  finally
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
  end;
end;

procedure T3DGrid.DestroyGeometry;
begin
  if fVBO <> 0 then
  begin
    glDeleteBuffers(1, @fVBO);
    fVBO := 0;
  end;

  if fVAO <> 0 then
  begin
    glDeleteVertexArrays(1, @fVAO);
    fVAO := 0;
  end;
end;

procedure T3DGrid.Render(const AView, AProjection: TMatrix4;
  const ACameraPosition: TVector3);
var
  OldDepthFunc: GLint;
  OldDepthMask: GLboolean;
  OldDepthTestEnabled: GLboolean;
  OldCullEnabled: GLboolean;
  OldBlendEnabled: GLboolean;
  OldBlendSrcRGB: GLint;
  OldBlendDstRGB: GLint;
  OldBlendSrcAlpha: GLint;
  OldBlendDstAlpha: GLint;
begin
  if (not fEnabled) or (fShader = nil) or (fVAO = 0) then
    Exit;

  glGetIntegerv(GL_DEPTH_FUNC, @OldDepthFunc);
  glGetBooleanv(GL_DEPTH_WRITEMASK, @OldDepthMask);
  OldDepthTestEnabled := glIsEnabled(GL_DEPTH_TEST);
  OldCullEnabled := glIsEnabled(GL_CULL_FACE);
  OldBlendEnabled := glIsEnabled(GL_BLEND);
  glGetIntegerv(GL_BLEND_SRC_RGB, @OldBlendSrcRGB);
  glGetIntegerv(GL_BLEND_DST_RGB, @OldBlendDstRGB);
  glGetIntegerv(GL_BLEND_SRC_ALPHA, @OldBlendSrcAlpha);
  glGetIntegerv(GL_BLEND_DST_ALPHA, @OldBlendDstAlpha);

  try
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
    glDepthMask(GL_TRUE);
    glDisable(GL_CULL_FACE);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    fShader.Use;
    fShader.SetUniform('view', AView);
    fShader.SetUniform('projection', AProjection);
    fShader.SetUniform('cameraPosition', ACameraPosition);

    glBindVertexArray(fVAO);
    glDrawArrays(GL_TRIANGLES, 0, 6);
  finally
    glBindVertexArray(0);
    glUseProgram(0);
    glDepthFunc(OldDepthFunc);
    glDepthMask(OldDepthMask);

    if OldDepthTestEnabled = GL_TRUE then
      glEnable(GL_DEPTH_TEST)
    else
      glDisable(GL_DEPTH_TEST);

    if OldCullEnabled = GL_TRUE then
      glEnable(GL_CULL_FACE)
    else
      glDisable(GL_CULL_FACE);

    if OldBlendEnabled = GL_TRUE then
      glEnable(GL_BLEND)
    else
      glDisable(GL_BLEND);

    glBlendFuncSeparate(GLenum(OldBlendSrcRGB), GLenum(OldBlendDstRGB),
      GLenum(OldBlendSrcAlpha), GLenum(OldBlendDstAlpha));
  end;
end;


end.