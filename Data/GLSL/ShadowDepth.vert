#version 450 core

layout(location = 0) in vec3 position;
layout(location = 4) in vec2 texcoord;
layout(location = 6) in uvec4 joints0;
layout(location = 7) in vec4 weights0;
layout(location = 8) in uvec4 joints1;
layout(location = 9) in vec4 weights1;

layout(std430, binding = 3) readonly buffer SkinPalette
{
    mat4 skinMatrices[];
};

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
uniform mat4 lightSpaceMatrix;
uniform int useSkinning;
uniform int skinMatrixCount;
uniform int flipAlphaCutoutV;
uniform int useInstanceBuffer;
uniform int instanceBaseOffset;
uniform int useVertexWind;
uniform int shadowWindMode;
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

out vec2 shadowTexcoord;

void AddSkinInfluence(inout mat4 skinMatrix, inout float totalWeight,
    uint jointIndex, float weight)
{
    if (weight <= 0.0 || skinMatrixCount <= 0)
        return;

    uint safeIndex = min(jointIndex, uint(skinMatrixCount - 1));
    skinMatrix += skinMatrices[safeIndex] * weight;
    totalWeight += weight;
}

mat4 CalculateSkinMatrix()
{
    mat4 skinMatrix = mat4(0.0);
    float totalWeight = 0.0;

    AddSkinInfluence(skinMatrix, totalWeight, joints0.x, weights0.x);
    AddSkinInfluence(skinMatrix, totalWeight, joints0.y, weights0.y);
    AddSkinInfluence(skinMatrix, totalWeight, joints0.z, weights0.z);
    AddSkinInfluence(skinMatrix, totalWeight, joints0.w, weights0.w);
    AddSkinInfluence(skinMatrix, totalWeight, joints1.x, weights1.x);
    AddSkinInfluence(skinMatrix, totalWeight, joints1.y, weights1.y);
    AddSkinInfluence(skinMatrix, totalWeight, joints1.z, weights1.z);
    AddSkinInfluence(skinMatrix, totalWeight, joints1.w, weights1.w);

    if (totalWeight <= 1e-8)
        return mat4(1.0);
    return skinMatrix / totalWeight;
}

vec3 RotateAroundAxis(vec3 value, vec3 axis, float angle)
{
    float sine = sin(angle);
    float cosine = cos(angle);
    return value * cosine + cross(axis, value) * sine +
        axis * dot(axis, value) * (1.0 - cosine);
}

void ApplyVertexWind(inout vec4 worldPosition, vec3 instanceWindRoot,
    vec3 instanceWindAxis, float instanceWindHeight)
{
    if (useVertexWind == 0 || instanceWindHeight <= 1e-5 ||
        windStrength <= 0.0)
        return;

    if (shadowWindMode == 1)
    {
        vec3 grassAxis = instanceWindAxis;
        if (dot(grassAxis, grassAxis) <= 1e-8)
            grassAxis = vec3(0.0, 1.0, 0.0);
        else
            grassAxis = normalize(grassAxis);

        vec3 direction = windDirection -
            grassAxis * dot(windDirection, grassAxis);
        if (dot(direction, direction) <= 1e-8)
        {
            direction = abs(grassAxis.x) < 0.85 ? vec3(1.0, 0.0, 0.0) :
                vec3(0.0, 0.0, 1.0);
            direction -= grassAxis * dot(direction, grassAxis);
        }
        direction = normalize(direction);

        vec3 crossDirection = normalize(cross(grassAxis, direction));
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
        return;
    }

    vec3 treeAxis = instanceWindAxis;
    if (dot(treeAxis, treeAxis) <= 1e-8)
        treeAxis = vec3(0.0, 1.0, 0.0);
    else
        treeAxis = normalize(treeAxis);

    vec3 direction = windDirection - treeAxis * dot(windDirection, treeAxis);
    if (dot(direction, direction) <= 1e-8)
    {
        direction = abs(treeAxis.x) < 0.85 ? vec3(1.0, 0.0, 0.0) :
            vec3(0.0, 0.0, 1.0);
        direction -= treeAxis * dot(direction, treeAxis);
    }
    direction = normalize(direction);
    vec3 rotationAxis = normalize(cross(treeAxis, direction));

    vec3 relativePosition = worldPosition.xyz - instanceWindRoot;
    float heightRatio = clamp(dot(relativePosition, treeAxis) /
        max(instanceWindHeight, 1e-5), 0.0, 1.0);
    if (heightRatio <= 0.0)
        return;

    float basePhase = windTime * windFrequency * 6.28318530718 +
        windPhaseOffset;
    float wave = sin(basePhase) * 0.70 + sin(basePhase * 1.73 + 1.17) * 0.30;
    float gust = 1.0 + windGustStrength * (0.5 + 0.5 *
        sin(windTime * windGustFrequency * 6.28318530718 +
        windPhaseOffset * 0.43));
    float heightProfile = heightRatio * heightRatio *
        (3.0 - 2.0 * heightRatio);
    float flex = mix(windTrunkFlex, windBranchFlex,
        smoothstep(0.18, 0.88, heightRatio));
    float spatialPhase = dot(relativePosition, vec3(0.173, 0.097, 0.131));
    float flutter = sin(basePhase * 4.1 + spatialPhase * 2.3) *
        windLeafFlutter * 0.08 * heightRatio * heightRatio;
    float rotationAngle = windStrength * heightProfile * gust *
        (wave * flex + flutter);

    worldPosition.xyz = instanceWindRoot + RotateAroundAxis(relativePosition,
        rotationAxis, rotationAngle);
}

void main()
{
    mat4 effectiveModelMatrix = modelMatrix;
    vec3 instanceWindRoot = windRoot;
    vec3 instanceWindAxis = windAxis;
    float instanceWindHeight = windHeight;
    vec3 localPosition = position;
    if (useSkinning != 0)
        localPosition = (CalculateSkinMatrix() * vec4(position, 1.0)).xyz;

    if (useInstanceBuffer != 0)
    {
        InstanceData instance = instances[instanceBaseOffset + gl_InstanceID];
        effectiveModelMatrix = instance.modelMatrix;
        instanceWindRoot = instance.windRootHeight.xyz;
        instanceWindHeight = instance.windRootHeight.w;
        instanceWindAxis = instance.windAxisUnused.xyz;
    }

    vec4 worldPosition = effectiveModelMatrix * vec4(localPosition, 1.0);
    ApplyVertexWind(worldPosition, instanceWindRoot, instanceWindAxis,
        instanceWindHeight);
    shadowTexcoord = flipAlphaCutoutV != 0 ?
        vec2(texcoord.x, 1.0 - texcoord.y) : texcoord;
    gl_Position = lightSpaceMatrix * worldPosition;
}
