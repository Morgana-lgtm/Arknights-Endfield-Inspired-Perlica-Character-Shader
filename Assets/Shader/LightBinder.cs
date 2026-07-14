using UnityEngine;

/// <summary>
/// 将场景中的点光源绑定到 Shader 的额外光（_OtherLight）参数。
/// 每帧自动同步光源颜色、强度和方向。
/// </summary>
[ExecuteAlways]
public class LightBinder : MonoBehaviour
{
    [Header("绑定光源")]
    [Tooltip("留空则自动查找场景中最亮的点光源")]
    public Light targetLight;

    [Header("目标材质")]
    [Tooltip("留空则使用当前 GameObject 的 Renderer 材质")]
    public Renderer targetRenderer;

    [Header("参数映射")]
    [Range(0, 2)] public float intensityScale = 0.3f;
    [Range(0, 0.5f)] public float baseBrightness = 0.1f;
    [Range(-1, 1)] public float normalOffset = 0f;

    private MaterialPropertyBlock _mpb;
    private static readonly int ColorId   = Shader.PropertyToID("_OtherLightColor");
    private static readonly int DirId     = Shader.PropertyToID("_OtherLightDir");
    private static readonly int StrengthId= Shader.PropertyToID("_OtherLightStrength");
    private static readonly int OffsetId  = Shader.PropertyToID("_OtherLightStrength_Offset");
    private static readonly int NmlBiasId = Shader.PropertyToID("_OtherLightOffset");

    void Awake()
    {
        _mpb = new MaterialPropertyBlock();

        if (targetRenderer == null)
            targetRenderer = GetComponent<Renderer>();

        if (targetLight == null)
            targetLight = FindBrightestPointLight();
    }

    void Update()
    {
        if (targetRenderer == null || targetLight == null || _mpb == null) return;

        targetRenderer.GetPropertyBlock(_mpb);

        // Direction: from fragment to light
        Vector3 dir = (targetLight.transform.position - transform.position).normalized;
        _mpb.SetVector(DirId, dir);

        // Color + intensity
        Color col = targetLight.color;
        col.a = 1f;
        _mpb.SetVector(ColorId, col);
        _mpb.SetFloat(StrengthId, targetLight.intensity * intensityScale);
        _mpb.SetFloat(OffsetId, baseBrightness);
        _mpb.SetFloat(NmlBiasId, normalOffset);

        targetRenderer.SetPropertyBlock(_mpb);
    }

    void OnDisable()
    {
        // Reset to default top-down light
        if (targetRenderer != null && _mpb != null)
        {
            targetRenderer.GetPropertyBlock(_mpb);
            _mpb.SetVector(DirId, Vector3.up);
            _mpb.SetVector(ColorId, new Color(0.9f, 0.95f, 1f, 1f));
            _mpb.SetFloat(StrengthId, 0.3f);
            _mpb.SetFloat(OffsetId, 0.1f);
            _mpb.SetFloat(NmlBiasId, 0f);
            targetRenderer.SetPropertyBlock(_mpb);
        }
    }

    void OnValidate()
    {
        if (intensityScale < 0) intensityScale = 0;
        if (baseBrightness < 0) baseBrightness = 0;
    }

    /// <summary>自动查找场景中最亮的点光源</summary>
    static Light FindBrightestPointLight()
    {
        Light best = null;
        float bestVal = -1f;
        foreach (var l in FindObjectsOfType<Light>())
        {
            if (l.type != LightType.Point) continue;
            float v = l.intensity * (0.299f * l.color.r + 0.587f * l.color.g + 0.114f * l.color.b);
            if (v > bestVal) { bestVal = v; best = l; }
        }
        return best;
    }
}