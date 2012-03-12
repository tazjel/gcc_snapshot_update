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
    
# This shell script fetches the source code of various software packages and
# automates the download-compile-install cycle. Latest version can be found at:
# https://github.com/bdsatish/gcc_snapshot_update/
#
# List of supported software is immediately below, see usage() function

set -e

usage() {
cat <<EOF
Usage:
  snapshot --d                # GCC-based D Compiler (GDC)
  snapshot --emacs            # install Emacs editor
  snapshot --fftw             # Fast Fourier Transforms in the West
  snapshot --fgsl             # Fortran bindings to GNU Scientific Library
  snapshot --gcc              # Fetch and build GCC weekly snapshot (C, Fortran)
  snapshot --gdb              # GNU Debugger snapshot
  snapshot --ginac            # Builds GiNaC C++ symbolic library
  snapshot --gmp              # GNU Multi-Precision library
  snapshot --lapack           # BLAS and Lapack  from Netlib
  snapshot --llvm             # LLVM with Clang compilers
  snapshot --mpc              # Multi-Precision Complex arithmetic library
  snapshot --mpfr             # Multi-Precision Floating Point library
  snapshot --numpy            # Numpy
  snapshot --octave           # Octave
  snapshot --openmpi          # Open MPI library
  snapshot --python           # Python 2.x interpreter
  snapshot --python3          # Python 3.x interpreter
  snapshot --scipy            # Scipy
  snapshot --update           # Fetch and apply patch to existing GCC snapshot
EOF
exit 1
}

# For those software whose versions are not given below, it means that their 
# latest versions are determined automatically.
GCC_VERSION=4.8         # <= 4.8
GDB_VERSION=7.3         # <= 7.3
OPENMPI_VERSION=1.4     # <= 1.5
GSL_VERSION=1.14        # <= 1.14
PY_VERSION=2.7.2        # <= 2.7.2
EMACS_VERSION=23.4      # <= 23.4
LLVM_VERSION=3.0        # >= 3.0

# Suggested to put ~/bin your ".profile" or equivalent start-up file
SYMLINK_BIN=$HOME/bin   # Shortcut to created executables (if any) will go here 

# Installation directories, change them if needed.
# These are just passed to --prefix of corresponding 'configure' script

INSTALL_DIR=$HOME/foss/installed
DOWNLOAD_DIR=$HOME/foss

GCC_PREFIX=$INSTALL_DIR/gcc          # ${GCC_PREFIX}/bin/gcc is the executable
GDB_PREFIX=$INSTALL_DIR/gdb          # ${GDB_PREFIX}/bin/gdb is the executable
GMP_PREFIX=$INSTALL_DIR/gmp          # ${GMP_PREFIX}/lib/libgmp.a is the library
MPFR_PREFIX=$INSTALL_DIR/mpfr        # ${MPFR_PREFIX}/lib/libmpfr.a is the library
MPC_PREFIX=$INSTALL_DIR/mpc          # ${MPC_PREFIX}/lib/libmpc.a is the library
CLOOG_PREFIX=$INSTALL_DIR/cloog      # ${CLOOG_PREFIX}/lib/libcloog.a is the library
PPL_PREFIX=$INSTALL_DIR/ppl          # ${PPL_PREFIX}/lib/libppl.a is the library
OMPI_PREFIX=$INSTALL_DIR/openmpi     # ${OMPI_PREFIX}/lib/libmpi.a is the library
                                     # ${OMPI_PREFIX}/bin/mpicc is the gcc wrapper
                                     
GSL_PREFIX=$INSTALL_DIR/gsl          # ${FGSL_PREFIX}/lib/libgsl.a
FGSL_PREFIX=$INSTALL_DIR/fgsl        # ${FGSL_PREFIX}/lib/libfgsl_xxx.a
LAPACK_PREFIX=$INSTALL_DIR/lapack    # liblapack.a AND libblas.a go here
FFTW_PREFIX=$INSTALL_DIR/fftw        # libfftw.a
GDC_PREFIX=$INSTALL_DIR/d            # ${GDC_PREFIX}/bin/gdc (or gdmd)
CLN_PREFIX=$INSTALL_DIR/cln          # ${CLN_PREFIX}/libcln.a is the library
GINAC_PREFIX=$INSTALL_DIR/ginac      # ${GINAC_PREFIX}/libginac.a is the library
PYTHON_PREFIX=$INSTALL_DIR/python    # ${PYTHON_PREFIX}/bin/python is the executable
EMACS_PREFIX=$INSTALL_DIR/emacs      # ../bin/emacs
LLVM_PREFIX=$INSTALL_DIR/llvm        # LLVM / Clang

# Global variables
GMP_INSTALLED=false
MPFR_INSTALLED=false
MPC_INSTALLED=false

#-------------------------- FUNCTION DEFINITIONS ONLY ------------------------------
# The actual script execution starts after all these definitions ! See below !

gmp_build() 
{
    if test -z "$1" || ! test "$1" == '--force' && test -e $GMP_PREFIX/lib/libgmp.la; then
          echo "GMP seems to be installed. To re-install, pass --force.";  return
    fi

    PWD=`pwd`
    cd $DOWNLOAD_DIR
    wget -N ftp://gcc.gnu.org/pub/gcc/infrastructure/gmp-*.tar.bz2
    tar --extract --overwrite --bzip2 --verbose --file gmp-*.tar.bz2

    cd gmp-*
    ./configure --prefix=$GMP_PREFIX --enable-static --disable-shared --enable-cxx
    make clean
    make -j 2
    make install

    rm -rf $DOWNLOAD_DIR/gmp-*.tar.bz2
    cd $PWD

}

mpfr_build() 
{
    if test -z "$1" || ! test "$1" == '--force' && test -e $MPFR_PREFIX/lib/libmpfr.la; then
          echo "MPFR seems to be installed. To re-install, pass --force.";  return
    fi

    gmp_build     # MPFR requires GMP

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
}

mpc_build() 
{
    if test -z "$1" || ! test "$1" == '--force' && test -e $MPC_PREFIX/lib/libmpc.la; then
          echo "MPC seems to be installed. To re-install, pass --force.";  return
    fi

    gmp_build            # MPC requires GMP, MPFR    
    mpfr_build

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

}

gcc_build() 
{
    if test -z "$1" || ! test "$1" == '--force' || test -z "$2" && test -e $GCC_PREFIX/bin/gcc; then
        echo "GCC seems to be installed. "
        echo "For example, to re-install C++, Ada and Fortran (C is built always): "
        echo "          ./snapshot  --gcc --force c++ ada fortran "
        echo "As of now, C, C++, Ada and Fortran are OK."
        return
    fi

    gpp=false
    gnat=false
    gfortran=false
    extra=""

    langs=c
    shift 1
    until test -z "$1"; do
      case "$1" in
        c++ | C++ ) 
              langs+=",c++"
              gpp=true
              ;;
        ada | Ada | ADA )
              gcc_vers=`gcc --version | head -n1 | cut -d' ' -f 3 | cut -c1-3`
              gnat_vers=`gnatmake --version | head -n1 | cut -d' ' -f 2 | cut -c1-3`
              if [ $gcc_vers != $gnat_vers ]; then
                  echo "GCC and GNAT versions are not identical."
                  echo "May be GNAT is not installed or a different version is installed."
                  echo "GCC Version:" $gcc_vers
                  echo "GNAT Version:" $gnat_vers
                  exit
              fi
              langs+=",ada"
              extra+=" --enable-libada "
              gnat=true
              # ada_dep_build         # Cloog anf PPL are for Ada
              ;;
        fortran| Fortran | FORTRAN )
              langs+=",fortran"
              gfortran=true
              ;;
        C | c )
            echo "C is built always ..." > /dev/null
              ;;
            * )
            echo "I do not know (or do not want to) build GCC for" "$1"
            exit
            ;;
      esac
      shift 1
    done

    gmp_build            # GCC requires GMP, MPFR and MPC 
    mpfr_build
    mpc_build

    PWD=`pwd`
    cd $DOWNLOAD_DIR
    
    # First line of README starts like:
    # Snapshot gcc-4.7-20110430 is now available on
    wget -O /tmp/README.gcc ftp://gcc.gnu.org/pub/gcc/snapshots/LATEST-$GCC_VERSION/README
    DATE=`cat /tmp/README.gcc | head -n 1 | cut -d' ' -f 2 | cut -d'-' -f 3`

    wget -N ftp://gcc.gnu.org/pub/gcc/snapshots/LATEST-$GCC_VERSION/gcc-$GCC_VERSION-$DATE.tar.bz2
    tar --extract --overwrite --bzip2 --verbose --file gcc-$GCC_VERSION-$DATE.tar.bz2

    rm -rf gcc-$GCC_VERSION
    mv gcc-$GCC_VERSION-$DATE gcc-$GCC_VERSION
    cd gcc-$GCC_VERSION

    # Remove everything except C, C++, Ada and Fortran (saves ~600 MB disk space)
    rm -rf boehm-gc libgo libjava libobjc libffi libitm
    rm -rf gcc/go gcc/java gcc/objc gcc/objcp
    rm -rf gcc/testsuite
    # rm -rf gnattools libada  gcc/ada       # Ada

    mkdir -p build
    cd build
   
    # Needed ?  --enable-fixed-point --with-long-double-128 --disable-lto
    ../configure --prefix=$GCC_PREFIX --enable-languages=$langs  --disable-multilib --disable-multiarch \
      --enable-checking=runtime --disable-libmudflap --enable-libgomp --disable-bootstrap \
      --enable-static --disable-shared --disable-decimal-float  --with-system-zlib  --disable-libitm \
      --disable-build-poststage1-with-cxx  --disable-build-with-cxx  --without-cloog --without-ppl \
      --disable-nls --enable-threads --enable-__cxa_atexit \
      --with-gmp=$GMP_PREFIX --with-mpfr=$MPFR_PREFIX --with-mpc=$MPC_PREFIX $extra 
    # For ClooG and PPL
    # --with-host-libstdcxx="Wl,-Bstatic,-lstdc++,-Bdynamic -lm" --with-ppl=$PPL_PREFIX --with-cloog=$CLOOG_PREFIX

    make clean
    make -j 2
    make install
    make distclean

    # export LDFLAGS=

    mkdir -p $SYMLINK_BIN
    ln -sfn $GCC_PREFIX/bin/gcc $SYMLINK_BIN/gcc
    ln -sfn $GCC_PREFIX/bin/gcc $SYMLINK_BIN/cc
    ln -sfn $GCC_PREFIX/bin/cpp $SYMLINK_BIN/cpp
    ln -sfn $GCC_PREFIX/bin/gcov $SYMLINK_BIN/gcov

    if [ $gfortran == true ]; then
      ln -sfn $GCC_PREFIX/bin/gfortran $SYMLINK_BIN/gfortran
    fi

    if [ $gpp == true ]; then
      ln -sfn $GCC_PREFIX/bin/g++ $SYMLINK_BIN/g++
      ln -sfn $GCC_PREFIX/bin/c++ $SYMLINK_BIN/c++
    fi

    if [ $gnat == true ]; then
      ln -sfn $GCC_PREFIX/bin/gnat $SYMLINK_BIN/gnat
      ln -sfn $GCC_PREFIX/bin/gnatbind $SYMLINK_BIN/gnatbind
      ln -sfn $GCC_PREFIX/bin/gnatchop $SYMLINK_BIN/gnatchop
      ln -sfn $GCC_PREFIX/bin/gnatclean $SYMLINK_BIN/gnatclean
      ln -sfn $GCC_PREFIX/bin/gnatfind $SYMLINK_BIN/gnatfind
      ln -sfn $GCC_PREFIX/bin/gnatkr $SYMLINK_BIN/gnatkr
      ln -sfn $GCC_PREFIX/bin/gnatlink $SYMLINK_BIN/gnatlink
      ln -sfn $GCC_PREFIX/bin/gnatls $SYMLINK_BIN/gnatls
      ln -sfn $GCC_PREFIX/bin/gnatmake $SYMLINK_BIN/gnatmake
      ln -sfn $GCC_PREFIX/bin/gnatname $SYMLINK_BIN/gnatname
      ln -sfn $GCC_PREFIX/bin/gnatprep $SYMLINK_BIN/gnatprep
      ln -sfn $GCC_PREFIX/bin/gnatxref $SYMLINK_BIN/gnatxref
    fi

    rm -rf $DOWNLOAD_DIR/gcc-core-*.tar.bz2
    rm -rf $DOWNLOAD_DIR/gcc-fortran-*.tar.bz2
    rm -rf $DOWNLOAD_DIR/gcc-testsuite-*.tar.bz2
    rm -rf $DOWNLOAD_DIR/gcc-g++-*.tar.bz2
    rm -rf $DOWNLOAD_DIR/gcc-$GCC_VERSION-$DATE.tar.bz2

    cd $PWD

}

gcc_update() 
{
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

gdb_build() 
{
    if test -z "$1" || ! test "$1" == '--force' && test -e $GDB_PREFIX/bin/gdb; then
          echo "GDB seems to be installed. To re-install, pass --force.";  return
    fi

    gmp_build            # GDB requires GMP, MPFR and MPC 
    mpfr_build
    mpc_build

    PWD=`pwd`
    cd $DOWNLOAD_DIR
    wget -N --retr-symlinks ftp://gcc.gnu.org/pub/gdb/snapshots/current/gdb.tar.bz2
    tar --extract --overwrite --bzip2 --verbose --file gdb.tar.bz2

    rm -rf gdb-$GDB_VERSION
    mv -f gdb-$GDB_VERSION* gdb-$GDB_VERSION
    cd gdb-$GDB_VERSION

    ./configure --prefix=$GDB_PREFIX --enable-languages=c,fortran,c++,python --disable-bootstrap \
      --enable-libquadmath --enable-libquadmath-support --disable-libssp  --with-python \
        --disable-build-poststage1-with-cxx  --disable-build-with-cxx  \
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

openmpi_build() 
{
    if test -z "$1" || ! test "$1" == '--force' && test -e $OMPI_PREFIX/bin/mpicc; then
          echo "OpenMPI seems to be installed. To re-install, pass --force.";  return
    fi

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
    MAX_ARRAY_DIM=2    # max 2D arrays are supported, can be up to 7
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

fgsl_build() 
{

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

lapack_build() 
{
    if test -z "$1" || ! test "$1" == '--force' && test -e $LAPACK_PREFIX/lib/liblapack.a; then
          echo "LAPACK seems to be installed. To re-install, pass --force.";  return
    fi

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
    echo 'OPTS      = -O3 -march=native -funroll-loops -fPIC' >> make.inc
    echo 'DRVOPTS   = $(OPTS)' >> make.inc
    echo 'NOOPT     = -O0 -ggdb -fPIC' >> make.inc
    echo 'LOADER    = gfortran' >> make.inc
    echo 'LOADOPTS  = -O3 -march=native -funroll-loops -fPIC' >> make.inc
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

fftw_build() 
{
    if test -z "$1" || ! test "$1" == '--force' && test -e $FFTW_PREFIX/lib/libfftw3.la; then
          echo "FFTW seems to be installed. To re-install, pass --force.";  return
    fi

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

    cd $PWD
    FFTW_INSTALLED=true
}

gdc_build()
{
    if test -z "$1" || ! test "$1" == '--force' && test -e $GDC_PREFIX/bin/gdc; then
          echo "GDC seems to be installed. To re-install, pass --force.";  return
    fi

    gmp_build            # GDC requires GMP, MPFR and MPC 
    mpfr_build
    mpc_build

    PWD=`pwd`
    GCC_BASE=4.6.2   # GCC version used to build D

    cd $DOWNLOAD_DIR
    rm -rf goshawk-gdc-* gdc
    
    wget -N  https://bitbucket.org/goshawk/gdc/get/tip.tar.gz  -O gdc.tar.gz
    tar --extract --overwrite --gzip --verbose --file gdc.tar.gz
    mv  goshawk-gdc-* gdc
    mkdir gdc/dev
    cd gdc/dev

    wget -N ftp://gcc.gnu.org/pub/gcc/releases/gcc-$GCC_BASE/gcc-core-$GCC_BASE.tar.bz2
    wget -N ftp://gcc.gnu.org/pub/gcc/releases/gcc-$GCC_BASE/gcc-g++-$GCC_BASE.tar.bz2

    tar --extract --overwrite --bzip2 --verbose --file gcc-core-$GCC_BASE.tar.bz2
    tar --extract --overwrite --bzip2 --verbose --file gcc-g++-$GCC_BASE.tar.bz2

    rm gcc-*.tar.bz2

    cd gcc-$GCC_BASE
    ln -s ../../../d gcc/d
    ./gcc/d/setup-gcc.sh -v2

    mkdir objdir
    cd objdir 
    ../configure --prefix=$GDC_PREFIX --enable-languages=d --disable-multiarch \
                 --disable-multilib --disable-shared --enable-checking=release \
                 --disable-bootstrap --disable-nls --disable-libgomp --enable-static \
                 --disable-decimal-float --with-system-zlib --disable-libmudflap \
                 --with-gmp=$GMP_PREFIX --with-mpfr=$MPFR_PREFIX --with-mpc=$MPC_PREFIX \
                 --with-bugurl="https://bitbucket.org/goshawk/gdc/issues"

    make -j2
    make install

    ln -sfn $GDC_PREFIX/bin/gdc $SYMLINK_BIN/gdc
    ln -sfn $GDC_PREFIX/bin/gdmd $SYMLINK_BIN/gdmd

    rm $DOWNLOAD_DIR/gdc.tar.gz

    cd $PWD
    GDC_INSTALLED=true
}

cln_build()
{
    if test -z "$1" || ! test "$1" == '--force' && test -e $GMP_PREFIX/lib/libcln.la; then
          echo "CLN seems to be installed. To re-install, pass --force.";  return
    fi

    gmp_build        # CLN requires GMP

    PWD=`pwd`
    cd $DOWNLOAD_DIR
    wget --no-remove-listing ftp://ftpthep.physik.uni-mainz.de/pub/gnu/
  
    # The last 3rd line in the ".listing" file is the latest one, download that
    CLN_BASE=`cat .listing | tail -n3 | head -n1 | cut -c57-`
    CLN_VERSION=`echo $CLN_BASE | cut -c5-9`
    wget -N ftp://ftpthep.physik.uni-mainz.de/pub/gnu/$CLN_BASE
    tar --extract --overwrite --bzip2 --verbose --file $CLN_BASE
    rm -rf .listing index.html

    cd cln-$CLN_VERSION
    ./configure --prefix=$CLN_PREFIX --with-gmp=$GMP_PREFIX   --with-pic  \
                --enable-static --disable-shared --disable-dependency-tracking
    make -j2
    make install

    rm -rf $DOWNLOAD_DIR/$CLN_BASE

    cd $PWD
    CLN_INSTALLED=true
}

ginac_build()
{
    cln_build             # GiNaC requires CLN

    PWD=`pwd`

    export CLN_LIBS="-L$CLN_PREFIX/lib -lcln"
    export CLN_CFLAGS="-I$CLN_PREFIX/include "


    cd $DOWNLOAD_DIR
    wget --no-remove-listing ftp://ftpthep.physik.uni-mainz.de/pub/GiNaC/
  
    # The last 3rd line in the ".listing" file is the latest one, download that
    # -rw-r--r--    1 1024     102       1048764 Nov  6 13:20 ginac-1.6.2.tar.bz2
    GINAC_BASE=`cat .listing | tail -n3 | head -n1 | cut -c57-`
    GINAC_VERSION=`echo $GINAC_BASE | cut -c7-11`
  
    wget -N ftp://ftpthep.physik.uni-mainz.de/pub/GiNaC/$GINAC_BASE
    tar --extract --overwrite --bzip2 --verbose --file $GINAC_BASE
    rm -rf .listing index.html

    cd ginac-$GINAC_VERSION
    ./configure --prefix=$GINAC_PREFIX --disable-dependency-tracking \
                --with-pic --enable-static --disable-shared 
    make -j2
    make install

    rm -rf $DOWNLOAD_DIR/$GINAC_BASE
    cd $PWD

    GINAC_INSTALLED=true
}

octave_build()
{

#export CXXFLAGS="-I$HOME/foss/installed/fftw/include"
#export CFLAGS="-I$HOME/foss/installed/fftw/include"
#export LDFLAGS="-L$HOME/foss/installed/fftw/lib"
# --disable-shared --disable-dl --enable-static 
./configure --prefix=$HOME/foss/installed/octave   --with-pic \
  --with-blas="-L$HOME/foss/installed/lapack -lblas" --with-lapack="-L$HOME/foss/installed/lapack -llapack" 
#  --without-amd --without-camd --without-colamd  --without-ccolamd --without-cholmod  --without-cxsparse  --without-umfpack  \
#  --without-hdf5
}

python_build()
{
    PWD=`pwd`
    cd $DOWNLOAD_DIR

    wget -N http://www.python.org/ftp/python/$PY_VERSION/Python-$PY_VERSION.tgz
    tar --extract --overwrite --gzip --verbose --file Python-$PY_VERSION.tgz
    cd Python-$PY_VERSION
  
    ./configure --prefix=$PYTHON_PREFIX --with-threads --enable-static --disable-shared --with-fpectl 
    make -j2
    make install

    rm -rf $DOWNLOAD_DIR/Python-$PY_VERSION $DOWNLOAD_DIR/Python-$PY_VERSION.tgz
    cd $PWD

    PYTHON_INSTALLED=true

}

numpy_build()
{
    PWD=`pwd`
    cd $DOWNLOAD_DIR

    wget -N http://sourceforge.net/projects/numpy/files/latest/download
    mv download numpy.tar.gz
    tar --extract --overwrite --gzip --verbose --file numpy.tar.gz
    
    cd numpy-*

    # Python version of where to find Python.h
    py_vers=`echo $PY_VERSION | cut -c1-3`
    echo $py_vers
    cat > site.cfg <<_EOF
[DEFAULT]
library_dirs = $PYTHON_PREFIX/lib:$LAPACK_PREFIX:$FFTW_PREFIX/lib
include_dirs = $PYTHON_PREFIX/include/python$py_vers:$FFTW_PREFIX/include
search_static_first = 1

[blas_opt]
libraries = blas

[lapack_opt]
libraries = lapack

[fftw]
libraries = fftw3

_EOF

    python setup.py build
    python setup.py install --prefix $PYTHON_PREFIX
    rm -rf $DOWNLOAD_DIR/numpy.at.gz $DOWNLOAD_DIR/numpy-*
    cd $PWD

    NUMPY_INSTALLED=true
}

scipy_build()
{
    PWD=`pwd`

    cd $DOWNLOAD_DIR

    wget -N http://sourceforge.net/projects/scipy/files/latest/download
    mv download scipy.tar.gz
    tar --extract --overwrite --gzip --verbose --file scipy.tar.gz
    
    cd scipy-*

    python setup.py build
    python setup.py install --prefix $PYTHON_PREFIX
    rm -rf $DOWNLOAD_DIR/scipy.tar.gz $DOWNLOAD_DIR/scipy-*

    cd $PWD

    SCIPY_INSTALLED=true

}

# ada_dep_build: Builds PPL and ClooG libraries
ada_dep_build()
{
    # if PPL is already installed, just return (unless you pass --force, 
    # in which case, I'll silently install)
    if test -z "$1" || ! test "$1" == '--force' && test -e $PPL_PREFIX/lib/libppl.la; then
          echo "PPL seems to be installed."
    else      # Forcing install ...
      PWD=`pwd`
      cd $DOWNLOAD_DIR
      wget -N ftp://gcc.gnu.org/pub/gcc/infrastructure/ppl-0.11.tar.gz
      tar --extract --overwrite --gzip --verbose --file ppl-0.11.tar.gz
      rm -rf ppl
      mv ppl-0.11 ppl

      gmp_options="-I$GMP_PREFIX/include -L$GMP_PREFIX/lib"
      cd ppl
      ./configure --prefix=$PPL_PREFIX --with-pic --with-cflags="$gmp_options"  \
                  --with-cxxflags="$gmp_options" --enable-static --disable-shared
      make -j2
      make install
      # rm -rf $DOWNLOAD_DIR/ppl-0.11.tar.gz

      cd $PWD
    fi

    # if Cloog is already installed, just return (unless you pass --force, 
    # in which case, I'll silently install)
    if test -z "$1" || ! test "$1" == '--force' && test -e $CLOOG_PREFIX/lib/libcloog.la; then
          echo "CLOOG seems to be installed."
    else      # Forcing install ...
      PWD=`pwd`
      cd $DOWNLOAD_DIR
      wget -N ftp://gcc.gnu.org/pub/gcc/infrastructure/cloog-ppl-0.15.11.tar.gz
      tar --extract --overwrite --gzip --verbose --file cloog-ppl-0.15.11.tar.gz
      rm -rf cloog-ppl
      mv cloog-ppl-0.15.11 cloog-ppl

      cd cloog-ppl
      export LDFLAGS="-lm"
      ./configure --prefix=$CLOOG_PREFIX --with-pic --enable-static --disable-shared \
                  --with-gmp="$GMP_PREFIX"  --with-ppl=$PPL_PREFIX

      make -j2
      make install

      export LDFLAGS=
      cd $PWD
      CLOOG_PPL_INSTALLED=true

    # rm -rf $DOWNLOAD_DIR/cloog-ppl-0.15.11.tar.gz
    fi

}

emacs_build()
{
    PWD=`pwd`

    cd $DOWNLOAD_DIR  
    wget -N  ftp://ftp.gnu.org/gnu/emacs/emacs-$EMACS_VERSION.tar.bz2
    tar --extract --overwrite --bzip2 --verbose --file emacs-$EMACS_VERSION.tar.bz2

    # aptitude install libxft2 libxft2-dev libxaw7-dev libjpeg62-dev libgif-dev libtiff4-dev libxaw3dxft6 libxaw7-dev libxaw7
    # NO POINT installing Xaw3d -- even if it is present, configure says 'no'
    # If you don't want image support: -with-xpm=no --with-jpeg=no --with-gif=no --with-tiff=no
    cd emacs-$EMACS_VERSION
    ./configure --prefix=$EMACS_PREFIX  \
                --with-x --with-x-tookit=athena  --with-xft  --with-dbus
    make -j2
    make install

    rm -rf $DOWNLOAD_DIR/emacs-$EMACS_VERSION.tar.bz2
    cd $PWD

    EMACS_INSTALLED=true
}

llvm_build()
{
		PWD=`pwd`

		cd $DOWNLOAD_DIR
		wget -N http://llvm.org/releases/$LLVM_VERSION/llvm-$LLVM_VERSION.tar.gz
		wget -N http://llvm.org/releases/$LLVM_VERSION/clang-$LLVM_VERSION.tar.gz

    tar --extract --overwrite --gzip --verbose --file llvm-$LLVM_VERSION.tar.gz
    tar --extract --overwrite --gzip --verbose --file clang-$LLVM_VERSION.tar.gz

		# clang dir must go into LLVM_SRC_DIR/tools/clang
		mv clang-$LLVM_VERSION.src/ llvm-$LLVM_VERSION.src/tools/clang

		cd llvm-$LLVM_VERSION.src
		./configure --prefix=$LLVM_PREFIX --enable-targets=host --enable-optimized \
				        --enable-pthreads --enable-pic --disable-docs --disable-shared
		make -j4
		make install

		# clang is automatically built, but not installed. We do it specifically:
		cd tools/clang
		make install

		rm -rf  $DOWNLOAD_DIR/llvm-$LLVM_VERSION.tar.gz $DOWNLOAD_DIR/clang-$LLVM_VERSION.tar.gz
    cd $PWD

    LLVM_INSTALLED=true
}


#------------------------- EXECUTION STARTS HERE --------------------------

#  Issue usage if no parameters are given.
test $# -eq 0 && usage

# For 64-bit machines, "-fPIC" is the magic solution :-)
machine=`uname -m`
if [ $machine == x86_64 ]; then 
  export CFLAGS=" -fPIC "
  export CXXFLAGS=" -fPIC "
  export FFLAGS=" -fPIC "
  export FCFLAGS=" -fPIC "
  export FCFLAGS_f90=" -fPIC "
  export FCFLAGS_F90=" -fPIC "
fi

if [[ $1 == '--gcc' ]]; then
    gcc_build $2 $3 $4 $5 $6 $7
elif [ $1 == '--update' ]; then
    gcc_update $2
elif [ $1 == '--gdb' ]; then
    gdb_build $2
elif [ $1 == '--emacs' ]; then
    emacs_build $2
elif [ $1 == '--openmpi' ]; then
    openmpi_build $2
elif [ $1 == '--gmp' ]; then
    gmp_build $2
elif [ $1 == '--mpfr' ]; then
    mpfr_build $2
elif [ $1 == '--mpc' ]; then
    mpc_build $2
elif [ $1 == '--fgsl' ]; then
    fgsl_build $2
elif [ $1 == '--lapack' ]; then
    lapack_build $2
elif [ $1 == '--fftw' ]; then
    fftw_build $2
elif [ $1 == '--d' ]; then
    gdc_build $2 
elif [ $1 == '--ginac' ]; then
    ginac_build $2
elif [ $1 == '--llvm' ]; then
		llvm_build $2
elif [ $1 == '--octave' ]; then
    octave_build $2
elif [ $1 == '--python' ]; then
    python_build $2
elif [ $1 == '--numpy' ]; then
    numpy_build $2
elif [ $1 == '--scipy' ]; then
    scipy_build $2
elif [ $1 == '--ipython' ]; then
    easy_install ipython[zmq]
elif [ $1 == '--matplotlib' ]; then
    pip install matplotlib
    echo "Replace backend_qt4.py if u encounter any error"
elif [ $1 == '--ada-dep' ]; then
    ada_dep_build $2
elif [ $1 == '--pyqt4' ]; then
    echo apt-get install libqt4-dev libqt4-gui
    echo Download SIP first and install it:
    echo [1] python configure.py
    echo [2] make 
    echo [3] make install
    echo Repeat [1]-[3] for PyQt4
else
    echo 'Unrecognized option: "$1"'
    echo ""
    usage
fi



