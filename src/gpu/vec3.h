#ifndef VECTOR_CUH
#define VECTOR_CUH
#include <cuda_runtime.h>

#include <cmath>
#include <iostream>

using namespace std;

class vec3 {
   public:
    float e[3];

    __host__ __device__ vec3() : e{0, 0, 0} {}
    __host__ __device__ vec3(float e0, float e1, float e2) : e{e0, e1, e2} {}

    __host__ __device__ float x() const { return e[0]; }
    __host__ __device__ float y() const { return e[1]; }
    __host__ __device__ float z() const { return e[2]; }

    __host__ __device__ float r() const { return e[0]; }
    __host__ __device__ float g() const { return e[1]; }
    __host__ __device__ float b() const { return e[2]; }

    __host__ __device__ vec3 operator-() const { return vec3(-e[0], -e[1], -e[2]); }

    __host__ __device__ float operator[](int i) const { return e[i]; }

    __host__ __device__ float& operator[](int i) { return e[i]; }

    __host__ __device__ vec3 operator+=(const vec3& v) {
        e[0] += v[0];
        e[1] += v[1];
        e[2] += v[2];

        return *this;
    }

    __host__ __device__ vec3& operator*=(float scalar) {
        e[0] *= scalar;
        e[1] *= scalar;
        e[2] *= scalar;
        return *this;
    }

    __host__ __device__ vec3& operator/=(double scalar) { return *this *= 1 / scalar; }

    __host__ __device__ float length() const { return std::sqrt(length_squared()); }

    __host__ __device__ float length_squared() const {
        return e[0] * e[0] + e[1] * e[1] + e[2] * e[2];
    }
};

using point3 = vec3;
using colour = vec3;

// Vector utilty functions

inline std::ostream& operator<<(std::ostream& out, const vec3& v) {
    return out << v.e[0] << ' ' << v.e[1] << ' ' << v.e[2];
}

__host__ __device__ inline vec3 operator+(const vec3& u, const vec3& v) {
    return vec3(u.e[0] + v.e[0], u.e[1] + v.e[1], u.e[2] + v.e[2]);
}

__host__ __device__ inline vec3 operator-(const vec3& u, const vec3& v) {
    return vec3(u.e[0] - v.e[0], u.e[1] - v.e[1], u.e[2] - v.e[2]);
}

__host__ __device__ inline vec3 operator*(const vec3& u, const vec3& v) {
    return vec3(u.e[0] * v.e[0], u.e[1] * v.e[1], u.e[2] * v.e[2]);
}

__host__ __device__ inline vec3 operator*(float scalar, const vec3& v) {
    return vec3(scalar * v.e[0], scalar * v.e[1], scalar * v.e[2]);
}

__host__ __device__ inline vec3 operator*(const vec3& v, float scalar) { return scalar * v; }

__host__ __device__ inline vec3 operator/(const vec3& v, float scalar) { return 1 / scalar * v; }

__host__ __device__ inline float dot(const vec3& u, const vec3& v);

__host__ __device__ inline vec3 cross(const vec3& u, const vec3& v);

__host__ __device__ inline vec3 unit_vector(const vec3& v) { return v / v.length(); }

#endif  // VECTOR_CUH