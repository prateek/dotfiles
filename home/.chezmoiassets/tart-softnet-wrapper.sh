#!/bin/sh
# tart wrapper: add softnet LAN isolation to runner-guest `tart run`.
#
# Tartelet drives `tart run` at /opt/homebrew/bin/tart and has no way to pass
# networking flags, so this wrapper owns that path and inserts --net-softnet unless
# the caller already chose a --net-* mode. Guests then reach the internet through
# the vmnet gateway but not the homelab LAN. softnet needs a passwordless-sudo grant
# (see the runner runbook). Laid down by run_after_18-tartelet-tart-softnet-wrapper.
real="/opt/homebrew/opt/tart/bin/tart"

# tart finds `softnet` by name on PATH; a LaunchAgent's PATH omits the brew bin dir.
PATH="${real%/opt/tart/bin/tart}/bin:$PATH"
export PATH

if [ "$1" = "run" ]; then
    shift
    case " $* " in
        *" --net-"*) exec "$real" run "$@" ;;
        *) exec "$real" run --net-softnet "$@" ;;
    esac
fi

exec "$real" "$@"
