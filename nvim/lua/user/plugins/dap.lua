-- nvim-dap: debug adapter protocol client. Currently used only for Unity
-- live debugging on Windows (see nvim/lua/user/unity_dap.lua); harmless
-- no-op setup elsewhere.

return {
  {
    'mfussenegger/nvim-dap',
    config = function()
      require('user.unity_dap').setup()
    end,
  },
}
