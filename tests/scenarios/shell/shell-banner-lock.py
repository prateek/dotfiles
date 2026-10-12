"""Inject a scheduling pause after stale-lock inspection, before reclamation."""
import os
from pathlib import Path
import select
import subprocess

fixture = Path(os.environ['FIXTURE'])
lock = fixture / 'refresh.lock'
lock.mkdir()
(lock / 'owner.pid').write_text('999999\n')
(lock / 'started_at').write_text('1\n')
(lock / 'owner.token').write_text('stale\n')
script = r'''
source "$1"
zmodload zsh/stat
if [[ "$3" == A ]]; then
  zstat() {
    builtin zstat "$@"
    print -r -- inspected
    read -r release
    [[ "$release" == release ]]
  }
fi
banner_acquire_lock "$2" 2000000000 "$3"
print -r -- "result=$?"
'''
library = Path(os.environ['DOTFILES_ROOT']) / 'home/dot_config/dotfiles/shell-banner/lib/cache.sh'
command = [os.environ['TEST_ZSH'], '-f', '-c', script, '_', str(library), str(lock)]
first = subprocess.Popen(command + ['A'], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE, text=True)
try:
    assert select.select([first.stdout], [], [], 5)[0], 'first contender did not inspect the lock'
    assert first.stdout.readline().strip() == 'inspected'
    second = subprocess.run(command + ['B'], capture_output=True, text=True, timeout=5, check=True)
    out, err = first.communicate('release\n', timeout=5)
    assert first.returncode == 0 and not err, (first.returncode, err)
    assert not second.stderr, second.stderr
    winners = [name for name, result in [('A', out), ('B', second.stdout)] if 'result=0' in result]
    assert len(winners) == 1, f'multiple refresh owners: {winners}'
    assert (lock / 'owner.token').read_text().strip() == winners[0]
finally:
    if first.poll() is None:
        first.kill()
        first.communicate(timeout=5)
print('one refresh owner')
