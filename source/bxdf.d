import std.math : sqrt;

import fwmath;
import spectrum;
import sampling;

enum BxDFType
{
    None             = 0,
    Reflection       = 1 << 0,
	Transmission     = 1 << 1,
	Diffuse          = 1 << 2,
	Glossy           = 1 << 3,
	Specular         = 1 << 4,

	All              = Reflection |
	                   Transmission |
					   Diffuse |
					   Glossy |
					   Specular,

    AllNonSpecular   = All & ~Specular
}

/**
//
//  Utility Methods
//

//  All vectors are in the reflection coordinate system
//  The Normal vector for the surface is the z-axis [0, 0, 1]
//  The X and Y axes are the tangent, and bitangent respectively
//
//  The parameterisation from Cartesian -> Spherical coordinate system
//  
//      x = r * sin( theta ) * cos( phi )
//      y = r * sin( theta ) * sin( phi )
//      z = r * cos( theta )
//
//      Where:
//          r       = radius of Sphere (radius = 1, in the reflection coordinate system)
//          theta   = angle between the Z and X axes [ 0, Pi ]
//          phi     = angle between the X and Y axes [ 0, 2*Pi )
//
//
*/

pure @safe @nogc nothrow float CosTheta( in vec3 w )        { return w.z; }
pure @safe @nogc nothrow float Cos2Theta( in vec3 w )       { return w.z * w.z; }
pure @safe @nogc nothrow float AbsCosTheta( in vec3 w )     { return Abs( w.z ); }

pure @safe @nogc nothrow float Sin2Theta( in vec3 w )       { return Max( 0.0, 1.0 - Cos2Theta( w ) ); }
pure @safe @nogc nothrow float SinTheta( in vec3 w )        { return sqrt( Sin2Theta( w ) ); }
pure @safe @nogc nothrow float TanTheta( in vec3 w )        { return SinTheta( w ) / CosTheta( w ); }
pure @safe @nogc nothrow float Tan2Theta( in vec3 w )       { return Sin2Theta( w ) / Cos2Theta( w ); }

pure @safe @nogc nothrow
float CosPhi( in vec3 w ) {
    float sinTheta = SinTheta( w );
	return ( sinTheta == 0.0f ) ? 1.0f : Clamp( w.x / sinTheta, -1.0f, 1.0f );
}

pure @safe @nogc nothrow
float SinPhi( in vec3 w ) {
    float sinTheta = SinTheta( w );
	return ( sinTheta == 0.0f ) ? 0.0f : Clamp( w.y / sinTheta, -1.0f, 1.0f );
}

pure @safe @nogc nothrow
float Cos2Phi( in vec3 w ) {
    float cosPhi = CosPhi( w );
	return cosPhi * cosPhi;
}

pure @safe @nogc nothrow
float Sin2Phi( in vec3 w ) {
    float sinPhi = SinPhi( w );
	return sinPhi*sinPhi;
}


pure @safe @nogc nothrow
float CosDPhi( in vec3 wa, in vec3 wb ) {
    return Clamp( (wa.x*wb.x + wa.y*wb.y) / sqrt( wa.x*wa.x + wa.y*wa.y ) * ( wb.x*wb.x + wb.y*wb.y ),
	               -1.0f, 1.0f );
}

pure @safe @nogc nothrow
vec3 Reflect( in vec3 wo, in vec3 n ) {
    return -1.0f*wo + 2.0f*v_dot( wo, n )*n;
}

pure @safe @nogc nothrow
bool Refract( in vec3 wi, in vec3 n, float eta, ref vec3 o_wt )
{
    float cosThetaI = v_dot( n, wi );
	float sin2ThetaI = Max( 0.0f, 1.0f - cosThetaI * cosThetaI );
	float sin2ThetaT = eta*eta * sin2ThetaI;

	//  Total internal reflection has occured!
	//
	if ( sin2ThetaT >= 1.0f ) { return false; }

	// F_TODO:: double check math for refracted direction...
	//
	float cosThetaT = sqrt( Max( 0.0f, 1.0f - sin2ThetaT ) );
	o_wt = v_normalise( -eta*wi + ( eta*cosThetaI - cosThetaT)*n );

	return true;
}


pure @safe @nogc nothrow
bool SameHemisphere( in vec3 a, in vec3 b ) {
    return ( a.z * b.z ) > 0.0f;
}

pure @safe @nogc nothrow
vec3 FaceForward( in vec3 v, in vec3 n ) {
    return ( v_dot( v, n ) >= 0.0f ) ? n : -1.0f*n;
}


//
//  Defines the abstract base class for BRDFs and BTDFs
//
abstract class BaseBxDF
{
    const BxDFType    m_type;

    pure @safe @nogc nothrow
	this( BxDFType type )
	{
	    m_type = type;
	}

    pure const @safe @nogc nothrow final
	BxDFType GetType() { return m_type; }
	
	pure const @safe @nogc nothrow
	bool MatchesType( BxDFType type ) {
	    return ( m_type & type ) == m_type;
	}

	//  BxDF Args:
	//
	//  wo = outgoing lighting direction on surface
	//  wi = incident lighting direction
	//

	/**
        Evaluate the BxDF for a given outgoing and incident lighting direction
        Params:
            wo = outgoing direction
            wi = incident lighting direction
        Returns:
            The ratio of reflected irradiance heading towards wo
    */
	pure const @safe @nogc nothrow
	Spectrum F( in vec3 wo, in vec3 wi );

    // F_TODO:: Document the parameters of these methods.
	
    /**
        Generates a sampling direction (o_wi) and PDF (o_pdf) give na random sample u (2D uniform random number)

        The default implementation will do simple cosine lobe sampling.

        NOTE:: The default implementation of Sample_F and Pdf is for cosine hemisphere sampling
               If a new sampling technique needs to be written, Pdf must also be changed accordingly
    */
	pure const @safe @nogc nothrow
    Spectrum Sample_F(
	    in vec3     wo,    
		in vec2     u,
		ref vec3    o_wi,
	    float*      o_pdf,
		BxDFType*   o_sampledType = null )
	{
        o_wi = CosineSampleHemisphere( u );
		if ( wo.z < 0.0f ) {
		    o_wi.z *= -1.0f;
		}
		*o_pdf = Pdf( wo, o_wi );
		return F( wo, o_wi );
	}

	/**
        Returns the PDF value for a pair of incoming and outgoing directions

        NOTE:: Does cosine hemisphere sampling by default. If a different PDF function is desired,
               then Sample_F must also be updated
    */
	pure const @safe @nogc nothrow
	float Pdf( in vec3 wo, in vec3 wi )
	{
	    return SameHemisphere( wo, wi ) ? AbsCosTheta( wi )*INV_PI : 0.0f;
	}


	/// F_TODO:: Add default routines for calculating hemispherical reflectances below
	///
	/**
        Compute the Hemispherical-Directional reflectance on the surface in the direction wo
        The integral of the BDRF toward wo over the hemisphere of incoming directions
    */
	pure const @safe @nogc nothrow
    Spectrum Rho( in vec3 wo, in vec2[] samples );

	/**
        Compute the average Hemispherical-Hemispherical reflection on the surface.
        The same as the Hemispheriecal-Directional reflectance, but averaged over the hemisphere
          of outgoing directions.
    */
	pure const @safe @nogc nothrow
    Spectrum Rho( in vec2[] samples1, in vec2[] samples2 );
}


class LambertBrdf : BaseBxDF
{
    Spectrum m_R;

    this( Spectrum reflectance )
	{
	    super( BxDFType.Diffuse | BxDFType.Reflection );
		m_R = reflectance;
	}
	
	/**
        Evaluate the BxDF for a given outgoing and incident lighting direction
        Params:
            wo = outgoing direction
            wi = incident lighting direction
        Returns:
            The ratio of reflected irradiance heading towards wo
    */
	override pure const @safe @nogc nothrow
	Spectrum F( in vec3 wo, in vec3 wi )
	{
	    return m_R*INV_PI;
	}


	/**
        Compute the Hemispherical-Directional reflectance on the surface in the direction wo
        The integral of the BDRF toward wo over the hemisphere of incoming directions
    */
	override pure const @safe @nogc nothrow
    Spectrum Rho( in vec3 wo, in vec2[] samples )
	{
	    return m_R;
	}

	/**
        Compute the average Hemispherical-Hemispherical reflection on the surface.
        The same as the Hemispheriecal-Directional reflectance, but averaged over the hemisphere
          of outgoing directions.
    */
	override pure const @safe @nogc nothrow
    Spectrum Rho( in vec2[] samples1, in vec2[] samples2 )
	{
        return m_R;
	}
}

