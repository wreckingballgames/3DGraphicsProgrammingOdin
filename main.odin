package main

import "core:fmt"
import sdl "vendor:sdl2"

WINDOW_TITLE :: "3D Renderer"
WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600
WINDOW_FLAGS :: sdl.WINDOW_RESIZABLE
RENDER_FLAGS :: sdl.RENDERER_ACCELERATED

main :: proc() {
    window, renderer, is_running := startup(WINDOW_TITLE, WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_FLAGS, RENDER_FLAGS)
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
