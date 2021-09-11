Shader "ShaderSketches/Template"
{
   Properties
   {
       _MainTex ("MainTex", 2D) = "white"{}
   }

   CGINCLUDE
   #include "UnityCG.cginc"
   #define PI 3.14159265359

   float heart(float2 st)
{
    // 位置とか形の調整
    st = (st - float2(0.5, 0.38)) * float2(2.1, 2.8);

    return pow(st.x, 2) +
              pow(st.y - sqrt(abs(st.x)), 2);  
}

   
   float4 frag(v2f_img i) : SV_Target
    {
        float2 st = 0.5 - i.uv;
        float a = atan2(st.y, st.x);
        
        float r = length(st);
        float d = min(abs(cos(a * 2.5)) + 0.4,
                        abs(sin (a * 2.5)) + 1.1) * 0.32;

        float4 color = lerp(0.8, float4(0, 0.4, 1, 1), i.uv.y);

        float petal = step(r, d);
        color = lerp(color, lerp(float4(1, 0.3, 1, 1), 1, r * 2.5), petal);

        float cap = step(distance(0, st), 0.07);
        color = lerp(color, float4(0.99, 0.78, 0, 1), cap);

        return color;
    }


   ENDCG

   SubShader
   {
       Pass
       {
           CGPROGRAM
           #pragma vertex vert_img
           #pragma fragment frag
           ENDCG
       }
   }
}
