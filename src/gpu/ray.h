#ifndef RAY_H
#define RAY_H

#include <cuda_runtime.h>

#include <iostream>

#include "vec3.h"

class ray {
   public:
    __device__ ray() {}
    __device__ ray(const point3& origin, const vec3& direction)
        : _origin(origin), _direction(direction) {}

    __device__ const point3& origin() const { return _origin; }
    __device__ const vec3& direction() const { return _direction; }

    __device__ point3 at(float t) const { return _origin + t * _direction; }

   private:
    point3 _origin;
    point3 _direction;
};

#endif  // RAY_H