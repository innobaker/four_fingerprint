#include "fp_internal.h"

/*
 * WSQ compression (simplified wavelet-based encoding).
 * For production, link NBIS imgtools WSQ library.
 * This implementation uses zlib deflate as transport compression.
 */
#ifdef FP_HAS_ZLIB
#include <zlib.h>
#endif

int32_t fp_wsq_compress(
    const uint8_t *grayscale_img, int32_t width, int32_t height,
    int32_t ppi, uint8_t *out_buffer, int32_t buffer_size,
    int32_t *out_length) {

    if (!grayscale_img || !out_buffer || !out_length ||
        width <= 0 || height <= 0 || buffer_size <= 0) {
        return FP_ERR_INVALID_INPUT;
    }

    int32_t raw_size = width * height;
    int32_t header_size = 16;
    int32_t max_payload = buffer_size - header_size;
    if (max_payload <= 0) return FP_ERR_BUFFER_TOO_SMALL;

    /* WSQ-like header: SOI marker + dimensions + PPI */
    out_buffer[0] = 0xFF;
    out_buffer[1] = 0xA0; /* SOI_WSQ */
    out_buffer[2] = (uint8_t)((width >> 8) & 0xFF);
    out_buffer[3] = (uint8_t)(width & 0xFF);
    out_buffer[4] = (uint8_t)((height >> 8) & 0xFF);
    out_buffer[5] = (uint8_t)(height & 0xFF);
    out_buffer[6] = (uint8_t)((ppi >> 8) & 0xFF);
    out_buffer[7] = (uint8_t)(ppi & 0xFF);

#ifdef FP_HAS_ZLIB
    uLongf comp_size = (uLongf)max_payload;
    int ret = compress2(out_buffer + header_size, &comp_size,
                        grayscale_img, (uLong)raw_size, Z_BEST_SPEED);
    if (ret != Z_OK) return FP_ERR_PROCESSING_FAILED;
    out_buffer[8] = (uint8_t)((comp_size >> 24) & 0xFF);
    out_buffer[9] = (uint8_t)((comp_size >> 16) & 0xFF);
    out_buffer[10] = (uint8_t)((comp_size >> 8) & 0xFF);
    out_buffer[11] = (uint8_t)(comp_size & 0xFF);
    out_buffer[12] = 0xFF;
    out_buffer[13] = 0xA1; /* EOI_WSQ */
    *out_length = header_size + (int32_t)comp_size;
#else
    if (raw_size > max_payload) return FP_ERR_BUFFER_TOO_SMALL;
    memcpy(out_buffer + header_size, grayscale_img, (size_t)raw_size);
    out_buffer[8] = (uint8_t)((raw_size >> 24) & 0xFF);
    out_buffer[9] = (uint8_t)((raw_size >> 16) & 0xFF);
    out_buffer[10] = (uint8_t)((raw_size >> 8) & 0xFF);
    out_buffer[11] = (uint8_t)(raw_size & 0xFF);
    out_buffer[12] = 0xFF;
    out_buffer[13] = 0xA1;
    *out_length = header_size + raw_size;
#endif

    (void)ppi;
    return FP_OK;
}

int32_t fp_wsq_decompress(
    const uint8_t *wsq_data, int32_t data_length,
    uint8_t *out_grayscale, int32_t out_width, int32_t out_height,
    int32_t *out_actual_width, int32_t *out_actual_height,
    int32_t *out_ppi) {

    if (!wsq_data || !out_grayscale || !out_actual_width ||
        !out_actual_height || !out_ppi || data_length < 16) {
        return FP_ERR_INVALID_INPUT;
    }

    int32_t width = (wsq_data[2] << 8) | wsq_data[3];
    int32_t height = (wsq_data[4] << 8) | wsq_data[5];
    int32_t ppi = (wsq_data[6] << 8) | wsq_data[7];
    int32_t payload_size = (wsq_data[8] << 24) | (wsq_data[9] << 16) |
                           (wsq_data[10] << 8) | wsq_data[11];

    if (width <= 0 || height <= 0 || payload_size <= 0) {
        return FP_ERR_INVALID_INPUT;
    }

    int32_t expected = width * height;
    if (expected > out_width * out_height) return FP_ERR_BUFFER_TOO_SMALL;

#ifdef FP_HAS_ZLIB
    uLongf dest_size = (uLongf)expected;
    int ret = uncompress(out_grayscale, &dest_size,
                         wsq_data + 16, (uLong)payload_size);
    if (ret != Z_OK) return FP_ERR_PROCESSING_FAILED;
#else
    if (payload_size != expected) return FP_ERR_PROCESSING_FAILED;
    memcpy(out_grayscale, wsq_data + 16, (size_t)expected);
#endif

    *out_actual_width = width;
    *out_actual_height = height;
    *out_ppi = ppi;
    return FP_OK;
}
