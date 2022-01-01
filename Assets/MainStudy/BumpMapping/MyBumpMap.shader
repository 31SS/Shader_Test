Shader "Unlit/MyBumpMap"
{
    Properties
    {
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _NormalMap ("Normal map", 2D) = "bump" {}
        _Shininess ("Shininess", Range(0.0, 1.0)) = 0.078125
    }
    SubShader
    {
        Tags { "Queue"="Geometry" "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Tags { "LightMode"="ForwardBase" }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                // float4 binNormal : BINORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                half3 lightDir : TEXCOORD1;
                half3 viewDir : TEXCOORD2;
                float4 pos : SV_POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            float4 _MainTex_ST;
            float4 _LightColor0;
            sampler2D _MainTex;
            sampler2D _NormalMap;
            half _Shininess;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv.xy;
                // 接空間におけるライト方向のベクトルと視点方向のベクトルを求める
                TANGENT_SPACE_ROTATION;
                o.lightDir = mul(rotation, ObjSpaceLightDir(v.vertex));
                o.viewDir = mul(rotation, ObjSpaceViewDir(v.vertex));
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                i.lightDir = normalize(i.lightDir);
                i.viewDir = normalize(i.viewDir);
                half3 halfDir = normalize(i.lightDir + i.viewDir);

                half4 tex = tex2D(_MainTex, i.uv);

                // ノーマルマップから法線情報を取得する
                half3 normal = UnpackNormal(tex2D(_NormalMap, i.uv));

                // ノーマルマップから得た法線情報をつかってライティング計算をする
                half4 diff = saturate(dot(normal, i.lightDir)) * _LightColor0;
                half3 spec = pow(max(0, dot(normal, halfDir)), _Shininess * 128.0) * _LightColor0.rgb * tex.rgb;

                fixed4 color;
                color.rgb  = tex.rgb * diff + spec;
                return color;
            }
            ENDCG
        }
    }
}
