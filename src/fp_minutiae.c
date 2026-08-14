#include "fp_internal.h"

int32_t fp_extract_minutiae(
    const uint8_t *grayscale_img, int32_t width, int32_t height,
    int32_t ppi,
    FpMinutia *out_minutiae, int32_t max_minutiae,
    int32_t *out_num_minutiae) {

    if (!grayscale_img || !out_minutiae || !out_num_minutiae ||
        width < 32 || height < 32 || max_minutiae <= 0) {
        return FP_ERR_INVALID_INPUT;
    }

    return fp_nbis_extract_minutiae(grayscale_img, width, height, ppi,
                                    out_minutiae, max_minutiae,
                                    out_num_minutiae);
}
