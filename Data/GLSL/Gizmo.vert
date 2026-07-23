#version 450 core

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 normal;      // declared but not used
layout(location = 2) in vec3 tangent;     // declared but not used
layout(location = 3) in vec3 bitangent;   // declared but not used
layout(location = 4) in vec2 texcoord;    // declared but not used

uniform mat4 modelMatrix;
uniform mat4 viewProjection;

out Vertex
{
    vec3 position;
    vec2 texcoord;
    mat3 tangentBasis;
} vout;

void main()
{
    // Compute world position and gl_Position using only position attribute
    vec4 worldPos = modelMatrix * vec4(position, 1.0);
    vout.position = worldPos.xyz;

    // Dummy values – these are never read by the solid-color fragment shader
    vout.texcoord = vec2(0.0);
    vout.tangentBasis = mat3(1.0);

    gl_Position = viewProjection * worldPos;
}