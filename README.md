# OpenGL Micro Engine

OpenGL Micro Engine (OGLM) is a Delphi/VCL OpenGL 3D engine with two runnable
projects:

- `OGLM_SandBox.dproj` - the Dear ImGui-based editor/sandbox.
- `OGLM_Game.dproj` - a lightweight game runtime template that loads scenes
  from `Data\Scenes`.

The engine code is source-based. There is no design-time package to install in
RAD Studio; the projects compile the engine units directly.

## What Is In This Repository

The project root contains the engine and app units:

- `Engine*.pas` - engine startup, asset paths, scripting, GUI, audio, input,
  physics integration, time, and shared engine types.
- `Renderer*.pas` - OpenGL renderer, shaders, meshes, cameras, lights,
  particles, billboards, animated sprites, skeletons, sky dome, and render
  techniques.
- `Managers*.pas` - scene and material library management.
- `Loader.OBJ.pas`, `Loader.GLTF.pas`, `PasGLTF.pas`, `PasJSON.pas` - model
  and data loading support.
- `Physics*.pas` - local physics math, geometry, settings, and physics world
  integration.
- `SandBox.pas`, `MainUnit.pas` - the editor application.
- `OGLM_GameForm.pas` - the standalone game window and command-line startup
  handling.
- `Data\` - checked-in runtime/editor assets.
- `External\` - dependency submodules used by the Delphi search path.

The current Delphi project files target `Win32` and `Win64`, default to
`Release | Win64`, and write the executable to the repository root. DCUs are
written under `Win64\<Config>` or `Win32\<Config>`.

## Requirements

- Windows 10 or Windows 11.
- Embarcadero RAD Studio / Delphi 12-era VCL toolchain, or a newer compatible
  Delphi version that can load the checked-in `.dproj` files.
- Windows desktop VCL support.
- An OpenGL driver that supports the checked-in GLSL shaders. The runtime
  shaders in `Data\GLSL` use `#version 450 core`, so OpenGL 4.5 support is the
  intended target.
- 64-bit native DLLs beside the executable when running `Win64` builds:
  `bass.dll` and `cimgui.dll`.

## Dependencies

Most Pascal dependencies are configured as Git submodules in `.gitmodules`.
Clone with submodules:

```bat
git clone --recurse-submodules <repo-url>
```

For an existing checkout, initialize or refresh them with:

```bat
git submodule update --init --recursive
```

The project search path in both `.dproj` files currently includes:

```text
External\DWScript\Source
External\kraft\src
External\FastMath\FastMath
External\GraphEx
External\dglOpenGL
External\ImGui-Pascal\src
External\pasdblstrutils\src
External\pasjson\src
External\pasmp\src
External\GraphEx\3rd party\AutoResourceStr
External\GraphEx\3rd party\DelphiZlib
```

The shared compiler defines are already stored in the project files:

```text
KraftPasMP;DYNAMIC_LINK;FM_COLUMN_MAJOR
```

`DYNAMIC_LINK` is required because the ImGui Pascal binding imports
`cimgui.dll` dynamically.

### Native DLLs

The Pascal import unit for BASS is present as `bass.pas`, but `bass.dll` is not
checked in. Download BASS for Windows from Un4seen and copy the matching
Win64 `bass.dll` beside `OGLM_SandBox.exe` or `OGLM_Game.exe`.

The ImGui submodule includes a Win64 `cimgui.dll` at:

```text
External\ImGui-Pascal\libs\dynamic\windows\64bit\cimgui.dll
```

Copy that DLL beside the executable, or replace it with a compatible Win64
build that matches the checked-out `ImGui-Pascal` binding.

Because the projects currently output EXEs to the repository root, the usual
runtime layout is:

```text
OGLM_SandBox.exe
OGLM_Game.exe
bass.dll
cimgui.dll
Data\
```

If you change the executable output folder, copy `Data`, `bass.dll`, and
`cimgui.dll` beside the new executable. `TEnginePaths` resolves assets relative
to the executable path, not the IDE working directory.

## Build

Open either project directly in Delphi:

- `OGLM_SandBox.dproj` for the editor.
- `OGLM_Game.dproj` for the game runtime template.

Select `Win64`, then build `Debug` or `Release`.

From a RAD Studio Command Prompt:

```bat
msbuild OGLM_SandBox.dproj /t:Build /p:Config=Release /p:Platform=Win64
msbuild OGLM_Game.dproj /t:Build /p:Config=Release /p:Platform=Win64
```

If using a normal Command Prompt, initialize the Delphi environment first. A
typical Delphi 12 installation uses:

```bat
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
```

Then run the `msbuild` commands above.

## Run The Editor

Build and run:

```bat
OGLM_SandBox.exe
```

The editor opens a VCL window with a Dear ImGui interface over the 3D viewport.
It includes scene and object tools, an inspector, material editing, texture and
model browsers, scene save/load, prefab and particle tools, physics controls,
audio emitter controls, script editing, runtime GUI tools, height-field terrain
tools, render texture capture, and an in-app log.

On exit, the editor writes `Log.txt` beside the executable.

## Run The Game Template

Build and run:

```bat
OGLM_Game.exe GUI_Scene_2.omescn
```

Bare scene names are resolved from `Data\Scenes`, and `.omescn` is appended
when needed. The checked-in scenes are:

```text
Data\Scenes\GUI_Scene_2.omescn
Data\Scenes\VertexTreeAndTerrainAndWater.omescn
```

`RunGame.bat` currently launches:

```bat
OGLM_Game.exe --fullscreen --resolution=1600x1024 --scene GUI_Scene_2.omescn
```

Supported game switches include:

```bat
OGLM_Game.exe --scene GUI_Scene_2.omescn
OGLM_Game.exe GUI_Scene_2
OGLM_Game.exe --fullscreen --res=1920x1080 GUI_Scene_2.omescn
OGLM_Game.exe --windowed --width 1280 --height 720
```

See `OGLM_Game_Commands.txt` for the full command-line reference.

If no scene is supplied, `OGLM_GameForm.pas` currently leaves
`DEFAULT_ENTRY_SCENE` empty. The engine then tries `Data\Default.omescn` if it
exists; this checkout does not include that file, so the built-in default scene
is used.

On exit, the game writes `OGLM_Game.log` beside the executable.

## Asset Layout

The engine expects these folders under `Data`:

```text
Data\GLSL\             GLSL shaders
Data\Tex\              material and default textures
Data\Materials\        saved material files and libraries
Data\Models\           OBJ/glTF model assets
Data\Scenes\           .omescn scene files
Data\Prefabs\          prefab metadata/files
Data\Particles\        particle textures and saved particle systems
Data\AnimatedSprites\  sprite-sheet textures
Data\Billboards\       billboard textures
Data\Audio\            audio assets
Data\Scripts\          DWScript assets
Data\EngineGUI\        runtime GUI skins/layouts
Data\Terrain\          height-field sources
Data\Generated\        generated runtime/editor outputs
```

The checked-in generated assets include `Data\Generated\EngineObjects.png`.

## Notes For New Host Applications

To embed the engine in another VCL app, add the OGLM project root and the
dependency search paths above to the host project, keep the same conditional
defines, and create a `TGameEngine` with a `TWinControl` host:

```pascal
var
  Settings: TEngineSettings;
  Engine: TGameEngine;
begin
  Settings := TEngineSettings.Default;
  Settings.Width := Host.ClientWidth;
  Settings.Height := Host.ClientHeight;
  Settings.AntialiasingSamples := 4;

  Engine := TGameEngine.Create(Host, Settings);
end;
```

Call `Engine.Update(DeltaTime, TimeSeconds)` and `Engine.Render` from your game
loop, forward resize events with `Engine.Resize`, and free the engine before
the host window is destroyed.

When runtime GUI is enabled, forward mouse and keyboard events through
`GuiMouseDown`, `GuiMouseMove`, `GuiMouseUp`, `GuiKeyDown`, `GuiKeyPress`, and
`GuiKeyUp`. Each returns `True` when the GUI consumed the input.

## Common Problems

`PasImGui` loads but the app fails at startup:
copy a compatible Win64 `cimgui.dll` beside the EXE.

Audio initialization or loading fails:
copy the Win64 `bass.dll` beside the EXE.

Shader files are missing:
make sure the complete `Data` folder is beside the EXE.

Shader compilation fails:
confirm that the GPU and driver support OpenGL 4.5 / GLSL 450.

Dependency units are missing:
initialize the submodules and confirm the project search path still matches the
paths listed in this README.

Old or surprising compile errors after dependency changes:
clean the project and remove stale DCUs under `Win64\Debug`, `Win64\Release`,
`Win32\Debug`, or `Win32\Release` before rebuilding.

## Tools Used

Textures are created with Materialize:
https://www.boundingboxsoftware.com/materialize/

Explosion atlas images are created with explotexgen:
https://www.saschawillems.de/creations/explosion-texture-generator/

Trees are generated with eztree:
https://www.eztree.dev/

Animations are created with Mixamo and/or mesh2motion:
https://www.mixamo.com/
https://app.mesh2motion.org/

Particles thanks to Kenney:
https://www.kenney.nl/

Some height maps are generated with L3DT standard. There are some issues with
their website, but downloading the software is manageable:
https://www.bundysoft.com/L3DT/downloads/standard.php

## Licensing

Original engine source is covered by `LICENSE`. Third-party submodules,
runtime DLLs, imported Pascal units, and assets retain their own licenses.
