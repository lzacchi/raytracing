#ifndef HITTABLE_H
#define HITTABLE_H

#include "interval.h"
#include "ray.h"

class hit_record {
   public:
    point3 p;  // Interstection point
    vec3 normal;
    float t;  // Intersection distance

    bool front_face;

    __device__ void set_face_normal(const ray& r, const vec3& outward_normal) {
        // Sets the hit record normal vector
        // outward_normal is assumed to have unit length
        front_face = dot(r.direction(), outward_normal) < 0;
        normal = front_face ? outward_normal : -outward_normal;
    }
};

class hittable {
   public:
    __device__ virtual ~hittable() = default;

    __device__ virtual bool hit(const ray& r, interval ray_t, hit_record& record) const = 0;
};

#endif  // HITTABLE_H