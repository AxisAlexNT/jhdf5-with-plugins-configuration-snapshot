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

import org.apache.commons.io.FileUtils;
import org.apache.commons.lang3.time.StopWatch;

/**
 * @author Bernd Rinn
 */
public class HDF5Extract
{

    public static void main(String[] args) throws IOException
    {
        if (args.length != 2)
        {
            System.err.println("Syntax: HDF5Extract <hdf5 file> <file>");
            System.exit(1);
        }
        final File hdf5File = new File(args[0]);
        final File file = new File(args[1]);
        final StopWatch watch = new StopWatch();
        watch.start();
        final IHDF5Reader reader = HDF5FactoryProvider.get().openForReading(hdf5File);
        final byte[] data = reader.int8().readArray(file.getAbsolutePath());
        FileUtils.writeByteArrayToFile(new File(file.getName()), data);
        reader.close();
        watch.stop();
        System.out.println("Extracting hdf5 file took " + watch);
    }

}
