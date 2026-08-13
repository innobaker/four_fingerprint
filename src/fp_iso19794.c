#include "fp_internal.h"

/*
 * ISO/IEC 19794-2 minutiae template export (simplified binary format).
 * Header + minutiae records for interoperability.
 */
int32_t fp_export_iso_template(
    const FpMinutia *minutiae, int32_t count,
    int32_t finger_position, int32_t ppi,
    uint8_t *out_buffer, int32_t buffer_size,
    int32_t *out_length) {

    if (!minutiae || !out_buffer || !out_length || count <= 0 || buffer_size <= 0) {
        return FP_ERR_INVALID_INPUT;
    }

    /* Minimum: 24-byte header + 6 bytes per minutia */
    int32_t needed = 24 + count * 6;
    if (needed > buffer_size) return FP_ERR_BUFFER_TOO_SMALL;

    memset(out_buffer, 0, (size_t)needed);

    /* Format identifier 'FMR\0' */
    out_buffer[0] = 'F';
    out_buffer[1] = 'M';
    out_buffer[2] = 'R';
    out_buffer[3] = 0x00;

    /* Version */
    out_buffer[4] = 0x20;
    out_buffer[5] = 0x32; /* ISO 19794-2:2011 */

    /* Record length (big-endian) */
    out_buffer[6] = (uint8_t)((needed >> 8) & 0xFF);
    out_buffer[7] = (uint8_t)(needed & 0xFF);

    /* Capture device ID */
    out_buffer[8] = 0x00;
    out_buffer[9] = 0x01;

    /* Finger position */
    out_buffer[10] = (uint8_t)finger_position;

    /* Impression type: 0 = live-scan plain */
    out_buffer[11] = 0x00;

    /* Horizontal/vertical pixel density (PPI, big-endian) */
    out_buffer[12] = (uint8_t)((ppi >> 8) & 0xFF);
    out_buffer[13] = (uint8_t)(ppi & 0xFF);
    out_buffer[14] = (uint8_t)((ppi >> 8) & 0xFF);
    out_buffer[15] = (uint8_t)(ppi & 0xFF);

    /* Minutia count */
    out_buffer[16] = (uint8_t)((count >> 8) & 0xFF);
    out_buffer[17] = (uint8_t)(count & 0xFF);

    int32_t offset = 24;
    for (int32_t i = 0; i < count; i++) {
        out_buffer[offset++] = (uint8_t)((minutiae[i].x >> 8) & 0xFF);
        out_buffer[offset++] = (uint8_t)(minutiae[i].x & 0xFF);
        out_buffer[offset++] = (uint8_t)((minutiae[i].y >> 8) & 0xFF);
        out_buffer[offset++] = (uint8_t)(minutiae[i].y & 0xFF);
        out_buffer[offset++] = (uint8_t)((minutiae[i].direction / 10) & 0xFF);
        out_buffer[offset++] = (uint8_t)(minutiae[i].type & 0xFF);
    }

    *out_length = needed;
    return FP_OK;
}
