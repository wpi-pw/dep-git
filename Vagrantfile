# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  config.vm.box = "bento/ubuntu-18.04"

  # Running must have provision scripts for vagrant
  config.vm.provision "shell", inline: "wget -qO vmh vmh.wpi.pw && bash vmh"
end
