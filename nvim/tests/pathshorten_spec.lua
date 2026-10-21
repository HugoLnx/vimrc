local script = debug.getinfo(1, 'S').source:sub(2):gsub('\\', '/')
local root = script:match('^(.*)/tests/[^/]+$') or 'nvim'
package.path = root .. '/lua/?.lua;' .. root .. '/lua/?/init.lua;' .. package.path

local checks = 0
local failures = {}
local function equal(actual, expected)
  checks = checks + 1
  if actual ~= expected then
    failures[#failures + 1] = string.format('Expected %q, got %q', expected, actual)
  end
end

local function run()
  -- Loading and running the core must also work without Neovim globals.
  local editor = vim
  local load_core = assert(loadfile(root .. '/lua/user/pathshorten.lua'))
  vim = nil
  local shorten = load_core()
  equal(shorten.shorten('filename', 3), 'fil')
  vim = editor

  equal(table.concat(shorten._split_words('IArenaPlayerCoreGPT'), '|'), 'IArena|Player|Core|GPT')
  equal(table.concat(shorten._split_words('arena_player_core_gpt'), '|'), 'arena|_player|_core|_gpt')
  equal(table.concat(shorten._split_words('IOStream'), '|'), 'IO|Stream')
  equal(table.concat(shorten._split_words('IArena'), '|'), 'IArena')
  equal(table.concat(shorten._split_words('foo12Bar__core-GPT'), '|'), 'foo12|Bar|__core|-GPT')
  equal(shorten._shorten_words({ 'Alpha', 'Middle', 'Omega' }, 12), 'AlphaMidOmeg')
  equal(shorten._shorten_words({ 'a', 'Middle', 'z' }, 6), 'aMiddz')
  equal(shorten._shorten_words({ 'a', 'LongWord' }, 5), 'aLong')
  equal(shorten._shorten_words({ 'Alpha', 'Middle', 'Omega' }, 7), 'AlpMOme')
  equal(shorten._shorten_folder('FolderName', 0), '')
  equal(shorten._shorten_folder('FolderName', 1), '/')
  equal(shorten._shorten_folder('FolderName', 4), 'Fol/')
  equal(shorten._shorten_folder('FolderName', 1, '\\'), '\\')
  equal(shorten._shorten_folder('FolderName', 4, '\\'), 'Fol\\')
  equal(shorten._shorten_folder('FolderName', 11, '\\'), 'FolderName\\')

  local example = 'Assets/Scripts/Gameplay/Arena/IArenaPlayerCoreGPT.cs'
  equal(shorten.shorten(example, 30), 'As/Aren/IArenaPlayerCoreGPT.cs')
  equal(#shorten.shorten(example, 30), 30)
  equal(shorten.shorten(example, 0), '')
  equal(shorten.shorten(example, -1), '')
  -- Legible reduction, distribution, and the single-edge cases.
  equal(shorten.shorten('FirstFolder/LastFolder/LongFilename', 8), 'LongFile')
  equal(shorten.shorten('FirstFolder/LastFolder/LongFilename', 20), 'Fir/Las/LongFilename')
  equal(shorten.shorten('FirstFolder/LongFilename', 8), 'F/LonFil')
  equal(shorten.shorten('FirstFolder/LongFilename', 20), 'FirsFol/LongFilename')
  equal(shorten.shorten('LongFilename', 5), 'LonFi')
  equal(shorten.shorten('a/b/LongFilename', 12), 'a/b/LongFile')
  -- Exact ideal, ideal distribution, and reclaimed slack during reduction.
  equal(shorten.shorten(example, 39), 'Asse/Sc/Ga/Arena/IArenaPlayerCoreGPT.cs')
  equal(shorten.shorten('FirstFolder/LastFolder/LongFilename', 28), 'FirsFol/LastFol/LongFilename')
  equal(shorten.shorten('a/b/c/d/VeryLongFilenameForTesting.cs', 25), 'a/b/c/d/VerLonFilFoTes.cs')

  local filename = 'abcdefghijklmno.cs'
  equal(shorten._shorten_filename(filename, 7), 'abcdefg')
  equal(shorten._shorten_filename(filename, 8), 'abcdefcs')
  equal(shorten._shorten_filename(filename, 10), 'abcdefghcs')
  equal(shorten._shorten_filename(filename, 11), 'abcdefgh.cs')
  equal(shorten._shorten_filename('.gitignore', 7), '.gitign')
  equal(shorten._shorten_filename('extensionless', 7), 'extensi')
  equal(shorten._shorten_filename('archive.tar.gz', 11), 'arch.tar.gz')
  equal(shorten.shorten('Assets\\Scripts\\Gameplay\\Arena\\IArenaPlayerCoreGPT.cs', 30),
    'As\\Aren\\IArenaPlayerCoreGPT.cs')
  equal(shorten.shorten('a\\b.cs', 20), 'a\\b.cs')
  equal(shorten.shorten('//Assets///Scripts//LongFilename.cs', 18), 'As/Sc/LongFilen.cs')
  equal(shorten.shorten('C:\\Users/xyz\\Projects\\Some/DeepFolder\\LongFileName.cs', 18),
    'C:\\Dee\\LonFiNam.cs')
  -- Tier B moves 21,22,27 to 12,13,45 and stops at the filename cap.
  equal(shorten.shorten(string.rep('a', 30) .. '/' .. string.rep('b', 30) .. '/' .. string.rep('c', 60), 70),
    string.rep('a', 11) .. '/' .. string.rep('b', 12) .. '/' .. string.rep('c', 45))
  local deep = {}
  for i = 1, 8 do deep[i] = string.rep(string.char(96 + i), 12) end
  deep[9] = string.rep('z', 60)
  -- Tier A drains centres 2,2,2,2,3,3, leaving edges 7,7 and filename 25.
  equal(shorten.shorten(table.concat(deep, '/'), 39), 'aaaaaa/hhhhhh/' .. string.rep('z', 25))
  -- A full filename and no visible folders leave the freed shares unused.
  equal(shorten.shorten('aaaa/bbbb/x', 3), 'x')

  local seed = 1729
  local function random(limit)
    seed = (seed * 48271) % 2147483647
    return seed % limit + 1
  end
  local names = {
    'a', 'xy', 'Assets', 'Scripts', 'IArenaPlayerCoreGPT', 'arena_player_core_gpt',
    'IOStream', 'LongFilename', 'foo12Bar', '__core', '012345', '.hidden', '---',
  }
  for sample = 1, 300 do
    local parts = {}
    for i = 1, random(9) do parts[i] = names[random(#names)] end
    local extensions = { '', '.cs', '.longextension', '.tar.gz' }
    parts[#parts] = parts[#parts] .. extensions[random(#extensions)]
    local separator = sample % 2 == 0 and '\\' or '/'
    local path = table.concat(parts, separator)
    if sample % 7 == 0 then path = separator .. separator .. path .. separator end
    for target = 1, 90 do
      local ok, out = pcall(shorten.shorten, path, target)
      assert(ok, string.format('%q at %d: %s', path, target, out))
      assert(#out <= target, string.format('%q at %d produced %q (%d)', path, target, out, #out))
      if #path <= target then
        equal(out, path)
      else
        assert(not out:match('^[/\\]'), string.format('%q at %d starts with a separator: %q', path, target, out))
        for _, pair in ipairs({ '//', '\\\\', '/\\', '\\/' }) do
          assert(not out:find(pair, 1, true), string.format('%q at %d doubled separators: %q', path, target, out))
        end
        local sep = path:match('[/\\]') or '/'
        local other = sep == '/' and '\\' or '/'
        assert(not out:find(other, 1, true), string.format('%q at %d changed separator: %q', path, target, out))
        checks = checks + 6
      end
      checks = checks + 2
    end
  end
  assert(#failures == 0, table.concat(failures, '\n'))
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
  io.stderr:write(err .. '\n')
  os.exit(1)
end
print(string.format('pathshorten_spec: %d checks passed', checks))
