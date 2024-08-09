Class SFXAI_CBotTurret extends SFXAI_Cover
    placeable
    config(AI);

var Vector m_createdPt;

public function Initialize()
{
    Super(SFXAI_Core).Initialize();
}

public function bool ChooseAttack(Actor oTarget, out Name nmPowerName)
{
    local SFXWeapon oWeapon;
    local ECoverAction AttackerCoverAction;
    local ECoverAction TargetCoverAction;
    
    if (MyBP == None || oTarget == None)
    {
        return FALSE;
    }
    if (IsTargetInFiringArc(MyBP, oTarget, m_fFiringArcAngle) == FALSE)
    {
        return FALSE;
    }
    if (Vehicle(oTarget) != None)
    {
        if (VSize(oTarget.location - MyBP.location) > MyBP.SightRadius)
        {
            return FALSE;
        }
    }

    oWeapon = SFXWeapon(MyBP.Weapon);
    if (oWeapon == None)
    {
        return FALSE;
    }
    if (CanShootWeapon(oTarget) == FALSE)
    {
        return FALSE;
    }
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
        {
            ClearPowerReservation(nmPowerName);
        }
        return FALSE;
    }
    return TRUE;
}

defaultproperties
{
    DefaultCommand = Class'SFXAICmd_Base_CBotTurret'
}
