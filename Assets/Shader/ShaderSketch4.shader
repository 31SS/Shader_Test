Shader "ShaderSketches/Template"
{
   Properties
   {
       _MainTex ("MainTex", 2D) = "white"{}
   }

   CGINCLUDE
   #include "UnityCG.cginc"
   #define PI 3.14159265359

   float rand(float2 st)
    {
        return frac(sin(dot(st, float2(12.9898, 78.233))) * 43758.5453);
    }


   float box(float2 st, float size)
   {
       size = 0.5 + size * 0.5;
       st = step(st , size) * step(1.0 - st, size);
       return st.x * st.y;
   }

    float box_size(float2 st, float n)
    {
        st = (floor(st * n) + 0.5) / n;
        float offs = rand(st) * 5;
        return (1 + sin(_Time.y * 3 + offs)) * 0.5;
    }

    float4 frag(v2f_img i) : SV_Target
    {
        float n = 10;
        float2 st = frac(i.uv * n);
        float size = box_size(i.uv, n);
        return box(st, size);
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
