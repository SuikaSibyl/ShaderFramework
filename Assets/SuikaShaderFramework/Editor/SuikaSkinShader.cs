using UnityEngine;
using UnityEditor;
using System;

public class SuikaSkinShader : SuikaShaderCommonGUI
{
    /////////////////////////////////////////////////////////
    ///               Specified Style Datas               ///
    /////////////////////////////////////////////////////////
    private static class SkinStyles
    {
        public static GUIContent skinText = EditorGUIUtility.TrTextContent("Skin", "Skin Map");
        public static GUIContent lutText = EditorGUIUtility.TrTextContent("LUT", "LUT Map");
    }

    /////////////////////////////////////////////////////////
    ///           Specified Material Properties           ///
    /////////////////////////////////////////////////////////
    MaterialProperty skinMap = null;
    MaterialProperty lutMap = null;

    /////////////////////////////////////////////////////////
    ///            Specified Finding Properties           ///
    /////////////////////////////////////////////////////////
    public override void FindExtraProperties(MaterialProperty[] props)
    {
        skinMap = FindProperty("_SkinTex", props);
        lutMap = FindProperty("_LUTTex", props);
    }

    /////////////////////////////////////////////////////////
    ///              Specified Properties GUI             ///
    /////////////////////////////////////////////////////////
    public override void AdditionalPropertyGUI(Material material)
    {
        EditorGUILayout.Space();
        GUILayout.Label("Hair Settings", EditorStyles.boldLabel);
        DoHairArea(material);
    }

    void DoHairArea(Material material)
    {
        m_MaterialEditor.TexturePropertySingleLine(SkinStyles.skinText, skinMap);
        m_MaterialEditor.TexturePropertySingleLine(SkinStyles.skinText, lutMap);
    }
}
