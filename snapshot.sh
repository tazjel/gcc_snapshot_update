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

GCC_VERSION=4.7         # <= 4.7
GDB_VERSION=7.2         # <= 7.2
OPENMPI_VERSION=1.4     # <= 1.5

INSTALL_DIR=/home/bdsatish/gnu/installed
GCC_PREFIX=$INSTALL_DIR/gcc
GDB_PREFIX=$INSTALL_DIR/gdb
GMP_PREFIX=$INSTALL_DIR/gmp
MPFR_PREFIX=$INSTALL_DIR/mpfr
MPC_PREFIX=$INSTALL_DIR/mpc
OPENMPI_PREFIX=$INSTALL_DIR/openmpi

DOWNLOAD_DIR=/home/bdsatish/gnu
SYMLINK_DIR=$HOME/bin

usage() {
cat <<EOF
Usage:
  snapshot --gcc              # Fetch and build GCC only
  snapshot --update           # Fetch and apply patch to existing GCC snapshot
  snapshot --openmpi          # Fetch and build Open MPI library
  snapshot --all              # Fetch and build GCC and GDB, from scratch  
EOF
exit 1
}

#-------------------- FUNCTION DEFINITIONS ONLY -------------------------------------
#  
#  --with-long-double-128, --build=i786-pc-linux-gnu, --disable-decimal-float 
# Wihout building decimal-float, build time is around 21 min
gcc_configure() {
./configure --prefix=$GCC_PREFIX --enable-languages=c,fortran  \
      --enable-checking=release --disable-libmudflap --enable-libgomp --disable-bootstrap \
      --enable-static --disable-shared --with-system-zlib --disable-decimal-float  \
      --with-gmp=$GMP_PREFIX --with-mpfr=$MPFR_PREFIX --with-mpc=$MPC_PREFIX
}

gcc_build() {
    ## Low CPU load consumption (change 1.2 to whatever u need)
    make -l 0.05 -j 1

    make install

    # Create symlinks
    rm -rf $SYMLINK_DIR/gcc 
    rm -rf $SYMLINK_DIR/g++
    rm -rf $SYMLINK_DIR/c++
    rm -rf $SYMLINK_DIR/cpp
    rm -rf $SYMLINK_DIR/gfortran
    rm -rf $SYMLINK_DIR/gcov
    ln -s $GCC_PREFIX/bin/gcc $SYMLINK_DIR/gcc
    ln -s $GCC_PREFIX/bin/cpp $SYMLINK_DIR/cpp
    ln -s $GCC_PREFIX/bin/gfortran $SYMLINK_DIR/gfortran
    ln -s $GCC_PREFIX/bin/gcov $SYMLINK_DIR/gcov
}

gdb_configure() {
./configure --prefix=$GDB_PREFIX --enable-languages=fortran --build=i786-pc-linux-gnu \
--enable-libquadmath --enable-libquadmath-support --disable-bootstrap  --disable-libssp  \
--with-gmp=$GMP_PREFIX --with-mpfr=$MPFR_PREFIX --with-mpc=$MPC_PREFIX
}

gdb_build() {
    make -l 0.05 -j 1
    make install

    # Create symlinks
    rm -rf $SYMLINK_DIR/gdb 
    rm -rf $SYMLINK_DIR/gdbserver
    rm -rf $SYMLINK_DIR/gdbtui
    ln -s $GDB_PREFIX/bin/gdb $SYMLINK_DIR/gdb
    ln -s $GDB_PREFIX/bin/gdbserver $SYMLINK_DIR/gdbserver
    ln -s $GDB_PREFIX/bin/gdbtui $SYMLINK_DIR/gdbtui
}

openmpi_build() {

wget http://www.open-mpi.org/software/ompi/v${OPENMPI_VERSION}/downloads/latest_snapshot.txt
VERSION=`cat latest_snapshot.txt`
wget http://www.open-mpi.org/software/ompi/v${OPENMPI_VERSION}/downloads/openmpi-${VERSION}.tar.bz2
tar xjvf openmpi-${VERSION}.tar.bz2

rm latest_snapshot.txt
rm openmpi-${VERSION}.tar.bz2

cd openmpi-${VERSION}
# f90-size=3 means upto 3D arrays are supported. Standard Fortran
# can support upto 7-D arrays, which we don't need
#
# CFLAGS enables 128-bit (16-byte) reals in C programs, which in turn
# enables REAL*16 support for F90 and F77
./configure --enable-static --disable-shared --disable-mpi-cxx \
            --disable-mpi-cxx-seek --enable-mpi-threads \
            --prefix=$OPENMPI_PREFIX \
            --without-memory-manager --without-libnuma  \
            --with-mpi-f90-size=3 CFLAGS=-m128bit-long-double 

make -l 0.05 -j 1
make install
}

#------------- EXECUTION STARTS HERE ------------------
#  Issue usage if no parameters are given.
test $# -eq 0 && usage

if [[ $1 == '--all' || $1 == '--gcc' ]]; then
    echo "Fetching latest ${GCC_VERSION} snapshot.Please wait..."
    cd $DOWNLOAD_DIR

    ## Clean up existing stuff (if any)
    rm -rf *.bz2
    rm -rf *.gz

    # Fetch and extract the latest GCC snapshot, GMP, MPC and MPFR from GCC website
    wget ftp://gcc.gnu.org/pub/gcc/snapshots/LATEST-$GCC_VERSION/gcc-core-*.tar.bz2
    wget ftp://gcc.gnu.org/pub/gcc/snapshots/LATEST-$GCC_VERSION/gcc-fortran-*.tar.bz2
    wget ftp://gcc.gnu.org/pub/gcc/infrastructure/gmp-*.tar.bz2
    wget ftp://gcc.gnu.org/pub/gcc/infrastructure/mpfr-*.tar.bz2
    wget ftp://gcc.gnu.org/pub/gcc/infrastructure/mpc-*.tar.gz
    wget ftp://gcc.gnu.org/pub/gdb/snapshots/current/gdb.tar.bz2

    ## Clean up existing stuff (if any)
    rm -rf gcc-$GCC_VERSION
    rm -rf gdb-$GDB_VERSION

    tar xjvf gcc-core-*.tar.bz2
    tar xjvf gcc-fortran-*.tar.bz2
    tar xjvf gmp-*.tar.bz2
    tar xjvf mpfr-*.tar.bz2
    tar xzvf mpc-*.tar.gz
    tar xjvf gdb.tar.bz2
    rm -rf *.tar.bz2
    rm -rf *.tar.gz

    # Rename folders
    mv gcc-$GCC_VERSION* gcc-$GCC_VERSION
    mv gdb-$GDB_VERSION* gdb-$GDB_VERSION

    # First, build the dependencies: GMP, MPFR and MPC
    echo 
    echo "Building GMP, MPFR and MPC ..."
    cd gmp*
    ./configure --prefix=$GMP_PREFIX --enable-static --disable-shared
    make -j 2
    make install
    cd ../mpfr*
    ./configure --prefix=$MPFR_PREFIX --enable-static --disable-shared --with-gmp=$GMP_PREFIX
    make -j 2
    make install
    cd ../mpc*
    ./configure --prefix=$MPC_PREFIX --enable-static --disable-shared \
                --with-gmp=$GMP_PREFIX --with-mpfr=$MPFR_PREFIX
    make -j 2
    make install
    cd ..
    echo "GMP, MPFR and MPC installed successfully !"

    ## Start the build ! See http://gcc.gnu.org/wiki/GFortranSource
    echo 
    echo "Starting gcc build..."
    cd gcc-$GCC_VERSION
    gcc_configure
    gcc_build
    if [[ $1 == '--all' ]]; then
        cd ../gdb-$GDB_VERSION
        gdb_configure
        gdb_build
    fi
    echo "Done."
elif [ $1 == '--update' ]; then
    wget ftp://gcc.gnu.org/pub/gcc/snapshots/LATEST-$GCC_VERSION/diffs/gcc-core-*.diff.bz2
    wget ftp://gcc.gnu.org/pub/gcc/snapshots/LATEST-$GCC_VERSION/diffs/gcc-fortran-*.diff.bz2
    cd gcc-$GCC_VERSION
    ./contrib/gcc_update --patch ../gcc-core-*.diff.bz2
    ./contrib/gcc_update --patch ../gcc-fortran-*.diff.bz2
    gcc_build
    rm ../*.diff.bz2
elif [ $1 == '--openmpi' ]; then
    openmpi_build
else
    usage
fi



