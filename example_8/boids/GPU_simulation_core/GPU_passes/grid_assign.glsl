#[compute]
#version 450

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;


// Binding 0 → positions_x buffer (float array)
layout(set = 0, binding = 0) buffer xPosBuffer {
    float x_positions[];
};

// Binding 1 → positions_y buffer (float array)
layout(set = 0, binding = 1) buffer yPosBuffer {
    float y_positions[];
};

// Binding 2 → positions_z buffer (float array)
layout(set = 0, binding = 2) buffer zPosBuffer {
    float z_positions[];
};


// Binding 8 → cell size buffer (int)
layout(set = 0, binding = 8) uniform CellSize {
    int cell_size;
};


// Binding 11 → cell_ids buffer (int array)
layout(set = 0, binding = 11) buffer CellIdsBuffer {
    int cell_ids[];
};



void main() {
    uint idx = gl_GlobalInvocationID.x;

	if (idx >= x_positions.length())
		return;

    // calculate the cell hash 
   // cell_ids[idx] = int(x_positions[idx]) + int(y_positions[idx]) * cell_size + int(z_positions[idx]) * cell_size * cell_size;
    cell_ids[idx] =  cell_size ;
}
