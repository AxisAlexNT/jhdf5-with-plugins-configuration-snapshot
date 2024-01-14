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
#include "h5jni.h"
#include <jni.h>

/*
/////////////////////////////////////////////////////////////////////////////////
//
// H5P helper methods for controlling the behavior on numeric conversions.
//
/////////////////////////////////////////////////////////////////////////////////
*/

H5T_conv_ret_t abort_on_overflow_cb(int except_type, hid_t *src_id, hid_t *dst_id, void *src_buf, void *dst_buf, void *op_data)
{
    if (except_type == H5T_CONV_EXCEPT_RANGE_HI || except_type == H5T_CONV_EXCEPT_RANGE_LOW)
    {
        return H5T_CONV_ABORT;
    }
    return H5T_CONV_UNHANDLED;
}

/*
 * Class:     ch_systemsx_cisd_cisd_hdf5_hdf5lib_HDFHelper
 * Method:    _H5Pcreate_xfer_abort_overflow
 * Signature: hid_t _H5Pcreate_xfer_abort_overflow()
 */
JNIEXPORT jlong JNICALL Java_ch_systemsx_cisd_hdf5_hdf5lib_HDFHelper__1H5Pcreate_1xfer_1abort_1overflow
  (JNIEnv *env, jclass clss)
{
    hid_t plist;
    herr_t status;

    plist = H5Pcreate(H5P_DATASET_XFER);
    if (plist < 0) {
        h5libraryError(env);
    }
    status = H5Pset_type_conv_cb(plist, (H5T_conv_except_func_t) abort_on_overflow_cb, NULL);
    if (status < 0)
    {
        h5libraryError(env);
    }
    return plist;
}

H5T_conv_ret_t abort_cb(int except_type, hid_t *src_id, hid_t *dst_id, void *src_buf, void *dst_buf, void *op_data)
{
    return H5T_CONV_ABORT;
}

/*
 * Class:     ch_systemsx_cisd_hdf5_hdf5lib_HDFHelper
 * Method:    _H5Pcreate_xfer_abort
 * Signature: hid_t _H5Pcreate_xfer_abort()
 */
JNIEXPORT jlong JNICALL Java_ch_systemsx_cisd_hdf5_hdf5lib_HDFHelper__1H5Pcreate_1xfer_1abort
  (JNIEnv *env, jclass clss)
{
    hid_t plist;
    herr_t status;

    plist = H5Pcreate(H5P_DATASET_XFER);
    if (plist < 0) {
        h5libraryError(env);
    }
    status = H5Pset_type_conv_cb(plist, (H5T_conv_except_func_t) abort_cb, NULL);
    if (status < 0)
    {
        h5libraryError(env);
    }
    return plist;
}

/*
/////////////////////////////////////////////////////////////////////////////////
//
// H5P helper methods for setting / getting the metadata cache image configuration. 
//
/////////////////////////////////////////////////////////////////////////////////
*/

/*
 * Class:     ch_systemsx_cisd_hdf5_hdf5lib_HDFHelper
 * Method:    _H5Pset_mdc_image_config
 * Signature: herr_t _H5Pset_mdc_image_config(hid_t, bool)
 */
JNIEXPORT jlong JNICALL Java_ch_systemsx_cisd_hdf5_hdf5lib_HDFHelper__1H5Pset_1mdc_1image_1config
  (JNIEnv *env, jclass clss, hid_t plist, jboolean generate_image)
{
    herr_t status;
    H5AC_cache_image_config_t config;
    
    config.version = H5AC__CURR_CACHE_IMAGE_CONFIG_VERSION;
    config.generate_image = generate_image;
    config.save_resize_status = 0;
    config.entry_ageout = H5AC__CACHE_IMAGE__ENTRY_AGEOUT__NONE;

    status = H5Pset_mdc_image_config(plist, &config);
    if (status < 0)
    {
        h5libraryError(env);
    }
    return status;
}

/*
 * Class:     ch_systemsx_cisd_hdf5_hdf5lib_HDFHelper
 * Method:    _H5Pget_mdc_image_enabled
 * Signature: hbool _H5Pget_mdc_image_enabled(hid_t)
 */
JNIEXPORT jboolean JNICALL Java_ch_systemsx_cisd_hdf5_hdf5lib_HDFHelper__1H5Pget_1mdc_1image_1enabled
  (JNIEnv *env, jclass clss, hid_t plist)
{
    herr_t status;
    H5AC_cache_image_config_t config;
    
    config.version = H5AC__CURR_CACHE_IMAGE_CONFIG_VERSION;
    
    status = H5Pget_mdc_image_config(plist, &config);
    if (status < 0)
    {
        h5libraryError(env);
    }
    return config.generate_image;
}
