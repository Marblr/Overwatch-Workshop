settings {
    "main": {
        "description": "Tool allowing the user to place ammo packs in a map and export their positions for use in the Limited Ammo mode.\n\nCode: HGTEH\nLast updated: 2025-01-30",
        "modeName": "Ammo Pack Editor"
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
            "heroLimit": "off"
        }
    },
    "heroes": {
        "allTeams": {
            "enabledHeroes": [
                "mercy"
            ],
            "general": {
                "enableSpawningWithUlt": true
            }
        }
    }
}

#!extension playMoreEffects

# used to determine v.
#!define __MACRO_RAYCAST__ raycast(hostPlayer.getEyePosition(), hostPlayer.getEyePosition() + (hostPlayer.getFacingDirection() * 100), null, null, false).getHitPosition()

# used to determine n.
#!define __MACRO_NORMAL__ crossProduct(hostPlayer.getFacingDirection(), Vector.UP)

# reflects v across n, offset by p.
#!define mirrorVector(v) v - 2 * dotProduct((v - p), n) / dotProduct(n, n) * n

#######################
###    VARIABLES    ###
#######################

globalvar C_AMMO_PACKS = []

globalvar allowPackEditing = true

globalvar isMirrorMode = false

globalvar i = 0

globalvar v = vect(0, 0, 0)
globalvar p = vect(0, 0, 0)
globalvar n = vect(0, 0, 0)
globalvar v_mirror = vect(0, 0, 0)

# this is technically the effect limit.
# the effective limit may be lower depending on player count & server load.
#!define MAX_PACKS 55

globalvar vectors = []
globalvar effects = []
globalvar hudTexts = []
globalvar worldTexts = []

globalvar vectors_mirror = []
globalvar effects_mirror = []
globalvar hudTexts_mirror = []
globalvar worldTexts_mirror = []

#!define SELECTION_DIST 1
globalvar selectedIndex = -1

#!define EXPORT_HOLD_TIME 3
globalvar exportTimer = 0


#################################
###    AMMO PACK PLACEMENT    ###
#################################

rule "Disable Inspector":
    disableInspector()


def tryCreateNewPack():
    @Name "Subroutine: Try to Create New Ammo Pack"

    if len(vectors) + len(vectors_mirror) >= MAX_PACKS:
        smallMessage(hostPlayer, "  {0} Failed to create pack — reached pack limit! ({1} / {2})".format(iconString(Icon.WARNING), len(vectors) + len(vectors_mirror), MAX_PACKS))
        return
        
    if v in vectors:
        smallMessage(hostPlayer, "  {0} Failed to create pack — duplicate position! {1}".format(iconString(Icon.WARNING), v))
        return

    # good to go!
    vectors.append(v)

    createEffect(localPlayer, Effect.RING, Color.RED if vectors.index(evalOnce(v)) == selectedIndex else Color.ORANGE, v, 0.5, EffectReeval.VISIBILITY_AND_COLOR)
    effects.append(getLastCreatedEntity())

    createInWorldText(localPlayer if localPlayer.isHoldingButton(Button.RELOAD) else null, "[{0}]".format(vectors.index(evalOnce(v))), v + vect(0, 0.5, 0), 1, Clip.NONE, WorldTextReeval.VISIBILITY_STRING_AND_COLOR, rgb(255, 100, 110) if vectors.index(evalOnce(v)) == selectedIndex else Color.WHITE, SpecVisibility.ALWAYS)
    worldTexts.append(getLastCreatedText())

    hudSubheader(localPlayer, "[{0}] {1}{2}".format(vectors.index(evalOnce(v)), evalOnce(v), Math.LOTS_OF_SPACES), HudPosition.LEFT, 0, rgb(255, 100, 110) if vectors.index(evalOnce(v)) == selectedIndex else Color.WHITE, HudReeval.VISIBILITY_STRING_AND_COLOR, SpecVisibility.ALWAYS)
    hudTexts.append(getLastCreatedText())


def tryCreateNewMirroredPack():
    @Name "Subroutine: Try to Create New Mirrored Ammo Pack"

    vectors_mirror.append(v_mirror)

    createEffect(localPlayer, Effect.RING, Color.RED if vectors_mirror.index(evalOnce(v_mirror)) == selectedIndex else Color.AQUA, v_mirror, 0.5, EffectReeval.VISIBILITY_AND_COLOR)
    effects_mirror.append(getLastCreatedEntity())

    createInWorldText(localPlayer if localPlayer.isHoldingButton(Button.RELOAD) else null, "[{0}]".format(vectors_mirror.index(evalOnce(v_mirror))), v_mirror + vect(0, 0.5, 0), 1, Clip.NONE, WorldTextReeval.VISIBILITY_STRING_AND_COLOR, rgb(255, 100, 110) if vectors_mirror.index(evalOnce(v_mirror)) == selectedIndex else Color.SKY_BLUE, SpecVisibility.ALWAYS)
    worldTexts_mirror.append(getLastCreatedText())

    hudSubheader(localPlayer, "[{0}] {1}{2}".format(vectors_mirror.index(evalOnce(v_mirror)), evalOnce(v_mirror), Math.LOTS_OF_SPACES), HudPosition.LEFT, 1, rgb(255, 100, 110) if vectors_mirror.index(evalOnce(v_mirror)) == selectedIndex else rgb(70, 220, 255), HudReeval.VISIBILITY_STRING_AND_COLOR, SpecVisibility.ALWAYS)
    hudTexts_mirror.append(getLastCreatedText())


rule "HUD Text":
    @Event global

    # ammo pack keybinds.
    hudSubheader(hostPlayer, "{0} Create Ammo Pack\n{1} Delete Ammo Pack\n{2} Export Positions to File\n{3}".format(buttonString(Button.SECONDARY_FIRE), buttonString(Button.PRIMARY_FIRE), buttonString(Button.INTERACT), Math.LOTS_OF_SPACES), HudPosition.LEFT, -1, Color.WHITE, HudReeval.VISIBILITY_AND_STRING, SpecVisibility.NEVER)
    
    # mirror mode keybinds.
    hudSubheader(hostPlayer, "[{0}] Mirror Mode: {1}".format(buttonString(Button.ABILITY_2), "ON" if isMirrorMode else "OFF"), HudPosition.RIGHT, -10, Color.AQUA if isMirrorMode else Color.WHITE, HudReeval.VISIBILITY_STRING_AND_COLOR, SpecVisibility.NEVER)
    hudSubheader(hostPlayer, "p = {0}".format(p if isMirrorMode else updateEveryTick(hostPlayer.getPosition())), HudPosition.RIGHT, -10, rgb(170, 140, 255) if isMirrorMode else rgb(220, 220, 220), HudReeval.VISIBILITY_STRING_AND_COLOR, SpecVisibility.NEVER)
    hudSubheader(hostPlayer, "n = {0}".format(n if isMirrorMode else updateEveryTick(__MACRO_NORMAL__)), HudPosition.RIGHT, -10, rgb(120, 255, 130) if isMirrorMode else rgb(220, 220, 220), HudReeval.VISIBILITY_STRING_AND_COLOR, SpecVisibility.NEVER)

    # export timer.
    progressBarHud(hostPlayer if exportTimer > 0 else null, (exportTimer / EXPORT_HOLD_TIME) * 100, "Hold to Export Ammo Packs...", HudPosition.TOP, 10, rgb(255, 160, 80), Color.WHITE, ProgressHudReeval.VISIBILITY_AND_VALUES, SpecVisibility.DEFAULT)

    
rule "Placement Preview":
    @Event global
    
    # point under crosshair.
    createEffect(localPlayer, Effect.RING, Color.GRAY, updateEveryTick(__MACRO_RAYCAST__), 0.5, EffectReeval.VISIBILITY_POSITION_AND_RADIUS)

    # mirrored point.
    createEffect(localPlayer if isMirrorMode else null, Effect.RING, Color.GRAY, updateEveryTick(mirrorVector(__MACRO_RAYCAST__)), 0.5, EffectReeval.VISIBILITY_POSITION_AND_RADIUS)
    createInWorldText(localPlayer if isMirrorMode else null, "•", updateEveryTick(mirrorVector(__MACRO_RAYCAST__)), 2, Clip.NONE, WorldTextReeval.VISIBILITY_AND_POSITION, Color.GRAY, SpecVisibility.DEFAULT)

    # mirror axis (beam is rotated 90° counter-clockwise).
    createBeam(localPlayer if isMirrorMode else null, Beam.GRAPPLE, p - (vect(n.z, 0, -n.x) * 100), p + (vect(n.z, 0, -n.x) * 100), Color.WHITE, EffectReeval.VISIBILITY_POSITION_AND_RADIUS)


rule "Place Ammo Pack":
    @Event global
    @Condition hostPlayer.hasSpawned() == true
    @Condition allowPackEditing == true
    @Condition hostPlayer.isHoldingButton(Button.SECONDARY_FIRE) == true

    v = __MACRO_RAYCAST__

    tryCreateNewPack()

    if isMirrorMode:
        v_mirror = mirrorVector(v)
        tryCreateNewMirroredPack()


rule "Select Ammo Pack Near Crosshair":
    @Event global
    @Condition hostPlayer.hasSpawned() == true
    @Condition allowPackEditing == true
    @Condition any([distance(__MACRO_RAYCAST__, pos) < SELECTION_DIST for pos in vectors])

    selectedIndex = vectors.index(sorted(vectors, lambda pos: distance(__MACRO_RAYCAST__, pos))[0])
    waitUntil(distance(__MACRO_RAYCAST__, vectors[selectedIndex]) > SELECTION_DIST or hostPlayer.isHoldingButton(Button.PRIMARY_FIRE) == true, Math.INFINITY)
    wait()
    selectedIndex = -1

    if RULE_CONDITION: goto RULE_START


rule "Remove Selected Ammo Pack":
    @Event global
    @Condition hostPlayer.hasSpawned() == true
    @Condition allowPackEditing == true
    @Condition hostPlayer.isHoldingButton(Button.PRIMARY_FIRE) == true

    if selectedIndex != -1:

        # remove point and effects.
        destroyEffect(effects[selectedIndex])
        destroyHudText(hudTexts[selectedIndex])
        destroyInWorldText(worldTexts[selectedIndex])

        vectors.remove(vectors[selectedIndex])
        effects.remove(effects[selectedIndex])
        hudTexts.remove(hudTexts[selectedIndex])
        worldTexts.remove(worldTexts[selectedIndex])

        if isMirrorMode:

            destroyEffect(effects_mirror[selectedIndex])
            destroyHudText(hudTexts_mirror[selectedIndex])
            destroyInWorldText(worldTexts_mirror[selectedIndex])

            vectors_mirror.remove(vectors_mirror[selectedIndex])
            effects_mirror.remove(effects_mirror[selectedIndex])
            hudTexts_mirror.remove(hudTexts_mirror[selectedIndex])
            worldTexts_mirror.remove(worldTexts_mirror[selectedIndex])


rule "Toggle Mirror Mode":
    @Event global
    @Condition hostPlayer.hasSpawned() == true
    @Condition hostPlayer.isHoldingButton(Button.ABILITY_2) == true

    allowPackEditing = false

    isMirrorMode = not isMirrorMode

    # mirror mode enabled: create mirrored points from existing points.
    if isMirrorMode:

        # TODO: it would be nice if p and n could be set independently of
        # toggling mirror mode, but I'm running out of useable keybinds lol.
        p = hostPlayer.getPosition()
        n = __MACRO_NORMAL__
        wait()

        for i in range(0, len(vectors)):
            v_mirror = mirrorVector(vectors[i])
            tryCreateNewMirroredPack()
            wait()

        if len(vectors) + len(vectors_mirror) > MAX_PACKS:
            smallMessage(hostPlayer, "  {0} Warning — exceeded pack limit during mirroring! ({1} / {2})".format(iconString(Icon.WARNING), len(vectors) + len(vectors_mirror), MAX_PACKS))

    # mirror mode disabled: destroy all mirrored points and effects.
    else:

        for i in range(0, len(vectors_mirror)):
            destroyEffect(effects_mirror[i])
            destroyHudText(hudTexts_mirror[i])
            destroyInWorldText(worldTexts_mirror[i])

        wait()
        vectors_mirror = []
        effects_mirror = []
        hudTexts_mirror = []
        worldTexts_mirror = []
    
    allowPackEditing = true

    # delay before re-fire to prevent spamming.
    wait(1)


rule "Export Ammo Pack Positions to File":
    @Event global
    @Condition hostPlayer.hasSpawned() == true
    @Condition vectors == true
    @Condition allowPackEditing == true
    @Condition hostPlayer.isHoldingButton(Button.INTERACT) == true

    # hold to confirm export.
    chase(exportTimer, EXPORT_HOLD_TIME, rate=1, ChaseReeval.NONE)
    wait(EXPORT_HOLD_TIME, Wait.ABORT_WHEN_FALSE)

    enableInspector()

        printLog("{0}\n".format(getCurrentMap()))

        for i in range (0, len(vectors)):
            printLog(vectors[i])
            wait()

        if isMirrorMode:
            printLog("# Mirrored | p = {0} | n = {1}".format(p, n))

            for i in range (0, len(vectors_mirror)):
                printLog(vectors_mirror[i])
                wait()

    disableInspector()
    
    smallMessage(hostPlayer, "  {0} Successfully exported ammo packs!".format(iconString(Icon.HAPPY)))

    stopChasingVariable(exportTimer)
    exportTimer = 0


rule "Export Canceled":
    @Event global
    @Condition hostPlayer.hasSpawned() == true
    @Condition hostPlayer.isHoldingButton(Button.INTERACT) == false or allowPackEditing == false

    stopChasingVariable(exportTimer)
    exportTimer = 0


#######################
###    NAVIGATION   ###
#######################
    
rule "Disable Weapon":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true

    eventPlayer.disallowButton(Button.PRIMARY_FIRE)
    eventPlayer.disallowButton(Button.SECONDARY_FIRE)


rule "Enable Noclip":
    @Event eachPlayer
    @Hero mercy
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.isUsingUltimate() == true

    eventPlayer.disableEnvironmentCollision(true)


rule "Disable Noclip":
    @Event eachPlayer
    @Hero mercy
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.isUsingUltimate() == false

    eventPlayer.enableEnvironmentCollision()


rule "Enable Speed Boost":
    @Event eachPlayer
    @Hero mercy
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.isHoldingButton(Button.ABILITY_1) == true

    eventPlayer.setMoveSpeed(1000)


rule "Disable Speed Boost":
    @Event eachPlayer
    @Hero mercy
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.isHoldingButton(Button.ABILITY_1) == false

    eventPlayer.setMoveSpeed(100)


rule "Enable Precise Movement":
    @Event eachPlayer
    @Hero mercy
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.isOnGround() == true
    @Condition eventPlayer.isHoldingButton(Button.CROUCH) == true

    eventPlayer.setMoveSpeed(5)


rule "Disable Precise Movement":
    @Event eachPlayer
    @Hero mercy
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.isHoldingButton(Button.CROUCH) == false

    eventPlayer.setMoveSpeed(100)


rule "Snap Position and Facing to Grid":
    @Event eachPlayer
    @Hero mercy
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.isOnGround() == true
    @Condition eventPlayer.isHoldingButton(Button.CROUCH) == true
    @Condition eventPlayer.isHoldingButton(Button.MELEE) == true

    eventPlayer.teleport(vect(round(eventPlayer.getPosition().x), eventPlayer.getPosition().y, round(eventPlayer.getPosition().z)))
    eventPlayer.setFacing(angleToDirection(round(horizontalAngleOfDirection(eventPlayer.getFacingDirection()) / 5) * 5, 0), Relativity.TO_WORLD)


rule "Restore Ultimate":
    @Event eachPlayer
    @Condition eventPlayer.hasSpawned() == true
    @Condition eventPlayer.getUltCharge() < 100

    eventPlayer.setUltCharge(100)


rule "Teleport to Other Side of Mirror":
    @Event eachPlayer
    @Hero mercy
    @Condition eventPlayer.isCommunicating(Comms.HELLO)

    eventPlayer.teleport(mirrorVector(eventPlayer.getPosition()))


###########################
###    AMMO PACK DATA   ###
###########################

# loads in previously saved ammo packs for editing.
# examples given are from the Limited Ammo mode.

rule "AMMO PACKS: MANUAL LOAD":
    @Event global
    @Disabled

    # load in custom vectors, optionally with a position and normal for mirroring.
    # useful for editing control stages individually.
    C_AMMO_PACKS = [
        vect(0, 0, 0)
    ]

    p = vect(0, 0, 0)
    n = vect(0, 0, 0)


rule "AMMO PACKS: Hanaoka":
    @Event global
    @Condition getCurrentMap() == Map.HANAOKA
    @Disabled
    
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
        vect(16.81, 40.07, -38.30)
    ]

    p = vect(0.00, 39.50, 7.00)
    n = vect(0.00, 0.00, 1.00)


rule "AMMO PACKS: Hollywood":
    @Event global
    @Condition getCurrentMap() == Map.HOLLYWOOD or getCurrentMap() == Map.HOLLYWOOD_HALLOWEEN
    @Disabled

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


rule "AMMO PACKS: Workshop Island":
    @Event global
    @Condition getCurrentMap() == Map.WORKSHOP_ISLAND

    C_AMMO_PACKS = [
        vect(8, 0, 8),
        vect(-8, 0, 8),
        vect(8, 0, -8),
        vect(-8, 0, -8)
    ]


rule "Load Ammo Pack Positions":
    @Event global
    @Condition C_AMMO_PACKS == true

    wait(3)

    # if p and n were defined, start in mirror mode.
    isMirrorMode = p and n

    for i in range(0, len(C_AMMO_PACKS)):

        v = C_AMMO_PACKS[i]
        tryCreateNewPack()

        if isMirrorMode:
            v_mirror = mirrorVector(v)
            tryCreateNewMirroredPack()
        
        wait()