// Neon Rain — custom shader for Kitty (Slang)
// Procedural cyberpunk data rain: cyan / magenta / violet, with subtle scanlines,
// depth layers and occasional horizontal glitch bands.
// Designed as a restrained overlay so terminal text remains readable.

static const float RAIN_DENSITY = 42.0;
static const float RAIN_SPEED = 0.72;
static const float GLOW_STRENGTH = 0.34;
static const float GLITCH_STRENGTH = 0.20;
static const float OVERLAY_STRENGTH = 0.28;

float hash21(float2 p) {
    p = frac(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return frac(p.x * p.y);
}

float box_mask(float2 p, float2 half_size) {
    float2 d = abs(p) - half_size;
    return 1.0 - smoothstep(0.0, 0.035, max(d.x, d.y));
}

// A compact synthetic glyph made from a few segments. It is not a font;
// it evokes angular terminal glyphs at low cost.
float glyph(float2 uv, float seed) {
    float2 p = uv - 0.5;
    float h = hash21(float2(seed, floor(seed * 7.13) + 2.0));
    float v = 0.0;

    // Outer strokes, with per-glyph variations.
    v = max(v, box_mask(p - float2(-0.18, 0.0), float2(0.035, 0.34)));
    v = max(v, box_mask(p - float2( 0.18, 0.0), float2(0.035, 0.34)));
    if (h > 0.22)
        v = max(v, box_mask(p - float2(0.0, 0.28), float2(0.19, 0.035)));
    if (h > 0.43)
        v = max(v, box_mask(p - float2(0.0, -0.28), float2(0.19, 0.035)));
    if (h > 0.58)
        v = max(v, box_mask(p - float2(0.0, 0.0), float2(0.17, 0.025)));
    if (h > 0.70)
        v = max(v, box_mask(p - float2(0.0, 0.12), float2(0.025, 0.14)));
    if (h > 0.82)
        v = max(v, box_mask(p - float2(0.04, -0.12), float2(0.13, 0.025)));
    return v;
}

public float4 fragment_main(float4 color, KittyTextures t, KittyCustomShaderData d) {
    float2 uv = t.pos;
    float time = d.timestamp;

    // Slight perspective compression toward the top gives the streams depth.
    float perspective = lerp(0.72, 1.22, uv.y);
    float2 p = float2(uv.x * perspective, uv.y);

    float col_width = 1.0 / RAIN_DENSITY;
    float column = floor(p.x / col_width);
    float x_local = frac(p.x / col_width);

    float seed = hash21(float2(column, 19.7));
    float speed = RAIN_SPEED * lerp(0.48, 1.35, hash21(float2(column, 4.1)));
    float phase = hash21(float2(column, 8.9)) * 2.0;
    float head = frac(time * speed * 0.10 + phase);

    // Stream length varies per column; vertical distance wraps smoothly.
    float stream_len = lerp(0.12, 0.48, hash21(float2(column, 31.4)));
    float y_stream = frac(uv.y + time * speed * 0.10 + phase);
    float behind_head = frac(head - uv.y + 1.0);
    float stream = 1.0 - smoothstep(stream_len * 0.55, stream_len, behind_head);
    stream *= smoothstep(0.0, 0.08, behind_head);

    // Discrete character cells within each stream.
    float glyph_rows = 24.0;
    float row = floor((uv.y + time * speed * 0.22 + phase) * glyph_rows);
    float y_local = frac((uv.y + time * speed * 0.22 + phase) * glyph_rows);
    float glyph_seed = column * 17.0 + row * 3.1 + seed * 13.0;
    float glyph_shape = glyph(float2(x_local, y_local), glyph_seed);
    float glyph_gate = step(0.22, hash21(float2(column, row + 6.0)));
    float characters = glyph_shape * glyph_gate * stream;

    // The leading glyph is brighter, cyan-white; trails drift toward violet.
    float head_distance = abs(uv.y - head);
    float head_glow = exp(-head_distance * 70.0) * step(0.35, seed);
    float palette_mix = 0.5 + 0.5 * sin(column * 0.21 + time * 0.28);
    float3 cyan = float3(0.02, 0.78, 1.00);
    float3 magenta = float3(0.92, 0.08, 0.78);
    float3 violet = float3(0.36, 0.12, 1.00);
    float3 stream_color = lerp(cyan, violet, smoothstep(0.18, 0.86, palette_mix));
    stream_color = lerp(stream_color, magenta, smoothstep(0.78, 0.98, palette_mix));

    float depth = lerp(0.40, 1.0, hash21(float2(column, 1.8)));
    float rain_mask = saturate(characters * 0.72 + head_glow * 0.55);
    float3 rain_rgb = stream_color * rain_mask * depth * GLOW_STRENGTH;
    rain_rgb += float3(0.42, 0.92, 1.0) * head_glow * 0.26;

    // Thin scanlines, deliberately subtle.
    float scan = 0.5 + 0.5 * sin(uv.y * 920.0);
    float scanline = (1.0 - smoothstep(0.78, 1.0, scan)) * 0.035;

    // Occasional short horizontal glitch bands, deterministic and inexpensive.
    float band_id = floor(uv.y * 36.0);
    float band_seed = hash21(float2(band_id, floor(time * 2.5)));
    float band_on = step(0.91, band_seed);
    float band_shift = (hash21(float2(band_id, 4.0)) - 0.5) * 0.045;
    float glitch_band = band_on * step(0.18, hash21(float2(floor(uv.x * 8.0 + time), band_id)));
    float glitch_edge = smoothstep(0.0, 0.06, uv.x) * (1.0 - smoothstep(0.92, 1.0, uv.x));
    float3 glitch_rgb = float3(0.95, 0.08, 0.58) * glitch_band * glitch_edge * GLITCH_STRENGTH;

    // Dim violet/cyan haze at the sides adds a sense of depth without a costly raymarch.
    float side = abs(uv.x - 0.5) * 2.0;
    float haze = smoothstep(0.35, 1.0, side) * 0.045;
    float3 haze_rgb = lerp(violet, cyan, uv.x) * haze;

    // Overlay, not a full-screen replacement: preserve existing terminal content.
    float3 base = color.rgb;
    float3 overlay = rain_rgb + glitch_rgb + haze_rgb;
    base = base * (1.0 - OVERLAY_STRENGTH * 0.22);
    base += overlay * OVERLAY_STRENGTH;
    base -= scanline * OVERLAY_STRENGTH;

    // Tiny chromatic offset impression via a narrow glitch tint (no extra texture samples).
    base += float3(0.02, 0.0, 0.035) * glitch_band * GLITCH_STRENGTH * 0.22;

    return float4(saturate(base), color.a);
}
