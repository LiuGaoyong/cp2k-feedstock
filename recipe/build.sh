#!/bin/bash
set -ex

if [[ "${mpi}" == "openmpi" ]]; then
  CP2K_USE_ELPA="ON"
  export OMPI_ALLOW_RUN_AS_ROOT=1
  export OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
  export OMPI_MCA_plm_rsh_agent=/bin/false
  TARGET="$PREFIX/include/elpa_openmp/modules/modules"
  if [ -d ${TARGET} ] ; then
    echo "${TARGET} exists."
  else
    WORKDIR=$(realpath $(pwd))
    cd $(dirname ${TARGET})
    ln -s . modules
    cd ${WORKDIR}
    ls ${TARGET}
  fi
else
  CP2K_USE_ELPA="OFF"
fi

# Build CP2K
export PKG_CONFIG_PATH="${PREFIX}/lib:${PKG_CONFIG_PATH}"
cmake -B build -S . \
  -GNinja \
  -DCMAKE_BUILD_TYPE="Release" \
  -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
  -DCMAKE_SKIP_RPATH="ON" \
  -DCMAKE_VERBOSE_MAKEFILE="OFF" \
  -DCP2K_BLAS_VENDOR="OpenBLAS" \
  -DCP2K_USE_EVERYTHING="OFF" \
  -DCP2K_USE_ELPA="${CP2K_USE_ELPA}" \
  -DCP2K_USE_FFTW3="ON" \
  -DCP2K_USE_HDF5="ON" \
  -DCP2K_USE_LIBINT2="ON" \
  -DCP2K_USE_LIBTORCH="ON" \
  -DCP2K_USE_LIBXC="ON" \
  -DCP2K_USE_LIBXSMM="ON" \
  -DCP2K_USE_MPI="ON" \
  -DCP2K_USE_MPI_F08="ON" \
  -DCP2K_USE_PLUMED="ON" \
  -DCP2K_USE_SIRIUS="ON" \
  -DCP2K_USE_SPGLIB="ON" \
  -DCP2K_USE_SPLA="ON" \
  -DCP2K_USE_TBLITE="OFF" \
  -DCP2K_USE_TREXIO="ON"
cmake --build build --parallel "${CPU_COUNT}"
cmake --install build
ln -sf cp2k.psmp "${PREFIX}/bin/cp2k.popt"
ln -sf cp2k.psmp "${PREFIX}/bin/cp2k"

# Restrict UCX to TCP (disable high-performance transports)
export UCX_TLS=self,tcp

# Run CP2K regression tests
#  │ │ >>> $BUILD_PREFIX/TEST-2026-05-27_03-45-14/QS/regtest-hybrid-ace-gs
#  │ │     h2o-admm-ace-gpw.inp:E_total                                                          -16.99625144           OK (   2.35 sec)
#  │ │     h2o-admm-ace-gpw.inp:M072                                                            0.00423932453           OK (   2.35 sec)
#  │ │ <<< $BUILD_PREFIX/TEST-2026-05-27_03-45-14/QS/regtest-hybrid-ace-gs (399 of 399) done in 4.69 sec
#  │ │ ------------------------------- Errors ---------------------------------
#  │ │ xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
#  │ │ $BUILD_PREFIX/TEST-2026-05-27_03-45-14/QS/regtest-moments-kpoints/C2_pbe_scf_kp.inp.out
#  │ │ Spec: {'matcher': 'Dipole_at_kp_1', 'tol': 1e-06, 'ref': -0.544}
#  │ │ Difference too large: 2.00e+00 > 1e-06, value: 0.544.
#  │ │ ------------------------------- Timings --------------------------------
#  │ │ Plot: name="timings", title="Timing Distribution", ylabel="time [s]"
#  │ │ PlotPoint: name="100th_percentile", plot="timings", label="100th %ile", y=22.24, yerr=0.0
#  │ │ PlotPoint: name="99th_percentile", plot="timings", label="99th %ile", y=9.01, yerr=0.0
#  │ │ PlotPoint: name="98th_percentile", plot="timings", label="98th %ile", y=6.84, yerr=0.0
#  │ │ PlotPoint: name="95th_percentile", plot="timings", label="95th %ile", y=5.63, yerr=0.0
#  │ │ PlotPoint: name="90th_percentile", plot="timings", label="90th %ile", y=4.91, yerr=0.0
#  │ │ PlotPoint: name="80th_percentile", plot="timings", label="80th %ile", y=4.22, yerr=0.0
#  │ │ ------------------------------- Summary --------------------------------
#  │ │ Number of FAILED  tests 0
#  │ │ Number of WRONG   tests 1
#  │ │ Number of CORRECT tests 438
#  │ │ Total number of   tests 439
#  │ │ Summary: correct: 438 / 439; wrong: 1; 21min
#  │ │ Status: FAILED
#  │ │ *************************** Testing ended ******************************
export CP2K_DATA_DIR="${PREFIX}/share/cp2k/data"
export OMP_STACKSIZE=256M
"${PWD}/tests/do_regtest.py" "${PREFIX}/bin" "psmp" \
  --maxtasks "${CPU_COUNT}" \
  --smoketest \
  --workbasedir "${BUILD_PREFIX}"
# For a full regression test without --smoketest add
#  --skipdir "QS/regtest-dcdft-hfx" \
#  --skipdir "SIRIUS/regtest-1" \
# to make it pass without error
