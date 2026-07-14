using UnityEngine;

[ExecuteAlways]
public class FaceDirSetter : MonoBehaviour
{
    public Transform forwardDir;
    public Transform rightDir;
    public Transform upDir;
    public Material faceMaterial; // 拖入这个模型的面部材质

    void Update()
    {
        if (faceMaterial == null) return;

        if (forwardDir) faceMaterial.SetVector("_ZmdFF", forwardDir.forward);
        if (rightDir)   faceMaterial.SetVector("_ZmdFR", rightDir.right);
        if (upDir)      faceMaterial.SetVector("_ZmdFU", upDir.up);
    }
}