import scene;
import camera;
import memory;
import image;
import sampling;
import fwmath;
import interactions;
import spectrum;

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

    this( BaseSampler* sampler, Camera cam, Image_F32* renderBuffer, LightingStrategy lightingStrategy )
	{
		super( sampler, cam, renderBuffer, 1 /* max bounces */ );
		m_lightingStrategy = lightingStrategy;
	}
	
	override Spectrum
	Irradiance( in Ray ray, Scene* scene, BaseSampler* sampler, IMemAlloc* memArena, int depth = 0 )
	{
		Spectrum radiance;

        SurfaceInteraction surfIntx;
		if ( scene.FindClosestIntersection( &ray, surfIntx ) )
		{
		    
		}
		
		return radiance;
	}
}
