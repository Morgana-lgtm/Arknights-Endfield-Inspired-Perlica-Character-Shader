Shader "Custom/Outlineshader"
{
    Properties
    {
        _OutlineWidth("√Ë±ﬂøÌ∂»", Range(0, 10)) = 1.0
        _ZBias("…Ó∂»∆´“∆", Range(0, 0.01)) = 0.001
        _OutlineColor("√Ë±ﬂ—’…´", Color) = (0.1, 0.1, 0.1, 1)
        _OutLineStrength("√Ë±ﬂ«ø∂»", Range(0, 2)) = 1
        _ZMinRefine("‘∂æ‡¿Î√Ë±ﬂ ’’≠œµ ˝", Range(0, 1)) = 0.4
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Name "Outline"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            Cull Front
            ZWrite On

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    
            CBUFFER_START(UnityPerMaterial)   
            float _OutlineWidth;
            float _ZBias;
            float4 _OutlineColor;
            float _OutLineStrength;
            float _ZMinRefine;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv0 : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
            };

            Varyings vert(Attributes v)
            {
                Varyings o;

                float3 biTangentOS = cross(v.normalOS, v.tangentOS.xyz) * v.tangentOS.w;

                float weightN = sqrt(saturate(1.0 - dot(v.uv1.xy, v.uv1.xy)));
                float3 smoothNormalOS = v.uv1.x * v.tangentOS.xyz + v.uv1.y * biTangentOS + weightN * v.normalOS;

                o.positionHCS = TransformObjectToHClip(v.positionOS.xyz);
                o.positionWS = TransformObjectToWorld(v.positionOS.xyz);
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);

                float3 smoothNormalVS = mul((float3x3)UNITY_MATRIX_IT_MV, smoothNormalOS);
                float2 clipNormal2D = mul((float2x3)UNITY_MATRIX_P, smoothNormalVS);
                float2 normal2D = normalize(clipNormal2D);

                float ScaleX = _ScreenParams.y / _ScreenParams.x;
                normal2D.x /= ScaleX;

                float depthScale = o.positionHCS.w;
                float outlineDepthClamp = min(depthScale, 20.0);
                float depthRefine = lerp(1, _ZMinRefine, smoothstep(1, 12, depthScale));

                float2 offset = normal2D * (_OutlineWidth * outlineDepthClamp * 0.01 * depthRefine);
                o.positionHCS.xy += offset * o.positionHCS.w;
                o.positionHCS.z -= _ZBias;

                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                Light mainLight = GetMainLight();
                float3 mainLightDir = mainLight.direction;
                float NoL = saturate(dot(i.normalWS, mainLightDir) * 0.5 + 0.5);
                float3 finalColor = _OutlineColor.rgb * lerp(0.7, 1.0, NoL) * _OutLineStrength;
                return float4(finalColor, 1);
            }
            ENDHLSL
        }
    }
}
