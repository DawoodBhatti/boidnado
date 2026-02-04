// res://example_9/proof_of_concept/pass3.glsl
#[compute]
#version 450

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) buffer DebugBuf {
    uint value;
};

void main() {
    value = value + 1;
}