Shader "Unlit/BTDF2"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Diffuse Color", Color) = (1, 1, 1, 1)
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
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
//        Tags { "RenderType"="Transparent" "Queue" = "Transparent" }
//        Blend DstColor Zero
//        ZTest LEqual
//        ZWrite On
//        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "UnityStandardUtils.cginc"

            uniform float4 _Color;
            half _D_Roughness;
            half _G_Roughness;
            half _F0;
            half _R_i;
            half _R_o;
            half _Roughness;
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float4 worldPos : TEXCOORD2;
                float4 viewDir : TEXCOORD3;
                float4 ambient : TEXCOORD4;
                float4 color : COLOR;
            };
            
           
            // <summary>
            // 正規分布関数
            // <summary>
            // <param name="N">法線</param>
            // <param name="H">ハーフベクトル</param>
            // <param name="alpha">表面の粗さ</param>
            
            //Nは法線、HはVとLのハーフベクトルaは表面の粗さ
            float3 distributionGGX(float3 N, float3 H)
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
            float3 GeometrySchlickGGX(float3 NdotV, float3 k)
            {
                float nom = NdotV;
                float denom = NdotV * (1.0 - k) + k;
                return nom / denom;
            }
            float3 GeometrySmith(float3 N, float3 V, float3 L, float3 Roughness)
            {
                float k = pow(Roughness + 1.0f, 2) / 8.0f;
                
                float NdotV = max(dot(N, V), 0.0);
                // float NdotV = saturate(dot(N, V));
                float NdotL = max(dot(N, L), 0.0);
                // float NdotL = saturate(dot(N, V));
                float ggx1 = GeometrySchlickGGX(NdotV, k);
                float ggx2 = GeometrySchlickGGX(NdotL, k);
                return ggx1 * ggx2;
            }

            			// G - 幾何減衰の項（クック トランスモデル）
			float3 G_CookTorrance(float3 L, float3 V, float3 H, float3 N) {
				float NdotH = saturate(dot(N, H));
				float NdotL = saturate(dot(N, L));
				float NdotV = saturate(dot(N, V));
				float VdotH = saturate(dot(V, H));

			    float NH2 = 5.0 * NdotH;
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

            float3 InnerProduct(float3 x, float3 y)
            {
                return saturate(dot(x, y));
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
                // o.normal = normalize(mul(unity_ObjectToWorld, float4(v.normal, 0.0)).xyz);

                o.normal = UnityObjectToWorldNormal(v.normal);
                // 該当ピクセルのライティングに、ワールド空間上での位置を保持しておく
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);

                // o.ambient.rgb = tex2D(_MainTex, o.normal);
                o.ambient.rgb = 0;
                o.ambient.rgb = ShadeSHPerVertex(o.normal, o.ambient.rgb);

                o.color = _Color;

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float perceptualRoughness = _Roughness;
                
                //環境光とテクスチャの乗算
                // float3 ambientLight = unity_AmbientEquator.xyz * tex2D(_MainTex, i.normal).rgb;
                float3 ambientLight = unity_AmbientEquator.xyz  * i.color;
                float3 albedo = tex2D(_MainTex, i.uv) * _Color;

                float eta = _R_i / _R_o;

                //入射ベクトルを求める
                float3 lightDirectionNormal = normalize(_WorldSpaceLightPos0.xyz);
                float3 NdotL = InnerProduct(i.normal, lightDirectionNormal);
                // ワールド空間上の視点（カメラ）位置と法線との内積を計算
                // float3 viewDirectionNormal = normalize((float4(_WorldSpaceCameraPos, 1.0) - i.worldPos).xyz);
                float3 viewDirectionNormal = normalize(i.worldPos - _WorldSpaceCameraPos.xyz);
                float3 refractedLightVector = refract(viewDirectionNormal, i.normal, eta);
                float3 NdotV = InnerProduct(i.normal, refractedLightVector);
                // ライトと視点ベクトルのハーフベクトルを計算
                float3 halfVector = -normalize(_R_i * lightDirectionNormal + _R_o * refractedLightVector);

                float3 HdotV = InnerProduct(halfVector, refractedLightVector);

                float3 HdotL = InnerProduct(halfVector, lightDirectionNormal);

                // Indirect Diffuse
                half3 indirectDiffuse = ShadeSHPerPixel(i.normal, i.ambient, i.worldPos);
                // roughnessに対応する鏡面反射のミップマップレベルを求める
                float3 reflDir = reflect(-i.viewDir, i.normal);
                half mip = perceptualRoughness * (1.7 - 0.7 * perceptualRoughness);

                mip *= UNITY_SPECCUBE_LOD_STEPS;
                half4 rgbm = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflDir, mip);
                half3 indirectSpecular = DecodeHDR(rgbm, unity_SpecCube0_HDR);
                

                // D_GGXの項
                float3 D = distributionGGX(i.normal, halfVector);
                float3 G = GeometrySmith(i.normal, refractedLightVector, lightDirectionNormal, _G_Roughness);
                // float G = G_CookTorrance(lightDirectionNormal, viewDirectionNormal, halfVector, i.normal);
                float3 F = Flesnel(refractedLightVector, halfVector, _F0);
                
                float3 cookTransModel = (D * G * F) / (4.0 * NdotL * NdotV + 0.000001);

                // float3 BTDF = ((HdotL * HdotV) / (NdotL * NdotV)) * ((pow(_R_o, 2) * D * G * (1 - F)) / pow((_R_i * HdotV + _R_o * HdotL), 2));
                
                float3 leftItem = abs((HdotL * HdotV) / (NdotL * NdotV));
                float3 rightItem = (pow(_R_o, 2) * D * G * (1 - F)) / pow((_R_i * HdotL+ _R_o * HdotV), 2);
                float3 BTDF = leftItem * rightItem;
                
                float3 diffuseReflection = _LightColor0.xyz * tex2D(_MainTex, i.normal).rgb * NdotL;                

                // 最後に色を合算して出力
                // return float4(ambientLight + BTDF + diffuseReflection, 1.0);

                // return float4(indirectDiffuse + indirectSpecular + BTDF + ambientLight, 1.0);
                return float4(diffuseReflection + BTDF + ambientLight, 1.0);
                // return float4(BTDF, 1.0);
                // return tex2D(_MainTex, i.uv) * cookTransModel * diffuseReflection;

                // return tex2D(_MainTex, i.uv) * cookTransModel;

                // return cookTransModel;
            }
            ENDCG
        }
    }
}
