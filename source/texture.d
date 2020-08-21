import fwmath;
import spectrum;
import interactions;

extern(C) byte* stbi_load( char* filename, int x, int y, int n, int desiredChannels =0 );

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
	const(byte)* m_imageData;
	const uint   m_height;
	const uint   m_width;
	const uint   m_numChannels;

	this( byte* imgDataPtr, uint imgHeight, uint imgWidth, uint numChannels )
	{
		assert( imgDataPtr != null, "Image texture being created with null imgDataPtr" );
		
		m_imageData = imgDataPtr;
		m_height    = imgHeight;
		m_width     = imgWidth;
		m_numChannels = numChannels;
	}

	override pure const @nogc @trusted nothrow
	Spectrum Sample( CSurfaceInteraction* surfIntx )
	{
		vec3 color = vec3(0.0f);

        /*
            byte* pData     = m_imgData;
            int nx          = m_imgWidth;
            int ny          = m_imgHeight;

            int i = uv.u * nx;
            int j = (1.0f - uv.v) * ny - 0.001;
            CLAMP_VAR( i, 0, nx - 1);
            CLAMP_VAR( j, 0, ny - 1 );


            float r = int(pData[3 * i + 3 * nx*j]) / 255.0;
            float g = int(pData[3 * i + 3 * nx*j + 1]) / 255.0;
            float b = int(pData[3 * i + 3 * nx*j + 2]) / 255.0;

            r = pow( r, 1.0/2.2 );
            g = pow( g, 1.0/2.2 );
            b = pow( b, 1.0/2.2 );

            colour = { r, g, b };
		 */

        const(byte)* pData = m_imageData;
		const uint   ny    = m_height;
		const uint   nx    = m_width;
		const uint   nc    = Min( 3, m_numChannels ); /// Cap out at 3 channels (RGB)
		const vec2   uv    = surfIntx.m_uv;           /// UV coordinates!

		const int i = Clamp( cast(int)( uv[0]*nx ), 0, nx - 1 );
		const int j = Clamp( cast(int)( (1.0f - uv[1])*ny -0.001 ), 0, ny -1 );

		foreach ( c; 0..nc )
		{
		    color.data[c] = Min( 1.0f, cast(float)( pData[nc*nx*j + nc*i + c]/255.0f ) );
		}
		
		return color;
	}
}
