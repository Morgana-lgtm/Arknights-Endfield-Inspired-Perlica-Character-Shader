using UnityEngine;

[ExecuteAlways]
public class FaceDirSetter : MonoBehaviour
{
    public Transform forwardDir;  // drag head bone here
    public Transform rightDir;    // drag head bone here
    public Transform upDir;       // drag head bone here

    void Update()
    {
        if (forwardDir) Shader.SetGlobalVector("_ZmdFF", forwardDir.forward);
        if (rightDir)   Shader.SetGlobalVector("_ZmdFR", rightDir.right);
        if (upDir)      Shader.SetGlobalVector("_ZmdFU", upDir.up);
    }
}