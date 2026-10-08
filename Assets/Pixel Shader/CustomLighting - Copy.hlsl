#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED


// ============================================================
// CUSTOM SPECULAR
// ============================================================

float LightingSpecularCustom(
    float3 L,
    float3 N,
    float3 V,
    float smoothness
)
{
    float3 H = SafeNormalize(L + V);
    float NdotH = saturate(dot(N, H));
    return pow(NdotH, smoothness);
}


// ============================================================
// MAIN LIGHTING
// ============================================================

void MainLighting_float(
    float3 normalWS,
    float3 positionWS,
    float3 viewWS,
    float smoothness,
    out float specular
)
{
    // Always give Shader Graph Preview a valid output
    specular = 0.0;

#ifndef SHADERGRAPH_PREVIEW

    // Only include URP lighting when NOT in Shader Graph Preview
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

    smoothness = exp2(10.0 * smoothness + 1.0);

    normalWS = normalize(normalWS);
    viewWS = SafeNormalize(viewWS);

    Light mainLight = GetMainLight(
        TransformWorldToShadowCoord(positionWS)
    );

    specular = LightingSpecularCustom(
        mainLight.direction,
        normalWS,
        viewWS,
        smoothness
    );

#endif
}


// ============================================================
// ADDITIONAL LIGHTING
// ============================================================

void AdditionalLighting_float(
    float3 normalWS,
    float3 positionWS,
    float3 viewWS,
    float2 screenUV,
    float smoothness,
    float hardness,
    out float3 specular
)
{
    // Always give Shader Graph Preview a valid output
    specular = float3(0.0, 0.0, 0.0);

#ifndef SHADERGRAPH_PREVIEW

    smoothness = exp2(10.0 * smoothness + 1.0);

    normalWS = normalize(normalWS);
    viewWS = SafeNormalize(viewWS);


    // --------------------------------------------------------
    // InputData
    // Required for Unity 6 Forward+
    // --------------------------------------------------------

    InputData inputData = (InputData)0;

    inputData.positionWS = positionWS;
    inputData.normalWS = normalWS;
    inputData.viewDirectionWS = viewWS;
    inputData.normalizedScreenSpaceUV = screenUV;


    // --------------------------------------------------------
    // Forward+
    // --------------------------------------------------------

#if USE_FORWARD_PLUS

    UNITY_LOOP

    for (
        uint lightIndex = 0;
        lightIndex < min(
            URP_FP_DIRECTIONAL_LIGHTS_COUNT,
            MAX_VISIBLE_LIGHTS
        );
        lightIndex++
    )
    {
        Light light = GetAdditionalLight(
            lightIndex,
            inputData.positionWS,
            half4(1.0, 1.0, 1.0, 1.0)
        );

        float3 attenuatedLight =
            light.color *
            light.distanceAttenuation *
            light.shadowAttenuation;

        float specularSoft =
            LightingSpecularCustom(
                light.direction,
                inputData.normalWS,
                inputData.viewDirectionWS,
                smoothness
            );

        float specularHard =
            smoothstep(
                0.005,
                0.01,
                specularSoft
            );

        float specularTerm =
            lerp(
                specularSoft,
                specularHard,
                hardness
            );

        specular +=
            specularTerm *
            attenuatedLight;
    }

#endif


    // --------------------------------------------------------
    // Normal Forward additional lights
    // --------------------------------------------------------

#if defined(_ADDITIONAL_LIGHTS)

    uint pixelLightCount =
        GetAdditionalLightsCount();

    LIGHT_LOOP_BEGIN(pixelLightCount)

        Light light = GetAdditionalLight(
            lightIndex,
            inputData.positionWS,
            half4(1.0, 1.0, 1.0, 1.0)
        );

        float3 attenuatedLight =
            light.color *
            light.distanceAttenuation *
            light.shadowAttenuation;

        float specularSoft =
            LightingSpecularCustom(
                light.direction,
                inputData.normalWS,
                inputData.viewDirectionWS,
                smoothness
            );

        float specularHard =
            smoothstep(
                0.005,
                0.01,
                specularSoft
            );

        float specularTerm =
            lerp(
                specularSoft,
                specularHard,
                hardness
            );

        specular +=
            specularTerm *
            attenuatedLight;

    LIGHT_LOOP_END

#endif

#endif
}


#endif