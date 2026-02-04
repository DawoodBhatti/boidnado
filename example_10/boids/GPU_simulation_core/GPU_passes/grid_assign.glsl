#[compute]
#version 450

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// Binding 0 - positions_x buffer (float array)
layout(set = 0, binding = 0) buffer xPosBuffer {
    float x_positions[];
};

// Binding 1 - positions_y buffer (float array)
layout(set = 0, binding = 1) buffer yPosBuffer {
    float y_positions[];
};

// Binding 2 - positions_z buffer (float array)
layout(set = 0, binding = 2) buffer zPosBuffer {
    float z_positions[];
};

// Binding 8 - global grid params
// Matches CPU-side packing:
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

// Binding 11 - cell_ids buffer (int array)
layout(set = 0, binding = 11) buffer CellIdsBuffer {
    int cell_ids[];
};

void main() {
    uint idx = gl_GlobalInvocationID.x;

    // Guard against extra threads
    if (idx >= uint(params.boid_count))
        return;


    // ----------------------------------------------------
    // Centered grid:
    //   World box is [-half_extent, +half_extent] on each axis.
    //   Positions inside that box map to [0, dim-1].
    //   Positions outside that box are marked as "no cell" (-1).
    // ----------------------------------------------------
    float half_extent_x = params.cell_size * float(params.grid_dim_x) * 0.5;
    float half_extent_y = params.cell_size * float(params.grid_dim_y) * 0.5;
    float half_extent_z = params.cell_size * float(params.grid_dim_z) * 0.5;

    // Shift world positions into [0, span] before dividing
    float gx_f = (x_positions[idx] + half_extent_x) / params.cell_size;
    float gy_f = (y_positions[idx] + half_extent_y) / params.cell_size;
    float gz_f = (z_positions[idx] + half_extent_z) / params.cell_size;

    // Floor to integer grid coordinates
    int gx = int(floor(gx_f));
    int gy = int(floor(gy_f));
    int gz = int(floor(gz_f));

    // If outside the grid bounds, mark as invalid cell
    if (gx < 0 || gx >= params.grid_dim_x ||
        gy < 0 || gy >= params.grid_dim_y ||
        gz < 0 || gz >= params.grid_dim_z) {
        cell_ids[idx] = -1;
        return;
    }

    // 3D → 1D cell index hash
    int cell = gx
             + gy * params.grid_dim_x
             + gz * (params.grid_dim_x * params.grid_dim_y);

    cell_ids[idx] = cell;
}