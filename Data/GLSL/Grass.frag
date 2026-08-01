#version 450 core

const int MaxLights = 8;
const float MaxGrassGlossPower = 8.0;
const float GrassSpecularScale = 0.08;
const float FoliageShadowMinBias = 0.00045;
const float FoliageShadowSlopeBias = 0.00120;
const float FoliageShadowStrengthScale = 0.84;

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

uniform sampler2D albedoTexture;
uniform sampler2D normalTexture;
uniform sampler2D specularTexture;
uniform sampler2DArray shadowMap;

uniform int useAlbedoTexture;
uniform int useNormalTexture;
uniform int useSpecularTexture;
uniform int useShadowMap;
uniform int shadowMapCount;
uniform int shadowMapIndices[MaxLights];
uniform float shadowStrengths[MaxLights];

uniform int lightCount;
uniform Light lights[MaxLights];
uniform vec3 eyePosition;
uniform vec3 diffuseColor;
uniform vec3 specularColor;
uniform float shininess;
uniform float specularLevel;
uniform float alpha;
uniform float alphaCutoff;
uniform float gamma;
uniform float hdrExposure;
uniform int usePostToneMapping;
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

float ShadowVisibility(vec4 lightSpacePosition, int shadowLayer,
    float lightShadowStrength, vec3 normal, vec3 lightDirection)
{
    if (useShadowMap == 0 || shadowLayer < 0 ||
        shadowLayer >= shadowMapCount)
        return 1.0;

    vec3 projected = lightSpacePosition.xyz / lightSpacePosition.w;
    projected = projected * 0.5 + 0.5;
    if (projected.x < 0.0 || projected.x > 1.0 ||
        projected.y < 0.0 || projected.y > 1.0 ||
        projected.z < 0.0 || projected.z > 1.0)
        return 1.0;

    float facing = abs(dot(normalize(normal), normalize(lightDirection)));
    float bias = max(FoliageShadowSlopeBias * (1.0 - facing),
        FoliageShadowMinBias);
    vec2 texelSize = 1.0 / vec2(textureSize(shadowMap, 0).xy);
    float visibility = 0.0;
    float totalWeight = 0.0;

    for (int y = -1; y <= 1; ++y)
    {
        for (int x = -1; x <= 1; ++x)
        {
            float weight = (2.0 - float(abs(x))) *
                (2.0 - float(abs(y)));
            float depth = texture(shadowMap,
                vec3(projected.xy + vec2(x, y) * texelSize,
                float(shadowLayer))).r;
            visibility += (projected.z - bias <= depth ? 1.0 : 0.0) *
                weight;
            totalWeight += weight;
        }
    }

    visibility /= max(totalWeight, 0.0001);
    return mix(1.0, visibility,
        clamp(lightShadowStrength * FoliageShadowStrengthScale, 0.0, 1.0));
}

vec3 ApplyFog(vec3 inputColor)
{
    if (useFog == 0)
        return inputColor;

    float distanceToEye = length(eyePosition - vin.position);
    float range = max(fogEnd - fogStart, 0.0001);
    float rangeVisibility = clamp((fogEnd - distanceToEye) / range, 0.0, 1.0);
    float densityVisibility = exp(-pow(max(fogDensity, 0.0) * distanceToEye, 2.0));
    float visibility = clamp(min(rangeVisibility, densityVisibility), 0.0, 1.0);
    return mix(fogColor.rgb, inputColor, visibility);
}

void main()
{
    vec2 uvDx = dFdx(vin.texcoord);
    vec2 uvDy = dFdy(vin.texcoord);
    vec4 albedoSample = useAlbedoTexture != 0 ?
        textureGrad(albedoTexture, vin.texcoord, uvDx, uvDy) :
        vec4(diffuseColor, 1.0);

    float cutoff = clamp(alphaCutoff, 0.0, 1.0);
    if (albedoSample.a < cutoff)
        discard;

    float edgeWidth = max(fwidth(albedoSample.a), 0.001);
    float edgeCoverage = smoothstep(cutoff,
        cutoff + edgeWidth * 2.0, albedoSample.a);
    vec3 albedo = max(albedoSample.rgb, vec3(0.0));
    if (useAlbedoTexture == 0)
        albedo = pow(albedo, vec3(2.2));

    vec3 tangentNormal = vec3(0.0, 0.0, 1.0);
    float normalCoherence = 1.0;
    if (useNormalTexture != 0)
    {
        tangentNormal = textureGrad(normalTexture, vin.texcoord, uvDx, uvDy).xyz;
        tangentNormal = tangentNormal * 2.0 - 1.0;
        normalCoherence = clamp(length(tangentNormal), 0.0, 1.0);
        if (normalCoherence > 0.0001)
            tangentNormal /= normalCoherence;
        else
            tangentNormal = vec3(0.0, 0.0, 1.0);
    }

    vec3 normal = normalize(vin.tangentBasis * tangentNormal);
    if (!gl_FrontFacing)
        normal = -normal;

    vec3 viewDirection = normalize(eyePosition - vin.position);
    vec3 specularMask = useSpecularTexture != 0 ?
        textureGrad(specularTexture, vin.texcoord, uvDx, uvDy).rgb :
        vec3(1.0);
    float specularEdgeFade = smoothstep(0.45, 1.0, edgeCoverage);
    specularMask *= max(specularColor, vec3(0.0)) * GrassSpecularScale *
        specularEdgeFade;

    vec3 lighting = albedo * 0.10;
    float sourceGlossPower = clamp(shininess, 2.0, 256.0);
    float grassGlossPower = min(sourceGlossPower, MaxGrassGlossPower);
    float normalVariance = max(1.0 - normalCoherence, 0.0);
    float filteredRoughnessSquared =
        2.0 / (grassGlossPower + 2.0) + normalVariance;
    float glossPower = max(2.0 / filteredRoughnessSquared - 2.0, 2.0);
    float specularFilter = (glossPower + 2.0) /
        (sourceGlossPower + 2.0);

    for (int i = 0; i < min(lightCount, MaxLights); ++i)
    {
        Light light = lights[i];
        if (light.enabled == 0)
            continue;

        vec3 lightDirection;
        float attenuation = 1.0;
        if (light.type == 0)
        {
            lightDirection = normalize(-light.direction);
        }
        else
        {
            vec3 toLight = light.position - vin.position;
            float distanceToLight = length(toLight);
            lightDirection = toLight / max(distanceToLight, 0.00001);
            attenuation = 1.0 / max(light.constantAttenuation +
                light.linearAttenuation * distanceToLight +
                light.quadraticAttenuation * distanceToLight * distanceToLight,
                0.00001);

            if (light.type == 2)
            {
                float spotAmount = dot(normalize(-light.direction),
                    -lightDirection);
                float spot = smoothstep(light.spotCutoff,
                    min(1.0, light.spotCutoff + 0.08), spotAmount);
                attenuation *= pow(spot, max(light.spotExponent, 1.0));
            }
        }

        float visibility = ShadowVisibility(vin.lightSpacePositions[i],
            shadowMapIndices[i], shadowStrengths[i], normal, lightDirection);
        float forwardDiffuse = max(dot(normal, lightDirection), 0.0);
        float diffuseAmount = mix(abs(dot(normal, lightDirection)),
            forwardDiffuse, 0.25);
        float backLight = pow(max(dot(-normal, lightDirection), 0.0), 1.4) *
            0.22;
        vec3 halfVector = normalize(lightDirection + viewDirection);
        float specularAmount = pow(max(dot(normal, halfVector), 0.0),
            glossPower) * max(specularLevel, 0.0) * specularFilter;

        lighting += light.ambient * albedo;
        lighting += light.diffuse * albedo *
            (diffuseAmount + backLight) * attenuation * visibility;
        lighting += light.specular * specularMask * specularAmount *
            attenuation * visibility * visibility;
    }

    lighting *= max(hdrExposure, 0.0) / 2.2;
    if (usePostToneMapping == 0)
    {
        lighting = lighting / (lighting + vec3(1.0));
        lighting = pow(max(lighting, vec3(0.0)),
            vec3(1.0 / max(gamma, 0.0001)));
    }

    color = vec4(ApplyFog(lighting), clamp(alpha, 0.0, 1.0));
}
