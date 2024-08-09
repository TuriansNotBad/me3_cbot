Class SFXAICmd_Base_CBotTurret extends SFXAICommand_Base_Combat within SFXAI_CBotTurret;

public function bool ShouldAttack()
{
    return TRUE;
}
public function Pushed()
{
    Outer.m_createdPt = Outer.MyBP.location;
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
    if (Outer.FireTarget == None)
    {
        Outer.SelectTarget();
    }

    // and always attack
    if (Outer.FireTarget != None && ShouldAttack())
    {
        Outer.Attack();
    }

    Outer.Sleep(0.100000001);
    goto 'Begin';
    stop;
};

defaultproperties
{
}