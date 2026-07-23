#version 450 core

const int MaxLights = 8;

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec3 tangent;
layout(location = 3) in vec3 bitangent;
layout(location = 4) in vec2 texcoord;
layout(location = 5) in vec3 morphPosition;

uniform mat4 modelMatrix;
uniform mat4 viewProjection;
uniform mat4 lightSpaceMatrix;
uniform mat4 lightSpaceMatrices[MaxLights];
uniform vec4 clipPlane;
uniform int useClipPlane;
uniform int heightFieldUseMorph;
uniform float heightFieldMorphFactor;

out Vertex
{
    vec3 position;
    vec2 texcoord;
    mat3 tangentBasis;
    vec3 geometricNormal;
    vec4 lightSpacePosition;
    vec4 lightSpacePositions[MaxLights];
} vout;

void main()
{
    int i;
    vec3 localPosition = position;
    if (heightFieldUseMorph != 0)
        localPosition = mix(position, morphPosition, clamp(heightFieldMorphFactor, 0.0, 1.0));

    vec4 worldPos = modelMatrix * vec4(localPosition, 1.0);
    if (useClipPlane != 0)
        // The reflection pass places its plane 0.05 above nominal water, while
        // the default six-wave stack can trough about 0.42 below it. Keep the
        // clip below that animated trough plus a small rasterization margin.
        gl_ClipDistance[0] = dot(worldPos, clipPlane) + 0.55;

    mat3 normalMatrix = transpose(inverse(mat3(modelMatrix)));

    vec3 N = normalize(normalMatrix * normal);
    vec3 T = normalize(normalMatrix * tangent);
    T = normalize(T - N * dot(N, T));
    // Height-field V coordinates grow along local +Z. cross(N, T) points in
    // the opposite direction for an XZ terrain, which inverted both the
    // normal-map Y channel and the parallax view direction.
    vec3 B = normalize(cross(T, N));

    vout.position = worldPos.xyz;
    vout.texcoord = texcoord;
    vout.tangentBasis = mat3(T, B, N);
    vout.geometricNormal = N;
    vout.lightSpacePosition = lightSpaceMatrix * worldPos;
    for (i = 0; i < MaxLights; ++i)
        vout.lightSpacePositions[i] = lightSpaceMatrices[i] * worldPos;

    gl_Position = viewProjection * worldPos;
}
