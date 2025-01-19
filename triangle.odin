package main

Triangle :: distinct [3]Vector3
Projected_Triangle :: distinct [3]Vector2
Face :: distinct [3]int

// Assumes Projected_Triangle's vertices are sorted y-ascending
find_midpoint_of_projected_triangle :: proc(tri: Projected_Triangle) -> Vector2 {
    m_x := ((tri[2].x - tri[0].x) * (tri[1].y - tri[0].y) / (tri[2].y - tri[0].y)) + tri[0].x
    m_y := tri[1].y
    return {m_x, m_y}
}
