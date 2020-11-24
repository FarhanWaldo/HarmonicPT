import fwmath;
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

		// Spectrum reflectance = m_albedo.Sample( si );
        const vec4 r = m_albedo.Sample( si ); // F_TODO:: Create ISpectralTexture interface for this...
        const vec3 reflectance = vec3( r.x, r.y, r. z );
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

        /// F_TODO:: Create ISpectralTexture interface for this....
		// Spectrum reflectance = m_R.Sample( si );
        const vec4 r = m_R.Sample( si );
        const vec3 reflectance = vec3( r.x, r.y, r.z );
		Spectrum T = Spectrum( 1.0f );

		const (BaseBxDF)* fresnelSpecularLobe =
			memArena.AllocInstance!FresnelSpecularBxDF( reflectance, T, m_etaI, m_etaT );

		si.m_bsdf.AddBxDF( fresnelSpecularLobe );
	}	
}


class PlasticMaterial : IMaterial
{
	ITexture* m_albedo;
    ITexture* m_spec;
    ITexture* m_roughness;
    bool      m_remapRoughness;
    
    pure @safe @nogc nothrow
    this( ITexture* albedo, ITexture* specColour, ITexture* roughness, bool remapRoughness )
    {
        m_albedo = albedo;
        m_spec   = specColour;
        m_roughness = roughness;
        m_remapRoughness = remapRoughness;
    }
    
	override @trusted
	void ComputeScatteringFunctions( SurfaceInteraction* si,
									 IMemAlloc*          memArena,
									 bool                transportFromEye,
									 bool                allowMultipleLobes )
	{
        import microfacet;
    
        si.m_bsdf  = memArena.AllocInstance!Bsdf( si.m_normal, si.m_shading.n, si.m_shading.dpdu );

        const vec4 albedo = m_albedo.Sample( si );
        const vec3 reflectance = vec3( albedo.r, albedo.g, albedo.b );

        if (!IsBlack(reflectance))
        {
            const (BaseBxDF)* lambertLobe = memArena.AllocInstance!LambertBRDF( reflectance );
            si.m_bsdf.AddBxDF( lambertLobe );
        }

        const vec4 specColour = m_spec.Sample( si );
        const vec3 ks = vec3( specColour.x, specColour.y, specColour.z );
        if (!IsBlack( ks ))
        {
            IFresnel* fresnel = cast(IFresnel*)  memArena.AllocInstance!FresnelDielectric( 1.5f, 1.0f );
            
            const vec4 r = m_roughness.Sample( si ); // should either have one or two components
            float roughness = r.x;

            if (m_remapRoughness)
                roughness = Beckmann_RoughnessToAlpha( roughness );

            auto microfacetDist = cast(BaseMicrofacetDistribution*) memArena.AllocInstance!BeckmannDistribution( roughness /*, true sample VNDF */ );
            const (BaseBxDF)* specLobe = memArena.AllocInstance!MicrofacetReflection( ks, fresnel, microfacetDist );

            si.m_bsdf.AddBxDF( specLobe );
        }
        
        // si.m_bsdf = memArena.AllocInstance!Bsdf( si.m_normal, si.m_shading.n, si.m_shading.dpdu );

        // /// F_TODO:: Create ISpectralTexture interface for this....
		// // Spectrum reflectance = m_R.Sample( si );
        // const vec4 r = m_R.Sample( si );
        // const vec3 reflectance = vec3( r.x, r.y, r.z );
		// Spectrum T = Spectrum( 1.0f );

		// const (BaseBxDF)* fresnelSpecularLobe =
		// 	memArena.AllocInstance!FresnelSpecularBxDF( reflectance, T, m_etaI, m_etaT );

		// si.m_bsdf.AddBxDF( fresnelSpecularLobe );
	}	

}
