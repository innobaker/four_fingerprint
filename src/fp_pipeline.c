#include "fp_internal.h"

int32_t fp_process_finger(
    const uint8_t *rgb_frame, int32_t width, int32_t height,
    const float *hand_landmarks, int32_t landmark_count,
    int32_t finger_code,
    const FpBoundingBox *finger_roi,
    float scale_factor,
    FpProcessedFinger *out_finger) {

    if (!rgb_frame || !hand_landmarks || !finger_roi || !out_finger ||
        width <= 0 || height <= 0 || landmark_count < FP_LANDMARK_COUNT) {
        return FP_ERR_INVALID_INPUT;
    }

    memset(out_finger, 0, sizeof(FpProcessedFinger));
    out_finger->finger_code = finger_code;
    out_finger->scale_factor = scale_factor;
    out_finger->resolution_ppi = FP_TARGET_PPI;

    int32_t roi_w = finger_roi->max_x - finger_roi->min_x;
    int32_t roi_h = finger_roi->max_y - finger_roi->min_y;
    if (roi_w < 16 || roi_h < 16) return FP_ERR_INVALID_INPUT;

    int32_t out_w = (int32_t)(roi_w * scale_factor);
    int32_t out_h = (int32_t)(roi_h * scale_factor);
    if (out_w < 32) out_w = 32;
    if (out_h < 32) out_h = 32;
    if (out_w > 512) out_w = 512;
    if (out_h > 512) out_h = 512;

    int32_t gray_size = width * height;
    uint8_t *gray = (uint8_t *)malloc((size_t)gray_size);
    uint8_t *crop = (uint8_t *)malloc((size_t)(roi_w * roi_h));
    uint8_t *norm = (uint8_t *)malloc((size_t)(roi_w * roi_h));
    uint8_t *unwarped = (uint8_t *)malloc((size_t)(out_w * out_h));
    if (!gray || !crop || !norm || !unwarped) {
        free(gray); free(crop); free(norm); free(unwarped);
        return FP_ERR_OUT_OF_MEMORY;
    }

    fp_rgb_to_gray(rgb_frame, width, height, gray);
    fp_crop_gray(gray, width, height,
                 finger_roi->min_x, finger_roi->min_y, roi_w, roi_h, crop);
    fp_normalize_illumination(crop, roi_w, roi_h, norm);

    float width_mm = fp_finger_width_mm(finger_code);
    float length_mm = width_mm * 2.5f;
    float unwarp_scale = 1.0f;
    fp_unwarp_cylindrical(norm, roi_w, roi_h, finger_roi,
                          width_mm, length_mm, unwarped, out_w, out_h, &unwarp_scale);

    int32_t is_live = FP_LIVENESS_UNKNOWN;
    fp_check_liveness(unwarped, out_w, out_h, hand_landmarks, landmark_count, &is_live);
    out_finger->is_live = is_live;
    if (is_live == FP_LIVENESS_NOT_LIVE) {
        free(gray); free(crop); free(norm); free(unwarped);
        return FP_ERR_LIVENESS_FAILED;
    }

    int32_t quality = 5;
    fp_assess_quality(unwarped, out_w, out_h, FP_TARGET_PPI, finger_code, &quality);
    out_finger->quality_score = quality;

    static FpMinutia minutiae_buf[200];
    int32_t minutia_count = 0;
    int32_t ret = fp_extract_minutiae(unwarped, out_w, out_h, FP_TARGET_PPI,
                                       minutiae_buf, 200, &minutia_count);
    if (ret != FP_OK) {
        free(gray); free(crop); free(norm); free(unwarped);
        return ret;
    }

    out_finger->minutia_count = minutia_count;
    out_finger->minutiae = (FpMinutia *)malloc((size_t)(minutia_count * sizeof(FpMinutia)));
    if (out_finger->minutiae) {
        memcpy(out_finger->minutiae, minutiae_buf,
               (size_t)(minutia_count * sizeof(FpMinutia)));
    }

    int32_t img_size = out_w * out_h;
    out_finger->normalized_image = (uint8_t *)malloc((size_t)img_size);
    if (out_finger->normalized_image) {
        memcpy(out_finger->normalized_image, unwarped, (size_t)img_size);
        out_finger->normalized_image_size = img_size;
    }

    uint8_t iso_buf[8192];
    int32_t iso_len = 0;
    if (fp_export_iso_template(minutiae_buf, minutia_count, finger_code,
                                FP_TARGET_PPI, iso_buf, 8192, &iso_len) == FP_OK) {
        out_finger->iso_template = (uint8_t *)malloc((size_t)iso_len);
        if (out_finger->iso_template) {
            memcpy(out_finger->iso_template, iso_buf, (size_t)iso_len);
            out_finger->iso_template_size = iso_len;
        }
    }

    free(gray);
    free(crop);
    free(norm);
    free(unwarped);
    return FP_OK;
}

int32_t fp_process_slap_frame(
    const uint8_t *rgb_frame, int32_t width, int32_t height,
    const float *hand_landmarks, int32_t landmark_count,
    int32_t *finger_codes,
    FpSlapResult *out_result,
    FpMinutia *out_minutia_buffer, int32_t max_minutiae,
    uint8_t *out_image_buffer, int32_t image_buffer_size) {

    if (!rgb_frame || !hand_landmarks || !finger_codes || !out_result ||
        width <= 0 || height <= 0 || landmark_count < FP_LANDMARK_COUNT) {
        return FP_ERR_INVALID_INPUT;
    }

    memset(out_result, 0, sizeof(FpSlapResult));

    float scale_factor = 1.0f;
    int32_t num_fingers = 4;
    fp_calibrate_scale(rgb_frame, width, height, hand_landmarks,
                       landmark_count, finger_codes, num_fingers, &scale_factor);

    int32_t gray_size = width * height;
    uint8_t *gray = (uint8_t *)malloc((size_t)gray_size);
    uint8_t *mask = (uint8_t *)malloc((size_t)gray_size);
    FpBoundingBox boxes[10];
    int32_t box_count = 0;
    if (!gray || !mask) {
        free(gray); free(mask);
        return FP_ERR_OUT_OF_MEMORY;
    }

    fp_rgb_to_gray(rgb_frame, width, height, gray);
    fp_segment_fingers(gray, width, height, hand_landmarks, landmark_count,
                       mask, boxes, 10, &box_count);

    int32_t total_minutiae = 0;
    int32_t minutia_offset = 0;

    for (int32_t f = 0; f < box_count && f < num_fingers; f++) {
        FpProcessedFinger finger;
        int32_t ret = fp_process_finger(rgb_frame, width, height,
                                         hand_landmarks, landmark_count,
                                         finger_codes[f], &boxes[f],
                                         scale_factor, &finger);
        if (ret == FP_ERR_LIVENESS_FAILED) continue;
        if (ret != FP_OK) continue;

        int32_t idx = out_result->num_fingers;
        if (idx >= 10) break;

        out_result->fingers[idx].finger_code = finger.finger_code;
        out_result->fingers[idx].quality_score = finger.quality_score;
        out_result->fingers[idx].minutia_count = finger.minutia_count;
        out_result->fingers[idx].is_live = finger.is_live;
        out_result->fingers[idx].resolution_ppi = finger.resolution_ppi;
        out_result->fingers[idx].scale_factor = finger.scale_factor;
        out_result->num_fingers++;
        total_minutiae += finger.minutia_count;

        if (out_minutia_buffer && finger.minutiae &&
            minutia_offset + finger.minutia_count <= max_minutiae) {
            memcpy(out_minutia_buffer + minutia_offset, finger.minutiae,
                   (size_t)(finger.minutia_count * sizeof(FpMinutia)));
            minutia_offset += finger.minutia_count;
        }

        if (out_image_buffer && finger.normalized_image && image_buffer_size > 0) {
            int32_t copy_size = finger.normalized_image_size;
            if (copy_size > image_buffer_size) copy_size = image_buffer_size;
            memcpy(out_image_buffer, finger.normalized_image, (size_t)copy_size);
        }

        fp_free_processed_finger(&finger);
    }

    out_result->success = (out_result->num_fingers > 0) ? 1 : 0;
    out_result->total_minutiae = total_minutiae;
    out_result->all_minutiae_count = minutia_offset;

    if (out_minutia_buffer && minutia_offset > 0) {
        out_result->all_minutiae = out_minutia_buffer;
    }

    free(gray);
    free(mask);
    return out_result->success ? FP_OK : FP_ERR_PROCESSING_FAILED;
}

void fp_free_processed_finger(FpProcessedFinger *finger) {
    if (!finger) return;
    free(finger->normalized_image);
    free(finger->iso_template);
    free(finger->minutiae);
    free(finger->encrypted_data);
    finger->normalized_image = NULL;
    finger->iso_template = NULL;
    finger->minutiae = NULL;
    finger->encrypted_data = NULL;
}

void fp_free_slap_result(FpSlapResult *result) {
    if (!result) return;
    free(result->iso_template);
    result->iso_template = NULL;
    result->all_minutiae = NULL;
}

const char *fp_get_version(void) {
    return FP_VERSION_STRING;
}
