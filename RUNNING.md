# 🏃 How to Run This Project

This guide provides step-by-step instructions to simulate the full Enterprise Bazel workflow locally. You will act as the **CI Server**, the **Release Manager**, and the **Developer**.

## 📋 Prerequisites

Ensure you have the following installed:

* **Bazel** (via Bazelisk recommended)
* **Python 3**
* **Bash** terminal (Linux/macOS)

---

## ⚡ Step 0: Start the Mock Artifactory

Bazel needs to download the `.tar.gz` artifacts via HTTP. We will use Python to verify `localhost:9000` as our "JFrog Artifactory".

1. Open a new terminal tab.
2. Run the file server pointing to the storage directory:

```bash
# Keep this terminal open!
python3 -m http.server 9000 --directory infrastructure/jfrog-storage

```

> ✅ **Verify:** Open `http://localhost:9000` in your browser. You should see an empty directory listing (or existing files).

---

## 🏗️ Step 1: The Producer Workflow (CI)

Act as the **CI Server**. We will build the `platform-math-lib` and publish a Release Candidate to the **Playground Registry**.

1. Navigate to the library repository:
```bash
cd repos/platform-math-lib

```


2. Run the CI pipeline to publish version `1.0.0-rc1`:
```bash
./ci_pipeline.sh 1.0.0-rc1
```

**What happened?**

* Artifact `corp_math-1.0.0-rc1.tar.gz` was created.
* Artifact was uploaded to `infrastructure/jfrog-storage`.
* Metadata and SHA256 hash were registered in `infrastructure/bcr-playground`.

---

## 🧪 Step 2: The Consumer Workflow (Staging)

Act as a **Developer or QA Bot**. We will verify if the Backend App works with the new RC version using the **Playground Registry**.

1. Navigate to the application repository:
```bash
cd ../backend-app

```


2. **Crucial:** Clean the cache to avoid checksum mismatches (since RCs are volatile):
```bash
bazel clean --expunge

```


3. Run the app using the **CI configuration** (points to Playground):
```bash
# Note: The flag must be BEFORE the 'run' command
bazel --bazelrc=ci.bazelrc run //:server

```



> ✅ **Success:** You should see `Soma Corporativa: 300` in the output.

---

## 🚀 Step 3: Promotion to Production

Act as the **Release Manager**. The RC is verified. Now we promote it to the **Production Registry** (Immutable).

Since we don't have a script for this yet, we will do it manually (simulating a Pull Request merge).

1. **Copy the Metadata:**
Copy the version folder from Playground to Prod:
```bash
cp -r ../../infrastructure/bcr-playground/modules/corp_math/1.0.0-rc1 \
      ../../infrastructure/bcr-prod/modules/corp_math/

```


2. **Update the Index:**
Add the version to the production `metadata.json`:
```bash
# Open the file
nano ../../infrastructure/bcr-prod/modules/corp_math/metadata.json

# Add "1.0.0-rc1" to the versions array.
# It should look like: { "versions": ["1.0.0-rc1"], ... }

```



---

## 🏢 Step 4: The Consumer Workflow (Production)

Act as a **Standard Developer**. Now that the library is in Production, we don't need special flags anymore.

1. Still in `repos/backend-app`, clean the cache one last time:
```bash
bazel clean --expunge

```


2. Run using the default configuration (Production):
```bash
bazel run //:server

```



> ✅ **Success:** Bazel now pulls the metadata from `bcr-prod`, verifies the hash, and runs the application.

---

## 🩺 Maintenance & Troubleshooting

### Registry Health Check

Run the auditor script to ensure all links and hashes are valid.

```bash
# Check Playground
python3 ../../health_check.py

# Check Production
python3 ../../health_check.py --registry infrastructure/bcr-prod

```

### Common Errors

**Error:** `Checksum error in repository ... Invalid SHA-256 SRI checksum`

* **Cause:** You re-ran the `ci_pipeline.sh`, which changed the file timestamp and hash, but Bazel cached the old download.
* **Fix:** Run `bazel clean --expunge` inside the consumer repo.

**Error:** `Connection refused` (during download)

* **Cause:** The Python HTTP server (Step 0) is not running.
* **Fix:** Start the server on port 9000.