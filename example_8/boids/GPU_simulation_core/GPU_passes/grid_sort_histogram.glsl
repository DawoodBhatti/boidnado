#[compute]
#version 450
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// Binding 11 - cell_ids
layout(set = 0, binding = 11) buffer CellIdsBuffer {
    int cell_ids[];
};

// Binding 13 - cell_counts
layout(set = 0, binding = 13) buffer CellCountsBuffer {
    int cell_counts[];
};

// Binding 8 - global grid params
// Matches your CPU-side packing:
//   float cell_size;
//   int   boid_count;
//   int   grid_dim_x;
//   int   grid_dim_y;
//   int   grid_dim_z;
//   int   pad0;
//   int   pad1;
//   int   pad2;
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

    if (idx >= uint(params.boid_count)) {
        return;
    }

    int cell = cell_ids[idx];

    if (cell < 0) {
        return;
    }

    // Protect against out-of-range cell IDs
    int max_cells = params.grid_dim_x * params.grid_dim_y * params.grid_dim_z;
    if (cell >= max_cells) {
        return;
    }

    atomicAdd(cell_counts[cell], 1);
}