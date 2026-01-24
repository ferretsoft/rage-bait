// Godray Shader - Fragment Shader
// Applies radial blur to godray lines

extern vec2 center;  // Center point of blur (in 0-1 UV coordinates)
extern float blurStrength;  // Blur strength (0.0 = no blur, higher = more blur)
extern float opacity;  // Overall opacity
extern float brightness;  // Brightness multiplier to fake additive glow

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = texture_coords;
    vec2 dir = uv - center;  // Direction from center to current pixel
    float dist = length(dir);  // Distance from center
    
    // Only blur if we're away from center
    if (dist < 0.001) {
        vec4 result = Texel(texture, uv);
        result.rgb *= brightness;  // Apply brightness for additive glow effect
        // Keep only green channel
        result.r = 0.0;
        result.b = 0.0;
        result.a *= opacity;
        return result * color;
    }
    
    vec2 normalizedDir = dir / dist;  // Normalized direction (from center to current pixel)
    
    // Radial blur: sample along the radial direction (from center outward)
    vec4 result = vec4(0.0);
    float totalWeight = 0.0;
    const int numSamples = 16;  // More samples for smoother blur
    
    // Calculate blur amount - make it very visible
    // For radial blur, we want to sample along the ray direction (from center outward)
    // The blur should create streaks that extend outward
    float blurRange = dist * blurStrength * 0.01;  // Blur range in UV space
    blurRange = min(blurRange, 0.3);  // Cap at 30% of screen
    
    // Sample points along the radial direction (from current position back toward center)
    // This creates streaks radiating outward from center
    for (int i = 0; i < numSamples; i++) {
        float t = float(i) / float(numSamples - 1);
        // Sample from current position (t=0) back toward center (t=1)
        float sampleDist = dist - t * blurRange;
        sampleDist = max(sampleDist, 0.0);  // Don't go past center
        vec2 sampleUV = center + normalizedDir * sampleDist;
        
        // Only sample if within bounds
        if (sampleUV.x >= 0.0 && sampleUV.x <= 1.0 && sampleUV.y >= 0.0 && sampleUV.y <= 1.0) {
            // Weight is highest at current position, decreases as we go toward center
            float weight = 1.0 - t * 0.3;  // Gentle falloff
            weight = max(weight, 0.0);
            vec4 sample = Texel(texture, sampleUV);
            result += sample * weight;
            totalWeight += weight;
        }
    }
    
    if (totalWeight > 0.0) {
        result /= totalWeight;
    } else {
        result = Texel(texture, uv);
    }
    
    // Fake additive glow by boosting brightness
    // Multiply RGB by brightness multiplier to make it glow more
    result.rgb *= brightness;
    
    // Keep only green channel (set red and blue to 0)
    result.r = 0.0;
    result.b = 0.0;
    // Green channel is already set by the brightness multiplication
    
    // Opacity is already applied to the rays when drawing to canvas
    // The opacity uniform is kept for potential future use, but not applied here
    // to avoid double-applying opacity
    
    return result * color;
}
