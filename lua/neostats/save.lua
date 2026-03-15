--saving and loading data from savefiles
--
--
local M = {} --module

local dir = vim.fn.stdpath("data") .. "/neostats" --folder for neostats data in nvims data folder
local file = dir .. "/neostats.json" --json file to save data into

--return the stats for the current project (cwd) or set them to default if its a new project
function M.get_project_stats(data, default)
	local project = vim.fn.getcwd() --get cwd to use as project key

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
	local project = vim.fn.getcwd() --get cwd to use as project key
	data[project] = nil --reset the data at that project
	return data --return table with project removed
end

return M
