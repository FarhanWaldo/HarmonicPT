import std.math : sqrt;

import fwmath;
import spectrum;
import sampling;


enum BxDFTypeFlag
{
    None             = 0,
    Reflection       = 1 << 0,
	Transmission     = 1 << 1,
	Diffuse          = 1 << 2,
	Glossy           = 1 << 3,
	Specular         = 1 << 4,
}
import std.typecons;
alias BitFlags!(BxDFTypeFlag, Yes.unsafe) BxDFType;

enum BxDFType BxDFType_None         = BxDFTypeFlag.None;
enum BxDFType BxDFType_Reflection   = BxDFTypeFlag.Reflection;
enum BxDFType BxDFType_Transmission = BxDFTypeFlag.Transmission;
enum BxDFType BxDFType_Diffuse      = BxDFTypeFlag.Diffuse;
enum BxDFType BxDFType_Glossy       = BxDFTypeFlag.Glossy;
enum BxDFType BxDFType_Specular     = BxDFTypeFlag.Specular;
enum BxDFType BxDFType_All =
	BxDFType_Reflection | BxDFType_Transmission | BxDFType_Diffuse | BxDFType_Glossy | BxDFType_Specular;
enum BxDFType BxDFType_AllNonSpecular = BxDFType_All & ~BxDFType_Specular;

pure @safe @nogc nothrow bool IsSpecular( BxDFType flags ) { return ((flags & BxDFType_Specular) == BxDFType_Specular); }


version(none){
/**

  Utility Methods


  All vectors are in the reflection coordinate system
  The Normal vector for the surface is the z-axis [0, 0, 1]
  The X and Y axes are the tangent, and bitangent respectively

  The parameterisation from Cartesian -> Spherical coordinate system
 
     x = r * sin( theta ) * cos( phi )
     y = r * sin( theta ) * sin( phi )
     z = r * cos( theta )

     Where:
         r       = radius of Sphere (radius = 1, in the reflection coordinate system)
         theta   = angle between the Z and X axes [ 0, Pi ]
         phi     = angle between the X and Y axes [ 0, 2*Pi )

*/
}
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

///
///  Fresnel implementation
///
interface IFresnel
{
	pure @nogc const nothrow
	Spectrum Evaluate( float cosIncidence );
}

class FresnelConstant : IFresnel
{
	pure @nogc const nothrow override
	Spectrum Evaluate( float cosIncidence )
	{
        return Spectrum( 1.0f );
	}
}

class FresnelDielectric : IFresnel
{
    float m_etaI;  /// index of refraction in incident medium
	float m_etaT;  /// index of refraction in transmitted medium

    pure @nogc const nothrow
	this( float etaIncident, float etaTransmitted )
	{
		m_etaI = etaIncident;
		m_etaT = etaTransmitted;
	}
	
	pure @nogc const nothrow override
	Spectrum Evaluate( float cosIncidence )
	{
		return Spectrum( Fresnel_Dielectric( cosIncidence, m_etaI, m_etaT ) );
	}
}

/**
  Computes the Fresnel response for unpolarised light scattering on a dielectric surface boundary
  Params:
      cosThetaI   = cosine of incidence angle (theta)
      etaI        = index of refraction for incident medium
      etaT        = index of refraction for transmitted medium

  Returns: a normalised float, [0.0, 1.0], that gives the percentage of light that is reflected
*/
pure @nogc @safe nothrow
float Fresnel_Dielectric( float cosThetaI, float etaI, float etaT )
{
    cosThetaI = Clamp( cosThetaI, -1.0f, 1.0f );
    bool entering = cosThetaI > 0.0f;
    if ( !entering )
    {
        Swap( etaI, etaT );
        cosThetaI = Abs( cosThetaI );
    }

    float sinThetaI = SafeSqrt( 1.0f - cosThetaI*cosThetaI );
    float sinThetaT = ( etaI / etaT ) * sinThetaI;

    if ( sinThetaT >= 1.0f )
    {
        return 1;
    }

    float cosThetaT = SafeSqrt( 1.0f - sinThetaT*sinThetaT );

    float rParallel =   ( ( etaT*cosThetaI ) - ( etaI*cosThetaT ) ) /
                        ( ( etaT*cosThetaI ) + ( etaI*cosThetaT ) );

    float rPerpendincular = ( ( etaI*cosThetaI ) - ( etaT*cosThetaT ) ) /
                            ( ( etaI*cosThetaI ) + ( etaT*cosThetaT ) );

    return 0.5f*( rParallel*rParallel + rPerpendincular*rPerpendincular );
}

//
//  Defines the abstract base class for BRDFs and BTDFs
//
abstract class BaseBxDF
{
    const BxDFType    m_type;

    pure @safe @nogc nothrow
	this( BxDFType typeFlags )
	{
	    m_type = typeFlags;
	}

    pure const @safe @nogc nothrow final
	BxDFType GetType() { return m_type; }
	
	pure const @safe @nogc nothrow final
	bool MatchesType( BxDFType typeFlags ) {
	    return ( m_type & typeFlags ) == m_type;
	}

    pure const @safe @nogc nothrow final
	bool IsSpecular()
	{
		return ( m_type & BxDFType_Specular ) == BxDFType_Specular;
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
	///`
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
	    super( BxDFType_Diffuse | BxDFType_Reflection );
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


class SpecularReflection : BaseBxDF
{
	const Spectrum  m_R;
	const IFresnel* m_fresnel;

	this( Spectrum tint, IFresnel* fresnel )
	{
		super( BxDFType_Reflection | BxDFType_Specular );
		m_R         = tint;
		m_fresnel   = fresnel;
	}

	/**
        Evaluate the BxDF for a given outgoing and incident lighting direction.
        Since this represents a specular scattering event, we make F() return 0 for an arbitrary incidence and exitant angle        

        Params:
            wo = outgoing direction
            wi = incident lighting direction
        Returns:
            Returns an empty spectrum
    */
	override pure const @safe @nogc nothrow
	Spectrum F( in vec3 wo, in vec3 wi )
	{
	    return Spectrum(0.0f);
	}

	/**
        Returns the PDF value for a pair of incoming and outgoing directions. Since this is a specular event,
        its PDF is technically described by a dirac delta function, and we'll be returning 0 for the PDF method.
        Specular lobes must be used by Sample_F()
    */
	override pure const @safe @nogc nothrow
	float Pdf( in vec3 wo, in vec3 wi )
	{
	    return 0.0f;
	}
	
    /**
        Generates a sampling direction (o_wi) and PDF (o_pdf) given a random sample u (2D uniform random number)

        Specular Reflection can only generate a single event when sampling, in the only direction where the PDF is non-zero

        Always assigns 1.0f to the pdf
    */
	override pure const @trusted @nogc nothrow
    Spectrum Sample_F(
	    in vec3     wo,    
		in vec2     u,
		ref vec3    o_wi,
	    float*      o_pdf,
		BxDFType*   o_sampledType = null )
	{
		o_wi = vec3( -1.0f*wo.x, -1.0f*wo.y, wo.z );
		*o_pdf = 1.0f; /// Delta distribution

		if ( o_sampledType )
		{
		    *o_sampledType = BxDFType_Specular | BxDFType_Reflection;
		}

		return m_fresnel.Evaluate(CosTheta(o_wi)) * m_R / AbsCosTheta( o_wi );
    }

	
	/**
        Compute the Hemispherical-Directional reflectance on the surface in the direction wo
        The integral of the BDRF toward wo over the hemisphere of incoming directions
    */
	override pure const @safe @nogc nothrow
    Spectrum Rho( in vec3 wo, in vec2[] samples )
	{
	    return Spectrum(0.0f);
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

/// F_TODO:: Add Fresnel Conductor
///


