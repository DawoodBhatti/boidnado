#[compute]
#version 450
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;


// Binding 8 - global grid params
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


// Binding 11 - cell_ids
layout(set = 0, binding = 11) buffer CellIdsBuffer {
    int cell_ids[];
};

// Binding 13 - cell_counts
layout(set = 0, binding = 13) buffer CellCountsBuffer {
    int cell_counts[];
};


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

    // Protect against out-of-range cell IDs
    int max_cells = params.grid_dim_x * params.grid_dim_y * params.grid_dim_z;
    if (cell >= max_cells) {
        return;
    }


	// Parallel-safe addition method which avoids race conditions from things like cell_counts[cell] += 1 called by multiple invocations simultaneously
    atomicAdd(cell_counts[cell], 1);
	
	
	//cell_counts[cell] = 5;
	//cell_counts[2] = cell;
	//cell_counts[3] = max_cells;
	//cell_counts[cell+4] = cell;
	//if (cell == 0){
    //cell_counts[5]=555;
    //}else{
    //cell_counts[5]=cell;
    //}
	

	
	
}