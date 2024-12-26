local g_aCMDs = {};
local g_flLastCMDTime = 0;

local g_aVoteOptions = {};

for _, sEventName in pairs({
    "vote_cast",
    "vote_options"
}) do
    mods.events:add_listener(sEventName);
end

local ETeams = { [0] = "U"; "S", "T", "CT" };
local EPlayerColor = { [0] = "Blue"; "Green", "Yellow", "Orange", "Purple" };

-- Called when a vote starts
local function OnVoteOptions(ctx)
    local aOptions = {};
    local iCount = ctx:get_int("count");
    local sTxt = "say_team \"VoteOptions = ";
    
    for i = 1, iCount do
        aOptions[i] = tostring(ctx:get_string(string.format("option%i", i)));
        if(i == iCount)then
            sTxt = sTxt .. aOptions[i];
        else
            sTxt = sTxt .. aOptions[i] .. ", ";
        end
    end

    g_aVoteOptions = aOptions;
    g_aCMDs[#g_aCMDs + 1] = sTxt .. '\"';
end

-- Called when someone casts a vote
local function OnVoteCast(ctx)
    local iCompTeammateColor = ctx:get_controller("userid").m_iCompTeammateColor:get();
    local sPlayerName = ctx:get_controller("userid"):get_name();
    g_aCMDs[#g_aCMDs + 1] = string.format("say_team \"[%s] %s voted %s \"", 
        ETeams[ctx:get_int("team")] or "UNK", EPlayerColor[iCompTeammateColor] or sPlayerName, 
        g_aVoteOptions[ctx:get_int("vote_option") + 1] or tostring(ctx:get_int("vote_option")));
end

events.event:add(function(ctx)
    local sEventName = ctx:get_name();
    if(sEventName == "vote_options")then
        OnVoteOptions(ctx);

    elseif(sEventName == "vote_cast")then
        OnVoteCast(ctx);

    end
end)

events.present_queue:add(function()
    if(#g_aCMDs == 0 or math.abs(g_flLastCMDTime - game.global_vars.real_time) < 0.3)then
        return;
    end
    g_flLastCMDTime = game.global_vars.real_time;

    if(not game.engine:in_game()) then
        g_mapPlayerKDs = {};
        g_aCMDs = {};
        return;
    end
    
    local aCMDs = {};
    if(#g_aCMDs > 1)then
        for i = 2, #g_aCMDs do
            aCMDs[i - 1] = g_aCMDs[i];
        end
    end

    game.engine:client_cmd(g_aCMDs[1]);
    g_aCMDs = aCMDs;
end);
