using UnityEngine;
using UnityEditor;
using System;

internal class SuikaLitShaderGUI : ShaderGUI
{
    #region EnumDefine
    private enum AlphaMode
    {
        None,
        Cutout,
        Blend
    }

    private enum BlendMode
    {
        Blend,
        Addition,
        Custom
    }

    private enum ZWriteMode
    {
        Off,
        On
    }

    private enum GrabMode
    {
        Off,
        On
    }

    private enum UVAnimationMode
    {
        None,
        Sequence,
        Flow
    }

    #endregion
    //material.SetInt("_ZWrite", 0);
    private static class Styles
    {
        public static GUIContent uvSetLabel = EditorGUIUtility.TrTextContent("UV Set");

        public static GUIContent alphaCutoffText = EditorGUIUtility.TrTextContent("Alpha Cutoff", "Threshold for alpha cutoff");
        public static GUIContent blendSrcText = EditorGUIUtility.TrTextContent("Blend Src", "Weight of Srouce");
        public static GUIContent blendDstText = EditorGUIUtility.TrTextContent("Blend Dst", "Weight of Destination");
        public static GUIContent blendOpText = EditorGUIUtility.TrTextContent("Blend Op", "Operator of Blending");

        public static GUIContent albedoText = EditorGUIUtility.TrTextContent("Albedo", "Albedo (RGB) and Transparency (A)");
        public static GUIContent materialText = EditorGUIUtility.TrTextContent("Material", "Albedo (RGB) and Transparency (A)");
        public static GUIContent normalText = EditorGUIUtility.TrTextContent("Normal", "Normal Map");
        public static GUIContent emissionText = EditorGUIUtility.TrTextContent("Emission", "Emission Map");
        public static GUIContent maskText = EditorGUIUtility.TrTextContent("Mask", "R Channel Present the mask");
        public static GUIContent dissolveText = EditorGUIUtility.TrTextContent("Dissolve", "Control the shape of dissolve");
        public static GUIContent dissolveEdgeText = EditorGUIUtility.TrTextContent("Edge", "Control the width & color of dissolve");
        public static GUIContent warpText = EditorGUIUtility.TrTextContent("Warp", "Control the warp settings");

        // Alpha mode
        public static string blendModeText = "Alpha Modes";
        public static string primaryMapsText = "Main Maps";
        public static string AlphaMode = "Alpha Mode";
        public static string BlendMode = "Blend Mode";
        public static readonly string[] alphaNames = Enum.GetNames(typeof(AlphaMode));
        public static readonly string[] zwriteNames = Enum.GetNames(typeof(ZWriteMode));
        public static readonly string[] ztestNames = Enum.GetNames(typeof(UnityEngine.Rendering.CompareFunction));
        public static readonly string[] cullNames = Enum.GetNames(typeof(UnityEngine.Rendering.CullMode));
        public static readonly string[] blendNames = Enum.GetNames(typeof(BlendMode));
        public static readonly string[] uvaNames = Enum.GetNames(typeof(UVAnimationMode));
        public static readonly string[] grabNames = Enum.GetNames(typeof(GrabMode));
    }

    // Alpha Mode
    MaterialProperty alphaMode = null;
    MaterialProperty alphaCutoff = null;
    MaterialProperty blendSrc = null;
    MaterialProperty blendDst = null;
    MaterialProperty blendOp = null;
    MaterialProperty blendMode = null;
    MaterialProperty zwriteMode = null;
    MaterialProperty ztestMode = null;
    MaterialProperty cullMode = null;
    // Albedo Map
    MaterialProperty albedoMap = null;
    MaterialProperty albedoColor = null;
    // Normal Map
    MaterialProperty normalMap = null;
    // Other Maps
    MaterialProperty maskMap = null;
    MaterialProperty emissionMap = null;
    MaterialProperty metallicMultiplier = null;
    MaterialProperty smoothnessMultiplier = null;

    MaterialEditor m_MaterialEditor;

    bool m_FirstTimeApply = true;

    public void FindProperties(MaterialProperty[] props)
    {
        alphaMode    = FindProperty("_AlphaMode", props);
        alphaCutoff  = FindProperty("_Cutoff", props);
        blendSrc     = FindProperty("_BlendSrc", props);
        blendDst     = FindProperty("_BlendDst", props);
        blendOp      = FindProperty("_BlendOp", props);
        blendMode    = FindProperty("_BlendMode", props);
        zwriteMode   = FindProperty("_ZWrite", props);
        ztestMode    = FindProperty("_ZTest", props);
        cullMode     = FindProperty("_CullMode", props);

        albedoMap = FindProperty("_MainTex", props);
        albedoColor = FindProperty("_BaseColor", props);
        normalMap = FindProperty("_NormalTex", props);
        maskMap = FindProperty("_MaskTex", props);
        emissionMap = FindProperty("_GlowTex", props);

        metallicMultiplier = FindProperty("_Metallic", props);
        smoothnessMultiplier = FindProperty("_Smoothness", props);
    }

    void Refresh(Material material)
    {
        //RefreshUVAMode(material);
        //RefreshGRABMode(material);
    }

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        FindProperties(properties);
        m_MaterialEditor = materialEditor;
        Material material = materialEditor.target as Material;

        // Make sure that needed setup (ie keywords/renderqueue) are set up if we're switching some existing
        // material to a standard shader.
        // Do this before any GUI code has been issued to prevent layout issues in subsequent GUILayout statements (case 780071)
        if (m_FirstTimeApply)
        {
            int renderQueue = material.renderQueue;
            MaterialChanged(material, false);
            material.renderQueue = renderQueue;
            m_FirstTimeApply = false;
        }

        ShaderPropertiesGUI(material);
    }

    public void ShaderPropertiesGUI(Material material)
    {
        // Use default labelWidth
        EditorGUIUtility.labelWidth = 0f;

        bool blendModeChanged = false;

        // Detect any changes to the material
        EditorGUI.BeginChangeCheck();
        {
            GUILayout.Label(Styles.blendModeText, EditorStyles.boldLabel);
            m_MaterialEditor.RenderQueueField();
            EditorGUI.indentLevel += 2;
            blendModeChanged = BlendModePopup(material);
            DoBlendModeArea(material);
            EditorGUI.indentLevel -= 2;

            // Primary properties
            EditorGUILayout.Space();
            GUILayout.Label(Styles.primaryMapsText, EditorStyles.boldLabel);
            DoAlbedoArea(material);

            //// UV Animation properties
            //EditorGUILayout.Space();
            //GUILayout.Label("UV Animation", EditorStyles.boldLabel);
            //DoUVAnimationArea(material);

            //// Dissolve properties
            //EditorGUILayout.Space();
            //GUILayout.Label("Dissolve Settings", EditorStyles.boldLabel);
            //DoDissolveArea(material);

            //// Warp properties
            //EditorGUILayout.Space();
            //GUILayout.Label("Warp Settings", EditorStyles.boldLabel);
            //DoWarpArea(material);
        }

        //m_MaterialEditor.EnableInstancingField();
        //m_MaterialEditor.DoubleSidedGIField();
    }

    void MaterialChanged(Material material, bool overrideRenderQueue)
    {
        Refresh(material);
        //blendMode = material.GetFloat("_Mode")
    }

    #region ALPHA BLENDING
    bool BlendModePopup(Material material)
    {
        EditorGUI.showMixedValue = alphaMode.hasMixedValue;
        var mode = (AlphaMode)alphaMode.floatValue;

        EditorGUI.BeginChangeCheck();
        mode = (AlphaMode)EditorGUILayout.Popup(Styles.AlphaMode, (int)mode, Styles.alphaNames);
        bool result = EditorGUI.EndChangeCheck();
        if (result)
        {
            m_MaterialEditor.RegisterPropertyChangeUndo("Rendering Mode");
            alphaMode.floatValue = (float)mode;

            if (mode == AlphaMode.Blend)
            {
                material.EnableKeyword("BLEND");
                material.DisableKeyword("CUTOUT");
            }
            else if (mode == AlphaMode.Cutout)
            {
                material.EnableKeyword("CUTOUT");
                material.DisableKeyword("BLEND");
            }
        }

        EditorGUI.showMixedValue = false;

        return result;
    }

    // ==============================
    // * Blend Mode *
    // ==============================
    void DoBlendModeArea(Material material)
    {
        if (((AlphaMode)material.GetFloat("_Mode") == AlphaMode.Cutout))
        {
            m_MaterialEditor.ShaderProperty(alphaCutoff, Styles.alphaCutoffText.text, 0);
        }
        else if (((AlphaMode)material.GetFloat("_Mode") == AlphaMode.Blend))
        {
            var mode = (BlendMode)blendMode.floatValue;

            EditorGUI.BeginChangeCheck();
            mode = (BlendMode)EditorGUILayout.Popup(Styles.BlendMode, (int)mode, Styles.blendNames);
            bool result = EditorGUI.EndChangeCheck();
            if (result)
            {
                //m_MaterialEditor.RegisterPropertyChangeUndo("Rendering Mode");
                blendMode.floatValue = (int)mode;
                SwitchBlendMode(material);
            }
            if ((BlendMode)blendMode.floatValue == BlendMode.Custom)
            {
                m_MaterialEditor.ShaderProperty(blendSrc, Styles.blendSrcText.text, 1);
                m_MaterialEditor.ShaderProperty(blendDst, Styles.blendDstText.text, 1);
                m_MaterialEditor.ShaderProperty(blendOp, Styles.blendOpText.text, 1);
            }
        }

        EditorGUI.showMixedValue = zwriteMode.hasMixedValue;
        var zwrite_mode = (ZWriteMode)zwriteMode.floatValue;
        EditorGUI.BeginChangeCheck();
        zwrite_mode = (ZWriteMode)EditorGUILayout.Popup("ZWrite", (int)zwrite_mode, Styles.zwriteNames);
        bool zwrite_result = EditorGUI.EndChangeCheck();
        if (zwrite_result)
        {
            //m_MaterialEditor.RegisterPropertyChangeUndo("Rendering Mode");
            zwriteMode.floatValue = (float)zwrite_mode;
        }
        
        EditorGUI.showMixedValue = ztestMode.hasMixedValue;
        var ztest_mode = (UnityEngine.Rendering.CompareFunction)ztestMode.floatValue;
        EditorGUI.BeginChangeCheck();
        ztest_mode = (UnityEngine.Rendering.CompareFunction)EditorGUILayout.Popup("ZTest", (int)ztest_mode, Styles.ztestNames);
        bool ztest_result = EditorGUI.EndChangeCheck();
        if (ztest_result)
        {
            //m_MaterialEditor.RegisterPropertyChangeUndo("Rendering Mode");
            ztestMode.floatValue = (float)ztest_mode;
        }
        
        EditorGUI.showMixedValue = cullMode.hasMixedValue;
        var cull_mode = (UnityEngine.Rendering.CullMode)cullMode.floatValue;
        EditorGUI.BeginChangeCheck();
        cull_mode = (UnityEngine.Rendering.CullMode)EditorGUILayout.Popup("Culling", (int)cull_mode, Styles.cullNames);
        bool cull_result = EditorGUI.EndChangeCheck();
        if (cull_result)
        {
            //m_MaterialEditor.RegisterPropertyChangeUndo("Rendering Mode");
            cullMode.floatValue = (float)cull_mode;
        }
    }

    void SwitchBlendMode(Material material)
    {
        switch ((BlendMode)blendMode.floatValue)
        {
            case BlendMode.Blend:
                material.SetInt("_BlendSrc", (int)UnityEngine.Rendering.BlendMode.One);
                material.SetInt("_BlendDst", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                material.SetInt("_BlendOp", (int)UnityEngine.Rendering.BlendOp.Add);
                break;
            case BlendMode.Addition:
                material.SetInt("_BlendSrc", (int)UnityEngine.Rendering.BlendMode.One);
                material.SetInt("_BlendDst", (int)UnityEngine.Rendering.BlendMode.One);
                material.SetInt("_BlendOp", (int)UnityEngine.Rendering.BlendOp.Add);
                break;
        }
    }
    #endregion

    void DoAlbedoArea(Material material)
    {
        m_MaterialEditor.TexturePropertySingleLine(Styles.albedoText, albedoMap, albedoColor);
        m_MaterialEditor.TexturePropertySingleLine(Styles.materialText, maskMap, metallicMultiplier, smoothnessMultiplier);
        m_MaterialEditor.TexturePropertySingleLine(Styles.normalText, normalMap);
        m_MaterialEditor.TexturePropertySingleLine(Styles.emissionText, emissionMap);
        //m_MaterialEditor.TexturePropertySingleLine(Styles.maskText, maskMap, noiseSpeed);
        //m_MaterialEditor.ShaderProperty(noiseDensity, "Noise Density", 2);
    }

    //void DoDissolveArea(Material material)
    //{
    //    m_MaterialEditor.TexturePropertySingleLine(Styles.dissolveText, dissolveMap, dissolveInt);
    //    m_MaterialEditor.ShaderProperty(dissolveEdgeColor, "Edge Color", 2);
    //    m_MaterialEditor.ShaderProperty(dissolveEdgeWidth, "Edge Width", 2);
    //}

    //void DoWarpArea(Material material)
    //{
    //    m_MaterialEditor.TexturePropertySingleLine(Styles.warpText, warpMap, warpInt);
    //    DoGrabArea(material);
    //}

    //void DoUVAnimationArea(Material material)
    //{
    //    EditorGUI.showMixedValue = uvaMode.hasMixedValue;
    //    var mode = (UVAnimationMode)uvaMode.floatValue;

    //    EditorGUI.BeginChangeCheck();
    //    EditorGUI.indentLevel += 2;
    //    mode = (UVAnimationMode)EditorGUILayout.Popup("UVA Mode", (int)mode, Styles.uvaNames);
    //    bool result = EditorGUI.EndChangeCheck();
    //    if (result)
    //    {
    //        uvaMode.floatValue = (int)mode;
    //    }
    //    EditorGUI.indentLevel -= 2;

    //    RefreshUVAMode(material);
    //}

    //void DoGrabArea(Material material)
    //{
    //    EditorGUI.showMixedValue = grabMode.hasMixedValue;
    //    var mode = (GrabMode)grabMode.floatValue;

    //    EditorGUI.BeginChangeCheck();
    //    EditorGUI.indentLevel += 2;
    //    mode = (GrabMode)EditorGUILayout.Popup("Grab Mode", (int)mode, Styles.grabNames);
    //    bool result = EditorGUI.EndChangeCheck();
    //    if (result)
    //    {
    //        grabMode.floatValue = (int)mode;
    //    }
    //    EditorGUI.indentLevel -= 2;

    //    RefreshGRABMode(material);
    //}

    //void RefreshUVAMode(Material material)
    //{
    //    material.DisableKeyword("UVSEQ");
    //    material.DisableKeyword("UVFLOW");
    //    switch ((UVAnimationMode)uvaMode.floatValue)
    //    {
    //        case UVAnimationMode.None:
    //            break;
    //        case UVAnimationMode.Sequence:
    //            DoSequenceAniArea(material);
    //            material.EnableKeyword("UVSEQ");
    //            break;
    //        case UVAnimationMode.Flow:
    //            DoUVFlowArea(material);
    //            material.EnableKeyword("UVFLOW");
    //            break;
    //    }
    //}

    //void RefreshGRABMode(Material material)
    //{
    //    switch ((GrabMode)grabMode.floatValue)
    //    {
    //        case GrabMode.Off:
    //            material.DisableKeyword("BGON");
    //            material.EnableKeyword("BGOFF");
    //            break;
    //        case GrabMode.On:
    //            material.DisableKeyword("BGOFF");
    //            material.EnableKeyword("BGON");
    //            break;
    //    }
    //}

    //void DoSequenceAniArea(Material material)
    //{
    //    m_MaterialEditor.ShaderProperty(uvaSeqRow, "Row", 2);
    //    m_MaterialEditor.ShaderProperty(uvaSeqCol, "Colume", 2); 
    //    m_MaterialEditor.ShaderProperty(uvaSeqSpeed, "Current", 2);
    //}

    //void DoUVFlowArea(Material material)
    //{
    //    m_MaterialEditor.ShaderProperty(uvaXSpeed, "X Speed", 2);
    //    m_MaterialEditor.ShaderProperty(uvaYSpeed, "Y Speed", 2); 
    //}
}
