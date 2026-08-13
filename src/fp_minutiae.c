#include "fp_internal.h"

/* Sobel edge detection */
static void fp_sobel(const uint8_t *src, int32_t w, int32_t h, int16_t *gx, int16_t *gy) {
    for (int32_t y = 1; y < h - 1; y++) {
        for (int32_t x = 1; x < w - 1; x++) {
            int32_t idx = y * w + x;
            gx[idx] = (int16_t)(
                -src[(y-1)*w+(x-1)] - 2*src[y*w+(x-1)] - src[(y+1)*w+(x-1)]
                + src[(y-1)*w+(x+1)] + 2*src[y*w+(x+1)] + src[(y+1)*w+(x+1)]
            );
            gy[idx] = (int16_t)(
                -src[(y-1)*w+(x-1)] - 2*src[(y-1)*w+x] - src[(y-1)*w+(x+1)]
                + src[(y+1)*w+(x-1)] + 2*src[(y+1)*w+x] + src[(y+1)*w+(x+1)]
            );
        }
    }
}

/* Simple binarization (Otsu-like threshold) */
static uint8_t fp_otsu_threshold(const uint8_t *img, int32_t n) {
    int32_t hist[256] = {0};
    for (int32_t i = 0; i < n; i++) hist[img[i]]++;

    int64_t total = n;
    int64_t sum = 0;
    for (int32_t i = 0; i < 256; i++) sum += (int64_t)i * hist[i];

    int64_t sumB = 0;
    int64_t wB = 0;
    float max_var = 0.0f;
    uint8_t threshold = 128;

    for (int32_t t = 0; t < 256; t++) {
        wB += hist[t];
        if (wB == 0) continue;
        int64_t wF = total - wB;
        if (wF == 0) break;
        sumB += (int64_t)t * hist[t];
        float mB = (float)sumB / (float)wB;
        float mF = (float)(sum - sumB) / (float)wF;
        float var = (float)wB * (float)wF * (mB - mF) * (mB - mF);
        if (var > max_var) {
            max_var = var;
            threshold = (uint8_t)t;
        }
    }
    return threshold;
}

/* Zhang-Suen thinning (simplified single pass) */
static void fp_thin_binary(uint8_t *bin, int32_t w, int32_t h) {
    uint8_t *tmp = (uint8_t *)malloc((size_t)(w * h));
    if (!tmp) return;

    for (int pass = 0; pass < 10; pass++) {
        memcpy(tmp, bin, (size_t)(w * h));
        int32_t changed = 0;
        for (int32_t y = 1; y < h - 1; y++) {
            for (int32_t x = 1; x < w - 1; x++) {
                if (!tmp[y * w + x]) continue;
                int32_t p2 = tmp[(y-1)*w+x] ? 1 : 0;
                int32_t p3 = tmp[(y-1)*w+(x+1)] ? 1 : 0;
                int32_t p4 = tmp[y*w+(x+1)] ? 1 : 0;
                int32_t p5 = tmp[(y+1)*w+(x+1)] ? 1 : 0;
                int32_t p6 = tmp[(y+1)*w+x] ? 1 : 0;
                int32_t p7 = tmp[(y+1)*w+(x-1)] ? 1 : 0;
                int32_t p8 = tmp[y*w+(x-1)] ? 1 : 0;
                int32_t p9 = tmp[(y-1)*w+(x-1)] ? 1 : 0;
                int32_t B = p2+p3+p4+p5+p6+p7+p8+p9;
                int32_t A = 0;
                int32_t n[9] = {p2,p3,p4,p5,p6,p7,p8,p9,p2};
                for (int32_t i = 0; i < 8; i++) {
                    if (!n[i] && n[i+1]) A++;
                }
                if (B >= 2 && B <= 6 && A == 1 &&
                    (!p2 || !p4 || !p6) && (!p4 || !p6 || !p8)) {
                    bin[y * w + x] = 0;
                    changed = 1;
                }
            }
        }
        if (!changed) break;
    }
    free(tmp);
}

/* Crossing number minutiae detection on thinned binary image */
static int32_t fp_detect_minutiae_cn(
    const uint8_t *thin, int32_t w, int32_t h,
    FpMinutia *out, int32_t max_out) {

    int32_t count = 0;

    for (int32_t y = 2; y < h - 2; y++) {
        for (int32_t x = 2; x < w - 2; x++) {
            if (!thin[y * w + x]) continue;

            int32_t p[8];
            p[0] = thin[(y-1)*w+x] ? 1 : 0;
            p[1] = thin[(y-1)*w+(x+1)] ? 1 : 0;
            p[2] = thin[y*w+(x+1)] ? 1 : 0;
            p[3] = thin[(y+1)*w+(x+1)] ? 1 : 0;
            p[4] = thin[(y+1)*w+x] ? 1 : 0;
            p[5] = thin[(y+1)*w+(x-1)] ? 1 : 0;
            p[6] = thin[y*w+(x-1)] ? 1 : 0;
            p[7] = thin[(y-1)*w+(x-1)] ? 1 : 0;

            int32_t cn = 0;
            for (int32_t i = 0; i < 8; i++) {
                int32_t j = (i + 1) % 8;
                if (p[i] == 0 && p[j] == 1) cn++;
            }

            if (cn == 1 || cn == 3) {
                if (count >= max_out) break;
                out[count].x = x;
                out[count].y = y;
                out[count].type = (cn == 1) ? FP_MINUTIA_RIDGE_ENDING : FP_MINUTIA_BIFURCATION;
                out[count].direction = (int32_t)((float)(cn % 8) * 450.0f);
                out[count].reliability = (cn == 1) ? 0.8 : 0.7;
                count++;
            }
        }
    }

    return count;
}

int32_t fp_extract_minutiae(
    const uint8_t *grayscale_img, int32_t width, int32_t height,
    int32_t ppi,
    FpMinutia *out_minutiae, int32_t max_minutiae,
    int32_t *out_num_minutiae) {

    if (!grayscale_img || !out_minutiae || !out_num_minutiae ||
        width < 32 || height < 32 || max_minutiae <= 0) {
        return FP_ERR_INVALID_INPUT;
    }

    (void)ppi;

    int32_t n = width * height;
    uint8_t *norm = (uint8_t *)malloc((size_t)n);
    uint8_t *bin = (uint8_t *)malloc((size_t)n);
    int16_t *gx = (int16_t *)calloc((size_t)n, sizeof(int16_t));
    int16_t *gy = (int16_t *)calloc((size_t)n, sizeof(int16_t));
    if (!norm || !bin || !gx || !gy) {
        free(norm); free(bin); free(gx); free(gy);
        return FP_ERR_OUT_OF_MEMORY;
    }

    fp_normalize_illumination(grayscale_img, width, height, norm);
    fp_sobel(norm, width, height, gx, gy);

    uint8_t thresh = fp_otsu_threshold(norm, n);
    for (int32_t i = 0; i < n; i++) bin[i] = (norm[i] > thresh) ? 255 : 0;

    fp_thin_binary(bin, width, height);

    /* Convert thinned ridges to binary 0/1 */
    for (int32_t i = 0; i < n; i++) bin[i] = (bin[i] > 0) ? 1 : 0;

    *out_num_minutiae = fp_detect_minutiae_cn(bin, width, height, out_minutiae, max_minutiae);

    free(norm);
    free(bin);
    free(gx);
    free(gy);

    return (*out_num_minutiae > 0) ? FP_OK : FP_ERR_PROCESSING_FAILED;
}
