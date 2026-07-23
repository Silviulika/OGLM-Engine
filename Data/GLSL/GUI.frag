#version 450 core

in vec2 vTexCoord;

uniform sampler2D guiTexture;
uniform vec4 tintColor;
uniform float opacity;
uniform bool colorKeyEnabled;
uniform vec3 colorKey;
uniform float colorKeyTolerance;

layout(location = 0) out vec4 FragColor;

void main()
{
    vec4 texColor = texture(guiTexture, vTexCoord);

    if (colorKeyEnabled && distance(texColor.rgb, colorKey) <= colorKeyTolerance)
        discard;

    FragColor = texColor * vec4(tintColor.rgb, tintColor.a * opacity);
}
