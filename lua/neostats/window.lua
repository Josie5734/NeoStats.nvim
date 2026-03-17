--managing windows

local M = {} --module

local order = { --the order to display the stats in the main window
	"total_chars",
	"total_time",
}

M.window = { --table for both windows
	main = {
		buf = nil,
		win = nil,
		width = function() --calculate width on window.width()
			return math.floor(vim.o.columns * 0.8)
		end,
		height = function() --same for height
			return math.floor(vim.o.lines * 0.8)
		end,
		padding = 1,
	}, --main window
	mini = { buf = nil, win = nil, width = 24, height = 5, padding = 1 }, --mini window
}

--creating window with generated text (table of lines)
function M.mini_window_open(xp)
	local buf = vim.api.nvim_create_buf(false, true) --buffer
	vim.api.nvim_buf_set_lines(
		buf,
		0,
		-1,
		false,
		M.mini_window_gen_text(xp, M.window.mini.width, M.window.mini.padding)
	) --set initial window text

	local win = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		anchor = "NW", --NW so that top left of window is placed at row,col
		width = M.window.mini.width,
		height = M.window.mini.height,
		row = (vim.o.lines - 4) - M.window.mini.height, --put window on bottom row + X for command line and lualine (and border if applicable)
		col = vim.o.columns - M.window.mini.width, --all the way to the right column, accounting for window width
		style = "minimal",
		border = "rounded",
		title = " NeoStats ", --title and footer, centered
		title_pos = "center",
		footer = " NeoStats ",
		footer_pos = "center",
		focusable = false, --cant click into the window
	})

	M.window.mini.buf = buf --store references to buffer and window
	M.window.mini.win = win
end

--update the mini window
function M.mini_window_update(xp)
	vim.api.nvim_buf_set_lines(
		M.window.mini.buf,
		0,
		-1,
		false,
		M.mini_window_gen_text(xp, M.window.mini.width, M.window.mini.padding)
	) --set updated window text
end

--close window
function M.mini_window_close()
	if M.window.mini.win and vim.api.nvim_win_is_valid(M.window.mini.win) then --if window.mini exists
		vim.api.nvim_win_close(M.window.mini.win, true) --close window.mini
		M.window.mini.win = nil --reset win var
	end
	if M.window.mini.buf and vim.api.nvim_buf_is_valid(M.window.mini.buf) then --if buffer exists
		vim.api.nvim_buf_delete(M.window.mini.buf, { force = true }) --delete buffer
		M.window.mini.buf = nil --reset buf var
	end
end

--check if mini window exists
function M.mini_window_exists()
	if M.window.mini.win and M.window.mini.buf then --if exists
		if vim.api.nvim_win_is_valid(M.window.mini.win) and vim.api.nvim_buf_is_valid(M.window.mini.buf) then
			return true --send true if valid
		end
	else
		return false --else send false
	end
end

--create main window (takes in stats table for displaying)
function M.main_window_open(stats)
	local width = M.window.main.width() --calculate width and height
	local height = M.window.main.height()

	local buf = vim.api.nvim_create_buf(false, true) --buffer
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, M.main_window_gen_text(stats, width)) --set initial window text

	local win = vim.api.nvim_open_win(buf, true, { --open win and get focus
		relative = "editor",
		anchor = "NW", --NW so that top left of window is placed at row,col
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
		title = " NeoStats ", --title and footer, centered
		title_pos = "center",
		footer = " NeoStats ",
		footer_pos = "center",
	})

	M.window.main.buf = buf --store references to buffer and window
	M.window.main.win = win

	vim.bo[M.window.main.buf].modifiable = false --make not modifiable
	vim.bo[M.window.main.buf].readonly = false --but still interactable

	--keymap for closing window with q
	vim.keymap.set("n", "q", function()
		M.main_window_close()
	end, { buffer = M.window.main.buf, nowait = true })
end

--close main window
function M.main_window_close()
	if M.main_window_exists() then --if window exists
		vim.api.nvim_win_close(M.window.main.win, true) --close window
		vim.api.nvim_buf_delete(M.window.main.buf, { force = true }) --delete buffer
		M.window.main.win = nil --delete references
		M.window.main.buf = nil
	end
end

--check if main window exists
function M.main_window_exists()
	if M.window.main.win and M.window.main.buf then --if exists
		if vim.api.nvim_win_is_valid(M.window.main.win) and vim.api.nvim_buf_is_valid(M.window.main.buf) then
			return true --return true if valid
		end
	else
		return false
	end
end

--generate text for main window
function M.main_window_gen_text(stats, width)
	local lines = {
		M.center("Your super cool NeoVim stats", width),
		"", --blank line
	}
	for _, stat in ipairs(order) do --in order given in order table
		local value = stats[stat] --get the value
		if stat == "total_time" then --if time
			value = M.time_format(value) --put into hh:mm:ss format
		end
		table.insert(lines, M.center(M.main_format_stat(stat, value, math.floor(width / 3)), width)) --format and insert into lines
	end
	return lines
end

--formatting for the main window
function M.main_format_stat(stat, value, width)
	local str = string.format("%-" .. width .. "s%s", stat .. ":", value) --get the formatted string
	--works by taking a width for the whole string and putting stat and value on opposite ends of it
	return str:gsub(" ", ".") --then return the string with the spaces replaced with dots
end
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

--format time from seconds to hh:mm:ss
function M.time_format(seconds)
	local hours = math.floor(seconds / 3600) --get hours
	local minutes = math.floor((seconds % 3600) / 60) --get minutes
	local secs = seconds % 60 --get remaining seconds

	return string.format("%02d:%02d:%02d", hours, minutes, secs) --return formatted
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
		"", --empty line
		M.mini_format_stat("xp", xp.total .. "/" .. xp.target, width, padding), --xp
		M.center(M.gen_xpbar(xp), width), --xp bar
		M.mini_format_stat("level", xp.level, width, padding), --level
	}
	return lines
end

return M
