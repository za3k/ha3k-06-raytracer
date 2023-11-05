CFLAGS=-Wall

all: raytrace
raytrace: raytrace.c
	cc $(CFLAGS) -g -O5 -msse2 -mfpmath=sse $< -lm -o $@
