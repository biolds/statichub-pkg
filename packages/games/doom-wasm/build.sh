#!/usr/bin/env bash
set -euo pipefail

WORKDIR="${STATICHUB_WORKDIR:?STATICHUB_WORKDIR is required}"
DISTDIR="${STATICHUB_DISTDIR:?STATICHUB_DISTDIR is required}"
PKGDIR="${STATICHUB_PKG:?STATICHUB_PKG is required}"

cd "$WORKDIR"

export PATH="/emsdk:/emsdk/node/current/bin:/emsdk/upstream/bin:/emsdk/llvm/clang/bin:$PATH"

if [ -f /emsdk/emsdk_env.sh ]; then
  source /emsdk/emsdk_env.sh
fi

apt-get update -qq
apt-get install -y -qq wget unzip build-essential libtool libtool-bin pkg-config m4 gettext

wget -q -O freedoom.zip https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedoom-0.13.0.zip
unzip -q freedoom.zip
cp freedoom-0.13.0/freedoom1.wad src/doom1.wad
rm -rf freedoom-0.13.0 freedoom.zip

embuilder build sdl2
embuilder build sdl2_mixer
embuilder build sdl2_net

mkdir -p "$WORKDIR/lib/autoconf"
cat >"$WORKDIR/lib/autoconf/extra.m4" <<'EOF'
AC_DEFUN([AS_IF], [if test -n "$1"; then $2; else $3; fi])
AC_DEFUN([AC_MSG_FAILURE], [echo "configure: error: $1" >&2; exit 1])
AC_DEFUN([AC_DEFINE], [AC_DEFINE_$1([$2], [$3], [$4])])
EOF
export ac_cv_func_log=no
export ac_cv_func_mmap=no
export ac_cv_func_ioperm=no
export ac_cv_header_stdio_h=yes
export ac_cv_header_stdlib_h=yes
export ac_cv_header_string_h=yes
export ac_cv_header_inttypes_h=yes
export ac_stdint=right
export ac_cv_header_stdint_h=yes
export ac_cv_header_strings_h=yes
export ac_cv_header_sys_stat_h=yes
export ac_cv_header_sys_types_h=yes
export ac_cv_header_unistd_h=yes
export ac_cv_header_dirent_h=yes

"$WORKDIR/scripts/clean.sh" 2>/dev/null || rm -f Makefile config.h 2>/dev/null || true
"$WORKDIR/scripts/build.sh" 2>&1

mkdir -p "$DISTDIR"
cp -a src/*.html src/*.js src/*.wasm src/doom1.wad src/default.cfg "$DISTDIR"/

HOST_OWNER=$(stat -c '%u:%g' "$DISTDIR")
chown -R "$HOST_OWNER" "$DISTDIR"
