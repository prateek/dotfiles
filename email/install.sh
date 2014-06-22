#!/bin/sh

# Adapted from: https://github.com/mattly/dotfiles-email/blob/master/bork_setup.sh
# TODO: actually start using Bork/Puppet/Chef for this sht

brew install notmuch
brew install sqlite
brew install offline-imap
brew install contacts
brew install urlview
brew install msmtp
brew install lynx
brew install gnupg
brew install gpgme

install_mutt () {
  name="mutt-kz"
  version="1.5.22"
  github_loc="karelzak/mutt-kz"
  git_ref="master"
  cd $(mktemp -d -t mutt)
  hub clone "$github_loc"
  cd mutt-kz
  prefix=$(command brew diy --set-version $version)
  ./prepare
  ./configure $prefix --enable-notmuch
  make
  make install
  brew link mutt-kz
}
install_mutt
