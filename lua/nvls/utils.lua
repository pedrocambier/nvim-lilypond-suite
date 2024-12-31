local os_type = vim.loop.os_uname().sysname

local M = {}

function M.message(str, level)
	level = level or "INFO"
	vim.notify("[NVLS] " .. str, vim.log.levels[level], {})
end

function M.has(file, string)
	local content = io.open(file, "r")
	if not content then return end
	content = content:read("*all")
	return content:find(string, 1, true) ~= nil
end

function M.joinpath(parent, filename)
	if not filename then return '' end
	return parent .. package.config:sub(1, 1) .. filename
end

function M.remove_path(file)
	local out
	if os_type == "Windows" then
		out = file:match('.*\\([^\\]+)$')
	else
		out = file:match('.*/([^/]+)$')
	end
	return out
end

function M.remove_extension(file)
	local parts = {}
	for part in file:gmatch("([^%.]+)") do
		table.insert(parts, part)
	end
	if #parts > 1 then
		table.remove(parts)
	end
	local out = table.concat(parts, ".")
	return out
end

function M.change_extension(file, new)
	local base, current = file:match("^(.+)(%.%w+)$")
	return base and current and base .. "." .. new or nil
end

function M.shellescape(file, escape)
	if not file then return '' end
	local windows = {
		[" "] = "^ ",
		["%("] = "^%(",
		["%)"] = "^%)"
	}
	local unix = {
		[" "] = "\\ ",
		["%("] = "\\%(",
		["%)"] = "\\%)"
	}

	local specialChars = (os_type == "Windows") and windows or unix

	if escape then
		for i, j in pairs(specialChars) do
			file = file:gsub(i, j)
		end
	else
		for i, j in pairs(specialChars) do
			file = file:gsub(j, i)
		end
	end

	return file
end

function M.concat_flags(flags)
	if type(flags) == "table" then
		flags = table.concat(flags, " ")
	end
	return flags
end

function M.extract_from_sel(_start, _end)
	local nlines = 0
	if (_end[2] == -1) then
		local total_nlines = #vim.api.nvim_buf_get_lines(0, 0, -1, false)
		nlines = math.abs(total_nlines - _start[2]) + 1
	else
		nlines = math.abs(_end[2] - _start[2]) + 1
	end
	local sel = vim.api.nvim_buf_get_lines(0, _start[2] - 1, _end[2], false)

	if nlines == 1 then
		sel[1] = sel[1]:sub(_start[3], _end[3])
	else
		sel[1] = sel[1]:sub(_start[3], -1)
		sel[nlines] = sel[nlines]:sub(1, _end[3])
	end

	return table.concat(sel, '\n')
end

function M.exists(path)
	return io.open(vim.fn.glob(path)) ~= nil
end

function M.last_mod(file)
	if not M.exists(file) then return 0 end
	local var = (
		os_type == "Darwin" and io.popen("stat -f %m " .. file) or
		os_type == "Linux" and io.popen("stat -c %Y " .. file) or
		os_type == "Windows" and io.popen(string.format("for %%F in (%s) do @echo %%~tF", file))
	)
	return var and tonumber(var:read()) or 0
end

function M.clear_tmp_files()
	local _file = require('nvls.config').fileInfos()
	local to_delete = {}
	if vim.bo.filetype == "tex" or vim.bo.filetype == "texinfo" then
		to_delete = {
			M.change_extension(_file.main, 'log'),
			M.change_extension(_file.main, 'aux'),
			M.change_extension(_file.main, 'out'),
			M.joinpath(_file.folder, 'tmp-ly'),
		}
		for _, file in ipairs(to_delete) do
			os.remove(file)
		end
	end
	local tmp_contents = vim.fn.readdir(_file.tmp)
	for _, item in ipairs(tmp_contents) do
		local item_path = M.joinpath(_file.tmp, item)
		table.insert(to_delete, item_path)
	end
	for _, file in ipairs(to_delete) do
		vim.fn.delete(file, "rf")
	end
end

local function change_note_duration(is_increase)
	local lin, col = unpack(vim.api.nvim_win_get_cursor(0))
	local cursor_word = vim.fn.expand('<cWORD>')
	if (cursor_word == "") then
		return
	end

	local line = vim.api.nvim_get_current_line()
	local reverse_line_until_cursor = string.reverse(string.sub(line, 1, col + 1))
	local line_from_cursor = string.sub(line, col + 1)

	local first_whitespace = string.find(line_from_cursor, "%s") or -1
	local reverse_first_whitespace = string.find(reverse_line_until_cursor, "%s") or -1
	local is_start_line = col == 0
	local is_whitespace = first_whitespace == 1
	local is_start_word = reverse_first_whitespace == 2

	local col_start_word = -1
	if (is_start_word or is_start_line) then
		col_start_word = col + 1
	elseif (is_whitespace) then
		col_start_word = string.find(line_from_cursor, "%S") + col
	else
		col_start_word = col - reverse_first_whitespace + 3
	end

	local number_start, number_end, duration = string.find(cursor_word, "(%d%d?%d?%d?)")
	local word_has_duration = duration ~= nil
	local col_start_number = -1
	local col_end_number = -1
	if not duration then
		col_start_number = col_start_word + string.len(cursor_word)
		col_end_number = col_start_number
		local reverse_duration = string.match(reverse_line_until_cursor, "%d%d?%d?%d?")
		if reverse_duration then
			duration = string.reverse(reverse_duration)
		end
	else
		col_start_number = col_start_word + number_start - 1
		col_end_number = col_start_word + number_end - 1
	end

	duration = tonumber(duration) or 4
	if (duration ~= 1 and math.fmod(duration, 2) ~= 0) then
		return
	end
	local new_duration = nil
		if is_increase and duration ~= 1 then
			new_duration = duration / 2
		elseif not is_increase and duration <= 512 then
			new_duration = duration * 2
		else
			return
		end

	local new_word = ""
	if word_has_duration then
		new_word = string.gsub(cursor_word, duration, new_duration)
	else
		new_word = cursor_word .. new_duration
	end

	local lendiff = string.len(new_word) - string.len(cursor_word)
	local suffix = ''
	local i = 0
	while (i < lendiff) do
		suffix = suffix .. ' '
		i = i + 1
	end

	vim.api.nvim_buf_set_text(0, lin - 1, col_start_number - 1, lin - 1, col_end_number, { '' .. new_duration .. suffix })
end

function M.increase_note_duration()
	change_note_duration(true)
end

function M.decrease_note_duration()
	change_note_duration(false)
end

function M.map(key, cmd)
	vim.keymap.set('n', key, cmd, { noremap = true, silent = true, buffer = true })
end

function M.imap(key, cmd)
	vim.keymap.set('i', key, cmd, { noremap = true, silent = true, buffer = true })
end

function M.vmap(key, cmd)
	vim.keymap.set('v', key, cmd, { noremap = true, silent = true, buffer = true })
end

return M
