import fwmath;
import scene;
import camera;
import memory;
import bxdf;
import bsdf;
import light;
import image;
import sampling;
import spectrum;
import interactions;

interface IIntegrator
{
    void Init( in Scene* scene,  IMemAlloc* memArena );

    /**
        Performs up to #numProgressions rendering progressions

        Returns: returns whether rendering has converged
    */
    bool RenderProgression( Scene* scene, IMemAlloc* memArena, int numProgressions = 1 );
}

class HelloWorldIntegrator : IIntegrator
{
    Camera      m_camera; // render camera
    Image_F32*  m_image;

    this( Camera cam, Image_F32* image )
    {
        m_camera = cam;
        m_image  = image;
    }

    override void
    Init( in Scene* scene, IMemAlloc* memArena )
    {
        // writeln( "HelloWorldIntegrator::Init()!");
    }

    /**
        This just draws a checkerboard to the render buffer, nothing fancy
        Really only performs a single progression, regardless of what's requested

        Returns: true, since render converges immediately
    */
    override bool
    RenderProgression( Scene* scene, IMemAlloc* memArena, int numProgressions = 1 )
    {
        // writeln( "HelloWorldIntegrator::Render()!");
        uint tileSize = 64;
        uint imageWidth = m_image.m_imageWidth;
        uint imageHeight = m_image.m_imageHeight;
        float[] imageBufferData = m_image.m_pixelData;

        foreach( uint row; 0 .. imageHeight )
        {
        	foreach( uint col; 0 .. imageWidth )
            {
                uint  pixelIndex = 3*( row * imageWidth + col);
    
                float r = 1.0f;
                float g = 1.0f;
                float b = 1.0f;

                if ( ((col/tileSize) % 2 == 0) ^ ((row/tileSize) % 2 == 0) )
                {
                    r = 0.7f;
                    g = 0.6f;
                    b = 0.6f;
                }

                imageBufferData[ pixelIndex     ] = r;
                imageBufferData[ pixelIndex + 1 ] = g;
                imageBufferData[ pixelIndex + 2 ] = b;
            }
        }

        return true; // converges after first progression
    }
}

class SamplerIntegrator : IIntegrator
{
    BaseSampler*    m_sampler;
	Camera          m_camera;
	Image_F32*      m_renderBuffer;
	const uint      m_maxBounces;

    this( BaseSampler* sampler, Camera cam, Image_F32* renderBuffer, uint maxBounces = 6 )
    {
        m_sampler       = sampler;
        m_camera        = cam;
        m_renderBuffer  = renderBuffer;
        m_maxBounces    = maxBounces; 
    }

    override void
    Init( in Scene* scene, IMemAlloc* memArena )
    {
        // writeln( "HelloWorldIntegrator::Init()!");
    }

    override bool
    RenderProgression( Scene* scene, IMemAlloc* memArena, int numProgressions = 1 )
    {
        const uint imageWidth = m_renderBuffer.m_imageWidth;
        const uint imageHeight = m_renderBuffer.m_imageHeight;
        const vec2 cameraDims  = vec2( cast(float) imageWidth, cast(float) imageHeight );

        float[] renderBuffer = m_renderBuffer.m_pixelData;

        // TODO:: Have better pixel filtering
        //
        foreach ( uint j; 0 .. imageHeight )
        {
            foreach( uint i; 0 .. imageWidth )
            {
                // // thread id stuff
                
                Spectrum pixelColour = Spectrum(0.0); // = vec3( 0.0, 1.0, 0.0 );
                // // int  nSamples;

                foreach ( progression; 0 .. numProgressions )
                {
                    // const vec2 pixelPos = vec2( cast(float) imageWidth, cast(float) imageHeight );
					memArena.Reset();
                    const vec2 pixelPos = vec2( cast(float) i, cast(float) j );
                    const vec2 jitteredPos = pixelPos + m_sampler.Get2D();

                    Ray cameraRay;
                    m_camera.SpawnRay( jitteredPos, cameraDims, cameraRay );

                    pixelColour += Irradiance( cameraRay, scene, m_sampler, memArena );
                }

                pixelColour *= (1.0/( cast(float) numProgressions ) );

                const float ir = pixelColour.r;
                const float ig = pixelColour.g;
                const float ib = pixelColour.b;

                ulong baseIndex = (( j*imageWidth ) + i ) * 3;
                renderBuffer[ baseIndex ]       += ir;
                renderBuffer[ baseIndex + 1 ]   += ig;
                renderBuffer[ baseIndex + 2 ]   += ib;
            }
        }

        return true;
    }

    Spectrum
    Irradiance(
        in  Ray      ray,
        Scene*          scene,
        BaseSampler*    sampler,
        IMemAlloc*      memArena,
        int             depth = 0 )
    {
        return vec3( 0.0, 0.0, 1.0 ); // Output just red
    }

}

class WhittedIntegrator : SamplerIntegrator
{
    this( BaseSampler* m_sampler, Camera cam, Image_F32* renderBuffer, uint maxBounces = 6 )
    {
        super( m_sampler, cam, renderBuffer, maxBounces );
    }

    override Spectrum
    Irradiance(
        in  Ray      ray,
        Scene*          scene,
        BaseSampler*    sampler,
        IMemAlloc*      memArena,
        int             depth = 0 )
    {
        vec3                radiance;
        SurfaceInteraction  surfIntx;

        if ( scene.FindClosestIntersection(&ray, surfIntx ) )
        {
            radiance = vec3( 1.0 );
        }
		else {

        radiance = 0.5*v_normalise( ray.m_dir ) + vec3( 0.5 );

		}

        return radiance;

    }

}

enum LightingStrategy
{
    UniformSampleAll,
	UniformSampleOne
}

class DirectLightingIntegrator : SamplerIntegrator
{
    LightingStrategy m_lightingStrategy;

    this( BaseSampler* sampler, Camera cam, Image_F32* renderBuffer, LightingStrategy lightingStrategy=LightingStrategy.UniformSampleOne )
	{
		super( sampler, cam, renderBuffer, 1 /* max bounces */ );
		m_lightingStrategy = lightingStrategy;
	}
	
	override Spectrum
	Irradiance( in Ray ray, Scene* scene, BaseSampler* sampler, IMemAlloc* memArena, int depth = 0 )
	{
		Spectrum radiance; // = Spectrum( 1.0f, 0.0f, 0.0f );

        SurfaceInteraction surfIntx;
		if ( scene.FindClosestIntersection( &ray, surfIntx ) )
		{
            ComputeScatteringFunctions( &surfIntx, memArena, true /* from eyes */, true /* allow multiple lobes */ );

			vec3 wo = surfIntx.m_wo;
			radiance += surfIntx.GetAreaLightEmission( wo );

			if ( m_lightingStrategy == LightingStrategy.UniformSampleAll )
			{
			    // TODO:: what are ya doin' mate
			}
			else
			{
			    radiance += UniformSampleOneLight( surfIntx, scene, memArena, sampler );
			}
		}
		else
		{
		    const vec3 dir = ray.m_dir;
			const float t = 0.5f*(dir.y+1.0f);
			const vec3 a = vec3( 0.5f, 0.7f, 1.0f );
			const vec3 b = vec3( 1.0f, 1.0f, 1.0f );
			const vec3 colour = Lerp(  t, a, b );
			radiance = colour;
		}
		
		return radiance;
	}
}

/// TODO:: [document]
///
@safe @nogc nothrow
Spectrum UniformSampleOneLight(
    in CInteraction intx,
	Scene*          scene,
	IMemAlloc*      memArena,
	BaseSampler*    sampler,
	bool            handleMedia = false /* currently unsupported */ )
{
    Spectrum irradiance;
	
    const ulong numLights = scene.m_lights.length;
	if ( numLights == 0 ) { return irradiance; }

	const ulong lightIndex = Min( numLights - 1, cast(ulong) sampler.Get1D()*numLights );
	CLightCommon* light = scene.m_lights[ lightIndex ];

	vec2 uLight         = sampler.Get2D();
	vec2 uScattering    = sampler.Get2D();

    irradiance = cast(float)(numLights)*EstimateDirect(
	                                     intx,
										 uScattering, uLight,
										 light, scene,
										 sampler, memArena,
										 true /* handle spec */,
										 false /* handle media */ );
	
	
    return irradiance;
}

/// Power heuristic (hardcoded with exponent=2) for computing MIS weights
///
pure @safe @nogc nothrow
float PowerHeuristic(int nf, float fPdf, int ng, float gPdf) {
	float f = nf * fPdf, g = ng * gPdf;
	return (f * f) / (f * f + g * g);
}

/// TODO::[document]
///
@trusted @nogc nothrow
Spectrum EstimateDirect(
    in CInteraction refIntx,
	vec2            uScatter,
	vec2            uLight,
    CLightCommon*   light,
	Scene*          scene,
	BaseSampler*    sampler,
	IMemAlloc*      memArena,
	bool            handleSpecular = false,
	bool            handleMedia = false )
{
    Spectrum irradiance;
    const BxDFType bsdfFlags = handleSpecular ? BxDFType.All : BxDFType.AllNonSpecular;

    vec3  wi;
	float lightPdf;
	float scatterPdf;

	VisibilityTester visTester;
	Spectrum irradianceFromLight =
	    Light_SampleIrradiance( light, &refIntx, uLight, wi, lightPdf, visTester );
	
	if ( lightPdf > 0.0f && !irradianceFromLight.IsBlack() )
	{
	    Spectrum F;
		if ( refIntx.m_isSurfaceInteraction )
		{
		    auto surfIntx = cast( const(SurfaceInteraction)* )( &refIntx );
			F = surfIntx.m_bsdf.F( surfIntx.m_wo, wi, bsdfFlags ) * Abs( v_dot( wi, surfIntx.m_shading.n ));
			scatterPdf = surfIntx.m_bsdf.Pdf( surfIntx.m_wo, wi, bsdfFlags );
		}
		else
		{
		    //[TODO]:: [medium] interaction
			//
        }

		if ( !F.IsBlack() )
		{
		    if ( handleMedia )
			{
			    /// TODO:: [media][volumes][transmittance]
			}
			else if ( !visTester.Unoccluded(scene) )
			{
			    /// Path is obstructed, zero out irradiance from light
				irradianceFromLight = Spectrum(0.0f);
			}

			if (!irradianceFromLight.IsBlack())
			{
			     // TODO:: We don't handle delta lights here.... maybe we should?
                // if ( light.IsDeltaLight() )

				
				const float weight = PowerHeuristic( 1, lightPdf, 1, scatterPdf );
				irradiance += (weight/lightPdf)*F*irradianceFromLight;
			}
		}
	}

	/// Do BSDF Sampling and combine with MIS
	///
    if ( !light.IsDeltaLight() )
	{
        Spectrum F;
		bool sampledSpecularBxdf = false;

		if ( refIntx.m_isSurfaceInteraction )
		{
		    BxDFType sampledType;
			auto surfIntx = cast( const(SurfaceInteraction)* )( &refIntx );

			F = surfIntx.m_bsdf.Sample_F( surfIntx.m_wo, wi, uScatter, scatterPdf, bsdfFlags, &sampledType );
			F *= Abs(v_dot( wi, surfIntx.m_shading.n  ));
			sampledSpecularBxdf = (sampledType & BxDFType.Specular) != 0;
		}
		else
		{
		    //[TODO]:: [medium] interaction
			//
        }

		if ( !F.IsBlack() && scatterPdf > 0.0f )
		{
		    float weight = 1.0f;

			if ( !sampledSpecularBxdf )
			{
			    lightPdf = Light_SamplePdf( light, &refIntx, wi );
				if ( lightPdf == 0.0f ) { return irradiance; }

				weight = PowerHeuristic( 1, scatterPdf, 1, lightPdf );
			}

			/// [TODO]:: [medium][volume][transmittance] compute transmittance here
			///
			SurfaceInteraction lightSurfIntx;
			Ray ray = refIntx.CreateRay( wi );
			Spectrum transmittance = Spectrum( 1.0f );

			const bool foundSurfaceInteraction =
			    scene.FindClosestIntersection( &ray, lightSurfIntx );


			Spectrum lightIrradiance;
			if ( foundSurfaceInteraction )
			{
			    const vec3 wo = -1.0f*wi;
			    lightIrradiance = GetAreaLightEmission( lightSurfIntx, wo );
			}
			/// PBRT uses Light::Le() for this but my old renderer would return an empty spectrum...
			/// [NOTE] :: Investigate this
			// else
			// {
			//     lightIrradiance = light.CalculateEmission( 
			// }

			if ( !lightIrradiance.IsBlack() )
			{
			    irradiance += F*lightIrradiance*transmittance*(weight/scatterPdf);
			}
		}

	}
	
	
    return irradiance;
}
