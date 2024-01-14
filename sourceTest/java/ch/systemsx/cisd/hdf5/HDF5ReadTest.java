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
import java.util.List;

import ch.systemsx.cisd.base.convert.NativeData;
import hdf.hdf5lib.HDFNativeData;

import hdf.hdf5lib.exceptions.HDF5LibraryException;

/**
 * @author Bernd Rinn
 */
public class HDF5ReadTest
{

    public static void main(String[] args)
    {
        try
        {
            IHDF5Reader reader = HDF5FactoryProvider.get().openForReading(new File("test.h5"));
            System.out.println(reader.object().getGroupMemberPaths("/"));
            describe(reader, "/Group1/MyBitSet", null);
            describe(reader, "/Group1/MyDataSet", null);
            byte[] bsb = reader.readAsByteArray("/Group1/MyBitSet");
            long[] bsl = HDFNativeData.byteToLong(0, bsb.length / NativeData.LONG_SIZE, bsb);
            System.out.println("length of /Group1/MyBitSet=" + bsl.length);
            for (long l : bsl)
            {
                System.out.print(l + " ");
            }
            System.out.println();
            BitSet bs = reader.readBitField("/Group1/MyBitSet");
            System.out.println(bs);
            System.out.println(reader.float64().getAttr("/", "version"));
            List<String> members = reader.object().getGroupMemberPaths("/Group1");
            for (String m : members)
            {
                System.out.println("  " + m);
            }
            listAttributes(reader, "/Group1");
            listAttributes(reader, "/Group1/MyDataSet");
            describe(reader, "/Group1/MyDataSet", "foo");
            describe(reader, "/Group1", "active");
            System.out.println(reader.bool().getAttr("/Group1", "active"));
            System.out.println(reader.string().getAttr("/Group1/MyDataSet", "foo"));
            System.out.println(reader.string().getAttr("/Group1/SubGroup1/MyDataSet", "foo"));
            System.out.println(reader.float64().readMatrix("/Group1/MyDataSet")[1][0]);
            System.out.println(reader.float32().readMatrix("/Group1/SubGroup1/MyDataSet")[1][2]);
            System.out.println(reader.string().read("/Group1/MyString").length());
            listAttributes(reader, "empty");
        } catch (HDF5LibraryException ex)
        {
            System.err.println(ex.getHDF5ErrorStackAsString());
            ex.printStackTrace();
        }
    }

    private static void listAttributes(IHDF5Reader reader, String objectName)
    {
        final List<String> attributeNames = reader.object().getAttributeNames(objectName);
        System.out.printf("Found %d attributes for object '%s':\n", attributeNames.size(),
                objectName);
        for (String a : attributeNames)
        {
            System.out.println(a);
        }
    }

    private static void describe(IHDF5Reader reader, String objectName, String attributeNameOrNull)
    {
        HDF5DataSetInformation dsInfo;
        HDF5DataTypeInformation dtInfo;
        if (attributeNameOrNull == null)
        {
            dsInfo = reader.getDataSetInformation(objectName);
            dtInfo = dsInfo.getTypeInformation();
        } else
        {
            dsInfo = null;
            dtInfo = reader.object().getAttributeInformation(objectName, attributeNameOrNull);
        }
        System.out.printf("%s%s, class=%s, elemSize=%d", objectName,
                attributeNameOrNull != null ? "#" + attributeNameOrNull : "",
                dtInfo.getDataClass(), dtInfo.getElementSize());
        if (dsInfo != null)
        {
            System.out.printf(", rank=%d, scalar=%s, variant=%s\n", dsInfo.getRank(), Boolean
                    .toString(dsInfo.isScalar()), dsInfo.tryGetTypeVariant());
            for (long dim : dsInfo.getDimensions())
            {
                System.out.println("  DIM " + dim);
            }
        } else
        {
            System.out.println();
        }
    }
}
