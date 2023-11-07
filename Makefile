CFLAGS=-Wall

all: raytrace-cpu raytrace-cuda
raytrace-cpu: raytrace.c
	cc $(CFLAGS) -g -O5 -msse2 -mfpmath=sse $< -lm -o $@
raytrace-cuda: raytrace.cu
	NVCC_PREPEND_FLAGS='-ccbin /usr/bin/g++-12' nvcc -O5 -o $@ $<
test: raytrace-cuda
	./raytrace-cuda | feh -
images: image-cpu.png image-cuda.png
image-cpu.png: raytrace-cpu
	./raytrace-cpu | convert ppm:- image-cpu.png
image-cuda.png: raytrace-cuda
	./raytrace-cuda | convert ppm:- image-cuda.png
rng: sample.cu
	NVCC_PREPEND_FLAGS='-ccbin /usr/bin/g++-12' nvcc -o $@ $<
