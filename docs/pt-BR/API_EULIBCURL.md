> 🌐 [English](../API_EULIBCURL.md) | **Português (BR)** | [README](../../README.pt-BR.md)

# Referência Completa — `euLibCurl.ew` & `curl_constants.e` (libcurl 8.15.0)

Documentação exaustiva da biblioteca principal (`include eulibcurl/euLibCurl.ew as curl`), cobrindo:
- Todas as **107 rotinas públicas** expostas por `euLibCurl.ew` (`namespace curl`), abrangendo **100% das 96 funções exportadas** por `libcurl-x32.dll` / `libcurl-x64.dll` (v8.15.0_5) além dos helpers Euphoria;
- Todos os **5 enums estruturados públicos** (`VI_*`, `EOPT_*`, `HDR_*`, `MMSG_*`, `WS_*`);
- Catálogo completo das **famílias de constantes** expostas por `curl_constants.e` (`namespace curl_const`, re-exportado automaticamente por `public include`).

---

## Sumário

1. [Módulos, Namespaces e Carregamento](#1-módulos-namespaces-e-carregamento)
2. [Estruturas e Enums Públicos Expostos](#2-estruturas-e-enums-públicos-expostos)
3. [Introspecção da DLL e Callbacks (`cdecl`)](#3-introspecção-da-dll-e-callbacks-cdecl)
4. [Global, Versão e Utilitários](#4-global-versão-e-utilitários)
5. [Listas Encadeadas (`curl_slist`)](#5-listas-encadeadas-curl_slist)
6. [Interface Easy Core](#6-interface-easy-core)
7. [Introspecção de Opções e Header API](#7-introspecção-de-opções-e-header-api)
8. [Interface Multi (`curl_multi_*`)](#8-interface-multi-curl_multi_)
9. [Interface Share (`curl_share_*`)](#9-interface-share-curl_share_)
10. [Interface MIME (Multipart Moderno)](#10-interface-mime-multipart-moderno)
11. [URL API (`curl_url*`)](#11-url-api-curl_url)
12. [WebSockets API (`curl_ws_*`)](#12-websockets-api-curl_ws_)
13. [HTTP/2 Server Push Headers](#13-http2-server-push-headers)
14. [API Legada (`curl_form*`, `curl_escape`, `curl_unescape`)](#14-api-legada-curl_form-curl_escape-curl_unescape)
15. [Família `curl_m*printf`](#15-família-curl_mprintf)
16. [Helpers Síncronos Modernos](#16-helpers-síncronos-modernos)
17. [Catálogo Completo de Constantes (`curl_constants.e`)](#17-catálogo-completo-de-constantes-curl_constants_e)

---

## 1. Módulos, Namespaces e Carregamento

```euphoria
include eulibcurl/euLibCurl.ew as curl
```

- **`euLibCurl.ew`** declara `namespace curl` e re-exporta `curl_constants.e` via `public include eulibcurl/curl_constants.e`.
- Ao importar `euLibCurl.ew`, o módulo detecta a arquitetura em tempo de execução/compilação e abre automaticamente:
  - Windows 64-bit (`ifdef BITS64`): `libcurl-x64.dll`
  - Windows 32-bit (`ifdef WINDOWS`): `libcurl-x32.dll`
  - Unix/Linux: `libcurl.so.4` ou `libcurl.so`
- Se a DLL ou qualquer um dos símbolos exportados não puder ser carregado, o módulo encerra imediatamente via `error:crash(...)` informando o arquivo/símbolo ausente.
- **Gestão de Memória por Handle:** Não há mais tabelas globais de strings (`string_tab`) nem ponteiros globais únicos (`a2dp`). O wrapper mantém o mapa interno `handle_allocs` indexado pelo ponteiro `atom curl`, alocando e preservando buffers apenas para opções onde a libcurl não copia os dados (`CURLOPT_POSTFIELDS` e `CURLOPT_ERRORBUFFER`). As alocações desse handle são liberadas automaticamente em `curl_easy_cleanup(curl)`, `curl_easy_reset(curl)` ou quando uma opção é sobrescrita com ponteiro externo.

---

## 2. Estruturas e Enums Públicos Expostos

Em `euLibCurl.ew`, funções que decodificam structs C retornam `sequence` indexadas pelos enums públicos abaixo (todos iniciando em `1`).

### 2.1 `VI_*` — Retorno de `curl_version_info()` (27 campos)

| Índice | Valor | Tipo Euphoria | Significado (campo de `curl_version_info_data`) |
|---|---|---|---|
| `VI_AGE` | `1` | `integer` | Idade da estrutura retornada (`CURLVERSION_*`, ex: `11` na 8.15.0). |
| `VI_VERSION` | `2` | `sequence` | String de versão da libcurl (ex: `"8.15.0"`). |
| `VI_VERSION_NUM` | `3` | `atom` | Versão numérica hexadecimal (ex: `#080F00`). |
| `VI_HOST` | `4` | `sequence` | Tripla de build/host (ex: `"i686-w64-mingw32"`). |
| `VI_FEATURES` | `5` | `atom` | Bitmask das capacidades compiladas (`CURL_VERSION_*`). |
| `VI_SSL_VERSION` | `6` | `sequence` | Biblioteca TLS em uso (ex: `"LibreSSL/4.1.0"`). |
| `VI_SSL_VERSION_NUM` | `7` | `atom` | Número legado de versão SSL (`0` em versões modernas). |
| `VI_LIBZ_VERSION` | `8` | `sequence` | Versão da zlib (ex: `"1.3.1.zlib-ng"`). |
| `VI_PROTOCOLS` | `9` | `sequence` | Lista de strings com protocolos suportados (ex: `{"http", "https", ...}`). |
| `VI_ARES` | `10` | `sequence` | Versão do c-ares (ou `""` se usar resolver nativo/threaded). |
| `VI_ARES_NUM` | `11` | `integer` | Versão numérica do c-ares. |
| `VI_LIBIDN` | `12` | `sequence` | Versão da biblioteca IDN (se presente). |
| `VI_ICONV_VER_NUM` | `13` | `integer` | Versão do iconv (se presente). |
| `VI_LIBSSH_VERSION` | `14` | `sequence` | Versão do libssh2 (ex: `"libssh2/1.11.1"`). |
| `VI_BROTLI_VER_NUM` | `15` | `atom` | Versão numérica do Brotli. |
| `VI_BROTLI_VERSION` | `16` | `sequence` | String de versão do Brotli (ex: `"1.1.0"`). |
| `VI_NGHTTP2_VER_NUM` | `17` | `atom` | Versão numérica do nghttp2. |
| `VI_NGHTTP2_VERSION` | `18` | `sequence` | String de versão do nghttp2 (ex: `"1.66.0"`). |
| `VI_QUIC_VERSION` | `19` | `sequence` | String HTTP/3 / QUIC (ex: `"ngtcp2/1.15.0 nghttp3/1.11.0"`). |
| `VI_CAINFO` | `20` | `sequence` | Caminho CA bundle embutido padrão (ou `""`). |
| `VI_CAPATH` | `21` | `sequence` | Diretório CA padrão (ou `""`). |
| `VI_ZSTD_VER_NUM` | `22` | `atom` | Versão numérica do zstd. |
| `VI_ZSTD_VERSION` | `23` | `sequence` | String de versão do zstd (ex: `"1.5.7"`). |
| `VI_HYPER_VERSION` | `24` | `sequence` | Versão do backend Hyper (ou `""`). |
| `VI_GSASL_VERSION` | `25` | `sequence` | Versão da libgsasl (ou `""`). |
| `VI_FEATURE_NAMES` | `26` | `sequence` | Lista de strings com nomes legíveis de recursos ativos (ex: `"AsynchDNS"`, `"HTTP2"`, `"HTTP3"`). |
| `VI_RTMP_VERSION` | `27` | `sequence` | Versão da biblioteca RTMP (ou `""`). |

### 2.2 `EOPT_*` — Retorno de `curl_easy_option_*()` (5 campos)

| Índice | Valor | Tipo Euphoria | Significado (campo de `struct curl_easyoption`) |
|---|---|---|---|
| `EOPT_NAME` | `1` | `sequence` | Nome da opção sem prefixo `CURLOPT_` (ex: `"URL"`). |
| `EOPT_ID` | `2` | `integer` | Valor numérico `CURLOPT_*` (ex: `10002`). |
| `EOPT_TYPE` | `3` | `integer` | Tipo da opção (`CURLOT_LONG` .. `CURLOT_FUNCTION`). |
| `EOPT_FLAGS` | `4` | `atom` | Flags da opção (ex: `CURLOT_FLAG_ALIAS = 1`). |
| `EOPT_RAW_PTR` | `5` | `atom` | Ponteiro C bruto para a struct (usado como `prev` em `curl_easy_option_next()`). |

### 2.3 `HDR_*` — Retorno de `curl_easy_header()` / `curl_easy_nextheader()` (7 campos)

| Índice | Valor | Tipo Euphoria | Significado (campo de `struct curl_header`) |
|---|---|---|---|
| `HDR_NAME` | `1` | `sequence` | Nome do cabeçalho HTTP. |
| `HDR_VALUE` | `2` | `sequence` | Valor do cabeçalho HTTP (sem `\r\n`). |
| `HDR_AMOUNT` | `3` | `atom` | Quantidade total de ocorrências desse nome na resposta. |
| `HDR_INDEX` | `4` | `atom` | Índice baseado em `0` desta instância específica. |
| `HDR_ORIGIN` | `5` | `atom` | Bitmask de origem (`CURLH_HEADER`, `CURLH_TRAILER`, `CURLH_CONNECT`, `CURLH_1XX`, `CURLH_PSEUDO`). |
| `HDR_ANCHOR` | `6` | `atom` | Ponteiro opaco interno da libcurl. |
| `HDR_RAW_PTR` | `7` | `atom` | Ponteiro C bruto da struct (passado como `prev` em `curl_easy_nextheader()`). |

### 2.4 `MMSG_*` — Retorno de `curl_multi_info_read()` (4 campos)

| Índice | Valor | Tipo Euphoria | Significado (campo de `CURLMsg`) |
|---|---|---|---|
| `MMSG_MSG` | `1` | `integer` | Tipo da mensagem (`CURLMSG_DONE = 1`). |
| `MMSG_EASY_HANDLE` | `2` | `atom` | Ponteiro `CURL *` do easy handle ao qual a mensagem se refere. |
| `MMSG_RESULT` | `3` | `integer` | Código `CURLcode` final da transferência (`CURLE_OK = 0` ou erro). |
| `MMSG_QUEUED` | `4` | `integer` | Quantidade de mensagens restantes ainda na fila do multi handle. |

### 2.5 `WS_*` — Retorno de metadata de WebSockets (`curl_ws_recv()` / `curl_ws_meta()`) (5 campos)

| Índice | Valor | Tipo Euphoria | Significado (campo de `struct curl_ws_frame`) |
|---|---|---|---|
| `WS_AGE` | `1` | `integer` | Versão da struct (`0`). |
| `WS_FLAGS` | `2` | `integer` | Bitmask de flags (`CURLWS_TEXT`, `CURLWS_BINARY`, `CURLWS_CONT`, `CURLWS_CLOSE`, `CURLWS_PING`, `CURLWS_PONG`, `CURLWS_OFFSET`). |
| `WS_OFFSET` | `3` | `atom` | Offset em bytes do fragmento atual dentro do frame WebSocket (`curl_off_t` 64-bit). |
| `WS_BYTESLEFT` | `4` | `atom` | Bytes pendentes restantes do payload do frame (`curl_off_t` 64-bit). |
| `WS_LEN` | `5` | `atom` | Tamanho do bloco atual entregue (`size_t`). |

---

## 3. Introspecção da DLL e Callbacks (`cdecl`)

### `curl_dll_handle()`
```euphoria
public function curl_dll_handle()
```
- **Descrição:** Retorna o handle nativo (`atom`) obtido por `open_dll()` para a DLL `libcurl` carregada.

### `curl_linked_count()`
```euphoria
public function curl_linked_count()
```
- **Descrição:** Retorna a quantidade de símbolos C distintos vinculados na carga do módulo (`96` na libcurl 8.15.0).

### `curl_linked_names()`
```euphoria
public function curl_linked_names()
```
- **Descrição:** Retorna uma `sequence` de strings com os nomes exatos de todas as funções/procedimentos C vinculados da DLL.

### `curl_callback(integer rid)`
```euphoria
public function curl_callback(integer rid)
```
- **Parâmetros:** `rid` — identificador retornado por `routine_id(...)` de uma função Euphoria.
- **Retorno:** `atom` — endereço executável de callback pronto para passar em `CURLOPT_*FUNCTION` / `CURLMOPT_*FUNCTION`.
- **Notas:** No Windows gera `call_back({'+', rid})` (`cdecl`), evitando corrupção de pilha; em Unix usa `call_back(rid)`. Chama `error:crash()` se `rid < 0`.

---

## 4. Global, Versão e Utilitários

### `curl_global_init(atom flags = CURL_GLOBAL_DEFAULT)`
- Inicializa o ambiente global da libcurl (Winsock, TLS, etc.). Deve ser chamado antes de iniciar operações (ou automaticamente via `curl_easy_init` / `curl_async_init`). Retorna `CURLE_OK` (`0`) em sucesso.

### `curl_global_init_mem(atom flags, atom malloc_cb, atom free_cb, atom realloc_cb, atom strdup_cb, atom calloc_cb)`
- Variante de `curl_global_init()` permitindo registrar alocadores de memória C customizados via ponteiros de callback `cdecl`. Retorna `CURLE_OK` em sucesso.

### `curl_global_cleanup()` *(procedure)*
- Libera recursos globais inicializados por `curl_global_init()`. Deve ser chamado ao encerrar o uso da biblioteca no processo.

### `curl_global_sslset(integer backend_id = -1, sequence backend_name = "")`
- Seleciona o backend SSL (antes de `curl_global_init()`) ou consulta os backends disponíveis quando chamado sem argumentos (`backend_id = -1, backend_name = ""`).
- **Retorno:** `{CURLsslset_code, lista_backends}` onde `lista_backends` é uma lista de pares `{id, nome}` (ex: `{{1, "openssl"}}`).

### `curl_global_trace(sequence config)`
- Configura rastreamento global de logs da libcurl (ex: `"all"`, `"tcp,http/2"`). Retorna `CURLE_OK` ou erro.

### `curl_version()`
- **Retorno:** `sequence` — string descritiva com versão da libcurl e bibliotecas vinculadas.

### `curl_version_info_raw(integer age = CURLVERSION_NOW)`
- **Retorno:** `atom` — ponteiro bruto para `curl_version_info_data` da DLL.

### `curl_version_info(integer age = CURLVERSION_NOW)`
- **Retorno:** `sequence` indexada por `VI_*` (ver [seção 2.1](#21-vi_--retorno-de-curl_version_info-27-campos)) com todas as informações decodificadas da build (ou `{}` se a DLL retornar `NULL`).

### `curl_free(atom ptr)` *(procedure)*
- Libera ponteiros alocados internamente pela própria `libcurl` (se `ptr != 0`). **Nunca** passe strings estáticas (como retornos de `curl_*_strerror`).

### `curl_getdate(sequence datestr, atom unused_now = 0)`
- Converte uma string de data HTTP/RFC (ex: `"Wed, 21 Oct 2015 07:28:00 GMT"`) em timestamp Unix (`atom` 64-bit) ou `-1` se inválida.

### `curl_getenv(sequence name)`
- Lê variável de ambiente via `curl_getenv` e libera o ponteiro retornado. Retorna `""` se não existir.

### `curl_strequal(sequence s1, sequence s2)`
- Comparação case-insensitive estilo libcurl. Retorna `1` se iguais, `0` se diferentes.

### `curl_strnequal(sequence s1, sequence s2, atom max_len)`
- Compara até `max_len` caracteres ignorando maiúsculas/minúsculas. Retorna `1` se iguais, `0` se diferentes.

---

## 5. Listas Encadeadas (`curl_slist`)

### `curl_slist_append(atom slist, sequence item)`
- Anexa `item` à lista `slist` (passe `0` para iniciar uma nova lista). Retorna o novo ponteiro raiz `atom` (ou `0` em falta de memória).

### `curl_slist_free_all(atom slist)` *(procedure)*
- Libera toda a lista encadeada `slist` (ignora `0` com segurança).

### `curl_slist_from_sequence(sequence items)`
- Helper moderno que cria uma `curl_slist` a partir de uma lista Euphoria de strings (ex: `{"Accept: application/json", "X-Key: 123"}`). Se falhar alguma alocação intermediária, libera o que já foi criado e retorna `0`.

### `curl_slist_to_sequence(atom slist)`
- Converte uma `curl_slist *` em uma `sequence` de strings Euphoria sem liberar a lista original.

---

## 6. Interface Easy Core

### `curl_easy_init()`
- Cria e retorna um novo Easy Handle (`atom`). Retorna `0` em falha.

### `curl_easy_cleanup(atom curl)` *(procedure)*
- Fecha o Easy Handle e libera automaticamente todas as alocações mantidas para ele em `handle_allocs` (ex: `CURLOPT_POSTFIELDS`). Ignora `0`.

### `curl_easy_reset(atom curl)` *(procedure)*
- Reseta todas as opções do handle `curl` aos padrões de fábrica (preservando conexões em cache), liberando as alocações gerenciadas desse handle em `handle_allocs`.

### `curl_easy_duphandle(atom curl)`
- Clona um Easy Handle mantendo suas opções configuradas. Retorna o novo ponteiro `atom` (ou `0` em falha).
- **Nota:** Como a libcurl não copia o ponteiro de `CURLOPT_POSTFIELDS` ao duplicar, evite depender de buffers de `POSTFIELDS` gerenciados pelo handle original após `curl_easy_cleanup(curl)`.

### `curl_easy_setopt(atom curl, integer opt, object param)`
- Configura opções no Easy Handle retornando `CURLcode` (`CURLE_OK = 0` em sucesso).
- **Despacho automático por tipo da constante `opt`:**
  - `30000 <= opt < 40000` (**`OFF_T`**): chama `curl_easy_setopt(..., C_LONGLONG)` (exige `atom`/`integer`; chama `error:crash` se receber `sequence`).
  - `40000 <= opt < 50000` (**`BLOB`**): se `sequence(param)`, empacota automaticamente os bytes em `struct curl_blob` com `CURL_BLOB_COPY` (12 bytes em 32-bit, 24 em 64-bit), envia e libera o temporário imediatamente. Se `atom(param)`, passa o ponteiro bruto diretamente.
  - `opt < 10000` (**`LONG`**): chama `curl_easy_setopt(..., C_LONG)` (chama `error:crash` se receber `sequence`).
  - `10000 <= opt < 30000` (**`STRING`/`OBJECT`/`SLIST`/`FUNCTION`**):
    - Se `sequence(param)` e `opt = CURLOPT_POSTFIELDS`: aloca buffer null-terminated preservando zeros internos, libera eventual alocação anterior dessa opção nesse handle, salva o ponteiro em `handle_allocs` (para sobreviver até o `perform`/`cleanup`) e envia à DLL.
    - Se `sequence(param)` para qualquer outra opção (ex: `CURLOPT_URL`, `CURLOPT_COPYPOSTFIELDS`, `CURLOPT_USERAGENT`): aloca temporário, envia à libcurl (que faz cópia própria na 8.15.0) e **libera imediatamente**.
    - Se `atom(param)`: passa ponteiro/endereço diretamente (e libera eventual alocação gerenciada anterior se `opt` for `CURLOPT_POSTFIELDS` ou `CURLOPT_ERRORBUFFER`).

### `curl_easy_perform(atom curl)`
- Executa a transferência de forma **síncrona (bloqueante)** até terminar. Retorna `CURLcode`.

### `curl_easy_getinfo_raw(atom curl, integer info, atom out_ptr)`
- Chama `curl_easy_getinfo` gravando o resultado bruto diretamente no buffer `out_ptr` (mínimo 8 bytes) fornecido pelo chamador. Retorna `CURLcode`.

### `curl_easy_getinfo(atom curl, integer info)`
- Consulta metadados pós/durante transferência e decodifica automaticamente conforme `and_bits(info, CURLINFO_TYPEMASK)`.
- **Retorno:** `{CURLcode, valor}` (se `CURLcode != CURLE_OK`, retorna `{rc, 0}`).
  - `CURLINFO_STRING`: `sequence` string (`""` se ponteiro nulo).
  - `CURLINFO_LONG`: `integer`/`atom` via `peek_longs`.
  - `CURLINFO_DOUBLE`: `atom` IEEE-754 via `float64_to_atom`.
  - `CURLINFO_SLIST`: para `CURLINFO_SSL_ENGINES` e `CURLINFO_COOKIELIST`, converte automaticamente em `sequence` de strings e chama `curl_slist_free_all()`; para outros ponteiros (`CURLINFO_CERTINFO`, `CURLINFO_TLS_*`), retorna o ponteiro `atom` bruto.
  - `CURLINFO_SOCKET`: `atom` (`peek_pointer`).
  - `CURLINFO_OFF_T`: `atom` 64-bit (`peek8s`).

### `curl_easy_pause(atom curl, integer bitmask)`
- Pausa ou retoma recebimento/envio (`CURLPAUSE_ALL`, `CURLPAUSE_RECV`, `CURLPAUSE_SEND`, `CURLPAUSE_CONT`). Retorna `CURLcode`.

### `curl_easy_escape(atom curl, sequence text)`
- Faz URL-encoding de `text` (preservando zeros binários `\0` via tamanho explícito `length(text)`), liberando a string C alocada pela DLL via `curl_free()`. Retorna string escapada (`""` se vazio ou falha).

### `curl_easy_unescape(atom curl, sequence text)`
- Decodifica URL-encoding preservando bytes binários (incluindo `\0`, usando o parâmetro `outlength` da DLL) e libera o ponteiro via `curl_free()`.

### `curl_easy_recv(atom curl, integer max_len = 16384)`
- Lê até `max_len` bytes brutos de um handle conectado com `CURLOPT_CONNECT_ONLY`.
- **Retorno:** `{CURLcode, bytes_recebidos}` (retorna `{CURLE_BAD_FUNCTION_ARGUMENT, ""}` se `max_len <= 0`).

### `curl_easy_send(atom curl, sequence data)`
- Envia `data` bruto em um handle conectado com `CURLOPT_CONNECT_ONLY`.
- **Retorno:** `{CURLcode, bytes_enviados}`.

### `curl_easy_strerror(integer err_code)`
- Converte um código `CURLcode` (`CURLE_*`) em mensagem descritiva (`sequence`). Seguro contra crash (não chama `curl_free`).

### `curl_easy_upkeep(atom curl)`
- Envia pings/frames de manutenção de conexão (ex: HTTP/2 PING) em conexões ociosas. Retorna `CURLcode`.

### `curl_easy_ssls_export(atom curl, atom export_cb, atom userptr = 0)`
- Itera pelas sessões/tickets TLS em cache chamando o callback `export_cb` (criado via `curl_callback()`). Retorna `CURLcode`.

### `curl_easy_ssls_import(atom curl, sequence session_key, sequence shmac, sequence sdata)`
- Importa uma sessão/ticket TLS previamente exportada para o cache do handle (ou `share` associado). Retorna `CURLcode`.

---

## 7. Introspecção de Opções e Header API

### `curl_easy_option_by_id(integer id)`
- Procura metadados da opção `CURLOPT_*` pelo código numérico. Retorna `sequence` indexada por `EOPT_*` ou `{}` se não existir.

### `curl_easy_option_by_name(sequence name)`
- Procura metadados da opção pelo nome **sem** prefixo `CURLOPT_` (ex: `"URL"`, `"FOLLOWLOCATION"`). Retorna `sequence` indexada por `EOPT_*` ou `{}`.

### `curl_easy_option_next(object prev = 0)`
- Itera por todas as opções suportadas pela libcurl 8.15.0. Passe `0` na primeira chamada e a `sequence` retornada (ou seu `EOPT_RAW_PTR`) nas seguintes; retorna `{}` ao término.

### `curl_easy_header(atom curl, sequence name, atom index = 0, atom origin = CURLH_HEADER, integer request = -1)`
- Consulta o cabeçalho HTTP `name` recebido na requisição `request` (`-1` = última/final), com origem `origin` (`CURLH_*`) e índice `index` (`0`-based para headers repetidos).
- **Retorno:** `{CURLHcode, header_seq}` onde `header_seq` usa índices `HDR_*` (ou `{CURLHcode, {}}` se não encontrado).

### `curl_easy_nextheader(atom curl, atom origin = CURLH_HEADER, integer request = -1, object prev = 0)`
- Itera sequencialmente pelos cabeçalhos recebidos. Passe `0` para o primeiro e a `sequence` anterior para o próximo; retorna `{}` ao concluir.

---

## 8. Interface Multi (`curl_multi_*`)

Base não-bloqueante da `libcurl`, utilizada internamente por [euLibCurlAsync.ew](API_ASYNC.md).

### `curl_multi_init()`
- Cria um multi handle (`atom`), ou `0` em falha.

### `curl_multi_cleanup(atom multi)`
- Libera o multi handle e retorna `CURLMcode` (`CURLM_BAD_HANDLE` se `multi = 0`).

### `curl_multi_add_handle(atom multi, atom easy)`
- Adiciona um `easy` handle ao `multi`. Retorna `CURLMcode`.

### `curl_multi_remove_handle(atom multi, atom easy)`
- Desanexa um `easy` handle do `multi`. Retorna `CURLMcode`.

### `curl_multi_perform(atom multi)`
- Executa passos pendentes sem bloquear. **Retorno:** `{CURLMcode, running_handles}`.

### `curl_multi_wait(atom multi, integer timeout_ms = 50, atom extra_fds = 0, integer extra_nfds = 0)`
- Aguarda atividade nos sockets do multi (ou em `extra_fds`) até `timeout_ms`. Retorna imediatamente se não houver descritores ativos. **Retorno:** `{CURLMcode, numfds}`.

### `curl_multi_poll(atom multi, integer timeout_ms = 50, atom extra_fds = 0, integer extra_nfds = 0)`
- Semelhante a `curl_multi_wait()`, porém dorme até `timeout_ms` mesmo sem descritores ativos, podendo ser acordada por `curl_multi_wakeup()`. **Retorno:** `{CURLMcode, numfds}`.

### `curl_multi_waitfds(atom multi, atom ufds_ptr = 0, integer ufds_size = 0)`
- Consulta os descritores de socket aguardados pelo `multi` (útil ao integrar com loops externos de polling). **Retorno:** `{CURLMcode, fd_count}`.

### `curl_multi_wakeup(atom multi)`
- Desperta uma chamada bloqueada em `curl_multi_poll()`. Retorna `CURLMcode`.

### `curl_multi_info_read(atom multi)`
- Lê a próxima mensagem da fila de eventos do `multi`.
- **Retorno:** `{}` se a fila estiver vazia, ou `{msg, easy_handle, result, msgs_in_queue}` indexado por `MMSG_*`.

### `curl_multi_setopt(atom multi, integer opt, object param)`
- Configura opções `CURLMOPT_*` despachando `C_LONGLONG` (`30000..39999`), `C_LONG` (`< 10000`) ou `C_POINTER`/string temporária. Retorna `CURLMcode`.

### `curl_multi_timeout(atom multi)`
- Consulta o timeout máximo recomendado (em ms) antes da próxima chamada a `curl_multi_perform` (`-1` se não houver timer pendente). **Retorno:** `{CURLMcode, timeout_ms}`.

### `curl_multi_fdset(atom multi, atom read_fd_set, atom write_fd_set, atom exc_fd_set)`
- Preenche conjuntos `fd_set` nativos para uso com `select()`. **Retorno:** `{CURLMcode, max_fd}`.

### `curl_multi_socket(atom multi, atom sock)` *(legada)*
- API antiga baseada em eventos de socket. **Retorno:** `{CURLMcode, running_handles}`.

### `curl_multi_socket_action(atom multi, atom sock, integer ev_bitmask)`
- Notifica a libcurl sobre atividade (`CURL_CSELECT_IN`/`OUT`/`ERR` ou `CURL_SOCKET_TIMEOUT`) no descritor `sock` no modelo orientado a eventos. **Retorno:** `{CURLMcode, running_handles}`.

### `curl_multi_socket_all(atom multi)` *(legada)*
- Dispara ação em todos os sockets do multi. **Retorno:** `{CURLMcode, running_handles}`.

### `curl_multi_assign(atom multi, atom sock, atom sockptr)`
- Associa um ponteiro de dados do usuário a um socket gerenciado no modelo `socket_action`. Retorna `CURLMcode`.

### `curl_multi_strerror(integer err_code)`
- Converte código `CURLM_*` em descrição textual (`sequence`).

### `curl_multi_get_handles(atom multi)`
- Retorna uma `sequence` com todos os `atom` easy handles atualmente anexados ao `multi` (e libera o array C automaticamente).

---

## 9. Interface Share (`curl_share_*`)

Permite compartilhar cache de DNS, cookies, sessões SSL, conexões ou PSL entre múltiplos easy handles via `CURLOPT_SHARE`.

### `curl_share_init()`
- Cria um share handle (`atom`), ou `0` em falha.

### `curl_share_cleanup(atom share)`
- Libera o share handle e retorna `CURLSHcode` (`CURLSHE_INVALID` se `share = 0`).

### `curl_share_setopt(atom share, integer opt, atom param)`
- Configura `CURLSHOPT_SHARE`, `CURLSHOPT_UNSHARE`, `CURLSHOPT_LOCKFUNC`, `CURLSHOPT_UNLOCKFUNC`, `CURLSHOPT_USERDATA`. Para `SHARE`/`UNSHARE` passa `C_LONG` (`CURL_LOCK_DATA_*`); para os demais passa `C_POINTER`. Retorna `CURLSHcode`.

### `curl_share_strerror(integer err_code)`
- Converte código `CURLSHE_*` em descrição textual (`sequence`).

---

## 10. Interface MIME (Multipart Moderno)

Constrói payloads `multipart/form-data` para envio via `CURLOPT_MIMEPOST`.

### `curl_mime_init(atom curl)`
- Cria uma nova estrutura `curl_mime` associada ao easy handle `curl`. Retorna `atom` (ou `0`).

### `curl_mime_free(atom mime)` *(procedure)*
- Libera o objeto `mime` e todas as suas partes/subpartes (ignora `0`).

### `curl_mime_addpart(atom mime)`
- Adiciona uma nova parte vazia ao objeto `mime` e retorna seu handle (`atom`).

### `curl_mime_name(atom part, sequence name)`
- Define o nome do campo `name` da parte `part`. Retorna `CURLcode`.

### `curl_mime_data(atom part, sequence data)`
- Define os dados brutos da parte preservando qualquer byte binário (incluindo `\0` internos). A libcurl copia os dados internamente. Retorna `CURLcode`.

### `curl_mime_data_cb(atom part, atom datasize, atom readfunc, atom seekfunc = 0, atom freefunc = 0, atom arg = 0)`
- Define dados alimentados por streaming via callbacks C (`datasize` é `C_LONGLONG`; passe `-1` se desconhecido). Retorna `CURLcode`.

### `curl_mime_filedata(atom part, sequence filename)`
- Anexa o conteúdo de um arquivo em disco como corpo da parte. Retorna `CURLcode`.

### `curl_mime_filename(atom part, object filename)`
- Define o atributo `filename="..."` enviado no `Content-Disposition` (passe `0` para remover/ocultar). Retorna `CURLcode`.

### `curl_mime_type(atom part, object mimetype)`
- Define o cabeçalho `Content-Type` da parte (ex: `"application/pdf"`, ou `0` para limpar). Retorna `CURLcode`.

### `curl_mime_encoder(atom part, object encoding)`
- Define o `Content-Transfer-Encoding` da parte (ex: `"base64"`, `"quoted-printable"`, `"binary"`, ou `0`). Retorna `CURLcode`.

### `curl_mime_headers(atom part, atom headers_slist, integer take_ownership = 0)`
- Associa cabeçalhos customizados (`curl_slist`) à parte. Se `take_ownership = 1`, `curl_mime_free()` libera o `slist` automaticamente. Retorna `CURLcode`.

### `curl_mime_subparts(atom part, atom subparts_mime)`
- Aninha outro objeto `curl_mime` como subparte multipart. Retorna `CURLcode`.

---

## 11. URL API (`curl_url*`)

Parser, construtor e normalizador de URLs compatível com RFC 3986 / WHATWG.

### `curl_url()`
- Cria um handle `CURLU *` (`atom`), ou `0`.

### `curl_url_cleanup(atom url_handle)` *(procedure)*
- Libera o handle `CURLU` (ignora `0`).

### `curl_url_dup(atom url_handle)`
- Duplica um handle `CURLU` preservando suas partes já analisadas.

### `curl_url_get(atom url_handle, integer what, atom flags = 0)`
- Extrai uma parte da URL (`CURLUPART_*`, ex: `CURLUPART_URL`, `CURLUPART_SCHEME`, `CURLUPART_HOST`, `CURLUPART_PORT`, `CURLUPART_PATH`, `CURLUPART_QUERY`, `CURLUPART_FRAGMENT`) usando opcionalmente flags `CURLU_*` (ex: `CURLU_DEFAULT_PORT`, `CURLU_URLDECODE`).
- **Retorno:** `{CURLUcode, valor_string}` (libera o ponteiro retornado pela DLL com `curl_free`).

### `curl_url_set(atom url_handle, integer what, object part, atom flags = 0)`
- Define ou substitui uma parte `CURLUPART_*` (passe `0` para limpar a parte ou uma `sequence` string; flags como `CURLU_APPENDQUERY` ou `CURLU_URLENCODE`). Retorna `CURLUcode`.

### `curl_url_strerror(integer err_code)`
- Converte código `CURLUE_*` em string descritiva.

---

## 12. WebSockets API (`curl_ws_*`)

Utilizada após conectar a um endpoint `ws://` / `wss://` com `curl_easy_setopt(eh, CURLOPT_CONNECT_ONLY, 2)` e `curl_easy_perform(eh)`.

### `curl_ws_recv(atom curl, integer max_len = 65536)`
- Recebe até `max_len` bytes de um frame WebSocket.
- **Retorno:** `{CURLcode, bytes_recebidos, meta_ws}`, onde `meta_ws` é `{}` ou uma `sequence` com índices `WS_*` (`{WS_AGE, WS_FLAGS, WS_OFFSET, WS_BYTESLEFT, WS_LEN}`). Retorna `{CURLE_BAD_FUNCTION_ARGUMENT, "", {}}` se `max_len <= 0`.

### `curl_ws_send(atom curl, sequence data, atom flags = CURLWS_TEXT, atom fragsize = 0)`
- Envia um frame ou fragmento WebSocket (`CURLWS_TEXT`, `CURLWS_BINARY`, `CURLWS_CONT`, `CURLWS_CLOSE`, `CURLWS_PING`, `CURLWS_PONG`, `CURLWS_OFFSET`). `fragsize` é passado como `C_LONGLONG`.
- **Retorno:** `{CURLcode, bytes_enviados}`.

### `curl_ws_meta(atom curl)`
- Retorna a metadata `WS_*` (ou `{}`) do frame WebSocket atual dentro de callbacks de escrita ou após recebimento.

---

## 13. HTTP/2 Server Push Headers

Funções chamadas dentro de um callback `CURLMOPT_PUSHFUNCTION` ao receber streams HTTP/2 Server Push.

### `curl_pushheader_bynum(atom push_headers, atom num)`
- Retorna o cabeçalho de índice `num` (`0`-based) como `sequence` (`""` se inválido). Não libera o ponteiro.

### `curl_pushheader_byname(atom push_headers, sequence name)`
- Retorna o valor do cabeçalho `name` do push HTTP/2 como `sequence` (`""` se ausente). Não libera o ponteiro.

---

## 14. API Legada (`curl_form*`, `curl_escape`, `curl_unescape`)

Mantidas para completude 100% com os exports da DLL. Para código novo, prefira **`curl_mime_*`** e **`curl_easy_escape()` / `curl_easy_unescape()`**.

### `curl_formadd(atom first_pp, atom last_pp, sequence pairs)`
- Wrapper tipado para `curl_formadd`, aceitando ponteiros C para `struct curl_httppost **` (`first_pp`, `last_pp`) e de `1` a `6` pares `{{CURLFORM_*, valor}, ...}` (adicionando `CURLFORM_END` ao final automaticamente). Chama `error:crash()` se `pairs` não tiver entre 1 e 6 itens. Retorna `CURLFORMcode`.

### `curl_formfree(atom form)` *(procedure)*
- Libera lista montada por `curl_formadd()`.

### `curl_formget(atom form, atom arg, atom append_cb)`
- Serializa um formulário `curl_formadd` chamando o callback `append_cb`. Retorna `0` em sucesso.

### `curl_escape(sequence text)`
- Versão global antiga de URL-encoding (preserva bytes via tamanho explícito). Retorna string escapada e chama `curl_free()`.

### `curl_unescape(sequence text)`
- Assinatura corrigida para 2 argumentos C (`const char *, int`). Decodifica URL até o primeiro `\0` e chama `curl_free()`. (Para payloads binários com `\0`, use `curl_easy_unescape()`.)

---

## 15. Família `curl_m*printf`

Todas as 10 funções `mprintf` da DLL estão vinculadas para cobertura integral (96/96). **Em Euphoria, prefira `printf()` e `sprintf()` nativos.**

- **`curl_mprintf(sequence text)`**: imprime `text` em `stdout` via `"%s"`. Retorna quantidade de chars impressos.
- **`curl_mfprintf(atom c_file_ptr, sequence text)`**: imprime `text` no `FILE *` C indicado.
- **`curl_msprintf(atom out_buf, sequence text)`**: escreve `text` no buffer C `out_buf` (garanta espaço suficiente!).
- **`curl_msnprintf(atom out_buf, atom max_len, sequence text)`**: escreve até `max_len` bytes no buffer C `out_buf`.
- **`curl_maprintf(sequence text)`**: formata via DLL, copia como `sequence` e libera o ponteiro com `curl_free()`.
- **`curl_mvprintf(sequence fmt, atom va_args_ptr = 0)`**: versão bruta passando `fmt` e `va_list` C.
- **`curl_mvfprintf(atom c_file_ptr, sequence fmt, atom va_args_ptr = 0)`**: imprime em `FILE *` com `va_list`.
- **`curl_mvsprintf(atom out_buf, sequence fmt, atom va_args_ptr = 0)`**: formata em `out_buf` com `va_list`.
- **`curl_mvsnprintf(atom out_buf, atom max_len, sequence fmt, atom va_args_ptr = 0)`**: formata até `max_len` em `out_buf` com `va_list`.
- **`curl_mvaprintf(sequence fmt, atom va_args_ptr = 0)`**: formata com `va_list`, retorna `sequence` e chama `curl_free()`.

---

## 16. Helpers Síncronos Modernos

### `curl_easy_perform_ex(atom curl)`
- Executa uma transferência síncrona no handle `curl` capturando todo o corpo da resposta automaticamente (via callback `cdecl` único e mapa de buffers isolado por handle, usando `CURLOPT_WRITEDATA`).
- **Retorno:** `{CURLcode, body_sequence}` — limpa a entrada do buffer interno ao terminar.

### `curl_easy_get_file(sequence url, sequence proxy = "", sequence filename = "")`
- Executa um download HTTP/HTTPS síncrono completo (ativa `CURLOPT_FOLLOWLOCATION = 1` e, no Windows, `CURLOPT_SSL_OPTIONS = CURLSSLOPT_NATIVE_CA`). Sempre chama `curl_easy_cleanup()` em todos os caminhos de erro ou sucesso.
- **Retorno:**
  - Se `length(filename) > 0`: grava os bytes em `filename` (modo `"wb"`) e retorna `CURLcode` (ou `CURLE_CANT_OPEN_FILE = 500` se não puder abrir o arquivo).
  - Se `filename = ""`: retorna `{CURLcode, body_sequence}`.

### `atoms_to_double(atom lo, atom hi)`
- Helper puro (sem alocação de memória) que converte dois inteiros/atoms de 32 bits em ordem little-endian (`lo`, `hi`) em um número `atom` IEEE-754 de 64 bits.

---

## 17. Catálogo Completo de Constantes (`curl_constants.e`)

O arquivo `curl_constants.e` (`namespace curl_const`, re-exportado como `public` por `euLibCurl.ew`) define **1.127 constantes** extraídas diretamente dos cabeçalhos da libcurl **8.15.0_5**:

| Prefixo / Grupo | Quantidade / Faixa | Finalidade e Principais Valores |
|---|---|---|
| `CURLE_*` | `0..102` + `CURLE_CANT_OPEN_FILE = 500` | Códigos de retorno da interface Easy: `CURLE_OK (0)`, `CURLE_UNSUPPORTED_PROTOCOL (1)`, `CURLE_URL_MALFORMAT (3)`, `CURLE_COULDNT_RESOLVE_HOST (6)`, `CURLE_COULDNT_CONNECT (7)`, `CURLE_HTTP_RETURNED_ERROR / CURLE_HTTP_NOT_FOUND (22)`, `CURLE_WRITE_ERROR (23)`, `CURLE_OPERATION_TIMEDOUT (28)`, `CURLE_SSL_CONNECT_ERROR (35)`, `CURLE_ABORTED_BY_CALLBACK (42)`, `CURLE_TOO_MANY_REDIRECTS (47)`, `CURLE_PEER_FAILED_VERIFICATION / CURLE_SSL_CACERT (60)`. |
| `CURLOPTTYPE_*` | Base de tipos | `LONG (0)`, `OBJECTPOINT / STRINGPOINT / SLISTPOINT / CBPOINT (10000)`, `FUNCTIONPOINT (20000)`, `OFF_T (30000)`, `BLOB (40000)`, `VALUES (0)`. |
| `CURLOPT_*` | **323 opções** (100% da DLL 8.15.0) + aliases | Ex: `CURLOPT_URL (10002)`, `CURLOPT_HTTPHEADER (10023)`, `CURLOPT_POST (47)`, `CURLOPT_POSTFIELDS (10015)`, `CURLOPT_POSTFIELDSIZE_LARGE (30120)`, `CURLOPT_CUSTOMREQUEST (10036)`, `CURLOPT_NOBODY (44)`, `CURLOPT_FOLLOWLOCATION (52)`, `CURLOPT_MAXREDIRS (68)`, `CURLOPT_TIMEOUT_MS (155)`, `CURLOPT_CONNECTTIMEOUT_MS (156)`, `CURLOPT_WRITEFUNCTION (20011)`, `CURLOPT_WRITEDATA (10001)`, `CURLOPT_HEADERFUNCTION (20079)`, `CURLOPT_XFERINFOFUNCTION (20219)`, `CURLOPT_NOPROGRESS (43)`, `CURLOPT_SSL_VERIFYPEER (64)`, `CURLOPT_SSL_VERIFYHOST (81)`, `CURLOPT_SSL_OPTIONS (216)`, `CURLOPT_CAINFO_BLOB (40309)`, `CURLOPT_MIMEPOST (10269)`, `CURLOPT_MAX_RECV_SPEED_LARGE (30146)`, `CURLOPT_RESUME_FROM_LARGE (30116)`. |
| `CURLOT_*` | `0..8` + `CURLOT_FLAG_ALIAS (1)` | Tipos de opção em `curl_easy_option_*`: `CURLOT_LONG (0)`, `CURLOT_VALUES (1)`, `CURLOT_OFF_T (2)`, `CURLOT_OBJECT (3)`, `CURLOT_STRING (4)`, `CURLOT_SLIST (5)`, `CURLOT_CBPTR (6)`, `CURLOT_BLOB (7)`, `CURLOT_FUNCTION (8)`. |
| `CURLINFO_*` | Máscaras + ~65 campos | Máscaras: `CURLINFO_STRING (#100000)`, `CURLINFO_LONG (#200000)`, `CURLINFO_DOUBLE (#300000)`, `CURLINFO_SLIST (#400000)`, `CURLINFO_PTR (#400000)`, `CURLINFO_SOCKET (#500000)`, `CURLINFO_OFF_T (#600000)`, `CURLINFO_TYPEMASK (#F00000)`. Campos comuns: `CURLINFO_EFFECTIVE_URL`, `CURLINFO_RESPONSE_CODE`, `CURLINFO_TOTAL_TIME`, `CURLINFO_CONTENT_TYPE`, `CURLINFO_SIZE_DOWNLOAD_T`, `CURLINFO_CONTENT_LENGTH_DOWNLOAD_T`, `CURLINFO_SPEED_DOWNLOAD_T`, `CURLINFO_SIZE_UPLOAD_T`, `CURLINFO_SPEED_UPLOAD_T`, `CURLINFO_REDIRECT_COUNT`, `CURLINFO_HTTP_VERSION`. |
| `CURLM_*` / `CURLMOPT_*` / `CURLMSG_*` | Multi Interface | Erros: `CURLM_CALL_MULTI_PERFORM (-1)`, `CURLM_OK (0)` .. `CURLM_UNRECOVERABLE_POLL (12)`. Opções: `CURLMOPT_MAX_TOTAL_CONNECTIONS (13)`, `CURLMOPT_MAX_HOST_CONNECTIONS (7)`, `CURLMOPT_MAXCONNECTS (6)`, `CURLMOPT_PIPELINING (3)`. Mensagens: `CURLMSG_DONE (1)`. Polling: `CURL_WAIT_POLLIN/PRI/OUT`, `CURL_POLL_*`, `CURL_CSELECT_*`, `CURLPIPE_*`. |
| `CURLSHE_*` / `CURLSHOPT_*` / `CURL_LOCK_*` | Share Interface | Erros `CURLSHE_OK (0)` .. `CURLSHE_NOT_BUILT_IN (5)`; opções `CURLSHOPT_SHARE (1)`, `CURLSHOPT_UNSHARE (2)`, `LOCKFUNC`, `UNLOCKFUNC`, `USERDATA`; dados `CURL_LOCK_DATA_COOKIE/DNS/SSL_SESSION/CONNECT/PSL/HSTS`; acessos `CURL_LOCK_ACCESS_SHARED/SINGLE`. |
| `CURLUE_*` / `CURLUPART_*` / `CURLU_*` | URL API | Erros `CURLUE_OK (0)` .. `CURLUE_BAD_USER (29)`; partes `CURLUPART_URL (0)` .. `CURLUPART_ZONEID (10)`; flags `CURLU_DEFAULT_PORT (1)`, `CURLU_URLDECODE (64)`, `CURLU_URLENCODE (128)`, `CURLU_APPENDQUERY (256)`, `CURLU_PUNYCODE (4096)`, etc. |
| `CURLH_*` / `CURLHE_*` | Header API | Origens: `CURLH_HEADER (1)`, `CURLH_TRAILER (2)`, `CURLH_CONNECT (4)`, `CURLH_1XX (8)`, `CURLH_PSEUDO (16)`. Erros: `CURLHE_OK (0)` .. `CURLHE_NOT_BUILT_IN (7)`. |
| `CURLWS_*` | WebSockets API | Frame flags: `CURLWS_TEXT (1)`, `CURLWS_BINARY (2)`, `CURLWS_CONT (4)`, `CURLWS_CLOSE (8)`, `CURLWS_PING (16)`, `CURLWS_OFFSET (32)`, `CURLWS_PONG (64)`. Opções `CURLOPT_WS_OPTIONS`: `CURLWS_RAW_MODE (1)`, `CURLWS_NOAUTOPONG (2)`. |
| `CURL_GLOBAL_*` / SSL / HTTP / Proxy / Auth / Pause | Configurações diversas | `CURL_GLOBAL_DEFAULT (3)`, `CURLSSLOPT_NATIVE_CA (16)`, `CURLSSLOPT_NO_REVOKE (2)`, `CURLSSLSET_OK (0)`, `CURLUSESSL_*`, `CURL_HTTP_VERSION_*` (`1_0`, `1_1`, `2_0`, `2TLS`, `3`, `3ONLY`), `CURLPROXY_*` (`HTTP`, `HTTPS`, `SOCKS4`, `SOCKS5`, `SOCKS5_HOSTNAME`), `CURLAUTH_*` (`BASIC`, `DIGEST`, `BEARER`, `ANY`, `ANYSAFE`), `CURLPAUSE_*` (`ALL=5`, `CONT=0`, `RECV=1`, `SEND=4`), `CURL_IPRESOLVE_*`, `CURLVERSION_NOW (11)`, `CURL_VERSION_*`, `CURL_WRITEFUNC_PAUSE/ERROR`, `CURL_READFUNC_ABORT/PAUSE`, `CURL_SEEKFUNC_*`, `CURLFORM_*`, `CURL_BLOB_NOCOPY/COPY`, `CURL_PUSH_OK/DENY/ERROROUT`, `CURL_SOCKET_BAD (-1)`, `CURL_ZERO_TERMINATED (-1)`, `CURL_ERROR_SIZE (256)`. |
