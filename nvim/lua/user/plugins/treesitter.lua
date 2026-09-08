local parsers = {
  'c', 'cpp', 'c_sharp', 'html', 'css', 'javascript', 'typescript',
  'lua', 'vim', 'vimdoc', 'go', 'ruby', 'elixir', 'yaml', 'json',
  'markdown', 'dockerfile',
}

-- vimdoc is the parser name for help files; the autocmd below needs the
-- actual filetype instead.
local filetypes = vim.tbl_map(function(parser)
  return parser == 'vimdoc' and 'help' or parser
end, parsers)

return {
  'nvim-treesitter/nvim-treesitter',
  -- master was frozen for Nvim 0.11 and doesn't support 0.12; main is now
  -- the only maintained branch (and Nvim's default), but it dropped the
  -- old nvim-treesitter.configs setup() API in favor of explicit
  -- vim.treesitter.start()/indentexpr wiring below.
  branch = 'main',
  build = ':TSUpdate',
  config = function()
    require('nvim-treesitter').install(parsers)

    local function attach(buf)
      vim.treesitter.start(buf)
      vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end

    vim.api.nvim_create_autocmd('FileType', {
      pattern = filetypes,
      callback = function(args)
        attach(args.buf)
      end,
    })

    -- The first buffer named on the command line gets its FileType event
    -- fired before init.lua (and thus this config()) even runs, so the
    -- autocmd above always misses it; attach to it directly here too.
    if vim.tbl_contains(filetypes, vim.bo.filetype) then
      attach(0)
    end
  end,
}
