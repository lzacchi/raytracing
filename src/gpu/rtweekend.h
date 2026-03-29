#ifndef RT_WEEKEND_H
#define RT_WEEKEND_H

#include <cuda_runtime.h>

#include "colour.h"
#include "interval.h"
#include "ray.h"
#include "vec3.h"

#define checkCudaErrors(val) check_cuda((val), #val, __FILE__, __LINE__)
inline void check_cuda(cudaError_t result, char const* const func, const char* const file,
                       int const line) {
    if (result) {
        std::cerr << "CUDA error = " << static_cast<unsigned int>(result) << " at " << file << ":"
                  << line << " '" << func << "' \n";
        // Make sure we call CUDA Device Reset before exiting
        cudaDeviceReset();
        exit(99);
    }
}

#endif  // RT_WEEKEND_H