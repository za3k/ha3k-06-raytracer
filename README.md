A simple raytracer written in C.

Based on a [raytracer](http://canonical.org/~kragen/sw/aspmisc/raytracer.c) written 
aytracer written by [kragen](http://canonical.org/~kragen/sw/aspmisc/my-very-first-raytracer.html); and on [Ray Tracing in One Weekend](https://raytracing.github.io/books/RayTracingInOneWeekend.html) by Peter Shirley, Trevor David Black, Steve Hollasch.

## Raytracing Progress
---
(Day 03): Write basic raytracer

Fix reference image. Initial render takes 14.1s.
Add CUDA support. Base render is now 621ms (1.6 fps) with no changes except to RNG.
Fix RNG. 102ms (9.8fps)
