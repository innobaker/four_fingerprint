#include "fp_internal.h"

/*
 * YCrCb skin-color segmentation with landmark-guided ROI refinement.
 * Produces per-finger bounding boxes and a combined mask.
 */
static void fp_ycrcb_skin_mask(const uint8_t *rgb, int32_t w, int32_t h,
                                 uint8_t *mask) {
    int32_t n = w * h;
    for (int32_t i = 0; i < n; i++) {
        int32_t r = rgb[i * 3];
        int32_t g = rgb[i * 3 + 1];
        int32_t b = rgb[i * 3 + 2];

        int32_t y  = ((66 * r + 129 * g + 25 * b + 128) >> 8) + 16;
        int32_t cb = ((-38 * r - 74 * g + 112 * b + 128) >> 8) + 128;
        int32_t cr = ((112 * r - 94 * g - 18 * b + 128) >> 8) + 128;

        int32_t is_skin = (y > 80 && cb >= 77 && cb <= 127 && cr >= 133 && cr <= 173);
        mask[i] = is_skin ? 255 : 0;
    }
}

static void fp_dilate_mask(uint8_t *mask, int32_t w, int32_t h, int32_t radius) {
    uint8_t *tmp = (uint8_t *)malloc((size_t)(w * h));
    if (!tmp) return;
    memcpy(tmp, mask, (size_t)(w * h));

    for (int32_t y = 0; y < h; y++) {
        for (int32_t x = 0; x < w; x++) {
            int32_t max_val = 0;
            for (int32_t dy = -radius; dy <= radius; dy++) {
                for (int32_t dx = -radius; dx <= radius; dx++) {
                    int32_t nx = x + dx;
                    int32_t ny = y + dy;
                    if (nx >= 0 && nx < w && ny >= 0 && ny < h) {
                        if (tmp[ny * w + nx] > max_val) max_val = tmp[ny * w + nx];
                    }
                }
            }
            mask[y * w + x] = (uint8_t)max_val;
        }
    }
    free(tmp);
}

int32_t fp_segment_fingers(
    const uint8_t *grayscale_img, int32_t width, int32_t height,
    const float *hand_landmarks, int32_t landmark_count,
    uint8_t *out_mask,
    FpBoundingBox *out_boxes, int32_t max_fingers,
    int32_t *out_num_fingers) {

    if (!grayscale_img || !hand_landmarks || !out_mask || !out_boxes ||
        !out_num_fingers || width <= 0 || height <= 0 ||
        landmark_count < FP_LANDMARK_COUNT || max_fingers <= 0) {
        return FP_ERR_INVALID_INPUT;
    }

    /* Build RGB from grayscale for skin detection */
    int32_t n = width * height;
    uint8_t *rgb = (uint8_t *)malloc((size_t)(n * 3));
    if (!rgb) return FP_ERR_OUT_OF_MEMORY;

    for (int32_t i = 0; i < n; i++) {
        rgb[i * 3] = grayscale_img[i];
        rgb[i * 3 + 1] = grayscale_img[i];
        rgb[i * 3 + 2] = grayscale_img[i];
    }

    fp_ycrcb_skin_mask(rgb, width, height, out_mask);
    fp_dilate_mask(out_mask, width, height, 2);
    free(rgb);

    int32_t count = 0;
    int32_t codes_to_use[] = {
        FP_FINGER_RIGHT_INDEX, FP_FINGER_RIGHT_MIDDLE,
        FP_FINGER_RIGHT_RING, FP_FINGER_RIGHT_LITTLE
    };
    int32_t num_codes = 4;

    if (max_fingers >= 10) num_codes = 4;

    for (int32_t f = 0; f < num_codes && count < max_fingers; f++) {
        int32_t code = codes_to_use[f];
        int32_t base = fp_landmark_finger_base(code);
        int32_t tip = fp_landmark_finger_tip(code);
        int32_t mid = (base + tip) / 2;

        float bx = fp_landmark_x(hand_landmarks, base, width);
        float by = fp_landmark_y(hand_landmarks, base, height);
        float tx = fp_landmark_x(hand_landmarks, tip, width);
        float ty = fp_landmark_y(hand_landmarks, tip, height);
        float mx = fp_landmark_x(hand_landmarks, mid, width);
        float my = fp_landmark_y(hand_landmarks, mid, height);

        float len = fp_dist(bx, by, tx, ty);
        float half_w = len * 0.15f;
        if (half_w < 8.0f) half_w = 8.0f;

        float cx = (bx + tx) / 2.0f;
        float cy = (by + ty) / 2.0f;
        (void)mx; (void)my;

        int32_t x0 = (int32_t)(cx - half_w);
        int32_t y0 = (int32_t)(cy - len * 0.45f);
        int32_t x1 = (int32_t)(cx + half_w);
        int32_t y1 = (int32_t)(cy + len * 0.45f);

        x0 = fp_clamp_i32(x0, 0, width - 1);
        y0 = fp_clamp_i32(y0, 0, height - 1);
        x1 = fp_clamp_i32(x1, x0 + 1, width);
        y1 = fp_clamp_i32(y1, y0 + 1, height);

        out_boxes[count].min_x = x0;
        out_boxes[count].min_y = y0;
        out_boxes[count].max_x = x1;
        out_boxes[count].max_y = y1;
        count++;
    }

    *out_num_fingers = count;
    return FP_OK;
}
