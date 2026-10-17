#version 440

// Braindance — l'écran « BD » de Cyberpunk 2077 : image virée dans une seule
// teinte, ondulation VHS, lignes qui sautent, barre qui défile, vignettage.
//
// Porté du shader kitty « cyberpunk-braindance » (pack kitty-cyberpunk-glitch).
// `intensity` dose l'effet ; la teinte du virage est la couleur de l'effet
// (`accent`), les reflets prennent sa teinte opposée.

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

const float WOBBLE     = 1.0;    // ondulation VHS
const float TINT       = 1.0;    // 0 = couleurs d'origine, 1 = virage complet
const float SCANLINES  = 0.5;
const float ROLL_SPEED = 0.35;   // barre qui défile, écrans par seconde
const vec3  LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 hueShift(vec3 c, float a) {
    const vec3 k = vec3(0.57735);
    float ca = cos(a), sa = sin(a);
    return clamp(c * ca + cross(k, c) * sa + k * dot(k, c) * (1.0 - ca), 0.0, 1.0);
}
float h21(vec2 p) { vec3 q = fract(vec3(p.x, p.y, p.x) * 0.1031); q += dot(q, vec3(q.y, q.z, q.x) + 33.33); return fract((q.x + q.y) * q.z); }
vec3 tex(vec2 uv) { return texture(source, clamp(uv, 0.0, 1.0)).rgb; }

void main() {
    vec2 u = qt_TexCoord0;
    float s = clamp(intensity, 0.0, 1.0);
    if (s <= 0.001) { fragColor = vec4(tex(u), 1.0) * qt_Opacity; return; }

    vec3 a = accent.rgb / max(max(accent.r, max(accent.g, accent.b)), 0.001);
    vec3 BD        = a;                          // teinte du virage
    vec3 HIGHLIGHT = hueShift(a, 3.14159);       // reflets dans les hautes lumières
    vec3 BAR       = mix(a, vec3(1.0), 0.2);
    vec3 NOISE     = mix(a, vec3(1.0), 0.35);

    vec2 res = resolution;
    float aspect = res.x / max(res.y, 1.0);
    float tick = floor(time * 20.0);

    vec2 su = u;
    su.x += (sin(u.y * 38.0 + time * 22.0) * 0.006 + sin(u.y * 7.0 - time * 5.0) * 0.004) * s * WOBBLE;
    float line = floor(u.y * res.y / 3.0);
    if (h21(vec2(line, tick)) < 0.05 * s) su.x += (h21(vec2(line, tick + 1.0)) - 0.5) * 0.1 * s;

    float spl = 0.006 * s;
    vec3 base = vec3(tex(su + vec2(spl, 0.0)).r, tex(su - vec2(spl, 0.0)).gb);
    float l = dot(base, LUMA);
    vec3 bd = BD * (0.02 + l * 1.6) + HIGHLIGHT * pow(l, 3.0) * 0.4;
    vec3 col = mix(base, bd, clamp(s * 1.4, 0.0, 1.0) * TINT);

    // barre qui défile de haut en bas
    float roll = fract(time * ROLL_SPEED);
    col += BAR * smoothstep(0.06, 0.0, abs(u.y - roll)) * 0.25 * s;

    if (h21(vec2(line, tick + 9.0)) < 0.03 * s) {
        float nz = h21(floor(u * res / vec2(2.0, 1.0)) + tick * 7.0);
        col = mix(col, vec3(nz) * NOISE, 0.7);
    }

    col *= 1.0 - SCANLINES * s * (0.5 + 0.5 * sin(u.y * res.y * 3.14159265));
    col *= 1.0 - 0.25 * s * smoothstep(0.3, 0.9, length((u - 0.5) * vec2(aspect, 1.0)) * 0.8);
    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0) * qt_Opacity;
}
