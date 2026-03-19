--mini window of NeoStats

local utils = require("neostats.window.utils") --import util functions
local data = require("neostats.data") --get data tables

local M = {}

M.window = { --window opts
	buf = nil,
	win = nil,
	width = 24, --width and height hardcoded for now, maybe change later, probably not
	height = 5,
	padding = 1,
}

--creating window with generated text (table of lines)
function M.open()
	local buf = vim.api.nvim_create_buf(false, true) --buffer
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, M.gen_text(M.window.width, M.window.padding)) --set initial window text

	local win = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		anchor = "NW", --NW so that top left of window is placed at row,col
		width = M.window.width,
		height = M.window.height,
		row = (vim.o.lines - 4) - M.window.height, --put window on bottom row + X for command line and lualine (and border if applicable)
		col = vim.o.columns - M.window.width, --all the way to the right column, accounting for window width
		style = "minimal",
		border = "rounded",
		title = " NeoStats ", --title and footer, centered
		title_pos = "center",
		footer = " NeoStats ",
		footer_pos = "center",
		focusable = false, --cant click into the window
	})

	M.window.buf = buf --store references to buffer and window
	M.window.win = win
end

--update window
function M.update()
	vim.api.nvim_buf_set_lines(M.window.buf, 0, -1, false, M.gen_text(M.window.width, M.window.padding)) --set updated window text
end

--close window
function M.close()
	if M.window.win and vim.api.nvim_win_is_valid(M.window.win) then --if window.mini exists
		vim.api.nvim_win_close(M.window.win, true) --close window.mini
		M.window.win = nil --reset win var
	end
	if M.window.buf and vim.api.nvim_buf_is_valid(M.window.buf) then --if buffer exists
		vim.api.nvim_buf_delete(M.window.buf, { force = true }) --delete buffer
		M.window.buf = nil --reset buf var
	end
end

--check if window exists
function M.exists()
	if M.window.win and M.window.buf then --if exists
		if vim.api.nvim_win_is_valid(M.window.win) and vim.api.nvim_buf_is_valid(M.window.buf) then
			return true --send true if valid
		end
	else
		return false --else send false
	end
end

--format stats for the mini window
--stat for label, value for number.
--width for width of window and padding for how much padding from the side
function M.format_stat(stat, value, width, padding)
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

--generate text for the mini window. takes an xpstats table and a window width
function M.gen_text(width, padding)
	local lines = {
		"", --empty line
		M.format_stat("xp", data.project.xp.total .. "/" .. data.project.xp.target, width, padding), --xp
		utils.center(utils.gen_xpbar(data.project.xp), width), --xp bar
		M.format_stat("level", data.project.xp.level, width, padding), --level
	}
	return lines
end

return M
