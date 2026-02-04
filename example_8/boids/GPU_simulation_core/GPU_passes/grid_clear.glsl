#[compute]
#version 450

layout(local_size_x = 64) in;

layout(set = 0, binding = 13) buffer CellCounts {
    int cell_counts[];
};

layout(set = 0, binding = 14) buffer CellOffsets {
    int cell_offsets[];
};

layout(set = 0, binding = 8) uniform GlobalParams {
    float cell_size;
    int   boid_count;
    int   grid_dim_x;
    int   grid_dim_y;
    int   grid_dim_z;
    int   pad0;
    int   pad1;
    int   pad2;
} params;

void main() {
    uint idx = gl_GlobalInvocationID.x;
    uint max_cells = uint(params.grid_dim_x * params.grid_dim_y * params.grid_dim_z);

    if (idx >= max_cells)
        return;

    cell_counts[idx] = 0;
    cell_offsets[idx] = 0;
}