#ifndef FP_INTERNAL_H
#define FP_INTERNAL_H

#include "four_fingerprint.h"
#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

#define FP_TARGET_PPI 500
#define FP_VERSION_STRING "1.0.0"

/* MediaPipe hand landmark count (21 points x 3 coords) */
#define FP_LANDMARK_COUNT 21
#define FP_LANDMARK_DIM 3

/* Anthropometric finger width priors (mm) at proximal interphalangeal joint */
#define FP_INDEX_FINGER_WIDTH_MM 14.5
#define FP_MIDDLE_FINGER_WIDTH_MM 15.0
#define FP_RING_FINGER_WIDTH_MM 13.5
#define FP_LITTLE_FINGER_WIDTH_MM 12.0
#define FP_THUMB_WIDTH_MM 16.5

/* BOZORTH3 recalibrated threshold for contactless captures */
#define FP_MATCH_THRESHOLD 25

/* Burst capture */
#define FP_BURST_FRAME_COUNT 8

typedef struct {
    int32_t x;
    int32_t y;
    int32_t w;
    int32_t h;
} FpRect;

typedef struct {
    uint8_t *data;
    int32_t width;
    int32_t height;
} FpGrayImage;

/* Utility functions */
static inline int32_t fp_clamp_i32(int32_t v, int32_t lo, int32_t hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

static inline float fp_clamp_f(float v, float lo, float hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

static inline float fp_dist(float x1, float y1, float x2, float y2) {
    float dx = x2 - x1;
    float dy = y2 - y1;
    return sqrtf(dx * dx + dy * dy);
}

static inline float fp_landmark_x(const float *landmarks, int idx, int img_w) {
    return landmarks[idx * FP_LANDMARK_DIM] * (float)img_w;
}

static inline float fp_landmark_y(const float *landmarks, int idx, int img_h) {
    return landmarks[idx * FP_LANDMARK_DIM + 1] * (float)img_h;
}

int32_t fp_rgb_to_gray(const uint8_t *rgb, int32_t w, int32_t h, uint8_t *gray);
int32_t fp_resize_gray(const uint8_t *src, int32_t sw, int32_t sh,
                       uint8_t *dst, int32_t dw, int32_t dh);
int32_t fp_crop_gray(const uint8_t *src, int32_t sw, int32_t sh,
                     int32_t x, int32_t y, int32_t cw, int32_t ch,
                     uint8_t *dst);
float fp_finger_width_mm(int32_t finger_code);
int32_t fp_landmark_finger_base(int32_t finger_code);
int32_t fp_landmark_finger_tip(int32_t finger_code);

#ifdef __cplusplus
}
#endif

#endif /* FP_INTERNAL_H */
