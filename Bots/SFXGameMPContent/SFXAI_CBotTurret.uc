Class SFXAI_CBotTurret extends SFXAI_Cover
    placeable
    config(AI);

var SFXCBot_TagPoint m_createdNP;
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
    // && TimeSinceEnemyVisible(idx) > 0.0
    return CanAttack(testpawn) ? ECBotVis.Normal : ECBotVis.NotVisible;
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

private function bool _IsTargetViableToPick(Pawn testTarget)
{
    return testTarget != None
        && !testTarget.IsInState('Downed')
        && testTarget.IsValidTargetFor(self)
        && GetPawnVisibilityType(testTarget) != ECBotVis.NotVisible;
}

function float GetPawnHealthPct(BioPawn pwn)
{
    return pwn.GetCurrentHealth() / pwn.GetMaxHealth();
}

function bool SelectTargetPlayer()
{
    local Controller PC;
    local Pawn potentialTar;
    local BioPawn curTar;
    local Actor OldTarget;
    local bool bResult;
    local float bestDist;
    local float tempDist;
    
    curTar = BioPawn(m_agentTarget);
    if (IsAgentTargetValid(curTar) && WorldInfo.GameTimeSeconds - TargetAcquisitionTime < 0.5)
        return true;

    OldTarget = m_agentTarget;

    // don't switch from low health enemies
    if (_IsTargetViableToPick(curTar) && curTar != None && GetPawnHealthPct(curTar) < 0.20 && curTar.GetCurrentShields() < 0.1)
        return true;

    // find closest enemy
    bestDist = 100000000.0;
    foreach WorldInfo.AllControllers(Class'Controller', PC)
    {
        if (!_IsTargetViableToPick(PC.Pawn))
            continue;
        
        tempDist = VSize(MyBP.location - PC.Pawn.location);
        if (bestDist > tempDist)
        {
            bestDist = tempDist;
            potentialTar = PC.Pawn;
        }
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
        m_agentTarget = None;

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

private function CBotDebugDraw_EnemyEval(BioPlayerController PC, BioCheatManager cmgr)
{
    local Controller C;
    local Canvas canvas;
    local Color highlight;
    local BioPawn curTar;
    local string str;

    canvas = PC.myHUD.Canvas;
    if (canvas == None)
        return;

    curTar = BioPawn(m_agentTarget);
    highlight.R = 255;
    highlight.A = 255;
    
    str = m_agentTarget @ "V:" @ _IsTargetViableToPick(curTar);
    if (curTar != None)
        str @= "D:" @ VSize(MyBP.location - curTar.location) @ "HP:" @ GetPawnHealthPct(curTar);
    
    cmgr.DrawProfileText(str);
    cmgr.DrawProfileText("-------------------------");
    foreach WorldInfo.AllControllers(Class'Controller', C)
    {
        curTar = BioPawn(C.Pawn);
        if (curTar == None) continue;
        canvas.DrawColor = curTar == Pawn(m_agentTarget) ? highlight : cmgr.ProfileTextColor;
        canvas.DrawText(
            curTar
            @ "V:"
            @ _IsTargetViableToPick(curTar)
            @ "D:"
            @ VSize(MyBP.location - curTar.location)
            @ "HP:"
            @ GetPawnHealthPct(curTar),
        );
        canvas.CurX = cmgr.GetProfileColumnCoord();
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
        cmgr.DrawProfileHeaderText("FireTarget:");
        cmgr.DrawProfileText(FireTarget);
        cmgr.DrawProfileHeaderText("Enemy:");
        cmgr.DrawProfileText(Enemy);
        cmgr.DrawProfileHeaderText("Attack target:");
        cmgr.DrawProfileText(m_agentTarget);
        cmgr.DrawProfileHeaderText("Focus:");
        cmgr.DrawProfileText(Focus);
        cmgr.DrawProfileHeaderText("FocalPoint:");
        cmgr.DrawProfileText(GetFocalPoint());
        cmgr.DrawProfileText("-------------------------");
        cmgr.DrawProfileText("Enemy evaluation:");
        CBotDebugDraw_EnemyEval(PC, cmgr);
    }
}

defaultproperties
{
    DefaultCommand=Class'SFXAICmd_Base_CBotTurret'
    bUseTicketing=false
    m_bAvoidDangerLinks=false
    MoveFireDelayTime=(X=0.001,Y=0.001)
}
