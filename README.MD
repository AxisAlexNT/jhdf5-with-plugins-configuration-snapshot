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
