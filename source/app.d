import core.memory;
import std.stdio;
import std.algorithm;
import std.math;
import std.range;
import std.parallelism;
import std.conv : emplace;

import derelict.sdl2.sdl;

import fwmath;
import image;
import camera;
import memory;
import scene;
import integrator;
import shape;
import sampling;
import material;
import spectrum;
import texture;


void main( string[] args)
{
    // Disable the garbage collector
    // GC.disable;
    immutable uint numCPUs = totalCPUs;
    writeln( "Number of CPUs = ", numCPUs );

    uint imageWidth     = 640;
    uint imageHeight    = 480;
    // uint imageWidth = 1920;
    // uint imageHeight = 1080;
    
    int tileSize = 64;
    float* pImageBufferData;
    ubyte* pDisplayBufferData;

    float whitepoint = 1.0f;
    
    // Create global memory allocator
    //
    ulong       stackSize = MegaBytes( 1000 );
    void*       rootMemAllocAddress = CAlignedMalloc( stackSize, 16 );
    scope(exit) CAlignedFree( rootMemAllocAddress );
    
    IMemAlloc  rootMemAlloc = new StackAlloc( rootMemAllocAddress, stackSize );
    immutable ulong geoStackSize = MegaBytes( 300 );
    BaseMemAlloc geoAlloc = new StackAlloc( rootMemAlloc.Allocate( geoStackSize ) );

    //
    // Set up Render and Display bufferss
    //

    //  Create an RGB (32 bits per channel) floating point render buffer
    //
    auto renderImage = ImageBuffer!float();
    auto imageInfoAlloca = ImageBuffer!float.alloca_t( imageWidth, imageHeight, 3 );
    ImageBuffer_Alloca( &renderImage, imageInfoAlloca, rootMemAlloc.Allocate( imageInfoAlloca.Size() ) );

    //  LDR (8 bits per channel) buffer for display
    //  
    auto displayImage = ImageBuffer!ubyte();
    auto displayImageAlloca = ImageBuffer!ubyte.alloca_t( imageWidth, imageHeight, 3 );
    ImageBuffer_Alloca( &displayImage, displayImageAlloca, rootMemAlloc.Allocate( displayImageAlloca.Size() ) );

    pImageBufferData = &renderImage.m_pixelData[ 0 ];
    pDisplayBufferData = &displayImage.m_pixelData[ 0 ];

    //
    //  SDL2 Setup
    //

    // Load the SDL 2 library. 
    DerelictSDL2.load();

    SDL_Window* p_sdlWindow = null;
    assert( SDL_Init( SDL_INIT_VIDEO ) >= 0, "[ERROR] Couldn't SDL_Init() failed." );
    scope(exit) SDL_Quit();

    p_sdlWindow = SDL_CreateWindow(
        "Harmonic PT",
        SDL_WINDOWPOS_UNDEFINED,
        SDL_WINDOWPOS_UNDEFINED,
        imageWidth,
        imageHeight,
        SDL_WINDOW_OPENGL
    );
    assert( p_sdlWindow != null, "[ERROR] SDL_CreateWindow failed" );
    scope(exit) SDL_DestroyWindow( p_sdlWindow );

    // Set up the pixel format color masks for RGB(A) byte arrays.
    // Only STBI_rgb (3) and STBI_rgb_alpha (4) are supported here!
    uint rmask, gmask, bmask, amask;
    // // #if SDL_BYTEORDER == SDL_BIG_ENDIAN
    //     int shift = (req_format == STBI_rgb) ? 8 : 0;
    //     rmask = 0xff000000 >> shift;
    //     gmask = 0x00ff0000 >> shift;
    //     bmask = 0x0000ff00 >> shift;
    //     amask = 0x000000ff >> shift;
    // #else // little endian, like x86
    rmask = 0x000000ff;
    gmask = 0x0000ff00;
    bmask = 0x00ff0000;
    amask = 0; //(req_format == STBI_rgb) ? 0 : 0xff000000;
    // #endif

    SDL_Surface* renderSurface = SDL_CreateRGBSurfaceFrom(
                                    // pImageBufferData,
                                    pDisplayBufferData,
                                    imageWidth,
                                    imageHeight,
                                    24 /* bits per pixel */,
                                    imageWidth * 3 /* bytes per row */,
                                    rmask, gmask, bmask, amask );

    assert( renderSurface != null, "[ERROR] SDL_CreateRGBSurfaceFrom() returned an invalid surface.");

    //The surface contained by the window
    SDL_Surface* gScreenSurface = null;
    //Get window surface
    gScreenSurface = SDL_GetWindowSurface( p_sdlWindow );

    SDL_Event   e;
    bool        quit = false;
    size_t      numProgressions = 0u;
    bool        renderHasConverged = false;

    void tonemap() {
        
        import std.math : pow;
        import std.range : iota;
        import std.parallelism;
        
        //  Create LDR display buffer from HDR render buffer
        //
        const float invNumProgressions = 1.0f/(cast(float) numProgressions);

        auto pixelIter = iota( imageWidth*imageHeight );
        foreach( i; taskPool.parallel(pixelIter) )
        {
            const uint pixelIndex = i*3;

            ubyte floatToUbyte( float v ) {
                return cast(ubyte) Min( 255, 255.0f*pow( invNumProgressions*v/whitepoint, 2.2f ));
            }

            pDisplayBufferData[ pixelIndex ]   = floatToUbyte( pImageBufferData[ pixelIndex ] );
            pDisplayBufferData[ pixelIndex+1 ] = floatToUbyte( pImageBufferData[ pixelIndex+1 ] );
            pDisplayBufferData[ pixelIndex+2 ] = floatToUbyte( pImageBufferData[ pixelIndex+2 ] );              
        }
    }

    void updateSdlDisplayBuffer() {
        SDL_BlitSurface( renderSurface, null, gScreenSurface, null );
        SDL_UpdateWindowSurface( p_sdlWindow );
    }


    //
    //  Scene Init
    //
    import datastructures;
    auto primBuffer = BufferT!( PrimCommon*, 512 )();

    IMaterial* nullMtl = null;

    ShapeCommon* MakeSphere( vec3 centre, float radius )
    {
        return cast(ShapeCommon*) AllocInstance!ShapeSphere( geoAlloc, centre, radius );
    }
    PrimCommon* MakeSurfacePrim( ShapeCommon* shp, IMaterial* mtl )
    {
        return cast(PrimCommon*) geoAlloc.AllocInstance!SurfacePrim( shp, mtl );
    }  

    void MakeSphereSurfacePrim( vec3 centre, float radius, IMaterial* mtl )
    {
        auto sph = MakeSphere( centre, radius );
        auto prim = MakeSurfacePrim( sph, mtl );
        primBuffer.Push( prim );
    }
    
    ITexture texRed   = new FlatColour( Spectrum( 0.8f, 0.0f, 0.0f ) );
    ITexture texGreen = new FlatColour( Spectrum( 0.0f, 0.8f, 0.0f ) );
    ITexture texBlue  = new FlatColour( Spectrum( 0.0f, 0.0f, 0.8f ) );
    ITexture texWhite = new FlatColour( Spectrum( 0.8f, 0.8f, 0.8f ) );
    ITexture texImgBrickWall = ImageTexture_LoadFromFile( "assets/brick_wall.jpg", true /* do linear space conversion*/ );
    ITexture texConst  = new FlatColour( vec3( 0.3f ));
    
    IMaterial lambertRed       = *geoAlloc.AllocInstance!MatteMaterial( &texRed );
    IMaterial lambertGreen     = *geoAlloc.AllocInstance!MatteMaterial( &texGreen );
    IMaterial lambertBlue      = *geoAlloc.AllocInstance!MatteMaterial( &texBlue );
    IMaterial lambertWhite     = *geoAlloc.AllocInstance!MatteMaterial( &texWhite ); 
    IMaterial brickWallAlbedo  = *geoAlloc.AllocInstance!MatteMaterial( &texImgBrickWall );
    IMaterial fresnelSpecMtl   = *geoAlloc.AllocInstance!FresnelSpecMaterial( &texWhite, 1.0f, 1.7f );
    IMaterial plasticMtl       = *geoAlloc.AllocInstance!PlasticMaterial( &texGreen, &texWhite, &texConst, true /* remap roughness */ );
    
    // MakeSphereSurfacePrim( vec3( 0.0f, 1.0f, 4.5f ), 2.0f, &brickWallAlbedo );
    MakeSphereSurfacePrim( vec3( 0.0f, 1.0f, 4.5f ), 2.0f, &plasticMtl );
    MakeSphereSurfacePrim( vec3( 0.0f, 0.0f, -1.0f ), 1.0f, &fresnelSpecMtl );
    // MakeSphereSurfacePrim( vec3( 0.0f, 0.0f, -1.0f ), 1.0f, &plasticMtl );
    MakeSphereSurfacePrim( vec3( 0.0f, -301.0f, 0.0f ), 300.0f, &lambertWhite );     /// Floor
    MakeSphereSurfacePrim( vec3( -306.0f, 0.0f, 0.0f ), 300.0f, &lambertWhite /*Red*/ );       /// left wall
    MakeSphereSurfacePrim( vec3( 306.0f, 0.0f, 0.0f ),  300.0f, &lambertWhite /*blue*/  );      /// right wall
    MakeSphereSurfacePrim( vec3( 0.0f, 0.0f, 310.0f ),  300.0f, &lambertGreen );     /// back wall
    
    // auto sph1 = MakeSphere( vec3( 0.0f, -601.0f, 0.0f ), 600.0f ); /// F_TODO:: Missing intersections at top of sphere once r >= 500
    // auto prim1 = MakeSurfacePrim( sph1, &lambertWhite );

    import light;   
    auto sph_lightGeo = MakeSphere( vec3( 0.0f, 8.0f, -1.0f ), 3.0f );
    auto sph_light = cast(LightCommon*) geoAlloc.AllocInstance!DiffuseAreaLight( Spectrum(2.0f, 2.0f, 2.0f), sph_lightGeo, 10 /* num samples */ );
    auto prim_light = cast(PrimCommon*) geoAlloc.AllocInstance!EmissiveSurfacePrim( sph_lightGeo, nullMtl, sph_light );
    primBuffer.Push( prim_light );
    
    const ulong numPrims = primBuffer.GetCount();
    PrimArray primList = PrimArray( primBuffer[0..numPrims] );
    Scene scene = Scene( primList, [ sph_light ] );       
    
    Camera renderCam;
    Camera_Init( renderCam,
                 vec3( -0.5f, 1.5f, -7.0f ) /* eyePos */,
                 vec3( 0.0f, 1.0f, 0.0f )  /* up */,
                 vec3( 0.0f, 0.0f, 0.0f ) /* lookAt */,
                 float(imageWidth)/float(imageHeight),
                 45.0f,
                 0.1, 10000.0f );

    
    BaseSampler sampler = new PixelSampler( 32, 0, 43123 /* random seed */ );
    // IIntegrator integrator = new DirectLightingIntegrator( &sampler, renderCam, &renderImage, numCPUs );
    IIntegrator integrator = new PathTracingIntegrator( &sampler, renderCam, &renderImage, numCPUs );
    integrator.Init( &scene, &rootMemAlloc );

    //
    //  Event/Render loop
    //
    while ( !quit )
    {
        while ( SDL_PollEvent( &e ) )
        {
            if ( e.type == SDL_QUIT )
            {
                quit = true;
                break;
            }

            // TODO:: Hook up keys to drive things like exposure values for tonemapping
            //
            // if (e.type == SDL_KEYDOWN){
            //     quit = true;
            // }
            // if (e.type == SDL_MOUSEBUTTONDOWN){
            //     quit = true;
            // }
        }
        
        if ( !renderHasConverged )
        {
            // writeln("Performing Render Progression # ", numProgressions, "" );
            write("Performing render progression ", numProgressions+1, "\r");

            renderHasConverged = integrator.RenderProgression( &scene );
            ++numProgressions;
            
            tonemap();
            updateSdlDisplayBuffer();
        }

    }

    writeln("\nRender is finished!\n");
    ImageBuffer_WriteToPng( &displayImage, cast(char*) "render.png" );
}
