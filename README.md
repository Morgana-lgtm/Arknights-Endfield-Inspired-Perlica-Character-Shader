# Arknights Endfield Inspired — Perlica Character Shader

基于 Unity 6 (URP 17.3) 的卡通风格角色渲染项目，以《明日方舟：终末地》佩丽卡（Perlica）为参考。

## 渲染特性

### 基础光照系统
- **Sigmoid 卡通阶跃阴影**：硬边 + 可调软硬过渡
- **晴天/阴天双模式混合**：`_DayStrength` 在两个光照状态间插值
- **背光补偿**：逆光时 Ramp UV 自动偏移，提亮暗部
- **三层漫反射 BRDF**：亮部 → 暗部 → 暗中暗，Ramp 图染色
- **饱和度自适应 Ramp 混合**：灰白区域弱化染色，鲜艳区域加强
- **顶光补光**：可调法线偏移 + 基础底光，防止下巴死黑

### 各部位专用 Shader

| Shader | 特点 |
|--------|------|
| **ToonBaseShader** | 通用 PBR + 卡通风格，含 SSS 透光 / 高光细化 Feature |
| **SkinToonShader** | 皮肤 LUT 暗部取色 + SSS 透光 + 粗糙度控制 |
| **FaceToonShader** | SDF 面部光影 + 表情贴图 + 球形法线 RIM |
| **HairToonShader** | Kajiya-Kay 各向异性高光 + 法线压平 + 背面描边 |
| **EyeToonShader** | 角膜法线球面化 + MatCap 高光 + 颜色 Trick |
| **Outline Shader** | 背面法线外扩描边，带深度缩放 |
| **BangsShadowSimple** | 刘海投影（沿光照方向偏移） |

### 后处理系统

| 效果 | 说明 |
|------|------|
| **LUT 调色** | 32×32×32 3D LUT 查表 + 曝光/对比度/饱和度/伽马 |
| **Bloom** | 预过滤 → 高斯模糊(H+V) → 合成 |
| **FXAA** | 自适应边缘检测抗锯齿 |

## 代码架构

```
Assets/
├── Shader/
│   ├── ZmdToonCore.hlsl         # 统一 CBUFFER + 结构体 + Vert + 工具函数
│   ├── ZmdToonLighting.hlsl     # 光源/阴影/Ramp/漫反射 BRDF
│   ├── ZmdToonSpecular.hlsl     # GGX/IBL 拟合/Fresnel Rim/NoLxz Rim
│   ├── ToonBaseShader.shader    # 通用卡通 (含 SSS + SpecularRefine Features)
│   ├── SkinToonShader.shader    # 皮肤
│   ├── FaceToonShader.shader    # 面部
│   ├── HairToonShader.shader    # 头发 + 描边
│   ├── EyeToonShader.shader     # 眼睛
│   ├── Outline shader.shader    # 描边 (Hair 的 UsePass 引用)
│   ├── BangsShadowSimple.shader # 刘海投影
│   ├── EyeShadowShader.shader   # 眼影
│   ├── FaceDirSetter.cs         # 面部方向设置 (MaterialPropertyBlock)
│   └── HairShaderController.cs  # 头发球心设置 (MaterialPropertyBlock)
├── Post/
│   ├── ZmdPostProcessFeature.cs # 后处理 Feature
│   ├── ZmdPostProcessPass.cs    # 后处理 Pass
│   ├── Hidden_ZmdColorGrading.shader  # LUT 调色
│   ├── Hidden_ZmdBloom.shader         # Bloom
│   ├── Hidden_ZmdFXAA.shader          # FXAA
│   ├── Hidden_ZmdCopy.shader          # 纹理拷贝
│   ├── Hidden_ZmdTest.shader          # 测试 Shader
│   ├── ZmdTestFeature.cs              # 测试 Feature
│   ├── NeutralLUT.png                 # 标准 LUT 图
│   ├── ZmdLut.mat / ZmdBloom.mat / ZmdFxaa.mat  # 后处理材质
│   └── GenerateNeutralLUT.cs          # LUT 生成工具
└── Settings/
    ├── PC_Renderer.asset        # PC 管线配置
    └── Mobile_Renderer.asset    # 移动端管线配置
```

## 材质参数指南

### ORM 贴图通道

| 通道 | 含义 |
|------|------|
| **R** | 金属度 (Metallic) |
| **G** | 反射率 (Reflectivity) |
| **B** | AO 遮蔽 |
| **A** | 光滑度 (Smoothness) |

### 头发 Kajiya-Kay 高光

- `_HairSpecularTex` — 高光颜色 LUT（U 轴=角度，V 轴=位置）
- `_SpecularPowStrength` — 高光锐度（默认 20）
- `_SpecularTrick_Flatten` — 法向压平（模拟圆柱）
- ORM.R 通道控制球心混合度

### 面部 SDF

- `_SdfTex` — SDF 魔法图（RG=阈值范围，B=RIM 方向）
- `_SdfRefineTex` — Refine 图（R=SSS 范围，G=脖子衔接，A=RIM Mask）
- `_FaceForward/Right/Up` — 由 FaceDirSetter.cs 自动设置

## 环境要求

- Unity 6000.3.11f1+
- Universal Render Pipeline 17.3+
- Shader 使用 HLSL + RenderGraph API

## 使用说明

1. 将 `PC_Renderer.asset` 或 `Mobile_Renderer.asset` 赋给对应 Quality 等级的 Renderer
2. 材质使用对应的 Custom Shader
3. 后处理在 Renderer 上添加 `ZmdPostProcessFeature` 并填入对应材质
4. 面部材质所在 GameObject 挂 `FaceDirSetter`，指定头部骨骼
5. 头发材质所在 GameObject 挂 `HairShaderController`，指定面部中心骨骼
