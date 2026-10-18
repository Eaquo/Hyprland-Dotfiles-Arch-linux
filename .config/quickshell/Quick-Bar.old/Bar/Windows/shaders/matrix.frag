#version 440

// Matrix — vol en 3D à travers la pluie de runes (« Inside the Matrix »).
//
// Porté depuis le shader du terminal kitty (templates wallust kitty-matrix.slang),
// lui-même porté de Shadertoy :
//   Inside the Matrix          https://www.shadertoy.com/view/4t3BWl
//   runes par FabriceNeyret2 / otaviogood  https://www.shadertoy.com/view/4ltyDM
//   portage Slang pour kitty : Kovid Goyal (GPLv3)
//
// Ici : même scène et même trajectoire de caméra, rendues par-dessus le wallpaper
// assombri ; couleurs = accent wallust (corps des colonnes) et accent éclairci
// (tête). `intensity` (0 → pic → 0 pendant un burst) dose l'ensemble.

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

const int   ITERATIONS = 40;
const float SPEED = 0.5;
const float STRIP_CHARS_MIN = 7.0;
const float STRIP_CHARS_MAX = 40.0;
const float STRIP_CHAR_HEIGHT = 0.15;
const float STRIP_CHAR_WIDTH = 0.10;
const float ZCELL_SIZE = STRIP_CHAR_HEIGHT * STRIP_CHARS_MAX;
const float XYCELL_SIZE = 12.0 * STRIP_CHAR_WIDTH;
const int   BLOCK_SIZE = 10;
const int   BLOCK_GAP = 2;
const float WALK_SPEED = 0.5 * XYCELL_SIZE;
const float BLOCKS_BEFORE_TURN = 3.0;
const float PI = 3.14159265359;

// ---- hasard ----

float hash(float v) { return fract(sin(v) * 43758.5453123); }
float hash(vec2 v)  { return hash(dot(v, vec2(5.3983, 5.4427))); }

vec2 hash2(vec2 v) {
    v = v * mat2(127.1, 311.7, 269.5, 183.3);
    return fract(sin(v) * 43758.5453123);
}
vec4 hash4(vec2 v) {
    vec4 p = v * mat4x2(127.1, 311.7, 269.5, 183.3, 113.5, 271.9, 246.1, 124.6);
    return fract(sin(p) * 43758.5453123);
}
vec4 hash4(vec3 v) {
    vec4 p = v * mat4x3(127.1, 311.7, 74.7, 269.5, 183.3, 246.1, 113.5, 271.9, 124.6, 271.9, 269.5, 311.7);
    return fract(sin(p) * 43758.5453123);
}

// ---- runes ----

float rune_line(vec2 p, vec2 a, vec2 b) {
    p -= a; b -= a;
    float h = clamp(dot(p, b) / dot(b, b), 0.0, 1.0);
    return length(p - b * h);
}

float rune(vec2 U, vec2 seed, float highlight) {
    float d = 1e5;
    for (int i = 0; i < 4; i++) {
        vec4 pos = hash4(seed);
        seed += 1.0;

        // chaque rune touche les 4 bords de sa case
        if (i == 0) pos.y = 0.0;
        if (i == 1) pos.x = 0.999;
        if (i == 2) pos.x = 0.0;
        if (i == 3) pos.y = 0.999;

        vec4 snaps = vec4(2.0, 3.0, 2.0, 3.0);
        pos = (floor(pos * snaps) + 0.5) / snaps;

        if (pos.xy != pos.zw) d = min(d, rune_line(U, pos.xy, pos.zw + 0.001));
    }
    return smoothstep(0.1, 0.0, d) + highlight * smoothstep(0.4, 0.0, d);
}

float random_char(vec2 outer, vec2 inner, float highlight) {
    vec2 seed = vec2(dot(outer, vec2(269.5, 183.3)), dot(outer, vec2(113.5, 271.9)));
    return rune(inner, seed, highlight);
}

// ---- pluie numérique (lancer de rayon dans la grille de colonnes) ----

vec3 rain(vec3 ro3, vec3 rd3, float t, vec3 headCol, vec3 bodyCol) {
    vec4 result = vec4(0.0);

    vec2 ro2 = ro3.xy;
    vec2 rd2 = normalize(rd3.xy);

    bool prefer_dx = abs(rd2.x) > abs(rd2.y);
    float t3_to_t2 = prefer_dx ? rd3.x / rd2.x : rd3.y / rd2.y;

    ivec3 cell_side  = ivec3(step(0.0, rd3));
    ivec3 cell_shift = ivec3(sign(rd3));

    float t2 = 0.0;
    ivec2 next_cell = ivec2(floor(ro2 / XYCELL_SIZE));

    for (int iter = 0; iter < ITERATIONS; iter++) {
        ivec2 cell = next_cell;
        float t2s = t2;

        vec2 side = vec2(next_cell + cell_side.xy) * XYCELL_SIZE;
        vec2 t2_side = (side - ro2) / rd2;
        if (t2_side.x < t2_side.y) { t2 = t2_side.x; next_cell.x += cell_shift.x; }
        else                       { t2 = t2_side.y; next_cell.y += cell_shift.y; }

        // cases vides (allées entre les blocs)
        vec2 cell_in_block = fract(vec2(cell) / float(BLOCK_SIZE));
        float gap = float(BLOCK_GAP) / float(BLOCK_SIZE);
        if (cell_in_block.x < gap || cell_in_block.y < gap
            || (cell_in_block.x < (gap + 0.1) && cell_in_block.y < (gap + 0.1))) continue;

        float t3s = t2s / t3_to_t2;
        float pos_z = ro3.z + rd3.z * t3s;
        float xh = hash(vec2(cell));
        float z_shift = xh * 11.0 - t * (0.5 + xh + xh * xh + pow(xh, 16.0) * 3.0);
        float czs = floor(z_shift / STRIP_CHAR_HEIGHT);
        z_shift = czs * STRIP_CHAR_HEIGHT;
        int zcell = int(floor((pos_z - z_shift) / ZCELL_SIZE));

        for (int j = 0; j < 2; j++) {
            vec4 ch  = hash4(vec3(ivec3(cell, zcell)));
            vec4 ch2 = fract(ch * vec4(127.1, 311.7, 271.9, 124.6));

            float chars_count   = ch.w * (STRIP_CHARS_MAX - STRIP_CHARS_MIN) + STRIP_CHARS_MIN;
            float target_length = chars_count * STRIP_CHAR_HEIGHT;
            float target_rad    = STRIP_CHAR_WIDTH * 0.5;
            float target_z = float(zcell) * ZCELL_SIZE + z_shift + ch.z * (ZCELL_SIZE - target_length);
            vec2  target   = vec2(cell) * XYCELL_SIZE + target_rad + ch.xy * (XYCELL_SIZE - target_rad * 2.0);

            vec2 sv = target - ro2;
            float tmin = dot(sv, rd2);
            if (tmin >= t2s && tmin <= t2) {
                float u = sv.x * rd2.y - sv.y * rd2.x;
                if (abs(u) < target_rad) {
                    u = (u / target_rad + 1.0) * 0.5;
                    float z = ro3.z + rd3.z * tmin / t3_to_t2;
                    float v = (z - target_z) / target_length;
                    if (v >= 0.0 && v < 1.0) {
                        float c = floor(v * chars_count);
                        float q = fract(v * chars_count);
                        vec2 char_hash = hash2(vec2(c + czs, ch2.x));
                        if (char_hash.x >= 0.1 || c == 0.0) {
                            float time_factor = floor(c == 0.0 ? t
                                : t * (ch2.z + ch2.w * ch2.w * 4.0 * pow(char_hash.y, 4.0)));
                            float a = random_char(vec2(char_hash.x, time_factor), vec2(u, q),
                                                  max(1.0, 3.0 - c * 0.5) * 0.2);
                            a *= clamp((chars_count - 0.5 - c) * 0.5, 0.0, 1.0);
                            if (a > 0.0) {
                                float attenuation = 1.0 + pow(0.06 * tmin / t3_to_t2, 2.0);
                                vec3 col = (c == 0.0 ? headCol : bodyCol) / attenuation;
                                float a1 = result.a;
                                result.a = a1 + (1.0 - a1) * a;
                                result.xyz = (result.xyz * a1 + col * (1.0 - a1) * a) / result.a;
                                if (result.a > 0.98) return result.xyz;
                            }
                        }
                    }
                }
            }
            zcell += cell_shift.z;
        }
    }
    return result.xyz * result.a;
}

// ---- caméra ----

vec2 rotate2D(vec2 v, float angle) {
    float s = sin(angle), c = cos(angle);
    return mat2(c, -s, s, c) * v;
}
vec3 rotateX(vec3 v, float angle) {
    float s = sin(angle), c = cos(angle);
    return mat3(1.0, 0.0, 0.0, 0.0, c, -s, 0.0, s, c) * v;
}
vec3 rotateY(vec3 v, float angle) {
    float s = sin(angle), c = cos(angle);
    return mat3(c, 0.0, -s, 0.0, 1.0, 0.0, s, 0.0, c) * v;
}
vec3 rotateZ(vec3 v, float angle) {
    float s = sin(angle), c = cos(angle);
    return mat3(c, -s, 0.0, s, c, 0.0, 0.0, 0.0, 1.0) * v;
}
float smoothstep1(float x) { return smoothstep(0.0, 1.0, x); }

void main() {
    vec2 tc = qt_TexCoord0;
    float I = intensity;
    vec3 base = texture(source, tc).rgb;
    if (I < 0.001) { fragColor = vec4(base, 1.0) * qt_Opacity; return; }

    // Repère centré, ratio respecté, y vers le haut (comme l'original Shadertoy)
    vec2 uv = (2.0 * tc - 1.0) * vec2(resolution.x / resolution.y, -1.0);
    float t = mod(time, 300.0) * SPEED;

    const float turn_rad = 0.25 / BLOCKS_BEFORE_TURN;
    const float turn_abs_time = (PI * 0.5 * turn_rad) * 1.5;
    const float turn_time = turn_abs_time / (1.0 - 2.0 * turn_rad + turn_abs_time);

    float level1_size = float(BLOCK_SIZE) * BLOCKS_BEFORE_TURN * XYCELL_SIZE;
    float gap_size = float(BLOCK_GAP) * XYCELL_SIZE;

    vec3 ro = vec3(gap_size * 0.5, gap_size * 0.5, 0.0);
    vec3 rd = vec3(uv.x, 2.0, uv.y);

    float tq = fract(t / (level1_size * 4.0 * 4.0) * WALK_SPEED);
    float t8 = fract(tq * 4.0);
    float t1 = fract(t8 * 8.0);

    vec2 prev, dir;
    if (tq < 0.25)      { prev = vec2(0.0, 0.0); dir = vec2(0.0, 1.0); }
    else if (tq < 0.50) { prev = vec2(0.0, 1.0); dir = vec2(1.0, 0.0); }
    else if (tq < 0.75) { prev = vec2(1.0, 1.0); dir = vec2(0.0, -1.0); }
    else                { prev = vec2(1.0, 0.0); dir = vec2(-1.0, 0.0); }

    float angle = floor(tq * 4.0);
    prev *= 4.0;

    const float first_turn_look_angle = 0.4;
    const float second_turn_drift_angle = 0.5;
    const float fifth_turn_drift_angle = 0.25;

    vec2 dirL = rotate2D(dir, -PI * 0.5);
    vec2 dirR = -dirL;
    vec2 turn;
    float turn_sign = 0.0;
    float up_down = 0.0;
    float rotate_on_turns = 1.0;
    float roll_on_turns = 1.0;
    float add_angel = 0.0;

    if (t8 < 0.125) {
        turn = dirL;
        turn_sign = -1.0;
        angle -= first_turn_look_angle * (max(0.0, t1 - (1.0 - turn_time * 2.0)) / turn_time
                                          - max(0.0, t1 - (1.0 - turn_time)) / turn_time * 2.5);
        roll_on_turns = 0.0;
    } else if (t8 < 0.250) {
        prev += dir;
        turn = dir;
        dir = dirL;
        angle -= 1.0;
        turn_sign = 1.0;
        add_angel += first_turn_look_angle * 0.5 + (-first_turn_look_angle * 0.5 + 1.0 + second_turn_drift_angle) * t1;
        rotate_on_turns = 0.0;
        roll_on_turns = 0.0;
    } else if (t8 < 0.375) {
        prev += dir + dirL;
        turn = dirR;
        turn_sign = 1.0;
        add_angel += second_turn_drift_angle * sqrt(1.0 - t1);
    } else if (t8 < 0.500) {
        prev += dir + dir + dirL;
        turn = dirR;
        dir = dirR;
        angle += 1.0;
        turn_sign = 0.0;
        up_down = sin(t1 * PI) * 0.37;
    } else if (t8 < 0.625) {
        prev += dir + dir;
        turn = dir;
        dir = dirR;
        angle += 1.0;
        turn_sign = -1.0;
        up_down = sin(-min(1.0, t1 / (1.0 - turn_time)) * PI) * 0.37;
    } else if (t8 < 0.750) {
        prev += dir + dir + dirR;
        turn = dirL;
        turn_sign = -1.0;
        add_angel -= (fifth_turn_drift_angle + 1.0) * smoothstep1(t1);
        rotate_on_turns = 0.0;
        roll_on_turns = 0.0;
    } else if (t8 < 0.875) {
        prev += dir + dir + dir + dirR;
        turn = dir;
        dir = dirL;
        angle -= 1.0;
        turn_sign = 1.0;
        add_angel -= fifth_turn_drift_angle - smoothstep1(t1) * (fifth_turn_drift_angle * 2.0 + 1.0);
        rotate_on_turns = 0.0;
        roll_on_turns = 0.0;
    } else {
        prev += dir + dir + dir;
        turn = dirR;
        turn_sign = 1.0;
        angle += fifth_turn_drift_angle * (1.5 * min(1.0, (1.0 - t1) / turn_time)
                 - 0.5 * smoothstep1(1.0 - min(1.0, t1 / (1.0 - turn_time))));
    }

    angle += add_angel;
    rd = rotateX(rd, up_down);

    vec2 p;
    if (turn_sign == 0.0) {
        p = prev + dir * (turn_rad + t1);
    } else if (t1 > (1.0 - turn_time)) {
        float tr = (t1 - (1.0 - turn_time)) / turn_time;
        vec2 ctr = prev + dir * (1.0 - turn_rad) + turn * turn_rad;
        p = ctr + turn_rad * rotate2D(dir, (tr - 1.0) * turn_sign * PI * 0.5);
        angle += tr * turn_sign * rotate_on_turns;
        rd = rotateY(rd, sin(tr * turn_sign * PI) * 0.2 * roll_on_turns);
    } else {
        t1 /= (1.0 - turn_time);
        p = prev + dir * (turn_rad + (1.0 - turn_rad * 2.0) * t1);
    }

    rd = rotateZ(rd, angle * PI * 0.5);
    ro.xy += level1_size * p;
    rd = normalize(rd);
    ro += rd * 0.2;

    // Couleurs wallust : corps = accent, tête = accent tiré vers le blanc
    vec3 tint    = accent.rgb;
    vec3 headCol = mix(tint, vec3(1.0), 0.7);
    vec3 r = rain(ro, rd, t, headCol, tint);

    // Wallpaper assombri et teinté (il reste devinable), pluie par-dessus
    float lum = dot(base, vec3(0.299, 0.587, 0.114));
    vec3 col = mix(base, lum * tint * 0.35, clamp(I * 0.9, 0.0, 1.0));
    col += r * 1.6 * I;

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
