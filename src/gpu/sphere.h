#ifndef SPHERE_H
#define SPHERE_H

#include "hittable.h"
#include "vec3.h"

class sphere : public hittable {
   public:
    __device__ sphere(const point3& centre, float radius) : centre(centre), radius(radius) {}

    __device__ bool hit(const ray& r, interval ray_t, hit_record& record) const override {
        vec3 oc = centre - r.origin();
        // Define the terms of the quadratic equation for the sphere
        float a = r.direction().length_squared();
        float h = dot(r.direction(), oc);
        float c = oc.length_squared() - radius * radius;

        auto discriminant = h * h - a * c;

        if (discriminant < 0) {
            return false;
        }

        auto sqrtd = std::sqrt(discriminant);

        // Find the nearest root that lies in the acceptable range
        auto root = (h - sqrtd) / a;
        if (!ray_t.surrounds(root)) {
            root = (h + sqrtd) / a;
            if (!ray_t.surrounds(root)) {
                return false;
            }
        }

        record.t = root;
        record.p = r.at(record.t);

        vec3 outward_normal = (record.p - centre) / radius;
        record.set_face_normal(r, outward_normal);

        return true;
    }

   private:
    point3 centre;
    float radius;
};

#endif  // SPHERE_H