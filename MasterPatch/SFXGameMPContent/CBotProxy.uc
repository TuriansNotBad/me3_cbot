Class CBotProxy extends Object;

struct KitLookup 
{
    var string sReal;
    var string sId;
};

var array<KitLookup> _kitLookup;

// Functions -----------------------------------------------------------

function string GetKitFromKitId(string kitId)
{
    local KitLookup kitInfo;
    
    if (kitId != "")
    {
        foreach _kitLookup(kitInfo)
        {
            if (kitInfo.sId == kitId)
            {
                return kitInfo.sReal;
            }
        }
    }
    return _kitLookup[0].sReal;
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
    
    agentKit = GetKitFromKitId(kitId);
    if (wpn == "")
    {
        // pick a weapon
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
	
    AIControllerClass = Class<AIController>(Class'SFXEngine'.static.GetSeekFreeObject(cheatMgr.AutoBotAIControllerName, Class'Class'));
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
	
    agentPrimp = SFXPRIMP(AI.PlayerReplicationInfo);
    agentPrimp.SetCharacterKit(Name(agentKit));
    agentArchetype = SFXPawn_PlayerMP(
        Class'SFXEngine'.static.GetSeekFreeObject(agentPrimp.GetPawnArchetype(), Class'SFXPawn_PlayerMP'));
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
    _kitLookup.Add((sReal="SentinelTurian",sId="tsent"))
    _kitLookup.Add((sReal="SoldierTurian",sId="tsol"))
}