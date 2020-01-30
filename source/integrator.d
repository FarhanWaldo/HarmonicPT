import scene;
import camera;
import memory;
import image;


interface IIntegrator
{
    pure void Init( in Scene* scene,  IMemAlloc* memArena );
    pure void Render( in Scene* scene, IMemAlloc* memArena );
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

    override pure void
    Init( in Scene* scene, IMemAlloc* memArena )
    {
        // writeln( "HelloWorldIntegrator::Init()!");
    }

    override pure void
    Render( in Scene* scene, IMemAlloc* memArena )
    {
        // writeln( "HelloWorldIntegrator::Render()!");
    }
}

// TODO:: Finish implementing
//
// class SamplerIntegrator : IIntegrator
// {
//     override pure void
//     Init( in Scene* scene, IMemAlloc* memArena )
//     {
//         writeln( "SamplerIntegrator::Init()!");
//     }

//     override pure void
//     Render( in Scene* scene, IMemAlloc* memArena )
//     {
//         writeln( "SamplerIntegrator::Render()!");
//     }

// }