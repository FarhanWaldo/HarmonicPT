import std.math;

// alias VecT!( uint, 2 ) vec2ui;
// alias VecT!( uint, 3 ) vec3ui;
// alias VecT!( uint, 4 ) vec4ui;

alias VecT!( float, 2 ) vec2f;
alias VecT!( float, 3 ) vec3f;
alias VecT!( float, 4 ) vec4f;

alias VecT!(double, 2) vec2d;
alias VecT!(double, 3) vec3d;
alias VecT!(double, 4) vec4d;

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
    opBinary( string op )( float f ) 
    {
        VecT v;

        v.data[0] = mixin( "data[0]"~op~"f" );
        v.data[1] = mixin( "data[1]"~op~"f" );
        static if ( dim >= 3 )  v.data[2] = mixin( "data[2]"~op~"f" );
        static if ( dim >= 4 )  v.data[3] = mixin( "data[3]"~op~"f" );

        return v;
    }

    pure const VecT
    opBinaryRight( string op )( float f )
    {
        VecT v;

        v.data[0] = mixin( "data[0]"~op~"f" );
        v.data[1] = mixin( "data[1]"~op~"f" );
        static if ( dim >= 3 )  v.data[2] = mixin( "data[2]"~op~"f" );
        static if ( dim >= 4 )  v.data[3] = mixin( "data[3]"~op~"f" );

        return v;
    }
}
/*
//
//  Math primitives
//

struct vec3
{
    union
    {
        struct 
        {
            float x, y, z;
        }

        struct
        {
            float r, g, b;
        }

        float[3] d;
    }

    pure const float
    magnitude()
    {
        return sqrt( x*x + y*y + z*z );
    }

    void normalise()
    {
        float invMag = 1.0f / magnitude();
        x *= invMag;
        y *= invMag;
        z *= invMag;
    }

    pure const vec3
    opBinary( string op )( vec3 rhs )
    {
        return mixin( "vec3( x"~op~"rhs.x, y"~op~"rhs.y, z"~op~"rhs.z)");
    }

    pure const vec3
    opBinary( string op )( float v )
    {
        return mixin( "vec3( v"~op~"x, v"~op~"y, z"~op~"z )" );
    }

    pure const vec3
    opBinaryRight( string op )( float v )
    {
        return mixin( "vec3( v"~op~"x, v"~op~"y, z"~op~"z )" );
    }

}

struct vec4
{
    union
    {
        struct
        {
            float x, y, z, w;
        }

        struct
        {
            float r, g, b, a;
        }

        // Quaternion representation
        //
        struct
        {
            vec3    axis;
            float   angle;
        }

        float[4] d;
    }

    float magnitude()
    {
        return sqrt( x*x + y*y + z*z + w*w );
    }

    void normalise()
    {
        float invMag = 1.0f / magnitude();
        x *= invMag;
        y *= invMag;
        z *= invMag;
        x *= invMag;
    }

    vec4 opMul( float scalar )
    {
        return vec4( x*scalar, y*scalar, z*scalar, w*scalar );
    }

    vec4 opAdd( vec4 v2 )
    {
        return vec4( x + v2.x, y + v2.y, z + v2.z, w + v2.w );
    }

    vec4 opSub( vec4 v2 )
    {
        return vec4( x - v2.x, y - v2.y, z - v2.z, w - v2.w );
    }

    vec4 opDiv( float scalar )
    {
        float invScalar =  1.0f/scalar;
        return vec4( x*invScalar, y*invScalar, z*invScalar, w*invScalar );
    }
}

struct vec2
{
    union
    {
        struct
        {
            float x, y;
        }

        struct
        {
            float u, v;
        }

        float[2] d;
    }

    float magnitude()
    {
        return sqrt( x*x + y*y );
    }

    void normalise()
    {
        float invMag = 1.0f / magnitude();
        x *= invMag;
        y *= invMag;
    }

    vec2 opMul( float scalar )
    {
        return vec2( x*scalar, y*scalar );
    }

    vec2 opAdd( vec2 v2 )
    {
        return vec2( x + v2.x, y + v2.y  );
    }

    vec2 opSub( vec2 v2 )
    {
        return vec2( x - v2.x, y - v2.y );
    }

    vec2 opDiv( float scalar )
    {
        float invScalar =  1.0f/scalar;
        return vec2( x*invScalar, y*invScalar );
    }
}

*/
//
//  Math primitive functions
//

pure vec3
v_cross( in vec3 a, in vec3 b )
{
    return vec3(
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