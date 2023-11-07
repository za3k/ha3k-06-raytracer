CFLAGS=-Wall

all: raytrace
raytrace: raytrace.c
	cc $(CFLAGS) -g -O5 -msse2 -mfpmath=sse $< -lm -o $@
test: raytrace
	./raytrace | convert ppm:- png:- | feh -
rng: sample.cu
	NVCC_PREPEND_FLAGS='-ccbin /usr/bin/g++-12' nvcc -o $@ $<
