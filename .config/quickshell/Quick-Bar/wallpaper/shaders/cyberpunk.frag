#version 440

// Cyberpunk — vol en 3D dans une ville néon sous la pluie (shader original Quick-Bar).
//
// Même principe que le thème Matrix : un lancer de rayon dans une grille (DDA),
// où chaque case est un gratte-ciel de hauteur aléatoire, séparés par des
// avenues. La caméra avance le long d'une avenue entre les tours.
//   · façades : fenêtres allumées au hasard, bandeaux et enseignes néon qui grésillent
//   · sol mouillé : second lancer de rayon → reflets de la ville
//   · brume colorée + halos des néons accumulés le long du rayon
//   · trafic volant (points lumineux), pluie fine
// Le wallpaper flouté sert de ciel. Les néons dérivent de la couleur de l'effet
// (`accent`) : elle-même + deux teintes décalées. `intensity` fait apparaître la ville.

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

const int   STEPS      = 72;     // pas de grille, rayon principal
const int   REFL_STEPS = 34;     // pas de grille, reflet du sol
const float BLOCK      = 7.0;    // période des pâtés de maisons (en cases)
const float STREET     = 3.0;    // largeur des avenues (en cases)
const float SPEED      = 1.6;    // vitesse de la caméra
const int   CARS       = 8;

vec3 neonA, neonB, neonC, haze;

float h11(float n) { return fract(sin(n * 127.1) * 43758.5453); }
float h21(vec2 p)  { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float h31(vec3 p)  { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

vec3 hueShift(vec3 c, float a) {
    const vec3 k = vec3(0.57735);
    float ca = cos(a), sa = sin(a);
    return c * ca + cross(k, c) * sa + k * dot(k, c) * (1.0 - ca);
}

// Tours de 2×2 cases : identifiant commun aux 4 cases d'une même tour.
vec2 towerId(vec2 cell) { return floor(cell * 0.5); }

// Hauteur de la case (0 = avenue).
float height(vec2 cell) {
    vec2 m = mod(cell, BLOCK);
    if (m.x < STREET || m.y < STREET) return 0.0;
    float r = h21(towerId(cell));
    return 7.0 + 22.0 * r * r + step(0.86, r) * 16.0;     // mégatours
}

vec3 towerNeon(vec2 tid) {
    float r = h21(tid * 1.37 + 4.2);
    return r < 0.36 ? neonA : (r < 0.70 ? neonB : neonC);
}

// Couleur d'une façade. P = point touché, axis = 0 (face ⟂ x) ou 1 (face ⟂ y).
vec3 shadeWall(vec3 P, vec2 cell, int axis, float h, float t) {
    vec2  tid = towerId(cell);
    float u   = axis == 0 ? P.y : P.x;            // le long du mur
    float v   = P.z;                               // hauteur
    float tr  = h21(tid + 9.0);

    // Béton sombre, panneaux, étages bas baignés par la lueur de la rue
    vec3 col = vec3(0.016, 0.018, 0.028) * (axis == 0 ? 1.0 : 0.72);
    float fu = fract(u * 0.5);                     // 0..1 sur la largeur de la tour
    col *= 0.75 + 0.25 * smoothstep(0.0, 0.04, fu) * smoothstep(1.0, 0.96, fu);
    col += haze * 0.55 * exp(-v * 0.45);

    // Fenêtres
    float cols = 9.0 + floor(tr * 7.0);
    vec2  wc  = vec2(fu * cols, v * 3.2);
    vec3  wid = vec3(floor(wc) + tid * 17.0, float(axis));
    float wr  = h31(wid);
    float lit = step(0.63, h31(wid + floor(t * 0.07 + wr * 11.0)));
    vec2  wf  = fract(wc);
    float win = smoothstep(0.10, 0.16, wf.x) * smoothstep(0.90, 0.84, wf.x)
              * smoothstep(0.18, 0.26, wf.y) * smoothstep(0.86, 0.78, wf.y);
    vec3  wcol = mix(vec3(1.0, 0.78, 0.50), vec3(0.62, 0.80, 1.0), step(0.55, wr));
    wcol = mix(wcol, towerNeon(tid), step(0.86, wr));
    float inRange = step(0.35, v) * step(v, h - 0.25);
    col += wcol * lit * win * inRange * (0.25 + 0.65 * wr);
    col += vec3(0.02, 0.03, 0.05) * (1.0 - lit) * win * inRange;   // vitres éteintes

    // Bandeaux néon horizontaux qui ceinturent la tour
    vec3  nc = towerNeon(tid);
    float bandZ = 1.2 + floor(tr * (h - 2.0));
    float band  = smoothstep(0.075, 0.02, abs(v - bandZ)) * step(0.30, tr);
    float topBand = smoothstep(0.09, 0.02, abs(v - (h - 0.10)));
    col += nc * (band * 2.0 + topBand * 1.0);

    // Panneau publicitaire géant animé (façon Night City) sur certaines façades
    float ar = h21(tid * 3.3 + float(axis) * 5.0);
    float adZ0 = 2.5 + floor(ar * max(h - 8.0, 1.0));
    vec2  ap = vec2((fu - 0.10) / 0.80, (v - adZ0) / 3.6);
    float inAd = step(0.0, ap.x) * step(ap.x, 1.0) * step(0.0, ap.y) * step(ap.y, 1.0) * step(0.62, ar);
    if (inAd > 0.5) {
        vec3  ac = ar < 0.80 ? neonA : (ar < 0.92 ? neonC : neonB);
        float blocks = step(0.55, h21(floor(ap * vec2(7.0, 4.0)) + floor(t * 1.2 + ar * 5.0)));
        float sweep  = smoothstep(0.12, 0.0, abs(fract(ap.x * 0.5 - t * 0.12 + ar) - 0.5) - 0.02);
        float ring   = exp(-abs(length((ap - 0.5) * vec2(1.9, 1.0)) - 0.30) * 26.0);
        float bars   = step(0.5, fract(ap.y * 9.0 - t * 0.6)) * step(0.72, ap.x) * 0.5;
        float scan   = 0.78 + 0.22 * sin(v * 60.0 - t * 5.0);
        float gl     = 0.85 + 0.15 * step(0.07, fract(sin(floor(t * 11.0) + ar * 40.0) * 43.7));
        vec3  ad = ac * (0.16 + blocks * 0.30 + sweep * 0.35 + ring * 1.5 + bars) * scan * gl;
        float edge = smoothstep(0.0, 0.03, ap.x) * smoothstep(1.0, 0.97, ap.x)
                   * smoothstep(0.0, 0.05, ap.y) * smoothstep(1.0, 0.95, ap.y);
        col = mix(col, ad * 2.2, edge);
    }

    // Enseigne verticale lumineuse, à « caractères », qui grésille
    float sr = h21(tid * 2.11 + float(axis) * 3.0);
    float sx = 0.18 + 0.60 * sr;
    float sy0 = h * (0.22 + 0.25 * h11(sr * 31.0)), sy1 = sy0 + h * (0.25 + 0.20 * sr);
    float inSign = smoothstep(0.075, 0.055, abs(fu - sx)) * step(sy0, v) * step(v, sy1) * step(0.42, sr);
    float fl = 0.70 + 0.30 * step(0.12, fract(sin(floor(t * 13.0) + sr * 77.0) * 43.7));
    fl *= 0.35 + 0.65 * step(0.06, fract(sin(floor(t * 0.9 + sr * 9.0) * 12.9) * 91.3));
    float glyph = 0.45 + 0.55 * step(0.42, fract(v * 2.6 + sr * 5.0))
                * step(0.25, h21(vec2(floor(v * 2.6 + sr * 5.0), sr)));
    vec3  sc = sr < 0.62 ? neonB : (sr < 0.82 ? neonC : neonA);
    col = mix(col, sc * glyph * 3.0 * fl, inSign);
    // halo de l'enseigne sur le mur
    col += sc * fl * 0.35 * smoothstep(0.30, 0.06, abs(fu - sx)) * step(sy0, v) * step(v, sy1) * step(0.42, sr) * (1.0 - inSign);

    return col;
}

// Lancer de rayon dans la ville. Renvoie la couleur ; `tHit` = distance (-1 = ciel),
// `N` = normale, `glow` = halos des néons accumulés le long du rayon.
vec3 castCity(vec3 ro, vec3 rd, float t, int steps, out float tHit, out vec3 N, out vec3 glow) {
    vec2 cell = floor(ro.xy);
    vec2 stp  = sign(rd.xy);
    vec2 inv  = 1.0 / max(abs(rd.xy), vec2(1e-5));
    vec2 side = (stp * (cell - ro.xy) + stp * 0.5 + 0.5) * inv;
    float tc = 0.0;
    int axis = 0;
    tHit = -1.0; N = vec3(0.0, 0.0, 1.0); glow = vec3(0.0);

    for (int i = 0; i < steps; i++) {
        float tExit = min(side.x, side.y);
        float h = height(cell);
        float zIn = ro.z + rd.z * tc, zOut = ro.z + rd.z * tExit;

        if (h > 0.0) {
            if (zIn < h && i > 0) {                       // façade
                tHit = tc;
                N = axis == 0 ? vec3(-stp.x, 0.0, 0.0) : vec3(0.0, -stp.y, 0.0);
                return shadeWall(ro + rd * tc, cell, axis, h, t);
            }
            if (zOut < h) {                               // toit
                tHit = (h - ro.z) / rd.z;
                return vec3(0.010, 0.012, 0.018) + haze * 0.05;
            }
            // halo : le rayon frôle une tour à néons
            float zm = 0.5 * (zIn + zOut);
            glow += towerNeon(towerId(cell)) * exp(-tc * 0.055) * 0.012
                  * smoothstep(h + 4.0, h, zm);
        } else if (rd.z < 0.0 && zOut < 0.0) {            // sol (avenue)
            tHit = -ro.z / rd.z;
            N = vec3(0.0, 0.0, 1.0);
            return vec3(0.0);                             // ombré par l'appelant
        }

        if (side.x < side.y) { tc = side.x; side.x += inv.x; cell.x += stp.x; axis = 0; }
        else                 { tc = side.y; side.y += inv.y; cell.y += stp.y; axis = 1; }
    }
    return vec3(0.0);
}

// Brume : plus épaisse au loin, colorée par la ville, lueur à hauteur des rues
vec3 applyFog(vec3 col, float dist, vec3 rd, vec3 sky) {
    float f = 1.0 - exp(-dist * 0.022);
    vec3 fogCol = mix(sky, haze * 2.2, 0.75) + haze * 1.2 * exp(-max(rd.z, 0.0) * 6.0);
    return mix(col, fogCol, f);
}

void main() {
    vec2 UV = qt_TexCoord0;
    float I = intensity;
    vec3 base = texture(source, UV).rgb;
    if (I < 0.001) { fragColor = vec4(base, 1.0) * qt_Opacity; return; }

    float aspect = resolution.x / resolution.y;
    vec2  uv = (UV - 0.5) * vec2(aspect, -1.0);            // centré, y vers le haut
    float t  = time;

    // Triade néon à partir de la couleur de l'effet, ravivée
    vec3 a = accent.rgb / max(max(accent.r, max(accent.g, accent.b)), 0.001);
    neonA = a;
    neonB = clamp(hueShift(a,  2.25), 0.0, 1.0);
    neonC = clamp(hueShift(a, -2.05), 0.0, 1.0);
    neonB /= max(max(neonB.r, max(neonB.g, neonB.b)), 0.001);
    neonC /= max(max(neonC.r, max(neonC.g, neonC.b)), 0.001);
    haze  = mix(neonB, neonC, 0.5 + 0.3 * sin(t * 0.05)) * 0.16;

    // Caméra : avance dans l'avenue (x ∈ [0, 2]), regard un peu levé, légers écarts
    vec3 ro  = vec3(1.5 + 0.45 * sin(t * 0.13), t * SPEED, 5.0 + 1.5 * sin(t * 0.09));
    vec3 fwd = normalize(vec3(0.11 * sin(t * 0.071), 1.0, 0.16 + 0.10 * sin(t * 0.11)));
    vec3 rgt = normalize(cross(fwd, vec3(0.0, 0.0, 1.0)));
    vec3 upv = cross(rgt, fwd);
    float roll = 0.035 * sin(t * 0.17);
    vec2 ruv = vec2(uv.x * cos(roll) - uv.y * sin(roll), uv.x * sin(roll) + uv.y * cos(roll));
    vec3 rd  = normalize(fwd * 0.80 + rgt * ruv.x + upv * ruv.y);

    // Ciel : wallpaper flouté et assombri + lueur de la ville vers l'horizon
    vec3 wall = textureLod(source, UV, 3.5).rgb;
    vec3 sky  = mix(wall, vec3(dot(wall, vec3(0.299, 0.587, 0.114))), 0.25) * 0.42;
    sky += haze * 1.6 * exp(-max(rd.z, 0.0) * 4.5);

    float tHit; vec3 N, glow;
    vec3 col = castCity(ro, rd, t, STEPS, tHit, N, glow);
    float dist = tHit;

    if (tHit < 0.0) {
        col = sky; dist = 1e3;
    } else if (N.z > 0.5 && ro.z + rd.z * tHit < 0.01) {
        // Sol mouillé : asphalte + marquage + reflet de la ville
        vec3 P = ro + rd * tHit;
        vec2 m = mod(P.xy, BLOCK);
        float lane = 0.0;
        if (m.x < STREET) lane = smoothstep(0.035, 0.015, abs(m.x - STREET * 0.5)) * step(0.5, fract(P.y * 0.35));
        if (m.y < STREET) lane = max(lane, smoothstep(0.035, 0.015, abs(m.y - STREET * 0.5)) * step(0.5, fract(P.x * 0.35)));
        vec3 ground = vec3(0.012, 0.013, 0.018) + neonA * lane * 0.55;

        // normale ondulée par les flaques et la pluie
        vec2 rip = vec2(sin(P.x * 9.0 + sin(P.y * 4.0 + t * 1.7)), sin(P.y * 7.0 + sin(P.x * 5.0 - t * 1.3))) * 0.018;
        vec3 rn = normalize(vec3(rip, 1.0));
        vec3 rr = reflect(rd, rn);
        float rt; vec3 rN, rGlow;
        vec3 rc = castCity(P + vec3(0.0, 0.0, 0.002), rr, t, REFL_STEPS, rt, rN, rGlow);
        vec3 rsky = haze * 1.8 + sky * 0.5;
        if (rt < 0.0) rc = rsky; else rc = applyFog(rc, rt, rr, rsky);
        rc += rGlow;
        float fres = 0.25 + 0.75 * pow(1.0 - max(-rd.z, 0.0), 3.0);  // rasant = miroir
        float puddle = 0.55 + 0.45 * smoothstep(0.35, 0.65, h21(floor(P.xy * 1.5)) );
        col = ground + rc * fres * puddle * 0.85;
    }

    if (tHit >= 0.0) col = applyFog(col, dist, rd, sky);
    col += glow;

    // Trafic volant : lumières qui remontent et descendent l'avenue, au-dessus de la rue
    for (int k = 0; k < CARS; k++) {
        float fk = float(k);
        float dir = h11(fk * 5.7) < 0.5 ? 1.0 : -1.0;
        float spd = 3.0 + 5.0 * h11(fk * 3.3);
        vec3 cp = vec3(dir > 0.0 ? 0.80 : 2.20,
                       ro.y + mod(h11(fk * 7.1) * 70.0 + t * (spd * dir - SPEED), 70.0) - 8.0,
                       6.5 + 9.0 * h11(fk * 2.3) + 0.15 * sin(t * 1.1 + fk));
        vec3 oc = cp - ro;
        float along = dot(oc, rd);
        if (along > 0.0 && along < dist) {
            float d2 = dot(oc - rd * along, oc - rd * along);
            vec3 lc = dir > 0.0 ? vec3(1.0, 0.16, 0.12) : mix(vec3(1.0), neonB, 0.45);  // feux arrière / phares
            col += lc * 0.0035 / (d2 + 0.0012) * exp(-along * 0.030);
        }
    }

    // Pluie fine, légèrement oblique (dans l'espace écran)
    vec2 rq = vec2(UV.x * aspect * 150.0 + UV.y * -34.0, UV.y * -3.6 + t * 6.5);
    float rs = h11(floor(rq.x));
    float ry = fract(rq.y * (0.6 + 0.9 * rs) + rs * 13.0);
    float streak = smoothstep(0.0, 0.10, ry) * smoothstep(0.42, 0.10, ry)
                 * step(0.50, rs) * smoothstep(0.5, 0.0, abs(fract(rq.x) - 0.5) * 3.0);
    col += mix(vec3(0.75, 0.85, 1.0), neonB, 0.3) * streak * 0.07;

    // Finition : vignette, courbe douce (les néons ne crament pas), léger contraste
    vec2 vg = UV - 0.5;
    col *= 1.0 - dot(vg, vg) * 0.85;
    col = col / (1.0 + col * 0.45);
    col = pow(col * 1.35, vec3(0.92));

    fragColor = vec4(mix(base, col, smoothstep(0.0, 0.30, I)), 1.0) * qt_Opacity;
}
