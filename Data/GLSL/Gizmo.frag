#version 450 core

uniform int activeColor;
uniform float hoverFactor;
uniform float selectedFactor;
uniform vec4 gizmoHoverColor;
uniform vec4 gizmoSelectedColor;

layout(location = 0) out vec4 FragColor;

vec4 BaseGizmoColor(int tag)
{
    // Single axes.
    if (tag == 0) return vec4(1.00, 0.08, 0.08, 1.0); // X
    if (tag == 1) return vec4(0.10, 1.00, 0.10, 1.0); // Y
    if (tag == 2) return vec4(0.15, 0.35, 1.00, 1.0); // Z

    // Center and 2-axis handles.
    if (tag == 3) return vec4(0.55, 0.62, 0.75, 1.0); // center (blue-gray; avoids hover yellow/selected orange)
    if (tag == 4) return vec4(0.20, 0.55, 1.00, 1.0); // XY (blue; avoids hover yellow)
    if (tag == 5) return vec4(0.15, 1.00, 1.00, 1.0); // YZ
    if (tag == 6) return vec4(1.00, 0.15, 1.00, 1.0); // XZ

    return vec4(1.0, 1.0, 1.0, 1.0);
}

void main()
{
    vec4 color = BaseGizmoColor(activeColor);

    // Hover = bright yellow. Drag/selected = orange, applied last.
    color = mix(color, gizmoHoverColor, clamp(hoverFactor, 0.0, 1.0));
    color = mix(color, gizmoSelectedColor, clamp(selectedFactor, 0.0, 1.0));

    FragColor = color;
}
