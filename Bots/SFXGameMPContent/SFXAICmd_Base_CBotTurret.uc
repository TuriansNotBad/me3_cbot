Class SFXAICmd_Base_CBotTurret extends SFXAICommand_Base_Combat within SFXAI_CBotTurret;

function bool ShouldAttack()
{
    return TRUE;
}

function Pushed()
{
    Outer.m_createdPt = Outer.MyBP.location;
    Outer.MyBP.SightRadius = 9000.0;
}



auto state Combat extends InCombat 
{
    
Begin:
    Outer.FindDrivablePawn();

     // stay in my spawn
    if (VSize(Outer.MyBP.location - Outer.m_createdPt) > 50.0)
    {
        Class'SFXAICmd_MoveToLocation'.static.MoveToLocation(Outer, Outer.m_createdPt, 0.0, true, true);
    }

    // find target
    Outer.SelectTargetPlayer();
    Outer.UpdateFocus();
    // and always attack
    if (Outer.m_agentTarget != None && ShouldAttack())
        Outer.StartFiring();
    else
        Outer.StopFiring();

    Outer.Sleep(0.1);
    goto 'Begin';
    stop;
};

defaultproperties
{
}
