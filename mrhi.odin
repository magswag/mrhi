package mrhi

Present_Mode :: enum u8 {
	Fifo,
	Immediate,
	Mailbox,
}

Queue :: enum u8 {
	Graphics,
	Compute,
	Transfer,
}

Format :: enum u8 {
	Unknown,

	// 8-bit Unsigned Normalized
	R8_Unorm,
	RG8_Unorm,
	RGBA8_Unorm,
	BGRA8_Unorm,

	// 8-bit sRGB
	RGBA8_Srgb,
	BGRA8_Srgb,

	// 32-bit Floating Point
	R32_F,
	RG32_F,
	RGB32_F,
	RGBA32_F,

	// 32-bit Unsigned Integer
	R32_U,
	RG32_U,
	RGB32_U,
	RGBA32_U,

	// Depth
	D32_F,

	// Compressed (Block)
	BC1_Unorm,
	BC1_Srgb,
	BC3_Unorm,
	BC3_Srgb,
	BC4_Unorm,
	BC4_Snorm,
	BC5_Unorm,
	BC5_Snorm,
	BC6H_Uf16,
	BC6H_Sf16,
	BC7_Unorm,
	BC7_Srgb,
}

Memory :: enum u8 {
	CPU,
	GPU,
}

Buffer_Usage :: enum u8 {
	Vertex_Read,
	Index_Read,
	Shader_Read,
	Shader_Write,
	Indirect_Read,
	Copy_Src,
	Copy_Dst,
}

Buffer_Usage_Set :: bit_set[Buffer_Usage]

Buffer_Desc :: struct {
	debug_name: Maybe(string),
	byte_size:  u32,
	usage:      Buffer_Usage_Set,
	memory:     Memory,
}

Texture_Usage :: enum u8 {
	Shader_Read,
	Shader_Write,
	Color_Write,
	Depth_Write,
	Depth_Read,
	Copy_Src,
	Copy_Dst,
}

Texture_Usage_Set :: bit_set[Texture_Usage]

Texture_Desc :: struct {
	debug_name: Maybe(string),
	dimensions: [3]u32,
	format:     Format,
}

Texture_View_Desc :: struct {
	texture:     Texture,
	base_mip:    u8,
	mip_count:   Maybe(u8), // If none, all mips
	base_layer:  u16,
	layer_count: Maybe(u16), // If none, all layers
}

// Graphics pipeline
Fill_Mode :: enum u8 {
	Fill,
	Wireframe,
}

Cull_Mode :: enum u8 {
	None,
	Back,
	Front,
}

Msaa_Sample_Count :: enum u8 {
	x1,
	x2,
	x4,
	x8,
}

Shader_Stage_Desc :: struct {
	shader: Shader,
	entry:  string,
}

Graphics_Pipeline_Desc :: struct {
	debug_name:     Maybe(string),
	task_stage:     Maybe(Shader_Stage_Desc),
	mesh_stage:     Maybe(Shader_Stage_Desc),
	vertex_stage:   Maybe(Shader_Stage_Desc),
	fragment_stage: Maybe(Shader_Stage_Desc),
	rasterizer:     struct {
		fill_mode:         Fill_Mode,
		cull_mode:         Cull_Mode,
		counter_clockwise: bool,
	},
	color_formats:  []Format,
	depth_format:   Maybe(Format),
	depth_stencil:  struct {
		enable_depth:   bool,
		enable_stencil: bool,
	},
	msaa_samples:   Msaa_Sample_Count,
}

Compute_Pipeline_Desc :: struct {
	debug_name: Maybe(string),
	shader:     Shader,
}

Ray_Tracing_Pipeline_Desc :: struct {}

Accel_Struct_Update_Mode :: enum u8 {
	Build,
	Prefer_Update,
}

Accel_Struct_Flags :: enum u8 {
	Allow_Update,
	Allow_Compaction,
	Prefer_Fast_Trace,
	Prefer_Fast_Build,
	Low_Memory,
	Use_Transform,
	Allow_Ray_Hit_Vertex_Return,
}

Accel_Struct_Flags_Set :: bit_set[Accel_Struct_Flags]

Tlas_Desc :: struct {
	max_instances: u32,
	flags:         Accel_Struct_Flags_Set,
	update_mode:   Accel_Struct_Update_Mode,
}

Blas_Desc :: struct {
	flags:       Accel_Struct_Flags_Set,
	update_mode: Accel_Struct_Update_Mode,
}

Render_Desc :: struct {
	area:              [2]u32,
	layer_count:       u32,
	color_attachments: []struct {
		view:         Texture_View,
		resolve_view: Maybe(Texture_View),
		clear_color:  [4]f32,
	},
	depth_attachment:  Maybe(Texture_View),
}

Surface_Config :: struct {
	extent:                   [2]u32,
	format:                   Format,
	present_mode:             Present_Mode,
	desired_frames_in_flight: u32,
}
