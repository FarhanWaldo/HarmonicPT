
alias IMemAlloc = BaseMemAlloc;
alias u64       = ulong;

/**
    The base allocator claas which all others will derive from
 */
abstract class BaseMemAlloc
{
    const u64   m_memCapacityBytes;    /// Total capacity of this memory allocator (bytes)
    u64         m_memAllocatedBytes;   /// How much memory has been allocated so far (bytes)

    this( u64 capacityInBytes )
    {
        m_memCapacityBytes = capacityInBytes;
    }

	/**
        Returns: Memory capacity of this allocator (bytes)        
	 */
    const pure u64 GetCapacityInBytes() { return m_memCapacityBytes; }

	/**
        Returns: Memory allocated so far by this allocator (bytes)
	 */
    const pure u64 GetNumAllocatedBytes()  { return m_memAllocatedBytes; }

	/**
        Returns: How much free space there is (bytes)
	 */
    const pure u64 GetNumUnallocatedBytes() { return m_memCapacityBytes - m_memAllocatedBytes; }

	/**
        "Clear all the books", so to speak. This tells the allocator to forget about all the allocations it has done.
        This may, or may not, result in actual deallocations happening (like free()), this depends on the specific allocator.
        The StackAlloc class will just zero it's memory offset pointer, for example.
	 */
    void    Reset();

	/**
        Allocates the bytesRequested amount of bytes, with the requested alignment

        Params:
            bytesRequested = Number of bytes you wish to allocate
            alignment = Desired memory alignment for allocated memory. Default is 16 byte alignment.

        Returns: An untyped slice (void[]) that is guaranteed to be bytesRequested size in bytes
	 */
	@nogc nothrow @trusted
    void[]   Allocate( u64 bytesRequested, u64 alignment = 16);
}

/**
    It's a stack basically. You can make allocations out of it but you can't "reclaim" memory from the middle of the stack.
    Resetting will cause the stack offset to be zero again, so subsequent allocations will be writing over memory from before.
    Very efficient at allocation, and fast to reset. Very little book-keeping required. This allocator is ideal for
    transient dynamic allocations: you can use it as an arena/scratch-buffer while ray tracing for a pixel, or per frame in a game loop,
    and just reset when you get to the next pixel, or start a new frame.
 */
class StackAlloc : BaseMemAlloc
{
    void*   m_memBufferStart;
    void*   m_memBufferEnd;

    u64     m_offsetFromStart;

    this( void* startAddress, u64 stackSizeInBytes )
    {
        super( stackSizeInBytes );
        m_memBufferStart = startAddress;
        m_memBufferEnd   = m_memBufferStart + stackSizeInBytes;
    }

	this( void[] memBuffer )
	{
		const u64 sizeInBytes = memBuffer.length;
		super( sizeInBytes );
		m_memBufferStart = cast(void*) memBuffer;
		m_memBufferEnd   = m_memBufferStart + sizeInBytes;
	}

    override
	void Reset()
    {
        m_offsetFromStart = 0;
        m_memAllocatedBytes = 0;
    }

	@nogc nothrow @trusted override
	void[] Allocate( u64 bytesRequested, u64 alignment = 16 )
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

/**
    Allocates a single instance of a class or a struct using a memory allocator object

    Params:
        TAlloc = The type of the memory allocator. This is usually inferred.
        T      = The struct or class you are intending to create an instance of
        Args   = Arg list for constructor/initialiser arguments for the class or struct. Also inferred.
        
        memAlloc = The allocator object
        args = A variadic list of arguments to forward to the constructor

    Returns:
        A pointer to the allocated object
 */
pragma(inline, true)
T* AllocInstance( T, TAlloc, Args... )( ref TAlloc memAlloc, auto ref Args args )
{
	import std.conv : emplace;

	static if (is(T == struct))
	{
	    return cast(T*) emplace( cast(T*) memAlloc.Allocate( T.sizeof ), args );
	}
	// else if (is(T == class))
	else
	{
	    import std.traits : classInstanceAlignment;
	    immutable ulong classSizeBytes = __traits( classInstanceSize, T );
		immutable ulong alignment      = classInstanceAlignment!T;
	    return cast(T*) [emplace!T( memAlloc.Allocate(classSizeBytes, alignment), args)].ptr;
	}
	// else
	// {
	//     static assert(false,"AllocInstance() called with type that's not a class or struct.");
	// }
}

/**
    Helper method that is used for allocating arrays of a struct type

    Params:
        T = Type of struct to create
        memAlloc = A pointer to an instance of BaseMemAlloc
        numElements = Number of elements in the array ( T[numElements] )
        alignment   = Alignment of memory for the array (16 byte by default)

    Returns:
        A slice for the array requested. The guaranteed lifetime of the slice is dependent upon the allocator used
 */
pragma(inline,true)
T[] AllocArray( T )( BaseMemAlloc* memAlloc, u64 numElements, u64 alignment= 16 )
{
	static if (is(T==class)) {
		static assert(false,"AllocArray!T Called with a class type, unequipped to handle that"); 
	}
    return cast( T[] )( memAlloc.Allocate( numElements * T.sizeof , 16 ) );
}

/**
    Takes an input memory address and returns one aligned to the specified alignment (must be a power of two)

    Params:
        address = Input memory address, assumed to be unaligned
        alignment = Requested alignment, in bytes.

    Returns: The aligned memory address
 */
@nogc pure nothrow void*
AlignAddress( void* address, u64 alignment = 16 )
{
    const u64 alignSub1 = alignment - 1;
    return cast( void*)( ( cast(long)( address ) + alignSub1 ) & ~alignSub1 );
}


import core.stdc.stdlib : malloc, free; // Need libstdc's malloc/free...

/**
    Uses libc's malloc to allocate `bytesRequested` many bytes, with a specified alignment in bytes.

    This routine will allocate slightly more memory than requested, for alignment, and also to store
    the unaligned address originally given by malloc, so that we can free this memory properly using
    CAlignedFree. We stash this address just behind the aligned pointer that gets returned.

    Params:
        bytesRequested = Number of bytes requested for allocation
        alignment      = Requested alignment of memory address (must be a power of two)

    Returns: An aligned memory address that should have bytesRequested allocated bytes
 */
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
    Can only be used to free an aligned pointer created by CAlignedMalloc

    Params:
        ptr = an aligned memory address, created by CAlignedMalloc
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

