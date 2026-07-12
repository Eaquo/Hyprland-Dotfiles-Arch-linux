#version 440

// Hologramme : teinte cyan/accent, interlace scanlines qui flickerent, RGB split,
// bande de scan lumineuse qui descend, léger jitter vertical.

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

void main() {
    vec2 uv = qt_TexCoord0;
    float I = intensity;
    if (I < 0.001) { fragColor = texture(source, uv) * qt_Opacity; return; }
    float t = time;

    // Jitter vertical
    float jitter = (hash(floor(t * 24.0)) - 0.5) * 0.004 * I;
    vec2 uvh = vec2(uv.x, uv.y + jitter);

    // RGB split
    float ca = 0.004 * I;
    vec3 col = vec3(
        texture(source, uvh + vec2(ca, 0.0)).r,
        texture(source, uvh).g,
        texture(source, uvh - vec2(ca, 0.0)).b
    );

    // Teinte hologramme = accent wallust (color11)
    vec3 holo = accent.rgb;
    col = mix(col, col * holo * 1.4, I * 0.55);

    // Interlace + flicker
    float line  = mod(floor(uv.y * resolution.y * 0.5), 2.0);
    float flick = 0.85 + 0.15 * sin(t * 40.0);
    col *= mix(1.0, mix(0.55, 1.0, line) * flick, I);

    // Bande de scan lumineuse qui descend
    float sweep = smoothstep(0.0, 0.04, abs(fract(uv.y - t * 0.3) - 0.5));
    col += holo * (1.0 - sweep) * 0.18 * I;

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
