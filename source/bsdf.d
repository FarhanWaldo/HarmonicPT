import fwmath;
import bxdf;
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
}
