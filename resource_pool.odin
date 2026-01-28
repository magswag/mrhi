package mrhi

Handle :: struct {
	index:      u16,
	generation: u16,
}

Resource_Pool :: struct($capacity: u16, $HandleT: typeid, $Hot: typeid, $Cold: typeid) {
	hot:         [dynamic]Hot,
	cold:        [dynamic]Cold,
	generations: [dynamic]u16,
	free_list:   [dynamic]u16,
}

res_pool_init :: proc(pool: ^Resource_Pool($capacity, $HandleT/Handle, $Hot, $Cold)) {
	pool.hot = make([dynamic]Hot, capacity)
	pool.cold = make([dynamic]Cold, capacity)
	pool.generations = make([dynamic]u16, capacity)
	pool.free_list = make([dynamic]u16, capacity)

	for i in 0 ..< capacity {
		append(&pool.free_list, capacity - i)
	}
}

res_pool_insert :: proc(
	pool: ^Resource_Pool($capacity, $HandleT/Handle, $Hot, $Cold),
	hot: Hot,
) -> HandleT {
	index := pop(&pool.free_list)
	pool.hot[index] = hot
	pool.generations[index] += 1

	return HandleT{index = index, generation = pool.generations[index]}
}

res_pool_get_hot :: proc(
	pool: ^Resource_Pool($capacity, $HandleT/Handle, $Hot, $Cold),
	handle: HandleT,
) -> Hot {
	return pool.hot[handle.index]
}

res_pool_get_cold :: proc(
	pool: ^Resource_Pool($capacity, $HandleT/Handle, $Hot, $Cold),
	handle: HandleT,
) -> Cold {
	return pool.cold[handle.index]
}

res_pool_destroy :: proc(pool: ^Resource_Pool($capacity, $HandleT/Handle, $Hot, $Cold)) {
	delete(pool.hot)
	delete(pool.cold)
	delete(pool.generations)
	delete(pool.free_list)
}
