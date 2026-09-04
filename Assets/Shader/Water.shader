Shader "Custom/Water"
{
    Properties
    {
        [MainTexture] _BaseMap ("Water Texture", 2D) = "white" {}
        [MainColor] _BaseColor ("Water Color", Color) = (1,1,1,1)

        _FlowStrength ("Flow Strength", Range(0, 0.08)) = 0.018
        _FlowSpeed ("Flow Speed", Range(0, 1)) = 0.12
        _FlowScale ("Flow Scale", Range(1, 20)) = 4

        [Header(Ambient Patchy Foam)]
        _FoamColor ("Foam Color", Color) = (1,1,1,1)
        _FoamScale ("Foam Noise Scale", Range(1, 60)) = 14
        _FoamThreshold ("Foam Coverage (higher = less foam)", Range(0, 1)) = 0.58
        _FoamSoftness ("Foam Edge Softness", Range(0.01, 0.6)) = 0.18
        _FoamDriftSpeed ("Foam Drift Speed", Range(0, 1)) = 0.04
        _FoamFlowInfluence ("Foam Flow Distortion", Range(0, 10)) = 3
    }

    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "RenderPipeline"="UniversalPipeline"
            "Queue"="Geometry"
        }

        Pass
        {
            Name "Water"

            Tags
            {
                "LightMode"="UniversalForward"
            }

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)

                float4 _BaseMap_ST;
                float4 _BaseColor;

                float _FlowStrength;
                float _FlowSpeed;
                float _FlowScale;

                float4 _FoamColor;
                float _FoamScale;
                float _FoamThreshold;
                float _FoamSoftness;
                float _FoamDriftSpeed;
                float _FoamFlowInfluence;

            CBUFFER_END


            Varyings Vert(Attributes IN)
            {
                Varyings OUT;

                OUT.positionHCS =
                    TransformObjectToHClip(
                        IN.positionOS.xyz
                    );

                OUT.uv =
                    TRANSFORM_TEX(
                        IN.uv,
                        _BaseMap
                    );

                return OUT;
            }


            // ============================================================
            // ORGANIC MULTI-DIRECTIONAL FLOW
            // ============================================================

            float2 Flow(float2 uv, out float2 distortionOut)
            {
                float t =
                    _Time.y * _FlowSpeed;


                // --------------------------------------------------------
                // FLOW FIELD 1
                // Mostly diagonal
                // --------------------------------------------------------

                float flow1 =
                    sin(
                        uv.x * _FlowScale
                        + uv.y * (_FlowScale * 0.7)
                        + t
                    );


                // --------------------------------------------------------
                // FLOW FIELD 2
                // Opposite diagonal
                // --------------------------------------------------------

                float flow2 =
                    cos(
                        uv.x * (_FlowScale * 0.65)
                        - uv.y * (_FlowScale * 0.9)
                        - t * 0.8
                    );


                // --------------------------------------------------------
                // FLOW FIELD 3
                // Different direction + slower
                // --------------------------------------------------------

                float flow3 =
                    sin(
                        (uv.x + uv.y)
                        * (_FlowScale * 0.45)
                        + t * 0.45
                    );


                // --------------------------------------------------------
                // FLOW FIELD 4
                // Gives irregular movement
                // --------------------------------------------------------

                float flow4 =
                    cos(
                        (uv.x - uv.y)
                        * (_FlowScale * 0.35)
                        - t * 0.35
                    );


                // --------------------------------------------------------
                // COMBINE THE FIELDS
                // --------------------------------------------------------

                float2 distortion;

                distortion.x =
                    flow1 * 0.45
                    + flow2 * 0.30
                    + flow3 * 0.15
                    + flow4 * 0.10;

                distortion.y =
                    flow2 * 0.45
                    + flow1 * 0.25
                    + flow4 * 0.20
                    + flow3 * 0.10;

                // Raw (un-scaled) distortion, handy for driving foam drift
                distortionOut = distortion;

                // Normalize the result
                distortion *=
                    _FlowStrength;


                return uv + distortion;
            }


            // ============================================================
            // PROCEDURAL NOISE (for ambient patchy foam - no texture needed)
            // ============================================================

            float Hash21(float2 p)
            {
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }

            float ValueNoise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);

                float a = Hash21(i);
                float b = Hash21(i + float2(1, 0));
                float c = Hash21(i + float2(0, 1));
                float d = Hash21(i + float2(1, 1));

                float2 u = f * f * (3.0 - 2.0 * f);

                return lerp(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
            }

            float FBM(float2 p)
            {
                float value = 0.0;
                float amplitude = 0.5;

                [unroll]
                for (int i = 0; i < 4; i++)
                {
                    value += amplitude * ValueNoise(p);
                    p *= 2.0;
                    amplitude *= 0.5;
                }

                return value;
            }


            half4 Frag(Varyings IN) : SV_Target
            {
                // ----------------------------------------------------
                // Flowing base texture (unchanged from before)
                // ----------------------------------------------------
                float2 distortion;
                float2 flowingUV = Flow(IN.uv, distortion);

                half4 water =
                    SAMPLE_TEXTURE2D(
                        _BaseMap,
                        sampler_BaseMap,
                        flowingUV
                    );

                water *= _BaseColor;


                // ----------------------------------------------------
                // AMBIENT PATCHY FOAM
                // Drifts slowly and gets warped by the same flow field
                // so it feels physically connected to the water motion.
                // ----------------------------------------------------
                float2 foamDrift =
                    float2(
                        sin(_Time.y * _FoamDriftSpeed) * 1.5,
                        cos(_Time.y * _FoamDriftSpeed * 0.7) * 1.5
                    );

                float2 foamCoord =
                    IN.uv * _FoamScale
                    + foamDrift
                    + distortion * _FoamFlowInfluence;

                float noiseValue = FBM(foamCoord);

                float patchyFoam =
                    smoothstep(_FoamThreshold, _FoamThreshold + _FoamSoftness, noiseValue);


                // ----------------------------------------------------
                // COMBINE
                // ----------------------------------------------------
                water.rgb = lerp(water.rgb, _FoamColor.rgb, patchyFoam * _FoamColor.a);

                return water;
            }

            ENDHLSL
        }
    }
}
