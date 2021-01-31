local E, L, V, P, G = unpack(ElvUI);
local LP = E:GetModule('LocationPlus')
local DT = E:GetModule('DataTexts')

local format, tinsert = string.format, table.insert
local SHOW, OTHER, LEVEL_RANGE, PROFESSIONS_FISHING, EMBLEM_SYMBOL, STATUS, CURRENCY, TRADE_SKILLS, FILTERS = SHOW, OTHER, LEVEL_RANGE, PROFESSIONS_FISHING, EMBLEM_SYMBOL, STATUS, CURRENCY, TRADE_SKILLS, FILTERS
local COLOR, CLASS_COLORS, CUSTOM, COLOR_PICKER = COLOR, CLASS_COLORS, CUSTOM, COLOR_PICKER

-- GLOBALS: AceGUIWidgetLSMlists

-- Defaults
P['locplus'] = {
-- Options
	['both'] = true,
	['combat'] = false,
	['timer'] = 0.5,
	['dig'] = true,
	['displayOther'] = "RLEVEL",
	['showicon'] = true,
	['hidecoords'] = false,
	['hidecoordsInInstance'] = true,
	['zonetext'] = true,
-- Tooltip
	['tt'] = true,
	['ttcombathide'] = true,
	['tthint'] = true,
	['ttst'] = true,
	['ttlvl'] = true,
	['fish'] = true,
	['petlevel'] = true,
	['ttinst'] = true,
	['ttreczones'] = true,
	['ttrecinst'] = true,
	['ttcoords'] = true,
	['curr'] = true,
	['prof'] = true,
	['profcap'] = false,
-- Filters
	['tthideraid'] = false,
	['tthidepvp'] = false,
-- Layout
	['dtshow'] = true,
	['shadow'] = false,
	['trans'] = true,
	['noback'] = true,
	['ht'] = false,
	['frameStrata'] = "LOW",
	['frameLevel'] = 2,
	['lpwidth'] = 200,
	['dtwidth'] = 100,
	['dtheight'] = 21,
	['lpauto'] = true,
	['userColor'] = { r = 1, g = 1, b = 1 },
	['customColor'] = 1,
	['userCoordsColor'] = { r = 1, g = 1, b = 1 },
	['customCoordsColor'] = 3,
	['trunc'] = false,
	['mouseover'] = false,
	['malpha'] = 1,
	['spacingAuto'] = true,
	['spacingManual'] = 20,
-- Fonts
	['lpfont'] = E.db.general.font,
	['lpfontsize'] = 12,
	['lpfontflags'] = "NONE",
	['useDTfont'] = true,
-- Init
	['LoginMsg'] = true,
}
P.datatexts.panels.LocPlusRightDT = {
	[1] = 'Time',
}
P.datatexts.panels.LocPlusLeftDT = {
	[1] = 'Primary Stat',
}

local FISH_ICON = "|TInterface\\AddOns\\ElvUI_LocPlus\\media\\fish.tga:14:14|t"
local PET_ICON = "|TInterface\\AddOns\\ElvUI_LocPlus\\media\\pet.tga:14:14|t"
local LEVEL_ICON = "|TInterface\\AddOns\\ElvUI_LocPlus\\media\\levelup.tga:14:14|t"

local function Options()
	E.Options.args.locplus = {
		order = 9000,
		type = 'group',
		name = LP.Title,
		childGroups = "tab",
		args = {
			name = {
				order = 1,
				type = "header",
				name = LP.Title..format("v|cffffa500%s|r",LP.version)..L[" by Benik (EU-Emerald Dream)"],
			},		
			desc = {
				order = 2,
				type = "description",
				name = L["LocationPlus adds a movable player location panel, 2 datatext panels and more"],
			},
			spacer1 = {
				order = 3,
				type = "description",
				name = "",
			},		
			toptop = {
				order = 4,
				type = "group",
				name = L["General"],
				guiInline = true,
				get = function(info) return E.db.locplus[ info[#info] ] end,
				set = function(info, value) E.db.locplus[ info[#info] ] = value; end, 
				args = {
					LoginMsg = {
						order = 1,
						name = L["Login Message"],
						desc = L["Enable/Disable the Login Message"],
						type = 'toggle',
						width = "full",                              
					},
					combat = {
						order = 2,
						name = L["Combat Hide"],
						desc = L["Show/Hide all panels when in combat"],
						type = 'toggle',				
					},
					timer = {
						order = 3,
						name = L["Update Timer"],
						desc = L["Adjust coords updates (in seconds) to avoid cpu load. Bigger number = less cpu load. Requires reloadUI."],
						type = "range",
						min = 0.05, max = 1, step = 0.05,
						set = function(info, value) E.db.locplus[ info[#info] ] = value; E:StaticPopup_Show("PRIVATE_RL"); end,					
					},
					zonetext = {
						order = 4,
						name = L["Hide Blizzard Zone Text"],
						type = 'toggle',
						set = function(info, value) E.db.locplus[ info[#info] ] = value; LP:ToggleBlizZoneText() end,					
					},
				},
			},
			general = {
				order = 5,
				type = "group",
				name = SHOW,
				get = function(info) return E.db.locplus[ info[#info] ] end,
				set = function(info, value) E.db.locplus[ info[#info] ] = value; end,
				args = {
					both = {
						order = 1,
						name = L["Zone and Subzone"],
						desc = L["Displays the main zone and the subzone in the location panel"],
						type = 'toggle',
						width = "full",					
					},
					hidecoords = {
						order = 2,
						name = L["Hide Coords"],
						desc = L["Show/Hide the coord frames"],
						type = 'toggle',
						set = function(info, value) E.db.locplus[ info[#info] ] = value; LP:HideCoords() end,					
					},
					hidecoordsInInstance = {
						order = 3,
						name = L["Hide Coords in Instance"],
						type = 'toggle',
						disabled = function() return E.db.locplus.hidecoords end,
						set = function(info, value) E.db.locplus[ info[#info] ] = value; LP:HideCoords() end,					
					},
					dig = {
						order = 4,
						name = L["Detailed Coords"],
						desc = L["Adds 2 digits in the coords"],
						type = 'toggle',
						set = function(info, value) E.db.locplus[ info[#info] ] = value; LP:CoordsDigit() end,					
					},
					displayOther = {
						order = 5,
						name = OTHER,
						type = 'select',
						desc = L["Show additional info in the Location Panel."],
							values = {
								['NONE'] = L['None'],
								['RLEVEL'] = LEVEL_ICON.." "..LEVEL_RANGE,
								['PET'] = PET_ICON.." "..L['Battle Pet Level'],
								['PFISH'] = FISH_ICON.." "..PROFESSIONS_FISHING,
							},			
					},
					showicon = {
						order = 6,
						name = EMBLEM_SYMBOL,
						type = 'toggle',
						disabled = function() return E.db.locplus.displayOther == 'NONE' end,					
					},					
					mouseover = {
						order = 7,
						name = L["Mouse Over"],
						desc = L["The frame is not shown unless you mouse over the frame."],
						type = 'toggle',
						width = "full",	
						set = function(info, value) E.db.locplus[ info[#info] ] = value; LP:MouseOver() end,					
					},
					malpha = {
						order = 8,
						type = "range",
						name = L["Alpha"],
						desc = L["Change the alpha level of the frame."],
						min = 0, max = 1, step = 0.1,
						disabled = function() return not E.db.locplus.mouseover end,
						set = function(info, value) E.db.locplus[ info[#info] ] = value; LP:MouseOver() end,
					},			
				},
			},
			gen_tt = {
				order = 6,
				type = "group",
				name = L["Tooltip"],
				get = function(info) return E.db.locplus[ info[#info] ] end,
				set = function(info, value) E.db.locplus[ info[#info] ] = value; end,	
				args = {
					tt_grp = {
						order = 1,
						type = "group",
						name = L["Tooltip"],
						guiInline = true,
						args = {				
							tt = {
								order = 1,
								name = L["Show/Hide tooltip"],
								type = 'toggle',
							},
							ttcombathide = {
								order = 2,
								name = L["Combat Hide"],
								desc = L["Hide tooltip while in combat."],
								type = 'toggle',
								disabled = function() return not E.db.locplus.tt end,			
							},
							tthint = {
								order = 3,
								name = L["Show Hints"],
								desc = L["Enable/Disable hints on Tooltip."],
								type = 'toggle',
								disabled = function() return not E.db.locplus.tt end,			
							},
						},
					},
					tt_options = {
						order = 2,
						type = "group",
						name = SHOW,
						guiInline = true,
						args = {
							ttst = {
								order = 1,
								name = STATUS,
								desc = L["Enable/Disable status on Tooltip."],
								type = 'toggle',
								width = "full",
								disabled = function() return not E.db.locplus.tt end,			
							},
							ttlvl = {
								order = 2,
								name = LEVEL_RANGE,
								desc = L["Enable/Disable level range on Tooltip."],
								type = 'toggle',
								disabled = function() return not E.db.locplus.tt end,		
							},
							fish = {
								order = 3,
								name = L["Area Fishing level"],
								desc = L["Enable/Disable fishing level on the area."],
								type = 'toggle',
								disabled = function() return not E.db.locplus.tt end,			
							},
							petlevel = {
								order = 4,
								name = L["Battle Pet level"],
								desc = L["Enable/Disable battle pet level on the area."],
								type = 'toggle',
								disabled = function() return not E.db.locplus.tt end,			
							},
							spacer2 = {
								order = 5,
								type = "description",
								width = "full",
								name = "",
							},	
							ttreczones = {
								order = 6,
								name = L["Recommended Zones"],
								desc = L["Enable/Disable recommended zones on Tooltip."],
								type = 'toggle',
								width = "full",
								disabled = function() return not E.db.locplus.tt end,	
							},
							ttinst = {
								order = 7,
								name = L["Zone Dungeons"],
								desc = L["Enable/Disable dungeons in the zone, on Tooltip."],
								type = 'toggle',
								disabled = function() return not E.db.locplus.tt end,		
							},
							ttrecinst = {
								order = 8,
								name = L["Recommended Dungeons"],
								desc = L["Enable/Disable recommended dungeons on Tooltip."],
								type = 'toggle',
								disabled = function() return not E.db.locplus.tt end,		
							},
							ttcoords = {
								order = 9,
								name = L["with Entrance Coords"],
								desc = L["Enable/Disable the coords for area dungeons and recommended dungeon entrances, on Tooltip."],
								type = 'toggle',
								disabled = function() return not E.db.locplus.tt end,		
							},
							spacer3 = {
								order = 10,
								type = "description",
								width = "full",
								name = "",
							},	
							curr = {
								order = 11,
								name = CURRENCY,
								desc = L["Enable/Disable the currencies, on Tooltip."],
								type = 'toggle',
								width = "full",
								disabled = function() return not E.db.locplus.tt end,			
							},
							prof = {
								order = 12,
								name = TRADE_SKILLS,
								desc = L["Enable/Disable the professions, on Tooltip."],
								type = 'toggle',
								disabled = function() return not E.db.locplus.tt end,			
							},
							profcap = {
								order = 13,
								name = L["Hide capped"],
								desc = L["Hides a profession when the player reaches its highest level."],
								type = 'toggle',
								disabled = function() return not E.db.locplus.tt or not E.db.locplus.prof end,			
							},
						},
					},
					tt_filters = {
						order = 3,
						type = "group",
						name = FILTERS,
						guiInline = true,
						get = function(info) return E.db.locplus[ info[#info] ] end,
						set = function(info, value) E.db.locplus[ info[#info] ] = value; end,	
						args = {
							tthideraid = {
								order = 1,
								name = L["Hide Raid"],
								desc = L["Show/Hide raids on recommended dungeons."],
								type = 'toggle',
								disabled = function() return not E.db.locplus.tt end,
							},
							tthidepvp = {
								order = 2,
								name = L["Hide PvP"],
								desc = L["Show/Hide PvP zones, Arenas and BGs on recommended dungeons and zones."],
								type = 'toggle',
								disabled = function() return not E.db.locplus.tt end,
							},
						},
					},
				},
			},
			layout = {
				order = 7,
				type = "group",
				name = L["Layout"],
				args = {
					lp_lo = {
						order = 1,
						type = "group",
						name = L["Layout"],
						guiInline = true,
						get = function(info) return E.db.locplus[ info[#info] ] end,
						args = {	
							shadow = {
								order = 1,
								name = L["Shadows"],
								desc = L["Enable/Disable layout with shadows."],
								type = 'toggle',
								disabled = function() return not E.db.locplus.noback end,
								set = function(info, value) E.db.locplus[ info[#info] ] = value; LP:ShadowPanels(); end,					
							},
							trans = {
								order = 2,
								name = L["Transparent"],
								desc = L["Enable/Disable transparent layout."],
								type = 'toggle',
								disabled = function() return not E.db.locplus.noback end,
								set = function(info, value) E.db.locplus[ info[#info] ] = value; LP:TransparentPanels() end,	
							},
							noback = {
								order = 3,
								name = L["Backdrop"],
								desc = L["Hides all panels background so you can place them on ElvUI's top or bottom panel."],
								type = 'toggle',
								set = function(info, value) E.db.locplus[ info[#info] ] = value; LP:TransparentPanels(); LP:ShadowPanels(); end,	
							},							
						},
					},
					locpanel = {
						order = 2,
						type = "group",
						name = L["Location Panel"],
						guiInline = true,
						get = function(info) return E.db.locplus[ info[#info] ] end,
						set = function(info, value) E.db.locplus[ info[#info] ] = value; end,
						args = {
							ht = {
								order = 1,
								name = L["Larger Location Panel"],
								desc = L["Adds 6 pixels at the Main Location Panel height."],
								type = 'toggle',
								disabled = function() return not E.db.locplus.noback end,
								set = function(info, value) E.db.locplus[ info[#info] ] = value; LP:DTHeight() end,	
							},
							frameStrata = {
								order = 2,
								type = "select",
								name = L["Frame Strata"],
								values = {
									["BACKGROUND"] = "BACKGROUND",
									["LOW"] = "LOW",
									["MEDIUM"] = "MEDIUM",
									["HIGH"] = "HIGH",
									["DIALOG"] = "DIALOG",
									["TOOLTIP"] = "TOOLTIP",
								},
								set = function(info, value) E.db.locplus[ info[#info] ] = value; LP:StrataAndLevel() end,	
							},
							frameLevel = {
								order = 3,
								type = "range",
								name = L["Frame Level"],
								min = 2, max = 128, step = 1,
								set = function(info, value) E.db.locplus[ info[#info] ] = value; LP:StrataAndLevel() end,
							},
							spacer1 = {
								order = 4,
								type = "header",
								name = "",
							},
							lpauto = {
								order = 5,
								type = "toggle",
								name = L["Auto width"],
								desc = L["Auto resized Location Panel."],
								set = function(info, value) E.db.locplus[ info[#info] ] = value; E.db.locplus.trunc = false; end,
							},	
							lpwidth = {
								order = 6,
								type = "range",
								name = L["Width"],
								desc = L["Adjust the Location Panel Width."],
								min = 100, max = 300, step = 1,
								disabled = function() return E.db.locplus.lpauto end,
							},
							trunc = {
								order = 7,
								type = "toggle",
								name = L["Truncate text"],
								desc = L["Truncates the text rather than auto enlarge the location panel when the text is bigger than the panel."],
								disabled = function() return E.db.locplus.lpauto end,
							},
							spacer2 = {
								order = 8,
								type = "header",
								name = "",
							},
							customColor = {
								order = 9,
								type = "select",
								name = COLOR,
								values = {
									[1] = L["Auto Colorize"],
									[2] = CLASS_COLORS,
									[3] = CUSTOM,
								},
							},
							userColor = {
								order = 10,
								type = "color",
								name = COLOR_PICKER,
								disabled = function() return E.db.locplus.customColor == 1 or E.db.locplus.customColor == 2 end,
								get = function(info)
									local t = E.db.locplus[ info[#info] ]
									return t.r, t.g, t.b, t.a
									end,
								set = function(info, r, g, b)
									local t = E.db.locplus[ info[#info] ]
									t.r, t.g, t.b = r, g, b
									LP:CoordsColor()
								end,
							},
						},
					},
					coords = {
						order = 3,
						type = "group",
						name = L["Coordinates"],
						guiInline = true,
						args = {
							customCoordsColor = {
								order = 1,
								type = "select",
								name = COLOR,
								values = {
									[1] = L["Use Custom Location Color"],
									[2] = CLASS_COLORS,
									[3] = CUSTOM,
								},
								get = function(info) return E.db.locplus[ info[#info] ] end,
								set = function(info, value) E.db.locplus[ info[#info] ] = value; LP:CoordsColor() end,
							},
							userCoordsColor = {
								order = 2,
								type = "color",
								name = COLOR_PICKER,
								disabled = function() return E.db.locplus.customCoordsColor == 1 or E.db.locplus.customCoordsColor == 2 end,
								get = function(info)
									local t = E.db.locplus[ info[#info] ]
									return t.r, t.g, t.b, t.a
									end,
								set = function(info, r, g, b)
									local t = E.db.locplus[ info[#info] ]
									t.r, t.g, t.b = r, g, b
									LP:CoordsColor() 
								end,
							},
							dig = {
								order = 3,
								name = L["Detailed Coords"],
								desc = L["Adds 2 digits in the coords"],
								type = 'toggle',
								get = function(info) return E.db.locplus[ info[#info] ] end,
								set = function(info, value) E.db.locplus[ info[#info] ] = value; LP:CoordsDigit() end,					
							},
						},
					},
					panels = {
						order = 4,
						type = "group",
						name = L["Size"],
						guiInline = true,
						args = {
							dtwidth = {
								order = 1,
								type = "range",
								name = L["DataTexts Width"],
								desc = L["Adjust the DataTexts Width."],
								min = 70, max = 200, step = 1,
								get = function(info) return E.db.locplus[ info[#info] ] end,
								set = function(info, value) E.db.locplus[ info[#info] ] = value; LP:DTWidth() end,
							},
							dtheight = {
								order = 2,
								type = "range",
								name = L["All Panels Height"],
								desc = L["Adjust All Panels Height."],
								min = 10, max = 32, step = 1,
								get = function(info) return E.db.locplus[ info[#info] ] end,
								set = function(info, value) E.db.locplus[ info[#info] ] = value; LP:DTHeight() end,
							},
						},
					},
					spacingGroup = {
						order = 5,
						type = "group",
						name = L["Spacing"],
						guiInline = true,
						get = function(info) return E.db.locplus[ info[#info] ] end,
						set = function(info, value) E.db.locplus[ info[#info] ] = value; LP:UpdateSpacing() end,
						args = {
							spacingAuto = {
								order = 1,
								type = "toggle",
								name = L["Auto"],
							},
							spacingManual = {
								order = 2,
								type = "range",
								name = L["Manual"],
								min = 0, max = 200, step = 1,
								disabled = function() return E.db.locplus.spacingAuto end,
							},
						},
					},
					font = {
						order = 6,
						type = "group",
						name = L["Fonts"],
						guiInline = true,
						get = function(info) return E.db.locplus[ info[#info] ] end,
						set = function(info, value) E.db.locplus[ info[#info] ] = value; LP:ChangeFont(); end,
						args = {
							useDTfont = {
								order = 1,
								name = L["Use DataTexts font"],
								type = 'toggle',
								width = 'full',
							},
							lpfont = {
								type = "select", dialogControl = 'LSM30_Font',
								order = 2,
								name = L["Font"],
								desc = L["Choose font for the Location and Coords panels."],
								values = AceGUIWidgetLSMlists.font,
								disabled = function() return E.db.locplus.useDTfont end,
							},
							lpfontsize = {
								order = 3,
								name = L["Font Size"],
								desc = L["Set the font size."],
								type = "range",
								min = 6, max = 22, step = 1,
								disabled = function() return E.db.locplus.useDTfont end,
							},
							lpfontflags = {
								order = 4,
								name = L["Font Outline"],
								type = 'select',
								values = {
									['NONE'] = L['None'],
									['OUTLINE'] = 'OUTLINE',
									['MONOCHROMEOUTLINE'] = 'MONOCROMEOUTLINE',
									['THICKOUTLINE'] = 'THICKOUTLINE',
								},
								disabled = function() return E.db.locplus.useDTfont end,
							},
						},
					},
				},
			},
		},					
	}
end
tinsert(LP.Config, Options)