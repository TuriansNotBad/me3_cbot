Class CBotProxy extends Object;

struct ItemLookup 
{
    var string sReal;
    var string sId;
};

var array<ItemLookup> _kitLookup;
var array<ItemLookup> _wpnLookup;

// Functions -----------------------------------------------------------

function string GetItemByLookup(string itemId, out array<ItemLookup> items)
{
    local ItemLookup itemInfo;
    
    if (items.Length == 0)
    {
        return "";
    }

    if (itemId != "")
    {
        foreach items(itemInfo)
        {
            if (InStr(itemInfo.sId, itemId, false, true) == 0)
            {
                return itemInfo.sReal;
            }
        }
    }
    return "";
}

function string GetKitByLookup(string kitId)
{
    local string kit;

    kit = GetItemByLookup(kitId, _kitLookup);
    if (kit == "" && _kitLookup.Length > 0)
    {
        // choose a default here
        kit = _kitLookup[0].sReal;
    }
    return kit;
}

function string GetWeaponByLookup(string wpnId)
{
    local string wpn;

    wpn = GetItemByLookup(wpnId, _wpnLookup);
    if (wpn == "" && _wpnLookup.Length > 0)
    {
        // choose a default here
        wpn = _wpnLookup[0].sReal;
    }
    return wpn;
}

public function SummonAgent(BioPlayerController PC, SFXCheatManagerNonNativeMP cheatMgr, optional string kitId, optional string wpn, optional int logicId)
{
    local SFXPawn PlayerPawn;
    local SFXPawn_PlayerMP AIPawn;
    local Class<AIController> AIControllerClass;
    local SFXAI_Core AI;
    local BioBaseSquad PlayerSquad;
    local BioWorldInfo BWI;
    local SFXPRIMP agentPrimp;
    local Actor agentArchetype;
    local string agentKit;
    local string agentWpn;
    
    agentKit = GetKitByLookup(kitId);
    agentWpn = GetWeaponByLookup(wpn);
    if (agentKit == "" || agentWpn == "")
    {
        PC.ClientMessage("CBot: failed to get kit or weapon from Kit =" @ kitId @ "Weapon =" @ wpn);
        return;
    }
    if (logicId == 0)
    {
        // pick a logic
    }
    
    if (PC.Role != ENetRole.ROLE_Authority)
    {
        PC.ClientMessage("CBot: controller doesn't have authority");
        return;
    }
    
    BWI = BioWorldInfo(PC.WorldInfo);
    if (BWI == None)
    {
        PC.ClientMessage("CBot: no world");
        return;
    }
    
    if (SFXPRIMP(PC.PlayerReplicationInfo) == None)
    {
        PC.ClientMessage("CBot: no mp PlayerReplicationInfo");
        return;
    }
    
    PlayerPawn = SFXPawn(PC.Pawn);
    if (PlayerPawn == None)
    {
        PC.ClientMessage("CBot: no Player pawn");
        return;
    }
    
    // allow spawning inside of PC for now
    PlayerPawn.bBlockActors = FALSE;
    
    // Spawn AI Controller
    
    // AutoBotAIControllerName is "SFXGameContent.SFXAI_AutoBot"
    AIControllerClass = Class'SFXAI_CBotTurret';
    if (AIControllerClass == None)
    {
        PC.ClientMessage("CBot: failed to fetch AIControllerClass");
        return;
    }
    
    AI = SFXAI_Core(Class'Engine'.static.GetCurrentWorldInfo().Spawn(AIControllerClass, , , PC.location, PC.Rotation));
    if (AI == None)
    {
        PC.ClientMessage("CBot: failed to create AI controller");
        return;
    }
    
    // Spawn AI Pawn
    
    // Setup replication info
    agentPrimp = SFXPRIMP(AI.PlayerReplicationInfo);
    agentPrimp.SetCharacterKit(Name(agentKit));
    if (agentWpn != "")
    {
        agentWpn = "SFXGameContent." $ agentWpn;
        agentPrimp.SetWeapon(0, Name(agentWpn), 9);
    }

    agentArchetype = SFXPawn_PlayerMP(
        Class'SFXEngine'.static.GetSeekFreeObject(agentPrimp.GetPawnArchetype(), Class'SFXPawn_PlayerMP')
    );
    AIPawn = Class'Engine'.static.GetCurrentWorldInfo().Spawn(Class<SFXPawn_PlayerMP>(agentArchetype.Class), , , PC.Pawn.location, PC.Pawn.Rotation, agentArchetype, TRUE);
    if (AIPawn == None)
    {
        PC.ClientMessage("CBot: failed to spawn Pawn");
        return;
    }
    else
    {
        AIPawn.Kit = agentPrimp.GetCharacterKit();
    }
    
    AI.Possess(AIPawn, FALSE);
    AIPawn.SetLocation(PlayerPawn.location, );
    AIPawn.SetRotation(PC.Rotation);
    AI.SetTeam(0);
    
    PC.bGodMode = TRUE;
    AI.bGodMode = TRUE;
    
    PlayerSquad = PlayerPawn.Squad;
    PlayerSquad.AddMember(AIPawn, FALSE);
    
    AIPawn.m_fPowerUsePercent = BWI.m_fAutoBotAttackPowerPercent;
    
    // level up
    SFXPawn_Player(AIPawn).AutoLevelUpInfo = SFXPawn_Player(AIPawn).PlayerClass.default.AutoLevelUpInfo;
    SFXPawn_Player(PlayerPawn).AutoLevelUpInfo = SFXPawn_Player(PlayerPawn).PlayerClass.default.AutoLevelUpInfo;
    cheatMgr.MPBotsLevelUp(AIPawn, 20);
    
    BWI.SetAutoBotsEnabled(TRUE);
}

defaultproperties
{
    // character kit lookup table
    _kitLookup.Add((sReal="SentinelTurian",sId="tsent"))
    _kitLookup.Add((sReal="SoldierTurian",sId="tsol"))

    // weapon lookup table
    _wpnLookup.Add((sReal="SFXWeapon_AssaultRifle_Cobra",sId="phaeston"))
    _wpnLookup.Add((sReal="SFXWeapon_AssaultRifle_Avenger",sId="avenger"))
}
