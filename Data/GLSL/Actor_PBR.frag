#version 450 core

const float PI = 3.14159265359;
const float Epsilon = 0.00001;
const float MinSurfaceRoughness = 0.55;
const float NormalMapStrength = 0.65;
const float SpecularAAAmount = 0.45;
const int MaxLights = 8;
const int MaxActorPOMLayers = 6;
const float MaxActorHeightScale = 0.005;

struct Light
{
    int enabled;
    int type;                     // 0 = directional, 1 = point, 2 = spot
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
    vec3 position;
    vec3 direction;
    float constantAttenuation;
    float linearAttenuation;
    float quadraticAttenuation;
    float spotCutoff;             // cosine of outer cone angle
    float spotExponent;
};

uniform float gamma;
uniform int layers;
uniform float pivot;
uniform float metallicMult;
uniform float specularLevel;
uniform float heightScale;
uniform float hdrExposure;
uniform int useParallaxMapping;
uniform float alpha; // 0.0 to 1.0
uniform int usePostToneMapping;

uniform int lightCount;
uniform Light lights[MaxLights];
uniform vec3 eyePosition;

uniform sampler2D albedoTexture;
uniform sampler2D normalTexture;
uniform sampler2D heightTexture;
uniform sampler2D metalnessTexture;
uniform sampler2D roughnessTexture;
uniform sampler2D specularTexture;
uniform sampler2D ambientOcclusionTexture;
uniform sampler2D specularBRDF_LUT;
uniform sampler2DArray shadowMap;
uniform int useShadowMap;
uniform int shadowLightIndex;
uniform float shadowStrength;
uniform int shadowMapCount;
uniform int shadowMapIndices[MaxLights];
uniform float shadowStrengths[MaxLights];
uniform float ambientShadowStrength;
uniform int useFog;
uniform vec4 fogColor;
uniform float fogDensity;
uniform float fogStart;
uniform float fogEnd;

in Vertex
{
    vec3 position;
    vec2 texcoord;
    mat3 tangentBasis;
    vec3 geometricNormal;
    vec4 lightSpacePosition;
    vec4 lightSpacePositions[MaxLights];
} vin;

out vec4 color;

// Fresnel
vec3 FresnelSchlick(float cosTheta, vec3 F0)
{
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

// GGX Distribution
float DistributionGGX(vec3 N, vec3 H, float roughness)
{
    float a = roughness * roughness;
    float a2 = a * a;

    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;

    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    
    return a2 / max(PI * denom * denom, Epsilon);
}

// Geometry
float GeometrySchlickGGX(float NdotV, float roughness)
{
    float r = roughness + 1.0;
    float k = (r * r) / 8.0;

    return NdotV / (NdotV * (1.0 - k) + k);
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness)
{
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);

    float ggx1 = GeometrySchlickGGX(NdotV, roughness);
    float ggx2 = GeometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}

vec2 ParallaxOcclusionMapping(sampler2D depthMap, vec2 uv, vec2 displacement,
                              float pivot, int layerCount)
{
    float layerDepth = 1.0 / float(layerCount);
    float currentLayerDepth = 0.0;

    vec2 deltaUv = displacement / float(layerCount);
    vec2 currentUv = uv + pivot * displacement;
    
    // Use textureGrad to avoid the MIP-mapping seam bugs discussed earlier
    vec2 dx = dFdx(uv);
    vec2 dy = dFdy(uv);
    float currentDepth = textureGrad(depthMap, currentUv, dx, dy).r;
	//float currentDepth = 1.0 - textureGrad(depthMap, currentUv, dx, dy).r;
	//float currentDepth = - textureGrad(depthMap, currentUv, dx, dy).r;

    for(int i = 0; i < layerCount; i++)
    {
        if(currentLayerDepth > currentDepth)
            break;

        currentUv -= deltaUv;
        currentDepth = textureGrad(depthMap, currentUv, dx, dy).r;
        currentLayerDepth += layerDepth;
    }

    vec2 prevUv = currentUv + deltaUv;
    float endDepth = currentDepth - currentLayerDepth;
    float startDepth = textureGrad(depthMap, prevUv, dx, dy).r - currentLayerDepth + layerDepth;
	//float startDepth = (1.0 - textureGrad(depthMap, prevUv, dx, dy).r) - currentLayerDepth + layerDepth;
	//float startDepth = - textureGrad(depthMap, prevUv, dx, dy).r - currentLayerDepth + layerDepth;
	
    float w = endDepth / (endDepth - startDepth);

    return mix(currentUv, prevUv, w);
}

float ShadowVisibility(vec4 lightSpacePosition, int shadowLayer, float lightShadowStrength, vec3 normal, vec3 lightDir)
{
    if (useShadowMap == 0 || shadowLayer < 0 || shadowLayer >= shadowMapCount)
        return 1.0;

    vec3 projCoords = lightSpacePosition.xyz / lightSpacePosition.w;
    projCoords = projCoords * 0.5 + 0.5;

    if (projCoords.x < 0.0 || projCoords.x > 1.0 ||
        projCoords.y < 0.0 || projCoords.y > 1.0 ||
        projCoords.z < 0.0 || projCoords.z > 1.0)
        return 1.0;

    float currentDepth = projCoords.z;

    // Start small. Increase only if you see acne.
    float normalFacing = clamp(dot(normal, lightDir), 0.0, 1.0);
    float bias = max(0.00035 * (1.0 - normalFacing), 0.00008);

    vec2 texelSize = 1.0 / vec2(textureSize(shadowMap, 0).xy);
    float filterRadius = 1.25;
    float compareWidth = max(bias * 2.0, 0.00018);
    float receiverDepth = currentDepth - bias;
    float randomAngle = fract(sin(dot(floor(gl_FragCoord.xy), vec2(12.9898, 78.233))) * 43758.5453) * 6.28318530718;
    float s = sin(randomAngle);
    float c = cos(randomAngle);
    mat2 rotation = mat2(c, -s, s, c);
    const vec2 poissonDisk[12] = vec2[](
        vec2(-0.613392,  0.617481),
        vec2( 0.170019, -0.040254),
        vec2(-0.299417,  0.791925),
        vec2( 0.645680,  0.493210),
        vec2(-0.651784,  0.717887),
        vec2( 0.421003,  0.027070),
        vec2(-0.817194, -0.271096),
        vec2(-0.705374, -0.668203),
        vec2( 0.977050, -0.108615),
        vec2( 0.063326,  0.142369),
        vec2( 0.203528,  0.214331),
        vec2(-0.667531,  0.326090)
    );
    float shadow = 0.0;

    for (int i = 0; i < 12; ++i)
    {
        vec2 offset = rotation * poissonDisk[i] * texelSize * filterRadius;
        float closestDepth = texture(shadowMap, vec3(projCoords.xy + offset, float(shadowLayer))).r;
        shadow += smoothstep(0.0, compareWidth, receiverDepth - closestDepth);
    }

    shadow /= 12.0;
    shadow = smoothstep(0.10, 0.90, shadow);
    return mix(1.0, 1.0 - shadow, clamp(lightShadowStrength, 0.0, 1.0));
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

// Main
void main()
{
    // VIEW DIRECTION
    vec3 Vworld = normalize(eyePosition - vin.position);
    vec3 Vtangent = normalize(transpose(vin.tangentBasis) * Vworld);
    vec2 baseUvDx = dFdx(vin.texcoord);
    vec2 baseUvDy = dFdy(vin.texcoord);

    // Actor UVs usually live in tightly packed atlases. Fade POM before a
    // grazing view can push a sample into a neighbouring island/background.
    float viewZ = clamp(Vtangent.z, 0.0, 1.0);
    float grazingFade = smoothstep(0.06, 0.30, viewZ);
    float heightScale_val = clamp(heightScale,
        -MaxActorHeightScale, MaxActorHeightScale) * grazingFade;

    // CALCULATE DISPLACEMENT
    vec2 displacement =
        (Vtangent.xy / max(viewZ, 0.08)) * heightScale_val;
    float displacementLength = length(displacement);
    float maxDisplacement = MaxActorHeightScale;
    if (displacementLength > maxDisplacement)
        displacement *= maxDisplacement / displacementLength;

    // Flat/default height maps bypass POM. Real maps use fewer samples when
    // viewed head-on, where extra layers produce no visible improvement.
    vec2 uv = vin.texcoord;
    if (useParallaxMapping != 0)
    {
        int maximumLayers = clamp(layers, 1, MaxActorPOMLayers);
        int minimumLayers = min(maximumLayers, 2);
        int layerCount = int(mix(float(maximumLayers), float(minimumLayers),
            clamp(abs(Vtangent.z), 0.0, 1.0)) + 0.5);
        vec2 displacementInTexels = abs(displacement) *
            vec2(textureSize(heightTexture, 0));

        if (max(displacementInTexels.x, displacementInTexels.y) > 0.25)
        {
            uv = ParallaxOcclusionMapping(
                heightTexture,
                vin.texcoord,
                displacement,
                pivot,
                layerCount
            );
        }
    }

    // TEXTURE SAMPLING
    // Albedo textures are uploaded as GL_SRGB8_ALPHA8. Texture sampling has
    // already converted them to linear RGB, so decoding them again here would
    // crush the actor's dark cloth and leather almost completely to black.
    vec3 albedo = textureGrad(albedoTexture, uv, baseUvDx, baseUvDy).rgb;

    float metallic = textureGrad(metalnessTexture, uv, baseUvDx, baseUvDy).r * metallicMult;

    float roughness = textureGrad(roughnessTexture, uv, baseUvDx, baseUvDy).r;
    roughness = clamp(roughness, MinSurfaceRoughness, 1.0);

    // NORMAL MAPPING
    vec3 tangentNormal = textureGrad(normalTexture, uv, baseUvDx, baseUvDy).rgb;
    tangentNormal = tangentNormal * 2.0 - 1.0;
    tangentNormal = normalize(vec3(tangentNormal.xy * NormalMapStrength, tangentNormal.z));

    vec3 N = normalize(vin.tangentBasis * tangentNormal);
    vec3 normalDx = dFdx(N);
    vec3 normalDy = dFdy(N);
    float normalVariance = max(dot(normalDx, normalDx), dot(normalDy, normalDy));
    roughness = clamp(
        sqrt(roughness * roughness + clamp(normalVariance * SpecularAAAmount, 0.0, 1.0)),
        MinSurfaceRoughness,
        1.0
    );

    // SURFACE REFLECTIVITY
    float specularStrength = max(specularLevel, 0.0);
    vec3 F0 = vec3(0.04);
    F0 = mix(F0, albedo, metallic);

    // DIRECT LIGHTING
    vec3 Lo = vec3(0.0);
    vec3 ambientAccum = vec3(0.0);

    vec3 shadowNormal = normalize(vin.geometricNormal);
    float castShadowVisibility = 1.0;

    for (int i = 0; i < min(lightCount, MaxLights); ++i)
    {
        Light light = lights[i];

        if (light.enabled == 0)
            continue;

        vec3 L;
        float attenuation = 1.0;

        if (light.type == 0) // Directional
        {
            L = normalize(-light.direction);
        }
        else if (light.type == 1) // Point
        {
            vec3 lightVec = light.position - vin.position;
            float distance = length(lightVec);

            L = lightVec / max(distance, Epsilon);

            attenuation =
                1.0 /
                max(
                    light.constantAttenuation +
                    light.linearAttenuation * distance +
                    light.quadraticAttenuation * distance * distance,
                    Epsilon
                );
        }
        else if (light.type == 2) // Spot
        {
            vec3 lightVec = light.position - vin.position;
            float distance = length(lightVec);

            L = lightVec / max(distance, Epsilon);

            float cosTheta = dot(-L, normalize(light.direction));
            float spot = smoothstep(
                light.spotCutoff,
                light.spotCutoff + 0.1,
                cosTheta
            );

            spot = pow(spot, light.spotExponent);

            attenuation =
                spot /
                max(
                    light.constantAttenuation +
                    light.linearAttenuation * distance +
                    light.quadraticAttenuation * distance * distance,
                    Epsilon
                );
        }
        else
        {
            continue;
        }

        // AMBIENT FROM THIS LIGHT
        ambientAccum += light.ambient;

        vec3 radiance = light.diffuse;

        if (length(radiance) < 0.0001)
            continue;

        float NdotL = max(dot(N, L), 0.0);
        if (NdotL <= 0.0)
            continue;

        vec3 H = normalize(Vworld + L);

        float shadowVisibility = 1.0;

        int shadowLayer = shadowMapIndices[i];
        if (shadowLayer >= 0)
        {
            shadowVisibility = ShadowVisibility(
                vin.lightSpacePositions[i],
                shadowLayer,
                shadowStrengths[i],
                shadowNormal,
                L
            );

            castShadowVisibility = min(
                castShadowVisibility,
                shadowVisibility
            );
        }

        float NdotV = max(dot(N, Vworld), 0.0);
        float NdotH = max(dot(N, H), 0.0);
        float HdotV = max(dot(H, Vworld), 0.0);

        // COOK-TORRANCE BRDF
        float NDF = DistributionGGX(N, H, roughness);
        float G = GeometrySmith(N, Vworld, L, roughness);
        vec3 F = clamp(FresnelSchlick(HdotV, F0) * specularStrength, vec3(0.0), vec3(1.0));

        vec3 numerator = NDF * G * F;
        float denominator = max(4.0 * NdotV * NdotL, Epsilon);
        vec3 new_specular = numerator / denominator;

        // ENERGY CONSERVATION
        vec3 kS = F;
        vec3 kD = vec3(1.0) - kS;
        kD *= 1.0 - metallic;

        vec3 new_diffuse = kD * albedo / PI;

		// Diffuse can keep a little residual light from ShadowStrength.
		// Specular should die much faster in shadow.
		float diffuseVisibility = shadowVisibility;
		float specularVisibility = shadowVisibility * shadowVisibility * shadowVisibility;

		Lo +=
			new_diffuse *
			radiance *
			NdotL *
			attenuation *
			diffuseVisibility;

		Lo +=
			new_specular *
			radiance *
			NdotL *
			attenuation *
			specularVisibility;
    }

	// ------------------------------------------------------------
	// AMBIENT / EDITOR IBL FILL
	// ------------------------------------------------------------

	// Material ambient occlusion map.
	vec3 aoTex = textureGrad(ambientOcclusionTexture, uv, baseUvDx, baseUvDy).rgb;

	float ao = clamp(dot(aoTex, vec3(0.333333)), 0.0, 1.0);
	ao = mix(1.0, ao, 0.45);

	// Original per-light ambient.
	vec3 lightAmbient = ambientAccum * albedo;

	// Neutral editor sky/fill. This replaces the missing cubemap irradiance.
	vec3 editorDiffuseIBL = albedo * 0.22 * ao;

	// Specular IBL approximation.
	// Real IBL would multiply the BRDF result by a prefiltered environment cubemap.
	// Since you only have a 2D LUT right now, use a small neutral reflection term.
	float NdotV_IBL = max(dot(N, Vworld), 0.0);
	vec3 F_IBL = clamp(FresnelSchlick(NdotV_IBL, F0) * specularStrength, vec3(0.0), vec3(1.0));

	vec2 brdf = texture(
		specularBRDF_LUT,
		vec2(NdotV_IBL, roughness)
	).rg;

	//vec3 specularMap = texture(specularTexture, uv).rgb;
	vec3 specularMap = textureGrad(specularTexture, uv, baseUvDx, baseUvDy).rgb * 0.25;

	vec3 editorSpecularIBL =
		(F_IBL * brdf.x + brdf.y) *
		specularMap *
		0.05 *
		specularStrength;

	// Keep ambient readable. Direct shadows are already applied to Lo.
	// This only lets shadow slightly affect the ambient/fill.
	float ambientShadow = mix(
		1.0,
		castShadowVisibility,
		clamp(ambientShadowStrength, 0.0, 1.0)
	);

	// Specular/environment reflection should be reduced harder in shadow.
	float specularAmbientShadow = mix(
		1.0,
		castShadowVisibility * castShadowVisibility * castShadowVisibility,
		clamp(ambientShadowStrength, 0.0, 1.0)
	);

	vec3 new_ambient =
		(lightAmbient + editorDiffuseIBL) * ambientShadow +
		editorSpecularIBL * specularAmbientShadow;

	// ------------------------------------------------------------
	// FINAL COLOR
	// ------------------------------------------------------------
	vec3 finalColor = new_ambient + Lo;

	// Keep shadows readable under the editor fill/IBL without turning PCF
	// fringe samples into a hard all-or-nothing blob.
	float finalShadowVisibility = mix(
		1.0,
		max(castShadowVisibility, 0.35),
		clamp(ambientShadowStrength * 0.85, 0.0, 1.0)
	);
	finalColor *= finalShadowVisibility;

	// Use the actor material's exposure instead of two hard-coded boosts. This
	// keeps the material editor parameter effective and applies exposure once.
	finalColor *= max(hdrExposure, 0.0);

    if (usePostToneMapping != 0)
    {
        finalColor = ApplyFog(finalColor, vin.position);
    }
    else
    {
        // TONEMAP
        finalColor = finalColor / (finalColor + vec3(1.0));

        // GAMMA CORRECTION
        finalColor = pow(finalColor, vec3(1.0 / gamma));
        finalColor = ApplyFog(finalColor, vin.position);
    }

    color = vec4(finalColor, alpha);
}
