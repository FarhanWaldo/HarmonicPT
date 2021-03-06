import spectrum;
import bxdf;
import fwmath;


class MicrofacetReflection : BaseBxDF
{
	const Spectrum   m_R;
    const IFresnel*  m_fresnel;
	
	const BaseMicrofacetDistribution* m_distribution;

    this( in Spectrum reflectance, IFresnel* fresnel, BaseMicrofacetDistribution* distribution )
	{
		super( BxDFType_Glossy | BxDFType_Reflection );
		m_R            = reflectance;
		m_fresnel      = fresnel;
        m_distribution = distribution;
	}
	
	/**
        Evaluate the BxDF for a given outgoing and incident lighting direction.

        Params:
            wo = outgoing direction
            wi = incident lighting direction
        Returns:
            Returns an empty spectrum
    */
	override pure const @safe @nogc nothrow
	Spectrum F( in vec3 wo, in vec3 wi )
	{   
		const float cosThetaO = AbsCosTheta( wo );
		const float cosThetaI = AbsCosTheta( wi );

		/// Half-angle vector
		vec3 wh = wo + wi;
        
        /// Handle degenerate cases
		///
		if ( cosThetaO == 0.0f || cosThetaI == 0.0f ) { return Spectrum(0.0f); }
        if ( wh.x == 0.0f && wh.y == 0.0f && wh.z == 0.0f ) { return Spectrum(0.0f); }

        wh.normalise();
        const vec3 n = vec3( 0.0f, 0.0f, 1.0f );
		
		Spectrum fresnel = m_fresnel.Evaluate(v_dot( wh, FaceForward( wh, n )) );

        return m_R*m_distribution.D( wh )* m_distribution.G( wo, wi )*fresnel /
                (4.0f*cosThetaO*cosThetaI);
	}

	/**
        Returns the PDF value for a pair of incoming and outgoing directions.
    */
	override pure const @safe @nogc nothrow
	float Pdf( in vec3 wo, in vec3 wi )
	{
		if (OnOppositeHemispheres(wo,wi))  { return 0.0f; }
		vec3 wh = wo+wi;
		wh.normalise();
		
		return m_distribution.Pdf(wo,wh)/
			     (4.0f*v_dot(wo, wh));
	}
	
    /**
        Generates a sampling direction (o_wi) and PDF (o_pdf) given a random sample u (2D uniform random number)
    */
	override pure const @trusted @nogc nothrow
    Spectrum Sample_F(
	    in vec3     wo,    
		in vec2     u,
		ref vec3    o_wi,
	    float*      o_pdf,
		BxDFType*   o_sampledType = null )
	{
		if ( wo.z == 0.0f ) { return Spectrum(0.0f); }
		const vec3 wh = m_distribution.Sample_Wh( wo, u );
		if ( v_dot(wo,wh) < 0.0f ) { return Spectrum(0.0f); } /// rare case

		o_wi = Reflect(wo,wh);
		if (OnOppositeHemispheres(wo, o_wi)) { return Spectrum(0.0f); }

		*o_pdf = m_distribution.Pdf(wo,wh) / (4.0f*v_dot(wo,wh));
		return F( wo, o_wi );
		
    }	
}

/**
    Maps a normalised floating point value for roughness to alpha for microfacet distributions

    Params:
        roughness =  surface roughness value, [0, 1]

    Returns: Equivalent alpha value to use for parameterising microfacet distributions
*/
pure @safe @nogc nothrow
float Beckmann_RoughnessToAlpha( float roughness )
{
    import std.math : log;
    roughness = Max( roughness, cast(float) 1e-3 );
    const float x = log( roughness );
    return  1.62142f + 0.819955f * x + 0.1734f * x * x +
            0.0171201f * x * x * x + 0.000640711f * x * x * x * x;
}

abstract class BaseMicrofacetDistribution
{
	const bool m_sampleVisibleNormals = false;   /// Sample only the normals that aren't self-shadowed in the masking model

	pure @safe @nogc nothrow 
	this( bool sampleVisibleNormals )
	{
	    m_sampleVisibleNormals = sampleVisibleNormals;
	}

	/**
        Evaluate the given Microfacet distribution for a given half-angle vector wh

        Params:
            wh = The half-angle vector; |(wi + wo)/2| ( halfway between incidence and outgoing direction)

        Returns:
            Ratio of normals oriented aligned with the half-angle vector -> [0.0, 1.0]
    */
	pure @safe @nogc nothrow const
	float D( in vec3 wh );

	
	pure @safe @nogc nothrow const
	float Lambda( in vec3 w );


	/**
        Sample the given Microfacet distribution for an incidence vector based on an outgoing angle

        Params:
            wo = Outgoing angle to sample against
             u = A uniformly distributed random number in [0,1]^2
    */
	pure @safe @nogc nothrow const
	vec3 Sample_Wh( in vec3 wo, in vec2 u );

	/**
        Calculate the Pdf for sampling this microfacet distribution with a given outgoing and half-angle vector

        Params:
            wo = Outgoing angle
            wi = Half angle vector i.e. (wo+wi)/|wo+wi|
    */
	pure @safe @nogc nothrow const
	float Pdf( in vec3 wo, in vec3 wh )
	{
	    if ( m_sampleVisibleNormals ) {
		    return D(wh)*G1(wo)*Abs(v_dot(wo,wh)) / Abs(CosTheta(wo));
		}
		else {
		    return D(wh)*Abs(CosTheta(wo));
		}
	}

	pure @safe @nogc nothrow const
	float G1( in vec3 w )
	{
	    return 1.0f/(1.0f + Lambda(w));
	}

	pure @safe @nogc nothrow const
	float G( in vec3 wo, in vec3 wi )
	{
	    return 1.0f/(1.0f + Lambda(wo) + Lambda(wi));
	}
}


class BeckmannDistribution : BaseMicrofacetDistribution
{
    ///  Controls size of microfacet distrbution
	///
	///  If m_alphaX == m_alphaY the distribution is isotropic, and anisotropic otherwise
	///    
    const float m_alphaX;
	const float m_alphaY;

    pure @safe @nogc nothrow
	this( float alphaX, float alphaY, bool sampleVisibleNDF = false )
	{
	    super( sampleVisibleNDF );

		m_alphaX = alphaX;
		m_alphaY = alphaY;
	}

	pure @safe @nogc nothrow
	this( float alpha, bool sampleVisibleNDF = false )
	{
	    super( sampleVisibleNDF );

		m_alphaX = alpha;
		m_alphaY = alpha;
	}

	/**
        Evaluate the given Microfacet distribution for a given half-angle vector wh

        Beckmann Distribution:

						e^( -Tan2(theta)( Cos2(phi)/a_x*a_x + Sin2(phi)/a_y*a_y ) )
			D( wh ) =  --------------------------------------------------------------
									  PI * a_x * a_y * Cos4( theta )

        Params:
            wh = The half-angle vector; i.e. (wi + wo)/||wi + wo|| ( halfway between incidence and outgoing direction)

        Returns:
            Ratio of normals oriented aligned with the half-angle vector -> [0.0, 1.0]
    */
	override pure @safe @nogc nothrow const
	float D( in vec3 wh )
	{
		import std.math : isFinite, exp;
		
		const float tan2Theta = Tan2Theta( wh );
        if ( !isFinite( tan2Theta )) { return 0.0f; }

        const float cos4Theta = Cos2Theta(wh)*Cos2Theta(wh);
		const float a_xx = m_alphaX*m_alphaX;
		const float a_xy = m_alphaX*m_alphaY;
		const float a_yy = m_alphaY*m_alphaY;
		
	    return exp( -tan2Theta*(Cos2Phi(wh)/a_xx + Sin2Phi(wh)/a_yy) )  /
			                ( PI*a_xy*cos4Theta );
	}

	
	override pure @safe @nogc nothrow const
	float Lambda( in vec3 w )
	{
		import std.math : isFinite, sqrt;
		
		const float absTanTheta = Abs( TanTheta( w) );
		if ( !isFinite( absTanTheta ) ) { return 0.0f; }

		const float alpha = sqrt( Cos2Phi( w )*m_alphaX*m_alphaX + Sin2Phi( w )*m_alphaY*m_alphaY );

		const float a = 1.0f / ( alpha * absTanTheta );
		if ( a > 1.6f ) { return 0.0f; }

		return (1 - 1.259f * a + 0.396f * a * a) /
			     (3.535f * a + 2.181f * a * a);
	}


	/**
        Sample the given Microfacet distribution for an incidence vector based on an outgoing angle

        Params:
            wo = Outgoing angle to sample against
             u = A uniformly distributed random number in [0,1]^2

        Returns:
            An incidence angle for sampling
    */
	override pure @safe @nogc nothrow const
	vec3 Sample_Wh( in vec3 wo, in vec2 u )
	{
        import std.math : log, sin, cos, sqrt;
		
		// if ( m_sampleVisibleNormals )
		// {
		// 	// F_TODO::
		// 	return vec3( 0.0f );
		// }
		// else
		{
			float tan2Theta = 0.0f;
			float phi       = 0.0f;

			// if ( m_alphaX == m_alphaY ) // isotropic case
			{
				float logSample = log( 1.0f - u.x );
				tan2Theta = -m_alphaX*m_alphaX*logSample;
				phi = u.y*TAU;
			}
			// else    // anisotropic
			{
				// F_TODO::
			}

			const float cosTheta  = 1.0f / sqrt( 1.0f + tan2Theta );
			const float sinTheta  = SafeSqrt( 1.0f - cosTheta*cosTheta );
			const float sinPhi    = sin(phi);
			
			vec3 wh = vec3( sinPhi*cosTheta, sinPhi*sinTheta, cos( phi ) );

			if (OnOppositeHemispheres( wo, wh )) { wh = -1.0f*wh; }

			return wh;
		}
	}
}


