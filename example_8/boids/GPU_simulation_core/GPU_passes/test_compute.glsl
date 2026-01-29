#[compute]
#version 450

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// Binding 0 → input buffer (float array)
layout(set = 0, binding = 0) buffer InputBuffer {
    float input_data[];
};

// Binding 1 → constants buffer (float array)
layout(set = 0, binding = 1) buffer ConstantsBuffer {
    float constants[];
};

// Binding 2 → output buffer (float array)
layout(set = 0, binding = 2) buffer OutputBuffer {
    float output_data[];
};

void main() {
    uint idx = gl_GlobalInvocationID.x;

    // Simple test: output = input + constants[0]
    output_data[idx] = input_data[idx] + constants[0];
}
