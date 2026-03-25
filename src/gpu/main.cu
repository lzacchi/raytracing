#include <time.h>

#include <ctime>
#include <iostream>

#include "colour.h"
#include "ray.h"
#include "vec3.h"

using namespace std;

#define checkCudaErrors(val) check_cuda((val), #val, __FILE__, __LINE__)
void check_cuda(cudaError_t result, char const* const func, const char* const file,
                int const line) {
    if (result) {
        std::cerr << "CUDA error = " << static_cast<unsigned int>(result) << " at " << file << ":"
                  << line << " '" << func << "' \n";
        // Make sure we call CUDA Device Reset before exiting
        cudaDeviceReset();
        exit(99);
    }
}

__device__ colour ray_colour(const ray& r) {
    vec3 unit_direction = unit_vector(r.direction());  // Normalize the direction to unit length
    auto colour_blend = 0.5f * (unit_direction.y() + 1.0f);
    return (1.0 - colour_blend) * colour(1.0, 1.0, 1.0) +
           colour_blend * colour(0.5, 0.7, 1.0);  // Linear interpolation
}

__device__ bool hit_sphere(const point3& centre, float radius, const ray& r) {
    vec3 oc = centre - r.origin();
    return true;
}

__global__ void render(vec3* frame_buffer, int max_x, int max_y, vec3 viewport_upper_left,
                       vec3 viewport_u, vec3 viewport_v, point3 origin) {
    int i = threadIdx.x + blockIdx.x * blockDim.x;
    int j = threadIdx.y + blockIdx.y * blockDim.y;
    if ((i >= max_x) || (j >= max_y)) return;
    int pixel_index = j * max_x + i;

    float u = float(i) / float(max_x);
    float v = float(j) / float(max_y);
    ray r(origin, viewport_upper_left + u * viewport_u + v * viewport_v);
    frame_buffer[pixel_index] = ray_colour(r);
}

int main() {
    float aspect_ratio = 16.0f / 9.0f;
    int image_width = 1200;

    int image_heigth = int(image_width / aspect_ratio);
    image_heigth = (image_heigth < 1) ? 1 : image_heigth;

    // Camera set-up
    float focal_length = 1.0f;
    float viewport_height = 2.0f;
    float viewport_width = viewport_height * (float(image_width) / image_heigth);
    auto camera_centre = vec3(0, 0, 0);

    // Calculate vectors across the horizontal and vertical viewport edges:
    auto viewport_u = vec3(viewport_width, 0, 0);
    auto viewport_v = vec3(0, -viewport_height, 0);

    // Calculate horizontal and vertical delta vectors
    auto pixel_delta_u = viewport_u / image_width;
    auto pixel_delta_v = viewport_v / image_heigth;

    // Calculate location of upper left pixel
    auto viewport_upper_left =
        camera_centre - vec3(0, 0, focal_length) - viewport_u / 2 - viewport_v / 2;
    auto pixel_upper_left = viewport_upper_left + 0.5f * (pixel_delta_u + pixel_delta_v);

    // Prepare data to send to GPU
    int num_pixels = image_width * image_heigth;
    size_t frame_buffer_size = 3 * num_pixels * sizeof(float);

    // allocate frame_buffer
    vec3* frame_buffer;
    checkCudaErrors(cudaMallocManaged((void**)&frame_buffer, frame_buffer_size));

    int thread_x = 8;
    int thread_y = 8;

    std::cerr << "Rendering a " << image_width << "x" << image_heigth << " image ";
    std::cerr << "in " << thread_x << "x" << thread_y << " blocks.\n";

    clock_t start, stop;
    start = clock();

    // Render our buffer
    dim3 blocks(image_width / thread_x + 1, image_heigth / thread_y + 1);
    dim3 threads(thread_x, thread_y);
    render<<<blocks, threads>>>(frame_buffer, image_width, image_heigth, viewport_upper_left,
                                viewport_u, viewport_v, camera_centre);
    checkCudaErrors(cudaGetLastError());
    checkCudaErrors(cudaDeviceSynchronize());

    stop = clock();
    double timer_seconds = ((double)stop - start) / CLOCKS_PER_SEC;
    std::cerr << "took " << timer_seconds << " seconds.\n";

    // Output frame_buffer as Image
    std::cout << "P3\n" << image_width << " " << image_heigth << "\n255\n";
    for (int j = 0; j < image_heigth; ++j) {
        for (int i = 0; i < image_width; ++i) {
            size_t pixel_index = j * image_width + i;

            float r = frame_buffer[pixel_index].x();
            float g = frame_buffer[pixel_index].y();
            float b = frame_buffer[pixel_index].z();

            write_colour(std::cout, frame_buffer[pixel_index]);
        }
    }
    checkCudaErrors(cudaFree(frame_buffer));
}
