#version 450 core

const int MaxLights = 8;

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec3 tangent;
layout(location = 3) in vec3 bitangent;
layout(location = 4) in vec2 texcoord;
layout(location = 5) in vec3 morphPosition;
layout(location = 6) in uvec4 joints0;
layout(location = 7) in vec4 weights0;
layout(location = 8) in uvec4 joints1;
layout(location = 9) in vec4 weights1;

layout(std430, binding = 3) readonly buffer SkinPalette
{
    mat4 skinMatrices[];
};

uniform mat4 modelMatrix;
uniform mat4 viewProjection;
uniform mat4 lightSpaceMatrix;
uniform mat4 lightSpaceMatrices[MaxLights];
uniform vec4 clipPlane;
uniform int useClipPlane;
uniform int heightFieldUseMorph;
uniform float heightFieldMorphFactor;
uniform int useSkinning;
uniform int skinMatrixCount;
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
    vec4 lightSpacePositions[MaxLights];
} vout;

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

void ApplyVertexWind(inout vec4 worldPosition, out vec3 rotationAxis,
    out float rotationAngle)
{
    rotationAxis = vec3(0.0, 0.0, 1.0);
    rotationAngle = 0.0;
    if (useVertexWind == 0 || windHeight <= 1e-5 || windStrength <= 0.0)
        return;

    vec3 treeAxis = windAxis;
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
    rotationAxis = normalize(cross(treeAxis, direction));

    vec3 relativePosition = worldPosition.xyz - windRoot;
    float heightRatio = clamp(dot(relativePosition, treeAxis) /
        max(windHeight, 1e-5), 0.0, 1.0);
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

    rotationAngle = windStrength * heightProfile * gust *
        (wave * flex + flutter);
    worldPosition.xyz = windRoot + RotateAroundAxis(relativePosition,
        rotationAxis, rotationAngle);
}

void main()
{
    int i;
    vec3 windRotationAxis;
    float windRotationAngle;
    vec3 localPosition = position;
    vec3 localNormal = normal;
    vec3 localTangent = tangent;
    vec3 localBitangent = bitangent;
    if (heightFieldUseMorph != 0)
        localPosition = mix(position, morphPosition, clamp(heightFieldMorphFactor, 0.0, 1.0));

    if (useSkinning != 0)
    {
        mat4 skinMatrix = CalculateSkinMatrix();
        localPosition = (skinMatrix * vec4(localPosition, 1.0)).xyz;
        localNormal = mat3(skinMatrix) * localNormal;
        localTangent = mat3(skinMatrix) * localTangent;
        localBitangent = mat3(skinMatrix) * localBitangent;
    }

    vec4 worldPos = modelMatrix * vec4(localPosition, 1.0);
    ApplyVertexWind(worldPos, windRotationAxis, windRotationAngle);
    if (useClipPlane != 0)
        // Match the terrain reflection overlap below the animated wave troughs.
        gl_ClipDistance[0] = dot(worldPos, clipPlane) + 0.55;

    vout.position = worldPos.xyz;
    vout.lightSpacePosition = lightSpaceMatrix * worldPos;
    for (i = 0; i < MaxLights; ++i)
        vout.lightSpacePositions[i] = lightSpaceMatrices[i] * worldPos;

    // Flip V if needed by asset pipeline
	vout.texcoord = vec2(texcoord.x, 1.0 - texcoord.y);
	//vout.texcoord = texcoord;

    // Proper normal transform. Imported files can contain a TANGENT accessor
    // filled with zeroes, so keep the shader finite even for malformed data.
    mat3 normalMatrix = transpose(inverse(mat3(modelMatrix)));
	
	vec3 N = normalMatrix * localNormal;
    if (dot(N, N) <= 1e-10)
        N = vec3(0.0, 1.0, 0.0);
    else
        N = normalize(N);
    if (useVertexWind != 0)
        N = RotateAroundAxis(N, windRotationAxis, windRotationAngle);

	vec3 T = normalMatrix * localTangent;
    if (useVertexWind != 0)
        T = RotateAroundAxis(T, windRotationAxis, windRotationAngle);
	T = T - N * dot(N, T);
    if (dot(T, T) <= 1e-10)
    {
        vec3 axis = abs(N.x) < 0.9 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
        T = normalize(axis - N * dot(N, axis));
    }
    else
        T = normalize(T);

    vec3 B = normalMatrix * localBitangent;
    if (useVertexWind != 0)
        B = RotateAroundAxis(B, windRotationAxis, windRotationAngle);
    B = B - N * dot(N, B) - T * dot(T, B);
    if (dot(B, B) <= 1e-10)
        B = normalize(cross(N, T));
    else
        B = normalize(B);

	vout.tangentBasis = mat3(T, B, N);
    vout.geometricNormal = N;

    gl_Position = viewProjection * worldPos;
}
