local render = ... or _G.render

render.csm_count = 4

local PASS = {}

PASS.Buffers = {
	{
		name = "model",
		write = "all",
		layout =
		{
			{
				format = "rgba16f",

				albedo = "rgb",
				roughness = "a",
			},
			{
				format = "rgba16f",

				view_normal = "rgb",
				metallic = "a",
			},
		}
	},
	{
		name = "light",
		write = "self",
		layout =
		{
			{
				format = "rgba16f",

				specular = "rgb",
				shadow = "a",
			}
		},
	}
}

render.AddGlobalShaderCode([[
float random(vec2 co)
{
	return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}]])

render.AddGlobalShaderCode([[
vec3 get_noise2(vec2 uv)
{
	return vec3(random(uv), random(uv*23.512), random(uv*6.53330));
}]])

render.AddGlobalShaderCode([[
vec3 get_noise3(vec2 uv)
{
	float x = random(uv);
	float y = random(uv*x);
	float z = random(uv*y);

	return vec3(x,y,z) * 2 - 1;
}]])

render.AddGlobalShaderCode([[
vec4 get_noise(vec2 uv)
{
	return texture(g_noise_texture, uv);
}]])

render.AddGlobalShaderCode([[
vec2 get_screen_uv()
{
	return gl_FragCoord.xy / g_gbuffer_size;
}]])

render.AddGlobalShaderCode([[
vec3 get_view_pos(vec2 uv)
{
	vec4 pos = g_projection_inverse * vec4(uv * 2.0 - 1.0, texture(tex_depth, uv).r * 2 - 1, 1.0);
	return pos.xyz / pos.w;
}]])

render.AddGlobalShaderCode([[
vec3 get_world_pos(vec2 uv)
{
	vec4 pos = g_view_inverse * g_projection_inverse * vec4(uv * 2.0 - 1.0, texture(tex_depth, uv).r * 2 - 1, 1.0);
	return pos.xyz / pos.w;
}]])

render.AddGlobalShaderCode([[
vec3 get_view_normal_from_depth(vec2 uv)
{
	const vec2 offset1 = vec2(0.0,0.001);
	const vec2 offset2 = vec2(0.001,0.0);

	float depth = texture(tex_depth, uv).r;
	float depth1 = texture(tex_depth, uv + offset1).r;
	float depth2 = texture(tex_depth, uv + offset2).r;

	vec3 p1 = vec3(offset1, depth1 - depth);
	vec3 p2 = vec3(offset2, depth2 - depth);

	vec3 normal = cross(p1, p2);
	normal.z = -normal.z;

	return normalize(normal);
}]])

render.AddGlobalShaderCode([[
vec3 get_world_normal(vec2 uv)
{
	return (-get_view_normal(uv) * mat3(g_view));
}]])

render.AddGlobalShaderCode([[
vec3 get_view_tangent(vec2 uv)
{
	vec3 norm = get_view_normal(uv);
	vec3 tang = abs(norm.x) < 0.999 ? vec3(1,0,0) : vec3(0,1,0);
	return normalize(cross(norm, tang));
}]])

render.AddGlobalShaderCode([[
vec3 get_world_tangent(vec2 uv)
{
	return normalize(-get_view_tangent(uv) * mat3(g_view));
}]])

render.AddGlobalShaderCode([[
vec3 get_view_bitangent(vec2 uv)
{
	return normalize(cross(get_view_normal(uv), get_view_tangent(uv)));
}]])

render.AddGlobalShaderCode([[
vec3 get_world_bitangent(vec2 uv)
{
	return normalize(-get_view_bitangent(uv) * mat3(g_view));
}]])

render.AddGlobalShaderCode([[
// http://www.geeks3d.com/20130122/normal-mapping-without-precomputed-tangent-space-vectors/
mat3 get_view_tbn(vec2 uv)
{
	vec3 N = (get_view_normal(uv));
	vec3 p = normalize(get_view_pos(uv));

	// get edge vectors of the pixel triangle
	vec3 dp1 = dFdx( p );
	vec3 dp2 = dFdy( p );
	vec2 duv1 = dFdx( uv );
	vec2 duv2 = dFdy( uv );

	// solve the linear system
	vec3 dp2perp = cross( dp2, N );
	vec3 dp1perp = cross( N, dp1 );
	vec3 T = dp2perp * duv1.x + dp1perp * duv2.x;
	vec3 B = dp2perp * duv1.y + dp1perp * duv2.y;

	// construct a scale-invariant frame
	float invmax = inversesqrt( max( dot(T,T), dot(B,B) ) );
	return mat3( T * invmax, B * invmax, N );
}]])

render.AddGlobalShaderCode([[
mat3 get_world_tbn(vec2 uv)
{
	mat3 tbn = get_view_tbn(uv);
	tbn[0] *= -mat3(g_view);
	tbn[1] *= -mat3(g_view);
	tbn[2] *= -mat3(g_view);
	return tbn;
}]])

render.AddGlobalShaderCode([[
#extension GL_ARB_texture_query_levels: enable

vec3 MMAL(samplerCube tex, vec3 normal, vec3 reflected, float roughness)
{
	vec2 size = textureSize(tex, 0);
	float levels = textureQueryLevels(tex) - 1;
	float mx = log2(roughness * size.x + 1) / log2(size.y);

	return textureLod(tex, normalize(mix(reflected, normal, roughness)), mx * levels).rgb;
}

vec3 get_env_color()
{
	float roughness = get_roughness(uv);
	float metallic = get_metallic(uv);

	vec3 cam_dir = -get_camera_dir(uv);
	vec3 sky_normal = get_world_normal(uv);
	vec3 sky_reflect = reflect(cam_dir, sky_normal).xyz;

	vec3 irradiance = MMAL(lua[tex_sky = render.GetSkyTexture()], sky_normal, sky_reflect, -metallic+1);
	vec3 reflection = MMAL(lua[tex_sky = render.GetSkyTexture()], sky_normal, sky_reflect, roughness);

	return mix((irradiance+reflection), reflection, metallic);
}
]], "get_env_color")

function PASS:Initialize()
	local META = self.model_shader:CreateMaterialTemplate(PASS.Name)

	function META:OnBind()
		if self.NoCull or self.Translucent then
			render.SetCullMode("none")
		else
			render.SetCullMode("front")
		end
		self.SkyTexture = render.GetSkyTexture()
		self.EnvironmentProbeTexture = render.GetEnvironmentProbeTexture()
		--self.EnvironmentProbePosition = render.GetEnvironmentProbeTexture().probe:GetPosition()
	end

	META:Register()
end

function PASS:Draw3D(what, dist)
	render.UpdateSky()

	render.SetBlendMode()
	render.SetDepth(true)
	self:BeginPass("model")
		event.Call("PreGBufferModelPass")
			render.Draw3DScene(what or "models", dist)
		event.Call("PostGBufferModelPass")
	self:EndPass()

	render.SetDepth(false)
	self:BeginPass("light")
		render.SetCullMode("back")
			event.Call("Draw3DLights")
		render.SetCullMode("front")
	self:EndPass()
end

function PASS:DrawDebug(i,x,y,w,h,size)
	for name, map in pairs(prototype.GetCreated(true, "shadow_map")) do
		local tex = map:GetTexture("depth")

		surface.SetWhiteTexture()
		surface.SetColor(1, 1, 1, 1)
		surface.DrawRect(x, y, w, h)

		surface.SetColor(1,1,1,1)
		surface.SetTexture(tex)
		surface.DrawRect(x, y, w, h)

		surface.SetTextPosition(x, y + 5)
		surface.DrawText(tostring(name))

		if i%size == 0 then
			y = y + h
			x = 0
		else
			x = x + w
		end

		i = i + 1
	end

	return i,x,y,w,h
end

PASS.Stages = {
	{
		name = "model",
		vertex = {
			mesh_layout = {
				{pos = "vec3"},
				{uv = "vec2"},
				{normal = "vec3"},
				--{tangent = "vec3"},
				{texture_blend = "float"},
			},
			source = [[
				#define GENERATE_TANGENT 1

				out vec3 view_pos;

				#ifdef GENERATE_TANGENT
					out vec3 vertex_view_normal;
				#else
					out mat3 tangent_space;
				#endif

				void main()
				{
					vec4 temp = g_view_world * vec4(pos, 1.0);
					view_pos = temp.xyz;
					gl_Position = g_projection * temp;


					#ifdef GENERATE_TANGENT
						vertex_view_normal = mat3(g_normal_matrix) * normal;
					#else
						vec3 view_normal = mat3(g_normal_matrix) * normal;
						vec3 view_tangent = mat3(g_normal_matrix) * tangent;
						vec3 view_bitangent = cross(view_tangent, view_normal);

						tangent_space = mat3(view_tangent, view_bitangent, view_normal);
					#endif
				}
			]]
		},
		fragment = {
			variables = {
				NoCull = false,
			},
			mesh_layout = {
				{uv = "vec2"},
				{texture_blend = "float"},
			},
			source = [[

				#define GENERATE_TANGENT 1
				//#define DEBUG_NORMALS 1

				in vec3 view_pos;

				#ifdef GENERATE_TANGENT
					in vec3 vertex_view_normal;
					#define tangent_space cotangent_frame(vertex_view_normal, view_pos, uv)
				#else
					in mat3 tangent_space;
					#define vertex_view_normal tangent_space[2]
				#endif

				// https://www.shadertoy.com/view/MslGR8
				bool dither(vec2 uv, float alpha)
				{
					if (lua[AlphaTest = false])
					{
						return alpha*alpha < (-gl_FragDepth+1)/20;
					}

					const vec3 magic = vec3( 0.06711056, 0.00583715, 52.9829189 );
					float lol = fract( magic.z * fract( dot( gl_FragCoord.xy, magic.xy ) ) );

					return (alpha + lol) < 1;
				}

				// http://www.geeks3d.com/20130122/normal-mapping-without-precomputed-tangent-space-vectors/
				mat3 cotangent_frame(vec3 N, vec3 p, vec2 uv)
				{
					// get edge vectors of the pixel triangle
					vec3 dp1 = dFdx( p );
					vec3 dp2 = dFdy( p );
					vec2 duv1 = dFdx( uv );
					vec2 duv2 = dFdy( uv );

					// solve the linear system
					vec3 dp2perp = cross( dp2, N );
					vec3 dp1perp = cross( N, dp1 );
					vec3 T = dp2perp * duv1.x + dp1perp * duv2.x;
					vec3 B = dp2perp * duv1.y + dp1perp * duv2.y;

					// construct a scale-invariant frame
					float invmax = inversesqrt( max( dot(T,T), dot(B,B) ) );
					return mat3( T * invmax, B * invmax, N );
				}

				void main()
				{
					//{albedo = vertex_view_normal; return;}

					// albedo
					vec4 color = texture(lua[AlbedoTexture = render.GetErrorTexture()], uv);

					if (texture_blend != 0)
						color = mix(color, texture(lua[Albedo2Texture = "texture"], uv), texture_blend);

					color *= lua[Color = Color(1,1,1,1)];

					albedo = color.rgb;

					if (lua[Translucent = false])
					{
						if (dither(uv, color.a))
						{
							discard;
						}
					}



					// normals
					vec4 normal_map = texture(lua[NormalTexture = render.GetBlackTexture()], uv);

					if (normal_map.xyz != vec3(0))
					{
						if (texture_blend != 0)
						{
							normal_map = mix(normal_map, texture(lua[Normal2Texture = "texture"], uv), texture_blend);
						}

						if (lua[SSBump = false])
						{
							// this is so wrong
							normal_map.xyz = normalize(pow((normal_map.xyz*0.1 + vec3(0,0,1)), vec3(0.1)));
						}

						if (lua[FlipYNormal = false])
						{
							normal_map.rgb = normal_map.rgb * vec3(1, -1, 1) + vec3(0, 1, 0);
						}

						if (lua[FlipXNormal = false])
						{
							normal_map.rgb = normal_map.rgb * vec3(-1, 1, 1) + vec3(1, 0, 0);
						}

						normal_map.xyz = /*normalize*/(normal_map.xyz * 2 - 1).xyz;

						view_normal = tangent_space * normal_map.xyz;
					}
					else
					{
						view_normal = vertex_view_normal;
					}

					view_normal = normalize(view_normal);

					// metallic
					if (lua[NormalAlphaMetallic = false])
					{
						metallic = normal_map.a;
					}
					else if (lua[AlbedoAlphaMetallic = false])
					{
						metallic = -color.a+1;
					}
					else
					{
						metallic = texture(lua[MetallicTexture = render.GetBlackTexture()], uv).r;
					}



					// roughness
					roughness = texture(lua[RoughnessTexture = render.GetBlackTexture()], uv).r;


					//generate roughness and metallic they're zero
					if (roughness == 0)
					{
						if (metallic != 0)
						{
							roughness = pow(-metallic+1, 0.25)/1.5;
						}
						else
						{
							roughness = 0.98;//max(pow((-(length(albedo)/3) + 1), 5), 0.9);
							//albedo *= pow(roughness, 0.5);
						}

						if (metallic == 0)
						{
							metallic = min((-roughness+1)/1.5, 0.075);
						}
					}


					metallic *= lua[MetallicMultiplier = 1];
					roughness *= lua[RoughnessMultiplier = 1];
					specular = vec3(0,0,0);
				}
			]]
		}
	},
	{
		name = "light",
		vertex = {
			mesh_layout = {
				{pos = "vec3"},
			},
			source = "gl_Position = g_projection_view_world * vec4(pos*0.5, 1);"
		},
		fragment = {
			variables = {
				light_view_pos = Vec3(0,0,0),
				light_color = Color(1,1,1,1),
				light_intensity = 0.5,
			},
			source = [[
				vec2 uv = get_screen_uv();

				float get_shadow_(vec2 uv)
				{
					float visibility = 0;

					if (lua[light_point_shadow = false])
					{
						vec3 light_dir = (get_view_pos(uv)*0.5+0.5) - (light_view_pos*0.5+0.5);
						vec3 dir = normalize(light_dir) * mat3(g_view);
						dir.z = -dir.z;


						float shadow_view = texture(lua[tex_shadow_map_cube = render.GetSkyTexture()], dir.xzy).r;

						visibility = shadow_view;
					}
					else
					{
						vec4 proj_inv = g_projection_view_inverse * vec4(uv * 2 - 1, texture(tex_depth, uv).r * 2 - 1, 1.0);

							]] .. (function()
								local code = ""
								for i = 1, render.csm_count do
									local str = [[
									{
										vec4 temp = light_projection_view * proj_inv;
										vec3 shadow_coord = temp.xyz / temp.w;

										if (
											shadow_coord.x >= -0.9 &&
											shadow_coord.x <= 0.9 &&
											shadow_coord.y >= -0.9 &&
											shadow_coord.y <= 0.9 &&
											shadow_coord.z >= -0.9 &&
											shadow_coord.z <= 0.9
										)
										{
											shadow_coord = 0.5 * shadow_coord + 0.5;

											visibility = (shadow_coord.z - texture(tex_shadow_map, shadow_coord.xy).r);
										}
										]]..(function()
											if i == 1 then
												return [[else if(lua[project_from_camera = false])
												{
													visibility = 0;
												}]]
											end
											return ""
										end)()..[[
									}
									]]
									str = str:gsub("tex_shadow_map", "lua[tex_shadow_map_" .. i .." = \"sampler2D\"]")
									str = str:gsub("light_projection_view", "lua[light_projection_view_" .. i .. " = \"mat4\"]")
									code = code .. str
								end
								return code
							end)() .. [[
					}

					return visibility;
				}

				void main()
				{

					vec3 pos = get_view_pos(uv);
					vec3 normal = get_view_normal(uv);

					float attenuation = 1;

					if (!lua[project_from_camera = false])
					{
						float radius = lua[light_radius = 1000];

						attenuation = compute_light_attenuation(pos, light_view_pos, radius, normal);
					}

					specular = compute_brdf(
						uv,
						normalize(pos - light_view_pos),
						normalize(pos),
						normal
					)*attenuation*light_intensity*light_color.rgb*5;

					if (lua[light_shadow = false])
					{
						shadow = get_shadow_(uv);
					}
				}
			]]
		}
	},
}

local TESSELLATION = false

if TESSELLATION then
	PASS.Stages[1].vertex = {
		mesh_layout = {
			{pos = "vec3"},
			{uv = "vec2"},
			{normal = "vec3"},
			--{tangent = "vec3"},
			{texture_blend = "float"},
		},
		source = [[
			#version 420
			out vec3 vPosition;
			out vec2 vTexCoord;
			out vec3 vNormal;
			out float vTextureBlend;

			void main() {
				vPosition = pos;
				vTexCoord = uv;
				vNormal = normal;
				vTextureBlend = texture_blend;
			}
		]]
	}
	PASS.Stages[1].tess_control = {
		source = [[
			#version 420
			layout(vertices = 3) out;

			in vec3 vPosition[];
			in vec2 vTexCoord[];
			in vec3 vNormal[];
			in float vTextureBlend[];

			out vec2 tcTexCoord[];
			out vec3 tcPosition[];
			out vec3 tcNormal[];
			out float tcTextureBlend[];

			void main()
			{
				tcTexCoord[gl_InvocationID] = vTexCoord[gl_InvocationID];
				tcPosition[gl_InvocationID] = vPosition[gl_InvocationID];
				tcNormal[gl_InvocationID] = vNormal[gl_InvocationID];
				tcTextureBlend[gl_InvocationID] = tcTextureBlend[gl_InvocationID];

				if(gl_InvocationID == 0)
				{
					float inTess  = lua[innerTessLevel = 10];
					float outTess = lua[outerTessLevel = 10];

					inTess = 16;
					outTess = 16;

					gl_TessLevelInner[0] = inTess;
					gl_TessLevelInner[1] = inTess;
					gl_TessLevelOuter[0] = outTess;
					gl_TessLevelOuter[1] = outTess;
					gl_TessLevelOuter[2] = outTess;
					gl_TessLevelOuter[3] = outTess;
				}
			}
		]],
	}
	PASS.Stages[1].tess_evaluation = {
		source = [[
			#version 420
			layout(triangles, equal_spacing, ccw) in;

			in vec3 tcPosition[];
			in vec2 tcTexCoord[];
			in vec3 tcNormal[];
			in float tcTextureBlend[];

			out vec3 tePosition;
			out vec2 teTexCoord;
			out vec3 teNormal;
			out float teTextureBlend;

			void main()
			{
				vec3 p0 = gl_TessCoord.x * tcPosition[0];
				vec3 p1 = gl_TessCoord.y * tcPosition[1];
				vec3 p2 = gl_TessCoord.z * tcPosition[2];
				vec3 pos = p0 + p1 + p2;

				vec2 tc0 = gl_TessCoord.x * tcTexCoord[0];
				vec2 tc1 = gl_TessCoord.y * tcTexCoord[1];
				vec2 tc2 = gl_TessCoord.z * tcTexCoord[2];
				teTexCoord = tc0 + tc1 + tc2;

				vec3 n0 = gl_TessCoord.x * tcNormal[0];
				vec3 n1 = gl_TessCoord.y * tcNormal[1];
				vec3 n2 = gl_TessCoord.z * tcNormal[2];
				vec3 normal = normalize(n0 + n1 + n2);
				teNormal = mat3(g_normal_matrix) * normal;

				teTextureBlend = (tcTextureBlend[0] + tcTextureBlend[1] + tcTextureBlend[2]) / 3;

				float height = texture(lua[HeightTexture = render.CreateTextureFromPath("https://upload.wikimedia.org/wikipedia/commons/5/57/Heightmap.png")], teTexCoord).x;
				pos += normal * (height * 0.5f);

				vec4 temp = g_view_world * vec4(pos, 1.0);
				tePosition = temp.xyz;
				gl_Position = g_projection * temp;

			}
		]],
	}
	PASS.Stages[1].geometry = {
		source = [[
			#version 420
			layout (triangles) in;
			layout (triangle_strip) out;
			layout (max_vertices = 3) out;

			in vec3 tePosition[3];
			in vec2 teTexCoord[3];
			in vec3 teNormal[3];
			in float teTextureBlend[3];

			out vec2 gTexCoord;
			out float gTextureBlend;

			out vec3 gPosition;
			out vec3 gFacetNormal;

			void main()
			{
				for ( int i = 0; i < gl_in.length(); i++)
				{
					gTexCoord = teTexCoord[i];
					gPosition = tePosition[i];
					gFacetNormal = vec3(1,0,0);//teNormal[i];
					gTextureBlend = teTextureBlend[i];
					gl_Position = gl_in[i].gl_Position;
					EmitVertex();
				}

				EndPrimitive();
			}
		]],
	}

	PASS.Stages[1].fragment.mesh_layout = nil

	PASS.Stages[1].fragment.source = [[
		#version 420
		//in vec3 pos;
		in vec2 uv;
		//in vec3 normal;
		//in vec3 tangent;
		in float texture_blend;
	]]
	.. PASS.Stages[1].fragment.source

	if RELOAD then
		for mesh in pairs(prototype.GetCreated()) do
			if mesh.Type == "mesh_builder" then
				mesh.mesh:SetMode("patches")
			end
		end
	end
elseif RELOAD then
	for mesh in pairs(prototype.GetCreated()) do
		if mesh.Type == "mesh_builder" then
			mesh.mesh:SetMode("triangles")
		end
	end
end

render.gbuffer_data_pass = PASS