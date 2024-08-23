Class SFXAICmd_Base_CBotTurret extends SFXAICommand_Base_Combat within SFXAI_CBotTurret;

function bool ShouldAttack()
{
    return true;
}

function Pushed()
{
    Outer.MyBP.SightRadius = 9000.0;
    if (Outer.m_createdNP == None)
        Outer.m_createdNP = Outer.Spawn(Class'SFXCBot_TagPoint', , , Outer.MyBP.location, , , true);
}

auto state Combat 
{
    
Begin:
    Outer.FindDrivablePawn();

    // custom actions can set this and never remove
    if (Outer.MyBP.bLockDesiredRotation)
        Outer.MyBP.LockDesiredRotation(false);

    // stay in my spawn
    if (Outer.m_createdNP != None && VSize(Outer.MyBP.location - Outer.m_createdNP.location) > 50.0)
    {
        Class'SFXAICmd_MoveToGoal'.static.MoveToGoal(Outer, Outer.m_createdNP, 0.0, true, true);
    }
    else if (VSize(Outer.MyBP.Acceleration) > 0.0)
    {
        // custom actions issue
        Outer.MyBP.SetDesiredSpeed(0.0);
        Outer.MyBP.StopMovement(false);
    }

    // find target
    Outer.SelectTargetPlayer();
    Outer.UpdateFocus();

    // and always attack
    if (Outer.m_agentTarget != None && ShouldAttack())
    {
        Outer.StartFiring();
    }
    else
    {
        Outer.StopFiring();
        if (Outer.ShouldReload())
            Outer.RELOAD();;
    }

    Outer.Sleep(0.1);
    goto 'Begin';
    stop;
};

defaultproperties
{
}
