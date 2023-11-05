A simple raytracer written in C.

Based on a [raytracer](http://canonical.org/~kragen/sw/aspmisc/raytracer.c) written 
aytracer written by [kragen](http://canonical.org/~kragen/sw/aspmisc/my-very-first-raytracer.html); and on [Ray Tracing in One Weekend](https://raytracing.github.io/books/RayTracingInOneWeekend.html) by Peter Shirley, Trevor David Black, Steve Hollasch.

## Raytracing Progress
---
### Basics (one sphere, on/off color), Rectangular viewport
<img src="v02.png"> (1s/pix)
---
### Basic coloring based on position ("normals")
<img src="v03.png"> (1s/pix)
---
### Add ground (a big sphere) and two more spheres
<img src="v05.png"> (1s/pix)
---
### Add antialiasing (and accidentally zoom out)
<img src="v06.png"> (10s/pix)
---
### Add sky color
<img src="v07.png"> (10s/pix)
---
### Add diffusion
<img src="v08.png"> (10s/pix)
---
### Make diffusion more directional (Lambertian diffusion) and zoom back in
<img src="v09.png"> (10s/pix)
---
### Increase (10x) random samples per pixel
<img src="v10.png"> (100s/pix)
---
### Shift camera slightly to not intersect the ground
<img src="v11a.png"> (100s/pix)
---
### Gamma correction
<img src="v12.png"> (100s/pix)
---
### Add color to spheres
<img src="v13.png"> (100s/pix)
---
### Add reflectivity and varied fuzziness parameter
<img src="v14.png"> (100s/pix)
---
### Final Scene
<img src="v15a.png"> (1s/pix, 2s) <br>
<img src="v15.png"> (10s/pix, 20s) <br>
<img src="v15b.png"> (100s/pix, 3m24s)<br>
<img src="v15c.png"> (1000s/pix, 33m)
