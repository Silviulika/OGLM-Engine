#version 450 core

const int MaxLights = 8;

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec3 tangent;
layout(location = 3) in vec3 bitangent;
layout(location = 4) in vec2 texcoord;
layout(location = 5) in vec3 morphPosition;

uniform mat4 modelMatrix;
uniform mat3 normalMatrix;
uniform mat4 viewProjection;
uniform mat4 lightSpaceMatrix;
uniform vec4 clipPlane;
uniform int useClipPlane;
uniform int heightFieldUseMorph;
uniform float heightFieldMorphFactor;
uniform sampler2D heightFieldHeights;
uniform int heightFieldUseTexture;
uniform vec2 heightFieldWorldSize;
uniform float heightFieldScale;
uniform int heightFieldMorphStep;

out Vertex
{
    vec3 position;
    vec2 texcoord;
    mat3 tangentBasis;
    vec3 geometricNormal;
    vec4 lightSpacePosition;
} vout;

float HeightFieldSample(ivec2 coord)
{
    ivec2 size = textureSize(heightFieldHeights, 0);
    ivec2 maxCoord = max(size - ivec2(1), ivec2(0));
    coord = clamp(coord, ivec2(0), maxCoord);
    return texelFetch(heightFieldHeights, coord, 0).r * heightFieldScale;
}

vec2 HeightFieldSampleCoord(vec2 localXZ)
{
    ivec2 size = textureSize(heightFieldHeights, 0);
    if (size.x <= 1 || size.y <= 1)
        return vec2(0.0);

    vec2 sampleMax = vec2(size - ivec2(1));
    vec2 worldSize = max(abs(heightFieldWorldSize), vec2(0.0001));
    return clamp((localXZ / worldSize + vec2(0.5)) * sampleMax,
        vec2(0.0), sampleMax);
}

float HeightFieldHeightAtLocal(vec2 localXZ)
{
    vec2 sampleCoord = HeightFieldSampleCoord(localXZ);
    ivec2 c0 = ivec2(floor(sampleCoord));
    ivec2 c1 = c0 + ivec2(1);
    vec2 t = fract(sampleCoord);

    float h00 = HeightFieldSample(c0);
    float h10 = HeightFieldSample(ivec2(c1.x, c0.y));
    float h01 = HeightFieldSample(ivec2(c0.x, c1.y));
    float h11 = HeightFieldSample(c1);
    float h0 = mix(h00, h10, t.x);
    float h1 = mix(h01, h11, t.x);
    return mix(h0, h1, t.y);
}

float HeightFieldCoarseHeightAtLocal(vec2 localXZ, int step)
{
    ivec2 size = textureSize(heightFieldHeights, 0);
    if (size.x <= 1 || size.y <= 1)
        return HeightFieldHeightAtLocal(localXZ);

    step = max(step, 1);
    ivec2 maxCoord = size - ivec2(1);
    ivec2 coord = ivec2(round(HeightFieldSampleCoord(localXZ)));
    ivec2 c0 = (coord / step) * step;
    ivec2 c1 = min(c0 + ivec2(step), maxCoord);
    vec2 denom = max(vec2(c1 - c0), vec2(1.0));
    vec2 t = clamp(vec2(coord - c0) / denom, vec2(0.0), vec2(1.0));

    float h00 = HeightFieldSample(c0);
    float h10 = HeightFieldSample(ivec2(c1.x, c0.y));
    float h01 = HeightFieldSample(ivec2(c0.x, c1.y));
    float h11 = HeightFieldSample(c1);

    if (t.y >= t.x)
        return h00 * (1.0 - t.y) + h01 * (t.y - t.x) + h11 * t.x;

    return h00 * (1.0 - t.x) + h11 * t.y + h10 * (t.x - t.y);
}

void ApplyHeightField(inout vec3 localPosition, vec3 localMorphPosition)
{
    if (heightFieldUseTexture == 0)
        return;

    float morphFactor = clamp(heightFieldMorphFactor, 0.0, 1.0);
    float height = HeightFieldHeightAtLocal(localPosition.xz);
    float offsetY = localPosition.y;

    if (heightFieldUseMorph != 0)
    {
        height = mix(height,
            HeightFieldCoarseHeightAtLocal(localPosition.xz,
                heightFieldMorphStep),
            morphFactor);
        offsetY = mix(localPosition.y, localMorphPosition.y, morphFactor);
    }

    localPosition.y = height + offsetY;
}

void HeightFieldBasisAtLocal(vec2 localXZ, out vec3 localNormal,
    out vec3 localTangent)
{
    ivec2 size = textureSize(heightFieldHeights, 0);
    if (size.x <= 1 || size.y <= 1)
    {
        localNormal = vec3(0.0, 1.0, 0.0);
        localTangent = vec3(1.0, 0.0, 0.0);
        return;
    }

    ivec2 coord = ivec2(round(HeightFieldSampleCoord(localXZ)));
    vec2 worldSize = max(abs(heightFieldWorldSize), vec2(0.0001));
    float stepX = worldSize.x / max(float(size.x - 1), 1.0);
    float stepZ = worldSize.y / max(float(size.y - 1), 1.0);
    float leftH = HeightFieldSample(coord + ivec2(-1, 0));
    float rightH = HeightFieldSample(coord + ivec2(1, 0));
    float downH = HeightFieldSample(coord + ivec2(0, -1));
    float upH = HeightFieldSample(coord + ivec2(0, 1));

    localTangent = normalize(vec3(2.0 * stepX, rightH - leftH, 0.0));
    vec3 localBitangent = normalize(vec3(0.0, upH - downH, 2.0 * stepZ));
    localNormal = normalize(cross(localBitangent, localTangent));
}

void main()
{
    vec3 localPosition = position;
    if (heightFieldUseTexture != 0)
        ApplyHeightField(localPosition, morphPosition);
    else if (heightFieldUseMorph != 0)
        localPosition = mix(position, morphPosition, clamp(heightFieldMorphFactor, 0.0, 1.0));

    vec4 worldPos = modelMatrix * vec4(localPosition, 1.0);
    if (useClipPlane != 0)
        gl_ClipDistance[0] = dot(worldPos, clipPlane);

    vec3 localNormal = normal;
    vec3 localTangent = tangent;
    if (heightFieldUseTexture != 0)
        HeightFieldBasisAtLocal(localPosition.xz, localNormal, localTangent);

    vec3 N = normalize(normalMatrix * localNormal);
    vec3 T = normalize(normalMatrix * localTangent);
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

    gl_Position = viewProjection * worldPos;
}
