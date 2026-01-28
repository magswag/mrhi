package mrhi

main :: proc() {
	init()
	defer shutdown()

	surface := create_surface(nil)
	defer destroy_surface(surface)

	configure_surface(
		surface,
		{extent = {1920, 1080}, format = .BGRA8_Unorm, present_mode = .Immediate},
	)

	tlas := create_tlas({max_instances = 12, flags = {.Allow_Update}, update_mode = .Build})
	defer destroy_tlas(tlas)

	blas := create_blas({flags = {.Prefer_Fast_Trace}})
	defer destroy_blas(blas)

	buffer := create_buffer(
		{debug_name = "Buffer", byte_size = 1024, usage = {.Vertex_Read}, memory = .CPU},
	)
	defer destroy_buffer(buffer)

	depth_tex := create_texture(
		{debug_name = "Depth Texture", dimensions = {2048, 2048, 1}, format = .D32_Float},
	)
	defer destroy_texture(depth_tex)

	depth_view := create_texture_view({texture = depth_tex, base_mip = 0, base_layer = 0})
	defer destroy_texture_view(depth_view)

	c_shader := create_shader()
	defer destroy_shader(c_shader)

	v_shader := create_shader()
	defer destroy_shader(v_shader)

	f_shader := create_shader()
	defer destroy_shader(f_shader)

	g_pipeline := create_graphics_pipeline(
		{
			debug_name = "Graphics Pipeline",
			vertex_stage = Shader_Stage_Desc{shader = v_shader, entry = "main"},
			fragment_stage = Shader_Stage_Desc{shader = f_shader, entry = "main"},
			rasterizer = {fill_mode = .Fill, cull_mode = .Back, counter_clockwise = true},
			color_formats = {.RGBA8_sRGB},
			depth_format = .D32_Float,
			depth_stencil = {enable_depth = true, enable_stencil = true},
		},
	)
	defer destroy_pipeline(g_pipeline)

	c_pipeline := create_compute_pipeline({debug_name = "Compute Pipeline", shader = c_shader})
	defer destroy_pipeline(c_pipeline)

	out, cmd := get_current_texture_view(surface)

	cmd_begin_rendering(
		cmd,
		{
			area = {1920, 1080},
			layer_count = 1,
			color_attachments = {{view = out, clear_color = {0.1, 0.2, 0.3, 1.0}}},
			depth_attachment = depth_view,
		},
	)

	cmd_bind_pipeline(cmd, g_pipeline)
	cmd_draw(cmd, 6, 1, 0, 0)

	cmd_end_rendering(cmd)

	cmd_bind_pipeline(cmd, c_pipeline)
	cmd_dispatch(cmd, {64, 1, 1})

	cmd_transition_texture(cmd, depth_tex, {.Copy_Dst}, {.Shader_Read})

	submit(.Graphics, cmd)
}
