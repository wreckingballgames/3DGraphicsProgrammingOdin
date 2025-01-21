package main

Triangle :: distinct [3]Vector3
Projected_Triangle :: struct {
    a: Vector2,
    b: Vector2,
    c: Vector2,
    color: u32,
    average_depth: f32,
}
Face :: struct {
    a: int,
    b: int,
    c: int,
    color: u32,
}

// Assumes Projected_Triangle's vertices are sorted y-ascending
find_midpoint_of_projected_triangle :: proc(tri: Projected_Triangle) -> Vector2 {
    m_x := ((tri.c.x - tri.a.x) * (tri.b.y - tri.a.y) / (tri.c.y - tri.a.y)) + tri.a.x
    m_y := tri.b.y
    return {m_x, m_y}
}
