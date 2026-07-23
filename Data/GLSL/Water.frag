#version 450 core

uniform sampler2D reflectionTexture;
uniform vec3 eyePosition;
uniform vec4 waterColor;
uniform vec4 deepColor;
uniform float time;
uniform float reflectionStrength;
uniform float waveScale;
uniform float waveSpeed;
uniform float waveStrength;
uniform float fresnelPower;
uniform float alpha;
uniform vec2 reflectionTextureSize;
uniform vec4 reflectionViewport;
uniform int useFog;
uniform vec4 fogColor;
uniform float fogDensity;
uniform float fogStart;
uniform float fogEnd;

in Vertex
{
    vec3 position;
    vec3 normal;
    vec2 texcoord;
    vec4 projectedPosition;
} vin;

out vec4 color;

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

vec2 WaveOffset(vec3 worldPosition)
{
    float frequency = max(abs(waveScale), 0.001);
    float t = time * max(waveSpeed, 0.0);
    float amplitude = max(waveStrength, 0.0);
    vec2 sourcePoint = worldPosition.xz;
    vec2 point = WarpWaterPoint(sourcePoint, frequency, t, amplitude);
    float energy = LocalWaterEnergy(sourcePoint, t);

    float w1 = sin(dot(point, normalize(vec2(1.00, 0.18))) * frequency + t * 1.20);
    float w2 = cos(dot(point, normalize(vec2(-0.31, 0.95))) * frequency * 1.62 - t * 1.55 + 1.7);
    float w3 = sin(dot(point + vec2(11.3, -4.7), normalize(vec2(0.62, -0.78))) * frequency * 2.27 + t * 0.82 + 3.2);
    float w4 = cos(dot(sourcePoint + vec2(-6.5, 8.1), normalize(vec2(-0.86, -0.51))) * frequency * 0.36 + t * 0.38 + 0.9);
    float w5 = sin(dot(sourcePoint + vec2(5.3, 2.9), normalize(vec2(0.16, 0.99))) * frequency * 0.91 - t * 0.63 + 5.3);

    float distortion = clamp(waveStrength * 0.0065, 0.0, 0.045);
    return vec2(w1 + w3 * 0.35 - w4 * 0.28,
                w2 - w3 * 0.28 + w5 * 0.24) * distortion * energy;
}

vec3 ApplyFog(vec3 inputColor, vec3 worldPosition)
{
    if (useFog == 0)
        return inputColor;

    float distanceToEye = length(eyePosition - worldPosition);
    float rangeVisibility = 1.0 - smoothstep(fogStart, max(fogStart + 0.001, fogEnd), distanceToEye);
    float density = max(fogDensity, 0.0);
    float densityVisibility = exp(-pow(density * distanceToEye, 2.0));
    float visibility = clamp(min(rangeVisibility, densityVisibility), 0.0, 1.0);

    return mix(fogColor.rgb, inputColor, visibility);
}

void main()
{
    vec3 N = normalize(vin.normal);
    vec3 V = normalize(eyePosition - vin.position);

    vec2 reflectionUV = (gl_FragCoord.xy - reflectionViewport.xy) / reflectionViewport.zw;
    reflectionUV.x = 1.0 - reflectionUV.x;

	vec2 waveOffset = WaveOffset(vin.position);

	// Fade distortion near the reflection texture edges to avoid clamped smearing.
	vec2 edgeDistance = min(reflectionUV, 1.0 - reflectionUV);
	float edgeFade = smoothstep(0.0, 0.08, min(edgeDistance.x, edgeDistance.y));

	reflectionUV += waveOffset * edgeFade;
	reflectionUV = clamp(reflectionUV, vec2(0.001), vec2(0.999));

	vec3 reflectionColor = texture(reflectionTexture, reflectionUV).rgb;

    float facing = clamp(dot(N, V), 0.0, 1.0);
    float fresnel = pow(1.0 - facing, max(fresnelPower, 0.001));
    float reflectionMix = clamp((0.12 + fresnel) * reflectionStrength, 0.0, 1.0);

    float shallow = clamp(facing * 0.55 + 0.25, 0.0, 1.0);
    vec3 baseWater = mix(deepColor.rgb, waterColor.rgb, shallow);
    vec3 resultColor = mix(baseWater, reflectionColor, reflectionMix);

    vec3 halfVector = normalize(V + normalize(vec3(-0.25, 1.0, 0.15)));
    float sparkle = pow(max(dot(N, halfVector), 0.0), 96.0) * 0.08;
    resultColor += vec3(sparkle);
    resultColor = ApplyFog(resultColor, vin.position);

    color = vec4(resultColor, clamp(alpha, 0.0, 1.0));
}
