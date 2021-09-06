Shader "Custom/Waterfall" {
	Properties {
		_MainTex ("Flow Tex"  , 2D   ) = "white" {}
		_FlowU      ("Flow Speed U", Float) = 1
		_FlowV      ("Flow Speed V", Float) = 1
		_Brightness ("Brightness", Float) = 1
	}
	
	SubShader { 
		Tags {
			"Queue"      = "Transparent"
			"RenderType" = "Transparent"
		}
		
		CGPROGRAM
			#pragma surface surf Standard alpha

			sampler2D _MainTex;
			half _FlowU;
			half _FlowV;
			half _Brightness;

			struct Input {
				float2 uv_MainTex;
			};

			void surf (Input IN, inout SurfaceOutputStandard o) {
				fixed flowTexU = tex2D(_MainTex, IN.uv_MainTex + half2(_Time.x * _FlowU, 0)).r;
				fixed flowTexV = tex2D(_MainTex, IN.uv_MainTex + half2(0, _Time.x * _FlowV)).g;

				o.Emission   = flowTexU * flowTexV * _Brightness;

				o.Albedo     = fixed3(0, 0, 0);
				o.Alpha      = 0;
				o.Metallic   = 0;
				o.Smoothness = 0;
			}
		ENDCG
	}

	Fallback "Transparent/Diffuse"
}