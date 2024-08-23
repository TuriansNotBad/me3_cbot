Class SFXAI_CBotTurret extends SFXAI_Cover
    placeable
    config(AI);

// @todo: builds
// @todo: add staggerfree mode toggle
// @todo: show bot names and blue outline in matches as real players would be shown like
// @todo: UX - currently ghosting player forever when spawning
// @todo: limit wall hack distance or option to disable entirely

// Match consumables

const c_AMC_AmmoArmorPiercing = -814405748;
const c_AMC_AmmoDisruptor     =  227097715;
const c_AMC_AmmoIncendiary    =-1109361556;
const c_AMC_AmmoPhasic        = -366520656;
const c_AMC_AmmoWarp          =  984397380;

const c_AMC_AmpAssaultRifle = -370375887;
const c_AMC_AmpPistol       = 1745725129;
const c_AMC_AmpSMG          =  105473311;
const c_AMC_AmpShotgun      = 1514620052;
const c_AMC_AmpSniperRifle  =  370621455;

const c_AMC_ModAdrenaline =   -1144971;
const c_AMC_ModCyclonic   = 1915545774;
const c_AMC_ModPowerAmp   =  350109524;

// Gear items, level 5 is max

const c_AMG_AmpAssaultRifle =  975595153;
const c_AMG_AmpPistol       =  881305038;
const c_AMG_AmpSMG          = -540458588;
const c_AMG_AmpShotgun      =-2118260984;
const c_AMG_AmpSniperRifle  =  829572041;

// Weapon mods, level 5 is max

const c_WM_AssaultRifleMagSize = 'SFXGameContent.SFXWeaponMod_AssaultRifleMagSize';
const c_WM_AssaultRifleDamage  = 'SFXGameContent.SFXWeaponMod_AssaultRifleDamage';

const c_WM_SniperRifleDmgAndPen = 'SFXGameContentDLC_Shared.SFXWeaponMod_SniperRifleDamageAndPen';
const c_WM_SniperRiflePen       = 'SFXGameContent.SFXWeaponMod_SniperRifleConstraintDamage';
const c_WM_SniperRifleDmg       = 'SFXGameContent.SFXWeaponMod_SniperRifleDamage';
const c_WM_SniperRifleSpareAmmo = 'SFXGameContent.SFXWeaponMod_SniperRifleReloadSpeed';

const c_WM_SMGMag = 'SFXGameContent.SFXWeaponMod_SMGMagSize';
const c_WM_SMGDmg = 'SFXGameContent.SFXWeaponMod_SMGDamage';
const c_WM_SmgPen = 'SFXGameContentDLC_Shared.SFXWeaponMod_SMGPenetration';

const c_WM_ShotgunSpareAmmo = 'SFXGameContent.SFXWeaponMod_ShotgunStability';
const c_WM_ShotgunDmg       = 'SFXGameContent.SFXWeaponMod_ShotgunDamage';
const c_WM_ShotgunAccuracy  = 'SFXGameContent.SFXWeaponMod_ShotgunAccuracy';
const c_WM_ShotgunDmgAndPen = 'SFXGameContentDLC_Shared.SFXWeaponMod_ShotgunDamageAndPen';

const c_WM_PistolSuperDmg = 'SFXGameContentDLC_Shared.SFXWeaponMod_PistolSuperDamage';
const c_WM_PistolMag      = 'SFXGameContent.SFXWeaponMod_PistolMagSize';
const c_WM_PistolPowerDmg = 'SFXGameContentDLC_CON_MP5.SFXWeaponMod_PistolPowerDamage_MP5';

var SFXCBot_TagPoint m_createdNP;
var Actor m_agentTarget;
var EAimNodes m_lastAimNode;
var array<ActiveMatchConsumable> m_AMC;

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
    //HaltWaves(true);
    m_lastAimNode = EAimNodes.AimNode_Cover;
    PlayerReplicationInfo.bBot = false;
    SetupMyWeaponMods();
    SetTimer(0.5, false, 'EnterMatchSetup', self);
}

function SetupMyWeaponMods()
{
    local SFXPRIMP primp;
    local int idx;
    local name wpnClass;

    primp = SFXPRIMP(PlayerReplicationInfo);
    if (primp == None) return;

    for (idx = 0; idx < 2; ++idx)
    {
        if (primp.GetWeapon(idx, wpnClass))
        {
            if (InStr(wpnClass, "AssaultRifle", false, true) > -1)
            {
                primp.SetWeaponMod(idx, 0,  c_WM_AssaultRifleDamage, 5);
                primp.SetWeaponMod(idx, 1, c_WM_AssaultRifleMagSize, 5);
            }
            else if (InStr(wpnClass, "Pistol", false, true) > -1)
            {
                primp.SetWeaponMod(idx, 0, c_WM_PistolSuperDmg, 5);
                primp.SetWeaponMod(idx, 1,      c_WM_PistolMag, 5);
            }
            else if (InStr(wpnClass, "Shotgun", false, true) > -1)
            {
                if (InStr(wpnClass, "SFXWeapon_Shotgun_Quarian", false, true) > -1)
                {
                    primp.SetWeaponMod(idx, 0, c_WM_ShotgunDmgAndPen, 5);
                    primp.SetWeaponMod(idx, 1, c_WM_ShotgunSpareAmmo, 5);
                }
                else
                {
                    primp.SetWeaponMod(idx, 0,     c_WM_ShotgunDmg, 5);
                    primp.SetWeaponMod(idx, 1, c_WM_ShotgunAccuracy, 5);
                }
            }
            else if (InStr(wpnClass, "SMG", false, true) > -1)
            {
                primp.SetWeaponMod(idx, 0, c_WM_SMGDmg, 5);
                primp.SetWeaponMod(idx, 1, c_WM_SMGMag, 5);
            }
            else if (InStr(wpnClass, "SniperRifle", false, true) > -1)
            {
                if (InStr(wpnClass, "Batarian", false, true) > -1 || InStr(wpnClass, "Turian", false, true) > -1)
                {
                    primp.SetWeaponMod(idx, 0,       c_WM_SniperRifleDmg, 5);
                    primp.SetWeaponMod(idx, 1, c_WM_SniperRifleSpareAmmo, 5);
                }
                else
                {
                    primp.SetWeaponMod(idx, 0, c_WM_SniperRifleDmgAndPen, 5);
                    primp.SetWeaponMod(idx, 1,       c_WM_SniperRiflePen, 5);
                }
            }
        }
    }
}

function EnterMatchSetup()
{
    local SFXWeapon Wpn;
    
    Wpn = SFXWeapon(MyBP.Weapon);
    if (Wpn == None || !Wpn.bIsInitialized)
    {
        SetTimer(0.5, false, 'EnterMatchSetup', self);
        return;
    }
    SetupActiveMatchConsumables();
    ApplyActiveMatchConsumables();
}

function ApplyActiveMatchConsumables()
{
    local SFXModule_GameEffectManager GEManager;
    local Class<SFXGameEffect> effectClass;
    local int idx;
    local SFXGameEffect GEMatchConsumable;
    local SFXPRIMP primp;
    local ActiveMatchConsumable amc;
    local EDurationType EDurationType;
    
    primp = SFXPRIMP(PlayerReplicationInfo);
    if (MyBP == None || primp == None) return;
    
    GEManager = MyBP.GetModule(Class'SFXModule_GameEffectManager');
    if (GEManager == None) return;

    GEManager.RemoveEffectsByCategory(primp.MatchConsumableGECategory);
    for (idx = 0; idx < primp.NumConsumablesAllowedPerMatch; idx++)
    {
        amc = m_AMC[idx];
        if (amc.ClassNameID == 0) continue;
        
        effectClass = Class'SFXGameEffect'.static.LoadGameEffectClass(Class'SFXEngine'.static.GetStrFromSFXUniqueID(amc.ClassNameID));
        if (effectClass == None) continue;

        GEMatchConsumable = GEManager.CreateAndApplyEffect(effectClass, primp.MatchConsumableGECategory, 0.0, EDurationType.DurationType_Permanent, amc.Value, self);
        if (GEMatchConsumable == None)
            Print("Failed to create match consumable for" @ self @ ":" @ amc.ClassNameID);
    }
}

private function SetupActiveMatchConsumables()
{
    local SFXWeapon wpn;

    wpn = SFXWeapon(MyBP.Weapon);
    if (wpn == None) return;

    // weapon amps + gear
    if (wpn.IsA('SFXWeapon_AssaultRifle_Base'))
    {
        AddActiveMatchConsumable(c_AMC_AmpAssaultRifle, 2);
        AddActiveMatchConsumable(c_AMG_AmpAssaultRifle, 5);
    }
    else if (wpn.IsA('SFXWeapon_Pistol_Base'))
    {
        AddActiveMatchConsumable(c_AMC_AmpPistol, 2);
        AddActiveMatchConsumable(c_AMG_AmpPistol, 5);
    }
    else if (wpn.IsA('SFXWeapon_Shotgun_Base'))
    {
        AddActiveMatchConsumable(c_AMC_AmpShotgun, 2);
        AddActiveMatchConsumable(c_AMG_AmpShotgun, 5);
    }
    else if (wpn.IsA('SFXWeapon_SMG_Base'))
    {
        AddActiveMatchConsumable(c_AMC_AmpSMG, 2);
        AddActiveMatchConsumable(c_AMG_AmpSMG, 5);
    }
    else if (wpn.IsA('SFXWeapon_SniperRifle_Base'))
    {
        AddActiveMatchConsumable(c_AMC_AmpSniperRifle, 2);
        AddActiveMatchConsumable(c_AMG_AmpSniperRifle, 5);
    }

    // pick ammo
    if (wpn.WeaponProjectiles.Length == 0)
    {
        if (wpn.IsA('SFXWeapon_SniperRifle_Widow') || wpn.IsA('SFXWeapon_SniperRifle_Javelin'))
            AddActiveMatchConsumable(c_AMC_AmmoPhasic, 2);
        else if (wpn.IsA('SFXWeapon_Shotgun_Quarian') || wpn.IsA('SFXWeapon_SniperRifle_Collector'))
            AddActiveMatchConsumable(c_AMC_AmmoIncendiary, 3);
        else if (wpn.IsA('SFXWeapon_SniperRifle_Base'))
            AddActiveMatchConsumable(c_AMC_AmmoWarp, 3);
        else
            AddActiveMatchConsumable(c_AMC_AmmoArmorPiercing, 3);
    }
    else
        AddActiveMatchConsumable(c_AMC_AmmoDisruptor, 3);
    
    // armor
    AddActiveMatchConsumable(c_AMC_ModCyclonic, 3);
}

function AddActiveMatchConsumable(int consumeClassNameId, int consumeLevel)
{
    local ActiveMatchConsumable amc;

    amc.ClassNameID = consumeClassNameId;
    amc.Value       = consumeLevel;
    m_amc.AddItem(amc);
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

function Print(coerce string msg)
{
    local BioPlayerController PC;
    
    foreach WorldInfo.AllControllers(Class'BioPlayerController', PC)
    {
        PC.ClientMessage(msg);
        break;
    }
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
