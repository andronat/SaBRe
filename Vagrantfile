Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/bionic64"

  config.vm.provision "shell", inline: <<-SHELL
    rm /vagrant/ubuntu-bionic-18.04-cloudimg-console.log

    apt-get update
    apt-get -y install sudo apt-utils build-essential openssl clang \
    libgraphviz-dev git libgnutls28-dev ntp libseccomp-dev libtool gettext \
    libssl-dev pkg-config libini-config-dev cmake cmake-curses-gui autoconf \
    linux-tools-common linux-tools-generic linux-cloud-tools-generic llvm tcl \
    efibootmgr python3-pip rustc rust-src libc6-dbg glibc-source

    timedatectl set-timezone Europe/London
    systemctl start ntp
    systemctl enable ntp

    echo core | tee /proc/sys/kernel/core_pattern
  SHELL

  config.vm.provision "shell", privileged: false, inline: <<-SHELL
    pip3 install lit psutil --user

    if ! grep -Fq "LLVM_CONFIG" ~/.profile; then
      echo 'export PATH="${HOME}/.local/bin:${PATH}"' >> ~/.profile
      echo 'export LLVM_CONFIG="/usr/bin/llvm-config-6.0"' >> ~/.profile
      echo 'export WORKDIR="/home/vagrant"' >> ~/.profile
      echo 'export AFLNET="${WORKDIR}/aflnet"' >> ~/.profile
      echo 'export PATH="${PATH}:${AFLNET}"' >> ~/.profile
      echo 'export AFL_PATH="${AFLNET}"' >> ~/.profile
      echo 'export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1' >> ~/.profile
      echo 'export AFL_SKIP_CPUFREQ=1' >> ~/.profile
      ulimit -c unlimited
    fi

    source "${HOME}/.profile"

    cd "${WORKDIR}"
    V="1.0.18"
    wget "https://download.libsodium.org/libsodium/releases/libsodium-${V}.tar.gz"
    tar xzf "libsodium-${V}.tar.gz"
    cd "libsodium-${V}"
    ./configure
    make && make check
    sudo make install
    # Check the following exist:
    # -> /usr/local/include/sodium/
    # -> /usr/local/include/sodium.h
    # -> /usr/local/lib/libsodium.*

    cd "${WORKDIR}"
    git clone https://github.com/zboxfs/zbox-c
    cd zbox-c
    mkdir -p m4
    ./autogen.sh
    ./configure
    make && make check
    sudo make install
    # Check the following exist:
    # -> /usr/local/lib/libzbox*
    # -> /home/vagrant/zbox-c/zbox.h
    # -> /home/vagrant/zbox-c/zbox
  SHELL
end
