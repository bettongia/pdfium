/*
 * Copyright 2026 The Authors. See the AUTHORS file for details.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * PDFium shared-library smoke test.
 *
 * Loads the library at the path given on the command line, resolves
 * FPDF_InitLibraryWithConfig and FPDF_DestroyLibrary via dlopen/dlsym,
 * calls them, and exits 0 on success.
 *
 * Usage: smoke_test <path-to-libpdfium.dylib|.so>
 *
 * Compile (macOS): cc -o smoke_test smoke_test.c
 * Compile (Linux): cc -o smoke_test smoke_test.c -ldl
 */

#include <stdio.h>
#include <string.h>
#include <dlfcn.h>

/* Minimal FPDF_LIBRARY_CONFIG matching version 2 of the PDFium ABI.
 * Zeroed fields instruct PDFium to use safe defaults (no V8, no custom fonts). */
typedef struct {
    int version;
    const char **m_pUserFontPaths;
    void *m_pIsolate;
    unsigned int m_v8EmbedderSlot;
} FPDF_LIBRARY_CONFIG;

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s <path-to-libpdfium>\n", argv[0]);
        return 1;
    }

    void *lib = dlopen(argv[1], RTLD_LAZY | RTLD_LOCAL);
    if (!lib) {
        fprintf(stderr, "smoke_test: dlopen failed: %s\n", dlerror());
        return 1;
    }

    void (*fpdf_init)(const FPDF_LIBRARY_CONFIG *) =
        (void (*)(const FPDF_LIBRARY_CONFIG *))dlsym(lib, "FPDF_InitLibraryWithConfig");
    void (*fpdf_destroy)(void) =
        (void (*)(void))dlsym(lib, "FPDF_DestroyLibrary");

    if (!fpdf_init) {
        fprintf(stderr, "smoke_test: symbol FPDF_InitLibraryWithConfig not found\n");
        dlclose(lib);
        return 1;
    }
    if (!fpdf_destroy) {
        fprintf(stderr, "smoke_test: symbol FPDF_DestroyLibrary not found\n");
        dlclose(lib);
        return 1;
    }

    FPDF_LIBRARY_CONFIG config;
    memset(&config, 0, sizeof(config));
    config.version = 2;

    fpdf_init(&config);
    fpdf_destroy();
    dlclose(lib);

    printf("smoke_test: %s OK\n", argv[1]);
    return 0;
}
