settings {
    "main": {
        "description": "Draw a visualization of spawn points in the level.\n\nCode: W402R\nLast updated: 2024-06-24",
        "modeName": "Spawn Points"
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
        "general": {}
    }
}

#Global variables

globalvar i = 0
globalvar arrayPointsTeam1 = []
globalvar arrayPointsTeam2 = []
globalvar arrayPointsAll = []
    
globalvar objPos = vect(0, 0, 0)

globalvar n0 = 0
globalvar n1 = 0
globalvar n2 = 0
    
globalvar player = null
    
globalvar avg0 = vect(0, 0, 0)
globalvar avg1 = vect(0, 0, 0)
globalvar avg2 = vect(0, 0, 0)

globalvar showInstructions = true


#Player variables

playervar isChangingHero = false
playervar pos = vect(0, 0, 0)
playervar rot = vect(0, 0, 0)


#######################
###    UTILITIES    ###
#######################

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
    
    
##########################
###    SPAWN POINTS    ###
##########################
    
rule "Instruction Text":
    @Event eachPlayer
    @Condition showInstructions == true
    @Condition eventPlayer.hasSpawned() == true

    hudSubtext(eventPlayer, "Press INTERACT [{0}] to display spawn points.".format(buttonString(Button.INTERACT)), HudPosition.TOP, 99, Color.WHITE, HudReeval.VISIBILITY_AND_STRING)


rule "Display Spawn Points":
    @Event global
    @Condition getAllPlayers().isHoldingButton(Button.INTERACT) == true

    # user knows the controls
    showInstructions = false

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
        
        # BUG: starting with season 11, there are 3 separate Push gamemodes all named "Push".
        # this causes the game mode comparison to fail and not display the correct value for push.
        objPos = getPayloadPosition() if getCurrentGamemode() == Gamemode.PUSH else getObjectivePosition(getCurrentObjective())
        wait(0.064)

        hudSubtext(getAllPlayers(), "[C] {0}".format(objPos), HudPosition.LEFT, 999, rgb(200, 200, 200), HudReeval.VISIBILITY, SpecVisibility.ALWAYS)
        createInWorldText(getAllPlayers(), "•", objPos, 4, Clip.NONE, WorldTextReeval.VISIBILITY_AND_POSITION, rgb(200, 200, 200), SpecVisibility.ALWAYS)

        createInWorldText(getAllPlayers(), "•", avg1, 4, Clip.NONE, WorldTextReeval.VISIBILITY, rgb(110, 190, 255), SpecVisibility.ALWAYS)
        createInWorldText(getAllPlayers(), "•", avg2, 4, Clip.NONE, WorldTextReeval.VISIBILITY, rgb(255, 120, 140), SpecVisibility.ALWAYS)

        hudSubtext(getAllPlayers(), "Team 1 Distance to Objective: {0}".format(distance(avg1, objPos)), HudPosition.RIGHT, -2, rgb(110, 190, 255), HudReeval.VISIBILITY, SpecVisibility.NEVER)
        hudSubtext(getAllPlayers(), "Team 2 Distance to Objective: {0}".format(distance(avg2, objPos)), HudPosition.RIGHT, -1, rgb(255, 120, 140), HudReeval.VISIBILITY, SpecVisibility.NEVER)