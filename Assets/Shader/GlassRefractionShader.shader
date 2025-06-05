Shader "Custom/URP/GlassRefraction"
{
    Properties
    {
        _MainTex ("Main Tex", 2D) = "white" {}
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _Cubemap ("Environment Cubemap", Cube) = "_Skybox" {}
        _Distortion ("Distortion", Range(0, 1)) = 0.2
        _RefractAmount ("Refract Amount", Range(0.0, 1.0)) = 1.0
        _ReflectAmount ("Reflect Amount", Range(0.0, 1.0)) = 0.5
        _IOR ("Index of Refraction", Range(1.0, 2.0)) = 1.5
        _RefractRT ("Refraction RT", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalRenderPipeline" "RenderType" = "Transparent" "Queue" = "Transparent" }
        
        Pass
        {
            HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _BumpMap_ST;
                float _Distortion;
                half _RefractAmount;
                half _ReflectAmount;
                float _IOR; // 折射率
            CBUFFER_END
            
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_BumpMap);
            SAMPLER(sampler_BumpMap);
            TEXTURECUBE(_Cubemap);
            SAMPLER(sampler_Cubemap);
            TEXTURE2D(_RefractRT);
            SAMPLER(sampler_RefractRT);
            
            struct Attributes
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 texcoord : TEXCOORD0;
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                
                float4 uv : TEXCOORD0;
                float4 TtoW0 : TEXCOORD1;
                float4 TtoW1 : TEXCOORD2;
                float4 TtoW2 : TEXCOORD3;
            };
            
            Varyings Vertex(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.vertex.xyz);
                
                output.uv.xy = TRANSFORM_TEX(input.texcoord, _MainTex);
                output.uv.zw = TRANSFORM_TEX(input.texcoord, _BumpMap);
                
                float3 worldPos = TransformObjectToWorld(input.vertex.xyz);
                float3 worldNormal = TransformObjectToWorldNormal(input.normal);
                float3 worldTangent = TransformObjectToWorldDir(input.tangent.xyz);
                float3 worldBinormal = cross(worldNormal, worldTangent) * input.tangent.w;
                
                // 构建从切线空间到世界空间的变换矩阵
                output.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
                output.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
                output.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);
                
                return output;
            }
            
            half4 Fragment(Varyings input) : SV_Target
            {
                float3 worldPos = float3(input.TtoW0.w, input.TtoW1.w, input.TtoW2.w);
                half3 worldViewDir = normalize(_WorldSpaceCameraPos - worldPos);
                
                // 从法线贴图获取法线并转换到世界空间
                half3 bump = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv.zw));
                bump = normalize(half3(
                    dot(input.TtoW0.xyz, bump),
                    dot(input.TtoW1.xyz, bump),
                    dot(input.TtoW2.xyz, bump)
                ));
                
                // 使用斯涅尔定律计算折射向量
                float eta = 1.0 / _IOR; // 空气到玻璃的折射率比
                half3 refractDir = refract(-worldViewDir, bump, eta);
                
                // 添加法线扰动来模拟扭曲效果
                refractDir = normalize(refractDir + bump * _Distortion);
                
                // 计算反射向量
                half3 reflectDir = reflect(-worldViewDir, bump);
                
                // 采样漫反射纹理
                half4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv.xy);
                
                // 从Cubemap采样反射颜色
                half3 reflectCol = SAMPLE_TEXTURECUBE(_Cubemap, sampler_Cubemap, reflectDir).rgb * texColor.rgb;
                //计算折射
                half2 refractUV = refractDir.xy * 0.5 + 0.5;
                refractUV = clamp(refractUV, 0.001, 0.999);
                half3 refractCol = SAMPLE_TEXTURE2D(_RefractRT, sampler_RefractRT, refractUV).rgb;

                // 使用菲涅尔效应计算反射率
                float fresnel = saturate(1.0 - dot(bump, worldViewDir));
                fresnel = pow(fresnel, 5.0);
                
                // 混合反射和折射
                half3 finalColor = lerp(
                    refractCol * _RefractAmount,
                    reflectCol * _ReflectAmount,
                    fresnel
                );
                
                return half4(finalColor, 1);
            }
            ENDHLSL
            
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off
            
            HLSLPROGRAM
            #pragma vertex Vertex
            #pragma fragment Fragment
            ENDHLSL
        }
    }
    //FallBack "Universal Render Pipeline/Unlit"
}