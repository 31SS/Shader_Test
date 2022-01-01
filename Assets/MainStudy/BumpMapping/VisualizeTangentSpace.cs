using System.Collections;
using System.Collections.Generic;
using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
#endif
public class VisualizeTangentSpace : MonoBehaviour
{
}
#if UNITY_EDITOR
[CustomEditor(typeof(VisualizeTangentSpace))]
public class VisualizeTangentSpaceEditor: Editor
{
    private int _targetIndex = 0;
    private VisualizeTangentSpace _target;
    private Mesh _mesh;
    private Vector3 _modelPos;
    private Vector3 _normal;
    private Vector3 _tangent;
    private Vector3 _binormal;

    public override void OnInspectorGUI ()
    {
        _targetIndex = EditorGUILayout.IntSlider(_targetIndex, 0, _mesh.vertexCount - 1);

        if (GUI.changed) {
            var normal = _mesh.normals[_targetIndex];

            // 法線がカメラ方面を向いている時のみ情報を更新する
            var viewDir = SceneView.lastActiveSceneView.camera.transform.position - (_target.transform.position + _modelPos);
            if (Vector3.Dot(viewDir, normal) >= 0) {
                _modelPos = _mesh.vertices[_targetIndex];
                _normal = normal;
                var tangent = _mesh.tangents[_targetIndex];
                _tangent = tangent;
                _binormal = Vector3.Cross(_normal, _tangent) * tangent.w;
            }
        }
    }

    private void OnSceneGUI(){
        if (Event.current.type == EventType.Repaint) {
            var transform = _target.transform;
            Handles.color = Color.red;
            Handles.ArrowHandleCap(0, transform.position + _modelPos, transform.rotation * Quaternion.LookRotation(_tangent), 1.0f, EventType.Repaint);
            Handles.color = Color.green;
            Handles.ArrowHandleCap(0, transform.position + _modelPos, transform.rotation * Quaternion.LookRotation(_binormal), 1.0f, EventType.Repaint);
            Handles.color = Color.blue;
            Handles.ArrowHandleCap(0, transform.position + _modelPos, transform.rotation * Quaternion.LookRotation(_normal), 1.0f, EventType.Repaint);
        }
    }

    private void OnEnable()
    {
        _target = target as VisualizeTangentSpace;
        _mesh = _target.GetComponent<MeshFilter>().sharedMesh;
        _modelPos = _mesh.vertices[_targetIndex];
        _normal = _mesh.normals[_targetIndex];
        _tangent = _mesh.tangents[_targetIndex];
    }
}
#endif