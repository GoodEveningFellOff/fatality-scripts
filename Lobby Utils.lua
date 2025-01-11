local function PatternScan(T, sModule, sPattern, sName, fnCallback)
    local p = utils.find_pattern(sModule, sPattern);
    if(p == 0)then
        error(string.format("Unable to find pattern %s", sName));
    end

    if(fnCallback)then
        p = ffi.cast("uintptr_t", fnCallback(p));
        if(p == 0)then
            error(string.format("Processed result of pattern %s failed", sName));
        end
    end

    return ffi.cast(T, p); 
end

local UiEngine = {
    m_pEngine = PatternScan("void**", "client.dll", "48 89 78 ? 48 89 0D ? ? ? ?", "UiEngine", function(p)
        return p + ffi.cast("int32_t*", p + 7)[0] + 11;
    end);

    m_pMainMenuPanel = PatternScan("uintptr_t*", "client.dll", "48 83 EC ? 48 8B 05 ? ? ? ? 48 8D 15", "MainMenuPanel", function(p)
        return p + ffi.cast("int32_t*", p + 7)[0] + 11;
    end);
};
do
    local fnRunScript = PatternScan("void(__thiscall*)(void*, void*, const char*, const char*, uint64_t)", 
        "panorama.dll", "4C 89 4C 24 ? 4C 89 44 24 ? 48 89 54 24 ? 55", "RunScript");
    function UiEngine:RunScript(sScript)
        if(ffi.cast("uintptr_t*", self.m_pEngine)[0] == 0 or self.m_pMainMenuPanel[0] == 0)then
            print("UiEngine:RunScript() failed");
            return;
        end

        local pPanel = ffi.cast("void**", self.m_pMainMenuPanel[0] + 8)[0];
        if(ffi.cast("uintptr_t", pPanel) == 0)then
            print("pPanel is NULL!");
            return;
        end

        return fnRunScript(self.m_pEngine[0], pPanel, sScript, "", 1);
    end
end

UiEngine:RunScript([[
var FatalityMainMenuLobby;
(function(FatalityMainMenuLobby) {
    const _aPrefixes = ['!', '/', '?', '.'];
    const _cBullet = '\u{2022}';
    const _cCheck = '\u{2714}';
    const _cTimes = '\u{2716}';
    const _regexFriendCode = /^(\w{5}-\w{4})$/i;

    let _m_elChatLinesContainer = undefined;
    function _FixLabelString(str) {
        return str.replaceAll('&apos;', `'`).replaceAll('&quot;', `"`).replaceAll('&lt;', `<`).replaceAll('&gt;', `>`).replaceAll('&amp;', `&`);
    };

    function _GetMapPool(sType = '', sMode = '') {
        let stGame = LobbyAPI.GetSessionSettings()?.game;
        let stMaps = GameTypesAPI.GetConfig()?.gameTypes?.[
            (sType.length !== 0) ? sType : stGame?.type]?.gameModes?.[
            (sMode.length !== 0) ? sMode : stGame?.mode]?.mapgroupsMP;

        if(!stMaps) return [];
        return Object.keys(stMaps);
    };

    function _UpdateActive() {
        let stGame = LobbyAPI.GetSessionSettings()?.game;
        let sMode = stGame?.mode_ui;
        let sMaps = stGame?.mapgroupname;
        if(!stGame || !sMode || !sMaps) return;

        if (sMode === 'competitive') {
            FatalityMainMenuLobby.m_aCompetitive = sMaps.split(',');

        } else if (sMode === 'scrimcomp2v2') {
            FatalityMainMenuLobby.m_aWingman = sMaps.split(',');
        
        } else if (sMode === 'casual') {
            FatalityMainMenuLobby.m_aCasual = [ sMaps.split(',')?.[0] ];

        } else if (sMode === 'deathmatch') {
            FatalityMainMenuLobby.m_aDeathmatch = [ sMaps.split(',')?.[0] ];
        }
    };

    function _GetForMode(sMode) {
        if (sMode === 'competitive') {
            return FatalityMainMenuLobby.m_aCompetitive;
        } else if (sMode === 'scrimcomp2v2') {
            return FatalityMainMenuLobby.m_aWingman;

        } else if (sMode === 'casual') {
            return FatalityMainMenuLobby.m_aCasual;

        } else if (sMode === 'deathmatch') {
            return FatalityMainMenuLobby.m_aDeathmatch;

        } else if (sMode === 'premier') {
            return ['mg_lobby_mapveto'];

        } else if (sMode === 'gungameprogressive') {
            return ['mg_skirmish_armsrace']

        }

        return [];
    };

    function _GetActive() {
        return _GetForMode(LobbyAPI.GetSessionSettings()?.game?.mode_ui);
    };

    function _ToggleMap(sMap) {
        let sMode = LobbyAPI.GetSessionSettings()?.game?.mode_ui;
        
        if (sMode === 'competitive') {
            // If the map is already in the array remove it, otherwise add it.
            var index = FatalityMainMenuLobby.m_aCompetitive.indexOf(sMap);
            if (index > -1) {
                FatalityMainMenuLobby.m_aCompetitive.splice(index, 1);
                return false;
            } else {
                FatalityMainMenuLobby.m_aCompetitive.push(sMap);
                return true;
            }

        } else if (sMode === 'scrimcomp2v2') {
            // If the map is already in the array remove it, otherwise add it.
            var index = FatalityMainMenuLobby.m_aWingman.indexOf(sMap);
            if (index > -1) {
                FatalityMainMenuLobby.m_aWingman.splice(index, 1);
                return false;
            } else {
                FatalityMainMenuLobby.m_aWingman.push(sMap);
                return true;
            }                
        }

        return true;
    };

    function _GetPlayer(aArgs) {
        let aMembers = LobbyAPI.GetSessionSettings().members;
        const iVal = parseInt(aArgs[0]);
        if(isNaN(iVal)){
            let aValidPlayers = [];
            for (let i = 0; i < aMembers.numMachines; i++) {
                let stPlayer = aMembers[`machine${i}`];
                if(stPlayer.player0.name.startsWith(aArgs.join(' '))) {
                    aValidPlayers.push(stPlayer.player0);
                }
            }

            if(aValidPlayers.length == 1){
                return aValidPlayers[0];    
            }

            aValidPlayers = [];

            if(_regexFriendCode.test(aArgs[0]))
            {
                let xuid = FriendsListAPI.GetXuidFromFriendCode(aArgs[0].toUpperCase());
                for (let i = 0; i < aMembers.numMachines; i++) {
                    let stPlayer = aMembers[`machine${i}`];
                    if(stPlayer.player0.steamid == xuid){
                        aValidPlayers.push(stPlayer.player0);
                    }
                }

                if(aValidPlayers.length == 1){
                    return aValidPlayers[0];
                }
            }

            return null;
        }
        else if(iVal < aMembers.numMachines && iVal >= 0){
            return aMembers[`machine${iVal}`].player0;
        }

        aValidPlayers = [];
        for (let i = 0; i < aMembers.numMachines; i++) {
            let stPlayer = aMembers[`machine${i}`];
            if(stPlayer.player0.xuid == aArgs[0]){
                aValidPlayers.push(stPlayer.player0);
            }
        }

        if(aValidPlayers.length == 1){
            return aValidPlayers[0];
        }
        
        return null;
    };

    function _SayParty(sMsg) {
        PartyListAPI.SessionCommand('Game::Chat', `run all xuid ${MyPersonaAPI.GetXuid()} chat ${sMsg.split(' ').join('\u{00A0}')}`);
    };

    function _SaySuccess(sMsg) {
        let sPrefix = (`${_cCheck} ${_cBullet} ${sMsg}`).split(' ').join('\u{00A0}');
        PartyListAPI.SessionCommand('Game::Chat', `run all xuid ${MyPersonaAPI.GetXuid()} chat ${sPrefix}`);
    };

    function _SayError(sMsg) {
        let sPrefix = (`${_cTimes} ${_cBullet} ${sMsg}`).split(' ').join('\u{00A0}');
        PartyListAPI.SessionCommand('Game::Chat', `run all xuid ${MyPersonaAPI.GetXuid()} chat ${sPrefix}`);
    };

    function _StartQueue() {
        LobbyAPI.StartMatchmaking(MyPersonaAPI.GetMyOfficialTournamentName(), MyPersonaAPI.GetMyOfficialTeamName(), '', '');
    };

    function _StopQueue() {
        if(LobbyAPI.GetMatchmakingStatusString() !== '') LobbyAPI.StopMatchmaking();
    };

    function _InvitePlayer(sFriendCode) {
        if (sFriendCode === null) return;

        let xuid = sFriendCode;  
        if(_regexFriendCode.test(sFriendCode)){
            xuid = FriendsListAPI.GetXuidFromFriendCode(sFriendCode.toUpperCase());
        }

        StoreAPI.RecordUIEvent("ActionInviteFriendFrom_nearby");
        FriendsListAPI.ActionInviteFriend(xuid, '');
        $.DispatchEvent('FriendInvitedFromContextMenu', xuid);            
    };

    function _UpdateSessionSettings(stGame) {
        if(LobbyAPI.GetMatchmakingStatusString() !== ''){
            _StopQueue();
            LobbyAPI.UpdateSessionSettings({ update: { game: stGame } });
            $.Schedule(1, _StartQueue);
        } 
        else {
            LobbyAPI.UpdateSessionSettings({ update: { game: stGame} }); 
        }
        
        $.Schedule(0.1, _UpdateActive);
    };

    let _m_aCommands = [];
    _m_aCommands = [
        { m_sTitle: 'Help', m_aAliases: ['help', 'h'], m_bEnabled: true, m_bHostOnly: false, m_bTrustedOnly: false, m_fnExec: (aArgs, sUser, sSteamID) => {
            const bIsHost = LobbyAPI.BIsHost();

            _m_aCommands.forEach((stCommand, i) => {
                if (i == 0 || !stCommand.m_bEnabled) 
                    return;

                _SayParty(`${(bIsHost || !stCommand.m_bHostOnly) ? _cCheck : _cTimes} ${stCommand.m_sTitle} ${_cBullet} (` + stCommand.m_aAliases.map((y) => `${_aPrefixes[0]}${y}`).join(', ') + ')');
            });
        }},

        { m_sTitle: 'Invite', m_aAliases: ['invite', 'inv'], m_bEnabled: false, m_bHostOnly: false, m_bTrustedOnly: false, m_fnExec: (aArgs, sUser, sSteamID) => {
            if (aArgs.length === 0) {
                _SayError('A friend code or steam id must be provided!');
                return;
            }
            
            _InvitePlayer(aArgs[0]);
        }},

        { m_sTitle: 'Start Queue', m_aAliases: ['startq', 'start', 'q'], m_bEnabled: true, m_bHostOnly: true, m_bTrustedOnly: false, m_fnExec: (aArgs, sUser, sSteamID) => {
            _StartQueue();
        }},

        { m_sTitle: 'Stop Queue', m_aAliases: ['stopq', 'stop', 'sq', 's'], m_bEnabled: true, m_bHostOnly: false, m_bTrustedOnly: false, m_fnExec: (aArgs, sUser, sSteamID) => {
            _StopQueue();
        }},

        { m_sTitle: 'Restart Queue', m_aAliases: ['restartq', 'restart', 'rq'], m_bEnabled: true, m_bHostOnly: true, m_bTrustedOnly: false, m_fnExec: (aArgs, sUser, sSteamID) => {
            _StopQueue();
            $.Schedule(1, () => {
                _StartQueue();
            });
        }},

        { m_sTitle: 'Map Pool', m_aAliases: ['pool', 'mp'], m_bEnabled: true, m_bHostOnly: false, m_bTrustedOnly: false, m_fnExec: (aArgs, sUser, sSteamID) => {
            let stSettings = LobbyAPI.GetSessionSettings();

            let aMaps = [];
            for (const sMapName of _GetMapPool()) {
                aMaps.push($.Localize(GameTypesAPI.GetMapGroupAttribute(sMapName, 'nameID')));
            }

            _SayParty(`${_cBullet} ${$.Localize('#SFUI_GameMode_' + stSettings.game.mode)} Map Pool:`);

            let iChunk = 0;
            for (var i = 0; i < Math.ceil(aMaps.length / 4); i++) {
                _SayParty(_cBullet + ' ' + aMaps.slice(iChunk, iChunk + 4).join(', '));
                iChunk += 4;
            }
        }},

        { m_sTitle: 'Toggle Map', m_aAliases: ['maps', 'map', 'm'], m_bEnabled: true, m_bHostOnly: true, m_bTrustedOnly: false, m_fnExec: (aArgs, sUser, sSteamID) => {
            _UpdateActive();
            let aMapPool = _GetMapPool();
            let sMode = LobbyAPI.GetSessionSettings().game.mode_ui;

            // No args? Show current maps.
            if (aArgs.length === 0 || sMode == 'premier') {
                _SayParty(`${_cBullet} Current Maps:`);

                let aMaps = [];
                for(const sMapName of _GetActive()){
                    aMaps.push($.Localize(GameTypesAPI.GetMapGroupAttribute(sMapName, 'nameID')));
                }

                let iChunk = 0;
                for (var i = 0; i < Math.ceil(aMaps.length / 4); i++) {
                    _SayParty(_cBullet + ' ' + aMaps.slice(iChunk, iChunk + 4).join(', '));
                    iChunk += 4;
                }

                return;
            }

            let sChangedMap = '';
            let sLocalizedMapName = '';

            // Find the map in the pool.
            for (const sMapInPool of aMapPool) {
                const sLocalizedName = $.Localize(GameTypesAPI.GetMapGroupAttribute(sMapInPool, 'nameID'));
                const regexMap = new RegExp(sMapInPool, 'i');
                const regexName = new RegExp(sLocalizedName, 'i');
                const sMapName = aArgs.join(' ');
                
                if(regexMap.test(sMapName) || regexName.test(sMapName)){
                    sChangedMap = sMapInPool;
                    sLocalizedMapName = sLocalizedName;
                    break;
                }
            }

            // No map found.
            if(sChangedMap.length === 0){
                _SayError(`Unknown map!`);
                return;
            }

        
            
            if(sMode === 'competitive' || sMode === 'scrimcomp2v2') {
                // Toggle the map and log if it was added or removed.
                if(_ToggleMap(sChangedMap)){
                    _SaySuccess(`Added ${sLocalizedMapName}!`);
                }
                else {
                    _SaySuccess(`Removed ${sLocalizedMapName}!`);
                }

            } else {
                if(_GetActive()[0] === sChangedMap) {
                    return;
                }
                
                _GetActive()[0] = sChangedMap
                _SaySuccess(`Changed Map to ${sLocalizedMapName}!`);
            }
            

            _UpdateSessionSettings({ mapgroupname: _GetActive().join()});
        }},

        { m_sTitle: 'Gamemode', m_aAliases: ['gamemode', 'mode', 'gm'], m_bEnabled: true, m_bHostOnly: true, m_bTrustedOnly: false, m_fnExec: (aArgs, sUser, sSteamID) => {
            const regexCompetitive =  /^(mm|co.{0,9})$/i;
            const regexWingman = /^(wm|w.{0,6})$/i;
            const regexPremier = /^(pm|p.{0,6})$/i;
            const regexCasual = /^(ca.{0,4})$/i;
            const regexDeathmatch = /^(dm|d.{0,9})$/i;
            const regexArmsRace = /^(a.{0,7})$/i;

            let stSettings = LobbyAPI.GetSessionSettings();
            let stGame = {};
            if (regexCompetitive.test(aArgs[0])) {
                if(stSettings.game.mode_ui === 'competitive'){
                    return;
                }

                stGame.type = 'classic';
                stGame.mode_ui = 'competitive';
                stGame.gamemodeflags = 16;
                _SaySuccess(`Changed Gamemode to Competitive!`);

            } else if (regexWingman.test(aArgs[0])) {
                if(stSettings.game.mode_ui === 'scrimcomp2v2'){
                    return;
                }

                stGame.type = 'classic';
                stGame.mode_ui = 'scrimcomp2v2';
                stGame.gamemodeflags = 0;
                _SaySuccess(`Changed Gamemode to Wingman!`);

            } else if (regexPremier.test(aArgs[0])) {
                if(stSettings.game.mode_ui === 'premier'){
                    return;
                }

                stGame.type = 'classic';
                stGame.mode = 'competitive';
                stGame.mode_ui = 'premier';
                stGame.gamemodeflags = 16;
                _SaySuccess(`Changed Gamemode to Premier!`);

            } else if(regexCasual.test(aArgs[0])) {
                if(stSettings.game.mode_ui === 'casual') {
                    return;
                }

                stGame.type = 'classic';
                stGame.mode = 'casual';
                stGame.mode_ui = 'casual';
                stGame.gamemodeflags = 0;
                _SaySuccess(`Changed Gamemode to Casual!`);
                
            } else if(regexDeathmatch.test(aArgs[0])) {
                if(stSettings.game.mode_ui === 'deathmatch'){
                    return;
                }

                stGame.type = 'gungame';
                stGame.mode = 'deathmatch';
                stGame.mode_ui = 'deathmatch';
                stGame.gamemodeflags = 32;
                _SaySuccess(`Changed Gamemode to Deathmatch!`);

            } else if(regexArmsRace.test(aArgs[0])) {
                if(stSettings.game.mode_ui === 'gungameprogressive') {
                    return;
                }

                stGame.type = 'skirmish';
                stGame.mode = 'skirmish';
                stGame.mode_ui = 'gungameprogressive';
                stGame.gamemodeflags = 0;
                _SaySuccess(`Changed Gamemode to Arms Race!`);
                
            } else {
                
                if (stSettings.game.mode_ui == 'competitive') {

                    stGame.type = 'classic';
                    stGame.mode = 'scrimcomp2v2';
                    stGame.mode_ui = 'scrimcomp2v2';
                    stGame.gamemodeflags = 0;
                    _SaySuccess(`Changed Gamemode to Wingman!`);

                } else if(stSettings.game.mode_ui == 'scrimcomp2v2') {
                    stGame.type = 'classic';
                    stGame.mode = 'competitive';
                    stGame.mode_ui = 'premier';
                    stGame.gamemodeflags = 16;

                    _SaySuccess(`Changed Gamemode to Premier!`);
                } else {

                    stGame.type = 'classic';
                    stGame.mode = 'competitive';
                    stGame.mode_ui = 'competitive';
                    stGame.gamemodeflags = 16;
                    
                    _SaySuccess(`Changed Gamemode to Competitive!`);
                }
            }

            if(!stGame.mode){
                stGame.mode = stGame.mode_ui;
            }

            stGame.mapgroupname = _GetForMode(stGame.mode_ui).join();

            _UpdateSessionSettings(stGame);
        }},

        { m_sTitle: 'Remake Lobby', m_aAliases: ['remake', 'reload', 'rl'], m_bEnabled: true, m_bHostOnly: false, m_bTrustedOnly: false, m_fnExec: (aArgs, sUser, sSteamID) => {
            _UpdateActive();
            let stSettings = LobbyAPI.GetSessionSettings();

            let sMySteamID = MyPersonaAPI.GetXuid();
            let aSteamIDs = [];
            for (let i = 0; i < stSettings.members.numMachines; i++) {
                let stPlayer = stSettings.members[`machine${i}`];
                if ( sMySteamID != stPlayer.id ) {
                    aSteamIDs.push(stPlayer.id)
                }
            }
            
            LobbyAPI.CloseSession();
            LobbyAPI.CreateSession();
            PartyListAPI.SessionCommand('MakeOnline', '');
        
            $.Schedule(0.5, () => {
                _UpdateSessionSettings(stSettings.game); 
                for (let i = 0; i < aSteamIDs.length; i++ ) {
                    _InvitePlayer(aSteamIDs[i]);
                }
            });
        }},

        { m_sTitle: 'List Players', m_aAliases: ['list', 'ls'], m_bEnabled: true, m_bHostOnly: false, m_bTrustedOnly: false, m_fnExec: (aArgs, sUser, sSteamID) => {
            let aMembers = LobbyAPI.GetSessionSettings().members;
            for (let i = 0; i < aMembers.numMachines; i++) {
                let stPlayer = aMembers[`machine${i}`];
                _SayParty(`${_cBullet} [${i}] = ${stPlayer.player0.name}`);
            }
        }},

        { m_sTitle: 'Location', m_aAliases: ['locate', 'loc'], m_bEnabled: true, m_bHostOnly: false, m_bTrustedOnly: false, m_fnExec: (aArgs, sUser, sSteamID) => {
            const mapLocations = {
                AF: "Afghanistan", AX: "Åland Islands", AL: "Albania", DZ: "Algeria", AS: "American Samoa", AD: "AndorrA", AO: "Angola", AI: "Anguilla", AQ: "Antarctica", AG: "Antigua and Barbuda",
                AR: "Argentina", AM: "Armenia", AW: "Aruba", AU: "Australia", AT: "Austria", AZ: "Azerbaijan", BS: "Bahamas", BH: "Bahrain", BD: "Bangladesh", BB: "Barbados",
                BY: "Belarus", BE: "Belgium", BZ: "Belize", BJ: "Benin", BM: "Bermuda", BT: "Bhutan", BO: "Bolivia", BA: "Bosnia and Herzegovina", BW: "Botswana", BV: "Bouvet Island",
                BR: "Brazil", IO: "British Indian Ocean Territory", BN: "Brunei Darussalam", BG: "Bulgaria", BF: "Burkina Faso", BI: "Burundi", KH: "Cambodia", CM: "Cameroon", CA: "Canada", CV: "Cape Verde",
                KY: "Cayman Islands", CF: "Central African Republic", TD: "Chad", CL: "Chile", CN: "China", CX: "Christmas Island", CC: "Cocos (Keeling) Islands", CO: "Colombia", KM: "Comoros", CG: "Congo",
                CD: "Congo, The Democratic Republic of the", CK: "Cook Islands", CR: "Costa Rica", CI: "Cote D\'Ivoire", HR: "Croatia", CU: "Cuba", CY: "Cyprus", CZ: "Czech Republic", DK: "Denmark", DJ: "Djibouti",
                DM: "Dominica", DO: "Dominican Republic", EC: "Ecuador", EG: "Egypt", SV: "El Salvador", GQ: "Equatorial Guinea", ER: "Eritrea", EE: "Estonia", ET: "Ethiopia", FK: "Falkland Islands (Malvinas)",
                FO: "Faroe Islands", FJ: "Fiji", FI: "Finland", FR: "France", GF: "French Guiana", PF: "French Polynesia", TF: "French Southern Territories", GA: "Gabon", GM: "Gambia", GE: "Georgia",
                DE: "Germany", GH: "Ghana", GI: "Gibraltar", GR: "Greece", GL: "Greenland",  GD: "Grenada", GP: "Guadeloupe", GU: "Guam", GT: "Guatemala", GG: "Guernsey",
                GN: "Guinea", GW: "Guinea-Bissau", GY: "Guyana", HT: "Haiti", HM: "Heard Island and Mcdonald Islands", VA: "Holy See (Vatican City State)", HN: "Honduras", HK: "Hong Kong", HU: "Hungary", IS: "Iceland",
                IN: "India", ID: "Indonesia", IR: "Iran, Islamic Republic Of", IQ: "Iraq", IE: "Ireland", IM: "Isle of Man", IL: "Israel", IT: "Italy", JM: "Jamaica", JP: "Japan",
                JE: "Jersey", JO: "Jordan", KZ: "Kazakhstan", KE: "Kenya", KI: "Kiribati", KP: "Korea, Democratic People\'S Republic of", KR: "Korea, Republic of", KW: "Kuwait", KG: "Kyrgyzstan", LA: "Lao People\'S Democratic Republic",
                LV: "Latvia", LB: "Lebanon", LS: "Lesotho", LR: "Liberia", LY: "Libyan Arab Jamahiriya", LI: "Liechtenstein", LT: "Lithuania", LU: "Luxembourg", MO: "Macao", MK: "Macedonia, The Former Yugoslav Republic of",
                MG: "Madagascar", MW: "Malawi", MY: "Malaysia", MV: "Maldives", ML: "Mali", MT: "Malta", MH: "Marshall Islands", MQ: "Martinique", MR: "Mauritania", MU: "Mauritius",
                YT: "Mayotte", MX: "Mexico", FM: "Micronesia, Federated States of", MD: "Moldova, Republic of", MC: "Monaco", MN: "Mongolia", MS: "Montserrat", MA: "Morocco", MZ: "Mozambique", MM: "Myanmar",
                NA: "Namibia", NR: "Nauru", NP: "Nepal", NL: "Netherlands", AN: "Netherlands Antilles", NC: "New Caledonia", NZ: "New Zealand", NI: "Nicaragua", NE: "Niger", NG: "Nigeria",
                NU: "Niue", NF: "Norfolk Island", MP: "Northern Mariana Islands", NO: "Norway", OM: "Oman", PK: "Pakistan", PW: "Palau", PS: "Palestinian Territory, Occupied", PA: "Panama", PG: "Papua New Guinea",
                PY: "Paraguay", PE: "Peru", PH: "Philippines", PN: "Pitcairn", PL: "Poland", PT: "Portugal", PR: "Puerto Rico", QA: "Qatar", RE: "Reunion", RO: "Romania",
                RU: "Russian Federation", RW: "RWANDA", SH: "Saint Helena", KN: "Saint Kitts and Nevis", LC: "Saint Lucia", PM: "Saint Pierre and Miquelon", VC: "Saint Vincent and the Grenadines", WS: "Samoa", SM: "San Marino", ST: "Sao Tome and Principe",
                SA: "Saudi Arabia", SN: "Senegal", CS: "Serbia and Montenegro", SC: "Seychelles", SL: "Sierra Leone", SG: "Singapore", SK: "Slovakia", SI: "Slovenia", SB: "Solomon Islands", SO: "Somalia",
                ZA: "South Africa", GS: "South Georgia and the South Sandwich Islands", ES: "Spain", LK: "Sri Lanka", SD: "Sudan", SR: "Suriname", SJ: "Svalbard and Jan Mayen", SZ: "Swaziland", SE: "Sweden", CH: "Switzerland",
                SY: "Syrian Arab Republic", TW: "Taiwan, Province of China", TJ: "Tajikistan", TZ: "Tanzania, United Republic of", TH: "Thailand", TL: "Timor-Leste", TG: "Togo", TK: "Tokelau",
                TO: "Tonga", TT: "Trinidad and Tobago", TN: "Tunisia", TR: "Turkey", TM: "Turkmenistan", TC: "Turks and Caicos Islands", TV: "Tuvalu", UG: "Uganda", UA: "Ukraine", AE: "United Arab Emirates",
                GB: "United Kingdom", US: "United States", UM: "United States Minor Outlying Islands", UY: "Uruguay", UZ: "Uzbekistan", VU: "Vanuatu", VE: "Venezuela", VN: "Viet Nam", VG: "Virgin Islands, British", VI: "Virgin Islands, U.S.",
                WF: "Wallis and Futuna", EH: "Western Sahara", YE: "Yemen", ZM: "Zambia", ZW: "Zimbabwe"
            };

            let aMembers = LobbyAPI.GetSessionSettings().members;

            if(aArgs.length !== 0) {
                let stPlayer = _GetPlayer(aArgs);
                if(!stPlayer){
                    _SayError(`Invalid player!`);
                    return;
                }

                _SayParty(`${_cBullet} ${stPlayer.name} is from ${mapLocations[stPlayer.game.loc]}`);
                return;
            }

            for (let i = 0; i < aMembers.numMachines; i++) {
                let stPlayer = aMembers[`machine${i}`];
                _SayParty(`${_cBullet} ${stPlayer.player0.name} is from ${mapLocations[stPlayer.player0.game.loc]}`);
            }
        }},

        { m_sTitle: 'Kick', m_aAliases: ['kick', 'rm'], m_bEnabled: true, m_bHostOnly: true, m_bTrustedOnly: true, m_fnExec: (aArgs, sUser, sSteamID) => {
            let aMembers = LobbyAPI.GetSessionSettings().members;
            if(aArgs.length === 0){
                _SayError('Must provide a player to kick');
                return;
            }

            let stPlayer = _GetPlayer(aArgs);
            if(!stPlayer){
                _SayError('Invalid player');
                return;
            }

            if(stPlayer.xuid ==  MyPersonaAPI.GetXuid() || stPlayer.xuid == sSteamID){
                _SayError('Cannot kick that player');
                return;
            }

            LobbyAPI.KickPlayer(stPlayer.xuid);
        }},

        { m_sTitle: 'Clear', m_aAliases: ['clear', 'cc'], m_bEnabled: true, m_bHostOnly: false, m_bTrustedOnly: true, m_fnExec: (aArgs, sUser, sSteamID) => {
            if(!_m_elChatLinesContainer) return;
            
            let sMsg = '';
            for(let i = 0; i < 100; i++) {
                sMsg = sMsg + `\u{2028} `;
            }
            for(let i = 0; i < 10; i++) {
                _SayParty(sMsg);
            }
            
            $.Schedule(0.5, () => {
                // If we don't safe the last element then we will not be able to open chat.
                let elLast = _m_elChatLinesContainer.GetChild(0);
                elLast.SetParent(_m_elChatLinesContainer.GetParent());
                _m_elChatLinesContainer.RemoveAndDeleteChildren();
                elLast.SetParent(_m_elChatLinesContainer);
            });
        }},

        { m_sTitle: '8Ball', m_aAliases: ['8ball', '8b'], m_bEnabled: true, m_bHostOnly: false, m_bTrustedOnly: false, m_fnExec: (aArgs, sUser, sSteamID) => {
            const a8BallAnswers = [
                'It is certain', 'It is decidedly so', 'Without a doubt', 'Yes definitely', 'You may rely on it', 'As I see it, yes', 'Most likely', 'Outlook good', 'Yes', 'Signs point to yes',
                'Reply hazy, try again', 'Ask again later', 'Better not tell you now', 'Cannot predict now', 'Concentrate and ask again',
                'Don\'t count on it', 'My reply is no', 'My sources say no', 'Outlook not so good', 'Very doubtful'
            ];

            if (aArgs.length === 0) {
                _SayError('You must ask the magic 8ball a question!');
                return;
            }
                
            _SayParty(`\u{2791} ${_cBullet} ${a8BallAnswers[Math.round(Math.random() * (19))]}`);
        }},

        { m_sTitle: 'Dice', m_aAliases: ['dice', 'roll', 'd'], m_bEnabled: true, m_bHostOnly: false, m_bTrustedOnly: false, m_fnExec: (aArgs, sUser, sSteamID) => {
            _SayParty(`${_cBullet} ${sUser} rolled a ${Math.round(Math.random() * 19) + 1}`);
        }},

        { m_sTitle: 'Gay', m_aAliases: ['gay'], m_bEnabled: true, m_bHostOnly: false, m_bTrustedOnly: false, m_fnExec: (aArgs, sUser, sSteamID) => {
            _SayParty(`${_cBullet} ${sUser} is ${Math.round(Math.random() * 100)}% gay!`);  
        }},
    ];

    function _OnNewChatEntry(elEntry, sType) {
        if(sType !== 'PlayerChat'){
            return
        }

        $.Schedule(0, function(elEntry)
        {
            if(!elEntry.BHasClass('chat-entry')){
                return;
            }

            if(elEntry.GetParent().BHasClass('chat-container__lines')) _m_elChatLinesContainer = elEntry.GetParent();

            let elPanel = elEntry.GetChild(0);
            if(!elPanel.BHasClass('left-right-flow') || !elPanel.BHasClass('horizontal-align-left')){
                return;
            }
            
            let elCSGOAvatarImage = elPanel.GetChild(0);
            let elLabel = elPanel.GetChild(elPanel.GetChildCount() - 1);
            
            let sUser = _FixLabelString($.Localize('{s:player_name}', elLabel));
            let sMsg  = _FixLabelString($.Localize('{s:msg}', elLabel));
            let sSteamID = elCSGOAvatarImage.steamid.toString();
            if(sSteamID === '0'){
                sSteamID = FatalityMainMenuLobby.m_sLastSteamID;
            }
            else {
                FatalityMainMenuLobby.m_sLastSteamID = sSteamID;    
            }

            let cPrefix = '';
            
            _aPrefixes.forEach((c) => { if(sMsg.startsWith(c)) cPrefix = c; });
            if (cPrefix.length === 0) return;

            const aArgs = sMsg.slice(cPrefix.length).trim().split(' ');
            const sCommand = aArgs.shift().toLowerCase();
            const bIsHost = LobbyAPI.BIsHost();
            _m_aCommands.every((stCommand) => {
                if (!stCommand.m_bEnabled || (!bIsHost && stCommand.m_bHostOnly)) {
                    return true;
                }

                if (stCommand.m_bTrustedOnly && !(MyPersonaAPI.GetXuid() === sSteamID || FriendsListAPI.GetFriendRelationship(sSteamID) === 'friend')){
                    return true;
                }
                    
                
                stCommand.m_aAliases.every((sGoalCommand) => {
                    if (sGoalCommand === sCommand) {
                        stCommand.m_fnExec(aArgs, sUser, sSteamID);
                        return false;
                    }
                    return true;
                });

                return true;
            });

        }.bind(this, elEntry));
    };
    
    function _OnSessionUpdate() {
        _UpdateActive();
    };

    function _OnReadyUpForMatch(bShouldShow) {
        // Store session settings so we can recreate the lobby once the match is over.
    };

    function _RegisterEvent(sEventName, fn) {
        if(!FatalityMainMenuLobby.m_mapHandlers[sEventName]) {
            FatalityMainMenuLobby.m_mapHandlers[sEventName] = [];
        }

        FatalityMainMenuLobby.m_mapHandlers[sEventName].push($.RegisterForUnhandledEvent(sEventName, fn));
    };

    if(!FatalityMainMenuLobby.UnregisterEvents) {
        
        FatalityMainMenuLobby.m_aCompetitive = _GetMapPool('classic', 'competitive');
        FatalityMainMenuLobby.m_aWingman = _GetMapPool('classic', 'scrimcomp2v2');
        FatalityMainMenuLobby.m_aCasual = [ _GetMapPool('classic', 'casual')?.[0] ];
        FatalityMainMenuLobby.m_aDeathmatch = [ _GetMapPool('gungame', 'deathmatch')?.[0] ];
        FatalityMainMenuLobby.m_sLastSteamID = '0';
        FatalityMainMenuLobby.m_mapHandlers = {};

        FatalityMainMenuLobby.UnregisterEvents = function() {
            for (const [key, value] of Object.entries(FatalityMainMenuLobby.m_mapHandlers)) {
                for (const v of value) {
                    $.UnregisterForUnhandledEvent(key, v);
                    FatalityMainMenuLobby.m_mapHandlers[key] = FatalityMainMenuLobby.m_mapHandlers[key].filter((x) => x != v);
                }
            }
        }
    }

    FatalityMainMenuLobby.UnregisterEvents();
    
    // Register events.
    {
        LobbyAPI.CreateSession();
        PartyListAPI.SessionCommand('MakeOnline', '');
        $.Schedule(1, _UpdateActive);
        _RegisterEvent("OnNewChatEntry", _OnNewChatEntry);
        _RegisterEvent("PanoramaComponent_Lobby_MatchmakingSessionUpdate", _OnSessionUpdate);
        _RegisterEvent("PanoramaComponent_GC_Hello", _OnSessionUpdate);
        //_RegisterEvent("PanoramaComponent_Lobby_ReadyUpForMatch", _OnReadyUpForMatch);
    }
})(FatalityMainMenuLobby || (FatalityMainMenuLobby = {}));
]]);
