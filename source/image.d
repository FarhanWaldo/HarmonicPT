import std.algorithm;
import memory;

extern(C) int stbi_write_png(char *filename, int w, int h, int comp, const void *data, int stride_in_bytes);

// alias Image( T ) = ImageBuffer!T;
alias Image_F32     = ImageBuffer!float;

struct ImageBuffer( T )
{
    alias T ChannelType;

    uint            m_imageWidth;
    uint            m_imageHeight;
    uint            m_componentsPerPixel;
    uint            m_numPixels;
    T[]             m_pixelData;
};

void
ImageBuffer_Init(T)(
    ImageBuffer!T* pImageBuffer,
    int          width,
    int          height,
    int          componentsPerPixel,
    IMemAlloc*   pMemAlloc )
{
    pImageBuffer.m_imageWidth = width;
    pImageBuffer.m_imageHeight = height;

    pImageBuffer.m_componentsPerPixel = componentsPerPixel;

    uint numPixels = width * height;
    pImageBuffer.m_numPixels = numPixels;

    //  Allocate memory
    //
    if ( pMemAlloc == null ) {
        pImageBuffer.m_pixelData.length = numPixels * componentsPerPixel;
    }
    else {
        pImageBuffer.m_pixelData = pMemAlloc.AllocArray!T( numPixels * componentsPerPixel );
    }

}

void
ImageBuffer_WriteToPng(T)( ImageBuffer!T* pImageBuffer, char* filename )
{
    int imageHeight             = pImageBuffer.m_imageHeight;
    int imageWidth              = pImageBuffer.m_imageWidth;
    int numComponents           = pImageBuffer.m_componentsPerPixel;
    float* pImageBufferData     = &pImageBuffer.m_pixelData[0];

    // Create 32 bpp image for png
    //
    uint[] imageBuffer;
    imageBuffer.length = imageHeight * imageWidth;

    for ( int row = 0; row < imageHeight; ++row )
    {
        for ( int col = 0; col < imageWidth; ++col )
        {
            int pixelIndex = row * imageWidth + col;

            uint ri = cast(uint)( min( pImageBufferData[ numComponents*pixelIndex    ], 1.0f)*255.0f );
            uint gi = cast(uint)( min( pImageBufferData[ numComponents*pixelIndex + 1], 1.0f)*255.0f );
            uint bi = cast(uint)( min( pImageBufferData[ numComponents*pixelIndex + 2], 1.0f)*255.0f );
            uint alpha = 0xFF;

            uint colour = ( alpha << 24 ) | ( bi << 16 ) | ( gi << 8 ) | ri;

            imageBuffer[ pixelIndex ] = colour;
        }
    }

    stbi_write_png( filename , imageWidth, imageHeight, 4 /* RGBA */, imageBuffer.ptr, 4 * imageWidth );
}
