#version 450 core

layout (location = 0) in vec3 inPosition;

uniform mat4 viewProjection;
uniform vec3 cameraPosition;
uniform float radius;

out vec3 vDirection;

void main()
{
    vec3 direction = normalize(inPosition);
    vec3 worldPosition = cameraPosition + direction * radius;
    vec4 clipPosition = viewProjection * vec4(worldPosition, 1.0);

    clipPosition.z = clipPosition.w;
    gl_Position = clipPosition;
    vDirection = direction;
}
