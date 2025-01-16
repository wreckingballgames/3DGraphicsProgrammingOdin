package main

import "core:fmt"
import "core:mem"
import sdl "vendor:sdl2"

WINDOW_TITLE :: "3D Renderer"
WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600
WINDOW_FLAGS :: sdl.WINDOW_RESIZABLE
RENDER_FLAGS :: sdl.RENDERER_ACCELERATED

Vector2 :: distinct [2]f32
Vector3 :: distinct [3]f32

main :: proc() {
    // Tracking allocator code adapted from Karl Zylinski's tutorials.
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    context.allocator = mem.tracking_allocator(&track)

    defer {
        for _, entry in track.allocation_map {
            fmt.eprintf("%v leaked %v bytes.\n", entry.location, entry.size)
        }
        for entry in track.bad_free_array {
            fmt.eprintf("%v bad free.\n", entry.location)
        }
        mem.tracking_allocator_destroy(&track)
    }

    if sdl.Init(sdl.INIT_EVERYTHING) != 0 {
        fmt.eprintln("Error initializing SDL.")
    }

    window := sdl.CreateWindow(WINDOW_TITLE, sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED, WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_FLAGS)
    if window == nil {
        fmt.eprintln("Error initializing SDL window.")
        return
    }

    renderer := sdl.CreateRenderer(window, -1, RENDER_FLAGS)
    if renderer == nil {
        fmt.eprintln("Error initializing SDL renderer.")
        sdl.DestroyWindow(window)
        return
    }

    color_buffer := make([]u32, size_of(u32) * WINDOW_WIDTH * WINDOW_HEIGHT)
    if color_buffer == nil {
        fmt.eprintln("Error allocating color buffer.")
        sdl.DestroyRenderer(renderer)
        sdl.DestroyWindow(window)
        return
    }

    color_buffer_texture := sdl.CreateTexture(renderer, .ARGB8888, .STREAMING, WINDOW_WIDTH, WINDOW_HEIGHT)
    if color_buffer_texture == nil {
        fmt.eprintln("Error creating color buffer texture.")
        delete(color_buffer)
        sdl.DestroyRenderer(renderer)
        sdl.DestroyWindow(window)
        return
    }
    defer shutdown(renderer, window, color_buffer, color_buffer_texture)

    is_running := true
    for is_running {
        is_running = process_input()
        update()
        render(renderer, color_buffer, color_buffer_texture, WINDOW_WIDTH, WINDOW_HEIGHT)

        // Free all memory allocated this frame.
        mem.free_all(context.temp_allocator)
    }
}

shutdown :: proc(renderer: ^sdl.Renderer, window: ^sdl.Window, color_buffer: []u32, color_buffer_texture: ^sdl.Texture) {
    delete(color_buffer)
    sdl.DestroyTexture(color_buffer_texture)
    sdl.DestroyRenderer(renderer)
    sdl.DestroyWindow(window)
    sdl.Quit()
}

process_input :: proc() -> bool {
    event: sdl.Event
    sdl.PollEvent(&event)

    #partial switch event.type {
        case .QUIT:
            return false
        case .KEYDOWN:
            if event.key.keysym.sym == .ESCAPE {
                return false
            }
    }

    return true
}

update :: proc() {
    // TODO
}

render :: proc(renderer: ^sdl.Renderer, color_buffer: []u32, color_buffer_texture: ^sdl.Texture, window_width, window_height: int) {
    clear_color_buffer(color_buffer, 0x00000000, window_width, window_height)

    // draw_grid(color_buffer, window_width, window_height, 0xFFAAAAAA, 10, 10, .Solid)

    // Create a 9x9x9 cube of points in 3D space.
    NUM_POINTS_IN_CUBE :: 9 * 9 * 9
    cube_points := make([]Vector3, NUM_POINTS_IN_CUBE, context.temp_allocator)

    // Load cube points from -1 to 1.
    point_count: int
    for x: f32 = -1.0; x <= 1.0; x += 0.25 {
        for y: f32 = -1.0; y <= 1.0; y += 0.25 {
            for z: f32 = -1.0; z <= 1.0; z += 0.25 {
                cube_points[point_count] = Vector3 {x, y, z}
                point_count += 1
            }
        }
    }

    project_and_draw_cube(color_buffer, window_width, window_height, cube_points, NUM_POINTS_IN_CUBE, 128)

    render_color_buffer(renderer, color_buffer, color_buffer_texture, window_width)

    sdl.RenderPresent(renderer)
}

// Takes a 3D vector and returns a projected 2D point.
project :: proc(vector: Vector3, fov_factor: f32) -> Vector2 {
    return vector.xy * fov_factor
}

project_and_draw_cube :: proc(color_buffer: []u32, window_width, window_height: int, cube_points: []Vector3, $num_points_in_cube: int, fov_factor: f32) {
    // Project and render all points in cube.
    for i := 0; i < num_points_in_cube; i += 1 {
        projected_point := project(cube_points[i], fov_factor)
        draw_rectangle(color_buffer, window_width, window_height, int(projected_point.x) + window_width / 2, int(projected_point.y) + window_height / 2, 4, 4, 0xFFFFFF00)
    }
}