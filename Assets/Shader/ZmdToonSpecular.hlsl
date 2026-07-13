#ifndef ZMD_TOON_SPECULAR
#define ZMD_TOON_SPECULAR

// ── Stylized Half-Dir (biased toward camera forward) ────
float3 ZmdGetStylizedHalfDir(float3 viewDir, float3 cameraForward, float3 mainLightDir)
{
    float  fwdY    = lerp(0.5, mainLightDir.y, _DayStrength);
    float3 fwdDir  = normalize(float3(cameraForward.x, fwdY, cameraForward.z));
    float3 newLight= mainLightDir * _DayStrength + 2.0 * fwdDir;
    return normalize(viewDir * (2.0 + _DayStrength) + newLight);
}

// ── GGX Specular (D term only) ──────────────────────────
float3 ZmdGGX(float3 N, float3 H, float3 V, float roughness2, float3 F0)
{
    float NoH = saturate(dot(N, H));
    float NoV = saturate(dot(N, V));
    float a2  = roughness2 * roughness2;
    float D   = a2 / max(1e-5, pow((NoH * a2 - NoH) * NoH + 1.0, 2.0));
    float Vis = 0.5 / max(1e-5, NoV * 2.0 + roughness2);
    float DV  = clamp(D * Vis, 0.0, 20.0);
    return DV * F0;
}

// ── IBL DFG Fit (replaces pre-integrated LUT lookup) ────
float3 ZmdIBLSpecular(float roughness2, float NoV, float3 F0)
{
    float r4 = roughness2 * roughness2;
    float r6 = r4 * roughness2;
    float nv2= NoV * NoV;
    float nv3= nv2 * NoV;

    // Fit part 1: DFG
    float A = 3.32707 * NoV + 0.0365463;
    float B = -9.04755 * NoV + 9.0632;
    float dfg1 = A + B * roughness2;

    float fx = 3.59685 * nv2 - 1.36772 * nv3 + 1.0;
    float fy = 9.22949 * nv3 - 16.3174 * nv2 + 9.04401;
    float fz = -20.2123 * nv3 + 19.7886 * nv2 + 5.56589;
    float dfg2 = dot(float3(fx, fy, fz), float3(1, roughness2, r6));
    float dfg  = dfg1 / max(1e-6, dfg2);

    // Fit part 2: scale+bias for env BRDF
    float s1 = dot(float2(-1.28514, 1.0), float2(NoV, 0.990440011));
    float s2 = dot(float2(1.0, -0.75591), float2(1.29678, NoV));
    float scale = dot(float2(s1, s2), float2(1, roughness2));

    float b1 = dot(float3(2.92338, 59.4188, 1.0), float3(NoV, nv3, 1.0));
    float b2 = dot(float3(1.0, -27.0302, 222.592), float3(20.3225, NoV, nv3));
    float b3 = dot(float3(626.130, 316.627, 1.0), float3(NoV, nv3, 121.563004));
    float bias = scale / max(1e-6, dot(float3(b1, b2, b3), float3(1, roughness2, r6)));

    float3 iblBRDF = dfg * F0 + bias;
    float  albedo  = dfg + bias;

    // Kulla-Conty multi-bounce compensation
    float  energyLoss = (1.0 - albedo) / max(0.001, albedo);
    float3 msComp     = F0 * energyLoss;
    return iblBRDF * (1.0 + msComp);
}

// ── Fresnel Rim ─────────────────────────────────────────
float3 ZmdFresnelRim(float NoV, float3 diffLight, float ao)
{
    float rStart = _RimLightArea * -0.6 + 0.8;
    float rEnd   = _RimLightArea * -0.4 + 0.9;
    float rt     = saturate(((1.0 - NoV) - rStart) / max(rEnd - rStart, 1e-5));
    float rArea  = rt * rt * (3.0 - 2.0 * rt); // smoothstep
    float3 rLight= rArea * _RimLightColor * _RimLightStrength;
    float3 rEff  = rLight * (ao * 0.5 + 0.5);
    float3 rBRDF = (diffLight - 0.25) * _RimLightDiffuseColorEffect + 0.25;
    return rBRDF * rEff;
}

// ── NoLxz Rim (directional highlight along light XZ) ────
float3 ZmdNoLxzRim(float3 N, float3 mainLightDir_xz, float NoV, float3 mainLightColor,
    float mainLightIntensity, float3 diffLight, float ao)
{
    float3 rimColor = lerp(1.0, mainLightColor * mainLightIntensity, _DayStrength);
    float  NoLxz    = dot(N, mainLightDir_xz);
    float  NoLxzRef = (0.5 - (0.5 * NoLxz - 1.0) * NoLxz) * _DayStrength;
    float  t        = saturate(5.0 * (0.4 - NoV));
    float  NoVMask  = smoothstep(0, 1, t);
    return rimColor * NoLxzRef * NoVMask * (ao * 0.5 + 0.5) * max(0.15, diffLight) * _RimLightNoLxzStrength;
}

#endif // ZMD_TOON_SPECULAR
