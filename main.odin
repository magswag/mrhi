package mrhi

main :: proc() {
	surface := create_surface(nil)

	tlas := create_tlas(&{max_instances = 12, flags = {.Allow_Update}, update_mode = .Build})
	blas := create_blas(&{flags = {.Prefer_Fast_Trace}})

	buffer := create_buffer(
		&Buffer_Desc {
			debug_name = "Buffer",
			byte_size = 1024,
			usage = {.Vertex_Read},
			memory = .CPU,
		},
	)

	depth_tex := create_texture(
		&Texture_Desc {
			debug_name = "Depth Texture",
			dimensions = {2048, 2048, 1},
			format = .D32_Float,
		},
	)

	depth_view := create_texture_view(
		&Texture_View_Desc{texture = depth_tex, base_mip = 0, base_layer = 0},
	)

	c_shader := create_shader()

	g_pipeline := create_graphics_pipeline(
		&Graphics_Pipeline_Desc {
			debug_name = "Graphics Pipeline",
			rasterizer = {fill_mode = .Fill, cull_mode = .Back, counter_clockwise = true},
			color_formats = {.RGBA8_sRGB},
			depth_format = .D32_Float,
			depth_stencil = {enable_depth = true, enable_stencil = true},
		},
	)

	c_pipeline := create_compute_pipeline(
		&Compute_Pipeline_Desc{debug_name = "Compute Pipeline", shader = c_shader},
	)

	out, cmd := get_current_texture_view(surface)

	cmd_begin_rendering(
		cmd,
		Render_Desc {
			area = {1920, 1080},
			layer_count = 1,
			color_attachments = {{view = out, clear_color = {0.1, 0.2, 0.3, 1.0}}},
			depth_attachment = depth_view,
		},
	)

	cmd_draw(cmd, 6, 1, 0, 0)

	cmd_end_rendering(cmd)

	cmd_transition_texture(cmd, depth_tex, {.Copy_Dst}, {.Shader_Read})

	submit(.Graphics, cmd)
}
