import fwmath;
import material;
import light;
import shape;
import interactions;

struct ScenePrimIntersection
{
    IntersectionResult      m_intRes;
    IPrimitive*             m_prim;
    IMaterial*              m_material;
}

enum PrimType
{
    kNone,
    kSurface,
    kEmissiveSurface,
    kAggregate
}

interface IPrimitive
{
    PrimType GetPrimType(); // Probably better just to have a member for this

    AABB ComputeBBox();

    /**
        Computes whether this primitive has the closest intersection with the ray computed so far
    */
    bool IntersectsRay( in ref Ray, out ScenePrimIntersection );

    // F_TODO:: Should this be in the interface?
    IMaterial* GetMaterial();
}

/**
    This interface is a useful abstraction for building acceleration structures over
    the entire scene's primitives.
*/
interface IAggregatePrim : IPrimitive
{
    /**
        Returns whether the ray intersections any prims at all, useful for occlusion queries
    */
    bool AnyIntersection( in ref Ray );
}

/**
    A flat array of primitives. No acceleration behind this acceleration structure...
    a brute force linear search
*/
class PrimList : IAggregatePrim
{
    IPrimitive[]       m_prims;

    // TODO:: Is this even necessary with runtime type info?
    override PrimType   GetPrimType() { return PrimType.kAggregate; }
    override AABB       ComputeBBox() { return AABB(); }
    override IMaterial* GetMaterial() { return null; }

    override bool
    IntersectsRay( in ref Ray ray, out ScenePrimIntersection scenePrimIntx )
    {
        bool intersectionOccurred = false;

        foreach ( prim; m_prims )
        {
            intersectionOccurred |= prim.IntersectsRay( ray, scenePrimIntx );
        }


        return intersectionOccurred;
    }

    override bool
    AnyIntersection( in ref Ray ray )
    {
        ScenePrimIntersection primIntx;

        foreach ( prim; m_prims )
        {
            if ( prim.IntersectsRay( ray, primIntx ) )
            {
                return true;
            }
        }

        return false;
    }

    this( IPrimitive[] prims )
    {
        m_prims = prims;

		// foreach( prim; prims )
	    // {
		//     import std.stdio;
		// 	writeln( *((cast( SurfacePrim ) prim).m_shape) );
		// }
    }
}

/**
    Represents any surface boundary in the world, and can have a material attached.
    The material will describe the scattering properties of the surface represented by the prim.

    This surface CANNOT be emissive. Use EmissiveSurfacePrim for that (usually area lights).
*/
class SurfacePrim : IPrimitive
{
    BaseShape*  m_shape;
    IMaterial*  m_material;

    PrimType    GetPrimType() { return PrimType.kSurface; }
    AABB        ComputeBBox() { return m_shape.ComputeBBox(); }
    IMaterial*  GetMaterial() { return m_material; }

    BaseShape*  GetShape() { return m_shape; }

    override bool
    IntersectsRay( in ref Ray ray, out ScenePrimIntersection primInt )
    {
        if ( m_shape.IntersectsRay( ray, primInt.m_intRes ) )
        {
            primInt.m_material = m_material;
            primInt.m_prim = cast( IPrimitive* ) this;

            return true;
        }

        return false;
    }

    this( BaseShape* shape, IMaterial* material )
    {
        m_shape = shape;
        m_material = material;
    }
}

/**
    Used to represent a surface boundary that emits light in the upper hemisphere oriented around its normal.
*/
class EmissiveSurfacePrim : SurfacePrim
{
    BaseAreaLight*          m_areaLight;

    final BaseAreaLight*    GetAreaLight() { return m_areaLight; }
    override PrimType       GetPrimType()  { return PrimType.kEmissiveSurface; }

    this( BaseShape* shape, IMaterial* material, BaseAreaLight* areaLight )
    {
        super( shape, material );
        m_areaLight = areaLight;
    }
}


/**
    Stores the primitives and lighting infornation.
*/
struct Scene
{
    IAggregatePrim      m_rootPrim;
    ILight*[]           m_lights;
}

bool
FindClosestIntersection( Scene* scene, in ref Ray ray, out SurfaceInteraction surfIntx )
{
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

    return intersectionFound;
}

bool
FindAnyIntersection( Scene* scene, in ref Ray ray )
{
    return scene.m_rootPrim.AnyIntersection( ray );
}
