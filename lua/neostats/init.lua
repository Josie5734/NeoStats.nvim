--plugin for tracking cool coding stats in projects

--[[
plan:

TODO:
look into tracking properly when two separate instances of nvim open 

TODO:
move some of the functions in init.lua into their own files
e.g all the stat functions into a stat file

TODO:
redo format for all_chars_typed table so that it can display every character
in the table
make it do multiple columns
needs some way to decide how many rows to have, and the how to space the rows on the lines

TODO:
add to opts table
-paste override (when paste tracking added)

TODO:
plans for stats to add tracking for:
.
-track pasted and yanked characters
  -yanks - track with "TextYankPost" autocmd
    -can get the text somehow will have to double check docs
  -pastes - will have to override the "p" and "P" commands to count the register characters
    -ideally will have setup opts first to make this disableable incase of any custom mappings
-look into tracking normal mode commands and keyinputs
-wpm tracker:
  -average wpm, highest wpm
  -optionally add current wpm tracker into little window

TODO:
cool extras:
  scrabble mode - makes each letter give its worth in scrabble points as xp (might actually be good as the default)
  xp multipliers - not sure how these would be gotten, maybe wpm or something
]]

local save = require("neostats.save") --get save functions
local window = { --get window functions as window.main.function() and window.mini.function()
	main = require("neostats.window.main"),
	mini = require("neostats.window.mini"),
}
local data = require("neostats.data") --get data tables

local NS = {}

NS.current_project = nil --path of currently open project

NS.config = { --default opts
	markers = { --things to use as project markers
		".git",
		"package.json",
		"pyproject.toml",
		"Cargo.toml",
		"go.mod",
		"Makefile",
		"stylua.toml",
		".nvim.lua",
	},
	autosave_interval = 30,
}

local total_time_update = 0 --time since the last update to total_time
local autosave = 30 --countdown to autosave
--decreased each update() until 0

--calculate xp level ups and stuff
function NS.xp_calc()
	if data.project.xp.total >= data.project.xp.target then --if at target for current level
		local temp = data.project.xp.target --store reached target temporarily
		data.project.xp.target = math.floor(data.project.xp.target * data.project.xp.inc) --go to next target threshold
		data.project.xp.level_size = data.project.xp.target - temp --update size of level
		data.project.xp.level_xp = 0 + (data.project.xp.total - temp) --reset levelxp, accounting for the total going over the target before this update
		data.project.xp.level = data.project.xp.level + 1 --iterate level
	end
end

--calculate time spent in session
function NS.track_time()
	local current_time = vim.loop.hrtime() --get current time
	local delta_time = (current_time - total_time_update) / 1e9 --get time since last update

	data.project.stats.total_time = data.project.stats.total_time + delta_time --add time to total
	data.session_time = data.session_time + delta_time --add time for session

	total_time_update = current_time --set when last update was
end

--record stats from char input in insert mode
function NS.add_chars(char)
	char = tostring(char) --convert to string
	if char ~= " " then --if input is not a space
		data.project.stats.all_typed_chars[char] = (data.project.stats.all_typed_chars[char] or 0) + 1 --iterate char typed. create entry if doesnt exist
	end
	data.project.stats.total_typed_chars = data.project.stats.total_typed_chars + 1 --iterate total char count
	data.project.xp.total = data.project.xp.total + 1 --add xp to total
	data.project.xp.level_xp = data.project.xp.level_xp + 1 --add xp to current level
end

--deleted chars
local buf_sizes = {} --store sizes for buffers
local attached = {} --store attached buffers
function NS.track_deleted_chars(buf)
	if attached[buf] then --quit if already attached to buffer
		return
	end
	attached[buf] = true --else mark that attached to buffer

	--get the size of the buffer before the change
	buf_sizes[buf] = vim.api.nvim_buf_get_offset(buf, vim.api.nvim_buf_line_count(buf))

	vim.api.nvim_buf_attach(buf, false, { --attach to buffer after change
		on_lines = function(_, buf, _, _, _, _, _)
			local new_size = vim.api.nvim_buf_get_offset(buf, vim.api.nvim_buf_line_count(buf))
			local old_size = buf_sizes[buf] or new_size --get the new size

			local diff = old_size - new_size --get difference between new and old size

			if diff > 0 then --if there was less in old size, add how many less to stats
				data.project.stats.total_deleted_chars = (data.project.stats.total_deleted_chars or 0) + diff
			end

			--update stored size
			buf_sizes[buf] = new_size
		end,
	})
end

--recursive function to look through project and count number of files
function NS.count_files(path)
	path = path or NS.current_project --path set to current project by default
	local count = 0 --current count of files

	local ignore = { --files/folders to ignore
		[".git"] = true,
		["node_modules"] = true,
		[".cache"] = true,
		["dist"] = true,
		["build"] = true,
	}

	for name, type in vim.fs.dir(path) do --for each item in the project
		local full = path .. "/" .. name --get full path
		if ignore[name] or type == "link" then --if name of item is in the ignore, table. ignore symlinks
			goto continue --skip this iteration
		end
		if type == "file" then --if the item is a file
			count = count + 1 --count it
		elseif type == "directory" then --if the item is a directory
			count = count + NS.count_files(full) --count from within that directory and add to current count
		end
		::continue:: --used to skip loop
	end
	return count --send count back
end

--update stats and other numbery stuff
function NS.update()
	NS.xp_calc() --update stats and stuff
	NS.track_time() --update time
	data.project.stats.deleted_percentage = string.format(
		"%.2f",
		((data.project.stats.total_deleted_chars / data.project.stats.total_typed_chars) * 100) or 0
	) --percent of characters deleted
	if window.mini.exists() then --if mini window exists
		window.mini.update() --update
	end
	if window.main.exists() then --if main window exists
		window.main.update() --update
	end
	autosave = autosave - 1 --countdown to autosave
	if autosave == 0 then --if counted down
		save.save_data() --save
		autosave = NS.config.autosave_interval --reset countdown
	end
end

--timer for updating
function NS.start_update_timer()
	if NS._update_timer then --if timer exists already then stop it
		NS._update_timer:stop()
	end

	--was getting "undefined-field" on new_timer() even though it worked fine
	---@diagnostic disable-next-line: undefined-field
	NS._update_timer = vim.uv.new_timer() --create new timer

	NS._update_timer:start(
		0, --start on startup
		1000, --repeat 1000ms (1second)
		vim.schedule_wrap(function()
			NS.update() --update everything that needs updating
		end)
	)
end

--return true if the inputted window is valid for counting splits
local function is_valid_window(win)
	local config = vim.api.nvim_win_get_config(win) --get config of windows
	if config.relative ~= "" then --if floating
		return true --return true
	end
	return false
end

--check if the project needs to be switched
function NS.check_project()
	local new_path = save.get_project_root() --get new root
	if NS.current_project ~= new_path then --if path is different
		NS.switch() --switch projects
	end
end

--switch project
function NS.switch()
	--NS.session_time() --save time for current project
	NS.xp_calc() --final xp calcs
	save.save_data() --save current project data
	NS.current_project = save.get_project_root() --get new current_project root
	data.data = save.load_data() --load new data
	data.project = save.get_project_stats() --get new project stats
	if window.mini.exists() then
		window.mini.update() --update window if it exists
	end
end

--exiting cleanly
function NS.exit()
	window.mini.close() --close mini window
	window.main.close() --close main window
	if NS._update_timer then --if timer exists
		NS._update_timer:stop() --stop update timer
	end
	--NS.session_time() --calculate session time and add to stats
	NS.xp_calc() --do any last xp calculations
	NS.track_time() --time calculations
	data.session_time = 0 --reset session time
	save.save_data() --save the current data
end

--setup stuff
function NS.setup(opts)
	opts = opts or {} --passed opts
	NS.config = vim.tbl_deep_extend("force", NS.config, opts) --merge/override defaults and passed opts
	save.setup(opts.markers) --setup save config

	NS.current_project = save.get_project_root() --get path of current project
	data.data = save.load_data() --load the saved data
	data.project = save.get_project_stats() --get the specific local project data
	--sets defaults if not

	--get total_time_update and set session_time
	data.session_time = 0 --set session time to 0 (should be already but just incase)
	total_time_update = vim.loop.hrtime()
	NS.start_update_timer() --start update timer

	--keymap for toggling the mini window
	vim.keymap.set("n", "<leader>ns", function()
		if window.mini.exists() then --if window exists
			NS.exit() --clean exit
		else --else open window
			window.mini.open() --pass in xp values for displaying
			NS.update() --update stuff
		end
	end, { desc = "Toggle NeoStats Window", silent = true, nowait = true, noremap = true })

	--commands for NeoStats
	vim.api.nvim_create_user_command("NeoStats", function(opts)
		local commands = { --table of commands
			default = function() --the default noargs function
				data.project.stats.project_files = NS.count_files() --get current file count
				window.main.open() --open the big window to display all stats
			end,
			reset = function() --reset
				save.reset_data() --call reset function
				data.project = save.get_project_stats() --load in new project data
				if window.mini.exists() then --if mini window open
					window.mini.update() --update window
				end
				print("NeoStats for current project have been reset") --output
			end,
			test = function() --call test function for any testing
				NS.test()
			end,
			--command2 = function() end
		}
		local cmd = opts.fargs[1] --get given args (if any)
		if not cmd then --if no arg given
			commands["default"]() --call default command
		elseif commands[cmd] then --else if arg given and if command exists
			commands[cmd]() --execute function
		end
	end, {
		nargs = "?", --allow zero or one arguments to be given
		complete = function() --completion for the arguments
			return { "reset" }
		end,
		desc = "NeoStats commands",
	})

	NS.create_autocmds() --create autocmds
end

--create all autocommands
function NS.create_autocmds()
	--define group for autocommands
	local augroup = vim.api.nvim_create_augroup("NeoStatsAuto", { clear = true })

	--for each char input in insert mode
	vim.api.nvim_create_autocmd("InsertCharPre", {
		group = augroup,
		pattern = "*",
		callback = function()
			NS.add_chars(vim.v.char)
		end,
	})

	--split tracking
	vim.api.nvim_create_autocmd("WinNew", { --add split open count
		group = augroup,
		pattern = "*",
		callback = function()
			local win = vim.api.nvim_get_current_win() --get window
			if not is_valid_window(win) then --if not a floating window
				data.project.stats.splits_opened = data.project.stats.splits_opened + 1 --iterate count
			end --this ignores the NeoStats window and any other plugin floating windows
		end,
	})
	vim.api.nvim_create_autocmd("WinClosed", { --add split close count
		group = augroup,
		pattern = "*",
		callback = function(args)
			local win = vim.api.nvim_get_current_win() --get window

			local other = tonumber(args.match) --detects the mini window specifically with config.relative ~= ""
			local _, config = pcall(vim.api.nvim_win_get_config, other)
			if config.relative ~= "" then
				return
			end

			if not is_valid_window(win) then --else if not a valid window
				data.project.stats.splits_closed = data.project.stats.splits_closed + 1 --iterate count
			end
		end,
	})

	--tab tracking
	vim.api.nvim_create_autocmd("TabNew", { --add tab open count
		group = augroup,
		pattern = "*",
		callback = function()
			data.project.stats.tabs_opened = data.project.stats.tabs_opened + 1
		end,
	})
	vim.api.nvim_create_autocmd("TabClosed", { --add tab close count
		group = augroup,
		pattern = "*",
		callback = function()
			data.project.stats.tabs_closed = data.project.stats.tabs_closed + 1
		end,
	})

	--on buf enter or directory change, check if need to load project again
	vim.api.nvim_create_autocmd({ "DirChanged", "BufEnter" }, {
		group = augroup,
		pattern = "*",
		callback = function(args)
			NS.check_project()
			NS.track_deleted_chars(args.buf)
		end,
	})

	--on leaving nvim, save data
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = augroup,
		callback = function()
			NS.exit() --clean exit
		end,
	})
end

--temporary test function for when needed
function NS.test()
	print(NS.count_files())
end

return NS

--[[ text testing area
--123123
]]
