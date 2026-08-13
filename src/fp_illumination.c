#include "fp_internal.h"

static void fp_dilate_simple(uint8_t *mask, int32_t w, int32_t h, int32_t r) {
    uint8_t *tmp = (uint8_t *)malloc((size_t)(w * h));
    if (!tmp) return;
    memcpy(tmp, mask, (size_t)(w * h));
    for (int32_t y = 0; y < h; y++) {
        for (int32_t x = 0; x < w; x++) {
            int32_t max_v = 0;
            for (int32_t dy = -r; dy <= r; dy++) {
                for (int32_t dx = -r; dx <= r; dx++) {
                    int32_t nx = x + dx, ny = y + dy;
                    if (nx >= 0 && nx < w && ny >= 0 && ny < h) {
                        if (tmp[ny * w + nx] > max_v) max_v = tmp[ny * w + nx];
                    }
                }
            }
            mask[y * w + x] = (uint8_t)max_v;
        }
    }
    free(tmp);
}

static void fp_clahe_tile(uint8_t *img, int32_t w, int32_t h,
                          int32_t tx, int32_t ty, int32_t tw, int32_t th) {
    int32_t hist[256] = {0};
    int32_t clip_limit = (tw * th) / 10;
    if (clip_limit < 1) clip_limit = 1;

    for (int32_t y = ty; y < ty + th && y < h; y++) {
        for (int32_t x = tx; x < tx + tw && x < w; x++) {
            hist[img[y * w + x]]++;
        }
    }

    int32_t excess = 0;
    for (int32_t i = 0; i < 256; i++) {
        if (hist[i] > clip_limit) {
            excess += hist[i] - clip_limit;
            hist[i] = clip_limit;
        }
    }
    int32_t redist = excess / 256;
    for (int32_t i = 0; i < 256; i++) hist[i] += redist;

    int32_t cdf[256];
    cdf[0] = hist[0];
    for (int32_t i = 1; i < 256; i++) cdf[i] = cdf[i - 1] + hist[i];

    int32_t cdf_min = cdf[0];
    for (int32_t i = 1; i < 256; i++) {
        if (cdf[i] < cdf_min) cdf_min = cdf[i];
    }
    int32_t scale = 255 * (tw * th - cdf_min);
    if (scale <= 0) scale = 1;

    uint8_t lut[256];
    for (int32_t i = 0; i < 256; i++) {
        lut[i] = (uint8_t)(((cdf[i] - cdf_min) * 255) / scale);
    }

    for (int32_t y = ty; y < ty + th && y < h; y++) {
        for (int32_t x = tx; x < tx + tw && x < w; x++) {
            img[y * w + x] = lut[img[y * w + x]];
        }
    }
}

static void fp_detect_highlights(const uint8_t *input, int32_t w, int32_t h,
                                  uint8_t *highlight_mask) {
    int32_t n = w * h;
    for (int32_t i = 0; i < n; i++) {
        highlight_mask[i] = (input[i] > 230) ? 255 : 0;
    }
    fp_dilate_simple(highlight_mask, w, h, 1);
}

static void fp_inpaint_highlights(uint8_t *img, const uint8_t *mask,
                                   int32_t w, int32_t h) {
    for (int32_t y = 1; y < h - 1; y++) {
        for (int32_t x = 1; x < w - 1; x++) {
            if (mask[y * w + x] == 0) continue;
            int32_t sum = 0, cnt = 0;
            for (int32_t dy = -2; dy <= 2; dy++) {
                for (int32_t dx = -2; dx <= 2; dx++) {
                    int32_t nx = x + dx, ny = y + dy;
                    if (mask[ny * w + nx] == 0) {
                        sum += img[ny * w + nx];
                        cnt++;
                    }
                }
            }
            if (cnt > 0) img[y * w + x] = (uint8_t)(sum / cnt);
        }
    }
}

int32_t fp_normalize_illumination(
    const uint8_t *input_img, int32_t width, int32_t height,
    uint8_t *output_img) {

    if (!input_img || !output_img || width <= 0 || height <= 0) {
        return FP_ERR_INVALID_INPUT;
    }

    int32_t n = width * height;
    memcpy(output_img, input_img, (size_t)n);

    int32_t tile_w = width / 8;
    int32_t tile_h = height / 8;
    if (tile_w < 8) tile_w = width;
    if (tile_h < 8) tile_h = height;

    for (int32_t ty = 0; ty < height; ty += tile_h) {
        for (int32_t tx = 0; tx < width; tx += tile_w) {
            int32_t tw = tile_w;
            int32_t th = tile_h;
            if (tx + tw > width) tw = width - tx;
            if (ty + th > height) th = height - ty;
            fp_clahe_tile(output_img, width, height, tx, ty, tw, th);
        }
    }

    uint8_t *hl_mask = (uint8_t *)calloc((size_t)n, 1);
    if (!hl_mask) return FP_ERR_OUT_OF_MEMORY;

    fp_detect_highlights(output_img, width, height, hl_mask);
    fp_inpaint_highlights(output_img, hl_mask, width, height);
    free(hl_mask);

    return FP_OK;
}
