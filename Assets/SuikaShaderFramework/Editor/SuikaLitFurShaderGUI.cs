using UnityEngine;
using UnityEditor;
using System;

internal class SuikaLitFurShaderGUI : SuikaShaderCommonGUI
{
    /////////////////////////////////////////////////////////
    ///               Specified Style Datas               ///
    /////////////////////////////////////////////////////////
    private static class FurStyles
    {
        public static GUIContent noiseText = EditorGUIUtility.TrTextContent("Noise", "Define Fur surface");
    }
    
    /////////////////////////////////////////////////////////
    ///           Specified Material Properties           ///
    /////////////////////////////////////////////////////////
    MaterialProperty noiseTex = null;
    MaterialProperty noiseTex_ST = null;
    MaterialProperty threshold = null;
    MaterialProperty furLength = null;

    /////////////////////////////////////////////////////////
    ///            Specified Finding Properties           ///
    /////////////////////////////////////////////////////////
    public override void FindExtraProperties(MaterialProperty[] props)
    {
        noiseTex = FindProperty("_NoiseTex", props);
        noiseTex_ST = FindProperty("_NoiseTex_UV", props);
        threshold = FindProperty("_Threshold", props);
        furLength = FindProperty("_FurLength", props);
    }

    /////////////////////////////////////////////////////////
    ///              Specified Properties GUI             ///
    /////////////////////////////////////////////////////////
    public override void AdditionalPropertyGUI(Material material)
    {
        EditorGUILayout.Space();
        GUILayout.Label("Fur Settings", EditorStyles.boldLabel);
        DoFurArea(material);
    }

    void DoFurArea(Material material)
    {
        m_MaterialEditor.TexturePropertySingleLine(FurStyles.noiseText, noiseTex, noiseTex_ST, threshold);
        m_MaterialEditor.ShaderProperty(furLength, "Length", 2);
    }
}
