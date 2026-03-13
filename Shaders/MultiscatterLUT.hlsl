// Production Ready Atmosphere Rendering technique, shader MultiscatterLUT
/*$(ShaderResources)*/

/*$(Embed:Common.hlsl)*/

#define DIRECTION_INTEGRATION_STEPS 8	// Taken from source paper, 8 azimuth and 8 zenith directions are used for multiple scattering integration
#define RAYMARCH_STEPS 				20 	// Taken from source paper

static float2 PlanetRadius = /*$(Variable:PlanetRadius)*/;
static float3 GroundAlbedo = /*$(Variable:GroundAlbedo)*/;

static float3 MieScatteringBase = /*$(Variable:MieScatteringBase)*/;
static float3 MieAbsorptionBase = /*$(Variable:MieAbsorptionBase)*/;
static float3 RayleighScatteringBase = /*$(Variable:RayleighScatteringBase)*/;
static float3 RayleighAbsorptionBase = /*$(Variable:RayleighAbsorptionBase)*/;
static float3 OzoneAbsorptionBase = /*$(Variable:OzoneAbsorptionBase)*/;

// Get unitless incoming luminance as a transfer function of luminance per steradian for a position, view, and light direction.
// Also outputs luminance factor for energy transfer.
float3 GetIncomingLuminance(float3 pos, float3 viewDir, float3 lightDir, out float3 luminanceFactor)
{
	// Intersect surface and atmosphere
	float surfaceDist = IntersectPlanet(pos, lightDir, PlanetRadius.x);
	float atmoDist = IntersectPlanet(pos, lightDir, PlanetRadius.y);
	if (atmoDist < 0.0) {
		return float3(0, 0, 0);
	}
	
	// Raymarch incoming luminance
	float hitDist = surfaceDist >= 0.0 ? surfaceDist : atmoDist;
	float dt = hitDist / RAYMARCH_STEPS;
	float3 transmittance = float3(1, 1, 1);
	float3 luminance = float3(0, 0, 0);
	luminanceFactor = float3(0, 0, 0);
	for (uint i = 0; i < RAYMARCH_STEPS; i++)
	{
		// Calculate light sample position and surface height
		float3 samplePos = pos + lightDir * i * dt;
		float surfaceHeight = max(0, length(samplePos) - PlanetRadius.x);
		float relativeHeight = surfaceHeight / (PlanetRadius.y - PlanetRadius.x);

		// Calculate scattering coefficients based on height density profile
		float3 mieScattering = MieScatteringBase;
		float3 mieAbsorption = MieAbsorptionBase;
		float3 rayleighScattering = RayleighScatteringBase;
		float3 rayleighAbsorption = RayleighAbsorptionBase;
		float3 ozoneAbsorption = OzoneAbsorptionBase;
		float3 extinction = GetScatteringCoefficients(surfaceHeight, mieScattering, mieAbsorption, rayleighScattering, rayleighAbsorption, ozoneAbsorption);
		float3 scattering = rayleighScattering + mieScattering;
		
		// Calculate transmittance of light through volume
		float lightCosTheta = dot(viewDir, lightDir);
		float3 lightTransmittance = GetAtmosphericTransmittance(TransmittanceLUT, LinearSampler, relativeHeight, samplePos, viewDir);

		// Premuliplied phase function modulated scattering, same as used in sky view LUT
		float3 phase = IsotropicPhase(lightCosTheta) * mieScattering + IsotropicPhase(lightCosTheta) * rayleighScattering;

		// Update transmittance, luminance, and Lf
		transmittance *= exp(-dt * extinction);
		luminance += phase * transmittance * lightTransmittance * dt;
		luminanceFactor += scattering * transmittance * dt;
	}

	// Apply light scattered from surface as ground diffuse response based on ray dir
	if (surfaceDist > 0.0)
	{
		float3 groundNormal = normalize(pos);
		float3 diffuse = GroundAlbedo * clamp(dot(groundNormal, lightDir), 0, 1);
		luminance += transmittance * diffuse;
	}

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
			float3 lightDir = SphericalToCarthesian(phi, theta);

			// Calculate isotropic phase function
			float lightCosTheta = dot(dir, lightDir);
			float3 phase = IsotropicPhase(lightCosTheta);

			// Calculate incoming luminance and multiple scattering factor for ray and view direction
			// Isotropic phase function is applied to integrands according to equation 5 and 7 from paper.
			float3 luminanceFactor;
			luminance += GetIncomingLuminance(pos, dir, lightDir, luminanceFactor) * phase;
			multiscatterFactor += luminanceFactor * phase;
		}
	}

	// Scale taken samples to get integration result
	float invSamples = 1.0 / (DIRECTION_INTEGRATION_STEPS * DIRECTION_INTEGRATION_STEPS);
	multiscatterFactor *= invSamples;
	luminance *= invSamples;

	// Finally convert multiscatter factor fms to Fms from paper
	multiscatterFactor = 1.0 / (1.0 - multiscatterFactor);

	// All done :)
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
