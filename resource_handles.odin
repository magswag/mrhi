package mrhi

Buffer :: distinct Handle
Texture :: distinct Handle
Texture_View :: distinct Handle
Surface :: distinct Handle
Shader :: distinct Handle
Command_List :: distinct Handle
Graphics_Pipeline :: distinct Handle
Compute_Pipeline :: distinct Handle
Ray_Tracing_Pipeline :: distinct Handle
Tlas :: distinct Handle
Blas :: distinct Handle

Pipeline :: union {
	Graphics_Pipeline,
	Compute_Pipeline,
}
