settings {
    "main": {
        "description": "Create and destroy bots that press buttons.\n\nCode: C2N23\nLast updated: 2024-10-09",
        "modeName": "Spawn Bots 2.0"
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
    }
}

#!extension spawnMoreDummyBots

#######################
###    VARIABLES    ###
#######################

# current mode
enum Mode:
    PLAY,
    EDIT,

    TOTAL_MODES

# hero colors for style ✨
globalvar HERO_COLORS = [
    rgb(124, 62, 82),   # Reaper
    rgb(214, 145, 65),  # Tracer
    rgb(236, 233, 189), # Mercy
    rgb(185, 180, 137), # Hanzo
    rgb(191, 115, 110), # Torbjorn
    rgb(148, 161, 165), # Reinhardt
    rgb(60, 126, 204),  # Pharah
    rgb(160, 169, 186), # Winston
    rgb(157, 105, 166), # Widowmaker
    rgb(124, 143, 122), # Bastion
    rgb(145, 187, 209), # Symmetra
    rgb(236, 229, 128), # Zenyatta
    rgb(149, 239, 66),  # Genji
    rgb(179, 139, 80),  # Roadhog
    rgb(173, 90, 95),   # Cassidy
    rgb(236, 190, 82),  # Junkrat
    rgb(231, 130, 184), # Zarya
    rgb(109, 121, 149), # Soldier: 76
    rgb(132, 201, 81),  # Lucio
    rgb(237, 147, 199), # D.Va
    rgb(109, 171, 235), # Mei
    rgb(118, 93, 189),  # Sombra
    rgb(131, 83, 76),   # Doomfist
    rgb(110, 137, 177), # Ana
    rgb(69, 139, 66),   # Orisa
    rgb(139, 98, 94),   # Brigitte
    rgb(151, 113, 228), # Moira
    rgb(219, 147, 66),  # Wrecking Ball
    rgb(198, 28, 65),   # Sojourn
    rgb(105, 105, 104), # Ashe
    rgb(154, 202, 243), # Echo
    rgb(85, 178, 204),  # Baptiste
    rgb(212, 135, 143), # Kiriko
    rgb(142, 181, 215), # Junker Queen
    rgb(148, 160, 165), # Sigma
    rgb(157, 140, 208), # Ramattra
    rgb(224, 182, 198), # Lifeweaver
    rgb(220, 132, 125), # Mauga
    rgb(183, 168, 142), # Illari
    rgb(121, 97, 78),   # Venture
    rgb(114, 31, 163)   # Juno
]

# heroes with ultimates that require extra logic for bots to use
globalvar TRANSFORMATIVE_ULTS = [
    Hero.DOOMFIST,
    Hero.ORISA,
    Hero.ROADHOG,
    Hero.SIGMA,
    Hero.BASTION,
    Hero.JUNKRAT,
    Hero.SOJOURN,
    Hero.SOLDIER,
    Hero.TORBJORN,
    Hero.ILLARI,
    Hero.VENTURE
]

globalvar BUILDABLE_ULTS = [
    Hero.SYMMETRA,
    Hero.BAPTISTE,
    Hero.LIFEWEAVER
]

# all buttons in a sensible order
globalvar BUTTONS = [
    Button.PRIMARY_FIRE,
    Button.SECONDARY_FIRE,
    Button.ABILITY_1,
    Button.ABILITY_2,
    Button.ULTIMATE,
    Button.JUMP,
    Button.MELEE,
    Button.CROUCH,
    Button.RELOAD,
    Button.INTERACT
]

# user chosen keybinds
globalvar KEYBIND_MENU =                  BUTTONS[createWorkshopSetting(enum["PRIMARY FIRE", "SECONDARY FIRE", "ABILITY 1", "ABILITY 2", "ULTIMATE", "JUMP", "MELEE", "CROUCH", "RELOAD", "INTERACT"], "Bot Menu Keybinds", "Toggle Bot Menu", 8, 0)]
globalvar KEYBIND_CREATE_BOT =            BUTTONS[createWorkshopSetting(enum["PRIMARY FIRE", "SECONDARY FIRE", "ABILITY 1", "ABILITY 2", "ULTIMATE", "JUMP", "MELEE", "CROUCH", "RELOAD", "INTERACT"], "Bot Menu Keybinds", "Create Bot", 1, 1)]
globalvar KEYBIND_DESTROY_BOT =           BUTTONS[createWorkshopSetting(enum["PRIMARY FIRE", "SECONDARY FIRE", "ABILITY 1", "ABILITY 2", "ULTIMATE", "JUMP", "MELEE", "CROUCH", "RELOAD", "INTERACT"], "Bot Menu Keybinds", "Destroy Bot", 0, 2)]
globalvar KEYBIND_CYCLE_HERO_FORWARD =    BUTTONS[createWorkshopSetting(enum["PRIMARY FIRE", "SECONDARY FIRE", "ABILITY 1", "ABILITY 2", "ULTIMATE", "JUMP", "MELEE", "CROUCH", "RELOAD", "INTERACT"], "Bot Menu Keybinds", "Cycle Hero Forward", 6, 3)]
globalvar KEYBIND_CYCLE_HERO_BACK =       BUTTONS[createWorkshopSetting(enum["PRIMARY FIRE", "SECONDARY FIRE", "ABILITY 1", "ABILITY 2", "ULTIMATE", "JUMP", "MELEE", "CROUCH", "RELOAD", "INTERACT"], "Bot Menu Keybinds", "Cycle Hero Backward", 2, 4)]
globalvar KEYBIND_CYCLE_BUTTON_FORWARD =  BUTTONS[createWorkshopSetting(enum["PRIMARY FIRE", "SECONDARY FIRE", "ABILITY 1", "ABILITY 2", "ULTIMATE", "JUMP", "MELEE", "CROUCH", "RELOAD", "INTERACT"], "Bot Menu Keybinds", "Cycle Button Forward", 3, 5)]
globalvar KEYBIND_CYCLE_BUTTON_BACK =     BUTTONS[createWorkshopSetting(enum["PRIMARY FIRE", "SECONDARY FIRE", "ABILITY 1", "ABILITY 2", "ULTIMATE", "JUMP", "MELEE", "CROUCH", "RELOAD", "INTERACT"], "Bot Menu Keybinds", "Cycle Button Backward", 4, 6)]
globalvar KEYBIND_SWAP_TEAM =             BUTTONS[createWorkshopSetting(enum["PRIMARY FIRE", "SECONDARY FIRE", "ABILITY 1", "ABILITY 2", "ULTIMATE", "JUMP", "MELEE", "CROUCH", "RELOAD", "INTERACT"], "Bot Menu Keybinds", "Swap Team", 7, 7)]
globalvar KEYBIND_PRESS_BUTTON =          BUTTONS[createWorkshopSetting(enum["PRIMARY FIRE", "SECONDARY FIRE", "ABILITY 1", "ABILITY 2", "ULTIMATE", "JUMP", "MELEE", "CROUCH", "RELOAD", "INTERACT"], "Bot Menu Keybinds", "Press Button", 9, 8)]
globalvar KEYBIND_RESET_COOLDOWNS =       BUTTONS[createWorkshopSetting(enum["PRIMARY FIRE", "SECONDARY FIRE", "ABILITY 1", "ABILITY 2", "ULTIMATE", "JUMP", "MELEE", "CROUCH", "RELOAD", "INTERACT"], "Utility Keybinds", "Reset All Cooldowns", 6, 9)]
globalvar KEYBIND_CHANGE_HERO =           BUTTONS[createWorkshopSetting(enum["PRIMARY FIRE", "SECONDARY FIRE", "ABILITY 1", "ABILITY 2", "ULTIMATE", "JUMP", "MELEE", "CROUCH", "RELOAD", "INTERACT"], "Utility Keybinds", "Change Hero (Hold)", 6, 10)]

globalvar dummies = []
globalvar i = 0

globalvar isFFA = getCurrentGamemode() == Gamemode.FFA or getCurrentGamemode() == Gamemode.SNOWBALL_FFA or getCurrentGamemode() == Gamemode.BOUNTY_HUNTER

playervar mode = Mode.PLAY
playervar showHUD = false
playervar showInstructions = true
playervar heroIndex = 0
playervar buttonIndex = 0
playervar teamIndex = 1

playervar entityHit = null

# Dummy Bots (do not initialize with values)

playervar buttonToPress
playervar pressButton
playervar spawnFacing

# Base Utilities

playervar isChangingHero = false
playervar pos = vect(0, 0, 0)
playervar rot = vect(0, 0, 0)


##################
###    BASE    ###
##################

rule "Disable Inspector":
    @Event global

    disableInspector()


rule "Change Hero Anywhere":
    @Event eachPlayer
    @Condition eventPlayer.isDummy() == false
    @Condition eventPlayer.isHoldingButton(KEYBIND_CHANGE_HERO) == true

    wait(1, Wait.ABORT_WHEN_FALSE)
    eventPlayer.pos = eventPlayer.getPosition()
    eventPlayer.rot = eventPlayer.getFacingDirection()
    eventPlayer.setAllowedHeroes([x for x in getAllHeroes() if x != eventPlayer.getCurrentHero()])
    eventPlayer.setAllowedHeroes(getAllHeroes())
    wait()
    eventPlayer.isChangingHero = true


rule "Restore Position and Facing":
    @Event eachPlayer
    @Condition eventPlayer.isDummy() == false
    @Condition eventPlayer.isChangingHero == true
    @Condition eventPlayer.hasSpawned() == true

    wait()
    eventPlayer.teleport(eventPlayer.pos)
    eventPlayer.setFacing(eventPlayer.rot, Relativity.TO_WORLD)
    eventPlayer.isChangingHero = false


rule "Reset All Cooldowns":
    @Event eachPlayer
    @Condition eventPlayer.isHoldingButton(KEYBIND_RESET_COOLDOWNS) == true

    getAllPlayers().setUltCharge(100)
    getAllPlayers().setAbilityCooldown(Button.ABILITY_1, 0)
    getAllPlayers().setAbilityCooldown(Button.ABILITY_2, 0)
    getAllPlayers().setAbilityCooldown(Button.SECONDARY_FIRE, 0)
    getAllPlayers().setAbilityCooldown(Button.CROUCH, 0)
    getAllPlayers().setAbilityCooldown(Button.JUMP, 0)


rule "Skip Assemble Heroes":
    @Condition isAssemblingHeroes() == true
    
    setMatchTime(0)


rule "Skip Setup":
    @Condition isInSetup() == true
    
    setMatchTime(0)
    
    
rule "End Match & Save Replay":
    @Event eachPlayer
    @Condition eventPlayer.isHoldingButton(Button.CROUCH) == true
    @Condition eventPlayer.isHoldingButton(Button.MELEE) == true
    @Condition eventPlayer.isHoldingButton(Button.INTERACT) == true
    
    wait(0.50, Wait.ABORT_WHEN_FALSE)

    if (getCurrentGamemode() == Gamemode.CONTROL):
        declareRoundVictory(eventPlayer.getTeam())
    else:
        setMatchTime(5)


##################
###    BOTS    ###
##################

def buildBotArray():
    dummies = [x for x in getAllPlayers() if x.isDummy()]
    

rule "Instructions HUD":
    @Event global
    
    hudSubheader(localPlayer if localPlayer.showInstructions else null, "TOGGLE BOT MENU", HudPosition.TOP, 98, rgb(255, 170, 30), HudReeval.VISIBILITY)
    hudSubtext(localPlayer if localPlayer.showInstructions else null, "[{0}] + [{1}]".format(buttonString(KEYBIND_MENU), buttonString(KEYBIND_PRESS_BUTTON)), HudPosition.TOP, 99, Color.WHITE, HudReeval.VISIBILITY_AND_STRING)


rule "Edit Mode HUD":
    @Event global

    # hero selection
    hudText(localPlayer if localPlayer.showHUD else null, heroIcon(getAllHeroes()[localPlayer.heroIndex]), "<— [{0}] PREV     NEXT [{1}] —> {2}".format(buttonString(KEYBIND_CYCLE_HERO_BACK), buttonString(KEYBIND_CYCLE_HERO_FORWARD), Math.LOTS_OF_SPACES), getAllHeroes()[localPlayer.heroIndex], HudPosition.LEFT, 1, HERO_COLORS[localPlayer.heroIndex], rgb(210, 210, 210), rgb(255, 255, 255), HudReeval.VISIBILITY_STRING_AND_COLOR)
    hudSubheader(localPlayer if localPlayer.showHUD else null, "•", HudPosition.LEFT, 2, rgba(0, 0, 0, 0), HudReeval.VISIBILITY)

    # button selection
    hudText(localPlayer if localPlayer.showHUD else null, buttonString(BUTTONS[localPlayer.buttonIndex]), "<— [{0}] PREV     NEXT [{1}] —> {2}".format(buttonString(KEYBIND_CYCLE_BUTTON_BACK), buttonString(KEYBIND_CYCLE_BUTTON_FORWARD), Math.LOTS_OF_SPACES), BUTTONS[localPlayer.buttonIndex], HudPosition.LEFT, 3, rgb(210, 210, 210), rgb(210, 210, 210), rgb(255, 255, 255), HudReeval.VISIBILITY_AND_STRING)
    hudSubheader(localPlayer if localPlayer.showHUD else null, "•", HudPosition.LEFT, 4, rgba(0, 0, 0, 0), HudReeval.VISIBILITY)

    # team selection (non-FFA only)
    hudText(localPlayer if localPlayer.showHUD and not isFFA else null, "♪", "[{0}] SWAP TEAM {1}".format(buttonString(KEYBIND_SWAP_TEAM), Math.LOTS_OF_SPACES), "{0}".format([Team.1, Team.2][localPlayer.teamIndex]), HudPosition.LEFT, 5, rgb(37, 212, 252) if localPlayer.teamIndex == 0 else rgb(239, 47, 82), rgb(210, 210, 210), rgb(255, 255, 255), HudReeval.VISIBILITY_STRING_AND_COLOR)
    hudSubheader(localPlayer if localPlayer.showHUD and not isFFA else null, "•", HudPosition.LEFT, 6, rgba(0, 0, 0, 0), HudReeval.VISIBILITY)

    # create and destroy
    hudSubheader(localPlayer if localPlayer.showHUD else null, "[{0}] CREATE BOT {1}".format(buttonString(KEYBIND_CREATE_BOT), Math.LOTS_OF_SPACES), HudPosition.LEFT, 7, rgb(210, 210, 210), HudReeval.VISIBILITY_AND_STRING)
    hudSubheader(localPlayer if localPlayer.showHUD else null, "[{0}] DESTROY BOT (HOLD TO DESTROY ALL) {1}".format(buttonString(KEYBIND_DESTROY_BOT), Math.LOTS_OF_SPACES), HudPosition.LEFT, 8, rgb(210, 210, 210), HudReeval.VISIBILITY_AND_STRING)


rule "Enter Play Mode":
    @Event eachPlayer
    @Condition eventPlayer.isDummy() == false
    @Condition eventPlayer.mode == Mode.PLAY

    eventPlayer.showHUD = false
    
    eventPlayer.allowButton(KEYBIND_CREATE_BOT)
    eventPlayer.allowButton(KEYBIND_DESTROY_BOT)
    eventPlayer.allowButton(KEYBIND_CYCLE_BUTTON_BACK)
    eventPlayer.allowButton(KEYBIND_CYCLE_BUTTON_FORWARD)
    eventPlayer.allowButton(KEYBIND_CYCLE_HERO_BACK)
    eventPlayer.allowButton(KEYBIND_CYCLE_HERO_FORWARD)
    eventPlayer.allowButton(KEYBIND_SWAP_TEAM)
    eventPlayer.allowButton(KEYBIND_PRESS_BUTTON)
    eventPlayer.allowButton(KEYBIND_MENU)


rule "Enter Edit Mode":
    @Event eachPlayer
    @Condition eventPlayer.isDummy() == false
    @Condition eventPlayer.mode == Mode.EDIT

    eventPlayer.showHUD = true

    eventPlayer.disallowButton(KEYBIND_CREATE_BOT)
    eventPlayer.disallowButton(KEYBIND_DESTROY_BOT)
    eventPlayer.disallowButton(KEYBIND_CYCLE_BUTTON_BACK)
    eventPlayer.disallowButton(KEYBIND_CYCLE_BUTTON_FORWARD)
    eventPlayer.disallowButton(KEYBIND_CYCLE_HERO_BACK)
    eventPlayer.disallowButton(KEYBIND_CYCLE_HERO_FORWARD)
    eventPlayer.disallowButton(KEYBIND_SWAP_TEAM)
    eventPlayer.disallowButton(KEYBIND_PRESS_BUTTON)
    eventPlayer.disallowButton(KEYBIND_MENU)


rule "Toggle Mode":
    @Event eachPlayer
    @Condition eventPlayer.isDummy() == false
    @Condition eventPlayer.isHoldingButton(KEYBIND_MENU) == true
    @Condition eventPlayer.isHoldingButton(KEYBIND_PRESS_BUTTON) == true

    eventPlayer.mode = (eventPlayer.mode + 1) % Mode.TOTAL_MODES
    
    eventPlayer.showInstructions = false


rule "Cycle Hero Forward":
    @Event eachPlayer
    @Condition eventPlayer.isDummy() == false
    @Condition eventPlayer.mode == Mode.EDIT
    @Condition eventPlayer.isHoldingButton(KEYBIND_CYCLE_HERO_FORWARD) == true
    @Condition eventPlayer.heroIndex < len(getAllHeroes()) - 1

    eventPlayer.heroIndex++


rule "Cycle Hero Backward":
    @Event eachPlayer
    @Condition eventPlayer.isDummy() == false
    @Condition eventPlayer.mode == Mode.EDIT
    @Condition eventPlayer.isHoldingButton(KEYBIND_CYCLE_HERO_BACK) == true
    @Condition eventPlayer.heroIndex > 0

    eventPlayer.heroIndex--


rule "Cycle Button Forward":
    @Event eachPlayer
    @Condition eventPlayer.isDummy() == false
    @Condition eventPlayer.mode == Mode.EDIT
    @Condition eventPlayer.isHoldingButton(KEYBIND_CYCLE_BUTTON_FORWARD) == true
    @Condition eventPlayer.buttonIndex < len(BUTTONS) - 1

    eventPlayer.buttonIndex++


rule "Cycle Button Backward":
    @Event eachPlayer
    @Condition eventPlayer.isDummy() == false
    @Condition eventPlayer.mode == Mode.EDIT
    @Condition eventPlayer.isHoldingButton(KEYBIND_CYCLE_BUTTON_BACK) == true
    @Condition eventPlayer.buttonIndex > 0

    eventPlayer.buttonIndex--


rule "Swap Team":
    @Event eachPlayer
    @Condition eventPlayer.isDummy() == false
    @Condition eventPlayer.mode == Mode.EDIT
    @Condition eventPlayer.isHoldingButton(KEYBIND_SWAP_TEAM) == true
    @Condition eventPlayer.isHoldingButton(KEYBIND_PRESS_BUTTON) == false

    eventPlayer.teamIndex = 1 - eventPlayer.teamIndex # assumes only two teams


rule "Create Bot":
    @Event eachPlayer
    @Condition eventPlayer.isDummy() == false
    @Condition eventPlayer.mode == Mode.EDIT
    @Condition eventPlayer.isHoldingButton(KEYBIND_CREATE_BOT) == true

    createDummy(getAllHeroes()[eventPlayer.heroIndex], Team.ALL if isFFA else [Team.1, Team.2][eventPlayer.teamIndex], -1, eventPlayer.getPosition(), eventPlayer.getFacingDirection())
    getLastCreatedEntity().buttonToPress = BUTTONS[eventPlayer.buttonIndex]
    getLastCreatedEntity().spawnFacing = eventPlayer.getFacingDirection()
    getLastCreatedEntity().disablePlayerCollision()

    buildBotArray()


rule "Set Bot Facing Direction":
    @Event eachPlayer
    @Condition eventPlayer.isDummy() == true
    @Condition eventPlayer.hasSpawned() == true

    # bots always spawn with a neutral pitch, so we need to set it again shortly after spawning
    wait(0.1)
    eventPlayer.setFacing(eventPlayer.spawnFacing, Relativity.TO_WORLD)


rule "Destroy Bot":
    @Event eachPlayer
    @Condition eventPlayer.isDummy() == false
    @Condition eventPlayer.mode == Mode.EDIT
    @Condition eventPlayer.isHoldingButton(KEYBIND_DESTROY_BOT) == true

    # BUGBUG: raycast does not hit players in spawn rooms (intangibility?)
    eventPlayer.entityHit = raycast(eventPlayer.getEyePosition(), eventPlayer.getEyePosition() + (eventPlayer.getFacingDirection() * 100), getAllPlayers(), eventPlayer, false).getPlayerHit()
    destroyDummy(eventPlayer.entityHit.getTeam(), eventPlayer.entityHit.getSlot())
    eventPlayer.entityHit = null

    buildBotArray()

    # if the delete button is held, delete them all
    wait(3, Wait.ABORT_WHEN_FALSE)
    destroyAllDummies()

    buildBotArray()


rule "Detect Start Holding Button":
    @Event eachPlayer
    @Condition eventPlayer.isDummy() == false
    @Condition eventPlayer.mode == Mode.PLAY
    @Condition eventPlayer.isHoldingButton(KEYBIND_MENU) == false
    @Condition eventPlayer.isHoldingButton(KEYBIND_PRESS_BUTTON) == true

    dummies.pressButton = true


rule "Actually Start Holding Button":
    @Event eachPlayer
    @Condition eventPlayer.isDummy() == true
    @Condition eventPlayer.pressButton == true

    # special case: heroes who need to place ults
    if eventPlayer.getCurrentHero() in BUILDABLE_ULTS and eventPlayer.buttonToPress == Button.ULTIMATE:
        eventPlayer.forceButtonPress(Button.ULTIMATE)
        wait(1)
        eventPlayer.forceButtonPress(Button.PRIMARY_FIRE)

    # special case: heroes with transformative ults
    elif eventPlayer.getCurrentHero() in TRANSFORMATIVE_ULTS and eventPlayer.isUsingUltimate():
        eventPlayer.startForcingButton(Button.SECONDARY_FIRE if eventPlayer.getCurrentHero() == Hero.SOJOURN else Button.PRIMARY_FIRE)

    else:
        eventPlayer.startForcingButton(eventPlayer.buttonToPress)


rule "Stop Holding Button":
    @Event eachPlayer
    @Condition eventPlayer.isDummy() == false
    @Condition eventPlayer.mode == Mode.PLAY
    @Condition eventPlayer.isHoldingButton(KEYBIND_PRESS_BUTTON) == false

    for i in range(len(BUTTONS)):
        dummies.stopForcingButton(BUTTONS[i])

    dummies.pressButton = false