package mrhi

Queue :: enum {
	Graphics,
	Compute,
	Transfer,
}

Format :: enum {
	Unknown,
	RGBA8_sRGB,
	D32,
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
	debug_name: string,
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
	debug_name: string,
	dimensions: [3]u32,
	format:     Format,
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

Rasterizer_Desc :: struct {
	fill_mode:         Fill_Mode,
	cull_mode:         Cull_Mode,
	counter_clockwise: bool,
}

Depth_Stencil_Desc :: struct {
	enable_depth:   bool,
	enable_stencil: bool,
}

Graphics_Pipeline_Desc :: struct {
	debug_name:    string,
	rasterizer:    Rasterizer_Desc,
	color_formats: []Format,
	depth_format:  Maybe(Format),
	depth_stencil: Depth_Stencil_Desc,
}

Compute_Pipeline_Desc :: struct {
	debug_name: string,
	shader:     Shader,
}
