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
import java.util.BitSet;

import hdf.hdf5lib.exceptions.HDF5LibraryException;

/**
 * @author Bernd Rinn
 */
public class HDF5WriteTest
{

    public static void main(String[] args)
    {
        final BitSet bs = new BitSet();
        bs.set(127);
        bs.set(64);
        bs.set(128);
        // bs.set(191);
        try
        {
            IHDF5Writer writer =
                    HDF5FactoryProvider.get().configure(new File("test.h5")).overwrite().writer();
            // writer.write("/Group1/SubGroup1/MyDataSet", new float[] { 1.0f, 2.0f, 3.0f, 4.0f });
            // writer.link("/Group1/SubGroup1/MyDataSet", "/Group1/MyDataSet");
            // writer.write("/Group1/MyDataSet", new float[] { 4.0f, 3.0f, 2.0f, 1.0f });
            // writer.write("/Group1/MyDataSet", new double[] { 4.0, 3.0, 2.0, 1.0 });
            writer.writeBitField("/Group1/MyBitSet", bs);
            writer.float32().writeMatrix("/Group1/MyDataSet", new float[][]
                {
                    { 4, 3, 2, 1, 0, -1 },
                    { 0, 1, 2, 3, 4, 5 } });
            writer.int64().writeArray("/Group1/MyDataSet2", new long[]
                { 4, 3, 2, 1 });
            writer.int64().writeArray("/Group1/MyDataSet3", new long[]
                { 1 });
            // writer.write("/Group1/MyDataSet", new int[] { 4, 3, 2, 1 });
            writer.object().createHardLink("/Group1/MyDataSet", "/Group1/SubGroup1/MyDataSet");
            writer.string().write("/Group1/MyString", "Und schon wieder die Geschichte vom Pferd!");
            writer.string().setAttr("/Group1/MyDataSet", "foo", "Die Geschichte vom Pferd");
            // writer.addAttribute("/Group1/SubGroup1/MyDataSet", "foo", "No story");
            writer.float64().setAttr("/", "version", 17.0);
            writer.bool().setAttr("/Group1", "active", true);
            writer.int8().writeArray("/empty", new byte[0]);
            writer.close();
        } catch (HDF5LibraryException ex)
        {
            System.err.println(ex.getHDF5ErrorStackAsString());
            ex.printStackTrace();
        }
    }

}
