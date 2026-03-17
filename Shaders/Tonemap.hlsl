// Production Ready Atmosphere Rendering technique, shader Tonemap
/*$(ShaderResources)*/

static const float Gamma = /*$(Variable:Gamma)*/;

// Convert a color to luminance values.
float luminance(float3 color)
{
	return dot(color, float3(0.2126, 0.7152, 0.0722));
}

// Approximated ACES filmic tonemapping approximation taken from
// https://64.github.io/tonemapping/#aces
// referencing
// https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
float3 ACESTonemap(float3 color)
{
	color *= 0.6;
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((color * (a * color + b)) / (color * (c * color + d) + e), 0, 1);
}

/*$(_compute:main)*/(uint3 DTid : SV_DispatchThreadID)
{
	uint2 pixel = DTid.xy;
	float4 sourceColor = Input[pixel];

	float3 result = pow(ACESTonemap(sourceColor.xyz), 1.0 / Gamma);
	Output[pixel] = float4(result, sourceColor.a);
}

/*
Shader Resources:
	Texture Input (as SRV)
	Texture Output (as UAV)
*/
