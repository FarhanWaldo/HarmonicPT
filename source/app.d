import core.memory;
import std.stdio;
import std.algorithm;
import std.math;
import std.range;
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
	
    uint imageWidth 	= 640;
    uint imageHeight 	= 480;

    int tileSize = 64;
    float* pImageBufferData;
	ubyte* pDisplayBufferData;

	float whitepoint = 2.0f;
	
    // Create global memory allocator
    //
    ulong       stackSize = MegaBytes( 500 );
    void*       rootMemAllocAddress = CAlignedMalloc( stackSize, 16 );
    scope(exit) CAlignedFree( rootMemAllocAddress );
    // StackAlloc  rootMemAlloc = new StackAlloc( rootMemAllocAddress, stackSize );
    IMemAlloc  rootMemAlloc = new StackAlloc( rootMemAllocAddress, stackSize );
	immutable ulong geoStackSize = MegaBytes( 100 );
	BaseMemAlloc geoAlloc = new StackAlloc( cast(void*) rootMemAlloc.Allocate( geoStackSize ), geoStackSize );

    //
    // Set up Render and Display bufferss
    //

	//	Create an RGB (32 bits per channel) floating point render buffer
	//
    auto renderImage = ImageBuffer!float();
    auto imageInfoAlloca = ImageBuffer!float.alloca_t( imageWidth, imageHeight, 3 );
    ImageBuffer_Alloca( &renderImage, imageInfoAlloca, rootMemAlloc.Allocate( imageInfoAlloca.Size() ) );

	//	LDR (8 bits per channel) buffer for display
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
        //	Create LDR display buffer from HDR render buffer
        //
        foreach ( uint row; 0..imageHeight )
        {
            foreach ( uint col; 0..imageWidth )
            {
                uint pixelIndex = 3 * ( row * imageWidth + col );

                // F_TODO:: sqrt approximates linear -> gamme space conversion
                //
                pDisplayBufferData[ pixelIndex ] 		= cast(ubyte) ( sqrt( ( pImageBufferData[ pixelIndex ] / whitepoint ) ) * 255.0f );
                pDisplayBufferData[ pixelIndex  + 1 ] 	= cast(ubyte) ( sqrt( ( pImageBufferData[ pixelIndex + 1 ] / whitepoint ) ) * 255.0f );
                pDisplayBufferData[ pixelIndex  + 2 ] 	= cast(ubyte) ( sqrt( ( pImageBufferData[ pixelIndex + 2 ] / whitepoint ) ) * 255.0f );
            }
        }
    }

    void updateSdlDisplayBuffer() {
        SDL_BlitSurface( renderSurface, null, gScreenSurface, null );
        SDL_UpdateWindowSurface( p_sdlWindow );
    }


    //
    //  Scene Init
    //
	IMaterial* nullMtl = null;

	ShapeCommon* MakeSphere( vec3 centre, float radius )
	{
		return cast(ShapeCommon*) emplace( geoAlloc.Alloc!ShapeSphere(), centre, radius );
	}
	PrimCommon* MakeSurfacePrim( ShapeCommon* shp, IMaterial* mtl )
	{
 		return cast(PrimCommon*) emplace( geoAlloc.Alloc!SurfacePrim(), shp, mtl );
	}  

    // auto texRed = cast(ITexture*) emplace!FlatColour( geoAlloc.AllocClass!FlatColour, Spectrum( 1.0f, 0.0f, 0.0f ) );
	// auto texWhite = cast(ITexture*) emplace!FlatColour( geoAlloc.AllocClass!FlatColour, Spectrum( 1.0f ) );

	// auto lambertRed = cast(IMaterial*) emplace!MatteMaterial( geoAlloc.AllocClass!MatteMaterial, texRed );
	// auto lambertWhite = cast(IMaterial*) emplace!MatteMaterial( geoAlloc.AllocClass!MatteMaterial, texWhite );
    ITexture texRed = new FlatColour( Spectrum( 1.0f, 0.0f, 0.0f ) );
	ITexture texWhite = new FlatColour( Spectrum( 1.0f, 1.0f, 1.0f ) );

	IMaterial lambertRed = new MatteMaterial( &texRed );
	IMaterial lambertWhite = new MatteMaterial( &texWhite );
	
	auto sph0 = MakeSphere( vec3( 0.0f ), 1.0f );
	sph0.m_shapeType = EShape.Sphere;
	// auto prim0 = MakeSurfacePrim( sph0, lambertRed );
	auto prim0 = MakeSurfacePrim( sph0, &lambertRed );
	
	auto sph1 = MakeSphere( vec3( 0.0f, -1001.0f, 0.0f ), 1000.0f );
	sph1.m_shapeType = EShape.Sphere;
	// auto prim1 = MakeSurfacePrim( sph1, lambertWhite );
	auto prim1 = MakeSurfacePrim( sph1, &lambertWhite );

	import light;
	
    auto sph_lightGeo = MakeSphere( vec3( 0.0f, 10.0f, 0.0f ), 5.0f );
	auto sph_light = cast(LightCommon*) emplace( geoAlloc.Alloc!DiffuseAreaLight(), Spectrum( 10.0f ), sph_lightGeo, 10 );
	auto prim_light = cast(PrimCommon*) emplace( geoAlloc.Alloc!EmissiveSurfacePrim(), sph_lightGeo, nullMtl, sph_light );
	
	// auto 
	
	import datastructures;
	// auto prims = CreateBuffer!(PrimCommon*)( geoAlloc, 256 );
	auto primBuffer = BufferT!( PrimCommon*, 512 )();
	primBuffer.Push( prim0 );
	primBuffer.Push( prim1 );
	primBuffer.Push( prim_light );

	PrimArray primList = PrimArray( primBuffer.range() );
    Scene scene = Scene( primList, [ sph_light ] );       
	
    Camera renderCam;
    Camera_Init( renderCam,
                 vec3( 0.0f, 0.0f, -5.0f ) /* eyePos */,
                 vec3( 0.0f, 1.0f, 0.0f )  /* up */,
                 vec3( 0.0f, 0.0f, 0.0f ) /* lookAt */,
                 float(imageWidth)/float(imageHeight),
                 45.0f,
                 0.1, 10000.0f );

    // IIntegrator integrator = new HelloWorldIntegrator( renderCam, &renderImage );
    BaseSampler sampler = new PixelSampler( 32, 0, 4123123 /* random seed */ );
    // IIntegrator integrator = new SamplerIntegrator( &sampler, renderCam, &renderImage );
    // IIntegrator integrator = new WhittedIntegrator( &sampler, renderCam, &renderImage );
	immutable ulong renderMemArenaSizeBytes = MegaBytes( 10 );
	BaseMemAlloc integratorArena = new StackAlloc( cast(void*) rootMemAlloc.Allocate( renderMemArenaSizeBytes ), renderMemArenaSizeBytes );
	IIntegrator integrator = new DirectLightingIntegrator( &sampler, renderCam, &renderImage );
    integrator.Init( &scene, &integratorArena );

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
            }

            if ( !renderHasConverged )
            {
                writeln("Performing Render Progression # ", numProgressions, "" );

                renderHasConverged =
                    integrator.RenderProgression( &scene, &integratorArena );

                tonemap();
                updateSdlDisplayBuffer();

                ++numProgressions;

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
	}


    ImageBuffer_WriteToPng( &renderImage, cast(char*) "render.png" );
}
