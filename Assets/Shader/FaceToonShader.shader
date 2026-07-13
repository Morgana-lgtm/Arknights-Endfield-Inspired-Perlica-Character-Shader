Shader "Custom/FaceToonShader"
{
    Properties
    {
        _MainTex("Main Tex",2D)="white"{}
      
        _IsNeedNormalMap("Enable Normal", Float) = 1
        _BumpScale("Normal Strength", Float) = 1.0

        _ForwardDirStrength("View Lock CameraForward", Range(0,1)) = 0

        _DayStrength("日光直射强度",Range(0,1))=1
        _OtherLightResultStrength_day1("晴天环境光系数",Float)=0.2
        _OtherLightResultStrength_day0("阴天环境光系数",Float)=1.0

        _OtherLightColor("顶光颜色",Color)=(0.9,0.95,1,1)
        _OtherLightOffset("法线偏移",Float)=0
        _OtherLightStrength("顶光强度",Float)=0.3
        _OtherLightStrength_Offset("保底亮度",Float)=0.1

        _ShadowCenter("阴影分界",Float)=0.5
        _ShadowSmoothness("阴影软硬",Float)=0.02
        _ShadowOffset("阴影偏移",Float)=0
        _ShadowStrength("阴影压暗强度",Float)=1

        _AoStrength("AO强度",Float)=1

        _BaseColor("基础染色",Color)=(1,1,1,1)
        _BaseColorPow("固有色对比度",Range(1,2))=1

        _AlbedoDarkStrength("暗部亮度系数",Range(0.01,1))=0.8
        _AlbedoDarkSaturation("暗部饱和度",Range(0,1))=0.8

        _RampTex ("RampTex", 2D) = "white" {}

        _SpecularStrength("高光强度",Range(0,2)) = 1.0
        _DiffuseBlendEffect("SSS漫反射衰减",Range(0,1)) = 0.6

        _RimLightArea("轮廓光宽度", Range(0, 1)) = 0.3
        _RimLightColor("轮廓光颜色", Color) = (1,1,1,1)
        _RimLightStrength("轮廓光强度", Range(0,3)) = 0.8
        _RimLightDiffuseColorEffect("固有色融合强度", Range(0,1)) = 0.6

        // 面部方向（由外部脚本传入）
        _FaceForward("Face Forward", Vector) = (0,0,1,0)
        _FaceRight("Face Right", Vector) = (1,0,0,0)
        _FaceUp("Face Up", Vector) = (0,1,0,0)



        // SDF贴图
        _SdfTex("SDF魔法图", 2D) = "white" {}
        // sdf范围限制图（x=sss范围, y=脖子衔接mask, w=rim mask）
        _SdfRefineTex("SDF Refine图", 2D) = "white" {}

        // 表情贴图
        _TrickTex("表情贴图", 2D) = "white" {}
        _TrickType("表情类型", Range(0,3)) = 0
        _TrickStrength("表情强度", Range(0,1)) = 0



        // SSS
        _SSSColor("SSS颜色", Color) = (1,0.8,0.7,1)
        _SSSArea("SSS范围", Range(0,2)) = 1.0

        // 皮肤材质
        _Roughness("粗糙度", Range(0,1)) = 0.5
        _ReflectivityStrength("反射率", Range(0,1)) = 0.5
        _LutColorTex("皮肤LUT贴图", 2D) = "white" {}

        // 边缘光
        _RimMaskStrength("Rim Mask强度", Range(0,1)) = 0.5

        _MainLightColor_dark("主光暗部颜色", Color) = (1,1,1,1)
        _SelfAoShadowStrength("自AO阴影强度", Range(0,1)) = 1

    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

        CBUFFER_START(UnityPerMaterial)    

        float _BumpScale;
        float _IsNeedNormalMap;

        float _ForwardDirStrength;

        float _DayStrength;
        float _OtherLightResultStrength_day1;
        float _OtherLightResultStrength_day0;

        float _ShadowCenter;
        float _ShadowSmoothness;
        float _ShadowOffset;
        float _ShadowStrength;
        

        float3 _BaseColor;
        float _BaseColorPow;
        float _AlbedoDarkStrength;  
        float _OtherLightOffset;
        float _OtherLightStrength;
        float _OtherLightStrength_Offset;
        float4 _OtherLightColor;
        float _AoStrength;

        float _SpecularStrength;
        float _DiffuseBlendEffect;

        float _RimLightArea;
        float3 _RimLightColor;
        float _RimLightStrength;
        float _RimLightDiffuseColorEffect;


        float4 _FaceForward;
        float4 _FaceRight;
        float4 _FaceUp;
        float4 _SSSColor;
        float _SSSArea;
        float _Roughness;
        float _ReflectivityStrength;
        float _TrickType;
        float _TrickStrength;
        float _RimMaskStrength;

        float4 _MainLightColor_dark;
        float _SelfAoShadowStrength;
        float _AlbedoDarkSaturation;

        CBUFFER_END

        ENDHLSL

        Pass
        {
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ SCREEN_SPACE_SHADOWS

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            TEXTURE2D(_NormalTex);
            SAMPLER(sampler_NormalTex);

            TEXTURE2D(_RampTex);
            SAMPLER(sampler_RampTex);

            TEXTURE2D(_SdfTex);
            SAMPLER(sampler_SdfTex);
            TEXTURE2D(_SdfRefineTex);
            SAMPLER(sampler_SdfRefineTex);
            TEXTURE2D(_TrickTex);
            SAMPLER(sampler_TrickTex);
            TEXTURE2D(_LutColorTex);    
            SAMPLER(sampler_LutColorTex);


            // 自定义Sigmoid硬阴影函数
            float SigmoidSharp(float x, float center, float smoothness)
            {
                float t = (x - center) / max(smoothness, 1e-6);
                return 1.0 / (1.0 + exp(-t));
            }

            float3 linear2sRGB(float3 c)
            {
                return pow(max(c, 0), 1.0/2.2);
            }

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv0 : TEXCOORD0;
                float3 normalOS  : NORMAL;
                float4 tangentOS : TANGENT;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv0 : TEXCOORD0;
                float3 positionWS   : TEXCOORD1;
                float3 normalWS     : TEXCOORD2;
                float3 tangentWS:TEXCOORD3;
                float3 bitangentWS:TEXCOORD4;
                float4 shadowCoord : TEXCOORD5;
            };


            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.uv0 = IN.uv0;

                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                OUT.normalWS = normalInput.normalWS;
                OUT.tangentWS = normalInput.tangentWS;
                OUT.bitangentWS = normalInput.bitangentWS;
                OUT.shadowCoord =TransformWorldToShadowCoord(OUT.positionWS);

                return OUT;
            }

            half4 frag(Varyings i, bool isFrontFace : SV_IsFrontFace) : SV_Target
            {
                float4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv0);
                float4 normalTex = SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, i.uv0);
                float4 sdfRefineTex_var = SAMPLE_TEXTURE2D(_SdfRefineTex, sampler_SdfRefineTex, i.uv0);

                float3 albedo = mainTex.xyz * _BaseColor.xyz;

                // 表情贴图
                float emojiType = _TrickType * 0.5;
                float2 emojiUV = float2(frac(abs(emojiType)), floor(emojiType) * 0.5);
                float4 trickTex_var = SAMPLE_TEXTURE2D(_TrickTex, sampler_TrickTex, i.uv0 * 0.5 + emojiUV);
                albedo = lerp(albedo, trickTex_var.xyz, trickTex_var.w * _TrickStrength);

                // 光源
                Light mainLight = GetMainLight(i.shadowCoord);
                float3 mainLightDir = mainLight.direction;
                float3 mainLightDir_xz = normalize(float3(mainLightDir.x, 6.10351562e-05, mainLightDir.z));

                float3 mainLightColor = mainLight.color;
                float mainLightIntensity = max(0.001, dot(mainLightColor, float3(0.299, 0.587, 0.114)));
                mainLightColor = mainLightColor / mainLightIntensity;

                // view dir
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.positionWS.xyz);
                float3 cameraForward = normalize(UNITY_MATRIX_V[2].xyz);
                viewDir = normalize(lerp(viewDir, cameraForward, _ForwardDirStrength));

                float3 worldUp = float3(0, 1, 0);
                float3 cameraRight = normalize(cross(worldUp, cameraForward) + float3(1e-6, 0, 0));

                // normal
                float3x3 tangentTransform = float3x3(i.tangentWS, i.bitangentWS, i.normalWS);
                float3 normalTex_processed = UnpackNormalScale(normalTex, _BumpScale);
                float3 normalWS_model = lerp(i.normalWS, normalize(mul(normalTex_processed, tangentTransform)), _IsNeedNormalMap);
                float facing = isFrontFace ? 1.0 : -1.0;
                normalWS_model = normalWS_model * facing;

                // 相机朝脸方向
                float3 cameraForward_faceDir = normalize(float3(
                    dot(cameraForward, _FaceRight.xyz),
                    dot(cameraForward, _FaceUp.xyz),
                    dot(cameraForward, _FaceForward.xyz)));
                float headFDotCamerF = cameraForward_faceDir.z / max(1e-5, sqrt(dot(cameraForward_faceDir.xz, cameraForward_faceDir.xz)));

                // SSS
                float view_sssStrength = lerp(saturate(headFDotCamerF + 0.5), 1, sdfRefineTex_var.y) * sdfRefineTex_var.x;
                float NoV_sss = saturate(dot(normalWS_model, viewDir)) * 0.85 + 0.15;
                float sss_area = saturate(_SSSArea * view_sssStrength * (1.0 - NoV_sss));
                float3 sssColorEffect = lerp(float3(1,1,1), _SSSColor.rgb, sss_area);
                float3 albedo_sssRefine = albedo * sssColorEffect;

                // 材质属性
                float metallic = 0;
                float energyDistribution_metallic = 0.96;
                float3 mainDiffuseColor_Light = albedo_sssRefine * energyDistribution_metallic;
                float reflectivity = 0.04 * _ReflectivityStrength;
                float3 F0 = float3(1,1,1) * reflectivity;
                float roughness2 = max(0.0078125, _Roughness * _Roughness);

                // 暗部颜色（不用LUT）
                float3 baseColor_dark = albedo_sssRefine * _AlbedoDarkStrength;
                float baseColor_dark_strength = dot(baseColor_dark, float3(0.299, 0.587, 0.114));
                baseColor_dark = lerp(baseColor_dark_strength.xxx, baseColor_dark, _AlbedoDarkSaturation);
                float3 mainDiffuseColor_dark = baseColor_dark * energyDistribution_metallic;
                float3 mainDiffuseColor_darkindark = mainDiffuseColor_dark * 0.65;

                // SDF光照
                float3 mainLightDir_xz_faceDir = normalize(float3(
                    dot(mainLightDir, _FaceRight.xyz), 6.10351562e-05,
                    dot(mainLightDir, _FaceForward.xyz)));
                float sdf_uvFlag = step(0, mainLightDir_xz_faceDir.x);
                float sdf_u = sdf_uvFlag * (2 * i.uv0.x - 1) + 1 - i.uv0.x;
                float4 sdfTex_var = SAMPLE_TEXTURE2D(_SdfTex, sampler_SdfTex, float2(sdf_u, i.uv0.y));

                float faceNoL_compensation = -0.5 * mainLightDir_xz_faceDir.z * mainLightDir_xz_faceDir.z + 0.5;
                float2 cameraForward_xz = normalize(cameraForward.xz);
                float backLight = saturate(-dot(cameraForward_xz, mainLightDir_xz.xz)) * saturate(-mainLightDir_xz_faceDir.z);
                float faceNoL = mainLightDir_xz_faceDir.z + backLight * faceNoL_compensation;
                float halfFaceNoL = faceNoL * 0.5;
                faceNoL = saturate(-faceNoL * 0.5 + 0.5);

                float sdf_min = max(0, 2 * faceNoL - 1);
                float sdf_width = max(1e-5, min(1, 2 * faceNoL) - sdf_min);
                float sdf_smoothVar = saturate((0.5 * (sdfTex_var.x + sdfTex_var.y) - sdf_min) / sdf_width);
                float sdf_backLight = halfFaceNoL * ceil(halfFaceNoL);
                sdf_smoothVar = sdf_smoothVar * sdf_smoothVar * (3 - 2 * sdf_smoothVar);
                float sdf_NoL = abs(-sdf_smoothVar - sdf_backLight) * 2 - 1;

                // 脖子衔接
                float NoL_model = dot(normalWS_model, mainLightDir);
                float ramp_NoL = lerp(sdf_NoL, NoL_model, sdfRefineTex_var.y);
                float ramp_u = ramp_NoL * 0.5 + 0.5;
                float4 rampTex_var = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(ramp_u, 0.5));
                float3 rampColor = rampTex_var.xyz;
                float rampColor_max = max(max(rampColor.x, rampColor.y), rampColor.z);
                float rampColor_min = min(min(rampColor.x, rampColor.y), rampColor.z);
                float rampColor_xyzStrength = rampColor_max - rampColor_min;

                // 阴影
                float shadowAttenuation = mainLight.shadowAttenuation;
                float2 screenUV = GetNormalizedScreenSpaceUV(i.positionHCS.xy);
                float ssShadow = SAMPLE_TEXTURE2D(_ScreenSpaceShadowmapTexture, sampler_PointClamp, screenUV).x;
                shadowAttenuation = min(shadowAttenuation, ssShadow);
                float shadowScene = saturate((SigmoidSharp(shadowAttenuation, _ShadowCenter, _ShadowSmoothness) + _ShadowOffset) * _ShadowStrength);

                float ao = mainTex.w;
                ao = pow(ao, _AoStrength);
                float ao_shadow = ao * shadowScene;
                float min_shadowAoNoLEffect = min(min(ao, shadowScene), rampTex_var.w);

                // 顶光
                float otherLightNoL = 0;
                otherLightNoL = saturate(otherLightNoL + _OtherLightOffset);
                otherLightNoL = otherLightNoL * _OtherLightStrength + _OtherLightStrength_Offset;
                float3 otherLightColor = lerp(_OtherLightColor.rgb, float3(1,1,1), min_shadowAoNoLEffect);
                float3 otherLightResult = otherLightColor * otherLightNoL;
                float3 otherLightResult_day1 = otherLightResult * _OtherLightResultStrength_day1;
                float3 otherLightResult_day0 = otherLightResult * _OtherLightResultStrength_day0;

                // 主光颜色
                float mainLightColorStrength = dot(mainLightColor * _MainLightColor_dark.rgb, float3(0.299, 0.587, 0.114));
                float3 mainLightColor_new = lerp(mainLightColorStrength.xxx, mainLightColor, min_shadowAoNoLEffect) * mainLightIntensity;
                float3 mainLightColor_final = lerp(otherLightResult_day0, mainLightColor_new + otherLightResult_day1, _DayStrength);

                // 漫反射brdf
                float mainDiffuseColor_Light_Strength = dot(mainDiffuseColor_Light, float3(0.299, 0.587, 0.114));
                float mainDiffuseColor_Dark_Strength = dot(mainDiffuseColor_darkindark, float3(0.299, 0.587, 0.114));
                float3 mainDiffuseColor_Dark_final = lerp(mainDiffuseColor_Dark_Strength.xxx, mainDiffuseColor_darkindark, 1.2);
                float3 mainDiffuseColor_Dark_lerp = lerp(mainDiffuseColor_Dark_final, mainDiffuseColor_dark, saturate(ao_shadow + rampTex_var.w));
                float3 mainDiffuseBrdf = lerp(mainDiffuseColor_Dark_lerp, mainDiffuseColor_Light, min_shadowAoNoLEffect);

                float3 rampColor_xyzEffect = rampColor * rampColor_xyzStrength + 1 - rampColor_xyzStrength;
                float3 mainDiffuseBrdf_rampColor = mainDiffuseBrdf * rampColor_xyzEffect;
                float mainDiffuseBrdf_strength = dot(mainDiffuseBrdf, float3(0.299, 0.587, 0.114));
                float mainDiffuseBrdf_rampColor_strength = dot(mainDiffuseBrdf_rampColor, float3(0.299, 0.587, 0.114));
                float rampColor_control = clamp(mainDiffuseBrdf_strength / max(0.01, mainDiffuseBrdf_rampColor_strength), 0, 1.5);

                float3 mainDiffuseColor_Light_final = lerp(mainDiffuseColor_Light_Strength.xxx, mainDiffuseColor_Light, 1.2);
                float3 mainDiffuseBrdf_lowLight = lerp(mainDiffuseColor_dark, mainDiffuseColor_Light_final, ao_shadow);
                float3 mainDiffuseBrdf_final = lerp(mainDiffuseBrdf_lowLight, mainDiffuseBrdf_rampColor * rampColor_control, _DayStrength);
                float3 mainDiffuseResult = mainLightColor_final * mainDiffuseBrdf_final;

                // 高光
                float ao_shadow_lowLight = lerp(ao_shadow, min_shadowAoNoLEffect, _DayStrength);
                float selfAoShadowEffect = lerp(_SelfAoShadowStrength, 1, ao_shadow_lowLight);
                float forwardLightDir_y = lerp(0.5, mainLightDir.y, _DayStrength);
                float3 forwardLightDir = normalize(float3(cameraForward.x, forwardLightDir_y, cameraForward.z));
                float NoV = saturate(dot(normalWS_model, viewDir));
                float3 mainLightDir_new = mainLightDir * _DayStrength + 2 * forwardLightDir;
                float3 halfDir_new = normalize(viewDir * (2 + _DayStrength) + mainLightDir_new);
                float NoH = dot(normalWS_model, halfDir_new);
                float a2 = roughness2 * roughness2;
                float specular_D = a2 / max(1e-5, pow((NoH * a2 - NoH) * NoH + 1, 2));
                float specular_V = 0.5 / max(1e-5, NoV * 2 + roughness2);
                float specular_DV = clamp(specular_D * specular_V, 0, 20);
                float3 specular_brdf = specular_DV * F0;
                float3 specularLight = mainLightColor_final * selfAoShadowEffect * (ao_shadow_lowLight * 0.5 + 0.5);
                float3 mainLightResult = mainDiffuseResult + specularLight * specular_brdf * _SpecularStrength;

                // 边缘光
                float sdf_z = lerp(-(sdfTex_var.z * 2 - 1), sdfTex_var.z * 2 - 1, sdf_uvFlag);
                float3 sdfDir = normalize(float3(sdf_z, 6.10351562e-05, 1 - abs(sdf_z)));
                float3 faceSpace_x = float3(_FaceRight.x, _FaceUp.x, _FaceForward.x);
                float3 faceSpace_y = float3(_FaceRight.y, _FaceUp.y, _FaceForward.y);
                float3 faceSpace_z = float3(_FaceRight.z, _FaceUp.z, _FaceForward.z);
                float3 sdfNormal = normalize(float3(dot(faceSpace_x, sdfDir), dot(faceSpace_y, sdfDir), dot(faceSpace_z, sdfDir)));
                float3 rimNormalWS = lerp(sdfNormal, i.normalWS, sdfRefineTex_var.y);

                float rim_NoV = dot(rimNormalWS, viewDir);
                float headFDotCamerF_rim = saturate(-0.9 + headFDotCamerF * 10);
                headFDotCamerF_rim = headFDotCamerF_rim * headFDotCamerF_rim * (3 - 2 * headFDotCamerF_rim);
                float rimStart = _RimLightArea * -0.6 + 0.8;
                float rimEnd = _RimLightArea * -0.4 + 0.9;
                float rimt = saturate(((1.0 - rim_NoV) - rimStart) / max(rimEnd - rimStart, 1e-5));
                float rimArea = rimt * rimt * (3.0 - 2.0 * rimt);
                float rimArea_mask = sdfRefineTex_var.w;
                float rimArea_final = lerp(rimArea, rimArea_mask, _RimMaskStrength);
                float rimHalfArea = saturate(dot(cameraRight, rimNormalWS));
                float3 rimLight = rimArea_final * headFDotCamerF_rim * _RimLightColor.rgb * _RimLightStrength;
                float3 rimLight_effectd = rimLight * min(ao, shadowScene);
                float3 rimLight_brdf = (mainDiffuseColor_Light - 0.25) * _RimLightDiffuseColorEffect + 0.25;
                float3 rimLightResult = rimLight_brdf * rimLight_effectd * rimHalfArea;

                float3 resultColor = mainLightResult + max(rimLightResult, 0);
                return float4(resultColor, 1);

            }
            ENDHLSL
        }
    }
}