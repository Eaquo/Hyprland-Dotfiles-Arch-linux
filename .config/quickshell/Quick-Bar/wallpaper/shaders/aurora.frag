#version 440

// Aurora — aurores boréales vues du sol, ciel étoilé (« Northern Lights »).
//
// Porté depuis le shader du terminal kitty (kitty/shaders/custom/northern-lights.slang,
// Kovid Goyal, GPLv3) : même projection zénithale, même bruit triangulaire et même
// marche de rayons volumétrique. Retirés : la traînée de souris et sa texture
// persistante (sans objet sur un fond d'écran), le tirage aléatoire par époque.
// Ici le ciel est le wallpaper assombri et les trois teintes du rideau
// (bas → milieu → haut) dérivent de la couleur de l'effet (`accent`).

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

const float AURORA_INTENSITY = 0.2;
const float AURORA_ALTITUDE  = 0.6;
const float WAVE_SPEED       = 0.55;
const int   MARCH_STEPS      = 50;
const float CURTAIN_SHARPNESS = 39.0;
const float CURTAIN_SOFTNESS  = 1.3;
const float CAMERA_DISTANCE   = 9.7;
const float PERSPECTIVE_TILT  = 0.12;
const float STAR_BRIGHTNESS   = 0.7;
const float STAR_SIZE         = 1.6;
const float STAR_DENSITY      = 6.0;
const mat2  TRI_ROT = mat2(0.95534, 0.29552, -0.29552, 0.95534);

// ── Bruit en onde triangulaire (les plis du rideau) ─────────────────────────
float triWave(float x) { return clamp(abs(fract(x) - 0.5), 0.01, 0.49); }
vec2  triWave2(vec2 p) { return vec2(triWave(p.x) + triWave(p.y), triWave(p.y + triWave(p.x))); }

float triNoise2d(vec2 p, float spd, float ts, float sharpness) {
    float z = 1.8, z2 = 2.5, rz = 0.0;
    float c = cos(p.x * 0.06), s = sin(p.x * 0.06);
    p = p * mat2(c, s, -s, c);
    vec2 bp = p;
    float tc = cos(ts * spd), tn = sin(ts * spd);
    mat2 tr = mat2(tc, tn, -tn, tc);
    for (int i = 0; i < 5; i++) {
        vec2 dg = (triWave2(bp * 1.85) * 0.75) * tr;
        p -= dg / z2;
        bp *= 1.3; z2 *= 0.45; z *= 0.42;
        p *= 1.21 + (rz - 1.0) * 0.02;
        rz += triWave(p.x + triWave(p.y)) * z;
        p = (p * TRI_ROT) * -1.0;
    }
    return clamp(1.0 / pow(rz * sharpness, CURTAIN_SOFTNESS), 0.0, 0.55);
}

float hash21(vec2 n) { return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453); }

// Hash flottant (Dave Hoskins) : le hash PCG entier de l'original ne passe pas
// dans les variantes GLSL sans `uint` que génère qsb.
vec3 hash33(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.xxy + p.yxx) * p.zyx);
}

// ── Étoiles (4 couches de densité croissante, scintillement) ────────────────
vec3 sampleStars(vec3 rd, float resX, float t) {
    const float density[4] = float[4](0.0005, 0.0015, 0.0045, 0.0125);
    vec3 c = vec3(0.0);
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        vec3 srd = rd * ((0.15 + fi * 0.02) * resX) + vec3(fi * 0.371, fi * 0.519, fi * 0.163);
        vec3 q  = fract(srd) - 0.5;
        vec3 rn = hash33(floor(srd));
        if (rn.x >= density[i] * STAR_DENSITY) continue;
        float c2 = 1.0 - smoothstep(0.0, STAR_SIZE, length(q));
        float tw = 0.7 + 0.3 * sin(t * (2.0 + rn.z * 5.0) + rn.y * 6.2831853);
        float flux = pow(10.0, -0.4 * rn.y * 6.0);
        c += c2 * mix(vec3(1.0, 0.49, 0.1), vec3(0.75, 0.9, 1.0), rn.z) * flux * tw;
    }
    return c * c * STAR_BRIGHTNESS;
}

// Projection zénithale : on regarde le ciel d'en dessous
vec3 zenithRayDir(vec2 cuv, float aspect, float spinC, float spinS) {
    vec2 suv = cuv * vec2(aspect, 1.0) * 1.5;
    vec3 rd = normalize(vec3(suv.x, 1.0 / sqrt(1.0 + dot(suv, suv)), suv.y));
    float ct = cos(PERSPECTIVE_TILT), st = sin(PERSPECTIVE_TILT);
    rd.yz = vec2(rd.y * ct - rd.z * st, rd.y * st + rd.z * ct);
    rd.xz = rd.xz * mat2(spinC, spinS, -spinS, spinC);
    return rd;
}

vec4 rayMarchAurora(vec3 ro, vec3 rd, vec2 fragCoord, float t, vec3 cLow, vec3 cMid, vec3 cHigh) {
    vec3 acc = vec3(0.0);
    float accA = 0.0;
    float dither = 0.006 * hash21(fragCoord);
    for (int i = 0; i < MARCH_STEPS; i++) {
        float fi = float(i);
        float pt = ((AURORA_ALTITUDE + pow(fi, 1.4) * 0.002) - ro.y) / (rd.y * 2.0 + 0.4);
        pt -= dither * smoothstep(0.0, 15.0, fi);
        if (pt < 0.0) continue;
        vec3 bpos = ro + pt * rd;
        float density = triNoise2d(bpos.zx, WAVE_SPEED, t, CURTAIN_SHARPNESS);
        float h = fi / float(MARCH_STEPS);
        vec3 col = mix(mix(cLow, cMid, smoothstep(0.0, 0.45, h)), cHigh, smoothstep(0.35, 1.0, h));
        col = max(col + sin(vec3(0.0, 1.0, 2.0) + h * 6.0) * 0.06, 0.0);
        acc  += col * density * exp(-accA * 2.0);
        accA += density * 0.05;
    }
    return vec4(acc * AURORA_INTENSITY, clamp(accA, 0.0, 1.0));
}

void main() {
    vec2 UV = qt_TexCoord0;
    float I = intensity;
    vec3 base = texture(source, UV).rgb;
    if (I < 0.001) { fragColor = vec4(base, 1.0) * qt_Opacity; return; }

    float aspect = resolution.x / max(resolution.y, 1.0);
    float t = time;

    vec3 a = accent.rgb / max(max(accent.r, max(accent.g, accent.b)), 0.001);
    vec3 cLow = a, cMid = hueShift(a, 0.8), cHigh = hueShift(a, 2.2);

    float spin = t * 0.02;
    vec3 ro = vec3(0.0, 0.0, -CAMERA_DISTANCE);
    vec3 rd = zenithRayDir(vec2(UV.x, 1.0 - UV.y) - 0.5, aspect, cos(spin), sin(spin));

    vec4 aur = smoothstep(0.0, 1.5, rayMarchAurora(ro, rd, UV * resolution, t, cLow, cMid, cHigh));
    vec3 fx = sampleStars(rd, resolution.x, t) * (1.0 - aur.a) + aur.rgb * 1.9;

    // Le wallpaper devient un ciel de nuit ; l'aurore et les étoiles s'y ajoutent
    float k = clamp(I * 2.5, 0.0, 1.0);
    float lum = dot(base, vec3(0.299, 0.587, 0.114));
    vec3 night = mix(base, vec3(lum) * vec3(0.55, 0.65, 1.0), 0.45) * 0.30;
    vec3 col = mix(base, night, k) + fx * k;

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
