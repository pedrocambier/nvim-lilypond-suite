local nvls_options

local default = {
  lilypond = {
    mappings = {
      player = "<F3>",
      compile = "<F5>",
      open_pdf = "<F6>",
      switch_buffers = "<A-Space>",
      insert_version = "<F4>",
      hyphenation = "<F12>",
      hyphenation_change_lang = "<F11>",
      insert_hyphen = "<leader>ih",
      add_hyphen = "<leader>ah",
      del_next_hyphen = "<leader>dh",
      del_prev_hyphen = "<leader>dH",
			increase_duration = "<C-a>",
			decrease_duration = "<C-x>",
    },
    options = {
      pitches_language = "default",
      hyphenation_language = "en_DEFAULT",
      output = "pdf",
      backend = nil,
      main_file = "main.ly",
      main_folder = "%:p:h",
      include_dir = nil,
      diagnostics = false,
      pdf_viewer = nil,
			project_folder = nil,
			output_folder = nil,
    },
  },
  latex = {
    mappings = {
      compile = "<F5>",
      open_pdf = "<F6>",
      lilypond_syntax = "<F3>"
    },
    options = {
      lilypond_book_flags = nil,
      clean_logs = false,
      main_file = "main.tex",
      main_folder = "%:p:h",
      include_dir = nil,
      lilypond_syntax_au = "BufEnter",
      pdf_viewer = nil,
    },
  },
  texinfo = {
    mappings = {
      compile = "<F5>",
      open_pdf = "<F6>",
      lilypond_syntax = "<F3>"
    },
    options = {
      lilypond_book_flags = "--pdf",
      clean_logs = false,
      main_file = "main.texi",
      main_folder = "%:p:h",
      --include_dir = nil,
      lilypond_syntax_au = "BufEnter",
      pdf_viewer = nil,
    },
  },
  player = {
    mappings = {
      quit = "q",
      play_pause = "p",
      loop = "<A-l>",
      backward = "h",
      small_backward = "<S-h>",
      forward = "l",
      small_forward = "<S-l>",
      decrease_speed = "j",
      increase_speed = "k",
      halve_speed = "<S-j>",
      double_speed = "<S-k>"
    },
    options = {
      row = 1,
      col = "99%",
      width = "37",
      height = "1",
      border_style = "single",
      winhighlight = "Normal:Normal,FloatBorder:Normal,FloatTitle:Normal",
      midi_synth = "fluidsynth",
      fluidsynth_flags = nil,
      timidity_flags = nil,
      audio_format = "mp3",
      mpv_flags = {
        "--msg-level=cplayer=no,ffmpeg=no,alsa=no",
        "--loop",
        "--config-dir=/dev/null",
        "--no-video"
      }
    },
  },
}

local default_hi = {
  lilyString = { link = "String" },
  lilyDynamic = { bold = true },
  lilyComment = { link = "Comment" },
  lilyNumber = { link = "Number" },
  lilyVar = { link = "Tag" },
  lilyBoolean = { link = "Boolean" },
  lilySpecial = { bold = true },
  lilyArgument = { link = "Type" },
  lilyScheme = { link = "Special" },
  lilyLyrics = { link = "Special" },
  lilyMarkup = { bold = true },
  lilyFunction = { link = "Statement" },
  lilyArticulation = { link = "PreProc" },
  lilyContext = { link = "Type" },
  lilyGrob = { link = "Include" },
  lilyTranslator = { link = "Type" },
  lilyPitch = { link = "Function" },
  lilyChord = {
    ctermfg = "lightMagenta",
    fg = "lightMagenta",
    bold = true
  },
}

local M = {}

M.setup = function(opts)
  opts = opts or {}
  nvls_options = vim.tbl_deep_extend('keep', opts, default)
  vim.g.nvls_language = nvls_options.lilypond.options.pitches_language
  M.syntax()
end

M.merge_options = function(opts)
	opts = opts or {}
	nvls_options = vim.tbl_deep_extend('keep', opts, nvls_options)
end

function M.syntax()
  local hi = default_hi
  if nvls_options and nvls_options.lilypond and nvls_options.lilypond.highlights then
    hi = vim.tbl_extend('keep', nvls_options.lilypond.highlights, default_hi)
  end
  for i, j in pairs(hi) do
    vim.api.nvim_set_hl(0, i, j)
  end
end

M.get_nvls_options = function()
  return nvls_options or default
end

vim.api.nvim_create_user_command('Viewer', function()
  local file = require('nvls.config').fileInfos()
  require('nvls.viewer').open(file.pdf, file.name .. ".pdf")
end, {})

return M
