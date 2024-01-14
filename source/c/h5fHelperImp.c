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

#include "hdf5.h"
#include "H5Ppublic.h"
#include <jni.h>
#include "h5jni.h"

/*
/////////////////////////////////////////////////////////////////////////////////
//
// H5F helper method for checking the state of the mdc image.
//
/////////////////////////////////////////////////////////////////////////////////
*/

/*
 * Class:     ch_systemsx_cisd_hdf5_hdf5lib_HDFHelper
 * Method:    _H5Fhas_mdc_image
 * Signature: hbool _H5Fhas_mdc_image(hid_t)
 */
JNIEXPORT jboolean JNICALL Java_ch_systemsx_cisd_hdf5_hdf5lib_HDFHelper__1H5Fhas_1mdc_1image
  (JNIEnv *env, jclass clss, hid_t file_id)
{
    herr_t status;
    haddr_t image_addr;
    hsize_t image_len; 
    
    status = H5Fget_mdc_image_info(file_id, &image_addr, &image_len);
    if (status < 0)
    {
        h5libraryError(env);
    }
    return (image_addr != HADDR_UNDEF) && (image_len > 0);
}
