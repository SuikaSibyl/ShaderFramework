using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Experimental.Rendering.Universal;
using System.Collections.Generic;

public class FurRenderFeature : ScriptableRendererFeature
{
    // A Setting Class
    // ------------------------------------
    // Indicate the Filtering settings
    [System.Serializable]
    public class FilterSettings
    {
        public RenderQueueType RenderQueueType;
        public LayerMask LayerMask = 1;
        public string[] PassNames;

        public FilterSettings()
        {
            RenderQueueType = RenderQueueType.Opaque;
            LayerMask = ~0;
            PassNames = new string[] { "FurRendererBase", "FurRendererLayer" };
        }
    }

    // A Setting Class
    // ------------------------------------
    // Indicate the All the detail settings for the render feature
    [System.Serializable]
    public class PassSettings
    {
        public string passProfilerTag = "FurRenderer";
        [Header("Settings")]
        public bool ShouldRender = true;
        [Tooltip("Set Layer Num")]
        [Range(1, 200)] public int PassLayerNum = 20;
        [Range(1000, 5000)] public int QueueMin = 2000;
        [Range(1000, 5000)] public int QueueMax = 5000;
        public RenderPassEvent PassEvent = RenderPassEvent.AfterRenderingSkybox;

        public FilterSettings filterSettings = new FilterSettings();
    }

    class FurRenderPass : ScriptableRenderPass
    {
        string m_ProfilerTag;
        PassSettings settings;

        // Filtering stuffs
        // -------------------
        FilteringSettings filter;
        List<ShaderTagId> m_ShaderTagIdList = new List<ShaderTagId>();
        DrawingSettings baseDrawingSetting, layerDrawingSetting;

        // ==============================================
        // Constructor of the render pass
        // ==============================================
        public FurRenderPass(PassSettings setting)
        {
            this.settings = setting;

            // Set the filter conditions
            // ---------------------------------------------
            // Build the render queue with the range
            RenderQueueRange queue = new RenderQueueRange();
            queue.lowerBound = settings.QueueMin;
            queue.upperBound = settings.QueueMax;
            // Build the filter with render queue & layermask
            filter = new FilteringSettings(queue, setting.filterSettings.LayerMask);
            // Build the ShaderTags in list
            string[] shaderTags = setting.filterSettings.PassNames;
            if (shaderTags != null && shaderTags.Length > 0)
                foreach (var passName in shaderTags)
                    m_ShaderTagIdList.Add(new ShaderTagId(passName));
        }

        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in a performant manner.
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {            
            //SortingCriteria sortingCriteria = (renderQueueType == RenderQueueType.Transparent)
            //    ? SortingCriteria.CommonTransparent
            //    : renderingData.cameraData.defaultOpaqueSortFlags;

            //Base DrawingSetting
            if (m_ShaderTagIdList.Count > 0)
                baseDrawingSetting = CreateDrawingSettings(m_ShaderTagIdList[0], ref renderingData,
                    renderingData.cameraData.defaultOpaqueSortFlags);
            else return;

            //Layer DrawingSetting
            if (m_ShaderTagIdList.Count > 1)
                layerDrawingSetting = CreateDrawingSettings(m_ShaderTagIdList[1], ref renderingData,
                    renderingData.cameraData.defaultOpaqueSortFlags);
            else return;
        }

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            // Get the command buffer
            CommandBuffer cmd = CommandBufferPool.Get(settings.passProfilerTag);

            // BaseLayer
            cmd.Clear();
            cmd.SetGlobalFloat("_FUR_OFFSET", 0);
            context.ExecuteCommandBuffer(cmd);
            context.DrawRenderers(renderingData.cullResults, ref baseDrawingSetting, ref filter);

            // TransparentLayer
            float inter = 1.0f / settings.PassLayerNum;
            for (int i = 1; i < settings.PassLayerNum; i++)
            {
                cmd.Clear();
                cmd.SetGlobalFloat("_FUR_OFFSET", i * inter);
                context.ExecuteCommandBuffer(cmd);
                context.DrawRenderers(renderingData.cullResults, ref layerDrawingSetting, ref filter);
            }
            CommandBufferPool.Release(cmd);
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {

        }
    }

    public PassSettings settings = new PassSettings();
    FurRenderPass m_ScriptablePass;

    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new FurRenderPass(settings);

        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


