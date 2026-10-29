# Appendix K: BNCrypto

[← Previous: Appendix J: BNSqlite](appendix_j_bnsqlite.md) · [Contents](toc.md)

`BNCrypto` is an external provider-backed module. It is not part of the Basic Next core and every consumer must import it explicitly:

```basic
IMPORT BNCrypto AS Crypto
```

The normative contract is [`language/0.6/bncrypto.md`](https://github.com/cquintella/BasicNext/blob/v0.6.11/language/0.6/bncrypto.md).

## Digests

`SHA256` and `SHA512` hash the UTF-8 bytes of a `STRING` and return lowercase hexadecimal — 64 characters and 128 characters respectively. The width is fixed and does not depend on the input:

```basic
IMPORT BNCrypto AS Crypto

FUNCTION Start() AS VOID
    PRINT Crypto.SHA256("abc")
END FUNCTION
```

```
ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
```

Digests are pure. They need no `HOST` capability, touch no file and no socket, and the same argument always produces the same result. That is why they are available to both the interpreter and compiled binaries without a permission decision.

## Why the digest is a `STRING` but a key is not

A digest is meant to be shown: printed, compared, written to a log. A key is the opposite — showing it is the bug. `BNCrypto` encodes that difference in the types rather than in a comment.

`Crypto.Bytes` is an **opaque** buffer. There is no implicit conversion from `Bytes` to `STRING`, so byte data cannot be printed, concatenated, or logged by accident. When you genuinely want to see the bytes, you ask for it:

```basic
IMPORT BNCrypto AS Crypto

FUNCTION Start() AS VOID
    LET secret AS Crypto.Bytes = Crypto.FromText("abc")
    PRINT secret.Length()
    PRINT secret.ToHex()
    RELEASE secret
END FUNCTION
```

```
3
616263
```

`Bytes` is a resource, like a file or a socket: it is owned, and `RELEASE` ends that ownership. Releasing twice is reported, not ignored.

## Keys: the `Key` type

A key is not even a `Bytes`. Every member that needs secret material — the ciphers, HMAC, the signing functions — takes a `Crypto.Key`, and a `Key` has no `ToHex`: once bytes become a key, the program cannot read them back. A `Key` knows its length and its algorithm, and its memory is overwritten with zeros when its last reference ends, or earlier when you call `Zeroize()`.

The usual way to get one is to let the operating system pick it. `GenerateKey` draws the key from the system's cryptographic random generator, at the length the algorithm needs:

```basic
IMPORT BNCrypto AS Crypto

FUNCTION Start() AS VOID
    LET key AS Crypto.Key OR Error = Crypto.GenerateKey(Crypto.ALG_AES_GCM_256)
    IF key IS Error THEN
        PRINT "no system entropy"
        RETURN
    END IF
    PRINT key.Length(), key.Algorithm()
    key.Zeroize()
    LET nonce AS Crypto.Bytes = Crypto.FromText("0123456789ab")
    LET sealed AS Crypto.Bytes OR Error = Crypto.SealAesGcm(key, nonce, Crypto.FromText("abc"), Crypto.FromText(""))
    IF sealed IS Error THEN
        PRINT sealed.Code
    END IF
END FUNCTION
```

```
32 1
1
```

`ALG_AES_GCM_256` is the constant `1` and its keys are 32 bytes. After `Zeroize()` the handle still exists but holds no key, so every operation with it returns an `Error` with code `1` (`INVALID_ARGUMENT`) and the program goes on. Generation itself returns `Key OR Error` because the system entropy source can fail; that failure is reported, never replaced by weaker randomness.

A key that already exists — read from a key store, or agreed with another party — enters through `ImportKey`, which checks the length the algorithm requires. The bytes you imported it from are an ordinary `Bytes`: release them as soon as the `Key` exists.

## Reading malformed input

`FromHex` returns `Bytes OR Error` rather than guessing. An odd-length string is not a byte sequence, so it is rejected instead of being silently truncated:

```basic
LET raw AS Crypto.Bytes OR Error = Crypto.FromHex("abc")
IF raw IS Error THEN
    PRINT "odd-length-rejected"
END IF
```

`ImportKey` takes the same posture with key lengths:

```basic
IMPORT BNCrypto AS Crypto

FUNCTION Start() AS VOID
    LET nonce AS Crypto.Bytes OR Error = Crypto.GenerateNonce(Crypto.ALG_AES_GCM_256)
    IF nonce IS Crypto.Bytes THEN
        PRINT nonce.Length()
    END IF
    LET short AS Crypto.Key OR Error = Crypto.ImportKey(Crypto.FromText("short"), Crypto.ALG_AES_GCM_256)
    IF short IS Error THEN
        PRINT short.Code
    END IF
END FUNCTION
```

```
12
1
```

When an input cannot be interpreted, you get an `Error` you must handle, never a partial result that looks plausible.

## Encrypting something

Encryption in `BNCrypto` is always *authenticated*: you do not get a mode that encrypts without also proving the message was not altered. `Seal` produces a ciphertext with a tag appended; `Open` verifies that tag before giving you anything back.

```basic
IMPORT BNCrypto AS Crypto

FUNCTION Start() AS VOID
    LET material AS Crypto.Bytes = Crypto.FromText("0123456789abcdef0123456789abcdef")
    LET key AS Crypto.Key OR Error = Crypto.ImportKey(material, Crypto.ALG_AES_GCM_256)
    RELEASE material
    IF key IS Error THEN
        PRINT "wrong key length"
        RETURN
    END IF
    LET nonce AS Crypto.Bytes = Crypto.FromText("0123456789ab")
    LET aad AS Crypto.Bytes = Crypto.FromText("hdr")
    LET sealed AS Crypto.Bytes OR Error = Crypto.SealAesGcm(key, nonce, Crypto.FromText("abc"), aad)
    IF sealed IS Error THEN
        PRINT "seal failed"
        RETURN
    END IF
    PRINT sealed.ToHex()
    LET opened AS Crypto.Bytes OR Error = Crypto.OpenAesGcm(key, nonce, sealed, aad)
    IF opened IS Crypto.Bytes THEN
        PRINT opened.ToHex()
    END IF
    LET forged AS Crypto.Bytes OR Error = Crypto.OpenAesGcm(key, nonce, sealed, Crypto.FromText("other"))
    IF forged IS Error THEN
        PRINT "rejected"
    END IF
END FUNCTION
```

```
f8cb8441c9b57bd8fd62663940f843f4e3cf1f
616263
rejected
```

The key is 32 bytes and the nonce is 12. Those are not suggestions: a wrong length gives you an `Error`, not a padded guess. The ciphertext is the three bytes of `abc` followed by a 16-byte tag.

The `aad` — additional authenticated data — is covered by the tag but is *not* encrypted. It is for the parts of a message that must travel in the clear yet must not be swapped, such as a header or a record id.

### The failure you want

Open with a different `aad`, change one byte of the ciphertext, or use another key, and `Open` returns `Error`. Not a shorter plaintext, not garbage — nothing. This is the whole point of authenticated encryption, and it is why `Open` returns `Bytes OR Error` and forces you to write the `IF`.

### One rule the language cannot enforce

Never use the same nonce twice with the same key. With AES-GCM in particular, repeating a nonce does not merely weaken the message — it can expose the authentication key itself. `BNCrypto` cannot check this for you, because it never sees your other messages.

The fixed nonce in the example above is there so that the output can be printed and compared; a real program draws a fresh one for every message with `Crypto.GenerateNonce(Crypto.ALG_AES_GCM_256)`, which returns 12 bytes from the system's cryptographic random generator, or keeps a counter it is certain never repeats. `HOST.Random` is the wrong source: it is a statistical generator, and its output can be predicted.

## One implementation, two backends

The cryptography does not live in the interpreter. It lives in one Rust library behind the C ABI, which is what compiled binaries link against and what the interpreter's provider calls. `bni` and `bnc` therefore run the *same* code, and the test suite asserts that a compiled program prints byte-for-byte what the interpreted one prints. A backend that drifted would fail that test rather than quietly disagree.

`Bytes` and `Key` work the same way: the handle travels as a pointer into a runtime table, so a compiled program creates, measures, uses, zeroizes and releases them through the same code the interpreter uses, and both backends run the whole surface.

## Proving a message came from you

A signature answers a different question from a MAC. A MAC proves *someone who knows the shared key* produced the message; a signature proves *the holder of one particular private key* did, and anyone with the public key can check it without being able to forge it.

```basic
IMPORT BNCrypto AS Crypto

FUNCTION Start() AS VOID
    LET seed AS Crypto.Key OR Error = Crypto.ImportKey(Crypto.FromText("0123456789abcdef0123456789abcdef"), Crypto.ALG_ED25519)
    IF seed IS Error THEN
        PRINT "bad seed"
        RETURN
    END IF
    LET message AS Crypto.Bytes = Crypto.FromText("abc")
    LET publicKey AS Crypto.Bytes OR Error = Crypto.Ed25519PublicKey(seed)
    LET signature AS Crypto.Bytes OR Error = Crypto.Ed25519Sign(seed, message)
    IF publicKey IS Crypto.Bytes THEN
        IF signature IS Crypto.Bytes THEN
            PRINT Crypto.Ed25519Verify(publicKey, message, signature)
            PRINT Crypto.Ed25519Verify(publicKey, Crypto.FromText("abd"), signature)
        END IF
    END IF
END FUNCTION
```

```
TRUE
FALSE
```

The private seed is a `Key`; the public key and the signature are ordinary `Bytes`, because they are meant to be published. Both Ed25519 and ECDSA P-256 sign deterministically, so the same key and message always give the same signature. That is a testing convenience, not a security property you should rely on for anything else. A P-256 key from `GenerateKey` is always a valid scalar: values outside the curve order are drawn again.

`Ed25519Verify` returns `FALSE` rather than an error. An invalid signature is an *answer*, not a malfunction — the caller is supposed to handle it as a normal outcome.

## Preparing for a quantum adversary

`MlKem` and `MlDsa` are the NIST post-quantum standards: FIPS 203 for key encapsulation and FIPS 204 for signatures. They exist because an adversary can record encrypted traffic today and decrypt it years from now, once a large enough quantum computer exists. Anything whose confidentiality must outlive that horizon should be protected with them now.

BN has no tuple, so the members that produce two values hand back one buffer with the parts concatenated, and `Slice` splits it. The private half becomes a `Key` again through `ImportKey`:

```basic
IMPORT BNCrypto AS Crypto

FUNCTION Start() AS VOID
    LET seed AS Crypto.Key OR Error = Crypto.GenerateKey(Crypto.ALG_ML_KEM_768)
    IF seed IS Error THEN
        RETURN
    END IF
    LET pair AS Crypto.Bytes OR Error = Crypto.MlKemKeypair(seed)   // publicKey || privateKey
    IF pair IS Error THEN
        RETURN
    END IF
    LET publicKey AS Crypto.Bytes OR Error = Crypto.Slice(pair, 0, 1184)
    LET privatePart AS Crypto.Bytes OR Error = Crypto.Slice(pair, 1184, 64)
    IF publicKey IS Error OR privatePart IS Error THEN
        RETURN
    END IF
    LET privateKey AS Crypto.Key OR Error = Crypto.ImportKey(privatePart, Crypto.ALG_ML_KEM_768)
    LET sent AS Crypto.Bytes OR Error = Crypto.MlKemEncapsulate(publicKey)    // ciphertext || sharedSecret
    IF privateKey IS Error OR sent IS Error THEN
        RETURN
    END IF
    LET ciphertext AS Crypto.Bytes OR Error = Crypto.Slice(sent, 0, 1088)
    LET shared AS Crypto.Bytes OR Error = Crypto.Slice(sent, 1088, 32)
    IF ciphertext IS Error OR shared IS Error THEN
        RETURN
    END IF
    LET received AS Crypto.Bytes OR Error = Crypto.MlKemDecapsulate(privateKey, ciphertext)
    IF received IS Crypto.Bytes THEN
        PRINT received.ToHex() = shared.ToHex()
    END IF
END FUNCTION
```

```
TRUE
```

The sizes are fixed by the standard, so the split is unambiguous. `Slice` refuses a window that runs past the end rather than returning a short buffer that might be mistaken for a key.

### The one thing you must not do

`MlKemEncapsulate` uses fresh randomness every call, and there is deliberately no deterministic variant. The underlying library offers one, marked hidden and hazardous, and `BNCrypto` does not expose it: reusing encapsulation randomness even once is a catastrophic failure, so the language does not offer you the rope.

The same caution applies to AEAD nonces, and for the same reason.

## What is not here yet

`BNCrypto` covers digests, `Bytes`, `Key`, system randomness, authenticated encryption, HMAC, Argon2id, Ed25519, ECDSA P-256, ML-KEM-768 and ML-DSA-65. What it does not do is decide policy for you: it has no opinion about where keys live, how long they last, or who may use them. Key storage, rotation and access control are the program's job.

One honest caveat on the post-quantum pair: every other algorithm here is checked byte-for-byte against a second, independent implementation. The post-quantum ones are not, because no independent implementation was available to check against. They are verified by round-trip, by tamper rejection, by the standard's object sizes, and by the upstream crates' own Wycheproof test suites. The contract document says so too; you should know which guarantees rest on what.

---

[Next: Appendix L: BNFfi — C Foreign Function Interface →](appendix_l_bnffi.md)
