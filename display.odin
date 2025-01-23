package main

import "core:math"
import "core:math/linalg"
import "core:slice"
import sdl "vendor:sdl2"
import "core:fmt"

Grid_Style :: enum {
    Solid,
    Dotted,
}

Draw_Mode :: enum {
    Wireframe_Only,
    Wireframe_And_Vertices,
    Solid_Only,
    Solid_And_Wireframe,
}

Backface_Culling_Mode :: enum {
    Backface_Culling_Enabled,
    Backface_Culling_Disabled,
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

draw_unfilled_triangle :: proc(color_buffer: []u32, window_width, window_height: int, tri: Projected_Triangle) {
    draw_line(color_buffer, window_width, window_height, int(tri.a.x), int(tri.a.y), int(tri.b.x), int(tri.b.y), tri.color)
    draw_line(color_buffer, window_width, window_height, int(tri.b.x), int(tri.b.y), int(tri.c.x), int(tri.c.y), tri.color)
    draw_line(color_buffer, window_width, window_height, int(tri.c.x), int(tri.c.y), int(tri.a.x), int(tri.a.y), tri.color)
}

draw_filled_triangle :: proc(color_buffer: []u32, window_width, window_height: int, tri: Projected_Triangle) {
    tri := tri
    // Sort tri vertices by y-value ascending (y0 < y1 < y2)
    if tri.a.y > tri.b.y {
        temp := tri.a
        tri.a = tri.b
        tri.b = temp
    }
    if tri.b.y > tri.c.y {
        temp := tri.b
        tri.b = tri.c
        tri.c = temp
    }
    if tri.a.y > tri.b.y {
        temp := tri.a
        tri.a = tri.b
        tri.b = temp
    }

    // If tri is flat-top or flat-bottom, less than half the work is required to fill it.
    if tri.b.y == tri.c.y {
        fill_flat_bottom_triangle(color_buffer, window_width, window_height, tri)
    } else if tri.a.y == tri.b.y {
        fill_flat_top_triangle(color_buffer, window_width, window_height, tri)
    } else {
        // Calculate the new vertex (Mx, My) using triangle similarity
        midpoint_vertex := find_midpoint_of_projected_triangle(tri)

        fill_flat_bottom_triangle(color_buffer, window_width, window_height, Projected_Triangle {tri.a, tri.b, midpoint_vertex, tri.color, tri.average_depth})
        fill_flat_top_triangle(color_buffer, window_width, window_height, Projected_Triangle {tri.b, midpoint_vertex, tri.c, tri.color, tri.average_depth})
    }
}

fill_flat_bottom_triangle :: proc(color_buffer: []u32, window_width, window_height: int, tri: Projected_Triangle) {
    // Find the two (inverted) slopes (the two legs of the triangle)
    inverted_slope1 := (tri.b.x - tri.a.x) / (tri.b.y - tri.a.y)
    inverted_slope2 := (tri.c.x - tri.a.x) / (tri.c.y - tri.a.y)

    // Loop all the scanlines from top to bottom.
    x_start := tri.a.x
    x_end := tri.a.x
    for y := tri.a.y; y <= tri.c.y; y += 1 {
        draw_line(color_buffer, window_width, window_height, int(x_start), int(y), int(x_end), int(y), tri.color)
        x_start += inverted_slope1
        x_end += inverted_slope2
    }
}

fill_flat_top_triangle :: proc(color_buffer: []u32, window_width, window_height: int, tri: Projected_Triangle) {
    // Find the two (inverted) slopes (the two legs of the triangle)
    inverted_slope1 := (tri.c.x - tri.a.x) / (tri.c.y - tri.a.y)
    inverted_slope2 := (tri.c.x - tri.b.x) / (tri.c.y - tri.b.y)

    // Loop all the scanlines from top to bottom.
    x_start := tri.c.x
    x_end := tri.c.x
    for y := tri.c.y; y >= tri.a.y; y -= 1 {
        draw_line(color_buffer, window_width, window_height, int(x_start), int(y), int(x_end), int(y), tri.color)
        x_start -= inverted_slope1
        x_end -= inverted_slope2
    }
}

// Takes a 3D vector and returns a projected 2D point.
project :: proc(vector: linalg.Vector3f32, fov_factor: f32, projection_style: Projection_Style) -> linalg.Vector2f32 {
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
transform_and_project_mesh :: proc(color_buffer: []u32, window_width, window_height: int, mesh: Mesh, camera_position: linalg.Vector3f32, fov_factor: f32, backface_culling_mode: Backface_Culling_Mode) {
    // Create a world matrix for the projected mesh. We calculate one matrix to transform all of the mesh's vertices!
    world_matrix := linalg.identity_matrix(matrix[4, 4]f32)
    // Matrix multiplication is not commutative (a * b != b * a) so the order matters.
    // Scale first
    world_matrix *= linalg.matrix4_scale_f32(mesh.scale)
    // Rotate second
    world_matrix *= linalg.matrix4_rotate_f32(mesh.rotation.x, linalg.Vector3f32 {-1.0, 0.0, 0.0})
    world_matrix *= linalg.matrix4_rotate_f32(mesh.rotation.y, linalg.Vector3f32 {0.0, 1.0, 0.0})
    world_matrix *= linalg.matrix4_rotate_f32(mesh.rotation.z, linalg.Vector3f32 {0.0, 0.0, -1.0})
    // Translate last
    world_matrix *= linalg.transpose(linalg.matrix4_translate_f32(mesh.translation))

    // Transform and project all tris in mesh.
    for i := 0; i < len(mesh.faces); i += 1 {
        face := mesh.faces[i]
        tri: Triangle

        tri[0] = mesh.vertices[face.a]
        tri[1] = mesh.vertices[face.b]
        tri[2] = mesh.vertices[face.c]

        // Transform all vertices in tri.
        transformed_tri: Triangle
        for j := 0; j < 3; j += 1 {
            // Calculate the transformed vertex by simply multiplying the vertex (plus a w of 1) by the world matrix.
            transformed_vertex := linalg.Vector4f32 {tri[j].x, tri[j].y, tri[j].z, 1} * world_matrix

            // Save transformed vertices.
            transformed_tri[j] = linalg.Vector3f32 {transformed_vertex.x, transformed_vertex.y, transformed_vertex.z}
        }

        if backface_culling_mode == .Backface_Culling_Enabled {
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
        }

        // Calculate average depth for each face after transformation
        average_depth: f32 = (transformed_tri[0].z + transformed_tri[1].z + transformed_tri[2].z) / 3.0

        // Project all vertices in tri.
        projected_tri: Projected_Triangle
        projected_tri.color = mesh.faces[i].color
        projected_tri.average_depth = average_depth
        for j := 0; j < 3; j += 1 {
            // Project all vertices in tri.
            projected_vertex: linalg.Vector2f32
            projected_vertex = project(transformed_tri[j], fov_factor, .Perspective)

            // Scale and translate the projected tris to middle of the screen
            projected_vertex.x += f32(window_width) / 2
            projected_vertex.y += f32(window_height) / 2

            switch j {
                case 0:
                    projected_tri.a = projected_vertex
                case 1:
                    projected_tri.b = projected_vertex
                case 2:
                    projected_tri.c = projected_vertex
            }
        }

        // Save the projected tri to the global array of tris to render.
        append(&triangles_to_render, projected_tri)
    }

    // Sort triangles_to_render by average depth (ascending)
    slice.sort_by(triangles_to_render[:], proc(a, b: Projected_Triangle) -> bool {return a.average_depth < b.average_depth})
}

render_triangle_vertices :: proc(color_buffer: []u32, window_width, window_height, rect_width, rect_height: int, color: u32) {
    for tri in triangles_to_render {
        draw_rectangle(color_buffer, window_width, window_height, int(tri.a.x), int(tri.a.y), rect_width, rect_height, color)
        draw_rectangle(color_buffer, window_width, window_height, int(tri.b.x), int(tri.b.y), rect_width, rect_height, color)
        draw_rectangle(color_buffer, window_width, window_height, int(tri.c.x), int(tri.c.y), rect_width, rect_height, color)
    }
}

render_unfilled_triangles :: proc(color_buffer: []u32, window_width, window_height: int) {
    for tri in triangles_to_render {
        draw_unfilled_triangle(color_buffer,
            window_width,
            window_height,
            tri
        )
    }
}

render_filled_triangles :: proc(color_buffer: []u32, window_width, window_height: int) {
    for tri in triangles_to_render {
        draw_filled_triangle(color_buffer,
            window_width,
            window_height,
            tri
        )
    }
}
