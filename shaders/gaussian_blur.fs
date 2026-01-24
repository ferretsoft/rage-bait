// Gaussian Blur Shader - Fragment Shader
// Applies a gaussian blur in a single direction

extern vec2 direction;  // Blur direction (normalized, e.g., {1, 0} for horizontal, {0, 1} for vertical)
extern float radius;  // Blur radius in pixels
extern vec2 textureSize;  // Size of the texture being blurred

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = texture_coords;
    vec2 texelSize = vec2(1.0 / textureSize.x, 1.0 / textureSize.y);
    
    vec4 result = vec4(0.0);
    float totalWeight = 0.0;
    
    // Gaussian blur with 9 samples (4 on each side + center)
    const int samples = 9;
    float weights[9];
    weights[0] = 0.01621622;
    weights[1] = 0.05405405;
    weights[2] = 0.12162162;
    weights[3] = 0.19459459;
    weights[4] = 0.22702703;
    weights[5] = 0.19459459;
    weights[6] = 0.12162162;
    weights[7] = 0.05405405;
    weights[8] = 0.01621622;
    
    for (int i = 0; i < samples; i++) {
        float offset = (float(i) - 4.0) * radius;
        vec2 sampleUV = uv + direction * offset * texelSize;
        
        // Only sample if within bounds
        if (sampleUV.x >= 0.0 && sampleUV.x <= 1.0 && sampleUV.y >= 0.0 && sampleUV.y <= 1.0) {
            result += Texel(texture, sampleUV) * weights[i];
            totalWeight += weights[i];
        }
    }
    
    if (totalWeight > 0.0) {
        result /= totalWeight;
    } else {
        result = Texel(texture, uv);
    }
    
    return result * color;
}

