--saving and loading data from savefiles
--
--
local M = {} --module

local dir = vim.fn.stdpath("data") .. "/neostats" --folder for neostats data in nvims data folder
local file = dir .. "/neostats.json" --json file to save data into

--figure out the root of project based off certain markers like git
function M.get_project_root()
	local cur_file = vim.api.nvim_buf_get_name(0) --current file open
	local start = cur_file ~= "" and vim.fs.dirname(cur_file) or vim.fn.getcwd()
	--if current buffer has file, start = containing folder, else start = cwd

	local markers = { --things to use as project markers
		".git",
		"package.json",
		"pyproject.toml",
		"Cargo.toml",
		"go.mod",
		"Makefile",
		"stylua.toml",
		".nvim.lua",
	}

	local found = vim.fs.find(markers, { --search upwards through directories to find markers
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
function M.get_project_stats(data, default)
	local project = M.get_project_root() --get project root to use as project key

	if not data[project] then --if no stats for the cwd
		data[project] = vim.deepcopy(default) --set to default (make copy of default rather than pointing to it)
	end

	return data[project] --return current project stats
end

--save to a JSON file in nvim data dir
function M.save_data(data)
	vim.fn.mkdir(dir, "p") --make the save directory if it doesnt exist

	local savefile = io.open(file, "w") --open savefile in write mode
	if not savefile then
		return --exit if file couldnt be opened
	end

	savefile:write(vim.fn.json_encode(data)) --write the data table into the file
	savefile:close() --close file
end

--load data from the JSON file
function M.load_data()
	local savefile = io.open(file, "r") --open savefile in read mode
	if not savefile then
		return {} --quit if file couldnt be opened
	end

	local content = savefile:read("a") --read all the files contents
	savefile:close() --close file

	if content and content ~= "" then --if the content exists and isnt empty
		return vim.fn.json_decode(content) --put content into data table and return
	end
end

--reset the data for the current project in the data table
function M.reset_data(data)
	local project = M.get_project_root() --get project root to use as project key
	data[project] = nil --reset the data at that project
	return data --return table with project removed
end

return M
