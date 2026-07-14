#ifndef ZMD_TOON_CORE
#define ZMD_TOON_CORE

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

// ── Unified Material Properties (all shaders share one CBUFFER) ──
CBUFFER_START(UnityPerMaterial)
    float _IsNeedOrmTex, _BumpScale, _IsNeedNormalMap, _ForwardDirStrength;
    float _DayStrength, _OtherLightResultStrength_day1, _OtherLightResultStrength_day0;
    float _ShadowCenter, _ShadowSmoothness, _ShadowOffset, _ShadowStrength;
    float3 _BaseColor; float _BaseColorPow, _AlbedoDarkStrength, _AlbedoDarkSaturation;
    float _OtherLightOffset, _OtherLightStrength, _OtherLightStrength_Offset;
    float4 _OtherLightColor; float3 _OtherLightDir; float _AoStrength;
    float _SpecularStrength, _DiffuseBlendEffect;
    float _RimLightArea; float3 _RimLightColor; float _RimLightStrength;
    float _RimLightDiffuseColorEffect, _RimLightNoLxzStrength;
    // ToonBase
    float _EnvRotation; float3 _EnvColor; float _EnvLightStrength;
    float _IsNeedSss; float4 _SSSColor; float _SssPowStrength;
    float _RefineF0U_lerp; float4 _SpecularRefineColor; float _SpecularRefineColorStrength;
    // Hair
    float4 _FaceCenter; float _SpecularTrick_Flatten, _ViewDirYOffset;
    float _SpecularPowStrength, _LutVPowStrength;
    float4 _SpecularBackF0; float _SpecularBackF0_ToHPowStrength;
    float _SelfAoShadowStrength, _BiNormalOffset_specularLut;
    float _OutlineWidth, _ZBias; float4 _OutlineColor; float _OutLineStrength, _ZMinRefine;
    // Skin / Face
    float _SSSArea, _Roughness, _ReflectivityStrength;
    // Face
    float _TrickType, _TrickStrength, _RimMaskStrength;
    float4 _MainLightColor_dark;
    // Eye
    float _CorneaBumpStrength; float3 _SpecularTrickColor, _EyeInTrickColor;
    float4 _SpecularColor;
CBUFFER_END

// Face direction — set by FaceDirSetter via Shader.SetGlobalVector
float4 _ZmdFF, _ZmdFR, _ZmdFU;

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

#endif // ZMD_TOON_CORE
