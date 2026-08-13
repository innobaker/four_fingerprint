#include "fp_internal.h"

static int32_t fp_angle_diff(int32_t a, int32_t b) {
    int32_t diff = abs(a - b);
    if (diff > 1800) diff = 3600 - diff;
    return diff;
}

static int32_t fp_minutia_distance(const FpMinutia *a, const FpMinutia *b) {
    int32_t dx = a->x - b->x;
    int32_t dy = a->y - b->y;
    return (int32_t)sqrtf((float)(dx * dx + dy * dy));
}

/*
 * BOZORTH3-inspired minutiae matching.
 * Recalibrated threshold for contactless captures: FP_MATCH_THRESHOLD (25).
 */
int32_t fp_match_templates(
    const FpMinutia *probe, int32_t probe_count,
    const FpMinutia *gallery, int32_t gallery_count,
    int32_t *out_match_score) {

    if (!probe || !gallery || !out_match_score ||
        probe_count <= 0 || gallery_count <= 0) {
        return FP_ERR_INVALID_INPUT;
    }

    int32_t score = 0;
    int32_t matched_gallery[200];
    memset(matched_gallery, 0, sizeof(matched_gallery));
    int32_t max_g = gallery_count < 200 ? gallery_count : 200;

    for (int32_t i = 0; i < probe_count; i++) {
        int32_t best_j = -1;
        int32_t best_dist = 999999;

        for (int32_t j = 0; j < max_g; j++) {
            if (matched_gallery[j]) continue;
            if (probe[i].type != gallery[j].type) continue;

            int32_t dist = fp_minutia_distance(&probe[i], &gallery[j]);
            int32_t angle_diff = fp_angle_diff(probe[i].direction, gallery[j].direction);

            if (dist < 15 && angle_diff < 300) {
                if (dist < best_dist) {
                    best_dist = dist;
                    best_j = j;
                }
            }
        }

        if (best_j >= 0) {
            matched_gallery[best_j] = 1;
            score += 10;
            if (best_dist < 8) score += 5;
        }
    }

    *out_match_score = score;
    return FP_OK;
}

int32_t fp_is_match(int32_t match_score) {
    return match_score >= FP_MATCH_THRESHOLD;
}
