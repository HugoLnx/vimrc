-- nvim-dap: debug adapter protocol client. Currently used only for Unity
-- live debugging on Windows (see nvim/lua/user/unity_dap.lua); harmless
-- no-op setup elsewhere.

return {
  {
    'mfussenegger/nvim-dap',
    config = function()
      require('user.unity_dap').setup()

      local dap = require('dap')
      local map = vim.keymap.set
      local function bind(keys, fn, desc)
        for _, lhs in ipairs(keys) do
          map('n', lhs, fn, { desc = desc })
        end
      end
      bind({ '<A-b>', '<F9>' }, dap.toggle_breakpoint, 'Dap: toggle breakpoint')
      bind({ '<A-c>', '<F5>' }, dap.continue, 'Dap: continue/start')
      bind({ '<A-s>', '<F10>' }, dap.step_over, 'Dap: step over')
      bind({ '<A-j>', '<F11>' }, dap.step_into, 'Dap: step into')
      bind({ '<A-k>', '<S-F11>' }, dap.step_out, 'Dap: step out')
    end,
  },
}
