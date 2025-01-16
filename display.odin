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

draw_rectangle :: proc(color_buffer: []u32, window_width, x, y, width, height: int, color: u32) {
    for i := y; i < y + height; i += 1 {
        for j := x; j < x + width; j += 1 {
            color_buffer[window_width * i + j] = color
        }
    }
}

draw_pixel :: proc(color_buffer: []u32, window_width, x, y: int, color: u32) {
    color_buffer[window_width * y + x] = color
}