#version 450 core

layout(location = 0) in vec3 position;
layout(location = 1) in vec4 billboardColor;
layout(location = 2) in vec2 texCoord;

uniform mat4 viewProjection;

out vec4 vColor;
out vec2 vTexCoord;

void main()
{
    vColor = billboardColor;
    vTexCoord = texCoord;
    gl_Position = viewProjection * vec4(position, 1.0);
}
