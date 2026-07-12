#version 440

// Matrix — vraie pluie de code : le fond est assombri et teinté vert, des gouttes
// tombent colonne par colonne avec une tête lumineuse blanche-verte et une traîne
// qui s'efface, chaque cellule scintille (faux glyphes).

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

float hash(float n)  { return fract(sin(n) * 43758.5453123); }
float hash2(vec2 p)  { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }

void main() {
    vec2 uv = qt_TexCoord0;
    float I = intensity;
    if (I < 0.001) { fragColor = texture(source, uv) * qt_Opacity; return; }
    float t = time;

    vec3  base = texture(source, uv).rgb;
    float lum  = dot(base, vec3(0.299, 0.587, 0.114));
    vec3  tint = accent.rgb;   // couleur wallust (color11)

    // Fond assombri + teinté accent (l'image reste devinable)
    vec3 col = mix(base, lum * tint * 0.6, I * 0.78);

    // Grille de cellules (glyphes) — colonnes fines, cellules un peu hautes
    float cols = 52.0;
    float rows = cols * (resolution.y / resolution.x) * 1.7;
    vec2  cell = floor(vec2(uv.x * cols, uv.y * rows));
    float colX = cell.x;

    // Goutte de la colonne : la tête descend (cell.y croît vers le bas)
    float speed = 9.0 + hash(colX) * 22.0;                 // cellules/s
    float len   = 9.0 + hash(colX * 1.7) * 16.0;           // longueur de la traîne
    float head  = mod(t * speed + hash(colX * 3.1) * rows, rows + len);
    float above = head - cell.y;                            // >0 = traîne (déjà passée)

    float inTrail = step(0.0, above) * step(above, len);
    float b       = inTrail * (1.0 - above / len);          // fondu de la traîne
    float isHead  = step(0.0, above) * step(above, 1.0);    // la tête

    // Scintillement par cellule (glyphe qui change)
    float glyph = step(0.30, hash2(cell + floor(t * 11.0)));

    // Rendu : traîne en accent + tête plus claire (accent → blanc)
    col += tint * (b * glyph) * 1.5 * I;
    col += mix(tint, vec3(1.0), 0.65) * (isHead * glyph) * I;

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
