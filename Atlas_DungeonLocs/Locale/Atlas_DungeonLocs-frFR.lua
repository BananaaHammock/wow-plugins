﻿-- $Id: Atlas_DungeonLocs-frFR.lua 1167 2011-01-07 13:33:23Z arithmandar $
--[[

	Atlas, a World of Warcraft instance map browser
	Copyright 2005-2010 Dan Gilbert <dan.b.gilbert@gmail.com>
	Copyright 2010-2011 Lothaer <lothayer@gmail.com >, Atlas Team

	This file is part of Atlas.

	Atlas is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 2 of the License, or
	(at your option) any later version.

	Atlas is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with Atlas; if not, write to the Free Software
	Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

--]]

local AceLocale = LibStub:GetLibrary("AceLocale-3.0");
local AL = AceLocale:NewLocale("Atlas_DungeonLocs", "frFR", false);
-- Localize file must set above to false, for example:
--    local AL = AceLocale:NewLocale("Atlas_DungeonLocs", "deDE", false);
if AL then
	--Common
	AL["Battlegrounds"] = "Champs de bataille";
	AL["Blue"] = "Bleu "; -- Espace pour le blanc avant une double ponctuation française
	AL["Dungeon Locations"] = "Emplacements des instances";
	AL["Green"] = "Vert "; -- Espace pour le blanc avant une double ponctuation française
	AL["Instances"] = "Instances";
	AL["White"] = "Blanc "; -- Espace pour le blanc avant une double ponctuation française

	--Zones
	AL["Crusaders' Coliseum"] = "L'épreuve du croisé";
end