#version 440

// Cyberpunk — glitch façon intro « Cyberpunk logo glitch » (référence : template
// After Effects de theFoxDesign), appliqué au wallpaper.
//
// Ce qui fait le style, d'après la vidéo de référence :
//   · l'image garde ses couleurs : seuls les contours se colorent (split RVB, liserés)
//   · trame de lignes fines (2 px) sur les zones claires
//   · liserés rouge / cyan de quelques pixels sur les contours
//   · tranches décalées qui dédoublent un morceau de l'image
//   · traînées de pixels (une colonne étirée en lignes)
//   · petits tirets de « données » cyan dispersés
//   · flashs monochromes blanc-gris
//   · événements tirés sur les grosses frappes (2ᵉ référence « Fast glitch logo
//     intro ») : bloom chromatique (fantômes flous), éclair brisé qui traverse
//     l'écran ; étincelles qui filent
//   · ambiance permanente (3ᵉ référence, fond animé « cyberpunk Son Goku ») :
//     micro-éclairs fins et ramifiés qui crépitent, pluie fine en diagonale,
//     braises lumineuses qui flottent, scintillement des zones claires (écrans)
//   · le glitch ne surgit que par fenêtres courtes, toutes les quelques secondes
// Rythme du glitch : le motif est re-tiré ~12 fois/s ; chaque tirage est une frappe forte,
// faible ou nulle. `intensity` dose le tout. L'or est la couleur de l'effet
// (`accent`), le cyan sa teinte opposée.

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

const float GLITCH_FPS = 12.0;
const vec3  LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 hueShift(vec3 c, float a) {
    const vec3 k = vec3(0.57735);
    float ca = cos(a), sa = sin(a);
    return clamp(c * ca + cross(k, c) * sa + k * dot(k, c) * (1.0 - ca), 0.0, 1.0);
}
float h11(float p) { p = fract(p * 0.1031); p *= p + 33.33; p *= p + p; return fract(p); }
float h21(vec2 p) { vec3 q = fract(vec3(p.x, p.y, p.x) * 0.1031); q += dot(q, vec3(q.y, q.z, q.x) + 33.33); return fract((q.x + q.y) * q.z); }
// Saturation minimale en gardant la teinte (palette terne → vrai néon)
vec3 vivid(vec3 c, float minSat) {
    float mx = max(c.r, max(c.g, c.b)), mn = min(c.r, min(c.g, c.b));
    float sat = mx > 0.0 ? (mx - mn) / mx : 0.0;
    if (sat >= minSat || mx - mn < 1e-4) return c / max(mx, 0.001);
    vec3 n = (c - mn) / (mx - mn);                  // teinte pure (0..1)
    return mix(vec3(1.0), n, minSat);               // valeur 1, saturation minSat
}
// Éclair : tracé brisé le long de x (deux échelles de zigzag), avec trous.
// Renvoie (distance verticale en pixels au tracé, 1 si segment éteint).
// Le halo suit la distance même dans les trous : pas de coupure franche.
vec2 bolt(vec2 u, vec2 res, float y0, float seed, float x0, float x1) {
    if (u.x < x0 || u.x > x1) return vec2(1e4, 1.0);
    float n1 = 10.0, n2 = 55.0;
    float s1 = floor(u.x * n1), t1 = fract(u.x * n1);
    float s2 = floor(u.x * n2), t2 = fract(u.x * n2);
    float hA = fract(sin((s1 + seed) * 12.9898) * 43758.5453), hB = fract(sin((s1 + 1.0 + seed) * 12.9898) * 43758.5453);
    float gA = fract(sin((s2 + seed) * 78.233) * 43758.5453),  gB = fract(sin((s2 + 1.0 + seed) * 78.233) * 43758.5453);
    float y = y0 + (mix(hA, hB, t1) - 0.5) * 0.09 + (mix(gA, gB, t2) - 0.5) * 0.018;
    // trous : quelques segments fins éteints → tracé « déconstruit »
    float gap = step(fract(sin((s2 + seed * 3.0) * 4.1414) * 9631.7), 0.18);
    // fondu aux extrémités du tracé
    float ends = smoothstep(0.0, 0.04, u.x - x0) * smoothstep(0.0, 0.04, x1 - u.x);
    return vec2(abs(u.y - y) * res.y / max(ends, 0.05), gap);
}
// Micro-éclair d'orientation libre : p en pixels, o origine, d direction unitaire,
// L longueur (px). Renvoie (distance au tracé en px, 1 si segment éteint).
vec2 crack(vec2 p, vec2 o, vec2 d, float L, float seed) {
    vec2  q = p - o;
    float a = dot(q, d);                         // abscisse le long de l'éclair
    if (a < 0.0 || a > L) return vec2(1e4, 1.0);
    float t = a / L;
    float n1 = 7.0, n2 = 28.0;
    float s1 = floor(t * n1), f1 = fract(t * n1), s2 = floor(t * n2), f2 = fract(t * n2);
    float hA = fract(sin((s1 + seed) * 12.9898) * 43758.5453), hB = fract(sin((s1 + 1.0 + seed) * 12.9898) * 43758.5453);
    float gA = fract(sin((s2 + seed) * 78.233) * 43758.5453),  gB = fract(sin((s2 + 1.0 + seed) * 78.233) * 43758.5453);
    float off = ((mix(hA, hB, f1) - 0.5) * 0.35 + (mix(gA, gB, f2) - 0.5) * 0.08) * L;
    float perp = dot(q, vec2(-d.y, d.x)) - off;
    float taper = smoothstep(0.0, 0.08, t) * smoothstep(1.0, 0.75, t);   // pointe fine aux bouts
    float gap = step(fract(sin((s2 + seed * 3.0) * 4.1414) * 9631.7), 0.12);
    return vec2(abs(perp) / max(taper, 0.05), gap);
}
vec3 tex(vec2 uv) { return texture(source, clamp(uv, 0.001, 0.999)).rgb; }

void main() {
    vec2 u = qt_TexCoord0;
    float I = clamp(intensity, 0.0, 1.0);
    if (I <= 0.001) { fragColor = vec4(tex(u), 1.0) * qt_Opacity; return; }

    // palette terne (accent grisâtre) : saturation minimale, même teinte
    vec3 a    = vivid(accent.rgb, 0.85);
    vec3 GOLD = a;
    vec3 CYAN = hueShift(a, 3.14159);
    vec3 RED  = hueShift(a, -0.7);

    vec2  res = resolution;
    float tick = floor(time * GLITCH_FPS);
    // Fenêtres de glitch : ~40 % des tranches de 2,5 s, sur leurs 0,4 premières secondes
    float win  = floor(time / 2.5);
    bool  glitchOn = h11(win + 0.5) < 0.4 && fract(time / 2.5) < 0.16;
    float roll = h11(tick + 0.37);
    float hit  = !glitchOn ? 0.0 : (roll < 0.30 ? 1.0 : (roll < 0.65 ? 0.5 : (roll < 0.85 ? 0.2 : 0.0)));
    float s    = clamp(I * hit * 1.25, 0.0, 1.0);
    vec3  col;

    if (s <= 0.001) {
        col = tex(u);
    } else {
        vec2 su = u + (vec2(h11(tick + 1.3), h11(tick + 2.7)) - 0.5) * vec2(0.012, 0.004) * s;

        // ── Tranches décalées (dédoublent un morceau de l'image) ──
        float slabs = floor(mix(8.0, 24.0, h11(tick + 3.0)));
        float slab  = floor(u.y * slabs + h11(tick + 4.0) * 0.7);
        float hs    = h21(vec2(slab, tick));
        bool  inSlab = hs < 0.4 * s;
        if (inSlab) su.x += (h21(vec2(slab, tick + 91.0)) - 0.5) * 0.18 * s;

        // ── Traînée de pixels : une colonne étirée sur quelques lamelles ──
        float lam = floor(u.y * res.y / 3.0);
        float hl  = h21(vec2(lam, tick + 5.0));
        // courte, brisée en segments avec des trous (pas de longue ligne droite)
        if (hl < 0.03 * s) {
            float edge = h21(vec2(lam, tick + 58.0));
            float len  = mix(0.06, 0.25, h21(vec2(lam, tick + 60.0)));
            bool  right = h21(vec2(lam, tick + 59.0)) < 0.5;
            float dx = right ? u.x - edge : edge - u.x;
            float seg = floor(u.x * 70.0);
            if (dx > 0.0 && dx < len && h21(vec2(seg, lam + tick)) > 0.3) su.x = edge;
        }

        // ── Image d'origine + split RVB + liserés colorés de quelques pixels ──
        // (les couleurs de l'image restent les siennes : seuls les contours se colorent)
        vec2 fr = vec2((3.0 + 5.0 * h11(tick + 7.0)) * s, 0.0) / res;
        vec3 c  = tex(su);
        vec3 cr = tex(su + fr), cb = tex(su - fr);
        col = vec3(cr.r, c.g, cb.b);                         // split rouge / bleu
        float l0 = dot(c, LUMA);
        col += RED  * max(dot(cr, LUMA) - l0, 0.0) * 1.2 * s; // frange d'un côté
        col += CYAN * max(dot(cb, LUMA) - l0, 0.0) * 1.2 * s; // frange de l'autre

        // ── Trame de lignes fines sur les zones claires ──
        float bright = smoothstep(0.15, 0.6, dot(col, LUMA));
        float line = step(0.5, fract(u.y * res.y / 2.0));
        col *= 1.0 - 0.35 * bright * line * (0.4 + 0.6 * s);

        // ── Tirets de données : petits traits cyan sur des rangées de 1 à 2 px ──
        float drow = floor(u.y * res.y / 2.0);
        float hd = h21(vec2(drow, tick + 61.0));
        if (hd < 0.012 * (0.3 + s)) {
            float x0 = h21(vec2(drow, tick + 62.0)), x1 = x0 + mix(0.03, 0.25, h21(vec2(drow, tick + 63.0)));
            float dash = step(0.45, fract(u.x * res.x / mix(6.0, 14.0, h21(vec2(drow, tick + 64.0)))));
            if (u.x > x0 && u.x < x1) col = mix(col, h21(vec2(drow, tick + 65.0)) < 0.7 ? CYAN : GOLD, dash * 0.7);
        }

        // ── Flash monochrome blanc-gris (rare) ──
        if (hit > 0.9 && h11(tick + 50.0) < 0.05 * I) {
            float l = dot(tex(su), LUMA);
            col = vec3(l * 1.3) * (1.0 - 0.4 * line);
        }

        // ════ Événements des grosses frappes (un seul par tirage, ou aucun) ════
        float ev = h11(tick + 101.0);
        vec2  px1 = 1.0 / res;
        if (hit > 0.9) {
            if (ev < 0.28) {
                // ── Bloom chromatique : fantômes cyan / magenta / or, flous et lumineux ──
                vec2 o1 = vec2(10.0 + 14.0 * h11(tick + 102.0), -3.0) * px1;
                vec2 o2 = vec2(-6.0, 4.0 + 6.0 * h11(tick + 103.0)) * px1;
                vec3 blur = vec3(0.0);
                for (int k = -3; k <= 3; k++) blur += tex(su + vec2(float(k) * 5.0, 0.0) * px1);
                blur /= 7.0;
                vec3 ghosts = CYAN * dot(tex(su + o1), LUMA) + RED * dot(tex(su - o1), LUMA) + GOLD * dot(tex(su + o2), LUMA);
                col = col * 0.75 + (ghosts * 0.5 + blur * 0.3) * I * (1.0 - 0.6 * dot(col, LUMA));   // moins fort sur les zones déjà claires
            } else if (ev < 0.55) {
                // ── Éclair : tracé brisé qui traverse l'écran, image étirée autour ──
                float y0 = mix(0.2, 0.8, h11(tick + 104.0));
                float x0 = h11(tick + 109.0) * 0.25, x1 = 1.0 - h11(tick + 110.0) * 0.25;
                vec2  b1 = bolt(u, res, y0, tick, x0, x1);
                // ramification : un second tracé plus court qui part de l'éclair
                float bx = mix(x0, x1, h11(tick + 111.0));
                vec2  b2 = h11(tick + 112.0) < 0.6 ? bolt(u, res, y0 + (h11(tick + 113.0) - 0.5) * 0.15, tick + 50.0, bx, min(bx + 0.25, 1.0)) : vec2(1e4, 1.0);
                float near = abs(u.y - y0) * res.y;
                if (near < res.y * 0.1) {
                    vec3 sm = vec3(0.0);
                    for (int k = 0; k < 8; k++) sm += tex(su + vec2(float(k) * 0.01, 0.0));
                    col = mix(col, sm / 8.0 * 1.2, 0.5 * smoothstep(res.y * 0.1, 0.0, near));
                }
                // éclat irrégulier le long du tracé (lissé, sans bandes verticales)
                float fx = u.x * 30.0, ff = fract(fx);
                float flick = 0.7 + 0.6 * mix(h21(vec2(floor(fx), tick)), h21(vec2(floor(fx) + 1.0, tick)), ff * ff * (3.0 - 2.0 * ff));
                vec3  lc = mix(GOLD, vec3(1.0), 0.5);
                // trait central éteint dans les trous, halo continu
                col += lc * (exp(-b1.x / 1.6) * 1.5 * (1.0 - b1.y) + exp(-b1.x / 22.0) * 0.4) * flick * I;
                col += mix(CYAN, vec3(1.0), 0.3) * (exp(-b2.x / 1.3) * 1.1 * (1.0 - b2.y) + exp(-b2.x / 14.0) * 0.25) * flick * I;
            }
        }

        col *= 1.0 + (h11(tick + 29.0) - 0.5) * 0.25 * s;
    }

    // ════ Ambiance permanente ════
    vec2  pp  = u * res;
    float sc  = res.y / 1440.0;                        // tailles prévues pour un écran 1440p
    vec3  zap = mix(vec3(1.0), CYAN, 0.25);            // blanc bleuté des éclairs

    // ── Scintillement des zones claires (écrans, néons) ──
    float lumC = dot(col, LUMA);
    vec2  zone = floor(u * vec2(9.0, 6.0));
    float fl   = h21(zone + floor(time * 9.0));
    col *= 1.0 + smoothstep(0.45, 0.85, lumC) * ((fl - 0.5) * 0.16 - step(0.96, fl) * 0.25) * I;

    // ── Pluie fine en diagonale ──
    vec2  rd  = normalize(vec2(0.35, 1.0));            // direction de chute (vers le bas, un peu à droite)
    vec2  rp  = vec2(dot(pp, vec2(rd.y, -rd.x)), dot(pp, rd)) / sc;
    float colR = floor(rp.x / 7.0);
    float hr  = h11(colR * 1.37);
    if (hr < 0.28) {
        float speed = mix(700.0, 1300.0, h11(colR + 3.1));
        float yR = rp.y - time * speed - hr * 4000.0;
        float cell = 260.0, f = fract(yR / cell);
        float drop = smoothstep(0.0, 0.05, f) * smoothstep(0.32, 0.0, f);      // traînée qui s'estompe
        float thin = smoothstep(1.2, 0.0, abs(fract(rp.x / 7.0) - 0.5) * 7.0);
        float dots = 0.6 + 0.4 * step(0.5, fract(yR / 9.0));                  // aspect pointillé
        col += mix(CYAN, vec3(1.0), 0.5) * drop * thin * dots * 0.22 * I;
    }

    // ── Braises : petits points lumineux qui montent en flottant ──
    for (int k = 0; k < 14; k++) {
        float fk = float(k);
        float life = 6.0 + 6.0 * h11(fk * 3.7);
        float ph = fract(time / life + h11(fk * 9.1));
        vec2  ep = vec2(h11(fk * 5.3) + sin(time * 0.7 + fk) * 0.02, 1.05 - ph * 1.15) * res;
        float r  = mix(1.5, 4.0, h11(fk * 2.9)) * sc;
        float dE = length(pp - ep);
        float tw = 0.6 + 0.4 * sin(time * 6.0 + fk * 2.0);
        float fade = smoothstep(0.0, 0.15, ph) * smoothstep(1.0, 0.7, ph);
        vec3  ec = h11(fk * 7.7) < 0.7 ? RED : GOLD;
        col += ec * (smoothstep(r, 0.0, dE) * 0.9 + exp(-dE / (r * 3.0)) * 0.35) * tw * fade * I;
    }

    // ── Micro-éclairs qui crépitent (1 à 3 à la fois, ~0,1 s chacun) ──
    float zt = floor(time * 8.0);
    for (int k = 0; k < 3; k++) {
        float fk = float(k), sd = zt * 3.0 + fk * 17.0;
        if (h11(sd + 0.3) > 0.45) continue;
        vec2  o   = vec2(h11(sd + 1.1), h11(sd + 2.2)) * res;
        float ang = h11(sd + 3.3) * 6.28318;
        vec2  dir = vec2(cos(ang), sin(ang));
        float L   = mix(0.06, 0.2, h11(sd + 4.4)) * res.y;
        vec2  c1  = crack(pp, o, dir, L, sd);
        // ramification qui part du milieu de l'éclair
        float ba  = ang + (h11(sd + 5.5) < 0.5 ? 0.7 : -0.7);
        vec2  c2  = crack(pp, o + dir * L * mix(0.3, 0.6, h11(sd + 6.6)), vec2(cos(ba), sin(ba)), L * 0.45, sd + 9.0);
        float w   = 1.1 * sc;
        col += zap * (exp(-c1.x / w) * 1.3 * (1.0 - c1.y) + exp(-c1.x / (12.0 * sc)) * 0.18) * I;
        col += zap * (exp(-c2.x / w) * 0.9 * (1.0 - c2.y) + exp(-c2.x / (9.0 * sc)) * 0.10) * I;
    }

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0) * qt_Opacity;
}
