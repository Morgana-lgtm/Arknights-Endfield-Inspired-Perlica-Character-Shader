using UnityEngine;
using UnityEditor;
using System.IO;

public class GenerateNeutralLUT
{
    [MenuItem("Tools/Generate Neutral LUT")]
    static void Generate()
    {
        const int size = 32;

        Texture2D tex = new Texture2D(size * size, size, TextureFormat.RGBA32, false, true);
        tex.wrapMode = TextureWrapMode.Clamp;

        for (int b = 0; b < size; b++)
        {
            int tileX = b % size;

            for (int g = 0; g < size; g++)
            {
                for (int r = 0; r < size; r++)
                {
                    Color c = new Color(
                        r / 31.0f,
                        g / 31.0f,
                        b / 31.0f,
                        1);

                    tex.SetPixel(
                        tileX * size + r,
                        g,
                        c);
                }
            }
        }

        tex.Apply();

        byte[] png = tex.EncodeToPNG();

        File.WriteAllBytes("Assets/NeutralLUT.png", png);

        AssetDatabase.Refresh();

        Debug.Log("Neutral LUT Generated");
    }
}