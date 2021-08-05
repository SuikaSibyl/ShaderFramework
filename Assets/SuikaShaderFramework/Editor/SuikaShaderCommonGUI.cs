using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System;

public class SuikaShaderCommonGUI : ShaderGUI
{
    /////////////////////////////////////////////////////////
    ///               Common Enum Definition              ///
    /////////////////////////////////////////////////////////
    #region EnumDefine
    protected enum AlphaMode
    {
        None,
        Cutout,
        Blend
    }

    protected enum BlendMode
    {
        Blend,
        Addition,
        Custom
    }

    protected enum WorkflowMode
    {
        RoughnessMetallic,
        SpecularGloss,
    }

    protected enum ZWriteMode
    {
        Off,
        On
    }
    #endregion

    /////////////////////////////////////////////////////////
    ///            Common Properties Definition           ///
    /////////////////////////////////////////////////////////
    #region PropertiesDefine
    // Alpha Mode
    protected MaterialProperty alphaMode = null;
    protected MaterialProperty workflowMode = null;
    protected MaterialProperty alphaCutoff = null;
    protected MaterialProperty blendSrc = null;
    protected MaterialProperty blendDst = null;
    protected MaterialProperty blendOp = null;
    protected MaterialProperty blendMode = null;
    protected MaterialProperty zwriteMode = null;
    protected MaterialProperty ztestMode = null;
    protected MaterialProperty cullMode = null;
    // Albedo Map
    protected MaterialProperty albedoMap = null;
    protected MaterialProperty albedoColor = null;
    // Normal Map
    protected MaterialProperty normalMap = null;
    // Other Maps
    protected MaterialProperty maskMap = null;
    protected MaterialProperty emissionMap = null;
    protected MaterialProperty metallicMultiplier = null;
    protected MaterialProperty smoothnessMultiplier = null;
    // Material Editor
    protected MaterialEditor m_MaterialEditor;
    // First Time Apply
    protected bool m_FirstTimeApply = true;
    #endregion

    /////////////////////////////////////////////////////////
    ///               Common Style Definition             ///
    /////////////////////////////////////////////////////////
    #region StyleDefine
    protected static class Styles
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
        public static readonly string[] workflowNames = Enum.GetNames(typeof(WorkflowMode));
        public static readonly string[] zwriteNames = Enum.GetNames(typeof(ZWriteMode));
        public static readonly string[] ztestNames = Enum.GetNames(typeof(UnityEngine.Rendering.CompareFunction));
        public static readonly string[] cullNames = Enum.GetNames(typeof(UnityEngine.Rendering.CullMode));
        public static readonly string[] blendNames = Enum.GetNames(typeof(BlendMode));
    }
    #endregion

    /////////////////////////////////////////////////////////
    ///            Common Function Definition             ///
    /////////////////////////////////////////////////////////
    #region FindProperties
    public void FindPropertiesBase(MaterialProperty[] props)
    {
        alphaMode = FindProperty("_Mode", props);
        workflowMode = FindProperty("_Workflow", props);
        alphaCutoff = FindProperty("_Cutoff", props);
        blendSrc = FindProperty("_BlendSrc", props);
        blendDst = FindProperty("_BlendDst", props);
        blendOp = FindProperty("_BlendOp", props);
        blendMode = FindProperty("_BlendMode", props);
        zwriteMode = FindProperty("_ZWrite", props);
        ztestMode = FindProperty("_ZTest", props);
        cullMode = FindProperty("_CullMode", props);

        albedoMap = FindProperty("_MainTex", props);
        albedoColor = FindProperty("_BaseColor", props);
        normalMap = FindProperty("_NormalTex", props);
        maskMap = FindProperty("_MaskTex", props);
        emissionMap = FindProperty("_GlowTex", props);

        metallicMultiplier = FindProperty("_Metallic", props);
        smoothnessMultiplier = FindProperty("_Smoothness", props);

        FindExtraProperties(props);
    }

    public virtual void FindExtraProperties(MaterialProperty[] props)
    {

    }

    #endregion

    /////////////////////////////////////////////////////////
    ///            Common Function Definition             ///
    /////////////////////////////////////////////////////////
    #region OnGuiBase
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        // ==================================
        // Detail Descriptions of Shader GUI
        // ==================================
        FindPropertiesBase(properties);
        m_MaterialEditor = materialEditor;
        Material material = materialEditor.target as Material;

        // ==================================
        // Init the Render Queue Info
        // ==================================
        if (m_FirstTimeApply)
        {
            // init render queue
            int renderQueue = material.renderQueue;
            material.renderQueue = renderQueue;
            m_FirstTimeApply = false;

            // init Blend mode
            material.SetInt("_BlendSrc", (int)UnityEngine.Rendering.BlendMode.One);
            material.SetInt("_BlendDst", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
            material.SetInt("_BlendOp", (int)UnityEngine.Rendering.BlendOp.Add);
        }

        // ==================================
        // Detail Descriptions of Shader GUI
        // ==================================
        ShaderPropertiesGUI(material);
    }
    #endregion

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

            AdditionalPropertyGUI(material);
        }
    }

    public virtual void AdditionalPropertyGUI(Material material)
    {

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

            if (mode == AlphaMode.None)
            {
                material.DisableKeyword("BLEND");
                material.DisableKeyword("CUTOUT");
                material.SetInt("_BlendSrc", (int)UnityEngine.Rendering.BlendMode.One);
                material.SetInt("_BlendDst", (int)UnityEngine.Rendering.BlendMode.Zero);
                material.SetInt("_BlendOp", (int)UnityEngine.Rendering.BlendOp.Add);
            }
            else if (mode == AlphaMode.Blend)
            {
                material.EnableKeyword("BLEND");
                material.DisableKeyword("CUTOUT");
                SwitchBlendMode(material);
            }
            else if (mode == AlphaMode.Cutout)
            {
                material.EnableKeyword("CUTOUT");
                material.DisableKeyword("BLEND");
                material.SetInt("_BlendSrc", (int)UnityEngine.Rendering.BlendMode.One);
                material.SetInt("_BlendDst", (int)UnityEngine.Rendering.BlendMode.Zero);
                material.SetInt("_BlendOp", (int)UnityEngine.Rendering.BlendOp.Add);
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

    void SelectWorkflow(Material material)
    {
        EditorGUI.showMixedValue = workflowMode.hasMixedValue;
        var workflow_mode = (WorkflowMode)workflowMode.floatValue;
        EditorGUI.BeginChangeCheck();
        workflow_mode = (WorkflowMode)EditorGUILayout.Popup("Workflow", (int)workflow_mode, Styles.workflowNames);
        bool workflow_result = EditorGUI.EndChangeCheck();
        if (workflow_result)
        {
            workflowMode.floatValue = (float)workflow_mode;

            switch ((WorkflowMode)workflowMode.floatValue)
            {
                case WorkflowMode.RoughnessMetallic:
                    material.EnableKeyword("_RoughnessMetallic");
                    material.DisableKeyword("_SpecularGloss");
                    break;
                case WorkflowMode.SpecularGloss:
                    material.EnableKeyword("_SpecularGloss");
                    material.DisableKeyword("_RoughnessMetallic");
                    break;
            }
        }
    }

    void DoAlbedoArea(Material material)
    {
        SelectWorkflow(material);
        m_MaterialEditor.TexturePropertySingleLine(Styles.albedoText, albedoMap, albedoColor);
        m_MaterialEditor.TexturePropertySingleLine(Styles.materialText, maskMap, metallicMultiplier, smoothnessMultiplier);
        m_MaterialEditor.TexturePropertySingleLine(Styles.normalText, normalMap);
        m_MaterialEditor.TexturePropertySingleLine(Styles.emissionText, emissionMap);
    }
    #endregion
}
