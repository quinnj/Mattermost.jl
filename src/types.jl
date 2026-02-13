# ============================================================================
# Mattermost API Types
# https://api.mattermost.com/
# ============================================================================

# --- User ---

@defaults struct User
    id::String = ""
    create_at::Int64 = 0
    update_at::Int64 = 0
    delete_at::Int64 = 0
    username::String = ""
    first_name::Union{String, Nothing} = nothing
    last_name::Union{String, Nothing} = nothing
    nickname::Union{String, Nothing} = nothing
    email::Union{String, Nothing} = nothing
    email_verified::Union{Bool, Nothing} = nothing
    auth_service::Union{String, Nothing} = nothing
    roles::Union{String, Nothing} = nothing
    locale::Union{String, Nothing} = nothing
    props::Union{JSON.Object, Nothing} = nothing
    last_password_update::Union{Int64, Nothing} = nothing
    last_picture_update::Union{Int64, Nothing} = nothing
    failed_attempts::Union{Int64, Nothing} = nothing
    mfa_active::Union{Bool, Nothing} = nothing
    is_bot::Union{Bool, Nothing} = nothing
    bot_description::Union{String, Nothing} = nothing
end

# --- Team ---

@defaults struct Team
    id::String = ""
    create_at::Int64 = 0
    update_at::Int64 = 0
    delete_at::Int64 = 0
    display_name::String = ""
    name::String = ""
    description::Union{String, Nothing} = nothing
    email::Union{String, Nothing} = nothing
    type::Union{String, Nothing} = nothing
    allowed_domains::Union{String, Nothing} = nothing
    invite_id::Union{String, Nothing} = nothing
    allow_open_invite::Union{Bool, Nothing} = nothing
end

# --- Channel ---

@defaults struct Channel
    id::String = ""
    create_at::Int64 = 0
    update_at::Int64 = 0
    delete_at::Int64 = 0
    team_id::Union{String, Nothing} = nothing
    type::String = ""
    display_name::String = ""
    name::String = ""
    header::Union{String, Nothing} = nothing
    purpose::Union{String, Nothing} = nothing
    last_post_at::Union{Int64, Nothing} = nothing
    total_msg_count::Union{Int64, Nothing} = nothing
    creator_id::Union{String, Nothing} = nothing
end

# --- ChannelMember ---

@defaults struct ChannelMember
    channel_id::String = ""
    user_id::String = ""
    roles::Union{String, Nothing} = nothing
    last_viewed_at::Union{Int64, Nothing} = nothing
    msg_count::Union{Int64, Nothing} = nothing
    mention_count::Union{Int64, Nothing} = nothing
    last_update_at::Union{Int64, Nothing} = nothing
end

# --- Post ---

@defaults struct Post
    id::String = ""
    create_at::Int64 = 0
    update_at::Int64 = 0
    delete_at::Int64 = 0
    edit_at::Union{Int64, Nothing} = nothing
    user_id::String = ""
    channel_id::String = ""
    root_id::Union{String, Nothing} = nothing
    original_id::Union{String, Nothing} = nothing
    message::String = ""
    type::Union{String, Nothing} = nothing
    props::Union{JSON.Object, Nothing} = nothing
    hashtag::Union{String, Nothing} = nothing
    file_ids::Union{Vector{String}, Nothing} = nothing
    pending_post_id::Union{String, Nothing} = nothing
    metadata::Union{JSON.Object, Nothing} = nothing
end

# --- PostList ---

@defaults struct PostList
    order::Union{Vector{String}, Nothing} = nothing
    posts::Union{JSON.Object, Nothing} = nothing
    next_post_id::Union{String, Nothing} = nothing
    prev_post_id::Union{String, Nothing} = nothing
    has_next::Union{Bool, Nothing} = nothing
end

# --- Bot ---

@defaults struct Bot
    user_id::String = ""
    create_at::Int64 = 0
    update_at::Int64 = 0
    delete_at::Int64 = 0
    username::String = ""
    display_name::Union{String, Nothing} = nothing
    description::Union{String, Nothing} = nothing
    owner_id::Union{String, Nothing} = nothing
end

# --- FileInfo ---

@defaults struct FileInfo
    id::String = ""
    user_id::Union{String, Nothing} = nothing
    post_id::Union{String, Nothing} = nothing
    create_at::Union{Int64, Nothing} = nothing
    update_at::Union{Int64, Nothing} = nothing
    delete_at::Union{Int64, Nothing} = nothing
    name::Union{String, Nothing} = nothing
    extension::Union{String, Nothing} = nothing
    size::Union{Int64, Nothing} = nothing
    mime_type::Union{String, Nothing} = nothing
end

# --- WebSocket Event ---

@defaults struct WebSocketEvent
    event::String = ""
    data::Union{JSON.Object, Nothing} = nothing
    broadcast::Union{JSON.Object, Nothing} = nothing
    seq::Int64 = 0
end

# --- StatusOK ---

struct StatusOK
    status::String
end
