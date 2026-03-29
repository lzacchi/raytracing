#ifndef INTERVAL_H
#define INTERVAL_H

#include <cuda_runtime.h>

#include "constants.h"
class interval {
   public:
    float min, max;
    __host__ __device__ interval() : min(+infinity), max(-infinity) {}  // default interval is empty
    __host__ __device__ interval(float min, float max) : min(min), max(max) {}

    __device__ float size() const { return max - min; }
    __device__ bool contains(float x) { return ((min <= x) && (x <= max)); }
    __device__ bool surrounds(float x) { return min < x && x < max; }

    __host__ __device__ float clip(float x) const {
        if (x < min) return min;
        if (x > max) return max;
        return x;
    }
};

#endif  // INTERVAL_H