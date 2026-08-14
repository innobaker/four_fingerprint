#include "fp_internal.h"

int32_t fp_assess_quality(
    const uint8_t *grayscale_img, int32_t width, int32_t height,
    int32_t ppi, int32_t finger_code,
    int32_t *out_quality_score) {

    if (!grayscale_img || !out_quality_score || width <= 0 || height <= 0) {
        return FP_ERR_INVALID_INPUT;
    }

    return fp_nfiq2_assess_quality(grayscale_img, width, height, ppi,
                                   finger_code, out_quality_score);
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
    int32_t best_quality = FP_NFIQ2_MIN_SCORE - 1;

    for (int32_t i = 0; i < frame_count; i++) {
        if (!frames[i]) continue;
        int32_t quality = 0;
        if (fp_assess_quality(frames[i], width, height, ppi, 0, &quality) == FP_OK) {
            if (quality > best_quality) {
                best_quality = quality;
                best_idx = i;
            }
        }
    }

    *out_best_index = best_idx;
    return FP_OK;
}
