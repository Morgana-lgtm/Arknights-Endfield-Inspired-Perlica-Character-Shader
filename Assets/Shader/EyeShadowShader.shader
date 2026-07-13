Shader "Custom/EyeShadow"
{
    Properties
    {
        _MainTex ("AlphaTexture", 2D) = "white" {}
        [HDR]_Color("EyeDarkColor", color) = (1,1,1,1)
        _Alpha("Alpha", range(0, 2)) = 1.0
        [Header(Blend Mode)]
        [Enum(UnityEngine.Rendering.BlendMode)]
        _BlendSrc("Blend src", int) = 5
        [Enum(UnityEngine.Rendering.BlendMode)]
        _BlendDst("Blend dst", int) = 1
        [Enum(UnityEngine.Rendering.BlendOp)]
        _BlendOp("BlendOp", int) = 21
        [Enum(Off, 0, On, 1)]
        _ZWrite ("ZWrite", float) = 0
    }
    SubShader
    {
        Tags {"RenderType" = "Transparent"  "Queue" = "Transparent" "RenderPipeline" = "UniversalPipeline"}
        LOD 100

        Pass
        {
            Name "CharacterTransparent"
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            BlendOp [_BlendOp]
            Blend [_BlendSrc] [_BlendDst]
            ZWrite [_ZWrite]

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            float4 _Color;
            float _Alpha;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

           half4 frag (v2f i) : SV_Target
            {
                float alphaTex_var = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).r;
                alphaTex_var = 1.0 - alphaTex_var;

                Light mainLight = GetMainLight();
                // 用RGB亮度代替a通道，解决不存在.a的问题
                half lightLuminance = dot(mainLight.color.rgb, half3(0.22, 0.707, 0.071));
                half lightStrength = saturate(lightLuminance);

                half3 colBase = half3(_Color.rgb);
                half3 shadowCol = colBase * mainLight.color.rgb;

                half3 color = lerp(half3(1,1,1), shadowCol, alphaTex_var * _Alpha);
                color = lerp(half3(1,1,1), color, lightStrength);
                half finalAlpha = lerp(0.0h, _Alpha * alphaTex_var, lightStrength);

                return half4(color, finalAlpha);
            }
            ENDHLSL
        }
    }
}