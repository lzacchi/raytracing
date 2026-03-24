#ifndef CONSTANTS_H
#define CONSTANTS_H

#include <cmath>
#include <iostream>
#include <limits>
#include <memory>
#include <random>
// Constants

const double infinity = std::numeric_limits<double>::infinity();
const double near_zero = 1e-160;
const double pi = 3.1415926535897932385;

// Utility Functions

inline double degrees_to_radians(double degrees) { return degrees * pi / 180.0; }

inline double random_double() {
    // returns a random real in [0, 1)
    static std::uniform_real_distribution<double> distribution(0.0, 1.0);
    static std::mt19937 generator;
    return distribution(generator);
}

inline double random_double(double min, double max) {
    // returns a random real in [0, 1)

    return min + (max - min) * random_double();
}

#endif  // CONSTANTS_H
