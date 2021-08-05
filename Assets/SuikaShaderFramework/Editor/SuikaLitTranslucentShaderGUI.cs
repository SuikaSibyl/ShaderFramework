using UnityEngine;
using UnityEditor;
using System;

internal class SuikaLitTranclucentShaderGUI : SuikaShaderCommonGUI
{
    /////////////////////////////////////////////////////////
    ///               Specified Style Datas               ///
    /////////////////////////////////////////////////////////
    private static class TranslucentStyles
    {
        public static GUIContent translucentText = EditorGUIUtility.TrTextContent("Traslucent", "Traslucent Map");
    }

    /////////////////////////////////////////////////////////
    ///           Specified Material Properties           ///
    /////////////////////////////////////////////////////////
    MaterialProperty translucentMap = null;
    MaterialProperty ambientStrength = null;
    MaterialProperty attenuationSpeed = null;
    MaterialProperty distortion = null;
    MaterialProperty scaling = null;

    /////////////////////////////////////////////////////////
    ///            Specified Finding Properties           ///
    /////////////////////////////////////////////////////////
    public override void FindExtraProperties(MaterialProperty[] props)
    {
        translucentMap = FindProperty("_TranslucentTex", props);
        ambientStrength = FindProperty("_AmbientStrength", props);
        attenuationSpeed = FindProperty("_AttenuationSpeed", props);
        distortion = FindProperty("_Distortion", props);
        scaling = FindProperty("_Scaling", props);
    }

    /////////////////////////////////////////////////////////
    ///              Specified Properties GUI             ///
    /////////////////////////////////////////////////////////
    public override void AdditionalPropertyGUI(Material material)
    {
        EditorGUILayout.Space();
        GUILayout.Label("Translucent Settings", EditorStyles.boldLabel);
        DoTranslucentArea(material);
    }

    void DoTranslucentArea(Material material)
    {
        m_MaterialEditor.TexturePropertySingleLine(TranslucentStyles.translucentText, translucentMap);
        m_MaterialEditor.ShaderProperty(ambientStrength, "Ambient", 2);
        m_MaterialEditor.ShaderProperty(attenuationSpeed, "Attenuation", 2);
        m_MaterialEditor.ShaderProperty(distortion, "Distortion", 2);
        m_MaterialEditor.ShaderProperty(scaling, "scaling", 2);
    }
}
