#version 450 core

uniform sampler2D leafAlphaTexture;
uniform int useAlphaCutout;
uniform float alphaCutoff;

in vec2 shadowTexcoord;

void main()
{
    if (useAlphaCutout != 0 &&
        texture(leafAlphaTexture, shadowTexcoord).a < alphaCutoff)
        discard;
}
