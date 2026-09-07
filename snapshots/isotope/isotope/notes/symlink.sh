cd ~

cd "$HOME"

ln -sfnT "$HOME/repos-$HOSTNAME/github" "$HOME/GitHub"
ln -sfnT "$HOME/Dropbox/_mm"       "$HOME/Mathematica_files"


dantopa@isotope:~$ ls -ld ~/GitHub ~/Mathematica_files
readlink -f ~/GitHub
readlink -f ~/Mathematica_files
lrwxrwxrwx 1 dantopa dantopa 34 Aug 30 00:26 /home/dantopa/GitHub -> /home/dantopa/repos-isotope/github
lrwxrwxrwx 1 dantopa dantopa 26 Aug 30 00:26 /home/dantopa/Mathematica_files -> /mnt/T7-Shield/Dropbox/_mm
/home/dantopa/repos-isotope/github


