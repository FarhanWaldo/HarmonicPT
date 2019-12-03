import std.stdio;
import fwmath;

struct Camera
{
    vec3        m_eyePos;
    vec3        m_lookDirection;
    vec3        m_up;
    vec3        m_right;    
};

pure void
Camera_Init( out  Camera camera,
                  vec3 eyePos,
                  vec3 up,
                  vec3 lookAt )
{
    vec3 lookDir = v_normalise( lookAt - eyePos );

    camera.m_eyePos         = eyePos;
    camera.m_lookDirection  = lookDir;
    camera.m_up             = up;
    camera.m_right          = v_cross( up, lookDir );
}