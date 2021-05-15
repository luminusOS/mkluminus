
<p align="center">
<a href="https://luminos.github.io"><img src="./docs/images/logo.png" height="150" width="150" alt="LuminOS"></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Maintained%3F-Yes-green?style=flat-square">
  <img src="https://img.shields.io/github/license/luminosystem/makeiso?style=flat-square">
  <img src="https://img.shields.io/github/stars/luminosystem/makeiso?style=flat-square">
  <img src="https://img.shields.io/github/forks/luminosystem/makeiso?color=teal&style=flat-square">
  <img src="https://img.shields.io/github/issues/luminosystem/makeiso?color=violet&style=flat-square">
</p>

<p align="center">
Embrace the productivity. Based on <a href="https://www.archlinux.org">Arch Linux</a>.
</p>

## Screenshots

<p align="center">
<img src="./docs/images/screenshot/1.png" alt="Screenshot 1">
</p>
<p align="center">
<img src="./docs/images/screenshot/2.png" alt="Screenshot 2">
</p>
<p align="center">
<img src="./docs/images/screenshot/3.png" alt="Screenshot 3">
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

    git clone https://github.com/luminosystem/makeiso.git
    cd makeiso

## Build

Just type the command

    sudo sh build.sh

For build in /tmp files to use the memory space and fast build, type

    sudo sh build.sh -T

For more options in build

    sh build.sh -h

## Testing

When complete the build, for test the ISO, you can use this simple command

    sh build.sh -r

And a new instance of QEMU is open for testing. You can also use the VirtualBox too.