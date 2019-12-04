import std.math;

//////////////////////////////////////////
//
//  Utilities
//
//////////////////////////////////////////

const float PI					= 3.14159265359f;
const float TAU 				= 6.28318530718f;
const float PI_OVER_4   		= 0.78539816339f;

const float INV_PI				= 0.31830988618f;
const float INV_TAU				= 0.15915494309f;		
const float INV_PI2				= 0.10132118364f;

// Converts degrees into radians
pure const T DegreesToRad( T )( in T degrees ) { return degrees*0.01745329251; }

pure const T Max( T )( in T a, in T b ) { return  ( a > b ) ? a : b ;  }
pure const T Min( T )( in T a, in T b ) { return  ( a < b ) ? a : b ;  }

// Clamps a value 'val' to the closed interval [min, max]
pure const T Clamp( T )( T val, T min, T max ) {
    if ( val < min ) { return min; }
    else if ( val > max ) { return max; }
    
    return val;
}


// pure const 

//////////////////////////////////////////
//
//  Vector Types
//
//////////////////////////////////////////

// alias VecT!( uint, 2 ) vec2ui;
// alias VecT!( uint, 3 ) vec3ui;
// alias VecT!( uint, 4 ) vec4ui;

alias VecT!( float, 2 ) vec2f;
alias VecT!( float, 3 ) vec3f;
alias VecT!( float, 4 ) vec4f;

alias VecT!(double, 2) vec2d;
alias VecT!(double, 3) vec3d;
alias VecT!(double, 4) vec4d;

//  Default vecX types are floating point!
//
alias vec2f vec2;
alias vec3f vec3;
alias vec4f vec4;

struct VecT( Type, int Dim ) //if (( Dim >= 2 ) && Dim ( <= 4 ))
{
    static if ( Dim < 2 )
    {
        static assert(0, "Dim value is too low");
    }
    else static if ( Dim > 4 )
    {
        static assert(0, "Dim value is too high");
    }

    union
    {
        Type[ Dim ] data;

        struct
        {
            Type x, y;
            static if ( Dim >= 3 ) Type z;
            static if ( Dim >= 4 ) Type w;
        }

        struct
        {
            static if ( Dim == 2 )
            {
                Type s, t;
            }
            else
            {
                Type r, g;

                static if ( Dim >= 3 ) Type b;
                static if ( Dim >= 4 ) Type a;
            }

        }
    }

    alias data  this;    // Means object can be indexed like it's an array
    alias Dim   dim;
    alias Type  valueType;

    //  Specialise constructor by dimension
    //
    static if ( Dim == 2 ) {
        this( Type x, Type y ) {
            data[0] = x;
            data[1] = y;
        }
    }
    else static if ( Dim == 3 ) {
        this( Type x, Type y, Type z ) {
            data[0] = x;
            data[1] = y;
            data[2] = z;
        }
    }
    else static if ( Dim == 4 ) {
        this( Type x, Type y, Type z, Type w ) {
            data[0] = x;
            data[1] = y;
            data[2] = z;
            data[3] = w;
        }
    }

    pure const Type
    magnitude()
    {
        static if ( dim == 2 ) return sqrt( x*x + y*y );
        else static if ( dim == 3 ) return sqrt( x*x + y*y + z*z );
        else static if ( dim == 4 ) return sqrt( x*x + y*y + z*z + w*w );
        else static assert(0, "Too many dimensions!");
    }

    pure const VecT
    opBinary( string op )( VecT rhs )
    {
        static if ( Dim == 2 ) return mixin( "VecT( x"~op~"rhs.x, y"~op~"rhs.y)" );
        else static if ( Dim == 3 ) return mixin( "VecT( x"~op~"rhs.x, y"~op~"rhs.y, z"~op~"rhs.z)" );
        else static if ( Dim == 4 ) return mixin( "VecT( x"~op~"rhs.x, y"~op~"rhs.y, z"~op~"rhs.z, w"~op~"rhs.w)" );
        else static assert( 0, "Not implemented");
    }

    pure const VecT
    opBinary( string op )( valueType f ) 
    {
        VecT v;

        v.data[0] = mixin( "data[0]"~op~"f" );
        v.data[1] = mixin( "data[1]"~op~"f" );
        static if ( dim >= 3 )  v.data[2] = mixin( "data[2]"~op~"f" );
        static if ( dim >= 4 )  v.data[3] = mixin( "data[3]"~op~"f" );

        return v;
    }

    pure const VecT
    opBinaryRight( string op )( valueType f )
    {
        VecT v;

        v.data[0] = mixin( "data[0]"~op~"f" );
        v.data[1] = mixin( "data[1]"~op~"f" );
        static if ( dim >= 3 )  v.data[2] = mixin( "data[2]"~op~"f" );
        static if ( dim >= 4 )  v.data[3] = mixin( "data[3]"~op~"f" );

        return v;
    }
}

//
//  Vector Utility Functions
//

//  Cross product is only valid for 3 dimensional vectors
//
pure VecT!( T, 3 )
v_cross( T )( in VecT!( T, 3 ) a, in VecT!( T , 3 ) b )
{
    return VecT!( T, 3 )(
            a.y*b.z - b.y*a.z,
            b.x*a.z - a.x*b.z,
            a.x*b.y - b.x*a.y  );
}

pure vec3
v_normalise( in vec3 v )
{
    float magnitude = 1.0f/v.magnitude();
    return magnitude * v;
}



//
//  Geometry primitives
//

struct Ray
{
    vec3  m_origin;
    vec3  m_dir;
}

struct Sphere
{
    vec3    m_centre;
    float   m_radius;
}


pure vec3
Ray_AtT( in ref Ray pRay, float t )
{
    return pRay.m_origin + t*pRay.m_dir;
}