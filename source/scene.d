import fwmath;
import material;
import light;
import shape;
import interactions;

alias const(PrimCommon)  CPrimCommon;

struct ScenePrimIntersection
{
    IntersectionResult      m_intRes;
    // IPrimitive*             m_prim;
    CPrimCommon*            m_prim;
    IMaterial*              m_material;
}

enum PrimType
{
    kNone=0,
    kSurface,
    kEmissiveSurface,
    kAggregate
}

struct PrimCommon
{
	PrimType    m_primType;
	enum        IsPrim = true;

	pure const @nogc @safe nothrow
	PrimType    GetPrimType() { return m_primType; }
}

struct SurfacePrim
{
	PrimCommon  m_common = { PrimType.kSurface };
	alias m_common this;

    ShapeCommon* m_shape;
	IMaterial*   m_material;

	this( ShapeCommon* shape, IMaterial* material )
	{
	    m_common.m_primType  = PrimType.kSurface;
		m_shape     = shape;
		m_material  = material;
	}
}

struct EmissiveSurfacePrim
{
	PrimCommon m_common = { PrimType.kEmissiveSurface };
	alias m_common this;

	ShapeCommon*     m_shape;
	IMaterial*       m_material; /// F_TODO:: Do emissive prims have materials? Emissive shaders?	
	BaseAreaLight*   m_light;

	this( ShapeCommon* shape, IMaterial* material, BaseAreaLight* light )
	{
		m_shape     = shape;
		m_material  = material;
		m_light     = light;
	}
}

struct PrimArray
{
	PrimCommon m_common = { PrimType.kAggregate };
	alias m_common this;

	
    PrimCommon*[] m_prims;

	this( PrimCommon*[] prims )
	{
		m_prims = prims;
	}
	
    enum isAggregatePrim = true;
	pure const @nogc @safe nothrow
	bool AnyIntersection( const(Ray)* ray )
	{
		ScenePrimIntersection primIntx;

		foreach ( prim; m_prims )
		{
		    if ( Prim_IntersectsRay( prim, ray, primIntx ) ) {
			    return true;
			}
		}

		return false;
	}

	pure const @nogc @safe nothrow
	bool ClosestIntersection( const(Ray)* ray, ref ScenePrimIntersection scenePrimIntx )
	{
	    bool anIntersectionOccurred = false;

        foreach ( prim; m_prims )
		{
		    anIntersectionOccurred |= Prim_IntersectsRay( prim, ray, scenePrimIntx );
		}
		
		return anIntersectionOccurred;
	}
	
}

pragma(inline, true) pure @nogc @trusted nothrow
AABB Prim_ComputeBBox(T)( const(T)* prim )
{
	static assert ( prim.IsPrim, "Did not pass in a valid prim object" );

	ShapeCommon* shape = void;
	if ( prim.GetPrimType() == PrimType.kSurface ) {
	    auto surfPrim = cast( SurfacePrim* ) prim;
		shape = surfPrim.m_shape;
	}
	else if ( prim.GetPrimType() == PrimType.kEmissiveSurface ) {
	    auto emissivePrim = cast( EmissiveSurfacePrim* ) prim;
		shape = emissivePrim.m_shape;
	}
	else {
	    assert ( false, "Invalid prim type" );
	}

	return Shape_ComputeBBox( shape );
}



pragma(inline, true) pure @nogc @trusted nothrow
IMaterial*
Prim_GetMaterial( const(PrimCommon)* prim )
{
    PrimType type = prim.GetPrimType();

	switch ( type )
	{			
    	case PrimType.kSurface:
		    auto surfPrim = cast( SurfacePrim* ) prim;
		    return surfPrim.m_material;

		case PrimType.kEmissiveSurface:
		    auto emissivePrim = cast( EmissiveSurfacePrim* ) prim;
			return emissivePrim.m_material;

			
		default:
		    return null;			
	}
}

pragma(inline, true) pure @nogc @trusted nothrow
ShapeCommon*
Prim_GetShape( const(PrimCommon)* prim )
{
    switch ( prim.GetPrimType() )
	{
	    case PrimType.kSurface:
		    auto surfPrim = cast( SurfacePrim* ) prim;
			return surfPrim.m_shape;
		case PrimType.kEmissiveSurface:
		    auto emissivePrim = cast( EmissiveSurfacePrim* ) prim;
			return emissivePrim.m_shape;

		default:
		    return null;
	}
}

pragma(inline, true) pure @nogc @trusted nothrow
bool
Prim_IntersectsRay( const(PrimCommon)* prim, const(Ray)* ray, ref ScenePrimIntersection primIntx )
{
    ShapeCommon* shape = Prim_GetShape( prim );
	if ( shape == null ||
	     !Shape_IntersectsRay( shape, ray, primIntx.m_intRes )) {
		 return false;
	}

    //    We have a valid shape and have intersected against the ray (closest intersection)
	//
	primIntx.m_material = Prim_GetMaterial( prim );
	primIntx.m_prim = prim;
	
	return true;
}


pragma(inline, true) pure @nogc @trusted nothrow
BaseAreaLight*
Prim_GetLight( PrimCommon* prim, Ray* ray, ref ScenePrimIntersection primIntx )
{
	switch ( prim.GetPrimType() )
	{
		default:
			return null;

		case PrimType.kEmissiveSurface:
		    auto emissivePrim = cast( EmissiveSurfacePrim* ) prim;
			return emissivePrim.m_light;
	}
}


/**
    Stores the primitives and lighting infornation.
*/
struct Scene
{
    // IAggregatePrim      m_rootPrim;
	PrimArray           m_rootPrim;
    ILight*[]           m_lights;
}

bool
FindClosestIntersection( const(Scene)* scene, in ref Ray ray, ref SurfaceInteraction surfIntx )
{
    ScenePrimIntersection primIntx;
	bool intersectionFound = scene.m_rootPrim.ClosestIntersection( &ray, primIntx );

    if ( intersectionFound )
	{
	    PrimType primType = primIntx.m_prim.GetPrimType();

		// TODO:: Get shading info for shape

   		surfIntx.m_prim     = primIntx.m_prim;
		surfIntx.m_material = primIntx.m_material;
		surfIntx.m_wo       = -1 * ray.m_dir;
	}
	/* TODO:: MEDIUM INTERACTION
	else
	{
	}
    */
	
	// bool intersectionFound = 
/*
    ScenePrimIntersection primIntx;
    bool intersectionFound = scene.m_rootPrim.IntersectsRay( ray, primIntx );

    if ( intersectionFound )
    {
        if ( is( typeof( primIntx.m_prim ) == SurfacePrim ) )
        {
            const BaseShape* shape = ( cast( SurfacePrim* )primIntx.m_prim ).GetShape();
            if ( shape != null )
            {
                shape.GetShadingInfo(  primIntx.m_intRes, surfIntx );
            }

            surfIntx.m_prim         = primIntx.m_prim;
            surfIntx.m_material     = primIntx.m_material;
            surfIntx.m_wo           = -1.0f * ray.m_dir;
        }
        else
        {
            // TODO:: Medium intersection
        }
    }
*/
    return intersectionFound;
}

bool
FindAnyIntersection( Scene* scene,  const(Ray)* ray )
{
    return scene.m_rootPrim.AnyIntersection( ray );
}
