import std.algorithm;

extern(C) int stbi_write_png(char *filename, int w, int h, int comp, const void *data, int stride_in_bytes);

struct ImageBuffer
{
    uint        imageWidth;
    uint        imageHeight;
    uint        componentsPerPixel;
    uint        numPixels;
    float[]     pixelData;
};

void
ImageBuffer_Init( ImageBuffer* pImageBuffer,
                  int          width,
                  int          height,
                  int          componentsPerPixel )
{
    pImageBuffer.imageWidth = width;
    pImageBuffer.imageHeight = height;
    pImageBuffer.componentsPerPixel = componentsPerPixel;

    uint numPixels = width * height;
    pImageBuffer.numPixels = numPixels;

    // Allocate memory
    pImageBuffer.pixelData.length = numPixels * componentsPerPixel;
}

void
ImageBuffer_WriteToPng( ImageBuffer* pImageBuffer, char* filename )
{
    int imageHeight             = pImageBuffer.imageHeight;
    int imageWidth              = pImageBuffer.imageWidth;
    int numComponents           = pImageBuffer.componentsPerPixel;
    float* pImageBufferData     = &pImageBuffer.pixelData[0];

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
