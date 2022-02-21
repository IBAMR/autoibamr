autoibamr
=========

The ``autoibamr.sh`` shell script downloads, configures, builds, and installs
[ibamr](https://ibamr.github.io) with common dependencies on
Linux and macOS computers.

`autoibamr` is based on candi: https://github.com/dealii/candi

Quickstart
----

The following commands download the current stable version of the installer and
then install the latest IBAMR release and common dependencies:

```bash
  git clone https://github.com/ibamr/autoibamr.git
  cd autoibamr
  ./autoibamr.sh
```

Follow the instructions on the screen
(you can abort the process by pressing < CTRL > + C)


### Installation

If you are on a cluster you will typically want to run `module load mpi` to set
up the correct MPI environment. After that you can run

```bash
  ./autoibamr.sh
```

Advanced Configuration
----

### Command line options

#### Help: ``[-h]``, ``[--help]``
You can get a list of all command line options by running
```bash
  ./autoibamr.sh -h
  ./autoibamr.sh --help
```

You can combine the command line options given below.

#### Prefix path: ``[-p <path>]``, ``[-p=<path>]``, ``[--prefix=<path>]``
```bash
  ./autoibamr.sh -p "/path/to/install/dir"
  ./autoibamr.sh -p="/path/to/install/dir"
  ./autoibamr.sh --prefix="/path/to/install/dir"
```

#### Multiple build processes: ``[-j<N>]``, ``[-j <N>]``, ``[--jobs=<N>]``
```bash
  ./autoibamr.sh -j<N>
  ./autoibamr.sh -j <N>
  ./autoibamr.sh --jobs=<N>
```

* Example: to use 2 build processes type ``./autoibamr.sh -j 2``.

#### Debug mode: `--enable-debugging`
```bash
  ./autoibamr.sh --enable-debugging
```
Sets up a debug build, where dependencies are compiled with assertion checking,
debug symbols, and optimizations and IBAMR is compiled with assertions, no
optimizations, and debug symbols.

#### Platform-specific optimizations: `--enable-native-optimizations`
```bash
  ./autoibamr.sh --enable-native-optimizations
```
Turns on processor-specific optimizations. Incompatible with debug mode.

#### User interaction: ``[-y]``, ``[--yes]``, ``[--assume-yes]``
```bash
  ./autoibamr.sh -y
  ./autoibamr.sh --yes
  ./autoibamr.sh --assume-yes
```

With this option you skip the user interaction. This might be useful if you
submit the installation to the queueing system of a cluster.

By default both libMesh and SILO will be set up and used as dependencies. They
can be disabled with `--disable-libmesh` and `--disable-silo` respectively.

### Configuration file options

If you want to change the set of packages to be installed,
you can enable or disable a package in the configuration file
[autoibamr.cfg](autoibamr.cfg).
This file is a simple text file and can be changed with any text editor.

Currently, we provide the packages

* CMake
* HDF5
* libMesh
* numdiff
* PETSc
* SAMRAI
* SILO

Their build scripts are in
[IBAMR-toolchain/packages](IBAMR-toolchain/packages).

In addition, PETSc sets up BLAS, LAPACK, HYPRE, metis, and parmetis.

There are several options within the configuration file, for example:

* Remove existing build directories to use always a fresh setup
```bash
  CLEAN_BUILD={ON|OFF}
```

and more.

Furthermore you can specify the install directory and other internal
directories, where the source and build files are stored:
* The ``DOWNLOAD_PATH`` folder (can be safely removed after installation)
* The ``UNPACK_PATH`` folder of the downloaded packages (can be safely removed
  after installation)
* The ``BUILD_PATH`` folder (can be safely removed after installation)
* The ``INSTALL_PATH`` destination folder
