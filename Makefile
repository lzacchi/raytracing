CUDA_PATH     ?= /opt/cuda
HOST_COMPILER  = g++
NVCC           = $(CUDA_PATH)/bin/nvcc -ccbin $(HOST_COMPILER)

SRC_CPU_PATH   = src/cpu/
SRC_GPU_PATH   = src/gpu/

BUILD_CPU_PATH = build/cpu/
BUILD_GPU_PATH = build/gpu/

IMG_CPU_PATH   = img/cpu/
IMG_GPU_PATH   = img/gpu/

NVCC_DBG       = -g -G
NVCC_DBG       =  # Uncomment for release
NVCCFLAGS      = $(NVCC_DBG) -m64
GENCODE_FLAGS  = -gencode arch=compute_86,code=sm_86

# Create directories
DIRS = $(BUILD_CPU_PATH) $(BUILD_GPU_PATH) $(IMG_CPU_PATH) $(IMG_GPU_PATH)
$(shell mkdir -p $(DIRS))

# Default target
all: out.jpg

# Executable
$(BUILD_GPU_PATH)cudart: $(BUILD_GPU_PATH)cudart.o
	$(NVCC) $(NVCCFLAGS) $(GENCODE_FLAGS) -o $@ $^

# Object file
$(BUILD_GPU_PATH)cudart.o: $(SRC_GPU_PATH)main.cu
	$(NVCC) $(NVCCFLAGS) $(GENCODE_FLAGS) -o $@ -c $<

# Pattern rule for any .ppm file in img/gpu/
$(IMG_GPU_PATH)%.ppm: $(BUILD_GPU_PATH)cudart
	mkdir -p $(IMG_GPU_PATH)
	rm -f $@
	./$(BUILD_GPU_PATH)cudart > $@

# Make "out.ppm" create the file in the correct location
out.ppm: $(IMG_GPU_PATH)out.ppm
	@echo "Created: $<"

# JPG output
out.jpg: $(IMG_GPU_PATH)out.ppm
	rm -f $(IMG_GPU_PATH)out.jpg
	ppmtojpeg $< > $(IMG_GPU_PATH)out.jpg

# Profile targets
profile_basic: $(BUILD_GPU_PATH)cudart
	mkdir -p $(IMG_GPU_PATH)
	nvprof ./$(BUILD_GPU_PATH)cudart > $(IMG_GPU_PATH)out.ppm

profile_metrics: $(BUILD_GPU_PATH)cudart
	mkdir -p $(IMG_GPU_PATH)
	nvprof --metrics achieved_occupancy,inst_executed,inst_fp_32,inst_fp_64,inst_integer ./$(BUILD_GPU_PATH)cudart > $(IMG_GPU_PATH)out.ppm

clean:
	rm -f $(BUILD_GPU_PATH)cudart $(BUILD_GPU_PATH)cudart.o $(IMG_GPU_PATH)out.ppm $(IMG_GPU_PATH)out.jpg

.PHONY: all clean profile_basic profile_metrics out.ppm