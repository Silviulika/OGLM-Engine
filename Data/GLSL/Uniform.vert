#version 450 core

layout(location = 0) in vec3 aPos;
layout(location = 1) in vec2 aTexCoord;
layout(location = 2) in vec3 aNormal;

out vec2 vTexCoord;
out vec3 vNormal;
out vec3 vFragPos;

uniform mat4 uMVP;
uniform mat4 uModel;        // needed for lighting in world space

void main()
{
    vec4 worldPos = uModel * vec4(aPos, 1.0);
    vFragPos = worldPos.xyz;
    gl_Position = uMVP * vec4(aPos, 1.0);
    vTexCoord = aTexCoord;
    // Transform normal to world space (assumes uniform scaling, else use normal matrix)
    vNormal = mat3(transpose(inverse(uModel))) * aNormal;
}