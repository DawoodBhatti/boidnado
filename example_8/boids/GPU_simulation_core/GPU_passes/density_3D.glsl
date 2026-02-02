#[compute]
#version 450

// Match your local size to your existing passes (e.g. 64)
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// Binding indices must match your RDUniform bindings
layout(std430, binding = 13) readonly buffer CellCountsBuffer {
    uint cell_counts[];
};

layout(std140, binding = 8) uniform GlobalParams {
    int total_boids;
    float grid_cell_size;
    int grid_dim_x;
    int grid_dim_y;
    int grid_dim_z;
    // ...whatever else you already have
};

layout(r32f, binding = 16) uniform writeonly image3D density_volume;


// Helper: map 1D cell index → 3D coords
ivec3 cell_index_to_coord(int idx) {
    int xy = grid_dim_x * grid_dim_y;

    int z = idx / xy;
    int rem = idx - z * xy;

    int y = rem / grid_dim_x;
    int x = rem - y * grid_dim_x;

    return ivec3(x, y, z);
}


void main() {
    uint gid = gl_GlobalInvocationID.x;

    int total_cells = grid_dim_x * grid_dim_y * grid_dim_z;
    if (int(gid) >= total_cells) {
        return;
    }

    uint count = cell_counts[gid];

    // Simple density: raw count (you can normalise later if you like)
    float density = float(count);

    ivec3 coord = cell_index_to_coord(int(gid));

    // Write density into the 3D texture
    imageStore(density_volume, coord, vec4(density, 0.0, 0.0, 0.0));
}