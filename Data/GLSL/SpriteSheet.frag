#version 450 core

uniform sampler2D spriteTexture;
uniform int useSpriteTexture;
uniform int spriteSheetColumns;
uniform int spriteSheetRows;
uniform int spriteSheetFrameCount;
uniform int spriteSheetFrame;
uniform float spriteSheetAlphaCutoff;
uniform int spriteSheetAlphaFromLuminance;
uniform vec4 spriteTint;

in vec2 vTexCoord;

out vec4 color;

vec2 SpriteSheetUV(vec2 localUV)
{
    int columns = max(spriteSheetColumns, 1);
    int rows = max(spriteSheetRows, 1);
    int frameCount = max(spriteSheetFrameCount, 1);
    int frame = spriteSheetFrame % frameCount;
    int column = frame % columns;
    int row = frame / columns;
    vec2 cellSize = vec2(1.0 / float(columns), 1.0 / float(rows));

    return vec2(
        (float(column) + localUV.x) * cellSize.x,
        1.0 - (float(row) + 1.0) * cellSize.y + localUV.y * cellSize.y
    );
}

void main()
{
    vec4 texel = vec4(1.0);
    if (useSpriteTexture != 0)
        texel = texture(spriteTexture, SpriteSheetUV(clamp(vTexCoord, 0.0, 1.0)));

    float luminanceAlpha = max(max(texel.r, texel.g), texel.b);
    float alpha = texel.a;
    if (spriteSheetAlphaFromLuminance != 0)
        alpha = luminanceAlpha;

    color = vec4(texel.rgb * spriteTint.rgb, alpha * spriteTint.a);
    if (color.a <= spriteSheetAlphaCutoff)
        discard;
}
