Shader "Unlit/MyPhong"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
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
            #include "UnityDeferredLibrary.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float3 normal : NORMAL;
                float4 vertex : SV_POSITION;
                float3 worldPos : TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            uniform fixed4 _LightColor0;

            v2f vert (appdata v)
            {
                v2f o = (v2f)0;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float t = dot(i.normal, WorldSpaceLightDir(i.vertex) * -1.0f);

                t *= -1.0f;

                if(t < 0.0f)
                {
                    t = 0.0f;
                }

                fixed3 diffuseLig = _LightColor0 * t;

                float3 refVec = reflect(WorldSpaceLightDir(i.vertex) * -1.0f, i.normal);
                float3 toEye = _WorldSpaceCameraPos - i.worldPos;
                toEye = normalize(toEye);

                t = dot(refVec, toEye);
                if(t < 0.0f)
                {
                    t = 0.0f;
                }

                t = pow(t, 5.0f);

                float3 specularLig = _LightColor0 * t;

                float3 lig = diffuseLig + specularLig;
                 lig += 0.3f;
                
                fixed4 finalColor = tex2D(_MainTex, i.uv);
                finalColor.xyz *= lig;                
                return finalColor;
            }
            ENDCG
        }
    }
}
