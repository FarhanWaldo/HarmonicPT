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
		si.m_bsdf = cast(Bsdf*) emplace( memArena.Alloc!Bsdf(), si.m_normal, si.m_shading.n, si.m_shading.dpdu );

		Spectrum reflectance = m_albedo.Sample( si.m_uv, si.m_pos );
        // si.m_bsdf.AddBxDF( cast(BaseBxDF*) emplace!LambertBrdf( memArena.AllocClass!LambertBrdf(), reflectance ) );
		// const BaseBxDF* lambertLobe = [new LambertBrdf( reflectance )].ptr;
		const(BaseBxDF)* lambertLobe = [emplace!LambertBrdf( memArena.AllocClass!LambertBrdf(), reflectance )].ptr;
		si.m_bsdf.AddBxDF( lambertLobe );
	}
	
}
