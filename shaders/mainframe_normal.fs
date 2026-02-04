// MainFrame/Plexi normal map: playfield lights (units, projectiles, areas) light the frame.
// Normal map is Metric3D (OpenGL-style): no Y flip.
// useLumaAlpha: 0 = mask by maskTexture.a (MainFrame), 1 = mask by luma of maskTexture.rgb (plexi).
// brightness: multiply final light (e.g. 0.5 = 50% for plexi).
// useSceneLight + sceneTexture: when 1, add lighting from scene (background) so every screen feeds the plexi.

extern Image maskTexture;
extern float useLumaAlpha;      // 0 = alpha channel, 1 = luma as alpha (plexi)
extern float brightness;        // 1.0 = full, 0.5 = 50% (plexi)
extern float useSceneLight;    // 0 = off, 1 = add scene texture luma as light (plexi on all screens)
extern Image sceneTexture;     // content behind plexi (when useSceneLight = 1)
extern vec2 sceneSize;         // scene texture size for UV (e.g. SCREEN_WIDTH, SCREEN_HEIGHT)
extern int lightCount;
extern vec4 lightPosRadius[32]; // x, y, radius, 0 per light (screen pixels)
extern vec4 lightColor[32];     // r, g, b, a per light

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 nSample = Texel(texture, texture_coords);
    // Metric3D: OpenGL-style tangent-space normals (no Y flip)
    vec3 N = nSample.rgb * 2.0 - 1.0;
    N = normalize(N);

    vec3 acc = vec3(0.0, 0.0, 0.0);
    int n = int(min(float(lightCount), 32.0));

    for (int i = 0; i < 32; i++) {
        float useLight = (float(i) < float(n)) ? 1.0 : 0.0;
        vec4 pr = lightPosRadius[i];
        vec2 lightPos = pr.xy;
        float radius = max(pr.z, 1.0);
        vec4 lc = lightColor[i];
        vec2 d = lightPos - screen_coords;
        float dist = length(d);
        float att = 1.0 - smoothstep(0.0, radius, dist);
        att *= useLight;
        vec3 L = normalize(vec3(d.x, d.y, 50.0));
        float NdL = max(0.0, dot(N, L));
        NdL = pow(NdL, 1.5);
        acc += lc.rgb * (lc.a * att * NdL);
    }

    // Plexi: add light from scene (background) so every screen feeds the plexi
    if (useSceneLight > 0.5 && sceneSize.x > 0.0 && sceneSize.y > 0.0) {
        vec2 uv = clamp(screen_coords / sceneSize, vec2(0.0), vec2(1.0));
        vec4 sceneSample = Texel(sceneTexture, uv);
        float sceneLuma = dot(sceneSample.rgb, vec3(0.299, 0.587, 0.114));
        acc += vec3(sceneLuma, sceneLuma, sceneLuma) * 0.5;
    }

    acc *= brightness;

    vec4 maskSample = Texel(maskTexture, texture_coords);
    float mask = (useLumaAlpha > 0.5) ? dot(maskSample.rgb, vec3(0.299, 0.587, 0.114)) : maskSample.a;
    return vec4(acc * mask, mask);
}
