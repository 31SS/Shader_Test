Shader "Unlit/GGX"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        [PowerSlider(0.1)] _F0 ("F0", Range(0.0, 1.0)) = 0.02
        _a ("alpha", Range(0.0, 1.0)) = 0.1
        _k ("alpha", Range(0.0, 1.0)) = 0.1
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

            half _F0;
            half _a;
            half _k;
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float4 vpos :TEXCOORD4;
                UNITY_FOG_COORDS(1)
                float4 pos : SV_POSITION;
            };

            // G - 幾何減衰の項（クック トランスモデル）
            float G_CookTorrance(float3 L, float3 V, float3 H, float3 N)
            {
                float NdotH = saturate(dot(N, H));
                float NdotL = saturate(dot(N, L));
                float NdotV = saturate(dot(N, V));
                float VdotH = saturate(dot(V, H));

                float NH2 = 2.0 * NdotH;
                float g1 = (NH2 * NdotV) / VdotH;
                float g2 = (NH2 * NdotL) / VdotH;
                float G = min(1.0, min(g1, g2));
                return G;
            }
            
            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);

                // ワールド空間での法線を計算
                o.normal = normalize(mul(unity_ObjectToWorld, float4(v.normal, 0.0)).xyz);

                // 該当ピクセルのライティングに、ワールド空間上での位置を保持しておく
                o.vpos = mul(unity_ObjectToWorld, v.vertex);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 lightDirectionNormal = normalize(_WorldSpaceLightPos0.xyz);
                float NdotL = saturate(dot(i.normal, lightDirectionNormal));
                // ワールド空間上の視点（カメラ）位置と法線との内積を計算
                float3 viewDirectionNormal = normalize((float4(_WorldSpaceCameraPos, 1.0) - i.vpos).xyz);
                float NdotV = saturate(dot(i.normal, viewDirectionNormal));
                // ライトと視点ベクトルのハーフベクトルを計算
                float3 halfVector = normalize(lightDirectionNormal + viewDirectionNormal);

                float G = G_CookTorrance(lightDirectionNormal, viewDirectionNormal, halfVector, i.normal);

                return G;
            }
            ENDCG
        }
    }
}
