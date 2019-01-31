//
//   Copyright 2018 Pixar
//
//   Licensed under the Apache License, Version 2.0 (the "Apache License")
//   with the following modification; you may not use this file except in
//   compliance with the Apache License and the following modification to it:
//   Section 6. Trademarks. is deleted and replaced with:
//
//   6. Trademarks. This License does not grant permission to use the trade
//      names, trademarks, service marks, or product names of the Licensor
//      and its affiliates, except as required to comply with Section 4(c) of
//      the License and to reproduce the content of the NOTICE file.
//
//   You may obtain a copy of the Apache License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the Apache License with the above modification is
//   distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//   KIND, either express or implied. See the Apache License for the specific
//   language governing permissions and limitations under the Apache License.
//

//----------------------------------------------------------
// Patches.VertexGregoryTriangle
//----------------------------------------------------------
#ifdef OSD_PATCH_VERTEX_GREGORY_TRIANGLE_SHADER

layout(location = 0) in vec4 position;
OSD_USER_VARYING_ATTRIBUTE_DECLARE

out block {
    ControlVertex v;
    OSD_USER_VARYING_DECLARE
} outpt;

void main()
{
    outpt.v.position = position;
    OSD_PATCH_CULL_COMPUTE_CLIPFLAGS(position);
    OSD_USER_VARYING_PER_VERTEX();
}

#endif

//----------------------------------------------------------
// Patches.TessControlGregoryTriangle
//----------------------------------------------------------
#ifdef OSD_PATCH_TESS_CONTROL_GREGORY_TRIANGLE_SHADER

patch out vec4 tessOuterLo, tessOuterHi;

in block {
    ControlVertex v;
    OSD_USER_VARYING_DECLARE
} inpt[];

out block {
    OsdPerPatchVertexBezier v;
    OSD_USER_VARYING_DECLARE
} outpt[18];

layout(vertices = 18) out;

void main()
{
    vec3 cv = inpt[gl_InvocationID].v.position.xyz;

    ivec3 patchParam = OsdGetPatchParam(OsdGetPatchIndex(gl_PrimitiveID));

    outpt[gl_InvocationID].v.patchParam = patchParam;
    outpt[gl_InvocationID].v.P          = cv;

    OSD_USER_VARYING_PER_CONTROL_POINT(gl_InvocationID, gl_InvocationID);

#if defined OSD_ENABLE_SCREENSPACE_TESSELLATION
    // Wait for all basis conversion to be finished
    barrier();
#endif
    if (gl_InvocationID == 0) {
        vec4 tessLevelOuter = vec4(0);
        vec2 tessLevelInner = vec2(0);

        OSD_PATCH_CULL(18);

        OsdGetTessLevelsUniformTriangle(patchParam,
                         tessLevelOuter, tessLevelInner,
                         tessOuterLo, tessOuterHi);

#if defined OSD_ENABLE_SCREENSPACE_TESSELLATION
        // Gather bezier control points to compute limit surface tess levels
        vec3 cv[15];
        cv[ 0] = outpt[ 0].v.P;
        cv[ 1] = outpt[ 1].v.P;
        cv[ 2] = outpt[15].v.P;
        cv[ 3] = outpt[ 7].v.P;
        cv[ 4] = outpt[ 5].v.P;
        cv[ 5] = outpt[ 2].v.P;
        cv[ 6] = outpt[ 3].v.P;
        cv[ 7] = outpt[ 8].v.P;
        cv[ 8] = outpt[ 6].v.P;
        cv[ 9] = outpt[17].v.P;
        cv[10] = outpt[13].v.P;
        cv[11] = outpt[16].v.P;
        cv[12] = outpt[11].v.P;
        cv[13] = outpt[12].v.P;
        cv[14] = outpt[10].v.P;

        OsdEvalPatchBezierTriangleTessLevels(
		         cv, patchParam,
                         tessLevelOuter, tessLevelInner,
                         tessOuterLo, tessOuterHi);
#else
        OsdGetTessLevelsUniformTriangle(patchParam,
                        tessLevelOuter, tessLevelInner,
                        tessOuterLo, tessOuterHi);

#endif

        gl_TessLevelOuter[0] = tessLevelOuter[0];
        gl_TessLevelOuter[1] = tessLevelOuter[1];
        gl_TessLevelOuter[2] = tessLevelOuter[2];

        gl_TessLevelInner[0] = tessLevelInner[0];
    }
}

#endif

//----------------------------------------------------------
// Patches.TessEvalGregoryTriangle
//----------------------------------------------------------
#ifdef OSD_PATCH_TESS_EVAL_GREGORY_TRIANGLE_SHADER

layout(triangles) in;
layout(OSD_SPACING) in;

patch in vec4 tessOuterLo, tessOuterHi;

in block {
    OsdPerPatchVertexBezier v;
    OSD_USER_VARYING_DECLARE
} inpt[];

out block {
    OutputVertex v;
    OSD_USER_VARYING_DECLARE
} outpt;

void main()
{
    vec2 UV = OsdGetTessParameterizationTriangle(gl_TessCoord.xy,
                                                 tessOuterLo,
                                                 tessOuterHi);

    vec3 P = vec3(0), dPu = vec3(0), dPv = vec3(0);
    vec3 N = vec3(0), dNu = vec3(0), dNv = vec3(0);

    vec3 cv[18];
    for (int i = 0; i < 18; ++i) {
        cv[i] = inpt[i].v.P;
    }

    ivec3 patchParam = inpt[0].v.patchParam;
    OsdEvalPatchGregoryTriangle(patchParam, UV, cv, P, dPu, dPv, N, dNu, dNv);

    // all code below here is client code
    outpt.v.position = OsdModelViewMatrix() * vec4(P, 1.0f);
    outpt.v.normal = (OsdModelViewMatrix() * vec4(N, 0.0f)).xyz;
    outpt.v.tangent = (OsdModelViewMatrix() * vec4(dPu, 0.0f)).xyz;
    outpt.v.bitangent = (OsdModelViewMatrix() * vec4(dPv, 0.0f)).xyz;
#ifdef OSD_COMPUTE_NORMAL_DERIVATIVES
    outpt.v.Nu = dNu;
    outpt.v.Nv = dNv;
#endif

    outpt.v.tessCoord = UV;
    outpt.v.patchCoord = OsdInterpolatePatchCoordTriangle(UV, patchParam);

    OSD_USER_VARYING_PER_EVAL_POINT_TRIANGLE(UV, 0, 5, 10);

    OSD_DISPLACEMENT_CALLBACK;

    gl_Position = OsdProjectionMatrix() * outpt.v.position;
}

#endif
