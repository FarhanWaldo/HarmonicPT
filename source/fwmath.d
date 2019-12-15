import std.math;

alias ulong     u64;
alias uint      u32;
alias ushort    u16;
alias ubyte     u8;

alias long      i64;
alias int       i32;
alias short     i16;
alias byte      i8;

alias double    f64;
alias float     f32;


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
pure T DegreesToRad( T )( in T degrees ) { return degrees*0.01745329251; }

pure T Max( T )( in T a, in T b ) { return  ( a > b ) ? a : b ;  }
pure T Min( T )( in T a, in T b ) { return  ( a < b ) ? a : b ;  }

pure T Abs( T )( in T a )         { return  ( a < T(0) ) ? -a : a; }

// Clamps a value 'val' to the closed interval [min, max]
pure T Clamp( T )( T val, T min, T max ) {
    if ( val < min ) { return min; }
    else if ( val > max ) { return max; }
    
    return val;
}

pure float
frand( int* seed )
{
    union frandT
    {
        float   fres;
        uint    ires;
    }

    seed[0] *= 16807;
    frandT v;
    v.ires = ((( cast(uint) seed[0] ) >> 9 ) | 0x3f800000 );
    return v.fres - 1.0f;
}

struct RNG
{
    i32 m_seed;

    this( i32 seed )
    {
        this.m_seed = seed;
    }

    float rand() {  return frand(&m_seed); }
}

// pure const 

//////////////////////////////////////////
//
//  Vector Primitives
//
//////////////////////////////////////////

// alias VecT!( uint, 2 ) vec2ui;
// alias VecT!( uint, 3 ) vec3ui;
// alias VecT!( uint, 4 ) vec4ui;

alias VecT!( float, 2 ) vec2f;
alias VecT!( float, 3 ) vec3f;
alias VecT!( float, 4 ) vec4f;

alias VecT!( double, 2 ) vec2d;
alias VecT!( double, 3 ) vec3d;
alias VecT!( double, 4 ) vec4d;

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

    this( Type v )
    {
        data[0] = v;
        data[1] = v;
        static if ( Dim >= 3 ) data[2] = v;
        static if ( Dim >= 4 ) data[3] = v;
    }

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

    void
    normalise()
    {
        this = (Type( 1 )/this.magnitude)*this;
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

alias QuatT!( float ) Quatf;
alias QuatT!( double ) Quatd;

struct QuatT( Type )
{
    union
    {
        Type[4] data;

        struct {    Type x, y, z, w;   }

        struct {
            VecT!( Type, 3 ) m_axis;
            Type             m_angle;
        }

        VecT!( Type, 4 ) vec;
    }

    // this( in VecT!( Type, 3 ) axis, Type angle )
    // {
    //     this.m_axis = axis;
    //     this.m_angle = angle;
    // }

    alias data this;
    alias Type valueType;
}

//////////////////////////////////////////
//
//  Vector Utilities
//
//////////////////////////////////////////

//  Cross product is only valid for 3 dimensional vectors
//
pure VecT!( T, 3 )
v_cross( T ) ( in VecT!( T, 3 ) a, in VecT!( T , 3 ) b )
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

pure T
v_dot( T, int Dim ) ( in ref VecT!( T, Dim ) a, in ref VecT!( T, Dim ) b )
{
    static if ( Dim == 2 ) return ( a.x*b.x + a.y*b.y );
    else static if ( Dim == 3 ) return ( a.x*b.x + a.y*b.y + a.z*b.z );
    else static assert( 0, "Invalid dimension for vector");
}

pure VecT!( T, Dim )
v_lerp( T, int Dim ) ( in ref VecT!( T, Dim ) a, in ref VecT!( T, Dim ) b, T interpolant )
{
    return interpolant*a + ( T(1) - interpolant )*b;
}

//////////////////////////////////////////
//
//  Quaternion Utilities
//
//////////////////////////////////////////

pure QuatT!( T )
CreateRotationQuat( T )( auto ref VecT!( T, 3 ) axis, T angle )
{
    QuatT!( T ) quat;
    T halfAngle = T(0.5)*angle;
    T cosHalfAngle = T( cos( halfAngle ) );
    T sinHalfAngle = T( sin( halfAngle ) );

    quat.m_angle = cosHalfAngle;
    quat.m_axis = sinHalfAngle*axis;

    quat.vec.normalise();

    return quat;
}

pure QuatT!( T )
QuatT_Mult( T ) ( auto ref QuatT!( T ) qA, in ref QuatT!( T ) qB )
{
    QuatT!( T ) c;

    c.m_angle = qA.m_angle*qB.m_angle - v_dot!( T, 3 )( qA.m_axis, qB.m_axis );
    c.m_axis  = v_cross( qA.m_axis, qB.m_axis ) + qA.m_angle*qB.m_axis + qB.m_angle*qA.m_axis;

    return c;
}

pure VecT!( T, 3 )
RotateVec3( T ) ( auto ref VecT!( T, 3 ) v, auto ref QuatT!( T ) rotQuat )
{
    alias QuatT!(T) _Quat;

    _Quat v4 = { m_axis : v, m_angle : T(0) };
    _Quat antiRotQuat = { m_axis : T(-1)*rotQuat.m_axis, m_angle : rotQuat.m_angle };

    v4 = QuatT_Mult( rotQuat, v4 );
    v4 = QuatT_Mult( v4, antiRotQuat );

    return v4.m_axis;
}

//////////////////////////////////////////
//
//  Matrix Primitives & Utilities
//
//////////////////////////////////////////

alias Mat4x4T!( float ) Mat4x4f;
alias Mat4x4T!( double ) Mat4x4d;

alias Mat4x4f Mat4x4;

struct Mat4x4T( T )
{
    union
    {
        T[ 16 ] d;
        T[4][4] dd;

        struct 
        {
            T a1, a2, a3, a4;
            T b1, b2, b3, b4;
            T c1, c2, c3, c4;
            T d1, d2, d3, d4;
        }
    }

    alias d this;
}

pure Mat4x4T!( T )
Mat4x4_Identity( T ) ()
{
    Mat4x4T!( T ) m = { d: [
        T(1), T(0), T(0), T(0),
        T(0), T(1), T(0), T(0),
        T(0), T(0), T(1), T(0),
        T(0), T(0), T(0), T(1) ]
    };

    return m;
}

pure T
Mat4x4_Determinant( T )( in ref Mat4x4T!( T ) m )
{
	return m.a1*m.b2*m.c3*m.d4 - m.a1*m.b2*m.c4*m.d3 + m.a1*m.b3*m.c4*m.d2 - m.a1*m.b3*m.c2*m.d4
		+ m.a1*m.b4*m.c2*m.d3 - m.a1*m.b4*m.c3*m.d2 - m.a2*m.b3*m.c4*m.d1 + m.a2*m.b3*m.c1*m.d4
		- m.a2*m.b4*m.c1*m.d3 + m.a2*m.b4*m.c3*m.d1 - m.a2*m.b1*m.c3*m.d4 + m.a2*m.b1*m.c4*m.d3
		+ m.a3*m.b4*m.c1*m.d2 - m.a3*m.b4*m.c2*m.d1 + m.a3*m.b1*m.c2*m.d4 - m.a3*m.b1*m.c4*m.d2
		+ m.a3*m.b2*m.c4*m.d1 - m.a3*m.b2*m.c1*m.d4 - m.a4*m.b1*m.c2*m.d3 + m.a4*m.b1*m.c3*m.d2
		- m.a4*m.b2*m.c3*m.d1 + m.a4*m.b2*m.c1*m.d3 - m.a4*m.b3*m.c1*m.d2 + m.a4*m.b3*m.c2*m.d1;
}

pure Mat4x4T!( T )
Mat4x4_Invert( T )( in ref Mat4x4T!( T ) m )
{
	T det = Mat4x4_Determinant( m );
	Mat4x4!T inverseM = 0;

	// Matrix is not invertible; return a zeroed out matrix for clarity
	//		since the inverse operator should never return a zero matrix
	if ( det == T(0)) { return inverseM; }

	T invdet = T(1)/det;

	inverseM.a1 = invdet  * (m.b2 * (m.c3 * m.d4 - m.c4 * m.d3) + m.b3 * (m.c4 * m.d2 - m.c2 * m.d4) + m.b4 * (m.c2 * m.d3 - m.c3 * m.d2));
	inverseM.a2 = -invdet * (m.a2 * (m.c3 * m.d4 - m.c4 * m.d3) + m.a3 * (m.c4 * m.d2 - m.c2 * m.d4) + m.a4 * (m.c2 * m.d3 - m.c3 * m.d2));
	inverseM.a3 = invdet  * (m.a2 * (m.b3 * m.d4 - m.b4 * m.d3) + m.a3 * (m.b4 * m.d2 - m.b2 * m.d4) + m.a4 * (m.b2 * m.d3 - m.b3 * m.d2));
	inverseM.a4 = -invdet * (m.a2 * (m.b3 * m.c4 - m.b4 * m.c3) + m.a3 * (m.b4 * m.c2 - m.b2 * m.c4) + m.a4 * (m.b2 * m.c3 - m.b3 * m.c2));
	inverseM.b1 = -invdet * (m.b1 * (m.c3 * m.d4 - m.c4 * m.d3) + m.b3 * (m.c4 * m.d1 - m.c1 * m.d4) + m.b4 * (m.c1 * m.d3 - m.c3 * m.d1));
	inverseM.b2 = invdet  * (m.a1 * (m.c3 * m.d4 - m.c4 * m.d3) + m.a3 * (m.c4 * m.d1 - m.c1 * m.d4) + m.a4 * (m.c1 * m.d3 - m.c3 * m.d1));
	inverseM.b3 = -invdet * (m.a1 * (m.b3 * m.d4 - m.b4 * m.d3) + m.a3 * (m.b4 * m.d1 - m.b1 * m.d4) + m.a4 * (m.b1 * m.d3 - m.b3 * m.d1));
	inverseM.b4 = invdet  * (m.a1 * (m.b3 * m.c4 - m.b4 * m.c3) + m.a3 * (m.b4 * m.c1 - m.b1 * m.c4) + m.a4 * (m.b1 * m.c3 - m.b3 * m.c1));
	inverseM.c1 = invdet  * (m.b1 * (m.c2 * m.d4 - m.c4 * m.d2) + m.b2 * (m.c4 * m.d1 - m.c1 * m.d4) + m.b4 * (m.c1 * m.d2 - m.c2 * m.d1));
	inverseM.c2 = -invdet * (m.a1 * (m.c2 * m.d4 - m.c4 * m.d2) + m.a2 * (m.c4 * m.d1 - m.c1 * m.d4) + m.a4 * (m.c1 * m.d2 - m.c2 * m.d1));
	inverseM.c3 = invdet  * (m.a1 * (m.b2 * m.d4 - m.b4 * m.d2) + m.a2 * (m.b4 * m.d1 - m.b1 * m.d4) + m.a4 * (m.b1 * m.d2 - m.b2 * m.d1));
	inverseM.c4 = -invdet * (m.a1 * (m.b2 * m.c4 - m.b4 * m.c2) + m.a2 * (m.b4 * m.c1 - m.b1 * m.c4) + m.a4 * (m.b1 * m.c2 - m.b2 * m.c1));
	inverseM.d1 = -invdet * (m.b1 * (m.c2 * m.d3 - m.c3 * m.d2) + m.b2 * (m.c3 * m.d1 - m.c1 * m.d3) + m.b3 * (m.c1 * m.d2 - m.c2 * m.d1));
	inverseM.d2 = invdet  * (m.a1 * (m.c2 * m.d3 - m.c3 * m.d2) + m.a2 * (m.c3 * m.d1 - m.c1 * m.d3) + m.a3 * (m.c1 * m.d2 - m.c2 * m.d1));
	inverseM.d3 = -invdet * (m.a1 * (m.b2 * m.d3 - m.b3 * m.d2) + m.a2 * (m.b3 * m.d1 - m.b1 * m.d3) + m.a3 * (m.b1 * m.d2 - m.b2 * m.d1));
	inverseM.d4 = invdet  * (m.a1 * (m.b2 * m.c3 - m.b3 * m.c2) + m.a2 * (m.b3 * m.c1 - m.b1 * m.c3) + m.a3 * (m.b1 * m.c2 - m.b2 * m.c1));


	return inverseM;
}

pure Mat4x4T!(T)
Mat4x4_Translation( T, U )( auto ref in VecT!( U, 3 ) translate )
{
    Mat4x4T!T m = { d : [
        T(1), T(0), T(0), T( translate.x ),
        T(0), T(1), T(0), T( translate.y ),
        T(0), T(0), T(1), T( translate.z ),
        T(0), T(0), T(0), T(1)
    ]};

    return m;
}
pure Mat4x4T!T
Mat4x4_Scale( T )( in ref VecT!( T, 3 ) scale )
{
    Mat4x4T!T m = { d: [
        T( scale.x ), T(0), T(0), T(0),
        T(0), T( scale.y), T(0), T(0),
        T(0), T(0), T( scale.z ), T(0),
        T(0), T(0), T(0), T(1)
    ]};

    return m;
}

pure VecT!(T,3)
TransformPoint( T )( in ref Mat4x4T!T m, in ref VecT!( T, 3 ) p )
{
    VecT!(T,3) xformedP = vec3(
		m.d[0]*p.x + m.d[1]*p.y + m.d[2]*p.z + m.d[3],
		m.d[4]*p.x + m.d[5]*p.y + m.d[6]*p.z + m.d[7],
		m.d[8]*p.x + m.d[9]*p.y + m.d[10]*p.z + m.d[11]
    );

    return xformedP;
}

pure VecT!(T,3)
TransformDirection( T )( in ref Mat4x4T!T m, in ref VecT!( T, 3 ) p )
{
    VecT!(T,3) xformedDir = vec3(
		m.d[0]*p.x + m.d[1]*p.y + m.d[2]*p.z,
		m.d[4]*p.x + m.d[5]*p.y + m.d[6]*p.z,
		m.d[8]*p.x + m.d[9]*p.y + m.d[10]*p.z
    );

    return xformedP;
}

pure Mat4x4T!T
Mat4x4_RotationFromQuat( T )( in ref QuatT!(T) rotQuat )
{
    alias rotQuat.vec rot;

	float x2 = rot.x*rot.x;
	float y2 = rot.y*rot.y;
	float z2 = rot.z*rot.z;
	//float w2 = rot.w*rot.w;

	float xy = rot.x * rot.y;
	float xz = rot.x * rot.z;
	float xw = rot.x * rot.w;

	float yz = rot.y*rot.z;
	float yw = rot.y*rot.w;

	float zw = rot.z*rot.w;

	Mat4x4T!T m = { d : [
		1.0f - 2.0f*y2 - 2.0f*z2, 2.0f*xy - 2.0f*zw, 2.0f*xz + 2.0f*yw, 0.0f,
		2.0f*xy + 2.0f*zw, 1.0f - 2.0f*x2 - 2.0f*z2, 2.0f*yz - 2.0f*xw, 0.0f,
		2.0f*xz - 2.0f*yw, 2.0f*yz + 2.0f*xw, 1.0f - 2.0f*x2 - 2.0f*y2, 0.0f,
		0.0f, 0.0f, 0.0f, 1.0f
    ]};
    
    return m;
}

/*
 General form of the Projection Matrix

		 uh = Cot( fov/2 ) == 1/Tan(fov/2)
		 uw / uh = 1/aspect
 
		   uw         0       0       0
			0        uh       0       0
			0         0      f/(f-n)  1
			0         0    -fn/(f-n)  0
*/
pure Mat4x4T!T
Mat4x4_OrthoProjection( T )( float width, float height, float _near, float _far )
{
    Mat4x4T!T m = Mat4x4_Identity!T();

	float  fRange = 1.0f / (_near - _far );

	m.dd[0][0] = 2.0f / width;
	m.dd[1][1] = 2.0f / height;
	m.dd[2][2] = fRange;
	m.dd[3][3] = 1.0f;

	m.dd[3][2] = fRange * _near;

    return m;
}

/*
How to calculate a view matrix:

		zaxis = normal(At - Eye)
		xaxis = normal(cross(Up, zaxis))
		yaxis = cross(zaxis, xaxis)

		xaxis.x           yaxis.x           zaxis.x          0
		xaxis.y           yaxis.y           zaxis.y          0
		xaxis.z           yaxis.z           zaxis.z          0
		- dot(xaxis, eye) - dot(yaxis, eye) - dot(zaxis, eye)  l

*/
pure Mat4x4T!T
Mat4x4_LookAtLH( T )(
    in VecT!(T,3) pos,
    in VecT!(T,3) target,
    in VecT!(T,3) up
)
{
    Mat4x4!T m = {};

	vec3 zaxis = v_normalise(target - pos);
	vec3 xaxis = v_normalise( v_cross(up, zaxis));
	vec3 yaxis = v_cross(zaxis, xaxis);

	m.dd[0][0] = xaxis.x;
	m.dd[0][1] = yaxis.x;
	m.dd[0][2] = zaxis.x;

	m.dd[1][0] = xaxis.y;
	m.dd[1][1] = yaxis.y;
	m.dd[1][2] = zaxis.y;

	m.dd[2][0] = xaxis.z;
	m.dd[2][1] = yaxis.z;
	m.dd[2][2] = zaxis.z;

	m.dd[3][0] = -v_dot(xaxis, pos);
	m.dd[3][1] = -v_dot(yaxis, pos);
	m.dd[3][2] = -v_dot(zaxis, pos);
	m.dd[3][3] = 1.0f;

    return m;
}

/*
 General form of the Projection Matrix

		 uh = Cot( fov/2 ) == 1/Tan(fov/2)
		 uw / uh = 1/aspect
 
		   uw         0       0       0
			0        uh       0       0
			0         0      f/(f-n)  1
			0         0    -fn/(f-n)  0
*/
pure Mat4x4T!T
Mat4x4_PerspectiveProjection( T ) (
    float fov,
    float aspectRatio,
    float nearDist,
    float farDist )
{
    Mat4x4T!T m = {};

	T frustumDepth = -(farDist - nearDist);
	T invDepth = 1.0f / frustumDepth;

	m.dd[1][1] = 1.0f / cast(T)(tan(0.5f * fov));
	m.dd[0][0] = m.vv[1][1] / aspectRatio;
	m.dd[2][2] = -farDist*invDepth;
	m.dd[3][2] = farDist*nearDist*invDepth;
	m.dd[2][3] = 1.0f;
	m.dd[3][3] = 0.0f;

    return m;
}

//	Create an orthonormal basis based on an input vector e0
//	Params:
//			e0 = input vector for constructing the basis. Make sure it's a unit vector
//			e1 = 2nd basis vector (output)
//			e2 = 3rd basis vector (output)
//
pure void
CreateCoordSystem( T )(
    auto ref VecT!(T,3) e0,
    out VecT!(T,3) e1,
    out VecT!(T,3) e2 
)
{
    if ( Abs( e0.x ) > Abs( e0.y ) )
    {
        e1 = v_normalise( VecT!(T,3)( -e0.z, T(0), e0.x ) );
    }
    else
    {
        e1 = v_normalise( VecT!(T,3) ( T(0), e0.z, -e0.y ) );
    }

    e2 = v_cross( e0, e1 );
}

//////////////////////////////////////////
//
//  Geometry Primitives
//
//////////////////////////////////////////


struct Ray
{
    vec3  m_origin;
    vec3  m_dir;   
}

struct AABB {
    vec3  m_min = vec3( float.max, float.max, float.max );
    vec3  m_max = vec3( -float.max, -float.max, -float.max );
}

struct Sphere
{
    vec3    m_centre;
    float   m_radius;
}

struct IntersectionResult
{
    bool    m_hit = false;
    float   m_minT = float.max;         // Parametric position along Ray where the intersection point occurs
    u64     m_index = cast(u64)-1;
    vec2    m_roots;
    vec3    m_contactNormal;
    vec3    m_contactPos;
    vec3    m_baryCoord;
}

pure vec3
Ray_AtT( in ref Ray pRay, float t )
{
    return pRay.m_origin + t*pRay.m_dir;
}