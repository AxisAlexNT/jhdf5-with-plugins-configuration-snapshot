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

package ch.systemsx.cisd.hdf5.tools;

import java.io.File;
import java.io.IOException;
import java.io.PrintStream;
import java.nio.charset.Charset;

import org.apache.commons.io.FileUtils;
import org.apache.commons.lang3.StringUtils;

/**
 * A code generator for the identical parts of the HDF5 Java classes class for different numerical
 * types.
 * 
 * @author Bernd Rinn
 */
public class HDF5CodeGenerator
{

    static class TemplateParameters
    {
        final String name;

        final String capitalizedName;

        final String capitalizedClassName;

        final String upperCaseClassName;

        final String wrapperName;

        final String storageType;

        final String featureBasedStorageType;

        final String storageTypeImport;

        final String memoryType;

        final String elementSize;
        
        final String javadocMethodReader;
        
        final String javadocMethodWriter;

        final boolean isUnsigned;

        final boolean isInteger;

        TemplateParameters(String name, String capitalizedName, String capitalizedClassName,
                String wrapperName, String storageType, String featureBasedStorageType,
                String storageTypeImport, String memoryType, String elementSize,
                String javadocMethodReader, String javadocMethodWriter,
                boolean isUnsigned, boolean isInteger)
        {
            this.name = name;
            this.capitalizedName = capitalizedName;
            this.capitalizedClassName = capitalizedClassName;
            this.upperCaseClassName = capitalizedClassName.toUpperCase();
            this.wrapperName = wrapperName;
            this.storageType = storageType;
            this.featureBasedStorageType = featureBasedStorageType;
            this.storageTypeImport = storageTypeImport;
            this.memoryType = memoryType;
            this.elementSize = elementSize;
            this.javadocMethodReader = javadocMethodReader;
            this.javadocMethodWriter = javadocMethodWriter;
            this.isUnsigned = isUnsigned;
            this.isInteger = isInteger;
        }

    }

    static TemplateParameters tp(String name, String capitalizedName, String capitalizedClassName,
            String wrapperName, String storageType, String featureBasedStorageType,
            String storageTypeImport, String memoryType, String elementSize, 
            String javadocMethodReader, String javadocMethodWriter, boolean isUnsigned,
            boolean isInteger)
    {
        return new TemplateParameters(name, capitalizedName, capitalizedClassName, wrapperName,
                storageType, featureBasedStorageType, storageTypeImport, memoryType, elementSize,
                javadocMethodReader, javadocMethodWriter, isUnsigned, isInteger);
    }

    static final TemplateParameters PLACEHOLDERS = tp("__name__", "__Name__", "__Classname__",
            "__Wrappername__", "__Storagetype__", "__FeatureBasedStoragetype__",
            "__StoragetypeImport__", "__Memorytype__", "__elementsize__", "__javadocmethodreader__", 
            "__javadocmethodwriter__", false, false);

    static final TemplateParameters[] NUMERICAL_TYPES =
            new TemplateParameters[]
                {
                        tp("byte",
                                "Byte",
                                "Int",
                                "Byte",
                                "H5T_STD_I8LE",
                                "features.isSigned() ? H5T_STD_I8LE : H5T_STD_U8LE",
                                "import static hdf.hdf5lib.HDF5Constants.H5T_STD_I8LE;\n"
                                        + "import static hdf.hdf5lib.HDF5Constants.H5T_STD_U8LE;",
                                "H5T_NATIVE_INT8", "1", 
                                "{@link IHDF5Reader#int8()} or {@link IHDF5Reader#uint8()}", 
                                "{@link IHDF5Writer#int8()} or {@link IHDF5Writer#uint8()}", 
                                false, true),
                        tp("byte",
                                "Byte",
                                "Int",
                                "Byte",
                                "H5T_STD_U8LE",
                                "H5T_STD_U8LE",
                                "import static hdf.hdf5lib.HDF5Constants.H5T_STD_U8LE;",
                                "H5T_NATIVE_UINT8", "1", "", "", true, true),
                        tp("short",
                                "Short",
                                "Int",
                                "Short",
                                "H5T_STD_I16LE",
                                "features.isSigned() ? H5T_STD_I16LE : H5T_STD_U16LE",
                                "import static hdf.hdf5lib.HDF5Constants.H5T_STD_I16LE;\n"
                                        + "import static hdf.hdf5lib.HDF5Constants.H5T_STD_U16LE;",
                                "H5T_NATIVE_INT16", "2", 
                                "{@link IHDF5Reader#int16()} or {@link IHDF5Reader#uint16()}", 
                                "{@link IHDF5Writer#int16()} or {@link IHDF5Writer#uint16()}", 
                                false, true),
                        tp("short",
                                "Short",
                                "Int",
                                "Short",
                                "H5T_STD_U16LE",
                                "H5T_STD_U16LE",
                                "import static hdf.hdf5lib.HDF5Constants.H5T_STD_U16LE;",
                                "H5T_NATIVE_UINT16", "2", "", "", true, true),
                        tp("int",
                                "Int",
                                "Int",
                                "Integer",
                                "H5T_STD_I32LE",
                                "features.isSigned() ? H5T_STD_I32LE : H5T_STD_U32LE",
                                "import static hdf.hdf5lib.HDF5Constants.H5T_STD_I32LE;\n"
                                        + "import static hdf.hdf5lib.HDF5Constants.H5T_STD_U32LE;",
                                "H5T_NATIVE_INT32", "4", 
                                "{@link IHDF5Reader#int32()} or {@link IHDF5Reader#uint32()}", 
                                "{@link IHDF5Writer#int32()} or {@link IHDF5Writer#uint32()}", 
                                false, true),
                        tp("int",
                                "Int",
                                "Int",
                                "Integer",
                                "H5T_STD_U32LE",
                                "H5T_STD_U32LE",
                                "import static hdf.hdf5lib.HDF5Constants.H5T_STD_U32LE;",
                                "H5T_NATIVE_UINT32", "4", "", "", true, true),
                        tp("long",
                                "Long",
                                "Int",
                                "Long",
                                "H5T_STD_I64LE",
                                "features.isSigned() ? H5T_STD_I64LE : H5T_STD_U64LE",
                                "import static hdf.hdf5lib.HDF5Constants.H5T_STD_I64LE;\n"
                                        + "import static hdf.hdf5lib.HDF5Constants.H5T_STD_U64LE;",
                                "H5T_NATIVE_INT64", "8", 
                                "{@link IHDF5Reader#int64()} or {@link IHDF5Reader#uint64()}", 
                                "{@link IHDF5Writer#int64()} or {@link IHDF5Writer#uint64()}", 
                                false, true),
                        tp("long",
                                "Long",
                                "Int",
                                "Long",
                                "H5T_STD_U64LE",
                                "H5T_STD_U64LE",
                                "import static hdf.hdf5lib.HDF5Constants.H5T_STD_U64LE;",
                                "H5T_NATIVE_UINT64", "8", "", "", true, true),
                        tp("float",
                                "Float",
                                "Float",
                                "Float",
                                "H5T_IEEE_F32LE",
                                "H5T_IEEE_F32LE",
                                "import static hdf.hdf5lib.HDF5Constants.H5T_IEEE_F32LE;",
                                "H5T_NATIVE_FLOAT", "4", 
                                "{@link IHDF5Reader#float32()}", 
                                "{@link IHDF5Writer#float32()}", 
                                false, false),
                        tp("double",
                                "Double",
                                "Float",
                                "Double",
                                "H5T_IEEE_F64LE",
                                "H5T_IEEE_F64LE",
                                "import static hdf.hdf5lib.HDF5Constants.H5T_IEEE_F64LE;",
                                "H5T_NATIVE_DOUBLE", "8", 
                                "{@link IHDF5Reader#float64()}", 
                                "{@link IHDF5Writer#float64()}", 
                                false, false) };

    /**
     * Generate the code for all numerical types from <var>codeTemplate</var> and write it to
     * <code>stdout</code>.
     */
    static void generateCode(final String codeTemplate)
    {
        for (TemplateParameters t : NUMERICAL_TYPES)
        {
            generateCode(codeTemplate, t, System.out);
        }
    }

    /**
     * Generate the code for all numerical types from <var>codeTemplate</var> and write it to
     * <code>out</code>.
     */
    static void generateCode(final String codeTemplate, final TemplateParameters params,
            final PrintStream out)
    {
        String s = codeTemplate;
        if (params.isInteger)
        {
            s =
                    StringUtils
                            .replace(
                                    s,
                                    "__NoteUnsigned__",
                                    " * <p>   \n"
                                            + " * <i>Note:</i> If you need to convert from and to unsigned values, use the methods of \n"
                                            + " * {@link UnsignedIntUtils}.\n");
        } else
        {
            s = StringUtils.replace(s, "__NoteUnsigned__", "");
        }
        s = StringUtils.replace(s, PLACEHOLDERS.name, params.name);
        s = StringUtils.replace(s, PLACEHOLDERS.capitalizedName, params.capitalizedName);
        s = StringUtils.replace(s, PLACEHOLDERS.capitalizedClassName, params.capitalizedClassName);
        s = StringUtils.replace(s, PLACEHOLDERS.upperCaseClassName, params.upperCaseClassName);
        s = StringUtils.replace(s, PLACEHOLDERS.wrapperName, params.wrapperName);
        s = StringUtils.replace(s, PLACEHOLDERS.storageType, params.storageType);
        s =
                StringUtils.replace(s, PLACEHOLDERS.featureBasedStorageType,
                        params.featureBasedStorageType);
        s = StringUtils.replace(s, PLACEHOLDERS.storageTypeImport, params.storageTypeImport);
        s = StringUtils.replace(s, PLACEHOLDERS.memoryType, params.memoryType);
        s = StringUtils.replace(s, PLACEHOLDERS.elementSize, params.elementSize);
        s = StringUtils.replace(s, PLACEHOLDERS.javadocMethodReader, params.javadocMethodReader);
        s = StringUtils.replace(s, PLACEHOLDERS.javadocMethodWriter, params.javadocMethodWriter);
        out.println(s);
    }

    public static void main(String[] args) throws IOException
    {
        for (TemplateParameters t : NUMERICAL_TYPES)
        {
            if (t.isUnsigned == false)
            {
                final String interfaceTemplateReader =
                        FileUtils
                                .readFileToString(new File(
                                        "sourceTest/java/ch/systemsx/cisd/hdf5/tools/IHDF5PrimitiveReader.java.templ"), 
                                        Charset.defaultCharset());
                final PrintStream outInterfaceReader =
                        new PrintStream(new File("source/java/ch/systemsx/cisd/hdf5/IHDF5"
                                + t.capitalizedName + "Reader.java"));
                generateCode(interfaceTemplateReader, t, outInterfaceReader);
                outInterfaceReader.close();
            }
            final String classTemplateReader =
                    FileUtils
                            .readFileToString(new File(
                                    t.isUnsigned ? "sourceTest/java/ch/systemsx/cisd/hdf5/tools/HDF5UnsignedPrimitiveReader.java.templ"
                                            : "sourceTest/java/ch/systemsx/cisd/hdf5/tools/HDF5PrimitiveReader.java.templ"), 
                                    Charset.defaultCharset());
            final PrintStream outclassReader =
                    new PrintStream(new File("source/java/ch/systemsx/cisd/hdf5/HDF5"
                            + (t.isUnsigned ? "Unsigned" : "") + t.capitalizedName + "Reader.java"));
            generateCode(classTemplateReader, t, outclassReader);
            outclassReader.close();
            if (t.isUnsigned == false)
            {
                final String interfaceTemplateWriter =
                        FileUtils
                                .readFileToString(new File(
                                        "sourceTest/java/ch/systemsx/cisd/hdf5/tools/IHDF5PrimitiveWriter.java.templ"), 
                                        Charset.defaultCharset());
                final PrintStream outInterfaceWriter =
                        new PrintStream(new File("source/java/ch/systemsx/cisd/hdf5/IHDF5"
                                + t.capitalizedName + "Writer.java"));
                generateCode(interfaceTemplateWriter, t, outInterfaceWriter);
                outInterfaceWriter.close();
            }
            final String classTemplateWriter =
                    FileUtils
                            .readFileToString(new File(
                                    t.isUnsigned ? "sourceTest/java/ch/systemsx/cisd/hdf5/tools/HDF5UnsignedPrimitiveWriter.java.templ"
                                            : "sourceTest/java/ch/systemsx/cisd/hdf5/tools/HDF5PrimitiveWriter.java.templ"), 
                                    Charset.defaultCharset());
            final PrintStream outclassWriter =
                    new PrintStream(new File("source/java/ch/systemsx/cisd/hdf5/HDF5"
                            + (t.isUnsigned ? "Unsigned" : "") + t.capitalizedName + "Writer.java"));
            generateCode(classTemplateWriter, t, outclassWriter);
            outclassWriter.close();
        }
    }
}
