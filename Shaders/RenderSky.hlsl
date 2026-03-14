// Production Ready Atmosphere Rendering technique, shader RenderSky
/*$(ShaderResources)*/

/*$(Embed:Common.hlsl)*/

static float3 CameraPos = /*$(Variable:CameraPos)*/;
static float4x4 InvViewProjMtx = /*$(Variable:InvViewProjMtx)*/;

static float2 SunDirection = /*$(Variable:SunDirection)*/;
static float3 SunColor = /*$(Variable:SunColor)*/;
static float SunIntensity = /*$(Variable:SunIntensity)*/;
static float SunDiskRadius = /*$(Variable:SunDiskRadius)*/;

static float2 PlanetRadius = /*$(Variable:PlanetRadius)*/;

// Get the sky view luminance from the sky view LUT.
float3 GetSkyViewLuminance(Texture2D<float4> lut, SamplerState lutSampler, float3 dir)
{
	float2 lutDims;
	lut.GetDimensions(lutDims.x, lutDims.y);

	// Calculate uv coords
	float theta = safeacos(-dir.y) - (0.5 * PI);
	float u = 0.5 + (atan2(dir.x, dir.z) / TWO_PI);
	float v = 0.5 + 0.5 * sign(theta) * sqrt(abs(theta) / (0.5 * PI));

	float2 uv = float2(u, v);
	return lut.SampleLevel(lutSampler, uv, 0).xyz;
}

/*$(_compute:main)*/(uint3 DTid : SV_DispatchThreadID)
{
	float2 lutSize;
	ColorTarget.GetDimensions(lutSize.x, lutSize.y);

	uint2 pixel = DTid.xy;
	float2 pixelCenter = pixel + float2(0.5, 0.5);
	float2 uv = pixelCenter / lutSize;
	float2 ndc = 2.0 * uv - 1.0;
	ndc.y *= -1.0; // Flip because of DX12's texture convenetion

	// Get ray direction from ndc
	float4 screenPos = mul(float4(ndc, 1, 1), InvViewProjMtx);
	screenPos.xyz /= screenPos.w;

	// Get sky color from LUT
	float3 viewDir = normalize(screenPos.xyz - CameraPos);
	float3 skyLuminance = GetSkyViewLuminance(SkyViewLUT, LinearSampler, viewDir);

	// Get sun disk parameters & calculate sun luminance
	float3 sunDir = GetSunDirection(SunDirection);
	float diskRadius = SunDiskRadius * 1e-3; // Adjust disk radius to be even smaller, otherwise UI doesn't display right :/
	float3 sunDiskIntensity = smoothstep(1.0 - diskRadius, 1.0, dot(viewDir, sunDir));
	sunDiskIntensity = sunDir.y <= 0.0 ? float3(0, 0, 0) : sunDiskIntensity; // Handle case when sun is below horizon line

	float3 viewPos = float3(0, PlanetRadius.x, 0) + CameraPos * 1e-6; // Adds camera position in mega meters to planet surface height
	float relSurfaceHeight = (length(viewPos) - PlanetRadius.x) / (PlanetRadius.y - PlanetRadius.x);
	float3 sunTransmittance = GetAtmosphericTransmittance(TransmittanceLUT, LinearSampler, relSurfaceHeight, viewPos, sunDir);
	float3 sunLuminance = sunDiskIntensity * SunColor * SunIntensity * sunTransmittance;

	// All done :)
	float3 luminance = skyLuminance + sunLuminance;
	ColorTarget[pixel] = float4(luminance, 1);
}

/*
Shader Resources:
	Texture TransmittanceLUT (as SRV)
	Texture SkyViewLUT (as SRV)
	Texture ColorTarget (as UAV)
	Sampler LinearSampler (as SamplerState)
*/
