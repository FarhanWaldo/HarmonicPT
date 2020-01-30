
import core.memory;
import std.stdio;
import std.algorithm;
import std.math;

import derelict.sdl2.sdl;

import fwmath;
import image;
import camera;
import memory;

import std.range;

void main( string[] args)
{
    // Disable the garbage collector
    GC.disable;
    writeln("hello world!");

    uint imageWidth 	= 640;
    uint imageHeight 	= 480;

	// Load the SDL 2 library. 
    DerelictSDL2.load();

	SDL_Window* p_sdlWindow = null;
    assert( SDL_Init( SDL_INIT_VIDEO ) >= 0, "[ERROR] Couldn't SDL_Init() failed." );

	p_sdlWindow = SDL_CreateWindow(
		"D-Harmonic PT",
		SDL_WINDOWPOS_UNDEFINED,
		SDL_WINDOWPOS_UNDEFINED,
		imageWidth,
		imageHeight,
		SDL_WINDOW_OPENGL
	);
    assert( p_sdlWindow != null, "[ERROR] SDL_CreateWindow failed" );

    Camera renderCam;
    Camera_Init( renderCam,
                 vec3( 0.0f, 0.0f, -1.0f ) /* eyePos */,
                 vec3( 0.0f, 1.0f, 0.0f )  /* up */,
                 vec3( 0.0f, 0.0f, 0.0f ) /* lookAt */,
                 float(imageWidth)/float(imageHeight),
                 45.0f,
                 0.1, 100000.0f );


    int tileSize = 64;
    float* pImageBufferData;
	ubyte* pDisplayBufferData;

	float whitepoint = 2.0f;
	
    // Create global memory allocator
    //
    ulong       stackSize = MegaBytes( 500 );
    void*       rootMemAllocAddress = CAlignedMalloc( stackSize, 16 );
    scope(exit) CAlignedFree( rootMemAllocAddress );
    StackAlloc  rootMemAlloc = new StackAlloc( rootMemAllocAddress, stackSize );

	//	Create an RGB (32 bits per channel) floating point render buffer
	//
    ImageBuffer!float renderImage = ImageBuffer!float ();
    ImageBuffer_Init!float( &renderImage, imageWidth, imageHeight, 3 /* RGB */, cast(BaseMemAlloc*) (&rootMemAlloc) );

	//	LDR (8 bits per channel) buffer for display
	//	
	ImageBuffer!ubyte displayImage = ImageBuffer!ubyte();
	ImageBuffer_Init( &displayImage, imageWidth, imageHeight, 3 /* RGB */, cast( BaseMemAlloc*) (&rootMemAlloc) );

    pImageBufferData = &renderImage.m_pixelData[ 0 ];
	pDisplayBufferData = &displayImage.m_pixelData[ 0 ];

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

            pImageBufferData[ pixelIndex     ] = r;
            pImageBufferData[ pixelIndex + 1 ] = g;
            pImageBufferData[ pixelIndex + 2 ] = b;
        }
    }

	//	Create LDR display buffer from HDR render buffer
	//
	foreach ( uint row; 0..imageHeight )
	{
		foreach ( uint col; 0..imageWidth )
		{
			uint pixelIndex = 3 * ( row * imageWidth + col );

			// F_TODO:: sqrt approximates linear -> gamme space conversion
			pDisplayBufferData[ pixelIndex ] 		= cast(ubyte) ( sqrt( ( pImageBufferData[ pixelIndex ] / whitepoint ) ) * 255.0f );
			pDisplayBufferData[ pixelIndex  + 1 ] 	= cast(ubyte) ( sqrt( ( pImageBufferData[ pixelIndex + 1 ] / whitepoint ) ) * 255.0f );
			pDisplayBufferData[ pixelIndex  + 2 ] 	= cast(ubyte) ( sqrt( ( pImageBufferData[ pixelIndex + 2 ] / whitepoint ) ) * 255.0f );
		}
	}

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

	SDL_BlitSurface( renderSurface, null, gScreenSurface, null );
	SDL_UpdateWindowSurface( p_sdlWindow );


	SDL_Event e;
    bool quit = false;
    size_t numProgressions = 0u;
    while ( !quit )
    {
        while ( SDL_PollEvent( &e ) )
        {
            if ( e.type == SDL_QUIT )
            {
                quit = true;
            }
            // if (e.type == SDL_KEYDOWN){
            //     quit = true;
            // }
            // if (e.type == SDL_MOUSEBUTTONDOWN){
            //     quit = true;
            // }
        }


	}

    // Close and destroy the window
    //
    SDL_DestroyWindow( p_sdlWindow );

    // Clean up
    //
    SDL_Quit();

    ImageBuffer_WriteToPng( &renderImage, cast(char*) "render.png" );
}