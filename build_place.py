#!/usr/bin/env python3
"""
build_place.py
Rebuilds the complete 3D Roblox XML Place (.rbxlx) for DON'T WAKE HIM.
Creates a fully rendered, visible horror house environment, visible Sleeping Man rig,
proper UDim2 screen GUI layouts, atmospheric warm/dark lighting, and embeds all scripts.
"""

import os
import xml.etree.ElementTree as ET

def create_item(parent, class_name, name, referent=None):
    item = ET.SubElement(parent, "Item", attrib={"class": class_name, "referent": referent or f"RBX_{os.urandom(8).hex()}"})
    ET.SubElement(item, "Properties")
    name_prop = ET.SubElement(item.find("Properties"), "string", attrib={"name": "Name"})
    name_prop.text = name
    return item

def add_prop_string(item, prop_name, val):
    props = item.find("Properties")
    p = ET.SubElement(props, "string", attrib={"name": prop_name})
    p.text = str(val or "")

def add_prop_bool(item, prop_name, val):
    props = item.find("Properties")
    p = ET.SubElement(props, "bool", attrib={"name": prop_name})
    p.text = "true" if val else "false"

def add_prop_float(item, prop_name, val):
    props = item.find("Properties")
    p = ET.SubElement(props, "float", attrib={"name": prop_name})
    p.text = str(val)

def add_prop_int(item, prop_name, val):
    props = item.find("Properties")
    p = ET.SubElement(props, "int", attrib={"name": prop_name})
    p.text = str(val)

def add_prop_color3(item, prop_name, r, g=None, b=None):
    if isinstance(r, (tuple, list)):
        r, g, b = r[0], r[1], r[2]
    props = item.find("Properties")
    p = ET.SubElement(props, "Color3", attrib={"name": prop_name})
    ET.SubElement(p, "R").text = str(r)
    ET.SubElement(p, "G").text = str(g)
    ET.SubElement(p, "B").text = str(b)

def add_prop_vector3(item, prop_name, x, y=None, z=None):
    if isinstance(x, (tuple, list)):
        x, y, z = x[0], x[1], x[2]
    props = item.find("Properties")
    p = ET.SubElement(props, "Vector3", attrib={"name": prop_name})
    ET.SubElement(p, "X").text = str(x)
    ET.SubElement(p, "Y").text = str(y)
    ET.SubElement(p, "Z").text = str(z)

def add_prop_cframe(item, prop_name, x, y=None, z=None, rx=0, ry=0, rz=0):
    if isinstance(x, (tuple, list)):
        x, y, z = x[0], x[1], x[2]
    props = item.find("Properties")
    p = ET.SubElement(props, "CoordinateFrame", attrib={"name": prop_name})
    ET.SubElement(p, "X").text = str(x)
    ET.SubElement(p, "Y").text = str(y)
    ET.SubElement(p, "Z").text = str(z)
    
    # Rotation matrix default identity or basic pitch/yaw
    import math
    radx, rady, radz = math.radians(rx), math.radians(ry), math.radians(rz)
    # Simple identity or rotation approximation
    cx, sx = math.cos(radx), math.sin(radx)
    cy, sy = math.cos(rady), math.sin(rady)
    cz, sz = math.cos(radz), math.sin(radz)
    
    ET.SubElement(p, "R00").text = str(cy*cz)
    ET.SubElement(p, "R01").text = str(-cy*sz)
    ET.SubElement(p, "R02").text = str(sy)
    ET.SubElement(p, "R10").text = str(cz*sx*sy + cx*sz)
    ET.SubElement(p, "R11").text = str(cx*cz - sx*sy*sz)
    ET.SubElement(p, "R12").text = str(-cy*sx)
    ET.SubElement(p, "R20").text = str(-cx*cz*sy + sx*sz)
    ET.SubElement(p, "R21").text = str(cz*sx + cx*sy*sz)
    ET.SubElement(p, "R22").text = str(cx*cy)

def add_prop_udim2(item, prop_name, scale_x, offset_x, scale_y, offset_y):
    props = item.find("Properties")
    p = ET.SubElement(props, "UDim2", attrib={"name": prop_name})
    ET.SubElement(p, "XS").text = str(scale_x)
    ET.SubElement(p, "XO").text = str(offset_x)
    ET.SubElement(p, "YS").text = str(scale_y)
    ET.SubElement(p, "YO").text = str(offset_y)

def add_prop_script(item, script_content):
    props = item.find("Properties")
    p = ET.SubElement(props, "ProtectedString", attrib={"name": "Source"})
    p.text = script_content

def build_part(parent, name, size, cframe_pos, color=(160, 160, 160), anchored=True, can_collide=True, material="SmoothPlastic", rx=0, ry=0, rz=0, transparency=0):
    part = create_item(parent, "Part", name)
    add_prop_vector3(part, "Size", size)
    add_prop_cframe(part, "CFrame", cframe_pos, rx=rx, ry=ry, rz=rz)
    add_prop_color3(part, "Color", color[0]/255.0, color[1]/255.0, color[2]/255.0)
    add_prop_bool(part, "Anchored", anchored)
    add_prop_bool(part, "CanCollide", can_collide)
    add_prop_string(part, "Material", material)
    if transparency > 0:
        add_prop_float(part, "Transparency", transparency)
    return part

def build_point_light(parent, color=(255, 220, 160), brightness=1.5, range_studs=20):
    light = create_item(parent, "PointLight", "PointLight")
    add_prop_color3(light, "Color", color[0]/255.0, color[1]/255.0, color[2]/255.0)
    add_prop_float(light, "Brightness", brightness)
    add_prop_float(light, "Range", range_studs)
    add_prop_bool(light, "Shadows", True)
    return light

def add_prop_ref(item, prop_name, target_item):
    """Reference property (Motor6D Part0/Part1, WeldConstraint, etc.)."""
    props = item.find("Properties")
    p = ET.SubElement(props, "Ref", attrib={"name": prop_name})
    p.text = target_item.get("referent")

def add_prop_token(item, prop_name, val):
    """Enum property serialized as a token (e.g. Face=Back, RigType=R6)."""
    props = item.find("Properties")
    p = ET.SubElement(props, "token", attrib={"name": prop_name})
    p.text = str(val)

def build_hiding_wardrobe(parent, name, center, size, object_text, front_sign, marker_pos, color=(50, 35, 25)):
    """Hollow-panel hiding spot.

    The wardrobe is built from 0.3-stud panels instead of one solid block so a
    player teleported inside never intersects solid geometry. The ProximityPrompt
    sits on the front panel with RequiresLineOfSight=false so it also works when
    the player is standing inside (about to leave).
    front_sign: +1 if the entry face is the +Z side, -1 for the -Z side.
    """
    cx, cy, cz = center
    sx, sy, sz = size
    t = 0.3
    model = create_item(parent, "Model", name)

    def panel(pname, psize, pcenter):
        return build_part(model, pname, psize, pcenter, color=color, material="Wood")

    panel("Panel_Bottom", (sx, t, sz), (cx, cy - sy/2 + t/2, cz))
    panel("Panel_Top", (sx, t, sz), (cx, cy + sy/2 - t/2, cz))
    panel("Panel_Left", (t, sy - 2*t, sz), (cx - sx/2 + t/2, cy, cz))
    panel("Panel_Right", (t, sy - 2*t, sz), (cx + sx/2 - t/2, cy, cz))
    panel("Panel_Back", (sx - 2*t, sy - 2*t, t), (cx, cy, cz - front_sign * (sz/2 - t/2)))
    front = panel("Panel_Front", (sx - 2*t, sy - 2*t, t), (cx, cy, cz + front_sign * (sz/2 - t/2)))

    prompt = create_item(front, "ProximityPrompt", "ProximityPrompt")
    add_prop_string(prompt, "ObjectText", object_text)
    add_prop_string(prompt, "ActionText", "Hide Inside")
    add_prop_float(prompt, "HoldDuration", 0.5)
    add_prop_float(prompt, "MaxActivationDistance", 8)
    add_prop_bool(prompt, "RequiresLineOfSight", False)

    build_part(model, "ExitMarker", (1, 1, 1), marker_pos, transparency=1, can_collide=False)
    return model

def build_sleeping_man_rig(house):
    """Jointed R6-style Sleeping Man lying face-up on the bed.

    All parts are unanchored with CanCollide=false; MonsterService PivotTo's the
    model every frame and animates the Motor6D C0s procedurally (breathing,
    walking swing, head stir). Pose: rotation +90 deg about X at torso centre
    T, so a local offset (dx, dy, dz) from the torso maps to world
    (T.x + dx, T.y - dz, T.z + dy).
    """
    import math
    TX, TY, TZ = -28.0, 3.4, 20.0

    def wpos(dx, dy, dz):
        return (TX + dx, TY - dz, TZ + dy)

    rig = create_item(house, "Model", "SleepingMan")

    # --- Parts (all lying: rx=+90) -------------------------------------
    def rig_part(name, size, local_off, color, material="SmoothPlastic", transparency=0):
        return build_part(rig, name, size, wpos(*local_off), color=color, material=material,
                          anchored=False, can_collide=False, rx=90, transparency=transparency)

    hrp = rig_part("HumanoidRootPart", (2, 2, 1), (0, 0, 0), (30, 30, 35), transparency=1)
    torso = rig_part("Torso", (2, 2, 1), (0, 0, 0), (40, 35, 45), material="Fabric")
    head = rig_part("Head", (2, 1, 1), (0, 1.5, 0), (180, 170, 160))
    arm_l = rig_part("Left Arm", (1, 2, 1), (-1.5, 0, 0), (40, 35, 45), material="Fabric")
    arm_r = rig_part("Right Arm", (1, 2, 1), (1.5, 0, 0), (40, 35, 45), material="Fabric")
    leg_l = rig_part("Left Leg", (1, 2, 1), (-0.5, -2, 0), (30, 30, 40), material="Fabric")
    leg_r = rig_part("Right Leg", (1, 2, 1), (0.5, -2, 0), (30, 30, 40), material="Fabric")

    # Classic head mesh
    head_mesh = create_item(head, "SpecialMesh", "HeadMesh")
    add_prop_token(head_mesh, "MeshType", "Head")
    add_prop_vector3(head_mesh, "Scale", (1.25, 1.25, 1.25))

    # Glowing red eyes welded to the head (local +Y = toward feet when lying,
    # local -Z = face direction = world up, so eyes are visible from above)
    eye1 = rig_part("Eye1", (0.3, 0.3, 0.3), (-0.35, 1.6, -0.55), (255, 30, 30), material="Neon")
    eye2 = rig_part("Eye2", (0.3, 0.3, 0.3), (0.35, 1.6, -0.55), (255, 30, 30), material="Neon")
    for eye in (eye1, eye2):
        weld = create_item(eye, "WeldConstraint", "EyeWeld")
        add_prop_ref(weld, "Part0", head)
        add_prop_ref(weld, "Part1", eye)

    # --- Humanoid (physics-driven; server keeps PlatformStand=true) ----
    hum = create_item(rig, "Humanoid", "Humanoid")
    add_prop_token(hum, "RigType", "R6")
    add_prop_bool(hum, "PlatformStand", True)
    add_prop_bool(hum, "BreakJointsOnDeath", False)

    # --- Motor6Ds (neutral standing pose; rotations applied at runtime) --
    def motor(name, part0, part1, c0, c1):
        j = create_item(torso, "Motor6D", name)
        add_prop_ref(j, "Part0", part0)
        add_prop_ref(j, "Part1", part1)
        add_prop_cframe(j, "C0", c0)
        add_prop_cframe(j, "C1", c1)
        return j

    motor("RootJoint", hrp, torso, (0, 0, 0), (0, 0, 0))
    motor("Neck", torso, head, (0, 1, 0), (0, -0.5, 0))
    motor("Left Shoulder", torso, arm_l, (-1, 0.5, 0), (0.5, 0.5, 0))
    motor("Right Shoulder", torso, arm_r, (1, 0.5, 0), (-0.5, 0.5, 0))
    motor("Left Hip", torso, leg_l, (-0.5, -1, 0), (0, 1, 0))
    motor("Right Hip", torso, leg_r, (0.5, -1, 0), (0, 1, 0))

    return rig

def build_place():
    root = ET.Element("roblox", attrib={"xmlns:xmime": "http://www.w3.org/2005/05/xmlmime", "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance", "xsi:noNamespaceSchemaLocation": "http://www.roblox.com/roblox.xsd", "version": "4"})

    # Services
    workspace = create_item(root, "Workspace", "Workspace")
    lighting = create_item(root, "Lighting", "Lighting")
    players_service = create_item(root, "Players", "Players")
    replicated_storage = create_item(root, "ReplicatedStorage", "ReplicatedStorage")
    server_script_service = create_item(root, "ServerScriptService", "ServerScriptService")
    starter_gui = create_item(root, "StarterGui", "StarterGui")
    starter_player = create_item(root, "StarterPlayer", "StarterPlayer")
    starter_player_scripts = create_item(starter_player, "StarterPlayerScripts", "StarterPlayerScripts")
    sound_service = create_item(root, "SoundService", "SoundService")

    # Hard 1-3 player co-op cap (enforced by the engine, not just Config)
    add_prop_int(players_service, "MaxPlayers", 3)

    # 1. Readable Ambient Horror Lighting Setup
    add_prop_color3(lighting, "Ambient", 0.25, 0.25, 0.30)
    add_prop_color3(lighting, "OutdoorAmbient", 0.15, 0.18, 0.25)
    add_prop_color3(lighting, "FogColor", 0.10, 0.12, 0.18)
    add_prop_float(lighting, "FogStart", 40)
    add_prop_float(lighting, "FogEnd", 250)
    add_prop_string(lighting, "TimeOfDay", "01:30:00")

    # 2. Lobby Area (Safe waiting area outside house)
    lobby = create_item(workspace, "Folder", "Lobby")
    lobby_spawns = create_item(lobby, "Folder", "SpawnPoints")
    build_part(lobby, "LobbyFloor", (50, 1, 50), (0, -0.5, 120), color=(60, 65, 75), material="Slate")
    lobby_sign = build_part(lobby, "LobbySign", (16, 6, 1), (0, 6, 96), color=(40, 40, 50), material="Wood")

    # Lobby sign faces the spawn area (+Z side) with title + how-to-play text
    sign_gui = create_item(lobby_sign, "SurfaceGui", "LobbySignGui")
    add_prop_token(sign_gui, "Face", "Back")
    add_prop_float(sign_gui, "LightInfluence", 0)
    sign_text = create_item(sign_gui, "TextLabel", "SignText")
    add_prop_udim2(sign_text, "Position", 0, 0, 0, 0)
    add_prop_udim2(sign_text, "Size", 1, 0, 1, 0)
    add_prop_string(sign_text, "Text",
                    "DON'T WAKE HIM\nFind 3 keys and unlock the front exit before he wakes.\n"
                    "2-3 players  |  Move quietly — the noise meter wakes him.\n"
                    "Hide in wardrobes if he gets up.")
    add_prop_bool(sign_text, "TextWrapped", True)
    add_prop_bool(sign_text, "TextScaled", True)
    add_prop_color3(sign_text, "TextColor3", 1.0, 0.88, 0.55)
    add_prop_float(sign_text, "BackgroundTransparency", 1.0)

    # Invisible lobby barrier walls: players are teleported to/from the house,
    # so these stop anyone from walking off the lobby island into the void.
    build_part(lobby, "LobbyBarrier_South", (52, 13, 1), (0, 6, 94.5), transparency=1)
    build_part(lobby, "LobbyBarrier_North", (52, 13, 1), (0, 6, 145.5), transparency=1)
    build_part(lobby, "LobbyBarrier_East", (1, 13, 52), (25.5, 6, 120), transparency=1)
    build_part(lobby, "LobbyBarrier_West", (1, 13, 52), (-25.5, 6, 120), transparency=1)
    
    lobby_light = build_part(lobby, "LobbyLamp", (2, 2, 2), (0, 10, 120), color=(255, 240, 200), can_collide=False)
    build_point_light(lobby_light, color=(255, 230, 180), brightness=2.5, range_studs=40)

    for i in range(3):
        sp = create_item(lobby_spawns, "SpawnLocation", f"LobbySpawn_{i+1}")
        add_prop_vector3(sp, "Size", (4, 1, 4))
        add_prop_cframe(sp, "CFrame", (-8 + i*8, 0.5, 120))
        add_prop_bool(sp, "Anchored", True)
        add_prop_bool(sp, "CanCollide", True)

    # 3. HOUSE ENVIRONMENT ARCHITECTURE
    # Layout structure:
    # [ MASTER BEDROOM ] | [ MAIN HALLWAY ] | [ LIVING ROOM ]
    #                      [ BATHROOM ]     | [ KITCHEN ]
    #                                       | [ FRONT EXIT ]
    house = create_item(workspace, "Folder", "House")
    house_spawns = create_item(house, "Folder", "SpawnPoints")
    key_spawns = create_item(workspace, "Folder", "KeySpawns")
    interactables = create_item(workspace, "Folder", "Interactables")
    hiding_spots = create_item(workspace, "Folder", "HidingSpots")

    # House Base / Foundation
    # Total footprint: 80 studs wide (X: -40 to 40), 70 studs deep (Z: -35 to 35)
    
    # ROOM FLOORS:
    # Bedroom Floor (X: -40 to -10, Z: -5 to 35)
    build_part(house, "Floor_Bedroom", (30, 1, 40), (-25, -0.5, 15), color=(90, 60, 45), material="WoodPlanks")
    build_part(house, "Rug_Bedroom", (22, 0.2, 26), (-25, 0.1, 15), color=(110, 30, 40), material="Fabric") # Large Crimson Rug

    # Hallway Floor (X: -10 to 10, Z: -5 to 35)
    build_part(house, "Floor_Hallway", (20, 1, 40), (0, -0.5, 15), color=(80, 50, 35), material="WoodPlanks")
    build_part(house, "Rug_Hallway", (6, 0.2, 32), (0, 0.1, 15), color=(140, 120, 80), material="Fabric") # Runner Rug

    # Living Room Floor (X: 10 to 40, Z: -5 to 35)
    build_part(house, "Floor_LivingRoom", (30, 1, 40), (25, -0.5, 15), color=(85, 55, 40), material="WoodPlanks")
    build_part(house, "Rug_LivingRoom", (18, 0.2, 22), (25, 0.1, 15), color=(50, 70, 90), material="Fabric") # Patterned Rug

    # Bathroom Floor (X: -10 to 10, Z: -35 to -5)
    build_part(house, "Floor_Bathroom", (20, 1, 30), (0, -0.5, -20), color=(220, 220, 225), material="Marble")

    # Kitchen Floor (X: 10 to 40, Z: -35 to -5)
    build_part(house, "Floor_Kitchen", (30, 1, 30), (25, -0.5, -20), color=(200, 200, 200), material="Cobblestone")

    # Front Exit Foyer Floor (X: -40 to -10, Z: -35 to -5)
    build_part(house, "Floor_FrontExit", (30, 1, 30), (-25, -0.5, -20), color=(50, 55, 60), material="Slate")

    # CEILINGS (12 studs high):
    build_part(house, "Ceiling_Main", (80, 1, 70), (0, 12.5, 0), color=(180, 175, 165), material="SmoothPlastic")

    # OUTER WALLS:
    build_part(house, "Wall_Outer_North", (80, 13, 1), (0, 6, 35), color=(70, 65, 60), material="Brick")
    build_part(house, "Wall_Outer_South", (80, 13, 1), (0, 6, -35), color=(70, 65, 60), material="Brick")
    build_part(house, "Wall_Outer_West", (1, 13, 70), (-40, 6, 0), color=(70, 65, 60), material="Brick")
    build_part(house, "Wall_Outer_East", (1, 13, 70), (40, 6, 0), color=(70, 65, 60), material="Brick")

    # INTERIOR DIVIDER WALLS & DOORWAY CUTOUTS:
    # Wall between Bedroom and Hallway (X = -10, Z = -5 to 35) with Door Cutout at Z = 15
    build_part(house, "Wall_BedHall_North", (1, 13, 14), (-10, 6, 28), color=(120, 110, 95), material="Wood")
    build_part(house, "Wall_BedHall_South", (1, 13, 14), (-10, 6, 2), color=(120, 110, 95), material="Wood")
    build_part(house, "Wall_BedHall_TopFrame", (1, 3, 12), (-10, 11, 15), color=(120, 110, 95), material="Wood")

    # Wall between Hallway and Living Room (X = 10, Z = -5 to 35) with Door Cutout at Z = 15
    build_part(house, "Wall_HallLiving_North", (1, 13, 14), (10, 6, 28), color=(120, 110, 95), material="Wood")
    build_part(house, "Wall_HallLiving_South", (1, 13, 14), (10, 6, 2), color=(120, 110, 95), material="Wood")
    build_part(house, "Wall_HallLiving_TopFrame", (1, 3, 12), (10, 11, 15), color=(120, 110, 95), material="Wood")

    # Wall dividing North Rooms (Bedroom/Hall/Living) from South Rooms (Exit/Bathroom/Kitchen) (Z = -5)
    # Cutouts at Z = -5, X = 0 (Hall to Bath), X = 25 (Living to Kitchen), X = -25 (Hall to Exit)
    build_part(house, "Wall_Mid_BedExit", (30, 13, 1), (-25, 6, -5), color=(120, 110, 95), material="Wood")
    build_part(house, "Wall_Mid_HallBath", (6, 13, 1), (-7, 6, -5), color=(120, 110, 95), material="Wood")
    build_part(house, "Wall_Mid_HallBath2", (6, 13, 1), (7, 6, -5), color=(120, 110, 95), material="Wood")
    build_part(house, "Wall_Mid_LivingKitchen", (30, 13, 1), (25, 6, -5), color=(120, 110, 95), material="Wood")

    # Wall between Bathroom and Kitchen (X = 10, Z = -35 to -5)
    build_part(house, "Wall_BathKitchen", (1, 13, 30), (10, 6, -20), color=(140, 140, 145), material="SmoothPlastic")

    # Wall between Front Exit Foyer and Bathroom (X = -10, Z = -35 to -5)
    build_part(house, "Wall_ExitBath", (1, 13, 30), (-10, 6, -20), color=(120, 110, 95), material="Wood")

    # LIGHT FIXTURES & ROOM LAMPS (Warm Atmospheric Horror Lighting):
    # Master Bedroom Lamp
    bed_lamp_base = build_part(house, "Lamp_Bedroom", (1.5, 4, 1.5), (-14, 4.5, 28), color=(200, 180, 100), material="Metal")
    build_point_light(bed_lamp_base, color=(255, 200, 130), brightness=1.8, range_studs=25)

    # Hallway Ceiling Sconce
    hall_lamp = build_part(house, "Lamp_Hallway", (2, 1, 2), (0, 11.5, 15), color=(240, 230, 180), material="Glass")
    build_point_light(hall_lamp, color=(240, 210, 150), brightness=1.5, range_studs=30)

    # Living Room Table Lamp
    living_lamp = build_part(house, "Lamp_LivingRoom", (2, 4, 2), (34, 4.5, 28), color=(180, 140, 90), material="Wood")
    build_point_light(living_lamp, color=(255, 220, 150), brightness=2.0, range_studs=35)

    # Kitchen Light
    kitchen_lamp = build_part(house, "Lamp_Kitchen", (3, 1, 3), (25, 11.5, -20), color=(220, 230, 240), material="Glass")
    build_point_light(kitchen_lamp, color=(220, 235, 255), brightness=1.6, range_studs=28)

    # Bathroom Light
    bath_lamp = build_part(house, "Lamp_Bathroom", (2, 1, 2), (0, 11.5, -20), color=(240, 240, 250), material="Glass")
    build_point_light(bath_lamp, color=(200, 230, 255), brightness=1.4, range_studs=22)

    # Exit Foyer Light
    exit_lamp = build_part(house, "Lamp_Exit", (2, 1, 2), (-25, 11.5, -20), color=(255, 200, 100), material="Metal")
    build_point_light(exit_lamp, color=(255, 180, 100), brightness=1.5, range_studs=25)

    # 4. DETAILED FURNITURE & PROPS IN ROOMS

    # MASTER BEDROOM FURNITURE:
    # Double Bed Frame, Mattress, Blanket, Pillows
    build_part(house, "BedFrame", (8, 1.5, 10), (-28, 0.75, 20), color=(70, 45, 30), material="Wood")
    build_part(house, "BedMattress", (7.5, 1.2, 9.5), (-28, 2.1, 20), color=(230, 230, 235), material="Fabric")
    build_part(house, "BedBlanket", (7.6, 0.4, 7.5), (-28, 2.7, 19), color=(120, 40, 50), material="Fabric")
    build_part(house, "Pillow1", (3, 0.5, 2), (-30, 2.9, 23.5), color=(240, 240, 240), material="Fabric")
    build_part(house, "Pillow2", (3, 0.5, 2), (-26, 2.9, 23.5), color=(240, 240, 240), material="Fabric")

    # Nightstands
    build_part(house, "Nightstand_Left", (3, 2.5, 3), (-34, 1.25, 23.5), color=(60, 40, 25), material="Wood")
    build_part(house, "Nightstand_Right", (3, 2.5, 3), (-22, 1.25, 23.5), color=(60, 40, 25), material="Wood")

    # Wardrobe / Hiding Spot 1 (Master Bedroom Closet) — hollow panels
    hiding_1 = build_hiding_wardrobe(
        hiding_spots, "HidingWardrobe_Bedroom", (-36, 4.5, 5), (5, 9, 4),
        "Bedroom Wardrobe Closet", +1, (-36, 1, 9))

    # 5. JOINTED SLEEPING MAN RIG (visible, animated, server-driven)
    build_sleeping_man_rig(house)

    # LIVING ROOM FURNITURE:
    # 3-Seater Sofa
    build_part(house, "Sofa_Base", (10, 2, 4), (25, 1.0, 28), color=(60, 50, 45), material="Fabric")
    build_part(house, "Sofa_Back", (10, 3.5, 1.2), (25, 2.75, 29.4), color=(60, 50, 45), material="Fabric")
    # Coffee Table
    build_part(house, "CoffeeTable", (6, 1.8, 3.5), (25, 0.9, 22), color=(70, 45, 30), material="Wood")
    # Armchairs
    build_part(house, "Armchair1", (4, 3, 4), (16, 1.5, 25), color=(70, 60, 55), material="Fabric")
    # TV Unit
    build_part(house, "TV_Stand", (8, 2.5, 2.5), (25, 1.25, 2), color=(40, 30, 20), material="Wood")
    build_part(house, "TV_Screen", (7, 4, 0.5), (25, 4.5, 2), color=(15, 15, 20), material="SmoothPlastic")
    # Hiding Spot 2 (Living Room Closet) — hollow panels
    build_hiding_wardrobe(
        hiding_spots, "HidingCloset_LivingRoom", (36, 4.5, 5), (5, 9, 4),
        "Living Room Closet", +1, (36, 1, 9))

    # KITCHEN FURNITURE:
    # L-Shaped Countertop & Cabinets
    build_part(house, "Counter_Long", (18, 3.5, 3), (26, 1.75, -33), color=(220, 220, 215), material="Marble")
    build_part(house, "Counter_Side", (3, 3.5, 12), (34, 1.75, -25), color=(220, 220, 215), material="Marble")
    build_part(house, "KitchenSink", (3.5, 0.2, 2), (26, 3.5, -33), color=(180, 180, 190), material="Metal")
    # Refrigerator
    build_part(house, "Fridge", (4.5, 8.5, 4), (14, 4.25, -32), color=(210, 215, 220), material="Metal")
    # Dining Table & Chairs
    build_part(house, "DiningTable", (7, 3, 4.5), (24, 1.5, -16), color=(80, 55, 35), material="Wood")
    build_part(house, "DiningChair1", (2, 3, 2), (21, 1.5, -16), color=(70, 45, 25), material="Wood")
    build_part(house, "DiningChair2", (2, 3, 2), (27, 1.5, -16), color=(70, 45, 25), material="Wood")

    # BATHROOM FIXTURES:
    # Bathtub
    build_part(house, "Bathtub", (7, 2.5, 3.5), (-4, 1.25, -32), color=(240, 240, 245), material="SmoothPlastic")
    # Vanity Sink & Mirror
    build_part(house, "VanitySink", (4, 3, 2.5), (6, 1.5, -33), color=(230, 230, 235), material="Marble")
    build_part(house, "Mirror", (3.5, 4, 0.2), (6, 5.5, -34.8), color=(200, 220, 230), material="Glass")
    # Toilet
    build_part(house, "Toilet", (2.2, 2.8, 2.5), (-7, 1.4, -10), color=(240, 240, 245), material="SmoothPlastic")
    # Hiding Spot 3 (Bathroom Linen Closet) — hollow panels (entry faces -Z)
    build_hiding_wardrobe(
        hiding_spots, "HidingCloset_Bathroom", (7, 4.5, -10), (4, 9, 3.5),
        "Bathroom Cabinet", -1, (7, 1, -14))

    # FRONT EXIT & FOYER:
    # Front Exit Door Frame & Metal Reinforced Door
    exit_model = create_item(workspace, "Model", "Exit")
    build_part(exit_model, "DoorFrame_Left", (1, 10, 1), (-28, 5, -34), color=(40, 40, 40), material="Metal")
    build_part(exit_model, "DoorFrame_Right", (1, 10, 1), (-22, 5, -34), color=(40, 40, 40), material="Metal")
    build_part(exit_model, "DoorFrame_Top", (7, 1, 1), (-25, 10, -34), color=(40, 40, 40), material="Metal")
    
    exit_door_part = build_part(exit_model, "ExitDoor", (5, 9, 0.8), (-25, 4.5, -34), color=(160, 40, 40), material="Metal")
    exit_prompt = create_item(exit_door_part, "ProximityPrompt", "ProximityPrompt")
    add_prop_string(exit_prompt, "ObjectText", "Heavy Front Exit Door")
    add_prop_string(exit_prompt, "ActionText", "Unlock & Escape (Requires 3 Keys)")
    add_prop_float(exit_prompt, "HoldDuration", 1.0)
    
    # Keypad Indicator Box (Red = Locked, Green = Unlocked)
    keypad = build_part(exit_model, "KeypadBox", (1.2, 1.8, 0.4), (-21.5, 5, -33.6), color=(25, 25, 30), material="Metal")
    build_part(exit_model, "LockLed", (0.4, 0.4, 0.2), (-21.5, 5.5, -33.3), color=(255, 30, 30), material="Neon")
    
    # EXIT SIGN (Glowing Overhead)
    exit_sign = build_part(exit_model, "ExitSign", (3, 1, 0.5), (-25, 10.8, -33.4), color=(40, 220, 50), material="Neon")

    # INTERACTABLE DOORS BETWEEN ROOMS:
    # Door 1: Bedroom to Hallway
    door1_model = create_item(interactables, "Model", "Door_Bedroom")
    d1_hinge = build_part(door1_model, "Hinge", (0.8, 9, 4), (-10, 4.5, 15), color=(110, 75, 45), material="Wood")
    d1_prompt = create_item(d1_hinge, "ProximityPrompt", "ProximityPrompt")
    add_prop_string(d1_prompt, "ObjectText", "Bedroom Door")
    add_prop_string(d1_prompt, "ActionText", "Open/Close Door")

    # Door 2: Living Room to Hallway
    door2_model = create_item(interactables, "Model", "Door_LivingRoom")
    d2_hinge = build_part(door2_model, "Hinge", (0.8, 9, 4), (10, 4.5, 15), color=(110, 75, 45), material="Wood")
    d2_prompt = create_item(d2_hinge, "ProximityPrompt", "ProximityPrompt")
    add_prop_string(d2_prompt, "ObjectText", "Living Room Door")
    add_prop_string(d2_prompt, "ActionText", "Open/Close Door")

    # House Player Spawns (Inside Hallway)
    for i in range(3):
        sp = create_item(house_spawns, "Part", f"HouseSpawn_{i+1}")
        add_prop_vector3(sp, "Size", (3, 0.5, 3))
        add_prop_cframe(sp, "CFrame", (-4 + i*4, 0.5, 10))
        add_prop_bool(sp, "Anchored", True)
        add_prop_bool(sp, "CanCollide", False)

    # Key Spawn Positions (6 Pool locations across rooms)
    key_coords = [
        (-34, 2.6, 23.5), # 1. Bedroom Nightstand
        (0, 1.0, 15),     # 2. Hallway Console Table
        (25, 2.0, 22),    # 3. Living Room Coffee Table
        (24, 3.2, -16),   # 4. Kitchen Dining Table
        (6, 3.2, -33),    # 5. Bathroom Vanity Sink
        (26, 3.7, -33),   # 6. Kitchen Marble Counter
    ]
    for i, coord in enumerate(key_coords):
        kp = create_item(key_spawns, "Part", f"KeySpawn_{i+1}")
        add_prop_vector3(kp, "Size", (1.5, 1.5, 1.5))
        add_prop_cframe(kp, "CFrame", (coord[0], coord[1], coord[2]))
        add_prop_bool(kp, "Anchored", True)
        add_prop_bool(kp, "CanCollide", False)
        add_prop_float(kp, "Transparency", 0.5)

    # Clue Spawn Positions (4 locations across rooms)
    clue_spawns = create_item(workspace, "Folder", "ClueSpawns")
    clue_coords = [
        (-22, 2.6, 23.5), # 1. Bedroom Nightstand Right
        (0, 2.6, 28),     # 2. Hallway Table
        (25, 2.0, 22),    # 3. Living Room Coffee Table
        (28, 3.8, -33),   # 4. Kitchen Counter
    ]
    for i, coord in enumerate(clue_coords):
        cp = create_item(clue_spawns, "Part", f"ClueSpawn_{i+1}")
        add_prop_vector3(cp, "Size", (1, 1, 1))
        add_prop_cframe(cp, "CFrame", (coord[0], coord[1], coord[2]))
        add_prop_bool(cp, "Anchored", True)
        add_prop_bool(cp, "CanCollide", False)
        add_prop_float(cp, "Transparency", 1.0)

    # 6. PROPER UDim2 SCREEN GUI LAYOUTS (FIXES BROKEN / CLIPPED UI)

    # MainHUD
    main_hud = create_item(starter_gui, "ScreenGui", "MainHUD")
    add_prop_bool(main_hud, "ResetOnSpawn", False)

    # Top-Left Noise Meter Container
    noise_frame = create_item(main_hud, "Frame", "NoiseFrame")
    add_prop_udim2(noise_frame, "Position", 0.02, 0, 0.02, 0)
    add_prop_udim2(noise_frame, "Size", 0, 240, 0, 36)
    add_prop_color3(noise_frame, "BackgroundColor3", 0.1, 0.1, 0.12)
    add_prop_float(noise_frame, "BackgroundTransparency", 0.3)

    noise_bar_fill = create_item(noise_frame, "Frame", "NoiseBarFill")
    add_prop_udim2(noise_bar_fill, "Position", 0, 2, 0, 2)
    add_prop_udim2(noise_bar_fill, "Size", 0, 0, 1, -4)
    add_prop_color3(noise_bar_fill, "BackgroundColor3", 0.2, 0.8, 0.3)

    noise_label = create_item(noise_frame, "TextLabel", "NoiseLabel")
    add_prop_udim2(noise_label, "Position", 0, 0, 0, 0)
    add_prop_udim2(noise_label, "Size", 1, 0, 1, 0)
    add_prop_string(noise_label, "Text", "NOISE: 0% [SAFE]")
    add_prop_color3(noise_label, "TextColor3", 1.0, 1.0, 1.0)
    add_prop_float(noise_label, "BackgroundTransparency", 1.0)
    add_prop_float(noise_label, "TextSize", 16)

    # Objective Counter Label
    obj_label = create_item(main_hud, "TextLabel", "ObjectiveLabel")
    add_prop_udim2(obj_label, "Position", 0.02, 0, 0.07, 0)
    add_prop_udim2(obj_label, "Size", 0, 240, 0, 32)
    add_prop_string(obj_label, "Text", "KEYS: 0/3")
    add_prop_color3(obj_label, "TextColor3", 0.95, 0.8, 0.3)
    add_prop_color3(obj_label, "BackgroundColor3", 0.1, 0.1, 0.12)
    add_prop_float(obj_label, "BackgroundTransparency", 0.4)
    add_prop_float(obj_label, "TextSize", 18)

    # Center-Top Timer Box
    timer_label = create_item(main_hud, "TextLabel", "TimerLabel")
    add_prop_udim2(timer_label, "Position", 0.43, 0, 0.02, 0)
    add_prop_udim2(timer_label, "Size", 0, 160, 0, 42)
    add_prop_string(timer_label, "Text", "04:00")
    add_prop_color3(timer_label, "TextColor3", 1.0, 1.0, 1.0)
    add_prop_color3(timer_label, "BackgroundColor3", 0.08, 0.08, 0.1)
    add_prop_float(timer_label, "BackgroundTransparency", 0.3)
    add_prop_float(timer_label, "TextSize", 24)

    # Bottom-Center Warning / Status Banner
    status_label = create_item(main_hud, "TextLabel", "StatusLabel")
    add_prop_udim2(status_label, "Position", 0.15, 0, 0.82, 0)
    add_prop_udim2(status_label, "Size", 0.7, 0, 0, 44)
    add_prop_string(status_label, "Text", "FIND 3 KEYS WITHOUT WAKING HIM!")
    add_prop_color3(status_label, "TextColor3", 1.0, 0.85, 0.3)
    add_prop_color3(status_label, "BackgroundColor3", 0.05, 0.05, 0.08)
    add_prop_float(status_label, "BackgroundTransparency", 0.4)
    add_prop_float(status_label, "TextSize", 20)

    # Mobile Touch Controls Frame
    mobile_frame = create_item(main_hud, "Frame", "MobileControlsFrame")
    add_prop_udim2(mobile_frame, "Position", 0.75, 0, 0.65, 0)
    add_prop_udim2(mobile_frame, "Size", 0, 140, 0, 140)
    add_prop_float(mobile_frame, "BackgroundTransparency", 1.0)
    add_prop_bool(mobile_frame, "Visible", False)

    # Mobile sprint toggle (wired in InteractionController via MouseButton1Down/Up)
    sprint_btn = create_item(mobile_frame, "TextButton", "SprintButton")
    add_prop_udim2(sprint_btn, "Position", 0, 0, 0.5, 0)
    add_prop_udim2(sprint_btn, "Size", 0, 140, 0, 70)
    add_prop_string(sprint_btn, "Text", "SPRINT")
    add_prop_color3(sprint_btn, "BackgroundColor3", 0.14, 0.15, 0.2)
    add_prop_float(sprint_btn, "BackgroundTransparency", 0.25)
    add_prop_color3(sprint_btn, "TextColor3", 0.94, 0.9, 0.75)
    add_prop_float(sprint_btn, "TextSize", 20)

    # ResultUI Modal
    result_ui = create_item(starter_gui, "ScreenGui", "ResultUI")
    add_prop_bool(result_ui, "ResetOnSpawn", False)
    add_prop_bool(result_ui, "Enabled", False)

    res_frame = create_item(result_ui, "Frame", "ResultFrame")
    add_prop_udim2(res_frame, "Position", 0.25, 0, 0.25, 0)
    add_prop_udim2(res_frame, "Size", 0.5, 0, 0.5, 0)
    add_prop_color3(res_frame, "BackgroundColor3", 0.08, 0.08, 0.12)
    add_prop_float(res_frame, "BackgroundTransparency", 0.1)

    res_title = create_item(res_frame, "TextLabel", "ResultTitleLabel")
    add_prop_udim2(res_title, "Position", 0.05, 0, 0.1, 0)
    add_prop_udim2(res_title, "Size", 0.9, 0, 0.25, 0)
    add_prop_string(res_title, "Text", "ESCAPED VICTORY!")
    add_prop_color3(res_title, "TextColor3", 0.3, 0.95, 0.4)
    add_prop_float(res_title, "BackgroundTransparency", 1.0)
    add_prop_float(res_title, "TextSize", 32)

    res_reason = create_item(res_frame, "TextLabel", "ResultReasonLabel")
    add_prop_udim2(res_reason, "Position", 0.05, 0, 0.4, 0)
    add_prop_udim2(res_reason, "Size", 0.9, 0, 0.2, 0)
    add_prop_string(res_reason, "Text", "All 3 keys collected and front exit unlocked!")
    add_prop_color3(res_reason, "TextColor3", 0.8, 0.8, 0.85)
    add_prop_float(res_reason, "BackgroundTransparency", 1.0)
    add_prop_float(res_reason, "TextSize", 20)

    res_coins = create_item(res_frame, "TextLabel", "CoinsEarnedLabel")
    add_prop_udim2(res_coins, "Position", 0.05, 0, 0.65, 0)
    add_prop_udim2(res_coins, "Size", 0.9, 0, 0.2, 0)
    add_prop_string(res_coins, "Text", "Coins Earned: +120")
    add_prop_color3(res_coins, "TextColor3", 0.95, 0.8, 0.3)
    add_prop_float(res_coins, "BackgroundTransparency", 1.0)
    add_prop_float(res_coins, "TextSize", 22)

    # NOTE: Shop / Stats / Settings panels are built at runtime by UIController
    # (fully wired to real server data). Empty placeholder ScreenGuis were
    # removed — no dead UI buttons exist anymore.

    # 7. EMBED LUAU SCRIPTS INTO XML
    def read_luau(path):
        with open(path, "r", encoding="utf-8") as f:
            return f.read()

    # Shared Modules
    rep_shared = create_item(replicated_storage, "Folder", "Shared")
    remotes_folder = create_item(replicated_storage, "Folder", "Remotes")

    cfg_mod = create_item(rep_shared, "ModuleScript", "Config")
    add_prop_script(cfg_mod, read_luau("src/ReplicatedStorage/Shared/Config.luau"))

    const_mod = create_item(rep_shared, "ModuleScript", "Constants")
    add_prop_script(const_mod, read_luau("src/ReplicatedStorage/Shared/Constants.luau"))

    util_mod = create_item(rep_shared, "ModuleScript", "Utility")
    add_prop_script(util_mod, read_luau("src/ReplicatedStorage/Shared/Utility.luau"))

    # Server Services
    server_services = create_item(server_script_service, "Folder", "Services")
    
    services_list = [
        ("DataService", "src/ServerScriptService/Services/DataService.luau"),
        ("AnalyticsService", "src/ServerScriptService/Services/AnalyticsService.luau"),
        ("RewardService", "src/ServerScriptService/Services/RewardService.luau"),
        ("MonetizationService", "src/ServerScriptService/Services/MonetizationService.luau"),
        ("NoiseService", "src/ServerScriptService/Services/NoiseService.luau"),
        ("InteractionService", "src/ServerScriptService/Services/InteractionService.luau"),
        ("ObjectiveService", "src/ServerScriptService/Services/ObjectiveService.luau"),
        ("MonsterService", "src/ServerScriptService/Services/MonsterService.luau"),
        ("RoundService", "src/ServerScriptService/Services/RoundService.luau"),
    ]
    for sname, spath in services_list:
        mod = create_item(server_services, "ModuleScript", sname)
        add_prop_script(mod, read_luau(spath))

    main_server = create_item(server_script_service, "Script", "MainServer")
    add_prop_script(main_server, read_luau("src/ServerScriptService/MainServer.server.luau"))

    # Client Controllers
    client_controllers = create_item(starter_player_scripts, "Folder", "Controllers")

    controllers_list = [
        ("InteractionController", "src/StarterPlayer/StarterPlayerScripts/Controllers/InteractionController.luau"),
        ("CameraController", "src/StarterPlayer/StarterPlayerScripts/Controllers/CameraController.luau"),
        ("AudioController", "src/StarterPlayer/StarterPlayerScripts/Controllers/AudioController.luau"),
        ("UIController", "src/StarterPlayer/StarterPlayerScripts/Controllers/UIController.luau"),
        ("ClientController", "src/StarterPlayer/StarterPlayerScripts/Controllers/ClientController.luau"),
    ]
    for cname, cpath in controllers_list:
        mod = create_item(client_controllers, "ModuleScript", cname)
        add_prop_script(mod, read_luau(cpath))

    main_client = create_item(starter_player_scripts, "LocalScript", "MainClient")
    add_prop_script(main_client, read_luau("src/StarterPlayer/StarterPlayerScripts/MainClient.client.luau"))

    # Write output XML place file
    tree = ET.ElementTree(root)
    ET.indent(tree, space="  ", level=0)
    output_path = "DontWakeHim.rbxlx"
    tree.write(output_path, encoding="utf-8", xml_declaration=True)
    print(f"[SUCCESS] Rebuilt place file with full 3D house architecture and fixed UDim2 UI: {output_path}")

if __name__ == "__main__":
    build_place()
