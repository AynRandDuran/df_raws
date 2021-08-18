-- Pause and warn if a unit's mood timer is too low.
-- By Randy McShandy
--@ module = true
--[====[

gui/warn-mood
===============
Popup warning for a mooded dwarf that can't get things.

]====]
moodUnits = starvingUnits or {}

function clear()
	moodUnits = {}
end

local gui = require 'gui'
local utils = require 'utils'
local units = df.global.world.units.active

local args = utils.invert({...})
if args.all or args.clear then
    clear()
end

warning = defclass(warning, gui.FramedScreen)
warning.ATTRS = {
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = 'Warning',
    frame_width = 20,
    frame_height = 18,
    frame_inset = 1,
    focus_path = 'mood-timer',
}

function warning:init(args)
    self.start = 1
    self.messages = args.messages
    self.frame_height = math.min(18, #self.messages)
    self.max_start = #self.messages - self.frame_height + 1
    for _, msg in pairs(self.messages) do
        self.frame_width = math.max(self.frame_width, #msg + 2)
    end
    self.frame_width = math.min(df.global.gps.dimx - 2, self.frame_width)
end

function warning:onRenderBody(p)
    for i = self.start, math.min(self.start + self.frame_height - 1, #self.messages) do
        p:string(self.messages[i]):newline()
    end
    if #self.messages > self.frame_height then
        if self.start > 1 then
            p:seek(self.frame_width - 1, 0):string(string.char(24), COLOR_LIGHTCYAN) -- up
        end
        if self.start < self.max_start then
            p:seek(self.frame_width - 1, self.frame_height - 1):string(string.char(25), COLOR_LIGHTCYAN) -- down
        end
    end
end

function warning:onInput(keys)
    if keys.LEAVESCREEN or keys.SELECT then
        self:dismiss()
    elseif keys.CURSOR_UP or keys.STANDARDSCROLL_UP then
        self.start = math.max(1, self.start - 1)
    elseif keys.CURSOR_DOWN or keys.STANDARDSCROLL_DOWN then
        self.start = math.min(self.start + 1, self.max_start)
    end
end

local function findRaceCaste(unit)
    local rraw = df.creature_raw.find(unit.race)
    return rraw, safe_index(rraw, 'caste', unit.caste)
end

local function getSexString(sex)
  local sym = df.pronoun_type.attrs[sex].symbol
  if not sym then
    return ""
  end
  return "("..sym..")"
end

local function nameOrSpeciesAndNumber(unit)
    if unit.name.has_name then
        return dfhack.TranslateName(dfhack.units.getVisibleName(unit))..' '..getSexString(unit.sex),true
    else
        return 'Unit #'..unit.id..' ('..df.creature_raw.find(unit.race).caste[unit.caste].caste_name[0]..' '..getSexString(unit.sex)..')',false
    end
end

local function checkVariable(var, limit, description, map, unit)
    local rraw = findRaceCaste(unit)
    local species = rraw.name[0]
    local profname = dfhack.units.getProfessionName(unit)
    if #profname == 0 then profname = nil end
    local name = nameOrSpeciesAndNumber(unit)
    if var < limit and var > 1 then
        if not map[unit.id] then
            map[unit.id] = true
            return name .. ", " .. (profname or species) .. " is " .. description .. "!"
        end
    else
        map[unit.id] = false
    end
    return nil
end

function doCheck()
    local messages = {} --as:string[]
    for i=#units-1, 0, -1 do
        local unit = units[i]
        local rraw = findRaceCaste(unit)
        if rraw and dfhack.units.isActive(unit) and not dfhack.units.isOpposedToLife(unit) then
            table.insert(messages, checkVariable(unit.job.mood_timeout, 3000, 'demanding items', moodUnits, unit))
        end
    end
    if #messages > 0 then
        dfhack.color(COLOR_LIGHTMAGENTA)
        for _, msg in pairs(messages) do
            print(dfhack.df2console(msg))
        end
        dfhack.color()
        df.global.pause_state = true
        warning{messages=messages}:show()
    end
end

if not moduleMode then doCheck() end