-- =============================================================================
-- t_eulibcurl.e - Unit and integration tests for euLibCurl (libcurl 8.15.0)
--
-- Usage:
--   eui tests\t_eulibcurl.e [LOCAL_BASE_URL]
-- =============================================================================

include std/cmdline.e
include std/filesys.e
include std/io.e
include std/machine.e
include std/search.e
include std/unittest.e
include eulibcurl/euLibCurl.ew as curl

sequence args = command_line()
sequence base_url = ""
for ai = 3 to length(args) do
    if match("http", args[ai]) = 1 then
        base_url = args[ai]
        exit
    end if
end for
if length(base_url) > 0 and base_url[$] = '/' then
    base_url = base_url[1..$-1]
end if

-- 1. DLL export coverage and metadata
test_equal("curl_linked_count() == 96", 96, curl:curl_linked_count())
test_true("curl_dll_handle() != 0", curl:curl_dll_handle() != 0)
test_true("curl_version() starts with libcurl/8.15.0", match("libcurl/8.15.0", curl:curl_version()) = 1)

test_equal("curl_global_init()", curl:CURLE_OK, curl:curl_global_init(curl:CURL_GLOBAL_DEFAULT))

sequence vi = curl:curl_version_info()
test_equal("version_info age == CURLVERSION_NOW (11)", curl:CURLVERSION_NOW, vi[curl:VI_AGE])
test_equal("version_info version == 8.15.0", "8.15.0", vi[curl:VI_VERSION])
test_true("ASYNCHDNS enabled", and_bits(vi[curl:VI_FEATURES], curl:CURL_VERSION_ASYNCHDNS) != 0)
test_true("SSL enabled", and_bits(vi[curl:VI_FEATURES], curl:CURL_VERSION_SSL) != 0)
test_true("HTTP2 enabled", and_bits(vi[curl:VI_FEATURES], curl:CURL_VERSION_HTTP2) != 0)
test_true("feature_names contains AsynchDNS", find("AsynchDNS", vi[curl:VI_FEATURE_NAMES]) > 0)
test_true("protocols contains https", find("https", vi[curl:VI_PROTOCOLS]) > 0)

sequence ssl_q = curl:curl_global_sslset(-1, "")
test_true("curl_global_sslset returns backends", length(ssl_q[2]) >= 1)

-- 2. Regression: strerror must not call curl_free() (testing 0..100)
integer strerror_ok = 1
for code = 0 to 100 do
    sequence msg = curl:curl_easy_strerror(code)
    if length(msg) = 0 then
        strerror_ok = 0
    end if
end for
test_true("curl_easy_strerror(0..100) without crash", strerror_ok)
test_equal("curl_easy_strerror(CURLE_OK)", "No error", curl:curl_easy_strerror(curl:CURLE_OK))
test_true("curl_multi_strerror(CURLM_CALL_MULTI_PERFORM)", length(curl:curl_multi_strerror(curl:CURLM_CALL_MULTI_PERFORM)) > 0)
test_true("curl_share_strerror(CURLSHE_OK)", length(curl:curl_share_strerror(curl:CURLSHE_OK)) > 0)
test_true("curl_url_strerror(CURLUE_OK)", length(curl:curl_url_strerror(curl:CURLUE_OK)) > 0)

-- 3. C utilities and date parsing
test_equal("curl_getdate RFC1123", 1445412480, curl:curl_getdate("Wed, 21 Oct 2015 07:28:00 GMT"))
test_equal("curl_strequal case-insensitive true", 1, curl:curl_strequal("Hello", "hELLo"))
test_equal("curl_strequal false", 0, curl:curl_strequal("Hello", "World"))
test_equal("curl_strnequal prefix", 1, curl:curl_strnequal("libcurl-x32", "LIBCURL-x64", 7))
test_equal("atoms_to_double(0, #3FF00000) == 1.0", 1.0, curl:atoms_to_double(0, #3FF00000))

-- 4. Regression: escape/unescape (legacy 2-arg and easy binary %00)
test_equal("curl_escape", "a%20b%26c", curl:curl_escape("a b&c"))
test_equal("curl_unescape", "a b&c", curl:curl_unescape("a%20b%26c"))

atom eh1 = curl:curl_easy_init()
atom eh2 = curl:curl_easy_init()
test_true("curl_easy_init valid distinct handles", eh1 != 0 and eh2 != 0 and eh1 != eh2)

sequence esc = curl:curl_easy_escape(eh1, {'A', 0, 'B', ' '})
test_equal("curl_easy_escape binary with NUL", "A%00B%20", esc)
sequence unesc = curl:curl_easy_unescape(eh1, esc)
test_equal("curl_easy_unescape binary preserving NUL", {'A', 0, 'B', ' '}, unesc)

-- 5. Regression: multi-handle POSTFIELDS + *_LARGE (64-bit) + reset + cleanup without double-free
test_equal("setopt CURLOPT_MAX_RECV_SPEED_LARGE (64-bit OFF_T)", curl:CURLE_OK,
    curl:curl_easy_setopt(eh1, curl:CURLOPT_MAX_RECV_SPEED_LARGE, 5000000000))
test_equal("setopt CURLOPT_POSTFIELDS eh1", curl:CURLE_OK,
    curl:curl_easy_setopt(eh1, curl:CURLOPT_POSTFIELDS, "payload-1"))
test_equal("setopt CURLOPT_POSTFIELDS eh2", curl:CURLE_OK,
    curl:curl_easy_setopt(eh2, curl:CURLOPT_POSTFIELDS, "payload-2"))
test_equal("setopt CURLOPT_POSTFIELDS overwrite eh1", curl:CURLE_OK,
    curl:curl_easy_setopt(eh1, curl:CURLOPT_POSTFIELDS, "payload-1b"))

atom dup = curl:curl_easy_duphandle(eh1)
test_true("curl_easy_duphandle != 0", dup != 0)
curl:curl_easy_reset(eh1)
curl:curl_easy_cleanup(dup)
curl:curl_easy_cleanup(eh1)
curl:curl_easy_cleanup(eh2)

-- 6. Slist
atom sl = curl:curl_slist_from_sequence({"X-One: 1", "X-Two: 2"})
test_true("curl_slist_from_sequence != 0", sl != 0)
test_equal("curl_slist_to_sequence", {"X-One: 1", "X-Two: 2"}, curl:curl_slist_to_sequence(sl))
curl:curl_slist_free_all(sl)

-- 7. Options Introspection API
sequence opt_url = curl:curl_easy_option_by_name("URL")
test_equal("option_by_name URL id", curl:CURLOPT_URL, opt_url[curl:EOPT_ID])
test_equal("option_by_name URL type", curl:CURLOT_STRING, opt_url[curl:EOPT_TYPE])
sequence opt_id = curl:curl_easy_option_by_id(curl:CURLOPT_MAX_RECV_SPEED_LARGE)
test_equal("option_by_id MAX_RECV_SPEED_LARGE", "MAX_RECV_SPEED_LARGE", opt_id[curl:EOPT_NAME])

integer opt_count = 0
sequence it = curl:curl_easy_option_next(0)
while length(it) > 0 do
    opt_count += 1
    it = curl:curl_easy_option_next(it)
end while
test_true("curl_easy_option_next counted >= 300 options", opt_count >= 300)

-- 8. URL API
atom uh = curl:curl_url()
test_true("curl_url() != 0", uh != 0)
test_equal("curl_url_set URL", curl:CURLUE_OK, curl:curl_url_set(uh, curl:CURLUPART_URL, "https://user:pass@example.com:8443/a/b?x=1#frag"))
test_equal("curl_url_get SCHEME", {curl:CURLUE_OK, "https"}, curl:curl_url_get(uh, curl:CURLUPART_SCHEME))
test_equal("curl_url_get HOST", {curl:CURLUE_OK, "example.com"}, curl:curl_url_get(uh, curl:CURLUPART_HOST))
test_equal("curl_url_get PORT", {curl:CURLUE_OK, "8443"}, curl:curl_url_get(uh, curl:CURLUPART_PORT))
test_equal("curl_url_get PATH", {curl:CURLUE_OK, "/a/b"}, curl:curl_url_get(uh, curl:CURLUPART_PATH))
test_equal("curl_url_get QUERY", {curl:CURLUE_OK, "x=1"}, curl:curl_url_get(uh, curl:CURLUPART_QUERY))
atom uh_dup = curl:curl_url_dup(uh)
test_equal("curl_url_set QUERY append", curl:CURLUE_OK, curl:curl_url_set(uh_dup, curl:CURLUPART_QUERY, "y=2", curl:CURLU_APPENDQUERY))
test_equal("curl_url_get QUERY after append", {curl:CURLUE_OK, "x=1&y=2"}, curl:curl_url_get(uh_dup, curl:CURLUPART_QUERY))
curl:curl_url_cleanup(uh_dup)
curl:curl_url_cleanup(uh)

-- 9. Share & Multi basic handles
atom sh = curl:curl_share_init()
test_true("curl_share_init != 0", sh != 0)
test_equal("curl_share_setopt COOKIE", curl:CURLSHE_OK, curl:curl_share_setopt(sh, curl:CURLSHOPT_SHARE, curl:CURL_LOCK_DATA_COOKIE))
test_equal("curl_share_cleanup", curl:CURLSHE_OK, curl:curl_share_cleanup(sh))

atom mh = curl:curl_multi_init()
atom meh = curl:curl_easy_init()
test_equal("curl_multi_add_handle", curl:CURLM_OK, curl:curl_multi_add_handle(mh, meh))
sequence mhandles = curl:curl_multi_get_handles(mh)
test_equal("curl_multi_get_handles", {meh}, mhandles)
test_equal("curl_multi_remove_handle", curl:CURLM_OK, curl:curl_multi_remove_handle(mh, meh))
test_equal("curl_multi_get_handles empty", {}, curl:curl_multi_get_handles(mh))
curl:curl_easy_cleanup(meh)
test_equal("curl_multi_cleanup", curl:CURLM_OK, curl:curl_multi_cleanup(mh))

-- 10. Local synchronous HTTP tests (when LOCAL_BASE_URL is provided)
if length(base_url) > 0 then
    atom eh = curl:curl_easy_init()
    atom sl_h = curl:curl_slist_from_sequence({"X-Test-Sync: Euphoria41"})
    test_equal("setopt URL", curl:CURLE_OK, curl:curl_easy_setopt(eh, curl:CURLOPT_URL, base_url & "/echo"))
    test_equal("setopt HTTPHEADER", curl:CURLE_OK, curl:curl_easy_setopt(eh, curl:CURLOPT_HTTPHEADER, sl_h))
    sequence ex_res = curl:curl_easy_perform_ex(eh)
    test_equal("curl_easy_perform_ex CURLE_OK", curl:CURLE_OK, ex_res[1])
    test_true("/echo response contains sent header", match("X-Test-Sync: Euphoria41", ex_res[2]) > 0)

    sequence gcode = curl:curl_easy_getinfo(eh, curl:CURLINFO_RESPONSE_CODE)
    test_equal("getinfo RESPONSE_CODE == 200", {curl:CURLE_OK, 200}, gcode)

    sequence hres = curl:curl_easy_header(eh, "X-Server-Header", 0, curl:CURLH_HEADER, -1)
    test_equal("curl_easy_header CURLHE_OK", curl:CURLHE_OK, hres[1])
    test_equal("curl_easy_header value", "euLibCurl-8.15", hres[2][curl:HDR_VALUE])

    curl:curl_slist_free_all(sl_h)
    curl:curl_easy_cleanup(eh)

    -- curl_easy_get_file to memory and disk
    sequence mem_res = curl:curl_easy_get_file(base_url & "/echo", "", "")
    test_equal("curl_easy_get_file memory CURLE_OK", curl:CURLE_OK, mem_res[1])
    test_true("curl_easy_get_file memory non-empty", length(mem_res[2]) > 0)

    sequence tmp_f = temp_file(current_dir(), "t_eucurl_", ".dat")
    integer f_rc = curl:curl_easy_get_file(base_url & "/file", "", tmp_f)
    test_equal("curl_easy_get_file file CURLE_OK", curl:CURLE_OK, f_rc)
    test_equal("downloaded file is 16384 bytes", 16384, file_length(tmp_f))
    if file_exists(tmp_f) then
        delete_file(tmp_f)
    end if
end if

curl:curl_global_cleanup()
test_report()
