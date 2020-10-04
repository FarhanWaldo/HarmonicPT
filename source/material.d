import memory;
import interactions;
import bsdf;
import bxdf;
import texture;
import spectrum;

import std.conv : emplace;

interface IMaterial
{
	@trusted
	void ComputeScatteringFunctions( SurfaceInteraction* si,
									 IMemAlloc*          memArena,
									 bool                transportFromEye,
									 bool                allowMultipleLobes );
}

class MatteMaterial : IMaterial
{
    ITexture* m_albedo;

	pure @safe @nogc nothrow
	this( ITexture* albedo )
	{
		m_albedo = albedo;
	}

	override @trusted
	void ComputeScatteringFunctions( SurfaceInteraction* si,
									 IMemAlloc*          memArena,
									 bool                transportFromEye,
									 bool                allowMultipleLobes )
	{
		si.m_bsdf = memArena.AllocInstance!Bsdf( si.m_normal, si.m_shading.n, si.m_shading.dpdu );

		Spectrum reflectance = m_albedo.Sample( si );
		const (BaseBxDF)* lambertLobe = memArena.AllocInstance!LambertBRDF( reflectance );
		si.m_bsdf.AddBxDF( lambertLobe );
	}
	
}

class FresnelSpecMaterial : IMaterial
{
	ITexture* m_R;     /// reflectance
    float     m_etaI;  /// IOR of incident medium
	float     m_etaT;  /// IOR of transmitted medium

	pure @safe @nogc nothrow
	this( ITexture* albedo, float etaIncident, float etaTransmitted )
	{
		m_R    = albedo;
		m_etaI = etaIncident;
		m_etaT = etaTransmitted;
	}

	override @trusted
	void ComputeScatteringFunctions( SurfaceInteraction* si,
									 IMemAlloc*          memArena,
									 bool                transportFromEye,
									 bool                allowMultipleLobes )
	{
		si.m_bsdf = memArena.AllocInstance!Bsdf( si.m_normal, si.m_shading.n, si.m_shading.dpdu );

		Spectrum reflectance = m_R.Sample( si );
		Spectrum T = Spectrum( 1.0f );

		const (BaseBxDF)* fresnelSpecularLobe =
			memArena.AllocInstance!FresnelSpecularBxDF( reflectance, T, m_etaI, m_etaT );

		si.m_bsdf.AddBxDF( fresnelSpecularLobe );
	}	
}

// class UberMaterial : IMaterial
// {
// 	ITexture* m_albedo; 
// }
