#version 450 core

const int MaxLights = 8;

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec3 tangent;
layout(location = 3) in vec3 bitangent;
layout(location = 4) in vec2 texcoord;

struct InstanceData
{
    mat4 modelMatrix;
    mat4 normalMatrix;
    vec4 windRootHeight;
    vec4 windAxisUnused;
};

layout(std430, binding = 4) readonly buffer InstanceBuffer
{
    InstanceData instances[];
};

uniform mat4 modelMatrix;
uniform mat3 normalMatrix;
uniform mat4 viewProjection;
uniform mat4 lightSpaceMatrix;
uniform vec4 clipPlane;
uniform int useClipPlane;
uniform int useInstanceBuffer;
uniform int instanceBaseOffset;
uniform int useVertexWind;
uniform float windTime;
uniform vec3 windDirection;
uniform float windStrength;
uniform float windFrequency;
uniform float windGustStrength;
uniform float windGustFrequency;
uniform float windPhaseOffset;
uniform float windTrunkFlex;
uniform float windBranchFlex;
uniform float windLeafFlutter;
uniform vec3 windRoot;
uniform vec3 windAxis;
uniform float windHeight;

out Vertex
{
    vec3 position;
    vec2 texcoord;
    mat3 tangentBasis;
    vec3 geometricNormal;
    vec4 lightSpacePosition;
} vout;

vec3 RotateAroundAxis(vec3 value, vec3 axis, float angle)
{
    float sine = sin(angle);
    float cosine = cos(angle);
    return value * cosine + cross(axis, value) * sine +
        axis * dot(axis, value) * (1.0 - cosine);
}

void ApplyGrassWind(inout vec4 worldPosition, vec3 instanceWindRoot,
    vec3 instanceWindAxis, float instanceWindHeight, inout vec3 worldNormal,
    inout vec3 worldTangent, inout vec3 worldBitangent)
{
    if (useVertexWind == 0 || instanceWindHeight <= 1e-5 ||
        windStrength <= 0.0)
        return;

    vec3 grassAxis = instanceWindAxis;
    if (dot(grassAxis, grassAxis) <= 1e-8)
        grassAxis = vec3(0.0, 1.0, 0.0);
    else
        grassAxis = normalize(grassAxis);

    vec3 direction = windDirection - grassAxis * dot(windDirection, grassAxis);
    if (dot(direction, direction) <= 1e-8)
    {
        direction = abs(grassAxis.x) < 0.85 ? vec3(1.0, 0.0, 0.0) :
            vec3(0.0, 0.0, 1.0);
        direction -= grassAxis * dot(direction, grassAxis);
    }
    direction = normalize(direction);

    vec3 crossDirection = normalize(cross(grassAxis, direction));
    vec3 bendAxis = normalize(cross(grassAxis, direction));
    vec3 relativePosition = worldPosition.xyz - instanceWindRoot;
    float heightRatio = clamp(dot(relativePosition, grassAxis) /
        max(instanceWindHeight, 1e-5), 0.0, 1.0);
    if (heightRatio <= 0.0)
        return;

    float basePhase = windTime * windFrequency * 6.28318530718 +
        windPhaseOffset;
    float spatialPhase = dot(relativePosition, vec3(0.31, 0.07, 0.23));
    float wave = sin(basePhase + spatialPhase) * 0.66 +
        sin(basePhase * 1.91 + spatialPhase * 1.37 + 0.8) * 0.34;
    float gust = 1.0 + windGustStrength * (0.5 + 0.5 *
        sin(windTime * windGustFrequency * 6.28318530718 +
        windPhaseOffset * 0.43));
    float heightProfile = heightRatio * heightRatio *
        (3.0 - 2.0 * heightRatio);
    float flutter = sin(basePhase * 5.3 + spatialPhase * 3.1) *
        windLeafFlutter * 0.12;
    float swayDistance = windStrength * instanceWindHeight *
        heightProfile * gust;
    float bendAmount = wave * windBranchFlex + flutter * heightRatio;

    worldPosition.xyz += direction * swayDistance * bendAmount;
    worldPosition.xyz += crossDirection * swayDistance * flutter * 0.55;

    float rotationAngle = windStrength * heightProfile * gust * bendAmount;
    worldNormal = RotateAroundAxis(worldNormal, bendAxis, rotationAngle);
    worldTangent = RotateAroundAxis(worldTangent, bendAxis, rotationAngle);
    worldBitangent = RotateAroundAxis(worldBitangent, bendAxis, rotationAngle);
}

void main()
{
    mat4 effectiveModelMatrix = modelMatrix;
    mat3 effectiveNormalMatrix = normalMatrix;
    vec3 instanceWindRoot = windRoot;
    vec3 instanceWindAxis = windAxis;
    float instanceWindHeight = windHeight;

    if (useInstanceBuffer != 0)
    {
        InstanceData instance = instances[instanceBaseOffset + gl_InstanceID];
        effectiveModelMatrix = instance.modelMatrix;
        effectiveNormalMatrix = mat3(instance.normalMatrix);
        instanceWindRoot = instance.windRootHeight.xyz;
        instanceWindHeight = instance.windRootHeight.w;
        instanceWindAxis = instance.windAxisUnused.xyz;
    }

    vec4 worldPos = effectiveModelMatrix * vec4(position, 1.0);

    vec3 N = effectiveNormalMatrix * normal;
    if (dot(N, N) <= 1e-10)
        N = vec3(0.0, 1.0, 0.0);
    else
        N = normalize(N);

    vec3 T = effectiveNormalMatrix * tangent;
    T = T - N * dot(N, T);
    if (dot(T, T) <= 1e-10)
    {
        vec3 axis = abs(N.x) < 0.9 ? vec3(1.0, 0.0, 0.0) :
            vec3(0.0, 1.0, 0.0);
        T = normalize(axis - N * dot(N, axis));
    }
    else
        T = normalize(T);

    vec3 B = effectiveNormalMatrix * bitangent;
    B = B - N * dot(N, B) - T * dot(T, B);
    if (dot(B, B) <= 1e-10)
        B = normalize(cross(N, T));
    else
        B = normalize(B);

    ApplyGrassWind(worldPos, instanceWindRoot, instanceWindAxis,
        instanceWindHeight, N, T, B);
    N = normalize(N);
    T = T - N * dot(N, T);
    if (dot(T, T) <= 1e-10)
    {
        vec3 axis = abs(N.x) < 0.9 ? vec3(1.0, 0.0, 0.0) :
            vec3(0.0, 1.0, 0.0);
        T = normalize(axis - N * dot(N, axis));
    }
    else
        T = normalize(T);

    B = B - N * dot(N, B) - T * dot(T, B);
    if (dot(B, B) <= 1e-10)
        B = normalize(cross(N, T));
    else
        B = normalize(B);

    if (useClipPlane != 0)
        gl_ClipDistance[0] = dot(worldPos, clipPlane);

    vout.position = worldPos.xyz;
    vout.texcoord = texcoord;
    vout.tangentBasis = mat3(T, B, N);
    vout.geometricNormal = N;
    vout.lightSpacePosition = lightSpaceMatrix * worldPos;

    gl_Position = viewProjection * worldPos;
}
