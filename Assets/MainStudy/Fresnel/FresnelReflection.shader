Shader "FresnelReflection"
{
    Properties
    {
        [PowerSlider(0.1)] _F0 ("F0", Range(0.0, 1.0)) = 0.02
        _CubeMap ("Cube Map", Cube) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
            CGPROGRAM
           #pragma vertex vert
           #pragma fragment frag
            
           #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                half3 normal : NORMAL;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                half vdotn : TEXCOORD1;
                half3 reflDir : TEXCOORD2;
            };

            UNITY_DECLARE_TEXCUBE(_CubeMap);
            float _F0;
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                half3 viewDir = normalize(ObjSpaceViewDir(v.vertex));
                o.vdotn = dot(viewDir, v.normal.xyz);
                o.reflDir = mul(unity_ObjectToWorld, reflect(-viewDir, v.normal.xyz));
                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                half fresnel = _F0 + (1.0h - _F0) * pow(1.0h - i.vdotn, 5);
                return UNITY_SAMPLE_TEXCUBE(_CubeMap, i.reflDir) * fresnel;
            }
            ENDCG
        }
    }
}