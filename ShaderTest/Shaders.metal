//
//  Shaders.metal
//  ShaderTest
//
//  Created by Yasuo Hasegawa on 2018/04/04.
//  Copyright © 2018年 Yasuo Hasegawa. All rights reserved.
//

// File for Metal kernel and shader functions

#include <metal_stdlib>
#include <simd/simd.h>

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "ShaderTypes.h"

using namespace metal;

typedef struct
{
    float3 position [[attribute(VertexAttributePosition)]];
    float2 texCoord [[attribute(VertexAttributeTexcoord)]];
} Vertex;

typedef struct
{
    float4 position [[position]];
    float2 texCoord;
} ColorInOut;

vertex ColorInOut vertexShader(Vertex in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]])
{
    ColorInOut out;

    float4 position = float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    //out.texCoord = in.texCoord;

    return out;
}

// http://glslsandbox.com/e#45949.16

float sdBox( float3 p, float3 dim )
{
    float3 d = abs(p) - dim;
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float map(float3 p)
{
    float3 q = fract(p) * 2.0 - 1.0;
    //return length(q) - 0.1;
    float3 boxDim = float3(.1,.5,.5); //vec3(0.2 + cv2 /3. ));
    return sdBox(q,  boxDim);
}

float trace(float3 o, float3 r)
{
    float t = 0.0;
    for (int i = 0; i < 32; ++i)
    {
        float3 p = o + r * t;
        float d = map(p);
        t += d * 0.5;
    }
    return t;
}

// multiply xz
float2x2 rotateX(float theta){
    return float2x2(cos(theta), -sin(theta), sin(theta), cos(theta));;
}

// multiply yz
float2x2 rotateY(float theta){
    return float2x2(cos(theta), -sin(theta), sin(theta), cos(theta)); ;
}

// multiply xy
float2x2 rotateZ(float theta){
    return float2x2(cos(theta), -sin(theta), sin(theta), cos(theta)); ;
}

fragment float4 fragmentShader(ColorInOut in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                               constant float2 &resolution [[buffer(0)]],
                               constant float  &time       [[buffer(1)]])
{
    float p_x = in.position.x / resolution.x;
    float p_y = in.position.y / resolution.x;
    float2 uv = float2(p_x, p_y);
    
    uv = uv * 2.0 - 1.0;
    
    uv.x *= resolution.x / resolution.y;
    
    float depth = 2.0;
    float3 r = normalize(float3(uv, depth));
    
    // This doesn't compile in Metal:
    // float4 x = float4(1);
    // x.xy *= float2x2(...);
    // with the error message "non-const reference cannot bind to vector element",
    // but switching it to x.xy = x.xy * float2x2(...) fixes it.
    bool enableRotation = true;
    if(enableRotation){
        r.xz = r.xz*rotateX(-4.75);
        r.yz = r.yz*rotateY(3.1);
    }
    
    float3 o = float3(0.0, 0.0, time);  // Movement (Translation) in 3d space
    
    float st = 1.;//(sin(time) + 1.5) * 0.4; // blur in and out
    
    float t = trace(o, r * st);
    
    float fog = 1./t ;
    
    float3 fc = float3(fog*2.);//( -cv0 ) + .5);  // glow intensity
    
    
    float3 tint = float3(0.8,0.8,0.8);//vec3(st *cv0 + sin(time/2.*PI)/2. + 0.5,st * cv1 + uv.y,st * cv1 + uv.x + sin(time/2.*PI)/2.+.25 ); // glow color
    
    return float4(fc * tint, 1.0);
}
