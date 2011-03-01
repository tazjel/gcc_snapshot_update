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

GCC_VERSION=4.6
GDB_VERSION=7.2
GCC_PREFIX=/home/bdsatish/gnu/installed/gcc
GDB_PREFIX=/home/bdsatish/gnu/installed/gdb
DOWNLOAD_DIR=/home/bdsatish/gnu
SYMLINK_DIR=$HOME/bin

usage() {
cat <<EOF
Usage:
  gcc_snapshot --new              # Fetch the latest snapshot sources
  gcc_snapshot --update           # Fetch and apply patch to existing snapshot
EOF
exit 1
}

gcc_configure() {
./configure --prefix=$GCC_PREFIX --enable-languages=fortran --build=i786-pc-linux-gnu --enable-checking=release --disable-libmudflap --enable-libgomp --disable-shared --disable-bootstrap  
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
./configure --prefix=$GDB_PREFIX --enable-languages=fortran --build=i786-pc-linux-gnu --enable-libquadmath --enable-libquadmath-support --disable-bootstrap  --disable-libssp
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

# Issue usage if no parameters are given.
test $# -eq 0 && usage

if [ $1 == '--new' ]; then
    echo "Fetching latest ${GCC_VERSION} snapshot.Please wait..."
    cd $DOWNLOAD_DIR

    ## Clean up existing stuff (if any)
    rm -rf gcc-$GCC_VERSION
    rm -rf gdb-$GDB_VERSION
    rm -rf *.tar.bz2
    rm -rf *.gz

    # Fetch and extract the latest GCC snapshot, GMP, MPC and MPFR from GCC website
    wget ftp://gcc.gnu.org/pub/gcc/snapshots/LATEST-$GCC_VERSION/gcc-core-*.tar.bz2
    wget ftp://gcc.gnu.org/pub/gcc/snapshots/LATEST-$GCC_VERSION/gcc-fortran-*.tar.bz2
    wget ftp://gcc.gnu.org/pub/gcc/infrastructure/gmp-*.tar.bz2
    wget ftp://gcc.gnu.org/pub/gcc/infrastructure/mpfr-*.tar.bz2
    wget ftp://gcc.gnu.org/pub/gcc/infrastructure/mpc-*.tar.gz
    wget ftp://gcc.gnu.org/pub/gdb/snapshots/current/gdb.tar.bz2
    tar xjvf gcc-core-*.tar.bz2
    tar xjvf gcc-fortran-*.tar.bz2
    tar xjvf gmp-*.tar.bz2 -C gcc-$GCC_VERSION*/
    tar xjvf mpfr-*.tar.bz2 -C gcc-$GCC_VERSION*/
    tar xzvf mpc-*.tar.gz -C gcc-$GCC_VERSION*/
    tar xjvf gdb.tar.bz2
    rm -rf *.tar.bz2
    rm -rf *.tar.gz


    # Rename folders
    mv gcc-$GCC_VERSION* gcc-$GCC_VERSION
    mv gcc-$GCC_VERSION/gmp-* gcc-$GCC_VERSION/gmp
    mv gcc-$GCC_VERSION/mpfr-* gcc-$GCC_VERSION/mpfr
    mv gcc-$GCC_VERSION/mpc-* gcc-$GCC_VERSION/mpc
    mv gdb-$GDB_VERSION* gdb-$GDB_VERSION

    ## Start the build ! See http://gcc.gnu.org/wiki/GFortranSource
    echo 
    echo "Starting build..."
    cd gcc-$GCC_VERSION
    gcc_configure
    gcc_build
    cd ../gdb-$GDB_VERSION
    gdb_configure
    gdb_build
    echo "Done."
elif [ $1 == '--update' ]; then
    wget ftp://gcc.gnu.org/pub/gcc/snapshots/LATEST-$GCC_VERSION/diffs/gcc-core-*.diff.bz2
    wget ftp://gcc.gnu.org/pub/gcc/snapshots/LATEST-$GCC_VERSION/diffs/gcc-fortran-*.diff.bz2
    cd gcc-$GCC_VERSION
    ./contrib/gcc_update --patch ../gcc-core-*.diff.bz2
    ./contrib/gcc_update --patch ../gcc-fortran-*.diff.bz2
    gcc_build
    rm ../*.diff.bz2
else
    usage
fi



