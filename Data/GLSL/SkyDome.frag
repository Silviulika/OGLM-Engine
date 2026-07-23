#version 450 core

in vec3 vDirection;

uniform vec4 topColor;
uniform vec4 horizonColor;
uniform vec4 bottomColor;
uniform vec4 nightColor;
uniform vec4 sunColor;
uniform vec3 sunDirection;
uniform float sunSize;
uniform float sunGlow;
uniform float sunIntensity;
uniform float starIntensity;
uniform float starDensity;
uniform float starGlare;
uniform vec2 starSize;
uniform bool twinkleStars;
uniform float time;
uniform bool cloudsEnabled;
uniform float cloudCoverage;
uniform float cloudScale;
uniform float cloudSpeed;
uniform float cloudOpacity;
uniform vec4 cloudColor;

out vec4 FragColor;

const float PI = 3.14159265359;

float hash12(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float valueNoise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);

    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p)
{
    float value = 0.0;
    float amplitude = 0.5;

    for (int i = 0; i < 5; ++i)
    {
        value += valueNoise(p) * amplitude;
        p = p * 2.03 + vec2(17.7, 11.3);
        amplitude *= 0.5;
    }

    return value;
}

vec2 directionToSkyUV(vec3 direction)
{
    float u = atan(direction.z, direction.x) / (2.0 * PI) + 0.5;
    float v = asin(clamp(direction.y, -1.0, 1.0)) / PI + 0.5;
    return vec2(u, v);
}

float starField(vec2 uv, float horizonFactor)
{
    vec2 grid = uv * starDensity;
    vec2 cell = floor(grid);
    vec2 localPos = fract(grid) - 0.5;

    float seed = hash12(cell);

    // Star rarity
    float star = step(0.9965, seed);

    float minStarSize = max(0.001, min(starSize.x, starSize.y));
    float maxStarSize = max(minStarSize, max(starSize.x, starSize.y));

    float size = mix(
        minStarSize,
        maxStarSize,
        hash12(cell + 19.17)
    );
	
	// Near the horizon, shrink stars and reduce glare.
	// This hides the skydome projection stretching.
	float horizonSize = mix(0.35, 1.0, horizonFactor);
	float glareAmount = starGlare * smoothstep(0.20, 1.0, horizonFactor);

	size *= horizonSize;

    float brightness = mix(0.35, 1.0, hash12(cell + 7.31));

    float d = length(localPos);

    // Round bright center
    float core = smoothstep(size, 0.0, d);

    // Round soft glow / glare
    float glowRadius = size * mix(2.5, 5.0, glareAmount);
    float glow = smoothstep(glowRadius, 0.0, d);

    // Stronger stars get a little more halo
    float brightStar = smoothstep(0.6, 1.0, brightness);

    float shape =
        core +
        glow * 0.22 * glareAmount * mix(0.6, 1.0, brightStar);

    return star * shape * brightness;
}

void main()
{
    vec3 direction = normalize(vDirection);
    vec3 sunDir = normalize(sunDirection);
    float height = clamp(direction.y * 0.5 + 0.5, 0.0, 1.0);

    vec3 lowerSky = mix(bottomColor.rgb, horizonColor.rgb, smoothstep(0.00, 0.52, height));
    vec3 upperSky = mix(horizonColor.rgb, topColor.rgb, smoothstep(0.44, 1.00, height));
    vec3 skyColor = mix(lowerSky, upperSky, smoothstep(0.42, 0.58, height));

    float dayAmount = smoothstep(-0.12, 0.28, sunDir.y);
    skyColor = mix(nightColor.rgb, skyColor, dayAmount);

    float sunAmount = max(dot(direction, sunDir), 0.0);
    float sunDisc = smoothstep(cos(max(0.001, sunSize)), 1.0, sunAmount);
    float sunHalo = pow(sunAmount, max(1.0, sunGlow)) * 0.35;
    skyColor += sunColor.rgb * (sunDisc * sunIntensity + sunHalo * sunIntensity) * dayAmount;

    vec2 skyUV = directionToSkyUV(direction);
    float nightAmount = 1.0 - smoothstep(-0.08, 0.22, sunDir.y);
	// 0 near/below horizon, 1 higher in the sky.
	// Increase the second value if you want stars to disappear higher up.
	float starHorizonFactor = smoothstep(0.02, 0.24, direction.y);

	float stars = starField(skyUV, starHorizonFactor);
    if (twinkleStars)
    {
        vec2 starCell = floor(skyUV * starDensity);
        stars *= 0.68 + 0.32 * sin(time * 4.0 + hash12(starCell) * 6.2831853);
    }
    skyColor += vec3(stars * starIntensity * nightAmount);

	if (cloudsEnabled)
	{
		// Allow clouds near the horizon, but avoid projection blow-up.
		float horizonFade = smoothstep(-0.04, 0.12, direction.y);

		// Flatter cloud layer. Lower divisor = more horizon stretching,
		// higher divisor = calmer clouds.
		float layerY = max(direction.y + 0.18, 0.24);
		vec2 cloudUV = direction.xz / layerY;

		// cloudScale is frequency:
		// 0.18..0.35 = large cloud masses
		// 0.60..1.50 = small wispy/noisy clouds
		vec2 wind = vec2(time * cloudSpeed, time * cloudSpeed * 0.22);
		vec2 p = cloudUV * cloudScale + wind;

		// Gentle warp only. Strong warp causes spiral/ribbon clouds.
		vec2 warp;
		warp.x = fbm(p * 0.70 + vec2(13.1, 71.7));
		warp.y = fbm(p * 0.70 + vec2(91.3, 21.4));
		warp = warp * 2.0 - 1.0;

		vec2 q = p + warp * 0.30;

		// Large cloud islands.
		float large = fbm(q * 0.55);

		// Puffy inner structure.
		float puffs = fbm(q * 1.65 + large * 0.85);

		// Small edge breakup, kept weak.
		float detail = fbm(q * 4.20 + puffs * 0.45);

		float cloudField = large * 0.62 + puffs * 0.31 + detail * 0.07;

		// Coverage mapping made much more usable.
		// 0.35 should show a few clouds.
		// 0.60 should show natural cumulus groups.
		// 0.90 should become overcast/stormy.
		float coverage = clamp(cloudCoverage, 0.0, 1.0);
		float threshold = mix(0.68, 0.30, coverage);
		float softness = mix(0.18, 0.09, coverage);

		float cloudMask = smoothstep(threshold, threshold + softness, cloudField);

		// Make clouds fuller/rounder, not thin wisps.
		cloudMask = pow(clamp(cloudMask, 0.0, 1.0), 0.72);

		// Keep them mostly in the upper sky, but still visible near horizon.
		cloudMask *= horizonFade;

		// Slightly fade at the zenith so it does not become a flat ceiling.
		cloudMask *= 1.0 - smoothstep(0.92, 1.0, direction.y) * 0.25;

		// Lighting.
		float sunFacing = clamp(dot(direction, sunDir) * 0.5 + 0.5, 0.0, 1.0);

		vec3 cloudBase = cloudColor.rgb * mix(0.55, 0.96, dayAmount);
		vec3 warmLight = sunColor.rgb * pow(sunFacing, 3.0) * 0.22 * dayAmount;

		// Internal gray/white variation gives a puffy look.
		vec3 cloudShade = mix(vec3(0.70, 0.76, 0.84), vec3(1.0), puffs);

		vec3 litCloud = cloudBase * cloudShade + warmLight;

		float finalCloudAlpha = cloudMask * clamp(cloudOpacity, 0.0, 1.0);

		skyColor = mix(skyColor, litCloud, finalCloudAlpha);
	}

    FragColor = vec4(skyColor, 1.0);
}
