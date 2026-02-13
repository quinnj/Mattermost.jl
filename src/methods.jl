# ============================================================================
# Mattermost API Methods
# https://api.mattermost.com/
# ============================================================================

# ===== Limits & helpers =====================================================

const MAX_POST_MESSAGE_LENGTH = 16383

"""
    split_message_text(text; limit=MAX_POST_MESSAGE_LENGTH) -> Vector{String}

Split `text` into chunks no longer than `limit` characters.
Prefers splitting on newline boundaries, then whitespace.
"""
function split_message_text(text::AbstractString; limit::Int = MAX_POST_MESSAGE_LENGTH)
    limit >= 1 || throw(ArgumentError("limit must be >= 1"))
    isempty(text) && return String[]

    parts = String[]
    start = firstindex(text)
    last_idx = lastindex(text)
    while start <= last_idx
        stop = nextind(text, start, limit - 1)
        if stop > last_idx
            push!(parts, String(text[start:last_idx]))
            break
        end
        sub = SubString(text, start, stop)
        br = findlast(==('\n'), sub)
        br === nothing && (br = findlast(isspace, sub))
        (br === nothing || br == start) && (br = stop)
        push!(parts, String(text[start:br]))
        start = nextind(text, br)
    end
    return parts
end

# ===== Bot info =============================================================

"""
    get_me() -> User

Get the authenticated user (bot or human).
"""
get_me() = _get(User, "users/me")

# ===== Users ================================================================

"""
    get_user(user_id::String) -> User

Get a user by ID.
"""
get_user(user_id::String) = _get(User, "users/$user_id")

"""
    get_user_by_username(username::String) -> User

Get a user by username.
"""
get_user_by_username(username::String) = _get(User, "users/username/$username")

# ===== Teams ================================================================

"""
    get_teams() -> Vector{Team}

Get all teams the authenticated user is a member of.
"""
get_teams() = _get(Vector{Team}, "users/me/teams")

"""
    get_team(team_id::String) -> Team

Get a team by ID.
"""
get_team(team_id::String) = _get(Team, "teams/$team_id")

"""
    get_team_by_name(name::String) -> Team

Get a team by name.
"""
get_team_by_name(name::String) = _get(Team, "teams/name/$name")

# ===== Channels =============================================================

"""
    get_channel(channel_id::String) -> Channel

Get a channel by ID.
"""
get_channel(channel_id::String) = _get(Channel, "channels/$channel_id")

"""
    get_channel_by_name(team_id::String, name::String) -> Channel

Get a channel by name within a team.
"""
get_channel_by_name(team_id::String, name::String) =
    _get(Channel, "teams/$team_id/channels/name/$name")

"""
    get_channels_for_user(user_id::String, team_id::String) -> Vector{Channel}

Get channels for a user in a team.
"""
get_channels_for_user(user_id::String, team_id::String) =
    _get(Vector{Channel}, "users/$user_id/teams/$team_id/channels")

"""
    create_direct_channel(user_id_1::String, user_id_2::String) -> Channel

Create a direct message channel between two users.
"""
create_direct_channel(user_id_1::String, user_id_2::String) =
    _post(Channel, "channels/direct"; body=[user_id_1, user_id_2])

"""
    get_channel_members(channel_id::String; page=nothing, per_page=nothing) -> Vector{ChannelMember}

Get members of a channel.
"""
function get_channel_members(channel_id::String; page=nothing, per_page=nothing)
    query = _build_params(; page, per_page)
    _get(Vector{ChannelMember}, "channels/$channel_id/members";
        query=isempty(query) ? nothing : query)
end

# ===== Posts ================================================================

"""
    create_post(channel_id::String, message::String;
        root_id=nothing, file_ids=nothing, props=nothing) -> Post

Create a new post in a channel.
"""
function create_post(channel_id::String, message::String;
        root_id=nothing, file_ids=nothing, props=nothing)
    body = _build_params(; channel_id, message, root_id, file_ids, props)
    _post(Post, "posts"; body)
end

"""
    get_post(post_id::String) -> Post

Get a post by ID.
"""
get_post(post_id::String) = _get(Post, "posts/$post_id")

"""
    update_post(post_id::String; message=nothing, is_pinned=nothing, props=nothing) -> Post

Update a post.
"""
function update_post(post_id::String; message=nothing, is_pinned=nothing, props=nothing)
    body = _build_params(; id=post_id, message, is_pinned, props)
    _put(Post, "posts/$post_id"; body)
end

"""
    patch_post(post_id::String; message=nothing, is_pinned=nothing, file_ids=nothing, props=nothing) -> Post

Partially update a post.
"""
function patch_post(post_id::String; message=nothing, is_pinned=nothing, file_ids=nothing, props=nothing)
    body = _build_params(; message, is_pinned, file_ids, props)
    _put(Post, "posts/$post_id/patch"; body)
end

"""
    delete_post(post_id::String)

Delete a post.
"""
delete_post(post_id::String) = _delete(Any, "posts/$post_id")

"""
    get_channel_posts(channel_id::String; page=nothing, per_page=nothing, since=nothing, before=nothing, after=nothing) -> PostList

Get posts for a channel.
"""
function get_channel_posts(channel_id::String; page=nothing, per_page=nothing,
        since=nothing, before=nothing, after=nothing)
    query = _build_params(; page, per_page, since, before, after)
    _get(PostList, "channels/$channel_id/posts";
        query=isempty(query) ? nothing : query)
end

"""
    get_post_thread(post_id::String) -> PostList

Get a post and its thread.
"""
get_post_thread(post_id::String) = _get(PostList, "posts/$post_id/thread")

"""
    send_long_message(channel_id::String, text::String; limit=MAX_POST_MESSAGE_LENGTH, kwargs...) -> Vector{Post}

Send `text` split into multiple posts if it exceeds the length limit.
"""
function send_long_message(channel_id::String, text::String;
        limit::Int = MAX_POST_MESSAGE_LENGTH, kwargs...)
    parts = split_message_text(text; limit)
    posts = Post[]
    for part in parts
        push!(posts, create_post(channel_id, part; kwargs...))
    end
    return posts
end

# ===== Bots =================================================================

"""
    get_bots(; page=nothing, per_page=nothing, include_deleted=nothing) -> Vector{Bot}

Get a page of bot accounts.
"""
function get_bots(; page=nothing, per_page=nothing, include_deleted=nothing)
    query = _build_params(; page, per_page, include_deleted)
    _get(Vector{Bot}, "bots"; query=isempty(query) ? nothing : query)
end

"""
    get_bot(bot_user_id::String) -> Bot

Get a bot by user ID.
"""
get_bot(bot_user_id::String) = _get(Bot, "bots/$bot_user_id")

"""
    create_bot(username::String; display_name=nothing, description=nothing) -> Bot

Create a new bot account.
"""
function create_bot(username::String; display_name=nothing, description=nothing)
    body = _build_params(; username, display_name, description)
    _post(Bot, "bots"; body)
end

"""
    disable_bot(bot_user_id::String) -> Bot

Disable a bot.
"""
disable_bot(bot_user_id::String) = _post(Bot, "bots/$bot_user_id/disable")

"""
    enable_bot(bot_user_id::String) -> Bot

Enable a bot.
"""
enable_bot(bot_user_id::String) = _post(Bot, "bots/$bot_user_id/enable")

# ===== Reactions ============================================================

"""
    add_reaction(post_id::String, emoji_name::String; user_id=nothing) -> Any

Add an emoji reaction to a post. If user_id is not provided, uses "me".
"""
function add_reaction(post_id::String, emoji_name::String; user_id=nothing)
    if user_id === nothing
        me = get_me()
        user_id = me.id
    end
    body = Dict("user_id" => user_id, "post_id" => post_id, "emoji_name" => emoji_name)
    _post(Any, "reactions"; body)
end
