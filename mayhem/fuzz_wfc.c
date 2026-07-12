// fuzz_wfc.c — in-process libFuzzer harness for wfc (Wave Function Collapse).
//
// Drives the same code path as the original file-input CLI target
// (`wfc -m overlapping input.png out.png`): stb_image decode -> wfc_overlapping
// (tile extraction, flips + rotations) -> wfc_run (propagation/collapse) ->
// wfc_output_image. Converted to an in-process harness so each input runs in
// microseconds instead of a full 128x128 CLI generation, with input dimensions
// bounded so the WFC solve stays cheap while every library stage is exercised.
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image.h"
#include "stb_image_write.h"

#define WFC_IMPLEMENTATION
#define WFC_USE_STB
#include "wfc.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
  int w = 0, h = 0, comp = 0;
  unsigned char *pixels = stbi_load_from_memory(data, (int)size, &w, &h, &comp, 0);
  if (!pixels)
    return 0;

  if (w < 3 || h < 3 || w > 20 || h > 20 || comp < 1 || comp > 4) {
    stbi_image_free(pixels);
    return 0;
  }

  struct wfc_image image = { pixels, comp, w, h };
  struct wfc *wfc = wfc_overlapping(16, 16, &image, 3, 3, 1, 1, 1, 1);
  if (wfc) {
    if (wfc_run(wfc, 12345)) {
      struct wfc_image *out = wfc_output_image(wfc);
      if (out)
        wfc_img_destroy(out);
    }
    wfc_destroy(wfc);
  }

  stbi_image_free(pixels);
  return 0;
}
