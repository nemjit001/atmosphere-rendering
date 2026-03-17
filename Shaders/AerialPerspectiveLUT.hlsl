// Production Ready Atmosphere Rendering technique, shader AerialPerspectiveLUT
/*$(ShaderResources)*/

/*$(_compute:main)*/(uint3 DTid : SV_DispatchThreadID)
{
}

/*
Shader Resources:
	Texture TransmittanceLUT (as SRV)
	Texture MultiscatterLUT (as SRV)
	Texture AerialPerspectiveLUT (as UAV)
Shader Samplers:
	LinearSampler filter: MinMagMipLinear addressmode: Clamp
*/
