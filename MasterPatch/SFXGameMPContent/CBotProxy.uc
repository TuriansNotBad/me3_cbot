Class CBotProxy extends Object;

struct ItemLookup 
{
    var string sReal;
    var string sId;
};

var array<ItemLookup> _kitLookup;
var array<ItemLookup> _wpnLookup;
var bool m_bStaggerFree;
var float m_fXrayVisionDist;
var bool m_bEnforceXrayVisionDist;

// Functions -----------------------------------------------------------

private function string GetItemByLookup(string itemId, out array<ItemLookup> items)
{
    local ItemLookup itemInfo;
    
    if (items.Length == 0)
        return "";

    if (itemId != "")
        foreach items(itemInfo)
            if (InStr(itemInfo.sId, itemId, false, true) == 0)
                return itemInfo.sReal;
    return "";
}

private function string GetKitByLookup(string kitId)
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

private function string GetWeaponByLookup(string wpnId)
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

private function ToggleDebugForAgent(BioPlayerController PC, coerce int idx)
{
    local SFXAI_CBotTurret agent;
    local int i;

    idx--;
    foreach PC.WorldInfo.AllControllers(Class'SFXAI_CBotTurret', agent)
    {
        if (i == idx)
            agent.CBotDebugDrawInit(PC);
        else
            agent.CBotDebugDrawRemove(PC);
        ++i;
    }
}

private function RandomizeCustomization(out SFXPRIMP primp)
{
    primp.CharacterData.Tint1ID = Rand(Class'SFXPlayerCustomizationMP'.default.Tint1Appearances.Length);
    primp.CharacterData.Tint2ID = Rand(Class'SFXPlayerCustomizationMP'.default.Tint2Appearances.Length);
    primp.CharacterData.PatternID = Rand(Class'SFXPlayerCustomizationMP'.default.PatternAppearances.Length);
    primp.CharacterData.PatternColorID = Rand(Class'SFXPlayerCustomizationMP'.default.PatternColorAppearances.Length);
    primp.CharacterData.SkinToneID = Rand(Class'SFXPlayerCustomizationMP'.default.SkinToneAppearances.Length);
    primp.CharacterData.EmissiveID = Rand(Class'SFXPlayerCustomizationMP'.default.EmissiveAppearances.Length);
    primp.CharacterData.PhongID = Rand(Class'SFXPlayerCustomizationMP'.default.PhongAppearances.Length);
}

private function ToggleStaggerImmunity(BioPlayerController PC)
{
    local int itr;
    local SFXAI_CBotTurret agent;

    // 81-85 - normal
    // 87-91 - stagger
    // 92-95 - knockback
    // 96-99 - melee
    // 110-114 - large
    foreach PC.WorldInfo.AllControllers(Class'SFXAI_CBotTurret', agent)
    {
        for (itr = 81; itr <= 85; ++itr)
            agent.MyBP.CustomActionClasses[itr] = None;
        for (itr = 87; itr <= 99; ++itr)
            agent.MyBP.CustomActionClasses[itr] = None;
        for (itr = 110; itr <= 114; ++itr)
            agent.MyBP.CustomActionClasses[itr] = None;
    }
    m_bStaggerFree = true;
}

private function SetXRayVisionDepth(BioPlayerController PC, coerce float d)
{
    local SFXAI_CBotTurret agent;

    foreach PC.WorldInfo.AllControllers(Class'SFXAI_CBotTurret', agent)
        agent.m_maxPenVisionDist = d;
    
    m_bEnforceXrayVisionDist = true;
    m_fXrayVisionDist = d;
}

function SummonAgent(BioPlayerController PC, SFXCheatManagerNonNativeMP cheatMgr, optional string kitId, optional string wpn, optional int logicId)
{
    local SFXPawn PlayerPawn;
    local SFXPawn_PlayerMP AIPawn;
    local Class<AIController> AIControllerClass;
    local SFXAI_Core AI;
    local BioWorldInfo BWI;
    local SFXPRIMP agentPrimp;
    local Actor agentArchetype;
    local string agentKit;
    local string agentWpn;
    local SFXModule_DamagePlayer dmgMod;
    
    if (kitId == "dbg")
    {
        ToggleDebugForAgent(PC, wpn);
        return;
    }
    else if (kitId == "stagger")
    {
        ToggleStaggerImmunity(PC);
        return;
    }
    else if (kitId == "xray")
    {
        SetXRayVisionDepth(PC, wpn);
        return;
    }

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
    
    PlayerPawn = SFXPawn(PC.Pawn);
    if (PlayerPawn == None)
    {
        PC.ClientMessage("CBot: no Player pawn");
        return;
    }
    
    // allow spawning inside of PC for now
    PlayerPawn.bBlockActors = false;
    
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
    agentPrimp.DisplayName = agentKit;
    RandomizeCustomization(agentPrimp);
    agentPrimp.SetCharacterKit(Name(agentKit));
    if (agentWpn != "")
    {
        agentWpn = "SFXGameContent." $ agentWpn;
        agentPrimp.SetWeapon(0, Name(agentWpn), 10);
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
    
    AI.Possess(AIPawn, false);
    AIPawn.SetLocation(PlayerPawn.location);
    AIPawn.SetRotation(PlayerPawn.Rotation);
    AI.SetTeam(0);
    
    PC.bGodMode = true;
    AIPawn.m_bMin1Health = true;
    
    // level up
    AIPawn.AutoLevelUpInfo = AIPawn.PlayerClass.default.AutoLevelUpInfo;
    cheatMgr.MPBotsLevelUp(AIPawn, 20);

    // disable bleed out effects
    dmgMod = AIPawn.GetModule(Class'SFXModule_DamagePlayer');
    dmgMod.BleedoutSFXInterpSpeed = 0.0;
    dmgMod.BleedoutVFXInterpSpeed = 0.0;

    // smooth aiming
    AIPawn.AimOffsetInterpSpeed       = 4.0;
    AIPawn.RemoteAimOffsetInterpSpeed = 4.0;

    if (m_bStaggerFree) ToggleStaggerImmunity(PC);
    if (m_bEnforceXrayVisionDist) SetXRayVisionDepth(PC, m_fXrayVisionDist);
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
