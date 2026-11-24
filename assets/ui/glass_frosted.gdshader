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
    float aa = max(fwidth(distance_to_edge) * 0.75, 0.35);
    float edge_mask = 1.0 - smoothstep(-aa, aa, distance_to_edge);
    vec3 backdrop = textureLod(scene_texture, SCREEN_UV, blur_lod).rgb;
    vec3 acrylic = mix(backdrop, tint.rgb, tint.a);
    float grain = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
    float top_light = pow(1.0 - UV.y, 2.0);
    float side_light = max(0.0, 1.0 - length((UV - vec2(0.12, 0.0)) * vec2(1.0, 1.6)));
    float depth = -distance_to_edge;
    float rim = 1.0 - smoothstep(0.3, 1.35, depth);
    float inner = smoothstep(0.8, 1.6, depth) * (1.0 - smoothstep(1.6, 3.3, depth));
    float edge_light = mix(-0.055, 0.13, 1.0 - UV.y);
    vec3 material_color = acrylic + grain * 0.012 + vec3(highlight * (top_light * 0.55 + side_light * 0.25) + rim * edge_light - inner * 0.025);
    COLOR = vec4(clamp(material_color, vec3(0.0), vec3(1.0)), edge_mask);
}
