--plugin for tracking cool coding stats in projects

--[[
plan:

next need to start working on getting/tracking some stats

TODO:
figure out saving and loading tracked data
per project tracking 

TODO:
command to reset current project data
NeoStats reset
  should just delete data[project]

TODO:
separate out functions into separate files

TODO:
make window values more variable

TODO:
opts implementation in setup to configure stuff

TODO:
make the larger window where all stats will be tracked 
  NeoStats command to open it 


TODO:
revisit fstat and center functions
ideally want to have everything lined up to be 1 column in from each side 
and span the whole distance between


for working out individual chars,
  in the insert mode character input autocmd, add each char to a list 
  then either on insert mode exist or on a timer
    create a copy of that list and clear the original
    go through copy list and for each char add 1 to the count for that char
    then delete copy
          copy is made so that chars can still be added whilst counting is happening


]]

local save = require("neostats.save") --get save functions

local NS = {}

NS.window = { buf = nil, win = nil, width = 24, height = 6 } --table for the floating window data

NS.default_stats = { --default stats used when no project stats are found
	xp = { --xp stuff
		total = 0, --total xp
		target = 100, --target xp for next level
		level_xp = 0, --xp for the current level (internal, used for xpbar)
		level_size = 100, --how much xp is needed for current level (tar-total on levelup, used for xpbar)
		level = 0, --current level
		inc = 2.05, --how much to multiply by for the next target
	},
	stats = { --tracked stats
		total_chars = 0,
	},
}

NS.data = { --track stats per project
	--[cwd] = {
	--xp = {}
	--stats = {}
	--}
}

--take in given text and width, return string with the text in the center of the width
function NS.center(text, width)
	local padding = math.floor((width - #text) / 2)
	return string.rep(" ", padding) .. text
end

--format the given label and stat value into a line for the window
function NS.fstat(label, value) --value is formatted into a string, so can be int or string on input
	return string.format("%-15s %s", label .. ":", value)
end

--calculate xp level ups and stuff
function NS.xp_calc()
	local project = save.get_project_stats(NS.data, NS.default_stats) --get current project data
	if project.xp.total >= project.xp.target then --if at target for current level
		local temp = project.xp.target --store reached target temporarily
		project.xp.target = math.floor(project.xp.target * project.xp.inc) --go to next target threshold
		project.xp.level_size = project.xp.target - temp --update size of level
		project.xp.level_xp = 0 + (project.xp.total - temp) --reset levelxp, accounting for the total going over the target before this update
		project.xp.level = project.xp.level + 1 --iterate level
	end
end
--build the bar for the xp bar
function NS.get_xpbar()
	local project = save.get_project_stats(NS.data, NS.default_stats) --get current project data
	local percent = (project.xp.level_xp / project.xp.level_size) * 100 --percentage of progress through level
	local progress = math.floor(percent / 5) --divide by 5 and cut off decimal to get number of #s to fill in bar
	return "[" .. string.rep("#", progress) .. string.rep("-", 20 - progress) .. "]" --put the bar together and return
end

--generate the text for the window
function NS.get_text()
	local project = save.get_project_stats(NS.data, NS.default_stats) --get current project data
	local lines = { --table of each line of text for the window
		NS.center("Neostats", NS.window.width), --title
		"", --empty line
		NS.center(NS.fstat("xp", project.xp.total .. "/" .. project.xp.target), NS.window.width), --xp
		NS.center(NS.get_xpbar(), NS.window.width), --xpbar
		NS.center(NS.fstat("level", project.xp.level), NS.window.width), --level
	}
	--[[ unused for now, saving incase needed later
	if #order > 0 then --if there is anything in the order table to put into the window
		for _, key in ipairs(order) do --for each stat in stats (using the order table to be in order)
			local name = key:gsub("_", " ") --replace the underscore with a space in the name
			table.insert(lines, NS.fstat(name, stats[key])) --insert formatted stat into the lines table
		end
	end
  ]]
	return lines
end

--update stats and other numbery stuff
function NS.update()
	NS.xp_calc() --update stats and stuff
	vim.api.nvim_buf_set_lines(NS.window.buf, 0, -1, false, NS.get_text()) --set updated window text
end

--timer for updating
function NS.start_timer()
	if NS._timer then --if timer exists already then stop it
		NS._timer:stop()
	end

	NS._timer = vim.loop.new_timer() --create new timer

	NS._timer:start(
		0, --start on startup
		1000, --repeat 1000ms (1second)
		vim.schedule_wrap(function()
			NS.update() --update everything that needs updating
		end)
	)
end

--creating window
function NS.create_window()
	local buf = vim.api.nvim_create_buf(false, true) --buffer
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, NS.get_text()) --set initial window text

	local win = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		anchor = "NW", --NW so that top left of window is placed at row,col
		width = NS.window.width,
		height = NS.window.height,
		row = (vim.o.lines - 4) - NS.window.height, --put window on bottom row + X for command line and lualine (and border if applicable)
		col = vim.o.columns - NS.window.width, --all the way to the right column, accounting for window width
		style = "minimal",
		border = "single",
	})

	NS.window.buf = buf --put objects into table
	NS.window.win = win
end

--close window
function NS.close_window()
	if NS.window.win and vim.api.nvim_win_is_valid(NS.window.win) then --if window exists
		vim.api.nvim_win_close(NS.window.win, true) --close window
		NS.window.win = nil --reset win var
	end
	if NS.window.buf and vim.api.nvim_buf_is_valid(NS.window.buf) then --if buffer exists
		vim.api.nvim_buf_delete(NS.window.buf, { force = true }) --delete buffer
		NS.window.buf = nil --reset buf var
	end
end

--exiting cleanly
function NS.exit()
	NS.close_window() --close window
	if NS._timer then --if timer exists
		NS._timer:stop() --stop update timer
	end
	NS.xp_calc() --do any last xp calculations
	save.save_data(NS.data) --save the current data
end

--setup stuff
function NS.setup()
	--keymap for toggling the window
	vim.keymap.set("n", "<leader>ns", function()
		if NS.window.win or NS.window.buf then --if window exists
			NS.exit() --clean exit
		else --else open window
			NS.data = save.load_data() --load the save data
			NS.create_window()
			NS.start_timer() --start update timer
		end
	end, { desc = "Toggle NeoStats Window", silent = true, nowait = true, noremap = true })

	--define group for autocommands
	local augroup = vim.api.nvim_create_augroup("NeoStatsAuto", { clear = true })

	--for each char input in insert mode
	vim.api.nvim_create_autocmd("InsertCharPre", {
		group = augroup,
		pattern = "*",
		callback = function()
			print(NS.data, NS.default_stats)
			local project = save.get_project_stats(NS.data, NS.default_stats) --get current project data
			project.stats.total_chars = project.stats.total_chars + 1 --iterate total char count
			project.xp.total = project.xp.total + 1 --add xp to total
			project.xp.level_xp = project.xp.level_xp + 1 --add xp to current level
		end,
	})

	--on leaving nvim, save data
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = augroup,
		callback = function()
			NS.exit() --clean exit
		end,
	})

	--if there are no stats for the cwd, sets the defaults for it
	save.get_project_stats(NS.data, NS.default_stats)
end

--temporary test function for when needed
function NS.test()
	print("neostats is connected")
end

return NS

--[[ text testing area

sdkhfkjsldjhfglsdkjfsdlkfjlklkjsd
dfsghfadgihjksdvbadfgjhdasngvjksdfbdsjfvdfsjkgdfgjbdgjkdfgdskjfgndfkgjndfgkjdfngdfskjgnksdfjngkdsjfgn
ksdjfhdskjfnsdkjfnsdkjfnsdkjfhsdkjfhskdjnfkjsdnfjksdnfjknsdkfjndsjkfnsdkjnfksjdnfkjsdnfkjsdnfkjsdnfkjsdnsdkjfnksdjfnsdjkfnsdkjfnsd#
sdkjfnsdkfjnsdfkjsdnfsdkjfnbsdfjdsnf
sdkfjnsdfkjsdnfkjndfgkjnsdfkjgnkjnsdfgkjnojndfgkjkjndfgkjnkljndfgkjnkjndfgkjnljndfgkjnkljdfgkljnkjnfgkjnlkjldfglknjkdfnglkmn
osidjflksdnfsdlkn

sikdujhfgsdkjfhsdfkjdh
ksadjnfsdkjfndkjfsn
lsdkjf
skdjfhnksdjnfkjsdnfkjsadnfkjdsnfkjsdnfkjsdkfjnkjnsdakjnfsn
ksjldnfkjsdnfsdkjndjfnsdlfknsdflkndsfknsdflknsdlfknsdlknknlkdnfsdlkfndsflk
kjsbnfdkjnfkjndfkgjndfkgjndfgkjndfgkjndfgkjndfgkjndfkgjndfkgjndfkgjndfgkjndfgkjdfngdfkjgndfgkjndf
jkndfgjnfdg kujhsdfkjhsdfkjdsfkjhsdfkjhsdfkjsdh
iksjhfksjdanfsdkjn
]]
