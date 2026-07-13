Shader "Hidden/ZmdBloom"
{
    Properties
    {
        _BloomThreshold ("Bloom Threshold", Range(0, 5)) = 1.0
        _BloomIntensity ("Bloom Intensity", Range(0, 5)) = 1.0
        _BloomScatter ("Bloom Scatter", Range(0, 1)) = 0.7
        _BloomTint ("Bloom Tint", Color) = (1, 1, 1, 1)
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }

        Pass { // 0: Prefilter
            Name "BloomPrefilter"
            Cull Off  ZWrite Off  ZTest Always
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            float _BloomThreshold, _BloomIntensity, _BloomScatter; float3 _BloomTint;
            half4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                float4 col = SAMPLE_TEXTURE2D_X_LOD(_BlitTexture, sampler_LinearClamp, input.texcoord, 0);
                float b = max(col.r, max(col.g, col.b));
                float c = max(0, b - _BloomThreshold) / max(b, 0.001);
                col.rgb *= c * _BloomIntensity;
                return col;
            }
            ENDHLSL
        }

        Pass { // 1: BlurH
            Name "BloomBlurH"
            Cull Off  ZWrite Off  ZTest Always
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            float _BloomThreshold, _BloomIntensity, _BloomScatter; float3 _BloomTint;
            half4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                float w,h; _BlitTexture.GetDimensions(w,h);
                float2 ts = float2(1.0/w, 1.0/h);
                float3 r = 0;
                float wg[5]={0.227027,0.1945946,0.1216216,0.054054,0.016216};
                float2 o[5]={float2(0,0),float2(1.3846,0),float2(3.2308,0),float2(5.0769,0),float2(6.9231,0)};
                for(int i=0;i<5;i++){
                    r+=SAMPLE_TEXTURE2D_X_LOD(_BlitTexture,sampler_LinearClamp,input.texcoord+o[i]*ts,0).rgb*wg[i];
                    r+=SAMPLE_TEXTURE2D_X_LOD(_BlitTexture,sampler_LinearClamp,input.texcoord-o[i]*ts,0).rgb*wg[i];
                }
                return half4(r,1);
            }
            ENDHLSL
        }

        Pass { // 2: BlurV
            Name "BloomBlurV"
            Cull Off  ZWrite Off  ZTest Always
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            float _BloomThreshold, _BloomIntensity, _BloomScatter; float3 _BloomTint;
            half4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                float w,h; _BlitTexture.GetDimensions(w,h);
                float2 ts = float2(1.0/w, 1.0/h);
                float3 r = 0;
                float wg[5]={0.227027,0.1945946,0.1216216,0.054054,0.016216};
                float2 o[5]={float2(0,0),float2(0,1.3846),float2(0,3.2308),float2(0,5.0769),float2(0,6.9231)};
                for(int i=0;i<5;i++){
                    r+=SAMPLE_TEXTURE2D_X_LOD(_BlitTexture,sampler_LinearClamp,input.texcoord+o[i]*ts,0).rgb*wg[i];
                    r+=SAMPLE_TEXTURE2D_X_LOD(_BlitTexture,sampler_LinearClamp,input.texcoord-o[i]*ts,0).rgb*wg[i];
                }
                return half4(r,1);
            }
            ENDHLSL
        }

        Pass { // 3: Composite
            Name "BloomComposite"
            Cull Off  ZWrite Off  ZTest Always
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            float _BloomThreshold, _BloomIntensity, _BloomScatter; float3 _BloomTint;
            TEXTURE2D(_BloomTex); SAMPLER(sampler_BloomTex);
            half4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                float4 scene = SAMPLE_TEXTURE2D_X_LOD(_BlitTexture, sampler_LinearClamp, input.texcoord, 0);
                float4 bloom = SAMPLE_TEXTURE2D(_BloomTex, sampler_BloomTex, input.texcoord);
                bloom.rgb *= _BloomTint * _BloomScatter;
                scene.rgb += bloom.rgb;
                return scene;
            }
            ENDHLSL
        }
    }
}