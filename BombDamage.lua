for _, sEventName in pairs({
    "bomb_beginplant",
    "bomb_planted",
    "bomb_defused",
    "bomb_exploded",
    "round_prestart"
}) do
    mods.events:add_listener(sEventName);
end

local g_vecBombPosition = vector(0, 0, 0);
local g_bIsPlanted = false;
events.event:add(function(ctx)
    local sEventName = ctx:get_name();
    if(sEventName == "bomb_beginplant")then
        g_vecBombPosition = ctx:get_controller("userid"):get_pawn():get_abs_origin();

    elseif(sEventName == "bomb_planted")then
        g_bIsPlanted = true;

    elseif(sEventName == "bomb_defused" or sEventName == "bomb_exploded" or sEventName == "round_prestart")then
        g_bIsPlanted = false;
    end
end);

local function GetBombRadius()
    --https://raw.githubusercontent.com/GoodEveningFellOff/Aimware-Scripts/main/Utils/CS2%20GetBombRadiusFn.lua
    local m = {
        -- Updated December-24th-2024 @21:52 EST
        -- map_showbombradius || bombradius @ game/csgo/maps/<map>.vpk/entities/default_ents.vents_c ## only lists if value is overwritten
        ["maps/de_ancient.vpk" ] = 650 * 3.5;
        ["maps/de_anubis.vpk"  ] = 450 * 3.5;
        ["maps/de_assembly.vpk"] = 500 * 3.5;
        ["maps/de_inferno.vpk" ] = 620 * 3.5;
        ["maps/de_mills.vpk"   ] = 500 * 3.5;
        ["maps/de_mirage.vpk"  ] = 650 * 3.5;
        ["maps/de_nuke.vpk"    ] = 650 * 3.5;
        ["maps/de_overpass.vpk"] = 650 * 3.5;
        ["maps/de_thera.vpk"   ] = 500 * 3.5;
        ["maps/de_vertigo.vpk" ] = 500 * 3.5;
        ["maps/de_train.vpk"   ] = 500 * 3.5; 
        ["maps/de_basalt.vpk"  ] = 500 * 3.5;
        ["maps/cs_italy.vpk"   ] = 500 * 3.5;
        ["maps/ar_pool_day.vpk"] = 500 * 3.5;
    };
    
    return m[game.global_vars.map_path] or 1750;
end

events.present_queue:add(function()
    if(not game.engine:in_game())then
        g_bIsPlanted = false;
    end

    if(not g_bIsPlanted)then
        return;
    end

    local pLocalController = entities.get_local_controller();
    local pLocalPawn = pLocalController:get_pawn();
    if(not pLocalPawn or not pLocalPawn:is_alive())then
        pLocalPawn = pLocalController:get_observer_target();
    end

    if(not pLocalPawn)then
        return;
    end

    local iHealth = pLocalPawn.m_iHealth:get();
    local iArmor = pLocalPawn.m_ArmorValue:get();
    local iBombRadius = GetBombRadius();

    if(iHealth <= 0)then
        return;
    end
	
	local flDistance = g_vecBombPosition:dist(pLocalPawn:get_eye_pos());
	local flDamage = (iBombRadius / 3.5) * math.exp(flDistance^2 / (-2 * (iBombRadius / 3)^2));

	if(iArmor > 0)then
		local flReducedDamage = flDamage / 2;
		
		if(iArmor < flReducedDamage)then
			local flReducedFraction = iArmor / flReducedDamage;
			flDamage = (flReducedFraction * flReducedDamage) + (1 - flReducedFraction) * flDamage;

		else
			flDamage = flReducedDamage;
		end
	end

	flDamage = math.floor(flDamage + 0.5);
    if(flDamage <= 0)then
        return;
    end

    local layer = draw.surface;
    layer.font = draw.fonts.gui_title;

    local v = math.floor(255 - 200 * math.clamp(flDamage / iHealth, 0, 1));
    local iWidth, iHeight = game.engine:get_screen_size();

    local vec2Position = draw.vec2(iWidth * 0.01, iHeight * 0.45);
    local sText = (flDamage >= iHealth) and "LETHAL" or ("-%0.0fHP"):format(flDamage);
    layer:add_text(draw.vec2(vec2Position.x + 1, vec2Position.y + 1), sText, draw.color(0, 0, 0));
    layer:add_text(vec2Position, sText, draw.color(255, v, v));
end);
