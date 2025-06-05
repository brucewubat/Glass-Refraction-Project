using UnityEngine;

public class RefractCameraRender : MonoBehaviour
{
    public Camera envCamera; // 拖入上面创建的 EnvCamera
    
    
    void Update()
    {
        // 每一帧让环境相机渲染到 RenderTexture
        envCamera.Render(); 
        
    }
}