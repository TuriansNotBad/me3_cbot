class Patch_SFXProjectile_Explosive extends SFXProjectile
    native
    config(Weapon);

public function DoImpact(Actor InImpactedActor, Controller InInstigatorController, float BaseDamage, float InDamageRadius, float Momentum, Vector HurtOrigin, bool bFullDamage, out TraceHitInfo HitInfo)
{
    local BioPawn HitPawn;
    local bool savedIsAPlayer;
    
    InImpactedActor.TakeRadiusDamage(InInstigatorController, BaseDamage, InDamageRadius, GetDamageType(), Momentum, HurtOrigin, TRUE, Self, , HitInfo);
    HitPawn = BioPawn(InImpactedActor);
    if (HitPawn != None && HitPawn.IsHostile(Instigator) && (!HitPawn.IsPlayerOwned() || !HitPawn.IsInCover()))
    {
        if (HitPawn.Role == ENetRole.ROLE_Authority)
        {
            // CBot change: || SFXPawn_Player(HitPawn) != None, bIsAPlayer swap
            if (HitPawn.IsPlayerOwned() || SFXPawn_Player(HitPawn) != None)
            {
                savedIsAPlayer = HitPawn.bIsAPlayer;
                HitPawn.bIsAPlayer = true;
                if (HitPawn.RequestReaction(0, InInstigatorController))
                {
                    HitPawn.ReplicateAnimatedReaction(HitPawn.CurrentCustomAction);
                }
                HitPawn.bIsAPlayer = savedIsAPlayer;
            }
            else if (HitPawn.RequestReaction(1, InInstigatorController))
            {
                HitPawn.ReplicateAnimatedReaction(HitPawn.CurrentCustomAction);
            }
        }
    }
}

defaultproperties
{
}
