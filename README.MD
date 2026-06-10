# Description
This repository is a snapshot of workspace for building JHDF5 library with modified configuration that should allow building it with plugin support enabled.

# Important links
* Original repository of JHDF5 source code: [https://sissource.ethz.ch/sispub/jhdf5](https://sissource.ethz.ch/sispub/jhdf5) ;
* Original repository of HDF5 library source code: [https://github.com/HDFGroup/hdf5](https://github.com/HDFGroup/hdf5) ;
* Original repository of HDF5 plugins source code: [https://github.com/HDFGroup/hdf5_plugins](https://github.com/HDFGroup/hdf5_plugins) ;
* HDF5 Homepage: [https://www.hdfgroup.org/solutions/hdf5/](https://www.hdfgroup.org/solutions/hdf5/)

# Motivation
I had to re-build these libraries in order to be able to create self-sufficient jar file for new HiCT implementation in Java.
We've extensively used HDF5 file format while developing our [HiCT tool](https://github.com/ctlab/HiCT) and first HiCT implementation was written in Python and relied on `h5py` library, that conveniently provides all native libraries.
However, the best implementation with decent abstraction level that I found for Java was JHDF5 library: [https://mvnrepository.com/artifact/ch.ethz.sis.jhdf5](https://mvnrepository.com/artifact/ch.ethz.sis.jhdf5) whose artifacts lack support of dynamically-loaded compression plugins.

There was both too much and too little documentation on how to enable support of reading compressed datasets. We had to install HDF5 library with plugins system-wide, put its location in PATH both on Windows and Linux and point ldconfig to it.
However, that might be too much for our target audience, we need to be able to run our tool with just one command (assuming required Java is installed).

# Brief summary of configuration changes
* Using CMake instead of autotools, because it's [better documented](https://docs.hdfgroup.org/archive/support/HDF5/release/cmakebuild.html) and allows configuration through CMakeUserPresets.json which I found to better work with.
* Put hdf5_plugins and hdf5-examples archives into the same directory and extract first one, because some configuration variables intersect between HDF5 and HDF5 Plugins' CMake projects. I've tried using GIT instead of TGZ as an external source, but that leads to strange errors that there is no download link whereas it's actually specified right in the project.
* Changed compilation scripts inside JHDF5 source folder (namely `source/c/compile_hdf5_linux_gcc.sh` and `source/c/compile_linux_amd64.sh`) in order to support building with CMake and therefore updated directory structure. Also, JNI patching is optionally done at this point (however, now I know it needs to be done separately and linked dynamically to hdf5).
* Resulting file in Linux is now named `libjhdf5_export_sharedlink.so`.

# Reproducible HiCT amd64 builds

The source archive expected by the scripts is the official HDF5 CMake archive:

```bash
cd source/c
curl -L -o CMake-hdf5-1.10.11.zip \
  https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.10/hdf5-1.10.11/src/CMake-hdf5-1.10.11.zip
```

The archive currently used by HiCT was verified with SHA-256:

```text
746f83358b0facb7e064d1d0dfe13b1451d26fa6caf3a7251f088824c8828ad4  CMake-hdf5-1.10.11.zip
```

Linux amd64 builds:

```bash
cd source/c
JAVA_HOME=/path/to/jdk ./build_linux_amd64_variants.sh generic avx2 avx512
```

The `generic` variant is the portable amd64 build. The `avx2` variant
targets AVX2/FMA/SSE4.2/BMI/BMI2 for the modern non-AVX-512 machines HiCT
currently targets. The `avx512` variant adds AVX-512F/DQ/BW/VL and must only be
loaded after CPU feature detection. The old `baseline` name is accepted as a
compatibility alias for `avx2`. Outputs are deployed to:

```text
libs/native/jhdf5/amd64-Linux-generic
libs/native/jhdf5/amd64-Linux-avx2
libs/native/jhdf5/amd64-Linux-avx512
```

The build scripts use the HDF5 CMake archive in offline/TGZ mode. They repack
the bundled `hdf5_plugins-release-1_10_11.zip`/`hdf5_plugins-master.zip` into
the `hdf5_plugins.tar.gz` layout expected by HDF5 CMake, then deploy the freshly
built compression plugin libraries together with `libhdf5` and `libjhdf5`.
Legacy plugin copies are used only when the current build did not produce plugin
libraries.

Windows amd64 builds should be run from a Visual Studio x64 Native Tools shell:

```powershell
cd source\c
.\build_windows_amd64_variants.ps1 -Variants generic,avx2,avx512
```

Outputs are deployed to:

```text
libs/native/jhdf5/amd64-Windows-generic
libs/native/jhdf5/amd64-Windows-avx2
libs/native/jhdf5/amd64-Windows-avx512
```

The Windows script follows the same layout: build/deploy the HDF5 DLLs and
freshly built plugin DLLs first, then fall back to legacy plugin DLLs if needed.

The legacy `amd64-Linux` and `amd64-Windows` bundled binaries are kept for
compatibility. HiCT should fall back to those or to the Java implementation if a
new native variant is unavailable or rejected by runtime CPU checks.



# Details
I've spent quite a long time trying to understand why just adding prebuilt plugin binaries isn't going to work.
First, there was a version hardcoded into JHDF5 sources (so plugins compiled for vesions <1.10.3 or >=1.11 would not work).
Then, there is API change in HDF5 starting from version 1.12.
The most puzzling, however, was to deal with HDF5 errors arising from wrong file descriptors.
It has turened out, that default configuration build jhdf5 and links it statically to hdf5.
All plugins are dynamic libraries depending on hdf5. If I only put jhdf5 and plugins, they will fail to load due to unresolved dependency on hdf5.
So, when I put and loaded hdf5, jhdf5 and plugins, there actually were to completely independent instances of HDF5 library (one from JHDF5 statically linked with HDF5, another from standalone HDF5 library) and one did know nothing about other's state including file descriptors.
It might have been possible to first extract plugins from jar to some temporary directory and then append it to plugins search path of statically linked HDF5 library inside JHDF5, however plugins might still work with two copies of HDF5 in that case (and they won't load if hdf5 library is not present).
What I then did was to link it dynamically to the necessary version of HDF5.
Now I first load HDF5 library, then its plugins, then JHDF5 and there is no problem with multiple instances of HDF5 code.

# Disclaimer
All source code of JHDF5, HDF5 and HDF5 plugins belongs to their respective owners.
This repository is only kept to freeze the configuration and file layout that allowed me to build them with no errors.

There might still be something I am not aware of or more simple and straightforward way to enable plugin support in JHDF5, but this is one that I've managed to do.
This repository is also not cleaned from temporary or build files and only represents working build workspace with configuration.
