#version 440

// Rain — pluie sur une vitre, le wallpaper flou derrière.
//
// Porté de « Heartfelt » par Martijn Steinrucken aka BigWings (2017)
//   https://www.shadertoy.com/view/ltffzl
//   Licence Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported.
// (via la conversion Unity de yumayanagisawa/Unity-Raindrops)
//
// Adapté : pas de cœur ; la quantité de pluie et de buée suit `intensity` ;
// éclairs ; teinte néon et léger décalage des couleurs dans les gouttes, dans la
// couleur de l'effet (`accent`). Nécessite une source avec mipmaps (flou =
// textureLod), cf. Wallpaper.qml.

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

#define S(a, b, t) smoothstep(a, b, t)

vec3 N13(float p) {
    // de Dave Hoskins
    vec3 p3 = fract(vec3(p) * vec3(.1031, .11369, .13787));
    p3 += dot(p3, p3.yzx + 19.19);
    return fract(vec3((p3.x + p3.y) * p3.z, (p3.x + p3.z) * p3.y, (p3.y + p3.z) * p3.x));
}
float N(float t) { return fract(sin(t * 12345.564) * 7658.76); }
float Saw(float b, float t) { return S(0., b, t) * S(1., b, t); }

// Gouttes qui ruissellent : x = goutte, y = traînée
vec2 DropLayer2(vec2 uv, float t) {
    vec2 UV = uv;

    uv.y += t * 0.75;
    vec2 a = vec2(6., 1.);
    vec2 grid = a * 2.;
    vec2 id = floor(uv * grid);

    float colShift = N(id.x);
    uv.y += colShift;

    id = floor(uv * grid);
    vec3 n = N13(id.x * 35.2 + id.y * 2376.1);
    vec2 st = fract(uv * grid) - vec2(.5, 0);

    float x = n.x - .5;

    float y = UV.y * 20.;
    float wiggle = sin(y + sin(y));
    x += wiggle * (.5 - abs(x)) * (n.z - .5);
    x *= .7;
    float ti = fract(t + n.z);
    y = (Saw(.85, ti) - .5) * .9 + .5;
    vec2 p = vec2(x, y);

    float d = length((st - p) * a.yx);
    float mainDrop = S(.4, .0, d);

    float r = sqrt(S(1., y, st.y));
    float cd = abs(st.x - x);
    float trail = S(.23 * r, .15 * r * r, cd);
    float trailFront = S(-.02, .02, st.y - y);
    trail *= trailFront * r * r;

    y = UV.y;
    y = fract(y * 10.) + (st.y - .5);
    float dd = length(st - vec2(x, y));
    float droplets = S(.3, 0., dd);
    float m = mainDrop + droplets * r * trailFront;

    return vec2(m, trail);
}

// Petites gouttes immobiles qui apparaissent et sèchent
float StaticDrops(vec2 uv, float t) {
    uv *= 40.;
    vec2 id = floor(uv);
    uv = fract(uv) - .5;
    vec3 n = N13(id.x * 107.45 + id.y * 3543.654);
    vec2 p = (n.xy - .5) * .7;
    float d = length(uv - p);
    float fade = Saw(.025, fract(t + n.z));
    return S(.3, 0., d) * fract(n.z * 10.) * fade;
}

vec2 Drops(vec2 uv, float t, float l0, float l1, float l2) {
    float s = StaticDrops(uv, t) * l0;
    vec2 m1 = DropLayer2(uv, t) * l1;
    vec2 m2 = DropLayer2(uv * 1.85, t) * l2;
    float c = s + m1.x + m2.x;
    c = S(.3, 1., c);
    return vec2(c, max(m1.y * l0, m2.y * l1));
}

void main() {
    vec2 UV = qt_TexCoord0;
    float I = intensity;
    vec3 base = texture(source, UV).rgb;
    if (I < 0.001) { fragColor = vec4(base, 1.0) * qt_Opacity; return; }

    // Repère centré, y vers le haut (les gouttes tombent vers le bas de l'écran)
    vec2 uv = (UV - .5) * vec2(resolution.x / resolution.y, -1.);
    float T = time;
    float t = T * .2;

    float rainAmount = clamp(I, 0., 1.);
    float maxBlur = mix(2., 4.5, rainAmount);   // buée : le wallpaper reste reconnaissable
    float minBlur = 1.;

    float zoom = -cos(T * .2);
    uv *= .7 + zoom * .3;

    float staticDrops = S(-.5, 1., rainAmount) * 2.;
    float layer1 = S(.25, .75, rainAmount);
    float layer2 = S(.0, .5, rainAmount);

    vec2 c = Drops(uv, t, staticDrops, layer1, layer2);
    vec2 e = vec2(.001, 0.);
    float cx = Drops(uv + e,    t, staticDrops, layer1, layer2).x;
    float cy = Drops(uv + e.yx, t, staticDrops, layer1, layer2).x;
    vec2 n = vec2(cx - c.x, cy - c.x);            // normale de la goutte
    n.y = -n.y;                                    // retour au repère de la texture

    // Buée partout, image nette vue à travers les gouttes et leurs traînées
    float focus = mix(maxBlur - c.y, minBlur, S(.1, .2, c.x));
    // Décalage des couleurs dans les gouttes (aberration chromatique)
    vec2 ca = n * 0.35;
    vec3 col = vec3(textureLod(source, UV + n + ca, focus).r,
                    textureLod(source, UV + n,      focus).g,
                    textureLod(source, UV + n - ca, focus).b);

    // Ambiance : teinte néon qui respire, éclairs, vignette
    float tt = (T + 3.) * .5;
    float colFade = sin(tt * .2) * .5 + .5;
    vec3 neon = mix(vec3(.8, .9, 1.3), accent.rgb * 1.5 + .15, .55);
    col *= mix(vec3(1.), neon, colFade * .8 + .2);

    float lightning = sin(tt * sin(tt * 10.));
    lightning *= pow(max(0., sin(tt + sin(tt))), 10.);
    col *= 1. + lightning * .9;

    vec2 vg = UV - .5;
    col *= 1. - dot(vg, vg) * .9;

    // Les traînées prennent un liseré néon
    col += accent.rgb * c.y * .05;

    // Entrée/sortie en douceur selon l'intensité
    fragColor = vec4(mix(base, col, S(0., .25, I)), 1.0) * qt_Opacity;
}
