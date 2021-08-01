Shader "Unlit/SuikaLit"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [HDR]_BaseColor("Base Color", Color) = (1,1,1,1)
        [Normal]_NormalTex ("Normal", 2D)  = "bump" {}
        _GlowTex ("Glow", 2D) = "black" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            // Include Suika Library
            #include "include/SuikaLitInput.hlsl"
            #include "include/SuikaLighting.hlsl"
            // #include "include/pbr.cginc"

            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                // Normal Precomputation
                CalcTangentSpace(v, o.tspace0, o.tspace1, o.tspace2);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                // Fetch world space normal
                half3 wNormal = WorldNormal(i);
                
                // Light mainLight = GetMainLight();
                // sample the texture
                half4 col = tex2D(_MainTex, i.uv);
                      col *= _BaseColor;
                return col;
            }
            ENDHLSL
        }
    }
}
