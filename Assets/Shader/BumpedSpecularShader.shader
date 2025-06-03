Shader "Custom/URP/BumpedSpecularShader"
{
    Properties
    {
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
        _MainTex ("Main Tex", 2D) = "white" {}
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _Specular ("Specular Color", Color) = (1, 1, 1, 1)
        _Gloss ("Gloss", Range(8.0, 256)) = 20
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry"}
        LOD 100

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

        CBUFFER_START(UnityPerMaterial)
            half4 _Color;
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            float4 _MainTex_ST;
            TEXTURE2D(_BumpMap);
            SAMPLER(sampler_BumpMap);
            float4 _BumpMap_ST;
            half4 _Specular;
            half _Gloss;
        CBUFFER_END

        struct Attributes
        {
            float4 vertex : POSITION;
            float3 normal : NORMAL;
            float4 tangent : TANGENT;
            float4 texcoord : TEXCOORD0;
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float4 uv : TEXCOORD0;
            float4 TtoW0 : TEXCOORD1;
            float4 TtoW1 : TEXCOORD2;
            float4 TtoW2 : TEXCOORD3;
            //float3 worldPos : TEXCOORD4; // 世界位置
            float4 shadowCoord : TEXCOORD5; // 阴影坐标
        };

        Varyings Vertex(Attributes input)
        {
            Varyings output;
            output.positionCS = TransformObjectToHClip(input.vertex.xyz);
            output.uv.xy = TRANSFORM_TEX(input.texcoord, _MainTex);
            output.uv.zw = TRANSFORM_TEX(input.texcoord, _BumpMap);
            
            //output.uv = TRANSFORM_TEX(input.texcoord, _MainTex);

            float3 worldPos = TransformObjectToWorld(input.vertex.xyz);

            float3 worldNormal = TransformObjectToWorldNormal(input.normal);
            float3 worldTangent = TransformObjectToWorldDir(input.tangent.xyz);
            float3 worldBinormal = cross(worldNormal, worldTangent) * input.tangent.w;

            output.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
            output.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
            output.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);

            output.shadowCoord = TransformWorldToShadowCoord(worldPos);
            return output;
        }

        half4 Fragment(Varyings input) : SV_Target
        {
            half3 worldPos = float3(input.TtoW0.w, input.TtoW1.w, input.TtoW2.w);
            half3 lightDir = normalize(_MainLightPosition.xyz - worldPos);
            half3 viewDir = normalize(_WorldSpaceCameraPos - worldPos);

            half3 bump = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap,sampler_BumpMap, input.uv.zw));
            bump = normalize(half3(dot(input.TtoW0.xyz, bump), dot(input.TtoW1.xyz, bump), dot(input.TtoW2.xyz, bump)));

            //half3 albedo = tex2D(sampler_MainTex, input.uv.xy).rgb * _Color.rgb;
            half3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv.xy).rgb * _Color.rgb;

            half3 ambient = _MainLightColor.rgb * albedo;
            
            half3 diffuse = _MainLightColor.rgb * albedo * max(0, dot(bump, lightDir));

            half3 halfDir = normalize(lightDir + viewDir);
            half3 specular = _MainLightColor.rgb * _Specular.rgb * pow(max(0, dot(bump, halfDir)), _Gloss);

            half shadow = MainLightRealtimeShadow(input.shadowCoord);
            
            return half4(ambient + (diffuse + specular) * shadow, 1.0);
        }
        ENDHLSL

        Pass
        {
            Tags { "LightMode" = "UniversalForward" }
            HLSLPROGRAM
            #pragma vertex Vertex
            #pragma fragment Fragment
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            ENDHLSL
        }
    }
    FallBack "Universal Render Pipeline/Lit"
}
