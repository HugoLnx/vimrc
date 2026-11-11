local M = {}

local MIN_IDEAL_FOLDERNAME_BUDGET = 7
local MIN_IDEAL_FILENAME_BUDGET = 11
local MIN_LEGIBLE_FOLDERS_BUDGET = 6
local MIN_LEGIBLE_FILENAME_BUDGET = 6
local MIN_LEGIBLE_BUDGET = 12
local MAX_IDEAL_REDUCTION_BUDGET = 2 * MIN_IDEAL_FOLDERNAME_BUDGET + MIN_IDEAL_FILENAME_BUDGET

local function split_words(s)
  local words, start, uppercase_run = {}, 1, 0
  for i = 1, #s do
    local c, prev, following = s:sub(i, i), s:sub(i - 1, i - 1), s:sub(i + 1, i + 1)
    local separator = not c:match('%w')
    local boundary = separator and prev:match('%w')
      or c:match('%u') and (prev:match('[%l%d]') or following:match('%l') and uppercase_run >= 2)
    if i > start and boundary then
      words[#words + 1] = s:sub(start, i - 1)
      start = i
    end
    uppercase_run = c:match('%u') and uppercase_run + 1 or 0
  end
  if start <= #s then
    words[#words + 1] = s:sub(start)
  end
  return words
end

-- Shortenings keep a subsequence of each part, described as kept byte ranges.
local function render(pieces)
  local out, marks, gap = {}, {}, false
  local function mark(i)
    if i > 0 and marks[#marks] ~= i then marks[#marks + 1] = i end
  end
  for _, piece in ipairs(pieces) do
    local str, pos = piece[1], 1
    for _, range in ipairs(piece[2]) do
      if range[1] > pos then gap = true end
      for i = range[1], range[2] do
        out[#out + 1] = str:sub(i, i)
        -- Hint the last kept char before a cut, or the first one after a leading cut.
        if gap then
          mark(#out > 1 and #out - 1 or 1)
          gap = false
        end
      end
      pos = math.max(pos, range[2] + 1)
    end
    if pos <= #str then gap = true end
  end
  if gap then mark(#out) end
  return table.concat(out), marks
end

local function word_ranges(words, budget)
  local count, shares, extra = #words, {}, budget
  if count == 0 or budget <= 0 then return {} end
  if count == 1 then return { { 1, math.min(budget, #words[1]) } } end
  for i = 1, count do shares[i] = 0 end
  local function give(i, amount)
    local add = math.min(amount, #words[i] - shares[i], extra)
    shares[i], extra = shares[i] + add, extra - add
  end
  if budget >= count * 3 then
    for i = 1, count do give(i, 3) end
  elseif budget < 6 then
    give(1, math.ceil(budget / 2))
    give(count, math.floor(budget / 2))
  else
    give(1, 3)
    give(count, 3)
    for i = 2, count - 1 do give(i, 3) end
  end
  -- Short words return their unused share to the remaining words.
  while extra > 0 and (shares[1] < #words[1] or shares[count] < #words[count]) do
    give(1, 1)
    give(count, 1)
  end
  while extra > 0 do
    local before = extra
    for i = 2, count - 1 do give(i, 1) end
    if extra == before then break end
  end
  local ranges, pos = {}, 1
  for i, word in ipairs(words) do
    if shares[i] > 0 then ranges[#ranges + 1] = { pos, pos + shares[i] - 1 } end
    pos = pos + #word
  end
  return ranges
end

-- Ranges index into `name .. sep`; the separator is the byte after the name.
local function folder_ranges(name, budget)
  local sep = { #name + 1, #name + 1 }
  if budget <= 0 then return {} end
  if budget == 1 then return { sep } end
  if budget < 5 then return { { 1, math.min(budget - 1, #name) }, sep } end
  if #name + 1 <= budget then return { { 1, #name + 1 } } end
  local ranges = word_ranges(split_words(name), budget - 1)
  ranges[#ranges + 1] = sep
  return ranges
end

local function base_ranges(base, budget)
  if budget <= 0 then return {} end
  if budget < 4 then return { { 1, math.min(budget, #base) } } end
  if #base <= budget then return { { 1, #base } } end
  return word_ranges(split_words(base), budget)
end

local function filename_ranges(filename, budget)
  if #filename <= budget then return { { 1, #filename } } end
  local base, ext = filename:match('^(.+)%.([^.]+)$')
  if not ext then return base_ranges(filename, budget) end
  if budget <= #ext + 5 then return base_ranges(base, budget) end
  -- Tight budgets drop the dot before the extension.
  local dot = budget <= #ext + 8 and 0 or 1
  local ranges = base_ranges(base, budget - #ext - dot)
  ranges[#ranges + 1] = { #base + 2 - dot, #filename }
  return ranges
end

local function shorten_words(words, budget)
  return (render({ { table.concat(words), word_ranges(words, budget) } }))
end

local function shorten_folder(name, budget, sep)
  return (render({ { name .. (sep or '/'), folder_ranges(name, budget) } }))
end

local function shorten_filename(filename, budget)
  return (render({ { filename, filename_ranges(filename, budget) } }))
end

local function clamp_slack(budgets, need)
  local freed = 0
  for i, b in ipairs(budgets) do
    if b > need[i] then
      freed = freed + b - need[i]
      budgets[i] = need[i]
    end
  end
  return freed
end

local function fill_leftover(budgets, need, extra)
  for i = #budgets, 1, -1 do
    local add = math.min(extra, need[i] - budgets[i])
    budgets[i], extra = budgets[i] + add, extra - add
  end
  return extra
end

local function distribute(budgets, need, extra)
  local file = #budgets
  local add = math.min(math.ceil(0.35 * extra), need[file] - budgets[file])
  budgets[file], extra = budgets[file] + add, extra - add
  local try_folder = math.ceil(0.5 * extra)
  for _ = 1, 2 do
    for i = file - 1, 1, -1 do
      add = math.min(try_folder, need[i] - budgets[i], extra)
      budgets[i], extra = budgets[i] + add, extra - add
      if extra == 0 then return end
    end
  end
  fill_leftover(budgets, need, extra)
end

local function legible(need, target)
  local n, budgets = #need - 1, {}
  for i = 1, n do budgets[i] = 0 end
  if n > 0 then
    budgets[1], budgets[n] = MIN_LEGIBLE_FOLDERS_BUDGET / 2, MIN_LEGIBLE_FOLDERS_BUDGET / 2
  end
  budgets[n + 1] = MIN_LEGIBLE_FILENAME_BUDGET
  clamp_slack(budgets, need)
  local sum = 0
  for _, b in ipairs(budgets) do sum = sum + b end
  local delta = target - sum
  local edges = n > 1 and { n, 1 } or n == 1 and { 1 } or {}
  if delta < 0 then
    while delta < 0 and n > 0 and (budgets[1] > 0 or budgets[n] > 0) do
      -- Reduction starts at the root; growth starts at the filename edge.
      for j = #edges, 1, -1 do
        local i = edges[j]
        if delta < 0 and budgets[i] > 0 then
          budgets[i], delta = budgets[i] - 1, delta + 1
        end
      end
    end
    budgets[n + 1] = budgets[n + 1] + delta
  elseif delta > 0 then
    local add = math.min(delta, math.min(need[n + 1], MIN_IDEAL_FILENAME_BUDGET) - budgets[n + 1])
    budgets[n + 1], delta = budgets[n + 1] + add, delta - add
    local function grow(indices)
      while delta > 0 do
        local before = delta
        for _, i in ipairs(indices) do
          if delta > 0 and budgets[i] < math.min(need[i], MIN_IDEAL_FOLDERNAME_BUDGET) then
            budgets[i], delta = budgets[i] + 1, delta - 1
          end
        end
        if before == delta then break end
      end
    end
    grow(edges)
    local centers = {}
    for i = n - 1, 2, -1 do centers[#centers + 1] = i end
    grow(centers)
    fill_leftover(budgets, need, delta)
  end
  return budgets
end

local function rebalance(budgets, need)
  local n, file = #budgets - 1, #budgets
  local function donor(floor)
    local best
    local function consider(i)
      if budgets[i] > math.min(floor, need[i]) and (not best or budgets[i] > budgets[best]) then
        best = i
      end
    end
    for i = 2, n - 1 do consider(i) end
    if best then return best end
    if n > 0 then
      consider(1)
      if n > 1 then consider(n) end
    end
    return best
  end
  local ready, total = true, 0
  for i = 1, n do
    total = total + budgets[i]
    if budgets[i] < math.min(3, need[i]) then ready = false end
  end
  if ready then
    while budgets[file] < math.min(need[file], 45) do
      local i = donor(3)
      if not i then break end
      budgets[i], budgets[file], total = budgets[i] - 1, budgets[file] + 1, total - 1
    end
  end
  -- Keep eight folder chars when trading below the legible floor.
  while total > 8 and budgets[file] < math.min(need[file], 25) do
    local i = donor(0)
    budgets[i], budgets[file], total = budgets[i] - 1, budgets[file] + 1, total - 1
  end
end

local function drop_single_slashes(budgets, need)
  local file, extra = #budgets, 0
  for i = 1, file - 1 do
    if budgets[i] == 1 then
      budgets[i], extra = 0, extra + 1
    end
  end
  local add = math.min(extra, need[file] - budgets[file])
  budgets[file], extra = budgets[file] + add, extra - add
  -- Only visible folders can reclaim separator-only shares.
  for i = file - 1, 1, -1 do
    if budgets[i] >= 2 then
      add = math.min(extra, need[i] - budgets[i])
      budgets[i], extra = budgets[i] + add, extra - add
    end
  end
end

-- Returns the shortened path and the sorted byte positions of its cut hints.
function M.shorten_marked(path, target)
  if target <= 0 then return '', {} end
  if #path <= target then return path, {} end
  local sep = path:match('[/\\]') or '/'
  local parts, need = {}, {}
  for part in path:gsub('\\', '/'):gmatch('[^/]+') do parts[#parts + 1] = part end
  if #parts == 0 then return '', {} end
  local n = #parts - 1
  for i, part in ipairs(parts) do need[i] = #part + (i <= n and 1 or 0) end
  local budgets
  if target < MAX_IDEAL_REDUCTION_BUDGET then
    budgets = legible(need, target)
  else
    budgets = {}
    for i = 1, n do budgets[i] = MIN_IDEAL_FOLDERNAME_BUDGET end
    budgets[n + 1] = MIN_IDEAL_FILENAME_BUDGET
    local min_ideal = n * MIN_IDEAL_FOLDERNAME_BUDGET + MIN_IDEAL_FILENAME_BUDGET
    local extra = target - min_ideal + clamp_slack(budgets, need)
    if extra >= 0 then
      distribute(budgets, need, extra)
    else
      local missing = -extra
      assert((n - 2) * MIN_IDEAL_FOLDERNAME_BUDGET >= missing, 'Insufficient center folder budget')
      while missing > 0 do
        for i = 2, n - 1 do
          if missing > 0 and budgets[i] > 0 then
            budgets[i], missing = budgets[i] - 1, missing - 1
          end
        end
      end
    end
  end
  rebalance(budgets, need)
  drop_single_slashes(budgets, need)
  local pieces = {}
  for i = 1, n do pieces[i] = { parts[i] .. sep, folder_ranges(parts[i], budgets[i]) } end
  pieces[n + 1] = { parts[n + 1], filename_ranges(parts[n + 1], budgets[n + 1]) }
  return render(pieces)
end

function M.shorten(path, target)
  return (M.shorten_marked(path, target))
end

M._split_words = split_words
M._shorten_words = shorten_words
M._shorten_folder = shorten_folder
M._shorten_filename = shorten_filename

return M
