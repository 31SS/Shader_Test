Shader "Unlit/BRDF2"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Diffuse Color", Color) = (1, 1, 1, 1)
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _D_Roughness ("D_Roughness", Range(0.0, 1.0)) = 0.1
        _G_Roughness ("G_Roughness", Range(0.0, 1.0)) = 0.1
         _F0 ("Fresnel Reflection Coefficient", Range(0.0, 1.0)) = 0.02
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
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            

            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            uniform float4 _Color;
            half _D_Roughness;
            half _G_Roughness;
            half _F0;

            struct Input {
				float2 uv_MainTex;
			};
            
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
                half3 lightDir : TEXCOORD3;
                half3 viewDir : TEXCOORD4;
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
            
            float4 _MainTex_ST;
            // float4 _LightColor0;
            sampler2D _MainTex;
            sampler2D _NormalMap;
            half _Shininess;

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
                o.uv = v.uv.xy;
                o.pos = UnityObjectToClipPos(v.vertex);
                // ワールド空間での法線を計算
                o.normal = normalize(mul(unity_ObjectToWorld, float4(v.normal, 0.0)).xyz);
                // 該当ピクセルのライティングに、ワールド空間上での位置を保持しておく
                o.vpos = mul(unity_ObjectToWorld, v.vertex);
                o.color = _Color;
                TANGENT_SPACE_ROTATION;
                o.lightDir = mul(rotation, ObjSpaceLightDir(v.vertex));
                o.viewDir = mul(rotation, ObjSpaceViewDir(v.vertex));

                
                
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 ambientLight = unity_AmbientEquator.xyz * i.color;
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

                
                
                i.lightDir = normalize(i.lightDir);
                i.viewDir = normalize(i.viewDir);
                half3 halfDir = normalize(i.lightDir + i.viewDir);
                // ノーマルマップから法線情報を取得する
                half3 normal = UnpackNormal(tex2D(_NormalMap, i.uv));

                float3 diffuseReflection =  _LightColor0.xyz * tex2D(_MainTex, i.normal).rgb * NdotL;
                
                // 最後に色を合算して出力
                return float4(ambientLight + cookTransModel + diffuseReflection, 1.0);

                // return tex2D(_MainTex, i.uv) * cookTransModel * diffuseReflection;

                // return tex2D(_MainTex, i.uv) * cookTransModel;

                // return cookTransModel;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
