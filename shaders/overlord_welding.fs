// Welding light: normal map lighting only where main RGB PNG alpha is 1 (mask multiplies result)
extern Image maskTexture;
extern Image excludeTexture;  // Where alpha > 0, do not add light (e.g. head region for banner-only pass)
extern float useExclude;      // 1 = multiply mask by (1 - excludeTexture.a), 0 = ignore excludeTexture
extern vec3 lightDir;         // Direction toward light (centered: from viewer)
extern vec3 lightColor;
extern float intensity;
extern float ambient;
extern float baseWash;
extern float specPower;
extern float specStrength;
extern float time;  // For flicker and light movement

// Simple hash for irregular flicker
float hash(float n) { return fract(sin(n) * 43758.5453); }

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 nSample = Texel(texture, texture_coords);
    // Both banner and head normal maps are DSINE (DirectX-style): green/Y flipped; flip back for tangent-space
    vec3 N = nSample.rgb * 2.0 - 1.0;
    N.y = -N.y;
    N = normalize(N);

    // Light from center (viewer direction) with subtle wobble
    float sway = 0.08 * sin(time * 2.1) + 0.05 * sin(time * 3.7);
    float tilt = 0.06 * sin(time * 1.5);
    vec3 L = normalize(lightDir + vec3(sway, tilt, 0.0));

    vec3 V = vec3(0.0, 0.0, 1.0);
    float NdL = dot(N, L);
    // Small light: only surfaces facing the light; power tightens the lit cone
    float diff = max(0.0, NdL);
    diff = pow(diff, 2.2);
    diff = ambient + (1.0 - ambient) * diff;
    vec3 R = reflect(-L, N);
    float spec = pow(max(0.0, dot(R, V)), specPower);
    float specAmount = spec * specStrength;

    // Flicker: random-heavy welding arc (wider range, more erratic)
    float flicker = 0.75 + 0.15 * sin(time * 23.0) + 0.08 * sin(time * 47.0);
    flicker = flicker + 0.18 * (hash(floor(time * 12.0)) - 0.5);
    flicker = flicker + 0.12 * (hash(floor(time * 31.0) + 7.0) - 0.5);
    flicker = flicker + 0.08 * (hash(floor(time * 5.3) + 13.0) - 0.5);
    flicker = clamp(flicker, 0.45, 1.38);
    float totalIntensity = (diff * intensity + specAmount + baseWash) * flicker;

    vec3 add = lightColor * totalIntensity;
    float mask = Texel(maskTexture, texture_coords).a;
    if (useExclude > 0.5)
        mask *= (1.0 - Texel(excludeTexture, texture_coords).a);
    return vec4(add * mask, mask);
}
