Shader "Unlit/BRDF+BumpMap"
{
    Properties
    {
        _Roughness("Roughness", Range(0.0, 1.0)) = 0.5
        _MainTex ("Texture", 2D) = "white" {}
        _D_Roughness ("D_Roughness", Range(0.0, 1.0)) = 0.1
        _G_Roughness ("G_Roughness", Range(0.0, 1.0)) = 0.1
        _F0 ("Fresnel Reflection Coefficient", Range(0.0, 1.0)) = 0.02
        _NormalMap ("Normal map", 2D) = "bump" {}
        _Shininess ("Shininess", Range(0.0, 1.0)) = 0.078125
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 100

        Pass
        {
            Tags{ "LightMode" = "ForwardBase" }
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            sampler2D _MainTex;
            sampler2D _NormalMap;
            float4 _MainTex_ST;
            float _Roughness;
            half _D_Roughness;
            half _G_Roughness;
            half _F0;
            half4 _Ambient;
            half _Shininess;
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                half4 tangent : TANGENT;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                half2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float4 worldPos :TEXCOORD2;
                half3 viewDir : TEXCOORD3;
                half3 lightDir : TEXCOORD4;
                half3 tangent : TEXCOORD5;
                half3 binormal : TEXCOORD6;
            };
                        
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
            float GeometrySmith(float3 N, float3 V, float3 L, float3 Roughness)
            {
                float k = pow(Roughness + 1.0f, 2) / 8.0f;
                
                float NdotV = max(dot(N, V), 0.0);
                float NdotL = max(dot(N, L), 0.0);
                float ggx1 = GeometrySchlickGGX(NdotV, k);
                float ggx2 = GeometrySchlickGGX(NdotL, k);
                return ggx1 * ggx2;
            }

            // G - 幾何減衰の項（クック トランスモデル）
			float G_CookTorrance(float3 L, float3 V, float3 H, float3 N) {
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

            //フレネルの式
            float Flesnel(float3 V, float H, float _F0)
            {
                float VdotH = saturate(dot(V, H));
                float F0 = saturate(_F0);
                float F = F0 + (1.0f - F0) * pow(1.0f - VdotH, 5);
                return F;
            }

            float BRDF(float3 N, float3 L, float3 V, float3 H)
            {
                float NdotL = saturate(dot(N, L));
                float NdotV = saturate(dot(N, V));
                //法線分布関数
                float3 D = distributionGGX(N, H);
                //幾何減衰
                float3 G = GeometrySmith(N, V, L, _G_Roughness);
                //フレネルの式
                float3 F = Flesnel(V, H, _F0);                
                return (D * G * F) / (4.0 * NdotL * NdotV + 0.000001);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                // ワールド空間での法線を計算
                o.normal = normalize(mul(unity_ObjectToWorld, float4(v.normal, 0.0)).xyz);
                // 該当ピクセルのライティングに、ワールド空間上での位置を保持しておく
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);

                // // ワールド空間のライト方向と視点方向を求める
                // o.lightDir = normalize(mul(unity_ObjectToWorld, ObjSpaceLightDir(v.vertex)));
                // o.viewDir = normalize(mul(unity_ObjectToWorld, ObjSpaceViewDir(v.vertex)));
                //
                // // ワールド <-> 接空間変換行列を作成するため、ワールド空間のnormal, tangent, binormalを求めておく
                // o.binormal = normalize(cross(v.normal, v.tangent) * v.tangent.w);
                // o.normal = UnityObjectToWorldNormal(v.normal);
                // o.tangent = mul(unity_ObjectToWorld, v.tangent.xyz);
                // o.binormal = mul(unity_ObjectToWorld, o.binormal);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // 接空間 -> ワールド空間変換行列
                half3x3 tangentToWorld = transpose(half3x3(i.tangent.xyz, i.binormal, i.normal));
                half3 halfDir = normalize(i.lightDir + i.viewDir);
                
                float3 lightDirectionNormal = normalize(_WorldSpaceLightPos0.xyz);
                // ワールド空間上の視点（カメラ）位置と法線との内積を計算
                float3 viewDirectionNormal = normalize((float4(_WorldSpaceCameraPos, 1.0) - i.worldPos).xyz);
                // ライトと視点ベクトルのハーフベクトルを計算
                float3 halfVector = normalize(lightDirectionNormal + viewDirectionNormal);

                // ノーマルマップから法線情報を取得する
                half3 normal = UnpackNormal(tex2D(_NormalMap, i.uv));
                normal = mul(tangentToWorld, normal);
                
                float NdotV = saturate(dot(i.normal, viewDirectionNormal));
                float NdotL = pow(0.5f * saturate(dot(i.normal, lightDirectionNormal)) + 0.5f, 2);
                
                float3 brdf = BRDF(i.normal, lightDirectionNormal, viewDirectionNormal, halfVector);

                float3 diffuseReflection =  tex2D(_MainTex, i.normal).rgb * NdotL * _LightColor0;
                                // ノーマルマップから得た法線情報をつかってライティング計算をする
                half4 diff = saturate(dot(normal, i.lightDir)) * _LightColor0;
                half3 spec = pow(max(0, dot(normal, halfDir)), _Shininess * 128.0) * _LightColor0.rgb;

                // 最後に色を合算して出力
                return float4(brdf + diffuseReflection, 1.0);
            }
            ENDCG
        }
    }
}
