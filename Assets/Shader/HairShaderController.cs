using UnityEngine;

// 挂载到头发网格物体上，用于驱动头发Shader所需的世界空间参数
public class HairShaderController : MonoBehaviour
{
    [Header("骨骼绑定")]
    [Tooltip("头部中心骨骼，用于球体平滑法向计算")]
    public Transform faceCenterBone;

    [Header("自动获取")]
    private Renderer hairRenderer;

    [Header("调试")]
    public bool showGizmo = true;
    public float gizmoRadius = 0.05f;
    public Vector3 centerOffset = new Vector3(0, 0.1f, -0.05f); // 先试着往上往后移
    void Start()
    {
        hairRenderer = GetComponent<Renderer>();
        if (hairRenderer == null)
        {
            Debug.LogWarning("HairShaderController: 未找到Renderer组件");
        }
    }

    void Update()
    {
        if (hairRenderer == null || faceCenterBone == null) return;

        // 使用 MaterialPropertyBlock 避免直接修改材质实例，性能更好且不会产生材质拷贝
        MaterialPropertyBlock mpb = new MaterialPropertyBlock();
        hairRenderer.GetPropertyBlock(mpb);
        mpb.SetVector("_FaceCenter", faceCenterBone.position);
        hairRenderer.SetPropertyBlock(mpb);
    }

    void OnDrawGizmosSelected()
    {
        if (!showGizmo || faceCenterBone == null) return;
        Gizmos.color = Color.yellow;
        Gizmos.DrawWireSphere(faceCenterBone.position, gizmoRadius);
        Gizmos.color = Color.cyan;
        Gizmos.DrawLine(transform.position, faceCenterBone.position);
    }
}