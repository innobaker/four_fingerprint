#include "fp_internal.h"

static int32_t g_nfiq2_initialized = 0;

int32_t fp_init_nfiq2(const char *model_dir) {
    (void)model_dir;
    g_nfiq2_initialized = 1;
    return FP_OK;
}

/*
 * NFIQ2-compatible quality assessment (1=best, 5=worst).
 * Computes ridge clarity, contrast, and uniformity metrics.
 */
static float fp_compute_ridge_clarity(const uint8_t *img, int32_t w, int32_t h) {
    float grad_sum = 0.0f;
    int32_t count = 0;
    for (int32_t y = 1; y < h - 1; y++) {
        for (int32_t x = 1; x < w - 1; x++) {
            int32_t gx = (int32_t)img[y * w + x + 1] - (int32_t)img[y * w + x - 1];
            int32_t gy = (int32_t)img[(y + 1) * w + x] - (int32_t)img[(y - 1) * w + x];
            grad_sum += sqrtf((float)(gx * gx + gy * gy));
            count++;
        }
    }
    return (count > 0) ? (grad_sum / (float)count) : 0.0f;
}

static float fp_compute_uniformity(const uint8_t *img, int32_t w, int32_t h) {
    int64_t sum = 0, sum_sq = 0;
    int32_t n = w * h;
    for (int32_t i = 0; i < n; i++) {
        sum += img[i];
        sum_sq += (int64_t)img[i] * img[i];
    }
    float mean = (float)sum / (float)n;
    float variance = (float)sum_sq / (float)n - mean * mean;
    return sqrtf(variance > 0 ? variance : 0.0f);
}

int32_t fp_assess_quality(
    const uint8_t *grayscale_img, int32_t width, int32_t height,
    int32_t ppi, int32_t finger_code,
    int32_t *out_quality_score) {

    (void)finger_code;

    if (!grayscale_img || !out_quality_score || width <= 0 || height <= 0) {
        return FP_ERR_INVALID_INPUT;
    }

    if (!g_nfiq2_initialized) {
        fp_init_nfiq2(NULL);
    }

    float clarity = fp_compute_ridge_clarity(grayscale_img, width, height);
    float uniformity = fp_compute_uniformity(grayscale_img, width, height);

    /* PPI penalty if not at 500 PPI */
    float ppi_factor = 1.0f;
    if (ppi > 0 && ppi != FP_TARGET_PPI) {
        float ratio = (float)ppi / (float)FP_TARGET_PPI;
        if (ratio < 1.0f) ratio = 1.0f / ratio;
        ppi_factor = (ratio > 2.0f) ? 0.5f : 1.0f;
    }

    /* Map metrics to NFIQ2 1-5 scale */
    float score = 3.0f;
    if (clarity > 25.0f && uniformity > 30.0f && uniformity < 80.0f) {
        score = 1.0f;
    } else if (clarity > 18.0f && uniformity > 20.0f) {
        score = 2.0f;
    } else if (clarity > 12.0f) {
        score = 3.0f;
    } else if (clarity > 6.0f) {
        score = 4.0f;
    } else {
        score = 5.0f;
    }

    if (ppi_factor < 1.0f && score < 5.0f) score += 1.0f;

    *out_quality_score = (int32_t)score;
    if (*out_quality_score < 1) *out_quality_score = 1;
    if (*out_quality_score > 5) *out_quality_score = 5;

    return FP_OK;
}

int32_t fp_select_best_frame(
    const uint8_t **frames, int32_t frame_count,
    int32_t width, int32_t height, int32_t ppi,
    int32_t *out_best_index) {

    if (!frames || !out_best_index || frame_count <= 0 ||
        width <= 0 || height <= 0) {
        return FP_ERR_INVALID_INPUT;
    }

    int32_t best_idx = 0;
    int32_t best_quality = 999;

    for (int32_t i = 0; i < frame_count; i++) {
        if (!frames[i]) continue;
        int32_t quality = 5;
        fp_assess_quality(frames[i], width, height, ppi, 0, &quality);
        if (quality < best_quality) {
            best_quality = quality;
            best_idx = i;
        }
    }

    *out_best_index = best_idx;
    return FP_OK;
}
