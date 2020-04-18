import fwmath;

alias vec3 Spectrum;

// const enum NumSpectralSamples = 10;
// const enum MinWavelength = 400.0f; // nanometres
// const enum MaxWavelength = 700.0f; // nanometres

/**
    Represents an SPD (Spectral Power Distribution) as a weighted sum of n-basis functions.
    The function basis should be an orthogonal function basis so that the coefficients can be
    linearly combined and scaled.

    This abstraction is sufficient to represent an SPD as a series of coefficients of these basis functions,
    or to represent as a discretely sampled SPD, breaking the wavelength range into segments and storing the spectral
    response for each segment.
*/
struct CoefficientSpectrum( NumSpectralSamples )
{
	float[NumSpectralSamples]  m_coeffs;

	// Allows indexing a CoefficientSpectrum object as if it was the m_samples array
	//
	alias m_coeffs this;

	this( float c )
	{
		m_coeffs[] = c;
	}
	
	pure const @nogc nothrow
	CoefficientSpectrum
	opBinary( string op )( in CoefficientSpectrum s )
	{
		static assert( ( op == "*" ) ||
					   ( op == "+" ) ||
					   ( op == "-" ) ||
					   ( op == "/" ),
					   "Op " ~op~ "= is not supported for Coefficient Spectrum" );
		
		CoefficientSpectrum newSpectrum = void;
        newSpectrum.m_coeffs[] = mixin( "m_coeffs[]" ~ op ~ "s.m_coeffs[]" );
		return newSpectrum;
	}

	pure const @nogc nothrow
	CoefficientSpectrum
	opBinaryRight( string op )( in CoefficientSpectrum s )
	{
 		static assert( ( op == "*" ) ||
					   ( op == "+" ) ||
					   ( op == "-" ) ||
					   ( op == "/" ),
					   "Op " ~op~ "= is not supported for Coefficient Spectrum" );
		
		CoefficientSpectrum newSpectrum = void;
        newSpectrum.m_coeffs[] = mixin( "m_coeffs[]" ~ op ~ "s.m_coeffs[]" );
		return newSpectrum;
	}

	pure @nogc nothrow
	void
	opOpAssign( string op )( in CoefficientSpectrum s )
	{
		static assert( ( op == "*" ) ||
					   ( op == "+" ) ||
					   ( op == "-" ) ||
					   ( op == "/" ),
					   "Op " ~op~ "= is not supported for Coefficient Spectrum" );

	    mixin( "m_coeffs[] " ~op~ "= s.m_coeffs[]" ); 
	}

	pure const bool
	IsBlack()
	{
		foreach (i; 0..NumSpectralSamples ) {
		    if ( m_coeffs[i] != 0.0f ) { return false; }
		}
	    return true;	
	}

	pure const @nogc nothrow
	CoefficientSpectrum
	Clamp( float low, float high )
	{
	    CoefficientSpectrum newSpectrum = void;

		foreach( i; 0..NumSpectralSamples ) {
		    newSpectrum[i] = fwmath.Clamp( m_coeffs[i], low, high );
		}

		return newSpectrum;
	}
};

 
