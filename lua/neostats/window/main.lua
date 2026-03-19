--code for the main window of NeoStats

local utils = require("neostats.window.utils") --import util functions
local data = require("neostats.data") --get data for project

local M = {}

M.window = { --table for window opts
	buf = nil,
	win = nil,
	width = function() --calculate width on window.width()
		return math.floor(vim.o.columns * 0.5)
	end,
	height = function() --same for height
		return math.floor(vim.o.lines * 0.8)
	end,
}

--create main window (takes in stats table for displaying)
function M.open()
	local width = M.window.width() --calculate width and height
	local height = M.window.height()

	local buf = vim.api.nvim_create_buf(false, true) --buffer
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, M.gen_text(width)) --set initial window text

	local win = vim.api.nvim_open_win(buf, true, { --open win and get focus
		relative = "editor",
		anchor = "NW", --NW so that top left of window is placed at row,col
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2) - vim.o.cmdheight, --account for cmdline
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
		title = " NeoStats ", --title and footer, centered
		title_pos = "center",
		footer = " NeoStats ",
		footer_pos = "center",
	})

	M.window.buf = buf --store references to buffer and window
	M.window.win = win

	vim.bo[M.window.buf].modifiable = false --make not modifiable
	vim.bo[M.window.buf].readonly = false --but still interactable

	--keymap for closing window with q
	vim.keymap.set("n", "q", function()
		M.close()
	end, { buffer = M.window.buf, nowait = true })
end

--close main window
function M.close()
	if M.exists() then --if window exists
		vim.api.nvim_win_close(M.window.win, true) --close window
		vim.api.nvim_buf_delete(M.window.buf, { force = true }) --delete buffer
		M.window.win = nil --delete references
		M.window.buf = nil
	end
end

--check if main window exists
function M.exists()
	if M.window.win and M.window.buf then --if exists
		if vim.api.nvim_win_is_valid(M.window.win) and vim.api.nvim_buf_is_valid(M.window.buf) then
			return true --return true if valid
		end
	else
		return false
	end
end

--generate text for main window. width is the width of the text
function M.gen_text(width)
	local lines = {
		utils.center("Your super cool NeoVim stats", width),
		"", --blank line
	}
	for _, stat in ipairs(data.order) do --in order given in order table
		local value = data.project.stats[stat] --get the value
		if stat == "total_time" then --if time
			value = utils.time_format(value) --put into hh:mm:ss format
		end
		table.insert(lines, utils.center(M.format_stat(stat, value, math.floor(width / 1.5)), width)) --format and insert into lines
	end
	return lines
end

--formatting for the main window
----width = total width of the text from stat to value
function M.format_stat(stat, value, width)
	local str = string.format("%-" .. (width - #tostring(value)) .. "s%s", stat .. ":", value) --get the formatted string
	--works by taking a width for the whole string and putting stat and value on opposite ends of it
	return str:gsub(" ", ".") --then return the string with the spaces replaced with dots
end

return M
