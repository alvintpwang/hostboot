# IBM_PROLOG_BEGIN_TAG
# This is an automatically generated prolog.
#
# $Source: src/usr/hwpf/plat/plat.mk $
#
# IBM CONFIDENTIAL
#
# COPYRIGHT International Business Machines Corp. 2014
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
# Common to both HB and HBRT
EXTRAINCDIR += ${ROOTPATH}/src/include/usr/ecmddatabuffer
EXTRAINCDIR += ${ROOTPATH}/src/include/usr/hwpf/plat
EXTRAINCDIR += ${ROOTPATH}/src/include/usr/hwpf/fapi
EXTRAINCDIR += ${ROOTPATH}/src/include/usr/hwpf/hwp

OBJS = fapiPlatHwAccess.o \
       fapiPlatHwpInvoker.o \
       fapiPlatReturnCodeDataRef.o \
       fapiPlatSystemConfig.o \
       fapiPlatTarget.o \
       fapiPlatUtil.o \
       fapiPlatAttributeService.o \
       fapiPlatMvpdAccess.o \
       fapiPlatMBvpdAccess.o \
       fapiPlatAttrOverrideSync.o
