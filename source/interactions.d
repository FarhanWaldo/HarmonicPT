import fwmath;
import bsdf;
import scene;
import material;
import spectrum;
import memory;
import light;

alias const(Interaction)         CInteraction;
alias const(SurfaceInteraction)  CSurfaceInteraction;

struct Interaction
{
    vec3    m_pos;
    vec3    m_normal;
    vec3    m_posError;
    vec3    m_wo;           /// Outgoing ray direction
    float   m_time;
    bool    m_isSurfaceInteraction = false;
	
	pure @nogc @safe nothrow
    this( in  vec3 pos, in  vec3 normal, float time )
    {
        m_pos       = pos;
        m_normal    = normal;
        m_time      = time;
    }

    pure const @nogc @safe nothrow
	Ray CreateRay( in ref vec3 dir )
    {
        Ray newRay = void;

        const bool enteringSurface = v_dot( dir, m_normal ) < 0.0f;
		const vec3 offsetP = (enteringSurface? -1.0f : 1.0f) * 10.0f*EPSILON*m_normal;
		
		newRay.m_origin = m_pos + offsetP;
        newRay.m_dir    = v_normalise( dir );
        newRay.m_maxT   = float.max;

        return newRay;
    }


    pure const @nogc @safe nothrow
	Ray CreateRayTo( in ref vec3 endPoint )
    {
        vec3 offsetPos = m_pos + 10.0f* EPSILON*m_normal;
        Ray newRay = CreateFiniteRaySegment( offsetPos, endPoint );
        newRay.m_maxT = newRay.m_maxT - 0.0001f; // TODO:: Find a way to deal with this robustly

        return newRay;
    }
}

/**
    Gives 
 */
struct SurfaceInteraction
{
    Interaction m_interaction;
	alias m_interaction this;
	
    struct Shading
    {
        vec3    n;    /// Shading normal. Can be different from m_normal (geometric normal) due to normal mapping, for example
        vec3    dpdu, dpdv;
        vec3    dndu, dndv;
    }

    vec2            m_uv;
    vec3            m_dpdu, m_dpdv;  /// Derivatives of position w.r.t. surface parameterisation ( R^2 => R^3 )
    vec3            m_dndu, m_dndv;  /// Derivatives of surface normal w.r.t. surface parameterisation ( R^2 => R^3 )

    Shading         m_shading; /// The shading coordinate system

    IMaterial*        m_material;
    CPrimCommon*      m_prim;
    Bsdf*             m_bsdf;

	pure @nogc @safe nothrow
    this( in  vec3 pos, in  vec2 uv, in  vec3 n,
          in  vec3 dpdu, in  vec3 dpdv,
          in  vec3 dndu, in  vec3 dndv,
          float time )
    {
	    m_isSurfaceInteraction = true;
		
        m_pos       = pos;
        m_normal    = n;
        m_time      = time;		

        m_uv = uv;
        m_shading = Shading( n, dpdu, dpdv, dndu, dndv );

        m_dpdu = dpdu;
        m_dpdv = dpdv;
        m_dndu = dndu;
        m_dndv = dndv;
    }
}

@safe
void ComputeScatteringFunctions(
	SurfaceInteraction* si,
	IMemAlloc*          memArena,
	bool                transportFromEyes,
	bool                allowMultipleLobes )
{
    if ( (si.m_prim != null) && (si.m_material != null) )
	{
	    si.m_material.ComputeScatteringFunctions( si, memArena, transportFromEyes, allowMultipleLobes );
	}
}
								

pure @safe @nogc nothrow
Spectrum GetAreaLightEmission( in SurfaceInteraction surfIntx, in ref vec3 wo )
{
    LightCommon* light = Prim_GetLight( surfIntx.m_prim );
    
    // return ( light != null ) ? CalculateEmission( light, surfIntx, wo ) : Spectrum(0.0f);
	if ( light != null )
	{
	    return CalculateEmission( light, surfIntx, wo );
	}

	return Spectrum( 0.0f );
}


// class MediumInteraction : Interaction
// {
    
// }

// C++ code
/*
vec3
OffsetRayOrigin(const vec3 &p, const vec3 &pError,
                               const vec3 &n, const vec3 &w) {
    float d = dot(abs(n), pError);
    vec3 offset = d * n;
    if (dot(w, n) < 0)
    {
        offset = -1.f*offset;
    }
    vec3 po = p + offset;
    // <<Round offset point po away from p>> 
       for (int i = 0; i < 3; ++i) {
           if (offset.v[i] > 0)      po.v[i] = NextFloatUp(po.v[i]);
           else if (offset.v[i] < 0) po.v[i] = NextFloatDown(po.v[i]);
       }

    return po;
}
*/
pure @nogc @safe nothrow
vec3 OffsetRayOrigin( in vec3 P, in vec3 pError, in vec3 N, in vec3 w )
{
	const float d = v_dot( N.abs(), pError );
	vec3 offset = d*N;
	if ( v_dot( w, N ) < 0.0f )
	{
	    offset *= -1.0f;
	}

    // FW_TODO:: Do that float thingy that's in the C++ code
	
	vec3 PO = P + offset;
	return PO;
}
