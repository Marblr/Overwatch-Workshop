settings {
    "main": {
        "description": "It's Overwatch, but there's fall damage.\n\nCode: 4H2EC\nLast updated: 2024-08-24",
        "modeName": "Fall Damage"
    },
    "lobby": {
        "team1Slots": 5,
        "team2Slots": 5
    },
    "gamemodes": {
        "control": {},
        "escort": {},
        "hybrid": {},
        "push": {},
        "tdm": {
            "enabledMaps": [
                "workshopIsland"
            ]
        },
        "general": {
            "roleLimit": "1Tank2Offense2Support"
        }
    }
}

#!extension explosionSounds
#!extension buffAndDebuffSounds

#!define toTimestamp(time) "{0}{1}:{2}{3}".format("0" if floor(time / 60) < 10 else "", floor(time / 60), "0" if floor(time % 60) < 10 else "", floor(time % 60))

#######################
###    VARIABLES    ###
#######################

# Debug Utilities

globalvar DEBUG = createWorkshopSetting(bool, "Technical Settings", "Show Debug Information", false, 1)

globalvar DEBUG_FEED_MAX = 5
playervar debug_feed_array = []
playervar debug_feed_num = 0

# Statistic Tracking

globalvar LOG_STATS = createWorkshopSetting(bool, "Technical Settings", "Record Statistics", false, 0)

globalvar statMatchDuration = 0
globalvar statReplayDuration = 0

globalvar statDamageTaken = 0
globalvar statDamageTakenPerHero = []
globalvar statDeaths = 0
globalvar statDeathsPerHero = []

globalvar statFallDamageTaken = 0
globalvar statFallDamageTakenPerHero = []
globalvar statFallDeaths = 0
globalvar statFallDeathsPerHero = []

playervar t = 0
playervar cachedHeroIndex = -1
playervar switchedHero = false
globalvar statPlaytimePerHero = []

globalvar statFallDeathsTimeline = []

globalvar i = 0
globalvar logString = ""

# Fall Damage Logic

enum FallImmunity:
    NONE,               # the player will take fall damage
    UNTIL_ON_GROUND,    # the player will NOT take fall damage for their next landing
    SCRIPTED,           # the player will NOT take fall damage until this is manually un-set
    ALWAYS_IMMUNE       # the player will NEVER take fall damage

globalvar C_FLOATING_HEROES = [
    Hero.ECHO,
    Hero.SIGMA,
    Hero.ZENYATTA
    #Hero.JUNO # overpy is currently unmaintained due to the workshop being neglected
]

globalvar C_TERMINAL_VELOCITY = 30 # effectively only 29.97 under normal gravity

globalvar FALL_DAMAGE_INSTANTLY_KILLS = createWorkshopSetting(bool, "Gameplay Settings", "Fall Damage Instantly Kills", false, 0)
globalvar RANDOM_SPREAD_PERCENTAGE = createWorkshopSetting(int[0:100], "Gameplay Settings", "Fall Damage Random Spread (Percentage)", 0, 1)
globalvar FLOATING_HEROES_ALWAYS_IMMUNE = false
globalvar ANNOUNCE_FALL_DEATHS = createWorkshopSetting(bool, "Gameplay Settings", "Announce Fall Deaths", true, 3)

globalvar VELOCITY_THRESHOLD = 13

playervar fallVelocity = 0
playervar fallDamage = 0
playervar fallDamageTaken = 0
playervar fallImmunityState = FallImmunity.NONE

globalvar KNOCKBACK_CREDIT_TIME = 5
playervar recentKnockbacker = null


###################################
###    FALL DAMAGE GAMEMODE     ###
###################################

rule "Begone, Inspector":
    @Event global
    @Condition DEBUG == false

    disableInspector()


rule "Record Last Source of Knockback":
    @Event playerReceivedKnockback
    @Condition attacker != eventPlayer

    # delay by one tick to ignore cases where the booped player never becomes airborne
    wait()
    if eventPlayer.isOnGround() == false:
        eventPlayer.recentKnockbacker = attacker
        wait(KNOCKBACK_CREDIT_TIME, Wait.RESTART_WHEN_TRUE)
        eventPlayer.recentKnockbacker = null
    
    
rule "Record Falling Velocity":
    @Event eachPlayer
    @Condition eventPlayer.isOnGround() == false

    # only store downward velocity
    eventPlayer.fallVelocity = max(0, -eventPlayer.getVerticalSpeed())

    # delayed by a frame so the velocity is not reset immediately upon landing
    wait()
    if RULE_CONDITION: goto RULE_START


rule "Calculate and Apply Fall Damage":
    @Event eachPlayer
    @Condition eventPlayer.isOnGround() == true

    # under certain conditions, do not apply fall damage
    if (eventPlayer.isDead() == true or
        eventPlayer.fallImmunityState != FallImmunity.NONE or
        (eventPlayer.hasStatusEffect(Status.PHASED_OUT) or eventPlayer.hasStatusEffect(Status.INVINCIBLE))): # ice block, wraith, suzu, etc
        goto skip

    if eventPlayer.fallVelocity > VELOCITY_THRESHOLD:

        # fall damage formula
        if FALL_DAMAGE_INSTANTLY_KILLS == true:
            eventPlayer.fallDamage = 99999
        else:
            eventPlayer.fallDamage = (eventPlayer.fallVelocity * eventPlayer.fallVelocity) / 15
            eventPlayer.fallDamage *= (eventPlayer.getMaxHealthOfType(Health.NORMAL) + eventPlayer.getMaxHealthOfType(Health.ARMOR) + eventPlayer.getMaxHealthOfType(Health.SHIELDS)) / 100
            if RANDOM_SPREAD_PERCENTAGE > 0:
                eventPlayer.fallDamage *= random.uniform(1 - (RANDOM_SPREAD_PERCENTAGE/100), 1 + (RANDOM_SPREAD_PERCENTAGE/100))

        # deal the damage
        # WORKSHOP BUG: passive healing can occur between these next three actions, leading to slight inaccuracies w.r.t. fall damage stats.
        eventPlayer.fallDamageTaken = eventPlayer.getHealth()
        damage(eventPlayer, eventPlayer.recentKnockbacker if eventPlayer.recentKnockbacker != null else eventPlayer, eventPlayer.fallDamage)
        eventPlayer.fallDamageTaken -= eventPlayer.getHealth()
        # this extra step is needed to handle a race condition with bap lamp where the result becomes negative.
        eventPlayer.fallDamageTaken = max(0, eventPlayer.fallDamageTaken)
        
        playEffect(getAllPlayers(), DynamicEffect.SOLDIER_SPRINT_START_SOUND, Color.BLACK, eventPlayer, eventPlayer.fallVelocity * 10)
        playEffect(getAllPlayers(), DynamicEffect.BAD_EXPLOSION, Color.ORANGE, eventPlayer.getPosition(), eventPlayer.fallVelocity * 0.03)

        if LOG_STATS and isGameInProgress():
            statFallDamageTaken += eventPlayer.fallDamageTaken
            statFallDamageTakenPerHero[getAllHeroes().index(eventPlayer.getCurrentHero())] += eventPlayer.fallDamageTaken

        # fall deaths
        if eventPlayer.isDead():

            playEffect(getAllPlayers(), DynamicEffect.DOOMFIST_METEOR_STRIKE_IMPACT_SOUND, Color.BLACK, eventPlayer, eventPlayer.fallVelocity)
            playEffect(getAllPlayers(), DynamicEffect.RING_EXPLOSION, Color.ORANGE, eventPlayer.getPosition(), eventPlayer.fallVelocity * 0.2)

            if ANNOUNCE_FALL_DEATHS: smallMessage(getAllPlayers(), "{0} {1} hit the ground too hard".format(heroIcon(eventPlayer.getCurrentHero()), eventPlayer))
            
            if LOG_STATS and isGameInProgress():
                statFallDeaths++
                statFallDeathsPerHero[getAllHeroes().index(eventPlayer.getCurrentHero())]++
                statFallDeathsTimeline.append("[{0}] {1} ({2}) died of fall damage{3} • landed at {4} m/s • took {5} damage".format(toTimestamp(statReplayDuration),
                                                                                                                                    eventPlayer,
                                                                                                                                    eventPlayer.getCurrentHero(),
                                                                                                                                    " due to {0} ({1})".format(eventPlayer.recentKnockbacker, eventPlayer.recentKnockbacker.getCurrentHero()) if eventPlayer.recentKnockbacker != null else "",
                                                                                                                                    eventPlayer.fallVelocity,
                                                                                                                                    eventPlayer.fallDamageTaken))

    skip:

    # print debug feed
    if DEBUG:
        hudSubheader(eventPlayer, "LANDED AT {0} m/s  •  TOOK {1} DAMAGE {2}".format(eventPlayer.fallVelocity, eventPlayer.fallDamageTaken, Math.LOTS_OF_SPACES), HudPosition.LEFT, eventPlayer.debug_feed_num, rgb(255, 160, 170) if eventPlayer.fallDamageTaken > 0 else rgb(160, 255, 170) if eventPlayer.fallVelocity > VELOCITY_THRESHOLD else rgb(220, 220, 220), HudReeval.NONE)
        if len(eventPlayer.debug_feed_array) >= DEBUG_FEED_MAX:
            destroyHudText(eventPlayer.debug_feed_array[eventPlayer.debug_feed_num % DEBUG_FEED_MAX])
        eventPlayer.debug_feed_array[eventPlayer.debug_feed_num % DEBUG_FEED_MAX] = getLastCreatedText()
        eventPlayer.debug_feed_num++

    # we're done, reset state
    eventPlayer.fallVelocity = 0
    eventPlayer.fallDamage = 0
    eventPlayer.fallDamageTaken = 0
    if eventPlayer.fallImmunityState == FallImmunity.UNTIL_ON_GROUND:
        eventPlayer.fallImmunityState = FallImmunity.NONE
    eventPlayer.recentKnockbacker = null


#############################
###    IMMUNITY CASES     ###
#############################

rule "IMMUNITY: Floating Heroes":
    @Event eachPlayer
    @Condition FLOATING_HEROES_ALWAYS_IMMUNE == true
    @Condition eventPlayer.hasSpawned() == true
    
    # wait for the hero change.
    waitUntil(eventPlayer.getCurrentHero() != evalOnce(eventPlayer.getCurrentHero()), Math.INFINITY)
    
    # flag the player as floating or non-floating.
    if eventPlayer.getCurrentHero() in C_FLOATING_HEROES:
        eventPlayer.fallImmunityState = FallImmunity.ALWAYS_IMMUNE
    else:
        eventPlayer.fallImmunityState = FallImmunity.NONE

    goto RULE_START
        

rule "IMMUNITY: Winston Leap":
    @Event eachPlayer
    @Hero winston
    @Condition eventPlayer.fallImmunityState != FallImmunity.ALWAYS_IMMUNE
    @Condition eventPlayer.isUsingAbility1() == true

    eventPlayer.fallImmunityState = FallImmunity.UNTIL_ON_GROUND


rule "IMMUNITY: Doomfist Slam":
    @Event eachPlayer
    @Hero doomfist
    @Condition eventPlayer.fallImmunityState != FallImmunity.ALWAYS_IMMUNE
    @Condition eventPlayer.isUsingAbility1() == true

    eventPlayer.fallImmunityState = FallImmunity.UNTIL_ON_GROUND
    waitUntil(eventPlayer.isUsingAbility1() == false, Math.INFINITY)
    eventPlayer.fallImmunityState = FallImmunity.NONE


rule "IMMUNITY: Mauga Charge":
    @Event eachPlayer
    @Hero mauga
    @Condition eventPlayer.fallImmunityState != FallImmunity.ALWAYS_IMMUNE
    @Condition eventPlayer.isUsingAbility1() == true

    eventPlayer.fallImmunityState = FallImmunity.SCRIPTED
    waitUntil(eventPlayer.isUsingAbility1() == false, Math.INFINITY)
    eventPlayer.fallImmunityState = FallImmunity.NONE


rule "IMMUNITY: Venture Burrow":
    @Event eachPlayer
    @Hero venture
    @Condition eventPlayer.fallImmunityState != FallImmunity.ALWAYS_IMMUNE
    @Condition eventPlayer.isUsingAbility1() == true

    eventPlayer.fallImmunityState = FallImmunity.SCRIPTED
    waitUntil(eventPlayer.isUsingAbility1() == false, Math.INFINITY)
    eventPlayer.fallImmunityState = FallImmunity.NONE


rule "IMMUNITY: Wrecking Ball Piledriver":
    @Event eachPlayer
    @Hero hammond
    @Condition eventPlayer.fallImmunityState != FallImmunity.ALWAYS_IMMUNE
    @Condition eventPlayer.fallVelocity > 90 # piledriver sets fall velocity to 98

    eventPlayer.fallImmunityState = FallImmunity.SCRIPTED

    # HACK: we can't directly detect when ball is using piledriver, but we can detect when he is falling faster than terminal velocity.
    # if he slows down the ability has ended, but we wait a bit to clear the immunity flag to cover "surf" landings.
    # note: the wait duration must be less than the wait timeout for sigma's ult immunity (0.5s)
    waitUntil(eventPlayer.fallVelocity < C_TERMINAL_VELOCITY, 10)
    wait(0.4)
    eventPlayer.fallImmunityState = FallImmunity.NONE


rule "IMMUNITY: Inside Sigma Ult":
    @Event playerReceivedKnockback
    @Condition eventPlayer.fallImmunityState != FallImmunity.ALWAYS_IMMUNE
    @Condition attacker.getCurrentHero() == Hero.SIGMA
    @Condition eventAbility == Button.ULTIMATE

    # HACK: let other immunity flags expire before applying this one
    waitUntil(eventPlayer.fallImmunityState == FallImmunity.NONE, 0.5)
    eventPlayer.fallImmunityState = FallImmunity.SCRIPTED

    waitUntil(attacker.isUsingUltimate() == false, 5)
    eventPlayer.fallImmunityState = FallImmunity.NONE


#########################
###    STATISTICS     ###
#########################

rule "STATISTICS: Replay Duration":
    @Event global
    @Condition LOG_STATS == true
    @Condition isInSetup() == true

    # time elapsed since the server began recording the replay
    chase(statReplayDuration, Math.INFINITY, rate=1, ChaseReeval.NONE)


rule "STATISTICS: Match Duration Resume":
    @Event global
    @Condition LOG_STATS == true
    @Condition isGameInProgress() == true

    # the built-in match timer is sometimes active while stats are not being tracked
    # we only care about time where stats are tracked
    chase(statMatchDuration, Math.INFINITY, rate=1, ChaseReeval.NONE)


rule "STATISTICS: Match Duration Pause":
    @Event global
    @Condition LOG_STATS == true
    @Condition isGameInProgress() == false

    stopChasingVariable(statMatchDuration)


rule "STATISTICS: Display Final Stats":
    @Event global
    @Condition LOG_STATS == true
    @Condition isMatchComplete() == true

    bigMessage(getAllPlayers(), "Fall Damage: {0}   •   Fall Deaths: {1}".format(round(statFallDamageTaken), statFallDeaths))


rule "STATISTICS: Increment Deaths":
    @Event playerDied
    @Condition LOG_STATS == true
    @Condition isGameInProgress() == true

    statDeaths++
    statDeathsPerHero[getAllHeroes().index(eventPlayer.getCurrentHero())]++


rule "STATISTICS: Increment Damage Taken":
    @Event playerTookDamage
    @Condition LOG_STATS == true
    @Condition isGameInProgress() == true

    statDamageTaken += eventDamage
    statDamageTakenPerHero[getAllHeroes().index(eventPlayer.getCurrentHero())] += eventDamage


rule "STATISTICS: Detect Hero Swap":
    @Event eachPlayer
    @Condition LOG_STATS == true
    @Condition getAllHeroes().index(eventPlayer.getCurrentHero()) != eventPlayer.cachedHeroIndex

    eventPlayer.switchedHero = true


# I'd like to make this rule not suck someday, but for now it works.
rule "STATISTICS: Track Playtime of Each Hero":
    @Event eachPlayer
    @Condition LOG_STATS == true
    @Condition isGameInProgress() == true

    # array values cannot be chased, so we temporarily track time on a player variable.
    # to reduce server load, this value is only added to the array about once per second.
    # ideally we would add to the array less frequently, but if a player leaves the server we lose all their tracked time.
    chase(eventPlayer.t, Math.INFINITY, rate=1, ChaseReeval.NONE)
    
    # if the match ends or the player switches hero, add it sooner to store the accurate time.
    waitUntil(isGameInProgress() == false or eventPlayer.switchedHero == true, 1)

    # if the player hasn't spawned, they don't have a hero. add this "lost time" to the last array element + 1.
    statPlaytimePerHero[eventPlayer.cachedHeroIndex if eventPlayer.cachedHeroIndex != -1 else len(getAllHeroes())] += eventPlayer.t
    eventPlayer.t = 0

    if eventPlayer.switchedHero == true:
        eventPlayer.cachedHeroIndex = getAllHeroes().index(eventPlayer.getCurrentHero())
        eventPlayer.switchedHero = false

    if RULE_CONDITION: goto RULE_START
    
    # we stop chasing instead of re-evaluating the rate to 0 in order for the debug HUD to work.
    stopChasingVariable(eventPlayer.t)
    eventPlayer.cachedHeroIndex = -1


rule "STATISTICS: Write Stats to Log File":
    @Event global
    @Condition LOG_STATS == true
    @Condition isMatchComplete() == true

    wait(0.25)
    enableInspector()

    printLog("FALL DAMAGE PLAYTEST RESULTS\n")

    printLog("-------------------------------------------------\n")

    printLog("Session: Final")
    printLog("Fall Damage Formula: (eventPlayer.fallVelocity * eventPlayer.fallVelocity) / 15\n")

    printLog("Gamemode: {0}".format(getCurrentGamemode()))
    printLog("Map: {0}".format(getCurrentMap()))
    printLog("Match Duration: {0}\n".format(statMatchDuration))

    printLog("-------------------------------------------------\n")

    printLog("Damage Taken: {0}".format(statDamageTaken))
    printLog("Fall Damage Taken: {0} ({1}%)\n".format(statFallDamageTaken, (statFallDamageTaken/statDamageTaken) * 100))

    printLog("Deaths: {0}".format(statDeaths))
    printLog("Fall Deaths: {0} ({1}%)\n".format(statFallDeaths, (statFallDeaths/statDeaths) * 100))
    wait()

    # mark the end of hero arrays to pad empty elements with zeros
    statDamageTakenPerHero[len(getAllHeroes())] = -1
    statFallDamageTakenPerHero[len(getAllHeroes())] = -1
    statDeathsPerHero[len(getAllHeroes())] = -1
    statFallDeathsPerHero[len(getAllHeroes())] = -1
    statPlaytimePerHero[len(getAllHeroes()) + 1] = -1 # extra element stores "lost time" where the player has no hero
    wait()

    # array strings need to be built manually (thanks provoxin for solution)
    logString = "["
    for i in range(0, len(statDamageTakenPerHero) - 1):
        logString = "{0}{1}{2}".format(logString, "" if i == 0 else ", ", statDamageTakenPerHero[i])
    logString = "{0}]".format(logString)

    printLog("Damage Taken Per Hero: {0}\n".format(logString))
    wait()

    logString = "["
    for i in range(0, len(statFallDamageTakenPerHero) - 1):
        logString = "{0}{1}{2}".format(logString, "" if i == 0 else ", ", statFallDamageTakenPerHero[i])
    logString = "{0}]".format(logString)

    printLog("Fall Damage Taken Per Hero: {0}\n".format(logString))
    wait()

    logString = "["
    for i in range(0, len(statDeathsPerHero) - 1):
        logString = "{0}{1}{2}".format(logString, "" if i == 0 else ", ", statDeathsPerHero[i])
    logString = "{0}]".format(logString)

    printLog("Deaths Per Hero: {0}\n".format(logString))
    wait()

    logString = "["
    for i in range(0, len(statFallDeathsPerHero) - 1):
        logString = "{0}{1}{2}".format(logString, "" if i == 0 else ", ", statFallDeathsPerHero[i])
    logString = "{0}]".format(logString)

    printLog("Fall Deaths Per Hero: {0}\n".format(logString))
    wait()

    logString = "["
    for i in range(0, len(statPlaytimePerHero) - 1):
        logString = "{0}{1}{2}".format(logString, "" if i == 0 else ", ", statPlaytimePerHero[i])
    logString = "{0}]".format(logString)

    printLog("Time Played Per Hero: {0}\n".format(logString))
    wait()

    printLog("-------------------------------------------------\n")

    printLog("Fall Deaths Timeline:\n")

    for i in range(0, len(statFallDeathsTimeline)):
        printLog(statFallDeathsTimeline[i])


####################
###    DEBUG     ###
####################

rule "DEBUG: Display Velocity":
    @Event global
    @Condition DEBUG == true

    hudText(localPlayer, iconString(Icon.ARROW_DOWN), "Fall Velocity {0}".format(Math.LOTS_OF_SPACES), "{0} m/s".format(localPlayer.fallVelocity), HudPosition.LEFT, -99, updateEveryTick(Color.ROSE if localPlayer.fallVelocity > VELOCITY_THRESHOLD and localPlayer.fallVelocity < C_TERMINAL_VELOCITY else rgb(220, 220, 220)), rgb(220, 220, 220), Color.WHITE, HudReeval.VISIBILITY_STRING_AND_COLOR, SpecVisibility.NEVER)
    hudSubtext(localPlayer, "•", HudPosition.LEFT, -98, rgba(0, 0, 0, 0), HudReeval.VISIBILITY)


rule "DEBUG: Display Last Source of Knockback":
    @Event global
    @Condition DEBUG == true

    hudSubheader(localPlayer, "•", HudPosition.LEFT, 1000000+100, rgba(0, 0, 0, 0), HudReeval.VISIBILITY)
    hudSubheader(localPlayer, "Recent Knockbacker: {0} {1}".format("" if localPlayer.recentKnockbacker == null else localPlayer.recentKnockbacker, Math.LOTS_OF_SPACES), HudPosition.LEFT, 1000000+101, rgb(220, 220, 220), HudReeval.VISIBILITY_AND_STRING)

    
rule "DEBUG: Display Immunity Status":
    @Event global
    @Condition DEBUG == true

    hudSubheader(localPlayer, "•", HudPosition.LEFT, 1000000+200, rgba(0, 0, 0, 0), HudReeval.VISIBILITY)
    hudSubheader(localPlayer, "Fall Immunity: {0} {1}".format(["NONE","UNTIL_ON_GROUND","SCRIPTED","ALWAYS_IMMUNE"][localPlayer.fallImmunityState], Math.LOTS_OF_SPACES), HudPosition.LEFT, 1000000+201, rgb(160, 255, 170) if localPlayer.fallImmunityState != FallImmunity.NONE else rgb(255, 160, 170), HudReeval.VISIBILITY_STRING_AND_COLOR)


rule "DEBUG: Display Match Duration":
    @Event global
    @Condition DEBUG == true
    @Disabled

    hudSubheader(localPlayer, "•", HudPosition.LEFT, 1000000+300, rgba(0, 0, 0, 0), HudReeval.VISIBILITY)
    hudSubheader(localPlayer, "Match Duration: {0} {1}".format(toTimestamp(statMatchDuration), Math.LOTS_OF_SPACES), HudPosition.LEFT, 1000000+301, rgb(245, 235, 170) if isGameInProgress() == true else rgb(190, 190, 190), HudReeval.VISIBILITY_STRING_AND_COLOR)


rule "DEBUG: Display Replay Duration":
    @Event global
    @Condition DEBUG == true
    @Disabled

    hudSubheader(localPlayer, "•", HudPosition.LEFT, 1000000+400, rgba(0, 0, 0, 0), HudReeval.VISIBILITY)
    hudSubheader(localPlayer, "Replay Duration: {0} {1}".format(toTimestamp(statReplayDuration), Math.LOTS_OF_SPACES), HudPosition.LEFT, 1000000+401, rgb(245, 235, 170) if isGameInProgress() == true else rgb(190, 190, 190), HudReeval.VISIBILITY_STRING_AND_COLOR)

        
rule "DEBUG: Display In-Progress Stats":
    @Event global
    @Condition DEBUG == true
    @Condition LOG_STATS == true

    hudSubheader(localPlayer, "•", HudPosition.LEFT, 1000000+900, rgba(0, 0, 0, 0), HudReeval.VISIBILITY, SpecVisibility.ALWAYS)
    hudSubheader(localPlayer, "Total Fall Damage: {0} ({1}%) {2}".format(statFallDamageTaken, (statFallDamageTaken/statDamageTaken) * 100, Math.LOTS_OF_SPACES), HudPosition.LEFT, 1000000+901, rgb(80, 220, 255), HudReeval.VISIBILITY_AND_STRING, SpecVisibility.ALWAYS)
    hudSubheader(localPlayer, "Total Fall Deaths: {0} ({1}%) {2}".format(statFallDeaths, (statFallDeaths/statDeaths) * 100, Math.LOTS_OF_SPACES), HudPosition.LEFT, 1000000+902, rgb(110, 180, 255), HudReeval.VISIBILITY_AND_STRING, SpecVisibility.ALWAYS)


# super useful, but causes frame stuttering.

# rule "DEBUG: Display Hero Playtime":
#     @Event global

#     hudSubtext(localPlayer, "{0} ({1}){2}".format(getAllHeroes()[localPlayer.cachedHeroIndex] if localPlayer.cachedHeroIndex != -1 else "NULL", localPlayer.cachedHeroIndex, Math.LOTS_OF_SPACES), HudPosition.LEFT, -2, Color.ORANGE, HudReeval.VISIBILITY_AND_STRING)
#     hudSubtext(localPlayer, "{0}{1}".format(localPlayer.t, Math.LOTS_OF_SPACES), HudPosition.LEFT, -1, Color.SKY_BLUE, HudReeval.VISIBILITY_AND_STRING)

#     statPlaytimePerHero[len(getAllHeroes()) + 1] = -1
#     wait()

#     for i in range(0, len(statPlaytimePerHero) - 1):
#         hudSubheader(localPlayer, "{0}: {1}{2}".format(getAllHeroes()[evalOnce(i)], statPlaytimePerHero[evalOnce(i)], Math.LOTS_OF_SPACES), HudPosition.LEFT, i, rgb(255-(i*2), 255-i, 255), HudReeval.VISIBILITY_AND_STRING)
#         wait()