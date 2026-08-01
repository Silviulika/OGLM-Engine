#version 450 core

in vec2 vTexcoord;

uniform sampler2D albedoTexture;
uniform int useAlbedoTexture;
uniform int useAlphaCutout;
uniform vec3 diffuseColor;
uniform float alphaCutoff;

out vec4 color;

void main()
{
    vec4 sampleColor = useAlbedoTexture != 0
        ? texture(albedoTexture, vTexcoord)
        : vec4(diffuseColor, 1.0);

    if (useAlphaCutout != 0)
    {
        if (sampleColor.a < clamp(alphaCutoff, 0.0, 1.0))
            discard;
    }
    else
        sampleColor.a = 1.0;

    color = sampleColor;
}
