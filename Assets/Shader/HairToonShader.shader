Shader "Custom/HairToonShader"
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

        // Smooth normal
        _FaceCenter("面部中心点", Vector) = (0,0,0,0)
        _SpecularTrick_Flatten("高光法向压平", Range(0,1)) = 0.5
        _ViewDirYOffset("ViewDir Y偏移", Range(-2, 2)) = 0

        // Kajiya-Kay specular
        _HairSpecularTex("头发高光颜色LUT", 2D) = "white" {}
        _SpecularPowStrength("高光锐度", Range(1,100)) = 20
        _LutVPowStrength("LUT V轴幂次", Range(0.1,5)) = 1
        _SpecularBackF0("背光高光强度", Color) = (0.1,0.1,0.1,1)
        _SpecularBackF0_ToHPowStrength("背光高光锐度", Range(0.01,1)) = 0.5
        _SelfAoShadowStrength("自AO阴影强度", Range(0,1)) = 1
        _BiNormalOffset_specularLut("BiNormal偏移", Range(-1,1)) = 0

        _OutlineWidth("描边宽度", Range(0, 10)) = 1.0
        _ZBias("深度偏移", Range(0, 0.01)) = 0.001
        _OutlineColor("描边颜色", Color) = (0.1, 0.1, 0.1, 1)
        _OutLineStrength("描边强度", Range(0, 2)) = 1
        _ZMinRefine("远距离描边收窄系数", Range(0, 1)) = 0.4
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
                float4 _FaceCenter; float _SpecularTrick_Flatten, _ViewDirYOffset;
                float _SpecularPowStrength, _LutVPowStrength;
                float4 _SpecularBackF0; float _SpecularBackF0_ToHPowStrength;
                float _SelfAoShadowStrength, _BiNormalOffset_specularLut;
                float _OutlineWidth, _ZBias; float4 _OutlineColor;
                float _OutLineStrength, _ZMinRefine;
            CBUFFER_END

            TEXTURE2D(_MainTex);          SAMPLER(sampler_MainTex);
            TEXTURE2D(_OrmTex);           SAMPLER(sampler_OrmTex);
            TEXTURE2D(_NormalTex);        SAMPLER(sampler_NormalTex);
            TEXTURE2D(_RampTex);          SAMPLER(sampler_RampTex);
            TEXTURE2D(_HairSpecularTex);  SAMPLER(sampler_HairSpecularTex);

            half4 frag(Varyings i, bool isFrontFace : SV_IsFrontFace) : SV_Target
            {
                float4 mainTex   = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv0);
                float4 ormTex    = SAMPLE_TEXTURE2D(_OrmTex, sampler_OrmTex, i.uv0);
                float4 normalTex = SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, i.uv0);
                ormTex = lerp(float4(0,1,0,0), ormTex, _IsNeedOrmTex);

                // ── Normal ──
                float3x3 TBN = float3x3(i.tangentWS, i.bitangentWS, i.normalWS);
                float3 nTS   = UnpackNormalScale(normalTex, _BumpScale);
                float3 N     = lerp(i.normalWS, normalize(mul(nTS, TBN)), _IsNeedNormalMap);

                // Smooth normal (ZW channels of normal tex)
                float3 nTS_H  = UnpackNormalScale(float4(normalTex.zw, normalTex.zw), _BumpScale);
                float3 HN     = lerp(i.normalWS, normalize(mul(nTS_H, TBN)), _IsNeedNormalMap);
                float3 sphereN= normalize(i.positionWS.xyz - _FaceCenter.xyz);
                HN = lerp(sphereN, HN, 1.0 - ormTex.x);

                float facing = isFrontFace ? 1.0 : -1.0;
                N = N * facing;

                // ── View dir ──
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.positionWS.xyz);
                float3 hairVD  = normalize(viewDir + float3(0, _ViewDirYOffset * (1.0 - ormTex.x), 0));
                float3 camFwd  = normalize(UNITY_MATRIX_V[2].xyz);
                viewDir = normalize(lerp(viewDir, camFwd, _ForwardDirStrength));

                // ── Main light ──
                float3 L, Lxz, lightCol; float lightIntensity, NoL;
                ZmdGetMainLight(i, L, Lxz, lightCol, lightIntensity, NoL);

                float3 otherLight = ZmdGetOtherLight(N);
                float3 lightFinal = ZmdGetMainLightColorFinal(lightCol, otherLight);
                float  shadow     = ZmdGetShadow(i, GetMainLight(i.shadowCoord).shadowAttenuation);

                // ── Material props ──
                float rough  = 1.0 - ormTex.w;
                float rough2 = max(rough * rough, 0.0078);
                float metallic = ormTex.r, reflec = ormTex.g;
                float ao = pow(ormTex.b, _AoStrength);

                float3 baseCol = mainTex.xyz * _BaseColor.xyz;
                baseCol = pow(baseCol, _BaseColorPow);
                float3 darkCol = baseCol * _AlbedoDarkStrength;
                float  darkLum = Luminance(darkCol);
                darkCol = lerp(darkLum.xxx, darkCol, _AlbedoDarkSaturation);

                float energyDist = 0.96 - 0.96 * metallic;
                float3 F0 = 0.04 * reflec.xxx + metallic * (baseCol - reflec.xxx * 0.04);

                // ── Ramp + Diffuse ──
                float  back     = ZmdGetBackLight(camFwd, Lxz);
                float  rampNoL  = ZmdGetRampNoL(NoL, back);
                float4 rampCol  = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(rampNoL, 0.5));
                float  rampNoF  = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(dot(N, camFwd) * 0.5 + 0.5, 0.5)).w;

                float3 diffLight, diffDark;
                float3 diffuse = ZmdGetDiffuseBRDF(baseCol, darkCol, metallic, ao, shadow, rampCol, rampNoF, energyDist, diffLight, diffDark);
                float3 diffRamp = ZmdApplyRampColor(diffuse, rampCol);

                float  aoShaNoF  = ao * shadow * rampNoF;
                float  minShadow = min(min(ao, shadow), rampCol.w);
                float3 diffLow   = lerp(diffDark * 0.65, diffLight, aoShaNoF);
                diffRamp = lerp(diffLow, diffRamp, _DayStrength);
                float3 diffResult = lightFinal * diffRamp;

                // ── Kajiya-Kay Specular ──
                float3 worldUp     = float3(0,1,0);
                float3 camRight    = normalize(cross(worldUp, camFwd) + float3(1e-6,0,0));
                float  dotRight    = dot(HN, camRight);
                float3 cylN        = normalize(HN - dotRight * camRight);
                float3 flatHN      = normalize(lerp(HN, cylN, _SpecularTrick_Flatten));

                // Hair tangent / binormal
                float3 tmpTan     = float3(0,0,1);
                float3 tmpBTan    = HN.zxy * tmpTan.yzx - HN * tmpTan;
                float3 hairBTan   = lerp(tmpBTan, i.tangentWS.yzx, 1.0 - ormTex.x);
                float3 hariBin    = HN.yzx * hairBTan.zxy - HN.zxy * hairBTan.yzx;
                float3 fakeTan    = normalize(cross(float3(0,1,0), flatHN));
                float3 hairBFlat  = normalize(cross(flatHN, fakeTan));
                float3 hairBLut   = normalize(lerp(hairBFlat, hariBin, 1.0 - ormTex.x) + HN * _BiNormalOffset_specularLut);

                float3 halfDir    = normalize(hairVD + L);
                float  ToH_lut    = dot(halfDir, hairBLut);
                float  lutU       = 1.0 - ToH_lut * ToH_lut;
                lutU = max(0.0001, sqrt(lutU));
                lutU = _SpecularPowStrength * log2(lutU);
                lutU = saturate(exp2(lutU) * reflec);

                float2 vdProj = float2(dot(viewDir, camRight), dot(viewDir, camFwd));
                float2 hnProj = float2(dot(HN, camRight), dot(HN, camFwd));
                float  VoHN   = saturate(dot(vdProj, hnProj));
                VoHN = pow(VoHN, _LutVPowStrength);
                float  lutV   = VoHN * VoHN * step(0.0, ToH_lut);

                float4 lutSpec = SAMPLE_TEXTURE2D(_HairSpecularTex, sampler_HairSpecularTex, float2(lutU, lutV));
                float3 lutF0   = lutSpec.xyz * F0;
                float3 backF0  = _SpecularBackF0.rgb * ormTex.w
                    * pow(sqrt(max(0, 1.0 - ToH_lut * ToH_lut)), _SpecularPowStrength * _SpecularBackF0_ToHPowStrength);
                float3 finalF0 = lutF0 * 7.0 + backF0;

                float  aoShaLow = lerp(aoShaNoF, minShadow, _DayStrength);
                float  selfAo   = lerp(_SelfAoShadowStrength, 1.0, aoShaLow);

                float3 specResult = lightFinal * selfAo * finalF0;

                float  sssBlend = 1.0 - _DiffuseBlendEffect * (1.0 - mainTex.w);
                float3 mainResult = diffResult * sssBlend + specResult;

                // ── Rim ──
                float  NoV        = saturate(dot(N, viewDir));
                float3 rimFresnel = ZmdFresnelRim(NoV, diffLight, ao);
                float3 rimLxz     = ZmdNoLxzRim(N, Lxz, NoV, lightCol, lightIntensity, diffLight, ao);
                float3 rimResult  = rimFresnel + rimLxz;

                return float4(mainResult + max(rimResult, 0), 1);
            }
            ENDHLSL
        }
        UsePass "Custom/Outlineshader/Outline"
    }
}