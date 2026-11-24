# Changelog

All notable changes to **euLibCurl** will be documented in this file.

## [1.0.0] - 2026-11-24

### Added
- **Complete OpenEuphoria 4.1+ wrapper (`euLibCurl.ew`, `namespace curl`):**
  - 100% coverage of all **96** exported functions from official **libcurl 8.15.0_5** (`libcurl-x32.dll` / `libcurl-x64.dll`) across Global, Easy, Options/Headers, Slist, Multi, Share, MIME, URL API, WebSockets, HTTP/2 Push, legacy Form/Escape, and `curl_m*printf` families.
  - Typed option dispatch for `C_LONG`, `C_POINTER`, `C_LONGLONG` (`*_LARGE`), and automatic `struct curl_blob` marshaling.
  - Safe `cdecl` callback helper (`curl_callback`) on Windows and isolated per-handle memory tracking (no global leaks/double-frees).
  - Complete `curl_constants.e` (`namespace curl_const`) with **1,127** constants verified 1:1 against `curl_easy_option_next()` (323/323 options).
- **Non-blocking async sub-library (`euLibCurlAsync.ew`, `namespace curl_async`):**
  - Built on `curl_multi_*` with native `ASYNCHDNS` (non-blocking DNS resolution).
  - Real **FIFO concurrency queue (`max_concurrent`)** with `curl_async_set_max_concurrent`, `curl_async_get_max_concurrent`, `curl_async_pending_count`, and `curl_async_running_count`.
  - **On-demand `output_file` creation:** files are opened only when the first data chunk arrives (or created empty on `CURLE_OK` with 0-byte body, excluding `HEAD`), preventing 0-byte ghost files on pre-data errors.
  - Support for streaming to disk, `resume_from`, `multipart/form-data` (`"form"`), pause/resume/cancel, `on_progress`/`on_chunk`/`on_complete` callbacks, automatic Windows native CA store (`CURLSSLOPT_NATIVE_CA`), and cooperative `std/task.e` integration.
- **Demos, Automated Tests, and Bilingual Documentation:**
  - 4 runnable demos (`basic`, `async`, `queue`, `task`).
  - Self-contained local test runner (`tests/run_tests.py`) executing 164 assertions (`66` unit + `98` async integration).
  - Full API reference documentation in **English** (default) and **Portuguese (BR)**.
