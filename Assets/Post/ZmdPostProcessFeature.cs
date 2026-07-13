using UnityEngine;
using UnityEngine.Rendering.Universal;

/// <summary>
/// 终末地后处理 Feature — 挂载到 Renderer 上
/// </summary>
public class ZmdPostProcessFeature : ScriptableRendererFeature
{
    [System.Serializable] public class EffectSettings { public bool enabled = true; public Material mat; }
    [System.Serializable] public class LutSettings : EffectSettings { public Texture2D lutTex; }

    public LutSettings LUT;
    public EffectSettings Bloom;
    public EffectSettings FXAA;

    private ZmdPostProcessPass _pass;

    public override void Create()
    {
        _pass = new ZmdPostProcessPass(LUT, Bloom, FXAA);
        _pass.renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (_pass != null && _pass.HasAnyEffect)
            renderer.EnqueuePass(_pass);
    }

    protected override void Dispose(bool disposing)
    {
        _pass?.Release();
        base.Dispose(disposing);
    }
}