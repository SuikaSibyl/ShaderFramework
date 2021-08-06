using UnityEngine;
using UnityEditor;
using System;

public class SuikaHairShaderGUI : SuikaShaderCommonGUI
{
    /////////////////////////////////////////////////////////
    ///               Specified Style Datas               ///
    /////////////////////////////////////////////////////////
    private static class HairStyles
    {
        public static GUIContent hairText = EditorGUIUtility.TrTextContent("Hair", "Hair Map");
    }

    /////////////////////////////////////////////////////////
    ///           Specified Material Properties           ///
    /////////////////////////////////////////////////////////
    MaterialProperty hairMap = null;

    /////////////////////////////////////////////////////////
    ///            Specified Finding Properties           ///
    /////////////////////////////////////////////////////////
    public override void FindExtraProperties(MaterialProperty[] props)
    {
        hairMap = FindProperty("_HairTex", props);
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
        m_MaterialEditor.TexturePropertySingleLine(HairStyles.hairText, hairMap);
    }
}
