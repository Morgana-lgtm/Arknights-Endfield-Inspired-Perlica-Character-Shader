Shader "Custom/ToonBaseShader"
{
    Properties
    {
        _MainTex("Main Tex",2D)="white"{}
        _OrmTex("Orm Tex",2D)="white"{}
        _NormalTex("Normal Tex",2D)="white"{}
        _IsNeedOrmTex("Enable OrmTex",Float)=1
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

        [Toggle(_SSS_ON)] _IsNeedSss("启用SSS透光", Float) = 0
        _SssColor("SSS透光颜色", Color) = (0.8, 0.3, 0.3, 1)
        _SssPowStrength("SSS扩散强度", Range(0,5)) = 1

        _EnvMap("环境立方贴图", Cube) = "white" {}
        _EnvRotation("环境旋转角度", Float) = 0
        _EnvColor("环境高光色调", Color) = (1,1,1,1)
        _EnvLightStrength("IBL环境高光强度", Range(0, 3)) = 0.2

        _RimLightArea("轮廓光宽度", Range(0, 1)) = 0.3
        _RimLightColor("轮廓光颜色", Color) = (1,1,1,1)
        _RimLightStrength("轮廓光强度", Range(0,3)) = 0.8
        _RimLightDiffuseColorEffect("固有色融合强度", Range(0,1)) = 0.6
        _RimLightNoLxzStrength("主光侧勾边强度", Range(0, 2)) = 0.7

        [Toggle(_SPECULARREFINE_ON)] _SpecularRefine("启用高光细化", Float) = 0
        _SpecularRefineF0Tex("F0颜色映射图", 2D) = "white" {}
        _RefineF0U_lerp("F0 U轴混合", Range(0,1)) = 0
        _SpecularRefineColorTex("自发光贴图", 2D) = "black" {}
        _SpecularRefineColor("自发光颜色", Color) = (1,1,1,1)
        _SpecularRefineColorStrength("自发光强度", Range(0,1)) = 1
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex ZmdVert
            #pragma fragment frag
            #pragma multi_compile _ SCREEN_SPACE_SHADOWS
            #pragma shader_feature_local _SSS_ON
            #pragma shader_feature_local _SPECULARREFINE_ON

            #include "ZmdToonCore.hlsl"
            #include "ZmdToonLighting.hlsl"
            #include "ZmdToonSpecular.hlsl"

            TEXTURE2D(_MainTex);        SAMPLER(sampler_MainTex);
            TEXTURE2D(_OrmTex);         SAMPLER(sampler_OrmTex);
            TEXTURE2D(_NormalTex);      SAMPLER(sampler_NormalTex);
            TEXTURE2D(_RampTex);        SAMPLER(sampler_RampTex);
            TEXTURECUBE(_EnvMap);       SAMPLER(sampler_EnvMap);
            TEXTURE2D(_SpecularRefineF0Tex);
            TEXTURE2D(_SpecularRefineColorTex);

            half4 frag(Varyings i, bool isFrontFace : SV_IsFrontFace) : SV_Target
            {
                // Textures
                float4 mainTex   = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv0);
                float4 ormTex    = SAMPLE_TEXTURE2D(_OrmTex, sampler_OrmTex, i.uv0);
                float4 normalTex = SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, i.uv0);
                ormTex = lerp(float4(0,1,0,0), ormTex, _IsNeedOrmTex);

                // Normal
                float3x3 TBN = float3x3(i.tangentWS, i.bitangentWS, i.normalWS);
                float3 nTS   = UnpackNormalScale(normalTex, _BumpScale);
                float3 N     = lerp(i.normalWS, normalize(mul(nTS, TBN)), _IsNeedNormalMap);
                float facing = isFrontFace ? 1.0 : -1.0;
                N = N * facing;

                // View dir
                float3 viewDir  = normalize(_WorldSpaceCameraPos.xyz - i.positionWS.xyz);
                float3 camFwd   = normalize(UNITY_MATRIX_V[2].xyz);
                viewDir = normalize(lerp(viewDir, camFwd, _ForwardDirStrength));

                // Main light
                float3 L, Lxz, lightCol; float lightIntensity, NoL;
                ZmdGetMainLight(i, L, Lxz, lightCol, lightIntensity, NoL);

                // Other light + final light color
                float3 otherLight = ZmdGetOtherLight(N);
                float3 lightFinal = ZmdGetMainLightColorFinal(lightCol, otherLight);

                // Shadow
                float shadow = ZmdGetShadow(i, GetMainLight(i.shadowCoord).shadowAttenuation);

                // Material properties
                float rough    = 1.0 - ormTex.w;
                float rough2   = max(rough * rough, 0.0078);
                float metallic = ormTex.r;
                float reflec   = ormTex.g;
                float ao       = pow(ormTex.b, _AoStrength);

                // Base color
                float3 baseCol = mainTex.xyz * _BaseColor.xyz;
                baseCol = pow(baseCol, _BaseColorPow);

                // SSS (shader feature)
                #ifdef _SSS_ON
                float sssNoV = saturate(dot(N, viewDir));
                float sssA   = pow(1.05 - sssNoV, 1.0 + mainTex.w * _SssPowStrength);
                sssA = min(0.9, sssA) * step(mainTex.w, 0.99);
                baseCol = lerp(baseCol, _SssColor.xyz, lerp(0, sssA, _IsNeedSss));
                #endif

                // Dark color
                float3 darkCol  = baseCol * _AlbedoDarkStrength;
                float  darkLum  = Luminance(darkCol);
                darkCol = lerp(darkLum.xxx, darkCol, _AlbedoDarkSaturation);

                // Energy conservation
                float energyDist = 0.96 - 0.96 * metallic;
                float3 F0 = 0.04 * reflec.xxx + metallic * (baseCol - reflec.xxx * 0.04);

                // Back light + Ramp
                float  back     = ZmdGetBackLight(camFwd, Lxz);
                float  rampNoL  = ZmdGetRampNoL(NoL, back);
                float4 rampCol  = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(rampNoL, 0.5));
                float  rampNoF  = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(dot(N, camFwd) * 0.5 + 0.5, 0.5)).w;

                // Diffuse BRDF
                float3 diffLight, diffDark;
                float3 diffuse = ZmdGetDiffuseBRDF(baseCol, darkCol, metallic, ao, shadow, rampCol, rampNoF, energyDist, diffLight, diffDark);

                // Ramp color
                float3 diffRamp = ZmdApplyRampColor(diffuse, rampCol);

                // Day blend
                float  aoShaNoF  = ao * shadow * rampNoF;
                float  minShadow = min(min(ao, shadow), rampCol.w);
                float3 diffLow   = lerp(diffDark * 0.65, diffLight, aoShaNoF);
                diffRamp = lerp(diffLow, diffRamp, _DayStrength);
                float3 diffResult = lightFinal * diffRamp;

                // Specular
                float  aoShaLow   = lerp(aoShaNoF, minShadow, _DayStrength);
                float3 halfDir    = ZmdGetStylizedHalfDir(viewDir, camFwd, L);
                float  NoV        = saturate(dot(N, viewDir));
                float3 specBRDF   = ZmdGGX(N, halfDir, viewDir, rough2, F0);

                // Specular refine (shader feature)
                #ifdef _SPECULARREFINE_ON
                float  frU = lerp((rough2 * rough2 / max(1e-5, pow((dot(N, halfDir) * rough2 * rough2 - dot(N, halfDir)) * dot(N, halfDir) + 1, 2))) * rough2, NoV * NoV, _RefineF0U_lerp);
                float  frV = rough * (1.0 - ao);
                float4 frTex = SAMPLE_TEXTURE2D(_SpecularRefineF0Tex, sampler_MainTex, float2(frU, frV));
                F0 *= frTex.xyz;
                #endif

                float3 specLight = lightFinal * (aoShaLow * 0.5 + 0.5);
                float3 specResult = specLight * specBRDF * _SpecularStrength;

                // Blend
                float  sssBlend = 1.0 - _DiffuseBlendEffect * (1.0 - mainTex.w);
                float3 mainLightResult = diffResult * sssBlend + specResult;

                // Specular refine emission (shader feature)
                #ifdef _SPECULARREFINE_ON
                float4 emitTex = SAMPLE_TEXTURE2D(_SpecularRefineColorTex, sampler_MainTex, i.uv0);
                mainLightResult += emitTex.xyz * _SpecularRefineColor.xyz * _SpecularRefineColorStrength * sssBlend;
                #endif

                // IBL Specular
                float3 iblSpec = ZmdIBLSpecular(rough2, NoV, F0);
                float3 reflDir  = reflect(-viewDir, N);
                reflDir.x = -reflDir.x;
                reflDir.z = -reflDir.z;
                float  angle   = _EnvRotation * 0.0174532925;
                float  s, c;
                sincos(angle, s, c);
                float3 rotDir;
                rotDir.x = reflDir.x * c - reflDir.z * s;
                rotDir.y = reflDir.y;
                rotDir.z = reflDir.x * s + reflDir.z * c;
                float  envLevel = log2(max(0.01, rough));
                envLevel = envLevel * 1.2 + 5.0;
                float3 envColor = GlossyEnvironmentReflection(rotDir, i.positionWS, rough, 1.0) * _EnvColor;
                float3 iblResult = envColor * iblSpec * _EnvLightStrength;

                // Rim
                float3 rimFresnel = ZmdFresnelRim(NoV, diffLight, ao);
                float3 rimLxz     = ZmdNoLxzRim(N, Lxz, NoV, lightCol, lightIntensity, diffLight, ao);
                float3 rimResult  = rimFresnel + rimLxz;

                return float4(mainLightResult + iblResult + max(rimResult, 0), 1);
            }
            ENDHLSL
        }
    }
}