import fwmath;
import interactions;
import scene;
import shape;
import spectrum;

struct VisibilityTester
{
    Interaction    m_p0;
	Interaction    m_p1;

	this( in ref Interaction p0, in ref Interaction p1 )
	{
	    m_p0 = p0;
		m_p1 = p1;
	}

	pure const @nogc @trusted nothrow
	bool Unoccluded( const(Scene)* scene )
	{
	    Ray shadowRay = m_p0.CreateRayTo( m_p1.m_pos );
	    return ! scene.FindAnyIntersection( &shadowRay );
	}
}

enum LightFlags : uint
{
    Invalid  = 0,
	Area     = 1,
	Infinite = 1 << 1
}

enum LightType : uint
{
    Invalid             = 0,
    DiffuseAreaLight    = 1,
	ImageBasedLight     = 2,
	FocussedAreaLight   = 3
}


struct LightCommon
{
    enum IsLight = true;

	LightFlags     m_flags;
	LightType      m_type;
	uint           m_numSamples = 1;

    this( LightFlags flags, LightType type, uint numSamples = 1 )
	{
	    m_flags         = flags;
		m_type          = type;
		m_numSamples    = numSamples;
	}
	
	pure const @nogc @safe nothrow
	LightFlags     GetFlags() { return m_flags; }

	pure const @nogc @safe nothrow
	LightType      GetType()  { return m_type; }

	pure const @nogc @safe nothrow
	uint           GetNumSamples() { return m_numSamples; }

	// F_TODO:: Add medium interface
}
alias const(LightCommon) CLightCommon;

struct DiffuseAreaLight
{
    LightCommon m_common;
	alias m_common this;

	// Replace with spectrum
	Spectrum      m_emission;
    ShapeCommon*  m_shape;	/// An area light is associated with a piece of geometry

	this( Spectrum emission, ShapeCommon* shape, uint numSamples = 1 )
	{
        assert( shape != null, "Creating DiffuseAreaLight with null shape pointer, something went wrong" );
	
	    m_common     = LightCommon( LightFlags.Area, LightType.DiffuseAreaLight, numSamples );
		m_emission   = emission;
		m_shape      = shape;
	}
}
alias const(DiffuseAreaLight) CDiffuseAreaLight;


pure @nogc @trusted nothrow
Spectrum // F_TODO:: Should be a spectrum....
Light_SampleIrradiance(
    CLightCommon* light,
    CInteraction* refPoint,
	vec2          randomSample,
	ref vec3      o_irradianceDirection,
	ref float     o_pdf,
	ref VisibilityTester visTester )
{
    switch ( light.GetType() )
	{
	    case LightType.DiffuseAreaLight:
		auto areaLight = cast(CDiffuseAreaLight*) light;
		return DiffuseAreaLight_SampleIrradiance( areaLight, refPoint, randomSample, o_irradianceDirection, o_pdf, visTester );

		default:
		return vec3(0.0f);
	}
}

pure @nogc @safe nothrow
Spectrum // F_TODO:: Should be spectrum ...
DiffuseAreaLight_SampleIrradiance(
    CDiffuseAreaLight* areaLight,
	CInteraction*      refPoint,
	vec2               randomSample,
    ref vec3           o_irradianceDirection,
	ref float          o_pdf,
	ref VisibilityTester visTester )
{
    return vec3(0.0f);
}
