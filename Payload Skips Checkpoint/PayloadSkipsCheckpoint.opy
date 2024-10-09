settings {
    "main": {
        "description": "Reliably force the payload to skip over a checkpoint, resulting in unintended game mode behavior.\n\nCode: X1Z2T\nLast updated: 2024-10-09",
        "modeName": "Payload Checkpoint Skipping"
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
    },
    "heroes": {
        "allTeams": {
            "tracer": {
                "ability1Cooldown%": 0
            },
            "enabledHeroes": [
                "tracer"
            ],
            "general": {
                "enableSpawningWithUlt": false,
                "ultGen%": 100,
                "combatUltGen%": 100,
                "passiveUltGen%": 100
            }
        }
    }
}

#Global variables

globalvar BUTTON_ARRAY
globalvar KEYBIND_CYCLE
globalvar KEYBIND_TELEPORT
globalvar KEYBIND_TOUCH

globalvar ROLL_BACK_TIME

globalvar payloadPosition
globalvar payloadProgress

globalvar setupName
globalvar setupPos
globalvar setupRot
globalvar setupCount

globalvar i

globalvar timer
globalvar barColor

globalvar map


#Player variables



####################
###    GLOBAL    ###
####################

rule "Init Global Variables":
    @Event global

    # user chosen keybinds
    BUTTON_ARRAY = [Button.INTERACT, Button.RELOAD, Button.MELEE, Button.ULTIMATE, Button.JUMP, Button.CROUCH]
    KEYBIND_CYCLE =     BUTTON_ARRAY[createWorkshopSetting(enum["INTERACT", "RELOAD", "MELEE", "ULTIMATE", "JUMP", "CROUCH"], "Keybinds", "Cycle Through Setups", 1, 0)]
    KEYBIND_TELEPORT =  BUTTON_ARRAY[createWorkshopSetting(enum["INTERACT", "RELOAD", "MELEE", "ULTIMATE", "JUMP", "CROUCH"], "Keybinds", "Teleport to Setup", 0, 1)]
    KEYBIND_TOUCH =     BUTTON_ARRAY[createWorkshopSetting(enum["INTERACT", "RELOAD", "MELEE", "ULTIMATE", "JUMP", "CROUCH"], "Keybinds", "Touch Payload", 2, 2)]

    # the amount of time it takes for the payload to roll backward
    ROLL_BACK_TIME = 10.00

    # contains setup coordinates for each map
    setupName = []
    setupPos = []
    setupRot = []
    setupCount = 0

    # the currently selected setup
    i = 0

    # used on HUD
    timer = 0
    barColor = Color.ROSE

    # store the current map to fire setup rules
    map = getCurrentMap()
    

rule "Init Player Variables":
    @Event eachPlayer


rule "Skip Assemble Heroes":
    @Condition isAssemblingHeroes() == true
    
    setMatchTime(0)


rule "Skip Setup":
    @Condition isInSetup() == true
    
    setMatchTime(0)


rule "Set Timer to 10 Minutes":
    @Event eachPlayer
    @Condition eventPlayer.isHoldingButton(Button.RELOAD) == true
    
    wait(5, Wait.ABORT_WHEN_FALSE)
    setMatchTime(600)

    
rule "End Match & Save Replay":
    @Event eachPlayer
    @Condition eventPlayer.isHoldingButton(Button.CROUCH) == true
    @Condition eventPlayer.isHoldingButton(Button.MELEE) == true
    @Condition eventPlayer.isHoldingButton(Button.INTERACT) == true
    
    if (getCurrentGamemode() == Gamemode.CONTROL):
        declareRoundVictory(eventPlayer.getTeam())
    else:
        setMatchTime(5)


#####################
###    SCRIPTS    ###
#####################

def setup():
    @Name "Setup Subroutine"

    # setup coordinates depend on the map (thanks to Coathar for help)
    if (setupCount > 0):
        eventPlayer.teleport(setupPos[i])
        eventPlayer.setFacing(setupRot[i], Relativity.TO_WORLD)
    else:
        bigMessage(eventPlayer, "No setup available for {0}".format(map))


rule "Teleport to Setup Position":
    @Event eachPlayer
    @Condition eventPlayer.isHoldingButton(KEYBIND_TELEPORT) == true

    setup()


rule "Touch Payload":
    @Event eachPlayer
    @Condition eventPlayer.isOnObjective() == false
    @Condition eventPlayer.isHoldingButton(KEYBIND_TOUCH) == true

    # advance the progress bar on the HUD
    chase(timer, 100, duration=ROLL_BACK_TIME, ChaseReeval.NONE)

    # lock-out until the payload begins rolling backward after 10 seconds
    wait(ROLL_BACK_TIME, Wait.ABORT_WHEN_FALSE)

    # change the progress bar color
    barColor = Color.LIME_GREEN

    # touch the payload as soon as it begins rolling backward
    setup()
    eventPlayer.startThrottleInDirection(Vector.FORWARD, 1, Relativity.TO_PLAYER, Throttle.REPLACE_EXISTING, ThrottleReeval.NONE)
    wait(0.256)
    eventPlayer.stopThrottleInDirection()


rule "Reset HUD Timer":
    @Event eachPlayer
    @Condition eventPlayer.isOnObjective() == true or eventPlayer.isHoldingButton(KEYBIND_TOUCH) == false

    # reset the progress bar when the "touch payload" rule becomes false
    stopChasingVariable(timer)
    timer = 0
    barColor = Color.ROSE


rule "Cycle Through Setups":
    @Event eachPlayer
    @Condition setupCount > 1
    @Condition eventPlayer.isHoldingButton(KEYBIND_CYCLE) == true

    i += 1

    # cycle to the beginning if the maximum is reached
    if (i >= setupCount):
        i = 0


rule "HUD Variables":
    @Event global

    # if the payload position cannot be retrieved, display a user friendly message
    if (getPayloadPosition() != null):
        payloadPosition = getPayloadPosition()
        payloadProgress = "{0}%".format(getPayloadProgressPercentage())
    else:
        payloadPosition = "Unavailable"
        payloadProgress = "Unavailable"

    # loop every tick
    wait()
    goto RULE_START


rule "HUD Display":
    @Event global

    # debug information
    hudText(localPlayer, iconString(Icon.HAPPY), "Player Position                                      ", updateEveryTick(localPlayer.getPosition()), HudPosition.LEFT, 0, rgb(200, 200, 200), rgb(200, 200, 200), Color.WHITE, HudReeval.VISIBILITY_AND_STRING, SpecVisibility.NEVER)
    hudText(localPlayer, iconString(Icon.EYE), "Player Facing Direction                   ", updateEveryTick(localPlayer.getFacingDirection()), HudPosition.LEFT, 1, rgb(200, 200, 200), rgb(200, 200, 200), Color.WHITE, HudReeval.VISIBILITY_AND_STRING, SpecVisibility.NEVER)

    hudSubtext(localPlayer, "•", HudPosition.LEFT, 2, rgba(0, 0, 0, 0), HudReeval.VISIBILITY, SpecVisibility.NEVER)

    hudText(localPlayer, iconString(Icon.FLAG), "Payload Position                                   ", payloadPosition, HudPosition.LEFT, 3, rgb(200, 200, 200), rgb(200, 200, 200), Color.WHITE, HudReeval.VISIBILITY_AND_STRING, SpecVisibility.NEVER)
    hudText(localPlayer, iconString(Icon.BOLT), "Payload Progress                                ", payloadProgress, HudPosition.LEFT, 4, rgb(200, 200, 200), rgb(200, 200, 200), Color.WHITE, HudReeval.VISIBILITY_AND_STRING, SpecVisibility.NEVER)
    
    # script instructions
    progressBarHud(localPlayer, timer, "[{3}] Current setup: {0} ({1}/{2})\n[{4}] Teleport to the setup location\n[{5}] Hold to touch payload".format(setupName[i], i + 1, setupCount, buttonString(KEYBIND_CYCLE), buttonString(KEYBIND_TELEPORT), buttonString(KEYBIND_TOUCH)), HudPosition.RIGHT, -1, barColor, rgb(200, 200, 200), ProgressHudReeval.VISIBILITY_VALUES_AND_COLOR, SpecVisibility.NEVER)

    # reveal payload origin
    # createInWorldText(localPlayer, "•", payloadPosition, 4, Clip.NONE, WorldTextReeval.VISIBILITY_AND_POSITION, Color.WHITE, SpecVisibility.NEVER)


rule "Testing: Nudge Forward":
    @Event eachPlayer
    @Condition eventPlayer.isHoldingButton(Button.CROUCH) == false
    @Condition eventPlayer.isHoldingButton(Button.ULTIMATE) == true
    @Disabled

    eventPlayer.teleport(eventPlayer.getPosition() + (angleToDirection(horizontalAngleOfDirection(eventPlayer.getFacingDirection()), 0)) * 0.01)


rule "Testing: Nudge Backward":
    @Event eachPlayer
    @Condition eventPlayer.isHoldingButton(Button.CROUCH) == true
    @Condition eventPlayer.isHoldingButton(Button.ULTIMATE) == true
    @Disabled

    eventPlayer.teleport(eventPlayer.getPosition() - (angleToDirection(horizontalAngleOfDirection(eventPlayer.getFacingDirection()), 0)) * 0.01)


rule "Re-enable all heroes":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true

    eventPlayer.setAllowedHeroes(getAllHeroes())


############################
###    MAP SETUP DATA    ###
############################

rule "SETUP: Circuit Royal":
    @Event global
    @Condition map == Map.CIRCUIT_ROYAL
    
    setupName[0] = "Checkpoint A"
    setupPos[0] = vect(3.21, 5.82, -3.01)
    setupRot[0] = vect(0.48, 0, -0.88)
    
    setupName[1] = "Checkpoint B"
    setupPos[1] = vect(48.51, 15.01, -8.21)
    setupRot[1] = vect(0.78, -0.01, -0.63)


rule "SETUP: Dorado":
    @Event global
    @Condition map == Map.DORADO
    
    setupName[0] = "Checkpoint A"
    setupPos[0] = vect(66.58, 6.63, -15.21)
    setupRot[0] = vect(0.89, 0, 0.41)
    
    setupName[1] = "Checkpoint B"
    setupPos[1] = vect(122.60, 10.83, 24.10)
    setupRot[1] = vect(0.97, 0, 0.24)
    
    setupName[2] = "Gate B Open"
    setupPos[2] = vect(139.12, 11, 28.22)
    setupRot[2] = vect(0.97, 0, 0.24)


rule "SETUP: Havana":
    @Event global
    @Condition map == Map.HAVANA
    
    setupName[0] = "Checkpoint A"
    setupPos[0] = vect(-17.81, 5.85, -79.27)
    setupRot[0] = vect(1, 0, 0)
    
    setupName[1] = "Checkpoint B"
    setupPos[1] = vect(52.49, 5.82, -83.25)
    setupRot[1] = vect(1, 0, 0)


rule "SETUP: Junkertown":
    @Event global
    @Condition map == Map.JUNKERTOWN
    
    setupName[0] = "Checkpoint A"
    setupPos[0] = vect(-29.23, 4.43, -47.28)
    setupRot[0] = vect(-0.50, 0, -0.86)

    setupName[1] = "Gate A Close"
    setupPos[1] = vect(-35.27, 4.69, -63.31)
    setupRot[1] = vect(-0.81, 0, -0.58)
    
    setupName[2] = "Checkpoint B"
    setupPos[2] = vect(-56.40, 7.26, -96.93)
    setupRot[2] = vect(-0.20, 0, -0.98)
    
    setupName[3] = "Gate B Close"
    setupPos[3] = vect(-56.25, 7.51, -113.07)
    setupRot[3] = vect(-0.48, 0, -0.87)


rule "SETUP: Rialto":
    @Event global
    @Condition map == Map.RIALTO
    
    setupName[0] = "Checkpoint A"
    setupPos[0] = vect(45.77, -0.40, -69.0)
    setupRot[0] = vect(-1, 0, 0)

    setupName[1] = "Checkpoint B"
    setupPos[1] = vect(-20.33, -1.40, -67.17)
    setupRot[1] = vect(-1, 0, 0)


rule "SETUP: Route 66":
    @Event global
    @Condition map == Map.ROUTE66
    
    setupName[0] = "Checkpoint A"
    setupPos[0] = vect(18.41, 2.09, -1.01)
    setupRot[0] = vect(-0.59, -0.03, -0.80)
    
    setupName[1] = "Checkpoint B"
    setupPos[1] = vect(-48.74, 3.31, -14.36)
    setupRot[1] = vect(-0.51, 0, 0.86)


rule "SETUP: Shambali Monastery":
    @Event global
    @Condition map == Map.SHAMBALI_MONASTERY
    
    setupName[0] = "Checkpoint A"
    setupPos[0] = vect(-28.21, 14.76, 80.82)
    setupRot[0] = vect(1, 0, 0.06)
    
    setupName[1] = "Checkpoint B"
    setupPos[1] = vect(-9.74, 24.88, 116.42)
    setupRot[1] = vect(-0.01, 0, 1)


rule "SETUP: Watchpoint: Gibraltar":
    @Event global
    @Condition map == Map.WATCHPOINT_GIBRALTAR
    
    setupName[0] = "Checkpoint A"
    setupPos[0] = vect(19.97, -5.16, -78.48)
    setupRot[0] = vect(0.69, 0.03, 0.72)
    
    setupName[1] = "Gate A Close"
    setupPos[1] = vect(28.98, -5.16, -65.98)
    setupRot[1] = vect(0.99, -0.04, 0.10)
    
    setupName[2] = "Checkpoint B"
    setupPos[2] = vect(65.58, -3.14, -33.22)
    setupRot[2] = vect(0.70, 0, 0.71)






rule "SETUP: Blizzard World":
    @Event global
    @Condition map == Map.BLIZZ_WORLD or map == Map.BLIZZ_WORLD_WINTER
    
    setupName[0] = "Checkpoint"
    setupPos[0] = vect(-59.30, -0.40, 103.99)
    setupRot[0] = vect(0.63, 0, 0.77)


rule "SETUP: Eichenwalde":
    @Event global
    @Condition map == Map.EICHENWALDE or map == Map.EICHENWALDE_HALLOWEEN
    
    setupName[0] = "Gate Open"
    setupPos[0] = vect(20.97, 4.83, -58.32)
    setupRot[0] = vect(0.96, 0, -0.27)

    setupName[1] = "Checkpoint"
    setupPos[1] = vect(86.15, 12.66, -74.93)
    setupRot[1] = vect(0.25, 0, 0.97)


rule "SETUP: Hollywood":
    @Event global
    @Condition map == Map.HOLLYWOOD or map == Map.HOLLYWOOD_HALLOWEEN
    
    setupName[0] = "Checkpoint"
    setupPos[0] = vect(5.24, 1.85, -69.50)
    setupRot[0] = vect(-0.47, 0, -0.88)


rule "SETUP: King's Row":
    @Event global
    @Condition map == Map.KINGS_ROW or map == Map.KINGS_ROW_WINTER
    
    setupName[0] = "Checkpoint"
    setupPos[0] = vect(-93.11, 0.93, -9.77)
    setupRot[0] = vect(-0.98, 0, 0.17)


rule "SETUP: Midtown":
    @Event global
    @Condition map == Map.MIDTOWN
    
    setupName[0] = "Checkpoint"
    setupPos[0] = vect(56.11, 3.58, -22.06)
    setupRot[0] = vect(1, 0, 0)


rule "SETUP: Numbani":
    @Event global
    @Condition map == Map.NUMBANI
    
    setupName[0] = "Checkpoint"
    setupPos[0] = vect(147.68, -4.17, 15.74)
    setupRot[0] = vect(0.58, 0, -0.81)


rule "SETUP: Paraiso":
    @Event global
    @Condition map == Map.PARAISO
    
    setupName[0] = "Checkpoint"
    setupPos[0] = vect(2.40, 4.83, -94.28)
    setupRot[0] = vect(0.88, 0, 0.47)





rule "SETUP: STORE COUNT":
    @Event global

    wait()
    setupCount = len(setupName)