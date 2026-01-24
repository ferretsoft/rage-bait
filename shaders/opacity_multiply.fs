// Opacity Multiply Shader - Fragment Shader
// Multiplies the texture by an opacity value

extern float opacity;  // Opacity multiplier (0.0 to 1.0)

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 texColor = Texel(texture, texture_coords);
    return texColor * color * opacity;
}


