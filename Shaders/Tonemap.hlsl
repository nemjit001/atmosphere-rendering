// Production Ready Atmosphere Rendering technique, shader Tonemap
/*$(ShaderResources)*/

static const float Exposure = /*$(Variable:Exposure)*/;
static const float3 WhitePoint = float3(1, 1, 1);

// Convert a color to luminance values.
float luminance(float3 color)
{
	return dot(color, float3(0.2126, 0.7152, 0.0722));
}

// Perform Reinhard-Extended tonemapping.
float3 ReinhardTonemap(float3 color)
{
	float whitePointL = luminance(WhitePoint);
	float inL = luminance(color);
	float outL = (inL * (1.0 + (inL / (whitePointL * whitePointL)))) / (1.0 + inL);
	return color * (outL / inL);
}

/*$(_compute:main)*/(uint3 DTid : SV_DispatchThreadID)
{
	uint2 pixel = DTid.xy;
	float4 sourceColor = ColorTarget[pixel];

	float3 result = pow(ReinhardTonemap(sourceColor.xyz), 1.0 / Exposure);
	ColorTarget[pixel] = float4(result, sourceColor.a);
}

/*
Shader Resources:
	Texture ColorTarget (as UAV)
*/
