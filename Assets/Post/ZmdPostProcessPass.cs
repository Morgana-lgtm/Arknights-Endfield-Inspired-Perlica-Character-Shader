using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

public class ZmdPostProcessPass : ScriptableRenderPass
{
    private readonly ZmdPostProcessFeature.LutSettings _lut;
    private readonly ZmdPostProcessFeature.EffectSettings _bloom;
    private readonly ZmdPostProcessFeature.EffectSettings _fxaa;

    private RTHandle _tmpRT, _b0, _b1;
    private Material _copyMat;
    private static readonly int BloomTexId = Shader.PropertyToID("_BloomTex");

    public bool HasAnyEffect =>
        (_lut is { enabled: true, mat: not null }) ||
        (_bloom is { enabled: true, mat: not null }) ||
        (_fxaa is { enabled: true, mat: not null });

    public ZmdPostProcessPass(ZmdPostProcessFeature.LutSettings l,
        ZmdPostProcessFeature.EffectSettings b, ZmdPostProcessFeature.EffectSettings f)
    { _lut = l; _bloom = b; _fxaa = f; }

    public void Release()
    { _tmpRT?.Release(); _b0?.Release(); _b1?.Release(); _tmpRT = _b0 = _b1 = null;
        if (_copyMat) CoreUtils.Destroy(_copyMat); _copyMat = null; }

    private Material CopyMat
    {
        get { if (!_copyMat) { var s = Shader.Find("Hidden/ZmdCopy"); if (s) _copyMat = CoreUtils.CreateEngineMaterial(s); } return _copyMat; }
    }

    private void EnsureRTs(int w, int h)
    {
        if (_tmpRT?.rt == null || _tmpRT.rt.width != w || _tmpRT.rt.height != h)
        { _tmpRT?.Release(); _tmpRT = RTHandles.Alloc(w, h, dimension: TextureDimension.Tex2D, useMipMap: false, autoGenerateMips: false, name: "Tmp"); }
        int hw = Mathf.Max(1, w / 2), hh = Mathf.Max(1, h / 2);
        if (_b0?.rt == null || _b0.rt.width != hw || _b0.rt.height != hh)
        { _b0?.Release(); _b1?.Release();
            _b0 = RTHandles.Alloc(hw, hh, dimension: TextureDimension.Tex2D, useMipMap: false, autoGenerateMips: false, name: "B0");
            _b1 = RTHandles.Alloc(hw, hh, dimension: TextureDimension.Tex2D, useMipMap: false, autoGenerateMips: false, name: "B1"); }
    }

    public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
    {
        UniversalResourceData rd = frameData.Get<UniversalResourceData>();
        UniversalCameraData cd = frameData.Get<UniversalCameraData>();
        TextureHandle camH = rd.activeColorTexture;
        int w = cd.cameraTargetDescriptor.width, h = cd.cameraTargetDescriptor.height;

        EnsureRTs(w, h);
        TextureHandle tmpH = renderGraph.ImportTexture(_tmpRT);
        TextureHandle b0H = default, b1H = default;
        bool doB = _bloom is { enabled: true, mat: not null };
        if (doB) { b0H = renderGraph.ImportTexture(_b0); b1H = renderGraph.ImportTexture(_b1); }

        bool doL = _lut is { enabled: true, mat: not null };
        bool doF = _fxaa is { enabled: true, mat: not null };
        var cm = CopyMat;

        // ── Copy cam → tmp ──
        if (cm) Blit(renderGraph, cm, camH, tmpH, 0, "CopyIn");

        // ── LUT: tmp → cam, then copy back ──
        if (doL) { if (_lut.lutTex) _lut.mat.SetTexture("_LutTex", _lut.lutTex); Blit(renderGraph, _lut.mat, tmpH, camH, 0, "LUT"); if (cm) Blit(renderGraph, cm, camH, tmpH, 0, "CopyLut"); }

        // ── Bloom ──
        if (doB)
        {
            Blit(renderGraph, _bloom.mat, tmpH, b0H, 0, "BloomPf");
            Blit(renderGraph, _bloom.mat, b0H, b1H, 1, "BloomBH");
            Blit(renderGraph, _bloom.mat, b1H, b0H, 2, "BloomBV");
            // Composite: tmp + b0 → cam
            {
                using var bc = renderGraph.AddRasterRenderPass<CompData>("BloomCmp", out var cd_);
                cd_.mat = _bloom.mat; cd_.scene = tmpH; cd_.bloom = b0H;
                bc.UseTexture(tmpH, AccessFlags.Read);
                bc.UseTexture(b0H, AccessFlags.Read);
                bc.SetRenderAttachment(camH, 0);
                bc.AllowGlobalStateModification(true);
                bc.SetRenderFunc<CompData>((d, ctx) => { ctx.cmd.SetGlobalTexture(BloomTexId, d.bloom); Blitter.BlitTexture(ctx.cmd, d.scene, Vector2.one, d.mat, 3); });
            }
            if (cm) Blit(renderGraph, cm, camH, tmpH, 0, "CopyBloom");
        }

        // ── FXAA: tmp → cam ──
        if (doF) Blit(renderGraph, _fxaa.mat, tmpH, camH, 0, "FXAA");
    }

    static void Blit(RenderGraph rg, Material m, TextureHandle src, TextureHandle dst, int pass, string name)
    {
        if (!m) return;
        using var b = rg.AddRasterRenderPass<Data>(name, out var d);
        d.mat = m; d.src = src; d.pass = pass;
        b.UseTexture(src, AccessFlags.Read);
        b.SetRenderAttachment(dst, 0);
        b.SetRenderFunc<Data>((d_, ctx) => Blitter.BlitTexture(ctx.cmd, d_.src, Vector2.one, d_.mat, d_.pass));
    }

    class Data { public Material mat; public TextureHandle src; public int pass; }
    class CompData { public Material mat; public TextureHandle scene; public TextureHandle bloom; }
}