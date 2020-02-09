import scene;
import camera;
import memory;
import image;


interface IIntegrator
{
    void Init( in Scene* scene,  IMemAlloc* memArena );

    /**
        Performs up to #numProgressions rendering progressions

        Returns: returns whether rendering has converged
    */
    bool RenderProgression( in Scene* scene, IMemAlloc* memArena, int numProgressions = 1 );
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
    RenderProgression( in Scene* scene, IMemAlloc* memArena, int numProgressions = 1 )
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