#[compute]
#version 450

// ------------------------------------------------------------
// Buffers
// ------------------------------------------------------------
layout(set = 0, binding = 0) buffer Positions {
    vec4 positions[];
};

layout(set = 0, binding = 1) buffer Velocities {
    vec4 velocities[];
};

// ------------------------------------------------------------
// Push constants
// ------------------------------------------------------------
layout(push_constant) uniform Params {
    float delta;
    float pad0;
    float pad1;
    float pad2;
} params;

// ------------------------------------------------------------
// Workgroup size
// ------------------------------------------------------------
layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

// ------------------------------------------------------------
// Main integration kernel
// ------------------------------------------------------------
void main() {
    uint index = gl_GlobalInvocationID.x;

    // Load
    vec3 pos = positions[index].xyz;
    vec3 vel = velocities[index].xyz;

    // Integrate
    pos += vel * params.delta;

    // Write back
    positions[index] = vec4(pos, 1.0);
}