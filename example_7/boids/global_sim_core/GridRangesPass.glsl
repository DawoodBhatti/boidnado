#[compute]
#version 450

layout(local_size_x = 256) in;

// Sorted indices
layout(set = 0, binding = 0) buffer SortedIndices {
	int sorted_indices[];
};

// Cell IDs
layout(set = 0, binding = 1) buffer CellIDs {
	int cell_ids[];
};

// Output: start/end
layout(set = 0, binding = 2) buffer CellStart {
	int cell_start[];
};

layout(set = 0, binding = 3) buffer CellEnd {
	int cell_end[];
};

// Grid params
layout(set = 0, binding = 4) uniform GridParams {
	int total_cells;
	int boid_count;
} grid;

void main() {
	uint gid = gl_GlobalInvocationID.x;

	if (gid >= uint(grid.total_cells)) {
		return;
	}

	cell_start[gid] = -1;
	cell_end[gid] = -1;

	for (int i = 0; i < grid.boid_count; i++) {
		int boid_index = sorted_indices[i];
		int cell = cell_ids[boid_index];

		if (cell == int(gid)) {
			if (cell_start[gid] == -1) {
				cell_start[gid] = i;
			}
			cell_end[gid] = i + 1;
		}
	}
}