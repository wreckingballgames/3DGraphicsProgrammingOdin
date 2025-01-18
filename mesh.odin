package main

import "core:os"
import "core:strings"
import "core:strconv"

// TODO: Use arena allocator to simplify mesh deallocation
Mesh :: struct {
    vertices: []Vector3,
    faces: []Face,
    rotation: Vector3,
}

NUM_VERTICES_IN_CUBE :: 8
NUM_FACES_IN_CUBE :: 6 * 2 // 6 cube faces with 2 tris each

load_obj_file_data :: proc(path: string, allocator := context.allocator) -> (^Mesh, os.Error) {
    // TODO: Read .OBJ file and load information into Mesh object on heap

    data, err := os.read_entire_file_from_filename_or_err(path, context.temp_allocator)
    if err != nil {
        return nil, err
    }

    vertices: [dynamic]Vector3

    // Big ups to GingerBill for this article helping me figure out how to do this simply https://odin-lang.org/news/read-a-file-line-by-line/
    it := string(data)

    for line in strings.split_lines_iterator(&it) {
        if strings.has_prefix(line, "v ") {
            split_string := strings.split(line, " ", context.temp_allocator)
            new_vertex: Vector3
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
            new_face[0], _ = strconv.parse_int(strings.split(split_string[1], "/", context.temp_allocator)[0])
            new_face[0] -= 1
            new_face[1], _ = strconv.parse_int(strings.split(split_string[2], "/", context.temp_allocator)[0])
            new_face[1] -= 1
            new_face[2], _ = strconv.parse_int(strings.split(split_string[3], "/", context.temp_allocator)[0])
            new_face[2] -= 1
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
