CUDA_PATH     ?= /opt/cuda
HOST_COMPILER  = g++
NVCC           = $(CUDA_PATH)/bin/nvcc -ccbin $(HOST_COMPILER)
CXX            = $(HOST_COMPILER)

SRC_GPU_PATH   = src/gpu/
BUILD_GPU_PATH = build/gpu/
IMG_GPU_PATH   = img/gpu/

# Find all header files automatically
HEADERS = $(wildcard $(SRC_GPU_PATH)*.h)
CUDA_SRCS = $(wildcard $(SRC_GPU_PATH)*.cu)
CXX_SRCS = $(wildcard $(SRC_GPU_PATH)*.cpp)

# Convert source files to object files
CUDA_OBJS = $(patsubst $(SRC_GPU_PATH)%.cu, $(BUILD_GPU_PATH)%.o, $(CUDA_SRCS))
CXX_OBJS = $(patsubst $(SRC_GPU_PATH)%.cpp, $(BUILD_GPU_PATH)%.o, $(CXX_SRCS))

# Include paths
INCLUDES = -I$(SRC_GPU_PATH) -I$(CUDA_PATH)/include

# NVCC_DBG       = -g -G
NVCC_DBG       =  # Uncomment for release
NVCCFLAGS      = $(NVCC_DBG) -m64 $(INCLUDES)
CXXFLAGS       = -O2 $(INCLUDES)
LDFLAGS        = -L$(CUDA_PATH)/lib64 -lcudart
GENCODE_FLAGS  = -gencode arch=compute_86,code=sm_86

# Create directories
DIRS = $(BUILD_GPU_PATH) $(IMG_GPU_PATH)
$(shell mkdir -p $(DIRS))

# Default target
all: out.jpg

# Link all object files
$(BUILD_GPU_PATH)cudart: $(CUDA_OBJS) $(CXX_OBJS)
	$(NVCC) $(NVCCFLAGS) $(GENCODE_FLAGS) -o $@ $^ $(LDFLAGS)

# Compile .cu files with nvcc
$(BUILD_GPU_PATH)%.o: $(SRC_GPU_PATH)%.cu $(HEADERS)
	$(NVCC) $(NVCCFLAGS) $(GENCODE_FLAGS) -o $@ -c $<

# Compile .cpp files with regular C++ compiler
$(BUILD_GPU_PATH)%.o: $(SRC_GPU_PATH)%.cpp $(HEADERS)
	$(CXX) $(CXXFLAGS) -c $< -o $@

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

memcheck: $(BUILD_GPU_PATH)cudart
	cuda-memcheck ./$(BUILD_GPU_PATH)cudart > $(IMG_GPU_PATH)out.ppm

clean:
	rm -f $(BUILD_GPU_PATH)cudart $(BUILD_GPU_PATH)*.o $(IMG_GPU_PATH)out.ppm $(IMG_GPU_PATH)out.jpg

.PHONY: all clean profile_basic profile_metrics memcheck out.ppm