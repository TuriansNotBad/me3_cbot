Class Patch_SFXCheatManagerNonNativeMP extends BioCheatManagerNonNative within BioPlayerController
    transient
    config(Game);

var CBotProxy cbProxy;
public final exec function CBot(optional string kitId, optional string wpn, optional int logicId)
{
    cbProxy.SummonAgent(Outer, Self, kitId, wpn, logicId);
}

defaultproperties
{
    // CBot
    cbProxy = CBotProxy'SFXGameMPContent.Default__CBotProxy'
}
