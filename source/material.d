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
		const (BaseBxDF)* lambertLobe = memArena.AllocInstance!LambertBrdf( reflectance );
		si.m_bsdf.AddBxDF( lambertLobe );
	}
	
}
