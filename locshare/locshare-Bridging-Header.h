//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#include <CommonCrypto/CommonDigest.h>
#include <CommonCrypto/CommonHMAC.h>
#include <CommonCrypto/CommonCryptor.h>

extern void curve25519_donna(unsigned char *output, const unsigned char *a, const unsigned char *b);

extern int  curve25519_sign(unsigned char* signature_out, /* 64 bytes */
                     const unsigned char* curve25519_privkey, /* 32 bytes */
                     const unsigned char* msg, const unsigned long msg_len,
                     const unsigned char* random); /* 64 bytes */

 extern int curve25519_verify(const unsigned char* signature, /* 64 bytes */
                       const unsigned char* curve25519_pubkey, /* 32 bytes */
                       const unsigned char* msg, const unsigned long msg_len);
