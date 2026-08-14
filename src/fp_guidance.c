#include "fp_internal.h"

int32_t fp_assess_guidance(
    const uint8_t *rgb_frame, int32_t width, int32_t height,
    const float *hand_landmarks, int32_t landmark_count,
    const int32_t *finger_codes, int32_t num_fingers,
    FpGuidanceResult *out_guidance,
    FpGuidanceRect *out_rects, int32_t max_rects) {

    if (!rgb_frame || !hand_landmarks || !finger_codes ||
        !out_guidance || width <= 0 || height <= 0) {
        return FP_ERR_INVALID_INPUT;
    }

    memset(out_guidance, 0, sizeof(FpGuidanceResult));

    float palm_span = 0.0f;
    float min_x = 1.0f, max_x = 0.0f;
    float min_y = 1.0f, max_y = 0.0f;
    int detected = 0;

    for (int32_t i = 0; i < landmark_count && i < 21; i++) {
        float lx = hand_landmarks[i * 3];
        float ly = hand_landmarks[i * 3 + 1];
        if (lx < min_x) min_x = lx;
        if (lx > max_x) max_x = lx;
        if (ly < min_y) min_y = ly;
        if (ly > max_y) max_y = ly;
    }

    palm_span = max_x - min_x;

    if (palm_span < 0.12f) {
        out_guidance->hand_distance = 0;
        snprintf(out_guidance->message, sizeof(out_guidance->message),
                 "Move hand closer");
    } else if (palm_span > 0.55f) {
        out_guidance->hand_distance = 2;
        snprintf(out_guidance->message, sizeof(out_guidance->message),
                 "Move hand farther");
    } else {
        out_guidance->hand_distance = 1;
        snprintf(out_guidance->message, sizeof(out_guidance->message),
                 "Hold steady");
    }

    int32_t required = num_fingers < 4 ? num_fingers : 4;
    for (int32_t f = 0; f < required && f < num_fingers; f++) {
        float fx = hand_landmarks[(f + 5) * 3];
        float fy = hand_landmarks[(f + 5) * 3 + 1];
        if (fx > 0.05f && fy > 0.05f) detected++;
    }

    if (detected < 2 && num_fingers >= 4) {
        out_guidance->finger_alignment = 0;
        snprintf(out_guidance->message, sizeof(out_guidance->message),
                 "Show all %d fingers", num_fingers);
    } else if (detected < required) {
        out_guidance->finger_alignment = 1;
        snprintf(out_guidance->message, sizeof(out_guidance->message),
                 "Show %d fingers", required);
    } else {
        out_guidance->finger_alignment = 2;
    }

    out_guidance->stability = 1;

    if (out_rects && max_rects > 0) {
        out_guidance->num_rects = 1;
        out_rects[0].x = 0.08f;
        out_rects[0].y = 0.12f;
        out_rects[0].width = 0.84f;
        out_rects[0].height = 0.66f;
        snprintf(out_rects[0].label, sizeof(out_rects[0].label), "Capture area");
        snprintf(out_rects[0].status, sizeof(out_rects[0].status), "tracking");
    }

    return FP_OK;
}
