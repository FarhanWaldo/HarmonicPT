import std.math : sin, cos, sqrt;
import fwmath;


pure vec2
ConcentricSampleDisk( in ref vec2 P )
{
    vec2 newSample;

    vec2 uOffset = 2.0f*P - vec2( 1.0f );
    if ( uOffset.x == 0.0f && uOffset.y == 0.0f ) return newSample;

    float theta, r;
    if ( Abs( uOffset.x ) > Abs( uOffset.y ) )
    {
        r = uOffset.x;
        theta = PI_OVER_4 * ( uOffset.y / uOffset.x );
    }
    else
    {
        r = uOffset.y;
        theta = PI_OVER_4 * ( uOffset.x / uOffset.y );
    }

    newSample = r * vec2( cos( theta ), sin( theta ) );
    return newSample;
}

pure vec3
UniformSampleHemisphere( in ref vec2 u )
{
    vec3 sample;
    float z = u.x;
    float r = sqrt( Max( 0.0f, 1.0f - z*z ) );
    float phi = 2.0f * PI * u.y;
    sample = vec3( r * cos( phi ), r * sin( phi ), z );
    return sample;
}

pure vec3
CosineSampleHemisphere( in ref vec2 u )
{
    vec2 p  = ConcentricSampleDisk( u );
    float z = sqrt( Max( 0.0f, 1.0f - v_dot( p, p ) ) );
    return vec3( p.x, p.y, z );
}

pure vec3
UniformSampleSphere( in ref vec2 u )
{
    float z     = 1.0f - 2.0f*u.y;
    float r     = sqrt( Max( 0.0f, 1.0f - z*z ) );
    float phi   = TAU*u.x;

    return vec3( r * cos( phi ), r * sin( phi ), z );
}

pure vec3
UniformSampleCone( in ref vec2 u, float cosThetaMax )
{
    float cosTheta =  ( 1.0f - u.x ) + ( u.x * cosThetaMax );
    float sinTheta = sqrt( 1.0f - cosTheta*cosTheta );
    float phi = u.y * 2.0f * PI;

    return vec3( cos( phi ) * sinTheta, sin( phi ) * sinTheta, cosTheta );
}


pure float
UniformHemispherePDF()
{
    return INV_TAU;
}

pure float
UniformSpherePDF()
{
    return 0.25f * INV_PI;
}

pure float
UniformConePdf( float cosThetaMax )
{
    return 1.0f / ( 2.0f * PI * ( 1.0f - cosThetaMax ) );
}