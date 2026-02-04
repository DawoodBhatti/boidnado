shader_type spatial;

uniform sampler3D density_tex;
uniform float slice_z; // 0.0 → 1.0

void fragment() {
    // UV from the quad
    vec2 uv = UV;

    // Sample the 3D texture at (x, y, z)
    float d = texture(density_tex, vec3(uv, slice_z)).r;

    // Simple grayscale mapping
    ALBEDO = vec3(d);
    ALPHA = 1.0;
}