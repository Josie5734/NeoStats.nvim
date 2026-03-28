--saving and loading data from savefiles

local data = require("neostats.data") --get data

local M = {} --module

local dir = vim.fn.stdpath("data") .. "/neostats" --folder for neostats data in nvims data folder
local file = dir .. "/neostats.json" --json file to save data into

M.markers = {} --markers to use for project markers

function M.setup(markers) --get the markers from opts
	M.markers = markers
end

--figure out the root of project based off certain markers like git
function M.get_project_root()
	local cur_file = vim.api.nvim_buf_get_name(0) --current file open
	local start = cur_file ~= "" and vim.fs.dirname(cur_file) or vim.fn.getcwd()
	--if current buffer has file, start = containing folder, else start = cwd

	local found = vim.fs.find(M.markers, { --search upwards through directories to find markers
		path = start, --start in current/containing folder
		upward = true, --go upwards
		limit = 1, --maximum number of matches (1 to stop at first one)
	})

	if #found > 0 then --if any markers found
		return vim.fs.dirname(found[1]) --set the project directory to the folder containing the marker
	end

	return vim.fn.getcwd() --else return cwd by default
end

--return the stats for the current project (cwd) or set them to default if its a new project
function M.get_project_stats()
	local project = M.get_project_root() --get project root to use as project key

	if not data.data[project] then --if no stats for the cwd
		data.data[project] = vim.deepcopy(data.default_stats) --set to default (make copy of default rather than pointing to it)
	end
	data.data[project] = M.check_project_stats()
	return data.data[project] --return current project stats
end

--check that the project stats have all the stat fields from default_stats
function M.check_project_stats()
	local project_root = M.get_project_root() --get project root to use as project key
	local project = data.data[project_root] --get current project
	for k, v in pairs(data.default_stats.stats) do --for each stat in default
		if project.stats[k] == nil then --if that stat doesnt exist in data_t
			project.stats[k] = vim.deepcopy(v) --create it with default value
		end
	end
	for k, v in pairs(data.default_stats.xp) do --same thing for xp, shouldnt really be necessary but just incase
		if project.xp[k] == nil then
			project.xp[k] = vim.deepcopy(v)
		end
	end
	return project
end

--save to a JSON file in nvim data_t dir
function M.save_data()
	vim.fn.mkdir(dir, "p") --make the save directory if it doesnt exist

	local savefile = io.open(file, "w") --open savefile in write mode
	if not savefile then
		return --exit if file couldnt be opened
	end

	savefile:write(vim.fn.json_encode(data.data)) --write the data_t table into the file
	savefile:close() --close file
end

--load data_t from the JSON file
function M.load_data()
	local savefile = io.open(file, "r") --open savefile in read mode
	if not savefile then
		return {} --quit if file couldnt be opened
	end

	local content = savefile:read("a") --read all the files contents
	savefile:close() --close file

	if content and content ~= "" then --if the content exists and isnt empty
		return vim.fn.json_decode(content) --put content into data_t table and return
	end
end

--reset the data_t for the current project in the data_t table
function M.reset_data()
	local project = M.get_project_root() --get project root to use as project key
	data.data[project] = nil --reset the actual data table
end

return M
