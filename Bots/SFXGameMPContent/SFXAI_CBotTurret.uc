Class SFXAI_CBotTurret extends SFXAI_Cover
    placeable
    config(AI);

// @todo: builds
// @todo: add weapon mods
// @todo: implement system for applying relevant active match consumables and gear item
// @todo: aim node does not update if agent has armor piercing and current node is still valid
// @todo: add staggerfree mode toggle
// @todo: show bot names and blue outline in matches as real players would be shown like
// @todo: random or inputted names and colors
// @todo: UX - currently ghosting player forever when spawning

const c_AMCAP4   = -814405748;
const c_AMCCM4   = 1915545774;
const c_AMCARRA3 = -370375887;

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
    local SFXPRIMP PRIMP;
    local BioPlayerController PC;
    local int idx;
    
    foreach WorldInfo.AllControllers(Class'BioPlayerController', PC)
    {
        PRIMP = SFXPRIMP(PC.PlayerReplicationInfo);
        for (idx = 0; idx < 4; ++idx)
            Print(PRIMP.ActiveMatchConsumables[idx].ClassNameID @ PRIMP.ActiveMatchConsumables[idx].Value);
        break;
    }
    Super(SFXAI_Core).Initialize();
    //HaltWaves(true);
    m_lastAimNode = EAimNodes.AimNode_Cover;
    AddActiveMatchConsumable(c_AMCAP4,   3);
    AddActiveMatchConsumable(c_AMCARRA3, 2);
    AddActiveMatchConsumable(c_AMCCM4,   3);
    PlayerReplicationInfo.bBot = false;
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

function AddActiveMatchConsumable(int consumeClassNameId, int consumeLevel)
{
    local SFXPRIMP primp;

    primp = SFXPRIMP(PlayerReplicationInfo);
    if (primp != None)
        primp.AddActiveMatchConsumable(consumeClassNameId, consumeLevel);
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

function float GetPawnHealthPct(BioPawn pwn)
{
    return pwn.GetCurrentHealth() / pwn.GetMaxHealth();
}

// -------------------------------------------------------------------------
//                               AIMING
// -------------------------------------------------------------------------

function bool IsAnyAimNodeVisible(BioPawn testpawn)
{
    if (testpawn == None) return false;
    return IsAimNodeVisible(testpawn, EAimNodes.AimNode_Chest)
        || IsAimNodeVisible(testpawn, EAimNodes.AimNode_Head);
        //|| IsAimNodeVisible(testpawn, EAimNodes.AimNode_LeftKnee)
        //|| IsAimNodeVisible(testpawn, EAimNodes.AimNode_RightKnee);
}

private function bool IsAimLocationVisible(BioPawn testpawn, const out Vector vAimLocation)
{
    local SFXWeapon wpnAgent;
    local Vector vAttackOrigin;
    local array<ImpactInfo> impactList;
    local ImpactInfo wpnImpact;
    local ImpactInfo impactItr;

    if (vAimLocation.x == 0.0)
        return false;
    
    wpnAgent = SFXWeapon(MyBP.Weapon);
    if (wpnAgent != None)
    {
        vAttackOrigin = wpnAgent.GetPhysicalFireStartLoc();
        wpnImpact = wpnAgent.CalcWeaponFire(
            vAttackOrigin,
            vAttackOrigin + Vector(Rotator(vAimLocation - vAttackOrigin)) * MyBP.SightRadius,
            impactList
        );
        foreach impactList(impactItr)
            if (testpawn == impactItr.HitActor)
                return true;
    }
    else
    {
        vAttackOrigin = MyBP.GetWeaponStartTraceLocation();
        return CanAISeeByPoints(vAttackOrigin, vAimLocation, Rotator(vAimLocation - vAttackOrigin), false);
    }
    return false;
}

function bool IsAimNodeVisible(BioPawn testpawn, EAimNodes node, optional out Vector vNodeLocation)
{
    local Vector vAimLocation;
    local Vector vAttackOrigin;
    local SFXWeapon wpnAgent;
    local array<ImpactInfo> impactList;
    local ImpactInfo wpnImpact;
    local ImpactInfo impactItr;

    if (testpawn == None)
        return false;
    
    if (!testpawn.GetAimNodeLocation(node, vAimLocation))
        return false;
    
    if (node == EAimNodes.AimNode_Chest && testpawn.IsA('SFXPawn_GethBomber'))
        vAimLocation.Z += 3.0;
    
    if (IsAimLocationVisible(testpawn, vAimLocation))
    {
        vNodeLocation = vAimLocation;
        return true;
    }
    return false;
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

private function bool GetDefaultAimLocation(BioPawn target, out Vector vAimLocation, EAimNodes pref, EAimNodes alt)
{
    if (!GetAimLocIsAimNodeVisWrapper(target, pref,                       vAimLocation, m_lastAimNode))
    if (!GetAimLocIsAimNodeVisWrapper(target, alt,                        vAimLocation, m_lastAimNode))
    //if (!GetAimLocIsAimNodeVisWrapper(target, EAimNodes.AimNode_LeftKnee, vAimLocation, m_lastAimNode))
    //if (!GetAimLocIsAimNodeVisWrapper(target, EAimNodes.AimNode_RightKnee,vAimLocation, m_lastAimNode))
    {
        m_lastAimNode = EAimNodes.AimNode_Cover;
        vAimLocation  = Super(SFXAI_Cover).GetAimLocation(target);
    }
    return true;
}

private function bool GetCollectorAimLocation(BioPawn target, out Vector vAimLocation)
{
    if (target.IsA('SFXPawn_Praetorian'))
    {
        vAimLocation = target.GetPrimarySkelMeshComponent().GetBoneLocation('Root');
        vAimLocation.Z -= 30.0;
        if (IsAimLocationVisible(target, vAimLocation))
        {
            m_lastAimNode = EAimNodes.AimNode_Head;
            return true;
        }
        else if (target.GetAimNodeLocation(EAimNodes.AimNode_Head, vAimLocation))
        {
            m_lastAimNode = EAimNodes.AimNode_Chest;
            return true;
        }
    }

    return GetDefaultAimLocation(target, vAimLocation, EAimNodes.AimNode_Head, EAimNodes.AimNode_Chest);
}

private function bool GetBoneAimLocationOrDefault(BioPawn target, out Vector vAimLocation, Name bone)
{
    local Vector tempAim;

    tempAim = target.GetPrimarySkelMeshComponent().GetBoneLocation(bone);
    if (IsAimLocationVisible(target, tempAim))
    {
        vAimLocation = tempAim;
        return true;
    }
    return GetDefaultAimLocation(target, vAimLocation, EAimNodes.AimNode_Chest, EAimNodes.AimNode_Head);
}

function Vector GetAimLocation(optional Actor oAimTarget)
{
    local Vector vAimLocation;
    local BioPawn oAimPawn;

    if (oAimTarget == None)
        oAimTarget = m_agentTarget;
    
    oAimPawn = BioPawn(oAimTarget);
    
    if (oAimPawn != None)
    {
        if (oAimPawn.IsA('SFXPawn_Collector_Base'))
        {
            if (GetCollectorAimLocation(oAimPawn, vAimLocation))
                return vAimLocation;
        }
        else if (oAimPawn.IsA('SFXPawn_Brute') || oAimPawn.IsA('SFXPawn_Banshee'))
        {
            m_lastAimNode = EAimNodes.AimNode_Head;
            if (GetBoneAimLocationOrDefault(oAimPawn, vAimLocation, 'Head'))
                return vAimLocation;
        }
        else if (oAimPawn.IsA('SFXPawn_GethBomber'))
        {
            m_lastAimNode = EAimNodes.AimNode_Chest;
            if (GetBoneAimLocationOrDefault(oAimPawn, vAimLocation, 'Head'))
            {
                vAimLocation.Z += 3.3;
                return vAimLocation;
            }
        }
    }

    GetDefaultAimLocation(oAimPawn, vAimLocation, EAimNodes.AimNode_Head, EAimNodes.AimNode_Chest);
    return vAimLocation;
}

// -------------------------------------------------------------------------
//                           Target Selection
// -------------------------------------------------------------------------

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
    {
        m_agentTarget = None;
        _SetEngineTargetVals();
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

// -------------------------------------------------------------------------
//           Function overrides to avoid some std behaviours
// -------------------------------------------------------------------------

function NotifyStuck();

function bool CanFireWeapon(Weapon Wpn, byte FireModeNum)
{
    return CanFireWeaponNoLOS(Wpn, FireModeNum);
}

// -------------------------------------------------------------------------
//                                DEBUG
// -------------------------------------------------------------------------

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

function CBotDebugDrawInit(BioPlayerController PC)
{
    BioHUD(PC.myHUD).AddDebugDraw(CBotDebugDraw);
}

function CBotDebugDrawRemove(BioPlayerController PC)
{
    BioHUD(PC.myHUD).ClearDebugDraw(CBotDebugDraw);
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
    local BioPawn bpAimTarget;
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
        CBotDebugDraw_EnemyEval(PC, cmgr);
        // -----------------------------------------------
        bpAimTarget = BioPawn(m_agentTarget);
        if (bpAimTarget == None) bpAimTarget = BioPawn(PC.Pawn);
        CBotDebugDraw_LineToAimWrapper(cmgr, bpAimTarget, vLineStart, EAimNodes.AimNode_Chest,    vis, nvis, fPenDist);
        CBotDebugDraw_LineToAimWrapper(cmgr, bpAimTarget, vLineStart, EAimNodes.AimNode_Head,     vis, nvis);
        CBotDebugDraw_LineToAimWrapper(cmgr, bpAimTarget, vLineStart, EAimNodes.AimNode_LeftKnee, vis, nvis);
        CBotDebugDraw_LineToAimWrapper(cmgr, bpAimTarget, vLineStart, EAimNodes.AimNode_RightKnee,vis, nvis);

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
    m_fReloadThreshold=1.0
    MoveFireDelayTime=(X=0.001,Y=0.001)
}
