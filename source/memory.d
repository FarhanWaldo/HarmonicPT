
alias IMemAlloc = BaseMemAlloc;
alias u64       = ulong;

abstract class BaseMemAlloc
{
    const u64   m_memCapacityBytes;
    u64         m_memAllocatedBytes;

    this( u64 capacityInBytes )
    {
        m_memCapacityBytes = capacityInBytes;
    }

    const pure u64 GetCapacityInBytes() { return m_memCapacityBytes; }
    const pure u64 GetNumAllocatedBytes()  { return m_memAllocatedBytes; }
    const pure u64 GetNumUnallocatedBytes() { return m_memCapacityBytes - m_memAllocatedBytes; }

    void    Reset();

	@nogc nothrow @trusted
    void[]   Allocate( u64 bytesRequested, u64 alignment = 16);
}

class StackAlloc : BaseMemAlloc
{
    /**
        The memory region governed by a StackAlloc object is described by the open-interval in the virtual address space
         [ m_memBufferStart, m_memBufferEnd )
    */
    void*   m_memBufferStart;
    void*   m_memBufferEnd;

    u64     m_offsetFromStart;

    this( void* startAddress, u64 stackSizeInBytes )
    {
        super( stackSizeInBytes );
        m_memBufferStart = startAddress;
        m_memBufferEnd   = m_memBufferStart + stackSizeInBytes;
    }

    override void
    Reset()
    {
        m_offsetFromStart = 0;
        m_memAllocatedBytes = 0;
    }

	@nogc nothrow @trusted
    override void[]
    Allocate( u64 bytesRequested, u64 alignment = 16 )
    {
        u64 alignedBytesSize = bytesRequested + ( alignment - 1 ); //AlignAllocSize( bytesRequested, alignment );
        void* startAddress = m_memBufferStart + m_offsetFromStart;

        assert( startAddress + alignedBytesSize < m_memBufferEnd, "Stack Allocator size has been exceded!" );

        m_offsetFromStart += alignedBytesSize;
        m_memAllocatedBytes += alignedBytesSize;

        void* alignedAddress = AlignAddress( startAddress, alignment);

        return alignedAddress[ 0 .. bytesRequested ];
    }
}


pragma(inline,true)
T* Alloc(T, T_Alloc)( ref T_Alloc alloc )
{
	return cast(T*) alloc.Allocate( T.sizeof );
}

pragma(inline,true)
T[] AllocArray( T )( BaseMemAlloc* memAlloc, u64 numElements, u64 alignment= 16 )
{
    return cast( T[] )( memAlloc.Allocate( numElements * T.sizeof , 16 ) );
}

@nogc pure nothrow void*
AlignAddress( void* address, u64 alignment = 16 )
{
    const u64 alignSub1 = alignment - 1;
    return cast( void*)( ( cast(long)( address ) + alignSub1 ) & ~alignSub1 );
}


import core.stdc.stdlib : malloc, free; // Need libstdc's malloc/free...

@nogc void*
CAlignedMalloc( u64 bytesRequested, u64 alignment )
{
    u64 alignSub1 = alignment - 1;
    void* mallocAddress = malloc( bytesRequested + (void*).sizeof + alignSub1 );

    void* alignedAddress = AlignAddress( mallocAddress, alignment );
    *(cast( void** )(alignedAddress)) =  mallocAddress;

    return &alignedAddress[ 1 ];
}

/**
    Can only be used to free an aligned pointer created vy CAlignedMalloc
*/
void
CAlignedFree( void* ptr )
{
    void* actualAddress = ptr - 1;
    free( actualAddress );
}

@nogc pure @safe nothrow
u64 MegaBytes( u64 numMegaBytes ) { return numMegaBytes*1000000; }
@nogc pure @safe nothrow
u64 KiloBytes( u64 numKiloBytes ) { return numKiloBytes*1000; }

