import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'install'))
import agentic  # noqa: E402


LINE = ('status_line = ["model-with-reasoning", "context-used", "five-hour-limit", '
        '"weekly-limit", "current-dir", "thread-name"]')


class AgenticTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.source = self.root / 'source'
        (self.source / 'claude').mkdir(parents=True)
        (self.source / 'codex').mkdir()
        (self.source / 'shell').mkdir()
        (self.source / 'claude' / 'statusline.py').write_text('print("ok")\n')
        (self.source / 'claude' / 'settings.managed.json').write_text(
            '{"model": "opusplan", "effortLevel": "medium"}\n')
        (self.source / 'codex' / 'status_line.txt').write_text(LINE + '\n')
        for name in ('aliases.sh', 'aliases.ps1', 'ralph-loop.cmd', 'rloop.cmd'):
            (self.source / 'shell' / name).write_text(name + '\n')
        self.original_source = agentic.AGENTIC_SRC
        agentic.AGENTIC_SRC = self.source

    def tearDown(self):
        agentic.AGENTIC_SRC = self.original_source
        self.temp.cleanup()

    def test_merge_preserves_unrelated_order_and_is_idempotent(self):
        path = self.root / 'settings.json'
        path.write_text('{\n  "before": true,\n  "model": "old",\n  "after": 3\n}\n')
        desired = {'model': 'opusplan', 'effortLevel': 'medium'}
        self.assertTrue(agentic.merge_claude_settings(path, desired, False))
        parsed = json.loads(path.read_text())
        self.assertEqual(list(parsed), ['before', 'model', 'after', 'effortLevel'])
        self.assertEqual(parsed['before'], True)
        self.assertEqual(parsed['after'], 3)
        self.assertFalse(agentic.merge_claude_settings(path, desired, False))
        self.assertEqual(len(list(self.root.glob('settings.json_*.bkp'))), 1)

    def test_merge_makes_copy_backup_on_change(self):
        path = self.root / 'settings.json'
        old = '{"keep": 1}\n'
        path.write_text(old)
        agentic.merge_claude_settings(path, {'model': 'opusplan'}, False)
        backups = list(self.root.glob('settings.json_*.bkp'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), old)

    def test_codex_upsert_existing_line(self):
        path = self.root / 'config.toml'
        path.write_text('[tui]\nstatus_line = ["old"]\nother = true\n[foo]\nx = 1\n')
        self.assertTrue(agentic.upsert_codex_status_line(path, LINE, False))
        self.assertEqual(path.read_text(), f'[tui]\n{LINE}\nother = true\n[foo]\nx = 1\n')

    def test_codex_upsert_tui_without_line(self):
        path = self.root / 'config.toml'
        path.write_text('[tui]\nother = true\n[foo]\nx = 1\n')
        agentic.upsert_codex_status_line(path, LINE, False)
        self.assertEqual(path.read_text(), f'[tui]\nother = true\n{LINE}\n[foo]\nx = 1\n')

    def test_codex_upsert_without_tui(self):
        path = self.root / 'config.toml'
        path.write_text('[foo]\nx = 1\n')
        agentic.upsert_codex_status_line(path, LINE, False)
        self.assertEqual(path.read_text(), f'[foo]\nx = 1\n\n[tui]\n{LINE}\n')

    def test_marker_block_insert_replace_and_idempotence(self):
        path = self.root / 'profile'
        path.write_text('export OLD=1\n')
        self.assertTrue(agentic.upsert_marker_block(path, 'agentic', 'source one', False))
        self.assertIn('# >>> agentic >>>\nsource one\n# <<< agentic <<<', path.read_text())
        self.assertTrue(agentic.upsert_marker_block(path, 'agentic', 'source two', False))
        self.assertNotIn('source one', path.read_text())
        self.assertFalse(agentic.upsert_marker_block(path, 'agentic', 'source two', False))
        self.assertEqual(path.read_text().count('# >>> agentic >>>'), 1)

    def test_to_windows_path(self):
        self.assertEqual(agentic.to_windows_path('/mnt/c/Users/Ada'), 'C:/Users/Ada')
        self.assertEqual(agentic.to_windows_path('/mnt/Z/a/b'), 'Z:/a/b')
        self.assertEqual(agentic.to_windows_path(r'c:\Users\Ada'), 'C:/Users/Ada')
        self.assertEqual(agentic.to_windows_path('D:/Users/Ada'), 'D:/Users/Ada')

    def test_sync_linux_end_to_end_and_skips_missing_codex(self):
        home = self.root / 'linux-home'
        home.mkdir()
        (home / '.zshrc').write_text('# zsh\n')
        self.assertTrue(agentic.sync_agentic(home, 'linux', {}, False))
        self.assertTrue((home / '.claude' / 'statusline.py').is_file())
        self.assertTrue((home / '.claude' / 'agentic' / 'shell' / 'aliases.sh').is_file())
        settings = json.loads((home / '.claude' / 'settings.json').read_text())
        self.assertEqual(settings['model'], 'opusplan')
        self.assertEqual(settings['statusLine']['command'], f'python3 "{home}/.claude/statusline.py"')
        self.assertFalse((home / '.bashrc').exists())
        self.assertIn('aliases.sh', (home / '.zshrc').read_text())
        self.assertFalse((home / '.codex').exists())
        before = (home / '.claude' / 'settings.json').read_text()
        self.assertFalse(agentic.sync_agentic(home, 'linux', {}, False))
        self.assertEqual((home / '.claude' / 'settings.json').read_text(), before)
        self.assertEqual(list((home / '.claude').glob('settings.json_*.bkp')), [])

    def test_sync_windows_derives_path_without_windows_override(self):
        home = self.root / 'windows-home'
        home.mkdir()
        agentic.sync_agentic(home, 'windows', {}, False)
        settings = json.loads((home / '.claude' / 'settings.json').read_text())
        self.assertEqual(settings['statusLine']['command'],
                         f'python "{agentic.to_windows_path(home)}/.claude/statusline.py"')
        profile = home / 'Documents' / 'PowerShell' / 'Microsoft.PowerShell_profile.ps1'
        self.assertIn(
            f'Test-Path "{agentic.to_windows_path(home)}/.claude/agentic/shell/aliases.ps1"',
            profile.read_text())
        self.assertTrue((home / '.claude' / 'bin' / 'ralph-loop.cmd').is_file())

    def test_split_syncs_touch_only_their_own_files_and_are_idempotent(self):
        claude_home = self.root / 'claude-home'
        claude_home.mkdir()
        self.assertTrue(agentic.sync_claude(claude_home, 'linux', {}, False))
        self.assertTrue((claude_home / '.claude' / 'statusline.py').is_file())
        self.assertTrue((claude_home / '.claude' / 'settings.json').is_file())
        self.assertFalse((claude_home / '.claude' / 'agentic').exists())
        self.assertFalse((claude_home / '.bashrc').exists())
        self.assertFalse(agentic.sync_claude(claude_home, 'linux', {}, False))

        codex_home = self.root / 'codex-home'
        (codex_home / '.codex').mkdir(parents=True)
        self.assertTrue(agentic.sync_codex(codex_home, 'linux', {}, False))
        self.assertTrue((codex_home / '.codex' / 'config.toml').is_file())
        self.assertFalse((codex_home / '.claude').exists())
        self.assertFalse(agentic.sync_codex(codex_home, 'linux', {}, False))

        shell_home = self.root / 'shell-home'
        shell_home.mkdir()
        self.assertTrue(agentic.sync_shell(shell_home, 'linux', {}, False))
        self.assertTrue((shell_home / '.claude' / 'agentic' / 'shell' / 'aliases.sh').is_file())
        self.assertTrue((shell_home / '.bashrc').is_file())
        self.assertFalse((shell_home / '.claude' / 'statusline.py').exists())
        self.assertFalse(agentic.sync_shell(shell_home, 'linux', {}, False))

    def test_dry_run_touches_nothing(self):
        home = self.root / 'dry-home'
        home.mkdir()
        agentic.sync_agentic(home, 'linux', {}, True)
        self.assertEqual(list(home.iterdir()), [])


if __name__ == '__main__':
    unittest.main()
