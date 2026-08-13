#include "fp_internal.h"

/*
 * Cylindrical finger surface unwarping.
 * Maps elliptical cross-section to flat plane using cv.remap equivalent logic.
 */
int32_t fp_unwarp_cylindrical(
    const uint8_t *input_img, int32_t width, int32_t height,
    const FpBoundingBox *finger_roi,
    float finger_width_mm, float finger_length_mm,
    uint8_t *output_img, int32_t out_width, int32_t out_height,
    float *out_scale_factor) {

    if (!input_img || !finger_roi || !output_img || !out_scale_factor ||
        width <= 0 || height <= 0 || out_width <= 0 || out_height <= 0) {
        return FP_ERR_INVALID_INPUT;
    }

    int32_t roi_w = finger_roi->max_x - finger_roi->min_x;
    int32_t roi_h = finger_roi->max_y - finger_roi->min_y;
    if (roi_w <= 0 || roi_h <= 0) return FP_ERR_INVALID_INPUT;

    float aspect = finger_length_mm / finger_width_mm;
    (void)aspect;

    /* Cylinder radius derived from finger width */
    float radius_px = (float)roi_w / 2.0f;
    if (radius_px < 1.0f) radius_px = 1.0f;

    memset(output_img, 128, (size_t)(out_width * out_height));

    for (int32_t oy = 0; oy < out_height; oy++) {
        float v = (float)oy / (float)(out_height - 1);
        int32_t src_y = finger_roi->min_y + (int32_t)(v * (roi_h - 1));

        for (int32_t ox = 0; ox < out_width; ox++) {
            float u = (float)ox / (float)(out_width - 1);
            /* Map flat coordinate to cylindrical arc */
            float theta = (u - 0.5f) * 3.14159265f;
            float arc_x = radius_px * sinf(theta);
            float src_x_f = (float)finger_roi->min_x + (float)roi_w / 2.0f + arc_x;
            int32_t src_x = (int32_t)src_x_f;

            src_x = fp_clamp_i32(src_x, finger_roi->min_x, finger_roi->max_x - 1);
            src_y = fp_clamp_i32(src_y, finger_roi->min_y, finger_roi->max_y - 1);

            output_img[oy * out_width + ox] = input_img[src_y * width + src_x];
        }
    }

    float px_per_mm = (float)out_width / finger_width_mm;
    float current_ppi = px_per_mm * 25.4f;
    *out_scale_factor = (current_ppi > 0) ? ((float)FP_TARGET_PPI / current_ppi) : 1.0f;

    return FP_OK;
}
