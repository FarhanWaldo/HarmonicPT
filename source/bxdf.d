import std.math;


import fwmath;
import spectrum;
import sampling;

enum BxDFType
{
    Reflection       = 1 << 0,
	Transmission     = 1 << 1,
	Diffuse          = 1 << 2,
	Glossy           = 1 << 3,
	Specular         = 1 << 4,

	All              = Reflection |
	                   Transmission |
					   Diffuse |
					   Glossy |
					   Specular
}


//
//  Utility Methods
//

//  All vectors are in the reflection coordinate system
//  The Normal vector for the surface is the z-axis [0, 0, 1]
//  The X and Y axes are the tangent, and bitangent respectively
//
//  The parameterisation from the Cartesian domain to Spherical Coords
//  
//      x = r * sin( theta ) * cos( phi )
//      y = r * sin( theta ) * sin( phi )
//      z = r * cos( theta )
//
//      Where:
//          r       = radius of Sphere (has value of 1 in the reflection coordinate system)
//          theta   = angle between the Z and X axes [ 0, Pi ]
//          phi     = angle between the X and Y axes [ 0, 2*Pi )
//
//


pure float CosTheta( in vec3 w )        { return w.z; }
pure float Cos2Theta( in vec3 w )       { return w.z * w.z; }
pure float AbsCosTheta( in vec3 w )     { return Abs( w.z ); }

pure float Sin2Theta( in vec3 w )       { return Max( 0.0, 1.0 - Cos2Theta( w ) ); }
pure float SinTheta( in vec3 w )        { return sqrt( Sin2Theta( w ) ); }
pure float TanTheta( in vec3 w )        { return SinTheta( w ) / CosTheta( w ); }
pure float Tan2Theta( in vec3 w )       { return Sin2Theta( w ) / Cos2Theta( w ); }

pure float CosPhi( in vec3 w ) {
    float sinTheta = SinTheta( w );
	return ( sinTheta == 0.0f ) ? 1.0f : Clamp( w.x / sinTheta, -1.0f, 1.0f );
}

pure float SinPhi( in vec3 w ) {
    float sinTheta = SinTheta( w );
	return ( sinTheta == 0.0f ) ? 0.0f : Clamp( w.y / sinTheta, -1.0f, 1.0f );
}

pure float Cos2Phi( in vec3 w ) {
    float cosPhi = CosPhi( w );
	return cosPhi * cosPhi;
}

pure float Sin2Phi( in vec3 w ) {
    float sinPhi = SinPhi( w );
	return sinPhi*sinPhi;
}


pure float CosDPhi( in vec3 wa, in vec3 wb ) {
    return Clamp( (wa.x*wb.x + wa.y*wb.y) / sqrt( wa.x*wa.x + wa.y*wa.y ) * ( wb.x*wb.x + wb.y*wb.y ),
	               -1.0f, 1.0f );
}

pure vec3 Reflect( in vec3 wo, in vec3 n ) {
    return -1.0f*wo + 2.0f*v_dot( wo, n )*n;
}

pure bool
Refract( in vec3 wi, in vec3 n, float eta, out vec3 o_wt )
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


pure bool SameHemisphere( in vec3 a, in vec3 b ) {
    return ( a.z * b.z ) > 0.0f;
}

pure vec3 FaceForward( in vec3 v, in vec3 n ) {
    return ( v_dot( v, n ) >= 0.0f ) ? n : -1.0f*n;
}


//
//  Defines the abstract base class for BRDFs and BTDFs
//
abstract class BaseBxdf
{
    const BxDFType    m_type;

	this( BxDFType type )
	{
	    m_type = type;
	}

	pure const bool
	MatchesType( BxDFType type ) {
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
	pure const vec3 F( in vec3 wo, in vec3 wi );

    // F_TODO:: Document the parameters of these methods.
	
    /**
        Generates a sampling direction (o_wi) and PDF (o_pdf) give na random sample u (2D uniform random number)
    */
	pure const vec3
	Sample_F(
	    in vec3     wo,    
		in vec2     u,
		out vec3    o_wi,
		out float   o_pdf,
		BxDFType*   o_sampledType = null );

	/**
        Returns the PDF value for a pair of incoming and outgoing directions
    */
	pure const float PDF( in vec3 wo, in vec3 wi );


	/**
        Compute the Hemispherical-Directional reflectance on the surface in the direction wo
        The integral of the BDRF toward wo over the hemisphere of incoming directions
    */
	pure const vec3 Rho( in vec3 wo, in vec2[] samples );

	/**
        Compute the average Hemispherical-Hemispherical reflection on the surface.
        The same as the Hemispheriecal-Directional reflectance, but averaged over the hemisphere
          of outgoing directions.
    */
	pure const vec3 Rho( in vec2[] samples1, in vec2[] samples2 );
}
