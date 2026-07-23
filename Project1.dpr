program Project1;

uses
  Vcl.Forms,
  MainUnit in 'MainUnit.pas' {MainForm},
  Engine in 'Engine.pas',
  SandBox in 'SandBox.pas',
  dglOpenGL in 'dglOpenGL.pas',
  Renderer.Mesh in 'Renderer.Mesh.pas',
  Renderer.Particles in 'Renderer.Particles.pas',
  Renderer.SkyDome in 'Renderer.SkyDome.pas',
  Renderer.Shader in 'Renderer.Shader.pas',
  Engine.Generators in 'Engine.Generators.pas',
  Renderer.Camera in 'Renderer.Camera.pas',
  Renderer.Light in 'Renderer.Light.pas',
  Managers.Scene in 'Managers.Scene.pas',
  Managers.Material in 'Managers.Material.pas',
  Renderer.Renderer in 'Renderer.Renderer.pas',
  Utility.Functions in 'Utility.Functions.pas',
  Loader.OBJ in 'Loader.OBJ.pas',
  Loader.GLTF in 'Loader.GLTF.pas',
  PasGLTF in 'PasGLTF.pas',
  PasJSON in 'PasJSON.pas',
  Engine.Time in 'Engine.Time.pas',
  Engine.Keyboard in 'Engine.Keyboard.pas',
  Engine.Mouse in 'Engine.Mouse.pas',
  Engine.Wind in 'Engine.Wind.pas',
  Engine.Scripting in 'Engine.Scripting.pas',
  Renderer.Mesh.Factory in 'Renderer.Mesh.Factory.pas',
  Renderer.Mesh.List in 'Renderer.Mesh.List.pas',
  DWS.FastMath in 'DWS.FastMath.pas',
  Physics.Geometry in 'Physics.Geometry.pas',
  Physics.Engine in 'Physics.Engine.pas',
  Physics.Math in 'Physics.Math.pas',
  Physics.Settings in 'Physics.Settings.pas',
  Renderer.RenderTechnique in 'Renderer.RenderTechnique.pas',
  Engine.Paths in 'Engine.Paths.pas',
  Editor.ImGuiBackend in 'Editor.ImGuiBackend.pas',
  PasImGui in 'PasImGui.pas',
  Engine.Types in 'Engine.Types.pas',
  Engine.Physics in 'Engine.Physics.pas',
  Engine.Audio in 'Engine.Audio.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
