using UnityEngine;

public class FrameTimeUI : MonoBehaviour
{
    private double _cpuFrameTime;
    private double _gpuFrameTime;

    private void LateUpdate()
    {
        _cpuFrameTime = FrameTime.Instance.CpuFrameTime;
        _gpuFrameTime = FrameTime.Instance.GpuFrameTime;
    }

    private void OnGUI()
    {
        GUI.Label(new Rect(8, 8, 300, 100), $"CPU : {_cpuFrameTime}");
        GUI.Label(new Rect(8, 108, 300, 100), $"GPU : {_gpuFrameTime}");
    }
}