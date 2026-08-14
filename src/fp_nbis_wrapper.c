#include "fp_internal.h"

#ifdef __cplusplus
extern "C" {
#endif

#include <lfs.h>
#include <bozorth.h>

#ifdef __cplusplus
}
#endif

#ifndef FP_USE_REAL_NBIS

int32_t fp_nbis_init(void) {
    return FP_OK;
}

void fp_nbis_cleanup(void) {
}

int32_t fp_nbis_extract_minutiae(
    const uint8_t *grayscale_img, int32_t width, int32_t height,
    int32_t ppi, FpMinutia *out_minutiae, int32_t max_minutiae,
    int32_t *out_num_minutiae) {

    if (!grayscale_img || !out_minutiae || !out_num_minutiae ||
        width < 16 || height < 16 || max_minutiae <= 0) {
        return FP_ERR_INVALID_INPUT;
    }

    int32_t count = 0;
    int32_t step = 8;
    for (int32_t y = step; y < height - step && count < max_minutiae; y += step) {
        for (int32_t x = step; x < width - step && count < max_minutiae; x += step) {
            int gx = (int)grayscale_img[y * width + x + 1] - (int)grayscale_img[y * width + x - 1];
            int gy = (int)grayscale_img[(y + 1) * width + x] - (int)grayscale_img[(y - 1) * width + x];
            int mag = gx * gx + gy * gy;
            if (mag > 400) {
                out_minutiae[count].x = x;
                out_minutiae[count].y = y;
                out_minutiae[count].direction = (int16_t)(atan2f((float)gy, (float)gx) * 180.0f / M_PI * 10);
                out_minutiae[count].type = 1;
                out_minutiae[count].reliability = (uint8_t)(mag > 1600 ? 90 : 60);
                count++;
            }
        }
    }

    *out_num_minutiae = count;
    return count > 0 ? FP_OK : FP_ERR_PROCESSING_FAILED;
}

int32_t fp_nbis_match_templates(
    const FpMinutia *probe, int32_t probe_count,
    const FpMinutia *gallery, int32_t gallery_count,
    int32_t *out_match_score) {

    if (!probe || !gallery || !out_match_score ||
        probe_count <= 0 || gallery_count <= 0) {
        return FP_ERR_INVALID_INPUT;
    }

    int32_t matches = 0;
    for (int32_t i = 0; i < probe_count && i < 40; i++) {
        for (int32_t j = 0; j < gallery_count && j < 40; j++) {
            int dx = probe[i].x - gallery[j].x;
            int dy = probe[i].y - gallery[j].y;
            int dist = dx * dx + dy * dy;
            if (dist < 400) {
                int dd = abs(probe[i].direction - gallery[j].direction);
                if (dd > 180) dd = 360 - dd;
                if (dd < 45) {
                    matches++;
                }
            }
        }
    }

    *out_match_score = matches * 5;
    return FP_OK;
}

#else

static LFSPARMS g_lfsparms;
static int g_nbis_initialized = 0;

int32_t fp_nbis_init(void) {
    if (g_nbis_initialized) return FP_OK;
    memset(&g_lfsparms, 0, sizeof(g_lfsparms));
    g_lfsparms.blocksize = 8;
    g_lfsparms.windowsize = 24;
    g_lfsparms.windowoffset = 8;
    g_lfsparms.num_directions = 16;
    g_lfsparms.start_dir_angle = M_PI / 2.0;
    g_nbis_initialized = 1;
    return FP_OK;
}

void fp_nbis_cleanup(void) {
    g_nbis_initialized = 0;
}

static int fp_minutiae_to_xyt(const FpMinutia *in, int count,
                               struct xyt_struct *out) {
    if (!in || !out || count <= 0) return FP_ERR_INVALID_INPUT;
    memset(out, 0, sizeof(*out));
    out->nrows = count < MAX_BOZORTH_MINUTIAE ? count : MAX_BOZORTH_MINUTIAE;
    for (int i = 0; i < out->nrows; i++) {
        out->xcol[i] = in[i].x;
        out->ycol[i] = in[i].y;
        out->thetacol[i] = in[i].direction / 10;
    }
    return FP_OK;
}

int32_t fp_nbis_extract_minutiae(
    const uint8_t *grayscale_img, int32_t width, int32_t height,
    int32_t ppi, FpMinutia *out_minutiae, int32_t max_minutiae,
    int32_t *out_num_minutiae) {

    MINUTIAE *minutiae = NULL;
    int *quality_map = NULL, *direction_map = NULL, *low_contrast_map = NULL;
    int *high_curve_map = NULL;
    int qm_len = 0, dm_len = 0, lcm_len = 0, hcm_len = 0;
    unsigned char *idata = NULL;
    int idata_len = 0;

    int ret = lfs_detect_minutiae_V2(
        &minutiae, &quality_map, &direction_map, &low_contrast_map,
        &high_curve_map, &qm_len, &dm_len, &lcm_len, &hcm_len,
        &idata, &idata_len, width, height, &g_lfsparms
    );

    if (ret != 0 || minutiae == NULL || minutiae->num <= 0) {
        free_minutiae(minutiae);
        return FP_ERR_PROCESSING_FAILED;
    }

    int count = minutiae->num < max_minutiae ? minutiae->num : max_minutiae;
    for (int i = 0; i < count; i++) {
        MINUTIA *m = minutiae->list[i];
        out_minutiae[i].x = m->x;
        out_minutiae[i].y = m->y;
        out_minutiae[i].direction = m->direction * 10;
        out_minutiae[i].type = m->type;
        out_minutiae[i].reliability = m->reliability;
    }

    *out_num_minutiae = count;
    free_minutiae(minutiae);
    return FP_OK;
}

int32_t fp_nbis_match_templates(
    const FpMinutia *probe, int32_t probe_count,
    const FpMinutia *gallery, int32_t gallery_count,
    int32_t *out_match_score) {

    struct xyt_struct probe_xyt, gallery_xyt;
    if (fp_minutiae_to_xyt(probe, probe_count, &probe_xyt) != FP_OK ||
        fp_minutiae_to_xyt(gallery, gallery_count, &gallery_xyt) != FP_OK) {
        return FP_ERR_INVALID_INPUT;
    }

    if (bozorth_probe_init(&probe_xyt) != 0) return FP_ERR_PROCESSING_FAILED;
    if (bozorth_gallery_init(&gallery_xyt) != 0) return FP_ERR_PROCESSING_FAILED;

    int score = bozorth_to_gallery(0, &probe_xyt, &gallery_xyt);
    if (score < 0) score = 0;

    *out_match_score = score;
    return FP_OK;
}

#endif
