// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unlit/NDF2"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        [PowerSlider(0.1)] _F0 ("F0", Range(0.0, 1.0)) = 0.02
        _a ("alpha", Range(0.0, 1.0)) = 0.1
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

            // D（GGX）の項
            float D_GGX(float3 H, float3 N) {
                float NdotH = saturate(dot(H, N));
                float roughness = saturate(_a);
                float alpha = roughness * roughness;
                float alpha2 = alpha * alpha;
                float t = ((NdotH * NdotH) * (alpha2 - 1.0) + 1.0);
                float PI = 3.1415926535897;
                return alpha2 / (PI * t * t);
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

                // D_GGXの項
                half D = D_GGX(i.normal, halfVector);

                return D;
            }
            ENDCG
        }
    }
}
