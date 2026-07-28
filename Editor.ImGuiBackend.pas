unit Editor.ImGuiBackend;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  Vcl.Controls,
  dglOpenGL,
  PasImGui;

function ImVec2Make(X, Y: Single): ImVec2;

type
  TEditorImGuiBackend = class
  private
    fContext: PImGuiContext;
    fFontTexture: GLuint;
    fShaderHandle: GLuint;
    fVertHandle: GLuint;
    fFragHandle: GLuint;
    fVboHandle: GLuint;
    fElementsHandle: GLuint;
    fVaoHandle: GLuint;
    fAttribLocationTex: GLint;
    fAttribLocationProjMtx: GLint;
    fLastCounter: Int64;
    fCounterFreq: Int64;

    procedure CreateDeviceObjects;
    procedure DestroyDeviceObjects;
    procedure CreateFontsTexture;
    procedure RenderDrawData(DrawData: PImDrawData);
    function VclKeyToImGuiKey(Key: Word): ImGuiKey;
    procedure UpdateModifierKeys;
  public
    constructor Create;
    destructor Destroy; override;

    procedure NewFrame(AWidth, AHeight: Integer);
    procedure Render;

    procedure MouseMove(X, Y: Integer);
    procedure MouseDown(Button: TMouseButton);
    procedure MouseUp(Button: TMouseButton);
    procedure MouseWheel(WheelDelta: Integer);
    procedure KeyDown(Key: Word);
    procedure KeyUp(Key: Word);
    procedure KeyPress(Key: Char);

    function WantCaptureMouse: Boolean;
    function WantCaptureKeyboard: Boolean;
    function MouseOverUi: Boolean;
  end;

implementation

function ImVec2Make(X, Y: Single): ImVec2;
begin
  Result.x := X;
  Result.y := Y;
end;

function OffsetPtr(Offset: NativeUInt): Pointer;
begin
  Result := Pointer(Offset);
end;

function ImDrawListAt(Data: PPImDrawList; Index: Integer): PImDrawList;
begin
  Result := PPImDrawList(NativeUInt(Data) + NativeUInt(Index) * SizeOf(PImDrawList))^;
end;

function ImDrawCmdAt(Data: PImDrawCmd; Index: Integer): PImDrawCmd;
begin
  Result := PImDrawCmd(NativeUInt(Data) + NativeUInt(Index) * SizeOf(ImDrawCmd));
end;

procedure CheckShader(Shader: GLuint; const Name: string);
var
  Status: GLint;
  Len: GLsizei;
  Log: array[0..2047] of AnsiChar;
begin
  Status := 0;
  glGetShaderiv(Shader, GL_COMPILE_STATUS, @Status);
  if Status <> 0 then
    Exit;

  FillChar(Log, SizeOf(Log), 0);
  Len := 0;
  glGetShaderInfoLog(Shader, SizeOf(Log) - 1, @Len, @Log[0]);
  raise Exception.CreateFmt('Dear ImGui %s shader compile failed: %s',
    [Name, string(AnsiString(Log))]);
end;

procedure CheckProgram(ProgramHandle: GLuint);
var
  Status: GLint;
  InfoLen: GLint;
  Len: GLsizei;
  Log: TBytes;
  Msg: string;
  Err: GLenum;
begin
  if ProgramHandle = 0 then
    raise Exception.Create('Dear ImGui shader link failed: glCreateProgram returned 0. The OpenGL context is probably not current.');

  Status := 0;
  glGetProgramiv(ProgramHandle, GL_LINK_STATUS, @Status);
  if Status <> 0 then
    Exit;

  InfoLen := 0;
  glGetProgramiv(ProgramHandle, GL_INFO_LOG_LENGTH, @InfoLen);

  Msg := '';
  if InfoLen > 1 then
  begin
    SetLength(Log, InfoLen + 1);
    FillChar(Log[0], Length(Log), 0);
    Len := 0;
    glGetProgramInfoLog(ProgramHandle, InfoLen, @Len, PAnsiChar(Log));
    Msg := string(AnsiString(PAnsiChar(Log)));
  end;

  Err := glGetError;

  raise Exception.CreateFmt(
    'Dear ImGui shader link failed. Program=%d GL error=$%x InfoLogLength=%d Log=%s',
    [ProgramHandle, Err, InfoLen, Msg]
  );
end;

{ TEditorImGuiBackend }

constructor TEditorImGuiBackend.Create;
var
  IO: PImGuiIO;
begin
  inherited Create;

  fContext := ImGui.CreateContext(nil);
  igSetCurrentContext(fContext);

  IO := ImGui.GetIO;
  IO^.ConfigFlags := IO^.ConfigFlags or ImGuiConfigFlags_NavEnableKeyboard or
    ImGuiConfigFlags_DockingEnable;
  IO^.BackendFlags := IO^.BackendFlags or ImGuiBackendFlags_RendererHasVtxOffset;
  IO^.DisplayFramebufferScale := ImVec2Make(1.0, 1.0);

  { Do not replace GetClipboardTextFn/SetClipboardTextFn here. Dear ImGui
    initializes correct Win32 UTF-8/UTF-16 clipboard handlers when the context
    is created. Keeping those native handlers also avoids crossing the
    Delphi/cimgui callback ABI for every cut/copy/paste operation. }

  QueryPerformanceFrequency(fCounterFreq);
  QueryPerformanceCounter(fLastCounter);

  CreateDeviceObjects;
end;

destructor TEditorImGuiBackend.Destroy;
begin
  if fContext <> nil then
    igSetCurrentContext(fContext);

  DestroyDeviceObjects;

  if fContext <> nil then
  begin
    ImGui.DestroyContext(fContext);
    fContext := nil;
  end;

  inherited Destroy;
end;

procedure TEditorImGuiBackend.CreateDeviceObjects;
const
  // Use the same GLSL style as Dear ImGui's official OpenGL3 backend.
  // It avoids layout(...) qualifiers and works reliably on more drivers/contexts.
  VertexShaderSource: AnsiString =
    '#version 130'#10 +
    'uniform mat4 ProjMtx;'#10 +
    'in vec2 Position;'#10 +
    'in vec2 UV;'#10 +
    'in vec4 Color;'#10 +
    'out vec2 Frag_UV;'#10 +
    'out vec4 Frag_Color;'#10 +
    'void main()'#10 +
    '{'#10 +
    '    Frag_UV = UV;'#10 +
    '    Frag_Color = Color;'#10 +
    '    gl_Position = ProjMtx * vec4(Position.xy, 0, 1);'#10 +
    '}'#10;
  FragmentShaderSource: AnsiString =
    '#version 130'#10 +
    'uniform sampler2D Texture;'#10 +
    'in vec2 Frag_UV;'#10 +
    'in vec4 Frag_Color;'#10 +
    'out vec4 Out_Color;'#10 +
    'void main()'#10 +
    '{'#10 +
    '    Out_Color = Frag_Color * texture(Texture, Frag_UV.st);'#10 +
    '}'#10;
var
  VertexSource: PAnsiChar;
  FragmentSource: PAnsiChar;
  VertexSourceLength: GLint;
  FragmentSourceLength: GLint;
begin
  fVertHandle := glCreateShader(GL_VERTEX_SHADER);
  fFragHandle := glCreateShader(GL_FRAGMENT_SHADER);

  if fVertHandle = 0 then
    raise Exception.Create('Dear ImGui vertex shader creation failed: glCreateShader returned 0.');
  if fFragHandle = 0 then
    raise Exception.Create('Dear ImGui fragment shader creation failed: glCreateShader returned 0.');

  VertexSource := PAnsiChar(VertexShaderSource);
  FragmentSource := PAnsiChar(FragmentShaderSource);
  VertexSourceLength := Length(VertexShaderSource);
  FragmentSourceLength := Length(FragmentShaderSource);
  glShaderSource(fVertHandle, 1, @VertexSource, @VertexSourceLength);
  glShaderSource(fFragHandle, 1, @FragmentSource, @FragmentSourceLength);
  glCompileShader(fVertHandle);
  glCompileShader(fFragHandle);
  CheckShader(fVertHandle, 'vertex');
  CheckShader(fFragHandle, 'fragment');

  fShaderHandle := glCreateProgram;
  if fShaderHandle = 0 then
    raise Exception.Create('Dear ImGui shader program creation failed: glCreateProgram returned 0.');

  glAttachShader(fShaderHandle, fVertHandle);
  glAttachShader(fShaderHandle, fFragHandle);

  // Required because the #version 130 shaders above do not use layout(location=...).
  glBindAttribLocation(fShaderHandle, 0, PAnsiChar(AnsiString('Position')));
  glBindAttribLocation(fShaderHandle, 1, PAnsiChar(AnsiString('UV')));
  glBindAttribLocation(fShaderHandle, 2, PAnsiChar(AnsiString('Color')));

  glLinkProgram(fShaderHandle);
  CheckProgram(fShaderHandle);

  fAttribLocationTex := glGetUniformLocation(fShaderHandle, PAnsiChar(AnsiString('Texture')));
  fAttribLocationProjMtx := glGetUniformLocation(fShaderHandle, PAnsiChar(AnsiString('ProjMtx')));

  glGenBuffers(1, @fVboHandle);
  glGenBuffers(1, @fElementsHandle);
  glGenVertexArrays(1, @fVaoHandle);

  glBindVertexArray(fVaoHandle);
  glBindBuffer(GL_ARRAY_BUFFER, fVboHandle);
  glEnableVertexAttribArray(0);
  glEnableVertexAttribArray(1);
  glEnableVertexAttribArray(2);
  glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, SizeOf(ImDrawVert), OffsetPtr(0));
  glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, SizeOf(ImDrawVert), OffsetPtr(SizeOf(ImVec2)));
  glVertexAttribPointer(2, 4, GL_UNSIGNED_BYTE, GL_TRUE, SizeOf(ImDrawVert), OffsetPtr(SizeOf(ImVec2) * 2));
  glBindVertexArray(0);
  glBindBuffer(GL_ARRAY_BUFFER, 0);

  CreateFontsTexture;
end;

procedure TEditorImGuiBackend.DestroyDeviceObjects;
begin
  if fVaoHandle <> 0 then
  begin
    glDeleteVertexArrays(1, @fVaoHandle);
    fVaoHandle := 0;
  end;

  if fVboHandle <> 0 then
  begin
    glDeleteBuffers(1, @fVboHandle);
    fVboHandle := 0;
  end;

  if fElementsHandle <> 0 then
  begin
    glDeleteBuffers(1, @fElementsHandle);
    fElementsHandle := 0;
  end;

  if fFontTexture <> 0 then
  begin
    glDeleteTextures(1, @fFontTexture);
    fFontTexture := 0;
  end;

  if fShaderHandle <> 0 then
  begin
    if fVertHandle <> 0 then
      glDetachShader(fShaderHandle, fVertHandle);
    if fFragHandle <> 0 then
      glDetachShader(fShaderHandle, fFragHandle);
    glDeleteProgram(fShaderHandle);
    fShaderHandle := 0;
  end;

  if fVertHandle <> 0 then
  begin
    glDeleteShader(fVertHandle);
    fVertHandle := 0;
  end;

  if fFragHandle <> 0 then
  begin
    glDeleteShader(fFragHandle);
    fFragHandle := 0;
  end;
end;

procedure TEditorImGuiBackend.CreateFontsTexture;
var
  IO: PImGuiIO;
  Pixels: PByte;
  Width: Integer;
  Height: Integer;
  BytesPerPixel: Integer;
  LastTexture: GLint;
begin
  IO := ImGui.GetIO;
  Pixels := nil;
  Width := 0;
  Height := 0;
  BytesPerPixel := 0;
  IO^.Fonts^.GetTexDataAsRGBA32(@Pixels, @Width, @Height, @BytesPerPixel);

  LastTexture := 0;
  glGetIntegerv(GL_TEXTURE_BINDING_2D, @LastTexture);

  glGenTextures(1, @fFontTexture);
  glBindTexture(GL_TEXTURE_2D, fFontTexture);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, Width, Height, 0, GL_RGBA,
    GL_UNSIGNED_BYTE, Pixels);

  IO^.Fonts^.SetTexID(Pointer(NativeUInt(fFontTexture)));
  glBindTexture(GL_TEXTURE_2D, LastTexture);
end;

procedure TEditorImGuiBackend.NewFrame(AWidth, AHeight: Integer);
var
  IO: PImGuiIO;
  NowCounter: Int64;
  Delta: Single;
begin
  if fContext = nil then
    Exit;

  igSetCurrentContext(fContext);

  IO := ImGui.GetIO;
  IO^.DisplaySize := ImVec2Make(AWidth, AHeight);

  QueryPerformanceCounter(NowCounter);
  if (fCounterFreq > 0) and (fLastCounter <> 0) then
    Delta := (NowCounter - fLastCounter) / fCounterFreq
  else
    Delta := 1.0 / 60.0;
  fLastCounter := NowCounter;

  if Delta <= 0 then
    Delta := 1.0 / 60.0;
  IO^.DeltaTime := Delta;

  ImGui.NewFrame;
end;

procedure TEditorImGuiBackend.Render;
begin
  if fContext = nil then
    Exit;

  igSetCurrentContext(fContext);
  ImGui.Render;
  RenderDrawData(ImGui.GetDrawData);
end;

procedure TEditorImGuiBackend.RenderDrawData(DrawData: PImDrawData);
var
  FBWidth: Integer;
  FBHeight: Integer;
  LastActiveTexture: GLint;
  LastProgram: GLint;
  LastTexture: GLint;
  LastArrayBuffer: GLint;
  LastElementArrayBuffer: GLint;
  LastVertexArray: GLint;
  LastViewport: array[0..3] of GLint;
  LastScissorBox: array[0..3] of GLint;
  LastBlendEnabled: GLboolean;
  LastCullEnabled: GLboolean;
  LastDepthEnabled: GLboolean;
  LastScissorEnabled: GLboolean;
  L, R, T, B: Single;
  OrthoProjection: array[0..15] of Single;
  ClipOff: ImVec2;
  ClipScale: ImVec2;
  CmdList: PImDrawList;
  Cmd: PImDrawCmd;
  N: Integer;
  CmdIndex: Integer;
  ClipMinX: Single;
  ClipMinY: Single;
  ClipMaxX: Single;
  ClipMaxY: Single;
  TextureHandle: GLuint;
begin
  if (DrawData = nil) or (not DrawData^.Valid) then
    Exit;

  FBWidth := Trunc(DrawData^.DisplaySize.x * DrawData^.FramebufferScale.x);
  FBHeight := Trunc(DrawData^.DisplaySize.y * DrawData^.FramebufferScale.y);
  if (FBWidth <= 0) or (FBHeight <= 0) then
    Exit;

  LastActiveTexture := 0;
  LastProgram := 0;
  LastTexture := 0;
  LastArrayBuffer := 0;
  LastElementArrayBuffer := 0;
  LastVertexArray := 0;

  glGetIntegerv(GL_ACTIVE_TEXTURE, @LastActiveTexture);
  glActiveTexture(GL_TEXTURE0);
  glGetIntegerv(GL_CURRENT_PROGRAM, @LastProgram);
  glGetIntegerv(GL_TEXTURE_BINDING_2D, @LastTexture);
  glGetIntegerv(GL_ARRAY_BUFFER_BINDING, @LastArrayBuffer);
  glGetIntegerv(GL_ELEMENT_ARRAY_BUFFER_BINDING, @LastElementArrayBuffer);
  glGetIntegerv(GL_VERTEX_ARRAY_BINDING, @LastVertexArray);
  glGetIntegerv(GL_VIEWPORT, @LastViewport[0]);
  glGetIntegerv(GL_SCISSOR_BOX, @LastScissorBox[0]);
  LastBlendEnabled := glIsEnabled(GL_BLEND);
  LastCullEnabled := glIsEnabled(GL_CULL_FACE);
  LastDepthEnabled := glIsEnabled(GL_DEPTH_TEST);
  LastScissorEnabled := glIsEnabled(GL_SCISSOR_TEST);

  glEnable(GL_BLEND);
  glBlendEquation(GL_FUNC_ADD);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  glDisable(GL_CULL_FACE);
  glDisable(GL_DEPTH_TEST);
  glEnable(GL_SCISSOR_TEST);
  glViewport(0, 0, FBWidth, FBHeight);

  L := DrawData^.DisplayPos.x;
  R := DrawData^.DisplayPos.x + DrawData^.DisplaySize.x;
  T := DrawData^.DisplayPos.y;
  B := DrawData^.DisplayPos.y + DrawData^.DisplaySize.y;

  OrthoProjection[0] := 2.0 / (R - L);
  OrthoProjection[1] := 0.0;
  OrthoProjection[2] := 0.0;
  OrthoProjection[3] := 0.0;
  OrthoProjection[4] := 0.0;
  OrthoProjection[5] := 2.0 / (T - B);
  OrthoProjection[6] := 0.0;
  OrthoProjection[7] := 0.0;
  OrthoProjection[8] := 0.0;
  OrthoProjection[9] := 0.0;
  OrthoProjection[10] := -1.0;
  OrthoProjection[11] := 0.0;
  OrthoProjection[12] := (R + L) / (L - R);
  OrthoProjection[13] := (T + B) / (B - T);
  OrthoProjection[14] := 0.0;
  OrthoProjection[15] := 1.0;

  glUseProgram(fShaderHandle);
  glUniform1i(fAttribLocationTex, 0);
  glUniformMatrix4fv(fAttribLocationProjMtx, 1, GL_FALSE, @OrthoProjection[0]);
  glBindVertexArray(fVaoHandle);

  ClipOff := DrawData^.DisplayPos;
  ClipScale := DrawData^.FramebufferScale;

  for N := 0 to DrawData^.CmdListsCount - 1 do
  begin
    CmdList := ImDrawListAt(DrawData^.CmdLists.Data, N);

    glBindBuffer(GL_ARRAY_BUFFER, fVboHandle);
    glBufferData(GL_ARRAY_BUFFER, CmdList^.VtxBuffer.Size * SizeOf(ImDrawVert),
      CmdList^.VtxBuffer.Data, GL_STREAM_DRAW);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, fElementsHandle);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, CmdList^.IdxBuffer.Size * SizeOf(ImDrawIdx),
      CmdList^.IdxBuffer.Data, GL_STREAM_DRAW);

    for CmdIndex := 0 to CmdList^.CmdBuffer.Size - 1 do
    begin
      Cmd := ImDrawCmdAt(CmdList^.CmdBuffer.Data, CmdIndex);
      if Assigned(Cmd^.UserCallback) then
      begin
        Cmd^.UserCallback(CmdList, Cmd);
        Continue;
      end;

      ClipMinX := (Cmd^.ClipRect.x - ClipOff.x) * ClipScale.x;
      ClipMinY := (Cmd^.ClipRect.y - ClipOff.y) * ClipScale.y;
      ClipMaxX := (Cmd^.ClipRect.z - ClipOff.x) * ClipScale.x;
      ClipMaxY := (Cmd^.ClipRect.w - ClipOff.y) * ClipScale.y;

      if (ClipMaxX <= ClipMinX) or (ClipMaxY <= ClipMinY) then
        Continue;

      glScissor(Trunc(ClipMinX), Trunc(FBHeight - ClipMaxY),
        Trunc(ClipMaxX - ClipMinX), Trunc(ClipMaxY - ClipMinY));

      TextureHandle := GLuint(NativeUInt(Cmd^.TextureId));
      glBindTexture(GL_TEXTURE_2D, TextureHandle);

      glDrawElementsBaseVertex(GL_TRIANGLES, Cmd^.ElemCount, GL_UNSIGNED_SHORT,
        OffsetPtr(NativeUInt(Cmd^.IdxOffset) * SizeOf(ImDrawIdx)), Cmd^.VtxOffset);
    end;
  end;

  glUseProgram(LastProgram);
  glBindTexture(GL_TEXTURE_2D, LastTexture);
  glActiveTexture(LastActiveTexture);
  glBindVertexArray(LastVertexArray);
  glBindBuffer(GL_ARRAY_BUFFER, LastArrayBuffer);
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, LastElementArrayBuffer);
  glViewport(LastViewport[0], LastViewport[1], LastViewport[2], LastViewport[3]);
  glScissor(LastScissorBox[0], LastScissorBox[1], LastScissorBox[2], LastScissorBox[3]);

  if LastBlendEnabled = GL_TRUE then glEnable(GL_BLEND) else glDisable(GL_BLEND);
  if LastCullEnabled = GL_TRUE then glEnable(GL_CULL_FACE) else glDisable(GL_CULL_FACE);
  if LastDepthEnabled = GL_TRUE then glEnable(GL_DEPTH_TEST) else glDisable(GL_DEPTH_TEST);
  if LastScissorEnabled = GL_TRUE then glEnable(GL_SCISSOR_TEST) else glDisable(GL_SCISSOR_TEST);
end;

procedure TEditorImGuiBackend.MouseMove(X, Y: Integer);
begin
  if fContext = nil then
    Exit;
  igSetCurrentContext(fContext);
  ImGui.AddMousePosEvent(X, Y);
end;

procedure TEditorImGuiBackend.MouseDown(Button: TMouseButton);
var
  B: Integer;
begin
  if fContext = nil then
    Exit;

  case Button of
    mbLeft: B := 0;
    mbRight: B := 1;
    mbMiddle: B := 2;
  else
    Exit;
  end;

  igSetCurrentContext(fContext);
  ImGui.AddMouseButtonEvent(B, True);
end;

procedure TEditorImGuiBackend.MouseUp(Button: TMouseButton);
var
  B: Integer;
begin
  if fContext = nil then
    Exit;

  case Button of
    mbLeft: B := 0;
    mbRight: B := 1;
    mbMiddle: B := 2;
  else
    Exit;
  end;

  igSetCurrentContext(fContext);
  ImGui.AddMouseButtonEvent(B, False);
end;

procedure TEditorImGuiBackend.MouseWheel(WheelDelta: Integer);
begin
  if fContext = nil then
    Exit;
  igSetCurrentContext(fContext);
  ImGui.AddMouseWheelEvent(0, WheelDelta / WHEEL_DELTA);
end;

function TEditorImGuiBackend.VclKeyToImGuiKey(Key: Word): ImGuiKey;
begin
  Result := ImGuiKey_None;

  case Key of
    VK_TAB: Result := ImGuiKey_Tab;
    VK_LEFT: Result := ImGuiKey_LeftArrow;
    VK_RIGHT: Result := ImGuiKey_RightArrow;
    VK_UP: Result := ImGuiKey_UpArrow;
    VK_DOWN: Result := ImGuiKey_DownArrow;
    VK_PRIOR: Result := ImGuiKey_PageUp;
    VK_NEXT: Result := ImGuiKey_PageDown;
    VK_HOME: Result := ImGuiKey_Home;
    VK_END: Result := ImGuiKey_End;
    VK_INSERT: Result := ImGuiKey_Insert;
    VK_DELETE: Result := ImGuiKey_Delete;
    VK_BACK: Result := ImGuiKey_Backspace;
    VK_SPACE: Result := ImGuiKey_Space;
    VK_RETURN: Result := ImGuiKey_Enter;
    VK_ESCAPE: Result := ImGuiKey_Escape;
    VK_CONTROL: Result := ImGuiKey_LeftCtrl;
    VK_SHIFT: Result := ImGuiKey_LeftShift;
    VK_MENU: Result := ImGuiKey_LeftAlt;
    VK_F1..VK_F12: Result := ImGuiKey_F1 + (Key - VK_F1);
  else
    if (Key >= Ord('0')) and (Key <= Ord('9')) then
      Result := ImGuiKey_0 + (Key - Ord('0'))
    else if (Key >= Ord('A')) and (Key <= Ord('Z')) then
      Result := ImGuiKey_A + (Key - Ord('A'));
  end;
end;

procedure TEditorImGuiBackend.UpdateModifierKeys;
var
  CtrlDown: Boolean;
  ShiftDown: Boolean;
  AltDown: Boolean;
begin
  CtrlDown := GetKeyState(VK_CONTROL) < 0;
  ShiftDown := GetKeyState(VK_SHIFT) < 0;
  AltDown := GetKeyState(VK_MENU) < 0;

  { InputText handles Ctrl+X/C/V itself. Feed only the standard modifier
    events expected by the current Dear ImGui API; no editor callback or
    direct manipulation of ImGuiInputTextCallbackData is required. }
  ImGui.AddKeyEvent(ImGuiMod_Ctrl, CtrlDown);
  ImGui.AddKeyEvent(ImGuiMod_Shift, ShiftDown);
  ImGui.AddKeyEvent(ImGuiMod_Alt, AltDown);
  ImGui.AddKeyEvent(ImGuiMod_Super, False);
end;

procedure TEditorImGuiBackend.KeyDown(Key: Word);
var
  ImKey: ImGuiKey;
begin
  if fContext = nil then
    Exit;
  igSetCurrentContext(fContext);
  UpdateModifierKeys;
  ImKey := VclKeyToImGuiKey(Key);
  if ImKey <> ImGuiKey_None then
    ImGui.AddKeyEvent(ImKey, True);
end;

procedure TEditorImGuiBackend.KeyUp(Key: Word);
var
  ImKey: ImGuiKey;
begin
  if fContext = nil then
    Exit;
  igSetCurrentContext(fContext);
  UpdateModifierKeys;
  ImKey := VclKeyToImGuiKey(Key);
  if ImKey <> ImGuiKey_None then
    ImGui.AddKeyEvent(ImKey, False);
end;

procedure TEditorImGuiBackend.KeyPress(Key: Char);
var
  S: UTF8String;
begin
  if fContext = nil then
    Exit;
  if Key < #32 then
    Exit;

  igSetCurrentContext(fContext);
  S := UTF8String(string(Key));
  ImGui.AddInputCharactersUTF8(AnsiString(S));
end;

function TEditorImGuiBackend.WantCaptureMouse: Boolean;
begin
  Result := False;
  if fContext = nil then
    Exit;
  igSetCurrentContext(fContext);
  Result := ImGui.GetIO^.WantCaptureMouse;
end;

function TEditorImGuiBackend.WantCaptureKeyboard: Boolean;
begin
  Result := False;
  if fContext = nil then
    Exit;
  igSetCurrentContext(fContext);
  Result := ImGui.GetIO^.WantCaptureKeyboard;
end;

function TEditorImGuiBackend.MouseOverUi: Boolean;
begin
  Result := False;
  if fContext = nil then
    Exit;

  igSetCurrentContext(fContext);

  // WantCaptureMouse is the official app-level test.
  // The hovered/active checks make first-click window moving/resizing more reliable
  // when VCL delivers MouseDown before the next ImGui NewFrame.
  Result := ImGui.GetIO^.WantCaptureMouse or
    ImGui.IsWindowHovered(ImGuiHoveredFlags_AnyWindow) or
    ImGui.IsAnyItemHovered or
    ImGui.IsAnyItemActive;
end;

end.
