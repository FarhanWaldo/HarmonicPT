import std.parallelism;

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

enum IntegratorType
{
    DirectLighting,
    PathTracing
}

abstract class IIntegrator
{
    void Init( in Scene* scene,  IMemAlloc* memArena );

    /**
        Performs up to #numProgressions rendering progressions

        Returns: returns whether rendering has converged
    */
    bool RenderProgression( Scene* scene, int numProgressions = 1 );
}

abstract class SamplerIntegrator : IIntegrator
{
    struct FilmTile
    {
        uint m_topLeftX;
        uint m_topLeftY;

        uint m_tileWidth;
        uint m_tileHeight;

        uint m_imgWidth;
        uint m_imgHeight;


        this( uint topLeftX, uint topLeftY,
              uint tileWidth, uint tileHeight,
              uint imgWidth, uint imgHeight )
        {
            m_topLeftX     = topLeftX;
            m_topLeftY     = topLeftY;
            m_tileWidth    = tileWidth;
            m_tileHeight   = tileHeight;
            m_imgWidth     = imgWidth;
            m_imgHeight    = imgHeight;
        }
    }

    
    BaseSampler*    m_sampler;
	Camera          m_camera;
	Image_F32*      m_renderBuffer;
	const uint      m_maxBounces;
	
	uint            m_finishedProgressions = 0;
	const uint      m_maxProgressions;
	
	const uint      m_numThreads;
	const ulong     m_perThreadArenaSizeBytes;
    BaseMemAlloc[]  m_perThreadArena;
	BaseSampler[]   m_perThreadSampler;
	

    this( BaseSampler* sampler,
		  Camera cam,
		  Image_F32* renderBuffer,
		  uint numThreads,
		  uint maxProgressions = 128,
		  uint maxBounces = 6,
		  ulong perThreadArenaSizeBytes = MegaBytes(4))
    {
        m_sampler         = sampler;
        m_camera          = cam;
        m_renderBuffer    = renderBuffer;
        m_maxBounces      = maxBounces;
		m_maxProgressions = maxProgressions;
		m_numThreads      = numThreads;
		m_perThreadArenaSizeBytes = perThreadArenaSizeBytes;
    }

    /**
        Pure virtual; sub-classed integrators can implement this function to compute irradiance along a ray,
        which will get invoked by RenderProgression here as required to generate the image.
     */
    Spectrum
    Irradiance(
        in  Ray      ray,
        Scene*          scene,
        BaseSampler*    sampler,
        IMemAlloc*      memArena,
        int             depth = 0 );

    
    override void
    Init( in Scene* scene, IMemAlloc* memArena )
    {
		/// Set up per thread memory arenas
		///
		const auto memSize = m_perThreadArenaSizeBytes;
		foreach( i; 0..m_numThreads )
		{
			m_perThreadArena ~= new StackAlloc( memArena.Allocate(memSize) );
		}

		/// Set up per thread samplers
		///
		import std.random;
		foreach( i; 0..m_numThreads )
		{
		    m_perThreadSampler ~= m_sampler.Clone( unpredictableSeed() );
		}
    }

    override bool
    RenderProgression( Scene* scene, int numProgressions = 1 )
    {
        const uint imageWidth = m_renderBuffer.m_imageWidth;
        const uint imageHeight = m_renderBuffer.m_imageHeight;
        const vec2 cameraDims  = vec2( cast(float) imageWidth, cast(float) imageHeight );

        float[] renderBuffer = m_renderBuffer.m_pixelData;

		FilmTile[] imageTiles;
		const uint tileSizeX = 64;
		const uint tileSizeY = 64;

		const uint numTilesX = imageWidth/tileSizeX;
		const uint numTilesY = imageHeight/tileSizeY;

		foreach ( tileId_y; 0..numTilesY+1 ) {
			foreach ( tileId_x; 0..numTilesX ) {
				const uint topLeftX = Min( tileId_x*tileSizeX, imageWidth - 1 );
				const uint topLeftY = Min( tileId_y*tileSizeY, imageHeight -1 );

				const uint width = Min( tileSizeX, imageWidth - topLeftX );
				const uint height = Min( tileSizeY, imageHeight - topLeftY );

				imageTiles ~= FilmTile( topLeftX, topLeftY, width, height, imageWidth, imageHeight ); 
			}
		}

		// import std.stdio;
		// foreach (taskCounter, ref tile; taskPool.parallel( imageTiles ))
		ulong tilesPerThread = imageTiles.length/m_numThreads;
		foreach (taskCounter, ref tile; taskPool.parallel( imageTiles, tilesPerThread ))
		{
			const auto threadId = taskPool.workerIndex;

			foreach (y; 0..tile.m_tileHeight ) {
				foreach( x; 0..tile.m_tileWidth ) {

					const ulong pixelIndex = (tile.m_topLeftY + y)*imageWidth + tile.m_topLeftX + x;

					const ulong j = pixelIndex / imageWidth; // current row
					const ulong i = pixelIndex - j*imageWidth; // current column

					Spectrum pixelColour = Spectrum(0.0);
					foreach ( progression; 0 .. numProgressions )
					{
						m_perThreadArena[threadId].Reset();
						const vec2 pixelPos = vec2( cast(float) i, cast(float) j );
						const vec2 jitteredPos = pixelPos + m_sampler.Get2D();

						Ray cameraRay;
						m_camera.SpawnRay( jitteredPos, cameraDims, cameraRay );

						pixelColour += Irradiance( cameraRay, scene, &m_perThreadSampler[threadId] , &m_perThreadArena[threadId] );
					}

					const float ir = pixelColour.r;
					const float ig = pixelColour.g;
					const float ib = pixelColour.b;

					const ulong baseIndex            = pixelIndex * 3;
					renderBuffer[ baseIndex ]       += ir;
					renderBuffer[ baseIndex + 1 ]   += ig;
					renderBuffer[ baseIndex + 2 ]   += ib;

				}
			}
		}

		m_finishedProgressions += numProgressions;
		
		const bool renderFinished = m_finishedProgressions >= m_maxProgressions;
		return renderFinished;
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

    this( BaseSampler* sampler,
	      Camera cam,
		  Image_F32* renderBuffer,
		  uint numThreads,
		  uint maxProgressions = 64,
		  LightingStrategy lightingStrategy=LightingStrategy.UniformSampleOne,
		  ulong perThreadArenaSize = MegaBytes(1))
	{
		super( sampler, cam, renderBuffer, numThreads, maxProgressions, 1 /* max bounces */, perThreadArenaSize );
		m_lightingStrategy = lightingStrategy;
	}
	
	override final Spectrum
	Irradiance( in Ray ray, Scene* scene, BaseSampler* sampler, IMemAlloc* memArena, int depth = 0 )
	{
		Spectrum radiance = Spectrum(0.0f);

        SurfaceInteraction surfIntx;
		if ( scene.FindClosestIntersection( &ray, surfIntx ) )
		{
		    if ( surfIntx.m_material != null )
			{
                ComputeScatteringFunctions( &surfIntx, memArena, true /* from eyes */, true /* allow multiple lobes */ );
            }
			
			vec3 wo = surfIntx.m_wo;
			radiance += surfIntx.GetAreaLightEmission( wo );

			// // DEBUG::  display surface normal in world space [-1,1]^3 -> [0,1]^3
		    // const vec3 surfaceN = v_normalise( surfIntx.m_normal );
			// const vec3 colourN = vec3(0.5f) + 0.5f*surfaceN;
			// radiance = colourN;

			if ( m_lightingStrategy == LightingStrategy.UniformSampleAll )
			{
			    // TODO:: what are ya doin' mate
				assert( false, "UniformSampleAll lighting strategy is not supported in the DirectLightingIntegrator" );
			}
			else
			{
			    radiance += UniformSampleOneLight( cast(CInteraction*) &surfIntx, scene, memArena, sampler );
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

class PathTracingIntegrator : SamplerIntegrator
{
	this( BaseSampler* sampler,
		  Camera       cam,
		  Image_F32*   renderBuffer,
		  uint         numThreads,
		  uint         maxProgressions = 512,
		  uint         maxBounces      = 6,
		  ulong        perThreadArenaSize = MegaBytes(2) )
	{
		super( sampler, cam, renderBuffer, numThreads, maxProgressions, maxBounces, perThreadArenaSize );
	}

	override final Spectrum
	Irradiance( in Ray _ray, Scene* scene, BaseSampler* sampler, IMemAlloc* memArena, int depth = 0 )
	{
	    Spectrum irradiance = Spectrum( 0.0f );
		Spectrum throughput = Spectrum( 1.0f );

        bool specularBounce = false;
		
		Ray ray = _ray;
		for ( int bounce = 0;; ++bounce )
		{
			memArena.Reset();
		    SurfaceInteraction surfIntx;
			const bool foundIntersection = scene.FindClosestIntersection( &ray, surfIntx );

			vec3 wo = surfIntx.m_wo;

			if ( bounce == 0 && foundIntersection )
			{
			    irradiance += surfIntx.GetAreaLightEmission( wo );
			}
			if ( !foundIntersection || bounce >= m_maxBounces )
			{
			    break;
			}

			ComputeScatteringFunctions( &surfIntx, memArena, true /* from eyes */, true /* allow multiples lobes */ );

			///  The renderer can use geometric primitives that don't create a valid BSDF in the surface interaction to represent geometry
			///    that's meant for creating boundaries between things. For example, the hull of a participating medium
			///
			if ( !surfIntx.m_bsdf )
			{
    			/// F_TODO:: CHeck if this is a light, if so, return, and renable the commented code below
				break;
			    // ray = surfIntx.CreateRay( ray.m_dir );
				// bounce--;
				// continue;
			}
 
			///  Accumulate irradiance from direct lighting
			///
			irradiance += throughput*UniformSampleOneLight( cast(CInteraction*) &surfIntx, scene, memArena, sampler );

            ///  Now sample the BSDF for the next ray direction
			///
			vec3 wi   = vec3(0.0f);
			float pdf = 0.0f;
			BxDFType flags;
			Spectrum F = surfIntx.m_bsdf.Sample_F( wo, wi, sampler.Get2D(), pdf, BxDFType_All, &flags );

			if ( F.IsBlack() || pdf == 0.0f )
			{
			    break;
			}

			specularBounce = IsSpecular( flags );
			
			///  Update throughput of the path for the next bounce
			///
			throughput = throughput*F*Abs( v_dot(wi,surfIntx.m_shading.n) )/pdf;

			ray = surfIntx.CreateRay( wi );

			/// Employ russian roulette after the 4th bounce
			///
			if ( bounce > 4 )
			{
			    const float p = (throughput.x + throughput.y + throughput.z) / 3.0f;
			    const float q = Max( 0.05f, 1.0f - p );

				if ( sampler.Get1D() < q )
				{
				    break;
				}

				throughput *= 1.0f/(1.0f - q);
			}
		}
		
		return irradiance;
	}
}

/// TODO:: [document]
///
@safe @nogc nothrow
Spectrum UniformSampleOneLight(
    CInteraction*   intx,
	Scene*          scene,
	IMemAlloc*      memArena,
	BaseSampler*    sampler,
	bool            handleMedia = false /* currently unsupported */ )
{
    Spectrum irradiance = Spectrum(0.0f);
	
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
    CInteraction*   refIntx,
	vec2            uScatter,
	vec2            uLight,
    CLightCommon*   light,
	Scene*          scene,
	BaseSampler*    sampler,
	IMemAlloc*      memArena,
	bool            handleSpecular = false,
	bool            handleMedia = false )
{
    Spectrum irradiance = Spectrum(0.0f);
    const BxDFType bsdfFlags = handleSpecular ? BxDFType_All : BxDFType_AllNonSpecular;

    vec3  wi = vec3(0.0f);
	float lightPdf = 0.0f;
	float scatterPdf = 0.0f;

	VisibilityTester visTester;
	Spectrum irradianceFromLight =
	    Light_SampleIrradiance( light, refIntx, uLight, wi, lightPdf, visTester );
	
	if ( lightPdf > 0.0f && !irradianceFromLight.IsBlack() )
	{
	    Spectrum F = Spectrum(0.0f);
		if ( refIntx.m_isSurfaceInteraction )
		{
			auto surfIntx = cast( const(SurfaceInteraction)* )( refIntx );
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
        Spectrum F = Spectrum(0.0f);
		bool sampledSpecularBxdf = false;

		if ( refIntx.m_isSurfaceInteraction )
		{
		    BxDFType sampledType;
			auto surfIntx = cast( const(SurfaceInteraction)* )( refIntx );

			if ( surfIntx.m_bsdf != null )
			{
				F = surfIntx.m_bsdf.Sample_F( surfIntx.m_wo, wi, uScatter, scatterPdf, bsdfFlags, &sampledType );
				F *= Abs(v_dot( wi, surfIntx.m_shading.n  ));
				sampledSpecularBxdf = (sampledType & BxDFType_Specular) == BxDFType_Specular;
			}
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
			    lightPdf = Light_SamplePdf( light, refIntx, wi );
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


			Spectrum lightIrradiance = Spectrum(0.0f); 
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
