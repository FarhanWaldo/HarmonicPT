import fwmath;
import bxdf;
import spectrum;
import datastructures;

struct Bsdf
{
    vec3  m_geoNormal;

	//  Can be used to transform in/out of the shading coordinate system
	//  { m_shadingNormal, m_shadingS, m_shadingT } form an orthonormal basis on the surface of the shading point
	//
	vec3  m_shadingNormal;
	vec3  m_shadingS;
	vec3  m_shadingT;

	enum MaxLobes = 8;
	alias BufferT!( BaseBxDF*, MaxLobes)  BxDFStack;
    BxDFStack m_bxdfs;
	
	float         m_eta; // Relative index of refraction

	pure @safe @nogc nothrow
	this( in vec3 geoNormal, in vec3 shadingNormal, in vec3 dpdu, float eta = 1.0f )
	{
	    m_geoNormal     = geoNormal;
		m_shadingNormal = shadingNormal;
		m_shadingS      = v_normalise( dpdu );
		m_shadingT      = v_normalise( v_cross( shadingNormal, dpdu ) );
		m_eta           = eta;
	}

	pure @safe @nogc nothrow
	void AddBxDF( BaseBxDF* bxdf ) {
		m_bxdfs.Push( bxdf );
	}

	pure const @safe @nogc nothrow
	uint NumComponents( BxDFType flags = BxDFType.All )
	{
	    uint numMatching = 0;
		foreach( bxdf; m_bxdfs.range() ) {
			if ( bxdf.MatchesType( flags ) ) {
				++numMatching;
			}
		}
		return numMatching;
	}

	/**
        Pushes the filtered lobes onto an externally provided BxDFStack

        Returns the number of BxDFs that match the flags 
	 */
	pure @safe @nogc nothrow
	uint Filter( ref BxDFStack filteredLobes, BxDFType flags ) {
		uint numMatching = 0;
		
        filteredLobes.Reset();
        foreach( bxdf; m_bxdfs.range() ) {
			if ( bxdf.MatchesType(flags) ) {
				++numMatching;
				filteredLobes.Push( bxdf );
			}
		}
		
		return numMatching;
	}

	pure const @safe @nogc nothrow
	vec3 WorldToLocal( in vec3 w )
	{
	    return vec3(
		    v_dot( w, m_shadingS ),
			v_dot( w, m_shadingT ),
			v_dot( w, m_shadingNormal ) );
	}

	pure const @safe @nogc nothrow
	vec3 LocalToWorld( in vec3 w )
	{
	    return vec3(
		    m_shadingS.x*w.x + m_shadingT.x*w.y + m_shadingNormal.x*w.z,
		    m_shadingS.y*w.x + m_shadingT.y*w.y + m_shadingNormal.y*w.z,
		    m_shadingS.z*w.x + m_shadingT.z*w.y + m_shadingNormal.z*w.z,
		);
	}

	pure @trusted @nogc nothrow
	Spectrum Sample_F( in vec3   world_wo,
					   ref vec3  o_world_wi,
					   in vec2   u,
					   ref float o_pdf,
					   BxDFType  flags,
					   BxDFType* o_sampledTypes = null )
	{
		Spectrum F;

		/// Filter down the BxDF stack to just the matching ones
		///
        BxDFStack  filteredLobes;
		const uint numMatchingLobes = Filter( filteredLobes, flags );
		if ( numMatchingLobes == 0 )
		{
            o_pdf = 0.0f;
			if ( o_sampledTypes )
			{
			    *o_sampledTypes = BxDFType.None;
				
			}
		
		    return F;
		}

		///  'u' is a uniform random 2D number supplied to this sampling function
		///  We'll use one of the two random numbers to pick one of the filtered lobes with equal probability
		///
	    const uint selectedLobeIndex = Min( numMatchingLobes - 1, cast(uint) u.x*numMatchingLobes );
		BaseBxDF* selectedLobe       = filteredLobes[ selectedLobeIndex ];

		///  Since we used u.x to select the lobe, we need to remap the u.x value to [0, 1) in order to use it
		///    for BxDF sampling (we need a uniform random number [0,1)x[0,1) )
		///
		///  u.x is currently in the interval [ lobeIndex/lobeCount, (lobeIndex+1)/lobeCount )
		///
		const float fLobeIndex = cast(float) selectedLobeIndex;
		const float fLobeCount = cast(float) numMatchingLobes;
        const vec2 uRemap = vec2( Min( 0.999999, u.x*fLobeCount - fLobeIndex ), u.y );
		
        const vec3 wo = WorldToLocal( world_wo );
        vec3       wi;

		if ( wo.z == 0.0f ) { return F; }

		o_pdf = 0.0f;
		if (o_sampledTypes) { *o_sampledTypes = selectedLobe.GetType(); }
		F = selectedLobe.Sample_F( wo, uRemap, wi, &o_pdf, o_sampledTypes );

		if ( o_pdf == 0.0f )
		{
		    if ( o_sampledTypes ) { *o_sampledTypes = BxDFType.None; }
			return F;
		}

		o_world_wi = LocalToWorld( wi );
		const float invLobeCount = 1.0f/fLobeCount; /// also the probability of selecting a lobe

		const bool isNotSpecularLobe = (selectedLobe.GetType() & BxDFType.Specular) == 0;
		if (isNotSpecularLobe && (numMatchingLobes > 1))
		{
		    float sumPdf = 0.0f;
			foreach( lobe; filteredLobes.range() )
			{
			    sumPdf += lobe.Pdf( wo, wi );
			}

			o_pdf = sumPdf;
		}
		if (numMatchingLobes > 1) { o_pdf *= invLobeCount; }

        if (isNotSpecularLobe)
		{
		    const bool isReflection = (v_dot(o_world_wi, m_geoNormal) * v_dot( world_wo, m_geoNormal)) > 0.0f;

			Spectrum sumF;
			foreach( lobe; filteredLobes ) {
			    const BxDFType lobeType = lobe.GetType();
				if ( (isReflection  && (lobeType & BxDFType.Reflection   )) ||
				     (!isReflection && (lobeType & BxDFType.Transmission )) )
			    {
					 sumF += lobe.F( wo, wi );
				}
			}
			F = sumF;
		}
		
		return F;
	}

	pure const @safe @nogc nothrow
	float Pdf( in vec3 world_wo, in vec3 world_wi, BxDFType flags )
	{
		return 0.0f;
	}
					   
}
