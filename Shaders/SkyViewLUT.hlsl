// Production Ready Atmosphere Rendering technique, shader SkyViewLUT
/*$(ShaderResources)*/

/*$(Embed:Common.hlsl)*/

#define RAYMARCH_STEPS 30 // Taken from source paper

static float3 CameraPos = /*$(Variable:CameraPos)*/;

static float3 SunColor = /*$(Variable:SunColor)*/;
static float2 SunDirection = /*$(Variable:SunDirection)*/;

static float2 PlanetRadius = /*$(Variable:PlanetRadius)*/;

static float3 MieScatteringBase = /*$(Variable:MieScatteringBase)*/;
static float3 MieAbsorptionBase = /*$(Variable:MieAbsorptionBase)*/;
static float3 RayleighScatteringBase = /*$(Variable:RayleighScatteringBase)*/;
static float3 RayleighAbsorptionBase = /*$(Variable:RayleighAbsorptionBase)*/;
static float3 OzoneAbsorptionBase = /*$(Variable:OzoneAbsorptionBase)*/;

// Get the distant sky view luminance for a position and direction
float3 GetSkyView(float3 pos, float3 dir)
{
	// Calculate sun direction
	float3 lightDir = GetSunDirection(SunDirection);

	// Intersect surface and atmosphere
	float surfaceDist = IntersectPlanet(pos, dir, PlanetRadius.x);
	float atmoDist = IntersectPlanet(pos, dir, PlanetRadius.y);
	if (atmoDist < 0.0) {
		return float3(0, 0, 0);
	}

	// Raymarch sky illumination
	float hitDist = surfaceDist > 0.0 ? surfaceDist : atmoDist; // If we hit the surface we raymarch until surface intersection point
	float dt = hitDist / RAYMARCH_STEPS;
	float3 luminance = float3(0, 0, 0);
	float3 transmittance = float3(1, 1, 1);
	for (uint i = 0; i < RAYMARCH_STEPS; i++)
	{
		// Calculate sample position and surface height
		float3 samplePos = pos + dir * i * dt;
		float surfaceHeight = max(0, length(samplePos) - PlanetRadius.x);
		float relativeHeight = surfaceHeight / (PlanetRadius.y - PlanetRadius.x);

		// Calculate scattering coefficients based on height density profile
		float3 mieScattering = MieScatteringBase;
		float3 mieAbsorption = MieAbsorptionBase;
		float3 rayleighScattering = RayleighScatteringBase;
		float3 rayleighAbsorption = RayleighAbsorptionBase;
		float3 ozoneAbsorption = OzoneAbsorptionBase;
		float3 extinction = GetScatteringCoefficients(surfaceHeight, mieScattering, mieAbsorption, rayleighScattering, rayleighAbsorption, ozoneAbsorption);

		// Calculate transmittance of light through volume
		float lightCosTheta = dot(dir, lightDir);
		float3 lightTransmittance = GetAtmosphericTransmittance(TransmittanceLUT, LinearSampler, relativeHeight, samplePos, lightDir);

		// Premuliplied phase function modulated scattering, simplifies luminance calculation
		float3 phase = MiePhase(lightCosTheta) * mieScattering + RayleighPhase(lightCosTheta) * rayleighScattering;

		// Apply new transmittance and luminance :)
		transmittance *= exp(-dt * extinction);
		luminance += phase * transmittance * lightTransmittance * SunColor * dt;
	}

	return luminance;
}

/*$(_compute:main)*/(uint3 DTid : SV_DispatchThreadID)
{
	float2 lutSize;
	SkyViewLUT.GetDimensions(lutSize.x, lutSize.y);

	uint2 pixel = DTid.xy;
	float2 pixelCenter = pixel + float2(0.5, 0.5);
	float2 uv = pixelCenter / lutSize;

	// Convert uv coords to a view direction in the lat/long texture
	// TODO(nemjit001): Apply nonlinear latitude transformation for packing more detail near horizon
	float phi = (2.0 * uv.x - 1.0) * PI;
	float theta = safeacos(2.0 * uv.y - 1.0);
	float3 viewDir = SphericalToCarthesian(phi, theta);

	float3 viewPos = float3(0, PlanetRadius.x, 0) + CameraPos * 1e-6; // Adds camera position in mega meters to planet surface height
	SkyViewLUT[pixel] = float4(GetSkyView(viewPos, viewDir), 1);
}

/*
Shader Resources:
	Texture TransmittanceLUT (as SRV)
	Texture SkyViewLUT (as UAV)
	Sampler LinearSampler (as SamplerState)
*/
