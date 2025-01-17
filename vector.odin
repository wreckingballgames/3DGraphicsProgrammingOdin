package main

import "core:math"

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
