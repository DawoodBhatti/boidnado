#[compute]
#version 450

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// Binding 5 → boid_indices (int array)
layout(set = 0, binding = 5) buffer InputBuffer {
    int boid_indices[];
};

// Binding 6 → sorted_boid_indices buffer (int array)
layout(set = 0, binding = 6) buffer OutputBuffer {
    int sorted_boid_indices[];
};


void main() {
    uint idx = gl_GlobalInvocationID.x;

    // Simple test: output = boid_indices + 1
    sorted_boid_indices[idx] = boid_indices[idx] + 1;
}
