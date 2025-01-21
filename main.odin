package main

import "core:fmt"
import "core:mem"
import sdl "vendor:sdl2"

WINDOW_TITLE :: "3D Renderer"
WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600
WINDOW_FLAGS :: sdl.WINDOW_RESIZABLE
RENDER_FLAGS :: sdl.RENDERER_ACCELERATED
TARGET_FPS :: 60
TARGET_FRAME_TIME_IN_MILLISECONDS :: 1000 / TARGET_FPS

car: ^Mesh
cube: ^Mesh
triangles_to_render: [dynamic]Projected_Triangle

draw_mode := Draw_Mode.Solid_And_Wireframe
backface_culling_mode := Backface_Culling_Mode.Backface_Culling_Enabled

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

    camera_position := Vector3 {0, 0, 0}

    car, _ = load_obj_file_data("./assets/vehicle-racer-low.obj")
    defer delete_mesh(car)

    cube, _ = load_obj_file_data("./assets/cube.obj")
    cube.faces[0].color = 0xFFFF0000
    cube.faces[1].color = 0xFFFF0000
    cube.faces[2].color = 0xFF00FF00
    cube.faces[3].color = 0xFF00FF00
    cube.faces[4].color = 0xFF0000FF
    cube.faces[5].color = 0xFF0000FF
    cube.faces[6].color = 0xFFFFFF00
    cube.faces[7].color = 0xFFFFFF00
    cube.faces[8].color = 0xFFFF00FF
    cube.faces[9].color = 0xFFFF00FF
    cube.faces[10].color = 0xFF00FFFF
    cube.faces[11].color = 0xFF00FFFF
    defer delete_mesh(cube)

    previous_frame_time: u32

    is_running := true
    for is_running {
        previous_frame_time = sdl.GetTicks()
        is_running = process_input()
        update(previous_frame_time)
        render(renderer, camera_position, color_buffer, color_buffer_texture, WINDOW_WIDTH, WINDOW_HEIGHT)

        // Free all memory allocated this frame.
        mem.free_all(context.temp_allocator)
    }
}

shutdown :: proc(renderer: ^sdl.Renderer, window: ^sdl.Window, color_buffer: []u32, color_buffer_texture: ^sdl.Texture) {
    delete(triangles_to_render)
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
            } else if event.key.keysym.sym == .NUM1 {
                draw_mode = .Wireframe_And_Vertices
            } else if event.key.keysym.sym == .NUM2 {
                draw_mode = .Wireframe_Only
            } else if event.key.keysym.sym == .NUM3 {
                draw_mode = .Solid_Only
            } else if event.key.keysym.sym == .NUM4 {
                draw_mode = .Solid_And_Wireframe
            } else if event.key.keysym.sym == .C {
                backface_culling_mode = .Backface_Culling_Enabled
            } else if event.key.keysym.sym == .D {
                backface_culling_mode = .Backface_Culling_Disabled
            }
    }

    return true
}

update :: proc(previous_frame_time: u32) {
    // Enforce fixed timestep
    time_to_wait := TARGET_FRAME_TIME_IN_MILLISECONDS - (sdl.GetTicks() - previous_frame_time)
    if time_to_wait > 0 && time_to_wait <= TARGET_FRAME_TIME_IN_MILLISECONDS {
        sdl.Delay(time_to_wait)
    }

    cube.rotation += 0.01
    // car.rotation.y += 0.01
}

render :: proc(renderer: ^sdl.Renderer, camera_position: Vector3, color_buffer: []u32, color_buffer_texture: ^sdl.Texture, window_width, window_height: int) {
    clear_color_buffer(color_buffer, 0x00000000, window_width, window_height)

    // draw_grid(color_buffer, window_width, window_height, 0xFFAAAAAA, 10, 10, .Solid)

    transform_and_project_mesh(color_buffer, window_width, window_height, cube^, camera_position, 900, backface_culling_mode)
    // transform_and_project_mesh(color_buffer, window_width, window_height, car^, camera_position, 900, backface_culling_mode)

    if draw_mode == .Wireframe_Only {
        render_unfilled_triangles(color_buffer, window_width, window_height, 0xFFFFFF00)
    } else if draw_mode == .Wireframe_And_Vertices {
        render_unfilled_triangles(color_buffer, window_width, window_height, 0xFFFFFF00)
        render_triangle_vertices(color_buffer, window_width, window_height, 10, 10, 0xFFFF0000)
    } else if draw_mode == .Solid_Only {
        render_filled_triangles(color_buffer, window_width, window_height, 0xFFFFFF00)
    } else if draw_mode == .Solid_And_Wireframe {
        render_filled_triangles(color_buffer, window_width, window_height, 0xFFFFFF00)
        render_unfilled_triangles(color_buffer, window_width, window_height, 0xFFFF0000)
    }

    // Empty buffer of tris to render.
    clear(&triangles_to_render)

    render_color_buffer(renderer, color_buffer, color_buffer_texture, window_width)
    sdl.RenderPresent(renderer)
}
