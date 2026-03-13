// Production Ready Atmosphere Rendering technique, shader RenderSky
/*$(ShaderResources)*/

/*$(Embed:Common.hlsl)*/

static float3 CameraPos = /*$(Variable:CameraPos)*/;
static float4x4 InvViewProjMtx = /*$(Variable:InvViewProjMtx)*/;

static float3 SunColor = /*$(Variable:SunColor)*/;
static float2 SunDirection = /*$(Variable:SunDirection)*/;
static float SunDiskRadius = /*$(Variable:SunDiskRadius)*/;

// Get the sky view color from the sky view LUT.
float3 GetSkyViewColor(Texture2D<float4> lut, SamplerState lutSampler, float3 dir)
{
	float2 lutDims;
	lut.GetDimensions(lutDims.x, lutDims.y);

	// Taken from https://learnopengl.com/PBR/IBL/Diffuse-irradiance
	// and adjusted for gigi's coordinate system
	static const float2 invAtan2 = 1.0 / float2(TWO_PI, PI);
	float2 uv = float2(atan2(dir.x, dir.z), asin(dir.y));
	uv *= invAtan2;
	uv += float2(0.5, 0.5);
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
	ndc.y *= -1.0; // Flip because of DX12's texture convenetion :/

	// Get ray direction from ndc
	float4 screenPos = mul(float4(ndc, 1, 1), InvViewProjMtx);
	screenPos.xyz /= screenPos.w;

	// Get sky color from LUT
	float3 rayDir = normalize(screenPos.xyz - CameraPos);
	float3 skyColor = GetSkyViewColor(SkyViewLUT, LinearSampler, rayDir);

	// Composite sun disk on top of sky
	float3 sunDir = GetSunDirection(SunDirection);
	float diskRadius = SunDiskRadius * 1e-3; // Adjust disk radius to be even smaller, otherwise UI doesn't display right :/
	float3 sunDiskIntensity = smoothstep(1.0 - diskRadius, 1.0, dot(rayDir, sunDir));
	sunDiskIntensity = sunDir.y <= 0.0 ? float3(0, 0, 0) : sunDiskIntensity; // Handle case when sun is below horizon line
	skyColor += sunDiskIntensity * SunColor;

	// All done :)
	ColorTarget[pixel] = float4(skyColor, 1);
}

/*
Shader Resources:
	Texture SkyViewLUT (as SRV)
	Texture ColorTarget (as UAV)
	Sampler LinearSampler (as SamplerState)
*/
