#include <math.h>
#include <stdio.h>
#include <time.h>
#include <stdint.h>
#include <stdlib.h>
#include <curand.h>
#include <curand_kernel.h>

#define W 800
#define H 600
#define MAX_OBJECTS 30
#define SAMPLES 100
#define MAX_BOUNCES 50
#define PIXELS (W*H)
#define THREADS 100
#define BLOCKS (ceil(PIXELS * 1.0) / THREADS)

/* Types */
typedef double sc; // scalar
typedef struct { sc x, y, z; } vec;

/* Vectors */
__host__ __device__ inline static sc dot(vec aa, vec bb)   { return aa.x*bb.x + aa.y*bb.y + aa.z*bb.z; }
__host__ __device__ inline static sc magsq(vec vv)         { return dot(vv, vv); }
__host__ __device__ inline static vec scale(vec vv, sc c)  { vec rv = { vv.x*c, vv.y*c, vv.z*c }; return rv; }
__host__ __device__ inline static vec normalize(vec vv)    { return scale(vv, 1/sqrt(dot(vv, vv))); }
__host__ __device__ inline static vec add(vec aa, vec bb)  { vec rv = { aa.x+bb.x, aa.y+bb.y, aa.z+bb.z }; return rv; }
__host__ __device__ inline static vec sub(vec aa, vec bb)  { return add(aa, scale(bb, -1)); }
__host__ __device__ inline static vec hadamard_product(vec aa, vec bb) { vec rv = { aa.x*bb.x, aa.y*bb.y, aa.z*bb.z }; return rv; }

/* Ray-tracing types */
typedef vec color;              // So as to reuse dot(vv,vv) and scale
typedef struct { color albedo; sc reflectivity; sc fuzz; } material;
typedef struct { vec cp; material ma; sc r; } sphere;
typedef struct { sphere spheres[MAX_OBJECTS]; int nn; } world;
typedef struct { vec start; vec dir; } ray; // dir is normalized!

/* Random sampling */

__global__ void setup_kernel(curandState *state){
  int idx = threadIdx.x+blockDim.x*blockIdx.x;
  curand_init(1234, idx, 0, &state[idx]);
}

__host__ static sc random_double() { 
    return (rand() / (RAND_MAX + 1.0)); } // [0, 1)
__host__ static vec random_vec() {
    vec v = { random_double(), random_double(), random_double() };
    return v;
}
__host__ static color random_color() { return random_vec(); }

__device__ static sc d_random_double(curandState *d_randstate) { return curand_uniform_double(d_randstate); }
__device__ static vec d_random_vec(curandState *d_randstate) {
    vec v = { d_random_double(d_randstate), d_random_double(d_randstate), d_random_double(d_randstate) };
    return v;
}
__device__ static vec d_random_in_unit_sphere(curandState *d_randstate) {
    while (1) {
        vec v = d_random_vec(d_randstate);
        if (magsq(v) <= 1) return v;
    }
}
__device__ static vec d_random_unit_vector(curandState *d_randstate) { return normalize(d_random_in_unit_sphere(d_randstate)); }

/* Ray-tracing */

__device__ static color BLACK = {0, 0, 0};
__device__ static color WHITE = {1.0, 1.0, 1.0};
__device__ static color BLUE = {0.25, 0.49, 1.0};

__device__ static vec reflect(vec incoming, vec normal) {
    return sub(incoming, scale(normal, dot(incoming,normal)*2));
}

__device__ static int find_nearest_intersection(ray rr, sphere ss, sc *intersection) {
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

__device__ static color ray_color(curandState *randstate, const world *here, ray rr)
{
  sc intersection;
  sc nearest_t;
  const sphere *nearest_object;
  color albedo = WHITE;

  for (int depth = 0; depth < MAX_BOUNCES; depth++) {
    nearest_object = 0;
    nearest_t = 1/.0;
    for (int i = 0; i < here->nn; i++) {
        if (find_nearest_intersection(rr, here->spheres[i], &intersection)) {
        if (intersection < 0.000001 || intersection >= nearest_t) continue;
        nearest_t = intersection;
        nearest_object = &here->spheres[i];
        }
    }

    if (nearest_object) {
        // Object color
        vec point = add(rr.start, scale(rr.dir, nearest_t));
        vec normal = normalize(sub(point, nearest_object->cp));

        ray bounce = { point };
        if (nearest_object->ma.reflectivity == 0) { // Matte, regular scattering
            bounce.dir = add(normal, d_random_unit_vector(randstate));
        } else { // Reflective metal scattering
            vec reflected = reflect(rr.dir, normal);
            bounce.dir = add(reflected, scale(d_random_unit_vector(randstate), nearest_object->ma.fuzz));
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


__device__ static ray get_ray(curandState *randstate, int w, int h, int x, int y) {
  // Camera is always at 0,0
  sc aspect = ((sc)w)/h; // Assume aspect >= 1
  sc viewport_height = 2.0;
  sc focal_length = 1.0; // Z distance of viewport
  sc viewport_width = viewport_height * aspect;

  sc pixel_width = (viewport_width / w);
  sc pixel_height = (viewport_height / h);
  sc left = viewport_width / -2.0;
  sc top = viewport_height / 2.0;

  sc px = left + (pixel_width * (x + d_random_double(randstate)));
  sc py = top - (pixel_height * (y + d_random_double(randstate)));

  vec pv = { px, py, focal_length };
  ray rr = { {0}, normalize(pv) };

  return rr;
}

__device__ static void render_pixel(curandState *randstate, const world *here, int w, int h, int samples, int x, int y, color *result)
{
  color pixel_color = {0, 0, 0};
  for (int sample = 0; sample < samples; ++sample) {
    ray rr = get_ray(randstate, w, h, x, y);
    pixel_color = add(pixel_color, ray_color(randstate, here, rr));
  }
  *result = pixel_color;
}

__global__ void render_pixels(curandState *randstate, const world *here, int w, int h, int samples, color *result)
{
  // COPY world + randstate

  int idx = threadIdx.x + blockDim.x*blockIdx.x;
  int x = idx % W;
  int y = idx / W;

  curandState state = randstate[threadIdx.x];

  if (idx < PIXELS) {
    render_pixel(&state, here, w, h, samples, x, y, &result[y*W+x]);
  }
}

static void render(curandState *d_randstate,
                   world *h_here, int w, int h, int samples_per_pixel)
{
  // Copy the world to the GPU
  world *d_here;
  cudaMalloc(&d_here, sizeof(world));
  cudaMemcpy(d_here, h_here, sizeof(world), cudaMemcpyHostToDevice);

  // Allocate space for the result
  color *d_result;
  color *h_result = (color *)malloc(sizeof(color)*PIXELS);
  cudaMalloc(&d_result, sizeof(color)*PIXELS);

  // Calculate the pixels
  render_pixels<<<BLOCKS, THREADS>>>(d_randstate, d_here, w, h, samples_per_pixel, d_result);
  cudaMemcpy(h_result, d_result, PIXELS * sizeof(color), cudaMemcpyDeviceToHost);

  // Print PPM
  output_header(w, h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      color pixel_color = h_result[y*W+x];
      encode_color(scale(pixel_color, 1.0/samples_per_pixel));
    }
  }
}

// Ground
sphere ground  = { .cp = {0,  -1000, 5}, .ma = { .albedo = {0.5, 0.5, 0.5} }, .r = 1000 };
// Sphere 1, reflective (fuzzier)
sphere sphere1 = { .cp = {-2, 1.0,   5}, .ma = { .albedo = {0.7, 0.7, 0.7}, .reflectivity = 1.0, .fuzz = 0.3 }, .r = 1 };
// Sphere 2, matte brown
sphere sphere2 = { .cp = {0,  1.0, 5},   .ma = { .albedo = {0.4, 0.2, 0.1} }, .r = 1 };
// Sphere 3, reflective
sphere sphere3 = { .cp = {2,  1.0, 5},    .ma = { .albedo = {0.5, 0.5, 0.5}, .reflectivity = 1.0, }, .r = 1 };
void scene(world *here) {
  sc ALT = -2.0;
  sc RAD = 0.2;

  here->spheres[here->nn++] = ground;
  here->spheres[here->nn++] = sphere1;
  here->spheres[here->nn++] = sphere2;
  here->spheres[here->nn++] = sphere3;

  for (int a=-2; a<=2; a++) {
    for (int b=3; b<=7; b++) {
      // Add a sphere
      sphere *s = &here->spheres[here->nn++];
      s->cp.x = a + 0.9*random_double();
      s->cp.y = RAD;
      s->cp.z = b + 0.9*random_double();
      s->r = RAD;
      s->ma.reflectivity = random_double() > 0.8;
      s->ma.fuzz = random_double();
      s->ma.albedo = random_color();
    }
  }

  for (int i=0; i<here->nn; i++) here->spheres[i].cp.y += ALT;
}

int main(int argc, char **argv) {
  curandState *d_randstate;
  cudaMalloc(&d_randstate, sizeof(curandState)*THREADS);
  setup_kernel<<<1, 1024>>>(d_randstate);

  world here = {0};
  scene(&here);

  clock_t start, stop;
  start = clock();
  render(d_randstate, &here, W, H, SAMPLES);
  stop = clock();
  fprintf(stderr, "Render: %ldms (%0.1f fps)\n", (stop-start)/1000, 1000000.0/(stop-start));
  return 0;
}
