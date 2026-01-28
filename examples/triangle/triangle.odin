package triangle

import "../../../mrhi"
import "core:fmt"
import sdl "vendor:sdl3"

main :: proc() {
	if !sdl.Init({.VIDEO}) {
		panic("Failed to init SDL")
	}
	defer sdl.Quit()

	window := sdl.CreateWindow("mRHI Triangle", 1920, 1080, {.RESIZABLE})
	defer sdl.DestroyWindow(window)

	mrhi.init()
	defer mrhi.shutdown()

	surface := mrhi.create_surface(window)
	defer mrhi.destroy_surface(surface)

	surface_config := mrhi.Surface_Config {
		extent                   = {1920, 1080},
		format                   = .RGBA8_Unorm,
		present_mode             = .Immediate,
		desired_frames_in_flight = 3,
	}
	mrhi.configure_surface(surface, surface_config)

	v_shader := mrhi.create_shader()
	f_shader := mrhi.create_shader()
	defer mrhi.destroy_shader(v_shader)
	defer mrhi.destroy_shader(f_shader)

	// pipeline := mrhi.create_graphics_pipeline(
	// 	{
	// 		debug_name = "Triangle Pipeline",
	// 		color_formats = {.RGBA8_Unorm},
	// 		vertex_stage = mrhi.Shader_Stage_Desc{shader = v_shader, entry = "main"},
	// 		fragment_stage = mrhi.Shader_Stage_Desc{shader = f_shader, entry = "main"},
	// 		rasterizer = {cull_mode = .None, fill_mode = .Fill},
	// 		msaa_samples = .x1,
	// 	},
	// )
	// defer mrhi.destroy_pipeline(pipeline)

	fullscreen := false
	event: sdl.Event

	main_loop: for {
		for sdl.PollEvent(&event) {
			#partial switch event.type {
			case .QUIT:
				break main_loop
			case .KEY_DOWN:
				switch event.key.key {
				case sdl.K_ESCAPE:
					break main_loop
				case sdl.K_F11:
					fullscreen = !fullscreen
					sdl.SetWindowFullscreen(window, fullscreen)
				}
			case .WINDOW_RESIZED:
				when ODIN_DEBUG {
					fmt.println(
						"Window resized(",
						event.window.data1,
						"x",
						event.window.data2,
						")",
					)
				}
				surface_config.extent = {u32(event.window.data1), u32(event.window.data2)}
				mrhi.configure_surface(surface, surface_config)

			case .WINDOW_EXPOSED:
				fmt.println("cuh")
			// Render
			// out, cmd := mrhi.get_current_texture_view(surface)

			// mrhi.cmd_begin_rendering(
			// 	cmd,
			// 	{
			// 		area = {1920, 1080},
			// 		color_attachments = {{clear_color = {0.1, 0.2, 0.3, 1.0}, view = out}},
			// 		layer_count = 1,
			// 	},
			// )

			// mrhi.cmd_set_scissor(cmd, {1920, 1080})
			// mrhi.cmd_set_viewport(cmd, {1920, 1080})

			// mrhi.cmd_draw(cmd, 3, 1, 0, 0)

			// mrhi.cmd_end_rendering(cmd)

			// mrhi.submit_and_present(cmd, surface)
			}
		}


	}
}
