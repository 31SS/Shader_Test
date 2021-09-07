
Shader "Custom/Waterfall 05" {
	Properties {
		_MainTex    ("Flow Tex"                  , 2D    ) = "white" {}
		_Color      ("Color"                     , Color ) = (1, 1, 1, 1)
		_FlowU      ("Flow Speed U (Min:x Max:y)", Vector) = (1, 1, 0, 0)
		_FlowV      ("Flow Speed V (Min:x Max:y)", Vector) = (1, 1, 0, 0)
		_Brightness ("Brightness"                , Float ) = 1
		_Gamma      ("Gamma"                     , Float ) = 1
	}
	
	SubShader { 
		Tags {
			"Queue"      = "Transparent"
			"RenderType" = "Transparent"
		}
		
		CGPROGRAM
			#pragma surface surf Standard alpha

			sampler2D _MainTex;
			fixed3 _Color;
			half2 _FlowU;
			half2 _FlowV;
			half _Brightness;
			half _Gamma;

			struct Input {
				float2 uv_MainTex;
				fixed3 color : COLOR;
			};

			void surf (Input IN, inout SurfaceOutputStandard o) {
				float2 uvOffset;
				uvOffset.x = _Time.x * lerp(_FlowU.x, _FlowU.y, IN.color.r) * (round(IN.color.r) * 2 - 1);
				uvOffset.y = _Time.x * lerp(_FlowV.x, _FlowV.y, IN.color.g);

				fixed flowTexU = tex2D(_MainTex, IN.uv_MainTex + half2(uvOffset.x, 0)).r;
				fixed flowTexV = tex2D(_MainTex, IN.uv_MainTex + half2(0, uvOffset.y)).g;

				o.Emission   = pow(flowTexU * flowTexV * IN.color.b, _Gamma) * _Brightness * _Color;

				o.Albedo     = fixed3(0, 0, 0);
				o.Alpha      = 0;
				o.Metallic   = 0;
				o.Smoothness = 0;
			}
		ENDCG
	}

	Fallback "Transparent/Diffuse"
}