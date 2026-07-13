Shader "Custom/SkinToonShader"
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

        _RimLightArea("轮廓光宽度", Range(0, 1)) = 0.3
        _RimLightColor("轮廓光颜色", Color) = (1,1,1,1)
        _RimLightStrength("轮廓光强度", Range(0,3)) = 0.8
        _RimLightDiffuseColorEffect("固有色融合强度", Range(0,1)) = 0.6
        _RimLightNoLxzStrength("主光侧勾边强度", Range(0, 2)) = 0.7

        _SSSColor("SSS透光颜色", Color) = (1.0, 0.8, 0.7, 1)
        _SSSArea("SSS范围", Range(0,2)) = 1.0
        _Roughness("粗糙度", Range(0,1)) = 0.5
        _ReflectivityStrength("反射率", Range(0,1)) = 0.5
        _LutColorTex("皮肤LUT贴图", 2D) = "white" {}
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

            #include "ZmdToonCore.hlsl"
            #include "ZmdToonLighting.hlsl"
            #include "ZmdToonSpecular.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float _IsNeedOrmTex, _BumpScale, _IsNeedNormalMap, _ForwardDirStrength;
                float _DayStrength, _OtherLightResultStrength_day1, _OtherLightResultStrength_day0;
                float _ShadowCenter, _ShadowSmoothness, _ShadowOffset, _ShadowStrength;
                float3 _BaseColor; float _BaseColorPow, _AlbedoDarkStrength, _AlbedoDarkSaturation;
                float _OtherLightOffset, _OtherLightStrength, _OtherLightStrength_Offset;
                float4 _OtherLightColor; float _AoStrength;
                float _SpecularStrength, _DiffuseBlendEffect;
                float _RimLightArea; float3 _RimLightColor; float _RimLightStrength;
                float _RimLightDiffuseColorEffect, _RimLightNoLxzStrength;
                float4 _SSSColor; float _SSSArea, _Roughness, _ReflectivityStrength;
            CBUFFER_END

            TEXTURE2D(_MainTex);     SAMPLER(sampler_MainTex);
            TEXTURE2D(_OrmTex);      SAMPLER(sampler_OrmTex);
            TEXTURE2D(_NormalTex);   SAMPLER(sampler_NormalTex);
            TEXTURE2D(_RampTex);     SAMPLER(sampler_RampTex);
            TEXTURE2D(_LutColorTex); SAMPLER(sampler_LutColorTex);

            half4 frag(Varyings i, bool isFrontFace : SV_IsFrontFace) : SV_Target
            {
                float4 mainTex   = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv0);
                float4 ormTex    = SAMPLE_TEXTURE2D(_OrmTex, sampler_OrmTex, i.uv0);
                float4 normalTex = SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, i.uv0);
                ormTex = lerp(float4(0,1,0,0), ormTex, _IsNeedOrmTex);

                float3x3 TBN = float3x3(i.tangentWS, i.bitangentWS, i.normalWS);
                float3 nTS   = UnpackNormalScale(normalTex, _BumpScale);
                float3 N     = lerp(i.normalWS, normalize(mul(nTS, TBN)), _IsNeedNormalMap);
                float facing = isFrontFace ? 1.0 : -1.0;
                N = N * facing;

                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.positionWS.xyz);
                float3 camFwd  = normalize(UNITY_MATRIX_V[2].xyz);
                viewDir = normalize(lerp(viewDir, camFwd, _ForwardDirStrength));

                // Main light
                float3 L, Lxz, lightCol; float lightIntensity, NoL;
                ZmdGetMainLight(i, L, Lxz, lightCol, lightIntensity, NoL);
                float3 otherLight = ZmdGetOtherLight(N);
                float3 lightFinal = ZmdGetMainLightColorFinal(lightCol, otherLight);

                // Skin: shadow disabled (skin uses SSS instead)
                float shadow = 1.0;

                // Skin material (metallic=0, fixed roughness/reflectivity)
                float metallic = 0.0;
                float energyDist = 0.96;
                float reflec  = 0.04 * _ReflectivityStrength;
                float3 F0     = float3(1,1,1) * reflec;
                float  rough2 = max(0.0078125, _Roughness * _Roughness);
                float  ao     = pow(ormTex.b, _AoStrength);

                // SSS
                float NoV_raw = dot(N, viewDir);
                float sssNoV  = saturate(NoV_raw) * 0.85 + 0.15;
                float sssA    = saturate(_SSSArea * (1.0 - sssNoV));
                float3 sssEff = lerp(float3(1,1,1), _SSSColor.rgb, sssA);
                float3 baseCol = mainTex.xyz * _BaseColor.xyz * sssEff;
                baseCol = pow(baseCol, _BaseColorPow);

                // Dark color from LUT
                float3 albedoSrgb = LinearToSRGB_approx(mainTex.brg);
                float  lutIdx     = albedoSrgb.r * 31.0;
                float  lutFloor   = floor(lutIdx);
                float  lutLerp    = lutIdx - lutFloor;
                float2 lutBase    = albedoSrgb.gb * float2(0.0302734375, 0.96875) + float2(0.00048828125, 0.015625);
                float  lutX       = lutFloor * 0.03125 + lutBase.x;
                float2 uv0        = float2(clamp(lutX, 0.0, 0.96875), lutBase.y);
                float2 uv1        = float2(min(uv0.x + 0.03125, 0.999), uv0.y);
                float3 lut1       = SAMPLE_TEXTURE2D(_LutColorTex, sampler_LutColorTex, saturate(uv0)).rgb;
                float3 lut2       = SAMPLE_TEXTURE2D(_LutColorTex, sampler_LutColorTex, saturate(uv1)).rgb;
                float3 lutRefined = lerp(lut1, lut2, lutLerp);

                float3 darkCol = lutRefined * energyDist * _AlbedoDarkStrength;
                float3 diffLight, diffDark;
                diffLight = baseCol * energyDist;
                diffDark  = darkCol;
                float3 diffDarkAttn = diffDark * 0.65;

                // Ramp + Diffuse
                float  back    = ZmdGetBackLight(camFwd, Lxz);
                float  rampNoL = ZmdGetRampNoL(NoL, back);
                float4 rampCol = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(rampNoL, 0.5));
                float  rampNoF = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(dot(N, camFwd) * 0.5 + 0.5, 0.5)).w;

                float  aoShaNoF  = ao * shadow * rampNoF;
                float  minShadow = min(min(ao, shadow), rampCol.w);

                float3 darkLerp  = lerp(diffDarkAttn, diffDark, saturate(aoShaNoF + rampCol.w));
                float3 diffuse    = lerp(darkLerp, diffLight, minShadow);
                float3 diffRamp   = ZmdApplyRampColor(diffuse, rampCol);
                float3 diffLow    = lerp(diffDarkAttn, diffLight, aoShaNoF);
                diffRamp = lerp(diffLow, diffRamp, _DayStrength);
                float3 diffResult = lightFinal * diffRamp;

                // Specular
                float  aoShaLow  = lerp(aoShaNoF, minShadow, _DayStrength);
                float3 halfDir   = ZmdGetStylizedHalfDir(viewDir, camFwd, L);
                float  NoV       = saturate(dot(N, viewDir));
                float3 specBRDF  = ZmdGGX(N, halfDir, viewDir, rough2, F0);
                float3 specLight = lightFinal * (aoShaLow * 0.5 + 0.5);
                float3 specResult = specLight * specBRDF * _SpecularStrength;

                float  sssBlend = 1.0 - _DiffuseBlendEffect * (1.0 - mainTex.w);
                float3 mainResult = diffResult * sssBlend + specResult;

                // Rim
                float3 rimFresnel = ZmdFresnelRim(NoV, diffLight, ao);
                float3 rimLxz     = ZmdNoLxzRim(N, Lxz, NoV, lightCol, lightIntensity, diffLight, ao);

                return float4(mainResult + max(rimFresnel + rimLxz, 0), 1);
            }
            ENDHLSL
        }
    }
}