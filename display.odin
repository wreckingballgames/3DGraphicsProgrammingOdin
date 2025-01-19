package main

import "core:math"
import "core:math/linalg"
import sdl "vendor:sdl2"

Grid_Style :: enum {
    Solid,
    Dotted,
}

clear_color_buffer :: proc(color_buffer: []u32, color: u32, width, height: int) {
    color_buffer := color_buffer
    for y := 0; y < height; y += 1 {
        for x := 0; x < width; x += 1 {
            color_buffer[width * y + x] = color
        }
    }
}

render_color_buffer :: proc(renderer: ^sdl.Renderer, color_buffer: []u32, texture: ^sdl.Texture, window_width: int) {
    sdl.UpdateTexture(texture, nil, raw_data(color_buffer), i32(window_width * size_of(u32)))
    sdl.RenderCopy(renderer, texture, nil, nil)
}

draw_grid :: proc(color_buffer: []u32, width, height: int, color: u32, dx, dy: int, grid_style: Grid_Style) {
    switch grid_style {
        case .Solid:
            for y := 0; y < height; y += 1 {
                for x := 0; x < width; x += 1 {
                    if x % dx == 0 || y % dy == 0 {
                        color_buffer[width * y + x] = color
                    }
                }
            }
        case .Dotted:
            for y := 0; y < height; y += dy {
                for x := 0; x < width; x += dx {
                    color_buffer[width * y + x] = color
                }
            }
    }
}

draw_rectangle :: proc(color_buffer: []u32, window_width, window_height, x, y, width, height: int, color: u32) {
    for i := y; i < y + height; i += 1 {
        for j := x; j < x + width; j += 1 {
            draw_pixel(color_buffer, window_width, window_height, x, y, color)
        }
    }
}

draw_pixel :: proc(color_buffer: []u32, window_width, window_height, x, y: int, color: u32) {
    if x > 0 && x < window_width && y > 0 && y < window_height {
        color_buffer[window_width * y + x] = color
    }
}

draw_line :: proc(color_buffer: []u32, window_width, window_height, x0, y0, x1, y1: int, color: u32) {
    delta_x := x1 - x0
    delta_y := y1 - y0

    longest_side_length := math.max(math.abs(delta_x), math.abs(delta_y))

    // Calculate how much to increment each step
    x_inc := f32(delta_x) / f32(longest_side_length)
    y_inc := f32(delta_y) / f32(longest_side_length)

    current_x := f32(x0)
    current_y := f32(y0)
    for i := 0; i <= longest_side_length; i += 1 {
        draw_pixel(color_buffer,
            window_width,
            window_height,
            int(math.round(current_x)),
            int(math.round(current_y)),
            color
        )
        current_x += x_inc
        current_y += y_inc
    }
}

draw_triangle :: proc(color_buffer: []u32, window_width, window_height: int, tri: Projected_Triangle, color: u32) {
    draw_line(color_buffer, window_width, window_height, int(tri[0].x), int(tri[0].y), int(tri[1].x), int(tri[1].y), color)
    draw_line(color_buffer, window_width, window_height, int(tri[1].x), int(tri[1].y), int(tri[2].x), int(tri[2].y), color)
    draw_line(color_buffer, window_width, window_height, int(tri[2].x), int(tri[2].y), int(tri[0].x), int(tri[0].y), color)
}

draw_filled_triangle :: proc(color_buffer: []u32, window_width, window_height: int, tri: Projected_Triangle, color: u32) {
    tri := tri
    // Sort tri vertices by y-value ascending (y0 < y1 < y2)
    if tri[0].y > tri[1].y {
        temp := tri[0]
        tri[0] = tri[1]
        tri[1] = temp
    }
    if tri[1].y > tri[2].y {
        temp := tri[1]
        tri[1] = tri[2]
        tri[2] = temp
    }
    if tri[0].y > tri[1].y {
        temp := tri[0]
        tri[0] = tri[1]
        tri[1] = temp
    }

    // Calculate the new vertex (Mx, My) using triangle similarity
    midpoint_vertex := find_midpoint_of_projected_triangle(tri)

    fill_flat_bottom_triangle(color_buffer, window_width, window_height, Projected_Triangle {tri[0], tri[1], midpoint_vertex}, color)
    fill_flat_top_triangle(color_buffer, window_width, window_height, Projected_Triangle {tri[1], midpoint_vertex, tri[2]}, color)
}

fill_flat_bottom_triangle :: proc(color_buffer: []u32, window_width, window_height: int, tri: Projected_Triangle, color: u32) {
    // Find the two (inverted) slopes (the two legs of the triangle)
    inverted_slope1 := (tri[1].x - tri[0].x) / (tri[1].y - tri[0].y)
    inverted_slope2 := (tri[2].x - tri[0].x) / (tri[2].y - tri[0].y)

    // Loop all the scanlines from top to bottom.
    x_start := tri[0].x
    x_end := tri[0].x
    for y := tri[0].y; y <= tri[2].y; y += 1 {
        draw_line(color_buffer, window_width, window_height, int(x_start), int(y), int(x_end), int(y), color)
        x_start += inverted_slope1
        x_end += inverted_slope2
    }
}

fill_flat_top_triangle :: proc(color_buffer: []u32, window_width, window_height: int, tri: Projected_Triangle, color: u32) {
    // Find the two (inverted) slopes (the two legs of the triangle)
    inverted_slope1 := (tri[2].x - tri[0].x) / (tri[2].y - tri[0].y)
    inverted_slope2 := (tri[2].x - tri[1].x) / (tri[2].y - tri[1].y)

    // Loop all the scanlines from top to bottom.
    x_start := tri[2].x
    x_end := tri[2].x
    for y := tri[2].y; y >= tri[0].y; y -= 1 {
        draw_line(color_buffer, window_width, window_height, int(x_start), int(y), int(x_end), int(y), color)
        x_start -= inverted_slope1
        x_end -= inverted_slope2
    }
}

// Takes a 3D vector and returns a projected 2D point.
project :: proc(vector: Vector3, fov_factor: f32, projection_style: Projection_Style) -> Vector2 {
    if projection_style == .Perspective {
        return vector.xy * fov_factor / vector.z
    } else {
        return vector.xy * fov_factor
    }
}

Projection_Style :: enum {
    Perspective,
    Orthographic,
}

// Transforms and projects all of a mesh's points before storing them in a global array of screen-space points to render.
transform_and_project_mesh :: proc(color_buffer: []u32, window_width, window_height: int, mesh: Mesh, camera_position: Vector3, fov_factor: f32) {
    // Transform and project all tris in mesh.
    for i := 0; i < len(mesh.faces); i += 1 {
        face := mesh.faces[i]
        tri: Triangle

        tri[0] = mesh.vertices[face[0]]
        tri[1] = mesh.vertices[face[1]]
        tri[2] = mesh.vertices[face[2]]

        // Transform all vertices in tri.
        transformed_tri: Triangle
        for j := 0; j < len(face); j += 1 {
            transformed_vertex := vector3_rotate_x(tri[j], mesh.rotation.x)
            transformed_vertex = vector3_rotate_y(transformed_vertex, mesh.rotation.y)
            transformed_vertex = vector3_rotate_z(transformed_vertex, mesh.rotation.z)

            // Translate the vertex a base 5 units away from the camera, assuming camera position (0, 0, 0).
            transformed_vertex.z -= 5

            // Save transformed vertices.
            transformed_tri[j] = transformed_vertex
        }

        // Perform back-face culling.
        //   A
        //  /\
        // C--B
        // Find the normal vector (cross product of vector B - A and vector C - A)
        // Vector order would be reversed in a right-handed coordinate system.
        normal := linalg.vector_cross3(transformed_tri.y - transformed_tri.x, transformed_tri.z - transformed_tri.x)
        // Find the camera ray (vector from point A of our tri to camera position).
        camera_ray := camera_position - transformed_tri.x
        // Check alignment of camera ray to normal (dot product). If alignment is less than or equal to 0, do not render the tri.
        if linalg.vector_dot(camera_ray, normal) < 0 {
            continue
        }

        // Project all vertices in tri.
        projected_tri: Projected_Triangle
        for j := 0; j < len(face); j += 1 {
            // Project all vertices in tri.
            projected_vertex: Vector2
            projected_vertex = project(transformed_tri[j], fov_factor, .Perspective)

            // Scale and translate the projected tris to middle of the screen
            projected_vertex.x += f32(window_width) / 2
            projected_vertex.y += f32(window_height) / 2

            projected_tri[j] = projected_vertex
        }


        // Save the projected tri to the global array of tris to render.
        append(&triangles_to_render, projected_tri)
    }
}

render_unfilled_triangles :: proc(color_buffer: []u32, window_width, window_height: int, color: u32) {
    for tri in triangles_to_render {
        // Draw triangle vertices
        draw_rectangle(color_buffer, window_width, window_height, int(tri[0].x), int(tri[0].y), 3, 3, color)
        draw_rectangle(color_buffer, window_width, window_height, int(tri[1].x), int(tri[1].y), 3, 3, color)
        draw_rectangle(color_buffer, window_width, window_height, int(tri[2].x), int(tri[2].y), 3, 3, color)


        // Draw triangle face
        draw_triangle(color_buffer,
            window_width,
            window_height,
            tri,
            color
        )
    }
}

render_filled_triangles :: proc(color_buffer: []u32, window_width, window_height: int, color: u32) {
    for tri in triangles_to_render {
        // Draw triangle vertices
        draw_rectangle(color_buffer, window_width, window_height, int(tri[0].x), int(tri[0].y), 3, 3, color)
        draw_rectangle(color_buffer, window_width, window_height, int(tri[1].x), int(tri[1].y), 3, 3, color)
        draw_rectangle(color_buffer, window_width, window_height, int(tri[2].x), int(tri[2].y), 3, 3, color)


        // Draw triangle face
        draw_filled_triangle(color_buffer,
            window_width,
            window_height,
            tri,
            color
        )
    }
}
