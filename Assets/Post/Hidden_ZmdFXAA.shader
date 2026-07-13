Shader "Hidden/ZmdFXAA"
{
    Properties
    {
        _EdgeThreshold ("Edge Threshold", Range(0.0312, 0.5)) = 0.125
        _EdgeThresholdMin ("Edge Threshold Min", Range(0.0312, 0.5)) = 0.0625
        _SubpixelQuality ("Subpixel Quality", Range(0, 1)) = 0.75
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Pass
        {
            Name "FXAA"
            Cull Off  ZWrite Off  ZTest Always
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            float _EdgeThreshold, _EdgeThresholdMin, _SubpixelQuality;

            half4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                float w,h; _BlitTexture.GetDimensions(w,h);
                float2 ts = float2(1.0/w, 1.0/h);

                float3 rgbN  = SAMPLE_TEXTURE2D_X_LOD(_BlitTexture, sampler_LinearClamp, input.texcoord, 0).rgb;
                float3 rgbNW = SAMPLE_TEXTURE2D_X_LOD(_BlitTexture, sampler_LinearClamp, input.texcoord + float2(-1,1)*ts, 0).rgb;
                float3 rgbNE = SAMPLE_TEXTURE2D_X_LOD(_BlitTexture, sampler_LinearClamp, input.texcoord + float2(1,1)*ts, 0).rgb;
                float3 rgbSW = SAMPLE_TEXTURE2D_X_LOD(_BlitTexture, sampler_LinearClamp, input.texcoord + float2(-1,-1)*ts, 0).rgb;
                float3 rgbSE = SAMPLE_TEXTURE2D_X_LOD(_BlitTexture, sampler_LinearClamp, input.texcoord + float2(1,-1)*ts, 0).rgb;

                float lN  = dot(rgbN,  float3(0.299,0.587,0.114));
                float lNW = dot(rgbNW, float3(0.299,0.587,0.114));
                float lNE = dot(rgbNE, float3(0.299,0.587,0.114));
                float lSW = dot(rgbSW, float3(0.299,0.587,0.114));
                float lSE = dot(rgbSE, float3(0.299,0.587,0.114));
                float lMin = min(lN, min(min(lNW,lNE), min(lSW,lSE)));
                float lMax = max(lN, max(max(lNW,lNE), max(lSW,lSE)));
                float lRange = lMax - lMin;
                if (lRange < max(_EdgeThresholdMin, lMax * _EdgeThreshold)) return half4(rgbN,1);

                float lH = (lNE+lSE-lNW-lSW)*0.5, lV = (lNW+lNE-lSW-lSE)*0.5;
                float dirH = abs(lH)>=abs(lV)?1:-1;
                float2 stepD = dirH>0 ? float2(ts.x,0) : float2(0,ts.y);
                float grad = dirH>0 ? abs(lH)*0.5 : abs(lV)*0.5;
                float2 uvP = input.texcoord+stepD*0.5, uvN = input.texcoord-stepD*0.5;
                float gP=grad*0.25, gN=grad*0.25, bestPx=uvP.x, bestPy=uvP.y, bestNx=uvN.x, bestNy=uvN.y;
                float2 wP=uvP+stepD, wN=uvN-stepD; bool dP=false,dN=false;
                for(int i=0;i<6;i++){
                    if(!dP){float lp=dot(SAMPLE_TEXTURE2D_X_LOD(_BlitTexture,sampler_LinearClamp,wP,0).rgb,float3(0.299,0.587,0.114))+gP*(1+i*0.5);
                        if(lp>lMax||lp<lMin)dP=true;else{bestPx=wP.x;bestPy=wP.y;wP+=stepD;}}
                    if(!dN){float ln=dot(SAMPLE_TEXTURE2D_X_LOD(_BlitTexture,sampler_LinearClamp,wN,0).rgb,float3(0.299,0.587,0.114))-gN*(1+i*0.5);
                        if(ln>lMax||ln<lMin)dN=true;else{bestNx=wN.x;bestNy=wN.y;wN-=stepD;}}
                    if(dP&&dN)break;
                }
                float subL = saturate(((lNW+lNE+lSW+lSE)*0.25-lN)/(lRange*0.5+0.001))*_SubpixelQuality;
                float eLen = max(abs(bestPx-bestNx),abs(bestPy-bestNy));
                float fBlend = max(saturate(eLen/(ts.x+ts.y)), subL)*0.5;
                float2 bUV = float2((bestPx+bestNx)*0.5,(bestPy+bestNy)*0.5);
                return lerp(float4(rgbN,1), SAMPLE_TEXTURE2D_X_LOD(_BlitTexture,sampler_LinearClamp,bUV,0), fBlend);
            }
            ENDHLSL
        }
    }
}