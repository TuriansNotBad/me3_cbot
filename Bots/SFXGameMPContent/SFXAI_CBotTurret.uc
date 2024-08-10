Class SFXAI_CBotTurret extends SFXAI_Cover
    placeable
    config(AI);

var Vector m_createdPt;
var Actor m_agentTarget;

enum ECBotVis
{
    Normal,
    Unaware,
    NotVisible
};

function Initialize()
{
    Super(SFXAI_Core).Initialize();
    HaltWaves(true);
}

function Print(coerce string msg)
{
    local BioPlayerController PC;
    
    foreach WorldInfo.AllControllers(Class'BioPlayerController', PC)
    {
        PC.ClientMessage(msg);
        break;
    }
}

function ECBotVis GetPawnVisibilityType(Pawn testpawn)
{
    local int idx;

    idx = GetEnemyIndex(testpawn);
    if (idx < 0)
        return CanAttack(testpawn) ? ECBotVis.Unaware : ECBotVis.NotVisible;
    return TimeSinceEnemyVisible(idx) > 0.0 ? ECBotVis.NotVisible : ECBotVis.Normal;
}

function HaltWaves(bool pause)
{
    local SFXGRIMP gri;
    local SFXWaveCoordinator_HordeOperation horde;

    gri = SFXGRIMP(WorldInfo.GRI);
    if (gri == None) return;
    horde = SFXWaveCoordinator_HordeOperation(gri.WaveCoordinator);
    if (horde == None) return;
    if (pause)
    {
        horde.BetweenWaveDelay = 100000000.0;
        horde.GoToWave(0);
    }
    else
    {
        horde.BetweenWaveDelay = 10.0;
        horde.GoToWave(0);
    }
}

function bool IsAgentTargetValid(Actor testTarget)
{
    return testTarget != None ? HasValidTarget(testTarget) : false;
}

function bool IsAgentEnemyValid(Pawn testTarget)
{
    return testTarget != None ? HasValidEnemy(testTarget) : false;
}

protected function _SetEngineTargetVals()
{
    Enemy = Pawn(m_agentTarget);
    FireTarget = m_agentTarget;
    ShotTarget = Pawn(m_agentTarget);
}

function bool SelectTargetPlayer()
{
    local BioPlayerController PC;
    local Pawn potentialTar;
    local Actor OldTarget;
    local bool bResult;
    
    if (IsAgentTargetValid(m_agentTarget) && WorldInfo.GameTimeSeconds - TargetAcquisitionTime < 0.5)
        return true;

    OldTarget = m_agentTarget;

    foreach WorldInfo.AllControllers(Class'BioPlayerController', PC)
    {
        if (PC.Pawn.IsInState('Downed') || !PC.Pawn.IsValidTargetFor(self) || GetPawnVisibilityType(PC.Pawn) == ECBotVis.NotVisible)
            continue;
        potentialTar = PC.Pawn;
        break;
    }

    bResult = IsAgentEnemyValid(potentialTar);
    if (bResult)
    {
        m_agentTarget = potentialTar;
        _SetEngineTargetVals();
        ValidateFireTargetLocation();
        if (OldTarget != m_agentTarget)
        {
            TargetAcquisitionTime = WorldInfo.GameTimeSeconds;
            OnTargetChanged();
            TriggerAttackVocalization();
        }
    }
    else
    {
        m_agentTarget = None;
        TargetAcquisitionTime = 0.0;
    }

    return bResult;
}

function bool UpdateFocus()
{
    local int idx;

    if (m_agentTarget == None)
    {
        Focus = None;
        return false;
    }
    
    // Handle non pawn target
    if (Pawn(m_agentTarget) == None)
    {
        if (CanAttack(m_agentTarget))
        {
            Focus = m_agentTarget;
            return true;
        }
        Focus = None;
        return false;
    }

    if (GetPawnVisibilityType(Pawn(m_agentTarget)) == ECBotVis.NotVisible)
    {
        Focus = None;
        return false;
    }

    Focus = m_agentTarget;
    return true;
}

function bool CanFireWeapon(Weapon Wpn, byte FireModeNum)
{
    return CanFireWeaponNoLOS(Wpn, FireModeNum);
}

function bool ChooseAttack(Actor oTarget, out Name nmPowerName)
{
    local SFXWeapon oWeapon;
    local ECoverAction AttackerCoverAction;
    local ECoverAction TargetCoverAction;
    
    if (MyBP == None || oTarget == None)
        return FALSE;

    if (IsTargetInFiringArc(MyBP, oTarget, m_fFiringArcAngle) == FALSE)
        return FALSE;

    if (Vehicle(oTarget) != None)
        if (VSize(oTarget.location - MyBP.location) > MyBP.SightRadius)
            return FALSE;

    oWeapon = SFXWeapon(MyBP.Weapon);
    if (oWeapon == None)
        return FALSE;

    if (CanShootWeapon(oTarget) == FALSE)
        return FALSE;
        
    if (ShouldReload() && RELOAD())
    {
        m_AttackResult = AttackResult.ATTACK_FAIL_RELOADING;
        return FALSE;
    }

    if (MyBP.IsInCover())
    {
        if (GetBestCoverAction(Cover, FireTarget, AttackerCoverAction, TargetCoverAction) == FALSE)
        {
            m_AttackResult = AttackResult.ATTACK_FAIL_NO_LOS;
            return FALSE;
        }
        PendingCoverAction = AttackerCoverAction;
        BestTargetCoverAction = TargetCoverAction;
    }
    
    if (m_bCheckLOS && CanAttack(oTarget) == FALSE)
    {
        m_AttackResult = AttackResult.ATTACK_FAIL_NO_LOS;
        if (nmPowerName != 'None')
            ClearPowerReservation(nmPowerName);

        return FALSE;
    }
    return TRUE;
}

function CBotDebugDrawInit()
{
    local BioPlayerController PC;
    local BioCheatManager cmgr;

    foreach WorldInfo.AllControllers(Class'BioPlayerController', PC)
    {
        cmgr = BioCheatManager(PC.CheatManager);
        if (cmgr == None)
            continue;
        BioHUD(PC.myHUD).AddDebugDraw(CBotDebugDraw);
    }
}

function CBotDebugDrawRemove()
{
    local BioPlayerController PC;
    local BioCheatManager cmgr;

    foreach WorldInfo.AllControllers(Class'BioPlayerController', PC)
    {
        cmgr = BioCheatManager(PC.CheatManager);
        if (cmgr == None)
            continue;
        BioHUD(PC.myHUD).ClearDebugDraw(CBotDebugDraw);
    }
}

function CBotDebugDraw(BioHUD HUD)
{
    local BioPlayerController PC;
    local BioCheatManager cmgr;
    
    foreach WorldInfo.AllControllers(Class'BioPlayerController', PC)
    {
        cmgr = BioCheatManager(PC.CheatManager);
        if (cmgr == None)
            continue;
        PC.myHUD.Canvas.SetPos(PC.myHUD.Canvas.CurX, 90.0);
        cmgr.DrawProfileText("Debug for" @ self);
        cmgr.DrawProfileText("-------------------------");
        cmgr.DrawProfileHeaderText("Attack target:");
        cmgr.DrawProfileText(m_agentTarget);
        cmgr.DrawProfileHeaderText("Focus:");
        cmgr.DrawProfileText(Focus);
        cmgr.DrawProfileHeaderText("FocalPoint:");
        cmgr.DrawProfileText(GetFocalPoint());
    }

}

defaultproperties
{
    DefaultCommand = Class'SFXAICmd_Base_CBotTurret'
}
