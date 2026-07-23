#version 450 core

uniform sampler2D billboardTexture;
uniform int useTexture;
uniform float alphaCutoff;

in vec4 vColor;
in vec2 vTexCoord;

out vec4 color;

void main()
{
    vec4 texel = (useTexture != 0) ? texture(billboardTexture, vTexCoord) : vec4(1.0);
    color = vec4(vColor.rgb * texel.rgb, vColor.a * texel.a);

    if (color.a <= alphaCutoff)
        discard;
}
