-- =============================================================================
-- t_eulibcurl_async.e - Integration tests for euLibCurlAsync.ew
--
-- Usage:
--   eui tests\t_eulibcurl_async.e http://127.0.0.1:<PORT>
-- =============================================================================

include std/cmdline.e
include std/error.e
include std/filesys.e
include std/io.e
include std/map.e
include std/os.e
include std/task.e
include std/unittest.e
include eulibcurl/euLibCurlAsync.ew as async

sequence args = command_line()
sequence base_url = ""
for ai = 3 to length(args) do
    if match("http", args[ai]) = 1 then
        base_url = args[ai]
        exit
    end if
end for
if length(base_url) = 0 then
    error:crash("Provide the local HTTP test server base URL as an argument.", {})
end if
if base_url[$] = '/' then
    base_url = base_url[1..$-1]
end if

-- Shared state for callback verification
integer prog_calls = 0
integer prog_saw_intermediate = 0
integer chunk_calls = 0
sequence completed_ids = {}
sequence completed_statuses = {}

function on_prog_cb(integer req_id, sequence prog)
    {} = req_id
    prog_calls += 1
    if prog[async:PROG_DL_PERCENT] > 0 and prog[async:PROG_DL_PERCENT] < 100 then
        prog_saw_intermediate = 1
    end if
    return 1
end function

function on_chunk_abort_cb(integer req_id, sequence chunk)
    {} = {req_id, chunk}
    chunk_calls += 1
    -- Abort after receiving the first chunk
    return 0
end function

procedure on_done_cb(integer req_id, integer final_status)
    completed_ids = append(completed_ids, req_id)
    completed_statuses = append(completed_statuses, final_status)
end procedure

async:curl_async_init(8, 4)

-- -----------------------------------------------------------------------------
-- 1. Slow GET: verifies non-blocking execution + gradual progress 0% -> 100%
-- -----------------------------------------------------------------------------
prog_calls = 0
prog_saw_intermediate = 0
completed_ids = {}
completed_statuses = {}

integer slow_id = async:curl_async_get(base_url & "/slow", "", {
    {"on_progress", routine_id("on_prog_cb")},
    {"on_complete", routine_id("on_done_cb")},
    {"user_data", "slow-tag"}
})
test_true("slow_id > 0", slow_id > 0)
test_equal("user_data preserved", "slow-tag", async:curl_async_get_userdata(slow_id))

integer free_loop_ticks = 0
integer saw_partial_bytes = 0

while async:curl_async_is_running(slow_id, 1) do
    free_loop_ticks += 1
    sequence inf = async:curl_async_info(slow_id, 0)
    atom dl_now = inf[async:INFO_DL_NOW]
    atom dl_tot = inf[async:INFO_DL_TOTAL]
    if dl_now > 0 and dl_tot > 0 and dl_now < dl_tot then
        saw_partial_bytes = 1
    end if
    sleep(0.01)
end while

test_true("main loop ran freely (> 5 iterations)", free_loop_ticks > 5)
test_true("observed intermediate progress or on_progress", saw_partial_bytes or prog_saw_intermediate)
test_equal("slow_id status DONE", async:ASYNC_STATUS_DONE, async:curl_async_status(slow_id, 0))
test_equal("slow_id on_complete invoked", {slow_id}, completed_ids)
test_equal("slow_id callback status DONE", {async:ASYNC_STATUS_DONE}, completed_statuses)

sequence slow_resp = async:curl_async_response(slow_id)
test_equal("slow HTTP 200", 200, slow_resp[async:RESP_HTTP_CODE])
test_equal("slow body 30000 bytes", 30000, length(slow_resp[async:RESP_BODY]))
async:curl_async_release(slow_id)

-- -----------------------------------------------------------------------------
-- 2. Parallel execution (4 concurrent 0.30s requests should take << 1.2s)
-- -----------------------------------------------------------------------------
atom t0 = time()
sequence pids = {}
for i = 1 to 4 do
    pids = append(pids, async:curl_async_get(sprintf("%s/delay?ms=300&i=%d", {base_url, i})))
end for
integer rem = async:curl_async_wait_all(5000, 10)
atom dt = time() - t0
test_equal("wait_all remaining == 0", 0, rem)
test_true("4 parallel requests faster than sequential (< 0.9s)", dt < 0.9)
for i = 1 to 4 do
    test_equal(sprintf("parallel #%d DONE", {i}), async:ASYNC_STATUS_DONE, async:curl_async_status(pids[i], 0))
    async:curl_async_release(pids[i])
end for

-- -----------------------------------------------------------------------------
-- 3. POST JSON + headers, PUT, PATCH, DELETE, HEAD
-- -----------------------------------------------------------------------------
integer id_post = async:curl_async_post(base_url & "/echo", `{"ok":true}`, {
    {"headers", {"Content-Type: application/json", "X-Custom: AsyncTest"}}
})
integer id_put = async:curl_async_put(base_url & "/echo", "put-payload")
integer id_patch = async:curl_async_patch(base_url & "/echo", "patch-payload")
integer id_del = async:curl_async_delete(base_url & "/echo")
integer id_head = async:curl_async_head(base_url & "/echo")

test_equal("wait_all verbs == 0", 0, async:curl_async_wait_all(5000, 10))

sequence b_post = async:curl_async_body(id_post)
test_true("POST method and body", match("METHOD=POST", b_post) > 0 and match(`{"ok":true}`, b_post) > 0)
test_true("POST custom header", match("X-Custom: AsyncTest", b_post) > 0)

sequence b_put = async:curl_async_body(id_put)
test_true("PUT method and body", match("METHOD=PUT", b_put) > 0 and match("put-payload", b_put) > 0)

sequence b_patch = async:curl_async_body(id_patch)
test_true("PATCH method and body", match("METHOD=PATCH", b_patch) > 0 and match("patch-payload", b_patch) > 0)

sequence b_del = async:curl_async_body(id_del)
test_true("DELETE method", match("METHOD=DELETE", b_del) > 0)

sequence r_head = async:curl_async_response(id_head)
test_equal("HEAD status DONE", async:ASYNC_STATUS_DONE, r_head[async:RESP_STATUS])
test_equal("HEAD HTTP 200", 200, r_head[async:RESP_HTTP_CODE])
test_equal("HEAD empty body", "", r_head[async:RESP_BODY])

async:curl_async_release(id_post)
async:curl_async_release(id_put)
async:curl_async_release(id_patch)
async:curl_async_release(id_del)
async:curl_async_release(id_head)

-- -----------------------------------------------------------------------------
-- 4. Multipart/form-data upload ("form")
-- -----------------------------------------------------------------------------
sequence up_tmp = temp_file(current_dir(), "t_up_", ".txt")
integer ufn = open(up_tmp, "wb")
puts(ufn, "uploaded-disk-file-content")
close(ufn)

integer id_mp = async:curl_async_post(base_url & "/multipart", "", {
    {"form", {
        {"field1", "value1"},
        {"memfile", "in-memory-bytes", "mem.bin", "application/octet-stream"},
        {"diskfile", up_tmp, "file"}
    }}
})
test_equal("multipart DONE", async:ASYNC_STATUS_DONE, async:curl_async_wait(id_mp, 5000, 10))
sequence mp_body = async:curl_async_body(id_mp)
test_true("multipart received field1", match("value1", mp_body) > 0)
test_true("multipart received memfile", match("in-memory-bytes", mp_body) > 0)
test_true("multipart received diskfile", match("uploaded-disk-file-content", mp_body) > 0)
async:curl_async_release(id_mp)
if file_exists(up_tmp) then
    delete_file(up_tmp)
end if

-- -----------------------------------------------------------------------------
-- 5. Direct download to disk + resume_from
-- -----------------------------------------------------------------------------
sequence dl_file = temp_file(current_dir(), "t_dl_", ".bin")
integer id_dl = async:curl_async_download(base_url & "/file", dl_file)
test_equal("file download DONE", async:ASYNC_STATUS_DONE, async:curl_async_wait(id_dl, 5000, 10))
test_equal("in-memory body empty when writing to file", "", async:curl_async_body(id_dl))
test_equal("file size is 16384 bytes", 16384, file_length(dl_file))
async:curl_async_release(id_dl)

-- Resume (resume_from = 8192) on a file containing the first half
sequence res_file = temp_file(current_dir(), "t_res_", ".bin")
integer rfn = open(res_file, "wb")
puts(rfn, repeat('A', 8192))
close(rfn)
integer id_res = async:curl_async_download(base_url & "/range", res_file, {
    {"resume_from", 8192}
})
test_equal("resume DONE", async:ASYNC_STATUS_DONE, async:curl_async_wait(id_res, 5000, 10))
test_equal("resume final size == 16384", 16384, file_length(res_file))
sequence res_bytes = read_file(res_file, BINARY_MODE)
test_equal("resume first half == A", repeat('A', 8192), res_bytes[1..8192])
test_equal("resume second half == C", repeat('C', 8192), res_bytes[8193..16384])
async:curl_async_release(id_res)

if file_exists(dl_file) then
    delete_file(dl_file)
end if
if file_exists(res_file) then
    delete_file(res_file)
end if

-- -----------------------------------------------------------------------------
-- 6. Redirects, headers, content-type, and effective_url
-- -----------------------------------------------------------------------------
integer id_redir = async:curl_async_get(base_url & "/redirect")
test_equal("redirect DONE", async:ASYNC_STATUS_DONE, async:curl_async_wait(id_redir, 5000, 10))
sequence rinf = async:curl_async_info(id_redir, 0)
test_equal("redirect HTTP 200", 200, rinf[async:INFO_HTTP_CODE])
test_true("effective_url points to /echo", match("/echo", rinf[async:INFO_EFFECTIVE_URL]) > 0)
test_true("final headers do not contain 302", match("302", rinf[async:INFO_HEADERS][1]) = 0)
test_true("content_type populated", length(rinf[async:INFO_CONTENT_TYPE]) > 0)
async:curl_async_release(id_redir)

-- -----------------------------------------------------------------------------
-- 7. Pause, Resume, and Cancel in flight
-- -----------------------------------------------------------------------------
integer id_ctrl = async:curl_async_get(base_url & "/slow")
test_equal("pause == CURLE_OK", async:CURLE_OK, async:curl_async_pause(id_ctrl))
test_equal("status PAUSED", async:ASYNC_STATUS_PAUSED, async:curl_async_status(id_ctrl, 1))
test_equal("resume == CURLE_OK", async:CURLE_OK, async:curl_async_resume(id_ctrl))
test_equal("cancel == 1", 1, async:curl_async_cancel(id_ctrl))
test_equal("status CANCELLED", async:ASYNC_STATUS_CANCELLED, async:curl_async_status(id_ctrl, 1))
async:curl_async_release(id_ctrl)

-- -----------------------------------------------------------------------------
-- 8. Abort via on_chunk and error handling (timeout)
-- -----------------------------------------------------------------------------
chunk_calls = 0
integer id_abort = async:curl_async_get(base_url & "/slow", "", {
    {"on_chunk", routine_id("on_chunk_abort_cb")}
})
integer abort_st = async:curl_async_wait(id_abort, 5000, 10)
test_equal("abort via on_chunk status ERROR", async:ASYNC_STATUS_ERROR, abort_st)
test_equal("on_chunk called exactly once", 1, chunk_calls)
async:curl_async_release(id_abort)

integer id_to = async:curl_async_get(base_url & "/delay?ms=1500", "", {
    {"timeout", 0.15}
})
integer to_st = async:curl_async_wait(id_to, 5000, 10)
test_equal("timeout status ERROR", async:ASYNC_STATUS_ERROR, to_st)
sequence err_pair = async:curl_async_error(id_to)
test_true("error != CURLE_OK and message populated", err_pair[1] != 0 and length(err_pair[2]) > 0)
async:curl_async_release(id_to)

-- -----------------------------------------------------------------------------
-- 9. Cooperative multitasking integration (std/task.e)
-- -----------------------------------------------------------------------------
atom ptid = async:curl_async_start_task(0.01, 0.02)
test_true("start_task returned valid id", ptid >= 0)
test_equal("task_running == 1", 1, async:curl_async_task_running())

integer id_task_req = async:curl_async_get(base_url & "/delay?ms=200")
integer yield_count = 0
while async:curl_async_is_running(id_task_req, 0) do
    yield_count += 1
    task_yield()
end while
test_true("task_yield executed multiple times", yield_count > 1)
test_equal("task req status DONE", async:ASYNC_STATUS_DONE, async:curl_async_status(id_task_req, 0))
async:curl_async_release(id_task_req)
async:curl_async_stop_task()
test_equal("task_running == 0 after stop", 0, async:curl_async_task_running())

-- -----------------------------------------------------------------------------
-- 10. Real FIFO concurrency queue (max_concurrent)
-- -----------------------------------------------------------------------------
async:curl_async_set_max_concurrent(3)
test_equal("get_max_concurrent == 3", 3, async:curl_async_get_max_concurrent())

-- 10.1 Concurrency limit enforcement and FIFO promotion
sequence q_ids = {}
for qi = 1 to 10 do
    q_ids = append(q_ids, async:curl_async_get(base_url & "/delay?ms=150"))
end for
test_equal("queue: 3 initially running", 3, async:curl_async_running_count(0))
test_equal("queue: 7 initially pending", 7, async:curl_async_pending_count(0))
test_equal("queue: 10 total active", 10, async:curl_async_active_count(0))
test_equal("queue: #1 RUNNING", async:ASYNC_STATUS_RUNNING, async:curl_async_status(q_ids[1], 0))
test_equal("queue: #4 PENDING", async:ASYNC_STATUS_PENDING, async:curl_async_status(q_ids[4], 0))
sequence pend_info = async:curl_async_info(q_ids[4], 0)
test_equal("queue: elapsed == 0 while PENDING", 0, pend_info[async:INFO_ELAPSED])

integer max_seen_running = async:curl_async_running_count(0)
while async:curl_async_active_count(0) > 0 do
    async:curl_async_wait_step(15)
    integer cur_run = async:curl_async_running_count(0)
    if cur_run > max_seen_running then
        max_seen_running = cur_run
    end if
end while
test_true("queue: never exceeded max_concurrent=3", max_seen_running <= 3)
integer q_all_done = 1
for qi = 1 to length(q_ids) do
    if async:curl_async_status(q_ids[qi], 0) != async:ASYNC_STATUS_DONE then
        q_all_done = 0
    end if
    async:curl_async_release(q_ids[qi])
end for
test_equal("queue: all 10 completed DONE", 1, q_all_done)

-- 10.2 Lazy output_file opening (does not create file while PENDING)
async:curl_async_set_max_concurrent(2)
sequence qf_ids = {}
sequence qf_paths = {}
for qi = 1 to 5 do
    sequence qpath = sprintf("%s\\eulibcurl_qfile_%d.bin", {current_dir(), qi})
    if file_exists(qpath) then
        delete_file(qpath)
    end if
    qf_paths = append(qf_paths, qpath)
    qf_ids = append(qf_ids, async:curl_async_download(base_url & "/delay?ms=150", qpath))
end for
test_equal("lazy file: #5 is PENDING", async:ASYNC_STATUS_PENDING, async:curl_async_status(qf_ids[5], 0))
test_equal("lazy file: file #5 does NOT exist while PENDING", 0, file_exists(qf_paths[5]))

integer qf_rem = async:curl_async_wait_all(10000, 15)
test_equal("lazy file: wait_all == 0", 0, qf_rem)
integer qf_ok = 1
for qi = 1 to length(qf_ids) do
    if async:curl_async_status(qf_ids[qi], 0) != async:ASYNC_STATUS_DONE or not file_exists(qf_paths[qi]) then
        qf_ok = 0
    end if
    if file_exists(qf_paths[qi]) then
        delete_file(qf_paths[qi])
    end if
    async:curl_async_release(qf_ids[qi])
end for
test_equal("lazy file: all 5 files created and completed", 1, qf_ok)

-- 10.3 Timeout does NOT tick while waiting in the PENDING queue
async:curl_async_set_max_concurrent(1)
sequence qto_ids = {}
for qi = 1 to 3 do
    -- Each request takes ~180ms; 3 sequentially ~540ms > 0.45s timeout,
    -- yet each individual request takes 180ms < 450ms!
    qto_ids = append(qto_ids, async:curl_async_get(base_url & "/delay?ms=180", "", {
        {"timeout", 0.45}
    }))
end for
integer qto_rem = async:curl_async_wait_all(10000, 15)
test_equal("queue timeout: wait_all == 0", 0, qto_rem)
integer qto_all_ok = 1
for qi = 1 to length(qto_ids) do
    if async:curl_async_status(qto_ids[qi], 0) != async:ASYNC_STATUS_DONE then
        qto_all_ok = 0
    end if
    async:curl_async_release(qto_ids[qi])
end for
test_equal("queue timeout: all 3 succeeded without expiring in queue", 1, qto_all_ok)

-- 10.4 Cancelling a PENDING item and immediate promotion on cancelling RUNNING
async:curl_async_set_max_concurrent(2)
completed_ids = {}
completed_statuses = {}
sequence qcancel_path = current_dir() & "\\eulibcurl_qcancel.bin"
if file_exists(qcancel_path) then
    delete_file(qcancel_path)
end if
integer qc1 = async:curl_async_get(base_url & "/delay?ms=220", "", {
    {"on_complete", routine_id("on_done_cb")}
})
integer qc2 = async:curl_async_get(base_url & "/delay?ms=220", "", {
    {"on_complete", routine_id("on_done_cb")}
})
integer qc3 = async:curl_async_get(base_url & "/delay?ms=220", "", {
    {"on_complete", routine_id("on_done_cb")}
})
integer qc4 = async:curl_async_download(base_url & "/delay?ms=220", qcancel_path, {
    {"on_complete", routine_id("on_done_cb")}
})
test_equal("cancel pending: qc4 is PENDING", async:ASYNC_STATUS_PENDING, async:curl_async_status(qc4, 0))
test_equal("cancel pending: return 1", 1, async:curl_async_cancel(qc4))
test_equal("cancel pending: qc4 status CANCELLED", async:ASYNC_STATUS_CANCELLED, async:curl_async_status(qc4, 0))
test_equal("cancel pending: qc4 file never opened", 0, file_exists(qcancel_path))
test_true("cancel pending: on_complete fired for qc4", find(qc4, completed_ids) > 0)
test_equal("cancel pending: 1 pending left (qc3)", 1, async:curl_async_pending_count(0))

test_equal("cancel running: return 1", 1, async:curl_async_cancel(qc1))
test_equal("cancel running: qc1 CANCELLED", async:ASYNC_STATUS_CANCELLED, async:curl_async_status(qc1, 0))
test_equal("cancel running: qc3 immediately promoted to RUNNING",
    async:ASYNC_STATUS_RUNNING, async:curl_async_status(qc3, 0))
test_equal("cancel running: pending queue empty", 0, async:curl_async_pending_count(0))

integer qc_rem = async:curl_async_wait_all(10000, 15)
test_equal("cancel running: wait_all == 0", 0, qc_rem)
test_equal("cancel running: qc2 DONE", async:ASYNC_STATUS_DONE, async:curl_async_status(qc2, 0))
test_equal("cancel running: qc3 DONE", async:ASYNC_STATUS_DONE, async:curl_async_status(qc3, 0))
async:curl_async_release(qc1)
async:curl_async_release(qc2)
async:curl_async_release(qc3)
async:curl_async_release(qc4)

-- 10.5 Dynamically raising max_concurrent + isolation when reusing options map
async:curl_async_set_max_concurrent(1)
map shared_opts = map:new()
sequence qdyn_ids = {}
for qi = 1 to 4 do
    map:put(shared_opts, "user_data", qi * 100)
    map:put(shared_opts, "headers", {sprintf("X-Queue-Item: %d", {qi})})
    qdyn_ids = append(qdyn_ids, async:curl_async_get(base_url & "/delay?ms=180", "", shared_opts))
end for
test_equal("dynamic: 1 running", 1, async:curl_async_running_count(0))
test_equal("dynamic: 3 queued", 3, async:curl_async_pending_count(0))

async:curl_async_set_max_concurrent(3)
test_equal("dynamic: immediately raised to 3 running", 3, async:curl_async_running_count(0))
test_equal("dynamic: 1 remaining in queue", 1, async:curl_async_pending_count(0))

integer qdyn_rem = async:curl_async_wait_all(10000, 15)
test_equal("dynamic: wait_all == 0", 0, qdyn_rem)
integer qdyn_ud_ok = 1
for qi = 1 to length(qdyn_ids) do
    if async:curl_async_status(qdyn_ids[qi], 0) != async:ASYNC_STATUS_DONE or
       async:curl_async_get_userdata(qdyn_ids[qi]) != qi * 100 then
        qdyn_ud_ok = 0
    end if
    async:curl_async_release(qdyn_ids[qi])
end for
test_equal("dynamic: isolated user_data per request and all DONE", 1, qdyn_ud_ok)

async:curl_async_set_max_concurrent(0)
test_equal("get_max_concurrent == 0 (unlimited)", 0, async:curl_async_get_max_concurrent())

-- -----------------------------------------------------------------------------
-- 11. On-demand output_file creation (no ghost file on error; empty file on CURLE_OK 0B)
-- -----------------------------------------------------------------------------
-- 11.1 Malformed URL (with \r): error before any data -> does NOT create file
sequence bad_url_file = current_dir() & "\\eulibcurl_bad_url.bin"
if file_exists(bad_url_file) then
    delete_file(bad_url_file)
end if
integer id_bad_url = async:curl_async_download(base_url & "/file\r", bad_url_file)
test_equal("bad url status ERROR", async:ASYNC_STATUS_ERROR, async:curl_async_wait(id_bad_url, 5000, 10))
test_equal("bad url did NOT create output file", 0, file_exists(bad_url_file))
async:curl_async_release(id_bad_url)

-- 11.2 Timeout before receiving any byte -> does NOT create file
sequence to_dl_file = current_dir() & "\\eulibcurl_to_dl.bin"
if file_exists(to_dl_file) then
    delete_file(to_dl_file)
end if
integer id_to_dl = async:curl_async_download(base_url & "/delay?ms=1500", to_dl_file, {
    {"timeout", 0.15}
})
test_equal("timeout download status ERROR", async:ASYNC_STATUS_ERROR, async:curl_async_wait(id_to_dl, 5000, 10))
test_equal("timeout download did NOT create output file", 0, file_exists(to_dl_file))
async:curl_async_release(id_to_dl)

-- 11.3 Successful response (HTTP 200 / CURLE_OK) with 0 bytes -> creates 0-byte file
sequence empty_dl_file = current_dir() & "\\eulibcurl_empty_dl.bin"
if file_exists(empty_dl_file) then
    delete_file(empty_dl_file)
end if
integer id_empty = async:curl_async_download(base_url & "/empty", empty_dl_file)
test_equal("empty 200 status DONE", async:ASYNC_STATUS_DONE, async:curl_async_wait(id_empty, 5000, 10))
test_equal("empty 200 created file", 1, file_exists(empty_dl_file))
test_equal("empty 200 file length == 0", 0, file_length(empty_dl_file))
if file_exists(empty_dl_file) then
    delete_file(empty_dl_file)
end if
async:curl_async_release(id_empty)

-- 11.4 Invalid output path (non-existent directory) -> reports CURLE_CANT_OPEN_FILE
integer id_bad_path = async:curl_async_download(
    base_url & "/file",
    current_dir() & "\\non_existent_dir_xyz_999\\out.bin"
)
test_equal("bad output path status ERROR", async:ASYNC_STATUS_ERROR, async:curl_async_wait(id_bad_path, 5000, 10))
sequence bp_err = async:curl_async_error(id_bad_path)
test_equal("bad output path curl_code == CURLE_CANT_OPEN_FILE", async:CURLE_CANT_OPEN_FILE, bp_err[1])
async:curl_async_release(id_bad_path)

async:curl_async_shutdown()
test_report()
