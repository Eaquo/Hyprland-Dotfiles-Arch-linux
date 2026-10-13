#version 440

// Underwater — le wallpaper vu sous l'eau : caustiques qui le déforment et
// rayons de lumière qui tombent de la surface.
//
// Fusion de deux shaders du terminal kitty (kitty/shaders/custom/, Kovid Goyal,
// GPLv3) : water.slang (caustiques) et underwater.slang (rayons, adapté de
// https://www.shadertoy.com/view/lljGDt). La teinte de l'eau et de la lumière
// dérive de la couleur de l'effet (`accent`).

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

// Tourne la teinte d'une couleur (rotation autour de l'axe gris)
vec3 hueShift(vec3 c, float a) {
    const vec3 k = vec3(0.57735);
    float ca = cos(a), sa = sin(a);
    return clamp(c * ca + cross(k, c) * sa + k * dot(k, c) * (1.0 - ca), 0.0, 1.0);
}

const float TAU = 6.28318530718;
const int   MAX_ITER = 6;
const float CAUSTIC_INTEN   = 0.005;
const float UV_DISPLACEMENT = 0.04;

float hash21(vec2 p) {
    p = fract(p * vec2(233.34, 851.73));
    p += dot(p, p + 23.45);
    return fract(p.x * p.y);
}

float rayStrength(vec2 src, vec2 refDir, vec2 coord, float seedA, float seedB, float speed, float t, float resX) {
    vec2  d = coord - src;
    float cosA = dot(normalize(d), refDir);
    float dither = hash21(coord) * 0.015 - 0.0075;
    float ray = clamp((0.45 + 0.15 * sin(cosA * seedA + t * speed))
                    + (0.30 + 0.20 * cos(-cosA * seedB + t * speed)) + dither, 0.0, 1.0);
    return ray * mix(0.5, 1.0, smoothstep(0.0, resX, resX - length(d)));
}

void main() {
    vec2 UV = qt_TexCoord0;
    float I = intensity;
    vec3 base = texture(source, UV).rgb;
    if (I < 0.001) { fragColor = vec4(base, 1.0) * qt_Opacity; return; }

    float k = clamp(I * 2.5, 0.0, 1.0);
    float aspect = resolution.x / max(resolution.y, 1.0);
    vec3  a = accent.rgb / max(max(accent.r, max(accent.g, accent.b)), 0.001);

    // ── Caustiques ────────────────────────────────────────────────────────
    float wt = time * 0.5 + 23.0;
    vec2 p = mod(UV * vec2(aspect, 1.0) * TAU, TAU) - 250.0;
    vec2 i = p;
    float c = 1.0;
    for (int n = 0; n < MAX_ITER; n++) {
        float tv = wt * (1.0 - (3.5 / float(n + 1)));
        i = p + vec2(cos(tv - i.x) + sin(tv + i.y), sin(tv - i.y) + cos(tv + i.x));
        c += 1.0 / length(vec2(p.x / (sin(i.x + tv) / CAUSTIC_INTEN), p.y / (cos(i.y + tv) / CAUSTIC_INTEN)));
    }
    c = 1.17 - pow(c / float(MAX_ITER), 1.4);
    float caustic = pow(abs(c), 15.0);

    // Le wallpaper ondule avec les caustiques
    vec2 tc = vec2(cos(c) - 0.75, sin(c) - 0.75) * UV_DISPLACEMENT * k;
    vec3 wall = texture(source, clamp(UV + tc, 0.0, 1.0)).rgb;

    // ── Rayons de surface (origine en haut à droite, hors écran) ──────────
    vec2 coord = vec2(UV.x, 1.0 - UV.y) * resolution;      // y vers le haut, comme l'original
    float r1 = rayStrength(resolution * vec2(0.7, 1.1), normalize(vec2(1.0,  0.116)), coord, 36.2214, 21.11349, 1.1, time, resolution.x);
    float r2 = rayStrength(resolution * vec2(0.8, 1.2), normalize(vec2(1.0, -0.241)), coord, 22.39910, 18.0234, 0.9, time, resolution.x);
    float rays = r1 * 0.5 + r2 * 0.4;
    float depth = 1.0 - UV.y;                               // 1 = surface, 0 = fond

    // ── Composition : eau teintée, plus sombre en profondeur ──────────────
    vec3 water = mix(vec3(0.20, 0.45, 0.60), a, 0.55);
    vec3 col = wall * mix(vec3(1.0), water * (0.45 + 0.75 * depth), k * 0.85);
    col += water * caustic * 0.55 * k;
    col += mix(vec3(1.0), a, 0.45) * rays * (0.10 + 0.55 * depth) * 0.55 * k;

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
