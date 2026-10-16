#!/usr/bin/env sh
set -eu

usage() {
  printf '%s\n' 'Usage: sh tool/package_linux.sh --version <x.y.z> --gui-dir <path> --cli <path> --output <path> [--dry-run]' >&2
}

version=''
gui_dir=''
cli_executable=''
output_dir=''
dry_run=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version) version="${2:-}"; shift 2 ;;
    --gui-dir) gui_dir="${2:-}"; shift 2 ;;
    --cli) cli_executable="${2:-}"; shift 2 ;;
    --output) output_dir="${2:-}"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    *) usage; exit 64 ;;
  esac
done

printf '%s' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || { usage; exit 64; }
[ -d "$gui_dir" ] || { printf '%s\n' "GUI input directory does not exist: $gui_dir" >&2; exit 66; }
[ -f "$cli_executable" ] || { printf '%s\n' "CLI executable does not exist: $cli_executable" >&2; exit 66; }
[ -n "$output_dir" ] || { usage; exit 64; }

gui_portable="chimera-gui-linux-x64-${version}-portable.tar.gz"
gui_installer="chimera-gui-linux-x64-${version}-installer.deb"
cli_portable="chimera-cli-linux-x64-${version}-portable.tar.gz"
cli_installer="chimera-cli-linux-x64-${version}-installer.deb"

if [ "$dry_run" -eq 1 ]; then
  printf '%s\n' "$gui_portable" "$gui_installer" "$cli_portable" "$cli_installer"
  exit 0
fi

mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
gui_dir="$(cd "$gui_dir" && pwd)"
cli_dir="$(cd "$(dirname "$cli_executable")" && pwd)"
cli_name="$(basename "$cli_executable")"

stage="$(mktemp -d)"
cleanup() {
  rm -rf -- "$stage"
}
trap cleanup EXIT INT TERM

tar --create --gzip --file "$output_dir/$gui_portable" --directory "$gui_dir" .
tar --create --gzip --file "$output_dir/$cli_portable" --directory "$cli_dir" "$cli_name"

gui_package="$stage/gui"
mkdir -p "$gui_package/DEBIAN" "$gui_package/opt/chimera/gui" "$gui_package/usr/bin"
cp -R "$gui_dir/." "$gui_package/opt/chimera/gui/"
ln -s /opt/chimera/gui/chimera_gui "$gui_package/usr/bin/chimera-gui"
printf '%s\n' \
  'Package: chimera-gui' \
  "Version: $version" \
  'Section: utils' \
  'Priority: optional' \
  'Architecture: amd64' \
  'Maintainer: Chimera maintainers' \
  'Description: Local-first developer toolbox desktop application' \
  >"$gui_package/DEBIAN/control"

cli_package="$stage/cli"
mkdir -p "$cli_package/DEBIAN" "$cli_package/usr/bin"
install -m 0755 "$cli_executable" "$cli_package/usr/bin/chimera"
printf '%s\n' \
  'Package: chimera-cli' \
  "Version: $version" \
  'Section: utils' \
  'Priority: optional' \
  'Architecture: amd64' \
  'Maintainer: Chimera maintainers' \
  'Description: Local-first developer toolbox command-line application' \
  >"$cli_package/DEBIAN/control"

dpkg-deb --root-owner-group --build "$gui_package" "$output_dir/$gui_installer"
dpkg-deb --root-owner-group --build "$cli_package" "$output_dir/$cli_installer"

printf '%s\n' \
  "$output_dir/$gui_portable" \
  "$output_dir/$gui_installer" \
  "$output_dir/$cli_portable" \
  "$output_dir/$cli_installer"
