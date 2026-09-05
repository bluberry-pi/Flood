Shader "Custom/BubbleDissolve"
{
    Properties
    {
        _BubbleColor      ("Bubble Color", Color) = (1,1,1,1)

        [Header(Growth)]
        _GrowEnd          ("Grow-In End (age)", Range(0,1)) = 0.15

        [Header(Shape Distortion)]
        _EdgeNoiseScale   ("Edge Noise Scale", Float) = 2.0
        _EdgeNoiseStrength("Edge Noise Strength", Float) = 0.18
        _NoiseTiling      ("Noise UV Tiling", Float) = 4.0
        _NoiseSeedSpreadX ("Noise Seed Spread X", Float) = 12.7
        _NoiseSeedSpreadY ("Noise Seed Spread Y", Float) = 31.3

        [Header(Bubble Edge)]
        _BubbleEdgeMin    ("Bubble Edge Inner", Float) = 0.40
        _BubbleEdgeMax    ("Bubble Edge Outer", Float) = 0.45

        [Header(Late Life Shrink)]
        _ShrinkStart      ("Shrink Start (age)", Range(0,1)) = 0.65
        _ShrinkEnd        ("Shrink End (age)", Range(0,1)) = 0.90
        _ShrinkFactor     ("Shrink Factor (>1 = shrinks)", Float) = 4.0

        [Header(Holes)]
        _VoronoiCellDensityStart("Hole Cell Density - Start (few big holes)", Float) = 1.5
        _VoronoiCellDensityEnd("Hole Cell Density - End (dense foam)", Float) = 4.0
        _VoronoiAngleOffset("Hole Angle Offset", Float) = 5.0
        _HoleEdgeMin      ("Hole Edge Inner", Float) = 0.10
        _HoleEdgeMax      ("Hole Edge Outer", Float) = 0.13
        _HoleFadeStart    ("Hole Fade-In Start (age)", Range(0,1)) = 0.15
        _HoleFadeEnd      ("Hole Fade-In End (age)", Range(0,1)) = 0.35
        _HoleThresholdMid ("Mid-Life Hole Threshold", Float) = 0.22
        _HoleThresholdLate("Late-Life Hole Threshold (breakup)", Float) = 0.06

        [Header(Dissolve)]
        _DissolveStart    ("Full Dissolve Start (age)", Range(0,1)) = 0.90
        _DissolveEnd      ("Full Dissolve End (age)", Range(0,1)) = 1.00
    }

    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "RenderPipeline"="UniversalPipeline" "IgnoreProjector"="True" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // ---------------------------------------------------------
            // Vertex input.
            // TEXCOORD0 is fed by the Particle System's Custom Vertex
            // Streams:  x,y = mesh UV | z = per-particle random seed
            // (stable for the particle's whole life) | w = AgePercent.
            // See setup notes below the shader.
            // ---------------------------------------------------------
            struct Attributes
            {
                float4 positionOS : POSITION;
                float4 uvData     : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float4 uvData      : TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _BubbleColor;
                float  _GrowEnd;
                float  _EdgeNoiseScale;
                float  _EdgeNoiseStrength;
                float  _NoiseTiling;
                float  _NoiseSeedSpreadX;
                float  _NoiseSeedSpreadY;
                float  _BubbleEdgeMin;
                float  _BubbleEdgeMax;
                float  _ShrinkStart;
                float  _ShrinkEnd;
                float  _ShrinkFactor;
                float  _VoronoiCellDensityStart;
                float  _VoronoiCellDensityEnd;
                float  _VoronoiAngleOffset;
                float  _HoleEdgeMin;
                float  _HoleEdgeMax;
                float  _HoleFadeStart;
                float  _HoleFadeEnd;
                float  _HoleThresholdMid;
                float  _HoleThresholdLate;
                float  _DissolveStart;
                float  _DissolveEnd;
            CBUFFER_END

            // ---------------- Gradient (Perlin-style) noise ----------------
            float2 GradientNoiseDir(float2 p)
            {
                p = fmod(p, 289.0);
                float x = fmod((34.0 * p.x + 1.0) * p.x, 289.0) + p.y;
                x = fmod((34.0 * x + 1.0) * x, 289.0);
                x = frac(x / 41.0) * 2.0 - 1.0;
                return normalize(float2(x - floor(x + 0.5), abs(x) - 0.5));
            }

            float GradientNoise(float2 p)
            {
                float2 ip = floor(p);
                float2 fp = frac(p);
                float d00 = dot(GradientNoiseDir(ip), fp);
                float d01 = dot(GradientNoiseDir(ip + float2(0.0, 1.0)), fp - float2(0.0, 1.0));
                float d10 = dot(GradientNoiseDir(ip + float2(1.0, 0.0)), fp - float2(1.0, 0.0));
                float d11 = dot(GradientNoiseDir(ip + float2(1.0, 1.0)), fp - float2(1.0, 1.0));
                fp = fp * fp * fp * (fp * (fp * 6.0 - 15.0) + 10.0);
                return lerp(lerp(d00, d01, fp.y), lerp(d10, d11, fp.y), fp.x);
            }

            float SampleGradientNoise(float2 uv, float scale)
            {
                return GradientNoise(uv * scale) + 0.5;
            }

            // ---------------- Voronoi (cellular) noise ----------------
            float2 VoronoiRandomVector(float2 uv, float offset)
            {
                float2x2 m = float2x2(15.27, 47.63, 99.41, 89.98);
                uv = frac(sin(mul(uv, m)) * 46839.32);
                return float2(sin(uv.y * offset) * 0.5 + 0.5, cos(uv.x * offset) * 0.5 + 0.5);
            }

            float SampleVoronoi(float2 uv, float angleOffset, float cellDensity)
            {
                float2 g = floor(uv * cellDensity);
                float2 f = frac(uv * cellDensity);
                float minDist = 8.0;
                for (int y = -1; y <= 1; y++)
                {
                    for (int x = -1; x <= 1; x++)
                    {
                        float2 lattice = float2((float)x, (float)y);
                        float2 offset = VoronoiRandomVector(lattice + g, angleOffset);
                        float d = distance(lattice + offset, f);
                        minDist = min(minDist, d);
                    }
                }
                return minDist;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uvData = IN.uvData;
                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                float2 uv          = IN.uvData.xy;
                float  randomSeed  = IN.uvData.z;
                float  agePercent  = saturate(IN.uvData.w);

                float2 centered = uv - 0.5;
                float distFromCenter = length(centered);

                // Shared noise coordinate: tiled UV + per-particle random offset,
                // so every particle's distortion/holes look different.
                float2 noiseCoord = uv * float2(_NoiseTiling, _NoiseTiling)
                                    + randomSeed * float2(_NoiseSeedSpreadX, _NoiseSeedSpreadY);

                // ---- Organic edge distortion (not a perfect circle) ----
                float edgeNoise = SampleGradientNoise(noiseCoord, _EdgeNoiseScale);
                float edgeDistortion = (edgeNoise - 0.5) * _EdgeNoiseStrength;
                float radiusField = distFromCenter + edgeDistortion;

                // ---- Grow-in (0 -> _GrowEnd): bubble expands from a point ----
                float growT = 1.0 - smoothstep(0.0, _GrowEnd, agePercent);
                // growT: 1 at birth (radius pushed huge = invisible), 0 once fully grown
                float growPenalty = growT * 4.0;

                // ---- Late-life shrink (_ShrinkStart -> _ShrinkEnd) ----
                float lateAgeT = smoothstep(_ShrinkStart, _ShrinkEnd, agePercent);
                float shrinkFactor = lerp(1.0, _ShrinkFactor, lateAgeT);

                float scaledRadius = radiusField * shrinkFactor + growPenalty;

                float bubbleEdge = smoothstep(_BubbleEdgeMin, _BubbleEdgeMax, scaledRadius);
                float bubbleMask = 1.0 - bubbleEdge;

                // ---- Cellular holes ----
                // Cell density grows across the particle's whole life (up to the
                // start of breakup) so the pattern goes from a few big holes to a
                // dense foam/net, matching the reference footage, instead of just
                // fading a fixed pattern in.
                float densityT = smoothstep(0.0, _ShrinkStart, agePercent);
                float cellDensity = lerp(_VoronoiCellDensityStart, _VoronoiCellDensityEnd, densityT);
                float voronoiOut = SampleVoronoi(noiseCoord, _VoronoiAngleOffset, cellDensity);

                float midAgeT = smoothstep(_HoleFadeStart, _HoleFadeEnd, agePercent);
                float holeThresholdMid  = lerp(1.0, _HoleThresholdMid, midAgeT);
                float holeThresholdLate = lerp(1.0, _HoleThresholdLate, lateAgeT);
                float combinedThreshold = holeThresholdMid * holeThresholdLate;

                float holeRaw  = voronoiOut * combinedThreshold;
                float holeEdge = smoothstep(_HoleEdgeMin, _HoleEdgeMax, holeRaw);
                float holeMask = 1.0 - holeEdge;

                float holeBlend = lerp(1.0, holeMask, midAgeT);

                // ---- Final dissolve to zero ----
                float dissolveT = 1.0 - smoothstep(_DissolveStart, _DissolveEnd, agePercent);

                float alpha = bubbleMask * holeBlend * dissolveT;

                return float4(_BubbleColor.rgb, _BubbleColor.a * alpha);
            }
            ENDHLSL
        }
    }
}
