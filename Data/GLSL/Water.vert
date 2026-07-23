#version 450 core

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec3 tangent;
layout(location = 3) in vec3 bitangent;
layout(location = 4) in vec2 texcoord;

uniform mat4 modelMatrix;
uniform mat4 viewProjection;
uniform float time;
uniform float waveScale;
uniform float waveSpeed;
uniform float waveStrength;

out Vertex
{
    vec3 position;
    vec3 normal;
    vec2 texcoord;
    vec4 projectedPosition;
} vout;

struct WaveSample
{
    float height;
    vec2 slope;
};

vec2 WarpWaterPoint(vec2 point, float frequency, float speed, float amplitude)
{
    float warpFrequency = max(frequency * 0.18, 0.025);
    vec2 warp;

    warp.x = sin(point.y * warpFrequency + point.x * warpFrequency * 0.31 + speed * 0.11);
    warp.x += cos(point.x * warpFrequency * 0.73 - point.y * warpFrequency * 0.19 - speed * 0.07) * 0.55;

    warp.y = cos(point.x * warpFrequency * 0.91 + point.y * warpFrequency * 0.27 - speed * 0.09);
    warp.y += sin(point.y * warpFrequency * 0.61 - point.x * warpFrequency * 0.43 + speed * 0.13) * 0.48;

    return point + warp * (1.8 + amplitude * 0.65);
}

float LocalWaterEnergy(vec2 point, float speed)
{
    float energy = sin(point.x * 0.071 + point.y * 0.113 + speed * 0.13);
    energy += cos(point.x * 0.039 - point.y * 0.087 - speed * 0.07) * 0.65;
    energy += sin((point.x + point.y) * 0.026 + speed * 0.05) * 0.42;

    return mix(0.72, 1.22, clamp(energy * 0.22 + 0.5, 0.0, 1.0));
}

void AddSineWave(inout WaveSample waveData, vec2 point, vec2 direction,
                 float frequency, float speed, float amplitude,
                 float phaseOffset)
{
    float phase = dot(point, direction) * frequency + speed + phaseOffset;
    float wave = sin(phase);
    float grad = cos(phase) * frequency * amplitude;

    waveData.height += wave * amplitude;
    waveData.slope += direction * grad;
}

void AddCosineWave(inout WaveSample waveData, vec2 point, vec2 direction,
                   float frequency, float speed, float amplitude,
                   float phaseOffset)
{
    float phase = dot(point, direction) * frequency + speed + phaseOffset;
    float wave = cos(phase);
    float grad = -sin(phase) * frequency * amplitude;

    waveData.height += wave * amplitude;
    waveData.slope += direction * grad;
}

WaveSample EvaluateWaterWaves(vec2 worldXZ)
{
    WaveSample waveData;
    waveData.height = 0.0;
    waveData.slope = vec2(0.0);

    float frequency = max(abs(waveScale), 0.001);
    float speed = time * max(waveSpeed, 0.0);
    float amplitude = max(waveStrength, 0.0);
    vec2 warpedXZ = WarpWaterPoint(worldXZ, frequency, speed, amplitude);
    float energy = LocalWaterEnergy(worldXZ, speed);

    AddSineWave(waveData, warpedXZ, normalize(vec2(1.00, 0.18)),
        frequency, speed * 1.20, amplitude * 0.30 * energy, 0.0);
    AddCosineWave(waveData, warpedXZ, normalize(vec2(-0.31, 0.95)),
        frequency * 1.62, -speed * 1.55, amplitude * 0.20 * energy, 1.7);
    AddSineWave(waveData, warpedXZ + vec2(11.3, -4.7), normalize(vec2(0.62, -0.78)),
        frequency * 2.27, speed * 0.82, amplitude * 0.14 * energy, 3.2);
    AddCosineWave(waveData, worldXZ + vec2(-6.5, 8.1), normalize(vec2(-0.86, -0.51)),
        frequency * 0.36, speed * 0.38, amplitude * 0.22 * energy, 0.9);
    AddSineWave(waveData, worldXZ + vec2(5.3, 2.9), normalize(vec2(0.16, 0.99)),
        frequency * 0.91, -speed * 0.63, amplitude * 0.08 * energy, 5.3);
    AddCosineWave(waveData, warpedXZ + vec2(-9.2, -3.4), normalize(vec2(0.92, -0.39)),
        frequency * 3.18, speed * 1.92, amplitude * 0.05 * energy, 2.4);

    waveData.slope = clamp(waveData.slope, vec2(-3.0), vec2(3.0));
    return waveData;
}

void main()
{
    vec4 worldPosition = modelMatrix * vec4(position, 1.0);
    WaveSample waves = EvaluateWaterWaves(worldPosition.xz);
    worldPosition.y += waves.height;

    vec3 waveNormal = normalize(vec3(-waves.slope.x, 1.0, -waves.slope.y));

    vout.position = worldPosition.xyz;
    vout.normal = waveNormal;
    vout.texcoord = texcoord;
    vout.projectedPosition = viewProjection * worldPosition;

    gl_Position = vout.projectedPosition;
}
