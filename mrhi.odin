package mrhi

Queue :: enum {
	Graphics,
	Compute,
	Transfer,
}

Format :: enum {
	Unknown,
	R32_Float,
	RG32_Float,
	RGB32_Float,
	RGBA32_Float,
	R32_Uint,
	RG32_Uint,
	RGB32_Uint,
	RGBA32_Uint,
	RGBA8_sRGB,
	D32_Float,
}

Memory :: enum {
	CPU,
	GPU,
}

Buffer_Usage :: enum {
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

Texture_Usage :: enum {
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
Fill_Mode :: enum {
	Fill,
	Wireframe,
}

Cull_Mode :: enum {
	None,
	Back,
	Front,
}

Graphics_Pipeline_Desc :: struct {
	debug_name:    Maybe(string),
	rasterizer:    struct {
		fill_mode:         Fill_Mode,
		cull_mode:         Cull_Mode,
		counter_clockwise: bool,
	},
	color_formats: []Format,
	depth_format:  Maybe(Format),
	depth_stencil: struct {
		enable_depth:   bool,
		enable_stencil: bool,
	},
}

Compute_Pipeline_Desc :: struct {
	debug_name: Maybe(string),
	shader:     Shader,
}

Ray_Tracing_Pipeline_Desc :: struct {}

Accel_Struct_Update_Mode :: enum {
	Build,
	Prefer_Update,
}

Accel_Struct_Flags :: enum {
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
