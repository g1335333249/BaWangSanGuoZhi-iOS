#include <metal_stdlib>
using namespace metal;

struct GameVertex {
    float4 position [[position]];
    float2 uv;
};

vertex GameVertex gameVertex(uint id [[vertex_id]],
                             constant float4 &rect [[buffer(0)]],
                             constant float &rightUV [[buffer(1)]]) {
    const float2 corners[4] = {
        float2(rect.x, rect.y), float2(rect.z, rect.y),
        float2(rect.x, rect.w), float2(rect.z, rect.w)
    };
    const float2 uv[4] = {
        float2(0, 1), float2(rightUV, 1),
        float2(0, 0), float2(rightUV, 0)
    };
    return { float4(corners[id], 0, 1), uv[id] };
}

fragment float4 gameFragment(GameVertex v [[stage_in]],
                             texture2d<float> pixels [[texture(0)]],
                             constant uint &quality [[buffer(0)]]) {
    constexpr sampler pixelSampler(coord::normalized, address::clamp_to_edge,
                                   mag_filter::nearest, min_filter::nearest);
    constexpr sampler smoothSampler(coord::normalized, address::clamp_to_edge,
                                    mag_filter::linear, min_filter::linear);
    float4 crisp = pixels.sample(pixelSampler, v.uv);
    if (quality == 0u) return crisp;
    float4 smooth = pixels.sample(smoothSampler, v.uv);
    if (quality == 1u) return smooth;

    // Contrast-adaptive smoothing. Preserve high-contrast Chinese glyph edges
    // and UI separators while softening low-contrast staircase color edges.
    // This is NOT AI reconstruction or a higher-resolution game renderer.
    float2 texel = 1.0 / float2(pixels.get_width(), pixels.get_height());
    float3 right = pixels.sample(pixelSampler, v.uv + float2(texel.x, 0)).rgb;
    float3 down  = pixels.sample(pixelSampler, v.uv + float2(0, texel.y)).rgb;
    float contrast = max(length(crisp.rgb - right), length(crisp.rgb - down));
    float preserve = smoothstep(0.12, 0.48, contrast);
    return mix(smooth, crisp, preserve);
}
