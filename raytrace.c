#include <math.h>
#include <stdio.h>
#include <time.h>
#include <stdint.h>
#include <stdlib.h>

/* Types */
typedef float sc; // scalar
typedef struct { sc x, y, z; } vec;
typedef int bool;

/* Vectors */
inline static sc dot(vec aa, vec bb)   { return aa.x*bb.x + aa.y*bb.y + aa.z*bb.z; }
inline static sc magsq(vec vv)         { return dot(vv, vv); }
inline static vec scale(vec vv, sc c)  { vec rv = { vv.x*c, vv.y*c, vv.z*c }; return rv; }
inline static vec normalize(vec vv)    { return scale(vv, 1/sqrt(dot(vv, vv))); }
inline static vec add(vec aa, vec bb)  { vec rv = { aa.x+bb.x, aa.y+bb.y, aa.z+bb.z }; return rv; }
inline static vec sub(vec aa, vec bb)  { return add(aa, scale(bb, -1)); }
inline static vec hadamard_product(vec aa, vec bb) { vec rv = { aa.x*bb.x, aa.y*bb.y, aa.z*bb.z }; return rv; }

/* Ray-tracing types */
typedef vec color;              // So as to reuse dot(vv,vv) and scale
typedef struct { color albedo; sc reflectivity; sc fuzz; } material;
typedef struct { vec cp; material ma; sc r; } sphere;
typedef struct { sphere *spheres; int nn; } world;
typedef struct { vec start; vec dir; } ray; // dir is normalized!

/* Random sampling */

static sc random_double() { 
    return (rand() / (RAND_MAX + 1.0)); } // [0, 1)
static vec random_vec() {
    vec v = { random_double(), random_double(), random_double() };
    return v;
}
static vec random_in_unit_sphere() {
    while (1) {
        vec v = random_vec();
        if (magsq(v) <= 1) return v;
    }
}
static vec random_unit_vector() { return normalize(random_in_unit_sphere()); }

static color random_color() { return random_vec(); }

/* Ray-tracing */

static color BLACK = {0, 0, 0};
static color WHITE = {1.0, 1.0, 1.0};
static color BLUE = {0.25, 0.49, 1.0};

static vec reflect(vec incoming, vec normal) {
    return sub(incoming, scale(normal, dot(incoming,normal)*2));
}

static bool find_nearest_intersection(ray rr, sphere ss, sc *intersection) {
  vec center_rel = sub(rr.start, ss.cp);
  // Quadratic coefficients of parametric intersection equation.  a == 1.
  sc b = 2*dot(center_rel, rr.dir), c = magsq(center_rel) - ss.r*ss.r;
  sc discrim = b*b - 4*c;
  if (discrim < 0) return 0;
  sc sqdiscrim = sqrt(discrim);
  *intersection = (-b - sqdiscrim > 0 ? (-b - sqdiscrim)/2
                                      : (-b + sqdiscrim)/2);
  return 1;
}

static color ray_color(world here, ray rr)
{
  sc intersection;
  sc nearest_t;
  sphere *nearest_object;
  color albedo = WHITE;

  for (int depth = 0; depth < 50; depth++) {
    nearest_object = 0;
    nearest_t = 1/.0;
    for (int i = 0; i < here.nn; i++) {
        if (find_nearest_intersection(rr, here.spheres[i], &intersection)) {
        if (intersection < 0.000001 || intersection >= nearest_t) continue;
        nearest_t = intersection;
        nearest_object = &here.spheres[i];
        }
    }

    if (nearest_object) {
        // Object color
        vec point = add(rr.start, scale(rr.dir, nearest_t));
        vec normal = normalize(sub(point, nearest_object->cp));

        ray bounce = { point };
        if (nearest_object->ma.reflectivity == 0) { // Matte, regular scattering
            bounce.dir = add(normal, random_unit_vector());
        } else { // Reflective metal scattering
            vec reflected = reflect(rr.dir, normal);
            bounce.dir = add(reflected, scale(random_unit_vector(), nearest_object->ma.fuzz));
            if (dot(bounce.dir, normal) < 0) return BLACK;
        }
        if (magsq(bounce.dir) < 0.0000001) return BLACK;
        bounce.dir = normalize(bounce.dir);
        rr = bounce;
        albedo = hadamard_product(albedo, nearest_object->ma.albedo);
    } else {
        // Sky color
        sc a = 0.5 * (rr.dir.y + 1);
        return hadamard_product(albedo, add(scale(WHITE, 1.0-a), scale(BLUE, a)));
    }
  }
  return BLACK;
}

/* PPM6 */
/* PPM P6 file format; see <http://netpbm.sourceforge.net/doc/ppm.html> */

static void
output_header(int w, int h)
{ printf("P6\n%d %d\n255\n", w, h); }

static unsigned char
byte(double dd) { return dd > 1 ? 255 : dd < 0 ? 0 : dd * 255 + 0.5; }

static void
encode_color(color co)
{ putchar(byte(sqrt(co.x))); putchar(byte(sqrt(co.y))); putchar(byte(sqrt(co.z))); }

/* Rendering */

static ray get_ray(int w, int h, int x, int y) {
  // Camera is always at 0,0
  sc aspect = ((sc)w)/h; // Assume aspect >= 1
  sc viewport_height = 2.0;
  sc focal_length = 1.0; // Z distance of viewport
  sc viewport_width = viewport_height * aspect;

  sc pixel_width = (viewport_width / w);
  sc pixel_height = (viewport_height / h);
  sc left = viewport_width / -2.0;
  sc top = viewport_height / 2.0;

  sc px = left + (pixel_width * (x + random_double()));
  sc py = top - (pixel_height * (y + random_double()));

  vec pv = { px, py, focal_length };
  ray rr = { {0}, normalize(pv) };

  return rr;
}

static void render(world here, int w, int h, int samples_per_pixel)
{
  output_header(w, h);
  for (int i = 0; i < h; i++)
    for (int j = 0; j < w; j++) {
      color pixel_color = {0, 0, 0};
      for (int sample = 0; sample < samples_per_pixel; ++sample) {
        ray rr = get_ray(w, h, j, i);
        pixel_color = add(pixel_color, ray_color(here, rr));
      }
      encode_color(scale(pixel_color, 1.0/samples_per_pixel));
    }
}

void scene(world *here) {
  sc ALT = -2.0;
  // Ground
  sphere ground = { .ma = { .albedo = {0.5, 0.5, 0.5} }, .r = 1000, .cp = {0, -1000+ALT, 5} };
  // Sphere 1, reflective (fuzzier)
  sphere sphere1 = { .ma = { .albedo = {0.7, 0.7, 0.7}, .reflectivity = 1.0, .fuzz = 0.3 }, .r = 1, .cp = {-2, ALT+1.0, 5} };
  // Sphere 2, matte brown
  sphere sphere2 = { .ma = { .albedo = {0.4, 0.2, 0.1} }, .r = 1, .cp = {0, ALT+1.0, 5} };
  // Sphere 3, reflective
  sphere sphere3 = { .ma = { .albedo = {0.5, 0.5, 0.5}, .reflectivity = 1.0, }, .r = 1, .cp = {2, ALT+1.0, 5} };

  here->spheres[here->nn++] = ground;
  here->spheres[here->nn++] = sphere1;
  here->spheres[here->nn++] = sphere2;
  here->spheres[here->nn++] = sphere3;

  for (int a=-2; a<=2; a++) {
    for (int b=3; b<=7; b++) {
      // Add a sphere
      sc RAD = 0.2;
      sphere new = {
        .cp = { a + 0.9*random_double(), ALT+RAD, b + 0.9*random_double() },
        .r = RAD,
        .ma = {
          .reflectivity = random_double() > 0.8,
          .albedo = random_color(),
          .fuzz = random_double(),
        },
      };
      here->spheres[here->nn++] = new;
    }
  }
}

int main(int argc, char **argv) {
  sphere ss[30];
  world here = { ss, 0 };
  scene(&here);

  clock_t start, stop;
  start = clock();
  render(here, 800, 600, 100);
  stop = clock();
  fprintf(stderr, "Render: %ldms\n", (stop-start)/1000);
  return 0;
}
