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

