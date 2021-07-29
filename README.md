
<p align="center">
<a href="https://luminos.github.io"><img src="./docs/images/logo.png" height="150" width="150" alt="LuminOS"></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Maintained%3F-Yes-green?style=flat-square">
  <img src="https://img.shields.io/github/license/luminosystem/make.sh?style=flat-square">
  <img src="https://img.shields.io/github/stars/luminosystem/make.sh?style=flat-square">
  <img src="https://img.shields.io/github/forks/luminosystem/make.sh?color=teal&style=flat-square">
  <img src="https://img.shields.io/github/issues/luminosystem/make.sh?color=violet&style=flat-square">
</p>

<p align="center">
Focus on what matters. Based on <a href="https://www.archlinux.org">Arch Linux</a>.
</p>

## Screenshots

<p float="left" align="center">
  <img src="./docs/images/screenshot/1.png" width="48%" />
  <img src="./docs/images/screenshot/2.png" width="48%" />
  <img src="./docs/images/screenshot/3.png" width="48%" />
  <img src="./docs/images/screenshot/4.png" width="48%" />
</p>

## Requirements

For your system
 - A UEFI System Compatible
 - KVM CPU Compatible

You need install these packages to build the ISO.

 - Archiso >= 49-1
 - Git
 - QEMU

Get the source code.

    git clone https://github.com/luminosystem/make.git
    cd make.sh

## Build

Just type the command

    sudo sh make.sh

For build in /tmp files to use the memory space and fast build, type

    sudo sh make.sh -T

When complete, the .iso file will be in the ./out directory by default, you can also change this with

    sudo sh make.sh -o "/out_directory_here"

For more options in build

    sh make.sh -h

## Testing

When complete the build, for test the ISO, you can use this simple command

    sh make.sh -r "file_name.iso"

And a new instance of QEMU is open for testing. You can also use the VirtualBox too.
