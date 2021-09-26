Shader "ShaderSketches/Template"
{
   Properties
   {
       _MainTex ("MainTex", 2D) = "white"{}
   }

   CGINCLUDE
   #include "UnityCG.cginc"
   #define PI 3.14159265359

    float circle(float2 st)
   {
    return step(0.3, distance(0.5, st));
   }

    float4 frag(v2f_img i) : SV_Target
    { 
        // 歪みの計算
        float x = 2 * i.uv.y + sin(_Time.y * 5);
        float distort = sin(_Time.y * 10) * 0.1 *
                             sin(5 * x) * (- (x - 1) * (x - 1) + 1);
        // 座標を歪ませる 
        i.uv.x += distort; 
        // RGB ごとに少しずつ座標をずらす
        return float4(circle(i.uv - float2(0, distort) * 0.3),
                           circle(i.uv + float2(0, distort) * 0.3),
                           circle(i.uv + float2(distort, 0) * 0.3),
                           1);
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
