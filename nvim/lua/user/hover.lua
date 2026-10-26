-- C# `gs`: the server's normal hover, preceded by the symbol's full
-- declaration header (modifiers, generics, base list, `where` constraints,
-- parameters) read from its definition via treesitter. Roslyn and csharp_ls
-- only hover with a short signature, so the header has to come from source.
local M = {}

-- Declarations that have a `name` field we can match against the definition
-- position (so a local/parameter doesn't resolve to its enclosing method).
local named = {
  class_declaration = true,
  struct_declaration = true,
  record_declaration = true,
  record_struct_declaration = true,
  interface_declaration = true,
  enum_declaration = true,
  delegate_declaration = true,
  method_declaration = true,
  constructor_declaration = true,
  destructor_declaration = true,
  local_function_statement = true,
  property_declaration = true,
  event_declaration = true,
}
-- No usable name field (the name lives in a nested declarator/operator token).
local unnamed = {
  field_declaration = true,
  event_field_declaration = true,
  operator_declaration = true,
  conversion_operator_declaration = true,
  indexer_declaration = true,
}

-- Children that start the body; the header is everything before them.
local body = {
  declaration_list = true,
  block = true,
  arrow_expression_clause = true,
  accessor_list = true,
  enum_member_declaration_list = true,
  constructor_initializer = true,
}

local function header_of(loc)
  local uri = loc.uri or loc.targetUri
  local range = loc.range or loc.targetSelectionRange
  if not uri or not range then
    return nil
  end
  local buf = vim.uri_to_bufnr(uri)
  vim.fn.bufload(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, 'c_sharp')
  if not ok or not parser then
    return nil
  end
  local tree = parser:parse()[1]
  if not tree then
    return nil
  end
  local row, col = range.start.line, range.start.character
  local node = tree:root():named_descendant_for_range(row, col, row, col)
  while node and not (named[node:type()] or unnamed[node:type()]) do
    node = node:parent()
  end
  if not node then
    return nil
  end
  if named[node:type()] then
    local name = node:field('name')[1]
    if not name then
      return nil
    end
    local nr, nc = name:start()
    if nr ~= row or nc ~= col then
      return nil
    end
  end

  local first, stop
  for child in node:iter_children() do
    if not first and child:type() ~= 'attribute_list' then
      first = child
    end
    if body[child:type()] then
      stop = child
      break
    end
  end
  if not first then
    return nil
  end
  local sr, sc = first:start()
  local er, ec
  if stop then
    er, ec = stop:start()
  else
    er, ec = node:end_()
  end
  local lines = vim.api.nvim_buf_get_text(buf, sr, sc, er, ec, {})
  local text = table.concat(lines, ' '):gsub('%s+', ' '):gsub('%s*;%s*$', ''):gsub('^%s+', ''):gsub('%s+$', '')
  return text ~= '' and text or nil
end

function M.hover()
  local buf = vim.api.nvim_get_current_buf()
  local function params(client)
    return vim.lsp.util.make_position_params(0, client.offset_encoding)
  end

  vim.lsp.buf_request_all(buf, 'textDocument/definition', params, function(def_results)
    local header
    for _, r in pairs(def_results) do
      local res = r.result
      if res and not vim.tbl_isempty(res) then
        local loc = vim.islist(res) and res[1] or res
        local ok, h = pcall(header_of, loc)
        if ok and h then
          header = h
          break
        end
      end
    end

    vim.lsp.buf_request_all(buf, 'textDocument/hover', params, function(hover_results)
      local lines = {}
      for _, r in pairs(hover_results) do
        if r.result and r.result.contents then
          local md = vim.lsp.util.convert_input_to_markdown_lines(r.result.contents)
          md = vim.split(table.concat(md, '\n'), '\n', { plain = true })
          vim.list_extend(lines, md)
          break
        end
      end
      if header then
        local head = { '```csharp', header, '```' }
        if #lines > 0 then
          vim.list_extend(head, { '---' })
        end
        lines = vim.list_extend(head, lines)
      end
      if #lines == 0 then
        vim.notify('No information available', vim.log.levels.INFO)
        return
      end
      vim.lsp.util.open_floating_preview(lines, 'markdown', {
        focus_id = 'gs',
        max_width = math.floor(vim.o.columns * 0.8),
        wrap = true,
      })
    end)
  end)
end

return M
