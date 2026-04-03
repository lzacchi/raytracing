#ifndef CAMERA_H
#define CAMERA_H

#include <cuda_runtime.h>
#include <curand_kernel.h>

#include "hittable.h"
#include "vec3.h"

#define RANDVEC3                                                             \
    vec3(curand_uniform(local_rand_state), curand_uniform(local_rand_state), \
         curand_uniform(local_rand_state))

class camera {
   public:
    float aspect_ratio = 1.0f;  //
    int image_width = 100;
    int pixel_samples = 10;
    int ray_bounces = 50;
    float vfov = 90.0f;
    point3 lookfrom = point3(-2, 2, 1);
    point3 lookat = point3(0, 0, -1);
    vec3 vup = vec3(0, 1, 0);

    float defocus_angle = 0.6f;
    float focus_dist = 10.0f;

    camera(float asp_ratio, int width, int tx = 8, int ty = 8, int n_sample = 10, int n_bounce = 50,
           float fov = 90.0f, point3 lookfrom = point3(0, 0, 0), point3 lookat = point3(0, 0, -1),
           vec3 vup = vec3(0, 1, 0))
        : aspect_ratio(asp_ratio),
          image_width(width),
          thread_x(tx),
          thread_y(ty),
          pixel_samples(n_sample),
          ray_bounces(n_bounce),
          vfov(fov),
          lookfrom(lookfrom),
          lookat(lookat),
          vup(vup) {
        initialize();
    }

    void render(vec3* frame_buffer, hittable** d_list,
                hittable** d_world);  // Wrapper to render kernel

    dim3 get_grid_dimension() const;
    dim3 get_block_dimension() const;

    int get_image_height() { return image_heigth; };

    void create_world(hittable** list, hittable** world);

   private:
    int image_heigth;

    vec3 defocus_disk_u;
    vec3 defocus_disk_v;
    vec3 u, v, w;

    vec3 viewport_upper_left;
    vec3 viewport_u;
    vec3 viewport_v;

    point3 centre;
    point3 pixel_00_loc;

    vec3 pixel_delta_u;
    vec3 pixel_delta_v;

    curandState* d_rand_state;
    curandState* d_rand_state_world;

    float pixel_samples_scale;

    int thread_x;
    int thread_y;

    void initialize();
    colour ray_colour();
};

#endif  // CAMERA_H