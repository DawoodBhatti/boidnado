#[compute]
#version 450
layout(local_size_x = 256) in;

// ------------------------------------------------------------
// Buffers (must match GridSortPass.gd bindings)
// ------------------------------------------------------------
layout(set = 0, binding = 0, std430) buffer CellIDs {
    int cell_ids[];
};

layout(set = 0, binding = 1, std430) buffer SortedIndices {
    int sorted_indices[];
};

// ------------------------------------------------------------
// Push constants (16 bytes, like your ocean shader)
// ------------------------------------------------------------
layout(push_constant) uniform Params {
    int total_boids;  // offset 0
    int stage;        // offset 4
    int pass;         // offset 8
    int pad;          // offset 12
} params;

// ------------------------------------------------------------
// Main bitonic compare kernel
// ------------------------------------------------------------
void main() {
    uint i = gl_GlobalInvocationID.x;

    if (i >= uint(params.total_boids)) {
        return;
    }

    uint j = i ^ uint(params.pass);

    if (j >= uint(params.total_boids)) {
        return;
    }

    int key_i = cell_ids[sorted_indices[i]];
    int key_j = cell_ids[sorted_indices[j]];

    bool ascending = ((i & uint(params.stage)) == 0);

    bool swap = ascending ? (key_i > key_j) : (key_i < key_j);

    if (swap) {
        int tmp = sorted_indices[i];
        sorted_indices[i] = sorted_indices[j];
        sorted_indices[j] = tmp;
    }
}