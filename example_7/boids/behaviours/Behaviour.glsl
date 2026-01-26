#[compute]
#version 450

layout(local_size_x = 256) in;

// ------------------------------------------------------------
// Storage buffers
// ------------------------------------------------------------
layout(set = 0, binding = 0, std430) buffer Positions {
    vec4 positions[];
};

layout(set = 0, binding = 1, std430) buffer Velocities {
    vec4 velocities[];
};

layout(set = 0, binding = 2, std430) buffer SwarmIDs {
    int swarm_ids[];
};

layout(set = 0, binding = 3, std430) buffer CellIDs {
    int cell_ids[];
};

layout(set = 0, binding = 4, std430) buffer SortedIndices {
    int sorted_indices[];
};

layout(set = 0, binding = 5, std430) buffer CellStart {
    int cell_start[];
};

layout(set = 0, binding = 6, std430) buffer CellEnd {
    int cell_end[];
};

// ------------------------------------------------------------
// Uniform buffer: slice + delta
// ------------------------------------------------------------
layout(set = 0, binding = 7) uniform Params {
    float start_index;
    float boid_count;
    float delta;
} params;

// ------------------------------------------------------------
// Uniform buffer: behaviour mask (ints)
// ------------------------------------------------------------
layout(set = 0, binding = 8) uniform Mask {
    int alignment;
    int cohesion;
    int separation;
    int wander;
    int boundary;
} mask;


// ------------------------------------------------------------
// Helper: clamp integer
// ------------------------------------------------------------
int clamp_int(int v, int min_v, int max_v) {
    if (v < min_v) {
        return min_v;
    }
    if (v > max_v) {
        return max_v;
    }
    return v;
}


// ------------------------------------------------------------
// Main behaviour kernel
// ------------------------------------------------------------
void main() {
    uint gid = gl_GlobalInvocationID.x;

    // Slice bounds
    int start_i = int(params.start_index);
    int count   = int(params.boid_count);

    if (gid < uint(start_i)) {
        return;
    }
    if (gid >= uint(start_i + count)) {
        return;
    }

    int boid_index = sorted_indices[gid];

    vec3 pos = positions[boid_index].xyz;
    vec3 vel = velocities[boid_index].xyz;

    // Accumulators
    vec3 align_acc = vec3(0.0);
    vec3 coh_acc   = vec3(0.0);
    vec3 sep_acc   = vec3(0.0);
    int  align_n   = 0;
    int  coh_n     = 0;
    int  sep_n     = 0;

    // Determine cell range
    int cell = cell_ids[boid_index];
    int start = cell_start[cell];
    int end   = cell_end[cell];

    if (start == -1 || end == -1) {
        return;
    }

    // Loop neighbours
    for (int i = start; i <= end; i++) {
        int other_index = sorted_indices[i];

        if (other_index == boid_index) {
            continue;
        }

        vec3 other_pos = positions[other_index].xyz;
        vec3 other_vel = velocities[other_index].xyz;

        vec3 diff = other_pos - pos;
        float dist = length(diff);

        // Alignment
        if (mask.alignment == 1) {
            align_acc += other_vel;
            align_n += 1;
        }

        // Cohesion
        if (mask.cohesion == 1) {
            coh_acc += other_pos;
            coh_n += 1;
        }

        // Separation
        if (mask.separation == 1) {
            if (dist < 1.0) {
                sep_acc -= normalize(diff);
                sep_n += 1;
            }
        }
    }

    // Final steering
    vec3 steering = vec3(0.0);

    if (mask.alignment == 1) {
        if (align_n > 0) {
            steering += (align_acc / float(align_n));
        }
    }

    if (mask.cohesion == 1) {
        if (coh_n > 0) {
            vec3 center = coh_acc / float(coh_n);
            steering += (center - pos);
        }
    }

    if (mask.separation == 1) {
        if (sep_n > 0) {
            steering += (sep_acc / float(sep_n));
        }
    }

    // Wander (simple jitter)
    if (mask.wander == 1) {
        steering += vec3(
            fract(sin(float(boid_index) * 12.9898) * 43758.5453),
            fract(sin(float(boid_index) * 78.233)  * 12345.6789),
            fract(sin(float(boid_index) * 45.543)  * 98765.4321)
        ) * 0.1;
    }

    // Boundary (simple clamp)
    if (mask.boundary == 1) {
        float limit = 50.0;
        if (pos.x < -limit) steering.x += 1.0;
        if (pos.x >  limit) steering.x -= 1.0;
        if (pos.y < -limit) steering.y += 1.0;
        if (pos.y >  limit) steering.y -= 1.0;
        if (pos.z < -limit) steering.z += 1.0;
        if (pos.z >  limit) steering.z -= 1.0;
    }

    // Apply steering
    vel += steering * params.delta;

    velocities[boid_index] = vec4(vel, 0.0);
}