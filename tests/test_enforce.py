import contextlib
import io
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'install'))
import aspects  # noqa: E402
import enforce  # noqa: E402
import fs  # noqa: E402


class Base(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.home = self.root / 'home'
        self.home.mkdir()
        self.local = self.root / 'local.lua'
        self.cfg = self.root / 'config.yml'
        self.cfg.write_text('csharp_lsp: false\n')
        self.patches = [
            mock.patch.object(fs, 'LOCAL_NVIM_TARGET', self.local),
            mock.patch.dict(os.environ, {'HOME': str(self.home)}),
            mock.patch.object(aspects.subprocess, 'run'),
            mock.patch.object(aspects.urllib.request, 'urlopen'),
        ]
        self.run_mock = self.patches[2].start()
        self.url_mock = self.patches[3].start()
        self.patches[0].start()
        self.patches[1].start()
        self.agentic = {}
        import agentic
        for n in ('sync_claude', 'sync_codex', 'sync_shell'):
            p = mock.patch.object(agentic, n, create=True, return_value=False)
            self.agentic[n] = p.start()
            self.patches.append(p)

    def tearDown(self):
        mock.patch.stopall()
        self.temp.cleanup()

    def run_main(self, *argv, config=True):
        args = list(argv)
        if config:
            args += ['--config', str(self.cfg)]
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            try:
                code = enforce.main(args)
            except SystemExit as e:
                code = e.code
        return code, out.getvalue(), err.getvalue()

    def files(self):
        return sorted(str(p.relative_to(self.home)) for p in self.home.rglob('*'))


class ResolveTests(unittest.TestCase):
    def labels(self, sel, skip, ctx='linux'):
        run, na = aspects.resolve(sel, skip, ctx)
        return [a.label for a in run], na

    def test_registry_order(self):
        self.assertEqual(aspects.LABELS, [
            'vim-config', 'nvim-config', 'nvim-local', 'git-config', 'git-templates',
            'vim-plugins', 'nvim-plugins', 'agentic-claude', 'agentic-codex',
            'agentic-shell', 'win-env'])

    def test_all_drops_win_env_on_linux(self):
        run, na = self.labels([], [])
        self.assertNotIn('win-env', run)
        self.assertEqual(na, [])
        self.assertIn('win-env', self.labels(['all'], [], 'windows')[0])

    def test_group_and_label(self):
        self.assertEqual(self.labels(['agentic'], [])[0],
                         ['agentic-claude', 'agentic-codex', 'agentic-shell'])
        self.assertEqual(self.labels(['nvim-local', 'vim'], [])[0],
                         ['vim-config', 'nvim-local', 'vim-plugins'])

    def test_skip(self):
        run, _ = self.labels(['all'], ['agentic', 'git-config'])
        self.assertNotIn('agentic-codex', run)
        self.assertNotIn('git-config', run)
        self.assertIn('git-templates', run)

    def test_unknown(self):
        with self.assertRaises(ValueError) as cm:
            aspects.resolve(['bogus'], [], 'linux')
        self.assertIn('vim-config', str(cm.exception))
        self.assertIn('agentic', str(cm.exception))

    def test_not_applicable_explicit(self):
        run, na = self.labels(['win-env'], [], 'wsl')
        self.assertEqual((run, na), ([], ['win-env']))

    def test_detect_os(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        pv = Path(tmp.name) / 'version'
        pv.write_text('Linux version 5 Microsoft-standard')
        with mock.patch.object(aspects.os, 'name', 'posix'), \
                mock.patch.object(aspects.sys, 'platform', 'linux'):
            self.assertEqual(aspects.detect_os(proc_version=pv), 'wsl')
            pv.write_text('Linux version 6 generic')
            self.assertEqual(aspects.detect_os(proc_version=pv), 'linux')
            self.assertEqual(aspects.detect_os(proc_version=pv.parent / 'nope'), 'linux')
        with mock.patch.object(aspects.sys, 'platform', 'darwin'), \
                mock.patch.object(aspects.os, 'name', 'posix'):
            self.assertEqual(aspects.detect_os(), 'mac')
        with mock.patch.object(aspects.os, 'name', 'nt'):
            self.assertEqual(aspects.detect_os(), 'windows')
        self.assertEqual(aspects.detect_os('wsl'), 'wsl')
        self.assertEqual(aspects.os_family('wsl'), 'linux')
        with self.assertRaises(ValueError):
            aspects.detect_os('beos')


class EnforceTests(Base):
    def test_unknown_label_errors(self):
        code, _, err = self.run_main('nope', '--os', 'linux')
        self.assertEqual(code, 2)
        self.assertIn('valid labels', err)

    def test_only_removed(self):
        code, _, err = self.run_main('--only', 'linux', '--os', 'linux')
        self.assertEqual(code, 2)
        self.assertIn('removed', err)

    def test_legacy_flags(self):
        code, out, err = self.run_main('--vim-only', '--dry-run', '--os', 'linux')
        self.assertEqual(code, 0)
        self.assertIn('deprecated', err)
        self.assertIn('-- vim-config --', out)
        self.assertIn('-- nvim-local --', out)
        self.assertNotIn('-- git-config --', out)
        self.assertNotIn('agentic', out)
        _, out, err = self.run_main('--agentic-only', '--dry-run', '--os', 'linux')
        self.assertIn('-- agentic-codex --', out)
        self.assertNotIn('vim-config', out)

    def test_config_skip_vs_cli(self):
        self.cfg.write_text('homes:\n  - os: linux\n    path: "~"\n    skip: [git, agentic]\n'
                            '  - os: windows\n    path: /mnt/c/x\n')
        _, out, _ = self.run_main('--dry-run', '--os', 'wsl')
        self.assertNotIn('git-config', out)
        self.assertNotIn('agentic-', out)
        self.assertIn('-- vim-config --', out)
        _, out, _ = self.run_main('agentic', '--dry-run', '--os', 'wsl')
        self.assertIn('-- agentic-claude --', out)
        self.assertNotIn('vim-config', out)

    def test_legacy_config_only_vim(self):
        self.cfg.write_text('homes:\n  - os: linux\n    path: "~"\n    only_vim: true\n')
        _, out, err = self.run_main('--dry-run', '--os', 'linux')
        self.assertIn('only_vim', err)
        self.assertNotIn('git-config', out)
        self.assertNotIn('agentic-', out)
        self.cfg.write_text('homes:\n  - os: linux\n    path: "~"\n    agentic: false\n')
        _, out, err = self.run_main('--dry-run', '--os', 'linux')
        self.assertIn('agentic: false', err)
        self.assertNotIn('agentic-', out)
        self.assertIn('git-config', out)

    def test_missing_config_defaults(self):
        code, out, _ = self.run_main('git-config', '--dry-run', '--os', 'linux',
                                     '--config', str(self.root / 'none.yml'), config=False)
        self.assertEqual(code, 0)
        self.assertIn(str(self.home), out)

    def test_not_applicable_notice(self):
        code, out, _ = self.run_main('win-env', '--os', 'wsl')
        self.assertEqual(code, 0)
        self.assertIn('not applicable on wsl', out)
        self.run_mock.assert_not_called()

    def test_check_exit_codes(self):
        sel = ['vim-config', 'nvim-config', 'nvim-local', 'git-config', 'git-templates']
        code, _, _ = self.run_main(*sel, '--check', '--os', 'linux')
        self.assertEqual(code, 1)
        self.assertEqual(self.files(), [])
        code, _, _ = self.run_main(*sel, '--os', 'linux')
        self.assertEqual(code, 0)
        self.assertTrue((self.home / '.vimrc').is_symlink())
        code, _, _ = self.run_main(*sel, '--check', '--os', 'linux')
        self.assertEqual(code, 0)
        code, out, _ = self.run_main(*sel, '--os', 'linux')
        self.assertNotIn('symlink', out)
        self.assertEqual(code, 0)

    def test_git_config_alone(self):
        self.run_main('git-config', '--os', 'linux')
        self.assertEqual(self.files(), ['.gitconfig'])
        self.assertFalse(self.local.exists())

    def test_nvim_local_alone(self):
        self.run_main('nvim-local', '--os', 'linux')
        self.assertEqual(self.files(), [])
        self.assertIn('csharp_lsp = false', self.local.read_text())

    def test_vim_config_only_its_files(self):
        self.run_main('vim-config', '--os', 'linux')
        self.assertEqual(self.files(), ['.vim', '.vim/backup', '.vim/syntax',
                                        '.vim/syntax/html', '.vim/tmp', '.vimrc'])

    def test_windows_copies(self):
        self.run_main('vim-config', '--os', 'windows')
        self.assertTrue((self.home / '_vimrc').is_file())
        self.assertFalse((self.home / '_vimrc').is_symlink())

    def test_agentic_labels_call_own_function(self):
        self.agentic['sync_codex'].return_value = True
        code, out, _ = self.run_main('agentic-codex', '--os', 'wsl')
        self.agentic['sync_codex'].assert_called_once_with(self.home, 'linux', {}, False)
        self.agentic['sync_claude'].assert_not_called()
        self.assertIn('changed', out)
        code, _, _ = self.run_main('agentic-codex', '--check', '--os', 'linux')
        self.assertEqual(code, 1)

    def test_plugins_dry_run_print_only(self):
        code, out, _ = self.run_main('vim-plugins', 'nvim-plugins', '--dry-run',
                                     '--os', 'linux')
        self.assertEqual(code, 0)
        self.assertIn('vim +PlugInstall +qall', out)
        self.assertIn('nvim --headless +Lazy! sync +qa', out)
        self.run_mock.assert_not_called()
        self.url_mock.assert_not_called()
        self.assertEqual(self.files(), [])

    def test_plugins_real_run_mocked(self):
        self.url_mock.return_value.__enter__.return_value.read.return_value = b'x'
        self.run_mock.return_value.returncode = 0
        with mock.patch.object(aspects.shutil, 'which', return_value='/usr/bin/x'):
            code, _, _ = self.run_main('vim-plugins', 'nvim-plugins', '--os', 'linux')
        self.assertEqual(code, 0)
        self.assertEqual((self.home / '.vim/autoload/plug.vim').read_bytes(), b'x')
        self.assertEqual(self.run_mock.call_count, 2)

    def test_plugin_missing_binary_skipped_and_download_failure_failed(self):
        self.url_mock.side_effect = OSError('offline')
        with mock.patch.object(aspects.shutil, 'which', return_value=None):
            code, out, _ = self.run_main('vim-plugins', 'nvim-plugins', '--os', 'linux')
        self.assertEqual(code, 1)
        self.assertIn('vim-plugins     failed', out)
        self.assertIn('nvim-plugins    skipped', out)
        self.run_mock.assert_not_called()

    def test_win_env_command(self):
        with mock.patch.object(aspects.shutil, 'which', return_value='x'):
            code, out, _ = self.run_main('win-env', '--dry-run', '--os', 'windows')
        self.assertIn('windows_env.ps1 -UserProfile', out)
        self.run_mock.assert_not_called()

    def test_list(self):
        code, out, _ = self.run_main('--list', '--os', 'wsl')
        self.assertEqual(code, 0)
        self.assertIn('win-env', out)
        self.assertIn('not applicable on wsl', out)


if __name__ == '__main__':
    unittest.main()
