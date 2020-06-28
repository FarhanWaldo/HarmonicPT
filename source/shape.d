import std.math : sqrt;
import fwmath;
import interactions;

enum EShape 
{
    Invalid = 0, 
    Sphere,
	Triangle,
}

struct ShapeCommon
{
    EShape m_shapeType;

	enum IsShape = true;
}

struct ShapeSphere
{
    ShapeCommon m_common;
	alias m_common this;

    Sphere m_geo;

	this( vec3 centre, float radius )
	{
	    m_shapeType = EShape.Sphere;
		m_geo.m_centre = centre;
		m_geo.m_radius = radius;
	}
	
}

pure @nogc @trusted nothrow
AABB Shape_ComputeBBox(T)( T* shape )
{
    static assert ( T.IsShape, "Did not pass in a type that is a shape" );

	if ( shape.m_shapeType == EShape.Sphere )
	{
		auto sph = cast( ShapeSphere* ) shape;
		return AABB( sph.m_geo.m_centre - vec3( sph.m_geo.m_radius ),
		             sph.m_geo.m_centre + vec3( sph.m_geo.m_radius ) );
	}
	else
	{
	    return AABB();
	}
}


pure @nogc @trusted nothrow
bool Shape_IntersectsRay(T)( const(T)* shape, const(Ray)* ray, ref IntersectionResult intxRes )
{
    static assert ( T.IsShape, "Did not pass in a type that is a shape" );

	if ( shape.m_shapeType == EShape.Sphere )
	{
		auto sphere = cast( const(ShapeSphere)* ) shape;
		return Sphere_IntersectsRay( sphere, ray, intxRes );
	}
	else
	{
	    assert( false, "Invalid shape" );
	}
}

pure @nogc @safe nothrow
bool Sphere_IntersectsRay( const(ShapeSphere)* shpSphere, const(Ray)* ray, ref IntersectionResult intxRes )
{
        immutable float radius = shpSphere.m_geo.m_radius;
		immutable vec3  centre = shpSphere.m_geo.m_centre;

        bool intersects = false;
        float tMin = Min( ray.m_maxT, intxRes.m_minT );

        immutable vec3 oc = ray.m_origin - centre;
        // Co-efficients of quadratic
        immutable float a = v_dot( ray.m_dir, ray.m_dir );
        immutable float b = v_dot( oc, ray.m_dir );
        immutable float c = v_dot( oc, oc ) - radius * radius;
        immutable float discriminant = b*b - a*c; // TODO:: Use Kahn's formulae with FMA to increase precision here

        if ( discriminant > 0.0f ) 
        {
            float sqrtDiscriminant =  sqrt( discriminant );
            float invA = 1.0f/a;
            float temp = ( -1.0f*b - sqrtDiscriminant )*invA;

            if ( temp > 0.0f && temp < tMin )
            {
                tMin = temp;
                intersects = true;
            }

            temp = ( -1*b + sqrtDiscriminant ) * invA;
            if ( temp > 0.0f && temp < tMin )
            {
                tMin = temp;
                intersects = true;
            }
        }

        if ( intersects )
        {
            vec3 intersectP = Ray_AtT( *ray, tMin );

            intxRes.m_hit = true;
            intxRes.m_minT = tMin;
            intxRes.m_index = 0; // TODO:: This feels unnecessary
            // intRes.m_roots
            intxRes.m_contactPos = intersectP;
            intxRes.m_contactNormal = v_normalise( intersectP - centre );
        }

        return intersects;

}
