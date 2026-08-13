#include "fp_internal.h"

/*
 * FFT-based liveness detection.
 * Real skin exhibits characteristic frequency spectrum; prints/screens differ.
 */
static void fp_fft_magnitude(const uint8_t *block, int32_t n, float *magnitude) {
    /* Simplified DFT for small block (64 samples) */
    for (int32_t k = 0; k < n / 2; k++) {
        float re = 0.0f, im = 0.0f;
        for (int32_t t = 0; t < n; t++) {
            float angle = -2.0f * 3.14159265f * k * t / (float)n;
            re += (float)block[t] * cosf(angle);
            im += (float)block[t] * sinf(angle);
        }
        magnitude[k] = sqrtf(re * re + im * im);
    }
}

int32_t fp_check_liveness(
    const uint8_t *grayscale_img, int32_t width, int32_t height,
    const float *hand_landmarks, int32_t landmark_count,
    int32_t *out_is_live) {

    if (!grayscale_img || !hand_landmarks || !out_is_live ||
        width <= 0 || height <= 0 || landmark_count < FP_LANDMARK_COUNT) {
        return FP_ERR_INVALID_INPUT;
    }

    /* Sample region around index finger tip */
    int32_t tip = 8;
    int32_t cx = (int32_t)fp_landmark_x(hand_landmarks, tip, width);
    int32_t cy = (int32_t)fp_landmark_y(hand_landmarks, tip, height);
    int32_t block_size = 64;
    int32_t half = block_size / 2;

    int32_t x0 = fp_clamp_i32(cx - half, 0, width - block_size);
    int32_t y0 = fp_clamp_i32(cy - half, 0, height - block_size);

    uint8_t block[64];
    for (int32_t i = 0; i < block_size; i++) {
        block[i] = grayscale_img[(y0 + i / 8) * width + (x0 + i % 8)];
    }

    float magnitude[32];
    fp_fft_magnitude(block, block_size, magnitude);

    /* Live skin: mid-frequency energy ratio */
    float low_energy = 0.0f, mid_energy = 0.0f, high_energy = 0.0f;
    for (int32_t k = 1; k < 8; k++) low_energy += magnitude[k];
    for (int32_t k = 8; k < 16; k++) mid_energy += magnitude[k];
    for (int32_t k = 16; k < 32; k++) high_energy += magnitude[k];

    float total = low_energy + mid_energy + high_energy;
    if (total < 1.0f) {
        *out_is_live = FP_LIVENESS_UNKNOWN;
        return FP_OK;
    }

    float mid_ratio = mid_energy / total;
    float high_ratio = high_energy / total;

    /* Printed/screen spoofs tend to have lower mid-frequency content */
    if (mid_ratio > 0.25f && high_ratio < 0.35f) {
        *out_is_live = FP_LIVENESS_LIVE;
    } else if (mid_ratio < 0.15f || high_ratio > 0.45f) {
        *out_is_live = FP_LIVENESS_NOT_LIVE;
    } else {
        *out_is_live = FP_LIVENESS_LIVE;
    }

    return FP_OK;
}
