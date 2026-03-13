// Production Ready Atmosphere Rendering technique, shader MultiscatterLUT
/*$(ShaderResources)*/

/*$(Embed:Common.hlsl)*/

#define DIRECTION_INTEGRATION_STEPS 8	// Taken from source paper, 8 azimuth and 8 zenith directions are used for multiple scattering integration
#define RAYMARCH_STEPS 				20 	// Taken from source paper

static float2 PlanetRadius = /*$(Variable:PlanetRadius)*/;

static float3 MieScatteringBase = /*$(Variable:MieScatteringBase)*/;
static float3 MieAbsorptionBase = /*$(Variable:MieAbsorptionBase)*/;
static float3 RayleighScatteringBase = /*$(Variable:RayleighScatteringBase)*/;
static float3 RayleighAbsorptionBase = /*$(Variable:RayleighAbsorptionBase)*/;
static float3 OzoneAbsorptionBase = /*$(Variable:OzoneAbsorptionBase)*/;

// Get unitless incoming luminance as a transfor function of luminance per steradian for a position and direction.
// Also outputs luminance factor for energy transfer.
float3 GetIncomingLuminance(float3 pos, float3 dir, out float3 luminanceFactor)
{
	// TODO(nemjit001): Integrate unitless luminance for direction and accumulate luminance factor at the same time
	float3 luminance = float3(0, 0, 0);
	luminanceFactor = float3(0, 0, 0);

	return luminance;
}

// Get the multiple scattering values (2nd order luminance and multiple scattering factor) for a position and direction.
float3 GetMultiscatterValues(float3 pos, float3 dir, out float3 multiscatterFactor)
{
	float dt = TWO_PI / DIRECTION_INTEGRATION_STEPS;
	float3 luminance = float3(0, 0, 0);
	multiscatterFactor = float3(0, 0, 0);
	for (uint x = 0; x < DIRECTION_INTEGRATION_STEPS; x++)
	{
		for (uint y = 0; y < DIRECTION_INTEGRATION_STEPS; y++)
		{
			// Generate a sample ray direction phi and theta ranged in [-PI, PI]
			float phi = x * dt - PI;
			float theta = y * dt - PI;
			float3 rayDir = SphericalToCarthesian(phi, theta);

			// Calculate incoming luminance and multiple scattering factor for ray
			float3 luminanceFactor;
			luminance += GetIncomingLuminance(pos, rayDir, luminanceFactor);
			multiscatterFactor += luminanceFactor;
		}
	}

	// Scale taken samples to get integration result
	float invSamples = 1.0 / (DIRECTION_INTEGRATION_STEPS * DIRECTION_INTEGRATION_STEPS);
	multiscatterFactor *= invSamples;
	luminance *= invSamples;

	// Finally convert multisactter factor fms to Fms from paper
	multiscatterFactor = 1.0 / (1.0 - multiscatterFactor);

	// Done :)
	return luminance;
}

/*$(_compute:main)*/(uint3 DTid : SV_DispatchThreadID)
{
	float2 lutSize;
	MultiscatterLUT.GetDimensions(lutSize.x, lutSize.y);

	uint2 pixel = DTid.xy;
	float2 pixelCenter = pixel + float2(0.5, 0.5);
	float2 uv = pixelCenter / lutSize;

	float dirCosTheta = 2.0 * uv.x - 1.0;
	float dirTheta = safeacos(dirCosTheta); // Angle between direction and horizon
	float height = lerp(PlanetRadius.x, PlanetRadius.y, uv.y); // Height above surface

	float3 pos = float3(0, height, 0);
	float3 dir = SphericalToCarthesian(0.0, dirTheta);

	float3 multiscatterFactor;
	float3 luminance = GetMultiscatterValues(pos, dir, multiscatterFactor);
	float3 psi = luminance * multiscatterFactor;
	MultiscatterLUT[pixel] = float4(psi, 1);
}

/*
Shader Resources:
	Texture TransmittanceLUT (as SRV)
	Texture MultiscatterLUT (as UAV)
	Sampler LinearSampler (as SamplerState)
*/
