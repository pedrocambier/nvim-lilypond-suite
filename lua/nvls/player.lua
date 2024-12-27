local Config = require('nvls.config')
local Utils = require('nvls.utils')
local nvls_options = require('nvls').get_nvls_options()

local M = {}

function M.convert()
  local C = Config.fileInfos()

  if Utils.exists(C.midi) then

    local midi_last = Utils.last_mod(C.midi)
    local audio_last = Utils.last_mod(C.audio)

    if (audio_last > midi_last) then
      M.open(C.audio, C.name .. "." .. C.audio_format)

    else
      Utils.message(string.format('Converting %s.midi to %s...', C.name, C.audio_format))
      local old_audio = Utils.shellescape(C.audio, false)
      if type(old_audio) == "string" then
        os.remove(old_audio)
      end
      require('nvls.make').async("fluidsynth")
    end

  elseif Utils.exists(C.audio) then
    M.open(C.audio, C.name .. "." .. C.audio_format)

  else
    Utils.message(string.format("Can't find %s.%s or %s.midi in working directory", C.name, C.audio_format, C.name), "ERROR")
    do return end
  end
end

local plopts = nvls_options.player.options
local row_status

local function num(value, axis)
  local factor = axis == "y" and vim.fn.winheight(0) or vim.fn.winwidth(0)
  local n = tonumber(value)
  if n then
    return math.floor(n + 0.5)
  elseif type(value) == "string" then
    local percentage = tonumber(value:match("(%d+%.?%d*)%%"))
    if percentage then
      local v = percentage / 100
      if v >= 0 and v <= 1 then
        return math.floor((v * factor) + 0.5)
      end
    end
  end
end

local function player_adjust(row, add)
  local decay
  local init = num(plopts.row, 'y')
  if init > vim.fn.winheight(0) / 2 then
    decay = add and -4 or 2
  else
    decay = add and 2 or -4
  end
  return row + decay + num(plopts.height, 'y')
end

function M.open(file, name)
  name = name or file
  local shortname = name:sub(9 - num(plopts.width, 'x'))
  name = shortname:len() < name:len() and "..." .. shortname or name

  if not row_status then row_status = num(plopts.row, 'y') end

  local opts = {
    style = "minimal",
    relative = "editor",
    row = row_status - num(plopts.height, 'y'),
    col = num(plopts.col, 'x') - num(plopts.width, 'x'),
    width = num(plopts.width, 'x'),
    height = num(plopts.height, 'y'),
    border = plopts.border_style,
    focusable = true,
    title = '['.. name .. ']',
    title_pos = 'center'
  }

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, false, opts)

  row_status = player_adjust(row_status, true)

  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_win_set_option(win, 'winhighlight', plopts.winhighlight)
  vim.api.nvim_set_current_win(win)

  vim.api.nvim_buf_call(buf, function()
    vim.fn.execute(string.format("term mpv %s %s", Utils.concat_flags(plopts.mpv_flags), file))
    vim.fn.execute('stopinsert')
  end)

  local function map(key, cmd)
    vim.keymap.set('n', key, cmd, { buffer = buf })
  end

  local opt, lyopt = nvls_options.player.mappings, nvls_options.lilypond.mappings

  map('<esc>', "<cmd>q<cr>")
  map("p", "ip<cmd>stopinsert<cr>")
  map(opt.quit, '<cmd>q<cr>')
  map(lyopt.switch_buffers, "<cmd>stopinsert<cr><C-w>w")
  map(opt.backward, "i<Left><cmd>stopinsert<cr>")
  map(opt.forward, "i<Right><cmd>stopinsert<cr>")
  map(opt.small_forward, "i<S-Right><cmd>stopinsert<cr>")
  map(opt.small_backward, "i<S-Left><cmd>stopinsert<cr>")
  map(opt.play_pause, "ip<cmd>stopinsert<cr>")
  map(opt.halve_speed, "i{<cmd>stopinsert<cr>")
  map(opt.double_speed, "i}<cmd>stopinsert<cr>")
  map(opt.decrease_speed, "i[<cmd>stopinsert<cr>")
  map(opt.increase_speed, "i]<cmd>stopinsert<cr>")
  map(opt.loop, "il<cmd>stopinsert<cr>")
  map(':', "")
  map('i', "")

  vim.api.nvim_create_autocmd({"WinClosed"}, {
    buffer = buf,
    callback = function()
      vim.api.nvim_buf_delete(buf, { force = true })
      row_status = player_adjust(row_status, false)
    end
  })
  vim.api.nvim_create_autocmd({"TermClose"}, {
    buffer = buf,
    callback = function()
      vim.api.nvim_buf_delete(buf, { force = true })
      row_status = player_adjust(row_status, false)
    end
  })
end

local function quickplayerInputType(sel)
  local from_top = Utils.extract_from_sel({0, 1, 1, 0}, vim.fn.getpos("'<"))

  local function getInputTypeFromSource(source)
    local relative = source:match(".*%prelative%s+%a*%p*%s*%{")
    local fixed = source:match(".*%pfixed%s+%a*%p*%s*%{")
    local chords = source:match(".*%pchords%s+%{")

    if relative then
      local ref_pitch = relative:match(".*%prelative(%s+%a%p*)") or " "
      return "\\relative" .. ref_pitch
    elseif fixed then
      local ref_pitch = fixed:match(".*%pfixed(%s+%a%p*)") or " "
      return "\\fixed" .. ref_pitch
    elseif chords then
      return "\\chords"
    else
      return ''
    end
  end

  if string.find(sel, "%pfixed%s+%a*%p*%s*%{") or
     string.find(sel, "%prelative%s+%a*%p*%s*%{") or
     string.find(sel, "%pchords.*%{") then
    return ''
  else
    return getInputTypeFromSource(from_top)
  end
end

local function quickplayerPitchesLanguage(sel)
	local from_top = Utils.extract_from_sel({ 0, 1, 1, 0 }, vim.fn.getpos("'<"))

	local function getLanguageFromSource(source)
		local language = source:match(".*(%planguage%s+\"%a*\")")
		if language then
			return language
		else
			local pitches_language = nvls_options.lilypond.options.pitches_language
			if (pitches_language ~= "default") then
				language = "\\language " .. pitches_language
				return language
			else
				return ''
			end
		end
	end

	if(string.find(sel, "%planguage%s+\"%a*\"")) then
		return ''
	else
		return getLanguageFromSource(from_top)
	end
end

local function quickplayerGetTempo(sel)
  local from_top = Utils.extract_from_sel({0, 1, 1, 0}, vim.fn.getpos("'<"))
	local to_bottom = Utils.extract_from_sel(vim.fn.getpos("'>"), {0, -1, -1, 0})

  local function extractTempo(source)
    local tempo = source:match([[.*%ptempo%s+(%d+%s*%=%s*%d+)]]) or
                  source:match([[.*%ptempo%s+(%"%a*%"%s+%d+%s*%=%s*%d+)]]) or
                  source:match([[.*%ptempo%s+(%"%a+%")]]) or
                  "4=60"
    return "\\tempo " .. tempo
  end

  if not (string.find(sel, "%ptempo%s") or string.find(from_top, "%ptempo%s") or string.find(to_bottom, "%ptempo%s")) then
    return ''
  elseif not (string.find(from_top, "%ptempo%s")) then
		return extractTempo(to_bottom)
	else
    return extractTempo(from_top)
  end
end

local function quickplayerCheckErr(str)
  local function countChar(s, char)
    local count = 0
    for _ in s:gmatch(char) do
      count = count + 1
    end
    return count
  end

  local bracket_pairs = {
    ["{"] = "}",
    ["<"] = ">"
  }

  for op_br, cl_br in pairs(bracket_pairs) do
    local op_count = countChar(str, op_br)
    local cl_count = countChar(str, cl_br)
    if op_count ~= cl_count then
      return string.format("%s brackets not matching in visual selection", op_br)
    end
  end

  if string.find(str, "%pscore%s") then
    return "Can't compile with \\score in visual selection"
  end

  return nil
end

function M.quickplayer()
  Utils.clear_tmp_files()
  local sel = Utils.extract_from_sel(vim.fn.getpos("'<"), vim.fn.getpos("'>"))

  local err_msg = quickplayerCheckErr(sel)
  if err_msg then
    Utils.message(err_msg, "ERROR")
    return
  else
    Utils.message('Converting to ' .. require('nvls.config').fileInfos().audio_format)
  end

	local language = quickplayerPitchesLanguage(sel)

  local input_type = quickplayerInputType(sel)

  local tempo = quickplayerGetTempo(sel)

  local codeParts = {}
  table.insert(codeParts, language)
  table.insert(codeParts, "\\score { ")
  table.insert(codeParts, input_type .. " { " .. sel .. " } ")
  table.insert(codeParts, "\\midi { " .. tempo .. " } ")
  table.insert(codeParts, "}")
  local code = table.concat(codeParts)

  local C = Config.fileInfos()
  local ly_file = Utils.joinpath(C.tmp, 'tmp.ly')
  local tmpfile = io.open(ly_file, 'w')
  if tmpfile then
    tmpfile:write(code)
    tmpfile:close()
  end
  os.execute(string.format('lilypond --loglevel=NONE -o %s %s', C.tmp, ly_file))

  require('nvls.make').async("tmpplayer")
end

return M
