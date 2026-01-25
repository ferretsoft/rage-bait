// Shader to apply blurred background and mask to plexi texture
// texture is the plexi texture being drawn
extern Image mask;  // Contains blurred background * mask
extern number opacity;
extern vec2 screenSize;  // Screen size for coordinate conversion

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 plexiColor = Texel(texture, texture_coords);
    
    // Convert screen coordinates to UV coordinates for mask (0-1 range)
    vec2 maskUV = screen_coords / screenSize;
    vec4 blurredMask = Texel(mask, maskUV);
    
    // Add blurred background, then multiply by plexi
    vec4 result = blurredMask * plexiColor * opacity;
    
    return result * color;
}

