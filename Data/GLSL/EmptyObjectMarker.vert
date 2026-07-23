#version 450 core

layout(location = 0) in vec3 position;

uniform mat4 modelMatrix;
uniform mat4 viewProjection;

void main()
{
    gl_Position = viewProjection * modelMatrix * vec4(position, 1.0);
}
