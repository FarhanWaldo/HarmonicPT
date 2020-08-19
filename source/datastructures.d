/// F_TODO::
/// 
///
///
struct BufferT(T, ulong N = 0, bool BOUND_CHECK = true )
{
    enum IsStatic = N != 0;

	ulong    m_size = 0;
	static if ( IsStatic )
	{
        T[N]      m_data = void;
        enum      m_capacity = N;
	}
	else
	{
	    T[]     m_data;
		ulong   m_capacity;

		this( T[] data )
		{
			m_data     = data;
			m_capacity = data.length;
			m_size     = 0;
		}
	}

    alias m_data this;

	pure @nogc @safe nothrow
	void Reset()
	{
	    m_size = 0;
	}

	pure @nogc @safe nothrow
	void Push(T)( auto ref T t)
	{
	    static if (BOUND_CHECK) {
	        assert ( m_size < m_capacity, "Exceeded capacity of Buffer" );
		}

		m_data[ m_size ] = t;
		++m_size;
	}

	pure const @nogc @safe nothrow
	bool Empty()
	{
	    return m_size == 0;
	}

	pure const @nogc @safe nothrow
	ulong GetCount()
	{
	    return m_size;
	}

	pure const @nogc @safe nothrow
	ulong GetCapacity()
	{
	    return m_capacity;
	}

	pure @nogc @safe nothrow
	T[] range()
	{
		return m_data[0..m_size];
	}

	pure const @nogc @safe nothrow
	const(T[]) range()
	{
		return m_data[0..m_size];
	}
}

/// Helper function to create a new Buffer from an allocator
///
///
pragma(inline,true) @nogc nothrow
BufferT!T CreateBuffer(T, ALLOC)( ref ALLOC allocator, ulong numElements )
{
    import memory : AllocArray;
    return BufferT!T( AllocArray!(T)( &allocator, numElements ) );
}
