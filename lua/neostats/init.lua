--plugin for tracking cool coding stats in projects

--[[
plan:

made window and text formatting

next need to start working on getting/tracking some stats
and a timer to update the text with those stats


idea for later:
have just the xp bar in the little corner window by default
then have a big window that can be opened from cmdline
big window shows all of the stats
and also has tickboxes for each stat to put it in the little menu
--]]

local M = {}

local window = { buf = nil, win = nil, width = 24, height = 20 } --table for the floating window data
local xpbar = { --xpbar stuff
	cur = 87, --current xp
	tar = 100, --target for next level
	inc = 1.3, --how much to multiply by for the next target
}
local stats = { --tracked stats
	total_chars = 5000000,
	other_stat = 20,
}
local order = { --the order that the stats are shown in the window
	"total_chars",
	"other_stat",
}

--take in given text and width, return string with the text in the center of the width
function M.center(text, width)
	local padding = math.floor((width - #text) / 2)
	return string.rep(" ", padding) .. text
end

--format the given label and stat value into a line for the window
function M.fstat(label, value) --value is formatted into a string, so can be int or string on input
	return string.format("%-15s %s", label .. ":", value)
end

--build the bar for the xp bar
function M.xpbar_calc()
	local percent = (xpbar.cur / xpbar.tar) * 100 --percentage of progress through level
	local progress = math.floor(percent / 5) --divide by 5 and cut off decimal to get number of #s to fill in bar
	return "[" .. string.rep("#", progress) .. string.rep("-", 20 - progress) .. "]" --put the bar together and return
end

--text for the window. in a function so it can be updated easily
function M.get_text()
	local lines = { --table of each line of text for the window
		M.center("Neostats", window.width), --title
		"", --empty line
		M.center(M.fstat("xp", xpbar.cur .. "/" .. xpbar.tar), window.width),
		M.center(M.xpbar_calc(), window.width),
		"",
	}
	for _, key in ipairs(order) do --for each stat in stats (using the order table to be in order)
		local name = key:gsub("_", " ") --replace the underscore with a space in the name
		table.insert(lines, M.fstat(name, stats[key])) --insert formatted stat into the lines table
	end
	return lines
end

--creating window
function M.create_window()
	local buf = vim.api.nvim_create_buf(false, true) --buffer
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, M.get_text()) --text

	local win = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		anchor = "NW", --NW so that top left of window is placed at row,col
		width = window.width,
		height = window.height,
		row = (vim.o.lines - 4) - window.height, --put window on bottom row + X for command line and lualine (and border if applicable)
		col = vim.o.columns - window.width, --all the way to the right column, accounting for window width
		style = "minimal",
		border = "single",
	})

	window.buf = buf --put objects into table
	window.win = win
end

--close window
function M.close_window()
	if window.win and vim.api.nvim_win_is_valid(window.win) then --if window exists
		vim.api.nvim_win_close(window.win, true) --close window
		window.win = nil --reset win var
	end
	if window.buf and vim.api.nvim_buf_is_valid(window.buf) then --if buffer exists
		vim.api.nvim_buf_delete(window.buf, { force = true }) --delete buffer
		window.buf = nil --reset buf var
	end
end

--setup stuff
function M.setup()
	--keymap for toggling the window
	vim.keymap.set("n", "<leader>ns", function()
		if window.win or window.buf then --if window exists
			M.close_window() --close window
		else --else open window
			M.create_window()
		end
	end, { desc = "Toggle NeoStats Window", silent = true, nowait = true, noremap = true })
end

--temporary test function for when needed
function M.test()
	print("neostats is connected")
end

return M
