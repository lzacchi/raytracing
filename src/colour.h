#ifndef COLOUR_H
#define COLOUR_H

#include <cmath>

#include "constants.h"
#include "interval.h"
#include "vec3.h"

using colour = vec3;

inline double linear_to_gamma(double linear_component) {
    if (linear_component > 0) return std::sqrt(linear_component);

    return 0;
}

inline void write_colour(std::ostream& out, const colour& pixel_colour) {
    auto r = pixel_colour.x();
    auto g = pixel_colour.y();
    auto b = pixel_colour.z();

    // Apply linear to gamma transform for gamma2
    r = linear_to_gamma(r);
    g = linear_to_gamma(g);
    b = linear_to_gamma(b);

    // Translate the [0,1] component values to the byte range [0, 255]
    static const interval intensity(0.000, 0.999);
    int rbyte = int(256 * intensity.clamp(r));
    int gbyte = int(256 * intensity.clamp(g));
    int bbyte = int(256 * intensity.clamp(b));

    // Write out the pixel colour components
    out << rbyte << ' ' << gbyte << ' ' << bbyte << '\n';
}

#endif  // COLOUR_H