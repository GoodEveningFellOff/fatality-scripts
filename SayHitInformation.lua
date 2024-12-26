local g_aCMDs = {};
local g_flLastCMDTime = 0;

local EHitgroups = { [0] = "body"; "head", "chest", "stomach", "arm", "arm", "leg", "leg" };

events.event:add(function(ctx)
    if(ctx:get_name() ~= "player_hurt")then
        return;
    end

    local pLocalPawn = entities.get_local_pawn();
    local pVictimPawn = ctx:get_pawn_from_id("userid");
    if(pLocalPawn ~= ctx:get_pawn_from_id("attacker") or pLocalPawn == pVictimPawn)then
        return;
    end

    g_aCMDs[#g_aCMDs + 1] = string.format("say \"[fatality] Hit %s for %s hp in %s (%i remaining)\"", 
        pVictimPawn:get_name(), ctx:get_int("dmg_health"), EHitgroups[ctx:get_int("hitgroup")] or "body", ctx:get_int("health"));
end)

events.present_queue:add(function()
    if(#g_aCMDs == 0 or math.abs(g_flLastCMDTime - game.global_vars.real_time) < 0.3)then
        return;
    end
    g_flLastCMDTime = game.global_vars.real_time;

    if(not game.engine:in_game()) then
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
