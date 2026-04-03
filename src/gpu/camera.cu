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

#define RND (curand_uniform(&local_rand_state))
#define WRND (curand_uniform(&local_rand_state))

#define RANDVEC3                                                             \
    vec3(curand_uniform(local_rand_state), curand_uniform(local_rand_state), \
         curand_uniform(local_rand_state))

__device__ vec3 random_in_unit_disk(curandState* local_rand_state) {
    vec3 p;
    do {
        p = 2.0f * vec3(curand_uniform(local_rand_state), curand_uniform(local_rand_state), 0) -
            vec3(1, 1, 0);
    } while (dot(p, p) >= 1.0f);
    return p;
}

__global__ void init_world_rand_state(curandState* state) { curand_init(1234, 0, 0, state); }

__global__ void create_world_kernel(hittable** sphere_list, hittable** world,
                                    curandState* rand_state) {
    if (threadIdx.x == 0 && blockIdx.x == 0) {
        curandState local_rand_state = *rand_state;
        // list of materials

        auto material_ground = new lambertian(colour(0.3, 0.3, 0.3));
        sphere_list[0] = new sphere(vec3(0, -1000, -1), 1000, material_ground);

        int i = 1;
        for (int a = -11; a < 11; ++a) {
            for (int b = -11; b < 11; ++b) {
                float choose_mat = WRND;
                vec3 centre(a + 0.9f * WRND, 0.2, b + 0.9f * WRND);
                if (choose_mat < 0.8f) {
                    auto rnd_lambertian =
                        new lambertian(vec3(WRND * WRND, WRND * WRND, WRND * WRND));
                    sphere_list[i++] = new sphere(centre, 0.2, rnd_lambertian);
                } else if (choose_mat < 0.95f) {
                    auto rnd_metal = new metal(
                        vec3(0.5f * (1.0f + WRND), 0.5f * (1.0f + WRND), 0.5f * (1.0f + WRND)),
                        0.5f * WRND);
                    sphere_list[i++] = new sphere(centre, 0.2, rnd_metal);
                } else {
                    sphere_list[i++] = new sphere(centre, 0.2, new dielectric(1.5));
                }
            }
        }

        sphere_list[i++] = new sphere(vec3(0, 1, 0), 1.0, new dielectric(1.5));
        sphere_list[i++] = new sphere(vec3(-4, 1, 0), 1.0, new lambertian(vec3(0.4, 0.2, 0.1)));
        sphere_list[i++] = new sphere(vec3(4, 1, 0), 1.0, new metal(vec3(0.7, 0.6, 0.5), 0.0));
        *rand_state = local_rand_state;
        *world = new hittable_list(sphere_list, 22 * 22 + 1 + 3);
    }
}

__global__ void free_world(hittable** list, hittable** world) {
    for (auto i = 0; i < 22 * 22 + 1 + 3; ++i) {
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
            if (record.material_ptr->scatter(current_ray, record, attenuation, scattered,
                                             local_rand_state)) {
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

__device__ point3 defocus_disk_sample(point3 camera_centre, vec3 defocus_disk_u,
                                      vec3 defocus_disk_v, curandState* local_rand_state) {
    auto p = random_in_unit_disk(local_rand_state);
    return camera_centre + (p[0] * defocus_disk_u) + (p[1] * defocus_disk_v);
}

__global__ void render_kernel(vec3* frame_buffer, int max_x, int max_y, int n_samples,
                              int n_bounces, point3 pixel_00_loc, vec3 pixel_delta_u,
                              vec3 pixel_delta_v, point3 camera_centre, hittable** world,
                              curandState* rand_state, float defocus_angle, vec3 defocus_disk_u,
                              vec3 defocus_disk_v) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    int j = threadIdx.y + blockIdx.y * blockDim.y;

    if ((i >= max_x) || (j >= max_y)) return;

    int pixel_index = j * max_x + i;
    curandState local_rand_state = rand_state[pixel_index];
    colour pixel_colour(0, 0, 0);

    for (auto sample = 0; sample < n_samples; ++sample) {
        // Use i and j (the pixel coordinates) + a random offset [0,1)
        float px = float(i) + curand_uniform(&local_rand_state);
        float py = float(j) + curand_uniform(&local_rand_state);

        // Calculate the location on the viewport for THIS specific pixel
        point3 pixel_sample = pixel_00_loc + (px * pixel_delta_u) + (py * pixel_delta_v);

        auto ray_origin = (defocus_angle <= 0)
                              ? camera_centre
                              : defocus_disk_sample(camera_centre, defocus_disk_u, defocus_disk_v,
                                                    &local_rand_state);

        vec3 ray_direction = pixel_sample - ray_origin;
        ray r(ray_origin, ray_direction);

        pixel_colour += ray_colour(r, world, n_bounces, &local_rand_state);
    }

    frame_buffer[pixel_index] = pixel_colour / n_samples;
    rand_state[pixel_index] = local_rand_state;
}

void camera::initialize() {
    image_heigth = int(image_width / aspect_ratio);
    image_heigth = (image_heigth < 1) ? 1 : image_heigth;
    centre = lookfrom;

    // determine viewport dimensions.
    float focal_length = (lookfrom - lookat).length();
    float theta = degrees_to_radians(vfov);
    float h = tan(theta / 2.0f);

    // Determine the distance to the viewport plane
    float viewport_distance = (defocus_angle <= 0) ? focal_length : focus_dist;
    float viewport_height = 2 * h * viewport_distance;
    float viewport_width = viewport_height * (float(image_width) / image_heigth);

    // Calculate u,v,w basis vectors for camera coordinate
    w = unit_vector(lookfrom - lookat);
    u = unit_vector(cross(vup, w));
    v = cross(w, u);

    viewport_u = viewport_width * u;    // horizontal viewport vector
    viewport_v = viewport_height * -v;  // vertical viewport vector

    pixel_delta_u = viewport_u / image_width;
    pixel_delta_v = viewport_v / image_heigth;

    // CRITICAL FIX: Use the same viewport_distance here!
    auto viewport_upper_left = centre - (viewport_distance * w) - viewport_u / 2 - viewport_v / 2;
    pixel_00_loc = viewport_upper_left + 0.5f * (pixel_delta_u + pixel_delta_v);

    // calculate the camera focus disk basis vectors (only used when defocus_angle > 0)
    float defocus_radius = focus_dist * tan(degrees_to_radians(defocus_angle) / 2.0f);
    defocus_disk_u = u * defocus_radius;
    defocus_disk_v = v * defocus_radius;

    pixel_samples_scale = 1.0f / pixel_samples;
}

dim3 camera::get_grid_dimension() const {
    return dim3((image_width + thread_x - 1) / thread_x, (image_heigth + thread_y - 1) / thread_y);
}

dim3 camera::get_block_dimension() const { return dim3(thread_x, thread_y); }

void camera::create_world(hittable** list, hittable** world) {
    // allocate + init a single RNG state for world creation
    checkCudaErrors(cudaMalloc((void**)&d_rand_state_world, sizeof(curandState)));
    init_world_rand_state<<<1, 1>>>(d_rand_state_world);
    checkCudaErrors(cudaGetLastError());
    checkCudaErrors(cudaDeviceSynchronize());

    create_world_kernel<<<1, 1>>>(list, world, d_rand_state_world);
    checkCudaErrors(cudaGetLastError());
    checkCudaErrors(cudaDeviceSynchronize());
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
                                       centre, d_world, d_rand_state, defocus_angle, defocus_disk_u,
                                       defocus_disk_v);

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
    checkCudaErrors(cudaFree(d_rand_state_world));
}