#version 450 core

layout(location = 0) in vec2 aPosition;
layout(location = 1) in vec2 aTexCoord;

uniform vec2 viewportSize;

out vec2 vTexCoord;

void main()
{
    vec2 ndc = vec2(
        (aPosition.x / viewportSize.x) * 2.0 - 1.0,
        1.0 - (aPosition.y / viewportSize.y) * 2.0
    );

    gl_Position = vec4(ndc, 0.0, 1.0);
    vTexCoord = aTexCoord;
}
