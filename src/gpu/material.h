#ifndef MATERIAL_H
#define MATERIAL_H

#include <curand_kernel.h>

#include "hittable.h"
#include "vec3.h"

#define RANDVEC3                                                             \
    vec3(curand_uniform(local_rand_state), curand_uniform(local_rand_state), \
         curand_uniform(local_rand_state))

__device__ inline vec3 random_in_unit_sphere(curandState* local_rand_state) {
    vec3 p;
    do {
        p = 2.0f * RANDVEC3 - vec3(1, 1, 1);
    } while (p.length_squared() >= 1.0f);
    return p;
}

__device__ inline float schlick(float cosine, float ref_idx) {
    float r0 = (1.0f - ref_idx) / (1.0f + ref_idx);
    r0 = r0 * r0;
    return r0 + (1.0f - r0) * pow((1.0f - cosine), 5.0f);
}

class material {
   public:
    ~material() = default;

    __device__ virtual bool scatter(const ray& r_in, const hit_record& record, colour& attenuation,
                                    ray& scattered, curandState* local_rand_state) const {
        return false;
    }
};

class lambertian : public material {
   public:
    __device__ lambertian(const colour& albedo) : albedo(albedo) {}

    __device__ bool scatter(const ray& r_in, const hit_record& record, colour& attenuation,
                            ray& scattered, curandState* local_rand_state) const override {
        auto scatter_direction = record.p + record.normal + random_in_unit_sphere(local_rand_state);
        scattered = ray(record.p, scatter_direction);
        attenuation = albedo;
        return true;
    }

   private:
    colour albedo;
};

class metal : public material {
   public:
    __device__ metal(const colour& albedo, float fuzz)
        : albedo(albedo), fuzz(fuzz < 1 ? fuzz : 1) {}

    __device__ bool scatter(const ray& r_in, const hit_record& record, colour& attenuation,
                            ray& scattered, curandState* local_rand_state) const override {
        vec3 reflected = reflect(r_in.direction(), record.normal);
        reflected = unit_vector(reflected) + fuzz * random_in_unit_sphere(local_rand_state);
        scattered = ray(record.p, reflected);
        attenuation = albedo;
        return dot(scattered.direction(), record.normal) > 0;
    }

   private:
    colour albedo;
    float fuzz;
};

class dielectric : public material {
   public:
    __device__ dielectric(float refraction_index) : refraction_index(refraction_index) {}

    __device__ bool scatter(const ray& r_in, const hit_record& record, colour& attenuation,
                            ray& scattered, curandState* local_rand_state) const override {
        vec3 outward_normal;
        vec3 reflected = reflect(r_in.direction(), record.normal);
        float ni_over_nt;
        attenuation = colour(1, 1, 1);
        vec3 refracted;
        float reflect_prob;
        float cosine;

        if (dot(r_in.direction(), record.normal) > 0.0f) {
            outward_normal = -record.normal;
            ni_over_nt = refraction_index;
            cosine = dot(r_in.direction(), record.normal) / r_in.direction().length();
            cosine = sqrt(1.0f - refraction_index * refraction_index * (1 - cosine * cosine));
        } else {
            outward_normal = record.normal;
            ni_over_nt = 1.0f / refraction_index;
            cosine = -dot(r_in.direction(), record.normal) / r_in.direction().length();
        }
        if (refract(r_in.direction(), outward_normal, ni_over_nt, refracted)) {
            reflect_prob = schlick(cosine, refraction_index);
        } else {
            reflect_prob = 1.0f;
        }
        if (curand_uniform(local_rand_state) < reflect_prob) {
            scattered = ray(record.p, reflected);
        } else {
            scattered = ray(record.p, refracted);
        }
        return true;
    }

   private:
    float refraction_index;
};

#endif  // MATERIAL_H