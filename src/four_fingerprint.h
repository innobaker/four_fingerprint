/*******************************************************************************
 * four_fingerprint.h - Contactless Slap Fingerprint Capture Plugin
 *
 * Public C API for FFI binding.
 ******************************************************************************/

#ifndef FOUR_FINGERPRINT_H
#define FOUR_FINGERPRINT_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Finger position codes (ISO 19794-2) */
#define FP_FINGER_UNKNOWN           0
#define FP_FINGER_RIGHT_THUMB       1
#define FP_FINGER_RIGHT_INDEX       2
#define FP_FINGER_RIGHT_MIDDLE      3
#define FP_FINGER_RIGHT_RING        4
#define FP_FINGER_RIGHT_LITTLE      5
#define FP_FINGER_LEFT_THUMB        6
#define FP_FINGER_LEFT_INDEX        7
#define FP_FINGER_LEFT_MIDDLE       8
#define FP_FINGER_LEFT_RING         9
#define FP_FINGER_LEFT_LITTLE      10

/* Minutia types */
#define FP_MINUTIA_BIFURCATION      0
#define FP_MINUTIA_RIDGE_ENDING     1

/* Liveness results */
#define FP_LIVENESS_NOT_LIVE        0
#define FP_LIVENESS_LIVE            1
#define FP_LIVENESS_UNKNOWN        -1

/* Capture state machine steps */
#define FP_STATE_IDLE              0
#define FP_STATE_LEFT_SLAP         1
#define FP_STATE_RIGHT_SLAP        2
#define FP_STATE_THUMBS            3
#define FP_STATE_PROCESSING        4
#define FP_STATE_COMPLETE          5

/* Capture state machine events */
#define FP_EVENT_START             0
#define FP_EVENT_LEFT_SLAP_DONE    1
#define FP_EVENT_RIGHT_SLAP_DONE   2
#define FP_EVENT_THUMBS_DONE       3
#define FP_EVENT_RESET             4

/* Quality scores (NFIQ2 1=Best, 5=Worst) */
#define FP_QUALITY_EXCELLENT       1
#define FP_QUALITY_GOOD            2
#define FP_QUALITY_FAIR            3
#define FP_QUALITY_POOR            4
#define FP_QUALITY_UNCLASSIFIABLE  5

/* Return codes */
#define FP_OK                       0
#define FP_ERR_INVALID_INPUT       -1
#define FP_ERR_PROCESSING_FAILED   -2
#define FP_ERR_OUT_OF_MEMORY       -3
#define FP_ERR_NOT_INITIALIZED     -4
#define FP_ERR_BUFFER_TOO_SMALL    -5
#define FP_ERR_LIVENESS_FAILED     -6

/* Data structures */

typedef struct {
    int32_t x;
    int32_t y;
    int32_t direction;  /* degrees * 10 */
    int32_t type;       /* 0=bifurcation, 1=ridge ending */
    double reliability;  /* 0.0 - 1.0 */
} FpMinutia;

typedef struct {
    int32_t finger_code;
    int32_t quality_score;
    int32_t minutia_count;
    int32_t is_live;
    int32_t resolution_ppi;
    double scale_factor;
} FpFingerResult;

typedef struct {
    int32_t success;
    int32_t num_fingers;
    int32_t total_minutiae;
    FpFingerResult fingers[10];
    FpMinutia *all_minutiae;
    int32_t all_minutiae_count;
    uint8_t *iso_template;
    int32_t iso_template_length;
} FpSlapResult;

typedef struct {
    int32_t current_step;
    int32_t left_ready;
    int32_t right_ready;
    int32_t thumbs_ready;
    int32_t initialized;
    int32_t capture_count;
} FpStateMachine;

typedef struct {
    int32_t min_x;
    int32_t min_y;
    int32_t max_x;
    int32_t max_y;
} FpBoundingBox;

typedef struct {
    int32_t finger_code;
    int32_t quality_score;
    int32_t minutia_count;
    int32_t is_live;
    int32_t resolution_ppi;
    double scale_factor;
    uint8_t *normalized_image;
    int32_t normalized_image_size;
    uint8_t *iso_template;
    int32_t iso_template_size;
    FpMinutia *minutiae;
    int32_t minutiae_count;
    uint8_t *encrypted_data;
    int32_t encrypted_data_size;
} FpProcessedFinger;

/* ===== Public FFI functions ===== */

/* 1. Scale / DPI calibration */
int32_t fp_calibrate_scale(
    const uint8_t *rgb_frame, int32_t width, int32_t height,
    const float *hand_landmarks, int32_t landmark_count,
    const int32_t *finger_codes, int32_t num_fingers,
    float *out_scale_factor
);

/* 2. Finger segmentation mask */
int32_t fp_segment_fingers(
    const uint8_t *grayscale_img, int32_t width, int32_t height,
    const float *hand_landmarks, int32_t landmark_count,
    uint8_t *out_mask,
    FpBoundingBox *out_boxes, int32_t max_fingers,
    int32_t *out_num_fingers
);

/* 3. Illumination normalization + specular highlight removal */
int32_t fp_normalize_illumination(
    const uint8_t *input_img, int32_t width, int32_t height,
    uint8_t *output_img
);

/* 4. Cylindrical surface unwarping */
int32_t fp_unwarp_cylindrical(
    const uint8_t *input_img, int32_t width, int32_t height,
    const FpBoundingBox *finger_roi,
    float finger_width_mm, float finger_length_mm,
    uint8_t *output_img, int32_t out_width, int32_t out_height,
    float *out_scale_factor
);

/* 5. Liveness / anti-spoofing gate */
int32_t fp_check_liveness(
    const uint8_t *grayscale_img, int32_t width, int32_t height,
    const float *hand_landmarks, int32_t landmark_count,
    int32_t *out_is_live
);

/* 6. NFIQ2 quality assessment */
int32_t fp_init_nfiq2(const char *model_dir);
int32_t fp_assess_quality(
    const uint8_t *grayscale_img, int32_t width, int32_t height,
    int32_t ppi, int32_t finger_code,
    int32_t *out_quality_score
);

/* 7. Minutiae extraction (MINDTCT) */
int32_t fp_extract_minutiae(
    const uint8_t *grayscale_img, int32_t width, int32_t height,
    int32_t ppi,
    FpMinutia *out_minutiae, int32_t max_minutiae,
    int32_t *out_num_minutiae
);

/* 8. Template matching (BOZORTH3) */
int32_t fp_match_templates(
    const FpMinutia *probe, int32_t probe_count,
    const FpMinutia *gallery, int32_t gallery_count,
    int32_t *out_match_score
);

/* 9. ISO/IEC 19794-2 template export */
int32_t fp_export_iso_template(
    const FpMinutia *minutiae, int32_t count,
    int32_t finger_position, int32_t ppi,
    uint8_t *out_buffer, int32_t buffer_size,
    int32_t *out_length
);

/* 10. WSQ compression / decompression */
int32_t fp_wsq_compress(
    const uint8_t *grayscale_img, int32_t width, int32_t height,
    int32_t ppi, uint8_t *out_buffer, int32_t buffer_size,
    int32_t *out_length
);

int32_t fp_wsq_decompress(
    const uint8_t *wsq_data, int32_t data_length,
    uint8_t *out_grayscale, int32_t out_width, int32_t out_height,
    int32_t *out_actual_width, int32_t *out_actual_height,
    int32_t *out_ppi
);

/* 11. Burst frame best-frame selection */
int32_t fp_select_best_frame(
    const uint8_t **frames, int32_t frame_count,
    int32_t width, int32_t height, int32_t ppi,
    int32_t *out_best_index
);

/* 12. Full pipeline: process a single slap frame */
int32_t fp_process_slap_frame(
    const uint8_t *rgb_frame, int32_t width, int32_t height,
    const float *hand_landmarks, int32_t landmark_count,
    int32_t *finger_codes,
    FpSlapResult *out_result,
    FpMinutia *out_minutia_buffer, int32_t max_minutiae,
    uint8_t *out_image_buffer, int32_t image_buffer_size
);

/* 13. Capture state machine */
int32_t fp_state_machine_init(FpStateMachine *state);
int32_t fp_state_machine_update(FpStateMachine *state, int32_t event);
int32_t fp_state_machine_get_step(const FpStateMachine *state);

/* 14. Encrypted storage (AES-256-GCM) */
int32_t fp_encrypt_data(
    const uint8_t *data, int32_t data_len,
    const uint8_t *key, int32_t key_len,
    uint8_t *out_encrypted, int32_t *out_enc_len
);

int32_t fp_decrypt_data(
    const uint8_t *data, int32_t data_len,
    const uint8_t *key, int32_t key_len,
    uint8_t *out_decrypted, int32_t *out_dec_len
);

/* 15. Process a single finger */
int32_t fp_process_finger(
    const uint8_t *rgb_frame, int32_t width, int32_t height,
    const float *hand_landmarks, int32_t landmark_count,
    int32_t finger_code,
    const FpBoundingBox *finger_roi,
    float scale_factor,
    FpProcessedFinger *out_finger
);

int32_t fp_is_match(int32_t match_score);

/* 16. Memory management */
void fp_free_slap_result(FpSlapResult *result);
void fp_free_processed_finger(FpProcessedFinger *finger);

/* 17. Version info */
const char *fp_get_version(void);

#ifdef __cplusplus
}
#endif

#endif /* FOUR_FINGERPRINT_H */
