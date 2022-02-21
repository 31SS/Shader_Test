using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class LineUp : MonoBehaviour
{
    //高さ
    public float high;
    //オブジェクト間の幅
    public float width;
    //上から見て縦、Z軸のオブジェクトの量
    public int vertical;
    //上から見て横、X軸のオブジェクトの量
    public int horizontal;

    //Prefabを入れる欄を作る
    public GameObject Model;

    //位置を入れる変数
    Vector3 pos;

    void Start()
    {
        //このスクリプトを入れたオブジェクトの位置
        pos = transform.position;

        //Z軸にverticalの数だけ並べる
        for (int vi = 0; vi < vertical; vi++)
        {
            //X軸にhorizontalの数だけ並べる
            for (int hi = 0; hi < horizontal; hi++)
            {
                //PrefabのCubeを生成する
                GameObject copy = Instantiate(Model,new Vector3(pos.x + horizontal * width / 2 - hi * width - width / 2,high,
                    pos.z + vertical * width / 2 - vi * width - width / 2), Quaternion.identity);
            }
        }
    }
}