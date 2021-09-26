Shader "ShaderSketches/Template"
{
   Properties
   {
       _MainTex ("MainTex", 2D) = "white"{}
   }

   CGINCLUDE
   #include "UnityCG.cginc"
   #define PI 3.14159265359

   float box(float2 st, float size)
   {
       size = 0.5 + size * 0.5;
       st = step(st , size) * step(1.0 - st, size);
       return st.x * st.y;
   }

    float wave(float2 st, float n)
    {
        st = (floor(st * n) + 0.5) / n;
        float d = distance(0.5, st);
        return (1 + sin(d * 3 - _Time.y * 3)) * 0.5;
    }

    float box_wave(float2 uv, float n)
    {
        float2 st = frac(uv * n);
        float size = wave(uv, n);
        return box(st, size);
    }

    float4 frag(v2f_img i) : SV_Target
    {
        return float4(box_wave(i.uv, 9), box_wave(i.uv, 18), box_wave(i.uv, 36), 1);
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
