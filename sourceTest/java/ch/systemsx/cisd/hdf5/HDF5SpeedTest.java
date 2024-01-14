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
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;

import hdf.hdf5lib.exceptions.HDF5LibraryException;

import ch.systemsx.cisd.hdf5.IHDF5WriterConfigurator.SyncMode;

/**
 * @author Bernd Rinn
 */
public class HDF5SpeedTest
{

    public static void main(String[] args)
    {
        final float[] arr = new float[1000000];
        for (int i = 0; i < arr.length; ++i)
        {
            arr[i] = (float) Math.random();
        }
        long start = System.currentTimeMillis();
        final File f1 = new File("speedtest.jo");
        try
        {
            for (int i = 0; i < 20; ++i)
            {
                f1.delete();
                final ObjectOutputStream s = new ObjectOutputStream(new FileOutputStream(f1));
                s.writeObject(arr);
                s.close();
            }
        } catch (Exception ex)
        {
            ex.printStackTrace();
        }
        final float twj = (System.currentTimeMillis() - start) / 1000.f;
        System.out.printf("Write Java Serialization: %.2f s\n",  twj);
        final File f2 = new File("speedtest.h5");
        f2.delete();
        start = System.currentTimeMillis();
        try
        {
            for (int i = 0; i < 20; ++i)
            {
                f2.delete();
                final IHDF5Writer writer =
                        HDF5FactoryProvider.get().configure(f2).syncMode(SyncMode.NO_SYNC).writer();
                writer.float32().writeArray("/f", arr);
                writer.close();
            }
        } catch (HDF5LibraryException ex)
        {
            System.err.println(ex.getHDF5ErrorStackAsString());
        }
        final float twh = (System.currentTimeMillis() - start) / 1000.f;
        System.out.printf("Write HDF5: %.2f s (%.2f %%)\n",  twh, 100.0 * twh / twj);
        start = System.currentTimeMillis();
        try
        {
            for (int i = 0; i < 20; ++i)
            {
                final ObjectInputStream s = new ObjectInputStream(new FileInputStream(f1));
                s.readObject();
                s.close();
            }
        } catch (Exception ex)
        {
            ex.printStackTrace();
        }
        final float trj = (System.currentTimeMillis() - start) / 1000.f;
        System.out.printf("Read Java Serialization: %.2f s\n",  trj);
        start = System.currentTimeMillis();
        try
        {
            for (int i = 0; i < 20; ++i)
            {
                final IHDF5Reader reader =
                        HDF5FactoryProvider.get().configureForReading(f2).reader();
                reader.float32().readArray("/f");
                reader.close();
            }
        } catch (HDF5LibraryException ex)
        {
            System.err.println(ex.getHDF5ErrorStackAsString());
        }
        final float trh = (System.currentTimeMillis() - start) / 1000.f;
        System.out.printf("Read HDF5: %.2f s (%.2f %%)\n",  trh, 100.0 * trh / trj);
    }
}
