struct FixedArray( T, ulong N )
{
	ulong m_endOffset;
	T[N]  m_data = void;

	alias m_data         this;
	alias T              Type;
	alias N              NumElements;
	alias m_endOffset    Count;

    @nogc @safe nothrow
	T[] range()
	{
	    return m_data[ 0 .. m_endOffset ];
	}
	
    @nogc @safe nothrow
	void Clear()
	{
	    m_endOffset = 0;
	}
	
	@nogc @safe nothrow
	void opOpAssign( string op )( in T value )
	{
		assert ( m_endOffset < N, "Pushing too many values onto FixedArray" );

		static if ( op == "~" )
		{
		    m_data[ m_endOffset ] = value;
			++m_endOffset;
		}
	}
}


struct DynamicArray( T )
{
    ulong m_endOffset;
	ulong m_numElements;
    T[]   m_data;

    alias m_data         this;
	alias T              Type;
	alias m_numElements  NumElements;
	alias m_endOffset    Count;

    @nogc @safe nothrow
	T[] range()
	{
	    return m_data[ 0 .. m_endOffset ];
	}
	
    @nogc @safe nothrow
	void Allocate( void[]* memBuffer )
	{
	    m_data = cast( T[] )( *memBuffer );
		m_numElements = m_data.length;
		m_endOffset = 0;
	}

	@nogc @safe nothrow
	void Allocate( T[]* memBuffer )
	{
	    m_data = *memBuffer;
		m_numElements = m_data.length;
		m_endOffset = 0;
	}

    @safe nothrow
	void Allocate( ulong numElements )
	{
	    m_data.reserve( numElements );
		m_numElements = numElements;
		m_endOffset = 0;
	}
	
	@nogc @safe nothrow
	void Clear()
	{
	    m_endOffset = 0;
	}

	@nogc @safe nothrow
	void opOpAssign( string op )( in T value )
	{
	    assert ( m_endOffset < m_numElements, "Pushing too many values onto Dynamic Array" );

		static if ( op == "~" )
		{
		    m_data[ m_endOffset ] = value;
			++m_endOffset;
		}
	}
}
