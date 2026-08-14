#include "fp_internal.h"

/* ============================================================================
 * NFIQ2 Wrapper
 *
 * When FP_USE_REAL_NFIQ2 is defined, this wrapper calls the actual NFIQ2
 * library (NIST Fingerprint Image Quality 2) which returns a unified quality
 * score on the 0-100 scale per ISO/IEC 29794-4.
 *
 * Otherwise it falls back to the built-in heuristic quality assessment.
 *
 * Building real NFIQ2 requires:
 *   - OpenCV 4.x
 *   - FingerJetFX OSE (libFRFXLL)
 *   - digestpp
 *   - C++11 compiler
 *
 * The NFIQ2 superbuild CMake is in third_party/nfiq2/.
 * ============================================================================ */

#ifdef FP_USE_REAL_NFIQ2

#include <nfiq2/nfiq2.hpp>

static NFIQ2::Algorithm *g_nfiq2_algo = NULL;
static int g_nfiq2_initialized = 0;

int32_t fp_nfiq2_init(const char *model_dir) {
    if (g_nfiq2_initialized) return FP_OK;

    try {
        if (model_dir && model_dir[0] != '\0') {
            NFIQ2::ModelInfo info(model_dir);
            g_nfiq2_algo = new NFIQ2::Algorithm(info);
        } else {
            g_nfiq2_algo = new NFIQ2::Algorithm();
        }

        if (!g_nfiq2_algo->isInitialized()) {
            delete g_nfiq2_algo;
            g_nfiq2_algo = NULL;
            return FP_ERR_PROCESSING_FAILED;
        }
        g_nfiq2_initialized = 1;
        return FP_OK;
    } catch (...) {
        return FP_ERR_PROCESSING_FAILED;
    }
}

void fp_nfiq2_cleanup(void) {
    if (g_nfiq2_algo) {
        delete g_nfiq2_algo;
        g_nfiq2_algo = NULL;
    }
    g_nfiq2_initialized = 0;
}

int32_t fp_nfiq2_assess_quality(
    const uint8_t *grayscale_img, int32_t width, int32_t height,
    int32_t ppi, int32_t finger_code, int32_t *out_quality_score) {

    (void)finger_code;

    if (!g_nfiq2_initialized) {
        fp_nfiq2_init(NULL);
    }
    if (!g_nfiq2_algo || !grayscale_img || !out_quality_score ||
        width <= 0 || height <= 0) {
        return FP_ERR_INVALID_INPUT;
    }

    try {
        NFIQ2::FingerprintImageData img(
            grayscale_img,
            (uint32_t)(width * height),
            (uint32_t)width,
            (uint32_t)height,
            (uint8_t)finger_code,
            (uint16_t)(ppi > 0 ? ppi : FP_TARGET_PPI)
        );

        unsigned int score = g_nfiq2_algo->computeUnifiedQualityScore(img);
        if (score > FP_NFIQ2_MAX_SCORE) score = FP_NFIQ2_MAX_SCORE;
        if (score < FP_NFIQ2_MIN_SCORE) score = FP_NFIQ2_MIN_SCORE;
        *out_quality_score = (int32_t)score;
        return FP_OK;
    } catch (...) {
        return FP_ERR_PROCESSING_FAILED;
    }
}

#else /* !FP_USE_REAL_NFIQ2 — fallback to heuristic */

int32_t fp_nfiq2_init(const char *model_dir) {
    (void)model_dir;
    return FP_OK;
}

void fp_nfiq2_cleanup(void) {}

int32_t fp_nfiq2_assess_quality(
    const uint8_t *grayscale_img, int32_t width, int32_t height,
    int32_t ppi, int32_t finger_code, int32_t *out_quality_score) {
    return fp_assess_quality(grayscale_img, width, height, ppi, finger_code,
                             out_quality_score);
}

#endif /* FP_USE_REAL_NFIQ2 */
