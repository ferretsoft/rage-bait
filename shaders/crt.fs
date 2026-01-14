// CRT Shader - Fragment Shader
// Creates retro CRT monitor effects: scanlines, curvature, chromatic aberration, vignette

extern vec2 screenSize;
extern float curvature;
extern float scanlineIntensity;
extern float chromaIntensity;
extern float vignetteIntensity;
extern float time;

vec2 curve(vec2 uv) {
    // Barrel distortion (curvature effect)
    uv = uv * 2.0 - 1.0;
    vec2 offset = abs(uv.yx) / vec2(curvature, curvature);
    uv = uv + uv * offset * offset;
    uv = uv * 0.5 + 0.5;
    return uv;
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = texture_coords;
    
    // Apply curvature
    uv = curve(uv);
    
    // Clamp to prevent sampling outside texture
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }
    
    // Chromatic aberration (color separation)
    float chromaOffset = chromaIntensity * 0.003;
    vec4 r = Texel(texture, uv + vec2(chromaOffset, 0.0));
    vec4 g = Texel(texture, uv);
    vec4 b = Texel(texture, uv - vec2(chromaOffset, 0.0));
    
    vec4 col = vec4(r.r, g.g, b.b, g.a);
    
    // Scanlines (horizontal lines)
    float scanline = sin(uv.y * screenSize.y * 0.7) * 0.5 + 0.5;
    scanline = pow(scanline, 8.0);
    col.rgb *= mix(1.0, scanline, scanlineIntensity);
    
    // Vignette (darkening at edges)
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(uv, center);
    float vignette = 1.0 - smoothstep(0.3, 1.0, dist) * vignetteIntensity;
    col.rgb *= vignette;
    
    // Subtle brightness variation (flicker)
    float flicker = 0.98 + sin(time * 10.0) * 0.02;
    col.rgb *= flicker;
    
    return col * color;
}







