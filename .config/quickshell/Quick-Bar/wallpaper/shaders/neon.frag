#version 440

// Néon — la transition de Cyberpunk 2077 : des barres néon balaient l'écran
// de gauche à droite et de droite à gauche, avec déchirures et split.
//
// Porté du shader kitty « cyberpunk-transition » (pack kitty-cyberpunk-glitch).
// Dans kitty c'est une transition unique (progression 0 → 1) ; ici les vagues
// de barres se répètent tant que l'effet est actif, et `intensity` les dose.
// Couleurs : l'accent, sa teinte opposée, une teinte voisine et le noir.

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

const float WAVE_PERIOD  = 1.6;   // secondes par vague de barres
const float BAR_ROWS     = 9.0;   // rangées de barres épaisses
const float BAR_LENGTH   = 0.24;  // longueur d'une barre (en unités de progression)
const float THIN_BARS    = 0.45;  // part des rangées découpées en 4 barres fines
const float INVERT_FLASH = 0.05;

vec3 hueShift(vec3 c, float a) {
    const vec3 k = vec3(0.57735);
    float ca = cos(a), sa = sin(a);
    return clamp(c * ca + cross(k, c) * sa + k * dot(k, c) * (1.0 - ca), 0.0, 1.0);
}
float h11(float p) { p = fract(p * 0.1031); p *= p + 33.33; p *= p + p; return fract(p); }
float h21(vec2 p) { vec3 q = fract(vec3(p.x, p.y, p.x) * 0.1031); q += dot(q, vec3(q.y, q.z, q.x) + 33.33); return fract((q.x + q.y) * q.z); }
vec3 tex(vec2 uv) { return texture(source, clamp(uv, 0.0, 1.0)).rgb; }

void main() {
    vec2 u = qt_TexCoord0;
    float I = clamp(intensity, 0.0, 1.0);
    if (I <= 0.001) { fragColor = vec4(tex(u), 1.0) * qt_Opacity; return; }

    vec3 a = accent.rgb / max(max(accent.r, max(accent.g, accent.b)), 0.001);
    vec3 NEON  = mix(a, vec3(1.0), 0.15);
    vec3 CYAN  = hueShift(a, 3.14159);
    vec3 RED   = hueShift(a, -0.9);
    vec3 BLACK = vec3(0.004, 0.003, 0.007);

    // progression de la vague en cours ; chaque vague a son propre tirage
    float wave = floor(time / WAVE_PERIOD);
    float p = fract(time / WAVE_PERIOD);
    float env = sin(p * 3.14159265) * I;
    float tick = floor(time * 18.0);
    vec2 res = resolution;

    // déchirures + split sur le wallpaper
    vec2 su = u;
    float nsl = floor(mix(30.0, 70.0, h11(tick + 17.0)));
    float sv = floor(u.y * nsl);
    if (h21(vec2(sv, tick + 5.0)) < 0.35 * env) su.x += (h21(vec2(sv, tick + 43.0)) - 0.5) * 0.12 * env;
    float spl = 0.015 * env;
    vec3 col = vec3(tex(su + vec2(spl, 0.0)).r, tex(su - vec2(spl, 0.0)).gb);

    // rangées de barres, certaines découpées en barres fines
    float b = floor(u.y * BAR_ROWS);
    float sub = 0.0;
    float rows = BAR_ROWS;
    if (h11(b + 0.5 + wave * 13.0) > 1.0 - THIN_BARS) {
        rows = BAR_ROWS * 4.0;
        b = 100.0 + floor(u.y * rows);
        sub = 1.0;
    }
    b += wave * 37.0;
    float hb = h11(b * 7.31 + 3.0);
    float x = (hb < 0.5 ? u.x : 1.0 - u.x) + (h21(vec2(b, tick)) - 0.5) * 0.05;
    float delay = h11(b * 3.1 + 1.0) * 0.35;
    float head = (p - delay) * 2.7;
    float tail = (p - delay - BAR_LENGTH + sub * 0.08) * 2.7;

    vec3 glow = vec3(0.0);
    if (x < head && x > tail) {
        float pk = h11(b * 5.7 + 9.0);
        vec3 bc = pk < 0.45 ? NEON : (pk < 0.65 ? CYAN : (pk < 0.8 ? RED : BLACK));
        bc *= 1.0 - step(0.82, fract(u.y * rows * 5.0)) * 0.35;                       // rayures internes
        if (h21(floor(u * res / vec2(16.0, 7.0)) + tick) > 0.88) bc = mix(bc, BLACK, 0.85); // trous de pixels
        bc = mix(bc, vec3(1.0), smoothstep(0.04, 0.0, head - x) * 0.6);             // bord avant brûlant
        bc = mix(bc, hb < 0.5 ? CYAN : RED, smoothstep(0.03, 0.0, x - tail) * 0.7);
        // intensité faible : les barres se fondent dans le wallpaper au lieu de le masquer
        col = mix(col, bc, clamp(I * 1.4, 0.0, 1.0));
    } else {
        col += (hb < 0.5 ? RED : CYAN) * smoothstep(0.07, 0.0, abs(x - head)) * 0.7 * env;
    }

    if (h11(tick + 50.0) < INVERT_FLASH * env) col = mix(col, 1.0 - col, 0.9);
    col *= 1.0 - 0.2 * env * (0.5 + 0.5 * sin(u.y * res.y * 3.14159265));
    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0) * qt_Opacity;
}
