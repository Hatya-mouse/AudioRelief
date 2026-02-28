//
//  HeightMap.metal
//  AudioRelief
//
//  Created by Shuntaro Kasatani on 2026/02/25.
//

#include <metal_stdlib>
#include "SculptureParams.h"
using namespace metal;

float remap(float x, float2 rangeA, float2 rangeB) {
    return rangeB.x + (x - rangeA.x) * (rangeB.y - rangeB.x) / (rangeA.y - rangeA.x);
}

float3 computeNormal(device float* heightData, uint2 coords, float2 size, uint2 dims) {
    float cellSize = size.x / (dims.x - 1);

    // Get the heights of four pixels around the vertex
    float leftHeight = heightData[max(int(coords.x) - 1, 0) + dims.x * coords.y];
    float upHeight = heightData[coords.x + dims.x * max(int(coords.y) - 1, 0)];
    float rightHeight = heightData[min(coords.x + 1, dims.x - 1) + dims.x * coords.y];
    float downHeight = heightData[coords.x + dims.x *  min(coords.y + 1, dims.y - 1)];
    
    // Calculate the direction
    float3 directionVector = float3(leftHeight - rightHeight, cellSize * 2, upHeight - downHeight);
    return normalize(directionVector);
}

float smoothBrush(float distance, float radius, float strength) {
    return (cos(clamp(distance / radius, 0.0, 1.0) * M_PI_F) + 1) * strength;
}

float sharpBrush(float distance, float radius, float strength) {
    return (1 - clamp(distance / radius, 0.0, 1.0)) * strength;
}

float squareBrush(float distance, float radius, float strength) {
    float delta = 0.1;
    return smoothstep(1.0, 1.0 - delta, distance / radius) * strength;
}

[[kernel]]
void sculptSurface(constant SculptureParams &params [[buffer(0)]],
                   device float* heightMap [[buffer(1)]],
                   uint2 pixelCoords [[thread_position_in_grid]]) {
    if (any(pixelCoords >= params.dimensions)) { return; }
    uint pixelIndex = pixelCoords.x + params.dimensions.x * pixelCoords.y;
    
    float heightMapData = heightMap[pixelIndex];
    float2 currentPosition = float2(remap(pixelCoords.x, float2(0, params.dimensions.x - 1), float2(-params.size.x / 2, params.size.x / 2)),
                                    remap(pixelCoords.y, float2(0, params.dimensions.y - 1), float2(-params.size.y / 2, params.size.y / 2)));
    
    float distance = length(currentPosition - params.position);
    float sculptureAmount = 0.0;
    if (params.brush == 0) {
        // 0: Smooth brush
        sculptureAmount = smoothBrush(distance, params.radius, params.strength);
    } else if (params.brush == 1) {
        // 1: Sharp (triangle) brush
        sculptureAmount = sharpBrush(distance, params.radius, params.strength);
    } else if (params.brush == 2) {
        // 2: Square brush
        sculptureAmount = squareBrush(distance, params.radius, params.strength);
    }
    heightMapData = saturate(heightMapData + sculptureAmount);
    
    heightMap[pixelIndex] = heightMapData;
}

[[kernel]]
void setVertexData(constant MeshParams &params [[buffer(0)]],
                   device PlaneVertex *vertices [[buffer(1)]],
                   device float* heightMap [[buffer(2)]],
                   uint2 vertexCoords [[thread_position_in_grid]]) {
    if (any(vertexCoords >= params.dimensions)) { return; }
    
    // Calculate the index and get the vertex
    uint vertexIndex = vertexCoords.x + params.dimensions.x * vertexCoords.y;
    device PlaneVertex &vert = vertices[vertexIndex];
    
    // Get the x, z position
    float2 vertexCoords01 = float2(vertexCoords) / float2(params.dimensions - 1);
    float2 xzPosition = params.size * vertexCoords01 - params.size / 2;
    
    // Calculate the y position
    float heightMapData = heightMap[vertexIndex];
    float height = heightMapData * params.maxThickness;
    float yPosition = clamp(height, 0.0, params.maxThickness);
    
    // Calculate the normal
    float3 normal = computeNormal(heightMap, vertexCoords, params.size, params.dimensions);
    
    vert.position = float3(xzPosition.x, yPosition, xzPosition.y);
    vert.normal = normal;
}
