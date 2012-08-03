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
  $me --cmake            # Install CMake build tool
  $me --d                # GCC-based D Compiler (GDC)
  $me --emacs            # install Emacs editor
  $me --lisp             # ECL -- embeddable common lisp
  $me --fftw             # Fast Fourier Transforms in the West
  $me --fgsl             # Fortran bindings to GNU Scientific Library
  $me --gcc              # Fetch and build GCC weekly snapshot (C, Fortran)
  $me --gdb              # GNU Debugger snapshot
  $me --ginac            # Builds GiNaC C++ symbolic library
  $me --gmp              # GNU Multi-Precision library
  $me --lapack           # BLAS and Lapack  from Netlib
  $me --llvm             # LLVM with Clang compilers
  $me --mpc              # Multi-Precision Complex arithmetic library
  $me --mpfr             # Multi-Precision Floating Point library
  $me --numpy            # Numpy
  $me --octave           # Octave
  $me --openmpi          # Open MPI library
  $me --pari-gp          # Pari/GP number theory CAS
  $me --pure             # Pure programming language, interpreter
  $me --python           # Python 2.x interpreter
  $me --python3          # Python 3.x interpreter
  $me --scipy            # Scipy
  $me --update           # Fetch and apply patch to existing GCC snapshot
  $me --valgrind         # Valgrind memory checker
EOF
exit 1
}

me=$(basename $0)

# For those software whose versions are not given below, it means that their 
# latest versions are determined automatically.
GCC_VERSION=4.7         # <= 4.8
GDB_VERSION=7.3         # <= 7.3
OPENMPI_VERSION=1.4     # <= 1.5
GSL_VERSION=1.14        # <= 1.14
PY_VERSION=2.7.3        # <= 2.7.3 or <= 3.2.3
EMACS_VERSION=23.4      # <= 23.4
LLVM_VERSION=3.1        # >= 3.1
BOOST_VERSION=1.49.0    # like 1.xx.0 where xx=31 to 49
CMAKE_VERSION=v2.8          # Latest in this series will be downloaded, like 2.8.7

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
ECL_PREFIX=$INSTALL_DIR/ecl          # Embeddable common lisp
BOEHM_PREFIX=$INSTALL_DIR/boehmgc    # ./lib/libgc.a
OCTAVE_PREFIX=$INSTALL_DIR/octave    
FLTK_PREFIX=$INSTALL_DIR/fltk 

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

#     OLD_CFLAGS=${CFLAGS}
#     export CFLAGS="${OLD_CFLAGS} -fpermissive -std=c99"
#     OLD_CXXFLAGS=${CXXFLAGS}
#     export CXXFLAGS="${OLD_CXXFLAGS} -fpermissive -std=c++03"

    CWD=`pwd`
    cd $DOWNLOAD_DIR
    rm -f index.html* .listing
    wget --no-remove-listing  ftp://ftp.gmplib.org/pub/
    # Last but 3rd line is the latest one
    local folder=$(cat .listing | tail -n3 | head -n1 | cut -d' ' -f16)

    rm -rf ${folder}
    wget -N ftp://ftp.gmplib.org/pub/${folder}/${folder}.tar.bz2
    tar --extract --overwrite --bzip2 --verbose --file ${folder}.tar.bz2

    cd ${folder}
    # Stupid hack to replace exit(0) with return(0) else the compiler will shout exit() not declared
#     sed -i 's/exit(/return(/g' ./configure
#     sed -i 's/exit (0)/return (0)/g' ./configure
    ./configure --prefix=$GMP_PREFIX --enable-static --disable-shared --enable-cxx
    make -j 2
    make install

#     export CFLAGS=${OLD_CFLAGS}
#     export CXXFLAGS=${OLD_CXXFLAGS}
    rm -rf $DOWNLOAD_DIR/${folder}.tar.bz2
    cd $CWD

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
        echo "          ./$me  --gcc --force c++ ada fortran "
        echo ""
        echo "To install the latest STABLE version (instead of latest snapshot):"
        echo "          ./$me  --gcc --force --stable c++ ada fortran "
        echo "As of now, C, C++, Ada and Fortran are OK."
        return
    fi

    # export CXXFLAGS+=" -fno-exceptions -fno-rtti "

    gpp=false
    gnat=false
    gfortran=false
    extra=""

    local langs=c
    local stable=false
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
        java | Java | JAVA)
              langs+=",java"
              ;;
        C | c )
            echo "C is built always ..." > /dev/null
              ;;
      --stable)
           stable=true
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
    
    if [[ $stable == false ]]; then
        # First line of README starts like:
        # Snapshot gcc-4.7-20110430 is now available on
        wget -O /tmp/README.gcc ftp://gcc.gnu.org/pub/gcc/snapshots/LATEST-$GCC_VERSION/README
        DATE=`cat /tmp/README.gcc | head -n 1 | cut -d' ' -f 2 | cut -d'-' -f 3`

        wget -N ftp://gcc.gnu.org/pub/gcc/snapshots/LATEST-$GCC_VERSION/gcc-$GCC_VERSION-$DATE.tar.bz2
        tar --extract --overwrite --bzip2 --verbose --file gcc-$GCC_VERSION-$DATE.tar.bz2

        rm -rf gcc-$GCC_VERSION
        mv gcc-$GCC_VERSION-$DATE gcc-$GCC_VERSION
        cd gcc-$GCC_VERSION
        rm -rf /tmp/README.gcc
    else
        wget --dont-remove-listing ftp://ftp.gnu.org/gnu/gcc/
        # Last 5th line is always latest stable
        latest=`cat .listing | tail -n5 | head -n1 | cut -f24 -d' '`
        latest=`echo $latest | tr -d '\r'`      # Delete newline char
        wget -N ftp://ftp.gnu.org/gnu/gcc/$latest/$latest.tar.bz2
        tar --extract --overwrite --bzip2 --verbose --file $latest.tar.bz2
        cd $latest
        rm -rf .listing index.html
    fi

    # Remove everything except C, C++, Ada and Fortran (saves ~600 MB disk space)
    rm -rf boehm-gc gcc/java  libjava libffi libitm # Java
    rm -rf gcc/go libgo gcc/objc libobjc gcc/objcp
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
    rm -rf ${GCC_PREFIX}        # Do not delete until 'make install' succeeds
    make install                # If it does, then redo 'make install'
    # make distclean

    # export LDFLAGS=

    mkdir -p $SYMLINK_BIN
    ln -sfn $GCC_PREFIX/bin/gcc $SYMLINK_BIN/gcc
    ln -sfn $GCC_PREFIX/bin/gcc $SYMLINK_BIN/cc
    ln -sfn $GCC_PREFIX/bin/cpp $SYMLINK_BIN/cpp
    ln -sfn $GCC_PREFIX/bin/gcov $SYMLINK_BIN/gcov

    # The following is the shared library version of libgcc.a but since
    # we are passing --disable-shared, clang++ cannot find it.
    # Instead pass -static-libgcc to clang

    # ln -sfn /lib/libgcc_s.so.1 $GCC_PREFIX/lib/libgcc_s.so

    # For --disable-shared, we don't generate libgcc_eh.a but all of its functions
    # are included in libgcc.a itself. And libc always links with libgcc_eh.a, so we just symlink it
    libgccfolder=$(find $GCC_PREFIX -name libgcc.a)
    libgccfolder=`dirname ${libgccfolder}`
    ln -sfn ${libgccfolder}/libgcc.a ${libgccfolder}/libgcc_eh.a


    ln -sfn $GCC_PREFIX/lib/libgcc.a $GCC_PREFIX/lib/libgcc_s.so

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

    exit

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
    # --disable-mpi-cxx --disable-mpi-cxx-seek 
    ./configure --prefix=$OMPI_PREFIX --enable-static --disable-shared \
            --enable-mpi-threads --with-pic \
            --without-memory-manager --without-libnuma  \
            --with-f90-max-array-dim=${MAX_ARRAY_DIM} \
            --with-wrapper-cflags=${LONG_DOUBLE}      \
            --with-wrapper-cxxflags=${LONG_DOUBLE}  

    make clean
    make -j 2
    make install

    mkdir -p $SYMLINK_BIN
    ln -sfn $OMPI_PREFIX/bin/mpicc  $SYMLINK_BIN/mpicc
    ln -sfn $OMPI_PREFIX/bin/mpic++ $SYMLINK_BIN/mpic++
    ln -sfn $OMPI_PREFIX/bin/mpiCC  $SYMLINK_BIN/mpiCC
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
    cat > make.inc << _EOF
# -*-makefile-*-
# Generated by "snapshot" script.
SHELL     = /bin/sh
FORTRAN   = gfortran
OPTS      = -O3 -march=native -funroll-loops -finline-limit=600 -fwhole-program -flto -fstack-arrays  -fno-protect-parens -fPIC
DRVOPTS   = $(OPTS)
NOOPT     = -O0 -ggdb -fPIC
LOADER    = gfortran
LOADOPTS  = -O3 -march=native -funroll-loops -finline-limit=600 -fwhole-program -flto -fstack-arrays  -fno-protect-parens -fPIC
TIMER     = INT_ETIME
ARCH      = ar 
ARCHFLAGS = cr
RANLIB    = ranlib
BLASLIB   = ../../libblas.a
LAPACKLIB = liblapack.a
TMGLIB    = libtmglib.a
EIGSRCLIB = libeigsrc.a
LINSRCLIB = liblinsrc.a
_EOF

    # First build BLAS, then Lapack
    make cleanlib
    make -j8 blaslib
    make -j8 lib          # "make all" builds and runs TESTING directory also

    # If build fails, add "-L.. -lblas" to every of INSTALL/Makefile 
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
    GCC_BASE=4.6.3   # GCC version used to build D

    cd $DOWNLOAD_DIR
    rm -rf goshawk-gdc-* gdc
    
    wget https://bitbucket.org/goshawk/gdc/get/default.tar.gz -O gdc.tar.gz
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
    if test -z "$1" || ! test "$1" == '--force' && test -x $OCTAVE_PREFIX/bin/octave; then
          echo "Octave seems to be installed. To re-install, pass --force.";  return
    fi

    PWD=`pwd`
    cd $DOWNLOAD_DIR

    wget -N http://ftp.gnu.org/gnu/octave/
    local file=$(html2text index.html | tail -n5 | head -n1 | cut -d' ' -f5)
    rm -f index.html
    local folder=$(basename $file .tar.gz)         # strip the extension .tar.gz from $file
    local version=$(echo $folder | cut -d'-' -f2)  # Like 3.6.1

    wget -N http://ftp.gnu.org/gnu/octave/$file
    tar --extract --overwrite --gzip --verbose --file $file
    rm -rf octave
    mv $folder octave
    cd octave

#export CXXFLAGS="-I$HOME/foss/installed/fftw/include"
#export CFLAGS="-I$HOME/foss/installed/fftw/include"
#export LDFLAGS="-L$HOME/foss/installed/fftw/lib"
# --disable-shared --disable-dl --enable-static 
    ./configure --prefix=$OCTAVE_PREFIX/bin/octave  --with-pic --disable-dependency-tracking --disable-largefile \
      --enable-openmp  \
      --with-blas="-L$HOME/foss/installed/lapack -lblas" --with-lapack="-L$HOME/foss/installed/lapack -llapack" 
#  --without-amd --without-camd --without-colamd  --without-ccolamd --without-cholmod  --without-cxsparse  --without-umfpack  \
#  --without-hdf5

    make -j2
    make install

    rm -rf $DOWNLOAD_DIR/$file
    cd $PWD
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
    if test -z "$1" || ! test "$1" == '--force' && test -e $LLVM_PREFIX/bin/clang; then
          $LLVM_PREFIX/bin/clang --version
          echo "LLVM/Clang seems to be installed. To re-install, pass --force.";  return
    fi

    local CWD=`pwd`

    cd $DOWNLOAD_DIR
    wget -N http://llvm.org/releases/$LLVM_VERSION/llvm-$LLVM_VERSION.src.tar.gz
    wget -N http://llvm.org/releases/$LLVM_VERSION/clang-$LLVM_VERSION.src.tar.gz

    rm -rf llvm-$LLVM_VERSION.src
    tar --extract --overwrite --gzip --verbose --file llvm-$LLVM_VERSION.src.tar.gz
    tar --extract --overwrite --gzip --verbose --file clang-$LLVM_VERSION.src.tar.gz

    # Do not build with clang, instead force to build with GCC toolchain
    export CC=$GCC_PREFIX/bin/gcc
    export CXX=$GCC_PREFIX/bin/g++
    export CPP=$GCC_PREFIX/bin/cpp
    export ONLY_TOOLS=true           # Do not build unittests

    local gcc_vers=$(gcc --version | head -n1 | cut -d' ' -f3)  # Parse GCC version

    # clang dir must go into LLVM_SRC_DIR/tools/clang
    mv clang-$LLVM_VERSION.src/ llvm-$LLVM_VERSION.src/tools/clang


    cd llvm-$LLVM_VERSION.src

    #  --with-optimize-option="-O3 -march=native -funroll-loops"
    # See also: http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=645546
    ./configure --prefix=$LLVM_PREFIX --enable-targets=host --enable-optimized --disable-assertions     \
                --enable-threads --enable-pic --disable-docs --disable-shared \
                --with-gcc-toolchain=$GCC_PREFIX --with-cxx-include-root=$GCC_PREFIX/include/c++/$gcc_vers
    make -j4
    make install

    # clang is automatically built, but not installed. We do it specifically:
    cd tools/clang
    make install
    make distclean

    cd ../..
    make distclean

    # May be put these in .bash_aliases ?
    #     alias clang="clang -static-libgcc"
    #     alias clang++="clang++ -static-libgcc -static-libstdc++"


    rm -rf  $DOWNLOAD_DIR/llvm-$LLVM_VERSION.src.tar.gz $DOWNLOAD_DIR/clang-$LLVM_VERSION.src.tar.gz
    cd $CWD

    LLVM_INSTALLED=true
}

boost_build()
{
    PWD=`pwd`

    cd $DOWNLOAD_DIR

    # string replace 1.49.0 --> 1_49_0
    DIRNAME=boost_${BOOST_VERSION//./_}
    wget -N http://sourceforge.net/projects/boost/files/boost/$BOOST_VERSION/$DIRNAME.tar.bz2/download
    tar --extract --overwrite --bzip2 --verbose --file $DIRNAME.tar.bz2

    cd $DIRNAME
    ./boostrap.sh --prefix=$BOOST_PREFIX

    # OpenMPI support added, if mpic++ exists
    if [ -x $OMPI_PREFIX/bin/mpic++ ]; then
        echo "using mpi : $OMPI_PREFIX/bin/mpic++ ;" >> tools/build/v2/user-config.jam
    fi

    # Compile and install (b2 is same as bjam)
    ./b2 link=static  runtime-link=static install

    # Boost.Build separately
    cd tools/build/v2
    ./bootstrap.sh
    ./b2 install --prefix=$BOOST_PREFIX

    # Download and install the PDF documentation
    # Stupid guys: instead of naming it as boost_1_49_0_pdf they just say boost_1_49_pdf !
    DOC=${DIRNAME:0:10}_pdf      # extract first 10 char from DIRNAME
    http://sourceforge.net/projects/boost/files/boost-docs/$BOOST_VERSION/$DOC.zip/download
    unzip $DOC
    mv $DOC/ $BOOST_PREFIX/pdf
    rm -rf $DOC.zip

    rm -rf  $DOWNLOAD_DIR/$DIRNAME.tar.bz2
    cd $PWD

    BOOST_INSTALLED=true
}

boehm_build()
{
    if test -z "$1" || ! test "$1" == '--force' && test -e $BOEHM_PREFIX/lib/libgc.a; then
          echo "Boehm seems to be installed. To re-install, pass --force.";  return
    fi

    PWD=`pwd`

    cd $DOWNLOAD_DIR

    rm -rf boehmgc
    wget -N https://github.com/ivmai/bdwgc/zipball/master
    mv master boehm.zip
    unzip boehm.zip
    mv -f ivmai-*  boehmgc

    wget -N https://github.com/ivmai/libatomic_ops/zipball/master
    mv master libatomic_ops.zip
    unzip libatomic_ops.zip
    mv -f ivmai-*  boehmgc/libatomic_ops
    ./boehmgc/libatomic_ops/autogen.sh

    cd boehmgc
    ./autogen.sh
    ./configure --prefix=$BOEHM_PREFIX --with-pic --disable-gcj-support --enable-cplusplus \
                --disable-dependency-tracking --enable-static --disable-shared
    
    make -j4
    make install

    rm -rf  $DOWNLOAD_DIR/ivmai-*.zip
    cd $PWD

    BOEHM_INSTALLED=true
}

ecl_build()
{
    if test -z "$1" || ! test "$1" == '--force' && test -e $ECL_PREFIX/bin/ecl; then
          echo "ECL seems to be installed. To re-install, pass --force.";  return
    fi

    gmp_build
    # A copy of BOEHM GC is included in ecl/gc folder, will be automatically built

    PWD=`pwd`

    cd $DOWNLOAD_DIR

    rm -rf ecl
    wget -N http://sourceforge.net/projects/ecls/files/latest/download
    mv download ecl.tar.gz
    tar --extract --overwrite --gzip --file ecl.tar.gz
    mv -f ecl-*  ecl

    cd ecl
    ./configure --prefix=$ECL_PREFIX  --with-gmp-prefix=$GMP_PREFIX --with-sse=yes \
                --enable-longdouble --enable-c99complex --enable-threads           \
                --enable-boehm=included --disable-shared
    
    make -j1     # -j4 seems to fail because of cyclic dependencies
    make install

    rm -rf  $DOWNLOAD_DIR/ecl.tar.gz
    cd $PWD

    ECL_INSTALLED=true
}

valgrind_build()
{
    [[ ${VALGRIND_PREFIX} ]] ||  VALGRIND_PREFIX=$INSTALL_DIR/valgrind

    if test -z "$1" || ! test "$1" == '--force' && test -e $VALGRIND_PREFIX/bin/valgrind; then
        valver=`$VALGRIND_PREFIX/bin/valgrind --version`
        echo "Valgrind seems to be installed. To re-install, pass --force.";  
        echo "Version: $valver"
        return
    fi
    
    local PWD=`pwd`
    local machine=`uname -m`
    if [ $machine == x86_64 ]; then 
        local bits="--enable-only64bit"
    else
        local bits="--enable-only32bit"
    fi

    cd $DOWNLOAD_DIR

    rm -rf valgrind
    svn export svn://svn.valgrind.org/valgrind/trunk valgrind
    cd valgrind
    ./autogen.sh

    ./configure --prefix=$VALGRIND_PREFIX --disable-dependency-tracking $bits
    make -j4
    make install

    mkdir -p $SYMLINK_BIN
    ln -sfn $VALGRIND_PREFIX/bin/valgrind  $SYMLINK_BIN/valgrind
    ln -sfn $VALGRIND_PREFIX/bin/valgrind-listener  $SYMLINK_BIN/valgrind-listener
    ln -sfn $VALGRIND_PREFIX/bin/vgdb  $SYMLINK_BIN/vgdb

    cd $PWD
}

cmake_build()
{
    [[ ${CMAKE_PREFIX} ]] ||  CMAKE_PREFIX=$INSTALL_DIR/cmake

    if test -z "$1" || ! test "$1" == '--force' && test -e $CMAKE_PREFIX/bin/cmake; then
        valver=`$CMAKE_PREFIX/bin/cmake --version`
        echo "CMake seems to be installed. To re-install, pass --force.";  
        echo "Version: $valver"
        return
    fi

    local PWD=`pwd`
    cd $DOWNLOAD_DIR

    wget -O cmake.html http://www.cmake.org/files/${CMAKE_VERSION}/
    rm -rf cmake
    # Last 5th line is the latest version
    local tgz_file=`html2text cmake.html | tail -n5 | head -n1 | cut -f2 -d' '`
    
    wget -N http://www.cmake.org/files/${CMAKE_VERSION}/${tgz_file}
    tar --extract --overwrite --gzip --file ${tgz_file}
    rm -rf $DOWNLOAD_DIR/${tgz_file}

    mv -f cmake-*  cmake
    cd cmake

    # --system-curl --system-libarchive
    ./configure --prefix=$CMAKE_PREFIX --system-zlib  \
                --system-bzip2  --no-qt-gui

    make -j4
    make install

    ln -sfn $CMAKE_PREFIX/bin/cmake $SYMLINK_BIN/cmake
    ln -sfn $CMAKE_PREFIX/bin/ccmake $SYMLINK_BIN/ccmake

    cd $PWD
}

pure_build() {


    export PATH=$LLVM_PREFIX/bin:$PATH
    ./configure --with-static-llvm --with-libgmp-prefix=$HOME/foss/installed/gmp \
                --with-libmpfr-prefix=$HOME/foss/installed/mpfr --with-readline  \
                --enable-release --disable-shared --prefix=$HOME/foss/installed/pure \
                --without/cast-elisp

}

mlterm_build()
{

# http://sourceforge.net/mailarchive/forum.php?thread_name=20120422031849.GA14566%40SDF.ORG&forum_name=mlterm-dev-en
# http://eyegene.ophthy.med.umich.edu/unicode/#termemulator
# http://www.scottro.net/qnd/qnd-mlterm.html
./configure --prefix=$HOME/foss/installed/mlterm --enable-static --disable-shared \
            --with-pic --enable-ind  --enable-anti-alias --disable-dependency-tracking \
             --with-x --with-gui --with-tools=mlcc,mlconfig --with-gtk  \
             --enable-ibus  --enable-fribidi

make -j4
make install
}

fltk_build()
{
./configure --prefix=$HOME/foss/installed/fltk --enable-xft  --enable-threads  --disable-shared
make -j4
make install
ln -sfn $FLTK_PREFIX/bin/fltk-config $SYMLINK_BIN/fltk-config
}


pari_gp_build()
{
    [[ ${PARI_GP_PREFIX} ]] ||  PARI_GP_PREFIX=$INSTALL_DIR/pari-gp

    if test -z "$1" || ! test "$1" == '--force' && test -e $PARI_GP_PREFIX/bin/gp; then
        $PARI_GP_PREFIX/bin/gp --version
        echo "GP/PARI seems to be installed. To re-install, pass --force.";  
        return
    fi

    local cwd=`pwd`
    cd $DOWNLOAD_DIR

    wget --dont-remove-listing  ftp://pari.math.u-bordeaux.fr/pub/pari/unix/
    rm -f index.html*
    local tgz_file=$(cat .listing | tail -n3 | head -n1 | cut -d' ' -f21)
    tgz_file=`echo $tgz_file | tr -d '\r'`      # Delete newline char
    local folder=$(basename $tgz_file .tar.gz)         # strip the extension .tar.gz from $file
    local version=$(echo $folder | cut -d'-' -f2)      # Like 2.5.1

    rm -rf pari*
    wget ftp://pari.math.u-bordeaux.fr/pub/pari/unix/$tgz_file
    tar --extract --overwrite --gzip --file ${tgz_file}
    
    cd $folder

    # hacks because FLTK's library dependencies are not recognized by Pari/GP
    # Since FLTK uses C++'s new and delete, we replace gcc by g++
    # A better solution would be -lstdc++ but it doesn't seem to work
    OLD_LDFLAGS="$LDFLAGS"
    LDFLAGS=`$FLTK_PREFIX/bin/fltk-config --ldflags`
    export LDFLAGS
    mv $SYMLINK_BIN/cc $SYMLINK_BIN/cc.bak
    mv $SYMLINK_BIN/gcc $SYMLINK_BIN/gcc.bak 
    ln -s $SYMLINK_BIN/g++ $SYMLINK_BIN/cc 
    ln -s $SYMLINK_BIN/g++ $SYMLINK_BIN/gcc 

    # Note the capital C in Configure !
    # If you pass --tune, it's gonna take a loooong time to build
      ./Configure --prefix=$HOME/foss/installed/pari-gp --static --graphic=fltk     \
              --with-gmp=$HOME/foss/installed/gmp --with-fltk=$HOME/foss/installed/fltk    \
              --with-readline

    make -j4 gp
    make install

    mv -f $GCC_PREFIX/bin/gcc $SYMLINK_BIN/cc
    mv -f $GCC_PREFIX/bin/gcc $SYMLINK_BIN/gcc
    mv -f $GCC_PREFIX/bin/g++ $SYMLINK_BIN/c++
    mv -f $GCC_PREFIX/bin/g++ $SYMLINK_BIN/g++

    export LDFLAGS=$OLD_LDFLAGS

    rm -f $DOWNLOAD_DIR/$tgz_file
    cd $cwd
}

ghc_build()
{
    # download .tar.bz2 from http://www.haskell.org/ghc/
    # You may need to do help it find libgmp.a
    # ln -s /home/bdsatish/foss/installed/gmp/lib/libgmp.a /usr/local/lib/libgmp.a
    ./configure --prefix=$HOME/foss/installed/ghc --disable-largefile --disable-shared \
        --with-gmp-includes=$HOME/foss/installed/gmp/include                           \
        --with-gmp-libraries=$HOME/foss/installed/gmp/lib

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
elif [ $1 == '--lisp' ]; then
    ecl_build $2 
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
elif [ $1 == '--valgrind' ]; then
    valgrind_build $2
elif [[ $1 == '--cmake' ]]; then
    cmake_build $2
elif [[ $1 == '--pari-gp' ]]; then
    pari_gp_build $2
elif [[ $1 == '--haskell' ]]; then
    ghc_build $2
else
    echo 'Unrecognized option: '"$1"
    echo ""
    usage
fi



