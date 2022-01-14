# *This is a work in progress and is not yet ready for public usage.*

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


### Examples

#### Install IBAMR on RHEL 7, CentOS 7 or Fedora:
```bash
  module load mpi/openmpi-`uname -i`
  ./autoibamr.sh
```

#### Install IBAMR on Ubuntu:
```bash
  ./autoibamr.sh
```

#### Install IBAMR on macOS:
```bash
  ./autoibamr.sh
```

#### Install IBAMR on a generic Linux system or cluster:
```bash
  ./autoibamr.sh
```

#### Install IBAMR on a system without pre-installed git:

```bash
  wget https://github.com/IBAMR/autoibamr/archive/master.tar.gz
  tar -xzf master.tar.gz
  cd autoibamr-master
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

#### Specific platform: ``[-pf=<platform>]``, ``[--platform=<platform>]``
```bash
  ./autoibamr.sh -pf=./IBAMR-toolchain/platforms/...
  ./autoibamr.sh --platform=./IBAMR-toolchain/platforms/...
```

If your platform is not detected automatically you can specify it with this
option manually. As shown above, this option is used to install IBAMR via
autoibamr on linux clusters, for example. For a complete list of supported platforms
see [IBAMR-toolchain/platforms](IBAMR-toolchain/platforms).

#### User interaction: ``[-y]``, ``[--yes]``, ``[--assume-yes]``
```bash
  ./autoibamr.sh -y
  ./autoibamr.sh --yes
  ./autoibamr.sh --assume-yes
```

With this option you skip the user interaction. This might be useful if you
submit the installation to the queueing system of a cluster.


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
* parmetis
* PETSc
* SAMRAI
* SILO
* zlib

Their build scripts are in
[IBAMR-toolchain/packages](IBAMR-toolchain/packages).

There are several options within the configuration file, for example:

* Remove existing build directories to use always a fresh setup
```bash
  CLEAN_BUILD={ON|OFF}
```

* Enable native compiler optimizations like ``-march=native``
```bash
  NATIVE_OPTIMIZATIONS={ON|OFF}
```

* Enable the build of the IBAMR examples
```bash
  BUILD_EXAMPLES={ON|OFF}
```

and more.

Furthermore you can specify the install directory and other internal
directories, where the source and build files are stored:
* The ``DOWNLOAD_PATH`` folder (can be safely removed after installation)
* The ``UNPACK_PATH`` folder of the downloaded packages (can be safely removed
  after installation)
* The ``BUILD_PATH`` folder (can be safely removed after installation)
* The ``INSTALL_PATH`` destination folder


### Single package installation mode

If you prefer to install only a single package, you can do so by
```bash
  ./autoibamr.sh --packages="IBAMR"
```
for instance, or a set of packages by
```bash
  ./autoibamr.sh --packages="opencascade petsc"
```

### Developer mode

Our installer provides a software developer mode by setting
``DEVELOPER_MODE=ON``
within [autoibamr.cfg](autoibamr.cfg).

More precisely, the developer mode skips the package ``fetch`` and ``unpack``,
everything else (package configuration, building and installation) is done
as before.

Note that you need to have a previous run of autoibamr and
you must not remove the ``UNPACK_PATH`` directory.
Then you can modify source files in ``UNPACK_PATH`` of a package and
run autoibamr again.
