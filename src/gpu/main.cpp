#include "camera.h"
#include "hittable.h"
#include "rtweekend.h"

using namespace std;

// External declarations from camera.cu
extern __global__ void create_world(hittable** d_list, hittable** d_world);
extern __global__ void free_world(hittable** d_list, hittable** d_world);

int main() {
    float aspect_ratio = 16.0f / 9;
    int image_width = 1920;

    int thread_x = 32;
    int thread_y = 32;

    camera cam(aspect_ratio, image_width, thread_x, thread_y);

    int image_heigth = cam.get_image_height();

    // make our world of hittables
    hittable** d_list;
    hittable** d_world;

    checkCudaErrors(cudaMalloc((void**)&d_list, 2 * sizeof(hittable*)));
    checkCudaErrors(cudaMalloc((void**)&d_world, sizeof(hittable*)));

    int num_pixels = image_width * image_heigth;
    size_t frame_buffer_size = num_pixels * sizeof(vec3);
    vec3* frame_buffer;

    checkCudaErrors(cudaMallocManaged((void**)&frame_buffer, frame_buffer_size));

    cam.create_world(d_list, d_world);

    checkCudaErrors(cudaGetLastError());
    checkCudaErrors(cudaDeviceSynchronize());

    cam.render(frame_buffer, d_list, d_world);
    // Clean up
    checkCudaErrors(cudaFree(frame_buffer));
    checkCudaErrors(cudaFree(d_list));
    checkCudaErrors(cudaFree(d_world));
}
