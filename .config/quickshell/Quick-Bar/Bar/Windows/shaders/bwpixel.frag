#version 440

// Noir & blanc pixelisé : quantifie l'image en gros pixels + niveaux de gris
// posterisés (vibe pixel-art rétro). L'ampleur suit l'intensité du burst.

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

void main() {
    vec2 uv = qt_TexCoord0;
    float I = intensity;
    if (I < 0.001) { fragColor = texture(source, uv) * qt_Opacity; return; }

    // Pixelisation : moins de cellules quand I monte → plus gros pixels
    float cells = mix(420.0, 80.0, I);
    vec2  grid  = vec2(cells, cells * resolution.y / resolution.x);
    vec2  puv   = (floor(uv * grid) + 0.5) / grid;

    // Niveau de gris + posterisation (6 paliers)
    vec3  c = texture(source, puv).rgb;
    float g = dot(c, vec3(0.299, 0.587, 0.114));
    g = floor(g * 6.0 + 0.5) / 6.0;
    vec3  bw = vec3(g);

    // Fondu progressif original → pixel N&B selon I
    vec3 col = mix(texture(source, uv).rgb, bw, I);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
