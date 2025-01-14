package main

import "core:fmt"
import "core:mem"
import sdl "vendor:sdl2"

WINDOW_TITLE :: "3D Renderer"
WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600
WINDOW_FLAGS :: sdl.WINDOW_RESIZABLE
RENDER_FLAGS :: sdl.RENDERER_ACCELERATED

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

    window, renderer, is_running := startup(WINDOW_TITLE, WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_FLAGS, RENDER_FLAGS)
    defer shutdown(renderer, window)

    for is_running {
        is_running = process_input()
        update()
        render(renderer)

        // Free all memory allocated this frame.
        mem.free_all(context.temp_allocator)
    }
}

startup :: proc(title: cstring, width, height: i32, window_flags: sdl.WindowFlags, render_flags: sdl.RendererFlags) -> (^sdl.Window, ^sdl.Renderer, bool) {
    if sdl.Init(sdl.INIT_EVERYTHING) != 0 {
        fmt.eprintln("Error initializing SDL.")
        return nil, nil, false
    }

    window := sdl.CreateWindow(title, sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED, width, height, window_flags)
    if window == nil {
        fmt.eprintln("Error initializing SDL window.")
        return nil, nil, false
    }

    renderer := sdl.CreateRenderer(window, -1, render_flags)
    if renderer == nil {
        fmt.eprintln("Error initializing SDL renderer.")
        return nil, nil, false
    }

    return window, renderer, true
}

shutdown :: proc(renderer: ^sdl.Renderer, window: ^sdl.Window) {
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

render :: proc(renderer: ^sdl.Renderer) {
    sdl.SetRenderDrawColor(renderer, 128, 128, 128, 255)
    sdl.RenderClear(renderer)
    sdl.RenderPresent(renderer)
}