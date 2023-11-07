CFLAGS=-Wall

LXLIB=-Iyeso -L/home/zachary/ha3k-06-raytracer-cuda/yeso -lyeso-xlib -lX11 -lXext

all: raytrace-cpu raytrace-cuda
images: image-cpu.png image-cuda.png
clean:
	rm -f *.o yeso/*.o *.a yeso/*.a raytrace-cpu raytrace-cuda image-cuda.png

raytrace-cpu: raytrace.c
	cc $(CFLAGS) -g -O5 -msse2 -mfpmath=sse $< -lm -o $@
raytrace-cuda: raytrace.cu yeso/yeso.h yeso/libyeso-xlib.a
	NVCC_PREPEND_FLAGS='-ccbin /usr/bin/g++-12' nvcc -O5 $(LXLIB) -o $@ $<
test: raytrace-cuda
	./raytrace-cuda | feh -
image-cpu.png: raytrace-cpu
	./raytrace-cpu | convert ppm:- $@
image-cuda.png: raytrace-cuda
	./raytrace-cuda | convert ppm:- $@
yeso/libyeso-xlib.a: yeso/yeso.o
	ar rcsDv $@ $^
