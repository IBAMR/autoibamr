#!/usr/bin/env bash
set -a

#  Copyright (C) 2013-2021 by David Wells, Bryn Barker,                        #
#  the candi authors AND by the DORSAL Authors, cf. AUTHORS file for details.  #
#                                                                              #
#  This file is part of autoibamr.                                             #
#                                                                              #
#  autoibamr is free software: you can redistribute it and/or modify           #
#  it under the terms of the GNU Lesser General Public License as              #
#  published by the Free Software Foundation, either                           #
#  version 3 of the License, or (at your option) any later version.            #
#                                                                              #
#  autoibamr is distributed in the hope that it will be useful,                #
#  but WITHOUT ANY WARRANTY; without even the implied warranty of              #
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the               #
#  GNU Lesser General Public License for more details.                         #
#                                                                              #
#  You should have received a copy of the GNU Lesser General Public License    #
#  along with autoibamr.  If not, see <http://www.gnu.org/licenses/>.          #

#  REMARK: autoibamr is a majorly tweaked and extended software based on       #
#          candi, which is based on DORSAL.                                    #
#  The origin is DORSAL (also licensed under the LGPL):                        #
#          https://bitbucket.org/fenics-project/dorsal/src                     #
#          master c667be2 2013-11-27                                           #

################################################################################
# The Unix date command does not work with nanoseconds, so use
# the GNU date instead. This is available in the 'coreutils' package
# from MacPorts.
if builtin command -v gdate > /dev/null; then
    DATE_CMD=$(which gdate)
else
    DATE_CMD=$(which date)
fi
# Start global timer
TIC_GLOBAL="$(${DATE_CMD} +%s)"
# Start logging
AUTOIBAMR_LOGFILE=$(pwd)/autoibamr.log
if [ -f autoibamr.log ]; then
    mv "${AUTOIBAMR_LOGFILE}" "${AUTOIBAMR_LOGFILE}.previous"
fi
touch "${AUTOIBAMR_LOGFILE}"

################################################################################
# Colors for progress and error reporting
BAD="\033[1;31m"
GOOD="\033[1;32m"
WARN="\033[1;35m"
INFO="\033[1;34m"

################################################################################
# Ensure that no PETSc environment variables are set.
unset PETSC_DIR
unset PETSC_ARCH

################################################################################
# Define autoibamr helper functions

prettify_dir() {
   # Make a directory name more readable by replacing homedir with "~"
   echo ${1/#$HOME\//~\/}
}

cecho() {
    # Display messages in a specified color and also log them
    COL=$1; shift
    echo -e "${COL}$*\033[0m"
    echo "$*" >> "${AUTOIBAMR_LOGFILE}"
}

default () {
    # Export a variable, if it is not already set
    VAR="${1%%=*}"
    VALUE="${1#*=}"
    eval "[[ \$$VAR ]] || export $VAR='$VALUE'"
}

quit_if_fail() {
    # Exit with some useful information if something goes wrong
    STATUS=$?
    if [ ${STATUS} -ne 0 ]; then
        cecho ${BAD} 'Failure with exit status:' ${STATUS}
        cecho ${BAD} 'Exit message:' $1
        exit ${STATUS}
    fi
}

################################################################################
# Parse command line input parameters
BUILD_LIBMESH=ON
BUILD_NUMDIFF=OFF
BUILD_SILO=ON
CMAKE_LOAD_TARBALL=ON
DEBUGGING=OFF
DEPENDENCIES_ONLY=OFF
EXTERNAL_BOOST=OFF
EXTERNAL_BOOST_DIR=
IBAMR_VERSION=0.14.0
JOBS=1
NATIVE_OPTIMIZATIONS=OFF
PREFIX=~/autoibamr
USER_INTERACTION=ON

# Figure out which binary to use for python support. Note that older PETSc ./configure only supports python2. For now, prefer
# using python2 but use what the user supplies as PYTHON_INTERPRETER.
if builtin command -v $(which python) --version >/dev/null 2>/dev/null; then
  PYTHON_INTERPRETER="$(which python)"
elif builtin command -v $(which python3) --version >/dev/null 2>/dev/null; then
  PYTHON_INTERPRETER="$(which python3)"
fi

while [ -n "$1" ]; do
    param="$1"
    case $param in

        -h|--help)
            echo "autoibamr"
            echo ""
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --dependencies-only            Compile everything but IBAMR itself."
            echo "  --disable-cmake-binary         Instead of trying to download a precompiled CMake binary, compile it."
            echo "  --disable-libmesh              Build IBAMR without libMesh. libMesh is on by default; this flag disables"
            echo "                                 it."
            echo "  --disable-silo                 Build IBAMR without SILO. SILO is on by default; this flag disables it."
            echo "  --enable-debugging             build dependencies with assertions, optimizations, and debug symbols,"
            echo "                                 and build IBAMR with assertions, no optimizations, and debug symbols."
            echo "  --enable-native-optimizations  Build dependencies and IBAMR with platform-specific optimizations."
            echo "  --enable-numdiff               Build the numdiff tool, which is required for IBAMR's test suite."
            echo "                                 Numdiff depends on gettext (available through homebrew) on macOS and has"
            echo "                                 no external dependencies on Linux."
            echo "  --external-boost=<path>        Use an external copy of boost instead of the one bundled with IBAMR."
            echo "  --ibamr-version                Version of IBAMR to install. Presently, versions 0.10.1, 0.11.0, 0.12.0,"
            echo "                                 0.12.1, 0.13.0, and 0.14.0 are supported."
            echo "  --python-interpreter           Absolute path to a python interpreter. Defaults to the first of"
            echo "                                 {python,python3,python2.7} found on the present machine."
            echo "  -p <path>, --prefix=<path>     Set a different prefix path (default $PREFIX)"
            echo "  -j <N>, -j<N>, --jobs=<N>      Compile with N processes in parallel (default ${JOBS})"
            echo "  -y, --yes, --assume-yes        Automatic yes to prompts."
            exit 0
        ;;

        #####################################
        # CMake tarball
        --disable-cmake-binary)
            CMAKE_LOAD_TARBALL=OFF
        ;;

        #####################################
        # only dependencies
        --dependencies-only)
            DEPENDENCIES_ONLY=ON
        ;;

        #####################################
        # libMesh
        --disable-libmesh)
            BUILD_LIBMESH=OFF
        ;;

        #####################################
        # SILO
        --disable-silo)
            BUILD_SILO=OFF
        ;;

        #####################################
        # debug builds
        --enable-debugging)
            DEBUGGING=ON
        ;;

        #####################################
        # native optimization builds
        --enable-native-optimizations)
            NATIVE_OPTIMIZATIONS=ON
        ;;

        #####################################
        # numdiff
        --enable-numdiff)
            BUILD_NUMDIFF=ON
        ;;

        #####################################
        # external boost
        --external-boost)
            EXTERNAL_BOOST=ON
            shift
            EXTERNAL_BOOST_DIR="${1}"
        ;;

        --external-boost=*)
            EXTERNAL_BOOST=ON
            EXTERNAL_BOOST_DIR="${param#*=}"
        ;;

        #####################################
        # IBAMR version
        --ibamr-version)
            shift
            IBAMR_VERSION="${1}"
        ;;

        --ibamr-version=*)
            IBAMR_VERSION="${param#*=}"
        ;;

        #####################################
        # python version
        --python-interpreter)
            shift
            PYTHON_INTERPRETER="${1}"
        ;;

        --python-interpreter=*)
            PYTHON_INTERPRETER="${param#*=}"
        ;;

        #####################################
        # Prefix path
        -p)
            shift
            PREFIX="${1}"
        ;;
        -p=*|--prefix=*)
            PREFIX="${param#*=}"
        ;;

        #####################################
        # Number of maximum processes to use
        --jobs=*)
            JOBS="${param#*=}"
        ;;

        # Make styled processes with or without space
        -j)
            shift
            JOBS="${1}"
        ;;

        -j*)
            JOBS="${param#*j}"
        ;;

        #####################################
        # Assume yes to prompts
        -y|--yes|--assume-yes)
            USER_INTERACTION=OFF
        ;;

        *)
            echo "invalid command line option <$param>. See -h for more information."
            exit 1
    esac
    shift
done

# Don't permit things that don't make sense
if [ ${DEBUGGING} = "ON" ] && [ ${NATIVE_OPTIMIZATIONS} = "ON" ]; then
  cecho ${BAD} "ERROR: --enable-debugging and --enable-native-optimizations are mutually incompatible features."
  exit 1
fi

if [ "${IBAMR_VERSION}" = "0.14.0" ]; then
    SAMRAI_VERSION=2024.01.24
elif [ "${IBAMR_VERSION}" = "0.13.0" ]; then
    SAMRAI_VERSION=2.4.4
elif [ "${IBAMR_VERSION}" = "0.12.1" ]; then
    SAMRAI_VERSION=2.4.4
elif [ "${IBAMR_VERSION}" = "0.12.0" ]; then
    SAMRAI_VERSION=2.4.4
elif [ "${IBAMR_VERSION}" = "0.11.0" ]; then
    SAMRAI_VERSION=2.4.4
elif [ "${IBAMR_VERSION}" = "0.10.1" ]; then
    SAMRAI_VERSION=2.4.4
else
    cecho ${BAD} "ERROR: at the present time autoibamr only supports IBAMR versions 0.14.0, 0.13.0, 0.12.1, 0.12.0, 0.11.0, and 0.10.1."
    exit 1
fi

# Check the input argument of the install path and (if used) replace the tilde
# character '~' by the users home directory ${HOME}. Afterwards clear the
# PREFIX input variable.
PREFIX_PATH=${PREFIX/#~\//$HOME\/}
unset PREFIX

RE='^[0-9]+$'
if [[ ! "${JOBS}" =~ ${RE} || ${JOBS} -lt 1 ]] ; then
  echo "ERROR: invalid number of build processes '${JOBS}'"
  exit 1
fi

################################################################################
# Set download tool

# Set given DOWNLOADER as preferred tool
DOWNLOADERS="${DOWNLOADER}"

# Check if the curl download is available
if builtin command -v curl > /dev/null; then
    # Set curl as the prefered download tool, if nothing else is specified
    DOWNLOADERS="${DOWNLOADERS} curl"
fi

# Check if the wget download is available
if builtin command -v wget > /dev/null; then
    # Set wget as the prefered download tool, if nothing else is specified
    DOWNLOADERS="${DOWNLOADERS} wget"
fi

if [ -z "${DOWNLOADERS}" ]; then
    echo "Please install wget or curl."
    exit 1
fi

################################################################################
#verify_archive():
#  return -1: internal error
#  return 0: CHECKSUM is matching          (archive found & verified)
#  return 1: No checksum provided          (archive found, but unable to verify)
#  return 2: ARCHIVE_FILE not found        (archive NOT found)
#  return 3: CHECKSUM mismatch             (archive file corrupted)
#  return 4: Not able to compute checksum  (archive found, but unable to verify)
#  return 5: Checksum algorithm not found  (archive found, but unable to verify)
# This function tries to verify the downloaded archive by determing and
# comparing checksums. For a specific package several checksums might be
# defined. Based on the length of the given checksum the underlying algorithm
# is determined. The first matching checksum verifies the archive.
verify_archive() {
    ARCHIVE_FILE=$1

    # Make sure the archive was downloaded
    if [ ! -e ${ARCHIVE_FILE} ]; then
        return 2
    fi

    # empty file?
    if [ ! -s ${ARCHIVE_FILE} ]; then
        return 2
    fi

    # Check CHECKSUM has been specified for the package
    if [ -z "${CHECKSUM}" ]; then
        cecho ${WARN} "No checksum for ${ARCHIVE_FILE}"
        return 1
    fi

    # Skip verifying archive, if CHECKSUM=skip
    if [ "${CHECKSUM}" = "skip" ]; then
        cecho ${WARN} "Skipped checksum check for ${ARCHIVE_FILE}"
        return 1
    fi

    cecho ${INFO} "Verifying ${ARCHIVE_FILE}"

    for CHECK in ${CHECKSUM}; do
        # Verify CHECKSUM using md5/sha1/sha256
        if [ ${#CHECK} = 32 ]; then
            ALGORITHM="md5"
            if builtin command -v md5sum > /dev/null; then
                CURRENT=$(md5sum ${ARCHIVE_FILE} | awk '{print $1}')
            elif builtin command -v md5 > /dev/null; then
                CURRENT="$(md5 -q ${ARCHIVE_FILE})"
            else
                cecho ${BAD} "Neither md5sum nor md5 were found in the PATH"
                return 4
            fi
        elif [ ${#CHECK} = 40 ]; then
            ALGORITHM="sha1"
            if builtin command -v sha1sum > /dev/null; then
                CURRENT=$(sha1sum ${ARCHIVE_FILE} | awk '{print $1}')
            elif builtin command -v shasum > /dev/null; then
                CURRENT=$(shasum -a 1 ${ARCHIVE_FILE} | awk '{print $1}')
            else
                cecho ${BAD} "Neither sha1sum nor shasum were found in the PATH"
                return 4
            fi
        elif [ ${#CHECK} = 64 ]; then
            ALGORITHM="sha256"
            if builtin command -v sha256sum > /dev/null; then
                CURRENT=$(sha256sum ${ARCHIVE_FILE} | awk '{print $1}')
            elif builtin command -v shasum > /dev/null; then
                CURRENT=$(shasum -a 256 ${ARCHIVE_FILE} | awk '{print $1}')
            else
                cecho ${BAD} "Neither sha256sum nor shasum were found in the PATH"
                return 4
            fi
        else
            cecho ${BAD} "Checksum algorithm could not be determined"
            exit 5
        fi

        test "${CHECK}" = "${CURRENT}"
        if [ $? = 0 ]; then
            cecho ${GOOD} "${ARCHIVE_FILE}: OK(${ALGORITHM})"
            return 0
        else
            cecho ${BAD} "${ARCHIVE_FILE}: FAILED(${ALGORITHM})"
            cecho ${BAD} "${CURRENT} does not match given checksum ${CHECK}"
        fi
    done
    unset ALGORITHM

    cecho ${BAD} "${ARCHIVE_FILE}: FAILED"
    cecho ${BAD} "Checksum does not match any in ${CHECKSUM}"
    return 3
}

download_archive () {
    ARCHIVE_FILE=$1

    # TODO - it would be nice to support mirrors here

    for DOWNLOADER in ${DOWNLOADERS}; do
    for source in ${SOURCE}; do
        # verify_archive:
        # * Skip loop if the ARCHIVE_FILE is already downloaded
        # * Remove corrupted ARCHIVE_FILE
        verify_archive ${ARCHIVE_FILE}
        archive_state=$?

        if [ ${archive_state} = 0 ]; then
             cecho ${INFO} "${ARCHIVE_FILE} already downloaded and verified."
             return 0;

        elif [ ${archive_state} = 1 ] || [ ${archive_state} = 4 ]; then
             cecho ${WARN} "${ARCHIVE_FILE} already downloaded, but unable to be verified."
             return 0;

        elif [ ${archive_state} = 3 ]; then
            cecho ${BAD} "${ARCHIVE_FILE} in your download folder is corrupted"

            # Remove the file and check if that was successful
            rm -f ${ARCHIVE_FILE}
            if [ $? = 0 ]; then
                cecho ${INFO} "Corrupted ${ARCHIVE_FILE} has been removed!"
            else
                cecho ${BAD} "Corrupted ${ARCHIVE_FILE} could not be removed."
                cecho ${INFO} "Please remove the file ${DOWNLOAD_PATH}/${ARCHIVE_FILE} on your own!"
                exit 1;
            fi
        fi
        unset archive_state

        # Set up complete url
        url=${source}${ARCHIVE_FILE}
        cecho ${INFO} "Trying to download ${url}"

        # Download.
        # If curl or wget is failing, continue this loop for trying an other mirror.
        if [ ${DOWNLOADER} = "curl" ]; then
            curl -f -L -k -O ${url} || continue
        elif [ ${DOWNLOADER} = "wget" ]; then
            wget --no-check-certificate ${url} -O ${ARCHIVE_FILE} || continue
        else
            cecho ${BAD} "autoibamr: Unknown downloader: ${DOWNLOADER}"
            exit 1
        fi

        unset url

        # Verify the download
        verify_archive ${ARCHIVE_FILE}
        archive_state=$?
        if [ ${archive_state} = 0 ] || [ ${archive_state} = 1 ] || [ ${archive_state} = 4 ]; then
            # If the download was successful, and the CHECKSUM is matching, skipped, or not possible
            return 0;
        fi
        unset archive_state
    done
    done

    # Unfortunately it seems that (all) download tryouts finally failed for some reason:
    verify_archive ${ARCHIVE_FILE}
    quit_if_fail "Error verifying checksum for ${ARCHIVE_FILE}\nMake sure that you are connected to the internet. If you are connected to the internet then this is a bug - please report it on the GitHub page."
}

package_fetch () {
    cecho ${GOOD} "Fetching ${PACKAGE} ${VERSION}"

    # Fetch the package appropriately from its source
    if [ ${PACKING} = ".tar.gz" ] || [ ${PACKING} = ".tgz" ] || [ ${PACKING} = ".tar.xz" ] || [ ${PACKING} = ".zip" ]; then
        cd "${DOWNLOAD_PATH}"
        download_archive "${NAME}${PACKING}"
        quit_if_fail "autoibamr: download_archive ${NAME}${PACKING} failed"
    elif [ "${PACKING}" = "git" ]; then
        # Go into the unpack dir
        cd "${UNPACK_PATH}"

        # Clone the git repository if not existing locally
        if [ ! -d "${EXTRACTSTO}" ]; then
            git clone "${SOURCE}${NAME}" "${EXTRACTSTO}"
            quit_if_fail "autoibamr: git clone ${SOURCE}${NAME} ${EXTRACTSTO} failed"
        fi

        # Checkout the desired version
        cd "${EXTRACTSTO}"
        git checkout "${VERSION}" --force
        quit_if_fail "autoibamr: git checkout ${VERSION} --force failed"

        # Switch to the tmp dir
        cd ..
    elif [ "${PACKING}" = "hg" ]; then
        cd "${UNPACK_PATH}"
        # Suitably clone or update hg repositories
        if [ ! -d "${NAME}" ]; then
            hg clone "${SOURCE}${NAME}"
        else
            cd "${NAME}"
            hg pull --update
            cd ..
        fi
    elif [ "${PACKING}" = "svn" ]; then
        cd "${UNPACK_PATH}"
        # Suitably check out or update svn repositories
        if [ ! -d "${NAME}" ]; then
            svn co "${SOURCE}" "${NAME}"
        else
            cd "${NAME}"
            svn up
            cd ..
        fi
    else
        cecho "${BAD}" "autoibamr: internal error: PACKING=${PACKING} for ${PACKAGE} unknown."
        return 1
    fi

    # Quit with a useful message if something goes wrong
    quit_if_fail "Error fetching ${PACKAGE} ${VERSION} using ${PACKING}."
}

package_unpack() {
    # First make sure we're in the right directory before unpacking
    cd "${UNPACK_PATH}"
    FILE_TO_UNPACK="${DOWNLOAD_PATH}/${NAME}${PACKING}"

    # Only need to unpack archives
    if [ "${PACKING}" = ".tar.bz2" ] || [ "${PACKING}" = ".tar.gz" ] || [ "${PACKING}" = ".tbz2" ] || [ "${PACKING}" = ".tgz" ] || [ "${PACKING}" = ".tar.xz" ] || [ "${PACKING}" = ".zip" ]; then
        cecho ${GOOD} "Unpacking ${NAME}${PACKING}"
        # Make sure the archive was downloaded
        if [ ! -e "${FILE_TO_UNPACK}" ]; then
            cecho "${BAD}" "${FILE_TO_UNPACK} does not exist. Please download first."
            exit 1
        fi

        # remove old unpack (this might be corrupted)
        if [ -d "${EXTRACTSTO}" ]; then
            cecho ${INFO} "Deleting extracted directory $(pwd)/${EXTRACTSTO}"
            rm -rf "${EXTRACTSTO}"
            quit_if_fail "Removing of ${EXTRACTSTO} failed."
        fi

        # Unpack the archive only if it isn't already

        # Unpack the archive in accordance with its packing
        if [ ${PACKING} = ".tar.bz2" ] || [ ${PACKING} = ".tbz2" ]; then
            tar xjf ${FILE_TO_UNPACK}
        elif [ ${PACKING} = ".tar.gz" ] || [ ${PACKING} = ".tgz" ]; then
            tar xzf ${FILE_TO_UNPACK}
        elif [ ${PACKING} = ".tar.xz" ]; then
            tar xJf ${FILE_TO_UNPACK}
        elif [ ${PACKING} = ".zip" ]; then
            unzip ${FILE_TO_UNPACK}
        fi
    fi

    # Apply patches with git cherry-pick of commits given by ${CHERRYPICKCOMMITS}
    if [ ${PACKING} = "git" ] && [ -n "${CHERRYPICKCOMMITS}" ]; then
        cecho ${INFO} "autoibamr: git cherry-pick -X theirs ${CHERRYPICKCOMMITS}"
        cd ${UNPACK_PATH}/${EXTRACTSTO}
        git cherry-pick -X theirs ${CHERRYPICKCOMMITS}
        quit_if_fail "autoibamr: git cherry-pick -X theirs ${CHERRYPICKCOMMITS} failed"
    fi

    # Apply patches
    cd ${UNPACK_PATH}/${EXTRACTSTO}
    package_specific_patch

    # Quit with a useful message if something goes wrong
    quit_if_fail "Error unpacking ${FILE_TO_UNPACK}."

    unset FILE_TO_UNPACK
}

package_build() {
    # Get things ready for the compilation process
    cecho ${GOOD} "Building ${PACKAGE} ${VERSION}"

    if [ ! -d "${UNPACK_PATH}/${EXTRACTSTO}" ]; then
        cecho ${BAD} "${EXTRACTSTO} does not exist -- please unpack first."
        exit 1
    fi

    # Set the BUILDDIR if nothing else was specified
    default BUILDDIR=${BUILD_PATH}/${NAME}

    # Always remove the build directory
    if [ -d ${BUILDDIR} ]; then
        cecho ${INFO} "Deleting previously used build directory $(pwd)/${BUILDDIR}"
        rm -rf ${BUILDDIR}
    fi

    # Create build directory if it does not exist
    if [ ! -d ${BUILDDIR} ]; then
        mkdir -p ${BUILDDIR}
    fi

    # Move to the build directory
    cd ${BUILDDIR}

    # Carry out any package-specific setup
    package_specific_setup
    quit_if_fail "There was a problem in build setup for ${PACKAGE} ${VERSION}."
    cd ${BUILDDIR}

    # Use the appropriate build system to compile and install the
    # package
    for cmd_file in autoibamr_configure autoibamr_build; do
        echo "#!/usr/bin/env bash" >${cmd_file}
        chmod a+x ${cmd_file}

        # Write variables to files so that they can be run stand-alone
        declare -x| grep -v "!::"| grep -v "ProgramFiles(x86)" >>${cmd_file}

        # From this point in autoibamr_*, errors are fatal
        echo "set -e" >>${cmd_file}
    done

    if [ ${BUILDCHAIN} = "autotools" ]; then
        if [ -f ${UNPACK_PATH}/${EXTRACTSTO}/configure ]; then
            echo ${UNPACK_PATH}/${EXTRACTSTO}/configure ${CONFOPTS} --prefix=${INSTALL_PATH} >>autoibamr_configure
        fi

        for target in "${TARGETS[@]}"; do
            echo make ${MAKEOPTS} -j ${JOBS} $target >>autoibamr_build
        done

    elif [ ${BUILDCHAIN} = "cmake" ]; then
        echo rm -f CMakeCache.txt \; cmake ${CONFOPTS} -DCMAKE_C_COMPILER="${CC}" \
             -DCMAKE_CXX_COMPILER="${CXX}" -DCMAKE_Fortran_COMPILER="${FC}" \
             -DCMAKE_INSTALL_MESSAGE=LAZY -DCMAKE_INSTALL_PREFIX=${INSTALL_PATH} \
             ${UNPACK_PATH}/${EXTRACTSTO} >>autoibamr_configure
        for target in "${TARGETS[@]}"; do
            echo make ${MAKEOPTS} -j ${JOBS} $target >>autoibamr_build
        done

    elif [ ${BUILDCHAIN} = "python" ]; then
        echo cp -rf ${UNPACK_PATH}/${EXTRACTSTO}/* . >>autoibamr_configure
        echo ${PYTHON_INTERPRETER} setup.py install --prefix=${INSTALL_PATH} >>autoibamr_build

    elif [ ${BUILDCHAIN} = "scons" ]; then
        echo cp -rf ${UNPACK_PATH}/${EXTRACTSTO}/* . >>autoibamr_configure
        for target in "${TARGETS[@]}"; do
            echo scons -j ${JOBS} ${CONFOPTS} prefix=${INSTALL_PATH} $target >>autoibamr_build
        done

    elif [ ${BUILDCHAIN} = "custom" ]; then
        # Write the function definition to file
        declare -f package_specific_build >>autoibamr_build
        echo package_specific_build >>autoibamr_build

    elif [ ${BUILDCHAIN} = "ignore" ]; then
        cecho ${INFO} "Info: ${PACKAGE} has forced BUILDCHAIN=${BUILDCHAIN}."

    else
        cecho ${BAD} "autoibamr: internal error: BUILDCHAIN=${BUILDCHAIN} for ${PACKAGE} unknown."
        exit 1
    fi
    echo "touch autoibamr_successful_build" >> autoibamr_build

    # Run the generated build scripts
    if [ ${BASH_VERSINFO} -ge 3 ]; then
        set -o pipefail
        ./autoibamr_configure 2>&1 | tee autoibamr_configure.log
    else
        ./autoibamr_configure
    fi
    quit_if_fail "There was a problem configuring ${PACKAGE} ${VERSION}."

    if [ ${BASH_VERSINFO} -ge 3 ]; then
        set -o pipefail
        ./autoibamr_build 2>&1 | tee autoibamr_build.log
    else
        ./autoibamr_build
    fi
    quit_if_fail "There was a problem building ${PACKAGE} ${VERSION}."

    # Carry out any package-specific post-build instructions
    package_specific_install
    quit_if_fail "There was a problem in post-build instructions for ${PACKAGE} ${VERSION}."
}

package_register() {
    # Set any package-specific environment variables
    package_specific_register
    quit_if_fail "There was a problem setting environment variables for ${PACKAGE} ${VERSION}."
}

package_conf() {
    # Write any package-specific environment variables to a config file,
    # i.e. e.g. a modulefile or source-able *.conf file
    package_specific_conf
    quit_if_fail "There was a problem creating the configfiles for ${PACKAGE} ${VERSION}."
}

guess_ostype() {
    # Try to guess the operating system type (ostype)
    if [ -f /usr/bin/cygwin1.dll ]; then
        echo cygwin

    elif [ -f /usr/bin/sw_vers ]; then
        echo macos

    elif [ -f /etc/os-release ]; then
        echo linux
    fi
}

################################################################################
### autoibamr script
################################################################################

echo "*******************************************************************************"
cecho ${GOOD} "This is autoibamr - automatically compile and install IBAMR ${IBAMR_VERSION}"
echo

# do some very minimal checking of the external boost, should it be provided
if [ ${EXTERNAL_BOOST} = "ON" ]; then
    if [ ! -d "${EXTERNAL_BOOST_DIR}" ]; then
        cecho ${BAD} "The provided boost directory ${EXTERNAL_BOOST_DIR} is not a directory."
        exit 1
    fi
    if [ ! -e "${EXTERNAL_BOOST_DIR}/include/boost/multi_array.hpp" ]; then
        cecho ${BAD} "The provided external boost does not have the multi_array.hpp header required by IBAMR."
        exit 1
    fi
    if [ ! -e "${EXTERNAL_BOOST_DIR}/include/boost/math/special_functions/round.hpp" ]; then
        cecho ${BAD} "The provided external boost does not have the round.hpp header required by IBAMR."
        exit 1
    fi
    if [ ! -e "${EXTERNAL_BOOST_DIR}/include/boost/math/tools/roots.hpp" ]; then
        cecho ${BAD} "The provided external boost does not have the roots.hpp header required by IBAMR."
        exit 1
    fi
    cecho ${INFO} "External boost in ${EXTERNAL_BOOST_DIR} passed basic checks."
fi

# Keep the current work directory of autoibamr.sh
# WARNING: You should NEVER override this variable!
export ORIG_DIR=`pwd`

# If any variables are missing, set them to defaults
default PROJECT=IBAMR-toolchain

default DOWNLOAD_PATH=${PREFIX_PATH}/tmp/src
default UNPACK_PATH=${PREFIX_PATH}/tmp/unpack
default BUILD_PATH=${PREFIX_PATH}/tmp/build
default INSTALL_PATH=${PREFIX_PATH}/packages
default CONFIGURATION_PATH=${PREFIX_PATH}/configuration

default DEVELOPER_MODE=OFF

# TODO - we can probably remove this
default PACKAGES_OFF=""

# all packages are mandatory except Silo and libMesh. PETSc, SAMRAI, and SILO
# all depend on HDF5. libMesh depends on PETSc.
PACKAGES="cmake hdf5 petsc"
if [ ${BUILD_NUMDIFF} = "ON" ]; then
    PACKAGES="${PACKAGES} numdiff"
fi
if [ ${BUILD_SILO} = "ON" ]; then
    PACKAGES="${PACKAGES} silo"
fi
if [ ${BUILD_LIBMESH} = "ON" ]; then
    PACKAGES="${PACKAGES} libmesh"
fi

# samrai optionally depends on SILO so add it afterwards
if [ ${DEPENDENCIES_ONLY} = "ON" ]; then
    PACKAGES="${PACKAGES} samrai"
else
    PACKAGES="${PACKAGES} samrai ibamr"
fi

################################################################################
# Check if project was specified correctly
if [ -d ${PROJECT} ]; then
    if [ -d ${PROJECT}/packages ]; then
        cecho ${INFO} "Project: ${PROJECT}: Found configuration."
    else
        cecho ${BAD} "Please contact the authors, if you have not changed autoibamr!"
        cecho ${INFO} "autoibamr: Internal error:"
        cecho ${INFO} "No subdirectory 'packages' in ${PROJECT}."
        exit 1
    fi
else
    cecho ${BAD} "Please contact the authors, if you have not changed autoibamr!"
    cecho ${INFO} "autoibamr: Internal error:"
    cecho ${INFO} "Error: No project configuration directory found for project ${PROJECT}."
    echo "Please check if you have specified right project name in autoibamr.cfg"
    echo "Please check if you have directory called ${PROJECT}"
    echo "with subdirectory ${PROJECT}/packages"
    exit 1
fi

################################################################################
# Guess the operating system type -> PLATFORM_OSTYPE
echo
PLATFORM_OSTYPE=`guess_ostype`
if [ -z "${PLATFORM_OSTYPE}" ]; then
    cecho ${WARN} "WARNING: could not determine your Operating System Type (assuming linux)"
    PLATFORM_OSTYPE=linux
fi

cecho ${INFO} "Operating System Type detected as: ${PLATFORM_OSTYPE}"

if [ -z "${PLATFORM_OSTYPE}" ]; then
    # check if PLATFORM_OSTYPE is set and not empty failed
    cecho ${BAD} "Error: (internal) could not set PLATFORM_OSTYPE"
        exit 1
fi

# Guess dynamic shared library file extension -> LDSUFFIX
if [ ${PLATFORM_OSTYPE} == "linux" ]; then
    LDSUFFIX=so

elif [ ${PLATFORM_OSTYPE} == "macos" ]; then
    LDSUFFIX=dylib

elif [ ${PLATFORM_OSTYPE} == "cygwin" ]; then
    LDSUFFIX=dll
fi

cecho ${INFO} "Dynamic shared library file extension detected as: *.${LDSUFFIX}"

# Print configuration options
if [ ${BUILD_LIBMESH} = "ON" ]; then
    cecho ${INFO} "Setting up with libMesh support"
else
    cecho ${INFO} "Setting up without libMesh support"
fi

if [ ${BUILD_SILO} = "ON" ]; then
    cecho ${INFO} "Setting up with SILO support"
else
    cecho ${INFO} "Setting up without SILO support"
fi


if [ ${DEPENDENCIES_ONLY} = "ON" ]; then
    cecho ${INFO} "Skipping compilation of IBAMR itself (only compiling dependencies)"
fi


if [ ${DEBUGGING} = "ON" ]; then
    cecho ${INFO} "Setting up a build intended for debugging"
fi

if [ ${NATIVE_OPTIMIZATIONS} = "ON" ]; then
    cecho ${INFO} "Setting up a build that uses platform-specific optimizations"
fi

if [ -z "${LDSUFFIX}" ]; then
    # check if PLATFORM_OSTYPE is set and not empty failed
    cecho ${BAD} "Error: (internal) could not set LDSUFFIX"
        exit 1
fi

# If interaction is enabled, let the user confirm
if [ ${USER_INTERACTION} = ON ]; then
    echo "--------------------------------------------------------------------------------"
    cecho ${GOOD} "Please make sure you've read the instructions above and your system"
    cecho ${GOOD} "is ready for installing ${PROJECT}."
    cecho ${BAD} "If not, please abort the installer by pressing <CTRL> + <C> !"
    cecho ${INFO} "Then copy and paste these instructions into this terminal."
    echo

    cecho ${GOOD} "Once ready, hit enter to continue!"
    read
fi

################################################################################
# Output configuration details
echo "*******************************************************************************"
cecho ${GOOD} "autoibamr tries now to download, configure, build and install:"
echo
cecho ${GOOD} "Project:  ${PROJECT}"
echo
echo "-------------------------------------------------------------------------------"

if [ ${DEVELOPER_MODE} = "OFF" ]; then
    cecho ${INFO} "Downloading files to:     $(prettify_dir ${DOWNLOAD_PATH})"
    cecho ${INFO} "Unpacking files to:       $(prettify_dir ${UNPACK_PATH})"
elif [ ${DEVELOPER_MODE} = "ON" ]; then
    cecho ${BAD} "Warning: You are using the DEVELOPER_MODE"
    cecho ${INFO} "Note: You need to have run autoibamr with the same settings without this mode before!"
    cecho ${BAD} "For packages not in the build mode={load|skip|once}, autoibamr now use"
    cecho ${BAD} "source files from: $(prettify_dir ${UNPACK_PATH})"
    echo
else
    cecho ${BAD} "autoibamr: bad variable: DEVELOPER_MODE={ON|OFF}; (your specified option is = ${DEVELOPER_MODE})"
    exit 1
fi

cecho ${INFO} "Building packages in:     $(prettify_dir ${BUILD_PATH})"
cecho ${GOOD} "Installing packages in:   $(prettify_dir ${INSTALL_PATH})"
cecho ${GOOD} "Package configuration in: $(prettify_dir ${CONFIGURATION_PATH})"
echo

echo "-------------------------------------------------------------------------------"
cecho ${INFO} "Number of (at most) build processes to use: JOBS=${JOBS}"
echo

echo "-------------------------------------------------------------------------------"
cecho ${INFO} "Packages:"
for PACKAGE in ${PACKAGES[@]}; do
    cecho ${INFO} ${PACKAGE}
done
echo

# if the program 'module' is available, output the currently loaded modulefiles
if builtin command -v module > /dev/null; then
    echo "-------------------------------------------------------------------------------"
    cecho ${GOOD} Currently loaded modulefiles:
    cecho ${INFO} "$(module list)"
    echo
fi

############################################################################
# Compiler variables check
# Firstly test, if compiler variables are set, and if not try to set the
# default mpi-compiler suite finally test, if compiler variables are useful.
#
# In all cases, CMake needs absolute paths to compilers, so expand them out

echo "--------------------------------------------------------------------------------"
cecho ${INFO} "Compiler Variables:"
echo

# CC test
if [ -z "${CC}" ]; then
    if builtin command -v mpicc > /dev/null; then
        cecho ${WARN} "CC  variable not set, but default mpicc  found."
        export CC=mpicc
    fi
fi

if [ -n "${CC}" ]; then
    cecho ${INFO} "CC  = $(which ${CC})"
    export CC=$(which ${CC})
else
    cecho ${BAD} "CC  variable not set. Please set it with \$export CC=<(MPI) C compiler>"
    cecho ${BAD} ""
    cecho ${BAD} "    export CC=<MPI C compiler>"
fi

# CXX test
if [ -z "${CXX}" ]; then
    if builtin command -v mpicxx > /dev/null; then
        cecho ${WARN} "CXX variable not set, but default mpicxx found."
        export CXX=mpicxx
    fi
fi

if [ -n "${CXX}" ]; then
    cecho ${INFO} "CXX = $(which ${CXX})"
    export CXX=$(which ${CXX})
else
    cecho ${BAD} "CXX variable not set. Please set it with \$export CXX=<(MPI) C++ compiler>"
    cecho ${BAD} ""
    cecho ${BAD} "    export CXX=<MPI C++ compiler>"
fi

# FC test
if [ -z "${FC}" ]; then
    if builtin command -v mpif90 > /dev/null; then
        cecho ${WARN} "FC  variable not set, but default mpif90 found."
        export FC=mpif90
    fi
fi

if [ -n "${FC}" ]; then
    cecho ${INFO} "FC  = $(which ${FC})"
    export FC=$(which ${FC})
else
    cecho ${BAD} "FC  variable not set. Please set it with"
    cecho ${BAD} ""
    cecho ${BAD} "    export FC=<MPI F90 compiler>"
fi

echo

# Final test for compiler variables
if [ -z "${CC}" ] || [ -z "${CXX}" ] || [ -z "${FC}" ]; then
    cecho ${BAD} "One or multiple compiler variables (CC, CXX, and FC) were not set"
    cecho ${BAD} "and could not be automatically found. If you are using a cluster,"
    cecho ${BAD} "A common cause of this problem is loading a compiler module"
    cecho ${BAD} "instead of loading an MPI module: e.g., you should run a command"
    cecho ${BAD} "similar to"
    cecho ${BAD} ""
    cecho ${BAD} "    module load openmpi_4.0.1/gcc_11.2.0"
    cecho ${BAD} ""
    cecho ${BAD} "to correctly set up the MPI environment with that version of GCC."
    cecho ${BAD} "Otherwise, set CC, CXX, and FC to their correct values and rerun"
    cecho ${BAD} "autoibamr."
    echo
    exit 1
fi

################################################################################
# If interaction is enabled, force the user to accept the current output
if [ ${USER_INTERACTION} = ON ]; then
    echo "--------------------------------------------------------------------------------"
    cecho ${GOOD} "Once ready, hit enter to continue!"
    read
fi

################################################################################
# Output configuration details
echo "*******************************************************************************"
cecho ${GOOD} "autoibamr tries now to download, configure, build and install:"
echo
cecho ${GOOD} "Project:  ${PROJECT}"
echo

# Create necessary directories and set appropriate variables
mkdir -p ${DOWNLOAD_PATH}
mkdir -p ${UNPACK_PATH}
mkdir -p ${BUILD_PATH}
mkdir -p ${INSTALL_PATH}
mkdir -p ${CONFIGURATION_PATH}

################################################################################
# Do a sanity check for the compilers
cecho ${INFO} "Checking the provided MPI compiler wrappers"
cd ${BUILD_PATH}
mkdir -p check-compilers
cd check-compilers

cat > ./test.c <<"EOF"
#include <mpi.h>

int main(int argc, char **argv)
{
  MPI_Init(&argc, &argv);
  MPI_Finalize();
}
EOF

${CC} test.c -o test.c.out
quit_if_fail "The provided C compiler ${CC} could not compile and link a basic test program. One possible problem is that some Linux distributions install the MPI compiler wrappers without installing the actual compilers (e.g., gcc)."

cat > ./test.cpp <<"EOF"
#include <mpi.h>

#include <vector>

int main(int argc, char **argv)
{
  std::vector<int> ints;
  MPI_Init(&argc, &argv);
  MPI_Finalize();
}
EOF
${CXX} test.cpp -o test.cpp.out
quit_if_fail "The provided C++ compiler ${CXX} could not compile and link a basic test program. A common cause of this error is forgetting to install a C++ compiler. One possible problem is that some Linux distributions install the MPI compiler wrappers without installing the actual compilers (e.g., g++)."

cat > ./test.f <<"EOF"
       PROGRAM MAIN
         WRITE (*,*) "HELLO WORLD"
       END PROGRAM
EOF
${FC} test.f -o test.f.out
quit_if_fail "The provided Fortran compiler ${FC} could not compile and link a basic test program. A common cause of this error is forgetting to install a Fortran compiler. One possible problem is that some Linux distributions install the MPI compiler wrappers without installing the actual compilers (e.g., gfortran)."

cecho ${GOOD} "The provided MPI compiler wrappers work"

################################################################################
# Do a sanity check for the command line utilities we use at some point
for APPLICATION in awk grep m4 make patch
do
    cecho ${INFO} "Testing that the program ${APPLICATION} is available"
    which ${APPLICATION}
    quit_if_fail "Unable to find ${APPLICATION} in default search directories - make sure this program is installed and run autoibamr again."
done
cecho ${GOOD} "The required command-line utilities work"

cecho ${INFO} "Testing that the python interpreter ${PYTHON_INTERPRETER} works"
PYTHONVER=$(${PYTHON_INTERPRETER} -c "import sys; print('{}.{}'.format(sys.version_info.major, sys.version_info.minor))")
quit_if_fail "The provided python interpreter ${PYTHON_INTERPRETER} could not run a basic test program. Try rerunning autoibamr with a different python interpreter (specified by --python-interpreter)"
cecho ${GOOD} "The python interpreter ${PYTHON_INTERPRETER} works and has detected version ${PYTHONVER}"

################################################################################
# configuration script
cat > ${CONFIGURATION_PATH}/enable.sh <<"EOF"
# helper script to source all configuration files. Use
#    source enable.sh
# to load into your current shell.

# hard-code in DIRNAME from configuration time:
EOF
# Split the command so we can save the path
echo "P=${CONFIGURATION_PATH}" >> ${CONFIGURATION_PATH}/enable.sh
cat >> ${CONFIGURATION_PATH}/enable.sh <<"EOF"
for f in $(find $P)
do
  if [ "$f" != "$P/enable.sh" ] && [ -f "$f" ]
  then
    source $f
  fi
done
EOF


# Keep original variables
# WARNING: do not overwrite this variables!
ORIG_INSTALL_PATH=${INSTALL_PATH}
ORIG_CONFIGURATION_PATH=${CONFIGURATION_PATH}
ORIG_JOBS=${JOBS}

# Reset timings
TIMINGS=""

# Fetch and build individual packages
for PACKAGE in ${PACKAGES[@]}; do
    # Start timer
    TIC="$(${DATE_CMD} +%s)"

    # Return to the original autoibamr directory
    cd ${ORIG_DIR}

    # Skip building this package if the user requests it
    SKIP=false
    case ${PACKAGE} in
        load:*) SKIP=true; LOAD=true; PACKAGE=${PACKAGE#*:};;
        skip:*) SKIP=true;  PACKAGE=${PACKAGE#*:};;
        once:*)
          # If the package is turned off in the deal.II configuration, do not
          # install it.
          PACKAGE=${PACKAGE#*:};
          if [[ ${PACKAGES_OFF} =~ ${PACKAGE} ]]; then
            SKIP=true;
          else
            SKIP=maybe;
          fi;;
    esac

    # Check if the package exists
    if [ ! -e ${PROJECT}/packages/${PACKAGE}.package ]; then
        cecho ${BAD} "${PROJECT}/packages/${PACKAGE}.package does not exist yet. Please create it."
        exit 1
    fi

    # Reset package-specific variables
    unset NAME
    unset VERSION
    unset SOURCE
    unset PACKING
    unset EXTRACTSTO
    unset CHECKSUM
    unset BUILDCHAIN
    unset BUILDDIR
    unset CONFOPTS
    unset MAKEOPTS
    unset CONFIG_FILE
    unset CHERRYPICKCOMMITS
    TARGETS=('' install)
    JOBS=${ORIG_JOBS}
    INSTALL_PATH=${ORIG_INSTALL_PATH}
    CONFIGURATION_PATH=${ORIG_CONFIGURATION_PATH}

    # Reset package-specific functions
    package_specific_patch () { true; }
    package_specific_setup () { true; }
    package_specific_build () { true; }
    package_specific_install () { true; }
    package_specific_register () { true; }
    package_specific_conf() { true; }

    # Fetch information pertinent to the package
    source ${PROJECT}/packages/${PACKAGE}.package

    # Ensure that the package file is sanely constructed
    if [ ! "${BUILDCHAIN}" ]; then
        cecho ${BAD} "${PACKAGE}.package is not properly formed. Please check that all necessary variables are defined."
        exit 1
    fi

    if [ ! "${BUILDCHAIN}" = "ignore" ] ; then
        if [ ! "${NAME}" ] || [ ! "${SOURCE}" ] || [ ! "${PACKING}" ]; then
            cecho ${BAD} "${PACKAGE}.package is not properly formed. Please check that all necessary variables are defined."
            exit 1
        fi
    fi

    # Most packages extract to a directory named after the package
    default EXTRACTSTO=${NAME}

    # Check if the package can be set to SKIP:
    default BUILDDIR=${BUILD_PATH}/${NAME}
    if [ ${SKIP} = maybe ] && [ ! -f ${BUILDDIR}/autoibamr_successful_build ]; then
        SKIP=false
    fi

    # Fetch, unpack and build package
    if [ ${SKIP} = false ]; then
        if [ ${DEVELOPER_MODE} = "OFF" ]; then
            # Fetch, unpack and build the current package
            package_fetch
            package_unpack
        fi
        package_build
    else
        if [ -n "${LOAD}" ]; then
            # Let the user know we're loading the current package
            cecho ${GOOD} "Loading ${PACKAGE}"
            unset LOAD
        else
            # Let the user know we're skipping the current package
            cecho ${GOOD} "Skipping ${PACKAGE}"
        fi
    fi
    package_register
    package_conf

    # Store timing
    TOC="$(($(${DATE_CMD} +%s)-TIC))"
    TIMINGS="$TIMINGS"$"\n""$PACKAGE: ""$((TOC)) s"
done

# print information about enable.sh
echo
echo To export environment variables for all installed libraries execute:
echo
cecho ${GOOD} "    source ${CONFIGURATION_PATH}/enable.sh"
echo

# Stop global timer
TOC_GLOBAL="$(($(${DATE_CMD} +%s)-TIC_GLOBAL))"

# Display a summary
echo
cecho ${GOOD} "Build finished in $((TOC_GLOBAL)) seconds."
echo
echo "Summary of timings:"
echo -e "$TIMINGS"
