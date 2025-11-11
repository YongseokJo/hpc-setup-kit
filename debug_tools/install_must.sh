#!/bin/bash


module add modules/2.0-20220630
module add gcc/7.5.0
module add openmpi 
module add cmake

#module show openmpi

export MPI_ROOT=/mnt/sw/nix/store/imz0paik74l75yah5d7nx1d47l445gy1-openmpi-4.0.7/
export PATH=$MPI_ROOT/bin:$PATH
export LD_LIBRARY_PATH=$MPI_ROOT/lib:$LD_LIBRARY_PATH

# same OMPI/env as above plus:
#export OMPI_MCA_ess=singleton
#export OMPI_MCA_plm=isolated

# (optional) nuke PMI hints from env so OMPI doesn’t try PMI2_Init
#unset PMI_RANK PMI_SIZE PMI_FD PMI_PORT PMIX_RANK SLURM_STEP_ID SLURM_JOB_ID

which -a mpicc
which -a mpicxx

#which mpicc
#which mpicxx
#which mpirun

rm -rf BUILD && mkdir BUILD && cd BUILD

#CC=$(which gcc) CXX=$(which g++) FC=$(which gfortran)
#FC=$(which mpifort) \
CC=$(which mpicc)  CXX=$(which mpicxx) \ 
cmake ../ \
	-DCMAKE_INSTALL_PREFIX=/mnt/home/yjo10/packages/must2/MUST-v1.9.2/install \
  -DMPI_C_COMPILER=$(which mpicc) \
  -DMPI_CXX_COMPILER=$(which mpicxx) \
	-DMPIEXEC_EXECUTABLE=$(which mpirun) \
	-DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath,$MPI_ROOT/lib" \
	-DCMAKE_SHARED_LINKER_FLAGS="-Wl,-rpath,$MPI_ROOT/lib" \
	-DMPI_C_HEADER_DIR="$MPI_ROOT/include" \
	-DMPI_CXX_HEADER_DIR="$MPI_ROOT/include" \
	-DMPI_C_LIBRARIES="$MPI_ROOT/lib/libmpi.so" \
	-DMPI_CXX_LIBRARIES="$MPI_ROOT/lib/libmpi.so" \
	-DCMAKE_BUILD_TYPE=Release #\

	#-Dwrap_DIR=$HOME/packages/must/externals/GTI/externals/PnMPI/externals/wrap \
	#-DCMAKE_C_COMPILER=mpicc -DCMAKE_CXX_COMPILER=mpicxx \
	#-DGTI_USE_WRAP=OFF -DPNMPI_USE_WRAP=OFF -DMUST_USE_WRAP=OFF\
	#-DBUILD_SHARED_LIBS=ON \
	#-DBUILD_STATIC_LIBS=OFF \
	#-DPNMPI_BUILD_STATIC=OFF \
	#-DPNMPI_ENABLE_FORTRAN=OFF -DGTI_WITH_FORTRAN=OFF -DMUST_WITH_FORTRAN=OFF
	#-DCMAKE_POSITION_INDEPENDENT_CODE=ON \

	# and/or disable static to use shared only:
	# If PnMPI exposes its own flags:
	#-DCMAKE_BUILD_TYPE=Release


	#-DCMAKE_BUILD_RPATH="$MPI_ROOT/lib" \
	#//-DCMAKE_INSTALL_RPATH="$MPI_ROOT/lib" \

#make clean
make -j && make install
#make -j1 VERBOSE=1 externals/GTI/externals/PnMPI/src/pnmpi/CMakeFiles/pnmpif_static.dir/all


export PATH=$HOME/packages/must/bin:$PATH
