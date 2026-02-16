shader_type canvas_item;

// Glitch/noise distortion shader for title logo (GDD 21.5)
// Activated when truth_stage >= 3

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float time_scale : hint_range(0.0, 5.0) = 1.0;
uniform float noise_scale : hint_range(1.0, 50.0) = 15.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float chromatic_aberration : hint_range(0.0, 0.05) = 0.01;

// Simple hash function for noise
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Value noise
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec2 uv = UV;
    float time = TIME * time_scale;
    
    // Skip processing if no intensity
    if (intensity < 0.01) {
        COLOR = texture(TEXTURE, uv);
        return;
    }
    
    // Random glitch blocks
    float block = floor(time * 8.0);
    float block_noise = hash(vec2(block, 0.0));
    
    // Horizontal displacement glitch
    float line_noise = noise(vec2(uv.y * noise_scale, time * 2.0));
    float glitch_offset = 0.0;
    
    if (block_noise > 0.7 && intensity > 0.3) {
        float glitch_strength = (block_noise - 0.7) * 3.33 * intensity;
        glitch_offset = (line_noise - 0.5) * 0.1 * glitch_strength;
    }
    
    // Subtle constant waviness
    float wave = sin(uv.y * 30.0 + time * 3.0) * 0.002 * intensity;
    
    // Apply distortion
    vec2 distorted_uv = uv + vec2(glitch_offset + wave, 0.0);
    
    // Chromatic aberration
    float aberration = chromatic_aberration * intensity;
    vec4 color_r = texture(TEXTURE, distorted_uv + vec2(aberration, 0.0));
    vec4 color_g = texture(TEXTURE, distorted_uv);
    vec4 color_b = texture(TEXTURE, distorted_uv - vec2(aberration, 0.0));
    
    vec4 color = vec4(color_r.r, color_g.g, color_b.b, color_g.a);
    
    // Scanlines
    float scanline = sin(uv.y * 400.0) * 0.5 + 0.5;
    scanline = mix(1.0, scanline, scanline_intensity * intensity);
    color.rgb *= scanline;
    
    // Random noise overlay
    float noise_overlay = noise(uv * 100.0 + time * 10.0);
    color.rgb = mix(color.rgb, vec3(noise_overlay), 0.03 * intensity);
    
    // Occasional color inversion on glitch blocks
    if (block_noise > 0.9 && intensity > 0.5) {
        float invert_band = step(0.4, fract(uv.y * 5.0 + time));
        color.rgb = mix(color.rgb, 1.0 - color.rgb, invert_band * 0.3);
    }
    
    COLOR = color;
}
