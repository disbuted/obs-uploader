-- ██████╗ ██████╗ ███████╗    ██╗   ██╗██████╗ ██╗      ██████╗  █████╗ ██████╗ ███████╗██████╗ 
--██╔═══██╗██╔══██╗██╔════╝    ██║   ██║██╔══██╗██║     ██╔═══██╗██╔══██╗██╔══██╗██╔════╝██╔══██╗
--██║   ██║██████╔╝███████╗    ██║   ██║██████╔╝██║     ██║   ██║███████║██║  ██║█████╗  ██████╔╝
--██║   ██║██╔══██╗╚════██║    ██║   ██║██╔═══╝ ██║     ██║   ██║██╔══██║██║  ██║██╔══╝  ██╔══██╗
--╚██████╔╝██████╔╝███████║    ╚██████╔╝██║     ███████╗╚██████╔╝██║  ██║██████╔╝███████╗██║  ██║
-- ╚═════╝ ╚═════╝ ╚══════╝     ╚═════╝ ╚═╝     ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝
--                          [Lua x Curl Based Obs To Streamable.com Uploader]
--                        ====================================================
--                                   Written by @disbuted on github :3
--                                     https://github.com/disbuted
--
--                                              Read Me:
--                        Make sure you have curl installed on your system to be able
--                      to do the required calls as lua and curl are how this is written
--                              and for your videos / clips to be uploaded :D
--
--                                        discord : humbleness

obs = obslua

streamable_username = "" -- streamable email that you signed up with
streamable_password = "" -- this is obvious
clip_directory = ""  -- copy the location from your video output in obs and put it here

local function directory_exists(path)
    local f = io.popen('if exist "' .. path .. '" (echo yes) else (echo no)')
    local result = f:read("*a"):gsub("\n", ""):gsub("\r", "")
    f:close()
    return result == "yes"
end


function get_latest_clip()
    if not directory_exists(clip_directory) then
        obs.script_log(obs.LOG_ERROR, "Clip directory does not exist: " .. clip_directory)
        return nil
    end
    
    local pfile = io.popen('dir /B /O:D "' .. clip_directory .. '" 2>nul')
    if not pfile then
        obs.script_log(obs.LOG_ERROR, "Failed to open directory.")
        return nil
    end
    
    local last_file = nil
    for file in pfile:lines() do
        obs.script_log(obs.LOG_INFO, "Found file: " .. file)
        last_file = file
    end
    pfile:close()
    
    if not last_file then
        obs.script_log(obs.LOG_WARNING, "No clips found in directory.")
        return nil
    end
    
    local new_name = "OBS - " .. last_file
    local old_path = clip_directory .. "\\" .. last_file
    local new_path = clip_directory .. "\\" .. new_name
    
    local success, err = os.rename(old_path, new_path)
    if not success then
        obs.script_log(obs.LOG_ERROR, "Failed to rename file: " .. err)
        return old_path 
    end
    
    obs.script_log(obs.LOG_INFO, "Renamed clip to: " .. new_name)
    return new_path
end

function copy_to_clipboard(text)
    local command = string.format("echo %s | clip", text)
    os.execute(command)
    obs.script_log(obs.LOG_INFO, "Copied link to clipboard: " .. text)
end

function upload_clip()
    local latest_clip = get_latest_clip()
    if not latest_clip then
        obs.script_log(obs.LOG_WARNING, "No clip found to upload.")
        return
    end
    
    local upload_command = string.format(
        "curl -u %s:%s -F \"file=@%s\" https://api.streamable.com/upload", -- current api call, might change in the future but i doubt
        streamable_username, streamable_password, latest_clip
    )
    
    local pfile = io.popen(upload_command)
    if not pfile then
        obs.script_log(obs.LOG_ERROR, "Failed to execute upload command.")
        return
    end
    
    local response = pfile:read("*a"):gsub("%s+$", "")  
    pfile:close()
    obs.script_log(obs.LOG_INFO, "Raw Upload response: " .. response)
    
    local video_id = response:match('"shortcode"%s*:%s*"(.-)"')
    if video_id then
        local video_url = "https://streamable.com/" .. video_id
        copy_to_clipboard(video_url)
        obs.script_log(obs.LOG_INFO, "Upload successful! Video URL: " .. video_url)
    else
        obs.script_log(obs.LOG_ERROR, "Failed to extract video URL from response. Full response: " .. response)
    end
end

function on_event(event)
    if event == obs.OBS_FRONTEND_EVENT_REPLAY_BUFFER_SAVED then
        obs.script_log(obs.LOG_INFO, "Replay buffer saved. Starting upload...")
        upload_clip()
    end
end

function script_load(settings)
    obs.obs_frontend_add_event_callback(on_event)
end

function script_description()
    return "Obs To Streamable.com Replay Buffer Uploader - Copies The Streamable Link To Your Clipboard > github @ disbuted"
end