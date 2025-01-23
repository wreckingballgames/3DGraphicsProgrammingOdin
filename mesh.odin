package main

import "core:os"
import "core:strings"
import "core:strconv"
import "core:math/linalg"
import "core:fmt"

// TODO: Use arena allocator to simplify mesh deallocation
Mesh :: struct {
    vertices: []linalg.Vector3f32,
    faces: []Face,
    rotation: linalg.Vector3f32,
    scale: linalg.Vector3f32,
    translation: linalg.Vector3f32,
}

load_obj_file_data :: proc(path: string, allocator := context.allocator) -> (^Mesh, os.Error) {
    data, err := os.read_entire_file_from_filename_or_err(path, context.temp_allocator)
    if err != nil {
        return nil, err
    }

    vertices: [dynamic]linalg.Vector3f32

    // Big ups to GingerBill for this article helping me figure out how to do this simply https://odin-lang.org/news/read-a-file-line-by-line/
    it := string(data)

    for line in strings.split_lines_iterator(&it) {
        if strings.has_prefix(line, "v ") {
            split_string := strings.split(line, " ", context.temp_allocator)
            new_vertex: linalg.Vector3f32
            new_vertex.x, _ = strconv.parse_f32(split_string[1])
            new_vertex.y, _ = strconv.parse_f32(split_string[2])
            new_vertex.z, _ = strconv.parse_f32(split_string[3])
            append(&vertices, new_vertex)
        }
    }

    faces: [dynamic]Face

    it = string(data)
    for line in strings.split_lines_iterator(&it) {
        if strings.has_prefix(line, "f ") {
            split_string := strings.split(line, " ", context.temp_allocator)
            new_face: Face
            new_face.a, _ = strconv.parse_int(strings.split(split_string[1], "/", context.temp_allocator)[0])
            new_face.b, _ = strconv.parse_int(strings.split(split_string[2], "/", context.temp_allocator)[0])
            new_face.c, _ = strconv.parse_int(strings.split(split_string[3], "/", context.temp_allocator)[0])
            // Subtract 1 from each index to account for OBJ's 1-based counting before appending
            new_face.a -= 1
            new_face.b -= 1
            new_face.c -= 1
            append(&faces, new_face)
        }
    }

    new_mesh := new(Mesh, allocator)
    new_mesh.vertices = vertices[:]
    new_mesh.faces = faces[:]
    return new_mesh, nil
}

delete_mesh :: proc(mesh: ^Mesh) {
    delete(mesh.vertices)
    delete(mesh.faces)
    free(mesh)
}
