Shader "Unlit/BRDF"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Diffuse Color", Color) = (1, 1, 1, 1)
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _a ("alpha", Range(0.0, 1.0)) = 0.1
        _k ("k", Range(0.0, 1.0)) = 0.1
         _F0 ("F0", Range(0.0, 1.0)) = 0.02
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
            #include "Lighting.cginc"

            uniform float4 _Color;
            half _a;
            half _k;
            half _F0;
            
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

            //正規分布関数
            //Nは法線、HはVとLのハーフベクトルaは表面の粗さ
            float distributionGGX(float3 N, float3 H, float alpha)
            {
                float a2 = alpha * alpha;
                float NdotH = saturate(dot(N, H));
                float NdotH2 = NdotH * NdotH;
            
                float nom = a2;
                float denom = (NdotH2 * (a2 - 1.0f) + 1.0f);
                denom = UNITY_PI * denom * denom;
            
                return nom / denom;
            }

            //ジオメトリ関数
            //Nは法線、Vは視線ベクトル、Lは入射光の逆ベクトル、kは法線
            float GeometrySchlickGGX(float3 NdotV, float3 k)
            {
                float nom = NdotV;
                float denom = NdotV * (1.0 - k) + k;
                return nom / denom;
            }
            float GeometrySmith(float3 N, float3 V, float3 L, float3 k)
            {
                float NdotV = max(dot(N, V), 0.0);
                float NdotL = max(dot(N, L), 0.0);
                float ggx1 = GeometrySchlickGGX(NdotV, k);
                float ggx2 = GeometrySchlickGGX(NdotL, k);
                return ggx1 * ggx2;
            }

            //フレネルの式
            float Flesnel(float3 V, float H, float _F0)
            {
                float VdotH = saturate(dot(V, H));
                float F0 = saturate(_F0);
                float F = F0 + (1.0f - F0) * pow(1.0f - VdotH, 5);
                return F;
            }

            // float Flesnel(float3 V, float H, float _F0)
            // {
            //     float VdotH = saturate(dot(V, H));
            //     float F0 = saturate(_F0);
            //     float F = pow(1.0 - VdotH, 5.0);
            //     F *= (1.0 - F0);
            //     F += F0;
            //     return F;
            // }
            
            sampler2D _MainTex;
            float4 _MainTex_ST;

            //フレネルの式
            //cosThetaは法線nと視点方向vとの内積
            // half fresnelSchlick(float cosTheta, half F0, v2f i)
            // {
            //     _F0 = lerp(_F0, tex2D(_MainTex, i.uv), 0.5f);
            //     return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
            //    // half fresnel = _F0 + (1.0h - _F0) * pow(1.0h - i.vdotn, 5);
            //    //  return fresnel;
            // }

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
                float3 ambientlight = unity_AmbientEquator.xyz * _Color.rgb;
                
                float3 lightDirectionNormal = normalize(_WorldSpaceLightPos0.xyz);
                float NdotL = saturate(dot(i.normal, lightDirectionNormal));
                // ワールド空間上の視点（カメラ）位置と法線との内積を計算
                float3 viewDirectionNormal = normalize((float4(_WorldSpaceCameraPos, 1.0) - i.vpos).xyz);
                float NdotV = saturate(dot(i.normal, viewDirectionNormal));
                // ライトと視点ベクトルのハーフベクトルを計算
                float3 halfVector = normalize(lightDirectionNormal + viewDirectionNormal);


                

                // D_GGXの項
                float D = distributionGGX(i.normal, halfVector, _a);

                float G = GeometrySmith(i.normal, viewDirectionNormal, lightDirectionNormal, _k);

                float F = Flesnel(viewDirectionNormal, halfVector, _F0);

                float cookTransModel = (D * G * F) / (4 * NdotL * NdotV + 0.000001);

                float diffuseReflection = _LightColor0.xyz * _Color.xyz * NdotL;

                // 最後に色を合算して出力
                return float4(ambientlight + diffuseReflection + cookTransModel, 1.0);

                // return tex2D(_MainTex, i.uv) * cookTransModel * diffuseReflection;
            }
            ENDCG
        }
    }
}
