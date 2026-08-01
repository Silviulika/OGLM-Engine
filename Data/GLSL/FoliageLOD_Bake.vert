#version 450 core

layout(location = 0) in vec3 position;
layout(location = 4) in vec2 texcoord;

uniform mat4 captureMatrix;

out vec2 vTexcoord;

void main()
{
    gl_Position = captureMatrix * vec4(position, 1.0);
    vTexcoord = vec2(texcoord.x, 1.0 - texcoord.y);
}
