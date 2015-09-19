mkdir -p ~/.vim/
mkdir -p ~/.vim/backup
mkdir -p ~/.vim/tmp
mkdir -p ~/.vim/skeletons
mkdir -p ~/.vim/bundle
mkdir -p ~/.vim/syntax
cp -rf ./vim/skeletons/* ~/.vim/skeletons
cp -rf ./vim/syntax/* ~/.vim/syntax
cp ./vimrc ~/.vimrc
cp ./gitconfig ~/.gitconfig

# Installing the plugins
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
vim +PluginInstall +qall
