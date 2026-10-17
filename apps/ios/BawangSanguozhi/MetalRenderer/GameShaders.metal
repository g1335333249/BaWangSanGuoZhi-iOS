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
                             texture2d<float> pixels [[texture(0)]]) {
    constexpr sampler nearest(mag_filter::nearest, min_filter::nearest);
    return pixels.sample(nearest, v.uv);
}
