return {
  'nvim-telescope/telescope.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    -- optional perf extension, needs a C toolchain (make); skip if that's
    -- not available (e.g. plain Windows without MSVC/mingw installed)
    { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make', cond = vim.fn.executable('make') == 1 },
  },
  config = function()
    local telescope = require('telescope')
    local default_ignore_patterns = {
      'node_modules/', '%.git/', 'deps/', '_build/', 'frameworks/',
      'tmp/cache/', 'dist/', '_old/', 'vendor/ruby/', 'coverage/',
    }
    -- project/build metadata and binary/media files: rarely what's wanted
    -- when jumping to a file to edit, so excluded from the default finder
    -- (still reachable via the unrestricted <C-S-p> finder below).
    local non_code_patterns = {
      '%.meta$', '%.csproj$', '%.sln$', '%.slnx$', '%.user$', '%.suo$',
      '%.pdb$', '%.dll$', '%.exe$', '%.obj$', '%.cache$',
      '%.png$', '%.jpg$', '%.jpeg$', '%.gif$', '%.bmp$', '%.ico$', '%.svg$',
      '%.mp3$', '%.wav$', '%.ogg$', '%.mp4$', '%.mov$',
      '%.zip$', '%.7z$', '%.rar$', '%.tar$', '%.gz$',
      '%.ttf$', '%.otf$', '%.woff$', '%.woff2$',
    }
    telescope.setup({
      defaults = {
        file_ignore_patterns = default_ignore_patterns,
      },
      pickers = {
        -- live_grep/grep_string spawn a new rg process per keystroke;
        -- Windows' CreateProcess overhead makes that noticeably laggy
        -- without debouncing.
        live_grep = { debounce = 50 },
        grep_string = { debounce = 50 },
      },
    })
    pcall(telescope.load_extension, 'fzf')

    local builtin = require('telescope.builtin')
    local function find_files_code()
      builtin.find_files({
        file_ignore_patterns = vim.list_extend(vim.deepcopy(default_ignore_patterns), non_code_patterns),
      })
    end
    -- Under Neovim, ctrlp.vim (classic-Vim-only, see vim/plugins.vim) never
    -- loads - Telescope is the replacement. Keep the muscle-memory shortcut.
    vim.keymap.set('n', '<C-p>', find_files_code, { desc = 'Find files (code/text only)' })
    vim.keymap.set('n', '<leader>ff', find_files_code, { desc = 'Find files (code/text only)' })
    vim.keymap.set('n', '<C-S-p>', builtin.find_files, { desc = 'Find files (all files)' })
    vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Live grep' })
    vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Find buffers' })
    vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Help tags' })
  end,
}
