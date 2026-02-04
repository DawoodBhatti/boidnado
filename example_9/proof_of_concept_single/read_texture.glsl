#[compute]
#version 450


layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(r32ui, binding = 0) uniform readonly uimage2D data_tex;

layout(std430, binding = 1) buffer DebugBuffer {
    uint value;
} debug_buf;

void main() {
    uvec4 texel = imageLoad(data_tex, ivec2(0, 0));
    debug_buf.value = texel.r;
}