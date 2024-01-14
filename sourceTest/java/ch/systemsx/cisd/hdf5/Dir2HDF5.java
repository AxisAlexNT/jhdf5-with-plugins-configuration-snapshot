/*
 * Copyright 2007 - 2018 ETH Zuerich, CISD and SIS.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package ch.systemsx.cisd.hdf5;

import java.io.File;
import java.io.IOException;

import org.apache.commons.lang3.time.StopWatch;

import ch.systemsx.cisd.hdf5.IHDF5WriterConfigurator.FileFormatVersionBounds;
import ch.systemsx.cisd.hdf5.h5ar.HDF5ArchiverFactory;
import ch.systemsx.cisd.hdf5.h5ar.IArchiveEntryVisitor;
import ch.systemsx.cisd.hdf5.h5ar.IHDF5Archiver;

/**
 * Creates a HDF5 file from a directory.
 * 
 * @author Bernd Rinn
 */
public class Dir2HDF5
{

    public static void main(String[] args) throws IOException
    {
        if (args.length == 0)
        {
            System.err.println("Syntax: Dir2HDF5 <hdf5 file> [<file or dir> ...]");
            System.exit(1);
        }
        final File hdf5File = new File(args[0]);
        final StopWatch watch = new StopWatch();
        watch.start();
        final IHDF5Archiver archiver =
                HDF5ArchiverFactory.open(hdf5File, true, FileFormatVersionBounds.getDefault(), null);
        if (args.length > 1)
        {
            for (int i = 1; i < args.length; ++i)
            {
                archiver.archiveFromFilesystem(new File(args[i]), IArchiveEntryVisitor.NONVERBOSE_VISITOR);
            }
        } else
        {
            archiver.archiveFromFilesystem(new File("."), IArchiveEntryVisitor.NONVERBOSE_VISITOR);
        }
        archiver.close();
        watch.stop();
        System.out.println("Creating hdf5 archive took " + watch);
    }

}
