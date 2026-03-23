--plugin for tracking cool coding stats in projects

--[[
plan:

TODO:
main window:
make better design/layout eventually
thinking having all the single value stats in the rows like they are,
then have the multivalues like individual chars in tables at the bottom, arranged together on the same lines
  would need function to format that
do something with "order" table so that it also stores a better name to be printed rather than the internal variable name,
  e.g "Characters Typed" instead of total_chars
  something like "total_chars" = "Characters Typed", so then when iterating through keys in order,
  send in order[key] to get the value rather than sending the key

TODO:
look into tracking properly when two separate instances of nvim open 

TODO:
plans for stats to add tracking for:
.
-how many of each individual character - (mostly done just need to change how it is displayed)
-characters + lines deleted (not sure about lines, but all and individual chars can be done, display same way as typed chars)
-number of files? potential for added/deleted?
-look into tracking normal mode commands and keyinputs
-splits and tabs opened/closed? probably an autocmd for those somewhere
]]

local save = require("neostats.save") --get save functions
local window = { --get window functions as window.main.function() and window.mini.function()
	main = require("neostats.window.main"),
	mini = require("neostats.window.mini"),
}
local data = require("neostats.data") --get data tables

local NS = {}

NS.current_project = nil --path of currently open project

local startup_time = 0 --time that project was opened

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
function NS.session_time()
	local sessiontime = os.time() - startup_time --time on call - time at startup
	data.project.stats.total_time = data.project.stats.total_time + sessiontime
end

--record stats from char input in insert mode
function NS.add_chars(char)
	char = tostring(char) --convert to string
	if char ~= " " then --if input is not a space
		data.project.stats.all_chars[char] = (data.project.stats.all_chars[char] or 0) + 1 --iterate char typed. create entry if doesnt exist
	end
	data.project.stats.total_chars = data.project.stats.total_chars + 1 --iterate total char count
	data.project.xp.total = data.project.xp.total + 1 --add xp to total
	data.project.xp.level_xp = data.project.xp.level_xp + 1 --add xp to current level
end

--update stats and other numbery stuff
function NS.update()
	NS.xp_calc() --update stats and stuff
	if window.mini.exists() then --if window exists
		window.mini.update() --update
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
	save.save_data(data.data) --save current project data
	startup_time = os.time() --reset startup time
	NS.current_project = save.get_project_root() --get new current_project root
	data.data = save.load_data() --load new data
	data.project = save.get_project_stats(data.data, data.default_stats) --get new project stats
	if window.mini.exists() then
		window.mini.update() --update window if it exists
	end
end

--exiting cleanly
function NS.exit()
	window.mini.close() --close window
	if NS._update_timer then --if timer exists
		NS._update_timer:stop() --stop update timer
	end
	NS.session_time() --calculate session time and add to stats
	NS.xp_calc() --do any last xp calculations
	save.save_data(data.data) --save the current data
end

--setup stuff
function NS.setup()
	NS.current_project = save.get_project_root() --get path of current project
	data.data = save.load_data() --load the saved data
	data.project = save.get_project_stats(data.data, data.default_stats) --get the specific local project data
	--sets defaults if not

	--get startuptime
	startup_time = os.time()

	--keymap for toggling the window
	vim.keymap.set("n", "<leader>ns", function()
		if window.mini.exists() then --if window exists
			NS.exit() --clean exit
		else --else open window
			window.mini.open() --pass in xp values for displaying
			NS.update() --update stuff
			NS.start_update_timer() --start update timer
		end
	end, { desc = "Toggle NeoStats Window", silent = true, nowait = true, noremap = true })

	--commands for NeoStats
	vim.api.nvim_create_user_command("NeoStats", function(opts)
		local commands = { --table of commands
			default = function() --the default noargs function
				window.main.open() --open the big window to display all stats
			end,
			reset = function() --reset
				save.reset_data(data.data) --call reset function
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
	print(vim.inspect(data.project.stats.all_chars))
end

return NS

--[[ text testing area
]]
