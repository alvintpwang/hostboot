#!/usr/bin/perl
# IBM_PROLOG_BEGIN_TAG
# This is an automatically generated prolog.
#
# $Source: src/usr/errl/parser/genErrlParsers.pl $
#
# IBM CONFIDENTIAL
#
# COPYRIGHT International Business Machines Corp. 2013
#
# p1
#
# Object Code Only (OCO) source materials
# Licensed Internal Code Source Materials
# IBM HostBoot Licensed Internal Code
#
# The source code for this program is not published or otherwise
# divested of its trade secrets, irrespective of what has been
# deposited with the U.S. Copyright Office.
#
# Origin: 30
#
# IBM_PROLOG_END_TAG

# Purpose: Generates files needed to parse SRC and User Detail Data from
#   Hostboot error logs. The files are delivered to the FSP and built there
#
# It scans the hostboot source code for the doxygen like error log tags and
# generates a C file for each component containing a function called by the FSP
# errl tool to parse the error log SRC, for example:
# - hbfwSrcParse1.C (For parsing errlogs generated by comp-id 0x01)
# - hbfwSrcParse2.C
# - hbfwSrcParse3.C
# It generates a file that contains IDs needed by the Hostboot User Detail Data
# parsers
# - hbfwUdIds.H
# It generates a makefile that builds the Hostboot SRC/UserDetailData parsers
# - makefile

use strict;
use Time::localtime;

#------------------------------------------------------------------------------
# Process Arguments
#------------------------------------------------------------------------------
my $DEBUG = 0;
my $base = ".";
my $outputDir = ".";

while( $ARGV = shift )
{
    if( $ARGV =~ m/-b/ )
    {
        $base = shift;
    }
    elsif( $ARGV =~ m/-o/i )
    {
        $outputDir = shift;
    }
    elsif( $ARGV =~ m/-d/i )
    {
        $DEBUG = 1;
    }
    else
    {
        usage();
    }
}

#------------------------------------------------------------------------------
# Global variables
#------------------------------------------------------------------------------
my $compIdFile = $base."/src/include/usr/hbotcompid.H";
my $compPath = $base."/src/usr";
my $compIncPath = $base."/src/include/usr";
my $genFilesPath = $base."/obj/genfiles";

#------------------------------------------------------------------------------
# Call subroutines to populate the following arrays:
# - @reasonCodeFiles   (The list of files to parse through for reason codes)
# - @filesToParse      (The list of files to parse through for SRC tags)
# - @pluginDirsToParse (the list of plugin directories containing User Detail
#                       Data parsers)
#------------------------------------------------------------------------------
my @reasonCodeFiles;
my @filesToParse;
my @pluginDirsToParse;
getReasonCodeFiles($compIncPath);
getFilesToParse($compPath);
getFilesToParse($compIncPath);
getFilesToParse($genFilesPath);
getPluginDirsToParse($compPath);

if ($DEBUG)
{
    print("---> ReasonCode files to process\n");
    foreach my $file(@reasonCodeFiles)
    {
        print("RC File: $file\n");
    }
}

if ($DEBUG)
{
    print("---> Files to parse for error log tags\n");
    foreach my $file(@filesToParse)
    {
        print("File to Parse: $file\n");
    }
}

if ($DEBUG)
{
    print("---> Directories to parse for user detail data\n");
    foreach my $dir(@pluginDirsToParse)
    {
        print("Plugin Directory to Parse: $dir\n");
    }
}

#------------------------------------------------------------------------------
# Process the compIdFile, recording all of the component ID values
#------------------------------------------------------------------------------
my %compIdToValueHash;

open(COMP_ID_FILE, $compIdFile) or die("Cannot open: $compIdFile: $!");

while (my $line = <COMP_ID_FILE>)
{
    # An example of the component ID line is:
    # const compId_t DEVFW_COMP_ID = 0x0200;
    if ($line =~ /^const compId_t (\w+) = 0x([\dA-Fa-f]+)00/)
    {
        my $compId = $1;
        my $compValue = $2;

        # Strip off any leading zeroes from the component value
        $compValue =~ s/^0//g;
        # Do not add PRDF component ID
        if ($compId ne "PRDF_COMP_ID")
        {
            $compIdToValueHash{$compId} = $compValue;
        }
    }
}

close(COMP_ID_FILE);

if ($DEBUG)
{
    print("---> Component ID values\n");
    foreach my $key (keys %compIdToValueHash)
    {
        print ("CompId: $key = $compIdToValueHash{$key},\n");
    }
}

#------------------------------------------------------------------------------
# Process the reasonCodeFiles, recording all of the module ids, reason codes
# and user detail data sections in hashes: The module ids and reason codes
# can be duplicated across components and so the namespace is also stored.
# Example hashes:
#
# %modIdToValueHash = (
#     'PNOR'   => { 'MOD_PNORDD_ERASEFLASH'     => '1A',
#                   'MOD_PNORDD_READFLASH'      => '12'},
#     'IBSCOM' => { 'IBSCOM_GET_TARG_VIRT_ADDR' => '03',
#                   'IBSCOM_SANITY_CHECK'       => '02'}
# );
#
# %rcToValueHash = (
#     'PNOR'   => { 'RC_UNSUPPORTED_OPERATION'  => '0607',
#                   'RC_STARTUP_FAIL'           => '0605'},
#     'IBSCOM' => { 'IBSCOM_INVALID_CONFIG'     => '1C03',
#                   'IBSCOM_INVALID_OP_TYPE'    => '1C02'}
# );
#
# %udIdToValueHash = (
#     'HWPF_UDT_HWP_RCVALUE' => '0x01',
#     'ERRL_UDT_CALLOUT'     => '0x07'
# );
#------------------------------------------------------------------------------
my %modIdToValueHash;
my %rcToValueHash;
my %udIdToValueHash;

foreach my $file (@reasonCodeFiles)
{
    open(RC_FILE, $file) or die("Cannot open: $file: $!");
    my $namespace = "NO_NS";
    my $processing = 0;
    my $processingModIds = 1;
    my $processingRcs = 2;
    my $processingUds = 3;
    my $compId = "";

    while (my $line = <RC_FILE>)
    {
        if ($line =~ /^\s*namespace\s+(\w+)/)
        {
            if ($namespace ne "NO_NS")
            {
                print ("$0: Multiple namespaces in '$file'\n");
                exit(1);
            }
            $namespace = $1;

            # Check for common code files where the reason codes do not contain
            # component IDs. Expand this hash as needed to add more components
            my %namespaceToCompHash = (
                "HWAS" => "HWAS_COMP_ID");

            if (exists $namespaceToCompHash{$namespace})
            {
                # Reason codes do not contain component IDs
                $compId = $namespaceToCompHash{$namespace};
            }
            else
            {
                # Reason codes contain component IDs
                $compId = "";
            }

            next;
        }
        elsif ($line =~ /enum.+ModuleId/i)
        {
            $processing = $processingModIds;
            next;
        }
        elsif ($line =~ /enum.+ReasonCode/i)
        {
            $processing = $processingRcs;
            next;
        }
        elsif ($line =~ /enum.+UserDetail/i)
        {
            $processing = $processingUds;
            next;
        }
        elsif ($line =~ /}/)
        {
            $processing = 0;
            next;
        }

        if ($processing == $processingModIds)
        {
            # Example: "MOD_PNORRP_WAITFORMESSAGE       = 0x01"
            if ($line =~ /(\w+)\s+=\s+0x([\dA-Fa-f]+)/)
            {
                $modIdToValueHash{$namespace}->{$1} = $2;
            }
        }
        elsif ($processing == $processingRcs)
        {
            if ($compId ne "")
            {
                # Reason code line does not contain Component ID
                # Example: "RC_TARGET_NOT_DECONFIGURABLE        = 0x01,"
                if ($line =~ /(\w+)\s+=\s+0x([\dA-Fa-f]+)/)
                {
                    if (! exists $compIdToValueHash{$compId})
                    {
                        print ("$0: Could not find CompID '$compId'\n");
                        exit(1);
                    }
                    $rcToValueHash{$namespace}->{$1} =
                        $compIdToValueHash{$compId} . $2;
                }
            }
            else
            {
                # Reason code line contains Component ID
                # Example: "RC_INVALID_MESSAGE_TYPE      = PNOR_COMP_ID | 0x01"
                if ($line =~ /(\w+)\s+=\s+(\w+)\s+\|\s+0x([\dA-Fa-f]+)/)
                {
                    if (! exists $compIdToValueHash{$2})
                    {
                        print ("$0: Could not find CompID '$2'\n");
                        exit(1);
                    }
                    $rcToValueHash{$namespace}->{$1} =
                        $compIdToValueHash{$2} . $3;
                }
            }
        }
        elsif ($processing == $processingUds)
        {
            # Example: "HWPF_UDT_HWP_RCVALUE       = 0x01,"
            if ($line =~ /(\w+)\s+=\s+(0x[\dA-Fa-f]+)/)
            {
               my $udId = $1;
               my $udValue = $2;

               if (exists($udIdToValueHash{$udId}))
               {
                   print ("$0: duplicate user data section in '$file'\n");
                   print ("$0: section is '$udId'\n");
                   exit(1);
               }

               $udIdToValueHash{$udId} = $udValue;
            }
        }
    }

    close(RC_FILE);
}

if ($DEBUG)
{
    print("---> ModuleId values\n");
    foreach my $namespaceKey (keys %modIdToValueHash)
    {
        foreach my $modIdKey (keys %{$modIdToValueHash{$namespaceKey}})
        {
            print ("$namespaceKey:$modIdKey:$modIdToValueHash{$namespaceKey}->{$modIdKey}\n");
        }
    }

    print("---> ReasonCode values\n");
    foreach my $namespaceKey (keys %rcToValueHash)
    {
        foreach my $rcKey (keys %{$rcToValueHash{$namespaceKey}})
        {
            print ("$namespaceKey:$rcKey:$rcToValueHash{$namespaceKey}->{$rcKey}\n");
        }
    }

    print("---> User Detail Data Section values\n");
    foreach my $udKey (keys %udIdToValueHash)
    {
        print ("$udKey:$udIdToValueHash{$udKey}\n");
    }
}

#------------------------------------------------------------------------------
# Generate the FSP hbfwUdIds.H file that contains the set of Hostboot component
# IDs and user detail data IDs. This is used by the user data parsers
#------------------------------------------------------------------------------
my $outputFileName = $outputDir . "/hbfwUdIds.H";
open(OFILE, ">", $outputFileName) or die("Cannot open: $outputFileName: $!");

print OFILE "// Automatically generated by Hostboot's $0\n";
print OFILE "// Do not modify this file in the FSP tree, it is provided by\n";
print OFILE "// Hostboot and will be overwritten\n";
print OFILE "//\n\n";
print OFILE "\#ifndef HBFWUDIDS_H\n";
print OFILE "\#define HBFWUDIDS_H\n\n";
print OFILE "// Hostboot component IDs\n";
print OFILE "namespace hbfw\n";
print OFILE "{\n";
print OFILE "    enum\n";
print OFILE "    {\n";
foreach my $key (keys %compIdToValueHash)
{
    print OFILE "        $key = 0x$compIdToValueHash{$key}00,\n";
}
print OFILE "    };\n";
print OFILE "}\n\n";
print OFILE "// Hostboot User Detail Data IDs\n";
print OFILE "enum\n";
print OFILE "{\n";
foreach my $udKey (keys %udIdToValueHash)
{
    print OFILE "    $udKey = $udIdToValueHash{$udKey},\n";
}
print OFILE "};\n\n";
print OFILE "#endif\n";

close(OFILE);

#------------------------------------------------------------------------------
# Process the code files, looking for error log tags, save the parsing for each
# in a hash indexed by the component value
#------------------------------------------------------------------------------
my %compValueToParseHash;
my %rcModValuesUsed;

foreach my $file (@filesToParse)
{
    open(PARSE_FILE, $file) or die("Cannot open: $file: $!");
    my @namespaces;
    push(@namespaces, "NO_NS");

    #-------------------------------------------------------------------------
    # Example Tag:
    #   /*@
    #     * @errortype
    #     * @reasoncode     I2C_INVALID_OP_TYPE
    #     * @severity       ERRL_SEV_UNRECOVERABLE
    #     * @moduleid       I2C_PERFORM_OP
    #     * @userdata1      i_opType
    #     * @userdata2      addr
    #     * @devdesc        Invalid Operation type.
    #     */
    # =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
    while (my $line = <PARSE_FILE>)
    {
        if ($line =~ /namespace\s+(\w+)/)
        {
            # Found a namespace, record it to be used when searching for
            # moduleid and reasoncode values
            push(@namespaces, $1);
            next;
        }

        if ($line =~ /\/\*\@/)
        {
            # Found the start of an error log tag
            my $modId = "";
            my $modIdValue = "";
            my $rc = "";
            my $rcValue = "";
            my @userData;
            my $desc = "";

            # Read the entire error log tag into an array
            my @tag;

            while ($line = <PARSE_FILE>)
            {
                if ($line =~ /\*\//)
                {
                    # Found the end of an error log tag
                    last;
                }
                push(@tag, $line);
            }

            # Process the error log tag
            my $numLines = scalar (@tag);

            for (my $lineNum = 0; $lineNum < $numLines; $lineNum++)
            {
                $line = $tag[$lineNum];

                if ($line =~ /\@moduleid\s+(\S+)/i)
                {
                    # Found a moduleid, find out the value
                    $modId = $1;

                    if ($modId =~ /(\w+)::(\w+)/)
                    {
                        # The namespace was provided
                        if ((exists $modIdToValueHash{$1}) &&
                            (exists ${modIdToValueHash{$1}->{$2}}))
                        {
                            $modIdValue = ${modIdToValueHash{$1}->{$2}};
                        }
                    }
                    else
                    {
                        # The namespace was not provided, look through all
                        # namespaces mentioned in the file
                        foreach my $namespace(@namespaces)
                        {
                            if ((exists $modIdToValueHash{$namespace}) &&
                                (exists ${modIdToValueHash{$namespace}->{$modId}}))
                            {
                                $modIdValue = ${modIdToValueHash{$namespace}->{$modId}};
                                last;
                            }
                        }
                    }

                    if ($modIdValue eq "")
                    {
                        print ("$0: Error finding moduleid value for '$file:$line'\n");
                        exit(1);
                    }
                }
                elsif ($line =~ /\@reasoncode\s+(\S+)/i)
                {
                    # Found a reasoncode, figure out the value
                    $rc = $1;

                    if ($rc =~ /(\w+)::(\w+)/)
                    {
                        # The namespace was provided
                        if ((exists $rcToValueHash{$1}) &&
                            (exists ${rcToValueHash{$1}->{$2}}))
                        {
                            $rcValue = ${rcToValueHash{$1}->{$2}};
                        }
                    }
                    else
                    {
                        # The namespace was not provided, look through all
                        # namespaces mentioned in the file
                        foreach my $namespace(@namespaces)
                        {
                            if ((exists $rcToValueHash{$namespace}) &&
                                (exists ${rcToValueHash{$namespace}->{$rc}}))
                            {
                                $rcValue = ${rcToValueHash{$namespace}->{$rc}};
                                last;
                            }
                        }
                    }

                    if ($rcValue eq "")
                    {
                        print ("$0: Error finding reasoncode value for '$file:$line'\n");
                        exit(1);
                    }
                }
                elsif ($line =~ /\@(userdata\S+)\s+(\S+.*)/i)
                {
                    # Found user data, strip out any double-quotes and trailing
                    # whitespace
                    my $udDesc = $1;
                    my $udText = $2;
                    $udText =~ s/\"//g;
                    $udText =~ s/\s+$//;

                    # Look for follow-on lines
                    for ($lineNum++; $lineNum < $numLines; $lineNum++)
                    {
                        $line = $tag[$lineNum];

                        if ($line =~ /\@/)
                        {
                            # Found the next element, rewind
                            $lineNum--;
                            last;
                        }

                        # Continuation of user data, strip out any double-quotes
                        # and leading / trailing whitespace
                        $line =~ s/^.+\*\s+//;
                        $line =~ s/\"//g;
                        $line =~ s/\s+$//;

                        if ($line ne "")
                        {
                            $udText = $udText . " " . $line;
                        }
                    }

                    my $udString = "\"$udDesc\", \"$udText\"";
                    push(@userData, $udString);
                }
                elsif ($line =~ /\@devdesc\s+(\S+.*)/i)
                {
                    # Found a description, strip out any double-quotes and
                    # trailing whitespace
                    $desc = $1;
                    $desc =~ s/\"//g;
                    $desc =~ s/\s+$//;

                    # Look for follow-on lines
                    for ($lineNum++; $lineNum < $numLines; $lineNum++)
                    {
                        $line = $tag[$lineNum];

                        if ($line =~ /\@/)
                        {
                            # Found the next element, rewind
                            $lineNum--;
                            last;
                        }

                        # Continuation of description, strip out any double-
                        # quotes and leading / trailing whitespace
                        $line =~ s/^.+\*\s+//;
                        $line =~ s/\"//g;
                        $line =~ s/\s+$//;

                        if ($line ne "")
                        {
                            $desc = $desc . " " . $line;
                        }
                    }
                }
            }

            # Check that the required fields were found
            if ($modId eq "")
            {
                print ("$0: moduleid missing from error log tag in '$file'\n");
                print ("$0: reasoncode is '$rc'\n");
                exit(1);
            }

            if ($rc eq "")
            {
                print ("$0: reasoncode missing from error log tag in '$file'\n");
                print ("$0: moduleid is '$modId'\n");
                exit(1);
            }

            if ($desc eq "")
            {
                print ("$0: description missing from error log tag in '$file'\n");
                print ("$0: moduleid is '$modId', reasoncode is '$rc'\n");
                exit(1);
            }

            # Create the combined returncode/moduleid value that the parser looks for and
            # ensure that it is not a duplicate of one already found
            my $rcModValue = $rcValue . $modIdValue;

            if (exists($rcModValuesUsed{$rcModValue}))
            {
                print ("$0: duplicate moduleid/reasoncode error log tag in '$file'\n");
                print ("$0: moduleid is '$modId', reasoncode is '$rc'\n");
                exit(1);
            }

            $rcModValuesUsed{$rcModValue} = 1;

            # Create the parser code for this error
            my $parserCode = "    case 0x$rcModValue:\n"
                           . "        i_parser.PrintString(\"devdesc\", \"$desc\");\n"
                           . "        i_parser.PrintString(\"moduleid\", \"$modId\");\n"
                           . "        i_parser.PrintString(\"reasoncode\", \"$rc\");\n";
            foreach my $udString(@userData)
            {
                $parserCode .= "        i_parser.PrintString($udString);\n";
            }
            $parserCode .= "        break;\n\n";

            # The component value is the first two characters of the 4 character rc
            my $compValue = $rcValue;
            $compValue =~ s/..$//;

            # Add the parser code to compValueToParseHash
            $compValueToParseHash{$compValue} .= $parserCode;
        }
    }

    close(PARSE_FILE);
}

#------------------------------------------------------------------------------
# For each component value, print a file containing the parse code
#------------------------------------------------------------------------------
my $timestamp = ctime();
my $imageId = getImageId();

foreach my $compValue (keys %compValueToParseHash)
{
    my $outputFileName = $outputDir . "/hbfwSrcParse$compValue.C";
    open(OFILE, ">", $outputFileName) or die("Cannot open: $outputFileName: $!");

    print OFILE "/*\n";
    print OFILE " * Automatically generated by Hostboot's $0\n";
    print OFILE " * Do not modify this file in the FSP tree, it is provided by\n";
    print OFILE " * Hostboot and will be overwritten\n";
    print OFILE " *\n";
    print OFILE " * TimeStamp:   $timestamp\n";
    print OFILE " * Image Id:    $imageId\n";
    print OFILE " *\n";
    print OFILE " */\n\n";
    print OFILE "#include <errlplugins.H>\n";
    print OFILE "#include <errlusrparser.H>\n";
    print OFILE "#include <srcisrc.H>\n\n";
    print OFILE "static bool SrcDataParse(ErrlUsrParser & i_parser,\n";
    print OFILE "                         const SrciSrc & i_src)\n";
    print OFILE "{\n";
    print OFILE "    uint32_t l_error = (i_src.reasonCode() << 8) + i_src.moduleId();\n";
    print OFILE "    bool l_success = true;\n\n";
    print OFILE "    switch(l_error)\n";
    print OFILE "    {\n";
    print OFILE $compValueToParseHash{$compValue};
    print OFILE "    default:\n";
    print OFILE "        l_success = false;\n";
    print OFILE "        break;\n";
    print OFILE "    };\n";
    print OFILE "    return l_success;\n";
    print OFILE "}\n\n";
    print OFILE "static errl::SrcPlugin g_SrcPlugin(0x$compValue";
    print OFILE "00, SrcDataParse, ERRL_CID_HOSTBOOT);\n";

    close(OFILE);
}

#------------------------------------------------------------------------------
# Figure out the user detail data files to compile for each component
#------------------------------------------------------------------------------
my %compValToUdFilesHash;

foreach my $dir(@pluginDirsToParse)
{
    my $ofiles = "";
    my $compId = "";
    my $compVal = 0;

    # Open the directory and read all entries (files) skipping any beginning
    # with "."
    my @dirEntries;
    opendir(DH, $dir) or die("Cannot open $dir directory");
    @dirEntries = grep { !/^\./ } readdir(DH);
    closedir(DH);

    # The plugin directory must contain a <COMP_ID>_Parse.C file which contains
    # the user detail data parser for that component
    foreach my $file(@dirEntries)
    {
        if ($file =~ /^(.+).C$/)
        {
            # Found a C file add it to the files to compile list
            $ofiles .= "$1\.o ";

            if ($file =~ /^(.+COMP_ID)_Parse.C$/)
            {
                # Found the main Parse.C file for a component
                $compId = $1;
            }
        }
    }

    if ($compId eq "")
    {
        print ("$0: Could not find CompID Parser file in $dir\n");
        exit(1);
    }

    # Find the component ID value
    if (! exists $compIdToValueHash{"$compId"})
    {
        print ("$0: Could not find CompID $compId while processing $dir\n");
        exit(1);
    }
    $compVal = $compIdToValueHash{$compId};

    $compValToUdFilesHash{$compVal} = $ofiles;
}

#------------------------------------------------------------------------------
# Generate the FSP makefile that builds the Hostboot error log parsers
#------------------------------------------------------------------------------
$outputFileName = $outputDir . "/makefile";
open(OFILE, ">", $outputFileName) or die("Cannot open: $outputFileName: $!");

print OFILE "\# Automatically generated by Hostboot's $0\n";
print OFILE "\# Do not modify this file in the FSP tree, it is provided by\n";
print OFILE "\# Hostboot and will be overwritten\n";
print OFILE "\#\n";

print OFILE "CFLAGS += -DPARSER\n\n";
print OFILE "EXPLIBS =\n\n";

print OFILE "\#-------------------------------------------------------------\n";
print OFILE "\# Call PRD makefile for prdf plugins\n";
print OFILE "\#-------------------------------------------------------------\n";
print OFILE ".if ( \$(CONTEXT) != \"x86.nfp\" )\n";
print OFILE "EXPLIB_SUBDIRS += prdf\n";
print OFILE "EXPSHLIB_SUBDIRS += prdf\n";
print OFILE ".else\n";
print OFILE "EXPLIB_SUBDIRS += prdf\n";
print OFILE ".endif\n";

print OFILE "\#-------------------------------------------------------------\n";
print OFILE "\# SRC Parsers\n";
print OFILE "\#-------------------------------------------------------------\n";
foreach my $compValue (keys %compValueToParseHash)
{
    print OFILE ".if ( \$(CONTEXT) != \"x86.nfp\" )\n";
    print OFILE "\tlibB-$compValue" . "00.so_OFILES = hbfwSrcParse$compValue.o\n";
    print OFILE "\tlibB-$compValue" . "00.so_EXTRA_LIBS = libbase.so\n\n";
    print OFILE ".else\n";
    print OFILE "\tlibB-$compValue" . "00.a_OFILES = hbfwSrcParse$compValue.o\n";
    print OFILE ".endif\n";
}

print OFILE "\#-------------------------------------------------------------\n";
print OFILE "\# User Detail Data Parsers\n";
print OFILE "\#-------------------------------------------------------------\n";
foreach my $compValue (keys %compValToUdFilesHash)
{
    print OFILE ".if ( \$(CONTEXT) != \"x86.nfp\" )\n";
    print OFILE "libB-$compValue" . "00.so_OFILES += $compValToUdFilesHash{$compValue}\n";
    print OFILE ".else\n";
    print OFILE "libB-$compValue" . "00.a_OFILES += $compValToUdFilesHash{$compValue}\n";
    print OFILE ".endif\n";
}

print OFILE ".if ( \$(CONTEXT) != \"x86.nfp\" )\n";
print OFILE "\#-------------------------------------------------------------\n";
print OFILE "\# Shared library for each component\n";
print OFILE "\#-------------------------------------------------------------\n";
print OFILE "SHARED_LIBRARIES = ";
foreach my $compValue (keys %compValueToParseHash)
{
    print OFILE "libB-$compValue" . "00.so ";
}
print OFILE "\n.else\n";
print OFILE "\#-------------------------------------------------------------\n";
print OFILE "\# x86 mode generate an archive file for each component\n";
print OFILE "\#-------------------------------------------------------------\n";
print OFILE "LIBRARIES = ";
foreach my $compValue (keys %compValueToParseHash)
{
    print OFILE "libB-$compValue" . "00.a ";
}
print OFILE "\nEXPLIBS = ";
foreach my $compValue (keys %compValueToParseHash)
{
    print OFILE "libB-$compValue" . "00.a ";
}
print OFILE "\n.endif\n";


print OFILE "\n\n.include<\${RULES_MK}>\n";

close(OFILE);

#------------------------------------------------------------------------------
# Subroutine that prints the usage
#------------------------------------------------------------------------------
sub usage
{
    print "Usage: $0 <-b base> <-d> <-o output dir>\"\n";
    print "\n";
    print "-b:     Base directory containing Hostboot src directory (default is pwd)\n";
    print "-o:     Output directory where files are created (default is pwd)\n";
    print "-d      Enable Debug messages.\n";
    print "\n\n";
    exit 1;
}

#------------------------------------------------------------------------------
# Subroutine that updates @reasonCodeFiles
#------------------------------------------------------------------------------
sub getReasonCodeFiles
{
    # Open the input directory and read all entries (files/directories)
    # Skipping any beginning with "."
    my $inputDir = @_[0];
    my @dirEntries;
    opendir(DH, $inputDir) or die("Cannot open $inputDir directory");
    @dirEntries = grep { !/^\./ } readdir(DH);
    closedir(DH);

    foreach my $dirEntry (@dirEntries)
    {
        my $dirEntryPath = "$inputDir/$dirEntry";

        if (-d $dirEntryPath)
        {
            # Exclude PRD directory
            if ( !($dirEntryPath =~ /prdf/) )
            {
                # Recursively call this function
                getReasonCodeFiles($dirEntryPath);
            }
        }
        elsif(($dirEntry =~ /reasoncodes/i) ||
              ($dirEntry =~ /service_codes/i) ||
              ($dirEntry =~ /examplerc/i))
        {
            # Found reason-codes file
            push(@reasonCodeFiles, $dirEntryPath);
        }
    }
}

#------------------------------------------------------------------------------
# Subroutine that updates @filesToParse
#------------------------------------------------------------------------------
sub getFilesToParse
{
    # Open the input directory and read all entries (files/directories)
    # Skipping any beginning with "."
    my $inputDir = @_[0];
    my @dirEntries;
    opendir(DH, $inputDir) or die("Cannot open $inputDir directory");
    @dirEntries = grep { !/^\./ } readdir(DH);
    closedir(DH);

    foreach my $dirEntry (@dirEntries)
    {
        my $dirEntryPath = "$inputDir/$dirEntry";

        if (-d $dirEntryPath)
        {
            # Exclude PRD directory
            if ( !($dirEntryPath =~ /prdf/) )
            {
                # Recursively call this function
                getFilesToParse($dirEntryPath);
            }
        }
        elsif($dirEntry =~ /\.[H|C]$/)
        {
            # Found file to parse
            push(@filesToParse, $dirEntryPath);
        }
    }
}

#------------------------------------------------------------------------------
# Subroutine that updates @pluginDirsToParse
#------------------------------------------------------------------------------
sub getPluginDirsToParse
{
    # Open the input directory and read all entries (files/directories)
    # Skipping any beginning with "."
    my $inputDir = @_[0];
    my @dirEntries;
    opendir(DH, $inputDir) or die("Cannot open $inputDir directory");
    @dirEntries = grep { !/^\./ } readdir(DH);
    closedir(DH);

    foreach my $dirEntry (@dirEntries)
    {
        my $dirEntryPath = "$inputDir/$dirEntry";

        if (-d $dirEntryPath)
        {
            if ($dirEntryPath =~ /plugins/)
            {
                # Found plugins directory
                push(@pluginDirsToParse, $dirEntryPath);
            }
            else
            {
                # Exclude PRD directory
                if ( !($dirEntryPath =~ /prdf/) )
                {
                    # Recursively call this function
                    getPluginDirsToParse($dirEntryPath);
                }
            }
        }
    }
}

#------------------------------------------------------------------------------
# Subroutine that gets the Image ID
#------------------------------------------------------------------------------
sub getImageId
{
    my $imageId = `git describe --dirty || echo Unknown-Image \`git rev-parse --short HEAD\``;
    chomp $imageId;

    if (($imageId =~ m/Unknown-Image/) ||   # Couldn't find git describe tag.
        ($imageId =~ m/dirty/) ||       # Find 'dirty' commit.
        ($imageId =~ m/^.{15}-[1-9]+/)) # Found commits after a tag.
    {
        $imageId = $imageId."/".$ENV{"USER"};
    }

    return $imageId;
}

