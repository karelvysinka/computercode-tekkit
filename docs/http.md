# http

HTTP requests. Must be enabled in CC config (it is by default).

## Synchronous
- `http.get(url [, headers [, binary]])` -> response, or nil + error.
- `http.get({ url=..., headers=..., binary=..., method=... })` - table form.
- `http.post(url, body [, headers [, binary]])` -> response.
- `http.post({ url=..., body=..., headers=..., method=... })`.
- `http.request(...)` - asynchronous; fires `http_success` or `http_failure` event.
- `http.checkURL(url)` -> bool, error.

## Response handle
- `:readAll()`, `:readLine()`, `:read(n?)`.
- `:getResponseCode()` -> number.
- `:getResponseHeaders()` -> table.
- `:close()`.

## WebSockets
- `http.websocket(url [, headers])` -> handle.
- handle: `:send(text [, binary])`, `:receive(timeout?)`, `:close()`.
- Fires `websocket_success`, `websocket_failure`, `websocket_message`, `websocket_closed`.

## Pattern: POST JSON to a REST API
```lua
local body = textutils.serializeJSON({ messages = {{role="user", content="hi"}} })
local resp, err = http.post({
    url = "https://api.example.com/chat",
    body = body,
    headers = {
        ["Authorization"] = "Bearer " .. apiKey,
        ["Content-Type"]  = "application/json",
    },
})
if not resp then error(err) end
local data = textutils.unserializeJSON(resp.readAll())
resp.close()
```
