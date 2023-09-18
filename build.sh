#!/bin/bash
TOPDIR="$(dirname $(readlink -f "$0"))"
DEP_DIR=${TOPDIR}/deps/3rd/usr/local/oceanbase/deps/devel
TOOLS_DIR=${TOPDIR}/deps/3rd/usr/local/oceanbase/devtools
RUNTIME_DIR=${TOPDIR}/deps/3rd/usr
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
MAKE_ARGS="-j $CPU_CORES"

PACKAGE=${2:-obproxy-ce}
VERSION=${3:-`cat rpm/${PACKAGE}-VER.txt`}
RELEASE=${4:-1}
PREFIX=/home/admin/obproxy
SPEC_FILE=obproxy.spec

function sw()
{
  export DEP_DIR;
  export TOOLS_DIR;
  export RUNTIME_DIR;
  export DEP_VAR=$DEP_DIR/var/;
  /sbin/ldconfig -n $DEP_DIR/lib;
  export LD_LIBRARY_PATH=$DEP_DIR/lib:$DEP_VAR/usr/local/lib64:$DEP_VAR/usr/local/lib:$DEP_VAR/usr/lib64:$DEP_VAR/usr/lib:$DEP_VAR/lib64:/usr/lib/x86_64-linux-gnu;
  export LIBRARY_PATH=$DEP_DIR/lib:$DEP_VAR/usr/local/lib64:$DEP_VAR/usr/local/lib:$DEP_VAR/usr/lib64:$DEP_VAR/usr/lib:/usr/lib/x86_64-linux-gnu;
  export CPLUS_INCLUDE_PATH=$DEP_DIR/include:${RUNTIME_DIR}/include:$DEP_VAR/usr/local/include:$DEP_VAR/usr/include:$DEP_VAR/devel/include:/usr/include/x86_64-linux-gnu;
  export C_INCLUDE_PATH=$DEP_DIR/include:${RUNTIME_DIR}/include:/usr/include/x86_64-linux-gnu;
  export PATH=$DEP_DIR/bin:$TOOLS_DIR/bin:$PATH;
}

export AUTOM4TE="autom4te"
export AUTOCONF="autoconf"

function do_init()
{
	set -x
  sw
	aclocal
	libtoolize --force --copy --automake
	autoconf --force
	automake --foreign --copy --add-missing -Woverride -Werror
}

function do_dep_init()
{
  cd $TOPDIR/deps/3rd && bash dep_create.sh
  cd $TOPDIR
  do_init
}

function do_clean()
{
	echo 'cleaning...'
	make distclean >/dev/null 2>&1
	rm -rf autom4te.cache
	for fn in aclocal.m4 configure config.guess config.sub depcomp install-sh \
		ltmain.sh libtool missing mkinstalldirs config.log config.status Makefile; do
		rm -f $fn
	done

	find . -name Makefile.in -exec rm -f {} \;
	find . -path ./tools/codestyle/astyle/build -prune -o -path ./doc -prune -o -name Makefile -exec rm -f {} \;
	find . -name .deps -prune -exec rm -rf {} \;
	echo 'done'
}

function do_config()
{
  set -x
  sw
  case "x$1" in
    xdebug)
      # configure for developers
      ./configure --with-gcc-version=9.3.0 --with-coverage=no --enable-buildtime=no --enable-strip-ut=no --enable-silent-rules --enable-dlink-observer=no
      echo -e "\033[31m ===build debug version=== \033[0m"
      ;;
    xgcov)
      # configure for gcov
      ./configure --with-gcc-version=9.3.0 --with-coverage=yes --enable-buildtime=no --enable-strip-ut=no --enable-silent-rules --enable-dlink-observer=no
      echo -e "\033[31m ===build gcov version=== \033[0m"
      ;;
    xasan)
      # configure for asan
     ./configure --with-gcc-version=9.3.0 --with-coverage=no --enable-buildtime=no --enable-strip-ut=no --enable-silent-rules --enable-dlink-observer=no --with-asan
      echo -e "\033[31m ===build asan version=== \033[0m"
      ;;
    xso)
      # configure for obproxy_so
      ./configure --with-gcc-version=9.3.0 --with-coverage=no --enable-buildtime=no --enable-strip-ut=no --enable-silent-rules --enable-dlink-observer=no --with-release --with-so
      echo -e "\033[31m ===build so version=== \033[0m"
      ;;
    *)
      # configure for release
      ./configure --with-gcc-version=9.3.0 --with-coverage=no --enable-buildtime=no --enable-strip-ut=no --enable-silent-rules --enable-dlink-observer=no
      echo -e "\033[31m ===build release version=== \033[0m"
      ;;
  esac
}

function do_make()
{
  set -x
  sw
  bear make $MAKE_ARGS
}

function do_rpm()
{
  set -x
  sw

  echo "[BUILD] make dist..."
  make dist-gzip || exit 1

  TMP_DIR=/${TOPDIR}/obproxy-tmp.$$
  echo "[BUILD] create tmp dirs...TMP_DIR=${TMP_DIR}"
  mkdir -p ${TMP_DIR}
  mkdir -p ${TMP_DIR}/BUILD
  mkdir -p ${TMP_DIR}/RPMS
  mkdir -p ${TMP_DIR}/SOURCES
  mkdir -p ${TMP_DIR}/SRPMS
  cp ${PACKAGE}-${VERSION}.tar.gz ${TMP_DIR}/SOURCES
  cd ${TMP_DIR}/BUILD

  echo "[BUILD] make rpms..._prefix=${PREFIX} spec_file=${SPEC_FILE}"
  rpmbuild --define "_topdir ${TMP_DIR}" --define "NAME ${PACKAGE}" --define "VERSION ${VERSION}" --define "_prefix ${PREFIX}" --define "RELEASE ${RELEASE}" --define "rpm_path ${TOPDIR}" -ba ${TOPDIR}/deps/3rd/${SPEC_FILE} || exit 2
  echo "[BUILD] make rpms done."

  cd ${TOPDIR}
  find ${TMP_DIR}/RPMS/ -name "*.rpm" -exec mv '{}' ./ \;
  rm -rf ${TMP_DIR}
}

case "x$1" in
xinit)
  do_dep_init
	;;
xqinit)
  do_init
	;;
xclean)
  do_clean
	;;
xconfig)
  do_config $2
  ;;
xmake)
  do_make
  ;;
xrpm)
  do_dep_init
  do_config
  do_rpm
  ;;
*)
  do_dep_init
  do_config
  do_make
	;;
esac
