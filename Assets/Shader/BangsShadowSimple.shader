Shader "Unlit/BangsShadowSimple"
{
    Properties
    {
        _BaseColor("Shadow Color", Color) = (0,0,0,0.4)
        _Offset("Projection Offset", Float) = 0.006
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "RenderPipeline" = "UniversalPipeline" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off

        Pass
        {
            Name "BangsShadow"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseColor;
            float _Offset;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                // Get main light direction and offset vertex along it
                Light mainLight = GetMainLight();
                float3 lightDir = normalize(mainLight.direction);
                float3 worldPos = TransformObjectToWorld(IN.positionOS.xyz);
                worldPos += lightDir * _Offset;
                OUT.positionHCS = TransformWorldToHClip(worldPos);

                return OUT;
            }

            half4 frag() : SV_Target
            {
                Light mainLight = GetMainLight();
                half lightIntensity = max(0.001, dot(mainLight.color, half3(0.299, 0.587, 0.114)));

                half4 col = _BaseColor;
                // Tint shadow by light color
                col.rgb *= mainLight.color;
                // Fade out shadow when light intensity approaches zero
                col.a *= saturate(lightIntensity);
                return col;
            }
            ENDHLSL
        }
    }
}