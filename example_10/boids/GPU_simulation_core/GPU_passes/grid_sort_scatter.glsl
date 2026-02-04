#[compute]
#version 450
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// Binding 11 - cell_ids (input from GridAssign)
layout(set = 0, binding = 11) buffer CellIdsBuffer {
    int cell_ids[];
};

// Binding 9 - boid_indices (input)
layout(set = 0, binding = 9) buffer BoidIndexBuffer {
    int boid_indices[];
};

// Binding 10 - sorted_boid_indices (output)
layout(set = 0, binding = 10) buffer SortedBoidIndexBuffer {
    int sorted_boid_indices[];
};

// Binding 12 - sorted_cell_ids (output)
layout(set = 0, binding = 12) buffer SortedCellIdBuffer {
    int sorted_cell_ids[];
};

// Binding 14 - cell_offsets (prefix results, used as atomic counters)
layout(set = 0, binding = 14) buffer CellOffsetsBuffer {
    int cell_offsets[];
};

// Binding 8 - global params
// MUST match CPU packing exactly:
//
//   float cell_size;
//   int   boid_count;
//   int   grid_dim_x;
//   int   grid_dim_y;
//   int   grid_dim_z;
//   int   pad0;
//   int   pad1;
//   int   pad2;
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
    uint idx = gl_GlobalInvocationID.x;

    // Only real boids participate
    if (idx >= uint(params.boid_count)) {
        return;
    }

    int cell = cell_ids[idx];

    // Ignore invalid cells
    if (cell < 0) {
        return;
    }

    int max_cells = params.grid_dim_x * params.grid_dim_y * params.grid_dim_z;

	// Ignore cells outside of defined bounds
    if (cell >= max_cells) {
        return;
    }

    // Reserve a slot in this cell's sorted range
    int offset = atomicAdd(cell_offsets[cell], 1);

    // Scatter boid index + cell id
    sorted_boid_indices[offset] = boid_indices[idx];
    sorted_cell_ids[offset]     = cell;
}