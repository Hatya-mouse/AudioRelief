//
//  CursorHighlight.metal
//  AudioRelief
//
//  Created by Shuntaro Kasatani on 2026/02/26.
//

#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
using namespace metal;

[[visible]]
void highlightCursorShader(realitykit::surface_parameters params) {
    const float MAX_THICKNESS = 0.25;
    const float SIZE_Y = 1.0;
    
    float2 clickPos = params.uniforms().custom_parameter().xy;
    float radius = params.uniforms().custom_parameter().z;
    float playhead = params.uniforms().custom_parameter().a;
    float height = params.geometry().model_position().y;

    // Calculate the color based on the height
    float normalizedHeight = saturate(height / MAX_THICKNESS);

    half3 lowColor = half3(0.1, 0.5, 0.1);
    half3 highColor = half3(0.5, 0.3, 0.1);
    half3 finalColor = mix(lowColor, highColor, normalizedHeight);

    params.surface().set_base_color(finalColor);
    
    // Calculate the distance to the cursor and highlight around it
    float2 currentPos = params.geometry().model_position().xz;
    float dist = distance(currentPos, clickPos);
    
    if (dist < radius * 0.8) {
        params.surface().set_emissive_color(half3(0.0, 0.3, 1.0));
    } else if (dist < radius) {
        params.surface().set_emissive_color(half3(0.0, 0.2, 0.6));
    }
    
    // Highlight the playhead
    if (playhead > 0) {
        float playheadY = playhead - SIZE_Y / 2;
        if (currentPos.y < playheadY) {
            float playheadDist = min((playheadY - currentPos.y) * 2.0, 1.0);
            half3 playheadGradient = mix(half3(0.2, 0.4, 1.0), half3(0.0, 0.0, 0.0), playheadDist);
            params.surface().set_emissive_color(playheadGradient);
        }
    }
}
