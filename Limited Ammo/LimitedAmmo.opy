settings {
    "main": {
        "description": "It's Overwatch, but everyone has finite ammo.\n\nCode: Q72WR\nLast updated: 2025-02-01",
        "modeName": "Limited Ammo"
    },
    "lobby": {
        "team1Slots": 5,
        "team2Slots": 5
    },
    "gamemodes": {
        "tdm": {
            "enabledMaps": [
                "workshopIsland"
            ]
        },
        "general": {
            "roleLimit": "1Tank2Offense2Support"
        }
    },
    "heroes": {
        "allTeams": {
            "disabledHeroes": [
                # these heroes cannot have their ammo read or written to, so goodbye.
                "kiriko",
                "lifeweaver",
                "mauga",
                "venture",
                "juno",
                "ramattra",
                # doomfist has an infinite ammo bug that cannot be solved right now.
                "doomfist"
            ]
        }
    }
}

#!extension projectiles
#!extension explosionSounds

#!define toTimestamp(time) "{0}{1}:{2}{3}".format("0" if floor(time / 60) < 10 else "", floor(time / 60), "0" if floor(time % 60) < 10 else "", floor(time % 60))

#######################
###    VARIABLES    ###
#######################

# Debug Utilities

globalvar DEBUG = createWorkshopSetting(bool, "Technical Settings", "Show Debug Information", false, 1)

globalvar d = 0

#!define DEBUG_TEXT_LIMIT 128
#!define DEBUG_EFFECT_LIMIT 128


# Statistic Tracking

globalvar LOG_STATS = createWorkshopSetting(bool, "Technical Settings", "Record Statistics", false, 0)

globalvar s = 0

globalvar str = ""

globalvar stats_Highlights = []

globalvar stats_MatchDuration = 0
globalvar stats_ReplayDuration = 0

globalvar stats_DurationPlaytime   = [] # array statistics are indexed per-hero.
globalvar stats_DurationAlive      = []
globalvar stats_DurationOutOfAmmo  = []

globalvar stats_AmmoConsumed       = []
globalvar stats_TimesReloaded      = []
globalvar stats_AmmoPacksCollected = []

globalvar stats_Kills              = []
globalvar stats_KillsOutOfAmmo     = []

globalvar stats_Deaths             = []
globalvar stats_DeathsOutOfAmmo    = []

#!define C_MAX_SLOTS_PER_TEAM 6

playervar SLOT_INDEX = -1  # used to track player duration stats through disconnects.
globalvar g_PlayerIsInSlot      = []
globalvar g_PlayerEntities      = []
globalvar g_PlayerHeroIndices   = []

globalvar g_TimestampsPlaytime  = []
globalvar g_TimestampsAlive     = []
globalvar g_TimestampsOutOfAmmo = []


# Limited Ammo Logic

globalvar AMMO_PACK_RESPAWN_TIME = createWorkshopSetting(int[1:60], "Gameplay Settings", "Ammo Pack Respawn Time (seconds)", 10, 0)
globalvar SHOW_ENEMY_INDICATORS = createWorkshopSetting(bool, "Gameplay Settings", "Show Out of Ammo Indicators Above Enemies", true, 1)

#!define LOW_AMMO_THRESHOLD 0.33
#!define AMMO_PACK_GAIN_RATIO 0.5
# TODO: implement per-hero collection radius?
#!define AMMO_PACK_COLLECTION_RADIUS 1.1

enum AmmoState:
    EMPTY,
    LOW,
    HIGH

enum AmmoType:
    NONE,       # the weapon does not exist or does not use ammo (usually melee weapons).
    CLIP,       # the weapon has a clip the player reloads ammo into (most weapons fall into this category).
    CUSTOM      # the weapon does not have a clip and requires a custom ammo manager rule (d.va's mech, hanzo's bow, etc).

# C_HERO_AMMO_DATA defines the type and maximum amount of ammunition for each hero.
# if the type is CLIP, max ammo is a ratio of max clip size.
# if the type is CUSTOM, max ammo is a direct value.

#!define INDEX_PRIMARY_TYPE    0
#!define INDEX_PRIMARY_MAX     1
#!define INDEX_SECONDARY_TYPE  2
#!define INDEX_SECONDARY_MAX   3

globalvar C_HERO_AMMO_DATA = [
    [AmmoType.CLIP,         3,      AmmoType.NONE,      null],  # Reaper
    [AmmoType.CLIP,         6,      AmmoType.NONE,      null],  # Tracer
    [AmmoType.CLIP,         2,      AmmoType.NONE,      null],  # Mercy
    [AmmoType.CUSTOM,      30,      AmmoType.NONE,      null],  # Hanzo
    [AmmoType.CLIP,         2,      AmmoType.NONE,      null],  # Torbjorn
    [AmmoType.NONE,      null,      AmmoType.NONE,      null],  # Reinhardt
    [AmmoType.CLIP,         4,      AmmoType.NONE,      null],  # Pharah
    [AmmoType.CLIP,         3,      AmmoType.NONE,      null],  # Winston
    [AmmoType.CLIP,         2,      AmmoType.NONE,      null],  # Widowmaker
    [AmmoType.CLIP,         3,      AmmoType.NONE,      null],  # Bastion
    [AmmoType.CLIP,         2,      AmmoType.NONE,      null],  # Symmetra
    [AmmoType.CLIP,         2,      AmmoType.NONE,      null],  # Zenyatta
    [AmmoType.CLIP,         3,      AmmoType.NONE,      null],  # Genji
    [AmmoType.CLIP,         4,      AmmoType.NONE,      null],  # Roadhog
    [AmmoType.CLIP,         5,      AmmoType.NONE,      null],  # Cassidy
    [AmmoType.CLIP,         4,      AmmoType.NONE,      null],  # Junkrat
    [AmmoType.CLIP,         5,      AmmoType.NONE,      null],  # Zarya
    [AmmoType.CLIP,         4,      AmmoType.NONE,      null],  # Soldier: 76
    [AmmoType.CLIP,         3,      AmmoType.NONE,      null],  # Lucio
    [AmmoType.CUSTOM,     160,      AmmoType.NONE,      null],  # D.Va (Mech)
    [AmmoType.CLIP,         2,      AmmoType.NONE,      null],  # Mei
    [AmmoType.CLIP,         3,      AmmoType.NONE,      null],  # Sombra
    [AmmoType.CLIP,         5,      AmmoType.NONE,      null],  # Doomfist
    [AmmoType.CLIP,         2,      AmmoType.NONE,      null],  # Ana
    [AmmoType.CUSTOM,     250,      AmmoType.NONE,      null],  # Orisa
    [AmmoType.NONE,      null,      AmmoType.NONE,      null],  # Brigitte
    [AmmoType.NONE,      null,      AmmoType.CUSTOM,      50],  # Moira
    [AmmoType.CLIP,         3,      AmmoType.NONE,      null],  # Wrecking Ball
    [AmmoType.CLIP,         6,      AmmoType.NONE,      null],  # Sojourn
    [AmmoType.CLIP,         3,      AmmoType.NONE,      null],  # Ashe
    [AmmoType.CLIP,         4,      AmmoType.NONE,      null],  # Echo
    [AmmoType.CLIP,         2,      AmmoType.CLIP,         2],  # Baptiste
    [AmmoType.CLIP,         2,      AmmoType.CLIP,         2],  # Kiriko
    [AmmoType.CLIP,         3,      AmmoType.NONE,      null],  # Junker Queen
    [AmmoType.CUSTOM,      48,      AmmoType.NONE,      null],  # Sigma
    [AmmoType.CLIP,         3,      AmmoType.NONE,      null],  # Ramattra
    [AmmoType.CLIP,         2,      AmmoType.CLIP,         2],  # Lifeweaver
    [AmmoType.CLIP,         2,      AmmoType.NONE,      null],  # Mauga
    [AmmoType.CLIP,         2,      AmmoType.NONE,      null],  # Illari
    [AmmoType.CLIP,         3,      AmmoType.NONE,      null],  # Venture
    [AmmoType.CLIP,         2,      AmmoType.NONE,      null],  # Hazard
    [AmmoType.CLIP,         2,      AmmoType.NONE,      null]   # Juno
]

# list of heroes who are not allowed to be played.
globalvar C_HEROES_DISABLED = [
    Hero.DOOMFIST,
    Hero.JUNO,
    Hero.KIRIKO,
    Hero.LIFEWEAVER,
    Hero.MAUGA,
    Hero.RAMATTRA,
    Hero.VENTURE
]

# list of heroes who have one ammo pool but two firing methods.
globalvar C_HEROES_ALT_FIRE = [
    Hero.CASSIDY,
    Hero.GENJI,
    Hero.MAUGA,
    Hero.MEI,
    Hero.SYMMETRA,
    Hero.TORBJORN,
    Hero.WINSTON,
    Hero.ZARYA,
    Hero.ZENYATTA
]

# list of heroes who reload ammo into their clip one-by-one.
globalvar C_HEROES_QUICK_DISABLE_RELOAD = [
    Hero.ASHE,
    Hero.DOOMFIST
]

# list of heroes who use primary fire to perform an action during their ultimate.
globalvar C_HEROES_NO_WARNING_ULT = [
    Hero.BASTION,
    Hero.CASSIDY,
    Hero.DOOMFIST,
    Hero.GENJI,
    Hero.JUNKRAT,
    Hero.ORISA,
    Hero.ROADHOG,
    Hero.SIGMA,
    Hero.TORBJORN,
    Hero.VENTURE,
    Hero.WINSTON
]

globalvar i = 0
globalvar j = 0

globalvar bracket

globalvar C_IS_CONTROL = false # we can't check if the game mode is control because of a workshop bug, so it's set explicitly.
globalvar CONTROL_STAGE = -1

globalvar C_AMMO_PACKS = [] # constant array of every ammo pack for the map.
globalvar C_AMMO_PACKS_STAGE_SLICE = [] # for control maps. index corresponds to each stage.

globalvar AMMO_PACK_POSITIONS = []
globalvar AMMO_PACK_TIMESTAMPS = []

globalvar AMMO_PACK_EFFECTS_PROJ = []
globalvar AMMO_PACK_EFFECTS_RING = []
globalvar AMMO_PACK_EFFECTS_TEXT = []

playervar HAS_ALT_FIRE = false

playervar AMMO_TYPE_PRIMARY = AmmoType.NONE
playervar AMMO_TYPE_SECONDARY = AmmoType.NONE

playervar MAX_RESERVE_AMMO_PRIMARY = 0
playervar MAX_RESERVE_AMMO_SECONDARY = 0

playervar reserveAmmoPrimary = 0
playervar reserveAmmoSecondary = 0

playervar cachedAmmoPrimary = -1
playervar cachedAmmoSecondary = -1

playervar ammoStatePrimary = AmmoState.EMPTY
playervar ammoStateSecondary = AmmoState.EMPTY

playervar touchedPackIndex = -1
playervar heroIndex = -1

playervar canCollectPacks = true # hacks for cases where ammo packs cannot be picked up.

playervar showIndicator = true # hacks for cases where the out of ammo indicator should be hidden.

playervar suppressNoAmmoWarning = false # hacks for cases where the out of ammo warning should not appear.

playervar pauseAmmoManager = false # hack for junkrat and bastion ults.

playervar antiHanzoCheese = false # hack for hanzo infinite ammo exploit.

playervar wasInMech = false # hack for d.va mech change.

playervar wasDuplicating = false # hacks for echo duplication.
playervar echoReserveAmmoPrimary = 0
playervar echoAmmoPrimary = 0


####################
###    SHARED    ###
####################

rule "Begone, Inspector":
    @Event global
    @Condition DEBUG == false

    disableInspector()


rule "Text Formatting":
    @Event global

    # stores a '<' character so we can display colored text (credit to Zezombye).
    createDummy(Hero.ANA, Team.ALL if getCurrentGamemode() == Gamemode.FFA else Team.1, false, null, null)
    getLastCreatedEntity().startForcingName("______________________________________________________________________________________________________________________________〼")
    bracket = getLastCreatedEntity()[0].split([])
    getLastCreatedEntity().startForcingName("______________________________________________________________________________________________________________________________ࡀ")
    bracket = "______________________________________________________________________________________________________________________________〼".replace(bracket, getLastCreatedEntity()[0]).substring(126, true)
    destroyAllDummies()


rule "Enforce Hero Whitelist":
    @Event eachPlayer

    # for some reason, heroes disabled via custom game settings are sometimes still enabled.
    # this ensures that disabled heroes cannot be selected.
    eventPlayer.setAllowedHeroes(getAllHeroes().exclude(C_HEROES_DISABLED))


rule "Kick Players After Match":
    @Event global
    @Condition LOG_STATS == true
    @Condition isMatchComplete() == true
    @Disabled

    # cycle in new players for streamed playtests.
    wait(25)
    removeFromGame(g_PlayerEntities.exclude(hostPlayer))


#########################
###    SUBROUTINES    ###
#########################

def resetPlayerState():
    @Name "Subroutine: Reset Player State"

    eventPlayer.pauseAmmoManager = false
    eventPlayer.wasInMech = false
    eventPlayer.showIndicator = true
    eventPlayer.suppressNoAmmoWarning = false

    eventPlayer.allowButton(Button.PRIMARY_FIRE)
    eventPlayer.allowButton(Button.SECONDARY_FIRE)
    eventPlayer.allowButton(Button.RELOAD)
    eventPlayer.setPrimaryFireEnabled(true)
    eventPlayer.setSecondaryFireEnabled(true)
    eventPlayer.setReloadEnabled(true)
    eventPlayer.setAbility1Enabled(true)
    eventPlayer.setAbility2Enabled(true)


def commitDurationPlaytime():
    @Name "Subroutine: Commit Duration: Playtime"

    if g_TimestampsPlaytime[eventPlayer.SLOT_INDEX] > 0:

        if eventPlayer.heroIndex != -1:
            stats_DurationPlaytime[eventPlayer.heroIndex] += getTotalTimeElapsed() - g_TimestampsPlaytime[eventPlayer.SLOT_INDEX]
        
        g_TimestampsPlaytime[eventPlayer.SLOT_INDEX] = 0


def commitDurationAlive():
    @Name "Subroutine: Commit Duration: Alive"

    if g_TimestampsAlive[eventPlayer.SLOT_INDEX] > 0:

        if eventPlayer.heroIndex != -1:
            stats_DurationAlive[eventPlayer.heroIndex] += getTotalTimeElapsed() - g_TimestampsAlive[eventPlayer.SLOT_INDEX]
        
        g_TimestampsAlive[eventPlayer.SLOT_INDEX] = 0


def commitDurationOutOfAmmo():
    @Name "Subroutine: Commit Duration: Out of Ammo"

    if g_TimestampsOutOfAmmo[eventPlayer.SLOT_INDEX] > 0:

        if eventPlayer.heroIndex != -1:
            stats_DurationOutOfAmmo[eventPlayer.heroIndex] += getTotalTimeElapsed() - g_TimestampsOutOfAmmo[eventPlayer.SLOT_INDEX]
        
        g_TimestampsOutOfAmmo[eventPlayer.SLOT_INDEX] = 0


def updateHeroIndex():
    @Name "Subroutine: Update Hero Index"

    # commit our accumulated playtime before updating our timestamp and hero index.
    if LOG_STATS and isGameInProgress():

        commitDurationPlaytime()
        g_TimestampsPlaytime[eventPlayer.SLOT_INDEX] = getTotalTimeElapsed()

        commitDurationAlive()
        g_TimestampsAlive[eventPlayer.SLOT_INDEX] = getTotalTimeElapsed()

        commitDurationOutOfAmmo()
    
    # index is "-1" if the player has not yet chosen a hero.
    eventPlayer.heroIndex = getAllHeroes().index(eventPlayer.getHeroOfDuplication() if eventPlayer.isDuplicatingAHero() else eventPlayer.getCurrentHero())
    g_PlayerHeroIndices[eventPlayer.SLOT_INDEX] = eventPlayer.heroIndex


def cacheAmmoData():
    @Name "Subroutine: Cache Ammo Data"

    # a value of "-1" prevents the ammo manager from using a previous hero's cached ammo values.
    eventPlayer.cachedAmmoPrimary = -1
    eventPlayer.cachedAmmoSecondary = -1

    eventPlayer.AMMO_TYPE_PRIMARY   = C_HERO_AMMO_DATA[eventPlayer.heroIndex][INDEX_PRIMARY_TYPE]
    eventPlayer.AMMO_TYPE_SECONDARY = C_HERO_AMMO_DATA[eventPlayer.heroIndex][INDEX_SECONDARY_TYPE]

    eventPlayer.MAX_RESERVE_AMMO_PRIMARY   = C_HERO_AMMO_DATA[eventPlayer.heroIndex][INDEX_PRIMARY_MAX]   if eventPlayer.AMMO_TYPE_PRIMARY   == AmmoType.CUSTOM else ceil(eventPlayer.getMaxAmmo(0) * C_HERO_AMMO_DATA[eventPlayer.heroIndex][INDEX_PRIMARY_MAX])   if eventPlayer.AMMO_TYPE_PRIMARY   == AmmoType.CLIP else 0
    eventPlayer.MAX_RESERVE_AMMO_SECONDARY = C_HERO_AMMO_DATA[eventPlayer.heroIndex][INDEX_SECONDARY_MAX] if eventPlayer.AMMO_TYPE_SECONDARY == AmmoType.CUSTOM else ceil(eventPlayer.getMaxAmmo(1) * C_HERO_AMMO_DATA[eventPlayer.heroIndex][INDEX_SECONDARY_MAX]) if eventPlayer.AMMO_TYPE_SECONDARY == AmmoType.CLIP else 0

    eventPlayer.HAS_ALT_FIRE = getAllHeroes()[eventPlayer.heroIndex] in C_HEROES_ALT_FIRE


def refillReserveAmmo():
    @Name "Subroutine: Refill Reserve Ammo"

    eventPlayer.reserveAmmoPrimary   = eventPlayer.MAX_RESERVE_AMMO_PRIMARY
    eventPlayer.reserveAmmoSecondary = eventPlayer.MAX_RESERVE_AMMO_SECONDARY


def givePlayerAmmo():
    @Name "Subroutine: Give Player Ammo"

    playEffect(getAllPlayers(), DynamicEffect.BRIGITTE_REPAIR_PACK_ARMOR_SOUND, Color.WHITE, eventPlayer.getPosition(), 150)
    playEffect(eventPlayer, DynamicEffect.BUFF_IMPACT_SOUND, Color.WHITE, eventPlayer, 100)

    # give ammo, but don't exceed the maximum reserve.
    if eventPlayer.reserveAmmoSecondary < eventPlayer.MAX_RESERVE_AMMO_SECONDARY:
        smallMessage(eventPlayer, "  {0} +{1} AMMO".format(abilityIconString(getAllHeroes()[eventPlayer.heroIndex], Button.SECONDARY_FIRE), floor(min(eventPlayer.MAX_RESERVE_AMMO_SECONDARY - eventPlayer.reserveAmmoSecondary, ceil(eventPlayer.MAX_RESERVE_AMMO_SECONDARY * AMMO_PACK_GAIN_RATIO)))))
        wait()
        eventPlayer.reserveAmmoSecondary += min(eventPlayer.MAX_RESERVE_AMMO_SECONDARY - eventPlayer.reserveAmmoSecondary, ceil(eventPlayer.MAX_RESERVE_AMMO_SECONDARY * AMMO_PACK_GAIN_RATIO))
        
    if eventPlayer.reserveAmmoPrimary < eventPlayer.MAX_RESERVE_AMMO_PRIMARY:
        smallMessage(eventPlayer, "  {0} +{1} AMMO".format(abilityIconString(getAllHeroes()[eventPlayer.heroIndex], Button.PRIMARY_FIRE), floor(min(eventPlayer.MAX_RESERVE_AMMO_PRIMARY - eventPlayer.reserveAmmoPrimary, ceil(eventPlayer.MAX_RESERVE_AMMO_PRIMARY * AMMO_PACK_GAIN_RATIO)))))
        wait()
        eventPlayer.reserveAmmoPrimary += min(eventPlayer.MAX_RESERVE_AMMO_PRIMARY - eventPlayer.reserveAmmoPrimary, ceil(eventPlayer.MAX_RESERVE_AMMO_PRIMARY * AMMO_PACK_GAIN_RATIO))

    
#################################
###    HERO SPECIFIC HACKS    ###
#################################

# while the ammo management logic is pretty robust, some heroes need extra tweaks to work properly.
# these "hack" rules fix problems caused by one-off interactions and game bugs.
# importantly, these rules precede the ammo management rules so the hack rules execute first within a tick.

# note that these rules do not use the built-in "Player" or "@Hero" field to filter which hero can run the rule.
# instead, we check the player's heroIndex so echo can fire these rules while using duplication.

rule "HACK: D.Va Switches to Generic Ammo Manager":
    @Event eachPlayer
    @Condition getAllHeroes()[eventPlayer.heroIndex] == Hero.DVA
    @Condition eventPlayer.wasInMech == true
    @Condition eventPlayer.isInAlternateForm() == true

    # the player was de-meched while out of ammo.
    if g_TimestampsOutOfAmmo[eventPlayer.SLOT_INDEX] > 0:
        stats_Highlights.append("[{0}] {1} ({2}) was de-meched while out of ammo for {3} seconds.".format(toTimestamp(stats_ReplayDuration),
                                                                                                          eventPlayer,
                                                                                                          getAllHeroes()[eventPlayer.heroIndex],
                                                                                                          getTotalTimeElapsed() - g_TimestampsOutOfAmmo[eventPlayer.SLOT_INDEX]))

    # pilot d.va has an entirely different weapon.
    eventPlayer.cachedAmmoPrimary = -1
    eventPlayer.AMMO_TYPE_PRIMARY = AmmoType.CLIP
    eventPlayer.MAX_RESERVE_AMMO_PRIMARY = ceil(eventPlayer.getMaxAmmo(0) * 4)
    refillReserveAmmo()
    eventPlayer.allowButton(Button.PRIMARY_FIRE)

    eventPlayer.wasInMech = false


rule "HACK: D.Va Switches to Custom Ammo Manager":
    @Event eachPlayer
    @Condition getAllHeroes()[eventPlayer.heroIndex] == Hero.DVA
    @Condition eventPlayer.isInAlternateForm() == false

    cacheAmmoData()
    # new mech, new me.
    refillReserveAmmo()

    eventPlayer.wasInMech = true
    
    
rule "HACK: Echo Duplication Start":
    @Event eachPlayer
    @Hero echo
    # this lock-out variable is required, otherwise the rule re-fires when exiting bastion/junkrat ult.
    @Condition eventPlayer.wasDuplicating == false
    @Condition eventPlayer.isDuplicatingAHero() == true

    # save echo's ammo prior to duplicating.
    # we store the cached ammo since our current ammo has already changed to the duplicated hero's.
    eventPlayer.echoAmmoPrimary = eventPlayer.cachedAmmoPrimary
    eventPlayer.echoReserveAmmoPrimary = eventPlayer.reserveAmmoPrimary

    # inherit the ammo data of the duplicated hero.
    resetPlayerState()
    updateHeroIndex()
    cacheAmmoData()
    refillReserveAmmo()

    eventPlayer.wasDuplicating = true


rule "HACK: Echo Duplication End":
    @Event eachPlayer
    @Hero echo
    @Condition eventPlayer.wasDuplicating == true
    @Condition eventPlayer.isDuplicatingAHero() == false

    # the player exited duplication while out of ammo.
    if g_TimestampsOutOfAmmo[eventPlayer.SLOT_INDEX] > 0:
        stats_Highlights.append("[{0}] {1} ({2}) exited duplication while out of ammo for {3} seconds.".format(toTimestamp(stats_ReplayDuration),
                                                                                                               eventPlayer,
                                                                                                               getAllHeroes()[eventPlayer.heroIndex],
                                                                                                               getTotalTimeElapsed() - g_TimestampsOutOfAmmo[eventPlayer.SLOT_INDEX]))
    
    # restore echo's ammo data.
    resetPlayerState()
    updateHeroIndex()
    cacheAmmoData()

    # restore echo's ammo from earlier.
    eventPlayer.setAmmo(0, eventPlayer.echoAmmoPrimary)
    eventPlayer.reserveAmmoPrimary = eventPlayer.echoReserveAmmoPrimary
    eventPlayer.reserveAmmoSecondary = 0
    
    eventPlayer.wasDuplicating = false


rule "HACK: Symmetra Shooting Shield":
    @Event eachPlayer
    @Condition getAllHeroes()[eventPlayer.heroIndex] == Hero.SYMMETRA
    @Condition eventPlayer.getAmmo(0) >= eventPlayer.getMaxAmmo(0)
    @Condition eventPlayer.reserveAmmoPrimary > 0
    @Condition eventPlayer.isFiringPrimaryFire() == true

    # when symmetra beams a shield, she regenerates ammo. while already at full ammo, this is undetectable by the ammo manager.
    # here we explicitly check for this and subtract reserve ammo manually (10 per second).
    eventPlayer.reserveAmmoPrimary -= 0.16

    if LOG_STATS and isGameInProgress():
        stats_AmmoConsumed[eventPlayer.heroIndex] += 0.16

    if eventPlayer.reserveAmmoPrimary <= 0:
        eventPlayer.reserveAmmoPrimary = 0
        # super hack: switch over to the ammo manager rule.
        eventPlayer.setAmmo(0, eventPlayer.getAmmo(0) - 0.1)
    
    wait()
    if RULE_CONDITION: goto RULE_START


rule "HACK: Doomfist Ult Over Packs":
    @Event eachPlayer
    @Condition getAllHeroes()[eventPlayer.heroIndex] == Hero.DOOMFIST
    @Condition eventPlayer.isUsingUltimate() == true
    
    # doomfist's entity still exists on the ground during ult, but he shouldn't be able to collect ammo packs in this state.
    eventPlayer.canCollectPacks = false
    waitUntil(eventPlayer.isUsingUltimate() == false, Math.INFINITY)
    eventPlayer.canCollectPacks = true


rule "HACK: Doomfist Empty Clip":
    @Event eachPlayer
    @Condition getAllHeroes()[eventPlayer.heroIndex] == Hero.DOOMFIST
    @Condition eventPlayer.getAmmo(0) <= 0

    # doomfist can shoot before his clip ammo increases, so this prevents firing infinite ammo by holding the button.
    eventPlayer.disallowButton(Button.PRIMARY_FIRE)
    waitUntil(eventPlayer.getAmmo(0) > 0, Math.INFINITY)
    eventPlayer.allowButton(Button.PRIMARY_FIRE)

    # we still want to actually shoot while holding the button, just a tick later so the ammo manager can run.
    wait()
    if eventPlayer.isHoldingButton(Button.PRIMARY_FIRE):
        eventPlayer.forceButtonPress(Button.PRIMARY_FIRE)


rule "HACK: Doomfist Frame Perfect Shot":
    @Event eachPlayer
    @Condition getAllHeroes()[eventPlayer.heroIndex] == Hero.DOOMFIST
    @Condition eventPlayer.isHoldingButton(Button.PRIMARY_FIRE) == true
    @Disabled

    # TODO: with good timing, doomfist can fire a shot on the same tick his ammo regenerates.
    # so far, every attempt to detect this has failed.
    # infinite ammo bugs are unnaceptable, so doomfist is disabled until there is a workaround.
    eventPlayer.reserveAmmoPrimary--


rule "HACK: Illari Negative Ammo":
    @Event eachPlayer
    @Condition getAllHeroes()[eventPlayer.heroIndex] == Hero.ILLARI
    @Condition eventPlayer.getAmmo(0) <= 0

    # illari's weapon does not prevent itself from firing when out of ammo, so we need to do it ourselves.
    eventPlayer.disallowButton(Button.PRIMARY_FIRE)
    waitUntil(eventPlayer.getAmmo(0) > 0, Math.INFINITY)
    eventPlayer.allowButton(Button.PRIMARY_FIRE)


rule "HACK: Hanzo Enable Abilities":
    @Event eachPlayer
    @Condition getAllHeroes()[eventPlayer.heroIndex] == Hero.HANZO
    @Condition eventPlayer.reserveAmmoPrimary > 0

    eventPlayer.setAbility1Enabled(true)
    eventPlayer.setAbility2Enabled(true)


rule "HACK: Hanzo Disable Abilities":
    @Event eachPlayer
    @Condition getAllHeroes()[eventPlayer.heroIndex] == Hero.HANZO
    @Condition eventPlayer.reserveAmmoPrimary <= 0

    eventPlayer.setAbility1Enabled(false)
    eventPlayer.setAbility2Enabled(false)

    # if we run out of ammo while using storm arrows, end it early.
    wait(0.25)
    if eventPlayer.isUsingAbility2() == true:
        eventPlayer.forceButtonPress(Button.ABILITY_2)


rule "HACK: Hanzo Infinite Ammo":
    @Event eachPlayer
    @Condition getAllHeroes()[eventPlayer.heroIndex] == Hero.HANZO
    @Condition eventPlayer.isFiringPrimaryFire() == false
    @Condition eventPlayer.isHoldingButton(Button.SECONDARY_FIRE) == true

    # 2025-02-01: fixes an issue where hanzo could continually hold secondary fire to prevent using ammo.
    # the wait here is essential for this hack to work. this is why you don't write crazy if statements. :)
    wait()
    eventPlayer.antiHanzoCheese = true
    waitUntil(eventPlayer.isHoldingButton(Button.SECONDARY_FIRE) == false, Math.INFINITY)
    eventPlayer.antiHanzoCheese = false


rule "HACK: Junkrat Ult Reload":
    @Event eachPlayer
    @Condition getAllHeroes()[eventPlayer.heroIndex] == Hero.JUNKRAT
    @Condition eventPlayer.isUsingUltimate() == true

    # junkrat's rip-tire changes the player's control entity, which prevents setting ammo.
    # this hack postpones running the ammo manager until the ultimate is finished.
    # BUGBUG: out of ammo duration doesn't track during the ult with this hack. freeze out of ammo timestamp when this is true?
    eventPlayer.pauseAmmoManager = true
    eventPlayer.setPrimaryFireEnabled(false)

    waitUntil(eventPlayer.isUsingUltimate() == false, Math.INFINITY)
    # unfortunately we can't know exactly when the control entity switches back to junkrat, so this wait is longer than it needs to be.
    wait(1.1)

    eventPlayer.pauseAmmoManager = false
    eventPlayer.setPrimaryFireEnabled(true)


rule "HACK: Bastion Ult Reload":
    @Event eachPlayer
    @Condition getAllHeroes()[eventPlayer.heroIndex] == Hero.BASTION
    @Condition eventPlayer.isUsingUltimate() == true

    # bastion's ultimate exhibits the same problem as junkrat's, so we perform the same hack.
    # BUGBUG: out of ammo duration doesn't track during the ult with this hack. freeze out of ammo timestamp when this is true?
    eventPlayer.pauseAmmoManager = true
    eventPlayer.setPrimaryFireEnabled(false)

    waitUntil(eventPlayer.isUsingUltimate() == false, Math.INFINITY)

    eventPlayer.pauseAmmoManager = false
    eventPlayer.setPrimaryFireEnabled(true)


rule "HACK: Sombra Stealth Indicator":
    @Event eachPlayer
    @Condition SHOW_ENEMY_INDICATORS == true
    @Condition getAllHeroes()[eventPlayer.heroIndex] == Hero.SOMBRA
    @Condition eventPlayer.getAbilityCooldown(Button.ABILITY_2) > 0

    # when sombra is in stealth, we need to hide the ammo indicator above her head to not give her away.
    eventPlayer.showIndicator = false

    # things that can exit stealth before it times out.
    # TODO: hack also exits stealth, but trying to detect it is an entire project of its own.
    waitUntil(   eventPlayer.isHoldingButton(Button.PRIMARY_FIRE)
              or eventPlayer.isHoldingButton(Button.MELEE)
              or eventPlayer.isHoldingButton(Button.ABILITY_1)
              or eventPlayer.isUsingUltimate()
              or eventPlayer.hasStatusEffect(Status.STUNNED)
              or eventPlayer.hasStatusEffect(Status.ASLEEP)
              or eventPlayer.hasStatusEffect(Status.ROOTED),
              5)
    
    eventPlayer.showIndicator = true


rule "HACK: Tracer Recall Indicator":
    @Event eachPlayer
    @Condition SHOW_ENEMY_INDICATORS == true
    @Condition getAllHeroes()[eventPlayer.heroIndex] == Hero.TRACER
    @Condition eventPlayer.isUsingAbility2() == true

    # tracer briefly disappears during recall.
    eventPlayer.showIndicator = false
    waitUntil(eventPlayer.isUsingAbility2() == false, Math.INFINITY)
    eventPlayer.showIndicator = true


rule "HACK: Bastion Turret Form Indicator":
    @Event eachPlayer
    @Condition SHOW_ENEMY_INDICATORS == true
    @Condition getAllHeroes()[eventPlayer.heroIndex] == Hero.BASTION
    @Condition eventPlayer.isInAlternateForm() == true

    # bastion has infinite ammo in turret form, so displaying the out of ammo indicator is misleading.
    eventPlayer.showIndicator = false
    eventPlayer.suppressNoAmmoWarning = true
    waitUntil(eventPlayer.isInAlternateForm() == false, Math.INFINITY)
    eventPlayer.showIndicator = true
    eventPlayer.suppressNoAmmoWarning = false


rule "HACK: Suppress Out of Ammo Warning During Ult":
    @Event eachPlayer
    @Condition getAllHeroes()[eventPlayer.heroIndex] in C_HEROES_NO_WARNING_ULT
    @Condition eventPlayer.isUsingUltimate() == true

    # some heroes need to use primary fire during their ultimate. we don't want to show the "out of ammo" warning in these cases.
    eventPlayer.suppressNoAmmoWarning = true
    waitUntil(eventPlayer.isUsingUltimate() == false, Math.INFINITY)
    eventPlayer.suppressNoAmmoWarning = false
    
    
##########################
###    LIMITED AMMO    ###
##########################

# this unholy mess positions the ammo hud in the bottom-right of the viewport.
#!define HUD_NEWLINES "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
#!define HUD_SPACES_TOP "                                                                                                                                                                                                                                                                                                                                                                                                                                       "
#!define HUD_SPACES_BOTTOM "                                                                                                                                                                                                                                                                                                                        "

#!define HUD_PULSE(x) (x * sin(getTotalTimeElapsed() * 15))
#!define HUD_PULSE_RED    rgb(255, 70  + HUD_PULSE(30), 70 + HUD_PULSE(40))
#!define HUD_PULSE_ORANGE rgb(255, 190 + HUD_PULSE(15), 60 + HUD_PULSE(20))

rule "Custom Ammo HUD (Global)":
    @Event global
    # debug huds use up a lot of our text budget, so in debug mode we use a global ammo hud which saves up to 48 text entries.
    # note that this ammo hud will not display properly in replays.
    @Condition DEBUG == true

    hudSubheader(localPlayer, "{0}{1}{2}PRIMARY AMMO".format("\n\n\n" if localPlayer.AMMO_TYPE_SECONDARY == AmmoType.NONE else "", HUD_NEWLINES, HUD_SPACES_TOP), HudPosition.LEFT, 1, rgba(0, 0, 0, 0) if localPlayer.AMMO_TYPE_PRIMARY == AmmoType.NONE else [HUD_PULSE_RED, HUD_PULSE_ORANGE, rgb(221, 221, 221)][localPlayer.ammoStatePrimary], HudReeval.VISIBILITY_STRING_AND_COLOR)
    hudSubtext(localPlayer, "{0}{1} {2}fgDDDDDDAA>/ {3}".format(HUD_SPACES_BOTTOM, ceil(localPlayer.reserveAmmoPrimary), bracket, localPlayer.MAX_RESERVE_AMMO_PRIMARY), HudPosition.LEFT, 2, rgba(0, 0, 0, 0) if localPlayer.AMMO_TYPE_PRIMARY == AmmoType.NONE else [HUD_PULSE_RED, HUD_PULSE_ORANGE, Color.WHITE][localPlayer.ammoStatePrimary], HudReeval.VISIBILITY_STRING_AND_COLOR)
    
    hudSubheader(localPlayer, "\n\n{0}SECONDARY AMMO".format(HUD_SPACES_TOP), HudPosition.LEFT, 3, rgba(0, 0, 0, 0) if localPlayer.AMMO_TYPE_SECONDARY == AmmoType.NONE else [HUD_PULSE_RED, HUD_PULSE_ORANGE, rgb(221, 221, 221)][localPlayer.ammoStateSecondary], HudReeval.VISIBILITY_STRING_AND_COLOR)
    hudSubtext(localPlayer, "{0}{1} {2}fgDDDDDDAA>/ {3}".format(HUD_SPACES_BOTTOM, ceil(localPlayer.reserveAmmoSecondary), bracket, localPlayer.MAX_RESERVE_AMMO_SECONDARY), HudPosition.LEFT, 4, rgba(0, 0, 0, 0) if localPlayer.AMMO_TYPE_SECONDARY == AmmoType.NONE else [HUD_PULSE_RED, HUD_PULSE_ORANGE, Color.WHITE][localPlayer.ammoStateSecondary], HudReeval.VISIBILITY_STRING_AND_COLOR)


rule "Custom Ammo HUD Replay Padding":
    @Event global

    # when viewing a replay, the ammo hud is pushed down by the team overlay at the top of the screen.
    # these newlines will display in-game but not in replays, so the hud will be offset to the correct position.
    hudSubheader(localPlayer, "\n\n\n\n", HudPosition.LEFT, 0, Color.WHITE, HudReeval.VISIBILITY_AND_STRING, SpecVisibility.NEVER)


rule "Custom Ammo HUD (Each Player)":
    @Event eachPlayer
    # with debug mode off, we create an ammo hud per-player so we can view them in replays.
    @Condition DEBUG == false

    hudSubheader(eventPlayer, "{0}{1}{2}PRIMARY AMMO".format("\n\n\n" if eventPlayer.AMMO_TYPE_SECONDARY == AmmoType.NONE else "", HUD_NEWLINES, HUD_SPACES_TOP), HudPosition.LEFT, 1, rgba(0, 0, 0, 0) if eventPlayer.AMMO_TYPE_PRIMARY == AmmoType.NONE else [HUD_PULSE_RED, HUD_PULSE_ORANGE, rgb(221, 221, 221)][eventPlayer.ammoStatePrimary], HudReeval.VISIBILITY_STRING_AND_COLOR)
    hudSubtext(eventPlayer, "{0}{1} {2}fgDDDDDDAA>/ {3}".format(HUD_SPACES_BOTTOM, ceil(eventPlayer.reserveAmmoPrimary), bracket, eventPlayer.MAX_RESERVE_AMMO_PRIMARY), HudPosition.LEFT, 2, rgba(0, 0, 0, 0) if eventPlayer.AMMO_TYPE_PRIMARY == AmmoType.NONE else [HUD_PULSE_RED, HUD_PULSE_ORANGE, Color.WHITE][eventPlayer.ammoStatePrimary], HudReeval.VISIBILITY_STRING_AND_COLOR)
    
    hudSubheader(eventPlayer, "\n\n{0}SECONDARY AMMO".format(HUD_SPACES_TOP), HudPosition.LEFT, 3, rgba(0, 0, 0, 0) if eventPlayer.AMMO_TYPE_SECONDARY == AmmoType.NONE else [HUD_PULSE_RED, HUD_PULSE_ORANGE, rgb(221, 221, 221)][eventPlayer.ammoStateSecondary], HudReeval.VISIBILITY_STRING_AND_COLOR)
    hudSubtext(eventPlayer, "{0}{1} {2}fgDDDDDDAA>/ {3}".format(HUD_SPACES_BOTTOM, ceil(eventPlayer.reserveAmmoSecondary), bracket, eventPlayer.MAX_RESERVE_AMMO_SECONDARY), HudPosition.LEFT, 4, rgba(0, 0, 0, 0) if eventPlayer.AMMO_TYPE_SECONDARY == AmmoType.NONE else [HUD_PULSE_RED, HUD_PULSE_ORANGE, Color.WHITE][eventPlayer.ammoStateSecondary], HudReeval.VISIBILITY_STRING_AND_COLOR)


rule "Out of Ammo Indicators":
    @Event eachPlayer

    # indicator for enemies.
    if SHOW_ENEMY_INDICATORS:
        createInWorldText(getPlayers(getOppositeTeam(eventPlayer.getTeam())) if eventPlayer.isAlive() and eventPlayer.showIndicator and ((eventPlayer.AMMO_TYPE_PRIMARY != AmmoType.NONE or eventPlayer.AMMO_TYPE_SECONDARY != AmmoType.NONE) and eventPlayer.ammoStatePrimary == AmmoState.EMPTY and eventPlayer.ammoStateSecondary == AmmoState.EMPTY) else null, "×", eventPlayer, 2, Clip.SURFACES, WorldTextReeval.VISIBILITY_POSITION_AND_STRING, rgb(255, 59, 103), SpecVisibility.DEFAULT)

    # indicator for teammates / spectators / replays.
    createInWorldText(getPlayers(eventPlayer.getTeam()), "" if not (eventPlayer.isAlive() and ((eventPlayer.AMMO_TYPE_PRIMARY != AmmoType.NONE and eventPlayer.ammoStatePrimary != AmmoState.HIGH) or (eventPlayer.AMMO_TYPE_SECONDARY != AmmoType.NONE and eventPlayer.ammoStateSecondary != AmmoState.HIGH))) else "×" if eventPlayer.ammoStatePrimary == AmmoState.EMPTY and eventPlayer.ammoStateSecondary == AmmoState.EMPTY else "!", eventPlayer, 2, Clip.NONE, WorldTextReeval.VISIBILITY_POSITION_STRING_AND_COLOR, Color.WHITE if eventPlayer.ammoStatePrimary == AmmoState.EMPTY and eventPlayer.ammoStateSecondary == AmmoState.EMPTY else rgb(255, 200, 60), SpecVisibility.ALWAYS)


rule "Player Changed Hero":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    
    resetPlayerState()
    eventPlayer.wasDuplicating = false
    updateHeroIndex()
    cacheAmmoData()
    refillReserveAmmo()
    
    # re-fire rule when the player changes hero.
    waitUntil(eventPlayer.getCurrentHero() != evalOnce(eventPlayer.getCurrentHero()), Math.INFINITY)

    goto RULE_START


rule "Primary Ammo is Empty":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.AMMO_TYPE_PRIMARY == AmmoType.NONE or (eventPlayer.reserveAmmoPrimary <= 0 and eventPlayer.getAmmo(0) <= 0)

    eventPlayer.ammoStatePrimary = AmmoState.EMPTY


rule "Primary Ammo is Low":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.AMMO_TYPE_PRIMARY != AmmoType.NONE
    @Condition eventPlayer.reserveAmmoPrimary + eventPlayer.getAmmo(0) > 0
    # TODO: should the low ammo threshold count max clip size + max reserve size?
    @Condition eventPlayer.reserveAmmoPrimary + eventPlayer.getAmmo(0) <= eventPlayer.MAX_RESERVE_AMMO_PRIMARY * LOW_AMMO_THRESHOLD

    eventPlayer.ammoStatePrimary = AmmoState.LOW


rule "Primary Ammo is High":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.AMMO_TYPE_PRIMARY != AmmoType.NONE
    @Condition eventPlayer.reserveAmmoPrimary + eventPlayer.getAmmo(0) > eventPlayer.MAX_RESERVE_AMMO_PRIMARY * LOW_AMMO_THRESHOLD

    eventPlayer.ammoStatePrimary = AmmoState.HIGH


rule "Secondary Ammo is Empty":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.AMMO_TYPE_SECONDARY == AmmoType.NONE or (eventPlayer.reserveAmmoSecondary <= 0 and eventPlayer.getAmmo(1) <= 0)

    eventPlayer.ammoStateSecondary = AmmoState.EMPTY


rule "Secondary Ammo is Low":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.AMMO_TYPE_SECONDARY != AmmoType.NONE
    @Condition eventPlayer.reserveAmmoSecondary + eventPlayer.getAmmo(1) > 0
    @Condition eventPlayer.reserveAmmoSecondary + eventPlayer.getAmmo(1) <= eventPlayer.MAX_RESERVE_AMMO_SECONDARY * LOW_AMMO_THRESHOLD

    eventPlayer.ammoStateSecondary = AmmoState.LOW


rule "Secondary Ammo is High":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.AMMO_TYPE_SECONDARY != AmmoType.NONE
    @Condition eventPlayer.reserveAmmoSecondary + eventPlayer.getAmmo(1) > eventPlayer.MAX_RESERVE_AMMO_SECONDARY * LOW_AMMO_THRESHOLD

    eventPlayer.ammoStateSecondary = AmmoState.HIGH


rule "Forget Cached Ammo on Death":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.isAlive() == false

    # dying and respawning causes an unnatural change in current ammo,
    # so we want the next execution of the ammo manager to begin in a clean, new state.
    eventPlayer.cachedAmmoPrimary = -1
    eventPlayer.cachedAmmoSecondary = -1


rule "Ammo Manager (Primary)":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.AMMO_TYPE_PRIMARY == AmmoType.CLIP
    @Condition eventPlayer.isAlive() == true
    @Condition eventPlayer.pauseAmmoManager == false
    @Condition eventPlayer.getAmmo(0) != eventPlayer.cachedAmmoPrimary

    # ensure our ammo is cached first.
    if eventPlayer.cachedAmmoPrimary != -1:

        # if the player's ammo increased, deplete from reserve ammo.
        if eventPlayer.getAmmo(0) > eventPlayer.cachedAmmoPrimary:

            eventPlayer.reserveAmmoPrimary -= eventPlayer.getAmmo(0) - eventPlayer.cachedAmmoPrimary

            # we're out of reserve ammo.
            if eventPlayer.reserveAmmoPrimary <= 0:

                # HACKHACK: don't let symmetra retain infinite ammo by beaming shields.
                if eventPlayer.heroIndex == getAllHeroes().index(Hero.SYMMETRA) and eventPlayer.isFiringPrimaryFire():
                    eventPlayer.reserveAmmoPrimary *= 3 # depletes 100 ammo in 10 seconds, the same as vanilla OW.

                # trim negative reserve ammo off the new clip since we can't afford it.
                eventPlayer.setAmmo(0, eventPlayer.getAmmo(0) + eventPlayer.reserveAmmoPrimary)
                eventPlayer.reserveAmmoPrimary = 0

        else:

            if LOG_STATS and isGameInProgress():
                stats_AmmoConsumed[eventPlayer.heroIndex] += eventPlayer.cachedAmmoPrimary - eventPlayer.getAmmo(0)

    # cache new ammo amount.
    eventPlayer.cachedAmmoPrimary = eventPlayer.getAmmo(0)

    # wait and loop actions are required to handle continuous ammo depletion.
    wait()
    if RULE_CONDITION: goto RULE_START


rule "Ammo Manager (Secondary)":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.AMMO_TYPE_SECONDARY == AmmoType.CLIP
    @Condition eventPlayer.isAlive() == true
    @Condition eventPlayer.pauseAmmoManager == false
    @Condition eventPlayer.getAmmo(1) != eventPlayer.cachedAmmoSecondary

    # ensure our ammo is cached first.
    if eventPlayer.cachedAmmoSecondary != -1:

        # if the player's ammo increased, deplete from reserve ammo.
        if eventPlayer.getAmmo(1) > eventPlayer.cachedAmmoSecondary:

            eventPlayer.reserveAmmoSecondary -= eventPlayer.getAmmo(1) - eventPlayer.cachedAmmoSecondary

            # we're out of reserve ammo.
            if eventPlayer.reserveAmmoSecondary < 0:

                # trim negative reserve ammo off the new clip since we can't afford it.
                eventPlayer.setAmmo(1, eventPlayer.getAmmo(1) + eventPlayer.reserveAmmoSecondary)
                eventPlayer.reserveAmmoSecondary = 0

        else:

            if LOG_STATS and isGameInProgress():
                stats_AmmoConsumed[eventPlayer.heroIndex] += eventPlayer.cachedAmmoSecondary - eventPlayer.getAmmo(1)

    # cache new ammo amount.
    eventPlayer.cachedAmmoSecondary = eventPlayer.getAmmo(1)

    # wait and loop actions are required to handle continuous ammo depletion.
    wait()
    if RULE_CONDITION: goto RULE_START


rule "Custom Ammo Manager (Hanzo)":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition getAllHeroes()[eventPlayer.heroIndex] == Hero.HANZO
    @Condition eventPlayer.isAlive() == true
    @Condition eventPlayer.isFiringPrimaryFire() == true

    # storm arrows fire instantly, so count them instantly.
    if eventPlayer.isUsingAbility2() == true:

        eventPlayer.reserveAmmoPrimary -= 1
        if LOG_STATS and isGameInProgress():
            stats_AmmoConsumed[eventPlayer.heroIndex] += 1

    # when hanzo stops drawing back his bow, we assume he fired an arrow (with exceptions).
    else:

        waitUntil(eventPlayer.isFiringPrimaryFire() == false, Math.INFINITY)
        if not (   eventPlayer.isDead()
                or (eventPlayer.antiHanzoCheese == false and eventPlayer.isHoldingButton(Button.SECONDARY_FIRE))
                or eventPlayer.isMeleeing()
                or (eventPlayer.getAbilityCooldown(Button.ABILITY_2) <= 0 and eventPlayer.isHoldingButton(Button.ABILITY_2))
                or eventPlayer.isOnWall()
                or eventPlayer.isUsingUltimate()
                or eventPlayer.hasStatusEffect(Status.STUNNED)
                or eventPlayer.hasStatusEffect(Status.ASLEEP)):

            eventPlayer.reserveAmmoPrimary -= 1
            if LOG_STATS and isGameInProgress():
                stats_AmmoConsumed[eventPlayer.heroIndex] += 1


rule "Custom Ammo Manager (Sigma)":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition getAllHeroes()[eventPlayer.heroIndex] == Hero.SIGMA
    @Condition eventPlayer.isAlive() == true
    @Condition eventPlayer.isFiringPrimaryFire() == true

    #!define SIGMA_FIRE_INTERVAL 0.176

    # sigma uses 2 ammo per shot, but we only deplete the second ammo if nothing has cancelled primary fire.
    eventPlayer.reserveAmmoPrimary -= 1
    if LOG_STATS and isGameInProgress():
        stats_AmmoConsumed[eventPlayer.heroIndex] += 1

    wait(SIGMA_FIRE_INTERVAL)

    if not (   eventPlayer.isDead()
            or eventPlayer.isMeleeing()
            or eventPlayer.isUsingAbility1()
            or eventPlayer.isUsingAbility2()
            or eventPlayer.isUsingUltimate() # BUGBUG: only depletes 1 when firing post-ult.
            or eventPlayer.hasStatusEffect(Status.STUNNED)
            or eventPlayer.hasStatusEffect(Status.ASLEEP)):

        eventPlayer.reserveAmmoPrimary -= 1
        if LOG_STATS and isGameInProgress():
            stats_AmmoConsumed[eventPlayer.heroIndex] += 1
    
            
rule "Custom Ammo Manager (D.Va)":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition getAllHeroes()[eventPlayer.heroIndex] == Hero.DVA
    @Condition eventPlayer.AMMO_TYPE_PRIMARY == AmmoType.CUSTOM
    @Condition eventPlayer.isAlive() == true
    @Condition eventPlayer.reserveAmmoPrimary > 0
    @Condition eventPlayer.isFiringPrimaryFire() == true

    #!define DVA_FIRE_RATE 0.15

    eventPlayer.reserveAmmoPrimary -= 1

    if LOG_STATS and isGameInProgress():
        stats_AmmoConsumed[eventPlayer.heroIndex] += 1

    wait(DVA_FIRE_RATE)
    if RULE_CONDITION: goto RULE_START

    
rule "Custom Ammo Manager (Orisa)":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition getAllHeroes()[eventPlayer.heroIndex] == Hero.ORISA
    @Condition eventPlayer.isAlive() == true
    @Condition eventPlayer.reserveAmmoPrimary > 0
    @Condition eventPlayer.isFiringPrimaryFire() == true

    #!define ORISA_FIRE_RATE 0.1

    eventPlayer.reserveAmmoPrimary -= 1

    if LOG_STATS and isGameInProgress():
        stats_AmmoConsumed[eventPlayer.heroIndex] += 1

    # we early-out if primary fire is released to sync up with the weapon firing bullets.
    waitUntil(eventPlayer.isFiringPrimaryFire() == false, ORISA_FIRE_RATE)
    if RULE_CONDITION: goto RULE_START

    
rule "Custom Ammo Manager (Moira)":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition getAllHeroes()[eventPlayer.heroIndex] == Hero.MOIRA
    @Condition eventPlayer.isAlive() == true
    @Condition eventPlayer.reserveAmmoSecondary > 0
    @Condition eventPlayer.isFiringSecondaryFire() == true

    # ever since her release, moira has had an exploit allowing her to quickly recharge healing by spamming right click.
    # if this custom fire rate seems odd, it's tuned to use roughly the same amount of ammo with and without this exploit.
    #!define MOIRA_FIRE_RATE 0.33

    eventPlayer.reserveAmmoSecondary -= 1

    if LOG_STATS and isGameInProgress():
        stats_AmmoConsumed[eventPlayer.heroIndex] += 1

    # we early-out if secondary fire is released to prevent the aforementioned exploit.
    waitUntil(eventPlayer.isFiringSecondaryFire() == false, MOIRA_FIRE_RATE)
    if RULE_CONDITION: goto RULE_START


rule "Disable Weapon (Primary)":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.AMMO_TYPE_PRIMARY == AmmoType.CUSTOM
    @Condition eventPlayer.reserveAmmoPrimary <= 0

    eventPlayer.disallowButton(Button.PRIMARY_FIRE)


rule "Enable Weapon (Primary)":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.AMMO_TYPE_PRIMARY == AmmoType.CUSTOM
    @Condition eventPlayer.reserveAmmoPrimary > 0

    # BUGBUG: cannot fire weapon when holding the button while gaining ammo.
    eventPlayer.allowButton(Button.PRIMARY_FIRE)


rule "Disable Weapon (Secondary)":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.AMMO_TYPE_SECONDARY == AmmoType.CUSTOM
    @Condition eventPlayer.reserveAmmoSecondary <= 0

    eventPlayer.disallowButton(Button.SECONDARY_FIRE)


rule "Enable Weapon (Secondary)":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.AMMO_TYPE_SECONDARY == AmmoType.CUSTOM
    @Condition eventPlayer.reserveAmmoSecondary > 0

    # BUGBUG: cannot fire weapon when holding the button while gaining ammo.
    eventPlayer.allowButton(Button.SECONDARY_FIRE)


rule "Disable Reload (Single Ammo Weapon)":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.AMMO_TYPE_PRIMARY == AmmoType.CLIP
    @Condition eventPlayer.AMMO_TYPE_SECONDARY == AmmoType.NONE
    @Condition eventPlayer.reserveAmmoPrimary <= 0

    eventPlayer.disallowButton(Button.RELOAD)

    # instantly disabling reload cancels the reload animation, which causes ugly viewmodel teleporting.
    # we wait a bit to fully disable reload except for heroes where it must happen instantly.
    if getAllHeroes()[eventPlayer.heroIndex] not in C_HEROES_QUICK_DISABLE_RELOAD:
        wait(1, Wait.ABORT_WHEN_FALSE)

    eventPlayer.setReloadEnabled(false)


rule "Enable Reload (Single Ammo Weapon)":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.AMMO_TYPE_PRIMARY == AmmoType.CLIP
    @Condition eventPlayer.AMMO_TYPE_SECONDARY == AmmoType.NONE
    @Condition eventPlayer.reserveAmmoPrimary > 0

    eventPlayer.allowButton(Button.RELOAD)
    eventPlayer.setReloadEnabled(true)


rule "Disable Reload (Dual Ammo Weapon)":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.AMMO_TYPE_PRIMARY == AmmoType.CLIP
    @Condition eventPlayer.AMMO_TYPE_SECONDARY == AmmoType.CLIP
    @Condition eventPlayer.reserveAmmoPrimary <= 0 or eventPlayer.getAmmo(0) >= eventPlayer.getMaxAmmo(0) 
    @Condition eventPlayer.reserveAmmoSecondary <= 0 or eventPlayer.getAmmo(1) >= eventPlayer.getMaxAmmo(1)

    eventPlayer.disallowButton(Button.RELOAD)
    eventPlayer.setReloadEnabled(false)


rule "Auto Reload (Dual Ammo Weapon)":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.AMMO_TYPE_PRIMARY == AmmoType.CLIP
    @Condition eventPlayer.AMMO_TYPE_SECONDARY == AmmoType.CLIP
    @Condition ((eventPlayer.reserveAmmoPrimary > 0 and eventPlayer.getAmmo(0) <= 0) 
             or (eventPlayer.reserveAmmoSecondary > 0 and eventPlayer.getAmmo(1) <= 0))

    # auto-reload only if we have reserve ammo for an empty clip.
    eventPlayer.allowButton(Button.RELOAD)
    eventPlayer.setReloadEnabled(true)


rule "Manual Reload (Dual Ammo Weapon)":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.AMMO_TYPE_PRIMARY == AmmoType.CLIP
    @Condition eventPlayer.AMMO_TYPE_SECONDARY == AmmoType.CLIP
    @Condition ((eventPlayer.reserveAmmoPrimary > 0 and eventPlayer.getAmmo(0) < eventPlayer.getMaxAmmo(0)) 
             or (eventPlayer.reserveAmmoSecondary > 0 and eventPlayer.getAmmo(1) < eventPlayer.getMaxAmmo(1)))
    @Condition eventPlayer.isHoldingButton(Button.RELOAD) == true

    # reloading is usually disabled, so we intercept the player's reload key to actually perform a reload.
    eventPlayer.allowButton(Button.RELOAD)
    eventPlayer.setReloadEnabled(true)
    eventPlayer.forceButtonPress(Button.RELOAD)


rule "Negative Ammo Failsafe (Primary)":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.reserveAmmoPrimary < 0

    eventPlayer.reserveAmmoPrimary = 0


rule "Negative Ammo Failsafe (Secondary)":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.reserveAmmoSecondary < 0

    eventPlayer.reserveAmmoSecondary = 0


rule "No Ammo Warning (Primary)":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.AMMO_TYPE_PRIMARY != AmmoType.NONE
    @Condition eventPlayer.isAlive() == true
    @Condition eventPlayer.ammoStatePrimary == AmmoState.EMPTY
    @Condition eventPlayer.suppressNoAmmoWarning == false
    @Condition eventPlayer.isHoldingButton(Button.PRIMARY_FIRE) == true or (eventPlayer.HAS_ALT_FIRE == true and eventPlayer.isHoldingButton(Button.SECONDARY_FIRE))

    playEffect(eventPlayer, DynamicEffect.DEBUFF_IMPACT_SOUND, Color.WHITE, eventPlayer, 100)
    smallMessage(eventPlayer, "  {0} OUT OF AMMO".format(abilityIconString(getAllHeroes()[eventPlayer.heroIndex], Button.PRIMARY_FIRE)))
    wait(3)


rule "No Ammo Warning (Secondary)":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.AMMO_TYPE_SECONDARY != AmmoType.NONE
    @Condition eventPlayer.isAlive() == true
    @Condition eventPlayer.ammoStateSecondary == AmmoState.EMPTY
    @Condition eventPlayer.suppressNoAmmoWarning == false
    @Condition eventPlayer.isHoldingButton(Button.SECONDARY_FIRE) == true

    playEffect(eventPlayer, DynamicEffect.DEBUFF_IMPACT_SOUND, Color.WHITE, eventPlayer, 100)
    smallMessage(eventPlayer, "  {0} OUT OF AMMO".format(abilityIconString(getAllHeroes()[eventPlayer.heroIndex], Button.SECONDARY_FIRE)))
    wait(3)


rule "Give Ammo: Player Touched Ammo Pack":
    @Event eachPlayer
    @Condition AMMO_PACK_POSITIONS == true
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.isAlive() == true
    @Condition eventPlayer.canCollectPacks == true
    @Condition eventPlayer.reserveAmmoPrimary < eventPlayer.MAX_RESERVE_AMMO_PRIMARY or eventPlayer.reserveAmmoSecondary < eventPlayer.MAX_RESERVE_AMMO_SECONDARY
    @Condition any([distance(eventPlayer.getPosition(), pack) < AMMO_PACK_COLLECTION_RADIUS for pack in AMMO_PACK_POSITIONS])

    # logically, the ammo pack that was touched must be the one closest to the player,
    # so here we sort all ammo packs by distance and store the nearest pack's index.
    eventPlayer.touchedPackIndex = AMMO_PACK_POSITIONS.index(sorted(AMMO_PACK_POSITIONS, lambda pack: distance(eventPlayer.getPosition(), pack))[0])

    # only allow the player to collect the ammo pack if its cooldown has expired.
    if getTotalTimeElapsed() > AMMO_PACK_TIMESTAMPS[eventPlayer.touchedPackIndex] + AMMO_PACK_RESPAWN_TIME:

        AMMO_PACK_TIMESTAMPS[eventPlayer.touchedPackIndex] = getTotalTimeElapsed()
        givePlayerAmmo()

        if LOG_STATS and isGameInProgress():
            stats_AmmoPacksCollected[eventPlayer.heroIndex]++
        

rule "Give Ammo: Player is in Spawn Room":
    @Event eachPlayer
    @Condition eventPlayer.isInSpawnRoom() == true
    @Condition eventPlayer.reserveAmmoPrimary < eventPlayer.MAX_RESERVE_AMMO_PRIMARY or eventPlayer.reserveAmmoSecondary < eventPlayer.MAX_RESERVE_AMMO_SECONDARY
    
    givePlayerAmmo()
    wait(1)
    if RULE_CONDITION: goto RULE_START


rule "Give Ammo: Player Respawned":
    @Event eachPlayer
    # this also fires when revived by mercy.
    @Condition eventPlayer.isAlive() == true

    refillReserveAmmo()


########################
###    STATISTICS    ###
########################

rule "STATISTICS: Player Joined":
    @Event playerJoined
    @Condition LOG_STATS == true
    @Condition isMatchComplete() == false

    # allow player variables to initialize before continuing.
    wait(0.064)

    # we need this player's absolute slot between 0 and 11.
    eventPlayer.SLOT_INDEX = eventPlayer.getSlot() + (C_MAX_SLOTS_PER_TEAM if eventPlayer.getTeam() == Team.2 else 0)

    g_PlayerIsInSlot[eventPlayer.SLOT_INDEX] = true
    g_PlayerEntities[eventPlayer.SLOT_INDEX] = eventPlayer
    g_PlayerHeroIndices[eventPlayer.SLOT_INDEX] = -1


rule "STATISTICS: Player Disconnected, Save Stats":
    @Event playerLeft
    @Condition LOG_STATS == true
    @Condition isMatchComplete() == false

    # we can't directly detect which player left, so loop through the global entity array to see who's missing.
    for s in range(0, C_MAX_SLOTS_PER_TEAM * 2):

        if g_PlayerIsInSlot[s] == true and entityExists(g_PlayerEntities[s]) == false:

            # this player has left, commit duration stats.
            if g_PlayerHeroIndices[s] != -1:
                if g_TimestampsPlaytime[s] > 0: stats_DurationPlaytime[g_PlayerHeroIndices[s]] += getTotalTimeElapsed() - g_TimestampsPlaytime[s]
                if g_TimestampsAlive[s] > 0: stats_DurationAlive[g_PlayerHeroIndices[s]] += getTotalTimeElapsed() - g_TimestampsAlive[s]
                if g_TimestampsOutOfAmmo[s] > 0: stats_DurationOutOfAmmo[g_PlayerHeroIndices[s]] += getTotalTimeElapsed() - g_TimestampsOutOfAmmo[s]

            stats_Highlights.append("[{0}] {1} (slot {2}) left the game with heroIndex {3} ({4} | {5} • {6} • {7})".format(toTimestamp(stats_ReplayDuration), g_PlayerEntities[s], s, g_PlayerHeroIndices[s], getTotalTimeElapsed(), g_TimestampsPlaytime[s], g_TimestampsAlive[s], g_TimestampsOutOfAmmo[s]))

            # this slot is now vacant.
            g_PlayerIsInSlot[s] = false
            g_TimestampsPlaytime[s] = 0
            g_TimestampsAlive[s] = 0
            g_TimestampsOutOfAmmo[s] = 0

            # we found them, so we're done!
            return


rule "STATISTICS: Replay Duration":
    @Event global
    @Condition LOG_STATS == true
    @Condition isInSetup() == true

    # time elapsed since the server began recording the replay.
    chase(stats_ReplayDuration, Math.INFINITY, rate=1, ChaseReeval.NONE)


rule "STATISTICS: Match Duration Resume":
    @Event global
    @Condition LOG_STATS == true
    @Condition isGameInProgress() == true

    chase(stats_MatchDuration, Math.INFINITY, rate=1, ChaseReeval.NONE)


rule "STATISTICS: Match Duration Pause":
    @Event global
    @Condition LOG_STATS == true
    @Condition isGameInProgress() == false

    stopChasingVariable(stats_MatchDuration)


rule "STATISTICS: Commit All Timestamps Between Rounds":
    @Event eachPlayer
    @Condition LOG_STATS == true
    @Condition eventPlayer.hasSpawned() == true
    @Condition isGameInProgress() == false

    commitDurationPlaytime()
    commitDurationAlive()
    commitDurationOutOfAmmo()


rule "STATISTICS: Set Timestamp: Hero Playtime":
    @Event eachPlayer
    @Condition LOG_STATS == true
    @Condition eventPlayer.hasSpawned() == true
    @Condition isGameInProgress() == true

    g_TimestampsPlaytime[eventPlayer.SLOT_INDEX] = getTotalTimeElapsed()


rule "STATISTICS: Set Timestamp: Alive":
    @Event eachPlayer
    @Condition LOG_STATS == true
    @Condition eventPlayer.hasSpawned() == true
    @Condition isGameInProgress() == true
    @Condition eventPlayer.isAlive() == true

    g_TimestampsAlive[eventPlayer.SLOT_INDEX] = getTotalTimeElapsed()


rule "STATISTICS: Set Timestamp: Out of Ammo":
    @Event eachPlayer
    @Condition LOG_STATS == true
    @Condition eventPlayer.hasSpawned() == true
    @Condition isGameInProgress() == true
    # we only care about heroes who can have ammo.
    @Condition eventPlayer.AMMO_TYPE_PRIMARY != AmmoType.NONE or eventPlayer.AMMO_TYPE_SECONDARY != AmmoType.NONE
    @Condition eventPlayer.ammoStatePrimary == AmmoState.EMPTY
    @Condition eventPlayer.ammoStateSecondary == AmmoState.EMPTY

    g_TimestampsOutOfAmmo[eventPlayer.SLOT_INDEX] = getTotalTimeElapsed()


rule "STATISTICS: Commit Timestamp: Out of Ammo":
    @Event eachPlayer
    @Condition LOG_STATS == true
    @Condition eventPlayer.hasSpawned() == true
    @Condition isGameInProgress() == true
    @Condition eventPlayer.ammoStatePrimary != AmmoState.EMPTY or eventPlayer.ammoStateSecondary != AmmoState.EMPTY

    commitDurationOutOfAmmo()


rule "STATISTICS: Player Is Reloading":
    @Event eachPlayer
    @Condition LOG_STATS == true
    @Condition isGameInProgress() == true
    @Condition eventPlayer.isReloading() == true

    stats_TimesReloaded[eventPlayer.heroIndex]++


rule "STATISTICS: Player Earned Kill":
    @Event playerDealtFinalBlow
    @Condition LOG_STATS == true
    @Condition isGameInProgress() == true
    @Condition attacker.heroIndex != -1

    stats_Kills[attacker.heroIndex]++

    # the player earned this kill while out of ammo.
    if g_TimestampsOutOfAmmo[attacker.SLOT_INDEX] > 0:

        stats_KillsOutOfAmmo[attacker.heroIndex]++

        stats_Highlights.append("[{0}] {1} ({2}) killed {3} ({4}) while out of ammo for {5} seconds.".format(toTimestamp(stats_ReplayDuration),
                                                                                                             attacker,
                                                                                                             getAllHeroes()[attacker.heroIndex],
                                                                                                             victim,
                                                                                                             getAllHeroes()[victim.heroIndex],
                                                                                                             getTotalTimeElapsed() - g_TimestampsOutOfAmmo[attacker.SLOT_INDEX]))


rule "STATISTICS: Player Died":
    # we can't use the "Player Died" event because it fires for rip-tires, lol.
    @Event eachPlayer
    @Condition LOG_STATS == true
    @Condition eventPlayer.hasSpawned() == true
    @Condition isGameInProgress() == true
    @Condition eventPlayer.heroIndex != -1
    @Condition eventPlayer.isAlive() == false

    stats_Deaths[eventPlayer.heroIndex]++

    # the player died while out of ammo.
    if g_TimestampsOutOfAmmo[eventPlayer.SLOT_INDEX] > 0:

        stats_DeathsOutOfAmmo[eventPlayer.heroIndex]++

        stats_Highlights.append("[{0}] {1} ({2}) died while out of ammo for {3} seconds.".format(toTimestamp(stats_ReplayDuration),
                                                                                                 eventPlayer,
                                                                                                 getAllHeroes()[eventPlayer.heroIndex],
                                                                                                 getTotalTimeElapsed() - g_TimestampsOutOfAmmo[eventPlayer.SLOT_INDEX]))

    # out of ammo duration will be compared to alive duration, so both are committed on death.
    commitDurationAlive()
    commitDurationOutOfAmmo()


rule "STATISTICS: Soldier Out of Ammo During Ult":
    @Event eachPlayer
    @Condition LOG_STATS == true
    @Condition eventPlayer.hasSpawned() == true
    @Condition getAllHeroes()[eventPlayer.heroIndex] == Hero.SOLDIER
    @Condition isGameInProgress() == true
    @Condition g_TimestampsOutOfAmmo[eventPlayer.SLOT_INDEX] > 0
    @Condition eventPlayer.isUsingUltimate() == true

    stats_Highlights.append("[{0}] {1} ({2}) ran out of ammo while using tactical visor.".format(toTimestamp(stats_ReplayDuration),
                                                                                                 eventPlayer,
                                                                                                 getAllHeroes()[eventPlayer.heroIndex]))


rule "STATISTICS: Write Stats to Log File":
    @Event global
    @Condition LOG_STATS == true
    @Condition isMatchComplete() == true

    wait(0.25)
    enableInspector()
    
    printLog("—————————————————————————————————————————————————\n")

    printLog("LIMITED AMMO PLAYTEST RESULTS\n")

    printLog("—————————————————————————————————————————————————\n")

    printLog("Session: Playtest 04\n")

    printLog("Gamemode: {0}".format(getCurrentGamemode()))
    printLog("Map: {0}".format(getCurrentMap()))
    printLog("Match Duration: {0}".format(stats_MatchDuration))
    printLog("Replay Duration: {0}\n".format(toTimestamp(stats_ReplayDuration)))

    printLog("—————————————————————————————————————————————————\n")

    # build strings from arrays.
    #!define printArray(array, length) str = "["\
    for i in range(0, length):\
        str = "{0}{1}{2}".format(str, "" if i == 0 else ", ", array[i])\
    str = "{0}]".format(str)\
    printLog("array = {0}\n".format(str))\
    wait()
    
    printArray(C_HEROES_DISABLED, len(C_HEROES_DISABLED))
    printArray(getAllHeroes(), len(getAllHeroes()))

    printArray(stats_DurationPlaytime, len(getAllHeroes()))
    printArray(stats_DurationAlive, len(getAllHeroes()))
    printArray(stats_DurationOutOfAmmo, len(getAllHeroes()))
    printArray(stats_AmmoConsumed, len(getAllHeroes()))
    printArray(stats_TimesReloaded, len(getAllHeroes()))
    printArray(stats_AmmoPacksCollected, len(getAllHeroes()))
    printArray(stats_Kills, len(getAllHeroes()))
    printArray(stats_KillsOutOfAmmo, len(getAllHeroes()))
    printArray(stats_Deaths, len(getAllHeroes()))
    printArray(stats_DeathsOutOfAmmo, len(getAllHeroes()))

    if stats_Highlights:

        printLog("—————————————————————————————————————————————————\n")

        printLog("Highlights:\n")

        for i in range(0, len(stats_Highlights)):
            printLog(stats_Highlights[i])
            wait()


###################
###    DEBUG    ###
###################

rule "DEBUG: Server Load":
    @Event global
    @Condition DEBUG == true

    hudSubheader(localPlayer, "CURRENT LOAD: {0}fgFFFFFFFF>{1}%{2}".format(bracket, updateEveryTick(getServerLoad()), Math.LOTS_OF_SPACES), HudPosition.TOP, 10, rgb(255, 170, 120), HudReeval.VISIBILITY_AND_STRING)
    hudSubheader(localPlayer, "AVERAGE LOAD: {0}fgFFFFFFFF>{1}%{2}".format(bracket, updateEveryTick(getAverageServerLoad()), Math.LOTS_OF_SPACES), HudPosition.TOP, 10, rgb(255, 190, 110), HudReeval.VISIBILITY_AND_STRING)
    hudSubheader(localPlayer, "PEAK LOAD: {0}fgFFFFFFFF>{1}%\n{2}".format(bracket, updateEveryTick(getPeakServerLoad()), Math.LOTS_OF_SPACES), HudPosition.TOP, 10, rgb(255, 210, 100), HudReeval.VISIBILITY_AND_STRING)


rule "DEBUG: Display g_ Arrays":
    @Event global
    @Condition DEBUG == true
    @Condition LOG_STATS == true
    
    wait(5)

    for d in range(0, C_MAX_SLOTS_PER_TEAM * 2):
        hudSubheader(localPlayer, "[{0}] {1} | {2}".format(evalOnce(d), g_PlayerEntities[evalOnce(d)], g_PlayerHeroIndices[evalOnce(d)]), HudPosition.RIGHT, -10, rgb(210, 210, 210) if g_PlayerEntities[evalOnce(d)] == null else Color.TURQUOISE if entityExists(g_PlayerEntities[evalOnce(d)]) else rgb(255, 110, 130), HudReeval.VISIBILITY_STRING_AND_COLOR)


rule "DEBUG: Display Durations":
    @Event global
    @Condition DEBUG == true
    @Condition LOG_STATS == true

    hudSubheader(localPlayer, "Duration Playtime: {0}fgFFFFFFFF>{1}".format(bracket, (getTotalTimeElapsed() - g_TimestampsPlaytime[localPlayer.SLOT_INDEX]) if g_TimestampsPlaytime[localPlayer.SLOT_INDEX] > 0 else 0), HudPosition.RIGHT, -30, rgb(210, 210, 210), HudReeval.VISIBILITY_AND_STRING)
    hudSubheader(localPlayer, "Duration Alive: {0}fgFFFFFFFF>{1}".format(bracket, (getTotalTimeElapsed() - g_TimestampsAlive[localPlayer.SLOT_INDEX]) if g_TimestampsAlive[localPlayer.SLOT_INDEX] > 0 else 0), HudPosition.RIGHT, -30, rgb(210, 210, 210), HudReeval.VISIBILITY_AND_STRING)
    hudSubheader(localPlayer, "Duration Out of Ammo: {0}fgFFFFFFFF>{1}\n".format(bracket, (getTotalTimeElapsed() - g_TimestampsOutOfAmmo[localPlayer.SLOT_INDEX]) if g_TimestampsOutOfAmmo[localPlayer.SLOT_INDEX] > 0 else 0), HudPosition.RIGHT, -30, rgb(210, 210, 210), HudReeval.VISIBILITY_AND_STRING)


rule "DEBUG: Text & Effect Limits":
    @Event global
    @Condition DEBUG == true

    hudSubheader(localPlayer, "Text Count: {0}fgFFFFFFFF>{1} / {2}".format(bracket, getNumberOfTextIds(), DEBUG_TEXT_LIMIT), HudPosition.RIGHT, -60, HUD_PULSE_RED if getNumberOfTextIds() > DEBUG_TEXT_LIMIT else rgb(90, 190, 255), HudReeval.VISIBILITY_STRING_AND_COLOR)
    hudSubheader(localPlayer, "Effect Count: {0}fgFFFFFFFF>{1} / {2}\n".format(bracket, getNumberOfEntityIds(), DEBUG_EFFECT_LIMIT), HudPosition.RIGHT, -60, HUD_PULSE_RED if getNumberOfTextIds() > DEBUG_TEXT_LIMIT else rgb(70, 210, 255), HudReeval.VISIBILITY_STRING_AND_COLOR)

    
rule "DEBUG: Exceeded Text Limit":
    @Event global
    @Condition getNumberOfTextIds() > DEBUG_TEXT_LIMIT

    bigMessage(getAllPlayers(), "{0}fgFF4455FF>ERROR: {0}fgFFFFFFFF>Exceeded Text Limit ({1}/{2})".format(bracket, getNumberOfTextIds(), DEBUG_TEXT_LIMIT))
    if DEBUG: printLog("[{0}] ERROR: Exceeded Text Limit ({0}/{1})".format(toTimestamp(stats_ReplayDuration), getNumberOfTextIds(), DEBUG_TEXT_LIMIT))


rule "DEBUG: Exceeded Effect Limit":
    @Event global
    @Condition getNumberOfEntityIds() > DEBUG_EFFECT_LIMIT

    bigMessage(getAllPlayers(), "{0}fgFF4455FF>ERROR: {0}fgFFFFFFFF>Exceeded Effect Limit ({0}/{1})".format(bracket, getNumberOfEntityIds(), DEBUG_EFFECT_LIMIT))
    if DEBUG: printLog("[{0}] ERROR: Exceeded Effect Limit ({0}/{1})".format(toTimestamp(stats_ReplayDuration), getNumberOfEntityIds(), DEBUG_EFFECT_LIMIT))


rule "DEBUG: Cycle Control Round":
    @Event global
    @Condition DEBUG == true
    @Condition C_IS_CONTROL == true
    @Condition hostPlayer.isHoldingButton(Button.INTERACT) == true

    declareRoundVictory(hostPlayer.getTeam())
    wait()
    setTeamScore(hostPlayer.getTeam(), 0)


############################
###    AMMO PACK DATA    ###
############################

# Ammo Pack Editor import code: HGTEH

rule "AMMO PACKS: Blizzard World":
    @Event global
    @Condition getCurrentMap() == Map.BLIZZ_WORLD or getCurrentMap() == Map.BLIZZ_WORLD_WINTER

    C_AMMO_PACKS = [
        vect(-8.34, 0.00, 29.98),
        vect(24.61, 0.01, 40.35),
        vect(-19.68, -5.10, 12.69),
        vect(-22.04, 5.00, 47.30),
        vect(27.08, 2.00, 48.86),
        vect(17.44, -4.00, 31.35),
        vect(2.98, -0.09, 46.76),
        vect(3.08, 6.00, 82.94),
        vect(24.14, 2.00, 83.80),
        vect(3.40, -0.99, 107.67),
        vect(2.95, 2.00, 67.79),
        vect(-24.21, 2.00, 69.73),
        vect(-28.21, 0.29, 110.95),
        vect(-54.35, -0.19, 88.72),
        vect(-77.31, 4.88, 66.11),
        vect(-42.83, -0.20, 65.37),
        vect(-78.18, 0.70, 101.96),
        vect(-75.60, 0.25, 67.80),
        vect(-74.55, 6.58, 97.26),
        vect(-49.54, -0.21, 116.04),
        vect(-30.16, 11.91, 88.42),
        vect(-69.86, 0.90, 135.25),
        vect(-84.70, -1.25, 107.33),
        vect(-87.60, -0.25, 143.48),
        vect(-80.41, -0.25, 178.84),
        vect(-102.52, -1.25, 126.11),
        vect(-112.99, -3.25, 101.74),
        vect(-134.90, 0.75, 121.97),
        vect(-124.98, 1.75, 88.37),
        vect(-109.18, -1.25, 148.55),
        vect(-116.28, -0.25, 115.91)
    ]


rule "AMMO PACKS: Circuit Royal":
    @Event global
    @Condition getCurrentMap() == Map.CIRCUIT_ROYAL

    C_AMMO_PACKS = [
        vect(-38.42, 4.28, -26.54),
        vect(-14.53, 7.00, -36.68),
        vect(-13.50, 6.02, -18.22),
        vect(-33.98, 6.00, -51.90),
        vect(-1.56, 5.98, -3.77),
        vect(-13.68, 6.00, 15.06),
        vect(-7.41, 6.00, 15.60),
        vect(17.37, 6.00, -3.94),
        vect(-1.92, 10.00, -27.48),
        vect(19.24, 10.00, -49.68),
        vect(34.65, 9.00, -18.31),
        vect(11.13, 15.00, -44.84),
        vect(40.91, 13.97, 2.88),
        vect(79.62, 11.96, -1.87),
        vect(33.02, 14.00, -19.53),
        vect(57.23, 13.96, 7.50),
        vect(72.99, 17.96, 11.19),
        vect(38.99, 14.96, 35.77),
        vect(85.38, 16.67, 48.16),
        vect(78.45, 9.96, 20.99),
        vect(56.41, 13.96, 29.67),
        vect(77.14, 9.96, 40.56),
        vect(111.72, 9.96, 11.21),
        vect(90.11, 15.96, 9.33),
        vect(96.88, 7.96, 29.71),
        vect(77.03, 16.67, 53.41),
        vect(52.11, 14.01, -22.75),
        vect(46.41, 18.96, 20.60),
        vect(-31.24, 11.00, -6.50)
    ]


rule "AMMO PACKS: Esperança":
    @Event global
    @Condition getCurrentMap() == Map.ESPERANCA

    C_AMMO_PACKS = [
        # Mid
        vect(0.00, -2.00, -64.88),
        vect(0.00, 1.00, -13.72),
        # Team 1
        vect(73.69, -2.98, -46.24),
        vect(68.93, -3.00, -33.10),
        vect(50.31, -2.00, -33.74),
        vect(32.00, 0.02, -55.00),
        vect(32.23, -4.00, -43.27),
        vect(40.04, -2.00, -22.42),
        vect(55.86, -3.00, -65.11),
        vect(77.24, -3.00, -67.47),
        vect(39.91, -6.00, -57.35),
        vect(13.58, -0.00, -28.97),
        vect(16.12, -5.99, -82.44),
        vect(36.79, -10.50, -84.83),
        vect(46.39, -6.00, -87.29),
        vect(9.80, -5.01, -44.94),
        vect(47.04, -2.00, -86.10),
        vect(25.09, -0.00, -2.83),
        # Team 2 | p = (0.00, 0.00, 4.00) | n = (1.00, 0.00, 0.00)
        vect(-73.68, -2.98, -46.26),
        vect(-68.92, -3.00, -33.12),
        vect(-50.31, -2.00, -33.75),
        vect(-31.99, 0.02, -55.01),
        vect(-32.22, -4.00, -43.27),
        vect(-40.04, -2.00, -22.43),
        vect(-55.85, -3.00, -65.12),
        vect(-77.23, -3.00, -67.48),
        vect(-39.90, -6.00, -57.36),
        vect(-13.57, -0.00, -28.97),
        vect(-16.10, -5.99, -82.44),
        vect(-36.77, -10.50, -84.84),
        vect(-46.38, -6.00, -87.29),
        vect(-9.79, -5.01, -44.94),
        vect(-47.03, -2.00, -86.11),
        vect(-25.09, -0.00, -2.83)
    ]


rule "AMMO PACKS: Hanamura":
    @Event global
    @Condition getCurrentMap() == Map.HANAMURA or getCurrentMap() == Map.HANAMURA_WINTER

    C_AMMO_PACKS = [
        vect(31.10, 0.19, 13.54),
        vect(42.29, 1.01, -6.16),
        vect(59.44, 2.00, -29.46),
        vect(28.37, 3.00, 31.15),
        vect(48.74, 6.00, 18.73),
        vect(25.85, 0.00, 7.83),
        vect(22.99, 0.02, -23.86),
        vect(6.03, 4.00, 12.85),
        vect(11.95, 11.13, 20.94),
        vect(23.05, 6.00, -12.12),
        vect(-9.57, 1.00, 8.65),
        vect(-2.93, -0.99, 33.16),
        vect(-21.95, -1.24, -16.76),
        vect(-2.76, -2.00, -40.53),
        vect(31.61, -1.55, -38.30),
        vect(43.05, -1.99, -63.84),
        vect(24.16, 2.94, -72.63),
        vect(13.05, 7.05, -48.93),
        vect(16.04, -1.00, -82.26),
        vect(-13.35, -5.10, -69.54),
        vect(6.66, -1.00, -92.72),
        vect(-37.06, 1.00, -63.10),
        vect(-20.18, 3.92, -57.23),
        vect(0.38, -1.00, -67.13),
        vect(-10.40, 1.00, -107.36),
        vect(-32.99, 1.00, -80.86)
    ]


rule "AMMO PACKS: Hanaoka":
    @Event global
    @Condition getCurrentMap() == Map.HANAOKA
    
    C_AMMO_PACKS = [

        # Mid
        vect(11.90, 39.50, 7.00),
        vect(-17.28, 41.50, 7.00),
        # Team 1
        vect(-24.22, 44.03, -113.99),
        vect(11.06, 40.01, -104.28),
        vect(-26.94, 43.05, -51.49),
        vect(22.25, 41.00, -71.35),
        vect(-2.01, 41.50, -9.38),
        vect(-4.90, 39.82, -95.17),
        vect(-5.06, 38.34, -58.71),
        vect(-30.02, 44.02, -74.56),
        vect(-30.47, 40.00, -83.98),
        vect(15.60, 42.50, -12.81),
        vect(-23.58, 40.50, -17.33),
        vect(-5.05, 40.02, -33.72),
        vect(23.25, 44.50, 5.35),
        vect(16.81, 40.07, -38.30),
        # Team 2 | p = (0.00, 39.50, 7.00) | n = (0.00, 0.00, 1.00)
        vect(-24.22, 44.03, 127.99),
        vect(11.06, 40.01, 118.28),
        vect(-26.94, 43.05, 65.49),
        vect(22.25, 41.00, 85.35),
        vect(-2.01, 41.50, 23.38),
        vect(-4.90, 39.82, 109.17),
        vect(-5.06, 38.34, 72.71),
        vect(-30.02, 44.02, 88.56),
        vect(-30.47, 40.00, 97.98),
        vect(15.60, 42.50, 26.81),
        vect(-23.58, 40.50, 31.33),
        vect(-5.05, 40.02, 47.72),
        vect(23.25, 44.50, 8.65),
        vect(16.81, 40.07, 52.30)
    ]


rule "AMMO PACKS: Hollywood":
    @Event global
    @Condition getCurrentMap() == Map.HOLLYWOOD or getCurrentMap() == Map.HOLLYWOOD_HALLOWEEN

    C_AMMO_PACKS = [
        vect(-17.70, 1.75, -15.60),
        vect(-11.21, 5.01, 41.79),
        vect(-18.52, 0.01, 42.49),
        vect(9.12, 1.75, 19.79),
        vect(11.36, 0.00, 44.40),
        vect(-5.78, 1.75, 10.88),
        vect(-38.79, 5.75, 25.16),
        vect(-34.78, -0.25, 10.32),
        vect(-39.51, 1.75, -3.29),
        vect(36.36, 2.75, -53.16),
        vect(6.76, 1.75, -9.74),
        vect(0.30, 1.75, -32.59),
        vect(3.01, 2.99, -59.37),
        vect(32.05, 1.86, -76.07),
        vect(-15.41, 1.73, -62.94),
        vect(16.61, 1.75, -40.02),
        vect(2.00, 10.75, -28.86),
        vect(2.06, 13.00, -66.18),
        vect(26.04, 1.62, -93.79),
        vect(-15.65, 1.75, -111.67),
        vect(6.84, 3.75, -97.19),
        vect(-35.29, 1.75, -84.66),
        vect(-44.35, 9.75, -106.46),
        vect(-19.00, 9.75, -116.30),
        vect(-40.00, 1.75, -103.29),
        vect(-26.72, 1.75, -123.88),
        vect(-44.03, 3.75, -137.79),
        vect(-18.34, 3.75, -153.27),
        vect(-12.56, 4.12, -88.43),
        vect(8.70, 3.75, -125.33)
    ]

    
rule "AMMO PACKS: Ilios":
    @Event global
    @Condition getCurrentMap() == Map.ILIOS

    C_IS_CONTROL = true

    C_AMMO_PACKS_STAGE_SLICE[0] = [0, 14]
    C_AMMO_PACKS_STAGE_SLICE[1] = [14, 16]
    C_AMMO_PACKS_STAGE_SLICE[2] = [30, 16]

    C_AMMO_PACKS = [

        # Team 1
        vect(351.33, -25.54, 17.66),
        vect(371.38, -27.64, -44.10),
        vect(341.11, -23.66, -33.23),
        vect(351.65, -18.64, -22.35),
        vect(314.29, -23.66, -23.57),
        vect(371.00, -27.64, -1.69),
        vect(336.59, -24.69, -4.88),
        # Team 2 | p = (326.42, -23.67, -38.40) | n = (-0.34, 0.00, -0.83)
        vect(304.74, -25.54, -95.78),
        vect(362.41, -27.64, -65.95),
        vect(333.23, -23.66, -52.40),
        vect(333.09, -18.64, -67.55),
        vect(307.36, -23.66, -40.42),
        vect(332.33, -27.64, -95.84),
        vect(310.09, -24.69, -69.39),


        # Mid
        vect(-199.25, 1.01, -7.25),
        vect(-225.38, 5.32, -33.42),
        # Team 1
        vect(-189.19, 1.00, -20.18),
        vect(-195.01, 1.00, -33.85),
        vect(-215.38, 1.00, -35.38),
        vect(-168.56, 5.00, -30.49),
        vect(-193.40, 5.04, -52.36),
        vect(-177.76, -1.00, -45.07),
        vect(-169.62, -4.76, -74.54),
        # Team 2 | p = (-220.98, 0.00, -29.02) | n = (-0.67, 0.00, 0.67)
        vect(-212.14, 1.00, 2.77),
        vect(-225.81, 1.00, -3.05),
        vect(-227.34, 1.00, -23.42),
        vect(-222.44, 5.00, 23.40),
        vect(-244.32, 5.04, -1.44),
        vect(-237.03, -1.00, 14.20),
        vect(-266.50, -4.76, 22.33),


        # Mid
        vect(28.50, 57.37, -141.91),
        vect(28.50, 60.37, -181.73),
        # Team 1
        vect(60.79, 60.37, -157.20),
        vect(52.13, 60.37, -143.32),
        vect(41.99, 60.49, -160.17),
        vect(64.90, 60.97, -174.63),
        vect(92.86, 60.37, -162.44),
        vect(80.27, 58.37, -145.82),
        vect(64.90, 64.47, -174.63),
        # Team 2 | p = (28.50, 60.63, -176.00) | n = (1.00, 0.00, 0.00)
        vect(-3.79, 60.37, -157.21),
        vect(4.87, 60.37, -143.32),
        vect(15.01, 60.49, -160.17),
        vect(-7.89, 60.97, -174.64),
        vect(-35.86, 60.37, -162.45),
        vect(-23.27, 58.37, -145.83),
        vect(-7.89, 64.47, -174.64)
    ]

    
rule "AMMO PACKS: Junkertown":
    @Event global
    @Condition getCurrentMap() == Map.JUNKERTOWN

    C_AMMO_PACKS = [
        vect(20.04, 9.00, -64.03),
        vect(-6.76, 1.51, -20.63),
        vect(-6.23, 7.06, -63.72),
        vect(2.41, 7.02, -83.68),
        vect(5.86, 7.04, -38.91),
        vect(23.09, 6.94, -35.47),
        vect(22.46, 10.10, -89.90),
        vect(-38.86, 4.83, -33.87),
        vect(-28.06, 4.48, -71.73),
        vect(-54.17, 4.48, -77.17),
        vect(-48.33, 12.48, -72.42),
        vect(-52.26, 1.48, -136.03),
        vect(-65.10, 12.43, -98.63),
        vect(-40.15, 7.57, -89.87),
        vect(-18.94, 13.48, -88.49),
        vect(-11.85, 6.48, -105.34),
        vect(-72.51, 6.37, -140.87),
        vect(-84.89, 7.44, -171.38),
        vect(-73.24, 7.43, -110.90),
        vect(-49.18, 7.37, -123.87),
        vect(-84.85, 13.37, -158.24),
        vect(-88.26, 7.44, -99.14),
        vect(-81.65, 6.44, -125.00),
        vect(-103.41, 6.44, -114.25),
        vect(-112.79, 12.44, -147.98),
        vect(-54.53, 7.37, -151.18),
        vect(-89.46, 6.37, -137.33),
        vect(-48.92, 13.51, -117.03),
        vect(-31.19, 6.53, -88.39)
    ]

    
rule "AMMO PACKS: King's Row":
    @Event global
    @Condition getCurrentMap() == Map.KINGS_ROW

    C_AMMO_PACKS = [
        vect(6.24, 0.07, -28.10),
        vect(-42.73, 0.09, -38.39),
        vect(8.94, 1.00, -9.63),
        vect(-19.75, 0.08, -7.99),
        vect(-21.70, 0.08, 11.82),
        vect(20.84, 6.03, -39.14),
        vect(-23.46, 1.00, -56.39),
        vect(-15.39, 1.00, -20.37),
        vect(-27.51, 6.00, -49.84),
        vect(-62.40, -0.13, -15.52),
        vect(-79.62, 0.27, 0.65),
        vect(-29.65, 9.00, -11.28),
        vect(-74.33, 0.50, -39.45),
        vect(-48.01, 2.00, -51.51),
        vect(-95.44, -2.50, -46.51),
        vect(-85.00, 0.98, -5.30),
        vect(-90.40, 0.82, -35.69),
        vect(-137.25, 0.07, -12.80),
        vect(-111.56, 1.07, 4.03),
        vect(-109.51, 1.07, 29.73),
        vect(-160.47, -2.93, 26.22),
        vect(-139.80, -2.93, 37.23),
        vect(-153.02, -2.91, 9.83),
        vect(-140.87, -0.93, 9.66),
        vect(-58.06, -0.06, -23.83),
        vect(-33.54, 0.08, -15.12),
        vect(-11.17, 0.07, -35.65),
        vect(-107.84, 1.07, -22.13),
        vect(-77.82, 6.00, -12.50)
    ]

    
rule "AMMO PACKS: King's Row (Winter)":
    @Event global
    @Condition getCurrentMap() == Map.KINGS_ROW_WINTER

    C_AMMO_PACKS = [
        vect(-42.73, 0.09, -38.39),
        vect(8.94, 1.00, -9.63),
        vect(-21.70, 0.08, 11.82),
        vect(20.84, 6.03, -39.14),
        vect(-23.46, 1.00, -56.39),
        vect(-15.39, 1.00, -20.37),
        vect(-27.51, 6.00, -49.84),
        vect(-29.65, 9.00, -11.28),
        vect(-74.33, 0.50, -39.45),
        vect(-48.01, 2.00, -51.51),
        vect(-95.44, -2.50, -46.51),
        vect(-90.40, 0.82, -35.69),
        vect(-137.25, 0.07, -12.80),
        vect(-111.56, 1.07, 4.03),
        vect(-109.51, 1.07, 29.73),
        vect(-160.47, -2.93, 26.22),
        vect(-139.80, -2.93, 37.23),
        vect(-153.02, -2.91, 9.83),
        vect(-140.87, -0.93, 9.66),
        vect(-11.17, 0.07, -35.65),
        vect(-107.84, 1.07, -22.13),
        vect(-77.82, 6.00, -12.50),
        vect(-57.03, -0.06, -23.50),
        vect(-62.43, 0.95, -15.58),
        vect(-33.11, 0.07, -17.99),
        vect(-18.27, 0.16, -7.79),
        vect(6.35, 0.60, -28.15),
        vect(-84.57, 0.95, -7.14),
        vect(-79.68, 0.27, 0.74)
    ]

    
rule "AMMO PACKS: Lijiang Tower":
    @Event global
    @Condition getCurrentMap() == Map.LIJIANG_TOWER or getCurrentMap() == Map.LIJIANG_TOWER_LNY

    C_IS_CONTROL = true

    C_AMMO_PACKS_STAGE_SLICE[0] = [0, 15]
    C_AMMO_PACKS_STAGE_SLICE[1] = [15, 14]
    C_AMMO_PACKS_STAGE_SLICE[2] = [29, 14]

    C_AMMO_PACKS = [

        # Mid
        vect(1.00, -2.00, -82.87),
        # Team 1
        vect(30.67, -3.00, -56.31),
        vect(24.34, 0.00, -36.43),
        vect(13.68, -0.00, -29.99),
        vect(24.40, 6.03, -37.23),
        vect(8.77, 0.00, -9.79),
        vect(39.02, -1.00, -13.41),
        vect(10.79, -1.00, -48.91),
        # Team 2 | p = (1.00, -1.00, -63.00) | n = (-1.00, 0.00, 0.00)
        vect(-28.67, -3.00, -56.31),
        vect(-22.34, 0.00, -36.43),
        vect(-11.68, -0.00, -29.99),
        vect(-22.40, 6.03, -37.23),
        vect(-6.77, 0.00, -9.79),
        vect(-37.02, -1.00, -13.41),
        vect(-8.79, -1.00, -48.91),


        # Mid
        vect(0.00, 94.05, 133.17),
        vect(0.00, 94.00, 182.81),
        # Team 1
        vect(13.65, 95.00, 114.74),
        vect(-30.27, 94.00, 140.44),
        vect(-30.21, 94.05, 176.20),
        vect(-9.21, 94.15, 156.40),
        vect(-52.39, 94.53, 154.60),
        vect(-39.60, 94.90, 140.65),
        # Team 2 | p = (0.00, 94.00, 143.00) | n = (-1.00, 0.00, 0.00)
        vect(-13.65, 95.00, 114.74),
        vect(30.27, 94.00, 140.44),
        vect(30.21, 94.05, 176.20),
        vect(9.21, 94.15, 156.40),
        vect(52.39, 94.53, 154.60),
        vect(39.60, 94.90, 140.65),


        # Mid
        vect(0.00, 270.00, 267.46),
        vect(0.00, 278.00, 300.41),
        # Team 1
        vect(15.47, 267.00, 272.79),
        vect(19.41, 267.00, 308.36),
        vect(29.45, 267.00, 320.85),
        vect(31.86, 267.00, 284.79),
        vect(8.25, 270.00, 305.25),
        vect(2.95, 270.00, 319.68),
        # Team 2 | p = (0.00, 267.33, 273.00) | n = (-1.00, 0.00, 0.00)
        vect(-15.47, 267.00, 272.79),
        vect(-19.41, 267.00, 308.36),
        vect(-29.45, 267.00, 320.85),
        vect(-31.86, 267.00, 284.79),
        vect(-8.25, 270.00, 305.25),
        vect(-2.95, 270.00, 319.68)
    ]

    
rule "AMMO PACKS: Midtown":
    @Event global
    @Condition getCurrentMap() == Map.MIDTOWN

    C_AMMO_PACKS = [
        vect(10.41, 3.97, 71.45),
        vect(-24.70, 3.99, 62.28),
        vect(-22.95, 3.75, 84.37),
        vect(-5.88, 4.97, 32.39),
        vect(-23.02, 4.00, 53.67),
        vect(-2.69, 8.45, 93.68),
        vect(-14.79, 10.56, 62.27),
        vect(16.92, 7.97, 56.35),
        vect(-7.42, 9.97, 21.52),
        vect(25.76, 3.96, 44.46),
        vect(36.63, 4.82, 20.11),
        vect(44.13, 7.89, 1.51),
        vect(78.27, 4.84, 40.45),
        vect(47.35, 3.84, 47.97),
        vect(49.50, 8.84, 45.49),
        vect(65.77, 5.84, 29.23),
        vect(35.88, -1.12, 8.57),
        vect(61.36, -0.16, -3.47),
        vect(83.92, 3.84, -37.09),
        vect(34.00, 3.58, -21.28),
        vect(88.32, 3.84, -2.50),
        vect(110.27, 7.85, -21.99),
        vect(86.78, 11.85, -37.99),
        vect(112.49, 2.84, -38.98),
        vect(125.39, 1.84, -29.42),
        vect(109.17, 2.84, -69.47),
        vect(143.32, 2.84, -63.62),
        vect(121.53, 0.84, -59.24),
        vect(86.35, 4.84, -60.18),
        vect(52.01, 3.58, -47.00),
        vect(61.17, 7.84, -1.24)
    ]

    
rule "AMMO PACKS: New Queen Street":
    @Event global
    @Condition getCurrentMap() == Map.NEW_QUEEN_STREET

    C_AMMO_PACKS = [

        # Mid
        vect(0.00, 0.00, 22.20),
        vect(0.00, 1.01, -18.48),
        # Team 1
        vect(-88.27, 11.00, -21.28),
        vect(-73.91, 8.01, 1.65),
        vect(-39.69, 4.00, -29.16),
        vect(-21.79, 4.00, -15.70),
        vect(-30.38, 4.00, -4.34),
        vect(-31.29, 4.00, 26.68),
        vect(-62.43, 8.00, 16.26),
        vect(-9.95, 2.00, -49.24),
        vect(-49.95, 4.00, -50.85),
        # Team 2 | p = (0.00, 0.00, 6.00) | n = (1.00, 0.00, 0.00)
        vect(88.27, 11.00, -21.28),
        vect(73.91, 8.01, 1.65),
        vect(39.69, 4.00, -29.16),
        vect(21.79, 4.00, -15.70),
        vect(30.38, 4.00, -4.34),
        vect(31.29, 4.00, 26.68),
        vect(62.43, 8.00, 16.26),
        vect(9.95, 2.00, -49.24),
        vect(49.95, 4.00, -50.85)
    ]

    
rule "AMMO PACKS: Numbani":
    @Event global
    @Condition getCurrentMap() == Map.NUMBANI

    C_AMMO_PACKS = [
        vect(94.83, -1.75, 32.70),
        vect(46.03, -1.92, 1.11),
        vect(27.39, 1.18, 4.15),
        vect(45.26, -0.75, -22.11),
        vect(85.73, 1.69, -15.90),
        vect(84.83, 6.25, 19.26),
        vect(71.94, -1.75, 19.58),
        vect(46.90, 0.25, 26.89),
        vect(61.74, -1.75, -3.83),
        vect(71.61, 0.25, -17.87),
        vect(100.56, 0.25, -18.32),
        vect(102.98, -1.75, 4.88),
        vect(119.01, -3.75, 33.01),
        vect(124.37, -3.75, 24.69),
        vect(144.91, -3.75, 41.27),
        vect(159.10, -3.75, 24.62),
        vect(141.98, -3.75, 6.00),
        vect(153.85, -3.92, -3.48),
        vect(120.78, -5.76, -16.33),
        vect(126.88, -5.76, -16.72),
        vect(149.58, 2.25, 28.17),
        vect(117.48, 4.25, 2.66),
        vect(75.61, 0.25, 14.00),
        vect(183.91, -1.75, -15.31),
        vect(179.01, -1.78, 27.71),
        vect(202.73, 0.20, 42.28),
        vect(220.98, 0.20, 22.65),
        vect(205.93, -3.80, -10.50),
        vect(198.09, -1.80, 11.26),
        vect(165.70, 4.25, -5.21)
    ]


rule "AMMO PACKS: Rialto":
    @Event global
    @Condition getCurrentMap() == Map.RIALTO

    C_AMMO_PACKS = [
        vect(97.88, -1.25, -30.02),
        vect(82.75, -1.24, -10.59),
        vect(80.03, -1.25, -33.54),
        vect(58.42, -1.25, -24.22),
        vect(55.48, -0.24, -33.48),
        vect(36.07, 0.87, -31.76),
        vect(36.32, -0.25, -53.15),
        vect(56.21, -0.25, -73.28),
        vect(40.43, 5.75, -64.49),
        vect(76.29, 3.75, -29.80),
        vect(4.86, 0.52, -85.64),
        vect(66.72, -0.25, -63.02),
        vect(0.11, -0.25, -53.00),
        vect(-3.05, 3.75, -33.03),
        vect(-14.10, -1.25, -54.21),
        vect(-11.85, -1.25, -23.53),
        vect(-27.43, -1.75, -37.57),
        vect(-46.63, -1.25, -74.09),
        vect(-14.37, -0.25, -78.30),
        vect(-24.96, 1.75, -102.55),
        vect(-45.91, 4.75, -77.38),
        vect(-64.98, 2.75, -92.77),
        vect(-44.69, 1.75, -111.69),
        vect(-78.75, 1.75, -110.00),
        vect(-64.69, 2.75, -138.99),
        vect(-49.16, 2.75, -139.00),
        vect(44.85, -1.25, -89.22),
        vect(32.79, -1.25, -79.19),
        vect(14.97, -1.25, -52.82)
    ]


rule "AMMO PACKS: Route 66":
    @Event global
    @Condition getCurrentMap() == Map.ROUTE66

    C_AMMO_PACKS = [
        vect(19.16, 7.56, 22.43),
        vect(62.04, 2.85, 0.74),
        vect(11.02, 8.97, -43.74),
        vect(-6.97, 3.02, -6.40),
        vect(-16.56, 3.49, -46.27),
        vect(-50.00, 3.30, -36.15),
        vect(-32.03, 3.43, -17.48),
        vect(-24.14, 12.58, -15.65),
        vect(-38.64, 3.33, -0.65),
        vect(-98.65, 10.50, 1.09),
        vect(-93.78, 6.50, -4.93),
        vect(-81.59, 6.50, -23.58),
        vect(-107.16, 12.50, -28.75),
        vect(-64.71, 6.50, 5.91),
        vect(44.36, 6.26, 46.32),
        vect(-28.39, 3.43, -19.19),
        vect(60.20, 0.11, 46.36),
        vect(35.08, 7.83, 0.22),
        vect(20.05, 2.05, 17.53),
        vect(22.20, 2.04, -15.47),
        vect(-23.85, 3.58, -56.01),
        vect(-11.69, 8.51, -40.18),
        vect(-77.14, 6.50, 23.98),
        vect(-51.80, 6.50, 23.23),
        vect(-90.11, 6.50, 22.60),
        vect(-67.41, 6.50, -9.26),
        vect(-76.46, 10.50, -5.69),
        vect(68.28, 0.98, 19.46),
        vect(50.91, 1.89, 16.59),
        vect(33.97, 2.14, -6.07)
    ]


rule "AMMO PACKS: Samoa":
    @Event global
    @Condition getCurrentMap() == Map.SAMOA

    C_IS_CONTROL = true

    C_AMMO_PACKS_STAGE_SLICE[0] = [0, 17]
    C_AMMO_PACKS_STAGE_SLICE[1] = [17, 18]
    C_AMMO_PACKS_STAGE_SLICE[2] = [35, 17]

    C_AMMO_PACKS = [

        # Mid
        vect(-330.00, 9.00, -88.02),
        # Team 1
        vect(-350.76, 9.00, -94.98),
        vect(-339.14, 2.93, -114.00),
        vect(-342.63, 2.95, -137.75),
        vect(-339.12, 3.03, -82.66),
        vect(-363.99, 7.04, -79.77),
        vect(-356.11, 9.00, -126.55),
        vect(-391.93, 7.03, -100.48),
        vect(-380.30, 7.05, -113.73),
        # Team 2 | p = (-330.00, 3.05, -100.00) | n = (1.00, 0.00, 0.00)
        vect(-309.24, 9.00, -94.98),
        vect(-320.86, 2.93, -114.00),
        vect(-317.37, 2.95, -137.75),
        vect(-320.88, 3.03, -82.66),
        vect(-296.01, 7.04, -79.77),
        vect(-303.89, 9.00, -126.55),
        vect(-268.07, 7.03, -100.48),
        vect(-279.70, 7.05, -113.73),


        # Mid
        vect(234.00, 14.99, -235.03),
        vect(233.97, 6.81, -256.00),
        # Team 1
        vect(245.04, 5.22, -277.25),
        vect(249.17, 9.25, -219.75),
        vect(261.59, 8.10, -253.86),
        vect(246.77, 7.00, -242.62),
        vect(286.89, 12.29, -233.10),
        vect(276.84, 13.00, -213.10),
        vect(291.44, 6.31, -268.77),
        vect(277.69, 9.00, -240.15),
        # Team 2 | p = (234.00, 6.80, -256.00) | n = (-1.00, 0.00, 0.00)
        vect(222.96, 5.22, -277.25),
        vect(218.83, 9.25, -219.75),
        vect(206.41, 8.10, -253.86),
        vect(221.23, 7.00, -242.62),
        vect(181.11, 12.29, -233.10),
        vect(191.16, 13.00, -213.10),
        vect(176.56, 6.31, -268.77),
        vect(190.31, 9.00, -240.15),


        # Mid
        vect(27.63, 344.63, 398.03),
        vect(27.63, 345.65, 376.18),
        vect(27.63, 333.63, 365.23),
        # Team 1
        vect(39.05, 338.62, 352.67),
        vect(55.30, 338.66, 346.18),
        vect(39.50, 340.63, 381.72),
        vect(66.73, 340.63, 364.62),
        vect(83.39, 342.63, 367.23),
        vect(45.24, 342.64, 398.48),
        vect(65.89, 340.66, 380.37),
        # Team 2 | p = (27.63, 339.62, 353.00) | n = (-1.00, 0.00, 0.00)
        vect(16.20, 338.62, 352.67),
        vect(-0.05, 338.66, 346.18),
        vect(15.75, 340.63, 381.72),
        vect(-11.48, 340.63, 364.62),
        vect(-28.14, 342.63, 367.23),
        vect(10.01, 342.64, 398.48),
        vect(-10.64, 340.66, 380.37)
    ]


rule "AMMO PACKS: Throne of Anubis":
    @Event global
    @Condition getCurrentMap() == Map.THRONE_OF_ANUBIS

    C_AMMO_PACKS = [
        # Mid
        vect(21.17, -1.00, 0.00),
        vect(-4.90, -5.00, 0.00),
        # Team 1
        vect(2.38, 1.95, 45.15),
        vect(1.02, 5.13, 100.57),
        vect(-0.98, -0.00, 89.04),
        vect(-33.00, 5.00, 81.84),
        vect(-38.12, 3.03, 47.85),
        vect(-13.55, 2.00, 62.34),
        vect(11.45, 4.00, 60.05),
        vect(-16.77, 2.00, 37.45),
        vect(6.30, 1.02, 21.49),
        vect(26.23, 5.13, 89.95),
        vect(19.99, 5.00, 32.28),
        vect(-18.68, 1.93, 24.55),
        vect(8.97, 6.56, 8.05),
        # Team 2 | p = (0.00, 3.50, 0.00) | n = (0.00, 0.00, -1.00)
        vect(2.38, 1.95, -45.15),
        vect(1.02, 5.13, -100.57),
        vect(-0.98, -0.00, -89.04),
        vect(-33.00, 5.00, -81.84),
        vect(-38.12, 3.03, -47.85),
        vect(-13.55, 2.00, -62.34),
        vect(11.45, 4.00, -60.05),
        vect(-16.77, 2.00, -37.45),
        vect(6.30, 1.02, -21.49),
        vect(26.23, 5.13, -89.95),
        vect(19.99, 5.00, -32.28),
        vect(-18.68, 1.93, -24.55),
        vect(8.97, 6.56, -8.05)
    ]


rule "AMMO PACKS: Watchpoint Gibraltar":
    @Event global
    @Condition getCurrentMap() == Map.WATCHPOINT_GIBRALTAR

    C_AMMO_PACKS = [
        vect(57.85, 9.44, -117.94),
        vect(23.19, 4.00, -112.29),
        vect(65.98, -6.19, -122.71),
        vect(45.97, -4.00, -144.95),
        vect(39.35, -3.98, -122.72),
        vect(19.77, -11.00, -110.96),
        vect(38.05, -11.00, -93.95),
        vect(26.52, -5.02, -82.62),
        vect(3.96, -5.00, -74.36),
        vect(3.28, -2.00, -104.42),
        vect(38.27, -0.00, -99.58),
        vect(22.45, 3.00, -62.74),
        vect(57.55, -1.00, -81.26),
        vect(29.61, -1.00, -34.41),
        vect(59.72, -5.01, -51.05),
        vect(26.40, -5.01, -52.02),
        vect(58.79, -10.00, -31.37),
        vect(59.79, -3.00, -42.30),
        vect(61.71, -2.98, -13.55),
        vect(85.11, -2.99, -45.63),
        vect(59.39, 3.35, -40.71),
        vect(90.35, 3.00, -29.83),
        vect(79.61, 1.00, -64.95),
        vect(56.43, 9.97, -42.47),
        vect(82.60, -3.00, 8.90),
        vect(110.80, 0.00, -2.96),
        vect(79.40, 1.00, 10.57),
        vect(50.14, 1.00, 25.95),
        vect(42.99, 9.00, 16.35),
        vect(79.05, 9.00, 21.28),
        vect(73.36, 1.00, 47.51),
        vect(78.64, -3.18, -12.33),
        vect(59.19, 1.00, -6.50),
        vect(89.90, -0.94, 33.84)
    ]


rule "AMMO PACKS: Workshop Island":
    @Event global
    @Condition getCurrentMap() == Map.WORKSHOP_ISLAND

    C_AMMO_PACKS = [
        vect(8, 0, 8),
        vect(-8, 0, 8),
        vect(8, 0, -8),
        vect(-8, 0, -8),

        # testing server crash.
        vect(0.43, 0.00, -12.94),
        vect(4.29, 0.00, -11.63),
        vect(6.76, 0.00, -13.51),
        vect(10.59, 0.00, -12.12),
        vect(12.91, 0.00, -8.75),
        vect(12.32, 0.00, -4.49),
        vect(6.61, 0.00, -4.38),
        vect(0.22, 0.00, -5.38),
        vect(-0.96, 0.00, -1.40),
        vect(3.61, 0.00, 1.43),
        vect(10.25, 0.00, 0.66),
        vect(14.94, 0.00, 5.82),
        vect(7.00, 0.00, 5.33),
        vect(1.81, 0.00, 4.65),
        vect(1.18, 0.00, 8.84),
        vect(7.64, 0.00, 12.68),
        vect(13.38, 0.00, 13.25),
        vect(0.21, 0.00, 10.94),
        vect(-4.01, 0.00, 5.99),
        vect(-4.89, 0.00, 2.02),
        vect(-8.25, 0.00, -0.72),
        vect(-7.95, 0.00, -3.67),
        vect(-11.10, 0.00, -7.11),
        vect(-11.37, 0.00, -10.06),
        vect(-7.76, 0.00, -11.44),
        vect(-3.89, 0.00, -9.39),
        vect(-4.82, 0.00, -4.33),
        vect(-9.41, 0.00, -2.40),
        vect(-10.44, 0.00, 2.46),
        vect(-12.73, 0.00, 4.92),
        vect(-14.90, 0.00, 8.29),
        vect(-12.40, 0.00, 10.88),
        vect(-13.79, 0.00, 15.85),
        vect(-9.67, 0.00, 15.63),
        vect(-5.01, 0.00, 14.52),
        vect(-4.60, 0.00, 11.33),
        vect(-0.56, 0.00, 14.36),
        vect(4.61, 0.00, 15.89),
        vect(-13.15, 0.00, 2.04),
        vect(-12.44, 0.00, -0.08),
        vect(-12.49, 0.00, -2.69),
        vect(-14.55, 0.00, -3.40),
        vect(-14.01, 0.00, -6.32),
        vect(-15.35, 0.00, -9.41),
        vect(-15.52, 0.00, -12.30),
        vect(-14.19, 0.00, -14.14),
        vect(-11.51, 0.00, -14.47),
        vect(-18.76, 0.00, -17.23),
        vect(-16.76, 0.00, -17.93),
        vect(17.47, 0.00, -17.67),
        vect(17.61, 0.00, -14.11),
        vect(14.08, 0.00, -17.69),
        vect(18.70, 0.00, -11.04),
        vect(16.69, 0.00, -8.68),
        vect(18.54, 0.00, -6.59),
        vect(17.15, 0.00, -4.83)
    ]


def destroyAmmoPacks():
    @Name "Subroutine: Destroy Ammo Packs"

    for i in range(len(AMMO_PACK_POSITIONS)):

        destroyEffect(AMMO_PACK_EFFECTS_PROJ[i])
        destroyEffect(AMMO_PACK_EFFECTS_RING[i])
        destroyInWorldText(AMMO_PACK_EFFECTS_TEXT[i])
        wait()

    AMMO_PACK_EFFECTS_PROJ = []
    AMMO_PACK_EFFECTS_RING = []
    AMMO_PACK_EFFECTS_TEXT = []

    AMMO_PACK_POSITIONS = []
    AMMO_PACK_TIMESTAMPS = []
    wait()


def createAmmoPacks():
    @Name "Subroutine: Create Ammo Packs"

    # returns the ammo pack's current remaining cooldown in seconds.
    #!define __PACK_COOLDOWN__ (AMMO_PACK_RESPAWN_TIME - (getTotalTimeElapsed() - AMMO_PACK_TIMESTAMPS[evalOnce(i)]))
    
    for i in range(0, len(AMMO_PACK_POSITIONS)):

        # create VFX.
        createProjectileEffect(getAllPlayers() if __PACK_COOLDOWN__ <= 0 else null, Projectile.BAPTISTE_BIOTIC_LAUNCHER, localPlayer, AMMO_PACK_POSITIONS[evalOnce(i)] + vect(0, 0.3 + (sin(getTotalTimeElapsed() * 2) * 0.1), 0), angleToDirection(getTotalTimeElapsed() * 80, -85), 0.02, ProjectileEffectReeval.VISIBILITY_POSITION_DIRECTION_AND_SIZE)
        AMMO_PACK_EFFECTS_PROJ[i] = getLastCreatedEntity()
        
        createEffect(getAllPlayers(), Effect.RING, Color.ORANGE if __PACK_COOLDOWN__ <= 0 else Color.GRAY, AMMO_PACK_POSITIONS[i], 0.5, EffectReeval.VISIBILITY_AND_COLOR)
        AMMO_PACK_EFFECTS_RING[i] = getLastCreatedEntity()
        
        # create respawn time text.
        createInWorldText(getAllPlayers(), __PACK_COOLDOWN__ if __PACK_COOLDOWN__ > 0 else "", AMMO_PACK_POSITIONS[i] + vect(0, 0.4, 0), 1, Clip.SURFACES, WorldTextReeval.VISIBILITY_AND_STRING, rgba(255, 255, 255, 200), SpecVisibility.ALWAYS)
        AMMO_PACK_EFFECTS_TEXT[i] = getLastCreatedText()

        # initialize cooldown timestamp.
        AMMO_PACK_TIMESTAMPS[i] = -AMMO_PACK_RESPAWN_TIME

        wait(0.032)


rule "Create All Ammo Packs":
    @Event global
    @Condition C_AMMO_PACKS == true
    @Condition C_IS_CONTROL == false

    # if the game mode is not control, create every ammo pack in the map.
    AMMO_PACK_POSITIONS = C_AMMO_PACKS
    createAmmoPacks()


rule "Swap Ammo Packs Between Control Stages":
    @Event global
    @Condition C_AMMO_PACKS == true
    @Condition C_IS_CONTROL == true
    @Condition getCurrentObjective() != CONTROL_STAGE

    # if the game mode is control, only ammo packs in the current stage should be active.
    destroyAmmoPacks()

    #!define INDEX_STAGE_START  0
    #!define INDEX_STAGE_LENGTH 1

    AMMO_PACK_POSITIONS = C_AMMO_PACKS.slice(C_AMMO_PACKS_STAGE_SLICE[getCurrentObjective()][INDEX_STAGE_START],
                                             C_AMMO_PACKS_STAGE_SLICE[getCurrentObjective()][INDEX_STAGE_LENGTH])
    createAmmoPacks()

    CONTROL_STAGE = getCurrentObjective()


rule "Warning for Missing Ammo Packs":
    @Event global
    @Condition C_AMMO_PACKS == false

    hudHeader(null if isGameInProgress() == true else localPlayer, "{0} WARNING {0}".format(iconString(Icon.WARNING)), HudPosition.TOP, 5, HUD_PULSE_ORANGE, HudReeval.VISIBILITY_AND_COLOR)
    hudSubtext(null if isGameInProgress() == true else localPlayer, "\nThis map does not have any ammo packs!", HudPosition.TOP, 5, Color.WHITE, HudReeval.VISIBILITY)
    hudSubtext(null if isGameInProgress() == true else localPlayer, "\nPlayers will be unable to replenish their ammo outside of spawn.", HudPosition.TOP, 5, Color.WHITE, HudReeval.VISIBILITY)