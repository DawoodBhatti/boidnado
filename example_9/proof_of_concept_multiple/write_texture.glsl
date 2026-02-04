#[compute]
#version 450

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(r32ui, binding = 0) uniform writeonly uimage2D data_tex;

layout(push_constant, std430) uniform Params {
    uint value;
} params;

void main() {
    imageStore(data_tex, ivec2(0, 0), uvec4(params.value, 0u, 0u, 0u));
}