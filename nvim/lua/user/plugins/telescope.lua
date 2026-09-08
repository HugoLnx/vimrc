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
    local make_entry = require('telescope.make_entry')
    local actions = require('telescope.actions')
    local action_state = require('telescope.actions.state')
    -- <C-t> normally opens only the entry under the cursor in a new tab
    -- (telescope's actions.set.edit reads get_selected_entry, ignoring
    -- multi-selection). Open every multi-selected entry in its own tab
    -- instead, falling back to stock select_tab when nothing is multi-selected.
    local function select_tab_multi(prompt_bufnr)
      local picker = action_state.get_current_picker(prompt_bufnr)
      local selections = picker:get_multi_selection()
      if #selections == 0 then
        return actions.select_tab(prompt_bufnr)
      end
      actions.close(prompt_bufnr)
      for _, entry in ipairs(selections) do
        local filename = entry.path or entry.filename
        if filename then
          vim.cmd('tabedit ' .. vim.fn.fnameescape(filename))
        end
      end
    end
    local default_ignore_patterns = {
      'node_modules/', '%.git/', 'deps/', '_build/', 'frameworks/',
      'tmp/cache/', 'dist/', '_old/', 'vendor/ruby/', 'coverage/',
    }
    -- project/build metadata and binary/media files: rarely what's wanted
    -- when jumping to a file to edit, so excluded from the code-only finder
    -- below via an entry_maker set lookup (still reachable via the
    -- unrestricted <leader>ff finder). Kept in sync with repo-configs/gitattributes'
    -- lfs-file list of binary types.
    local non_code_extensions = {
      'meta', 'csproj', 'sln', 'slnx', 'user', 'suo', 'pdb', 'dll', 'exe', 'obj', 'cache',
      'asset', 'config', 'unity', 'rsp', 'asmdef',
      -- images
      'png', 'jpg', 'jpeg', 'gif', 'bmp', 'ico', 'svg', 'svgz', 'psd', 'tga', 'ai', 'apng',
      'atsc', 'tiff', 'tif', 'iff', 'pict', 'dds', 'xcf', 'leo', 'kra', 'kpp', 'clip',
      'webm', 'webp', 'afphoto', 'afdesign',
      -- audio/video
      'mp3', 'wav', 'ogg', 'aiff', 'aif', 'mod', 'it', 's3m', 'xm',
      'mp4', 'mov', 'asf', 'mpg', 'mpeg', 'flv', 'ogv', 'wmv', 'mkv',
      -- archives
      'zip', '7z', 'rar', 'tar', 'gz', 'dmg',
      -- fonts
      'ttf', 'otf', 'woff', 'woff2',
      -- 3D / unity assets & materials
      'mat', 'fbx', 'blend', 'blender', 'dae', 'max', 'mb', 'ma', '3ds', 'dfx', 'c4d',
      'lwo', 'lwo2', 'abc', '3dm', 'glb', 'unitypackage', 'sbsar', 'cubemap', 'bundle',
      -- binaries / packaging
      'bin', 'so', 'dylib', 'lib', 'o', 'a', 'pdf', 'sqlite', 'db', 'snk', 'pfx', 'p12',
      'cer', 'nupkg', 'rns', 'reason', 'lxo',
      -- documentation
      'md', 'mdc', 'txt', 'rst', 'csv', 'doc', 'docx',
    }
    local function to_set(list)
      local set = {}
      for _, item in ipairs(list) do
        set[item:lower()] = true
      end
      return set
    end
    local non_code_ext_set = to_set(non_code_extensions)
    -- Extensionless/dotfile basename prefixes excluded from <C-p> alongside non_code_extensions.
    local non_code_basename_prefixes = { 'readme', 'changelog' }
    -- Extracts the last dot-suffix of a path's basename, lowercased.
    -- Returns nil for dotfiles (e.g. .gitignore) and extension-less files.
    local function file_extension(line)
      local basename = line:match('[^/\\]+$') or line
      local ext = basename:match('^.+%.([^.]+)$')
      return ext and ext:lower() or nil
    end
    -- Lowercased basename, used for dotfiles/extensionless names that
    -- file_extension() can't match (e.g. .gitconfig, README, CHANGELOG).
    local function file_basename(line)
      return (line:match('[^/\\]+$') or line):lower()
    end
    -- Matches a basename against a list of prefixes, e.g. "dockerfile" matches
    -- both "dockerfile" and "dockerfile.dev"; ".eslintrc" matches both
    -- ".eslintrc" and ".eslintrc.js".
    local function basename_matches(basename, prefixes)
      for _, prefix in ipairs(prefixes) do
        if basename == prefix or basename:sub(1, #prefix + 1) == prefix .. '.' then
          return true
        end
      end
      return false
    end
    local function is_non_code_file(line)
      local ext = file_extension(line)
      if ext ~= nil and non_code_ext_set[ext] == true then
        return true
      end
      return basename_matches(file_basename(line), non_code_basename_prefixes)
    end
    -- Documentation files: <leader>fd finder and (inverted) <C-p> exclusion.
    local doc_extensions_set = to_set({ 'md', 'mdc', 'txt', 'rst', 'adoc', 'asciidoc', 'org' })
    local doc_basename_prefixes = {
      'readme', 'changelog', '.cursorrules', 'license', 'licence', 'contributing',
      'authors', 'contributors', 'maintainers', 'code_of_conduct', 'notice', 'history',
      'news', 'todo', '.clinerules', '.windsurfrules',
    }
    local function is_doc_file(line)
      local ext = file_extension(line)
      if ext ~= nil and doc_extensions_set[ext] == true then
        return true
      end
      return basename_matches(file_basename(line), doc_basename_prefixes)
    end
    -- Configuration files: <leader>fc finder.
    local config_extensions_set = to_set({
      'cfg', 'yml', 'yaml', 'json', 'config', 'toml', 'conf', 'properties', 'ini',
    })
    local config_basename_prefixes = {
      '.editorconfig', '.gitconfig', '.gitignore', '.gitattributes', '.gitmodules',
      '.clang-format', '.clang-tidy', '.npmrc', '.nvmrc', '.yarnrc', '.eslintrc',
      '.prettierrc', '.babelrc', '.dockerignore', 'dockerfile', 'procfile', 'vagrantfile',
    }
    local function is_config_file(line)
      local ext = file_extension(line)
      if ext ~= nil and config_extensions_set[ext] == true then
        return true
      end
      return basename_matches(file_basename(line), config_basename_prefixes)
    end
    telescope.setup({
      defaults = {
        file_ignore_patterns = default_ignore_patterns,
        mappings = {
          i = {
            ['<C-t>'] = select_tab_multi,
            ['<C-z>'] = actions.toggle_selection,
            ['<C-s>'] = actions.select_horizontal,
          },
          n = {
            ['<C-t>'] = select_tab_multi,
            ['<C-z>'] = actions.toggle_selection,
            ['<C-s>'] = actions.select_horizontal,
          },
        },
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
      local opts = { file_ignore_patterns = default_ignore_patterns, hidden = true }
      local gen_entry = make_entry.gen_from_file(opts)
      opts.entry_maker = function(line)
        if is_non_code_file(line) then
          return nil
        end
        return gen_entry(line)
      end
      builtin.find_files(opts)
    end
    -- Inclusion-filtered finders: only entries matching the predicate survive.
    local function find_files_matching(predicate)
      return function()
        local opts = { file_ignore_patterns = default_ignore_patterns, hidden = true }
        local gen_entry = make_entry.gen_from_file(opts)
        opts.entry_maker = function(line)
          if not predicate(line) then
            return nil
          end
          return gen_entry(line)
        end
        builtin.find_files(opts)
      end
    end
    local find_files_docs = find_files_matching(is_doc_file)
    local find_files_config = find_files_matching(is_config_file)
    -- Under Neovim, ctrlp.vim (classic-Vim-only, see vim/plugins.vim) never
    -- loads - Telescope is the replacement. Keep the muscle-memory shortcut.
    vim.keymap.set('n', '<C-p>', find_files_code, { desc = 'Find files (code/text only)' })
    vim.keymap.set('n', '<leader>ff', function() builtin.find_files({ hidden = true }) end,
      { desc = 'Find files (all files)' })
    vim.keymap.set('n', '<leader>fd', find_files_docs, { desc = 'Find documentation files' })
    vim.keymap.set('n', '<leader>fc', find_files_config, { desc = 'Find configuration files' })
    vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Live grep' })
    vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Find buffers' })
    vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Help tags' })
  end,
}
