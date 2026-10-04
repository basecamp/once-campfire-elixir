/* Active Storage's ruby-vips/ImageProcessing pipeline, exposed as a small port executable.
 * Domain models, variants and persistence stay in Elixir. */
#include <vips/vips.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int fail(void) { fprintf(stderr, "%s", vips_error_buffer()); vips_error_clear(); return 1; }
static int accepts_page(const char *path) {
  const char *loader = vips_foreign_find_load(path);
  if (!loader) { vips_error_clear(); return 0; }
  VipsOperation *op = vips_operation_new(loader);
  if (!op) { vips_error_clear(); return 0; }
  const char **names; int *flags; int n; int accepts = 0;
  if (vips_object_get_args(VIPS_OBJECT(op), &names, &flags, &n) == 0) {
    for (int i = 0; i < n; i++) {
      int required = (flags[i] & VIPS_ARGUMENT_REQUIRED) && !(flags[i] & VIPS_ARGUMENT_DEPRECATED);
      if (!strcmp(names[i], "page") && !required && (flags[i] & VIPS_ARGUMENT_CONSTRUCT) && (flags[i] & VIPS_ARGUMENT_INPUT)) accepts = 1;
    }
  }
  g_object_unref(op); return accepts;
}
/* Build a vips operation from the same ordered required and keyword arguments
 * that ruby-vips uses. Values arrive as argv data, never command text. */
static VipsImage *operation(VipsImage *image, const char *name, int count, char **args,
                            int options, char **keywords) {
  VipsOperation *op = vips_operation_new(name);
  if (!op) return NULL;
  const char **names; int *flags; int n, index = 0, bound = 0;
  const char *output = NULL;
  if (vips_object_get_args(VIPS_OBJECT(op), &names, &flags, &n)) goto error;
  for (int i = 0; i < n; i++) {
    GParamSpec *spec = g_object_class_find_property(G_OBJECT_GET_CLASS(op), names[i]);
    if (!(flags[i] & VIPS_ARGUMENT_REQUIRED) || (flags[i] & VIPS_ARGUMENT_DEPRECATED)) continue;
    if ((flags[i] & VIPS_ARGUMENT_OUTPUT) && G_PARAM_SPEC_VALUE_TYPE(spec) == VIPS_TYPE_IMAGE && !output) output = names[i];
    if (!(flags[i] & VIPS_ARGUMENT_INPUT)) continue;
    if (!bound && G_PARAM_SPEC_VALUE_TYPE(spec) == VIPS_TYPE_IMAGE) {
      g_object_set(op, names[i], image, NULL); bound = 1;
    } else {
      if (index >= count || vips_object_set_argument_from_string(VIPS_OBJECT(op), names[i], args[index++])) goto error;
    }
  }
  if (!bound || !output || index != count) goto error;
  for (int i = 0; i < options; i++) {
    if (vips_object_set_argument_from_string(VIPS_OBJECT(op), keywords[i * 2], keywords[i * 2 + 1])) goto error;
  }
  if (vips_cache_operation_buildp(&op)) goto error;
  VipsImage *result = NULL;
  g_object_get(op, output, &result, NULL);
  vips_object_unref_outputs(VIPS_OBJECT(op));
  g_object_unref(op);
  return result;
error:
  vips_object_unref_outputs(VIPS_OBJECT(op));
  g_object_unref(op);
  return NULL;
}

/* Loader and saver keyword filtering follows ImageProcessing::Vips::Utils. */
static int foreign_io(const char *filename, VipsImage *image, int options, char **keywords,
                      VipsImage **loaded) {
  int saving = image != NULL;
  const char *name = saving ? vips_foreign_find_save(filename) : vips_foreign_find_load(filename);
  char explicit_name[128]; int explicit_operation = 0;
  for (int i = 0; i < options; i++) {
    if (!strcmp(keywords[i*2], saving ? "saver" : "loader")) {
      snprintf(explicit_name, sizeof(explicit_name), "%s%s", keywords[i*2+1], saving ? "save" : "load");
      name = explicit_name; explicit_operation = 1;
    }
  }
  if (!name) return -1;
  VipsOperation *op = vips_operation_new(name);
  if (!op) return -1;
  const char **names; int *flags; int n;
  if (vips_object_get_args(VIPS_OBJECT(op), &names, &flags, &n)) goto error;
  g_object_set(op, "filename", filename, NULL);
  if (saving) g_object_set(op, "in", image, NULL);
  for (int i = 0; i < options; i++) {
    const char *key = keywords[i*2], *value = keywords[i*2+1];
    if (!strcmp(key, "autorot") || !strcmp(key, "saver") || !strcmp(key, "loader")) continue;
    if (saving && !strcmp(key, "quality")) key = "Q";
    int valid = 0;
    for (int j = 0; j < n; j++) {
      if (!strcmp(key, names[j]) && (flags[j] & VIPS_ARGUMENT_INPUT) &&
          !(flags[j] & VIPS_ARGUMENT_REQUIRED)) valid = 1;
    }
    if ((valid || explicit_operation) && vips_object_set_argument_from_string(VIPS_OBJECT(op), key, value)) goto error;
  }
  if (vips_cache_operation_buildp(&op)) goto error;
  if (!saving) g_object_get(op, "out", loaded, NULL);
  vips_object_unref_outputs(VIPS_OBJECT(op)); g_object_unref(op); return 0;
error:
  vips_object_unref_outputs(VIPS_OBJECT(op)); g_object_unref(op); return -1;
}

static VipsImage *sharpen(VipsImage *image) {
  double values[] = {-1,-1,-1,-1,32,-1,-1,-1,-1};
  VipsImage *mask = vips_image_new_matrix_from_array(3,3,values,9), *output = NULL;
  if (!mask) return NULL;
  vips_image_set_double(mask, "scale", 24.0);
  if (vips_conv(image, &output, mask, "precision", VIPS_PRECISION_INTEGER, NULL)) output = NULL;
  g_object_unref(mask);
  return output;
}

static VipsImage *transform(VipsImage *image, const char *name, int count, char **args,
                            int options, char **keywords) {
  if (!strcmp(name, "resize_to_limit") || !strcmp(name, "resize_to_fit") ||
      !strcmp(name, "resize_to_fill") || !strcmp(name, "resize_and_pad") || !strcmp(name, "resize_to_cover")) {
    if (count != 2) return NULL;
    int width = atoi(args[0]), height = atoi(args[1]);
    if (width <= 0 || height <= 0) return NULL;
    char cover_width[32], cover_height[32]; char *dimensions[2] = {args[0], args[1]};
    if (!strcmp(name, "resize_to_cover")) {
      if ((double)vips_image_get_width(image) / vips_image_get_height(image) > (double)width / height)
        dimensions[0] = "10000000";
      else dimensions[1] = "10000000";
    }
    snprintf(cover_width, sizeof(cover_width), "%s", dimensions[0]);
    snprintf(cover_height, sizeof(cover_height), "%s", dimensions[1]);
    dimensions[0] = cover_width; dimensions[1] = cover_height;
    /* Additional thumbnail options use the same libvips operation keywords. */
    char *extra[128]; int used = 0;
    extra[used++] = "height"; extra[used++] = dimensions[1];
    extra[used++] = "no_rotate"; extra[used++] = "true";
    if (!strcmp(name, "resize_to_limit")) { extra[used++] = "size"; extra[used++] = "down"; }
    if (!strcmp(name, "resize_to_fill")) { extra[used++] = "crop"; extra[used++] = "centre"; }
    if (!strcmp(name, "resize_to_cover")) { extra[used++] = "crop"; extra[used++] = "none"; }
    int do_sharpen = 1, alpha = 0; char *gravity = "centre";
    char *padding[128]; int padding_used = 0;
    for (int i = 0; i < options; i++) {
      if (!strcmp(keywords[i*2], "sharpen")) { do_sharpen = strcmp(keywords[i*2+1], "false") != 0; continue; }
      if (!strcmp(name, "resize_and_pad")) {
        if (!strcmp(keywords[i*2], "gravity")) { gravity = keywords[i*2+1]; continue; }
        if (!strcmp(keywords[i*2], "alpha")) { alpha = !strcmp(keywords[i*2+1], "true"); continue; }
        if (!strcmp(keywords[i*2], "background") || !strcmp(keywords[i*2], "extend")) {
          if (padding_used + 2 > 128) return NULL;
          padding[padding_used++] = keywords[i*2]; padding[padding_used++] = keywords[i*2+1]; continue;
        }
      }
      if (used + 2 > 128) return NULL;
      extra[used++] = keywords[i*2]; extra[used++] = keywords[i*2+1];
    }
    VipsImage *thumb = operation(image, "thumbnail_image", 1, dimensions, used/2, extra);
    if (!thumb) return NULL;
    VipsImage *output = do_sharpen ? sharpen(thumb) : g_object_ref(thumb);
    g_object_unref(thumb);
    if (!output) return NULL;
    if (!strcmp(name, "resize_and_pad")) {
      if (alpha && !vips_image_hasalpha(output)) {
        VipsImage *with_alpha = NULL; double value = 255;
        if (vips_bandjoin_const(output, &with_alpha, &value, 1, NULL)) { g_object_unref(output); return NULL; }
        g_object_unref(output); output = with_alpha;
      }
      char width_arg[32], height_arg[32]; snprintf(width_arg, sizeof(width_arg), "%d", width); snprintf(height_arg, sizeof(height_arg), "%d", height);
      char *pad_args[] = {gravity, width_arg, height_arg};
      VipsImage *padded = operation(output, "gravity", 3, pad_args, padding_used/2, padding);
      g_object_unref(output); return padded;
    }
    return output;
  }
  if (!strcmp(name, "rotate") && count == 1) {
    double angle = atof(args[0]);
    if (!options && (angle == 90 || angle == 180 || angle == 270)) {
      VipsImage *rotated = NULL;
      if (vips_rot(image, &rotated, angle == 90 ? VIPS_ANGLE_D90 : angle == 180 ? VIPS_ANGLE_D180 : VIPS_ANGLE_D270, NULL)) return NULL;
      return rotated;
    }
    if (options > 63) return NULL;
    char *extra[128]; extra[0] = "angle"; extra[1] = args[0];
    for (int i = 0; i < options*2; i++) extra[i+2] = keywords[i];
    return operation(image, "similarity", 0, NULL, options+1, extra);
  }
  return operation(image, name, count, args, options, keywords);
}

int main(int argc, char **argv) {
  if (argc < 2) return 2;
  if (VIPS_INIT(argv[0])) return fail();
  vips_block_untrusted_set(TRUE);
  vips_operation_block_set("VipsForeignLoadOpenslide", TRUE);
  if (!strcmp(argv[1], "version")) { puts(vips_version_string()); return 0; }
  if (argc < 3) return 2;
  VipsImage *input = NULL;
  if (!strcmp(argv[1], "analyze")) {
    input = vips_image_new_from_file(argv[2], "access", VIPS_ACCESS_SEQUENTIAL, NULL);
    if (!input) { puts("{}"); return 0; }
    int width = vips_image_get_width(input), height = vips_image_get_height(input);
    char *orientation = NULL;
    if (vips_image_get_typeof(input, "exif-ifd0-Orientation") && !vips_image_get_as_string(input, "exif-ifd0-Orientation", &orientation)) {
      if (strstr(orientation, "Right-top") || strstr(orientation, "Left-bottom") || strstr(orientation, "Top-right") || strstr(orientation, "Bottom-left")) { int swap=width; width=height; height=swap; }
      g_free(orientation);
    }
    printf("{\"width\":%d,\"height\":%d}\n", width, height);
    g_object_unref(input); return 0;
  }
  if (!strcmp(argv[1], "transform")) {
    if (argc < 4) return 2;
    char *loader_options[256], *saver_options[256]; int loader_count = 0, saver_count = 0, autorot = 1;
    if (accepts_page(argv[2])) { loader_options[loader_count++] = "page"; loader_options[loader_count++] = "0"; }
    for (int scan = 4; scan < argc;) {
      const char *name = argv[scan++];
      if (scan >= argc) return 2;
      int count = atoi(argv[scan++]); if (count < 0 || scan + count >= argc) return 2;
      scan += count; int options = atoi(argv[scan++]);
      if (options < 0 || scan + options*2 > argc) return 2;
      if (!strcmp(name, "loader") || !strcmp(name, "saver")) {
        if (count) return 2;
        char **destination = !strcmp(name, "loader") ? loader_options : saver_options;
        int *used = !strcmp(name, "loader") ? &loader_count : &saver_count;
        if (*used + options*2 > 256) return 2;
        for (int j = 0; j < options*2; j++) destination[(*used)++] = argv[scan+j];
        if (!strcmp(name, "loader")) for (int j = 0; j < options; j++) {
          if (!strcmp(argv[scan+j*2], "autorot")) autorot = strcmp(argv[scan+j*2+1], "false") != 0;
          if (!strcmp(argv[scan+j*2], "autorotate")) autorot = 0;
        }
      }
      scan += options*2;
    }
    if (foreign_io(argv[2], NULL, loader_count/2, loader_options, &input)) return fail();
    VipsImage *current = NULL;
    if (autorot) { if (vips_autorot(input, &current, NULL)) return fail(); }
    else current = g_object_ref(input);
    g_object_unref(input);
    int index = 4;
    while (index < argc) {
      const char *name = argv[index++];
      if (index >= argc) return 2;
      int count = atoi(argv[index++]);
      if (count < 0 || index + count >= argc) return 2;
      char **args = argv + index; index += count;
      int options = atoi(argv[index++]);
      if (options < 0 || index + options*2 > argc) return 2;
      if (!strcmp(name, "loader") || !strcmp(name, "saver")) { index += options*2; continue; }
      VipsImage *next = transform(current, name, count, args, options, argv + index);
      index += options*2;
      g_object_unref(current);
      if (!next) return fail();
      current = next;
    }
    int status = foreign_io(argv[3], current, saver_count/2, saver_options, NULL);
    g_object_unref(current);
    return status ? fail() : 0;
  }
  int convert = !strcmp(argv[1], "convert");
  if ((!convert && strcmp(argv[1], "resize")) || argc != (convert ? 4 : 6)) return 2;
  input = accepts_page(argv[2]) ? vips_image_new_from_file(argv[2], "page", 0, NULL) : vips_image_new_from_file(argv[2], NULL);
  if (!input) return fail();
  VipsImage *rotated=NULL, *thumbnail=NULL, *mask=NULL, *output=NULL;
  if (vips_autorot(input, &rotated, NULL)) return fail();
  if (convert) {
    if (vips_image_write_to_file(rotated, argv[3], NULL)) return fail();
    g_object_unref(rotated); g_object_unref(input); return 0;
  }
  int width = atoi(argv[4]), height = atoi(argv[5]);
  if (width<=0 || height<=0) return 2;
  if (vips_thumbnail_image(rotated, &thumbnail, width, "height", height, "size", VIPS_SIZE_DOWN, "no_rotate", TRUE, NULL)) return fail();
  double values[] = {-1,-1,-1,-1,32,-1,-1,-1,-1};
  mask = vips_image_new_matrix_from_array(3,3,values,9);
  if (!mask) return fail();
  vips_image_set_double(mask,"scale",24.0); vips_image_set_double(mask,"offset",0.0);
  if (vips_conv(thumbnail,&output,mask,"precision",VIPS_PRECISION_INTEGER,NULL)) return fail();
  if (vips_image_write_to_file(output,argv[3],NULL)) return fail();
  g_object_unref(output);g_object_unref(mask);g_object_unref(thumbnail);g_object_unref(rotated);g_object_unref(input);
  return 0;
}
