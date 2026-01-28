package mrhi

import "core:c"
import "core:fmt"
import "core:math/fixed"
import "core:os"
import "core:sys/windows"
import "vendor:directx/d3d12"
import "vendor:directx/dxgi"
import sdl "vendor:sdl3"

Rtv :: distinct d3d12.CPU_DESCRIPTOR_HANDLE
Uav :: distinct d3d12.CPU_DESCRIPTOR_HANDLE
Dsv :: distinct d3d12.CPU_DESCRIPTOR_HANDLE

@(private = "file")
D3d12_Texture_View_Type :: union {
	Rtv,
	Uav,
	Dsv,
}

@(private = "file")
D3d12_Swapchain :: struct {
	raw:         ^dxgi.ISwapChain3,
	rtv_heap:    ^d3d12.IDescriptorHeap,
	frame_index: int,
	fence:       ^d3d12.IFence,
	fence_event: windows.HANDLE,
	frame_datas: [3]struct {
		cmd_allocator: ^d3d12.ICommandAllocator,
		cmd:           Command_List,
		texture:       Texture,
		view:          Texture_View,
		fence_value:   u64,
	},
}

@(private = "file")
D3d12_Swapchain_Data :: struct {
	config: Surface_Config,
}

@(private = "file")
D3d12_Texture :: struct {
	initialized: bool,
	resource:    ^d3d12.IResource,
}

@(private = "file")
D3D12_Context :: struct {
	factory:                ^dxgi.IFactory6,
	adapter:                ^dxgi.IAdapter1,
	device:                 ^d3d12.IDevice,
	cmd_queue:              ^d3d12.ICommandQueue,
	pool_surface:           Resource_Pool(5, Surface, D3d12_Swapchain, D3d12_Swapchain_Data),
	pool_cmd_list:          Resource_Pool(10, Command_List, ^d3d12.ICommandList, bool),
	pool_graphics_pipeline: Resource_Pool(10, Graphics_Pipeline, ^d3d12.IPipelineState, bool),
	pool_compute_pipeline:  Resource_Pool(10, Compute_Pipeline, ^d3d12.IPipelineState, bool),
	pool_texture:           Resource_Pool(32, Texture, D3d12_Texture, bool),
	pool_texture_view:      Resource_Pool(32, Texture_View, D3d12_Texture_View_Type, bool),
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

	for i: u32 = 0; ctx.factory->EnumAdapters1(i, &ctx.adapter) != dxgi.ERROR_NOT_FOUND; i += 1 {
		desc: dxgi.ADAPTER_DESC1
		ctx.adapter->GetDesc1(&desc)

		if .SOFTWARE in desc.Flags {
			continue
		}

		if d3d12.CreateDevice(cast(^dxgi.IUnknown)ctx.adapter, ._12_0, dxgi.IDevice_UUID, nil) >=
		   0 {
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
		cast(^dxgi.IUnknown)ctx.adapter,
		._12_0,
		d3d12.IDevice_UUID,
		cast(^rawptr)&ctx.device,
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
	res_pool_init(&ctx.pool_cmd_list)
	res_pool_init(&ctx.pool_compute_pipeline)
	res_pool_init(&ctx.pool_graphics_pipeline)
	res_pool_init(&ctx.pool_texture)
	res_pool_init(&ctx.pool_texture_view)
}

@(require_results)
create_surface :: proc(window: ^sdl.Window) -> Surface {
	props := sdl.GetWindowProperties(window)
	hwnd := sdl.GetPointerProperty(props, sdl.PROP_WINDOW_WIN32_HWND_POINTER, nil)
	window_handle := dxgi.HWND(hwnd)

	hr: d3d12.HRESULT

	flags: dxgi.SWAP_CHAIN

	swapchain: ^dxgi.ISwapChain3
	hr = ctx.factory->CreateSwapChainForHwnd(
		cast(^dxgi.IUnknown)ctx.cmd_queue,
		window_handle,
		&dxgi.SWAP_CHAIN_DESC1 {
			Width = 0,
			Height = 0,
			Format = .R8G8B8A8_UNORM,
			SampleDesc = {Count = 1},
			BufferUsage = {.RENDER_TARGET_OUTPUT},
			BufferCount = 3,
			Scaling = .NONE,
			SwapEffect = .FLIP_DISCARD,
			AlphaMode = .UNSPECIFIED,
			Flags = flags,
		},
		nil,
		nil,
		cast(^^dxgi.ISwapChain1)&swapchain,
	)
	check(hr, "Failed to create swap chain")

	desc_heap: ^d3d12.IDescriptorHeap
	hr = ctx.device->CreateDescriptorHeap(
		&d3d12.DESCRIPTOR_HEAP_DESC{NumDescriptors = 3, Type = .RTV, Flags = {}},
		d3d12.IDescriptorHeap_UUID,
		cast(^rawptr)&desc_heap,
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

	return res_pool_insert(
		&ctx.pool_surface,
		D3d12_Swapchain{raw = swapchain, rtv_heap = desc_heap},
		D3d12_Swapchain_Data{},
	)
}

configure_surface :: proc(surface: Surface, config: Surface_Config) {
	surface_data := res_pool_get_cold(&ctx.pool_surface, surface)
	surface := res_pool_get_hot(&ctx.pool_surface, surface)

	flags: dxgi.SWAP_CHAIN

	#partial switch config.present_mode {
	case .Immediate:
		flags += {.ALLOW_TEARING}
	}

	surface.raw->ResizeBuffers(
		config.desired_frames_in_flight,
		config.extent.x,
		config.extent.y,
		format_map[config.format],
		flags,
	)

	surface_data.config = config
}

@(require_results)
create_buffer :: proc(desc: Buffer_Desc) -> Buffer {
	return {}
}

@(require_results)
create_texture :: proc(desc: Texture_Desc) -> Texture {
	return {}
}

@(require_results)
create_texture_view :: proc(desc: Texture_View_Desc) -> Texture_View {
	return {}
}

@(require_results)
create_shader :: proc() -> Shader {
	return {}
}

@(require_results)
create_compute_pipeline :: proc(desc: Compute_Pipeline_Desc) -> Compute_Pipeline {

	return {}
}

@(require_results)
create_graphics_pipeline :: proc(desc: Graphics_Pipeline_Desc) -> Graphics_Pipeline {
	depth_format := format_map[desc.depth_format.? or_else .Unknown]

	color_formats: [8]dxgi.FORMAT
	for format, i in desc.color_formats {
		color_formats[i] = format_map[format]
	}

	hr: d3d12.HRESULT
	pso: ^d3d12.IPipelineState

	hr = ctx.device->CreateGraphicsPipelineState(
		&d3d12.GRAPHICS_PIPELINE_STATE_DESC {
			pRootSignature = nil,
			RasterizerState = {
				FillMode = fill_mode_map[desc.rasterizer.fill_mode],
				CullMode = cull_mode_map[desc.rasterizer.cull_mode],
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

@(require_results)
create_blas :: proc(desc: Blas_Desc) -> Blas {
	return {}
}

@(require_results)
create_tlas :: proc(desc: Tlas_Desc) -> Tlas {
	return {}
}

shutdown :: proc() {
	res_pool_destroy(&ctx.pool_surface)
	res_pool_destroy(&ctx.pool_cmd_list)
	res_pool_destroy(&ctx.pool_compute_pipeline)
	res_pool_destroy(&ctx.pool_graphics_pipeline)
	res_pool_destroy(&ctx.pool_texture)
	res_pool_destroy(&ctx.pool_texture_view)
}

destroy_surface :: proc(surface: Surface) {}

destroy_buffer :: proc(buffer: Buffer) {}

destroy_texture :: proc(texture: Texture) {}

destroy_texture_view :: proc(texture_view: Texture_View) {}

destroy_shader :: proc(shader: Shader) {}

destroy_pipeline :: proc(pipeline: Pipeline) {
	pipeline_state: ^d3d12.IPipelineState

	switch pip in pipeline {
	case Graphics_Pipeline:
		pipeline_state = res_pool_get_hot(&ctx.pool_graphics_pipeline, pip)^

	case Compute_Pipeline:
		pipeline_state = res_pool_get_hot(&ctx.pool_compute_pipeline, pip)^
	}

	pipeline_state->Release()
}

destroy_blas :: proc(blas: Blas) {}

destroy_tlas :: proc(tlas: Tlas) {}

@(require_results)
get_current_texture_view :: proc(surface: Surface) -> (Texture_View, Command_List) {
	surface := res_pool_get_hot(&ctx.pool_surface, surface)

	swapchain := surface.raw
	frame_index := swapchain->GetCurrentBackBufferIndex()
	frame_data := &surface.frame_datas[frame_index]
	frame_tex := res_pool_get_hot(&ctx.pool_texture, frame_data.texture)

	cmd := cast(^d3d12.IGraphicsCommandList)res_pool_get_hot(&ctx.pool_cmd_list, frame_data.cmd)

	hr: d3d12.HRESULT

	// Reset
	hr = frame_data.cmd_allocator->Reset()
	check(hr, "Failed to reset command allocator")

	cmd->Reset(frame_data.cmd_allocator, nil)


	// PRESENT -> RENDER_TARGET
	barrier := d3d12.RESOURCE_BARRIER {
		Type = .TRANSITION,
		Flags = {},
		Transition = {
			pResource = frame_tex.resource,
			StateBefore = d3d12.RESOURCE_STATE_PRESENT,
			StateAfter = {.RENDER_TARGET},
			Subresource = d3d12.RESOURCE_BARRIER_ALL_SUBRESOURCES,
		},
	}

	cmd->ResourceBarrier(1, &barrier)

	return frame_data.view, frame_data.cmd
}

cmd_transition_texture :: proc(
	cmd: Command_List,
	texture: Texture,
	src: Texture_Usage_Set,
	dst: Texture_Usage_Set,
) {

}

cmd_transition_buffer :: proc(
	cmd: Command_List,
	buffer: Buffer,
	src: Buffer_Usage_Set,
	dst: Buffer_Usage_Set,
) {

}

cmd_copy_texture :: proc(cmd: Command_List, src: Buffer, dst: Texture) {
	cmd := cast(^d3d12.IGraphicsCommandList)res_pool_get_hot(&ctx.pool_cmd_list, cmd)

	//cmd->CopyTextureRegion()
}

cmd_memory_barrier :: proc(cmd: Command_List) {

}

@(require_results)
acquire_command_list :: proc() -> Command_List {
	return {}
}

submit :: proc(queue: Queue, cmd: Command_List) {
	cmd := cast(^d3d12.IGraphicsCommandList)res_pool_get_hot(&ctx.pool_cmd_list, cmd)

	cmd->Close()
	ctx.cmd_queue->ExecuteCommandLists(1, (^^d3d12.ICommandList)(&cmd))
}

submit_and_present :: proc(cmd: Command_List, surface: Surface) {
	cmd := cast(^d3d12.IGraphicsCommandList)res_pool_get_hot(&ctx.pool_cmd_list, cmd)
	surface_data := res_pool_get_cold(&ctx.pool_surface, surface)
	surface := res_pool_get_hot(&ctx.pool_surface, surface)

	swapchain := surface.raw

	hr: d3d12.HRESULT

	frame_index := surface.frame_index
	frame := &surface.frame_datas[frame_index]
	frame_tex := res_pool_get_hot(&ctx.pool_texture, frame.texture)

	// RENDER_TARGET -> PRESENT
	barrier := d3d12.RESOURCE_BARRIER {
		Type = .TRANSITION,
		Flags = {},
		Transition = {
			pResource = frame_tex.resource,
			StateBefore = {.RENDER_TARGET},
			StateAfter = d3d12.RESOURCE_STATE_PRESENT,
			Subresource = d3d12.RESOURCE_BARRIER_ALL_SUBRESOURCES,
		},
	}

	cmd->ResourceBarrier(1, &barrier)

	hr = cmd->Close()
	check(hr, "Failed to close command list")

	// Execute
	ctx.cmd_queue->ExecuteCommandLists(1, (^^d3d12.ICommandList)(&cmd))

	// Present
	sync_interval: u32
	present_flags: dxgi.PRESENT

	switch surface_data.config.present_mode {
	case .Fifo:
		sync_interval = 1
	case .Immediate:
		sync_interval = 0
		present_flags += {.ALLOW_TEARING}
	case .Mailbox:
		sync_interval = 0
	}

	hr = swapchain->Present1(sync_interval, present_flags, &dxgi.PRESENT_PARAMETERS{})
	check(hr, "Failed to present")

	// Wait for frame to finish
	current_fence_value := frame.fence_value

	ctx.cmd_queue->Signal(surface.fence, current_fence_value)

	fi := swapchain->GetCurrentBackBufferIndex()
	surface.frame_index = int(fi)
	frame2 := &surface.frame_datas[fi]

	if surface.fence->GetCompletedValue() < frame2.fence_value {
		surface.fence->SetEventOnCompletion(frame2.fence_value, surface.fence_event)

		windows.WaitForSingleObject(surface.fence_event, 12000000)
	}

	surface.frame_datas[fi].fence_value = current_fence_value + 1
}

cmd_draw :: proc(
	cmd: Command_List,
	vertex_count: u32,
	instance_count: u32,
	first_vertex: u32,
	first_instance: u32,
) {
	cmd := cast(^d3d12.IGraphicsCommandList)res_pool_get_hot(&ctx.pool_cmd_list, cmd)

	cmd->DrawInstanced(vertex_count, instance_count, first_vertex, first_instance)
}

cmd_draw_indirect_count :: proc(
	cmd: Command_List,
	buffer: Buffer,
	offset: i32,
	count_buffer: Buffer,
	count_buffer_offset: i32,
	max_draw_count: u32,
	stride: u32,
) {
	cmd := cast(^d3d12.IGraphicsCommandList)res_pool_get_hot(&ctx.pool_cmd_list, cmd)
}

cmd_set_viewport :: proc(cmd: Command_List, extent: [2]f32) {
	cmd := cast(^d3d12.IGraphicsCommandList)res_pool_get_hot(&ctx.pool_cmd_list, cmd)

	cmd->RSSetViewports(1, &d3d12.VIEWPORT{Width = extent.x, Height = extent.y})
}

cmd_set_scissor :: proc(cmd: Command_List, extent: [2]u32) {
	cmd := cast(^d3d12.IGraphicsCommandList)res_pool_get_hot(&ctx.pool_cmd_list, cmd)

	cmd->RSSetScissorRects(
		1,
		&d3d12.RECT{left = 0, right = i32(extent.x), top = 0, bottom = i32(extent.y)},
	)
}

cmd_bind_pipeline :: proc(cmd: Command_List, pipeline: Pipeline) {
	cmd := cast(^d3d12.IGraphicsCommandList)res_pool_get_hot(&ctx.pool_cmd_list, cmd)

	pipeline_state: ^d3d12.IPipelineState

	switch pip in pipeline {
	case Graphics_Pipeline:
		pipeline_state = res_pool_get_hot(&ctx.pool_graphics_pipeline, pip)^

	case Compute_Pipeline:
		pipeline_state = res_pool_get_hot(&ctx.pool_compute_pipeline, pip)^

	}

	cmd->SetPipelineState(pipeline_state)
}

cmd_begin_rendering :: proc(cmd: Command_List, desc: Render_Desc) {
	cmd := cast(^d3d12.IGraphicsCommandList)res_pool_get_hot(&ctx.pool_cmd_list, cmd)

	num_render_targets := len(desc.color_attachments)
	render_target_descs := [4]d3d12.CPU_DESCRIPTOR_HANDLE{}

	for &color_attachment, i in desc.color_attachments {
		render_target_descs[i] = cast(d3d12.CPU_DESCRIPTOR_HANDLE)res_pool_get_hot(
			&ctx.pool_texture_view,
			color_attachment.view,
		).(Rtv)
	}

	cmd->OMSetRenderTargets(u32(num_render_targets), raw_data(&render_target_descs), false, nil)

	// Clear color targets
	for i in 0 ..< num_render_targets {
		clear_color := &desc.color_attachments[i].clear_color
		cmd->ClearRenderTargetView(render_target_descs[i], clear_color, 0, nil)
	}

	cmd->IASetPrimitiveTopology(.TRIANGLELIST)
}

cmd_end_rendering :: proc(cmd: Command_List) {}

cmd_dispatch :: proc(cmd: Command_List, group_count: [3]u32) {
	cmd := cast(^d3d12.IGraphicsCommandList)res_pool_get_hot(&ctx.pool_cmd_list, cmd)

	cmd->Dispatch(group_count.x, group_count.y, group_count.z)
}

@(private = "file")
format_map := [Format]dxgi.FORMAT {
	.Unknown     = .UNKNOWN,
	.R8_Unorm    = .R8_UNORM,
	.RG8_Unorm   = .R8G8_UNORM,
	.RGBA8_Unorm = .R8G8B8A8_UNORM,
	.BGRA8_Unorm = .B8G8R8A8_UNORM,
	.RGBA8_Srgb  = .R8G8B8A8_UNORM_SRGB,
	.BGRA8_Srgb  = .B8G8R8A8_UNORM_SRGB,
	.R32_F       = .R32_FLOAT,
	.RG32_F      = .R32G32_FLOAT,
	.RGB32_F     = .R32G32B32_FLOAT,
	.RGBA32_F    = .R32G32B32A32_FLOAT,
	.R32_U       = .R32_UINT,
	.RG32_U      = .R32G32_UINT,
	.RGB32_U     = .R32G32B32_UINT,
	.RGBA32_U    = .R32G32B32A32_UINT,
	.D32_F       = .D32_FLOAT,
	.BC1_Unorm   = .BC1_UNORM,
	.BC1_Srgb    = .BC1_UNORM_SRGB,
	.BC3_Unorm   = .BC3_UNORM,
	.BC3_Srgb    = .BC3_UNORM_SRGB,
	.BC4_Unorm   = .BC4_UNORM,
	.BC4_Snorm   = .BC4_SNORM,
	.BC5_Unorm   = .BC5_UNORM,
	.BC5_Snorm   = .BC5_SNORM,
	.BC6H_Uf16   = .BC6H_UF16,
	.BC6H_Sf16   = .BC6H_SF16,
	.BC7_Unorm   = .BC7_UNORM,
	.BC7_Srgb    = .BC7_UNORM_SRGB,
}

@(private = "file")
cull_mode_map := [Cull_Mode]d3d12.CULL_MODE {
	.None  = .NONE,
	.Front = .FRONT,
	.Back  = .BACK,
}

@(private = "file")
fill_mode_map := [Fill_Mode]d3d12.FILL_MODE {
	.Wireframe = .WIREFRAME,
	.Fill      = .SOLID,
}
