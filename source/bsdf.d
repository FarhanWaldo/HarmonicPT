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
	alias BufferT!( const(BaseBxDF)*, MaxLobes)  BxDFStack;
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
	void AddBxDF( const(BaseBxDF)* bxdf ) {
		m_bxdfs.Push( bxdf );
	}

	pure const @safe @nogc nothrow
	uint NumComponents( BxDFTypeFlags flags = BxDFTypeFlags_All )
	{
	    uint numMatching = 0;
		foreach( bxdf; m_bxdfs.range() ) {
			if ( bxdf.MatchesType( flags ) ) {
				++numMatching;
			}
		}
		return numMatching;
	}

    pure const @trusted @nogc nothrow
	void Filter( ref BxDFStack filteredLobes, BxDFTypeFlags flags )
	{
		foreach( bxdf; m_bxdfs.range() ) {
			// if( bxdf.MatchesType( flags ) ) {
				filteredLobes.Push( bxdf );
			// }
		}
	}
	
	/**
        Returns a new BxDFStack with only the lobes that match against flags
	 */
	pure const @trusted @nogc nothrow
	BxDFStack FilterLobes( BxDFTypeFlags flags ) {
		BxDFStack filteredLobes;
		const ulong numLobes = m_bxdfs.GetCount();
        foreach( bxdf; m_bxdfs[0..numLobes] ) {
			// if ( bxdf.MatchesType(flags) ) {
				filteredLobes.Push( bxdf );
			// }
		}
		return filteredLobes;
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

    pure const @safe @nogc nothrow
	Spectrum F( in vec3 world_wo, in vec3 world_wi, BxDFTypeFlags flags )
	{
	    const vec3 wo = v_normalise( WorldToLocal( world_wo ) );
		const vec3 wi = v_normalise( WorldToLocal( world_wi ) );

		const bool isReflection = (v_dot(world_wo, m_geoNormal) * v_dot(world_wi,m_geoNormal)) > 0.0f;

		Spectrum sumF = Spectrum(0.0f);
		
		const BxDFStack lobes = FilterLobes( flags );
		const ulong lobeCount = lobes.GetCount();
		foreach( lobe; lobes[0..lobeCount] ) {

			const BxDFTypeFlags lobeTypeFlags = lobe.GetType();
			if ( (isReflection  && (lobeTypeFlags & BxDFType.Reflection   )) ||
				 (!isReflection && (lobeTypeFlags & BxDFType.Transmission )) )
			{
				 sumF += lobe.F( wo, wi );
			}
		}
		
		return sumF;
	}
	
	pure const @trusted @nogc nothrow
	Spectrum Sample_F( in vec3   world_wo,
					   ref vec3  o_world_wi,
					   in vec2   u,
					   ref float o_pdf,
					   BxDFTypeFlags  flags,
					   BxDFTypeFlags* o_sampledTypes = null )
	{
		Spectrum F = Spectrum(0.0f);

		/// Filter down the BxDF stack to just the matching ones
		///
		BxDFStack filteredLobes = FilterLobes( flags );
		const uint numMatchingLobes = cast(uint) filteredLobes.GetCount();
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
	    const uint selectedLobeIndex  = Min( numMatchingLobes - 1, cast(uint) u.x*numMatchingLobes );
		const(BaseBxDF)* selectedLobe = filteredLobes[ selectedLobeIndex ];

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

		///  Sample the randomly selected lobe
		///
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

		///  Average the PDF of all matching lobes
		///
		const bool isNotSpecularLobe = !selectedLobe.IsSpecular();
		if (isNotSpecularLobe && (numMatchingLobes > 1))
		{
		    float sumPdf = 0.0f;
			foreach( lobe; filteredLobes[0..numMatchingLobes] )
			{
			    sumPdf += lobe.Pdf( wo, wi );
			}

			o_pdf = sumPdf;
		}
		if (numMatchingLobes > 1) { o_pdf *= invLobeCount; }

        if (isNotSpecularLobe)
		{
		    const bool isReflection = (v_dot(o_world_wi, m_geoNormal) * v_dot( world_wo, m_geoNormal)) > 0.0f;

			Spectrum sumF = Spectrum(0.0f);
			foreach( lobe; filteredLobes[0..numMatchingLobes] )
			{
			    const BxDFTypeFlags lobeType = lobe.GetType();
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

	pure const @trusted @nogc nothrow
	float Pdf( in vec3 world_wo, in vec3 world_wi, BxDFTypeFlags flags )
	{
        if ( m_bxdfs.Empty() ) { return 0.0f; }

		// Convert directions from worldspace to the reflection coordinate system
		//
		const vec3 wo = WorldToLocal( world_wo );
		const vec3 wi = WorldToLocal( world_wi );

        if ( wo.z == 0.0f ) { return 0.0f; }

		BxDFStack lobes = FilterLobes( flags );
		const uint matchingLobes = cast(uint) lobes.GetCount();
        float pdf = 0.0f;
		foreach ( lobe; lobes[0..matchingLobes] ) {
		    pdf += lobe.Pdf( wo, wi );
		}

		if ( matchingLobes > 1 ) { pdf /= ( cast(float) matchingLobes ); }
		
		return pdf;
	}
					   
}
