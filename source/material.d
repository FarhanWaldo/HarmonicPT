import memory;
import interactions;
import texture;

interface IMaterial
{
	pure @safe @nogc nothrow
	void ComputeScatteringFunctions( SurfaceInteraction* si,
									 IMemAlloc*          memAlloc,
									 bool                transportFromEye,
									 bool                allowMultipleLobes );
}
version(none) {
class MatteMaterial
{
    ITexture* m_albedo;

	this( ITexture* albedo )
	{
		m_albedo = albedo;
	}

	override pure @safe @nogc nothrow
	void ComputeScatteringFunctions( SurfaceInteraction* si,
									 IMemAlloc*          memAlloc,
									 bool                transportFromEye,
									 bool                allowMultipleLobes )
	{
		
	}
	
}
}
