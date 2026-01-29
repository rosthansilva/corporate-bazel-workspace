import json
import os
import urllib.request
import hashlib
import sys
import argparse

GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
RESET = "\033[0m"

def calculate_sha256(content):
    return hashlib.sha256(content).hexdigest()

def validate_module_version(registry_path, module, version):
    source_file = os.path.join(registry_path, "modules", module, version, "source.json")
    
    if not os.path.exists(source_file):
        print(f"{RED}❌ {module}@{version}: Missing source.json{RESET}")
        return False

    try:
        with open(source_file, 'r') as f:
            data = json.load(f)
    except json.JSONDecodeError:
        print(f"{RED}❌ {module}@{version}: Invalid JSON format in source.json{RESET}")
        return False

    url = data.get('url')
    integrity = data.get('integrity')

    if not url:
        print(f"{RED}❌ {module}@{version}: Missing 'url' field{RESET}")
        return False

    try:
        # Timeout set to 5 seconds to avoid hanging
        with urllib.request.urlopen(url, timeout=5) as response:
            if response.status != 200:
                print(f"{RED}❌ {module}@{version}: HTTP Error {response.status}{RESET}")
                return False
            
            content = response.read()
            
    except Exception as e:
        print(f"{RED}❌ {module}@{version}: Connection failed - {e}{RESET}")
        return False

    if integrity:
        if not integrity.startswith("sha256-"):
            print(f"{YELLOW}⚠️  {module}@{version}: Unknown integrity format (expected sha256-){RESET}")
            return True # Soft pass

        expected_hash = integrity.replace("sha256-", "")
        actual_hash = calculate_sha256(content)

        if expected_hash != actual_hash:
            print(f"{RED}❌ {module}@{version}: Checksum Mismatch!{RESET}")
            print(f"   Expected: {expected_hash}")
            print(f"   Actual:   {actual_hash}")
            return False
    else:
        print(f"{YELLOW}⚠️  {module}@{version}: No integrity hash defined (insecure){RESET}")

    print(f"{GREEN}✅ {module}@{version}: Healthy (Verified SHA256){RESET}")
    return True

def main():
    parser = argparse.ArgumentParser(description="Validate Bazel Registry Health")
    parser.add_argument("--registry", default="infrastructure/bcr-playground", help="Path to registry (default: infrastructure/bcr-playground)")
    args = parser.parse_args()

    registry_path = args.registry
    modules_dir = os.path.join(registry_path, "modules")

    print(f"🏥 Validating Registry Integrity: {os.path.abspath(registry_path)}")
    print("-" * 60)

    if not os.path.exists(modules_dir):
        print(f"{RED}CRITICAL: Registry modules directory not found at {modules_dir}{RESET}")
        sys.exit(1)

    all_healthy = True
    total_checked = 0

    for module in sorted(os.listdir(modules_dir)):
        mod_path = os.path.join(modules_dir, module)
        if not os.path.isdir(mod_path): continue

        metadata_path = os.path.join(mod_path, "metadata.json")
        if not os.path.exists(metadata_path):
            print(f"{RED}❌ {module}: Missing metadata.json{RESET}")
            all_healthy = False
            continue

        try:
            with open(metadata_path, 'r') as f:
                versions = json.load(f).get("versions", [])
        except json.JSONDecodeError:
            print(f"{RED}❌ {module}: Invalid metadata.json{RESET}")
            all_healthy = False
            continue

        for ver in versions:
            total_checked += 1
            if not validate_module_version(registry_path, module, ver):
                all_healthy = False

    print("-" * 60)
    if total_checked == 0:
        print(f"{YELLOW}⚠️  Registry is empty.{RESET}")
    elif all_healthy:
        print(f"{GREEN}🎉 All systems operational. Registry is healthy.{RESET}")
        sys.exit(0)
    else:
        print(f"{RED}💥 Registry has errors. Please fix before deploying.{RESET}")
        sys.exit(1)

if __name__ == "__main__":
    main()