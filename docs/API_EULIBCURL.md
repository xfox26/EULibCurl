> 🌐 **English** | [Português (BR)](pt-BR/API_EULIBCURL.md) | [README](../README.md)

# Complete API Reference — `euLibCurl.ew` & `curl_constants.e` (libcurl 8.15.0)

Exhaustive documentation for the core library (`include eulibcurl/euLibCurl.ew as curl`), covering:
- All **107 public routines** exposed by `euLibCurl.ew` (`namespace curl`), spanning **100% of all 96 functions exported** by `libcurl-x32.dll` / `libcurl-x64.dll` (v8.15.0_5) plus Euphoria helpers;
- All **5 public structured enums** (`VI_*`, `EOPT_*`, `HDR_*`, `MMSG_*`, `WS_*`);
- Complete catalog of the **1,127 constants** in `curl_constants.e` (`namespace curl_const`, automatically re-exported via `public include`).

---

## Table of Contents

1. [Modules, Namespaces, and DLL Loading](#1-modules-namespaces-and-dll-loading)
2. [Public Structured Enums](#2-public-structured-enums)
3. [DLL Introspection and Callbacks (`cdecl`)](#3-dll-introspection-and-callbacks-cdecl)
4. [Global, Version, and Utilities](#4-global-version-and-utilities)
5. [Linked Lists (`curl_slist`)](#5-linked-lists-curl_slist)
6. [Easy Core Interface](#6-easy-core-interface)
7. [Options Introspection and Header API](#7-options-introspection-and-header-api)
8. [Multi Interface (`curl_multi_*`)](#8-multi-interface-curl_multi_)
9. [Share Interface (`curl_share_*`)](#9-share-interface-curl_share_)
10. [MIME Interface (Modern Multipart)](#10-mime-interface-modern-multipart)
11. [URL API (`curl_url*`)](#11-url-api-curl_url)
12. [WebSockets API (`curl_ws_*`)](#12-websockets-api-curl_ws_)
13. [HTTP/2 Server Push Headers](#13-http2-server-push-headers)
14. [Legacy API (`curl_form*`, `curl_escape`, `curl_unescape`)](#14-legacy-api-curl_form-curl_escape-curl_unescape)
15. [`curl_m*printf` Family](#15-curl_mprintf-family)
16. [Modern Synchronous Helpers](#16-modern-synchronous-helpers)
17. [Complete Constants Catalog (`curl_constants.e`)](#17-complete-constants-catalog-curl_constants_e)

---

## 1. Modules, Namespaces, and DLL Loading

```euphoria
include eulibcurl/euLibCurl.ew as curl
```

- **`euLibCurl.ew`** defines `namespace curl` and re-exports `curl_constants.e` via `public include eulibcurl/curl_constants.e`.
- On load, the module detects the host architecture and automatically opens:
  - Windows 64-bit (`ifdef BITS64`): `bin/libcurl-x64.dll` or `libcurl-x64.dll`
  - Windows 32-bit (`ifdef WINDOWS`): `bin/libcurl-x32.dll` or `libcurl-x32.dll`
  - Unix/Linux: `libcurl.so.4` or `libcurl.so`
- If the library or any exported C symbol cannot be loaded, the module fails immediately via `error:crash(...)` identifying the missing library/symbol.
- **Per-Handle Memory Management:** The wrapper maintains an internal `handle_allocs` map indexed by `atom curl`, allocating and tracking buffers only for options where libcurl does not copy data (`CURLOPT_POSTFIELDS` and `CURLOPT_ERRORBUFFER`). All tracked buffers for a handle are freed automatically on `curl_easy_cleanup(curl)`, `curl_easy_reset(curl)`, or when overwritten by an external pointer.

---

## 2. Public Structured Enums

Functions that decode C structs return a `sequence` indexed by the public 1-based enums below.

### 2.1 `VI_*` — Return of `curl_version_info()` (27 fields)

| Index | Value | Type | Meaning (`curl_version_info_data` field) |
|---|---|---|---|
| `VI_AGE` | `1` | `integer` | Struct age (`CURLVERSION_*`, e.g., `11` in 8.15.0). |
| `VI_VERSION` | `2` | `sequence` | libcurl version string (e.g., `"8.15.0"`). |
| `VI_VERSION_NUM` | `3` | `atom` | Hexadecimal version number (e.g., `#080F00`). |
| `VI_HOST` | `4` | `sequence` | Host build triple (e.g., `"i686-w64-mingw32"`). |
| `VI_FEATURES` | `5` | `atom` | Compiled feature bitmask (`CURL_VERSION_*`). |
| `VI_SSL_VERSION` | `6` | `sequence` | TLS backend string (e.g., `"LibreSSL/4.1.0"`). |
| `VI_SSL_VERSION_NUM` | `7` | `atom` | Legacy SSL version number (`0` on modern builds). |
| `VI_LIBZ_VERSION` | `8` | `sequence` | zlib version string (e.g., `"1.3.1.zlib-ng"`). |
| `VI_PROTOCOLS` | `9` | `sequence` | List of supported protocol strings (e.g., `{"http", "https", ...}`). |
| `VI_ARES` | `10` | `sequence` | c-ares version (or `""` when using threaded resolver). |
| `VI_ARES_NUM` | `11` | `integer` | Numeric c-ares version. |
| `VI_LIBIDN` | `12` | `sequence` | IDN library version (if present). |
| `VI_ICONV_VER_NUM` | `13` | `integer` | iconv version number (if present). |
| `VI_LIBSSH_VERSION` | `14` | `sequence` | libssh2 version (e.g., `"libssh2/1.11.1"`). |
| `VI_BROTLI_VER_NUM` | `15` | `atom` | Numeric Brotli version. |
| `VI_BROTLI_VERSION` | `16` | `sequence` | Brotli version string (e.g., `"1.1.0"`). |
| `VI_NGHTTP2_VER_NUM` | `17` | `atom` | Numeric nghttp2 version. |
| `VI_NGHTTP2_VERSION` | `18` | `sequence` | nghttp2 version string (e.g., `"1.66.0"`). |
| `VI_QUIC_VERSION` | `19` | `sequence` | HTTP/3 / QUIC string (e.g., `"ngtcp2/1.15.0 nghttp3/1.11.0"`). |
| `VI_CAINFO` | `20` | `sequence` | Default built-in CA bundle path (or `""`). |
| `VI_CAPATH` | `21` | `sequence` | Default CA directory path (or `""`). |
| `VI_ZSTD_VER_NUM` | `22` | `atom` | Numeric zstd version. |
| `VI_ZSTD_VERSION` | `23` | `sequence` | zstd version string (e.g., `"1.5.7"`). |
| `VI_HYPER_VERSION` | `24` | `sequence` | Hyper backend version (or `""`). |
| `VI_GSASL_VERSION` | `25` | `sequence` | libgsasl version (or `""`). |
| `VI_FEATURE_NAMES` | `26` | `sequence` | List of human-readable feature names (e.g., `"AsynchDNS"`, `"HTTP2"`, `"HTTP3"`). |
| `VI_RTMP_VERSION` | `27` | `sequence` | RTMP library version (or `""`). |

### 2.2 `EOPT_*` — Return of `curl_easy_option_*()` (5 fields)

| Index | Value | Type | Meaning (`struct curl_easyoption`) |
|---|---|---|---|
| `EOPT_NAME` | `1` | `sequence` | Option name without `CURLOPT_` prefix (e.g., `"URL"`). |
| `EOPT_ID` | `2` | `integer` | Numeric `CURLOPT_*` ID (e.g., `10002`). |
| `EOPT_TYPE` | `3` | `integer` | Option type (`CURLOT_LONG` .. `CURLOT_FUNCTION`). |
| `EOPT_FLAGS` | `4` | `atom` | Option flags (e.g., `CURLOT_FLAG_ALIAS = 1`). |
| `EOPT_RAW_PTR` | `5` | `atom` | Raw C struct pointer (passed as `prev` to `curl_easy_option_next()`). |

### 2.3 `HDR_*` — Return of `curl_easy_header()` / `curl_easy_nextheader()` (7 fields)

| Index | Value | Type | Meaning (`struct curl_header`) |
|---|---|---|---|
| `HDR_NAME` | `1` | `sequence` | HTTP header name. |
| `HDR_VALUE` | `2` | `sequence` | HTTP header value (without `\r\n`). |
| `HDR_AMOUNT` | `3` | `atom` | Total occurrences of this header name in the response. |
| `HDR_INDEX` | `4` | `atom` | 0-based index of this specific occurrence. |
| `HDR_ORIGIN` | `5` | `atom` | Origin bitmask (`CURLH_HEADER`, `CURLH_TRAILER`, `CURLH_CONNECT`, `CURLH_1XX`, `CURLH_PSEUDO`). |
| `HDR_ANCHOR` | `6` | `atom` | Opaque internal libcurl pointer. |
| `HDR_RAW_PTR` | `7` | `atom` | Raw C struct pointer (passed as `prev` to `curl_easy_nextheader()`). |

### 2.4 `MMSG_*` — Return of `curl_multi_info_read()` (4 fields)

| Index | Value | Type | Meaning (`CURLMsg`) |
|---|---|---|---|
| `MMSG_MSG` | `1` | `integer` | Message type (`CURLMSG_DONE = 1`). |
| `MMSG_EASY_HANDLE` | `2` | `atom` | `CURL *` easy handle associated with the message. |
| `MMSG_RESULT` | `3` | `integer` | Final transfer `CURLcode` (`CURLE_OK = 0` or error). |
| `MMSG_QUEUED` | `4` | `integer` | Remaining messages still queued in the multi handle. |

### 2.5 `WS_*` — WebSocket Frame Metadata (`curl_ws_recv()` / `curl_ws_meta()`) (5 fields)

| Index | Value | Type | Meaning (`struct curl_ws_frame`) |
|---|---|---|---|
| `WS_AGE` | `1` | `integer` | Struct version (`0`). |
| `WS_FLAGS` | `2` | `integer` | Flag bitmask (`CURLWS_TEXT`, `CURLWS_BINARY`, `CURLWS_CONT`, `CURLWS_CLOSE`, `CURLWS_PING`, `CURLWS_PONG`, `CURLWS_OFFSET`). |
| `WS_OFFSET` | `3` | `atom` | Byte offset of the current fragment within the frame (64-bit `curl_off_t`). |
| `WS_BYTESLEFT` | `4` | `atom` | Remaining bytes in the frame payload (64-bit `curl_off_t`). |
| `WS_LEN` | `5` | `atom` | Size of the current delivered chunk (`size_t`). |

---

## 3. DLL Introspection and Callbacks (`cdecl`)

### `curl_dll_handle()`
Returns the native `atom` handle returned by `open_dll()` for the loaded libcurl shared library.

### `curl_linked_count()`
Returns the number of distinct C symbols linked from the DLL (`96` in libcurl 8.15.0).

### `curl_linked_names()`
Returns a `sequence` of strings containing the exact names of all linked C functions/procedures.

### `curl_callback(integer rid)`
Creates an executable C callback pointer compatible with libcurl's `cdecl` convention (`call_back({'+', rid})` on Windows, `call_back(rid)` on Unix). Calls `error:crash()` if `rid < 0`.

---

## 4. Global, Version, and Utilities

### `curl_global_init(atom flags = CURL_GLOBAL_DEFAULT)`
Initializes global libcurl state (Winsock, TLS, etc.). Returns `CURLE_OK` (`0`) on success.

### `curl_global_init_mem(atom flags, atom malloc_cb, atom free_cb, atom realloc_cb, atom strdup_cb, atom calloc_cb)`
Initializes global libcurl state with custom C memory allocator callbacks (`cdecl`). Returns `CURLE_OK` on success.

### `curl_global_cleanup()` *(procedure)*
Releases global resources initialized by `curl_global_init()`.

### `curl_global_sslset(integer backend_id = -1, sequence backend_name = "")`
Selects the SSL backend before `curl_global_init()` or queries available backends when called with defaults. Returns `{CURLsslset_code, backend_list}` where each entry is `{id, name}`.

### `curl_global_trace(sequence config)`
Configures global libcurl trace logging (e.g., `"all"`, `"tcp,http/2"`). Returns `CURLE_OK` or an error code.

### `curl_version()`
Returns a human-readable `sequence` describing the libcurl version and linked libraries.

### `curl_version_info_raw(integer age = CURLVERSION_NOW)`
Returns the raw C pointer (`atom`) to `curl_version_info_data`.

### `curl_version_info(integer age = CURLVERSION_NOW)`
Returns a `sequence` indexed by `VI_*` (see [Section 2.1](#21-vi_--return-of-curl_version_info-27-fields)), or `{}` if the DLL returns `NULL`.

### `curl_free(atom ptr)` *(procedure)*
Frees memory allocated by libcurl itself (safely ignores `0`). **Never** pass static strings such as `curl_*_strerror()` results.

### `curl_getdate(sequence datestr, atom unused_now = 0)`
Parses an HTTP/RFC date string into a 64-bit Unix timestamp (`atom`), or `-1` if invalid.

### `curl_getenv(sequence name)`
Reads an environment variable via `curl_getenv`, freeing the returned C pointer. Returns `""` if unset.

### `curl_strequal(sequence s1, sequence s2)`
Case-insensitive string equality (`1` if equal, `0` otherwise).

### `curl_strnequal(sequence s1, sequence s2, atom max_len)`
Case-insensitive prefix equality up to `max_len` characters (`1` if equal, `0` otherwise).

---

## 5. Linked Lists (`curl_slist`)

### `curl_slist_append(atom slist, sequence item)`
Appends `item` to `slist` (pass `0` to start a new list). Returns the new head pointer (`atom`) or `0` on out-of-memory.

### `curl_slist_free_all(atom slist)` *(procedure)*
Frees the entire linked list (safely ignores `0`).

### `curl_slist_from_sequence(sequence items)`
Helper that creates a `curl_slist` from a Euphoria sequence of strings. Cleans up and returns `0` if any allocation fails.

### `curl_slist_to_sequence(atom slist)`
Converts a `curl_slist *` into a Euphoria `sequence` of strings without freeing the original list.

---

## 6. Easy Core Interface

### `curl_easy_init()`
Creates and returns a new Easy Handle (`atom`), or `0` on failure.

### `curl_easy_cleanup(atom curl)` *(procedure)*
Closes the Easy Handle and automatically frees all buffers tracked for it in `handle_allocs`. Safely ignores `0`.

### `curl_easy_reset(atom curl)` *(procedure)*
Resets all handle options to defaults (preserving connection cache) and frees tracked buffers for this handle.

### `curl_easy_duphandle(atom curl)`
Duplicates an Easy Handle along with its configured options. Returns the new `atom` handle (or `0` on failure).

### `curl_easy_setopt(atom curl, integer opt, object param)`
Configures options on an Easy Handle and returns `CURLcode` (`CURLE_OK = 0` on success).
- **Automatic type dispatch based on `opt`:**
  - `30000 <= opt < 40000` (**`OFF_T`**): passes `C_LONGLONG` (requires `atom`/`integer`).
  - `40000 <= opt < 50000` (**`BLOB`**): if `sequence(param)`, packs into `struct curl_blob` with `CURL_BLOB_COPY`, submits, and frees the temporary struct immediately. If `atom(param)`, passes raw pointer.
  - `opt < 10000` (**`LONG`**): passes `C_LONG`.
  - `10000 <= opt < 30000` (**`STRING`/`OBJECT`/`SLIST`/`FUNCTION`**):
    - For `CURLOPT_POSTFIELDS` with a `sequence`, allocates a binary-safe buffer tracked in `handle_allocs` (freed on overwrite/reset/cleanup).
    - For all other string options (`CURLOPT_URL`, `CURLOPT_COPYPOSTFIELDS`, `CURLOPT_USERAGENT`, etc.), allocates a temporary C string, submits to libcurl (which copies it internally), and frees immediately.
    - For an `atom`, passes the raw pointer/value directly.

### `curl_easy_perform(atom curl)`
Executes a transfer **synchronously (blocking)** until completion. Returns `CURLcode`.

### `curl_easy_getinfo_raw(atom curl, integer info, atom out_ptr)`
Calls `curl_easy_getinfo`, writing the raw result into caller-provided `out_ptr` (minimum 8 bytes). Returns `CURLcode`.

### `curl_easy_getinfo(atom curl, integer info)`
Queries transfer metadata and automatically decodes according to `and_bits(info, CURLINFO_TYPEMASK)`. Returns `{CURLcode, value}` (or `{rc, 0}` on error). Automatically converts `CURLINFO_SSL_ENGINES` and `CURLINFO_COOKIELIST` slists into Euphoria sequences and frees the C slist.

### `curl_easy_pause(atom curl, integer bitmask)`
Pauses or resumes receive/send (`CURLPAUSE_ALL`, `CURLPAUSE_RECV`, `CURLPAUSE_SEND`, `CURLPAUSE_CONT`). Returns `CURLcode`.

### `curl_easy_escape(atom curl, sequence text)`
Binary-safe URL-encoding preserving embedded `\0` bytes. Frees the DLL buffer via `curl_free()`.

### `curl_easy_unescape(atom curl, sequence text)`
Binary-safe URL-decoding preserving embedded `\0` bytes (via `outlength`). Frees the DLL buffer via `curl_free()`.

### `curl_easy_recv(atom curl, integer max_len = 16384)`
Receives up to `max_len` raw bytes from a `CURLOPT_CONNECT_ONLY` handle. Returns `{CURLcode, received_bytes}`.

### `curl_easy_send(atom curl, sequence data)`
Sends raw `data` over a `CURLOPT_CONNECT_ONLY` handle. Returns `{CURLcode, bytes_sent}`.

### `curl_easy_strerror(integer err_code)`
Converts a `CURLcode` (`CURLE_*`) into a human-readable string (safe — never calls `curl_free`).

### `curl_easy_upkeep(atom curl)`
Sends connection upkeep frames (e.g., HTTP/2 PING) on idle connections. Returns `CURLcode`.

### `curl_easy_ssls_export(atom curl, atom export_cb, atom userptr = 0)`
Iterates over cached TLS sessions/tickets via `export_cb` (created with `curl_callback()`). Returns `CURLcode`.

### `curl_easy_ssls_import(atom curl, sequence session_key, sequence shmac, sequence sdata)`
Imports a previously exported TLS session/ticket into the handle (or associated `share`). Returns `CURLcode`.

---

## 7. Options Introspection and Header API

### `curl_easy_option_by_id(integer id)`
Looks up `CURLOPT_*` metadata by numeric ID. Returns a `sequence` indexed by `EOPT_*` or `{}`.

### `curl_easy_option_by_name(sequence name)`
Looks up option metadata by name **without** the `CURLOPT_` prefix (e.g., `"URL"`, `"FOLLOWLOCATION"`). Returns `EOPT_*` sequence or `{}`.

### `curl_easy_option_next(object prev = 0)`
Iterates through all supported options in libcurl 8.15.0. Pass `0` to start, and the previous sequence (or `EOPT_RAW_PTR`) to advance; returns `{}` when finished.

### `curl_easy_header(atom curl, sequence name, atom index = 0, atom origin = CURLH_HEADER, integer request = -1)`
Queries HTTP header `name` from `request` (`-1` = final request), with `origin` (`CURLH_*`) and 0-based `index`. Returns `{CURLHcode, header_seq}` (`HDR_*`) or `{CURLHcode, {}}`.

### `curl_easy_nextheader(atom curl, atom origin = CURLH_HEADER, integer request = -1, object prev = 0)`
Iterates through received headers. Pass `0` for the first and the previous sequence for subsequent calls; returns `{}` at end.

---

## 8. Multi Interface (`curl_multi_*`)

Non-blocking foundation used internally by [euLibCurlAsync.ew](API_ASYNC.md).

### `curl_multi_init()`
Creates a multi handle (`atom`), or `0` on failure.

### `curl_multi_cleanup(atom multi)`
Cleans up the multi handle and returns `CURLMcode`.

### `curl_multi_add_handle(atom multi, atom easy)`
Attaches an easy handle to `multi`. Returns `CURLMcode`.

### `curl_multi_remove_handle(atom multi, atom easy)`
Detaches an easy handle from `multi`. Returns `CURLMcode`.

### `curl_multi_perform(atom multi)`
Performs pending non-blocking transfer steps. Returns `{CURLMcode, running_handles}`.

### `curl_multi_wait(atom multi, integer timeout_ms = 50, atom extra_fds = 0, integer extra_nfds = 0)`
Waits for socket activity up to `timeout_ms` (returns immediately if no active descriptors). Returns `{CURLMcode, numfds}`.

### `curl_multi_poll(atom multi, integer timeout_ms = 50, atom extra_fds = 0, integer extra_nfds = 0)`
Like `curl_multi_wait()`, but sleeps up to `timeout_ms` even with no active descriptors and can be woken via `curl_multi_wakeup()`. Returns `{CURLMcode, numfds}`.

### `curl_multi_waitfds(atom multi, atom ufds_ptr = 0, integer ufds_size = 0)`
Queries socket descriptors awaited by `multi`. Returns `{CURLMcode, fd_count}`.

### `curl_multi_wakeup(atom multi)`
Wakes a blocked `curl_multi_poll()` call immediately. Returns `CURLMcode`.

### `curl_multi_info_read(atom multi)`
Reads the next event from `multi`. Returns `{}` if empty, or `{msg, easy_handle, result, msgs_in_queue}` indexed by `MMSG_*`.

### `curl_multi_setopt(atom multi, integer opt, object param)`
Configures `CURLMOPT_*` options (`C_LONGLONG`, `C_LONG`, or `C_POINTER`/string). Returns `CURLMcode`.

### `curl_multi_timeout(atom multi)`
Queries recommended maximum wait time in milliseconds (`-1` if no timer pending). Returns `{CURLMcode, timeout_ms}`.

### `curl_multi_fdset(atom multi, atom read_fd_set, atom write_fd_set, atom exc_fd_set)`
Populates native `fd_set` structures for `select()`. Returns `{CURLMcode, max_fd}`.

### `curl_multi_socket(atom multi, atom sock)` *(legacy)*
Legacy socket-event API. Returns `{CURLMcode, running_handles}`.

### `curl_multi_socket_action(atom multi, atom sock, integer ev_bitmask)`
Event-driven socket notification (`CURL_CSELECT_*` or `CURL_SOCKET_TIMEOUT`). Returns `{CURLMcode, running_handles}`.

### `curl_multi_socket_all(atom multi)` *(legacy)*
Triggers action on all multi sockets. Returns `{CURLMcode, running_handles}`.

### `curl_multi_assign(atom multi, atom sock, atom sockptr)`
Associates a user pointer with a socket in the `socket_action` model. Returns `CURLMcode`.

### `curl_multi_strerror(integer err_code)`
Converts `CURLM_*` code to a descriptive string.

### `curl_multi_get_handles(atom multi)`
Returns a `sequence` of all easy handles currently attached to `multi` (and frees the internal C array).

---

## 9. Share Interface (`curl_share_*`)

Shares DNS cache, cookies, SSL sessions, connections, or PSL across easy handles via `CURLOPT_SHARE`.

### `curl_share_init()`
Creates a share handle (`atom`), or `0` on failure.

### `curl_share_cleanup(atom share)`
Frees the share handle and returns `CURLSHcode`.

### `curl_share_setopt(atom share, integer opt, atom param)`
Configures `CURLSHOPT_SHARE`, `CURLSHOPT_UNSHARE`, `CURLSHOPT_LOCKFUNC`, `CURLSHOPT_UNLOCKFUNC`, `CURLSHOPT_USERDATA`. Returns `CURLSHcode`.

### `curl_share_strerror(integer err_code)`
Converts `CURLSHE_*` code to a descriptive string.

---

## 10. MIME Interface (Modern Multipart)

Builds `multipart/form-data` payloads for `CURLOPT_MIMEPOST`.

### `curl_mime_init(atom curl)`
Creates a `curl_mime` structure associated with `curl`. Returns `atom` (or `0`).

### `curl_mime_free(atom mime)` *(procedure)*
Frees `mime` and all its parts/subparts (ignores `0`).

### `curl_mime_addpart(atom mime)`
Adds a new empty part and returns its handle (`atom`).

### `curl_mime_name(atom part, sequence name)`
Sets the field name of `part`. Returns `CURLcode`.

### `curl_mime_data(atom part, sequence data)`
Sets binary-safe part data (copied internally by libcurl). Returns `CURLcode`.

### `curl_mime_data_cb(atom part, atom datasize, atom readfunc, atom seekfunc = 0, atom freefunc = 0, atom arg = 0)`
Streams part data via C callbacks (`datasize` is `C_LONGLONG`; pass `-1` if unknown). Returns `CURLcode`.

### `curl_mime_filedata(atom part, sequence filename)`
Attaches a file on disk as part content. Returns `CURLcode`.

### `curl_mime_filename(atom part, object filename)`
Sets the remote `filename="..."` attribute (pass `0` to clear). Returns `CURLcode`.

### `curl_mime_type(atom part, object mimetype)`
Sets the part `Content-Type` header (or `0` to clear). Returns `CURLcode`.

### `curl_mime_encoder(atom part, object encoding)`
Sets `Content-Transfer-Encoding` (`"base64"`, `"quoted-printable"`, `"binary"`, or `0`). Returns `CURLcode`.

### `curl_mime_headers(atom part, atom headers_slist, integer take_ownership = 0)`
Attaches custom headers (`curl_slist`) to the part. If `take_ownership = 1`, `curl_mime_free()` frees the slist automatically. Returns `CURLcode`.

### `curl_mime_subparts(atom part, atom subparts_mime)`
Nests another `curl_mime` object as multipart subparts. Returns `CURLcode`.

---

## 11. URL API (`curl_url*`)

RFC 3986 / WHATWG-compliant URL parser, builder, and normalizer.

### `curl_url()`
Creates a `CURLU *` handle (`atom`), or `0`.

### `curl_url_cleanup(atom url_handle)` *(procedure)*
Frees the `CURLU` handle (ignores `0`).

### `curl_url_dup(atom url_handle)`
Duplicates a `CURLU` handle with all parsed parts.

### `curl_url_get(atom url_handle, integer what, atom flags = 0)`
Extracts a URL part (`CURLUPART_*`) with optional `CURLU_*` flags. Returns `{CURLUcode, string_value}` (automatically calls `curl_free`).

### `curl_url_set(atom url_handle, integer what, object part, atom flags = 0)`
Sets or clears (`0`) a URL part (`CURLUPART_*`) with optional `CURLU_*` flags. Returns `CURLUcode`.

### `curl_url_strerror(integer err_code)`
Converts `CURLUE_*` code to a descriptive string.

---

## 12. WebSockets API (`curl_ws_*`)

Used after connecting to `ws://` / `wss://` with `curl_easy_setopt(eh, CURLOPT_CONNECT_ONLY, 2)` and `curl_easy_perform(eh)`.

### `curl_ws_recv(atom curl, integer max_len = 65536)`
Receives up to `max_len` bytes of a WebSocket frame. Returns `{CURLcode, received_bytes, ws_meta}` where `ws_meta` is `{}` or indexed by `WS_*`.

### `curl_ws_send(atom curl, sequence data, atom flags = CURLWS_TEXT, atom fragsize = 0)`
Sends a WebSocket frame or fragment (`fragsize` is `C_LONGLONG`). Returns `{CURLcode, bytes_sent}`.

### `curl_ws_meta(atom curl)`
Returns `WS_*` metadata (or `{}`) for the current WebSocket frame.

---

## 13. HTTP/2 Server Push Headers

Used inside a `CURLMOPT_PUSHFUNCTION` callback when receiving HTTP/2 Server Push streams.

### `curl_pushheader_bynum(atom push_headers, atom num)`
Returns the 0-based header `num` as a `sequence` (`""` if invalid).

### `curl_pushheader_byname(atom push_headers, sequence name)`
Returns the value of push header `name` as a `sequence` (`""` if absent).

---

## 14. Legacy API (`curl_form*`, `curl_escape`, `curl_unescape`)

Retained for 100% DLL export coverage. Prefer **`curl_mime_*`** and **`curl_easy_escape()` / `curl_easy_unescape()`** for new code.

### `curl_formadd(atom first_pp, atom last_pp, sequence pairs)`
Typed wrapper for `curl_formadd` accepting 1 to 6 `{{CURLFORM_*, value}, ...}` pairs (automatically appending `CURLFORM_END`). Returns `CURLFORMcode`.

### `curl_formfree(atom form)` *(procedure)*
Frees a list built by `curl_formadd()`.

### `curl_formget(atom form, atom arg, atom append_cb)`
Serializes a `curl_formadd` form via `append_cb`. Returns `0` on success.

### `curl_escape(sequence text)`
Legacy global URL-encoding. Returns escaped string and calls `curl_free()`.

### `curl_unescape(sequence text)`
Legacy 2-argument URL-decoding (up to first `\0`). Calls `curl_free()`. Use `curl_easy_unescape()` for binary data containing `\0`.

---

## 15. `curl_m*printf` Family

All 10 `mprintf` exports are linked for 96/96 coverage. **In Euphoria, prefer native `printf()` and `sprintf()`.**

- **`curl_mprintf(sequence text)`**: prints `text` to `stdout` via `"%s"`.
- **`curl_mfprintf(atom c_file_ptr, sequence text)`**: prints `text` to a C `FILE *`.
- **`curl_msprintf(atom out_buf, sequence text)`**: writes `text` into C buffer `out_buf`.
- **`curl_msnprintf(atom out_buf, atom max_len, sequence text)`**: writes up to `max_len` bytes into `out_buf`.
- **`curl_maprintf(sequence text)`**: formats via DLL, copies as `sequence`, and calls `curl_free()`.
- **`curl_mvprintf(sequence fmt, atom va_args_ptr = 0)`**: raw `va_list` variant to `stdout`.
- **`curl_mvfprintf(atom c_file_ptr, sequence fmt, atom va_args_ptr = 0)`**: raw `va_list` variant to `FILE *`.
- **`curl_mvsprintf(atom out_buf, sequence fmt, atom va_args_ptr = 0)`**: raw `va_list` variant to `out_buf`.
- **`curl_mvsnprintf(atom out_buf, atom max_len, sequence fmt, atom va_args_ptr = 0)`**: raw `va_list` bounded variant.
- **`curl_mvaprintf(sequence fmt, atom va_args_ptr = 0)`**: raw `va_list` allocating variant; returns `sequence` and calls `curl_free()`.

---

## 16. Modern Synchronous Helpers

### `curl_easy_perform_ex(atom curl)`
Runs a synchronous transfer on `curl`, capturing the full response body in a per-handle buffer via a single `cdecl` callback. Returns `{CURLcode, body_sequence}`.

### `curl_easy_get_file(sequence url, sequence proxy = "", sequence filename = "")`
Performs a complete synchronous HTTP/HTTPS download (enables `CURLOPT_FOLLOWLOCATION = 1` and `CURLSSLOPT_NATIVE_CA` on Windows). Always calls `curl_easy_cleanup()`.
- If `length(filename) > 0`: writes to `filename` (`"wb"`) only on `CURLE_OK` and returns `CURLcode` (or `CURLE_CANT_OPEN_FILE = 500` if the file cannot be opened).
- If `filename = ""`: returns `{CURLcode, body_sequence}`.

### `atoms_to_double(atom lo, atom hi)`
Zero-allocation helper converting two 32-bit little-endian values (`lo`, `hi`) into a 64-bit IEEE-754 `atom`.

---

## 17. Complete Constants Catalog (`curl_constants.e`)

`curl_constants.e` (`namespace curl_const`, publicly re-exported by `euLibCurl.ew`) defines **1,127 constants** extracted directly from official libcurl **8.15.0_5** headers:

| Prefix / Group | Count / Range | Purpose & Common Values |
|---|---|---|
| `CURLE_*` | `0..102` + `CURLE_CANT_OPEN_FILE = 500` | Easy interface error codes: `CURLE_OK (0)`, `CURLE_UNSUPPORTED_PROTOCOL (1)`, `CURLE_URL_MALFORMAT (3)`, `CURLE_COULDNT_RESOLVE_HOST (6)`, `CURLE_COULDNT_CONNECT (7)`, `CURLE_HTTP_RETURNED_ERROR (22)`, `CURLE_WRITE_ERROR (23)`, `CURLE_OPERATION_TIMEDOUT (28)`, `CURLE_SSL_CONNECT_ERROR (35)`, `CURLE_ABORTED_BY_CALLBACK (42)`, `CURLE_TOO_MANY_REDIRECTS (47)`, `CURLE_PEER_FAILED_VERIFICATION (60)`. |
| `CURLOPTTYPE_*` | Type offsets | `LONG (0)`, `OBJECTPOINT / STRINGPOINT / SLISTPOINT / CBPOINT (10000)`, `FUNCTIONPOINT (20000)`, `OFF_T (30000)`, `BLOB (40000)`, `VALUES (0)`. |
| `CURLOPT_*` | **323 options** (100% of 8.15.0 DLL) + aliases | E.g., `CURLOPT_URL (10002)`, `CURLOPT_HTTPHEADER (10023)`, `CURLOPT_POST (47)`, `CURLOPT_POSTFIELDS (10015)`, `CURLOPT_POSTFIELDSIZE_LARGE (30120)`, `CURLOPT_CUSTOMREQUEST (10036)`, `CURLOPT_NOBODY (44)`, `CURLOPT_FOLLOWLOCATION (52)`, `CURLOPT_MAXREDIRS (68)`, `CURLOPT_TIMEOUT_MS (155)`, `CURLOPT_CONNECTTIMEOUT_MS (156)`, `CURLOPT_WRITEFUNCTION (20011)`, `CURLOPT_WRITEDATA (10001)`, `CURLOPT_HEADERFUNCTION (20079)`, `CURLOPT_XFERINFOFUNCTION (20219)`, `CURLOPT_NOPROGRESS (43)`, `CURLOPT_SSL_VERIFYPEER (64)`, `CURLOPT_SSL_VERIFYHOST (81)`, `CURLOPT_SSL_OPTIONS (216)`, `CURLOPT_CAINFO_BLOB (40309)`, `CURLOPT_MIMEPOST (10269)`, `CURLOPT_MAX_RECV_SPEED_LARGE (30146)`, `CURLOPT_RESUME_FROM_LARGE (30116)`. |
| `CURLOT_*` | `0..8` + `CURLOT_FLAG_ALIAS (1)` | Option types in `curl_easy_option_*`: `CURLOT_LONG (0)` .. `CURLOT_FUNCTION (8)`. |
| `CURLINFO_*` | Masks + ~65 fields | Type masks (`CURLINFO_STRING` .. `CURLINFO_OFF_T`, `CURLINFO_TYPEMASK`) and transfer info fields (`RESPONSE_CODE`, `EFFECTIVE_URL`, `TOTAL_TIME`, `CONTENT_TYPE`, `SIZE_DOWNLOAD_T`, `SPEED_DOWNLOAD_T`, `REDIRECT_COUNT`, `HTTP_VERSION`, etc.). |
| `CURLM_*` / `CURLMOPT_*` / `CURLMSG_*` | Multi Interface | Error codes (`CURLM_CALL_MULTI_PERFORM (-1)`, `CURLM_OK (0)` .. `12`), multi options (`MAX_TOTAL_CONNECTIONS`, `MAX_HOST_CONNECTIONS`, `PIPELINING`, etc.), `CURLMSG_DONE (1)`, polling constants (`CURL_WAIT_*`, `CURL_POLL_*`, `CURL_CSELECT_*`, `CURLPIPE_*`). |
| `CURLSHE_*` / `CURLSHOPT_*` / `CURL_LOCK_*` | Share Interface | Share error codes, options, lock data types (`COOKIE`, `DNS`, `SSL_SESSION`, `CONNECT`, `PSL`, `HSTS`), and lock access modes. |
| `CURLUE_*` / `CURLUPART_*` / `CURLU_*` | URL API | URL error codes (`0..29`), parts (`URL`..`ZONEID`), and flags (`DEFAULT_PORT`, `URLDECODE`, `URLENCODE`, `APPENDQUERY`, `PUNYCODE`, etc.). |
| `CURLH_*` / `CURLHE_*` | Header API | Header origins (`HEADER`, `TRAILER`, `CONNECT`, `1XX`, `PSEUDO`) and error codes (`0..7`). |
| `CURLWS_*` | WebSockets API | Frame flags (`TEXT`, `BINARY`, `CONT`, `CLOSE`, `PING`, `PONG`, `OFFSET`) and `CURLOPT_WS_OPTIONS` (`RAW_MODE`, `NOAUTOPONG`). |
| `CURL_GLOBAL_*` / SSL / HTTP / Proxy / Auth / Pause | General flags | `CURL_GLOBAL_DEFAULT (3)`, `CURLSSLOPT_NATIVE_CA (16)`, `CURL_HTTP_VERSION_*`, `CURLPROXY_*`, `CURLAUTH_*`, `CURLPAUSE_*`, `CURL_IPRESOLVE_*`, `CURLVERSION_NOW (11)`, `CURL_VERSION_*`, `CURL_BLOB_NOCOPY/COPY`, `CURL_PUSH_*`, `CURL_SOCKET_BAD (-1)`, `CURL_ZERO_TERMINATED (-1)`, `CURL_ERROR_SIZE (256)`. |
