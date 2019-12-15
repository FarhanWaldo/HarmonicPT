import fwmath;
import material;
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

    bool IntersectsRay( in ref Ray, out ScenePrimIntersection );

    // F_TODO:: Should this be in the interface?
    IMaterial* GetMaterial();
}

class SurfacePrim : IPrimitive
{
    BaseShape*      m_shape;
    IMaterial*      m_material;

    PrimType  GetPrimType() { return PrimType.kSurface; }
    AABB ComputeBBox() { return AABB(); }
    IMaterial* GetMaterial() { return m_material; }

    BaseShape* GetShape() { return m_shape; }


    bool IntersectsRay( in ref Ray, out ScenePrimIntersection )
    {
        return false; // STUB
    }
}

// class EmissiveSurfacePrim : IPrimitive
// {
// }3 ce