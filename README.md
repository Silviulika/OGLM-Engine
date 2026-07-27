# OpenGL Micro Engine

OpenGL Micro Engine is a Delphi real-time 3D engine and editor built on
OpenGL. The repository contains two closely related parts:

- **Engine**: rendering, scenes, materials, physics, audio, GUI controls,
  serialization, and DWScript scripting.
- **SandBox**: the VCL and Dear ImGui editor used to inspect and edit Engine
  scenes and assets.

The engine includes cameras, lights, glTF/OBJ loading, PBR materials, terrain,
water, animated meshes, particles, billboards, grass and tree wind, physics,
audio emitters, prefabs, runtime GUI controls, and DWScript integration.

## Supported Build

The currently tested configuration is:

- Windows 10 or Windows 11, 64-bit
- Embarcadero Delphi 12 Athens
- Delphi Win64 compiler version 36.0
- VCL application platform
- `Release | Win64` or `Debug | Win64`
- A graphics driver supporting OpenGL 4.5 and GLSL 4.50

The project contains Win32 configurations, but this guide uses Win64
throughout. Download or build Win64 versions of all native runtime libraries.

## Required Software

Install these Delphi features using the RAD Studio installer:

1. Delphi 12.
2. Windows 64-bit application development.
3. VCL.
4. The Windows SDK selected by the Delphi installer.

No third-party Delphi design-time package needs to be installed in the IDE.
The engine builds the required Pascal dependencies directly from source after
you download them. Third-party source and binaries are not distributed with
the Engine repository.

GLScene is **not** required. Some old package names remain in the generated
`.dproj` package list, but active Engine and SandBox units do not use GLScene.

## Dependencies

None of the following third-party dependencies are included. Download each
one from its upstream project and retain its license and notices.

| Dependency | Download | Local location used by this guide |
| --- | --- | --- |
| DWScript | [Official Bitbucket repository](https://bitbucket.org/egrange/dwscript/) | `External\DWScript\Source` |
| Neslib.FastMath | [GitHub repository](https://github.com/neslib/FastMath) | The folder containing `Neslib.FastMath.pas` |
| Kraft physics | [GitHub repository](https://github.com/BeRo1985/kraft) | `External\kraft\src` |
| PasMP | [GitHub repository](https://github.com/BeRo1985/pasmp) | `External\pasmp\src` |
| GraphicEx and DelphiZlib | [GitHub repository](https://github.com/mike-lischke/GraphicEx) | `External\GraphicEx` and its `3rd party\DelphiZlib` folder |
| ImGui-Pascal | [GitHub repository](https://github.com/Coldzer0/ImGui-Pascal) | `External\ImGui-Pascal\src` |
| cimgui / Dear ImGui | [cimgui](https://github.com/cimgui/cimgui) and [Dear ImGui](https://github.com/ocornut/imgui) | Win64 `cimgui.dll` beside the EXE |
| BASS | [Official BASS download](https://www.un4seen.com/bass.html) | Delphi API source plus Win64 `bass.dll` |
| dglOpenGL | [GitHub repository](https://github.com/SaschaWillems/dglOpenGL) | `dglOpenGL.pas` in the project root |
| PasGLTF | [GitHub repository](https://github.com/BeRo1985/pasgltf) | `PasGLTF.pas` in the project root |
| PasJSON | [GitHub repository](https://github.com/BeRo1985/pasjson) | `PasJSON.pas` in the project root |

GraphicEx's upstream repository contains its required DelphiZlib sources under
`3rd party\DelphiZlib`; DelphiZlib is not a separate download. BASS provides
both the Delphi declarations and native DLL from its Windows download.

The Engine's current ImGui integration targets Dear ImGui 1.91.0. Use an
ImGui-Pascal revision and Win64 `cimgui.dll` built from the same cimgui/Dear
ImGui API version. Mixing binding and DLL versions can compile successfully
but fail at startup or while rendering the editor.

## Build The SandBox

### 1. Get The Engine Source

The Engine checkout must include at least:

```text
Data\
GuiEditor\
MaterialEditor\
OGLM_SandBox.dpr
OGLM_SandBox.dproj
```

The `External` directory, dependency units, `bass.dll`, and `cimgui.dll` are
not part of the checkout. The following steps create that local setup.

### 2. Download The Pascal Dependencies

Download the libraries from the links in [Dependencies](#dependencies). For
the project paths already stored in `OGLM_SandBox.dproj`, arrange the extracted
source like this:

```text
External\
  DWScript\
    Source\
  kraft\
    src\
  pasmp\
    src\
  GraphicEx\
    3rd party\
      DelphiZlib\
  ImGui-Pascal\
    src\
  bass24\
    delphi\
  Neslib.FastMath\
    <folder containing Neslib.FastMath.pas>
```

Folder names in downloaded archives may contain a version suffix. Rename the
local folder to the name above or change the project search path to its actual
location.

The `.dproj` currently references three stand-alone units by filename. Copy
these downloaded source files into the Engine project root:

```text
dglOpenGL.pas
PasGLTF.pas
PasJSON.pas
```

Alternatively, place them elsewhere, add their folders to the project search
path, and update their entries under **Project > Add to Project**.

### 3. Download The Native Runtime Libraries

1. Download BASS for Windows from
   [the official BASS page](https://www.un4seen.com/bass.html), then copy the Win64
   `bass.dll` beside `OGLM_SandBox.exe`.
2. Download or build cimgui from
   [cimgui](https://github.com/cimgui/cimgui), including its
   [Dear ImGui](https://github.com/ocornut/imgui) submodule.
3. Build cimgui as a 64-bit Windows DLL using the same Dear ImGui API version
   as the ImGui-Pascal binding, then copy `cimgui.dll` beside
   `OGLM_SandBox.exe`.

Neither DLL is interchangeable between Win32 and Win64. Follow each upstream
project's build instructions and license terms.

### 4. Open The Project

1. Start Delphi.
2. Open `OGLM_SandBox.dproj`.
3. Select `Win64` as the target platform.
4. Select `Debug` for the first build. Use `Release` after the setup is
   confirmed.

Open the `.dproj`, not an old `Project1` project file.

### 5. Configure Unit Search Paths

Open:

```text
Project > Options > Delphi Compiler > Search path
```

Select `All configurations - Windows 64-bit`, then ensure these paths are
available:

```text
GuiEditor
MaterialEditor
External\kraft\src
External\pasmp\src
External\GraphicEx
External\GraphicEx\3rd party\DelphiZlib
External\ImGui-Pascal\src
External\bass24\delphi
External\DWScript\Source
<directory containing Neslib.FastMath.pas>
```

The project currently stores all entries above except the DWScript and
Neslib.FastMath paths. Every entry refers to a dependency you downloaded in
step 2. Prefer project-level paths so another Delphi project is not affected
by this setup.

### 6. Configure Conditional Defines

Open:

```text
Project > Options > Delphi Compiler > Conditional defines
```

The active Win64 configuration must define:

```text
KraftPasMP;DYNAMIC_LINK;FM_COLUMN_MAJOR
```

Keep `DEBUG` in Debug and `RELEASE` in Release as appropriate.

`DYNAMIC_LINK` is required because Delphi uses `cimgui.dll`; ImGui-Pascal does
not support static cimgui linking with Delphi. The current Debug configuration
already includes it. Add it to Release if it is missing.

### 7. Disable Runtime Packages

Open:

```text
Project > Options > Packages > Runtime Packages
```

Make sure **Link with runtime packages** is disabled.

This avoids accidental dependencies on unrelated packages listed by the IDE,
including historical GLScene package names. The application should link the
Delphi RTL and VCL normally.

### 8. Clean And Build

Use:

```text
Project > Clean
Project > Build OGLM_SandBox
```

The Win64 project writes DCUs to `Win64\<Configuration>`. Its current Debug
and Release configurations write `OGLM_SandBox.exe` to the repository root.

Do a full Build after changing dependency paths. A simple Compile can reuse
old DCUs and hide a missing source path.

### 9. Check Runtime Files

The executable directory must contain:

```text
OGLM_SandBox.exe
bass.dll
cimgui.dll
Data\
```

Both DLLs must be downloaded or built separately as 64-bit libraries matching
the Win64 executable.

The current VCL editor backend imports `cimgui.dll` directly. It does not need
`SDL2.dll` or `glfw3.dll`; those files belong to alternate ImGui backends.

If the DLLs are absent from a source checkout:

- obtain the official 64-bit BASS library from
  [the BASS download page](https://www.un4seen.com/bass.html) and follow its license
  terms;
- obtain or build a 64-bit `cimgui.dll` from
  [cimgui](https://github.com/cimgui/cimgui) matching the downloaded
  ImGui-Pascal binding; the Engine integration currently targets ImGui 1.91.0.

The complete `Data` directory is required. In particular:

```text
Data\GLSL\       GLSL 4.50 shaders
Data\Tex\        default material textures
Data\Models\     model assets
Data\Materials\  saved materials and libraries
Data\Scenes\     scenes
Data\Scripts\    DWScript files
Data\EngineGUI\  runtime GUI layouts and atlases
```

`TEnginePaths` resolves `Data` relative to the executable, not relative to the
IDE working directory. If the EXE output directory is changed, copy `Data`,
`bass.dll`, and `cimgui.dll` beside the new EXE.

### 10. Run

Run with `F9`. A successful startup should:

1. Open the SandBox VCL window.
2. Create an OpenGL context.
3. Compile the shaders in `Data\GLSL`.
4. Create the default scene, camera, light, and `DefaultPBRMaterial`.
5. Display the ImGui editor over the 3D viewport.

The OpenGL vendor, renderer, and version are written to the in-application log
and to `Log.txt`.

## Command-Line Build

After the IDE paths and conditional symbols have been saved into the project,
open the **RAD Studio Command Prompt** and run:

```bat
msbuild OGLM_SandBox.dproj /t:Build /p:Config=Release /p:Platform=Win64
```

If using a normal Command Prompt, initialize the Delphi environment first.
The default Delphi 12 installation uses:

```bat
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
msbuild OGLM_SandBox.dproj /t:Build /p:Config=Release /p:Platform=Win64
```

Installation paths can differ. The RAD Studio Command Prompt is the safer
choice.

## Use The Engine In A New VCL Application

The Engine is source-based; there is no Engine design-time package to install.

### 1. Create The Host Project

1. Create a new VCL Forms Application.
2. Add a Win64 target.
3. Add the OpenGL Micro Engine project directory to its unit search path.
4. Add all dependency paths listed in the SandBox setup.
5. Define `KraftPasMP;DYNAMIC_LINK;FM_COLUMN_MAJOR`.
6. Disable runtime packages.
7. Deploy `Data`, `bass.dll`, and `cimgui.dll` beside the host EXE.

The render host can be a `TForm`, `TPanel`, or another `TWinControl` with a
valid Windows handle.

### 2. Create And Run TGameEngine

This is a minimal form-hosted loop:

```pascal
unit GameMain;

interface

uses
  Winapi.Windows,
  System.Classes,
  System.SysUtils,
  Vcl.Forms,
  Vcl.ExtCtrls,
  Engine;

type
  TGameForm = class(TForm)
  private
    FEngine: TGameEngine;
    FLoopTimer: TTimer;
    FStartTick: UInt64;
    FLastTick: UInt64;
    procedure LoopTimer(Sender: TObject);
  protected
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
    procedure Resize; override;
  end;

implementation

procedure TGameForm.CreateWnd;
var
  Settings: TEngineSettings;
begin
  inherited;

  if FEngine <> nil then
    Exit;

  Settings := TEngineSettings.Default;
  Settings.Width := ClientWidth;
  Settings.Height := ClientHeight;
  Settings.AntialiasingSamples := 4;

  FEngine := TGameEngine.Create(Self, Settings);

  FStartTick := GetTickCount64;
  FLastTick := FStartTick;
  FLoopTimer := TTimer.Create(Self);
  FLoopTimer.Interval := 16;
  FLoopTimer.OnTimer := LoopTimer;
  FLoopTimer.Enabled := True;
end;

procedure TGameForm.DestroyWnd;
begin
  FreeAndNil(FLoopTimer);
  FreeAndNil(FEngine);
  inherited;
end;

procedure TGameForm.Resize;
begin
  inherited;
  if FEngine <> nil then
    FEngine.Resize(ClientWidth, ClientHeight);
end;

procedure TGameForm.LoopTimer(Sender: TObject);
var
  Tick: UInt64;
  DeltaSeconds: Double;
  TimeSeconds: Double;
begin
  Tick := GetTickCount64;
  DeltaSeconds := (Tick - FLastTick) / 1000.0;
  TimeSeconds := (Tick - FStartTick) / 1000.0;
  FLastTick := Tick;

  FEngine.Update(DeltaSeconds, TimeSeconds);
  FEngine.Render;
end;

end.
```

For a `TPanel` host, pass the panel to `TGameEngine.Create` and use the panel's
client size in `Resize`.

The engine constructor automatically:

- initializes asset paths from the executable directory;
- creates the renderer and OpenGL context;
- loads the core shaders;
- creates the default material library;
- creates the default scene, light, and camera;
- creates physics, audio, script, and GUI managers according to
  `TEngineSettings`;
- loads `Data\Default.omescn` if that optional file exists.

Free `TGameEngine` before destroying its host window, because renderer cleanup
requires a valid window and OpenGL context.

### 3. Forward Runtime GUI Input

When `Settings.EnableGUI` is enabled, forward the host's mouse and keyboard
events to these methods before processing game input:

```pascal
FEngine.GuiMouseDown(Button, Shift, X, Y);
FEngine.GuiMouseMove(Shift, X, Y);
FEngine.GuiMouseUp(Button, Shift, X, Y);
FEngine.GuiKeyDown(Key, Shift);
FEngine.GuiKeyPress(Key);
FEngine.GuiKeyUp(Key, Shift);
```

Each method returns `True` when the runtime GUI consumed the input.

## Common Build Problems

### Unit `Neslib.FastMath` Not Found

Add the directory containing `Neslib.FastMath.pas` to the Win64 project search
path. A placeholder README under `External\Neslib.FastMath` is not the source
unit.

### Unit `dwsComp` Or Another `dws...` Unit Not Found

Add:

```text
External\DWScript\Source
```

Then use Project > Clean followed by Project > Build.

### Unit `PasImGui`, `Kraft`, `PasMP`, Or `GraphicEx` Not Found

Download the missing library from the dependency table, place it in the
documented local `External` folder, and restore the corresponding search path.
These are source dependencies, not IDE packages.

### ImGui Reports That Static Linking Is Unsupported

Add `DYNAMIC_LINK` to the active configuration's conditional defines and keep
`cimgui.dll` beside the EXE.

### Missing `cimgui.dll` Or `bass.dll` At Startup

Download or build the 64-bit DLLs using the links above and place them beside
the Win64 executable. Windows searches the executable directory first for
these project-local libraries.

### GLScene Package Or DCP Error

Disable **Link with runtime packages**. GLScene is not required by the active
source. If necessary, remove stale GLScene names from the configuration's
runtime package list.

### Shader File Not Found Or Shader Compilation Fails

Confirm that `Data\GLSL` is beside the EXE and that the GPU driver supports
OpenGL 4.5. The supplied shaders declare `#version 450 core`.

### The Application Starts From The Wrong Data Directory

Assets are resolved relative to `ParamStr(0)`, which is the executable path.
Move or copy the complete `Data` directory beside the executable.

### Strange Errors After Updating Sources

Old DCUs can mask changed dependencies. Use Project > Clean, remove stale
generated DCUs under `Win64\Debug` or `Win64\Release` if necessary, and perform
a full Build.

## Licensing

Original engine source is covered by [LICENSE](LICENSE). Third-party libraries,
DLLs, and assets retain their own licenses.
