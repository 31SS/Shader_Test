Shader "Custom/wipeCircle" {
	Properties{
		_Radius("Radius", Range(0,2))=2
	}
    SubShader {
        Pass {
            CGPROGRAM

            #include "UnityCG.cginc"

            #pragma vertex vert_img
            #pragma fragment frag

            float _Radius;
            fixed4 frag(v2f_img i) : COLOR {
        	i.uv -= fixed2(0.5, 0.5);
           	i.uv.x *= 16.0/9.0;
           	if( distance(i.uv, fixed2(0,0)) < _Radius ){
           		discard;
           	}
                return fixed4(0.0,0.0,0.0,1.0);
            }
            ENDCG
        }
    }
}