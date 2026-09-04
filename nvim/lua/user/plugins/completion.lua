return {
  'saghen/blink.cmp',
  version = '*',
  opts = {
    keymap = {
      preset = 'default',
      ['<C-n>'] = false, -- superseded by <C-j>
      ['<C-p>'] = false, -- superseded by <C-k>
      ['<C-y>'] = false, -- superseded by <C-h>
      ['<C-j>'] = { 'select_next', 'fallback_to_mappings' },
      ['<C-k>'] = { 'select_prev', 'fallback_to_mappings' }, -- superseded default show_signature binding
      ['<C-h>'] = { 'select_and_accept', 'fallback' },
      ['<C-\\>'] = { 'show_signature', 'hide_signature', 'fallback' },
    },
    appearance = { nerd_font_variant = 'mono' },
    completion = { documentation = { auto_show = true } },
  },
}
