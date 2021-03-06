import std.algorithm;

extern(C) int stbi_write_png(char *filename, int w, int h, int comp, const void *data, int stride_in_bytes);

// alias Image( T ) = ImageBuffer!T;
alias Image_F32     = ImageBuffer!float;

struct ImageBuffer( T )
{
    alias T ChannelType;

    struct alloca_t
    {
        uint       width;
        uint       height;
        uint       componentsPerPixel;

        ulong
        GetSizeInBytes()
        {
            return width * height * componentsPerPixel * T.sizeof;
        }

        alias GetSizeInBytes Size;
    }

    uint            m_imageWidth;
    uint            m_imageHeight;
    uint            m_componentsPerPixel;
    uint            m_numPixels;
    T[]             m_pixelData;
};

void
ImageBuffer_Alloca( T, U ) (
    ImageBuffer!T*              pImageBuffer,
    ref ImageBuffer!T.alloca_t  alloca,
    U                           memBuffer
)
{
    auto typedMemBuffer = cast( T[] )( memBuffer );
    ImageBuffer_Init!T(
        pImageBuffer,
        alloca.width,
        alloca.height,
        alloca.componentsPerPixel,
        &typedMemBuffer
    );
}

void
ImageBuffer_Init(T)(
    ImageBuffer!T* pImageBuffer,
    int          width,
    int          height,
    int          componentsPerPixel,
    T[]*         pixelDataBuffer )
{
    pImageBuffer.m_imageWidth   = width;
    pImageBuffer.m_imageHeight  = height;

    pImageBuffer.m_componentsPerPixel = componentsPerPixel;

    uint numPixels              = width * height;
    pImageBuffer.m_numPixels    = numPixels;

    //  Allocate memory
    //
    if ( pixelDataBuffer == null ) {
        pImageBuffer.m_pixelData.length = numPixels * componentsPerPixel;
    }
    else {
        pImageBuffer.m_pixelData = *pixelDataBuffer;
    }

}

void
ImageBuffer_WriteToPng(T)( ImageBuffer!T* pImageBuffer, char* filename )
{
    int imageHeight             = pImageBuffer.m_imageHeight;
    int imageWidth              = pImageBuffer.m_imageWidth;
    int numComponents           = pImageBuffer.m_componentsPerPixel;
    T*  pImageBufferData        = &pImageBuffer.m_pixelData[0];

    // Create 32 bpp image for png
    //
    uint[] imageBuffer;
    imageBuffer.length = imageHeight * imageWidth;

    for ( int row = 0; row < imageHeight; ++row )
    {
        for ( int col = 0; col < imageWidth; ++col )
        {
            const int pixelIndex = row * imageWidth + col;
			const int compIndex = numComponents*pixelIndex;

			static if (is(T==ubyte))
			{
				uint ri = pImageBufferData[ compIndex ];
				uint gi = pImageBufferData[ compIndex + 1 ];
				uint bi = pImageBufferData[ compIndex + 2 ];
			}
			else
			{
				uint ri = cast(uint)( min( pImageBufferData[ compIndex ], 1.0f)*255.0f );
				uint gi = cast(uint)( min( pImageBufferData[ compIndex + 1], 1.0f)*255.0f );
				uint bi = cast(uint)( min( pImageBufferData[ compIndex + 2], 1.0f)*255.0f );
			}
            uint alpha = 0xFF;

            uint colour = ( alpha << 24 ) | ( bi << 16 ) | ( gi << 8 ) | ri;

            imageBuffer[ pixelIndex ] = colour;
        }
    }

    stbi_write_png( filename , imageWidth, imageHeight, 4 /* RGBA */, imageBuffer.ptr, 4 * imageWidth );
}
