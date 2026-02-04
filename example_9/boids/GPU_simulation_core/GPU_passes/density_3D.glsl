#[compute]
#version 450
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// Binding 13 - cell_counts
layout(set = 0, binding = 13) readonly buffer CellCountsBuffer {
    uint cell_counts[];
};

// Binding 8 - global params (same layout as other passes)
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

// Binding 16 - 3D density image
layout(set = 0, binding = 16) uniform writeonly image3D density_volume;

// 1D → 3D cell coords using *params* fields
ivec3 cell_index_to_coord(int idx) {
    int xy = params.grid_dim_x * params.grid_dim_y;

    int z   = idx / xy;
    int rem = idx - z * xy;

    int y = rem / params.grid_dim_x;
    int x = rem - y * params.grid_dim_x;

    return ivec3(x, y, z);
}

void main() {
    uint gid = gl_GlobalInvocationID.x;

    int total_cells = params.grid_dim_x * params.grid_dim_y * params.grid_dim_z;
    if (int(gid) >= total_cells) {
        return;
    }

    uint count = cell_counts[gid];
    float density = float(count);

    ivec3 coord = cell_index_to_coord(int(gid));
    imageStore(density_volume, coord, vec4(density, 0.0, 0.0, 0.0));
}