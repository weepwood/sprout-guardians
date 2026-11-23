shader_type canvas_item;

// Single mip-filtered scene sample instead of an expensive multi-pass blur.
uniform sampler2D scene_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod : hint_range(0.0, 5.0) = 2.4;
uniform vec4 tint : source_color = vec4(0.17, 0.25, 0.22, 0.47);
uniform float corner_radius : hint_range(0.0, 0.5) = 0.15;

void fragment() {
    vec2 uv = UV;
    float distance_to_edge = length(max(abs(uv - vec2(0.5)) - vec2(0.5 - corner_radius), vec2(0.0))) - corner_radius;
    float edge_mask = 1.0 - smoothstep(-0.015, 0.018, distance_to_edge);
    vec4 blurred = textureLod(scene_texture, SCREEN_UV, blur_lod);
    COLOR = vec4(mix(blurred.rgb, tint.rgb, tint.a), 0.88 * edge_mask);
}