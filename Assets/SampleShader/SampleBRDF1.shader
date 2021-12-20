Shader "SampleShader1"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Albedo", 2D) = "white" {}
        _Roughness("Roughness", Range(0.0, 1.0)) = 0.5
        _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
    }

    SubShader
    {
        Pass
        {
            // SH求めるのに必要
            Tags{ "LightMode" = "ForwardBase" }

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase

            #include "UnityCG.cginc"
            #include "UnityStandardUtils.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                half2 texcoord : TEXCOORD0;
                half3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                half2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                half3 worldNormal : TEXCOORD2;
                half3 viewDir : TEXCOORD3;
                half4 ambient : TEXCOORD4;
            };

            float3 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _Metallic;
            float _Roughness;
            float3 _LightColor0;

            #define _DielectricF0 0.04

            inline half Fd_Burley(half ndotv, half ndotl, half ldoth, half roughness)
            {
                half fd90 = 0.5 + 2 * ldoth * ldoth * roughness;
                half lightScatter = (1 + (fd90 - 1) * pow(1 - ndotl, 5));
                half viewScatter = (1 + (fd90 - 1) * pow(1 - ndotv, 5));

                half diffuse = lightScatter * viewScatter;
                return diffuse;
            }
            
            inline float V_SmithGGXCorrelated(float ndotl, float ndotv, float alpha)
            {
                float lambdaV = ndotl * (ndotv * (1 - alpha) + alpha);
                float lambdaL = ndotv * (ndotl * (1 - alpha) + alpha);

                return 0.5f / (lambdaV + lambdaL + 0.0001);
            }

            inline half D_GGX(half perceptualRoughness, half ndoth, half3 normal, half3 halfDir) {
                half3 ncrossh = cross(normal, halfDir);
                half a = ndoth * perceptualRoughness;
                half k = perceptualRoughness / (dot(ncrossh, ncrossh) + a * a);
                half d = k * k * UNITY_INV_PI;
                return min(d, 65504.0h);
            }

            inline half3 F_Schlick(half3 f0, half cos)
            {
                return f0 + (1 - f0) * pow(1 - cos, 5);
            }
            
            half4 BRDF(half3 albedo, half metallic, half perceptualRoughness, float3 normal, float3 viewDir, float3 lightDir, float3 lightColor, half3 indirectDiffuse, half3 indirectSpecular)
            {
                float3 halfDir = normalize(lightDir + viewDir);
                half ndotv = abs(dot(normal, viewDir));
                float ndotl = max(0, dot(normal, lightDir));
                float ndoth = max(0, dot(normal, halfDir));
                half ldoth = max(0, dot(lightDir, halfDir));
                half reflectivity = lerp(_DielectricF0, 1, metallic);
                half3 f0 = lerp(_DielectricF0, albedo, metallic);
                
                half diffuseTerm = Fd_Burley(ndotv, ndotl, ldoth, perceptualRoughness) * ndotl;
                half3 diffuse = albedo * (1 - reflectivity) * lightColor * diffuseTerm;
                // Indirect Diffuse
                diffuse += albedo * (1 - reflectivity) * indirectDiffuse;
                
                float alpha = perceptualRoughness * perceptualRoughness;
                float V = V_SmithGGXCorrelated(ndotl, ndotv, alpha);
                float D = D_GGX(perceptualRoughness, ndotv, normal, halfDir);
                float3 F = F_Schlick(f0, ldoth); 
                float3 specular = V * D * F * ndotl * lightColor;
                specular *= UNITY_PI;
                specular = max(0, specular);
                
                // Indirect Specular
                half surfaceReduction = 1.0 / (alpha * alpha + 1.0);
                half f90 = saturate((1 - perceptualRoughness) + reflectivity);
                specular += surfaceReduction * indirectSpecular * lerp(f0, f90, pow(1 - ndotv, 5));
                
                half3 color = diffuse + specular;
                return half4(color, 1);
            }
            
            v2f vert(appdata v)
            {
                v2f o = (v2f)0;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.viewDir = UnityWorldSpaceViewDir(o.worldPos);

                // SH
                o.ambient.rgb = ShadeSHPerVertex(o.worldNormal, o.ambient.rgb);

                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                half3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;
                half metallic = _Metallic;
                half perceptualRoughness = _Roughness;

                i.worldNormal = normalize(i.worldNormal);
                i.viewDir = normalize(i.viewDir);

                // Indirect Diffuse
                half3 indirectDiffuse = ShadeSHPerPixel(i.worldNormal, i.ambient, i.worldPos);
                // roughnessに対応する鏡面反射のミップマップレベルを求める
                half3 reflDir = reflect(-i.viewDir, i.worldNormal);
                half mip = perceptualRoughness * (1.7 - 0.7 * perceptualRoughness);
                // 間接光の鏡面反射（リフレクションプローブのブレンドとかは考慮しない）
                mip *= UNITY_SPECCUBE_LOD_STEPS;
                half4 rgbm = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflDir, mip);
                half3 indirectSpecular = DecodeHDR(rgbm, unity_SpecCube0_HDR);

                half4 c = BRDF(albedo, metallic, perceptualRoughness, i.worldNormal, i.viewDir, _WorldSpaceLightPos0.xyz, _LightColor0.rgb, indirectDiffuse, indirectSpecular);
                return c;
            }

            ENDCG
        }
    }
}