#version 450 core

layout(location = 0) in vec3 position;
layout(location = 4) in vec2 texcoord;

uniform mat4 modelMatrix;
uniform mat4 viewProjection;

out vec2 vTexcoord;

void main()
{
    gl_Position = viewProjection * modelMatrix * vec4(position, 1.0);
    // Render-target textures use OpenGL's bottom-left origin, so flip V when
    // displaying the captured impostor on the billboard.
    vTexcoord = vec2(texcoord.x, 1.0 - texcoord.y);
}
