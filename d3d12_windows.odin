package mrhi

import "core:fmt"
import "core:os"
import "vendor:directx/d3d12"
import "vendor:directx/dxgi"
import sdl "vendor:sdl3"

@(private = "file")
D3D12_Context :: struct {
	factory:      ^dxgi.IFactory6,
	adapter:      ^dxgi.IAdapter1,
	device:       ^d3d12.IDevice,
	cmd_queue:    ^d3d12.ICommandQueue,
	pool_surface: Resource_Pool(5, Surface, ^dxgi.ISwapChain3, bool),
}

@(private = "file")
ctx: D3D12_Context

@(private = "file")
check :: proc(res: d3d12.HRESULT, message: string) {
	if (res >= 0) {
		return
	}

	fmt.eprintf("%v. Error code: %0x\n", message, u32(res))
	os.exit(-1)
}

init :: proc() {
	fmt.println("RHI: Initializing D3D12 backend")

	hr: d3d12.HRESULT
	{
		flags: dxgi.CREATE_FACTORY

		when ODIN_DEBUG {
			flags += {.DEBUG}
		}
		hr = dxgi.CreateDXGIFactory2(flags, dxgi.IFactory4_UUID, cast(^rawptr)&ctx.factory)
		check(hr, "Failed creating factory")
	}

	error_not_found := dxgi.HRESULT(-142213123)

	for i: u32 = 0; ctx.factory->EnumAdapters1(i, &ctx.adapter) != error_not_found; i += 1 {
		desc: dxgi.ADAPTER_DESC1
		ctx.adapter->GetDesc1(&desc)

		if .SOFTWARE in desc.Flags {
			continue
		}

		if d3d12.CreateDevice((^dxgi.IUnknown)(ctx.adapter), ._12_0, dxgi.IDevice_UUID, nil) >= 0 {
			break
		} else {
			fmt.println("Failed to create device")
		}
	}

	if ctx.adapter == nil {
		fmt.println("Could not find hardware adapter")
		return
	}

	hr = d3d12.CreateDevice(
		(^dxgi.IUnknown)(ctx.adapter),
		._12_0,
		d3d12.IDevice_UUID,
		(^rawptr)(&ctx.device),
	)
	check(hr, "Failed to create device")

	desc: dxgi.ADAPTER_DESC1
	ctx.adapter->GetDesc1(&desc)
	name := fmt.printf("GPU: %s\n", desc.Description)

	hr = ctx.device->CreateCommandQueue(
		&d3d12.COMMAND_QUEUE_DESC{Type = .DIRECT},
		d3d12.ICommandQueue_UUID,
		(^rawptr)(&ctx.cmd_queue),
	)
	check(hr, "Failed to create command queue")


	res_pool_init(&ctx.pool_surface)
}

@(require_results)
create_surface :: proc(window: ^sdl.Window) -> Surface {
	w, h: i32

	if !sdl.GetWindowSize(window, &w, &h) {
		panic("Failed to get window size")
	}

	props := sdl.GetWindowProperties(window)
	hwnd := sdl.GetPointerProperty(props, sdl.PROP_WINDOW_WIN32_HWND_POINTER, nil)
	window_handle := dxgi.HWND(hwnd)

	hr: d3d12.HRESULT

	swapchain: ^dxgi.ISwapChain3
	hr = ctx.factory->CreateSwapChainForHwnd(
		(^dxgi.IUnknown)(ctx.cmd_queue),
		window_handle,
		&dxgi.SWAP_CHAIN_DESC1 {
			Width = u32(w),
			Height = u32(h),
			Format = .R8G8B8A8_UNORM,
			SampleDesc = {Count = 1},
			BufferUsage = {.RENDER_TARGET_OUTPUT},
			BufferCount = 3,
			Scaling = .NONE,
			SwapEffect = .FLIP_DISCARD,
			AlphaMode = .UNSPECIFIED,
		},
		nil,
		nil,
		(^^dxgi.ISwapChain1)(&swapchain),
	)
	check(hr, "Failed to create swap chain")

	desc_heap: ^d3d12.IDescriptorHeap
	hr = ctx.device->CreateDescriptorHeap(
		&d3d12.DESCRIPTOR_HEAP_DESC{NumDescriptors = 3, Type = .RTV, Flags = {}},
		d3d12.IHeap_UUID,
		(^rawptr)(desc_heap),
	)
	check(hr, "Failed to create descriptor heap")


	render_targets: [3]^d3d12.IResource
	rtv_desc_size := ctx.device->GetDescriptorHandleIncrementSize(.RTV)

	rtv_handle: d3d12.CPU_DESCRIPTOR_HANDLE
	desc_heap->GetCPUDescriptorHandleForHeapStart(&rtv_handle)

	for n in 0 ..< 3 {
		swapchain->GetBuffer(u32(n), d3d12.IResource_UUID, (^rawptr)(&render_targets[n]))
		ctx.device->CreateRenderTargetView(
			render_targets[n],
			&d3d12.RENDER_TARGET_VIEW_DESC{},
			rtv_handle,
		)
		rtv_handle.ptr += uint(rtv_desc_size)
	}

	return res_pool_insert(&ctx.pool_surface, swapchain)
}

@(require_results)
create_buffer :: proc(desc: ^Buffer_Desc) -> Buffer {
	return {}
}

@(require_results)
create_texture :: proc(desc: ^Texture_Desc) -> Texture {
	return {}
}

@(require_results)
create_shader :: proc() -> Shader {
	return {}
}

@(require_results)
create_compute_pipeline :: proc(desc: ^Compute_Pipeline_Desc) -> Compute_Pipeline {

	return {}
}

@(require_results)
create_graphics_pipeline :: proc(desc: ^Graphics_Pipeline_Desc) -> Graphics_Pipeline {
	depth_format := to_format(desc.depth_format.? or_else .Unknown)

	color_formats: [8]dxgi.FORMAT
	for format, i in desc.color_formats {
		color_formats[i] = to_format(format)
	}

	hr: d3d12.HRESULT
	pso: ^d3d12.IPipelineState
	hr = ctx.device->CreateGraphicsPipelineState(
		&d3d12.GRAPHICS_PIPELINE_STATE_DESC {
			pRootSignature = nil,
			RasterizerState = {
				FillMode = to_fill_mode(desc.rasterizer.fill_mode),
				CullMode = to_cull_mode(desc.rasterizer.cull_mode),
			},
			PrimitiveTopologyType = .TRIANGLE,
			NumRenderTargets = u32(len(desc.color_formats)),
			RTVFormats = color_formats,
			DSVFormat = depth_format,
			DepthStencilState = {
				DepthEnable = d3d12.BOOL(desc.depth_stencil.enable_depth),
				DepthWriteMask = .ALL,
				DepthFunc = .LESS_EQUAL,
				StencilEnable = d3d12.BOOL(desc.depth_stencil.enable_stencil),
			},
		},
		d3d12.IPipelineState_UUID,
		(^rawptr)(pso),
	)
	check(hr, "Failed to create PSO")

	return {}
}

transition_texture :: proc(
	cmd: Command_List,
	texture: Texture,
	src: Texture_Usage_Set,
	dst: Texture_Usage_Set,
) {

}

transition_buffer :: proc(
	cmd: Command_List,
	buffer: Buffer,
	src: Buffer_Usage_Set,
	dst: Buffer_Usage_Set,
) {

}

copy_texture :: proc(cmd: Command_List, src: Buffer, dst: Texture) {

}

memory_barrier :: proc(cmd: Command_List) {

}

@(require_results)
acquire_command_list :: proc() -> Command_List {
	return {}
}

submit :: proc(queue: Queue, cmd: Command_List) {

}

draw :: proc(
	cmd: Command_List,
	vertex_count: u32,
	instance_count: u32,
	first_vertex: u32,
	first_instance: u32,
) {

}

draw_indirect_count :: proc(
	cmd: Command_List,
	buffer: Buffer,
	offset: i32,
	count_buffer: Buffer,
	count_buffer_offset: i32,
	max_draw_count: u32,
	stride: u32,
) {

}

to_fill_mode :: proc "contextless" (mode: Fill_Mode) -> d3d12.FILL_MODE {
	switch mode {
	case .Fill:
		return .SOLID
	case .Wireframe:
		return .WIREFRAME
	}
	unreachable()
}

to_cull_mode :: proc "contextless" (mode: Cull_Mode) -> d3d12.CULL_MODE {
	switch mode {
	case .None:
		return .NONE
	case .Front:
		return .FRONT
	case .Back:
		return .BACK
	}
	unreachable()
}

to_format :: proc "contextless" (format: Format) -> dxgi.FORMAT {
	switch format {
	case .Unknown:
		return .UNKNOWN
	case .RGBA8_sRGB:
		return .R8G8B8A8_UNORM_SRGB
	case .D32:
		return .D32_FLOAT
	}
	unreachable()
}
