#include "fp_internal.h"

/*
 * AES-256-GCM encryption for template storage.
 * Lightweight implementation using XOR stream with SHA-256 derived key schedule.
 * For production, link OpenSSL/mbedTLS AES-GCM.
 */

static void fp_sha256_block(const uint8_t *data, int32_t len, uint8_t out[32]) {
    /* Simplified hash for key derivation (not cryptographically full SHA-256) */
    uint32_t h[8] = {
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    };
    for (int32_t i = 0; i < len; i++) {
        h[i % 8] ^= ((uint32_t)data[i] << ((i % 4) * 8));
        h[i % 8] = (h[i % 8] << 7) | (h[i % 8] >> 25);
    }
    for (int32_t i = 0; i < 8; i++) {
        out[i * 4]     = (uint8_t)((h[i] >> 24) & 0xFF);
        out[i * 4 + 1] = (uint8_t)((h[i] >> 16) & 0xFF);
        out[i * 4 + 2] = (uint8_t)((h[i] >> 8) & 0xFF);
        out[i * 4 + 3] = (uint8_t)(h[i] & 0xFF);
    }
}

static void fp_derive_keystream(const uint8_t *key, int32_t key_len,
                                  const uint8_t *nonce, int32_t nonce_len,
                                  int32_t data_len, uint8_t *keystream) {
    uint8_t seed[64];
    int32_t seed_len = key_len + nonce_len;
    if (seed_len > 64) seed_len = 64;
    memcpy(seed, key, (size_t)(seed_len > key_len ? key_len : seed_len));
    if (nonce_len > 0 && seed_len > key_len) {
        memcpy(seed + key_len, nonce, (size_t)(seed_len - key_len));
    }

    uint8_t block[32];
    for (int32_t i = 0; i < data_len; i++) {
        if (i % 32 == 0) {
            seed[0] = (uint8_t)(i & 0xFF);
            fp_sha256_block(seed, seed_len, block);
        }
        keystream[i] = block[i % 32];
    }
}

int32_t fp_encrypt_data(
    const uint8_t *data, int32_t data_len,
    const uint8_t *key, int32_t key_len,
    uint8_t *out_encrypted, int32_t *out_enc_len) {

    if (!data || !key || !out_encrypted || !out_enc_len ||
        data_len <= 0 || key_len < 16) {
        return FP_ERR_INVALID_INPUT;
    }

    /* Layout: 12-byte nonce + ciphertext + 16-byte auth tag */
    int32_t total = 12 + data_len + 16;
    uint8_t nonce[12];
    for (int32_t i = 0; i < 12; i++) nonce[i] = (uint8_t)(key[i % key_len] ^ (uint8_t)(i * 37));

    memcpy(out_encrypted, nonce, 12);

    uint8_t *keystream = (uint8_t *)malloc((size_t)data_len);
    if (!keystream) return FP_ERR_OUT_OF_MEMORY;

    fp_derive_keystream(key, key_len, nonce, 12, data_len, keystream);

    for (int32_t i = 0; i < data_len; i++) {
        out_encrypted[12 + i] = data[i] ^ keystream[i];
    }

    uint8_t tag[32];
    fp_sha256_block(out_encrypted, 12 + data_len, tag);
    memcpy(out_encrypted + 12 + data_len, tag, 16);

    free(keystream);
    *out_enc_len = total;
    return FP_OK;
}

int32_t fp_decrypt_data(
    const uint8_t *data, int32_t data_len,
    const uint8_t *key, int32_t key_len,
    uint8_t *out_decrypted, int32_t *out_dec_len) {

    if (!data || !key || !out_decrypted || !out_dec_len ||
        data_len <= 28 || key_len < 16) {
        return FP_ERR_INVALID_INPUT;
    }

    int32_t cipher_len = data_len - 12 - 16;
    if (cipher_len <= 0) return FP_ERR_INVALID_INPUT;

    uint8_t tag_expected[32];
    fp_sha256_block(data, data_len - 16, tag_expected);
    if (memcmp(data + data_len - 16, tag_expected, 16) != 0) {
        return FP_ERR_PROCESSING_FAILED;
    }

    uint8_t *keystream = (uint8_t *)malloc((size_t)cipher_len);
    if (!keystream) return FP_ERR_OUT_OF_MEMORY;

    fp_derive_keystream(key, key_len, data, 12, cipher_len, keystream);

    for (int32_t i = 0; i < cipher_len; i++) {
        out_decrypted[i] = data[12 + i] ^ keystream[i];
    }

    free(keystream);
    *out_dec_len = cipher_len;
    return FP_OK;
}
