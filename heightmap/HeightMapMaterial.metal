//
//  HeigthMapMaterial.metal
//  AudioRelief
//
//  Created by Shuntaro Kasatani on 2026/02/26.
//

#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
using namespace metal;

[[visible]]
void heightMapShader(realitykit::surface_parameters params) {
    const float MAX_THICKNESS = 0.25;
    const float SIZE_Y = 1.0;
    const float BRUSH_BORDER_THICKNESS = 0.02;
    
    float2 clickPos = params.uniforms().custom_parameter().xy;
    float radius = params.uniforms().custom_parameter().z;
    float playhead = params.uniforms().custom_parameter().a;
    float height = params.geometry().model_position().y;

    // Calculate the color based on the height
    float normalizedHeight = saturate(height / MAX_THICKNESS);
    
    half3 highColor = half3(0.2, 0.2, 0.2);
    half3 lowColor = half3(1.0, 1.0, 1.0);
    half3 finalColor = mix(lowColor, highColor, normalizedHeight);

    params.surface().set_base_color(finalColor);
    
    // Adjust roughness & metalic
    params.surface().set_roughness(0.8);
    params.surface().set_metallic(0.0);
    
    // Calculate the distance to the cursor and highlight around it
    float2 currentPos = params.geometry().model_position().xz;
    float dist = distance(currentPos, clickPos);
    
    half3 selectionColor = half3(0.25, 0.75, 1.0);
    half3 emissiveColor = half3(0.0, 0.0, 0.0);
    if (dist < radius - BRUSH_BORDER_THICKNESS) {
        emissiveColor += selectionColor;
    } else if (dist < radius) {
        emissiveColor += selectionColor * 2;
    }
    
    // Highlight the playhead
    if (playhead > 0) {
        float playheadY = playhead - SIZE_Y / 2;
        if (currentPos.y < playheadY) {
            float playheadDist = min((playheadY - currentPos.y) * 2.0, 1.0);
            half3 playheadGradient = mix(selectionColor, half3(0.0, 0.0, 0.0), playheadDist);
            emissiveColor += playheadGradient;
        }
    }
    
    // Apply the emissive color
    params.surface().set_emissive_color(emissiveColor);
}
