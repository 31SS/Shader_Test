using UnityEngine;

public class LineUp : MonoBehaviour
{
    public float high;
    public float width;
    public int vertical;
    public int horizontal;
    
    public GameObject Model;
    
    Vector3 pos;

    void Start()
    {
        pos = transform.position;
        
        for (int vi = 0; vi < vertical; vi++)
        {
            for (int hi = 0; hi < horizontal; hi++)
            {
                GameObject copy = Instantiate(Model,new Vector3(pos.x + horizontal * width / 2 - hi * width - width / 2,high,
                    pos.z + vertical * width / 2 - vi * width - width / 2), Quaternion.identity);
            }
        }
    }
}