import bxdf;
import fwmath;


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


//////////////////////////////
////
////   HEY NILOY: Finish implementing the Beckmann distribution
////
///////////////////////////////////
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

        Params:
            wh = The half-angle vector; |(wi + wo)/2| ( halfway between incidence and outgoing direction)

        Returns:
            Ratio of normals oriented aligned with the half-angle vector -> [0.0, 1.0]
    */
	override pure @safe @nogc nothrow const
	float D( in vec3 wh )
	{
	    /// F_TODO:: Implement
	    return 0.0f;
	}

	
	override pure @safe @nogc nothrow const
	float Lambda( in vec3 w )
	{
	    return 0.0f;
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
	    return vec3(0.0f);
	}
}
