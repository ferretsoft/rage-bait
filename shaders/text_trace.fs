// Text Trace Shader - Fragment Shader
// Traces lines from text to a center point

extern vec2 center;  // Center point (in 0-1 UV coordinates)
extern vec2 textPos;  // Text position (in 0-1 UV coordinates)
extern float lineWidth;  // Width of the trace line
extern float opacity;  // Opacity of the line
extern vec3 lineColor;  // Color of the line (RGB)

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = texture_coords;
    
    // Calculate direction from text to center
    vec2 dir = center - textPos;
    float distToCenter = length(dir);
    
    // If text position is at center, don't draw
    if (distToCenter < 0.001) {
        return vec4(0.0, 0.0, 0.0, 0.0);
    }
    
    vec2 normalizedDir = dir / distToCenter;
    
    // Calculate distance from current pixel to the line segment from textPos to center
    vec2 toPixel = uv - textPos;
    float projection = dot(toPixel, normalizedDir);
    
    // Clamp projection to line segment
    projection = clamp(projection, 0.0, distToCenter);
    
    // Find closest point on line segment
    vec2 closestPoint = textPos + normalizedDir * projection;
    
    // Distance from pixel to line
    float distToLine = length(uv - closestPoint);
    
    // Convert line width from pixels to UV space (approximate)
    float lineWidthUV = lineWidth / love_ScreenSize.x;
    
    // Draw line with smooth falloff
    float alpha = 1.0 - smoothstep(0.0, lineWidthUV, distToLine);
    alpha *= opacity;
    
    // Only draw if we're on the line segment
    if (projection < 0.0 || projection > distToCenter) {
        alpha = 0.0;
    }
    
    vec4 result = vec4(lineColor, alpha);
    return result * color;
}


