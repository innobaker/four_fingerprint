#include "fp_internal.h"

int32_t g_countdown_remaining = 0;
int32_t g_countdown_active = 0;
int32_t g_ring_mode = 0;

int32_t fp_state_machine_init(FpStateMachine *state) {
    if (!state) return FP_ERR_INVALID_INPUT;
    memset(state, 0, sizeof(FpStateMachine));
    state->current_step = FP_STATE_IDLE;
    state->initialized = 1;
    return FP_OK;
}

int32_t fp_state_machine_update(FpStateMachine *state, int32_t event) {
    if (!state || !state->initialized) return FP_ERR_NOT_INITIALIZED;

    switch (state->current_step) {
        case FP_STATE_IDLE:
            if (event == FP_EVENT_START) {
                state->current_step = FP_STATE_LEFT_SLAP;
                state->left_ready = 0;
                state->right_ready = 0;
                state->thumbs_ready = 0;
                state->capture_count = 0;
            } else if (event == FP_EVENT_RESET) {
                state->current_step = FP_STATE_IDLE;
            }
            break;

        case FP_STATE_LEFT_SLAP:
            if (event == FP_EVENT_LEFT_SLAP_DONE) {
                state->left_ready = 1;
                state->current_step = FP_STATE_RIGHT_SLAP;
                state->capture_count++;
            } else if (event == FP_EVENT_RESET) {
                state->current_step = FP_STATE_IDLE;
            }
            break;

        case FP_STATE_RIGHT_SLAP:
            if (event == FP_EVENT_RIGHT_SLAP_DONE) {
                state->right_ready = 1;
                state->current_step = FP_STATE_THUMBS;
                state->capture_count++;
            } else if (event == FP_EVENT_RESET) {
                state->current_step = FP_STATE_IDLE;
            }
            break;

        case FP_STATE_THUMBS:
            if (event == FP_EVENT_THUMBS_DONE) {
                state->thumbs_ready = 1;
                state->current_step = FP_STATE_PROCESSING;
                state->capture_count++;
            } else if (event == FP_EVENT_RESET) {
                state->current_step = FP_STATE_IDLE;
            }
            break;

        case FP_STATE_PROCESSING:
            state->current_step = FP_STATE_COMPLETE;
            break;

        case FP_STATE_COMPLETE:
            if (event == FP_EVENT_RESET || event == FP_EVENT_START) {
                if (event == FP_EVENT_START) {
                    state->current_step = FP_STATE_LEFT_SLAP;
                    state->left_ready = 0;
                    state->right_ready = 0;
                    state->thumbs_ready = 0;
                    state->capture_count = 0;
                } else {
                    state->current_step = FP_STATE_IDLE;
                }
            }
            break;

        default:
            break;
    }

    return FP_OK;
}

int32_t fp_state_machine_get_step(const FpStateMachine *state) {
    if (!state || !state->initialized) return FP_STATE_IDLE;
    return state->current_step;
}

int32_t fp_start_countdown(int32_t seconds) {
    g_countdown_active = 1;
    g_countdown_remaining = seconds;
    return FP_OK;
}

int32_t fp_get_countdown_remaining(void) {
    return g_countdown_remaining;
}

int32_t fp_is_countdown_finished(void) {
    return (g_countdown_active && g_countdown_remaining <= 0) ? 1 : 0;
}

int32_t fp_set_ring_mode(int32_t mode) {
    g_ring_mode = mode;
    return FP_OK;
}
