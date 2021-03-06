import fwmath;
import spectrum;
import interactions;

extern(C) nothrow ubyte* stbi_load( char* filename, int* x, int* y, int* n, int desiredChannels =0 );

// interface ITexture
abstract class ITexture
{
	pure const @nogc @safe nothrow
	vec4 Sample( CSurfaceInteraction* surfIntx );
}

class FlatColour : ITexture
{
    vec3 m_colour;

	this( vec3 colour )
	{
		m_colour = colour;
	}

	override pure const @nogc @safe nothrow
	vec4 Sample( CSurfaceInteraction* surfIntx )
	{
		return vec4( m_colour.r, m_colour.g, m_colour.b, 0.0f );
	}
}

enum ImageFormat 
{
    Invalid = 0,

    /// The type of the channel and the number of channels
    ///
    
    Byte,
    Byte2,
    Byte3,
    Byte4,

    Float,
    Float2,
    Float3,
    Float4
}

enum ChannelType
{
    Invalid,
    Byte,
    Float
}

pure @nogc @safe nothrow
ChannelType GetChannelType( ImageFormat format )
{
    if ((format <= ImageFormat.Byte4) && (format >= ImageFormat.Byte))
        return ChannelType.Byte;
    else if ((format <= ImageFormat.Float4) && (format >= ImageFormat.Float))
        return ChannelType.Float;
    else
        return ChannelType.Invalid;
}

pure @nogc @safe nothrow
ulong GetChannelSizeInBytes( ImageFormat format )
{
    if ((format <= ImageFormat.Byte4) && (format >= ImageFormat.Byte))
        return 1;
    else if ((format <= ImageFormat.Float4) && (format >= ImageFormat.Float))
        return 4;
    else
        return 0;
}


/**
 */
class ImageTexture : ITexture
{
	const(ubyte)*      m_imageData;     /// A read-only, non-owning pointer to image data. One byte per channel.
	const uint         m_height;       
	const uint         m_width;

    const ImageFormat  m_format;
    const uint         m_numChannels;
    const ChannelType  m_channelType;
    const ulong        m_channelSizeInBytes;
    
	pure @nogc nothrow
	this( ubyte* imgDataPtr, uint imgHeight, uint imgWidth, uint numChannels, ImageFormat format )
	{
		m_imageData = imgDataPtr;
		m_height    = imgHeight;
		m_width     = imgWidth;
		m_numChannels = numChannels;

        m_format = format;
        m_channelType = GetChannelType( format );
        m_channelSizeInBytes = GetChannelSizeInBytes( format );
	}

	override pure const @nogc @trusted nothrow
	vec4 Sample( CSurfaceInteraction* surfIntx )
	{
		vec4 color = vec4(0.0f);

	    if ( m_imageData )
		{
			import std.math;
			const(ubyte)* pData = m_imageData;
			const uint   ny    = m_height;
			const uint   nx    = m_width;
			const uint   nc    = Min( 4, m_numChannels ); /// Cap out at 4 channels (RGBA)
			const vec2   uv    = surfIntx.m_uv;           /// UV coordinates!

			const int i = Clamp( cast(int)( uv[0]*nx ), 0, nx - 1 );
			const int j = Clamp( cast(int)( (1.0f - uv[1])*ny -0.001 ), 0, ny -1 );
            const ulong pixelIndex = nx*j + i;
            const ulong channelSize = m_channelSizeInBytes;
            
			foreach ( c; 0..nc )
			{
                float value = 0.0f;
                
                const ulong channelOffset = (m_numChannels*pixelIndex + c)*channelSize;
                union Channel
                {
                    const(ubyte*) _asByte;
                    const(float*) _asFloat;
                }
                Channel channel = { _asByte : &pData[ channelOffset ] };

                if ( m_channelType == ChannelType.Byte )
                {
                    /// If image is stored as byte we have to remap [0, 255] -> [0.0, 1.0]
                    value = cast(float)((*channel._asByte)) / 255.0f;
                }
                else if ( m_channelType == ChannelType.Float )
                {
                    value = *channel._asFloat;
                }

				color[c] = Clamp( value, 0.0f, 1.0f );
			}
		}
		else
		{
		    color = vec4( 0.9f, 0.0f, 0.9f, 0.0f ); /// if texture is missing, return magenta
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

    const ImageFormat format = cast(ImageFormat)(ImageFormat.Byte + numComponents - 1);
    
	if ( imageData == null ) {
	    writeln("[ERROR] Couldn't load texture '", filename, "'");
	    // return false;
	}
	else {
		newTex = new ImageTexture( imageData, width, height, numComponents, format );
		writeln("Succesfully loaded texture file '", filename, "'" );
	}
	
    return newTex;
	// return true;
}

