using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

public class ZmdTestFeature : ScriptableRendererFeature
{
    public Material testMat;
    private ZmdTestPass _pass;

    public override void Create() { _pass = new ZmdTestPass(testMat); _pass.renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing; }
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    { if (_pass != null && testMat != null) renderer.EnqueuePass(_pass); }
}

class ZmdTestPass : ScriptableRenderPass
{
    private readonly Material _mat;
    private RTHandle _tmp;

    public ZmdTestPass(Material mat) { _mat = mat; }

    public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
    {
        if (_mat == null) return;

        UniversalResourceData rd = frameData.Get<UniversalResourceData>();
        UniversalCameraData cd = frameData.Get<UniversalCameraData>();
        TextureHandle sceneH = rd.activeColorTexture;
        int w = cd.cameraTargetDescriptor.width, h = cd.cameraTargetDescriptor.height;

        // Create temp RT
        if (_tmp?.rt == null || _tmp.rt.width != w || _tmp.rt.height != h)
        { _tmp?.Release(); _tmp = RTHandles.Alloc(w, h, dimension: TextureDimension.Tex2D, useMipMap: false, autoGenerateMips: false, name: "Tmp"); }
        TextureHandle tmpH = renderGraph.ImportTexture(_tmp);

        // ── Pass 1: copy scene → tmp ──
        // Tests whether UseTexture auto-binds _BlitTexture for shader reading
        {
            using var b = renderGraph.AddRasterRenderPass<Data>("TestCopy_SceneToTmp", out var d);
            d.mat = _mat;
            b.UseTexture(sceneH, AccessFlags.Read);
            b.SetRenderAttachment(tmpH, 0);
            b.SetRenderFunc<Data>((d_, ctx) =>
                ctx.cmd.DrawProcedural(Matrix4x4.identity, d_.mat, 0, MeshTopology.Triangles, 3));
        }

        // ── Pass 2: copy tmp → scene ──
        {
            using var b = renderGraph.AddRasterRenderPass<Data>("TestCopy_TmpToScene", out var d);
            d.mat = _mat;
            b.UseTexture(tmpH, AccessFlags.Read);
            b.SetRenderAttachment(sceneH, 0);
            b.SetRenderFunc<Data>((d_, ctx) =>
                ctx.cmd.DrawProcedural(Matrix4x4.identity, d_.mat, 0, MeshTopology.Triangles, 3));
        }
    }

    class Data { public Material mat; }
}