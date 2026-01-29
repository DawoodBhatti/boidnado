#[compute]
#[version 450]

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// Binding 5 → unsorted boid index buffer (int array)
layout(set = 0, binding = 5) buffer InputBuffer {
    float boid_index[];
};

// Binding 6 → unsorted cell id buffer (float array)
layout(set = 0, binding = 6) buffer ConstantsBuffer {
    float constants[];
};


void main() {
    uint idx = gl_GlobalInvocationID.x;

    // Simple test: output = input + constants[0]
    output_data[idx] = input_data[idx] + constants[0];
}
