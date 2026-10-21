load '../../support/common'

setup() {
  setup_fixture
  libexec="$DOTFILES_ROOT/home/dot_local/libexec/thaw"
}

launchctl_list() {
  printf '#!/bin/sh\nprintf "PID\\tStatus\\tLabel\\n%s"\n' "$1" >"$FIXTURE/bin/launchctl"
  chmod +x "$FIXTURE/bin/launchctl"
}

memory_pressure_level() {
  printf '#!/bin/sh\necho %s\n' "$1" >"$FIXTURE/bin/sysctl"
  chmod +x "$FIXTURE/bin/sysctl"
}

@test "a stopped com.prateek agent with a failed last run reveals Launchd Monitor" {
  launchctl_list '-\t7\tcom.prateek.wiki-sessions-sync\n-\t0\tcom.prateek.gui-corp-ca\n'
  run_bash 0 "$libexec/executable_launchd-jobs-failing"
}

@test "running agents, clean exits, and other labels keep Launchd Monitor hidden" {
  launchctl_list '34496\t1\tcom.prateek.devbox-orca-tunnel\n-\t0\tcom.prateek.gui-corp-ca\n-\t78\tcom.apple.example\n'
  run_bash 1 "$libexec/executable_launchd-jobs-failing"
}

@test "warning and critical memory pressure reveal iStat memory" {
  memory_pressure_level 2
  run_bash 0 "$libexec/executable_memory-pressure-high"
  memory_pressure_level 4
  run_bash 0 "$libexec/executable_memory-pressure-high"
}

@test "normal memory pressure keeps iStat memory hidden" {
  memory_pressure_level 1
  run_bash 1 "$libexec/executable_memory-pressure-high"
}
