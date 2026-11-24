-- =============================================================================
-- eulibcurl_task_demo.ex - Cooperative multitasking demo with std/task.e
--
-- Usage:
--   eui demo\eulibcurl_task_demo.ex [URL]
--   (Defaults to https://httpbin.org/bytes/16384 when no argument is provided)
-- =============================================================================

include std/cmdline.e
include std/os.e
include std/task.e
include eulibcurl/euLibCurlAsync.ew as async

sequence args = command_line()
sequence target_url = "https://httpbin.org/bytes/16384"
if length(args) >= 3 then
    target_url = args[3]
end if

integer worker_cycles = 0
integer req_id = 0

procedure background_worker()
    while async:curl_async_is_running(req_id, 0) do
        worker_cycles += 1
        task_delay(0.01)
    end while
end procedure

-- Start internal cooperative curl_multi pumping task
atom pump_tid = async:curl_async_start_task(0.01, 0.03)
printf(1, "Pump task started (id=%d). Dispatching async GET to %s\n", {pump_tid, target_url})

req_id = async:curl_async_get(target_url, "", {
    {"timeout", 15}
})

atom worker_tid = task_create(routine_id("background_worker"), {})
task_schedule(worker_tid, 1)

-- Task 0 loop: monitors progress while pump_task and worker_task run cooperatively
integer last_reported = -1
while async:curl_async_is_running(req_id, 0) do
    sequence prog = async:curl_async_progress(req_id, 0)
    if worker_cycles != last_reported then
        last_reported = worker_cycles
        printf(1, "\rWorker cycles=%d | Received=%d / %d bytes (%.1f%%)   ", {
            worker_cycles,
            prog[async:PROG_DL_NOW],
            prog[async:PROG_DL_TOTAL],
            prog[async:PROG_DL_PERCENT]
        })
    end if
    task_delay(0.01)
end while

sequence resp = async:curl_async_response(req_id)
printf(1, "\nFinished! Status=%s | HTTP=%d | Bytes=%d | Worker cycles=%d\n", {
    async:curl_async_status_name(resp[async:RESP_STATUS]),
    resp[async:RESP_HTTP_CODE],
    length(resp[async:RESP_BODY]),
    worker_cycles
})

async:curl_async_release(req_id)
async:curl_async_shutdown()
