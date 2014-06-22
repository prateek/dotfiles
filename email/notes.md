# Steps Followed #

- Pretty much followed [1], except for the following changes - 

#DID NOT USE THIS IN THE END - Installed `mutt-kz` using `install.sh`
- Install using homebrew and this guy -
http://stackoverflow.com/questions/20883936/how-to-apply-this-mutt-sidebar-patch

- `mkdir -p ~/.mail`

- Generate SSL certs, via: [2]
```sh
# 1. Generate certs
$ export hostname="imap.gmail.com"
$ export cert_path="/Users/prungta/dotfiles/email/certificate"
$ export sslcacertfile=$cert_path/'gmail.cert'
$ openssl s_client -CApath $cert_path -connect ${hostname}:imaps -showcerts \
  | perl -ne 'print if /BEGIN/../END/; print STDERR if /return/' > $sslcacertfile
  ^D

# 2. Verfiy cert
$ openssl s_client -CAfile $sslcacertfile -connect ${hostname}:imaps 2>&1 </dev/null
```

## References ## 
[1] http://stevelosh.com/blog/2012/10/the-homely-mutt/
[2] http://docs.offlineimap.org/en/latest/FAQ.html?highlight=create%20certificate#how-do-i-generate-an-sslcacertfile-file
