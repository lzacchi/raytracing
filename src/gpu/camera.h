#ifndef CAMERA_H
#define CAMERA_H

#include <cuda_runtime.h>
#include <curand_kernel.h>

#include "hittable.h"
#include "vec3.h"

class camera {
   public:
    float aspect_ratio = 1.0f;
    int image_width = 100;

    camera(float asp_ratio, int width, int tx = 8, int ty = 8)
        : aspect_ratio(asp_ratio), image_width(width), thread_x(tx), thread_y(ty) {
        initialize();
    }

    void render(vec3* frame_buffer, hittable** d_list, hittable** d_world,
                curandState* d_rand_state);  // Wrapper to render kernel

    dim3 get_grid_dimension() const;
    dim3 get_block_dimension() const;

    int get_image_height() { return image_heigth; };

    void create_world(hittable** list, hittable** world);

    void init_render();

   private:
    int image_heigth;
    point3 centre;
    point3 pixel_00_loc;
    vec3 pixel_delta_u;
    vec3 pixel_delta_v;

    int thread_x;
    int thread_y;

    void initialize();
    colour ray_colour();
};

#endif  // CAMERA_H