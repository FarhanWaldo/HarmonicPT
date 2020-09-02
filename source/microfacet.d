import bxdf;
import fwmath;


class MicrofacetDistribution
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
        Calculate the Pdf for sampling this microfacet distribution with a given outgoing and half angle vector

        Params:
            wo = Outgoing angle
            wh = half-angle vector  
    */
	pure @safe @nogc nothrow const
	float Pdf( in vec3 wo, in vec3 wh );


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
