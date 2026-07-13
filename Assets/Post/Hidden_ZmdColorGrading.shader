Shader "Hidden/ZmdColorGrading"
{
    Properties
    {
        _Intensity ("Intensity", Range(0,1)) = 1
        _Exposure ("Exposure", Float) = 0
        _Contrast ("Contrast", Float) = 1
        _Saturation ("Saturation", Float) = 1
        _Gamma ("Gamma", Float) = 1
        _LutTex ("LUT Texture", 2D) = "white" {}
        _LutContribution ("LUT Contribution", Range(0,1)) = 0
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" }
        Pass
        {
            Name "ColorGrading"
            Cull Off  ZWrite Off  ZTest Always
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            float _Intensity, _Exposure, _Contrast, _Saturation, _Gamma;
            TEXTURE2D(_LutTex); SAMPLER(sampler_LutTex);
            float _LutContribution;

            float3 ApplyLut(float3 color)
            {
                float3 c = pow(max(color, 0), 1.0 / 2.2);
                const float N = 32.0;
                float3 lc = c * (N - 1.0);
                float3 fl = floor(lc), fr = frac(lc);
                float tx = fl.b;
                float2 it = (fl.rg + fr.rg) / N;
                float2 u0 = float2((tx + it.x) / N, it.y);
                float2 u1 = float2((tx + 1.0 + it.x) / N, it.y);
                float3 s0 = SAMPLE_TEXTURE2D_LOD(_LutTex, sampler_LutTex, saturate(u0), 0).rgb;
                float3 s1 = SAMPLE_TEXTURE2D_LOD(_LutTex, sampler_LutTex, saturate(u1), 0).rgb;
                return lerp(color, pow(max(lerp(s0, s1, fr.b), 0), 2.2), _LutContribution);
            }

            float3 ApplyBase(float3 c)
            {
                c *= exp2(_Exposure);
                c = (c - 0.5) * _Contrast + 0.5;
                float g = dot(c, float3(0.2126,0.7152,0.0722));
                c = lerp(g.xxx, c, _Saturation);
                c = pow(saturate(c), 1.0 / max(0.001, _Gamma));
                return c;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                float4 col = SAMPLE_TEXTURE2D_X_LOD(_BlitTexture, sampler_LinearClamp, input.texcoord, 0);
                float3 grading = ApplyBase(col.rgb);
                col.rgb = lerp(col.rgb, grading, _Intensity);
                col.rgb = ApplyLut(col.rgb);
                return col;
            }
            ENDHLSL
        }
    }
}