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

import static hdf.hdf5lib.H5.*;
import static hdf.hdf5lib.HDF5Constants.*;

public class TestLowLevelHDF5
{

    static class Container
    {
        String s;
        
        Container()
        {
        }

    }

    public static void main(String[] args) throws Exception
    {
        Container[] cont = new Container[1];
        cont[0] = new Container();
        cont[0].s = "aaa";
        long[] dims = new long[]
            { cont.length };
        long fileId = H5Fcreate("compoundTest.h5", H5F_ACC_TRUNC, H5P_DEFAULT, H5P_DEFAULT);
        long dataSpaceId = H5Screate_simple(1, dims, dims);
        
        long dataTypeId = H5Tcreate(H5T_COMPOUND, 5);
        long stringDataType = H5Tcopy(H5T_C_S1);
        H5Tset_size(stringDataType, 5);
        H5Tinsert(dataTypeId, "s", 0, stringDataType);
        long dataSetId =
                H5Dcreate(fileId, "ds", dataTypeId, dataSpaceId, H5P_DEFAULT, H5P_DEFAULT,
                        H5P_DEFAULT);
        H5Dwrite(dataSetId, dataTypeId, H5S_ALL, H5S_ALL, H5P_DEFAULT, (cont[0].s + '\0').getBytes());
        H5Tclose(dataTypeId);
        H5Sclose(dataSpaceId);
        H5Dclose(dataSetId);
        H5Fclose(fileId);
    }
}
