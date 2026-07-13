#ifndef ZMD_TOON_LIGHTING
#define ZMD_TOON_LIGHTING

// ── Main Light + Color Normalization ────────────────────
void ZmdGetMainLight(Varyings i, out float3 mainLightDir, out float3 mainLightDir_xz,
    out float3 mainLightColor, out float mainLightIntensity, out float NoL)
{
    Light mainLight = GetMainLight(i.shadowCoord);
    mainLightDir    = mainLight.direction;
    mainLightDir_xz = normalize(float3(mainLightDir.x, 6.10351562e-05, mainLightDir.z));

    mainLightColor     = mainLight.color;
    mainLightIntensity = max(0.001, Luminance(mainLightColor));
    mainLightColor     = mainLightColor / mainLightIntensity; // normalize hue, strip intensity

    NoL = dot(i.normalWS, mainLightDir);
}

// ── Top Fill Light ──────────────────────────────────────
float3 ZmdGetOtherLight(float3 normalWS)
{
    float3 otherLightDir = float3(0, 1, 0);
    float  otherNoL      = dot(otherLightDir, normalWS);
    otherNoL = saturate(otherNoL + _OtherLightOffset);
    otherNoL = otherNoL * _OtherLightStrength + _OtherLightStrength_Offset;
    return _OtherLightColor.rgb * otherNoL;
}

// ── Composite Main Light Color (day blend) ──────────────
float3 ZmdGetMainLightColorFinal(float3 mainLightColor, float3 otherLightResult)
{
    float3 other_day1 = otherLightResult * _OtherLightResultStrength_day1;
    float3 other_day0 = otherLightResult * _OtherLightResultStrength_day0;
    return lerp(other_day0, mainLightColor + other_day1, _DayStrength);
}

// ── Shadow (Sigmoid toon step + screen space blend) ─────
float ZmdGetShadow(Varyings i, float shadowAttenuationIn)
{
    float2 screenUV  = GetNormalizedScreenSpaceUV(i.positionHCS.xy);
    float  ssShadow  = SAMPLE_TEXTURE2D(_ScreenSpaceShadowmapTexture, sampler_PointClamp, screenUV).x;
    float  shadowAtt = min(shadowAttenuationIn, ssShadow);
    return saturate((SigmoidSharp(shadowAtt, _ShadowCenter, _ShadowSmoothness) + _ShadowOffset) * _ShadowStrength);
}

// ── Back Light Detection ────────────────────────────────
float ZmdGetBackLight(float3 cameraForward, float3 mainLightDir_xz)
{
    float2 cf_xz     = normalize(cameraForward.xz);
    float  backLight = saturate(-dot(cf_xz, mainLightDir_xz.xz));
    float  backLightY= saturate(-abs(cameraForward.y) + 0.75);
    backLightY = backLightY * backLightY * (3.0 - 2.0 * backLightY); // smoothstep
    return backLight * backLightY;
}

// ── Ramp NoL (back-light compensated) ───────────────────
float ZmdGetRampNoL(float NoL, float backLight)
{
    float rampN = 0.5 - 0.5 * NoL * NoL;
    float finalN= clamp(rampN * backLight + NoL, -1, 1);
    return finalN * 0.5 + 0.5;
}

// ── Diffuse BRDF (3-layer lerp: dark→dark_attn→light) ───
float3 ZmdGetDiffuseBRDF(
    float3 baseColor, float3 baseColor_dark, float metallic,
    float ao, float shadow, float4 rampColor, float rampNoF,
    float energyDist, out float3 diffLight, out float3 diffDark)
{
    float3 diffLightOut = baseColor       * energyDist;
    float3 diffDarkOut  = baseColor_dark  * energyDist;
    float3 diffDarkAttn = diffDarkOut * 0.65;

    float aoShadow    = ao * shadow;
    float minShadow   = min(min(ao, shadow), rampColor.w);
    float aoShaNoF    = aoShadow * rampNoF;

    float3 darkLerp   = lerp(diffDarkAttn, diffDarkOut, saturate(aoShaNoF + rampColor.w));
    float3 diffuse    = lerp(darkLerp, diffLightOut, minShadow);

    diffLight = diffLightOut;
    diffDark  = diffDarkOut;
    return diffuse;
}

// ── Ramp Color Saturation-Adaptive Blending ─────────────
float3 ZmdApplyRampColor(float3 diffuse, float4 rampColor)
{
    float  rampMax  = max(max(rampColor.r, rampColor.g), rampColor.b);
    float  rampMin  = min(min(rampColor.r, rampColor.g), rampColor.b);
    float  rampSat  = rampMax - rampMin;
    float3 rampEff  = rampColor.rgb * rampSat + 1.0 - rampSat;
    float3 diffRamp = diffuse * rampEff;

    float brdfStr   = Luminance(diffuse);
    float brdfRStr  = Luminance(diffRamp);
    float rampCtrl  = clamp(brdfStr / max(0.01, brdfRStr), 0.0, 1.5);
    return diffRamp * rampCtrl;
}

#endif // ZMD_TOON_LIGHTING
