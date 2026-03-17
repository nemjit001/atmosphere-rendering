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

float4 GetAerialPerspective(float3 pos, float3 dir)
{
	// Calculate sun direction
	float3 lightDir = GetSunDirection(SunDirection);

	// Intersect atmosphere
	float atmoDist = IntersectPlanet(pos, dir, PlanetRadius.y);
	if (atmoDist < 0.0) {
		return float4(0, 0, 0, 0);
	}

	// Raymarch aerial perspective
	float dt = atmoDist / RAYMARCH_STEPS;
	float3 luminance = float3(0, 0, 0);
	float3 transmittance = float3(1, 1, 1);
	for (uint i = 0; i < RAYMARCH_STEPS; i++)
	{
		// TODO(nemjit001): Raymarch luminance and transmittance using LUTs and scattering coeffs
	}

	float meanTransmittance = (transmittance.x + transmittance.y + transmittance.z) / 3.0;
	return float4(luminance, meanTransmittance);
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
	float3 froxelPos = CameraPos + froxelDist * viewDir; // Froxel position in meters
	froxelPos *= 1e-6; // Froxel position in megameters

	// Get aerial perspective LUT value based on froxel position and view direction
	AerialPerspectiveLUT[froxelIdx] = GetAerialPerspective(froxelPos, viewDir);
}

/*
Shader Resources:
	Texture TransmittanceLUT (as SRV)
	Texture MultiscatterLUT (as SRV)
	Texture AerialPerspectiveLUT (as UAV)
Shader Samplers:
	LinearSampler filter: MinMagMipLinear addressmode: Clamp
*/
