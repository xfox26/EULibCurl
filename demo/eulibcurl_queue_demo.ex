-- =============================================================================
-- eulibcurl_queue_demo.ex - Batch download with FIFO queue (max_concurrent = 4)
--
-- Configures concurrency to 4 simultaneous downloads, enqueues 100 downloads,
-- and prints the final status of each operation as soon as it finishes.
--
-- Usage:
--   eui demo\eulibcurl_queue_demo.ex [BASE_URL]
--   (Defaults to https://httpbin.org when no argument is provided)
-- =============================================================================

include std/filesys.e
include eulibcurl/euLibCurlAsync.ew as async

constant
    TOTAL_DOWNLOADS = 100,
    MAX_CONCURRENT  = 4

sequence args = command_line()
sequence base_url = "https://httpbin.org"
if length(args) >= 3 then
    base_url = args[3]
    if length(base_url) > 0 and base_url[$] = '/' then
        base_url = base_url[1..$-1]
    end if
end if

integer completed_count = 0
integer ok_count = 0
integer err_count = 0
atom total_bytes = 0

procedure on_download_complete(integer req_id, integer final_status)
    integer item_num = async:curl_async_get_userdata(req_id)
    sequence info = async:curl_async_info(req_id, 0)

    completed_count += 1
    if final_status = async:ASYNC_STATUS_DONE then
        ok_count += 1
        total_bytes += info[async:INFO_DL_NOW]
    else
        err_count += 1
    end if

    sequence status_txt = async:curl_async_status_name(final_status)
    integer running_now = async:curl_async_running_count(0)
    integer pending_now = async:curl_async_pending_count(0)

    if final_status = async:ASYNC_STATUS_DONE then
        printf(1, "[%3d/%3d] Item #%03d (req #%3d) -> %-9s | HTTP %3d | %5d B | %.2fs | running=%d queued=%2d\n", {
            completed_count, TOTAL_DOWNLOADS, item_num, req_id,
            status_txt, info[async:INFO_HTTP_CODE], info[async:INFO_DL_NOW],
            info[async:INFO_ELAPSED], running_now, pending_now
        })
    else
        printf(1, "[%3d/%3d] Item #%03d (req #%3d) -> %-9s | %s | running=%d queued=%2d\n", {
            completed_count, TOTAL_DOWNLOADS, item_num, req_id,
            status_txt, info[async:INFO_ERROR], running_now, pending_now
        })
    end if

    -- Clean up temporary file and release request memory immediately
    sequence out_path = info[async:INFO_OUTPUT_FILE]
    if length(out_path) > 0 and file_exists(out_path) then
        delete_file(out_path)
    end if
    async:curl_async_release(req_id)
end procedure

-- Create temporary directory for downloaded files
sequence out_dir = current_dir() & "\\eulibcurl_queue_tmp"
if not file_exists(out_dir) then
    create_directory(out_dir)
end if

-- Configure real FIFO concurrency queue with a limit of 4 simultaneous downloads
async:curl_async_init(0, 0, MAX_CONCURRENT)

printf(1, "=== FIFO Queue Demo (max_concurrent = %d, total = %d downloads) ===\n", {
    async:curl_async_get_max_concurrent(), TOTAL_DOWNLOADS
})
printf(1, "Target server: %s\n\n", {base_url})

atom t_start = time()
integer cb_done = routine_id("on_download_complete")

for i = 1 to TOTAL_DOWNLOADS do
    sequence url = sprintf("%s/bytes/4096?item=%d", {base_url, i})
    sequence dst = sprintf("%s\\item_%03d.bin", {out_dir, i})
    async:curl_async_download(url, dst, {
        {"timeout", 30},
        {"user_data", i},
        {"on_complete", cb_done}
    })
end for

integer peak_running = async:curl_async_running_count(0)
printf(1, "Enqueued all items: %d running now, %d waiting in FIFO queue.\n\n", {
    peak_running, async:curl_async_pending_count(0)
})

-- Wait for all 100 operations without blocking the event loop
while async:curl_async_active_count(0) > 0 do
    async:curl_async_wait_step(25)
    integer cur_running = async:curl_async_running_count(0)
    if cur_running > peak_running then
        peak_running = cur_running
    end if
end while

atom elapsed = time() - t_start

if file_exists(out_dir) then
    remove_directory(out_dir)
end if
async:curl_async_shutdown()

printf(1, "\n=== Final Summary ===\n", {})
printf(1, "Total completed   : %d/%d\n", {completed_count, TOTAL_DOWNLOADS})
printf(1, "Succeeded (DONE)  : %d\n", {ok_count})
printf(1, "Errors/Cancelled  : %d\n", {err_count})
printf(1, "Total transferred : %.1f KB\n", {total_bytes / 1024.0})
printf(1, "Peak concurrent   : %d (configured limit: %d)\n", {peak_running, MAX_CONCURRENT})
printf(1, "Total elapsed     : %.2fs\n", {elapsed})
