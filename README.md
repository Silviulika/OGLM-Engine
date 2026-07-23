## OpenGL Micro Engine

OpenGL Micro Engine is a Delphi-based real-time 3D engine and editor built on
OpenGL. It is designed as a compact, readable codebase for experimenting with
rendering systems, scene editing, and runtime engine features without hiding the
interesting parts behind a large framework.

The project includes a scene hierarchy, cameras, lights, material libraries,
GLSL shader management, texture loading, glTF/OBJ import, terrain and water
rendering, billboards, particles, animated sprites, physics integration, audio
emitters, scene serialization, prefab-style workflows, and DWScript-based
scripting.

The editor side provides an ImGui-powered viewport, object inspector, transform
gizmos, asset browsers, material tools, mesh and primitive creation tools,
particle editing, render-texture capture, and scene save/load workflows. The
goal is to keep the editor close to the runtime so engine behavior can be built,
inspected, and adjusted visually while still remaining approachable in source.

## Release Status

This repository is being prepared for a source-first public GitHub release. The
original engine/editor code is licensed under the MIT license in `LICENSE`.
Third-party libraries, bindings, tools, and assets keep their own licenses and
are listed in `THIRD_PARTY_NOTICES.md`.

The MIT license does not relicense files owned by third parties. Keep each
upstream license notice with its source, and treat bundled binaries and assets as
separate release items.
