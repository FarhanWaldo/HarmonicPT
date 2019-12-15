import fwmath;
import interactions;

/**
    Abstract Base Class for any geometry we want to have ray intersections against.
    Concrete instances of BaseShape should be able to plug into SurfacePrim or EmissiveSurfacePrim

*/
abstract class BaseShape
{
    AABB ComputeBBox();

    bool IntersectsRay( in ref Ray, out IntersectionResult );

    pure const float GetArea();


    // TODO:: Might be worth creating an EmissiveBaseShape for area light sources, could be significant memory reduction in practice

    ////
    //  Methods for sampling area light sources
    ////

    //  Default to a probability distribution for uniformly sampling the surface of the shape
    //
    pure const float
    EvalPDF( in ref Interaction )
    {
        return 1.0f/this.GetArea();
    }

    //  Evaluate 
    //
    pure const float EvalPDF( in ref Interaction, in ref vec3 wi );

    /**
        Generate an interaction object for a random sample on the shape
        Params:
            u = a 2D random generated number, u s in [0,1]^2
            newIntx = The generated interaction object on the surface of this shape
    */
    pure const void Sample( in ref vec2 u, out Interaction newIntx );

    /**
        Generate an interaction object for a random point on the shape, given a reference point
        Params:
            refPoint = A reference point in the world, so we can generate an interaction with respect to this reference point.
            u = a 2D random generated number, u is in [0,1]^2
            newIntx = The generated interaction object on the surface of this shape
    */
    pure const void Sample( in ref Interaction refPoint, in ref vec2 u, out Interaction newIntx );

}

class ShapeSphere : BaseShape
{
    Sphere m_sphere;

    this( vec3 centre, float radius )
    {
        m_sphere = Sphere( centre, radius );
    }

    override AABB
    ComputeBBox()
    {
        return AABB( 
            m_sphere.m_centre - vec3( m_sphere.m_radius ) , // min
            m_sphere.m_centre + vec3( m_sphere.m_radius ) // max
        );
    }

    /// Return surface area of sphere primitive
    override pure const float
    GetArea()
    {
        return 4.0f*PI* m_sphere.m_radius*m_sphere.m_radius;
    }

    override pure const float
    EvalPDF( in ref Interaction, in ref vec3 wi )
    {
        return 0.0f; // STUB
    }

    override pure const void
    Sample( in ref vec2 u, out Interaction newIntx )
    {
        // return Interaction(); // STUB
    }

    override pure const void
    Sample( in ref Interaction refPoint, in ref vec2 u, out Interaction newIntx )
    {
        // return Interaction(); // STUB
    }

    override bool
    IntersectsRay( in ref Ray, out IntersectionResult intRes )
    {
        return false;
    }
}