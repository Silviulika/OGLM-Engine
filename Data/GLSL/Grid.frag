#version 450 core

layout (location = 0) in vec3 NearPoint;
layout (location = 1) in vec3 FarPoint;

layout (location = 0) out vec4 FragColor;

uniform mat4 view;
uniform mat4 projection;
uniform vec3 cameraPosition;

// Calculate an anti-aliased grid line and suppress it when a cell becomes
// smaller than a few pixels.  The latter is important for the finer LOD: it
// lets subdivisions appear as the camera approaches without turning the
// distant grid into a solid/moire pattern.
float GetGridAlpha(vec3 fragPos3D, float scale) {
    vec2 coord = fragPos3D.xz * scale;
    vec2 derivative = max(fwidth(coord), vec2(0.000001));
    vec2 grid = abs(fract(coord - 0.5) - 0.5) / derivative;
    float line = min(grid.x, grid.y);
    float lineAlpha = 1.0 - min(line, 1.0);

    float pixelsPerCell = 1.0 / max(derivative.x, derivative.y);
    float lodVisibility = smoothstep(2.0, 5.0, pixelsPerCell);
    return lineAlpha * lodVisibility;
}

// Compute depth value manually for correct rendering sorting
float ComputeDepth(vec3 pos) {
    vec4 clip_space_pos = projection * view * vec4(pos.xyz, 1.0);
    return (clip_space_pos.z / clip_space_pos.w);
}

void main() {
    // Calculate ray intersection with the horizontal ground plane (Y = 0)
    float rayY = FarPoint.y - NearPoint.y;
    if (abs(rayY) < 0.000001) {
        discard;
    }

    float t = -NearPoint.y / rayY;
    
    // Discard fragments that do not intersect the plane or look upward
    if (t < 0.0) {
        discard;
    }

    vec3 fragPos3D = NearPoint + t * (FarPoint - NearPoint);

    // Update depth buffer to make sure objects clip through the grid naturally
    gl_FragDepth = clamp((ComputeDepth(fragPos3D) + 1.0) / 2.0, 0.0, 1.0);

    // Linear camera distance depth fading
    float linearDepth = length(fragPos3D - cameraPosition);
    float fading = max(0.0, min(1.0, (100.0 - linearDepth) / 70.0)); // Adjust visibility bounds here

    // 1. Calculate Grid Lines
    // Main grid lines happen every 10 units (scale = 0.1)
    float mainGridAlpha = GetGridAlpha(fragPos3D, 0.1); 
    // Sub-grid lines happen every 1 unit (scale = 1.0)
    float subGridAlpha = GetGridAlpha(fragPos3D, 1.0);
    // Each one-unit cell gains ten 0.1-unit subdivisions when those cells are
    // large enough on screen. GetGridAlpha provides the smooth LOD transition.
    float detailGridAlpha = GetGridAlpha(fragPos3D, 10.0);

    // 2. Define Colors
    vec3 detailGridColor = vec3(0.08);                           // Finest, faintest level
    vec3 subGridColor = vec3(0.15);                              // One-unit grid
    vec3 mainGridColor = vec3(0.4);                              // Ten-unit grid

    // 3. Blend Grids (coarser levels take precedence at shared lines)
    vec3 gridColor = detailGridColor;
    gridColor = mix(gridColor, subGridColor, subGridAlpha);
    gridColor = mix(gridColor, mainGridColor, mainGridAlpha);
    float gridAlpha = max(mainGridAlpha,
                          max(subGridAlpha, detailGridAlpha * 0.45));
    vec4 finalColor = vec4(gridColor, gridAlpha);

    // 4. Highlight Central World Axes (X = Red, Z = Blue)
    float axisThreshold = 0.05;
    if (fragPos3D.x > -axisThreshold && fragPos3D.x < axisThreshold) {
        finalColor = vec4(1.0, 0.0, 0.0,
                          max(gridAlpha, detailGridAlpha)); // Z-Axis Line
    }
    if (fragPos3D.z > -axisThreshold && fragPos3D.z < axisThreshold) {
        finalColor = vec4(0.0, 0.0, 1.0,
                          max(gridAlpha, detailGridAlpha)); // X-Axis Line
    }

    // Apply distance fading
    FragColor = finalColor;
    FragColor.a *= fading;
    
    // Discard completely transparent fragments to optimize alpha blending performance
    if (FragColor.a < 0.01) {
        discard;
    }
}
