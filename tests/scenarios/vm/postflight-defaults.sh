#!/bin/sh
set -eu

case "$*" in
  "read -g KeyRepeat")
    printf '1\n'
    ;;
  "read -g InitialKeyRepeat")
    printf '12\n'
    ;;
  "read -g AppleShowAllExtensions")
    printf '1\n'
    ;;
  "read com.apple.finder AppleShowAllFiles")
    printf '%s\n' "${DOTFILES_TEST_FINDER_SHOW_HIDDEN:-1}"
    ;;
  "read com.apple.finder ShowPathbar")
    printf '1\n'
    ;;
  "read com.apple.dock autohide")
    printf '1\n'
    ;;
  "read com.prakashjoshipax.VoiceInk CurrentTranscriptionModel") printf 'parakeet-tdt-0.6b-v3\n' ;;
  "read com.prakashjoshipax.VoiceInk IsMenuBarOnly")         printf '1\n' ;;
  "read io.tailscale.ipn.macsys HideDockIcon")               printf '1\n' ;;
  "read io.tailscale.ipn.macsys TailscaleStartOnLogin")      printf '1\n' ;;
  "read com.manytricks.Moom Application Mode")               printf '2\n' ;;
  "read dev.kdrag0n.MacVirt global_showMenubarExtra")        printf '1\n' ;;
  "read com.cmuxterm.app appearanceMode")                    printf 'system\n' ;;
  "read com.hegenberg.BetterTouchTool BTTDisabledLegacyUI")  printf '1\n' ;;
  "read com.raycast.macos navigationCommandStyleIdentifierKey") printf 'vim\n' ;;
  "read com.setapp.DesktopClient EnableLauncher")            printf '0\n' ;;
  "read net.elasticthreads.nv DefaultEEIdentifier")          printf 'com.microsoft.VSCode\n' ;;
  "read pro.betterdisplay.BetterDisplay SUAutomaticallyUpdate") printf '1\n' ;;
  "read com.stonerl.Thaw SectionDividerStyle")               printf '1\n' ;;
  "read com.stonerl.Thaw SUEnableAutomaticChecks")           printf '1\n' ;;
  *)
    printf 'unexpected defaults invocation: %s\n' "$*" >&2
    exit 1
    ;;
esac
