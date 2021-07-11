using UnityEngine;
using System.Collections;

public class PostEffect_c : MonoBehaviour {

	public Material sepia;

	void OnRenderImage(RenderTexture src, RenderTexture dest)
	{
		Graphics.Blit (src, dest, sepia);
	}
}