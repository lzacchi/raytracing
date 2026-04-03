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

    int thread_x = 16;
    int thread_y = 16;
    int pixel_samples = 200;
    int max_bounce = 50;
    float cam_fov = 20.0f;
    point3 cam_lookfrom = point3(12, 2, 3);
    point3 cam_lookat = point3(0, 0, 0);
    vec3 cam_vup = vec3(0, 1, 0);

    camera cam(aspect_ratio, image_width, thread_x, thread_y, pixel_samples, max_bounce, cam_fov,
               cam_lookfrom, cam_lookat, cam_vup);

    int image_heigth = cam.get_image_height();

    // make our world of hittables
    hittable** d_list;
    hittable** d_world;

    checkCudaErrors(cudaMalloc((void**)&d_list, (22 * 22 + 1 + 3) * sizeof(hittable*)));
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
