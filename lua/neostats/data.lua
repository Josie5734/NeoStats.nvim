--module for holding data tables to make them shareable easily

--TODO:
--change stat names to better things

local M = {}

M.data = { --track stats per project
	--[projectroot] = {
	--xp = {}
	--stats = {}
	--}
}

M.project = {} --stats for current project

M.default_stats = { --default stats used when no project stats are found
	xp = { --xp stuff
		total = 0, --total xp
		target = 100, --target xp for next level
		level_xp = 0, --xp for the current level (internal, used for xpbar)
		level_size = 100, --how much xp is needed for current level (tar-total on levelup, used for xpbar)
		level = 0, --current level
		inc = 2.05, --how much to multiply by for the next target
	},
	stats = { --tracked stats
		total_typed_chars = 0, --chars typed
		all_typed_chars = {}, --table for every character typed, is built dynamically upon typing a character
		total_deleted_chars = 0, --total deleted chars
		total_time = 0, --time in project
		deleted_percentage = 0, --percentage of chars deleted out of inserted
	},
}

return M
