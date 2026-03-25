#ifndef COLOUR_H
#define COLOUR_H

#include <iostream>

#include "vec3.h"

using colour = vec3;

inline void write_colour(std::ostream& out, const colour& pixel_colour) {
    // This is actually the render
    auto r = pixel_colour.x();
    auto g = pixel_colour.y();
    auto b = pixel_colour.z();

    // translate the [0,1] component values to the byte range [0,255]
    int rbyte = int(255.99 * r);
    int gbyte = int(255.99 * g);
    int bbyte = int(255.99 * b);

    // Write out the pixel colour components
    out << rbyte << ' ' << gbyte << ' ' << bbyte << '\n';
}
#endif  // COLOUR_H