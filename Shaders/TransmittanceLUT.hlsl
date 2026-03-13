// Production Ready Atmosphere Rendering technique, shader TransmittanceLUT
/*$(ShaderResources)*/

/*$(Embed:Common.hlsl)*/

#define RAYMARCH_STEPS 40 // Taken from source paper

static float2 PlanetRadius = /*$(Variable:PlanetRadius)*/;

static float3 MieScatteringBase = /*$(Variable:MieScatteringBase)*/;
static float3 MieAbsorptionBase = /*$(Variable:MieAbsorptionBase)*/;
static float3 RayleighScatteringBase = /*$(Variable:RayleighScatteringBase)*/;
static float3 RayleighAbsorptionBase = /*$(Variable:RayleighAbsorptionBase)*/;
static float3 OzoneAbsorptionBase = /*$(Variable:OzoneAbsorptionBase)*/;

// Get the atmospheric transmittance for a position and direction
float3 GetTransmittance(float3 pos, float3 dir)
{
	// Only calculate transmittance for rays going though the atmosphere
	float atmoDist = IntersectPlanet(pos, dir, PlanetRadius.y);
	if (atmoDist < 0.0) {
		return float3(0, 0, 0);
	}

	// Raymarch transmittance only
	float dt = atmoDist / RAYMARCH_STEPS;
	float3 transmittance = float3(1, 1, 1);
	for (uint i = 0; i < RAYMARCH_STEPS; i++)
	{
		// Calculate sample position and surface height
		float3 samplePos = pos + dir * i * dt;
		float surfaceHeight = max(0, length(samplePos) - PlanetRadius.x);

		// Calculate scattering coefficients based on height density profile
		float3 mieScattering = MieScatteringBase;
		float3 mieAbsorption = MieAbsorptionBase;
		float3 rayleighScattering = RayleighScatteringBase;
		float3 rayleighAbsorption = RayleighAbsorptionBase;
		float3 ozoneAbsorption = OzoneAbsorptionBase;
		float3 extinction = GetScatteringCoefficients(surfaceHeight, mieScattering, mieAbsorption, rayleighScattering, rayleighAbsorption, ozoneAbsorption);

		// Update transmittance
		transmittance *= exp(-dt * extinction);
	}

	return transmittance;
}

/*$(_compute:main)*/(uint3 DTid : SV_DispatchThreadID)
{
	float2 lutSize;
	TransmittanceLUT.GetDimensions(lutSize.x, lutSize.y);

	uint2 pixel = DTid.xy;
	float2 pixelCenter = pixel + float2(0.5, 0.5);
	float2 uv = pixelCenter / lutSize;

	float sunCosTheta = 2.0 * uv.x - 1.0;
	float sunTheta = safeacos(sunCosTheta); // Angle between sun and horizon
	float height = lerp(PlanetRadius.x, PlanetRadius.y, uv.y); // Height above surface

	float3 pos = float3(0, height, 0);
	float3 sunDir = SphericalToCarthesian(0.0, sunTheta);
	TransmittanceLUT[pixel] = float4(GetTransmittance(pos, sunDir), 1);
}

/*
Shader Resources:
	Texture TransmittanceLUT (as UAV)
*/
