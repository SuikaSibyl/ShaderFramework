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
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            // Include Suika Library
            #include "include/SuikaLitInput.hlsl"
            #include "include/lighting.cginc"
            #include "include/pbr.cginc"

            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                    // Clac TBN

                CalcTangentSpace(v, o);
                half3 wNormal = UnityObjectToWorldNormal(v.normal);
                half3 wTangent = UnityObjectToWorldDir(v.tangent.xyz);
                half tangentSign = v.tangent.w * unity_WorldTransformParams.w;
                // Cross({World Space} Normal, Tangent), Get Bitangent
                half3 wBitangent = cross(wNormal, wTangent) * tangentSign;
                // o.tspace0 = half3(0, 0, 0);
                // o.tspace1 = half3(wTangent.y, wBitangent.y, wNormal.y);
                // o.tspace2 = half3(wTangent.z, wBitangent.z, wNormal.z);

                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                fixed3  tNormal = normalize(UnpackNormal(tex2D(_NormalTex, i.uv)).xyz);
                half3 wNormal = NormalTangentToWorld(tNormal, i);
                // sample the texture
                half4 col = tex2D(_MainTex, i.uv);
                      col *= _BaseColor;
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return half4(wNormal,1);
            }
            ENDCG
        }
    }
}
