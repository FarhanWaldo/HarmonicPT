import std.stdio;
import std.math : tan;
import fwmath;

struct Camera
{
    vec3        m_eyePos;
    vec3        m_lookDirection;
    vec3        m_up;
    vec3        m_right;

    float       m_aspectRatio;
    float       m_vertFoV;
    float       m_near;
    float       m_far;
};

pure void
Camera_Init(
    ref  Camera camera,
    vec3 eyePos,
    vec3 up,
    vec3 lookAt,
    float aspectRatio,
    float vertFoV,
    float near,
    float far )
{
    vec3 lookDir = v_normalise( lookAt - eyePos );

    camera.m_eyePos         = eyePos;
    camera.m_lookDirection  = lookDir;
    camera.m_up             = v_normalise( up );
    camera.m_right          = v_normalise( v_cross( up, lookDir ) );

    camera.m_aspectRatio    = aspectRatio;
    camera.m_vertFoV        = vertFoV;
    camera.m_near           = near;
    camera.m_far            = far;
}

void
SpawnRay(
    in ref Camera pCamera,
    in ref vec2 pixelCoord,
    in ref vec2 windowSize,
    ref Ray ray )
{
    float halfHeight = float( tan( pCamera.m_vertFoV / 2.0f ) );
    float halfWidth  = halfHeight * pCamera.m_aspectRatio;

    float near = pCamera.m_near;

    // Lower-Left Corner
    vec3 LLC =     pCamera.m_eyePos
                +  ( near * pCamera.m_lookDirection)
		        -  ( halfWidth * near * pCamera.m_right )
                -  ( halfHeight * near * pCamera.m_up )
				;
    
    // Normalise the pixel coord using the window size
    //
    vec2 ndcPixelCoord = vec2(
        pixelCoord.x / windowSize.x,
        1.0f - ( pixelCoord.y / windowSize.y ) );

    vec3 horizontal = 2.0f * halfWidth * near * pCamera.m_right;
    vec3 vertical   = 2.0f * halfHeight * near * pCamera.m_up;

    ray = Ray(
        pCamera.m_eyePos,
        v_normalise( LLC + ndcPixelCoord.x*horizontal + ndcPixelCoord.y*vertical - pCamera.m_eyePos ) );
}
