--general window functions and/or functions used by both windows

local M = {}

--format time from seconds to hh:mm:ss
function M.time_format(seconds)
	local hours = math.floor(seconds / 3600) --get hours
	local minutes = math.floor((seconds % 3600) / 60) --get minutes
	local secs = seconds % 60 --get remaining seconds

	return string.format("%02d:%02d:%02d", hours, minutes, secs) --return formatted
end

--take in given text and width, return string with the text in the center of the width
function M.center(text, width)
	local padding = math.floor((width - #text) / 2)
	return string.rep(" ", padding) .. text .. string.rep(" ", padding)
end

--generate the xp bar
function M.gen_xpbar(xp)
	local percent = (xp.level_xp / xp.level_size) * 100 --percentage of progress through level
	local progress = math.floor(percent / 5) --divide by 5 and cut off decimal to get number of #s to fill in bar
	return "[" .. string.rep("#", progress) .. string.rep("-", 20 - progress) .. "]" --put the bar together and return
end

return M
