#[compute]
#version 450
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// binding = 8 (u_global)
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

// binding = 13 (u_cell_counts)
layout(set = 0, binding = 13) buffer CellCountsBuffer {
    int cell_counts[];
};


// binding = 14 (u_cell_offsets)
layout(set = 0, binding = 14) buffer CellOffsetsBuffer {
    int cell_offsets[];
};


// binding = 15 (u_cell_mapping)
// cell_mapping[c] = ivec2(start, end) with end exclusive
layout(set = 0, binding = 15) buffer CellMappingBuffer {
    ivec2 cell_mapping[];
};


void main() {
    uint cell = gl_GlobalInvocationID.x;

    int total_cells = params.grid_dim_x * params.grid_dim_y * params.grid_dim_z;
    if (int(cell) >= total_cells) {
        return;
    }

    int count = cell_counts[cell];
    int start = cell_offsets[cell];
    int end   = start + count;

    // Empty cells become (start, start); behaviour can treat that as empty
    cell_mapping[cell] = ivec2(start, end);
}