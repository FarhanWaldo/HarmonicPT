import std.math : sqrt;
import fwmath;
import interactions;
import sampling;
import scene : ScenePrimIntersection;

enum EShape 
{
    Invalid = 0, 
    Sphere,
	Triangle,
}

alias const(ShapeCommon)     CShapeCommon;
alias const(ShapeSphere)     CShapeSphere;

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

pragma(inline,true) pure @nogc @trusted nothrow
float Shape_Pdf( CShapeCommon* shape, CInteraction* refPoint, in vec3 wi )
{
    switch( shape.m_shapeType )
	{
	    case EShape.Sphere:
		    auto sphere = cast( CShapeSphere* ) shape;
			return Sphere_Pdf( sphere, refPoint, wi );

		default:
		    assert("Shape_Pdf called for unimplemented shape type ");
			return 0.0f;
	}
}

pure @nogc @safe nothrow
float Sphere_Pdf( CShapeSphere* sphere, CInteraction* refPoint, in vec3 wi )
{
	const vec3 centre = sphere.m_geo.m_centre;
	const float r     = sphere.m_geo.m_radius;
    const vec3 origin = OffsetRayOrigin( refPoint.m_pos, refPoint.m_posError, refPoint.m_normal, centre - refPoint.m_pos );

	if ((origin - centre).magnitudeSquared() <= r*r)
	{
        assert("damnit, more work to do");          
	}

	const float sinThetaMax2 = r*r/((refPoint.m_pos-centre).magnitudeSquared());
	const float cosThetaMax  = SafeSqrt( sinThetaMax2 );
	
	return UniformConePdf( cosThetaMax );
}

pragma(inline, true) pure @nogc @trusted nothrow
Interaction
Shape_Sample( CShapeCommon* shape, CInteraction* refPoint, in vec2 randomSample )
{
    switch ( shape.m_shapeType )
	{
	    case EShape.Sphere:
			auto sphere = cast( CShapeSphere* ) shape;
			return Sphere_Sample( sphere, refPoint, randomSample );

		default:
			assert("Unimplemented shape type");
			return Interaction();
	}
}

pure @nogc @safe nothrow
Interaction
Sphere_Sample( CShapeSphere* sphere, in vec2 randomSample )
{
    vec3 n = UniformSampleSphere( randomSample );
	vec3 p = sphere.m_geo.m_centre + sphere.m_geo.m_radius*n;

    auto  intx = Interaction( p, n, 0.0f /* FW_TODO::[time] */ );
	intx.m_posError = 0.00001 * p.abs(); /* FW_TODO::[precision] */ 
	
	return intx;
}

pure @nogc @safe nothrow
Interaction
Sphere_Sample( CShapeSphere* sphere, CInteraction* refPoint, in vec2 randomSample )
{
    /// F_TODO:: Implement this sampling function, then DiffuseAreaLight_SampleIrradiance
	///
    const vec3  centre = sphere.m_geo.m_centre;
    const float r      = sphere.m_geo.m_radius;
	const float r2     = r*r; // radius rsquared
    const vec3  refPos = refPoint.m_pos;
	const vec3  refPointToCentre = centre - refPos;

	const float distToRefSquared = refPointToCentre.magnitudeSquared();
	// Fallback to random, but uniform sampling of the unit sphere if ref point is inside circle
	//
	if ( distToRefSquared < r2 )
	{
	    return Sphere_Sample( sphere, randomSample );
	}


	pure @nogc @safe nothrow void
	CreateOnb( in vec3 e0, ref vec3 e1, ref vec3 e2 )
	{
	     if ( Abs( e0.x ) > Abs( e0.y ) ) {
		     e1 = v_normalise( vec3( -e0.z, 0.0f, e0.x ) ); 
		 }
		 else {
		     e1 = v_normalise( vec3( 0.0f, e0.z, -e0.y ) );  
		 }

		 e2 = v_cross( e0, e1 );
	}
	// Create a coordinate system where the z axis faces from the ref point
	//   to the centre of the sphere
	//
	vec3 _y, _x;
	const vec3 _z = v_normalise( refPointToCentre );
	CreateOnb( _z, _x, _y );

    const vec2 u = randomSample;

	//  Find sin and cos of theta for the right-angle triangle formed from the centre of the sphere
	//   with a line joining the centre and ref point, and the centre to a point on the radius of the sphere,
	//      perpendicular to the other line
	//
	//  This gives us the max range of theta for the cone subtended from the refPoint to the sphere
	//
	const float sinThetaMax2 = r*r/distToRefSquared;
	const float cosThetaMax  = sqrt( Max( 0.0f, 1.0f - sinThetaMax2 ) );
	const float cosTheta     = (1.0f - u.x) + u.x*cosThetaMax;
	const float sinTheta     = sqrt( Max( 0.0f, 1.0f - cosTheta*cosTheta ) );
	const float phi          = u.y * TAU;

	const float distToCentre = sqrt( distToRefSquared ); // distToRef and disToCentre are interchangeable
	const float distToSurface =
	    distToCentre*cosTheta - sqrt( Max(0.0f, r2 - distToCentre*distToCentre*sinTheta*sinTheta) );
		
    const float cosAlpha =
	    ( distToCentre*distToCentre + r2 - distToSurface*distToSurface ) /
		( 2.0f*distToCentre*r );
    const float sinAlpha = sqrt( Max( 0.0f, 1.0f - cosAlpha*cosAlpha ) );

	import std.math : sin, cos;
	//  Use above basis vectors to determine world space normals s
    //  
    //  Note::  { _x, _y, _z } is a orthonormal basis centred around the ref point
    //          { -_x, -_y, -_z } is an equivalent basis centred around a point lying on the sphere
    //
	//
	const vec3 sphereN =
	    cosTheta*sin(phi)*(-1.0f*_x) +
		sinTheta*sin(phi)*(-1.0f*_y) +
		cos(phi)         *(-1.0f*_z);

    vec3 sphereP = r * sphereN;
	sphereP *= r/(sphereP.magnitude()); // apply some numerical correction...

	const vec3 pError = 0.0001f * sphereP.abs(); /* FW_TODO::[precision] */

    const vec3 offsetSphereP = sphereP + centre + 0.001*sphereN;
	
    auto intx = Interaction( offsetSphereP , sphereN, 0.0f /* FW_TODO::[time] */ );
	intx.m_posError = pError;
	
	return intx;
}


pure @trusted @nogc nothrow
void Shape_GetShadingInfo( CShapeCommon* shape, ref SurfaceInteraction surfIntx, in ScenePrimIntersection primInt )
{
   switch ( shape.m_shapeType )
	{
	    case EShape.Sphere:
			auto sphere = cast( CShapeSphere* ) shape;
			return Sphere_GetShadingInfo( sphere, surfIntx, primInt.m_intRes );

		default:
			assert("Unimplemented shape type");
	}
}


pure @safe @nogc nothrow
void Sphere_GetShadingInfo( CShapeSphere* sphere, ref SurfaceInteraction surfIntx, in IntersectionResult intRes )
{
	const vec3 p = intRes.m_contactNormal; // intersection point on a unit sphere in origin

	import std.math : atan2, asin, fmod;
	// defines the angle on the X-Z plane, going counter clockwise from +X axis; domain: [ 0, 2*pi )
    float phi = atan2( p.z, p.x );
    // defines the angle on the X-Y plane, going counter clockwise from the +X axis; domain: [ -pi/2, pi/2 ]
    const float theta = asin( p.y );

    if ( phi < 0.0f ) phi += TAU;

    const vec2 uv = vec2( phi / TAU, ( theta + PI/2.0f ) / PI );

	const float sinTheta = p.y;
	const float cosTheta = SafeSqrt( 1.0f - sinTheta*sinTheta );
	const float cosPhi   = p.x/cosTheta;
	const float sinPhi   = p.z/cosTheta;

	/// first-order derivatives (of surface parameterisation)
	///
	const vec3 dpdu = vec3( -sinTheta*cosPhi, cosTheta, -sinTheta*sinPhi );
	const vec3 dpdv = vec3( -cosTheta*sinPhi, 0.0f, cosTheta*cosPhi );

	/// second-order derivatives
	///
	const vec3 d2pdu2 = vec3( -cosTheta*cosPhi, -sinTheta, -cosTheta*sinPhi );
	const vec3 d2pduv = vec3( sinTheta*sinPhi, 0.0f, -sinTheta*cosPhi );
	const vec3 d2pdv2 = vec3( -cosTheta*cosPhi, 0.0f, -cosTheta*sinPhi );

	///  First fundamental forms
	///
	const float E = v_dot( dpdu, dpdu );
	const float F = v_dot( dpdu, dpdv );
	const float G = v_dot( dpdv, dpdv );

	const vec3 normal = v_normalise( v_cross( dpdu, dpdv ) );

	///  Second fundamental forms
	///
	const float e = v_dot( normal, d2pdu2 );
	const float f = v_dot( normal, d2pduv );
	const float g = v_dot( normal, d2pdv2 );

	const float invDet = 1.0f/( E*G - F*F ); // inverse determinant for second fundamental form
	const vec3 dndu = (f*F - e*G)*invDet*dpdu + (e*F - f*E)*invDet*dpdv;
	const vec3 dndv = (g*F - f*G)*invDet*dpdu + (f*F - g*E)*invDet*dpdv;

	surfIntx = SurfaceInteraction( intRes.m_contactPos, uv, normal,
								   dpdu, dpdv,
								   dndu, dndv,
								   0.0f /* time */ );

	surfIntx.m_posError = 0.0001* intRes.m_contactPos.abs();
	
	
}
