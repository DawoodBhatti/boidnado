#[compute]
#version 450
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// Positions
layout(set = 0, binding = 0) buffer XPosBuffer { float x_positions[]; };
layout(set = 0, binding = 1) buffer YPosBuffer { float y_positions[]; };
layout(set = 0, binding = 2) buffer ZPosBuffer { float z_positions[]; };

// Velocities
layout(set = 0, binding = 3) buffer XVelBuffer { float x_velocities[]; };
layout(set = 0, binding = 4) buffer YVelBuffer { float y_velocities[]; };
layout(set = 0, binding = 5) buffer ZVelBuffer { float z_velocities[]; };

// Swarm params (16 floats per swarm)
layout(set = 0, binding = 6) buffer SwarmParamsBuffer {
    float swarm_params[];
};

// Boid → swarm map
layout(set = 0, binding = 7) buffer BoidToSwarmBuffer {
    int boid_to_swarm[];
};

// Global params
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

// Sorted grid
layout(set = 0, binding = 10) buffer SortedBoidIndexBuffer {
    int sorted_boid_indices[];
};

layout(set = 0, binding = 12) buffer SortedCellIdBuffer {
    int sorted_cell_ids[];
};

layout(set = 0, binding = 15) buffer CellMappingBuffer {
    ivec2 cell_mapping[];
};

const int FLOATS_PER_SWARM = 16;

struct Swarm {
    float start_index;
    float count;
    float sight_radius;
    float fov_angle_deg;
    float cage_radius;
    float desired_separation;
    float alignment_weight;
    float cohesion_weight;
    float separation_weight;
    float wander_strength;
    float boundary_strength;
    float alignment_mask;
    float cohesion_mask;
    float separation_mask;
    float wander_mask;
    float boundary_mask;
};

Swarm load_swarm(int swarm_id) {
    int base = swarm_id * FLOATS_PER_SWARM;
    Swarm s;
    s.start_index        = swarm_params[base + 0];
    s.count              = swarm_params[base + 1];
    s.sight_radius       = swarm_params[base + 2];
    s.fov_angle_deg      = swarm_params[base + 3];
    s.cage_radius        = swarm_params[base + 4];
    s.desired_separation = swarm_params[base + 5];
    s.alignment_weight   = swarm_params[base + 6];
    s.cohesion_weight    = swarm_params[base + 7];
    s.separation_weight  = swarm_params[base + 8];
    s.wander_strength    = swarm_params[base + 9];
    s.boundary_strength  = swarm_params[base + 10];
    s.alignment_mask     = swarm_params[base + 11];
    s.cohesion_mask      = swarm_params[base + 12];
    s.separation_mask    = swarm_params[base + 13];
    s.wander_mask        = swarm_params[base + 14];
    s.boundary_mask      = swarm_params[base + 15];
    return s;
}

float rand01(uint seed) {
    seed ^= seed << 13;
    seed ^= seed >> 17;
    seed ^= seed << 5;
    return float(seed) / 4294967295.0;
}

void main() {
    uint boid = gl_GlobalInvocationID.x;
    if (boid >= uint(params.boid_count)) {
        return;
    }

    // Load position & velocity
    vec3 pos = vec3(
        x_positions[boid],
        y_positions[boid],
        z_positions[boid]
    );

    vec3 vel = vec3(
        x_velocities[boid],
        y_velocities[boid],
        z_velocities[boid]
    );

    // Swarm lookup
    int swarm_id = boid_to_swarm[boid];
    Swarm s = load_swarm(swarm_id);

    // Precompute FOV cosine
    float half_fov_rad = radians(s.fov_angle_deg * 0.5);
    float cos_fov = cos(half_fov_rad);

    vec3 accel = vec3(0.0);

    // ---------------------------------------------------------
    // Neighbour search via grid
    // ---------------------------------------------------------
    // Compute this boid's cell index (reuse your grid_assign logic or read from cell_ids)
    // For simplicity here, assume you recompute cell from position:
    float half_extent_x = params.cell_size * float(params.grid_dim_x) * 0.5;
    float half_extent_y = params.cell_size * float(params.grid_dim_y) * 0.5;
    float half_extent_z = params.cell_size * float(params.grid_dim_z) * 0.5;

    float gx_f = (pos.x + half_extent_x) / params.cell_size;
    float gy_f = (pos.y + half_extent_y) / params.cell_size;
    float gz_f = (pos.z + half_extent_z) / params.cell_size;

    int gx = int(floor(gx_f));
    int gy = int(floor(gy_f));
    int gz = int(floor(gz_f));

    if (gx < 0 || gx >= params.grid_dim_x ||
        gy < 0 || gy >= params.grid_dim_y ||
        gz < 0 || gz >= params.grid_dim_z) {
        // Outside grid: maybe just apply boundary and bail
    } else {
        vec3 align_sum = vec3(0.0);
        vec3 cohesion_sum = vec3(0.0);
        vec3 separation_sum = vec3(0.0);
        int neighbour_count = 0;
        int separation_count = 0;

        vec3 forward = normalize(vel + vec3(1e-6)); // avoid NaN

        // Loop over 27 neighbour cells
        for (int dz = -1; dz <= 1; dz++) {
            for (int dy = -1; dy <= 1; dy++) {
                for (int dx = -1; dx <= 1; dx++) {
                    int nx = gx + dx;
                    int ny = gy + dy;
                    int nz = gz + dz;

                    if (nx < 0 || nx >= params.grid_dim_x ||
                        ny < 0 || ny >= params.grid_dim_y ||
                        nz < 0 || nz >= params.grid_dim_z) {
                        continue;
                    }

                    int ncell = nx
                              + ny * params.grid_dim_x
                              + nz * (params.grid_dim_x * params.grid_dim_y);

                    ivec2 range = cell_mapping[ncell];
                    int start = range.x;
                    int end   = range.y;

                    for (int k = start; k < end; k++) {
                        int other_boid = sorted_boid_indices[k];
                        if (other_boid == int(boid)) {
                            continue;
                        }

                        vec3 other_pos = vec3(
                            x_positions[other_boid],
                            y_positions[other_boid],
                            z_positions[other_boid]
                        );

                        vec3 to_other = other_pos - pos;
                        float dist = length(to_other);
                        if (dist <= 0.0001) {
                            continue;
                        }

                        // Optional sight radius
                        if (s.sight_radius > 0.0 && dist > s.sight_radius) {
                            continue;
                        }

                        // FOV check
                        vec3 dir = to_other / dist;
                        float d = dot(forward, dir);
                        if (d < cos_fov) {
                            continue;
                        }

                        neighbour_count++;

                        // Alignment
                        if (s.alignment_mask > 0.5) {
                            vec3 other_vel = vec3(
                                x_velocities[other_boid],
                                y_velocities[other_boid],
                                z_velocities[other_boid]
                            );
                            align_sum += other_vel;
                        }

                        // Cohesion
                        if (s.cohesion_mask > 0.5) {
                            cohesion_sum += other_pos;
                        }

                        // Separation
                        if (s.separation_mask > 0.5 && dist < s.desired_separation) {
                            separation_sum += (-dir) / dist;
                            separation_count++;
                        }
                    }
                }
            }
        }

        // Apply alignment
        if (neighbour_count > 0 && s.alignment_mask > 0.5 && s.alignment_weight != 0.0) {
            vec3 avg_vel = align_sum / float(neighbour_count);
            vec3 steer = (avg_vel - vel);
            accel += steer * s.alignment_weight;
        }

        // Apply cohesion
        if (neighbour_count > 0 && s.cohesion_mask > 0.5 && s.cohesion_weight != 0.0) {
            vec3 avg_pos = cohesion_sum / float(neighbour_count);
            vec3 desired = (avg_pos - pos);
            accel += desired * s.cohesion_weight;
        }

        // Apply separation
        if (separation_count > 0 && s.separation_mask > 0.5 && s.separation_weight != 0.0) {
            vec3 sep = separation_sum / float(separation_count);
            accel += sep * s.separation_weight;
        }
    }

    // Wander
    if (s.wander_mask > 0.5 && s.wander_strength != 0.0) {
        uint seed = boid * 9781u + uint(gl_WorkGroupID.x) * 6271u + uint(gl_WorkGroupID.y) * 7919u;
        vec3 rand_vec = vec3(
            rand01(seed),
            rand01(seed ^ 0x12345678u),
            rand01(seed ^ 0x87654321u)
        ) * 2.0 - vec3(1.0);
        rand_vec = normalize(rand_vec + vec3(1e-6));
        accel += rand_vec * s.wander_strength;
    }

    // Boundary potential
    if (s.boundary_mask > 0.5 && s.boundary_strength != 0.0) {
        float dist = length(pos);
        float threshold = 0.8 * s.cage_radius;
        if (dist > threshold) {
            vec3 normal = pos / max(dist, 1e-4);
            float margin = max(dist - s.cage_radius, 0.001);
            float strength = s.boundary_strength * margin;
            vec3 inward = -normal;
            accel += inward * strength;
        }
    }

    // ---------------------------------------------------------
    // Integrate (simple Euler)
	// Placeholder for now until behaviours work well
    // ---------------------------------------------------------
    float dt = 0.016; // or pass in via global params if you want

    vel += accel * dt;

    // Optional: clamp speed
    float speed = length(vel);
    float max_speed = 20.0;
    if (speed > max_speed) {
        vel = vel * (max_speed / speed);
    }

    pos += vel * dt;

    // Write back
    x_positions[boid] = pos.x;
    y_positions[boid] = pos.y;
    z_positions[boid] = pos.z;

    x_velocities[boid] = vel.x;
    y_velocities[boid] = vel.y;
    z_velocities[boid] = vel.z;
}