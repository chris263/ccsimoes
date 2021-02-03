sudo apt-get install git
mkdir ~/cxgn
git clone https://github.com/solgenomics/sgn ~/cxgn/sgn/
git clone https://github.com/solgenomics/Barcode-code128 ~/cxgn/Barcode-code128/
git clone https://github.com/solgenomics/Cview ~/cxgn/Cview/
git clone https://github.com/solgenomics/ITAG ~/cxgn/ITAG/
git clone https://github.com/solgenomics/Phenome ~/cxgn/Phenome/
git clone https://github.com/solgenomics/R_libs ~/cxgn/R_libs/
git clone https://github.com/solgenomics/Tea ~/cxgn/Tea/
git clone https://github.com/solgenomics/VIGS ~/cxgn/VIGS/
git clone https://github.com/solgenomics/biosource ~/cxgn/biosource/
git clone https://github.com/solgenomics/breedbase_portuguese ~/cxgn/breedbase_portuguese/
git clone https://github.com/solgenomics/cassava ~/cxgn/cassava/
git clone https://github.com/solgenomics/cea ~/cxgn/cea/
git clone https://github.com/solgenomics/cxgn-corelibs ~/cxgn/cxgn-corelibs/
git clone https://github.com/solgenomics/perl-local-lib ~/cxgn/local-lib/
git clone https://github.com/solgenomics/sweetpotatobase ~/cxgn/sweetpotatobase/
git clone https://github.com/solgenomics/sgn-devtools ~/cxgn/sgn-devtools/
git clone https://github.com/solgenomics/solGS ~/cxgn/solGS/
git clone https://github.com/solgenomics/starmachine ~/cxgn/starmachine/
git clone https://github.com/solgenomics/tomato_genome ~/cxgn/tomato_genome/
git clone https://github.com/GMOD/Chado ~/cxgn/Chado/

# Sublime
wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add -
echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list
sudo apt-get update
sudo apt-get install sublime-text

# R

# Dependencias para agricolae e outros pacotes: 
sudo apt-get install aptitude
sudo aptitude install libgdal-dev libproj-dev libgsl-dev libudunits2-dev freeglut3-dev

sudo apt install dirmngr apt-transport-https ca-certificates software-properties-common gnupg2
sudo apt-key adv --keyserver keys.gnupg.net --recv-key 'E19F5F87128899B192B1A2C2AD5F960A256A04AF'
sudo add-apt-repository 'deb https://cloud.r-project.org/bin/linux/debian buster-cran35/'
sudo apt update
sudo apt install r-base

#Tweaks
sudo add-apt-repository universe
sudo apt install gnome-tweak-tool

#Install cpanm



# Guest addition - Ubuntu
# sudo apt update
# sudo apt install build-essential dkms linux-headers-$(uname -r)
# sudo add-apt-repository multiverse
# sudo apt install virtualbox-guest-dkms virtualbox-guest-x11
# sudo reboot

#preparing sgn
sudo bash ~/cxgn/sgn/js/install_node.sh

echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" |sudo tee  /etc/apt/sources.list.d/pgdg.list













