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

        // Face direction (set by FaceDirSetter)
        _FaceForward("Face Forward", Vector) = (0,0,1,0)
        _FaceRight("Face Right", Vector) = (1,0,0,0)
        _FaceUp("Face Up", Vector) = (0,1,0,0)

        // SDF
        _SdfTex("SDF魔法图", 2D) = "white" {}
        _SdfRefineTex("SDF Refine图", 2D) = "white" {}

        // Expression
        _TrickTex("表情贴图", 2D) = "white" {}
        _TrickType("表情类型", Range(0,3)) = 0
        _TrickStrength("表情强度", Range(0,1)) = 0

        // SSS
        _SSSColor("SSS颜色", Color) = (1,0.8,0.7,1)
        _SSSArea("SSS范围", Range(0,2)) = 1.0

        // Skin material
        _Roughness("粗糙度", Range(0,1)) = 0.5
        _ReflectivityStrength("反射率", Range(0,1)) = 0.5
        _LutColorTex("皮肤LUT贴图", 2D) = "white" {}

        // Rim
        _RimMaskStrength("Rim Mask强度", Range(0,1)) = 0.5
        _MainLightColor_dark("主光暗部颜色", Color) = (1,1,1,1)
        _SelfAoShadowStrength("自AO阴影强度", Range(0,1)) = 1
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

            TEXTURE2D(_MainTex);      SAMPLER(sampler_MainTex);
            TEXTURE2D(_NormalTex);    SAMPLER(sampler_NormalTex);
            TEXTURE2D(_RampTex);      SAMPLER(sampler_RampTex);
            TEXTURE2D(_SdfTex);       SAMPLER(sampler_SdfTex);
            TEXTURE2D(_SdfRefineTex); SAMPLER(sampler_SdfRefineTex);
            TEXTURE2D(_TrickTex);     SAMPLER(sampler_TrickTex);
            TEXTURE2D(_LutColorTex);  SAMPLER(sampler_LutColorTex);

            half4 frag(Varyings i, bool isFrontFace : SV_IsFrontFace) : SV_Target
            {
                float4 mainTex         = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv0);
                float4 normalTex       = SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, i.uv0);
                float4 sdfRefine       = SAMPLE_TEXTURE2D(_SdfRefineTex, sampler_SdfRefineTex, i.uv0);

                float3 albedo = mainTex.xyz * _BaseColor.xyz;

                // Expression
                float  emojiType = _TrickType * 0.5;
                float2 emojiUV   = float2(frac(abs(emojiType)), floor(emojiType) * 0.5);
                float4 trickTex  = SAMPLE_TEXTURE2D(_TrickTex, sampler_TrickTex, i.uv0 * 0.5 + emojiUV);
                albedo = lerp(albedo, trickTex.xyz, trickTex.w * _TrickStrength);

                // ── Main light ──
                Light  mainLight   = GetMainLight(i.shadowCoord);
                float3 L            = mainLight.direction;
                float3 Lxz          = normalize(float3(L.x, 6.10351562e-05, L.z));
                float3 lightCol     = mainLight.color;
                float  lightInt     = max(0.001, Luminance(lightCol));
                lightCol = lightCol / lightInt;

                // ── View dir ──
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.positionWS.xyz);
                float3 camFwd  = normalize(UNITY_MATRIX_V[2].xyz);
                viewDir = normalize(lerp(viewDir, camFwd, _ForwardDirStrength));
                float3 worldUp  = float3(0,1,0);
                float3 camRight = normalize(cross(worldUp, camFwd) + float3(1e-6,0,0));

                // ── Normal ──
                float3x3 TBN = float3x3(i.tangentWS, i.bitangentWS, i.normalWS);
                float3 nTS   = UnpackNormalScale(normalTex, _BumpScale);
                float3 N     = lerp(i.normalWS, normalize(mul(nTS, TBN)), _IsNeedNormalMap);
                float  facing= isFrontFace ? 1.0 : -1.0;
                N = N * facing;

                // Camera face direction
                float3 camFaceDir = normalize(float3(
                    dot(camFwd, _FaceRight.xyz),
                    dot(camFwd, _FaceUp.xyz),
                    dot(camFwd, _FaceForward.xyz)));
                float headDot = camFaceDir.z / max(1e-5, sqrt(dot(camFaceDir.xz, camFaceDir.xz)));

                // SSS
                float  viewSssStr = lerp(saturate(headDot + 0.5), 1.0, sdfRefine.y) * sdfRefine.x;
                float  sssNoV     = saturate(dot(N, viewDir)) * 0.85 + 0.15;
                float  sssA       = saturate(_SSSArea * viewSssStr * (1.0 - sssNoV));
                float3 sssEff     = lerp(float3(1,1,1), _SSSColor.rgb, sssA);
                float3 albedoSss  = albedo * sssEff;

                // ── Material (skin: metallic=0) ──
                float  energyDist = 0.96;
                float3 diffLight  = albedoSss * energyDist;
                float  reflec     = 0.04 * _ReflectivityStrength;
                float3 F0         = float3(1,1,1) * reflec;
                float  rough2     = max(0.0078125, _Roughness * _Roughness);

                // Dark color
                float3 darkBase    = albedoSss * _AlbedoDarkStrength;
                float  darkLum     = Luminance(darkBase);
                float3 diffDark    = lerp(darkLum.xxx, darkBase, _AlbedoDarkSaturation) * energyDist;
                float3 diffDarkIn  = diffDark * 0.65;

                // ── SDF Lighting ──
                float3 LxzFace = normalize(float3(dot(L, _FaceRight.xyz), 6.10351562e-05, dot(L, _FaceForward.xyz)));
                float  sdfFlag = step(0, LxzFace.x);
                float  sdfU    = sdfFlag * (2.0 * i.uv0.x - 1.0) + 1.0 - i.uv0.x;
                float4 sdfTex  = SAMPLE_TEXTURE2D(_SdfTex, sampler_SdfTex, float2(sdfU, i.uv0.y));

                float faceComp = -0.5 * LxzFace.z * LxzFace.z + 0.5;
                float2 cfXz    = normalize(camFwd.xz);
                float  back     = saturate(-dot(cfXz, Lxz.xz)) * saturate(-LxzFace.z);
                float  faceNoL  = LxzFace.z + back * faceComp;
                float  halfFace = faceNoL * 0.5;
                faceNoL = saturate(-faceNoL * 0.5 + 0.5);

                float sdfMin    = max(0, 2.0 * faceNoL - 1.0);
                float sdfWidth  = max(1e-5, min(1, 2.0 * faceNoL) - sdfMin);
                float sdfSmooth = saturate((0.5 * (sdfTex.x + sdfTex.y) - sdfMin) / sdfWidth);
                float sdfBack   = halfFace * ceil(halfFace);
                sdfSmooth = sdfSmooth * sdfSmooth * (3.0 - 2.0 * sdfSmooth);
                float sdfNoL = abs(-sdfSmooth - sdfBack) * 2.0 - 1.0;

                // Neck blend
                float  modelNoL = dot(N, L);
                float  rampU     = lerp(sdfNoL, modelNoL, sdfRefine.y) * 0.5 + 0.5;
                float4 rampCol   = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(rampU, 0.5));

                // Shadow
                float shadowAttn = mainLight.shadowAttenuation;
                float2 screenUV  = GetNormalizedScreenSpaceUV(i.positionHCS.xy);
                float  ssShadow  = SAMPLE_TEXTURE2D(_ScreenSpaceShadowmapTexture, sampler_PointClamp, screenUV).x;
                shadowAttn = min(shadowAttn, ssShadow);
                float shadow = saturate((SigmoidSharp(shadowAttn, _ShadowCenter, _ShadowSmoothness) + _ShadowOffset) * _ShadowStrength);

                float ao      = pow(mainTex.w, _AoStrength);
                float aoShadow= ao * shadow;
                float minSh   = min(min(ao, shadow), rampCol.w);

                // Other light
                float3 otherL = ZmdGetOtherLight(N);
                float3 otherDay1 = otherL * _OtherLightResultStrength_day1;
                float3 otherDay0 = otherL * _OtherLightResultStrength_day0;

                // Main light color with dark tint
                float  lightColStr  = Luminance(lightCol * _MainLightColor_dark.rgb);
                float3 lightColNew  = lerp(lightColStr.xxx, lightCol, minSh) * lightInt;
                float3 lightFinal   = lerp(otherDay0, lightColNew + otherDay1, _DayStrength);

                // Diffuse BRDF
                float  diffLightStr = Luminance(diffLight);
                float  diffDarkStr  = Luminance(diffDarkIn);
                float3 diffDarkF    = lerp(diffDarkStr.xxx, diffDarkIn, 1.2);
                float3 darkLerp     = lerp(diffDarkF, diffDark, saturate(aoShadow + rampCol.w));
                float3 diffuse      = lerp(darkLerp, diffLight, minSh);

                float  rampMax = max(max(rampCol.r, rampCol.g), rampCol.b);
                float  rampMin = min(min(rampCol.r, rampCol.g), rampCol.b);
                float  rampSat = rampMax - rampMin;
                float3 rampEff = rampCol.rgb * rampSat + 1.0 - rampSat;
                float3 diffRamp= diffuse * rampEff;

                float  diffStr   = Luminance(diffuse);
                float  diffRStr  = Luminance(diffRamp);
                float  rampCtrl  = clamp(diffStr / max(0.01, diffRStr), 0.0, 1.5);
                float3 diffLightF = lerp(diffLightStr.xxx, diffLight, 1.2);
                float3 diffLow    = lerp(diffDark, diffLightF, aoShadow);
                diffRamp = lerp(diffLow, diffRamp * rampCtrl, _DayStrength);
                float3 diffResult = lightFinal * diffRamp;

                // ── Specular ──
                float aoShaLow     = lerp(aoShadow, minSh, _DayStrength);
                float selfAo       = lerp(_SelfAoShadowStrength, 1.0, aoShaLow);
                float fwdY         = lerp(0.5, L.y, _DayStrength);
                float3 fwdDir      = normalize(float3(camFwd.x, fwdY, camFwd.z));
                float3 newLight    = L * _DayStrength + 2.0 * fwdDir;
                float3 halfDir     = normalize(viewDir * (2.0 + _DayStrength) + newLight);
                float  NoV         = saturate(dot(N, viewDir));
                float3 specBRDF    = ZmdGGX(N, halfDir, viewDir, rough2, F0);
                float3 specLight   = lightFinal * selfAo * (aoShaLow * 0.5 + 0.5);
                float3 mainResult  = diffResult + specLight * specBRDF * _SpecularStrength;

                // ── Rim (SDF-based) ──
                float sdfZ    = lerp(-(sdfTex.z * 2.0 - 1.0), sdfTex.z * 2.0 - 1.0, sdfFlag);
                float3 sdfDir = normalize(float3(sdfZ, 6.10351562e-05, 1.0 - abs(sdfZ)));
                float3 fsX = float3(_FaceRight.x, _FaceUp.x, _FaceForward.x);
                float3 fsY = float3(_FaceRight.y, _FaceUp.y, _FaceForward.y);
                float3 fsZ = float3(_FaceRight.z, _FaceUp.z, _FaceForward.z);
                float3 sdfN= normalize(float3(dot(fsX, sdfDir), dot(fsY, sdfDir), dot(fsZ, sdfDir)));
                float3 rimN= lerp(sdfN, i.normalWS, sdfRefine.y);

                float  rimNoV   = dot(rimN, viewDir);
                float  headRim  = saturate(-0.9 + headDot * 10.0);
                headRim = headRim * headRim * (3.0 - 2.0 * headRim);
                float  rStart   = _RimLightArea * -0.6 + 0.8;
                float  rEnd     = _RimLightArea * -0.4 + 0.9;
                float  rt       = saturate(((1.0 - rimNoV) - rStart) / max(rEnd - rStart, 1e-5));
                float  rArea    = rt * rt * (3.0 - 2.0 * rt);
                float  rAreaM   = sdfRefine.w;
                float  rAreaF   = lerp(rArea, rAreaM, _RimMaskStrength);
                float  rHalf    = saturate(dot(camRight, rimN));
                float3 rimLight = rAreaF * headRim * _RimLightColor.rgb * _RimLightStrength;
                float3 rimEff   = rimLight * min(ao, shadow);
                float3 rimBRDF  = (diffLight - 0.25) * _RimLightDiffuseColorEffect + 0.25;
                float3 rimResult= rimBRDF * rimEff * rHalf;

                return float4(mainResult + max(rimResult, 0), 1);
            }
            ENDHLSL
        }
    }
}