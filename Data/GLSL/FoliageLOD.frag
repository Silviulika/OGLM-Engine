#version 450 core

in vec2 vTexcoord;

uniform sampler2D spriteTexture;
uniform float alphaCutoff;

out vec4 color;

void main()
{
    vec4 spriteColor = texture(spriteTexture, vTexcoord);
    if (spriteColor.a < clamp(alphaCutoff, 0.0, 1.0))
        discard;
    // Foliage materials are alpha-tested in their full geometry shaders.
    // Keep the captured silhouette alpha-tested as well; blending the atlas
    // alpha here makes the complete distant tree/grass sprite look ghosted.
    color = vec4(spriteColor.rgb, 1.0);
}
