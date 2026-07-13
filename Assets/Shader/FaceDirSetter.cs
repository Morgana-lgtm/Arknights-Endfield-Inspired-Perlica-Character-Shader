using UnityEngine;

public class FaceDirSetter : MonoBehaviour
{
    public Transform headBone;
    private Renderer faceRenderer;
    private MaterialPropertyBlock _mpb;

    void Start()
    {
        faceRenderer = GetComponent<Renderer>();
        _mpb = new MaterialPropertyBlock();
    }

    void Update()
    {
        if (faceRenderer == null || headBone == null) return;

        // Use MaterialPropertyBlock to avoid per-frame material instance creation (breaks SRP Batcher)
        faceRenderer.GetPropertyBlock(_mpb);
        _mpb.SetVector("_FaceForward", headBone.forward);
        _mpb.SetVector("_FaceRight", headBone.right);
        _mpb.SetVector("_FaceUp", headBone.up);
        faceRenderer.SetPropertyBlock(_mpb);
    }
}