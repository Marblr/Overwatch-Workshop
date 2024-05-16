settings {
    "main": {
        "description": "Create and destroy bots that press buttons.\n\nCode: C2N23\nLast updated: 2024-05-16",
        "modeName": "Spawn Bots 2.0"
    },
    "lobby": {
        "team1Slots": 5,
        "team2Slots": 5
    },
    "gamemodes": {
        "assault": {
            "enabledMaps": []
        },
        "control": {
            "enabledMaps": []
        },
        "escort": {
            "enabledMaps": []
        },
        "flashpoint": {
            "enabledMaps": []
        },
        "hybrid": {
            "enabledMaps": [
                {"hollywood":["morning"]}
            ]
        },
        "practiceRange": {
            "enabled": false,
            "enableTrainingPartner": false
        },
        "push": {
            "enabledMaps": []
        },
        "tdm": {
            "enabledMaps": []
        },
        "general": {
            "gamemodeStartTrigger": "manual",
            "heroLimit": "off",
            "tankPassiveHealthBonus": "alwaysEnabled"
        }
    },
    "heroes": {
        "allTeams": {
            "general": {
                "enableSpawningWithUlt": true,
                "ultGen%": 500,
                "combatUltGen%": 500,
                "passiveUltGen%": 500
            }
        }
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
globalvar HERO_COLORS = [rgb(122, 46, 73),   # Reaper
                         rgb(222, 122, 0),   # Tracer
                         rgb(250, 242, 173), # Mercy
                         rgb(178, 168, 101), # Hanzo
                         rgb(186, 76, 63),   # Torbjorn
                         rgb(124, 139, 140), # Reinhardt
                         rgb(0, 88, 188),    # Pharah
                         rgb(143, 146, 174), # Winston
                         rgb(139, 63, 143),  # Widowmaker
                         rgb(91, 115, 81),   # Bastion
                         rgb(118, 180, 201), # Symmetra
                         rgb(252, 238, 90),  # Zenyatta
                         rgb(128, 251, 0),   # Genji
                         rgb(174, 111, 28),  # Roadhog
                         rgb(166, 41, 39),   # Cassidy
                         rgb(231, 162, 23),  # Junkrat
                         rgb(246, 94, 166),  # Zarya
                         rgb(68, 82, 117),   # Soldier: 76
                         rgb(103, 197, 25),  # Lucio
                         rgb(252, 121, 189), # D.Va
                         rgb(70, 154, 240),  # Mei
                         rgb(81, 40, 169),   # Sombra
                         rgb(130, 62, 53),   # Doomfist
                         rgb(72, 105, 158),  # Ana
                         rgb(16, 111, 4),    # Orisa
                         rgb(145, 82, 77),   # Brigitte
                         rgb(151, 114, 229), # Moira
                         rgb(220, 147, 67),  # Wrecking Ball
                         rgb(215, 62, 44),   # Sojourn
                         rgb(110, 108, 106), # Ashe
                         rgb(137, 200, 255), # Echo
                         rgb(40, 165, 195),  # Baptiste
                         rgb(208, 70, 86),   # Kiriko
                         rgb(87, 159, 207),  # Junker Queen
                         rgb(124, 139, 140), # Sigma
                         rgb(125, 85, 199),  # Ramattra
                         rgb(225, 165, 186), # Lifeweaver
                         rgb(219, 66, 22),   # Mauga
                         rgb(165, 140, 84),  # Illari
                         rgb(121, 97, 78)    # Venture
]

# heroes with ultimates that require extra logic for bots to use
globalvar TRANSFORMATIVE_ULTS = [Hero.DOOMFIST,
                                 Hero.ORISA,
                                 Hero.ROADHOG,
                                 Hero.SIGMA,
                                 Hero.BASTION,
                                 Hero.JUNKRAT,
                                 Hero.SOJOURN,
                                 Hero.SOLDIER,
                                 Hero.TORBJORN,
                                 Hero.ILLARI,
                                 Hero.VENTURE]

globalvar PLACEMENT_ULTS = [Hero.SYMMETRA,
                            Hero.BAPTISTE,
                            Hero.LIFEWEAVER]

# all buttons in a sensible order
globalvar BUTTONS = [Button.PRIMARY_FIRE,
                     Button.SECONDARY_FIRE,
                     Button.ABILITY_1,
                     Button.ABILITY_2,
                     Button.ULTIMATE,
                     Button.JUMP,
                     Button.MELEE,
                     Button.CROUCH,
                     Button.RELOAD,
                     Button.INTERACT]

# user chosen keybinds
globalvar KEYBIND_MENU_A =                BUTTONS[createWorkshopSetting(enum["PRIMARY FIRE", "SECONDARY FIRE", "ABILITY 1", "ABILITY 2", "ULTIMATE", "JUMP", "MELEE", "CROUCH", "RELOAD", "INTERACT"], "Bot Keybinds", "Toggle Bot Menu (First Button)", 8, 0)]
globalvar KEYBIND_MENU_B =                BUTTONS[createWorkshopSetting(enum["PRIMARY FIRE", "SECONDARY FIRE", "ABILITY 1", "ABILITY 2", "ULTIMATE", "JUMP", "MELEE", "CROUCH", "RELOAD", "INTERACT"], "Bot Keybinds", "Toggle Bot Menu (Second Button)", 9, 1)]
globalvar KEYBIND_CREATE_BOT =            BUTTONS[createWorkshopSetting(enum["PRIMARY FIRE", "SECONDARY FIRE", "ABILITY 1", "ABILITY 2", "ULTIMATE", "JUMP", "MELEE", "CROUCH", "RELOAD", "INTERACT"], "Bot Keybinds", "Create Bot", 1, 2)]
globalvar KEYBIND_DESTROY_BOT =           BUTTONS[createWorkshopSetting(enum["PRIMARY FIRE", "SECONDARY FIRE", "ABILITY 1", "ABILITY 2", "ULTIMATE", "JUMP", "MELEE", "CROUCH", "RELOAD", "INTERACT"], "Bot Keybinds", "Destroy Bot", 0, 3)]
globalvar KEYBIND_CYCLE_HERO_FORWARD =    BUTTONS[createWorkshopSetting(enum["PRIMARY FIRE", "SECONDARY FIRE", "ABILITY 1", "ABILITY 2", "ULTIMATE", "JUMP", "MELEE", "CROUCH", "RELOAD", "INTERACT"], "Bot Keybinds", "Cycle Hero Forward", 6, 4)]
globalvar KEYBIND_CYCLE_HERO_BACK =       BUTTONS[createWorkshopSetting(enum["PRIMARY FIRE", "SECONDARY FIRE", "ABILITY 1", "ABILITY 2", "ULTIMATE", "JUMP", "MELEE", "CROUCH", "RELOAD", "INTERACT"], "Bot Keybinds", "Cycle Hero Backward", 2, 5)]
globalvar KEYBIND_CYCLE_BUTTON_FORWARD =  BUTTONS[createWorkshopSetting(enum["PRIMARY FIRE", "SECONDARY FIRE", "ABILITY 1", "ABILITY 2", "ULTIMATE", "JUMP", "MELEE", "CROUCH", "RELOAD", "INTERACT"], "Bot Keybinds", "Cycle Button Forward", 3, 6)]
globalvar KEYBIND_CYCLE_BUTTON_BACK =     BUTTONS[createWorkshopSetting(enum["PRIMARY FIRE", "SECONDARY FIRE", "ABILITY 1", "ABILITY 2", "ULTIMATE", "JUMP", "MELEE", "CROUCH", "RELOAD", "INTERACT"], "Bot Keybinds", "Cycle Button Backward", 4, 7)]
globalvar KEYBIND_SWAP_TEAM =             BUTTONS[createWorkshopSetting(enum["PRIMARY FIRE", "SECONDARY FIRE", "ABILITY 1", "ABILITY 2", "ULTIMATE", "JUMP", "MELEE", "CROUCH", "RELOAD", "INTERACT"], "Bot Keybinds", "Swap Team", 7, 8)]
globalvar KEYBIND_PRESS_BUTTON =          BUTTONS[createWorkshopSetting(enum["PRIMARY FIRE", "SECONDARY FIRE", "ABILITY 1", "ABILITY 2", "ULTIMATE", "JUMP", "MELEE", "CROUCH", "RELOAD", "INTERACT"], "Bot Keybinds", "Press Button", 9, 9)]
globalvar KEYBIND_RESET_COOLDOWNS =       BUTTONS[createWorkshopSetting(enum["PRIMARY FIRE", "SECONDARY FIRE", "ABILITY 1", "ABILITY 2", "ULTIMATE", "JUMP", "MELEE", "CROUCH", "RELOAD", "INTERACT"], "Other Keybinds", "Reset All Cooldowns", 6, 10)]
globalvar KEYBIND_CHANGE_HERO =           BUTTONS[createWorkshopSetting(enum["PRIMARY FIRE", "SECONDARY FIRE", "ABILITY 1", "ABILITY 2", "ULTIMATE", "JUMP", "MELEE", "CROUCH", "RELOAD", "INTERACT"], "Other Keybinds", "Change Hero (Hold)", 6, 11)]

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
    @Event eachPlayer
    @Condition eventPlayer.isDummy() == false
    
    hudSubheader(eventPlayer if eventPlayer.showInstructions else null, "TOGGLE BOT MENU", HudPosition.TOP, 98, rgb(255, 170, 30), HudReeval.VISIBILITY)
    hudSubtext(eventPlayer if eventPlayer.showInstructions else null, "[{0}] + [{1}]".format(buttonString(KEYBIND_MENU_A), buttonString(KEYBIND_MENU_B)), HudPosition.TOP, 99, Color.WHITE, HudReeval.VISIBILITY_AND_STRING)


rule "Edit Mode HUD":
    @Event eachPlayer
    @Condition eventPlayer.isDummy() == false

    # hero selection
    hudText(eventPlayer if eventPlayer.showHUD else null, heroIcon(getAllHeroes()[eventPlayer.heroIndex]), "<— [{0}] PREV     NEXT [{1}] —> {2}".format(buttonString(KEYBIND_CYCLE_HERO_BACK), buttonString(KEYBIND_CYCLE_HERO_FORWARD), Math.LOTS_OF_SPACES), getAllHeroes()[eventPlayer.heroIndex], HudPosition.LEFT, 1, HERO_COLORS[eventPlayer.heroIndex], rgb(210, 210, 210), rgb(255, 255, 255), HudReeval.VISIBILITY_STRING_AND_COLOR)
    hudSubheader(eventPlayer if eventPlayer.showHUD else null, "•", HudPosition.LEFT, 2, rgba(0, 0, 0, 0), HudReeval.VISIBILITY)

    # button selection
    hudText(eventPlayer if eventPlayer.showHUD else null, buttonString(BUTTONS[eventPlayer.buttonIndex]), "<— [{0}] PREV     NEXT [{1}] —> {2}".format(buttonString(KEYBIND_CYCLE_BUTTON_BACK), buttonString(KEYBIND_CYCLE_BUTTON_FORWARD), Math.LOTS_OF_SPACES), BUTTONS[eventPlayer.buttonIndex], HudPosition.LEFT, 3, rgb(210, 210, 210), rgb(210, 210, 210), rgb(255, 255, 255), HudReeval.VISIBILITY_AND_STRING)
    hudSubheader(eventPlayer if eventPlayer.showHUD else null, "•", HudPosition.LEFT, 4, rgba(0, 0, 0, 0), HudReeval.VISIBILITY)

    # team selection (non-FFA only)
    hudText(eventPlayer if eventPlayer.showHUD and not isFFA else null, "♪", "[{0}] SWAP TEAM {1}".format(buttonString(KEYBIND_SWAP_TEAM), Math.LOTS_OF_SPACES), "{0}".format([Team.1, Team.2][eventPlayer.teamIndex]), HudPosition.LEFT, 5, rgb(37, 212, 252) if eventPlayer.teamIndex == 0 else rgb(239, 47, 82), rgb(210, 210, 210), rgb(255, 255, 255), HudReeval.VISIBILITY_STRING_AND_COLOR)
    hudSubheader(eventPlayer if eventPlayer.showHUD and not isFFA else null, "•", HudPosition.LEFT, 6, rgba(0, 0, 0, 0), HudReeval.VISIBILITY)

    # create and destroy
    hudSubheader(eventPlayer if eventPlayer.showHUD else null, "[{0}] CREATE BOT {1}".format(buttonString(KEYBIND_CREATE_BOT), Math.LOTS_OF_SPACES), HudPosition.LEFT, 7, rgb(210, 210, 210), HudReeval.VISIBILITY_AND_STRING)
    hudSubheader(eventPlayer if eventPlayer.showHUD else null, "[{0}] DESTROY BOT (HOLD TO DESTROY ALL) {1}".format(buttonString(KEYBIND_DESTROY_BOT), Math.LOTS_OF_SPACES), HudPosition.LEFT, 8, rgb(210, 210, 210), HudReeval.VISIBILITY_AND_STRING)


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
    eventPlayer.allowButton(KEYBIND_MENU_A)
    eventPlayer.allowButton(KEYBIND_MENU_B)


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
    eventPlayer.disallowButton(KEYBIND_MENU_A)
    eventPlayer.disallowButton(KEYBIND_MENU_B)


rule "Toggle Mode":
    @Event eachPlayer
    @Condition eventPlayer.isDummy() == false
    @Condition eventPlayer.isHoldingButton(KEYBIND_MENU_A) == true
    @Condition eventPlayer.isHoldingButton(KEYBIND_MENU_B) == true

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

    # BUG: raycast does not hit players in spawn rooms (is there intangibility?)
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
    @Condition eventPlayer.isHoldingButton(Button.RELOAD) == false
    @Condition eventPlayer.isHoldingButton(KEYBIND_PRESS_BUTTON) == true

    dummies.pressButton = true


rule "Actually Start Holding Button":
    @Event eachPlayer
    @Condition eventPlayer.isDummy() == true
    @Condition eventPlayer.pressButton == true

    # special case: heroes who need to manually place ults
    if eventPlayer.getCurrentHero() in PLACEMENT_ULTS and eventPlayer.buttonToPress == Button.ULTIMATE:
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