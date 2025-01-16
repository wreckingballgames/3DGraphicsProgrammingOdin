package main

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

project_and_draw_cube :: proc(color_buffer: []u32, window_width, window_height: int, cube_points: []Vector3, $num_points_in_cube: int, fov_factor: f32) {
    // Project and render all points in cube.
    for i := 0; i < num_points_in_cube; i += 1 {
        projected_point := project(cube_points[i], fov_factor, .Perspective)
        draw_rectangle(color_buffer,
            window_width,
            window_height,
            int(projected_point.x) + window_width / 2,
            int(projected_point.y) + window_height / 2,
            4,
            4,
            0xFFFFFF00
        )
    }
}