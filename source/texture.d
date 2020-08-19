import fwmath;
import spectrum;

interface ITexture
{
	pure const @nogc @safe nothrow
	Spectrum Sample( vec2 uv, vec3 P );
}

class FlatColour : ITexture
{
	Spectrum m_colour;

	this( Spectrum colour )
	{
		m_colour = colour;
	}

	override pure const @nogc @safe nothrow
	Spectrum Sample( vec2 uv, vec3 P )
	{
		return m_colour;
	}
}
