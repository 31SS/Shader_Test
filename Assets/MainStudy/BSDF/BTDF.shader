Shader "BTDF"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _D_Roughness ("D_Roughness", Range(0.0, 1.0)) = 0.1
        _G_Roughness ("G_Roughness", Range(0.0, 1.0)) = 0.1
        _F0 ("Fresnel Reflection Coefficient", Range(0.0, 1.0)) = 0.02
        _R_i ("η_i", Range(0.0, 2.0)) = 1.0
        _R_o ("η_o", Range(0.0, 2.0)) = 1.5
        _Roughness ("_Roughness", Range(0.0, 1.0)) = 0.1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Lightmode" = "ForwardBase"}
        LOD 100

        Pass
        {            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityStandardUtils.cginc"
            #include "Lighting.cginc"

            float _Roughness;
            half _D_Roughness;
            half _G_Roughness;
            half _F0;
            half _R_i;
            half _R_o;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                half2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float4 worldPos :TEXCOORD2;
                half3 viewDir : TEXCOORD3;
                half4 ambient : TEXCOORD4;
            };                        

            float3 InnerProduct(float3 x, float3 y)
            {
                return saturate(dot(x, y));
            }
            
            // <summary>
            // 正規分布関数
            // <summary>
            // <param name="N">法線</param>
            // <param name="H">ハーフベクトル</param>
            // <param name="alpha">表面の粗さ</param>
            
            //Nは法線、HはVとLのハーフベクトルaは表面の粗さ
            float distributionGGX(float3 N, float3 H)
            {
                float a = _D_Roughness * _D_Roughness;
                float a2 = a * a;
                float NdotH = InnerProduct(N, H);
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
            
            float GeometrySmith(float3 N, float3 V, float3 L, float3 Roughness)
            {
                float k = pow(Roughness + 1.0f, 2) / 8.0f;
                
                float NdotV = max(InnerProduct(N, V), 0.0);
                float NdotL = max(InnerProduct(N, L), 0.0);
                float ggx1 = GeometrySchlickGGX(NdotV, k);
                float ggx2 = GeometrySchlickGGX(NdotL, k);
                return ggx1 * ggx2;
            }
            
            //フレネルの式
            float Flesnel(float3 V, float H, float _F0)
            {
                float VdotH = InnerProduct(V, H);
                float F0 = saturate(_F0);
                float F = F0 + (1.0f - F0) * pow(1.0f - VdotH, 5);
                return F;
            }

            float BTDF(float3 N, float3 L, float3 V, float3 H, float3 R)
            {
                float NdotL = pow(0.5f * InnerProduct(N, L) + 0.5f, 2);
                float NdotV = InnerProduct(N, V);
                float3 HdotV = InnerProduct(H, V);
                float3 HdotL = InnerProduct(H, L);
                //法線分布関数
                float3 D = distributionGGX(N, H);
                //幾何減衰
                float3 G = GeometrySmith(N, V, L, _G_Roughness);
                //フレネルの式
                float3 F = Flesnel(R, H, _F0);
                float3 leftItem = abs((HdotL * HdotV) / (NdotL * NdotV));
                float3 rightItem = (pow(_R_o, 2) * D * G * (1 - F)) / pow((_R_i * HdotL+ _R_o * HdotV), 2);
                return leftItem * rightItem;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                // ワールド空間での法線を計算
                o.normal = normalize(mul(unity_ObjectToWorld, float4(v.normal, 0.0)).xyz);
                // 該当ピクセルのライティングに、ワールド空間上での位置を保持しておく
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                // o.ambient = 1;
                // // SH
                // o.ambient.rgb = ShadeSHPerVertex(o.normal, o.ambient.rgb);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float eta = _R_i / _R_o;
                float3 lightDirectionNormal = normalize(_WorldSpaceLightPos0.xyz);
                // ワールド空間上の視点（カメラ）位置と法線との内積を計算
                float3 viewDirectionNormal = normalize((float4(_WorldSpaceCameraPos, 1.0) - i.worldPos).xyz);
                float3 refractedLightVector = refract(viewDirectionNormal, i.normal, eta);
                // ライトと視点ベクトルのハーフベクトルを計算
                float3 halfVector = normalize(lightDirectionNormal + refractedLightVector);

                float NdotV = InnerProduct(i.normal, viewDirectionNormal);
                float NdotL = pow(0.5f * InnerProduct(i.normal, lightDirectionNormal) + 0.5f, 2);
                
                float3 btdf = BTDF(i.normal, lightDirectionNormal, viewDirectionNormal, halfVector , refractedLightVector);

                float3 diffuseReflection =  tex2D(_MainTex, i.normal).rgb * NdotL * _LightColor0;

                // 最後に色を合算して出力
                return float4(btdf + diffuseReflection, 1.0);
            }
            ENDCG
        }
    }
}
