#version 440

// Mana — l'énergie du personnage du fond d'écran : une aura en flammes qui monte de son contour, un liseré qui
// pulse sur sa silhouette, des étincelles qui s'élèvent. La puissance respire : elle monte jusqu'à un pic puis
// redescend (cycle ~7 s) — au repos un simple liseré, au pic une aura qui déborde. Couleurs = celles du personnage (color1, color2).
// Le contour vient de `field`, préparé une fois par fond par scripts/system/wall-mana.py :
//   R = masque du personnage · G = proximité extérieure du contour · B = proximité intérieure.
// `intensity` dose l'ensemble (0 = le fond d'écran tel quel).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float intensity;
    float time;
    vec2  resolution;
    vec4  accent;
    vec4  color1;            // couleur vive du personnage (cœur des flammes)
    vec4  color2;            // seconde couleur (pointes des flammes)
};

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D field;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 5; i++) { v += a * noise(p); p = p * 2.02 + vec2(3.1, 1.7); a *= 0.5; }
    return v;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec3 base = texture(source, uv).rgb;
    float I = intensity;
    float asp = resolution.x / max(1.0, resolution.y);
    float t = time;
    vec3 c1 = color1.rgb, c2 = color2.rgb;
    vec4 F = texture(field, uv);

    // puissance : monte lentement jusqu'au pic puis redescend (cycle ~7 s), petite surtension au sommet
    float ph = 0.5 - 0.5 * cos(t * 6.2832 / 7.0);
    float P = 0.2 + 0.8 * pow(ph, 1.6) + 0.06 * sin(t * 9.0) * ph;

    // flammes fluides : bruit déformé qui s'écoule vers le haut (y du texte vers le bas → +t fait monter le motif)
    vec2 p = vec2(uv.x * asp, uv.y);
    vec2 w = vec2(fbm(p * 2.6 + vec2(0.0, t * 0.55)), fbm(p * 2.6 + vec2(5.2, t * 0.7)));
    float n = fbm(p * vec2(4.0, 2.2) + w * 2.2 + vec2(0.0, t * 0.9));
    float n2 = fbm(p * vec2(9.0, 5.0) + w * 1.5 + vec2(0.0, t * 1.8));
    // on lit le contour plus bas : l'aura d'un point du contour s'étire vers le haut, d'autant plus que P est fort
    vec2 lift = vec2((w.x - 0.5) * 0.04 * P, (0.02 + 0.16 * n * n) * P);
    vec4 Fl = texture(field, uv + lift);
    float g = max(Fl.g, Fl.r * 0.95) * (1.0 - F.r);         // pas de flammes sur le personnage lui-même
    float reach = mix(0.78, 0.12, P);                         // au repos l'aura colle au contour, au pic elle s'étend
    float near = smoothstep(0.0, 0.25, g);                    // jamais de flammes loin du contour
    float flame = smoothstep(reach, reach + 0.35, g + (n - 0.5) * 0.7 * P + (n2 - 0.5) * 0.25) * near;
    float tongue = smoothstep(reach + 0.25, reach + 0.6, g + (n2 - 0.4) * 0.6 * P) * near;
    // des langues séparées par des vides plutôt qu'un halo plein : le détail fin découpe la flamme
    float wisps = smoothstep(0.35, 0.75, n2 + 0.25 * (1.0 - flame));
    float body = flame * mix(0.35, 1.0, wisps);

    vec3 aura = mix(c2, c1, body) * body * (0.55 + 0.5 * P);
    aura += mix(c1, vec3(1.0), 0.4) * pow(tongue * wisps, 2.0) * 0.6 * P;   // cœur des langues, plus clair
    aura += c1 * pow(F.g, 3.0) * (0.25 + 0.35 * P);                    // halo serré, toujours là

    // liseré : le bord du personnage s'allume par vagues qui montent
    float rim = pow(F.b, 2.5) * (0.35 + 0.65 * P) * (0.6 + 0.4 * sin(uv.y * 50.0 + t * 5.0 + n * 6.0));
    vec3 rimc = mix(c1, vec3(1.0), 0.35) * rim * 0.8;

    // étincelles : montent depuis l'aura, s'éteignent en s'éloignant
    float sp = 0.0;
    for (int l = 0; l < 2; l++) {
        float sc = 40.0 + float(l) * 25.0;
        vec2 gp = vec2(uv.x * asp, uv.y + t * (0.12 + 0.05 * float(l))) * sc;
        gp.x += sin(gp.y * 0.25 + float(l) * 2.0) * 0.6;
        vec2 cell = floor(gp), f = fract(gp) - 0.5;
        float r = hash(cell + float(l) * 7.3);
        if (r > 0.8) {
            vec2 o = vec2(hash(cell + 1.1), hash(cell + 2.3)) - 0.5;
            float life = texture(field, uv + vec2(0.0, 0.06)).g;    // naît près du contour
            sp += smoothstep(0.12, 0.0, length(f - o * 0.6)) * life * P * (0.5 + 0.5 * sin(t * 6.0 + r * 40.0));
        }
    }
    vec3 spc = mix(c1, vec3(1.0), 0.5) * sp * (1.0 - F.r);

    // le décor s'assombrit un peu pour que l'énergie ressorte
    vec3 col = base * (1.0 - (0.15 + 0.25 * P) * I * (1.0 - F.r) * (1.0 - g));
    col += (aura + spc) * I + rimc * I;
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
