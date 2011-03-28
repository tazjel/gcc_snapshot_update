#! /bin/bash

#    Copyright (C) 2011, Satish BD <mail @AT@ bdsatish .DOT. in>
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
    
# This shell script fetches the latest GCC snapshot and builds the GCC compiler itself.
# Latest version can be found at: https://github.com/bdsatish/gcc_snapshot_update/

set -e

usage() {
cat <<EOF
Usage:
  snapshot --gcc              # Fetch and build GCC weekly snapshot
                              # (in addition, implies --gmp, --mpfr and --mpc)
  snapshot --update           # Fetch and apply patch to existing GCC snapshot
  snapshot --openmpi          # Fetch and build Open MPI library
  snapshot --gmp              # Fetch and build GMP library
  snapshot --mpfr             # Fetch and build MPFR library (implies --gmp)
  snapshot --mpc              # Fetch and build MPC library (implies --gmp, --mpfr)
  snapshot --gdb              # Fetch and build latest nightly GDB snapshot
EOF
exit 1
}

GCC_VERSION=4.7         # <= 4.7
GDB_VERSION=7.2         # <= 7.2
OPENMPI_VERSION=1.4     # <= 1.5

# Suggested to put ~/bin your ".profile" or equivalent start-up file
SYMLINK_BIN=$HOME/bin   # Shortcut to created executables (if any) will go here 

# Installation directories, change them if needed.
# These are just passed to --prefix of corresponding 'configure' script

INSTALL_DIR=/home/bdsatish/gnu/installed

GCC_PREFIX=$INSTALL_DIR/gcc          # ${GCC_PREFIX}/bin/gcc is the executable
GDB_PREFIX=$INSTALL_DIR/gdb          # ${GDB_PREFIX}/bin/gdb is the executable
GMP_PREFIX=$INSTALL_DIR/gmp          # ${GMP_PREFIX}/lib/libgmp.a is the library
MPFR_PREFIX=$INSTALL_DIR/mpfr        # ${MPFR_PREFIX}/lib/libmpfr.a is the library
MPC_PREFIX=$INSTALL_DIR/mpc          # ${MPC_PREFIX}/lib/libmpc.a is the library
OMPI_PREFIX=$INSTALL_DIR/openmpi     # ${OMPI_PREFIX}/lib/libopenmpi.a is the library

DOWNLOAD_DIR=/home/bdsatish/gnu

# Global variables
GMP_INSTALLED=false
MPFR_INSTALLED=false
MPC_INSTALLED=false

#-------------------------- FUNCTION DEFINITIONS ONLY ------------------------------
# The actual script execution starts after all these definitions ! See below !

gmp_build() {

    PWD=`pwd`
    cd $DOWNLOAD_DIR
    wget -N ftp://gcc.gnu.org/pub/gcc/infrastructure/gmp-*.tar.bz2
    tar --extract --overwrite --bzip2 --verbose --file gmp-*.tar.bz2

    cd gmp-*
    ./configure --prefix=$GMP_PREFIX --enable-static --disable-shared
    make clean
    make -j 2
    make install

    rm -rf ../gmp-*.tar.bz2
    cd $PWD

    GMP_INSTALLED=true
}

mpfr_build() {
    if ! $GMP_INSTALLED; then gmp_build; fi
    
    PWD=`pwd`
    cd $DOWNLOAD_DIR
    wget -N ftp://gcc.gnu.org/pub/gcc/infrastructure/mpfr-*.tar.bz2
    tar --extract --overwrite --bzip2 --verbose --file mpfr-*.tar.bz2

    cd mpfr-*
    ./configure --prefix=$MPFR_PREFIX --enable-static --disable-shared --with-gmp=$GMP_PREFIX
    make clean
    make -j 2
    make install

    rm -rf ../mpfr-*.tar.bz2
    cd $PWD

    MPFR_INSTALLED=true
}

mpc_build() {
    if ! $GMP_INSTALLED; then gmp_build; fi
    if ! $MPFR_INSTALLED; then mpfr_build; fi

    PWD=`pwd`
    cd $DOWNLOAD_DIR
    wget -N ftp://gcc.gnu.org/pub/gcc/infrastructure/mpc-*.tar.gz
    tar --extract --overwrite --gzip --verbose --file mpc-*.tar.gz

    cd mpc-*
    ./configure --prefix=$MPC_PREFIX --enable-static --disable-shared \
                --with-gmp=$GMP_PREFIX --with-mpfr=$MPFR_PREFIX
    make clean
    make -j 2
    make install

    rm -rf ../mpc-*.tar.gz
    cd $PWD

    MPC_INSTALLED=true    
}

gcc_build() {
    if ! $GMP_INSTALLED; then gmp_build; fi
    if ! $MPFR_INSTALLED; then mpfr_build; fi
    if ! $MPC_INSTALLED; then mpc_build; fi

    PWD=`pwd`
    cd $DOWNLOAD_DIR
    wget -N ftp://gcc.gnu.org/pub/gcc/snapshots/LATEST-$GCC_VERSION/gcc-core-*.tar.bz2
    wget -N ftp://gcc.gnu.org/pub/gcc/snapshots/LATEST-$GCC_VERSION/gcc-fortran-*.tar.bz2
    tar --extract --overwrite --bzip2 --verbose --file gcc-core-*.tar.bz2
    tar --extract --overwrite --bzip2 --verbose --file gcc-fortran-*.tar.bz2
    
    rm -rf gcc-$GCC_VERSION
    mv gcc-$GCC_VERSION* gcc-$GCC_VERSION
    cd gcc-$GCC_VERSION
   
    # Needed ?  --enable-fixed-point --with-long-double-128
    ./configure --prefix=$GCC_PREFIX --enable-languages=c,fortran --disable-lto \
      --enable-checking=release --disable-libmudflap --enable-libgomp --disable-bootstrap \
      --enable-static --disable-shared --with-system-zlib --disable-decimal-float  \
      --with-gmp=$GMP_PREFIX --with-mpfr=$MPFR_PREFIX --with-mpc=$MPC_PREFIX

    make clean
    make -j 1
    make install

    mkdir -p $SYMLINK_BIN
    ln -sfn $GCC_PREFIX/bin/gcc $SYMLINK_BIN/gcc
    ln -sfn $GCC_PREFIX/bin/cpp $SYMLINK_BIN/cpp
    ln -sfn $GCC_PREFIX/bin/gfortran $SYMLINK_BIN/gfortran
    ln -sfn $GCC_PREFIX/bin/gcov $SYMLINK_BIN/gcov

    rm -rf ../gcc-core-*.tar.bz2
    rm -rf ../gcc-fortran-*.tar.bz2
    cd $PWD

    GCC_INSTALLED=true
}

gcc_update() {

    PWD=`pwd`
    cd $DOWNLOAD_DIR
    wget ftp://gcc.gnu.org/pub/gcc/snapshots/LATEST-$GCC_VERSION/diffs/gcc-core-*.diff.bz2
    wget ftp://gcc.gnu.org/pub/gcc/snapshots/LATEST-$GCC_VERSION/diffs/gcc-fortran-*.diff.bz2

    cd gcc-$GCC_VERSION
    ./contrib/gcc_update --patch ../gcc-core-*.diff.bz2
    ./contrib/gcc_update --patch ../gcc-fortran-*.diff.bz2
    # This is GCC update ! So DON'T make clean
    make -j 1
    make install

    rm ../*.diff.bz2
    cd $PWD
}

gdb_build() {
    if ! $GMP_INSTALLED; then gmp_build; fi
    if ! $MPFR_INSTALLED; then mpfr_build; fi
    if ! $MPC_INSTALLED; then mpc_build; fi

    PWD=`pwd`
    cd $DOWNLOAD_DIR
    wget -N ftp://gcc.gnu.org/pub/gdb/snapshots/current/gdb.tar.bz2
    tar --extract --overwrite --bzip2 --verbose --file gdb.tar.bz2

    rm -rf gdb-$GDB_VERSION
    mv gdb-$GDB_VERSION* gdb-$GDB_VERSION
    cd gdb-$GDB_VERSION

    ./configure --prefix=$GDB_PREFIX --enable-languages=c,fortran --disable-bootstrap \
      --enable-libquadmath --enable-libquadmath-support --disable-libssp  \
      --with-gmp=$GMP_PREFIX --with-mpfr=$MPFR_PREFIX --with-mpc=$MPC_PREFIX

    make clean
    make -j 1
    make install

    mkdir -p $SYMLINK_BIN
    ln -sfn $GDB_PREFIX/bin/gdb $SYMLINK_BIN/gdb
    ln -sfn $GDB_PREFIX/bin/gdbserver $SYMLINK_BIN/gdbserver
    ln -sfn $GDB_PREFIX/bin/gdbtui $SYMLINK_BIN/gdbtui

    rm -rf ../gdb.tar.bz2
    cd $PWD

    GDB_INSTALLED=true
}

openmpi_build() {

    PWD=`pwd`
    cd $DOWNLOAD_DIR
    BASE_URL=http://www.open-mpi.org/software/ompi/v${OPENMPI_VERSION}/downloads
    wget -N ${BASE_URL}/latest_snapshot.txt
    VERSION=`cat latest_snapshot.txt`
    wget -N ${BASE_URL}/openmpi-${VERSION}.tar.bz2
    tar --extract --overwrite --bzip2 --verbose --file  openmpi-${VERSION}.tar.bz2
    cd openmpi-${VERSION}
    
    # max-array-dim=3 means upto 3D arrays are supported. Standard Fortran
    # can support upto 7-D arrays, which we don't need
    #
    # CFLAGS enables 128-bit (16-byte) reals in C programs, which in turn
    # enables REAL*16 support for F90 and F77
    ./configure --prefix=$OMPI_PREFIX --enable-static --disable-shared \
            --disable-mpi-cxx --disable-mpi-cxx-seek --enable-mpi-threads \
            --without-memory-manager --without-libnuma  \
            --with-f90-max-array-dim=3 CFLAGS=-m128bit-long-double \
            --with-wrapper-cflags=-m128bit-long-double

    make clean
    make -j 1
    make install

    mkdir -p $SYMLINK_BIN
    ln -sfn $OMPI_PREFIX/bin/mpicc $SYMLINK_BIN/mpicc
    ln -sfn $OMPI_PREFIX/bin/mpif77 $SYMLINK_BIN/mpif77
    ln -sfn $OMPI_PREFIX/bin/mpif90 $SYMLINK_BIN/mpif90
    ln -sfn $OMPI_PREFIX/bin/mpirun $SYMLINK_BIN/mpirun
    ln -sfn $OMPI_PREFIX/bin/mpiexec $SYMLINK_BIN/mpiexec
    
    ln -sfn $OMPI_PREFIX/bin/ompi_info $SYMLINK_BIN/ompi_info
    #ln -sfn $OMPI_PREFIX/bin/gfortran $SYMLINK_BIN/mpif90
    #ln -sfn $OMPI_PREFIX/bin/gcov $SYMLINK_BIN/mpirun

    rm ../latest_snapshot.txt
    rm ../openmpi-${VERSION}.tar.bz2
    cd $PWD

    OPENMPI_INSTALLED=true
}

#------------------------- EXECUTION STARTS HERE --------------------------

#  Issue usage if no parameters are given.
test $# -eq 0 && usage

if [[ $1 == '--gcc' ]]; then
    gcc_build
elif [ $1 == '--update' ]; then
    gcc_update
elif [ $1 == '--gdb' ]; then
    gdb_build
elif [ $1 == '--openmpi' ]; then
    openmpi_build
elif [ $1 == '--gmp' ]; then
    gmp_build
elif [ $1 == '--mpfr' ]; then
    mpfr_build
elif [ $1 == '--mpc' ]; then
    mpc_build
else
    usage
fi



