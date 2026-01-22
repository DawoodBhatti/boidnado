shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

uniform vec4 color_white : source_color;
uniform vec4 color_grey : source_color;
uniform float squares;

void fragment() {
    vec2 scaled = UV * squares;

    int xi = int(floor(scaled.x));
    int yi = int(floor(scaled.y));
    int sum = xi + yi;

    bool is_white = (sum % 2) == 0;

    vec4 col = color_grey;
    if (is_white) {
        col = color_white;
    }

    ALBEDO = col.rgb;
    ALPHA = col.a;
}