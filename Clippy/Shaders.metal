//
//  Shaders.metal
//  Clippy
//
//  Created by Mehmet Akbaba on 13.12.2025.
//

#include <metal_stdlib>
using namespace metal;

// Vertex shader to output a fullscreen triangle
struct TexturedVertex {
    float4 position [[position]];
    float2 texCoord;
};

vertex TexturedVertex texture_vertex(uint vid [[vertex_id]]) {
    TexturedVertex out;
    // A single triangle that covers the whole screen in normalized device coordinates
    const float4 positions[] = {
        float4(-1.0, -1.0, 0.0, 1.0),
        float4( 3.0, -1.0, 0.0, 1.0),
        float4(-1.0,  3.0, 0.0, 1.0)
    };
    const float2 texCoords[] = {
        float2(0.0, 1.0),
        float2(2.0, 1.0),
        float2(0.0, -1.0)
    };

    out.position = positions[vid];
    out.texCoord = texCoords[vid];
    return out;
}

// Fragment shader to sample from the source texture
fragment float4 texture_fragment(TexturedVertex in [[stage_in]],
                                 texture2d<float> sourceTexture [[texture(0)]])
{
    constexpr sampler s(coord::normalized, filter::linear, address::clamp_to_edge);
    return sourceTexture.sample(s, in.texCoord);
}

