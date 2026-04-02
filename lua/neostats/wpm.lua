--wpm tracker for NeoStats

local M = {}

local chars = {} --table of characters typed

local cpw = 5 --characters per word
local countwin = 10 --seconds to count wpm over

--setup module with opts
function M.setup(opts_cpw, opts_countwin)
	cpw = cpw or opts_cpw --set cpw
	countwin = countwin or opts_countwin --set countwindow
end

--add typed char and the time to chars table
function M.add_chars(c)
	table.insert(chars, { char = c, time = os.time() })
end

--calculate wpm
function M.calc_wpm()
	local current = os.time() --get current time
	local count = 0 --number of characters
	for i = #chars, 1, -1 do --iterate through chars table backwards
		if current - chars[i].time <= countwin then --if char is within the count window
			count = count + 1 --iterate counter
		end
	end
	return (count / cpw) --output wpm
end

return M
