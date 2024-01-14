/*
 * Copyright 2011 - 2018 ETH Zuerich, CISD and SIS.
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

package ch.systemsx.cisd.hdf5.examples;

import static ch.systemsx.cisd.hdf5.HDF5ArrayBlockParamsBuilder.slice;
import static ch.systemsx.cisd.hdf5.HDF5ArrayBlockParamsBuilder.blockIndex;
import static ch.systemsx.cisd.hdf5.MatrixUtils.dims;

import java.util.Random;

import org.apache.commons.lang3.ArrayUtils;

import ch.systemsx.cisd.base.mdarray.MDIntArray;
import ch.systemsx.cisd.hdf5.HDF5DataSet;
import ch.systemsx.cisd.hdf5.HDF5Factory;
import ch.systemsx.cisd.hdf5.HDF5MDDataBlock;
import ch.systemsx.cisd.hdf5.IHDF5Reader;
import ch.systemsx.cisd.hdf5.IHDF5Writer;

/**
 * An example for block-wise reading and writing of an integer matrix. This can be used to read and
 * write arrays and matrices that are too big to fit into memory. Only the block
 */
public class BlockwiseMatrixExample
{

    public static void main(String[] args)
    {
        Random rng = new Random();
        MDIntArray mydata = new MDIntArray(dims(10, 10));

        // Write the integer matrix.
        try (IHDF5Writer writer = HDF5Factory.open("largeimatrix.h5"))
        {
            // Define the block size as 10 x 10.
            try (HDF5DataSet dataSet = writer.int32().createMDArrayAndOpen("mydata", dims(10, 10)))
            {
                // Write 5 x 7 blocks.
                for (int bx = 0; bx < 5; ++bx)
                {
                    for (int by = 0; by < 7; ++by)
                    {
                        fillMatrix(rng, mydata);
                        writer.int32().writeMDArray(dataSet, mydata, blockIndex(bx, by));
                    }
                }
            }
        }

        // Read the matrix in again, using the "natural" 10 x 10 blocks.
        try (IHDF5Reader reader = HDF5Factory.openForReading("largeimatrix.h5"))
        {
            for (HDF5MDDataBlock<MDIntArray> block : reader.int32().getMDArrayNaturalBlocks("mydata"))
            {
                System.out.println(ArrayUtils.toString(block.getIndex()) + " -> "
                        + block.getData().toString());
            }
    
            // Read a 1d sliced block of size 10 where the first index is fixed
            System.out.println(reader.int32().readMDArray("mydata", slice(30, -1).block(10).index(4)));
        }
    }

    static void fillMatrix(Random rng, MDIntArray mydata)
    {
        for (int i = 0; i < mydata.size(0); ++i)
        {
            for (int j = 0; j < mydata.size(1); ++j)
            {
                mydata.set(rng.nextInt(), i, j);
            }
        }
    }

}
