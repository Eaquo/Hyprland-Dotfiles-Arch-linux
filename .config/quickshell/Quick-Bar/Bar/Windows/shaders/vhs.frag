#version 440

// VHS rétro : ondulation horizontale, barre de tracking qui roule, chroma shift,
// bruit analogique, désaturation, scanlines. Coût nul quand intensity == 0.

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

float hash(float n) { return fract(sin(n) * 43758.5453123); }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }

void main() {
    vec2 uv = qt_TexCoord0;
    float I = intensity;
    if (I < 0.001) { fragColor = texture(source, uv) * qt_Opacity; return; }
    float t = time;

    // Ondulation horizontale
    float wave = sin(uv.y * 60.0 + t * 8.0) * 0.003 * I
               + sin(uv.y * 13.0 - t * 3.0) * 0.006 * I;

    // Barre de tracking qui roule vers le haut
    float bar      = fract(uv.y - t * 0.4);
    float trackBar = smoothstep(0.0, 0.03, bar) * (1.0 - smoothstep(0.05, 0.10, bar));
    float jump     = trackBar * (hash(floor(t * 30.0)) - 0.5) * 0.10 * I;

    vec2 uvv = vec2(uv.x + wave + jump, uv.y);

    // Chroma shift horizontal (fort sur la barre)
    float ca = 0.006 * I + trackBar * 0.02 * I;
    vec3 col = vec3(
        texture(source, uvv + vec2(ca, 0.0)).r,
        texture(source, uvv).g,
        texture(source, uvv - vec2(ca, 0.0)).b
    );

    // Bruit analogique (renforcé sur la barre)
    col += (hash2(uv * resolution + t) - 0.5) * (0.05 + trackBar * 0.30) * I;

    // Désaturation + teinte accent sur la barre
    float g = dot(col, vec3(0.33));
    col = mix(col, vec3(g), 0.22 * I);
    col += accent.rgb * trackBar * 0.15 * I;

    // Scanlines
    col *= mix(1.0, 0.9 + 0.1 * sin(uv.y * resolution.y * 1.2), I * 0.5);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
