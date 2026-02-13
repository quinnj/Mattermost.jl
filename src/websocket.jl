# ============================================================================
# WebSocket Event Listener
#
# Connects to the Mattermost WebSocket API to receive real-time events.
# This is the primary mechanism for building bots — analogous to Telegram's
# long-polling but over a persistent WebSocket connection.
# ============================================================================

"""
    run_websocket(handler::Function; error_handler=nothing)

Connect to the Mattermost WebSocket and call `handler(event::WebSocketEvent)`
for each received event. Blocks indefinitely.

The connection is authenticated via the Authorization header using the
current client's token. Auto-reconnects with exponential backoff on
connection failures.

# Example
```julia
with_mattermost("BOT_TOKEN", "https://mm.example.com") do
    run_websocket() do event
        if event.event == "posted"
            post_data = JSON.parse(event.data["post"])
            channel_id = post_data["channel_id"]
            message = post_data["message"]
            create_post(channel_id, "Echo: \$message")
        end
    end
end
```
"""
function run_websocket(handler::Function;
        error_handler::Union{Function, Nothing} = nothing)
    client = _get_client()
    ws_url = _websocket_url(client)
    headers = ["Authorization" => "Bearer $(client.token)"]
    @info "Mattermost.run_websocket: Connecting to $ws_url"

    consecutive_errors = 0
    while true
        try
            HTTP.WebSockets.open(ws_url; headers) do ws
                consecutive_errors = 0
                @info "Mattermost.run_websocket: Connected and authenticated"

                for msg in ws
                    try
                        data = JSON.parse(String(msg))
                        # Skip status responses and hello events
                        haskey(data, "event") || continue
                        event = _parse_result(WebSocketEvent, data)
                        try
                            handler(event)
                        catch e
                            bt = catch_backtrace()
                            if error_handler !== nothing
                                error_handler(e, bt)
                            else
                                @error "WebSocket handler error" exception=(e, bt)
                            end
                        end
                    catch e
                        if e isa HTTP.WebSockets.WebSocketError || e isa EOFError
                            rethrow()
                        end
                        @error "WebSocket parse error" exception=(e, catch_backtrace())
                    end
                end
            end
        catch e
            if e isa InterruptException
                @info "Mattermost.run_websocket: Interrupted, stopping"
                rethrow()
            end
            consecutive_errors += 1
            backoff = min(60, 2^min(consecutive_errors, 6))
            @error "WebSocket connection error (reconnecting in $(backoff)s)" exception=(e, catch_backtrace())
            sleep(backoff)
        end
    end
end

"""
Build the WebSocket URL from the client's base_url.
Converts `https://server/api/v4/` -> `wss://server/api/v4/websocket`
Converts `http://server/api/v4/` -> `ws://server/api/v4/websocket`
"""
function _websocket_url(client::Client)
    url = rstrip(client.base_url, '/')
    url = replace(url, r"^https://" => "wss://")
    url = replace(url, r"^http://" => "ws://")
    return string(url, "/websocket")
end
