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

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

        CBUFFER_START(UnityPerMaterial)

        float _IsNeedOrmTex;
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
        float _AlbedoDarkSaturation;
        float _OtherLightOffset;
        float _OtherLightStrength;
        float _OtherLightStrength_Offset;
        float4 _OtherLightColor;
        float _AoStrength;

        float _SpecularStrength;
        float _DiffuseBlendEffect;

        float _IsNeedSss;
        float4 _SssColor;
        float _SssPowStrength;

        float _EnvRotation;
        float3 _EnvColor;
        float _EnvLightStrength;

        float _RimLightArea;
        float3 _RimLightColor;
        float _RimLightStrength;
        float _RimLightDiffuseColorEffect;

        float _RimLightNoLxzStrength;

        float _RefineF0U_lerp;
        float4 _SpecularRefineColor;
        float _SpecularRefineColorStrength;
        CBUFFER_END

        ENDHLSL

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ SCREEN_SPACE_SHADOWS
            #pragma shader_feature_local _SSS_ON
            #pragma shader_feature_local _SPECULARREFINE_ON

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            TEXTURE2D(_OrmTex);
            SAMPLER(sampler_OrmTex);

            TEXTURE2D(_NormalTex);
            SAMPLER(sampler_NormalTex);

            TEXTURE2D(_RampTex);
            SAMPLER(sampler_RampTex);

            TEXTURECUBE(_EnvMap);
            SAMPLER(sampler_EnvMap);

            TEXTURE2D(_SpecularRefineF0Tex);
            TEXTURE2D(_SpecularRefineColorTex);


            // 自定义Sigmoid硬阴影函数
            float SigmoidSharp(float x, float center, float smoothness)
            {
                float t = (x - center) / max(smoothness, 1e-6);
                return 1.0 / (1.0 + exp(-t));
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

            half4 frag(Varyings i,bool isFrontFace : SV_IsFrontFace) : SV_Target
            {
                // 基础贴图资源获取
                float4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv0);
                float4 ormTex = SAMPLE_TEXTURE2D(_OrmTex, sampler_OrmTex, i.uv0);
                float4 normalTex= SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, i.uv0);
                ormTex = lerp(float4(0,1,0,0),ormTex,_IsNeedOrmTex);// ORM开关默认值 AO=0, Rough=1, Metal=0

                // 光源属性获取
                Light mainLight = GetMainLight(i.shadowCoord);
                float3 mainLightDir = mainLight.direction;
                // 获取xz平面光源dir
                float3 mainLightDir_xz = normalize(float3(mainLightDir.x, 6.10351562e-05, mainLightDir.z));

                // normal处理
                float3x3 tangentTransform = float3x3( i.tangentWS, i.bitangentWS, i.normalWS); // TBN矩阵
                float3 normalTex_processed = UnpackNormalScale(normalTex, _BumpScale);
                float3 normalWS = lerp( i.normalWS ,normalize(mul(normalTex_processed, tangentTransform)), _IsNeedNormalMap);

                // 面朝向
                float facing = isFrontFace ? 1.0 : -1.0;
                normalWS = normalWS * facing;

                // view dir
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz-i.positionWS.xyz);

                // 相机forward dir
                float3 cameraForward = UNITY_MATRIX_V[2].xyz;
                cameraForward = normalize(cameraForward);
                viewDir = lerp(viewDir, cameraForward, _ForwardDirStrength);
                viewDir = normalize(viewDir);

                // 获取光源颜色
                float3 mainLightColor = mainLight.color;
                float mainLightIntensity = max(0.001, (0.299 * mainLightColor.r + 0.587 * mainLightColor.g + 0.114 * mainLightColor.b));// 把RGB转成亮度（灰度），防止除零
                mainLightColor = mainLightColor / mainLightIntensity;// 用亮度归一化颜色，只保留色相，剔除明暗强度
                float NoL = dot(normalWS, mainLightDir);

                // 头顶补光光源计算
                float3 otherLightDir = float3(0,1,0);
                float otherLightNoL = dot(otherLightDir, normalWS);
                otherLightNoL = saturate(otherLightNoL + _OtherLightOffset);// 偏移+钳位，把底部黑暗区域抬起来，防止下巴、腹部死黑
                otherLightNoL = otherLightNoL * _OtherLightStrength + _OtherLightStrength_Offset;// 缩放亮度 + 基础底光
                float3 otherLightColor = _OtherLightColor;
                float3 otherLightResult = otherLightColor * otherLightNoL;

                // 计算日光强度两个临界情况的补光结果
                float3 otherLightResult_day1 = otherLightResult * _OtherLightResultStrength_day1;
                float3 otherLightResult_day0 = otherLightResult * _OtherLightResultStrength_day0;
                // 主光和补光相融合 得到最终主光源
                float3 mainLightColor_final = lerp( otherLightResult_day0, mainLightColor + otherLightResult_day1 ,_DayStrength);

                // shadow 获取
                float shadowAttenuation = 1;
                float2 screenUV = GetNormalizedScreenSpaceUV(i.positionHCS.xy);// 把裁剪空间坐标转为屏幕UV
                float ssShadow = SAMPLE_TEXTURE2D(_ScreenSpaceShadowmapTexture, sampler_PointClamp, screenUV).x;// 采样URP屏幕空间阴影贴图
                // 同时混合物体自身投影 + 场景阴影，取最小值（阴影叠加更重）
                shadowAttenuation = mainLight.shadowAttenuation;
                shadowAttenuation = min(mainLight.shadowAttenuation, ssShadow);

                float shadowScene = (SigmoidSharp(shadowAttenuation, _ShadowCenter, _ShadowSmoothness) + _ShadowOffset) * _ShadowStrength ;// 卡通阶跃处理：Sigmoid做成硬阴影分界
                shadowScene = saturate(shadowScene);

                //材质属性获取
                float roughness = 1 - ormTex.w;// 光滑度 → 粗糙度转换
                float roughness2 = max(roughness * roughness, 0.0078);// 粗糙度平方 + 下限保护，防止高光出现镜面奇点
                float metallic = ormTex.r;// R通道：金属度
                float reflectivity = ormTex.g;// G通道：反射率，控制非金属F0
                float ao = ormTex.b;// B通道：AO闭塞值
                ao = pow(ao, _AoStrength);// 幂次增强闭塞，加深暗部死角

                //漫反射颜色三层准备
                float3 baseColor = mainTex.xyz * _BaseColor.xyz;
                baseColor = pow(baseColor, _BaseColorPow);

                // SSS 半透明边缘透光效果 (shader_feature: _SSS_ON)
                #ifdef _SSS_ON
                float NoV_sss = saturate(dot(normalWS, viewDir));
                float sss_area = pow(1.05 - NoV_sss, 1 + mainTex.w * _SssPowStrength);
                sss_area = min(0.9, sss_area) * step(mainTex.w, 0.99); // 防止完全不透明区域也被影响
                baseColor = lerp(baseColor, _SssColor.xyz, lerp(0, sss_area, _IsNeedSss));
                #endif

                // 暗部颜色（饱和度衰减）
                float3 baseColor_dark = baseColor * _AlbedoDarkStrength;
                float baseColor_dark_strength = dot(baseColor_dark, float3(0.299, 0.587, 0.114));// RGB转灰度亮度
                baseColor_dark = lerp(baseColor_dark_strength.xxx, baseColor_dark, _AlbedoDarkSaturation);// 在纯灰度黑白色与原色之间插值，控制饱和度

                // 能量守恒分配
                float energyDistribution_metallic = 0.96 - 0.96 * metallic;
                float3 mainDiffuseColor_Light = baseColor * energyDistribution_metallic;
                float3 mainDiffuseColor_Dark  = baseColor_dark * energyDistribution_metallic;
                float3 mainDiffuseColor_Dark_attention = mainDiffuseColor_Dark * 0.65;
                float3 F0 = 0.04 * reflectivity.xxx + metallic * (baseColor - reflectivity.xxx * 0.04);//F0 菲涅尔基础反射率（给高光用）

                // 背光判断
                float2 cameraForward_xz = normalize(cameraForward.xz);
                float backLight = saturate(-dot(cameraForward_xz, mainLightDir_xz.xz));// dot结果：光源与相机朝向相反时为负值，加负号转正
                float backLight_y = saturate(-abs(cameraForward.y) + 0.75);
                // smoothstep手动版,三阶平滑缓动函数，等价于 smoothstep (0,1,t)。
                backLight_y = backLight_y * backLight_y * (3.0 - 2.0 * backLight_y);//缓动过渡，避免硬切
                backLight = backLight * backLight_y;

                // 采样ramp的NoL计算
                float rampNoL = 0.5 - 0.5 * NoL * NoL;//正面受光 NoL≈1 → rampNoL=0 侧面、背光 NoL 变小 → rampNoL 数值抬升 专门提亮背光区域，为逆光补偿预留增量。
                float NoL_rampFinal = clamp(rampNoL * backLight + NoL, -1, 1);//只在逆光环境抬升暗部，顺光完全不破坏原有光照分布。
                NoL_rampFinal = NoL_rampFinal * 0.5 + 0.5;
                float4 rampColor = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(NoL_rampFinal, 0.5));

                // Ramp采样UV（NoF轴，用于暗中暗边缘）
                float NoF = dot(normalWS, cameraForward) * 0.5 + 0.5;
                float rampColor_NoF = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(NoF, 0.5)).w;//Alpha 通道专门存轮廓边缘压暗系数

                //其他项组合（ao / shadow / NoF）
                float ao_shadow = ao * shadowScene;
                float min_shadowEffect = min(min(ao, shadowScene), rampColor.w);//控制：亮部色 ↔ 暗部色
                float ao_shadow_NoFRamp = ao_shadow * rampColor_NoF;//暗部 ↔ 暗中暗

                //三层漫反射 Brdf + Ramp 染色
                // Day=1 状态，三层lerp
                float3 mainDiffuseColor_Dark_lerp = lerp(mainDiffuseColor_Dark_attention, mainDiffuseColor_Dark,saturate(ao_shadow_NoFRamp + rampColor.w));
                float3 mainDiffuseBrdf = lerp(mainDiffuseColor_Dark_lerp, mainDiffuseColor_Light, min_shadowEffect);

                // Ramp 饱和度自适应染色
                float rampColor_max = max(max(rampColor.r, rampColor.g), rampColor.b);
                float rampColor_min = min(min(rampColor.r, rampColor.g), rampColor.b);
                float rampSat = rampColor_max - rampColor_min;// 算出饱和度（色度值)
                float3 rampColor_xyzEffect = rampColor.rgb * rampSat + 1 - rampSat;// 饱和度越高，Ramp染色越强；灰白区域弱化染色
                float3 mainDiffuseBrdf_rampColor = mainDiffuseBrdf * rampColor_xyzEffect;

                // 亮度补偿防止ramp压太暗
                float brdf_str     = dot(mainDiffuseBrdf, float3(0.299,0.587,0.114));//不带Ramp染色的原始BRDF亮度
                float brdf_r_str   = dot(mainDiffuseBrdf_rampColor, float3(0.299,0.587,0.114));// 叠加了Ramp染色之后的整体亮度
                float rampColor_control = clamp(brdf_str / max(0.01, brdf_r_str), 0, 1.5);//亮度比值，用来反向控制Ramp强度

                // Day=0 状态，2层简单lerp
                float3 mainDiffuseBrdf_lowLight = lerp(mainDiffuseColor_Dark_attention,  mainDiffuseColor_Light, ao_shadow_NoFRamp);

                // 根据日光强度混合两个状态
                float3 mainDiffuseBrdf_final = lerp(mainDiffuseBrdf_lowLight, mainDiffuseBrdf_rampColor * rampColor_control,  _DayStrength);

                // 漫反射结果
                float3 mainDiffuseResult = mainLightColor_final * mainDiffuseBrdf_final;


                //高光
                float ao_shadow_lowLight = lerp(ao_shadow_NoFRamp, min_shadowEffect, _DayStrength);

                // 风格化 half dir（偏相机方向）
                float forwardLightDir_y = lerp(0.5, mainLightDir.y, _DayStrength);//// Y轴高度：阴天压低到0.5，晴天跟随真实光源高度
                float3 forwardLightDir = normalize(float3(cameraForward.x, forwardLightDir_y, cameraForward.z));// XZ完全锁定为相机前后方向，只改变高度
                float NoV = saturate(dot(normalWS, viewDir));
                float3 mainLightDir_new = mainLightDir * _DayStrength + 2 * forwardLightDir;// 混合真实主光 + 两倍强度的相机正面光
                float3 halfDir_new = normalize(viewDir * (2 + _DayStrength) + mainLightDir_new);// 视线拉长，再和新光源合成半角向量
                float NoH = dot(normalWS, halfDir_new);

                // GGX D+V
                float a2 = roughness2 * roughness2;
                float specular_D = a2 / max(1e-5, pow((NoH * a2 - NoH) * NoH + 1, 2));
                float specular_V = 0.5 / max(1e-5, NoV * 2 + roughness2);

                // 高光F0细化 (shader_feature: _SPECULARREFINE_ON)
                #ifdef _SPECULARREFINE_ON
                float f0Refine_u = lerp(specular_D * roughness2, NoV * NoV, _RefineF0U_lerp);
                float f0Refine_v = roughness * (1 - ao);
                float4 F0RefineTex_var = SAMPLE_TEXTURE2D(_SpecularRefineF0Tex, sampler_MainTex, float2(f0Refine_u, f0Refine_v));
                F0 *= F0RefineTex_var.xyz;
                #endif

                float specular_DV = clamp(specular_D * specular_V, 0, 20);//上限钳到 20，抑制高光爆亮
                float3 specular_brdf = specular_DV * F0;

                float3 specularLight = mainLightColor_final * (ao_shadow_lowLight * 0.5 + 0.5);// 高光颜色：主光颜色 + 阴影遮罩
                float3 mainLightSpecularResult = specularLight * specular_brdf * _SpecularStrength;// 最终高光结果

                // 漫反射+高光融合（albedo w 通道控制 SSS 区域能量）
                float diffuseSpecularBlend = 1 - _DiffuseBlendEffect * (1 - mainTex.w);
                float3 mainLightResult = mainDiffuseResult * diffuseSpecularBlend + mainLightSpecularResult;

                // 自发光叠加 (shader_feature: _SPECULARREFINE_ON)
                #ifdef _SPECULARREFINE_ON
                float4 specularRefineColorTex_var = SAMPLE_TEXTURE2D(_SpecularRefineColorTex, sampler_MainTex, i.uv0);
                float3 specularRefineResult = specularRefineColorTex_var.xyz * _SpecularRefineColor.xyz * _SpecularRefineColorStrength * diffuseSpecularBlend;
                mainLightResult += specularRefineResult;
                #endif


                // IBL高光计算

                float roughness4 = roughness2 * roughness2;
                float roughness6 = roughness4 * roughness2;
                float NoV2 = NoV * NoV;
                float NoV3 = NoV2 * NoV;
                float fit_A = 3.32707 * NoV + 0.0365463;
                float fit_B = -9.04755 * NoV + 9.0632;
                float IBLspecular_brdf1 = fit_A + fit_B * roughness2;

                float fitX = 3.59685 * NoV2 - 1.36772 * NoV3 + 1.0;
                float fitY = 9.22949 * NoV3 - 16.3174 * NoV2 + 9.04401;
                float fitZ = -20.2123 * NoV3 + 19.7886 * NoV2 + 5.56589;
                float3 nvFactors = float3(fitX, fitY, fitZ);
                float IBLspecular_brdf2 = dot(nvFactors, float3(1, roughness2, roughness6));

                float IBLspecular_brdf = IBLspecular_brdf1/IBLspecular_brdf2;

                // IBL高光函数计算继续 拟合Lut图查找部分 DFG拟合板块
                float scale_fit_part1 = dot(float2(-1.28514, 1.0), float2(NoV, 0.990440011));
                float scale_fit_part2 = dot(float2(1.0, -0.75591), float2(1.29678, NoV));
                float env_scale = dot(float2(scale_fit_part1, scale_fit_part2), float2(1, roughness2));
                float bias_fit_x = dot(float3(2.92338, 59.4188, 1.0), float3(NoV, NoV3, 1.0));
                float bias_fit_y = dot(float3(1.0, -27.0302, 222.592), float3(20.3225, NoV, NoV3));
                float bias_fit_z = dot(float3(626.130, 316.627, 1.0), float3(NoV, NoV3, 121.563004));
                float bias_denominator = dot(float3(bias_fit_x, bias_fit_y, bias_fit_z), float3(1,roughness2,roughness6));
                float env_bias = env_scale / bias_denominator;

                float3 IBLspecular_brdf_final = IBLspecular_brdf * F0 + env_bias;
                float IBLspecular_brdf_final_noF0 = IBLspecular_brdf  + env_bias;
                // 把IBL的传统预积分过程，拟合成了一个标准数学函数


                // IBL高光补充项 多级弹射补偿 前面是单次弹射的函数拟合
                float directionalAlbedo = IBLspecular_brdf_final_noF0;
                // 计算多级弹射补偿因子 (Kulla-Conty Approximation)
                // 目的：找回在微表面缝隙中经过多次弹射后才射出的光线
                float energyLossFactor = (1.0 - directionalAlbedo) / directionalAlbedo;
                // 补偿颜色主要受 F0 影响
                float3 ms_compensation = F0 * energyLossFactor;
                // 最终的 IBL BRDF = 基础项 + 补偿项
                // 这能显著提升粗糙材质在高光下的饱和度和亮度
                float3 final_ibl_brdf = IBLspecular_brdf_final * (1.0 + ms_compensation);

                // IBL高光 light部分获取
                float3 reflectDir = reflect(-viewDir, normalWS);
                reflectDir.x = -reflectDir.x;
                // reflectDir.y = -reflectDir.y;
                reflectDir.z = -reflectDir.z;

                // 旋转环境贴图
                float angle = _EnvRotation * 0.0174532925; // 将角度转换为弧度 (PI/180)
                float s, c;
                sincos(angle, s, c); // 同时获得正弦和余弦

                float3 rotatedDir;
                rotatedDir.x = reflectDir.x * c - reflectDir.z * s; // 旋转 X
                rotatedDir.y = reflectDir.y;                       // Y 保持不变
                rotatedDir.z = reflectDir.x * s + reflectDir.z * c; // 旋转 Z

                float envMap_level = log2(max(0.01, roughness));
                envMap_level = envMap_level * 1.2 + 5.0;
                float3 envMap_color = GlossyEnvironmentReflection(rotatedDir, i.positionWS, roughness, 1.0);
                envMap_color *= _EnvColor;

                // IBL高光结果获取
                float3 indirLightSpecular = envMap_color * final_ibl_brdf * _EnvLightStrength ;


                // Fresnel Rim
                float rimStart = _RimLightArea * -0.6 + 0.8;
                float rimEnd   = _RimLightArea * -0.4 + 0.9;
                float rimt = saturate(((1.0 - NoV) - rimStart) / max(rimEnd - rimStart, 1e-5));// 菲涅尔因子：1-NoV = 视线垂直边缘，越靠近模型轮廓数值越高
                float rimArea = rimt * rimt * (3.0 - 2.0 * rimt);// SmoothStep 平滑过渡（三次埃尔米特插值，无生硬锯齿）
                float3 rimLight = rimArea * _RimLightColor * _RimLightStrength;// 基础轮廓光颜色与强度
                // Fresnel Rim 遮罩改为柔和版
                float3 rimLight_effectd = rimLight * (ao * 0.5 + 0.5); // 只用AO，不用shadow
                float3 rimLight_brdf = (mainDiffuseColor_Light - 0.25) * _RimLightDiffuseColorEffect + 0.25;// 用漫反射主色调做颜色融合，让轮廓光贴合物体固有色，不会凭空冒出冷色光
                float3 rimLightResult = rimLight_brdf * rimLight_effectd;

                // NoLxz 光源边缘光（只在主光照亮的一侧生成勾边）
                float3 rim_mainLight = lerp(1, mainLightColor * mainLightIntensity, _DayStrength);// 阴天用纯白色轮廓，晴天跟随主光颜色
                float NoLxz = dot(normalWS, mainLightDir_xz);// 只取XZ水平面的光照夹角，忽略上下俯仰，只控制左右明暗边界
                float NoLxz_refine = (0.5 - (0.5 * NoLxz - 1) * NoLxz) * _DayStrength;// 二次曲线塑形：把N·L变成柔和的明暗过渡带，生成一条窄窄的亮边
                float t = saturate(5.0 * (0.4 - NoV));
                float NoV_mask = smoothstep(0, 1, t);// 菲涅尔遮罩：只保留物体轮廓，内部不会泛光
                float3 rim_mainLightResult = rim_mainLight * NoLxz_refine * NoV_mask * (ao * 0.5 + 0.5) * max(0.15, mainDiffuseColor_Light) * _RimLightNoLxzStrength;

                // 1. rimLightResult：背光菲涅尔轮廓（逆光勾边）
                // 2. rim_mainLightResult：主光受光侧亮边（顺光勾边)
                float3 rimLight_finalResult = rimLightResult + rim_mainLightResult;

                float3 resultColor = mainLightResult + indirLightSpecular + max(rimLight_finalResult, 0);

                return float4(resultColor,1);
            }

            ENDHLSL
        }
    }
}