Shader "Custom/URP/BumpedDiffuseShaderQQ"
{
    Properties
    {
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
        _MainTex ("Main Tex", 2D) = "white" {}
        _BumpMap ("Normal Map", 2D) = "bump" {}
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalRenderPipeline" "RenderType" = "Opaque"}
        
        Pass
        {
            HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
                float4 _MainTex_ST;
                float4 _BumpMap_ST;
            CBUFFER_END
            
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_BumpMap);
            SAMPLER(sampler_BumpMap);
            
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
                float2 uvMain : TEXCOORD0;
                float2 uvBump : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                float3 worldNormal : TEXCOORD3;
                float3 worldTangent : TEXCOORD4;
                float3 worldBinormal : TEXCOORD5;
            };
            
            Varyings Vertex(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.vertex.xyz);
                
                output.uvMain = TRANSFORM_TEX(input.texcoord, _MainTex);
                output.uvBump = TRANSFORM_TEX(input.texcoord, _BumpMap);
                
                output.worldPos = TransformObjectToWorld(input.vertex.xyz);
                output.worldNormal = TransformObjectToWorldNormal(input.normal);
                output.worldTangent = TransformObjectToWorldDir(input.tangent.xyz);
                output.worldBinormal = cross(output.worldNormal, output.worldTangent) * input.tangent.w;
                
                return output;
            }


            half4 Fragment(Varyings input) : SV_Target
            {
                
                half3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uvMain).rgb * _Color.rgb;
                half3 bump = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uvBump));
                half3 bumpWorld = normalize(
                    bump.x * input.worldTangent +
                    bump.y * input.worldBinormal +
                    bump.z * input.worldNormal
                );
                
                Light mainLight = GetMainLight();
                half3 lightDir = normalize(mainLight.direction);
                half3 viewDir = normalize(_WorldSpaceCameraPos - input.worldPos);
                
                half3 ambient = half3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w) * albedo * 0.5;
                half3 diffuse = mainLight.color.rgb * albedo * max(0, dot(bumpWorld, lightDir)) * mainLight.shadowAttenuation * 0.5;
                
                return half4(ambient + diffuse, 1.0);
            }
            ENDHLSL
            
            Tags { "LightMode" = "UniversalForward" }
            ZWrite On
            Blend Off
        }

    }
    //FallBack "Universal Render Pipeline/Lit"
}
