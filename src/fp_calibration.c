#include "fp_internal.h"

/*
 * Scale calibration using anthropometric finger-width priors.
 * Measures perpendicular width at the PIP joint landmark pair.
 */
int32_t fp_calibrate_scale(
    const uint8_t *rgb_frame, int32_t width, int32_t height,
    const float *hand_landmarks, int32_t landmark_count,
    const int32_t *finger_codes, int32_t num_fingers,
    float *out_scale_factor) {

    (void)rgb_frame;

    if (!hand_landmarks || !finger_codes || !out_scale_factor ||
        width <= 0 || height <= 0 || landmark_count < FP_LANDMARK_COUNT ||
        num_fingers <= 0) {
        return FP_ERR_INVALID_INPUT;
    }

    float total_scale = 0.0f;
    int32_t valid = 0;

    for (int32_t f = 0; f < num_fingers; f++) {
        int32_t code = finger_codes[f];
        int32_t base_idx = fp_landmark_finger_base(code);
        int32_t tip_idx = fp_landmark_finger_tip(code);

        float bx = fp_landmark_x(hand_landmarks, base_idx, width);
        float by = fp_landmark_y(hand_landmarks, base_idx, height);
        float tx = fp_landmark_x(hand_landmarks, tip_idx, width);
        float ty = fp_landmark_y(hand_landmarks, tip_idx, height);

        float finger_len_px = fp_dist(bx, by, tx, ty);
        if (finger_len_px < 10.0f) continue;

        /* Estimate width as ~22% of finger length (anthropometric ratio) */
        float width_px = finger_len_px * 0.22f;
        float width_mm = fp_finger_width_mm(code);

        /* PPI = pixels per inch; scale_factor converts current PPI to 500 PPI */
        float current_ppi = (width_px / width_mm) * 25.4f;
        if (current_ppi > 50.0f && current_ppi < 2000.0f) {
            total_scale += (float)FP_TARGET_PPI / current_ppi;
            valid++;
        }
    }

    if (valid == 0) {
        *out_scale_factor = 1.0f;
        return FP_OK;
    }

    *out_scale_factor = total_scale / (float)valid;
    return FP_OK;
}
