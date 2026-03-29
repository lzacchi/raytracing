#include <__clang_cuda_builtin_vars.h>
#include <cuda_runtime.h>

#include <cmath>
#include <ctime>
#include <iostream>

#include "camera.h"
#include "constants.h"
#include "hittable.h"
#include "hittable_list.h"
#include "rtweekend.h"
#include "sphere.h"
#include "vec3.h"

__global__ void create_world_kernel(hittable** list, hittable** world) {
    if (threadIdx.x == 0 && blockIdx.x == 0) {
        *(list) = new sphere(vec3(0, 0, -1), 0.5);
        *(list + 1) = new sphere(vec3(0, -100.5, -1), 100);

        *world = new hittable_list(list, 2);
    }
}

__global__ void free_world(hittable** list, hittable** world) {
    delete *(list);
    delete *(list + 1);
    delete *(world);
}

__device__ colour ray_colour(const ray& r, hittable** world) {
    hit_record record;
    interval ray_t(0.0f, infinity);

    if ((*world)->hit(r, ray_t, record)) {
        // Return normal-based colour
        return 0.5f *
               colour(record.normal.x() + 1.0f, record.normal.y() + 1.0f, record.normal.z() + 1.0f);
    } else {
        // Background graduent
        vec3 unit_direction = unit_vector(r.direction());
        float t = 0.5f * (unit_direction.y() + 1.0f);
        return (1.0f - t) * colour(1.0f, 1.0f, 1.0f) + t * colour(0.5f, 0.7f, 1.0f);
    }
}

__global__ void init_render_kernel(int max_x, int max_y, curandState* rand_state) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    int j = threadIdx.y + blockIdx.y * blockDim.y;

    if ((i >= max_x) || (j >= max_y)) {
        return;
    }
    int pixel_index = j * max_x + i;
    // Each thread gets same seed, a different sequence number, no offset
    curand_init(1984, pixel_index, 0, &rand_state[pixel_index]);
}

__global__ void random_init();

__global__ void render_kernel(vec3* frame_buffer, int max_x, int max_y, point3 pixel_00_loc,
                              vec3 pixel_delta_u, vec3 pixel_delta_v, point3 camera_centre,
                              hittable** world) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    int j = threadIdx.y + blockIdx.y * blockDim.y;

    if ((i >= max_x) || (j >= max_y)) {
        return;  // Avoid computing outside frame_buffer;
    }

    int pixel_index = j * max_x + i;

    // calculate pixel location directly
    point3 pixel_centre = pixel_00_loc + (i * pixel_delta_u) + (j * pixel_delta_v);
    vec3 ray_direction = pixel_centre - camera_centre;

    ray r(camera_centre, ray_direction);

    frame_buffer[pixel_index] = ray_colour(r, world);
}

void camera::initialize() {
    image_heigth = int(image_width / aspect_ratio);
    image_heigth = (image_heigth < 1) ? 1 : image_heigth;

    centre = point3(0, 0, 0);
    float focal_length = 1.0f;
    float viewport_height = 2.0f;
    float viewport_width = viewport_height * (float(image_width) / image_heigth);

    vec3 viewport_u = vec3(viewport_width, 0, 0);    // horizontal viewport vector
    vec3 viewport_v = vec3(0, -viewport_height, 0);  // vertical viewport vector

    pixel_delta_u = viewport_u / image_width;
    pixel_delta_v = viewport_v / image_heigth;

    vec3 viewport_upper_left = centre - vec3(0, 0, focal_length) - viewport_u / 2 - viewport_v / 2;
    pixel_00_loc = viewport_upper_left + 0.5f * (pixel_delta_u + pixel_delta_v);
}

dim3 camera::get_grid_dimension() const {
    return dim3((image_width + thread_x - 1) / thread_x, (image_heigth + thread_y - 1) / thread_y);
}

dim3 camera::get_block_dimension() const { return dim3(thread_x, thread_y); }

void camera::create_world(hittable** list, hittable** world) {
    create_world_kernel<<<1, 1>>>(list, world);
}

void camera::render(vec3* frame_buffer, hittable** d_list, hittable** d_world,
                    curandState* d_rand_state) {
    dim3 blocks = get_grid_dimension();
    dim3 threads = get_block_dimension();

    std::cerr << "Rendering a " << image_width << "x" << image_heigth << " image ";
    std::cerr << "in " << thread_x << "x" << thread_y << " blocks.\n";
    int num_pixels = image_heigth * image_width;
    checkCudaErrors(cudaMalloc((void**)&d_rand_state, num_pixels * sizeof(curandState)));
    init_render_kernel<<<blocks, threads>>>(image_width, image_heigth, d_rand_state);

    clock_t start, stop;

    start = clock();

    render_kernel<<<blocks, threads>>>(frame_buffer, image_width, image_heigth, pixel_00_loc,
                                       pixel_delta_u, pixel_delta_v, centre, d_world);

    checkCudaErrors(cudaGetLastError());
    checkCudaErrors(cudaDeviceSynchronize());
    stop = clock();

    double timer_seconds = ((double)stop - start) / CLOCKS_PER_SEC;
    std::cerr << "took " << timer_seconds << " seconds.\n";

    std::cout << "P3\n" << image_width << ' ' << image_heigth << "\n255\n";
    for (int j = 0; j < image_heigth; ++j) {
        for (int i = 0; i < image_width; ++i) {
            size_t pixel_index = j * image_width + i;

            float r = frame_buffer[pixel_index].x();
            float g = frame_buffer[pixel_index].y();
            float b = frame_buffer[pixel_index].z();

            write_colour(std::cout, frame_buffer[pixel_index]);
        }
    }

    // clean up
    checkCudaErrors(cudaDeviceSynchronize());
    free_world<<<1, 1>>>(d_list, d_world);
    checkCudaErrors(cudaGetLastError());
}
