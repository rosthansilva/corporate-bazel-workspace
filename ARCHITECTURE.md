## 🧩 Versioning Strategy: Industry Standards vs. Our Approach

This project implements a versioning strategy that adapts the industry-standard **Snapshot vs. Release** model to work seamlessly with **Bazel's hermetic build system**.

### 1. The Industry Standard (Maven/Gradle Model)

Large organizations (e.g., Google, Uber, Nubank) typically configure Artifactory/S3 with two distinct repository types:

* **`libs-snapshot-local` (Development):**
* **Mutable:** Allows overwriting artifacts.
* **Versioning:** Uses dynamic suffixes like `1.0.0-SNAPSHOT`. Clients automatically download the latest version available, regardless of content changes.
* **Risk:** Builds are not reproducible over time because the underlying code for `1.0.0-SNAPSHOT` changes.


* **`libs-release-local` (Production):**
* **Immutable:** Once `1.0.0` is published, it **cannot** be overwritten or deleted.
* **Guarantee:** Ensures that a build running today produces the exact same result as a build running next year.



### 2. My Adaptation for Bazel (Bzlmod)

Bazel enforces stricter requirements than Maven or Gradle. It relies on **SHA256 checksums** to guarantee integrity. If an artifact is overwritten (Standard Snapshot behavior) but the hash changes, Bazel will fail with a `Checksum Mismatch`.

To bridge this gap, our architecture adapts the standard model:

| Feature | Standard "Snapshot" Model | Our "Playground" Model |
| --- | --- | --- |
| **Storage** | `libs-snapshot-local` | `jfrog-storage` (via **Playground Registry**) |
| **Mutability** | **Implicit:** The file changes, the URL stays the same. | **Explicit:** The file changes, and the **CI updates the Registry JSON** with the new Hash. |
| **Client Behavior** | Checks for "newer" timestamp. | Checks `source.json` for the exact SHA256 hash. |
| **Resolution** | Non-deterministic (can change silently). | **Deterministic** (locked to the hash in the registry). |

### Summary

* **BCR Playground = `libs-snapshot-local**`: It allows us to publish Release Candidates (`-rc1`) and iterate quickly. The CI pipeline handles the complexity of updating the SHA256 hash automatically.
* **BCR Production = `libs-release-local**`: It is a strictly immutable registry. Versions here are final, safe, and manually promoted.