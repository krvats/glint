# Maintainer: krvats
pkgname=glint
pkgver=1.1.1
pkgrel=1
pkgdesc="Resolution, refresh rate, brightness and colour for your monitor, themed like your rice (Caelestia, pywal)"
arch=('any')
url="https://github.com/krvats/glint"
license=('MIT')
depends=('python' 'python-gobject' 'gtk4' 'libadwaita' 'ddcutil' 'i2c-tools')
optdepends=('adw-gtk-theme: GTK3 apps follow your colours' 'qt6ct: Qt apps follow your colours' 'python-pywalfox: Firefox follows your colours')
install=glint.install
source=("$pkgname-$pkgver.tar.gz::$url/archive/refs/tags/v$pkgver.tar.gz")
sha256sums=('SKIP')   # replace with `makepkg -g` output before submitting

package() {
  cd "$srcdir/$pkgname-$pkgver"
  install -Dm755 src/bin/glint "$pkgdir/usr/bin/glint"
  install -Dm755 src/bin/glint-gui "$pkgdir/usr/bin/glint-gui"
  install -d "$pkgdir/usr/share/glint"
  cp -r src/share/profiles src/share/monitors src/share/quickshell "$pkgdir/usr/share/glint/"
  install -Dm644 src/share/glint.desktop "$pkgdir/usr/share/applications/glint.desktop"
  install -Dm644 src/system/60-glint-i2c.rules "$pkgdir/usr/lib/udev/rules.d/60-glint-i2c.rules"
  install -Dm644 src/system/glint.conf "$pkgdir/usr/lib/modules-load.d/glint.conf"
  install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
