// Production Ready Atmosphere Rendering technique, shader MultiscatterLUT
/*$(ShaderResources)*/

/*$(_compute:main)*/(uint3 DTid : SV_DispatchThreadID)
{
	float2 lutSize;
	MultiscatterLUT.GetDimensions(lutSize.x, lutSize.y);

	uint2 pixel = DTid.xy;
	float2 pixelCenter = pixel + float2(0.5, 0.5);
	float2 uv = pixelCenter / lutSize;

	MultiscatterLUT[pixel] = float4(uv, 0, 1);
}

/*
Shader Resources:
	Texture TransmittanceLUT (as SRV)
	Texture MultiscatterLUT (as UAV)
	Sampler LinearSampler (as SamplerState)
*/
