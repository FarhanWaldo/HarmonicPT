import std.math : sin, cos, sqrt;
import fwmath;


/**
    Sampling and PDF methods for basic shapes
*/

pure @nogc @safe nothrow
vec2 ConcentricSampleDisk( in ref vec2 P )
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

pure @nogc @safe nothrow
vec3 UniformSampleHemisphere( in ref vec2 u )
{
    vec3 sample;
    float z = u.x;
    float r = sqrt( Max( 0.0f, 1.0f - z*z ) );
    float phi = 2.0f * PI * u.y;
    sample = vec3( r * cos( phi ), r * sin( phi ), z );
    return sample;
}

pure @nogc @safe nothrow
vec3 CosineSampleHemisphere( in ref vec2 u )
{
    vec2 p  = ConcentricSampleDisk( u );
    float z = sqrt( Max( 0.0f, 1.0f - v_dot( p, p ) ) );
    return vec3( p.x, p.y, z );
}

pure @nogc @safe nothrow
vec3 UniformSampleSphere( in ref vec2 u )
{
    float z     = 1.0f - 2.0f*u.y;
    float r     = sqrt( Max( 0.0f, 1.0f - z*z ) );
    float phi   = TAU*u.x;

    return vec3( r * cos( phi ), r * sin( phi ), z );
}

pure @nogc @safe nothrow
vec3 UniformSampleCone( in ref vec2 u, float cosThetaMax )
{
    float cosTheta =  ( 1.0f - u.x ) + ( u.x * cosThetaMax );
    float sinTheta = sqrt( 1.0f - cosTheta*cosTheta );
    float phi = u.y * 2.0f * PI;

    return vec3( cos( phi ) * sinTheta, sin( phi ) * sinTheta, cosTheta );
}


pure @nogc @safe nothrow
float UniformHemispherePDF()
{
    return INV_TAU;
}

pure @nogc @safe nothrow
float UniformSpherePDF()
{
    return 0.25f * INV_PI;
}

pure @nogc @safe nothrow
float UniformConePdf( float cosThetaMax )
{
    return 1.0f / ( 2.0f * PI * ( 1.0f - cosThetaMax ) );
}


/*******************************
    Samplers
*/

abstract class BaseSampler
{
    const ulong m_samplesPerPixel;
    ulong       m_1DArrayOffset;
    ulong       m_2DArrayOffset;

    vec2        m_currentPixel;
    ulong       m_currentPixelSampleIndex;

    //  TODO:: D arrays track size... this is probably not necessary
    //
    ulong[]     m_1DSamplesArraySizes;
    ulong[]     m_2DSamplesArraySizes;

    float[][]   m_1DSamplesArray;
    vec2[][]    m_2DSamplesArray;

    /***
        Methods
    */
    this( ulong samplesPerPixel )
    {
        m_samplesPerPixel = samplesPerPixel;
    }

    int RoundCount( int n )
    {
        return n;
    }

    @safe @nogc nothrow float Get1D();
    @safe @nogc nothrow vec2  Get2D();

    void Request1DArray( uint n )
    {
        m_1DSamplesArraySizes ~= n;
		m_1DSamplesArray ~= new float[ n * m_samplesPerPixel ];
    }

    void Request2DArray( uint n )
    {
		m_2DSamplesArraySizes ~= n;
		m_2DSamplesArray ~= new vec2[ n * m_samplesPerPixel ];
    }

    BaseSampler* Clone( int seed );

    float[] Get1DArray( int index )
    {
        if ( m_1DArrayOffset == m_1DSamplesArraySizes.length ) { return null; }

        return m_1DSamplesArray[ m_1DArrayOffset++ ][ (m_currentPixelSampleIndex*index)..(m_currentPixelSampleIndex*(index+1)) ];
    }
    
    vec2[] Get2DArray( int index )
    {
        if ( m_2DArrayOffset == m_2DSamplesArraySizes.length ) { return null; }

        return m_2DSamplesArray[ m_2DArrayOffset++ ][ (m_currentPixelSampleIndex*index)..(m_currentPixelSampleIndex*(index+1)) ];
    }

    bool StartNextSample()
    {
        m_1DArrayOffset = 0;
        m_2DArrayOffset = 0;

        ++m_currentPixelSampleIndex;

        return m_currentPixelSampleIndex < m_samplesPerPixel;
    }

    void StartPixel( vec2 pixelPos )
    {
        m_currentPixel              = pixelPos;
        m_currentPixelSampleIndex   = 0;
        m_1DArrayOffset             = 0;
        m_2DArrayOffset             = 0;
    }
}


class PixelSampler : BaseSampler
{
	float[][] m_samples1D;
	vec2[][]  m_samples2D;
	uint      m_currentDimension1D   = 0;
	uint      m_currentDimension2D   = 0;
	uint      m_numSampledDimensions = 0;
	RNG       m_rng;
	
	this( u64 samplesPerPixel, u32 nSampledDims, int seed )
	{
		super( samplesPerPixel );
		m_numSampledDimensions = nSampledDims;
		m_rng = RNG( seed );

		foreach ( uint dim; 0..nSampledDims )
		{
			m_samples1D ~= new float[ samplesPerPixel ];
			m_samples2D ~= new vec2[ samplesPerPixel ];
		}
	}

	override float Get1D()
	{
		if ( m_currentDimension1D < m_samples1D.length )
        {
            return m_samples1D[ m_currentDimension1D++ ][ m_currentPixelSampleIndex ];
		}
		else
        {
            return m_rng.rand();
		}
	}

    override vec2 Get2D()
    {
        if ( m_currentDimension2D < m_samples2D.length )
        {
            return m_samples2D[ m_currentDimension2D++ ][ m_currentPixelSampleIndex ];
        }
        else
        {
            return vec2( m_rng.rand(), m_rng.rand() );
        }
    }

    override BaseSampler* Clone( int seed )
    {
        return null;
    }

    override bool StartNextSample()
    {
        m_currentDimension1D = 0;
        m_currentDimension2D = 0;

        return super.StartNextSample();
    }
}

