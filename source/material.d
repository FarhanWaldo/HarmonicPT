import memory;
import interactions;
import bsdf;
import bxdf;
import texture;
import spectrum;

import std.conv : emplace;

interface IMaterial
{
	@safe @nogc nothrow
	void ComputeScatteringFunctions( SurfaceInteraction* si,
									 IMemAlloc*          memArena,
									 bool                transportFromEye,
									 bool                allowMultipleLobes );
}

class MatteMaterial : IMaterial
{
    ITexture* m_albedo;

	this( ITexture* albedo )
	{
		m_albedo = albedo;
	}

	override @trusted @nogc nothrow
	void ComputeScatteringFunctions( SurfaceInteraction* si,
									 IMemAlloc*          memArena,
									 bool                transportFromEye,
									 bool                allowMultipleLobes )
	{
		si.m_bsdf = cast(Bsdf*) emplace( memArena.Alloc!Bsdf(), si.m_normal, si.m_shading.n, si.m_shading.dpdu );

		Spectrum reflectance = m_albedo.Sample( si.m_uv, si.m_pos );

		// F_TODO:: Add lambert brdf
	}
	
}
