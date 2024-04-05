settings {
    "main": {
        "description": "Draw a visualization of spawn points in the level. Last updated: 2024-04-05",
        "modeName": "Spawn Points"
    },
    "gamemodes": {
        "assault": {
            "enabledMaps": [],
            "captureSpeed%": 500,
            "gamemodeStartTrigger": "manual",
            "heroLimit": "off",
            "respawnTime%": 10,
            "tankPassiveHealthBonus": "alwaysEnabled"
        },
        "control": {
            "enabledMaps": [],
            "captureSpeed%": 500,
            "gamemodeStartTrigger": "manual",
            "heroLimit": "off",
            "respawnTime%": 10,
            "scoreToWin": 3,
            "scoringSpeed%": 500,
            "tankPassiveHealthBonus": "alwaysEnabled"
        },
        "escort": {
            "enabledMaps": [],
            "gamemodeStartTrigger": "manual",
            "heroLimit": "off",
            "payloadSpeed%": 500,
            "respawnTime%": 10,
            "tankPassiveHealthBonus": "alwaysEnabled"
        },
        "flashpoint": {
            "enabledMaps": [],
            "captureSpeed%": 500,
            "respawnTime%": 10,
            "scoreToWin": 5
        },
        "hybrid": {
            "enabledMaps": [
                {
                    "kingsRow": [
                        "night"
                    ]
                }
            ],
            "captureSpeed%": 500,
            "gamemodeStartTrigger": "manual",
            "heroLimit": "off",
            "payloadSpeed%": 500,
            "respawnTime%": 10,
            "tankPassiveHealthBonus": "alwaysEnabled"
        },
        "practiceRange": {
            "enabled": false,
            "gamemodeStartTrigger": "manual",
            "heroLimit": "off",
            "respawnTime%": 10,
            "tankPassiveHealthBonus": "alwaysEnabled",
            "enableTrainingPartner": false
        },
        "push": {
            "enabledMaps": [],
            "gamemodeStartTrigger": "manual",
            "heroLimit": "off",
            "respawnTime%": 10,
            "tankPassiveHealthBonus": "alwaysEnabled",
            "ts1PushSpeedModifier%": 500,
            "ts1WalkSpeedModifier%": 500
        },
        "tdm": {
            "enabledMaps": [],
            "gamemodeStartTrigger": "manual",
            "heroLimit": "off",
            "respawnTime%": 10,
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

#Global variables

globalvar i
globalvar arrayPointsTeam1
globalvar arrayPointsTeam2
globalvar arrayPointsAll

globalvar objPos

globalvar n0
globalvar n1
globalvar n2

globalvar player

globalvar avg0
globalvar avg1
globalvar avg2


#Player variables

playervar isChangingHero
playervar pos
playervar rot


#Activated extensions


####################
###    GLOBAL    ###
####################

rule "Init Global Variables":
    @Event global

    disableInspector()

    i = 0
    arrayPointsTeam1 = []
    arrayPointsTeam2 = []
    arrayPointsAll = []

    objPos = vect(0, 0, 0)
    
    n0 = 0
    n1 = 0
    n2 = 0

    player = null

    avg0 = vect(0, 0, 0)
    avg1 = vect(0, 0, 0)
    avg2 = vect(0, 0, 0)
    

rule "Init Player Variables":
    @Event eachPlayer
    
    eventPlayer.isChangingHero = false
    eventPlayer.pos = vect(0, 0, 0)
    eventPlayer.rot = vect(0, 0, 0)


rule "Change Hero Anywhere":
    @Event eachPlayer
    @Condition eventPlayer.isDummy() == false
    @Condition eventPlayer.isHoldingButton(Button.MELEE) == true

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
    @Condition eventPlayer.isHoldingButton(Button.MELEE) == true

    getAllPlayers().setUltCharge(100)
    getAllPlayers().setAbilityCooldown(Button.ABILITY_1, 0)
    getAllPlayers().setAbilityCooldown(Button.ABILITY_2, 0)
    getAllPlayers().setAbilityCooldown(Button.SECONDARY_FIRE, 0)


rule "Skip Assemble Heroes":
    @Condition isAssemblingHeroes() == true
    
    setMatchTime(0)


rule "Skip Setup":
    @Condition isInSetup() == true
    
    setMatchTime(0)


rule "Set Timer to 10 Minutes":
    @Event eachPlayer
    @Condition eventPlayer.isHoldingButton(Button.RELOAD) == true
    
    wait(1, Wait.ABORT_WHEN_FALSE)
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
    
rule "Cache Player":
    @Event eachPlayer
    @Slot 0
    @Condition eventPlayer.hasSpawned() == true

    player = eventPlayer
    hudSubtext(eventPlayer, "Press INTERACT [{0}] to display spawn points.".format(buttonString(Button.INTERACT)), HudPosition.TOP, 99, Color.WHITE, HudReeval.VISIBILITY_AND_STRING)


rule "Display Spawn Points":
    @Event global
    @Condition player.isHoldingButton(Button.INTERACT) == true

    # reset state
    destroyAllHudTexts()
    destroyAllInWorldTexts()
    destroyAllEffects()
    arrayPointsTeam1 = []
    arrayPointsTeam2 = []
    arrayPointsAll = []
    avg0 = vect(0, 0, 0)
    avg1 = vect(0, 0, 0)
    avg2 = vect(0, 0, 0)
    wait()

    # draw a visualization of spawn points in the level
    # in deathmatch maps, iterate though all spawns - otherwise separate by team
    if getCurrentGamemode() == Gamemode.TDM or getCurrentGamemode() == Gamemode.FFA:

        n0 = len(getSpawnPoints(Team.ALL))

        # All Teams
        for i in range(0, n0):
            arrayPointsAll[i] = getSpawnPoints(Team.ALL)[i]

            hudSubtext(getAllPlayers(), "[{0}] {1}".format(i+1, arrayPointsAll[i].getPosition()), HudPosition.LEFT, i + len(arrayPointsTeam1) + len(arrayPointsTeam2), rgb(180 + (i*(64/n0)), 180 + (i*(64/n0)), 180 + (i*(64/n0))), HudReeval.VISIBILITY, SpecVisibility.ALWAYS)
            createInWorldText(getAllPlayers(), i + 1, arrayPointsAll[i].getPosition() + vect(0, -0.75, 0), 2, Clip.NONE, WorldTextReeval.VISIBILITY, rgb(180 + (i*(64/n0)), 180 + (i*(64/n0)), 180 + (i*(64/n0))), SpecVisibility.ALWAYS)

            createEffect(getAllPlayers(), Effect.SPHERE, Color.WHITE, arrayPointsAll[i].getPosition(), 0.25, EffectReeval.VISIBILITY)
            createBeam(getAllPlayers(), Beam.GRAPPLE, arrayPointsAll[i].getPosition(), arrayPointsAll[i].getPosition() + (arrayPointsAll[i].getFacingDirection() * 0.5), Color.WHITE, EffectReeval.VISIBILITY)
            
            avg0 += arrayPointsAll[i].getPosition()
            wait(0.064)

        avg0 /= n0
        createEffect(getAllPlayers(), Effect.SPHERE, Color.ORANGE, avg0, 0.25, EffectReeval.VISIBILITY)
        hudSubtext(getAllPlayers(), avg0, HudPosition.TOP, 1, Color.ORANGE, HudReeval.VISIBILITY)

    else:

        n1 = len(getSpawnPoints(Team.1))
        n2 = len(getSpawnPoints(Team.2))

        # Team 1
        for i in range(0, n1):
            arrayPointsTeam1[i] = getSpawnPoints(Team.1)[i]

            hudSubtext(getAllPlayers(), "[{0}] {1} • {2}".format(i+1, arrayPointsTeam1[i].getPosition(), arrayPointsTeam1[i].getFacingDirection()), HudPosition.LEFT, i, rgb(80 + (i*(90/n1)), 160 + (i*(90/n1)), 255), HudReeval.VISIBILITY, SpecVisibility.ALWAYS)
            createInWorldText(getAllPlayers(), i + 1, arrayPointsTeam1[i].getPosition() + vect(0, -0.75, 0), 2, Clip.NONE, WorldTextReeval.VISIBILITY, rgb(80 + (i*(90/n1)), 160 + (i*(90/n1)), 255), SpecVisibility.ALWAYS)

            createEffect(getAllPlayers(), Effect.SPHERE, Color.SKY_BLUE, arrayPointsTeam1[i].getPosition(), 0.25, EffectReeval.VISIBILITY)
            createBeam(getAllPlayers(), Beam.GRAPPLE, arrayPointsTeam1[i].getPosition(), arrayPointsTeam1[i].getPosition() + (arrayPointsTeam1[i].getFacingDirection() * 0.5), Color.WHITE, EffectReeval.VISIBILITY)
            
            avg1 += arrayPointsTeam1[i].getPosition()
            wait(0.064)

        hudSubheader(getAllPlayers(), "•", HudPosition.LEFT, len(arrayPointsTeam1), rgba(0, 0, 0, 0), HudReeval.VISIBILITY, SpecVisibility.ALWAYS)
        
        # Team 2
        for i in range(0, n2):
            arrayPointsTeam2[i] = getSpawnPoints(Team.2)[i]

            hudSubtext(getAllPlayers(), "[{0}] {1} • {2}".format(i+1, arrayPointsTeam2[i].getPosition(), arrayPointsTeam2[i].getFacingDirection()), HudPosition.LEFT, i + len(arrayPointsTeam1), rgb(255, 90 + (i*(90/n2)), 110 + (i*(90/n2))), HudReeval.VISIBILITY, SpecVisibility.ALWAYS)
            createInWorldText(getAllPlayers(), i + 1, arrayPointsTeam2[i].getPosition() + vect(0, -1, 0), 2, Clip.NONE, WorldTextReeval.VISIBILITY, rgb(255, 90 + (i*(90/n2)), 110 + (i*(90/n2))), SpecVisibility.ALWAYS)

            createEffect(getAllPlayers(), Effect.SPHERE, Color.RED, arrayPointsTeam2[i].getPosition(), 0.25, EffectReeval.VISIBILITY)
            createBeam(getAllPlayers(), Beam.GRAPPLE, arrayPointsTeam2[i].getPosition(), arrayPointsTeam2[i].getPosition() + (arrayPointsTeam2[i].getFacingDirection() * 0.5), Color.WHITE, EffectReeval.VISIBILITY)
            
            avg2 += arrayPointsTeam2[i].getPosition()
            wait(0.064)

        hudSubheader(getAllPlayers(), "•", HudPosition.LEFT, len(arrayPointsTeam1) + len(arrayPointsTeam2), rgba(0, 0, 0, 0), HudReeval.VISIBILITY, SpecVisibility.ALWAYS)

        # look for asymmetries between team spawns and objective
        avg1 /= n1
        avg2 /= n2
        objPos = getPayloadPosition() if getCurrentGamemode() == Gamemode.PUSH else getObjectivePosition(getCurrentObjective())
        wait(0.064)

        hudSubtext(getAllPlayers(), "[C] {0}".format(objPos), HudPosition.LEFT, 999, rgb(200, 200, 200), HudReeval.VISIBILITY, SpecVisibility.ALWAYS)
        createInWorldText(getAllPlayers(), "•", objPos, 4, Clip.NONE, WorldTextReeval.VISIBILITY, rgb(200, 200, 200), SpecVisibility.ALWAYS)

        createInWorldText(getAllPlayers(), "•", avg1, 4, Clip.NONE, WorldTextReeval.VISIBILITY, rgb(110, 190, 255), SpecVisibility.ALWAYS)
        createInWorldText(getAllPlayers(), "•", avg2, 4, Clip.NONE, WorldTextReeval.VISIBILITY, rgb(255, 120, 140), SpecVisibility.ALWAYS)

        hudSubtext(getAllPlayers(), "Team 1 Distance to Objective: {0}".format(distance(avg1, objPos)), HudPosition.RIGHT, -2, rgb(110, 190, 255), HudReeval.VISIBILITY, SpecVisibility.NEVER)
        hudSubtext(getAllPlayers(), "Team 2 Distance to Objective: {0}".format(distance(avg2, objPos)), HudPosition.RIGHT, -1, rgb(255, 120, 140), HudReeval.VISIBILITY, SpecVisibility.NEVER)