#ifndef HITTABLE_LIST_H
#define HITTABLE_LIST_H

#include "hittable.h"

class hittable_list : public hittable {
   public:
    __device__ hittable_list() {}
    __device__ hittable_list(hittable** list, int list_size) : list(list), list_size(list_size) {}

    __device__ bool hit(const ray& r, interval ray_t, hit_record& record) const override {
        hit_record temp_record;
        bool hit_anything = false;

        auto closest_so_far = ray_t.max;

        for (auto i = 0; i < list_size; ++i) {
            if (list[i]->hit(r, interval(ray_t.min, closest_so_far), temp_record)) {
                hit_anything = true;
                closest_so_far = temp_record.t;
                record = temp_record;
            }
        }
        return hit_anything;
    }

   private:
    hittable** list;
    int list_size;
};

#endif  // HITTABLE_LIST_H
