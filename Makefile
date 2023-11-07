CFLAGS=-Wall

all: raytrace-cpu raytrace-cuda
raytrace-cpu: raytrace.c
	cc $(CFLAGS) -g -O5 -msse2 -mfpmath=sse $< -lm -o $@
raytrace-cuda: raytrace.cu
	NVCC_PREPEND_FLAGS='-ccbin /usr/bin/g++-12' nvcc -O5 -o $@ $<
test: raytrace
	./raytrace | convert ppm:- png:- | feh -
rng: sample.cu
	NVCC_PREPEND_FLAGS='-ccbin /usr/bin/g++-12' nvcc -o $@ $<
