# ============================================================================
# Streaming Message Support
#
# Allows incrementally updating a Mattermost post as content streams in
# (e.g., from an SSE-based AI agent response). Handles rate-limiting by
# batching edits at a configurable interval.
# ============================================================================

"""
    StreamingMessage

A handle to a Mattermost post that can be incrementally updated.
Edits are rate-limited to avoid excessive API calls.

Fields:
- `channel_id` — the channel containing the post
- `post_id` — the post being updated
- `buffer` — current accumulated text
- `last_sent` — the text that was last successfully sent
- `last_update` — timestamp of the last successful edit
- `min_interval` — minimum seconds between edits (default: 1.0)
- `pending` — whether there are unsent changes
"""
mutable struct StreamingMessage
    channel_id::String
    post_id::String
    buffer::String
    last_sent::String
    last_update::Float64
    min_interval::Float64
    pending::Bool
end

function _streaming_display_text(text::String)
    if length(text) <= MAX_POST_MESSAGE_LENGTH
        return text, false
    end
    parts = split_message_text(text; limit=MAX_POST_MESSAGE_LENGTH)
    return parts[1], true
end

"""
    send_streaming_message(channel_id, [initial_text]; min_interval=1.0, kwargs...) -> StreamingMessage

Send an initial post and return a `StreamingMessage` handle for incremental updates.

# Example
```julia
sm = send_streaming_message(channel_id, "Thinking...")
for chunk in sse_stream
    append!(sm, chunk)
end
finish!(sm)
```
"""
function send_streaming_message(channel_id::String,
        initial_text::String = "...";
        min_interval::Float64 = 1.0,
        kwargs...)
    post = create_post(channel_id, initial_text; kwargs...)
    StreamingMessage(channel_id, post.id, initial_text, initial_text,
        time(), min_interval, false)
end

"""
    update!(sm::StreamingMessage, text::String) -> StreamingMessage

Replace the message buffer and send an edit if the rate-limit interval has passed.
"""
function update!(sm::StreamingMessage, text::String)
    sm.buffer = text
    now = time()
    display_text, overflow = _streaming_display_text(text)
    if now - sm.last_update >= sm.min_interval && display_text != sm.last_sent
        try
            patch_post(sm.post_id; message=display_text)
            sm.last_update = now
            sm.last_sent = display_text
            sm.pending = overflow
        catch e
            e isa MattermostError || rethrow()
            sm.pending = true
        end
    else
        sm.pending = overflow || (display_text != sm.last_sent)
    end
    return sm
end

"""
    Base.append!(sm::StreamingMessage, chunk::String) -> StreamingMessage

Append `chunk` to the message buffer and attempt an edit.
"""
function Base.append!(sm::StreamingMessage, chunk::String)
    update!(sm, sm.buffer * chunk)
end

"""
    flush!(sm::StreamingMessage) -> StreamingMessage

Force an immediate edit, bypassing the rate-limit interval.
"""
function flush!(sm::StreamingMessage)
    display_text, overflow = _streaming_display_text(sm.buffer)
    if display_text != sm.last_sent
        patch_post(sm.post_id; message=display_text)
        sm.last_update = time()
        sm.last_sent = display_text
    end
    sm.pending = overflow
    return sm
end

"""
    finish!(sm::StreamingMessage; text=nothing, send_kwargs...) -> StreamingMessage

Send the final edit. If `text` is provided, it replaces the buffer first.
If the final text exceeds the limit, the post is edited with the first chunk
and remaining chunks are sent as new posts.
"""
function finish!(sm::StreamingMessage; text::Union{String,Nothing} = nothing, send_kwargs...)
    final_text = text !== nothing ? text : sm.buffer
    sm.buffer = final_text
    parts = split_message_text(final_text; limit=MAX_POST_MESSAGE_LENGTH)
    if isempty(parts)
        sm.pending = false
        return sm
    end

    first_part = parts[1]
    if first_part != sm.last_sent
        patch_post(sm.post_id; message=first_part)
        sm.last_sent = first_part
        sm.last_update = time()
    end

    for part in parts[2:end]
        create_post(sm.channel_id, part; send_kwargs...)
    end
    sm.pending = false
    return sm
end

"""
    with_streaming_message(f, channel_id; initial_text="...", kwargs...) -> StreamingMessage

Create a streaming message, execute `f(sm)`, then `finish!` automatically.

# Example
```julia
with_streaming_message(channel_id) do sm
    for chunk in sse_stream
        append!(sm, chunk)
    end
end
```
"""
function with_streaming_message(f::Function, channel_id::String;
        initial_text::String = "...", kwargs...)
    sm = send_streaming_message(channel_id, initial_text; kwargs...)
    try
        f(sm)
    finally
        finish!(sm)
    end
    return sm
end

"""
    stream_to_message(source, channel_id; initial_text="...", kwargs...) -> StreamingMessage

Consume an iterable `source` and stream each chunk to a Mattermost post.
"""
function stream_to_message(source, channel_id::String;
        initial_text::String = "...", kwargs...)
    sm = send_streaming_message(channel_id, initial_text; kwargs...)
    for chunk in source
        append!(sm, string(chunk))
    end
    finish!(sm)
    return sm
end
