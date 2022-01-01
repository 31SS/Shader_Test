Shader "Unlit/BRDF3"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Diffuse Color", Color) = (1, 1, 1, 1)
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _D_Roughness ("D_Roughness", Range(0.0, 1.0)) = 0.1
        _G_Roughness ("G_Roughness", Range(0.0, 1.0)) = 0.1
         _F0 ("Fresnel Reflection Coefficient", Range(0.0, 1.0)) = 0.02
        _BumpMap ("Bump map", 2D) = "bump" {}
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
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            uniform float4 _Color;
            half _D_Roughness;
            half _G_Roughness;
            half _F0;
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float4 vpos :TEXCOORD2;
                float3 lightDir : TEXCOORD3;
                float4 pos : SV_POSITION;
                float4 color : COLOR;
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
            sampler2D _BumpMap;
            // fixed4 _Color;
            float4 _MainTex_ST;

            // 接空間へ変換する行列を生成する
            // ※ 接空間からローカル空間への変換の逆行列で、ローカルのライトを接空間に変換する
            float4x4 InvTangentMatrix(float3 tan, float3 bin, float3 nor)
            {
                float4x4 mat = float4x4(
                    float4(tan, 0),
                    float4(bin, 0),
                    float4(nor, 0),
                    float4(0, 0, 0, 1)
                );

                // 正規直交系行列なので、逆行列は転置行列で求まる
                return transpose(mat);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);

                // ワールド空間での法線を計算
                o.normal = normalize(mul(unity_ObjectToWorld, float4(v.normal, 0.0)).xyz);
                o.uv = v.uv.xy;

                // 該当ピクセルのライティングに、ワールド空間上での位置を保持しておく
                o.vpos = mul(unity_ObjectToWorld, v.vertex);
                o.color = _Color;

                 // ローカル空間上での接空間ベクトルの方向を求める
                float3 n = normalize(v.normal);
                float3 t = v.tangent;
                float3 b = cross(n, t);

                // ワールド位置にあるライトをローカル空間へ変換する
                float3 localLight = mul(unity_WorldToObject, _WorldSpaceLightPos0);

                // ローカルライトを接空間へ変換する（行列の掛ける順番に注意）
                o.lightDir = mul(localLight, InvTangentMatrix(t, b, n));

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
                float3 D = distributionGGX(i.normal, halfVector);
                float3 G = GeometrySmith(i.normal, viewDirectionNormal, lightDirectionNormal, _G_Roughness);
                // float G = G_CookTorrance(lightDirectionNormal, viewDirectionNormal, halfVector, i.normal);
                float3 F = Flesnel(viewDirectionNormal, halfVector, _F0);

                // float cookTransModel = (D * G * F) / (4 * NdotL * NdotV + 0.000001);

                float3 cookTransModel = (D * G * F) / (4.0 * NdotL * NdotV + 0.000001);

                float3 normal = float4(UnpackNormal(tex2D(_BumpMap, i.uv)), 1);
                float3 light = normalize(i.lightDir);
                float diff = max(0, dot(normal, light));

                float3 ambientLight = unity_AmbientEquator.xyz * i.color * diff;
                float3 diffuseReflection = _LightColor0.xyz * tex2D(_MainTex, i.normal).rgb;

                float4 color = tex2D(_MainTex, i.uv);

                // 最後に色を合算して出力
                // return float4(ambientLight + cookTransModel + diffuseReflection, 1.0);

                return diff * tex2D(_MainTex, i.normal);
                // return tex2D(_MainTex, i.uv) * cookTransModel * diffuseReflection;

                // return tex2D(_MainTex, i.uv) * cookTransModel;

                // return cookTransModel;
            }
            ENDCG
        }
    }
}
