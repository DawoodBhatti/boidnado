#[compute]
#version 450
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// Binding 13 - cell_counts (input histogram)
layout(set = 0, binding = 13) buffer CellCountsBuffer {
    int cell_counts[];
};

// Binding 14 - cell_offsets (output prefix sum)
layout(set = 0, binding = 14) buffer CellOffsetsBuffer {
    int cell_offsets[];
};

// Binding 8 - global grid params
// Must match CPU-side packing EXACTLY:
//
//   float cell_size;   // 4 bytes
//   int   boid_count;  // 4 bytes
//   int   grid_dim_x;  // 4 bytes
//   int   grid_dim_y;  // 4 bytes
//   int   grid_dim_z;  // 4 bytes
//   int   pad0;        // 4 bytes
//   int   pad1;        // 4 bytes
//   int   pad2;        // 4 bytes
//
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
    uint cell = gl_GlobalInvocationID.x;

    // Total number of grid cells
    int max_cells = params.grid_dim_x * params.grid_dim_y * params.grid_dim_z;

    // Out-of-range threads do nothing
    if (cell >= uint(max_cells)) {
        return;
    }

    // Exclusive prefix sum:
    //   offset[cell] = sum(counts[0 .. cell-1])
    int sum = 0;

    for (uint i = 0; i < cell; i++) {
        sum += cell_counts[i];
    }

    cell_offsets[cell] = sum;
}