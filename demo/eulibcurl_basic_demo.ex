-- =============================================================================
-- eulibcurl_basic_demo.ex - Synchronous euLibCurl demo (libcurl 8.15.0)
--
-- Usage:
--   eui demo\eulibcurl_basic_demo.ex [URL]
--   (Defaults to https://httpbin.org/get when no argument is provided)
-- =============================================================================

include std/cmdline.e
include std/text.e
include eulibcurl/euLibCurl.ew as curl

sequence args = command_line()
sequence target_url = "https://httpbin.org/get"
if length(args) >= 3 then
    target_url = args[3]
end if

puts(1, "=== 1. libcurl Build Information ===\n")
printf(1, "curl_version()      : %s\n", {curl:curl_version()})
printf(1, "Linked DLL exports  : %d\n", {curl:curl_linked_count()})

sequence vi = curl:curl_version_info()
printf(1, "Structured version  : %s (%s)\n", {vi[curl:VI_VERSION], vi[curl:VI_HOST]})
printf(1, "SSL / HTTP2 / QUIC  : %s | nghttp2=%s | quic=%s\n", {
    vi[curl:VI_SSL_VERSION], vi[curl:VI_NGHTTP2_VERSION], vi[curl:VI_QUIC_VERSION]
})
printf(1, "ASYNCHDNS enabled?  : %d\n", {
    and_bits(vi[curl:VI_FEATURES], curl:CURL_VERSION_ASYNCHDNS) != 0
})

puts(1, "\n=== 2. URL API (curl_url) ===\n")
atom uh = curl:curl_url()
integer urc = curl:curl_url_set(uh, curl:CURLUPART_URL, target_url)
if urc = curl:CURLUE_OK then
    sequence scheme = curl:curl_url_get(uh, curl:CURLUPART_SCHEME)
    sequence host   = curl:curl_url_get(uh, curl:CURLUPART_HOST)
    sequence path   = curl:curl_url_get(uh, curl:CURLUPART_PATH)
    printf(1, "Scheme=%s | Host=%s | Path=%s\n", {scheme[2], host[2], path[2]})
end if
curl:curl_url_cleanup(uh)

puts(1, "\n=== 3. Synchronous HTTP GET with Custom Headers ===\n")
curl:curl_global_init(curl:CURL_GLOBAL_DEFAULT)
atom eh = curl:curl_easy_init()

atom slist = curl:curl_slist_from_sequence({
    "Accept: application/json, text/plain, */*",
    "X-Demo-Client: euLibCurl-8.15.0"
})

integer rc = curl:curl_easy_setopt(eh, curl:CURLOPT_URL, target_url)
rc = curl:curl_easy_setopt(eh, curl:CURLOPT_FOLLOWLOCATION, 1)
rc = curl:curl_easy_setopt(eh, curl:CURLOPT_TIMEOUT, 15)
rc = curl:curl_easy_setopt(eh, curl:CURLOPT_HTTPHEADER, slist)
ifdef WINDOWS then
    rc = curl:curl_easy_setopt(eh, curl:CURLOPT_SSL_OPTIONS, curl:CURLSSLOPT_NATIVE_CA)
end ifdef
if rc != curl:CURLE_OK then
    printf(1, "Warning while setting options: %s\n", {curl:curl_easy_strerror(rc)})
end if

sequence res = curl:curl_easy_perform_ex(eh)
if res[1] = curl:CURLE_OK then
    sequence code_info = curl:curl_easy_getinfo(eh, curl:CURLINFO_RESPONSE_CODE)
    sequence time_info = curl:curl_easy_getinfo(eh, curl:CURLINFO_TOTAL_TIME)
    sequence ct_info   = curl:curl_easy_getinfo(eh, curl:CURLINFO_CONTENT_TYPE)
    printf(1, "HTTP %d in %.3fs | Content-Type=%s | %d bytes\n", {
        code_info[2], time_info[2], ct_info[2], length(res[2])
    })

    puts(1, "\nReceived headers (via curl_easy_nextheader):\n")
    object hdr = curl:curl_easy_nextheader(eh, curl:CURLH_HEADER, -1, 0)
    while length(hdr) > 0 do
        printf(1, "  %s: %s\n", {hdr[curl:HDR_NAME], hdr[curl:HDR_VALUE]})
        hdr = curl:curl_easy_nextheader(eh, curl:CURLH_HEADER, -1, hdr)
    end while

    sequence preview = res[2]
    if length(preview) > 400 then
        preview = preview[1..400] & "\n... (truncated)"
    end if
    printf(1, "\nResponse body:\n%s\n", {preview})
else
    printf(1, "Request error (%d): %s\n", {res[1], curl:curl_easy_strerror(res[1])})
end if

curl:curl_slist_free_all(slist)
curl:curl_easy_cleanup(eh)
curl:curl_global_cleanup()
