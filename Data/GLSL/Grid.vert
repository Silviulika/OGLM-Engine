#version 450 core

layout (location = 0) in vec3 aPos;

layout (location = 0) out vec3 outNearPoint;
layout (location = 1) out vec3 outFarPoint;

uniform mat4 view;
uniform mat4 projection;

// Helper function to unproject screen points into world space
vec3 UnprojectPoint(float x, float y, float z, mat4 viewMat, mat4 projMat) {
    mat4 viewInv = inverse(viewMat);
    mat4 projInv = inverse(projMat);
    vec4 unprojectedPoint = viewInv * projInv * vec4(x, y, z, 1.0);
    return unprojectedPoint.xyz / unprojectedPoint.w;
}

void main() {
    // Project clip space positions to the world space near and far planes
    outNearPoint = UnprojectPoint(aPos.x, aPos.y, -1.0, view, projection);
    outFarPoint  = UnprojectPoint(aPos.x, aPos.y, 1.0, view, projection);
    
    gl_Position = vec4(aPos, 1.0);
}
