using UnityEngine;

[ExecuteAlways]
public class FaceDirSetter : MonoBehaviour
{
    public Transform forwardDir;
    public Renderer faceRenderer;

    private MaterialPropertyBlock _mpb = new MaterialPropertyBlock();

    void Update()
    {
        if (forwardDir == null || faceRenderer == null) return;

        faceRenderer.GetPropertyBlock(_mpb);
        _mpb.SetVector("_ZmdFF", forwardDir.forward);
        _mpb.SetVector("_ZmdFR", forwardDir.right);
        _mpb.SetVector("_ZmdFU", forwardDir.up);
        faceRenderer.SetPropertyBlock(_mpb);
    }
}