// Production Ready Atmosphere Rendering technique, shader AerialPerspectiveLUT
/*$(ShaderResources)*/

/*$(Embed:Common.hlsl)*/

#define RAYMARCH_STEPS 30 // Taken from source paper

static const float3 CameraPos = /*$(Variable:CameraPos)*/;
static float4x4 InvViewProjMtx = /*$(Variable:InvViewProjMtx)*/;

static float2 SunDirection = /*$(Variable:SunDirection)*/;
static float3 SunColor = /*$(Variable:SunColor)*/;
static float SunIntensity = /*$(Variable:SunIntensity)*/;

static float2 PlanetRadius = /*$(Variable:PlanetRadius)*/;

static float3 MieScatteringBase = /*$(Variable:MieScatteringBase)*/;
static float3 MieAbsorptionBase = /*$(Variable:MieAbsorptionBase)*/;
static float3 RayleighScatteringBase = /*$(Variable:RayleighScatteringBase)*/;
static float3 RayleighAbsorptionBase = /*$(Variable:RayleighAbsorptionBase)*/;
static float3 OzoneAbsorptionBase = /*$(Variable:OzoneAbsorptionBase)*/;

static const float AerialPerspectiveDepth = /*$(Variable:AerialPerspectiveDepth)*/;

float4 GetAerialPerspective(float3 pos, float3 dir, float traceDist)
{
	// Calculate sun direction
	float3 lightDir = GetSunDirection(SunDirection);

	// Intersect atmosphere
	float atmoDist = IntersectPlanet(pos, dir, PlanetRadius.y);
	if (atmoDist < 0.0) {
		return float4(0, 0, 0, 0);
	}

	// Raymarch aerial perspective
	traceDist = min(atmoDist, traceDist);
	float dt = traceDist / RAYMARCH_STEPS;
	float3 transmittance = float3(1, 1, 1);
	float3 luminance = float3(0, 0, 0);
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

		// Get multiple scattering energy factor
		float3 psi = GetAtmosphericTransmittance(MultiscatterLUT, LinearSampler, relativeHeight, samplePos, lightDir);

		// Premuliplied phase function modulated scattering, simplifies luminance calculation
		float3 phase = MiePhase(lightCosTheta) * mieScattering + RayleighPhase(lightCosTheta) * rayleighScattering;

		// Apply new transmittance and luminance
		transmittance *= exp(-dt * extinction);
		luminance += (phase * transmittance * lightTransmittance + psi) * SunColor * SunIntensity * dt;
	}

	// Average transmittance into single alpha value for LUT
	float transmittanceAlpha = (transmittance.x + transmittance.y + transmittance.z) / 3.0;
	return float4(luminance, transmittanceAlpha);
}

/*$(_compute:main)*/(uint3 DTid : SV_DispatchThreadID)
{
	float3 lutSize;
	AerialPerspectiveLUT.GetDimensions(lutSize.x, lutSize.y, lutSize.z);

	uint3 froxelIdx = DTid.xyz;
	float3 froxelCenter = froxelIdx + float3(0.5, 0.5, 0.5);
	float3 uvw = froxelCenter / lutSize;

	// Calculate froxel ndc coords
	float2 ndc = 2.0 * uvw.xy - 1.0;
	ndc.y *= -1.0;

	// Get ray direction from ndc
	// This uses froxel w coordinate for shooting ray through the actual center of the froxel instead of through the far plane.
	float4 screenPos = mul(float4(ndc, uvw.z, 1), InvViewProjMtx);
	screenPos.xyz /= screenPos.w;
	float3 viewDir = normalize(screenPos.xyz - CameraPos);

	// Calculate froxel world-space position in megameters based on camera position
	float froxelDist = uvw.z * AerialPerspectiveDepth * 1000.0; // Froxel distance from camera in meters
	float3 viewPos = float3(0, PlanetRadius.x, 0) + CameraPos * 1e-6;
	float3 froxelPos = viewPos + 1e-6 * froxelDist * viewDir; // Froxel position in megameters

	// Get aerial perspective LUT value based on froxel position and view direction
	AerialPerspectiveLUT[froxelIdx] = GetAerialPerspective(viewPos, viewDir, 1e-6 * froxelDist);
}

/*
Shader Resources:
	Texture TransmittanceLUT (as SRV)
	Texture MultiscatterLUT (as SRV)
	Texture AerialPerspectiveLUT (as UAV)
Shader Samplers:
	LinearSampler filter: MinMagMipLinear addressmode: Clamp
*/
