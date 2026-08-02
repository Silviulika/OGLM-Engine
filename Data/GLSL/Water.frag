#version 450 core

uniform sampler2D reflectionTexture;
uniform sampler2D sceneDepthTexture;
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
uniform int useSceneDepth;
uniform float nearPlane;
uniform float farPlane;
uniform vec3 foamColor;
uniform float foamIntensity;
uniform float shoreFoamDistance;
uniform float shoreFoamFeather;
uniform float shoreLineSmoothness;
uniform float foamNoiseScale;
uniform float crestFoamThreshold;
uniform float crestFoamIntensity;
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
    float waveHeight;
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

vec4 permute(vec4 x)
{
    return mod(((x * 34.0) + 1.0) * x, 289.0);
}

vec4 taylorInvSqrt(vec4 r)
{
    return 1.79284291400159 - 0.85373472095314 * r;
}

vec3 fade(vec3 t)
{
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

float cnoise(vec3 P)
{
    vec3 Pi0 = floor(P);
    vec3 Pi1 = Pi0 + vec3(1.0);
    Pi0 = mod(Pi0, 289.0);
    Pi1 = mod(Pi1, 289.0);
    vec3 Pf0 = fract(P);
    vec3 Pf1 = Pf0 - vec3(1.0);
    vec4 ix = vec4(Pi0.x, Pi1.x, Pi0.x, Pi1.x);
    vec4 iy = vec4(Pi0.yy, Pi1.yy);
    vec4 iz0 = Pi0.zzzz;
    vec4 iz1 = Pi1.zzzz;

    vec4 ixy = permute(permute(ix) + iy);
    vec4 ixy0 = permute(ixy + iz0);
    vec4 ixy1 = permute(ixy + iz1);

    vec4 gx0 = ixy0 / 7.0;
    vec4 gy0 = fract(floor(gx0) / 7.0) - 0.5;
    gx0 = fract(gx0);
    vec4 gz0 = vec4(0.5) - abs(gx0) - abs(gy0);
    vec4 sz0 = step(gz0, vec4(0.0));
    gx0 -= sz0 * (step(0.0, gx0) - 0.5);
    gy0 -= sz0 * (step(0.0, gy0) - 0.5);

    vec4 gx1 = ixy1 / 7.0;
    vec4 gy1 = fract(floor(gx1) / 7.0) - 0.5;
    gx1 = fract(gx1);
    vec4 gz1 = vec4(0.5) - abs(gx1) - abs(gy1);
    vec4 sz1 = step(gz1, vec4(0.0));
    gx1 -= sz1 * (step(0.0, gx1) - 0.5);
    gy1 -= sz1 * (step(0.0, gy1) - 0.5);

    vec3 g000 = vec3(gx0.x, gy0.x, gz0.x);
    vec3 g100 = vec3(gx0.y, gy0.y, gz0.y);
    vec3 g010 = vec3(gx0.z, gy0.z, gz0.z);
    vec3 g110 = vec3(gx0.w, gy0.w, gz0.w);
    vec3 g001 = vec3(gx1.x, gy1.x, gz1.x);
    vec3 g101 = vec3(gx1.y, gy1.y, gz1.y);
    vec3 g011 = vec3(gx1.z, gy1.z, gz1.z);
    vec3 g111 = vec3(gx1.w, gy1.w, gz1.w);

    vec4 norm0 = taylorInvSqrt(vec4(dot(g000, g000), dot(g010, g010),
        dot(g100, g100), dot(g110, g110)));
    g000 *= norm0.x;
    g010 *= norm0.y;
    g100 *= norm0.z;
    g110 *= norm0.w;
    vec4 norm1 = taylorInvSqrt(vec4(dot(g001, g001), dot(g011, g011),
        dot(g101, g101), dot(g111, g111)));
    g001 *= norm1.x;
    g011 *= norm1.y;
    g101 *= norm1.z;
    g111 *= norm1.w;

    float n000 = dot(g000, Pf0);
    float n100 = dot(g100, vec3(Pf1.x, Pf0.yz));
    float n010 = dot(g010, vec3(Pf0.x, Pf1.y, Pf0.z));
    float n110 = dot(g110, vec3(Pf1.xy, Pf0.z));
    float n001 = dot(g001, vec3(Pf0.xy, Pf1.z));
    float n101 = dot(g101, vec3(Pf1.x, Pf0.y, Pf1.z));
    float n011 = dot(g011, vec3(Pf0.x, Pf1.yz));
    float n111 = dot(g111, Pf1);

    vec3 fade_xyz = fade(Pf0);
    vec4 n_z = mix(vec4(n000, n100, n010, n110),
        vec4(n001, n101, n011, n111), fade_xyz.z);
    vec2 n_yz = mix(n_z.xy, n_z.zw, fade_xyz.y);
    return 2.2 * mix(n_yz.x, n_yz.y, fade_xyz.x);
}

float FoamNoise(vec2 p)
{
    float n = cnoise(vec3(p, time * 0.16));
    n += cnoise(vec3(p * 2.31 + 13.7, time * 0.29)) * 0.5;
    n += cnoise(vec3(p * 5.17 - 7.4, -time * 0.37)) * 0.25;
    return clamp(n / 1.75 * 0.5 + 0.5, 0.0, 1.0);
}

float FoamLace(vec2 p)
{
    float n = abs(cnoise(vec3(p, time * 0.18)));
    n += abs(cnoise(vec3(p * 2.9 + 3.1, -time * 0.27))) * 0.45;
    return clamp(n / 1.45, 0.0, 1.0);
}

float LinearizeDepth(float depth)
{
    float z = depth * 2.0 - 1.0;
    return (2.0 * nearPlane * farPlane) /
        (farPlane + nearPlane - z * (farPlane - nearPlane));
}

void AccumulateSceneDepth(vec2 uv, float weight, inout float total, inout float weightSum)
{
    float sampleDepth = texture(sceneDepthTexture, clamp(uv, vec2(0.0), vec2(1.0))).r;
    if (sampleDepth < 0.999999)
    {
        total += sampleDepth * weight;
        weightSum += weight;
    }
}

float FilteredSceneDepth(vec2 screenUV, float smoothness)
{
    vec2 depthSize = vec2(textureSize(sceneDepthTexture, 0));
    vec2 texel = 1.0 / max(depthSize, vec2(1.0));
    float radius = clamp(smoothness, 0.0, 12.0);
    if (radius <= 0.001)
        return texture(sceneDepthTexture, clamp(screenUV, vec2(0.0), vec2(1.0))).r;

    float nearRadius = max(radius, 0.35);
    float farRadius = nearRadius * 2.0;
    float farWeight = smoothstep(1.0, 4.0, radius);
    float total = 0.0;
    float weightSum = 0.0;

    AccumulateSceneDepth(screenUV, 4.0, total, weightSum);
    AccumulateSceneDepth(screenUV + texel * vec2( nearRadius,  0.0), 2.0, total, weightSum);
    AccumulateSceneDepth(screenUV + texel * vec2(-nearRadius,  0.0), 2.0, total, weightSum);
    AccumulateSceneDepth(screenUV + texel * vec2( 0.0,  nearRadius), 2.0, total, weightSum);
    AccumulateSceneDepth(screenUV + texel * vec2( 0.0, -nearRadius), 2.0, total, weightSum);
    AccumulateSceneDepth(screenUV + texel * vec2( nearRadius,  nearRadius), 1.0, total, weightSum);
    AccumulateSceneDepth(screenUV + texel * vec2(-nearRadius,  nearRadius), 1.0, total, weightSum);
    AccumulateSceneDepth(screenUV + texel * vec2( nearRadius, -nearRadius), 1.0, total, weightSum);
    AccumulateSceneDepth(screenUV + texel * vec2(-nearRadius, -nearRadius), 1.0, total, weightSum);
    AccumulateSceneDepth(screenUV + texel * vec2( farRadius,  0.0), 0.85 * farWeight, total, weightSum);
    AccumulateSceneDepth(screenUV + texel * vec2(-farRadius,  0.0), 0.85 * farWeight, total, weightSum);
    AccumulateSceneDepth(screenUV + texel * vec2( 0.0,  farRadius), 0.85 * farWeight, total, weightSum);
    AccumulateSceneDepth(screenUV + texel * vec2( 0.0, -farRadius), 0.85 * farWeight, total, weightSum);
    AccumulateSceneDepth(screenUV + texel * vec2( farRadius,  farRadius), 0.45 * farWeight, total, weightSum);
    AccumulateSceneDepth(screenUV + texel * vec2(-farRadius,  farRadius), 0.45 * farWeight, total, weightSum);
    AccumulateSceneDepth(screenUV + texel * vec2( farRadius, -farRadius), 0.45 * farWeight, total, weightSum);
    AccumulateSceneDepth(screenUV + texel * vec2(-farRadius, -farRadius), 0.45 * farWeight, total, weightSum);

    if (weightSum <= 0.0)
        return 1.0;

    return total / weightSum;
}

float ShoreFoam(vec2 screenUV, vec2 worldXZ)
{
    if (useSceneDepth == 0)
        return 0.0;
    if (any(lessThan(screenUV, vec2(0.0))) ||
        any(greaterThan(screenUV, vec2(1.0))))
        return 0.0;

    float lineSmooth = clamp(shoreLineSmoothness, 0.0, 12.0);
    float sceneDepth = FilteredSceneDepth(screenUV, lineSmooth);
    if (sceneDepth >= 0.999999)
        return 0.0;

    float sceneLinearDepth = LinearizeDepth(sceneDepth);
    float waterLinearDepth = LinearizeDepth(gl_FragCoord.z);
    float depthGap = sceneLinearDepth - waterLinearDepth;
    if (depthGap <= 0.0)
        return 0.0;

    float foamWidth = max(shoreFoamDistance, 0.05);
    float feather = max(shoreFoamFeather, 0.02);
    float noiseScale = max(foamNoiseScale, 0.02);
    float scaledDepth = clamp(depthGap / foamWidth, 0.0, 1.0);
    float smoothBoost = lineSmooth * 0.01;
    float depthAA = max(fwidth(scaledDepth) * (2.5 + lineSmooth * 0.75),
        0.002 + lineSmooth * 0.0008);
    float drift = time * max(waveSpeed, 0.08);

    vec2 shoreUV = worldXZ * noiseScale + vec2(drift * 0.18, -drift * 0.11);
    vec2 fineUV = worldXZ * noiseScale * 3.85 + vec2(-drift * 0.44, drift * 0.27);
    float broadNoise = FoamNoise(shoreUV);
    float laceNoise = FoamLace(fineUV);

    float shallowMask = 1.0 - smoothstep(0.12 - smoothBoost,
        1.0 + feather * 0.85 + depthAA + smoothBoost, scaledDepth);
    float noisyReach = smoothstep(scaledDepth - feather * 0.35 - depthAA,
        scaledDepth + feather * 0.35 + depthAA + smoothBoost,
        0.42 + broadNoise * 0.48);
    float raggedPatches = smoothstep(0.42, 0.76, broadNoise) *
        smoothstep(0.16, 0.68, laceNoise);
    float waterLine = 1.0 - smoothstep(0.0,
        max(0.2, feather * 0.65) + broadNoise * 0.12 + depthAA +
        smoothBoost * 1.4, scaledDepth);

    return clamp(max(waterLine * mix(0.38, 0.72, laceNoise),
        shallowMask * noisyReach * raggedPatches), 0.0, 1.0);
}

float CrestFoam(vec2 worldXZ, vec3 normal, float waveHeight)
{
    float amplitude = max(waveStrength, 0.001);
    float normalizedPeak = waveHeight / max(amplitude * 0.62, 0.001);
    float heightMask = smoothstep(crestFoamThreshold, 1.0, normalizedPeak);
    float slopeMask = smoothstep(0.04, 0.34, 1.0 - clamp(normal.y, 0.0, 1.0));
    float drift = time * max(waveSpeed, 0.08);
    float foamScale = max(waveScale * max(foamNoiseScale, 0.02), 0.08);
    float patchNoise = FoamNoise(worldXZ * foamScale * 0.9 +
        vec2(drift * 0.22, -drift * 0.17));
    float laceNoise = FoamLace(worldXZ * foamScale * 2.4 +
        vec2(-drift * 0.7, drift * 0.38));
    float breakup = smoothstep(0.46, 0.82, patchNoise) *
        smoothstep(0.14, 0.72, laceNoise);

    return crestFoamIntensity * heightMask * mix(0.38, 1.0, slopeMask) * breakup;
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

    vec2 screenUV = (gl_FragCoord.xy - reflectionViewport.xy) / reflectionViewport.zw;
    vec2 reflectionUV = screenUV;
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

    float shoreFoam = ShoreFoam(screenUV, vin.position.xz);
    float crestFoam = CrestFoam(vin.position.xz, N, vin.waveHeight);
    float foam = clamp(shoreFoam + crestFoam * 0.85, 0.0, 1.0);
    float foamPaint = clamp(foam * foamIntensity, 0.0, 1.0);
    vec3 whiteFoam = mix(foamColor * 0.92, vec3(1.0), smoothstep(0.35, 0.9, foamPaint));
    resultColor = clamp(mix(resultColor, whiteFoam, foamPaint) +
        whiteFoam * foam * 0.18, 0.0, 1.0);

    resultColor = ApplyFog(resultColor, vin.position);

    color = vec4(resultColor, clamp(alpha + foamPaint * 0.30, 0.0, 1.0));
}
