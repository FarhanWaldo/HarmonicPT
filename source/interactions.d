import fwmath;
import bsdf;
import scene;
import material;

class Interaction
{
    vec3    m_pos;
    vec3    m_normal;
    vec3    m_posError;
    float   m_time;
    vec3    m_wo;           /// Outgoing ray direction

    this( in ref vec3 pos, in ref vec3 normal, float time )
    {
        m_pos       = pos;
        m_normal    = normal;
        m_time      = time;
    }

    const Ray CreateRay( in ref vec3 dir )
    {
        Ray newRay = void;

        newRay.m_origin = m_pos * 10.0f*EPSILON*m_normal; // TODO:: Do better than arbitrary multiplying by 10*EPSILON
        newRay.m_dir    = v_normalise( dir );
        newRay.m_maxT   = float.max;

        return newRay;
    }


    const Ray CreateRayTo( in ref vec3 endPoint )
    {
        vec3 offsetPos = m_pos + EPSILON*m_normal;
        Ray newRay = CreateFiniteRaySegment( offsetPos, endPoint );
        newRay.m_maxT = newRay.m_maxT - 0.0001f; // TODO:: Find a way to deal with this robustly

        return newRay;
    }
}

class SurfaceInteraction : Interaction
{
    struct Shading
    {
        vec3    n;
        vec3    dpdu, dpdv;
        vec3    dndu, dndv;
    }

    vec2            m_uv;
    vec3            m_dpdu, m_dpdv;
    vec3            m_dndu, m_dndv;

    Shading         m_shading; // The shading coordinate system

    IMaterial*      m_material;
    IPrimitive*     m_prim;
    Bsdf*           m_bsdf;

    this( in ref vec3 pos, in ref vec2 uv, in ref vec3 n,
          in ref vec3 dpdu, in ref vec3 dpdv,
          in ref vec3 dndu, in ref vec3 dndv,
          float time )
    {
        super( pos, n, time );

        m_uv = uv;
        m_shading = Shading( n, dpdu, dpdv, dndu, dndv );

        m_dpdu = dpdu;
        m_dpdv = dpdv;
        m_dndu = dndu;
        m_dndv = dndv;
    }
}

pure vec3
GetAreaLightEmission( SurfaceInteraction surfIntx, in ref vec3 wo )
{
    // TODO:: Implement IAreaLight::L ()
    return vec3();
}


// class MediumInteraction : Interaction
// {
    
// }