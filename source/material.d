import memory;
import interactions;

interface IMaterial
{
	pure @safe @nogc nothrow
	void ComputeScatteringFunctions( SurfaceInteraction* si,
									 IMemAlloc*          memAlloc,
									 bool                transportFromEye,
									 bool                allowMultipleLobes );
}

