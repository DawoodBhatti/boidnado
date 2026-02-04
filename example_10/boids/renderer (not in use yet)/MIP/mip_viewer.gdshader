shader_type spatial;

uniform sampler3D density_tex;

void fragment() {
    vec2 uv = UV;

    float max_d = 0.0;

    // Sample along Z (128 steps is fine for debugging)
    for (int i = 0; i < 128; i++) {
        float z = float(i) / 127.0;
        float d = texture(density_tex, vec3(uv, z)).r;

        if (d > max_d) {
            max_d = d;
        }
    }

    ALBEDO = vec3(max_d);
    ALPHA = 1.0;
}