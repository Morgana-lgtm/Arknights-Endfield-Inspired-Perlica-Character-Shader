#ifndef ZMD_TOON_CORE
#define ZMD_TOON_CORE

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

// ── Structures ──────────────────────────────────────────
struct Attributes
{
    float4 positionOS : POSITION;
    float2 uv0        : TEXCOORD0;
    float3 normalOS   : NORMAL;
    float4 tangentOS  : TANGENT;
};

struct Varyings
{
    float4 positionHCS   : SV_POSITION;
    float2 uv0           : TEXCOORD0;
    float3 positionWS    : TEXCOORD1;
    float3 normalWS      : TEXCOORD2;
    float3 tangentWS     : TEXCOORD3;
    float3 bitangentWS   : TEXCOORD4;
    float4 shadowCoord   : TEXCOORD5;
};

// ── Vertex Shader ───────────────────────────────────────
Varyings ZmdVert(Attributes IN)
{
    Varyings OUT;
    OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
    OUT.positionWS  = TransformObjectToWorld(IN.positionOS.xyz);
    OUT.uv0         = IN.uv0;

    VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
    OUT.normalWS    = normalInput.normalWS;
    OUT.tangentWS   = normalInput.tangentWS;
    OUT.bitangentWS = normalInput.bitangentWS;
    OUT.shadowCoord = TransformWorldToShadowCoord(OUT.positionWS);
    return OUT;
}

// ── Utility Functions ───────────────────────────────────
float SigmoidSharp(float x, float center, float smoothness)
{
    float t = (x - center) / max(smoothness, 1e-6);
    return 1.0 / (1.0 + exp(-t));
}

float3 LinearToSRGB_approx(float3 c) { return pow(max(c, 0), 1.0 / 2.2); }
float3 SRGBToLinear_approx(float3 c) { return pow(max(c, 0), 2.2); }

float Luminance(float3 c) { return dot(c, float3(0.299, 0.587, 0.114)); }

#endif // ZMD_TOON_CORE
