#version 450 core

uniform sampler2D leafAlphaTexture;
uniform int useAlphaCutout;
uniform float alphaCutoff;

in vec2 shadowTexcoord;

void main()
{
    if (useAlphaCutout != 0)
    {
        float stableCutoff = clamp(alphaCutoff - 0.04, 0.0, 1.0);
        if (texture(leafAlphaTexture, shadowTexcoord).a < stableCutoff)
            discard;
    }
}
