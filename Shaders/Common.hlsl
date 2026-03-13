#ifndef COMMON_HLSL
#define COMMON_HLSL

#define PI      3.14159265
#define TWO_PI  6.28318531

// Clamped acos function to ensure that invalid values get clamped
float safeacos(float x)
{
	return acos(clamp(x, -1, 1));
}

// Intersect a planet centered around (0, 0, 0) with a given radius.
float IntersectPlanet(float3 origin, float3 dir, float radius)
{
	float3 co = origin;
	float a = dot(dir, dir);
	float halfB = dot(co, dir);
	float c = dot(co, co) - (radius * radius);

	float discriminant = (halfB * halfB) - (a * c);
	if (discriminant < 0.0) {
		return -1.0;
	}

	float depth = (-halfB - sqrt(discriminant)) / a;
	if (depth >= 0.0) {
		return depth;
	}

	depth = (-halfB + sqrt(discriminant)) / a;
	if (depth >= 0.0) {
		return depth;
	}

	return -1.0;
}

// Convert spherical coordinates to a direction vector using Y-up.
float3 SphericalToCarthesian(float phi, float theta)
{
	return float3(
		sin(theta) * sin(phi),
		cos(theta),
		sin(theta) * cos(phi)
	);
}

// Get the carthesian direction vector towards the sun based on the azimuth/altitude representation used to store direction.
float3 GetSunDirection(float2 azimuthAltitude)
{
	float sunPhi = azimuthAltitude.x * PI; // ranged in [-pi, pi]
	float sunTheta = safeacos(azimuthAltitude.y);
	return SphericalToCarthesian(sunPhi, sunTheta);
}

// Get the extinction coefficient for a certain height.
// This will also output the adjusted scattering and absorption coefficients.
float3 GetScatteringCoefficients(
	float h,
	inout float3 mieScattering,
	inout float3 mieAbsorption,
	inout float3 rayleighScattering,
	inout float3 rayleighAbsorption,
	inout float3 ozoneAbsorption
)
{
	h = h * 1000.0; // Convert megameters to kilometers

	// Calculate atmospheric density of atmospheric layers
	// TODO(nemjit001): might want to expose these height profiles as params
	float mieDensity = exp(-h / 1.2);
	float rayleighDensity = exp(-h / 8.0);
	float ozoneDensity = max(0, 1.0 - (abs(h - 25.0) / 15.0));

	// Apply density to scattering & absorption coefficients
	mieScattering = mieDensity * mieScattering;
	mieAbsorption = mieDensity * mieAbsorption;
	rayleighScattering = rayleighDensity * rayleighScattering;
	rayleighAbsorption = rayleighDensity * rayleighAbsorption;
	ozoneAbsorption = ozoneDensity * ozoneAbsorption;

	// Calculate extinction coefficient
	return mieScattering + mieAbsorption + rayleighScattering + rayleighAbsorption + ozoneAbsorption;
}

// Henyey-Greenstein phase function parameterized by `g`.
float HenyeyGreensteinPhase(float cosTheta, float g)
{
	float g2 = g * g;
	float denom = (1.0 + g2 - (2.0 * g) * cosTheta);
	return (1.0 / (4.0 * PI)) * ((1 - g2) / pow(denom, 1.5));
}

// Mie scattering phase function (HG phase with g=0.8).
float MiePhase(float cosTheta)
{
	return HenyeyGreensteinPhase(cosTheta, 0.8);
}

// Rayleigh scattering phase function.
float RayleighPhase(float cosTheta)
{
	return (3.0 * (1.0 + (cosTheta * cosTheta))) / (16.0 * PI);
}

// Isotropic scattering phase function.
float IsotropicPhase(float cosTheta)
{
	return 1.0 / (4.0 * PI);
}

// Get the atmospheric transmittance from a LUT.
// This function works for both the transmittance LUT and multiple scattering LUT. (both LUTs use same parameterization)
float3 GetAtmosphericTransmittance(Texture2D<float4> lut, SamplerState lutSampler, float h, float3 pos, float3 dir)
{
	float2 lutDims;
	lut.GetDimensions(lutDims.x, lutDims.y);

	float3 up = normalize(pos); // Local up vector as normalized direction from planet center
	float cosTheta = clamp(dot(up, dir), -1, 1);
	float u = 0.5 + 0.5 * cosTheta;
	float v = clamp(h, 0, 1);
	return lut.SampleLevel(lutSampler, float2(u, v), 0).xyz;
}

#endif //COMMON_HLSL
