#include "fp_internal.h"

int32_t fp_rgb_to_gray(const uint8_t *rgb, int32_t w, int32_t h, uint8_t *gray) {
    if (!rgb || !gray || w <= 0 || h <= 0) return FP_ERR_INVALID_INPUT;
    int32_t n = w * h;
    for (int32_t i = 0; i < n; i++) {
        int32_t r = rgb[i * 3];
        int32_t g = rgb[i * 3 + 1];
        int32_t b = rgb[i * 3 + 2];
        gray[i] = (uint8_t)((77 * r + 150 * g + 29 * b) >> 8);
    }
    return FP_OK;
}

int32_t fp_resize_gray(const uint8_t *src, int32_t sw, int32_t sh,
                       uint8_t *dst, int32_t dw, int32_t dh) {
    if (!src || !dst || sw <= 0 || sh <= 0 || dw <= 0 || dh <= 0) {
        return FP_ERR_INVALID_INPUT;
    }
    for (int32_t y = 0; y < dh; y++) {
        int32_t sy = (y * sh) / dh;
        for (int32_t x = 0; x < dw; x++) {
            int32_t sx = (x * sw) / dw;
            dst[y * dw + x] = src[sy * sw + sx];
        }
    }
    return FP_OK;
}

int32_t fp_crop_gray(const uint8_t *src, int32_t sw, int32_t sh,
                     int32_t x, int32_t y, int32_t cw, int32_t ch,
                     uint8_t *dst) {
    if (!src || !dst || cw <= 0 || ch <= 0) return FP_ERR_INVALID_INPUT;
    x = fp_clamp_i32(x, 0, sw - 1);
    y = fp_clamp_i32(y, 0, sh - 1);
    if (x + cw > sw) cw = sw - x;
    if (y + ch > sh) ch = sh - y;
    for (int32_t row = 0; row < ch; row++) {
        memcpy(dst + row * cw, src + (y + row) * sw + x, (size_t)cw);
    }
    return FP_OK;
}

float fp_finger_width_mm(int32_t finger_code) {
    switch (finger_code) {
        case FP_FINGER_RIGHT_INDEX:
        case FP_FINGER_LEFT_INDEX:
            return FP_INDEX_FINGER_WIDTH_MM;
        case FP_FINGER_RIGHT_MIDDLE:
        case FP_FINGER_LEFT_MIDDLE:
            return FP_MIDDLE_FINGER_WIDTH_MM;
        case FP_FINGER_RIGHT_RING:
        case FP_FINGER_LEFT_RING:
            return FP_RING_FINGER_WIDTH_MM;
        case FP_FINGER_RIGHT_LITTLE:
        case FP_FINGER_LEFT_LITTLE:
            return FP_LITTLE_FINGER_WIDTH_MM;
        case FP_FINGER_RIGHT_THUMB:
        case FP_FINGER_LEFT_THUMB:
            return FP_THUMB_WIDTH_MM;
        default:
            return FP_INDEX_FINGER_WIDTH_MM;
    }
}

int32_t fp_landmark_finger_base(int32_t finger_code) {
    switch (finger_code) {
        case FP_FINGER_RIGHT_THUMB:
        case FP_FINGER_LEFT_THUMB: return 2;
        case FP_FINGER_RIGHT_INDEX:
        case FP_FINGER_LEFT_INDEX: return 5;
        case FP_FINGER_RIGHT_MIDDLE:
        case FP_FINGER_LEFT_MIDDLE: return 9;
        case FP_FINGER_RIGHT_RING:
        case FP_FINGER_LEFT_RING: return 13;
        case FP_FINGER_RIGHT_LITTLE:
        case FP_FINGER_LEFT_LITTLE: return 17;
        default: return 5;
    }
}

int32_t fp_landmark_finger_tip(int32_t finger_code) {
    switch (finger_code) {
        case FP_FINGER_RIGHT_THUMB:
        case FP_FINGER_LEFT_THUMB: return 4;
        case FP_FINGER_RIGHT_INDEX:
        case FP_FINGER_LEFT_INDEX: return 8;
        case FP_FINGER_RIGHT_MIDDLE:
        case FP_FINGER_LEFT_MIDDLE: return 12;
        case FP_FINGER_RIGHT_RING:
        case FP_FINGER_LEFT_RING: return 16;
        case FP_FINGER_RIGHT_LITTLE:
        case FP_FINGER_LEFT_LITTLE: return 20;
        default: return 8;
    }
}
