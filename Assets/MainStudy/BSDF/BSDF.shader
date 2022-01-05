Shader "BSDF"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _D_Roughness ("D_Roughness", Range(0.0, 1.0)) = 0.1
        _G_Roughness ("G_Roughness", Range(0.0, 1.0)) = 0.1
        _F0 ("Fresnel Reflection Coefficient", Range(0.0, 1.0)) = 0.02
        _R_i ("η_i", Range(0.0, 2.0)) = 1.0
        _R_o ("η_o", Range(0.0, 2.0)) = 1.5
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
            
            //法線分布関数、D項
            float D_NormalDistribution(float3 N, float3 H)
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

            //幾何減衰、G項
            float G_SchlickGGX(float3 NdotV, float3 k)
            {
                float nom = NdotV;
                float denom = NdotV * (1.0 - k) + k;
                return nom / denom;
            }            
            float G_ShadowingMasking(float3 N, float3 L, float3 V, float3 Roughness)
            {
                float k = pow(Roughness + 1.0f, 2) / 8.0f;
                
                float NdotV = max(InnerProduct(N, V), 0.0);
                float NdotL = max(InnerProduct(N, L), 0.0);
                float ggx1 = G_SchlickGGX(NdotV, k);
                float ggx2 = G_SchlickGGX(NdotL, k);
                float G = ggx1 * ggx2;
                if(G < 0 || 1 < G)
                {
                    return 0;
                }
                return G;
            }
            
            //フレネルの式、F項
            float F_Flesnel(float3 V, float H, float _F0)
            {
                float VdotH = InnerProduct(V, H);
                // float F0 = saturate(_F0);
                // float F0 = pow((_R_i - _R_o) / (_R_i + _R_o), 2);
                float F0 = pow((_R_i - _R_o) / (_R_i + _R_o), 2);
                float F = F0 + (1.0f - F0) * pow(1.0f - VdotH, 5);
                return F;
            }

            
            float BRDF(float3 N, float3 L, float3 V, float3 H)
            {
                float NdotL = InnerProduct(N, L);
                float NdotV = InnerProduct(N, V);
                //法線分布関数
                float3 D = D_NormalDistribution(N, H);
                //幾何減衰
                float3 G = G_ShadowingMasking(N, L, V, _G_Roughness);
                //フレネルの式
                float3 F = F_Flesnel(V, H, _F0);                
                return (D * G * F) / (4.0 * NdotL * NdotV + 0.000001);
            }
            
            float BTDF(float3 N, float3 L, float3 V, float3 H, float3 R)
            {
                float NdotL = pow(0.5f * InnerProduct(N, L) + 0.5f, 2);
                float NdotV = abs(InnerProduct(N, V));
                float3 HdotV = abs(InnerProduct(H, V));
                float3 HdotL = abs(InnerProduct(H, L));
                //法線分布関数
                float3 D = D_NormalDistribution(N, H);
                //幾何減衰
                float3 G = G_ShadowingMasking(N, V, L, _G_Roughness);
                //フレネルの式
                float3 F = F_Flesnel(V, H, _F0);
                float3 leftItem = (HdotL * HdotV) / (NdotL * NdotV);
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
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float eta = _R_i / _R_o;
                float3 lightDirectionNormal = normalize(_WorldSpaceLightPos0.xyz);
                // ワールド空間上の視点（カメラ）位置
                float3 viewDirectionNormal = normalize((float4(_WorldSpaceCameraPos, 1.0) - i.worldPos).xyz);
                // 屈折光ベクトルを計算
                float3 refractedLightVector = refract(viewDirectionNormal, i.normal, eta);
                // ライトと視点ベクトルのハーフベクトルを計算
                float3 halfVector_R = normalize(lightDirectionNormal + viewDirectionNormal);
                float3 halfVector_T = normalize(lightDirectionNormal + refractedLightVector);

                // ハーフランバート用の内積
                float NdotL = pow(0.5f * InnerProduct(i.normal, lightDirectionNormal) + 0.5f, 2);

                float3 brdf = BRDF(i.normal, lightDirectionNormal, viewDirectionNormal, halfVector_R);                
                float3 btdf = BTDF(i.normal, lightDirectionNormal, viewDirectionNormal, halfVector_T, refractedLightVector);

                float3 diffuseReflection =  tex2D(_MainTex, i.normal).rgb * NdotL * _LightColor0;

                // 最後に色を合算して出力
                return float4(brdf + btdf + diffuseReflection, 1.0);
            }
            ENDCG
        }
    }
}
