package main

import "core:fmt"
import "core:mem"
import "core:math"
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

    camera_position := Vector3 {0, 0, -5}

    is_running := true
    for is_running {
        is_running = process_input()
        update()
        render(renderer, camera_position, color_buffer, color_buffer_texture, WINDOW_WIDTH, WINDOW_HEIGHT)

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

render :: proc(renderer: ^sdl.Renderer, camera_position: Vector3, color_buffer: []u32, color_buffer_texture: ^sdl.Texture, window_width, window_height: int) {
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
                cube_points[point_count] = Vector3 {x, y, z - camera_position.z}
                point_count += 1
            }
        }
    }

    project_and_draw_cube(color_buffer, window_width, window_height, cube_points, NUM_POINTS_IN_CUBE, 640)

    render_color_buffer(renderer, color_buffer, color_buffer_texture, window_width)

    sdl.RenderPresent(renderer)
}

vector3_rotate_x :: proc(vector: Vector3, angle: f32) -> Vector3 {
    return Vector3 {
        vector.x,
        vector.y * math.cos(angle) - vector.z * math.sin(angle),
        vector.z * math.cos(angle) + vector.y * math.sin(angle),
    }
}

vector3_rotate_y :: proc(vector: Vector3, angle: f32) -> Vector3 {
    return Vector3 {
        vector.x * math.cos(angle) - vector.z * math.sin(angle),
        vector.y,
        vector.z * math.cos(angle) + vector.x * math.sin(angle),
    }
}

vector3_rotate_z :: proc(vector: Vector3, angle: f32) -> Vector3 {
    return Vector3 {
        vector.x * math.cos(angle) - vector.y * math.sin(angle),
        vector.y * math.cos(angle) + vector.x * math.sin(angle),
        vector.z,
    }
}