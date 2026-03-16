--managing windows

local M = {} --module

M.window = { buf = nil, win = nil, width = 24, height = 6 } --table for the floating window data

--creating window with given text (table of lines)
function M.create_window(text)
	local buf = vim.api.nvim_create_buf(false, true) --buffer
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, text) --set initial window text

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

	M.window.buf = buf --put objects into table
	M.window.win = win
end

--close window
function M.close_window()
	if M.window.win and vim.api.nvim_win_is_valid(M.window.win) then --if window exists
		vim.api.nvim_win_close(M.window.win, true) --close window
		M.window.win = nil --reset win var
	end
	if M.window.buf and vim.api.nvim_buf_is_valid(M.window.buf) then --if buffer exists
		vim.api.nvim_buf_delete(M.window.buf, { force = true }) --delete buffer
		M.window.buf = nil --reset buf var
	end
end

return M
