import std.math;

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
    opMul( float scalar )
    {
        return vec3( x*scalar, y*scalar, z*scalar );
    }

    pure const vec3
    opAdd( vec3 v2 )
    {
        return vec3( x + v2.x, y + v2.y, z + v2.z );
    }

    pure const vec3 
    opSub( vec3 v2 )
    {
        return vec3( x - v2.x, y - v2.y, z - v2.z );
    }

    pure const vec3
    opDiv( float scalar )
    {
        float invScalar =  1.0f/scalar;
        return vec3( x*invScalar, y*invScalar, z*invScalar );
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
    vec3  m_origin  = {};
    vec3  m_dir     = {};
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