#version 440

// Fireworks — feux d'artifice au-dessus du wallpaper assombri.
//
// Porté depuis le shader du terminal kitty (kitty/shaders/custom/fireworks.slang,
// Kovid Goyal, GPLv3), lui-même porté de Shadertoy :
//   "Fireworks" par Martijn Steinrucken (BigWings), 2015
//   https://www.shadertoy.com/view/lscGRl — CC BY-NC-SA 3.0
// Ici : cinq bouquets répartis sur la largeur de l'écran, et chaque bouquet prend
// une teinte tournée autour de la couleur de l'effet (`accent`).

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

const int   NUM_EXPLOSIONS = 5;
const int   NUM_PARTICLES  = 42;
const float TIME_SCALE     = 0.5;
const vec3  MOD3 = vec3(0.1031, 0.11369, 0.13787);

vec3 hash31(float p) {
    vec3 p3 = fract(vec3(p) * MOD3);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract(vec3((p3.x + p3.y) * p3.z, (p3.x + p3.z) * p3.y, (p3.y + p3.z) * p3.x));
}

float light(vec2 uv, vec2 pos, float size) {
    uv -= pos;
    return size * size / dot(uv, uv);
}

vec3 explosion(vec2 uv, vec2 p, float seed, float t, vec3 baseCol) {
    vec3 col = vec3(0.0);
    vec3 en = hash31(seed);
    vec2  startP = p - vec2(0.0, t * t * 0.1);
    float pt = 1.0 - pow(t - 1.0, 2.0);
    float b  = smoothstep(en.x - en.z, en.x + en.z, t) * smoothstep(en.y + en.z, en.y - en.z, t);
    float sizeBase = mix(0.01, 0.005, smoothstep(0.0, 0.1, pt)) * smoothstep(1.0, 0.1, pt);
    for (int i = 0; i < NUM_PARTICLES; i++) {
        vec3 n = hash31(float(i)) - 0.5;
        vec2 endP = startP + normalize(n.xy) * n.z - vec2(0.0, t * 0.2);
        vec2 pos  = mix(p, endP, pt);
        float sparkle = sin((pt + n.z) * 21.0) * 0.5 + 0.5;
        sparkle = pow(sparkle, pow(en.x, 3.0) * 50.0) * 0.01;
        col += baseCol * light(uv, pos, sizeBase + sparkle * b);
    }
    return col;
}

void main() {
    vec2 UV = qt_TexCoord0;
    float I = intensity;
    vec3 base = texture(source, UV).rgb;
    if (I < 0.001) { fragColor = vec4(base, 1.0) * qt_Opacity; return; }

    float aspect = resolution.x / max(resolution.y, 1.0);
    float t = mod(time, 3600.0) * TIME_SCALE;
    vec2 uv = vec2((UV.x - 0.5) * aspect, UV.y);           // y = 0 en haut : la gravité tire vers le bas
    vec3 a = accent.rgb / max(max(accent.r, max(accent.g, accent.b)), 0.001);

    vec3 c = vec3(0.0);
    for (int i = 0; i < NUM_EXPLOSIONS; i++) {
        float et = t + float(i) * 1234.45235;
        float id = floor(et);
        et -= id;
        vec3 h = hash31(id);
        vec2 p = vec2((h.x - 0.5) * aspect * 0.85, h.y * 0.75 + 0.05);
        c += explosion(uv, p, id, et, hueShift(a, (h.z - 0.5) * 3.2) + 0.08);
    }
    c = 1.0 - exp(-c * 1.4);                               // les cœurs saturent en blanc sans brûler

    float k = clamp(I * 2.5, 0.0, 1.0);
    vec3 col = base * mix(1.0, 0.32, k) + c * k;
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
