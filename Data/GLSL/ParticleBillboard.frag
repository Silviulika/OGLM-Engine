#version 450 core

uniform sampler2D particleTexture;
uniform int useTexture;

in vec4 vColor;
in vec2 vTexCoord;

out vec4 color;

void main()
{
    vec4 texel = (useTexture != 0) ? texture(particleTexture, vTexCoord) : vec4(1.0);
    color = vec4(vColor.rgb * texel.rgb, vColor.a * texel.a);

    if (color.a <= 0.001)
        discard;
}
