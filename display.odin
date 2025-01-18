package main

import "core:math"
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

draw_triangle :: proc(color_buffer: []u32, window_width, window_height, x0, y0, x1, y1, x2, y2: int, color: u32) {
    draw_line(color_buffer, window_width, window_height, x0, y0, x1, y1, color)
    draw_line(color_buffer, window_width, window_height, x1, y1, x2, y2, color)
    draw_line(color_buffer, window_width, window_height, x2, y2, x0, y0, color)
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
    for i := 0; i < len(mesh.tris); i += 1 {
        tri := mesh.tris[i]
        projected_tri: Projected_Triangle

        // Transform and project all vertices in tri.
        for j := 0; j < len(tri); j += 1 {
            transformed_vertex := vector3_rotate_x(tri[j], mesh.rotation.x)
            transformed_vertex = vector3_rotate_y(transformed_vertex, mesh.rotation.y)
            transformed_vertex = vector3_rotate_z(transformed_vertex, mesh.rotation.z)

            // Translate the vertex away from the camera
            transformed_vertex.z -= camera_position.z

            projected_vertex := project(transformed_vertex, fov_factor, .Perspective)

            // Scale and translate the projected tris to middle of the screen
            projected_vertex.x += f32(window_width) / 2
            projected_vertex.y += f32(window_height) / 2

            projected_tri[j] = projected_vertex
        }

        // Save the projected tri to the global array of tris to render.
        append(&triangles_to_render, projected_tri)
    }
}

render_triangles :: proc(color_buffer: []u32, window_width, window_height: int, color: u32) {
    for tri in triangles_to_render {
        // Draw triangle vertices
        draw_rectangle(color_buffer, window_width, window_height, int(tri[0].x), int(tri[0].y), 3, 3, color)
        draw_rectangle(color_buffer, window_width, window_height, int(tri[1].x), int(tri[1].y), 3, 3, color)
        draw_rectangle(color_buffer, window_width, window_height, int(tri[2].x), int(tri[2].y), 3, 3, color)


        // Draw triangle face
        draw_triangle(color_buffer,
            window_width,
            window_height,
            int(tri[0].x),
            int(tri[0].y),
            int(tri[1].x),
            int(tri[1].y),
            int(tri[2].x),
            int(tri[2].y),
            color
        )
    }
}
