
import core.memory;
import std.stdio;
import std.algorithm;
import std.math;

import derelict.sdl2.sdl;

import fwmath;
import image;
import camera;


void main( string[] args)
{
	// Load the SDL 2 library. 
    DerelictSDL2.load();


	writeln("Loaded the derelict-sdl2 bindings!");
 
    // Disable the garbage collector
    GC.disable;

    writeln("hello world!");

    Camera renderCam;
    Camera_Init( renderCam,
                 vec3( 0.0f, 0.0f, -1.0f ) /* eyePos */,
                 vec3( 0.0f, 1.0f, 0.0f )  /* up */,
                 vec3( 0.0f, 0.0f, 0.0f ) /* lookAt */ );

    uint imageWidth = 1920;
    uint imageHeight = 1080;
    int tileSize = 64;
    float* pImageBufferData;
    
    ImageBuffer renderImage = ImageBuffer();
    ImageBuffer_Init( &renderImage, imageWidth, imageHeight, 3 /* RGB */ );

    pImageBufferData = &renderImage.pixelData[0];
    for ( uint row = 0; row < imageHeight; ++row )
    {
        for ( uint col = 0; col < imageWidth; ++col )
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

    ImageBuffer_WriteToPng( &renderImage, cast(char*) "render.png" );
}