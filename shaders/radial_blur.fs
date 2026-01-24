// Radial Blur Shader - Fragment Shader
// Creates a radial blur effect emanating from a center point

extern vec2 center;  // Center point of blur (in 0-1 UV coordinates)
extern float strength;  // Blur strength (0.0 = no blur, higher = more blur)

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = texture_coords;
    vec2 dir = uv - center;  // Direction from center to current pixel
    float dist = length(dir);  // Distance from center
    
    // Only blur if we're away from center
    if (dist < 0.001) {
        return Texel(texture, uv) * color;
    }
    
    vec2 normalizedDir = dir / dist;  // Normalized direction (from center to current pixel)
    
    // Inverted radial blur: blur increases with distance from center
    // Sample along the direction from current pixel toward center
    vec4 result = vec4(0.0);
    float totalWeight = 0.0;
    const int numSamples = 16;  // More samples for smoother blur
    
    // Calculate blur amount based on distance from center (further = more blur)
    float blurAmount = min(dist * strength, 1.0);  // Clamp blur amount
    
    // Sample points along the direction from current pixel toward center
    for (int i = 0; i < numSamples; i++) {
        float t = float(i) / float(numSamples - 1);
        // Sample inward toward center - the further from center, the more we sample inward
        // At center (dist=0): no blur, just original pixel
        // Far from center: sample many points going inward
        float sampleDist = dist * (1.0 - t * blurAmount);  // Sample from current position inward
        vec2 sampleUV = center + normalizedDir * sampleDist;
        
        // Only sample if within bounds
        if (sampleUV.x >= 0.0 && sampleUV.x <= 1.0 && sampleUV.y >= 0.0 && sampleUV.y <= 1.0) {
            // Weight increases as we go further from center (more blur) - much less falloff
            float weight = 1.0 - (t * 0.3);  // Very gentle linear falloff
            result += Texel(texture, sampleUV) * weight;
            totalWeight += weight;
        }
    }
    
    if (totalWeight > 0.0) {
        result /= totalWeight;
    } else {
        result = Texel(texture, uv);
    }
    
    return result * color;
}

