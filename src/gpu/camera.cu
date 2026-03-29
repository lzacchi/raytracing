#include <cuda_runtime.h>

#include <ctime>
#include <iostream>

#include "camera.h"
#include "constants.h"
#include "hittable.h"
#include "hittable_list.h"
#include "material.h"
#include "rtweekend.h"
#include "sphere.h"
#include "vec3.h"

class material;

__global__ void create_world_kernel(hittable** sphere_list, hittable** world) {
    if (threadIdx.x == 0 && blockIdx.x == 0) {
        // list of materials
        auto material_ground = new lambertian(colour(0.8, 0.8, 0.8));
        auto material_centre = new lambertian(colour(0.1, 0.2, 0.5));
        auto material_left = new dielectric(1.50);
        auto material_bubble = new dielectric(1.0f / 1.50f);
        auto material_right = new metal(colour(0.8, 0.6, 0.2), 1.0);

        sphere_list[0] = new sphere(vec3(0, 0, -1), 0.5, material_ground);
        sphere_list[1] = new sphere(vec3(0, -100.5, -1), 100, material_centre);
        sphere_list[2] = new sphere(vec3(-1, 0, -1), 0.5, material_left);
        sphere_list[3] = new sphere(vec3(-1, 0, -1), 0.4, material_bubble);
        sphere_list[4] = new sphere(vec3(1, 0, -1), 0.5, material_right);

        *world = new hittable_list(sphere_list, 5);
    }
}

__global__ void free_world(hittable** list, hittable** world) {
    for (auto i = 0; i < 5; ++i) {
        delete ((sphere*)list[i])->material_ptr;
        delete list[i];
    }
    delete *world;
}

__device__ colour ray_colour(const ray& r, hittable** world, int n_bounces,
                             curandState* local_rand_state) {
    interval ray_t(0.001f, infinity);
    ray current_ray = r;
    colour current_attenuation = colour(1, 1, 1);

    for (auto i = 0; i < n_bounces; ++i) {
        hit_record record;
        if ((*world)->hit(current_ray, ray_t, record)) {
            ray scattered;
            colour attenuation;
            if (record.material_ptr->scatter(r, record, attenuation, scattered, local_rand_state)) {
                current_attenuation = attenuation * current_attenuation;
                current_ray = scattered;
            } else {
                return colour(0, 0, 0);
            }
        } else {
            // Background gradient
            vec3 unit_direction = unit_vector(current_ray.direction());
            float t = 0.5f * (unit_direction.y() + 1.0f);
            colour background = (1.0f - t) * vec3(1.0, 1.0, 1.0) + t * vec3(0.5, 0.7, 1.0);
            return current_attenuation * background;
        }
    }
    return vec3(0, 0, 0);
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

__global__ void render_kernel(vec3* frame_buffer, int max_x, int max_y, int n_samples,
                              int n_bounces, point3 pixel_00_loc, vec3 pixel_delta_u,
                              vec3 pixel_delta_v, point3 camera_centre, hittable** world,
                              curandState* rand_state) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    int j = threadIdx.y + blockIdx.y * blockDim.y;

    if ((i >= max_x) || (j >= max_y)) {
        return;  // Avoid computing outside frame_buffer;
    }

    int pixel_index = j * max_x + i;
    curandState local_rand_state = rand_state[pixel_index];
    colour pixel_colour(0, 0, 0);

    for (auto sample = 0; sample < n_samples; ++sample) {
        float u = float(i + curand_uniform(&local_rand_state)) / float(max_x);
        float v = float(j + curand_uniform(&local_rand_state)) / float(max_y);

        point3 pixel_centre =
            pixel_00_loc + (u * max_x * pixel_delta_u) + (v * max_y * pixel_delta_v);
        vec3 ray_direction = pixel_centre - camera_centre;
        ray r(camera_centre, ray_direction);

        pixel_colour += ray_colour(r, world, n_bounces, &local_rand_state);
    }

    // Average the samples

    // calculate pixel location directly
    pixel_colour /= n_samples;

    frame_buffer[pixel_index] = pixel_colour;
    rand_state[pixel_index] = local_rand_state;
}

void camera::initialize() {
    image_heigth = int(image_width / aspect_ratio);
    image_heigth = (image_heigth < 1) ? 1 : image_heigth;

    centre = point3(0, 0, 0);
    float focal_length = 1.0f;
    float theta = degrees_to_radians(vfov);
    auto h = std::tan(theta / 2.0f);
    float viewport_height = 2 * h * focal_length;
    float viewport_width = viewport_height * (float(image_width) / image_heigth);

    viewport_u = vec3(viewport_width, 0, 0);    // horizontal viewport vector
    viewport_v = vec3(0, -viewport_height, 0);  // vertical viewport vector

    pixel_delta_u = viewport_u / image_width;
    pixel_delta_v = viewport_v / image_heigth;

    viewport_upper_left = centre - vec3(0, 0, focal_length) - viewport_u / 2 - viewport_v / 2;
    pixel_00_loc = viewport_upper_left + 0.5f * (pixel_delta_u + pixel_delta_v);

    pixel_samples_scale = 1.0f / pixel_samples;
}

dim3 camera::get_grid_dimension() const {
    return dim3((image_width + thread_x - 1) / thread_x, (image_heigth + thread_y - 1) / thread_y);
}

dim3 camera::get_block_dimension() const { return dim3(thread_x, thread_y); }

void camera::create_world(hittable** list, hittable** world) {
    create_world_kernel<<<1, 1>>>(list, world);
}

void camera::render(vec3* frame_buffer, hittable** d_list, hittable** d_world) {
    dim3 blocks = get_grid_dimension();
    dim3 threads = get_block_dimension();

    std::cerr << "Rendering a " << image_width << "x" << image_heigth << " image ";
    std::cerr << "in " << thread_x << "x" << thread_y << " blocks.\n";

    int num_pixels = image_heigth * image_width;

    checkCudaErrors(cudaMalloc((void**)&d_rand_state, num_pixels * sizeof(curandState)));
    init_render_kernel<<<blocks, threads>>>(image_width, image_heigth, d_rand_state);

    clock_t start, stop;

    start = clock();

    render_kernel<<<blocks, threads>>>(frame_buffer, image_width, image_heigth, pixel_samples,
                                       ray_bounces, pixel_00_loc, pixel_delta_u, pixel_delta_v,
                                       centre, d_world, d_rand_state);

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
    checkCudaErrors(cudaFree(d_rand_state));
}