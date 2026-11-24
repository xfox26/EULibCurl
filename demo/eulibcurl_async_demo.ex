-- =============================================================================
-- eulibcurl_async_demo.ex - Non-blocking async requests & download demo
--
-- Usage:
--   eui demo\eulibcurl_async_demo.ex [BASE_URL]
--   (Defaults to https://httpbin.org when no argument is provided)
-- =============================================================================

include std/filesys.e
include std/os.e
include eulibcurl/euLibCurlAsync.ew as async

sequence args = command_line()
sequence base_url = "https://httpbin.org"
if length(args) >= 3 then
    base_url = args[3]
    if length(base_url) > 0 and base_url[$] = '/' then
        base_url = base_url[1..$-1]
    end if
end if

procedure on_done_proc(integer req_id, integer final_status)
    sequence info = async:curl_async_info(req_id, 0)
    printf(1, "\n[Callback on_complete] Req #%d -> %s (HTTP %d, %d bytes in %.2fs)\n", {
        req_id,
        async:curl_async_status_name(final_status),
        info[async:INFO_HTTP_CODE],
        info[async:INFO_DL_NOW],
        info[async:INFO_ELAPSED]
    })
end procedure

function progress_bar(atom pct)
    if pct < 0 then
        return "[   ...   ]"
    end if
    integer filled = floor(pct / 10)
    if filled > 10 then
        filled = 10
    end if
    return "[" & repeat('#', filled) & repeat('-', 10 - filled) & sprintf(" %5.1f%%", {pct}) & "]"
end function

sequence out_file = temp_file(current_dir(), "eulibcurl_demo_", ".bin")
integer cb_done = routine_id("on_done_proc")

printf(1, "Dispatching 3 async requests against %s ...\n", {base_url})

integer r_get = async:curl_async_get(base_url & "/get", "", {
    {"timeout", 15},
    {"on_complete", cb_done}
})

integer r_post = async:curl_async_post(
    base_url & "/post",
    `{"project":"euLibCurl","mode":"async"}`,
    {
        {"headers", {"Content-Type: application/json"}},
        {"timeout", 15},
        {"on_complete", cb_done}
    }
)

integer r_dl = async:curl_async_download(base_url & "/bytes/32768", out_file, {
    {"timeout", 15},
    {"on_complete", cb_done}
})

integer ticks = 0
while async:curl_async_active_count(1) > 0 do
    -- Simulates continuous main-loop work without blocking
    ticks += 1
    sequence i1 = async:curl_async_info(r_get, 0)
    sequence i2 = async:curl_async_info(r_post, 0)
    sequence i3 = async:curl_async_info(r_dl, 0)

    printf(1, "\rTick=%03d | GET:%s | POST:%s | DL:%s %dB   ", {
        ticks,
        async:curl_async_status_name(i1[async:INFO_STATUS]),
        async:curl_async_status_name(i2[async:INFO_STATUS]),
        progress_bar(i3[async:INFO_DL_PERCENT]),
        i3[async:INFO_DL_NOW]
    })

    sleep(0.02)
end while

printf(1, "\n\nCompleted after %d free main-loop iterations!\n", {ticks})
if file_exists(out_file) then
    printf(1, "Downloaded file size (%s): %d bytes\n", {out_file, file_length(out_file)})
    delete_file(out_file)
end if

async:curl_async_release(r_get)
async:curl_async_release(r_post)
async:curl_async_release(r_dl)
async:curl_async_shutdown()
