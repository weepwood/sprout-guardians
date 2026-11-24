shader_type canvas_item;

// Acrylic: sample scene mipmaps once, then tint and add subtle stable grain.
// Corner radius is in logical pixels, not a fraction of panel width.
uniform sampler2D scene_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod : hint_range(0.0, 5.0) = 3.5;
uniform vec4 tint : source_color = vec4(0.095, 0.12, 0.16, 0.62);
uniform vec2 panel_size = vec2(280.0, 280.0);
uniform float radius = 10.0;
uniform float highlight = 0.08;

void fragment() {
    vec2 p = abs((UV - vec2(0.5)) * panel_size) - panel_size * 0.5 + vec2(radius);
    float distance_to_edge = length(max(p, vec2(0.0))) + min(max(p.x, p.y), 0.0) - radius;
    float edge_mask = 1.0 - smoothstep(-0.7, 0.7, distance_to_edge);
    vec3 backdrop = textureLod(scene_texture, SCREEN_UV, blur_lod).rgb;
    vec3 acrylic = mix(backdrop, tint.rgb, tint.a);
    float grain = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
    float top_light = pow(1.0 - UV.y, 2.0);
    float side_light = max(0.0, 1.0 - length((UV - vec2(0.12, 0.0)) * vec2(1.0, 1.6)));
    float rim = 1.0 - smoothstep(0.0, 1.8, -distance_to_edge);
    COLOR = vec4(acrylic + grain * 0.018 + vec3(highlight * (top_light * 0.45 + side_light * 0.35) + rim * 0.035), edge_mask);
}
