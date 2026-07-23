#version 450 core

const float PI = 3.14159265359;
const float Epsilon = 0.00001;
// Terrain contains high-frequency normal detail, which otherwise turns into
// sparkly plastic highlights at medium and far distances.
const float MinTerrainRoughness = 0.22;
const float TerrainSpecularScale = 0.05;
const float TerrainSpecularAAAmount = 0.18;
const float TerrainSpecularAALimit = 0.35;
const float TerrainSpecularIBLStrength = 0.22;
const float TerrainDiffuseIBLStrength = 0.22;
const float TerrainExposureBoost = 0.3;
const float TerrainHeightBlendDepth = 0.18;
const int MaxLights = 8;
const int MaxTerrainLayers = 5;
const int MaxTerrainPOMLayers = 24;

struct Light
{
    int enabled;
    int type;
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
    vec3 position;
    vec3 direction;
    float constantAttenuation;
    float linearAttenuation;
    float quadraticAttenuation;
    float spotCutoff;
    float spotExponent;
};

uniform float gamma;
uniform int lightCount;
uniform Light lights[MaxLights];
uniform vec3 eyePosition;
uniform int layers;
uniform float pivot;
uniform float metallicMult;
uniform float specularLevel;
uniform float heightScale;
uniform float ambientShadowStrength;
uniform float hdrExposure;
uniform int usePostToneMapping;

uniform int useTerrainAlphaMasks;
uniform int useAlphaTextures[MaxTerrainLayers];
uniform int useHeightTextures[MaxTerrainLayers];
uniform float terrainUVScale;
uniform sampler2D alphaTextures[MaxTerrainLayers];
uniform sampler2D albedoTextures[MaxTerrainLayers];
uniform sampler2D normalTextures[MaxTerrainLayers];
uniform sampler2D heightTextures[MaxTerrainLayers];
uniform sampler2D metalnessTextures[MaxTerrainLayers];
uniform sampler2D roughnessTextures[MaxTerrainLayers];

uniform sampler2DArray shadowMap;
uniform int useShadowMap;
uniform int shadowLightIndex;
uniform float shadowStrength;
uniform int shadowMapCount;
uniform int shadowMapIndices[MaxLights];
uniform float shadowStrengths[MaxLights];
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

vec3 FresnelSchlick(float cosTheta, vec3 F0)
{
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

float DistributionGGX(vec3 N, vec3 H, float roughness)
{
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    return a2 / max(PI * denom * denom, Epsilon);
}

float GeometrySchlickGGX(float NdotV, float roughness)
{
    float r = roughness + 1.0;
    float k = (r * r) / 8.0;
    return NdotV / max(NdotV * (1.0 - k) + k, Epsilon);
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness)
{
    float ggx1 = GeometrySchlickGGX(max(dot(N, V), 0.0), roughness);
    float ggx2 = GeometrySchlickGGX(max(dot(N, L), 0.0), roughness);
    return ggx1 * ggx2;
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

    float normalFacing = clamp(dot(normal, lightDir), 0.0, 1.0);
    float bias = max(0.0012 * (1.0 - normalFacing), 0.00025);
    vec2 texelSize = 1.0 / vec2(textureSize(shadowMap, 0).xy);
    float filterRadius = 1.25;
    float compareWidth = max(bias * 2.0, 0.00025);
    float receiverDepth = projCoords.z - bias;
    float randomAngle = fract(sin(dot(floor(gl_FragCoord.xy), vec2(12.9898, 78.233))) * 43758.5453) * 6.28318530718;
    float s = sin(randomAngle);
    float c = cos(randomAngle);
    mat2 rotation = mat2(c, -s, s, c);
    const vec2 poissonDisk[24] = vec2[](
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
        vec2(-0.667531,  0.326090),
        vec2(-0.098422, -0.295755),
        vec2(-0.885922,  0.215369),
        vec2( 0.566637,  0.605213),
        vec2( 0.039766, -0.396100),
        vec2( 0.751946,  0.453352),
        vec2( 0.078707, -0.715323),
        vec2(-0.075838, -0.529344),
        vec2( 0.724479, -0.580798),
        vec2( 0.222999, -0.215125),
        vec2(-0.467574, -0.405438),
        vec2(-0.248268, -0.814753),
        vec2( 0.354411, -0.887570)
    );
    float shadow = 0.0;

    for (int i = 0; i < 24; ++i)
    {
        vec2 offset = rotation * poissonDisk[i] * texelSize * filterRadius;
        float closestDepth = texture(shadowMap, vec3(projCoords.xy + offset, float(shadowLayer))).r;
        shadow += smoothstep(0.0, compareWidth, receiverDepth - closestDepth);
    }

    shadow /= 24.0;
    shadow = smoothstep(0.10, 0.90, shadow);
    return mix(1.0, 1.0 - shadow, clamp(lightShadowStrength, 0.0, 1.0));
}

float AlphaMaskValue(int layer, vec2 uv)
{
    if (useTerrainAlphaMasks == 0)
        return (layer == 0) ? 1.0 : 0.0;

    if (useAlphaTextures[layer] == 0)
        return 0.0;

    vec2 texel = 0.5 / vec2(textureSize(alphaTextures[layer], 0));
    vec2 maskUV = clamp(uv, texel, vec2(1.0) - texel);
    vec3 mask = textureLod(alphaTextures[layer], maskUV, 0.0).rgb;
    return clamp(dot(mask, vec3(0.2126, 0.7152, 0.0722)), 0.0, 1.0);
}

vec2 TerrainAlphaUV(vec2 materialUV)
{
    vec2 alphaUV = materialUV / max(terrainUVScale, 0.0001);
    alphaUV.y = 1.0 - alphaUV.y;
    return alphaUV;
}

void LayerWeights(vec2 uv, out float weights[MaxTerrainLayers])
{
    float sumWeights = 0.0;

    for (int i = 0; i < MaxTerrainLayers; ++i)
    {
        weights[i] = AlphaMaskValue(i, uv);
        sumWeights += weights[i];
    }

    if (sumWeights <= Epsilon)
    {
        weights[0] = 1.0;
        for (int i = 1; i < MaxTerrainLayers; ++i)
            weights[i] = 0.0;
        return;
    }

    for (int i = 0; i < MaxTerrainLayers; ++i)
        weights[i] /= sumWeights;
}

void ApplyHeightBlend(vec2 materialUV, vec2 uvDx, vec2 uvDy,
                      inout float weights[MaxTerrainLayers])
{
    float scores[MaxTerrainLayers];
    float maxScore = -1.0;

    for (int i = 0; i < MaxTerrainLayers; ++i)
    {
        float surfaceHeight = 0.5;
        if (weights[i] > Epsilon && useHeightTextures[i] != 0)
            surfaceHeight = textureGrad(heightTextures[i], materialUV, uvDx, uvDy).r;

        scores[i] = weights[i] + surfaceHeight * TerrainHeightBlendDepth;
        if (weights[i] > Epsilon)
            maxScore = max(maxScore, scores[i]);
    }

    float sumWeights = 0.0;
    for (int i = 0; i < MaxTerrainLayers; ++i)
    {
        float heightWeight = max(
            scores[i] - maxScore + TerrainHeightBlendDepth,
            0.0
        );
        weights[i] *= heightWeight;
        sumWeights += weights[i];
    }

    if (sumWeights <= Epsilon)
        return;

    for (int i = 0; i < MaxTerrainLayers; ++i)
        weights[i] /= sumWeights;
}

float TerrainHeightAt(vec2 materialUV, vec2 uvDx, vec2 uvDy,
                      float weights[MaxTerrainLayers], out float heightWeight)
{
    float heightValue = 0.0;
    heightWeight = 0.0;

    for (int i = 0; i < MaxTerrainLayers; ++i)
    {
        float weight = weights[i];
        if (weight <= Epsilon || useHeightTextures[i] == 0)
            continue;

        heightValue += textureGrad(heightTextures[i], materialUV, uvDx, uvDy).r * weight;
        heightWeight += weight;
    }

    if (heightWeight <= Epsilon)
        return 0.0;

    return heightValue / heightWeight;
}

vec2 TerrainParallaxUV(vec2 materialUV, vec3 viewTangent, vec2 uvDx, vec2 uvDy,
                       float weights[MaxTerrainLayers])
{
    float heightWeight;
    TerrainHeightAt(materialUV, uvDx, uvDy, weights, heightWeight);
    if (heightWeight <= Epsilon)
        return materialUV;

    float viewZ = max(viewTangent.z, 0.12);
    float grazingFade = clamp(viewTangent.z * 8.0, 0.0, 1.0);
    float parallaxScale = max(heightScale, 0.0) * grazingFade;
    if (parallaxScale <= Epsilon)
        return materialUV;

    vec2 displacement = (viewTangent.xy / viewZ) * parallaxScale;
    float displacementLength = length(displacement);
    float maxDisplacement = max(parallaxScale * 2.0, 0.0001);
    if (displacementLength > maxDisplacement)
        displacement *= maxDisplacement / displacementLength;

    int layerCount = clamp(layers, 4, MaxTerrainPOMLayers);
    float layerDepth = 1.0 / float(layerCount);
    float currentLayerDepth = 0.0;
    vec2 deltaUV = displacement / float(layerCount);
    vec2 currentUV = materialUV + pivot * displacement;
    float currentDepth = TerrainHeightAt(currentUV, uvDx, uvDy, weights, heightWeight);

    for (int i = 0; i < MaxTerrainPOMLayers; ++i)
    {
        if (i >= layerCount || currentLayerDepth > currentDepth)
            break;

        currentUV -= deltaUV;
        currentDepth = TerrainHeightAt(currentUV, uvDx, uvDy, weights, heightWeight);
        currentLayerDepth += layerDepth;
    }

    vec2 previousUV = currentUV + deltaUV;
    float endDepth = currentDepth - currentLayerDepth;
    float startDepth =
        TerrainHeightAt(previousUV, uvDx, uvDy, weights, heightWeight) -
        currentLayerDepth + layerDepth;
    float depthDifference = endDepth - startDepth;
    float blend = (abs(depthDifference) > Epsilon)
        ? endDepth / depthDifference
        : 0.0;

    return mix(currentUV, previousUV, clamp(blend, 0.0, 1.0));
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
    vec2 materialUV = vin.texcoord;
    vec2 baseUvDx = dFdx(vin.texcoord);
    vec2 baseUvDy = dFdy(vin.texcoord);
    vec2 alphaUV = TerrainAlphaUV(materialUV);
    float weights[MaxTerrainLayers];
    float gammaValue = max(gamma, 0.0001);
    vec3 V = normalize(eyePosition - vin.position);
    vec3 Vtangent = normalize(transpose(vin.tangentBasis) * V);

    LayerWeights(alphaUV, weights);
    ApplyHeightBlend(materialUV, baseUvDx, baseUvDy, weights);
    materialUV = TerrainParallaxUV(materialUV, Vtangent, baseUvDx, baseUvDy, weights);
    alphaUV = TerrainAlphaUV(materialUV);
    LayerWeights(alphaUV, weights);
    ApplyHeightBlend(materialUV, baseUvDx, baseUvDy, weights);

    vec3 albedo = vec3(0.0);
    vec3 tangentNormal = vec3(0.0);
    float metallic = 0.0;
    float roughness = 0.0;

    for (int i = 0; i < MaxTerrainLayers; ++i)
    {
        float weight = weights[i];
        if (weight <= Epsilon)
            continue;

        vec3 layerAlbedo = textureGrad(
            albedoTextures[i], materialUV, baseUvDx, baseUvDy
        ).rgb;
        vec3 layerNormal = textureGrad(
            normalTextures[i], materialUV, baseUvDx, baseUvDy
        ).rgb * 2.0 - 1.0;
        float layerMetallic = textureGrad(
            metalnessTextures[i], materialUV, baseUvDx, baseUvDy
        ).r;
        float layerRoughness = textureGrad(
            roughnessTextures[i], materialUV, baseUvDx, baseUvDy
        ).r;

        albedo += layerAlbedo * weight;
        tangentNormal += normalize(layerNormal) * weight;
        metallic += layerMetallic * weight;
        roughness += layerRoughness * weight;
    }

    // Albedo arrays use GL_SRGB8_ALPHA8, so texture sampling has already
    // converted them to linear RGB. Applying pow(2.2) here would decode twice
    // and crush the material's midtone detail.

    if (dot(tangentNormal, tangentNormal) <= Epsilon)
        tangentNormal = vec3(0.0, 0.0, 1.0);
    tangentNormal = normalize(tangentNormal);
    vec3 N = normalize(vin.tangentBasis * tangentNormal);

    metallic = clamp(metallic * metallicMult, 0.0, 1.0);

    // Filter high-frequency normal-map detail into roughness to prevent
    // shimmering/specular fireflies on the terrain.
    vec3 normalDx = dFdx(N);
    vec3 normalDy = dFdy(N);
    float normalVariance = max(dot(normalDx, normalDx), dot(normalDy, normalDy));
    roughness = clamp(
        sqrt(roughness * roughness +
             clamp(normalVariance * TerrainSpecularAAAmount, 0.0, TerrainSpecularAALimit)),
        MinTerrainRoughness,
        1.0
    );

    float specularStrength = max(specularLevel, 0.0) * TerrainSpecularScale;
    vec3 F0 = mix(vec3(0.04), albedo, metallic);
    vec3 Lo = vec3(0.0);
    vec3 ambientAccum = vec3(0.0);
    float castShadowVisibility = 1.0;

    for (int i = 0; i < min(lightCount, MaxLights); ++i)
    {
        Light light = lights[i];
        if (light.enabled == 0)
            continue;

        vec3 L;
        float attenuation = 1.0;

        if (light.type == 0)
        {
            L = normalize(-light.direction);
        }
        else
        {
            vec3 lightVec = light.position - vin.position;
            float distance = max(length(lightVec), Epsilon);
            L = lightVec / distance;
            attenuation = 1.0 / max(light.constantAttenuation +
                                    light.linearAttenuation * distance +
                                    light.quadraticAttenuation * distance * distance, Epsilon);

            if (light.type == 2)
            {
                float cosTheta = dot(-L, normalize(light.direction));
                float spot = smoothstep(light.spotCutoff, light.spotCutoff + 0.1, cosTheta);
                attenuation *= pow(spot, light.spotExponent);
            }
        }

        vec3 H = normalize(V + L);
        float NdotL = max(dot(N, L), 0.0);
        float NdotV = max(dot(N, V), 0.0);
        float HdotV = max(dot(H, V), 0.0);

        vec3 F = clamp(FresnelSchlick(HdotV, F0) * specularStrength, vec3(0.0), vec3(1.0));
        float NDF = DistributionGGX(N, H, roughness);
        float G = GeometrySmith(N, V, L, roughness);
        vec3 numerator = NDF * G * F;
        float denominator = max(4.0 * NdotV * NdotL, Epsilon);
        vec3 specular = numerator / denominator;

        vec3 kS = F;
        vec3 kD = (vec3(1.0) - kS) * (1.0 - metallic);
        vec3 radiance = light.diffuse * attenuation;
        float visibility = 1.0;
        int shadowLayer = shadowMapIndices[i];
        if (shadowLayer >= 0)
            visibility = ShadowVisibility(
                vin.lightSpacePositions[i],
                shadowLayer,
                shadowStrengths[i],
                normalize(vin.geometricNormal),
                L
            );

        castShadowVisibility = min(castShadowVisibility, visibility);

        vec3 diffuse = kD * albedo / PI;
        float specularVisibility = visibility * visibility * visibility;
        Lo += diffuse * radiance * NdotL * visibility;
        Lo += specular * radiance * NdotL * specularVisibility;
        ambientAccum += light.ambient * attenuation;
    }

    // The regular PBR material gets an editor IBL fill; terrain needs the same
    // baseline illumination so HDR tone mapping does not leave it unnaturally dark.
    vec3 terrainDiffuseIBL = albedo * TerrainDiffuseIBLStrength;
    float terrainAmbientShadow = mix(
        1.0,
        max(castShadowVisibility, 0.35),
        clamp(ambientShadowStrength * 0.85, 0.0, 1.0)
    );
    float environmentNdotV = max(dot(N, V), 0.0);
    vec3 environmentFresnel = FresnelSchlick(environmentNdotV, F0);
    vec3 terrainSpecularIBL = environmentFresnel *
        (1.0 - roughness * 0.75) *
        TerrainSpecularIBLStrength * specularStrength;
    vec3 ambient = (albedo * ambientAccum + terrainDiffuseIBL) *
        terrainAmbientShadow +
        terrainSpecularIBL * terrainAmbientShadow * terrainAmbientShadow;
    vec3 finalColor = ambient + Lo;
    if (usePostToneMapping != 0)
    {
        finalColor *= max(hdrExposure, 0.0) * TerrainExposureBoost;
        finalColor = ApplyFog(finalColor, vin.position);
    }
    else
    {
        finalColor = finalColor / (finalColor + vec3(1.0));
        finalColor = pow(finalColor, vec3(1.0 / gammaValue));
        finalColor = ApplyFog(finalColor, vin.position);
    }

    color = vec4(finalColor, 1.0);
}
