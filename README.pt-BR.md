> 🌐 [English](README.md) | **Português (BR)**

# euLibCurl & euLibCurlAsync — Documentação Oficial (libcurl 8.15.0 / OpenEuphoria 4.1+)

Pacote completo para comunicação de rede (**HTTP/1.1, HTTP/2, HTTP/3, HTTPS, WebSockets, FTP/FTPS, SFTP, SMTP, IMAP, POP3, MIME e URL API**) em **OpenEuphoria 4.1+**, usando a build oficial **libcurl 8.15.0_5** (`LibreSSL/4.1.0`, `zlib-ng`, `brotli`, `zstd`, `nghttp2`, `ngtcp2`, `nghttp3`, `libssh2`, `WinIDN`, `ASYNCHDNS`).

---

## Sumário e Documentação Detalhada

| Documento | Conteúdo |
|---|---|
| **[Referência Completa da Biblioteca Principal (`docs/pt-BR/API_EULIBCURL.md`)](docs/pt-BR/API_EULIBCURL.md)** | Todas as **107 rotinas públicas** (cobrindo 96/96 exports da DLL), todos os **5 enums estruturados** (`VI_*`, `EOPT_*`, `HDR_*`, `MMSG_*`, `WS_*`), gestão de memória por handle, despacho `LONG` / `POINTER` / `OFF_T` / `BLOB`, e catálogo das **1.127 constantes** de `curl_constants.e` (`namespace curl_const`). |
| **[Referência Completa da Biblioteca Assíncrona (`docs/pt-BR/API_ASYNC.md`)](docs/pt-BR/API_ASYNC.md)** | Todas as **40 rotinas públicas**, os **4 enums expostos** (`ASYNC_STATUS_*`, `INFO_*`, `PROG_*`, `RESP_*`), fila real de concorrência FIFO (`max_concurrent`), todas as **31 opções** de requisição (`opts`), assinaturas de callbacks, máquina de estados e receitas práticas (`loop`, GUI timers, lotes com centenas de downloads, `std/task.e`). |

---

## Arquitetura dos Módulos

```
include/eulibcurl/
├── curl_constants.e     (namespace curl_const — 1.127 constantes da libcurl 8.15.0)
├── euLibCurl.ew         (namespace curl       — public include curl_constants.e; 107 rotinas)
├── euLibCurlAsync.ew    (namespace curl_async — public include euLibCurl.ew as curl; 40 rotinas)
├── README.md            (este guia inicial e índice)
└── docs/
    ├── API_EULIBCURL.md (referência completa de euLibCurl.ew e curl_constants.e)
    └── API_ASYNC.md     (referência completa de euLibCurlAsync.ew)
```

### Encadeamento de `public include` e Namespaces
- Ao incluir **`include eulibcurl/euLibCurl.ew as curl`**:
  - Todas as funções e enums de `euLibCurl.ew` **e todas as constantes** de `curl_constants.e` ficam acessíveis tanto diretamente (quando não há conflito) quanto com prefixo `curl:` (ex: `curl:CURLE_OK`, `curl:CURLOPT_URL`, `curl:VI_VERSION`).
- Ao incluir **`include eulibcurl/euLibCurlAsync.ew as async`**:
  - Como `euLibCurlAsync.ew` faz `public include eulibcurl/euLibCurl.ew as curl`, todas as constantes e funções públicas re-exportadas ficam acessíveis via `async:` (ex: `async:CURLE_OK`, `async:CURL_HTTP_VERSION_2TLS`, `async:curl_easy_strerror(...)`) além de todas as rotinas e enums `ASYNC_STATUS_*`, `INFO_*`, `PROG_*` e `RESP_*`.
  - Se preferir usar `curl:` diretamente no mesmo arquivo para a API síncrona, faça também `include eulibcurl/euLibCurl.ew as curl`.

---

## Requisitos e Instalação

1. **OpenEuphoria 4.1+** (32-bit ou 64-bit).
2. As DLLs nativas da **libcurl 8.15.0_5** residem em `C:\Euphoria\bin\` (ou no diretório do executável / `PATH`):
   - `libcurl-x32.dll` — carregada automaticamente em builds 32-bit (`eui.exe` padrão).
   - `libcurl-x64.dll` — carregada automaticamente em builds 64-bit (`ifdef BITS64`).
   - Em sistemas Unix/Linux, carrega `libcurl.so.4` / `libcurl.so`.
3. **Sem dependências externas:** ambas as DLLs dependem apenas de bibliotecas nativas do sistema operacional Windows.

---

## Guia Rápido de Uso

### Exemplo 1 — Requisição Síncrona Simples (`euLibCurl.ew`)

```euphoria
include std/console.e
include eulibcurl/euLibCurl.ew as curl

sequence res = curl:curl_easy_get_file("https://httpbin.org/get")
if res[1] = curl:CURLE_OK then
    printf(1, "Recebidos %d bytes:\n%s\n", {length(res[2]), res[2]})
else
    printf(1, "Erro (%d): %s\n", {res[1], curl:curl_easy_strerror(res[1])})
end if
```

### Exemplo 2 — Requisição Síncrona Avançada com Headers e `getinfo`

```euphoria
include eulibcurl/euLibCurl.ew as curl

integer grc = curl:curl_global_init(curl:CURL_GLOBAL_DEFAULT)
atom eh = curl:curl_easy_init()
atom headers = curl:curl_slist_from_sequence({
    "Accept: application/json",
    "X-Client: Euphoria-4.1"
})

integer rc = curl:curl_easy_setopt(eh, curl:CURLOPT_URL, "https://httpbin.org/get")
rc = curl:curl_easy_setopt(eh, curl:CURLOPT_HTTPHEADER, headers)
rc = curl:curl_easy_setopt(eh, curl:CURLOPT_FOLLOWLOCATION, 1)
ifdef WINDOWS then
    rc = curl:curl_easy_setopt(eh, curl:CURLOPT_SSL_OPTIONS, curl:CURLSSLOPT_NATIVE_CA)
end ifdef

sequence resp = curl:curl_easy_perform_ex(eh)
if resp[1] = curl:CURLE_OK then
    sequence code = curl:curl_easy_getinfo(eh, curl:CURLINFO_RESPONSE_CODE)
    sequence elapsed = curl:curl_easy_getinfo(eh, curl:CURLINFO_TOTAL_TIME)
    printf(1, "HTTP %d em %.3fs (%d bytes)\n", {code[2], elapsed[2], length(resp[2])})
end if

curl:curl_slist_free_all(headers)
curl:curl_easy_cleanup(eh)
curl:curl_global_cleanup()
```

### Exemplo 3 — Downloads e POST Assíncronos sem Travar o Script (`euLibCurlAsync.ew`)

```euphoria
include std/os.e
include eulibcurl/euLibCurlAsync.ew as async

integer id1 = async:curl_async_get("https://httpbin.org/delay/2")
integer id2 = async:curl_async_download("https://httpbin.org/bytes/65536", "arquivo.bin")

integer ciclos = 0
while async:curl_async_is_running(id1) or async:curl_async_is_running(id2) do
    ciclos += 1
    -- auto_poll = 0 evita chamar curl_multi_perform duas vezes seguidas na mesma iteracao
    sequence p2 = async:curl_async_progress(id2, 0)
    printf(1, "\rCiclo=%d | DL #2: %d/%d bytes (%.1f%%)   ", {
        ciclos, p2[async:PROG_DL_NOW], p2[async:PROG_DL_TOTAL], p2[async:PROG_DL_PERCENT]
    })
    sleep(0.02)
end while
puts(1, "\n")

sequence r1 = async:curl_async_response(id1)
printf(1, "Req #1 finalizada: %s (HTTP %d)\n", {
    async:curl_async_status_name(r1[async:RESP_STATUS]),
    r1[async:RESP_HTTP_CODE]
})

async:curl_async_release(id1)
async:curl_async_release(id2)
async:curl_async_shutdown()
```

### Exemplo 4 — Timer em Interfaces Gráficas (Win32Lib / wxEuphoria)

Em aplicações com loop de eventos de interface gráfica, dispare a requisição normalmente no handler de clique do botão e use um timer periódico (ex: a cada 20–50 ms) chamando `curl_async_poll()`:

```euphoria
procedure onTimer_AsyncCurl()
    integer ativos = async:curl_async_poll()
    if active_req_id > 0 then
        sequence inf = async:curl_async_info(active_req_id, 0)
        -- Atualiza barra de progresso na janela sem travar a UI
        atualizar_barra(inf[async:INFO_DL_PERCENT])
        if async:curl_async_is_done(active_req_id, 0) then
            sequence resp = async:curl_async_response(active_req_id)
            async:curl_async_release(active_req_id)
            active_req_id = 0
            exibir_resultado(resp)
        end if
    end if
end procedure
```

### Exemplo 5 — Multitarefa Cooperativa (`std/task.e`)

```euphoria
include std/task.e
include eulibcurl/euLibCurlAsync.ew as async

atom pump_id = async:curl_async_start_task(0.01, 0.03)
integer req_id = async:curl_async_get("https://httpbin.org/bytes/16384")

while async:curl_async_is_running(req_id, 0) do
    -- Outras tarefas agendadas executam automaticamente junto com o bombeamento de rede
    task_yield()
end while

sequence corpo = async:curl_async_body(req_id)
async:curl_async_release(req_id)
async:curl_async_shutdown()
```

---

## Cuidados Importantes e Boas Práticas

1. **HTTPS no Windows (`CURLSSLOPT_NATIVE_CA`):**
   - A `libcurl-x32.dll` (8.15.0_5, LibreSSL/4.1.0) não traz um caminho `CURLINFO_CAINFO` embutido por padrão (`VI_CAINFO = ""`).
   - `euLibCurlAsync.ew` e `curl_easy_get_file()` aplicam automaticamente `CURLOPT_SSL_OPTIONS = CURLSSLOPT_NATIVE_CA` no Windows quando `ssl_verify = 1` e nenhum `ca_info`/`ca_path` customizado é passado, validando certificados pela store nativa do Windows.
   - Se usar `curl_easy_init()` + `curl_easy_perform()` diretamente para URLs `https://`, configure `CURLOPT_SSL_OPTIONS` com `CURLSSLOPT_NATIVE_CA` ou informe `CURLOPT_CAINFO`.
2. **Callbacks C no Windows (`cdecl`):**
   - A DLL da libcurl usa convenção **`cdecl`**. Sempre crie ponteiros de callback usando **`curl:curl_callback(routine_id(...))`** (que usa `call_back({'+', rid})` no Windows), nunca `call_back(rid)` puro.
3. **Ciclo de vida da memória:**
   - Em `euLibCurl.ew`: libere `slist` com `curl_slist_free_all()`, handles MIME com `curl_mime_free()`, URLs com `curl_url_cleanup()`, share com `curl_share_cleanup()`, multi com `curl_multi_cleanup()`, e easy handles com `curl_easy_cleanup()`.
   - Em `euLibCurlAsync.ew`: chame `curl_async_release(req_id)` após ler a resposta para remover os metadados/body da memória, e `curl_async_shutdown()` ao encerrar o programa.
4. **Reentrância em callbacks assíncronos:**
   - Dentro de `on_progress`, `on_chunk` e `on_complete`, use `auto_poll = 0` ao chamar `curl_async_info(id, 0)` ou `curl_async_progress(id, 0)` (o módulo já protege contra reentrância internamente com `in_poll`, mas passar `0` torna a intenção explícita e evita chamadas extras).

---

## Programas de Demonstração e Suítes de Teste

| Arquivo | Descrição |
|---|---|
| [`demo/eulibcurl_basic_demo.ex`](demo/eulibcurl_basic_demo.ex) | Inspeção de `curl_version_info()`, `curl_url*`, GET síncrono com `curl_slist`, `curl_easy_getinfo()` e `curl_easy_nextheader()`. |
| [`demo/eulibcurl_async_demo.ex`](demo/eulibcurl_async_demo.ex) | GET, POST JSON e download em disco paralelos com barra de progresso em tempo real sem bloquear o loop. |
| [`demo/eulibcurl_queue_demo.ex`](demo/eulibcurl_queue_demo.ex) | Download em massa de 100 arquivos usando a fila FIFO com limite de 4 downloads simultâneos (`max_concurrent = 4`), exibindo o status final de cada item conforme conclui. |
| [`demo/eulibcurl_task_demo.ex`](demo/eulibcurl_task_demo.ex) | Execução cooperativa com `curl_async_start_task()` e `std/task.e`. |
| [`tests/run_tests.py`](tests/run_tests.py) | Executor autônomo com servidor HTTP local para rodar toda a suíte (`python tests/run_tests.py`). |
| [`tests/t_eulibcurl.e`](tests/t_eulibcurl.e) | Suíte unitária e integrada (`77/77` asserções com servidor local) validando os 96 exports da DLL, constantes, tipos 64-bit e wrappers síncronos. |
| [`tests/t_eulibcurl_async.e`](tests/t_eulibcurl_async.e) | Suíte integrada (`98/98` asserções) validando execução não-bloqueante, paralelismo, verbos HTTP, multipart, retomada, redirects, pause/resume/cancel, callbacks, erros, `std/task.e`, fila FIFO (`max_concurrent`) e abertura sob demanda de `output_file`. |
