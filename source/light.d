import fwmath;
import interactions;
import scene;
import shape;
import spectrum;

struct VisibilityTester
{
    Interaction    m_p0;
	Interaction    m_p1;

	pure @nogc @safe nothrow
	this( in Interaction p0, in Interaction p1 )
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
Spectrum
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
Spectrum
DiffuseAreaLight_SampleIrradiance(
    CDiffuseAreaLight* areaLight,
	CInteraction*      refPoint,
	vec2               randomSample,
    ref vec3           o_irradianceDirection,
	ref float          o_pdf,
	ref VisibilityTester visTester )
{
	Interaction shapeIntx = Shape_Sample( areaLight.m_shape, refPoint, randomSample );
    // FW_TODO::[MediumInterface] assign the one fron the light to the Interaction object
    // FW_TODO::[pbrt] should probably consult PBRT or something on this part...
	o_irradianceDirection = v_normalise( shapeIntx.m_pos - refPoint.m_pos );
	o_pdf                 = Shape_Pdf( areaLight.m_shape, refPoint, o_irradianceDirection );

	visTester             = VisibilityTester(*refPoint, cast(CInteraction) shapeIntx );

    pure @nogc @safe nothrow
	Spectrum CalculateEmission( CDiffuseAreaLight* light,  in Interaction intx, in vec3 wo )
	{
	    return ( v_dot( intx.m_normal, wo ) > 0.0f ) ? light.m_emission : Spectrum( 0.0f );
	}
	
    // return radiance;
	return CalculateEmission( areaLight, shapeIntx, -1.0f*o_irradianceDirection );
}


pure @nogc @trusted nothrow
float
Light_SamplePdf(
  	CLightCommon* light,
	CInteraction* refPoint,
	in vec3       irradianceDirection )
{
    switch ( light.GetType() )
	{
	    case LightType.DiffuseAreaLight:
		    auto areaLight = cast(CDiffuseAreaLight*)( light );
			return Shape_Pdf( areaLight.m_shape, refPoint, irradianceDirection );

		default:
		    assert(false, "Unsupported light type for Light_SamplePdf");
	}
}
