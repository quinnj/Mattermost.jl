# ============================================================================
# Mattermost API Client Infrastructure
# ============================================================================

# --- Error type ---

struct MattermostError <: Exception
    status_code::Int
    id::String
    message::String
end

Base.showerror(io::IO, e::MattermostError) =
    print(io, "MattermostError($(e.status_code)): $(e.message) [$(e.id)]")

# --- Client ---

struct Client
    token::String
    base_url::String  # e.g. "https://mattermost.example.com/api/v4/"
end

const MATTERMOST_CLIENT = ScopedValue{Client}()

"""
    with_mattermost(f::Function, token::String, server_url::String)

Execute `f` with a scoped Mattermost client.

# Example
```julia
with_mattermost("BOT_TOKEN", "https://mattermost.example.com") do
    me = get_me()
    println("Bot: \$(me.username)")
end
```
"""
function with_mattermost(f::Function, token::String, server_url::String)
    url = rstrip(server_url, '/')
    client = Client(token, string(url, "/api/v4/"))
    @with MATTERMOST_CLIENT => client f()
end

"""
    with_client(f::Function, client::Client)

Execute `f` with an existing `Client` bound as the active Mattermost client.
Useful for re-establishing the client context in spawned tasks.
"""
with_client(f::Function, client::Client) = @with MATTERMOST_CLIENT => client f()

function _get_client()
    isassigned(MATTERMOST_CLIENT) || error("No Mattermost client set. Use `with_mattermost(token, server_url)` to set credentials.")
    return MATTERMOST_CLIENT[]
end

# --- Request helpers ---

function _build_params(; kwargs...)
    params = Dict{String,Any}()
    for (k, v) in kwargs
        v !== nothing && (params[String(k)] = v)
    end
    return params
end

_parse_result(::Type{Bool}, result) = result::Bool
_parse_result(::Type{Int64}, result) = Int64(result)
_parse_result(::Type{String}, result) = String(result)
_parse_result(::Type{Any}, result) = result
_parse_result(::Type{Vector{T}}, result) where T = T[_parse_result(T, x) for x in result]
function _parse_result(::Type{T}, result) where T
    JSON.parse(JSON.json(result), T)
end

function _auth_headers(client::Client)
    return [
        "Authorization" => "Bearer $(client.token)",
        "Content-Type" => "application/json",
    ]
end

"""
    _request(::Type{T}, method, path; body=nothing, query=nothing) -> T

Make an authenticated request to the Mattermost API.
"""
function _request(::Type{T}, method::String, path::String;
        body=nothing, query=nothing) where T
    client = _get_client()
    url = string(client.base_url, lstrip(path, '/'))
    headers = _auth_headers(client)
    kw = Dict{Symbol,Any}(:status_exception => false)
    if body !== nothing
        kw[:body] = JSON.json(body; omit_null=true)
    end
    if query !== nothing
        kw[:query] = query
    end
    resp = HTTP.request(method, url, headers; kw...)
    if resp.status >= 400
        data = try
            JSON.parse(String(resp.body))
        catch
            nothing
        end
        if data !== nothing && haskey(data, "message")
            throw(MattermostError(
                get(data, "status_code", resp.status),
                get(data, "id", ""),
                get(data, "message", "Unknown error"),
            ))
        end
        throw(MattermostError(resp.status, "", "HTTP $(resp.status)"))
    end
    # Some endpoints return empty body (204 No Content)
    if T === Nothing || isempty(resp.body)
        return nothing
    end
    data = JSON.parse(String(resp.body))
    _parse_result(T, data)
end

# Convenience wrappers
_get(::Type{T}, path; query=nothing) where T = _request(T, "GET", path; query)
_post(::Type{T}, path; body=nothing, query=nothing) where T = _request(T, "POST", path; body, query)
_put(::Type{T}, path; body=nothing) where T = _request(T, "PUT", path; body)
_delete(::Type{T}, path) where T = _request(T, "DELETE", path)
