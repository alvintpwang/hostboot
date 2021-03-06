/* IBM_PROLOG_BEGIN_TAG                                                   */
/* This is an automatically generated prolog.                             */
/*                                                                        */
/* $Source: src/usr/hwpf/hwp/dram_training/mss_draminit/mss_ddr4_funcs.H $ */
/*                                                                        */
/* OpenPOWER HostBoot Project                                             */
/*                                                                        */
/* Contributors Listed Below - COPYRIGHT 2013,2015                        */
/* [+] International Business Machines Corp.                              */
/*                                                                        */
/*                                                                        */
/* Licensed under the Apache License, Version 2.0 (the "License");        */
/* you may not use this file except in compliance with the License.       */
/* You may obtain a copy of the License at                                */
/*                                                                        */
/*     http://www.apache.org/licenses/LICENSE-2.0                         */
/*                                                                        */
/* Unless required by applicable law or agreed to in writing, software    */
/* distributed under the License is distributed on an "AS IS" BASIS,      */
/* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or        */
/* implied. See the License for the specific language governing           */
/* permissions and limitations under the License.                         */
/*                                                                        */
/* IBM_PROLOG_END_TAG                                                     */
// $Id: mss_ddr4_funcs.H,v 1.5 2015/09/04 18:14:20 thi Exp $

//------------------------------------------------------------------------------
// *! (C) Copyright International Business Machines Corp. 2013
// *! All Rights Reserved -- Property of IBM
// *! ***  ***
//------------------------------------------------------------------------------
// *! TITLE : mss_ddr4_funcs.H
// *! DESCRIPTION : Tools for DDR4 DIMMs centaur procedures
// *! OWNER NAME : jdsloat@us.ibm.com
// *! BACKUP NAME : sglancy@us.ibm.com
// #! ADDITIONAL COMMENTS :
//

//------------------------------------------------------------------------------
// Don't forget to create CVS comments when you check in your changes!
//------------------------------------------------------------------------------
// CHANGE HISTORY:
//------------------------------------------------------------------------------
// Version:|  Author: |  Date:  | Comment:
//---------|----------|---------|-----------------------------------------------
//         |          |         |
//  1.5    | 09/04/15 | thi     | Fix Doxygen
//  1.4    | 03/14/14 | kcook   | Added DDR4 Register function support.
//  1.3    | 10/10/13 | bellows | Added required CVS Id comment
//  1.2    | 10/09/13 | jdsloat | Fixed argument list in function call
//  1.1    | 10/04/13 | jdsloat | First revision

#ifndef _MSS_DDR4_FUNCS_H
#define _MSS_DDR4_FUNCS_H


//----------------------------------------------------------------------
// DDR4 FUNCS
//----------------------------------------------------------------------


//--------------------------------------------------------------
// @brief Set MRS1 settings for Rank 0 and Rank 1
//
// @param[in] i_target             Reference to MBA Target.
// @param[in] i_port_number        MBA port number
// @param[in/out] io_ccs_inst_cnt  CCS instruction count
//
// @return ReturnCode
//--------------------------------------------------------------
fapi::ReturnCode mss_mrs_load_ddr4( fapi::Target& i_target,
                                      uint32_t i_port_number,
                                      uint32_t& io_ccs_inst_cnt);

//--------------------------------------------------------------
// @brief Writes MPR pattern for inverted address location for
//        training with DDR4 RDIMMs.
//
// @param[in] i_target_mba          Reference to MBA Target.
//
// @return ReturnCode
//--------------------------------------------------------------
fapi::ReturnCode mss_ddr4_invert_mpr_write( fapi::Target& i_target_mba);

//--------------------------------------------------------------
// @brief Writes RCD control words for DDR4 register.
//
// @param[in] i_target             Reference to MBA Target.
// @param[in] i_port_number        MBA port number
// @param[in/out] io_ccs_inst_cnt  CCS instruction count
//
// @return ReturnCode
//--------------------------------------------------------------
fapi::ReturnCode mss_rcd_load_ddr4(
            fapi::Target& i_target,
            uint32_t i_port_number,
            uint32_t& io_ccs_inst_cnt);

//--------------------------------------------------------------
// @brief Creates RCD_CNTRL_WORD attribute for DDR4 register
//
// @param[in] i_target_mba          Reference to MBA Target.
//
// @return ReturnCode
//--------------------------------------------------------------
fapi::ReturnCode mss_create_rcd_ddr4( const fapi::Target& i_target_mba);

#endif /* _MSS_DDR4_FUNCS_H */


