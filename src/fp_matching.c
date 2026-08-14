#include "fp_internal.h"

int32_t fp_match_templates(
    const FpMinutia *probe, int32_t probe_count,
    const FpMinutia *gallery, int32_t gallery_count,
    int32_t *out_match_score) {

    if (!probe || !gallery || !out_match_score ||
        probe_count <= 0 || gallery_count <= 0) {
        return FP_ERR_INVALID_INPUT;
    }

    return fp_nbis_match_templates(probe, probe_count, gallery, gallery_count,
                                   out_match_score);
}

int32_t fp_is_match(int32_t match_score) {
    return match_score >= FP_MATCH_THRESHOLD;
}