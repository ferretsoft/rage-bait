// Plexi shader - simple brightness detection and blur (optimized)
extern Image source;
extern number brightnessThreshold;
extern vec2 textureSize;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = texture_coords;
    vec2 pixelSize = 1.0 / textureSize;
    
    // Simple box blur with fewer samples for performance
    vec4 blurredBackground = vec4(0.0);
    float totalWeight = 0.0;
    
    // Use a larger blur kernel for more blur effect
    int radius = 3;  // Increased radius for larger blur
    for (int y = -radius; y <= radius; y++) {
        for (int x = -radius; x <= radius; x++) {
            vec2 offset = vec2(float(x), float(y)) * pixelSize;
            vec4 sample = Texel(source, clamp(uv + offset, vec2(0.0), vec2(1.0)));
            blurredBackground += sample;
            totalWeight += 1.0;
        }
    }
    
    if (totalWeight > 0.0) {
        blurredBackground /= totalWeight;
    } else {
        blurredBackground = Texel(source, uv);
    }
    
    // Detect bright pixels and create a mask (grow by 8 pixels)
    // Sample surrounding pixels to expand the mask area
    float maxBrightness = 0.0;
    int growRadius = 2;  // Approximately 8 pixels (2*2+1 = 5, but we'll sample more)
    vec2 growPixelSize = 8.0 / textureSize;  // 8 pixels in UV space
    
    // Check surrounding area for bright pixels
    for (int y = -growRadius; y <= growRadius; y++) {
        for (int x = -growRadius; x <= growRadius; x++) {
            vec2 offset = vec2(float(x), float(y)) * growPixelSize;
            vec4 sample = Texel(source, clamp(uv + offset, vec2(0.0), vec2(1.0)));
            float sampleBrightness = dot(sample.rgb, vec3(0.299, 0.587, 0.114));
            maxBrightness = max(maxBrightness, sampleBrightness);
        }
    }
    
    // Create mask based on maximum brightness in expanded area
    float maskValue = smoothstep(brightnessThreshold, 1.0, maxBrightness);
    
    // Return blurred background with mask (for use in second layer)
    return blurredBackground * maskValue;
}

