#version 450 core

//Material.frag

in vec2 vTexCoord;
in vec3 vNormal;
in vec3 vFragPos;

out vec4 FragColor;

// Material properties
uniform struct Material {
    vec3 diffuse;
    vec3 specular;
    float shininess;
    sampler2D diffuseTexture;
} uMaterial;

// Light properties (directional light for simplicity)
uniform vec3 uLightDir;      // direction towards light
uniform vec3 uLightColor;
uniform vec3 uViewPos;       // camera position
uniform int uUseTexture;

void main()
{
    // Sample texture if provided (fallback to material diffuse color)	
	vec3 texColor = texture(uMaterial.diffuseTexture, vTexCoord).rgb;
	vec3 baseColor = uMaterial.diffuse;
	if (uUseTexture == 1) baseColor = texColor * uMaterial.diffuse;
    
    // Ambient
    float ambientStrength = 0.2;
    vec3 ambient = ambientStrength * uLightColor;
    
    // Diffuse
    vec3 norm = normalize(vNormal);
    vec3 lightDir = normalize(-uLightDir);  // because uLightDir is direction to light
    float diff = max(dot(norm, lightDir), 0.0);
    vec3 diffuse = diff * uLightColor;
    
    // Specular (Blinn-Phong simplified)
    float specularStrength = 0.5;
    vec3 viewDir = normalize(uViewPos - vFragPos);
    vec3 reflectDir = reflect(-lightDir, norm);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), uMaterial.shininess);
    vec3 specular = specularStrength * spec * uLightColor * uMaterial.specular;
    
    vec3 result = (ambient + diffuse + specular) * baseColor;
    FragColor = vec4(result, 1.0);
}