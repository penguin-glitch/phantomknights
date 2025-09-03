-- All of this is for the Green Knight's signature ability right now. I'm not sure if I'll implement any more lua-based functionality. 
-- Heavily based on how Arc's Outer Expansion implements the cultist abilities.

-- Note to self: We don't know what happens when you try to teleport into a room that's already full. That's bad. Find out.
-- Should probably block targeting from completing if there's no empty slot in the room
-- Also need to fix the cursor rendering - for some reason the default cursor is still rendering over it.

-- written by kokoro, and also taken from Arc's Outer Expansion github.
local function convertMousePositionToEnemyShipPosition(mousePosition)
	local cApp = Hyperspace.Global.GetInstance():GetCApp()
	local combatControl = cApp.gui.combatControl
	local position = combatControl.position
	local targetPosition = combatControl.targetPosition
	local enemyShipOriginX = position.x + targetPosition.x
	local enemyShipOriginY = position.y + targetPosition.y
	return Hyperspace.Point(mousePosition.x - enemyShipOriginX, mousePosition.y - enemyShipOriginY)
end

local function convertMousePositionToPlayerShipPosition(mousePosition)
	local cApp = Hyperspace.Global.GetInstance():GetCApp()
	local combatControl = cApp.gui.combatControl
	local playerPosition = combatControl.playerShipPosition
	return Hyperspace.Point(mousePosition.x - playerPosition.x, mousePosition.y - playerPosition.y)
end

local function get_slot_at_location(shipManager, location, intruder)
    return Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetClosestSlot(location, shipManager.iShipId, intruder)
end

local function get_room_at_location(shipManager, location, includeWalls)
	return Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetSelectedRoom(location.x, location.y, includeWalls)
end

local targeting_toggle = false  -- set this to true to start ability targeting
local target_crew = nil         -- stores the ID of the crew whose ability is being targeted.

local roomAtMouse = -1
local shipAtMouse = -1
local slotAtMouse = nil
local mousePosLocal = Hyperspace.Point(0, 0)
-- Use the teleport icon
local cursorImage = Hyperspace.Resources:CreateImagePrimitiveString("mouse/mouse_teleport_in1.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)

-- Also written by Arc, edited to get the slot at mouse.
script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, function()
	if targeting_toggle then
		local mousePos = Hyperspace.Mouse.position
		mousePosLocal = convertMousePositionToEnemyShipPosition(mousePos)
		--print("MOUSE POS X:"..mousePos.x.." Y:"..mousePos.y.." LOCAL X:"..mousePosLocal.x.." Y:"..mousePosLocal.y)
		if Hyperspace.ships.enemy and mousePosLocal.x >= 0 then
			shipAtMouse = 1
            slotAtMouse = get_slot_at_location(Hyperspace.ships.enemy, mousePosLocal, true)
			roomAtMouse = get_room_at_location(Hyperspace.ships.enemy, mousePosLocal, true)
			--if roomAtMouse >= 0 then 
				--print(roomAtMouse)
			--end
		else
			shipAtMouse = 0
			mousePosLocal = convertMousePositionToPlayerShipPosition(mousePos)
		    roomAtMouse = get_room_at_location(Hyperspace.ships.player, mousePosLocal, true)
            slotAtMouse = get_slot_at_location(Hyperspace.ships.player, mousePosLocal, false)
		end
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(mousePos.x,mousePos.y,0)
		Graphics.CSurface.GL_RenderPrimitive(cursorImage)
		Graphics.CSurface.GL_PopMatrix()
	end
end, function() end)

script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_DOWN, function(x, y)
    if targeting_toggle then
        targeting_toggle = false
        local crewmem = target_crew
        local blueprint = nil

        if slotAtMouse ~= nil and crewmem ~= nil then  
            local start = Hyperspace.Pointf(crewmem.x, crewmem.y)
            local target = Hyperspace.Pointf(mousePosLocal.x, mousePosLocal.y)

            if crewmem.type == "unique_greenknight" then 
                blueprint = "GREENKNIGHT_BEAM"
            else 
                blueprint = "PK_BEAM_" + string.sub(crewmem.type, -1, -1)
            end

            local spaceManager = Hyperspace.App.world.space
            local beam = spaceManager:CreateBeam(
                Hyperspace.Blueprints:GetWeaponBlueprint(blueprint),    
                start,
                crewmem.currentShipId,
                crewmem.iShipId, -- beams cannot target their own ship, so this prevents the beam from spawning on your own ship
                start,
                target,
                crewmem.currentShipId,
                start.RelativeDistance(start, target),
                1
            )
            crewmem.extend:InitiateTeleport(crewmem.currentShipId, roomAtMouse, slotAtMouse.slotId)
        end

    end
end)

script.on_internal_event(Defines.InternalEvents_ACTIVATE_POWER, function(power, shipManager)
    local crewmem = power.crew
    if string.sub(crewmem.type, 0, 14) == "phantom_knight" then
        target_crew = crewmem
        if targeting_toggle then
            targeting_toggle = false
            shipAtMouse = -1
            slotAtMouse = nil
            power:CancelPower(true)
            power.powerCooldown.first = power.powerCooldown.second - 0.1
        else
            targeting_toggle = true
        end
    end
    return Defines.Chain.CONTINUE
end)