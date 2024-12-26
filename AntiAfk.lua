local g_vecPosition = vector(0, 0, 0);
local g_bSwitcher, g_bLeft, g_bRight = false, false, false;
local g_flLastCheckTime = 0;
events.frame_stage_notify:add(function(eStage)
    if(eStage ~= client_frame_stage.render_start)then
        return;
    end

    if(not game.engine:in_game())then
        return;
    end

    local pLocalPawn = entities.get_local_pawn();
    local vecPosition = pLocalPawn:get_abs_origin();
    if(not pLocalPawn:is_alive())then
        return;
    end

    if(g_bLeft)then
        game.engine:client_cmd("-left");
        g_bLeft = false;
        g_vecPosition = vecPosition;
    end

    if(g_bRight)then
        game.engine:client_cmd("-right");
        g_bRight = false;
        g_vecPosition = vecPosition;
    end

    if(vecPosition:dist(g_vecPosition) > 1)then
        g_flLastCheckTime = game.global_vars.real_time;
        g_vecPosition = vecPosition;
        return;
    end

    if(math.abs(g_flLastCheckTime - game.global_vars.real_time) < 10)then
        return;
    end

    g_flLastCheckTime = game.global_vars.real_time;

    if(g_bSwitcher)then
        game.engine:client_cmd("+left");
        g_bLeft = true;
    else
        game.engine:client_cmd("+right");
        g_bRight = true;
    end

    g_bSwitcher = not g_bSwitcher;
end);
