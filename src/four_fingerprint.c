#include "four_fingerprint.h"

#if defined(_WIN32)
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

/* All public API functions are implemented in module files.
 * This file ensures symbols are exported for FFI linkage. */

FFI_PLUGIN_EXPORT const char *fp_get_version_exported(void) {
    return fp_get_version();
}
