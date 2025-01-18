package main

Mesh :: struct {
    vertices: []Vector3,
    tris: []Triangle,
    rotation: Vector3,
}

NUM_VERTICES_IN_CUBE :: 8
NUM_TRIS_IN_CUBE :: 6 * 2 // 6 cube faces with 2 tris each
