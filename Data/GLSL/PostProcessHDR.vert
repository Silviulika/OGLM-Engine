#version 450 core

layout (location = 0) in vec2 in_position;
layout (location = 1) in vec2 in_tex_coordinates;

out vec2 vertex_tex_coordinates;

void main()
{
    vertex_tex_coordinates = in_tex_coordinates;
    gl_Position = vec4(in_position, 0.0, 1.0);
}
