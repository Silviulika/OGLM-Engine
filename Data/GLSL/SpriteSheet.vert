#version 450 core

layout(location = 0) in vec3 position;
layout(location = 4) in vec2 texcoord;

uniform mat4 modelMatrix;
uniform mat4 viewProjection;
uniform vec4 clipPlane;
uniform int useClipPlane;

out vec2 vTexCoord;

void main()
{
    vec4 worldPos = modelMatrix * vec4(position, 1.0);
    if (useClipPlane != 0)
        gl_ClipDistance[0] = dot(worldPos, clipPlane);

    vTexCoord = vec2(texcoord.x, 1.0 - texcoord.y);
    gl_Position = viewProjection * worldPos;
}
