import fwmath;
import spectrum;
import interactions;

extern(C) nothrow ubyte* stbi_load( char* filename, int* x, int* y, int* n, int desiredChannels =0 );

interface ITexture
{
	pure const @nogc @safe nothrow
	Spectrum Sample( CSurfaceInteraction* surfIntx );
}

class FlatColour : ITexture
{
	Spectrum m_colour;

	this( Spectrum colour )
	{
		m_colour = colour;
	}

	override pure const @nogc @safe nothrow
	Spectrum Sample( CSurfaceInteraction* surfIntx )
	{
		return m_colour;
	}
}

/**
 */
class ImageTexture : ITexture
{
	const(ubyte)* m_imageData;     /// A read-only, non-owning pointer to image data. One byte per channel.
	const uint   m_height;       
	const uint   m_width;
	const uint   m_numChannels;
	const bool   m_doGammaToLinearConversion = false;

	pure @nogc nothrow
	this( ubyte* imgDataPtr, uint imgHeight, uint imgWidth, uint numChannels, bool makeLinearSpace = false )
	{
		m_imageData = imgDataPtr;
		m_height    = imgHeight;
		m_width     = imgWidth;
		m_numChannels = numChannels;
		m_doGammaToLinearConversion = makeLinearSpace;
	}

	override pure const @nogc @trusted nothrow
	Spectrum Sample( CSurfaceInteraction* surfIntx )
	{
		vec3 color = vec3(0.0f);

	    if ( m_imageData )
		{
			import std.math;
			const(ubyte)* pData = m_imageData;
			const uint   ny    = m_height;
			const uint   nx    = m_width;
			const uint   nc    = Min( 3, m_numChannels ); /// Cap out at 3 channels (RGB)
			const vec2   uv    = surfIntx.m_uv;           /// UV coordinates!

			const int i = Clamp( cast(int)( uv[0]*nx ), 0, nx - 1 );
			const int j = Clamp( cast(int)( (1.0f - uv[1])*ny -0.001 ), 0, ny -1 );

			foreach ( c; 0..nc )
			{
			    float value = Clamp( cast(float)( pData[m_numChannels*(nx*j + i) + c]/255.0f ), 0.0f, 1.0f );
				if ( m_doGammaToLinearConversion ) {
					value = pow(value, 1.0/2.2 );
				}

				color[c] = value;
			}
		}
		else
		{
		    color = vec3( 0.9f, 0.0f, 0.9f ); /// if texture is missing, return magenta
		}
		
		return color;
	}
}



@trusted  
// bool LoadFromFile( ImageTexture imgTex, string filename )
ImageTexture ImageTexture_LoadFromFile( string filename, bool convertToLinearSpace = false )
{
    ImageTexture newTex;
	import std.stdio : writeln;
    // assert( imgTex is null, "LoadFromFile() | Making sure ImageTexture object is null before we load a new file into it " );

	int width, height, numComponents;
	ubyte* imageData = stbi_load( cast(char*) filename, &width, &height, &numComponents, 0 /* desired components */ );

	if ( imageData == null ) {
	    writeln("[ERROR] Couldn't load texture '", filename, "'");
	    // return false;
	}
	else {
		newTex = new ImageTexture( imageData, width, height, numComponents, convertToLinearSpace );
		writeln("Succesfully loaded texture file '", filename, "'" );
	}
	
    return newTex;
	// return true;
}

