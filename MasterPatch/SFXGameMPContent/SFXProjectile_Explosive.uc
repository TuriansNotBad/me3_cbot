Class SFXProjectile_Explosive extends SFXProjectile
    native
    config(Weapon);

struct native ReplicatedStick 
{
    var Vector HitLocation;
    var Vector HitNormal;
    var Actor StuckActor;
    var int BoneIndex;
    var int Reaction;
    var byte Trigger;
};

var Class<SFXRumble_Explode> ExplodeRumbleClass;
var transient repnotify ReplicatedStick ReplicatedStickInfo;
var const Name DecalDissolveParamName;
var const WwiseEvent ExplosionSound;
var const WwiseEvent AdditionalExplosionSound;
var const WwiseEvent StickPawnImpactSound;
var const WwiseEvent NPStickPawnImpactSound;
var const WwiseEvent StickShieldImpactSound;
var const WwiseEvent NPStickShieldImpactSound;
var const WwiseEvent StickEnvironmentImpactSound;
var const WwiseEvent NPStickEnvironmentImpactSound;
var const float DuckDistanceThreshold;
var const WwiseEvent WwiseDuckEvent;
var float ExplosionLoudness;
var float fFuseLength;
var float StickExplodeDelay;
var const ParticleSystem ProjExplosionTemplate;
var(SFXProjectile_Explosive) RvrClientEffectInterface CE_ExplosionTemplate;
var const MaterialInterface ExplosionDecal;
var const float DecalWidth;
var const float DecalHeight;
var const float DurationOfDecal;
var const float MaxEffectDistance;
var const float AccelRate;
var const float TossZ;
var const float TerminalVelocity;
var const float CustomGravityScaling;
var const float ExplosionParticleLifetime;
var const float ExplosionEffectRadius;
var transient clearcrosslevel Actor StuckTo;
var float MinExplodeRumbleDistance;
var float MaxExplodeRumbleDistance;
var const bool bDuckAudio;
var const bool bUseHurtRadius;
var const bool bRandomizeFuse;
var const bool bAdvanceExplosionEffect;
var bool bSuppressExplosionFX;
var bool bArmed;
var const bool bStickPawns;
var const bool bStickWalls;
var transient bool bStuck;
var bool bProximityCheck;
var bool bPlayExplodeForceFeedback;
var transient byte LastReplicatedStickInfoTriggerCounter;

public simulated function Explode(Vector HitLocation, Vector HitNormal)
{
    local float NewMomentum;
    local float NewDamageRadius;
    local float NewDamage;
    local SFXPlayerController PC;
    local float fDistance;
    local float fScale;
    local ForceFeedbackWaveform Rumble;
    local int idx;
    
    if (IsShuttingDown() || bClientPredictionActive)
    {
        return;
    }
    if (!bArmed)
    {
        return;
    }
    bArmed = FALSE;
    NewMomentum = GetMomentum();
    NewDamageRadius = GetDamageRadius();
    NewDamage = GetDamage();
    if (Role == ENetRole.ROLE_Authority && (NewDamage > 0.0 || NewMomentum > 0.0) && NewDamageRadius > 0.0)
    {
        MakeNoise(ExplosionLoudness, 'NoiseType_Explosion');
        if (bUseHurtRadius)
        {
            ProjectileHurtRadius(NewDamage, NewDamageRadius, NewMomentum, HitLocation, HitNormal);
        }
    }
    if (WorldInfo.NetMode != ENetMode.NM_DedicatedServer && !bSuppressExplosionFX)
    {
        SpawnExplosionEffects(location, HitNormal);
    }
    if (bPlayExplodeForceFeedback)
    {
        PC = SFXPlayerController(WorldInfo.GetALocalPlayerController());
        if (PC != None && PC.Pawn != None && PC.IsLocalPlayerController())
        {
            fDistance = VSize(PC.Pawn.location - HitLocation);
            if (fDistance <= MaxExplodeRumbleDistance)
            {
                Rumble = ExplodeRumbleClass.default.TheWaveForm;
                if (fDistance > MinExplodeRumbleDistance)
                {
                    fScale = 1.0 - (fDistance - MinExplodeRumbleDistance) / (MaxExplodeRumbleDistance - MinExplodeRumbleDistance);
                    fScale *= fScale;
                    for (idx = 0; idx < Rumble.Samples.Length; idx++)
                    {
                        Rumble.Samples[idx].LeftAmplitude *= fScale;
                        Rumble.Samples[idx].RightAmplitude *= fScale;
                    }
                }
                PC.ClientPlayForceFeedbackWaveform(Rumble);
            }
        }
    }
    Super.Explode(HitLocation, HitNormal);
}
public event function HitWall(Vector HitNormal, Actor Wall, PrimitiveComponent WallComp)
{
    if (bShuttingDown || bClientPredictionActive)
    {
        return;
    }
    if (!bStickWalls)
    {
        Super.HitWall(HitNormal, Wall, WallComp);
    }
    else
    {
        StickTrace(Wall, HitNormal, WallComp);
    }
}
public simulated function Init(Vector Direction)
{
    Super.Init(Direction);
    Velocity = default.Speed * Direction;
    Velocity.Z += TossZ;
    Acceleration = AccelRate * Normal(Velocity);
    bArmed = TRUE;
    if (bRandomizeFuse)
    {
        SetTimer(fFuseLength + FRand() * 0.5, FALSE, , );
    }
    else
    {
        SetTimer(fFuseLength, FALSE, , );
    }
}
public event simulated function Landed(Vector HitNormal, Actor FloorActor)
{
    HitWall(HitNormal, FloorActor, None);
}
public static function PrecacheVFX(SFXObjectPool ObjectPool, RvrClientEffectManager ClientEffects)
{
    Super.PrecacheVFX(ObjectPool, ClientEffects);
    ObjectPool.PrecacheImpactEmitter(default.ProjExplosionTemplate);
}
public simulated function Recycle()
{
    Super.Recycle();
    bStuck = default.bStuck;
    if (StuckTo != None)
    {
        SetBase(None, , , );
        StuckTo = None;
    }
    bSuppressExplosionFX = default.bSuppressExplosionFX;
    bProximityCheck = default.bProximityCheck;
    fFuseLength = default.fFuseLength;
}
public simulated function ReplicatedEvent(Name VarName)
{
    if (VarName == 'ReplicatedStickInfo')
    {
        if (int(LastReplicatedStickInfoTriggerCounter) != int(ReplicatedStickInfo.Trigger))
        {
            Stick(ReplicatedStickInfo.StuckActor, ReplicatedStickInfo.HitLocation, ReplicatedStickInfo.HitNormal, ReplicatedStickInfo.BoneIndex, ReplicatedStickInfo.Reaction);
            LastReplicatedStickInfoTriggerCounter = ReplicatedStickInfo.Trigger;
        }
    }
    else
    {
        Super.ReplicatedEvent(VarName);
    }
}
public event simulated function SetInitialState()
{
    bScriptInitialized = TRUE;
    if (Role < ENetRole.ROLE_Authority && AccelRate != 0.0)
    {
        GotoState('WaitingForVelocity', , , );
    }
    else
    {
        GotoState(InitialState != 'None' ? InitialState : 'Auto', , , );
    }
}
public function Timer()
{
    if (IsShuttingDown() == FALSE && bClientPredictionActive == FALSE)
    {
        Explode(location, vect(0.0, 0.0, 1.0));
        ShutDown();
    }
}
public event singular simulated function Touch(Actor Other, PrimitiveComponent OtherComp, Vector HitLocation, Vector HitNormal)
{
    local Pawn OtherPawn;
    
    if (bShuttingDown || bClientPredictionActive)
    {
        return;
    }
    if (Other == None || Other.bDeleteMe)
    {
        return;
    }
    if (Other.StopsProjectile(Self) && (Role == ENetRole.ROLE_Authority || bBegunPlay) && (bBlockedByInstigator || Other != Instigator))
    {
        if (!bStickPawns)
        {
            ImpactedActor = Other;
            ProcessTouch(Other, HitLocation, HitNormal);
            ImpactedActor = None;
        }
        else
        {
            if (Role != ENetRole.ROLE_Authority)
            {
                return;
            }
            OtherPawn = Pawn(Other);
            if (Projectile(Other) != None || OtherPawn != None && OtherPawn.GetTeam().TeamIndex == 0)
            {
                return;
            }
            if (bProximityCheck && OtherPawn != None)
            {
                DelayedExplosion();
            }
            else
            {
                ImpactedActor = Other;
                StickTrace(Other, HitNormal, OtherComp);
            }
        }
    }
}
public simulated function bool CanSplash()
{
    return FALSE;
}
public simulated function bool CheckMaxEffectDistance(PlayerController P, Vector SpawnLocation, optional float CullDistance)
{
    local float Dist;
    
    if (P.ViewTarget == None)
    {
        return TRUE;
    }
    if (Vector(P.Rotation) Dot (SpawnLocation - P.ViewTarget.location) < 0.0)
    {
        return VSize(P.ViewTarget.location - SpawnLocation) < ExplosionEffectRadius;
    }
    Dist = VSize(SpawnLocation - P.ViewTarget.location);
    if (CullDistance > float(0) && CullDistance < Dist * P.LODDistanceFactor)
    {
        return FALSE;
    }
    return TRUE;
}
public simulated function bool EffectIsRelevant(Vector SpawnLocation, bool bForceDedicated, optional float CullDistance)
{
    local PlayerController PC;
    
    if (WorldInfo.NetMode != ENetMode.NM_DedicatedServer && SpawnLocation == location)
    {
        foreach LocalPlayerControllers(Class'PlayerController', PC)
        {
            if (PC.ViewTarget != None && VSize(PC.ViewTarget.location - location) < 256.0)
            {
                return TRUE;
            }
        }
    }
    return Super(Actor).EffectIsRelevant(SpawnLocation, bForceDedicated, CullDistance);
}
public function ProcessTouch(Actor Other, Vector HitLocation, Vector HitNormal)
{
    if (bShuttingDown || bClientPredictionActive)
    {
        return;
    }
    if (SFXPawn_Player(Instigator) != None && (SFXPawn_Henchman(Other) != None || SFXPawn_Player(Other) != None))
    {
        return;
    }
    if (Pawn(Other) == None && StaticMeshActor(Other) == None && BioPhysicsActor(Other) == None && DynamicSMActor(Other) == None)
    {
        return;
    }
    if (StaticMeshActor(Other) != None || BioPhysicsActor(Other) != None || DynamicSMActor(Other) != None)
    {
        if (VSizeSq(location - Owner.location) < float(40000))
        {
            return;
        }
    }
    if (GetDamageRadius() > 0.0)
    {
        Explode(HitLocation, HitNormal);
    }
    else
    {
        Other.TakeRadiusDamage(InstigatorController, GetDamage(), GetDamageRadius(), GetDamageType(), GetMomentum(), HitLocation, TRUE, Instigator.Weapon);
    }
    if (IsShuttingDown() == FALSE)
    {
        ShutDown();
    }
}
public function bool ProjectileHurtRadius(float InDamageAmount, float InDamageRadius, float Momentum, Vector HurtOrigin, Vector HitNormal)
{
    local bool bCausedDamage;
    local bool bInitializedAltOrigin;
    local bool bFailedAltOrigin;
    local Actor Victim;
    local Vector AltOrigin;
    local Vector OutLocation;
    local Vector OutNormal;
    local TraceHitInfo HitInfo;
    
    if (bHurtEntry)
    {
        return FALSE;
    }
    bHurtEntry = TRUE;
    bCausedDamage = FALSE;
    if (ImpactedActor != None && ImpactedActor != Self)
    {
        DoImpactTrace(ImpactedActor, InstigatorController, InDamageAmount, InDamageRadius, Momentum, HurtOrigin, TRUE);
        if (ImpactedActor != None)
        {
            bCausedDamage = ImpactedActor.bProjTarget;
        }
    }
    foreach CollidingActors(Class'Actor', Victim, InDamageRadius, HurtOrigin, TRUE, , )
    {
        if (Victim.CollisionComponent != None && !Victim.bWorldGeometry && Victim != Self && Victim != ImpactedActor && (Victim.bProjTarget || NavigationPoint(Victim) == None && Volume(Victim) == None))
        {
            if (Victim.Trace(OutLocation, OutNormal, HurtOrigin, Victim.CollisionComponent.Bounds.Origin, FALSE, , HitInfo, 1) != None)
            {
                if (!bInitializedAltOrigin)
                {
                    bInitializedAltOrigin = TRUE;
                    AltOrigin = HurtOrigin + Class'BioPawn'.default.MaxStepHeight * HitNormal;
                    if (Victim.Trace(OutLocation, OutNormal, HurtOrigin, AltOrigin, FALSE, , , 1) != None)
                    {
                        if (Velocity == vect(0.0, 0.0, 0.0))
                        {
                            bFailedAltOrigin = TRUE;
                        }
                        else
                        {
                            AltOrigin = HurtOrigin - Class'BioPawn'.default.MaxStepHeight * Normal(Velocity);
                            bFailedAltOrigin = Victim.Trace(OutLocation, OutNormal, HurtOrigin, AltOrigin, FALSE, , , ) != None;
                        }
                    }
                }
                if (bFailedAltOrigin || Victim.Trace(OutLocation, OutNormal, HurtOrigin, Victim.CollisionComponent.Bounds.Origin, , , , ) != None)
                {
                    continue;
                }
            }
            DoImpactTrace(Victim, InstigatorController, InDamageAmount, InDamageRadius, Momentum, HurtOrigin, FALSE);
            bCausedDamage = bCausedDamage || Victim.bProjTarget;
        }
    }
    bHurtEntry = FALSE;
    return bCausedDamage;
}
public function DelayedExplosion()
{
    local Vector HitNormal;
    
    if (StuckTo != None)
    {
        HitNormal = Normal(location - StuckTo.location);
    }
    SetBase(None, , , );
    Explode(location, HitNormal);
    if (IsShuttingDown() == FALSE)
    {
        ShutDown();
    }
}
public function DoImpact(Actor InImpactedActor, Controller InInstigatorController, float BaseDamage, float InDamageRadius, float Momentum, Vector HurtOrigin, bool bFullDamage, out TraceHitInfo HitInfo)
{
    local BioPawn HitPawn;
    
    InImpactedActor.TakeRadiusDamage(InInstigatorController, BaseDamage, InDamageRadius, GetDamageType(), Momentum, HurtOrigin, TRUE, Self, , HitInfo);
    HitPawn = BioPawn(InImpactedActor);
    if (HitPawn != None && HitPawn.IsHostile(Instigator) && (!HitPawn.IsPlayerOwned() || !HitPawn.IsInCover()))
    {
        if (HitPawn.Role == ENetRole.ROLE_Authority)
        {
            // CBot change: || SFXPawn_Player(HitPawn) != None
            if (HitPawn.IsPlayerOwned() || SFXPawn_Player(HitPawn) != None)
            {
                if (HitPawn.RequestReaction(0, InInstigatorController))
                {
                    HitPawn.ReplicateAnimatedReaction(HitPawn.CurrentCustomAction);
                }
            }
            else if (HitPawn.RequestReaction(1, InInstigatorController))
            {
                HitPawn.ReplicateAnimatedReaction(HitPawn.CurrentCustomAction);
            }
        }
    }
}
public function DoImpactTrace(Actor InImpactedActor, Controller InInstigatorController, float BaseDamage, float InDamageRadius, float Momentum, Vector HurtOrigin, bool bFullDamage)
{
    local Vector LineDir;
    local Vector OutLocation;
    local Vector OutNormal;
    local TraceHitInfo HitInfo;
    local TraceHitInfo BestHitInfo;
    local float Time;
    local float BestTime;
    local int ArmourIndex;
    local SFXModule_Armour ArmourMod;
    
    ArmourMod = InImpactedActor.GetModule(Class'SFXModule_Armour');
    BestTime = 1.0;
    if (ArmourMod != None)
    {
        for (ArmourIndex = 0; ArmourIndex < 12; ArmourIndex++)
        {
            if (ArmourMod.ActiveArmour[ArmourIndex] == None || ArmourMod.ActiveArmour[ArmourIndex].AttachInstance == None)
            {
                continue;
            }
            LineDir = InImpactedActor.location - location;
            if (InImpactedActor.TraceComponent(OutLocation, OutNormal, ArmourMod.ActiveArmour[ArmourIndex].AttachInstance, InImpactedActor.location + LineDir, location - LineDir, vect(0.0, 0.0, 0.0), HitInfo, TRUE) == TRUE)
            {
                Time = VSize(OutLocation - location) / (VSize(InImpactedActor.location - location) + VSize(LineDir) * float(2));
                if (Time < BestTime)
                {
                    BestHitInfo = HitInfo;
                    BestTime = Time;
                }
            }
        }
    }
    DoImpact(InImpactedActor, InInstigatorController, BaseDamage, InDamageRadius, Momentum, HurtOrigin, bFullDamage, BestHitInfo);
}
public simulated function DoStickImpact(Actor Other, Vector HitLocation, Vector HitNormal, TraceHitInfo HitInfo);

public function Class<DamageType> GetDamageType()
{
    local Class<DamageType> DamageType;
    local SFXWeapon Weapon;
    
    DamageType = MyDamageType;
    Weapon = SFXWeapon(Owner);
    if (Weapon == None)
    {
        Weapon = SFXWeapon(Outer);
    }
    if (Weapon != None)
    {
        DamageType = Weapon.GetDamageType();
    }
    return DamageType;
}
public function EReactionTypes GetStickReaction()
{
    return 0;
}
public static final function float RadiusFallOff(float Distance, float OuterRadius, optional float InnerRadius)
{
    local float Scale;
    
    if (Distance > OuterRadius)
    {
        return 0.0;
    }
    else if (Distance <= InnerRadius)
    {
        return 1.0;
    }
    else
    {
        Scale = 1.0 - (Distance - InnerRadius) / (OuterRadius - InnerRadius);
        return Scale * Scale;
    }
}
public function ReplicateStick(Actor Other, Vector HitLocation, Vector HitNormal, int BoneIndex)
{
    local BioPawn P;
    local BioCustomAction CurrentCA;
    
    ReplicatedStickInfo.Trigger++;
    ReplicatedStickInfo.StuckActor = Other;
    ReplicatedStickInfo.BoneIndex = BoneIndex;
    ReplicatedStickInfo.HitLocation = HitLocation;
    ReplicatedStickInfo.HitNormal = HitNormal;
    P = BioPawn(Other);
    if (P != None && P.GetCurrentCustomAction(CurrentCA) && CurrentCA != None && CurrentCA.IsA('SFXCustomAction_DamageReaction'))
    {
        ReplicatedStickInfo.Reaction = P.CurrentCustomAction;
    }
    else
    {
        ReplicatedStickInfo.Reaction = 0;
    }
}
public simulated function SetExplosionEffectParameters(ParticleSystemComponent ProjExplosion);

public simulated function SpawnExplosionEffects(Vector HitLocation, Vector HitNormal)
{
    local Rotator EffectRotation;
    local Vector ListenerPosition;
    
    if (ProjExplosionTemplate != None)
    {
        EffectRotation = Rotator(HitNormal) + rot(-16384, 0, 0);
        SFXGRI(WorldInfo.GRI).DuringAsyncWorker.SpawnEffectAtLocation(Instigator, ProjExplosionTemplate, location, EffectRotation, ExplosionParticleLifetime);
    }
    if (ExplosionDecal != None && Pawn(ImpactedActor) == None)
    {
        SFXGRI(WorldInfo.GRI).DuringAsyncWorker.SpawnImpactDecalAtLocation(Instigator, ExplosionDecal, HitLocation, HitNormal, DecalWidth, DecalHeight, 5.0, TRUE, DurationOfDecal);
    }
    if (CE_ExplosionTemplate != None)
    {
        Class'RvrClientEffectManager'.static.GetClientEffectManager().PlayAtLocation(CE_ExplosionTemplate, HitLocation);
    }
    if (ExplosionSound != None && !bSuppressAudio)
    {
        SFXGRI(WorldInfo.GRI).PlayTransientSound(ExplosionSound, HitLocation);
    }
    if (AdditionalExplosionSound != None && !bSuppressAudio)
    {
        SFXGRI(WorldInfo.GRI).PlayTransientSound(AdditionalExplosionSound, HitLocation);
    }
    if (bDuckAudio)
    {
        ListenerPosition = Class'WwiseAudioComponent'.static.GetMicPosition();
        if (VSize(ListenerPosition - HitLocation) < DuckDistanceThreshold)
        {
            PlaySound(WwiseDuckEvent, TRUE);
        }
    }
    bSuppressExplosionFX = TRUE;
}
public simulated function bool Stick(Actor Other, Vector HitLocation, Vector HitNormal, int BoneIdx, optional int Reaction)
{
    local bool bStuckToPawn;
    local BioPawn oPawn;
    local Rotator BoneRot;
    local Name BoneName;
    local ImpactInfo Impact;
    local SFXWeapon Weapon;
    local TraceHitInfo HitInfo;
    
    bStopAiming = TRUE;
    SetHardAttach(TRUE);
    oPawn = BioPawn(Other);
    Weapon = SFXWeapon(ProjectileOwner);
    if (Weapon != None)
    {
        Impact.HitActor = Other;
        Impact.HitLocation = HitLocation;
        Impact.HitNormal = HitNormal;
        Impact.RayDir = -HitNormal;
        Weapon.__OnWeaponImpact__Delegate(Weapon, Impact);
    }
    Velocity = vect(0.0, 0.0, 0.0);
    Acceleration = vect(0.0, 0.0, 0.0);
    if (oPawn != None)
    {
        if (StickShieldImpactSound != None && oPawn.HasAnyShieldResistance())
        {
            if (Instigator != None && Instigator.IsHumanControlled() && Instigator.IsLocallyControlled() || NPStickShieldImpactSound == None)
            {
                SFXGRI(WorldInfo.GRI).PlayTransientSound(StickShieldImpactSound, HitLocation);
            }
            else
            {
                SFXGRI(WorldInfo.GRI).PlayTransientSound(NPStickShieldImpactSound, HitLocation);
            }
        }
        else if (Instigator != None && Instigator.IsHumanControlled() && Instigator.IsLocallyControlled() || NPStickPawnImpactSound == None)
        {
            SFXGRI(WorldInfo.GRI).PlayTransientSound(StickPawnImpactSound, HitLocation);
        }
        else
        {
            SFXGRI(WorldInfo.GRI).PlayTransientSound(NPStickPawnImpactSound, HitLocation);
        }
        BoneName = oPawn.Mesh.GetBoneName(BoneIdx);
        SetLocation(oPawn.Mesh.GetBoneLocation(BoneName), );
        BoneRot = QuatToRotator(oPawn.Mesh.GetBoneQuaternion(BoneName));
        SetBase(oPawn, , oPawn.Mesh, BoneName);
        SetRelativeLocation(HitLocation - oPawn.Mesh.GetBoneLocation(BoneName) << BoneRot);
        SetCollision(FALSE, FALSE, );
        if (Role != ENetRole.ROLE_Authority)
        {
            oPawn.ClientPlayAnimatedReaction(Reaction);
        }
        bStuckToPawn = TRUE;
    }
    else
    {
        if (Instigator != None && Instigator.IsHumanControlled() && Instigator.IsLocallyControlled() || NPStickEnvironmentImpactSound == None)
        {
            SFXGRI(WorldInfo.GRI).PlayTransientSound(StickEnvironmentImpactSound, HitLocation);
        }
        else
        {
            SFXGRI(WorldInfo.GRI).PlayTransientSound(NPStickEnvironmentImpactSound, HitLocation);
        }
        SetLocation(HitLocation, );
        if (Other != None && StaticMeshCollectionActor(Other) == None)
        {
            SetBase(Other, , , );
        }
    }
    bStuck = TRUE;
    StuckTo = Other;
    if (Role != ENetRole.ROLE_Authority)
    {
        DoStickImpact(Other, HitLocation, HitNormal, HitInfo);
    }
    return bStuckToPawn;
}
public function StickTrace(Actor Other, Vector HitNormal, PrimitiveComponent OtherComp)
{
    local Vector HitLocation;
    local TraceHitInfo HitInfo;
    local Attachment Attachment;
    local BioPawn oPawn;
    local int BoneIdx;
    local Vector MovementDir;
    local float MovementMag;
    
    MovementDir = Normal(Velocity);
    MovementMag = VSize(Velocity) + float(100);
    if (Self.TraceComponent(HitLocation, HitNormal, OtherComp, location + MovementDir * float(100), location - MovementDir * MovementMag, vect(0.0, 0.0, 0.0), HitInfo, TRUE) == FALSE)
    {
        return;
    }
    oPawn = BioPawn(Other);
    if (oPawn != None)
    {
        if (HitInfo.BoneName == 'None')
        {
            foreach oPawn.Mesh.Attachments(Attachment, )
            {
                if (Attachment.Component == HitInfo.HitComponent)
                {
                    HitInfo.BoneName = Attachment.BoneName;
                    break;
                }
            }
        }
        BoneIdx = oPawn.Mesh.MatchRefBone(HitInfo.BoneName);
    }
    if (Role == ENetRole.ROLE_Authority)
    {
        if (oPawn != None)
        {
            oPawn.RequestReaction(GetStickReaction(), InstigatorController, -HitNormal * GetMomentum());
        }
        ReplicateStick(Other, HitLocation, HitNormal, BoneIdx);
    }
    Stick(Other, HitLocation, HitNormal, BoneIdx);
    if (Role == ENetRole.ROLE_Authority)
    {
        DoStickImpact(Other, HitLocation, HitNormal, HitInfo);
    }
    SetTimer(StickExplodeDelay, FALSE, 'DelayedExplosion', );
}
public function Tick_Prediction(float DeltaTime)
{
    local SFXProjectile_Explosive oTargetProjectile;
    
    oTargetProjectile = SFXProjectile_Explosive(TargetProjectile);
    if (bGotAPredictionTarget && oTargetProjectile != None && oTargetProjectile.bStuck == TRUE)
    {
        if (!bStuck)
        {
            StuckTo = oTargetProjectile.StuckTo;
            Acceleration = oTargetProjectile.Acceleration;
            Velocity = oTargetProjectile.Velocity;
            SetLocation(oTargetProjectile.location, );
            SetRotation(oTargetProjectile.Rotation);
            if (BioPawn(StuckTo) != None)
            {
                SetBase(oTargetProjectile.Base, , oTargetProjectile.BaseSkelComponent, oTargetProjectile.BaseBoneName);
                SetRelativeLocation(oTargetProjectile.RelativeLocation);
            }
            else if (StuckTo != None && StaticMeshCollectionActor(StuckTo) == None)
            {
                SetBase(StuckTo, , , );
            }
            bStuck = TRUE;
        }
        Speed = oTargetProjectile.Speed;
    }
    Super.Tick_Prediction(DeltaTime);
}

state WaitingForVelocity 
{
    public simulated function Tick(float DeltaTime)
    {
        if (!IsZero(Velocity))
        {
            Acceleration = AccelRate * Normal(Velocity);
            GotoState(InitialState != 'None' ? InitialState : 'Auto', , , );
        }
    }
    
    stop;
};

replication
{
    if (bNetDirty && Role == ENetRole.ROLE_Authority)
        ReplicatedStickInfo;
}

defaultproperties
{
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        ReplacementPrimitive = None
    End Template
    ExplodeRumbleClass = Class'SFXRumble_Explode'
    DecalDissolveParamName = 'DissolveAmount'
    DuckDistanceThreshold = 500.0
    WwiseDuckEvent = None
    ExplosionLoudness = 1.0
    fFuseLength = 25.0
    StickExplodeDelay = 25.0
    ExplosionDecal = DecalMaterial'BioVFX_C_Impacts.Generic.Decals.DECAL_Blast_Generic'
    DurationOfDecal = 4.0
    MaxEffectDistance = 10000.0
    TerminalVelocity = 3500.0
    CustomGravityScaling = 1.0
    ExplosionParticleLifetime = 3.0
    ExplosionEffectRadius = 1000.0
    MinExplodeRumbleDistance = 250.0
    MaxExplodeRumbleDistance = 1500.0
    bUseHurtRadius = TRUE
    bRandomizeFuse = TRUE
    Speed = 8000.0
    MaxSpeed = 8000.0
    MomentumTransfer = 100.0
    CylinderComponent = CollisionCylinder
    bSwitchToZeroCollision = TRUE
    bBlockedByInstigator = FALSE
    Components = (CollisionCylinder)
    LifeSpan = 0.0
    CollisionComponent = CollisionCylinder
    bCollideComplex = TRUE
}