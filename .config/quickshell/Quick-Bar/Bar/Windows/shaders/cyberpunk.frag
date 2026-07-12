#version 440
// Cyberpunk Glitch - Bandes ondulées + Hologram (optimisé d'après référence)
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float intensity;
    float time;
    vec2 resolution;
    vec4 accent;
};

layout(binding = 1) uniform sampler2D source;

float hash(float n) { return fract(sin(n) * 43758.5453123); }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }

void main() {
    vec2 uv = qt_TexCoord0;
    float I = intensity;
    float t = time * 2.35;

    if (I < 0.001) {
        fragColor = texture(source, uv) * qt_Opacity;
        return;
    }

    vec3 col = texture(source, uv).rgb;

    // ── Bandes horizontales ondulées fortes ───────────────────────────
    float bands = 16.0;                    // nombre de bandes visible
    float band = floor(uv.y * bands);

    float wave = sin(uv.y * 28.0 + t * 15.0) * 0.022
               + sin(uv.y * 9.5 - t * 8.5) * 0.041
               + sin(uv.y * 4.0 + t * 3.0) * 0.012;

    float noiseShift = (hash(band + floor(t * 22.0)) - 0.5) * 0.28 * I;

    float shift = wave + noiseShift;
    shift += sin(band * 2.7 + t * 5.0) * 0.03 * I;
    shift += (hash(band * 3.0 + floor(t * 18.0)) - 0.5) * 0.05 * I;

    vec2 uvS = vec2(clamp(uv.x + shift, 0.0, 1.0), uv.y);

    // Aberration chromatique
    float ca = clamp(abs(shift) * 0.75 + 0.004, 0.004, 0.03);
    col.r = texture(source, uvS + vec2(ca * 1.75, 0.0)).r;
    col.g = texture(source, uvS).g;
    col.b = texture(source, uvS - vec2(ca * 1.45, 0.0)).b;

    // ── Glow / Bordures lumineuses des bandes (très important) ───────
    float edge = abs(fract(uv.y * bands) - 0.5);
    float glowAnim = 0.8 + 0.2 * sin(t * 8.0 + band);
    float lineGlow = exp(-edge * 45.0) * glowAnim;
    col += accent.rgb * lineGlow * I * 1.25;
    col += vec3(lineGlow * 0.75 * I);           // glow blanc

    // ── Freeze aléatoire ───────────────────────────────────────────────
    float freeze = step(0.91 - I * 0.65, hash(floor(t * 8.0) * 17.0));
    float isFreezing = freeze * step(fract(t * 7.8), 0.32 + I * 0.2);

    if (isFreezing > 0.5) {
    uvS.y = floor(uv.y * 13.0 + hash(band)) / 13.0;

    col.r = texture(source, uvS + vec2(ca * 1.75, 0.0)).r;
    col.g = texture(source, uvS).g;
    col.b = texture(source, uvS - vec2(ca * 1.45, 0.0)).b;

    col = col * 1.22 + vec3(0.08, 0.04, 0.18);
}

    // ── Scratches + Grain ──────────────────────────────────────────────
    float scratch = 0.0;
    for (float i = 0.0; i < 6.0; i++) {
        float s = hash(band + i * 11.0 + floor(t * 32.0));
        if (s > 0.905) {
            float d = abs(fract(uv.y * 62.0 + s * 45.0) - 0.5);
            scratch += 1.0 - smoothstep(0.0, 0.003, d);
        }
    }
    col += vec3(scratch * 2.5 * I);

    // Scanlines + Grain
    float scan = mix(
        1.0,
        0.65 + 0.35 * sin(uv.y * resolution.y * 6.0),
        I
    );
    col *= mix(1.0, scan, I * 0.8);
    col += (hash2(uv * resolution * 2.6 + t * 24.0) - 0.5) * 0.16 * I;

    // ── Éclairs / Orage (discret) ──────────────────────────────────────
    float lightning = 0.0;
    for (int i = 0; i < 3; i++) {
        float seed = hash(float(i) * 14.0 + floor(t * 12.0));
        if (seed > 0.93 - I * 0.45) {
            float y = hash(float(i) * 9.0);
            float d = abs(uv.y - y);
            lightning += smoothstep(0.007, 0.0, d) * 1.8;
            lightning += smoothstep(0.065, 0.0, d) * 0.9;
        }
    }
    col += lightning * I * 0.65;
    col += accent.rgb * lightning * I * 1.55;

    vec2 p = uv * 2.0 - 1.0;
    col = clamp(col * (1.0 + I * 0.2), 0.0, 1.15);
    float vignette = 1.0 - dot(p, p) * 0.25;
    col *= vignette;

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
