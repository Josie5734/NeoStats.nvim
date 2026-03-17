--plugin for tracking cool coding stats in projects

--[[
plan:
TODO:
opts implementation in setup to configure stuff
not actually sure what yet

TODO:
make the larger window where all stats will be tracked 
  NeoStats command to open it 
call big window the MainWindow and rename little one to MiniWindow
would first have to refactor current window stuff to be MiniWindow specific
then make stuff for MainWindow

TODO:
plans for stats to track:
.
-total characters typed in insert mode
-how many of each individual character
-characters + lines deleted 
-time spent in the project


for working out individual chars,
  in the insert mode character input autocmd, add each char to a list 
  then either on insert mode exist or on a timer
    create a copy of that list and clear the original
    go through copy list and for each char add 1 to the count for that char
    then delete copy
          copy is made so that chars can still be added whilst counting is happening


]]

local save = require("neostats.save") --get save functions
local window = require("neostats.window") --get window functions

local NS = {}

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
		total_chars = 0, --chars typed
		total_time = 0, --time in project
	},
}

NS.current_project = nil --path of currently open project

NS.data = { --track stats per project
	--[projectroot] = {
	--xp = {}
	--stats = {}
	--}
}

NS.project = {} --stats for current project

local startup_time = 0 --time that project was opened

--calculate xp level ups and stuff
function NS.xp_calc()
	if NS.project.xp.total >= NS.project.xp.target then --if at target for current level
		local temp = NS.project.xp.target --store reached target temporarily
		NS.project.xp.target = math.floor(NS.project.xp.target * NS.project.xp.inc) --go to next target threshold
		NS.project.xp.level_size = NS.project.xp.target - temp --update size of level
		NS.project.xp.level_xp = 0 + (NS.project.xp.total - temp) --reset levelxp, accounting for the total going over the target before this update
		NS.project.xp.level = NS.project.xp.level + 1 --iterate level
	end
end

--calculate time spent in session
function NS.session_time()
	local sessiontime = os.time() - startup_time --time on call - time at startup
	NS.project.stats.total_time = NS.project.stats.total_time + sessiontime
end

--update stats and other numbery stuff
function NS.update()
	NS.xp_calc() --update stats and stuff
	if window.mini_window_exists() then --if window exists
		window.mini_window_update(NS.project.xp) --update
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

--check if the project needs to be switched
function NS.check_project()
	local new_path = save.get_project_root() --get new root
	if NS.current_project ~= new_path then --if path is different
		NS.switch() --switch projects
	end
end

--switch project
function NS.switch()
	NS.session_time() --save time for current project
	NS.xp_calc() --final xp calcs
	save.save_data(NS.data) --save current project data
	startup_time = os.time() --reset startup time
	NS.current_project = save.get_project_root() --get new current_project root
	NS.data = save.load_data() --load new data
	NS.project = save.get_project_stats(NS.data, NS.default_stats) --get new project stats
	if window.mini_window_exists() then
		window.mini_window_update(NS.project.xp) --update window if it exists
	end
end

--exiting cleanly
function NS.exit()
	window.mini_window_close() --close window
	if NS._update_timer then --if timer exists
		NS._update_timer:stop() --stop update timer
	end
	NS.session_time() --calculate session time and add to stats
	NS.xp_calc() --do any last xp calculations
	save.save_data(NS.data) --save the current data
end

--setup stuff
function NS.setup()
	NS.current_project = save.get_project_root() --get path of current project
	NS.data = save.load_data() --load the saved data
	NS.project = save.get_project_stats(NS.data, NS.default_stats) --get the specific local project data
	--sets defaults if not

	--get startuptime
	startup_time = os.time()

	--keymap for toggling the window
	vim.keymap.set("n", "<leader>ns", function()
		if window.mini_window_exists() then --if window exists
			NS.exit() --clean exit
		else --else open window
			window.mini_window_open(NS.project.xp) --pass in xp values for displaying
			NS.update()
			NS.start_update_timer() --start update timer
		end
	end, { desc = "Toggle NeoStats Window", silent = true, nowait = true, noremap = true })

	--commands for NeoStats
	vim.api.nvim_create_user_command("NeoStats", function(opts)
		local commands = { --table of commands
			default = function() --the default noargs function
				window.main_window_open()
			end,
			reset = function() --reset
				save.reset_data(NS.data) --call reset function
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
			NS.project.stats.total_chars = NS.project.stats.total_chars + 1 --iterate total char count
			NS.project.xp.total = NS.project.xp.total + 1 --add xp to total
			NS.project.xp.level_xp = NS.project.xp.level_xp + 1 --add xp to current level
		end,
	})

	--on buf enter or directory change, check if need to load project again
	vim.api.nvim_create_autocmd({ "DirChanged", "BufEnter" }, {
		group = augroup,
		pattern = "*",
		callback = function()
			NS.check_project()
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
	print(NS.project.stats.total_time)
end

return NS

--[[ text testing area

]]
