-- Tidy Plates - Dedicated to the loves-of-my-life..
--------------------------------------------------------------------------------------------------------------
-- I. Variables and Functions
--------------------------------------------------------------------------------------------------------------
TidyPlates = {}
local _
local numChildren = -1
local activetheme, massQueue, targetQueue, functionQueue = {}, {}, {}, {}		-- Queue Lists
local ForEachPlate													-- Allocated for Function (Defined later in file)
local EMPTY_TEXTURE = "Interface\\Addons\\TidyPlates\\Media\\Empty"
local select, pairs, tostring  = select, pairs, tostring 			-- Local function copies
local CreateTidyPlatesStatusbar = CreateTidyPlatesStatusbar			-- Local function copy
local InCombat, HasTarget = false, false
local Plates, PlatesVisible, PlatesFading, GUID = {}, {}, {}, {}	-- Plate Lists
local nameplate, extended, bars, regions, visual					-- Temp References
local unit, unitcache, style, stylename, unitchanged				-- Temp References
local currentTarget													-- Stores current target plate pointer
local extendedSetAlpha, HighlightIsShown, HighlightSetAlpha			-- Local copies of methods; faster than table lookups
local PlateSetAlpha, PlateGetAlpha									-- Local function copies

----------------------------
-- Internal Functions
----------------------------
-- Simple Functions
local function IsPlateShown(plate) return plate and plate:IsShown() end
local function SetTargetQueue(plate, func) if func then targetQueue[plate] = func end end
local function SetMassQueue(func) if func then massQueue[func] = true end end
local function SetFunctionQueue(func) if func then functionQueue[func] = true end end
-- Indicator Functions
local UpdateIndicator_CustomScaleText, UpdateIndicator_Standard, UpdateIndicator_CustomAlpha
local UpdateIndicator_Level, UpdateIndicator_ThreatGlow, UpdateIndicator_RaidIcon, UpdateIndicator_EliteIcon, UpdateIndicator_UnitColor, UpdateIndicator_Name
local UpdateIndicator_HealthBarColor, UpdateIndicator_HealthBar, UpdateHitboxShape
-- Data and Condition Functions
local OnNewNameplate, OnShowNameplate, OnHideNameplate, OnUpdateNameplate, OnResetNameplate, OnEchoNewNameplate
local OnUpdateHealth, OnUpdateLevel, OnUpdateThreatSituation, OnUpdateRaidIcon
local OnMouseoverNameplate, OnLeaveNameplate, OnRequestWidgetUpdate, OnRequestDelegateUpdate
-- Spell Casting
local UpdateCastAnimation, StartCastAnimation, StopCastAnimation, OnUpdateTargetCastbar
-- Main Loop 
local OnUpdate
local ApplyPlateExtension

--------------------------------------------------------------------------------------------------------------
-- II. Frame/Layer Appearance Functions:  These functions set the appearance of specific object types
--------------------------------------------------------------------------------------------------------------
local function SetObjectShape(object, width, height) object:SetWidth(width); object:SetHeight(height) end
local function SetObjectFont(object,  font, size, flags) object:SetFont(font, size, flags) end
local function SetObjectJustify(object, horz, vert) object:SetJustifyH(horz); object:SetJustifyV(vert) end
local function SetObjectShadow(object, shadow) if shadow then object:SetShadowColor(0,0,0,1); object:SetShadowOffset(1, -1) else object:SetShadowColor(0,0,0,0) end  end
local function SetObjectAnchor(object, anchor, anchorTo, x, y) object:ClearAllPoints();object:SetPoint(anchor, anchorTo, anchor, x, y) end
local function SetObjectTexture(object, texture) object:SetTexture(texture); object:SetTexCoord(0,1,0,1)  end
local function SetObjectBartexture(obj, tex, ori, crop) obj:SetStatusBarTexture(tex); obj:SetOrientation(ori); end
-- SetFontGroupObject
local function SetFontGroupObject(object, objectstyle) 
		SetObjectFont(object, objectstyle.typeface, objectstyle.size, objectstyle.flags) 
		SetObjectJustify(object, objectstyle.align, objectstyle.vertical)
		SetObjectShadow(object, objectstyle.shadow)
end
-- SetAnchorGroupObject
local function SetAnchorGroupObject(object, objectstyle, anchorTo)
		SetObjectShape(object, objectstyle.width, objectstyle.height) --end				
		SetObjectAnchor(object, objectstyle.anchor, anchorTo, objectstyle.x, objectstyle.y) 
end
-- SetBarGroupObject
local function SetBarGroupObject(object, objectstyle, anchorTo)
		SetObjectShape(object, objectstyle.width, objectstyle.height) --end
		SetObjectAnchor(object, objectstyle.anchor, anchorTo, objectstyle.x, objectstyle.y) --end	
		SetObjectBartexture(object, objectstyle.texture, objectstyle.orientation, objectstyle.texcoord) --end
		object:SetBackdrop({bgFile = objectstyle.backdrop,})
end
--------------------------------------------------------------------------------------------------------------
-- III. Nameplate Style: These functions request updates for the appearance of the various graphical objects
--------------------------------------------------------------------------------------------------------------
local UpdateStyle
do
	-- UpdateStyle Variables
	local index, content
	local objectstyle, objectname, objectregion, objectenable
	-- Style Property Groups
	local fontgroup = {"name", "level", "spelltext", "customtext"}
	local anchorgroup = {"healthborder", "threatborder", "castborder", "castnostop",
						"name",  "spelltext", "customtext", "level",
						"customart", "spellicon", "raidicon", "skullicon", "eliteicon", "target"}		
	local bargroup = {"castbar", "healthbar"}
	local texturegroup = {"castborder", "castnostop", "healthborder", "threatborder", "eliteicon", "skullicon", "highlight", "target"}
	-- UpdateStyle: 
	function UpdateStyle()
		-- Frame
		SetAnchorGroupObject(extended, style.frame, nameplate)
		-- Anchorgroup
		for index = 1, #anchorgroup do 
			objectname = anchorgroup[index]; SetAnchorGroupObject(visual[objectname], style[objectname], extended) 
			objectenable = style[objectname].show
			if objectenable then visual[objectname]:Show() else visual[objectname]:Hide() end
		end
		-- Bars
		for index = 1, #bargroup do objectname = bargroup[index]; SetBarGroupObject(bars[objectname], style[objectname], extended) end
		-- Texture
		for index = 1, #texturegroup do objectname = texturegroup[index]; SetObjectTexture(visual[objectname], style[objectname].texture) end
		-- Font Group
		for index = 1, #fontgroup do objectname = fontgroup[index];SetFontGroupObject(visual[objectname], style[objectname]) end
		-- Hide Stuff
		if unit.isElite then visual.eliteicon:Hide() else visual.eliteicon:Hide() end
		if unit.isBoss then visual.level:Hide() else visual.skullicon:Hide() end
		if not unit.isTarget then visual.target:Hide() end
		if not unit.isMarked then visual.raidicon:Hide() end
	end
end
--------------------------------------------------------------------------------------------------------------
-- IV. Indicators: These functions update the actual data shown on the graphical objects
--------------------------------------------------------------------------------------------------------------

do
	local color = {}
	local threatborder, alpha, forcealpha, scale
	-- UpdateIndicator_HealthBarColor: Runs the delgate function to get the desired color
	function UpdateIndicator_HealthBarColor()
		if activetheme.SetHealthbarColor then
			bars.healthbar:SetStatusBarColor(activetheme.SetHealthbarColor(unit))
		else bars.healthbar:SetStatusBarColor(bars.health:GetStatusBarColor()) end	
	end
	-- UpdateIndicator_HealthBar: Updates the value on the health bar
	function UpdateIndicator_HealthBar()
		bars.healthbar:SetMinMaxValues(bars.health:GetMinMaxValues())
		bars.healthbar:SetValue(bars.health:GetValue())
	end
	-- UpdateIndicator_Name: 
	function UpdateIndicator_Name() 
		visual.name:SetText(unit.name)	
		-- Name Color
		if activetheme.SetNameColor then
			visual.name:SetTextColor(activetheme.SetNameColor(unit))
		else visual.name:SetTextColor(1,1,1,1) end
	end
	-- UpdateIndicator_Level:
	function UpdateIndicator_Level() 
		visual.level:SetText(unit.level)
		local tr, tg, tb = regions.level:GetTextColor()
		visual.level:SetTextColor(tr, tg, tb)
	end
	-- UpdateIndicator_ThreatGlow: Updates the aggro glow
	function UpdateIndicator_ThreatGlow() 
		if not style.threatborder.show then return end
		threatborder = visual.threatborder
		if activetheme.SetThreatColor then 
			threatborder:SetVertexColor(activetheme.SetThreatColor(unit) )
		else
			if InCombat and unit.reaction ~= "FRIENDLY" and unit.type == "NPC" then
				local color = style.threatcolor[unit.threatSituation]
				threatborder:Show()
				threatborder:SetVertexColor(color.r, color.g, color.b, (color.a or 1))
			else threatborder:Hide() end
		end
	end	
	-- UpdateIndicator_Target
	function UpdateIndicator_Target()
		if unit.isTarget and style.target.show then visual.target:Show() else visual.target:Hide() end
	end
	-- UpdateIndicator_RaidIcon
	function UpdateIndicator_RaidIcon() 
		if unit.isMarked and style.raidicon.show then 
			visual.raidicon:Show()
			visual.raidicon:SetTexCoord(regions.raidicon:GetTexCoord()) 
		else visual.raidicon:Hide() end
	end
	-- UpdateIndicator_EliteIcon: Updates the border overlay art and threat glow to Elite or Non-Elite art
	function UpdateIndicator_EliteIcon() 
		threatborder = visual.threatborder
		if unit.isElite and style.eliteicon.show then visual.eliteicon:Show() else visual.eliteicon:Hide() end
	end
	-- UpdateIndicator_UnitColor: Update the health bar coloring, if needed
	function UpdateIndicator_UnitColor() 
		-- Set Health Bar
		if activetheme.SetHealthbarColor then
			bars.healthbar:SetStatusBarColor(activetheme.SetHealthbarColor(unit))
		else bars.healthbar:SetStatusBarColor(bars.health:GetStatusBarColor()) end	
		-- Name Color
		if activetheme.SetNameColor then
			visual.name:SetTextColor(activetheme.SetNameColor(unit))
		else visual.name:SetTextColor(1,1,1,1) end
	end
	-- UpdateIndicator_Standard: Updates Standard Indicators
	function UpdateIndicator_Standard()
		if IsPlateShown(nameplate) then
			if unitcache.name ~= unit.name then UpdateIndicator_Name() end
			if unitcache.level ~= unit.level then UpdateIndicator_Level() end
			UpdateIndicator_RaidIcon()
			if unitcache.isElite ~= unit.isElite then UpdateIndicator_EliteIcon() end
			if (unitcache.red ~= unit.red) or (unitcache.green ~= unit.green) or (unitcache.blue ~= unit.blue) then
				UpdateIndicator_UnitColor() end
		end
	end
	-- UpdateIndicator_CustomAlpha: Calls the alpha delegate to get the requested alpha
	function UpdateIndicator_CustomAlpha()
		if activetheme.SetAlpha then 
			local previousAlpha = extended.requestedAlpha
			extended.requestedAlpha = activetheme.SetAlpha(unit) or previousAlpha or unit.alpha or 1
		else extended.requestedAlpha = unit.alpha or 1 end
			
		if not PlatesFading[nameplate] then
			extended:SetAlpha(extended.requestedAlpha)
			--visual.highlight:SetAlpha(extended.requestedAlpha)		-- Active Alpha (Not required)
		end
	end
	-- UpdateIndicator_CustomScaleText: Updates the custom indicators (text, image, alpha, scale)
	function UpdateIndicator_CustomScaleText()
		threatborder = visual.threatborder
		
		if unit.health and (extended.requestedAlpha > 0) then
			-- Scale
			if activetheme.SetScale then 
				scale = activetheme.SetScale(unit)
				if scale then extended:SetScale( scale )end
			end
			-- Set Special-Case Regions
			if style.customtext.show then
				if activetheme.SetCustomText then visual.customtext:SetText(activetheme.SetCustomText(unit))
				else visual.customtext:SetText("") end
			end
			if style.customart.show then
				if activetheme.SetCustomArt then visual.customart:SetTexture(activetheme.SetCustomArt(unit))
				else visual.customart:SetTexture(EMPTY_TEXTURE) end
			end
			UpdateIndicator_UnitColor()
		end
	end
	-- UpdateHitboxShape:  Updates the nameplate's hitbox, but only out of combat
	function UpdateHitboxShape()
		if not InCombat then 
			objectstyle = style.hitbox
			SetObjectShape(nameplate, objectstyle.width, objectstyle.height) 
		end 
	end
end

--------------------------------------------------------------------------------------------------------------
-- V. Data Gather: Gathers Information about the unit and requests updates, if needed
--------------------------------------------------------------------------------------------------------------
do
	--------------------------------
	-- References and Cache
	--------------------------------
	-- UpdateUnitCache
	local function UpdateUnitCache() for key, value in pairs(unit) do unitcache[key] = value end end
	-- UpdateReferences
	function UpdateReferences(plate)
			nameplate = plate
			extended = plate.extended
			bars = extended.bars
			regions = extended.regions 
			unit = extended.unit
			unitcache = extended.unitcache
			visual = extended.visual
			style = extended.style
			threatborder = visual.threatborder
	end
	--------------------------------
	-- Data Conversion Functions
	local ClassReference = {}		
	-- ColorToString: Converts a color to a string with a C- prefix
	local function ColorToString(r,g,b) return "C"..math.floor((100*r) + 0.5)..math.floor((100*g) + 0.5)..math.floor((100*b) + 0.5) end
	-- GetUnitCombatStatus: Determines if a unit is in combat by checking the name text color
	local function GetUnitCombatStatus(r, g, b) return (r > .5 and g < .5) end
	-- GetUnitAggroStatus: Determines if a unit is attacking, by looking at aggro glow region
	local GetUnitAggroStatus
	do
		local shown 
		local red, green, blue
		function GetUnitAggroStatus( region)
			shown = region:IsShown()
			if not shown then return "LOW" end
			red, green, blue = region:GetVertexColor()
			if green > .7 then return "MEDIUM" end
			if red > .7 then return "HIGH" end
		end
	end
	-- GetUnitReaction: Determines the reaction, and type of unit from the health bar color
	local function GetUnitReaction(red, green, blue)									
		if red < .01 and blue < .01 and green > .99 then return "FRIENDLY", "NPC" 
		elseif red < .01 and blue > .99 and green < .01 then return "FRIENDLY", "PLAYER"
		elseif red > .99 and blue < .01 and green > .99 then return "NEUTRAL", "NPC"
		elseif red > .99 and blue < .01 and green < .01 then return "HOSTILE", "NPC"
		else return "HOSTILE", "PLAYER" end
	end
	-- Raid Icon Lookup table
	local ux, uy
	local RaidIconCoordinate = { --from GetTexCoord. input is ULx and ULy (first 2 values).
		[0]		= { [0]		= "STAR", [0.25]	= "MOON", },
		[0.25]	= { [0]		= "CIRCLE", [0.25]	= "SQUARE",	},
		[0.5]	= { [0]		= "DIAMOND", [0.25]	= "CROSS", },
		[0.75]	= { [0]		= "TRIANGLE", [0.25]	= "SKULL", }, }
		
	-- Populates the class color lookup table
	for classname, color in pairs(RAID_CLASS_COLORS) do 
		ClassReference[ColorToString(color.r, color.g, color.b)] = classname end
	--------------------------------
	-- Mass Gather Functions
	--------------------------------
	local function GatherData_Alpha(plate)
		--unit.alpha = plate:GetAlpha()					-- Virtual Parent
		if HasTarget then unit.alpha = plate.alpha else unit.alpha = 1 end	-- Active Alpha
		--unit.alpha = plate:GetAlpha()					-- "No Alpha Override"

		unit.isTarget = HasTarget and unit.alpha == 1
		unit.isMouseover = regions.highlight:IsShown()
		-- GUID
		if unit.isTarget then 
			currentTarget = plate
			OnUpdateTargetCastbar(plate)
			if not unit.guid then
				-- UpdateCurrentGUID
				unit.guid = UnitGUID("target") 
				if unit.guid then GUID[unit.guid] = plate end
			end
			extended:GetFrameLevel(127)
		else
			extended:GetFrameLevel(extended.frameLevel)
		end
		
		--print(extended:GetFrameLevel(), extended:GetFrameStrata(), unit.name, unit.isTarget)
		UpdateIndicator_Target()
		if activetheme.OnContextUpdate then activetheme.OnContextUpdate(extended, unit) end
	end
	
	-- GatherData_Static: Updates Static Information
	local function GatherData_Static()
		unit.name = regions.name:GetText()
		unit.isBoss = regions.skullicon:IsShown()
		unit.isDangerous = unit.isBoss
		unit.isElite = (regions.eliteicon:IsShown() or 0) == 1
	end
	
	-- GatherData_BasicInfo: Updates Unit Variables
	local function GatherData_BasicInfo()
		if unit.isBoss then unit.level = "??"
		else unit.level = regions.level:GetText() end
		unit.health = bars.health:GetValue() or 0
		_, unit.healthmax = bars.health:GetMinMaxValues()
		
		if InCombat then
			unit.threatSituation = GetUnitAggroStatus(regions.threatglow) 
		else unit.threatSituation = "LOW" end
		
		unit.isMarked = regions.raidicon:IsShown() or false
		
		unit.isInCombat = GetUnitCombatStatus(regions.name:GetTextColor())
		unit.red, unit.green, unit.blue = bars.health:GetStatusBarColor()
		unit.levelcolorRed, levelcolorGreen, levelcolorBlue = regions.level:GetTextColor()
		unit.reaction, unit.type = GetUnitReaction(unit.red, unit.green, unit.blue)
		unit.class = ClassReference[ColorToString(unit.red, unit.green, unit.blue)] or "UNKNOWN"
		unit.InCombatLockdown = InCombat
		
		if unit.isMarked then 
			ux, uy = regions.raidicon:GetTexCoord()
			unit.raidIcon = RaidIconCoordinate[ux][uy]
		else unit.raidIcon = nil end
	end
	
	--------------------------------
	-- Graphical Updates
	--------------------------------
	-- CheckNameplateStyle
	local function CheckNameplateStyle()
		if activetheme.SetStyle then 
			stylename = activetheme.SetStyle(unit); extended.style = activetheme[stylename]
		else extended.style = activetheme; stylename = tostring(activetheme) end
		style = extended.style
		if extended.stylename ~= stylename then 
			UpdateStyle()
			extended.stylename = stylename
			unit.style = stylename
		end
		UpdateHitboxShape()
	end
	
	-- ProcessUnitChanges
	local function ProcessUnitChanges()	
			-- Unit Cache
			unitchanged = false
			for key, value in pairs(unit) do 
				if unitcache[key] ~= value then 
					unitchanged = true 
				end
			end
			
			-- Update Style/Indicators
			if unitchanged then
				CheckNameplateStyle()
				UpdateIndicator_Standard()
				UpdateIndicator_HealthBar()
			end
			
			-- Update Widgets 
			if activetheme.OnUpdate then activetheme.OnUpdate(extended, unit) end
			
			-- Update Delegates
			UpdateIndicator_Target()
			UpdateIndicator_ThreatGlow()
			UpdateIndicator_HealthBarColor()
			UpdateIndicator_CustomAlpha()
			UpdateIndicator_CustomScaleText()
			
			-- Cache the old unit information
			UpdateUnitCache()
	end

	--------------------------------
	-- Setup
	--------------------------------
	local function PrepareNameplate(plate)
		-- Gather Basic Information
		GatherData_Static() 
		unit.alpha = 1
		unit.isTarget = false
		unit.isMouseover = false
		unit.targetOf = nil
		extended.unitcache = wipe(extended.unitcache)				
		extended.stylename = ""	
		
		-- For Fading In
		PlatesFading[plate] = true
		extended.requestedAlpha = 0
		extended.visibleAlpha = 0
		extended:SetAlpha(0)
		
		-- Graphics
		unit.isCasting = false
		bars.castbar:Hide()
		visual.highlight:Hide()
		regions.highlight:Hide()

		-- Widgets/Extensions
		if activetheme.OnInitialize then activetheme.OnInitialize(extended) end	
	end

	--------------------------------
	-- Individual Gather/Entry-Point Functions
	--------------------------------	
	-- OnHideNameplate
	function OnHideNameplate(source)
		local plate = source.parentPlate
		UpdateReferences(plate)
		if unit.guid then GUID[unit.guid] = nil end
		--extended:Hide()									-- Virtual Parent
		StopCastAnimation(plate)
		PlatesVisible[plate] = nil
		wipe(extended.unit)
		wipe(extended.unitcache)
		for widgetname, widget in pairs(extended.widgets) do widget:Hide() end
		if plate == currentTarget then currentTarget = nil end
	end
	
	-- OnEchoNewNameplate: Intended to reduce CPU by bypassing the full update, and only checking the alpha value
	local function OnEchoNewNameplate(plate)
		if not plate:IsShown() then return end	
		-- Gather Information
		UpdateReferences(plate)
		GatherData_Alpha(plate)
		ProcessUnitChanges()
	end
	-- OnNewNameplate: When a new nameplate is generated, this function hooks the appropriate functions
	function OnNewNameplate(plate)
		local health, cast = plate:GetChildren()
		UpdateReferences(plate)
		PrepareNameplate(plate)
		GatherData_BasicInfo()
		
		-- Alternative to reduce initial CPU load
		CheckNameplateStyle()
		UpdateIndicator_CustomAlpha()
			
		-- Hook for Updates	
		health:HookScript("OnShow", OnShowNameplate )
		health:HookScript("OnHide", OnHideNameplate)
		health:HookScript("OnValueChanged", OnUpdateHealth) 
		
		-- Activates nameplate visibility
		--extended:SetPoint("CENTER", plate)				-- Virtual Parent
		--extended:Show()									-- Virtual Parent
		PlatesVisible[plate] = true
		SetTargetQueue(plate, OnEchoNewNameplate)		-- Echo for a partial update (alpha only)
	end
	
	-- OnShowNameplate
	function OnShowNameplate(source)
		local plate = source.parentPlate
		-- Activate Plate
		PlatesVisible[plate] = true
		UpdateReferences(plate)
		PrepareNameplate(plate)
		GatherData_BasicInfo()

		CheckNameplateStyle()
		UpdateIndicator_CustomAlpha()
		UpdateHitboxShape()
		
		--extended:Show()									-- Virtual Parent
		SetTargetQueue(plate, OnUpdateNameplate)		-- Echo for a full update
	end

	-- OnUpdateNameplate
	function OnUpdateNameplate(plate)		
		if not plate:IsShown() then return end	
		-- Gather Information
		UpdateReferences(plate)
		GatherData_Alpha(plate)
		GatherData_BasicInfo()
		ProcessUnitChanges()
	end
	-- OnUpdateLevel
	function OnUpdateLevel(plate)
		if not IsPlateShown(plate) then return end
		UpdateReferences(plate)
		if unit.isBoss then unit.level = "??"
		else unit.level = regions.level:GetText() end
		UpdateIndicator_Level()
	end

	-- OnUpdateThreatSituation
	function OnUpdateThreatSituation(plate)
		if not IsPlateShown(plate) then return end
		UpdateReferences(plate)

		if InCombat then unit.threatSituation = GetUnitAggroStatus(regions.threatglow) 
		else unit.threatSituation = "LOW" end
		unit.isInCombat = GetUnitCombatStatus(regions.name:GetTextColor())
				
		CheckNameplateStyle()
		UpdateIndicator_ThreatGlow()
		UpdateIndicator_CustomAlpha()
		UpdateIndicator_CustomScaleText()
		UpdateIndicator_HealthBarColor()
	end
	
	-- OnUpdateRaidIcon
	function OnUpdateRaidIcon(plate) 
		if not IsPlateShown(plate) then return end
		UpdateReferences(plate)
		unit.isMarked = regions.raidicon:IsShown() or false
		if unit.isMarked then 
			ux, uy = regions.raidicon:GetTexCoord()
			unit.raidIcon = RaidIconCoordinate[ux][uy]
		else unit.raidIcon = nil end	
		UpdateIndicator_RaidIcon()
		UpdateIndicator_UnitColor()
	end
	
	-- OnUpdateReaction
	function OnUpdateReaction(plate) 
		if not IsPlateShown(plate) then return end
		UpdateReferences(plate)
		unit.red, unit.green, unit.blue = bars.health:GetStatusBarColor()
		unit.reaction, unit.type = GetUnitReaction(unit.red, unit.green, unit.blue)
		unit.class = ClassReference[ColorToString(unit.red, unit.green, unit.blue)] or "UNKNOWN"
		UpdateIndicator_UnitColor()
		UpdateIndicator_CustomScaleText()
	end	

	-- OnMouseoverNameplate
	function OnMouseoverNameplate(plate)
		if not IsPlateShown(plate) then return end
		UpdateReferences(plate)
		unit.isMouseover = regions.highlight:IsShown()
		
		if unit.isMouseover then
			visual.highlight:Show()
			if (not unit.guid) then 
				unit.guid = UnitGUID("mouseover") 
				if unit.guid then GUID[unit.guid] = plate end
			end
		else visual.highlight:Hide() end
		
		OnUpdateThreatSituation(plate)
		if activetheme.OnContextUpdate then activetheme.OnContextUpdate(extended, unit) end
		if activetheme.OnUpdate then activetheme.OnUpdate(extended, unit) end
	end
	
	-- OnRequestWidgetUpdate: Updates just the widgets
	function OnRequestWidgetUpdate(plate)
		if not IsPlateShown(plate) then return end
		UpdateReferences(plate)
		if activetheme.OnContextUpdate then activetheme.OnContextUpdate(extended, unit) end
		if activetheme.OnUpdate then activetheme.OnUpdate(extended, unit) end
	end
	
	-- OnRequestDelegateUpdate: Updates just the delegate function indicators (excluding Style?)
	function OnRequestDelegateUpdate(plate)
			if not IsPlateShown(plate) then return end
			UpdateReferences(plate)
			UpdateIndicator_ThreatGlow()
			UpdateIndicator_HealthBarColor()
			UpdateIndicator_CustomAlpha()
			UpdateIndicator_CustomScaleText()
	end

	-- OnUpdateHealth
	function OnUpdateHealth(source)
		local plate = source.parentPlate
		if not IsPlateShown(plate) then return end
		UpdateReferences(plate)
		unit.health = bars.health:GetValue() or 0
		_, unit.healthmax = bars.health:GetMinMaxValues()
		UpdateIndicator_HealthBar()
		UpdateIndicator_HealthBarColor()
		UpdateIndicator_CustomAlpha()
		UpdateIndicator_CustomScaleText()
	end

	-- Update the Animation
	function UpdateCastAnimation(castbar)
		local currentTime = GetTime()
		if currentTime > (castbar.endTime or 0) then
			StopCastAnimation(castbar.parentPlate)
		else castbar:SetValue(currentTime) end
	end
	
	-- Shows the Cast Animation (requires references)
	function StartCastAnimation(plate, spell, displayName, icon, startTime, endTime, notInterruptible, channel)
		UpdateReferences(plate)
		if (tonumber(GetCVar("showVKeyCastbar")) == 1) and spell then
			local castbar = bars.castbar
			local r, g, b, a = 1, .8, 0, 1
			unit.isCasting = true
			unit.spellName = spell
			unit.spellIsShielded = notInterruptible
			if activetheme.SetCastbarColor then  r, g, b, a = activetheme.SetCastbarColor(unit)  end	
			
			castbar.endTime = endTime
			castbar:SetStatusBarColor( r, g, b, a or 1)
			castbar:SetMinMaxValues(startTime, endTime)
			castbar:SetValue(GetTime())
			castbar:Show()	
			visual.spelltext:SetText(displayName or spell)

			visual.spellicon:SetTexture(icon)
			if notInterruptible then 
				visual.castnostop:Show(); visual.castborder:Hide()
			else visual.castnostop:Hide(); visual.castborder:Show() end
			
			castbar:SetScript("OnUpdate", UpdateCastAnimation)	
			UpdateIndicator_CustomScaleText()	
			UpdateIndicator_CustomAlpha()
		end
	end
	
	-- Hides the Cast Animation (requires references)
	function StopCastAnimation(plate)
		UpdateReferences(plate)
		bars.castbar:Hide()	
		bars.castbar:SetScript("OnUpdate", nil)
		unit.isCasting = false
		UpdateIndicator_CustomScaleText()
		UpdateIndicator_CustomAlpha()
	end

	-- OnUpdateTargetCastbar: Called from hooking into the original nameplate castbar's "OnValueChanged"
	function OnUpdateTargetCastbar(source)
		if not source then return end
		local plate
		if PlatesVisible[source] then plate = source else plate = source.parentPlate end
		
		if plate.extended.unit.isTarget then
			-- Grabs the target's casting information
			local spell, name, icon, start, finish, noInt, channel, _
			spell, _, name, icon, start, finish, _, _, noInt = UnitCastingInfo("target")
			if not spell then spell, _, name, icon, start, finish, _, _, noInt = UnitChannelInfo("target"); channel = true end	
			
			if spell then StartCastAnimation(plate, spell, name, icon, start/1000, finish/1000, noInt, channel) 
			else StopCastAnimation(plate) end
		end
	end	

	-- OnResetNameplate
	function OnResetNameplate(plate)
		local extended = plate.extended
		extended.unitcache = wipe(extended.unitcache)				
		extended.stylename = ""
		OnShowNameplate(extended)
	end
end

--------------------------------------------------------------------------------------------------------------
-- VI. Nameplate Extension: Applies scripts, hooks, and adds additional frame variables and elements
--------------------------------------------------------------------------------------------------------------

do
	local bars, regions, health, castbar, healthbar, visual
	local region
	local platelevels = 1
	
	function ApplyPlateExtension(plate)
		Plates[plate] = true
		--plate.extended = CreateFrame("Frame", nil, WorldFrame)		-- Virtual Parent
		plate.extended = CreateFrame("Frame", nil, plate)		-- Active Alpha
		local extended = plate.extended
		platelevels = platelevels + 1
		extended.frameLevel = platelevels
		extended:SetFrameLevel(platelevels)
		
		extended.style, extended.unit, extended.unitcache, extended.stylecache, extended.widgets = {}, {}, {}, {}, {}
		
		extended.regions, extended.bars, extended.visual = {}, {}, {}
		regions = extended.regions
		bars = extended.bars
		bars.health, bars.cast = plate:GetChildren()
		extended.stylename = ""

		-- Set Frame Levels and Parent
		regions.threatglow, regions.healthborder, regions.castborder, regions.castnostop,
			regions.spellicon, regions.highlight, regions.name, regions.level,
			regions.skullicon, regions.raidicon, regions.eliteicon = plate:GetRegions()
			
		-- This block makes the Blizz nameplate invisible
		regions.threatglow:SetTexCoord( 0, 0, 0, 0 )
		regions.healthborder:SetTexCoord( 0, 0, 0, 0 )
		regions.castborder:SetTexCoord( 0, 0, 0, 0 )
		regions.castnostop:SetTexCoord( 0, 0, 0, 0 )
		regions.skullicon:SetTexCoord( 0, 0, 0, 0 )
		regions.eliteicon:SetTexCoord( 0, 0, 0, 0 )
		regions.name:SetWidth( 000.1 )
		regions.level:SetWidth( 000.1 )
		regions.spellicon:SetTexCoord( 0, 0, 0, 0 )
		regions.spellicon:SetWidth(.001)
		regions.raidicon:SetAlpha( 0 )
		regions.highlight:SetTexture(EMPTY_TEXTURE)
		bars.health:SetStatusBarTexture(EMPTY_TEXTURE) 
		bars.cast:SetStatusBarTexture(EMPTY_TEXTURE) 
		
		-- Create Statusbars
		bars.healthbar = CreateTidyPlatesStatusbar(extended) 
		bars.castbar = CreateTidyPlatesStatusbar(extended) 
		health, cast, healthbar, castbar = bars.health, bars.cast, bars.healthbar, bars.castbar
		extended.parentPlate = plate
		health.parentPlate = plate
		cast.parentPlate = plate
		castbar.parentPlate = plate
		
		-- Visible Bars
		local level = extended:GetFrameLevel()
		healthbar:SetFrameLevel(level)
		castbar.parent = plate
		castbar:Hide()
		castbar:SetFrameLevel(level)
		castbar:SetStatusBarColor(1,.8,0)
		
		-- Visual Regions
		visual = extended.visual
		visual.customart = extended:CreateTexture(nil, "OVERLAY")
		visual.target = extended:CreateTexture(nil, "ARTWORK")
		visual.eliteicon = extended:CreateTexture(nil, "OVERLAY")
		visual.threatborder = healthbar:CreateTexture(nil, "ARTWORK")
		visual.spelltext = castbar:CreateFontString(nil, "OVERLAY")
		visual.customtext = healthbar:CreateFontString(nil, "OVERLAY")
		visual.healthborder = healthbar:CreateTexture(nil, "ARTWORK")
		visual.castborder = castbar:CreateTexture(nil, "ARTWORK")
		visual.castnostop = castbar:CreateTexture(nil, "ARTWORK")
		visual.spellicon = castbar:CreateTexture(nil, "OVERLAY")
		visual.skullicon = healthbar:CreateTexture(nil, "OVERLAY")
		visual.raidicon = healthbar:CreateTexture(nil, "OVERLAY")
		visual.raidicon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
		visual.name  = healthbar:CreateFontString(nil, "OVERLAY")
		visual.level = healthbar:CreateFontString(nil, "OVERLAY")
		visual.highlight = healthbar:CreateTexture(nil, "OVERLAY")
		visual.highlight:SetAllPoints(visual.healthborder)
		visual.highlight:SetBlendMode("ADD")
		
		--extended:Hide()		-- Virtual Parent
		
		if not extendedSetAlpha then
			PlateSetAlpha = plate.SetAlpha
			PlateGetAlpha = plate.GetAlpha
			extendedSetAlpha = plate.extended.SetAlpha
			HighlightIsShown = plate.extended.visual.highlight.IsShown
		end
				
		OnNewNameplate(plate)
	end
end

--------------------------------------------------------------------------------------------------------------
-- VII. World Update Functions: Refers new plates to 'ApplyPlateExtension()', and watches for Alpha/Transparency
-- and Highlight/Mouseover changes, and sends those changes to the appropriate handler.
-- Also processes the update queue (ie. echos)
--------------------------------------------------------------------------------------------------------------

do
	local plate, curChildren
	local WorldGetNumChildren, WorldGetChildren = WorldFrame.GetNumChildren, WorldFrame.GetChildren
	
	-- IsFrameNameplate: Checks to see if the frame is a Blizz nameplate
	local function IsFrameNameplate(frame)
		local region = frame:GetRegions()
		return region and region:GetObjectType() == "Texture" and region:GetTexture() == "Interface\\TargetingFrame\\UI-TargetingFrame-Flash" 
	end
	
	-- OnWorldFrameChange: Checks for new Blizz Plates
	local function OnWorldFrameChange(...)
		for index = 1, select("#", ...) do
			plate = select(index, ...)
			if not Plates[plate] and IsFrameNameplate(plate) then
				ApplyPlateExtension(plate)
			end
		end
	end
	
	-- ForEachPlate
	function ForEachPlate(functionToRun, ...)
		for plate in pairs(PlatesVisible) do
			if plate.extended:IsShown() then -- Plate and extended frame both explicitly visible
				functionToRun(plate, ...)
			end
		end
	end

	-- Nameplate Fade-In
	local visibleAlpha, requestedAlpha
	local fadeInRate, fadeOutRate = .07, .2
	local function UpdateNameplateFade(plate)
		extended = plate.extended
		--if extended then
			visibleAlpha = extended.visibleAlpha
			requestedAlpha = extended.requestedAlpha
			if visibleAlpha < requestedAlpha then
				visibleAlpha = visibleAlpha + fadeInRate
				extended.visibleAlpha = visibleAlpha
				extendedSetAlpha(extended, visibleAlpha)
			else
				extended.visibleAlpha = requestedAlpha
				extendedSetAlpha(extended, visibleAlpha)
				PlatesFading[plate] = nil
			end
		--end
	end
	
	-- OnUpdate: This function is processed every frame!
	local queuedFunction
	local HasMouseover, LastMouseover, CurrentMouseover
	
	function OnUpdate(self)
		HasMouseover = false
		-- This block checks for highlight changes
		for plate in pairs(PlatesVisible) do
		
			-- [[		Active Alpha		-- For "No Alpha Override" (Comment this all out)
			-- Alpha: Gets the nameplate's original alpha and restore's full opacity
			-- The Blizz UI sets the alpha on every frame, so we need to set it back, on every frame
			if (HasTarget) then 
				plate.alpha = PlateGetAlpha(plate)	
				PlateSetAlpha(plate, 1) 			
			end
			--]]
			
			-- Highlight: CURSOR_UPDATE events are unreliable for GUID updates.  This provides a much better experience.
			highlightRegion = plate.extended.regions.highlight
			if HighlightIsShown(highlightRegion) then
				HasMouseover = true
				CurrentMouseover = plate
			end
		end

		-- Fade-In Loop
		for plate in pairs(PlatesFading) do
			UpdateNameplateFade(plate)
		end

		-- Process the Update Request Queues
		if massQueue[OnResetNameplate] then
			ForEachPlate(OnResetNameplate)
			for queuedFunction in pairs(massQueue) do massQueue[queuedFunction] = nil end
		else
			-- Function Queue: Runs the specified function
			for queuedFunction, run in pairs(functionQueue) do 
				queuedFunction()
				functionQueue[queuedFunction] = nil 
			end
			-- Mass Update Queue: Run the specified function on ALL visible plates
			if massQueue[OnUpdateNameplate] then 
				for queuedFunction in pairs(massQueue) do massQueue[queuedFunction] = nil end
				ForEachPlate(OnUpdateNameplate)
			else
				for queuedFunction in pairs(massQueue) do
					massQueue[queuedFunction] = nil
					ForEachPlate(queuedFunction)
				end	
			end
			-- Spefific Nameplate Function Queue: Runs the function on a specific plate
			for plate, queuedFunction in pairs(targetQueue) do
				targetQueue[plate] = nil
				queuedFunction(plate)
			end
		end	
		
		-- Process Mouseover
		if HasMouseover then 
			if LastMouseover ~= CurrentMouseover then
				--ForEachPlate(OnLeaveNameplate)		-- Resets the highlight regions
				if LastMouseover then OnMouseoverNameplate(LastMouseover) end
				OnMouseoverNameplate(CurrentMouseover)
				LastMouseover = CurrentMouseover
			end
		elseif LastMouseover then 
			OnMouseoverNameplate(LastMouseover)
			LastMouseover = nil 
		end
		
		-- Detect New Nameplates
		curChildren = WorldGetNumChildren(WorldFrame)
		if (curChildren ~= numChildren) then
			numChildren = curChildren
			OnWorldFrameChange(WorldGetChildren(WorldFrame)) 
		end	
	end
end
--------------------------------------------------------------------------------------------------------------
-- VIII. Event Handlers: sends event-driven changes to  the appropriate gather/update handler.
--------------------------------------------------------------------------------------------------------------
do
	local events = {}
	local function EventHandler(self, event, ...)
		events[event](event, ...)
	end
	local PlateHandler = CreateFrame("Frame", nil, WorldFrame)
	PlateHandler:SetFrameStrata("TOOLTIP") -- When parented to WorldFrame, causes OnUpdate handler to run close to last
	PlateHandler:SetScript("OnEvent", EventHandler)
	
	-- Events
	function events:PLAYER_ENTERING_WORLD() PlateHandler:SetScript("OnUpdate", OnUpdate) end
	function events:PLAYER_REGEN_ENABLED() InCombat = false; SetMassQueue(OnUpdateNameplate) end
	function events:PLAYER_REGEN_DISABLED() InCombat = true; SetMassQueue(OnUpdateNameplate) end
	
	function events:PLAYER_TARGET_CHANGED()
		HasTarget = UnitExists("target") == 1 -- Must be bool, never nil!
		if (not HasTarget) then currentTarget = nil end
		SetMassQueue(OnUpdateNameplate)		-- Could be "SetMassQueue(UpdateTarget), someday...  :-o
	end

	function events:RAID_TARGET_UPDATE() ForEachPlate(OnUpdateRaidIcon) end
	function events:UNIT_THREAT_SITUATION_UPDATE() 	SetMassQueue(OnUpdateThreatSituation) end  -- Only fired when a target changes
	function events:UNIT_LEVEL() ForEachPlate(OnUpdateLevel) end
	function events:PLAYER_CONTROL_LOST() ForEachPlate(OnUpdateReaction) end
	events.PLAYER_CONTROL_GAINED = events.PLAYER_CONTROL_LOST
	events.UNIT_FACTION = events.PLAYER_CONTROL_LOST	
	
	function events:UNIT_SPELLCAST_START(unitid,  spell, ...) if unitid == "target" and currentTarget then OnUpdateTargetCastbar(currentTarget) end  end
	events.UNIT_SPELLCAST_STOP = events.UNIT_SPELLCAST_START
	events.UNIT_SPELLCAST_INTERRUPTED = events.UNIT_SPELLCAST_START
	events.UNIT_SPELLCAST_FAILED = events.UNIT_SPELLCAST_START
	events.UNIT_SPELLCAST_DELAYED = events.UNIT_SPELLCAST_START
	events.UNIT_SPELLCAST_CHANNEL_START = events.UNIT_SPELLCAST_START
	events.UNIT_SPELLCAST_CHANNEL_STOP = events.UNIT_SPELLCAST_START
	events.UNIT_SPELLCAST_FAILED_QUIET = events.UNIT_SPELLCAST_START
	
	-- Registration of Blizzard Events
	for eventname in pairs(events) do PlateHandler:RegisterEvent(eventname) end	
end

--------------------------------------------------------------------------------------------------------------
-- IX. External Commands: Allows widgets and themes to request updates to the plates.
-- Useful to make a theme respond to externally-captured data (such as the combat log)
--------------------------------------------------------------------------------------------------------------
function TidyPlates:ForceUpdate() SetMassQueue(OnResetNameplate) end
function TidyPlates:Update() SetMassQueue(OnUpdateNameplate) end
function TidyPlates:RequestWidgetUpdate() SetMassQueue(OnRequestWidgetUpdate) end
function TidyPlates:RequestDelegateUpdate() SetMassQueue(OnRequestDelegateUpdate) end
function TidyPlates:ActivateTheme(theme) if theme and type(theme) == 'table' then activetheme = theme; SetMassQueue(OnResetNameplate) end end
TidyPlates.StartCastAnimationOnNameplate = StartCastAnimation
TidyPlates.StopCastAnimationOnNameplate = StopCastAnimation
TidyPlates.NameplatesByGUID, TidyPlates.NameplatesAll, TidyPlates.NameplatesByVisible = GUID, Plates, PlatesVisible














