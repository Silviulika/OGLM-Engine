#version 450 core

layout(location = 0) in vec3 position;

uniform mat4 modelMatrix;
uniform mat4 viewProjection;
uniform sampler2D heightFieldHeights;
uniform int heightFieldUseTexture;
uniform vec2 heightFieldWorldSize;
uniform float heightFieldScale;

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

void ApplyHeightField(inout vec3 localPosition)
{
    if (heightFieldUseTexture == 0)
        return;

    localPosition.y += HeightFieldHeightAtLocal(localPosition.xz);
}

void main()
{
    vec3 localPosition = position;
    ApplyHeightField(localPosition);
    gl_Position = viewProjection * modelMatrix * vec4(localPosition, 1.0);
}
