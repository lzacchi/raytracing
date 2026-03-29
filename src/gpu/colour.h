#ifndef COLOUR_H
#define COLOUR_H

#include <iostream>

#include "interval.h"
#include "vec3.h"

using colour = vec3;

inline float linear_to_gamma(float linear_component) {
    if (linear_component > 0) {
        return std::sqrt(linear_component);
    }
    return 0;
}

inline void write_colour(std::ostream& out, const colour& pixel_colour) {
    // This is actually the render
    auto r = pixel_colour.x();
    auto g = pixel_colour.y();
    auto b = pixel_colour.z();

    // Apply linear to gamma transform for gamma 2
    r = linear_to_gamma(r);
    g = linear_to_gamma(g);
    b = linear_to_gamma(b);

    // translate the [0,1] component values to the byte range [0,255]
    static const interval intensity(0.000f, 0.999f);
    int rbyte = int(255.99 * intensity.clip(r));
    int gbyte = int(255.99 * intensity.clip(g));
    int bbyte = int(255.99 * intensity.clip(b));

    // Write out the pixel colour components
    out << rbyte << ' ' << gbyte << ' ' << bbyte << '\n';
}
#endif  // COLOUR_H