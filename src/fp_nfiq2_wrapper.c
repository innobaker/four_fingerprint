#include "fp_internal.h"

#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

typedef void (*GetNfiq2VersionFn)(int *, int *, int *, const char **);
typedef const char *(*InitNfiq2Fn)(char **);
typedef int (*ComputeNfiq2ScoreFn)(int, const unsigned char *, int, int, int, int);

static void *g_nfiq2_handle = NULL;
static GetNfiq2VersionFn g_get_version = NULL;
static InitNfiq2Fn g_init = NULL;
static ComputeNfiq2ScoreFn g_compute_score = NULL;
static int g_nfiq2_initialized = 0;

static int32_t fp_nfiq2_load_library(void) {
    if (g_nfiq2_handle) return FP_OK;

    g_nfiq2_handle = dlopen("libNfiq2Api.so", RTLD_NOW);
    if (!g_nfiq2_handle) {
        return FP_ERR_PROCESSING_FAILED;
    }

    g_get_version = (GetNfiq2VersionFn)dlsym(g_nfiq2_handle, "GetNfiq2Version");
    g_init = (InitNfiq2Fn)dlsym(g_nfiq2_handle, "InitNfiq2");
    g_compute_score = (ComputeNfiq2ScoreFn)dlsym(g_nfiq2_handle, "ComputeNfiq2Score");

    if (!g_get_version || !g_init || !g_compute_score) {
        dlclose(g_nfiq2_handle);
        g_nfiq2_handle = NULL;
        return FP_ERR_PROCESSING_FAILED;
    }

    return FP_OK;
}

int32_t fp_nfiq2_init(const char *model_dir) {
    (void)model_dir;

    if (g_nfiq2_initialized) return FP_OK;

    int32_t ret = fp_nfiq2_load_library();
    if (ret != FP_OK) return ret;

    char *hash = NULL;
    const char *result = g_init(&hash);
    if (!result || !hash) {
        dlclose(g_nfiq2_handle);
        g_nfiq2_handle = NULL;
        return FP_ERR_PROCESSING_FAILED;
    }

    g_nfiq2_initialized = 1;
    return FP_OK;
}

void fp_nfiq2_cleanup(void) {
    if (g_nfiq2_handle) {
        dlclose(g_nfiq2_handle);
        g_nfiq2_handle = NULL;
    }
    g_nfiq2_initialized = 0;
}

int32_t fp_nfiq2_assess_quality(
    const uint8_t *grayscale_img, int32_t width, int32_t height,
    int32_t ppi, int32_t finger_code, int32_t *out_quality_score) {

    (void)finger_code;

    if (!grayscale_img || !out_quality_score ||
        width <= 0 || height <= 0) {
        return FP_ERR_INVALID_INPUT;
    }

    if (!g_nfiq2_initialized) {
        int32_t ret = fp_nfiq2_init(NULL);
        if (ret != FP_OK) {
            return ret;
        }
    }

    if (!g_compute_score) {
        return FP_ERR_PROCESSING_FAILED;
    }

    int32_t size = width * height;
    int32_t score = g_compute_score(0, grayscale_img, size, width, height, ppi);

    if (score < 0) score = 0;
    if (score > FP_NFIQ2_MAX_SCORE) score = FP_NFIQ2_MAX_SCORE;
    if (score < FP_NFIQ2_MIN_SCORE) score = FP_NFIQ2_MIN_SCORE;

    *out_quality_score = score;
    return FP_OK;
}
