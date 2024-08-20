class Patch_SFXWeapon extends SFXWeapon_NativeBase
    placeable
    abstract
    config(Weapon);

// Workaround for the weapon impact audio playing at full volume
public simulated function WwiseEvent GetImpactSound(PhysicalMaterial PhysMat)
{
    local SFXPhysicalMaterialProperty PhysMatProp;
    local WwiseEvent result;
    local Pawn oldInstigator;
    
    if (PhysMat != None)
    {
        PhysMatProp = SFXPhysicalMaterialProperty(PhysMat.PhysicalMaterialProperty);
        if (PhysMatProp != None)
        {
            if (PhysMatProp.PhysicalMaterialImpactSounds != None)
            {
                if (SFXPawn_Player(Instigator) != None && Instigator.IsLocallyControlled() && AIController(Instigator.Controller) != None)
                {
                    oldInstigator = Instigator;
                    Instigator = None;
                    result = GetWeaponSpecificImpactSound(PhysMatProp.PhysicalMaterialImpactSounds);
                    Instigator = oldInstigator;
                    return result;
                }
                else
                    return GetWeaponSpecificImpactSound(PhysMatProp.PhysicalMaterialImpactSounds);
            }
        }
    }
    return None;
}

defaultproperties
{
}
