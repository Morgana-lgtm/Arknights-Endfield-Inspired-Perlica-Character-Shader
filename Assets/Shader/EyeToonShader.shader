Shader "Custom/EyeToonShader"
{
    Properties
    {
        _MainTex("Main Tex",2D)="white"{}
        _OrmTex("Orm Tex",2D)="white"{}
        _RampTex("Ramp",2D)="white"{}
        _SpecularMatcap("Specular Matcap",2D)="white"{}

        [Toggle] _IsNeedOrmTex("Enable Orm",Float)=1

        _CorneaBumpStrength("Cornea Bump Strength",Range(0,2))=1

        _SpecularTrickColor("Specular Trick Color",Color)=(1,1,1,1)
        _EyeInTrickColor("Eye Inner Trick Color",Color)=(1,1,1,1)

        _ForwardDirStrength("View Lock CameraForward",Range(0,1))=0

        _DayStrength("Day Strength",Range(0,1))=1
        _OtherLightResultStrength_day1("Sunny Ambient",Float)=0.2
        _OtherLightResultStrength_day0("Cloudy Ambient",Float)=1

        _OtherLightColor("Other Light Color",Color)=(0.9,0.95,1,1)
        _OtherLightOffset("Other Light Offset",Float)=0
        _OtherLightStrength("Other Light Strength",Float)=0.3
        _OtherLightStrength_Offset("Other Light Min",Float)=0.1

        _ShadowCenter("Shadow Center",Float)=0.5
        _ShadowSmoothness("Shadow Smoothness",Float)=0.02
        _ShadowOffset("Shadow Offset",Float)=0
        _ShadowStrength("Shadow Strength",Float)=1

        _AoStrength("AO Strength",Float)=1
        _SelfAoShadowStrength("Specular Shadow Strength",Range(0,1))=0.5

        _BaseColor("Base Color",Color)=(1,1,1,1)
        _BaseColorPow("Base Color Pow",Range(1,2))=1
        _AlbedoDarkStrength("Dark Strength",Range(0.01,1))=0.8
        _AlbedoDarkSaturation("Dark Saturation",Range(0,1))=0.8

        _SpecularStrength("Matcap Strength",Range(0,2))=1
        _SpecularColor("Specular Color",Color)=(1,1,1,1)

        _RimLightArea("Rim Area",Range(0,1))=0.3
        _RimLightColor("Rim Color",Color)=(1,1,1,1)
        _RimLightStrength("Rim Strength",Range(0,3))=0.8
        _RimLightDiffuseColorEffect("Diffuse Blend",Range(0,1))=0.6
        _RimLightNoLxzStrength("NoLxz Rim",Range(0,2))=0.7
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

            TEXTURE2D(_MainTex);         SAMPLER(sampler_MainTex);
            TEXTURE2D(_OrmTex);          SAMPLER(sampler_OrmTex);
            TEXTURE2D(_RampTex);         SAMPLER(sampler_RampTex);
            TEXTURE2D(_SpecularMatcap);  SAMPLER(sampler_SpecularMatcap);

            half4 frag(Varyings i, bool isFrontFace : SV_IsFrontFace) : SV_Target
            {
                float4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv0);
                float4 ormTex  = SAMPLE_TEXTURE2D(_OrmTex, sampler_OrmTex, i.uv0);
                ormTex = lerp(float4(0,1,1,0), ormTex, _IsNeedOrmTex);

                // ── Cornea normal ──
                float2 fracUV  = frac(i.uv0);
                float2 centerUV= fracUV - float2(0.5, 0.5);
                float  eyeArea = step(0.25, dot(centerUV, centerUV));
                float2 cntUV   = centerUV * 2.0;
                float  uvSq    = dot(cntUV, cntUV);
                float  zHemi   = sqrt(max(0, 1.0 - min(1.0, uvSq)));
                zHemi = max(zHemi, 1e-16);

                float2 corneaTS_xy = 0.125 * _CorneaBumpStrength * cntUV;
                float3 corneaTS    = float3(corneaTS_xy, zHemi);
                corneaTS = lerp(corneaTS, float3(0,0,1), eyeArea);
                corneaTS.x *= -1;

                float3 N = normalize(corneaTS.x * i.tangentWS + corneaTS.y * i.bitangentWS + corneaTS.z * i.normalWS);
                float  facing = isFrontFace ? 1.0 : -1.0;
                N = N * facing;

                // ── View dir ──
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.positionWS.xyz);
                float3 camFwd  = normalize(UNITY_MATRIX_V[2].xyz);
                viewDir = normalize(lerp(viewDir, camFwd, _ForwardDirStrength));

                // ── Main light ──
                float3 L, Lxz, lightCol; float lightIntensity, NoL;
                ZmdGetMainLight(i, L, Lxz, lightCol, lightIntensity, NoL);

                float3 otherLight = ZmdGetOtherLight(N);
                float3 lightFinal = ZmdGetMainLightColorFinal(lightCol, otherLight);
                float  shadow     = ZmdGetShadow(i, GetMainLight(i.shadowCoord).shadowAttenuation);

                float ao = pow(ormTex.b, _AoStrength);

                // ── Diffuse ──
                float3 baseCol = mainTex.xyz * _BaseColor.xyz;
                baseCol = pow(baseCol, _BaseColorPow);
                float3 darkCol = baseCol * _AlbedoDarkStrength;
                float  darkLum = Luminance(darkCol);
                darkCol = lerp(darkLum.xxx, darkCol, _AlbedoDarkSaturation);

                float energyDist = 0.96;
                float3 diffLight = baseCol * energyDist;
                float3 diffDark  = darkCol * energyDist;
                float3 diffDarkAttn = diffDark * 0.65;

                float  back    = ZmdGetBackLight(camFwd, Lxz);
                float  rampNoL = ZmdGetRampNoL(NoL, back);
                float4 rampCol = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(rampNoL, 0.5));
                float  rampNoF = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(dot(N, camFwd) * 0.5 + 0.5, 0.5)).w;

                float  aoShadow = ao * shadow;
                float  minShadow = min(min(ao, shadow), rampCol.w);
                float  aoShaNoF  = aoShadow * rampNoF;

                float3 darkLerp  = lerp(diffDarkAttn, diffDark, saturate(aoShaNoF + rampCol.w));
                float3 eyeTrick  = lerp(1.0, _SpecularTrickColor * 2.5, eyeArea);
                float3 innerTrick= lerp(1.0, _EyeInTrickColor * 2.5, mainTex.a);
                float3 trickAlbedo = eyeTrick * innerTrick;
                float3 diffuse = lerp(darkLerp, diffLight * trickAlbedo, minShadow);
                float3 diffRamp = ZmdApplyRampColor(diffuse, rampCol);
                float3 diffLow  = lerp(diffDarkAttn, diffLight, aoShaNoF);
                diffRamp = lerp(diffLow, diffRamp, _DayStrength);
                float3 diffResult = lightFinal * diffRamp;

                // ── MatCap ──
                float  dayDark = lerp(rampNoF, minShadow, _DayStrength);
                float3 N_vs    = normalize(mul((float3x3)UNITY_MATRIX_V, N));
                float2 matUV   = N_vs.xy * 0.5 + 0.5;
                float4 matcap  = SAMPLE_TEXTURE2D(_SpecularMatcap, sampler_SpecularMatcap, matUV);
                float3 matBRDF = matcap.rgb * _SpecularStrength + _SpecularColor.rgb * matcap.a;
                float  matDark = dayDark * 0.5 + 0.5;
                matDark *= lerp(_SelfAoShadowStrength, 1.0, dayDark);
                float3 specResult = lightFinal * matBRDF * matDark;

                // ── Rim ──
                float  NoV       = saturate(dot(N, viewDir));
                float3 rimFresnel= ZmdFresnelRim(NoV, diffLight, ao);
                float3 rimLxz    = ZmdNoLxzRim(N, Lxz, NoV, lightCol, lightIntensity, diffLight, ao);

                return float4(diffResult + specResult + max(rimFresnel + rimLxz, 0), 1);
            }
            ENDHLSL
        }
    }
}