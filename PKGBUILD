#    Copyright (C) 2022 7thCore
#    This file is part of IsRSrv-Script.
#
#    IsRSrv-Script is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    IsRSrv-Script is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

pkgname=mcsrv-script
pkgver=1.5
pkgrel=7
pkgdesc='Minecraft server script for running the server on linux.'
arch=('x86_64')
license=('GPL3')
depends=('bash'
         'coreutils'
         'sudo'
         'grep'
         'sed'
         'awk'
         'curl'
         'rsync'
         'wget'
         'findutils'
         'tmux'
         'jq'
         'zip'
         'unzip'
         'p7zip'
         'postfix'
         's-nail'
         'jre-openjdk-headless')
install=mcsrv-script.install
source=('bash_profile'
        'mcsrv-mkdir-tmpfs@.service'
        'mcsrv-script.bash'
        'mcsrv-send-notification@.service'
        'mcsrv-serversync@.service'
        'mcsrv@.service'
        'mcsrv-timer-1.service'
        'mcsrv-timer-1.timer'
        'mcsrv-timer-2.service'
        'mcsrv-timer-2.timer'
        'mcsrv-tmpfs@.service')
sha256sums=('f1e2f643b81b27d16fe79e0563e39c597ce42621ae7c2433fd5b70f1eeab5d63'
            '2c9e93440eb49130e9d267abae0dc5e2cb57236dc44af84ec338cb09a0852902'
            '1d142e2bbc3bb0266e01c139d5bc3d51558a16542f93fc0c6dfd6788b2feac7f'
            '5da081f8fd954393296cd4f7123f2d51f65b496ad844d642b382d74df53160b3'
            '45c2e17ffab48ef1e84a6a462932d114872d646a5964c3e6942fc8e8313d1093'
            '643193daa629eb44d87f039f2d9802f1b42ed61d7f6e074488312512582ef09f'
            'c138b9693bf1e63fb0bbb6658dc419a9abc05778483409d63b2c3adb45b84147'
            '5116c82874543bd11f4976495fb30075fd076115ad877fcecb8e1a6a97f5471e'
            '1e2a15e070127b28668e8d34c8fa63253d7c4008984d26cb6cfc86f29f4b9a2d'
            '59bb73d65729d1b8919d3ed0b3cbc7603b42499a1cdd7aaa5ad9f96d733f531b'
            '495dfac9c1e1064cec88c57c4556e97a33ebf41a217456cc30f4779ced7d4238')

package() {
  install -d -m0755 "${pkgdir}/usr/bin"
  install -d -m0755 "${pkgdir}/srv/mcsrv"
  install -d -m0755 "${pkgdir}/srv/mcsrv/servers"
  install -d -m0755 "${pkgdir}/srv/mcsrv/config"
  install -d -m0755 "${pkgdir}/srv/mcsrv/environments"
  install -d -m0755 "${pkgdir}/srv/mcsrv/updates"
  install -d -m0755 "${pkgdir}/srv/mcsrv/backups"
  install -d -m0755 "${pkgdir}/srv/mcsrv/logs"
  install -d -m0755 "${pkgdir}/srv/mcsrv/tmpfs"
  install -d -m0755 "${pkgdir}/srv/mcsrv/.config"
  install -d -m0755 "${pkgdir}/srv/mcsrv/.config/systemd"
  install -d -m0755 "${pkgdir}/srv/mcsrv/.config/systemd/user"
  install -D -Dm755 "${srcdir}/mcsrv-script.bash" "${pkgdir}/usr/bin/mcsrv-script"
  install -D -Dm755 "${srcdir}/mcsrv-timer-1.timer" "${pkgdir}/srv/mcsrv/.config/systemd/user/mcsrv-timer-1.timer"
  install -D -Dm755 "${srcdir}/mcsrv-timer-1.service" "${pkgdir}/srv/mcsrv/.config/systemd/user/mcsrv-timer-1.service"
  install -D -Dm755 "${srcdir}/mcsrv-timer-2.timer" "${pkgdir}/srv/mcsrv/.config/systemd/user/mcsrv-timer-2.timer"
  install -D -Dm755 "${srcdir}/mcsrv-timer-2.service" "${pkgdir}/srv/mcsrv/.config/systemd/user/mcsrv-timer-2.service"
  install -D -Dm755 "${srcdir}/mcsrv-send-notification@.service" "${pkgdir}/srv/mcsrv/.config/systemd/user/mcsrv-send-notification@.service"
  install -D -Dm755 "${srcdir}/mcsrv@.service" "${pkgdir}/srv/mcsrv/.config/systemd/user/mcsrv@.service"
  install -D -Dm755 "${srcdir}/mcsrv-mkdir-tmpfs@.service" "${pkgdir}/srv/mcsrv/.config/systemd/user/mcsrv-mkdir-tmpfs@.service"
  install -D -Dm755 "${srcdir}/mcsrv-tmpfs@.service" "${pkgdir}/srv/mcsrv/.config/systemd/user/mcsrv-tmpfs@.service"
  install -D -Dm755 "${srcdir}/mcsrv-serversync@.service" "${pkgdir}/srv/mcsrv/.config/systemd/user/mcsrv-serversync@.service"
  install -D -Dm755 "${srcdir}/bash_profile" "${pkgdir}/srv/mcsrv/.bash_profile"
}
