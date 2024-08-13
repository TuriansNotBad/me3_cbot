Class SFXAI_CBotTurret extends SFXAI_Cover
    placeable
    config(AI);

var SFXCBot_TagPoint m_createdNP;
var Actor m_agentTarget;
var EAimNodes m_lastAimNode;

enum ECBotVis
{
    Normal,
    Unaware,
    NotVisible
};

enum EAimNodes
{
    AimNode_Cover,
    AimNode_Head,
    AimNode_LeftShoulder,
    AimNode_RightShoulder,
    AimNode_Chest,
    AimNode_Groin,
    AimNode_LeftKnee,
    AimNode_RightKnee,
};

function Initialize()
{
    Super(SFXAI_Core).Initialize();
    HaltWaves(true);
    m_lastAimNode = EAimNodes.AimNode_Cover;
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

function float GetWpnPenetrationDistance(optional Pawn testpawn)
{
    local SFXWeapon wpn;

    if (testpawn == None) testpawn = MyBP;
    wpn = SFXWeapon(testpawn.Weapon);
    if (wpn == None) return 0.0;
    return wpn.DistancePenetrated + (wpn.PenetrationBonus.Value - 1.0) * 100.0;
}

function ECBotVis GetPawnVisibilityType(Pawn testpawn)
{
    local int idx;

    idx = GetEnemyIndex(testpawn);
    if (idx < 0)
        return IsAnyAimNodeVisible(BioPawn(testpawn)) ? ECBotVis.Unaware : ECBotVis.NotVisible;
    return IsAnyAimNodeVisible(BioPawn(testpawn)) ? ECBotVis.Normal : ECBotVis.NotVisible;
}

function bool IsAnyAimNodeVisible(BioPawn testpawn)
{
    local int i;

    if (testpawn == None)
        return false;

    return IsAimNodeVisible(testpawn, EAimNodes.AimNode_Chest)
        || IsAimNodeVisible(testpawn, EAimNodes.AimNode_Head)
        || IsAimNodeVisible(testpawn, EAimNodes.AimNode_LeftKnee)
        || IsAimNodeVisible(testpawn, EAimNodes.AimNode_RightKnee);
}

function bool IsAimNodeVisible(BioPawn testpawn, EAimNodes node, optional out Vector vNodeLocation)
{
    local Vector vAimLocation;
    local Vector vAttackOrigin;
    local SFXWeapon wpnAgent;
    local array<ImpactInfo> impactList;
    local ImpactInfo wpnImpact;
    local ImpactInfo impactItr;
    local bool result;

    if (testpawn == None)
        return false;
    
    if (!testpawn.GetAimNodeLocation(node, vAimLocation))
        return false;
    
    if (vAimLocation.x == 0.0)
        return false;

    result        = false;
    
    wpnAgent = SFXWeapon(MyBP.Weapon);
    if (wpnAgent != None)
    {
        vAttackOrigin = wpnAgent.GetPhysicalFireStartLoc();
        // todo: limit length to distance to aim location + penetration depth + padding?
        wpnImpact = wpnAgent.CalcWeaponFire(
            vAttackOrigin,
            vAttackOrigin + Vector(Rotator(vAimLocation - vAttackOrigin)) * Pawn.SightRadius,
            impactList
        );
        foreach impactList(impactItr)
        {
            if (testpawn == impactItr.HitActor)
            {
                result = true;
                break;
            }
        }
    }
    else
    {
        vAttackOrigin = MyBP.GetWeaponStartTraceLocation();
        result = CanAISeeByPoints(vAttackOrigin, vAimLocation, Rotator(vAimLocation - vAttackOrigin), false);
    }
    
    if (result)
        vNodeLocation = vAimLocation;
    return result;
}

private function bool GetAimLocIsAimNodeVisWrapper(BioPawn testpawn, EAimNodes node, out Vector vNodePos, out EAimNodes outNode)
{
    if (IsAimNodeVisible(testpawn, node, vNodePos))
    {
        outNode = node;
        return true;
    }
    return false;
}

// @todo: aim does not update if agent has armor piercing
function Vector GetAimLocation(optional Actor oAimTarget)
{
    local Vector vAimLocation;
    local EAimNodes ePreferNode;
    local EAimNodes eAltPreferNode;

    if (oAimTarget == None)
        oAimTarget = m_agentTarget;
    
    if (oAimTarget != None)
    {
        ePreferNode    = EAimNodes.AimNode_Head;
        eAltPreferNode = EAimNodes.AimNode_Chest;
        // @todo: maybe sfxweapon has a better way to determine dist to stop aiming for the head at
        if (VSize(oAimTarget.location - MyBP.location) > 1000.0)
        {
            ePreferNode    = EAimNodes.AimNode_Chest;
            eAltPreferNode = EAimNodes.AimNode_Head;
        }
    }

    // if head, chest, lknee, and rknee are not visible use default
    if (!GetAimLocIsAimNodeVisWrapper(BioPawn(oAimTarget), ePreferNode,                vAimLocation, m_lastAimNode))
    if (!GetAimLocIsAimNodeVisWrapper(BioPawn(oAimTarget), eAltPreferNode,             vAimLocation, m_lastAimNode))
    if (!GetAimLocIsAimNodeVisWrapper(BioPawn(oAimTarget), EAimNodes.AimNode_LeftKnee, vAimLocation, m_lastAimNode))
    if (!GetAimLocIsAimNodeVisWrapper(BioPawn(oAimTarget), EAimNodes.AimNode_RightKnee,vAimLocation, m_lastAimNode))
    {
        m_lastAimNode = EAimNodes.AimNode_Cover;
        vAimLocation  = Super(SFXAI_Cover).GetAimLocation(oAimTarget);
    }
    
    return vAimLocation;
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
        tempDist = VSize(MyBP.location - PC.Pawn.location);
        if (bestDist > tempDist)
        {
            if (!_IsTargetViableToPick(PC.Pawn))
                continue;
        
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

private function CBotDebugDrawLineToAimNode(BioPawn testpawn, Vector vStart, EAimNodes node, Color vis, Color nvis)
{
    local Vector vEnd;
    local Color cCol;

    if (testpawn == None || !testpawn.GetAimNodeLocation(node, vEnd))
        return;
    
    cCol = nvis;
    if (IsAimNodeVisible(testpawn, node))
        cCol = vis;
    if (node == m_lastAimNode)
    {
        cCol.r = 0; cCol.g = 0; cCol.b = 255;
    }
    DrawDebugLine(vStart, vEnd, cCol.r, cCol.g, cCol.b);
    DrawDebugSphere(vEnd, 25, 6, cCol.r, cCol.g, cCol.b);
}

function CBotDebugDraw_LineToAimWrapper(BioCheatManager cmgr, BioPawn testpawn, Vector vStart, EAimNodes node, Color vis, Color nvis, optional out float inFPenDist)
{
    local Vector vAttackOrigin;
    local Vector vTraceEnd;
    local Vector vEnd;
    local ImpactInfo wpnImpact;
    local ImpactInfo impactItr;
    local array<ImpactInfo> impactList;
    local SFXWeapon wpnAgent;
    local Color cCol;
    local bool bActorHit;
    local float fPenDist;
    
    wpnAgent = SFXWeapon(MyBP.Weapon);
    if (testpawn == None || !testpawn.GetAimNodeLocation(node, vEnd) || wpnAgent == None)
        return;

    vAttackOrigin = wpnAgent.GetPhysicalFireStartLoc();
    vTraceEnd = vAttackOrigin + Vector(Rotator(vEnd - vAttackOrigin)) * MyBP.SightRadius;
    fPenDist = wpnAgent.DistancePenetrated;
    wpnAgent.DistancePenetrated = 1000000.0;
    wpnImpact = wpnAgent.CalcWeaponFire(vAttackOrigin, vTraceEnd, impactList);
    wpnAgent.DistancePenetrated = fPenDist;
    cCol = nvis;
    foreach impactList(impactItr)
    {
        if (testpawn == impactItr.HitActor)
        {
            DrawDebugSphere(impactItr.HitLocation, 25, 6, 0, 0, 255);
            fPenDist = impactItr.PenetrationDepth;
            if (fPenDist <= GetWpnPenetrationDistance())
                cCol = vis;
            bActorHit = true;
        }
        else
            DrawDebugSphere(impactItr.HitLocation, 25, 6, 255, 255, 255);
    }
    
    if (node == m_lastAimNode)
    {
        cCol.r = 0; cCol.g = 255; cCol.b = 0;
    }
    inFPenDist = bActorHit ? fPenDist : -1.0;
    DrawDebugLine(vStart, vTraceEnd, cCol.r, cCol.g, cCol.b);
    //DrawDebugSphere(vEnd, 25, 6, cCol.r, cCol.g, cCol.b);
}

function CBotDebugDraw(BioHUD HUD)
{
    local BioPlayerController PC;
    local BioCheatManager cmgr;
    local Vector vLineStart;
    local Vector vLineStop;
    local Color vis;
    local Color nvis;
    local BioPawn bp;
    local float fPenDist;

    vLineStart = SFXWeapon(MyBP.Weapon) != None ? SFXWeapon(MyBP.Weapon).GetPhysicalFireStartLoc() : MyBP.GetWeaponStartTraceLocation();
    vis.G  = 255; vis.B = 255; vis.R = 255;
    nvis.R = 255;
    
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
        //CBotDebugDraw_EnemyEval(PC, cmgr);
        // -----------------------------------------------
        CBotDebugDraw_LineToAimWrapper(cmgr, BioPawn(PC.Pawn), vLineStart, EAimNodes.AimNode_Chest,    vis, nvis, fPenDist);
        CBotDebugDraw_LineToAimWrapper(cmgr, BioPawn(PC.Pawn), vLineStart, EAimNodes.AimNode_Head,     vis, nvis);
        CBotDebugDraw_LineToAimWrapper(cmgr, BioPawn(PC.Pawn), vLineStart, EAimNodes.AimNode_LeftKnee, vis, nvis);
        CBotDebugDraw_LineToAimWrapper(cmgr, BioPawn(PC.Pawn), vLineStart, EAimNodes.AimNode_RightKnee,vis, nvis);

        cmgr.DrawProfileText("-------------------------");
        cmgr.DrawProfileText("Penetration:");
        cmgr.DrawProfileText("Required:" @ fPenDist @ "Available:" @ GetWpnPenetrationDistance());
    }
}

defaultproperties
{
    DefaultCommand=Class'SFXAICmd_Base_CBotTurret'
    bUseTicketing=false
    m_bAvoidDangerLinks=false
    MoveFireDelayTime=(X=0.001,Y=0.001)
}
