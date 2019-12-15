import fwmath;
import material;
import light;
import shape;

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
    Represents any surface boundary in the world, and can have a material attached.
    The material will describe the scattering properties of the surface represented by the prim.

    This surface CANNOT be emissive. Use EmissiveSurfacePrim for that (usually area lights).
*/
class SurfacePrim : IPrimitive
{
    BaseShape*      m_shape;
    IMaterial*      m_material;

    PrimType  GetPrimType() { return PrimType.kSurface; }
    AABB ComputeBBox() { return m_shape.ComputeBBox(); }
    IMaterial* GetMaterial() { return m_material; }

    BaseShape* GetShape() { return m_shape; }


    bool IntersectsRay( in ref Ray ray, out ScenePrimIntersection primInt )
    {
        if ( m_shape.IntersectsRay( ray, primInt.m_intRes ) )
        {
            primInt.m_material = m_material;
            primInt.m_prim = cast( IPrimitive* ) this;

            return true;
        }

        return false;
    }
}

/**
    Used to represent a surface boundary that emits light in the upper hemisphere oriented around its normal.
*/
class EmissiveSurfacePrim : SurfacePrim
{
    BaseAreaLight* m_areaLight;

    final BaseAreaLight* GetAreaLight() { return m_areaLight; }

    override PrimType GetPrimType()  {  return PrimType.kEmissiveSurface; }
}