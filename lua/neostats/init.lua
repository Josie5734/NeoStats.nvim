--plugin for tracking cool coding stats in projects

--[[
plan:

made window and text formatting

next need to start working on getting/tracking some stats
and a timer to update the text with those stats

TODO:
revisit fstat and center functions
ideally want to have everything lined up to be 1 column in from each side 
and span the whole distance between

TODO:
implement timer for updating window at set times 
create update function:
  calls the xp_calc, then bar builder, then text replacement 
remove temporary update on leaving insert mode autocmd


for working out individual chars,
  in the insert mode character input autocmd, add each char to a list 
  then either on insert mode exist or on a timer
    create a copy of that list and clear the original
    go through copy list and for each char add 1 to the count for that char
    then delete copy
          copy is made so that chars can still be added whilst counting is happening


idea for later:
have just the xp bar in the little corner window by default
then have a big window that can be opened from cmdline
big window shows all of the stats
and also has tickboxes for each stat to put it in the little menu





--update the text in the window (taken from wpm, needs reimplementing here)
function M.update_window()
	if not M.wpm_buf or not vim.api.nvim_buf_is_valid(M.wpm_buf) then
		print("invalid buf")
		return
	end
	local wpm_num = M.get_wpm()
	M.get_total()
	vim.api.nvim_buf_set_lines(M.wpm_buf, 0, -1, false, { "WPM: " .. wpm_num .. " Total: " .. total })
end





onupdate:
  if levelxp >= leveltarget:
    levelxp = 0
    level + 1 
    leveltarget = recalculate
    levelsize = leveltarget - totalxp

ontextcalc:
  xp:  totalxp/leveltarget 
  [##--] = levelxp as percent of levelsize cut to nearest 5 
--]]

local M = {}

local window = { buf = nil, win = nil, width = 24, height = 6 } --table for the floating window data
local xp = { --xp stuff
	total = 0, --total xp
	target = 100, --target xp for next level
	level_xp = 0, --xp for the current level (internal, used for xpbar)
	level_size = 100, --how much xp is needed for current level (tar-total on levelup, used for xpbar)
	level = 0, --current level
	inc = 2.05, --how much to multiply by for the next target
}
local stats = { --tracked stats
	total_chars = 0,
	other_stat = 20,
}
local order = { --the order that the stats are shown in the window
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

--calculate xp level ups and stuff
function M.xp_calc()
	if xp.total >= xp.target then --if at target for current level
		local temp = xp.target --store reached target temporarily
		xp.target = math.floor(xp.target * xp.inc) --go to next target threshold
		xp.level_size = xp.target - temp --update size of level
		xp.level_xp = 0 + (xp.total - temp) --reset levelxp, accounting for the total going over the target before this update
		xp.level = xp.level + 1 --iterate level
	end
end
--build the bar for the xp bar
function M.get_xpbar()
	local percent = (xp.level_xp / xp.level_size) * 100 --percentage of progress through level
	local progress = math.floor(percent / 5) --divide by 5 and cut off decimal to get number of #s to fill in bar
	return "[" .. string.rep("#", progress) .. string.rep("-", 20 - progress) .. "]" --put the bar together and return
end

--generate the text for the window
function M.get_text()
	local lines = { --table of each line of text for the window
		M.center("Neostats", window.width), --title
		"", --empty line
		M.center(M.fstat("xp", xp.total .. "/" .. xp.target), window.width), --xp
		M.center(M.get_xpbar(), window.width), --xpbar
		M.center(M.fstat("level", xp.level), window.width), --level
	}
	if #order > 0 then --if there is anything in the order table to put into the window
		for _, key in ipairs(order) do --for each stat in stats (using the order table to be in order)
			local name = key:gsub("_", " ") --replace the underscore with a space in the name
			table.insert(lines, M.fstat(name, stats[key])) --insert formatted stat into the lines table
		end
	end
	return lines
end

--update stats and other numbery stuff
function M.update()
	M.xp_calc() --update xp bar ad stats and stuff
	vim.api.nvim_buf_set_lines(window.buf, 0, -1, false, M.get_text()) --set updated window text
end

--timer for updating
function M.start_timer()
	if M._timer then --if timer exists already then stop it
		M._timer:stop()
	end

	M._timer = vim.loop.new_timer() --create new timer

	M._timer:start(
		0, --start on startup
		1000, --repeat 1000ms (1second)
		vim.schedule_wrap(function()
			M.update() --update everything that needs updating
		end)
	)
end

--creating window
function M.create_window()
	local buf = vim.api.nvim_create_buf(false, true) --buffer
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, M.get_text()) --set initial window text

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
			M._timer:stop() --stop update timer
		else --else open window
			M.create_window()
			M.start_timer() --start update timer
		end
	end, { desc = "Toggle NeoStats Window", silent = true, nowait = true, noremap = true })

	--define group for autocommands
	local augroup = vim.api.nvim_create_augroup("NeoStatsAuto", { clear = true })

	--for each char input in insert mode
	vim.api.nvim_create_autocmd("InsertCharPre", {
		group = augroup,
		pattern = "*",
		callback = function()
			stats.total_chars = stats.total_chars + 1 --iterate total char count
			xp.total = xp.total + 1 --add xp to total
			xp.level_xp = xp.level_xp + 1 --add xp to current level
		end,
	})
end

--temporary test function for when needed
function M.test()
	print("neostats is connected")
end

return M

--[[ text testing area

]]
