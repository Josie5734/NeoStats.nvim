--managing windows

local M = {} --module

M.window = { buf = nil, win = nil, width = 24, height = 6, padding = 1 } --table for the floating window data

--creating window with given text (table of lines)
function M.mini_window_open(xp)
	local buf = vim.api.nvim_create_buf(false, true) --buffer
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, M.mini_window_gen_text(xp, M.window.width, M.window.padding)) --set initial window text

	local win = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		anchor = "NW", --NW so that top left of window is placed at row,col
		width = M.window.width,
		height = M.window.height,
		row = (vim.o.lines - 4) - M.window.height, --put window on bottom row + X for command line and lualine (and border if applicable)
		col = vim.o.columns - M.window.width, --all the way to the right column, accounting for window width
		style = "minimal",
		border = "single",
		focusable = false, --cant click into the window
	})

	M.window.buf = buf --store references to buffer and window
	M.window.win = win
end

--update the mini window
function M.mini_window_update(xp)
	vim.api.nvim_buf_set_lines(M.window.buf, 0, -1, false, M.mini_window_gen_text(xp, M.window.width, M.window.padding)) --set updated window text
end

--close window
function M.mini_window_close()
	if M.window.win and vim.api.nvim_win_is_valid(M.window.win) then --if window exists
		vim.api.nvim_win_close(M.window.win, true) --close window
		M.window.win = nil --reset win var
	end
	if M.window.buf and vim.api.nvim_buf_is_valid(M.window.buf) then --if buffer exists
		vim.api.nvim_buf_delete(M.window.buf, { force = true }) --delete buffer
		M.window.buf = nil --reset buf var
	end
end
--
--take in given text and width, return string with the text in the center of the width
function M.center(text, width)
	local padding = math.floor((width - #text) / 2)
	return string.rep(" ", padding) .. text
end

--format stats for the mini window
--stat for label, value for number.
--width for width of window and padding for how much padding from the side
function M.mini_format_stat(stat, value, width, padding)
	return string.format(
		string.rep(" ", padding) .. "%-" .. ((width - (padding * 2)) - #tostring(value)) .. "s%s",
		stat .. ":",
		value
	)
	--create spaces * padding for left of string padding
	--then do "stat:" formatted with space after
	--then "value"
	--space in middle is calculated by
	--width - padding*2 to get width with padding from both sides
	--then width - #value to account for value being put on the end
end

--generate the xp bar
function M.gen_xpbar(xp)
	local percent = (xp.level_xp / xp.level_size) * 100 --percentage of progress through level
	local progress = math.floor(percent / 5) --divide by 5 and cut off decimal to get number of #s to fill in bar
	return "[" .. string.rep("#", progress) .. string.rep("-", 20 - progress) .. "]" --put the bar together and return
end

--generate text for the mini window. takes an xpstats table and a window width
function M.mini_window_gen_text(xp, width, padding)
	local lines = {
		M.center("NeoStats", width), --title bar
		"", --empty line
		M.mini_format_stat("xp", xp.total .. "/" .. xp.target, width, padding), --xp
		M.center(M.gen_xpbar(xp), width), --xp bar
		M.mini_format_stat("level", xp.level, width, padding), --level
	}
	return lines
end

--plan for formatting mini window text
--all text should be exactly 1 column in from each side
--so column 1 = border, column 2 = space, column 3 = text

return M
