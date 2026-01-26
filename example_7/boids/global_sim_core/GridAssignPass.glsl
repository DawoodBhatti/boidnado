#[compute]
#version 450

layout(local_size_x = 256) in;

// Positions
layout(set = 0, binding = 0) buffer Positions {
	vec4 positions[];
};

// Output: cell IDs
layout(set = 0, binding = 1) buffer CellIDs {
	int cell_ids[];
};

// Grid params
layout(set = 0, binding = 2) uniform GridParams {
	float cell_size;
	int grid_dim_x;
	int grid_dim_y;
	int grid_dim_z;
} grid;

int clamp_int(int v, int min_v, int max_v) {
	if (v < min_v) {
		return min_v;
	}
	if (v > max_v) {
		return max_v;
	}
	return v;
}

void main() {
	uint gid = gl_GlobalInvocationID.x;

	vec3 pos = positions[gid].xyz;

	int cx = int(floor(pos.x / grid.cell_size));
	int cy = int(floor(pos.y / grid.cell_size));
	int cz = int(floor(pos.z / grid.cell_size));

	cx = clamp_int(cx, 0, grid.grid_dim_x - 1);
	cy = clamp_int(cy, 0, grid.grid_dim_y - 1);
	cz = clamp_int(cz, 0, grid.grid_dim_z - 1);

	int index = cx
		+ cy * grid.grid_dim_x
		+ cz * grid.grid_dim_x * grid.grid_dim_y;

	cell_ids[gid] = index;
}