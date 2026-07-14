using UnityEngine;

[ExecuteAlways]
public class FaceDirSetter : MonoBehaviour
{
    public Transform forwardDir;
    public Transform rightDir;
    public Transform upDir;

    private Renderer _r;
    private MaterialPropertyBlock _mpb = new MaterialPropertyBlock();

    void Start()
    {
        foreach (var r in GetComponentsInChildren<Renderer>(true))
            if (r.sharedMaterial != null && r.sharedMaterial.shader.name.Contains("FaceToon"))
                { _r = r; break; }
    }

    void Update()
    {
        if (_r == null) return;

        _r.GetPropertyBlock(_mpb);
        if (forwardDir) _mpb.SetVector("_ZmdFF", forwardDir.forward);
        if (rightDir)   _mpb.SetVector("_ZmdFR", rightDir.right);
        if (upDir)      _mpb.SetVector("_ZmdFU", upDir.up);
        _r.SetPropertyBlock(_mpb);
    }
}