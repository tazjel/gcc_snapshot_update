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
  snapshot --gcc              # Fetch and build GCC weekly snapshot (C, Fortran)
                              # (in addition, implies --gmp, --mpfr and --mpc)
  snapshot --update           # Fetch and apply patch to existing GCC snapshot
  snapshot --openmpi          # Open MPI library
  snapshot --lapack           # Lapack from Netlib
  snapshot --fftw             # Fast Fourier Transforms in the West
  snapshot --fgsl             # Fortran bindings to GNU Scientific Library
  snapshot --gmp              # GNU Multi-Precision library
  snapshot --mpfr             # Multi-Precision Floating Point library (implies --gmp)
  snapshot --mpc              # Multi-Precision Complex arithmetic library (implies --gmp, --mpfr)
  snapshot --gdb              # GNU Debugger snapshot
EOF
exit 1
}

GCC_VERSION=4.7         # <= 4.7
GDB_VERSION=7.2         # <= 7.2
OPENMPI_VERSION=1.4     # <= 1.5
GSL_VERSION=1.14        # <= 1.14


# Suggested to put ~/bin your ".profile" or equivalent start-up file
SYMLINK_BIN=$HOME/bin   # Shortcut to created executables (if any) will go here 

# Installation directories, change them if needed.
# These are just passed to --prefix of corresponding 'configure' script

INSTALL_DIR=/home/bdsatish/foss/installed
DOWNLOAD_DIR=/home/bdsatish/foss

GCC_PREFIX=$INSTALL_DIR/gcc          # ${GCC_PREFIX}/bin/gcc is the executable
GDB_PREFIX=$INSTALL_DIR/gdb          # ${GDB_PREFIX}/bin/gdb is the executable
GMP_PREFIX=$INSTALL_DIR/gmp          # ${GMP_PREFIX}/lib/libgmp.a is the library
MPFR_PREFIX=$INSTALL_DIR/mpfr        # ${MPFR_PREFIX}/lib/libmpfr.a is the library
MPC_PREFIX=$INSTALL_DIR/mpc          # ${MPC_PREFIX}/lib/libmpc.a is the library
OMPI_PREFIX=$INSTALL_DIR/openmpi     # ${OMPI_PREFIX}/lib/libmpi.a is the library
                                     # ${OMPI_PREFIX}/bin/mpicc is the gcc wrapper
                                     
GSL_PREFIX=$INSTALL_DIR/gsl          # ${FGSL_PREFIX}/lib/libgsl.a
FGSL_PREFIX=$INSTALL_DIR/fgsl        # ${FGSL_PREFIX}/lib/libfgsl_xxx.a
LAPACK_PREFIX=$INSTALL_DIR/lapack    # liblapack.a AND libblas.a go here
FFTW_PREFIX=$INSTALL_DIR/fftw        # libfftw.a

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

    rm -rf $DOWNLOAD_DIR/gmp-*.tar.bz2
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

    rm -rf $DOWNLOAD_DIR/mpfr-*.tar.bz2
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

    rm -rf $DOWNLOAD_DIR/mpc-*.tar.gz
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
    wget -N ftp://gcc.gnu.org/pub/gcc/snapshots/LATEST-$GCC_VERSION/gcc-g++-*.tar.bz2
    tar --extract --overwrite --bzip2 --verbose --file gcc-core-*.tar.bz2
    tar --extract --overwrite --bzip2 --verbose --file gcc-fortran-*.tar.bz2
    tar --extract --overwrite --bzip2 --verbose --file gcc-g++-*.tar.bz2
    
    rm -rf gcc-$GCC_VERSION
    mv gcc-$GCC_VERSION* gcc-$GCC_VERSION
    cd gcc-$GCC_VERSION
    mkdir -p build
    cd build
   
    # Needed ?  --enable-fixed-point --with-long-double-128 --disable-lto
    ../configure --prefix=$GCC_PREFIX --enable-languages=c,fortran  \
      --enable-checking=release --disable-libmudflap --enable-libgomp --disable-bootstrap \
      --enable-static --disable-shared --disable-decimal-float  --with-system-zlib  \
      --with-gmp=$GMP_PREFIX --with-mpfr=$MPFR_PREFIX --with-mpc=$MPC_PREFIX

    make clean
    make -j 1
    make install

    mkdir -p $SYMLINK_BIN
    ln -sfn $GCC_PREFIX/bin/gcc $SYMLINK_BIN/gcc
    ln -sfn $GCC_PREFIX/bin/cpp $SYMLINK_BIN/cpp
    ln -sfn $GCC_PREFIX/bin/gcov $SYMLINK_BIN/gcov
    ln -sfn $GCC_PREFIX/bin/gfortran $SYMLINK_BIN/gfortran
    ln -sfn $GCC_PREFIX/bin/gcc $SYMLINK_BIN/g++

    rm -rf $DOWNLOAD_DIR/gcc-core-*.tar.bz2
    rm -rf $DOWNLOAD_DIR/gcc-fortran-*.tar.bz2
    rm -rf $DOWNLOAD_DIR/gcc-g++-*.tar.bz2
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

    rm $DOWNLOAD_DIR/*.diff.bz2
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

    rm -rf $DOWNLOAD_DIR/gdb.tar.bz2
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
    
    # Passed to CFLAGS to enable 128-bit (16-byte) reals in C programs, 
    # which in turn enables REAL*16 support for F90 and F77 (libquadmath!)
    LONG_DOUBLE=-m128bit-long-double
    MAX_ARRAY_DIM=3    # max 3D arrays are supported, can be up to 7
    ./configure --prefix=$OMPI_PREFIX --enable-static --disable-shared \
            --disable-mpi-cxx --disable-mpi-cxx-seek --enable-mpi-threads \
            --without-memory-manager --without-libnuma  \
            --with-f90-max-array-dim=${MAX_ARRAY_DIM} \
            --with-wrapper-cflags=${LONG_DOUBLE}  CFLAGS=${LONG_DOUBLE} 

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

    rm $DOWNLOAD_DIR/latest_snapshot.txt
    rm $DOWNLOAD_DIR/openmpi-${VERSION}.tar.bz2
    cd $PWD

    OPENMPI_INSTALLED=true
}

fgsl_build() {

    PWD=`pwd`
    
    # First build GNU GSL before Fortran GSL
    cd $DOWNLOAD_DIR
    wget -N http://ftp.gnu.org/gnu/gsl/gsl-${GSL_VERSION}.tar.gz
    tar --extract --overwrite --gzip --verbose --file  gsl-${GSL_VERSION}.tar.gz
    cd gsl-${GSL_VERSION}

    ./configure --prefix=${GSL_PREFIX}  --enable-static --disable-shared
    make clean
    make -j 1
    make install
    
    cd $DOWNLOAD_DIR
    FGSL_VERSION=0.9.3
    wget -N http://www.lrz.de/services/software/mathematik/gsl/fortran/fgsl-${FGSL_VERSION}.tar.gz
    tar --extract --overwrite --gzip --verbose --file  fgsl-${FGSL_VERSION}.tar.gz
    cd fgsl-${FGSL_VERSION}
    ./configure --prefix ${FGSL_PREFIX}  --f90 gfortran --gsl ${GSL_PREFIX}
    make -j 1
    make install
    
    rm $DOWNLOAD_DIR/fgsl-${FGSL_VERSION}.tar.gz
    rm $DOWNLOAD_DIR/gsl-${GSL_VERSION}.tar.gz

    cd $PWD
    FGSL_INSTALLED=true
}

lapack_build() {

    PWD=`pwd`
    
    cd $DOWNLOAD_DIR
    wget -N ftp://netlib.org/lapack/lapack.tgz
    tar --extract --overwrite --gzip --verbose --file  lapack.tgz
    cd lapack-*
    
    # Write out the make.inc, putting your desired options here
    # Adapted from http://gcc.gnu.org/wiki/GfortranBuild
    echo '# -*-makefile-*- '  > make.inc
    echo '# Generated by "snapshot" script. ' >> make.inc
    echo 'SHELL     = /bin/sh' >> make.inc
    echo 'FORTRAN   = gfortran' >> make.inc
    echo 'OPTS      = -O2 -ggdb -mtune=pentium4' >> make.inc
    echo 'DRVOPTS   = $(OPTS)' >> make.inc
    echo 'NOOPT     = -O0' >> make.inc
    echo 'LOADER    = gfortran' >> make.inc
    echo 'LOADOPTS  = -O2 -ggdb -mtune=pentium4' >> make.inc
    echo 'TIMER     = INT_ETIME' >> make.inc
    echo 'ARCH      = ar' >> make.inc
    echo 'ARCHFLAGS = cr' >> make.inc
    echo 'RANLIB    = ranlib' >> make.inc
    echo 'BLASLIB   = ../../libblas.a' >> make.inc
    echo 'LAPACKLIB = liblapack.a' >> make.inc
    echo 'TMGLIB    = libtmglib.a' >> make.inc
    echo 'EIGSRCLIB = libeigsrc.a' >> make.inc
    echo 'LINSRCLIB = liblinsrc.a' >> make.inc

    # First build BLAS, then Lapack
    make cleanlib
    make blaslib
    make lib          # "make all" builds and runs TESTING directory also

    # Lapack doesn't come with "make install". We do it by ourselves
    mkdir -p $LAPACK_PREFIX
    cp -f lib*.a $LAPACK_PREFIX
    
    rm -rf $DOWNLOAD_DIR/lapack.tgz

    cd $PWD
    LAPACK_INSTALLED=true
}

fftw_build() {

    PWD=`pwd`
    
    cd $DOWNLOAD_DIR

    # Fetch the latest version number from the NEWS file
    BASE_URL=ftp://ftp.fftw.org/pub/fftw
    wget -N ${BASE_URL}/NEWS
    # The first line is of the format 
    # FFTW x.y.z
    # We get the second field (-f2) i.e., x.y.z, using space as delimiter (-d' ')
    FFTW_VERSION=`head -n1 NEWS | cut -f2 -d' ' -`
    wget -N ${BASE_URL}/fftw-${FFTW_VERSION}.tar.gz
    tar --extract --overwrite --gzip --verbose --file fftw-${FFTW_VERSION}.tar.gz
    cd fftw-*
    # --enable-single gives machine type mismatch error
    # --enable-openmp / --enable-threads are mutually exclusive
    ./configure --prefix=$FFTW_PREFIX --enable-static --disable-shared \
        --enable-sse2 --enable-mpi     \
        --enable-threads --enable-alloca
    make -j 1
    make install

    rm $DOWNLOAD_DIR/NEWS
    rm $DOWNLOAD_DIR/fftw-${FFTW_VERSION}.tar.gz
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
elif [ $1 == '--fgsl' ]; then
    fgsl_build
elif [ $1 == '--lapack' ]; then
    lapack_build
elif [ $1 == '--fftw' ]; then
    fftw_build
else
    usage
fi



