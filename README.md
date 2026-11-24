> 🌐 **English** | [Português (BR)](README.pt-BR.md)

# euLibCurl & euLibCurlAsync — libcurl 8.15.0 for OpenEuphoria 4.1+

Complete networking library (**HTTP/1.1, HTTP/2, HTTP/3, HTTPS, WebSockets, FTP/FTPS, SFTP, SMTP, IMAP, POP3, MIME, and URL API**) for **OpenEuphoria 4.1+** (32-bit and 64-bit), powered by official **libcurl 8.15.0_5** builds (`LibreSSL/4.1.0`, `zlib-ng`, `brotli`, `zstd`, `nghttp2`, `ngtcp2`, `nghttp3`, `libssh2`, `WinIDN`, `ASYNCHDNS`).

---

## Documentation

| Document | Contents |
|---|---|
| **[Core Library Reference (`docs/API_EULIBCURL.md`)](docs/API_EULIBCURL.md)** | All **107 public routines** (100% of all 96 DLL exports + helpers), all **5 structured enums** (`VI_*`, `EOPT_*`, `HDR_*`, `MMSG_*`, `WS_*`), per-handle memory management, `LONG` / `POINTER` / `OFF_T` / `BLOB` dispatch, and the **1,127 constants** in `curl_constants.e` (`namespace curl_const`). |
| **[Async Sub-Library Reference (`docs/API_ASYNC.md`)](docs/API_ASYNC.md)** | All **40 public routines**, all **4 public enums** (`ASYNC_STATUS_*`, `INFO_*`, `PROG_*`, `RESP_*`), real **FIFO concurrency queue (`max_concurrent`)**, on-demand `output_file` creation, all **31 request options** (`opts`), callback signatures, state machine, and practical recipes (`loop`, GUI timers, batch downloads, `std/task.e`). |

---

## Repository Layout

```text
euLibCurl/
├── eu.cfg                        # -i include (runs directly from a fresh clone)
├── LICENSE                       # MIT License
├── CHANGELOG.md
├── README.md                     # English guide (default)
├── README.pt-BR.md               # Portuguese (BR) guide
├── bin/
│   ├── libcurl-x32.dll           # Official libcurl 8.15.0_5 Win32 DLL
│   ├── libcurl-x64.dll           # Official libcurl 8.15.0_5 Win64 DLL
│   └── THIRD_PARTY_NOTICES.txt   # Licenses & SHA-256 checksums
├── include/
│   └── eulibcurl/
│       ├── curl_constants.e      # namespace curl_const — 1,127 libcurl 8.15.0 constants
│       ├── euLibCurl.ew          # namespace curl       — 107 routines (96/96 DLL exports)
│       └── euLibCurlAsync.ew     # namespace curl_async — 40 routines (non-blocking curl_multi)
├── docs/
│   ├── API_EULIBCURL.md          # Complete core API reference (EN)
│   ├── API_ASYNC.md              # Complete async API reference (EN)
│   └── pt-BR/
│       ├── API_EULIBCURL.md      # Complete core API reference (PT-BR)
│       └── API_ASYNC.md          # Complete async API reference (PT-BR)
├── demo/
│   ├── eulibcurl_basic_demo.ex
│   ├── eulibcurl_async_demo.ex
│   ├── eulibcurl_queue_demo.ex
│   └── eulibcurl_task_demo.ex
└── tests/
    ├── run_tests.py              # Self-contained local HTTP test server & runner
    ├── t_eulibcurl.e
    └── t_eulibcurl_async.e
```

---

## Requirements & Installation

1. **OpenEuphoria 4.1+** (32-bit or 64-bit).
2. **Run directly from a clone:**
   ```powershell
   git clone https://github.com/xfox26/EULibCurl.git
   cd EULibCurl
   eui demo\eulibcurl_basic_demo.ex
   ```
   The included `eu.cfg` (`-i include`) and automatic `bin/` DLL lookup let all demos and tests run immediately without modifying your global OpenEuphoria installation.
3. **Install globally into OpenEuphoria (optional):**
   - Copy `include/eulibcurl/` into `C:\Euphoria\include\eulibcurl\`.
   - Copy `bin/libcurl-x32.dll` and `bin/libcurl-x64.dll` into `C:\Euphoria\bin\` (or your app directory / `PATH`).
   - On Linux/Unix, `euLibCurl.ew` automatically loads `libcurl.so.4` / `libcurl.so`.

---

## Quick Start

### Example 1 — Simple Synchronous GET (`euLibCurl.ew`)

```euphoria
include eulibcurl/euLibCurl.ew as curl

sequence res = curl:curl_easy_get_file("https://httpbin.org/get")
if res[1] = curl:CURLE_OK then
    printf(1, "Received %d bytes:\n%s\n", {length(res[2]), res[2]})
else
    printf(1, "Error (%d): %s\n", {res[1], curl:curl_easy_strerror(res[1])})
end if
```

### Example 2 — Non-Blocking Async Downloads & POST (`euLibCurlAsync.ew`)

```euphoria
include std/os.e
include eulibcurl/euLibCurlAsync.ew as async

integer id1 = async:curl_async_get("https://httpbin.org/delay/2")
integer id2 = async:curl_async_download("https://httpbin.org/bytes/65536", "output.bin")

integer ticks = 0
while async:curl_async_is_running(id1) or async:curl_async_is_running(id2) do
    ticks += 1
    sequence p2 = async:curl_async_progress(id2, 0)
    printf(1, "\rTick=%d | DL #2: %d/%d bytes (%.1f%%)   ", {
        ticks, p2[async:PROG_DL_NOW], p2[async:PROG_DL_TOTAL], p2[async:PROG_DL_PERCENT]
    })
    sleep(0.02)
end while
puts(1, "\n")

async:curl_async_release(id1)
async:curl_async_release(id2)
async:curl_async_shutdown()
```

### Example 3 — Batch Downloads with FIFO Concurrency Queue (`max_concurrent`)

```euphoria
include eulibcurl/euLibCurlAsync.ew as async

procedure on_done(integer req_id, integer final_status)
    sequence info = async:curl_async_info(req_id, 0)
    printf(1, "Req #%d -> %s (HTTP %d, %d bytes)\n", {
        req_id, async:curl_async_status_name(final_status),
        info[async:INFO_HTTP_CODE], info[async:INFO_DL_NOW]
    })
    async:curl_async_release(req_id)
end procedure

-- Run at most 4 downloads concurrently; remaining items stay queued in ASYNC_STATUS_PENDING
async:curl_async_init(0, 0, 4)

for i = 1 to 100 do
    async:curl_async_download(
        sprintf("https://httpbin.org/bytes/4096?item=%d", {i}),
        sprintf("item_%03d.bin", {i}),
        {{"timeout", 30}, {"on_complete", routine_id("on_done")}}
    )
end for

while async:curl_async_active_count(0) > 0 do
    async:curl_async_wait_step(25)
end while

async:curl_async_shutdown()
```

---

## Key Highlights & Best Practices

1. **Windows HTTPS (`CURLSSLOPT_NATIVE_CA`):**
   - `euLibCurlAsync.ew` and `curl_easy_get_file()` automatically enable `CURLSSLOPT_NATIVE_CA` on Windows when `ssl_verify = 1` and no custom `ca_info`/`ca_path` is provided, validating certificates against the Windows trust store.
2. **Windows `cdecl` Callbacks:**
   - Always create libcurl callback pointers with **`curl:curl_callback(routine_id(...))`** (which uses `call_back({'+', rid})` on Windows).
3. **On-Demand `output_file` Creation:**
   - In `euLibCurlAsync.ew`, output files are opened lazily when the first data chunk arrives (or created empty if the server returns `CURLE_OK` with 0 bytes, excluding `HEAD`). Pre-data errors (bad URL, DNS, timeout, TLS, cancellation) never create 0-byte ghost files.
4. **Releasing Completed Requests:**
   - Call `curl_async_release(req_id)` after reading response data (or inside `on_complete` for large batches) to free response buffers promptly.

---

## Demos & Automated Tests

Run the full offline test suite (starts a local Python `ThreadingHTTPServer`, zero external dependencies):

```powershell
python tests/run_tests.py
```

| File | Description |
|---|---|
| [`demo/eulibcurl_basic_demo.ex`](demo/eulibcurl_basic_demo.ex) | Inspects `curl_version_info()`, `curl_url*`, synchronous GET with `curl_slist`, `curl_easy_getinfo()`, and `curl_easy_nextheader()`. |
| [`demo/eulibcurl_async_demo.ex`](demo/eulibcurl_async_demo.ex) | Parallel GET, JSON POST, and disk download with a real-time progress bar without blocking the main loop. |
| [`demo/eulibcurl_queue_demo.ex`](demo/eulibcurl_queue_demo.ex) | Batch download of 100 files using the FIFO queue (`max_concurrent = 4`), printing each item's status as it finishes. |
| [`demo/eulibcurl_task_demo.ex`](demo/eulibcurl_task_demo.ex) | Cooperative multitasking using `curl_async_start_task()` and `std/task.e`. |
| [`tests/run_tests.py`](tests/run_tests.py) | Self-contained local HTTP test server and runner. |
| [`tests/t_eulibcurl.e`](tests/t_eulibcurl.e) | Core wrapper unit & HTTP integration suite (`77/77` assertions). |
| [`tests/t_eulibcurl_async.e`](tests/t_eulibcurl_async.e) | Async sub-library integration suite (`98/98` assertions). |

---

## License

MIT License — see [LICENSE](LICENSE) and [bin/THIRD_PARTY_NOTICES.txt](bin/THIRD_PARTY_NOTICES.txt).
