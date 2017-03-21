install_date=$(date +%Y%m%d%H%M)
rm -f async.sh-*
rm -f pure.sh-*
curl -o async.sh-$install_date https://raw.githubusercontent.com/sindresorhus/pure/master/async.zsh
curl -o pure.sh-$install_date https://raw.githubusercontent.com/sindresorhus/pure/master/pure.zsh
chmod +x async.sh-$install_date
chmod +x pure.sh-$install_date
rm -f ./zfunctions/async
ln -s $PWD/async.sh-$install_date ./zfunctions/async
rm -f ./zfunctions/prompt_pure_setup
ln -s $PWD/pure.sh-$install_date ./zfunctions/prompt_pure_setup
