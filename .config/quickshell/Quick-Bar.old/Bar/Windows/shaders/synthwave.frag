#version 440

// Synthwave néon : aberration chromatique pulsée, teinte magenta↔cyan, bloom des
// zones claires, balayage horizontal néon. Vibe retrowave.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float intensity;
    float time;
    vec2  resolution;
    vec4  accent;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;
    float I = intensity;
    if (I < 0.001) { fragColor = texture(source, uv) * qt_Opacity; return; }
    float t = time;

    // Aberration chromatique pulsée
    float ca = 0.012 * I * (0.6 + 0.4 * sin(t * 20.0));
    vec3 col = vec3(
        texture(source, uv + vec2(ca, 0.0)).r,
        texture(source, uv).g,
        texture(source, uv - vec2(ca, 0.0)).b
    );

    // Néon dérivé de l'accent wallust (pulse entre accent et une variante plus claire)
    vec3 neonA = accent.rgb;
    vec3 neonB = clamp(accent.rgb * 1.6 + 0.15, 0.0, 1.0);
    vec3 neon  = mix(neonA, neonB, 0.5 + 0.5 * sin(uv.y * 3.0 + t * 4.0));

    // Bloom simple : booste les zones claires en néon
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    col += neon * smoothstep(0.6, 1.0, lum) * 0.5 * I;
    col = mix(col, col * neon * 1.3, I * 0.35);

    // Balayage horizontal néon
    float sweep = smoothstep(0.0, 0.15, abs(fract(uv.x - t * 0.5) - 0.5));
    col += neon * (1.0 - sweep) * 0.10 * I;

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
