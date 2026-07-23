#version 450 core

const int MaxLights = 8;
const float InvPi = 0.31830988618;
const float DielectricSpecularScale = 0.25;

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
uniform sampler2D ambientOcclusionTexture;
uniform sampler2DArray shadowMap;

uniform int useAlbedoTexture;
uniform int useNormalTexture;
uniform int useSpecularTexture;
uniform int useAmbientOcclusionTexture;
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
uniform float ambientShadowStrength;
uniform float alpha;
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

    float facing = max(dot(normal, lightDirection), 0.0);
    float bias = max(0.00035 * (1.0 - facing), 0.00008);
    vec2 texelSize = 1.0 / vec2(textureSize(shadowMap, 0).xy);
    float visibility = 0.0;

    for (int y = -1; y <= 1; ++y)
    {
        for (int x = -1; x <= 1; ++x)
        {
            float depth = texture(shadowMap,
                vec3(projected.xy + vec2(x, y) * texelSize,
                float(shadowLayer))).r;
            visibility += projected.z - bias <= depth ? 1.0 : 0.0;
        }
    }

    visibility /= 9.0;
    return mix(1.0, visibility, clamp(lightShadowStrength, 0.0, 1.0));
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
    vec3 albedo = useAlbedoTexture != 0 ?
        textureGrad(albedoTexture, vin.texcoord, uvDx, uvDy).rgb :
        diffuseColor;
    // GL_SRGB8_ALPHA8 sampling already returns linear RGB. Only the
    // textureless color fallback still needs conversion from display space.
    albedo = max(albedo, vec3(0.0));
    if (useAlbedoTexture == 0)
        albedo = pow(albedo, vec3(2.2));

    vec3 tangentNormal = vec3(0.0, 0.0, 1.0);
    if (useNormalTexture != 0)
    {
        tangentNormal = textureGrad(normalTexture, vin.texcoord, uvDx, uvDy).xyz;
        tangentNormal = normalize(tangentNormal * 2.0 - 1.0);
    }
    vec3 normal = normalize(vin.tangentBasis * tangentNormal);

    vec3 specularMask = useSpecularTexture != 0 ?
        textureGrad(specularTexture, vin.texcoord, uvDx, uvDy).rgb :
        vec3(1.0);
    // The inexpensive Blinn highlight otherwise carries several times the
    // reflectance of the PBR path and washes bright bark toward white.
    specularMask *= max(specularColor, vec3(0.0)) *
        DielectricSpecularScale;

    float sampledAO = 1.0;
    if (useAmbientOcclusionTexture != 0)
    {
        vec3 aoSample = textureGrad(ambientOcclusionTexture, vin.texcoord,
            uvDx, uvDy).rgb;
        sampledAO = clamp(dot(aoSample, vec3(0.333333)), 0.0, 1.0);
    }
    float ao = mix(1.0, sampledAO, clamp(ambientShadowStrength, 0.0, 1.0));

    vec3 viewDirection = normalize(eyePosition - vin.position);
    vec3 lighting = albedo * 0.08 * ao;
    float glossPower = clamp(shininess, 2.0, 256.0);

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
        float diffuseAmount = max(dot(normal, lightDirection), 0.0);
        vec3 halfVector = normalize(lightDirection + viewDirection);
        float specularAmount = pow(max(dot(normal, halfVector), 0.0),
            glossPower) * max(specularLevel, 0.0);

        lighting += light.ambient * albedo * ao;
        // Lambert is a BRDF, so normalize diffuse energy just as the PBR
        // shader does. This keeps bright albedo detail below tone-map clipping.
        lighting += light.diffuse * albedo * (diffuseAmount * InvPi) *
            attenuation * visibility;
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
