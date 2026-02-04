#[compute]
#version 450

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// Binding 9 → boid_indices (int array)
layout(set = 0, binding = 9) buffer InputBuffer {
    int boid_indices[];
};

// Binding 10 → sorted_boid_indices buffer (int array)
layout(set = 0, binding = 10) buffer OutputBuffer {
    int sorted_boid_indices[];
};

void main() {
    uint idx = gl_GlobalInvocationID.x;

    // Prevent out-of-bounds access
    if (idx >= boid_indices.length()) {
        return;
    }

    sorted_boid_indices[idx] = boid_indices[idx] + 1;
}